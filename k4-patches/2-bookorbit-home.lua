local Device = require("device")
local UIManager = require("ui/uimanager")
local Event = require("ui/event")

local EV_KEY = 1
local KEY_DOWN = 1

local HOME_KEYCODE = 102
local SCREENKB_KEYCODE = 29 -- the "Keyboard" Fn-style modifier

local screenkb_held = false

-- How long to wait after a Home press for another one before treating the
-- click count as final. Keep this in sync with the K5 patch.
local CLICK_TIMEOUT = 0.4

local click_count = 0
local timer_scheduled = false

local function openDashboard()
    UIManager:broadcastEvent(Event:new("BookOrbitOpenDashboard"))
end

-- Opens QuickRSS's article list the same way its own main-menu entry does.
-- QuickRSS's koplugin directory is on package.path once plugins finish
-- loading, so this require resolves fine from here too.
local function openQuickRSS()
    local ok, FeedView = pcall(require, "modules/ui/feed_view")
    if ok and FeedView then
        UIManager:show(FeedView:new{})
    else
        require("logger").warn("bookorbit-home: could not open QuickRSS:", FeedView)
    end
end

-- Closes a widget the same "proper" way its own Back/close button would:
-- Menu-based widgets (BookOrbit's dashboard, etc.) via onCloseAllMenus, so
-- close_callback runs even if the user had navigated into a subfolder and
-- a plain Close would only step back one level; everything else via its
-- own onClose, which is how ReaderUI, FileManager, and QuickRSS's widgets
-- all expect to be torn down.
local function closeWidget(widget)
    if widget.onCloseAllMenus then
        widget:onCloseAllMenus()
    elseif widget.onClose then
        widget:onClose()
    else
        UIManager:close(widget)
    end
end

-- Tears down whatever is currently on screen -- a book, BookOrbit's
-- dashboard, QuickRSS, any open dialog -- and opens a fresh file browser at
-- the user's configured home folder (Filebrowser settings -> Home folder),
-- regardless of what got us here.
local function forceOpenHomeFileBrowser()
    -- Close a currently open book properly first (flushes reading position
    -- and settings) rather than yanking it out from under itself.
    local ok_ru, ReaderUI = pcall(require, "apps/reader/readerui")
    if ok_ru and ReaderUI.instance then
        ReaderUI.instance:onClose()
    end

    local stack = UIManager._window_stack
    local guard = 0
    while stack[1] and guard < 50 do
        local top = stack[#stack].widget
        closeWidget(top)
        if stack[#stack] and stack[#stack].widget == top then
            -- Didn't budge: force it off as a last resort so we can't get
            -- stuck here.
            UIManager:close(top)
        end
        guard = guard + 1
    end

    local ok_fu, filemanagerutil = pcall(require, "apps/filemanager/filemanagerutil")
    local home_dir = ok_fu and filemanagerutil.getHomeFolder() or nil

    local ok_fm, FileManager = pcall(require, "apps/filemanager/filemanager")
    if ok_fm then
        FileManager:showFiles(home_dir)
    else
        require("logger").warn("bookorbit-home: could not open file browser")
    end
end

-- Runs once no further Home click has arrived within CLICK_TIMEOUT of the
-- last one: 1 click -> dashboard, 2 -> QuickRSS. (3+ never reaches here --
-- see the key-down handling below.)
local function finalizeClickSequence()
    timer_scheduled = false
    local count = click_count
    click_count = 0
    if count == 1 then
        openDashboard()
    elseif count == 2 then
        openQuickRSS()
    end
end

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
        -- Any Keyboard+<key> combo -- including Keyboard+Home's long-click
        -- action on this device -- bypasses the click counter entirely and
        -- is left completely untouched, exactly like before this patch.
        return
    end

    if ev.code ~= HOME_KEYCODE then
        return
    end

    if ev.value == KEY_DOWN then
        if timer_scheduled then
            UIManager:unschedule(finalizeClickSequence)
            timer_scheduled = false
        end

        click_count = click_count + 1
        if click_count >= 3 then
            -- Third press in the burst: don't wait for a timeout since
            -- there's no 4th action to disambiguate from -- just act now.
            click_count = 0
            UIManager:nextTick(forceOpenHomeFileBrowser)
        else
            UIManager:scheduleIn(CLICK_TIMEOUT, finalizeClickSequence)
            timer_scheduled = true
        end
    end

    -- We now fully own plain Home: always swallow it (both down and up)
    -- rather than ever letting stock handling see the raw key.
    ev.code = -1
end)
