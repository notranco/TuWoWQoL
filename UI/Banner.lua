local _, NS = ...

---------------------------------------------------------------------
-- Anclaje y banner del mensaje
---------------------------------------------------------------------
NS.f = CreateFrame("Frame", "TuWoWQoLMessageFrame", UIParent)
NS.f:SetSize(500, 70)
NS.f:SetPoint("TOP", UIParent, "TOP", 0, -180)
NS.f:SetFrameStrata("HIGH")
NS.f:SetMovable(true)
NS.f:SetClampedToScreen(true)
NS.f:RegisterForDrag("LeftButton")

NS.anchorTex = NS.f:CreateTexture(nil, "BACKGROUND")
NS.anchorTex:SetAllPoints()
NS.anchorTex:SetTexture(0, 0.6, 0, 0.35)
NS.anchorTex:Hide()
NS.anchorLabel = NS.f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
NS.anchorLabel:SetPoint("CENTER")
NS.anchorLabel:SetText("TuWoW QoL - mensaje (arrastrá para mover)")
NS.anchorLabel:Hide()

NS.banner = CreateFrame("Frame", nil, NS.f)
NS.banner:SetSize(400, 64)
NS.banner:SetPoint("CENTER", NS.f, "CENTER", 0, 0)
NS.banner:Hide()

local bgL = NS.banner:CreateTexture(nil, "BACKGROUND")
bgL:SetTexture(NS.WHITE)
bgL:SetPoint("TOPLEFT")
bgL:SetPoint("BOTTOMRIGHT", NS.banner, "BOTTOM", 0, 0)
bgL:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.7)
local bgR = NS.banner:CreateTexture(nil, "BACKGROUND")
bgR:SetTexture(NS.WHITE)
bgR:SetPoint("TOPLEFT", NS.banner, "TOP", 0, 0)
bgR:SetPoint("BOTTOMRIGHT")
bgR:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0.7, 0, 0, 0, 0)

NS.lines = {}
local function MakeLine(top, left)
    local t = NS.banner:CreateTexture(nil, "BORDER")
    t:SetTexture(NS.WHITE)
    t:SetHeight(2)
    if top then
        if left then
            t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT", NS.banner, "TOP", 0, 0)
        else
            t:SetPoint("TOPLEFT", NS.banner, "TOP", 0, 0); t:SetPoint("TOPRIGHT")
        end
    else
        if left then
            t:SetPoint("BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT", NS.banner, "BOTTOM", 0, 0)
        else
            t:SetPoint("BOTTOMLEFT", NS.banner, "BOTTOM", 0, 0); t:SetPoint("BOTTOMRIGHT")
        end
    end
    t.left = left
    NS.lines[#NS.lines + 1] = t
end
MakeLine(true, true); MakeLine(true, false); MakeLine(false, true); MakeLine(false, false)

NS.iconBG = NS.banner:CreateTexture(nil, "ARTWORK")
NS.iconBG:SetTexture(NS.WHITE)
NS.iconBG:SetVertexColor(0, 0, 0, 0.85)
NS.iconBG:SetSize(46, 46)
NS.iconBG:SetPoint("LEFT", 26, 0)
NS.icon = NS.banner:CreateTexture(nil, "OVERLAY")
NS.icon:SetSize(40, 40)
NS.icon:SetPoint("CENTER", NS.iconBG, "CENTER")
NS.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

NS.text = NS.banner:CreateFontString(nil, "OVERLAY")
NS.text:SetFont(NS.FONT, 30, "OUTLINE")
NS.text:SetPoint("CENTER")
