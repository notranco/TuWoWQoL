local ADDON, NS = ...

---------------------------------------------------------------------
-- Configuracion (Interfaz > AddOns)
---------------------------------------------------------------------
NS.panel = CreateFrame("Frame", "TuWoWQoLOptions", UIParent)
NS.panel.name = "TuWoW QoL"

local controls = {}
local refreshing = false
NS.snapshot = nil
local unlockCB
NS.OpenEditor = nil

function NS.ApplyAll()
    NS.ApplyPos(NS.f, NS.db.msgPos)
    NS.ApplyPos(NS.barFrame, NS.db.barPos)
    NS.ApplyPos(NS.radar, NS.db.radarPos)
    NS.ApplyScale()
    NS.ApplyMinimap()
    NS.ApplyLock()
end

function NS.Refresh()
    if not NS.db then return end
    refreshing = true
    for _, c in ipairs(controls) do
        if c.kind == "check" then
            c.frame:SetChecked(NS.db[c.key] and true or false)
        else
            c.frame:SetValue(NS.db[c.key])
        end
    end
    if unlockCB then unlockCB:SetChecked(NS.unlocked) end
    refreshing = false
end

function NS.Header(parent, str, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOP", parent, "TOP", 0, y)
    fs:SetText(str)
    local l1 = parent:CreateTexture(nil, "ARTWORK")
    l1:SetTexture(NS.WHITE)
    l1:SetVertexColor(1, 0.82, 0, 0.4)
    l1:SetHeight(1)
    l1:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y - 7)
    l1:SetPoint("TOPRIGHT", fs, "TOPLEFT", -10, -7)
    local l2 = parent:CreateTexture(nil, "ARTWORK")
    l2:SetTexture(NS.WHITE)
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

function NS.Note(parent, str, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, y)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -22, y)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    fs:SetText(str)
    return fs
end

function NS.Check(parent, key, label, y, onChange)
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
        NS.db[key] = self:GetChecked() and true or false
        if onChange then onChange() end
    end)
    controls[#controls + 1] = { kind = "check", key = key, frame = cb }
    return cb
end

function NS.Slider(parent, key, label, minV, maxV, step, y, fmt, onChange)
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
        NS.db[key] = value
        if onChange then onChange() end
    end)
    controls[#controls + 1] = { kind = "slider", key = key, frame = s }
    return s
end

function NS.Button(parent, label, x, y, width, onClick)
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

function NS.ResetPositions()
    NS.db.msgPos = NS.DeepCopy(NS.DEFAULTS.msgPos)
    NS.db.barPos = NS.DeepCopy(NS.DEFAULTS.barPos)
    NS.db.radarPos = NS.DeepCopy(NS.DEFAULTS.radarPos)
    NS.ApplyPos(NS.f, NS.db.msgPos)
    NS.ApplyPos(NS.barFrame, NS.db.barPos)
    NS.ApplyPos(NS.radar, NS.db.radarPos)
end

function NS.BuildOptions()
    local title = NS.panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("TuWoW QoL")
    local sub = NS.panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetText("Mejoras de calidad de vida - módulo Putrefacto  (v" ..
        tostring(GetAddOnMetadata(ADDON, "Version") or "?") .. ")")

    local box = CreateFrame("Frame", nil, NS.panel)
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
        -- Scroll nativo de WoW: UIPanelScrollFrameTemplate trae su propia barra con
        -- flechas, rueda del mouse y arrastre del cursor.
        local scroll = CreateFrame("ScrollFrame", "TuWoWQoLOptionsScroll" .. pageIndex, box,
            "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -28, 8)

        local content = CreateFrame("Frame", nil, scroll)
        content:SetHeight(440)
        content.labels = {}
        scroll:SetScrollChild(content)
        scroll.content = content
        scroll:SetScript("OnSizeChanged", function(self, width)
            local contentWidth = math.max(100, width)
            self.content:SetWidth(contentWidth)
            for _, labelText in ipairs(self.content.labels) do
                labelText:SetWidth(math.max(80, contentWidth - 48))
            end
        end)
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
        local ok, t = pcall(CreateFrame, "Button", "TuWoWQoLTab" .. i, NS.panel, "OptionsFrameTabButtonTemplate")
        if ok and t then
            t.native = true
            t:SetText(label)
            local fs = t:GetFontString()
            t:SetWidth((fs and fs:GetStringWidth() or 60) + 34)
        else
            t = CreateFrame("Button", nil, NS.panel, "UIPanelButtonTemplate")
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
    NS.Header(general, "Opciones generales", -14)
    NS.Check(general, "sounds", "Activar sonidos", -40)
    NS.Check(general, "animations", "Activar animaciones", -66)
    NS.Check(general, "showMinimap", "Mostrar botón en el minimapa", -92, NS.ApplyMinimap)
    NS.Header(general, "Interfaz", -134)
    NS.Button(general, "Editar interfaz", 20, -160, 160, function() NS.OpenEditor() end)
    NS.Button(general, "Restablecer posición", 200, -160, 170, NS.ResetPositions)
    NS.Header(general, "Pruebas", -214)
    NS.Button(general, "Probar aviso", 20, -240, 140, function() NS.Trigger(15, true) end)
    NS.Button(general, "Probar contagio", 170, -240, 140, function()
        NS.ShowMsg("contagion", "¡Jugador está Putrefacto y cerca tuyo!")
    end)
    NS.Note(general, "La prueba simula una cuenta regresiva de 15 segundos.", -272)

    -- Avisos
    local warns = NewPage()
    NewTab("Avisos", 2)
    NS.Header(warns, "Cuenta regresiva", -14)
    NS.Check(warns, "warnStart", "Aviso inicial (vomitarás en X segundos)", -40)
    NS.Check(warns, "warn10", "Aviso a 10 segundos", -66)
    NS.Check(warns, "warnCount", "Cuenta 3, 2, 1", -92)
    NS.Check(warns, "warnVomit", "Mensaje ¡VOMITANDO!", -118)
    NS.Header(warns, "Estado", -162)
    NS.Check(warns, "warnApplied", "Avisar al recibir el debuff", -188)
    NS.Check(warns, "eatFallback", "Respaldo: detectar comida y pociones por buffs", -224)
    NS.Check(warns, "warnNight", "Avisar 5 minutos antes de la noche", -250)
    NS.Note(warns, "La cuenta (60 s exactos) empieza cuando el servidor avisa que tu estómago putrefacto rechaza lo consumido. " ..
        "El respaldo solo sirve si ese mensaje no te llega. " ..
        "Si perdés el debuff durante la cuenta, se cancela. " ..
        "Con Estómago de hierro solo se avisa si la inmunidad se va a acabar antes de que vomites.", -288)

    -- Contagio
    local cont = NewPage()
    NewTab("Contagio", 3)
    NS.Header(cont, "Alerta de contagio", -14)
    NS.Note(cont, "Si vomitas sobre otros jugadores, ellos también vomitan. " ..
        "Estas alertas funcionan con integrantes de tu grupo o banda.", -40)
    NS.Check(cont, "warnContagion", "Avisar si alguien del grupo recibe Putrefacto", -84)
    NS.Check(cont, "warnNear", "Avisar si un jugador con Putrefacto está cerca", -110)
    NS.Header(cont, "Jugadores cercanos", -146)
    NS.Check(cont, "warnEat", "Avisar si un jugador cercano come con Putrefacto", -172)
    NS.Check(cont, "warnImminent", "Avisar si un jugador cercano está por vomitar", -198)
    NS.Check(cont, "warnTheirVomit", "Avisar si un jugador cercano vomita", -224)
    NS.Check(cont, "warnAway", "Avisarme quién está cerca antes de vomitar", -250)
    NS.Check(cont, "wideRange", "Radio amplio (~28 yd); apagado: ~10 yd", -276)
    NS.Check(cont, "warnUnknown", "Avisar si no se puede medir la distancia", -302)
    NS.Check(cont, "silentNameplates", "Detectar sin mostrar barras amistosas (el addon las oculta)", -334,
        function() NS.SetSilentNameplateMode(NS.db.silentNameplates) end)
    NS.Note(cont, "El cliente solo expone unidades ajenas mediante grupo, objetivo, foco, cursor o nameplates. " ..
        "Este modo activa las placas amistosas para obtener sus unidades y las vuelve invisibles.", -366)

    -- Sincronía
    local sync = NewPage()
    NewTab("Sincronía", 4)
    NS.Header(sync, "Sincronización con otros usuarios", -14)
    NS.Note(sync, "Los jugadores que tengan este addon comparten su estado (Putrefacto, comió, va a vomitar, " ..
        "inmune) por tu grupo o banda, así cada uno sabe cuándo alejarse.", -40)
    NS.Check(sync, "syncEnabled", "Compartir y recibir estado con otros usuarios del addon", -92)
    NS.Check(sync, "syncNearby", "También con jugadores cercanos fuera del grupo (experimental)", -118)
    NS.Slider(sync, "alertSeconds", "Avisar cuando falten (seg)", 5, 20, 1, -170, "%d")
    NS.Header(sync, "Pruebas", -230)
    NS.Button(sync, "Probar radar", 20, -256, 140, NS.TestSync)
    NS.Button(sync, "Ver usuarios", 170, -256, 140, NS.ListUsers)
    NS.Note(sync, "Los avisos por jugador cercano se activan en la pestaña Contagio. El radar se muestra desde Editar interfaz " ..
        "(la prueba lo necesita activado) y solo lista jugadores cercanos. La prueba crea 3 jugadores falsos durante unos 25 segundos.", -288)

    SelectTab(1)
end
