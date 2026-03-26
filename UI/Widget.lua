local addonName, ReSpec = ...
local C = ReSpec.Colors
local S = ReSpec.State
local K = ReSpec.Constants

local LOOT_SPEC_CORNER_ICON_TEXTURE = "Interface\\AddOns\\ReSpec\\Assets\\lootbag"

-- ======================================================
-- LOOT CHECKBOX UI
-- ======================================================

function ReSpec.UpdateLootSpecCheckbox(button)
    if not button or not button.lootCheck or not button.specData then
        return
    end

    if not ReSpec.IsLootSpecSelectorEnabled() then
        button.lootCheck:Hide()
        return
    end

    button.lootCheck:Show()

    local state = ReSpec.GetLootCheckboxState(button)

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

function ReSpec.UpdateLootSpecIcon(button)
    if not button or not button.lootSpecIcon or not button.specData then
        return
    end

    if not ReSpec.ShouldShowLootSpecIcon() then
        button.lootSpecIcon:Hide()
        return
    end

    local displayedLootSpecID = ReSpec.GetDisplayedLootSpecID()
    if displayedLootSpecID == button.specData.specID then
        button.lootSpecIcon:Show()
    else
        button.lootSpecIcon:Hide()
    end
end

function ReSpec.RefreshLootSpecIcons()
    if S.mainButton and S.mainButton.specData then
        ReSpec.UpdateLootSpecIcon(S.mainButton)
    end

    for i = 1, #S.secondaryButtons do
        local button = S.secondaryButtons[i]
        if button and button.specData then
            ReSpec.UpdateLootSpecIcon(button)
        end
    end
end

function ReSpec.RefreshLootSpecCheckboxes()
    if S.mainButton and S.mainButton.specData then
        ReSpec.UpdateLootSpecCheckbox(S.mainButton)
    end

    for i = 1, #S.secondaryButtons do
        local button = S.secondaryButtons[i]
        if button and button.specData then
            ReSpec.UpdateLootSpecCheckbox(button)
        end
    end

    ReSpec.RefreshLootSpecIcons()
end

function ReSpec.CreateLootCheckbox(button)
    local box = CreateFrame("Button", nil, button)
    local size = ReSpec.GetLootCheckboxSize()
    local offset = ReSpec.GetLootCheckboxOffset()

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
        ReSpec.ShowLootSpecTooltip(self, button)
    end)

    box:SetScript("OnLeave", function()
        GameTooltip_Hide()
    end)

    box:SetScript("OnClick", function(self)
        ReSpec.SetLootSpecFromButton(button)
        ReSpec.RefreshLootSpecCheckboxes()

        if self:IsMouseOver() then
            ReSpec.ShowLootSpecTooltip(self, button)
        else
            GameTooltip_Hide()
        end
    end)

    return box
end

-- ======================================================
-- VISUAL HELPERS
-- ======================================================

function ReSpec.CreateShadow(parent)
    local shadow = parent:CreateTexture(nil, "BACKGROUND", nil, -1)
    shadow:SetPoint("TOPLEFT", 4, -4)
    shadow:SetPoint("BOTTOMRIGHT", -4, 4)
    C.ApplyTexture(shadow, C.SHADOW)
    return shadow
end

function ReSpec.UpdateButtonVisual(button, isActive, isMain)
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
        button:SetScale(isMain and 1.0 or K.SECONDARY_SCALE)

        if button.border then
            button.border:SetScale(1.0)
            button.border:SetVertexColor(unpack(C.WHITE))
        end
    end
end

function ReSpec.UpdateButtonHoverVisual(button, isHovered)
    if not button or not button.specData then
        return
    end

    local isCurrentSpec = button.specData.specIndex == ReSpec.GetCurrentSpecIndex()

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

-- ======================================================
-- BUTTON CREATION
-- ======================================================

function ReSpec.CreateSpecButton(parent, name)
    local button = CreateFrame("Button", addonName .. name, parent)
    local size = ReSpec.GetButtonSize()
    button:SetSize(size, size)

    button.shadow = ReSpec.CreateShadow(button)

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

    button.lootSpecIcon = button:CreateTexture(nil, "OVERLAY", nil, 3)
    button.lootSpecIcon:SetTexture(LOOT_SPEC_CORNER_ICON_TEXTURE)
    button.lootSpecIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    button.lootSpecIcon:Hide()

    button.lootCheck = ReSpec.CreateLootCheckbox(button)

    button:SetScript("OnEnter", function(self)
        ReSpec.BeginExpand()
        self.hoverGlow:Show()
        ReSpec.UpdateButtonHoverVisual(self, true)

        if S.widget and S.widget.isDragging then
            return
        end

        if self.specData then
            ReSpec.ShowTooltip(self, self.specData)
        end
    end)

    button:SetScript("OnLeave", function(self)
        self.hoverGlow:Hide()
        ReSpec.UpdateButtonHoverVisual(self, false)

        if GameTooltip:GetOwner() == self then
            GameTooltip_Hide()
        end

        if not ReSpec.IsMouseOverReSpecUI() then
            ReSpec.BeginDelayedCollapse()
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
        if self.specData and self.specData.specIndex ~= ReSpec.GetCurrentSpecIndex() then
            ReSpec.HideLootSpecPopup()
            ReSpec.SwitchToSpec(self.specData.specIndex)
        end
    end)

    return button
end

-- ======================================================
-- LAYOUT / ANIMATION HELPERS
-- ======================================================

function ReSpec.UpdateHoverArea()
    if not S.widget or not S.mainButton then
        return
    end

    local width = S.mainButton:GetWidth() + (K.HOVER_PADDING * 2)
    local height = S.mainButton:GetHeight() + (K.HOVER_PADDING * 2)

    S.widget:SetSize(width, height)

    S.mainButton:ClearAllPoints()
    S.mainButton:SetPoint("TOPLEFT", S.widget, "TOPLEFT", K.HOVER_PADDING, -K.HOVER_PADDING)
end

function ReSpec.BeginExpand()
    if not S.widget then
        return
    end

    S.widget.isHovered = true
    S.widget.targetExpanded = true
    S.widget.collapseAt = nil
end

function ReSpec.BeginDelayedCollapse()
    if not S.widget then
        return
    end

    S.widget.isHovered = false
    S.widget.collapseAt = GetTime() + K.COLLAPSE_DELAY
end

function ReSpec.GetAxisSizes(count)
    local size = ReSpec.GetButtonSize()
    local mainSpan = size + K.BUTTON_GAP + K.CHEVRON_WIDTH
    local secondarySpan = 0

    if count > 0 then
        secondarySpan = K.BUTTON_GAP + (count * size) + ((count - 1) * K.BUTTON_GAP)
    end

    return mainSpan, secondarySpan
end

function ReSpec.LayoutStatic()
    local direction = ReSpec.GetExpandDirection()
    local size = ReSpec.GetButtonSize()

    S.mainButton:ClearAllPoints()
    S.mainButton:SetPoint("TOPLEFT", S.widget, "TOPLEFT", K.HOVER_PADDING, -K.HOVER_PADDING)

    S.chevron:ClearAllPoints()
    S.chevron:SetAtlas("UI-HUD-ActionBar-Flyout")
    S.chevron:SetBlendMode("BLEND")
    S.chevron:SetVertexColor(unpack(C.WHITE))
    S.chevron:SetRotation(0)
    S.chevron:SetSize(18, 7)

    local spacing = 4
    local offset = (size / 2) + spacing

    if direction == "right" then
        S.chevron:SetPoint("CENTER", S.mainButton, "CENTER", offset, 0)
        S.chevron:SetRotation(-math.pi / 2)
    elseif direction == "left" then
        S.chevron:SetPoint("CENTER", S.mainButton, "CENTER", -offset, 0)
        S.chevron:SetRotation(math.pi / 2)
    elseif direction == "up" then
        S.chevron:SetPoint("CENTER", S.mainButton, "CENTER", 0, offset)
        S.chevron:SetRotation(0)
    else
        S.chevron:SetPoint("CENTER", S.mainButton, "CENTER", 0, -offset)
        S.chevron:SetRotation(math.pi)
    end
end

function ReSpec.PositionSecondaryButtons(progress)
    local direction = ReSpec.GetExpandDirection()
    local size = ReSpec.GetButtonSize()

    for i = 1, #S.secondaryButtons do
        local button = S.secondaryButtons[i]
        if button.specData then
            button:ClearAllPoints()

            if direction == "right" then
                local finalX = K.BUTTON_GAP + K.CHEVRON_WIDTH + K.BUTTON_GAP + ((i - 1) * (size + K.BUTTON_GAP))
                local hiddenX = K.BUTTON_GAP + K.CHEVRON_WIDTH - 10
                local x = hiddenX + ((finalX - hiddenX) * progress)
                button:SetPoint("LEFT", S.mainButton, "RIGHT", x, 0)
            elseif direction == "left" then
                local finalX = -(K.BUTTON_GAP + K.CHEVRON_WIDTH + K.BUTTON_GAP + (i * size) + ((i - 1) * K.BUTTON_GAP))
                local hiddenX = -(K.BUTTON_GAP + K.CHEVRON_WIDTH) + 10
                local x = hiddenX + ((finalX - hiddenX) * progress)
                button:SetPoint("LEFT", S.mainButton, "LEFT", x, 0)
            elseif direction == "up" then
                local finalY = K.BUTTON_GAP + K.CHEVRON_WIDTH + K.BUTTON_GAP + ((i - 1) * (size + K.BUTTON_GAP))
                local hiddenY = K.BUTTON_GAP + K.CHEVRON_WIDTH - 10
                local y = hiddenY + ((finalY - hiddenY) * progress)
                button:SetPoint("BOTTOM", S.mainButton, "TOP", 0, y)
            else
                local finalY = -(K.BUTTON_GAP + K.CHEVRON_WIDTH + K.BUTTON_GAP + (i * size) + ((i - 1) * K.BUTTON_GAP))
                local hiddenY = -(K.BUTTON_GAP + K.CHEVRON_WIDTH) + 10
                local y = hiddenY + ((finalY - hiddenY) * progress)
                button:SetPoint("BOTTOM", S.mainButton, "BOTTOM", 0, y)
            end

            button:SetAlpha(progress)

            if progress > 0.03 then
                button:Show()
                if ReSpec.IsLootSpecSelectorEnabled() then
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

local function UpdateLootSpecIconLayout(button)
    if not button or not button.lootSpecIcon then
        return
    end

    local buttonSize = ReSpec.GetButtonSize()
    local iconSize = math.max(12, math.floor(buttonSize * 0.34 + 0.5))
    local inset = math.max(1, math.floor(buttonSize * 0.03 + 0.5))

    button.lootSpecIcon:ClearAllPoints()
    button.lootSpecIcon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
    button.lootSpecIcon:SetSize(iconSize, iconSize)
end

-- ======================================================
-- CORE UI
-- ======================================================

function ReSpec.EnsureUI()
    if S.initialized then
        return
    end

    ReSpec.EnsureDB()

    local db = ReSpec.GetDB()
    local size = ReSpec.GetButtonSize()

    S.widget = CreateFrame("Frame", addonName .. "Widget", UIParent)
    S.widget:SetSize(size + (K.HOVER_PADDING * 2), size + (K.HOVER_PADDING * 2))
    S.widget:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.x, db.y)
    S.widget:SetFrameStrata("MEDIUM")
    S.widget:SetFrameLevel(20)
    S.widget:SetMovable(true)
    S.widget:EnableMouse(true)
    S.widget:SetClampedToScreen(true)

    S.widget.targetExpanded = false
    S.widget.isHovered = false
    S.widget.collapseAt = nil
    S.widget.secondaryCount = 0
    S.widget.currentOffset = 0
    S.widget.isDragging = false
    S.widget.dragOffsetX = 0
    S.widget.dragOffsetY = 0
    S.widget.currentAlpha = ReSpec.ComputeWidgetAlpha(false)

    S.widget:SetScript("OnEnter", ReSpec.BeginExpand)
    S.widget:SetScript("OnLeave", ReSpec.BeginDelayedCollapse)

    S.mainButton = ReSpec.CreateSpecButton(S.widget, "MainButton")
    ReSpec.UpdateHoverArea()
    UpdateLootSpecIconLayout(S.mainButton)

    S.mainButton:SetFrameLevel(S.widget:GetFrameLevel() + 20)
    S.mainButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    S.mainButton:SetScript("OnClick", nil)
    S.mainButton:SetScript("OnMouseDown", nil)
    S.mainButton:SetScript("OnMouseUp", nil)
    S.mainButton.pushedShade:Hide()

    if S.mainButton.shadow then
        S.mainButton.shadow:Hide()
    end

    if S.mainButton.border then
        S.mainButton.border:Hide()
    end

    S.mainButton:SetScript("OnMouseDown", function(self, mouseButton)
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

        local centerX, centerY = S.widget:GetCenter()

        if not centerX or not centerY then
            return
        end

        S.widget.isDragging = true
        S.widget.dragOffsetX = cursorX - centerX
        S.widget.dragOffsetY = cursorY - centerY

        ReSpec.BeginExpand()
        GameTooltip_Hide()
    end)

    S.mainButton:SetScript("OnMouseUp", function(self, mouseButton)
        if mouseButton == "RightButton" then
            ReSpec.HandleMainButtonRightClick()
            return
        end

        if S.widget.isDragging then
            S.widget.isDragging = false
            ReSpec.SavePosition(S.widget)

            if not ReSpec.IsMouseOverReSpecUI() then
                ReSpec.BeginDelayedCollapse()
            end
        end
    end)

    S.chevron = S.mainButton:CreateTexture(nil, "OVERLAY", nil, 2)
    S.chevron:SetAtlas("UI-HUD-ActionBar-Flyout")
    S.chevron:SetBlendMode("BLEND")
    S.chevron:SetVertexColor(unpack(C.WHITE))

    for i = 1, K.MAX_SECONDARY_BUTTONS do
        S.secondaryButtons[i] = ReSpec.CreateSpecButton(S.widget, "SecondaryButton" .. i)
        S.secondaryButtons[i]:SetFrameLevel(S.widget:GetFrameLevel() + 5)
        UpdateLootSpecIconLayout(S.secondaryButtons[i])
    end

    S.widget:SetScript("OnUpdate", function(self, elapsed)
        if self.isDragging then
            GameTooltip_Hide()
            ReSpec.HideLootSpecPopup()

            local scale = UIParent:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale

            local newCenterX = cursorX - self.dragOffsetX
            local newCenterY = cursorY - self.dragOffsetY

            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", newCenterX, newCenterY)
        end

        if self.collapseAt and not self.isHovered and not ReSpec.IsMouseOverReSpecUI() and GetTime() >= self.collapseAt then
            self.targetExpanded = false
            self.collapseAt = nil
            ReSpec.HideLootSpecPopup()
        end

        local _, maxSecondarySpan = ReSpec.GetAxisSizes(self.secondaryCount)
        local targetSecondarySpan = self.targetExpanded and maxSecondarySpan or 0

        local diff = targetSecondarySpan - self.currentOffset
        if math.abs(diff) < 0.5 then
            self.currentOffset = targetSecondarySpan
        else
            self.currentOffset = self.currentOffset + diff * math.min(elapsed * K.ANIMATION_SPEED, 1)
        end

        local progress = 0
        if maxSecondarySpan > 0 then
            progress = math.min(1, math.max(0, self.currentOffset / maxSecondarySpan))
        end

        local targetAlpha = ReSpec.ComputeWidgetAlpha(ReSpec.ShouldUseExpandedOpacity())
        local alphaDiff = targetAlpha - (self.currentAlpha or targetAlpha)

        if math.abs(alphaDiff) < 0.01 then
            self.currentAlpha = targetAlpha
        else
            self.currentAlpha = (self.currentAlpha or targetAlpha) + alphaDiff * math.min(elapsed * 12, 1)
        end

        self:SetAlpha(self.currentAlpha)

        ReSpec.PositionSecondaryButtons(progress)
    end)

    S.initialized = true
end

function ReSpec.UpdateSpecs()
    ReSpec.EnsureUI()
    if not S.initialized then
        return
    end

    if ReSpec.ShouldHideInCombat() and InCombatLockdown() then
        ReSpec.HideLootSpecPopup()
        S.widget:Hide()
        return
    end

    local specs = ReSpec.GetVisibleSpecs()
    local currentSpec = ReSpec.GetCurrentSpecIndex()

    if #specs <= 1 then
        ReSpec.HideLootSpecPopup()
        S.widget:Hide()
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

    ReSpec.ApplyInactiveSpecOrder(inactiveSpecs)

    if not activeSpec then
        ReSpec.HideLootSpecPopup()
        S.widget:Hide()
        return
    end

    S.mainButton.specData = activeSpec
    S.mainButton.icon:SetTexture(activeSpec.icon or 134400)
    ReSpec.UpdateButtonVisual(S.mainButton, true, true)
    S.mainButton:Show()

    S.widget.secondaryCount = math.min(#inactiveSpecs, K.MAX_SECONDARY_BUTTONS)

    for i = 1, #S.secondaryButtons do
        local button = S.secondaryButtons[i]
        local spec = inactiveSpecs[i]

        if spec and i <= K.MAX_SECONDARY_BUTTONS then
            button.specData = spec
            button.icon:SetTexture(spec.icon or 134400)
            ReSpec.UpdateButtonVisual(button, false, false)
            button:SetAlpha(0)

            if S.widget.targetExpanded then
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
            if button.lootSpecIcon then
                button.lootSpecIcon:Hide()
            end
        end
    end

    ReSpec.LayoutStatic()
    ReSpec.RefreshLootSpecCheckboxes()
    ReSpec.RefreshLootSpecPopup()

    S.widget.currentAlpha = ReSpec.ComputeWidgetAlpha(S.widget.isHovered)
    S.widget:SetAlpha(S.widget.currentAlpha)

    S.widget:Show()
end

function ReSpec_RefreshLayout()
    ReSpec.EnsureDB()

    if not S.initialized or not S.widget then
        return
    end

    local db = ReSpec.GetDB()
    local size = ReSpec.GetButtonSize()
    local lootBoxSize = ReSpec.GetLootCheckboxSize()
    local lootBoxOffset = ReSpec.GetLootCheckboxOffset()

    S.widget.currentOffset = 0
    S.widget.targetExpanded = false
    S.widget.collapseAt = nil
    S.widget.isDragging = false

    GameTooltip_Hide()
    ReSpec.HideLootSpecPopup()

    S.widget:SetSize(size + (K.HOVER_PADDING * 2), size + (K.HOVER_PADDING * 2))
    S.mainButton:SetSize(size, size)

    if S.mainButton.lootCheck then
        S.mainButton.lootCheck:SetSize(lootBoxSize, lootBoxSize)
        S.mainButton.lootCheck:ClearAllPoints()
        S.mainButton.lootCheck:SetPoint("TOPLEFT", S.mainButton, "TOPLEFT", lootBoxOffset, -lootBoxOffset)
    end

    UpdateLootSpecIconLayout(S.mainButton)

    for i = 1, #S.secondaryButtons do
        S.secondaryButtons[i]:SetSize(size, size)

        if S.secondaryButtons[i].lootCheck then
            S.secondaryButtons[i].lootCheck:SetSize(lootBoxSize, lootBoxSize)
            S.secondaryButtons[i].lootCheck:ClearAllPoints()
            S.secondaryButtons[i].lootCheck:SetPoint("TOPLEFT", S.secondaryButtons[i], "TOPLEFT", lootBoxOffset,
                -lootBoxOffset)
        end

        UpdateLootSpecIconLayout(S.secondaryButtons[i])
    end

    S.widget:ClearAllPoints()
    S.widget:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.x, db.y)

    ReSpec.UpdateHoverArea()
    ReSpec.UpdateVisibility()
    ReSpec.RefreshLootSpecCheckboxes()
end
