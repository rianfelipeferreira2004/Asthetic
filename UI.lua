-- ==================================================
-- ASTHETIC HUB | UI SHELL (modern + clean)
-- Mesmos exports (_G.*) e comportamento; so visual.
--  - Janela 16px radius + hairline border + top highlight
--  - TopBar: logo, titulo, version pill, minimize
--  - Toggle flutuante com click-vs-drag (nao abre ao arrastar)
--  - Pop animation ao abrir + auto-scale em telas pequenas
-- ==================================================

local Services = {
    Players = game:GetService("Players"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    RunService = game:GetService("RunService"),
    CoreGui = game:GetService("CoreGui"),
    ContentProvider = game:GetService("ContentProvider"),
}

local Settings = _G.ASTHETIC
local Theme = Settings.UI.Theme
local ACCENT = Theme.Accent
local RADIUS = Settings.UI.CornerRadius or 16

local UI_W = Settings.UI.Width
-- TopBar um pouco mais alta p/ respirar
local TOPBAR_H = 58

-- ==================================================
-- GUI PARENT (gethui if available)
-- ==================================================
local GuiParent = Services.CoreGui

pcall(function()
    if type(gethui) == "function" then
        local HUI = gethui()
        if HUI then GuiParent = HUI end
    end
end)

-- Clean old instances
pcall(function()
    local Old = GuiParent:FindFirstChild("ASTHETIC_HUB")
    if Old then Old:Destroy() end
    local OldToggle = GuiParent:FindFirstChild("ToggleGUI")
    if OldToggle then OldToggle:Destroy() end
end)

-- ==================================================
-- TOGGLE (floating button, branding do dono)
-- ==================================================
local ASSET_ID = Settings.AssetID
pcall(function()
    Services.ContentProvider:PreloadAsync({ASSET_ID})
end)

local ToggleScreenGui = Instance.new("ScreenGui")
ToggleScreenGui.Name = "ToggleGUI"
ToggleScreenGui.ResetOnSpawn = false
ToggleScreenGui.IgnoreGuiInset = true
ToggleScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ToggleScreenGui.Parent = GuiParent

local Toggle = Instance.new("ImageButton")
Toggle.Name = "Y"
Toggle.Size = UDim2.new(0, 54, 0, 54)
Toggle.Position = UDim2.new(0.02, 0, 0.5, -27)
Toggle.BackgroundColor3 = Color3.fromRGB(22, 23, 33)
Toggle.BorderSizePixel = 0
Toggle.BackgroundTransparency = 0.06
Toggle.Image = ASSET_ID
Toggle.ZIndex = 999
Toggle.Parent = ToggleScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = Toggle

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = ACCENT
ToggleStroke.Thickness = 1.5
ToggleStroke.Transparency = 0.35
ToggleStroke.Parent = Toggle

-- brilho de vidro: faixa clara no topo do botao
local ToggleSheen = Instance.new("Frame")
ToggleSheen.Name = "Sheen"
ToggleSheen.Size = UDim2.new(1, -16, 0, 1)
ToggleSheen.Position = UDim2.new(0, 8, 0, 5)
ToggleSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleSheen.BackgroundTransparency = 0.82
ToggleSheen.BorderSizePixel = 0
ToggleSheen.ZIndex = 1000
ToggleSheen.Parent = Toggle

local ToggleSheenCorner = Instance.new("UICorner")
ToggleSheenCorner.CornerRadius = UDim.new(1, 0)
ToggleSheenCorner.Parent = ToggleSheen

-- ==================================================
-- MAIN UI
-- ==================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ASTHETIC_HUB"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = GuiParent

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, UI_W, 0, Settings.UI.Height)
Main.Position = UDim2.new(0.5, -UI_W / 2, 0.5, -Settings.UI.Height / 2)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, RADIUS)
MainCorner.Parent = Main

-- hairline border clara (efeito vidro fosco)
local MainBorder = Instance.new("UIStroke")
MainBorder.Color = Theme.Border
MainBorder.Thickness = 1
MainBorder.Transparency = 0.92
MainBorder.Parent = Main

-- highlight superior: linha de luz no topo da janela
local TopHighlight = Instance.new("Frame")
TopHighlight.Name = "TopHighlight"
TopHighlight.Size = UDim2.new(1, -48, 0, 1)
TopHighlight.Position = UDim2.new(0, 24, 0, 0)
TopHighlight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TopHighlight.BackgroundTransparency = 0.9
TopHighlight.BorderSizePixel = 0
TopHighlight.ZIndex = 30
TopHighlight.Parent = Main

-- auto-scale p/ telas pequenas (mobile): escala tudo junto
local MainScale = Instance.new("UIScale")
MainScale.Parent = Main

local function ApplyResponsiveScale()
    local Vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1200, 800)
    local S = math.min(Vp.X / 560, Vp.Y / 430)
    S = math.clamp(S, 0.62, 1)
    MainScale.Scale = S
end
ApplyResponsiveScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ApplyResponsiveScale)
end

-- ==================================================
-- TOP BAR
-- ==================================================
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
TopBar.BackgroundColor3 = Theme.TopBar
TopBar.BorderSizePixel = 0
TopBar.Active = true
TopBar.ZIndex = 20
TopBar.Parent = Main

local TopGradient = Instance.new("UIGradient")
TopGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 32, 46)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 21, 29))
})
TopGradient.Rotation = 90
TopGradient.Parent = TopBar

-- divisor hairline embaixo da topbar
local TopDivider = Instance.new("Frame")
TopDivider.Name = "TopDivider"
TopDivider.Size = UDim2.new(1, 0, 0, 1)
TopDivider.Position = UDim2.new(0, 0, 1, -1)
TopDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TopDivider.BackgroundTransparency = 0.93
TopDivider.BorderSizePixel = 0
TopDivider.ZIndex = 22
TopDivider.Parent = TopBar

-- logo: quadrado accent com gradiente + letra
local Logo = Instance.new("Frame")
Logo.Name = "Logo"
Logo.Size = UDim2.new(0, 32, 0, 32)
Logo.Position = UDim2.new(0, 14, 0.5, -16)
Logo.BackgroundColor3 = ACCENT
Logo.BorderSizePixel = 0
Logo.ZIndex = 21
Logo.Parent = TopBar

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 10)
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
LogoLetter.TextSize = 17
LogoLetter.Font = Enum.Font.GothamBold
LogoLetter.ZIndex = 22
LogoLetter.Parent = Logo

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -230, 0, 22)
Title.Position = UDim2.new(0, 54, 0, 9)
Title.BackgroundTransparency = 1
Title.Text = Settings.Name
Title.TextColor3 = Theme.Text
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.GothamBold
Title.TextTruncate = Enum.TextTruncate.AtEnd
Title.ZIndex = 21
Title.Parent = TopBar

local Subtitle = Instance.new("TextLabel")
Subtitle.Name = "Subtitle"
Subtitle.Size = UDim2.new(1, -230, 0, 15)
Subtitle.Position = UDim2.new(0, 54, 0, 31)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = Settings.Version
Subtitle.TextColor3 = Theme.SubText
Subtitle.TextSize = 10
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Font = Enum.Font.GothamMedium
Subtitle.TextTruncate = Enum.TextTruncate.AtEnd
Subtitle.ZIndex = 21
Subtitle.Parent = TopBar

-- pill de status (online dot + texto curto)
local StatusPill = Instance.new("Frame")
StatusPill.Name = "StatusPill"
StatusPill.Size = UDim2.new(0, 92, 0, 24)
StatusPill.Position = UDim2.new(1, -138, 0.5, -12)
StatusPill.BackgroundColor3 = Theme.Card
StatusPill.BorderSizePixel = 0
StatusPill.ZIndex = 21
StatusPill.Parent = TopBar

local StatusPillCorner = Instance.new("UICorner")
StatusPillCorner.CornerRadius = UDim.new(1, 0)
StatusPillCorner.Parent = StatusPill

local StatusPillStroke = Instance.new("UIStroke")
StatusPillStroke.Color = Color3.fromRGB(255, 255, 255)
StatusPillStroke.Thickness = 1
StatusPillStroke.Transparency = 0.9
StatusPillStroke.Parent = StatusPill

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 7, 0, 7)
StatusDot.Position = UDim2.new(0, 10, 0.5, -3.5)
StatusDot.BackgroundColor3 = Color3.fromRGB(90, 230, 140)
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 22
StatusDot.Parent = StatusPill

local StatusDotCorner = Instance.new("UICorner")
StatusDotCorner.CornerRadius = UDim.new(1, 0)
StatusDotCorner.Parent = StatusDot

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -26, 1, 0)
StatusText.Position = UDim2.new(0, 22, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Ready"
StatusText.TextColor3 = Theme.SubText
StatusText.TextSize = 10
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Font = Enum.Font.GothamMedium
StatusText.ZIndex = 22
StatusText.Parent = StatusPill

_G.ASTHETIC_StatusText = StatusText

-- minimize (ghost button)
local MinBtn = Instance.new("TextButton")
MinBtn.Name = "Minimize"
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -38, 0.5, -14)
MinBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.BackgroundTransparency = 1
MinBtn.BorderSizePixel = 0
MinBtn.Text = "–"
MinBtn.TextColor3 = Theme.SubText
MinBtn.TextSize = 18
MinBtn.Font = Enum.Font.GothamBold
MinBtn.AutoButtonColor = false
MinBtn.ZIndex = 23
MinBtn.Parent = TopBar

local MinBtnCorner = Instance.new("UICorner")
MinBtnCorner.CornerRadius = UDim.new(0, 8)
MinBtnCorner.Parent = MinBtn

MinBtn.MouseEnter:Connect(function()
    Services.TweenService:Create(MinBtn, TweenInfo.new(0.12), {BackgroundTransparency = 0.88}):Play()
end)
MinBtn.MouseLeave:Connect(function()
    Services.TweenService:Create(MinBtn, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
end)

-- ==================================================
-- SIDEBAR
-- ==================================================
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, Settings.UI.SidebarWidth, 1, -TOPBAR_H)
Sidebar.Position = UDim2.new(0, 0, 0, TOPBAR_H)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 5
Sidebar.Parent = Main

local SidebarDivider = Instance.new("Frame")
SidebarDivider.Size = UDim2.new(0, 1, 1, -16)
SidebarDivider.Position = UDim2.new(1, -1, 0, 8)
SidebarDivider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SidebarDivider.BackgroundTransparency = 0.94
SidebarDivider.BorderSizePixel = 0
SidebarDivider.ZIndex = 6
SidebarDivider.Parent = Sidebar

-- cabecalho da sidebar
local SideHeader = Instance.new("TextLabel")
SideHeader.Size = UDim2.new(1, -16, 0, 18)
SideHeader.Position = UDim2.new(0, 10, 0, 10)
SideHeader.BackgroundTransparency = 1
SideHeader.Text = "MENU"
SideHeader.TextColor3 = Theme.SubText
SideHeader.TextSize = 9
SideHeader.TextXAlignment = Enum.TextXAlignment.Left
SideHeader.Font = Enum.Font.GothamBold
SideHeader.ZIndex = 7
SideHeader.Parent = Sidebar

local TabScroll = Instance.new("ScrollingFrame")
TabScroll.Name = "TabScroll"
TabScroll.Size = UDim2.new(1, 0, 1, -34)
TabScroll.Position = UDim2.new(0, 0, 0, 30)
TabScroll.BackgroundTransparency = 1
TabScroll.BorderSizePixel = 0
TabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TabScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabScroll.ScrollingDirection = Enum.ScrollingDirection.Y
TabScroll.ScrollBarThickness = 0
TabScroll.ScrollBarImageTransparency = 1
TabScroll.Active = true
TabScroll.ZIndex = 6
TabScroll.Parent = Sidebar

local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingTop = UDim.new(0, 2)
TabPadding.PaddingBottom = UDim.new(0, 8)
TabPadding.PaddingLeft = UDim.new(0, 8)
TabPadding.PaddingRight = UDim.new(0, 8)
TabPadding.Parent = TabScroll

local TabList = Instance.new("UIListLayout")
TabList.Padding = UDim.new(0, 4)
TabList.SortOrder = Enum.SortOrder.LayoutOrder
TabList.Parent = TabScroll

-- ==================================================
-- CONTENT
-- ==================================================
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -Settings.UI.SidebarWidth, 1, -TOPBAR_H)
Content.Position = UDim2.new(0, Settings.UI.SidebarWidth, 0, TOPBAR_H)
Content.BackgroundColor3 = Theme.Background
Content.BorderSizePixel = 0
Content.ZIndex = 5
Content.Parent = Main

-- ==================================================
-- EXPORT
-- ==================================================
_G.ASTHETIC_Main = Main
_G.ASTHETIC_TopBar = TopBar
_G.ASTHETIC_Sidebar = Sidebar
_G.ASTHETIC_TabScroll = TabScroll
_G.ASTHETIC_Content = Content
_G.ASTHETIC_ScreenGui = ScreenGui
_G.ASTHETIC_Toggle = Toggle
_G.ASTHETIC_GuiParent = GuiParent

-- ==================================================
-- SHOW / HIDE (com pop animation)
-- ==================================================
local isUIVisible = true
local ToggleScale = Instance.new("UIScale")
ToggleScale.Parent = Toggle

local function SetUIVisible(Visible)
    isUIVisible = Visible
    ScreenGui.Enabled = Visible
    if Visible then
        local Vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1200, 800)
        local Target = math.clamp(math.min(Vp.X / 560, Vp.Y / 430), 0.62, 1)
        MainScale.Scale = Target * 0.94
        Services.TweenService:Create(MainScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Scale = Target
        }):Play()
    end
end

local function PulseToggle()
    ToggleScale.Scale = 0.88
    Services.TweenService:Create(ToggleScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = 1
    }):Play()
end

MinBtn.MouseButton1Click:Connect(function()
    SetUIVisible(false)
    PulseToggle()
end)

-- ==================================================
-- DRAG SYSTEM (Main)
-- ==================================================
local Dragging = false
local DragStart = nil
local StartPosition = nil
local ActiveTouch = nil

local function StartDrag(Input)
    if Dragging then return end
    if Input.UserInputType == Enum.UserInputType.Touch then
        ActiveTouch = Input
    end
    Dragging = true
    DragStart = Input.Position
    StartPosition = Main.Position
end

local function StopDrag()
    Dragging = false
    ActiveTouch = nil
    DragStart = nil
    StartPosition = nil
end

TopBar.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or
       Input.UserInputType == Enum.UserInputType.Touch then
        StartDrag(Input)
    end
end)

local function CreateDragZone(Name, Position, Size)
    local Zone = Instance.new("Frame")
    Zone.Name = Name
    Zone.Position = Position
    Zone.Size = Size
    Zone.BackgroundTransparency = 1
    Zone.BorderSizePixel = 0
    Zone.Active = true
    Zone.ZIndex = 50
    Zone.Parent = Main

    Zone.InputBegan:Connect(function(Input)
        if Input.UserInputType == Enum.UserInputType.MouseButton1 or
           Input.UserInputType == Enum.UserInputType.Touch then
            StartDrag(Input)
        end
    end)

    return Zone
end

CreateDragZone("DragTop", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 0, 5))
CreateDragZone("DragBottom", UDim2.new(0, 0, 1, -5), UDim2.new(1, 0, 0, 5))
CreateDragZone("DragLeft", UDim2.new(0, 0, 0, 0), UDim2.new(0, 5, 1, 0))
CreateDragZone("DragRight", UDim2.new(1, -5, 0, 0), UDim2.new(0, 5, 1, 0))

Services.UserInputService.InputChanged:Connect(function(Input)
    if not Dragging then return end
    if Input.UserInputType == Enum.UserInputType.Touch then
        if ActiveTouch and Input ~= ActiveTouch then return end
    end
    if not DragStart or not StartPosition then return end
    if Input.UserInputType ~= Enum.UserInputType.MouseMovement and
       Input.UserInputType ~= Enum.UserInputType.Touch then return end

    local Delta = Input.Position - DragStart
    Main.Position = UDim2.new(
        StartPosition.X.Scale,
        StartPosition.X.Offset + Delta.X,
        StartPosition.Y.Scale,
        StartPosition.Y.Offset + Delta.Y
    )
end)

Services.UserInputService.InputEnded:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.Touch then
        if ActiveTouch and Input == ActiveTouch then
            StopDrag()
        end
        return
    end
    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
        if Dragging then StopDrag() end
    end
end)

-- ==================================================
-- DRAG + TAP no Toggle (tap alterna, arrasto so move)
-- ==================================================
local ToggleDragging = false
local ToggleDragStart = nil
local ToggleStartPos = nil
local ToggleActiveTouch = nil
local ToggleDownPos = nil
local ToggleDownTime = 0

Toggle.InputBegan:Connect(function(Input)
    if Input.UserInputType == Enum.UserInputType.MouseButton1 or
       Input.UserInputType == Enum.UserInputType.Touch then
        if Input.UserInputType == Enum.UserInputType.Touch then
            ToggleActiveTouch = Input
        end
        ToggleDragging = true
        ToggleDragStart = Input.Position
        ToggleStartPos = Toggle.Position
        ToggleDownPos = Input.Position
        ToggleDownTime = os.clock()
    end
end)

Services.UserInputService.InputChanged:Connect(function(Input)
    if not ToggleDragging then return end
    if Input.UserInputType == Enum.UserInputType.Touch then
        if ToggleActiveTouch and Input ~= ToggleActiveTouch then return end
    end
    if not ToggleDragStart or not ToggleStartPos then return end
    if Input.UserInputType ~= Enum.UserInputType.MouseMovement and
       Input.UserInputType ~= Enum.UserInputType.Touch then return end

    local Delta = Input.Position - ToggleDragStart
    Toggle.Position = UDim2.new(
        ToggleStartPos.X.Scale,
        ToggleStartPos.X.Offset + Delta.X,
        ToggleStartPos.Y.Scale,
        ToggleStartPos.Y.Offset + Delta.Y
    )
end)

Services.UserInputService.InputEnded:Connect(function(Input)
    local IsToggleInput = (Input.UserInputType == Enum.UserInputType.MouseButton1)
        or (Input.UserInputType == Enum.UserInputType.Touch and ToggleActiveTouch and Input == ToggleActiveTouch)
    if not IsToggleInput then return end

    -- tap (sem arrasto): alterna a UI
    if ToggleDragging and ToggleDownPos then
        local Moved = (Input.Position - ToggleDownPos).Magnitude
        if Moved < 10 and os.clock() - ToggleDownTime < 0.6 then
            SetUIVisible(not isUIVisible)
            PulseToggle()
        end
    end

    ToggleDragging = false
    ToggleActiveTouch = nil
    ToggleDragStart = nil
    ToggleStartPos = nil
    ToggleDownPos = nil
end)

-- pop de entrada na primeira abertura
task.spawn(function()
    task.wait(0.05)
    SetUIVisible(true)
end)

print("✅ UI Loaded (modern shell)")
