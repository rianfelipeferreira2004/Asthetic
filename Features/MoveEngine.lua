-- ==================================================
-- ASTHETIC HUB | CORE | MoveEngine (movimento anti-BAC)
--
-- POR QUE EXISTE: o anti-cheat do jogo (codes BAC-XXXX)
-- valida movimento no server. Fly a 350-1000 u/s com
-- BodyVelocity + snap de CFrame = flag quase certo
-- (foi o que gerou o bac-10515).
--
-- COMO FUNCIONA: igual aos scripts do genero que nao
-- caem — hum:Move() + AssemblyLinearVelocity direto,
-- 40-60 u/s, SEM criar instances no character, SEM
-- PlatformStand, SEM escrever CFrame. Pro server parece
-- um player andando rapido, nao um teleporte.
--
-- Go(Dest, Speed, Opts) ... viagem ate o ponto
--   Opts: ArriveDist, Timeout, ShouldStop, OnArrive(ok)
-- Hold(Pos, ShouldStop) .... hover parado via velocidade
-- StopAll() ................. para tudo
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

local MAX_SPEED = 60
local DEFAULT_SPEED = 40
local HOLD_KP = 8
local HOLD_MAX = 30
local CLIMB_MAX = 20

local TravelConn = nil
local HoldConn = nil

local function GetHR()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

local function StopTravel()
    if TravelConn then
        TravelConn:Disconnect()
        TravelConn = nil
    end
end

local function StopHold()
    if HoldConn then
        HoldConn:Disconnect()
        HoldConn = nil
    end
end

local MoveEngine = {}

-- ==================================================
-- GO: anda (voa baixo via velocidade) ate Dest
-- ==================================================
function MoveEngine.Go(Dest, Speed, Opts)
    Opts = Opts or {}
    StopTravel()
    StopHold()

    local Hum, Root = GetHR()
    if not Hum or not Root or Hum.Health <= 0 then
        if Opts.OnArrive then task.spawn(Opts.OnArrive, false) end
        return false
    end

    Speed = math.min(Speed or DEFAULT_SPEED, MAX_SPEED)
    local Arrive = Opts.ArriveDist or 4
    local Timeout = Opts.Timeout or 60
    local t0 = os.clock()

    TravelConn = RunService.Heartbeat:Connect(function()
        if Opts.ShouldStop and Opts.ShouldStop() then
            StopTravel()
            if Opts.OnArrive then task.spawn(Opts.OnArrive, false) end
            return
        end
        local H, R = GetHR()
        if not H or not R or H.Health <= 0 then
            StopTravel()
            if Opts.OnArrive then task.spawn(Opts.OnArrive, false) end
            return
        end

        local D = Dest - R.Position
        local Dist = D.Magnitude
        if Dist <= Arrive or os.clock() - t0 > Timeout then
            local Arrived = Dist <= Arrive
            StopTravel()
            -- zera o horizontal; deixa o Y p/ a gravidade
            -- assentar natural (parece legit)
            pcall(function()
                local V = R.AssemblyLinearVelocity
                R.AssemblyLinearVelocity = Vector3.new(0, math.min(V.Y, 0), 0)
            end)
            pcall(function() H:Move(Vector3.zero, false) end)
            if Opts.OnArrive then task.spawn(Opts.OnArrive, Arrived) end
            return
        end

        local Unit = D.Unit
        -- anda de verdade (animacao + estado Running legit)
        local Flat = Vector3.new(D.X, 0, D.Z)
        if Flat.Magnitude > 0.05 then
            pcall(function() H:Move(Flat.Unit, false) end)
        end
        -- subida limitada: foguete vertical tambem e flag
        local ClimbY = math.clamp(Unit.Y * Speed, -Speed, CLIMB_MAX)
        pcall(function()
            R.AssemblyLinearVelocity = Vector3.new(Unit.X * Speed, ClimbY, Unit.Z * Speed)
        end)
    end)

    return true
end

-- ==================================================
-- HOLD: fica parado num ponto (hover) sem CFrame lock.
-- CFrame pinado todo frame = micro-teleports; aqui um
-- controlador P de velocidade segura a posicao.
-- ==================================================
function MoveEngine.Hold(Pos, ShouldStop)
    StopTravel()
    StopHold()

    HoldConn = RunService.Heartbeat:Connect(function()
        if ShouldStop and ShouldStop() then
            StopHold()
            return
        end
        local H, R = GetHR()
        if not H or not R or H.Health <= 0 then
            StopHold()
            return
        end
        local Err = Pos - R.Position
        if Err.Magnitude < 1 then
            pcall(function()
                R.AssemblyLinearVelocity = Vector3.zero
                H:Move(Vector3.zero, false)
            end)
            return
        end
        local V = Err * HOLD_KP
        if V.Magnitude > HOLD_MAX then
            V = V.Unit * HOLD_MAX
        end
        pcall(function()
            R.AssemblyLinearVelocity = V
            H:Move(Vector3.zero, false)
        end)
    end)

    return function() StopHold() end
end

function MoveEngine.StopAll()
    StopTravel()
    StopHold()
end

function MoveEngine.IsMoving()
    return TravelConn ~= nil or HoldConn ~= nil
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.ASTHETIC_MoveEngine = MoveEngine

print("✅ MoveEngine Loaded (movimento legit anti-BAC)")
