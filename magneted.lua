local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

------------------------------------------------
-- CONFIG
------------------------------------------------

local Config = {
    Enabled = true,

    Teleport = true,
    Magnet = true,
    DashCancel = true,

    TeleportHeight = 2,
    MagnetDuration = 0.5,
    MagnetStrength = 50,
    MagnetSmoothness = 0.65,

    ActivationKey1 = Enum.KeyCode.E,
    ActivationKey2 = Enum.KeyCode.Q
}

------------------------------------------------
-- VARIABLES
------------------------------------------------

local pullConnection = nil
local dashVelocity = nil
local npcList = {}
local lastNpcUpdate = 0

------------------------------------------------
-- CHARACTER SETUP
------------------------------------------------

local function setupCharacter(newChar)
    character = newChar
    rootPart = newChar:WaitForChild("HumanoidRootPart")
    dashVelocity = nil

    rootPart.ChildAdded:Connect(function(child)
        if child:IsA("BodyVelocity") or child:IsA("LinearVelocity") then
            dashVelocity = child
        end
    end)
end

if player.Character then
    setupCharacter(player.Character)
end

player.CharacterAdded:Connect(setupCharacter)

------------------------------------------------
-- NPC CACHE
------------------------------------------------

local function updateNpcCache()
    npcList = {}

    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model")
            and model:FindFirstChild("Humanoid")
            and model:FindFirstChild("HumanoidRootPart") then

            local root = model.HumanoidRootPart

            if root ~= rootPart then
                table.insert(npcList, root)
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    if tick() - lastNpcUpdate > 0.5 then
        lastNpcUpdate = tick()
        updateNpcCache()
    end
end)

------------------------------------------------
-- GET CLOSEST TARGET
------------------------------------------------

local function getClosestTarget()
    if not rootPart then
        return nil
    end

    local closestRoot = nil
    local shortestDistance = math.huge
    local myPos = rootPart.Position

    -- PLAYERS
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then

            local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
            local root = plr.Character:FindFirstChild("HumanoidRootPart")

            if humanoid and humanoid.Health > 0 and root then
                local dist = (myPos - root.Position).Magnitude

                if dist < shortestDistance and dist > 0.1 then
                    shortestDistance = dist
                    closestRoot = root
                end
            end
        end
    end

    -- NPCS
    for _, npcRoot in ipairs(npcList) do
        if npcRoot and npcRoot.Parent then

            local humanoid = npcRoot.Parent:FindFirstChildOfClass("Humanoid")

            if humanoid and humanoid.Health > 0 then
                local dist = (myPos - npcRoot.Position).Magnitude

                if dist < shortestDistance and dist > 0.1 then
                    shortestDistance = dist
                    closestRoot = npcRoot
                end
            end
        end
    end

    return closestRoot
end

------------------------------------------------
-- MAGNET
------------------------------------------------

local function startMagnetPull()

    if not Config.Magnet then
        return
    end

    if pullConnection then
        pullConnection:Disconnect()
        pullConnection = nil
    end

    local startTime = tick()

    pullConnection = RunService.Heartbeat:Connect(function()

        if not rootPart or not rootPart.Parent then
            pullConnection:Disconnect()
            pullConnection = nil
            return
        end

        local elapsed = tick() - startTime

        if elapsed >= Config.MagnetDuration then
            pullConnection:Disconnect()
            pullConnection = nil
            return
        end

        local targetRoot = getClosestTarget()

        if not targetRoot then
            return
        end

        local currentPos = rootPart.Position

        local targetHorizontal = Vector3.new(
            targetRoot.Position.X,
            currentPos.Y,
            targetRoot.Position.Z
        )

        local direction = targetHorizontal - currentPos
        local distance = direction.Magnitude

        if distance > 1 then

            direction = direction.Unit

            local desiredVelocity =
                direction * Config.MagnetStrength

            local currentVelocity =
                rootPart.AssemblyLinearVelocity

            local newVelocity =
                currentVelocity:Lerp(
                    desiredVelocity,
                    Config.MagnetSmoothness
                )

            rootPart.AssemblyLinearVelocity = Vector3.new(
                newVelocity.X * 0.85,
                currentVelocity.Y,
                newVelocity.Z * 0.85
            )
        end
    end)
end

------------------------------------------------
-- DASH CANCEL
------------------------------------------------

local function cancelDash()

    if not Config.DashCancel then
        return
    end

    if dashVelocity and dashVelocity.Parent then
        dashVelocity:Destroy()
        dashVelocity = nil
    end

    if rootPart then
        local velocity = rootPart.AssemblyLinearVelocity

        rootPart.AssemblyLinearVelocity = Vector3.new(
            0,
            velocity.Y,
            0
        )
    end
end

------------------------------------------------
-- MAIN ACTION
------------------------------------------------

local function executeAction()

    if not Config.Enabled then
        return
    end

    if not rootPart then
        return
    end

    local targetRoot = getClosestTarget()

    ------------------------------------------------
    -- TP
    ------------------------------------------------

    if Config.Teleport and targetRoot then

        local targetPos =
            targetRoot.Position +
            Vector3.new(0, Config.TeleportHeight, 0)

        rootPart.CFrame =
            CFrame.new(
                targetPos.X,
                targetPos.Y,
                targetPos.Z
            )
    end

    ------------------------------------------------
    -- MAGNET
    ------------------------------------------------

    if Config.Magnet then
        startMagnetPull()
    end

    ------------------------------------------------
    -- DASH CANCEL
    ------------------------------------------------

    if Config.DashCancel then
        cancelDash()
    end
end

------------------------------------------------
-- KEYBOARD
------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)

    if gameProcessed then
        return
    end

    if input.KeyCode == Config.ActivationKey1
        or input.KeyCode == Config.ActivationKey2 then

        executeAction()
    end
end)

------------------------------------------------
-- GUI
------------------------------------------------

local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("MagnetConfigGui")

if oldGui then
    oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MagnetConfigGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

------------------------------------------------
-- MAIN FRAME
------------------------------------------------

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 270)
main.Position = UDim2.new(0.5, -130, 0.5, -135)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
main.BorderSizePixel = 0
main.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = main

------------------------------------------------
-- TITLE
------------------------------------------------

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 45)
title.BackgroundTransparency = 1
title.Text = "MAGNET CONFIG"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.Parent = main

------------------------------------------------
-- STATUS
------------------------------------------------

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 25)
status.Position = UDim2.new(0, 10, 0, 43)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(100, 255, 140)
status.TextSize = 14
status.Font = Enum.Font.Gotham
status.Text = "STATUS: ON"
status.Parent = main

------------------------------------------------
-- BUTTON CREATOR
------------------------------------------------

local function createToggle(text, y, callback, initial)

    local button = Instance.new("TextButton")

    button.Size = UDim2.new(1, -30, 0, 38)
    button.Position = UDim2.new(0, 15, 0, y)

    button.BackgroundColor3 =
        initial
        and Color3.fromRGB(40, 110, 65)
        or Color3.fromRGB(70, 70, 75)

    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextSize = 15
    button.Font = Enum.Font.GothamBold
    button.Text = text .. ": " .. (initial and "ON" or "OFF")
    button.Parent = main

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 7)
    buttonCorner.Parent = button

    local state = initial

    button.MouseButton1Click:Connect(function()

        state = not state

        button.Text =
            text .. ": " .. (state and "ON" or "OFF")

        button.BackgroundColor3 =
            state
            and Color3.fromRGB(40, 110, 65)
            or Color3.fromRGB(70, 70, 75)

        callback(state)
    end)

    return button
end

------------------------------------------------
-- TOGGLES
------------------------------------------------

createToggle(
    "TP",
    75,
    function(value)
        Config.Teleport = value
    end,
    Config.Teleport
)

createToggle(
    "MAGNET",
    120,
    function(value)
        Config.Magnet = value
    end,
    Config.Magnet
)

createToggle(
    "DASH CANCEL",
    165,
    function(value)
        Config.DashCancel = value
    end,
    Config.DashCancel
)

------------------------------------------------
-- HIDE BUTTON
------------------------------------------------

local hideButton = Instance.new("TextButton")

hideButton.Size = UDim2.new(1, -30, 0, 32)
hideButton.Position = UDim2.new(0, 15, 0, 215)
hideButton.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
hideButton.Text = "HIDE MENU  [RightShift]"
hideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
hideButton.TextSize = 13
hideButton.Font = Enum.Font.GothamBold
hideButton.Parent = main

local hideCorner = Instance.new("UICorner")
hideCorner.CornerRadius = UDim.new(0, 7)
hideCorner.Parent = hideButton

------------------------------------------------
-- SHOW/HIDE
------------------------------------------------

local hidden = false

local function toggleMenu()

    hidden = not hidden

    main.Visible = not hidden
end

hideButton.MouseButton1Click:Connect(toggleMenu)

UserInputService.InputBegan:Connect(function(input, gameProcessed)

    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        toggleMenu()
    end
end)

------------------------------------------------
-- DRAGGABLE MENU
------------------------------------------------

local dragging = false
local dragStart
local startPosition

title.InputBegan:Connect(function(input)

    if input.UserInputType == Enum.UserInputType.MouseButton1 then

        dragging = true
        dragStart = input.Position
        startPosition = main.Position

        input.Changed:Connect(function()

            if input.UserInputState ==
                Enum.UserInputState.End then

                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)

    if dragging
        and input.UserInputType ==
        Enum.UserInputType.MouseMovement then

        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)
