--[[
    Demonology Script - Fluent UI Edition  (10/10 Final Build)
    ESP + Speed + NightVision + HuntAlert + Task Panel + Special Items
    RightShift 切换GUI  |  P键选中物品  |  F9复制路径
]]

local HttpService     = game:GetService("HttpService")
local Players         = game:GetService("Players")
local UserInputService= game:GetService("UserInputService")
local RunService      = game:GetService("RunService")
local CoreGui        = game:GetService("CoreGui")
local Lighting       = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris         = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

-- 移动端检测
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

--===================================
-- 全局状态
--===================================
local Connections  = {}      -- 所有连接，便于卸载
local CleanupFns  = {}      -- 所有清理函数
local ESPObjects  = {}       -- [object] = espData
local ESPDirty    = false    -- 增量刷新标记
local DetectedGhostRoom = nil
local CachedGhostRoom  = nil
local LastGhostPos     = Vector3.zero
local huntAlertConn    = nil
local speedConn        = nil
local nightVisionConn  = nil
local huntNotifFrame   = nil
local huntBlinking     = false
local eventCooldowns   = {}
local hookedSounds     = {}
local powerMonitored   = {}
local TaskManualState  = {}
local energyObj        = nil
local energyType       = nil
local energySearched   = false
local SelectedItem     = nil
local deepSearchLastTime = {}

--===================================
-- 自动ESP配置
--===================================
local AutoESP = {
    HidingSpots = { "Kitchen_Closet","GhostCloset","HallCloset","Closet","Locker","HidingSpot" },
    Switches    = { "FuseBox","Buttons","MainAnchor","PowerBox" },
    Ghosts      = { "Ghost" },
    Blacklist   = { "Cobblestone","Path","Road","Ground","Floor","Wall","Roof","Door","Window",
                     "Stairs","Map","Exterior","Interior","House","Room","Lobby","Spawn" },
}

local ItemNames = {
    ["1"]="摄像机",["2"]="温度计",["3"]="书",["4"]="黑光",["5"]="通灵盒子",
    ["6"]="EMF读卡器",["7"]="手电筒",["8"]="激光投影仪",["9"]="花",
    ["10"]="能量手表",["11"]="能量饮料",["12"]="盐",["13"]="打火机",["100"]="好运币",
}

-- 特殊物品（油灯 / 油 / 花）—— 路径精确匹配
local SpecialItems = {
    { path = "Items.10.MeshPart",  name = "油灯", color = Color3.fromRGB(255,180,50)  },
    { path = "Items.11.Decal",     name = "油",   color = Color3.fromRGB(200,200,50)  },
    { path = "Items.12.Planter_V2",name = "花",   color = Color3.fromRGB(255,105,180) },
}

--===================================
-- 配置
--===================================
local Configuration = {
    ESP = {
        HidingSpots = true, Switches = true, Ghosts = true,
        NormalItems = true, CursedItems = true, GhostRoom = true, Salt = true,
    },
    NightVision = false,
    HuntAlert   = true,
    Speed = { Enabled = false, Value = 16 },
}

--===================================
-- 工具函数
--===================================
local function SafeFindByPath(root, pathStr)
    local obj = root
    for part in pathStr:gmatch("[^%.]+") do
        obj = obj and obj:FindFirstChild(part)
    end
    return obj
end

local function Register(conn) table.insert(Connections, conn) end
local function AddCleanup(fn) table.insert(CleanupFns, fn) end

--===================================
-- Fluent UI 加载
--===================================
local Fluent = nil
local FluentUrls = {
    "https://twix.cyou/Fluent.txt",
    "https://ttwizz.pages.dev/Fluent.txt",
    "https://raw.githubusercontent.com/dawid-scripts/Fluent/main/Fluent.lua",
    "https://raw.githubusercontent.com/ttwizz/Fluent/main/Fluent.lua",
    "https://cdn.jsdelivr.net/gh/dawid-scripts/Fluent@main/Fluent.lua",
    "https://fastly.jsdelivr.net/gh/dawid-scripts/Fluent@main/Fluent.lua",
}

if typeof(script)=="Instance" and script:FindFirstChild("Fluent") and script:FindFirstChild("Fluent"):IsA("ModuleScript") then
    Fluent = require(script:FindFirstChild("Fluent"))
else
    for _,url in ipairs(FluentUrls) do
        local ok,res = pcall(function() return game:HttpGet(url,true) end)
        if ok and typeof(res)=="string" and res:find("dawid") then
            Fluent = getfenv().loadstring(res)()
            break
        end
    end
    if not Fluent then error("无法加载 Fluent UI，请检查网络") end
end

--===================================
-- ScreenGui
--===================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DemonologyGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

if IsMobile then
    local btn = Instance.new("TextButton")
    btn.Name = "MobileToggle"
    btn.Size = UDim2.new(0,50,0,50)
    btn.Position = UDim2.new(1,-65,0.5,-25)
    btn.BackgroundColor3 = Color3.fromRGB(40,40,60)
    btn.BackgroundTransparency = 0.3
    btn.Text = "👻"
    btn.TextSize = 24
    btn.TextColor3 = Color3.new(1,1,1)
    btn.AutoButtonColor = true
    btn.Draggable = true
    btn.Parent = ScreenGui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = btn
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(100,100,150); s.Thickness=2; s.Parent=btn
end

--===================================
-- ESP 系统
--===================================
local function RemoveESP(obj)
    if not ESPObjects[obj] then return end
    local d = ESPObjects[obj]
    if d.highlight      then d.highlight:Destroy() end
    if d.highlights then for _,h in pairs(d.highlights) do pcall(h.Destroy,h) end end
    if d.billboard      then d.billboard:Destroy() end
    if d.box           then d.box:Destroy() end
    if d.boxes then for _,b in pairs(d.boxes) do pcall(b.Destroy,b) end end
    if d.conns then for _,c in ipairs(d.conns) do pcall(c.Disconnect,c) end end
    if d.circleBillboard  then d.circleBillboard:Destroy() end
    if d.labelBillboard   then d.labelBillboard:Destroy() end
    if d.glowBillboard    then d.glowBillboard:Destroy() end
    ESPObjects[obj] = nil
end

local function MakeLabel(adornee, text, color, yOff, size)
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_Label"
    bb.Size = UDim2.new(0, size or 200, 0, 30)
    bb.StudsOffset = Vector3.new(0, yOff or 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Adornee = adornee
    bb.Parent   = adornee
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color
    lbl.TextStrokeColor3 = Color3.new(0,0,0)
    lbl.TextStrokeTransparency = 0
    lbl.Text = text
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.Parent = bb
    return bb
end

local function CreateESP(obj, name, color)
    if ESPObjects[obj] then return end
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_Highlight"
    hl.FillColor = color; hl.FillTransparency = 0.6
    hl.OutlineColor = Color3.new(1,1,1); hl.OutlineTransparency = 0
    hl.Adornee = obj; hl.Parent = obj
    local bb = MakeLabel(obj, name, color)
    ESPObjects[obj] = { highlight = hl, billboard = bb }
end

local function CreateFloorESP(obj, name, color)
    if ESPObjects[obj] then return end
    local data = { highlights = {} }
    local floorKW = {"floor","ground","carpet","rug","tile"}
    local function IsFloor(p)
        if not p:IsA("BasePart") then return false end
        local n = p.Name:lower()
        for _,kw in ipairs(floorKW) do if n:find(kw) then return true end end
        if p.Size.Y < 2 and p.Size.X > 3 and p.Size.Z > 3 then return true end
        return false
    end
    for _,d in ipairs(obj:GetDescendants()) do
        if IsFloor(d) and not data.highlights[d] then
            local h = Instance.new("Highlight")
            h.Name = "FloorESP_Highlight"
            h.FillColor = color; h.FillTransparency = 0.5
            h.OutlineColor = Color3.new(1,1,1); h.OutlineTransparency = 0
            h.Adornee = d; h.Parent = d
            data.highlights[d] = h
        end
    end
    if not next(data.highlights) then
        local h = Instance.new("Highlight")
        h.Name = "ESP_Highlight"
        h.FillColor = color; h.FillTransparency = 0.6
        h.OutlineColor = Color3.new(1,1,1); h.OutlineTransparency = 0
        h.Adornee = obj; h.Parent = obj
        data.highlights[obj] = h
    end
    local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    if pp then data.billboard = MakeLabel(pp, name, color) end
    ESPObjects[obj] = data
end

local function CreateGhostESP(obj)
    if ESPObjects[obj] then return end
    local data = { boxes = {}, conns = {} }
    local bodyKW = {"head","torso","arm","leg","hand","foot"}
    local function AddBox(p)
        if not p:IsA("BasePart") or data.boxes[p] then return end
        local n = p.Name:lower(); local ok = false
        for _,kw in ipairs(bodyKW) do if n:find(kw) then ok=true break end end
        if not ok then return end
        local b = Instance.new("BoxHandleAdornment")
        b.Name = "GhostESP_Box"; b.Adornee = p; b.AlwaysOnTop = true
        b.Color3 = Color3.fromRGB(255,0,0); b.Transparency = 0.7
        b.Size = p.Size; b.ZIndex = 10; b.Parent = p
        data.boxes[p] = b
    end
    for _,d in ipairs(obj:GetDescendants()) do AddBox(d) end
    table.insert(data.conns, obj.DescendantAdded:Connect(AddBox))
    table.insert(data.conns, obj.DescendantRemoving:Connect(function(p)
        if data.boxes[p] then data.boxes[p]:Destroy(); data.boxes[p]=nil end
    end))
    local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
    data.billboard = MakeLabel(root or obj, "[鬼] "..obj.Name, Color3.new(1,1,1), 3, 200)
    ESPObjects[obj] = data
end

local function NameInList(name, list)
    local lower = name:lower()
    for _,b in ipairs(AutoESP.Blacklist) do if lower:find(b:lower()) then return false end end
    for _,n in ipairs(list) do if lower==n:lower() then return true end end
    return false
end

local RoomKeywords = {
    "bedroom","livingroom","kitchen","bathroom","hallway","attic","basement",
    "garage","diningroom","masterbedroom","guestroom","office","storage","foyer",
    "stairs","landing","laundryroom","nursery","playroom","sunroom","pantry",
    "hall","den","study","library","room","closet","closets",
}

local function IsRoomModel(name)
    local n = name:lower()
    for _,kw in ipairs(RoomKeywords) do if n:find(kw) then return true end end
    return false
end

local function FindGhostRoom()
    local ghostPos = nil
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and NameInList(obj.Name, AutoESP.Ghosts) then
            local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if p then ghostPos = p.Position break end
        end
    end
    if not ghostPos then return nil end
    local minD,closest = math.huge,nil
    for _,obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and IsRoomModel(obj.Name) then
            local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if p then
                local d = (p.Position - ghostPos).Magnitude
                if d < minD then minD=d; closest=obj end
            end
        end
    end
    return closest
end

-- 物品识别
local function IdentifyItem(item)
    local num = tonumber(item.Name)
    if num and num>=1 and num<=9 then
        return ItemNames[item.Name] or "物品", false
    elseif item:FindFirstChild("Magnifying Glass") then return "诅咒道具放大镜", true
    elseif item:FindFirstChild("Meshes/Canobj")   then return "盐", false
    elseif item:FindFirstChild("Base")            then return "能量饮料", false
    elseif item:FindFirstChild("Color")           then return "打火机", false
    elseif item:FindFirstChild("Red Teddy Bear")  then return "小熊娃娃", false
    elseif item:FindFirstChild("Screen")          then return "能量手表", false
    elseif item:FindFirstChild("Main") then
        if num and num==100 then return "Umbra板", true else return "物品", false end
    elseif item:FindFirstChild("mirror.002")      then return "鬼魅镜", true
    elseif item:FindFirstChild("Meshes/Frame (1)") then return "音乐盒子", true
    else return "物品", false end
end

-- 特殊物品 ESP（油灯 / 油 / 花）
local function RefreshSpecialItemsESP()
    for _,info in ipairs(SpecialItems) do
        local obj = SafeFindByPath(workspace, info.path)
        if not obj then continue end
        if ESPObjects[obj] then continue end

        local adornee = obj
        if obj:IsA("Decal") then
            adornee = obj.Parent
            if not adornee or not adornee:IsA("BasePart") then continue end
        end

        local hl = Instance.new("Highlight")
        hl.Name = "SpecialItemESP"
        hl.Adornee = adornee
        hl.FillColor = info.color
        hl.FillTransparency = 0.55
        hl.OutlineColor = Color3.new(1,1,1)
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = adornee

        local bb = MakeLabel(adornee, "[物品] "..info.name, info.color, 2, 160)

        ESPObjects[obj] = { highlight = hl, billboard = bb }
    end
end

-- 主 ESP 刷新（增量驱动，不再死循环全扫）
local function RefreshESP()
    -- 清除失效引用
    for obj in pairs(ESPObjects) do
        if not obj or not obj.Parent then RemoveESP(obj) end
    end

    -- 扫描 Models
    for _,obj in ipairs(workspace:GetDescendants()) do
        if not obj:IsA("Model") then continue end
        local n = obj.Name
        if Configuration.ESP.HidingSpots and NameInList(n, AutoESP.HidingSpots) then
            CreateESP(obj, "[躲藏] "..n, Color3.fromRGB(0,255,100))
        elseif Configuration.ESP.Switches and NameInList(n, AutoESP.Switches) then
            CreateESP(obj, "[电闸] "..n, Color3.fromRGB(255,255,0))
        elseif Configuration.ESP.Ghosts and NameInList(n, AutoESP.Ghosts) then
            CreateGhostESP(obj)
        elseif n=="ExitDoor" then
            CreateESP(obj, "[大门] "..n, Color3.fromRGB(255,165,0))
        end
    end

    -- Map.Closets
    if Configuration.ESP.HidingSpots then
        local map = workspace:FindFirstChild("Map")
        if map then
            local closets = map:FindFirstChild("Closets")
            if closets then
                for _,obj in ipairs(closets:GetChildren()) do
                    if not ESPObjects[obj] then
                        CreateESP(obj, "[躲藏] "..obj.Name, Color3.fromRGB(0,255,100))
                    end
                end
            end
        end
    end

    -- Items
    if Configuration.ESP.NormalItems or Configuration.ESP.CursedItems then
        local items = workspace:FindFirstChild("Items")
        if items then
            for _,item in ipairs(items:GetChildren()) do
                if ESPObjects[item] then continue end
                local name,cursed = IdentifyItem(item)
                if cursed and Configuration.ESP.CursedItems then
                    CreateESP(item, name, Color3.fromRGB(255,50,50))
                elseif not cursed and Configuration.ESP.NormalItems then
                    CreateESP(item, name, Color3.fromRGB(0,150,255))
                end
            end
        end
        -- CursedPossessionHolder
        local ch = workspace:FindFirstChild("CursedPossessionHolder")
        if ch then
            for _,item in ipairs(ch:GetChildren()) do
                if ESPObjects[item] then continue end
                local nm = item:FindFirstChild("Primary") and "预言家" or "诅咒物品"
                if Configuration.ESP.CursedItems then
                    CreateESP(item, nm, Color3.fromRGB(255,50,50))
                end
            end
        end
    end

    -- Salt
    if Configuration.ESP.Salt then
        local sp = workspace:FindFirstChild("SaltPiles")
        if sp then
            for _,obj in ipairs(sp:GetChildren()) do
                if ESPObjects[obj] then continue end
                local part = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
                if not part then continue end
                local disturbed = (obj.Name=="DisturbedSaltLine")
                local fc = disturbed and Color3.fromRGB(139,69,19)  or Color3.fromRGB(255,255,200)
                local oc = disturbed and Color3.fromRGB(160,82,45)  or Color3.fromRGB(255,255,0)
                local tc = disturbed and Color3.fromRGB(210,180,140) or Color3.fromRGB(255,255,200)
                local txt= disturbed and "[盐 - 已踩]" or "[盐]"
                local hl = Instance.new("Highlight")
                hl.Name = disturbed and "DisturbedSaltESP_Highlight" or "SaltESP_Highlight"
                hl.Adornee = obj; hl.FillColor = fc; hl.FillTransparency = 0.6
                hl.OutlineColor = oc; hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = obj
                local bb = MakeLabel(part, txt, tc, 2, 200)
                ESPObjects[obj] = { highlight = hl, billboard = bb }
            end
        end
    end

    -- 鬼房
    if Configuration.ESP.GhostRoom then
        if not CachedGhostRoom then
            CachedGhostRoom = FindGhostRoom()
        end
        if CachedGhostRoom and not ESPObjects[CachedGhostRoom] then
            CreateFloorESP(CachedGhostRoom, "[鬼房] "..CachedGhostRoom.Name, Color3.fromRGB(255,100,200))
        end
    end

    -- 特殊物品（油灯 / 油 / 花）
    RefreshSpecialItemsESP()
end

-- 增量驱动
Register(workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Decal") then
        ESPDirty = true
    end
end))

Register(workspace.DescendantRemoved:Connect(function(obj)
    RemoveESP(obj)
end))

-- 初始刷新
task.spawn(function()
    task.wait(1)
    RefreshESP()
end)

--===================================
-- Speed 系统
--===================================
local function ApplySpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local h = char:FindFirstChildOfClass("Humanoid")
    if not h then return end
    h.WalkSpeed = Configuration.Speed.Enabled and Configuration.Speed.Value or 16
end

local function StartSpeedLoop()
    if speedConn then return end
    speedConn = RunService.Heartbeat:Connect(ApplySpeed)
end

local function StopSpeedLoop()
    if speedConn then speedConn:Disconnect(); speedConn=nil end
    local char = LocalPlayer.Character
    if char then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
    end
end
AddCleanup(StopSpeedLoop)

--===================================
-- 夜视系统
--===================================
local function SetNightVision(on)
    if on then
        if nightVisionConn then return end
        nightVisionConn = RunService.Heartbeat:Connect(function()
            Lighting.Brightness = 3
            Lighting.ClockTime = 12
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 1000
            Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
        end)
    else
        if nightVisionConn then nightVisionConn:Disconnect(); nightVisionConn=nil end
        Lighting.Brightness = 1; Lighting.ClockTime = 18
        Lighting.GlobalShadows = true; Lighting.FogEnd = 200
        Lighting.OutdoorAmbient = Color3.fromRGB(120,120,120)
    end
end
AddCleanup(function() SetNightVision(false) end)

--===================================
-- 能量条
--===================================
local EnergyBarFrame = Instance.new("Frame")
EnergyBarFrame.Name = "EnergyBar"
EnergyBarFrame.Size = IsMobile and UDim2.new(0,200,0,22) or UDim2.new(0,260,0,26)
EnergyBarFrame.Position = IsMobile and UDim2.new(0.5,-100,1,-60) or UDim2.new(0.5,-130,1,-70)
EnergyBarFrame.BackgroundColor3 = Color3.fromRGB(30,30,46)
EnergyBarFrame.BackgroundTransparency = 0.3; EnergyBarFrame.BorderSizePixel = 0
EnergyBarFrame.Parent = ScreenGui
local c1=Instance.new("UICorner"); c1.CornerRadius=UDim.new(0,6); c1.Parent=EnergyBarFrame
local s1=Instance.new("UIStroke"); s1.Color=Color3.fromRGB(49,50,68); s1.Thickness=1; s1.Parent=EnergyBarFrame

local ebarFill = Instance.new("Frame")
ebarFill.Name="Fill"; ebarFill.Size=UDim2.new(1,0,1,0)
ebarFill.BackgroundColor3=Color3.fromRGB(255,80,80); ebarFill.BorderSizePixel=0
ebarFill.Parent=EnergyBarFrame
local c2=Instance.new("UICorner"); c2.CornerRadius=UDim.new(0,6); c2.Parent=ebarFill

local ebarText = Instance.new("TextLabel")
ebarText.Name="Text"; ebarText.Size=UDim2.new(1,0,1,0)
ebarText.BackgroundTransparency=1; ebarText.Text="能量: 搜索中..."
ebarText.TextColor3=Color3.new(1,1,1); ebarText.TextStrokeColor3=Color3.new(0,0,0)
ebarText.TextStrokeTransparency=0; ebarText.Font=Enum.Font.GothamBold; ebarText.TextSize=13
ebarText.Parent=EnergyBarFrame

local function SearchEnergy()
    energyObj=nil; energyType=nil
    local function scan(container)
        for _,v in ipairs(container:GetDescendants()) do
            if v:IsA("NumberValue") or v:IsA("IntValue") then
                local n=v.Name:lower()
                if n=="energy" or n=="stamina" or n=="sanity" then
                    energyObj=v; energyType="value"; return true
                end
            end
        end
        return false
    end
    if scan(LocalPlayer) then return end
    local char=LocalPlayer.Character
    if char and scan(char) then return end
    -- Attribute
    local attr=LocalPlayer:GetAttribute("Energy")
    if type(attr)~="number" then attr=LocalPlayer:GetAttribute("Stamina") end
    if type(attr)~="number" then attr=LocalPlayer:GetAttribute("Sanity") end
    if type(attr)=="number" then energyType="attribute"; return end
    -- PlayerGui label
    local pg=LocalPlayer:FindFirstChild("PlayerGui")
    if pg then
        for _,v in ipairs(pg:GetDescendants()) do
            if v:IsA("TextLabel") then
                local t=v.Text:lower()
                if (t:find("energy") or t:find("stamina") or t:find("sanity")) and t:match("(%d+%.?%d*)") then
                    energyObj=v; energyType="label"; return
                end
            end
        end
    end
end

local function GetEnergyValue()
    if energyType=="attribute" then
        local a=LocalPlayer:GetAttribute("Energy")
        if type(a)~="number" then a=LocalPlayer:GetAttribute("Stamina") end
        if type(a)~="number" then a=LocalPlayer:GetAttribute("Sanity") end
        return type(a)=="number" and a or nil
    end
    if energyObj and energyObj.Parent then
        if energyType=="value" then return energyObj.Value
        elseif energyType=="label" then return tonumber(energyObj.Text:match("(%d+%.?%d*)")) end
    end
    energyObj=nil; energyType=nil
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.3)
        if not energyObj and energyType~="attribute" and not energySearched then
            energySearched=true
            SearchEnergy()
        end
        local e=GetEnergyValue()
        if e~=nil then
            local p=math.clamp(e,0,100)
            ebarFill.Size=UDim2.new(p/100,0,1,0)
            ebarText.Text=string.format("能量: %.1f%%",p)
        else
            ebarFill.Size=UDim2.new(1,0,1,0)
            ebarText.Text="能量: 搜索中..."
        end
    end
end)

--===================================
-- 任务面板
--===================================
local TaskPanel=nil
local TaskTranslations={
    {en="identify the correct ghost type",zh="识别正确的鬼类型"},
    {en="capture photo of the ghost",zh="拍摄鬼的照片"},
    {en="have every member of your team escape the house",zh="让所有队友逃离房子"},
    {en="reach an average sanity",zh="达到平均理智值"},
    {en="find the cursed item",zh="找到诅咒物品"},
    {en="use the cursed item",zh="使用诅咒物品"},
    {en="use smudge stick",zh="使用圣木"},
    {en="use emf reader",zh="使用EMF读卡器"},
    {en="use spirit box",zh="使用通灵盒"},
    {en="use uv light",zh="使用黑光"},
    {en="use thermometer",zh="使用温度计"},
    {en="use camera",zh="使用相机"},
    {en="collect evidence",zh="收集证据"},
    {en="survive a hunt",zh="在猎杀中存活"},
    {en="cleanse the area",zh="净化区域"},
    {en="place salt",zh="放置盐"},
    {en="light candle",zh="点燃蜡烛"},
    {en="listen to radio",zh="收听电台"},
    {en="freeze the ghost",zh="冻结鬼"},
    {en="prevent a hunt",zh="阻止一次猎杀"},
    {en="witness a hunt",zh="目击一次猎杀"},
    {en="repel the ghost",zh="驱赶鬼"},
    {en="find the ghost room",zh="找到鬼房"},
    {en="objective #1",zh="目标 1"},{en="objective #2",zh="目标 2"},
    {en="objective #3",zh="目标 3"},{en="objective #4",zh="目标 4"},
    {en="objective",zh="目标"},{en="ghost type",zh="鬼类型"},
    {en="cursed item",zh="诅咒物品"},{en="smudge stick",zh="圣木"},
    {en="emf reader",zh="EMF读卡器"},{en="spirit box",zh="通灵盒"},
    {en="uv light",zh="黑光"},{en="thermometer",zh="温度计"},
    {en="sanity",zh="理智值"},{en="evidence",zh="证据"},
    {en="ghost room",zh="鬼房"},{en="ghost",zh="鬼"},{en="house",zh="房子"},
    {en="hunt",zh="猎杀"},{en="collect",zh="收集"},{en="survive",zh="存活"},
    {en="find",zh="找到"},{en="cleanse",zh="净化"},{en="place",zh="放置"},
    {en="light",zh="点燃"},{en="listen",zh="收听"},{en="freeze",zh="冻结"},
    {en="repel",zh="驱赶"},{en="prevent",zh="阻止"},{en="witness",zh="目击"},
    {en="escape",zh="逃离"},{en="camera",zh="相机"},{en="radio",zh="电台"},
    {en="candle",zh="蜡烛"},{en="area",zh="区域"},{en="salt",zh="盐"},
    {en="team",zh="团队"},{en="average",zh="平均"},{en="photo",zh="照片"},
    {en="correct",zh="正确的"},{en="identify",zh="识别"},{en="capture",zh="拍摄"},
    {en="use",zh="使用"},
}

local function escapePattern(s) return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])","%%%1")) end

local robloxTranslator=nil
pcall(function()
    robloxTranslator=game:GetService("LocalizationService"):GetTranslatorForLocaleAsync("zh-cjv")
end)

local function TranslateTask(text)
    if not text or text=="" then return "" end
    local cleaned=text:gsub("<[^>]+>",""):gsub("&nbsp;"," "):gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">")
    local lower=cleaned:lower()
    -- 长句优先
    for _,p in ipairs(TaskTranslations) do
        if p.en:find(" ") then
            local pat=escapePattern(p.en)
            if lower:find(pat) then
                cleaned=cleaned:gsub(pat,p.zh)
                return (cleaned:gsub("  +"," ")):match("^%s*(.-)%s*$")
            end
        end
    end
    if robloxTranslator then
        local ok,res=pcall(function() return robloxTranslator:Translate(game,cleaned) end)
        if ok and res and res~=cleaned and #res>0 and res:match("[\228-\233][\128-\191][\128-\191]") then
            return res
        end
    end
    for _,p in ipairs(TaskTranslations) do
        if not p.en:find(" ") then
            cleaned=cleaned:gsub(escapePattern(p.en),p.zh)
        end
    end
    return (cleaned:gsub("  +"," ")):match("^%s*(.-)%s*$")
end

local function FindTaskBoard()
    local anchor=workspace:FindFirstChild("Anchor")
    if anchor then
        local sg=anchor:FindFirstChild("SurfaceGui")
        if sg then local h=sg:FindFirstChild("Holder"); if h then return h end end
    end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v.Name=="Holder" and v.Parent and v.Parent:IsA("SurfaceGui") then return v end
    end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("SurfaceGui") and v:FindFirstChild("Title") and v:FindFirstChild("Description") then return v end
    end
    local pg=LocalPlayer:FindFirstChild("PlayerGui")
    if pg then for _,v in ipairs(pg:GetDescendants()) do if v.Name=="Holder" then return v end end end
    return nil
end

local function GetTaskItems(board)
    local items={}
    if not board then return items end
    for _,child in ipairs(board:GetChildren()) do
        if child:IsA("GuiObject") or child:IsA("Folder") or child:IsA("Configuration") then
            local t=child:FindFirstChild("Title"); local d=child:FindFirstChild("Description")
            if t and d then
                local tt=t:IsA("TextLabel") and t.Text or ""
                local dt=d:IsA("TextLabel") and d.Text or ""
                if #tt:gsub("%s","")>0 or #dt:gsub("%s","")>0 then
                    table.insert(items,{title=tt,desc=dt})
                end
            end
        end
    end
    return items
end

local lastTaskContentHash=""

local function RefreshTaskPanel()
    if not TaskPanel or IsMobile then return end
    local board=FindTaskBoard()
    local items=GetTaskItems(board)
    local hash=""
    for _,t in ipairs(items) do hash=hash..(t.title or "").."|"..(t.desc or "").."#" end
    if hash==lastTaskContentHash then return end
    lastTaskContentHash=hash

    for _,c in ipairs(TaskPanel:GetChildren()) do
        if c:IsA("TextLabel") or c:IsA("TextButton") then c:Destroy() end
    end
    if #items==0 then
        local m=Instance.new("TextLabel")
        m.Size=UDim2.new(1,0,0,22); m.BackgroundTransparency=1
        m.Text="暂无任务"; m.TextColor3=Color3.fromRGB(200,200,220)
        m.TextStrokeTransparency=0.8; m.Font=Enum.Font.GothamBold; m.TextSize=16
        m.TextXAlignment=Enum.TextXAlignment.Left; m.Parent=TaskPanel
        return
    end
    local hdr=Instance.new("TextLabel")
    hdr.Size=UDim2.new(1,0,0,24); hdr.BackgroundTransparency=1
    hdr.Text="📋 任务（点击切换完成）"
    hdr.TextColor3=Color3.fromRGB(150,200,255); hdr.TextStrokeColor3=Color3.new(0,0,0)
    hdr.TextStrokeTransparency=0.6; hdr.Font=Enum.Font.GothamBold; hdr.TextSize=16
    hdr.TextXAlignment=Enum.TextXAlignment.Left; hdr.Parent=TaskPanel

    for i,t in ipairs(items) do
        if i>5 then break end
        local key=t.title or ("task_"..i)
        local done=TaskManualState[key]==true
        local descLabel=nil

        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(1,0,0,28)
        btn.BackgroundColor3=Color3.fromRGB(40,40,60); btn.BackgroundTransparency=0.7
        btn.AutoButtonColor=true
        local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(0,4); bc.Parent=btn
        btn.Text="• "..TranslateTask(t.title or "")..(done and " ✓" or "")
        btn.TextColor3=done and Color3.fromRGB(120,255,120) or Color3.fromRGB(255,255,180)
        btn.TextStrokeColor3=Color3.new(0,0,0); btn.TextStrokeTransparency=0.6
        btn.Font=Enum.Font.GothamBold; btn.TextSize=18
        btn.TextXAlignment=Enum.TextXAlignment.Left; btn.TextWrapped=true; btn.Parent=TaskPanel
        local bp=Instance.new("UIPadding"); bp.PaddingLeft=UDim.new(0,6); bp.Parent=btn

        btn.MouseButton1Click:Connect(function()
            TaskManualState[key]=not TaskManualState[key]
            local d=TaskManualState[key]==true
            btn.Text="• "..TranslateTask(t.title or "")..(d and " ✓" or "")
            btn.TextColor3=d and Color3.fromRGB(120,255,120) or Color3.fromRGB(255,255,180)
            if descLabel then descLabel.TextColor3=d and Color3.fromRGB(100,200,100) or Color3.fromRGB(180,180,200) end
        end)

        if t.desc and #t.desc:gsub("%s","")>0 then
            descLabel=Instance.new("TextLabel")
            descLabel.Size=UDim2.new(1,0,0,22); descLabel.BackgroundTransparency=1
            descLabel.Text="  "..TranslateTask(t.desc)
            descLabel.TextColor3=done and Color3.fromRGB(100,200,100) or Color3.fromRGB(180,180,200)
            descLabel.TextStrokeColor3=Color3.new(0,0,0); descLabel.TextStrokeTransparency=0.7
            descLabel.Font=Enum.Font.Gotham; descLabel.TextSize=15
            descLabel.TextXAlignment=Enum.TextXAlignment.Left; descLabel.TextWrapped=true; descLabel.Parent=TaskPanel
        end
    end
end

if not IsMobile then
    TaskPanel=Instance.new("Frame")
    TaskPanel.Name="TaskPanel"; TaskPanel.Size=UDim2.new(0,400,0,300)
    TaskPanel.Position=UDim2.new(0,10,1,-320)
    TaskPanel.BackgroundColor3=Color3.fromRGB(20,20,30); TaskPanel.BackgroundTransparency=0.2
    TaskPanel.BorderSizePixel=0; TaskPanel.Parent=ScreenGui
    local tc=Instance.new("UICorner"); tc.CornerRadius=UDim.new(0,8); tc.Parent=TaskPanel
    local ts=Instance.new("UIStroke"); ts.Color=Color3.fromRGB(80,80,110); ts.Thickness=2; ts.Parent=TaskPanel
    local tl=Instance.new("UIListLayout"); tl.SortOrder=Enum.SortOrder.LayoutOrder; tl.Padding=UDim.new(0,4); tl.Parent=TaskPanel
    local tp=Instance.new("UIPadding"); tp.PaddingLeft=UDim.new(0,10); tp.PaddingRight=UDim.new(0,10)
    tp.PaddingTop=UDim.new(0,8); tp.PaddingBottom=UDim.new(0,6); tp.Parent=TaskPanel

    task.spawn(function()
        while true do task.wait(1); RefreshTaskPanel() end
    end)
end

--===================================
-- 通知系统
--===================================
local function FluentNotify(title,content,duration)
    duration=duration or 4
    local frame=Instance.new("Frame")
    frame.Size=IsMobile and UDim2.new(0,280,0,50) or UDim2.new(0,380,0,60)
    frame.Position=IsMobile and UDim2.new(1,-295,0,15) or UDim2.new(1,-410,0,20)
    frame.BackgroundColor3=Color3.fromRGB(40,40,60); frame.BackgroundTransparency=0.1; frame.BorderSizePixel=0
    frame.Parent=ScreenGui
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=frame
    local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(100,100,150); s.Thickness=2; s.Parent=frame
    local tl=Instance.new("TextLabel"); tl.Size=UDim2.new(1,-20,0,24); tl.Position=UDim2.new(0,10,0,4)
    tl.BackgroundTransparency=1; tl.Text=title; tl.TextColor3=Color3.new(1,1,1)
    tl.TextStrokeColor3=Color3.new(0,0,0); tl.TextStrokeTransparency=0.4
    tl.Font=Enum.Font.GothamBold; tl.TextSize=IsMobile and 14 or 16; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=frame
    local dl=Instance.new("TextLabel"); dl.Size=UDim2.new(1,-20,0,20); dl.Position=UDim2.new(0,10,0,28)
    dl.BackgroundTransparency=1; dl.Text=content; dl.TextColor3=Color3.fromRGB(220,220,220)
    dl.TextStrokeColor3=Color3.new(0,0,0); dl.TextStrokeTransparency=0.5
    dl.Font=Enum.Font.Gotham; dl.TextSize=IsMobile and 12 or 14; dl.TextXAlignment=Enum.TextXAlignment.Left; dl.TextWrapped=true; dl.Parent=frame
    Debris:AddItem(frame,duration)
end

local function NotifyWithCooldown(key,title,content,cooldown,duration)
    cooldown=cooldown or 5
    local now=tick()
    if eventCooldowns[key] and (now-eventCooldowns[key])<cooldown then return end
    eventCooldowns[key]=now
    FluentNotify(title,content,duration or 4)
end

--===================================
-- 音频事件 & 猎杀警告
--===================================
local function SetupHuntAlert()
    if huntNotifFrame then return end
    huntNotifFrame=Instance.new("Frame")
    huntNotifFrame.Name="HuntNotification"
    huntNotifFrame.Size=UDim2.new(0,380,0,50)
    huntNotifFrame.Position=UDim2.new(1,-410,0,20)
    huntNotifFrame.BackgroundColor3=Color3.fromRGB(180,0,0); huntNotifFrame.BackgroundTransparency=0.15
    huntNotifFrame.BorderSizePixel=0; huntNotifFrame.Visible=false; huntNotifFrame.Parent=ScreenGui
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=huntNotifFrame
    local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(255,80,80); s.Thickness=2; s.Parent=huntNotifFrame
    local ic=Instance.new("TextLabel"); ic.Size=UDim2.new(0,36,1,0); ic.Position=UDim2.new(0,10,0,0)
    ic.BackgroundTransparency=1; ic.Text="⚠"; ic.TextColor3=Color3.fromRGB(255,100,100)
    ic.Font=Enum.Font.GothamBold; ic.TextSize=24; ic.Parent=huntNotifFrame
    local tt=Instance.new("TextLabel"); tt.Size=UDim2.new(1,-50,1,0); tt.Position=UDim2.new(0,46,0,0)
    tt.BackgroundTransparency=1; tt.Text="鬼正在猎杀！快躲起来！"
    tt.TextColor3=Color3.fromRGB(255,220,220); tt.TextStrokeColor3=Color3.new(0,0,0); tt.TextStrokeTransparency=0.5
    tt.TextXAlignment=Enum.TextXAlignment.Left; tt.Font=Enum.Font.GothamBold; tt.TextSize=18; tt.Parent=huntNotifFrame
end

local function StartHuntBlink()
    if huntBlinking then return end
    huntBlinking=true; huntNotifFrame.Visible=true
    task.spawn(function()
        for i=1,24 do
            if not huntNotifFrame or not huntNotifFrame.Visible then break end
            huntNotifFrame.BackgroundColor3=Color3.fromRGB(200,0,0); task.wait(0.25)
            if not huntNotifFrame or not huntNotifFrame.Visible then break end
            huntNotifFrame.BackgroundColor3=Color3.fromRGB(100,0,0); task.wait(0.25)
        end
        if huntNotifFrame then huntNotifFrame.Visible=false end
        huntBlinking=false
    end)
end

local function HookOneSound(sound,onPlay)
    if not sound or not sound:IsA("Sound") or hookedSounds[sound] then return end
    hookedSounds[sound]=true
    sound:GetPropertyChangedSignal("Playing"):Connect(function()
        if sound.IsPlaying then onPlay(sound.Name) end
    end)
    if sound.IsPlaying then onPlay(sound.Name) end
end

local function StartHuntAlert()
    if huntAlertConn then return end
    SetupHuntAlert()

    local huntCooldown=0
    local HuntKW={"hunt","chase","kill","attack","warning","alert","breath","breathe",
                   "sigh","roar","growl","screech","howl","snarl","hiss","angry","rage","stalk","hunting","ambush"}

    local function IsHuntSound(name)
        local n=name:lower()
        for _,kw in ipairs(HuntKW) do if n:find(kw) then return true end end
        return false
    end

    local function onHuntTrigger(soundName)
        if not Configuration.HuntAlert then return end
        local now=tick()
        if now-huntCooldown<12 then return end
        huntCooldown=now
        FluentNotify("⚠ 猎杀警告","鬼开始猎杀了！快躲起来！",4)
        StartHuntBlink()
    end

    local function HookGhostSounds(ghost)
        if not ghost then return end
        for _,d in ipairs(ghost:GetDescendants()) do
            if d:IsA("Sound") and IsHuntSound(d.Name) then
                HookOneSound(d,onHuntTrigger)
            end
        end
        Register(ghost.DescendantAdded:Connect(function(d)
            if d:IsA("Sound") and IsHuntSound(d.Name) then HookOneSound(d,onHuntTrigger) end
        end))
    end

    -- 初始
    HookGhostSounds(workspace:FindFirstChild("Ghost"))

    -- Ghost 出现时
    Register(workspace.ChildAdded:Connect(function(c)
        if c.Name=="Ghost" then task.wait(0.3); HookGhostSounds(c) end
    end))

    -- RemoteEvent
    pcall(function()
        for _,child in ipairs(ReplicatedStorage:GetDescendants()) do
            if child:IsA("RemoteEvent") and (child.Name:lower():find("hunt") or child.Name:lower():find("chase")) then
                Register(child.OnClientEvent:Connect(function(...) onHuntTrigger(child.Name) end))
            end
        end
    end)

    -- 死亡检测
    Register(workspace.ChildAdded:Connect(function(c)
        if c.Name=="Ghost" then
            task.wait(0.5)
            local g=workspace:FindFirstChild("Ghost")
            if not g then return end
            Register(g.DescendantAdded:Connect(function(d)
                if d:IsA("Sound") then
                    if d.Name=="Scream" or d.Name=="BoneBreak" then
                        NotifyWithCooldown("death","☠ 死亡警告","有人被鬼杀死了！",5,4)
                    elseif d.Name=="Hunt" then
                        NotifyWithCooldown("hunt","⚠ 猎杀警告","鬼开始猎杀了！快躲起来！",12,4)
                        StartHuntBlink()
                    end
                end
            end))
        end
    end))

    huntAlertConn=true
end

local function StopHuntAlert()
    if huntNotifFrame then huntNotifFrame.Visible=false end
    huntBlinking=false
end

-- 电闸检测
local PowerNames={"FuseBox","PowerBox","MainAnchor","Buttons","Breaker","ElectricPanel"}

local function MonitorPowerBox(pb)
    if powerMonitored[pb] then return end
    powerMonitored[pb]=true
    local cd=0
    local function onChange()
        local now=tick()
        if now-cd>15 then
            cd=now
            NotifyWithCooldown("poweroutage","⚡ 鬼已把电闸拉上","你暂时无法开灯，请找到电闸所在位置并开启",15,5)
        end
    end
    pcall(function() Register(pb:GetPropertyChangedSignal("Transparency"):Connect(onChange)) end)
    pcall(function() Register(pb:GetPropertyChangedSignal("Color"):Connect(onChange)) end)
    pcall(function() Register(pb:GetPropertyChangedSignal("CanCollide"):Connect(onChange)) end)
    Register(pb.DescendantAdded:Connect(function(d)
        if d:IsA("ClickDetector") or d:IsA("ProximityPrompt") or d:IsA("SurfaceGui") then onChange() end
    end))
end

local function FindAndMonitorPowerBoxes()
    for _,d in ipairs(workspace:GetDescendants()) do
        if (d:IsA("Model") or d:IsA("Part")) then
            for _,n in ipairs(PowerNames) do
                if d.Name==n then MonitorPowerBox(d); break end
            end
        end
    end
end
FindAndMonitorPowerBoxes()
Register(workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Model") or d:IsA("Part") then
        for _,n in ipairs(PowerNames) do
            if d.Name==n then MonitorPowerBox(d); break end
        end
    end
end))

-- 音频事件
local AudioEvents={
    {name="singing", soundName="GhostSinging", cooldown=10, title="♪ 幽灵正在唱歌中", content="鬼正在唱歌，注意聆听歌声来源的方向"},
    {name="death",   soundName="Scream",      cooldown=5,  title="☠ 你已经被鬼杀死", content="队友被鬼击杀了！注意安全"},
    {name="mirrorcrack",soundName="MirrorCrack",cooldown=5, title="🪞 您的诅咒镜子碎了", content="请立刻躲在柜子里！"},
}

local function FindInSoundsFolder(name)
    local r={}
    local function scan(parent)
        if not parent then return end
        for _,c in ipairs(parent:GetChildren()) do
            if c:IsA("Sound") and c.Name==name then table.insert(r,c)
            elseif c:IsA("Folder") or c:IsA("Model") then
                local s=c:FindFirstChild(name)
                if s and s:IsA("Sound") then table.insert(r,s) end
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("PlayerScripts"))
    scan(game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"))
    scan(ReplicatedStorage); scan(game:GetService("SoundService"))
    local pg=LocalPlayer:FindFirstChild("PlayerGui")
    if pg then for _,c in ipairs(pg:GetChildren()) do if c:IsA("Sound") and c.Name==name then table.insert(r,c) end end end
    return r
end

local function HookAudioEvent(cfg)
    local sounds=FindInSoundsFolder(cfg.soundName)
    if #sounds==0 then
        local now=tick()
        if not deepSearchLastTime[cfg.name] or (now-deepSearchLastTime[cfg.name])>10 then
            deepSearchLastTime[cfg.name]=now
            local services={
                ReplicatedStorage, game:GetService("SoundService"),
                game:GetService("StarterPack"), game:GetService("StarterGui"),
                game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"),
                LocalPlayer:FindFirstChild("PlayerScripts"),
                LocalPlayer:FindFirstChild("PlayerGui"),
            }
            for _,svc in ipairs(services) do
                if svc then
                    pcall(function()
                        for _,d in ipairs(svc:GetDescendants()) do
                            if d:IsA("Sound") and d.Name==cfg.soundName then table.insert(sounds,d) end
                        end
                    end)
                end
            end
        end
    end
    for _,snd in ipairs(sounds) do
        HookOneSound(snd,function()
            NotifyWithCooldown(cfg.name,cfg.title,cfg.content,cfg.cooldown,4)
        end)
    end
end

task.spawn(function()
    for _,ev in ipairs(AudioEvents) do HookAudioEvent(ev) end
    local function MonitorService(svc)
        if not svc then return end
        Register(svc.DescendantAdded:Connect(function(d)
            if d:IsA("Sound") then
                for _,ev in ipairs(AudioEvents) do
                    if d.Name==ev.soundName then
                        HookOneSound(d,function()
                            NotifyWithCooldown(ev.name,ev.title,ev.content,ev.cooldown,4)
                        end)
                    end
                end
            end
        end))
    end
    MonitorService(LocalPlayer:FindFirstChild("PlayerScripts"))
    MonitorService(ReplicatedStorage); MonitorService(game:GetService("SoundService"))
    MonitorService(game:GetService("StarterGui")); MonitorService(workspace)
    task.wait(2)
    MonitorService(LocalPlayer:FindFirstChild("PlayerScripts"))
    while true do
        task.wait(30)
        for _,ev in ipairs(AudioEvents) do
            local sounds=FindInSoundsFolder(ev.soundName)
            for _,snd in ipairs(sounds) do
                HookOneSound(snd,function()
                    NotifyWithCooldown(ev.name,ev.title,ev.content,ev.cooldown,4)
                end)
            end
        end
    end
end)

--===================================
-- 物品选中 & DEX 路径
--===================================
local function GetFullPath(obj)
    local p={}; local c=obj
    while c and c~=game do table.insert(p,1,c.Name); c=c.Parent end
    return "game."..table.concat(p,".")
end

local function GetItemFromPart(part)
    if not part then return nil end
    local items=workspace:FindFirstChild("Items")
    if items then
        local c=part
        while c and c~=workspace do
            if c.Parent==items then return c end
            c=c.Parent
        end
    end
    local c=part
    while c and c.Parent and c.Parent~=workspace do c=c.Parent end
    return c
end

local function SelectItem()
    local t=Mouse.Target
    if not t then SelectedItem=nil; print("[选中] 未指向任何对象"); return end
    SelectedItem=GetItemFromPart(t)
    if SelectedItem then
        print("[选中] "..SelectedItem.Name.."  (路径: "..GetFullPath(SelectedItem)..")")
    else
        print("[选中] "..t.Name)
    end
end

local function PrintSelectedInfo()
    if not SelectedItem then print("[打印] 没有选中物品，先指向物品再按P选中"); return end
    print("========== 选中物品信息 ==========")
    print("名称: "..SelectedItem.Name)
    print("路径: "..GetFullPath(SelectedItem))
    print("类型: "..SelectedItem.ClassName)
    print("位置: "..tostring(SelectedItem:GetPivot().Position))
    print("子对象:")
    for _,c in ipairs(SelectedItem:GetChildren()) do
        print("  - "..c.Name.."  ("..c.ClassName..")")
    end
    print("==================================")
end

local function ShowDexPath()
    if not SelectedItem then print("[DEX] 没有选中物品"); return end
    local path=GetFullPath(SelectedItem)
    print("[DEX路径] "..path)
    pcall(function() setclipboard(path); print("[DEX路径] 已复制到剪贴板") end)
end

Register(UserInputService.InputBegan:Connect(function(input,processed)
    if processed then return end
    if input.KeyCode==Enum.KeyCode.P then SelectItem(); PrintSelectedInfo()
    elseif input.KeyCode==Enum.KeyCode.F9 then ShowDexPath() end
end))

--===================================
-- Fluent UI 界面
--===================================
local UISettings={
    TabWidth = IsMobile and 70 or 160,
    Size = IsMobile and {380,320} or {580,460},
    Theme = "Amethyst", Acrylic = false, Transparency = true,
    MinimizeKey = "", ShowNotifications = true, ShowWarnings = true,
}

local InterfaceManager={}
function InterfaceManager:ImportSettings()
    pcall(function()
        if getfenv().isfile and getfenv().readfile and getfenv().isfile("DemonologyUISettings.ttwizz") then
            for k,v in next,HttpService:JSONDecode(getfenv().readfile("DemonologyUISettings.ttwizz")) do UISettings[k]=v end
        end
    end)
end
function InterfaceManager:ExportSettings()
    pcall(function()
        if getfenv().writefile then
            getfenv().writefile("DemonologyUISettings.ttwizz",HttpService:JSONEncode(UISettings))
        end
    end)
end
InterfaceManager:ImportSettings()
UISettings.__LAST_RUN__=os.date()
InterfaceManager:ExportSettings()

local Window = Fluent:CreateWindow({
    Title = "恶魔学辅助",
    SubTitle = "透视 | 速度 | 夜视 | 猎杀提醒",
    TabWidth = UISettings.TabWidth,
    Size = UDim2.fromOffset(table.unpack(UISettings.Size)),
    Theme = UISettings.Theme,
    Acrylic = UISettings.Acrylic,
    MinimizeKey = UISettings.MinimizeKey,
})

local Tabs={}
Tabs.ESP     = Window:AddTab({Title="ESP",    Icon="layers"})
Tabs.Speed   = Window:AddTab({Title="速度",   Icon="zap"})
Tabs.Vision  = Window:AddTab({Title="视觉",   Icon="eye"})
Tabs.Settings= Window:AddTab({Title="设置",   Icon="settings"})

-- ESP 页
Tabs.ESP:AddParagraph({Title="ESP 透视",Content="自动识别并绘制躲藏点、电闸、鬼、物品等"})
local ES=Tabs.ESP:AddSection("ESP 开关")
ES:AddToggle("HidingSpotsToggle",{Title="躲藏点",Description="显示躲藏位置",Default=Configuration.ESP.HidingSpots,Callback=function(v) Configuration.ESP.HidingSpots=v; ESPDirty=true end})
ES:AddToggle("SwitchesToggle",{Title="电闸",Description="显示电闸位置",Default=Configuration.ESP.Switches,Callback=function(v) Configuration.ESP.Switches=v; ESPDirty=true end})
ES:AddToggle("GhostsToggle",{Title="鬼",Description="显示鬼的轮廓",Default=Configuration.ESP.Ghosts,Callback=function(v) Configuration.ESP.Ghosts=v; ESPDirty=true end})
ES:AddToggle("NormalItemsToggle",{Title="普通物品",Description="显示普通道具",Default=Configuration.ESP.NormalItems,Callback=function(v) Configuration.ESP.NormalItems=v; ESPDirty=true end})
ES:AddToggle("CursedItemsToggle",{Title="诅咒物品",Description="显示诅咒道具",Default=Configuration.ESP.CursedItems,Callback=function(v) Configuration.ESP.CursedItems=v; ESPDirty=true end})
ES:AddToggle("GhostRoomToggle",{Title="鬼房",Description="显示鬼所在房间",Default=Configuration.ESP.GhostRoom,Callback=function(v) Configuration.ESP.GhostRoom=v; ESPDirty=true end})
ES:AddToggle("SaltToggle",{Title="盐",Description="显示盐堆",Default=Configuration.ESP.Salt,Callback=function(v) Configuration.ESP.Salt=v; ESPDirty=true end})

-- 速度页
Tabs.Speed:AddParagraph({Title="移动速度",Content="调整角色移动速度"})
local SS=Tabs.Speed:AddSection("速度设置")
SS:AddToggle("SpeedToggle",{Title="启用速度",Description="开启自定义速度",Default=Configuration.Speed.Enabled,Callback=function(v)
    Configuration.Speed.Enabled=v
    v and StartSpeedLoop() or StopSpeedLoop()
end})
SS:AddSlider("SpeedSlider",{Title="速度值",Description="设置移动速度",Default=Configuration.Speed.Value,Min=8,Max=100,Rounding=1,Callback=function(v) Configuration.Speed.Value=v end})

-- 视觉页
Tabs.Vision:AddParagraph({Title="视觉效果",Content="夜视和猎杀提醒"})
local VS=Tabs.Vision:AddSection("夜视")
VS:AddToggle("NightVisionToggle",{Title="夜视",Description="提高亮度，去除黑暗",Default=Configuration.NightVision,Callback=function(v)
    Configuration.NightVision=v; SetNightVision(v)
end})
local AS=Tabs.Vision:AddSection("猎杀提醒")
AS:AddToggle("HuntAlertToggle",{Title="猎杀提醒",Description="鬼开始猎杀时显示警告",Default=Configuration.HuntAlert,Callback=function(v)
    Configuration.HuntAlert=v; v and StartHuntAlert() or StopHuntAlert()
end})

-- 设置页
Tabs.Settings:AddParagraph({Title="界面设置",Content="调整 UI 外观和行为"})
local UI=Tabs.Settings:AddSection("UI")
UI:AddDropdown("ThemeDropdown",{Title="主题",Description="更改 UI 主题",Values=Fluent.Themes,Default=Fluent.Theme,Callback=function(v) Fluent:SetTheme(v); UISettings.Theme=v; InterfaceManager:ExportSettings() end})
if Fluent.UseAcrylic then
    UI:AddToggle("AcrylicToggle",{Title="亚克力效果",Description="模糊背景，需要画质 >= 8",Default=Fluent.Acrylic,Callback=function(v)
        if not v or not UISettings.ShowWarnings then Fluent:ToggleAcrylic(v)
        elseif UISettings.ShowWarnings then
            Window:Dialog({Title="警告",Content="此选项可能被检测！确定启用？",Buttons={
                {Title="确认",Callback=function() Fluent:ToggleAcrylic(v) end},
                {Title="取消",Callback=function() Fluent.Options.AcrylicToggle:SetValue(false) end},
            }})
        end
    end})
end
UI:AddToggle("TransparencyToggle",{Title="透明度",Description="使 UI 透明",Default=UISettings.Transparency,Callback=function(v) Fluent:ToggleTransparency(v); UISettings.Transparency=v; InterfaceManager:ExportSettings() end})

Window:SelectTab(1)

local function Notify(msg)
    if Fluent and typeof(msg)=="string" then
        Fluent:Notify({Title="恶魔学辅助",Content=msg,Duration=1.5})
    end
end

-- 移动端按钮
if IsMobile then
    local uiVisible=true
    local function ToggleUI()
        uiVisible=not uiVisible
        pcall(function()
            for _,v in ipairs(ScreenGui:GetChildren()) do
                if v:IsA("Frame") or v:IsA("ScrollingFrame") then v.Visible=uiVisible end
            end
            Fluent:Toggle()
        end)
    end
    ScreenGui:FindFirstChild("MobileToggle").MouseButton1Click:Connect(ToggleUI)
    pcall(function() ScreenGui.MobileToggle.TouchTap:Connect(ToggleUI) end)
end

--===================================
-- 心跳：增量刷新 ESP + 鬼房缓存
--===================================
Register(RunService.Heartbeat:Connect(function()
    if ESPDirty then ESPDirty=false; RefreshESP() end
    -- 鬼房缓存更新
    if Configuration.ESP.GhostRoom then
        local ghost=workspace:FindFirstChild("Ghost")
        local root=ghost and (ghost.PrimaryPart or ghost:FindFirstChild("HumanoidRootPart"))
        if root and (root.Position-LastGhostPos).Magnitude>=3 then
            LastGhostPos=root.Position
            CachedGhostRoom=FindGhostRoom()
            ESPDirty=true
        end
    end
end))

--===================================
-- 初始化
--===================================
task.wait(1)
RefreshESP()
if Configuration.HuntAlert then StartHuntAlert() end

local char=LocalPlayer.Character
if char then
    local h=char:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed=16 end
end

print("[Demonology] 10/10 Final Build 加载完成")
print("  RightShift = 切换GUI")
print("  P键 = 选中物品并打印信息")
print("  F9键 = 查看选中物品的DEX路径")

--===================================
-- 安全卸载（可选）
--===================================
local function SafeUnload()
    for _,c in ipairs(Connections) do pcall(c.Disconnect,c) end
    for _,fn in ipairs(CleanupFns) do pcall(fn) end
    for obj in pairs(ESPObjects) do RemoveESP(obj) end
    ScreenGui:Destroy()
    pcall(function() Fluent:Destroy() end)
    print("[Demonology] 已安全卸载")
end
AddCleanup(SafeUnload)

getfenv().DemonologyUnload = SafeUnload
