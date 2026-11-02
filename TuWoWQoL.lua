local ADDON = "TuWoWQoL"
local FONT = "Fonts\\FRIZQT__.TTF"
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- spellId del debuff Putrefacto
local DEBUFF_ID = 900112
-- Estomago de hierro: evita el vomito mientras dure. Si se acaba antes de que
-- llegue el vomito, vomitas igual.
local IMMUNITY_ID = 50056
local IMMUNITY_MARGIN = 1 -- seg de margen: la inmunidad debe cubrir el vomito con 1s de sobra

local ICON_DEBUFF = "Interface\\Icons\\Spell_Shadow_CorpseExplode"
local ICON_SKULL = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"

-- Buffs que aparecen al comer/beber
local FOOD_BUFFS = {
    ["Comida"] = true, ["Bebida"] = true, ["Comer"] = true, ["Beber"] = true,
    ["Food"] = true, ["Drink"] = true, ["Refreshment"] = true,
}
-- Fragmentos (en minuscula) de hechizos de pociones/frascos usados
local POTION_PATTERNS = { "poci", "frasco", "potion", "flask", "elixir" }

-- Estilo de cada mensaje: color, icono, duracion (seg), sonido, prioridad,
-- tamaño de letra y animaciones. Los sonidos son nombres de sonido de 3.3.5.
local MSG = {
    start     = { color = { 1.00, 0.82, 0.25 }, icon = ICON_DEBUFF, dur = 4, sound = "AlarmClockWarning1",
                  prio = 2, size = 30, anim = "pop" },
    ten       = { color = { 1.00, 0.60, 0.10 }, icon = ICON_DEBUFF, dur = 4, sound = "RaidWarning",
                  prio = 2, size = 30, anim = "pop", pulse = true },
    tick      = { color = { 1.00, 0.25, 0.25 }, icon = nil, dur = 1, sound = "MapPing",
                  prio = 3, size = 56, anim = "punch", fade = 0.15 },
    vomit     = { color = { 1.00, 0.10, 0.10 }, icon = ICON_DEBUFF, dur = 4, sound = "igQuestFailed",
                  prio = 3, size = 38, anim = "pop", pulse = true, shake = true },
    applied   = { color = { 0.65, 1.00, 0.25 }, icon = ICON_DEBUFF, dur = 4, sound = "AlarmClockWarning2",
                  prio = 2, size = 24, anim = "pop" },
    contagion = { color = { 0.65, 1.00, 0.25 }, icon = ICON_SKULL, dur = 4, sound = "TellMessage",
                  prio = 1, size = 24, anim = "pop" },
    -- Otros jugadores
    eat       = { color = { 1.00, 0.82, 0.25 }, icon = ICON_SKULL, dur = 3, sound = "TellMessage",
                  prio = 2, size = 22, anim = "pop" },
    imminent  = { color = { 1.00, 0.45, 0.10 }, icon = ICON_SKULL, dur = 4, sound = "RaidWarning",
                  prio = 3, size = 30, anim = "pop", pulse = true },
    theirVomit = { color = { 1.00, 0.10, 0.10 }, icon = ICON_SKULL, dur = 3, sound = "igQuestFailed",
                  prio = 3, size = 32, anim = "pop", shake = true },
    night      = { color = { 1.00, 0.48, 0.12 }, icon = ICON_SKULL, dur = 6, sound = "RaidWarning",
                  prio = 2, size = 28, anim = "pop" },
    away      = { color = { 1.00, 0.30, 0.30 }, icon = ICON_DEBUFF, dur = 3, sound = "AlarmClockWarning3",
                  prio = 3, size = 26, anim = "pop", pulse = true },
}

local NEAR_COOLDOWN = 20 -- seg entre alertas de cercania por jugador
local MINIMAP_ICON = ICON_SKULL

local DEFAULTS = {
    delay = 60,
    sounds = true,
    animations = true,
    warnStart = true,
    warn10 = true,
    warnCount = true,
    warnVomit = true,
    warnApplied = true,
    warnContagion = true, -- alguien del grupo recibe el debuff
    warnNear = true,      -- jugador con el debuff cerca
    -- Otros jugadores / sincronizacion
    warnEat = true,       -- un jugador cercano come estando Putrefacto
    warnImminent = true,  -- un jugador cercano esta por vomitar
    warnTheirVomit = true, -- un jugador cercano vomita
    warnAway = true,      -- aviso para mi: alejate de X antes de vomitar
    wideRange = false,    -- true: ~28 yd, false: ~10 yd (radio de contagio por defecto)
    warnUnknown = false,  -- avisar aunque no se pueda medir la distancia
    silentNameplates = false, -- activar nameplates amistosos y ocultar las placas de jugadores
    warnNight = true,
    dayNightCycleMinutes = 120, -- duración real de un ciclo completo de 24 horas del juego
    dayNightSunrise = 360, -- 06:00 hora del juego
    dayNightSunset = 1200, -- 20:00 hora del juego
    alertSeconds = 10,    -- avisar cuando falten estos segundos
    syncEnabled = true,   -- compartir/recibir estado por grupo o banda
    syncNearby = false,   -- tambien por /decir a jugadores cercanos (experimental)
    showRadar = false,    -- el radar viene oculto por defecto
    showBar = false,
    eatFallback = false,  -- respaldo: detectar comida/pociones por buffs si no llega el mensaje
    radarScale = 1,
    radarRows = 6,
    texts = {},           -- textos personalizados (ver TEXTS)
    style = {},           -- estilo personalizado por tipo de aviso (tamaño, duracion, color, sonido)
    cfgVersion = 3,
    showMinimap = true,
    minimapAngle = 215,
    msgScale = 1,
    barScale = 1,
    msgPos = { point = "TOP", relPoint = "TOP", x = 0, y = -180 },
    barPos = { point = "TOP", relPoint = "TOP", x = 0, y = -250 },
    radarPos = { point = "LEFT", relPoint = "LEFT", x = 30, y = 0 },
}

local db
local unlocked = false -- true = modo "Editar interfaz"
local initialized = false

-- Segundos exactos entre comer estando Putrefacto y vomitar (confirmado en el servidor)
local EAT_DELAY = 60
local DAY_NIGHT = {
    gameMinutes = nil, lastSample = 0,
    observedPhase = nil, observedAt = nil,
    isDay = nil, warningSent = false,
    elapsed = 0, tooltipElapsed = 0, buttonCheckElapsed = 0,
}
-- Jugadores con distancia desconocida se muestran en el radar solo si hubo señales recientes
local RADAR_FRESH = 8

-- Textos editables. Marcadores: {name} {s} {est} {list}
local TEXTS = {
    start = "¡Vomitarás en {s} segundos!",
    ten = "¡Vas a vomitar en 10 segundos!",
    vomit = "¡VOMITANDO!",
    applied = "Estás Putrefacto: evitá comer, beber o usar pociones",
    groupInfect = "¡{name} está Putrefacto! Cuidado con el contagio",
    near = "¡{name} está Putrefacto y cerca tuyo!",
    eat = "{name} comió: vomita en {est}{s}s",
    imminent = "¡{name} vomita en {s}s! ¡Alejate!",
    theirVomit = "¡{name} está vomitando! ¡Alejate!",
    nightSoon = "La noche empieza en {m} min; los bichos pueden tener Rabiar.",
    vomitedOn = "¡{name} vomitó cerca tuyo!",
    away = "¡Alejate! Vomitás en {s}s y hay gente cerca: {list}",
    radarTitle = "Contagio",
    radarEmpty = "(nadie con Putrefacto cerca)",
    radarMe = "Vos",
    stVomitIn = "{est}vomita en {s}s",
    stMyVomit = "vomitás en {s}s",
    stVomiting = "¡VOMITANDO!",
    stPutrid = "Putrefacto",
    stImmune = "Putrefacto (inmune)",
    barText = "Vomitás en {s}s",
}

local function Txt(key, vars)
    local str = db and db.texts and db.texts[key]
    if not str or str == "" then str = TEXTS[key] or key end
    str = string.gsub(str, "{(%w+)}", function(k)
        local v = vars and vars[k]
        if v == nil then return "{" .. k .. "}" end
        return tostring(v)
    end)
    return str
end

-- Cuenta regresiva
local endTime, totalTime = nil, 60
local warned10, lastCount = false, nil
local testing = false
local hadDebuff, wasEating = false, false

-- Mensaje activo
local msgUntil, msgStart, curPriority, curStyle = 0, 0, 0, MSG.start

-- Contagio
local infected, nearCD, nearElapsed = {}, {}, 0

-- Otros jugadores (ver seccion "Otros jugadores") y usuarios del addon detectados
local people, addonUsers = {}, {}
-- Unidades expuestas por los nameplates de Awesome WotLK (TuWoW).
local nameplateUnits = {}
local hiddenNameplateFrames = {}
local radar

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = DeepCopy(v) end
    return out
end

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

---------------------------------------------------------------------
-- Anclaje y banner del mensaje
---------------------------------------------------------------------
local f = CreateFrame("Frame", "TuWoWQoLMessageFrame", UIParent)
f:SetSize(500, 70)
f:SetPoint("TOP", UIParent, "TOP", 0, -180)
f:SetFrameStrata("HIGH")
f:SetMovable(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")

local anchorTex = f:CreateTexture(nil, "BACKGROUND")
anchorTex:SetAllPoints()
anchorTex:SetTexture(0, 0.6, 0, 0.35)
anchorTex:Hide()
local anchorLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
anchorLabel:SetPoint("CENTER")
anchorLabel:SetText("TuWoW QoL - mensaje (arrastrá para mover)")
anchorLabel:Hide()

local banner = CreateFrame("Frame", nil, f)
banner:SetSize(400, 64)
banner:SetPoint("CENTER", f, "CENTER", 0, 0)
banner:Hide()

local bgL = banner:CreateTexture(nil, "BACKGROUND")
bgL:SetTexture(WHITE)
bgL:SetPoint("TOPLEFT")
bgL:SetPoint("BOTTOMRIGHT", banner, "BOTTOM", 0, 0)
bgL:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.7)
local bgR = banner:CreateTexture(nil, "BACKGROUND")
bgR:SetTexture(WHITE)
bgR:SetPoint("TOPLEFT", banner, "TOP", 0, 0)
bgR:SetPoint("BOTTOMRIGHT")
bgR:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0.7, 0, 0, 0, 0)

local lines = {}
local function MakeLine(top, left)
    local t = banner:CreateTexture(nil, "BORDER")
    t:SetTexture(WHITE)
    t:SetHeight(2)
    if top then
        if left then
            t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT", banner, "TOP", 0, 0)
        else
            t:SetPoint("TOPLEFT", banner, "TOP", 0, 0); t:SetPoint("TOPRIGHT")
        end
    else
        if left then
            t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT", banner, "BOTTOM", 0, 0)
        else
            t:SetPoint("BOTTOMLEFT", banner, "BOTTOM", 0, 0); t:SetPoint("BOTTOMRIGHT")
        end
    end
    t.left = left
    lines[#lines + 1] = t
end
MakeLine(true, true); MakeLine(true, false); MakeLine(false, true); MakeLine(false, false)

local iconBG = banner:CreateTexture(nil, "ARTWORK")
iconBG:SetTexture(WHITE)
iconBG:SetVertexColor(0, 0, 0, 0.85)
iconBG:SetSize(46, 46)
iconBG:SetPoint("LEFT", 26, 0)
local icon = banner:CreateTexture(nil, "OVERLAY")
icon:SetSize(40, 40)
icon:SetPoint("CENTER", iconBG, "CENTER")
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local text = banner:CreateFontString(nil, "OVERLAY")
text:SetFont(FONT, 30, "OUTLINE")
text:SetPoint("CENTER")

---------------------------------------------------------------------
-- Barra de tiempo
---------------------------------------------------------------------
local barFrame = CreateFrame("Frame", "TuWoWQoLBarFrame", UIParent)
barFrame:SetSize(260, 28)
barFrame:SetPoint("TOP", UIParent, "TOP", 0, -250)
barFrame:SetFrameStrata("HIGH")
barFrame:SetMovable(true)
barFrame:SetClampedToScreen(true)
barFrame:RegisterForDrag("LeftButton")
barFrame:SetBackdrop({
    bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
barFrame:SetBackdropColor(0, 0, 0, 0.65)
barFrame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
barFrame:SetAlpha(0)
barFrame:Hide()

local barIcon = barFrame:CreateTexture(nil, "ARTWORK")
barIcon:SetSize(22, 22)
barIcon:SetPoint("LEFT", 3, 0)
barIcon:SetTexture(ICON_DEBUFF)
barIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local bar = CreateFrame("StatusBar", nil, barFrame)
bar:SetPoint("LEFT", barIcon, "RIGHT", 4, 0)
bar:SetPoint("RIGHT", barFrame, "RIGHT", -3, 0)
bar:SetHeight(16)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetMinMaxValues(0, 1)
bar:SetValue(1)

local barBG = bar:CreateTexture(nil, "BACKGROUND")
barBG:SetAllPoints()
barBG:SetTexture(WHITE)
barBG:SetVertexColor(0.1, 0.1, 0.1, 0.9)

local spark = bar:CreateTexture(nil, "OVERLAY")
spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
spark:SetBlendMode("ADD")
spark:SetSize(20, 34)

local glow = bar:CreateTexture(nil, "OVERLAY")
glow:SetAllPoints()
glow:SetTexture(WHITE)
glow:SetVertexColor(1, 0.1, 0.1)
glow:SetBlendMode("ADD")
glow:SetAlpha(0)

local barText = bar:CreateFontString(nil, "OVERLAY")
barText:SetFont(FONT, 12, "OUTLINE")
barText:SetPoint("CENTER")

local barAlpha = 0

local function SavePos(frame, key)
    local point, _, relPoint, x, y = frame:GetPoint()
    db[key] = { point = point, relPoint = relPoint, x = x, y = y }
end

local function ApplyPos(frame, pos)
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

f:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self, "msgPos") end)
barFrame:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
barFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self, "barPos") end)

local function ApplyLock()
    f:EnableMouse(unlocked)
    barFrame:EnableMouse(unlocked)
    local strata = unlocked and "FULLSCREEN_DIALOG" or "HIGH"
    f:SetFrameStrata(strata)
    barFrame:SetFrameStrata(strata)
    if radar then
        radar:EnableMouse(unlocked)
        radar:SetFrameStrata(strata)
    end
    if unlocked then
        anchorTex:Show(); anchorLabel:Show()
    else
        anchorTex:Hide(); anchorLabel:Hide()
    end
end

local function ApplyScale()
    barFrame:SetScale(db.barScale or 1)
    if radar then radar:SetScale(db.radarScale or 1) end
end

---------------------------------------------------------------------
-- Mensajes
---------------------------------------------------------------------
local function ShowMsg(kind, str, silent)
    local st = MSG[kind]
    local ov = db.style and db.style[kind]
    local now = GetTime()
    if not unlocked and st.prio < curPriority and now < msgUntil then return end
    curPriority, curStyle = st.prio, st
    msgStart, msgUntil = now, now + ((ov and ov.dur) or st.dur)
    if unlocked then msgUntil = now + 3600 end -- en el editor la vista previa queda fija

    local col = (ov and ov.color) or st.color
    local r, g, b = col[1], col[2], col[3]
    text:SetFont(FONT, (ov and ov.size) or st.size, "OUTLINE")
    text:SetText(str)
    text:SetTextColor(r, g, b)
    text:ClearAllPoints()
    if st.icon then
        icon:SetTexture(st.icon)
        icon:Show(); iconBG:Show()
        text:SetPoint("CENTER", banner, "CENTER", 24, 0)
    else
        icon:Hide(); iconBG:Hide()
        text:SetPoint("CENTER", banner, "CENTER", 0, 0)
    end
    banner:SetWidth(math.min(900, math.max(240, text:GetStringWidth() + (st.icon and 150 or 90))))
    for _, t in ipairs(lines) do
        if t.left then
            t:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, 1)
        else
            t:SetGradientAlpha("HORIZONTAL", r, g, b, 1, r, g, b, 0)
        end
    end
    banner:SetAlpha(0)
    banner:Show()
    if st.sound and db.sounds and not silent and not (ov and ov.mute) then PlaySound(st.sound) end
end

local function HideMsg()
    banner:Hide()
    curPriority, msgUntil = 0, 0
end

local function UpdateBanner(now)
    if not banner:IsShown() then return end
    if now >= msgUntil then
        banner:Hide()
        curPriority = 0
        return
    end
    local st = curStyle
    local age, remaining = now - msgStart, msgUntil - now
    local scale, alpha, xoff = 1, 1, 0
    if db.animations then
        alpha = math.min(1, age / 0.12)
        local fo = st.fade or 0.4
        if remaining < fo then alpha = alpha * math.max(0, remaining / fo) end
        if st.anim == "pop" then
            if age < 0.15 then
                scale = 0.7 + 0.42 * (age / 0.15)
            elseif age < 0.25 then
                scale = 1.12 - 0.12 * ((age - 0.15) / 0.10)
            end
        elseif st.anim == "punch" then
            if age < 0.25 then
                local k = 1 - age / 0.25
                scale = 1 + 0.7 * k * k
            end
        end
        if st.pulse and age > 0.3 then alpha = alpha * (0.8 + 0.2 * math.sin(age * 9)) end
        if st.shake and age < 0.6 then xoff = math.sin(age * 80) * 10 * (1 - age / 0.6) end
    end
    banner:SetAlpha(alpha)
    banner:SetScale((db.msgScale or 1) * scale)
    banner:ClearAllPoints()
    banner:SetPoint("CENTER", f, "CENTER", xoff, 0)
end

---------------------------------------------------------------------
-- Deteccion de auras
---------------------------------------------------------------------
local function HasPutrid(unit)
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, i)
        if not name then break end
        if spellId == DEBUFF_ID then return true end
    end
    return false
end

-- Momento (GetTime) en que termina Estomago de hierro, o nil si no lo tenes.
-- Se busca en buffs y debuffs por si el servidor lo aplica de cualquiera de las dos formas.
local function GetImmunityExpiry()
    for i = 1, 40 do
        local name, _, _, _, _, _, expires, _, _, _, spellId = UnitBuff("player", i)
        if not name then break end
        if spellId == IMMUNITY_ID then
            if not expires or expires == 0 then return math.huge end
            return expires
        end
    end
    for i = 1, 40 do
        local name, _, _, _, _, _, expires, _, _, _, spellId = UnitDebuff("player", i)
        if not name then break end
        if spellId == IMMUNITY_ID then
            if not expires or expires == 0 then return math.huge end
            return expires
        end
    end
    return nil
end

local function IsEating()
    for i = 1, 40 do
        local name = UnitBuff("player", i)
        if not name then break end
        if FOOD_BUFFS[name] then return true end
    end
    return false
end

local function GroupUnits()
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
local function ImmuneAt(t)
    if testing then return false end -- las pruebas ignoran la inmunidad
    local expires = GetImmunityExpiry()
    return expires ~= nil and expires > t + IMMUNITY_MARGIN
end

---------------------------------------------------------------------
-- Otros jugadores: estado, alertas y sincronizacion entre usuarios
---------------------------------------------------------------------
local PREFIX = "TWQ"
local VERSION = (GetAddOnMetadata and GetAddOnMetadata(ADDON, "Version")) or "?"
local PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x400
local EXTRA_UNITS = { "target", "focus", "mouseover" }
local DANGER_INDEX, NEAR_INDEX = 3, 4 -- CheckInteractDistance: 3 = ~10 yd, 4 = ~28 yd

-- Si sabes el spellId del vomito de otros jugadores, agregalo aca: [id] = true.
-- Mientras tanto se reconoce por nombre del hechizo. Usa /twqol debug para ver ids.
local VOMIT_SPELL_IDS = {}
local VOMIT_NAME_PATTERNS = { "vomit", "vómit" }

-- Debuffs que aparecen al vomitar (spellIds tomados de capturas del servidor)
-- Cuando alguien vomita cerca, aplica el aturdimiento STUN_ID (5 s) a los jugadores cercanos;
-- al terminar, esos jugadores reciben Nauseabundo (30 s) y ¡Vomitado! (20 s) del vomitador.
-- Quien vomita NO ve esos dos debuffs en si mismo, solo en quienes contagia.
local STUN_ID = 24919    -- Nauseabundo (aturdido 5 s): señal inmediata de "X vomito"
local NAUSEA_ID = 49869  -- Nauseabundo (30 s): solo se registra en /twqol debug
local VOMITED_ID = 49870 -- ¡Vomitado!: marca que alguien vomito (refuerzo)

local debugOn = false
local lastHello, lastHB, helloAt = 0, 0, nil
local lastImm
local selfVomited, lastVSent = false, 0
local vomitOnMeBy
local lastAck, acks = {}, {}
local lastMouse = 0
local lastAwayCheck, lastAwayMsg = 0, 0
local spellClass = {}

local function Say(str)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffTuWoW QoL:|r " .. str)
end

-- true si yo no puedo contagiarme (ya tengo el debuff o Estomago de hierro)
local function IAmSafe()
    return not hadDebuff and not ImmuneAt(GetTime())
end

local function Person(name, src)
    local p = people[name]
    if not p then p = {}; people[name] = p end
    p.seen = GetTime()
    if src then p.src = src end
    return p
end

local function RefreshNameplateUnits()
    -- En algunos clientes los eventos ADDED/REMOVED no reflejan bien los tokens
    -- reutilizados. Reconcilia el conjunto con los tokens activos antes de medir.
    local active = {}
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and UnitIsPlayer(unit) then
            active[unit] = true
        end
    end
    for unit in pairs(nameplateUnits) do
        if not active[unit] then nameplateUnits[unit] = nil end
    end
    for unit in pairs(active) do nameplateUnits[unit] = true end
end

local function HideFriendlyNameplate(unit)
    if not (db and db.silentNameplates and C_NamePlate and C_NamePlate.GetNamePlateForUnit)
       or not UnitExists(unit) or not UnitIsPlayer(unit) or not UnitIsFriend("player", unit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or not plate.SetAlpha or hiddenNameplateFrames[unit] then return end
    hiddenNameplateFrames[unit] = { frame = plate, alpha = plate:GetAlpha() }
    plate:SetAlpha(0)
end

local function RestoreSilentNameplates(restoreCVar)
    for unit, saved in pairs(hiddenNameplateFrames) do
        if saved.frame and saved.frame.SetAlpha then saved.frame:SetAlpha(saved.alpha or 1) end
        hiddenNameplateFrames[unit] = nil
    end
    if restoreCVar and db and db.silentNameplatesOriginal ~= nil and SetCVar then
        SetCVar("nameplateShowFriends", db.silentNameplatesOriginal)
        db.silentNameplatesOriginal = nil
    end
end

local function SetSilentNameplateMode(enabled, restoreForLogout)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit and GetCVar and SetCVar) then return end
    if enabled then
        if db.silentNameplatesOriginal == nil then
            db.silentNameplatesOriginal = GetCVar("nameplateShowFriends") or "0"
        end
        SetCVar("nameplateShowFriends", "1")
        for i = 1, 40 do
            local unit = "nameplate" .. i
            if UnitExists(unit) then HideFriendlyNameplate(unit) end
        end
    else
        RestoreSilentNameplates(true)
    end
    if restoreForLogout then RestoreSilentNameplates(true) end
end

local function FindUnit(name)
    RefreshNameplateUnits()
    for _, unit in ipairs(GroupUnits()) do
        if UnitName(unit) == name then return unit end
    end
    for unit in pairs(nameplateUnits) do
        if UnitExists(unit) and UnitIsPlayer(unit) and UnitName(unit) == name then
            return unit
        end
    end
    for _, unit in ipairs(EXTRA_UNITS) do
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
           and UnitName(unit) == name then
            return unit
        end
    end
end

-- "danger" (~10 yd), "near" (~28 yd), "far" o "unknown" (no se puede medir)
local function DistanceClass(name, p)
    if p and p.test then return "danger" end
    local unit = FindUnit(name)
    if unit then
        if CheckInteractDistance(unit, DANGER_INDEX) then return "danger" end
        if CheckInteractDistance(unit, NEAR_INDEX) then return "near" end
        return "far"
    end
    -- Sin unitId: si nos hablo por SAY hace poco, esta en rango de /decir (~25 yd)
    if p and p.chan == "SAY" and p.chanAt and GetTime() - p.chanAt < 15 then return "near" end
    return "unknown"
end

local function InAlertRange(cls)
    if cls == "danger" then return true end
    if cls == "near" then return db.wideRange end
    if cls == "unknown" then return db.warnUnknown end
    return false
end

local function SetPutrid(name, on, src)
    local p = Person(name, src)
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
local function SetEat(name, secs, src, est)
    local now = GetTime()
    local p = Person(name, src)
    if src ~= "sync" and p.vomitAt and p.vomitAt > now then return end
    p.putrid = true
    p.vomitAt = now + secs
    p.est = est and true or false
    p.warnedImminent = nil
    if db.warnEat and IAmSafe() and not p.immune and (not p.eatAlertAt or now - p.eatAlertAt > 5) then
        if InAlertRange(DistanceClass(name, p)) then
            p.eatAlertAt = now
            ShowMsg("eat", Txt("eat", { name = name, s = math.floor(secs + 0.5), est = est and "~" or "" }))
        end
    end
end

-- Un jugador vomito. El aturdimiento, ¡Vomitado! y Nauseabundo llegan uno tras otro por el
-- mismo vomito, asi que se ignoran repeticiones dentro de 25 s.
local function SetVomit(name, src)
    local now = GetTime()
    local p = Person(name, src)
    local already = p.lastVomit and now - p.lastVomit < 25
    p.vomitAt = nil
    p.warnedImminent = nil
    if already then return p end
    p.lastVomit = now
    p.vomitUntil = now + 4
    if db.warnTheirVomit and IAmSafe() and not p.immune then
        if InAlertRange(DistanceClass(name, p)) then
            ShowMsg("theirVomit", Txt("theirVomit", { name = name }))
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
        if spellId == DEBUFF_ID then
            putrid = true
        elseif spellId == IMMUNITY_ID then
            immune = true
        elseif spellId == VOMITED_ID or spellId == STUN_ID then
            -- quien vomito: el que aplico el debuff (o la propia unidad si no se sabe)
            vomitedBy = (caster and UnitName(caster)) or UnitName(unit)
        end
    end
    for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, i)
        if not name then break end
        if spellId == IMMUNITY_ID then immune = true end
        if FOOD_BUFFS[name] then eating = true end
    end
    return putrid, immune, eating, vomitedBy
end

-- true si yo tengo ¡Vomitado! o el aturdimiento de vomito aplicado por mi mismo.
-- Con el aturdimiento y sin caster conocido solo se acepta si mi cuenta esta por terminar
-- (si no, podria ser el vomito de un desconocido).
local function SelfVomitAura()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, caster, _, _, spellId = UnitDebuff("player", i)
        if not name then break end
        if spellId == VOMITED_ID then
            if caster == nil or UnitIsUnit(caster, "player") then return true end
        elseif spellId == STUN_ID then
            if caster and UnitIsUnit(caster, "player") then return true end
            if caster == nil and endTime and endTime - GetTime() <= 4 then return true end
        end
    end
    return false
end

-- Nombre del jugador que me aplico el aturdimiento de vomito (vomito cerca mio), si lo hay
local function AuraVomitOnMe()
    for i = 1, 40 do
        local name, _, _, _, _, _, _, caster, _, _, spellId = UnitDebuff("player", i)
        if not name then break end
        if spellId == STUN_ID and caster and not UnitIsUnit(caster, "player") then
            return UnitName(caster)
        end
    end
end

local function HandleUnitAura(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return end
    local name = UnitName(unit)
    if not name then return end
    local now = GetTime()
    local putrid, immune, eating, vomitedBy = ScanUnit(unit)
    local p = people[name]
    if vomitedBy then
        if not (p and p.vomitedAura) then
            p = p or Person(name, "aura")
            p.vomitedAura = true
            if vomitedBy ~= UnitName("player") then SetVomit(vomitedBy, "aura") end
        end
    elseif p and p.vomitedAura then
        p.vomitedAura = nil
    end
    if putrid then
        if not p then p = Person(name, "aura") end
        if not p.putrid then SetPutrid(name, true, "aura") end
    elseif p and p.putrid then
        SetPutrid(name, false, "aura")
    end
    if p then
        p.immune = immune
        local was = p.eating
        p.eating = eating
        p.seen = now
        if putrid and eating and not was and not (p.vomitAt and p.vomitAt > now) and not immune then
            SetEat(name, db.delay, "aura", true)
        end
    end
end

---------------------------------------------------------------------
-- Envio y recepcion de mensajes entre usuarios del addon
---------------------------------------------------------------------
local function ImmSecs(expires)
    if not expires then return 0 end
    if expires == math.huge then return 9999 end
    return math.max(1, math.floor(expires - GetTime()))
end

local function Send(msg)
    if not db or not db.syncEnabled then return end
    local ch
    local _, itype = IsInInstance()
    if itype == "pvp" then
        ch = "BATTLEGROUND"
    elseif (GetNumRaidMembers() or 0) > 0 then
        ch = "RAID"
    elseif (GetNumPartyMembers() or 0) > 0 then
        ch = "PARTY"
    end
    if ch then pcall(SendAddonMessage, PREFIX, msg, ch) end
    if db.syncNearby then pcall(SendAddonMessage, PREFIX, msg, "SAY") end
end

local function SendState()
    local now = GetTime()
    local rem = "-"
    if endTime and not testing then rem = tostring(math.max(0, math.ceil(endTime - now))) end
    Send(string.format("S:%d:%s:%d", hadDebuff and 1 or 0, rem, ImmSecs(GetImmunityExpiry())))
end

local function SendHello()
    local now = GetTime()
    if now - lastHello < 8 then return end
    lastHello = now
    Send("H:" .. tostring(VERSION))
    if hadDebuff or endTime then SendState() end
end

local function Num(str)
    local n = tonumber(str)
    if n and n >= 0 and n <= 3600 then return n end
end

-- Jugador fuera del grupo que nos hablo por /decir y esta por vomitar: le avisamos
-- por susurro que estamos cerca, para que su aviso "alejate" nos incluya.
local function MaybeAck(sender, p, rem)
    if not rem or rem > 15 or p.chan ~= "SAY" then return end
    if FindUnit(sender) or not IAmSafe() then return end
    local now = GetTime()
    if lastAck[sender] and now - lastAck[sender] < 6 then return end
    lastAck[sender] = now
    pcall(SendAddonMessage, PREFIX, "A", "WHISPER", sender)
end

local function OnAddonMessage(prefix, msg, channel, sender)
    if prefix ~= PREFIX or not db or not db.syncEnabled or not msg or not sender then return end
    if sender == UnitName("player") then return end
    local now = GetTime()
    local au = addonUsers[sender]
    local isNew = false
    if not au then au = {}; addonUsers[sender] = au; isNew = true end
    au.seen = now

    local cmd, rest = string.match(msg, "^(%a):?(.*)$")
    if not cmd then return end

    if cmd == "H" then
        au.ver = string.match(rest, "^([^:]*)")
        if isNew and not helloAt then helloAt = now + 1 + math.random() end
        return
    elseif cmd == "A" then
        acks[sender] = now
        return
    end

    local p = Person(sender, "sync")
    p.addon = true
    p.chan = channel and string.upper(channel) or nil
    p.chanAt = now

    if cmd == "P" then
        SetPutrid(sender, rest == "1", "sync")
    elseif cmd == "E" then
        local s = Num(rest)
        if s then
            SetEat(sender, s, "sync", false)
            MaybeAck(sender, p, s)
        end
    elseif cmd == "V" then
        SetVomit(sender, "sync")
    elseif cmd == "C" then
        p.vomitAt = nil
        p.warnedImminent = nil
    elseif cmd == "I" then
        local s = Num(rest)
        p.immune = s ~= nil and s > 0
    elseif cmd == "S" then
        local pu, rem, imm = string.match(rest, "^(%d):([%-%d]*):(%d+)$")
        if pu then
            p.immune = (tonumber(imm) or 0) > 0
            if pu == "1" then
                p.putrid = true
                local r = Num(rem)
                if r then
                    if not (p.vomitAt and math.abs(p.vomitAt - (now + r)) < 3) then
                        SetEat(sender, r, "sync", false)
                    end
                    MaybeAck(sender, p, r)
                else
                    p.vomitAt = nil
                end
            else
                SetPutrid(sender, false, "sync")
            end
        end
    end
end

---------------------------------------------------------------------
-- Combat log: detecta a jugadores cercanos aunque no esten en tu grupo
-- (el combat log llega con jugadores hasta ~50 yardas)
---------------------------------------------------------------------
-- Mi propio vomito confirmado (aturdimiento / ¡Vomitado! aplicado por mi)
local function ConfirmSelfVomit()
    if endTime and not testing then
        endTime = nil
        if db.warnVomit then ShowMsg("vomit", Txt("vomit")) end
    end
    local now = GetTime()
    if now - lastVSent > 25 then
        lastVSent = now
        Send("V")
    end
end

local CLEU_AURA = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_AURA_REFRESH = true }

local function ClassifySpell(spellId, spellName)
    local c = spellClass[spellId]
    if c ~= nil then return c end
    c = false
    if VOMIT_SPELL_IDS[spellId] then
        c = "vomit"
    elseif spellName then
        local lower = string.lower(spellName)
        for _, pat in ipairs(VOMIT_NAME_PATTERNS) do
            if string.find(lower, pat, 1, true) then c = "vomit"; break end
        end
        if not c then
            for _, pat in ipairs(POTION_PATTERNS) do
                if string.find(lower, pat, 1, true) then c = "potion"; break end
            end
        end
    end
    spellClass[spellId] = c
    return c
end

local function DebugEv(sub, srcName, dstName, spellId, spellName)
    Say(string.format("[%s] %s -> %s  id=%s  %s", tostring(sub), tostring(srcName), tostring(dstName),
        tostring(spellId), tostring(spellName)))
end

local function OnCombatLog(sub, srcName, srcFlags, dstName, dstFlags, spellId, spellName)
    if not spellId then return end
    local me = UnitName("player")

    if CLEU_AURA[sub] then
        -- Aturdimiento (24919), ¡Vomitado! (49870) y Nauseabundo (49869): quien vomito es el
        -- que aplica el efecto sobre los demas
        if spellId == STUN_ID or spellId == VOMITED_ID or spellId == NAUSEA_ID then
            if debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
            if sub == "SPELL_AURA_APPLIED" and spellId ~= NAUSEA_ID then
                local vomiter
                if srcName and bit.band(srcFlags or 0, PLAYER_FLAG) ~= 0 then
                    vomiter = srcName
                elseif spellId == VOMITED_ID and dstName and bit.band(dstFlags or 0, PLAYER_FLAG) ~= 0 then
                    vomiter = dstName
                end
                if vomiter == me then
                    if spellId == STUN_ID then ConfirmSelfVomit() end
                elseif vomiter then
                    SetVomit(vomiter, "log")
                end
            end
            return
        end
        if not dstName or dstName == me or bit.band(dstFlags or 0, PLAYER_FLAG) == 0 then return end
        if spellId == DEBUFF_ID then
            if debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
            if sub == "SPELL_AURA_REMOVED" then
                if people[dstName] then SetPutrid(dstName, false, "log") end
            elseif not (people[dstName] and people[dstName].putrid) then
                SetPutrid(dstName, true, "log")
            end
        elseif spellId == IMMUNITY_ID then
            if debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
            local p = people[dstName]
            if sub == "SPELL_AURA_REMOVED" then
                if p then p.immune = false end
            else
                Person(dstName, "log").immune = true
            end
        elseif sub == "SPELL_AURA_APPLIED" and spellName and FOOD_BUFFS[spellName] then
            local p = people[dstName]
            if p and p.putrid and not p.immune then
                if debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
                SetEat(dstName, db.delay, "log", true)
            end
        end

    elseif sub == "SPELL_CAST_SUCCESS" then
        if not srcName or srcName == me or bit.band(srcFlags or 0, PLAYER_FLAG) == 0 then return end
        local c = ClassifySpell(spellId, spellName)
        if c == "vomit" then
            if debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
            SetVomit(srcName, "log")
        elseif c == "potion" then
            local p = people[srcName]
            if p and p.putrid and not p.immune then
                if debugOn then DebugEv(sub, srcName, dstName, spellId, spellName) end
                SetEat(srcName, db.delay, "log", true)
            end
        end
    end
end

---------------------------------------------------------------------
-- Aviso para el que va a vomitar: "alejate de X, Y"
---------------------------------------------------------------------
local function AwayCheck(now, remaining)
    if now - lastAwayCheck < 0.5 then return end
    lastAwayCheck = now
    if ImmuneAt(endTime or now) then return end

    local idx = db.wideRange and NEAR_INDEX or DANGER_INDEX
    local names, seen = {}, {}
    for _, unit in ipairs(GroupUnits()) do
        if UnitExists(unit) and not UnitIsDeadOrGhost(unit) and CheckInteractDistance(unit, idx) then
            local name = UnitName(unit)
            local p = name and people[name]
            if name and not (p and (p.putrid or p.immune)) then
                names[#names + 1] = name
                seen[name] = true
            end
        end
    end
    -- usuarios fuera de grupo que confirmaron estar cerca (susurro "A")
    for name, t in pairs(acks) do
        if now - t < 8 then
            if not seen[name] then names[#names + 1] = name end
        else
            acks[name] = nil
        end
    end

    if #names > 0 and now - lastAwayMsg >= 4 then
        lastAwayMsg = now
        local shown = {}
        for i = 1, math.min(3, #names) do shown[i] = names[i] end
        local list = table.concat(shown, ", ")
        if #names > 3 then list = list .. " y " .. (#names - 3) .. " más" end
        ShowMsg("away", Txt("away", { s = math.ceil(remaining), list = list }))
    end
end

---------------------------------------------------------------------
-- Mantenimiento (1 vez por segundo)
---------------------------------------------------------------------
local function TickPerson(name, p, now)
    if p.test and p.testUntil and now > p.testUntil then
        people[name] = nil
        return
    end

    if p.vomitAt and now >= p.vomitAt + (p.test and 0 or 3) then
        if p.test then SetVomit(name, "test") else p.vomitAt = nil end
    end
    if p.vomitUntil and now > p.vomitUntil then p.vomitUntil = nil end

    if p.vomitAt and not p.immune and not p.warnedImminent and db.warnImminent and IAmSafe() then
        local rem = p.vomitAt - now
        if rem > 0 and rem <= (db.alertSeconds or 10) then
            p.warnedImminent = true
            if InAlertRange(DistanceClass(name, p)) then
                ShowMsg("imminent", Txt("imminent", { name = name, s = math.ceil(rem) }))
            end
        end
    end

    -- limpieza de entradas viejas
    local idle = now - (p.seen or 0)
    if not p.putrid and not p.vomitAt and not p.vomitUntil then
        if (not p.immune and idle > 120) or idle > 900 then people[name] = nil end
    end
end

local function RosterTick(now)
    for name, p in pairs(people) do TickPerson(name, p, now) end
    for name, au in pairs(addonUsers) do
        if now - (au.seen or 0) > 3600 then addonUsers[name] = nil end
    end
end

local function SyncTick(now)
    if not db.syncEnabled then return end
    if helloAt and now >= helloAt then
        helloAt = nil
        SendHello()
    end
    if (hadDebuff or endTime) and now - lastHB >= 5 then
        lastHB = now
        SendState()
    end
end

---------------------------------------------------------------------
-- Pruebas y utilidades
---------------------------------------------------------------------
local function TestSync()
    local now = GetTime()
    local function fake(name, rem, est, immune)
        local p = Person(name, "test")
        p.test, p.testUntil, p.addon = true, now + 24, true
        p.putrid, p.est, p.immune, p.warnedImminent = true, est, immune or false, nil
        p.vomitAt = rem and (now + rem) or nil
        p.vomitUntil = nil
    end
    fake("Jugador1", 14, false)
    fake("Jugador2", 40, true)
    fake("Jugador3", nil, false, true)
    if db.warnEat then ShowMsg("eat", Txt("eat", { name = "Jugador1", s = 14, est = "" })) end
end

local function ListUsers()
    local names = {}
    for name, au in pairs(addonUsers) do names[#names + 1] = name .. " (v" .. tostring(au.ver or "?") .. ")" end
    table.sort(names)
    if #names == 0 then
        Say("Todavía no detecté usuarios del addon. Se detectan al entrar a un grupo o al coincidir cerca (si Sincronía cercana está activa).")
    else
        Say("Usuarios con el addon: " .. table.concat(names, ", "))
    end
end

local function ShowStatus()
    if not db then
        Say("La configuración todavía no está lista.")
        return
    end

    local now = GetTime()
    local condition
    if hadDebuff then
        condition = "Putrefacto"
    else
        condition = "sin Putrefacto"
    end

    if endTime and not testing then
        condition = condition .. "; vómito en " .. math.max(0, math.ceil(endTime - now)) .. " s"
    elseif testing then
        condition = condition .. "; cuenta regresiva de prueba activa"
    end

    local immune = GetImmunityExpiry()
    if immune then
        local remaining = immune == math.huge and "indefinida" or (math.max(0, math.ceil(immune - now)) .. " s")
        condition = condition .. "; Estómago de hierro: " .. remaining
    else
        condition = condition .. "; sin inmunidad detectada"
    end
    Say("Estado: " .. condition .. ".")

    local peers = {}
    for name, au in pairs(addonUsers) do
        if now - (au.seen or 0) <= 3600 then
            peers[#peers + 1] = name .. " (v" .. tostring(au.ver or "?") .. ")"
        end
    end
    table.sort(peers)
    local groupSize = (GetNumRaidMembers() or 0) + (GetNumRaidMembers() == 0 and (GetNumPartyMembers() or 0) or 0)
    local syncMode = db.syncEnabled and (groupSize > 0 and "grupo/banda" or "sin grupo") or "desactivada"
    if db.syncEnabled and db.syncNearby then syncMode = syncMode .. " + /decir" end
    Say("Sincronización: " .. syncMode .. ". Usuarios detectados: " .. #peers .. ".")
    if #peers > 0 then
        local shown = {}
        for i = 1, math.min(5, #peers) do shown[i] = peers[i] end
        local suffix = #peers > 5 and (" y " .. (#peers - 5) .. " más") or ""
        Say("Usuarios: " .. table.concat(shown, ", ") .. suffix .. ".")
    end
end

local function ShowHelp()
    Say("Comandos: /twqol o /tuwowqol (opciones), status, debug, radar, lista, test, editar.")
end

---------------------------------------------------------------------
-- Radar de contagio (lista en pantalla)
---------------------------------------------------------------------
local RADAR_ROWS = 8
local DIST_LABEL = { danger = "<10y", near = "<28y", far = "lejos", unknown = "?" }

radar = CreateFrame("Frame", "TuWoWQoLRadar", UIParent)
radar:SetSize(250, 40)
radar:SetPoint("LEFT", UIParent, "LEFT", 30, 0)
radar:SetFrameStrata("HIGH")
radar:SetMovable(true)
radar:SetClampedToScreen(true)
radar:RegisterForDrag("LeftButton")
radar:SetBackdrop({
    bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
radar:SetBackdropColor(0, 0, 0, 0.55)
radar:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
radar:Hide()
radar:SetScript("OnDragStart", function(self) if unlocked then self:StartMoving() end end)
radar:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePos(self, "radarPos") end)

local radarTitle = radar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
radarTitle:SetPoint("TOPLEFT", 8, -6)
local radarRows = {}
for i = 1, RADAR_ROWS do
    local fs = radar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", radar, "TOPLEFT", 8, -20 - (i - 1) * 14)
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
    local cls = DistanceClass(name, p)
    if cls == "danger" then return cls end
    if cls == "near" or cls == "far" then return cls end
    if cls == "unknown" and now - (p.seen or 0) <= RADAR_FRESH then return cls end
    return nil
end

local function UpdateRadar(now)
    local list = {}
    local maxRows = math.min(RADAR_ROWS, math.max(1, db.radarRows or 6))
    local me = Txt("radarMe")
    if endTime then
        local rem = math.max(0, endTime - now)
        list[#list + 1] = { key = 2, rem = rem, name = me, mine = true,
            state = Txt("stMyVomit", { s = math.ceil(rem) }), r = 1, g = 0.6, b = 0.1 }
    elseif hadDebuff then
        list[#list + 1] = { key = 3, rem = 0, name = me, mine = true,
            state = Txt("stPutrid"), r = 0.65, g = 1, b = 0.25 }
    end

    for name, p in pairs(people) do
        local cls = RadarClass(name, p, now)
        if cls then
            local e
            if p.vomitUntil and now < p.vomitUntil then
                e = { key = 1, rem = 0, state = Txt("stVomiting"), r = 1, g = 0.15, b = 0.15 }
            elseif p.vomitAt and not p.immune and p.vomitAt > now then
                local rem = p.vomitAt - now
                e = { key = 2, rem = rem, state = Txt("stVomitIn", { s = math.ceil(rem), est = p.est and "~" or "" }),
                    r = 1, g = (rem <= (db.alertSeconds or 10)) and 0.2 or 0.6, b = 0.1 }
            elseif p.putrid then
                e = { key = 3, rem = 0, state = p.immune and Txt("stImmune") or Txt("stPutrid"),
                    r = 0.65, g = 1, b = 0.25 }
            end
            if e then
                e.name, e.p, e.cls = name, p, cls
                list[#list + 1] = e
            end
        end
    end

    -- En el editor se muestran filas de ejemplo para poder ver los textos
    if unlocked and #list == 0 then
        list[1] = { key = 1, rem = 0, name = "Jugador1", cls = "danger", state = Txt("stVomiting"), r = 1, g = 0.15, b = 0.15 }
        list[2] = { key = 2, rem = 14, name = "Jugador2", cls = "danger", state = Txt("stVomitIn", { s = 14, est = "" }), r = 1, g = 0.6, b = 0.1 }
        list[3] = { key = 2, rem = 40, name = "Jugador3", cls = "near", state = Txt("stVomitIn", { s = 40, est = "~" }), r = 1, g = 0.6, b = 0.1 }
        list[4] = { key = 3, rem = 0, name = "Jugador4", cls = "near", state = Txt("stImmune"), r = 0.65, g = 1, b = 0.25 }
    end
    table.sort(list, RadarSort)

    local n = math.min(#list, maxRows)
    if not (db.showRadar and (n > 0 or unlocked)) then
        if radar:IsShown() then radar:Hide() end
        return
    end

    radarTitle:SetText(unlocked and (Txt("radarTitle") .. " (arrastrá para mover)") or Txt("radarTitle"))
    for i = 1, RADAR_ROWS do
        local e = list[i]
        if i <= n then
            local dist = e.mine and "" or ("  |cff999999" .. DIST_LABEL[e.cls or "unknown"] .. "|r")
            radarRows[i]:SetText(string.format("%s  |cff%s%s|r%s", e.name, Hex(e.r, e.g, e.b), e.state, dist))
            radarRows[i]:Show()
        elseif i == 1 then
            radarRows[i]:SetText("|cff999999" .. Txt("radarEmpty") .. "|r")
            radarRows[i]:Show()
        else
            radarRows[i]:Hide()
        end
    end
    radar:SetHeight(26 + math.max(n, 1) * 14)
    radar:Show()
end

local function Trigger(delay, isTest)
    if endTime then return end
    local d = delay or db.delay
    totalTime = d
    testing = isTest and true or false
    endTime = GetTime() + d
    warned10 = d <= 10
    lastCount = nil
    if db.warnStart and not ImmuneAt(endTime) then
        ShowMsg("start", Txt("start", { s = d }))
    end
    if not testing then Send("E:" .. d) end
end

local function CancelCountdown()
    if endTime and not testing then Send("C") end
    endTime = nil
    testing = false
    HideMsg()
end

local function UpdateCountdown(now)
    if not endTime then return end
    local remaining = endTime - now

    if remaining <= 10 and not warned10 then
        warned10 = true
        if db.warn10 and not ImmuneAt(endTime) then
            ShowMsg("ten", Txt("ten"))
        end
    end

    if remaining <= 10 and remaining > 0 and db.warnAway then
        AwayCheck(now, remaining)
    end

    if remaining <= 3 and remaining > 0 then
        local c = math.ceil(remaining)
        if c ~= lastCount then
            lastCount = c
            if db.warnCount and not ImmuneAt(endTime) then ShowMsg("tick", tostring(c)) end
        end
    end

    if remaining <= 0 then
        local vomitTime = endTime
        local immune = ImmuneAt(vomitTime)
        local wasTest = testing
        endTime = nil
        testing = false
        if not wasTest then
            Send(immune and "C" or "V")
            if not immune then lastVSent = GetTime() end
        end
        if db.warnVomit and not immune then ShowMsg("vomit", Txt("vomit")) end
    end
end

local function UpdateBar(now, elapsed)
    local want = false
    if endTime and db.showBar then
        want = true
        local remaining = math.max(0, endTime - now)
        bar:SetMinMaxValues(0, totalTime)
        bar:SetValue(remaining)
        if remaining > 20 then
            bar:SetStatusBarColor(0.25, 0.8, 0.25)
        elseif remaining > 10 then
            bar:SetStatusBarColor(1, 0.65, 0.1)
        else
            bar:SetStatusBarColor(0.9, 0.15, 0.15)
        end
        barText:SetText(Txt("barText", { s = math.ceil(remaining) }))
        spark:ClearAllPoints()
        spark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * (remaining / totalTime), 0)
        spark:Show()
        if db.animations and remaining <= 10 then
            glow:SetAlpha(0.28 * (0.5 + 0.5 * math.sin(now * 8)))
        else
            glow:SetAlpha(0)
        end
    elseif unlocked then
        want = true
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0.6)
        bar:SetStatusBarColor(0.25, 0.8, 0.25)
        barText:SetText(Txt("barText", { s = 42 }))
        spark:Hide()
        glow:SetAlpha(0)
    end

    local speed = db.animations and 4 or 1000
    if want then
        barAlpha = math.min(1, barAlpha + elapsed * speed)
        if not barFrame:IsShown() then barFrame:Show() end
    else
        barAlpha = math.max(0, barAlpha - elapsed * speed)
        if barAlpha <= 0 and barFrame:IsShown() then barFrame:Hide() end
    end
    barFrame:SetAlpha(barAlpha)
end

DAY_NIGHT.CycleTimeText = function(totalSec)
    totalSec = math.max(0, math.floor(totalSec + 0.5))
    local hours = math.floor(totalSec / 3600)
    local minutes = math.floor((totalSec % 3600) / 60)
    local seconds = totalSec % 60
    if hours > 0 then return string.format("%dh %02dm", hours, minutes) end
    return string.format("%02dm %02ds", minutes, seconds)
end

DAY_NIGHT.GetCycleGameMinutes = function(realNow)
    local hours, minutes = GetGameTime()
    if type(hours) ~= "number" or type(minutes) ~= "number" then return nil end
    local serverMinutes = (hours * 60 + minutes) % 1440
    local cycleLength = tonumber(db.dayNightCycleMinutes) or 120
    if cycleLength < 1 then cycleLength = 120 end
    local secondsPerGameMinute = cycleLength * 60 / 1440

    if not DAY_NIGHT.gameMinutes or DAY_NIGHT.lastSample == 0
       or math.abs(DAY_NIGHT.gameMinutes - serverMinutes) > 2 then
        DAY_NIGHT.gameMinutes = serverMinutes
    else
        DAY_NIGHT.gameMinutes = (DAY_NIGHT.gameMinutes + math.max(0, realNow - DAY_NIGHT.lastSample) / secondsPerGameMinute) % 1440
    end
    DAY_NIGHT.lastSample = realNow
    return DAY_NIGHT.gameMinutes, secondsPerGameMinute
end

DAY_NIGHT.GetCycleInfo = function(realNow)
    local gameMinutes, secondsPerGameMinute = DAY_NIGHT.GetCycleGameMinutes(realNow)
    if not gameMinutes then return nil end

    local sunrise = (tonumber(db.dayNightSunrise) or 360) % 1440
    local sunset = (tonumber(db.dayNightSunset) or 1200) % 1440
    local isDay, elapsed, phaseLength
    if sunrise <= gameMinutes and gameMinutes < sunset then
        isDay = true
        elapsed = gameMinutes - sunrise
        phaseLength = sunset - sunrise
    else
        isDay = false
        elapsed = gameMinutes >= sunset and (gameMinutes - sunset) or (gameMinutes + 1440 - sunset)
        phaseLength = 1440 - sunset + sunrise
    end

    if DAY_NIGHT.observedPhase and DAY_NIGHT.observedAt then
        local observedIsDay = DAY_NIGHT.observedPhase == "day"
        local observedElapsed = math.max(0, realNow - DAY_NIGHT.observedAt)
        local observedLength = (observedIsDay and (sunset - sunrise) or (1440 - sunset + sunrise))
            * secondsPerGameMinute
        if observedElapsed < observedLength then
            return observedIsDay, observedLength - observedElapsed, observedElapsed, observedLength, "server"
        else
            DAY_NIGHT.observedPhase, DAY_NIGHT.observedAt = nil, nil
        end
    end

    local remainingSeconds = math.max(0, (phaseLength - elapsed) * secondsPerGameMinute)
    return isDay, remainingSeconds, elapsed * secondsPerGameMinute, phaseLength * secondsPerGameMinute, "clock"
end

DAY_NIGHT.Update = function(realNow)
    if not db then return end
    local isDay, remainingSeconds = DAY_NIGHT.GetCycleInfo(realNow)
    if isDay == nil then return end
    if DAY_NIGHT.iconTexture then
        DAY_NIGHT.iconTexture:SetTexture(isDay and "Interface\\Icons\\Spell_Holy_SearingLight"
            or "Interface\\Icons\\INV_Misc_Moon_01")
    end

    if DAY_NIGHT.isDay ~= nil and DAY_NIGHT.isDay ~= isDay then
        if isDay then
            DAY_NIGHT.warningSent = false
        end
    end
    DAY_NIGHT.isDay = isDay

    if isDay and db.warnNight and not DAY_NIGHT.warningSent and remainingSeconds <= 300 then
        DAY_NIGHT.warningSent = true
        ShowMsg("night", Txt("nightSoon", { m = math.max(1, math.ceil(remainingSeconds / 60)) }))
    end
end

DAY_NIGHT.HandleMessage = function(message)
    if type(message) ~= "string" then return end
    local lower = string.lower(message)
    lower = string.gsub(lower, "í", "i")
    lower = string.gsub(lower, "Í", "i")
    local isNight = string.find(lower, "ha llegado la noche", 1, true)
        or string.find(lower, "llego la noche", 1, true)
        or string.find(lower, "empieza la noche", 1, true)
        or (string.find(lower, "noche", 1, true) and string.find(lower, "rabiar", 1, true)
            and string.find(lower, "loot", 1, true))
    local isDay = string.find(lower, "amanec", 1, true)
        or string.find(lower, "llego el dia", 1, true)
        or string.find(lower, "ha llegado el dia", 1, true)
        or string.find(lower, "empieza el dia", 1, true)
        or string.find(lower, "comienza el dia", 1, true)
        or string.find(lower, "dia ha llegado", 1, true)
        or (string.find(lower, "dia", 1, true) and string.find(lower, "dejan de rabiar", 1, true))
    if not isNight and not isDay then return end

    local now = GetTime()
    local phase = isNight and "night" or "day"
    DAY_NIGHT.observedPhase, DAY_NIGHT.observedAt = phase, now
    DAY_NIGHT.lastSample = 0 -- alinea también el cálculo del reloj al anuncio del servidor
    if isNight then
        DAY_NIGHT.gameMinutes = tonumber(db.dayNightSunset) or 1200
    else
        DAY_NIGHT.gameMinutes = tonumber(db.dayNightSunrise) or 360
        DAY_NIGHT.warningSent = false
    end
    DAY_NIGHT.isDay = isDay and true or false
end

---------------------------------------------------------------------
-- Contagio
---------------------------------------------------------------------
local function CheckNear()
    if not db.warnNear or unlocked then return end
    if HasPutrid("player") or ImmuneAt(GetTime()) then return end
    RefreshNameplateUnits()
    local now = GetTime()
    local seen = {}
    local range = db.wideRange and NEAR_INDEX or DANGER_INDEX
    local function CheckUnit(unit)
        if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsDeadOrGhost(unit)
           and HasPutrid(unit) and CheckInteractDistance(unit, range) then
            local name = UnitName(unit) or unit
            if not seen[name] then
                seen[name] = true
                if not nearCD[name] or now - nearCD[name] >= NEAR_COOLDOWN then
                    nearCD[name] = now
                    ShowMsg("contagion", Txt("near", { name = name }))
                end
            end
        end
    end
    for _, unit in ipairs(GroupUnits()) do CheckUnit(unit) end
    for unit in pairs(nameplateUnits) do CheckUnit(unit) end

    -- El combat log puede revelar Putrefacto en otros jugadores sin darnos un
    -- unitId. Solo usar esa señal si el usuario habilitó avisos sin distancia.
    if db.warnUnknown then
        for name, p in pairs(people) do
            if p.putrid and p.src == "log" and now - (p.seen or 0) <= RADAR_FRESH
               and not seen[name] and DistanceClass(name, p) == "unknown"
               and (not nearCD[name] or now - nearCD[name] >= NEAR_COOLDOWN) then
                nearCD[name] = now
                ShowMsg("contagion", Txt("near", { name = name }))
            end
        end
    end
end

local function HandleGroupAura(unit)
    local name = UnitName(unit)
    if not name then return end
    if HasPutrid(unit) then
        if not infected[name] then
            infected[name] = true
            if db.warnContagion and not HasPutrid("player") and not ImmuneAt(GetTime()) then
                nearCD[name] = GetTime()
                ShowMsg("contagion", Txt("groupInfect", { name = name }))
            end
        end
    else
        infected[name] = nil
    end
end

---------------------------------------------------------------------
-- Boton de minimapa
---------------------------------------------------------------------
local mm = CreateFrame("Button", "TuWoWQoLMinimapButton", Minimap)
mm:SetSize(31, 31)
mm:SetFrameStrata("MEDIUM")
mm:SetFrameLevel(8)
mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
if mm.SetPropagateMouseClicks then mm:SetPropagateMouseClicks(false) end
mm:RegisterForDrag("LeftButton")
mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local mmIcon = mm:CreateTexture(nil, "BACKGROUND")
mmIcon:SetSize(20, 20)
mmIcon:SetPoint("CENTER", 0, 1)
mmIcon:SetTexture(MINIMAP_ICON)
mmIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

-- Botón independiente para el ciclo: su tooltip no comparte el botón de configuración.
DAY_NIGHT.iconButton = CreateFrame("Button", "TuWoWQoLCycleButton", Minimap)
DAY_NIGHT.iconButton:SetSize(42, 42)
DAY_NIGHT.iconButton:SetFrameStrata("MEDIUM")
DAY_NIGHT.iconButton:SetFrameLevel(10)
DAY_NIGHT.iconTexture = DAY_NIGHT.iconButton:CreateTexture(nil, "BACKGROUND")
DAY_NIGHT.iconTexture:SetSize(33, 33)
DAY_NIGHT.iconTexture:SetPoint("CENTER")
DAY_NIGHT.iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Moon_01")

local mmBorder = mm:CreateTexture(nil, "OVERLAY")
mmBorder:SetSize(53, 53)
mmBorder:SetPoint("TOPLEFT")
mmBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

DAY_NIGHT.PlaceButton = function()
    local cycleButton = DAY_NIGHT.iconButton
    if not cycleButton then return end
    local reference = _G.ForeverUIMinimapDiel or DAY_NIGHT.button or _G.DayNightBarMinimapButton
    cycleButton:ClearAllPoints()
    if reference and reference.IsShown and reference:IsShown() then
        cycleButton:SetPoint("CENTER", reference, "CENTER", 0, 0)
        DAY_NIGHT.iconTexture:SetAlpha(0)
    else
        local angle = math.rad(45)
        cycleButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
        DAY_NIGHT.iconTexture:SetAlpha(1)
    end
end

local function PlaceMinimapButton()
    local angleDegrees = db.minimapAngle or 215
    local angle = math.rad(angleDegrees)
    mm:ClearAllPoints()
    mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
end

local function ApplyMinimap()
    if db.showMinimap then
        PlaceMinimapButton()
        DAY_NIGHT.PlaceButton()
        mm:Show()
        DAY_NIGHT.iconButton:Show()
    else
        mm:Hide()
        DAY_NIGHT.iconButton:Hide()
    end
end

local function MinimapDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale
    db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
    PlaceMinimapButton()
end

mm:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", MinimapDragUpdate) end)
mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
DAY_NIGHT.RefreshTooltip = function(force)
    if not GameTooltip then return end
    if force then
        if GameTooltip.SetOwner then GameTooltip:SetOwner(force, "ANCHOR_LEFT") end
    elseif not GameTooltip:IsShown()
       or not (GameTooltip:IsOwned(DAY_NIGHT.iconButton)
           or (DAY_NIGHT.button and GameTooltip:IsOwned(DAY_NIGHT.button))) then
        return
    end
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Ciclo del día", 1, 0.82, 0.2)
    local isDay, remainingSeconds, elapsedSeconds, phaseSeconds, source = DAY_NIGHT.GetCycleInfo(GetTime())
    if isDay == nil then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Estado", "No disponible", 0.1, 0.8, 1, 0.75, 0.75, 0.75)
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Fase", isDay and "Día" or "Noche",
            0.1, 0.8, 1, isDay and 0.85 or 0.75, isDay and 0.95 or 0.8, 1)
        GameTooltip:AddDoubleLine("Próxima fase",
            (isDay and "Noche en: " or "Día en: ") .. DAY_NIGHT.CycleTimeText(remainingSeconds),
            0.1, 0.8, 1, 1, 0.85, 0.25)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(isDay and "Estado nocturno" or "Efectos nocturnos", 1, 0.82, 0.2)
        GameTooltip:AddDoubleLine("Rabiar", isDay and "Inactivo" or "Activo",
            0.1, 0.8, 1, isDay and 0.75 or 1, isDay and 0.75 or 0.3, isDay and 0.75 or 0.2)
        if not isDay then
            GameTooltip:AddDoubleLine("Loot del mundo", "x2.0", 0.1, 0.8, 1, 1, 0.85, 0.25)
            GameTooltip:AddDoubleLine("Experiencia", "+10%", 0.1, 0.8, 1, 1, 0.85, 0.25)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Fuente", source == "server" and "Anuncio del servidor" or "Reloj del juego",
            0.1, 0.8, 1, 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

DAY_NIGHT.HookButton = function()
    local nativeCycle = _G.ForeverUIMinimapDiel
    if nativeCycle and DAY_NIGHT.reference ~= nativeCycle then
        DAY_NIGHT.reference = nativeCycle
        if nativeCycle.HookScript then
            nativeCycle:HookScript("OnShow", DAY_NIGHT.PlaceButton)
            nativeCycle:HookScript("OnHide", DAY_NIGHT.PlaceButton)
        end
        DAY_NIGHT.PlaceButton()
    end

    if DAY_NIGHT.button then return end
    local button = _G.DayNightBarMinimapButton
    if not button or not button.HookScript then return end
    DAY_NIGHT.button = button
    button:HookScript("OnEnter", function(self) DAY_NIGHT.RefreshTooltip(self) end)
    button:HookScript("OnDragStop", DAY_NIGHT.PlaceButton)
    button:HookScript("OnShow", DAY_NIGHT.PlaceButton)
    button:HookScript("OnHide", DAY_NIGHT.PlaceButton)
    DAY_NIGHT.PlaceButton()
end

mm:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddDoubleLine("TuWoW QoL", "v" .. VERSION,
        1, 0.82, 0.2, 0.65, 0.65, 0.65)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Clic izq.", "Opciones", 0.1, 0.8, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Clic der.", "Editar interfaz", 0.1, 0.8, 1, 1, 1, 1)
    GameTooltip:Show()
end)
mm:SetScript("OnLeave", function() GameTooltip:Hide() end)

DAY_NIGHT.iconButton:SetScript("OnEnter", function(self)
    DAY_NIGHT.RefreshTooltip(self)
end)
DAY_NIGHT.iconButton:SetScript("OnLeave", function(self)
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end)

---------------------------------------------------------------------
-- Configuracion (Interfaz > AddOns)
---------------------------------------------------------------------
local panel = CreateFrame("Frame", "TuWoWQoLOptions", UIParent)
panel.name = "TuWoW QoL"

local controls = {}
local refreshing = false
local snapshot
local unlockCB
local OpenEditor

local function ApplyAll()
    ApplyPos(f, db.msgPos)
    ApplyPos(barFrame, db.barPos)
    ApplyPos(radar, db.radarPos)
    ApplyScale()
    ApplyMinimap()
    ApplyLock()
end

local function Refresh()
    if not db then return end
    refreshing = true
    for _, c in ipairs(controls) do
        if c.kind == "check" then
            c.frame:SetChecked(db[c.key] and true or false)
        else
            c.frame:SetValue(db[c.key])
        end
    end
    if unlockCB then unlockCB:SetChecked(unlocked) end
    refreshing = false
end

local function Header(parent, str, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOP", parent, "TOP", 0, y)
    fs:SetText(str)
    local l1 = parent:CreateTexture(nil, "ARTWORK")
    l1:SetTexture(WHITE)
    l1:SetVertexColor(1, 0.82, 0, 0.4)
    l1:SetHeight(1)
    l1:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y - 7)
    l1:SetPoint("TOPRIGHT", fs, "TOPLEFT", -10, -7)
    local l2 = parent:CreateTexture(nil, "ARTWORK")
    l2:SetTexture(WHITE)
    l2:SetVertexColor(1, 0.82, 0, 0.4)
    l2:SetHeight(1)
    l2:SetPoint("TOPLEFT", fs, "TOPRIGHT", 10, -7)
    l2:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, y - 7)
end

local function ScrollOptionsByWheel(scroll, delta)
    local current = scroll:GetVerticalScroll()
    local limit = scroll:GetVerticalScrollRange()
    scroll:SetVerticalScroll(math.max(0, math.min(limit, current - delta * 18)))
end

local function Note(parent, str, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -22, y)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(str)
    return fs
end

local function Check(parent, key, label, y, onChange)
    local name = "TuWoWQoLCheck" .. key
    local cb = CreateFrame("CheckButton", name, parent, "OptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 18, y)
    local labelText = _G[name .. "Text"]
    labelText:SetText(label)
    labelText:SetJustifyH("LEFT")
    labelText:SetWordWrap(true)
    parent.labels = parent.labels or {}
    parent.labels[#parent.labels + 1] = labelText
    cb:EnableMouseWheel(true)
    cb:SetScript("OnMouseWheel", function(_, delta) ScrollOptionsByWheel(parent:GetParent(), delta) end)
    cb:SetScript("OnClick", function(self)
        if refreshing then return end
        db[key] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    controls[#controls + 1] = { kind = "check", key = key, frame = cb }
    return cb
end

local function Slider(parent, key, label, minV, maxV, step, y, fmt, onChange)
    local name = "TuWoWQoLSlider" .. key
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, y)
    s:SetWidth(280)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    _G[name .. "Low"]:SetText(string.format(fmt, minV))
    _G[name .. "High"]:SetText(string.format(fmt, maxV))
    s:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        _G[name .. "Text"]:SetText(label .. ": " .. string.format(fmt, value))
        if refreshing then return end
        db[key] = value
        if onChange then onChange() end
    end)
    controls[#controls + 1] = { kind = "slider", key = key, frame = s }
    return s
end

local function Button(parent, label, x, y, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 140, 24)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    b:SetText(label)
    b:SetScript("OnClick", onClick)
    if parent:GetParent() and parent:GetParent():GetObjectType() == "ScrollFrame" then
        local scroll = parent:GetParent()
        b:EnableMouseWheel(true)
        b:SetScript("OnMouseWheel", function(_, delta) ScrollOptionsByWheel(scroll, delta) end)
    end
    return b
end

local function ResetPositions()
    db.msgPos = DeepCopy(DEFAULTS.msgPos)
    db.barPos = DeepCopy(DEFAULTS.barPos)
    db.radarPos = DeepCopy(DEFAULTS.radarPos)
    ApplyPos(f, db.msgPos)
    ApplyPos(barFrame, db.barPos)
    ApplyPos(radar, db.radarPos)
end

local function BuildOptions()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("TuWoW QoL")
    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Mejoras de calidad de vida - módulo Putrefacto  (v" ..
        tostring(GetAddOnMetadata(ADDON, "Version") or "?") .. ")")

    local box = CreateFrame("Frame", nil, panel)
    box:SetPoint("TOPLEFT", 14, -86)
    box:SetPoint("BOTTOMRIGHT", -14, 14)
    box:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    box:SetBackdropColor(0, 0, 0, 0.55)
    box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    local pages, tabs = {}, {}
    local function NewPage()
        local pageIndex = #pages + 1
        -- ScrollFrame simple: la plantilla agregaba otra barra con flechas además
        -- del indicador propio que usamos para que el scroll se vea en 3.3.5.
        local scroll = CreateFrame("ScrollFrame", "TuWoWQoLOptionsScroll" .. pageIndex, box)
        scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -28, 8)
        scroll:EnableMouseWheel(true)

        local content = CreateFrame("Frame", nil, scroll)
        content:SetHeight(410)
        content.labels = {}
        scroll:SetScrollChild(content)
        scroll.content = content
        scroll:SetScript("OnMouseWheel", function(self, delta)
            ScrollOptionsByWheel(self, delta)
        end)
        scroll:SetScript("OnSizeChanged", function(self, width)
            local contentWidth = math.max(100, width - 28)
            self.content:SetWidth(contentWidth)
            for _, labelText in ipairs(self.content.labels) do
                labelText:SetWidth(math.max(80, contentWidth - 48))
            end
            if self.UpdateIndicator then self:UpdateIndicator(self:GetVerticalScroll()) end
        end)

        -- Algunos clientes 3.3.5 muestran solo las flechas de la plantilla.
        -- Este indicador propio deja visible la posición y el recorrido restante.
        local track = CreateFrame("Frame", nil, scroll)
        track:SetWidth(4)
        track:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -5, -18)
        track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -5, 18)
        local trackTex = track:CreateTexture(nil, "BACKGROUND")
        trackTex:SetAllPoints()
        trackTex:SetTexture(WHITE)
        trackTex:SetVertexColor(0.25, 0.25, 0.25, 0.9)
        local thumb = CreateFrame("Frame", nil, track)
        thumb:SetWidth(4)
        local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
        thumbTex:SetAllPoints()
        thumbTex:SetTexture(WHITE)
        thumbTex:SetVertexColor(1, 0.78, 0.1, 1)
        scroll.UpdateIndicator = function(self, offset)
            local range = self:GetVerticalScrollRange()
            local trackHeight = track:GetHeight()
            if range <= 0 or trackHeight <= 0 then
                thumb:Hide()
                return
            end
            local thumbHeight = math.max(24, trackHeight * self:GetHeight() / self.content:GetHeight())
            local travel = trackHeight - thumbHeight
            thumb:SetHeight(thumbHeight)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0, -travel * math.min(1, math.max(0, offset / range)))
            thumb:Show()
        end
        scroll:SetScript("OnVerticalScroll", function(self, offset) self:UpdateIndicator(offset) end)
        scroll:SetScript("OnShow", function(self) self:UpdateIndicator(self:GetVerticalScroll()) end)
        scroll:Hide()
        pages[#pages + 1] = scroll
        return content
    end

    local function SelectTab(i)
        for idx, p in ipairs(pages) do
            local t = tabs[idx]
            if idx == i then
                p:Show()
                p:SetVerticalScroll(0)
                if t.native then PanelTemplates_SelectTab(t) else t:LockHighlight() end
            else
                p:Hide()
                if t.native then PanelTemplates_DeselectTab(t) else t:UnlockHighlight() end
            end
        end
    end

    -- Pestañas reales (la misma plantilla que usan Questie y otros addons).
    -- Si la plantilla no existe en el cliente, se usan botones chicos como respaldo.
    local function NewTab(label, i)
        local ok, t = pcall(CreateFrame, "Button", "TuWoWQoLTab" .. i, panel, "OptionsFrameTabButtonTemplate")
        if ok and t then
            t.native = true
            t:SetText(label)
            local fs = t:GetFontString()
            t:SetWidth((fs and fs:GetStringWidth() or 60) + 34)
        else
            t = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
            t:SetSize(90, 24)
            t:SetText(label)
        end
        if i == 1 then
            t:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 6, t.native and -3 or 2)
        else
            t:SetPoint("LEFT", tabs[i - 1], "RIGHT", t.native and -4 or 4, 0)
        end
        t:SetScript("OnClick", function() SelectTab(i) end)
        tabs[i] = t
    end

    -- General
    local general = NewPage()
    NewTab("General", 1)
    Header(general, "Opciones generales", -14)
    Check(general, "sounds", "Activar sonidos", -40)
    Check(general, "animations", "Activar animaciones", -66)
    Check(general, "showMinimap", "Mostrar botón en el minimapa", -92, ApplyMinimap)
    Header(general, "Interfaz", -134)
    Button(general, "Editar interfaz", 20, -160, 160, function() OpenEditor() end)
    Button(general, "Restablecer posición", 200, -160, 170, ResetPositions)
    Note(general, "Mové el mensaje, la barra y el radar; cambiá tamaños, textos, colores, duración y sonido de cada aviso.", -190)
    Header(general, "Pruebas", -214)
    Button(general, "Probar aviso", 20, -240, 140, function() Trigger(15, true) end)
    Button(general, "Probar contagio", 170, -240, 140, function()
        ShowMsg("contagion", "¡Jugador está Putrefacto y cerca tuyo!")
    end)
    Note(general, "La prueba simula una cuenta regresiva de 15 segundos.", -272)

    -- Avisos
    local warns = NewPage()
    NewTab("Avisos", 2)
    Header(warns, "Cuenta regresiva", -14)
    Check(warns, "warnStart", "Aviso inicial (vomitarás en X segundos)", -40)
    Check(warns, "warn10", "Aviso a 10 segundos", -66)
    Check(warns, "warnCount", "Cuenta 3, 2, 1", -92)
    Check(warns, "warnVomit", "Mensaje ¡VOMITANDO!", -118)
    Header(warns, "Estado", -162)
    Check(warns, "warnApplied", "Avisar al recibir el debuff", -188)
    Check(warns, "eatFallback", "Respaldo: detectar comida y pociones por buffs", -224)
    Check(warns, "warnNight", "Avisar 5 minutos antes de la noche", -250)
    Note(warns, "La cuenta (60 s exactos) empieza cuando el servidor avisa que tu estómago putrefacto rechaza lo consumido. " ..
        "El respaldo solo sirve si ese mensaje no te llega. " ..
        "Si perdés el debuff durante la cuenta, se cancela. " ..
        "Con Estómago de hierro solo se avisa si la inmunidad se va a acabar antes de que vomites.", -288)

    -- Contagio
    local cont = NewPage()
    NewTab("Contagio", 3)
    Header(cont, "Alerta de contagio", -14)
    Note(cont, "Si vomitas sobre otros jugadores, ellos también vomitan. " ..
        "Estas alertas funcionan con integrantes de tu grupo o banda.", -40)
    Check(cont, "warnContagion", "Avisar si alguien del grupo recibe Putrefacto", -84)
    Check(cont, "warnNear", "Avisar si un jugador con Putrefacto está cerca", -110)
    Header(cont, "Jugadores cercanos", -146)
    Check(cont, "warnEat", "Avisar si un jugador cercano come con Putrefacto", -172)
    Check(cont, "warnImminent", "Avisar si un jugador cercano está por vomitar", -198)
    Check(cont, "warnTheirVomit", "Avisar si un jugador cercano vomita", -224)
    Check(cont, "warnAway", "Avisarme quién está cerca antes de vomitar", -250)
    Check(cont, "wideRange", "Radio amplio (~28 yd); apagado: ~10 yd", -276)
    Check(cont, "warnUnknown", "Avisar si no se puede medir la distancia", -302)
    Check(cont, "silentNameplates", "Detectar sin mostrar barras amistosas (el addon las oculta)", -334,
        function() SetSilentNameplateMode(db.silentNameplates) end)
    Note(cont, "El cliente solo expone unidades ajenas mediante grupo, objetivo, foco, cursor o nameplates. " ..
        "Este modo activa las placas amistosas para obtener sus unidades y las vuelve invisibles.", -366)

    -- Sincronía
    local sync = NewPage()
    NewTab("Sincronía", 4)
    Header(sync, "Sincronización con otros usuarios", -14)
    Note(sync, "Los jugadores que tengan este addon comparten su estado (Putrefacto, comió, va a vomitar, " ..
        "inmune) por tu grupo o banda, así cada uno sabe cuándo alejarse.", -40)
    Check(sync, "syncEnabled", "Compartir y recibir estado con otros usuarios del addon", -92)
    Check(sync, "syncNearby", "También con jugadores cercanos fuera del grupo (experimental)", -118)
    Slider(sync, "alertSeconds", "Avisar cuando falten (seg)", 5, 20, 1, -170, "%d")
    Header(sync, "Pruebas", -230)
    Button(sync, "Probar radar", 20, -256, 140, TestSync)
    Button(sync, "Ver usuarios", 170, -256, 140, ListUsers)
    Note(sync, "Los avisos por jugador cercano se activan en la pestaña Contagio. El radar se muestra desde Editar interfaz " ..
        "(la prueba lo necesita activado) y solo lista jugadores cercanos. La prueba crea 3 jugadores falsos durante unos 25 segundos.", -288)

    SelectTab(1)
end

---------------------------------------------------------------------
-- Editor de interfaz (modo edicion)
---------------------------------------------------------------------
local E = {}

local EDIT_ITEMS = {
    { key = "start", kind = "start", label = "Aviso inicial", hint = "{s} = segundos", vars = { s = 60 } },
    { key = "ten", kind = "ten", label = "Aviso a 10 segundos" },
    { kind = "tick", label = "Cuenta 3, 2, 1 (solo el número)" },
    { key = "vomit", kind = "vomit", label = "Vomitás (vos)" },
    { key = "applied", kind = "applied", label = "Recibís el debuff Putrefacto" },
    { key = "groupInfect", kind = "contagion", label = "Alguien del grupo recibe el debuff",
      hint = "{name} = jugador", vars = { name = "Jugador" } },
    { key = "near", kind = "contagion", label = "Jugador Putrefacto cerca tuyo",
      hint = "{name} = jugador", vars = { name = "Jugador" } },
    { key = "eat", kind = "eat", label = "Otro jugador comió",
      hint = "{name} = jugador, {s} = segundos, {est} = ~ si es estimado", vars = { name = "Jugador", s = 14, est = "" } },
    { key = "imminent", kind = "imminent", label = "Otro jugador está por vomitar",
      hint = "{name} = jugador, {s} = segundos", vars = { name = "Jugador", s = 8 } },
    { key = "theirVomit", kind = "theirVomit", label = "Otro jugador vomita",
      hint = "{name} = jugador", vars = { name = "Jugador" } },
    { key = "vomitedOn", kind = "theirVomit", label = "Alguien vomitó cerca tuyo",
      hint = "{name} = jugador", vars = { name = "Jugador" } },
    { key = "away", kind = "away", label = "Alejate (vos vas a vomitar)",
      hint = "{s} = segundos, {list} = jugadores cerca", vars = { s = 8, list = "Jugador1, Jugador2" } },
    { key = "nightSoon", kind = "night", label = "Aviso antes de la noche", hint = "{m} = minutos", vars = { m = 5 } },
    { key = "radarTitle", label = "Radar: título" },
    { key = "radarMe", label = "Radar: tu nombre" },
    { key = "stMyVomit", label = "Radar: vos vomitás en", hint = "{s} = segundos" },
    { key = "stVomitIn", label = "Radar: otro vomita en", hint = "{s} = segundos, {est} = ~ si es estimado" },
    { key = "stVomiting", label = "Radar: vomitando" },
    { key = "stPutrid", label = "Radar: Putrefacto" },
    { key = "stImmune", label = "Radar: Putrefacto e inmune" },
    { key = "radarEmpty", label = "Radar: sin jugadores (solo en el editor)" },
    { key = "barText", label = "Barra de tiempo", hint = "{s} = segundos" },
}

local function SetEdit(on)
    unlocked = on and true or false
    ApplyLock()
    if not unlocked then HideMsg() end
end

local function Ov(kind)
    db.style = db.style or {}
    local o = db.style[kind]
    if not o then o = {}; db.style[kind] = o end
    return o
end

function E.Preview(silent)
    local it = EDIT_ITEMS[E.cur or 1]
    if not it or not it.kind then return end
    local str = it.key and Txt(it.key, it.vars) or "3"
    ShowMsg(it.kind, str, silent)
end

function E.Select(i)
    local n = #EDIT_ITEMS
    if i < 1 then i = n elseif i > n then i = 1 end
    E.cur = i
    local it = EDIT_ITEMS[i]
    E.label:SetText(string.format("%d/%d  %s", i, n, it.label))
    E.hint:SetText(it.hint or "")
    if it.key then
        local cur = db.texts and db.texts[it.key]
        if not cur or cur == "" then cur = TEXTS[it.key] end
        E.edit:SetText(cur)
        E.edit:Show()
    else
        E.edit:Hide()
    end
    if it.kind then
        local st = MSG[it.kind]
        local ov = db.style and db.style[it.kind]
        local col = (ov and ov.color) or st.color
        E.size.silent = true; E.size:SetValue((ov and ov.size) or st.size); E.size.silent = false
        E.dur.silent = true; E.dur:SetValue((ov and ov.dur) or st.dur); E.dur.silent = false
        E.swatch:SetTexture(col[1], col[2], col[3])
        E.sound:SetChecked(not (ov and ov.mute))
        E.size:Show(); E.dur:Show(); E.sound:Show(); E.colorBtn:Show(); E.swatch:Show(); E.testBtn:Show()
        E.Preview(true)
    else
        E.size:Hide(); E.dur:Hide(); E.sound:Hide(); E.colorBtn:Hide(); E.swatch:Hide(); E.testBtn:Hide()
    end
end

local function EdSlider(ed, name, label, x, y, w, minV, maxV, step, fmt, onChange)
    local sl = CreateFrame("Slider", name, ed, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", ed, "TOPLEFT", x, y)
    sl:SetWidth(w)
    sl:SetMinMaxValues(minV, maxV)
    sl:SetValueStep(step)
    _G[name .. "Low"]:SetText(string.format(fmt, minV))
    _G[name .. "High"]:SetText(string.format(fmt, maxV))
    sl:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        _G[name .. "Text"]:SetText(label .. ": " .. string.format(fmt, value))
        if self.silent then return end
        onChange(value)
    end)
    return sl
end

local function PickColor()
    local it = EDIT_ITEMS[E.cur or 1]
    if not it or not it.kind then return end
    local ov = Ov(it.kind)
    local c = ov.color or MSG[it.kind].color
    local r0, g0, b0 = c[1], c[2], c[3]
    local function apply(r, g, b)
        ov.color = { r, g, b }
        E.swatch:SetTexture(r, g, b)
        E.Preview(true)
    end
    ColorPickerFrame:Hide()
    ColorPickerFrame:SetColorRGB(r0, g0, b0)
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = { r0, g0, b0 }
    ColorPickerFrame.func = function()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        apply(r, g, b)
    end
    ColorPickerFrame.cancelFunc = function() apply(r0, g0, b0) end
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ColorPickerFrame:Show()
end

local function CloseGameMenu()
    if not GameMenuFrame or not GameMenuFrame:IsShown() then return end
    if HideUIPanel then HideUIPanel(GameMenuFrame) end
    if GameMenuFrame:IsShown() then GameMenuFrame:Hide() end
end

local function BuildEditor()
    local ed = CreateFrame("Frame", "TuWoWQoLEditor", UIParent)
    E.frame = ed
    if GameMenuFrame and not E.gameMenuHooked then
        GameMenuFrame:HookScript("OnShow", function()
            if E.frame and E.frame:IsShown() then CloseGameMenu() end
        end)
        E.gameMenuHooked = true
    end
    ed:SetScript("OnUpdate", function()
        CloseGameMenu()
    end)
    ed:SetSize(420, 540)
    ed:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 40)
    ed:SetFrameStrata("FULLSCREEN_DIALOG")
    ed:SetMovable(true)
    ed:EnableMouse(true)
    ed:SetClampedToScreen(true)
    ed:RegisterForDrag("LeftButton")
    ed:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ed:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    ed:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    ed:SetBackdropColor(0, 0, 0, 0.92)
    ed:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    ed:Hide()
    tinsert(UISpecialFrames, "TuWoWQoLEditor")

    local title = ed:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", ed, "TOP", 0, -12)
    title:SetText("TuWoW QoL - Editar interfaz")
    Note(ed, "Arrastrá el mensaje, la barra y el radar para moverlos. Esta ventana también se mueve.", -34)
    local close = CreateFrame("Button", nil, ed, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -2, -2)

    Slider(ed, "msgScale", "Tamaño del aviso", 0.6, 1.6, 0.1, -72, "%.1f")
    Slider(ed, "barScale", "Tamaño de la barra", 0.6, 1.6, 0.1, -118, "%.1f", ApplyScale)
    Slider(ed, "radarScale", "Tamaño del radar", 0.6, 1.6, 0.1, -164, "%.1f", ApplyScale)
    Slider(ed, "radarRows", "Filas del radar", 1, 8, 1, -210, "%d")
    Check(ed, "showBar", "Mostrar barra de tiempo", -246)
    Check(ed, "showRadar", "Mostrar radar (solo jugadores cercanos)", -272)

    Header(ed, "Textos y estilo", -304)
    Button(ed, "<", 24, -326, 30, function() E.Select((E.cur or 1) - 1) end)
    Button(ed, ">", 366, -326, 30, function() E.Select((E.cur or 1) + 1) end)
    E.label = ed:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    E.label:SetPoint("TOP", ed, "TOP", 0, -331)
    E.label:SetWidth(300)

    local eb = CreateFrame("EditBox", "TuWoWQoLEditorText", ed, "InputBoxTemplate")
    E.edit = eb
    eb:SetSize(360, 20)
    eb:SetPoint("TOPLEFT", ed, "TOPLEFT", 36, -356)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(160)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local it = EDIT_ITEMS[E.cur or 1]
        if not it or not it.key then return end
        db.texts = db.texts or {}
        db.texts[it.key] = self:GetText()
        E.Preview(true)
    end)

    E.hint = ed:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    E.hint:SetPoint("TOPLEFT", ed, "TOPLEFT", 36, -382)
    E.hint:SetWidth(350)
    E.hint:SetJustifyH("LEFT")

    E.size = EdSlider(ed, "TuWoWQoLEdSize", "Tamaño de letra", 30, -420, 170, 14, 70, 1, "%d", function(v)
        local it = EDIT_ITEMS[E.cur or 1]
        if it and it.kind then Ov(it.kind).size = v; E.Preview(true) end
    end)
    E.dur = EdSlider(ed, "TuWoWQoLEdDur", "Duración (s)", 225, -420, 170, 1, 10, 0.5, "%.1f", function(v)
        local it = EDIT_ITEMS[E.cur or 1]
        if it and it.kind then Ov(it.kind).dur = v end
    end)

    local snd = CreateFrame("CheckButton", "TuWoWQoLEdSound", ed, "OptionsCheckButtonTemplate")
    E.sound = snd
    snd:SetPoint("TOPLEFT", ed, "TOPLEFT", 18, -450)
    _G["TuWoWQoLEdSoundText"]:SetText("Sonido")
    snd:SetScript("OnClick", function(self)
        local it = EDIT_ITEMS[E.cur or 1]
        if it and it.kind then Ov(it.kind).mute = not self:GetChecked() end
    end)
    E.colorBtn = Button(ed, "Color", 110, -452, 70, PickColor)
    E.swatch = ed:CreateTexture(nil, "ARTWORK")
    E.swatch:SetSize(16, 16)
    E.swatch:SetPoint("TOPLEFT", ed, "TOPLEFT", 186, -456)
    E.testBtn = Button(ed, "Probar", 215, -452, 80, function() E.Preview(false) end)
    Button(ed, "Restablecer", 300, -452, 100, function()
        local it = EDIT_ITEMS[E.cur or 1]
        if not it then return end
        if it.key and db.texts then db.texts[it.key] = nil end
        if it.kind and db.style then db.style[it.kind] = nil end
        E.Select(E.cur or 1)
    end)

    Button(ed, "Restablecer posiciones", 20, -498, 180, ResetPositions)
    Button(ed, "Listo", 310, -498, 90, function() ed:Hide() end)

    ed:SetScript("OnShow", function()
        SetEdit(true)
        Refresh()
        E.Select(E.cur or 1)
    end)
    ed:SetScript("OnHide", function()
        SetEdit(false)
    end)
end

OpenEditor = function()
    if not db then return end
    if not E.frame then BuildEditor() end
    if E.frame:IsShown() then
        E.frame:Hide()
        return
    end
    snapshot = nil -- lo hecho en el editor se guarda al instante
    CloseGameMenu()
    if InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
    E.frame:Show()
end

local function Snapshot()
    snapshot = DeepCopy(db)
end

panel.okay = function() snapshot = nil end
panel.cancel = function()
    if snapshot and db then
        for k in pairs(db) do db[k] = nil end
        for k, v in pairs(snapshot) do db[k] = DeepCopy(v) end
        snapshot = nil
        ApplyAll()
        Refresh()
    end
end
panel.default = function()
    if not db then return end
    for k in pairs(db) do db[k] = nil end
    CopyDefaults(DEFAULTS, db)
    ApplyAll()
    Refresh()
end
panel.refresh = Refresh
panel:SetScript("OnShow", function()
    if db and not snapshot then Snapshot() end
    Refresh()
end)

local function OpenConfig()
    if not db then return end
    if InterfaceOptionsFrame:IsShown() and panel:IsVisible() then
        InterfaceOptionsFrame:Hide()
        return
    end
    -- Se llama dos veces por un bug conocido de 3.3.5 al abrir categorias de addons
    InterfaceOptionsFrame_OpenToCategory(panel)
    InterfaceOptionsFrame_OpenToCategory(panel)
end

mm:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
        OpenEditor()
    else
        OpenConfig()
    end
end)

SLASH_TUWOWQOL1 = "/twqol"
SLASH_TUWOWQOL2 = "/tuwowqol"
SlashCmdList["TUWOWQOL"] = function(msg)
    local cmd = string.lower(string.match(msg or "", "^%s*(%S*)") or "")
    if cmd == "help" or cmd == "ayuda" then
        ShowHelp()
    elseif cmd == "status" or cmd == "estado" then
        ShowStatus()
    elseif cmd == "debug" then
        debugOn = not debugOn
        Say("debug " .. (debugOn and "activado: se muestran eventos de Putrefacto, comida y vómito de otros jugadores" or "desactivado"))
    elseif cmd == "radar" then
        if db then
            db.showRadar = not db.showRadar
            Say("radar " .. (db.showRadar and "activado" or "desactivado"))
        end
    elseif cmd == "lista" or cmd == "users" then
        ListUsers()
    elseif cmd == "test" then
        if db then TestSync() end
    elseif cmd == "editar" or cmd == "ui" or cmd == "editor" then
        OpenEditor()
    else
        OpenConfig()
    end
end

---------------------------------------------------------------------
-- Eventos y bucle principal
---------------------------------------------------------------------
local radarElapsed = 0

f:SetScript("OnUpdate", function(self, elapsed)
    if not db then return end
    local now = GetTime()
    if not DAY_NIGHT.reference then
        DAY_NIGHT.buttonCheckElapsed = DAY_NIGHT.buttonCheckElapsed + elapsed
        if DAY_NIGHT.buttonCheckElapsed >= 1 then
            DAY_NIGHT.buttonCheckElapsed = 0
            DAY_NIGHT.HookButton()
        end
    end
    UpdateCountdown(now)
    UpdateBanner(now)
    UpdateBar(now, elapsed)

    DAY_NIGHT.elapsed = DAY_NIGHT.elapsed + elapsed
    if DAY_NIGHT.elapsed >= 1 then
        DAY_NIGHT.elapsed = 0
        DAY_NIGHT.Update(now)
    end

    DAY_NIGHT.tooltipElapsed = DAY_NIGHT.tooltipElapsed + elapsed
    if DAY_NIGHT.tooltipElapsed >= 0.5 then
        DAY_NIGHT.tooltipElapsed = 0
        DAY_NIGHT.RefreshTooltip()
    end

    radarElapsed = radarElapsed + elapsed
    if radarElapsed >= 0.4 then
        radarElapsed = 0
        UpdateRadar(now)
    end

    nearElapsed = nearElapsed + elapsed
    if nearElapsed >= 1 then
        nearElapsed = 0
        CheckNear()
        RosterTick(now)
        SyncTick(now)
    end
end)

-- Mensaje del servidor al comer/beber/usar una pocion estando Putrefacto
-- ("Tu estómago putrefacto rechaza lo consumido... sientes fuertes náuseas."):
-- el vomito llega EAT_DELAY segundos despues.
local function OnEatMessage(msg, sender, event)
    if not msg or type(msg) ~= "string" then return end
    local lower = string.lower(msg)
    if not (string.find(lower, "rechaza", 1, true) and string.find(lower, "putrefacto", 1, true)) then return end
    -- un emote de otro jugador no cuenta (los mensajes del servidor llegan sin autor o con el mio)
    if (event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_TEXT_EMOTE")
       and sender and sender ~= "" and sender ~= UnitName("player") then
        return
    end
    if debugOn then Say("mensaje de comida (" .. tostring(event) .. "): " .. msg) end
    if not endTime then Trigger(EAT_DELAY) end
end

local function OnPlayerAura()
    local has = HasPutrid("player")

    if initialized then
        -- Compartir cambios de estado con otros usuarios del addon
        if has ~= hadDebuff then Send(has and "P:1" or "P:0") end
        local imm = GetImmunityExpiry()
        if (imm ~= nil) ~= (lastImm ~= nil) then Send("I:" .. ImmSecs(imm)) end
        lastImm = imm

        -- Mi propio vomito confirmado por el aturdimiento / ¡Vomitado! aplicado por mi
        local vomitedNow = SelfVomitAura()
        if vomitedNow and not selfVomited then ConfirmSelfVomit() end
        selfVomited = vomitedNow

        -- Alguien vomito cerca mio (me aplico el aturdimiento de vomito)
        local by = AuraVomitOnMe()
        if by then
            if by ~= vomitOnMeBy then
                vomitOnMeBy = by
                SetVomit(by, "aura")
                if db.warnTheirVomit then ShowMsg("theirVomit", Txt("vomitedOn", { name = by })) end
            end
        else
            vomitOnMeBy = nil
        end

        -- No avisa si Estomago de hierro cubriria un vomito de ahora en adelante
        if has and not hadDebuff and db.warnApplied and not ImmuneAt(GetTime() + db.delay) then
            ShowMsg("applied", Txt("applied"))
        end

        -- Se cancela si perdés el debuff
        if not has and endTime and not testing and (endTime - GetTime()) > 2 then
            CancelCountdown()
        end

        local eatingNow = IsEating()
        if eatingNow and not wasEating and has and db.eatFallback then
            Trigger()
        end
        wasEating = eatingNow
    end

    hadDebuff = has
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_FOCUS_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
-- El mensaje de comida puede llegar por varios canales segun el servidor
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("CHAT_MSG_EMOTE")
f:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
f:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
f:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
f:RegisterEvent("UI_INFO_MESSAGE")
f:RegisterEvent("UI_ERROR_MESSAGE")
-- Awesome WotLK expone tokens de unidad para placas visibles en el cliente TuWoW.
if C_NamePlate and C_NamePlate.GetNamePlates then
    pcall(f.RegisterEvent, f, "NAME_PLATE_UNIT_ADDED")
    pcall(f.RegisterEvent, f, "NAME_PLATE_UNIT_REMOVED")
end
f:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        TuWoWQoLDB = TuWoWQoLDB or {}
        TuWoWQoLDB.showDayNight = nil
        TuWoWQoLDB.dayNightPos = nil
        -- Migracion a la v0.5: el radar viene oculto y el vomito tarda 60 s exactos
        if next(TuWoWQoLDB) ~= nil then
            local v = TuWoWQoLDB.cfgVersion or 0
            if v < 2 then
                TuWoWQoLDB.showRadar = false
                TuWoWQoLDB.delay = 60
            end
            if v < 3 then TuWoWQoLDB.wideRange = false end -- contagio: ~10 yd
        end
        CopyDefaults(DEFAULTS, TuWoWQoLDB)
        db = TuWoWQoLDB
        SetSilentNameplateMode(db.silentNameplates)
        BuildOptions()
        InterfaceOptions_AddCategory(panel)
        InterfaceOptionsFrame:HookScript("OnShow", function() Snapshot() end)
        InterfaceOptionsFrame:HookScript("OnHide", function()
            snapshot = nil
            Refresh()
        end)
        ApplyAll()
        -- En 3.3.5 no hace falta registrar el prefijo; en clientes nuevos si.
        if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not db then return end
        if db.silentNameplates then SetSilentNameplateMode(true) end
        hadDebuff = HasPutrid("player")
        wasEating = IsEating()
        lastImm = GetImmunityExpiry()
        selfVomited = SelfVomitAura()
        initialized = true
        for unit in pairs(nameplateUnits) do HandleUnitAura(unit) end
        helloAt = GetTime() + 4

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if type(arg1) == "string" then
            nameplateUnits[arg1] = true
            HideFriendlyNameplate(arg1)
            if debugOn then
                local name = UnitName(arg1)
                if name then Say("nameplate detectado: " .. name .. (UnitIsPlayer(arg1) and " (jugador)" or " (no jugador)")) end
            end
            if db and initialized then HandleUnitAura(arg1) end
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local saved = hiddenNameplateFrames[arg1]
        if saved and saved.frame and saved.frame.SetAlpha then
            saved.frame:SetAlpha(saved.alpha or 1)
            hiddenNameplateFrames[arg1] = nil
        end
        if arg1 then nameplateUnits[arg1] = nil end

    elseif event == "PLAYER_LOGOUT" then
        if db and db.silentNameplates then RestoreSilentNameplates(true) end

    elseif not db or not initialized then
        return

    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            OnPlayerAura()
        elseif arg1 and (string.find(arg1, "^party%d$") or string.find(arg1, "^raid%d+$")) then
            HandleGroupAura(arg1)
            HandleUnitAura(arg1)
        elseif arg1 == "target" or arg1 == "focus"
           or (arg1 and string.find(arg1, "^nameplate%d+$")) then
            HandleUnitAura(arg1)
        end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- 3.3.5: timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName
        OnCombatLog(arg2, arg4, arg5, arg7, arg8, arg9, arg10)

    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(arg1, arg2, arg3, arg4)

    elseif string.sub(event, 1, 8) == "CHAT_MSG" or string.sub(event, 1, 10) == "UI_INFO_ME"
           or string.sub(event, 1, 10) == "UI_ERROR_M" then
        if event == "CHAT_MSG_SYSTEM" or event == "UI_INFO_MESSAGE" then DAY_NIGHT.HandleMessage(arg1) end
        OnEatMessage(arg1, arg2, event)

    elseif event == "PLAYER_TARGET_CHANGED" then
        HandleUnitAura("target")

    elseif event == "PLAYER_FOCUS_CHANGED" then
        HandleUnitAura("focus")

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        local now = GetTime()
        if now - lastMouse >= 0.3 then
            lastMouse = now
            HandleUnitAura("mouseover")
        end

    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        if db.syncEnabled and not helloAt then helloAt = GetTime() + 2 end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 ~= "player" or not arg2 then return end
        if db.eatFallback and HasPutrid("player") then
            local lower = string.lower(arg2)
            for _, p in ipairs(POTION_PATTERNS) do
                if string.find(lower, p, 1, true) then
                    Trigger()
                    break
                end
            end
        end
    end
end)
