const std = @import("std");
const Config = @import("config.zig").Config;

const ESC = "\x1b";
const CSI = ESC ++ "[";

const CatDef = struct {
    name: []const u8,
    icon: []const u8,
    fields: []const []const u8,
    desc: []const u8,
};

const categories = [_]CatDef{
    .{ .name = "Input", .icon = "I", .fields = &.{ "input_mode", "angle_unit", "implicit_multiply", "function_syntax", "arg_separator", "decimal_separator", "digit_group", "auto_close_parens", "smart_completion" }, .desc = "Input mode, syntax, separators" },
    .{ .name = "Precision", .icon = "P", .fields = &.{ "significant_figures", "decimal_places", "use_sig_figs", "max_integer_digits", "fractional_format", "rounding", "output_base", "show_base_prefix" }, .desc = "Rounding, sig figs, output base" },
    .{ .name = "Display", .icon = "D", .fields = &.{ "result_format", "show_separators", "show_plus_sign", "color_enabled", "unicode_output", "unicode_fractions", "line_width", "result_lines", "show_ans_label", "show_expression", "show_result_banner", "show_time" }, .desc = "Colors, Unicode, layout" },
    .{ .name = "Behavior", .icon = "B", .fields = &.{ "auto_calc", "show_warnings", "confirm_exit", "error_beep", "key_click", "persistent_history", "history_size", "history_unique", "use_ans", "ans_on_empty", "strict_parsing", "allow_unknown_constants", "case_sensitive", "implicit_mult_precedence", "e_notation_always_scientific", "auto_repeat_operator", "wrap_at_boundary", "confirm_clear_history" }, .desc = "Auto-calc, exit confirm, warnings" },
    .{ .name = "Complex", .icon = "C", .fields = &.{ "complex_enabled", "complex_notation", "i_symbol", "show_real_zero", "polar_angle_unit" }, .desc = "Complex number settings" },
    .{ .name = "Keyboard", .icon = "K", .fields = &.{ "graph_trigger", "exit_key", "clear_key", "history_back", "history_forward", "ans_key", "graph_key", "unit_conv_key", "toggle_angle_key", "copy_key", "paste_key", "help_key", "clear_entry_key", "tab_complete" }, .desc = "Key bindings, shortcuts" },
    .{ .name = "Graph", .icon = "G", .fields = &.{ "graph_engine", "graph_width", "graph_height", "graph_x_min", "graph_x_max", "graph_y_min", "graph_y_max", "graph_auto_scale", "graph_show_axes", "graph_show_grid", "graph_show_legend", "graph_resolution", "graph_aspect_ratio", "graph_braille", "graph_color", "graph_multi_trace", "graph_x_label", "graph_y_label" }, .desc = "Graph engine, dimensions, colors" },
    .{ .name = "Functions", .icon = "F", .fields = &.{ "load_math_lib", "allow_user_functions", "allow_user_constants", "extra_functions" }, .desc = "Math lib, user functions" },
    .{ .name = "Units", .icon = "U", .fields = &.{ "unit_enabled", "unit_system", "unit_temperature", "unit_pressure", "unit_length", "unit_mass", "unit_volume", "unit_speed", "unit_energy", "unit_time", "unit_auto_convert", "unit_convert_on_enter", "unit_show_conversion" }, .desc = "Unit conversion defaults" },
    .{ .name = "History", .icon = "H", .fields = &.{ "history_enabled", "history_max_entries", "history_save_file", "history_save_on_exit", "history_load_on_start", "history_show_timestamps", "history_search_mode", "history_dedup", "history_persist_across_sessions" }, .desc = "History persistence, search" },
    .{ .name = "Matrix", .icon = "M", .fields = &.{ "matrix_enabled", "matrix_max_size", "matrix_brackets", "matrix_separator_rows", "matrix_align_columns", "matrix_auto_detect" }, .desc = "Matrix operations" },
    .{ .name = "Stats", .icon = "S", .fields = &.{ "stats_enabled", "stats_auto_regression", "stats_show_fitted", "stats_confidence_interval", "stats_max_data_points" }, .desc = "Statistics behavior" },
    .{ .name = "Advanced", .icon = "A", .fields = &.{ "recursion_limit", "evaluation_timeout_ms", "memory_limit_mb", "cache_expressions", "parallel_eval", "eval_mode", "log_level", "log_file" }, .desc = "Recursion limits, caching, eval" },
    .{ .name = "Custom", .icon = "*", .fields = &.{ "prompt_template", "prompt_color", "error_color", "warn_color", "result_color", "number_color", "highlight_color", "additions_path", "okugins_dir" }, .desc = "Prompt, error colors, templates" },
};

fn findFieldConfig(name: []const u8) ?std.builtin.Type.StructField {
    inline for (@typeInfo(Config).Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) return field;
    }
    return null;
}

fn formatFieldValue(cfg: *const Config, name: []const u8, buf: []u8) []const u8 {
    inline for (@typeInfo(Config).Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            const val = @field(cfg, field.name);
            switch (field.type) {
                bool => return if (val) "true" else "false",
                f64 => return std.fmt.bufPrint(buf, "{d}", .{val}) catch "?",
                u32 => return std.fmt.bufPrint(buf, "{d}", .{val}) catch "?",
                []const u8 => return if (val.len > 0) val else "(empty)",
                else => {
                    if (@typeInfo(field.type) == .Enum) return @tagName(val);
                    return std.fmt.bufPrint(buf, "{any}", .{val}) catch "?";
                },
            }
        }
    }
    return "?";
}

fn getFieldKind(name: []const u8) []const u8 {
    inline for (@typeInfo(Config).Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            return switch (field.type) {
                bool => "bool",
                f64 => "float",
                u32 => "int",
                []const u8 => "str",
                else => if (@typeInfo(field.type) == .Enum) "enum" else "?",
            };
        }
    }
    return "?";
}

fn getEnumValues(name: []const u8, out: []u8) []const u8 {
    inline for (@typeInfo(Config).Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            if (@typeInfo(field.type) == .Enum) {
                const info = @typeInfo(field.type).Enum;
                var pos: usize = 0;
                inline for (info.fields, 0..) |ef, j| {
                    if (j > 0) { if (pos < out.len) { out[pos] = ' '; pos += 1; } }
                    if (pos + ef.name.len <= out.len) {
                        @memcpy(out[pos..][0..ef.name.len], ef.name);
                        pos += ef.name.len;
                    }
                }
                return out[0..pos];
            }
        }
    }
    return "";
}

fn getNextEnumValue(name: []const u8, current: []const u8, dir: i8) []const u8 {
    inline for (@typeInfo(Config).Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            if (@typeInfo(field.type) == .Enum) {
                const info = @typeInfo(field.type).Enum;
                // Build runtime array of enum names
                var names: [32][]const u8 = undefined;
                var count: usize = 0;
                inline for (info.fields) |ef| {
                    names[count] = ef.name;
                    count += 1;
                }
                var idx: isize = -1;
                for (names[0..count], 0..) |n, i| {
                    if (std.mem.eql(u8, n, current)) {
                        idx = @as(isize, @intCast(i));
                        break;
                    }
                }
                if (idx < 0) return current;
                const n = count;
                const next_i = @mod(idx + @as(isize, @intCast(dir)), @as(isize, @intCast(n)));
                return names[@as(usize, @intCast(next_i))];
            }
        }
    }
    return current;
}

fn getFieldBool(cfg: *const Config, name: []const u8) bool {
    inline for (@typeInfo(Config).Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, name) and field.type == bool) {
            return @field(cfg, field.name);
        }
    }
    return false;
}

fn toggleFieldBool(cfg: *Config, name: []const u8) void {
    inline for (@typeInfo(Config).Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, name) and field.type == bool) {
            @field(cfg, field.name) = !@field(cfg, field.name);
        }
    }
}

fn setFieldStr(cfg: *Config, name: []const u8, value: []const u8) void {
    inline for (@typeInfo(Config).Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            Config.setFieldValue(cfg, field, value);
        }
    }
}

fn fieldDescription(name: []const u8) []const u8 {
    const descs = std.StaticStringMap([]const u8).initComptime(.{
        .{ "input_mode", "Input parsing mode" },
        .{ "angle_unit", "Default angle unit for trig functions" },
        .{ "implicit_multiply", "Allow 2x syntax" },
        .{ "function_syntax", "Function call style" },
        .{ "arg_separator", "Separator between function arguments" },
        .{ "decimal_separator", "Decimal point character" },
        .{ "digit_group", "Thousands separator style" },
        .{ "auto_close_parens", "Automatically close open parentheses" },
        .{ "smart_completion", "Tab-complete based on context" },
        .{ "significant_figures", "Number of significant digits" },
        .{ "decimal_places", "Fixed decimal places (0=auto)" },
        .{ "use_sig_figs", "Use significant figures instead of decimal places" },
        .{ "max_integer_digits", "Max integer digits before scientific notation" },
        .{ "fractional_format", "How to display fractions" },
        .{ "rounding", "Rounding mode" },
        .{ "output_base", "Numeric output base" },
        .{ "show_base_prefix", "Show 0b/0o/0x prefix" },
        .{ "result_format", "Number display format" },
        .{ "show_separators", "Show thousands separators" },
        .{ "show_plus_sign", "Show + prefix on positive numbers" },
        .{ "color_enabled", "Enable ANSI color output" },
        .{ "unicode_output", "Use Unicode symbols" },
        .{ "unicode_fractions", "Display fractions as Unicode" },
        .{ "line_width", "Maximum output line width" },
        .{ "result_lines", "Max lines for multi-line results" },
        .{ "show_ans_label", "Show '= ' prefix on results" },
        .{ "show_expression", "Echo back the expression before result" },
        .{ "show_result_banner", "Show a banner before results" },
        .{ "show_time", "Show evaluation time" },
        .{ "auto_calc", "Automatically evaluate on enter" },
        .{ "show_warnings", "Display warning messages" },
        .{ "confirm_exit", "Ask before exiting" },
        .{ "error_beep", "Beep on error" },
        .{ "key_click", "Click sound on keypress" },
        .{ "persistent_history", "Save history between sessions" },
        .{ "history_size", "Number of entries to keep" },
        .{ "history_unique", "Don't store duplicate entries" },
        .{ "use_ans", "Use 'ans' variable for last result" },
        .{ "ans_on_empty", "Re-display ans on empty input" },
        .{ "strict_parsing", "Enable strict parsing mode" },
        .{ "allow_unknown_constants", "Warn instead of error on unknown names" },
        .{ "case_sensitive", "Distinguish upper/lower case" },
        .{ "implicit_mult_precedence", "Precedence of implicit multiplication" },
        .{ "e_notation_always_scientific", "Always show e-notation as scientific" },
        .{ "auto_repeat_operator", "Repeat last operator on empty input" },
        .{ "wrap_at_boundary", "Wrap output at word boundaries" },
        .{ "confirm_clear_history", "Confirm before clearing history" },
        .{ "complex_enabled", "Enable complex number support" },
        .{ "complex_notation", "Complex output format" },
        .{ "i_symbol", "Symbol for imaginary unit" },
        .{ "show_real_zero", "Show 0 real part for pure imaginary" },
        .{ "polar_angle_unit", "Angle unit for polar complex form" },
        .{ "graph_trigger", "When to trigger auto-graph" },
        .{ "exit_key", "Key binding for exit" },
        .{ "clear_key", "Key binding for clear screen" },
        .{ "history_back", "Key binding for history back" },
        .{ "history_forward", "Key binding for history forward" },
        .{ "ans_key", "Key binding for ans" },
        .{ "graph_key", "Key binding for graph" },
        .{ "unit_conv_key", "Key binding for unit conversion" },
        .{ "toggle_angle_key", "Key binding for angle toggle" },
        .{ "copy_key", "Key binding for copy" },
        .{ "paste_key", "Key binding for paste" },
        .{ "help_key", "Key binding for help" },
        .{ "clear_entry_key", "Key binding to clear current entry" },
        .{ "tab_complete", "Enable tab completion" },
        .{ "graph_engine", "Graph rendering engine" },
        .{ "graph_width", "Character width of graph" },
        .{ "graph_height", "Character height of graph" },
        .{ "graph_x_min", "Minimum X axis value" },
        .{ "graph_x_max", "Maximum X axis value" },
        .{ "graph_y_min", "Minimum Y axis value" },
        .{ "graph_y_max", "Maximum Y axis value" },
        .{ "graph_auto_scale", "Auto-scale Y axis to fit data" },
        .{ "graph_show_axes", "Show X/Y axes" },
        .{ "graph_show_grid", "Show grid lines" },
        .{ "graph_show_legend", "Show trace legend" },
        .{ "graph_resolution", "Number of evaluation points" },
        .{ "graph_aspect_ratio", "Aspect ratio for graph" },
        .{ "graph_braille", "Use braille dots" },
        .{ "graph_color", "Colorize graph traces" },
        .{ "graph_multi_trace", "Allow multiple traces" },
        .{ "graph_x_label", "X axis label" },
        .{ "graph_y_label", "Y axis label" },
        .{ "load_math_lib", "Load built-in math library" },
        .{ "allow_user_functions", "Allow user-defined functions" },
        .{ "allow_user_constants", "Allow user-defined constants" },
        .{ "extra_functions", "Extra function modules to load" },
        .{ "unit_enabled", "Enable unit conversion" },
        .{ "unit_system", "Preferred unit system" },
        .{ "unit_temperature", "Default temperature unit" },
        .{ "unit_pressure", "Default pressure unit" },
        .{ "unit_length", "Default length unit" },
        .{ "unit_mass", "Default mass unit" },
        .{ "unit_volume", "Default volume unit" },
        .{ "unit_speed", "Default speed unit" },
        .{ "unit_energy", "Default energy unit" },
        .{ "unit_time", "Default time unit" },
        .{ "unit_auto_convert", "Auto-convert to default units" },
        .{ "unit_convert_on_enter", "Convert on enter key" },
        .{ "unit_show_conversion", "Show conversion result" },
        .{ "history_enabled", "Enable history tracking" },
        .{ "history_max_entries", "Maximum history entries" },
        .{ "history_save_file", "History file path" },
        .{ "history_save_on_exit", "Save history on exit" },
        .{ "history_load_on_start", "Load history on startup" },
        .{ "history_show_timestamps", "Show timestamps in history" },
        .{ "history_search_mode", "History search algorithm" },
        .{ "history_dedup", "Deduplicate history entries" },
        .{ "history_persist_across_sessions", "Keep history across sessions" },
        .{ "matrix_enabled", "Enable matrix operations" },
        .{ "matrix_max_size", "Maximum matrix dimensions" },
        .{ "matrix_brackets", "Matrix bracket style" },
        .{ "matrix_separator_rows", "Separate matrix rows visually" },
        .{ "matrix_align_columns", "Align matrix columns" },
        .{ "matrix_auto_detect", "Auto-detect matrix input" },
        .{ "stats_enabled", "Enable statistics" },
        .{ "stats_auto_regression", "Auto-calculate regression" },
        .{ "stats_show_fitted", "Show fitted values" },
        .{ "stats_confidence_interval", "Confidence interval level" },
        .{ "stats_max_data_points", "Maximum data points" },
        .{ "recursion_limit", "Maximum recursion depth" },
        .{ "evaluation_timeout_ms", "Expression evaluation timeout (ms)" },
        .{ "memory_limit_mb", "Memory limit in MB" },
        .{ "cache_expressions", "Cache compiled expressions" },
        .{ "parallel_eval", "Evaluate independent sub-expressions in parallel" },
        .{ "eval_mode", "Evaluation mode" },
        .{ "log_level", "Logging level" },
        .{ "log_file", "Log file path" },
        .{ "prompt_template", "Prompt string" },
        .{ "prompt_color", "Prompt color" },
        .{ "error_color", "Error message color" },
        .{ "warn_color", "Warning message color" },
        .{ "result_color", "Result color" },
        .{ "number_color", "Number color" },
        .{ "highlight_color", "Highlight color" },
        .{ "additions_path", "Path to additions file" },
        .{ "okugins_dir", "Directory for okugin plugins" },
    });
    return descs.get(name) orelse "No description";
}

fn readKey(reader: std.io.AnyReader) !u16 {
    var buf: [1]u8 = undefined;
    const n = reader.read(&buf) catch return 0;
    if (n == 0) return 0;
    const c = buf[0];
    if (c == 0x1b) {
        var seq: [4]u8 = undefined;
        if ((reader.read(seq[0..1]) catch return 0x1b) == 0) return 0x1b;
        if (seq[0] == '[') {
            if ((reader.read(seq[1..2]) catch return 0x1b) == 0) return 0x1b;
            switch (seq[1]) {
                'A' => return 0x101, 'B' => return 0x102, 'C' => return 0x103, 'D' => return 0x104,
                'H' => return 0x105, 'F' => return 0x106,
                else => {},
            }
            if (seq[1] == '5' and (reader.read(seq[2..3]) catch return 0x1b) > 0 and seq[2] == '~') return 0x107;
            if (seq[1] == '6' and (reader.read(seq[2..3]) catch return 0x1b) > 0 and seq[2] == '~') return 0x108;
            return 0x1b;
        }
        _ = reader.read(seq[1..2]) catch return 0x1b;
        return 0x1b;
    }
    return c;
}

pub fn runConfigTui(cfg: *Config, path: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader().any();

    var cat_idx: usize = 0;
    var opt_idx: usize = 0;
    var status_msg: []const u8 = "↑↓ arrows | Enter: toggle/edit | Tab: cycle cat | Esc: quit | s: save & quit | r: reset";
    var dirty = false;

    try stdout.writeAll(CSI ++ "?1049h" ++ CSI ++ "?25l");
    defer {
        stdout.writeAll(CSI ++ "?25h") catch {};
        stdout.writeAll(CSI ++ "?1049l") catch {};
    }

    main_loop: while (true) {
        try stdout.writeAll(CSI ++ "2J" ++ CSI ++ "H");

        try stdout.print(CSI ++ "44;37m" ++ "╔══ XNC Config ════════════════════════════════", .{});
        for (0..24) |_| try stdout.writeAll("═");
        try stdout.writeAll("╗" ++ CSI ++ "0m\n");

        for (categories, 0..) |cat, ci| {
            if (ci == cat_idx) {
                try stdout.print(CSI ++ "7m", .{});
            } else {
                try stdout.print(CSI ++ "37;40m", .{});
            }
            try stdout.print(" {s} ", .{cat.name});
        }
        try stdout.writeAll(CSI ++ "0m\n");

        try stdout.writeAll(CSI ++ "34m" ++ "╠═══════════════════════════════════════════════════╣" ++ CSI ++ "0m\n");

        const cat = categories[cat_idx];
        const fields = cat.fields;
        var buf: [128]u8 = undefined;

        var scroll: usize = 0;
        const max_rows = 17;
        if (opt_idx >= max_rows) scroll = opt_idx - max_rows + 1;

        var row: usize = 0;
        for (fields, 0..) |fname, fi| {
            if (fi < scroll) continue;
            if (row >= max_rows) {
                try stdout.print(CSI ++ "37m  ... {d} more" ++ CSI ++ "K\n", .{fields.len - fi});
                row += 1;
                continue;
            }
            row += 1;

            const val = formatFieldValue(cfg, fname, &buf);
            const sel = fi == opt_idx;

            if (sel) try stdout.writeAll(CSI ++ "33;1m") else try stdout.writeAll(CSI ++ "37m");
            try stdout.writeAll(if (sel) " > " else "   ");

            if (fname.len > 27) {
                try stdout.writeAll(fname[0..27]);
            } else {
                try stdout.writeAll(fname);
                try stdout.writeAll(CSI ++ "K");
                for (0..@as(usize, @intCast(@max(0, 27 - fname.len)))) |_| try stdout.writeByte(' ');
            }
            try stdout.writeAll(" ");

            if (sel) try stdout.writeAll(CSI ++ "32;1m") else try stdout.writeAll(CSI ++ "36m");
            const kind = getFieldKind(fname);
            if (std.mem.eql(u8, kind, "bool")) {
                const on = getFieldBool(cfg, fname);
                if (on) {
                    try stdout.writeAll(CSI ++ "32m✓ ON ");
                } else {
                    try stdout.writeAll(CSI ++ "31m✗ OFF");
                }
            } else if (std.mem.eql(u8, kind, "enum")) {
                const display_val = if (val.len > 22) val[0..22] else val;
                try stdout.print(CSI ++ "35m{s}" ++ CSI ++ "K", .{display_val});
            } else {
                const display_val = if (val.len > 24) val[0..24] else val;
                try stdout.print(CSI ++ "37m{s}" ++ CSI ++ "K", .{display_val});
            }
            try stdout.writeAll(CSI ++ "0m");
            try stdout.writeAll(CSI ++ "K\n");
        }

        for (row..max_rows) |_| {
            try stdout.writeAll(CSI ++ "K\n");
        }

        try stdout.writeAll(CSI ++ "34m" ++ "╠═══════════════════════════════════════════════════╣" ++ CSI ++ "0m\n");
        const sel_name = fields[opt_idx];
        const desc = fieldDescription(sel_name);
        const kind = getFieldKind(sel_name);
        try stdout.print(CSI ++ "37m  {s} ", .{desc});
        if (std.mem.eql(u8, kind, "enum")) {
            var enum_buf: [128]u8 = undefined;
            const vals = getEnumValues(sel_name, &enum_buf);
            if (vals.len > 0) {
                try stdout.print(CSI ++ "33m[{s}]" ++ CSI ++ "K", .{vals});
            }
        }
        try stdout.writeAll(CSI ++ "K\n");

        try stdout.print(CSI ++ "44;37m  {s}" ++ CSI ++ "K", .{status_msg});
        try stdout.writeAll(CSI ++ "0m\n");

        try stdout.writeAll(CSI ++ "?25h");

        const key = readKey(stdin) catch 0;
        try stdout.writeAll(CSI ++ "?25l");

        switch (key) {
            0x1b, 'q' => break :main_loop,
            's' => {
                if (path.len > 0) {
                    cfg.generateTomlConfig(path) catch {
                        status_msg = "Failed to save config!";
                        continue;
                    };
                    status_msg = "Config saved!";
                } else {
                    status_msg = "No config path set";
                }
                dirty = false;
            },
            0x101 => { if (opt_idx > 0) opt_idx -= 1; }, // Up
            0x102 => { if (opt_idx + 1 < fields.len) opt_idx += 1; }, // Down
            0x104, 'h' => { // Left / prev cat
                if (cat_idx > 0) { cat_idx -= 1; opt_idx = 0; }
            },
            0x103, 'l', '\t' => { // Right / Tab / next cat
                cat_idx = (cat_idx + 1) % categories.len;
                opt_idx = 0;
            },
            0x105 => opt_idx = 0, // Home
            0x106 => opt_idx = fields.len - 1, // End
            0x107 => { if (scroll > 0) scroll -= 1; }, // PgUp
            0x108 => { scroll += 1; }, // PgDn
            '\r', '\n', ' ' => { // Enter / Space - edit
                const edit_name = fields[opt_idx];
                const edit_kind = getFieldKind(edit_name);
                if (std.mem.eql(u8, edit_kind, "bool")) {
                    toggleFieldBool(cfg, edit_name);
                    dirty = true;
                    status_msg = "Toggled!";
                } else if (std.mem.eql(u8, edit_kind, "enum")) {
                    const edit_val = formatFieldValue(cfg, edit_name, &buf);
                    const next = getNextEnumValue(edit_name, edit_val, 1);
                    setFieldStr(cfg, edit_name, next);
                    dirty = true;
                    status_msg = "Cycled!";
                } else {
                    try editField(cfg, edit_name, stdin, stdout.any());
                    dirty = true;
                    status_msg = "Updated!";
                }
            },
            'r' => { status_msg = "Reset config to defaults (not implemented)"; },
            else => {},
        }
    }

    if (dirty and path.len > 0) {
        cfg.generateTomlConfig(path) catch {};
    }
}

fn editField(cfg: *Config, name: []const u8, reader: std.io.AnyReader, writer: std.io.AnyWriter) !void {
    var buf: [256]u8 = undefined;
    const current = formatFieldValue(cfg, name, &buf);
    const desc = fieldDescription(name);

    var input = std.ArrayList(u8).init(std.heap.page_allocator);
    defer input.deinit();
    try input.appendSlice(current);

    try writer.writeAll(CSI ++ "2K\r");
    try writer.print(CSI ++ "33m {s}: ", .{desc});

    try writer.writeAll(CSI ++ "?25h");

    while (true) {
        try writer.print(CSI ++ "K{s}", .{input.items});
        const key = readKey(reader) catch 0;
        switch (key) {
            0x1b, '\r', '\n' => break,
            0x7f, 0x08 => {
                if (input.items.len > 0) {
                    input.items.len -= 1;
                }
            },
            else => {
                if (key >= 0x20 and key <= 0x7e) {
                    try input.append(@as(u8, @intCast(key)));
                }
            },
        }
    }

    try writer.writeAll(CSI ++ "?25l");
    try writer.writeAll(CSI ++ "2K\r");

    const new_val = if (input.items.len > 0) input.items else current;
    setFieldStr(cfg, name, new_val);

    try writer.print(CSI ++ "32m ✓ {s} = {s}" ++ CSI ++ "K\n", .{ name, new_val });
}
