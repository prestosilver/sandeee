const std = @import("std");

const util = @import("../util.zig");
const events = @import("../events.zig");

const allocator = util.allocator;

const MAX_EVENTS = 8;

// TODO: really this should be a linked list and stored by event

fn Event(comptime T: type) type {
    return struct {
        const Handler = *const fn (T) T.Error!void;

        events: [MAX_EVENTS]Handler = undefined,
        count: usize = 0,

        const Self = @This();

        pub fn attach(self: *Self, handler: Handler) void {
            if (self.count == MAX_EVENTS)
                @panic("Max events attached");

            for (self.events[0..self.count]) |event| {
                if (event == handler)
                    @panic("Double event attach");
            }

            self.events[self.count] = handler;
            self.count += 1;
        }

        pub fn detach(self: *Self, handler: Handler) void {
            var idx: usize = 0;
            while (idx < self.count) : (idx += 1) {
                if (self.events[idx] == handler) {
                    const tmp = self.events[self.count];
                    self.events[self.count] = self.events[idx];
                    self.events[idx] = tmp;
                    self.count -= 1;
                }
            }
        }

        pub fn send(self: *const Self, data: T) T.Error!void {
            for (self.events[0..self.count]) |event| {
                try event(data);
            }
        }
    };
}

pub var event_mouse_move: Event(events.input.EventMouseMove) = .{};
pub var event_key_down: Event(events.input.EventKeyDown) = .{};
pub var event_key_up: Event(events.input.EventKeyUp) = .{};
pub var event_key_char: Event(events.input.EventKeyChar) = .{};
pub var event_mouse_click: Event(events.input.EventMouseClick) = .{};
pub var event_mouse_scroll: Event(events.input.EventMouseScroll) = .{};
pub var event_display_resize: Event(events.input.EventDisplayResize) = .{};
pub var event_clipboard_copy: Event(events.input.EventClipboardCopy) = .{};
pub var event_clipboard_paste: Event(events.input.EventClipboardPaste) = .{};

pub var event_window_create: Event(events.windows.EventWindowCreate) = .{};
pub var event_window_close: Event(events.windows.EventWindowClose) = .{};
pub var event_popup_create: Event(events.windows.EventPopupCreate) = .{};
pub var event_popup_close: Event(events.windows.EventPopupClose) = .{};

pub var event_telem_update: Event(events.system.EventTelemUpdate) = .{};
pub var event_syscall_run: Event(events.system.EventSyscallRun) = .{};
pub var event_cmd_run: Event(events.system.EventCmdRun) = .{};
pub var event_debug_set: Event(events.system.EventDebugSet) = .{};
pub var event_notification_send: Event(events.system.EventNotificationSend) = .{};
pub var event_email_recv: Event(events.system.EventEmailRecv) = .{};
pub var event_setting_set: Event(events.system.EventSettingSet) = .{};
pub var event_state_change: Event(events.system.EventStateChange) = .{};
