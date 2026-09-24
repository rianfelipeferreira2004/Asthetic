-- ==================================================
-- ASTHETIC HUB | FEATURE | Bypass Anti Cheat V3 (stealth)
--
-- V2 ainda tomou kick. Endurecimento V3:
--  1. HealthRestore agora DEFAULT OFF. Qualquer escrita em
--     Health replica p/ o servidor; se o jogo valida dano
--     no server, restore = flag. Morte virou evento normal:
--     morre limpo -> respawna -> FarmingManager retoma
--     sozinho (hook de respawn ja existe).
--  2. Camadas independentes via SetFlags: HealthRestore,
--     StateShield, VoidRescue. Tudo desligavel sem editar.
--  3. Nomes dos movers? Este arquivo nao cria movers.
--     (Randomizacao feita nos arquivos de voo.)
-- Mantido: sem Destroy/Clone, sem inf, sem loop de escrita,
-- state Dead intacto (zumbi = kick), shield client-side.
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local VOID_Y = -200
local SAFE_ZONE = Vector3.new(533, 70, -366)
local RESTORE_COOLDOWN = 0.15

-- Defaults seguros: nada que escreva propriedade replicada
-- com valor contestavel liga sozinho.
local Flags = {
    HealthRestore = false,
    StateShield = true,
    VoidRescue = true,
}

local Enabled = false
local HealthConn = nil
local WatchThread = nil
local RespawnConn = nil
local HookedChar = nil

local LastGoodHealth = nil
local OrigMaxHealth = nil
local LastRestore = 0

-- ==================================================
-- HELPERS
-- ==================================================
local function GetHum()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

local function ApplyStateShield(Hum)
    if not Hum then return end
    pcall(function()
        Hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)
end

local function RemoveStateShield(Hum)
    if not Hum then return end
    pcall(function()
        Hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    end)
end

-- So executa se HealthRestore explicitamente ligado.
-- Nunca passa do MaxHealth original.
local function OnHealthChanged(NewHealth)
    if not Enabled or not Flags.HealthRestore then return end
    local Hum = GetHum()
    if not Hum or Hum.Health <= 0 then return end
    if type(NewHealth) ~= "number" then return end

    if LastGoodHealth and NewHealth < LastGoodHealth then
        if os.clock() - LastRestore >= RESTORE_COOLDOWN then
            LastRestore = os.clock()
            local Cap = OrigMaxHealth or Hum.MaxHealth
            local Target = math.min(LastGoodHealth, Cap)
            pcall(function()
                Hum.Health = Target
            end)
            return
        end
        return
    end
    LastGoodHealth = NewHealth
end

local function HookCharacter(Char)
    if not Char or HookedChar == Char then return end
    HookedChar = Char
    if HealthConn then pcall(function() HealthConn:Disconnect() end) HealthConn = nil end

    local Hum = Char:WaitForChild("Humanoid", 10)
    if not Hum then return end
    OrigMaxHealth = Hum.MaxHealth -- so leitura, nunca escrita
    LastGoodHealth = Hum.Health
    if Flags.StateShield then
        ApplyStateShield(Hum)
    end
    HealthConn = Hum.HealthChanged:Connect(OnHealthChanged)
end

local function StartWatch()
    if WatchThread then return end
    WatchThread = task.spawn(function()
        while Enabled do
            task.wait(0.25)
            if not Enabled then break end
            if Flags.VoidRescue then
                local _, Root = GetHum()
                if Root and Root.Position.Y < VOID_Y then
                    pcall(function()
                        Root.CFrame = CFrame.new(SAFE_ZONE)
                        Root.AssemblyLinearVelocity = Vector3.zero
                        Root.AssemblyAngularVelocity = Vector3.zero
                    end)
                    print("[Bypass] Void rescue -> Safe Zone")
                end
            end
        end
        WatchThread = nil
    end)
end

-- ==================================================
-- ENABLE / DISABLE / FLAGS
-- ==================================================
local function Enable()
    if Enabled then return end
    Enabled = true
    LastRestore = 0
    if Player.Character then
        task.spawn(HookCharacter, Player.Character)
    end
    if not RespawnConn then
        RespawnConn = Player.CharacterAdded:Connect(function(Char)
            HookedChar = nil
            if Enabled then
                task.wait(1)
                HookCharacter(Char)
            end
        end)
    end
    StartWatch()
    print("[Bypass] Shield ON (restore=" .. tostring(Flags.HealthRestore)
        .. " shield=" .. tostring(Flags.StateShield)
        .. " void=" .. tostring(Flags.VoidRescue) .. ")")
end

local function Disable()
    if not Enabled then return end
    Enabled = false
    if HealthConn then pcall(function() HealthConn:Disconnect() end) HealthConn = nil end
    local Hum = GetHum()
    RemoveStateShield(Hum)
    HookedChar = nil
    print("[Bypass] Shield OFF")
end

-- Uso no console do executor:
--   _G.ASTHETIC_BypassAntiCheat.SetFlags({HealthRestore = true})
local function SetFlags(NewFlags)
    if type(NewFlags) ~= "table" then return Flags end
    for K, V in pairs(NewFlags) do
        if Flags[K] ~= nil and type(V) == "boolean" then
            Flags[K] = V
        end
    end
    -- aplica shield imediatamente se ja ligado
    local Hum = GetHum()
    if Enabled and Hum then
        if Flags.StateShield then ApplyStateShield(Hum) else RemoveStateShield(Hum) end
    end
    print("[Bypass] Flags: restore=" .. tostring(Flags.HealthRestore)
        .. " shield=" .. tostring(Flags.StateShield)
        .. " void=" .. tostring(Flags.VoidRescue))
    return GetFlags()
end

local function GetFlags()
    return {
        HealthRestore = Flags.HealthRestore,
        StateShield = Flags.StateShield,
        VoidRescue = Flags.VoidRescue,
    }
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.ASTHETIC_BypassAntiCheat = {
    Enable = Enable,
    Disable = Disable,
    IsEnabled = function() return Enabled end,
    SetFlags = SetFlags,
    GetFlags = GetFlags,
}

task.spawn(function()
    task.wait(2)
    if not Enabled then
        pcall(Enable)
    end
end)

print("✅ BypassAntiCheat V3 Loaded (stealth, restore OFF por padrao)")
