local addonName = ...

local defaults = {
    x = 100,
    y = 100,
    hideInCombat = false,
    expandDirection = "left",
    transparency = 70,
    useCustomOpacity = false,
    fullOpacityOnHover = true,
    reverseOrder = false,
    rightClickAction = "settings",
}

function ReSpec_EnsureDB()
    if type(ReSpecDB) ~= "table" then
        ReSpecDB = {}
    end

    for key, value in pairs(defaults) do
        if ReSpecDB[key] == nil then
            ReSpecDB[key] = value
        end
    end
end

function ReSpec_GetDB()
    ReSpec_EnsureDB()
    return ReSpecDB
end
