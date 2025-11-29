const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;
const compiler = @import("compiler");

const alloc = std.heap.page_allocator;

pub fn main() !void {
    var file = try std.fs.cwd().openFile("./test.txt", .{ .mode = .read_only });
    defer file.close();

    var buf: [1]u8 = undefined;
    const reader = file.reader(&buf);
    var lexer = Lexer{
        .Reader = reader
    };

    while (try lexer.getNextToken()) |token| {
        token.logValues();
    }
}
