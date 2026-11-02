local _, NS = ...

---------------------------------------------------------------------
-- Radar de contagio (lista en pantalla)
---------------------------------------------------------------------
local RADAR_ROWS = 8
local DIST_LABEL = { danger = "<10y", near = "<28y", far = "lejos", unknown = "?" }

NS.radar = CreateFrame("Frame", "TuWoWQoLRadar", UIParent)
NS.radar:SetSize(250, 40)
NS.radar:SetPoint("LEFT", UIParent, "LEFT", 30, 0)
NS.radar:SetFrameStrata("HIGH")
NS.radar:SetMovable(true)
NS.radar:SetClampedToScreen(true)
NS.radar:RegisterForDrag("LeftButton")
NS.radar:SetBackdrop({
    bgFile = NS.WHITE, edgeFile = NS.WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
NS.radar:SetBackdropColor(0, 0, 0, 0.55)
NS.radar:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
NS.radar:Hide()
NS.radar:SetScript("OnDragStart", function(self) if NS.unlocked then self:StartMoving() end end)
NS.radar:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); NS.SavePos(self, "radarPos") end)

local radarTitle = NS.radar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
radarTitle:SetPoint("TOPLEFT", 8, -6)
local radarRows = {}
for i = 1, RADAR_ROWS do
    local fs = NS.radar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", NS.radar, "TOPLEFT", 8, -20 - (i - 1) * 14)
    fs:SetJustifyH("LEFT")
    radarRows[i] = fs
end

local function Hex(r, g, b)
    return string.format("%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local function RadarSort(a, b)
    if a.key ~= b.key then return a.key < b.key end
    local distanceOrder = { danger = 1, near = 2, unknown = 3, far = 4 }
    local aDistance = distanceOrder[a.cls or "danger"] or 5
    local bDistance = distanceOrder[b.cls or "danger"] or 5
    if aDistance ~= bDistance then return aDistance < bDistance end
    return a.rem < b.rem
end

-- El radar informa la distancia medida aunque quede fuera del radio de alerta.
-- Sin unitId (solo combat log o sincronía), muestra "?" mientras haya señales recientes.
local function RadarClass(name, p, now)
    if p.test then return "danger" end
    local cls = NS.DistanceClass(name, p)
    if cls == "danger" then return cls end
    if cls == "near" or cls == "far" then return cls end
    if cls == "unknown" and now - (p.seen or 0) <= NS.RADAR_FRESH then return cls end
    return nil
end

function NS.UpdateRadar(now)
    local list = {}
    local maxRows = math.min(RADAR_ROWS, math.max(1, NS.db.radarRows or 6))
    local me = NS.Txt("radarMe")
    if NS.endTime then
        local rem = math.max(0, NS.endTime - now)
        list[#list + 1] = { key = 2, rem = rem, name = me, mine = true,
            state = NS.Txt("stMyVomit", { s = math.ceil(rem) }), r = 1, g = 0.6, b = 0.1 }
    elseif NS.hadDebuff then
        list[#list + 1] = { key = 3, rem = 0, name = me, mine = true,
            state = NS.Txt("stPutrid"), r = 0.65, g = 1, b = 0.25 }
    end

    for name, p in pairs(NS.people) do
        local cls = RadarClass(name, p, now)
        if cls then
            local e
            if p.vomitUntil and now < p.vomitUntil then
                e = { key = 1, rem = 0, state = NS.Txt("stVomiting"), r = 1, g = 0.15, b = 0.15 }
            elseif p.vomitAt and not p.immune and p.vomitAt > now then
                local rem = p.vomitAt - now
                e = { key = 2, rem = rem, state = NS.Txt("stVomitIn", { s = math.ceil(rem), est = p.est and "~" or "" }),
                    r = 1, g = (rem <= (NS.db.alertSeconds or 10)) and 0.2 or 0.6, b = 0.1 }
            elseif p.putrid then
                e = { key = 3, rem = 0, state = p.immune and NS.Txt("stImmune") or NS.Txt("stPutrid"),
                    r = 0.65, g = 1, b = 0.25 }
            end
            if e then
                e.name, e.p, e.cls = name, p, cls
                list[#list + 1] = e
            end
        end
    end

    -- En el editor se muestran filas de ejemplo para poder ver los textos
    if NS.unlocked and #list == 0 then
        list[1] = { key = 1, rem = 0, name = "Jugador1", cls = "danger", state = NS.Txt("stVomiting"), r = 1, g = 0.15, b = 0.15 }
        list[2] = { key = 2, rem = 14, name = "Jugador2", cls = "danger", state = NS.Txt("stVomitIn", { s = 14, est = "" }), r = 1, g = 0.6, b = 0.1 }
        list[3] = { key = 2, rem = 40, name = "Jugador3", cls = "near", state = NS.Txt("stVomitIn", { s = 40, est = "~" }), r = 1, g = 0.6, b = 0.1 }
        list[4] = { key = 3, rem = 0, name = "Jugador4", cls = "near", state = NS.Txt("stImmune"), r = 0.65, g = 1, b = 0.25 }
    end
    table.sort(list, RadarSort)

    local n = math.min(#list, maxRows)
    if not (NS.db.showRadar and (n > 0 or NS.unlocked)) then
        if NS.radar:IsShown() then NS.radar:Hide() end
        return
    end

    radarTitle:SetText(NS.unlocked and (NS.Txt("radarTitle") .. " (arrastrá para mover)") or NS.Txt("radarTitle"))
    for i = 1, RADAR_ROWS do
        local e = list[i]
        if i <= n then
            local dist = e.mine and "" or ("  |cff999999" .. DIST_LABEL[e.cls or "unknown"] .. "|r")
            radarRows[i]:SetText(string.format("%s  |cff%s%s|r%s", e.name, Hex(e.r, e.g, e.b), e.state, dist))
            radarRows[i]:Show()
        elseif i == 1 then
            radarRows[i]:SetText("|cff999999" .. NS.Txt("radarEmpty") .. "|r")
            radarRows[i]:Show()
        else
            radarRows[i]:Hide()
        end
    end
    NS.radar:SetHeight(26 + math.max(n, 1) * 14)
    NS.radar:Show()
end
