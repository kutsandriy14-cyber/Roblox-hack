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

-- Логгер: пишет и в консоль executor'а, и в скрытое сообщение Roblox
local __stages = {}
local function dlog(stage)
    table.insert(__stages, stage)
    pcall(function() warn("[DT] " .. stage) end)
    pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "DebugTools",
        Text = stage,
        Duration = 2,
    }) end)
end

dlog("services+config")

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

-- ВАЖНО: определяем isMobile СРАЗУ, до любого использования.
-- Раньше он определялся ниже (после создания mini), из-за чего
-- mini.Visible = nil и кнопки не работали корректно.
local viewportSizeEarly = Camera.ViewportSize
local isMobile = viewportSizeEarly.X < 600 or (UserInputService.TouchEnabled and viewportSizeEarly.X < 900)

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

-- Универсальный обработчик тапа. Совместим с Delta / Fluxus / Wave и т.д.
-- 3 уровня:
--   1) .Activated — стандарт для Roblox
--   2) MouseButton1Click — для ПК-экзекуторов
--   3) Глобальный UserInputService.TouchEnded + проверка попадания в AbsoluteRect
--      кнопки — тач-страховка для Delta, где первые два могут молчать.
-- Также делаем визуальный feedback (кнопка белеет на 100мс) — сразу видно,
-- реагирует или нет.
getgenv().__ESP_TAP_REGISTRY = getgenv().__ESP_TAP_REGISTRY or {}
local __tapRegistry = getgenv().__ESP_TAP_REGISTRY

local function onTap(button, callback)
    table.insert(__tapRegistry, { button = button, callback = callback })

    local function fire()
        pcall(callback)
        local orig = button.BackgroundColor3
        button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        task.delay(0.1, function()
            pcall(function() if button and button.Parent then button.BackgroundColor3 = orig end end)
        end)
    end

    button.Activated:Connect(fire)
    button.MouseButton1Click:Connect(fire)
end

-- Глобальный тач-обработчик — последний рубеж для Delta mobile
if not getgenv().__ESP_TAP_HOOK_INSTALLED then
    getgenv().__ESP_TAP_HOOK_INSTALLED = true
    task.spawn(function()
        local uis = game:GetService("UserInputService")
        local lastTouchStart = nil
        uis.TouchStarted:Connect(function(input, processed)
            if processed then return end
            lastTouchStart = { pos = input.Position, t = tick() }
        end)
        uis.TouchEnded:Connect(function(input, processed)
            if processed then return end
            if not lastTouchStart then return end
            if tick() - lastTouchStart.t > 0.5 then lastTouchStart = nil; return end
            local p = input.Position
            for _, entry in ipairs(__tapRegistry) do
                local btn = entry.button
                if btn and btn.Parent and btn.Visible and btn.Active then
                    local r = btn.AbsoluteRect
                    if p.X >= r.Min.X and p.X <= r.Max.X
                       and p.Y >= r.Min.Y and p.Y <= r.Max.Y then
                        pcall(entry.callback)
                        break
                    end
                end
            end
            lastTouchStart = nil
        end)
    end)
end

------------------------------------------------------------
-- GUI
------------------------------------------------------------
dlog("GUI (Rayfield)")
------------------------------------------------------------
-- GUI: Rayfield UI Library
------------------------------------------------------------
-- Rayfield сама рисует окно, табы, тоглы, слайдеры, инпуты, дропдауны.
-- Это намного стабильнее для Delta mobile, чем самописные TextButton —
-- внутри Rayfield использует свой собственный рендер (ImGui-подобный).
-- Весь блок обёрнут в собственный pcall — если Rayfield не загрузится,
-- бэкенд (ESP/Aimbot/Fly) всё равно запустится.
local Rayfield, Window, Tabs = nil, nil, nil
local _guiOk, _guiErr = pcall(function()
pcall(function()
    Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
end)
if not Rayfield then
    -- fallback: попробуем альтернативный источник
    pcall(function()
        Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/UI-Library/Rayfield/main/src.lua"))()
    end)
end
if not Rayfield then
    warn("[DebugTools] Rayfield не загрузился. UI недоступен, но ESP/Aimbot/Fly продолжат работать через CONFIG.")
end

local Window, Tabs = {}, {}

if Rayfield then
    local themeName = CONFIG.Theme and "Default" or "Default"
    Window = Rayfield:CreateWindow({
        Name = "DEBUG TOOLS — kentikvr",
        LoadingTitle = "DEBUG TOOLS",
        LoadingSubtitle = "kentikvr • universal",
        ConfigurationSaving = { Enabled = true, FolderName = "DebugToolsCfg", FileName = "config" },
        KeySystem = false,
    })

    -- 5 вкладок как и было
    Tabs.ESP       = Window:CreateTab("◉ ESP",     4483362458)
    Tabs.Movement  = Window:CreateTab("↗ MOVE",    4483362458)
    Tabs.AIM       = Window:CreateTab("◎ AIM",     4483362458)
    Tabs.Trigger   = Window:CreateTab("⌖ TRIG",    4483362458)
    Tabs.Misc      = Window:CreateTab("⚙ MISC",    4483362458)

    ------------------------------------------------------------
    -- ESP
    ------------------------------------------------------------
    local EspSection = Tabs.ESP:CreateSection("ESP")
    Tabs.ESP:CreateToggle({
        Name = "Enable ESP",
        CurrentValue = CONFIG.EspEnabled,
        Flag = "EspEnabled",
        Callback = function(v) CONFIG.EspEnabled = v end,
    })
    Tabs.ESP:CreateToggle({
        Name = "Boxes (highlight)",
        CurrentValue = CONFIG.EspBoxEnabled,
        Flag = "EspBox",
        Callback = function(v) CONFIG.EspBoxEnabled = v end,
    })
    Tabs.ESP:CreateToggle({
        Name = "Visible only (dim if behind wall)",
        CurrentValue = CONFIG.EspVisibleOnly,
        Flag = "EspVisOnly",
        Callback = function(v) CONFIG.EspVisibleOnly = v end,
    })
    Tabs.ESP:CreateSlider({
        Name = "Max distance (studs)",
        Range = { 50, 3000 },
        Increment = 50,
        Suffix = " studs",
        CurrentValue = CONFIG.EspMaxDistance,
        Flag = "EspDist",
        Callback = function(v) CONFIG.EspMaxDistance = v end,
    })

    ------------------------------------------------------------
    -- Movement
    ------------------------------------------------------------
    local MovSection = Tabs.Movement:CreateSection("Speed & Jump")
    Tabs.Movement:CreateToggle({
        Name = "Speed hack",
        CurrentValue = CONFIG.SpeedEnabled,
        Flag = "Speed",
        Callback = function(v) CONFIG.SpeedEnabled = v end,
    })
    Tabs.Movement:CreateSlider({
        Name = "WalkSpeed",
        Range = { 16, 500 },
        Increment = 1,
        CurrentValue = CONFIG.WalkSpeed,
        Flag = "WS",
        Callback = function(v) CONFIG.WalkSpeed = v end,
    })
    Tabs.Movement:CreateToggle({
        Name = "Jump hack",
        CurrentValue = CONFIG.JumpEnabled,
        Flag = "Jump",
        Callback = function(v) CONFIG.JumpEnabled = v end,
    })
    Tabs.Movement:CreateSlider({
        Name = "JumpPower",
        Range = { 50, 300 },
        Increment = 5,
        CurrentValue = CONFIG.JumpPower,
        Flag = "JP",
        Callback = function(v) CONFIG.JumpPower = v end,
    })
    Tabs.Movement:CreateToggle({
        Name = "Infinite jump",
        CurrentValue = CONFIG.InfiniteJump,
        Flag = "InfJump",
        Callback = function(v) CONFIG.InfiniteJump = v end,
    })
    Tabs.Movement:CreateToggle({
        Name = "NoClip",
        CurrentValue = CONFIG.NoClipEnabled,
        Flag = "NoClip",
        Callback = function(v) CONFIG.NoClipEnabled = v end,
    })

    local FlySection = Tabs.Movement:CreateSection("Fly")
    Tabs.Movement:CreateToggle({
        Name = "Enable fly",
        CurrentValue = CONFIG.FlyEnabled,
        Flag = "Fly",
        Callback = function(v) CONFIG.FlyEnabled = v end,
    })
    Tabs.Movement:CreateDropdown({
        Name = "Fly method",
        Options = { "CFrame", "BodyMover" },
        CurrentOption = CONFIG.FlyMethod,
        Flag = "FlyMethod",
        Callback = function(v) CONFIG.FlyMethod = v end,
    })
    Tabs.Movement:CreateSlider({
        Name = "Fly speed",
        Range = { 10, 300 },
        Increment = 5,
        CurrentValue = CONFIG.FlySpeed,
        Flag = "FlySpeed",
        Callback = function(v) CONFIG.FlySpeed = v end,
    })

    ------------------------------------------------------------
    -- Aimbot
    ------------------------------------------------------------
    Tabs.AIM:CreateToggle({
        Name = "Enable aimbot",
        CurrentValue = CONFIG.AimEnabled,
        Flag = "Aim",
        Callback = function(v) CONFIG.AimEnabled = v end,
    })
    Tabs.AIM:CreateToggle({
        Name = "Hold RMB to aim",
        CurrentValue = CONFIG.AimHoldRMB,
        Flag = "AimRMB",
        Callback = function(v) CONFIG.AimHoldRMB = v end,
    })
    Tabs.AIM:CreateToggle({
        Name = "Show FOV circle",
        CurrentValue = CONFIG.AimShowFov,
        Flag = "AimFovShow",
        Callback = function(v) CONFIG.AimShowFov = v end,
    })
    Tabs.AIM:CreateSlider({
        Name = "FOV (degrees)",
        Range = { 10, 360 },
        Increment = 5,
        CurrentValue = CONFIG.AimFov,
        Flag = "AimFov",
        Callback = function(v) CONFIG.AimFov = v end,
    })
    Tabs.AIM:CreateSlider({
        Name = "Smoothness (1=snappy)",
        Range = { 1, 30 },
        Increment = 1,
        CurrentValue = CONFIG.AimSmoothness,
        Flag = "AimSmooth",
        Callback = function(v) CONFIG.AimSmoothness = v end,
    })
    Tabs.AIM:CreateSlider({
        Name = "Max distance (studs)",
        Range = { 25, 2000 },
        Increment = 25,
        CurrentValue = CONFIG.AimMaxDistance,
        Flag = "AimDist",
        Callback = function(v) CONFIG.AimMaxDistance = v end,
    })
    Tabs.AIM:CreateToggle({
        Name = "Visible only",
        CurrentValue = CONFIG.AimVisibleOnly,
        Flag = "AimVis",
        Callback = function(v) CONFIG.AimVisibleOnly = v end,
    })
    Tabs.AIM:CreateDropdown({
        Name = "Target part",
        Options = { "Head", "HumanoidRootPart" },
        CurrentOption = CONFIG.AimTargetPart,
        Flag = "AimPart",
        Callback = function(v) CONFIG.AimTargetPart = v end,
    })

    ------------------------------------------------------------
    -- Trigger Bot
    ------------------------------------------------------------
    Tabs.Trigger:CreateToggle({
        Name = "Enable trigger bot",
        CurrentValue = CONFIG.TriggerEnabled,
        Flag = "Trig",
        Callback = function(v) CONFIG.TriggerEnabled = v end,
    })
    Tabs.Trigger:CreateToggle({
        Name = "Hold LMB to fire",
        CurrentValue = CONFIG.TriggerHoldMode,
        Flag = "TrigHold",
        Callback = function(v) CONFIG.TriggerHoldMode = v end,
    })
    Tabs.Trigger:CreateSlider({
        Name = "FOV (degrees)",
        Range = { 5, 90 },
        Increment = 1,
        CurrentValue = CONFIG.TriggerFov,
        Flag = "TrigFov",
        Callback = function(v) CONFIG.TriggerFov = v end,
    })
    Tabs.Trigger:CreateSlider({
        Name = "Smoothness (1=snappy)",
        Range = { 1, 30 },
        Increment = 1,
        CurrentValue = CONFIG.TriggerSmoothness,
        Flag = "TrigSmooth",
        Callback = function(v) CONFIG.TriggerSmoothness = v end,
    })
    Tabs.Trigger:CreateSlider({
        Name = "Max distance (studs)",
        Range = { 25, 2000 },
        Increment = 25,
        CurrentValue = CONFIG.TriggerMaxDistance,
        Flag = "TrigDist",
        Callback = function(v) CONFIG.TriggerMaxDistance = v end,
    })
    Tabs.Trigger:CreateSlider({
        Name = "Click delay (ms)",
        Range = { 0, 500 },
        Increment = 5,
        CurrentValue = CONFIG.TriggerDelayMs,
        Flag = "TrigDelay",
        Callback = function(v) CONFIG.TriggerDelayMs = v end,
    })
    Tabs.Trigger:CreateDropdown({
        Name = "Target part",
        Options = { "Head", "HumanoidRootPart", "Humanoid" },
        CurrentOption = CONFIG.TriggerTargetPart,
        Flag = "TrigPart",
        Callback = function(v) CONFIG.TriggerTargetPart = v end,
    })
    Tabs.Trigger:CreateToggle({
        Name = "Visible only",
        CurrentValue = CONFIG.TriggerVisibleOnly,
        Flag = "TrigVis",
        Callback = function(v) CONFIG.TriggerVisibleOnly = v end,
    })

    ------------------------------------------------------------
    -- Misc (Hitbox)
    ------------------------------------------------------------
    Tabs.Misc:CreateToggle({
        Name = "Expand hitboxes",
        CurrentValue = CONFIG.HitboxEnabled,
        Flag = "Hitbox",
        Callback = function(v) CONFIG.HitboxEnabled = v end,
    })
    Tabs.Misc:CreateSlider({
        Name = "Size multiplier",
        Range = { 1, 10 },
        Increment = 0.5,
        CurrentValue = CONFIG.HitboxSize,
        Flag = "HitboxSize",
        Callback = function(v) CONFIG.HitboxSize = v end,
    })
    Tabs.Misc:CreateSlider({
        Name = "Max distance (studs)",
        Range = { 25, 3000 },
        Increment = 25,
        CurrentValue = CONFIG.HitboxMaxDistance,
        Flag = "HitboxDist",
        Callback = function(v) CONFIG.HitboxMaxDistance = v end,
    })

    -- Пара кнопок для удобства
    Tabs.Misc:CreateButton({
        Name = "Unload script",
        Callback = function()
            Rayfield:Destroy()
        end,
    })
end -- if Rayfield then
end) -- GUI pcall
if not _guiOk then
    warn("[DebugTools] GUI (Rayfield) ошибка: " .. tostring(_guiErr))
end

-- Если Rayfield не подгрузился — бэкенд всё равно работает,
-- просто управление через CONFIG напрямую (например через консоль executor).

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
dlog("Input")
-- RightShift toggles Rayfield window (Rayfield сам управляет видимостью через флаг)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift and Window and Window.Toggle then
        pcall(function() Window:Toggle() end)
    end
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
dlog("FOV")
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
dlog("анти-античит")
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
dlog("Fly")
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
dlog("Hitbox")
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
dlog("RenderStepped")
------------------------------------------------------------
-- THROTTLE: тяжёлые операции (raycast ESP, getDescendants hitbox) НЕ каждый кадр.
-- ESP ~5 раз/сек, hitbox ~2.5 раза/сек.
local ESP_TICK = 0
local HITBOX_TICK = 0
local ESP_INTERVAL = 0.5  -- 500 мс = 2 Гц (было 5 Гц — слишком лагает на Delta)
local HITBOX_INTERVAL = 1.0 -- 1 секунда = 1 Гц (хитбоксы меняются редко)

RunService.RenderStepped:Connect(function(dt)
    local now = tick()
    local myRoot = getRoot()

    -- ESP — throttled, без raycast (на мобиле он жрёт FPS)
    if now - ESP_TICK >= ESP_INTERVAL then
        ESP_TICK = now
    for player, data in pairs(espObjects) do
        if myRoot and data.Root and data.Root.Parent and data.Humanoid then
            local distance = (myRoot.Position - data.Root.Position).Magnitude
            local baseColor = getTeamColor(player)
            local visible = CONFIG.EspEnabled and distance <= CONFIG.EspMaxDistance and data.Humanoid.Health > 0
            data.Highlight.Enabled = visible
            data.Billboard.Enabled = visible
            if visible then
                data.Label.TextColor3 = baseColor
                data.Highlight.FillColor = baseColor
                data.Label.Text = string.format(
                    "%s\n%d studs | HP: %d/%d",
                    player.DisplayName,
                    math.floor(distance),
                    math.floor(data.Humanoid.Health),
                    math.floor(data.Humanoid.MaxHealth)
                )
            end
        else
            removeESP(player)
        end
    end
    end -- ESP throttle close

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

    -- Hitbox Expander — throttled
    if now - HITBOX_TICK >= HITBOX_INTERVAL then
        HITBOX_TICK = now
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

dlog("✓ loaded")
print("[DebugTools] loaded universal hub. RightShift — menu.")
end)

if not ok then
    warn("[DebugTools] runtime error: " .. tostring(err))
    -- показать на экране
    pcall(function()
        local sg = Instance.new("ScreenGui", game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
        sg.Name = "DebugToolsError"
        local f = Instance.new("Frame", sg)
        f.Size = UDim2.new(1, -20, 0, 100)
        f.Position = UDim2.new(0, 10, 0, 10)
        f.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        local t = Instance.new("TextLabel", f)
        t.Size = UDim2.new(1, -20, 1, -20)
        t.Position = UDim2.fromOffset(10, 10)
        t.BackgroundTransparency = 1
        t.TextColor3 = Color3.new(1, 1, 1)
        t.Font = Enum.Font.GothamBold
        t.TextSize = 14
        t.TextWrapped = true
        t.TextXAlignment = Enum.TextXAlignment.Left
        t.TextYAlignment = Enum.TextYAlignment.Top
        local stages = table.concat(__stages or {}, " → ")
        t.Text = "❌ ERROR\nЭтапы: " .. stages .. "\nОшибка: " .. tostring(err)
    end)
end
