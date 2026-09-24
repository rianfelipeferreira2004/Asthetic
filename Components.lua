-- ==================================================
-- ASTHETIC HUB | Components (modern + clean)
-- Mesmas assinaturas e retornos; so visual.
--  - Tabs: pill moderna (tint accent + indicador lateral)
--  - SectionTitle: titulo + barra accent
--  - Checkboxes: toggle switch estilo iOS com animacao
-- ==================================================

local TweenService = game:GetService("TweenService")
local Theme = _G.ASTHETIC.UI.Theme
local ACCENT = Theme.Accent

local ANIM = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ==================================================
-- GET TAB TEXT SIZE
-- ==================================================
local function GetTabTextSize(Name)
    local Length = #Name
    if Length >= 16 then return 10
    elseif Length >= 13 then return 11
    elseif Length >= 9 then return 12
    elseif Length >= 6 then return 13
    else return 14 end
end

-- ==================================================
-- CREATE TAB (pill)
-- ==================================================
function CreateTab(Name, Order)
    local TabScroll = _G.ASTHETIC_TabScroll
    local TabHeight = _G.ASTHETIC.UI.TabHeight or 36

    local Tab = Instance.new("TextButton")
    Tab.Name = Name:gsub("%s+", "_") .. "_Tab"
    Tab.Size = UDim2.new(1, 0, 0, TabHeight)
    Tab.BackgroundColor3 = ACCENT
    Tab.BackgroundTransparency = 1
    Tab.BorderSizePixel = 0
    Tab.Text = ""
    Tab.AutoButtonColor = false
    Tab.LayoutOrder = Order or 1
    Tab.ZIndex = 7
    Tab:SetAttribute("Selected", false)
    Tab.Parent = TabScroll

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 10)
    Corner.Parent = Tab

    local Indicator = Instance.new("Frame")
    Indicator.Name = "Indicator"
    Indicator.Size = UDim2.new(0, 3, 0, 18)
    Indicator.Position = UDim2.new(0, 7, 0.5, -9)
    Indicator.BackgroundColor3 = ACCENT
    Indicator.BackgroundTransparency = 1
    Indicator.BorderSizePixel = 0
    Indicator.ZIndex = 8
    Indicator.Parent = Tab

    local IndicatorCorner = Instance.new("UICorner")
    IndicatorCorner.CornerRadius = UDim.new(1, 0)
    IndicatorCorner.Parent = Indicator

    local Text = Instance.new("TextLabel")
    Text.Name = "TabText"
    Text.Size = UDim2.new(1, -26, 1, 0)
    Text.Position = UDim2.new(0, 18, 0, 0)
    Text.BackgroundTransparency = 1
    Text.Text = Name
    Text.TextColor3 = Color3.fromRGB(150, 150, 172)
    Text.TextSize = GetTabTextSize(Name)
    Text.TextXAlignment = Enum.TextXAlignment.Left
    Text.TextYAlignment = Enum.TextYAlignment.Center
    Text.Font = Enum.Font.GothamMedium
    Text.TextTruncate = Enum.TextTruncate.AtEnd
    Text.Active = false
    Text.Selectable = false
    Text.ZIndex = 8
    Text.Parent = Tab

    -- hover sutil (so quando nao selecionada)
    Tab.MouseEnter:Connect(function()
        if not Tab:GetAttribute("Selected") then
            TweenService:Create(Tab, ANIM, {BackgroundTransparency = 0.9}):Play()
        end
    end)
    Tab.MouseLeave:Connect(function()
        if not Tab:GetAttribute("Selected") then
            TweenService:Create(Tab, ANIM, {BackgroundTransparency = 1}):Play()
        end
    end)

    return Tab
end

-- ==================================================
-- CREATE PAGE
-- ==================================================
function CreatePage(Name)
    local Content = _G.ASTHETIC_Content
    local Page = Instance.new("ScrollingFrame")
    Page.Name = Name .. "_Page"
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.Visible = false
    Page.CanvasSize = UDim2.new(0, 0, 0, 0)
    Page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    Page.ScrollingDirection = Enum.ScrollingDirection.Y
    Page.ScrollBarThickness = 3
    Page.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
    Page.ScrollBarImageTransparency = 0.75
    Page.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    Page.HorizontalScrollBarInset = Enum.ScrollBarInset.None
    Page.Active = true
    Page.Selectable = true
    Page.ZIndex = 6
    Page.Parent = Content

    local Padding = Instance.new("UIPadding")
    Padding.PaddingTop = UDim.new(0, 14)
    Padding.PaddingBottom = UDim.new(0, 16)
    Padding.PaddingLeft = UDim.new(0, 16)
    Padding.PaddingRight = UDim.new(0, 14)
    Padding.Parent = Page

    local List = Instance.new("UIListLayout")
    List.Padding = UDim.new(0, 6)
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Parent = Page

    return Page
end

-- ==================================================
-- CREATE SECTION TITLE (titulo + barra accent)
-- ==================================================
function CreateSectionTitle(Parent, TextValue, Order)
    local Holder = Instance.new("Frame")
    Holder.Name = "SectionTitle"
    Holder.Size = UDim2.new(1, 0, 0, 28)
    Holder.BackgroundTransparency = 1
    Holder.LayoutOrder = Order or 1
    Holder.ZIndex = 8
    Holder.Parent = Parent

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 0, 19)
    Label.BackgroundTransparency = 1
    Label.Text = TextValue
    Label.TextColor3 = Color3.fromRGB(235, 235, 245)
    Label.TextSize = 13
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextYAlignment = Enum.TextYAlignment.Center
    Label.Font = Enum.Font.GothamBold
    Label.TextTruncate = Enum.TextTruncate.AtEnd
    Label.Active = false
    Label.Selectable = false
    Label.ZIndex = 8
    Label.Parent = Holder

    local Bar = Instance.new("Frame")
    Bar.Size = UDim2.new(0, 22, 0, 3)
    Bar.Position = UDim2.new(0, 0, 0, 21)
    Bar.BackgroundColor3 = ACCENT
    Bar.BorderSizePixel = 0
    Bar.ZIndex = 8
    Bar.Parent = Holder

    local BarCorner = Instance.new("UICorner")
    BarCorner.CornerRadius = UDim.new(1, 0)
    BarCorner.Parent = Bar

    return Holder
end

-- ==================================================
-- SWITCH BUILDER (base dos checkboxes modernos)
-- Retorna: SwitchButton, Knob, applyVisual(On, instant)
-- ==================================================
local function BuildSwitch(Parent)
    local Switch = Instance.new("TextButton")
    Switch.Name = "CheckBox"
    Switch.Size = UDim2.new(0, 42, 0, 24)
    Switch.Position = UDim2.new(1, -42, 0.5, -12)
    Switch.BackgroundColor3 = Color3.fromRGB(42, 44, 60)
    Switch.BorderSizePixel = 0
    Switch.Text = ""
    Switch.AutoButtonColor = false
    Switch.Active = true
    Switch.ZIndex = 20
    Switch.Parent = Parent

    local SwitchCorner = Instance.new("UICorner")
    SwitchCorner.CornerRadius = UDim.new(1, 0)
    SwitchCorner.Parent = Switch

    local SwitchStroke = Instance.new("UIStroke")
    SwitchStroke.Color = Color3.fromRGB(255, 255, 255)
    SwitchStroke.Thickness = 1
    SwitchStroke.Transparency = 0.88
    SwitchStroke.Parent = Switch

    local Knob = Instance.new("Frame")
    Knob.Name = "Knob"
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = UDim2.new(0, 4, 0.5, -8)
    Knob.BackgroundColor3 = Color3.fromRGB(200, 200, 215)
    Knob.BorderSizePixel = 0
    Knob.ZIndex = 21
    Knob.Parent = Switch

    local KnobCorner = Instance.new("UICorner")
    KnobCorner.CornerRadius = UDim.new(1, 0)
    KnobCorner.Parent = Knob

    local function applyVisual(On, Instant)
        local Bg = On and ACCENT or Color3.fromRGB(42, 44, 60)
        local KnobPos = On and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 4, 0.5, -8)
        local KnobColor = On and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 215)
        local StrokeT = On and 0.4 or 0.88
        if Instant then
            Switch.BackgroundColor3 = Bg
            Knob.Position = KnobPos
            Knob.BackgroundColor3 = KnobColor
            SwitchStroke.Transparency = StrokeT
        else
            TweenService:Create(Switch, ANIM, {BackgroundColor3 = Bg}):Play()
            TweenService:Create(Knob, ANIM, {Position = KnobPos, BackgroundColor3 = KnobColor}):Play()
            TweenService:Create(SwitchStroke, ANIM, {Transparency = StrokeT}):Play()
        end
    end

    return Switch, Knob, applyVisual
end

local function BuildRow(Parent, TextValue, Order)
    local Holder = Instance.new("Frame")
    Holder.Name = TextValue:gsub("%s+", "_")
    Holder.Size = UDim2.new(1, 0, 0, 34)
    Holder.BackgroundTransparency = 1
    Holder.BorderSizePixel = 0
    Holder.LayoutOrder = Order or 1
    Holder.Active = false
    Holder.ZIndex = 9
    Holder.Parent = Parent

    local Label = Instance.new("TextLabel")
    Label.Name = "Label"
    Label.Size = UDim2.new(1, -52, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = TextValue
    Label.TextColor3 = Color3.fromRGB(208, 208, 224)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextYAlignment = Enum.TextYAlignment.Center
    Label.Font = Enum.Font.GothamMedium
    Label.TextTruncate = Enum.TextTruncate.AtEnd
    Label.Active = false
    Label.Selectable = false
    Label.ZIndex = 10
    Label.Parent = Holder

    return Holder
end

-- ==================================================
-- CREATE CHECKBOX (switch) — mesmo retorno de antes
-- ==================================================
function CreateCheckbox(Parent, TextValue, Order)
    local Holder = BuildRow(Parent, TextValue, Order)
    local Switch, _, applyVisual = BuildSwitch(Holder)

    local Enabled = false
    local function Toggle()
        Enabled = not Enabled
        applyVisual(Enabled, false)
    end

    Switch.MouseButton1Click:Connect(Toggle)
    applyVisual(false, true)

    return Holder, Switch, function() return Enabled end
end

-- ==================================================
-- CREATE TEXTBOX WITH CHECKBOX — mesmo retorno de antes
-- ==================================================
function CreateTextBoxWithCheckbox(Parent, TextValue, Order, DefaultValue, MinValue, MaxValue)
    DefaultValue = DefaultValue or 50
    MinValue = MinValue or 0
    MaxValue = MaxValue or 1000

    local Holder = Instance.new("Frame")
    Holder.Name = TextValue:gsub("%s+", "_")
    Holder.Size = UDim2.new(1, 0, 0, 34)
    Holder.BackgroundTransparency = 1
    Holder.BorderSizePixel = 0
    Holder.LayoutOrder = Order or 1
    Holder.Active = false
    Holder.ZIndex = 9
    Holder.Parent = Parent

    local Label = Instance.new("TextLabel")
    Label.Name = "Label"
    Label.Size = UDim2.new(0, 92, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = TextValue
    Label.TextColor3 = Color3.fromRGB(208, 208, 224)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.TextYAlignment = Enum.TextYAlignment.Center
    Label.Font = Enum.Font.GothamMedium
    Label.TextTruncate = Enum.TextTruncate.AtEnd
    Label.Active = false
    Label.Selectable = false
    Label.ZIndex = 10
    Label.Parent = Holder

    local TextBox = Instance.new("TextBox")
    TextBox.Name = "TextBox"
    TextBox.Size = UDim2.new(0, 64, 0, 26)
    TextBox.Position = UDim2.new(0, 96, 0.5, -13)
    TextBox.BackgroundColor3 = Color3.fromRGB(30, 31, 45)
    TextBox.BorderSizePixel = 0
    TextBox.Text = tostring(DefaultValue)
    TextBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextBox.TextSize = 12
    TextBox.TextXAlignment = Enum.TextXAlignment.Center
    TextBox.TextYAlignment = Enum.TextYAlignment.Center
    TextBox.Font = Enum.Font.GothamMedium
    TextBox.ClearTextOnFocus = false
    TextBox.ZIndex = 11
    TextBox.Parent = Holder

    local TBoxCorner = Instance.new("UICorner")
    TBoxCorner.CornerRadius = UDim.new(0, 8)
    TBoxCorner.Parent = TextBox

    local TBoxStroke = Instance.new("UIStroke")
    TBoxStroke.Color = Color3.fromRGB(255, 255, 255)
    TBoxStroke.Thickness = 1
    TBoxStroke.Transparency = 0.88
    TBoxStroke.Parent = TextBox

    local Switch, _, applyVisual = BuildSwitch(Holder)

    local Enabled = false
    local CurrentValue = DefaultValue

    local function UpdateValue()
        local val = tonumber(TextBox.Text)
        if val then
            CurrentValue = math.clamp(val, MinValue, MaxValue)
            TextBox.Text = tostring(CurrentValue)
        else
            TextBox.Text = tostring(CurrentValue)
        end
    end

    local function Toggle()
        Enabled = not Enabled
        applyVisual(Enabled, false)
    end

    Switch.MouseButton1Click:Connect(Toggle)
    TextBox.FocusLost:Connect(UpdateValue)
    TextBox.Focused:Connect(function()
        TweenService:Create(TBoxStroke, ANIM, {Transparency = 0.4, Color = ACCENT}):Play()
    end)
    TextBox.FocusLost:Connect(function()
        TweenService:Create(TBoxStroke, ANIM, {Transparency = 0.88, Color = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    applyVisual(false, true)

    return Holder, Switch, function() return Enabled end, TextBox, function() return CurrentValue end
end

-- ==================================================
-- SMART CHECKBOX (switch) — mesmo table de retorno
-- ==================================================
function CreateSmartCheckbox(Parent, LabelText, Order, ToggleFunction, GetStateFunction)
    local Holder = BuildRow(Parent, LabelText, Order)
    local Switch, _, applyVisual = BuildSwitch(Holder)

    local Enabled = false
    if GetStateFunction then
        Enabled = GetStateFunction() and true or false
        applyVisual(Enabled, true)
    else
        applyVisual(false, true)
    end

    local function UpdateUI(state)
        Enabled = state and true or false
        applyVisual(Enabled, false)
    end

    Switch.MouseButton1Click:Connect(function()
        if ToggleFunction then
            local currentState = GetStateFunction and GetStateFunction() or Enabled
            local newState = not currentState
            UpdateUI(newState)
            task.spawn(ToggleFunction)
        end
    end)

    return {
        Holder = Holder,
        Button = Switch,
        GetState = function() return Enabled end,
        SetState = UpdateUI,
        Update = UpdateUI,
    }
end

print("✅ Components Loaded (modern)")
