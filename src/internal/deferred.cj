/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
 * This source file is part of the Cangjie project, licensed under Apache-2.0.
 * 
 * This is a modification of a file originally part of the stdx Cangjie library
 * under the same license.
 *
 * See https://cangjie-lang.cn/pages/LICENSE for license information.
 */

package effects.internal

internal import std.sync.AtomicBool

private type ThreadHandle = CPointer<Unit>

@FastNative
foreign func CJ_MRT_GetCurrentCJThread(): ThreadHandle

@FastNative
foreign func CJ_MRT_ThreadWait(): Unit

@FastNative
foreign func CJ_MRT_ThreadResumeAndWait(readyThread: ThreadHandle): Unit

@FastNative
foreign func CJ_MRT_ThreadReady(readyThread: ThreadHandle): Unit

internal enum HandlerResponse<Res> {
    Resume(Res) | Throw(Exception) | Abort(Error) | Invalid
}

extend<Res> HandlerResponse<Res> {
    protected func unpack<R1>(): R1 {
        match (this) {
            case Resume(r) => (r as R1).getOrThrow()
            case Throw(exn) => throw exn
            case Abort(err) => throw err
            case Invalid => throw Exception("INTERNAL ERROR: invalid handler response")
        }
    }
}

public class ResumptionInternal<Res, Ret> <: Resumption<Res, Ret> {
    private let used = AtomicBool(false)
    private let waitingThread = unsafe { CJ_MRT_GetCurrentCJThread() }
    ResumptionInternal(let handler: DeferredHandlerCase1<Res, Ret>) {}

    // Executed by the handler (handle block) from a different thread
    // to the one in which the object was constructed (waitingThread)
    private func respond(r: HandlerResponse<Res>): Ret {
        // EXECUTED BY HANDLER
        if (this.used.swap(true)) {
            throw DoubleResumeException()
        }
        this.handler.response = r
        this.handler.frame.parent = HandlerFrame.getActiveFrame()
        this.handler.frame.handlerThread = unsafe { CJ_MRT_GetCurrentCJThread() }
        unsafe { CJ_MRT_ThreadResumeAndWait(this.waitingThread) }
        this.handler.frame.mainLoop()
    }

    protected func proceed(res: Res): Ret {
        respond(Resume(res))
    }
    protected func fail(err: Error): Ret {
        respond(Abort(err))
    }
    protected func fail(exn: Exception): Ret {
        respond(Throw(exn))
    }
}

public type DeferredHandlerFn<Cmd, Res, Ret> = (Cmd, ResumptionInternal<Res, Ret>) -> Ret

// We need these intermediate class because there is currently no other way to represent
// the existential types DeferredHandleCase<_, _, Ret> (used by DeferredFrame<Ret>) and
// DeferredHandlerCase<_, Res, Ret> (used in ResumptionInternal<Res, Ret>)
abstract class DeferredHandlerCase0<Ret> <: HandlerCase {
    protected open func fulfill(): Ret
}

abstract class DeferredHandlerCase1<Res, Ret> <: DeferredHandlerCase0<Ret> {
    DeferredHandlerCase1(let frame: DeferredFrame<Ret>) {}
    var response: HandlerResponse<Res> = Invalid
}

class DeferredHandlerCase<Cmd, Res, Ret> <: DeferredHandlerCase1<Res, Ret> {
    DeferredHandlerCase(frame: DeferredFrame<Ret>, let h: DeferredHandlerFn<Cmd, Res, Ret>) {
        super(frame)
    }
    var command: Option<Cmd> = None
    var resumption: Option<ResumptionInternal<Res, Ret>> = None
    protected override func tryHandle<R1>(maybeCmd: Command<R1>): Option<R1> {
        // EXECUTED BY HANDLEE
        match (maybeCmd as Cmd) {
            case Some(cmd) =>
                this.command = cmd
                this.resumption = ResumptionInternal<Res, Ret>(this)
                this.frame.request(Perform(this))
                this.response.unpack<R1>()
            case None => None
        }
    }

    protected override func fulfill(): Ret {
        // EXECUTED BY HANDLER
        let cmd = this.command.getOrThrow()
        this.command = None
        let res = this.resumption.getOrThrow()
        this.resumption = None
        this.h(cmd, res)
    }
}

// Requests from the `try` block
enum HandlerRequest<Ret> {
    Invalid
    | Perform(DeferredHandlerCase0<Ret>)
    | Return(Ret)
    | Throw(Exception)
    | Abort(Error)
}

// Represents a try-handle-finally block which can register both immediate
// and deferred handlers for any effect.
public class DeferredFrame<Ret> <: HandlerFrameExpression<Ret> {
    var handlerThread = unsafe { CJ_MRT_GetCurrentCJThread() }
    var handleeThread = ThreadHandle()
    var handlerRequest: HandlerRequest<Ret> = Invalid

    protected DeferredFrame(fn: () -> Ret) { super(fn) }
    public override func start(): Ret {
        // Running the `try` block and handling the effects
        this.parent = HandlerFrame.getActiveFrame()
        spawn {
            // Running the `try` block.
            // Requests are handled by other thread by the ResumeAndWait
            // runtime function (to main thread) and leaving a request
            // in this.handlerRequest
            this.handleeThread = unsafe { CJ_MRT_GetCurrentCJThread() }
            HandlerFrame.setActiveFrame(this)
            try {
                this.request(HandlerRequest<Ret>.Return(this.fn()))
            } catch (exn: Exception) {
                this.request(Throw(exn))
            } catch (err: Error) {
                this.request(Abort(err))
            }
        }
        unsafe { CJ_MRT_ThreadWait() }
        // Handles all "final" requests from the thread spawned above?
        // i.e. return, throw, and abort
        // performs are handled elsewhere??
        this.mainLoop()
    }

    // Reacts to requests received from the 'handlee' (try-block)
    func mainLoop(): Ret {
        this.parent = HandlerFrame.getActiveFrame()
        match (this.handlerRequest) {
            case Perform(handlerCase) => handlerCase.fulfill()
            case Return(ret) =>
                unsafe { CJ_MRT_ThreadReady(handleeThread) }
                this.finalizer()
                ret
            case Throw(exn) =>
                unsafe { CJ_MRT_ThreadReady(handleeThread) }
                this.finalizer()
                throw exn
            case Abort(err) =>
                unsafe { CJ_MRT_ThreadReady(handleeThread) }
                this.finalizer()
                throw err
            case Invalid => throw Exception("INTERNAL ERROR: invalid handler request")
        }
    }

    func setDeferredHandler<Cmd, Res>(h: DeferredHandlerFn<Cmd, Res, Ret>): Unit {
        this.addHandlerCase(DeferredHandlerCase(this, h))
    }

    func request(req: HandlerRequest<Ret>) {
        // Method only called by the handler
        // (while inside of a `handle` block)
        this.handlerRequest = req
        unsafe { CJ_MRT_ThreadResumeAndWait(this.handlerThread) }
    }

    // Public method to construct the 'try-handle-finally' block before
    // later using the `then_finally` method to provide the 'finally'
    // as well as 'execute the block'.
    public func handle<Cmd, Res>(h: (Cmd, ResumptionInternal<Res, Ret>) -> Ret): This
    where Cmd <: Command<Res> {
        let defferred_handler: (Cmd, ResumptionInternal<Res, Ret>) -> Ret = { cmd: Cmd, r: ResumptionInternal<Res, Ret> =>
            try {
                h(cmd, r)
            } catch (exn: Exception) {
                HandlerFrame.failExn<Res, Ret>(r, exn)
            } catch (err: Error) {
                HandlerFrame.failErr<Res, Ret>(r, err)
            }
        }
        this.setDeferredHandler<Cmd, Res>(defferred_handler)
        this
    }
}
