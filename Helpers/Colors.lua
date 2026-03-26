local addonName, ReSpec = ...

ReSpec = ReSpec or {}
ReSpec.Colors = ReSpec.Colors or {}

local C = ReSpec.Colors

C.BG_DARK = { 0.01, 0.01, 0.01, 1 }
C.BG_DARK_SOFT = { 0.02, 0.02, 0.02, 0.85 }
C.BG_HOVER = { 0.05, 0.05, 0.05, 1 }
C.BG_SELECTED = { 0.18, 0.13, 0.02, 0.95 }
C.BG_SELECTED_INDICATOR = { 0.16, 0.12, 0.02, 1 }
C.BG_CHECKBOX_GOLD = { 0.18, 0.14, 0.03, 0.95 }
C.BG_CHECKBOX_GREEN = { 0.04, 0.16, 0.04, 0.95 }
C.BG_BUTTON = { 0.08, 0.07, 0.06, 0.92 }
C.BG_POPUP_BACKDROP = { 0.01, 0.01, 0.01, 0.98 }
C.INDICATOR_BG = { 0.10, 0.10, 0.10, 1 }

C.BORDER_DIM = { 0.20, 0.20, 0.20, 1 }
C.BORDER_LIGHT = { 0.45, 0.45, 0.45, 1 }
C.BORDER_POPUP = { 0.22, 0.22, 0.22, 1 }

C.GOLD = { 1, 0.82, 0 }
C.GOLD_FULL = { 1, 0.82, 0, 1 }
C.GREEN_FULL = { 0.30, 1, 0.30, 1 }
C.WHITE = { 1, 1, 1, 1 }
C.WHITE_SOFT = { 0.95, 0.95, 0.95, 1 }
C.WHITE_DIM = { 0.70, 0.70, 0.70, 1 }

C.SHADOW = { 0, 0, 0, 0.45 }
C.HOVER_OVERLAY = { 1, 1, 1, 0.05 }
C.HOVER_INNER = { 1, 1, 1, 0.12 }
C.PUSHED_SHADE = { 0, 0, 0, 0.2 }

C.SETTINGS_LABEL = { 1, 0.82, 0 }
C.SETTINGS_DIVIDER = { 1, 1, 1, 0.14 }

function C.ApplyTexture(texture, color)
    if not texture or not color then
        return
    end

    texture:SetColorTexture(unpack(color))
end

function C.ApplyText(fontString, color)
    if not fontString or not color then
        return
    end

    fontString:SetTextColor(unpack(color))
end
