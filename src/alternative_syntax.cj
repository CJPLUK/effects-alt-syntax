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

public import effects.internal.{Command, DoubleResumeException, UnhandledCommandException, DeferredFrame, ImmediateFrame, HandlerFrame}
import effects.internal.ResumptionInternal

public type Resumption<Res, Ret> = ResumptionInternal<Res, Ret>

public func perform<Cmd, Res>(cmd: Cmd): Res where Cmd <: Command<Res> {
    HandlerFrame.perf(cmd)
}

public func resume<Res, Ret>(r: Resumption<Res, Ret>, x: Res) {
    HandlerFrame.proceed(r, x)
}

public func try_deferrable<Ret>( f: () -> Ret): DeferredFrame<Ret> {
    DeferredFrame(f)
}

public func try_<Ret>( f: () -> Ret): ImmediateFrame<Ret> {
    ImmediateFrame<Ret>(f)
}