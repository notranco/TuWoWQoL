local _, NS = ...

-- Contagio
---------------------------------------------------------------------
function NS.CheckNear()
    if not NS.db.warnNear or NS.unlocked then return end
    if NS.HasPutrid("player") or NS.ImmuneAt(GetTime()) then return end
    NS.RefreshNameplateUnits()
    local now = GetTime()
    local seen = {}
    local members = NS.GroupUnits()
    for _, unit in ipairs(members) do NS.AlertNearUnit(unit, now, seen) end
    for unit in pairs(NS.nameplateUnits) do NS.AlertNearUnit(unit, now, seen) end

    -- Unidades que no avisan por evento (objetivo del objetivo, objetivos del grupo):
    -- se leen aca y se registran en la lista de jugadores para el radar.
    local function ScanToken(unit)
        if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
        NS.HandleUnitAura(unit)
        NS.AlertNearUnit(unit, now, seen)
    end
    for _, unit in ipairs(NS.TARGET_TOKENS) do ScanToken(unit) end
    for _, member in ipairs(members) do ScanToken(member .. "target") end
    for _, unit in ipairs(NS.EXTRA_UNITS) do NS.AlertNearUnit(unit, now, seen) end

    -- El combat log puede revelar Putrefacto en otros jugadores sin darnos un
    -- unitId. Solo usar esa señal si el usuario habilitó avisos sin distancia.
    if NS.db.warnUnknown then
        for name, p in pairs(NS.people) do
            if p.putrid and p.src == "log" and now - (p.seen or 0) <= NS.RADAR_FRESH
               and not seen[name] and NS.DistanceClass(name, p) == "unknown"
               and (not NS.nearCD[name] or now - NS.nearCD[name] >= NS.NEAR_COOLDOWN) then
                NS.nearCD[name] = now
                NS.ShowMsg("contagion", NS.Txt("near", { name = name }))
            end
        end
    end
end

function NS.HandleGroupAura(unit)
    local name = UnitName(unit)
    if not name then return end
    if NS.HasPutrid(unit) then
        if not NS.infected[name] then
            NS.infected[name] = true
            if NS.db.warnContagion and not NS.HasPutrid("player") and not NS.ImmuneAt(GetTime()) then
                NS.nearCD[name] = GetTime()
                NS.ShowMsg("contagion", NS.Txt("groupInfect", { name = name }))
            end
        end
    else
        NS.infected[name] = nil
    end
end
