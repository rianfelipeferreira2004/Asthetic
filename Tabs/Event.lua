--==================================================
-- ASTHETIC HUB | TAB | Event
-- Feature: Auto Attack Drone
-- ✅ ដក Auto Save Config ចេញ (ManagerDrone មិនពាក់ព័ន្ធ Config)
--==================================================

local TabsManager = _G.ASTHETIC_TabsManager
local TweenService = game:GetService("TweenService")

local EventTab, EventPage = TabsManager:RegisterTab("Event", 5, "EVENT")

--==================================================
-- CONTENT
--==================================================
CreateSectionTitle(EventPage, "Event", 1)

--==================================================
-- FEATURE: AUTO ATTACK DRONE (Checkbox)
--==================================================
local ManagerHolder = Instance.new("Frame")
ManagerHolder.Size = UDim2.new(1, 0, 0, 52)
ManagerHolder.BackgroundTransparency = 1
ManagerHolder.LayoutOrder = 2
ManagerHolder.Parent = EventPage

local ManagerLabel = Instance.new("TextLabel")
ManagerLabel.Size = UDim2.new(1, -50, 0, 20)
ManagerLabel.Position = UDim2.new(0, 0, 0, 2)
ManagerLabel.BackgroundTransparency = 1
ManagerLabel.Text = "Auto Event"
ManagerLabel.TextColor3 = Color3.fromRGB(220, 220, 235)
ManagerLabel.TextSize = 13
ManagerLabel.TextXAlignment = Enum.TextXAlignment.Left
ManagerLabel.TextYAlignment = Enum.TextYAlignment.Center
ManagerLabel.Font = Enum.Font.GothamBold
ManagerLabel.Parent = ManagerHolder

local ManagerSub = Instance.new("TextLabel")
ManagerSub.Size = UDim2.new(1, -50, 0, 18)
ManagerSub.Position = UDim2.new(0, 0, 0, 24)
ManagerSub.BackgroundTransparency = 1
ManagerSub.Text = "AFK <-> Attack Drone"
ManagerSub.TextColor3 = Color3.fromRGB(150, 150, 170)
ManagerSub.TextSize = 10
ManagerSub.TextXAlignment = Enum.TextXAlignment.Left
ManagerSub.Font = Enum.Font.Gotham
ManagerSub.Parent = ManagerHolder

local ManagerButton = Instance.new("TextButton")
ManagerButton.Size = UDim2.new(0, 26, 0, 26)
ManagerButton.Position = UDim2.new(1, -26, 0.5, -13)
ManagerButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
ManagerButton.BorderSizePixel = 0
ManagerButton.Text = ""
ManagerButton.AutoButtonColor = false
ManagerButton.Parent = ManagerHolder

local ManagerCorner = Instance.new("UICorner")
ManagerCorner.CornerRadius = UDim.new(0, 6)
ManagerCorner.Parent = ManagerButton

local ManagerStroke = Instance.new("UIStroke")
ManagerStroke.Color = Color3.fromRGB(200, 200, 220)
ManagerStroke.Thickness = 1.5
ManagerStroke.Parent = ManagerButton

local ManagerCheck = Instance.new("TextLabel")
ManagerCheck.Size = UDim2.new(1, 0, 1, 0)
ManagerCheck.BackgroundTransparency = 1
ManagerCheck.Text = "✓"
ManagerCheck.TextColor3 = Color3.fromRGB(255, 255, 255)
ManagerCheck.TextSize = 18
ManagerCheck.Font = Enum.Font.GothamBold
ManagerCheck.Visible = false
ManagerCheck.Parent = ManagerButton

--==================================================
-- ✅ UPDATE UI FUNCTION
--==================================================
local function UpdateManagerUI(State)
    ManagerCheck.Visible = State
    if State then
        ManagerButton.BackgroundColor3 = Color3.fromRGB(105, 90, 190)
        ManagerStroke.Color = Color3.fromRGB(135, 120, 225)
    else
        ManagerButton.BackgroundColor3 = Color3.fromRGB(28, 29, 39)
        ManagerStroke.Color = Color3.fromRGB(200, 200, 220)
    end
end

ManagerButton.MouseButton1Click:Connect(function()
    if not _G.ASTHETIC_ManagerDrone then
        warn("[ASTHETIC] ManagerDrone not loaded!")
        return
    end

    local NewState = not _G.ASTHETIC_ManagerDrone.IsEnabled()
    UpdateManagerUI(NewState)

    -- ✅ Call Enable/Disable (មិន Save Config)
    if NewState then
        _G.ASTHETIC_ManagerDrone.Enable()
    else
        _G.ASTHETIC_ManagerDrone.Disable()
    end
end)

--==================================================
-- ✅ SYNC STATE ON LOAD
--==================================================
task.spawn(function()
    task.wait(1)
    if _G.ASTHETIC_ManagerDrone then
        local State = _G.ASTHETIC_ManagerDrone.IsEnabled()
        UpdateManagerUI(State)
    end
end)

--==================================================
-- ✅ REFRESH FUNCTION
--==================================================
_G.ASTHETIC_RefreshEventUI = function()
    if _G.ASTHETIC_ManagerDrone then
        local State = _G.ASTHETIC_ManagerDrone.IsEnabled()
        UpdateManagerUI(State)
        print("[ASTHETIC] Event Tab UI Refreshed | State: " .. tostring(State))
    end
end

--==================================================
-- ✅ STATUS LABEL (mostra timer real do evento)
--==================================================
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 18)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: aguardando..."
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
StatusLabel.TextSize = 11
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.LayoutOrder = 3
StatusLabel.Parent = EventPage

local function UpdateStatusLabel()
    if not _G.ASTHETIC_ManagerDrone then
        StatusLabel.Text = "Status: ManagerDrone não carregado!"
        return
    end
    local ok, sec, txt, active = pcall(function()
        if _G.ASTHETIC_ManagerDrone.GetLastEvent then
            return _G.ASTHETIC_ManagerDrone.GetLastEvent()
        else
            local s, t, a = _G.ASTHETIC_ManagerDrone.GetEventInfo()
            return s, t, a
        end
    end)
    if not ok then
        StatusLabel.Text = "Status: erro ao ler evento"
        return
    end
    if txt == nil or txt == "" then
        StatusLabel.Text = "Status: HUD do evento não encontrado"
    elseif active then
        StatusLabel.Text = "Status: EVENTO ATIVO | " .. tostring(txt) .. " (" .. tostring(sec) .. "s)"
    else
        StatusLabel.Text = "Status: sem evento | " .. tostring(txt)
    end
end

--==================================================
-- ✅ PERIODIC SYNC (para quando GUI for destruída)
--==================================================
task.spawn(function()
    while task.wait(0.5) do
        if not ManagerHolder.Parent then break end
        if _G.ASTHETIC_ManagerDrone then
            local CurrentState = _G.ASTHETIC_ManagerDrone.IsEnabled()
            local UIState = ManagerCheck.Visible

            if CurrentState ~= UIState then
                UpdateManagerUI(CurrentState)
                print("[ASTHETIC] Event UI Sync | State: " .. tostring(CurrentState))
            end
            pcall(UpdateStatusLabel)
        else
            StatusLabel.Text = "Status: ManagerDrone não carregado!"
        end
    end
end)

print("✅ Event Tab Loaded")
