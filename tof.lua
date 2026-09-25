-- LocalScript
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Создаём ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeleportMenu"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Главный фрейм (окно)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 220, 0, 120)
mainFrame.Position = UDim2.new(0.5, -110, 0.5, -60)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true -- можно перетаскивать мышкой
mainFrame.Parent = screenGui

-- Скругление углов
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = mainFrame

-- Обводка
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(90, 90, 100)
stroke.Thickness = 1.5
stroke.Parent = mainFrame

-- Заголовок
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "⚡ Teleport Menu"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = mainFrame

-- Кнопка телепорта
local tpButton = Instance.new("TextButton")
tpButton.Name = "TPButton"
tpButton.Size = UDim2.new(0.85, 0, 0, 40)
tpButton.Position = UDim2.new(0.5, 0, 0.5, -5)
tpButton.AnchorPoint = UDim2.new(0.5, 0, 0.5, 0)
tpButton.BackgroundColor3 = Color3.fromRGB(60, 130, 220)
tpButton.Text = "🏁 Телепорт на финиш"
tpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tpButton.Font = Enum.Font.GothamSemibold
tpButton.TextSize = 14
tpButton.BorderSizePixel = 0
tpButton.AutoButtonColor = false
tpButton.Parent = mainFrame

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = tpButton

-- Функция телепорта
local function teleport()
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Безопасно ищем цель через pcall
    local ok, target = pcall(function()
        return workspace.tower.sections.finish.exit.ParticleBrick
    end)

    if ok and target then
        hrp.CFrame = target.CFrame
    else
        warn("[TeleportMenu] Цель не найдена: workspace.tower.sections.finish.exit.ParticleBrick")
    end
end

-- Ховер-эффект
tpButton.MouseEnter:Connect(function()
    tpButton.BackgroundColor3 = Color3.fromRGB(80, 150, 240)
end)
tpButton.MouseLeave:Connect(function()
    tpButton.BackgroundColor3 = Color3.fromRGB(60, 130, 220)
end)

-- Клик
tpButton.MouseButton1Click:Connect(function()
    teleport()
end)

-- Закрытие по RightShift
local toggleKey = Enum.KeyCode.RightShift
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == toggleKey then
        mainFrame.Visible = not mainFrame.Visible
    end
end)
