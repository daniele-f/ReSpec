local addonName, ReSpec = ...
local addon = CreateFrame("Frame")

-- ======================================================
-- EVENTS
-- ======================================================

addon:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ReSpec.EnsureUI()
        ReSpec.UpdateVisibility()
        ReSpec.RefreshLootSpecCheckboxes()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        ReSpec.UpdateVisibility()
        ReSpec.RefreshLootSpecCheckboxes()
        ReSpec.RefreshLootSpecPopup()
        return
    end

    if event == "PLAYER_LOOT_SPEC_UPDATED" then
        ReSpec.RefreshLootSpecCheckboxes()
        ReSpec.RefreshLootSpecPopup()
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        ReSpec.HideLootSpecPopup()

        if ReSpec.State and ReSpec.State.widget and ReSpec.ShouldHideInCombat() then
            ReSpec.State.widget:Hide()
        end
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        ReSpec.UpdateVisibility()
        ReSpec.RefreshLootSpecCheckboxes()
        return
    end
end)

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
addon:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
addon:RegisterEvent("PLAYER_REGEN_DISABLED")
addon:RegisterEvent("PLAYER_REGEN_ENABLED")

-- ======================================================
-- SLASH COMMANDS
-- ======================================================

SLASH_RESPEC1 = "/respec"

SlashCmdList["RESPEC"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "config" then
        ReSpec.OpenSettings()
        return
    end

    print("|cff00ff98ReSpec|r commands:")
    print("|cff00ff98/respec config|r - open settings")
end
