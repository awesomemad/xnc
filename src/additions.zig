const std = @import("std");

pub const AdditionFunction = struct {
    name: []const u8,
    expression: []const u8,
};

pub const AdditionList = struct {
    functions: [][]const u8,
    constants: [][]const u8,
};

pub const Additions = struct {
    functions: std.StringHashMap(AdditionFunction),
    constants: std.StringHashMap(f64),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Additions {
        return .{
            .functions = std.StringHashMap(AdditionFunction).init(allocator),
            .constants = std.StringHashMap(f64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Additions) void {
        {
            var it = self.functions.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*.name);
                self.allocator.free(entry.value_ptr.*.expression);
            }
        }
        self.functions.deinit();
        {
            var it = self.constants.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
            }
        }
        self.constants.deinit();
    }

    pub fn addFunction(self: *Additions, name: []const u8, expression: []const u8) !void {
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);
        const entry = AdditionFunction{
            .name = try self.allocator.dupe(u8, name),
            .expression = try self.allocator.dupe(u8, expression),
        };
        try self.functions.put(key, entry);
    }

    pub fn removeFunction(self: *Additions, name: []const u8) void {
        if (self.functions.getPtr(name)) |entry| {
            self.allocator.free(entry.name);
            self.allocator.free(entry.expression);
        }
        _ = self.functions.remove(name);
    }

    pub fn addConstant(self: *Additions, name: []const u8, value: f64) !void {
        const key = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(key);
        try self.constants.put(key, value);
    }

    pub fn removeConstant(self: *Additions, name: []const u8) void {
        _ = self.constants.remove(name);
    }

    pub fn list(self: *Additions) AdditionList {
        var funcs_list = std.ArrayList([]const u8).init(self.allocator);
        var consts_list = std.ArrayList([]const u8).init(self.allocator);

        var fit = self.functions.iterator();
        while (fit.next()) |entry| {
            const line = std.fmt.allocPrint(self.allocator, "{s} = {s}", .{ entry.value_ptr.name, entry.value_ptr.expression }) catch continue;
            funcs_list.append(line) catch continue;
        }

        var cit = self.constants.iterator();
        while (cit.next()) |entry| {
            const line = std.fmt.allocPrint(self.allocator, "{s} = {d}", .{ entry.key_ptr.*, entry.value_ptr.* }) catch continue;
            consts_list.append(line) catch continue;
        }

        return .{
            .functions = funcs_list.items,
            .constants = consts_list.items,
        };
    }

    pub fn loadFromFile(self: *Additions, path: []const u8) !void {
        const file = if (std.fs.path.isAbsolute(path))
            std.fs.openFileAbsolute(path, .{}) catch |err| {
                if (err == error.FileNotFound) return;
                return err;
            }
        else
            std.fs.cwd().openFile(path, .{}) catch |err| {
                if (err == error.FileNotFound) return;
                return err;
            };
        defer file.close();

        const contents = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(contents);

        var current_section: []const u8 = "";
        var lines = std.mem.splitScalar(u8, contents, '\n');

        while (lines.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \t\r");
            if (line.len == 0 or line[0] == '#') continue;

            if (line[0] == '[') {
                const close = std.mem.indexOfScalar(u8, line, ']') orelse continue;
                current_section = std.mem.trim(u8, line[1..close], " \t");
                continue;
            }

            const eq_pos = std.mem.indexOfScalar(u8, line, '=') orelse continue;
            const key = std.mem.trim(u8, line[0..eq_pos], " \t");
            var raw_value = std.mem.trim(u8, line[eq_pos + 1 ..], " \t");

            if (raw_value.len >= 2 and raw_value[0] == '"' and raw_value[raw_value.len - 1] == '"') {
                raw_value = raw_value[1 .. raw_value.len - 1];
            }

            if (std.mem.eql(u8, current_section, "functions")) {
                self.addFunction(key, raw_value) catch continue;
            } else if (std.mem.eql(u8, current_section, "constants")) {
                const val = std.fmt.parseFloat(f64, raw_value) catch continue;
                self.addConstant(key, val) catch continue;
            }
        }
    }

    pub fn saveToFile(self: *Additions, path: []const u8) !void {
        const file = if (std.fs.path.isAbsolute(path))
            try std.fs.createFileAbsolute(path, .{})
        else
            try std.fs.cwd().createFile(path, .{});
        defer file.close();
        const w = file.writer();

        try w.writeAll("# xnc additions\n");
        try w.writeAll("# User-defined functions and constants\n\n");

        try w.writeAll("[functions]\n");
        var fit = self.functions.iterator();
        while (fit.next()) |entry| {
            try w.print("{s} = \"{s}\"\n", .{ entry.value_ptr.name, entry.value_ptr.expression });
        }

        try w.writeAll("\n[constants]\n");
        var cit = self.constants.iterator();
        while (cit.next()) |entry| {
            try w.print("{s} = {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }

    pub fn getExpression(self: *Additions, name: []const u8) ?[]const u8 {
        if (self.functions.get(name)) |fn_def| {
            return fn_def.expression;
        }
        return null;
    }

    pub fn getConstant(self: *Additions, name: []const u8) ?f64 {
        if (self.constants.get(name)) |val| return val;
        return null;
    }
};
