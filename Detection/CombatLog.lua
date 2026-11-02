local _, NS = ...

---------------------------------------------------------------------
-- Combat log: detecta a jugadores cercanos aunque no esten en tu grupo
-- (el combat log llega con jugadores hasta ~50 yardas)
---------------------------------------------------------------------
-- Mi propio vomito confirmado (aturdimiento / ¡Vomitado! aplicado por mi)
function NS.ConfirmSelfVomit(showWithoutCountdown)
    if NS.endTime and not NS.testing then
        NS.endTime = nil
        if NS.db.warnVomit then NS.ShowMsg("vomit", NS.Txt("vomit")) end
    elseif showWithoutCountdown and not NS.testing and NS.db and NS.db.warnVomit then
        NS.ShowMsg("vomit", NS.Txt("vomit"))
    end
    local now = GetTime()
    if now - NS.lastVSent > 25 then
        NS.lastVSent = now
        NS.Send("V")
    end
end

local CLEU_AURA = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_AURA_REFRESH = true }

-- Guarda en la DB los spellIds que se reconocieron como vomito por nombre. Sirven para completar
-- NS.VOMIT_SPELL_IDS con datos reales del servidor (se ven con /twqol ids).
function NS.LearnVomitSpell(spellId, spellName)
    local db = NS.db
    if not db or NS.VOMIT_SPELL_IDS[spellId] then return end
    db.learnedSpells = db.learnedSpells or {}
    if db.learnedSpells[spellId] then return end
    local count = 0
    for _ in pairs(db.learnedSpells) do count = count + 1 end
    if count >= 50 then return end
    db.learnedSpells[spellId] = spellName or "?"
    if NS.debugOn then NS.Say("spellId de vómito aprendido: " .. spellId .. " (" .. tostring(spellName) .. ")") end
end

function NS.ListLearnedSpells()
    local ids = {}
    for id, name in pairs((NS.db and NS.db.learnedSpells) or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    if #ids == 0 then
        NS.Say("Todavía no se aprendió ningún spellId de vómito de otros jugadores.")
        return
    end
    NS.Say("SpellIds de vómito vistos (agregalos a NS.VOMIT_SPELL_IDS):")
    for _, id in ipairs(ids) do NS.Say("  [" .. id .. "] = true  -- " .. tostring(NS.db.learnedSpells[id])) end
end

local function ClassifySpell(spellId, spellName)
    local c = NS.spellClass[spellId]
    if c ~= nil then return c end
    c = false
    if NS.VOMIT_SPELL_IDS[spellId] or (NS.db and NS.db.learnedSpells and NS.db.learnedSpells[spellId]) then
        c = "vomit"
    elseif spellName then
        local lower = string.lower(spellName)
        for _, pat in ipairs(NS.VOMIT_NAME_PATTERNS) do
            if string.find(lower, pat, 1, true) then c = "vomit"; break end
        end
        if c == "vomit" then NS.LearnVomitSpell(spellId, spellName) end
        if not c then
            for _, pat in ipairs(NS.POTION_PATTERNS) do
                if string.find(lower, pat, 1, true) then c = "potion"; break end
            end
        end
    end
    NS.spellClass[spellId] = c
    return c
end

local function DebugEv(sub, srcName, dstName, spellId, spellName)
    NS.Say(string.format("[%s] %s -> %s  id=%s  %s", tostring(sub), tostring(srcName), tostring(dstName),
        tostring(spellId), tostring(spellName)))
end

function NS.OnCombatLog(sub, srcName, srcFlags, dstName, dstFlags, spellId, spellName)
    if not spellId then return end
    -- el combat log dispara miles de eventos: se descarta lo que no sirve antes de cualquier trabajo
    if not (CLEU_AURA[sub] or sub == "SPELL_CAST_SUCCESS") then return end
    local me = NS.myName or UnitName("player")

    if CLEU_AURA[sub] then
        -- Aturdimiento (24919), ¡Vomitado! (49870) y Nauseabundo (49869): quien vomito es el
        -- que aplica el efecto sobre los demas
        if spellId == NS.STUN_ID or spellId == NS.VOMITED_ID or spellId == NS.NAUSEA_ID then
            if NS.debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
            if sub == "SPELL_AURA_APPLIED" and spellId ~= NS.NAUSEA_ID then
                local vomiter
                if srcName and bit.band(srcFlags or 0, NS.PLAYER_FLAG) ~= 0 then
                    vomiter = srcName
                elseif spellId == NS.VOMITED_ID and dstName and bit.band(dstFlags or 0, NS.PLAYER_FLAG) ~= 0 then
                    vomiter = dstName
                end
                if vomiter == me then
                    if spellId == NS.STUN_ID then NS.ConfirmSelfVomit() end
                elseif vomiter then
                    NS.SetVomit(vomiter, "log")
                end
            end
            return
        end
        if not dstName or dstName == me or bit.band(dstFlags or 0, NS.PLAYER_FLAG) == 0 then return end
        if spellId == NS.DEBUFF_ID then
            if NS.debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
            if sub == "SPELL_AURA_REMOVED" then
                if NS.people[dstName] then NS.SetPutrid(dstName, false, "log") end
            elseif not (NS.people[dstName] and NS.people[dstName].putrid) then
                NS.SetPutrid(dstName, true, "log")
            end
        elseif spellId == NS.IMMUNITY_ID then
            if NS.debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
            local p = NS.people[dstName]
            if sub == "SPELL_AURA_REMOVED" then
                if p then p.immune = false end
            else
                NS.Person(dstName, "log").immune = true
            end
        elseif sub == "SPELL_AURA_APPLIED" and spellName and NS.FOOD_BUFFS[spellName] then
            local p = NS.people[dstName]
            if p and p.putrid and not p.immune then
                if NS.debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
                NS.SetEat(dstName, NS.db.delay, "log", true)
            end
        end

    elseif sub == "SPELL_CAST_SUCCESS" then
        if not srcName or srcName == me or bit.band(srcFlags or 0, NS.PLAYER_FLAG) == 0 then return end
        local c = ClassifySpell(spellId, spellName)
        if c == "vomit" then
            if NS.debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
            NS.SetVomit(srcName, "log")
        elseif c == "potion" then
            local p = NS.people[srcName]
            if p and p.putrid and not p.immune then
                if NS.debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
                NS.SetEat(srcName, NS.db.delay, "log", true)
            end
        end
    end
end
