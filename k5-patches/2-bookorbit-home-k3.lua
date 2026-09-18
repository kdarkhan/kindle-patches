local Device = require("device")
local UIManager = require("ui/uimanager")
local Event = require("ui/event")

local EV_KEY = 1
local KEY_DOWN = 1

local HOME_KEYCODE = 102
local SCREENKB_KEYCODE = 29 -- the "Keyboard" Fn-style modifier

local screenkb_held = false

-- True only when the topmost widget on screen is ReaderUI itself, i.e. we're
-- actually looking at a regular book's pages (not a menu/dialog on top of
-- it, and not some other full-screen app like QuickRSS's article reader).
local function isReadingRegularBook()
    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
    if not ok or not ReaderUI.instance or not ReaderUI.instance.document then
        return false
    end
    local ok2, top_widget = pcall(function()
        local stack = UIManager._window_stack
        return stack and stack[#stack] and stack[#stack].widget
    end)
    if not ok2 then
        -- Can't introspect the window stack for some reason: fall back to
        -- the old always-open-dashboard behavior rather than breaking Home.
        return true
    end
    return top_widget == ReaderUI.instance
end

-- Decision is latched on key-down and reused for the matching key-up so a
-- single physical press is never half-swallowed.
local intercept_home = false

Device.input:registerEventAdjustHook(function(this, ev)
    if ev.type ~= EV_KEY then
        return
    end

    if ev.code == SCREENKB_KEYCODE then
        -- Track modifier state ourselves; let the raw event pass through
        -- untouched so existing Keyboard+X combos keep working as before.
        screenkb_held = (ev.value == KEY_DOWN)
        return
    end

    if screenkb_held then
        -- Any Keyboard+<key> combo: don't touch it, existing behavior owns this.
        return
    end

    if ev.code ~= HOME_KEYCODE then
        return
    end

    if ev.value == KEY_DOWN then
        intercept_home = isReadingRegularBook()
        if intercept_home then
            UIManager:nextTick(function()
                UIManager:broadcastEvent(Event:new("BookOrbitOpenDashboard"))
            end)
        end
    end

    if intercept_home then
        ev.code = -1 -- swallow plain Home only while reading a regular book
    end
    -- else: leave the event untouched so stock Home behavior handles it
    -- (e.g. while reading a QuickRSS article, browsing files, or in a menu).
end)
