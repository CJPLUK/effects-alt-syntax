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

public import effects.internal.{Command, DoubleResumeException, UnhandledCommandException}
import effects.internal.{HandlerFrame, ImmediateFrame, ImmediateHandlerReturn}

public func perform<Cmd, Res>(cmd: Cmd): Res where Cmd <: Command<Res> {
    HandlerFrame.perf(cmd)
}

public class Handle<Cmd, Res> where Cmd <: Command<Res> {
    public Handle(let f: (Cmd) -> Res) {}
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
        } catch (e: Exception) {
            return ImmediateHandlerReturn<Res>.Exc(e)
        }
    }

    frame.setFinally(final.f)
    frame.start()
}
