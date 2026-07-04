--[[
    Demonology Script - Fluent UI Edition
    ESP + Speed + NightVision + HuntAlert + Task Panel
    RightShift 切换GUI
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- 检测是否为移动端（手机/平板）
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

--===================================
-- 自动ESP配置
--===================================
local AutoESP = {
    HidingSpots = {
        "Kitchen_Closet",
        "GhostCloset",
        "HallCloset",
        "Closet",
        "Locker",
        "HidingSpot",
    },
    Switches = {
        "FuseBox",
        "Buttons",
        "MainAnchor",
        "PowerBox",
    },
    Ghosts = {
        "Ghost",
    },
    Blacklist = {
        "Cobblestone",
        "Path",
        "Road",
        "Ground",
        "Floor",
        "Wall",
        "Roof",
        "Door",
        "Window",
        "Stairs",
        "Map",
        "Exterior",
        "Interior",
        "House",
        "Room",
        "Lobby",
        "Spawn",
    },
}

local ItemNames = {
    ["1"] = "摄像机",
    ["2"] = "温度计",
    ["3"] = "书",
    ["4"] = "黑光",
    ["5"] = "通灵盒子",
    ["6"] = "EMF读卡器",
    ["7"] = "手电筒",
    ["8"] = "激光投影仪",
    ["9"] = "花",
    ["10"] = "能量手表",
    ["11"] = "能量饮料",
    ["12"] = "盐",
    ["13"] = "打火机",
    ["100"] = "好运币",
}

--===================================
-- 配置
--===================================
local Configuration = {}

Configuration.ESP = {}
Configuration.ESP.HidingSpots = true
Configuration.ESP.Switches = true
Configuration.ESP.Ghosts = true
Configuration.ESP.NormalItems = true
Configuration.ESP.CursedItems = true
Configuration.ESP.GhostRoom = true
Configuration.ESP.Salt = true

Configuration.NightVision = false
Configuration.HuntAlert = true

Configuration.Speed = {}
Configuration.Speed.Enabled = false
Configuration.Speed.Value = 16

--===================================
-- Fluent UI 初始化
--===================================
local Fluent = nil

local FluentUrls = {
    "https://twix.cyou/Fluent.txt",
    "https://ttwizz.pages.dev/Fluent.txt",
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/main/Fluent.lua",
    "https://pastebin.com/raw/6V7xQ7Z8",
}

if typeof(script) == "Instance" and script:FindFirstChild("Fluent") and script:FindFirstChild("Fluent"):IsA("ModuleScript") then
    Fluent = require(script:FindFirstChild("Fluent"))
else
    for _, url in ipairs(FluentUrls) do
        local Success, Result = pcall(function()
            return game:HttpGet(url, true)
        end)
        if Success and typeof(Result) == "string" and string.find(Result, "dawid") then
            Fluent = getfenv().loadstring(Result)()
            break
        end
    end
    if not Fluent then
        error("无法加载 Fluent UI，请检查网络连接")
    end
end

--===================================
-- ScreenGui (全局GUI容器)
--===================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DemonologyGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

-- 移动端浮动按钮（切换GUI）
local MobileToggleBtn = nil
if IsMobile then
    MobileToggleBtn = Instance.new("TextButton")
    MobileToggleBtn.Name = "MobileToggle"
    MobileToggleBtn.Size = UDim2.new(0, 50, 0, 50)
    MobileToggleBtn.Position = UDim2.new(1, -65, 0.5, -25)
    MobileToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    MobileToggleBtn.BackgroundTransparency = 0.3
    MobileToggleBtn.Text = "👻"
    MobileToggleBtn.TextSize = 24
    MobileToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MobileToggleBtn.AutoButtonColor = true
    MobileToggleBtn.Draggable = true
    MobileToggleBtn.Parent = ScreenGui

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 10)
    btnCorner.Parent = MobileToggleBtn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Color3.fromRGB(100, 100, 150)
    btnStroke.Thickness = 2
    btnStroke.Parent = MobileToggleBtn
end

--===================================
-- ESP 系统
--===================================
local ESPObjects = {}
local DetectedGhostRoom = nil

local function CreateESP(obj, name, color)
    if ESPObjects[obj] then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.FillColor = color
    highlight.FillTransparency = 0.6
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.OutlineTransparency = 0
    highlight.Adornee = obj
    highlight.Parent = obj

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Label"
    billboard.Size = IsMobile and UDim2.new(0, 160, 0, 24) or UDim2.new(0, 200, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = obj
    billboard.Parent = obj

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Text = name
    label.Font = Enum.Font.GothamBold
    label.TextSize = IsMobile and 12 or 14
    label.Parent = billboard

    ESPObjects[obj] = { highlight = highlight, billboard = billboard }
end

local function CreateFloorESP(obj, name, color)
    -- 鬼房只绘制地板，不绘制墙壁
    if ESPObjects[obj] then return end

    local data = { highlights = {}, billboard = nil }
    local FloorKeywords = {"floor", "ground", "carpet", "rug", "tile"}

    local function IsFloorPart(part)
        if not part:IsA("BasePart") then return false end
        local lowerName = part.Name:lower()
        for _, kw in ipairs(FloorKeywords) do
            if lowerName:find(kw) then return true end
        end
        -- 地板通常是扁平的（Y尺寸很小）
        if part.Size.Y < 2 and part.Size.X > 3 and part.Size.Z > 3 then
            return true
        end
        return false
    end

    for _, desc in ipairs(obj:GetDescendants()) do
        if IsFloorPart(desc) and not data.highlights[desc] then
            local hl = Instance.new("Highlight")
            hl.Name = "FloorESP_Highlight"
            hl.FillColor = color
            hl.FillTransparency = 0.5
            hl.OutlineColor = Color3.new(1, 1, 1)
            hl.OutlineTransparency = 0
            hl.Adornee = desc
            hl.Parent = desc
            data.highlights[desc] = hl
        end
    end

    -- 如果没找到地板部件，对整个Model加ESP作为兜底
    if next(data.highlights) == nil then
        local hl = Instance.new("Highlight")
        hl.Name = "ESP_Highlight"
        hl.FillColor = color
        hl.FillTransparency = 0.6
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.OutlineTransparency = 0
        hl.Adornee = obj
        hl.Parent = obj
        data.highlights[obj] = hl
    end

    -- 标签
    local primaryPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    if primaryPart then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ESP_Label"
        billboard.Size = UDim2.new(0, 200, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 2.5, 0)
        billboard.AlwaysOnTop = true
        billboard.Adornee = primaryPart
        billboard.Parent = obj

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = color
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextStrokeTransparency = 0
        label.Text = name
        label.Font = Enum.Font.GothamBold
        label.TextSize = 14
        label.Parent = billboard

        data.billboard = billboard
    end

    ESPObjects[obj] = data
end

local function RemoveESP(obj)
    if not ESPObjects[obj] then return end
    local data = ESPObjects[obj]
    if data.highlight then data.highlight:Destroy() end
    if data.highlights then
        for _, hl in pairs(data.highlights) do
            pcall(function() hl:Destroy() end)
        end
    end
    if data.billboard then data.billboard:Destroy() end
    if data.box then data.box:Destroy() end
    if data.circleBillboard then data.circleBillboard:Destroy() end
    if data.labelBillboard then data.labelBillboard:Destroy() end
    if data.glowBillboard then data.glowBillboard:Destroy() end
    if data.boxes then
        for _, box in pairs(data.boxes) do
            pcall(function() box:Destroy() end)
        end
    end
    if data.conns then
        for _, conn in ipairs(data.conns) do
            pcall(function() conn:Disconnect() end)
        end
    end
    ESPObjects[obj] = nil
end

local function CreateGhostESP(obj)
    if ESPObjects[obj] then return end

    local data = { boxes = {}, conns = {} }

    local BodyKeywords = {
        "head", "torso", "arm", "leg", "hand", "foot",
    }

    local function AddPartBox(part)
        if not part:IsA("BasePart") then return end
        if data.boxes[part] then return end

        local lowerName = part.Name:lower()
        local isBodyPart = false
        for _, kw in ipairs(BodyKeywords) do
            if lowerName:find(kw) then
                isBodyPart = true
                break
            end
        end
        if not isBodyPart then return end

        local box = Instance.new("BoxHandleAdornment")
        box.Name = "GhostESP_Box"
        box.Adornee = part
        box.AlwaysOnTop = true
        box.Color3 = Color3.fromRGB(255, 0, 0)
        box.Transparency = 0.7
        box.Size = part.Size
        box.ZIndex = 10
        box.Parent = part

        data.boxes[part] = box
    end

    local function RemovePartBox(part)
        local box = data.boxes[part]
        if box then
            box:Destroy()
            data.boxes[part] = nil
        end
    end

    for _, desc in ipairs(obj:GetDescendants()) do
        AddPartBox(desc)
    end

    table.insert(data.conns, obj.DescendantAdded:Connect(AddPartBox))
    table.insert(data.conns, obj.DescendantRemoving:Connect(RemovePartBox))

    local rootPart = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "GhostESP_Label"
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = rootPart or obj
    billboard.Parent = obj

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.Text = "[鬼] " .. obj.Name
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard

    data.billboard = billboard

    ESPObjects[obj] = data
end

local function NameInList(name, list)
    local lower = name:lower()
    for _, n in ipairs(AutoESP.Blacklist) do
        if lower:find(n:lower()) then return false end
    end
    for _, n in ipairs(list) do
        if lower == n:lower() then return true end
    end
    return false
end

local function IsNumberName(name)
    return tonumber(name) ~= nil
end

local RoomKeywords = {
    "bedroom", "livingroom", "kitchen", "bathroom",
    "hallway", "attic", "basement", "garage", "diningroom",
    "masterbedroom", "guestroom", "office", "storage", "foyer",
    "stairs", "landing", "laundryroom", "nursery", "playroom",
    "sunroom", "pantry", "hall", "den", "study", "library",
    "room", "closet", "closets",
}

local function IsRoomModel(name)
    local lower = name:lower()
    for _, kw in ipairs(RoomKeywords) do
        if lower:find(kw) then return true end
    end
    return false
end

local function IsNonRoomModel(name)
    if NameInList(name, AutoESP.HidingSpots) then return true end
    if NameInList(name, AutoESP.Switches) then return true end
    if NameInList(name, AutoESP.Ghosts) then return true end
    if IsNumberName(name) then return true end
    return false
end

local function FindGhostRoom()
    local ghostPos = nil
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and NameInList(obj.Name, AutoESP.Ghosts) then
            local primary = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if primary then
                ghostPos = primary.Position
                break
            end
        end
    end

    if not ghostPos then return nil end

    local minDist = math.huge
    local closestRoom = nil

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and IsRoomModel(obj.Name) and not IsNonRoomModel(obj.Name) then
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local dist = (part.Position - ghostPos).Magnitude
                if dist < minDist then
                    minDist = dist
                    closestRoom = obj
                end
            end
        end
    end

    return closestRoom
end

local function RefreshESP()
    -- 清理所有旧ESP，包括已失效的对象引用
    for obj, _ in pairs(ESPObjects) do
        RemoveESP(obj)
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            local name = obj.Name
            if Configuration.ESP.HidingSpots and NameInList(name, AutoESP.HidingSpots) then
                CreateESP(obj, "[躲藏] " .. name, Color3.fromRGB(0, 255, 100))
            elseif Configuration.ESP.Switches and NameInList(name, AutoESP.Switches) then
                CreateESP(obj, "[电闸] " .. name, Color3.fromRGB(255, 255, 0))
            elseif Configuration.ESP.Ghosts and NameInList(name, AutoESP.Ghosts) then
                CreateGhostESP(obj)
            elseif name == "ExitDoor" then
                CreateESP(obj, "[大门] " .. name, Color3.fromRGB(255, 165, 0))
            end
        end
    end

    -- 额外：从 Map.Closets 文件夹直接读取躲藏点（新地图格式）
    if Configuration.ESP.HidingSpots then
        local map = workspace:FindFirstChild("Map")
        if map then
            local closests = map:FindFirstChild("Closets")
            if closests then
                for _, obj in ipairs(closests:GetChildren()) do
                    if obj:IsA("Model") or obj:IsA("BasePart") then
                        if not ESPObjects[obj] then
                            CreateESP(obj, "[躲藏] " .. obj.Name, Color3.fromRGB(0, 255, 100))
                        end
                    end
                end
            end
        end
    end

    if Configuration.ESP.NormalItems or Configuration.ESP.CursedItems then
        local itemsFolder = workspace:FindFirstChild("Items")
        if itemsFolder then
            for _, item in ipairs(itemsFolder:GetChildren()) do
                if ESPObjects[item] then continue end

                local isCursed = false
                local itemName = nil
                local num = tonumber(item.Name)

                -- 编号1-9优先用映射表（基础道具，固定名称）
                if num and num >= 1 and num <= 9 then
                    itemName = ItemNames[item.Name] or "物品"
                    isCursed = false
                -- 以下用子部件名称判断特殊物品
                elseif item:FindFirstChild("Magnifying Glass") then
                    itemName = "诅咒道具放大镜"
                    isCursed = true
                elseif item:FindFirstChild("Meshes/Canobj") then
                    itemName = "盐"
                    isCursed = false
                elseif item:FindFirstChild("Base") then
                    itemName = "能量饮料"
                    isCursed = false
                elseif item:FindFirstChild("Color") then
                    itemName = "打火机"
                    isCursed = false
                elseif item:FindFirstChild("Red Teddy Bear") then
                    itemName = "小熊娃娃"
                    isCursed = false
                elseif item:FindFirstChild("Screen") then
                    itemName = "能量手表"
                    isCursed = false
                elseif item:FindFirstChild("Main") then
                    if num and num == 100 then
                        itemName = "Umbra板"
                        isCursed = true
                    else
                        itemName = "物品"
                        isCursed = false
                    end
                elseif item:FindFirstChild("mirror.002") then
                    itemName = "鬼魅镜"
                    isCursed = true
                elseif item:FindFirstChild("Meshes/Frame (1)") then
                    itemName = "音乐盒子"
                    isCursed = true
                else
                    itemName = "物品"
                    isCursed = false
                end

                if itemName then
                    if isCursed and Configuration.ESP.CursedItems then
                        CreateESP(item, itemName, Color3.fromRGB(255, 50, 50))
                    elseif not isCursed and Configuration.ESP.NormalItems then
                        CreateESP(item, itemName, Color3.fromRGB(0, 150, 255))
                    end
                end
            end
        end

        -- 额外遍历 CursedPossessionHolder（诅咒道具容器，不在Items里）
        local cursedHolder = workspace:FindFirstChild("CursedPossessionHolder")
        if cursedHolder then
            for _, item in ipairs(cursedHolder:GetChildren()) do
                if ESPObjects[item] then continue end

                local isCursed = true
                local itemName = nil

                if item:FindFirstChild("Primary") then
                    itemName = "预言家"
                else
                    itemName = "诅咒物品"
                end

                if isCursed and Configuration.ESP.CursedItems then
                    CreateESP(item, itemName, Color3.fromRGB(255, 50, 50))
                end
            end
        end
    end

    if Configuration.ESP.Salt then
        local saltPiles = workspace:FindFirstChild("SaltPiles")
        if saltPiles then
            -- 遍历所有盐堆，包括所有 DisturbedSaltLine
            for _, obj in ipairs(saltPiles:GetChildren()) do
                if not ESPObjects[obj] then
                    local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
                    if part then
                        local isDisturbed = (obj.Name == "DisturbedSaltLine")
                        local fillColor = isDisturbed and Color3.fromRGB(139, 69, 19) or Color3.fromRGB(255, 255, 200)
                        local outlineColor = isDisturbed and Color3.fromRGB(160, 82, 45) or Color3.fromRGB(255, 255, 0)
                        local textColor = isDisturbed and Color3.fromRGB(210, 180, 140) or Color3.fromRGB(255, 255, 200)
                        local labelText = isDisturbed and "[盐 - 已踩]" or "[盐]"

                        local highlight = Instance.new("Highlight")
                        highlight.Name = isDisturbed and "DisturbedSaltESP_Highlight" or "SaltESP_Highlight"
                        highlight.Adornee = obj
                        highlight.FillColor = fillColor
                        highlight.FillTransparency = 0.6
                        highlight.OutlineColor = outlineColor
                        highlight.OutlineTransparency = 0
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.Parent = obj

                        local billboard = Instance.new("BillboardGui")
                        billboard.Name = isDisturbed and "DisturbedSaltESP_Label" or "SaltESP_Label"
                        billboard.Size = UDim2.new(0, 200, 0, 30)
                        billboard.StudsOffset = Vector3.new(0, 2, 0)
                        billboard.AlwaysOnTop = true
                        billboard.Adornee = part
                        billboard.Parent = obj

                        local label = Instance.new("TextLabel")
                        label.Size = UDim2.new(1, 0, 1, 0)
                        label.BackgroundTransparency = 1
                        label.TextColor3 = textColor
                        label.TextStrokeColor3 = Color3.new(0, 0, 0)
                        label.TextStrokeTransparency = 0
                        label.Text = labelText
                        label.Font = Enum.Font.GothamBold
                        label.TextSize = 14
                        label.Parent = billboard

                        ESPObjects[obj] = { highlight = highlight, billboard = billboard }
                    end
                end
            end
        end
    end

    if Configuration.ESP.GhostRoom then
        if not DetectedGhostRoom then
            DetectedGhostRoom = FindGhostRoom()
        end
        if DetectedGhostRoom then
            CreateFloorESP(DetectedGhostRoom, "[鬼房] " .. DetectedGhostRoom.Name, Color3.fromRGB(255, 100, 200))
        end
    end
end

task.spawn(function()
    while true do
        task.wait(3)
        RefreshESP()
    end
end)

--===================================
-- Speed 系统
--===================================
local speedConn = nil

local function ApplySpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if Configuration.Speed.Enabled then
        humanoid.WalkSpeed = Configuration.Speed.Value
    else
        humanoid.WalkSpeed = 16
    end
end

local function StartSpeedLoop()
    if speedConn then return end
    speedConn = RunService.Heartbeat:Connect(function()
        ApplySpeed()
    end)
    print("[Demonology] 速度循环已启动")
end

local function StopSpeedLoop()
    if speedConn then
        speedConn:Disconnect()
        speedConn = nil
    end
    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = 16
        end
    end
end

--===================================
-- 夜视系统
--===================================
local nightVisionConn = nil
local function SetNightVision(enabled)
    if enabled then
        if nightVisionConn then return end
        nightVisionConn = RunService.Heartbeat:Connect(function()
            Lighting.Brightness = 3
            Lighting.ClockTime = 12
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1000
            Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        end)
    else
        if nightVisionConn then
            nightVisionConn:Disconnect()
            nightVisionConn = nil
        end
        Lighting.Brightness = 1
        Lighting.ClockTime = 18
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 200
        Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 120)
    end
end

--===================================
-- 能量条
--===================================
local EnergyBarFrame = Instance.new("Frame")
EnergyBarFrame.Name = "EnergyBar"
EnergyBarFrame.Size = IsMobile and UDim2.new(0, 200, 0, 22) or UDim2.new(0, 260, 0, 26)
EnergyBarFrame.Position = IsMobile and UDim2.new(0.5, -100, 1, -60) or UDim2.new(0.5, -130, 1, -70)
EnergyBarFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
EnergyBarFrame.BackgroundTransparency = 0.3
EnergyBarFrame.BorderSizePixel = 0
EnergyBarFrame.Parent = ScreenGui

local ebarCorner = Instance.new("UICorner")
ebarCorner.CornerRadius = UDim.new(0, 6)
ebarCorner.Parent = EnergyBarFrame

local ebarStroke = Instance.new("UIStroke")
ebarStroke.Color = Color3.fromRGB(49, 50, 68)
ebarStroke.Thickness = 1
ebarStroke.Parent = EnergyBarFrame

local ebarFill = Instance.new("Frame")
ebarFill.Name = "Fill"
ebarFill.Size = UDim2.new(1, 0, 1, 0)
ebarFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
ebarFill.BorderSizePixel = 0
ebarFill.Parent = EnergyBarFrame

local ebarFillCorner = Instance.new("UICorner")
ebarFillCorner.CornerRadius = UDim.new(0, 6)
ebarFillCorner.Parent = ebarFill

local ebarText = Instance.new("TextLabel")
ebarText.Name = "Text"
ebarText.Size = UDim2.new(1, 0, 1, 0)
ebarText.BackgroundTransparency = 1
ebarText.Text = "能量: 搜索中..."
ebarText.TextColor3 = Color3.fromRGB(255, 255, 255)
ebarText.TextStrokeColor3 = Color3.new(0, 0, 0)
ebarText.TextStrokeTransparency = 0
ebarText.Font = Enum.Font.GothamBold
ebarText.TextSize = 13
ebarText.Parent = EnergyBarFrame

local energyObj = nil
local energyType = nil
local energySearched = false

local function SearchEnergy()
    energyObj = nil
    energyType = nil

    pcall(function()
        for _, v in ipairs(LocalPlayer:GetDescendants()) do
            if v:IsA("NumberValue") or v:IsA("IntValue") then
                local n = v.Name:lower()
                if n == "energy" or n == "stamina" or n == "sanity" then
                    energyObj = v
                    energyType = "value"
                    return
                end
            end
        end
    end)

    if not energyObj then
        pcall(function()
            local char = LocalPlayer.Character
            if char then
                for _, v in ipairs(char:GetDescendants()) do
                    if v:IsA("NumberValue") or v:IsA("IntValue") then
                        local n = v.Name:lower()
                        if n == "energy" or n == "stamina" or n == "sanity" then
                            energyObj = v
                            energyType = "value"
                            return
                        end
                    end
                end
            end
        end)
    end

    if not energyObj then
        pcall(function()
            local attr = LocalPlayer:GetAttribute("Energy")
            if type(attr) ~= "number" then
                attr = LocalPlayer:GetAttribute("Stamina")
            end
            if type(attr) ~= "number" then
                attr = LocalPlayer:GetAttribute("Sanity")
            end
            if type(attr) == "number" then
                energyType = "attribute"
                return
            end
        end)
    end

    if not energyObj and energyType ~= "attribute" then
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                for _, v in ipairs(pg:GetDescendants()) do
                    if v:IsA("NumberValue") or v:IsA("IntValue") then
                        local n = v.Name:lower()
                        if n == "energy" or n == "stamina" or n == "sanity" then
                            energyObj = v
                            energyType = "value"
                            return
                        end
                    end
                end
            end
        end)
    end

    if not energyObj and energyType ~= "attribute" then
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                for _, v in ipairs(pg:GetDescendants()) do
                    if v:IsA("TextLabel") then
                        local txt = v.Text:lower()
                        if (txt:find("energy") or txt:find("stamina") or txt:find("sanity")) and txt:match("(%d+%.?%d*)") then
                            energyObj = v
                            energyType = "label"
                            return
                        end
                    end
                end
            end
        end)
    end
end

local function GetEnergyValue()
    if energyType == "attribute" then
        local attr = LocalPlayer:GetAttribute("Energy")
        if type(attr) ~= "number" then attr = LocalPlayer:GetAttribute("Stamina") end
        if type(attr) ~= "number" then attr = LocalPlayer:GetAttribute("Sanity") end
        if type(attr) == "number" then return attr end
        return nil
    end

    if energyObj and energyObj.Parent then
        if energyType == "value" then
            return energyObj.Value
        elseif energyType == "label" then
            local num = tonumber(energyObj.Text:match("(%d+%.?%d*)"))
            return num
        end
    end

    energyObj = nil
    energyType = nil
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.3)
        if not energyObj and energyType ~= "attribute" and not energySearched then
            energySearched = true
            SearchEnergy()
        end

        local energy = GetEnergyValue()
        if energy ~= nil then
            local percent = math.clamp(energy, 0, 100)
            ebarFill.Size = UDim2.new(percent / 100, 0, 1, 0)
            ebarText.Text = string.format("能量: %.1f%%", percent)
        else
            ebarFill.Size = UDim2.new(1, 0, 1, 0)
            ebarText.Text = "能量: 搜索中..."
        end
    end
end)

--===================================
-- 任务面板 (左下角)
--===================================
-- 手动标记的任务完成状态（key=任务标题原文，value=true/false）
local TaskManualState = {}

local TaskPanel = Instance.new("Frame")
TaskPanel.Name = "TaskPanel"
TaskPanel.Size = IsMobile and UDim2.new(0, 280, 0, 220) or UDim2.new(0, 400, 0, 300)
TaskPanel.Position = IsMobile and UDim2.new(0, 5, 1, -230) or UDim2.new(0, 10, 1, -320)
TaskPanel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
TaskPanel.BackgroundTransparency = 0.2
TaskPanel.BorderSizePixel = 0
TaskPanel.Parent = ScreenGui

local taskCorner = Instance.new("UICorner")
taskCorner.CornerRadius = UDim.new(0, 8)
taskCorner.Parent = TaskPanel

local taskStroke = Instance.new("UIStroke")
taskStroke.Color = Color3.fromRGB(80, 80, 110)
taskStroke.Thickness = 2
taskStroke.Parent = TaskPanel

local taskLayout = Instance.new("UIListLayout")
taskLayout.SortOrder = Enum.SortOrder.LayoutOrder
taskLayout.Padding = UDim.new(0, 4)
taskLayout.Parent = TaskPanel

local taskPadding = Instance.new("UIPadding")
taskPadding.PaddingLeft = UDim.new(0, 10)
taskPadding.PaddingRight = UDim.new(0, 10)
taskPadding.PaddingTop = UDim.new(0, 8)
taskPadding.PaddingBottom = UDim.new(0, 6)
taskPadding.Parent = TaskPanel

local TaskTranslations = {
    -- 完整句子（先长后短，有序数组）
    {en = "identify the correct ghost type", zh = "识别正确的鬼类型"},
    {en = "capture photo of the ghost", zh = "拍摄鬼的照片"},
    {en = "have every member of your team escape the house", zh = "让所有队友逃离房子"},
    {en = "reach an average sanity", zh = "达到平均理智值"},
    {en = "find the cursed item", zh = "找到诅咒物品"},
    {en = "use the cursed item", zh = "使用诅咒物品"},
    {en = "use smudge stick", zh = "使用圣木"},
    {en = "use emf reader", zh = "使用EMF读卡器"},
    {en = "use spirit box", zh = "使用通灵盒"},
    {en = "use uv light", zh = "使用黑光"},
    {en = "use thermometer", zh = "使用温度计"},
    {en = "use camera", zh = "使用相机"},
    {en = "collect evidence", zh = "收集证据"},
    {en = "survive a hunt", zh = "在猎杀中存活"},
    {en = "cleanse the area", zh = "净化区域"},
    {en = "place salt", zh = "放置盐"},
    {en = "light candle", zh = "点燃蜡烛"},
    {en = "listen to radio", zh = "收听电台"},
    {en = "freeze the ghost", zh = "冻结鬼"},
    {en = "prevent a hunt", zh = "阻止一次猎杀"},
    {en = "witness a hunt", zh = "目击一次猎杀"},
    {en = "repel the ghost", zh = "驱赶鬼"},
    {en = "find the ghost room", zh = "找到鬼房"},
    {en = "objective #1", zh = "目标 1"},
    {en = "objective #2", zh = "目标 2"},
    {en = "objective #3", zh = "目标 3"},
    {en = "objective #4", zh = "目标 4"},
    -- 短词（放后面，避免破坏长句）
    {en = "objective", zh = "目标"},
    {en = "ghost type", zh = "鬼类型"},
    {en = "cursed item", zh = "诅咒物品"},
    {en = "smudge stick", zh = "圣木"},
    {en = "emf reader", zh = "EMF读卡器"},
    {en = "spirit box", zh = "通灵盒"},
    {en = "uv light", zh = "黑光"},
    {en = "thermometer", zh = "温度计"},
    {en = "sanity", zh = "理智值"},
    {en = "evidence", zh = "证据"},
    {en = "ghost room", zh = "鬼房"},
    {en = "ghost", zh = "鬼"},
    {en = "house", zh = "房子"},
    {en = "hunt", zh = "猎杀"},
    {en = "collect", zh = "收集"},
    {en = "survive", zh = "存活"},
    {en = "find", zh = "找到"},
    {en = "cleanse", zh = "净化"},
    {en = "place", zh = "放置"},
    {en = "light", zh = "点燃"},
    {en = "listen", zh = "收听"},
    {en = "freeze", zh = "冻结"},
    {en = "repel", zh = "驱赶"},
    {en = "prevent", zh = "阻止"},
    {en = "witness", zh = "目击"},
    {en = "escape", zh = "逃离"},
    {en = "camera", zh = "相机"},
    {en = "radio", zh = "电台"},
    {en = "candle", zh = "蜡烛"},
    {en = "area", zh = "区域"},
    {en = "salt", zh = "盐"},
    {en = "team", zh = "团队"},
    {en = "average", zh = "平均"},
    {en = "photo", zh = "照片"},
    {en = "correct", zh = "正确的"},
    {en = "identify", zh = "识别"},
    {en = "capture", zh = "拍摄"},
    {en = "use", zh = "使用"},
}

-- 转义pattern特殊字符
local function escapePattern(s)
    return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

-- 尝试用 Roblox 官方翻译
local robloxTranslator = nil
pcall(function()
    local LocalizationService = game:GetService("LocalizationService")
    robloxTranslator = LocalizationService:GetTranslatorForLocaleAsync("zh-cjv")
end)

local function TranslateTask(text)
    if not text or text == "" then return "" end

    -- 清理所有HTML标签和实体
    local cleaned = text:gsub("<[^>]+>", ""):gsub("&nbsp;", " "):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
    local lower = cleaned:lower()

    -- 第一轮：只尝试完整句子匹配（长句优先，避免短词破坏）
    local sentenceMatched = false
    local result = lower
    for _, pair in ipairs(TaskTranslations) do
        if pair.en:find(" ") then
            local pattern = escapePattern(pair.en)
            if lower:find(pattern) then
                result = result:gsub(pattern, pair.zh)
                sentenceMatched = true
            end
        end
    end

    -- 如果完整句子匹配到了，直接返回
    if sentenceMatched then
        result = result:gsub("  +", " ")
        result = result:match("^%s*(.-)%s*$") or result
        return result
    end

    -- 没匹配到完整句子，尝试 Roblox 官方翻译
    if robloxTranslator then
        local success, robloxResult = pcall(function()
            return robloxTranslator:Translate(game, cleaned)
        end)
        if success and robloxResult and robloxResult ~= cleaned and #robloxResult > 0 then
            if robloxResult:match("[\228-\233][\128-\191][\128-\191]") then
                return robloxResult
            end
        end
    end

    -- 最后才用短词匹配
    for _, pair in ipairs(TaskTranslations) do
        if not pair.en:find(" ") then
            local pattern = escapePattern(pair.en)
            result = result:gsub(pattern, pair.zh)
        end
    end
    result = result:gsub("  +", " ")
    result = result:match("^%s*(.-)%s*$") or result
    return result
end

local function FindTaskBoard()
    -- 搜索1: workspace.Anchor.SurfaceGui.Holder
    local anchor = workspace:FindFirstChild("Anchor")
    if anchor then
        local sg = anchor:FindFirstChild("SurfaceGui")
        if sg then
            local holder = sg:FindFirstChild("Holder")
            if holder then return holder end
        end
    end

    -- 搜索2: 全workspace搜索SurfaceGui中的Holder
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "Holder" and v.Parent and v.Parent:IsA("SurfaceGui") then
            return v
        end
    end

    -- 搜索3: 找含Title和Description的SurfaceGui
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("SurfaceGui") and v:FindFirstChild("Title") and v:FindFirstChild("Description") then
            return v
        end
    end

    -- 搜索4: PlayerGui中搜索
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, v in ipairs(pg:GetDescendants()) do
            if v.Name == "Holder" then
                return v
            end
        end
    end

    return nil
end

local function IsTaskCompleted(child, title)
    -- 检测方式1: 有Completed/IsCompleted/Done为true的BoolValue
    local completedVal = child:FindFirstChild("Completed") or child:FindFirstChild("IsCompleted") or child:FindFirstChild("Done")
    if completedVal and completedVal:IsA("BoolValue") and completedVal.Value then
        return true
    end
    -- 检测方式2: Attribute为true
    if child:GetAttribute("Completed") == true or child:GetAttribute("IsCompleted") == true or child:GetAttribute("Done") == true then
        return true
    end
    -- 检测方式3: Title文字本身包含完成标记
    if title and title:IsA("TextLabel") then
        local t = title.Text
        if t:find("✓") or t:find("√") or t:find("[已完成]") or t:lower():find("%[completed%]") or t:lower():find("%[done%]") then
            return true
        end
    end
    return false
end

local function GetTaskItems(board)
    local items = {}
    if not board then return items end

    for _, child in ipairs(board:GetChildren()) do
        if child:IsA("GuiObject") or child:IsA("Folder") or child:IsA("Configuration") then
            local title = child:FindFirstChild("Title")
            local desc = child:FindFirstChild("Description")
            if title and desc then
                local titleText = title:IsA("TextLabel") and title.Text or ""
                local descText = desc:IsA("TextLabel") and desc.Text or ""
                if #titleText:gsub("%s", "") > 0 or #descText:gsub("%s", "") > 0 then
                    table.insert(items, { title = titleText, desc = descText })
                end
            end
        end
    end

    return items
end

-- 记录上次任务内容，只在内容变化时才重建面板（避免点击失效）
local lastTaskContentHash = ""

local function RefreshTaskPanel()
    local board = FindTaskBoard()
    local taskItems = GetTaskItems(board)

    -- 生成内容哈希，检测任务内容是否变化
    local hash = ""
    for _, task in ipairs(taskItems) do
        hash = hash .. (task.title or "") .. "|" .. (task.desc or "") .. "#"
    end

    -- 内容没变化，不重建（保留可点击状态）
    if hash == lastTaskContentHash then return end
    lastTaskContentHash = hash

    -- 内容变了，清空重建
    for _, child in ipairs(TaskPanel:GetChildren()) do
        if child:IsA("TextLabel") or child:IsA("TextButton") then
            child:Destroy()
        end
    end

    if #taskItems == 0 then
        local msg = Instance.new("TextLabel")
        msg.Size = UDim2.new(1, 0, 0, 22)
        msg.BackgroundTransparency = 1
        msg.Text = "暂无任务"
        msg.TextColor3 = Color3.fromRGB(200, 200, 220)
        msg.TextStrokeTransparency = 0.8
        msg.Font = Enum.Font.GothamBold
        msg.TextSize = 16
        msg.TextXAlignment = Enum.TextXAlignment.Left
        msg.Parent = TaskPanel
        return
    end

    -- 标题提示
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 24)
    header.BackgroundTransparency = 1
    header.Text = "📋 任务（点击切换完成）"
    header.TextColor3 = Color3.fromRGB(150, 200, 255)
    header.TextStrokeColor3 = Color3.new(0, 0, 0)
    header.TextStrokeTransparency = 0.6
    header.Font = Enum.Font.GothamBold
    header.TextSize = 16
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = TaskPanel

    for i, task in ipairs(taskItems) do
        if i > 5 then break end

        local taskKey = task.title or ("task_" .. i)
        local isDone = TaskManualState[taskKey] == true
        local descLabel = nil

        -- 用TextButton，可点击切换完成状态
        local titleBtn = Instance.new("TextButton")
        titleBtn.Size = UDim2.new(1, 0, 0, 28)
        titleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        titleBtn.BackgroundTransparency = 0.7
        titleBtn.AutoButtonColor = true
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = titleBtn
        local checkMark = isDone and " ✓" or ""
        titleBtn.Text = "• " .. TranslateTask(task.title or "") .. checkMark
        titleBtn.TextColor3 = isDone and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 255, 180)
        titleBtn.TextStrokeColor3 = Color3.new(0, 0, 0)
        titleBtn.TextStrokeTransparency = 0.6
        titleBtn.Font = Enum.Font.GothamBold
        titleBtn.TextSize = 18
        titleBtn.TextXAlignment = Enum.TextXAlignment.Left
        titleBtn.TextWrapped = true
        titleBtn.Parent = TaskPanel

        -- 文字左内边距
        local btnPad = Instance.new("UIPadding")
        btnPad.PaddingLeft = UDim.new(0, 6)
        btnPad.Parent = titleBtn

        -- 点击切换完成状态
        titleBtn.MouseButton1Click:Connect(function()
            TaskManualState[taskKey] = not TaskManualState[taskKey]
            local done = TaskManualState[taskKey] == true
            titleBtn.Text = "• " .. TranslateTask(task.title or "") .. (done and " ✓" or "")
            titleBtn.TextColor3 = done and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 255, 180)
            -- 同步更新描述颜色
            if descLabel then
                descLabel.TextColor3 = done and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(180, 180, 200)
            end
        end)

        if task.desc and #task.desc:gsub("%s", "") > 0 then
            descLabel = Instance.new("TextLabel")
            descLabel.Size = UDim2.new(1, 0, 0, 22)
            descLabel.BackgroundTransparency = 1
            descLabel.Text = "  " .. TranslateTask(task.desc)
            descLabel.TextColor3 = isDone and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(180, 180, 200)
            descLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
            descLabel.TextStrokeTransparency = 0.7
            descLabel.Font = Enum.Font.Gotham
            descLabel.TextSize = 15
            descLabel.TextXAlignment = Enum.TextXAlignment.Left
            descLabel.TextWrapped = true
            descLabel.Parent = TaskPanel
        end
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        RefreshTaskPanel()
    end
end)
--===================================
-- 音频事件通知系统（唱歌/死亡/电闸/诅咒镜子）
-- 用Fluent UI自带的Notify，样式统一好看
--===================================

-- 通知冷却（避免同一事件短时间内重复触发）
local eventCooldowns = {}

local function FluentNotify(title, content, subContent, duration)
    if Fluent then
        Fluent:Notify({
            Title = title,
            Content = content,
            SubContent = subContent or "",
            Duration = duration or 4
        })
    else
        -- Fluent还没加载好，用临时通知兜底
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 380, 0, 60)
        frame.Position = UDim2.new(1, -410, 0, 20)
        frame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        frame.BackgroundTransparency = 0.2
        frame.Parent = ScreenGui
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(100, 100, 150)
        stroke.Thickness = 2
        stroke.Parent = frame
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, -20, 0, 28)
        tl.Position = UDim2.new(0, 10, 0, 4)
        tl.BackgroundTransparency = 1
        tl.Text = title
        tl.TextColor3 = Color3.fromRGB(255, 255, 255)
        tl.TextStrokeColor3 = Color3.new(0, 0, 0)
        tl.TextStrokeTransparency = 0.5
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 16
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.Parent = frame
        local dl = Instance.new("TextLabel")
        dl.Size = UDim2.new(1, -20, 0, 22)
        dl.Position = UDim2.new(0, 10, 0, 32)
        dl.BackgroundTransparency = 1
        dl.Text = content
        dl.TextColor3 = Color3.fromRGB(220, 220, 220)
        dl.TextStrokeColor3 = Color3.new(0, 0, 0)
        dl.TextStrokeTransparency = 0.6
        dl.Font = Enum.Font.Gotham
        dl.TextSize = 14
        dl.TextXAlignment = Enum.TextXAlignment.Left
        dl.Parent = frame
        task.delay(duration or 4, function()
            if frame and frame.Parent then frame:Destroy() end
        end)
    end
end

local function NotifyWithCooldown(eventKey, title, content, subContent, cooldown, duration)
    cooldown = cooldown or 5
    local now = tick()
    if eventCooldowns[eventKey] and (now - eventCooldowns[eventKey]) < cooldown then
        return
    end
    eventCooldowns[eventKey] = now
    FluentNotify(title, content, subContent, duration)
end

-- 已监听的Sound集合（避免重复连接）
local hookedSounds = {}

local function HookOneSound(sound, onPlay)
    if not sound or not sound:IsA("Sound") then return end
    if hookedSounds[sound] then return end
    hookedSounds[sound] = true

    sound:GetPropertyChangedSignal("Playing"):Connect(function()
        if sound.IsPlaying then
            onPlay()
        end
    end)

    if sound.IsPlaying then
        onPlay()
    end
end

-- 事件配置
local AudioEvents = {
    {
        name = "singing",
        soundName = "GhostSinging",
        cooldown = 10,
        title = "♪ 幽灵正在唱歌中",
        content = "鬼正在唱歌，注意聆听歌声来源的方向",
        subContent = "GhostSinging",
        searchIn = "Deep", -- 改成深度搜索
    },
    {
        name = "death",
        soundName = "Scream",
        cooldown = 5,
        title = "☠ 你已经被鬼杀死",
        content = "队友被鬼击杀了！注意安全",
        subContent = "Death Sound",
        searchIn = "Deep", -- 改成深度搜索
    },
    {
        name = "poweroutage",
        soundName = "PowerOutage",
        cooldown = 15,
        title = "⚡ 鬼已把电闸拉上",
        content = "你暂时无法开灯，请找到电闸所在位置并开启",
        subContent = "Power Outage",
        searchIn = "Deep",
    },
    {
        name = "mirrorcrack",
        soundName = "MirrorCrack",
        cooldown = 5,
        title = "🪞 您的诅咒镜子碎了",
        content = "请立刻躲在柜子里！",
        subContent = "Mirror Crack",
        searchIn = "Deep", -- 改成深度搜索
    },
}

--===================================
-- 电闸检测（基于电闸对象变化）
--===================================
local powerOutageCooldown = 0
local powerMonitored = {}

local PowerNames = {"FuseBox", "PowerBox", "MainAnchor", "Buttons", "Breaker", "ElectricPanel"}

local function MonitorPowerBox(powerBox)
    if powerMonitored[powerBox] then return end
    powerMonitored[powerBox] = true

    local function onPowerChange()
        local now = tick()
        if now - powerOutageCooldown > 15 then
            powerOutageCooldown = now
            NotifyWithCooldown(
                "poweroutage",
                "⚡ 鬼已把电闸拉上",
                "你暂时无法开灯，请找到电闸所在位置并开启",
                "Power Outage",
                15,
                5
            )
        end
    end

    pcall(function()
        powerBox:GetPropertyChangedSignal("Transparency"):Connect(onPowerChange)
    end)
    pcall(function()
        powerBox:GetPropertyChangedSignal("Color"):Connect(onPowerChange)
    end)
    pcall(function()
        powerBox:GetPropertyChangedSignal("CanCollide"):Connect(onPowerChange)
    end)

    powerBox.DescendantAdded:Connect(function(desc)
        if desc:IsA("ClickDetector") or desc:IsA("ProximityPrompt") or desc:IsA("SurfaceGui") then
            onPowerChange()
        end
    end)
end

local function FindAndMonitorPowerBoxes()
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("Model") or desc:IsA("Part") then
            for _, name in ipairs(PowerNames) do
                if desc.Name == name then
                    MonitorPowerBox(desc)
                    break
                end
            end
        end
    end
end

FindAndMonitorPowerBoxes()

workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("Model") or desc:IsA("Part") then
        for _, name in ipairs(PowerNames) do
            if desc.Name == name then
                MonitorPowerBox(desc)
                break
            end
        end
    end
end)

-- 在多个常见位置搜索指定名称的Sound
local function FindInSoundsFolder(name)
    local results = {}

    -- 1. PlayerScripts.Sounds（运行时）
    local ps = LocalPlayer:FindFirstChild("PlayerScripts")
    if ps then
        local sf = ps:FindFirstChild("Sounds")
        if sf then
            local s = sf:FindFirstChild(name)
            if s and s:IsA("Sound") then table.insert(results, s) end
        end
        -- PlayerScripts 下所有子级搜一遍（不深入，避免卡）
        for _, child in ipairs(ps:GetChildren()) do
            if child:IsA("Sound") and child.Name == name then
                table.insert(results, child)
            elseif child:IsA("Folder") or child:IsA("Model") then
                local s2 = child:FindFirstChild(name)
                if s2 and s2:IsA("Sound") then table.insert(results, s2) end
            end
        end
    end

    -- 2. StarterPlayerScripts.Sounds（模板）
    local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
    if sps then
        local sf = sps:FindFirstChild("Sounds")
        if sf then
            local s = sf:FindFirstChild(name)
            if s and s:IsA("Sound") then table.insert(results, s) end
        end
        -- StarterPlayerScripts 下所有子级搜一遍
        for _, child in ipairs(sps:GetChildren()) do
            if child:IsA("Sound") and child.Name == name then
                table.insert(results, child)
            elseif child:IsA("Folder") or child:IsA("Model") then
                local s2 = child:FindFirstChild(name)
                if s2 and s2:IsA("Sound") then table.insert(results, s2) end
            end
        end
    end

    -- 3. ReplicatedStorage
    local rs = game:GetService("ReplicatedStorage")
    if rs then
        for _, child in ipairs(rs:GetChildren()) do
            if child:IsA("Sound") and child.Name == name then
                table.insert(results, child)
            elseif child:IsA("Folder") or child:IsA("Model") then
                local s2 = child:FindFirstChild(name)
                if s2 and s2:IsA("Sound") then table.insert(results, s2) end
            end
        end
    end

    -- 4. SoundService
    local ss = game:GetService("SoundService")
    if ss then
        for _, child in ipairs(ss:GetChildren()) do
            if child:IsA("Sound") and child.Name == name then
                table.insert(results, child)
            elseif child:IsA("Folder") or child:IsA("Model") then
                local s2 = child:FindFirstChild(name)
                if s2 and s2:IsA("Sound") then table.insert(results, s2) end
            end
        end
    end

    -- 5. StarterGui / PlayerGui
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _, child in ipairs(pg:GetChildren()) do
            if child:IsA("Sound") and child.Name == name then
                table.insert(results, child)
            end
        end
    end

    return results
end

-- 启动时做一次全游戏深度搜索（只执行一次，不影响持续性能）
local function DeepSearchOnce(name)
    local results = {}
    -- 只遍历客户端可访问的服务
    local services = {
        game:GetService("ReplicatedStorage"),
        game:GetService("SoundService"),
        game:GetService("StarterPack"),
        game:GetService("StarterGui"),
        game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"),
        LocalPlayer:FindFirstChild("PlayerScripts"),
        LocalPlayer:FindFirstChild("PlayerGui"),
    }
    for _, svc in ipairs(services) do
        if svc then
            pcall(function()
                for _, desc in ipairs(svc:GetDescendants()) do
                    if desc:IsA("Sound") and desc.Name == name then
                        table.insert(results, desc)
                    end
                end
            end)
        end
    end
    return results
end

-- 在 Ghost.Head 中搜索
local function FindInGhostHead(name)
    local results = {}
    local ghost = workspace:FindFirstChild("Ghost")
    if ghost then
        local head = ghost:FindFirstChild("Head")
        if head then
            local s = head:FindFirstChild(name)
            if s and s:IsA("Sound") then table.insert(results, s) end
        end
    end
    return results
end

-- 深度搜索是否已执行过（记录时间，定期重新扫描）
local deepSearchLastTime = {}

local function HookAudioEvent(eventCfg)
    local sounds = {}
    if eventCfg.searchIn == "GhostHead" then
        sounds = FindInGhostHead(eventCfg.soundName)
    elseif eventCfg.searchIn == "Sounds" then
        sounds = FindInSoundsFolder(eventCfg.soundName)
    elseif eventCfg.searchIn == "Deep" then
        -- 先快速搜常见位置
        sounds = FindInSoundsFolder(eventCfg.soundName)
        -- 找不到或超过10秒没做过深度搜索，做一次全游戏深度搜索
        local now = tick()
        if #sounds == 0 or not deepSearchLastTime[eventCfg.name] or (now - deepSearchLastTime[eventCfg.name]) > 10 then
            deepSearchLastTime[eventCfg.name] = now
            local deepResults = DeepSearchOnce(eventCfg.soundName)
            for _, s in ipairs(deepResults) do
                local found = false
                for _, r in ipairs(sounds) do
                    if r == s then found = true break end
                end
                if not found then table.insert(sounds, s) end
            end
        end
    end
    if #sounds == 0 then return false end

    for _, sound in ipairs(sounds) do
        HookOneSound(sound, function()
            -- 如果需要暗度验证（电闸事件），检查 Lighting.Brightness 是否较低
            if eventCfg.requireDarkness then
                local brightness = Lighting.Brightness
                -- 停电时亮度通常会大幅下降
                if brightness > 1.5 then
                    -- 亮度正常，不是停电，跳过通知
                    return
                end
            end

            NotifyWithCooldown(
                eventCfg.name,
                eventCfg.title,
                eventCfg.content,
                eventCfg.subContent,
                eventCfg.cooldown,
                4
            )
        end)
    end
    return true
end

-- 持续尝试监听 + 监听新生成的Sound
task.spawn(function()
    -- 初始深度扫描（启动时做一次）
    for _, event in ipairs(AudioEvents) do
        HookAudioEvent(event)
    end

    -- 监听各服务的新Sound（动态捕捉）
    local function MonitorService(service)
        if not service then return end
        service.DescendantAdded:Connect(function(desc)
            if desc:IsA("Sound") then
                for _, event in ipairs(AudioEvents) do
                    if desc.Name == event.soundName then
                        HookOneSound(desc, function()
                            -- 如果需要暗度验证（电闸事件）
                            if event.requireDarkness then
                                if Lighting.Brightness > 1.5 then
                                    return
                                end
                            end

                            NotifyWithCooldown(
                                event.name,
                                event.title,
                                event.content,
                                event.subContent,
                                event.cooldown,
                                4
                            )
                        end)
                    end
                end
            end
        end)
    end

    MonitorService(LocalPlayer:FindFirstChild("PlayerScripts"))
    MonitorService(game:GetService("ReplicatedStorage"))
    MonitorService(game:GetService("SoundService"))
    MonitorService(game:GetService("StarterGui"))
    MonitorService(workspace)

    -- PlayerScripts 可能还没加载，等一下再监听
    task.wait(2)
    MonitorService(LocalPlayer:FindFirstChild("PlayerScripts"))

    -- 之后每30秒做一次快速搜索（兜底，不做深度搜索避免卡顿）
    while true do
        task.wait(30)
        for _, event in ipairs(AudioEvents) do
            -- 只做快速搜索，不做深度搜索
            local sounds = FindInSoundsFolder(event.soundName)
            for _, sound in ipairs(sounds) do
                HookOneSound(sound, function()
                    NotifyWithCooldown(
                        event.name,
                        event.title,
                        event.content,
                        event.subContent,
                        event.cooldown,
                        4
                    )
                end)
            end
        end
    end
end)

workspace.ChildAdded:Connect(function(child)
    if child.Name == "Ghost" then
        task.wait(0.5)
        local ghost = workspace:FindFirstChild("Ghost")
        if ghost then
            ghost.DescendantAdded:Connect(function(desc)
                if desc:IsA("Sound") then
                    if desc.Name == "Hunt" then
                        NotifyWithCooldown(
                            "hunt",
                            "⚠ 猎杀警告",
                            "鬼开始猎杀了！快躲起来！",
                            "Ghost.Hunt",
                            12,
                            4
                        )
                        if huntNotifFrame then
                            huntNotifFrame.Visible = true
                            local blinkCount = 0
                            task.spawn(function()
                                while blinkCount < 24 and huntNotifFrame and huntNotifFrame.Visible do
                                    huntNotifFrame.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                                    task.wait(0.25)
                                    blinkCount = blinkCount + 1
                                    if not huntNotifFrame or not huntNotifFrame.Visible then break end
                                    huntNotifFrame.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
                                    task.wait(0.25)
                                    blinkCount = blinkCount + 1
                                end
                                if huntNotifFrame then
                                    huntNotifFrame.Visible = false
                                end
                            end)
                        end
                    elseif desc.Name == "Scream" or desc.Name == "BoneBreak" then
                        NotifyWithCooldown(
                            "death",
                            "☠ 死亡警告",
                            "有人被鬼杀死了！",
                            "Ghost." .. desc.Name,
                            5,
                            4
                        )
                    end
                end
            end)
        end
    end
end)


local huntAlertLabel = nil

local huntNotifFrame = nil

local function SetupHuntAlert()
    if huntNotifFrame then return end

    huntNotifFrame = Instance.new("Frame")
    huntNotifFrame.Name = "HuntNotification"
    huntNotifFrame.Size = UDim2.new(0, 380, 0, 50)
    huntNotifFrame.Position = UDim2.new(1, -410, 0, 20)
    huntNotifFrame.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
    huntNotifFrame.BackgroundTransparency = 0.15
    huntNotifFrame.BorderSizePixel = 0
    huntNotifFrame.Visible = false
    huntNotifFrame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = huntNotifFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 80, 80)
    stroke.Thickness = 2
    stroke.Parent = huntNotifFrame

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 36, 1, 0)
    icon.Position = UDim2.new(0, 10, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "⚠"
    icon.TextColor3 = Color3.fromRGB(255, 100, 100)
    icon.Font = Enum.Font.GothamBold
    icon.TextSize = 24
    icon.Parent = huntNotifFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -50, 1, 0)
    title.Position = UDim2.new(0, 46, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "鬼正在猎杀！快躲起来！"
    title.TextColor3 = Color3.fromRGB(255, 220, 220)
    title.TextStrokeColor3 = Color3.new(0, 0, 0)
    title.TextStrokeTransparency = 0.5
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.Parent = huntNotifFrame

    huntAlertLabel = huntNotifFrame
end

local function StartHuntAlert()
    if huntAlertConn then return end
    SetupHuntAlert()

    local huntBlinking = false

    -- 猎杀相关声音关键词（叹气/预警/咆哮/猎杀等，不含scream避免和死亡音效冲突）
    local HuntSoundKeywords = {
        "hunt", "chase", "kill", "attack", "warning", "alert",
        "breath", "breathe", "sigh", "roar", "growl",
        "screech", "howl", "snarl", "hiss", "angry", "rage",
        "stalk", "hunting", "ambush",
    }

    local function IsHuntSound(name)
        local lower = name:lower()
        for _, kw in ipairs(HuntSoundKeywords) do
            if lower:find(kw) then return true end
        end
        return false
    end

    local huntCooldown = 0

    local function onHuntTrigger(soundName)
        if not Configuration.HuntAlert then return end
        local now = tick()
        if now - huntCooldown < 12 then return end -- 12秒冷却
        huntCooldown = now

        -- Fluent通知
        FluentNotify(
            "⚠ 猎杀警告",
            "鬼开始猎杀了！快躲起来！",
            soundName or "Hunt",
            4
        )

        -- 常驻闪烁提示
        if not huntBlinking then
            huntBlinking = true
            huntNotifFrame.Visible = true
            task.spawn(function()
                for i = 1, 24 do
                    if not huntNotifFrame.Visible then break end
                    huntNotifFrame.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                    task.wait(0.25)
                    if not huntNotifFrame.Visible then break end
                    huntNotifFrame.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
                    task.wait(0.25)
                end
                huntNotifFrame.Visible = false
                huntBlinking = false
            end)
        end
    end

    local function onHuntEnd()
        huntNotifFrame.Visible = false
        huntBlinking = false
    end

    local hookedHuntSounds = {}

    local function HookSound(sound)
        if not sound or not sound:IsA("Sound") then return end
        if hookedHuntSounds[sound] then return end
        if not IsHuntSound(sound.Name) then return end
        hookedHuntSounds[sound] = true

        sound:GetPropertyChangedSignal("Playing"):Connect(function()
            if sound.IsPlaying then
                onHuntTrigger(sound.Name)
            else
                onHuntEnd()
            end
        end)

        if sound.IsPlaying then
            onHuntTrigger(sound.Name)
        end
    end

    local function MonitorGhost()
        local ghost = workspace:FindFirstChild("Ghost")
        if not ghost then return end

        for _, desc in ipairs(ghost:GetDescendants()) do
            HookSound(desc)
        end

        ghost.DescendantAdded:Connect(function(desc)
            HookSound(desc)
        end)
    end

    -- 初始扫描一次
    MonitorGhost()

    -- Ghost出现时监听
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "Ghost" then
            task.wait(0.3)
            MonitorGhost()
        end
    end)

    -- RemoteEvent监听（可能游戏用远程事件触发猎杀）
    pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        for _, child in ipairs(rs:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                if child.Name:lower():find("hunt") or child.Name:lower():find("chase") then
                    child.OnClientEvent:Connect(function(...)
                        onHuntTrigger(child.Name)
                    end)
                end
            end
        end
    end)

    huntAlertConn = workspace.ChildAdded:Connect(function() end)
end

local function StopHuntAlert()
    if huntAlertConn then
        huntAlertConn:Disconnect()
        huntAlertConn = nil
    end
    if huntNotifFrame then
        huntNotifFrame.Visible = false
    end
end

--===================================
-- Fluent UI 界面
--===================================

local UISettings = {
        TabWidth = IsMobile and 100 or 160,
        Size = IsMobile and { 420, 360 } or { 580, 460 },
        Theme = "Amethyst",
        Acrylic = false,
        Transparency = true,
        MinimizeKey = IsMobile and "Button" or "RightShift",
        ShowNotifications = true,
        ShowWarnings = true
    }

    local InterfaceManager = {}

    function InterfaceManager:ImportSettings()
        pcall(function()
            if getfenv().isfile and getfenv().readfile and getfenv().isfile("DemonologyUISettings.ttwizz") and getfenv().readfile("DemonologyUISettings.ttwizz") then
                for Key, Value in next, HttpService:JSONDecode(getfenv().readfile("DemonologyUISettings.ttwizz")) do
                    UISettings[Key] = Value
                end
            end
        end)
    end

    function InterfaceManager:ExportSettings()
        pcall(function()
            if getfenv().isfile and getfenv().readfile and getfenv().writefile then
                getfenv().writefile("DemonologyUISettings.ttwizz", HttpService:JSONEncode(UISettings))
            end
        end)
    end

    InterfaceManager:ImportSettings()
    UISettings.__LAST_RUN__ = os.date()
    InterfaceManager:ExportSettings()

    do
        local Window = Fluent:CreateWindow({
            Title = "恶魔学辅助",
            SubTitle = "透视 | 速度 | 夜视 | 猎杀提醒",
            TabWidth = UISettings.TabWidth,
            Size = UDim2.fromOffset(table.unpack(UISettings.Size)),
            Theme = UISettings.Theme,
            Acrylic = UISettings.Acrylic,
            MinimizeKey = UISettings.MinimizeKey
        })

    local Tabs = {}

    Tabs.ESP = Window:AddTab({ Title = "ESP", Icon = "layers" })

    Tabs.ESP:AddParagraph({
        Title = "ESP 透视",
        Content = "自动识别并绘制躲藏点、电闸、鬼、物品等"
    })

    local ESPSection = Tabs.ESP:AddSection("ESP 开关")

    ESPSection:AddToggle("HidingSpotsToggle", {
        Title = "躲藏点",
        Description = "显示躲藏位置",
        Default = Configuration.ESP.HidingSpots,
        Callback = function(Value)
            Configuration.ESP.HidingSpots = Value
            RefreshESP()
        end
    })

    ESPSection:AddToggle("SwitchesToggle", {
        Title = "电闸",
        Description = "显示电闸位置",
        Default = Configuration.ESP.Switches,
        Callback = function(Value)
            Configuration.ESP.Switches = Value
            RefreshESP()
        end
    })

    ESPSection:AddToggle("GhostsToggle", {
        Title = "鬼",
        Description = "显示鬼的轮廓",
        Default = Configuration.ESP.Ghosts,
        Callback = function(Value)
            Configuration.ESP.Ghosts = Value
            RefreshESP()
        end
    })

    ESPSection:AddToggle("NormalItemsToggle", {
        Title = "普通物品",
        Description = "显示普通道具",
        Default = Configuration.ESP.NormalItems,
        Callback = function(Value)
            Configuration.ESP.NormalItems = Value
            RefreshESP()
        end
    })

    ESPSection:AddToggle("CursedItemsToggle", {
        Title = "诅咒物品",
        Description = "显示诅咒道具",
        Default = Configuration.ESP.CursedItems,
        Callback = function(Value)
            Configuration.ESP.CursedItems = Value
            RefreshESP()
        end
    })

    ESPSection:AddToggle("GhostRoomToggle", {
        Title = "鬼房",
        Description = "显示鬼所在房间",
        Default = Configuration.ESP.GhostRoom,
        Callback = function(Value)
            Configuration.ESP.GhostRoom = Value
            RefreshESP()
        end
    })

    ESPSection:AddToggle("SaltToggle", {
        Title = "盐",
        Description = "显示盐堆",
        Default = Configuration.ESP.Salt,
        Callback = function(Value)
            Configuration.ESP.Salt = Value
            RefreshESP()
        end
    })

    Tabs.Speed = Window:AddTab({ Title = "速度", Icon = "zap" })

    Tabs.Speed:AddParagraph({
        Title = "移动速度",
        Content = "调整角色移动速度"
    })

    local SpeedSection = Tabs.Speed:AddSection("速度设置")

    SpeedSection:AddToggle("SpeedToggle", {
        Title = "启用速度",
        Description = "开启自定义速度",
        Default = Configuration.Speed.Enabled,
        Callback = function(Value)
            Configuration.Speed.Enabled = Value
            if Value then
                StartSpeedLoop()
            else
                StopSpeedLoop()
            end
        end
    })

    SpeedSection:AddSlider("SpeedSlider", {
        Title = "速度值",
        Description = "设置移动速度",
        Default = Configuration.Speed.Value,
        Min = 8,
        Max = 100,
        Rounding = 1,
        Callback = function(Value)
            Configuration.Speed.Value = Value
        end
    })

    Tabs.Vision = Window:AddTab({ Title = "视觉", Icon = "eye" })

    Tabs.Vision:AddParagraph({
        Title = "视觉效果",
        Content = "夜视和猎杀提醒"
    })

    local VisionSection = Tabs.Vision:AddSection("夜视")

    VisionSection:AddToggle("NightVisionToggle", {
        Title = "夜视",
        Description = "提高亮度，去除黑暗",
        Default = Configuration.NightVision,
        Callback = function(Value)
            Configuration.NightVision = Value
            SetNightVision(Value)
        end
    })

    local AlertSection = Tabs.Vision:AddSection("猎杀提醒")

    AlertSection:AddToggle("HuntAlertToggle", {
        Title = "猎杀提醒",
        Description = "鬼开始猎杀时显示警告",
        Default = Configuration.HuntAlert,
        Callback = function(Value)
            Configuration.HuntAlert = Value
            if Value then
                StartHuntAlert()
            else
                StopHuntAlert()
            end
        end
    })

    Tabs.Settings = Window:AddTab({ Title = "设置", Icon = "settings" })

    Tabs.Settings:AddParagraph({
        Title = "界面设置",
        Content = "调整 UI 外观和行为"
    })

    local UISection = Tabs.Settings:AddSection("UI")

    UISection:AddDropdown("ThemeDropdown", {
        Title = "主题",
        Description = "更改 UI 主题",
        Values = Fluent.Themes,
        Default = Fluent.Theme,
        Callback = function(Value)
            Fluent:SetTheme(Value)
            UISettings.Theme = Value
            InterfaceManager:ExportSettings()
        end
    })

    if Fluent.UseAcrylic then
        UISection:AddToggle("AcrylicToggle", {
            Title = "亚克力效果",
            Description = "模糊背景，需要画质 >= 8",
            Default = Fluent.Acrylic,
            Callback = function(Value)
                if not Value or not UISettings.ShowWarnings then
                    Fluent:ToggleAcrylic(Value)
                elseif UISettings.ShowWarnings then
                    Window:Dialog({
                        Title = "警告",
                        Content = "此选项可能被检测！确定启用？",
                        Buttons = {
                            {
                                Title = "确认",
                                Callback = function()
                                    Fluent:ToggleAcrylic(Value)
                                end
                            },
                            {
                                Title = "取消",
                                Callback = function()
                                    Fluent.Options.AcrylicToggle:SetValue(false)
                                end
                            }
                        }
                    })
                end
            end
        })
    end

    UISection:AddToggle("TransparencyToggle", {
        Title = "透明度",
        Description = "使 UI 透明",
        Default = UISettings.Transparency,
        Callback = function(Value)
            Fluent:ToggleTransparency(Value)
            UISettings.Transparency = Value
            InterfaceManager:ExportSettings()
        end
    })

    UISection:AddKeybind("MinimizeKeybind", {
        Title = "切换键",
        Description = "切换 UI 显示/隐藏",
        Default = Fluent.MinimizeKey,
        ChangedCallback = function(Value)
            UISettings.MinimizeKey = Value ~= Enum.UserInputType.MouseButton2 and UserInputService:GetStringForKeyCode(Value) or "RMB"
            InterfaceManager:ExportSettings()
        end
    })
    Fluent.MinimizeKeybind = Fluent.Options.MinimizeKeybind

    Window:SelectTab(1)

    local function Notify(Message)
        if Fluent and typeof(Message) == "string" then
            Fluent:Notify({
                Title = "恶魔学辅助",
                Content = Message,
                Duration = 1.5
            })
        end
    end

    Notify("脚本加载完成！")

    -- 移动端按钮绑定切换GUI
    if IsMobile and MobileToggleBtn then
        MobileToggleBtn.MouseButton1Click:Connect(function()
            Fluent:Toggle()
        end)
    end
end

--===================================
-- 初始化
--===================================
task.wait(1)
RefreshESP()
if Configuration.HuntAlert then
    StartHuntAlert()
end

--===================================
-- 物品选中与信息打印系统
--===================================
local Mouse = LocalPlayer:GetMouse()
local SelectedItem = nil
local UIS = game:GetService("UserInputService")

local function GetFullPath(obj)
    local path = {}
    local cur = obj
    while cur and cur ~= game do
        table.insert(path, 1, cur.Name)
        cur = cur.Parent
    end
    return "game." .. table.concat(path, ".")
end

local function GetItemFromPart(part)
    if not part then return nil end
    -- 先找 Items 文件夹里的父级
    local items = workspace:FindFirstChild("Items")
    if items then
        local cur = part
        while cur and cur ~= workspace do
            if cur.Parent == items then
                return cur
            end
            cur = cur.Parent
        end
    end
    -- 如果不在Items里，返回鼠标指向的最顶层Model/Part
    local cur = part
    while cur and cur.Parent and cur.Parent ~= workspace do
        cur = cur.Parent
    end
    return cur
end

local function SelectItem()
    local target = Mouse.Target
    if not target then
        SelectedItem = nil
        print("[选中] 未指向任何对象")
        return
    end
    local item = GetItemFromPart(target)
    SelectedItem = item
    if item then
        print("[选中] " .. item.Name .. "  (路径: " .. GetFullPath(item) .. ")")
    else
        print("[选中] " .. target.Name)
    end
end

local function PrintSelectedInfo()
    if not SelectedItem then
        print("[打印] 没有选中的物品，先指向物品再按P选中")
        return
    end
    print("========== 选中物品信息 ==========")
    print("名称: " .. SelectedItem.Name)
    print("路径: " .. GetFullPath(SelectedItem))
    print("类型: " .. SelectedItem.ClassName)
    print("位置: " .. tostring(SelectedItem:GetPivot().Position))
    print("子对象:")
    for _, child in ipairs(SelectedItem:GetChildren()) do
        print("  - " .. child.Name .. "  (" .. child.ClassName .. ")")
    end
    print("==================================")
end

local function ShowDexPath()
    if not SelectedItem then
        print("[DEX] 没有选中的物品")
        return
    end
    local path = GetFullPath(SelectedItem)
    print("[DEX路径] " .. path)
    -- 复制到剪贴板（如果可用）
    pcall(function()
        setclipboard(path)
        print("[DEX路径] 已复制到剪贴板")
    end)
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.P then
        SelectItem()
        PrintSelectedInfo()
    elseif input.KeyCode == Enum.KeyCode.F9 then
        ShowDexPath()
    end
end)

local char = LocalPlayer.Character
if char then
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 16
        print("[Demonology] 初始速度已重置为 16")
    end
end

print("[Demonology] 加载完成")
print("  RightShift = 切换GUI")
print("  P键 = 选中鼠标指向的物品并打印信息")
print("  F9键 = 查看选中物品的DEX路径")