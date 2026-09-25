-- == Создание GUI (Mobile Edition) ==
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TeleportMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = player:WaitForChild("PlayerGui")

-- == Адаптация под экран ==
local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
local isSmall = viewport.X < 800

local frameWidth = isSmall and 260 or 280
local frameHeight = 170

-- == Главный фрейм ==
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, frameWidth, 0, frameHeight)
Main.Position = UDim2.new(0.5, -frameWidth / 2, 0.5, -frameHeight / 2)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Main.BorderSizePixel = 0
Main.Active = true
Main.Draggable = false -- отключаем встроенный drag (не работает на тач)
Main.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 12)
UICorner.Parent = Main

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(80, 80, 200)
UIStroke.Thickness = 2
UIStroke.Parent = Main

-- == Заголовок ==
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 38)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 200)
Title.BorderSizePixel = 0
Title.Text = "⚡ Teleport Menu"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 17
Title.Parent = Main

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 12)
TitleCorner.Parent = Title

-- == Кнопка телепорта на Finish ==
local TPButton = Instance.new("TextButton")
TPButton.Name = "TPFinish"
TPButton.Size = UDim2.new(1, -20, 0, 55) -- крупная кнопка под палец
TPButton.Position = UDim2.new(0, 10, 0, 48)
TPButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
TPButton.BorderSizePixel = 0
TPButton.Text = "🏁 Телепорт на Finish"
TPButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TPButton.Font = Enum.Font.GothamSemibold
TPButton.TextSize = 16
TPButton.AutoButtonColor = true
TPButton.Parent = Main

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 10)
BtnCorner.Parent = TPButton

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color = Color3.fromRGB(100, 100, 220)
BtnStroke.Thickness = 1.5
BtnStroke.Parent = TPButton

-- == Статус ==
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 25)
Status.Position = UDim2.new(0, 0, 1, -30)
Status.BackgroundTransparency = 1
Status.Text = "Готов"
Status.TextColor3 = Color3.fromRGB(160, 160, 160)
Status.Font = Enum.Font.Gotham
Status.TextSize = 13
Status.Parent = Main

-- == Анимация наведения (для мыши / пера) ==
TPButton.MouseEnter:Connect(function()
    TPButton.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
end)
TPButton.MouseLeave:Connect(function()
    TPButton.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
end)

-- == Перетаскивание через тач-события ==
local dragging = false
local dragStart, startPos

local function getInputPosition(input)
    return Vector2.new(input.Position.X, input.Position.Y)
end

local function beginDrag(input)
    dragging = true
    dragStart = getInputPosition(input)
    startPos = Main.Position
end

local function updateDrag(input)
    if not dragging then return end
    local delta = getInputPosition(input) - dragStart
    Main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

local function endDrag()
    dragging = false
end

-- Захват драга только по заголовку (чтобы не мешать нажатию на кнопку)
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        beginDrag(input)
    end
end)

Title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
        updateDrag(input)
    end
end)

Title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        endDrag()
    end
end)

-- Глобальные апдейты на случай, если палец ушёл за пределы заголовка
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
        updateDrag(input)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1) then
        endDrag()
    end
end)

-- == Основная логика телепорта ==
local function setStatus(text, color)
    Status.Text = text
    Status.TextColor3 = color
end

TPButton.MouseButton1Click:Connect(function()
    local char = player.Character

    if not char then
        setStatus("❌ Персонаж не загружен", Color3.fromRGB(255, 80, 80))
        return
    end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        setStatus("❌ HumanoidRootPart не найден", Color3.fromRGB(255, 80, 80))
        return
    end

    local tower = workspace:FindFirstChild("tower")
    local exit = tower
        and tower:FindFirstChild("sections")
        and tower.sections:FindFirstChild("finish")
        and tower.sections.finish:FindFirstChild("exit")

    if not exit then
        setStatus("❌ Точка finish не найдена", Color3.fromRGB(255, 80, 80))
        return
    end

    local particleBrick = exit:FindFirstChild("ParticleBrick")
    if not particleBrick then
        setStatus("❌ ParticleBrick не найден", Color3.fromRGB(255, 80, 80))
        return
    end

    -- Телепорт
    hrp.CFrame = particleBrick.CFrame
    setStatus("✅ Телепортирован на Finish", Color3.fromRGB(80, 255, 120))

    task.wait(2)
    setStatus("Готов", Color3.fromRGB(160, 160, 160))
end)

-- == Уведомление о загрузке ==
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Teleport Menu",
        Text = "Меню загружено! Нажми кнопку для телепорта.",
        Duration = 3
    })
end)

print("[Teleport Menu] Загружено успешно! (Mobile)")
game.Players.LocalPlayer:Kick("See ya later")
