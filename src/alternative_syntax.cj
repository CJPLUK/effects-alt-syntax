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

public func try_with_effects<Cmd, Res>( f: () -> Unit, h: Handle<Cmd, Res>, final!: Finally = Finally({=>}))
where Cmd <: Command<Res> {
    let frame = ImmediateFrame(f)

    frame.setImmediateHandler<Cmd, Res, Unit> { cmd: Cmd =>
        try {
            return ImmediateHandlerReturn.Result(h.f(cmd))
        } catch (e: Exception) {
            return ImmediateHandlerReturn<Res>.Exc(e)
        }
    }

    frame.setFinally(final.f)
    frame.start()
}
