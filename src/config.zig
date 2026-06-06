const std = @import("std");
const toml = @import("toml.zig");

pub const InputMode = enum {
    infix,
    postfix,
    prefix,
    rpn,
};

pub const AngleUnit = enum {
    degrees,
    radians,
    grads,
};

pub const FunctionSyntax = enum {
    before,
    after,
    traditional,
};

pub const OutputBase = enum(u8) {
    dec = 10,
    bin = 2,
    oct = 8,
    hex = 16,
};

pub const ResultFormat = enum {
    auto,
    fixed,
    scientific,
    engineering,
};

pub const FractionalFormat = enum {
    auto,
    decimal,
    fraction,
    mixed,
};

pub const RoundingMode = enum {
    nearest,
    floor,
    ceil,
    truncate,
    significant,
};

pub const ImplicitMultPrecedence = enum {
    standard,
    tight,
    loose,
};

pub const ComplexNotation = enum {
    cartesian,
    polar,
    cis,
};

pub const GraphEngine = enum {
    ascii,
    braille,
    none,
};

pub const HistorySearch = enum {
    fuzzy,
    exact,
    substring,
};

pub const MatrixBrackets = enum {
    square,
    parens,
    double,
};

pub const GraphTrigger = enum {
    disabled,
    enter,
    any,
    custom,
};

pub const LogLevel = enum {
    none,
    @"error",
    warn,
    info,
    debug,
};

pub const UnitSystem = enum {
    metric,
    imperial,
    auto,
};

pub const EvalMode = enum {
    normal,
    debug,
    trace,
};

pub const DecimalSep = enum {
    period,
    comma,
};

pub const DigitGroup = enum {
    none,
    comma,
    space,
    apostrophe,
};

pub const ArgSep = enum {
    comma,
    semicolon,
    pipe,
    space,
};

pub const Config = struct {
    // Input
    input_mode: InputMode = .infix,
    angle_unit: AngleUnit = .degrees,
    implicit_multiply: bool = true,
    function_syntax: FunctionSyntax = .before,
    arg_separator: ArgSep = .comma,
    decimal_separator: DecimalSep = .period,
    digit_group: DigitGroup = .none,
    auto_close_parens: bool = true,
    smart_completion: bool = false,

    // Precision
    significant_figures: u32 = 15,
    decimal_places: u32 = 0,
    use_sig_figs: bool = false,
    max_integer_digits: u32 = 20,
    fractional_format: FractionalFormat = .auto,
    rounding: RoundingMode = .nearest,
    output_base: OutputBase = .dec,
    show_base_prefix: bool = false,

    // Display
    result_format: ResultFormat = .auto,
    show_separators: bool = true,
    show_plus_sign: bool = false,
    color_enabled: bool = true,
    color_prompt: []const u8 = "cyan",
    color_result: []const u8 = "green",
    color_error: []const u8 = "red",
    color_warning: []const u8 = "yellow",
    color_number: []const u8 = "white",
    color_function: []const u8 = "magenta",
    color_operator: []const u8 = "blue",
    color_highlight: []const u8 = "bold",
    unicode_output: bool = true,
    unicode_fractions: bool = true,
    line_width: u32 = 80,
    result_lines: u32 = 0,
    show_ans_label: bool = true,
    show_expression: bool = true,
    show_result_banner: bool = false,
    show_time: bool = false,

    // Behavior
    auto_calc: bool = true,
    show_warnings: bool = true,
    confirm_exit: bool = true,
    error_beep: bool = false,
    key_click: bool = false,
    persistent_history: bool = true,
    history_size: u32 = 1000,
    history_unique: bool = false,
    ans_variable: []const u8 = "ans",
    last_result_variable: []const u8 = "prev",
    use_ans: bool = true,
    ans_on_empty: bool = true,
    strict_parsing: bool = false,
    allow_unknown_constants: bool = false,
    case_sensitive: bool = true,
    implicit_mult_precedence: ImplicitMultPrecedence = .standard,
    e_notation_always_scientific: bool = true,
    auto_repeat_operator: bool = false,
    wrap_at_boundary: bool = true,
    confirm_clear_history: bool = true,

    // Complex
    complex_enabled: bool = true,
    complex_notation: ComplexNotation = .cartesian,
    i_symbol: []const u8 = "i",
    show_real_zero: bool = false,
    polar_angle_unit: AngleUnit = .radians,

    // Keyboard
    graph_trigger: GraphTrigger = .disabled,
    exit_key: []const u8 = "ctrl+q",
    clear_key: []const u8 = "ctrl+l",
    history_back: []const u8 = "up",
    history_forward: []const u8 = "down",
    ans_key: []const u8 = "ctrl+a",
    graph_key: []const u8 = "ctrl+g",
    unit_conv_key: []const u8 = "ctrl+u",
    toggle_angle_key: []const u8 = "ctrl+d",
    copy_key: []const u8 = "ctrl+c",
    paste_key: []const u8 = "ctrl+v",
    help_key: []const u8 = "ctrl+h",
    clear_entry_key: []const u8 = "ctrl+e",
    tab_complete: bool = true,

    // Graph
    graph_engine: GraphEngine = .ascii,
    graph_width: u32 = 78,
    graph_height: u32 = 24,
    graph_x_min: f64 = -10.0,
    graph_x_max: f64 = 10.0,
    graph_y_min: f64 = -10.0,
    graph_y_max: f64 = 10.0,
    graph_auto_scale: bool = true,
    graph_show_axes: bool = true,
    graph_show_grid: bool = false,
    graph_show_legend: bool = true,
    graph_resolution: u32 = 120,
    graph_aspect_ratio: f64 = 0.5,
    graph_braille: bool = false,
    graph_color: bool = true,
    graph_multi_trace: bool = true,
    graph_x_label: []const u8 = "X",
    graph_y_label: []const u8 = "Y",

    // Functions
    load_math_lib: bool = true,
    allow_user_functions: bool = true,
    allow_user_constants: bool = true,
    extra_functions: [][]const u8 = &.{},

    // Unit system
    unit_enabled: bool = true,
    unit_system: UnitSystem = .auto,
    unit_temperature: []const u8 = "celsius",
    unit_pressure: []const u8 = "kpa",
    unit_length: []const u8 = "m",
    unit_mass: []const u8 = "kg",
    unit_volume: []const u8 = "l",
    unit_speed: []const u8 = "mps",
    unit_energy: []const u8 = "j",
    unit_time: []const u8 = "s",
    unit_auto_convert: bool = true,
    unit_convert_on_enter: bool = false,
    unit_show_conversion: bool = true,

    // History
    history_enabled: bool = true,
    history_max_entries: u32 = 1000,
    history_save_file: []const u8 = "~/.xnc_history",
    history_save_on_exit: bool = true,
    history_load_on_start: bool = true,
    history_show_timestamps: bool = false,
    history_search_mode: HistorySearch = .substring,
    history_dedup: bool = false,
    history_persist_across_sessions: bool = true,

    // Matrix
    matrix_enabled: bool = true,
    matrix_max_size: u32 = 20,
    matrix_brackets: MatrixBrackets = .square,
    matrix_separator_rows: bool = true,
    matrix_align_columns: bool = true,
    matrix_auto_detect: bool = true,

    // Stats
    stats_enabled: bool = true,
    stats_auto_regression: bool = true,
    stats_show_fitted: bool = true,
    stats_confidence_interval: f64 = 0.95,
    stats_max_data_points: u32 = 10000,

    // Advanced
    recursion_limit: u32 = 100,
    evaluation_timeout_ms: u32 = 10000,
    memory_limit_mb: u32 = 100,
    cache_expressions: bool = true,
    parallel_eval: bool = false,
    eval_mode: EvalMode = .normal,
    log_level: LogLevel = .none,
    log_file: []const u8 = "",

    // Customization
    prompt_template: []const u8 = "xnc> ",
    prompt_color: []const u8 = "cyan",
    error_color: []const u8 = "red",
    warning_color: []const u8 = "yellow",
    info_color: []const u8 = "bright_green",
    result_header: []const u8 = "= ",
    welcome_message: []const u8 = "xnc - X is Not a Calculator",
    show_welcome: bool = true,
    show_version: bool = true,
    version_info: []const u8 = "3.2.0",
    config_format: []const u8 = "toml",
    additions_path: []const u8 = "~/.xnc/additions.toml",
    okugins_dir: []const u8 = "~/.xnc/okugins",
    custom_aliases: std.StringArrayHashMap([]const u8) = undefined,

    pub fn init(allocator: std.mem.Allocator) Config {
        var cfg = Config{ .custom_aliases = std.StringArrayHashMap([]const u8).init(allocator) };
        cfg.extra_functions = &.{};
        return cfg;
    }

    pub fn deinit(self: *Config) void {
        self.custom_aliases.deinit();
    }

    pub fn generateTomlConfig(self: *Config, path: []const u8) !void {
        const file = if (std.fs.path.isAbsolute(path))
            try std.fs.createFileAbsolute(path, .{})
        else
            try std.fs.cwd().createFile(path, .{});
        defer file.close();
        const w = file.writer();

        try w.writeAll("# xnc configuration v3.2.0\n");
        try w.writeAll("# Generated by xnc. Edit this file or run `config` to configure.\n\n");

        const sections = [_]toml.Section{
            .{ .name = "input", .comment = "Input mode and parsing" },
            .{ .name = "precision", .comment = "Number precision and output formatting" },
            .{ .name = "display", .comment = "Display and color settings" },
            .{ .name = "behavior", .comment = "General behavior" },
            .{ .name = "complex", .comment = "Complex number settings" },
            .{ .name = "keyboard", .comment = "Keyboard shortcuts" },
            .{ .name = "graph", .comment = "Graphing" },
            .{ .name = "units", .comment = "Unit conversion" },
            .{ .name = "history", .comment = "Expression history" },
            .{ .name = "matrix", .comment = "Matrix operations" },
            .{ .name = "stats", .comment = "Statistics" },
            .{ .name = "advanced", .comment = "Advanced settings" },
            .{ .name = "customization", .comment = "Customization" },
        };

        const entry_defs = [_]struct { section: []const u8, key: []const u8, comment: []const u8, get_val: *const fn (*const Config) []const u8 }{
            .{ .section = "input", .key = "mode", .comment = "Input mode (infix, postfix, prefix, rpn)", .get_val = fieldToStr("input_mode") },
            .{ .section = "input", .key = "angle_unit", .comment = "Angle unit (degrees, radians, grads)", .get_val = fieldToStr("angle_unit") },
            .{ .section = "input", .key = "implicit_multiply", .comment = "Allow implicit multiplication", .get_val = fieldToStr("implicit_multiply") },
            .{ .section = "input", .key = "function_syntax", .comment = "Function syntax (before, after, traditional)", .get_val = fieldToStr("function_syntax") },
            .{ .section = "input", .key = "arg_separator", .comment = "Argument separator (comma, semicolon, pipe, space)", .get_val = fieldToStr("arg_separator") },
            .{ .section = "input", .key = "decimal_separator", .comment = "Decimal point (period, comma)", .get_val = fieldToStr("decimal_separator") },
            .{ .section = "input", .key = "digit_group", .comment = "Digit grouping (none, comma, space, apostrophe)", .get_val = fieldToStr("digit_group") },
            .{ .section = "input", .key = "auto_close_parens", .comment = "Auto-close parentheses", .get_val = fieldToStr("auto_close_parens") },
            .{ .section = "input", .key = "smart_completion", .comment = "Tab completion", .get_val = fieldToStr("smart_completion") },
            .{ .section = "precision", .key = "significant_figures", .comment = "Significant figures", .get_val = fieldToStr("significant_figures") },
            .{ .section = "precision", .key = "decimal_places", .comment = "Decimal places (0=auto)", .get_val = fieldToStr("decimal_places") },
            .{ .section = "precision", .key = "use_sig_figs", .comment = "Use significant figures", .get_val = fieldToStr("use_sig_figs") },
            .{ .section = "precision", .key = "output_base", .comment = "Output base (10, 2, 8, 16)", .get_val = fieldToStr("output_base") },
            .{ .section = "precision", .key = "show_base_prefix", .comment = "Show 0x/0b/0o prefixes", .get_val = fieldToStr("show_base_prefix") },
            .{ .section = "precision", .key = "rounding", .comment = "Rounding (nearest, floor, ceil, truncate, significant)", .get_val = fieldToStr("rounding") },
            .{ .section = "precision", .key = "fractional_format", .comment = "Fraction format (auto, decimal, fraction, mixed)", .get_val = fieldToStr("fractional_format") },
            .{ .section = "display", .key = "result_format", .comment = "Result format (auto, fixed, scientific, engineering)", .get_val = fieldToStr("result_format") },
            .{ .section = "display", .key = "color_enabled", .comment = "Enable colors", .get_val = fieldToStr("color_enabled") },
            .{ .section = "display", .key = "color_prompt", .comment = "Prompt color name", .get_val = fieldToStr("color_prompt") },
            .{ .section = "display", .key = "color_result", .comment = "Result color name", .get_val = fieldToStr("color_result") },
            .{ .section = "display", .key = "color_error", .comment = "Error color name", .get_val = fieldToStr("color_error") },
            .{ .section = "display", .key = "unicode_output", .comment = "Use unicode", .get_val = fieldToStr("unicode_output") },
            .{ .section = "display", .key = "line_width", .comment = "Line width for wrapping", .get_val = fieldToStr("line_width") },
            .{ .section = "display", .key = "show_expression", .comment = "Show expression with result", .get_val = fieldToStr("show_expression") },
            .{ .section = "behavior", .key = "auto_calc", .comment = "Auto-calculate on enter", .get_val = fieldToStr("auto_calc") },
            .{ .section = "behavior", .key = "show_warnings", .comment = "Show warnings", .get_val = fieldToStr("show_warnings") },
            .{ .section = "behavior", .key = "confirm_exit", .comment = "Confirm before exit", .get_val = fieldToStr("confirm_exit") },
            .{ .section = "behavior", .key = "strict_parsing", .comment = "Strict parsing mode", .get_val = fieldToStr("strict_parsing") },
            .{ .section = "behavior", .key = "case_sensitive", .comment = "Case-sensitive names", .get_val = fieldToStr("case_sensitive") },
            .{ .section = "complex", .key = "enabled", .comment = "Enable complex numbers", .get_val = fieldToStr("complex_enabled") },
            .{ .section = "complex", .key = "notation", .comment = "Complex notation (cartesian, polar, cis)", .get_val = fieldToStr("complex_notation") },
            .{ .section = "complex", .key = "i_symbol", .comment = "Imaginary unit symbol (i, j)", .get_val = fieldToStr("i_symbol") },
            .{ .section = "keyboard", .key = "history_back", .comment = "History back key", .get_val = fieldToStr("history_back") },
            .{ .section = "keyboard", .key = "history_forward", .comment = "History forward key", .get_val = fieldToStr("history_forward") },
            .{ .section = "keyboard", .key = "tab_complete", .comment = "Tab completion", .get_val = fieldToStr("tab_complete") },
            .{ .section = "graph", .key = "engine", .comment = "Graph engine (ascii, braille, none)", .get_val = fieldToStr("graph_engine") },
            .{ .section = "graph", .key = "width", .comment = "Graph width", .get_val = fieldToStr("graph_width") },
            .{ .section = "graph", .key = "height", .comment = "Graph height", .get_val = fieldToStr("graph_height") },
            .{ .section = "graph", .key = "x_min", .comment = "X minimum", .get_val = fieldToStr("graph_x_min") },
            .{ .section = "graph", .key = "x_max", .comment = "X maximum", .get_val = fieldToStr("graph_x_max") },
            .{ .section = "graph", .key = "auto_scale", .comment = "Auto-scale axes", .get_val = fieldToStr("graph_auto_scale") },
            .{ .section = "graph", .key = "show_axes", .comment = "Show axes", .get_val = fieldToStr("graph_show_axes") },
            .{ .section = "units", .key = "enabled", .comment = "Enable unit conversion", .get_val = fieldToStr("unit_enabled") },
            .{ .section = "units", .key = "system", .comment = "Unit system (metric, imperial, auto)", .get_val = fieldToStr("unit_system") },
            .{ .section = "history", .key = "enabled", .comment = "Enable history", .get_val = fieldToStr("history_enabled") },
            .{ .section = "history", .key = "max_entries", .comment = "Max history entries", .get_val = fieldToStr("history_max_entries") },
            .{ .section = "history", .key = "save_on_exit", .comment = "Save history on exit", .get_val = fieldToStr("history_save_on_exit") },
            .{ .section = "history", .key = "load_on_start", .comment = "Load history on start", .get_val = fieldToStr("history_load_on_start") },
            .{ .section = "matrix", .key = "enabled", .comment = "Enable matrix ops", .get_val = fieldToStr("matrix_enabled") },
            .{ .section = "matrix", .key = "max_size", .comment = "Max matrix size", .get_val = fieldToStr("matrix_max_size") },
            .{ .section = "stats", .key = "enabled", .comment = "Enable stats", .get_val = fieldToStr("stats_enabled") },
            .{ .section = "stats", .key = "auto_regression", .comment = "Auto regression", .get_val = fieldToStr("stats_auto_regression") },
            .{ .section = "advanced", .key = "recursion_limit", .comment = "Recursion limit", .get_val = fieldToStr("recursion_limit") },
            .{ .section = "advanced", .key = "eval_mode", .comment = "Eval mode (normal, debug, trace)", .get_val = fieldToStr("eval_mode") },
            .{ .section = "customization", .key = "prompt", .comment = "Prompt string", .get_val = fieldToStr("prompt_template") },
            .{ .section = "customization", .key = "welcome", .comment = "Welcome message", .get_val = fieldToStr("welcome_message") },
            .{ .section = "customization", .key = "show_welcome", .comment = "Show welcome", .get_val = fieldToStr("show_welcome") },
        };

        for (sections) |section| {
            try w.print("\n[{s}]\n", .{section.name});
            if (section.comment.len > 0) {
                try w.print("# {s}\n", .{section.comment});
            }
            for (entry_defs) |def| {
                if (!std.mem.eql(u8, def.section, section.name)) continue;
                if (def.comment.len > 0) {
                    try w.print("# {s}\n", .{def.comment});
                }
                const val_str = def.get_val(self);
                try w.print("{s} = {s}\n", .{ def.key, val_str });
            }
        }
    }

    fn fieldToEnumStr(self: *const Config, comptime name: []const u8) []const u8 {
        const field_type = @TypeOf(@field(self, name));
        const info = @typeInfo(field_type);
        if (info == .Enum) {
            return @tagName(@field(self, name));
        }
        return "";
    }

    fn fieldToStr(comptime name: []const u8) *const fn (*const Config) []const u8 {
        const impl = struct {
            fn f(cfg: *const Config) []const u8 {
                const val = @field(cfg, name);
                const T = @TypeOf(val);
                switch (@typeInfo(T)) {
                    .Bool => return if (val) "true" else "false",
                    .Int, .ComptimeInt => {
                        return std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{val}) catch "0";
                    },
                    .Float, .ComptimeFloat => {
                        return std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{val}) catch "0";
                    },
                    .Pointer => return val,
                    .Enum => return @tagName(val),
                    else => return "",
                }
            }
        }.f;
        return impl;
    }

    pub fn loadFromToml(self: *Config, allocator: std.mem.Allocator, path: []const u8) !void {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(contents);

        var map = try toml.TomlParser.parse(allocator, contents);
        defer {
            var it = map.keyIterator();
            while (it.next()) |k| allocator.free(k.*);
            map.deinit();
        }

        var it = map.iterator();
        while (it.next()) |entry| {
            const full_key = entry.key_ptr.*;
            const value = entry.value_ptr.*;

            const dot_pos = std.mem.indexOfScalar(u8, full_key, '.');
            const field_key = if (dot_pos) |pos| full_key[pos + 1 ..] else full_key;

            inline for (@typeInfo(Config).Struct.fields) |field| {
                if (std.mem.eql(u8, field_key, field.name)) {
                    const val_str = switch (value) {
                        .string => |s| s,
                        .boolean => |b| if (b) "true" else "false",
                        .integer => |i| std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{i}) catch "0",
                        .float => |f| std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{f}) catch "0",
                    };
                    setFieldValue(self, field, val_str);
                    break;
                }
            }
        }
    }

    pub fn runConfigWizard(self: *Config, path: []const u8) !void {
        const stdout = std.io.getStdOut().writer();
        const stdin = std.io.getStdIn().reader();
        var buf: [1024]u8 = undefined;

        try stdout.writeAll("\n");
        try stdout.writeAll("┌──────────────────────────────────────┐\n");
        try stdout.writeAll("│  xnc Configuration Wizard v3.2.0     │\n");
        try stdout.writeAll("│  Press Enter to accept defaults.     │\n");
        try stdout.writeAll("└──────────────────────────────────────┘\n\n");

        try stdout.writeAll("Config format: (1) TOML  (2) Lua  [1]: ");
        const fmt_line = try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse "";
        const fmt_trimmed = std.mem.trim(u8, fmt_line, " \t\r\n");
        if (std.mem.eql(u8, fmt_trimmed, "2") or std.mem.eql(u8, fmt_trimmed, "lua")) {
            self.config_format = "lua";
        } else {
            self.config_format = "toml";
        }

        const questions = [_]struct { key: []const u8, prompt: []const u8, default: []const u8, kind: enum { bool, @"enum", number, string }, options: []const u8 }{
            .{ .key = "input_mode", .prompt = "Input mode", .default = "infix", .kind = .@"enum", .options = "infix, postfix, prefix, rpn" },
            .{ .key = "angle_unit", .prompt = "Angle unit", .default = "degrees", .kind = .@"enum", .options = "degrees, radians, grads" },
            .{ .key = "implicit_multiply", .prompt = "Implicit multiplication", .default = "true", .kind = .bool, .options = "yes/no" },
            .{ .key = "decimal_places", .prompt = "Decimal places (0=auto)", .default = "0", .kind = .number, .options = "0-15" },
            .{ .key = "output_base", .prompt = "Output base", .default = "10", .kind = .number, .options = "10, 2, 8, 16" },
            .{ .key = "rounding", .prompt = "Rounding mode", .default = "nearest", .kind = .@"enum", .options = "nearest, floor, ceil, truncate, significant" },
            .{ .key = "color_enabled", .prompt = "Enable colors", .default = "true", .kind = .bool, .options = "yes/no" },
            .{ .key = "unicode_output", .prompt = "Unicode output", .default = "true", .kind = .bool, .options = "yes/no" },
            .{ .key = "complex_enabled", .prompt = "Complex numbers", .default = "true", .kind = .bool, .options = "yes/no" },
            .{ .key = "graph_width", .prompt = "Graph width", .default = "78", .kind = .number, .options = "40-200" },
            .{ .key = "graph_height", .prompt = "Graph height", .default = "24", .kind = .number, .options = "10-80" },
            .{ .key = "history_max_entries", .prompt = "Max history entries", .default = "1000", .kind = .number, .options = "10-10000" },
            .{ .key = "confirm_exit", .prompt = "Confirm on exit", .default = "true", .kind = .bool, .options = "yes/no" },
            .{ .key = "show_welcome", .prompt = "Show welcome on start", .default = "true", .kind = .bool, .options = "yes/no" },
            .{ .key = "prompt_template", .prompt = "Prompt string", .default = "xnc> ", .kind = .string, .options = "" },
        };

        for (questions) |q| {
            if (q.options.len > 0) {
                try stdout.print("  ({s}) ", .{q.options});
            }
            try stdout.print("{s} [{s}]: ", .{ q.prompt, q.default });
            const line = try stdin.readUntilDelimiterOrEof(&buf, '\n') orelse "";
            const trimmed = std.mem.trim(u8, line, " \t\r\n");
            const val = if (trimmed.len > 0) trimmed else q.default;

            inline for (@typeInfo(Config).Struct.fields) |field| {
                if (std.mem.eql(u8, q.key, field.name)) {
                    setFieldValue(self, field, val);
                }
            }
        }

        try stdout.writeAll("\n┌─ Saving configuration ─────────────────┐\n");
        if (std.mem.eql(u8, self.config_format, "lua")) {
            try self.generateLuaConfig(path);
            try stdout.writeAll("│  Config saved to xnc.lua               │\n");
        } else {
            try self.generateTomlConfig(path);
            try stdout.writeAll("│  Config saved to xnc.toml              │\n");
        }
        try stdout.writeAll("└──────────────────────────────────────┘\n");
    }

    pub fn generateLuaConfig(self: *Config, path: []const u8) !void {
        const file = if (std.fs.path.isAbsolute(path))
            try std.fs.createFileAbsolute(path, .{})
        else
            try std.fs.cwd().createFile(path, .{});
        defer file.close();
        const w = file.writer();

        try w.writeAll("-- xnc Lua configuration\n");
        try w.writeAll("-- Generated by xnc. Edit this file or run `config-tui` to reconfigure.\n\n");

        inline for (@typeInfo(Config).Struct.fields) |field| {
            const name = field.name;
            const val = @field(self, name);
            const T = field.type;

            if (T == bool) {
                try w.print("config.{s} = {s}\n", .{ name, if (val) "true" else "false" });
            } else if (T == u32 or T == u64) {
                try w.print("config.{s} = {d}\n", .{ name, val });
            } else if (T == f64) {
                try w.print("config.{s} = {d}\n", .{ name, val });
            } else if (T == []const u8) {
                try w.print("config.{s} = \"{s}\"\n", .{ name, val });
            } else {
                switch (@typeInfo(T)) {
                    .Enum => try w.print("config.{s} = \"{s}\"\n", .{ name, @tagName(val) }),
                    else => {},
                }
            }
        }
    }

    pub fn loadFromLua(self: *Config, allocator: std.mem.Allocator, path: []const u8) !void {
        const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(contents);

        var lines = std.mem.splitScalar(u8, contents, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or std.mem.startsWith(u8, trimmed, "--")) continue;

            const dot_pos = std.mem.indexOfScalar(u8, trimmed, '.') orelse continue;
            const after_dot = trimmed[dot_pos + 1 ..];
            const eq_pos = std.mem.indexOfScalar(u8, after_dot, '=') orelse continue;
            const key = std.mem.trim(u8, after_dot[0..eq_pos], " \t");
            var raw_val = std.mem.trim(u8, after_dot[eq_pos + 1 ..], " \t");

            if (raw_val.len >= 2 and raw_val[0] == '"' and raw_val[raw_val.len - 1] == '"') {
                raw_val = raw_val[1 .. raw_val.len - 1];
            }

            inline for (@typeInfo(Config).Struct.fields) |field| {
                if (std.mem.eql(u8, key, field.name)) {
                    setFieldValue(self, field, raw_val);
                }
            }
        }
    }

    pub fn loadFromFile(self: *Config, allocator: std.mem.Allocator, path: []const u8) !void {
        if (std.mem.endsWith(u8, path, ".lua")) {
            return self.loadFromLua(allocator, path);
        }
        return self.loadFromToml(allocator, path);
    }

    pub fn setFieldValue(self: *Config, comptime field: std.builtin.Type.StructField, value: []const u8) void {
        switch (field.type) {
            bool => {
                const v = std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "yes") or std.mem.eql(u8, value, "1");
                @field(self, field.name) = v;
            },
            u32 => {
                @field(self, field.name) = std.fmt.parseInt(u32, value, 0) catch return;
            },
            u64 => {
                @field(self, field.name) = std.fmt.parseInt(u64, value, 0) catch return;
            },
            f64 => {
                @field(self, field.name) = std.fmt.parseFloat(f64, value) catch return;
            },
            []const u8 => {
                @field(self, field.name) = value;
            },
            OutputBase => {
                const v = std.meta.stringToEnum(OutputBase, value) orelse return;
                @field(self, field.name) = v;
            },
            else => {
                switch (@typeInfo(field.type)) {
                    .Enum => {
                        const v = std.meta.stringToEnum(field.type, value) orelse return;
                        @field(self, field.name) = v;
                    },
                    else => {},
                }
            },
        }
    }

    pub fn applyCliOverride(self: *Config, key: []const u8, value: []const u8) void {
        inline for (@typeInfo(Config).Struct.fields) |field| {
            if (std.mem.eql(u8, key, field.name)) {
                setFieldValue(self, field, value);
                return;
            }
        }
    }
};
