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
import effects

class Effect <: effects.Command<Int64> {
    Effect(let x: Int64) {}
    public func defaultImpl() { x }
}
class Another <: effects.Command<Float64> {
    Another(let x: Float64) {}
    public func defaultImpl() { x }
}

main(): Int64 {
    println("Default implementation:")
    println(perform(Effect(6)))

    let message: String = effects.try_ {
        println("With different handler:")
        println(effects.perform(Effect(6)))
        return "aoeu"
    } .handle {e: Effect =>
        e.x + 1
    } .handle {a: Another =>
        a.x + 1.0
    } .then_finally {} // not omissable

    println(message)

    // try_deferrable is necessary to register deferred handlers
    let new_message: String = effects.try_deferrable {
        println("With deferred handler:")
        println(effects.perform(Effect(7)))
        println("after perform")
        return "Normal execution"
    // By adding an extra resumption argument to the lambda, this becomes
    // a deferred handler
    } .handle {c: Effect, r: effects.Resumption<Int64, String> =>
        println("in deferred handler")
        if (c.x == 7) {
            // Deferred handlers allow for early returns as well
            // as intentionally storing the resumption to use later
            return "Alert! 7 is a special number, abort normal execution"
        }
        effects.resume(r, c.x + 2)
    // You can also use immediate handlers here too
    } .handle {a: Another =>
        a.x + 1.0
    } .then_finally {}

    print(new_message)

    return 0
}
```
