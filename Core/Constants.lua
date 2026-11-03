-- Constantes, textos, valores por defecto y estado compartido
local _, NS = ...

NS.FONT = "Fonts\\FRIZQT__.TTF"
NS.WHITE = "Interface\\Buttons\\WHITE8X8"

-- spellId del debuff Putrefacto
NS.DEBUFF_ID = 900112
-- Estomago de hierro: evita el vomito mientras dure. Si se acaba antes de que
-- llegue el vomito, vomitas igual.
NS.IMMUNITY_ID = 50056
NS.IMMUNITY_MARGIN = 1 -- seg de margen: la inmunidad debe cubrir el vomito con 1s de sobra

NS.ICON_DEBUFF = "Interface\\Icons\\Spell_Shadow_CorpseExplode"
local ICON_SKULL = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"

-- Buffs que aparecen al comer/beber
NS.FOOD_BUFFS = {
    ["Comida"] = true, ["Bebida"] = true, ["Comer"] = true, ["Beber"] = true,
    ["Food"] = true, ["Drink"] = true, ["Refreshment"] = true,
}
-- Fragmentos (en minuscula) de hechizos de pociones/frascos usados
NS.POTION_PATTERNS = { "poci", "frasco", "potion", "flask", "elixir" }

-- Estilo de cada mensaje: color, icono, duracion (seg), sonido, prioridad,
-- tamaño de letra y animaciones. Los sonidos son nombres de sonido de 3.3.5.
NS.MSG = {
    start     = { color = { 1.00, 0.82, 0.25 }, icon = NS.ICON_DEBUFF, dur = 4, sound = "AlarmClockWarning1",
                  prio = 2, size = 30, anim = "pop" },
    ten       = { color = { 1.00, 0.60, 0.10 }, icon = NS.ICON_DEBUFF, dur = 4, sound = "RaidWarning",
                  prio = 2, size = 30, anim = "pop", pulse = true },
    tick      = { color = { 1.00, 0.25, 0.25 }, icon = nil, dur = 1, sound = "MapPing",
                  prio = 3, size = 56, anim = "punch", fade = 0.15 },
    vomit     = { color = { 1.00, 0.10, 0.10 }, icon = NS.ICON_DEBUFF, dur = 4, sound = "igQuestFailed",
                  prio = 3, size = 38, anim = "pop", pulse = true, shake = true },
    applied   = { color = { 0.65, 1.00, 0.25 }, icon = NS.ICON_DEBUFF, dur = 4, sound = "AlarmClockWarning2",
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
    away      = { color = { 1.00, 0.30, 0.30 }, icon = NS.ICON_DEBUFF, dur = 3, sound = "AlarmClockWarning3",
                  prio = 3, size = 26, anim = "pop", pulse = true },
    -- Cambio de fase del ciclo dia/noche (anuncio del servidor)
    nightStart = { color = { 1.00, 0.48, 0.12 }, icon = ICON_SKULL, dur = 6, sound = "RaidWarning",
                   prio = 2, size = 26, anim = "pop", pulse = true },
    dayStart  = { color = { 1.00, 0.85, 0.30 }, icon = "Interface\\Icons\\Spell_Holy_SearingLight", dur = 5,
                  sound = "AlarmClockWarning2", prio = 1, size = 24, anim = "pop" },
}

NS.NEAR_COOLDOWN = 20 -- seg entre alertas de cercania por jugador
NS.MINIMAP_ICON = ICON_SKULL

NS.DEFAULTS = {
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
    warnPhase = true,     -- banner al empezar la noche / el dia (anuncio del servidor)
    autoSay = false,      -- avisar por /decir "alejense" antes de vomitar (para quien no tiene el addon)
    radarAlways = false,  -- mostrar el radar aunque no haya nadie para listar
    learnedSpells = {},   -- spellIds de vomito aprendidos por nombre (ver /twqol ids)
    dayNightCycleMinutes = 240, -- ciclo real: 2 h de día + 2 h de noche
    dayNightSunrise = 360, -- 06:00 hora del juego
    dayNightSunset = 1080, -- 18:00 hora del juego (12 h de día y 12 h de noche)
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
    cfgVersion = 4,
    showMinimap = true,
    minimapAngle = 215,
    msgScale = 1,
    barScale = 1,
    msgPos = { point = "TOP", relPoint = "TOP", x = 0, y = -180 },
    barPos = { point = "TOP", relPoint = "TOP", x = 0, y = -250 },
    radarPos = { point = "LEFT", relPoint = "LEFT", x = 30, y = 0 },
}

NS.db = nil
NS.unlocked = false -- true = modo "Editar interfaz"
NS.initialized = false

-- Segundos exactos entre comer estando Putrefacto y vomitar (confirmado en el servidor)
NS.EAT_DELAY = 60
-- Jugadores con distancia desconocida se muestran en el radar solo si hubo señales recientes
NS.RADAR_FRESH = 8

-- Textos editables. Marcadores: {name} {s} {est} {list}
NS.TEXTS = {
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
    nightStart = "¡Cae la noche! Rabiar activo, loot x2 y +10% de experiencia",
    dayStart = "Amanece: Rabiar inactivo",
    sayAway = "¡Voy a vomitar en {s}s! ¡Aléjense!",
}

function NS.Txt(key, vars)
    local str = NS.db and NS.db.texts and NS.db.texts[key]
    if not str or str == "" then str = NS.TEXTS[key] or key end
    str = string.gsub(str, "{(%w+)}", function(k)
        local v = vars and vars[k]
        if v == nil then return "{" .. k .. "}" end
        return tostring(v)
    end)
    return str
end

-- Cuenta regresiva
NS.endTime, NS.totalTime = nil, 60
NS.warned10, NS.lastCount = false, nil
NS.testing = false
NS.hadDebuff, NS.wasEating = false, false
NS.lastBarSec = nil
NS.saidAway, NS.lastSay = false, -math.huge -- aviso por /decir (autoSay)
-- Ultima vez que se vio el debuff en mi: evita repetir "Estas Putrefacto" cuando el servidor
-- lo quita y lo vuelve a poner (refresco) sin que realmente haya pasado a estar sano.
NS.lastPutridSeen = -math.huge
NS.APPLIED_REARM = 45

-- Mensaje activo
NS.msgUntil, NS.msgStart, NS.curPriority, NS.curStyle = 0, 0, 0, NS.MSG.start

-- Contagio
NS.infected, NS.nearCD, NS.nearElapsed = {}, {}, 0

-- Otros jugadores (ver seccion "Otros jugadores") y usuarios del addon detectados
NS.people, NS.addonUsers = {}, {}
-- Unidades expuestas por los nameplates de Awesome WotLK (TuWoW).
NS.nameplateUnits = {}
NS.hiddenNameplateFrames = {}
NS.radar = nil

function NS.DeepCopy(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do out[k] = NS.DeepCopy(v) end
    return out
end

function NS.CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            NS.CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end
