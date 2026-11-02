local _, NS = ...

---------------------------------------------------------------------
-- Aviso para el que va a vomitar: "alejate de X, Y"
---------------------------------------------------------------------
function NS.AwayCheck(now, remaining)
    if now - NS.lastAwayCheck < 0.5 then return end
    NS.lastAwayCheck = now
    if NS.ImmuneAt(NS.endTime or now) then return end

    local wide = NS.db.wideRange
    local names, seen = {}, {}
    -- Cualquier unidad conocida cuenta: grupo, nameplates (aunque esten ocultas), objetivo,
    -- foco y cursor. Asi tambien avisa en mundo abierto, sin grupo.
    local function consider(unit)
        if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player")
           or UnitIsDeadOrGhost(unit) then return end
        local name = UnitName(unit)
        if not name or seen[name] then return end
        local p = NS.people[name]
        if p and (p.putrid or p.immune) then return end
        if NS.HasPutrid(unit) then return end -- ya tiene Putrefacto: no hay nada que contagiar
        if NS.UnitWithinRadius(unit, wide) then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    NS.RefreshNameplateUnits()
    for _, unit in ipairs(NS.GroupUnits()) do consider(unit) end
    for unit in pairs(NS.nameplateUnits) do consider(unit) end
    for _, unit in ipairs(NS.EXTRA_UNITS) do consider(unit) end
    -- usuarios fuera de grupo que confirmaron estar cerca (susurro "A")
    for name, t in pairs(NS.acks) do
        if now - t < 8 then
            if not seen[name] then
                seen[name] = true
                names[#names + 1] = name
            end
        else
            NS.acks[name] = nil
        end
    end

    if #names > 0 and now - NS.lastAwayMsg >= 4 then
        NS.lastAwayMsg = now
        local shown = {}
        for i = 1, math.min(3, #names) do shown[i] = names[i] end
        local list = table.concat(shown, ", ")
        if #names > 3 then list = list .. " y " .. (#names - 3) .. " más" end
        NS.ShowMsg("away", NS.Txt("away", { s = math.ceil(remaining), list = list }))
    end

    -- Opcional: avisar a los de cerca por /decir (una vez por cuenta regresiva)
    if #names > 0 and NS.db.autoSay and not NS.saidAway and now - NS.lastSay >= 60 then
        NS.saidAway, NS.lastSay = true, now
        pcall(SendChatMessage, NS.Txt("sayAway", { s = math.ceil(remaining) }), "SAY")
    end
end

---------------------------------------------------------------------
-- Mantenimiento (1 vez por segundo)
---------------------------------------------------------------------
local function TickPerson(name, p, now)
    if p.test and p.testUntil and now > p.testUntil then
        NS.people[name] = nil
        return
    end

    if p.vomitAt and now >= p.vomitAt + (p.test and 0 or 3) then
        if p.test then NS.SetVomit(name, "test") else p.vomitAt = nil end
    end
    if p.vomitUntil and now > p.vomitUntil then p.vomitUntil = nil end

    if p.vomitAt and not p.immune and not p.warnedImminent and NS.db.warnImminent and NS.CanBeInfected() then
        local rem = p.vomitAt - now
        if rem > 0 and rem <= (NS.db.alertSeconds or 10) then
            p.warnedImminent = true
            if NS.InAlertRange(NS.DistanceClass(name, p)) then
                NS.ShowMsg("imminent", NS.Txt("imminent", { name = name, s = math.ceil(rem) }))
            end
        end
    end

    -- limpieza de entradas viejas
    local idle = now - (p.seen or 0)
    if not p.putrid and not p.vomitAt and not p.vomitUntil then
        if (not p.immune and idle > 120) or idle > 900 then NS.people[name] = nil end
    end
end

function NS.RosterTick(now)
    for name, p in pairs(NS.people) do TickPerson(name, p, now) end
    for name, au in pairs(NS.addonUsers) do
        if now - (au.seen or 0) > 3600 then NS.addonUsers[name] = nil end
    end
    for key, t in pairs(NS.recentMsg) do
        if now - t > 5 then NS.recentMsg[key] = nil end
    end
    for name, t in pairs(NS.nearCD) do
        if now - t > 300 then NS.nearCD[name] = nil end
    end
    for name, t in pairs(NS.lastAck) do
        if now - t > 300 then NS.lastAck[name] = nil end
    end
end

function NS.SyncTick(now)
    if not NS.db then return end
    if NS.helloAt and now >= NS.helloAt then
        NS.helloAt = nil
        NS.SendHello()
    end
    if not NS.db.syncEnabled then return end
    if (NS.hadDebuff or NS.endTime) and now - NS.lastHB >= 5 then
        NS.lastHB = now
        NS.SendState()
    end
end
