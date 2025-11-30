const logErr = @import("std").log.err;

pub const ExceptionType = error {
    IllegalCharacter,
    NotImplemented,
    NotClosed,
};

pub const Exception = struct {
    err: ExceptionType,
    line: usize,
    pos: usize,
    message: ?[]const u8,

    pub fn printException(this: Exception) void {
        logErr("Exception: {} in [{d} | {d}].\nExtra info: {?s}", .{ this.err, this.line, this.pos, this.message});
    }
};
