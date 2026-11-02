local _, NS = ...

---------------------------------------------------------------------
-- Pruebas y utilidades
---------------------------------------------------------------------
function NS.TestSync()
    local now = GetTime()
    local function fake(name, rem, est, immune)
        local p = NS.Person(name, "test")
        p.test, p.testUntil, p.addon = true, now + 24, true
        p.putrid, p.est, p.immune, p.warnedImminent = true, est, immune or false, nil
        p.vomitAt = rem and (now + rem) or nil
        p.vomitUntil = nil
    end
    fake("Jugador1", 14, false)
    fake("Jugador2", 40, true)
    fake("Jugador3", nil, false, true)
    if NS.db.warnEat then NS.ShowMsg("eat", NS.Txt("eat", { name = "Jugador1", s = 14, est = "" })) end
end

function NS.ListUsers()
    local names = {}
    for name, au in pairs(NS.addonUsers) do names[#names + 1] = name .. " (v" .. tostring(au.ver or "?") .. ")" end
    table.sort(names)
    if #names == 0 then
        NS.Say("Todavía no detecté usuarios del addon. Se detectan al entrar a un grupo o al coincidir cerca (si Sincronía cercana está activa).")
    else
        NS.Say("Usuarios con el addon: " .. table.concat(names, ", "))
    end
end

function NS.ShowStatus()
    if not NS.db then
        NS.Say("La configuración todavía no está lista.")
        return
    end

    local now = GetTime()
    local condition
    if NS.hadDebuff then
        condition = "Putrefacto"
    else
        condition = "sin Putrefacto"
    end

    if NS.endTime and not NS.testing then
        condition = condition .. "; vómito en " .. math.max(0, math.ceil(NS.endTime - now)) .. " s"
    elseif NS.testing then
        condition = condition .. "; cuenta regresiva de prueba activa"
    end

    local immune = NS.GetImmunityExpiry()
    if immune then
        local remaining = immune == math.huge and "indefinida" or (math.max(0, math.ceil(immune - now)) .. " s")
        condition = condition .. "; Estómago de hierro: " .. remaining
    else
        condition = condition .. "; sin inmunidad detectada"
    end
    NS.Say("Estado: " .. condition .. ".")
    NS.Say("Ciclo: " .. TuWoWQoLDayNight.Describe())

    local peers = {}
    for name, au in pairs(NS.addonUsers) do
        if now - (au.seen or 0) <= 3600 then
            peers[#peers + 1] = name .. " (v" .. tostring(au.ver or "?") .. ")"
        end
    end
    table.sort(peers)
    local groupSize = (GetNumRaidMembers() or 0) + (GetNumRaidMembers() == 0 and (GetNumPartyMembers() or 0) or 0)
    local syncMode = NS.db.syncEnabled and (groupSize > 0 and "grupo/banda" or "sin grupo") or "desactivada"
    if NS.db.syncEnabled and NS.db.syncNearby then syncMode = syncMode .. " + /decir" end
    NS.Say("Sincronización: " .. syncMode .. ". Usuarios detectados: " .. #peers .. ".")
    if #peers > 0 then
        local shown = {}
        for i = 1, math.min(5, #peers) do shown[i] = peers[i] end
        local suffix = #peers > 5 and (" y " .. (#peers - 5) .. " más") or ""
        NS.Say("Usuarios: " .. table.concat(shown, ", ") .. suffix .. ".")
    end
end

-- /twqol ciclo            -> muestra la fase actual
-- /twqol ciclo dia|noche [minutos]  -> calibra a mano (la fase empezo hace N minutos)
-- /twqol ciclo reset      -> olvida el ancla y las duraciones aprendidas
function NS.CycleCommand(arg, extra)
    local DN = TuWoWQoLDayNight
    arg = string.lower(arg or "")
    arg = string.gsub(arg, "í", "i")
    if arg == "" then
        NS.Say("Ciclo: " .. DN.Describe())
    elseif arg == "dia" or arg == "day" then
        DN.Calibrate("day", extra)
        NS.Say("Ciclo calibrado: " .. DN.Describe())
    elseif arg == "noche" or arg == "night" then
        DN.Calibrate("night", extra)
        NS.Say("Ciclo calibrado: " .. DN.Describe())
    elseif arg == "reset" then
        DN.Reset()
        NS.Say("Ciclo reiniciado. Se vuelve a sincronizar con el próximo anuncio del servidor.")
    else
        NS.Say("Uso: /twqol ciclo [dia|noche [minutos transcurridos] | reset]")
    end
end

function NS.ShowHelp()
    NS.Say("Comandos: /twqol o /tuwowqol (opciones), status, debug, radar, lista, test, editar, " ..
        "ciclo [dia|noche [min] | reset], ids.")
end
