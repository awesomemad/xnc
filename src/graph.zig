const std = @import("std");
const Number = @import("number.zig").Number;
const Config = @import("config.zig").Config;
const FunctionTable = @import("functions.zig").FunctionTable;
const Expr = @import("parser.zig").Expr;

pub const GraphTrace = struct {
    expr: []const u8,
    color: []const u8,
    points: std.ArrayList(f64),
};

pub const Graph = struct {
    cfg: *const Config,
    funcs: *FunctionTable,
    traces: std.ArrayList(GraphTrace),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, cfg: *const Config, funcs: *FunctionTable) Graph {
        return .{
            .cfg = cfg,
            .funcs = funcs,
            .traces = std.ArrayList(GraphTrace).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Graph) void {
        for (self.traces.items) |t| t.points.deinit();
        self.traces.deinit();
    }

    pub fn addTrace(self: *Graph, expr: []const u8) !void {
        const trace = GraphTrace{
            .expr = try self.allocator.dupe(u8, expr),
            .color = "green",
            .points = std.ArrayList(f64).init(self.allocator),
        };
        try self.traces.append(trace);
    }

    pub fn clear(self: *Graph) void {
        for (self.traces.items) |t| t.points.deinit();
        self.traces.clearRetainingCapacity();
    }

    pub fn evaluateTraces(self: *Graph) void {
        const x_min = self.cfg.graph_x_min;
        const x_max = self.cfg.graph_x_max;
        const res = self.cfg.graph_resolution;
        if (res == 0) return;
        const step = (x_max - x_min) / @as(f64, @floatFromInt(res));

        var constants = std.StringHashMap(Number).init(self.allocator);
        defer constants.deinit();
        var variables = std.StringHashMap(Number).init(self.allocator);
        defer variables.deinit();

        for (self.traces.items) |*trace| {
            trace.points.clearRetainingCapacity();
            var i: u32 = 0;
            while (i < res) : (i += 1) {
                const x = x_min + @as(f64, @floatFromInt(i)) * step;
                variables.put("x", Number.init(x)) catch continue;
                var expr = Expr.init(self.allocator, trace.expr, self.cfg, self.funcs, &constants, &variables) catch {
                    trace.points.append(std.math.nan(f64)) catch {};
                    continue;
                };
                defer expr.deinit();
                const result = expr.parse() catch {
                    trace.points.append(std.math.nan(f64)) catch {};
                    continue;
                };
                trace.points.append(result.real) catch {};
            }
        }
    }

    const plot_chars = [6]u8{ '*', 'o', '+', 'x', '#', '@' };
    const plot_colors = [6][]const u8{ "green", "yellow", "red", "blue", "magenta", "cyan" };
    const ansi_colors = [6][]const u8{ "32", "33", "31", "34", "35", "36" };

    fn formatNum(buf: []u8, val: f64) []const u8 {
        if (val == 0) return "0";
        const abs_val = @abs(val);
        if (abs_val >= 1000) return std.fmt.bufPrint(buf[0..16], "{d:.0}", .{val}) catch "?";
        if (abs_val >= 10) return std.fmt.bufPrint(buf[0..16], "{d:.1}", .{val}) catch "?";
        if (abs_val >= 1) return std.fmt.bufPrint(buf[0..16], "{d:.2}", .{val}) catch "?";
        if (abs_val >= 0.01) return std.fmt.bufPrint(buf[0..16], "{d:.3}", .{val}) catch "?";
        return std.fmt.bufPrint(buf[0..16], "{e:.2}", .{val}) catch "?";
    }

    fn yRange(self: *Graph) struct { f64, f64 } {
        var y_min = self.cfg.graph_y_min;
        var y_max = self.cfg.graph_y_max;
        if (self.cfg.graph_auto_scale) {
            y_min = 10e9;
            y_max = -10e9;
            for (self.traces.items) |trace| {
                for (trace.points.items) |y| {
                    if (std.math.isFinite(y)) {
                        if (y < y_min) y_min = y;
                        if (y > y_max) y_max = y;
                    }
                }
            }
            if (y_min == 10e9) { y_min = -10; y_max = 10; }
            const yr = y_max - y_min;
            if (yr == 0) { y_min -= 1; y_max += 1; }
            else { y_min -= yr * 0.1; y_max += yr * 0.1; }
        }
        return .{ y_min, y_max };
    }

    fn writeAxisY(writer: anytype, label: []const u8, w: usize) !void {
        if (label.len > 0) {
            var padded: [16]u8 = undefined;
            @memset(&padded, ' ');
            const pos = if (label.len < w) w - label.len else 0;
            @memcpy(padded[pos..][0..@min(label.len, w - pos)], label[0..@min(label.len, w - pos)]);
            try writer.writeAll(padded[0..w]);
        } else {
            for (0..w) |_| try writer.writeByte(' ');
        }
    }

    pub fn renderASCII(self: *Graph) ![]u8 {
        if (self.traces.items.len == 0) return self.allocator.dupe(u8, "  (no functions to graph)\n");
        const width = self.cfg.graph_width;
        const height = self.cfg.graph_height;
        const x_min = self.cfg.graph_x_min;
        const x_max = self.cfg.graph_x_max;
        const y_range_ = self.yRange();
        const y_min = y_range_[0];
        const y_max = y_range_[1];
        const x_range = x_max - x_min;
        const y_range = y_max - y_min;
        if (x_range == 0 or y_range == 0) return self.allocator.dupe(u8, "  (invalid range)\n");
        const x_step = x_range / @as(f64, @floatFromInt(width));
        const y_step = y_range / @as(f64, @floatFromInt(height));
        const y_label_w: usize = 7;

        var result = std.ArrayList(u8).init(self.allocator);
        try result.append('\n');
        var label_buf: [32]u8 = undefined;

        const y_axis_row = if (y_max > 0 and y_min < 0)
            @as(i32, @intFromFloat((0 - y_min) / y_range * @as(f64, @floatFromInt(height))))
        else -1;

        var row: i32 = @as(i32, @intCast(height)) - 1;
        while (row >= 0) : (row -= 1) {
            const ry = @as(f64, @floatFromInt(row));
            const y = y_min + ry * y_step;
            const is_x_axis = row == y_axis_row;
            const y_tick = @mod(ry, 5) == 0;

            if (self.cfg.graph_show_axes) {
                const lab = if (y_tick) formatNum(&label_buf, y) else "";
                try writeAxisY(result.writer(), lab, y_label_w);
            }

            if (is_x_axis) { try result.appendSlice("─"); }
            else if (y_tick and self.cfg.graph_show_grid) { try result.appendSlice("·"); }
            else { try result.append(' '); }

            for (0..width) |col| {
                var plotted = false;
                var plot_char: u8 = '*';
                var plot_ti: usize = 0;

                for (self.traces.items, 0..) |trace, ti| {
                    if (trace.points.items.len == 0) continue;
                    const idx = @min(col, @as(usize, @intCast(trace.points.items.len - 1)));
                    const y_val = trace.points.items[idx];
                    if (!std.math.isFinite(y_val)) continue;
                    const y_pixel = (y_val - y_min) / y_range * @as(f64, @floatFromInt(height));
                    const diff = y_pixel - ry;
                    if (diff >= -0.5 and diff <= 0.5) {
                        plot_char = plot_chars[ti % plot_chars.len];
                        plot_ti = ti;
                        plotted = true;
                        break;
                    }
                }

                if (plotted) {
                    if (self.cfg.graph_color) {
                        try result.append('\x1b');
                        try result.append('[');
                        try result.appendSlice(ansi_colors[plot_ti % ansi_colors.len]);
                        try result.append('m');
                        try result.append(plot_char);
                        try result.appendSlice("\x1b[0m");
                    } else {
                        try result.append(plot_char);
                    }
                } else if (is_x_axis) {
                    try result.appendSlice("─");
                } else if (y_tick and self.cfg.graph_show_grid) {
                    try result.appendSlice("·");
                } else {
                    const x_tick = col > 0 and @mod(@as(f64, @floatFromInt(col)), 10) == 0;
                    if (x_tick and is_x_axis) try result.appendSlice("┴")
                    else if (x_tick and self.cfg.graph_show_grid) try result.append('+')
                    else try result.append(' ');
                }
            }
            try result.append('\n');
        }

        if (self.cfg.graph_show_axes) {
            try result.append(' ');
            for (0..y_label_w) |_| try result.append(' ');
            const x_labels_count = 5;
            for (0..x_labels_count) |li| {
                const col = width * li / (x_labels_count - 1);
                const x_val = x_min + @as(f64, @floatFromInt(col)) * x_step;
                const x_label = formatNum(&label_buf, x_val);
                const pad = if (li == 0) 0 else if (li == x_labels_count - 1) width + 1 - x_label.len else 0;
                _ = pad;
                if (li > 0) {
                    const spaces = @max(1, (width / (x_labels_count - 1)) - x_label.len);
                    for (0..spaces) |_| try result.append(' ');
                }
                try result.appendSlice(x_label);
            }
            try result.append('\n');
        }

        if (self.cfg.graph_show_legend and self.traces.items.len > 0) {
            try result.appendSlice("\n  Legend:\n");
            for (self.traces.items, 0..) |trace, ti| {
                const c = plot_chars[ti % plot_chars.len];
                if (self.cfg.graph_color) {
                    try std.fmt.format(result.writer(), "    \x1b[{s}m{c}\x1b[0m  {s}\n", .{ ansi_colors[ti % ansi_colors.len], c, trace.expr });
                } else {
                    try std.fmt.format(result.writer(), "    {c}  {s}\n", .{ c, trace.expr });
                }
            }
        }
        try result.append('\n');
        return result.toOwnedSlice();
    }

    pub fn renderBraille(self: *Graph) ![]u8 {
        if (self.traces.items.len == 0) return self.allocator.dupe(u8, "  (no functions to graph)\n");
        const width = self.cfg.graph_width;
        const height = self.cfg.graph_height;
        const x_min = self.cfg.graph_x_min;
        const x_max = self.cfg.graph_x_max;
        const y_range_ = self.yRange();
        const y_min = y_range_[0];
        const y_max = y_range_[1];
        const x_range = x_max - x_min;
        const y_range = y_max - y_min;
        if (x_range == 0 or y_range == 0) return self.allocator.dupe(u8, "  (invalid range)\n");

        const b_w = width;
        const b_h = height * 4;
        const vw = b_w * 2;
        const vh = b_h;

        const y_label_w: usize = 7;

        var result = std.ArrayList(u8).init(self.allocator);
        try result.append('\n');

        var label_buf: [32]u8 = undefined;

        const dot_bit = [4][2]u3{ .{ 0, 3 }, .{ 1, 4 }, .{ 2, 5 }, .{ 6, 7 } };

        var pixel_grid = try self.allocator.alloc([]u8, b_h);
        defer self.allocator.free(pixel_grid);
        for (0..b_h) |r| {
            pixel_grid[r] = try self.allocator.alloc(u8, b_w);
            @memset(pixel_grid[r], 0);
        }
        defer { for (pixel_grid) |r| self.allocator.free(r); }

        for (self.traces.items, 0..) |trace, ti| {
            if (trace.points.items.len < 2) continue;
            _ = ti;

            for (0..vw) |vx| {
                const frac = @as(f64, @floatFromInt(vx)) / @as(f64, @floatFromInt(vw));
                const idx = @min(@as(usize, @intFromFloat(@floor(frac * @as(f64, @floatFromInt(trace.points.items.len))))), trace.points.items.len - 1);
                const y_val = trace.points.items[idx];
                if (!std.math.isFinite(y_val)) continue;
                const py_f = (y_max - y_val) / y_range * @as(f64, @floatFromInt(vh));
                const py = @as(i32, @intFromFloat(@round(py_f)));
                if (py < 0 or py >= @as(i32, @intCast(vh))) continue;
                const bc = @as(usize, @intCast(vx / 2));
                const br = @as(usize, @intCast(@as(usize, @intCast(py)) / 4));
                if (br < b_h and bc < b_w) {
                    const bit = dot_bit[@as(usize, @intCast(py)) % 4][vx % 2];
                    pixel_grid[br][bc] |= @as(u8, 1) << @as(u3, @intCast(bit));
                }
            }

            for (1..vw) |vx| {
                const idx0 = @min(@as(usize, @intFromFloat(@floor(@as(f64, @floatFromInt(vx - 1)) / @as(f64, @floatFromInt(vw)) * @as(f64, @floatFromInt(trace.points.items.len))))), trace.points.items.len - 1);
                const y0 = trace.points.items[idx0];
                if (!std.math.isFinite(y0)) continue;
                const py0_f = (y_max - y0) / y_range * @as(f64, @floatFromInt(vh));
                const py0 = @as(i32, @intFromFloat(@round(py0_f)));

                const idx1 = @min(@as(usize, @intFromFloat(@floor(@as(f64, @floatFromInt(vx)) / @as(f64, @floatFromInt(vw)) * @as(f64, @floatFromInt(trace.points.items.len))))), trace.points.items.len - 1);
                const y1 = trace.points.items[idx1];
                if (!std.math.isFinite(y1)) continue;
                const py1_f = (y_max - y1) / y_range * @as(f64, @floatFromInt(vh));
                const py1 = @as(i32, @intFromFloat(@round(py1_f)));

                if (@abs(py0 - py1) > 1) {
                    const s: i32 = if (py1 > py0) 1 else -1;
                    var pi = py0 + s;
                    while (true) {
                        if (pi >= 0 and pi < @as(i32, @intCast(vh))) {
                            const bc = @as(usize, @intCast(vx / 2));
                            const br = @as(usize, @intCast(@as(usize, @intCast(pi)) / 4));
                            if (br < b_h and bc < b_w) {
                                const bit = dot_bit[@as(usize, @intCast(pi)) % 4][vx % 2];
                                pixel_grid[br][bc] |= @as(u8, 1) << @as(u3, @intCast(bit));
                            }
                        }
                        if (pi == py1) break;
                        pi += s;
                    }
                }
            }
        }

        for (0..b_h) |r| {
            const y = y_max - @as(f64, @floatFromInt(r)) / @as(f64, @floatFromInt(vh)) * y_range;
            const is_label_row = r % 4 == 0;
            if (self.cfg.graph_show_axes) {
                const lab = if (is_label_row) formatNum(&label_buf, y) else "";
                try writeAxisY(result.writer(), lab, y_label_w);
            }
            if (self.cfg.graph_show_axes) {
                try result.appendSlice("│");
            }
            for (0..b_w) |c| {
                const pattern = pixel_grid[r][c];
                if (pattern != 0) {
                    const braille_char = @as(u21, 0x2800) + (pattern & 0x3F);
                    var utf8_buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(braille_char, &utf8_buf) catch 1;
                    try result.appendSlice(utf8_buf[0..len]);
                } else {
                    try result.append(' ');
                }
            }
            try result.append('\n');
        }

        if (self.cfg.graph_show_axes) {
            try result.append(' ');
            for (0..y_label_w) |_| try result.append(' ');
            try result.appendSlice("└");
            const x_labels_count = 5;
            for (0..x_labels_count) |li| {
                const col = b_w * li / (x_labels_count - 1);
                const x_val = x_min + @as(f64, @floatFromInt(col * 2)) / @as(f64, @floatFromInt(vw)) * x_range;
                const x_label = formatNum(&label_buf, x_val);
                if (li > 0) {
                    const spaces = @max(1, (b_w / (x_labels_count - 1)) - x_label.len);
                    for (0..spaces) |_| try result.append(' ');
                }
                try result.appendSlice(x_label);
            }
            try result.append('\n');
        }

        if (self.cfg.graph_show_legend and self.traces.items.len > 0) {
            try result.appendSlice("\n  Legend:\n");
            for (self.traces.items, 0..) |trace, ti| {
                const cc = ansi_colors[ti % ansi_colors.len];
                try std.fmt.format(result.writer(), "    \x1b[{s}m●\x1b[0m  {s}\n", .{ cc, trace.expr });
            }
        }

        try result.append('\n');
        return result.toOwnedSlice();
    }

    pub fn render(self: *Graph) ![]u8 {
        switch (self.cfg.graph_engine) {
            .braille => return self.renderBraille(),
            .ascii => return self.renderASCII(),
            .none => return self.allocator.dupe(u8, ""),
        }
    }
};
