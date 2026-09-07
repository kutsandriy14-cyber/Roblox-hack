-- Запускать через executor:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/kutsandriy14-cyber/Roblox-hack/refs/heads/main/esp_movement_menu.lua"))()
-- или просто скопировать содержимое в executor.
--[[
    ESP + MOVEMENT DEBUG MENU
    Для собственного Roblox-плейса.

    Управление:
    - RightShift: открыть/скрыть меню после закрытия.
    - Fly: WASD, Space вверх, LeftControl вниз.
]]

if game and game.GetService then -- стандартная среда Roblox
    if getgenv and getgenv().__ESP_MOVEMENT_MENU_LOADED then
        warn("[DebugTools] уже запущен, повторный запуск игнорирую")
        return
    end
    if getgenv then getgenv().__ESP_MOVEMENT_MENU_LOADED = true end
end

local ok, err = pcall(function()
-- всё тело скрипта внутри этого блока
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CONFIG = {
    MaxDistance = 500,
    WalkSpeed = 16,
    JumpPower = 50,
    FlySpeed = 70,
    InfiniteJump = false,
    AimFov = 90,
    AimSmoothness = 5,
    AimTargetPart = "Head",
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
main.Size = UDim2.fromOffset(390, 480)
main.Position = UDim2.new(0.5, -195, 0.5, -240)
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
content.Name = "Content"
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
local aimTab = makeTab("AIM", "◎   AIM", 110)

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

local aimPage = Instance.new("Frame")
aimPage.Size = UDim2.fromScale(1,1)
aimPage.BackgroundTransparency = 1
aimPage.Visible = false
aimPage.Parent = content
pages.AIM = aimPage

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

-- Тумблеры для каждого чит-параметра: имя → ключ в state, дефолт.
state.SpeedEnabled = false
state.JumpEnabled = false
state.NoClipEnabled = false
state.AimEnabled = false
state.AimShowFov = true
state.AimHoldRightMouse = true

makeToggle(movePage, "Speed Hack", 7, state.SpeedEnabled, function(v) state.SpeedEnabled = v end)
makeInput(movePage, "Speed value", CONFIG.WalkSpeed, 51, function(v)
    CONFIG.WalkSpeed = math.clamp(v, 0, 500)
    return CONFIG.WalkSpeed
end)
makeToggle(movePage, "High Jump", 102, state.JumpEnabled, function(v) state.JumpEnabled = v end)
makeInput(movePage, "Jump value", CONFIG.JumpPower, 146, function(v)
    CONFIG.JumpPower = math.clamp(v, 0, 500)
    return CONFIG.JumpPower
end)
makeToggle(movePage, "Fly", 197, state.FlyEnabled, function(v) state.FlyEnabled = v end)
makeInput(movePage, "Fly speed", CONFIG.FlySpeed, 241, function(v)
    CONFIG.FlySpeed = math.clamp(v, 10, 500)
    return CONFIG.FlySpeed
end)
makeToggle(movePage, "Infinite Jump", 292, CONFIG.InfiniteJump, function(v) CONFIG.InfiniteJump = v end)
makeToggle(movePage, "No Clip", 336, state.NoClipEnabled, function(v) state.NoClipEnabled = v end)

-- Вкладка AIM
makeToggle(aimPage, "Aimbot", 7, state.AimEnabled, function(v) state.AimEnabled = v end)
makeToggle(aimPage, "Hold Right Mouse", 51, state.AimHoldRightMouse, function(v) state.AimHoldRightMouse = v end)
makeToggle(aimPage, "Show FOV Circle", 95, state.AimShowFov, function(v) state.AimShowFov = v end)
makeInput(aimPage, "FOV (deg)", CONFIG.AimFov, 146, function(v)
    CONFIG.AimFov = math.clamp(v, 10, 360)
    return CONFIG.AimFov
end)
makeInput(aimPage, "Smoothness", CONFIG.AimSmoothness, 190, function(v)
    CONFIG.AimSmoothness = math.clamp(v, 1, 30)
    return CONFIG.AimSmoothness
end)
label(aimPage, "Target part: Head (default)", UDim2.new(1, -12, 0, 25), UDim2.fromOffset(6, 245), 12, Color3.fromRGB(140,138,165))
label(aimPage, "Works while holding Right Mouse", UDim2.new(1, -12, 0, 25), UDim2.fromOffset(6, 268), 12, Color3.fromRGB(140,138,165))

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
aimTab.MouseButton1Click:Connect(function() selectTab("AIM") end)
selectTab("ESP")

-- Кольцо FOV через Drawing (если executor даёт) — тонкое, яркое, не мешает.
local fovCircle
if Drawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Visible = false
    fovCircle.Color = Color3.fromRGB(255, 90, 100)
    fovCircle.Thickness = 1
    fovCircle.Filled = false
    fovCircle.Transparency = 0.6
end

local aimRightMouseDown = false
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimRightMouseDown = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimRightMouseDown = false
    end
end)

-- Аим-бот: ищем ближайшую цель в FOV от центра экрана и плавно
-- наводим камеру. Безопасно: меняем только локальный CFrame камеры.
local function getAimTarget()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end
    local camera = Workspace.CurrentCamera
    local best, bestDist = nil, CONFIG.AimFov
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            local head = player.Character:FindFirstChild("Head")
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            local part = (CONFIG.AimTargetPart == "HumanoidRootPart") and root or head
            if hum and hum.Health > 0 and part then
                -- пропускаем тиммейтов
                if LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
                    continue
                end
                local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    local maxPx = math.tan(math.rad(CONFIG.AimFov / 2)) * (camera.ViewportSize.Y / 2) * 2
                    if dist <= maxPx and dist < bestDist then
                        best = part
                        bestDist = dist
                    end
                end
            end
        end
    end
    return best
end

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

-- Infinite Jump: слушаем JumpRequest (это событие посылается на любую
-- клавишу прыжка/тачскрин), и форсим состояние Jumping.
UserInputService.JumpRequest:Connect(function()
    if CONFIG.InfiniteJump then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
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

    -- Fly: CFrame-двигание + временное отключение гравитации.
    -- BodyVelocity/BodyGyro серверные плееры часто обнуляют, поэтому
    -- CFrame-двигание работает почти везде.
    if state.FlyEnabled then
        local root = getCharacterRoot()
        if root then
            if not flyVelocity then
                -- первый кадр полёта: запоминаем гравитацию и отключаем
                flyVelocity = { savedGravity = Workspace.Gravity }
                Workspace.Gravity = 0
                local hum = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
                if hum then hum.PlatformStand = true end
            end
            local camera = Workspace.CurrentCamera
            local direction = Vector3.zero
            if keys[Enum.KeyCode.W] then direction += camera.CFrame.LookVector end
            if keys[Enum.KeyCode.S] then direction -= camera.CFrame.LookVector end
            if keys[Enum.KeyCode.D] then direction += camera.CFrame.RightVector end
            if keys[Enum.KeyCode.A] then direction -= camera.CFrame.RightVector end
            if keys[Enum.KeyCode.Space] then direction += Vector3.yAxis end
            if keys[Enum.KeyCode.LeftControl] then direction -= Vector3.yAxis end
            if direction.Magnitude > 0 then
                root.CFrame = root.CFrame + direction.Unit * CONFIG.FlySpeed * dt
            end
            root.CFrame = CFrame.new(root.Position) * (camera.CFrame - camera.CFrame.Position)
        end
    elseif flyVelocity then
        Workspace.Gravity = flyVelocity.savedGravity or 196.2
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
        flyVelocity = nil
        if flyGyro then flyGyro = nil end
    end

    -- Форс WalkSpeed / JumpPower — только если соответствующий тумблер ON.
    -- Иначе оставляем дефолтные значения, чтобы не ломать плеер.
    local myChar = LocalPlayer.Character
    if myChar then
        local hum = myChar:FindFirstChildOfClass("Humanoid")
        if hum then
            local targetSpeed = state.SpeedEnabled and CONFIG.WalkSpeed or 16
            local targetJump = state.JumpEnabled and CONFIG.JumpPower or 50
            if hum.WalkSpeed ~= targetSpeed then hum.WalkSpeed = targetSpeed end
            if hum.UseJumpPower ~= true then hum.UseJumpPower = true end
            if hum.JumpPower ~= targetJump then hum.JumpPower = targetJump end
        end
    end

    -- No Clip: отключаем коллизии у всех частей персонажа, пока тумблер ON.
    if state.NoClipEnabled then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end

    -- Aimbot: плавно наводим камеру на ближайшую цель в FOV.
    if state.AimEnabled and (state.AimHoldRightMouse == false or aimRightMouseDown) then
        local target = getAimTarget()
        if target then
            local camera = Workspace.CurrentCamera
            local targetPos = target.Position
            local aimCF = CFrame.lookAt(camera.CFrame.Position, targetPos)
            -- плавность: smoothness = 1 = моментально, выше = плавнее
            local alpha = 1 / math.max(1, CONFIG.AimSmoothness)
            camera.CFrame = camera.CFrame:Lerp(aimCF, alpha)
        end
    end

    -- FOV-кольцо: рисуем только когда тумблер Show FOV включён.
    if fovCircle then
        if state.AimShowFov and state.AimEnabled then
            local camera = Workspace.CurrentCamera
            fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
            local radiusPx = math.tan(math.rad(CONFIG.AimFov / 2)) * (camera.ViewportSize.Y / 2) * 2
            fovCircle.Radius = radiusPx
            fovCircle.Visible = true
        else
            fovCircle.Visible = false
        end
    end
end)

-- Анти-античит: навешиваем на Humanoid моментальный откат WalkSpeed/JumpPower,
-- если серверный скрипт их перезаписывает. Работает через GetPropertyChangedSignal —
-- реагирует за один кадр, без задержки.
local function bindForce(character)
    local hum = character:WaitForChild("Humanoid", 5)
    if not hum then return end

    local function forceNow()
        if not hum or not hum.Parent then return end
        if state.SpeedEnabled and hum.WalkSpeed ~= CONFIG.WalkSpeed then
            hum.WalkSpeed = CONFIG.WalkSpeed
        end
        if state.JumpEnabled then
            if hum.UseJumpPower ~= true then hum.UseJumpPower = true end
            if hum.JumpPower ~= CONFIG.JumpPower then
                hum.JumpPower = CONFIG.JumpPower
            end
        end
    end

    forceNow()
    -- моментальный откат при любом изменении свойства
    hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if state.SpeedEnabled and hum.WalkSpeed ~= CONFIG.WalkSpeed then
            hum.WalkSpeed = CONFIG.WalkSpeed
        end
    end)
    hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if state.JumpEnabled and hum.JumpPower ~= CONFIG.JumpPower then
            hum.JumpPower = CONFIG.JumpPower
        end
    end)
    hum:GetPropertyChangedSignal("UseJumpPower"):Connect(function()
        if state.JumpEnabled and hum.UseJumpPower ~= true then
            hum.UseJumpPower = true
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(bindForce)
-- если персонаж уже есть (CharacterAutoLoads), привязаться к нему
if LocalPlayer.Character then
    task.spawn(bindForce, LocalPlayer.Character)
end

-- Перехват сеттера на уровне метатаблицы. Если executor даёт hookmetamethod —
-- блокируем попытки сервера/анти-чита перезаписать WalkSpeed/JumpPower.
-- Это второй эшелон: первый — GetPropertyChangedSignal, второй — перехват сеттера.
if hookmetamethod and newcclosure then
    local blocked = 0
    local oldIndex
    pcall(function()
        oldIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
            if self and self:IsA("Humanoid") then
                if key == "WalkSpeed" and state.SpeedEnabled and value ~= CONFIG.WalkSpeed then
                    blocked += 1
                    return oldIndex(self, key, CONFIG.WalkSpeed)  -- откатываем
                end
                if key == "JumpPower" and state.JumpEnabled and value ~= CONFIG.JumpPower then
                    blocked += 1
                    return oldIndex(self, key, CONFIG.JumpPower)
                end
                if key == "UseJumpPower" and state.JumpEnabled and value ~= true then
                    return oldIndex(self, key, true)
                end
            end
            return oldIndex(self, key, value)
        end))
    end)
    if oldIndex then
        print("[DebugTools] hookmetamethod активен (анти-античит)")
    end
end

print("[DebugTools] loaded. Press RightShift to toggle the menu.")
-- конец тела скрипта
end)
if not ok then
    warn("[DebugTools] runtime error: " .. tostring(err))
end
