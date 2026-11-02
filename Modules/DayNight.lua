-- Ciclo día/noche y su botón/tooltip de minimapa.
--
-- El servidor anuncia cada cambio de fase por chat. Ese anuncio es la referencia:
-- se guarda con la hora real (time()) en la configuración, así sobrevive a
-- relogueos y recargas de interfaz. A partir de ahí la fase se calcula con las
-- duraciones del día y de la noche, que el addon aprende al ver dos anuncios
-- seguidos (si todavía no las conoce usa 06:00-20:00 dentro del ciclo de 2 h).
-- El reloj del juego solo se usa si se comprueba que va acelerado.
TuWoWQoLDayNight = {}

local DN = TuWoWQoLDayNight
DN.state = {
    isDay = nil, warningSent = false, elapsed = 0, tooltipElapsed = 0,
    buttonCheckElapsed = 0, lastMsgPhase = nil, lastMsgAt = 0, handling = false,
    clock = { mins = nil, changedAt = nil, fast = 0, slow = 0, secPerMin = nil },
}

local MIN_PHASE, MAX_PHASE = 300, 14400 -- segundos: rango razonable para una fase

local function GetDB()
    return DN.getDB and DN.getDB()
end

local function Debug(text)
    if DN.isDebug and DN.isDebug() and DN.say then DN.say(text) end
end

function DN.Configure(getDB, showMessage, getText, say, isDebug)
    DN.getDB = getDB
    DN.showMessage = showMessage
    DN.getText = getText
    DN.say = say
    DN.isDebug = isDebug
    DN.InstallChatHook()
end

function DN.CycleTimeText(totalSec)
    totalSec = math.max(0, math.floor(totalSec + 0.5))
    local hours = math.floor(totalSec / 3600)
    local minutes = math.floor((totalSec % 3600) / 60)
    local seconds = totalSec % 60
    if hours > 0 then return string.format("%dh %02dm", hours, minutes) end
    return string.format("%02dm %02ds", minutes, seconds)
end

---------------------------------------------------------------------
-- Duraciones
---------------------------------------------------------------------
local function ValidLen(v)
    v = tonumber(v)
    if v and v >= MIN_PHASE and v <= MAX_PHASE then return v end
end

-- Devuelve segundos de día, segundos de noche y si fueron aprendidos del servidor.
function DN.GetLengths()
    local db = GetDB()
    local cycle = (tonumber(db and db.dayNightCycleMinutes) or 120) * 60
    if cycle < 2 * MIN_PHASE then cycle = 7200 end
    local sunrise = (tonumber(db and db.dayNightSunrise) or 360) % 1440
    local sunset = (tonumber(db and db.dayNightSunset) or 1200) % 1440
    local dayDefault = cycle * ((sunset - sunrise) % 1440) / 1440
    local nightDefault = cycle - dayDefault
    local dayLen = ValidLen(db and db.dayNightDayLen)
    local nightLen = ValidLen(db and db.dayNightNightLen)
    if dayLen and nightLen then return dayLen, nightLen, true end
    -- Con una sola fase conocida, la otra completa el ciclo de 2 horas.
    if dayLen then return dayLen, ValidLen(cycle - dayLen) or nightDefault, false end
    if nightLen then return ValidLen(cycle - nightLen) or dayDefault, nightLen, false end
    return dayDefault, nightDefault, false
end

local function LearnLength(phase, seconds)
    local db = GetDB()
    if not db or seconds < MIN_PHASE or seconds > MAX_PHASE then return end
    local key = phase == "day" and "dayNightDayLen" or "dayNightNightLen"
    local otherKey = phase == "day" and "dayNightNightLen" or "dayNightDayLen"
    -- El ciclo completo es fijo: dia + noche tiene que dar (casi) el total. Si no cierra, se
    -- perdieron anuncios (por ejemplo por estar desconectado) y el valor no sirve.
    local cycle = (tonumber(db.dayNightCycleMinutes) or 120) * 60
    local other = ValidLen(db[otherKey])
    if (other and math.abs(seconds + other - cycle) > cycle * 0.1)
       or (not other and seconds > cycle - MIN_PHASE) then
        Debug("ciclo: duración de " .. phase .. " descartada, no cierra con el ciclo (" .. math.floor(seconds) .. " s)")
        return
    end
    local old = ValidLen(db[key])
    -- Un valor muy distinto del conocido suele ser un anuncio perdido: se descarta.
    if old and (seconds < old * 0.65 or seconds > old * 1.35) then
        Debug("ciclo: duración de " .. phase .. " descartada (" .. math.floor(seconds) .. " s)")
        return
    end
    db[key] = math.floor(seconds + 0.5)
    Debug("ciclo: duración de " .. phase .. " = " .. db[key] .. " s")
end

---------------------------------------------------------------------
-- Reloj del juego (solo si va acelerado)
---------------------------------------------------------------------
function DN.SampleClock(realNow)
    if not GetGameTime then return end
    local hours, minutes = GetGameTime()
    if type(hours) ~= "number" or type(minutes) ~= "number" then return end
    local mins = (hours * 60 + minutes) % 1440
    local c = DN.state.clock
    if c.mins == nil then
        c.mins, c.changedAt = mins, realNow
        return
    end
    if mins == c.mins then return end
    local interval = realNow - c.changedAt
    local firstChange = c.firstChangeSeen
    c.firstChangeSeen = true
    -- El primer cambio mide un minuto parcial: se ignora.
    if firstChange and (mins - c.mins) % 1440 == 1 then
        if interval <= 20 then
            c.fast = c.fast + 1
            c.secPerMin = c.secPerMin and (c.secPerMin * 0.7 + interval * 0.3) or interval
        elseif interval >= 40 then
            c.slow = c.slow + 1
        end
    end
    c.mins, c.changedAt = mins, realNow
end

local function ClockInfo(realNow)
    local c = DN.state.clock
    if not (c.mins and c.secPerMin and c.fast >= 3 and c.fast > c.slow) then return nil end
    local db = GetDB()
    local sunrise = (tonumber(db.dayNightSunrise) or 360) % 1440
    local sunset = (tonumber(db.dayNightSunset) or 1200) % 1440
    local spm = c.secPerMin
    local gm = (c.mins + math.min(1, math.max(0, (realNow - c.changedAt) / spm))) % 1440
    local isDay, elapsed, phaseLength
    if sunrise <= gm and gm < sunset then
        isDay, elapsed, phaseLength = true, gm - sunrise, sunset - sunrise
    else
        isDay = false
        elapsed = gm >= sunset and (gm - sunset) or (gm + 1440 - sunset)
        phaseLength = 1440 - sunset + sunrise
    end
    return isDay, math.max(0, (phaseLength - elapsed) * spm), elapsed * spm, phaseLength * spm, "clock"
end

---------------------------------------------------------------------
-- Fase actual
---------------------------------------------------------------------
-- Devuelve: esDia, segundos restantes, segundos transcurridos, duración de la fase, fuente.
-- Fuente: "server" (dentro de la fase anunciada), "projected" (calculada desde el último
-- anuncio), "projectedGuess" (ídem pero con duraciones aún sin confirmar) o "clock".
function DN.GetCycleInfo()
    local db = GetDB()
    if not db then return nil end
    local anchor = db.dayNightAnchor
    if type(anchor) == "table" and (anchor.phase == "day" or anchor.phase == "night")
       and tonumber(anchor.at) then
        local dayLen, nightLen, learned = DN.GetLengths()
        local isDay = anchor.phase == "day"
        local t = math.max(0, time() - anchor.at)
        local len = isDay and dayLen or nightLen
        local source = "server"
        if t >= len then
            source = learned and "projected" or "projectedGuess"
            local otherLen = isDay and nightLen or dayLen
            t = (t - len) % (dayLen + nightLen)
            isDay = not isDay
            len = otherLen
            if t >= len then
                t = t - len
                isDay = not isDay
                len = isDay and dayLen or nightLen
            end
        elseif not learned then
            source = "serverGuess"
        end
        return isDay, math.max(0, len - t), t, len, source
    end
    return ClockInfo(GetTime())
end

function DN.Update()
    local db = GetDB()
    if not db then return end
    local isDay, remainingSeconds = DN.GetCycleInfo()
    if isDay == nil then return end
    if DN.iconTexture then
        DN.iconTexture:SetTexture(isDay and "Interface\\Icons\\Spell_Holy_SearingLight"
            or "Interface\\Icons\\INV_Misc_Moon_01")
    end
    local state = DN.state
    if not isDay then state.warningSent = false end
    state.isDay = isDay
    if isDay and db.warnNight and not state.warningSent and remainingSeconds <= 300 then
        state.warningSent = true
        if DN.showMessage and DN.getText then
            DN.showMessage("night", DN.getText("nightSoon", { m = math.max(1, math.ceil(remainingSeconds / 60)) }))
        end
    end
end

---------------------------------------------------------------------
-- Anuncios del servidor
---------------------------------------------------------------------
local ACCENTS = {
    ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u",
    ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u", ["Ü"] = "u",
}

local function Normalize(message)
    local s = string.gsub(message, "|c%x%x%x%x%x%x%x%x", "")
    s = string.gsub(s, "|r", "")
    s = string.gsub(s, "|H.-|h(.-)|h", "%1")
    s = string.lower(s)
    for accented, plain in pairs(ACCENTS) do s = string.gsub(s, accented, plain) end
    return s
end

local DAY_PHRASES = {
    "ha llegado el dia", "llego el dia", "el dia ha llegado", "empieza el dia",
    "comienza el dia", "amanece", "dejan de rabiar", "rates normales",
}
local NIGHT_PHRASES = {
    "ha llegado la noche", "llego la noche", "la noche ha llegado", "empieza la noche",
    "comienza la noche", "anochece",
}

local function FirstPosition(text, phrases)
    local best
    for _, phrase in ipairs(phrases) do
        local pos = string.find(text, phrase, 1, true)
        if pos and (not best or pos < best) then best = pos end
    end
    return best
end

-- strict: el mensaje viene de un hook genérico del chat (sin saber el canal), así que
-- se exige además la mención de "rabiar" que llevan ambos anuncios del servidor.
function DN.HandleMessage(message, event, sender, strict)
    if type(message) ~= "string" or message == "" then return end
    local state = DN.state
    if state.handling then return end
    if strict and not string.find(message, "[Rr]abi") then return end
    state.handling = true
    local ok, err = pcall(DN.ProcessMessage, message, event, sender, strict)
    state.handling = false
    if not ok then Debug("ciclo: error " .. tostring(err)) end
end

function DN.ProcessMessage(message, event, sender, strict)
    local db = GetDB()
    if not db then return end
    local text = Normalize(message)
    local dayPos = FirstPosition(text, DAY_PHRASES)
    local nightPos = FirstPosition(text, NIGHT_PHRASES)
    if not nightPos and string.find(text, "noche", 1, true) and string.find(text, "rabi", 1, true)
       and string.find(text, "loot", 1, true) and not dayPos then
        nightPos = string.find(text, "noche", 1, true)
    end
    if not dayPos and not nightPos then return end
    local phase
    if dayPos and nightPos then
        phase = dayPos < nightPos and "day" or "night"
    else
        phase = dayPos and "day" or "night"
    end

    local nowT = time()
    local state = DN.state
    -- El mismo anuncio llega por el evento y por el hook del chat (y por cada ventana).
    if state.lastMsgPhase == phase and nowT - state.lastMsgAt < 20 then return end
    state.lastMsgPhase, state.lastMsgAt = phase, nowT

    local prev = db.dayNightAnchor
    if type(prev) == "table" and prev.phase and prev.phase ~= phase and tonumber(prev.at) then
        LearnLength(prev.phase, nowT - prev.at)
    end
    db.dayNightAnchor = { phase = phase, at = nowT }
    state.warningSent = false
    Debug("ciclo: anuncio de " .. phase .. " (" .. tostring(event) .. (strict and ", hook" or "") .. ")")
    DN.Update()
    if db.warnPhase ~= false and DN.showMessage and DN.getText then
        local kind = phase == "night" and "nightStart" or "dayStart"
        DN.showMessage(kind, DN.getText(kind))
    end
end

-- Calibracion manual: la fase empezo hace `minutes` minutos (0 = recien empezo).
function DN.Calibrate(phase, minutes)
    local db = GetDB()
    if not db or (phase ~= "day" and phase ~= "night") then return false end
    local m = tonumber(minutes) or 0
    db.dayNightAnchor = { phase = phase, at = time() - math.max(0, m) * 60 }
    DN.state.warningSent = false
    DN.state.lastMsgPhase = nil
    DN.Update()
    return true
end

-- Olvida el ancla y las duraciones aprendidas (se vuelve a sincronizar con el proximo anuncio).
function DN.Reset()
    local db = GetDB()
    if not db then return end
    db.dayNightAnchor, db.dayNightDayLen, db.dayNightNightLen = nil, nil, nil
    DN.state.warningSent = false
    DN.state.lastMsgPhase = nil
end

-- Respaldo: algunos anuncios del servidor no llegan por un evento de chat conocido
-- pero sí terminan escritos en una ventana de chat.
function DN.InstallChatHook()
    if DN.hooked or not hooksecurefunc then return end
    DN.hooked = true
    -- El combat log dispara el hook por cada linea y no recibe anuncios del servidor
    local combatLog = _G.COMBATLOG or _G.ChatFrame2
    for i = 1, (NUM_CHAT_WINDOWS or 7) do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.AddMessage and frame ~= combatLog then
            hooksecurefunc(frame, "AddMessage", function(_, message)
                -- Un mensaje de jugador lleva el enlace |Hplayer: ; esos nunca valen (se podrian falsear)
                if type(message) == "string" and not string.find(message, "|Hplayer:", 1, true)
                   and string.find(message, "[Rr]abi") then
                    DN.HandleMessage(message, "ChatFrame", nil, true)
                end
            end)
        end
    end
end

-- Con un icono nativo (ForeverUI / DayNightBar) el tooltip se engancha a ese icono y el boton
-- propio no se muestra, asi no le tapa los clics. Solo si el icono nativo no recibe el mouse se
-- deja un boton invisible encima para poder mostrar el tooltip.
function DN.PlaceButton()
    local cycleButton = DN.iconButton
    if not cycleButton then return end
    if DN.visible == false then
        cycleButton:Hide()
        return
    end
    local reference = _G.ForeverUIMinimapDiel or DN.button or _G.DayNightBarMinimapButton
    cycleButton:ClearAllPoints()
    if reference and reference.IsShown and reference:IsShown() then
        DN.iconTexture:SetAlpha(0)
        if reference.IsMouseEnabled and reference:IsMouseEnabled() then
            cycleButton:Hide()
        else
            cycleButton:SetPoint("CENTER", reference, "CENTER", 0, 0)
            cycleButton:Show()
        end
    else
        local angle = math.rad(45)
        cycleButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * 80, math.sin(angle) * 80)
        DN.iconTexture:SetAlpha(1)
        cycleButton:Show()
    end
end

local SOURCE_TEXT = {
    server = "Anuncio del servidor",
    serverGuess = "Anuncio del servidor",
    projected = "Estimado desde el último anuncio",
    projectedGuess = "Estimado desde el último anuncio",
    clock = "Reloj del juego",
}

function DN.RefreshTooltip(force)
    if not GameTooltip then return end
    if force then
        if GameTooltip.SetOwner then GameTooltip:SetOwner(force, "ANCHOR_LEFT") end
    elseif not GameTooltip:IsShown()
       or not (GameTooltip:IsOwned(DN.iconButton) or (DN.button and GameTooltip:IsOwned(DN.button))
               or (DN.reference and GameTooltip:IsOwned(DN.reference))) then
        return
    end
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Ciclo del día", 1, 0.82, 0.2)
    local isDay, remainingSeconds, elapsedSeconds, phaseSeconds, source = DN.GetCycleInfo()
    if isDay == nil then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Estado", "No disponible", 0.1, 0.8, 1, 0.75, 0.75, 0.75)
        GameTooltip:AddLine("Se sincroniza con el próximo anuncio del servidor.", 0.7, 0.7, 0.7, true)
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Fase", isDay and "Día" or "Noche",
            0.1, 0.8, 1, isDay and 0.85 or 0.75, isDay and 0.95 or 0.8, 1)
        GameTooltip:AddDoubleLine("Próxima fase",
            (isDay and "Noche en: " or "Día en: ") .. DN.CycleTimeText(remainingSeconds),
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
        local sourceText = SOURCE_TEXT[source] or "Reloj del juego"
        GameTooltip:AddDoubleLine("Fuente", sourceText, 0.1, 0.8, 1, 0.7, 0.7, 0.7)
        if source == "serverGuess" or source == "projectedGuess" then
            GameTooltip:AddLine("La duración exacta se confirma al ver un día y una noche.", 0.6, 0.6, 0.6, true)
        end
    end
    GameTooltip:Show()
end

function DN.Describe()
    local isDay, remaining, _, phaseSeconds, source = DN.GetCycleInfo()
    if isDay == nil then
        return "sin datos todavía; se sincroniza con el próximo anuncio del servidor. " ..
            "Podés calibrar con /twqol ciclo dia|noche [minutos transcurridos]."
    end
    local dayLen, nightLen, learned = DN.GetLengths()
    return string.format("%s, %s en %s (fuente: %s). Día %s / noche %s%s.",
        isDay and "día" or "noche", isDay and "noche" or "día", DN.CycleTimeText(remaining),
        string.lower(SOURCE_TEXT[source] or "reloj del juego"),
        DN.CycleTimeText(dayLen), DN.CycleTimeText(nightLen), learned and "" or " (estimado)")
end

function DN.HookButton()
    local nativeCycle = _G.ForeverUIMinimapDiel
    if nativeCycle and DN.reference ~= nativeCycle then
        DN.reference = nativeCycle
        if nativeCycle.HookScript then
            nativeCycle:HookScript("OnShow", DN.PlaceButton)
            nativeCycle:HookScript("OnHide", DN.PlaceButton)
            nativeCycle:HookScript("OnEnter", function(self) DN.RefreshTooltip(self) end)
            nativeCycle:HookScript("OnLeave", function(self)
                if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            end)
        end
        DN.PlaceButton()
    end
    if DN.button then return end
    local button = _G.DayNightBarMinimapButton
    if not button or not button.HookScript then return end
    DN.button = button
    button:HookScript("OnEnter", function(self) DN.RefreshTooltip(self) end)
    button:HookScript("OnDragStop", DN.PlaceButton)
    button:HookScript("OnShow", DN.PlaceButton)
    button:HookScript("OnHide", DN.PlaceButton)
    DN.PlaceButton()
end

DN.iconButton = CreateFrame("Button", "TuWoWQoLCycleButton", Minimap)
DN.iconButton:SetSize(42, 42)
DN.iconButton:SetFrameStrata("MEDIUM")
DN.iconButton:SetFrameLevel(10)
DN.iconTexture = DN.iconButton:CreateTexture(nil, "BACKGROUND")
DN.iconTexture:SetSize(33, 33)
DN.iconTexture:SetPoint("CENTER")
DN.iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Moon_01")
DN.iconButton:SetScript("OnEnter", function(self) DN.RefreshTooltip(self) end)
DN.iconButton:SetScript("OnLeave", function(self)
    if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end)

function DN.SetVisible(visible)
    DN.visible = visible and true or false
    DN.PlaceButton()
end

function DN.Tick(now, elapsed)
    local state = DN.state
    state.buttonCheckElapsed = state.buttonCheckElapsed + elapsed
    if not DN.reference and state.buttonCheckElapsed >= 1 then
        state.buttonCheckElapsed = 0
        DN.HookButton()
    end
    state.placeElapsed = (state.placeElapsed or 0) + elapsed
    if state.placeElapsed >= 3 then
        state.placeElapsed = 0
        DN.PlaceButton() -- el icono nativo puede mostrarse u ocultarse sin avisar
    end
    state.elapsed = state.elapsed + elapsed
    if state.elapsed >= 1 then
        state.elapsed = 0
        DN.SampleClock(now)
        DN.Update()
    end
    state.tooltipElapsed = state.tooltipElapsed + elapsed
    if state.tooltipElapsed >= 0.5 then
        state.tooltipElapsed = 0
        DN.RefreshTooltip()
    end
end
