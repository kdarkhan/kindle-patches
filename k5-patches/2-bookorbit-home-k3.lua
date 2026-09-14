local Device = require("device")
local UIManager = require("ui/uimanager")
local Event = require("ui/event")

local EV_KEY = 1
local KEY_DOWN = 1

local HOME_KEYCODE = 102
local SCREENKB_KEYCODE = 29 -- the "Keyboard" Fn-style modifier

local screenkb_held = false

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

    if ev.code == HOME_KEYCODE and ev.value == KEY_DOWN then
        UIManager:nextTick(function()
            UIManager:broadcastEvent(Event:new("BookOrbitOpenDashboard"))
        end)
        ev.code = -1 -- swallow plain Home only
    end
end)
