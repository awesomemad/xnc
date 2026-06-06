const std = @import("std");
const Config = @import("config.zig").Config;

fn colorCode(name: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, name, "black")) return "\x1b[30m";
    if (std.mem.eql(u8, name, "red")) return "\x1b[31m";
    if (std.mem.eql(u8, name, "green")) return "\x1b[32m";
    if (std.mem.eql(u8, name, "yellow")) return "\x1b[33m";
    if (std.mem.eql(u8, name, "blue")) return "\x1b[34m";
    if (std.mem.eql(u8, name, "magenta")) return "\x1b[35m";
    if (std.mem.eql(u8, name, "cyan")) return "\x1b[36m";
    if (std.mem.eql(u8, name, "white")) return "\x1b[37m";
    if (std.mem.eql(u8, name, "bold")) return "\x1b[1m";
    if (std.mem.eql(u8, name, "dim")) return "\x1b[2m";
    if (std.mem.eql(u8, name, "italic")) return "\x1b[3m";
    if (std.mem.eql(u8, name, "underline")) return "\x1b[4m";
    if (std.mem.eql(u8, name, "reset")) return "\x1b[0m";
    if (std.mem.eql(u8, name, "bright_red")) return "\x1b[91m";
    if (std.mem.eql(u8, name, "bright_green")) return "\x1b[92m";
    if (std.mem.eql(u8, name, "bright_yellow")) return "\x1b[93m";
    if (std.mem.eql(u8, name, "bright_blue")) return "\x1b[94m";
    if (std.mem.eql(u8, name, "bright_magenta")) return "\x1b[95m";
    if (std.mem.eql(u8, name, "bright_cyan")) return "\x1b[96m";
    return null;
}

pub const Display = struct {
    cfg: *const Config,
    writer: std.io.AnyWriter,

    pub fn init(cfg: *const Config, writer: std.io.AnyWriter) Display {
        return .{ .cfg = cfg, .writer = writer };
    }

    pub fn color(self: *Display, name: []const u8) void {
        if (!self.cfg.color_enabled) return;
        if (colorCode(name)) |code| {
            self.writer.writeAll(code) catch {};
        }
    }

    pub fn resetColor(self: *Display) void {
        if (!self.cfg.color_enabled) return;
        self.writer.writeAll("\x1b[0m") catch {};
    }

    pub fn prompt(self: *Display) void {
        if (self.cfg.color_enabled) {
            self.color(self.cfg.prompt_color);
            self.writer.writeAll(self.cfg.prompt_template) catch {};
            self.resetColor();
        } else {
            self.writer.writeAll(self.cfg.prompt_template) catch {};
        }
    }

    pub fn result(self: *Display, label: []const u8, value: []const u8) void {
        if (self.cfg.show_ans_label and label.len > 0) {
            if (self.cfg.color_enabled) {
                self.color(self.cfg.color_result);
                self.writer.print("{s} ", .{label}) catch {};
                self.resetColor();
            } else {
                self.writer.print("{s} ", .{label}) catch {};
            }
        }
        if (self.cfg.color_enabled) {
            self.color(self.cfg.color_number);
            self.writer.writeAll(value) catch {};
            self.resetColor();
        } else {
            self.writer.writeAll(value) catch {};
        }
        self.writer.writeAll("\n") catch {};
    }

    pub fn showError(self: *Display, msg: []const u8) void {
        if (self.cfg.color_enabled) {
            self.color(self.cfg.color_error);
            self.writer.writeAll("ERROR: ") catch {};
            self.resetColor();
        } else {
            self.writer.writeAll("ERROR: ") catch {};
        }
        self.writer.writeAll(msg) catch {};
        self.writer.writeAll("\n") catch {};
    }

    pub fn warning(self: *Display, msg: []const u8) void {
        if (!self.cfg.show_warnings) return;
        if (self.cfg.color_enabled) {
            self.color(self.cfg.color_warning);
            self.writer.writeAll("WARNING: ") catch {};
            self.resetColor();
        } else {
            self.writer.writeAll("WARNING: ") catch {};
        }
        self.writer.writeAll(msg) catch {};
        self.writer.writeAll("\n") catch {};
    }

    pub fn info(self: *Display, msg: []const u8) void {
        if (self.cfg.color_enabled) {
            self.color(self.cfg.info_color);
            self.writer.writeAll(msg) catch {};
            self.resetColor();
        } else {
            self.writer.writeAll(msg) catch {};
        }
        self.writer.writeAll("\n") catch {};
    }

    pub fn writeLine(self: *Display, msg: []const u8) void {
        self.writer.writeAll(msg) catch {};
        self.writer.writeAll("\n") catch {};
    }

    pub fn clear(self: *Display) void {
        self.writer.writeAll("\x1b[2J\x1b[H") catch {};
    }

    pub fn welcome(self: *Display) void {
        if (!self.cfg.show_welcome) return;
        const line = "-" ** 50;
        self.writeLine(line);
        self.writeLine(self.cfg.welcome_message);
        if (self.cfg.show_version) {
            self.writeLine(self.cfg.version_info);
        }
        self.writeLine("Type 'help' for commands, 'exit' to quit");
        self.writeLine(line);
        self.writer.writeAll("\n") catch {};
    }

    pub fn showHelp(self: *Display, topic: ?[]const u8) void {
        const t = topic orelse "";
        if (std.mem.eql(u8, t, "operators") or std.mem.eql(u8, t, "ops")) {
            self.writeLine("=== Operators ===");
            self.writeLine("  +    Addition");
            self.writeLine("  -    Subtraction / Negation");
            self.writeLine("  *    Multiplication");
            self.writeLine("  /    Division");
            self.writeLine("  ^    Power");
            self.writeLine("  %    Modulo");
            self.writeLine("  !    Factorial (postfix: 5!)");
            self.writeLine("  _    Previous answer");
            self.writeLine("  ()   Grouping / Function calls");
            self.writeLine("  []   List constructor");
            return;
        }
        if (std.mem.eql(u8, t, "functions") or std.mem.eql(u8, t, "funcs") or std.mem.eql(u8, t, "fn")) {
            self.writeLine("=== Functions ===");
            self.writeLine("  Trig: sin, cos, tan, asin, acos, atan, atan2");
            self.writeLine("  Hyper: sinh, cosh, tanh, asinh, acosh, atanh");
            self.writeLine("  Log: exp, ln, log, log2, log10");
            self.writeLine("  Roots: sqrt, cbrt, root");
            self.writeLine("  Round: abs, floor, ceil, round, trunc, frac, sign");
            self.writeLine("  Stats: min, max, clamp, lerp, deg, rad");
            self.writeLine("  Number: gcd, lcm, fact, nCr, nPr, hypot, mod, rem");
            self.writeLine("  Complex: conj, real, imag, arg, norm, polar, rect");
            self.writeLine("  Power: pow, expm1, log1p, erf, erfc");
            self.writeLine("  Special: gamma, lgamma, zeta, sigmoid, relu, softplus");
            self.writeLine("  Secant: cot, sec, csc, acot, asec, acsc, coth, sech, csch, sinc");
            return;
        }
        if (std.mem.eql(u8, t, "constants") or std.mem.eql(u8, t, "consts")) {
            self.writeLine("=== Constants ===");
            self.writeLine("  pi / π          3.14159265358979");
            self.writeLine("  e               2.71828182845905");
            self.writeLine("  tau / τ         6.28318530717959");
            self.writeLine("  phi / φ         1.61803398874989");
            self.writeLine("  gamma_const / γ 0.57721566490153");
            self.writeLine("  inf / ∞         Infinity");
            self.writeLine("  i / j           Imaginary unit");
            return;
        }
        if (std.mem.eql(u8, t, "graph") or std.mem.eql(u8, t, "plot") or std.mem.eql(u8, t, "plotting")) {
            self.writeLine("=== Graphing ===");
            self.writeLine("  graph sin(x)      Plot sin(x)");
            self.writeLine("  graph sin(x);cos(x)  Multiple traces");
            self.writeLine("  graph             Re-display last graph");
            self.writeLine("  ");
            self.writeLine("  Settings (via config or set):");
            self.writeLine("    graph_width, graph_height");
            self.writeLine("    graph_x_min, graph_x_max");
            self.writeLine("    graph_y_min, graph_y_max");
            self.writeLine("    graph_auto_scale, graph_show_axes");
            self.writeLine("    graph_show_grid, graph_show_legend");
            self.writeLine("    graph_resolution, graph_color");
            return;
        }
        if (std.mem.eql(u8, t, "config") or std.mem.eql(u8, t, "configuration") or std.mem.eql(u8, t, "settings")) {
            self.writeLine("=== Configuration ===");
            self.writeLine("  config            Show current settings");
            self.writeLine("  config-gen        Generate xnc.toml");
            self.writeLine("  config-tui        Interactive wizard");
            self.writeLine("  set <key> = <val> Change a setting");
            self.writeLine("  reset             Reset to defaults");
            self.writeLine("  ");
            self.writeLine("  Run 'config' to see all settings.");
            return;
        }
        if (std.mem.eql(u8, t, "units") or std.mem.eql(u8, t, "unit") or std.mem.eql(u8, t, "convert")) {
            self.writeLine("=== Unit Conversion ===");
            self.writeLine("  unit <val> <from> <to>");
            self.writeLine("  ");
            self.writeLine("  Examples:");
            self.writeLine("    unit 100 km mi");
            self.writeLine("    unit 32 f c");
            self.writeLine("    unit 5 gal l");
            self.writeLine("  ");
            self.writeLine("  80+ units across 17 categories.");
            return;
        }
        if (std.mem.eql(u8, t, "stats") or std.mem.eql(u8, t, "statistics") or std.mem.eql(u8, t, "data")) {
            self.writeLine("=== Statistics ===");
            self.writeLine("  data <value>      Add data point");
            self.writeLine("  stats show        Show statistics");
            self.writeLine("  stats clear       Clear data");
            self.writeLine("  ");
            self.writeLine("  Shows: n, sum, mean, median, stdev,");
            self.writeLine("  variance, min, max, quartiles,");
            self.writeLine("  linear regression.");
            return;
        }
        if (std.mem.eql(u8, t, "additions") or std.mem.eql(u8, t, "add") or std.mem.eql(u8, t, "custom")) {
            self.writeLine("=== Additions (Custom Functions & Constants) ===");
            self.writeLine("  additions list                    List all");
            self.writeLine("  additions add-fn <n> = <expr>    Add function");
            self.writeLine("  additions add-const <n> = <v>    Add constant");
            self.writeLine("  ");
            self.writeLine("  Saved to ~/.xnc/additions.toml");
            self.writeLine("  Available in all sessions.");
            return;
        }
        if (std.mem.eql(u8, t, "okugin") or std.mem.eql(u8, t, "plugins") or std.mem.eql(u8, t, "plugin")) {
            self.writeLine("=== Okugins (Plugins) ===");
            self.writeLine("  okugin list       List installed plugins");
            self.writeLine("  ");
            self.writeLine("  Okugins extend xnc with new functions,");
            self.writeLine("  commands, hooks, converters, graphs,");
            self.writeLine("  and display themes.");
            self.writeLine("  Place .okugin files in ~/.xnc/okugins/");
            return;
        }
        if (std.mem.eql(u8, t, "vars") or std.mem.eql(u8, t, "variables")) {
            self.writeLine("=== Variables ===");
            self.writeLine("  vars           Show all variables");
            self.writeLine("  <name> = <expr>  Set a variable");
            self.writeLine("  ans            Show last result");
            self.writeLine("  ");
            self.writeLine("  Use variables in expressions:");
            self.writeLine("    x = 5");
            self.writeLine("    x^2 + 3");
            return;
        }
        if (std.mem.eql(u8, t, "matrix") or std.mem.eql(u8, t, "matrices")) {
            self.writeLine("=== Matrix Operations ===");
            self.writeLine("  [1,2;3,4]  Create a 2x2 matrix");
            self.writeLine("  Supports: +, -, *, det, inv, transpose");
            return;
        }
        if (std.mem.eql(u8, t, "modes") or std.mem.eql(u8, t, "mode")) {
            self.writeLine("=== Modes ===");
            self.writeLine("  mode    Show current mode");
            self.writeLine("  angle   Toggle deg/rad/grad");
            self.writeLine("  set input_mode = rpn    Change input mode");
            self.writeLine("  set output_base = 16   Hex output");
            self.writeLine("  set result_format = scientific");
            return;
        }

        if (t.len > 0) {
            self.writeLine("Unknown help topic. Try: operators, functions, constants, graph,");
            self.writeLine("  config, units, stats, additions, okugin, vars, matrix, modes");
            return;
        }

        self.writeLine("╔══════════════════════════════════════════╗");
        self.writeLine("║            xnc Help v3.2.0              ║");
        self.writeLine("╚══════════════════════════════════════════╝");
        self.writeLine("");
        self.writeLine("  help <topic>  for detailed info on a topic");
        self.writeLine("");
        self.writeLine("  Topics: operators, functions, constants, graph,");
        self.writeLine("          config, units, stats, additions, okugin,");
        self.writeLine("          vars, matrix, modes");
        self.writeLine("");
        self.writeLine("  Examples:  help functions   help graph   help config");
        self.writeLine("");
        self.writeLine("  Quick start:");
        self.writeLine("    2+2           Basic arithmetic");
        self.writeLine("    sin(pi/2)     Trigonometry");
        self.writeLine("    x = 5         Variables");
        self.writeLine("    graph sin(x)  Plot a function");
        self.writeLine("    unit 100 km mi  Unit conversion");
        self.writeLine("    data 42       Data entry");
        self.writeLine("    config-tui    Interactive setup");
        self.writeLine("    help          This screen");
        self.writeLine("    exit          Quit");
    }

    pub fn showConfig(self: *Display, cfg: *const Config) void {
        self.writeLine("=== Current Configuration ===");
        inline for (@typeInfo(Config).Struct.fields) |field| {
            const val = @field(cfg, field.name);
            const T = field.type;
            if (T == []const u8) {
                self.writer.print("  {s} = \"{s}\"\n", .{ field.name, val }) catch {};
            } else {
                self.writer.print("  {s} = {any}\n", .{ field.name, val }) catch {};
            }
        }
    }

    pub fn showVars(self: *Display, vars: anytype) void {
        self.writeLine("=== Variables ===");
        var it = vars.iterator();
        var count: u32 = 0;
        while (it.next()) |entry| {
            self.writer.print("  {s} = {d:.6}\n", .{ entry.key_ptr.*, entry.value_ptr.*.real }) catch {};
            count += 1;
        }
        if (count == 0) self.writeLine("  (no variables defined)");
    }

    pub fn showHistory(self: *Display, entries: [][]const u8) void {
        self.writeLine("=== History ===");
        for (entries, 0..) |entry, i| {
            self.writer.print("  {d:>4}: {s}\n", .{ i + 1, entry }) catch {};
        }
    }

    pub fn showMode(self: *Display, cfg: *const Config) void {
        self.writeLine("=== Mode ===");
        self.writer.print("  Input mode:       {s}\n", .{@tagName(cfg.input_mode)}) catch {};
        self.writer.print("  Angle unit:       {s}\n", .{@tagName(cfg.angle_unit)}) catch {};
        self.writer.print("  Output base:      {d}\n", .{@intFromEnum(cfg.output_base)}) catch {};
        self.writer.print("  Result format:    {s}\n", .{@tagName(cfg.result_format)}) catch {};
        self.writer.print("  Rounding:         {s}\n", .{@tagName(cfg.rounding)}) catch {};
        self.writer.print("  Complex mode:     {}\n", .{cfg.complex_enabled}) catch {};
        self.writer.print("  Unit conversion:  {}\n", .{cfg.unit_enabled}) catch {};
    }
};
