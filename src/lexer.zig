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
    DISTINCT, // [!=] 
    GREATER,
    EQUAL_GREATER,
    LESSER,
    EQUAL_LESSER,

    COMMENT,
    BLOCK_COMMENT,

    ASSIGN,
    INTEGER, // todo
    FLOAT, // todo

    IF, // todo
    WHILE, // todo

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
        log("line {d}: {s} -> {?s} ", .{ this.Line, @tagName(this.TKWord), this.Value });
    }
};

pub const Lexer = struct {
    Reader: Reader,
    Line: usize = 1,

    /// Consumes the next char in the file. Returns null only if at EOF
    fn consume(this: *Lexer) !?u8 {
        if (this.Reader.atEnd()) return null;

        var c: [1]u8 = undefined;
        _ = try this.Reader.interface.readSliceShort(&c);
        return c[0];
    }

    /// Peeks in the file and searches for the char in {currentPos + offset}.
    fn peek(this: *Lexer, offset: usize) !?u8 {
        const size = try this.Reader.file.getEndPos();
        const offsetPos = this.Reader.logicalPos() + offset;
        if (size - offsetPos == 0) return null;

        const cont = try this.Reader.interface.peek(offset);
        return cont[offset - 1];
    }

    /// Performed ideally after a `peek`
    fn toss(this: *Lexer, offset: usize) void {
        this.Reader.interface.toss(offset);
    }

    /// Returns:
    /// - usize > 0: discarded bytes from the file until delimeter
    /// - usize == 0: it was at EOF
    /// exception: ReaderFailed
    fn skipLine(this: *Lexer) !usize {
        this.Line += 1;
        return try this.Reader.interface.discardDelimiterInclusive('\n');
    }

    fn skipBlockComment(this: *Lexer) !?Token {
        while (try this.consume()) |c| {
            switch (c) {
                '\n' => {
                    this.Line += 1;
                    continue;
                },
                '*' => if (try this.peek(1)) |c1| switch (c1) {
                    '\n' => {
                        this.Line += 1;
                        this.toss(1);
                        continue;
                    },
                    '/' => {
                        this.toss(1);
                        return this.simpleToken(.BLOCK_COMMENT);
                    },
                    else => continue,
                },
                else => continue,
            }
        }
        return error.CommentNotClosed;
    }

    fn simpleToken(this: *Lexer, TKW: TokenType) Token {
        return Token{
            .Line = this.Line,
            .TKWord = TKW,
        };
    }

    pub fn getNextToken(this: *Lexer) !?Token {
        while (try this.consume()) |c| {
            if (c == ' ' or c == '\t') continue;
            if (c == '\n') {
                this.Line += 1;
                continue;
            }

            return switch (c) {
                '*' => this.simpleToken(.MULTIPLY),
                '/' => if (try this.consume()) |c1| return switch (c1) {
                    '\n' => error.IllegalNewLine,
                    '/' => value: {
                        if (try this.skipLine() == 0) {
                            break :value null;
                        }
                        break :value this.simpleToken(.COMMENT);
                    },
                    '*' => try this.skipBlockComment(),
                    else => this.simpleToken(.DEVIDE),
                } else null,
                '+' => this.simpleToken(.ADD),
                '-' => this.simpleToken(.SUBTRACT),
                '=' => if (try this.consume()) |c1| return switch (c1) {
                    '\n' => error.IllegalNewLine,
                    '=' => this.simpleToken(.EQUAL),
                    else => value: {
                        break :value this.simpleToken(.ASSIGN);
                    },
                } else null,
                '>' => if (try this.consume()) |c1| switch (c1) {
                    '\n' => error.IllegalNewLine,
                    '=' => this.simpleToken(.EQUAL_GREATER),
                    else => value: {
                        break :value this.simpleToken(.GREATER);
                    },
                } else null,
                '<' => if (try this.consume()) |c1| switch (c1) {
                    '\n' => error.IllegalNewLine,
                    '=' => this.simpleToken(.EQUAL_LESSER),
                    else => value: {
                        break :value this.simpleToken(.LESSER);
                    },
                } else null,
                '!' => if (try this.consume()) |c1|  switch (c1) {
                    '\n' => error.IllegalNewLine,
                    '=' => this.simpleToken(.DISTINCT),
                } else null,
                else => null,
            };
        }
        return null;
    }
};
