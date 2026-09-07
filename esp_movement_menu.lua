-- esp_movement_menu.lua
-- Универсальный чит-хаб для Roblox: ESP / Aimbot / Trigger Bot / Fly / Noclip / Hitbox Expander.
-- Запуск: loadstring(game:HttpGet("https://raw.githubusercontent.com/kutsandriy14-cyber/Roblox-hack/refs/heads/main/esp_movement_menu.lua"))()
-- Управление: RightShift — открыть/скрыть меню; ЛКМ-drag по плавающей кнопке Debug — перетащить.

if game and game.GetService and getgenv and getgenv().__ESP_MOVEMENT_MENU_LOADED then
    warn("[DebugTools] уже запущен, повторный запуск игнорирую")
    return
end
if getgenv then getgenv().__ESP_MOVEMENT_MENU_LOADED = true end

local ok, err = pcall(function()

------------------------------------------------------------
-- Services
------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

------------------------------------------------------------
-- Config / State
------------------------------------------------------------
local CONFIG = {
    -- ESP
    EspEnabled = true,
    EspMaxDistance = 800,
    EspBoxEnabled = true,
    EspVisibleOnly = false, -- тусклый цвет если за стеной
    -- Aimbot
    AimEnabled = false,
    AimHoldRMB = true,
    AimShowFov = true,
    AimFov = 90,
    AimSmoothness = 5,
    AimTargetPart = "Head",
    AimMaxDistance = 350,
    AimVisibleOnly = true,
    -- Trigger Bot
    TriggerEnabled = false,
    TriggerFov = 25,
    TriggerSmoothness = 2,
    TriggerTargetPart = "Head",
    TriggerMaxDistance = 250,
    TriggerVisibleOnly = true,
    TriggerDelayMs = 25, -- задержка между наведением и кликом
    TriggerHoldMode = true, -- стрелять только при зажатой ЛКМ
    -- Movement
    SpeedEnabled = false,
    WalkSpeed = 16,
    JumpEnabled = false,
    JumpPower = 50,
    FlyEnabled = false,
    FlyMethod = "CFrame", -- "CFrame" | "BodyMover"
    FlySpeed = 70,
    InfiniteJump = false,
    NoClipEnabled = false,
    -- Hitbox Expander
    HitboxEnabled = false,
    HitboxSize = 2, -- множитель
    HitboxMaxDistance = 600,
    -- Misc
    Theme = Color3.fromRGB(112, 92, 255),
}

local state = {
    MenuVisible = true,
    ActiveTab = "ESP",
    RightMouseDown = false,
    LeftMouseDown = false,
}

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local c = getCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local c = getCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getMyTeam()
    return LocalPlayer.Team
end

local function isAlly(player)
    if not player or player == LocalPlayer then return true end
    local myTeam = getMyTeam()
    if myTeam and player.Team and myTeam == player.Team then return true end
    return false
end

-- Raycast от нашей позиции к цели. Если луч не упёрся в стену — цель видимая.
-- Игнорируем: наш персонаж, персонаж цели (его собственные части), и любой
-- персонаж игрока в целом (т.к. его "собственная" геометрия не считается стеной).
local function isTargetVisible(targetPart)
    if not targetPart or not targetPart.Parent then return false end
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    local dist = direction.Magnitude
    if dist < 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = {}
    local myChar = getCharacter()
    if myChar then table.insert(filterList, myChar) end
    local targetChar = targetPart.Parent
    if targetChar then table.insert(filterList, targetChar) end
    params.FilterDescendantsInstances = filterList
    local result = Workspace:Raycast(origin, direction.Unit * dist, params)
    return result == nil
end

-- Получить список валидных целей в радиусе. targetPart = "Head"|"HumanoidRootPart".
local function getTargets(targetPartName, maxDist, visibleOnly)
    local list = {}
    local myRoot = getRoot()
    if not myRoot then return list end

    for _, player in ipairs(Players:GetPlayers()) do
        if not isAlly(player) and player.Character then
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            local part = player.Character:FindFirstChild(targetPartName)
            if hum and hum.Health > 0 and part and part:IsA("BasePart") then
                local dist = (myRoot.Position - part.Position).Magnitude
                if dist <= maxDist then
                    if not visibleOnly or isTargetVisible(part) then
                        table.insert(list, { player = player, part = part, hum = hum, dist = dist })
                    end
                end
            end
        end
    end

    return list
end

-- Лучшая цель в FOV от центра экрана (по убыванию близости к центру).
local function pickBestTarget(targets, fovDeg)
    local best, bestScore = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local maxPx = math.tan(math.rad(fovDeg / 2)) * (Camera.ViewportSize.Y / 2) * 2
    for _, t in ipairs(targets) do
        local screenPos, onScreen = Camera:WorldToViewportPoint(t.part.Position)
        if onScreen then
            local px = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
            if px <= maxPx and px < bestScore then
                best = t
                bestScore = px
            end
        end
    end
    return best
end

-- Симуляция клика мыши (для trigger bot).
local function fireClick()
    -- Приоритет: mouse1click (executor). Фолбэк: VirtualInputManager.
    if type(mouse1click) == "function" then
        pcall(mouse1click)
        return true
    end
    if type(mouse1press) == "function" and type(mouse1release) == "function" then
        pcall(mouse1press)
        task.delay(0.02, function() pcall(mouse1release) end)
        return true
    end
    -- Фолбэк для executor'ов с VirtualInputManager
    local vim = game:GetService("VirtualInputManager")
    if vim and vim.SendMouseButtonEvent then
        pcall(function()
            vim:SendMouseButtonEvent(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2, 0, true, game, 1)
            task.delay(0.02, function()
                pcall(function()
                    vim:SendMouseButtonEvent(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2, 0, false, game, 1)
                end)
            end)
        end)
        return true
    end
    return false
end

------------------------------------------------------------
-- UI helpers
------------------------------------------------------------
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

------------------------------------------------------------
-- GUI
------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "DebugToolsGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = PlayerGui
gui.IgnoreGuiInset = true

-- Плавающая кнопка (для вызова меню, можно перетаскивать)
local mini = Instance.new("TextButton")
mini.Name = "OpenButton"
mini.Size = UDim2.fromOffset(56, 56)
mini.Position = UDim2.fromOffset(20, 200)
mini.BackgroundColor3 = CONFIG.Theme
mini.Text = "DBG"
mini.TextColor3 = Color3.new(1, 1, 1)
mini.Font = Enum.Font.GothamBold
mini.TextSize = 14
mini.AutoButtonColor = true
mini.Visible = false
mini.Parent = gui
corner(mini, 14)
stroke(mini, Color3.fromRGB(190, 185, 255), 1)

-- Перетаскивание плавающей кнопки
do
    local dragging = false
    local dragStart, startPos
    mini.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mini.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        mini.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end)
    mini.MouseButton1Click:Connect(function()
        if not dragging then setMenu(true) end
    end)
end

-- Главное окно
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(420, 520)
main.Position = UDim2.new(0.5, -210, 0.5, -260)
main.BackgroundColor3 = Color3.fromRGB(19, 19, 28)
main.BorderSizePixel = 0
main.Visible = true
main.Parent = gui
corner(main, 12)
stroke(main, Color3.fromRGB(68, 64, 105), 1)

-- Шапка
local top = Instance.new("Frame")
top.Size = UDim2.new(1, 0, 0, 44)
top.BackgroundColor3 = Color3.fromRGB(28, 27, 42)
top.BorderSizePixel = 0
top.Parent = main
corner(top, 12)

label(top, "DEBUG TOOLS", UDim2.new(1, -120, 0, 20), UDim2.fromOffset(16, 6), 16, Color3.new(1,1,1)).Font = Enum.Font.GothamBold
label(top, "kentikvr • universal", UDim2.new(1, -120, 0, 14), UDim2.fromOffset(16, 24), 10, Color3.fromRGB(150, 148, 175))

local function topButton(text, x, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(30, 26)
    b.Position = UDim2.new(1, x, 0, 9)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = true
    b.Parent = top
    corner(b, 7)
    return b
end

local minimize = topButton("—", -70, Color3.fromRGB(65, 63, 88))
local close = topButton("×", -34, Color3.fromRGB(145, 57, 72))

-- Перетаскивание главного окна
do
    local dragging = false
    local dragStart, startPos
    top.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end)
end

-- Сайдбар вкладок
local tabs = Instance.new("Frame")
tabs.Size = UDim2.fromOffset(110, 0)
tabs.Position = UDim2.new(0, 0, 0, 44)
tabs.Size = UDim2.new(0, 110, 1, -44)
tabs.BackgroundColor3 = Color3.fromRGB(24, 24, 35)
tabs.BorderSizePixel = 0
tabs.Parent = main

local tabLayout = Instance.new("UIListLayout")
tabLayout.Padding = UDim.new(0, 4)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Parent = tabs

local tabPadding = Instance.new("UIPadding")
tabPadding.PaddingTop = UDim.new(0, 8)
tabPadding.Parent = tabs

-- Контент (ScrollingFrame для прокрутки)
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -118, 1, -52)
content.Position = UDim2.fromOffset(114, 48)
content.BackgroundTransparency = 1
content.ClipsDescendants = true
content.Parent = main

local tabButtons = {}
local pages = {}
local pageOrder = { "ESP", "Movement", "AIM", "Trigger", "Misc" }

local function makeTab(name, text, order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -10, 0, 38)
    b.LayoutOrder = order
    b.BackgroundColor3 = Color3.fromRGB(35, 34, 50)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(205, 203, 220)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.AutoButtonColor = true
    b.Parent = tabs
    corner(b, 7)
    tabButtons[name] = b
    return b
end

for i, name in ipairs(pageOrder) do
    makeTab(name, ({
        ESP = "◉   ESP",
        Movement = "↗   MOVE",
        AIM = "◎   AIM",
        Trigger = "⌖   TRIG",
        Misc = "⚙   MISC",
    })[name], i)
end

-- Каждая вкладка — ScrollingFrame
local function makePage(name)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = name .. "Page"
    sf.Size = UDim2.fromScale(1, 1)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 4
    sf.ScrollBarImageColor3 = CONFIG.Theme
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Visible = (name == state.ActiveTab)
    sf.Parent = content
    pages[name] = sf
    return sf
end

for _, name in ipairs(pageOrder) do
    makePage(name)
end

-- Компоненты UI внутри ScrollingFrame
local function makeToggle(parent, text, y, initial, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 0, 36)
    b.Position = UDim2.fromOffset(6, y)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextColor3 = Color3.new(1, 1, 1)
    b.AutoButtonColor = true
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
    label(parent, title, UDim2.new(0.46, 0, 0, 22), UDim2.fromOffset(6, y), 12, Color3.fromRGB(205, 203, 220))
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.5, -8, 0, 28)
    box.Position = UDim2.new(0.5, 2, 0, y - 3)
    box.BackgroundColor3 = Color3.fromRGB(34, 33, 47)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Text = tostring(value)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.Parent = parent
    corner(box, 7)
    stroke(box, Color3.fromRGB(65, 63, 90), 1)
    box.FocusLost:Connect(function(enterPressed)
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

local function makeSegmented(parent, title, options, y, default, callback)
    label(parent, title, UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, y), 12, Color3.fromRGB(205, 203, 220))
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -12, 0, 28)
    row.Position = UDim2.fromOffset(6, y + 22)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local buttons = {}
    local current = default
    local each = (1 - 12 / row.AbsoluteSize.X) -- placeholder, override below

    for i, opt in ipairs(options) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1 / #options, -2, 1, 0)
        b.Position = UDim2.new((i - 1) / #options, 2 * (i - 1), 0, 0)
        b.BackgroundColor3 = (opt == current) and CONFIG.Theme or Color3.fromRGB(40, 39, 56)
        b.Text = opt
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.AutoButtonColor = true
        b.Parent = row
        corner(b, 6)
        buttons[opt] = b
        b.MouseButton1Click:Connect(function()
            current = opt
            for k, v in pairs(buttons) do
                v.BackgroundColor3 = (k == current) and CONFIG.Theme or Color3.fromRGB(40, 39, 56)
            end
            callback(opt)
        end)
    end
end

local function makeSectionTitle(parent, text, y)
    local l = label(parent, text, UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, y), 12, Color3.fromRGB(180, 178, 200))
    l.Font = Enum.Font.GothamBold
end

------------------------------------------------------------
-- ESP
------------------------------------------------------------
local espObjects = {}

local function removeESP(player)
    local data = espObjects[player]
    if not data then return end
    if data.Highlight then data.Highlight:Destroy() end
    if data.Billboard then data.Billboard:Destroy() end
    if data.BoxFrame then data.BoxFrame:Destroy() end
    espObjects[player] = nil
end

local function getTeamColor(player)
    if player.Team and player.Team.TeamColor then return player.Team.TeamColor.Color end
    return Color3.fromRGB(255, 95, 105)
end

local function createESP(player, character)
    if player == LocalPlayer then return end
    removeESP(player)
    local root = character:WaitForChild("HumanoidRootPart", 5)
    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid then return end

    local color = getTeamColor(player)

    local highlight = Instance.new("Highlight")
    highlight.Name = "DebugESP"
    highlight.Adornee = character
    highlight.FillColor = color
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.FillTransparency = 0.55
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Enabled = CONFIG.EspEnabled
    highlight.Parent = character

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPInfo"
    billboard.Adornee = head or root
    billboard.Size = UDim2.fromOffset(220, 50)
    billboard.StudsOffset = Vector3.new(0, 2.8, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = CONFIG.EspEnabled
    billboard.Parent = character

    local text = Instance.new("TextLabel")
    text.Name = "Info"
    text.Size = UDim2.fromScale(1, 1)
    text.BackgroundTransparency = 1
    text.TextColor3 = color
    text.TextStrokeColor3 = Color3.new(0, 0, 0)
    text.TextStrokeTransparency = 0.15
    text.Font = Enum.Font.GothamBold
    text.TextSize = 13
    text.TextWrapped = true
    text.Parent = billboard

    espObjects[player] = {
        Character = character,
        Root = root,
        Humanoid = humanoid,
        Highlight = highlight,
        Billboard = billboard,
        Label = text,
    }
end

local function trackPlayer(player)
    if player == LocalPlayer then return end
    player.CharacterAdded:Connect(function(character) createESP(player, character) end)
    player.CharacterRemoving:Connect(function() removeESP(player) end)
    if player.Character then createESP(player, player.Character) end
end

for _, player in ipairs(Players:GetPlayers()) do trackPlayer(player) end
Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(removeESP)

------------------------------------------------------------
-- UI: страницы
------------------------------------------------------------
local espPage = pages.ESP
local movePage = pages.Movement
local aimPage = pages.AIM
local trigPage = pages.Trigger
local miscPage = pages.Misc

-- === ESP ===
makeSectionTitle(espPage, "ESP", 6)
makeToggle(espPage, "Player ESP", 26, CONFIG.EspEnabled, function(v) CONFIG.EspEnabled = v end)
makeToggle(espPage, "Visible Only (dim if behind wall)", 68, CONFIG.EspVisibleOnly, function(v) CONFIG.EspVisibleOnly = v end)
makeInput(espPage, "Max distance (studs)", CONFIG.EspMaxDistance, 110, function(v)
    CONFIG.EspMaxDistance = math.clamp(v, 25, 5000)
    return CONFIG.EspMaxDistance
end)

-- === Movement ===
makeSectionTitle(movePage, "Movement", 6)
makeToggle(movePage, "Speed Hack", 26, CONFIG.SpeedEnabled, function(v) CONFIG.SpeedEnabled = v end)
makeInput(movePage, "WalkSpeed", CONFIG.WalkSpeed, 68, function(v)
    CONFIG.WalkSpeed = math.clamp(v, 0, 500)
    return CONFIG.WalkSpeed
end)
makeToggle(movePage, "High Jump", 110, CONFIG.JumpEnabled, function(v) CONFIG.JumpEnabled = v end)
makeInput(movePage, "JumpPower", CONFIG.JumpPower, 152, function(v)
    CONFIG.JumpPower = math.clamp(v, 0, 500)
    return CONFIG.JumpPower
end)
makeToggle(movePage, "Fly", 194, CONFIG.FlyEnabled, function(v) CONFIG.FlyEnabled = v end)
makeSegmented(movePage, "Fly method", { "CFrame", "BodyMover" }, 236, CONFIG.FlyMethod, function(v) CONFIG.FlyMethod = v end)
makeInput(movePage, "Fly speed", CONFIG.FlySpeed, 296, function(v)
    CONFIG.FlySpeed = math.clamp(v, 10, 500)
    return CONFIG.FlySpeed
end)
makeToggle(movePage, "Infinite Jump", 340, CONFIG.InfiniteJump, function(v) CONFIG.InfiniteJump = v end)
makeToggle(movePage, "No Clip (universal)", 382, CONFIG.NoClipEnabled, function(v) CONFIG.NoClipEnabled = v end)

-- === AIM ===
makeSectionTitle(aimPage, "Aimbot", 6)
makeToggle(aimPage, "Aimbot", 26, CONFIG.AimEnabled, function(v) CONFIG.AimEnabled = v end)
makeToggle(aimPage, "Hold Right Mouse", 68, CONFIG.AimHoldRMB, function(v) CONFIG.AimHoldRMB = v end)
makeToggle(aimPage, "Visible Only (skip behind walls)", 110, CONFIG.AimVisibleOnly, function(v) CONFIG.AimVisibleOnly = v end)
makeToggle(aimPage, "Show FOV Circle", 152, CONFIG.AimShowFov, function(v) CONFIG.AimShowFov = v end)
makeInput(aimPage, "FOV (deg)", CONFIG.AimFov, 194, function(v)
    CONFIG.AimFov = math.clamp(v, 5, 360)
    return CONFIG.AimFov
end)
makeInput(aimPage, "Smoothness (1=snappy)", CONFIG.AimSmoothness, 236, function(v)
    CONFIG.AimSmoothness = math.clamp(v, 1, 30)
    return CONFIG.AimSmoothness
end)
makeInput(aimPage, "Max distance (studs)", CONFIG.AimMaxDistance, 278, function(v)
    CONFIG.AimMaxDistance = math.clamp(v, 25, 5000)
    return CONFIG.AimMaxDistance
end)
makeSegmented(aimPage, "Target part", { "Head", "HumanoidRootPart" }, 320, CONFIG.AimTargetPart, function(v) CONFIG.AimTargetPart = v end)

-- === Trigger ===
makeSectionTitle(trigPage, "Trigger Bot", 6)
makeToggle(trigPage, "Trigger Bot", 26, CONFIG.TriggerEnabled, function(v) CONFIG.TriggerEnabled = v end)
makeToggle(trigPage, "Fire only when LMB held", 68, CONFIG.TriggerHoldMode, function(v) CONFIG.TriggerHoldMode = v end)
makeToggle(trigPage, "Visible Only (skip behind walls)", 110, CONFIG.TriggerVisibleOnly, function(v) CONFIG.TriggerVisibleOnly = v end)
makeInput(trigPage, "FOV (deg)", CONFIG.TriggerFov, 152, function(v)
    CONFIG.TriggerFov = math.clamp(v, 1, 90)
    return CONFIG.TriggerFov
end)
makeInput(trigPage, "Aim smoothness (1=snappy)", CONFIG.TriggerSmoothness, 194, function(v)
    CONFIG.TriggerSmoothness = math.clamp(v, 1, 30)
    return CONFIG.TriggerSmoothness
end)
makeInput(trigPage, "Max distance (studs)", CONFIG.TriggerMaxDistance, 236, function(v)
    CONFIG.TriggerMaxDistance = math.clamp(v, 25, 2000)
    return CONFIG.TriggerMaxDistance
end)
makeInput(trigPage, "Click delay (ms)", CONFIG.TriggerDelayMs, 278, function(v)
    CONFIG.TriggerDelayMs = math.clamp(v, 0, 500)
    return CONFIG.TriggerDelayMs
end)
makeSegmented(trigPage, "Target part", { "Head", "HumanoidRootPart", "Humanoid" }, 320, CONFIG.TriggerTargetPart, function(v) CONFIG.TriggerTargetPart = v end)

-- === Misc ===
makeSectionTitle(miscPage, "Hitbox Expander", 6)
makeToggle(miscPage, "Expand Hitboxes", 26, CONFIG.HitboxEnabled, function(v) CONFIG.HitboxEnabled = v end)
makeInput(miscPage, "Size multiplier", CONFIG.HitboxSize, 68, function(v)
    CONFIG.HitboxSize = math.clamp(v, 1, 10)
    return CONFIG.HitboxSize
end)
makeInput(miscPage, "Max distance (studs)", CONFIG.HitboxMaxDistance, 110, function(v)
    CONFIG.HitboxMaxDistance = math.clamp(v, 25, 3000)
    return CONFIG.HitboxMaxDistance
end)

-- Переключение вкладок
local function selectTab(name)
    state.ActiveTab = name
    for tabName, page in pairs(pages) do
        page.Visible = (tabName == name)
        local btn = tabButtons[tabName]
        if btn then
            btn.BackgroundColor3 = (tabName == name) and CONFIG.Theme or Color3.fromRGB(35, 34, 50)
            btn.TextColor3 = (tabName == name) and Color3.new(1, 1, 1) or Color3.fromRGB(205, 203, 220)
        end
    end
end
for _, name in ipairs(pageOrder) do
    tabButtons[name].MouseButton1Click:Connect(function() selectTab(name) end)
end
selectTab(state.ActiveTab)

------------------------------------------------------------
-- Сворачивание/закрытие меню
------------------------------------------------------------
local function setMenu(visible)
    state.MenuVisible = visible
    main.Visible = visible
    mini.Visible = not visible
end
minimize.MouseButton1Click:Connect(function() setMenu(false) end)
close.MouseButton1Click:Connect(function() setMenu(false) end)

------------------------------------------------------------
-- Input
------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then setMenu(not state.MenuVisible) end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        state.RightMouseDown = true
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        state.LeftMouseDown = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        state.RightMouseDown = false
    end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        state.LeftMouseDown = false
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if CONFIG.InfiniteJump then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

------------------------------------------------------------
-- FOV Circle (Drawing)
------------------------------------------------------------
local aimFovCircle, trigFovCircle
if Drawing then
    aimFovCircle = Drawing.new("Circle")
    aimFovCircle.Visible = false
    aimFovCircle.Color = Color3.fromRGB(255, 90, 100)
    aimFovCircle.Thickness = 1
    aimFovCircle.Filled = false
    aimFovCircle.Transparency = 0.6

    trigFovCircle = Drawing.new("Circle")
    trigFovCircle.Visible = false
    trigFovCircle.Color = Color3.fromRGB(120, 220, 120)
    trigFovCircle.Thickness = 1
    trigFovCircle.Filled = false
    trigFovCircle.Transparency = 0.6
end

------------------------------------------------------------
-- Анти-античит: моментальный откат WalkSpeed/JumpPower
------------------------------------------------------------
local function bindForce(character)
    local hum = character:WaitForChild("Humanoid", 5)
    if not hum then return end
    local function forceNow()
        if not hum or not hum.Parent then return end
        if CONFIG.SpeedEnabled and hum.WalkSpeed ~= CONFIG.WalkSpeed then
            hum.WalkSpeed = CONFIG.WalkSpeed
        end
        if CONFIG.JumpEnabled then
            if hum.UseJumpPower ~= true then hum.UseJumpPower = true end
            if hum.JumpPower ~= CONFIG.JumpPower then hum.JumpPower = CONFIG.JumpPower end
        end
    end
    forceNow()
    hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if CONFIG.SpeedEnabled and hum.WalkSpeed ~= CONFIG.WalkSpeed then
            hum.WalkSpeed = CONFIG.WalkSpeed
        end
    end)
    hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if CONFIG.JumpEnabled and hum.JumpPower ~= CONFIG.JumpPower then
            hum.JumpPower = CONFIG.JumpPower
        end
    end)
    hum:GetPropertyChangedSignal("UseJumpPower"):Connect(function()
        if CONFIG.JumpEnabled and hum.UseJumpPower ~= true then
            hum.UseJumpPower = true
        end
    end)
end
LocalPlayer.CharacterAdded:Connect(bindForce)
if LocalPlayer.Character then task.spawn(bindForce, LocalPlayer.Character) end

-- hookmetamethod перехват
if hookmetamethod and newcclosure then
    pcall(function()
        local oldIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
            if self and self:IsA("Humanoid") then
                if key == "WalkSpeed" and CONFIG.SpeedEnabled and value ~= CONFIG.WalkSpeed then
                    return oldIndex(self, key, CONFIG.WalkSpeed)
                end
                if key == "JumpPower" and CONFIG.JumpEnabled and value ~= CONFIG.JumpPower then
                    return oldIndex(self, key, CONFIG.JumpPower)
                end
                if key == "UseJumpPower" and CONFIG.JumpEnabled and value ~= true then
                    return oldIndex(self, key, true)
                end
            end
            return oldIndex(self, key, value)
        end))
        print("[DebugTools] hookmetamethod активен")
    end)
end

------------------------------------------------------------
-- Fly
------------------------------------------------------------
local flyBodyVelocity, flyBodyGyro
local flySavedGravity
local flyKeyW, flyKeyA, flyKeyS, flyKeyD, flyKeySpace, flyKeyLCTRL
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.W then flyKeyW = true end
        if input.KeyCode == Enum.KeyCode.A then flyKeyA = true end
        if input.KeyCode == Enum.KeyCode.S then flyKeyS = true end
        if input.KeyCode == Enum.KeyCode.D then flyKeyD = true end
        if input.KeyCode == Enum.KeyCode.Space then flyKeySpace = true end
        if input.KeyCode == Enum.KeyCode.LeftControl then flyKeyLCTRL = true end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.W then flyKeyW = false end
        if input.KeyCode == Enum.KeyCode.A then flyKeyA = false end
        if input.KeyCode == Enum.KeyCode.S then flyKeyS = false end
        if input.KeyCode == Enum.KeyCode.D then flyKeyD = false end
        if input.KeyCode == Enum.KeyCode.Space then flyKeySpace = false end
        if input.KeyCode == Enum.KeyCode.LeftControl then flyKeyLCTRL = false end
    end
end)

local function startFly()
    local root = getRoot()
    if not root then return end
    if CONFIG.FlyMethod == "CFrame" then
        flySavedGravity = Workspace.Gravity
        Workspace.Gravity = 0
        local hum = getHumanoid()
        if hum then hum.PlatformStand = true end
    else
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyVelocity.Velocity = Vector3.zero
        flyBodyVelocity.Parent = root
        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        flyBodyGyro.P = 1e5
        flyBodyGyro.D = 100
        flyBodyGyro.Parent = root
    end
end

local function stopFly()
    if CONFIG.FlyMethod == "CFrame" then
        Workspace.Gravity = flySavedGravity or 196.2
        local hum = getHumanoid()
        if hum then hum.PlatformStand = false end
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    end
end

------------------------------------------------------------
-- Hitbox Expander storage
------------------------------------------------------------
local originalHitboxSizes = {}

local function restoreHitbox(player)
    local data = originalHitboxSizes[player]
    if not data then return end
    for part, size in pairs(data) do
        if part and part.Parent then part.Size = size end
    end
    originalHitboxSizes[player] = nil
end

local function applyHitbox(player)
    if not player.Character then return end
    local head = player.Character:FindFirstChild("Head")
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not head or not root then return end
    if not originalHitboxSizes[player] then
        originalHitboxSizes[player] = {}
    end
    for _, part in ipairs({ head, root }) do
        if not originalHitboxSizes[player][part] then
            originalHitboxSizes[player][part] = part.Size
        end
        local orig = originalHitboxSizes[player][part]
        part.Size = orig * CONFIG.HitboxSize
        part.Transparency = 0.7
        part.CanCollide = false
    end
end

------------------------------------------------------------
-- Главный цикл
------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
    -- ESP
    local myRoot = getRoot()
    for player, data in pairs(espObjects) do
        if myRoot and data.Root and data.Root.Parent and data.Humanoid then
            local distance = (myRoot.Position - data.Root.Position).Magnitude
            local baseColor = getTeamColor(player)
            local dim = false
            if CONFIG.EspVisibleOnly then
                local head = data.Character and data.Character:FindFirstChild("Head")
                if head and not isTargetVisible(head) then
                    dim = true
                end
            end
            local visible = CONFIG.EspEnabled and distance <= CONFIG.EspMaxDistance and data.Humanoid.Health > 0
            data.Highlight.Enabled = visible
            data.Billboard.Enabled = visible
            if visible then
                local col = dim and baseColor:Lerp(Color3.new(0.4, 0.4, 0.4), 0.5) or baseColor
                data.Label.TextColor3 = col
                data.Highlight.FillColor = col
                data.Label.Text = string.format(
                    "%s\n%d studs | HP: %d/%d%s",
                    player.DisplayName,
                    math.floor(distance),
                    math.floor(data.Humanoid.Health),
                    math.floor(data.Humanoid.MaxHealth),
                    dim and "  •  BEHIND" or ""
                )
            end
        else
            removeESP(player)
        end
    end

    -- Aimbot
    if CONFIG.AimEnabled and (not CONFIG.AimHoldRMB or state.RightMouseDown) then
        local targets = getTargets(CONFIG.AimTargetPart, CONFIG.AimMaxDistance, CONFIG.AimVisibleOnly)
        local best = pickBestTarget(targets, CONFIG.AimFov)
        if best then
            local aimCF = CFrame.lookAt(Camera.CFrame.Position, best.part.Position)
            local alpha = 1 / math.max(1, CONFIG.AimSmoothness)
            Camera.CFrame = Camera.CFrame:Lerp(aimCF, alpha)
        end
    end

    -- Trigger Bot
    if CONFIG.TriggerEnabled and (not CONFIG.TriggerHoldMode or state.LeftMouseDown) then
        local targetPartName = CONFIG.TriggerTargetPart
        if targetPartName == "Humanoid" then targetPartName = "Head" end
        local targets = getTargets(targetPartName, CONFIG.TriggerMaxDistance, CONFIG.TriggerVisibleOnly)
        local best = pickBestTarget(targets, CONFIG.TriggerFov)
        if best then
            local aimCF = CFrame.lookAt(Camera.CFrame.Position, best.part.Position)
            local alpha = 1 / math.max(1, CONFIG.TriggerSmoothness)
            Camera.CFrame = Camera.CFrame:Lerp(aimCF, alpha)
            task.delay(CONFIG.TriggerDelayMs / 1000, function()
                if CONFIG.TriggerEnabled then
                    fireClick()
                end
            end)
        end
    end

    -- Fly
    if CONFIG.FlyEnabled then
        local root = getRoot()
        if root then
            if not flyBodyVelocity and CONFIG.FlyMethod == "BodyMover" then
                startFly()
            elseif not flySavedGravity and CONFIG.FlyMethod == "CFrame" then
                startFly()
            end
            local direction = Vector3.zero
            if flyKeyW then direction += Camera.CFrame.LookVector end
            if flyKeyS then direction -= Camera.CFrame.LookVector end
            if flyKeyD then direction += Camera.CFrame.RightVector end
            if flyKeyA then direction -= Camera.CFrame.RightVector end
            if flyKeySpace then direction += Vector3.yAxis end
            if flyKeyLCTRL then direction -= Vector3.yAxis end

            if CONFIG.FlyMethod == "CFrame" then
                if direction.Magnitude > 0 then
                    root.CFrame = root.CFrame + direction.Unit * CONFIG.FlySpeed * dt
                end
                root.CFrame = CFrame.new(root.Position) * (Camera.CFrame - Camera.CFrame.Position)
            else
                if flyBodyVelocity then
                    flyBodyVelocity.Velocity = direction.Magnitude > 0 and direction.Unit * CONFIG.FlySpeed or Vector3.zero
                end
                if flyBodyGyro then
                    flyBodyGyro.CFrame = Camera.CFrame
                end
            end
        end
    else
        if flyBodyVelocity or flySavedGravity then stopFly() end
    end

    -- No Clip
    if CONFIG.NoClipEnabled then
        local char = getCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end

    -- Hitbox Expander
    if CONFIG.HitboxEnabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if not isAlly(player) and player.Character and myRoot then
                local head = player.Character:FindFirstChild("Head")
                if head and (myRoot.Position - head.Position).Magnitude <= CONFIG.HitboxMaxDistance then
                    applyHitbox(player)
                end
            end
        end
    else
        -- восстанавливаем оригинальные размеры когда выключаем
        for player, _ in pairs(originalHitboxSizes) do
            restoreHitbox(player)
        end
    end

    -- FOV Circles
    if aimFovCircle then
        if CONFIG.AimShowFov and CONFIG.AimEnabled then
            aimFovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local r = math.tan(math.rad(CONFIG.AimFov / 2)) * (Camera.ViewportSize.Y / 2) * 2
            aimFovCircle.Radius = r
            aimFovCircle.Visible = true
        else
            aimFovCircle.Visible = false
        end
    end
    if trigFovCircle then
        if CONFIG.TriggerEnabled then
            trigFovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            local r = math.tan(math.rad(CONFIG.TriggerFov / 2)) * (Camera.ViewportSize.Y / 2) * 2
            trigFovCircle.Radius = r
            trigFovCircle.Visible = true
        else
            trigFovCircle.Visible = false
        end
    end
end)

-- Force WalkSpeed/JumpPower каждый кадр (фолбэк)
RunService.Heartbeat:Connect(function()
    local hum = getHumanoid()
    if not hum then return end
    if CONFIG.SpeedEnabled and hum.WalkSpeed ~= CONFIG.WalkSpeed then
        hum.WalkSpeed = CONFIG.WalkSpeed
    end
    if CONFIG.JumpEnabled then
        if hum.UseJumpPower ~= true then hum.UseJumpPower = true end
        if hum.JumpPower ~= CONFIG.JumpPower then hum.JumpPower = CONFIG.JumpPower end
    end
end)

-- No Clip через Stepped (применяется ДО физики — стабильнее)
RunService.Stepped:Connect(function(_, dt)
    if CONFIG.NoClipEnabled then
        local char = getCharacter()
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

print("[DebugTools] loaded universal hub. RightShift — menu.")
end)

if not ok then
    warn("[DebugTools] runtime error: " .. tostring(err))
end
