const std = @import("std");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const TokenState = enum {
    text,
    int,
    float
};

pub const TokenValue = union(TokenState) {
    text: []u8,
    int: *i32,
    float: *f32,
};

pub fn createTokenValue(alloc: Allocator, val: TokenValue) !TokenValue {
    const value = switch (val) {
        .text => |str| TokenValue{ .text = try alloc.dupe(u8, str) },
        .int => |int| TokenValue{ .int = value: {
            const number = try alloc.create(i32);
            number.* = int.*;
            break :value number;
        } },
        .float => |float| TokenValue{ .float = value: {
            const number = try alloc.create(f32);
            number.* = float.*;
            break :value number;
        } },
    };
    return value;
}

pub fn changeTokenValue(alloc: Allocator, actVal: *TokenValue, val: TokenValue) !void {
    switch (actVal.*) {
        .text => {
            if (val.text.len > actVal.text.len)
                actVal.text = try alloc.realloc(actVal.text, val.text.len);

            assert(actVal.text.len >=  val.text.len);
            @memcpy(actVal.text, val.text);
        },
        .int => |int| int.* = val.int.*,
        .float => |float| float.* = val.float.*,
    }
}

pub fn freeTokenValue(alloc: Allocator, actVal: TokenValue) void {
    switch (actVal) {
        .text => |str| alloc.free(str),
        .int => |number| alloc.destroy(number),
        .float => |number| alloc.destroy(number),
    }
}
