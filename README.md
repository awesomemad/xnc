# xnc — X is Not a Calculator

A feature-rich terminal calculator and expression evaluator with graphing,
unit conversion, statistics, matrix operations, and a plugin system.

## Features

- **Expression evaluation** — Infix, postfix, prefix, RPN. Complex numbers.
- **80+ built-in functions** — Trig, hyperbolic, log/exp, stats, special functions
- **User-defined functions & constants** — `add-fn f = x^2 + 1` then call `f(5)`
- **Plugin system (okugins)** — `.okugin` files with `[function.<name>]` sections
- **ASCII/braille graphing** — `graph sin(x)` or `plot cos(x)`
- **Unit conversion** — `unit 100 km mi`
- **Statistics** — `data 1`, `data 2`, `stats show`
- **Matrix operations** — `[1,2;3,4]`
- **Visual config editor** — `config` command opens interactive TUI
- **TOML config file** — `config gen` writes `xnc.toml`
- **Expression history** — Persisted across sessions

## Building

Requires **Zig 0.13.0**.

```
zig build
```

## Usage

```
zig build run
```

Or directly:

```
./zig-out/bin/xnc
```

### Commands

| Command | Description |
|---------|-------------|
| `config` | Open visual config editor |
| `config show` | Display current config |
| `config gen` | Generate TOML config file |
| `graph <expr>` | Plot an expression (e.g. `graph sin(x)`) |
| `additions list` | List user-defined functions/constants |
| `additions add-fn <name> = <expr>` | Define a function |
| `additions add-const <name> = <value>` | Define a constant |
| `okugin list` | List discovered plugins |
| `data <value>` | Add a data point |
| `stats show` | Show statistics |
| `help [topic]` | Show help |
| `vars` | Show defined variables |
| `set <key> = <value>` | Change a config value |
| `unit <value> <from> <to>` | Convert a unit |
| `exit` / `quit` | Exit |

### Plugins

Place `.okugin` files in `~/.xnc/okugins/`. Example `hello.okugin`:

```ini
[plugin]
name = "hello"
version = "1.0"
description = "Hello world plugin"
author = "you"
type = "function"

[function.greet]
expression = "42"
```

Use `okugin list` to discover. Functions defined in plugins
are callable as `greet()` in expressions.

## Config

Default location: `xnc.toml` in current directory, `~/.xnc/additions.toml`
for user functions, or `$XNC_CONFIG` env var.
Run `config` for the visual editor, or `config gen` to generate a TOML file.

## License

MIT
