-- ==================================================
-- ASTHETIC HUB | FEATURE | God Mode (safe, delega p/ Bypass V2)
--
-- A versao antiga fazia Humanoid replace + Health = inf,
-- que replica pro servidor e toma kick (mesma causa do
-- Bypass V1). Agora delega pro shield stealth do
-- BypassAntiCheat V2: restore limitado ao MaxHealth
-- original + anti-ragdoll client-side + void rescue.
-- API mantida 1:1 p/ a aba Setting continuar funcionando.
-- ==================================================

local GodModeEnabled = false

local function GetBypass()
    return _G.ASTHETIC_BypassAntiCheat
end

local function EnableGodMode()
    if GodModeEnabled then return end
    GodModeEnabled = true
    local B = GetBypass()
    if B then
        pcall(function() B.Enable() end)
    else
        warn("[GodMode] BypassAntiCheat ainda nao carregou (Loader o carrega por ultimo, aguarde o hub abrir)")
    end
    print("[ASTHETIC] God Mode: ON (safe)")
end

local function DisableGodMode()
    if not GodModeEnabled then return end
    GodModeEnabled = false
    local B = GetBypass()
    if B then
        pcall(function() B.Disable() end)
    end
    print("[ASTHETIC] God Mode: OFF")
end

local function ToggleGodMode()
    if GodModeEnabled then
        DisableGodMode()
    else
        EnableGodMode()
    end
end

-- ==================================================
-- EXPORT (mesma API de antes)
-- ==================================================
_G.ASTHETIC_GodMode = {
    Toggle = ToggleGodMode,
    Enable = EnableGodMode,
    Disable = DisableGodMode,
    IsEnabled = function() return GodModeEnabled end
}

print("✅ GodMode Feature Loaded (safe, via Bypass V2)")
