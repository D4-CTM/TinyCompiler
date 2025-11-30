const std = @import("std");
const token = @import("token.zig");

const Token = token.Token;
const TestAllocator = std.testing.allocator;

const eql = std.testing.expectEqual;
const eqlStr = std.testing.expectEqualStrings;
const expect = std.testing.expect;

test "Create integer value" {
    var tk = Token{
        .alloc = TestAllocator,
        .kword = .INTEGER,
        .line = 0,
        .pos = 0
    };

    var int: i32 = 25;
    try expect(tk.value == null);
    try tk.createValue(.{ .int = &int });
    defer tk.freeValue();
    
    try expect(tk.value != null);
    try eql(tk.value.?.int.*, int);

    var int2: i32 = 9;
    try tk.updateValue(.{ .int = &int2});
    try eql(tk.value.?.int.*, int2);
}

test "Create float value" {
    var tk = Token{
        .alloc = TestAllocator,
        .kword = .FLOAT,
        .line = 0,
        .pos = 0
    };

    var float: f32 = 3.14;
    try expect(tk.value == null);
    try tk.createValue(.{ .float = &float });
    defer tk.freeValue();
    
    try expect(tk.value != null);
    try eql(tk.value.?.float.*, float);

    var float2: f32 = 1.98;
    try tk.updateValue(.{ .float = &float2});
    try eql(tk.value.?.float.*, float2);
}

test "Crate string value" {
    var tk = Token{
        .alloc = std.heap.page_allocator,
        .kword = .STRING,
        .line = 0,
        .pos = 0
    };
    defer tk.freeValue();
    
    const oldLen = value: {
        const str: []u8 = @constCast("Hello world!");
        try expect(tk.value == null);
        try tk.createValue(.{ .text = str });
        
        try expect(tk.value != null);
        try eql(tk.value.?.text.len, str.len);
        try eqlStr(tk.value.?.text, str);
        break :value str.len;
    };

    {
        const str: []u8 = @constCast("What a beautiful world!");
        try tk.updateValue(.{ .text = str }); 
        try expect(tk.value.?.text.len > oldLen);
        try eql(tk.value.?.text.len, str.len);
        try eqlStr(tk.value.?.text, str);
    }
}

test "GoTo verification" {
    var x: u8 = 0;

    const y = test_y: {
        defer x = 10;
        while (true) {
            break :test_y 10;
        }
    };

    try eql(x, y);
}
