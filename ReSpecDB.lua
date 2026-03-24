local addonName = ...

local defaults = {
    hideInCombat = true,
    expandDirection = "right",
    rightClickAction = "settings",
    reverseOrder = false,
    useCustomOpacity = false,
    transparency = 70,
    fullOpacityOnHover = true,
}

local BUTTON_SIZE = 42
local HOVER_PADDING = 6
local WIDGET_SIZE = BUTTON_SIZE + (HOVER_PADDING * 2)

local function ApplyDefaultPosition()
    local cx, cy = UIParent:GetCenter()
    local uiHeight = UIParent:GetHeight()

    if cx and cy and uiHeight then
        local halfWidget = WIDGET_SIZE / 2

        local left = cx - halfWidget
        local top = cy + halfWidget
        local y = top - uiHeight

        ReSpecDB.x = left
        ReSpecDB.y = y
    else
        ReSpecDB.x = 0
        ReSpecDB.y = 0
    end
end

function ReSpec_EnsureDB()
    if type(ReSpecDB) ~= "table" then
        ReSpecDB = {}
    end

    for key, value in pairs(defaults) do
        if ReSpecDB[key] == nil then
            ReSpecDB[key] = value
        end
    end

    if ReSpecDB.x == nil or ReSpecDB.y == nil then
        ApplyDefaultPosition()
    end
end

function ReSpec_GetDB()
    ReSpec_EnsureDB()
    return ReSpecDB
end

function ReSpec_ResetDB()
    ReSpecDB = {}

    for key, value in pairs(defaults) do
        ReSpecDB[key] = value
    end

    ApplyDefaultPosition()
end
