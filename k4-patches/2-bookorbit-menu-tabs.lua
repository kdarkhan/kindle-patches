local TouchMenu = require("ui/widget/touchmenu")
local ConfigDialog = require("ui/widget/configdialog")

-- Top menu (file browser / settings / tools / search): left page-turn
-- buttons switch tabs directly (one press, any focus state); right
-- page-turn buttons keep their normal item-list pagination.
local orig_touchmenu_init = TouchMenu.init
TouchMenu.init = function(self, ...)
    orig_touchmenu_init(self, ...)
    self.key_events.NextPage = { { "RPgFwd" } }
    self.key_events.PrevPage = { { "RPgBack" } }
    self.key_events.NextTab = { { "LPgFwd" } }
    self.key_events.PrevTab = { { "LPgBack" } }
end

-- "+"-style and exit/help-style icons are marked remember == false (they're
-- action popups, not real content tabs) -- step over them.
local function isRealTab(tab_item_table, idx)
    local t = tab_item_table[idx]
    return t and t.remember ~= false
end

function TouchMenu:onNextTab()
    local ntabs = #self.tab_item_table
    if ntabs > 1 then
        local idx = self.cur_tab
        for _ = 1, ntabs do
            idx = idx + 1
            if idx > ntabs then
                idx = 1
            end
            if isRealTab(self.tab_item_table, idx) then
                -- Go through the tab bar, not switchMenuTab directly, so
                -- the selected-tab icon highlight updates too.
                self.bar:switchToTab(idx)
                break
            end
        end
    end
    return true
end

function TouchMenu:onPrevTab()
    local ntabs = #self.tab_item_table
    if ntabs > 1 then
        local idx = self.cur_tab
        for _ = 1, ntabs do
            idx = idx - 1
            if idx < 1 then
                idx = ntabs
            end
            if isRealTab(self.tab_item_table, idx) then
                self.bar:switchToTab(idx)
                break
            end
        end
    end
    return true
end

-- Bottom (reader) menu: same idea, left page-turn buttons switch panels.
-- ConfigDialog has no existing page-turn bindings, so nothing to preserve
-- on the right side here.
local orig_configdialog_init = ConfigDialog.init
ConfigDialog.init = function(self, ...)
    orig_configdialog_init(self, ...)
    self.key_events.NextTab = { { "LPgFwd" } }
    self.key_events.PrevTab = { { "LPgBack" } }
end

function ConfigDialog:onNextTab()
    local npanels = #self.config_options
    if npanels > 1 then
        local next_panel = self.panel_index + 1
        if next_panel > npanels then
            next_panel = 1
        end
        self:onShowConfigPanel(next_panel)
    end
    return true
end

function ConfigDialog:onPrevTab()
    local npanels = #self.config_options
    if npanels > 1 then
        local prev_panel = self.panel_index - 1
        if prev_panel < 1 then
            prev_panel = npanels
        end
        self:onShowConfigPanel(prev_panel)
    end
    return true
end
