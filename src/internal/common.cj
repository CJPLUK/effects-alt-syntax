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

internal abstract class HandlerCase {
    protected open func tryHandle<R1>(cmd: Command<R1>): Option<R1>
}

// This class represents the possible returns of an immediate handler
internal enum ImmediateHandlerReturn<T> {
    Result(T)
    | Exc(Exception)
    | Err(Error)
}

public abstract class HandlerFrame {
    private static let ACTIVE_FRAME_KEY = ThreadLocal<HandlerFrame>()
    internal static func getActiveFrame(): Option<HandlerFrame> {
        ACTIVE_FRAME_KEY.get()
    }
    internal static func setActiveFrame(f: Option<HandlerFrame>) {
        ACTIVE_FRAME_KEY.set(f)
    }

    private var handlers = Array<HandlerCase>()
    internal var parent: Option<HandlerFrame> = None
    internal var finalizer: () -> Unit = {=>}
    internal func setFinally(finalizer: () -> Unit): Unit {
        this.finalizer = finalizer
    }

    internal func addHandlerCase(h: HandlerCase) {
        this.handlers = Array<HandlerCase>(this.handlers.size + 1) {
            i => if (i == 0) {
                h
            } else {
                this.handlers[i - 1]
            }
        }
    }

    protected static func perf<Cmd, Res>(cmd: Cmd): Res where Cmd <: Command<Res> {
        var maybeFrame = getActiveFrame()
        while (let Some(frame) <- maybeFrame) {
            for (handlerCase in frame.handlers) {
                if (let Some(result) <- handlerCase.tryHandle(cmd)) {
                    return result
                }
            }
            maybeFrame = frame.parent
        }
        cmd.defaultImpl()
    }

    protected static func proceed<Res, Ret>(r: ResumptionInternal<Res, Ret>, arg: Res): Ret {
        r.proceed(arg)
    }

    protected static func failErr<Res, Ret> (r: ResumptionInternal<Res, Ret>, err: Error): Ret {
        r.fail(err)
    }

    protected static func failExn<Res, Ret>(r: ResumptionInternal<Res, Ret>, exn: Exception): Ret {
        r.fail(exn)
    }
}

// Represents a try-handle-finally block expression which may return a value of type `Ret`
internal abstract class HandlerFrameExpression<Ret> <: HandlerFrame {
    HandlerFrameExpression( let fn: () -> Ret ) {}
    // Equivalent of executing the try-handle-finally block and return its value
    // as an expression.
    // The details of implementation will involve handling effects themselves so
    // is more complicated when allowing for deferred resumptions.
    protected func start(): Ret
    // Public facing method to use at end of constructing the object which automatically
    // executes the 'try-handle-finally block' to return a value (see README example)
    public func then_finally(f: () -> Unit) {
        this.setFinally(f)
        this.start()
    }


    // All types of `HandlerFrameExpression`s can register immediate effect handlers,
    // which only handle effects, but have no ability to defer the resumption by returning
    // early (with a value of type `Ret`).
    public func handle<Cmd, Res>(h: (Cmd) -> Res): This
    where Cmd <: Command<Res> {
        this.setImmediateHandler<Cmd, Res> { cmd: Cmd =>
            try {
                return ImmediateHandlerReturn.Result(h(cmd))
            } catch (exn: Exception) {
                return ImmediateHandlerReturn<Res>.Exc(exn)
            } catch (err: Error) {
                return ImmediateHandlerReturn<Res>.Err(err)
            }
        }
        this
    }
    private func setImmediateHandler<Cmd, Res>(h: (Cmd) -> ImmediateHandlerReturn<Res>): Unit {
        this.addHandlerCase(ImmediateHandlerCase<Cmd, Res, Ret>(this, h))
    }
}

abstract sealed class Resumption<Res, Ret> {}