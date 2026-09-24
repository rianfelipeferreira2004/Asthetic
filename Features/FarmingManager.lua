-- ==================================================
-- ASTHETIC HUB | FEATURE | Farming Manager V2
-- Rewrite senior: EggCheck + Day/Night + AFK + VIPTP
--
-- O QUE MUDOU EM RELACAO A V1 (bugs reais corrigidos):
--  1. Scan com CACHE por UID. V1 fazia GetDescendants() +
--     require() em TODOS os ovos a cada 0.05s (20x/s).
--     Isso lagava o executor e derrubava FPS no mobile.
--     V2 resolve a categoria uma vez por UID e depois o
--     scan vira leitura de tabela (barato).
--  2. Single-driver. V1 tinha DOIS pilotos: o Day/NightLoop
--     parado em "while WaitingForVIPTP" + a cadeia que o
--     OnVIPTPComplete spawnava (FlyToSafe + StartVIPTP).
--     Os dois podiam mandar StartVIPTP juntos (double-run).
--     V2: OnVIPTPComplete so sinaliza; quem decide o
--     proximo passo e sempre o loop principal.
--  3. StopAll era async com race: mandava JumpOut (10s de
--     jumps) e 0.5s depois ja voava p/ SafeZone enquanto o
--     AFK DistCheck ainda puxava de volta p/ esteira
--     (teleport fight). V2 espera o JumpOut terminar
--     (com timeout) ANTES de voar.
--  4. Re-valida o ovo antes do VIPTP. V1 guardava o UID a
--     noite e atirava VIPTP de dia sem checar se o ovo
--     sumiu (pego por outro player). V2 re-escaneia.
--  5. RunId: Disable() invalida loops/callbacks pendentes.
--     V1 deixava thread fantasma voar p/ SafeZone mesmo
--     depois de desligar.
--  6. Anti-kick real (VirtualUser.Idled). O AntiAFK antigo
--     (mouse/camera) NAO impede kick do Roblox; sem isso
--     farm AFK de horas morre em ~20min.
--  7. VIPTP wait com timeout (120s). V1 esperava pra sempre
--     se o VIPTP travasse -> char parado na safe zone.
--  8. Rate real ($/s com scale+mutacoes) no sort, igual ao
--     AutoFarm manual. V1 usava EarningRate base.
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Player = Players.LocalPlayer

-- nomes de sessao p/ os movers (veja Bypass V3)
local MOVER_BV = "Mover" .. tostring(math.random(100000, 999999))
local MOVER_BG = "Gyro" .. tostring(math.random(100000, 999999))

-- ==================================================
-- AREA EGG CYCLE (fase Dia/Noite do jogo)
-- ==================================================
local AreaEggCycle = nil
pcall(function()
    AreaEggCycle = require(ReplicatedStorage.Shared.Util.AreaEggCycle)
end)
if not AreaEggCycle then
    warn("[FarmingManager] AreaEggCycle nao encontrado! Usando fallback do HUD.")
end

-- ==================================================
-- SETTINGS
-- ==================================================
local NIGHT_CHECK_INTERVAL = 0.05
local DAY_CHECK_INTERVAL = 0.5
local SAFE_ZONE = Vector3.new(533, 70, -366)
local SAFE_ZONE_DIST = 5
local SAFE_WAIT_AFTER_REACH = 1
local FLY_SPEED = 1000
local SAFE_FLY_SPEED = 500
local RETURN_SPEED = 800
local FLY_OFFSET = 15
local METHOD = "InstantTeleport"

local VIPTP_TIMEOUT = 120 -- se o VIPTP nao completar, volta a escanear
local JUMPOUT_TIMEOUT = 6 -- espera o JumpOut no maximo isso (s)

-- ==================================================
-- RARITY (tudo normalizado p/ minusculo)
-- ==================================================
local SelectedRarities = { divine = true, eternal = true, secret = true, mythical = true, cosmic = true }

local RARITY_PRIORITY = {
    divine = 1,
    eternal = 2,
    secret = 3,
    mythical = 4,
    cosmic = 5,
}

local function norm(s)
    if type(s) ~= "string" then return nil end
    return string.lower(s)
end

-- ==================================================
-- CACHE: MeshId -> categoria (resolve 1x, nao por scan)
-- ==================================================
local MeshIdMap = {}
local MeshIdMapBuilt = false

local function BuildMeshIdMap()
    if MeshIdMapBuilt then return end
    local Data = ReplicatedStorage:FindFirstChild("Data")
    local Configs = Data and Data:FindFirstChild("Assets")
    Configs = Configs and Configs:FindFirstChild("Configs")
    local EggModels = ReplicatedStorage:FindFirstChild("Assets")
    EggModels = EggModels and EggModels:FindFirstChild("Models")
    EggModels = EggModels and EggModels:FindFirstChild("Eggs")
    if not Configs or not EggModels then return end

    local Count = 0
    for _, Config in ipairs(Configs:GetChildren()) do
        local ok, Module = pcall(require, Config)
        if ok and Module and Module.Egg then
            local ModelName = Module.Egg.ModelName or Config.Name
            local Template = EggModels:FindFirstChild(ModelName)
            if Template then
                for _, Desc in ipairs(Template:GetDescendants()) do
                    if (Desc:IsA("MeshPart") or Desc:IsA("SpecialMesh")) and Desc.MeshId ~= "" then
                        MeshIdMap[Desc.MeshId] = Config.Name
                        Count = Count + 1
                    end
                end
            end
        end
    end
    MeshIdMapBuilt = true
    print("[FarmingManager] MeshId Map: " .. tostring(Count) .. " meshes")
end

-- ==================================================
-- CACHE: categoria -> dados do pet (resolve 1x)
-- ==================================================
local PetCache = {} -- [category] = { RarityRaw, RarityNorm, DisplayName, BaseRate }

local function ExtractRarity(Module)
    local R = Module.Rarity
    if type(R) == "string" then return R end
    if type(R) == "table" then
        return R._id or R.RarityId or R.Name
    end
    return nil
end

local function GetPetCached(Category)
    local Hit = PetCache[Category]
    if Hit then return Hit end
    local Data = ReplicatedStorage:FindFirstChild("Data")
    local Configs = Data and Data:FindFirstChild("Assets")
    Configs = Configs and Configs:FindFirstChild("Configs")
    if not Configs then return nil end
    local Config = Configs:FindFirstChild(Category)
    if not Config then return nil end
    local ok, Module = pcall(require, Config)
    if not ok or not Module then return nil end
    local Raw = ExtractRarity(Module)
    local Entry = {
        RarityRaw = Raw,
        RarityNorm = norm(Raw),
        DisplayName = Module.DisplayName or Category,
        BaseRate = Module.EarningRate or 0,
    }
    PetCache[Category] = Entry
    return Entry
end

-- Mutacoes: require uma vez, nao por ovo por scan
local MutationsMod = nil
local MutationsTried = false
local function GetMutationMult(Mutations)
    if not Mutations or #Mutations == 0 then return 1 end
    if not MutationsTried then
        MutationsTried = true
        pcall(function()
            MutationsMod = require(ReplicatedStorage.Shared.Modules.Mutations)
        end)
    end
    if MutationsMod then
        local ok, Mult = pcall(MutationsMod.EarningsFor, Mutations)
        if ok and type(Mult) == "number" then return Mult end
    end
    return 1
end

-- Taxa real $/s (mesma formula do AutoFarm manual)
local function RealRate(BaseRate, Scale, Mutations)
    Scale = Scale or 1
    local Payout
    if Scale <= 5 then
        Payout = Scale ^ 1.85
    else
        Payout = (Scale / 5) ^ 1.2 * 19.637875755794113
    end
    return math.round(BaseRate * Payout * GetMutationMult(Mutations))
end

-- ==================================================
-- CACHE: UID -> categoria (resolve 1x por ovo)
-- UIDs somem do container quando coletados, entao o
-- ChildRemoved invalida a entrada (evita memoria infinita)
-- ==================================================
local UidCategory = {} -- [uid] = category | false (false = Unknown, nao tenta de novo por 30s)
local UidUnknownAt = {} -- [uid] = os.clock() do ultimo "unknown"

local function DeepResolveCategory(Slot)
    if not MeshIdMapBuilt then BuildMeshIdMap() end
    for _, Desc in ipairs(Slot:GetDescendants()) do
        if (Desc:IsA("MeshPart") or Desc:IsA("SpecialMesh")) and Desc.MeshId ~= "" then
            local Cat = MeshIdMap[Desc.MeshId]
            if Cat then return Cat end
        end
    end
    return nil
end

local function GetContainer()
    return Workspace:FindFirstChild("AreaEggSlotsClient")
end

local function UidLocation(Uid)
    local C = GetContainer()
    if C and C:FindFirstChild(Uid) then return "container" end
    if Workspace:FindFirstChild(Uid) then return "workspace" end
    return nil
end

-- diagnostico do ultimo scan
local LastScan = { total = 0, categorized = 0, matched = 0, note = "" }
local LastFoundName = "none"
local LastNoEggLog = 0

local function FindBestEgg()
    local Container = GetContainer()
    if not Container then
        LastScan = { total = 0, categorized = 0, matched = 0, note = "sem container AreaEggSlotsClient" }
        return nil
    end

    local Best = nil
    local BestScore = nil
    local total, categorized = 0, 0
    local matched = 0

    for _, Slot in ipairs(Container:GetChildren()) do
        if Slot:IsA("Model") then
            total = total + 1
            local Uid = Slot.Name
            local Category = UidCategory[Uid]

            if Category == nil then
                -- resolve 1x por UID (pcall: modelo quebrado nao pode matar o scan)
                local ok, Cat = pcall(DeepResolveCategory, Slot)
                if ok and Cat then
                    Category = Cat
                    UidCategory[Uid] = Cat
                else
                    UidCategory[Uid] = false
                    UidUnknownAt[Uid] = os.clock()
                    Category = false
                end
            elseif Category == false then
                -- tenta de novo a cada 30s (jogo pode ter atualizado o MeshIdMap)
                if os.clock() - (UidUnknownAt[Uid] or 0) > 30 then
                    UidCategory[Uid] = nil
                end
            end

            if Category and Category ~= false then
                categorized = categorized + 1
                local Pet = GetPetCached(Category)
                if Pet and Pet.RarityNorm and SelectedRarities[Pet.RarityNorm] then
                    matched = matched + 1
                    local Scale = Slot:GetAttribute("AssetScale") or 1
                    local Mutations = Slot:GetAttribute("Mutations") or {}
                    local Rate = RealRate(Pet.BaseRate, Scale, Mutations)
                    local Prio = RARITY_PRIORITY[Pet.RarityNorm] or 999
                    -- score unico: prioridade manda, dentro da mesma raridade ganha o $/s
                    local Score = Prio * 1e15 - Rate
                    if not BestScore or Score < BestScore then
                        BestScore = Score
                        Best = {
                            Slot = Slot,
                            Uid = Uid,
                            Rarity = Pet.RarityRaw,
                            RarityNorm = Pet.RarityNorm,
                            EarningRate = Rate,
                            DisplayName = Pet.DisplayName,
                        }
                    end
                end
            end
        end
    end

    LastScan = { total = total, categorized = categorized, matched = matched, note = "" }
    if Best then
        LastFoundName = Best.DisplayName .. " (" .. tostring(Best.Rarity) .. " $" .. tostring(Best.EarningRate) .. "/s)"
    end
    return Best
end

local function InvalidateUid(_, Child)
    -- ChildRemoved: limpa cache do UID (ovo coletado / despawnado)
    if Child and Child.Name then
        UidCategory[Child.Name] = nil
        UidUnknownAt[Child.Name] = nil
    end
end

local function SetRarities(List)
    SelectedRarities = {}
    for _, r in ipairs(List) do
        local rn = norm(r)
        if rn then SelectedRarities[rn] = true end
    end
    print("[FarmingManager] Rarities: " .. table.concat(List, ", "))
end

local function LogNoEgg(prefix)
    if os.clock() - LastNoEggLog < 5 then return end
    LastNoEggLog = os.clock()
    print(prefix .. " sem ovo p/ farm | slots=" .. tostring(LastScan.total)
        .. " reconhecidos=" .. tostring(LastScan.categorized)
        .. " na-raridade=" .. tostring(LastScan.matched)
        .. (LastScan.note ~= "" and (" (" .. LastScan.note .. ")") or ""))
    if LastScan.total > 0 and LastScan.matched == 0 then
        print("[FarmingManager] DICA: rode _G.ASTHETIC_FarmingManager.DebugScan() e me mande o resultado")
    end
end

-- ==================================================
-- STATE (RunId invalida threads/callbacks velhos)
-- ==================================================
local FarmingEnabled = false
local RunId = 0
local CurrentState = "IDLE"
local CurrentPhase = "UNKNOWN"
local FarmingThread = nil
local AFKStarted = false
local WaitingForVIPTP = false
local VIPTPStartTime = 0
local CurrentTargetUid = nil

local Stats = { Collected = 0, VIPTPFails = 0, StartedAt = 0, LastFound = "none" }

local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil

-- ==================================================
-- HUMANOID / FLY
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    return Char:FindFirstChildOfClass("Humanoid"), Char:FindFirstChild("HumanoidRootPart")
end

local function CleanupFly()
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    if BodyVelocity then
        pcall(function() BodyVelocity.Velocity = Vector3.zero BodyVelocity.MaxForce = Vector3.zero end)
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    if BodyGyro then
        pcall(function() BodyGyro.MaxTorque = Vector3.zero end)
        BodyGyro:Destroy()
        BodyGyro = nil
    end
    local Hum, Root = GetHumanoid()
    if Hum then pcall(function() Hum.PlatformStand = false Hum.Sit = false end) end
    if Root then
        pcall(function()
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function SelfFlyTP(Destination, Speed, MyRun)
    CleanupFly()
    -- stealth: cap de velocidade (snap/voo absurdo = movement check)
    if _G.ASTHETIC_Stealth ~= false then
        Speed = math.min(Speed, 350)
    end
    local Hum, Root = GetHumanoid()
    if not Hum or not Root or Hum.Health <= 0 then return false end
    Hum.PlatformStand = true

    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Name = MOVER_BV
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = 1250
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.Parent = Root

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.Name = MOVER_BG
    BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    BodyGyro.P = 3000
    BodyGyro.D = 500
    BodyGyro.CFrame = Root.CFrame
    BodyGyro.Parent = Root

    local StartTime = os.clock()
    local Done = false
    FlyConnection = RunService.Heartbeat:Connect(function()
        if not FarmingEnabled or MyRun ~= RunId then CleanupFly() return end
        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 or Hum2.Health <= 0 or not BodyVelocity or not BodyGyro then
            CleanupFly() return
        end
        local CurrentPos = Root2.Position
        local Direction = Destination - CurrentPos
        if Direction.Magnitude <= 3 or os.clock() - StartTime > 30 then
            CleanupFly()
            if Direction.Magnitude <= 3 then
                pcall(function()
                    Root2.CFrame = CFrame.new(Destination)
                    Root2.AssemblyLinearVelocity = Vector3.zero
                    Root2.AssemblyAngularVelocity = Vector3.zero
                end)
                Done = true
            end
            return
        end
        BodyVelocity.Velocity = Direction.Unit * Speed
        BodyGyro.CFrame = CFrame.new(CurrentPos, Destination)
    end)
    return true
end

-- ==================================================
-- FASE DIA/NOITE
-- ==================================================
local function GetPhase()
    if AreaEggCycle then
        local ok, IsNight = pcall(AreaEggCycle.IsNightPhase, Workspace:GetServerTimeNow())
        if ok then
            return IsNight and "Night" or "Day"
        end
    end
    local ok, Text = pcall(function()
        return Player.PlayerGui.HUD.GameHUD.BottomRight.NightTimer.Value.Text
    end)
    if ok and type(Text) == "string" then
        local M = tonumber(string.match(Text, "(%d+)m")) or 0
        local S = tonumber(string.match(Text, "(%d+)s")) or 0
        if (M * 60 + S) > 10 then return "Day" else return "Night" end
    end
    return "UNKNOWN"
end

-- ==================================================
-- COORDENACAO AFK <-> VIPTP
-- ==================================================
local function EnsureAFK()
    if not FarmingEnabled then return end
    local AFK = _G.ASTHETIC_AFKSystem
    if not AFK then return end
    if AFK.IsEnabled() then AFKStarted = true return end
    -- nunca liga o AFK no meio de um VIPTP (teleport fight)
    local VIPTP = _G.ASTHETIC_VIPTP
    if VIPTP and VIPTP.IsEnabled() then return end
    AFK.Enable()
    AFKStarted = true
end

-- Para o AFK e espera sair da esteira ANTES de voar.
-- (V1 voava 0.5s depois enquanto o DistCheck puxava de volta.)
local function StopAFKSync()
    local AFK = _G.ASTHETIC_AFKSystem
    if not AFK or not AFK.IsEnabled() then AFKStarted = false return end
    local TreadmillPos = AFK.GetMyTreadmillPos()
    if not TreadmillPos then
        local _, Treadmill = AFK.FindMyPlotAndTreadmill()
        if Treadmill then TreadmillPos = Treadmill.Position end
    end
    if TreadmillPos then
        local done = false
        AFK.JumpOutTreadmill(TreadmillPos, function() done = true end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < JUMPOUT_TIMEOUT do
            if not FarmingEnabled then break end
            task.wait(0.1)
        end
    end
    AFK.Disable()
    AFKStarted = false
end

local function StopFlightSystems()
    StopAFKSync()
    local VIPTP = _G.ASTHETIC_VIPTP
    if VIPTP and VIPTP.IsEnabled() then VIPTP.Disable() print("[FarmingManager] VIPTP parado") end
    local TS = _G.ASTHETIC_TeleportSystem
    if TS and TS.IsEnabled() then TS.Disable() print("[FarmingManager] TeleportSystem parado") end
    CleanupFly()
end

-- ==================================================
-- SAFE ZONE (retorna true/false; V1 ignorava falha)
-- ==================================================
local function FlyToSafeZoneAndWait(MyRun)
    local _, Root = GetHumanoid()
    if not Root then return false end
    if (Root.Position - SAFE_ZONE).Magnitude <= SAFE_ZONE_DIST then return true end
    if not SelfFlyTP(SAFE_ZONE, SAFE_FLY_SPEED, MyRun) then return false end
    local t0 = os.clock()
    while FarmingEnabled and MyRun == RunId and os.clock() - t0 < 12 do
        local _, Root2 = GetHumanoid()
        if Root2 and (Root2.Position - SAFE_ZONE).Magnitude <= SAFE_ZONE_DIST then
            return true
        end
        task.wait(0.1)
    end
    return false
end

-- ==================================================
-- VIPTP (com re-validacao + timeout; single-driver:
-- o callback so sinaliza, o loop decide o proximo passo)
-- ==================================================
local function StartVIPTP(Uid, MyRun)
    local VIPTP = _G.ASTHETIC_VIPTP
    if not VIPTP then warn("[FarmingManager] VIPTP nao carregado!") return false end
    if not UidLocation(Uid) then return false end -- ovo sumiu na espera
    WaitingForVIPTP = true
    VIPTPStartTime = os.clock()
    CurrentTargetUid = Uid
    CurrentState = "VIPTP_RUN"
    print("[FarmingManager] VIPTP -> " .. tostring(Uid))
    VIPTP.SetTargetId(Uid)
    VIPTP.Enable()
    return true
end

local function WaitVIPTP(MyRun)
    while FarmingEnabled and MyRun == RunId and WaitingForVIPTP do
        if os.clock() - VIPTPStartTime > VIPTP_TIMEOUT then
            warn("[FarmingManager] VIPTP timeout (" .. VIPTP_TIMEOUT .. "s), abortando e re-escaneando")
            local VIPTP = _G.ASTHETIC_VIPTP
            if VIPTP and VIPTP.IsEnabled() then pcall(function() VIPTP.Disable() end) end
            WaitingForVIPTP = false
            CurrentTargetUid = nil
            Stats.VIPTPFails = Stats.VIPTPFails + 1
            return false
        end
        task.wait(0.5)
    end
    return FarmingEnabled and MyRun == RunId
end

-- Chamado pelo VIPTP ao terminar. SO sinaliza, nao pilota.
local function OnVIPTPComplete()
    if not WaitingForVIPTP then return end
    WaitingForVIPTP = false
    local Uid = CurrentTargetUid
    CurrentTargetUid = nil
    if Uid and not UidLocation(Uid) then
        Stats.Collected = Stats.Collected + 1
        print("[FarmingManager] Ovo coletado! Total: " .. Stats.Collected)
    else
        print("[FarmingManager] VIPTP terminou (ovo ainda no mapa ou sumiu antes)")
    end
end

-- ==================================================
-- ESPERA O DIA (com RunId; V1 travava aqui p/ sempre)
-- ==================================================
local function WaitForDay(MyRun)
    CurrentState = "WAIT_DAY"
    while FarmingEnabled and MyRun == RunId do
        local Phase = GetPhase()
        CurrentPhase = Phase
        if Phase == "Day" then return true end
        task.wait(DAY_CHECK_INTERVAL)
    end
    return false
end

-- ==================================================
-- NIGHT LOOP: escaneia barato, achou ovo -> safe -> dia -> VIPTP
-- ==================================================
local function NightLoop(MyRun)
    CurrentState = "NIGHT_SCAN"
    while FarmingEnabled and MyRun == RunId do
        local Phase = GetPhase()
        CurrentPhase = Phase
        if Phase == "Day" then return end

        local BestEgg = FindBestEgg()
        if BestEgg and Phase == "Night" then
            print("[FarmingManager] Ovo a noite: " .. BestEgg.DisplayName .. " ($" .. tostring(BestEgg.EarningRate) .. "/s)")
            Stats.LastFound = LastFoundName
            CurrentState = "NIGHT_EGG_FOUND"
            StopFlightSystems()
            task.wait(0.3)
            if not (FarmingEnabled and MyRun == RunId) then return end
            if not FlyToSafeZoneAndWait(MyRun) then
                print("[FarmingManager] Falha indo p/ safe, tentando de novo no prox scan")
                EnsureAFK()
                task.wait(1)
            else
                task.wait(SAFE_WAIT_AFTER_REACH)
                if WaitForDay(MyRun) then
                    -- re-valida: prefere o MESMO ovo, senao o melhor atual
                    local Uid = UidLocation(BestEgg.Uid) and BestEgg.Uid or nil
                    if not Uid then
                        local Fresh = FindBestEgg()
                        if Fresh then Uid = Fresh.Uid end
                    end
                    if Uid and StartVIPTP(Uid, MyRun) then
                        WaitVIPTP(MyRun)
                    else
                        print("[FarmingManager] Ovo sumiu antes do VIPTP -> AFK")
                        EnsureAFK()
                    end
                end
            end
        else
            CurrentState = "NIGHT_SCAN"
            if Phase ~= "Night" then
                -- UNKNOWN: nao sabe a fase, fica AFK quieto sem atirar VIPTP no escuro
                EnsureAFK()
            else
                LogNoEgg("[FarmingManager] Night:")
                EnsureAFK()
            end
        end
        task.wait(NIGHT_CHECK_INTERVAL)
    end
end

-- ==================================================
-- DAY LOOP: achou ovo -> safe -> VIPTP na hora
-- ==================================================
local function DayLoop(MyRun)
    CurrentState = "DAY_SCAN"
    while FarmingEnabled and MyRun == RunId do
        local Phase = GetPhase()
        CurrentPhase = Phase
        if Phase == "Night" then return end
        if Phase == "UNKNOWN" then EnsureAFK() task.wait(0.5) continue end

        local BestEgg = FindBestEgg()
        if BestEgg then
            print("[FarmingManager] Ovo de dia: " .. BestEgg.DisplayName .. " ($" .. tostring(BestEgg.EarningRate) .. "/s)")
            Stats.LastFound = LastFoundName
            CurrentState = "DAY_EGG_FOUND"
            StopFlightSystems()
            task.wait(0.3)
            if not (FarmingEnabled and MyRun == RunId) then return end
            FlyToSafeZoneAndWait(MyRun) -- se falhar, VIPTP tenta mesmo assim do ponto atual
            task.wait(0.5)
            if not (FarmingEnabled and MyRun == RunId) then return end
            local Uid = UidLocation(BestEgg.Uid) and BestEgg.Uid or nil
            if not Uid then
                local Fresh = FindBestEgg()
                if Fresh then Uid = Fresh.Uid end
            end
            if Uid and StartVIPTP(Uid, MyRun) then
                WaitVIPTP(MyRun)
            else
                print("[FarmingManager] Ovo sumiu antes do VIPTP -> AFK")
                EnsureAFK()
            end
        else
            CurrentState = "DAY_SCAN"
            LogNoEgg("[FarmingManager] Day:")
            EnsureAFK()
        end
        task.wait(DAY_CHECK_INTERVAL)
    end
end

-- ==================================================
-- MAIN LOOP
-- ==================================================
local function MainLoop(MyRun)
    print("[FarmingManager] MainLoop iniciado")
    while FarmingEnabled and MyRun == RunId do
        local Phase = GetPhase()
        CurrentPhase = Phase
        local ok, err
        if Phase == "Day" then
            ok, err = pcall(DayLoop, MyRun)
        else
            ok, err = pcall(NightLoop, MyRun)
        end
        if not ok then
            CurrentState = "LOOP_ERROR"
            warn("[FarmingManager] Erro no loop (retry em 2s): " .. tostring(err))
            task.wait(2)
        end
        task.wait(0.1)
    end
    print("[FarmingManager] MainLoop parado")
end

-- ==================================================
-- ANTI-KICK REAL (VirtualUser) + AntiAFK
-- mousemoverel/camera SOZINHOS nao evitam kick do Roblox.
-- ==================================================
local VirtualUser = game:GetService("VirtualUser")
local IdledConn = nil

local function EnableIdleProtection()
    if IdledConn then return end
    IdledConn = Player.Idled:Connect(function()
        pcall(function() VirtualUser:ClickButton2(Vector2.new()) end)
    end)
    local AntiAFK = _G.ASTHETIC_AntiAFK
    if AntiAFK and not AntiAFK.IsEnabled() then pcall(function() AntiAFK.Enable() end) end
    print("[FarmingManager] Anti-kick ON")
end

local function DisableIdleProtection()
    if IdledConn then pcall(function() IdledConn:Disconnect() end) IdledConn = nil end
end

-- Se o char morrer/respawnar no meio do farm, reancora o loop
local RespawnConn = nil
local function HookRespawn()
    if RespawnConn then return end
    RespawnConn = Player.CharacterAdded:Connect(function()
        if not FarmingEnabled then return end
        print("[FarmingManager] Respawn detectado, retomando em 3s...")
        task.wait(3)
        if FarmingEnabled then
            StopFlightSystems()
            EnsureAFK()
        end
    end)
end

-- Invalida cache de UID quando o ovo sai do container (coletado/despawn)
local ContainerHooked = nil
local function HookContainer()
    local C = GetContainer()
    if C and C ~= ContainerHooked then
        ContainerHooked = C
        pcall(function()
            C.ChildRemoved:Connect(InvalidateUid)
        end)
    end
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================
local function Enable()
    if FarmingEnabled then return end
    FarmingEnabled = true
    RunId = RunId + 1
    local MyRun = RunId
    CurrentState = "CHECK_TIME"
    AFKStarted = false
    WaitingForVIPTP = false
    CurrentTargetUid = nil
    Stats.StartedAt = os.time()

    BuildMeshIdMap()
    HookContainer()
    HookRespawn()
    EnableIdleProtection()

    if FarmingThread then pcall(task.cancel, FarmingThread) FarmingThread = nil end
    FarmingThread = task.spawn(MainLoop, MyRun)
    print("[ASTHETIC] FarmingManager: ON")
end

local function Disable()
    if not FarmingEnabled then return end
    FarmingEnabled = false
    RunId = RunId + 1 -- mata loops, voos e callbacks pendentes
    if FarmingThread then pcall(task.cancel, FarmingThread) FarmingThread = nil end
    WaitingForVIPTP = false
    CurrentTargetUid = nil
    CurrentState = "IDLE"
    CurrentPhase = "UNKNOWN"
    task.spawn(function()
        StopFlightSystems()
        DisableIdleProtection()
    end)
    print("[ASTHETIC] FarmingManager: OFF | Coletados nesta sessao: " .. Stats.Collected)
end

local function Toggle()
    if FarmingEnabled then Disable() else Enable() end
end

-- ==================================================
-- EXPORT (API 100% compativel com a V1 + extras)
-- ==================================================
_G.ASTHETIC_FarmingManager = {
    Enable = Enable,
    Disable = Disable,
    Toggle = Toggle,
    IsEnabled = function() return FarmingEnabled end,
    SetRarities = SetRarities,
    GetState = function() return CurrentState end,
    GetPhase = function() return CurrentPhase end,
    FindBestEgg = FindBestEgg,
    OnVIPTPComplete = OnVIPTPComplete,
    GetStats = function()
        return {
            Collected = Stats.Collected,
            VIPTPFails = Stats.VIPTPFails,
            LastFound = Stats.LastFound,
            State = CurrentState,
            Phase = CurrentPhase,
            ScanTotal = LastScan.total,
            ScanCategorized = LastScan.categorized,
            ScanMatched = LastScan.matched,
            ScanNote = LastScan.note,
        }
    end,
    GetDebug = function()
        return {
            State = CurrentState,
            Phase = CurrentPhase,
            Enabled = FarmingEnabled,
            ScanTotal = LastScan.total,
            ScanCategorized = LastScan.categorized,
            ScanMatched = LastScan.matched,
            ScanNote = LastScan.note,
            LastFound = LastFoundName,
            Collected = Stats.Collected,
        }
    end,
    DebugScan = function()
        local Container = GetContainer()
        if not Container then
            print("[FarmingManager][Debug] SEM container AreaEggSlotsClient!")
            return nil
        end
        local kids = Container:GetChildren()
        print("[FarmingManager][Debug] slots: " .. #kids)
        local shown = 0
        for _, Slot in ipairs(kids) do
            if shown >= 10 then break end
            if Slot:IsA("Model") then
                shown = shown + 1
                local ok, Cat = pcall(DeepResolveCategory, Slot)
                local info = "slot=" .. Slot.Name .. " categoria=" .. tostring(ok and Cat or "ERRO")
                if ok and Cat then
                    local Pet = GetPetCached(Cat)
                    if Pet then
                        local Scale = Slot:GetAttribute("AssetScale") or 1
                        local Rate = RealRate(Pet.BaseRate, Scale, Slot:GetAttribute("Mutations") or {})
                        info = info .. " raridade=" .. tostring(Pet.RarityRaw)
                            .. " nome=" .. tostring(Pet.DisplayName)
                            .. " $/s=" .. tostring(Rate)
                            .. " passa-filtro=" .. tostring(SelectedRarities[Pet.RarityNorm] == true)
                    else
                        info = info .. " (sem dados no config!)"
                    end
                else
                    info = info .. " (MeshId desconhecido!)"
                end
                print("[FarmingManager][Debug] " .. info)
            end
        end
        local best = FindBestEgg()
        print("[FarmingManager][Debug] melhor ovo: " .. (best and (best.DisplayName .. " " .. best.Uid) or "NENHUM"))
        return best
    end,
    NIGHT_CHECK_INTERVAL = NIGHT_CHECK_INTERVAL,
    DAY_CHECK_INTERVAL = DAY_CHECK_INTERVAL,
    FLY_SPEED = FLY_SPEED,
    SAFE_FLY_SPEED = SAFE_FLY_SPEED,
    RETURN_SPEED = RETURN_SPEED,
    FLY_OFFSET = FLY_OFFSET,
    METHOD = METHOD,
}

-- Registra no CharacterSystem (se existir) p/ sobreviver ao BypassAntiCheat
if _G.ASTHETIC_CharacterSystem then
    pcall(function()
        _G.ASTHETIC_CharacterSystem:RegisterFeature({
            Name = "FarmingManager",
            Enable = Enable,
            Disable = Disable,
            IsEnabled = function() return FarmingEnabled end,
        })
    end)
end

task.spawn(function()
    task.wait(2)
    BuildMeshIdMap()
    HookContainer()
end)

print("✅ FarmingManager V2 Loaded (cache + single-driver + anti-kick + revalidacao)")
