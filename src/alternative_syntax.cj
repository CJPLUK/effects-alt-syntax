/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
 * This source file is part of the Cangjie project, licensed under Apache-2.0.
 * 
 * This is a modification of a file originally part of the stdx Cangjie library
 * under the same license.
 *
 * See https://cangjie-lang.cn/pages/LICENSE for license information.
 */

package effects

public import effects.internal.{Command, DoubleResumeException, UnhandledCommandException, DeferredHandlerFn, ResumptionInternal, HandlerFrame}
import effects.internal.{ImmediateFrame, DeferredFrame, ImmediateHandlerReturn}

public type Resumption<Res, Ret> = ResumptionInternal<Res, Ret>

public func perform<Cmd, Res>(cmd: Cmd): Res where Cmd <: Command<Res> {
    HandlerFrame.perf(cmd)
}

public func resume<Res, Ret>(r: Resumption<Res, Ret>, x: Res) {
    HandlerFrame.proceed(r, x)
}

public class Handle<Cmd, Res> where Cmd <: Command<Res> {
    public Handle(let f: (Cmd) -> Res) {}
}

public class DeferredHandle<Cmd, Res, Ret> where Cmd <: Command<Res> {
    public DeferredHandle(let f: DeferredHandlerFn<Cmd, Res, Ret>) {}
}

public func handle<Cmd, Res>(f: (Cmd) -> Res) where Cmd <: Command<Res> {
    Handle(f)
}

public func handle<Cmd, Res, Ret>(f: (Cmd, Resumption<Res, Ret>) -> Ret) where Cmd <: Command<Res> {
    DeferredHandle(f)
}

public class Finally {
    public Finally(let f: () -> Unit) {}
}

public func try_with_effects<Cmd, Res, Ret>( f: () -> Ret, h: Handle<Cmd, Res>, final!: Finally = Finally({=>})): Ret
where Cmd <: Command<Res> {
    let frame = ImmediateFrame(f)

    frame.setImmediateHandler<Cmd, Res, Ret> { cmd: Cmd =>
        try {
            return ImmediateHandlerReturn.Result(h.f(cmd))
        } catch (exn: Exception) {
            return ImmediateHandlerReturn<Res>.Exc(exn)
        } catch (err: Error) {
            return ImmediateHandlerReturn<Res>.Err(err)
        }
    }

    frame.setFinally(final.f)
    frame.start()
}

public func try_with_effects<Cmd, Res, Ret>( f: () -> Ret, h: DeferredHandle<Cmd, Res, Ret>, final!: Finally = Finally({=>})): Ret where Cmd <: Command<Res> {
    let frame = DeferredFrame(f)

    frame.setDeferredHandler({ cmd: Cmd, r: Resumption<Res, Ret> =>
        try {
            h.f(cmd, r)
        } catch (exn: Exception) {
            HandlerFrame.failExn(r, exn)
        } catch (err: Error) {
            HandlerFrame.failErr(r, err)
        }
    })
    frame.setFinally(final.f)
    frame.start()
}