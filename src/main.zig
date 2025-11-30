const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;

const alloc = std.heap.page_allocator;

pub fn main() !void {
    var file = try std.fs.cwd().openFile("./test.txt", .{ .mode = .read_only });
    defer file.close();

    var buf: [10]u8 = undefined;
    const reader = file.reader(&buf);
    var lexer = Lexer{
        .r = reader
    };

    while (try lexer.getNextToken()) |out| {
        switch (out) {
            .exception => |k| k.printException(),
            .token => |t| t.logValues(),
        }
    }
}
