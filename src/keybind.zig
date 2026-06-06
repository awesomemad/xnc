const std = @import("std");
const Config = @import("config.zig").Config;

pub const KeyAction = enum {
    none,
    exit,
    clear,
    history_back,
    history_forward,
    insert_ans,
    graph,
    unit_conv,
    toggle_angle,
    copy_result,
    paste,
    help,
    clear_entry,
    tab_complete,
    enter,
    cancel,
    delete_char,
    delete_word,
    move_left,
    move_right,
    move_home,
    move_end,
    move_word_left,
    move_word_right,
};

pub const KeyBinding = struct {
    ctrl: bool,
    alt: bool,
    shift: bool,
    key: u8,
    action: KeyAction,
};

pub const KeyBindings = struct {
    bindings: std.ArrayList(KeyBinding),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) KeyBindings {
        var kb = KeyBindings{
            .bindings = std.ArrayList(KeyBinding).init(allocator),
            .allocator = allocator,
        };
        kb.setDefaults();
        return kb;
    }

    pub fn deinit(self: *KeyBindings) void {
        self.bindings.deinit();
    }

    pub fn setDefaults(self: *KeyBindings) void {
        self.bindings.clearRetainingCapacity();
        self.bindings.append(.{ .ctrl = true, .alt = false, .shift = false, .key = 'q', .action = .exit }) catch {};
        self.bindings.append(.{ .ctrl = true, .alt = false, .shift = false, .key = 'l', .action = .clear }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x1B, .action = .history_back }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x1C, .action = .history_forward }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x48, .action = .history_back }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x50, .action = .history_forward }) catch {};
        self.bindings.append(.{ .ctrl = true, .alt = false, .shift = false, .key = 'a', .action = .insert_ans }) catch {};
        self.bindings.append(.{ .ctrl = true, .alt = false, .shift = false, .key = 'g', .action = .graph }) catch {};
        self.bindings.append(.{ .ctrl = true, .alt = false, .shift = false, .key = 'u', .action = .unit_conv }) catch {};
        self.bindings.append(.{ .ctrl = true, .alt = false, .shift = false, .key = 'd', .action = .toggle_angle }) catch {};
        self.bindings.append(.{ .ctrl = true, .alt = false, .shift = false, .key = 'h', .action = .help }) catch {};
        self.bindings.append(.{ .ctrl = true, .alt = false, .shift = false, .key = 'e', .action = .clear_entry }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = '\t', .action = .tab_complete }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = '\r', .action = .enter }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x7F, .action = .delete_char }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x08, .action = .delete_char }) catch {};
        self.bindings.append(.{ .ctrl = true, .alt = false, .shift = false, .key = 'w', .action = .delete_word }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x4B, .action = .move_left }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x4D, .action = .move_right }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x47, .action = .move_home }) catch {};
        self.bindings.append(.{ .ctrl = false, .alt = false, .shift = false, .key = 0x4F, .action = .move_end }) catch {};
    }

    pub fn resolve(self: *KeyBindings, ctrl: bool, alt: bool, shift: bool, key: u8) KeyAction {
        for (self.bindings.items) |b| {
            if (b.ctrl == ctrl and b.alt == alt and b.shift == shift and b.key == key) {
                return b.action;
            }
        }
        return .none;
    }

    pub fn addBinding(self: *KeyBindings, binding: KeyBinding) !void {
        try self.bindings.append(binding);
    }

    pub fn loadFromConfig(_: *KeyBindings, _: *const Config) void {
    }
};

pub const LineEditor = struct {
    buffer: std.ArrayList(u8),
    cursor: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LineEditor {
        return .{
            .buffer = std.ArrayList(u8).init(allocator),
            .cursor = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LineEditor) void {
        self.buffer.deinit();
    }

    pub fn insertChar(self: *LineEditor, ch: u8) void {
        self.buffer.insert(self.cursor, ch) catch {};
        self.cursor += 1;
    }

    pub fn insertString(self: *LineEditor, s: []const u8) void {
        for (s) |ch| self.insertChar(ch);
    }

    pub fn deleteChar(self: *LineEditor) void {
        if (self.cursor > 0 and self.cursor <= self.buffer.items.len) {
            _ = self.buffer.orderedRemove(self.cursor - 1);
            self.cursor -= 1;
        }
    }

    pub fn deleteForward(self: *LineEditor) void {
        if (self.cursor < self.buffer.items.len) {
            _ = self.buffer.orderedRemove(self.cursor);
        }
    }

    pub fn deleteWord(self: *LineEditor) void {
        if (self.cursor == 0) return;
        const end = self.cursor;
        self.cursor -= 1;
        while (self.cursor > 0 and self.buffer.items[self.cursor] == ' ') self.cursor -= 1;
        while (self.cursor > 0 and self.buffer.items[self.cursor - 1] != ' ') self.cursor -= 1;
        const count = end - self.cursor;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            _ = self.buffer.orderedRemove(self.cursor);
        }
    }

    pub fn moveLeft(self: *LineEditor) void {
        if (self.cursor > 0) self.cursor -= 1;
    }

    pub fn moveRight(self: *LineEditor) void {
        if (self.cursor < self.buffer.items.len) self.cursor += 1;
    }

    pub fn moveHome(self: *LineEditor) void {
        self.cursor = 0;
    }

    pub fn moveEnd(self: *LineEditor) void {
        self.cursor = self.buffer.items.len;
    }

    pub fn moveWordLeft(self: *LineEditor) void {
        if (self.cursor == 0) return;
        self.cursor -= 1;
        while (self.cursor > 0 and self.buffer.items[self.cursor] == ' ') self.cursor -= 1;
        while (self.cursor > 0 and self.buffer.items[self.cursor - 1] != ' ') self.cursor -= 1;
    }

    pub fn moveWordRight(self: *LineEditor) void {
        while (self.cursor < self.buffer.items.len and self.buffer.items[self.cursor] != ' ') self.cursor += 1;
        while (self.cursor < self.buffer.items.len and self.buffer.items[self.cursor] == ' ') self.cursor += 1;
    }

    pub fn clearBuffer(self: *LineEditor) void {
        self.buffer.clearRetainingCapacity();
        self.cursor = 0;
    }

    pub fn setText(self: *LineEditor, text: []const u8) void {
        self.buffer.clearRetainingCapacity();
        self.buffer.appendSlice(text) catch {};
        self.cursor = text.len;
    }

    pub fn getText(self: *LineEditor) []const u8 {
        return self.buffer.items;
    }

    pub fn readLine(self: *LineEditor, keys: *KeyBindings, history: anytype) ![]const u8 {
        _ = keys;
        _ = history;
        if (std.os.windows.isWindows()) {
            return try self.readLineWindows();
        }
        return try self.readLinePosix();
    }

    fn readLineWindows(self: *LineEditor) ![]const u8 {
        const stdin = std.io.getStdIn();
        const reader = stdin.reader();

        var buf: [1024]u8 = undefined;
        const line = try reader.readUntilDelimiterOrEof(&buf, '\n');
        if (line) |l| {
            const trimmed = std.mem.trimRight(u8, l, "\r");
            return try self.allocator.dupe(u8, trimmed);
        }
        return error.EndOfStream;
    }

    fn readLinePosix(self: *LineEditor) ![]const u8 {
        const stdin = std.io.getStdIn();
        const reader = stdin.reader();

        var buf: [1024]u8 = undefined;
        const line = try reader.readUntilDelimiterOrEof(&buf, '\n');
        if (line) |l| {
            return try self.allocator.dupe(u8, l);
        }
        return error.EndOfStream;
    }
};
