-- -- Config --
local Mod = {
    handle = nil,
    isOpen = false,
    eventHandlers = {},
    debug = true,
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
        self:Log("Menu opened")
    else
        Stealth.HideDui(self.handle)
        self:Log("Menu closed")
    end
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

    if Stealth.IsControlJustPressed(k.Toggle) then self:Toggle(); return end
    if not self.isOpen then return end

    if     Stealth.IsControlJustPressed(k.Up)    then self:SendInput("up")
    elseif Stealth.IsControlJustPressed(k.Down)  then self:SendInput("down")
    elseif Stealth.IsControlJustPressed(k.Left)  then self:SendInput("left")
    elseif Stealth.IsControlJustPressed(k.Right) then self:SendInput("right")
    elseif Stealth.IsControlJustPressed(k.Enter) then self:SendInput("enter")
    elseif Stealth.IsControlJustPressed(k.Back)  then self:SendInput("back")
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

-- -- Start --
CreateThread(function()
    if not Mod:Init() then return end
    while true do
        Mod:ProcessKeys()
        Wait(0)
    end
end)