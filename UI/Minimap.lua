local _, NS = ...

---------------------------------------------------------------------
-- Boton de minimapa
---------------------------------------------------------------------
NS.mm = CreateFrame("Button", "TuWoWQoLMinimapButton", Minimap)
NS.mm:SetSize(31, 31)
NS.mm:SetFrameStrata("MEDIUM")
NS.mm:SetFrameLevel(8)
NS.mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
if NS.mm.SetPropagateMouseClicks then NS.mm:SetPropagateMouseClicks(false) end
NS.mm:RegisterForDrag("LeftButton")
NS.mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local mmIcon = NS.mm:CreateTexture(nil, "BACKGROUND")
mmIcon:SetSize(20, 20)
mmIcon:SetPoint("CENTER", 0, 1)
mmIcon:SetTexture(NS.MINIMAP_ICON)
mmIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local mmBorder = NS.mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(53, 53)
mmBorder:SetPoint("TOPLEFT")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function PlaceMinimapButton()
    local angleDegrees = NS.db.minimapAngle or 215
    local angle = math.rad(angleDegrees)
    NS.mm:ClearAllPoints()
    NS.mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

function NS.ApplyMinimap()
    if NS.db.showMinimap then
        PlaceMinimapButton()
        NS.mm:Show()
    else
        NS.mm:Hide()
    end
    TuWoWQoLDayNight.SetVisible(NS.db.showMinimap)
end

local function MinimapDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    NS.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    PlaceMinimapButton()
end

NS.mm:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", MinimapDragUpdate) end)
NS.mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
NS.mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddDoubleLine("TuWoW QoL", "v" .. NS.VERSION,
        1, 0.82, 0.2, 0.65, 0.65, 0.65)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Clic izq.", "Opciones", 0.1, 0.8, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Clic der.", "Editar interfaz", 0.1, 0.8, 1, 1, 1, 1)
    GameTooltip:Show()
end)
NS.mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
