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
mini.Active = true
mini.Visible = isMobile -- на мобиле показываем сразу, на ПК — только после закрытия
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

-- Адаптивный UI: на мобиле — почти весь экран, на ПК — фиксированный размер.
-- Определяем мобилку по размеру экрана (надёжнее, чем по TouchEnabled, потому что
-- Bluetooth-клавиатура у мобильных юзеров делает KeyboardEnabled = true).
local viewportSize = Camera.ViewportSize
local isMobile = viewportSize.X < 600 or (UserInputService.TouchEnabled and viewportSize.X < 900)

-- Главное окно
local main = Instance.new("Frame")
main.Name = "Main"
if isMobile then
    main.Size = UDim2.new(0.96, 0, 0.78, 0)
    main.Position = UDim2.new(0.02, 0, 0.11, 0)
else
    main.Size = UDim2.fromOffset(420, 520)
    main.Position = UDim2.new(0.5, -210, 0.5, -260)
end
main.BackgroundColor3 = Color3.fromRGB(19, 19, 28)
main.BorderSizePixel = 0
main.Visible = true
main.Active = true -- мобайл: чтобы тач-скролл внутри работал
main.Draggable = false -- мы перетаскиваем вручную через InputBegan
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
tabs.Size = isMobile and UDim2.new(0, 70, 1, -44) or UDim2.new(0, 110, 1, -44)
tabs.Position = UDim2.new(0, 0, 0, 44)
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

local tabButtons = {}
local pages = {}
local pageOrder = { "ESP", "Movement", "AIM", "Trigger", "Misc" }

local function makeTab(name, text, order)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -10, 0, isMobile and 50 or 38)
    b.LayoutOrder = order
    b.BackgroundColor3 = Color3.fromRGB(35, 34, 50)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(205, 203, 220)
    b.Font = Enum.Font.GothamBold
    b.TextSize = isMobile and 10 or 12
    b.TextWrapped = true
    b.AutoButtonColor = true
    b.Parent = tabs
    corner(b, 7)
    tabButtons[name] = b
    return b
end

for i, name in ipairs(pageOrder) do
    makeTab(name, isMobile and ({
        ESP = "◉\nESP",
        Movement = "↗\nMOVE",
        AIM = "◎\nAIM",
        Trigger = "⌖\nTRIG",
        Misc = "⚙\nMISC",
    })[name] or ({
        ESP = "◉   ESP",
        Movement = "↗   MOVE",
        AIM = "◎   AIM",
        Trigger = "⌖   TRIG",
        Misc = "⚙   MISC",
    })[name], i)
end

-- Каждая вкладка — ScrollingFrame, лежит прямо в main с одной и той же геометрией.
-- selectTab включает/выключает Visible, перекрытия не страшны — ClipsDescendants режет.
local PAGE_OFFSET = isMobile and 78 or 118
local function makePage(name)
    local sf = Instance.new("ScrollingFrame")
    sf.Name = name .. "Page"
    sf.Size = UDim2.new(1, -PAGE_OFFSET - 6, 1, -52)
    sf.Position = UDim2.fromOffset(PAGE_OFFSET, 48)
    -- Полупрозрачный фон, чтобы было видно, что страница существует
    sf.BackgroundTransparency = 0.7
    sf.BackgroundColor3 = Color3.fromRGB(22, 22, 32)
    sf.BorderSizePixel = 0
    sf.ZIndex = 5
    sf.ScrollBarThickness = isMobile and 6 or 4
    sf.ScrollBarImageColor3 = CONFIG.Theme
    -- Явный большой CanvasSize — на мобиле AutomaticCanvasSize иногда глючит
    -- при первом рендере. Реальный размер пересчитается после первого кадра.
    sf.CanvasSize = UDim2.new(0, 0, 0, 1000)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.ElasticBehavior = Enum.ElasticBehavior.Never
    sf.ScrollingDirection = Enum.ScrollingDirection.Y
    sf.Visible = (name == state.ActiveTab)
    sf.Parent = main
    pages[name] = sf
    return sf
end

for _, name in ipairs(pageOrder) do
    makePage(name)
end

-- Отладка: что страницы созданы
for n, p in pairs(pages) do
    print(string.format("[DebugTools] page %s created: size=%s pos=%s visible=%s parent=%s", n, tostring(p.Size), tostring(p.Position), tostring(p.Visible), tostring(p.Parent and p.Parent.Name or "nil")))
end

-- Компоненты UI внутри ScrollingFrame (адаптивные под мобилку)
local function makeToggle(parent, text, y, initial, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 0, isMobile and 42 or 36)
    b.Position = UDim2.fromOffset(6, y)
    b.Font = Enum.Font.GothamBold
    b.TextSize = isMobile and 13 or 12
    b.TextColor3 = Color3.new(1, 1, 1)
    b.AutoButtonColor = true
    b.Parent = parent
    corner(b, 8)
    local enabled = initial
    local function refresh()
        b.Text = text .. (enabled and "   ON" or "   OFF")
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
    -- Горизонтальный layout: заголовок слева, поле справа, в одну строку.
    label(parent, title, UDim2.new(0.55, 0, 0, isMobile and 34 or 30), UDim2.fromOffset(6, y - 2), isMobile and 13 or 12, Color3.fromRGB(205, 203, 220))
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.42, -6, 0, isMobile and 34 or 30)
    box.Position = UDim2.new(0.56, 0, 0, y - 2)
    box.BackgroundColor3 = Color3.fromRGB(34, 33, 47)
    box.TextColor3 = Color3.new(1, 1, 1)
    box.Text = tostring(value)
    box.Font = Enum.Font.GothamBold
    box.TextSize = isMobile and 14 or 12
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
local ESP_GAP = 6
local espY = 0
local function _t(parent, text, initial, callback)
    espY += (ESP_GAP + (isMobile and 42 or 36))
    return makeToggle(parent, text, espY, initial, callback)
end
local function _i(parent, title, value, callback)
    espY += (ESP_GAP + (isMobile and 34 or 30))
    return makeInput(parent, title, value, espY, callback)
end
makeSectionTitle(espPage, "ESP", 6)
espY = 6
_t(espPage, "Player ESP", CONFIG.EspEnabled, function(v) CONFIG.EspEnabled = v end)
_t(espPage, "Visible Only (dim if behind wall)", CONFIG.EspVisibleOnly, function(v) CONFIG.EspVisibleOnly = v end)
_i(espPage, "Max distance (studs)", CONFIG.EspMaxDistance, function(v)
    CONFIG.EspMaxDistance = math.clamp(v, 25, 5000)
    return CONFIG.EspMaxDistance
end)

-- === Movement ===
local moveY = 0
local function __t(parent, text, initial, callback)
    moveY += (ESP_GAP + (isMobile and 42 or 36))
    return makeToggle(parent, text, moveY, initial, callback)
end
local function __i(parent, title, value, callback)
    moveY += (ESP_GAP + (isMobile and 34 or 30))
    return makeInput(parent, title, value, moveY, callback)
end
local function __s(parent, title, options, default, callback)
    moveY += (ESP_GAP + 50)
    return makeSegmented(parent, title, options, moveY, default, callback)
end
makeSectionTitle(movePage, "Movement", 6)
moveY = 6
__t(movePage, "Speed Hack", CONFIG.SpeedEnabled, function(v) CONFIG.SpeedEnabled = v end)
__i(movePage, "WalkSpeed", CONFIG.WalkSpeed, function(v)
    CONFIG.WalkSpeed = math.clamp(v, 0, 500)
    return CONFIG.WalkSpeed
end)
__t(movePage, "High Jump", CONFIG.JumpEnabled, function(v) CONFIG.JumpEnabled = v end)
__i(movePage, "JumpPower", CONFIG.JumpPower, function(v)
    CONFIG.JumpPower = math.clamp(v, 0, 500)
    return CONFIG.JumpPower
end)
__t(movePage, "Fly", CONFIG.FlyEnabled, function(v) CONFIG.FlyEnabled = v end)
__s(movePage, "Fly method", { "CFrame", "BodyMover" }, CONFIG.FlyMethod, function(v) CONFIG.FlyMethod = v end)
__i(movePage, "Fly speed", CONFIG.FlySpeed, function(v)
    CONFIG.FlySpeed = math.clamp(v, 10, 500)
    return CONFIG.FlySpeed
end)
__t(movePage, "Infinite Jump", CONFIG.InfiniteJump, function(v) CONFIG.InfiniteJump = v end)
__t(movePage, "No Clip (universal)", CONFIG.NoClipEnabled, function(v) CONFIG.NoClipEnabled = v end)

-- === AIM ===
local aimY = 0
local function _at(parent, text, initial, callback)
    aimY += (ESP_GAP + (isMobile and 42 or 36))
    return makeToggle(parent, text, aimY, initial, callback)
end
local function _ai(parent, title, value, callback)
    aimY += (ESP_GAP + (isMobile and 34 or 30))
    return makeInput(parent, title, value, aimY, callback)
end
local function _as(parent, title, options, default, callback)
    aimY += (ESP_GAP + 50)
    return makeSegmented(parent, title, options, aimY, default, callback)
end
makeSectionTitle(aimPage, "Aimbot", 6)
aimY = 6
_at(aimPage, "Aimbot", CONFIG.AimEnabled, function(v) CONFIG.AimEnabled = v end)
_at(aimPage, "Hold Right Mouse", CONFIG.AimHoldRMB, function(v) CONFIG.AimHoldRMB = v end)
_at(aimPage, "Visible Only (skip behind walls)", CONFIG.AimVisibleOnly, function(v) CONFIG.AimVisibleOnly = v end)
_at(aimPage, "Show FOV Circle", CONFIG.AimShowFov, function(v) CONFIG.AimShowFov = v end)
_ai(aimPage, "FOV (deg)", CONFIG.AimFov, function(v)
    CONFIG.AimFov = math.clamp(v, 5, 360)
    return CONFIG.AimFov
end)
_ai(aimPage, "Smoothness (1=snappy)", CONFIG.AimSmoothness, function(v)
    CONFIG.AimSmoothness = math.clamp(v, 1, 30)
    return CONFIG.AimSmoothness
end)
_ai(aimPage, "Max distance (studs)", CONFIG.AimMaxDistance, function(v)
    CONFIG.AimMaxDistance = math.clamp(v, 25, 5000)
    return CONFIG.AimMaxDistance
end)
_as(aimPage, "Target part", { "Head", "HumanoidRootPart" }, CONFIG.AimTargetPart, function(v) CONFIG.AimTargetPart = v end)

-- === Trigger ===
local trigY = 0
local function _tt(parent, text, initial, callback)
    trigY += (ESP_GAP + (isMobile and 42 or 36))
    return makeToggle(parent, text, trigY, initial, callback)
end
local function _ti(parent, title, value, callback)
    trigY += (ESP_GAP + (isMobile and 34 or 30))
    return makeInput(parent, title, value, trigY, callback)
end
local function _ts(parent, title, options, default, callback)
    trigY += (ESP_GAP + 50)
    return makeSegmented(parent, title, options, trigY, default, callback)
end
makeSectionTitle(trigPage, "Trigger Bot", 6)
trigY = 6
_tt(trigPage, "Trigger Bot", CONFIG.TriggerEnabled, function(v) CONFIG.TriggerEnabled = v end)
_tt(trigPage, "Fire only when LMB held", CONFIG.TriggerHoldMode, function(v) CONFIG.TriggerHoldMode = v end)
_tt(trigPage, "Visible Only (skip behind walls)", CONFIG.TriggerVisibleOnly, function(v) CONFIG.TriggerVisibleOnly = v end)
_ti(trigPage, "FOV (deg)", CONFIG.TriggerFov, function(v)
    CONFIG.TriggerFov = math.clamp(v, 1, 90)
    return CONFIG.TriggerFov
end)
_ti(trigPage, "Aim smoothness (1=snappy)", CONFIG.TriggerSmoothness, function(v)
    CONFIG.TriggerSmoothness = math.clamp(v, 1, 30)
    return CONFIG.TriggerSmoothness
end)
_ti(trigPage, "Max distance (studs)", CONFIG.TriggerMaxDistance, function(v)
    CONFIG.TriggerMaxDistance = math.clamp(v, 25, 2000)
    return CONFIG.TriggerMaxDistance
end)
_ti(trigPage, "Click delay (ms)", CONFIG.TriggerDelayMs, function(v)
    CONFIG.TriggerDelayMs = math.clamp(v, 0, 500)
    return CONFIG.TriggerDelayMs
end)
_ts(trigPage, "Target part", { "Head", "HumanoidRootPart", "Humanoid" }, CONFIG.TriggerTargetPart, function(v) CONFIG.TriggerTargetPart = v end)

-- === Misc ===
local miscY = 0
local function _mt(parent, text, initial, callback)
    miscY += (ESP_GAP + (isMobile and 42 or 36))
    return makeToggle(parent, text, miscY, initial, callback)
end
local function _mi(parent, title, value, callback)
    miscY += (ESP_GAP + (isMobile and 34 or 30))
    return makeInput(parent, title, value, miscY, callback)
end
makeSectionTitle(miscPage, "Hitbox Expander", 6)
miscY = 6
_mt(miscPage, "Expand Hitboxes", CONFIG.HitboxEnabled, function(v) CONFIG.HitboxEnabled = v end)
_mi(miscPage, "Size multiplier", CONFIG.HitboxSize, function(v)
    CONFIG.HitboxSize = math.clamp(v, 1, 10)
    return CONFIG.HitboxSize
end)
_mi(miscPage, "Max distance (studs)", CONFIG.HitboxMaxDistance, function(v)
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

-- Мобильный fly-контроллер: экранные кнопки W/A/S/D/Space/LCtrl.
-- Показывается только на мобиле и только когда Fly включён.
local mobileFlyFrame
if isMobile then
    mobileFlyFrame = Instance.new("Frame")
    mobileFlyFrame.Name = "MobileFly"
    mobileFlyFrame.Size = UDim2.fromOffset(220, 220)
    mobileFlyFrame.Position = UDim2.new(1, -240, 1, -260)
    mobileFlyFrame.BackgroundTransparency = 1
    mobileFlyFrame.Visible = false
    mobileFlyFrame.Parent = gui

    local function flyBtn(name, text, dx, dy, w, h)
        local b = Instance.new("TextButton")
        b.Name = name
        b.Size = UDim2.fromOffset(w or 50, h or 50)
        b.Position = UDim2.fromOffset(dx, dy)
        b.BackgroundColor3 = Color3.fromRGB(35, 34, 50)
        b.BackgroundTransparency = 0.4
        b.Text = text
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 18
        b.AutoButtonColor = true
        b.Parent = mobileFlyFrame
        corner(b, 12)
        stroke(b, Color3.fromRGB(112, 92, 255), 1)
        return b
    end

    -- W вверху, A слева, S внизу, D справа. Space (▲) выше W, LCtrl (▼) ниже S.
    local btnSpace = flyBtn("Space", "▲", 80, 0, 50, 40)
    local btnW = flyBtn("W", "W", 80, 50)
    local btnA = flyBtn("A", "A", 20, 110)
    local btnS = flyBtn("S", "S", 80, 110)
    local btnD = flyBtn("D", "D", 140, 110)
    local btnLCtrl = flyBtn("LCtrl", "▼", 80, 170, 50, 40)

    local keyMap = {
        W = "W", A = "A", S = "S", D = "D", Space = "Space", LCtrl = "LeftControl",
    }
    local flyKeyByBtn = {
        W = "W", A = "A", S = "S", D = "D", Space = "Space", LCtrl = "LeftControl",
    }

    -- эмуляция удержания клавиш через глобальный флаг
    local mobileKeys = {}
    for _, btn in ipairs({ btnW, btnA, btnS, btnD, btnSpace, btnLCtrl }) do
        local key = flyKeyByBtn[btn.Name]
        btn.MouseButton1Down:Connect(function() mobileKeys[key] = true end)
        btn.MouseButton1Up:Connect(function() mobileKeys[key] = false end)
        -- тач-страховка
        btn.TouchLongPress:Connect(function() end) -- noop, чтобы движок не игнорил touch
    end
    -- на тач-устройствах InputBegan не всегда срабатывает для TextButton с TouchEnded,
    -- поэтому делаем явный TouchTap через InputBegan
    for _, btn in ipairs({ btnW, btnA, btnS, btnD, btnSpace, btnLCtrl }) do
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                mobileKeys[flyKeyByBtn[btn.Name]] = true
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                mobileKeys[flyKeyByBtn[btn.Name]] = false
            end
        end)
    end
    -- затыкаем тачи на мобильных кнопках, чтобы они не "съедали" тапы в игре
    for _, btn in ipairs({ btnW, btnA, btnS, btnD, btnSpace, btnLCtrl }) do
        btn.Active = true
    end
    -- глобальный доступ для fly-цикла
    getgenv().__ESP_MOBILE_KEYS = mobileKeys
end

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
        if mobileFlyFrame then mobileFlyFrame.Visible = true end
        local root = getRoot()
        if root then
            if not flyBodyVelocity and CONFIG.FlyMethod == "BodyMover" then
                startFly()
            elseif not flySavedGravity and CONFIG.FlyMethod == "CFrame" then
                startFly()
            end
            local direction = Vector3.zero
            -- клавиатура ИЛИ мобильные кнопки
            local mk = getgenv and getgenv().__ESP_MOBILE_KEYS
            local wHeld = flyKeyW or (mk and mk.W)
            local aHeld = flyKeyA or (mk and mk.A)
            local sHeld = flyKeyS or (mk and mk.S)
            local dHeld = flyKeyD or (mk and mk.D)
            local spHeld = flyKeySpace or (mk and mk.Space)
            local lcHeld = flyKeyLCTRL or (mk and mk.LeftControl)
            if wHeld then direction += Camera.CFrame.LookVector end
            if sHeld then direction -= Camera.CFrame.LookVector end
            if dHeld then direction += Camera.CFrame.RightVector end
            if aHeld then direction -= Camera.CFrame.RightVector end
            if spHeld then direction += Vector3.yAxis end
            if lcHeld then direction -= Vector3.yAxis end

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
        if mobileFlyFrame then mobileFlyFrame.Visible = false end
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
