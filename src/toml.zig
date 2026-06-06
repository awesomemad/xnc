const std = @import("std");

pub const TomlValue = union(enum) {
    string: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,
};

pub const ValueStyle = enum {
    quoted_string,
    bare,
    boolean,
    integer,
    float,
};

pub const Section = struct {
    name: []const u8,
    comment: []const u8,
};

pub const TomlEntry = struct {
    section: []const u8,
    key: []const u8,
    comment: []const u8,
    value: []const u8,
    value_style: ValueStyle,
};

pub const ParseError = error{
    InvalidSection,
    InvalidKeyValue,
    EmptyValue,
    UnterminatedString,
    InvalidEscape,
    InvalidNumber,
};

fn isWhitespace(c: u8) bool {
    return switch (c) {
        ' ', '\t', '\n', '\r' => true,
        else => false,
    };
}

fn trimLeft(s: []const u8) []const u8 {
    for (s, 0..) |c, i| {
        if (!isWhitespace(c)) return s[i..];
    }
    return s[s.len..];
}

fn trimRight(s: []const u8) []const u8 {
    var i: usize = s.len;
    while (i > 0) {
        i -= 1;
        if (!isWhitespace(s[i])) return s[0 .. i + 1];
    }
    return s[0..0];
}

fn trim(s: []const u8) []const u8 {
    return trimRight(trimLeft(s));
}

fn stripInlineComment(s: []const u8) []const u8 {
    for (s, 0..) |c, i| {
        if (c == '#' and i > 0 and isWhitespace(s[i - 1])) {
            return s[0..i];
        }
    }
    return s;
}

fn parseQuotedString(allocator: std.mem.Allocator, s: []const u8) !struct { value: []const u8 } {
    std.debug.assert(s.len > 0 and s[0] == '"');

    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var i: usize = 1;
    while (i < s.len) {
        switch (s[i]) {
            '"' => return .{ .value = try result.toOwnedSlice() },
            '\\' => {
                i += 1;
                if (i >= s.len) return ParseError.InvalidEscape;
                switch (s[i]) {
                    'n' => try result.append('\n'),
                    't' => try result.append('\t'),
                    '"' => try result.append('"'),
                    '\\' => try result.append('\\'),
                    else => return ParseError.InvalidEscape,
                }
            },
            else => try result.append(s[i]),
        }
        i += 1;
    }

    return ParseError.UnterminatedString;
}

fn parseLiteralValue(s: []const u8) !TomlValue {
    if (std.mem.eql(u8, s, "true")) return TomlValue{ .boolean = true };
    if (std.mem.eql(u8, s, "false")) return TomlValue{ .boolean = false };

    if (s.len == 0) return ParseError.EmptyValue;

    var is_number = true;
    var has_dot = false;
    var start: usize = 0;

    if (s[0] == '-' or s[0] == '+') {
        if (s.len == 1) is_number = false;
        start = 1;
    }

    if (is_number) {
        for (s[start..]) |c| {
            if (c == '.') {
                if (has_dot) {
                    is_number = false;
                    break;
                }
                has_dot = true;
            } else if (c < '0' or c > '9') {
                is_number = false;
                break;
            }
        }
    }

    if (is_number) {
        if (has_dot) {
            const val = std.fmt.parseFloat(f64, s) catch return ParseError.InvalidNumber;
            return TomlValue{ .float = val };
        } else {
            const val = std.fmt.parseInt(i64, s, 10) catch return ParseError.InvalidNumber;
            return TomlValue{ .integer = val };
        }
    }

    return TomlValue{ .string = s };
}

fn writeEntry(writer: anytype, entry: TomlEntry) !void {
    if (entry.comment.len > 0) {
        try writer.print("# {s}\n", .{entry.comment});
    }
    switch (entry.value_style) {
        .quoted_string => {
            try writer.writeByte('"');
            for (entry.value) |c| {
                switch (c) {
                    '\\' => try writer.writeAll("\\\\"),
                    '"' => try writer.writeAll("\\\""),
                    '\n' => try writer.writeAll("\\n"),
                    '\t' => try writer.writeAll("\\t"),
                    else => try writer.writeByte(c),
                }
            }
            try writer.writeAll("\"\n");
        },
        .bare, .boolean, .integer, .float => {
            try writer.print("{s} = {s}\n", .{ entry.key, entry.value });
        },
    }
}

pub const TomlParser = struct {
    pub fn parse(allocator: std.mem.Allocator, contents: []const u8) !std.StringHashMap(TomlValue) {
        var map = std.StringHashMap(TomlValue).init(allocator);
        errdefer map.deinit();

        var current_section: []const u8 = "";
        var lines = std.mem.splitScalar(u8, contents, '\n');

        while (lines.next()) |raw_line| {
            const line = trimLeft(raw_line);

            if (line.len == 0) continue;
            if (line[0] == '#') continue;

            if (line[0] == '[') {
                const close = std.mem.indexOfScalar(u8, line, ']') orelse return ParseError.InvalidSection;
                if (close <= 1) return ParseError.InvalidSection;
                current_section = trim(line[1..close]);
                if (current_section.len == 0) return ParseError.InvalidSection;
                continue;
            }

            const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse return ParseError.InvalidKeyValue;
            const key = trim(line[0..eq_pos]);
            if (key.len == 0) return ParseError.InvalidKeyValue;

            var raw_value = trimLeft(line[eq_pos + 1 ..]);
            if (raw_value.len == 0) return ParseError.EmptyValue;

            var value: TomlValue = undefined;

            if (raw_value[0] == '"') {
                const parsed = try parseQuotedString(allocator, raw_value);
                value = TomlValue{ .string = parsed.value };
            } else {
                raw_value = stripInlineComment(raw_value);
                const trimmed_val = trim(raw_value);
                if (trimmed_val.len == 0) return ParseError.EmptyValue;
                value = try parseLiteralValue(trimmed_val);
            }

            const full_key = if (current_section.len == 0)
                try allocator.dupe(u8, key)
            else
                try std.fmt.allocPrint(allocator, "{s}.{s}", .{ current_section, key });

            try map.put(full_key, value);
        }

        return map;
    }

    pub fn generate(allocator: std.mem.Allocator, sections: []const Section, entries: []const TomlEntry) ![]u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();
        const w = buf.writer();

        var first = true;

        for (entries) |entry| {
            if (entry.section.len == 0) {
                if (!first) try buf.append('\n');
                try writeEntry(w, entry);
                first = false;
            }
        }

        for (sections) |section| {
            if (!first) try buf.append('\n');
            if (section.comment.len > 0) {
                try w.print("# {s}\n", .{section.comment});
            }
            try w.print("[{s}]\n", .{section.name});
            for (entries) |entry| {
                if (std.mem.eql(u8, entry.section, section.name)) {
                    try writeEntry(w, entry);
                }
            }
            first = false;
        }

        return buf.toOwnedSlice();
    }
};
