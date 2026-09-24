-- ==================================================
-- YOKUDO HUB | FEATURE | Manager Drone
-- គ្រប់គ្រង Event → ហៅ Attack ឬ AFK
-- ✅ Event ចេញ → Stop AFK → Jump Out → Call Attack
--    (AttackDrone គ្រប់គ្រង Fly TP ទៅ Safe Zone ខ្លួនឯង)
-- ✅ Event Sec <= 10 → Stop Attack → Call AFK
-- ✅ Stop ពេល Disable
-- ✅ Restart ពេល Character Added
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================
local EVENT_CHECK_INTERVAL = 1
local EVENT_STOP_ATTACK_THRESHOLD = 10
local SAFE_WAIT_TIME = 1
local SAFE_ZONE = Vector3.new(533, 70, -366)
local AFK_JUMP_WAIT = 0.5

-- ==================================================
-- STATE
-- ==================================================
local ManagerEnabled = false
local LastEventSec = 0
local LastEventText = ""
local LastEventActive = false
local ManagerThread = nil
local Switching = false

-- ==================================================
-- GET EVENT INFO (ROBUSTO)
-- ==================================================
local function ParseTimeSec(Text)
    if not Text or Text == "" then return nil end
    -- formato 1: "1m 30s" / "2m" / "45s"
    local M = tonumber(string.match(Text, "(%d+)%s*m")) or 0
    local S = tonumber(string.match(Text, "(%d+)%s*s")) or 0
    if M > 0 or S > 0 or string.find(Text, "m") or string.find(Text, "s") then
        return M * 60 + S
    end
    -- formato 2: "01:30" / "1:05"
    local mm, ss = string.match(Text, "(%d+):(%d+)")
    if mm and ss then
        return tonumber(mm) * 60 + tonumber(ss)
    end
    return nil
end

local function ReadTimerText(TimerObj)
    if not TimerObj then return nil end
    -- caso 1: TextLabel direto
    local ok, txt = pcall(function() return TimerObj.Text end)
    if ok and type(txt) == "string" and txt ~= "" then return txt end
    -- caso 2: tem filho .Value que pode ser StringValue ou GuiObject
    local ok2, val = pcall(function() return TimerObj:FindFirstChild("Value") end)
    if ok2 and val then
        if val:IsA("StringValue") or val:IsA("IntValue") then
            return tostring(val.Value)
        end
        local ok3, t2 = pcall(function() return val.Text end)
        if ok3 and type(t2) == "string" and t2 ~= "" then return t2 end
    end
    -- caso 3: o proprio .Value é string
    local ok4, v = pcall(function() return TimerObj.Value end)
    if ok4 and type(v) == "string" and v ~= "" then return v end
    return nil
end

local function GetEventInfo()
    local Text = nil

    -- tentativa 1: path original
    pcall(function()
        local Timer = game:GetService("Players").LocalPlayer.PlayerGui
            .HUD.GameHUD.BottomRight.ExperimentTimer
        Text = Text or ReadTimerText(Timer)
        if not Text then
            Text = tostring(Timer.Value.Text)
        end
    end)

    -- tentativa 2: varredura no BottomRight por qualquer label com "event"
    if not Text or Text == "" then
        pcall(function()
            local BR = game:GetService("Players").LocalPlayer.PlayerGui
                .HUD.GameHUD.BottomRight
            for _, d in ipairs(BR:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text ~= "" then
                    local low = string.lower(d.Text)
                    if string.find(low, "event") then
                        Text = d.Text
                        break
                    end
                end
            end
        end)
    end

    -- tentativa 3: varredura geral no PlayerGui
    if not Text or Text == "" then
        pcall(function()
            local PG = game:GetService("Players").LocalPlayer.PlayerGui
            for _, d in ipairs(PG:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text ~= "" then
                    local low = string.lower(d.Text)
                    if string.find(low, "event ends") or string.find(low, "event starts") then
                        Text = d.Text
                        break
                    end
                end
            end
        end)
    end

    if not Text or Text == "" then
        return 0, "", false
    end

    local low = string.lower(Text)
    -- ativo = "event ends" em qualquer caixa; "in Xm Ys" sozinho = esperando evento
    local IsEventActive = string.find(low, "event ends") ~= nil
    local Sec = ParseTimeSec(Text) or 0

    return Sec, Text, IsEventActive
end

-- ==================================================
-- FORCE STOP ALL FEATURES
-- ==================================================
local function ForceStopAll()
    print("[ManagerDrone] Force Stop All Features")

    if _G.YOKUDO_AttackDrone then
        pcall(function() _G.YOKUDO_AttackDrone.Stop() end)
    end
    if _G.YOKUDO_AFKSystem then
        pcall(function() _G.YOKUDO_AFKSystem.Disable() end)
    end
end

-- ==================================================
-- SWITCH FROM AFK TO ATTACK
-- Event ចេញ → Stop AFK → Jump Out → Call Attack
-- AttackDrone គ្រប់គ្រង Fly TP ទៅ Safe Zone ខ្លួនឯង
-- ==================================================
local function SwitchAFKToAttack()
    if Switching then return end
    if not ManagerEnabled then return end
    Switching = true
    print("[ManagerDrone] Event Detected → Switch AFK to Attack")

    -- 1. រក Treadmill Pos
    local TreadmillPos = nil
    if _G.YOKUDO_AFKSystem then
        TreadmillPos = _G.YOKUDO_AFKSystem.GetMyTreadmillPos()
    end

    if not TreadmillPos and _G.YOKUDO_AFKSystem then
        local _, Treadmill = _G.YOKUDO_AFKSystem.FindMyPlotAndTreadmill()
        if Treadmill then
            TreadmillPos = Treadmill.Position
        end
    end

    if not TreadmillPos then
        print("[ManagerDrone] No Treadmill → Stop AFK → Call Attack")
        if _G.YOKUDO_AFKSystem then
            _G.YOKUDO_AFKSystem.Disable()
        end
        task.wait(0.5)
        if ManagerEnabled and _G.YOKUDO_AttackDrone then
            _G.YOKUDO_AttackDrone.Start()
        end
        Switching = false
        return
    end

    -- 2. Jump ចេញពី Treadmill រហូតដល់ Dist > 5
    print("[ManagerDrone] Jumping out of Treadmill...")
    _G.YOKUDO_AFKSystem.JumpOutTreadmill(TreadmillPos, function()
        if not ManagerEnabled then Switching = false return end
        print("[ManagerDrone] ✅ Jumped out!")

        -- 3. Stop AFK (បិទ AFKEnabled → FlyTP របស់ AFKSystem ឈប់)
        if _G.YOKUDO_AFKSystem then
            _G.YOKUDO_AFKSystem.Disable()
        end

        task.wait(AFK_JUMP_WAIT)

        if not ManagerEnabled then Switching = false return end

        -- 4. ហៅ Attack Drone (AttackDrone គ្រប់គ្រង Fly TP ទៅ Safe Zone ខ្លួនឯង)
        print("[ManagerDrone] Call Attack Drone → Fly TP to Safe Zone → Spawn Loop")
        if _G.YOKUDO_AttackDrone then
            _G.YOKUDO_AttackDrone.Start()
        end
        Switching = false
    end)
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop()
    while ManagerEnabled do
        local EventSec, EventText, IsEventActive = GetEventInfo()

        local EventNotActive = not IsEventActive
        -- Sec==0 com evento ativo = parse falhou -> assume ativo (evita dead zone)
        local HasValidTimer = EventSec > 0
        local EventStopAttack = IsEventActive and HasValidTimer and EventSec <= EVENT_STOP_ATTACK_THRESHOLD
        local EventActive = IsEventActive and (not HasValidTimer or EventSec > EVENT_STOP_ATTACK_THRESHOLD)

        print("[ManagerDrone] Text:", EventText, "| Sec:", EventSec, "| IsActive:", IsEventActive, "| NotActive:", EventNotActive, "| StopAttack:", EventStopAttack, "| Active:", EventActive)

        -- ==================================================
        -- Event មិនទាន់ចេញ (Text = "in Xm Ys") → AFK System
        -- ==================================================
        if EventNotActive then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event Not Active → Stop Attack")
                _G.YOKUDO_AttackDrone.Stop()
            end

            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                print("[ManagerDrone] Event Not Active → AFK System")
                _G.YOKUDO_AFKSystem.Enable()
            end
        -- ==================================================
        -- Event ជិតចប់ (Sec <= 10) → Stop Attack → AFK
        -- ==================================================
        elseif EventStopAttack then
            if _G.YOKUDO_AttackDrone and _G.YOKUDO_AttackDrone.IsEnabled() then
                print("[ManagerDrone] Event <= 10s → Stop Attack → AFK System")
                _G.YOKUDO_AttackDrone.Stop()
            end

            if _G.YOKUDO_AFKSystem and not _G.YOKUDO_AFKSystem.IsEnabled() then
                _G.YOKUDO_AFKSystem.Enable()
            end
        -- ==================================================
        -- Event ចេញ (Sec > 10 ou Sec desconhecido) → Switch AFK → Attack
        -- ==================================================
        elseif EventActive then
            if not Switching then
                if _G.YOKUDO_AFKSystem and _G.YOKUDO_AFKSystem.IsEnabled() then
                    print("[ManagerDrone] Event Active → Switch AFK to Attack")
                    SwitchAFKToAttack()
                elseif _G.YOKUDO_AttackDrone and not _G.YOKUDO_AttackDrone.IsEnabled() then
                    print("[ManagerDrone] Event Active → Attack Drone")
                    _G.YOKUDO_AttackDrone.Start()
                end
            end
        end

        LastEventSec = EventSec
        LastEventText = EventText
        LastEventActive = IsEventActive
        task.wait(EVENT_CHECK_INTERVAL)
    end

    Switching = false
    ForceStopAll()
    print("[ManagerDrone] MainLoop Stopped")
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function EnableManager()
    if ManagerEnabled then return end
    ManagerEnabled = true

    if ManagerThread then
        pcall(function() task.cancel(ManagerThread) end)
        ManagerThread = nil
    end

    ManagerThread = task.spawn(function() MainLoop() end)

    print("[ManagerDrone] Manager Drone: ON")
end

local function DisableManager()
    if not ManagerEnabled then return end
    ManagerEnabled = false
    Switching = false

    if ManagerThread then
        pcall(function() task.cancel(ManagerThread) end)
        ManagerThread = nil
    end

    ForceStopAll()

    print("[ManagerDrone] Manager Drone: OFF")
end

local function ToggleManager()
    if ManagerEnabled then
        DisableManager()
    else
        EnableManager()
    end
end

-- ==================================================
-- AUTO RE-APPLY ON CHARACTER ADDED
-- ==================================================
Player.CharacterAdded:Connect(function(Char)
    if ManagerEnabled then
        print("[ManagerDrone] Character Added → Restarting Manager...")
        task.wait(1)

        LastEventSec = 0
        LastEventText = ""

        if ManagerThread then
            pcall(function() task.cancel(ManagerThread) end)
            ManagerThread = nil
        end

        ManagerThread = task.spawn(function() MainLoop() end)

        print("[ManagerDrone] ✅ Re-applied on new Character")
    end
end)

-- ==================================================
-- EXPORT
-- ==================================================
_G.YOKUDO_ManagerDrone = {
    Enable = EnableManager,
    Disable = DisableManager,
    Toggle = ToggleManager,
    IsEnabled = function() return ManagerEnabled end,
    GetEventInfo = GetEventInfo,
    GetLastEvent = function() return LastEventSec, LastEventText, LastEventActive end,
    IsSwitching = function() return Switching end,
    ForceStopAll = ForceStopAll,
    SwitchAFKToAttack = SwitchAFKToAttack,
}

print("✅ ManagerDrone Feature Loaded (Switch AFK to Attack)")
