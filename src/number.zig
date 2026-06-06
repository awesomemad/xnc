const std = @import("std");
const config = @import("config.zig");

pub const Number = struct {
    real: f64,
    imag: f64,

    pub const zero: Number = .{ .real = 0.0, .imag = 0.0 };
    pub const one: Number = .{ .real = 1.0, .imag = 0.0 };
    pub const two: Number = .{ .real = 2.0, .imag = 0.0 };
    pub const half: Number = .{ .real = 0.5, .imag = 0.0 };
    pub const pi: Number = .{ .real = std.math.pi, .imag = 0.0 };
    pub const e: Number = .{ .real = std.math.e, .imag = 0.0 };
    pub const tau: Number = .{ .real = std.math.tau, .imag = 0.0 };
    pub const inf: Number = .{ .real = std.math.inf(f64), .imag = 0.0 };
    pub const nan_val: Number = .{ .real = std.math.nan(f64), .imag = 0.0 };
    pub const i: Number = .{ .real = 0.0, .imag = 1.0 };

    pub fn init(real: f64) Number {
        return .{ .real = real, .imag = 0.0 };
    }

    pub fn initComplex(real: f64, imag: f64) Number {
        return .{ .real = real, .imag = imag };
    }

    pub fn isZero(self: Number) bool {
        return self.real == 0.0 and self.imag == 0.0;
    }

    pub fn isReal(self: Number) bool {
        return self.imag == 0.0;
    }

    pub fn isNaN(self: Number) bool {
        return std.math.isNan(self.real) or std.math.isNan(self.imag);
    }

    pub fn isInf(self: Number) bool {
        return std.math.isInf(self.real) or std.math.isInf(self.imag);
    }

    pub fn isFinite(self: Number) bool {
        return std.math.isFinite(self.real) and std.math.isFinite(self.imag);
    }

    pub fn negate(self: Number) Number {
        return .{ .real = -self.real, .imag = -self.imag };
    }

    pub fn add(self: Number, other: Number) Number {
        return .{ .real = self.real + other.real, .imag = self.imag + other.imag };
    }

    pub fn sub(self: Number, other: Number) Number {
        return .{ .real = self.real - other.real, .imag = self.imag - other.imag };
    }

    pub fn mul(self: Number, other: Number) Number {
        const a = self.real;
        const b = self.imag;
        const c = other.real;
        const d = other.imag;
        return .{
            .real = a * c - b * d,
            .imag = a * d + b * c,
        };
    }

    pub fn div(self: Number, other: Number) Number {
        const a = self.real;
        const b = self.imag;
        const c = other.real;
        const d = other.imag;
        const denom = c * c + d * d;
        if (denom == 0.0) return inf;
        return .{
            .real = (a * c + b * d) / denom,
            .imag = (b * c - a * d) / denom,
        };
    }

    pub fn abs(self: Number) f64 {
        return @sqrt(self.real * self.real + self.imag * self.imag);
    }

    pub fn arg(self: Number) f64 {
        return std.math.atan2(self.imag, self.real);
    }

    pub fn conj(self: Number) Number {
        return .{ .real = self.real, .imag = -self.imag };
    }

    pub fn sqrt(self: Number) Number {
        if (self.isReal() and self.real >= 0) {
            return init(@sqrt(self.real));
        }
        const r = self.abs();
        const phi = self.arg();
        const sqrt_r = @sqrt(r);
        return .{
            .real = sqrt_r * @cos(phi / 2.0),
            .imag = sqrt_r * @sin(phi / 2.0),
        };
    }

    pub fn cbrt(self: Number) Number {
        return self.pow(Number.init(1.0 / 3.0));
    }

    pub fn pow(self: Number, other: Number) Number {
        if (self.isReal() and other.isReal()) {
            if (self.real >= 0) return init(std.math.pow(f64, self.real, other.real));
            if (other.real == std.math.floor(other.real)) {
                const result = std.math.pow(f64, -self.real, other.real);
                if (@mod(other.real, 2.0) != 0) return init(-result);
                return init(result);
            }
        }
        const ln_result = self.ln();
        const mul_result = ln_result.mul(other);
        return mul_result.exp();
    }

    pub fn exp(self: Number) Number {
        if (self.isReal()) return init(std.math.exp(self.real));
        const exp_real = std.math.exp(self.real);
        return .{
            .real = exp_real * @cos(self.imag),
            .imag = exp_real * @sin(self.imag),
        };
    }

    pub fn ln(self: Number) Number {
        if (self.isReal() and self.real > 0) return init(@log(self.real));
        return initComplex(@log(self.abs()), self.arg());
    }

    pub fn log2(self: Number) Number {
        return self.ln().div(init(@log(2.0)));
    }

    pub fn log10(self: Number) Number {
        return self.ln().div(init(@log(10.0)));
    }

    pub fn log(self: Number, base: Number) Number {
        return self.ln().div(base.ln());
    }

    pub fn sin(self: Number) Number {
        if (self.isReal()) return init(@sin(self.real));
        const a = self.real;
        const b = self.imag;
        return .{
            .real = @sin(a) * std.math.cosh(b),
            .imag = @cos(a) * std.math.sinh(b),
        };
    }

    pub fn cos(self: Number) Number {
        if (self.isReal()) return init(@cos(self.real));
        const a = self.real;
        const b = self.imag;
        return .{
            .real = @cos(a) * std.math.cosh(b),
            .imag = -@sin(a) * std.math.sinh(b),
        };
    }

    pub fn tan(self: Number) Number {
        return self.sin().div(self.cos());
    }

    pub fn asin(self: Number) Number {
        const one_minus_sq = Number.one.sub(self.mul(self));
        const inner = (Number.i.mul(self)).add(one_minus_sq.sqrt());
        return Number.i.negate().mul(inner.ln());
    }

    pub fn acos(self: Number) Number {
        const sq = Number.one.sub(self.mul(self));
        return (self.add(sq.sqrt().mul(Number.i))).ln().mul(Number.i).negate();
    }

    pub fn atan(self: Number) Number {
        const num = Number.one.sub(Number.i.mul(self));
        const den = Number.one.add(Number.i.mul(self));
        return Number.half.mul(Number.i.mul(num.div(den)).ln());
    }

    pub fn sinh(self: Number) Number {
        if (self.isReal()) return init(std.math.sinh(self.real));
        const a = self.real;
        const b = self.imag;
        return .{
            .real = std.math.sinh(a) * @cos(b),
            .imag = std.math.cosh(a) * @sin(b),
        };
    }

    pub fn cosh(self: Number) Number {
        if (self.isReal()) return init(std.math.cosh(self.real));
        const a = self.real;
        const b = self.imag;
        return .{
            .real = std.math.cosh(a) * @cos(b),
            .imag = std.math.sinh(a) * @sin(b),
        };
    }

    pub fn tanh(self: Number) Number {
        return self.sinh().div(self.cosh());
    }

    pub fn asinh(self: Number) Number {
        const sq = Number.one.add(self.mul(self));
        return self.add(sq.sqrt()).ln();
    }

    pub fn acosh(self: Number) Number {
        const sq = self.mul(self).sub(Number.one);
        return self.add(sq.sqrt()).ln();
    }

    pub fn atanh(self: Number) Number {
        return Number.half.mul(Number.one.add(self).div(Number.one.sub(self))).ln();
    }

    pub fn floor(self: Number) Number {
        return init(@floor(self.real));
    }

    pub fn ceil(self: Number) Number {
        return init(@ceil(self.real));
    }

    pub fn round(self: Number) Number {
        return init(@round(self.real));
    }

    pub fn trunc(self: Number) Number {
        return init(@trunc(self.real));
    }

    pub fn frac(self: Number) Number {
        return init(self.real - @trunc(self.real));
    }

    pub fn signum(self: Number) Number {
        if (self.isZero()) return zero;
        return init(if (self.real > 0) 1.0 else -1.0);
    }

    pub fn eq(self: Number, other: Number) bool {
        return self.real == other.real and self.imag == other.imag;
    }

    pub fn ne(self: Number, other: Number) bool {
        return !self.eq(other);
    }

    pub fn gt(self: Number, other: Number) bool {
        if (!self.isReal() or !other.isReal()) return false;
        return self.real > other.real;
    }

    pub fn lt(self: Number, other: Number) bool {
        if (!self.isReal() or !other.isReal()) return false;
        return self.real < other.real;
    }

    pub fn formatNum(self: Number, cfg: *const config.Config, allocator: std.mem.Allocator) ![]u8 {
        if (self.isNaN()) return allocator.dupe(u8, "NaN");
        if (self.isInf()) return allocator.dupe(u8, if (self.real > 0) "Infinity" else "-Infinity");

        if (self.isReal()) {
            return formatReal(self.real, cfg, allocator);
        }

        const real_str = if (self.real != 0.0 or cfg.show_real_zero)
            try formatReal(self.real, cfg, allocator)
        else
            "";

        const imag_str = try formatReal(@abs(self.imag), cfg, allocator);

        var parts = std.ArrayList(u8).init(allocator);
        if (real_str.len > 0) {
            try parts.appendSlice(real_str);
        }
        if (self.imag >= 0 and real_str.len > 0) {
            try parts.append('+');
        }
        try parts.appendSlice(imag_str);
        try parts.appendSlice(cfg.i_symbol);

        return parts.toOwnedSlice();
    }

    fn formatReal(val: f64, cfg: *const config.Config, allocator: std.mem.Allocator) ![]u8 {
        if (val == 0.0) return allocator.dupe(u8, "0");

        var result = std.ArrayList(u8).init(allocator);

        const base = @intFromEnum(cfg.output_base);
        if (base != 10) {
            const int_part: u64 = @intCast(@abs(@as(i64, @intFromFloat(val))));
            const prefix = if (cfg.show_base_prefix) blk: {
                break :blk switch (base) {
                    2 => "0b",
                    8 => "0o",
                    16 => "0x",
                    else => "",
                };
            } else "";
            try result.appendSlice(prefix);
            const buf = try allocator.alloc(u8, 64);
            const formatted = if (base == 16)
                std.fmt.bufPrint(buf, "{s}{x}", .{ prefix, int_part }) catch unreachable
            else if (base == 8)
                std.fmt.bufPrint(buf, "{s}{o}", .{ prefix, int_part }) catch unreachable
            else
                std.fmt.bufPrint(buf, "{s}{b}", .{ prefix, int_part }) catch unreachable;
            try result.appendSlice(formatted);
            return result.toOwnedSlice();
        }

        const abs_val = @abs(val);
        const use_sci = switch (cfg.result_format) {
            .scientific => true,
            .engineering => true,
            .fixed => abs_val < std.math.pow(f64, 10.0, @as(f64, @floatFromInt(cfg.max_integer_digits))),
            .auto => (abs_val >= std.math.pow(f64, 10.0, @as(f64, @floatFromInt(cfg.max_integer_digits))) or
                (abs_val < 0.001 and abs_val > 0)),
        };

        if (use_sci) {
            const exponent: i64 = @intFromFloat(@floor(@log10(abs_val)));
            const mantissa = abs_val / std.math.pow(f64, 10.0, @as(f64, @floatFromInt(exponent)));

            const prefix = if (val < 0) "-" else if (cfg.show_plus_sign) "+" else "";
            try result.appendSlice(prefix);

            const mantissa_str = try formatFixed(mantissa, cfg, allocator);
            try result.appendSlice(mantissa_str);

            if (cfg.result_format == .engineering) {
                const eng_exp = (@as(i64, @intFromFloat(@divFloor(@as(f64, @floatFromInt(exponent)), 3.0))) * 3);
                try result.appendSlice("e");
                try result.appendSlice(std.fmt.bufPrint(
                    try allocator.alloc(u8, 16),
                    "{d}",
                    .{eng_exp},
                ) catch unreachable);
            } else {
                try result.appendSlice("e");
                try result.appendSlice(std.fmt.bufPrint(
                    try allocator.alloc(u8, 16),
                    "{d}",
                    .{exponent},
                ) catch unreachable);
            }
        } else {
            const prefix = if (val < 0) "-" else if (cfg.show_plus_sign) "+" else "";
            try result.appendSlice(prefix);

            const str = try formatFixed(abs_val, cfg, allocator);
            try result.appendSlice(str);
        }

        return result.toOwnedSlice();
    }

fn formatFixed(val: f64, cfg: *const config.Config, allocator: std.mem.Allocator) ![]u8 {
    _ = allocator;
    var buf: [512]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "{d:.10}", .{val}) catch unreachable;

    var result = std.ArrayList(u8).init(std.heap.page_allocator);

    if (cfg.show_separators) {
        const dot_pos = std.mem.indexOfScalar(u8, str, '.') orelse str.len;
        var idx: usize = 0;
        while (idx < dot_pos) : (idx += 1) {
            try result.append(str[idx]);
            if (idx < dot_pos - 1) {
                const remaining = dot_pos - idx - 1;
                const sep: u8 = switch (cfg.digit_group) {
                    .comma => @as(u8, ','),
                    .space => @as(u8, ' '),
                    .apostrophe => @as(u8, '\''),
                    .none => 0,
                };
                if (sep != 0 and remaining > 0 and @mod(remaining, 3) == 0) {
                    try result.append(sep);
                }
            }
        }
        if (dot_pos < str.len) {
            try result.appendSlice(str[dot_pos..]);
        }
    } else {
        try result.appendSlice(str);
    }

    return result.toOwnedSlice();
}
};
