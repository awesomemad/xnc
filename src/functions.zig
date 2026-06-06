const std = @import("std");
const Number = @import("number.zig").Number;
const Config = @import("config.zig").Config;

pub const FunctionType = enum {
    unary,
    binary,
    ternary,
    variadic,
};

pub const BuiltinFunction = struct {
    name: []const u8,
    description: []const u8,
    fn_type: FunctionType,
    min_args: u32,
    max_args: u32,
    eval: *const fn (args: []const Number) Number,
};

fn wrapUnary(comptime f: *const fn (Number) Number) *const fn (args: []const Number) Number {
    return struct {
        fn call(args: []const Number) Number {
            return f(args[0]);
        }
    }.call;
}

const Builtins = struct {
    fn sin(args: []const Number) Number { return args[0].sin(); }
    fn cos(args: []const Number) Number { return args[0].cos(); }
    fn tan(args: []const Number) Number { return args[0].tan(); }
    fn asin(args: []const Number) Number { return args[0].asin(); }
    fn acos(args: []const Number) Number { return args[0].acos(); }
    fn atan(args: []const Number) Number { return args[0].atan(); }
    fn atan2(args: []const Number) Number { return Number.init(std.math.atan2(args[0].real, args[1].real)); }
    fn sinh(args: []const Number) Number { return args[0].sinh(); }
    fn cosh(args: []const Number) Number { return args[0].cosh(); }
    fn tanh(args: []const Number) Number { return args[0].tanh(); }
    fn asinh(args: []const Number) Number { return args[0].asinh(); }
    fn acosh(args: []const Number) Number { return args[0].acosh(); }
    fn atanh(args: []const Number) Number { return args[0].atanh(); }
    fn exp(args: []const Number) Number { return args[0].exp(); }
    fn ln(args: []const Number) Number { return args[0].ln(); }
    fn log(args: []const Number) Number {
        if (args.len == 1) return args[0].log10();
        return args[0].log(args[1]);
    }
    fn log2(args: []const Number) Number { return args[0].log2(); }
    fn log10(args: []const Number) Number { return args[0].log10(); }
    fn sqrt(args: []const Number) Number { return args[0].sqrt(); }
    fn cbrt(args: []const Number) Number { return args[0].cbrt(); }
    fn abs(args: []const Number) Number { return Number.init(args[0].abs()); }
    fn floor(args: []const Number) Number { return args[0].floor(); }
    fn ceil(args: []const Number) Number { return args[0].ceil(); }
    fn round(args: []const Number) Number { return args[0].round(); }
    fn trunc(args: []const Number) Number { return args[0].trunc(); }
    fn frac(args: []const Number) Number { return args[0].frac(); }
    fn sign(args: []const Number) Number { return args[0].signum(); }
    fn min(args: []const Number) Number {
        var result = args[0];
        for (args[1..]) |a| { if (a.real < result.real) result = a; }
        return result;
    }
    fn max(args: []const Number) Number {
        var result = args[0];
        for (args[1..]) |a| { if (a.real > result.real) result = a; }
        return result;
    }
    fn clamp(args: []const Number) Number {
        var result = args[0];
        if (result.real < args[1].real) result = args[1];
        if (result.real > args[2].real) result = args[2];
        return result;
    }
    fn lerp(args: []const Number) Number {
        return Number.init(args[0].real + args[2].real * (args[1].real - args[0].real));
    }
    fn deg(args: []const Number) Number { return Number.init(args[0].real * 180.0 / std.math.pi); }
    fn rad(args: []const Number) Number { return Number.init(args[0].real * std.math.pi / 180.0); }
    fn gcd(args: []const Number) Number { return Number.init(@as(f64, @floatFromInt(std.math.gcd(@as(u64, @intFromFloat(args[0].real)), @as(u64, @intFromFloat(args[1].real)))))); }
    fn lcm(args: []const Number) Number {
        const a: u64 = @intFromFloat(args[0].real);
        const b: u64 = @intFromFloat(args[1].real);
        return Number.init(@as(f64, @floatFromInt(a * b / std.math.gcd(a, b))));
    }
    fn fact(args: []const Number) Number {
        const n: u64 = @intFromFloat(args[0].real);
        var result: f64 = 1.0;
        var i: u64 = 2;
        while (i <= n) : (i += 1) result *= @as(f64, @floatFromInt(i));
        return Number.init(result);
    }
    fn nCr(args: []const Number) Number {
        const n: u64 = @intFromFloat(args[0].real);
        const r: u64 = @intFromFloat(args[1].real);
        if (r > n) return Number.zero;
        var result: f64 = 1.0;
        var i: u64 = 0;
        while (i < r) : (i += 1) {
            result *= @as(f64, @floatFromInt(n - i));
            result /= @as(f64, @floatFromInt(i + 1));
        }
        return Number.init(result);
    }
    fn nPr(args: []const Number) Number {
        const n: u64 = @intFromFloat(args[0].real);
        const r: u64 = @intFromFloat(args[1].real);
        if (r > n) return Number.zero;
        var result: f64 = 1.0;
        var i: u64 = 0;
        while (i < r) : (i += 1) {
            result *= @as(f64, @floatFromInt(n - i));
        }
        return Number.init(result);
    }
    fn hypot(args: []const Number) Number { return Number.init(@sqrt(args[0].real * args[0].real + args[1].real * args[1].real)); }
    fn mod(args: []const Number) Number { return Number.init(@mod(args[0].real, args[1].real)); }
    fn rem(args: []const Number) Number { return Number.init(@rem(args[0].real, args[1].real)); }
    fn conj(args: []const Number) Number { return args[0].conj(); }
    fn real(args: []const Number) Number { return Number.init(args[0].real); }
    fn imag(args: []const Number) Number { return Number.init(args[0].imag); }
    fn arg(args: []const Number) Number { return Number.init(args[0].arg()); }
    fn norm(args: []const Number) Number { return Number.init(args[0].abs()); }
    fn polar(args: []const Number) Number {
        return Number.initComplex(args[0].real * @cos(args[1].real), args[0].real * @sin(args[1].real));
    }
    fn rect(args: []const Number) Number { return Number.initComplex(args[0].real, args[1].real); }
    fn pow_func(args: []const Number) Number { return args[0].pow(args[1]); }
    fn root(args: []const Number) Number { return args[0].pow(Number.init(1.0 / args[1].real)); }
    fn expm1(args: []const Number) Number { return Number.init(std.math.expm1(args[0].real)); }
    fn log1p(args: []const Number) Number { return Number.init(std.math.log1p(args[0].real)); }
    fn erf_impl(args: []const Number) Number {
        const x = args[0].real;
        const a1 = 0.254829592;
        const a2 = -0.284496736;
        const a3 = 1.421413741;
        const a4 = -1.453152027;
        const a5 = 1.061405429;
        const p = 0.3275911;
        const sgn: f64 = if (x >= 0) @as(f64, 1.0) else @as(f64, -1.0);
        const ax = @abs(x);
        const t = @as(f64, 1.0) / (@as(f64, 1.0) + p * ax);
        const y = @as(f64, 1.0) - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * std.math.exp(-ax * ax);
        return Number.init(sgn * y);
    }
    fn erfc_impl(args: []const Number) Number { return Number.init(1.0 - erf_impl(args).real); }
    fn gamma_fn(args: []const Number) Number { return Number.init(std.math.gamma(f64, args[0].real)); }
    fn lgamma(args: []const Number) Number { return Number.init(std.math.lgamma(f64, args[0].real)); }
    fn zeta(args: []const Number) Number {
        _ = args;
        return Number.nan_val;
    }
    fn sigmoid(args: []const Number) Number { return Number.init(1.0 / (1.0 + std.math.exp(-args[0].real))); }
    fn relu(args: []const Number) Number { return Number.init(if (args[0].real > 0) args[0].real else 0.0); }
    fn softplus(args: []const Number) Number { return Number.init(std.math.log1p(std.math.exp(args[0].real))); }
    fn cot(args: []const Number) Number { return args[0].cos().div(args[0].sin()); }
    fn sec(args: []const Number) Number { return Number.one.div(args[0].cos()); }
    fn csc(args: []const Number) Number { return Number.one.div(args[0].sin()); }
    fn acot(args: []const Number) Number { return Number.init(std.math.pi / 2.0 - std.math.atan(args[0].real)); }
    fn asec(args: []const Number) Number { return args[0].pow(Number.init(-1.0)).acos(); }
    fn acsc(args: []const Number) Number { return args[0].pow(Number.init(-1.0)).asin(); }
    fn coth(args: []const Number) Number { return args[0].cosh().div(args[0].sinh()); }
    fn sech(args: []const Number) Number { return Number.one.div(args[0].cosh()); }
    fn csch(args: []const Number) Number { return Number.one.div(args[0].sinh()); }
    fn sinc(args: []const Number) Number {
        if (args[0].real == 0.0) return Number.one;
        return Number.init(@sin(args[0].real) / args[0].real);
    }
    fn rad2deg(args: []const Number) Number { return Number.init(args[0].real * 180.0 / std.math.pi); }
    fn deg2rad(args: []const Number) Number { return Number.init(args[0].real * std.math.pi / 180.0); }
    fn grad2rad(args: []const Number) Number { return Number.init(args[0].real * std.math.pi / 200.0); }
    fn rad2grad(args: []const Number) Number { return Number.init(args[0].real * 200.0 / std.math.pi); }
};

pub const FunctionTable = struct {
    map: std.StringHashMap(BuiltinFunction),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) FunctionTable {
        var self = FunctionTable{
            .map = std.StringHashMap(BuiltinFunction).init(allocator),
            .allocator = allocator,
        };
        self.registerStd();
        return self;
    }

    pub fn deinit(self: *FunctionTable) void {
        self.map.deinit();
    }

    fn register(self: *FunctionTable, name: []const u8, desc: []const u8, fn_type: FunctionType, min: u32, max: u32, eval: *const fn (args: []const Number) Number) void {
        self.map.put(name, .{
            .name = name,
            .description = desc,
            .fn_type = fn_type,
            .min_args = min,
            .max_args = max,
            .eval = eval,
        }) catch {};
    }

    fn registerStd(self: *FunctionTable) void {
        self.register("sin", "Sine", .unary, 1, 1, Builtins.sin);
        self.register("cos", "Cosine", .unary, 1, 1, Builtins.cos);
        self.register("tan", "Tangent", .unary, 1, 1, Builtins.tan);
        self.register("asin", "Arc sine", .unary, 1, 1, Builtins.asin);
        self.register("acos", "Arc cosine", .unary, 1, 1, Builtins.acos);
        self.register("atan", "Arc tangent", .unary, 1, 1, Builtins.atan);
        self.register("atan2", "Arc tangent (2 args)", .binary, 2, 2, Builtins.atan2);
        self.register("sinh", "Hyperbolic sine", .unary, 1, 1, Builtins.sinh);
        self.register("cosh", "Hyperbolic cosine", .unary, 1, 1, Builtins.cosh);
        self.register("tanh", "Hyperbolic tangent", .unary, 1, 1, Builtins.tanh);
        self.register("asinh", "Inverse hyperbolic sine", .unary, 1, 1, Builtins.asinh);
        self.register("acosh", "Inverse hyperbolic cosine", .unary, 1, 1, Builtins.acosh);
        self.register("atanh", "Inverse hyperbolic tangent", .unary, 1, 1, Builtins.atanh);
        self.register("exp", "Exponential (e^x)", .unary, 1, 1, Builtins.exp);
        self.register("ln", "Natural logarithm", .unary, 1, 1, Builtins.ln);
        self.register("log", "Logarithm (base 10, or custom)", .variadic, 1, 2, Builtins.log);
        self.register("log2", "Binary logarithm", .unary, 1, 1, Builtins.log2);
        self.register("log10", "Common logarithm", .unary, 1, 1, Builtins.log10);
        self.register("sqrt", "Square root", .unary, 1, 1, Builtins.sqrt);
        self.register("cbrt", "Cube root", .unary, 1, 1, Builtins.cbrt);
        self.register("abs", "Absolute value", .unary, 1, 1, Builtins.abs);
        self.register("floor", "Round down", .unary, 1, 1, Builtins.floor);
        self.register("ceil", "Round up", .unary, 1, 1, Builtins.ceil);
        self.register("round", "Round to nearest", .unary, 1, 1, Builtins.round);
        self.register("trunc", "Truncate", .unary, 1, 1, Builtins.trunc);
        self.register("frac", "Fractional part", .unary, 1, 1, Builtins.frac);
        self.register("sign", "Sign function", .unary, 1, 1, Builtins.sign);
        self.register("min", "Minimum", .variadic, 2, 100, Builtins.min);
        self.register("max", "Maximum", .variadic, 2, 100, Builtins.max);
        self.register("clamp", "Clamp value", .ternary, 3, 3, Builtins.clamp);
        self.register("lerp", "Linear interpolation", .ternary, 3, 3, Builtins.lerp);
        self.register("deg", "Radians to degrees", .unary, 1, 1, Builtins.deg);
        self.register("rad", "Degrees to radians", .unary, 1, 1, Builtins.rad);
        self.register("gcd", "Greatest common divisor", .binary, 2, 2, Builtins.gcd);
        self.register("lcm", "Least common multiple", .binary, 2, 2, Builtins.lcm);
        self.register("fact", "Factorial", .unary, 1, 1, Builtins.fact);
        self.register("nCr", "Combinations", .binary, 2, 2, Builtins.nCr);
        self.register("nPr", "Permutations", .binary, 2, 2, Builtins.nPr);
        self.register("hypot", "Hypotenuse/Euclidean distance", .binary, 2, 2, Builtins.hypot);
        self.register("mod", "Modulo", .binary, 2, 2, Builtins.mod);
        self.register("rem", "Remainder", .binary, 2, 2, Builtins.rem);
        self.register("conj", "Complex conjugate", .unary, 1, 1, Builtins.conj);
        self.register("real", "Real part", .unary, 1, 1, Builtins.real);
        self.register("imag", "Imaginary part", .unary, 1, 1, Builtins.imag);
        self.register("arg", "Complex argument/angle", .unary, 1, 1, Builtins.arg);
        self.register("norm", "Complex magnitude", .unary, 1, 1, Builtins.norm);
        self.register("polar", "Polar to complex", .binary, 2, 2, Builtins.polar);
        self.register("rect", "Rectangular complex", .binary, 2, 2, Builtins.rect);
        self.register("pow", "Power (x^y)", .binary, 2, 2, Builtins.pow_func);
        self.register("root", "Nth root", .binary, 2, 2, Builtins.root);
        self.register("expm1", "e^x - 1", .unary, 1, 1, Builtins.expm1);
        self.register("log1p", "ln(1+x)", .unary, 1, 1, Builtins.log1p);
        self.register("erf", "Error function", .unary, 1, 1, Builtins.erf_impl);
        self.register("erfc", "Complementary error function", .unary, 1, 1, Builtins.erfc_impl);
        self.register("gamma", "Gamma function", .unary, 1, 1, Builtins.gamma_fn);
        self.register("lgamma", "Log gamma function", .unary, 1, 1, Builtins.lgamma);
        self.register("zeta", "Riemann zeta function", .unary, 1, 1, Builtins.zeta);
        self.register("sigmoid", "Sigmoid / logistic function", .unary, 1, 1, Builtins.sigmoid);
        self.register("relu", "ReLU activation", .unary, 1, 1, Builtins.relu);
        self.register("softplus", "Softplus activation", .unary, 1, 1, Builtins.softplus);
        self.register("cot", "Cotangent", .unary, 1, 1, Builtins.cot);
        self.register("sec", "Secant", .unary, 1, 1, Builtins.sec);
        self.register("csc", "Cosecant", .unary, 1, 1, Builtins.csc);
        self.register("acot", "Arc cotangent", .unary, 1, 1, Builtins.acot);
        self.register("asec", "Arc secant", .unary, 1, 1, Builtins.asec);
        self.register("acsc", "Arc cosecant", .unary, 1, 1, Builtins.acsc);
        self.register("coth", "Hyperbolic cotangent", .unary, 1, 1, Builtins.coth);
        self.register("sech", "Hyperbolic secant", .unary, 1, 1, Builtins.sech);
        self.register("csch", "Hyperbolic cosecant", .unary, 1, 1, Builtins.csch);
        self.register("sinc", "Sinc function", .unary, 1, 1, Builtins.sinc);
        self.register("rad2deg", "Radians to degrees", .unary, 1, 1, Builtins.rad2deg);
        self.register("deg2rad", "Degrees to radians", .unary, 1, 1, Builtins.deg2rad);
        self.register("grad2rad", "Gradians to radians", .unary, 1, 1, Builtins.grad2rad);
        self.register("rad2grad", "Radians to gradians", .unary, 1, 1, Builtins.rad2grad);
    }

    pub fn get(self: *FunctionTable, name: []const u8) ?BuiltinFunction {
        return self.map.get(name);
    }

    pub fn has(self: *FunctionTable, name: []const u8) bool {
        return self.map.contains(name);
    }

    pub fn list(self: *FunctionTable) std.StringHashMap(BuiltinFunction).Iterator {
        return self.map.iterator();
    }

    pub fn evaluate(self: *FunctionTable, name: []const u8, args: []const Number) !Number {
        const func = self.get(name) orelse return error.UnknownFunction;
        if (args.len < func.min_args or args.len > func.max_args) return error.WrongArgCount;
        return func.eval(args);
    }
};
