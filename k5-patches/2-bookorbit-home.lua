local Device = require('device')
local UIManager = require('ui/uimanager')
local Event = require('ui/event')

local HOME_KEYCODE = 102
local EV_KEY = 1
local KEY_DOWN = 1

-- How long to wait after a Home press for another one before treating the
-- click count as final. Keep this in sync with the K4 patch.
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
  local ok_ru, ReaderUI = pcall(require, 'apps/reader/readerui')
  if ok_ru and ReaderUI.instance then
    return ReaderUI.instance
  end
  local ok_fm, FileManager = pcall(require, 'apps/filemanager/filemanager')
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
    UIManager:broadcastEvent(Event:new('BookOrbitOpenDashboard'))
  end
end

-- Finds a QuickRSS feed-list or article-reader widget already sitting
-- somewhere in the window stack (e.g. buried under the dashboard), by
-- comparing each widget's metatable to the class itself -- that's how
-- koreader's Widget:new() sets instances up, so this reliably identifies
-- instances regardless of how deep in the stack they are.
local function findBuriedQuickRSSWidget()
  local ok1, FeedView = pcall(require, 'modules/ui/feed_view')
  local ok2, ArticleReader = pcall(require, 'modules/ui/article_reader')
  local stack = UIManager._window_stack
  for i = #stack, 1, -1 do
    local mt = getmetatable(stack[i].widget)
    if (ok1 and mt == FeedView) or (ok2 and mt == ArticleReader) then
      return stack[i].widget
    end
  end
end

-- Opens QuickRSS's article list the same way its own main-menu entry does
-- -- or, if a feed list/article reader is already open but buried under
-- something else, surfaces it instead of stacking a redundant new one.
local function openQuickRSS()
  local existing = findBuriedQuickRSSWidget()
  if existing then
    local stack = UIManager._window_stack
    local guard = 0
    while stack[#stack] and stack[#stack].widget ~= existing and guard < 50 do
      closeWidget(stack[#stack].widget)
      guard = guard + 1
    end
    return
  end

  local ok, FeedView = pcall(require, 'modules/ui/feed_view')
  if ok and FeedView then
    UIManager:show(FeedView:new{})
  else
    require('logger').warn('bookorbit-home: could not open QuickRSS:', FeedView)
  end
end

-- Tears down whatever is currently on screen -- a book, BookOrbit's
-- dashboard, QuickRSS, any open dialog -- and opens a fresh file browser at
-- the user's configured home folder (Filebrowser settings -> Home folder),
-- regardless of what got us here.
local function forceOpenHomeFileBrowser()
  -- Close a currently open book properly first (flushes reading position
  -- and settings) rather than yanking it out from under itself.
  local ok_ru, ReaderUI = pcall(require, 'apps/reader/readerui')
  if ok_ru and ReaderUI.instance then
    ReaderUI.instance:onClose()
  end

  local stack = UIManager._window_stack
  local guard = 0
  while stack[1] and guard < 50 do
    local top = stack[#stack].widget
    closeWidget(top)
    if stack[#stack] and stack[#stack].widget == top then
      -- Didn't budge: force it off as a last resort so we can't get stuck
      -- here.
      UIManager:close(top)
    end
    guard = guard + 1
  end

  local ok_fu, filemanagerutil = pcall(require, 'apps/filemanager/filemanagerutil')
  local home_dir = ok_fu and filemanagerutil.getHomeFolder() or nil

  local ok_fm, FileManager = pcall(require, 'apps/filemanager/filemanager')
  if ok_fm then
    FileManager:showFiles(home_dir)
  else
    require('logger').warn('bookorbit-home: could not open file browser')
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
  if ev.type ~= EV_KEY or ev.code ~= HOME_KEYCODE then
    return
  end

  if ev.value == KEY_DOWN then
    if timer_scheduled then
      UIManager:unschedule(finalizeClickSequence)
      timer_scheduled = false
    end

    click_count = click_count + 1
    if click_count >= 3 then
      -- Third press in the burst: don't wait for a timeout since there's
      -- no 4th action to disambiguate from -- just act now.
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
