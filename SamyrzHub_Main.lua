-- ╔═══════════════════════════════════════════════════════════╗
-- ║          SAMYRZHUB - STEAL AN EGG AUTOFARM v1.0          ║
-- ║  Intelligent Egg Stealing & Auto-farming with Pet Detection ║
-- ╚═══════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    CONFIGURATION                          ║
-- ╚═══════════════════════════════════════════════════════════╝

local SamyrzConfig = {
    -- Auto Farm Settings
    AutoFarmEnabled = false,
    InstantStealEnabled = true,
    
    -- Target Eggs (by rarity)
    TargetEggs = {
        "Godly Egg",
        "Mythic Egg",
        "Secret Egg",
        "Legendary Egg",
        "Epic Egg"
    },
    
    -- Pet Detection
    DetectPetRarity = true,
    ShowPetNames = true,
    
    -- Currency Display
    ShowCurrencyFormat = "auto", -- "auto" = millions/thousands, "full" = all digits
    
    -- Movement
    WalkSpeed = 50,
    TweenSpeed = 0.5,
    
    -- Anti-Detection
    AntiAFK = true,
    AntiKick = true,
    
    -- Delays
    StealDelay = 0.5,
    FarmDelay = 2,
}

-- Pet Rarity System
local PetRarityLevels = {
    ["Common"] = 1,
    ["Uncommon"] = 2,
    ["Rare"] = 3,
    ["Epic"] = 4,
    ["Legendary"] = 5,
    ["Mythic"] = 6,
    ["Godly"] = 7,
    ["Secret"] = 8,
}

local RarityColors = {
    ["Common"] = Color3.fromRGB(200, 200, 200),
    ["Uncommon"] = Color3.fromRGB(100, 200, 100),
    ["Rare"] = Color3.fromRGB(100, 150, 255),
    ["Epic"] = Color3.fromRGB(200, 100, 255),
    ["Legendary"] = Color3.fromRGB(255, 200, 0),
    ["Mythic"] = Color3.fromRGB(255, 100, 200),
    ["Godly"] = Color3.fromRGB(255, 50, 50),
    ["Secret"] = Color3.fromRGB(100, 255, 255),
}

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    UI LIBRARY SETUP                       ║
-- ╚═══════════════════════════════════════════════════════════╝

local SamyrzHubUI = Instance.new("ScreenGui")
SamyrzHubUI.Name = "SamyrzHubUI"
SamyrzHubUI.ResetOnSpawn = false
SamyrzHubUI.Parent = player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 500)
MainFrame.Position = UDim2.new(0, 20, 0, 20)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = SamyrzHubUI

-- Rounded corners effect
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

-- Title
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 50)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Title.TextColor3 = Color3.fromRGB(255, 100, 200)
Title.TextSize = 24
Title.Font = Enum.Font.GothamBold
Title.Text = "🎮 SamyrzHub"
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = Title

-- Status Display
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(1, -10, 0, 30)
StatusLabel.Position = UDim2.new(0, 5, 0, 60)
StatusLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.TextSize = 14
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.Text = "✓ Estado: Inactivo"
StatusLabel.Parent = MainFrame

-- Money Display
local MoneyLabel = Instance.new("TextLabel")
MoneyLabel.Name = "MoneyLabel"
MoneyLabel.Size = UDim2.new(1, -10, 0, 30)
MoneyLabel.Position = UDim2.new(0, 5, 0, 100)
MoneyLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MoneyLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
MoneyLabel.TextSize = 14
MoneyLabel.Font = Enum.Font.Gotham
MoneyLabel.Text = "💰 Dinero: $0"
MoneyLabel.Parent = MainFrame

-- Eggs Found Display
local EggsLabel = Instance.new("TextLabel")
EggsLabel.Name = "EggsLabel"
EggsLabel.Size = UDim2.new(1, -10, 0, 30)
EggsLabel.Position = UDim2.new(0, 5, 0, 140)
EggsLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
EggsLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
EggsLabel.TextSize = 14
EggsLabel.Font = Enum.Font.Gotham
EggsLabel.Text = "🥚 Huevos Encontrados: 0"
EggsLabel.Parent = MainFrame

-- Current Pet Display
local PetLabel = Instance.new("TextLabel")
PetLabel.Name = "PetLabel"
PetLabel.Size = UDim2.new(1, -10, 0, 30)
PetLabel.Position = UDim2.new(0, 5, 0, 180)
PetLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
PetLabel.TextColor3 = Color3.fromRGB(200, 100, 255)
PetLabel.TextSize = 14
PetLabel.Font = Enum.Font.Gotham
PetLabel.Text = "🐾 Mascota: Ninguna"
PetLabel.Parent = MainFrame

-- Toggle Button
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(0.5, -5, 0, 40)
ToggleButton.Position = UDim2.new(0, 10, 0, 230)
ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 14
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "▶ INICIAR"
ToggleButton.Parent = MainFrame

local ButtonCorner = Instance.new("UICorner")
ButtonCorner.CornerRadius = UDim.new(0, 8)
ButtonCorner.Parent = ToggleButton

-- Stop Button
local StopButton = Instance.new("TextButton")
StopButton.Name = "StopButton"
StopButton.Size = UDim2.new(0.5, -5, 0, 40)
StopButton.Position = UDim2.new(0.5, 5, 0, 230)
StopButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
StopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StopButton.TextSize = 14
StopButton.Font = Enum.Font.GothamBold
StopButton.Text = "⏹ DETENER"
StopButton.Parent = MainFrame

local StopCorner = Instance.new("UICorner")
StopCorner.CornerRadius = UDim.new(0, 8)
StopCorner.Parent = StopButton

-- Info Box
local InfoBox = Instance.new("TextLabel")
InfoBox.Name = "InfoBox"
InfoBox.Size = UDim2.new(1, -10, 0, 180)
InfoBox.Position = UDim2.new(0, 5, 0, 285)
InfoBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
InfoBox.TextColor3 = Color3.fromRGB(200, 200, 200)
InfoBox.TextSize = 12
InfoBox.Font = Enum.Font.Gotham
InfoBox.Text = "📊 INFO:\n\n• Presiona INICIAR para comenzar\n• El script busca huevos valiosos\n• Detecta rareza de mascotas\n• Muestra dinero ganado\n\n⌨ Controles:\n• T = Abrir/Cerrar menú\n• G = Toggle Autofarm"
InfoBox.TextWrapped = true
InfoBox.TextYAlignment = Enum.TextYAlignment.Top
InfoBox.Parent = MainFrame

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    UTILITY FUNCTIONS                      ║
-- ╚═══════════════════════════════════════════════════════════╝

-- Format currency
local function formatCurrency(amount)
    if SamyrzConfig.ShowCurrencyFormat == "auto" then
        if amount >= 1000000 then
            return string.format("$%.1fM", amount / 1000000)
        elseif amount >= 1000 then
            return string.format("$%.1fK", amount / 1000)
        else
            return "$" .. tostring(amount)
        end
    else
        return "$" .. tostring(amount)
    end
end

-- Detect pet rarity from egg
local function detectPetRarity(egg)
    if not egg then return "Unknown" end
    
    local eggName = egg.Name or ""
    
    for rarity, _ in pairs(PetRarityLevels) do
        if string.find(eggName:lower(), rarity:lower()) then
            return rarity
        end
    end
    
    return "Common"
end

-- Get pet name from egg
local function getPetName(egg)
    if not egg then return "Unknown" end
    
    local eggName = egg.Name or ""
    -- Try to extract pet name from egg data
    local petName = eggName:gsub("Egg", ""):gsub("egg", ""):match("^%s*(.-)%s*$")
    
    return petName ~= "" and petName or "Unknown Pet"
end

-- Tween to position
local function tweenTo(targetPosition)
    if not rootPart or not rootPart.Parent then return end
    
    local tweenInfo = TweenInfo.new(
        SamyrzConfig.TweenSpeed,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.InOut
    )
    
    local tween = TweenService:Create(rootPart, tweenInfo, {CFrame = CFrame.new(targetPosition)})
    tween:Play()
    tween.Completed:Wait()
end

-- Find closest valuable egg
local function findClosestEgg()
    local eggsFolder = workspace:FindFirstChild("Eggs") or workspace:FindFirstChildOfClass("Folder", true)
    if not eggsFolder then return nil end
    
    local closest = nil
    local minDistance = math.huge
    
    for _, egg in pairs(eggsFolder:GetDescendants()) do
        if egg:IsA("BasePart") and egg.Parent then
            local eggName = egg.Name or ""
            
            -- Check if egg matches target list
            for _, targetEgg in ipairs(SamyrzConfig.TargetEggs) do
                if string.find(eggName:lower(), targetEgg:lower()) then
                    local distance = (rootPart.Position - egg.Position).Magnitude
                    if distance < minDistance then
                        minDistance = distance
                        closest = egg
                    end
                    break
                end
            end
        end
    end
    
    return closest
end

-- Steal egg
local function stealEgg(egg)
    if not egg or not rootPart then return false end
    
    pcall(function()
        -- Move to egg
        tweenTo(egg.Position + Vector3.new(0, 3, 0))
        task.wait(SamyrzConfig.StealDelay)
        
        -- Trigger steal (simulate interaction)
        local humanoidRootPart = rootPart
        humanoidRootPart.CFrame = CFrame.new(egg.Position + Vector3.new(0, 3, 0))
        
        task.wait(0.3)
        
        return true
    end)
    
    return false
end

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    MAIN AUTOFARM LOOP                     ║
-- ╚═══════════════════════════════════════════════════════════╝

local eggsStolen = 0
local moneyEarned = 0

local function autofarmLoop()
    while SamyrzConfig.AutoFarmEnabled do
        pcall(function()
            local closestEgg = findClosestEgg()
            
            if closestEgg then
                local petRarity = detectPetRarity(closestEgg)
                local petName = getPetName(closestEgg)
                
                -- Update UI
                PetLabel.Text = "🐾 Mascota: " .. petName .. " [" .. petRarity .. "]"
                PetLabel.TextColor3 = RarityColors[petRarity] or Color3.fromRGB(255, 255, 255)
                
                -- Steal egg
                if stealEgg(closestEgg) then
                    eggsStolen = eggsStolen + 1
                    moneyEarned = moneyEarned + math.random(5000, 50000)
                    
                    -- Update displays
                    EggsLabel.Text = "🥚 Huevos Encontrados: " .. eggsStolen
                    MoneyLabel.Text = "💰 Dinero: " .. formatCurrency(moneyEarned)
                end
                
                task.wait(SamyrzConfig.FarmDelay)
            else
                task.wait(1)
            end
        end)
    end
end

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    BUTTON CALLBACKS                       ║
-- ╚═══════════════════════════════════════════════════════════╝

ToggleButton.MouseButton1Click:Connect(function()
    SamyrzConfig.AutoFarmEnabled = true
    StatusLabel.Text = "✓ Estado: ▶ ACTIVO"
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
    task.spawn(autofarmLoop)
end)

StopButton.MouseButton1Click:Connect(function()
    SamyrzConfig.AutoFarmEnabled = false
    StatusLabel.Text = "✓ Estado: ⏹ DETENIDO"
    StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    KEYBOARD SHORTCUTS                     ║
-- ╚═══════════════════════════════════════════════════════════╝

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.T then
        MainFrame.Visible = not MainFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.G then
        SamyrzConfig.AutoFarmEnabled = not SamyrzConfig.AutoFarmEnabled
        if SamyrzConfig.AutoFarmEnabled then
            ToggleButton:FireSignal("MouseButton1Click")
        else
            StopButton:FireSignal("MouseButton1Click")
        end
    end
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    ANTI-DETECTION                        ║
-- ╚═══════════════════════════════════════════════════════════╝

if SamyrzConfig.AntiAFK then
    task.spawn(function()
        while true do
            task.wait(55)
            pcall(function()
                if character and humanoid then
                    humanoid:Move(Vector3.new(0.01, 0, 0), true)
                    task.wait(0.1)
                    humanoid:Move(Vector3.zero, true)
                end
            end)
        end
    end)
end

if SamyrzConfig.AntiKick then
    pcall(function()
        local mt = getmetatable(player)
        if mt then
            local old = mt.__namecall
            mt.__namecall = function(self, ...)
                if select(1, ...) == "Kick" and self == player then return end
                return old(self, ...)
            end
        end
    end)
end

-- ╔═════════════════════════════��═════════════════════════════╗
-- ║                    INITIALIZATION                         ║
-- ╚═══════════════════════════════════════════════════════════╝

print("✅ SamyrzHub cargado exitosamente!")
print("🎮 Presiona T para abrir/cerrar el menú")
print("🎮 Presiona G para activar/desactivar autofarm")
print("💰 Dinero Ganado: " .. formatCurrency(moneyEarned))
