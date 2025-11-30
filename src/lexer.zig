const std = @import("std");
const tv = @import("values.zig");
const tokens = @import("token.zig");
const string = @import("string.zig");
const exception = @import("exception.zig");

const Reader = std.fs.File.Reader;
const log = std.log.info;

const Token = tokens.Token;
const KeywordEnum = tokens.KeywordEnum;

const ExceptionType = exception.ExceptionType;
const Exception = exception.Exception;

const String = string.String;

const TokenState = tv.TokenState;
const TokenValue = tv.TokenValue;

const isLetter = std.ascii.isAlphabetic;
const isAlpha = std.ascii.isAlphanumeric;
const isDigit = std.ascii.isDigit;

const TryToken = union(enum) { token: Token, exception: Exception };

pub const Lexer = struct {
    r: Reader,
    alloc: std.mem.Allocator,
    pos: usize = 0,
    line: usize = 1,

    fn throwException(this: *Lexer, exType: ExceptionType, msg: ?[]const u8) TryToken {
        return TryToken{ .exception = Exception{ .err = exType, .line = this.line, .pos = this.pos, .message = msg } };
    }

    fn createTokenValue(this: *Lexer, TKW: KeywordEnum, val: TokenValue) TryToken {
        return TryToken{ .token = Token{
            .line = this.line,
            .pos = this.pos,
            .kword = TKW,
            .value = val,
            .alloc = this.alloc,
        } };
    }

    fn simpleToken(this: *Lexer, TKW: KeywordEnum) TryToken {
        return TryToken{ .token = Token{
            .line = this.line,
            .pos = this.pos,
            .kword = TKW,
            .alloc = this.alloc,
        } };
    }

    /// Consumes the next char in the file. Returns null only if at EOF
    fn consume(this: *Lexer) !?u8 {
        const size = try this.r.file.getEndPos();
        const pos = this.r.logicalPos();
        if (size - pos == 0) return null;

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
        return try this.r.interface.discardDelimiterExclusive('\n');
    }

    fn skipBlockComment(this: *Lexer) !TryToken {
        const blockStartPos: usize = this.pos;
        const blockStartLine: usize = this.line;
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
        var ex = this.throwException(error.NotClosed, "Comment not closed");
        ex.exception.line = blockStartLine;
        ex.exception.pos = blockStartPos;
        return ex;
    }

    fn extractString(this: *Lexer) !TryToken {
        const blockStartPos: usize = this.pos;
        const blockStartLine: usize = this.line;
        var str = try String.initCapacity(this.alloc, 15);
        defer str.deinit();
        while (try this.consume()) |c| {
            try switch (c) {
                '\\' => if (try this.consume()) |c1| {
                    try str.append(c);
                    try str.append(c1);
                } else break,
                '\n' => return this.throwException(error.NotClosed, "Invalid new line before closing a string"),
                '"' => return this.createTokenValue(.TEXT, try str.createTokenValue(this.alloc, .text)),
                else => str.append(c),
            };
        }
        var ex = this.throwException(error.NotClosed, "String not closed");
        ex.exception.line = blockStartLine;
        ex.exception.pos = blockStartPos;
        return ex;
    }

    fn extractText(this: *Lexer, c: u8) !TryToken {
        var state: TokenState = if (isDigit(c) or c == '-' or c == '+') num_value: {
            break :num_value .int;
        } else if (isLetter(c) or c == '_') text_value: {
            break :text_value .text;
        } else return this.throwException(error.IllegalCharacter, null);

        var str: String = try String.initCapacity(this.alloc, 2);
        defer str.deinit();
        try str.append(c);

        while (try this.peek(1)) |c1| {
            if (c1 == ' ' or c1 == '\t' or c1 == ';' or c1 == '\n') break;

            this.toss(1);
            switch (state) {
                .text => if (!(isAlpha(c1) or c1 == '_')) return this.throwException(error.IllegalCharacter, null) else try str.append(c1),
                .int => if (!isDigit(c1)) {
                    if (c1 == '.') {
                        state = .float;
                        try str.append(c1);
                        continue;
                    }
                    return this.throwException(error.IllegalCharacter, null);
                } else try str.append(c1),
                .float => if (!isDigit(c1)) return this.throwException(error.IllegalCharacter, null) else try str.append(c1),
            }
        }

        switch (state) {
            .int, .float => return this.createTokenValue(.NUMBER, try str.createTokenValue(this.alloc, state)),
            .text => {
                if (KeywordEnum.fromText(str.str)) |kw| {
                    return this.simpleToken(kw);
                }
                return this.createTokenValue(.IDENTIFIER, try str.createTokenValue(this.alloc, state));
            },
        }
    }

    pub fn getNextToken(this: *Lexer) !?TryToken {
        while (try this.consume()) |c| {
            if (c == ' ' or c == '\t') continue;
            if (c == '\n') {
                this.line += 1;
                this.pos = 0;
                continue;
                // return this.simpleToken(.NEW_LINE);
            }

            return switch (c) {
                '*', ';', '(', ')', '{', '}' => |c1| this.simpleToken(.fromChar(c1)),
                '"' => try this.extractString(),
                '+', '-' => if (try this.peek(1)) |c1| return switch (c1) {
                    '1'...'9' => try this.extractText(c),
                    else => this.simpleToken(.fromChar(c))
                } else null,
                '/' => if (try this.peek(1)) |c1| return switch (c1) {
                    '/' => value: {
                        this.toss(1);
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
                    else => this.simpleToken(.ASSIGN),
                } else null,
                '>' => if (try this.peek(1)) |c1| switch (c1) {
                    '=' => value: {
                        this.toss(1);
                        break :value this.simpleToken(.EQUAL_GREATER);
                    },
                    else => this.simpleToken(.GREATER),
                } else null,
                '<' => if (try this.peek(1)) |c1| switch (c1) {
                    '=' => value: {
                        this.toss(1);
                        break :value this.simpleToken(.EQUAL_LESSER);
                    },
                    else => this.simpleToken(.LESSER),
                } else null,
                '!' => if (try this.peek(1)) |c1| switch (c1) {
                    '=' => value: {
                        this.toss(1);
                        break :value this.simpleToken(.DISTINCT);
                    },
                    else => this.simpleToken(.NOT),
                } else null,
                else => try this.extractText(c),
            };
        }
        return null;
    }
};
