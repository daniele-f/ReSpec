local addonName = ...
ReSpecSettingsCategory = nil

local directionLabels = {
    left = "Left",
    right = "Right",
    up = "Up",
    down = "Down",
}

local rightClickActionLabels = {
    settings = "Open settings",
    talents = "Open talents",
    nothing = "Nothing",
}

local LEFT_MARGIN = 26
local TOP_MARGIN = -24
local SECTION_SPACING = 26
local ROW_SPACING = 10
local ROW_HEIGHT = 34
local LABEL_WIDTH = 220
local DROPDOWN_WIDTH = 180
local CONTROL_OFFSET = LABEL_WIDTH + 16

local function EnsureDB()
    ReSpec_EnsureDB()
end

local function RefreshLayout()
    if ReSpec_RefreshLayout then
        ReSpec_RefreshLayout()
    end
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

local function CreateHeader(panel)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", LEFT_MARGIN, TOP_MARGIN)
    title:SetText("ReSpec")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Quick spec switching widget")

    local reloadButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reloadButton:SetSize(140, 30)
    reloadButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -20, -20)
    reloadButton:SetText("Reload UI")
    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)

    return subtitle
end

local function CreateSectionHeader(parent, anchor, text)
    local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -SECTION_SPACING)
    header:SetText(text)

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.14)
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -20, -8)
    divider:SetHeight(1)

    local nextAnchor = CreateFrame("Frame", nil, parent)
    nextAnchor:SetSize(1, 1)
    nextAnchor:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -4)

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
    label:SetTextColor(1, 0.82, 0)
    label:SetText(text)
    return label
end

local function CreateCheckboxRow(parent, anchor, text, getValue, setValue)
    local row = CreateRow(parent, anchor, ROW_HEIGHT)

    local label = CreateGoldLabel(row, text)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)

    local checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", row, "LEFT", CONTROL_OFFSET, 0)
    checkbox:SetChecked(getValue())

    checkbox:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        RefreshLayout()
    end)

    row.Label = label
    row.Checkbox = checkbox
    return row
end

local function CreateDropdownRow(parent, anchor, text, options, getValue, setValue)
    local row = CreateRow(parent, anchor, ROW_HEIGHT)

    local label = CreateGoldLabel(row, text)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
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

    UpdateDropdownText()

    row.Label = label
    row.Dropdown = dropdown
    return row
end

local function CreateCheckboxSliderRow(parent, anchor, text, minValue, maxValue, getEnabled, setEnabled, getValue,
                                       setValue)
    local row = CreateRow(parent, anchor, ROW_HEIGHT)

    local label = CreateGoldLabel(row, text)
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(LABEL_WIDTH)

    local checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", row, "LEFT", CONTROL_OFFSET, 0)
    checkbox:SetChecked(getEnabled())

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

    local function SetSliderValue(value, shouldRefresh)
        value = Clamp(math.floor(value + 0.5), minValue, maxValue)
        setValue(value)
        slider:SetValue(value)

        if shouldRefresh then
            RefreshLayout()
        end
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
                if dep.UpdateState then
                    dep.UpdateState()
                end
            end
        end

        RefreshLayout()
    end)

    UpdateEnabledState()

    row.Label = label
    row.Checkbox = checkbox
    row.Slider = slider
    row.SetSliderValue = SetSliderValue
    row.UpdateEnabledState = UpdateEnabledState
    return row
end

local function CreateIndentedCheckboxRow(parent, anchor, text, isEnabled, getValue, setValue)
    local row = CreateRow(parent, anchor, ROW_HEIGHT)

    local label = CreateGoldLabel(row, text)
    label:SetPoint("LEFT", row, "LEFT", LEFT_MARGIN, 0)

    local checkbox = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    checkbox:SetPoint("LEFT", row, "LEFT", CONTROL_OFFSET + LEFT_MARGIN, 0)

    local function UpdateState()
        local enabled = isEnabled()
        checkbox:SetEnabled(enabled)
        checkbox:SetAlpha(enabled and 1 or 0.45)
        label:SetAlpha(enabled and 1 or 0.45)
        checkbox:SetChecked(getValue())
    end

    checkbox:SetScript("OnClick", function(self)
        setValue(self:GetChecked() and true or false)
        UpdateState()
        RefreshLayout()
    end)

    UpdateState()

    row.Checkbox = checkbox
    row.Label = label
    row.UpdateState = UpdateState
    return row
end

local function BuildGeneralSection(parent, anchor)
    local currentAnchor = CreateSectionHeader(parent, anchor, "General")

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

    currentAnchor = CreateDropdownRow(
        parent,
        currentAnchor,
        "Right click",
        {
            { value = "settings", label = rightClickActionLabels.settings },
            { value = "talents",  label = rightClickActionLabels.talents },
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

    local opacityRow = CreateCheckboxSliderRow(
        parent,
        currentAnchor,
        "Opacity",
        10,
        100,
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
            return ReSpecDB.transparency or 100
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

local function BuildSettingsContent(panel, subtitle)
    local topAnchor = CreateFrame("Frame", nil, panel)
    topAnchor:SetSize(1, 1)
    topAnchor:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, 0)

    BuildGeneralSection(panel, topAnchor)
end

local function CreateSettingsPanel()
    EnsureDB()

    local panel = CreateFrame("Frame")
    panel.name = addonName

    local subtitle = CreateHeader(panel)
    BuildSettingsContent(panel, subtitle)

    return panel
end

local function RegisterSettings()
    EnsureDB()

    local panel = CreateSettingsPanel()

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)

    ReSpecSettingsCategory = category
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", RegisterSettings)
