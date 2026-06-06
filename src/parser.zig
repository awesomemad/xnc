const std = @import("std");
const Number = @import("number.zig").Number;
const Config = @import("config.zig").Config;
const FunctionTable = @import("functions.zig").FunctionTable;
const Additions = @import("additions.zig").Additions;
const OkuginRegistry = @import("okugin.zig").OkuginRegistry;

pub const TokenType = enum {
    number,
    ident,
    plus,
    minus,
    star,
    slash,
    caret,
    percent,
    lparen,
    rparen,
    lbracket,
    rbracket,
    comma,
    equals,
    semicolon,
    pipe,
    exclaim,
    factorial,
    eof,
    invalid,
    dot,
    arrow,
    at,
};

pub const Token = struct {
    type: TokenType,
    start: usize,
    end: usize,
    text: []const u8,
};

pub const Op = enum {
    add,
    sub,
    mul,
    div,
    mod,
    pow,
    neg,
    pos,
    fact,
    assign,
    implicit_mul,
};

pub const Expr = struct {
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(Token),
    pos: usize,
    cfg: *const Config,
    funcs: *FunctionTable,
    constants: *std.StringHashMap(Number),
    variables: *std.StringHashMap(Number),
    additions: ?*Additions,
    okugin_reg: ?*const OkuginRegistry,

    pub fn init(allocator: std.mem.Allocator, input: []const u8, cfg: *const Config, funcs: *FunctionTable, constants: *std.StringHashMap(Number), variables: *std.StringHashMap(Number)) !Expr {
        return initFull(allocator, input, cfg, funcs, constants, variables, null, null);
    }

    pub fn initFull(allocator: std.mem.Allocator, input: []const u8, cfg: *const Config, funcs: *FunctionTable, constants: *std.StringHashMap(Number), variables: *std.StringHashMap(Number), additions: ?*Additions, okugin_reg: ?*const OkuginRegistry) !Expr {
        var self = Expr{
            .allocator = allocator,
            .tokens = std.ArrayList(Token).init(allocator),
            .pos = 0,
            .cfg = cfg,
            .funcs = funcs,
            .constants = constants,
            .variables = variables,
            .additions = additions,
            .okugin_reg = okugin_reg,
        };
        try self.tokenize(input);
        return self;
    }

    pub fn deinit(self: *Expr) void {
        self.tokens.deinit();
    }

    fn tokenize(self: *Expr, input: []const u8) !void {
        var i: usize = 0;
        while (i < input.len) {
            switch (input[i]) {
                ' ', '\t', '\r', '\n' => i += 1,
                '+' => {
                    try self.tokens.append(.{ .type = .plus, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '-' => {
                    if (i + 1 < input.len and input[i + 1] == '>') {
                        try self.tokens.append(.{ .type = .arrow, .start = i, .end = i + 2, .text = input[i .. i + 2] });
                        i += 2;
                    } else {
                        try self.tokens.append(.{ .type = .minus, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                        i += 1;
                    }
                },
                '*' => {
                    try self.tokens.append(.{ .type = .star, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '/' => {
                    try self.tokens.append(.{ .type = .slash, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '^' => {
                    try self.tokens.append(.{ .type = .caret, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '%' => {
                    try self.tokens.append(.{ .type = .percent, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '(' => {
                    try self.tokens.append(.{ .type = .lparen, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                ')' => {
                    try self.tokens.append(.{ .type = .rparen, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '[' => {
                    try self.tokens.append(.{ .type = .lbracket, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                ']' => {
                    try self.tokens.append(.{ .type = .rbracket, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                ',' => {
                    try self.tokens.append(.{ .type = .comma, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '=' => {
                    try self.tokens.append(.{ .type = .equals, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                ';' => {
                    try self.tokens.append(.{ .type = .semicolon, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '|' => {
                    try self.tokens.append(.{ .type = .pipe, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '!' => {
                    try self.tokens.append(.{ .type = .exclaim, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                '.' => {
                    if (i + 1 < input.len and std.ascii.isDigit(input[i + 1])) {
                        const start = i;
                        i += 1;
                        while (i < input.len and std.ascii.isDigit(input[i])) i += 1;
                        try self.tokens.append(.{ .type = .number, .start = start, .end = i, .text = input[start..i] });
                    } else {
                        try self.tokens.append(.{ .type = .dot, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                        i += 1;
                    }
                },
                '@' => {
                    try self.tokens.append(.{ .type = .at, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
                'a'...'z', 'A'...'Z', '_' => {
                    const start = i;
                    i += 1;
                    while (i < input.len and (std.ascii.isAlphanumeric(input[i]) or input[i] == '_' or input[i] == '\'')) i += 1;
                    try self.tokens.append(.{ .type = .ident, .start = start, .end = i, .text = input[start..i] });
                },
                '0'...'9' => {
                    const start = i;
                    i += 1;
                    var is_hex = false;
                    if (input[start] == '0' and i < input.len and (input[i] == 'x' or input[i] == 'X')) {
                        is_hex = true;
                        i += 1;
                        while (i < input.len and std.ascii.isHex(input[i])) i += 1;
                    } else if (input[start] == '0' and i < input.len and (input[i] == 'b' or input[i] == 'B')) {
                        i += 1;
                        while (i < input.len and (input[i] == '0' or input[i] == '1')) i += 1;
                    } else if (input[start] == '0' and i < input.len and (input[i] == 'o' or input[i] == 'O')) {
                        i += 1;
                        while (i < input.len and input[i] >= '0' and input[i] <= '7') i += 1;
                    } else {
                        while (i < input.len and std.ascii.isDigit(input[i])) i += 1;
                        if (i < input.len and input[i] == '.') {
                            i += 1;
                            while (i < input.len and std.ascii.isDigit(input[i])) i += 1;
                        }
                        if (i < input.len and (input[i] == 'e' or input[i] == 'E')) {
                            i += 1;
                            if (i < input.len and (input[i] == '+' or input[i] == '-')) i += 1;
                            while (i < input.len and std.ascii.isDigit(input[i])) i += 1;
                        }
                    }
                    try self.tokens.append(.{ .type = .number, .start = start, .end = i, .text = input[start..i] });
                },
                else => {
                    try self.tokens.append(.{ .type = .invalid, .start = i, .end = i + 1, .text = input[i .. i + 1] });
                    i += 1;
                },
            }
        }
        try self.tokens.append(.{ .type = .eof, .start = input.len, .end = input.len, .text = "" });
    }

    fn peek(self: *Expr) Token {
        return self.tokens.items[self.pos];
    }

    fn advance(self: *Expr) Token {
        const tok = self.tokens.items[self.pos];
        self.pos += 1;
        return tok;
    }

    fn expect(self: *Expr, tok_type: TokenType) !Token {
        const tok = self.advance();
        if (tok.type != tok_type) return error.UnexpectedToken;
        return tok;
    }

    pub fn parse(self: *Expr) anyerror!Number {
        self.pos = 0;
        const result = try self.parseAssignment();
        return result;
    }

    fn parseAssignment(self: *Expr) anyerror!Number {
        const tok = self.peek();
        if (tok.type == .ident) {
            const saved_pos = self.pos;
            const name_tok = self.advance();
            if (self.peek().type == .equals) {
                _ = self.advance();
                const value = try self.parseAssignment();
                try self.variables.put(name_tok.text, value);
                return value;
            }
            self.pos = saved_pos;
        }
        return self.parseExpr();
    }

    fn parseExpr(self: *Expr) anyerror!Number {
        var result = try self.parseTerm();
        while (true) {
            const tok = self.peek();
            switch (tok.type) {
                .plus => {
                    _ = self.advance();
                    const right = try self.parseTerm();
                    result = result.add(right);
                },
                .minus => {
                    _ = self.advance();
                    const right = try self.parseTerm();
                    result = result.sub(right);
                },
                else => break,
            }
        }
        return result;
    }

    fn parseTerm(self: *Expr) anyerror!Number {
        var result = try self.parsePower();
        while (true) {
            const tok = self.peek();
            switch (tok.type) {
                .star => {
                    _ = self.advance();
                    const right = try self.parsePower();
                    result = result.mul(right);
                },
                .slash => {
                    _ = self.advance();
                    const right = try self.parsePower();
                    result = result.div(right);
                },
                .percent => {
                    _ = self.advance();
                    const right = try self.parsePower();
                    result = Number.init(@mod(result.real, right.real));
                },
                else => {
                    if (self.cfg.implicit_multiply and self.isImplicitMul()) {
                        const right = try self.parsePower();
                        result = result.mul(right);
                    } else break;
                },
            }
        }
        return result;
    }

    fn isImplicitMul(self: *Expr) bool {
        const tok = self.peek();
        return tok.type == .number or tok.type == .ident or tok.type == .lparen;
    }

    fn parsePower(self: *Expr) anyerror!Number {
        var result = try self.parseUnary();
        if (self.peek().type == .caret) {
            _ = self.advance();
            const right = try self.parsePower();
            result = result.pow(right);
        }
        return result;
    }

    fn parseUnary(self: *Expr) anyerror!Number {
        const tok = self.peek();
        switch (tok.type) {
            .plus => {
                _ = self.advance();
                return self.parseUnary();
            },
            .minus => {
                _ = self.advance();
                const val = try self.parseUnary();
                return val.negate();
            },
            else => return self.parsePrimary(),
        }
    }

    fn parsePrimary(self: *Expr) anyerror!Number {
        const tok = self.peek();
        switch (tok.type) {
            .number => {
                _ = self.advance();
                return parseNumberLiteral(tok.text);
            },
            .ident => {
                _ = self.advance();
                const name = tok.text;

                if (self.peek().type == .lparen) {
                    _ = self.advance();
                    var args = std.ArrayList(Number).init(self.allocator);
                    defer args.deinit();

                    if (self.peek().type != .rparen) {
                        const arg_val = try self.parseExpr();
                        try args.append(arg_val);
                        while (self.peek().type == .comma) {
                            _ = self.advance();
                            const next_arg = try self.parseExpr();
                            try args.append(next_arg);
                        }
                    }
                    _ = try self.expect(.rparen);

                    if (self.funcs.has(name)) {
                        return self.funcs.evaluate(name, args.items) catch |err| {
                            if (self.cfg.strict_parsing) return err;
                            return Number.nan_val;
                        };
                    }

                    if (self.additions) |adds| {
                        if (adds.getExpression(name)) |expr| {
                            if (args.items.len > 0) {
                                try self.variables.put("x", args.items[0]);
                            }
                            var sub = initFull(self.allocator, expr, self.cfg, self.funcs, self.constants, self.variables, self.additions, self.okugin_reg) catch return Number.nan_val;
                            defer sub.deinit();
                            return sub.parse() catch Number.nan_val;
                        }
                        if (adds.getConstant(name)) |c| {
                            return Number.init(c);
                        }
                    }

                    if (self.okugin_reg) |oreg| {
                        if (oreg.getFunction(name)) |expr| {
                            if (args.items.len > 0) {
                                try self.variables.put("x", args.items[0]);
                            }
                            var sub = initFull(self.allocator, expr, self.cfg, self.funcs, self.constants, self.variables, self.additions, self.okugin_reg) catch return Number.nan_val;
                            defer sub.deinit();
                            return sub.parse() catch Number.nan_val;
                        }
                    }

                    return Number.nan_val;
                }

                if (self.constants.get(name)) |c| return c;
                if (self.variables.get(name)) |v| return v;

                if (self.additions) |adds| {
                    if (adds.getExpression(name)) |expr| {
                        var sub = initFull(self.allocator, expr, self.cfg, self.funcs, self.constants, self.variables, self.additions, self.okugin_reg) catch return Number.zero;
                        defer sub.deinit();
                        return sub.parse() catch Number.zero;
                    }
                    if (adds.getConstant(name)) |c| return Number.init(c);
                }

                if (self.okugin_reg) |oreg| {
                    if (oreg.getFunction(name)) |expr| {
                        var sub = initFull(self.allocator, expr, self.cfg, self.funcs, self.constants, self.variables, self.additions, self.okugin_reg) catch return Number.zero;
                        defer sub.deinit();
                        return sub.parse() catch Number.zero;
                    }
                }

                if (std.mem.eql(u8, name, self.cfg.ans_variable) or std.mem.eql(u8, name, "ans")) {
                    if (self.variables.get("__ans__")) |v| return v;
                    return Number.zero;
                }

                if (std.mem.eql(u8, name, "pi") or std.mem.eql(u8, name, "π")) return Number.pi;
                if (std.mem.eql(u8, name, "e") or std.mem.eql(u8, name, "e")) return Number.e;
                if (std.mem.eql(u8, name, "tau") or std.mem.eql(u8, name, "τ")) return Number.tau;
                if (std.mem.eql(u8, name, "phi") or std.mem.eql(u8, name, "φ")) return Number.init(1.6180339887498948482);
                if (std.mem.eql(u8, name, "gamma_const") or std.mem.eql(u8, name, "γ")) return Number.init(0.5772156649015328606);
                if (std.mem.eql(u8, name, "inf") or std.mem.eql(u8, name, "∞")) return Number.inf;
                if (std.mem.eql(u8, name, "i") or std.mem.eql(u8, name, "j")) return Number.i;

                if (self.cfg.allow_unknown_constants) {
                    return Number.zero;
                }

                return error.UnknownIdentifier;
            },
            .lparen => {
                _ = self.advance();
                const result = try self.parseExpr();
                _ = try self.expect(.rparen);
                return result;
            },
            .lbracket => {
                _ = self.advance();
                var elements = std.ArrayList(Number).init(self.allocator);
                defer elements.deinit();
                if (self.peek().type != .rbracket) {
                    try elements.append(try self.parseExpr());
                    while (self.peek().type == .comma) {
                        _ = self.advance();
                        try elements.append(try self.parseExpr());
                    }
                }
                _ = try self.expect(.rbracket);
                return Number.init(@as(f64, @floatFromInt(elements.items.len)));
            },
            .eof => return Number.zero,
            else => return error.UnexpectedToken,
        }
    }

    fn parseNumberLiteral(text: []const u8) Number {
        var str = text;
        var base: u8 = 10;

        if (std.mem.startsWith(u8, str, "0x") or std.mem.startsWith(u8, str, "0X")) {
            base = 16;
            str = str[2..];
        } else if (std.mem.startsWith(u8, str, "0b") or std.mem.startsWith(u8, str, "0B")) {
            base = 2;
            str = str[2..];
        } else if (std.mem.startsWith(u8, str, "0o") or std.mem.startsWith(u8, str, "0O")) {
            base = 8;
            str = str[2..];
        }

        if (base != 10) {
            const val = std.fmt.parseInt(u64, str, base) catch return Number.zero;
            return Number.init(@as(f64, @floatFromInt(val)));
        }

        const val = std.fmt.parseFloat(f64, str) catch return Number.zero;
        return Number.init(val);
    }
};
