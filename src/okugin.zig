const std = @import("std");

pub const PluginType = enum {
    function,
    command,
    hook,
    converter,
    graph,
    display,
    full,
};

pub const HookEvent = enum {
    before_eval,
    after_eval,
    before_exit,
    after_config_load,
    before_graph,
    on_error,
};

pub const HookFn = *const fn (context: *anyopaque) void;

pub const OkuginInstance = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    author: []const u8,
    plugin_type: PluginType,
    loaded: bool,
    path: []const u8,
    functions: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *OkuginInstance) void {
        var it = self.functions.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.functions.deinit();
    }

    pub fn getFunction(self: *const OkuginInstance, name: []const u8) ?[]const u8 {
        if (self.functions.get(name)) |expr| return expr;
        return null;
    }
};

pub const OkuginRegistry = struct {
    plugins: std.StringHashMap(OkuginInstance),
    hooks: std.EnumArray(HookEvent, std.ArrayList(HookFn)),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) OkuginRegistry {
        var hooks: std.EnumArray(HookEvent, std.ArrayList(HookFn)) = undefined;
        inline for (@typeInfo(HookEvent).Enum.fields) |field| {
            const event: HookEvent = @enumFromInt(field.value);
            hooks.set(event, std.ArrayList(HookFn).init(allocator));
        }
        return .{
            .plugins = std.StringHashMap(OkuginInstance).init(allocator),
            .hooks = hooks,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *OkuginRegistry) void {
        var it = self.plugins.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*.name);
            self.allocator.free(entry.value_ptr.*.version);
            self.allocator.free(entry.value_ptr.*.description);
            self.allocator.free(entry.value_ptr.*.author);
            self.allocator.free(entry.value_ptr.*.path);
            entry.value_ptr.*.deinit();
        }
        self.plugins.deinit();

        inline for (@typeInfo(HookEvent).Enum.fields) |field| {
            const event: HookEvent = @enumFromInt(field.value);
            self.hooks.get(event).deinit();
        }
    }

    pub fn scanDirectory(self: *OkuginRegistry, dir_path: []const u8) !void {
        var dir = if (std.fs.path.isAbsolute(dir_path))
            try std.fs.openDirAbsolute(dir_path, .{ .iterate = true })
        else
            try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".okugin")) continue;

            const file_path = try std.fs.path.join(self.allocator, &[_][]const u8{ dir_path, entry.name });
            defer self.allocator.free(file_path);

            const file = try std.fs.openFileAbsolute(file_path, .{});
            defer file.close();

            const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
            defer self.allocator.free(content);

            const instance = parseOkuginFile(self.allocator, content, file_path) catch continue;

            const key = try self.allocator.dupe(u8, instance.name);
            try self.plugins.put(key, instance);
        }
    }

    pub fn load(self: *OkuginRegistry, name: []const u8) !void {
        const instance = self.plugins.getPtr(name) orelse return error.PluginNotFound;
        if (instance.loaded) return;

        const file = try std.fs.openFileAbsolute(instance.path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        var current_fn: ?[]const u8 = null;
        var lines = std.mem.splitScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (trimmed[0] == '[') {
                const close = std.mem.indexOfScalar(u8, trimmed, ']') orelse continue;
                const section = trimmed[1..close];
                if (std.mem.startsWith(u8, section, "function.")) {
                    current_fn = section["function.".len..];
                    continue;
                }
                current_fn = null;
                continue;
            }

            if (current_fn) |fname| {
                const eq_pos = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
                const k = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                if (std.mem.eql(u8, k, "expression")) {
                    const raw_value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");
                    const value = if (raw_value.len >= 2 and raw_value[0] == '"' and raw_value[raw_value.len - 1] == '"')
                        raw_value[1 .. raw_value.len - 1]
                    else
                        raw_value;
                    const key = try self.allocator.dupe(u8, fname);
                    const val = try self.allocator.dupe(u8, value);
                    instance.functions.put(key, val) catch {};
                }
            }
        }

        instance.loaded = true;
    }

    pub fn unload(self: *OkuginRegistry, name: []const u8) void {
        if (self.plugins.getPtr(name)) |entry| {
            entry.loaded = false;
        }
    }

    pub fn getFunction(self: *const OkuginRegistry, name: []const u8) ?[]const u8 {
        var it = self.plugins.iterator();
        while (it.next()) |entry| {
            if (!entry.value_ptr.loaded) continue;
            if (entry.value_ptr.getFunction(name)) |expr| return expr;
        }
        return null;
    }

    pub fn list(self: *OkuginRegistry) []OkuginInstance {
        const result = self.allocator.alloc(OkuginInstance, self.plugins.count()) catch {
            return &[_]OkuginInstance{};
        };
        var idx: usize = 0;
        var it = self.plugins.iterator();
        while (it.next()) |entry| {
            result[idx] = entry.value_ptr.*;
            idx += 1;
        }
        return result;
    }

    pub fn registerHook(self: *OkuginRegistry, event: HookEvent, hook: HookFn) !void {
        try self.hooks.getPtr(event).append(hook);
    }

    pub fn fireHook(self: *OkuginRegistry, event: HookEvent, context: *anyopaque) void {
        for (self.hooks.get(event).items) |hook| {
            hook(context);
        }
    }

    pub fn download(self: *OkuginRegistry, url: []const u8, dest_dir: []const u8) !void {
        _ = self;
        _ = url;
        _ = dest_dir;
    }
};

fn parseOkuginFile(allocator: std.mem.Allocator, content: []const u8, file_path: []const u8) !OkuginInstance {
    var name: ?[]const u8 = null;
    var version: ?[]const u8 = null;
    var description: ?[]const u8 = null;
    var author: ?[]const u8 = null;
    var plugin_type: ?PluginType = null;

    var in_plugin_section = false;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        if (trimmed[0] == '[') {
            const close = std.mem.indexOfScalar(u8, trimmed, ']') orelse continue;
            const section = trimmed[1..close];
            in_plugin_section = std.mem.eql(u8, section, "plugin");
            continue;
        }

        if (!in_plugin_section) continue;

        const eq_pos = std.mem.indexOfScalar(u8, trimmed, '=') orelse continue;
        const k = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
        const raw_value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

        const value = if (raw_value.len >= 2 and raw_value[0] == '"' and raw_value[raw_value.len - 1] == '"')
            raw_value[1 .. raw_value.len - 1]
        else
            raw_value;

        if (std.mem.eql(u8, k, "name")) {
            name = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, k, "version")) {
            version = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, k, "description")) {
            description = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, k, "author")) {
            author = try allocator.dupe(u8, value);
        } else if (std.mem.eql(u8, k, "type")) {
            plugin_type = parsePluginType(value);
        }
    }

    return OkuginInstance{
        .name = name orelse return error.MissingName,
        .version = version orelse return error.MissingVersion,
        .description = description orelse return error.MissingDescription,
        .author = author orelse return error.MissingAuthor,
        .plugin_type = plugin_type orelse return error.MissingType,
        .loaded = false,
        .path = try allocator.dupe(u8, file_path),
        .functions = std.StringHashMap([]const u8).init(allocator),
        .allocator = allocator,
    };
}

fn parsePluginType(type_str: []const u8) ?PluginType {
    if (std.mem.eql(u8, type_str, "function")) return .function;
    if (std.mem.eql(u8, type_str, "command")) return .command;
    if (std.mem.eql(u8, type_str, "hook")) return .hook;
    if (std.mem.eql(u8, type_str, "converter")) return .converter;
    if (std.mem.eql(u8, type_str, "graph")) return .graph;
    if (std.mem.eql(u8, type_str, "display")) return .display;
    if (std.mem.eql(u8, type_str, "full")) return .full;
    return null;
}

pub fn getOkuginsDir(allocator: std.mem.Allocator) ![]u8 {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const home = env_map.get("HOME") orelse env_map.get("USERPROFILE") orelse return error.HomeDirNotFound;
    return std.fs.path.join(allocator, &[_][]const u8{ home, ".xnc", "okugins" });
}
