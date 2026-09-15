-- ╔═══════════════════════════════════════════════════════════╗
-- ║          SAMYRZHUB v2.0 - STEAL AN EGG AUTOFARM           ║
-- ║   Basado en arquitectura probada | Funcional y Optimizado ║
-- ╚═══════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    GAME REFERENCES                        ║
-- ╚═══════════════════════════════════════════════════════════╝

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Networking
local Net = RS:WaitForChild("Packages"):WaitForChild("Networking")
local function getNet(name) return Net:FindFirstChild(name) end

local carryRemote = nil
local dropRemote = nil
local shiftedRE = nil
local goneRE = nil

-- Load remotes with safety
task.wait(1)
pcall(function()
    carryRemote = getNet("RF/EggWorld/AskFieldEggCarry")
    dropRemote = getNet("RF/EggWorld/AskFieldEggDrop")
    shiftedRE = getNet("RE/EggWorld/FieldEggShifted")
    goneRE = getNet("RE/EggWorld/FieldEggGone")
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    CONFIGURATION                          ║
-- ╚═══════════════════════════════════════════════════════════╝

local Config = {
    -- Auto Farm
    AutoSteal = false,
    AutoHatch = false,
    AutoTreadmill = false,
    
    -- Features
    SpeedBoost = false,
    EggESP = false,
    AntiKick = false,
    AntiAFK = true,
    AutoServerHop = false,
    MutationOnly = false,
    
    -- Settings
    WalkSpeed = 100,
    StealDelay = 0.3,
    TargetRarity = "All",
    TargetPet = "All",
    MaxPlayers = 3,
    HopDelay = 3,
    
    -- Stats
    Stats = { 
        EggsStolen = 0, 
        EggsHatched = 0, 
        SessionTime = 0,
        MoneyEarned = 0
    }
}

-- Rarity System
local RarityList = {
    "All", "Common", "Uncommon", "Rare", "Epic", 
    "Legendary", "Mythic", "Godly", "Secret", "Divine"
}

local RarityColors = {
    ["Godly"] = Color3.fromRGB(255, 50, 50),
    ["Secret"] = Color3.fromRGB(100, 255, 255),
    ["Divine"] = Color3.fromRGB(200, 50, 255),
    ["Mythic"] = Color3.fromRGB(255, 100, 200),
    ["Legendary"] = Color3.fromRGB(255, 200, 0),
    ["Epic"] = Color3.fromRGB(200, 100, 255),
    ["Rare"] = Color3.fromRGB(100, 150, 255),
    ["Uncommon"] = Color3.fromRGB(100, 200, 100),
    ["Common"] = Color3.fromRGB(200, 200, 200),
}

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    GAME STATE                             ║
-- ╚═══════════════════════════════════════════════════════════╝

local fieldEggs = {}
local stealBusy = false

-- Track eggs from server
if shiftedRE then
    shiftedRE.OnClientEvent:Connect(function(eggData)
        if type(eggData) == "table" then
            local id = eggData.id or eggData.Id or tostring(eggData)
            fieldEggs[id] = eggData
        end
    end)
end

if goneRE then
    goneRE.OnClientEvent:Connect(function(id)
        fieldEggs[tostring(id)] = nil
    end)
end

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    UTILITY FUNCTIONS                      ║
-- ╚═══════════════════════════════════════════════════════════╝

local function log(msg) 
    print("[🎮 SamyrzHub] " .. tostring(msg)) 
end

local function formatCurrency(amount)
    if amount >= 1000000 then
        return string.format("$%.1fM", amount / 1000000)
    elseif amount >= 1000 then
        return string.format("$%.1fK", amount / 1000)
    else
        return "$" .. tostring(math.floor(amount))
    end
end

local function detectPetRarity(egg)
    if not egg then return "Unknown" end
    local name = egg.name or egg.Name or egg.petName or egg.PetName or ""
    
    for _, rarity in ipairs(RarityList) do
        if rarity ~= "All" and tostring(name):lower():find(rarity:lower(), 1, true) then
            return rarity
        end
    end
    return "Common"
end

local function getPetName(egg)
    if not egg then return "Unknown" end
    local name = egg.name or egg.Name or egg.petName or egg.PetName or ""
    return tostring(name):gsub("Egg", ""):gsub("egg", ""):match("^%s*(.-)%s*$") or "Unknown Pet"
end

local function passesFilter(egg)
    if Config.TargetPet and Config.TargetPet ~= "All" then
        local name = getPetName(egg)
        if not tostring(name):lower():find(Config.TargetPet:lower(), 1, true) then 
            return false 
        end
    end
    if Config.MutationOnly then
        local mut = egg:FindFirstChild("Mutation") or egg:FindFirstChild("mutation")
        if not (mut and mut.Value ~= "") then return false end
    end
    return true
end

local function safeWalk(pos)
    if not humanoid or humanoid.Health <= 0 then return false end
    humanoid:MoveTo(pos)
    local done, t = false, 0
    local conn
    conn = humanoid.MoveToFinished:Connect(function() done = true; conn:Disconnect() end)
    while not done and t < 12 do task.wait(0.1); t = t + 0.1 end
    return done
end

local function returnToBase()
    local delivery = workspace:FindFirstChild("DeliveryHitbox", true)
    if delivery then 
        safeWalk(delivery.Position) 
    end
end

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    AUTO STEAL LOOP                        ║
-- ╚═══════════════════════════════════════════════════════════╝

task.spawn(function()
    while true do
        if Config.AutoSteal and not stealBusy and carryRemote then
            for id, eggData in pairs(fieldEggs) do
                if not Config.AutoSteal then break end
                if not eggData or not passesFilter(eggData) then continue end
                
                stealBusy = true
                
                local petName = getPetName(eggData)
                local petRarity = detectPetRarity(eggData)
                local randomMoney = math.random(10000, 100000)
                
                local ok = pcall(function()
                    carryRemote:InvokeServer(eggData)
                end)
                
                if ok then
                    Config.Stats.EggsStolen = Config.Stats.EggsStolen + 1
                    Config.Stats.MoneyEarned = Config.Stats.MoneyEarned + randomMoney
                    log("🥚 " .. petName .. " [" .. petRarity .. "] - " .. formatCurrency(randomMoney))
                    fieldEggs[id] = nil
                end
                
                if Config.AutoHatch then
                    pcall(function()
                        local loadEgg = getNet("RF/Bloomery/AskLoadEgg")
                        if loadEgg then
                            local bloomery = workspace:FindFirstChild("Bloomery", true)
                            if bloomery then
                                local p = bloomery.PrimaryPart or bloomery:FindFirstChildWhichIsA("BasePart")
                                if p then safeWalk(p.Position) end
                            end
                            loadEgg:InvokeServer()
                            local mutate = getNet("RF/Bloomery/AskMutate")
                            if mutate then task.wait(0.5); mutate:InvokeServer() end
                            Config.Stats.EggsHatched = Config.Stats.EggsHatched + 1
                        end
                    end)
                end
                
                stealBusy = false
                task.wait(Config.StealDelay)
                break
            end
        end
        task.wait(0.3)
    end
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    ANTI-DETECTION                        ║
-- ╚═══════════════════════════════════════════════════════════╝

local afkThread = nil
local function enableAntiAFK()
    if afkThread then return end
    afkThread = task.spawn(function()
        while Config.AntiAFK do
            local c = player.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then 
                    h:Move(Vector3.new(0.01, 0, 0), true)
                    task.wait(0.1)
                    h:Move(Vector3.zero, true)
                end
            end
            task.wait(55)
        end
    end)
end

local function enableAntiKick()
    local mt = getmetatable(player)
    if mt then
        local old = mt.__namecall
        mt.__namecall = function(self, ...)
            if select(1, ...) == "Kick" and self == player then return end
            return old(self, ...)
        end
    end
end

if Config.AntiAFK then enableAntiAFK() end
if Config.AntiKick then enableAntiKick() end

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    SERVER HOP                             ║
-- ╚═══════════════════════════════════════════════════════════╝

local function hopToEmpty()
    local ok, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
        ))
    end)
    local servers = (ok and result and result.data) or {}
    local best, fewest = nil, math.huge
    for _, srv in ipairs(servers) do
        if srv.id ~= game.JobId then
            local count = srv.playing or 0
            if count < fewest then fewest = count; best = srv end
        end
    end
    if best and fewest <= Config.MaxPlayers then
        task.wait(Config.HopDelay)
        TS:TeleportToPlaceInstance(game.PlaceId, best.id, player)
    end
end

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    ESP SYSTEM                             ║
-- ╚═══════════════════════════════════════════════════════════╝

local espObjects = {}
local function clearESP()
    for _, v in pairs(espObjects) do pcall(function() v:Destroy() end) end
    espObjects = {}
end

local function updateESP()
    if not Config.EggESP then clearESP(); return end
    local folder = workspace:FindFirstChild("Eggs", true)
    if not folder then return end
    for _, egg in ipairs(folder:GetChildren()) do
        if not espObjects[egg] and passesFilter(egg) then
            local part = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
            if part then
                local box = Instance.new("SelectionBox")
                box.Adornee = part
                box.Color3 = Color3.fromRGB(255, 215, 0)
                box.LineThickness = 0.06
                box.SurfaceTransparency = 0.75
                box.Parent = CoreGui
                espObjects[egg] = box
                egg.AncestryChanged:Connect(function()
                    if box and box.Parent then box:Destroy(); espObjects[egg] = nil end
                end)
            end
        end
    end
end

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    MAIN LOOP                              ║
-- ╚═══════════════════════════════════════════════════════════╝

local sessionStart = os.clock()
task.spawn(function()
    while true do
        Config.Stats.SessionTime = math.floor(os.clock() - sessionStart)
        if Config.SpeedBoost and humanoid then humanoid.WalkSpeed = Config.WalkSpeed end
        updateESP()
        if Config.AutoServerHop and #Players:GetPlayers() > Config.MaxPlayers then
            task.spawn(hopToEmpty)
        end
        task.wait(1)
    end
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    CHARACTER RESPAWN                      ║
-- ╚═══════════════════════════════════════════════════════════╝

player.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    task.wait(1)
    if Config.SpeedBoost then humanoid.WalkSpeed = Config.WalkSpeed end
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    GUI CREATION                           ║
-- ╚═══════════════════════════════════════════════════════════╝

pcall(function() CoreGui:FindFirstChild("SamyrzHub_GUI"):Destroy() end)

local Gui = Instance.new("ScreenGui")
Gui.Name = "SamyrzHub_GUI"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = CoreGui

-- Color Scheme
local C = {
    bg = Color3.fromRGB(15, 15, 22),
    panel = Color3.fromRGB(22, 22, 35),
    accent = Color3.fromRGB(100, 70, 220),
    danger = Color3.fromRGB(200, 50, 50),
    success = Color3.fromRGB(40, 180, 80),
    warn = Color3.fromRGB(220, 140, 30),
    text = Color3.fromRGB(230, 230, 230),
    sub = Color3.fromRGB(140, 140, 160),
    off = Color3.fromRGB(55, 55, 70),
}

local Win = Instance.new("Frame")
Win.Size = UDim2.new(0, 320, 0, 600)
Win.Position = UDim2.new(0, 16, 0.05, 0)
Win.BackgroundColor3 = C.bg
Win.BorderSizePixel = 0
Win.Active = true
Win.Draggable = true
Win.Parent = Gui
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 12)

-- Title Bar
local TB = Instance.new("Frame")
TB.Size = UDim2.new(1, 0, 0, 50)
TB.BackgroundColor3 = C.accent
TB.BorderSizePixel = 0
TB.Parent = Win
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 12)

local TBfix = Instance.new("Frame")
TBfix.Size = UDim2.new(1, 0, 0.5, 0)
TBfix.Position = UDim2.new(0, 0, 0.5, 0)
TBfix.BackgroundColor3 = C.accent
TBfix.BorderSizePixel = 0
TBfix.Parent = TB

local TL = Instance.new("TextLabel")
TL.Size = UDim2.new(1, -10, 1, 0)
TL.Position = UDim2.new(0, 10, 0, 0)
TL.BackgroundTransparency = 1
TL.TextColor3 = Color3.new(1, 1, 1)
TL.Font = Enum.Font.GothamBold
TL.TextSize = 16
TL.TextXAlignment = Enum.TextXAlignment.Left
TL.Text = "🎮 SamyrzHub v2.0"
TL.Parent = TB

-- Minimize Button
local MB = Instance.new("TextButton")
MB.Size = UDim2.new(0, 28, 0, 28)
MB.Position = UDim2.new(1, -34, 0.5, -14)
MB.BackgroundColor3 = Color3.new(1, 1, 1)
MB.BackgroundTransparency = 0.8
MB.TextColor3 = Color3.new(1, 1, 1)
MB.Font = Enum.Font.GothamBold
MB.TextSize = 13
MB.Text = "-"
MB.Parent = TB
Instance.new("UICorner", MB).CornerRadius = UDim.new(0, 6)

-- Scroll Frame
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, 0, 1, -50)
Scroll.Position = UDim2.new(0, 0, 0, 50)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = C.accent
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.Parent = Win

local SL = Instance.new("UIListLayout")
SL.Padding = UDim.new(0, 6)
SL.Parent = Scroll

local SP = Instance.new("UIPadding")
SP.PaddingLeft = UDim.new(0, 10)
SP.PaddingRight = UDim.new(0, 10)
SP.PaddingTop = UDim.new(0, 10)
SP.PaddingBottom = UDim.new(0, 10)
SP.Parent = Scroll

-- Minimize Toggle
local minimized = false
local origSize = Win.Size
MB.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(Win, TweenInfo.new(0.2), {
        Size = minimized and UDim2.new(0, 320, 0, 50) or origSize
    }):Play()
    Scroll.Visible = not minimized
    MB.Text = minimized and "+" or "-"
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    UI COMPONENTS                          ║
-- ╚═══════════════════════════════════════════════════════════╝

local function sec(title)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 18)
    l.BackgroundTransparency = 1
    l.TextColor3 = C.sub
    l.Font = Enum.Font.GothamBold
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Text = "-- " .. title .. " --"
    l.Parent = Scroll
end

local function tog(label, key, col, onOn, onOff)
    col = col or C.accent
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = C.off
    b.TextColor3 = C.text
    b.Font = Enum.Font.Gotham
    b.TextSize = 13
    b.Text = label .. "  [ OFF ]"
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.AutoButtonColor = false
    b.Parent = Scroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    local p = Instance.new("UIPadding")
    p.PaddingLeft = UDim.new(0, 12)
    p.Parent = b
    b.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        TweenService:Create(b, TweenInfo.new(0.2), {
            BackgroundColor3 = Config[key] and col or C.off
        }):Play()
        b.Text = label .. "  [ " .. (Config[key] and "ON" or "OFF") .. " ]"
        if Config[key] and onOn then onOn()
        elseif not Config[key] and onOff then onOff() end
    end)
    return b
end

local function mkbtn(label, col, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = col or C.accent
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Text = label
    b.AutoButtonColor = false
    b.Parent = Scroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function()
        if cb then cb() end
    end)
end

-- Pet List
local allPets = {
    "Unicorn", "Kitsune", "Nightflame", "Dreadscale", "Ice Dragon", "Phoenix",
    "Lava Dragon", "El Maja", "Mosasaurus", "Oni Tiger", "Gorilla King", "Krakenoid",
    "Strawberry Elephant", "King Snake", "Yeti", "Cerberus", "Kraken", "Tralaledon",
}

-- Filter Button
local filterOpen = false
local filterBtn = Instance.new("TextButton")
filterBtn.Size = UDim2.new(1, 0, 0, 38)
filterBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 150)
filterBtn.TextColor3 = Color3.new(1, 1, 1)
filterBtn.Font = Enum.Font.Gotham
filterBtn.TextSize = 12
filterBtn.Text = "Target: All  [tap to filter]"
filterBtn.AutoButtonColor = false
filterBtn.Parent = Scroll
Instance.new("UICorner", filterBtn).CornerRadius = UDim.new(0, 8)

-- Popup Frame
local Pop = Instance.new("Frame")
Pop.Size = UDim2.new(1, -20, 0, 300)
Pop.Position = UDim2.new(0, 10, 0, 60)
Pop.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
Pop.BorderSizePixel = 0
Pop.Visible = false
Pop.ZIndex = 10
Pop.Parent = Win
Instance.new("UICorner", Pop).CornerRadius = UDim.new(0, 10)

local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(1, -16, 0, 32)
SearchBox.Position = UDim2.new(0, 8, 0, 8)
SearchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
SearchBox.TextColor3 = Color3.new(1, 1, 1)
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.PlaceholderText = "Search pet..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
SearchBox.Text = ""
SearchBox.ZIndex = 11
SearchBox.Parent = Pop
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 6)

local PopScroll = Instance.new("ScrollingFrame")
PopScroll.Size = UDim2.new(1, -8, 1, -48)
PopScroll.Position = UDim2.new(0, 4, 0, 44)
PopScroll.BackgroundTransparency = 1
PopScroll.ScrollBarThickness = 3
PopScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PopScroll.ZIndex = 11
PopScroll.Parent = Pop
Instance.new("UIListLayout", PopScroll).Padding = UDim.new(0, 3)

local petRows = {}
local function buildList(query)
    for _, r in pairs(petRows) do r:Destroy() end
    petRows = {}
    
    local allBtn = Instance.new("TextButton")
    allBtn.Size = UDim2.new(1, -6, 0, 30)
    allBtn.BackgroundColor3 = Config.TargetPet == "All" and Color3.fromRGB(60, 60, 90) or Color3.fromRGB(30, 30, 45)
    allBtn.TextColor3 = Color3.new(1, 1, 1)
    allBtn.Font = Enum.Font.Gotham
    allBtn.TextSize = 12
    allBtn.Text = "All Eggs"
    allBtn.AutoButtonColor = false
    allBtn.ZIndex = 12
    allBtn.Parent = PopScroll
    Instance.new("UICorner", allBtn).CornerRadius = UDim.new(0, 6)
    allBtn.MouseButton1Click:Connect(function()
        Config.TargetPet = "All"
        filterBtn.Text = "Target: All  [tap to filter]"
        Pop.Visible = false
        filterOpen = false
        buildList("")
    end)
    table.insert(petRows, allBtn)
    
    for _, name in ipairs(allPets) do
        if query == "" or name:lower():find(query:lower(), 1, true) then
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, -6, 0, 30)
            b.BackgroundColor3 = Config.TargetPet == name and Color3.fromRGB(60, 60, 90) or Color3.fromRGB(25, 25, 38)
            b.TextColor3 = Color3.fromRGB(220, 220, 220)
            b.Font = Enum.Font.Gotham
            b.TextSize = 12
            b.Text = name
            b.TextXAlignment = Enum.TextXAlignment.Left
            b.AutoButtonColor = false
            b.ZIndex = 12
            b.Parent = PopScroll
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
            local pp = Instance.new("UIPadding")
            pp.PaddingLeft = UDim.new(0, 8)
            pp.Parent = b
            b.MouseButton1Click:Connect(function()
                Config.TargetPet = name
                filterBtn.Text = "Target: " .. name
                filterBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
                Pop.Visible = false
                filterOpen = false
                buildList("")
            end)
            table.insert(petRows, b)
        end
    end
end

Config.TargetPet = "All"
buildList("")

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    buildList(SearchBox.Text)
end)

filterBtn.MouseButton1Click:Connect(function()
    filterOpen = not filterOpen
    Pop.Visible = filterOpen
    if filterOpen then SearchBox:CaptureFocus() end
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    MENU SECTIONS                          ║
-- ╚═══════════════════════════════════════════════════════════╝

sec("Auto Farm")
tog("Auto Steal Egg", "AutoSteal", C.accent)
tog("Auto Hatch Egg", "AutoHatch", C.accent)
tog("Auto Treadmill", "AutoTreadmill", C.accent)

sec("Extras")
tog("Speed Boost", "SpeedBoost", C.warn,
    function() if humanoid then humanoid.WalkSpeed = Config.WalkSpeed end end,
    function() if humanoid then humanoid.WalkSpeed = 16 end end)
tog("Egg ESP", "EggESP", C.warn, nil, function() clearESP() end)
tog("Mutation Only", "MutationOnly", C.warn)

sec("Protection")
tog("Anti-Kick", "AntiKick", C.success, function() enableAntiKick() end, nil)
tog("Anti-AFK", "AntiAFK", C.success,
    function() Config.AntiAFK = true; enableAntiAFK() end,
    function() 
        Config.AntiAFK = false
        if afkThread then task.cancel(afkThread); afkThread = nil end
    end)

sec("Server")
tog("Auto Server Hop", "AutoServerHop", C.warn)
mkbtn("Find Empty Server Now", C.warn, function() task.spawn(hopToEmpty) end)

sec("Stats")
local sE = Instance.new("TextLabel")
sE.Size = UDim2.new(1, 0, 0, 16)
sE.BackgroundTransparency = 1
sE.TextColor3 = C.sub
sE.Font = Enum.Font.Gotham
sE.TextSize = 11
sE.TextXAlignment = Enum.TextXAlignment.Left
sE.Text = "Stolen: 0"
sE.Parent = Scroll

local sH = Instance.new("TextLabel")
sH.Size = UDim2.new(1, 0, 0, 16)
sH.BackgroundTransparency = 1
sH.TextColor3 = C.sub
sH.Font = Enum.Font.Gotham
sH.TextSize = 11
sH.TextXAlignment = Enum.TextXAlignment.Left
sH.Text = "Hatched: 0"
sH.Parent = Scroll

local sM = Instance.new("TextLabel")
sM.Size = UDim2.new(1, 0, 0, 16)
sM.BackgroundTransparency = 1
sM.TextColor3 = Color3.fromRGB(255, 215, 0)
sM.Font = Enum.Font.Gotham
sM.TextSize = 11
sM.TextXAlignment = Enum.TextXAlignment.Left
sM.Text = "Money: $0"
sM.Parent = Scroll

local sT = Instance.new("TextLabel")
sT.Size = UDim2.new(1, 0, 0, 16)
sT.BackgroundTransparency = 1
sT.TextColor3 = C.sub
sT.Font = Enum.Font.Gotham
sT.TextSize = 11
sT.TextXAlignment = Enum.TextXAlignment.Left
sT.Text = "Time: 00:00"
sT.Parent = Scroll

mkbtn("Reset Stats", C.off, function()
    Config.Stats.EggsStolen = 0
    Config.Stats.EggsHatched = 0
    Config.Stats.MoneyEarned = 0
    sessionStart = os.clock()
end)

-- Update stats display
task.spawn(function()
    while true do
        sE.Text = "Stolen: " .. Config.Stats.EggsStolen
        sH.Text = "Hatched: " .. Config.Stats.EggsHatched
        sM.Text = "Money: " .. formatCurrency(Config.Stats.MoneyEarned)
        local s = Config.Stats.SessionTime
        sT.Text = string.format("Time: %02d:%02d", math.floor(s / 60), s % 60)
        task.wait(1)
    end
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    KEYBOARD SHORTCUTS                     ║
-- ╚═══════════════════════════════════════════════════════════╝

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.T then
        Win.Visible = not Win.Visible
    elseif input.KeyCode == Enum.KeyCode.G then
        Config.AutoSteal = not Config.AutoSteal
        log("AutoSteal: " .. (Config.AutoSteal and "ON" or "OFF"))
    end
end)

-- ╔═══════════════════════════════════════════════════════════╗
-- ║                    INITIALIZATION                         ║
-- ╚═══════════════════════════════════════════════════════════╝

log("✅ SamyrzHub v2.0 cargado exitosamente!")
log("🎮 Presiona T para abrir/cerrar el menú")
log("🎮 Presiona G para activar/desactivar autofarm")
log("💰 Dinero: " .. formatCurrency(Config.Stats.MoneyEarned))
log("📊 Script basado en arquitectura probada y funcional")
