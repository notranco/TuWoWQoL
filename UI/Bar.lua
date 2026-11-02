local _, NS = ...

---------------------------------------------------------------------
-- Barra de tiempo
---------------------------------------------------------------------
NS.barFrame = CreateFrame("Frame", "TuWoWQoLBarFrame", UIParent)
NS.barFrame:SetSize(260, 28)
NS.barFrame:SetPoint("TOP", UIParent, "TOP", 0, -250)
NS.barFrame:SetFrameStrata("HIGH")
NS.barFrame:SetMovable(true)
NS.barFrame:SetClampedToScreen(true)
NS.barFrame:RegisterForDrag("LeftButton")
NS.barFrame:SetBackdrop({
    bgFile = NS.WHITE, edgeFile = NS.WHITE, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
})
NS.barFrame:SetBackdropColor(0, 0, 0, 0.65)
NS.barFrame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
NS.barFrame:SetAlpha(0)
NS.barFrame:Hide()

local barIcon = NS.barFrame:CreateTexture(nil, "ARTWORK")
barIcon:SetSize(22, 22)
barIcon:SetPoint("LEFT", 3, 0)
barIcon:SetTexture(NS.ICON_DEBUFF)
barIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

NS.bar = CreateFrame("StatusBar", nil, NS.barFrame)
NS.bar:SetPoint("LEFT", barIcon, "RIGHT", 4, 0)
NS.bar:SetPoint("RIGHT", NS.barFrame, "RIGHT", -3, 0)
NS.bar:SetHeight(16)
NS.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
NS.bar:SetMinMaxValues(0, 1)
NS.bar:SetValue(1)

local barBG = NS.bar:CreateTexture(nil, "BACKGROUND")
barBG:SetAllPoints()
barBG:SetTexture(NS.WHITE)
barBG:SetVertexColor(0.1, 0.1, 0.1, 0.9)

NS.spark = NS.bar:CreateTexture(nil, "OVERLAY")
NS.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
NS.spark:SetBlendMode("ADD")
NS.spark:SetSize(20, 34)

NS.glow = NS.bar:CreateTexture(nil, "OVERLAY")
NS.glow:SetAllPoints()
NS.glow:SetTexture(NS.WHITE)
NS.glow:SetVertexColor(1, 0.1, 0.1)
NS.glow:SetBlendMode("ADD")
NS.glow:SetAlpha(0)

NS.barText = NS.bar:CreateFontString(nil, "OVERLAY")
NS.barText:SetFont(NS.FONT, 12, "OUTLINE")
NS.barText:SetPoint("CENTER")

NS.barAlpha = 0

function NS.SavePos(frame, key)
    local point, _, relPoint, x, y = frame:GetPoint()
    NS.db[key] = { point = point, relPoint = relPoint, x = x, y = y }
end

function NS.ApplyPos(frame, pos)
    frame:ClearAllPoints()
    frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

NS.f:SetScript("OnDragStart", function(self) if NS.unlocked then self:StartMoving() end end)
NS.f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); NS.SavePos(self, "msgPos") end)
NS.barFrame:SetScript("OnDragStart", function(self) if NS.unlocked then self:StartMoving() end end)
NS.barFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); NS.SavePos(self, "barPos") end)

function NS.ApplyLock()
    NS.f:EnableMouse(NS.unlocked)
    NS.barFrame:EnableMouse(NS.unlocked)
    local strata = NS.unlocked and "FULLSCREEN_DIALOG" or "HIGH"
    NS.f:SetFrameStrata(strata)
    NS.barFrame:SetFrameStrata(strata)
    if NS.radar then
        NS.radar:EnableMouse(NS.unlocked)
        NS.radar:SetFrameStrata(strata)
    end
    if NS.unlocked then
        NS.anchorTex:Show(); NS.anchorLabel:Show()
    else
        NS.anchorTex:Hide(); NS.anchorLabel:Hide()
    end
end

function NS.ApplyScale()
    NS.barFrame:SetScale(NS.db.barScale or 1)
    if NS.radar then NS.radar:SetScale(NS.db.radarScale or 1) end
end
