local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

------------------------------------------------
-- CONFIGURATION
------------------------------------------------

local Config = {
    Enabled = true,

    Magnet = false,
    Teleport = true,
    DashCancel = true,

    MagnetStrength = 50,
    MagnetSmoothness = 0.65,
    TeleportHeight = 2,

    MagnetKey = Enum.KeyCode.E,
    TeleportKey = Enum.KeyCode.T,
    DashCancelKey = Enum.KeyCode.Q,

    MenuKey = Enum.KeyCode.RightShift
}

------------------------------------------------
-- CHARACTER
------------------------------------------------

local character
local rootPart
local dashVelocity

local function setupCharacter(newCharacter)
    character = newCharacter
    rootPart = newCharacter:WaitForChild("HumanoidRootPart")
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

local npcList = {}
local lastNpcUpdate = 0

local function updateNpcCache()
    table.clear(npcList)

    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") then
            local humanoid = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart")

            if humanoid and root and root ~= rootPart then
                table.insert(npcList, {
                    Root = root,
                    Humanoid = humanoid
                })
            end
        end
    end
end

RunService.Heartbeat:Connect(function()
    local now = os.clock()

    if now - lastNpcUpdate >= 1 then
        lastNpcUpdate = now
        updateNpcCache()
    end
end)

------------------------------------------------
-- CLOSEST TARGET
------------------------------------------------

local function getClosestTarget()
    if not rootPart then
        return nil
    end

    local closestRoot = nil
    local closestDistance = math.huge
    local myPosition = rootPart.Position

    -- Players
    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            local targetCharacter = targetPlayer.Character

            if targetCharacter then
                local humanoid =
                    targetCharacter:FindFirstChildOfClass("Humanoid")

                local targetRoot =
                    targetCharacter:FindFirstChild("HumanoidRootPart")

                if humanoid
                    and humanoid.Health > 0
                    and targetRoot then

                    local distance =
                        (myPosition - targetRoot.Position).Magnitude

                    if distance > 0.1
                        and distance < closestDistance then

                        closestDistance = distance
                        closestRoot = targetRoot
                    end
                end
            end
        end
    end

    -- NPCs
    for _, npc in ipairs(npcList) do
        local targetRoot = npc.Root
        local humanoid = npc.Humanoid

        if targetRoot
            and targetRoot.Parent
            and humanoid
            and humanoid.Health > 0 then

            local distance =
                (myPosition - targetRoot.Position).Magnitude

            if distance > 0.1
                and distance < closestDistance then

                closestDistance = distance
                closestRoot = targetRoot
            end
        end
    end

    return closestRoot
end

------------------------------------------------
-- MAGNET
------------------------------------------------

local magnetConnection

local function stopMagnet()
    if magnetConnection then
        magnetConnection:Disconnect()
        magnetConnection = nil
    end
end

local function startMagnet()
    stopMagnet()

    magnetConnection = RunService.Heartbeat:Connect(function()
        if not Config.Enabled or not Config.Magnet then
            return
        end

        if not rootPart or not rootPart.Parent then
            return
        end

        local targetRoot = getClosestTarget()

        if not targetRoot then
            return
        end

        local currentPosition = rootPart.Position

        local targetHorizontal = Vector3.new(
            targetRoot.Position.X,
            currentPosition.Y,
            targetRoot.Position.Z
        )

        local direction =
            targetHorizontal - currentPosition

        local distance = direction.Magnitude

        if distance <= 1 then
            return
        end

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
            newVelocity.X,
            currentVelocity.Y,
            newVelocity.Z
        )
    end)
end

------------------------------------------------
-- MAGNET TOGGLE
------------------------------------------------

local function toggleMagnet()
    if not Config.Enabled then
        return
    end

    Config.Magnet = not Config.Magnet

    if Config.Magnet then
        startMagnet()
    else
        stopMagnet()
    end
end

------------------------------------------------
-- TELEPORT
------------------------------------------------

local function teleportToClosest()
    if not Config.Enabled or not Config.Teleport then
        return
    end

    if not rootPart then
        return
    end

    local targetRoot = getClosestTarget()

    if not targetRoot then
        return
    end

    local targetPosition =
        targetRoot.Position +
        Vector3.new(0, Config.TeleportHeight, 0)

    rootPart.CFrame = CFrame.new(targetPosition)
end

------------------------------------------------
-- DASH CANCEL
------------------------------------------------

local function cancelDash()
    if not Config.Enabled or not Config.DashCancel then
        return
    end

    if not rootPart then
        return
    end

    if dashVelocity and dashVelocity.Parent then
        dashVelocity:Destroy()
        dashVelocity = nil
    end

    local velocity =
        rootPart.AssemblyLinearVelocity

    rootPart.AssemblyLinearVelocity = Vector3.new(
        0,
        velocity.Y,
        0
    )
end

------------------------------------------------
-- GUI
------------------------------------------------

local playerGui = player:WaitForChild("PlayerGui")

local oldGui = playerGui:FindFirstChild("MagnetConfig")

if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "MagnetConfig"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

------------------------------------------------
-- MAIN WINDOW
------------------------------------------------

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(285, 330)
main.Position = UDim2.new(0.5, -142, 0.5, -165)
main.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

------------------------------------------------
-- TITLE
------------------------------------------------

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.fromOffset(10, 5)
title.BackgroundTransparency = 1
title.Text = "MAGNET"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 20
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

------------------------------------------------
-- GLOBAL TOGGLE
------------------------------------------------

local globalButton = Instance.new("TextButton")
globalButton.Size = UDim2.new(1, -20, 0, 38)
globalButton.Position = UDim2.fromOffset(10, 50)
globalButton.Font = Enum.Font.GothamBold
globalButton.TextSize = 14
globalButton.TextColor3 = Color3.new(1, 1, 1)
globalButton.Parent = main

local function updateGlobalButton()
    globalButton.Text =
        "MASTER: " .. (Config.Enabled and "ON" or "OFF")

    globalButton.BackgroundColor3 =
        Config.Enabled
        and Color3.fromRGB(40, 115, 65)
        or Color3.fromRGB(75, 45, 45)
end

local globalCorner = Instance.new("UICorner")
globalCorner.CornerRadius = UDim.new(0, 7)
globalCorner.Parent = globalButton

globalButton.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled

    if not Config.Enabled then
        stopMagnet()
    elseif Config.Magnet then
        startMagnet()
    end

    updateGlobalButton()
end)

updateGlobalButton()

------------------------------------------------
-- TOGGLE BUTTON CREATOR
------------------------------------------------

local function createToggle(name, y, getter, setter)
    local button = Instance.new("TextButton")

    button.Size = UDim2.new(1, -20, 0, 36)
    button.Position = UDim2.fromOffset(10, y)
    button.Font = Enum.Font.Gotham
    button.TextSize = 14
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Parent = main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 7)
    corner.Parent = button

    local function refresh()
        local state = getter()

        button.Text =
            name .. ": " .. (state and "ON" or "OFF")

        button.BackgroundColor3 =
            state
            and Color3.fromRGB(40, 100, 60)
            or Color3.fromRGB(55, 55, 62)
    end

    button.MouseButton1Click:Connect(function()
        setter(not getter())
        refresh()
    end)

    refresh()

    return refresh
end

------------------------------------------------
-- TOGGLES
------------------------------------------------

createToggle(
    "MAGNET",
    98,
    function()
        return Config.Magnet
    end,
    function(value)
        Config.Magnet = value

        if value and Config.Enabled then
            startMagnet()
        else
            stopMagnet()
        end
    end
)

createToggle(
    "TELEPORT",
    140,
    function()
        return Config.Teleport
    end,
    function(value)
        Config.Teleport = value
    end
)

createToggle(
    "DASH CANCEL",
    182,
    function()
        return Config.DashCancel
    end,
    function(value)
        Config.DashCancel = value
    end
)

------------------------------------------------
-- KEY INFO
------------------------------------------------

local keyInfo = Instance.new("TextLabel")
keyInfo.Size = UDim2.new(1, -20, 0, 55)
keyInfo.Position = UDim2.fromOffset(10, 224)
keyInfo.BackgroundTransparency = 1
keyInfo.TextColor3 = Color3.fromRGB(190, 190, 195)
keyInfo.TextSize = 12
keyInfo.Font = Enum.Font.Gotham
keyInfo.TextXAlignment = Enum.TextXAlignment.Left
keyInfo.TextYAlignment = Enum.TextYAlignment.Top
keyInfo.Text =
    "MAGNET: E\n" ..
    "TELEPORT: T\n" ..
    "DASH CANCEL: Q"
keyInfo.Parent = main

------------------------------------------------
-- HIDE BUTTON
------------------------------------------------

local hideButton = Instance.new("TextButton")
hideButton.Size = UDim2.new(1, -20, 0, 30)
hideButton.Position = UDim2.fromOffset(10, 292)
hideButton.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
hideButton.Text = "HIDE MENU  [RightShift]"
hideButton.TextColor3 = Color3.new(1, 1, 1)
hideButton.TextSize = 12
hideButton.Font = Enum.Font.GothamBold
hideButton.Parent = main

local hideCorner = Instance.new("UICorner")
hideCorner.CornerRadius = UDim.new(0, 7)
hideCorner.Parent = hideButton

------------------------------------------------
-- MENU VISIBILITY
------------------------------------------------

local menuVisible = true

local function toggleMenu()
    menuVisible = not menuVisible
    main.Visible = menuVisible
end

hideButton.MouseButton1Click:Connect(toggleMenu)

------------------------------------------------
-- INPUT
------------------------------------------------

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Config.MenuKey then
        toggleMenu()
        return
    end

    if input.KeyCode == Config.MagnetKey then
        toggleMagnet()
        return
    end

    if input.KeyCode == Config.TeleportKey then
        teleportToClosest()
        return
    end

    if input.KeyCode == Config.DashCancelKey then
        cancelDash()
        return
    end
end)

------------------------------------------------
-- DRAG MENU
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
    if dragging and
        input.UserInputType ==
        Enum.UserInputType.MouseMovement then

        local delta =
            input.Position - dragStart

        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

------------------------------------------------
-- INITIAL NPC CACHE
------------------------------------------------

updateNpcCache()
