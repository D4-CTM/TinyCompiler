const std = @import("std");
const compiler = @import("compiler");

const Reader = std.fs.File.Reader;
const log = std.log.info;

// Tokens & states
pub const TokenType = enum(u8) {
    DEVIDE,
    MULTIPLY,
    ADD,
    SUBTRACT,

    EQUAL,
    NOT_EQUAL,
    EQUAL_GREATER,
    EQUAL_LESSER,

    COMMENT,
    START_BLOCK_COMMENT,
    END_BLOCK_COMMENT,

    ASSIGN,
    INTEGER,
    FLOAT,

    IDENTIFIER,
};

pub const Token = struct {
    /// Which Token Keyword it is
    TKWord: TokenType,
    /// What is the value of the token, usually for identifiers
    Value: ?[]u8 = null,
    /// In which line the token lives
    Line: usize,

    pub fn logValues(this: Token) void {
        log("line {d}: {s} -> {?s} ", .{ this.Line, @tagName(this.TKWord), this.Value});
    }
};

pub const Lexer = struct {
    Reader: Reader,
    Line: usize = 1,

    fn consumeChar(this: *Lexer) !?u8 {
        if (this.Reader.atEnd()) return null;

        var c: [1]u8 = undefined;
        if (try this.Reader.interface.readSliceShort(&c) == 0) return null;
        return c[0];
    }

    /// Returns:
    /// - usize > 0: discarded bytes from the file until delimeter
    /// - usize == 0: it stopped do to finding the EOF
    /// exception: ReaderFailed
    fn skipLine(this: *Lexer) !usize {
        return try this.Reader.interface.discardDelimiterLimit('\n', .unlimited);
    }

    fn simpleToken(this: *Lexer, TKW: TokenType) Token {
        return Token{ .Line = this.Line, .TKWord = TKW };
    }

    pub fn getNextToken(this: *Lexer) !?Token {
        while (try this.consumeChar()) |c| {
            if (c == ' ' or c == '\t') continue;
            if (c == '\n') {
                this.Line += 1;
                continue;
            }

            return switch (c) {
                '*' => this.simpleToken(.MULTIPLY),
                '/' => if (try this.consumeChar()) |c1| switch (c1) {
                    '\n' => error.IllegalNewLine,
                    '/' => {
                        if (try this.skipLine() == 0) {
                            return null;
                        }
                        return this.simpleToken(.COMMENT);
                    },
                    else => this.simpleToken(.DEVIDE),
                } else null,
                '+' => this.simpleToken(.ADD),
                '-' => this.simpleToken(.SUBTRACT),
                '=' => if (try this.consumeChar()) |c1| switch (c1) {
                    '\n' => error.IllegalNewLine,
                    '=' => this.simpleToken(.EQUAL),
                    else => this.simpleToken(.ASSIGN)
                } else null,
                else => null
            };
        }
        return null;
    }
};
