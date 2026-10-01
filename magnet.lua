– MAGNET SCRIPT
– written by sennsi
– front dash cancel by lanzintherandom
– magnet by sxlitude1

-- Optimized: TP 2 Studs Above + Magnet Pull (E) + Dash Cancel (Q) + Mobile UI
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local rootPart = character:WaitForChild("HumanoidRootPart")

local pullConnection = nil
local dashVelocity = nil
local npcList = {}
local lastNpcUpdate = 0

------------------------------------------------
-- SETUP CHARACTER + DASH DETECTION
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

if player.Character then setupCharacter(player.Character) end
player.CharacterAdded:Connect(setupCharacter)

------------------------------------------------
-- NPC CACHE
------------------------------------------------
local function updateNpcCache()
    npcList = {}
    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and model:FindFirstChild("Humanoid") and model:FindFirstChild("HumanoidRootPart") then
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
    local closestRoot = nil
    local shortestDistance = math.huge
    local myPos = rootPart.Position

    -- Players
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local root = plr.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (myPos - root.Position).Magnitude
                if dist < shortestDistance and dist > 0.1 then
                    shortestDistance = dist
                    closestRoot = root
                end
            end
        end
    end

    -- NPCs
    for _, npcRoot in ipairs(npcList) do
        if npcRoot and npcRoot.Parent then
            local dist = (myPos - npcRoot.Position).Magnitude
            if dist < shortestDistance and dist > 0.1 then
                shortestDistance = dist
                closestRoot = npcRoot
            end
        end
    end

    return closestRoot
end

------------------------------------------------
-- MAGNET PULL
------------------------------------------------
local function startMagnetPull()
    if pullConnection then pullConnection:Disconnect() end
    
    local startTime = tick()
    local pullDuration = 0.5
    local pullStrength = 50
    local smoothness = 0.65

    pullConnection = RunService.Heartbeat:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= pullDuration then
            pullConnection:Disconnect()
            pullConnection = nil
            return
        end

        local targetRoot = getClosestTarget()
        if not targetRoot then return end

        local currentPos = rootPart.Position
        local targetHorizontal = Vector3.new(targetRoot.Position.X, currentPos.Y, targetRoot.Position.Z)
        
        local direction = (targetHorizontal - currentPos)
        local distance = direction.Magnitude

        if distance > 1 then
            direction = direction.Unit
            local desiredVel = direction * pullStrength
            local currentVel = rootPart.AssemblyLinearVelocity
            local newVel = currentVel:Lerp(desiredVel, smoothness)

            rootPart.AssemblyLinearVelocity = Vector3.new(
                newVel.X * 0.85,
                currentVel.Y,
                newVel.Z * 0.85
            )
        end
    end)
end

------------------------------------------------
-- CORE ACTION LOGIC (MERGED)
------------------------------------------------
local function executeCombinedActions()
    -- Action E: Teleport 2 studs above + Pull
    local targetRoot = getClosestTarget()
    if targetRoot then
        local targetPos = targetRoot.Position + Vector3.new(0, 2, 0)
        rootPart.CFrame = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
        startMagnetPull()
    end
    
    -- Action Q: Dash Cancel
    if dashVelocity and dashVelocity.Parent then
        dashVelocity:Destroy()
        dashVelocity = nil
    end
    
    if rootPart then
        local vel = rootPart.AssemblyLinearVelocity
        rootPart.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
    end
end

------------------------------------------------
-- INPUT HANDLING (PC / KEYBOARD)
------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- If E or Q is pressed on keyboard, trigger both actions together
    if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Q then
        executeCombinedActions()
    end
end)

------------------------------------------------
-- MOBILE UI CREATION
------------------------------------------------
if UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
    -- We can check if it's mobile or just provide the button if desired. 
    -- To ensure it shows up reliably on mobile devices:
    
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Remove existing GUI if re-running
    if playerGui:FindFirstChild("CombinedActionGui") then
        playerGui.CombinedActionGui:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CombinedActionGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui

    local actionButton = Instance.new("TextButton")
    actionButton.Name = "ActionButton"
    actionButton.Size = UDim2.new(0, 70, 0, 70)
    actionButton.Position = UDim2.new(0.85, -35, 0.6, -35) -- Clean position on the right side
    actionButton.AnchorPoint = Vector2.new(0.5, 0.5)
    actionButton.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    actionButton.Text = "TP/Q"
    actionButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    actionButton.TextSize = 18
    actionButton.Font = Enum.Font.GothamBold
    actionButton.Parent = screenGui

    -- Styling for a clean, modern look
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0) -- Perfect circle
    uiCorner.Parent = actionButton

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = Color3.fromRGB(255, 255, 255)
    uiStroke.Transparency = 0.5
    uiStroke.Thickness = 2
    uiStroke.Parent = actionButton

    -- Smooth touch animation & action trigger
    actionButton.MouseButton1Click:Connect(function()
        executeCombinedActions()
        
        -- Smooth visual feedback (scale down and back up)
        local tweenService = game:GetService("TweenService")
        local info = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        
        local shrink = tweenService:Create(actionButton, info, {Size = UDim2.new(0, 60, 0, 60)})
        local grow = tweenService:Create(actionButton, info, {Size = UDim2.new(0, 70, 0, 70)})
        
        shrink:Play()
        shrink.Completed:Connect(function()
            grow:Play()
        end)
    end)
end
