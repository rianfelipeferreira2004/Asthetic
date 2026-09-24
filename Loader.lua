-- ==================================================
-- ASTHETIC HUB | STEAL AN EGG | Loader (modern loading)
-- Mesmo fluxo de load; so visual + status por etapa.
-- ==================================================

local BASE_URL = "https://raw.githubusercontent.com/rianfelipeferreira2004/Asthetic/main/"

_G.ASTHETIC_EnablePrint = false

-- NÃO sobrescreve o print global (quebrava módulos internos do CoreGui
-- como RobloxGui.Modules.Common.Locales.en-us). Usa helper local.
local oldPrint = print
local function YPrint(...)
    if _G.ASTHETIC_EnablePrint then
        oldPrint(...)
    end
end

YPrint("🔵 Loading ASTHETIC HUB...")

-- ==================================================
-- CACHE SYSTEM
-- ==================================================
_G.ASTHETIC_Cache = _G.ASTHETIC_Cache or {}

local function GetScript(path)
    local fullPath = BASE_URL .. path
    if _G.ASTHETIC_Cache[fullPath] then
        return _G.ASTHETIC_Cache[fullPath]
    end
    local script = game:HttpGet(fullPath)
    _G.ASTHETIC_Cache[fullPath] = script
    return script
end

-- ==================================================
-- WAIT UNTIL GAME IS LOADED
-- ==================================================
repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

local Player = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")

-- Parent seguro: gethui/get_hui/protectgui quando existir, senão CoreGui.
-- Parentear direto no CoreGui em alguns executores dispara erro interno
-- do RobloxGui (Locales en-us). Por isso resolve com pcall + fallback.
local function GetGuiParent()
    local ok, hui = pcall(function()
        if type(gethui) == "function" then return gethui() end
        if type(get_hui) == "function" then return get_hui() end
    end)
    if ok and hui then return hui end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg then return cg end
    return game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

local GuiParent = GetGuiParent()

YPrint("✅ Game loaded, Player: " .. Player.Name)

-- ==================================================
-- CREATE LOADING SCREEN (modern card)
-- ==================================================
local ACCENT = Color3.fromRGB(105, 90, 190)

local function CreateLoadingScreen()
    local LoadingGui = Instance.new("ScreenGui")
    LoadingGui.Name = "LoadingScreen"
    LoadingGui.ResetOnSpawn = false
    LoadingGui.IgnoreGuiInset = true
    LoadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    LoadingGui.DisplayOrder = 9999
    LoadingGui.Parent = GuiParent

    -- véu escuro de fundo
    local Veil = Instance.new("Frame")
    Veil.Size = UDim2.new(1, 0, 1, 0)
    Veil.BackgroundColor3 = Color3.fromRGB(8, 9, 13)
    Veil.BackgroundTransparency = 0.35
    Veil.BorderSizePixel = 0
    Veil.Parent = LoadingGui

    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Size = UDim2.new(0, 300, 0, 168)
    Container.Position = UDim2.new(0.5, -150, 0.5, -84)
    Container.BackgroundColor3 = Color3.fromRGB(15, 16, 22)
    Container.BorderSizePixel = 0
    Container.ClipsDescendants = true
    Container.Parent = LoadingGui

    local ContainerCorner = Instance.new("UICorner")
    ContainerCorner.CornerRadius = UDim.new(0, 18)
    ContainerCorner.Parent = Container

    local ContainerBorder = Instance.new("UIStroke")
    ContainerBorder.Color = Color3.fromRGB(255, 255, 255)
    ContainerBorder.Thickness = 1
    ContainerBorder.Transparency = 0.92
    ContainerBorder.Parent = Container

    -- highlight superior
    local Sheen = Instance.new("Frame")
    Sheen.Size = UDim2.new(1, -64, 0, 1)
    Sheen.Position = UDim2.new(0, 32, 0, 0)
    Sheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Sheen.BackgroundTransparency = 0.9
    Sheen.BorderSizePixel = 0
    Sheen.Parent = Container

    -- logo
    local Logo = Instance.new("Frame")
    Logo.Size = UDim2.new(0, 38, 0, 38)
    Logo.Position = UDim2.new(0, 20, 0, 18)
    Logo.BackgroundColor3 = ACCENT
    Logo.BorderSizePixel = 0
    Logo.Parent = Container

    local LogoCorner = Instance.new("UICorner")
    LogoCorner.CornerRadius = UDim.new(0, 12)
    LogoCorner.Parent = Logo

    local LogoGradient = Instance.new("UIGradient")
    LogoGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 135, 245)),
        ColorSequenceKeypoint.new(1, ACCENT)
    })
    LogoGradient.Rotation = 45
    LogoGradient.Parent = Logo

    local LogoLetter = Instance.new("TextLabel")
    LogoLetter.Size = UDim2.new(1, 0, 1, 0)
    LogoLetter.BackgroundTransparency = 1
    LogoLetter.Text = "A"
    LogoLetter.TextColor3 = Color3.fromRGB(255, 255, 255)
    LogoLetter.TextSize = 20
    LogoLetter.Font = Enum.Font.GothamBold
    LogoLetter.Parent = Logo

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -76, 0, 22)
    Title.Position = UDim2.new(0, 68, 0, 20)
    Title.BackgroundTransparency = 1
    Title.Text = "ASTHETIC HUB"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 17
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Font = Enum.Font.GothamBold
    Title.Parent = Container

    local Subtitle = Instance.new("TextLabel")
    Subtitle.Size = UDim2.new(1, -76, 0, 14)
    Subtitle.Position = UDim2.new(0, 68, 0, 42)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Steal An Egg"
    Subtitle.TextColor3 = Color3.fromRGB(148, 148, 168)
    Subtitle.TextSize = 10
    Subtitle.TextXAlignment = Enum.TextXAlignment.Left
    Subtitle.Font = Enum.Font.GothamMedium
    Subtitle.Parent = Container

    -- status da etapa
    local Status = Instance.new("TextLabel")
    Status.Name = "Status"
    Status.Size = UDim2.new(1, -40, 0, 14)
    Status.Position = UDim2.new(0, 20, 0, 74)
    Status.BackgroundTransparency = 1
    Status.Text = "Iniciando..."
    Status.TextColor3 = Color3.fromRGB(148, 148, 168)
    Status.TextSize = 10
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.Font = Enum.Font.Gotham
    Status.Parent = Container

    local BarBg = Instance.new("Frame")
    BarBg.Name = "BarBg"
    BarBg.Size = UDim2.new(1, -40, 0, 5)
    BarBg.Position = UDim2.new(0, 20, 0, 94)
    BarBg.BackgroundColor3 = Color3.fromRGB(34, 35, 50)
    BarBg.BorderSizePixel = 0
    BarBg.Parent = Container

    local BarBgCorner = Instance.new("UICorner")
    BarBgCorner.CornerRadius = UDim.new(1, 0)
    BarBgCorner.Parent = BarBg

    local Bar = Instance.new("Frame")
    Bar.Name = "Bar"
    Bar.Size = UDim2.new(0, 0, 1, 0)
    Bar.BackgroundColor3 = ACCENT
    Bar.BorderSizePixel = 0
    Bar.Parent = BarBg

    local BarCorner = Instance.new("UICorner")
    BarCorner.CornerRadius = UDim.new(1, 0)
    BarCorner.Parent = Bar

    local BarGradient = Instance.new("UIGradient")
    BarGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 135, 245)),
        ColorSequenceKeypoint.new(1, ACCENT)
    })
    BarGradient.Parent = Bar

    local Percent = Instance.new("TextLabel")
    Percent.Name = "Percent"
    Percent.Size = UDim2.new(0, 60, 0, 18)
    Percent.Position = UDim2.new(1, -80, 0, 112)
    Percent.BackgroundTransparency = 1
    Percent.Text = "0%"
    Percent.TextColor3 = Color3.fromRGB(255, 255, 255)
    Percent.TextSize = 15
    Percent.TextXAlignment = Enum.TextXAlignment.Right
    Percent.Font = Enum.Font.GothamBold
    Percent.Parent = Container

    local Hint = Instance.new("TextLabel")
    Hint.Size = UDim2.new(1, -40, 0, 14)
    Hint.Position = UDim2.new(0, 20, 0, 134)
    Hint.BackgroundTransparency = 1
    Hint.Text = "Pronto pra farmar 🥚"
    Hint.TextColor3 = Color3.fromRGB(110, 110, 130)
    Hint.TextSize = 9
    Hint.TextXAlignment = Enum.TextXAlignment.Left
    Hint.Font = Enum.Font.Gotham
    Hint.Parent = Container

    -- entrada suave
    Container.Size = UDim2.new(0, 280, 0, 156)
    Container.Position = UDim2.new(0.5, -140, 0.5, -78)
    TweenService:Create(Container, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 300, 0, 168),
        Position = UDim2.new(0.5, -150, 0.5, -84),
    }):Play()

    local Current = 0
    local function UpdateProgress(percent, status)
        percent = math.clamp(percent, 0, 100)
        if percent < Current then return end
        Current = percent
        TweenService:Create(Bar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(percent / 100, 0, 1, 0)
        }):Play()
        Percent.Text = math.floor(percent) .. "%"
        if status then Status.Text = status end
    end

    return {
        Gui = LoadingGui,
        Update = UpdateProgress,
        Destroy = function()
            TweenService:Create(Container, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                Size = UDim2.new(0, 280, 0, 156),
                Position = UDim2.new(0.5, -140, 0.5, -78),
            }):Play()
            TweenService:Create(Veil, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
            task.wait(0.2)
            LoadingGui:Destroy()
        end
    }
end

-- ==================================================
-- CREATE LOADING SCREEN
-- ==================================================
local Loading = CreateLoadingScreen()
Loading.Update(5, "Iniciando...")

-- ==================================================
-- LOAD CORE FILES
-- ==================================================
Loading.Update(10, "Config...")
loadstring(GetScript("Config.lua"))()

Loading.Update(15, "Interface...")
loadstring(GetScript("UI.lua"))()

Loading.Update(20, "Componentes...")
loadstring(GetScript("Components.lua"))()

-- ==================================================
-- LOAD TABS MANAGER
-- ==================================================
Loading.Update(25, "Abas...")
loadstring(GetScript("Tabs/Init.lua"))()

-- ==================================================
-- LOAD FEATURES
-- ==================================================
Loading.Update(28, "Anti AFK...")
loadstring(GetScript("Features/AntiAFK.lua"))()

Loading.Update(30, "WalkSpeed...")
loadstring(GetScript("Features/WalkSpeed.lua"))()

Loading.Update(33, "AntiTrap...")
loadstring(GetScript("Features/AntiTrap.lua"))()

Loading.Update(36, "GodMode...")
loadstring(GetScript("Features/GodMode.lua"))()

Loading.Update(39, "Teleportes...")
loadstring(GetScript("Features/TeleportSystem.lua"))()

Loading.Update(42, "AutoFarm...")
loadstring(GetScript("Features/AutoFarm.lua"))()

Loading.Update(45, "AutoAttack...")
loadstring(GetScript("Features/AutoAttack.lua"))()

Loading.Update(48, "AFK System...")
loadstring(GetScript("Features/AFKSystem.lua"))()

Loading.Update(50, "VIP TP...")
loadstring(GetScript("Features/VIPTP.lua"))()

Loading.Update(51, "Attack Drone...")
loadstring(GetScript("Features/AttackDrone.lua"))()

Loading.Update(54, "Manager Drone...")
loadstring(GetScript("Features/ManagerDrone.lua"))()

Loading.Update(57, "Fast Click...")
loadstring(GetScript("Features/ManualFastClick.lua"))()

Loading.Update(59, "Farming Manager...")
loadstring(GetScript("Features/FarmingManager.lua"))()

Loading.Update(60, "Config System...")
loadstring(GetScript("Features/ConfigSystem.lua"))()

-- ==================================================
-- LOAD TABS
-- ==================================================
Loading.Update(62, "Aba Info...")
loadstring(GetScript("Tabs/Info.lua"))()

Loading.Update(65, "Aba Farming...")
loadstring(GetScript("Tabs/Farming.lua"))()

Loading.Update(70, "Aba Combat...")
loadstring(GetScript("Tabs/Combat.lua"))()

Loading.Update(75, "Aba Auto Farming...")
loadstring(GetScript("Tabs/AutoFarming.lua"))()

Loading.Update(80, "Aba Event...")
loadstring(GetScript("Tabs/Event.lua"))()

Loading.Update(85, "Aba Hop Server...")
loadstring(GetScript("Tabs/HopServer.lua"))()

Loading.Update(90, "Aba Setting...")
loadstring(GetScript("Tabs/Setting.lua"))()

-- ==================================================
-- SELECT DEFAULT TAB
-- ==================================================
Loading.Update(92, "Finalizando...")
if _G.ASTHETIC_TabsManager then
    _G.ASTHETIC_TabsManager:SelectTabByName("Info")
end

Loading.Update(95, "Quase lá...")

-- ==================================================
-- LOAD ANTI CHEAT
-- ==================================================
Loading.Update(98, "Bypass...")
loadstring(GetScript("Features/BypassAntiCheat.lua"))()

-- ==================================================
-- WAIT 2 SECONDS THEN APPLY CONFIG
-- ==================================================
YPrint("⏳ Waiting 2s before applying config...")
task.wait(2)

if _G.ASTHETIC_ConfigSystem then
    YPrint("🔧 Applying Config...")
    _G.ASTHETIC_ConfigSystem.Load()
end

Loading.Update(100, "Pronto! 🥚")

task.wait(0.35)
Loading.Destroy()
YPrint("✅ Loading Screen Closed!")
YPrint("🚀 ASTHETIC HUB | Ready!")
