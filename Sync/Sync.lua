local _, NS = ...

---------------------------------------------------------------------
-- Envio y recepcion de mensajes entre usuarios del addon
---------------------------------------------------------------------
function NS.ImmSecs(expires)
    if not expires then return 0 end
    if expires == math.huge then return 9999 end
    return math.max(1, math.floor(expires - GetTime()))
end

function NS.Send(msg)
    if not NS.db then return end
    local isVersionHello = string.sub(msg or "", 1, 2) == "H:"
    if not NS.db.syncEnabled and not isVersionHello then return end
    local ch
    local _, itype = IsInInstance()
    if itype == "pvp" then
        ch = "BATTLEGROUND"
    elseif (GetNumRaidMembers() or 0) > 0 then
        ch = "RAID"
    elseif (GetNumPartyMembers() or 0) > 0 then
        ch = "PARTY"
    end
    if ch then pcall(SendAddonMessage, NS.PREFIX, msg, ch) end
    if isVersionHello and IsInGuild and IsInGuild() then
        pcall(SendAddonMessage, NS.PREFIX, msg, "GUILD")
    end
    if NS.db.syncNearby then pcall(SendAddonMessage, NS.PREFIX, msg, "SAY") end
end

function NS.SendState()
    local now = GetTime()
    local rem = "-"
    if NS.endTime and not NS.testing then rem = tostring(math.max(0, math.ceil(NS.endTime - now))) end
    NS.Send(string.format("S:%d:%s:%d", NS.hadDebuff and 1 or 0, rem, NS.ImmSecs(NS.GetImmunityExpiry())))
end

function NS.SendHello()
    local now = GetTime()
    if now - NS.lastHello < 8 then return end
    NS.lastHello = now
    NS.Send("H:" .. tostring(NS.VERSION))
    if NS.hadDebuff or NS.endTime then NS.SendState() end
end

local function IsVersionNewer(candidate, installed)
    local cMajor, cMinor, cPatch = string.match(tostring(candidate or ""), "^v?(%d+)%.(%d+)%.?(%d*)$")
    local iMajor, iMinor, iPatch = string.match(tostring(installed or ""), "^v?(%d+)%.(%d+)%.?(%d*)$")
    if not cMajor or not iMajor then return false end
    cMajor, cMinor, cPatch = tonumber(cMajor), tonumber(cMinor), tonumber(cPatch) or 0
    iMajor, iMinor, iPatch = tonumber(iMajor), tonumber(iMinor), tonumber(iPatch) or 0
    if cMajor ~= iMajor then return cMajor > iMajor end
    if cMinor ~= iMinor then return cMinor > iMinor end
    return cPatch > iPatch
end

local function Num(str)
    local n = tonumber(str)
    if n and n >= 0 and n <= 3600 then return n end
end

-- Jugador fuera del grupo que nos hablo por /decir y esta por vomitar: le avisamos
-- por susurro que estamos cerca, para que su aviso "alejate" nos incluya.
local function MaybeAck(sender, p, rem)
    if not rem or rem > 15 or p.chan ~= "SAY" then return end
    if NS.FindUnit(sender) or not NS.CanBeInfected() then return end
    local now = GetTime()
    if NS.lastAck[sender] and now - NS.lastAck[sender] < 6 then return end
    NS.lastAck[sender] = now
    pcall(SendAddonMessage, NS.PREFIX, "A", "WHISPER", sender)
end

function NS.OnAddonMessage(prefix, msg, channel, sender)
    if prefix ~= NS.PREFIX or not NS.db or not msg or not sender then return end
    if sender == (NS.myName or UnitName("player")) then return end
    local now = GetTime()
    -- Con "cercanos" el mismo mensaje llega por grupo/banda y por /decir: se procesa una vez
    local key = sender .. "\1" .. msg
    if NS.recentMsg[key] and now - NS.recentMsg[key] < 1 then return end
    NS.recentMsg[key] = now
    local au = NS.addonUsers[sender]
    local isNew = false
    if not au then au = {}; NS.addonUsers[sender] = au; isNew = true end
    au.seen = now

    local cmd, rest = string.match(msg, "^(%a):?(.*)$")
    if not cmd then return end
    if not NS.db.syncEnabled and cmd ~= "H" then return end

    if cmd == "H" then
        au.ver = string.match(rest, "^([^:]*)")
        if IsVersionNewer(au.ver, NS.VERSION)
           and (not NS.UPDATE_NOTICE.version or IsVersionNewer(au.ver, NS.UPDATE_NOTICE.version)) then
            NS.UPDATE_NOTICE.version = au.ver
            NS.Say(sender .. " usa TuWoW QoL v" .. au.ver .. "; tu versión es v" .. NS.VERSION
                .. ". Actualizalo desde el Launcher o en https://github.com/notranco/TuWoWQoL")
        end
        if isNew and not NS.helloAt then NS.helloAt = now + 1 + math.random() end
        return
    elseif cmd == "A" then
        NS.acks[sender] = now
        return
    end

    local p = NS.Person(sender, "sync")
    p.addon = true
    p.chan = channel and string.upper(channel) or nil
    p.chanAt = now

    if cmd == "P" then
        NS.SetPutrid(sender, rest == "1", "sync")
    elseif cmd == "E" then
        local s = Num(rest)
        if s then
            NS.SetEat(sender, s, "sync", false)
            MaybeAck(sender, p, s)
        end
    elseif cmd == "V" then
        NS.SetVomit(sender, "sync")
    elseif cmd == "C" then
        p.vomitAt = nil
        p.warnedImminent = nil
    elseif cmd == "I" then
        local s = Num(rest)
        p.immune = s ~= nil and s > 0
    elseif cmd == "S" then
        local pu, rem, imm = string.match(rest, "^(%d):([%-%d]*):(%d+)$")
        if pu then
            p.immune = (tonumber(imm) or 0) > 0
            if pu == "1" then
                p.putrid = true
                local r = Num(rem)
                if r then
                    if not (p.vomitAt and math.abs(p.vomitAt - (now + r)) < 3) then
                        NS.SetEat(sender, r, "sync", false)
                    end
                    MaybeAck(sender, p, r)
                else
                    p.vomitAt = nil
                end
            else
                NS.SetPutrid(sender, false, "sync")
            end
        end
    end
end
