local src = Stealth.FetchContent("http://localhost:3000/menu")
if not src then
    Stealth.AddNotification("Failed to fetch Neuro.", Stealth.NOTIFY_ERROR)
    return
end

local fn, err = load(src)
if not fn then
    Stealth.AddNotification("Failed to load Neuro: " .. tostring(err), Stealth.NOTIFY_ERROR)
    return
end

fn()
Stealth.AddNotification("Neuro has loaded!", Stealth.NOTIFY_SUCCESS)