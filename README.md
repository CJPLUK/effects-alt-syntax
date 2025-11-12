# Effect Handlers Without Special Syntax

This package provides a way to use effect handlers in Cangjie
without the need for the special try-handle syntax hidden behind
the experimental flag `--enable-eh`.

> [!WARNING]
> This allows for deferred resumption but relies on a version of Cangjie newer than 1.0.3.
> For something which works with Cangjie 1.0.3, look at the [immediate-handlers branch](https://github.com/Huawei-Edinburgh-Programming-Languages/effects-alt-syntax/tree/immediate-handlers)

### Notes for improvements:
- Allow multiple handlers

## Setup

Add this package as a dependency to your cjpm.toml config file with the following:
```toml
[dependencies]
  effects = { git = "https://github.com/Huawei-Edinburgh-Programming-Languages/effects-alt-syntax.git", branch = "deferred-resumption" }
```

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

    let message: String = try_with_effects({=>
        println("With different handler:")
        println(perform(Effect(6)))
        return "aoeu" // a value returned in this block is returned by the whole try_with_effects call
    }, handle { e: Effect => e.x + 1 }
    // Optional "finally clause":
    // , Finally {=> println("...finally")}
    )

    println("message") // aoeu

    let new_message: String = try_with_effects({=>
        println("With deferred handler:")
        println(perform(Effect(7)))
        println("after perform")
    }, // add a resumption argument here to automatically use deferred handlers:
    handle {c: Effect, r: Resumption<Int64, String> =>
        println("in deferred handler")
        if (c.x == 7) {
            // Deferred handlers allow for early returns as well
            // as intentionally storing the resumption to use later
            return "Alert! 7 is a special number, abort normal execution"
        } 
        resume(r, c.x + 2)
    })

    println(new_message)

    return 0
}
```
