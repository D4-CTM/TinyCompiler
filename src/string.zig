//! lightweight String implementation thought for this compiler
const std = @import("std");
const tv = @import("values.zig");

const Allocator = std.mem.Allocator;
const parseFloat = std.fmt.parseFloat;
const parseInt = std.fmt.parseInt;

pub const String = struct {
    alloc: Allocator,
    str: []u8,
    len: usize = 0,

    pub fn initCapacity(alloc: std.mem.Allocator, capacity: usize) !String {
        return String{
            .alloc = alloc,
            .str = try alloc.alloc(u8, capacity),
        };
    }

    pub fn deinit(this: *String) void {
        this.alloc.free(this.str);
        this.len = 0;
    }
    
    pub fn append(this: *String, c: u8) !void {
        if (this.len >= this.str.len) {
            this.str = try this.alloc.realloc(this.str, this.str.len * 3);
        }

        this.str[this.len] = c;
        this.len += 1;
    }

    pub fn pop(this: *String) !void {
        this.len -= 1;
    }

    pub fn toi(this: *String, comptime t: type) !*t {
        var int = try parseInt(t, this.str[0..this.len], 0);
        return &int;
    }

    pub fn tof(this: *String, comptime t: type) !*t {
        var float = try parseFloat(t, this.str[0..this.len]);
        return &float;
    }

    pub fn createTokenValue(this: *String, alloc: Allocator, state: tv.TokenState) !tv.TokenValue {
        return switch (state) {
            .int => tv.createTokenValue(alloc, .{
                .int = try this.toi(i32)
            }),
            .float => tv.createTokenValue(alloc, .{
                .float = try this.tof(f32)
            }),
            .text => tv.createTokenValue(alloc, .{
                .text = this.str[0..this.len]
            })
        };
    }
};
