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

// This class is used internally when an Exception occurs within an immediate
// handler case
public class ImmediateFrameExceptionWrapper {
    ImmediateFrameExceptionWrapper(let frame: Option<HandlerFrame>, let exception: Exception) {}
}

// This class is used internally when an Error occurs within an immediate
// handler case
public class ImmediateFrameErrorWrapper {
    ImmediateFrameErrorWrapper(let frame: Option<HandlerFrame>, let error: Error) {}
}

// This class is used internally when an immediate handler case finishes
// execution without resuming
// 
// Note: there's an issue with generics in Cangjie that don't allow us to
// have the type of result be generic
public class ImmediateEarlyReturn {
    ImmediateEarlyReturn(let frame: Option<HandlerFrame>, let result: Any) {}
}

class ImmediateHandlerCase<Cmd, Res, Ret> <: HandlerCase {
    ImmediateHandlerCase(let frame: HandlerFrame, let h: (Cmd) -> ImmediateHandlerReturn<Res>) {}
    protected override func tryHandle<R1>(maybeCmd: Command<R1>): Option<R1> {
        match (maybeCmd as Cmd) {
            case Some(cmd) =>
                let oldFrame = HandlerFrame.getActiveFrame()
                try {
                    HandlerFrame.setActiveFrame(frame.parent)
                    match (this.h(cmd)) {
                        case Result(v) => v as R1
                        case Exc(e) => throw e
                        case Err(e) => throw e
                    }
                } finally {
                    HandlerFrame.setActiveFrame(oldFrame)
                }
            case None => None
        }
    }
}

public class ImmediateFrame<Ret> <: HandlerFrame {
    public ImmediateFrame(let fn: () -> Ret) {}
    public func start(): Ret {
        let previous = HandlerFrame.getActiveFrame()
        this.parent = previous
        try {
            HandlerFrame.setActiveFrame(this)
            fn()
        } finally {
            HandlerFrame.setActiveFrame(previous)
            this.finalizer()
        }
    }
}
