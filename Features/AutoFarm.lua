--==================================================
-- ASTHETIC HUB | FEATURE | Auto Farm
-- Check Egg + Display Card + Select + Send to Teleport
-- ✅ Register ជាមួយ CharacterSystem
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

-- espera com timeout: sem isso, se o jogo renomear um path,
-- o WaitForChild infinito TRAVA o carregamento do hub inteiro aqui
local function SafeWaitChild(parent, name, timeout)
    if not parent then return nil end
    local found = parent:FindFirstChild(name)
    if found then return found end
    local ok, res = pcall(function()
        return parent:WaitForChild(name, timeout or 10)
    end)
    if ok and res then return res end
    return parent:FindFirstChild(name)
end

local Container = SafeWaitChild(workspace, "AreaEggSlotsClient", 15)
if not Container then
    warn("[ASTHETIC][AutoFarm] AreaEggSlotsClient não encontrado! Start Check Egg vai listar vazio.")
end

--==================================================
-- VARIABLES
--==================================================
local AutoFarmEnabled = false
local SelectedEgg = nil
local EggList = {}

--==================================================
-- ASSETS
--==================================================
local Assets = SafeWaitChild(ReplicatedStorage, "Data", 10)
if Assets then Assets = SafeWaitChild(Assets, "Assets", 10) end
local Configs = Assets and SafeWaitChild(Assets, "Configs", 10) or nil
local EggAssets = SafeWaitChild(ReplicatedStorage, "Assets", 10)
local EggModels = EggAssets and SafeWaitChild(EggAssets, "Models", 10) or nil
if EggModels then EggModels = SafeWaitChild(EggModels, "Eggs", 10) end
if not Configs or not EggModels then
    warn("[ASTHETIC][AutoFarm] Configs/Eggs não encontrados! Reconhecimento por MeshId desativado (ovos aparecem como Unknown).")
end

--==================================================
-- MESHID MAP
--==================================================
local MeshIdToCategory = {}

local function BuildMeshIdMap()
    if not Configs or not EggModels then return end
    for _, Config in ipairs(Configs:GetChildren()) do
        local Success, Module = pcall(function()
            return require(Config)
        end)
        if Success and Module and Module.Egg then
            local ModelName = Module.Egg.ModelName or Config.Name
            local EggTemplate = EggModels:FindFirstChild(ModelName)
            if EggTemplate then
                for _, descendant in ipairs(EggTemplate:GetDescendants()) do
                    if descendant:IsA("MeshPart") and descendant.MeshId ~= "" then
                        MeshIdToCategory[descendant.MeshId] = Config.Name
                    end
                    if descendant:IsA("SpecialMesh") and descendant.MeshId ~= "" then
                        MeshIdToCategory[descendant.MeshId] = Config.Name
                    end
                end
            end
        end
    end
end

BuildMeshIdMap()

--==================================================
-- GET PET DATA
--==================================================
local function GetPetData(AssetCategory)
    local Data = {
        Name = AssetCategory,
        DisplayName = AssetCategory,
        EarningRate = 0,
        Icon = nil
    }
    if not Configs then return Data end
    local Config = Configs:FindFirstChild(AssetCategory)
    if not Config then return Data end
    
    local Success, Module = pcall(function()
        return require(Config)
    end)
    
    if Success and Module then
        Data.DisplayName = Module.DisplayName or AssetCategory
        Data.EarningRate = Module.EarningRate or 0
        Data.Icon = Module.Icon
    end
    
    return Data
end

--==================================================
-- FORMAT MONEY
--==================================================
local function FormatMoney(Amount)
    if type(Amount) ~= "number" then return tostring(Amount) end
    if Amount >= 1e12 then
        return string.format("%.2fT", Amount / 1e12)
    elseif Amount >= 1e9 then
        return string.format("%.2fB", Amount / 1e9)
    elseif Amount >= 1e6 then
        return string.format("%.2fM", Amount / 1e6)
    elseif Amount >= 1e3 then
        return string.format("%.2fK", Amount / 1e3)
    else
        return tostring(math.floor(Amount))
    end
end

--==================================================
-- CALCULATE REAL RATE
--==================================================
local function CalculateRatePerSecond(EarningRate, Scale, Mutations)
    local PayoutFactor
    if Scale <= 5 then
        PayoutFactor = Scale ^ 1.85
    else
        PayoutFactor = (Scale / 5) ^ 1.2 * 19.637875755794113
    end
    
    local MutationMultiplier = 1
    if Mutations and #Mutations > 0 then
        local Success, MutationsModule = pcall(function()
            return require(ReplicatedStorage.Shared.Modules.Mutations)
        end)
        if Success and MutationsModule then
            MutationMultiplier = MutationsModule.EarningsFor(Mutations)
        end
    end
    
    return math.round(EarningRate * PayoutFactor * MutationMultiplier)
end

--==================================================
-- FIND ASSET CATEGORY
--==================================================
local function FindAssetCategory(EggModel)
    for _, descendant in ipairs(EggModel:GetDescendants()) do
        if descendant:IsA("MeshPart") and descendant.MeshId ~= "" then
            local Category = MeshIdToCategory[descendant.MeshId]
            if Category then return Category end
        end
        if descendant:IsA("SpecialMesh") and descendant.MeshId ~= "" then
            local Category = MeshIdToCategory[descendant.MeshId]
            if Category then return Category end
        end
    end
    return nil
end

--==================================================
-- SCAN EGGS
--==================================================
local function ScanEggs()
    EggList = {}

    -- container pode ter sumido/renomeado: tenta resolver de novo
    local C = Container or workspace:FindFirstChild("AreaEggSlotsClient")
    if not C then
        warn("[ASTHETIC][AutoFarm] ScanEggs: sem container!")
        return EggList
    end
    Container = C

    local unknown = 0
    for _, child in ipairs(C:GetChildren()) do
        if child:IsA("Model") then
            local ok, AssetCategory = pcall(FindAssetCategory, child)
            if ok and AssetCategory then
                local Data = GetPetData(AssetCategory)
                if Data then
                    local Scale = child:GetAttribute("AssetScale") or 1
                    local Mutations = child:GetAttribute("Mutations") or {}
                    local RealRate = CalculateRatePerSecond(Data.EarningRate, Scale, Mutations)

                    table.insert(EggList, {
                        Id = child.Name,
                        Category = AssetCategory,
                        DisplayName = Data.DisplayName,
                        Icon = Data.Icon,
                        EarningRate = RealRate,
                        Model = child
                    })
                end
            else
                -- ✅ ovo não reconhecido (jogo mudou o modelo): lista mesmo assim
                -- como Unknown pra teleporte manual continuar funcionando
                unknown = unknown + 1
                table.insert(EggList, {
                    Id = child.Name,
                    Category = nil,
                    DisplayName = "Unknown (" .. child.Name .. ")",
                    Icon = nil,
                    EarningRate = 0,
                    Model = child
                })
            end
        end
    end

    table.sort(EggList, function(a, b)
        return a.EarningRate > b.EarningRate
    end)

    if unknown > 0 then
        warn("[ASTHETIC][AutoFarm] " .. unknown .. " ovo(s) não reconhecidos (Unknown). O jogo pode ter atualizado os modelos.")
    end

    return EggList
end

--==================================================
-- ENABLE / DISABLE
--==================================================
local function EnableAutoFarm()
    AutoFarmEnabled = true
    print("[ASTHETIC] Auto Farm: ON")
end

local function DisableAutoFarm()
    AutoFarmEnabled = false
    print("[ASTHETIC] Auto Farm: OFF")
end

--==================================================
-- SELECT EGG (Save only, NO Teleport)
--==================================================
local function SelectEgg(EggData)
    SelectedEgg = EggData
    print("[ASTHETIC] Selected Egg: " .. EggData.DisplayName .. " ($" .. FormatMoney(EggData.EarningRate) .. "/s)")
end

--==================================================
-- START TELEPORT (Called on Start button)
--==================================================
local function StartTeleport()
    if not SelectedEgg then
        warn("[ASTHETIC] No Egg Selected")
        return
    end

    local Method = _G.ASTHETIC_SelectedMethod or "TeleportFly"
    local Speed = _G.ASTHETIC_TeleportSpeed or 300

    print("[ASTHETIC] Start Teleport | Method: " .. Method .. " | Speed: " .. tostring(Speed) .. " | Target: " .. SelectedEgg.Id)

    if _G.ASTHETIC_TeleportSystem then
        _G.ASTHETIC_TeleportSystem.SetMethod(Method)
        _G.ASTHETIC_TeleportSystem.SetSpeed(Speed)
        _G.ASTHETIC_TeleportSystem.SetTargetId(SelectedEgg.Id)
        _G.ASTHETIC_TeleportSystem.Enable()
    end
end

--==================================================
-- STOP TELEPORT (Called on Stop button)
--==================================================
local function StopTeleport()
    if _G.ASTHETIC_TeleportSystem then
        _G.ASTHETIC_TeleportSystem.Disable()
    end
    print("[ASTHETIC] Stop Teleport")
end

--==================================================
-- EXPORT
--==================================================
_G.ASTHETIC_AutoFarm = {
    Enable = EnableAutoFarm,
    Disable = DisableAutoFarm,
    IsEnabled = function() return AutoFarmEnabled end,
    ScanEggs = ScanEggs,
    GetEggList = function() return EggList end,
    SelectEgg = SelectEgg,
    StartTeleport = StartTeleport,
    StopTeleport = StopTeleport,
    GetSelectedEgg = function() return SelectedEgg end,
    FormatMoney = FormatMoney
}

print("✅ AutoFarm Feature Loaded (Register)")
