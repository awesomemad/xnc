const std = @import("std");
const Number = @import("number.zig").Number;
const Config = @import("config.zig").Config;

pub const DataSet = struct {
    x: std.ArrayList(f64),
    y: std.ArrayList(f64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DataSet {
        return .{
            .x = std.ArrayList(f64).init(allocator),
            .y = std.ArrayList(f64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DataSet) void {
        self.x.deinit();
        self.y.deinit();
    }

    pub fn clear(self: *DataSet) void {
        self.x.clearRetainingCapacity();
        self.y.clearRetainingCapacity();
    }

    pub fn addPoint(self: *DataSet, x_val: f64, y_val: f64) !void {
        try self.x.append(x_val);
        try self.y.append(y_val);
    }

    pub fn addValue(self: *DataSet, val: f64) !void {
        try self.x.append(@as(f64, @floatFromInt(self.x.items.len + 1)));
        try self.y.append(val);
    }

    pub fn count(self: *DataSet) usize {
        return self.x.items.len;
    }

    pub fn mean(self: *DataSet) f64 {
        if (self.y.items.len == 0) return 0;
        var s: f64 = 0;
        for (self.y.items) |v| s += v;
        return s / @as(f64, @floatFromInt(self.y.items.len));
    }

    pub fn variance(self: *DataSet) f64 {
        const n = self.y.items.len;
        if (n < 2) return 0;
        const m = self.mean();
        var sum_sq: f64 = 0;
        for (self.y.items) |v| {
            const diff = v - m;
            sum_sq += diff * diff;
        }
        return sum_sq / @as(f64, @floatFromInt(n - 1));
    }

    pub fn stdDev(self: *DataSet) f64 {
        return @sqrt(self.variance());
    }

    pub fn sum(self: *DataSet) f64 {
        var result: f64 = 0;
        for (self.y.items) |v| result += v;
        return result;
    }

    pub fn min(self: *DataSet) f64 {
        if (self.y.items.len == 0) return 0;
        var result = self.y.items[0];
        for (self.y.items) |v| { if (v < result) result = v; }
        return result;
    }

    pub fn max(self: *DataSet) f64 {
        if (self.y.items.len == 0) return 0;
        var result = self.y.items[0];
        for (self.y.items) |v| { if (v > result) result = v; }
        return result;
    }

    pub fn median(self: *DataSet) f64 {
        const n = self.y.items.len;
        if (n == 0) return 0;
        var sorted = self.y.clone() catch return 0;
        defer sorted.deinit();
        std.mem.sort(f64, sorted.items, {}, comptime std.sort.asc(f64));
        if (n % 2 == 1) return sorted.items[n / 2];
        return (sorted.items[n / 2 - 1] + sorted.items[n / 2]) / 2.0;
    }

    pub fn quartiles(self: *DataSet) struct { q1: f64, q2: f64, q3: f64 } {
        const n = self.y.items.len;
        if (n == 0) return .{ .q1 = 0, .q2 = 0, .q3 = 0 };
        if (n == 1) return .{ .q1 = self.y.items[0], .q2 = self.y.items[0], .q3 = self.y.items[0] };
        var sorted = self.y.clone() catch return .{ .q1 = 0, .q2 = 0, .q3 = 0 };
        defer sorted.deinit();
        std.mem.sort(f64, sorted.items, {}, comptime std.sort.asc(f64));
        const q2 = if (n % 2 == 1) sorted.items[n / 2] else (sorted.items[n / 2 - 1] + sorted.items[n / 2]) / 2.0;

        const first_half = sorted.items[0 .. n / 2];
        const second_half = sorted.items[n - n / 2 ..];

        const q1 = if (first_half.len % 2 == 1) first_half[first_half.len / 2] else (first_half[first_half.len / 2 - 1] + first_half[first_half.len / 2]) / 2.0;
        const q3 = if (second_half.len % 2 == 1) second_half[second_half.len / 2] else (second_half[second_half.len / 2 - 1] + second_half[second_half.len / 2]) / 2.0;

        return .{ .q1 = q1, .q2 = q2, .q3 = q3 };
    }

    pub fn linearRegression(self: *DataSet) RegressionResult {
        const n = self.x.items.len;
        if (n < 2) return RegressionResult.zero();
        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        var sum_xy: f64 = 0;
        var sum_xx: f64 = 0;
        for (0..n) |i| {
            const xv = self.x.items[i];
            const yv = self.y.items[i];
            sum_x += xv;
            sum_y += yv;
            sum_xy += xv * yv;
            sum_xx += xv * xv;
        }
        const nf = @as(f64, @floatFromInt(n));
        const denom = nf * sum_xx - sum_x * sum_x;
        const slope = if (denom != 0) (nf * sum_xy - sum_x * sum_y) / denom else 0;
        const intercept = (sum_y - slope * sum_x) / nf;
        const r_num = nf * sum_xy - sum_x * sum_y;
        const r_den = @sqrt((nf * sum_xx - sum_x * sum_x) * (nf * self.sum_sq_y() - sum_y * sum_y));
        const r = if (r_den != 0) r_num / r_den else 0;

        return .{
            .slope = slope,
            .intercept = intercept,
            .correlation = r,
            .r_squared = r * r,
        };
    }

    fn sum_sq_y(self: *DataSet) f64 {
        var total: f64 = 0;
        for (self.y.items) |v| total += v * v;
        return total;
    }

    pub fn formatStats(self: *DataSet, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        const n = self.count();
        try result.appendSlice("=== Statistics ===\n");
        try std.fmt.format(result.writer(), "n     = {d}\n", .{n});
        try std.fmt.format(result.writer(), "sum   = {d:.6}\n", .{self.sum()});
        try std.fmt.format(result.writer(), "mean  = {d:.6}\n", .{self.mean()});
        try std.fmt.format(result.writer(), "median= {d:.6}\n", .{self.median()});
        try std.fmt.format(result.writer(), "stdev = {d:.6}\n", .{self.stdDev()});
        try std.fmt.format(result.writer(), "var   = {d:.6}\n", .{self.variance()});
        try std.fmt.format(result.writer(), "min   = {d:.6}\n", .{self.min()});
        try std.fmt.format(result.writer(), "max   = {d:.6}\n", .{self.max()});

        const q = self.quartiles();
        try std.fmt.format(result.writer(), "Q1    = {d:.6}\n", .{q.q1});
        try std.fmt.format(result.writer(), "Q2    = {d:.6}\n", .{q.q2});
        try std.fmt.format(result.writer(), "Q3    = {d:.6}\n", .{q.q3});

        if (n >= 2) {
            const reg = self.linearRegression();
            try std.fmt.format(result.writer(), "slope = {d:.6}\n", .{reg.slope});
            try std.fmt.format(result.writer(), "intercept = {d:.6}\n", .{reg.intercept});
            try std.fmt.format(result.writer(), "r     = {d:.6}\n", .{reg.correlation});
            try std.fmt.format(result.writer(), "r^2   = {d:.6}\n", .{reg.r_squared});
        }
        return result.toOwnedSlice();
    }
};

pub const RegressionResult = struct {
    slope: f64,
    intercept: f64,
    correlation: f64,
    r_squared: f64,

    pub fn zero() RegressionResult {
        return .{ .slope = 0, .intercept = 0, .correlation = 0, .r_squared = 0 };
    }
};
