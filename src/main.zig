const std = @import("std");
const Lexer = @import("lexer.zig").Lexer;

pub fn main() !void {
    var alloc = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer alloc.deinit();

    var file = try std.fs.cwd().openFile("./test.txt", .{ .mode = .read_only });
    defer file.close();

    var buf: [10]u8 = undefined;
    const reader = file.reader(&buf);
    var lexer = Lexer{
        .r = reader,
        .alloc = alloc.allocator()
    };

    while (try lexer.getNextToken()) |out| {
        switch (out) {
            .exception => |k| {
                k.printException();
                break;
            },
            .token => |t| t.logValues(),
        }
    }
}
