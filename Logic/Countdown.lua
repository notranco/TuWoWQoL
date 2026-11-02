-- Cuenta regresiva del vomito y barra de tiempo
local _, NS = ...

function NS.Trigger(delay, isTest)
    if NS.endTime then return end
    local d = delay or NS.db.delay
    NS.totalTime = d
    NS.testing = isTest and true or false
    NS.endTime = GetTime() + d
    NS.warned10 = d <= 10
    NS.lastCount = nil
    NS.lastBarSec = nil
    NS.saidAway = false
    if NS.db.warnStart and not NS.ImmuneAt(NS.endTime) then
        NS.ShowMsg("start", NS.Txt("start", { s = d }))
    end
    if not NS.testing then NS.Send("E:" .. d) end
end

function NS.CancelCountdown()
    if NS.endTime and not NS.testing then NS.Send("C") end
    NS.endTime = nil
    NS.testing = false
    NS.saidAway = false
    NS.HideMsg()
end

function NS.UpdateCountdown(now)
    if not NS.endTime then return end
    local remaining = NS.endTime - now

    if remaining <= 10 and not NS.warned10 then
        NS.warned10 = true
        if NS.db.warn10 and not NS.ImmuneAt(NS.endTime) then
            NS.ShowMsg("ten", NS.Txt("ten"))
        end
    end

    if remaining <= 10 and remaining > 0 and NS.db.warnAway then
        NS.AwayCheck(now, remaining)
    end

    if remaining <= 3 and remaining > 0 then
        local c = math.ceil(remaining)
        if c ~= NS.lastCount then
            NS.lastCount = c
            if NS.db.warnCount and not NS.ImmuneAt(NS.endTime) then NS.ShowMsg("tick", tostring(c)) end
        end
    end

    if remaining <= 0 then
        local vomitTime = NS.endTime
        local immune = NS.ImmuneAt(vomitTime)
        local wasTest = NS.testing
        NS.endTime = nil
        NS.testing = false
        if not wasTest then
            NS.Send(immune and "C" or "V")
            if not immune then NS.lastVSent = GetTime() end
        end
        if NS.db.warnVomit and not immune then NS.ShowMsg("vomit", NS.Txt("vomit")) end
    end
end

function NS.UpdateBar(now, elapsed)
    local want = false
    if NS.endTime and NS.db.showBar then
        want = true
        local remaining = math.max(0, NS.endTime - now)
        NS.bar:SetMinMaxValues(0, NS.totalTime)
        NS.bar:SetValue(remaining)
        if remaining > 20 then
            NS.bar:SetStatusBarColor(0.25, 0.8, 0.25)
        elseif remaining > 10 then
            NS.bar:SetStatusBarColor(1, 0.65, 0.1)
        else
            NS.bar:SetStatusBarColor(0.9, 0.15, 0.15)
        end
        -- el texto solo se rearma cuando cambia el segundo (Txt hace un gsub y crea strings)
        local sec = math.ceil(remaining)
        if sec ~= NS.lastBarSec then
            NS.lastBarSec = sec
            NS.barText:SetText(NS.Txt("barText", { s = sec }))
        end
        NS.spark:ClearAllPoints()
        NS.spark:SetPoint("CENTER", NS.bar, "LEFT", NS.bar:GetWidth() * (remaining / NS.totalTime), 0)
        NS.spark:Show()
        if NS.db.animations and remaining <= 10 then
            NS.glow:SetAlpha(0.28 * (0.5 + 0.5 * math.sin(now * 8)))
        else
            NS.glow:SetAlpha(0)
        end
    elseif NS.unlocked then
        want = true
        NS.bar:SetMinMaxValues(0, 1)
        NS.bar:SetValue(0.6)
        NS.bar:SetStatusBarColor(0.25, 0.8, 0.25)
        NS.barText:SetText(NS.Txt("barText", { s = 42 }))
        NS.lastBarSec = nil
        NS.spark:Hide()
        NS.glow:SetAlpha(0)
    end

    local speed = NS.db.animations and 4 or 1000
    if want then
        NS.barAlpha = math.min(1, NS.barAlpha + elapsed * speed)
        if not NS.barFrame:IsShown() then NS.barFrame:Show() end
    else
        NS.barAlpha = math.max(0, NS.barAlpha - elapsed * speed)
        if NS.barAlpha <= 0 and NS.barFrame:IsShown() then NS.barFrame:Hide() end
    end
    NS.barFrame:SetAlpha(NS.barAlpha)
end
