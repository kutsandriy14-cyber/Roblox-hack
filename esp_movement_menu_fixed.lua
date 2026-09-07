-- Запускать напрямую как LocalScript в StarterPlayerScripts или StarterGui.
--[[
    ESP + MOVEMENT DEBUG MENU
    Для собственного Roblox-плейса.

    Управление:
    - RightShift: открыть/скрыть меню после закрытия.
    - Fly: WASD, Space вверх, LeftControl вниз.

    Важно: это клиентский отладочный LocalScript. Telegram-верификация
    здесь намеренно не используется: надёжная проверка требует серверной
    части и внешнего HTTPS-сервера.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CONFIG = {
    MaxDistance = 500,
    WalkSpeed = 16,
    JumpPower = 50,
    FlySpeed = 70,
    Theme = Color3.fromRGB(112, 92, 255),
}

local state = {
    EspEnabled = true,
    FlyEnabled = false,
    MenuVisible = true,
    ActiveTab = "ESP",
}

local espObjects = {}
local flyConnection
local flyVelocity
local flyGyro
local keys = {}

local function getCharacterRoot()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getColor(player)
    if player.Team then
        return player.Team.TeamColor.Color
    end
    return Color3.fromRGB(255, 95, 105)
end

local function removeESP(player)
    local data = espObjects[player]
    if not data then return end
    if data.Highlight then data.Highlight:Destroy() end
    if data.Billboard then data.Billboard:Destroy() end
    espObjects[player] = nil
end

local function createESP(player, character)
    if player == LocalPlayer then return end
    removeESP(player)

    local root = character:WaitForChild("HumanoidRootPart", 5)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "DebugESP"
    highlight.Adornee = character
    highlight.FillColor = getColor(player)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Enabled = state.EspEnabled
    highlight.Parent = character

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPInfo"
    billboard.Adornee = root
    billboard.Size = UDim2.fromOffset(230, 58)
    billboard.StudsOffset = Vector3.new(0, 3.25, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = state.EspEnabled
    billboard.Parent = character

    local label = Instance.new("TextLabel")
    label.Name = "Info"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = getColor(player)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0.15
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextWrapped = true
    label.Parent = billboard

    espObjects[player] = {
        Character = character,
        Root = root,
        Humanoid = humanoid,
        Highlight = highlight,
        Billboard = billboard,
        Label = label,
    }
end

local function trackPlayer(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(character)
        createESP(player, character)
    end)
    player.CharacterRemoving:Connect(function()
        removeESP(player)
    end)
    if player.Character then createESP(player, player.Character) end
end

for _, player in ipairs(Players:GetPlayers()) do trackPlayer(player) end
Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(removeESP)

local gui = Instance.new("ScreenGui")
gui.Name = "DebugToolsGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(70, 70, 90)
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = parent
    return s
end

local function label(parent, text, size, position, fontSize, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = color or Color3.fromRGB(230, 230, 240)
    l.Font = Enum.Font.Gotham
    l.TextSize = fontSize or 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = size
    l.Position = position
    l.Parent = parent
    return l
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(390, 300)
main.Position = UDim2.new(0.5, -195, 0.5, -150)
main.BackgroundColor3 = Color3.fromRGB(19, 19, 28)
main.BorderSizePixel = 0
main.Parent = gui
corner(main, 12)
stroke(main, Color3.fromRGB(68, 64, 105), 1)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 48)
top.BackgroundColor3 = Color3.fromRGB(28, 27, 42)
top.BorderSizePixel = 0
top.Parent = main
corner(top, 12)

label(top, "DEBUG TOOLS", UDim2.new(1, -120, 0, 20), UDim2.fromOffset(16, 7), 16, Color3.fromRGB(255,255,255)).Font = Enum.Font.GothamBold
label(top, "kentikvr • private test", UDim2.new(1, -120, 0, 16), UDim2.fromOffset(16, 27), 10, Color3.fromRGB(150, 148, 175))

local function topButton(text, x, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(30, 28)
    b.Position = UDim2.new(1, x, 0, 10)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.AutoButtonColor = true
    b.Parent = top
    corner(b, 7)
    return b
end

local minimize = topButton("—", -70, Color3.fromRGB(65, 63, 88))
local close = topButton("×", -34, Color3.fromRGB(145, 57, 72))

local tabs = Instance.new("Frame")
tabs.Size = UDim2.fromOffset(112, 234)
tabs.Position = UDim2.fromOffset(10, 57)
tabs.BackgroundColor3 = Color3.fromRGB(24, 24, 35)
tabs.BorderSizePixel = 0
tabs.Parent = main
corner(tabs, 9)

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -137, 1, -67)
content.Position = UDim2.fromOffset(127, 57)
content.BackgroundTransparency = 1
content.Parent = main

local tabButtons = {}
local pages = {}

local function makeTab(name, text, y)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -14, 0, 42)
    b.Position = UDim2.fromOffset(7, y)
    b.BackgroundColor3 = Color3.fromRGB(35, 34, 50)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(205, 203, 220)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Parent = tabs
    corner(b, 7)
    tabButtons[name] = b
    return b
end

local espTab = makeTab("ESP", "◉   ESP", 14)
local moveTab = makeTab("Movement", "↗   MOVEMENT", 62)

local espPage = Instance.new("Frame")
espPage.Size = UDim2.fromScale(1,1)
espPage.BackgroundTransparency = 1
espPage.Parent = content
pages.ESP = espPage

local movePage = Instance.new("Frame")
movePage.Size = UDim2.fromScale(1,1)
movePage.BackgroundTransparency = 1
movePage.Visible = false
movePage.Parent = content
pages.Movement = movePage

local function makeToggle(parent, text, y, initial, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 0, 38)
    b.Position = UDim2.fromOffset(6, y)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Parent = parent
    corner(b, 8)
    local enabled = initial
    local function refresh()
        b.Text = text .. (enabled and "     ON" or "     OFF")
        b.BackgroundColor3 = enabled and Color3.fromRGB(57, 139, 92) or Color3.fromRGB(75, 72, 91)
    end
    refresh()
    b.MouseButton1Click:Connect(function()
        enabled = not enabled
        refresh()
        callback(enabled)
    end)
    return b
end

local function makeInput(parent, title, value, y, callback)
    label(parent, title, UDim2.new(0.48, 0, 0, 25), UDim2.fromOffset(6, y), 13, Color3.fromRGB(205,203,220))
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.48, -6, 0, 30)
    box.Position = UDim2.new(0.52, 0, 0, y - 3)
    box.BackgroundColor3 = Color3.fromRGB(34, 33, 47)
    box.TextColor3 = Color3.fromRGB(255,255,255)
    box.Text = tostring(value)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 13
    box.ClearTextOnFocus = false
    box.Parent = parent
    corner(box, 7)
    stroke(box, Color3.fromRGB(65,63,90), 1)
    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            n = math.floor(n)
            box.Text = tostring(callback(n))
        else
            box.Text = tostring(value)
        end
    end)
    return box
end

makeToggle(espPage, "Player ESP", 7, state.EspEnabled, function(v) state.EspEnabled = v end)
makeInput(espPage, "Max distance", CONFIG.MaxDistance, 58, function(v)
    CONFIG.MaxDistance = math.clamp(v, 25, 5000)
    return CONFIG.MaxDistance
end)
label(espPage, "Shows name, distance and HP", UDim2.new(1, -12, 0, 25), UDim2.fromOffset(6, 105), 12, Color3.fromRGB(140,138,165))
label(espPage, "Only for your own game testing", UDim2.new(1, -12, 0, 25), UDim2.fromOffset(6, 130), 12, Color3.fromRGB(140,138,165))

local humanoid = function()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

makeInput(movePage, "WalkSpeed", CONFIG.WalkSpeed, 7, function(v)
    CONFIG.WalkSpeed = math.clamp(v, 0, 250)
    local h = humanoid(); if h then h.WalkSpeed = CONFIG.WalkSpeed end
    return CONFIG.WalkSpeed
end)
makeInput(movePage, "JumpPower", CONFIG.JumpPower, 49, function(v)
    CONFIG.JumpPower = math.clamp(v, 0, 250)
    local h = humanoid(); if h then h.UseJumpPower = true; h.JumpPower = CONFIG.JumpPower end
    return CONFIG.JumpPower
end)
makeInput(movePage, "Fly speed", CONFIG.FlySpeed, 91, function(v)
    CONFIG.FlySpeed = math.clamp(v, 10, 250)
    return CONFIG.FlySpeed
end)
makeToggle(movePage, "Fly", 138, state.FlyEnabled, function(v) state.FlyEnabled = v end)

local function selectTab(name)
    state.ActiveTab = name
    for tabName, page in pairs(pages) do
        page.Visible = (tabName == name)
        tabButtons[tabName].BackgroundColor3 = (tabName == name) and CONFIG.Theme or Color3.fromRGB(35,34,50)
        tabButtons[tabName].TextColor3 = (tabName == name) and Color3.new(1,1,1) or Color3.fromRGB(205,203,220)
    end
end
espTab.MouseButton1Click:Connect(function() selectTab("ESP") end)
moveTab.MouseButton1Click:Connect(function() selectTab("Movement") end)
selectTab("ESP")

local mini = Instance.new("TextButton")
mini.Name = "OpenButton"
mini.Size = UDim2.fromOffset(52, 52)
mini.Position = UDim2.fromOffset(20, 150)
mini.BackgroundColor3 = CONFIG.Theme
mini.Text = "ESP"
mini.TextColor3 = Color3.new(1,1,1)
mini.Font = Enum.Font.GothamBold
mini.TextSize = 14
mini.Visible = false
mini.Parent = gui
corner(mini, 12)
stroke(mini, Color3.fromRGB(190,185,255), 1)

local function setMenu(visible)
    state.MenuVisible = visible
    main.Visible = visible
    mini.Visible = not visible
end
minimize.MouseButton1Click:Connect(function() setMenu(false) end)
close.MouseButton1Click:Connect(function() setMenu(false) end)
mini.MouseButton1Click:Connect(function() setMenu(true) end)

local dragging = false
local dragStart, startPosition
local function beginDrag(input)
    dragging = true
    dragStart = input.Position
    startPosition = main.Position
    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then dragging = false end
    end)
end
top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then beginDrag(input) end
end)
UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStart
    main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then setMenu(not state.MenuVisible) end
    if input.UserInputType == Enum.UserInputType.Keyboard then keys[input.KeyCode] = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then keys[input.KeyCode] = false end
end)

local timer = 0
RunService.RenderStepped:Connect(function(dt)
    timer += dt
    if timer >= 0.1 then
        timer = 0
        local myRoot = getCharacterRoot()
        for player, data in pairs(espObjects) do
            if myRoot and data.Root and data.Root.Parent and data.Humanoid then
                local distance = (myRoot.Position - data.Root.Position).Magnitude
                local visible = state.EspEnabled and distance <= CONFIG.MaxDistance and data.Humanoid.Health > 0
                data.Highlight.Enabled = visible
                data.Billboard.Enabled = visible
                if visible then
                    data.Label.Text = string.format("%s\n%d studs | HP: %d/%d", player.DisplayName, math.floor(distance), math.floor(data.Humanoid.Health), math.floor(data.Humanoid.MaxHealth))
                end
            else
                removeESP(player)
            end
        end
    end

    if state.FlyEnabled then
        local root = getCharacterRoot()
        if root then
            if not flyVelocity then
                flyVelocity = Instance.new("BodyVelocity")
                flyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
                flyVelocity.Parent = root
                flyGyro = Instance.new("BodyGyro")
                flyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
                flyGyro.P = 1e5
                flyGyro.Parent = root
            end
            local camera = workspace.CurrentCamera
            local direction = Vector3.zero
            if keys[Enum.KeyCode.W] then direction += camera.CFrame.LookVector end
            if keys[Enum.KeyCode.S] then direction -= camera.CFrame.LookVector end
            if keys[Enum.KeyCode.D] then direction += camera.CFrame.RightVector end
            if keys[Enum.KeyCode.A] then direction -= camera.CFrame.RightVector end
            if keys[Enum.KeyCode.Space] then direction += Vector3.yAxis end
            if keys[Enum.KeyCode.LeftControl] then direction -= Vector3.yAxis end
            flyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * CONFIG.FlySpeed or Vector3.zero
            flyGyro.CFrame = camera.CFrame
        end
    elseif flyVelocity then
        flyVelocity:Destroy(); flyVelocity = nil
        if flyGyro then flyGyro:Destroy(); flyGyro = nil end
    end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    local h = character:WaitForChild("Humanoid", 5)
    if h then
        h.WalkSpeed = CONFIG.WalkSpeed
        h.UseJumpPower = true
        h.JumpPower = CONFIG.JumpPower
    end
end)

print("Debug Tools loaded. Press RightShift to toggle the menu.")
