-- Tracking --
local Mod = {
    Handle = Stealth.CreateDui("http://localhost:3000"),
    isOpen = false,
    Keybinds = {
        MenuOpen = VK_F2,
        ArrowKeys = {
            Up = VK_UP,
            Down = VK_DOWN,
            Left = VK_LEFT,
            Right = VK_RIGHT
        }
    }
}

-- Functionality --

function Mod:ToggleMenu()
    self.isOpen = not self.isOpen;
    if self.isOpen then
        Stealth.ShowDui(
            self.Handle
        )
    else
        Stealth.HideDui(
            self.Handle
        )
    end
end

function Mod:sendMessage(content, bypassOpenCheck)
    if not bypassOpenCheck and not self.isOpen then return end

    if self.isOpen or bypassOpenCheck then
        Stealth.SendDuiMessage(
            self.Handle,
            content
        )
    end
end

-- Keybinds --
CreateThread(function()
    while true do
        if Stealth.IsControlPressed(Mod.Keybinds.MenuOpen) then
            Mod:ToggleMenu()
        elseif Stealth.IsControlPressed(Mod.Keybinds.ArrowKeys.Up) then
            Mod:sendMessage({
                navigate = "up"
            })
        elseif Stealth.IsControlPressed(Mod.Keybinds.ArrowKeys.Down) then
            Mod:sendMessage({
                navigate = "down"
            })
        elseif Stealth.IsControlPressed(Mod.Keybinds.ArrowKeys.Left) then
            Mod:sendMessage({
                navigate = "left"
            })
        elseif Stealth.IsControlPressed(Mod.Keybinds.ArrowKeys.Right) then
            Mod:sendMessage({
                navigate = "right"
            })
        end
        Wait(0)
    end
end)
