local _, NS = ...

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
    NS.unlocked = on and true or false
    NS.ApplyLock()
    if not NS.unlocked then NS.HideMsg() end
end

local function Ov(kind)
    NS.db.style = NS.db.style or {}
    local o = NS.db.style[kind]
    if not o then o = {}; NS.db.style[kind] = o end
    return o
end

function E.Preview(silent)
    local it = EDIT_ITEMS[E.cur or 1]
    if not it or not it.kind then return end
    local str = it.key and NS.Txt(it.key, it.vars) or "3"
    NS.ShowMsg(it.kind, str, silent)
end

function E.Select(i)
    local n = #EDIT_ITEMS
    if i < 1 then i = n elseif i > n then i = 1 end
    E.cur = i
    local it = EDIT_ITEMS[i]
    E.label:SetText(string.format("%d/%d  %s", i, n, it.label))
    E.hint:SetText(it.hint or "")
    if it.key then
        local cur = NS.db.texts and NS.db.texts[it.key]
        if not cur or cur == "" then cur = NS.TEXTS[it.key] end
        E.edit:SetText(cur)
        E.edit:Show()
    else
        E.edit:Hide()
    end
    if it.kind then
        local st = NS.MSG[it.kind]
        local ov = NS.db.style and NS.db.style[it.kind]
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
    local c = ov.color or NS.MSG[it.kind].color
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
    NS.Note(ed, "Arrastrá el mensaje, la barra y el radar para moverlos. Esta ventana también se mueve.", -34)
    local close = CreateFrame("Button", nil, ed, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", ed, "TOPRIGHT", -2, -2)

    NS.Slider(ed, "msgScale", "Tamaño del aviso", 0.6, 1.6, 0.1, -72, "%.1f")
    NS.Slider(ed, "barScale", "Tamaño de la barra", 0.6, 1.6, 0.1, -118, "%.1f", NS.ApplyScale)
    NS.Slider(ed, "radarScale", "Tamaño del radar", 0.6, 1.6, 0.1, -164, "%.1f", NS.ApplyScale)
    NS.Slider(ed, "radarRows", "Filas del radar", 1, 8, 1, -210, "%d")
    NS.Check(ed, "showBar", "Mostrar barra de tiempo", -246)
    NS.Check(ed, "showRadar", "Mostrar radar (solo jugadores cercanos)", -272)

    NS.Header(ed, "Textos y estilo", -304)
    NS.Button(ed, "<", 24, -326, 30, function() E.Select((E.cur or 1) - 1) end)
    NS.Button(ed, ">", 366, -326, 30, function() E.Select((E.cur or 1) + 1) end)
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
        NS.db.texts = NS.db.texts or {}
        NS.db.texts[it.key] = self:GetText()
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
    E.colorBtn = NS.Button(ed, "Color", 110, -452, 70, PickColor)
    E.swatch = ed:CreateTexture(nil, "ARTWORK")
    E.swatch:SetSize(16, 16)
    E.swatch:SetPoint("TOPLEFT", ed, "TOPLEFT", 186, -456)
    E.testBtn = NS.Button(ed, "Probar", 215, -452, 80, function() E.Preview(false) end)
    NS.Button(ed, "Restablecer", 300, -452, 100, function()
        local it = EDIT_ITEMS[E.cur or 1]
        if not it then return end
        if it.key and NS.db.texts then NS.db.texts[it.key] = nil end
        if it.kind and NS.db.style then NS.db.style[it.kind] = nil end
        E.Select(E.cur or 1)
    end)

    NS.Button(ed, "Restablecer posiciones", 20, -498, 180, NS.ResetPositions)
    NS.Button(ed, "Listo", 310, -498, 90, function() ed:Hide() end)

    ed:SetScript("OnShow", function()
        SetEdit(true)
        NS.Refresh()
        E.Select(E.cur or 1)
    end)
    ed:SetScript("OnHide", function()
        SetEdit(false)
    end)
end

NS.OpenEditor = function()
    if not NS.db then return end
    if not E.frame then BuildEditor() end
    if E.frame:IsShown() then
        E.frame:Hide()
        return
    end
    NS.snapshot = nil -- lo hecho en el editor se guarda al instante
    CloseGameMenu()
    if InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
    E.frame:Show()
end

function NS.Snapshot()
    NS.snapshot = NS.DeepCopy(NS.db)
end

NS.panel.okay = function() NS.snapshot = nil end
NS.panel.cancel = function()
    if NS.snapshot and NS.db then
        for k in pairs(NS.db) do NS.db[k] = nil end
        for k, v in pairs(NS.snapshot) do NS.db[k] = NS.DeepCopy(v) end
        NS.snapshot = nil
        NS.ApplyAll()
        NS.Refresh()
    end
end
NS.panel.default = function()
    if not NS.db then return end
    for k in pairs(NS.db) do NS.db[k] = nil end
    NS.CopyDefaults(NS.DEFAULTS, NS.db)
    NS.ApplyAll()
    NS.Refresh()
end
NS.panel.refresh = NS.Refresh
NS.panel:SetScript("OnShow", function()
    if NS.db and not NS.snapshot then NS.Snapshot() end
    NS.Refresh()
end)

local function OpenConfig()
    if not NS.db then return end
    if InterfaceOptionsFrame:IsShown() and NS.panel:IsVisible() then
        InterfaceOptionsFrame:Hide()
        return
    end
    -- Se llama dos veces por un bug conocido de 3.3.5 al abrir categorias de addons
    InterfaceOptionsFrame_OpenToCategory(NS.panel)
    InterfaceOptionsFrame_OpenToCategory(NS.panel)
end

NS.mm:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        if GameMenuFrame and GameMenuFrame:IsShown() then HideUIPanel(GameMenuFrame) end
        NS.OpenEditor()
    else
        OpenConfig()
    end
end)

SLASH_TUWOWQOL1 = "/twqol"
SLASH_TUWOWQOL2 = "/tuwowqol"
SlashCmdList["TUWOWQOL"] = function(msg)
    local cmd = string.lower(string.match(msg or "", "^%s*(%S*)") or "")
    if cmd == "help" or cmd == "ayuda" then
        NS.ShowHelp()
    elseif cmd == "status" or cmd == "estado" then
        NS.ShowStatus()
    elseif cmd == "debug" then
        NS.debugOn = not NS.debugOn
        NS.Say("debug " .. (NS.debugOn and "activado: se muestran eventos de Putrefacto, comida y vómito de otros jugadores" or "desactivado"))
    elseif cmd == "radar" then
        if NS.db then
            NS.db.showRadar = not NS.db.showRadar
            NS.Say("radar " .. (NS.db.showRadar and "activado" or "desactivado"))
        end
    elseif cmd == "lista" or cmd == "users" then
        NS.ListUsers()
    elseif cmd == "test" then
        if NS.db then NS.TestSync() end
    elseif cmd == "editar" or cmd == "ui" or cmd == "editor" then
        NS.OpenEditor()
    else
        OpenConfig()
    end
end
