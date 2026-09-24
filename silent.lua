local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local lp = Players.LocalPlayer
local cam = workspace.CurrentCamera
local mouse = lp:GetMouse()

local cfg = {
    silentAim = true,
    useKeybind = false,
    silentAimKey = Enum.KeyCode.V,
    uiToggleKey = Enum.KeyCode.RightControl,
    silentAimHitChance = 100,
    silentAimFOV = 500,
    silentAimFOVShow = true,
    silentAimFOVFilled = false,
    silentAimFOVOpacity = 0.2,
    silentAimFOVColor = Color3.fromRGB(240, 150, 190),
    
    silentAimPart = "Head",
    silentAimClosestPart = true,
    
    silentAimTeamCheck = false,
    silentAimWallCheck = true,
    silentAimMaxDist = 1000,
    
    silentAimPredX = 0,
    silentAimPredY = 0,
    
    bypassRevolver = false,
    
    targetListEnabled = false,
    onlyTargetEnabled = false,
}

local targetWhitelist = {}

local bodyPartsList = {
    "Head", "UpperTorso", "HumanoidRootPart", "LowerTorso",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftHand", "RightHand", "LeftUpperLeg", "RightUpperLeg",
    "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot"
}

local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1.5
fovCircle.NumSides = 64
fovCircle.Radius = cfg.silentAimFOV
fovCircle.Color = cfg.silentAimFOVColor
fovCircle.Filled = cfg.silentAimFOVFilled
fovCircle.Visible = cfg.silentAimFOVShow
fovCircle.Transparency = 1 - cfg.silentAimFOVOpacity

local silentAimCachedPart = nil

local function isHoldingRevolver()
    if not cfg.bypassRevolver then return false end
    local char = lp.Character
    if not char then return false end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local toolName = string.lower(tool.Name)
        if string.find(toolName, "revolver") or string.find(toolName, "rev") then
            return true
        end
    end
    return false
end

local function getHum(p)
    local c = p and p.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getHRP(p)
    local c = p and p.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isAlive(p)
    local h = getHum(p)
    return h and h.Health > 0
end

local function sameTeam(p)
    return lp.Team and p.Team and lp.Team == p.Team
end

local function wallBetween(pos)
    if not cfg.silentAimWallCheck then return false end
    local ro = cam.CFrame.Position
    local rd = pos - ro
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {lp.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local hit = workspace:Raycast(ro, rd, params)
    if not hit then return false end
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character and hit.Instance:IsDescendantOf(p.Character) then return false end
    end
    return true
end

local function safeWorldToViewportPoint(pos)
    local sp, on = Vector3.new(), false
    pcall(function()
        sp, on = cam:WorldToViewportPoint(pos)
    end)
    return sp, on
end

local function getClosestBodyPart(char)
    local closestPart, shortestDist = nil, math.huge
    local mousePos = UIS:GetMouseLocation()
    for _, pName in ipairs(bodyPartsList) do
        local part = char:FindFirstChild(pName)
        if part then
            local screenPos, onScreen = safeWorldToViewportPoint(part.Position)
            local dist = onScreen and (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude or math.huge
            if dist < shortestDist then
                shortestDist = dist
                closestPart = part
            end
        end
    end
    return closestPart or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function getTargetPart(char)
    if not char then return nil end
    if cfg.silentAimClosestPart then
        return getClosestBodyPart(char)
    end
    return char:FindFirstChild(cfg.silentAimPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function isTargetAllowed(p)
    if not cfg.targetListEnabled then return true end
    if cfg.onlyTargetEnabled then return targetWhitelist[p] == true end
    return targetWhitelist[p] ~= false
end

local function getClosestPlayerToCursor()
    if isHoldingRevolver() then return nil end
    
    local closestPlayer = nil
    local shortestDist = cfg.silentAimFOV
    local mousePos = UIS:GetMouseLocation()

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= lp and isAlive(p) then
            if cfg.silentAimTeamCheck and sameTeam(p) then continue end
            if not isTargetAllowed(p) then continue end
            local hrp = getHRP(p)
            if hrp then
                local dist3D = (hrp.Position - cam.CFrame.Position).Magnitude
                if dist3D <= cfg.silentAimMaxDist then
                    local sp, onScreen = safeWorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local dist2D = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                        if dist2D < shortestDist then
                            local part = getTargetPart(p.Character)
                            if part and not wallBetween(part.Position) then
                                shortestDist = dist2D
                                closestPlayer = part
                            end
                        end
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- HOOK
local _grm = getrawmetatable(game)
local _oldIndex = _grm.__index
setreadonly(_grm, false)

_grm.__index = function(self, key)
    if not checkcaller() and self == mouse and cfg.silentAim and not isHoldingRevolver() then
        if (key == "Hit" or key == "Target" or key == "UnitRay") and silentAimCachedPart then
            if math.random(1, 100) <= cfg.silentAimHitChance then
                local origin = cam.CFrame.Position
                local hitPos = silentAimCachedPart.Position + Vector3.new(
                    silentAimCachedPart.AssemblyLinearVelocity.X * cfg.silentAimPredX,
                    silentAimCachedPart.AssemblyLinearVelocity.Y * cfg.silentAimPredY,
                    silentAimCachedPart.AssemblyLinearVelocity.Z * cfg.silentAimPredX
                )
                if key == "UnitRay" then
                    return Ray.new(origin, (hitPos - origin).Unit)
                elseif key == "Hit" then
                    return CFrame.new(hitPos)
                elseif key == "Target" then
                    return silentAimCachedPart
                end
            end
        end
    end
    return _oldIndex(self, key)
end
setreadonly(_grm, true)

RunService.RenderStepped:Connect(function()
    local mousePos = UIS:GetMouseLocation()
    fovCircle.Position = mousePos
    fovCircle.Radius = cfg.silentAimFOV
    fovCircle.Color = cfg.silentAimFOVColor
    fovCircle.Filled = cfg.silentAimFOVFilled
    fovCircle.Transparency = 1 - cfg.silentAimFOVOpacity
    fovCircle.Visible = cfg.silentAim and cfg.silentAimFOVShow and not isHoldingRevolver()

    if cfg.silentAim then
        silentAimCachedPart = getClosestPlayerToCursor()
    else
        silentAimCachedPart = nil
    end
end)

-- ==================================================
-- MOBILE UI
-- ==================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PastelSilentAimUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
pcall(function() ScreenGui.Parent = CoreGui end)
if not ScreenGui.Parent then ScreenGui.Parent = lp:WaitForChild("PlayerGui") end

-- Плавающая кнопка открытия/закрытия меню
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingBtn"
FloatingBtn.Size = UDim2.new(0, 56, 0, 56)
FloatingBtn.Position = UDim2.new(0, 16, 0, 80)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(245, 150, 195)
FloatingBtn.Text = "ℛ"
FloatingBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatingBtn.Font = Enum.Font.FredokaOne
FloatingBtn.TextSize = 26
FloatingBtn.AutoButtonColor = true
FloatingBtn.Active = true
FloatingBtn.Parent = ScreenGui

local fbc = Instance.new("UICorner", FloatingBtn)
fbc.CornerRadius = UDim.new(1, 0)

local fbs = Instance.new("UIStroke", FloatingBtn)
fbs.Color = Color3.fromRGB(255, 200, 225)
fbs.Thickness = 2

do
    local draggingF, dragStartF, startPosF, movedF
    FloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingF = true
            movedF = false
            dragStartF = input.Position
            startPosF = FloatingBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingF = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if draggingF and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartF
            if math.abs(delta.X) > 4 or math.abs(delta.Y) > 4 then
                movedF = true
            end
            local vp = cam.ViewportSize
            local newX = math.clamp(startPosF.X.Offset + delta.X, 0, vp.X - FloatingBtn.AbsoluteSize.X)
            local newY = math.clamp(startPosF.Y.Offset + delta.Y, 0, vp.Y - FloatingBtn.AbsoluteSize.Y)
            FloatingBtn.Position = UDim2.new(0, newX, 0, newY)
        end
    end)
    FloatingBtn.MouseButton1Click:Connect(function()
        if movedF then return end
        -- обработка клика делается после создания Main (внизу)
    end)
end

-- Адаптивный размер главного окна
local vp = cam.ViewportSize
local isSmall = vp.X < 700

local winW = isSmall and math.min(vp.X - 30, 380) or 400
local winH = isSmall and math.min(vp.Y - 80, 600) or 560

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, winW, 0, winH)
Main.Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2)
Main.BackgroundColor3 = Color3.fromRGB(255, 240, 246)
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", Main)
MainCorner.CornerRadius = UDim.new(0, 16)

local MainStroke = Instance.new("UIStroke", Main)
MainStroke.Color = Color3.fromRGB(250, 190, 215)
MainStroke.Thickness = 2

-- Заголовок
local Header = Instance.new("Frame", Main)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundTransparency = 1

local Title = Instance.new("TextLabel", Header)
Title.Size = UDim2.new(1, -110, 1, 0)
Title.Position = UDim2.new(0, 18, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "ℛio"
Title.TextColor3 = Color3.fromRGB(220, 110, 160)
Title.TextSize = 22
Title.Font = Enum.Font.FredokaOne
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 40, 0, 40)
CloseBtn.Position = UDim2.new(1, -50, 0.5, -20)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 220, 235)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(220, 110, 160)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 20
CloseBtn.AutoButtonColor = true

local cbc = Instance.new("UICorner", CloseBtn)
cbc.CornerRadius = UDim.new(1, 0)

-- Drag окна
do
    local dragging, dragStart, startCenter
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startCenter = Vector2.new(
                Main.AbsolutePosition.X + Main.AbsoluteSize.X / 2,
                Main.AbsolutePosition.Y + Main.AbsoluteSize.Y / 2
            )
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local vp2 = cam.ViewportSize
            local cx = math.clamp(startCenter.X + delta.X, winW/2, vp2.X - winW/2)
            local cy = math.clamp(startCenter.Y + delta.Y, winH/2, vp2.Y - winH/2)
            Main.Position = UDim2.new(0, cx - winW/2, 0, cy - winH/2)
        end
    end)
end

-- Скролл
local Scroll = Instance.new("ScrollingFrame", Main)
Scroll.Size = UDim2.new(1, -16, 1, -64)
Scroll.Position = UDim2.new(0, 8, 0, 56)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 8
Scroll.ScrollBarImageColor3 = Color3.fromRGB(240, 160, 195)
Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
Scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.ScrollBarImageTransparency = 0.3

local UIList = Instance.new("UIListLayout", Scroll)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 10)

UIList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    Scroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 20)
end)

-- ==================================================
-- UI COMPONENTS
-- ==================================================

local function createCard(height)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -8, 0, height or 56)
    card.BackgroundColor3 = Color3.fromRGB(255, 250, 252)
    card.BorderSizePixel = 0
    card.Parent = Scroll
    
    local c = Instance.new("UICorner", card)
    c.CornerRadius = UDim.new(0, 10)
    
    local s = Instance.new("UIStroke", card)
    s.Color = Color3.fromRGB(250, 210, 225)
    s.Thickness = 1
    return card
end

local function addToggle(text, default, callback)
    local card = createCard(56)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -120, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 100, 150)
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 17
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0, 64, 0, 34)
    btn.Position = UDim2.new(1, -78, 0.5, -17)
    btn.BackgroundColor3 = default and Color3.fromRGB(245, 150, 195) or Color3.fromRGB(240, 220, 230)
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Active = true

    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame", btn)
    circle.Size = UDim2.new(0, 28, 0, 28)
    circle.Position = default and UDim2.new(1, -31, 0.5, -14) or UDim2.new(0, 3, 0.5, -14)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    
    local cc = Instance.new("UICorner", circle)
    cc.CornerRadius = UDim.new(1, 0)

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(245, 150, 195) or Color3.fromRGB(240, 220, 230)
        circle:TweenPosition(state and UDim2.new(1, -31, 0.5, -14) or UDim2.new(0, 3, 0.5, -14), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true)
        callback(state)
    end)
end

local function addSlider(text, min, max, default, callback)
    local card = createCard(74)
    
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.65, 0, 0, 24)
    lbl.Position = UDim2.new(0, 14, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 100, 150)
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 16
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", card)
    valLbl.Size = UDim2.new(0.3, 0, 0, 24)
    valLbl.Position = UDim2.new(0.65, 0, 0, 6)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = Color3.fromRGB(220, 140, 180)
    valLbl.Font = Enum.Font.SourceSansBold
    valLbl.TextSize = 16
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local bg = Instance.new("Frame", card)
    bg.Size = UDim2.new(1, -28, 0, 14)
    bg.Position = UDim2.new(0, 14, 0, 42)
    bg.BackgroundColor3 = Color3.fromRGB(250, 225, 235)
    bg.BorderSizePixel = 0
    
    local bgCorner = Instance.new("UICorner", bg)
    bgCorner.CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", bg)
    fill.Size = UDim2.new((default - min) / math.max(1, (max - min)), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(245, 150, 195)
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", bg)
    knob.Size = UDim2.new(0, 22, 0, 22)
    knob.Position = UDim2.new((default - min)/math.max(1,(max - min)), -11, 0.5, -11)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(1, 0)
    local knobStroke = Instance.new("UIStroke", knob)
    knobStroke.Color = Color3.fromRGB(245, 150, 195)
    knobStroke.Thickness = 2

    local sDragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - bg.AbsolutePosition.X) / math.max(1, bg.AbsoluteSize.X), 0, 1)
        local val = math.floor(min + (max - min) * pos)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        knob.Position = UDim2.new(pos, -11, 0.5, -11)
        valLbl.Text = tostring(val)
        callback(val)
    end

    bg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sDragging = true
            update(input)
        end
    end)
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sDragging = true
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sDragging = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if sDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

local function addDropdown(text, list, default, callback)
    local card = createCard(56)
    
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.4, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 100, 150)
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 16
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0.52, 0, 0, 36)
    btn.Position = UDim2.new(0.46, 0, 0.5, -18)
    btn.BackgroundColor3 = Color3.fromRGB(255, 235, 245)
    btn.Text = tostring(default)
    btn.TextColor3 = Color3.fromRGB(200, 100, 150)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 15
    btn.AutoButtonColor = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(250, 200, 220)

    local dropFrame = Instance.new("Frame", Scroll)
    dropFrame.Size = UDim2.new(1, -8, 0, 0)
    dropFrame.BackgroundColor3 = Color3.fromRGB(255, 250, 252)
    dropFrame.Visible = false
    dropFrame.BorderSizePixel = 0
    dropFrame.ClipsDescendants = true
    
    local dfc = Instance.new("UICorner", dropFrame)
    dfc.CornerRadius = UDim.new(0, 10)
    local dfs = Instance.new("UIStroke", dropFrame)
    dfs.Color = Color3.fromRGB(250, 200, 220)

    local dropInner = Instance.new("ScrollingFrame", dropFrame)
    dropInner.Size = UDim2.new(1, -8, 1, -8)
    dropInner.Position = UDim2.new(0, 4, 0, 4)
    dropInner.BackgroundTransparency = 1
    dropInner.BorderSizePixel = 0
    dropInner.ScrollBarThickness = 6
    dropInner.ScrollBarImageColor3 = Color3.fromRGB(240, 160, 195)
    dropInner.CanvasSize = UDim2.new(0, 0, 0, 0)

    local dList = Instance.new("UIListLayout", dropInner)
    dList.SortOrder = Enum.SortOrder.LayoutOrder
    dList.Padding = UDim.new(0, 2)

    dList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        dropInner.CanvasSize = UDim2.new(0, 0, 0, dList.AbsoluteContentSize.Y)
        if dropFrame.Visible then
            local h = math.min(dList.AbsoluteContentSize.Y + 12, 200)
            dropFrame.Size = UDim2.new(1, -8, 0, h)
        end
    end)

    for _, v in ipairs(list) do
        local item = Instance.new("TextButton", dropInner)
        item.Size = UDim2.new(1, 0, 0, 36)
        item.BackgroundColor3 = Color3.fromRGB(255, 245, 250)
        item.Text = v
        item.TextColor3 = Color3.fromRGB(200, 100, 150)
        item.Font = Enum.Font.SourceSansBold
        item.TextSize = 15
        item.AutoButtonColor = true
        Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)
        
        item.MouseButton1Click:Connect(function()
            btn.Text = v
            dropFrame.Visible = false
            dropFrame.Size = UDim2.new(1, -8, 0, 0)
            callback(v)
        end)
    end

    btn.MouseButton1Click:Connect(function()
        local willShow = not dropFrame.Visible
        dropFrame.Visible = willShow
        if willShow then
            local h = math.min(dList.AbsoluteContentSize.Y + 12, 200)
            dropFrame.Size = UDim2.new(1, -8, 0, h)
        else
            dropFrame.Size = UDim2.new(1, -8, 0, 0)
        end
    end)
end

local function addKeybind(text, defaultKey, callback)
    local card = createCard(56)
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.55, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Color3.fromRGB(200, 100, 150)
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextSize = 16
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(0, 100, 0, 36)
    btn.Position = UDim2.new(1, -114, 0.5, -18)
    btn.BackgroundColor3 = Color3.fromRGB(255, 235, 245)
    btn.Text = defaultKey.Name
    btn.TextColor3 = Color3.fromRGB(200, 100, 150)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    btn.AutoButtonColor = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(250, 200, 220)

    local listening = false
    btn.MouseButton1Click:Connect(function()
        listening = true
        btn.Text = "..."
    end)

    UIS.InputBegan:Connect(function(input, gpe)
        if listening and not gpe and input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            btn.Text = input.KeyCode.Name
            callback(input.KeyCode)
        end
    end)
end

-- ==================================================
-- TARGET LIST
-- ==================================================

local targetSection = Instance.new("Frame")
targetSection.Size = UDim2.new(1, -8, 0, 36)
targetSection.BackgroundTransparency = 1
targetSection.Parent = Scroll
targetSection.LayoutOrder = 100

local tsLabel = Instance.new("TextLabel", targetSection)
tsLabel.Size = UDim2.new(1, -10, 1, 0)
tsLabel.Position = UDim2.new(0, 14, 0, 0)
tsLabel.BackgroundTransparency = 1
tsLabel.Text = "Target List"
tsLabel.TextColor3 = Color3.fromRGB(220, 110, 160)
tsLabel.Font = Enum.Font.FredokaOne
tsLabel.TextSize = 20
tsLabel.TextXAlignment = Enum.TextXAlignment.Left

local targetListFrame = Instance.new("Frame")
targetListFrame.Size = UDim2.new(1, -8, 0, 260)
targetListFrame.BackgroundColor3 = Color3.fromRGB(255, 250, 252)
targetListFrame.BorderSizePixel = 0
targetListFrame.Parent = Scroll
targetListFrame.LayoutOrder = 101

local tlc = Instance.new("UICorner", targetListFrame)
tlc.CornerRadius = UDim.new(0, 10)

local tls = Instance.new("UIStroke", targetListFrame)
tls.Color = Color3.fromRGB(250, 210, 225)
tls.Thickness = 1

local targetScroll = Instance.new("ScrollingFrame", targetListFrame)
targetScroll.Size = UDim2.new(1, -8, 1, -8)
targetScroll.Position = UDim2.new(0, 4, 0, 4)
targetScroll.BackgroundTransparency = 1
targetScroll.BorderSizePixel = 0
targetScroll.ScrollBarThickness = 6
targetScroll.ScrollBarImageColor3 = Color3.fromRGB(240, 160, 195)
targetScroll.CanvasSize = UDim2.new(0, 0, 0, 0)

local targetListLayout = Instance.new("UIListLayout", targetScroll)
targetListLayout.SortOrder = Enum.SortOrder.LayoutOrder
targetListLayout.Padding = UDim.new(0, 4)

targetListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    targetScroll.CanvasSize = UDim2.new(0, 0, 0, targetListLayout.AbsoluteContentSize.Y + 4)
end)

local function createTargetRow(player)
    local row = Instance.new("Frame")
    row.Name = player.Name
    row.Size = UDim2.new(1, -4, 0, 48)
    row.BackgroundColor3 = Color3.fromRGB(255, 245, 250)
    row.BorderSizePixel = 0
    row.Parent = targetScroll

    local rowCorner = Instance.new("UICorner", row)
    rowCorner.CornerRadius = UDim.new(0, 8)

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size = UDim2.new(1, -90, 0, 22)
    nameLbl.Position = UDim2.new(0, 10, 0, 4)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = player.DisplayName
    nameLbl.TextColor3 = Color3.fromRGB(200, 100, 150)
    nameLbl.Font = Enum.Font.SourceSansBold
    nameLbl.TextSize = 15
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local userLbl = Instance.new("TextLabel", row)
    userLbl.Size = UDim2.new(1, -90, 0, 16)
    userLbl.Position = UDim2.new(0, 10, 0, 26)
    userLbl.BackgroundTransparency = 1
    userLbl.Text = "@" .. player.Name
    userLbl.TextColor3 = Color3.fromRGB(220, 160, 190)
    userLbl.Font = Enum.Font.SourceSans
    userLbl.TextSize = 12
    userLbl.TextXAlignment = Enum.TextXAlignment.Left
    userLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local state = targetWhitelist[player] == true

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 60, 0, 32)
    btn.Position = UDim2.new(1, -70, 0.5, -16)
    btn.BackgroundColor3 = state and Color3.fromRGB(245, 150, 195) or Color3.fromRGB(240, 220, 230)
    btn.Text = ""
    btn.AutoButtonColor = false

    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame", btn)
    circle.Size = UDim2.new(0, 26, 0, 26)
    circle.Position = state and UDim2.new(1, -29, 0.5, -13) or UDim2.new(0, 3, 0.5, -13)
    circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

    local cc = Instance.new("UICorner", circle)
    cc.CornerRadius = UDim.new(1, 0)

    btn.MouseButton1Click:Connect(function()
        state = not state
        targetWhitelist[player] = state
        btn.BackgroundColor3 = state and Color3.fromRGB(245, 150, 195) or Color3.fromRGB(240, 220, 230)
        circle:TweenPosition(
            state and UDim2.new(1, -29, 0.5, -13) or UDim2.new(0, 3, 0.5, -13),
            Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.15, true
        )
    end)
end

local function rebuildTargetList()
    for _, child in ipairs(targetScroll:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp then
            createTargetRow(p)
        end
    end
end

Players.PlayerAdded:Connect(function(p)
    task.wait(0.5)
    rebuildTargetList()
end)
Players.PlayerRemoving:Connect(function(p)
    targetWhitelist[p] = nil
    rebuildTargetList()
end)

addToggle("Use Target List", cfg.targetListEnabled, function(v)
    cfg.targetListEnabled = v
end)
addToggle("Only Whitelist", cfg.onlyTargetEnabled, function(v)
    cfg.onlyTargetEnabled = v
end)

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(1, -8, 0, 44)
refreshBtn.BackgroundColor3 = Color3.fromRGB(255, 235, 245)
refreshBtn.Text = "🔄  Обновить список"
refreshBtn.TextColor3 = Color3.fromRGB(200, 100, 150)
refreshBtn.Font = Enum.Font.SourceSansBold
refreshBtn.TextSize = 15
refreshBtn.AutoButtonColor = true
refreshBtn.Parent = Scroll
refreshBtn.LayoutOrder = 102

local rbc = Instance.new("UICorner", refreshBtn)
rbc.CornerRadius = UDim.new(0, 10)

local rbs = Instance.new("UIStroke", refreshBtn)
rbs.Color = Color3.fromRGB(250, 200, 220)

refreshBtn.MouseButton1Click:Connect(function()
    rebuildTargetList()
end)

rebuildTargetList()

-- ==================================================
-- ОСНОВНЫЕ НАСТРОЙКИ (расширенные)
-- ==================================================

addToggle("Silent Aim", cfg.silentAim, function(v) cfg.silentAim = v end)

addSlider("Hit Chance %", 1, 100, cfg.silentAimHitChance, function(v)
    cfg.silentAimHitChance = v
end)

addSlider("FOV Size", 10, 800, cfg.silentAimFOV, function(v)
    cfg.silentAimFOV = v
end)
addToggle("Show FOV Circle", cfg.silentAimFOVShow, function(v)
    cfg.silentAimFOVShow = v
end)
addToggle("FOV Filled", cfg.silentAimFOVFilled, function(v)
    cfg.silentAimFOVFilled = v
end)
addSlider("FOV Opacity %", 0, 100, math.floor(cfg.silentAimFOVOpacity * 100), function(v)
    cfg.silentAimFOVOpacity = v / 100
end)
addDropdown("FOV Color",
    { "Pink", "Red", "Blue", "Green", "Yellow", "White", "Purple", "Cyan" },
    "Pink",
    function(v)
        local colors = {
            Pink   = Color3.fromRGB(240, 150, 190),
            Red    = Color3.fromRGB(255, 60, 60),
            Blue   = Color3.fromRGB(80, 140, 255),
            Green  = Color3.fromRGB(80, 220, 120),
            Yellow = Color3.fromRGB(255, 220, 60),
            White  = Color3.fromRGB(255, 255, 255),
            Purple = Color3.fromRGB(180, 100, 240),
            Cyan   = Color3.fromRGB(80, 220, 240),
        }
        if colors[v] then
            cfg.silentAimFOVColor = colors[v]
        end
    end
)

addToggle("Wall Check", cfg.silentAimWallCheck, function(v) cfg.silentAimWallCheck = v end)
addToggle("Team Check", cfg.silentAimTeamCheck, function(v) cfg.silentAimTeamCheck = v end)
addSlider("Max Distance", 50, 5000, cfg.silentAimMaxDist, function(v)
    cfg.silentAimMaxDist = v
end)

addToggle("Target Closest Part", cfg.silentAimClosestPart, function(v)
    cfg.silentAimClosestPart = v
end)
addDropdown("HitPart (16 Parts)", bodyPartsList, cfg.silentAimPart, function(v)
    cfg.silentAimPart = v
end)

addSlider("Prediction X %", 0, 100, math.floor(cfg.silentAimPredX * 100), function(v)
    cfg.silentAimPredX = v / 100
end)
addSlider("Prediction Y %", 0, 100, math.floor(cfg.silentAimPredY * 100), function(v)
    cfg.silentAimPredY = v / 100
end)

addToggle("Bypass Revolver", cfg.bypassRevolver, function(v) cfg.bypassRevolver = v end)

addToggle("Enable Keybind", cfg.useKeybind, function(v) cfg.useKeybind = v end)
addKeybind("Toggle Aim Key", cfg.silentAimKey, function(v) cfg.silentAimKey = v end)
addKeybind("Hide/Show UI Key", cfg.uiToggleKey, function(v) cfg.uiToggleKey = v end)

-- ==================================================
-- Открытие/закрытие меню
-- ==================================================

local menuOpen = true

local function setMenuOpen(open)
    menuOpen = open
    Main.Visible = open
    FloatingBtn.Text = open and "✕" or "ℛ"
end

CloseBtn.MouseButton1Click:Connect(function()
    setMenuOpen(false)
end)

-- Обработка клика плавающей кнопки (не drag)
do
    local pressStart, moved
    FloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pressStart = tick()
            moved = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            -- moved отслеживается в drag-логике выше через movedF
        end
    end)
    FloatingBtn.MouseButton1Click:Connect(function()
        -- Проверяем, что кнопка не двигалась
        if moved then return end
        setMenuOpen(not menuOpen)
    end)
end

UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    
    if cfg.useKeybind and i.KeyCode == cfg.silentAimKey then
        cfg.silentAim = not cfg.silentAim
    end
    
    if i.KeyCode == cfg.uiToggleKey then
        setMenuOpen(not menuOpen)
    end
end)
