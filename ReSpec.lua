local addonName, ReSpec = ...
local addon = CreateFrame("Frame")
local C = ReSpec.Colors

local widget
local mainButton
local chevron
local secondaryButtons = {}
local initialized = false
local lootSpecPopup

local UpdateSpecs

local DEFAULT_BUTTON_SIZE = 42
local SECONDARY_SCALE = 0.92
local BUTTON_GAP = 6
local CHEVRON_WIDTH = 2
local ANIMATION_SPEED = 14
local HOVER_PADDING = 6
local COLLAPSE_DELAY = 1.5
local MAX_SECONDARY_BUTTONS = 3

local function EnsureDB()
    ReSpec_EnsureDB()
end

local function GetDB()
    return ReSpec_GetDB()
end

local function GetExpandDirection()
    return GetDB().expandDirection or "right"
end

local function ShouldReverseOrder()
    return GetDB().reverseOrder == true
end

local function GetRightClickAction()
    return GetDB().rightClickAction or "settings"
end

local function GetButtonSize()
    return GetDB().buttonSize or DEFAULT_BUTTON_SIZE
end

local function GetLootCheckboxSize()
    local buttonSize = GetButtonSize()
    return math.max(12, math.floor(buttonSize * 0.43 + 0.5))
end

local function GetLootCheckboxOffset()
    local buttonSize = GetButtonSize()
    return math.max(1, math.floor(buttonSize * 0.05 + 0.5))
end

local function ShouldShowTooltips()
    return GetDB().showTooltips ~= false
end

local function IsLootSpecSelectorEnabled()
    return GetDB().lootSpecEnabled ~= false and GetRightClickAction() ~= "lootspec"
end

local function ComputeWidgetAlpha(isHovered)
    local db = GetDB()

    if not db.useCustomOpacity then
        return 1
    end

    if isHovered and db.fullOpacityOnHover then
        return 1
    end

    local value = math.max(10, math.min(90, db.transparency or 90))
    return value / 100
end

local function IsMouseOverReSpecUI()
    if widget and MouseIsOver(widget) then
        return true
    end

    if lootSpecPopup and lootSpecPopup:IsShown() and MouseIsOver(lootSpecPopup) then
        return true
    end

    if mainButton and mainButton.lootCheck and mainButton.lootCheck:IsShown() and MouseIsOver(mainButton.lootCheck) then
        return true
    end

    for i = 1, #secondaryButtons do
        local button = secondaryButtons[i]
        if button and button.lootCheck and button.lootCheck:IsShown() and MouseIsOver(button.lootCheck) then
            return true
        end
    end

    return false
end

local function ShouldUseExpandedOpacity()
    if not widget then
        return false
    end

    if widget.isHovered then
        return true
    end

    if widget.collapseAt and widget.targetExpanded then
        return true
    end

    return false
end

local function SavePosition(frame)
    local db = GetDB()

    local cx, cy = frame:GetCenter()
    if not cx or not cy then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)

    db.x = cx
    db.y = cy
end

local function ShouldHideInCombat()
    return GetDB().hideInCombat == true
end

local function GetCurrentSpecIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end

    return GetSpecialization()
end

local function GetSpecData(specIndex)
    if not specIndex then
        return nil
    end

    local specID, name, _, icon

    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        specID, name, _, icon = C_SpecializationInfo.GetSpecializationInfo(specIndex)
    else
        specID, name, _, icon = GetSpecializationInfo(specIndex)
    end

    if not specID then
        return nil
    end

    return {
        specIndex = specIndex,
        specID = specID,
        name = name,
        icon = icon,
    }
end

local function GetVisibleSpecs()
    local specs = {}
    local count = GetNumSpecializations() or 0

    for specIndex = 1, count do
        local data = GetSpecData(specIndex)
        if data then
            specs[#specs + 1] = data
        end
    end

    return specs
end

local function GetLootSpecMode()
    return GetLootSpecialization() or 0
end

local function HideLootSpecPopup()
    if lootSpecPopup then
        lootSpecPopup:Hide()
        lootSpecPopup.anchorButton = nil
    end
end

local function UpdateVisibility()
    if not widget then
        return
    end

    if ShouldHideInCombat() and InCombatLockdown() then
        HideLootSpecPopup()
        widget:Hide()
        return
    end

    UpdateSpecs()
end

local function OpenSettings()
    HideLootSpecPopup()

    if ReSpecSettingsCategory then
        Settings.OpenToCategory(ReSpecSettingsCategory:GetID())
    else
        print("|cffff7f7f[ReSpec]|r Settings not ready yet.")
    end
end

local function OpenTalents()
    HideLootSpecPopup()

    if PlayerSpellsFrame and PlayerSpellsFrame:IsShown() then
        HideUIPanel(PlayerSpellsFrame)
        return
    end

    if PlayerSpellsMicroButton and PlayerSpellsMicroButton.Click then
        PlayerSpellsMicroButton:Click()
        return
    end

    if TogglePlayerSpellsFrame then
        TogglePlayerSpellsFrame()
        return
    end

    if ToggleTalentFrame then
        ToggleTalentFrame()
        return
    end
end

local function ReverseTableInPlace(t)
    local left = 1
    local right = #t

    while left < right do
        t[left], t[right] = t[right], t[left]
        left = left + 1
        right = right - 1
    end
end

local function ShouldNormalizeDirectionOrder(direction)
    return direction == "left" or direction == "up"
end

local function ApplyInactiveSpecOrder(inactiveSpecs)
    local direction = GetExpandDirection()

    if ShouldNormalizeDirectionOrder(direction) then
        ReverseTableInPlace(inactiveSpecs)
    end

    if ShouldReverseOrder() then
        ReverseTableInPlace(inactiveSpecs)
    end
end

local function SwitchToSpec(specIndex)
    if not specIndex then
        return
    end

    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("Cannot change specialization in combat.", 1.0, 0.1, 0.1)
        return
    end

    if GetCurrentSpecIndex() == specIndex then
        return
    end

    if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
        C_SpecializationInfo.SetSpecialization(specIndex)
    else
        SetSpecialization(specIndex)
    end
end

local function IsCurrentSpecButton(button)
    if not button or not button.specData then
        return false
    end

    local currentSpec = GetSpecData(GetCurrentSpecIndex())
    return currentSpec and currentSpec.specID == button.specData.specID
end

local function GetLootCheckboxState(button)
    if not button or not button.specData then
        return "none"
    end

    local lootSpecMode = GetLootSpecMode()
    local specID = button.specData.specID

    if IsCurrentSpecButton(button) then
        if lootSpecMode == 0 then
            return "current"
        end

        if lootSpecMode == specID then
            return "explicit"
        end

        return "none"
    end

    if lootSpecMode == specID then
        return "explicit"
    end

    return "none"
end

local function SetLootSpecFromButton(button)
    if not button or not button.specData then
        return
    end

    local specID = button.specData.specID
    local lootSpecMode = GetLootSpecMode()

    if IsCurrentSpecButton(button) then
        if lootSpecMode == 0 then
            SetLootSpecialization(specID)
        elseif lootSpecMode == specID then
            SetLootSpecialization(0)
        else
            SetLootSpecialization(specID)
        end
        return
    end

    SetLootSpecialization(specID)
end

local function ShowLootSpecTooltip(owner, button)
    if not ShouldShowTooltips() or not button or not button.specData then
        return
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")

    local state = GetLootCheckboxState(button)

    if state == "current" then
        GameTooltip:SetText("Current loot specialization", 0.3, 1, 0.3)
        GameTooltip:AddLine("Click to lock loot to this specialization.", 0.8, 0.8, 0.8, true)
    elseif state == "explicit" then
        if IsCurrentSpecButton(button) then
            GameTooltip:SetText("Loot locked to this specialization", 1, 0.82, 0)
            GameTooltip:AddLine("Click to switch back to Current Specialization.", 0.8, 0.8, 0.8, true)
        else
            GameTooltip:SetText("Current loot specialization", 1, 0.82, 0)
        end
    else
        GameTooltip:SetText("Set loot specialization", 1, 1, 1)
    end

    GameTooltip:Show()
end

local function UpdateLootSpecCheckbox(button)
    if not button or not button.lootCheck or not button.specData then
        return
    end

    if not IsLootSpecSelectorEnabled() then
        button.lootCheck:Hide()
        return
    end

    button.lootCheck:Show()

    local state = GetLootCheckboxState(button)

    if state == "current" then
        button.lootCheck.check:Show()
        C.ApplyTexture(button.lootCheck.bg, C.BG_CHECKBOX_GREEN)
        button.lootCheck.check:SetVertexColor(unpack(C.GREEN_FULL))
    elseif state == "explicit" then
        button.lootCheck.check:Show()
        C.ApplyTexture(button.lootCheck.bg, C.BG_CHECKBOX_GOLD)
        button.lootCheck.check:SetVertexColor(unpack(C.GOLD_FULL))
    else
        button.lootCheck.check:Hide()
        C.ApplyTexture(button.lootCheck.bg, C.BG_DARK_SOFT)
        button.lootCheck.check:SetVertexColor(unpack(C.GOLD_FULL))
    end
end

local function RefreshLootSpecCheckboxes()
    if mainButton and mainButton.specData then
        UpdateLootSpecCheckbox(mainButton)
    end

    for i = 1, #secondaryButtons do
        local button = secondaryButtons[i]
        if button and button.specData then
            UpdateLootSpecCheckbox(button)
        end
    end
end

local function PositionLootSpecPopup()
    if not lootSpecPopup or not mainButton or not mainButton:IsShown() then
        return
    end

    local popupWidth = lootSpecPopup:GetWidth() or 0
    local popupHeight = lootSpecPopup:GetHeight() or 0

    local centerX = mainButton:GetCenter()
    local top = mainButton:GetTop()
    local bottom = mainButton:GetBottom()

    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()

    if not centerX or not top or not bottom or not screenWidth or not screenHeight then
        return
    end

    local screenPadding = 16
    local verticalGap = 6

    local left = centerX - (popupWidth / 2)
    left = math.max(screenPadding, math.min(left, screenWidth - screenPadding - popupWidth))

    local showBelow = (top + verticalGap + popupHeight) > (screenHeight - screenPadding)

    lootSpecPopup:ClearAllPoints()

    if showBelow then
        local topY = bottom - verticalGap
        lootSpecPopup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, topY)
    else
        local bottomY = top + verticalGap
        lootSpecPopup:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottomY)
    end
end

local function EnsureLootSpecPopup()
    if lootSpecPopup then
        return
    end

    lootSpecPopup = CreateFrame("Frame", addonName .. "LootSpecPopup", UIParent, "BackdropTemplate")
    lootSpecPopup:SetFrameStrata("DIALOG")
    lootSpecPopup:SetFrameLevel(120)
    lootSpecPopup:SetClampedToScreen(true)
    lootSpecPopup:EnableMouse(true)
    lootSpecPopup:Hide()

    lootSpecPopup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    lootSpecPopup:SetBackdropColor(unpack(C.BG_POPUP_BACKDROP))
    lootSpecPopup:SetBackdropBorderColor(unpack(C.BORDER_POPUP))

    lootSpecPopup.rows = {}
    lootSpecPopup.anchorButton = nil
    lootSpecPopup._mouseWasDown = false

    lootSpecPopup:SetScript("OnUpdate", function(self)
        if not self:IsShown() then
            return
        end

        if self.anchorButton and not self._mouseWasDown then
            if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                self._mouseWasDown = true
                if not MouseIsOver(self) and not MouseIsOver(self.anchorButton) then
                    HideLootSpecPopup()
                end
            end
        elseif self._mouseWasDown then
            if not IsMouseButtonDown("LeftButton") and not IsMouseButtonDown("RightButton") then
                self._mouseWasDown = false
            end
        end
    end)
end

local function CreateLootSpecPopupRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(34)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    C.ApplyTexture(row.bg, C.BG_DARK)

    row.separator = row:CreateTexture(nil, "BORDER")
    row.separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.separator:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.separator:SetHeight(1)
    C.ApplyTexture(row.separator, C.BORDER_DIM)

    row.selectedBg = row:CreateTexture(nil, "ARTWORK")
    row.selectedBg:SetAllPoints()
    C.ApplyTexture(row.selectedBg, C.BG_SELECTED)
    row.selectedBg:Hide()

    row.selectedTop = row:CreateTexture(nil, "OVERLAY")
    row.selectedTop:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.selectedTop:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.selectedTop:SetHeight(1)
    C.ApplyTexture(row.selectedTop, C.GOLD_FULL)
    row.selectedTop:Hide()

    row.selectedBottom = row:CreateTexture(nil, "OVERLAY")
    row.selectedBottom:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.selectedBottom:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.selectedBottom:SetHeight(1)
    C.ApplyTexture(row.selectedBottom, C.GOLD_FULL)
    row.selectedBottom:Hide()

    row.selectedLeft = row:CreateTexture(nil, "OVERLAY")
    row.selectedLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.selectedLeft:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.selectedLeft:SetWidth(1)
    C.ApplyTexture(row.selectedLeft, C.GOLD_FULL)
    row.selectedLeft:Hide()

    row.selectedRight = row:CreateTexture(nil, "OVERLAY")
    row.selectedRight:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.selectedRight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.selectedRight:SetWidth(1)
    C.ApplyTexture(row.selectedRight, C.GOLD_FULL)
    row.selectedRight:Hide()

    row.indicatorBg = row:CreateTexture(nil, "ARTWORK")
    row.indicatorBg:SetSize(12, 12)
    row.indicatorBg:SetPoint("LEFT", row, "LEFT", 10, 0)
    row.indicatorBg:SetTexture("Interface\\Buttons\\WHITE8X8")
    C.ApplyTexture(row.indicatorBg, C.INDICATOR_BG)

    row.indicatorBorderTop = row:CreateTexture(nil, "OVERLAY")
    row.indicatorBorderTop:SetPoint("TOPLEFT", row.indicatorBg, "TOPLEFT", 0, 0)
    row.indicatorBorderTop:SetPoint("TOPRIGHT", row.indicatorBg, "TOPRIGHT", 0, 0)
    row.indicatorBorderTop:SetHeight(1)
    C.ApplyTexture(row.indicatorBorderTop, C.BORDER_LIGHT)

    row.indicatorBorderBottom = row:CreateTexture(nil, "OVERLAY")
    row.indicatorBorderBottom:SetPoint("BOTTOMLEFT", row.indicatorBg, "BOTTOMLEFT", 0, 0)
    row.indicatorBorderBottom:SetPoint("BOTTOMRIGHT", row.indicatorBg, "BOTTOMRIGHT", 0, 0)
    row.indicatorBorderBottom:SetHeight(1)
    C.ApplyTexture(row.indicatorBorderBottom, C.BORDER_LIGHT)

    row.indicatorBorderLeft = row:CreateTexture(nil, "OVERLAY")
    row.indicatorBorderLeft:SetPoint("TOPLEFT", row.indicatorBg, "TOPLEFT", 0, 0)
    row.indicatorBorderLeft:SetPoint("BOTTOMLEFT", row.indicatorBg, "BOTTOMLEFT", 0, 0)
    row.indicatorBorderLeft:SetWidth(1)
    C.ApplyTexture(row.indicatorBorderLeft, C.BORDER_LIGHT)

    row.indicatorBorderRight = row:CreateTexture(nil, "OVERLAY")
    row.indicatorBorderRight:SetPoint("TOPRIGHT", row.indicatorBg, "TOPRIGHT", 0, 0)
    row.indicatorBorderRight:SetPoint("BOTTOMRIGHT", row.indicatorBg, "BOTTOMRIGHT", 0, 0)
    row.indicatorBorderRight:SetWidth(1)
    C.ApplyTexture(row.indicatorBorderRight, C.BORDER_LIGHT)

    row.indicatorDot = row:CreateTexture(nil, "OVERLAY")
    row.indicatorDot:SetSize(6, 6)
    row.indicatorDot:SetPoint("CENTER", row.indicatorBg, "CENTER", 0, 0)
    row.indicatorDot:SetTexture("Interface\\Buttons\\WHITE8X8")
    C.ApplyTexture(row.indicatorDot, C.GOLD_FULL)
    row.indicatorDot:Hide()

    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.text:SetPoint("LEFT", row.indicatorBg, "RIGHT", 10, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.text:SetJustifyH("LEFT")

    row:SetScript("OnEnter", function(self)
        if not self.isSelected then
            C.ApplyTexture(self.bg, C.BG_HOVER)
        end
    end)

    row:SetScript("OnLeave", function(self)
        if not self.isSelected then
            C.ApplyTexture(self.bg, C.BG_DARK)
        end
    end)

    parent.rows[index] = row
    return row
end

local function SetLootSpecPopupRowSelected(row, isSelected)
    row.isSelected = isSelected == true

    if row.isSelected then
        row.selectedBg:Show()
        row.selectedTop:Show()
        row.selectedBottom:Show()
        row.selectedLeft:Show()
        row.selectedRight:Show()

        C.ApplyTexture(row.indicatorBg, C.BG_SELECTED_INDICATOR)
        C.ApplyTexture(row.indicatorBorderTop, C.GOLD_FULL)
        C.ApplyTexture(row.indicatorBorderBottom, C.GOLD_FULL)
        C.ApplyTexture(row.indicatorBorderLeft, C.GOLD_FULL)
        C.ApplyTexture(row.indicatorBorderRight, C.GOLD_FULL)
        row.indicatorDot:Show()

        row.text:SetTextColor(unpack(C.WHITE))
    else
        row.selectedBg:Hide()
        row.selectedTop:Hide()
        row.selectedBottom:Hide()
        row.selectedLeft:Hide()
        row.selectedRight:Hide()

        C.ApplyTexture(row.indicatorBg, C.INDICATOR_BG)
        C.ApplyTexture(row.indicatorBorderTop, C.BORDER_LIGHT)
        C.ApplyTexture(row.indicatorBorderBottom, C.BORDER_LIGHT)
        C.ApplyTexture(row.indicatorBorderLeft, C.BORDER_LIGHT)
        C.ApplyTexture(row.indicatorBorderRight, C.BORDER_LIGHT)
        row.indicatorDot:Hide()

        row.text:SetTextColor(unpack(C.WHITE_SOFT))
    end
end

local function RefreshLootSpecPopup()
    if not lootSpecPopup or not mainButton or not mainButton.specData then
        return
    end

    local currentSpec = GetSpecData(GetCurrentSpecIndex())
    local lootSpecMode = GetLootSpecMode()
    local specs = GetVisibleSpecs()
    local entries = {}

    entries[#entries + 1] = {
        text = string.format("Current Specialization (%s)", currentSpec and currentSpec.name or UNKNOWN),
        selected = lootSpecMode == 0,
        onClick = function()
            SetLootSpecialization(0)
            RefreshLootSpecCheckboxes()
            RefreshLootSpecPopup()
        end,
    }

    for i = 1, #specs do
        local spec = specs[i]
        entries[#entries + 1] = {
            text = spec.name,
            selected = lootSpecMode == spec.specID,
            onClick = function()
                SetLootSpecialization(spec.specID)
                RefreshLootSpecCheckboxes()
                RefreshLootSpecPopup()
            end,
        }
    end

    local rowHeight = 40
    local innerPadding = 4
    local width = 310
    local height = (#entries * rowHeight) + (innerPadding * 2)

    lootSpecPopup:SetSize(width, height)

    for i = 1, #entries do
        local row = lootSpecPopup.rows[i] or CreateLootSpecPopupRow(lootSpecPopup, i)
        local topY = -innerPadding - ((i - 1) * rowHeight)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", lootSpecPopup, "TOPLEFT", innerPadding, topY)
        row:SetPoint("TOPRIGHT", lootSpecPopup, "TOPRIGHT", -innerPadding, topY)
        row:SetHeight(rowHeight - 2)

        row.text:SetText(entries[i].text)
        SetLootSpecPopupRowSelected(row, entries[i].selected)
        row:SetScript("OnClick", entries[i].onClick)
        row:Show()
    end

    for i = #entries + 1, #lootSpecPopup.rows do
        lootSpecPopup.rows[i]:Hide()
    end

    if lootSpecPopup:IsShown() then
        PositionLootSpecPopup()
    end
end

local function OpenLootSpecPopup()
    EnsureLootSpecPopup()
    lootSpecPopup.anchorButton = mainButton
    lootSpecPopup._mouseWasDown = false
    RefreshLootSpecPopup()
    PositionLootSpecPopup()
    lootSpecPopup:Show()
end

local function HandleMainButtonRightClick()
    local action = GetRightClickAction()

    if action == "settings" then
        OpenSettings()
        return
    end

    if action == "talents" then
        OpenTalents()
        return
    end

    if action == "lootspec" then
        OpenLootSpecPopup()
        return
    end

    HideLootSpecPopup()
end

local function GetMainButtonRightClickTooltipText()
    local action = GetRightClickAction()

    if action == "settings" then
        return "Right click to open settings"
    end

    if action == "talents" then
        return "Right click to open talents"
    end

    if action == "lootspec" then
        return "Right click to change loot specialization"
    end

    return ""
end

local function ShowTooltip(button, specData)
    if not ShouldShowTooltips() then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_NONE")

    local direction = GetExpandDirection()
    local screenHeight = UIParent:GetHeight()

    local left = button:GetLeft()
    local top = button:GetTop()

    local tooltipPadding = 8
    local edgePadding = 140

    if direction == "up" or direction == "down" then
        if left and left < edgePadding then
            GameTooltip:SetPoint("LEFT", button, "RIGHT", tooltipPadding, 0)
        else
            GameTooltip:SetPoint("RIGHT", button, "LEFT", -tooltipPadding, 0)
        end
    else
        if top and top > (screenHeight - edgePadding) then
            GameTooltip:SetPoint("TOP", button, "BOTTOM", 0, -tooltipPadding)
        else
            GameTooltip:SetPoint("BOTTOM", button, "TOP", 0, tooltipPadding)
        end
    end

    GameTooltip:AddLine(specData.name or UNKNOWN, 1, 0.82, 0)
    GameTooltip:AddLine(" ")

    if specData.specIndex == GetCurrentSpecIndex() then
        GameTooltip:AddLine("Current specialization", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left click + SHIFT to drag", 0.7, 0.7, 0.7)
        local rightClickText = GetMainButtonRightClickTooltipText()
        if rightClickText ~= "" then
            GameTooltip:AddLine(rightClickText, 0.7, 0.7, 0.7)
        end
    else
        GameTooltip:AddLine("Click to switch", 0.2, 1, 0.2)
    end

    GameTooltip:Show()
end

local function UpdateHoverArea()
    if not widget or not mainButton then
        return
    end

    local width = mainButton:GetWidth() + (HOVER_PADDING * 2)
    local height = mainButton:GetHeight() + (HOVER_PADDING * 2)

    widget:SetSize(width, height)

    mainButton:ClearAllPoints()
    mainButton:SetPoint("TOPLEFT", widget, "TOPLEFT", HOVER_PADDING, -HOVER_PADDING)
end

local function BeginExpand()
    if not widget then
        return
    end

    widget.isHovered = true
    widget.targetExpanded = true
    widget.collapseAt = nil
end

local function BeginDelayedCollapse()
    if not widget then
        return
    end

    widget.isHovered = false
    widget.collapseAt = GetTime() + COLLAPSE_DELAY
end

local function CreateShadow(parent)
    local shadow = parent:CreateTexture(nil, "BACKGROUND", nil, -1)
    shadow:SetPoint("TOPLEFT", 4, -4)
    shadow:SetPoint("BOTTOMRIGHT", -4, 4)
    C.ApplyTexture(shadow, C.SHADOW)
    return shadow
end

local function UpdateButtonVisual(button, isActive, isMain)
    if isActive then
        button.hoverInnerGlow:Hide()
        button.icon:SetAlpha(1)
        button:SetScale(1.0)

        if button.border then
            button.border:SetScale(1.0)
            button.border:SetVertexColor(unpack(C.WHITE))
        end
    else
        button.hoverInnerGlow:Hide()
        button.icon:SetAlpha(0.88)
        button:SetScale(isMain and 1.0 or SECONDARY_SCALE)

        if button.border then
            button.border:SetScale(1.0)
            button.border:SetVertexColor(unpack(C.WHITE))
        end
    end
end

local function UpdateButtonHoverVisual(button, isHovered)
    if not button or not button.specData then
        return
    end

    local isCurrentSpec = button.specData.specIndex == GetCurrentSpecIndex()

    if isCurrentSpec then
        button.hoverInnerGlow:Hide()
        if button.border then
            button.border:SetVertexColor(unpack(C.WHITE))
        end
        return
    end

    if isHovered then
        button.hoverInnerGlow:Show()
        button.icon:SetAlpha(1)

        if button.border then
            button.border:SetVertexColor(unpack(C.GOLD_FULL))
            button.border:SetScale(1.06)
        end
    else
        button.hoverInnerGlow:Hide()
        button.icon:SetAlpha(0.88)

        if button.border then
            button.border:SetVertexColor(unpack(C.WHITE))
            button.border:SetScale(1.0)
        end
    end
end

local function CreateLootCheckbox(button)
    local box = CreateFrame("Button", nil, button)
    local size = GetLootCheckboxSize()
    local offset = GetLootCheckboxOffset()

    box:SetSize(size, size)
    box:SetPoint("TOPLEFT", button, "TOPLEFT", offset, -offset)
    box:RegisterForClicks("LeftButtonUp")

    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints()
    C.ApplyTexture(box.bg, C.BG_DARK_SOFT)

    box.check = box:CreateTexture(nil, "OVERLAY")
    box.check:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    box.check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    box.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    box.check:SetVertexColor(unpack(C.GOLD_FULL))
    box.check:Hide()

    box:SetScript("OnEnter", function(self)
        ShowLootSpecTooltip(self, button)
    end)

    box:SetScript("OnLeave", function()
        GameTooltip_Hide()
    end)

    box:SetScript("OnClick", function(self)
        SetLootSpecFromButton(button)
        RefreshLootSpecCheckboxes()

        if self:IsMouseOver() then
            ShowLootSpecTooltip(self, button)
        else
            GameTooltip_Hide()
        end
    end)

    return box
end

local function CreateSpecButton(parent, name)
    local button = CreateFrame("Button", addonName .. name, parent)
    local size = GetButtonSize()
    button:SetSize(size, size)

    button.shadow = CreateShadow(button)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    C.ApplyTexture(button.bg, C.BG_BUTTON)

    button.border = button:CreateTexture(nil, "BORDER")
    button.border:SetAllPoints()
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 5, -5)
    button.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.hoverGlow = button:CreateTexture(nil, "OVERLAY")
    button.hoverGlow:SetAllPoints()
    C.ApplyTexture(button.hoverGlow, C.HOVER_OVERLAY)
    button.hoverGlow:Hide()

    button.hoverInnerGlow = button:CreateTexture(nil, "OVERLAY", nil, 1)
    button.hoverInnerGlow:SetPoint("TOPLEFT", button.icon, -1, 1)
    button.hoverInnerGlow:SetPoint("BOTTOMRIGHT", button.icon, 1, -1)
    C.ApplyTexture(button.hoverInnerGlow, C.HOVER_INNER)
    button.hoverInnerGlow:SetBlendMode("ADD")
    button.hoverInnerGlow:Hide()

    button.pushedShade = button:CreateTexture(nil, "OVERLAY")
    button.pushedShade:SetAllPoints()
    C.ApplyTexture(button.pushedShade, C.PUSHED_SHADE)
    button.pushedShade:Hide()

    button.lootCheck = CreateLootCheckbox(button)

    button:SetScript("OnEnter", function(self)
        BeginExpand()
        self.hoverGlow:Show()
        UpdateButtonHoverVisual(self, true)

        if widget and widget.isDragging then
            return
        end

        if self.specData then
            ShowTooltip(self, self.specData)
        end
    end)

    button:SetScript("OnLeave", function(self)
        self.hoverGlow:Hide()
        UpdateButtonHoverVisual(self, false)

        if GameTooltip:GetOwner() == self then
            GameTooltip_Hide()
        end

        if not IsMouseOverReSpecUI() then
            BeginDelayedCollapse()
        end
    end)

    button:SetScript("OnMouseDown", function(self)
        self.pushedShade:Show()
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", 6, -6)
        self.icon:SetPoint("BOTTOMRIGHT", -4, 4)
    end)

    button:SetScript("OnMouseUp", function(self)
        self.pushedShade:Hide()
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", 5, -5)
        self.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    end)

    button:SetScript("OnClick", function(self)
        if self.specData and self.specData.specIndex ~= GetCurrentSpecIndex() then
            HideLootSpecPopup()
            SwitchToSpec(self.specData.specIndex)
        end
    end)

    return button
end

local function GetAxisSizes(count)
    local size = GetButtonSize()
    local mainSpan = size + BUTTON_GAP + CHEVRON_WIDTH
    local secondarySpan = 0

    if count > 0 then
        secondarySpan = BUTTON_GAP + (count * size) + ((count - 1) * BUTTON_GAP)
    end

    return mainSpan, secondarySpan
end

local function LayoutStatic()
    local direction = GetExpandDirection()
    local size = GetButtonSize()

    mainButton:ClearAllPoints()
    mainButton:SetPoint("TOPLEFT", widget, "TOPLEFT", HOVER_PADDING, -HOVER_PADDING)

    chevron:ClearAllPoints()
    chevron:SetAtlas("UI-HUD-ActionBar-Flyout")
    chevron:SetBlendMode("BLEND")
    chevron:SetVertexColor(unpack(C.WHITE))
    chevron:SetRotation(0)
    chevron:SetSize(18, 7)

    local spacing = 4
    local offset = (size / 2) + spacing

    if direction == "right" then
        chevron:SetPoint("CENTER", mainButton, "CENTER", offset, 0)
        chevron:SetRotation(-math.pi / 2)
    elseif direction == "left" then
        chevron:SetPoint("CENTER", mainButton, "CENTER", -offset, 0)
        chevron:SetRotation(math.pi / 2)
    elseif direction == "up" then
        chevron:SetPoint("CENTER", mainButton, "CENTER", 0, offset)
        chevron:SetRotation(0)
    else
        chevron:SetPoint("CENTER", mainButton, "CENTER", 0, -offset)
        chevron:SetRotation(math.pi)
    end
end

local function PositionSecondaryButtons(progress)
    local direction = GetExpandDirection()
    local size = GetButtonSize()

    for i = 1, #secondaryButtons do
        local button = secondaryButtons[i]
        if button.specData then
            button:ClearAllPoints()

            if direction == "right" then
                local finalX = BUTTON_GAP + CHEVRON_WIDTH + BUTTON_GAP + ((i - 1) * (size + BUTTON_GAP))
                local hiddenX = BUTTON_GAP + CHEVRON_WIDTH - 10
                local x = hiddenX + ((finalX - hiddenX) * progress)
                button:SetPoint("LEFT", mainButton, "RIGHT", x, 0)
            elseif direction == "left" then
                local finalX = -(BUTTON_GAP + CHEVRON_WIDTH + BUTTON_GAP + (i * size) + ((i - 1) * BUTTON_GAP))
                local hiddenX = -(BUTTON_GAP + CHEVRON_WIDTH) + 10
                local x = hiddenX + ((finalX - hiddenX) * progress)
                button:SetPoint("LEFT", mainButton, "LEFT", x, 0)
            elseif direction == "up" then
                local finalY = BUTTON_GAP + CHEVRON_WIDTH + BUTTON_GAP + ((i - 1) * (size + BUTTON_GAP))
                local hiddenY = BUTTON_GAP + CHEVRON_WIDTH - 10
                local y = hiddenY + ((finalY - hiddenY) * progress)
                button:SetPoint("BOTTOM", mainButton, "TOP", 0, y)
            else
                local finalY = -(BUTTON_GAP + CHEVRON_WIDTH + BUTTON_GAP + (i * size) + ((i - 1) * BUTTON_GAP))
                local hiddenY = -(BUTTON_GAP + CHEVRON_WIDTH) + 10
                local y = hiddenY + ((finalY - hiddenY) * progress)
                button:SetPoint("BOTTOM", mainButton, "BOTTOM", 0, y)
            end

            button:SetAlpha(progress)

            if progress > 0.03 then
                button:Show()
                if IsLootSpecSelectorEnabled() then
                    button.lootCheck:Show()
                end
            else
                button:Hide()
                button.hoverGlow:Hide()
                button.hoverInnerGlow:Hide()
                button.lootCheck:Hide()
            end
        else
            button:Hide()
        end
    end
end

local function EnsureUI()
    if initialized then
        return
    end

    EnsureDB()

    local db = GetDB()
    local size = GetButtonSize()

    widget = CreateFrame("Frame", addonName .. "Widget", UIParent)
    widget:SetSize(size + (HOVER_PADDING * 2), size + (HOVER_PADDING * 2))
    widget:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.x, db.y)
    widget:SetFrameStrata("MEDIUM")
    widget:SetFrameLevel(20)
    widget:SetMovable(true)
    widget:EnableMouse(true)
    widget:SetClampedToScreen(true)

    widget.targetExpanded = false
    widget.isHovered = false
    widget.collapseAt = nil
    widget.secondaryCount = 0
    widget.currentOffset = 0
    widget.isDragging = false
    widget.dragOffsetX = 0
    widget.dragOffsetY = 0
    widget.currentAlpha = ComputeWidgetAlpha(false)

    widget:SetScript("OnEnter", BeginExpand)
    widget:SetScript("OnLeave", BeginDelayedCollapse)

    mainButton = CreateSpecButton(widget, "MainButton")
    UpdateHoverArea()

    mainButton:SetFrameLevel(widget:GetFrameLevel() + 20)
    mainButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    mainButton:SetScript("OnClick", nil)
    mainButton:SetScript("OnMouseDown", nil)
    mainButton:SetScript("OnMouseUp", nil)
    mainButton.pushedShade:Hide()

    if mainButton.shadow then
        mainButton.shadow:Hide()
    end

    if mainButton.border then
        mainButton.border:Hide()
    end

    mainButton:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton ~= "LeftButton" then
            return
        end

        if not IsShiftKeyDown() then
            return
        end

        local scale = UIParent:GetEffectiveScale()
        local cursorX, cursorY = GetCursorPosition()
        cursorX = cursorX / scale
        cursorY = cursorY / scale

        local centerX, centerY = widget:GetCenter()

        if not centerX or not centerY then
            return
        end

        widget.isDragging = true
        widget.dragOffsetX = cursorX - centerX
        widget.dragOffsetY = cursorY - centerY

        BeginExpand()
        GameTooltip_Hide()
    end)

    mainButton:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "RightButton" then
            HandleMainButtonRightClick()
            return
        end

        if widget.isDragging then
            widget.isDragging = false
            SavePosition(widget)

            if not IsMouseOverReSpecUI() then
                BeginDelayedCollapse()
            end
        end
    end)

    chevron = mainButton:CreateTexture(nil, "OVERLAY", nil, 2)
    chevron:SetAtlas("UI-HUD-ActionBar-Flyout")
    chevron:SetBlendMode("BLEND")
    chevron:SetVertexColor(unpack(C.WHITE))

    for i = 1, MAX_SECONDARY_BUTTONS do
        secondaryButtons[i] = CreateSpecButton(widget, "SecondaryButton" .. i)
        secondaryButtons[i]:SetFrameLevel(widget:GetFrameLevel() + 5)
    end

    widget:SetScript("OnUpdate", function(self, elapsed)
        if self.isDragging then
            GameTooltip_Hide()
            HideLootSpecPopup()

            local scale = UIParent:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale

            local newCenterX = cursorX - self.dragOffsetX
            local newCenterY = cursorY - self.dragOffsetY

            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", newCenterX, newCenterY)
        end

        if self.collapseAt and not self.isHovered and not IsMouseOverReSpecUI() and GetTime() >= self.collapseAt then
            self.targetExpanded = false
            self.collapseAt = nil
            HideLootSpecPopup()
        end

        local _, maxSecondarySpan = GetAxisSizes(self.secondaryCount)
        local targetSecondarySpan = self.targetExpanded and maxSecondarySpan or 0

        local diff = targetSecondarySpan - self.currentOffset
        if math.abs(diff) < 0.5 then
            self.currentOffset = targetSecondarySpan
        else
            self.currentOffset = self.currentOffset + diff * math.min(elapsed * ANIMATION_SPEED, 1)
        end

        local progress = 0
        if maxSecondarySpan > 0 then
            progress = math.min(1, math.max(0, self.currentOffset / maxSecondarySpan))
        end

        local targetAlpha = ComputeWidgetAlpha(ShouldUseExpandedOpacity())
        local alphaDiff = targetAlpha - (self.currentAlpha or targetAlpha)

        if math.abs(alphaDiff) < 0.01 then
            self.currentAlpha = targetAlpha
        else
            self.currentAlpha = (self.currentAlpha or targetAlpha) + alphaDiff * math.min(elapsed * 12, 1)
        end

        self:SetAlpha(self.currentAlpha)

        PositionSecondaryButtons(progress)
    end)

    initialized = true
end

UpdateSpecs = function()
    EnsureUI()
    if not initialized then
        return
    end

    if ShouldHideInCombat() and InCombatLockdown() then
        HideLootSpecPopup()
        widget:Hide()
        return
    end

    local specs = GetVisibleSpecs()
    local currentSpec = GetCurrentSpecIndex()

    if #specs <= 1 then
        HideLootSpecPopup()
        widget:Hide()
        return
    end

    local activeSpec
    local inactiveSpecs = {}

    for i = 1, #specs do
        local spec = specs[i]
        if spec.specIndex == currentSpec then
            activeSpec = spec
        else
            inactiveSpecs[#inactiveSpecs + 1] = spec
        end
    end

    ApplyInactiveSpecOrder(inactiveSpecs)

    if not activeSpec then
        HideLootSpecPopup()
        widget:Hide()
        return
    end

    mainButton.specData = activeSpec
    mainButton.icon:SetTexture(activeSpec.icon or 134400)
    UpdateButtonVisual(mainButton, true, true)
    mainButton:Show()

    widget.secondaryCount = math.min(#inactiveSpecs, MAX_SECONDARY_BUTTONS)

    for i = 1, #secondaryButtons do
        local button = secondaryButtons[i]
        local spec = inactiveSpecs[i]

        if spec and i <= MAX_SECONDARY_BUTTONS then
            button.specData = spec
            button.icon:SetTexture(spec.icon or 134400)
            UpdateButtonVisual(button, false, false)
            button:SetAlpha(0)

            if widget.targetExpanded then
                button:Show()
            else
                button:Hide()
            end
        else
            button.specData = nil
            button:Hide()
            button.hoverGlow:Hide()
            button.hoverInnerGlow:Hide()
            button.lootCheck:Hide()
        end
    end

    LayoutStatic()
    RefreshLootSpecCheckboxes()
    RefreshLootSpecPopup()

    widget.currentAlpha = ComputeWidgetAlpha(widget.isHovered)
    widget:SetAlpha(widget.currentAlpha)

    widget:Show()
end

function ReSpec_RefreshLayout()
    EnsureDB()

    if not initialized or not widget then
        return
    end

    local db = GetDB()
    local size = GetButtonSize()
    local lootBoxSize = GetLootCheckboxSize()
    local lootBoxOffset = GetLootCheckboxOffset()

    widget.currentOffset = 0
    widget.targetExpanded = false
    widget.collapseAt = nil
    widget.isDragging = false

    GameTooltip_Hide()
    HideLootSpecPopup()

    widget:SetSize(size + (HOVER_PADDING * 2), size + (HOVER_PADDING * 2))
    mainButton:SetSize(size, size)

    if mainButton.lootCheck then
        mainButton.lootCheck:SetSize(lootBoxSize, lootBoxSize)
        mainButton.lootCheck:ClearAllPoints()
        mainButton.lootCheck:SetPoint("TOPLEFT", mainButton, "TOPLEFT", lootBoxOffset, -lootBoxOffset)
    end

    for i = 1, #secondaryButtons do
        secondaryButtons[i]:SetSize(size, size)

        if secondaryButtons[i].lootCheck then
            secondaryButtons[i].lootCheck:SetSize(lootBoxSize, lootBoxSize)
            secondaryButtons[i].lootCheck:ClearAllPoints()
            secondaryButtons[i].lootCheck:SetPoint("TOPLEFT", secondaryButtons[i], "TOPLEFT", lootBoxOffset,
                -lootBoxOffset)
        end
    end

    widget:ClearAllPoints()
    widget:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.x, db.y)

    UpdateHoverArea()
    UpdateVisibility()
    RefreshLootSpecCheckboxes()
end

addon:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        EnsureUI()
        UpdateVisibility()
        RefreshLootSpecCheckboxes()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        UpdateVisibility()
        RefreshLootSpecCheckboxes()
        RefreshLootSpecPopup()
        return
    end

    if event == "PLAYER_LOOT_SPEC_UPDATED" then
        RefreshLootSpecCheckboxes()
        RefreshLootSpecPopup()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        HideLootSpecPopup()

        if widget and ShouldHideInCombat() then
            widget:Hide()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        UpdateVisibility()
        RefreshLootSpecCheckboxes()
        return
    end
end)

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
addon:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
addon:RegisterEvent("PLAYER_REGEN_DISABLED")
addon:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_RESPEC1 = "/respec"

SlashCmdList["RESPEC"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "config" then
        OpenSettings()
        return
    end

    print("|cff00ff98ReSpec|r commands:")
    print("|cff00ff98/respec config|r - open settings")
end
