const std = @import("std");
const Config = @import("config.zig").Config;

pub const History = struct {
    entries: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    cfg: *Config,
    current_idx: usize,
    save_dirty: bool,

    pub fn init(allocator: std.mem.Allocator, cfg: *Config) History {
        var h = History{
            .entries = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
            .cfg = cfg,
            .current_idx = 0,
            .save_dirty = false,
        };
        if (cfg.history_load_on_start and cfg.persistent_history) {
            h.load() catch {};
        }
        return h;
    }

    pub fn deinit(self: *History) void {
        if (self.save_dirty and self.cfg.history_save_on_exit) {
            self.save() catch {};
        }
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.deinit();
    }

    pub fn push(self: *History, expr: []const u8) !void {
        if (!self.cfg.history_enabled) return;

        if (self.cfg.history_unique) {
            for (self.entries.items) |e| {
                if (std.mem.eql(u8, e, expr)) return;
            }
        }

        if (self.cfg.history_dedup) {
            var i: usize = 0;
            while (i < self.entries.items.len) {
                if (std.mem.eql(u8, self.entries.items[i], expr)) {
                    self.allocator.free(self.entries.items[i]);
                    _ = self.entries.orderedRemove(i);
                } else {
                    i += 1;
                }
            }
        }

        const entry = try self.allocator.dupe(u8, expr);
        try self.entries.append(entry);

        if (self.entries.items.len > self.cfg.history_max_entries) {
            const removed = self.entries.orderedRemove(0);
            self.allocator.free(removed);
        }

        self.current_idx = self.entries.items.len;
        self.save_dirty = true;
    }

    pub fn back(self: *History) ?[]const u8 {
        if (self.entries.items.len == 0) return null;
        if (self.current_idx == 0) return null;
        self.current_idx -= 1;
        return self.entries.items[self.current_idx];
    }

    pub fn forward(self: *History) ?[]const u8 {
        if (self.current_idx >= self.entries.items.len) return null;
        self.current_idx += 1;
        if (self.current_idx >= self.entries.items.len) return null;
        return self.entries.items[self.current_idx];
    }

    pub fn peek(self: *History) ?[]const u8 {
        if (self.entries.items.len == 0) return null;
        const idx = self.current_idx;
        if (idx < self.entries.items.len) return self.entries.items[idx];
        return self.entries.items[self.entries.items.len - 1];
    }

    pub fn resetNav(self: *History) void {
        self.current_idx = self.entries.items.len;
    }

    pub fn clear(self: *History) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.clearRetainingCapacity();
        self.current_idx = 0;
        self.save_dirty = true;
    }

    pub fn search(self: *History, query: []const u8) ?[]const u8 {
        if (self.entries.items.len == 0) return null;

        var i: usize = self.entries.items.len;
        while (i > 0) {
            i -= 1;
            const entry = self.entries.items[i];
            switch (self.cfg.history_search_mode) {
                .exact => {
                    if (std.mem.eql(u8, entry, query)) return entry;
                },
                .substring => {
                    if (std.mem.indexOf(u8, entry, query) != null) return entry;
                },
                .fuzzy => {
                    var qi: usize = 0;
                    for (entry) |ch| {
                        if (qi < query.len and std.ascii.toLower(ch) == std.ascii.toLower(query[qi])) {
                            qi += 1;
                        }
                    }
                    if (qi == query.len) return entry;
                },
            }
        }
        return null;
    }

    pub fn getEntries(self: *History) [][]const u8 {
        return self.entries.items;
    }

    fn save(self: *History) !void {
        var path_buf: [1024]u8 = undefined;
        var path: []const u8 = self.cfg.history_save_file;

        if (path.len > 0 and path[0] == '~') {
            var env_map = std.process.getEnvMap(self.allocator) catch return;
            defer env_map.deinit();
            const home = env_map.get("USERPROFILE") orelse env_map.get("HOME") orelse return;
            const rest = path[1..];
            const total = home.len + rest.len;
            if (total < path_buf.len) {
                @memcpy(path_buf[0..home.len], home);
                if (rest.len > 0) @memcpy(path_buf[home.len..][0..rest.len], rest);
                path = path_buf[0..total];
            }
        }

        const file = std.fs.createFileAbsolute(path, .{}) catch |err| {
            if (err == error.PathNotFound) return;
            return err;
        };
        defer file.close();
        const writer = file.writer();

        for (self.entries.items) |entry| {
            try writer.print("{s}\n", .{entry});
        }
    }

    fn load(self: *History) !void {
        var path_buf: [1024]u8 = undefined;
        var path: []const u8 = self.cfg.history_save_file;

        if (path.len > 0 and path[0] == '~') {
            var env_map = std.process.getEnvMap(self.allocator) catch return;
            defer env_map.deinit();
            const home = env_map.get("USERPROFILE") orelse env_map.get("HOME") orelse return;
            const rest = path[1..];
            const total = home.len + rest.len;
            if (total < path_buf.len) {
                @memcpy(path_buf[0..home.len], home);
                if (rest.len > 0) @memcpy(path_buf[home.len..][0..rest.len], rest);
                path = path_buf[0..total];
            }
        }

        const file = std.fs.openFileAbsolute(path, .{}) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer file.close();

        const contents = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(contents);

        var lines = std.mem.splitScalar(u8, contents, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len > 0) {
                const entry = try self.allocator.dupe(u8, trimmed);
                try self.entries.append(entry);
            }
        }
        self.current_idx = self.entries.items.len;

        while (self.entries.items.len > self.cfg.history_max_entries) {
            const removed = self.entries.orderedRemove(0);
            self.allocator.free(removed);
        }
    }
};
