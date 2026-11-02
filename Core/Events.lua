local ADDON, NS = ...

---------------------------------------------------------------------
-- Eventos y bucle principal
---------------------------------------------------------------------
local radarElapsed = 0

-- Eventos por los que el servidor puede anunciar el cambio de día/noche. Los de jugadores
-- (decir, gritar, canales) no se escuchan para que nadie pueda falsear el ciclo.
local DAYNIGHT_EVENTS = {
    CHAT_MSG_SYSTEM = true, UI_INFO_MESSAGE = true, CHAT_MSG_RAID_WARNING = true,
    CHAT_MSG_MONSTER_YELL = true, CHAT_MSG_MONSTER_EMOTE = true, CHAT_MSG_RAID_BOSS_EMOTE = true,
}

NS.f:SetScript("OnUpdate", function(self, elapsed)
    if not NS.db then return end
    local now = GetTime()
    NS.UpdateCountdown(now)
    NS.UpdateBanner(now)
    NS.UpdateBar(now, elapsed)
    TuWoWQoLDayNight.Tick(now, elapsed)

    radarElapsed = radarElapsed + elapsed
    if radarElapsed >= 0.4 then
        radarElapsed = 0
        NS.UpdateRadar(now)
    end

    NS.nearElapsed = NS.nearElapsed + elapsed
    if NS.nearElapsed >= 1 then
        NS.nearElapsed = 0
        -- El debuff se perdio de verdad (no fue un refresco): cancela la cuenta
        if NS.endTime and not NS.testing and (NS.endTime - now) > 2 and not NS.HasPutrid("player")
           and now - NS.lastPutridSeen > 3 then
            NS.CancelCountdown()
        end
        NS.CheckNear()
        NS.RosterTick(now)
        NS.SyncTick(now)
    end
end)

-- Mensaje del servidor al comer/beber/usar una pocion estando Putrefacto
-- ("Tu estómago putrefacto rechaza lo consumido... sientes fuertes náuseas."):
-- el vomito llega EAT_DELAY segundos despues.
local function OnEatMessage(msg, sender, event)
    if not msg or type(msg) ~= "string" then return end
    local lower = string.lower(msg)
    local rejectedPutrid = string.find(lower, "rechaza", 1, true) and string.find(lower, "putrefacto", 1, true)
    local hasNausea = string.find(lower, "náuseas", 1, true) or string.find(lower, "nauseas", 1, true)
    local beginsVomit = string.find(lower, "comienzas a vomitar", 1, true)
        or string.find(lower, "comienzas a vomit", 1, true)
        or string.find(lower, "empiezas a vomitar", 1, true)
    local ownVomitMessage = hasNausea and beginsVomit
    if not rejectedPutrid and not ownVomitMessage then return end
    -- un emote de otro jugador no cuenta (los mensajes del servidor llegan sin autor o con el mio)
    if (event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_TEXT_EMOTE")
       and sender and sender ~= "" and sender ~= UnitName("player") then
        return
    end
    if ownVomitMessage then
        -- Un texto de emote sin emisor propio puede pertenecer a otro jugador cercano.
        if sender and sender ~= "" and sender ~= UnitName("player") then return end
        if event ~= "CHAT_MSG_SYSTEM" and event ~= "UI_INFO_MESSAGE" and event ~= "UI_ERROR_MESSAGE"
           and sender ~= UnitName("player") then return end
    end
    if NS.debugOn then NS.Say("mensaje de comida (" .. tostring(event) .. "): " .. msg) end
    if ownVomitMessage then
        NS.ConfirmSelfVomit(true)
        return
    end
    if not NS.endTime then NS.Trigger(NS.EAT_DELAY) end
end

local function OnPlayerAura()
    local has = NS.HasPutrid("player")

    if NS.initialized then
        -- Compartir cambios de estado con otros usuarios del addon
        if has ~= NS.hadDebuff then NS.Send(has and "P:1" or "P:0") end
        local imm = NS.GetImmunityExpiry()
        if (imm ~= nil) ~= (NS.lastImm ~= nil) then NS.Send("I:" .. NS.ImmSecs(imm)) end
        NS.lastImm = imm

        -- Mi propio vomito confirmado por el aturdimiento / ¡Vomitado! aplicado por mi
        local vomitedNow = NS.SelfVomitAura()
        if vomitedNow and not NS.selfVomited then NS.ConfirmSelfVomit() end
        NS.selfVomited = vomitedNow

        -- Alguien vomito cerca mio (me aplico el aturdimiento de vomito)
        local by = NS.AuraVomitOnMe()
        if by then
            if by ~= NS.vomitOnMeBy then
                NS.vomitOnMeBy = by
                NS.SetVomit(by, "aura")
                if NS.db.warnTheirVomit then NS.ShowMsg("theirVomit", NS.Txt("vomitedOn", { name = by })) end
            end
        else
            NS.vomitOnMeBy = nil
        end

        -- No avisa si Estomago de hierro cubriria un vomito de ahora en adelante
        local nowT = GetTime()
        if has and not NS.hadDebuff then
            local fresh = nowT - NS.lastPutridSeen > NS.APPLIED_REARM
            if NS.debugOn then
                NS.Say("Putrefacto aplicado (" .. (fresh and "nuevo" or "refresco, sin aviso") .. ")")
            end
            if fresh and NS.db.warnApplied and not NS.ImmuneAt(nowT + NS.db.delay) then
                NS.ShowMsg("applied", NS.Txt("applied"))
            end
        elseif NS.hadDebuff and not has and NS.debugOn then
            NS.Say("Putrefacto perdido")
        end
        if has or NS.hadDebuff then NS.lastPutridSeen = nowT end

        -- Se cancela si perdés el debuff (con un margen por si el servidor lo refresca)
        if not has and NS.endTime and not NS.testing and (NS.endTime - nowT) > 2
           and nowT - NS.lastPutridSeen > 3 then
            NS.CancelCountdown()
        end

        local eatingNow = NS.IsEating()
        if eatingNow and not NS.wasEating and has and NS.db.eatFallback then
            NS.Trigger()
        end
        NS.wasEating = eatingNow
    end

    NS.hadDebuff = has
end

NS.f:RegisterEvent("ADDON_LOADED")
NS.f:RegisterEvent("PLAYER_ENTERING_WORLD")
NS.f:RegisterEvent("PLAYER_LOGOUT")
NS.f:RegisterEvent("UNIT_AURA")
NS.f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
NS.f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
NS.f:RegisterEvent("CHAT_MSG_ADDON")
NS.f:RegisterEvent("PLAYER_TARGET_CHANGED")
NS.f:RegisterEvent("PLAYER_FOCUS_CHANGED")
NS.f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
NS.f:RegisterEvent("RAID_ROSTER_UPDATE")
NS.f:RegisterEvent("PARTY_MEMBERS_CHANGED")
-- El mensaje de comida puede llegar por varios canales segun el servidor
NS.f:RegisterEvent("CHAT_MSG_SYSTEM")
NS.f:RegisterEvent("CHAT_MSG_EMOTE")
NS.f:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
NS.f:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
NS.f:RegisterEvent("CHAT_MSG_RAID_BOSS_EMOTE")
NS.f:RegisterEvent("CHAT_MSG_RAID_WARNING")
NS.f:RegisterEvent("CHAT_MSG_MONSTER_YELL")
NS.f:RegisterEvent("UI_INFO_MESSAGE")
NS.f:RegisterEvent("UI_ERROR_MESSAGE")
-- Awesome WotLK expone tokens de unidad para placas visibles en el cliente TuWoW.
if C_NamePlate and C_NamePlate.GetNamePlates then
    pcall(NS.f.RegisterEvent, NS.f, "NAME_PLATE_UNIT_ADDED")
    pcall(NS.f.RegisterEvent, NS.f, "NAME_PLATE_UNIT_REMOVED")
end
NS.f:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        TuWoWQoLDB = TuWoWQoLDB or {}
        TuWoWQoLDB.showDayNight = nil
        TuWoWQoLDB.dayNightPos = nil
        TuWoWQoLDB.showDRWidget, TuWoWQoLDB.drWidgetScale, TuWoWQoLDB.drWidgetPos = nil, nil, nil
        -- Migracion a la v0.5: el radar viene oculto y el vomito tarda 60 s exactos
        if next(TuWoWQoLDB) ~= nil then
            local v = TuWoWQoLDB.cfgVersion or 0
            if v < 2 then
                TuWoWQoLDB.showRadar = false
                TuWoWQoLDB.delay = 60
            end
            if v < 3 then TuWoWQoLDB.wideRange = false end -- contagio: ~10 yd
        end
        NS.CopyDefaults(NS.DEFAULTS, TuWoWQoLDB)
        NS.db = TuWoWQoLDB
        TuWoWQoLDayNight.Configure(function() return NS.db end, NS.ShowMsg, NS.Txt, NS.Say, function() return NS.debugOn end)
        NS.SetSilentNameplateMode(NS.db.silentNameplates)
        NS.BuildOptions()
        InterfaceOptions_AddCategory(NS.panel)
        InterfaceOptionsFrame:HookScript("OnShow", function() NS.Snapshot() end)
        InterfaceOptionsFrame:HookScript("OnHide", function()
            NS.snapshot = nil
            NS.Refresh()
        end)
        NS.ApplyAll()
        -- En 3.3.5 no hace falta registrar el prefijo; en clientes nuevos si.
        if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(NS.PREFIX) end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not NS.db then return end
        if NS.db.silentNameplates then NS.SetSilentNameplateMode(true) end
        NS.hadDebuff = NS.HasPutrid("player")
        if NS.hadDebuff then NS.lastPutridSeen = GetTime() end
        NS.wasEating = NS.IsEating()
        NS.lastImm = NS.GetImmunityExpiry()
        NS.selfVomited = NS.SelfVomitAura()
        NS.initialized = true
        for unit in pairs(NS.nameplateUnits) do NS.HandleUnitAura(unit) end
        NS.helloAt = GetTime() + 4

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if type(arg1) == "string" then
            NS.nameplateUnits[arg1] = true
            NS.HideFriendlyNameplate(arg1)
            if NS.debugOn then
                local name = UnitName(arg1)
                if name then NS.Say("nameplate detectado: " .. name .. (UnitIsPlayer(arg1) and " (jugador)" or " (no jugador)")) end
            end
            if NS.db and NS.initialized then NS.HandleUnitAura(arg1) end
        end

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local saved = NS.hiddenNameplateFrames[arg1]
        if saved and saved.frame and saved.frame.SetAlpha then
            saved.frame:SetAlpha(saved.alpha or 1)
            NS.hiddenNameplateFrames[arg1] = nil
        end
        if arg1 then NS.nameplateUnits[arg1] = nil end

    elseif event == "PLAYER_LOGOUT" then
        if NS.db and NS.db.silentNameplates then NS.RestoreSilentNameplates(true) end

    elseif not NS.db or not NS.initialized then
        return

    elseif event == "UNIT_AURA" then
        if arg1 == "player" then
            OnPlayerAura()
        elseif arg1 and (string.find(arg1, "^party%d$") or string.find(arg1, "^raid%d+$")) then
            NS.HandleGroupAura(arg1)
            NS.HandleUnitAura(arg1)
        elseif arg1 == "target" or arg1 == "focus"
           or (arg1 and string.find(arg1, "^nameplate%d+$")) then
            NS.HandleUnitAura(arg1)
        end

    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- 3.3.5: timestamp, subevent, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellId, spellName
        NS.OnCombatLog(arg2, arg4, arg5, arg7, arg8, arg9, arg10)

    elseif event == "CHAT_MSG_ADDON" then
        NS.OnAddonMessage(arg1, arg2, arg3, arg4)

    elseif string.sub(event, 1, 8) == "CHAT_MSG" or string.sub(event, 1, 10) == "UI_INFO_ME"
           or string.sub(event, 1, 10) == "UI_ERROR_M" then
        if DAYNIGHT_EVENTS[event] then TuWoWQoLDayNight.HandleMessage(arg1, event, arg2) end
        if event ~= "CHAT_MSG_RAID_WARNING" and event ~= "CHAT_MSG_MONSTER_YELL" then
            OnEatMessage(arg1, arg2, event)
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        NS.HandleUnitAura("target")

    elseif event == "PLAYER_FOCUS_CHANGED" then
        NS.HandleUnitAura("focus")

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        local now = GetTime()
        if now - NS.lastMouse >= 0.3 then
            NS.lastMouse = now
            NS.HandleUnitAura("mouseover")
        end

    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        if NS.db.syncEnabled and not NS.helloAt then NS.helloAt = GetTime() + 2 end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if arg1 ~= "player" or not arg2 then return end
        if NS.db.eatFallback and NS.HasPutrid("player") then
            local lower = string.lower(arg2)
            for _, p in ipairs(NS.POTION_PATTERNS) do
                if string.find(lower, p, 1, true) then
                    NS.Trigger()
                    break
                end
            end
        end
    end
end)
