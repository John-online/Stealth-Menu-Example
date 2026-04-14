-- -- Config --
local Mod = {
    handle = nil,
    isOpen = false,
    eventHandlers = {},
    debug = true,
    simpleEsp = false,
    nearbyDistance = 120,
    nearbyRefreshMs = 100,
    nextNearbyRefreshAt = 0,
    holdState = {
        leftAt = 0,
        rightAt = 0,
        initialDelay = 170,
        repeatDelay = 40
    },
    keybinds = {
        Toggle = VK_F3,
        Up     = VK_UP,
        Down   = VK_DOWN,
        Left   = VK_LEFT,
        Right  = VK_RIGHT,
        Enter  = 0x0D,
        Back   = 0x08
    },
    urls = {
        Menu     = "http://localhost:3000",
        Validate = "http://localhost:3000/validateUserId"
    },
    userId = Stealth.GetUserID()
}

-- -- Debug --
function Mod:Log(message)
    if self.debug then
        print("[Menu] " .. tostring(message))
    end
end

-- -- Event system --
function Mod.ListenChanges(itemId, callback)
    if type(itemId) ~= "string" or type(callback) ~= "function" then return false end
    if type(Mod.eventHandlers[itemId]) ~= "table" then
        Mod.eventHandlers[itemId] = {}
    end
    table.insert(Mod.eventHandlers[itemId], callback)
    return true
end

function Mod:DispatchEvent(event)
    local listeners = self.eventHandlers[event.item_id]
    if type(listeners) ~= "table" then return end
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, event)
        if not ok then self:Log("Handler error for " .. event.item_id .. ": " .. tostring(err)) end
    end
end

-- -- Menu lifecycle --
function Mod:Init()
    local ok = Stealth.FetchContent(self.urls.Validate)
    if ok ~= "true" then
        self:Log("Init failed: user validation returned false")
        return false
    end
    self.handle = Stealth.CreateDui(self.urls.Menu)
    self:Log("Init success")
    return true
end

function Mod:Toggle()
    if not self.handle then return end
    self.isOpen = not self.isOpen
    if self.isOpen then
        Stealth.ShowDui(self.handle)
        self:SetNearbyDistance(self.nearbyDistance)
        self:RefreshNearbyPlayers()
        self.nextNearbyRefreshAt = GetGameTimer() + self.nearbyRefreshMs
        self:Log("Menu opened")
    else
        Stealth.HideDui(self.handle)
        self.nextNearbyRefreshAt = 0
        self:Log("Menu closed")
    end
end

function Mod:ClampDistance(value)
    local numberValue = tonumber(value) or self.nearbyDistance
    if numberValue < 10 then numberValue = 10 end
    if numberValue > 500 then numberValue = 500 end
    return math.floor(numberValue / 10 + 0.5) * 10
end

function Mod:ExecuteMenuQuery(query)
    local wrapped = string.format([[
        (function() {
            var helper = window.StealthMenuHelper;
            if (!helper) {
                var frames = document.getElementsByTagName('iframe');
                for (var i = 0; i < frames.length; i++) {
                    try {
                        var fw = frames[i].contentWindow;
                        if (fw && fw.StealthMenuHelper) { helper = fw.StealthMenuHelper; break; }
                    } catch(e) {}
                }
            }

            if (!helper) return '{"ok":false,"reason":"helper_missing"}';

            try {
                var result = (%s);
                return JSON.stringify(result || { ok: true });
            } catch (err) {
                return JSON.stringify({ ok: false, reason: String(err) });
            }
        })();
    ]], query)

    return Stealth.ExecuteJSWithResult(wrapped)
end

function Mod:SetNearbyDistance(distance)
    self.nearbyDistance = self:ClampDistance(distance)
    self:ExecuteMenuQuery(string.format("helper.setNearbyDistance(%d)", self.nearbyDistance))
end

function Mod:GetNearbyPlayers(maxDistance)
    local players = {}
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local ped = GetPlayerPed(player)
            if ped and ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local dx = myCoords.x - coords.x
                local dy = myCoords.y - coords.y
                local dz = myCoords.z - coords.z
                local distance = math.sqrt(dx * dx + dy * dy + dz * dz)

                if distance <= maxDistance then
                    local serverId = GetPlayerServerId(player)
                    local playerName = GetPlayerName(player) or ("Player " .. tostring(serverId))
                    table.insert(players, {
                        server_id = serverId,
                        name = playerName,
                        distance = math.floor(distance + 0.5)
                    })
                end
            end
        end
    end

    table.sort(players, function(a, b)
        return a.distance < b.distance
    end)

    return players
end

function Mod:RefreshNearbyPlayers(silent)
    local players = self:GetNearbyPlayers(self.nearbyDistance)
    local payload = json.encode(players)
    self:ExecuteMenuQuery("helper.setNearbyPlayers(" .. payload .. ")")
    if not silent then
        self:Log("Nearby players refreshed: " .. tostring(#players) .. " within " .. tostring(self.nearbyDistance) .. "m")
    end
end

function Mod:ProcessAutoRefresh()
    if not self.isOpen then return end

    local now = GetGameTimer()
    if now < self.nextNearbyRefreshAt then return end

    self:RefreshNearbyPlayers(true)
    self.nextNearbyRefreshAt = now + self.nearbyRefreshMs
end

function Mod:IsControlHeld(key)
    if type(Stealth.IsControlPressed) ~= "function" then
        return false
    end
    return Stealth.IsControlPressed(key)
end

function Mod:DrawSimpleEspForPed(targetPed)
    if not DoesEntityExist(targetPed) or IsEntityDead(targetPed) then return end

    local headPos = GetPedBoneCoords(targetPed, 31086, 0.0, 0.0, 0.0)
    local lFoot = GetPedBoneCoords(targetPed, 14201, 0.0, 0.0, 0.0)
    local rFoot = GetPedBoneCoords(targetPed, 52301, 0.0, 0.0, 0.0)
    local footZ = math.min(lFoot.z, rFoot.z)

    local hx, hy = Stealth.WorldToScreen(headPos.x, headPos.y, headPos.z + 0.2)
    local fx, fy = Stealth.WorldToScreen(headPos.x, headPos.y, footZ - 0.1)

    if hx and fx and hy and fy then
        local height = math.abs(fy - hy)
        local width = height * 0.35
        local bx = (hx + fx) * 0.5
        local by = (hy + fy) * 0.5
        Stealth.DrawBox(bx, by, width, height, 51, 115, 230, 200, 1.0)

        local hp = GetEntityHealth(targetPed) - 100
        local maxHp = GetEntityMaxHealth(targetPed) - 100
        if maxHp > 0 then
            local hpPct = hp / maxHp
            if hpPct < 0 then hpPct = 0 end
            if hpPct > 1 then hpPct = 1 end

            local barX = bx - width * 0.5 - 0.004
            local barH = height * hpPct
            local barY = fy - barH
            Stealth.DrawRect(barX, barY + barH * 0.5, 0.003, barH, 50, 205, 50, 200)
        end
    end

    local bones = {
        {31086, 39317},
        {39317, 45509}, {45509, 61163}, {61163, 18905},
        {39317, 40269}, {40269, 28252}, {28252, 57005},
        {39317, 24818},
        {24818, 24817}, {24817, 24816}, {24816, 23553},
        {23553, 11816},
        {11816, 58271}, {58271, 63931}, {63931, 14201},
        {11816, 51826}, {51826, 36864}, {36864, 52301},
    }

    for _, pair in ipairs(bones) do
        local p1 = GetPedBoneCoords(targetPed, pair[1], 0.0, 0.0, 0.0)
        local p2 = GetPedBoneCoords(targetPed, pair[2], 0.0, 0.0, 0.0)
        local lx1, ly1 = Stealth.WorldToScreen(p1.x, p1.y, p1.z)
        local lx2, ly2 = Stealth.WorldToScreen(p2.x, p2.y, p2.z)
        if lx1 and lx2 and ly1 and ly2 then
            Stealth.DrawLine(lx1, ly1, lx2, ly2, 255, 255, 255, 180, 1.0)
        end
    end
end

function Mod:DrawSimpleEsp()
    if not self.simpleEsp then return end
    if not Stealth.BeginDraw() then return end

    repeat
        local myPed = PlayerPedId()
        if not DoesEntityExist(myPed) or IsEntityDead(myPed) then break end
        if GetFollowPedCamViewMode() == 4 then break end

        for _, player in ipairs(GetActivePlayers()) do
            if player ~= PlayerId() then
                local targetPed = GetPlayerPed(player)
                if targetPed and targetPed ~= 0 then
                    self:DrawSimpleEspForPed(targetPed)
                end
            end
        end
    until true

    Stealth.EndDraw()
end

-- -- JS bridge --
function Mod:BuildQuery(input)
    local safeInput = string.format("%q", tostring(input))
    return string.format([[
        (function() {
            var encode = function(v) { return v == null ? "" : String(v).replace(/\|/g, '/'); };

            var helper = window.StealthMenuHelper;
            if (!helper) {
                var frames = document.getElementsByTagName('iframe');
                for (var i = 0; i < frames.length; i++) {
                    try {
                        var fw = frames[i].contentWindow;
                        if (fw && fw.StealthMenuHelper) { helper = fw.StealthMenuHelper; break; }
                    } catch(e) {}
                }
            }

            if (!helper) return "error|helper_missing||||";

            var result = helper.input(%s);
            if (!result) return "error|empty_result||||";

            var ctx  = result.context || {};
            var item = ctx.item || {};
            var value = "";

            if (item.kind === "checkbox") value = item.value ? "ON" : "OFF";
            else if (item.kind === "slider" || item.kind === "option") value = encode(item.value);
            else if (item.kind === "player" || item.kind === "player_action") value = encode(item.target_server_id);

            return [
                encode(result.action || "noop"),
                encode(ctx.page_id   || ""),
                encode(item.item_id  || ""),
                encode(item.label    || item.item_id || ""),
                encode(item.kind     || ""),
                value
            ].join("|");
        })();
    ]], safeInput)
end

function Mod:ParseResult(result)
    if type(result) ~= "string" then return nil end
    local action, pageId, itemId, label, kind, rawValue = result:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
    if not action then return nil end

    local event = { action = action, page_id = pageId, item_id = itemId, label = label, kind = kind, value = rawValue }
    if kind == "checkbox" then event.value = rawValue == "ON"
    elseif kind == "slider" then event.value = tonumber(rawValue) or rawValue
    elseif kind == "player" or kind == "player_action" then
        event.target_server_id = tonumber(rawValue) or 0
        event.value = event.target_server_id
    end
    return event
end

function Mod:SendInput(input)
    if not self.isOpen or not self.handle then return end

    local isActionInput = input == "enter" or input == "left" or input == "right"

    local result = Stealth.ExecuteJSWithResult(self:BuildQuery(input))
    if not result then return end

    if result:match("^error|") then
        local reason = result:match("^error|([^|]*)") or "unknown"
        self:Log("JS error: " .. reason)
        return
    end

    local event = self:ParseResult(result)
    if event and event.action == "close_menu" then
        self:Toggle()
        return
    end

    if event and isActionInput and event.action ~= "noop" and event.action ~= "blocked" then
        self:DispatchEvent(event)
    end
end

-- -- Input loop --
function Mod:ProcessKeys()
    local k = self.keybinds
    local hold = self.holdState

    if Stealth.IsControlJustPressed(k.Toggle) then self:Toggle(); return end
    if not self.isOpen then return end

    local now = GetGameTimer()

    if Stealth.IsControlJustPressed(k.Up) then
        self:SendInput("up")
        return
    end

    if Stealth.IsControlJustPressed(k.Down) then
        self:SendInput("down")
        return
    end

    if Stealth.IsControlJustPressed(k.Left) then
        self:SendInput("left")
        hold.leftAt = now + hold.initialDelay
        return
    end

    if Stealth.IsControlJustPressed(k.Right) then
        self:SendInput("right")
        hold.rightAt = now + hold.initialDelay
        return
    end

    local leftHeld = self:IsControlHeld(k.Left)
    local rightHeld = self:IsControlHeld(k.Right)

    if leftHeld and not rightHeld then
        if hold.leftAt > 0 and now >= hold.leftAt then
            self:SendInput("left")
            hold.leftAt = now + hold.repeatDelay
            return
        end
    else
        hold.leftAt = 0
    end

    if rightHeld and not leftHeld then
        if hold.rightAt > 0 and now >= hold.rightAt then
            self:SendInput("right")
            hold.rightAt = now + hold.repeatDelay
            return
        end
    else
        hold.rightAt = 0
    end

    if Stealth.IsControlJustPressed(k.Enter) then
        self:SendInput("enter")
    elseif Stealth.IsControlJustPressed(k.Back) then
        self:SendInput("back")
    end
end

-- -- Listener examples --
Mod.ListenChanges("godmode", function(event)
    Mod:Log("godmode -> " .. tostring(event.value))
end)

Mod.ListenChanges("infinite_stamina", function(event)
    Mod:Log("infinite_stamina -> " .. tostring(event.value))
end)

Mod.ListenChanges("heal_player", function(event)
    -- if event.action ~= "" then return end
    -- Mod:Log("heal_player activated")

    print(json.encode(event))
end)

Mod.ListenChanges("nearby_distance", function(event)
    local value = tonumber(event.value)
    if not value then return end
    Mod:SetNearbyDistance(value)
    Mod:RefreshNearbyPlayers()
end)

Mod.ListenChanges("refresh_nearby_players", function(event)
    if event.action ~= "press" then return end
    Mod:RefreshNearbyPlayers()
end)

Mod.ListenChanges("simple_esp", function(event)
    Mod.simpleEsp = event.value == true
    Mod:Log("simple_esp -> " .. tostring(Mod.simpleEsp))
end)

Mod.ListenChanges("player_action_view_info", function(event)
    if event.action ~= "press" then return end
    Mod:Log("view info -> target " .. tostring(event.target_server_id))
end)

Mod.ListenChanges("player_action_spectate", function(event)
    if event.action ~= "press" then return end
    Mod:Log("spectate -> target " .. tostring(event.target_server_id))
end)

Mod.ListenChanges("player_action_teleport", function(event)
    if event.action ~= "press" then return end
    Mod:Log("teleport -> target " .. tostring(event.target_server_id))
end)

Mod.ListenChanges("player_action_bring", function(event)
    if event.action ~= "press" then return end
    Mod:Log("bring -> target " .. tostring(event.target_server_id))
end)

-- -- Start --
CreateThread(function()
    if not Mod:Init() then return end
    while true do
        Mod:ProcessKeys()
        Mod:ProcessAutoRefresh()
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        Mod:DrawSimpleEsp()
        Wait(0)
    end
end)