local addonName, ReSpec = ...
ReSpecSettingsCategory = nil

local C = ReSpec.Colors

-- ======================================================
-- LABELS / DISPLAY TEXT
-- ======================================================

local directionLabels = {
    left = "Left",
    right = "Right",
    up = "Up",
    down = "Down",
}

local rightClickActionLabels = {
    settings = "Open settings",
    talents = "Open talents",
    lootspec = "Change loot spec",
    nothing = "Do nothing",
}

-- ======================================================
-- LAYOUT CONSTANTS
-- ======================================================

local LEFT_MARGIN = 26
local TOP_MARGIN = -24
local SECTION_SPACING = 18
local ROW_SPACING = 6
local ROW_HEIGHT = 34
local LABEL_WIDTH = 220
local DROPDOWN_WIDTH = 180
local CONTROL_OFFSET = LABEL_WIDTH + 32

local SECTION_HEADER_OFFSET = 0
local ROW_INDENT = 16
local RIGHT_PADDING = 20

-- ======================================================
-- LOCAL STATE
-- ======================================================

local settingsRows = {}
local settingsPanel = nil
local settingsSubtitle = nil
local settingsContentRoot = nil

-- ======================================================
-- BASIC HELPERS
-- ======================================================

local function EnsureDB()
    ReSpec_EnsureDB()
end

local function RefreshLayout()
    if ReSpec_RefreshLayout then
        ReSpec_RefreshLayout()
    end
end

local function RegisterSettingsRow(row)
    settingsRows[#settingsRows + 1] = row
    return row
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

-- ======================================================
-- SEARCHABLE SETTINGS REGISTRATION
-- These are used by Blizzard Settings search.
-- ======================================================

local function RegisterSearchableSettings(category)
    EnsureDB()

    Settings.RegisterProxySetting(
        category,
        "respec_hide_in_combat",
        Settings.VarType.Boolean,
        "Hide in combat",
        true,
        function()
            return ReSpecDB.hideInCombat == true
        end,
        function(value)
            ReSpecDB.hideInCombat = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_expand_direction",
        Settings.VarType.String,
        "Direction",
        "right",
        function()
            return ReSpecDB.expandDirection or "right"
        end,
        function(value)
            ReSpecDB.expandDirection = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_reverse_order",
        Settings.VarType.Boolean,
        "Reverse order",
        false,
        function()
            return ReSpecDB.reverseOrder == true
        end,
        function(value)
            ReSpecDB.reverseOrder = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_right_click_action",
        Settings.VarType.String,
        "Right click",
        "settings",
        function()
            return ReSpecDB.rightClickAction or "settings"
        end,
        function(value)
            ReSpecDB.rightClickAction = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_show_tooltips",
        Settings.VarType.Boolean,
        "Show tooltips",
        true,
        function()
            return ReSpecDB.showTooltips ~= false
        end,
        function(value)
            ReSpecDB.showTooltips = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_show_loot_spec_icon",
        Settings.VarType.Boolean,
        "Show loot spec icon",
        true,
        function()
            return ReSpecDB.showLootSpecIcon ~= false
        end,
        function(value)
            ReSpecDB.showLootSpecIcon = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_button_size",
        Settings.VarType.Number,
        "Scale",
        42,
        function()
            return ReSpecDB.buttonSize or 42
        end,
        function(value)
            ReSpecDB.buttonSize = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_use_custom_opacity",
        Settings.VarType.Boolean,
        "Opacity",
        false,
        function()
            return ReSpecDB.useCustomOpacity == true
        end,
        function(value)
            ReSpecDB.useCustomOpacity = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_transparency",
        Settings.VarType.Number,
        "Opacity value",
        90,
        function()
            return ReSpecDB.transparency or 90
        end,
        function(value)
            ReSpecDB.transparency = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_full_opacity_on_hover",
        Settings.VarType.Boolean,
        "Full opacity on hover",
        true,
        function()
            return ReSpecDB.fullOpacityOnHover == true
        end,
        function(value)
            ReSpecDB.fullOpacityOnHover = value
            RefreshLayout()
        end
    )

    Settings.RegisterProxySetting(
        category,
        "respec_show_hero_spec_icon",
        Settings.VarType.Boolean,
        "Show Hero Talent instead",
        false,
        function()
            return ReSpecDB.showHeroSpecIcon == true
        end,
        function(value)
            ReSpecDB.showHeroSpecIcon = value
            RefreshLayout()
            if ReSpec.UpdateSpecs then
                ReSpec.UpdateSpecs()
            end
        end
    )
end

-- ======================================================
-- TOP HEADER
-- ======================================================

local function CreateHeader(panel)
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(42, 42)
    logo:SetPoint("TOPLEFT", LEFT_MARGIN, TOP_MARGIN)
    logo:SetTexture("Interface\\AddOns\\ReSpec\\Assets\\ReSpec_Icon.png")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("LEFT", logo, "RIGHT", 10, 2)
    title:SetText("ReSpec")
    title:SetTextColor(1, 1, 1)

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetText("Quick spec switching button")
    subtitle:SetTextColor(0.8, 0.8, 0.8)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    C.ApplyTexture(divider, C.SETTINGS_DIVIDER)
    divider:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -10)
    divider:SetHeight(1)

    local resetButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    resetButton:SetSize(100, 30)
    resetButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -20)
    resetButton:SetText("Reset")

    panel.ResetButton = resetButton

    return divider
end

-- ======================================================
-- GENERIC BUILDING BLOCKS
-- ======================================================

local function CreateSectionHeader(parent, anchor, text)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -SECTION_SPACING)
    header:SetText(text)
    header:SetTextColor(1, 1, 1)

    -- local divider = parent:CreateTexture(nil, "ARTWORK")
    -- C.ApplyTexture(divider, C.SETTINGS_DIVIDER)
    -- divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    -- divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, -6)
    -- divider:SetHeight(1)

    local nextAnchor = CreateFrame("Frame", nil, parent)
    nextAnchor:SetSize(1, 1)
    nextAnchor:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)

    return nextAnchor
end

local function CreateRow(parent, anchor, height)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(height or ROW_HEIGHT)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -ROW_SPACING)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, 0)
    return row
end

local function CreateGoldLabel(parent, text)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetJustifyH("LEFT")
    C.ApplyText(label, C.SETTINGS_LABEL)
    label:SetText(text)
    return label
end

-- ======================================================
-- ROW FACTORIES
-- ======================================================

local function CreateCheckboxRow(parent, anchor, text, getValue, setValue)
    local row = CreateRow(parent, anchor, ROW_HEIGHT)

    local label = CreateGoldLabel(row, text)
    label:SetPoint("LEFT", row, "LEFT", 16, 0)

    local checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", row, "LEFT", CONTROL_OFFSET, 0)

    local function Refresh()
        checkbox:SetChecked(getValue())
    end

    checkbox:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        Refresh()
        RefreshLayout()
    end)

    row.Label = label
    row.Checkbox = checkbox
    row.Refresh = Refresh

    Refresh()
    return RegisterSettingsRow(row)
end

local function CreateDropdownRow(parent, anchor, text, options, getValue, setValue)
    local row = CreateRow(parent, anchor, ROW_HEIGHT)

    local label = CreateGoldLabel(row, text)
    label:SetPoint("LEFT", row, "LEFT", 16, 0)
    label:SetWidth(LABEL_WIDTH)

    local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
    dropdown:SetPoint("LEFT", row, "LEFT", CONTROL_OFFSET, 0)
    dropdown:SetWidth(DROPDOWN_WIDTH)

    local function UpdateDropdownText()
        local current = getValue()

        for _, option in ipairs(options) do
            if option.value == current then
                dropdown:SetDefaultText(option.label)
                return
            end
        end

        dropdown:SetDefaultText("")
    end

    dropdown:SetupMenu(function(_, rootDescription)
        for _, option in ipairs(options) do
            rootDescription:CreateRadio(
                option.label,
                function()
                    return getValue() == option.value
                end,
                function()
                    setValue(option.value)
                    UpdateDropdownText()
                    RefreshLayout()
                end
            )
        end
    end)

    row.Label = label
    row.Dropdown = dropdown
    row.Refresh = UpdateDropdownText

    UpdateDropdownText()
    return RegisterSettingsRow(row)
end

local function CreateSliderRow(parent, anchor, text, minValue, maxValue, getValue, setValue)
    local row = CreateRow(parent, anchor, ROW_HEIGHT)

    local label = CreateGoldLabel(row, text)
    label:SetPoint("LEFT", row, "LEFT", 16, 0)
    label:SetWidth(LABEL_WIDTH)

    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("LEFT", row, "LEFT", CONTROL_OFFSET, 0)
    slider:SetWidth(190)

    local options = Settings.CreateSliderOptions(minValue, maxValue, 1)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return math.floor(value + 0.5) .. "%"
    end)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Min, function()
        return ""
    end)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Max, function()
        return ""
    end)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Top, function()
        return ""
    end)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Left, function()
        return ""
    end)

    local function Refresh()
        slider:SetValue(Clamp(getValue(), minValue, maxValue))
    end

    slider:Init(
        Clamp(getValue(), minValue, maxValue),
        options.minValue,
        options.maxValue,
        options.steps,
        options.formatters
    )

    slider:RegisterCallback("OnValueChanged", function(_, value)
        setValue(Clamp(math.floor(value + 0.5), minValue, maxValue))
        RefreshLayout()
    end, slider)

    row.Label = label
    row.Slider = slider
    row.Refresh = Refresh

    Refresh()
    return RegisterSettingsRow(row)
end

local function CreateCheckboxSliderRow(parent, anchor, text, minValue, maxValue, getEnabled, setEnabled, getValue,
                                       setValue)
    local row = CreateRow(parent, anchor, ROW_HEIGHT)

    local label = CreateGoldLabel(row, text)
    label:SetPoint("LEFT", row, "LEFT", 16, 0)
    label:SetWidth(LABEL_WIDTH)

    local checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", row, "LEFT", CONTROL_OFFSET, 0)

    local slider = CreateFrame("Frame", nil, row, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("LEFT", checkbox, "RIGHT", 12, 0)
    slider:SetWidth(190)

    local options = Settings.CreateSliderOptions(minValue, maxValue, 1)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
        return math.floor(value + 0.5) .. "%"
    end)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Min, function()
        return ""
    end)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Max, function()
        return ""
    end)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Top, function()
        return ""
    end)
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Left, function()
        return ""
    end)

    local function UpdateEnabledState()
        local enabled = getEnabled()

        checkbox:SetChecked(enabled)
        slider:SetEnabled(enabled)
        slider:SetAlpha(enabled and 1 or 0.45)

        if slider.Backward then
            slider.Backward:SetEnabled(enabled)
            slider.Backward:SetAlpha(enabled and 1 or 0.45)
        end

        if slider.Forward then
            slider.Forward:SetEnabled(enabled)
            slider.Forward:SetAlpha(enabled and 1 or 0.45)
        end
    end

    local function Refresh()
        local value = Clamp(getValue(), minValue, maxValue)
        slider:SetValue(value)
        UpdateEnabledState()
    end

    slider:Init(
        Clamp(getValue(), minValue, maxValue),
        options.minValue,
        options.maxValue,
        options.steps,
        options.formatters
    )

    slider:RegisterCallback("OnValueChanged", function(_, value)
        setValue(Clamp(math.floor(value + 0.5), minValue, maxValue))
        RefreshLayout()
    end, slider)

    checkbox:SetScript("OnClick", function(self)
        setEnabled(self:GetChecked() and true or false)
        UpdateEnabledState()

        if row.dependents then
            for _, dep in ipairs(row.dependents) do
                if dep.Refresh then
                    dep:Refresh()
                end
            end
        end

        RefreshLayout()
    end)

    row.Label = label
    row.Checkbox = checkbox
    row.Slider = slider
    row.Refresh = Refresh

    Refresh()
    return RegisterSettingsRow(row)
end

local function CreateIndentedCheckboxRow(parent, anchor, text, isEnabled, getValue, setValue)
    local row = CreateRow(parent, anchor, ROW_HEIGHT)

    local label = CreateGoldLabel(row, text)
    label:SetPoint("LEFT", row, "LEFT", LEFT_MARGIN, 0)

    local checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", row, "LEFT", CONTROL_OFFSET + LEFT_MARGIN, 0)

    local function Refresh()
        local enabled = isEnabled()
        checkbox:SetEnabled(enabled)
        checkbox:SetAlpha(enabled and 1 or 0.45)
        label:SetAlpha(enabled and 1 or 0.45)
        checkbox:SetChecked(getValue())
    end

    checkbox:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        Refresh()
        RefreshLayout()
    end)

    row.Checkbox = checkbox
    row.Label = label
    row.Refresh = Refresh

    Refresh()
    return RegisterSettingsRow(row)
end

-- ======================================================
-- SECTION BUILDERS
-- ======================================================

local function BuildBehaviorSection(parent, anchor)
    local currentAnchor = CreateSectionHeader(parent, anchor, "Behavior")

    currentAnchor = CreateCheckboxRow(
        parent,
        currentAnchor,
        "Hide in combat",
        function()
            EnsureDB()
            return ReSpecDB.hideInCombat == true
        end,
        function(value)
            EnsureDB()
            ReSpecDB.hideInCombat = value
        end
    )

    currentAnchor = CreateCheckboxRow(
        parent,
        currentAnchor,
        "Show tooltips",
        function()
            EnsureDB()
            return ReSpecDB.showTooltips ~= false
        end,
        function(value)
            EnsureDB()
            ReSpecDB.showTooltips = value
        end
    )

    currentAnchor = CreateDropdownRow(
        parent,
        currentAnchor,
        "Right click action",
        {
            { value = "settings", label = rightClickActionLabels.settings },
            { value = "talents",  label = rightClickActionLabels.talents },
            { value = "lootspec", label = rightClickActionLabels.lootspec },
            { value = "nothing",  label = rightClickActionLabels.nothing },
        },
        function()
            EnsureDB()
            return ReSpecDB.rightClickAction or "settings"
        end,
        function(value)
            EnsureDB()
            ReSpecDB.rightClickAction = value
        end
    )

    return currentAnchor
end

local function BuildAppearanceSection(parent, anchor)
    local currentAnchor = CreateSectionHeader(parent, anchor, "Appearance")

    currentAnchor = CreateSliderRow(
        parent,
        currentAnchor,
        "Scale",
        50,
        150,
        function()
            EnsureDB()
            local size = ReSpecDB.buttonSize or 42
            return math.floor((size / 42) * 100 + 0.5)
        end,
        function(value)
            EnsureDB()
            ReSpecDB.buttonSize = math.floor((42 * value / 100) + 0.5)
        end
    )

    currentAnchor = CreateDropdownRow(
        parent,
        currentAnchor,
        "Direction",
        {
            { value = "left",  label = directionLabels.left },
            { value = "right", label = directionLabels.right },
            { value = "up",    label = directionLabels.up },
            { value = "down",  label = directionLabels.down },
        },
        function()
            EnsureDB()
            return ReSpecDB.expandDirection
        end,
        function(value)
            EnsureDB()
            ReSpecDB.expandDirection = value
        end
    )

    currentAnchor = CreateCheckboxRow(
        parent,
        currentAnchor,
        "Reverse order",
        function()
            EnsureDB()
            return ReSpecDB.reverseOrder == true
        end,
        function(value)
            EnsureDB()
            ReSpecDB.reverseOrder = value
        end
    )

    currentAnchor = CreateCheckboxRow(
        parent,
        currentAnchor,
        "Show Hero Talent instead",
        function()
            EnsureDB()
            return ReSpecDB.showHeroSpecIcon == true
        end,
        function(value)
            EnsureDB()
            ReSpecDB.showHeroSpecIcon = value
            if ReSpec.UpdateSpecs then
                ReSpec.UpdateSpecs()
            end
        end
    )

    currentAnchor = CreateCheckboxRow(
        parent,
        currentAnchor,
        "Show loot spec icon",
        function()
            EnsureDB()
            return ReSpecDB.showLootSpecIcon ~= false
        end,
        function(value)
            EnsureDB()
            ReSpecDB.showLootSpecIcon = value
        end
    )

    local opacityRow = CreateCheckboxSliderRow(
        parent,
        currentAnchor,
        "Opacity",
        10,
        90,
        function()
            EnsureDB()
            return ReSpecDB.useCustomOpacity == true
        end,
        function(value)
            EnsureDB()
            ReSpecDB.useCustomOpacity = value
        end,
        function()
            EnsureDB()
            return ReSpecDB.transparency or 90
        end,
        function(value)
            EnsureDB()
            ReSpecDB.transparency = value
        end
    )

    currentAnchor = opacityRow

    local hoverRow = CreateIndentedCheckboxRow(
        parent,
        currentAnchor,
        "Full opacity on hover",
        function()
            EnsureDB()
            return ReSpecDB.useCustomOpacity == true
        end,
        function()
            EnsureDB()
            return ReSpecDB.fullOpacityOnHover == true
        end,
        function(value)
            EnsureDB()
            ReSpecDB.fullOpacityOnHover = value
        end
    )

    opacityRow.dependents = { hoverRow }
    currentAnchor = hoverRow

    return currentAnchor
end

-- ======================================================
-- SETTINGS CONTENT BUILDING
-- ======================================================

local function BuildSettingsContent(panel, subtitle)
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)

    if scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:Hide()
        scrollFrame.ScrollBar:Disable()
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(700)
    content:SetHeight(1)

    scrollFrame:SetScrollChild(content)

    local topAnchor = CreateFrame("Frame", nil, content)
    topAnchor:SetSize(1, 1)
    topAnchor:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    local anchor = BuildBehaviorSection(content, topAnchor)
    anchor = BuildAppearanceSection(content, anchor)

    return content
end

local function RebuildSettingsContent()
    settingsRows = {}

    if settingsContentRoot then
        settingsContentRoot:Hide()
        settingsContentRoot:SetParent(nil)
        settingsContentRoot = nil
    end

    if settingsPanel and settingsSubtitle then
        settingsContentRoot = BuildSettingsContent(settingsPanel, settingsSubtitle)
    end
end

-- ======================================================
-- RESET FLOW
-- ======================================================

local function ResetSettings()
    ReSpec_ResetDB()
    RebuildSettingsContent()
    RefreshLayout()
end

StaticPopupDialogs["RESPEC_CONFIRM_RESET"] = {
    text = "Are you sure you want to reset these settings?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        ResetSettings()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ======================================================
-- SETTINGS PANEL CREATION
-- ======================================================

local function CreateSettingsPanel()
    EnsureDB()

    local panel = CreateFrame("Frame")
    panel.name = addonName

    local subtitle = CreateHeader(panel)

    settingsPanel = panel
    settingsSubtitle = subtitle
    settingsContentRoot = BuildSettingsContent(panel, subtitle)

    panel.ResetButton:SetScript("OnClick", function()
        StaticPopup_Show("RESPEC_CONFIRM_RESET")
    end)

    return panel
end

-- ======================================================
-- REGISTRATION
-- ======================================================

local function RegisterSettings()
    EnsureDB()

    local panel = CreateSettingsPanel()

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    RegisterSearchableSettings(category)
    Settings.RegisterAddOnCategory(category)

    ReSpecSettingsCategory = category
end

-- ======================================================
-- EVENT BOOTSTRAP
-- ======================================================

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", RegisterSettings)
