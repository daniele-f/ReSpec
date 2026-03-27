local addonName, ReSpec = ...

ReSpec = ReSpec or {}
ReSpec.State = ReSpec.State or {}
ReSpec.Constants = ReSpec.Constants or {}

local S = ReSpec.State
local K = ReSpec.Constants

K.DEFAULT_BUTTON_SIZE = 42
K.SECONDARY_SCALE = 0.92
K.BUTTON_GAP = 6
K.CHEVRON_WIDTH = 2
K.ANIMATION_SPEED = 14
K.HOVER_PADDING = 6
K.COLLAPSE_DELAY = 1.5
K.MAX_SECONDARY_BUTTONS = 3

S.widget = S.widget or nil
S.mainButton = S.mainButton or nil
S.chevron = S.chevron or nil
S.secondaryButtons = S.secondaryButtons or {}
S.initialized = S.initialized or false
S.lootSpecPopup = S.lootSpecPopup or nil

-- ======================================================
-- DATABASE HELPERS
-- ======================================================

function ReSpec.EnsureDB()
    ReSpec_EnsureDB()
end

function ReSpec.GetDB()
    return ReSpec_GetDB()
end

-- ======================================================
-- SETTINGS / STATE HELPERS
-- ======================================================

function ReSpec.GetExpandDirection()
    return ReSpec.GetDB().expandDirection or "right"
end

function ReSpec.ShouldReverseOrder()
    return ReSpec.GetDB().reverseOrder == true
end

function ReSpec.GetRightClickAction()
    return ReSpec.GetDB().rightClickAction or "settings"
end

function ReSpec.GetButtonSize()
    return ReSpec.GetDB().buttonSize or K.DEFAULT_BUTTON_SIZE
end

function ReSpec.ShouldShowTooltips()
    return ReSpec.GetDB().showTooltips ~= false
end

function ReSpec.ShouldShowLootSpecIcon()
    return ReSpec.GetDB().showLootSpecIcon ~= false
end

function ReSpec.ShouldHideInCombat()
    return ReSpec.GetDB().hideInCombat == true
end

function ReSpec.ComputeWidgetAlpha(isHovered)
    local db = ReSpec.GetDB()

    if not db.useCustomOpacity then
        return 1
    end

    if isHovered and db.fullOpacityOnHover then
        return 1
    end

    local value = math.max(10, math.min(90, db.transparency or 90))
    return value / 100
end

function ReSpec.ShouldUseExpandedOpacity()
    if not S.widget then
        return false
    end

    if S.widget.isHovered then
        return true
    end

    if S.widget.collapseAt and S.widget.targetExpanded then
        return true
    end

    return false
end

function ReSpec.IsMouseOverReSpecUI()
    if S.widget and MouseIsOver(S.widget) then
        return true
    end

    if S.lootSpecPopup and S.lootSpecPopup:IsShown() and MouseIsOver(S.lootSpecPopup) then
        return true
    end

    return false
end

-- ======================================================
-- SPECIALIZATION HELPERS
-- ======================================================

function ReSpec.GetCurrentSpecIndex()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        return C_SpecializationInfo.GetSpecialization()
    end

    return GetSpecialization()
end

function ReSpec.GetSpecData(specIndex)
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

function ReSpec.GetVisibleSpecs()
    local specs = {}
    local count = GetNumSpecializations() or 0

    for specIndex = 1, count do
        local data = ReSpec.GetSpecData(specIndex)
        if data then
            specs[#specs + 1] = data
        end
    end

    return specs
end

function ReSpec.ReverseTableInPlace(t)
    local left = 1
    local right = #t

    while left < right do
        t[left], t[right] = t[right], t[left]
        left = left + 1
        right = right - 1
    end
end

function ReSpec.ShouldNormalizeDirectionOrder(direction)
    return direction == "left" or direction == "up"
end

function ReSpec.ApplyInactiveSpecOrder(inactiveSpecs)
    local direction = ReSpec.GetExpandDirection()

    if ReSpec.ShouldNormalizeDirectionOrder(direction) then
        ReSpec.ReverseTableInPlace(inactiveSpecs)
    end

    if ReSpec.ShouldReverseOrder() then
        ReSpec.ReverseTableInPlace(inactiveSpecs)
    end
end

function ReSpec.SwitchToSpec(specIndex)
    if not specIndex then
        return
    end

    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("Cannot change specialization in combat.", 1.0, 0.1, 0.1)
        return
    end

    if ReSpec.GetCurrentSpecIndex() == specIndex then
        return
    end

    if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
        C_SpecializationInfo.SetSpecialization(specIndex)
    else
        SetSpecialization(specIndex)
    end
end

-- ======================================================
-- LOOT SPECIALIZATION HELPERS
-- ======================================================

function ReSpec.GetLootSpecMode()
    return GetLootSpecialization() or 0
end

function ReSpec.GetDisplayedLootSpecID()
    local lootSpecMode = ReSpec.GetLootSpecMode()

    if lootSpecMode == 0 then
        local currentSpec = ReSpec.GetSpecData(ReSpec.GetCurrentSpecIndex())
        return currentSpec and currentSpec.specID or 0
    end

    return lootSpecMode
end

-- ======================================================
-- POSITION / VISIBILITY HELPERS
-- ======================================================

function ReSpec.SavePosition(frame)
    local db = ReSpec.GetDB()

    local cx, cy = frame:GetCenter()
    if not cx or not cy then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)

    db.x = cx
    db.y = cy
end

function ReSpec.UpdateVisibility()
    if not S.widget then
        return
    end

    if ReSpec.ShouldHideInCombat() and InCombatLockdown() then
        ReSpec.HideLootSpecPopup()
        S.widget:Hide()
        return
    end

    ReSpec.UpdateSpecs()
end

-- ======================================================
-- UI ACTIONS
-- ======================================================

function ReSpec.OpenSettings()
    ReSpec.HideLootSpecPopup()

    if ReSpecSettingsCategory then
        Settings.OpenToCategory(ReSpecSettingsCategory:GetID())
    else
        print("|cffff7f7f[ReSpec]|r Settings not ready yet.")
    end
end

function ReSpec.OpenTalents()
    ReSpec.HideLootSpecPopup()

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

function ReSpec.HandleMainButtonRightClick()
    local action = ReSpec.GetRightClickAction()

    if action == "settings" then
        ReSpec.OpenSettings()
        return
    end

    if action == "talents" then
        ReSpec.OpenTalents()
        return
    end

    if action == "lootspec" then
        ReSpec.OpenLootSpecPopup()
        return
    end

    ReSpec.HideLootSpecPopup()
end

-- ======================================================
-- TOOLTIPS
-- ======================================================

function ReSpec.GetMainButtonRightClickTooltipText()
    local action = ReSpec.GetRightClickAction()

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

function ReSpec.ShowTooltip(button, specData)
    if not ReSpec.ShouldShowTooltips() then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_NONE")

    local direction = ReSpec.GetExpandDirection()
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

    if specData.specIndex == ReSpec.GetCurrentSpecIndex() then
        GameTooltip:AddLine("Current specialization", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left click + SHIFT to drag", 0.7, 0.7, 0.7)

        local rightClickText = ReSpec.GetMainButtonRightClickTooltipText()
        if rightClickText ~= "" then
            GameTooltip:AddLine(rightClickText, 0.7, 0.7, 0.7)
        end
    else
        GameTooltip:AddLine("Click to switch", 0.2, 1, 0.2)
    end

    GameTooltip:Show()
end
