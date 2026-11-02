local _, NS = ...

---------------------------------------------------------------------
-- Deteccion de auras
---------------------------------------------------------------------
function NS.HasPutrid(unit)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, i)
        if not name then break end
        if spellId == NS.DEBUFF_ID then return true end
    end
    return false
end

-- Momento (GetTime) en que termina Estomago de hierro, o nil si no lo tenes.
-- Se busca en buffs y debuffs por si el servidor lo aplica de cualquiera de las dos formas.
function NS.GetImmunityExpiry()
    for i = 1, 40 do
        local name, _, _, _, _, _, expires, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId == NS.IMMUNITY_ID then
            if not expires or expires == 0 then return math.huge end
            return expires
        end
    end
    for i = 1, 40 do
        local name, _, _, _, _, _, expires, _, _, _, spellId = UnitDebuff("player", i)
        if not name then break end
        if spellId == NS.IMMUNITY_ID then
            if not expires or expires == 0 then return math.huge end
            return expires
        end
    end
    return nil
end

function NS.IsEating()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if NS.FOOD_BUFFS[name] then return true end
    end
    return false
end

function NS.GroupUnits()
    local units = {}
    local raid = GetNumRaidMembers()
    if raid and raid > 0 then
        for i = 1, raid do units[#units + 1] = "raid" .. i end
    else
        for i = 1, (GetNumPartyMembers() or 0) do units[#units + 1] = "party" .. i end
    end
    return units
end

---------------------------------------------------------------------
-- Cuenta regresiva
---------------------------------------------------------------------
-- true si Estomago de hierro seguira activo (con margen) en el instante t
function NS.ImmuneAt(t)
    if NS.testing then return false end -- las pruebas ignoran la inmunidad
    local expires = NS.GetImmunityExpiry()
    return expires ~= nil and expires > t + NS.IMMUNITY_MARGIN
end
