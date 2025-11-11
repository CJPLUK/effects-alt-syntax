# Effect Handlers Without Special Syntax

This package provides a way to use effect handlers in Cangjie
without the need for the special try-handle syntax hidden behind
the experimental flag `--enable-eh`.

> [!WARNING]
> This allows for deferred resumption but relies on a version of Cangjie newer than 1.0.3.
> For something which works with Cangjie 1.0.3, look at the [immediate-handlers branch](https://github.com/Huawei-Edinburgh-Programming-Languages/effects-alt-syntax/tree/immediate-handlers)

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
