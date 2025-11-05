# Effect Handlers (non-deferred) Without Special Syntax

This package provides a way to use effect handlers in Cangjie
without the need for the special try-handle syntax hidden behind
the experimental flag `--enable-eh`.

> ![WARNING]
> This does not allow for deferred resumptions.

## Minimal Example

```cangjie
import effects.*

class Effect <: Command<Int64> {
    Effect(let x: Int64) {}

    public func defaultImpl() { x }
}

main(): Int64 {
    println("Default implementation:")
    println(perform(Effect(6)))

    try_with_effects({=>
        println("With different handler:")
        println(perform(Effect(6)))
    }, Handle { e: Effect => e.x + 1 }
    // Optional "finally clause":
    // , Finally {=> println("...finally")}
    )

    return 0
}
```