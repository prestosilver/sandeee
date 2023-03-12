const std = @import("std");
const

const GameState = struct {
    drawFn: *const fn (*GameState) void,

    pub fn draw(state: *GameState, batch: sb.SpriteBatch) void {

    }
};
