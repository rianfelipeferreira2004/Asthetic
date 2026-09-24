-- ==================================================
-- ASTHETIC HUB | TABS MANAGER (modern pill transitions)
-- Mesma API; anima tint accent + indicador + texto.
-- ==================================================

local TweenService = game:GetService("TweenService")
local Theme = _G.ASTHETIC.UI.Theme
local ACCENT = Theme.Accent

local ANIM = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local TabsManager = {}
TabsManager.Tabs = {}
TabsManager.Pages = {}
TabsManager.ActiveTab = nil
TabsManager.ActivePage = nil

local TEXT_ACTIVE = Color3.fromRGB(255, 255, 255)
local TEXT_IDLE = Color3.fromRGB(150, 150, 172)

-- ==================================================
-- REGISTER TAB
-- ==================================================
function TabsManager:RegisterTab(Name, Order, PageName)
    local Tab = CreateTab(Name, Order)
    local Page = CreatePage(PageName or Name:upper())

    table.insert(self.Tabs, { Tab = Tab, Page = Page, Name = Name })

    Tab.MouseButton1Click:Connect(function()
        self:SelectTab(Tab, Page)
    end)

    return Tab, Page
end

-- ==================================================
-- SELECT TAB
-- ==================================================
function TabsManager:SelectTab(SelectedTab, SelectedPage)
    for _, data in ipairs(self.Tabs) do
        data.Page.Visible = false
        local Indicator = data.Tab:FindFirstChild("Indicator")
        local TabText = data.Tab:FindFirstChild("TabText")
        data.Tab:SetAttribute("Selected", false)
        TweenService:Create(data.Tab, ANIM, {BackgroundColor3 = ACCENT, BackgroundTransparency = 1}):Play()
        if Indicator then
            TweenService:Create(Indicator, ANIM, {BackgroundTransparency = 1}):Play()
        end
        if TabText then
            TweenService:Create(TabText, ANIM, {TextColor3 = TEXT_IDLE}):Play()
        end
    end

    SelectedPage.Visible = true
    task.wait(0.05)
    pcall(function()
        SelectedPage.CanvasPosition = Vector2.new(0, 0)
    end)

    SelectedTab:SetAttribute("Selected", true)
    TweenService:Create(SelectedTab, ANIM, {BackgroundColor3 = ACCENT, BackgroundTransparency = 0.8}):Play()
    local Indicator = SelectedTab:FindFirstChild("Indicator")
    local TabText = SelectedTab:FindFirstChild("TabText")
    if Indicator then
        TweenService:Create(Indicator, ANIM, {BackgroundTransparency = 0}):Play()
    end
    if TabText then
        TweenService:Create(TabText, ANIM, {TextColor3 = TEXT_ACTIVE}):Play()
    end

    self.ActiveTab = SelectedTab
    self.ActivePage = SelectedPage
end

-- ==================================================
-- GET TAB BY NAME
-- ==================================================
function TabsManager:GetTab(Name)
    for _, data in ipairs(self.Tabs) do
        if data.Name == Name then
            return data.Tab, data.Page
        end
    end
    return nil, nil
end

-- ==================================================
-- SELECT TAB BY NAME
-- ==================================================
function TabsManager:SelectTabByName(Name)
    local Tab, Page = self:GetTab(Name)
    if Tab and Page then
        self:SelectTab(Tab, Page)
    end
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.ASTHETIC_TabsManager = TabsManager

print("✅ Tabs Manager Loaded (modern)")
