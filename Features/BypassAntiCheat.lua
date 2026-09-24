-- ==================================================
-- ASTHETIC HUB | FEATURE | Bypass Anti Cheat V2 (stealth)
--
-- POR QUE A V1 TOMAVA KICK (diagnostico senior):
--  1. OldHumanoid:Destroy() no client REPLICA pro servidor.
--     O server via o humanoid sumir + um clone desconhecido
--     aparecer no character = tampering na cara = kick.
--  2. MaxHealth/Health = math.huge REPLICA pro servidor.
--     Qualquer sanity check do jogo (vida acima do maximo
--     possivel) = kick instantaneo.
--  3. Loop a cada 0.1s + Heartbeat escrevendo Health/MaxHealth
--     = spam de replicacao com assinatura obvia de cheat.
--  4. Auto-rodava o replace 2s apos o load: todo mundo tomava
--     kick sozinho, sem apertar nada.
--
-- V2: NADA com valor impossivel chega ao servidor.
--  - Sem Destroy/Clone: humanoid original intacto.
--  - Sem inf: restore limitado ao MaxHealth ORIGINAL.
--  - Sem loop de escrita: so reage a dano (event-driven,
--    com throttle de 0.15s).
--  - Morte real (0 de vida) NAO e bloqueada: deixa morrer
--    limpo p/ respawnar (FarmingManager retoma sozinho).
--    Travar o estado Dead local gerava "zumbi" que o server
--    ja matou = outro motivo classico de kick.
--  - State shield e client-side (nao replica): anti-ragdoll
--    do tapa do guarda.
--  - Void rescue: salva antes do kill-plane.
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

local VOID_Y = -200
local SAFE_ZONE = Vector3.new(533, 70, -366)
local RESTORE_COOLDOWN = 0.15

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

-- Shield client-side (nao replica): segura o ragdoll do guard
-- sem tocar em nada que o servidor valide.
local function ApplyStateShield(Hum)
    if not Hum then return end
    pcall(function()
        Hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
    end)
    -- NOTA: estado Dead propositalmente INTACTO (ver cabecalho).
end

local function RemoveStateShield(Hum)
    if not Hum then return end
    pcall(function()
        Hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
    end)
end

-- ==================================================
-- RESTORE CAPPED: so cobre DANO, nunca passa do max
-- original. Cura do jogo continua funcionando (sobe o
-- baseline em vez de ser sobrescrita).
-- ==================================================
local function OnHealthChanged(NewHealth)
    if not Enabled then return end
    local Hum = GetHum()
    if not Hum or Hum.Health <= 0 then return end -- morte real: respawn limpo
    if type(NewHealth) ~= "number" then return end

    if LastGoodHealth and NewHealth < LastGoodHealth then
        if os.clock() - LastRestore >= RESTORE_COOLDOWN then
            LastRestore = os.clock()
            local Cap = OrigMaxHealth or Hum.MaxHealth
            local Target = math.min(LastGoodHealth, Cap)
            pcall(function()
                Hum.Health = Target
            end)
            return -- nao atualiza baseline: proximo dano compara com o valor pre-dano
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
    -- guarda o max ORIGINAL e nunca escreve nele (escrever = kick)
    OrigMaxHealth = Hum.MaxHealth
    LastGoodHealth = Hum.Health
    ApplyStateShield(Hum)
    HealthConn = Hum.HealthChanged:Connect(OnHealthChanged)
end

-- ==================================================
-- VOID RESCUE (0.25s, barato)
-- ==================================================
local function StartWatch()
    if WatchThread then return end
    WatchThread = task.spawn(function()
        while Enabled do
            task.wait(0.25)
            if not Enabled then break end
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
        WatchThread = nil
    end)
end

-- ==================================================
-- ENABLE / DISABLE
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
    print("[Bypass] Shield ON (stealth, sem replace, sem inf)")
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

-- ==================================================
-- EXPORT
-- ==================================================
_G.ASTHETIC_BypassAntiCheat = {
    Enable = Enable,
    Disable = Disable,
    IsEnabled = function() return Enabled end,
}

-- Auto-liga o shield passivo (seguro: nenhuma escrita
-- replicada com valor impossivel). O replace assassino
-- da V1 foi removido — nao existe mais auto-kick no load.
task.spawn(function()
    task.wait(2)
    if not Enabled then
        pcall(Enable)
    end
end)

print("✅ BypassAntiCheat V2 Loaded (stealth: capped restore + state shield + void rescue)")
