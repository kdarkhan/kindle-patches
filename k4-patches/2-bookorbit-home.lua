local Device = require('device')
local UIManager = require('ui/uimanager')
local Event = require('ui/event')

local HOME_KEYCODE = 102
local EV_KEY = 1
local KEY_DOWN = 1

Device.input:registerEventAdjustHook(function(this, ev)
  if ev.type == EV_KEY and ev.code == HOME_KEYCODE then
    if ev.value == KEY_DOWN then
      UIManager:nextTick(function()
        UIManager:broadcastEvent(Event:new('BookOrbitOpenDashboard'))
      end)
    end
    -- Rewrite to an unmapped code so the built-in home/library view
    -- never sees this as a Home keypress (avoids both views opening).
    ev.code = -1
  end
end)
