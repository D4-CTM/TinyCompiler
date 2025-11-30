const std = @import("std");
const values = @import("values.zig");

const TokenValue = values.TokenValue;
const Allocator = std.mem.Allocator;
const log = std.log.info;

const assert = std.debug.assert;

fn hashTxt(str: []u8) usize {
    var i: usize = 1;
    for (str) |c| {
        i += c;
    }
    return i;
}

// Keywords Enum
pub const KeywordEnum = enum(u8) {
    DIVIDE,
    MULTIPLY,
    ADD,
    SUBTRACT,

    NOT,

    EQUAL,
    DISTINCT, // [!=]
    GREATER,
    EQUAL_GREATER,
    LESSER,
    EQUAL_LESSER,

    COMMENT,
    BLOCK_COMMENT,

    ASSIGN,
    // Variable type
    INTEGER,
    FLOAT,
    STRING,
    // Variable content
    TEXT,
    NUMBER,

    IF,
    WHILE,

    L_BRACE,
    R_BRACE,
    L_CURLY_BRACE,
    R_CURLY_BRACE,
    SEMICOLON,

    IDENTIFIER,

    NEW_LINE,
    UNKNOWN,

    pub fn fromChar(c: u8) KeywordEnum {
        return switch (c) {
            '{' => KeywordEnum.L_CURLY_BRACE,
            '}' => KeywordEnum.R_CURLY_BRACE,
            '(' => KeywordEnum.L_BRACE,
            ')' => KeywordEnum.R_BRACE,
            '+' => KeywordEnum.ADD,
            '-' => KeywordEnum.SUBTRACT,
            '*' => KeywordEnum.MULTIPLY,
            ';' => KeywordEnum.SEMICOLON,
            '\n' => KeywordEnum.NEW_LINE,
            else => KeywordEnum.UNKNOWN,
        };
    }

    pub fn fromText(str: []u8) ?KeywordEnum {
        return switch (hashTxt(str)) {
            hashTxt(@constCast("if")) => KeywordEnum.IF,
            hashTxt(@constCast("while")) => KeywordEnum.WHILE,
            hashTxt(@constCast("int")) => KeywordEnum.INTEGER,
            hashTxt(@constCast("float")) => KeywordEnum.FLOAT,
            hashTxt(@constCast("string")) => KeywordEnum.STRING,
            else => null,
        };
    }
};

pub const Token = struct {
    /// Keyword
    kword: KeywordEnum,
    /// What is the value of the token, usually for identifiers or numbers
    value: ?TokenValue = null,
    /// In which line the token lives
    line: usize,
    // Position within the line
    pos: usize,

    alloc: Allocator,

    pub fn createValue(this: *Token, tk: TokenValue) !void {
        this.value = try values.createTokenValue(this.alloc, tk);
    }

    pub fn updateValue(this: *Token, tk: TokenValue) !void {
        if (this.value) |*val| {
            try values.changeTokenValue(this.alloc, val, tk);
        } else this.value = try values.createTokenValue(this.alloc, tk);
    }

    pub fn freeValue(this: *Token) void {
        if (this.value) |*val| {
            values.freeTokenValue(this.alloc, val);
        }
    }

    pub fn logValues(this: Token) void {
        const msg = "\'{s}\' at [{d} | {d}]";
        if (this.value) |val| switch (val) {
            .text => |str| log(msg ++ " -> {s}", .{ @tagName(this.kword), this.line, this.pos, str }),
            .int => |int| log(msg ++ " -> {d}", .{ @tagName(this.kword), this.line, this.pos, int.* }),
            .float => |float| log(msg ++ " -> {d}", .{ @tagName(this.kword), this.line, this.pos, float.* }),
        };
        log(msg, .{ @tagName(this.kword), this.line, this.pos });
    }
};
