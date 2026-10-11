-- [[ Pun Hub - Blade Ball ]] --
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Pun Hub | Blade Ball",
   LoadingTitle = "Pun Hub Loading...",
   LoadingSubtitle = "by AI Collaborator",
   ConfigurationSaving = {
      Enabled = false,
      FolderName = nil,
      FileName = "PunHubBB"
   },
   KeySystem = false,
})

local Tab = Window:CreateTab("Main", 4483362458)

-- Biến cấu hình tính năng
local _G_Config = {
   AutoParry = false,
   AutoSpam = false,
   SpamRPS = 60,
   showStats = true -- Mặc định bật hiển thị thống kê
}

Rayfield:Notify({
   Title = "Pun Hub Loaded",
   Content = "Đang chờ hook capture parry...",
   Duration = 3,
   Image = 4483362458,
})

-- ==========================================
-- PHẦN HOOK VÀ LOGIC PARRY
-- ==========================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StatsService = game:GetService("Stats")
local lp = Players.LocalPlayer

local captured = {}
local getupvals = debug.getupvalues or getupvalues
local pry_fn

for _, fn in ipairs(getgc(true)) do
    if type(fn) == "function" then
        local s = debug.info(fn, "s")
        if s and s:find("SwordsController") and s:find("PRY") then
            local ups = getupvals(fn)
            if typeof(ups[1]) == "Instance" and ups[1]:IsA("RemoteEvent") and
               typeof(ups[2]) == "Instance" and ups[2]:IsA("RemoteEvent") and
               type(ups[3]) == "table" then
                pry_fn = fn
                break
            end
        end
    end
end

if not pry_fn then 
    Rayfield:Notify({Title = "Lỗi", Content = "Không tìm thấy PRY function!", Duration = 5})
end

local Camera = Workspace.CurrentCamera

local function GetParryData()
    local viewportSize = Camera.ViewportSize
    local centerPos = {
        viewportSize.X / 2,
        viewportSize.Y / 2
    }
    local events = {}
    if Workspace:FindFirstChild("Alive") then
        for _, v in pairs(workspace.Alive:GetChildren()) do
            if v ~= lp.Character and v:FindFirstChild("HumanoidRootPart") then
                local screenPos, isOnScreen = Camera:WorldToScreenPoint(v.HumanoidRootPart.Position)
                if isOnScreen then
                    events[tostring(v)] = screenPos
                end
            end
        end
    end
    return Camera.CFrame, events, centerPos
end

local function executeParry()
    if not captured.remote then return end
    local char = lp.Character
    if not char or not char.PrimaryPart then return end
    local balls = workspace:FindFirstChild("Balls")
    if not balls then return end
    for _, ball in ipairs(balls:GetChildren()) do
        local key = captured.kt[3] or (captured.kt[2] and captured.kt[2][3])
        if not key then return end
        local camCF, events, centerPos = GetParryData()
        local ok, transformed = pcall(captured.tf, key, "TIME")
        if not ok then return end
        local timeStr = tostring(math.floor(workspace:GetServerTimeNow()*100))
        local chars = {}
        for i = 1, #timeStr do
            local ki = (i-1) % #transformed + 1
            chars[i] = string.char(bit32.bxor((timeStr:byte(i)+i)%256, transformed:byte(ki)))
        end
        pcall(function()
            captured.remote:FireServer(
                captured.hash, key, table.concat(chars),
                0.5, camCF,
                events, centerPos, false
            )
        end)
        break
    end
end

local function onCaptured()
    Rayfield:Notify({Title = "Thành công", Content = "Auto Parry đã được kích hoạt (Armed)!", Duration = 3})
end

if pry_fn then
    local ups = getupvals(pry_fn)
    local re1, re2 = ups[1], ups[2]

    local function setupHook(re)
        local mt = getrawmetatable(re)
        setreadonly(mt, false)
        local old = rawget(mt, "__index")

        mt.__index = newcclosure(function(self, key)
            if key == "FireServer" then
                return function(_, ...)
                    local args = {...}
                    if #args == 8 and not captured.remote then
                        captured.remote = self
                        captured.hash = args[1]
                        captured.kt = ups[3]
                        captured.tf = ups[4]
                        onCaptured()
                    end
                    return old(self, key)(self, ...)
                end
            end
            return old(self, key)
        end)
        setreadonly(mt, true)
    end

    pcall(function() setupHook(re1) end)
    pcall(function() setupHook(re2) end)
end

-- ==========================================
-- [ СТАТИСТИКА ] & [ ПИНГ ] & [ УВУ ДЕТЕКТ ]
-- ==========================================
local ballStats = { current = 0, peak = 0 }

local function GetBallSpeed()
    local balls = workspace:FindFirstChild("Balls")
    if not balls then return 0 end
    for _, v in pairs(balls:GetChildren()) do
        if v:GetAttribute("realBall") then
            if v.Velocity then
                return v.Velocity.Magnitude
            end
            local z = v:FindFirstChild("zoomies")
            if z and z:FindFirstChild("VectorVelocity") then
                return z.VectorVelocity.Magnitude
            end
        end
    end
    return 0
end

local function UpdateBallStats()
    local speed = GetBallSpeed()
    ballStats.current = math.floor(speed)
    if speed > ballStats.peak then
        ballStats.peak = math.floor(speed)
    end
end

local lastBallId = nil
task.spawn(function()
    while true do
        local balls = workspace:FindFirstChild("Balls")
        local newId = nil
        if balls then
            for _, v in pairs(balls:GetChildren()) do
                if v:GetAttribute("realBall") then
                    newId = v:GetDebugId()
                    break
                end
            end
        end
        if newId and newId ~= lastBallId then
            ballStats.peak = 0
            lastBallId = newId
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while true do
        if _G_Config.showStats then
            UpdateBallStats()
        end
        task.wait(0.05)
    end
end)

local function GetPing()
    local success, result = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return success and result or 100
end

local Lerp_Radians = 0
local Last_Warping = tick()

local function Is_Curved(ball)
    local Zoomies = ball:FindFirstChild("zoomies")
    if not Zoomies then
        return false
    end
    local Velocity = Zoomies.VectorVelocity
    local Character = lp.Character
    if not Character or not Character.PrimaryPart then
        return false
    end
    
    local distanceToBall = (Character.PrimaryPart.Position - ball.Position).Magnitude
    if distanceToBall <= 25 then
        return false
    end
    
    local Speed = Velocity.Magnitude
    local Direction = (Character.PrimaryPart.Position - ball.Position).Unit
    local Dot = Direction:Dot(Velocity.Unit)
    
    local Ping = GetPing() / 1000
    local Distance = (Character.PrimaryPart.Position - ball.Position).Magnitude
    local Reach_Time = Distance / Speed - Ping
    local Radians = math.rad(math.asin(math.clamp(Dot, -1, 1)))
    Lerp_Radians = Lerp_Radians + (Radians - Lerp_Radians) * 0.8
    
    if Lerp_Radians < 0.018 then
        Last_Warping = tick()
    end
    
    if (tick() - Last_Warping) < (Reach_Time / 1.5) then
        return true
    end
    return Dot < (0.5 - Ping)
end

-- ==========================================
-- GIAO DIỆN RAYFIELD UI
-- ==========================================
Tab:CreateSection("Tính năng chính")

Tab:CreateToggle({
   Name = "Auto Parry",
   CurrentValue = false,
   Flag = "AutoParryFlag",
   Callback = function(Value)
      _G_Config.AutoParry = Value
   end,
})

Tab:CreateToggle({
   Name = "Auto Spam",
   CurrentValue = false,
   Flag = "AutoSpamFlag",
   Callback = function(Value)
      _G_Config.AutoSpam = Value
   end,
})

Tab:CreateSlider({
   Name = "Spam RPS (Tốc độ gửi)",
   Range = {10, 120},
   Increment = 1,
   Suffix = "RPS",
   CurrentValue = 60,
   Flag = "SpamRPSSlider",
   Callback = function(Value)
      _G_Config.SpamRPS = Value
   end,
})

-- ==========================================
-- VÒNG LẶP XỬ LÝ CHÍNH
-- ==========================================
task.spawn(function()
    while task.wait() do
        if captured.remote then
            local balls = workspace:FindFirstChild("Balls")
            if balls and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = lp.Character.HumanoidRootPart
                
                for _, ball in ipairs(balls:GetChildren()) do
                    if ball:GetAttribute("realBall") then
                        local distance = (ball.Position - hrp.Position).Magnitude
                        local speed = ballStats.current
                        
                        if _G_Config.AutoParry then
                            -- Kiểm tra thêm điều kiện uốn bóng / khoảng cách ngưỡng
                            local isCurved = Is_Curved(ball)
                            local threshold = math.clamp(speed * 0.35, 15, 35)
                            
                            if distance <= threshold or isCurved then
                                executeParry()
                            end
                        end
                    end
                end
            end
            
            if _G_Config.AutoSpam then
                executeParry()
                task.wait(1 / _G_Config.SpamRPS)
            end
        end
    end
end)
