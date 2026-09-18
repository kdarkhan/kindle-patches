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

local function findHost()
    local ok_ru, ReaderUI = pcall(require, "apps/reader/readerui")
    if ok_ru and ReaderUI.instance then
        return ReaderUI.instance
    end
    local ok_fm, FileManager = pcall(require, "apps/filemanager/filemanager")
    if ok_fm and FileManager.instance then
        return FileManager.instance
    end
end

local function isInWindowStack(widget)
    local stack = UIManager._window_stack
    for i = 1, #stack do
        if stack[i].widget == widget then
            return true
        end
    end
    return false
end

-- Opens the BookOrbit dashboard -- or, if it's already open but buried
-- under something else (e.g. QuickRSS was opened via double-click without
-- closing the dashboard first), surfaces it instead. BookOrbit's own
-- openCatalogBrowser() silently no-ops when it's already open, so without
-- this a click while it's buried would appear to do nothing at all.
local function openDashboard()
    local host = findHost()
    local bookorbit = host and host.bookorbit
    local dashboard = bookorbit and bookorbit.catalog_browser

    if dashboard and isInWindowStack(dashboard) then
        local stack = UIManager._window_stack
        local guard = 0
        while stack[#stack] and stack[#stack].widget ~= dashboard and guard < 50 do
            closeWidget(stack[#stack].widget)
            guard = guard + 1
        end
    else
        UIManager:broadcastEvent(Event:new("BookOrbitOpenDashboard"))
    end
end

-- Opens QuickRSS via its own show() entry point, which surfaces an
-- already-open feed list/article reader instead of stacking a redundant
-- duplicate on top of it. Falls back to constructing the feed list
-- directly if a not-yet-updated QuickRSS build doesn't have show() yet.
local function openQuickRSS()
    local ok, FeedView = pcall(require, "modules/ui/feed_view")
    if not ok or not FeedView then
        require("logger").warn("bookorbit-home: could not open QuickRSS:", FeedView)
        return
    end
    if FeedView.show then
        FeedView.show()
    else
        UIManager:show(FeedView:new{})
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
