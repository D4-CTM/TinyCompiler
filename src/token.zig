const std = @import("std");
const values = @import("values.zig");

const TokenValue = values.TokenValue;
const Allocator = std.mem.Allocator;
const log = std.log.info;

const assert = std.debug.assert;

// Tokens & states
pub const Keywords = enum(u8) {
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
    INTEGER, // todo
    FLOAT, // todo
    STRING, // todo

    IF, // todo
    WHILE, // todo

    L_BRACE,
    R_BRACE,
    L_CURLY_BRACE,
    R_CURLY_BRACE,
    SEMICOLON,

    IDENTIFIER, // todo

    NEW_LINE,
    UNKNOWN,

    pub fn fromChar(c: u8) Keywords {
        return switch (c) {
            '{' => Keywords.L_CURLY_BRACE,
            '}' => Keywords.R_CURLY_BRACE,
            '(' => Keywords.L_BRACE,
            ')' => Keywords.R_BRACE,
            '+' => Keywords.ADD,
            '-' => Keywords.SUBTRACT,
            '*' => Keywords.MULTIPLY,
            ';' => Keywords.SEMICOLON,
            '\n' => Keywords.NEW_LINE,
            else => Keywords.UNKNOWN,
        };
    }
};

pub const Token = struct {
    /// Keyword
    kword: Keywords,
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
        log("\'{s}\' at [{d} | {d}] -> {?} ", .{ @tagName(this.kword), this.line, this.pos, this.value });
    }
};
