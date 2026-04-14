---
description: "Use when editing the Stealth menu example (Lua + HTML/JS). Keep code beginner-friendly, keyboard-first, and compatible with isolated Stealth API workflows."
name: "Stealth Menu Example Rules"
applyTo: "**/*"
---
# Stealth Menu Example Rules

- Keep it simple: this project is example code for menu developers, so prefer clear, minimal logic over complex abstractions.
- Keep controls keyboard-first unless explicitly requested otherwise:
  - Arrow Up/Down: move selection
  - Arrow Left/Right: adjust slider or option value
  - Enter: confirm selected item
  - Backspace: go back
- Do not add mouse-driven behavior. Treat this as a hard rule unless the user explicitly asks to change it.
- Do not rely on native FiveM NUI event patterns for this example (no browser-to-Lua event posting assumptions).
- For Lua to JS communication, prefer query-style helpers via `Stealth.ExecuteJSWithResult` and return structured result objects.
- For DUI and browser control, use Stealth API methods (`Stealth.CreateDui`, `Stealth.ShowDui`, `Stealth.HideDui`, `Stealth.ExecuteJSWithResult`, etc.) instead of native FiveM DUI/NUI wiring.
- When updating menu logic, preserve or extend `window.StealthMenuHelper` behavior so Lua can ask for input handling and current selection context.
- Prefer `Stealth.IsControlJustPressed` for single-action key handling in menu loops.
- Keep lightweight notifications/debug output in example Lua flows when helpful for teaching and understanding behavior.
