local _, NS = ...

---------------------------------------------------------------------
-- Mensajes
---------------------------------------------------------------------
function NS.ShowMsg(kind, str, silent)
    local st = NS.MSG[kind]
    local ov = NS.db.style and NS.db.style[kind]
    local now = GetTime()
    if not NS.unlocked and st.prio < NS.curPriority and now < NS.msgUntil then return end
    NS.curPriority, NS.curStyle = st.prio, st
    NS.msgStart, NS.msgUntil = now, now + ((ov and ov.dur) or st.dur)
    if NS.unlocked then NS.msgUntil = now + 3600 end -- en el editor la vista previa queda fija

    local col = (ov and ov.color) or st.color
    local r, g, b = col[1], col[2], col[3]
    NS.text:SetFont(NS.FONT, (ov and ov.size) or st.size, "OUTLINE")
    NS.text:SetText(str)
    NS.text:SetTextColor(r, g, b)
    NS.text:ClearAllPoints()
    if st.icon then
        NS.icon:SetTexture(st.icon)
        NS.icon:Show(); NS.iconBG:Show()
        NS.text:SetPoint("CENTER", NS.banner, "CENTER", 24, 0)
    else
        NS.icon:Hide(); NS.iconBG:Hide()
        NS.text:SetPoint("CENTER", NS.banner, "CENTER", 0, 0)
    end
    NS.banner:SetWidth(math.min(900, math.max(240, NS.text:GetStringWidth() + (st.icon and 150 or 90))))
    for _, t in ipairs(NS.lines) do
        if t.left then
            t:SetGradientAlpha("HORIZONTAL", r, g, b, 0, r, g, b, 1)
        else
            t:SetGradientAlpha("HORIZONTAL", r, g, b, 1, r, g, b, 0)
        end
    end
    NS.banner:SetAlpha(0)
    NS.banner:Show()
    if st.sound and NS.db.sounds and not silent and not (ov and ov.mute) then PlaySound(st.sound) end
end

function NS.HideMsg()
    NS.banner:Hide()
    NS.curPriority, NS.msgUntil = 0, 0
end

function NS.UpdateBanner(now)
    if not NS.banner:IsShown() then return end
    if now >= NS.msgUntil then
        NS.banner:Hide()
        NS.curPriority = 0
        return
    end
    local st = NS.curStyle
    local age, remaining = now - NS.msgStart, NS.msgUntil - now
    local scale, alpha, xoff = 1, 1, 0
    if NS.db.animations then
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
    NS.banner:SetAlpha(alpha)
    NS.banner:SetScale((NS.db.msgScale or 1) * scale)
    NS.banner:ClearAllPoints()
    NS.banner:SetPoint("CENTER", NS.f, "CENTER", xoff, 0)
end
