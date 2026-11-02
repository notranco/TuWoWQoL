local ADDON, NS = ...

---------------------------------------------------------------------
-- Otros jugadores: estado, alertas y sincronizacion entre usuarios
---------------------------------------------------------------------
NS.PREFIX = "TWQ"
NS.VERSION = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "?"
NS.UPDATE_NOTICE = { version = nil }
NS.PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
NS.EXTRA_UNITS = { "target", "focus", "mouseover" }
-- Unidades que no generan eventos propios: se revisan una vez por segundo.
NS.TARGET_TOKENS = { "targettarget", "focustarget", "mouseovertarget" }
NS.DANGER_INDEX, NS.NEAR_INDEX = 3, 4 -- CheckInteractDistance: 3 = ~10 yd, 4 = ~28 yd
NS.DANGER_YARDS, NS.NEAR_YARDS = 10, 28 -- radios que usa LibRangeCheck-3.0 si esta disponible
NS.recentMsg = {} -- dedupe de mensajes de addon repetidos (grupo + /decir)

-- Si sabes el spellId del vomito de otros jugadores, agregalo aca: [id] = true.
-- Mientras tanto se reconoce por nombre del hechizo. Usa /twqol debug para ver ids.
NS.VOMIT_SPELL_IDS = {}
NS.VOMIT_NAME_PATTERNS = { "vomit", "vómit" }

-- Debuffs que aparecen al vomitar (spellIds tomados de capturas del servidor)
-- Cuando alguien vomita cerca, aplica el aturdimiento STUN_ID (5 s) a los jugadores cercanos;
-- al terminar, esos jugadores reciben Nauseabundo (30 s) y ¡Vomitado! (20 s) del vomitador.
-- Quien vomita NO ve esos dos debuffs en si mismo, solo en quienes contagia.
NS.STUN_ID = 24919    -- Nauseabundo (aturdido 5 s): señal inmediata de "X vomito"
NS.NAUSEA_ID = 49869  -- Nauseabundo (30 s): solo se registra en /twqol debug
NS.VOMITED_ID = 49870 -- ¡Vomitado!: marca que alguien vomito (refuerzo)

NS.debugOn = false
NS.lastHello, NS.lastHB, NS.helloAt = 0, 0, nil
NS.lastImm = nil
NS.selfVomited, NS.lastVSent = false, 0
NS.vomitOnMeBy = nil
NS.lastAck, NS.acks = {}, {}
NS.lastMouse = 0
NS.lastAwayCheck, NS.lastAwayMsg = 0, 0
NS.spellClass = {}

function NS.Say(str)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTuWoW QoL:|r " .. str)
end

-- true si yo PUEDO contagiarme (no tengo el debuff ni Estomago de hierro): solo entonces
-- importan los avisos sobre otros jugadores.
function NS.CanBeInfected()
    return not NS.hadDebuff and not NS.ImmuneAt(GetTime())
end

function NS.Person(name, src)
    local p = NS.people[name]
    if not p then p = {}; NS.people[name] = p end
    p.seen = GetTime()
    if src then p.src = src end
    return p
end

function NS.RefreshNameplateUnits()
    -- En algunos clientes los eventos ADDED/REMOVED no reflejan bien los tokens
    -- reutilizados. Reconcilia el conjunto con los tokens activos antes de medir.
    local active = {}
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            active[unit] = true
        end
    end
    for unit in pairs(NS.nameplateUnits) do
        if not active[unit] then NS.nameplateUnits[unit] = nil end
    end
    for unit in pairs(active) do NS.nameplateUnits[unit] = true end
end

function NS.HideFriendlyNameplate(unit)
    if not (NS.db and NS.db.silentNameplates and C_NamePlate and C_NamePlate.GetNamePlateForUnit)
       or not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsFriend("player", unit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or not plate.SetAlpha or NS.hiddenNameplateFrames[unit] then return end
    NS.hiddenNameplateFrames[unit] = { frame = plate, alpha = plate:GetAlpha() }
    plate:SetAlpha(0)
end

function NS.RestoreSilentNameplates(restoreCVar)
    for unit, saved in pairs(NS.hiddenNameplateFrames) do
        if saved.frame and saved.frame.SetAlpha then saved.frame:SetAlpha(saved.alpha or 1) end
        NS.hiddenNameplateFrames[unit] = nil
    end
    if restoreCVar and NS.db and NS.db.silentNameplatesOriginal ~= nil and SetCVar then
        SetCVar("nameplateShowFriends", NS.db.silentNameplatesOriginal)
        NS.db.silentNameplatesOriginal = nil
    end
end

function NS.SetSilentNameplateMode(enabled, restoreForLogout)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit and GetCVar and SetCVar) then return end
    if enabled then
        if NS.db.silentNameplatesOriginal == nil then
            NS.db.silentNameplatesOriginal = GetCVar("nameplateShowFriends") or "0"
        end
        SetCVar("nameplateShowFriends", "1")
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if UnitExists(unit) then NS.HideFriendlyNameplate(unit) end
        end
    else
        NS.RestoreSilentNameplates(true)
    end
    if restoreForLogout then NS.RestoreSilentNameplates(true) end
end

-- Mapa nombre -> unidad armado una sola vez por pasada (el radar y los avisos preguntan
-- por muchos jugadores seguidos y recorrer todas las unidades por cada uno era caro).
local unitMap, unitMapAt = {}, -1
function NS.BuildUnitMap(force)
    local now = GetTime()
    if not force and now - unitMapAt < 0.25 then return unitMap end
    unitMapAt = now
    wipe(unitMap)
    NS.RefreshNameplateUnits()
    local function add(unit)
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
            local name = UnitName(unit)
            if name and not unitMap[name] then unitMap[name] = unit end
        end
    end
    local members = NS.GroupUnits()
    for _, unit in ipairs(members) do add(unit) end
    for unit in pairs(NS.nameplateUnits) do add(unit) end
    for _, unit in ipairs(NS.EXTRA_UNITS) do add(unit) end
    for _, unit in ipairs(NS.TARGET_TOKENS) do add(unit) end
    for _, member in ipairs(members) do add(member .. "target") end
    return unitMap
end

function NS.FindUnit(name)
    local unit = NS.BuildUnitMap()[name]
    -- una unidad recien aparecida (nameplate, objetivo) todavia no esta en el cache
    if not unit and GetTime() - unitMapAt > 0.1 then unit = NS.BuildUnitMap(true)[name] end
    -- el token puede haber cambiado dentro de la ventana de cache
    if unit and UnitExists(unit) and UnitName(unit) == name then return unit end
end

-- LibRangeCheck-3.0 es opcional: si algun addon la trae, las distancias son mas finas.
local function RangeLib()
    return LibStub and LibStub("LibRangeCheck-3.0", true) or nil
end

-- "danger" (~10 yd), "near" (~28 yd) o "far" segun la unidad
function NS.UnitDistanceBand(unit)
    local rc = RangeLib()
    if rc then
        local ok, lo, hi = pcall(rc.GetRange, rc, unit)
        if ok and (lo or hi) then
            if hi and hi <= NS.DANGER_YARDS then return "danger" end
            if hi and hi <= NS.NEAR_YARDS then return "near" end
            if lo and lo >= NS.NEAR_YARDS then return "far" end
        end
    end
    if CheckInteractDistance(unit, NS.DANGER_INDEX) then return "danger" end
    if CheckInteractDistance(unit, NS.NEAR_INDEX) then return "near" end
    return "far"
end

-- true si la unidad esta dentro del radio de contagio configurado
function NS.UnitWithinRadius(unit, wide)
    local band = NS.UnitDistanceBand(unit)
    return band == "danger" or (wide and band == "near") or false
end

-- "danger" (~10 yd), "near" (~28 yd), "far" o "unknown" (no se puede medir)
function NS.DistanceClass(name, p)
    if p and p.test then return "danger" end
    local unit = NS.FindUnit(name)
    if unit then return NS.UnitDistanceBand(unit) end
    -- Sin unitId: si nos hablo por SAY hace poco, esta en rango de /decir (~25 yd)
    if p and p.chan == "SAY" and p.chanAt and GetTime() - p.chanAt < 15 then return "near" end
    return "unknown"
end

function NS.InAlertRange(cls)
    if cls == "danger" then return true end
    if cls == "near" then return NS.db.wideRange end
    if cls == "unknown" then return NS.db.warnUnknown end
    return false
end

function NS.SetPutrid(name, on, src)
    local p = NS.Person(name, src)
    if on then
        p.putrid = true
    else
        p.putrid = false
        p.vomitAt = nil
        p.warnedImminent = nil
    end
    return p
end

-- Un jugador con Putrefacto comio: vomitara en secs segundos (est = estimado)
function NS.SetEat(name, secs, src, est)
    local now = GetTime()
    local p = NS.Person(name, src)
    if src ~= "sync" and p.vomitAt and p.vomitAt > now then return end
    p.putrid = true
    p.vomitAt = now + secs
    p.est = est and true or false
    p.warnedImminent = nil
    if NS.db.warnEat and NS.CanBeInfected() and not p.immune and (not p.eatAlertAt or now - p.eatAlertAt > 5) then
        if NS.InAlertRange(NS.DistanceClass(name, p)) then
            p.eatAlertAt = now
            NS.ShowMsg("eat", NS.Txt("eat", { name = name, s = math.floor(secs + 0.5), est = est and "~" or "" }))
        end
    end
end

-- Un jugador vomito. El aturdimiento, ¡Vomitado! y Nauseabundo llegan uno tras otro por el
-- mismo vomito, asi que se ignoran repeticiones dentro de 25 s.
function NS.SetVomit(name, src)
    local now = GetTime()
    local p = NS.Person(name, src)
    local already = p.lastVomit and now - p.lastVomit < 25
    p.vomitAt = nil
    p.warnedImminent = nil
    if already then return p end
    p.lastVomit = now
    p.vomitUntil = now + 4
    if NS.db.warnTheirVomit and NS.CanBeInfected() and not p.immune then
        if NS.InAlertRange(NS.DistanceClass(name, p)) then
            NS.ShowMsg("theirVomit", NS.Txt("theirVomit", { name = name }))
        end
    end
    return p
end

-- Mira las auras de una unidad: Putrefacto, Estomago de hierro y si esta comiendo
local function ScanUnit(unit)
    local putrid, immune, eating, vomitedBy = false, false, false, nil
    for i = 1, 40 do
        local name, _, _, _, _, _, _, caster, _, _, spellId = UnitDebuff(unit, i)
        if not name then break end
        if spellId == NS.DEBUFF_ID then
            putrid = true
        elseif spellId == NS.IMMUNITY_ID then
            immune = true
        elseif spellId == NS.VOMITED_ID or spellId == NS.STUN_ID then
            -- quien vomito: el que aplico el debuff (o la propia unidad si no se sabe)
            vomitedBy = (caster and UnitName(caster)) or UnitName(unit)
        end
    end
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, i)
        if not name then break end
        if spellId == NS.IMMUNITY_ID then immune = true end
        if NS.FOOD_BUFFS[name] then eating = true end
    end
    return putrid, immune, eating, vomitedBy
end

-- true si yo tengo ¡Vomitado! o el aturdimiento de vomito aplicado por mi mismo.
-- Con el aturdimiento y sin caster conocido solo se acepta si mi cuenta esta por terminar
-- (si no, podria ser el vomito de un desconocido).
function NS.SelfVomitAura()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, caster, _, _, spellId = UnitDebuff("player", i)
        if not name then break end
        if spellId == NS.VOMITED_ID then
            if caster == nil or UnitIsUnit(caster, "player") then return true end
        elseif spellId == NS.STUN_ID then
            if caster and UnitIsUnit(caster, "player") then return true end
            if caster == nil and NS.endTime and NS.endTime - GetTime() <= 4 then return true end
        end
    end
    return false
end

-- Nombre del jugador que me aplico el aturdimiento de vomito (vomito cerca mio), si lo hay
function NS.AuraVomitOnMe()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, caster, _, _, spellId = UnitDebuff("player", i)
        if not name then break end
        if spellId == NS.STUN_ID and caster and not UnitIsUnit(caster, "player") then
            return UnitName(caster)
        end
    end
end

-- Avisa si la unidad tiene Putrefacto y esta dentro del radio de contagio.
-- seen (opcional) evita repetir el aviso para el mismo jugador dentro de una pasada.
function NS.AlertNearUnit(unit, now, seen)
    if not NS.db.warnNear or NS.unlocked then return end
    if NS.hadDebuff or NS.ImmuneAt(now) then return end
    if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player")
       or UnitIsDeadOrGhost(unit) then return end
    if not NS.HasPutrid(unit) then return end
    if not NS.UnitWithinRadius(unit, NS.db.wideRange) then return end
    local name = UnitName(unit) or unit
    if seen then
        if seen[name] then return end
        seen[name] = true
    end
    if not NS.nearCD[name] or now - NS.nearCD[name] >= NS.NEAR_COOLDOWN then
        NS.nearCD[name] = now
        NS.ShowMsg("contagion", NS.Txt("near", { name = name }))
    end
end

function NS.HandleUnitAura(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return end
    local name = UnitName(unit)
    if not name then return end
    local now = GetTime()
    local putrid, immune, eating, vomitedBy = ScanUnit(unit)
    local p = NS.people[name]
    if vomitedBy then
        if not (p and p.vomitedAura) then
            p = p or NS.Person(name, "aura")
            p.vomitedAura = true
            if vomitedBy ~= UnitName("player") then NS.SetVomit(vomitedBy, "aura") end
        end
    elseif p and p.vomitedAura then
        p.vomitedAura = nil
    end
    if putrid then
        if not p then p = NS.Person(name, "aura") end
        if not p.putrid then NS.SetPutrid(name, true, "aura") end
    elseif p and p.putrid then
        NS.SetPutrid(name, false, "aura")
    end
    if p then
        p.immune = immune
        local was = p.eating
        p.eating = eating
        p.seen = now
        if putrid and eating and not was and not (p.vomitAt and p.vomitAt > now) and not immune then
            NS.SetEat(name, NS.db.delay, "aura", true)
        end
    end
    -- Mouseover, target, focus y nameplates avisan al instante: si no, el aviso dependia de
    -- que la unidad siguiera ahi en la pasada de 1 s. Los miembros del grupo ya avisan por
    -- su cuenta (HandleGroupAura y CheckNear).
    if putrid and not string.find(unit, "^party%d$") and not string.find(unit, "^raid%d+$") then
        NS.AlertNearUnit(unit, now)
    end
end
