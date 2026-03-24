local addonName = ...
local addon = CreateFrame("Frame")

local widget
local mainButton
local chevron
local secondaryButtons = {}
local initialized = false

local UpdateSpecs

local BUTTON_SIZE = 42
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
    return GetDB().expandDirection or "left"
end

local function ShouldReverseOrder()
    return GetDB().reverseOrder == true
end

local function GetRightClickAction()
    return GetDB().rightClickAction or "settings"
end

local function ComputeWidgetAlpha(isHovered)
    local db = GetDB()

    if not db.useCustomOpacity then
        return 1
    end

    if isHovered and db.fullOpacityOnHover then
        return 1
    end

    local value = db.transparency or 100
    return math.max(0.1, math.min(1, value / 100))
end

local function SavePosition(frame)
    local db = GetDB()

    local left = frame:GetLeft()
    local top = frame:GetTop()
    if not left or not top then
        return
    end

    local y = top - UIParent:GetHeight()

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, y)

    db.x = left
    db.y = y
end

local function ShouldHideInCombat()
    return GetDB().hideInCombat == true
end

local function UpdateVisibility()
    if not widget then
        return
    end

    if ShouldHideInCombat() and InCombatLockdown() then
        widget:Hide()
        return
    end

    UpdateSpecs()
end

local function OpenSettings()
    if ReSpecSettingsCategory then
        Settings.OpenToCategory(ReSpecSettingsCategory:GetID())
    else
        print("|cffff7f7f[ReSpec]|r Settings not ready yet.")
    end
end

local function OpenTalents()
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

local function GetMainButtonRightClickTooltipText()
    local action = GetRightClickAction()

    if action == "settings" then
        return "Right click to open settings"
    end

    if action == "talents" then
        return "Right click to open talents"
    end

    return ""
end

local function ShowTooltip(button, specData)
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
        GameTooltip:AddLine(GetMainButtonRightClickTooltipText(), 0.7, 0.7, 0.7)
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
    shadow:SetColorTexture(0, 0, 0, 0.45)
    return shadow
end

local function UpdateButtonVisual(button, isActive, isMain)
    if isActive then
        button.selectedGlow:Show()
        button.icon:SetAlpha(1)
        button:SetScale(1.0)

        if button.border then
            button.border:SetScale(1.10)
        end
    else
        button.selectedGlow:Hide()
        button.icon:SetAlpha(0.88)
        button:SetScale(isMain and 1.0 or SECONDARY_SCALE)

        if button.border then
            button.border:SetScale(1.0)
        end
    end
end

local function CreateSpecButton(parent, name)
    local button = CreateFrame("Button", addonName .. name, parent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)

    button.shadow = CreateShadow(button)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0.08, 0.07, 0.06, 0.92)

    button.border = button:CreateTexture(nil, "BORDER")
    button.border:SetAllPoints()
    button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 5, -5)
    button.icon:SetPoint("BOTTOMRIGHT", -5, 5)
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.hoverGlow = button:CreateTexture(nil, "OVERLAY")
    button.hoverGlow:SetAllPoints()
    button.hoverGlow:SetTexture()
    button.hoverGlow:SetBlendMode("ADD")
    button.hoverGlow:SetAlpha(0.45)
    button.hoverGlow:Hide()

    button.selectedGlow = button:CreateTexture(nil, "OVERLAY")
    button.selectedGlow:SetAllPoints()
    button.selectedGlow:SetTexture()
    button.selectedGlow:SetBlendMode("ADD")
    button.selectedGlow:SetAlpha(0.85)
    button.selectedGlow:SetPoint("TOPLEFT", button.icon, -18, 18)
    button.selectedGlow:SetPoint("BOTTOMRIGHT", button.icon, 18, -18)
    button.selectedGlow:Hide()

    button.pushedShade = button:CreateTexture(nil, "OVERLAY")
    button.pushedShade:SetAllPoints()
    button.pushedShade:SetColorTexture(0, 0, 0, 0.2)
    button.pushedShade:Hide()

    button:SetScript("OnEnter", function(self)
        BeginExpand()
        self.hoverGlow:Show()

        if widget and widget.isDragging then
            return
        end

        if self.specData then
            ShowTooltip(self, self.specData)
        end
    end)

    button:SetScript("OnLeave", function(self)
        self.hoverGlow:Hide()
        GameTooltip_Hide()

        if not MouseIsOver(widget) then
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
            SwitchToSpec(self.specData.specIndex)
        end
    end)

    return button
end

local function GetAxisSizes(count)
    local mainSpan = BUTTON_SIZE + BUTTON_GAP + CHEVRON_WIDTH
    local secondarySpan = 0

    if count > 0 then
        secondarySpan = BUTTON_GAP + (count * BUTTON_SIZE) + ((count - 1) * BUTTON_GAP)
    end

    return mainSpan, secondarySpan
end

local function LayoutStatic()
    local direction = GetExpandDirection()

    mainButton:ClearAllPoints()
    mainButton:SetPoint("TOPLEFT", widget, "TOPLEFT", HOVER_PADDING, -HOVER_PADDING)

    chevron:ClearAllPoints()
    chevron:SetAtlas("UI-HUD-ActionBar-Flyout")
    chevron:SetBlendMode("BLEND")
    chevron:SetVertexColor(1, 1, 1, 1)
    chevron:SetRotation(0)
    chevron:SetSize(18, 7)

    local spacing = 4
    local offset = (BUTTON_SIZE / 2) + spacing

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

    for i = 1, #secondaryButtons do
        local button = secondaryButtons[i]
        if button.specData then
            button:ClearAllPoints()

            if direction == "right" then
                local finalX = BUTTON_GAP + CHEVRON_WIDTH + BUTTON_GAP + ((i - 1) * (BUTTON_SIZE + BUTTON_GAP))
                local hiddenX = BUTTON_GAP + CHEVRON_WIDTH - 10
                local x = hiddenX + ((finalX - hiddenX) * progress)
                button:SetPoint("LEFT", mainButton, "RIGHT", x, 0)
            elseif direction == "left" then
                local finalX = -(BUTTON_GAP + CHEVRON_WIDTH + BUTTON_GAP + (i * BUTTON_SIZE) + ((i - 1) * BUTTON_GAP))
                local hiddenX = -(BUTTON_GAP + CHEVRON_WIDTH) + 10
                local x = hiddenX + ((finalX - hiddenX) * progress)
                button:SetPoint("LEFT", mainButton, "LEFT", x, 0)
            elseif direction == "up" then
                local finalY = BUTTON_GAP + CHEVRON_WIDTH + BUTTON_GAP + ((i - 1) * (BUTTON_SIZE + BUTTON_GAP))
                local hiddenY = BUTTON_GAP + CHEVRON_WIDTH - 10
                local y = hiddenY + ((finalY - hiddenY) * progress)
                button:SetPoint("BOTTOM", mainButton, "TOP", 0, y)
            else
                local finalY = -(BUTTON_GAP + CHEVRON_WIDTH + BUTTON_GAP + (i * BUTTON_SIZE) + ((i - 1) * BUTTON_GAP))
                local hiddenY = -(BUTTON_GAP + CHEVRON_WIDTH) + 10
                local y = hiddenY + ((finalY - hiddenY) * progress)
                button:SetPoint("BOTTOM", mainButton, "BOTTOM", 0, y)
            end

            button:SetAlpha(progress)

            if progress > 0.03 then
                button:Show()
            else
                button:Hide()
                button.hoverGlow:Hide()
                button.selectedGlow:Hide()
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

    widget = CreateFrame("Frame", addonName .. "Widget", UIParent)
    widget:SetSize(BUTTON_SIZE + (HOVER_PADDING * 2), BUTTON_SIZE + (HOVER_PADDING * 2))
    widget:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)
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

        local left = widget:GetLeft()
        local bottom = widget:GetBottom()

        if not left or not bottom then
            return
        end

        widget.isDragging = true
        widget.dragOffsetX = cursorX - left
        widget.dragOffsetY = cursorY - bottom

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

            if not MouseIsOver(widget) then
                BeginDelayedCollapse()
            end
        end
    end)

    chevron = mainButton:CreateTexture(nil, "OVERLAY", nil, 2)
    chevron:SetAtlas("UI-HUD-ActionBar-Flyout")
    chevron:SetBlendMode("BLEND")
    chevron:SetVertexColor(1, 1, 1, 1)

    for i = 1, MAX_SECONDARY_BUTTONS do
        secondaryButtons[i] = CreateSpecButton(widget, "SecondaryButton" .. i)
        secondaryButtons[i]:SetFrameLevel(widget:GetFrameLevel() + 5)
    end

    widget:SetScript("OnUpdate", function(self, elapsed)
        if self.isDragging then
            GameTooltip_Hide()

            local scale = UIParent:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale

            local newLeft = cursorX - self.dragOffsetX
            local newBottom = cursorY - self.dragOffsetY

            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newLeft, newBottom)
        end

        if self.collapseAt and not self.isHovered and not MouseIsOver(self) and GetTime() >= self.collapseAt then
            self.targetExpanded = false
            self.collapseAt = nil
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

        local targetAlpha = ComputeWidgetAlpha(self.isHovered)
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
        widget:Hide()
        return
    end

    local specs = GetVisibleSpecs()
    local currentSpec = GetCurrentSpecIndex()

    if #specs <= 1 then
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
            button.selectedGlow:Hide()
        end
    end

    LayoutStatic()

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

    widget.currentOffset = 0
    widget.targetExpanded = false
    widget.collapseAt = nil
    widget.isDragging = false

    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x, db.y)

    UpdateVisibility()
end

addon:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        EnsureUI()
        UpdateVisibility()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        UpdateVisibility()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        if widget and ShouldHideInCombat() then
            widget:Hide()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        UpdateVisibility()
        return
    end
end)

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
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
