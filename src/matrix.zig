const std = @import("std");
const Number = @import("number.zig").Number;
const Config = @import("config.zig").Config;

pub const Matrix = struct {
    data: [][]Number,
    rows: usize,
    cols: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Matrix {
        var data = try allocator.alloc([]Number, rows);
        var i: usize = 0;
        errdefer {
            for (data[0..i]) |row| allocator.free(row);
            allocator.free(data);
        }
        while (i < rows) : (i += 1) {
            data[i] = try allocator.alloc(Number, cols);
            for (data[i], 0..) |*elem, j| {
                elem.* = if (i == j) Number.one else Number.zero;
            }
        }
        return Matrix{ .data = data, .rows = rows, .cols = cols, .allocator = allocator };
    }

    pub fn deinit(self: *Matrix) void {
        for (self.data) |row| self.allocator.free(row);
        self.allocator.free(self.data);
    }

    pub fn fromSlice(allocator: std.mem.Allocator, values: []const []const Number) !Matrix {
        const rows = values.len;
        const cols = if (rows > 0) values[0].len else 0;
        const mat = try Matrix.init(allocator, rows, cols);
        for (mat.data, values) |row, src| {
            @memcpy(row, src);
        }
        return mat;
    }

    pub fn add(self: *Matrix, other: *Matrix) !Matrix {
        if (self.rows != other.rows or self.cols != other.cols) return error.DimensionMismatch;
        const result = try Matrix.init(self.allocator, self.rows, self.cols);
        for (result.data, 0..) |row, i| {
            for (row, 0..) |*elem, j| {
                elem.* = self.data[i][j].add(other.data[i][j]);
            }
        }
        return result;
    }

    pub fn sub(self: *Matrix, other: *Matrix) !Matrix {
        if (self.rows != other.rows or self.cols != other.cols) return error.DimensionMismatch;
        const result = try Matrix.init(self.allocator, self.rows, self.cols);
        for (result.data, 0..) |row, i| {
            for (row, 0..) |*elem, j| {
                elem.* = self.data[i][j].sub(other.data[i][j]);
            }
        }
        return result;
    }

    pub fn mul(self: *Matrix, other: *Matrix) !Matrix {
        if (self.cols != other.rows) return error.DimensionMismatch;
        const result = try Matrix.init(self.allocator, self.rows, other.cols);
        for (result.data, 0..) |row, i| {
            for (row, 0..) |*elem, j| {
                elem.* = Number.zero;
                for (0..self.cols) |k| {
                    elem.* = elem.*.add(self.data[i][k].mul(other.data[k][j]));
                }
            }
        }
        return result;
    }

    pub fn scalarMul(self: *Matrix, scalar: Number) !Matrix {
        const result = try Matrix.init(self.allocator, self.rows, self.cols);
        for (result.data, 0..) |row, i| {
            for (row, 0..) |*elem, j| {
                elem.* = self.data[i][j].mul(scalar);
            }
        }
        return result;
    }

    pub fn transpose(self: *Matrix) !Matrix {
        const result = try Matrix.init(self.allocator, self.cols, self.rows);
        for (result.data, 0..) |row, i| {
            for (row, 0..) |*elem, j| {
                elem.* = self.data[j][i];
            }
        }
        return result;
    }

    pub fn determinant(self: *Matrix) !Number {
        if (self.rows != self.cols) return error.NotSquare;
        if (self.rows == 1) return self.data[0][0];
        if (self.rows == 2) {
            return self.data[0][0].mul(self.data[1][1]).sub(self.data[0][1].mul(self.data[1][0]));
        }
        var det = Number.zero;
        for (0..self.cols) |j| {
            var m = try self.minor(0, j);
            defer m.deinit();
            const cofactor = if (j % 2 == 0) self.data[0][j] else self.data[0][j].negate();
            det = det.add(cofactor.mul(try m.determinant()));
        }
        return det;
    }

    pub fn minor(self: *Matrix, exclude_row: usize, exclude_col: usize) !Matrix {
        const result = try Matrix.init(self.allocator, self.rows - 1, self.cols - 1);
        var ri: usize = 0;
        while (ri < self.rows - 1) : (ri += 1) {
            var ci: usize = 0;
            while (ci < self.cols - 1) : (ci += 1) {
                const sr = if (ri >= exclude_row) ri + 1 else ri;
                const sc = if (ci >= exclude_col) ci + 1 else ci;
                result.data[ri][ci] = self.data[sr][sc];
            }
        }
        return result;
    }

    pub fn inverse(self: *Matrix) !Matrix {
        if (self.rows != self.cols) return error.NotSquare;
        const det = try self.determinant();
        if (det.isZero()) return error.SingularMatrix;

        const n = self.rows;
        const result = try Matrix.init(self.allocator, n, n);

        for (0..n) |i| {
            for (0..n) |j| {
                var m = try self.minor(i, j);
                defer m.deinit();
                const mdet = try m.determinant();
                const sign: f64 = if ((i + j) % 2 == 0) 1.0 else -1.0;
                result.data[j][i] = Number.init(sign).mul(mdet).div(det);
            }
        }
        return result;
    }

    pub fn format(self: *Matrix, cfg: *const Config, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        const brackets = switch (cfg.matrix_brackets) {
            .square => .{ '[', ']' },
            .parens => .{ '(', ')' },
            .double => .{ '|', '|' },
        };

        try result.append(brackets[0]);
        try result.append('\n');
        for (self.data, 0..) |row, i| {
            try result.appendSlice("  ");
            for (row, 0..) |elem, j| {
                if (j > 0) try result.appendSlice("  ");
                const elem_str = try elem.formatNum(cfg, allocator);
                try result.appendSlice(elem_str);
                allocator.free(elem_str);
            }
            if (i < self.data.len - 1 and cfg.matrix_separator_rows) {
                try result.append(',');
            }
            try result.append('\n');
        }
        try result.append(brackets[1]);
        return result.toOwnedSlice();
    }
};
