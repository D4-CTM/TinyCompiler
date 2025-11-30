const std = @import("std");
const tokens = @import("token.zig");
const exception = @import("exception.zig");
const compiler = @import("compiler");

const Reader = std.fs.File.Reader;
const log = std.log.info;

const Token = tokens.Token;
const Keywords = tokens.Keywords;

const ExceptionType = exception.ExceptionType;
const Exception = exception.Exception;

const TryToken = union(enum) { token: Token, exception: Exception };

pub const Lexer = struct {
    r: Reader,
    pos: usize = 0,
    line: usize = 1,

    /// Consumes the next char in the file. Returns null only if at EOF
    fn consume(this: *Lexer) !?u8 {
        if (this.r.atEnd()) return null;

        var c: [1]u8 = undefined;
        _ = try this.r.interface.readSliceShort(&c);

        this.pos += 1;
        return c[0];
    }

    /// Peeks in the file and searches for the char in {currentPos + offset}.
    fn peek(this: *Lexer, offset: usize) !?u8 {
        const size = try this.r.file.getEndPos();
        const offsetPos = this.r.logicalPos() + offset;
        if (size - offsetPos == 0) return null;

        const cont = try this.r.interface.peek(offset);
        return cont[offset - 1];
    }

    /// Performed ideally after a `peek`
    fn toss(this: *Lexer, offset: usize) void {
        this.r.interface.toss(offset);
        this.pos += 1;
    }

    /// Returns:
    /// - usize > 0: discarded bytes from the file until delimeter
    /// - usize == 0: it was at EOF
    /// exception: ReaderFailed
    fn skipLine(this: *Lexer) !usize {
        defer {
            this.line += 1;
            this.pos = 0;
        }
        return try this.r.interface.discardDelimiterInclusive('\n');
    }

    fn skipBlockComment(this: *Lexer) !?TryToken {
        while (try this.consume()) |c| {
            switch (c) {
                '\n' => {
                    this.line += 1;
                    this.pos = 0;
                    continue;
                },
                '*' => if (try this.peek(1)) |c1| switch (c1) {
                    '/' => {
                        this.toss(1);
                        return this.simpleToken(.BLOCK_COMMENT);
                    },
                    else => continue,
                },
                else => continue,
            }
        }
        return this.throwException(error.NotClosed, "Comment not closed");
    }

    fn throwException(this: *Lexer, exType: ExceptionType, msg: ?[]const u8) TryToken {
        return TryToken{ .exception = Exception{ .err = exType, .line = this.line, .pos = this.pos, .message = msg } };
    }

    fn simpleToken(this: *Lexer, TKW: Keywords) TryToken {
        return TryToken{ .token = Token{
            .line = this.line,
            .pos = this.pos,
            .kword = TKW,
        } };
    }

    pub fn getNextToken(this: *Lexer) !?TryToken {
        while (try this.consume()) |c| {
            if (c == ' ' or c == '\t') continue;
            if (c == '\n') {
                defer {
                    this.line += 1;
                    this.pos = 0;
                }
                return this.simpleToken(.NEW_LINE);
            }

            return switch (c) {
                ';', '(', ')', '{', '}' => |c1| this.simpleToken(.fromChar(c1)),
                '+', '-', '*' => |c1| this.simpleToken(.fromChar(c1)),

                '/' => if (try this.peek(1)) |c1| return switch (c1) {
                    '/' => value: {
                        if (try this.skipLine() == 0) {
                            break :value null;
                        }
                        break :value this.simpleToken(.COMMENT);
                    },
                    '*' => value: {
                        this.toss(1);
                        break :value try this.skipBlockComment();
                    },
                    else => this.simpleToken(.DIVIDE),
                } else null,
                '=' => if (try this.peek(1)) |c1| return switch (c1) {
                    '=' => value: {
                        this.toss(1);
                        break :value this.simpleToken(.EQUAL);
                    },
                    else => value: {
                        break :value this.simpleToken(.ASSIGN);
                    },
                } else null,
                '>' => if (try this.peek(1)) |c1| switch (c1) {
                    '=' => value: {
                        this.toss(1);
                        break :value this.simpleToken(.EQUAL_GREATER);
                    },
                    else => value: {
                        break :value this.simpleToken(.GREATER);
                    },
                } else null,
                '<' => if (try this.peek(1)) |c1| switch (c1) {
                    '=' => value: {
                        this.toss(1);
                        break :value this.simpleToken(.EQUAL_LESSER);
                    },
                    else => value: {
                        break :value this.simpleToken(.LESSER);
                    },
                } else null,
                '!' => if (try this.peek(1)) |c1| switch (c1) {
                    '=' => value: {
                        this.toss(1);
                        break :value this.simpleToken(.DISTINCT);
                    },
                    else => this.simpleToken(.NOT),
                } else null,
                else => this.simpleToken(.UNKNOWN),
            };
        }
        return null;
    }
};
