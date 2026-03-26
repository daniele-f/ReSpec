local addonName, ReSpec = ...
local C = ReSpec.Colors
local S = ReSpec.State

-- ======================================================
-- POPUP WINDOW
-- ======================================================

function ReSpec.HideLootSpecPopup()
    if S.lootSpecPopup then
        S.lootSpecPopup:Hide()
        S.lootSpecPopup.anchorButton = nil
    end
end

function ReSpec.PositionLootSpecPopup()
    if not S.lootSpecPopup or not S.mainButton or not S.mainButton:IsShown() then
        return
    end

    local popupWidth = S.lootSpecPopup:GetWidth() or 0
    local popupHeight = S.lootSpecPopup:GetHeight() or 0

    local centerX = S.mainButton:GetCenter()
    local top = S.mainButton:GetTop()
    local bottom = S.mainButton:GetBottom()

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

    S.lootSpecPopup:ClearAllPoints()

    if showBelow then
        local topY = bottom - verticalGap
        S.lootSpecPopup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, topY)
    else
        local bottomY = top + verticalGap
        S.lootSpecPopup:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottomY)
    end
end

function ReSpec.EnsureLootSpecPopup()
    if S.lootSpecPopup then
        return
    end

    S.lootSpecPopup = CreateFrame("Frame", addonName .. "LootSpecPopup", UIParent, "BackdropTemplate")
    S.lootSpecPopup:SetFrameStrata("DIALOG")
    S.lootSpecPopup:SetFrameLevel(120)
    S.lootSpecPopup:SetClampedToScreen(true)
    S.lootSpecPopup:EnableMouse(true)
    S.lootSpecPopup:Hide()

    S.lootSpecPopup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    S.lootSpecPopup:SetBackdropColor(unpack(C.BG_POPUP_BACKDROP))
    S.lootSpecPopup:SetBackdropBorderColor(unpack(C.BORDER_POPUP))

    S.lootSpecPopup.rows = {}
    S.lootSpecPopup.anchorButton = nil
    S.lootSpecPopup._mouseWasDown = false

    S.lootSpecPopup:SetScript("OnUpdate", function(self)
        if not self:IsShown() then
            return
        end

        if self.anchorButton and not self._mouseWasDown then
            if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
                self._mouseWasDown = true
                if not MouseIsOver(self) and not MouseIsOver(self.anchorButton) then
                    ReSpec.HideLootSpecPopup()
                end
            end
        elseif self._mouseWasDown then
            if not IsMouseButtonDown("LeftButton") and not IsMouseButtonDown("RightButton") then
                self._mouseWasDown = false
            end
        end
    end)
end

function ReSpec.CreateLootSpecPopupRow(parent, index)
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

function ReSpec.SetLootSpecPopupRowSelected(row, isSelected)
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

function ReSpec.RefreshLootSpecPopup()
    if not S.lootSpecPopup or not S.mainButton or not S.mainButton.specData then
        return
    end

    local currentSpec = ReSpec.GetSpecData(ReSpec.GetCurrentSpecIndex())
    local lootSpecMode = ReSpec.GetLootSpecMode()
    local specs = ReSpec.GetVisibleSpecs()
    local entries = {}

    entries[#entries + 1] = {
        text = string.format("Current Specialization (%s)", currentSpec and currentSpec.name or UNKNOWN),
        selected = lootSpecMode == 0,
        onClick = function()
            SetLootSpecialization(0)
            ReSpec.RefreshLootSpecCheckboxes()
            ReSpec.RefreshLootSpecPopup()
        end,
    }

    for i = 1, #specs do
        local spec = specs[i]
        entries[#entries + 1] = {
            text = spec.name,
            selected = lootSpecMode == spec.specID,
            onClick = function()
                SetLootSpecialization(spec.specID)
                ReSpec.RefreshLootSpecCheckboxes()
                ReSpec.RefreshLootSpecPopup()
            end,
        }
    end

    local rowHeight = 40
    local innerPadding = 4
    local width = 310
    local height = (#entries * rowHeight) + (innerPadding * 2)

    S.lootSpecPopup:SetSize(width, height)

    for i = 1, #entries do
        local row = S.lootSpecPopup.rows[i] or ReSpec.CreateLootSpecPopupRow(S.lootSpecPopup, i)
        local topY = -innerPadding - ((i - 1) * rowHeight)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", S.lootSpecPopup, "TOPLEFT", innerPadding, topY)
        row:SetPoint("TOPRIGHT", S.lootSpecPopup, "TOPRIGHT", -innerPadding, topY)
        row:SetHeight(rowHeight - 2)

        row.text:SetText(entries[i].text)
        ReSpec.SetLootSpecPopupRowSelected(row, entries[i].selected)
        row:SetScript("OnClick", entries[i].onClick)
        row:Show()
    end

    for i = #entries + 1, #S.lootSpecPopup.rows do
        S.lootSpecPopup.rows[i]:Hide()
    end

    if S.lootSpecPopup:IsShown() then
        ReSpec.PositionLootSpecPopup()
    end
end

function ReSpec.OpenLootSpecPopup()
    ReSpec.EnsureLootSpecPopup()
    S.lootSpecPopup.anchorButton = S.mainButton
    S.lootSpecPopup._mouseWasDown = false
    ReSpec.RefreshLootSpecPopup()
    ReSpec.PositionLootSpecPopup()
    S.lootSpecPopup:Show()
end
