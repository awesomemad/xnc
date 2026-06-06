const std = @import("std");
const config = @import("config.zig");
const number = @import("number.zig");
const parser = @import("parser.zig");
const functions = @import("functions.zig");
const display = @import("display.zig");
const history = @import("history.zig");
const keybind = @import("keybind.zig");
const units = @import("units.zig");
const matrix = @import("matrix.zig");
const stats = @import("stats.zig");
const graph = @import("graph.zig");
const additions = @import("additions.zig");
const okugin = @import("okugin.zig");
const tui_edit = @import("config_tui.zig");

const Number = number.Number;
const Config = config.Config;
const Display = display.Display;
const History = history.History;
const FunctionTable = functions.FunctionTable;
const KeyBindings = keybind.KeyBindings;
const Parser = parser.Expr;
const UnitConverter = units.UnitConverter;
const Matrix = matrix.Matrix;
const Graph = graph.Graph;
const DataSet = stats.DataSet;
const Additions = additions.Additions;
const OkuginRegistry = okugin.OkuginRegistry;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var cfg = Config.init(allocator);
    defer cfg.deinit();

    const config_path = findConfigPath(allocator) catch null;
    if (config_path) |path| {
        cfg.loadFromFile(allocator, path) catch {};
        allocator.free(path);
    }

    applyCliOverrides(&cfg) catch {};

    var funcs = FunctionTable.init(allocator);
    defer funcs.deinit();

    var constants = std.StringHashMap(Number).init(allocator);
    defer constants.deinit();

    var variables = std.StringHashMap(Number).init(allocator);
    defer variables.deinit();

    var additions_inst = Additions.init(allocator);
    defer additions_inst.deinit();
    if (cfg.additions_path.len > 0) {
        const expanded = try expandHome(cfg.additions_path, allocator);
        defer allocator.free(expanded);
        additions_inst.loadFromFile(expanded) catch {};
    }

    var okugin_reg = OkuginRegistry.init(allocator);
    defer okugin_reg.deinit();
    if (cfg.okugins_dir.len > 0) {
        const expanded = try expandHome(cfg.okugins_dir, allocator);
        defer allocator.free(expanded);
        okugin_reg.scanDirectory(expanded) catch {};
    }

    var history_inst = History.init(allocator, &cfg);
    defer history_inst.deinit();

    var keys = KeyBindings.init(allocator);
    defer keys.deinit();

    var converter = UnitConverter.init(allocator);
    defer converter.deinit();

    var graf = Graph.init(allocator, &cfg, &funcs);
    defer graf.deinit();

    var data_set = DataSet.init(allocator);
    defer data_set.deinit();

    var display_inst = Display.init(&cfg, std.io.getStdOut().writer().any());
    var line_editor = keybind.LineEditor.init(allocator);
    defer line_editor.deinit();

    display_inst.welcome();

    if (cfg.history_load_on_start and cfg.persistent_history) {
        display_inst.info("History loaded");
    }

    var ans = Number.zero;
    var prev = Number.zero;
    var running: bool = true;
    const in_data_entry: bool = false;

    while (running) {
        display_inst.prompt();

        const line = readLine(allocator, std.io.getStdIn().reader().any()) catch |err| {
            if (err == error.EndOfStream) break;
            display_inst.showError("Input error");
            continue;
        };
        defer allocator.free(line);

        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) {
            if (cfg.ans_on_empty and cfg.use_ans and !ans.isZero()) {
                const ans_str = ans.formatNum(&cfg, allocator) catch continue;
                defer allocator.free(ans_str);
                display_inst.result("ans = ", ans_str);
            }
            continue;
        }

        try history_inst.push(trimmed);

        if (handleCommand(trimmed, &display_inst, &cfg, &history_inst, &converter, &graf, &data_set, &variables, &line_editor, &running, &ans, &additions_inst, &okugin_reg)) {
            continue;
        }

        const first_word_end = std.mem.indexOfScalar(u8, trimmed, ' ') orelse trimmed.len;
        const maybe_cmd = trimmed[0..first_word_end];
        if (maybe_cmd.len > 0 and std.mem.indexOfScalar(u8, "abcdefghijklmnopqrstuvwxyz_", maybe_cmd[0]) != null) {
            if (maybe_cmd.len > 1) suggestCommand(&display_inst, maybe_cmd);
        }

        if (in_data_entry) {
            const val = std.fmt.parseFloat(f64, trimmed) catch {
                display_inst.showError("Expected a number for data entry");
                continue;
            };
            try data_set.addValue(val);

            if (cfg.stats_auto_regression and data_set.count() >= 2) {
                const stats_str = try data_set.formatStats(allocator);
                defer allocator.free(stats_str);
                display_inst.writeLine(stats_str);
            } else {
                var buf: [128]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "Data point {d}: {d:.6}", .{ data_set.count(), val }) catch "data";
                display_inst.info(msg);
            }
            continue;
        }

        var parse_ctx = Parser.initFull(allocator, trimmed, &cfg, &funcs, &constants, &variables, &additions_inst, &okugin_reg) catch {
            display_inst.showError("Parse error");
            continue;
        };
        defer parse_ctx.deinit();

        const result = parse_ctx.parse() catch |err| {
            display_inst.showError(switch (err) {
                error.UnknownIdentifier => "Hmm, I don't know that name. Use 'additions' to add custom functions or constants, or 'vars' to see defined variables.",
                error.UnknownFunction => "Unknown function — type 'help' for the full list of built-in functions.",
                error.WrongArgCount => "Wrong number of arguments — check the function's expected arguments.",
                error.UnexpectedToken => "Unexpected token — check your syntax (missing operator or parenthesis?).",
                error.DivisionByZero => "Can't divide by zero!",
                else => "Something went wrong evaluating that expression.",
            });
            continue;
        };

        prev = ans;
        ans = result;
        try variables.put("__ans__", result);
        try variables.put("prev", prev);

        if (cfg.show_expression) {
            display_inst.info(trimmed);
        }

        const result_str = result.formatNum(&cfg, allocator) catch {
            display_inst.showError("Format error");
            continue;
        };
        defer allocator.free(result_str);
        display_inst.result("= ", result_str);

        if (result.isNaN()) {
            display_inst.warning("Result is NaN");
        }
        if (result.isInf()) {
            display_inst.warning("Result is infinite");
        }

    }

    display_inst.writeLine("Goodbye!");
}

fn readLine(allocator: std.mem.Allocator, reader: std.io.AnyReader) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const writer = buf.writer();
    reader.streamUntilDelimiter(writer, '\n', 65536) catch |err| {
        if (err == error.EndOfStream and buf.items.len > 0) {
            const result = try buf.toOwnedSlice();
            return result;
        }
        return err;
    };
    const line = try buf.toOwnedSlice();
    const trimmed = std.mem.trimRight(u8, line, "\r");
    return allocator.dupe(u8, trimmed);
}

fn handleCommand(line: []const u8, display_inst: *Display, cfg: *Config, history_inst: *History, converter: *UnitConverter, graf: *Graph, data_set: *DataSet, variables: *std.StringHashMap(Number), _: *keybind.LineEditor, running: *bool, ans: *Number, additions_inst: *Additions, okugin_reg: *OkuginRegistry) bool {
    const first_word_end = std.mem.indexOfScalar(u8, line, ' ') orelse line.len;
    const cmd = line[0..first_word_end];
    const rest = std.mem.trimLeft(u8, line[first_word_end..], " ");

    if (std.mem.eql(u8, cmd, "exit") or std.mem.eql(u8, cmd, "quit")) {
        if (cfg.confirm_exit) {
            display_inst.writeLine("Type 'exit' again to confirm, or 'cancel' to cancel.");
            display_inst.prompt();
            const confirm = readLine(std.heap.page_allocator, std.io.getStdIn().reader().any()) catch return true;
            defer std.heap.page_allocator.free(confirm);
            const trimmed = std.mem.trim(u8, confirm, " \t\r\n");
            if (!std.mem.eql(u8, trimmed, "exit") and !std.mem.eql(u8, trimmed, "quit") and !std.mem.eql(u8, trimmed, "y") and !std.mem.eql(u8, trimmed, "yes")) {
                return true;
            }
        }
        running.* = false;
        return true;
    }

    if (std.mem.eql(u8, cmd, "help")) {
        const topic = if (rest.len > 0) rest else null;
        display_inst.showHelp(topic);
        return true;
    }

    if (std.mem.eql(u8, cmd, "clear") or std.mem.eql(u8, cmd, "cls")) {
        display_inst.clear();
        return true;
    }

    if (std.mem.eql(u8, cmd, "history") or std.mem.eql(u8, cmd, "hist")) {
        const entries = history_inst.getEntries();
        display_inst.showHistory(entries);
        return true;
    }

    if (std.mem.eql(u8, cmd, "config")) {
        if (std.mem.eql(u8, rest, "show") or std.mem.eql(u8, rest, "list")) {
            display_inst.showConfig(cfg);
            return true;
        }
        if (std.mem.eql(u8, rest, "gen") or std.mem.eql(u8, rest, "generate")) {
            cfg.generateTomlConfig("xnc.toml") catch {
                display_inst.showError("Failed to generate config file");
                return true;
            };
            display_inst.info("Config file generated (xnc.toml)");
            return true;
        }
        display_inst.info("Opening config editor...");
        tui_edit.runConfigTui(cfg, "xnc.toml") catch {
            display_inst.showError("Config editor failed");
            return true;
        };
        return true;
    }

    if (std.mem.eql(u8, cmd, "config-gen") or std.mem.eql(u8, cmd, "genconfig")) {
        cfg.generateTomlConfig("xnc.toml") catch {
            display_inst.showError("Failed to generate config file");
            return true;
        };
        display_inst.info("Config file generated (xnc.toml)");
        return true;
    }

    if (std.mem.eql(u8, cmd, "config-tui") or std.mem.eql(u8, cmd, "tui")) {
        display_inst.info("Tip: use 'config' to open the editor now (config-tui is the old name)");
        tui_edit.runConfigTui(cfg, "xnc.toml") catch {
            display_inst.showError("Config editor failed");
            return true;
        };
        return true;
    }

    if (std.mem.eql(u8, cmd, "additions")) {
        const parts = rest;
        if (std.mem.startsWith(u8, parts, "add-fn ") or std.mem.startsWith(u8, parts, "addfunc ")) {
            const after = parts[7..];
            const eq_pos = std.mem.indexOfScalar(u8, after, '=') orelse {
                display_inst.showError("Usage: additions add-fn <name> = <expression>");
                return true;
            };
            const fname = std.mem.trim(u8, after[0..eq_pos], " ");
            const fexpr = std.mem.trim(u8, after[eq_pos + 1 ..], " ");
            additions_inst.addFunction(fname, fexpr) catch {
                display_inst.showError("Failed to add function");
                return true;
            };
            if (cfg.additions_path.len > 0) {
                const save_path = expandHome(cfg.additions_path, std.heap.page_allocator) catch {
                    display_inst.showError("Failed to resolve additions path");
                    return true;
                };
                defer std.heap.page_allocator.free(save_path);
                additions_inst.saveToFile(save_path) catch {};
            }
            display_inst.info("Function added");
            return true;
        }
        if (std.mem.startsWith(u8, parts, "add-const ") or std.mem.startsWith(u8, parts, "addconst ")) {
            const after = parts[9..];
            const eq_pos = std.mem.indexOfScalar(u8, after, '=') orelse {
                display_inst.showError("Usage: additions add-const <name> = <value>");
                return true;
            };
            const cname = std.mem.trim(u8, after[0..eq_pos], " ");
            const cvalue = std.fmt.parseFloat(f64, std.mem.trim(u8, after[eq_pos + 1 ..], " ")) catch {
                display_inst.showError("Invalid number");
                return true;
            };
            additions_inst.addConstant(cname, cvalue) catch {
                display_inst.showError("Failed to add constant");
                return true;
            };
            if (cfg.additions_path.len > 0) {
                const save_path = expandHome(cfg.additions_path, std.heap.page_allocator) catch {
                    display_inst.showError("Failed to resolve additions path");
                    return true;
                };
                defer std.heap.page_allocator.free(save_path);
                additions_inst.saveToFile(save_path) catch {};
            }
            display_inst.info("Constant added");
            return true;
        }
        if (std.mem.eql(u8, parts, "") or std.mem.eql(u8, parts, "list")) {
            const list = additions_inst.list();
            display_inst.writeLine("=== Additions ===");
            display_inst.writeLine("Functions:");
            for (list.functions) |f| {
                display_inst.writeLine(f);
            }
            display_inst.writeLine("Constants:");
            for (list.constants) |c| {
                display_inst.writeLine(c);
            }
            return true;
        }
        display_inst.info("Usage: additions list | add-fn <name> = <expr> | add-const <name> = <value>");
        return true;
    }

    if (std.mem.eql(u8, cmd, "okugin")) {
        const parts = rest;
        if (std.mem.eql(u8, parts, "list") or std.mem.eql(u8, parts, "")) {
            const plugins = okugin_reg.list();
            display_inst.writeLine("=== Okugins ===");
            if (plugins.len == 0) {
                display_inst.writeLine("No plugins found");
            } else {
                for (plugins) |p| {
                    display_inst.writeLine(std.fmt.allocPrint(std.heap.page_allocator, "{s} v{s} by {s} - {s} ({s})", .{ p.name, p.version, p.author, p.description, @tagName(p.plugin_type) }) catch "plugin");
                }
            }
            return true;
        }
        display_inst.info("Usage: okugin list");
        return true;
    }

    if (std.mem.eql(u8, cmd, "vars") or std.mem.eql(u8, cmd, "variables")) {
        display_inst.showVars(variables);
        return true;
    }

    if (std.mem.eql(u8, cmd, "mode")) {
        display_inst.showMode(cfg);
        return true;
    }

    if (std.mem.eql(u8, cmd, "angle") or std.mem.eql(u8, cmd, "toggle-angle")) {
        cfg.angle_unit = switch (cfg.angle_unit) {
            .degrees => config.AngleUnit.radians,
            .radians => config.AngleUnit.grads,
            .grads => config.AngleUnit.degrees,
        };
        display_inst.info(std.fmt.allocPrint(std.heap.page_allocator, "Angle unit: {s}", .{@tagName(cfg.angle_unit)}) catch "Angle switched");
        return true;
    }

    if (std.mem.eql(u8, cmd, "graph") or std.mem.eql(u8, cmd, "plot")) {
        if (rest.len == 0) {
            graf.evaluateTraces();
            const graph_str = graf.render() catch {
                display_inst.showError("Graph error");
                return true;
            };
            defer std.heap.page_allocator.free(graph_str);
            display_inst.writeLine(graph_str);
        } else {
            graf.addTrace(rest) catch {};
            graf.clear();
            graf.addTrace(rest) catch {};
            graf.evaluateTraces();
            const graph_str = graf.render() catch {
                display_inst.showError("Graph error");
                return true;
            };
            defer std.heap.page_allocator.free(graph_str);
            display_inst.writeLine(graph_str);
        }
        return true;
    }

    if (std.mem.eql(u8, cmd, "unit") or std.mem.eql(u8, cmd, "conv") or std.mem.eql(u8, cmd, "convert")) {
        if (rest.len == 0) {
            display_inst.showError("Usage: unit <value> <from> <to>  e.g. unit 100 km mi");
            return true;
        }

        var parts = std.mem.splitScalar(u8, rest, ' ');
        const val_str = parts.next() orelse {
            display_inst.showError("Missing value");
            return true;
        };
        const from_str = parts.next() orelse {
            display_inst.showError("Missing 'from' unit");
            return true;
        };
        const to_str = parts.next() orelse {
            display_inst.showError("Missing 'to' unit");
            return true;
        };

        const val = std.fmt.parseFloat(f64, val_str) catch {
            display_inst.showError("Invalid number");
            return true;
        };

        const result = converter.convert(val, from_str, to_str) catch {
            display_inst.showError("Conversion error");
            return true;
        };
        const result_str = converter.formatResult(result) catch {
            display_inst.showError("Format error");
            return true;
        };
        defer std.heap.page_allocator.free(result_str);
        display_inst.result("", result_str);
        return true;
    }

    if (std.mem.eql(u8, cmd, "data") or std.mem.eql(u8, cmd, "stats")) {
        if (std.mem.eql(u8, rest, "clear")) {
            data_set.clear();
            display_inst.info("Data cleared");
            return true;
        }
        if (std.mem.eql(u8, rest, "show")) {
            if (data_set.count() == 0) {
                display_inst.info("No data points yet. Add some with: data <value>");
                return true;
            }
            const stats_str = data_set.formatStats(std.heap.page_allocator) catch return true;
            defer std.heap.page_allocator.free(stats_str);
            display_inst.writeLine(stats_str);
            return true;
        }
        if (rest.len > 0) {
            const val = std.fmt.parseFloat(f64, rest) catch {
                display_inst.info("Usage: data <value> | stats show | stats clear");
                return true;
            };
            data_set.addValue(val) catch {
                display_inst.showError("Failed to add data point");
                return true;
            };
            var buf: [128]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Data point {d}: {d:.6}", .{ data_set.count(), val }) catch "data";
            display_inst.info(msg);
            return true;
        }
        display_inst.info("Usage: data <value> | stats show | stats clear");
        return true;
    }

    if (std.mem.eql(u8, cmd, "set")) {
        if (std.mem.indexOfScalar(u8, rest, '=')) |eq_pos| {
            const key = std.mem.trim(u8, rest[0..eq_pos], " ");
            const value = std.mem.trim(u8, rest[eq_pos + 1 ..], " ");
            cfg.applyCliOverride(key, value);
            display_inst.info("Config updated");
        } else {
            display_inst.showError("Usage: set <key> = <value>");
        }
        return true;
    }

    if (std.mem.eql(u8, cmd, "reset")) {
        cfg.* = Config.init(std.heap.page_allocator);
        display_inst.info("Config reset to defaults");
        return true;
    }

    if (std.mem.eql(u8, cmd, "ans")) {
        const ans_str = ans.formatNum(cfg, std.heap.page_allocator) catch return true;
        defer std.heap.page_allocator.free(ans_str);
        display_inst.result("ans = ", ans_str);
        return true;
    }

    return false;
}

fn suggestCommand(display_inst: *Display, cmd: []const u8) void {
    const suggestions = [_][2][]const u8{
        .{ "config", "config-gen" },
        .{ "config", "config-tui" },
        .{ "addition", "additions" },
        .{ "addtion", "additions" },
        .{ "addition", "additions" },
        .{ "okugins", "okugin" },
        .{ "oku", "okugin" },
        .{ "plug", "okugin" },
        .{ "plugin", "okugin" },
        .{ "hist", "history" },
        .{ "vari", "vars" },
        .{ "variable", "vars" },
        .{ "conv", "unit" },
        .{ "convert", "unit" },
        .{ "plot", "graph" },
        .{ "set", "set <key> = <value>" },
    };
    for (suggestions) |s| {
        if (std.mem.startsWith(u8, cmd, s[0])) {
            display_inst.info(std.fmt.allocPrint(std.heap.page_allocator, "Did you mean '{s}'? Type 'help' for all commands.", .{s[1]}) catch "Type 'help' for commands.");
            return;
        }
    }
}

fn findConfigPath(allocator: std.mem.Allocator) ![]u8 {
    const candidates = [_][]const u8{
        "xnc.toml",
        "xnc.conf",
        ".xnc.toml",
    };

    for (candidates) |candidate| {
        if (std.fs.cwd().access(candidate, .{})) {
            return allocator.dupe(u8, candidate);
        } else |_| {}
    }

    {
        var env_map = std.process.getEnvMap(allocator) catch {
            return error.FileNotFound;
        };
        defer env_map.deinit();
        if (env_map.get("XNC_CONFIG")) |env_path| {
            const accessible = if (std.fs.path.isAbsolute(env_path))
                std.fs.accessAbsolute(env_path, .{})
            else
                std.fs.cwd().access(env_path, .{});
            if (accessible) {
                return allocator.dupe(u8, env_path);
            } else |_| {}
        }
    }

    return error.FileNotFound;
}

fn applyCliOverrides(cfg: *Config) !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        const is_long = std.mem.startsWith(u8, arg, "--");
        const is_short = std.mem.startsWith(u8, arg, "-") and !is_long;
        if (is_long or is_short) {
            const key_start: usize = if (is_long) @as(usize, 2) else @as(usize, 1);
            var key: []const u8 = arg[key_start..];

            if (std.mem.indexOfScalar(u8, key, '=')) |eq_pos| {
                const k = key[0..eq_pos];
                const v = key[eq_pos + 1 ..];
                cfg.applyCliOverride(k, v);
            } else if (i + 1 < args.len) {
                i += 1;
                cfg.applyCliOverride(key, args[i]);
            }
        }
    }
}

fn expandHome(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    if (!std.mem.startsWith(u8, path, "~/")) return allocator.dupe(u8, path);
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();
    const home = env_map.get("HOME") orelse env_map.get("USERPROFILE") orelse return allocator.dupe(u8, path);
    return std.fs.path.join(allocator, &[_][]const u8{ home, path[2..] });
}

test "number basic arithmetic" {
    const a = Number.init(5.0);
    const b = Number.init(3.0);
    try std.testing.expectEqual(@as(f64, 8.0), a.add(b).real);
    try std.testing.expectEqual(@as(f64, 2.0), a.sub(b).real);
    try std.testing.expectEqual(@as(f64, 15.0), a.mul(b).real);
    try std.testing.expectEqual(@as(f64, 5.0 / 3.0), a.div(b).real);
}

test "number complex arithmetic" {
    const a = Number.initComplex(1.0, 2.0);
    const b = Number.initComplex(3.0, 4.0);
    const s = a.add(b);
    try std.testing.expectEqual(@as(f64, 4.0), s.real);
    try std.testing.expectEqual(@as(f64, 6.0), s.imag);
    const p = a.mul(b);
    try std.testing.expectEqual(@as(f64, -5.0), p.real);
    try std.testing.expectEqual(@as(f64, 10.0), p.imag);
}

test "number trigonometry" {
    const half = Number.init(0.5);
    const s = half.asin();
    try std.testing.expectApproxEqAbs(@as(f64, std.math.pi / 6.0), s.real, 1e-10);
}

test "number powers" {
    const two = Number.init(2.0);
    const eight = two.pow(Number.init(3.0));
    try std.testing.expectApproxEqAbs(@as(f64, 8.0), eight.real, 1e-10);
    const sqrt4 = Number.init(4.0).sqrt();
    try std.testing.expectApproxEqAbs(@as(f64, 2.0), sqrt4.real, 1e-10);
}

test "number constants" {
    try std.testing.expectApproxEqAbs(@as(f64, std.math.pi), Number.pi.real, 1e-15);
    try std.testing.expectApproxEqAbs(@as(f64, std.math.e), Number.e.real, 1e-15);
}

test "unit conversion" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var conv = UnitConverter.init(allocator);
    defer conv.deinit();

    const result = try conv.convert(100.0, "km", "mi");
    try std.testing.expectApproxEqAbs(@as(f64, 62.1371), result.value, 1e-2);
}

test "parser simple expression" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var cfg = Config.init(allocator);
    defer cfg.deinit();

    var funcs = FunctionTable.init(allocator);
    defer funcs.deinit();

    var constants = std.StringHashMap(Number).init(allocator);
    defer constants.deinit();

    var variables = std.StringHashMap(Number).init(allocator);
    defer variables.deinit();

    var expr = try Parser.init(allocator, "2+3", &cfg, &funcs, &constants, &variables);
    defer expr.deinit();
    const result = try expr.parse();
    try std.testing.expectEqual(@as(f64, 5.0), result.real);
}

test "parser complex expression" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var cfg = Config.init(allocator);
    defer cfg.deinit();

    var funcs = FunctionTable.init(allocator);
    defer funcs.deinit();

    var constants = std.StringHashMap(Number).init(allocator);
    defer constants.deinit();

    var variables = std.StringHashMap(Number).init(allocator);
    defer variables.deinit();

    var expr = try Parser.init(allocator, "sin(pi/2)", &cfg, &funcs, &constants, &variables);
    defer expr.deinit();
    const result = try expr.parse();
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), result.real, 1e-10);
}

test "stats" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var ds = DataSet.init(allocator);
    defer ds.deinit();

    try ds.addValue(1.0);
    try ds.addValue(2.0);
    try ds.addValue(3.0);
    try ds.addValue(4.0);
    try ds.addValue(5.0);

    try std.testing.expectEqual(@as(f64, 3.0), ds.mean());
    try std.testing.expectEqual(@as(usize, 5), ds.count());
    try std.testing.expectEqual(@as(f64, 15.0), ds.sum());
    try std.testing.expectEqual(@as(f64, 1.0), ds.min());
    try std.testing.expectEqual(@as(f64, 5.0), ds.max());
    try std.testing.expectEqual(@as(f64, 3.0), ds.median());
}

test "matrix operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var m1 = try Matrix.init(allocator, 2, 2);
    defer m1.deinit();
    m1.data[0][0] = Number.init(1.0);
    m1.data[0][1] = Number.init(2.0);
    m1.data[1][0] = Number.init(3.0);
    m1.data[1][1] = Number.init(4.0);

    var m2 = try Matrix.init(allocator, 2, 2);
    defer m2.deinit();
    m2.data[0][0] = Number.init(5.0);
    m2.data[0][1] = Number.init(6.0);
    m2.data[1][0] = Number.init(7.0);
    m2.data[1][1] = Number.init(8.0);

    var sum = try m1.add(&m2);
    defer sum.deinit();
    try std.testing.expectEqual(@as(f64, 6.0), sum.data[0][0].real);
    try std.testing.expectEqual(@as(f64, 8.0), sum.data[0][1].real);
    try std.testing.expectEqual(@as(f64, 10.0), sum.data[1][0].real);
    try std.testing.expectEqual(@as(f64, 12.0), sum.data[1][1].real);

    const det = try m1.determinant();
    try std.testing.expectEqual(@as(f64, -2.0), det.real);
}
