--// ============================================================
--//  RELWX HUB  —  MacLib Edition
--//  พอร์ตฟังก์ชันจาก Lineage I Sailueatarchiwa → MacLib UI
--//  (ต้องโหลด MacLib ก่อนสคริปต์นี้)
--// ============================================================

if not MacLib then
    return warn("[RELWX] ต้องโหลด MacLib ก่อนสคริปต์นี้")
end

local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local RunService  = game:GetService("RunService")
local Teleport    = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local SoundSvc    = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer

--// ============================================================
--//  CONFIG / FLAGS
--// ============================================================
local Config = {
    MasterOn         = true,
    DebugLog         = false,
    JobChoice        = "ทั้งหมด",
    FarmTP           = true,
    InstantPrompt    = true,
    SpamRadius       = 20,
    FarmInterval     = 0.5,
    PromptCooldown   = 4,
    TpDelay          = 0.15,
    SpamInterval     = 0.3,
    ToolChoice       = "",
    TargetName       = "",
    WalkSpeedValue   = 32,
    JumpPowerValue   = 80,
    FlySpeed         = 60,
    SpinSpeed        = 4,
    SoundInterval    = 0.4,
}

local Flags = {
    AutoFarm      = false,
    PromptSpam    = false,
    CoinCollect   = false,
    UnlimitedAmmo = false,
    WalkSpeedOn   = false,
    JumpPowerOn   = false,
    Fly           = false,
    Noclip        = false,
    GodMode       = false,
    ESPPlayers    = false,
    AntiAFK       = true,
    HideName      = false,
    CameraSpin    = false,
    SoundSpam     = false,
}

local function On(k)
    return Config.MasterOn and Flags[k] == true
end

--// ============================================================
--//  HELPERS
--// ============================================================
local function Hum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function Root()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function TpTo(pos)
    local r = Root()
    if r then
        r.AssemblyLinearVelocity = Vector3.zero
        r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
end

local function FirePrompt(pp)
    if Config.InstantPrompt then
        pcall(function() pp.HoldDuration = 0 end)
    end
    if fireproximityprompt then
        pcall(fireproximityprompt, pp)
    else
        pcall(function()
            pp:InputHoldBegin()
            task.wait(math.max(pp.HoldDuration, 0) + 0.05)
            pp:InputHoldEnd()
        end)
    end
end

--// ============================================================
--//  JOB SYSTEM (Workspace.Job)
--// ============================================================
local JobOptions = { "ทั้งหมด", "งานก่อสร้าง", "ทำความสะอาด", "ซ่อมรถ", "ขยะ" }
local JobCache = { t = 0, key = "", sites = {}, npcs = {} }

local function JobPrompts(choice)
    if JobCache.key == choice and os.clock() - JobCache.t < 3 then
        return JobCache.sites, JobCache.npcs
    end
    local sites, npcs = {}, {}
    local job = workspace:FindFirstChild("Job")
    if job then
        local folders = choice == "ทั้งหมด" and job:GetChildren() or { job:FindFirstChild(choice) }
        for _, f in ipairs(folders) do
            if f then
                for _, d in ipairs(f:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then
                        if d:FindFirstAncestor("NPC") then
                            npcs[#npcs + 1] = d
                        else
                            sites[#sites + 1] = d
                        end
                    end
                end
            end
        end
    end
    JobCache = { t = os.clock(), key = choice, sites = sites, npcs = npcs }
    return sites, npcs
end

local function PromptPart(pp)
    local p = pp.Parent
    return (p and p:IsA("BasePart")) and p or nil
end

local Fired = {}
local function PickNearest(list, cooldown)
    local me = Root()
    if not me then return nil end
    local best, bd = nil, math.huge
    for _, pp in ipairs(list) do
        local part = PromptPart(pp)
        if pp.Parent and pp.Enabled and part and os.clock() - (Fired[pp] or 0) > cooldown then
            local d = (part.Position - me.Position).Magnitude
            if d < bd then
                best, bd = pp, d
            end
        end
    end
    return best, bd
end

local function Interact(pp, dist)
    local part = PromptPart(pp)
    if not part then return false end
    local reach = math.max((pp.MaxActivationDistance or 10) - 3, 3)
    if dist > reach then
        if not Config.FarmTP then return false end
        TpTo(part.Position)
        task.wait(Config.TpDelay)
    end
    FirePrompt(pp)
    Fired[pp] = os.clock()
    return true
end

local WasFarming = false
local Stats = { farmCount = 0, farmStart = nil }

local function FarmStep()
    if not On("AutoFarm") then
        WasFarming = false
        return
    end
    if not WasFarming then
        WasFarming = true
        Stats.farmStart = os.clock()
        Stats.farmCount = 0
    end
    local hum = Hum()
    if not Root() or not hum or hum.Health <= 0 then return end
    local sites, npcs = JobPrompts(Config.JobChoice)
    local pp, d = PickNearest(sites, Config.PromptCooldown)
    if not pp then
        pp, d = PickNearest(npcs, Config.PromptCooldown * 2)
    end
    if pp and Interact(pp, d) then
        Stats.farmCount = Stats.farmCount + 1
    end
end

task.spawn(function()
    while true do
        local ok, err = pcall(FarmStep)
        if not ok and Config.DebugLog then warn("[RELWX] Farm:", err) end
        task.wait(math.max(Config.FarmInterval, 0.05))
    end
end)

local function TpToJob()
    local sites, npcs = JobPrompts(Config.JobChoice)
    local pp = npcs[1] or sites[1]
    local part = pp and PromptPart(pp)
    if part then
        TpTo(part.Position)
        return true
    end
    return false
end

--// ============================================================
--//  WORLD SCAN (Prompt spam + coins)
--// ============================================================
local World = { t = -100, prompts = {}, coins = {} }
local Scanning = false

local function ScanWorld()
    if Scanning or os.clock() - World.t < 8 then return end
    Scanning = true
    task.spawn(function()
        local prompts, coins = {}, {}
        local n = 0
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") then
                prompts[#prompts + 1] = d
            elseif d:IsA("BasePart") then
                local nm = string.lower(d.Name)
                if (nm == "coin" or nm == "coins" or nm == "เหรียญ")
                    and (d:FindFirstChildWhichIsA("TouchTransmitter")
                        or d:FindFirstChildWhichIsA("ProximityPrompt")) then
                    coins[#coins + 1] = d
                end
            end
            n = n + 1
            if n % 4000 == 0 then task.wait() end
        end
        World = { t = os.clock(), prompts = prompts, coins = coins }
        Scanning = false
    end)
end

task.spawn(function()
    while true do
        if On("PromptSpam") or On("CoinCollect") then ScanWorld() end
        local me = Root()
        if me and On("PromptSpam") then
            for _, pp in ipairs(World.prompts) do
                local part = pp.Parent and PromptPart(pp)
                if part and pp.Enabled
                    and (part.Position - me.Position).Magnitude <= Config.SpamRadius then
                    FirePrompt(pp)
                end
            end
        end
        task.wait(math.max(Config.SpamInterval, 0.1))
    end
end)

task.spawn(function()
    while true do
        local me = Root()
        if me and On("CoinCollect") then
            for _, c in ipairs(World.coins) do
                if c.Parent then
                    if firetouchinterest and c:FindFirstChildWhichIsA("TouchTransmitter") then
                        pcall(firetouchinterest, me, c, 0)
                        pcall(firetouchinterest, me, c, 1)
                    else
                        local pp = c:FindFirstChildWhichIsA("ProximityPrompt")
                        if pp then
                            TpTo(c.Position)
                            task.wait(Config.TpDelay)
                            FirePrompt(pp)
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

--// ============================================================
--//  WEAPONS
--// ============================================================
local function ToolList()
    local out = {}
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") then out[#out + 1] = t.Name end
        end
    end
    local c = LocalPlayer.Character
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") then out[#out + 1] = t.Name end
        end
    end
    if #out == 0 then out[1] = "(ไม่มีอาวุธ)" end
    return out
end

local function EquipSelected()
    local hum, bp = Hum(), LocalPlayer:FindFirstChildOfClass("Backpack")
    if not (hum and bp) then return false end
    local t = bp:FindFirstChild(Config.ToolChoice)
    if t and t:IsA("Tool") then
        hum:EquipTool(t)
        return true
    end
    return false
end

local AmmoMax = setmetatable({}, { __mode = "k" })
local function IsAmmoName(n)
    n = string.lower(n)
    return n:find("ammo") or n:find("mag") or n:find("clip") or n:find("bullet")
        or n:find("กระสุน") or n:find("แม็ก")
end

task.spawn(function()
    while true do
        if On("UnlimitedAmmo") then
            for _, r in ipairs({ LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character }) do
                if r then
                    for _, tool in ipairs(r:GetChildren()) do
                        if tool:IsA("Tool") then
                            for _, v in ipairs(tool:GetDescendants()) do
                                if (v:IsA("IntValue") or v:IsA("NumberValue")) and IsAmmoName(v.Name) then
                                    local mx = AmmoMax[v] or v.Value
                                    if v.Value > mx then mx = v.Value end
                                    AmmoMax[v] = mx
                                    if v.Value < mx then v.Value = mx end
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(0.25)
    end
end)

--// ============================================================
--//  PLAYER TOOLS
--// ============================================================
local function TpToTarget()
    local p = Players:FindFirstChild(Config.TargetName)
    local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if r then
        TpTo((r.CFrame * CFrame.new(0, 0, 4)).Position)
        return true
    end
    return false
end

--// ESP
local ESPHolder = Instance.new("Folder")
ESPHolder.Name = "RELWX_ESP"
pcall(function()
    ESPHolder.Parent = (gethui and gethui()) or game:GetService("CoreGui")
end)
if not ESPHolder.Parent then
    ESPHolder.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
local ESPItems = {}

local function ESPClear(p)
    local it = ESPItems[p]
    if it then
        it.hl:Destroy()
        it.bb:Destroy()
        ESPItems[p] = nil
    end
end

task.spawn(function()
    while true do
        local cam = workspace.CurrentCamera
        for _, p in ipairs(Players:GetPlayers()) do
            local c = p.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if p ~= LocalPlayer and On("ESPPlayers") and r then
                local it = ESPItems[p]
                if not it or it.target ~= c then
                    ESPClear(p)
                    local hl = Instance.new("Highlight")
                    hl.Adornee = c
                    hl.FillColor = Color3.fromRGB(255, 50, 50)
                    hl.OutlineColor = Color3.fromRGB(255, 50, 50)
                    hl.FillTransparency = 0.6
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = ESPHolder

                    local bb = Instance.new("BillboardGui")
                    bb.Size = UDim2.fromOffset(160, 32)
                    bb.StudsOffset = Vector3.new(0, 3.5, 0)
                    bb.AlwaysOnTop = true
                    bb.Adornee = r
                    bb.Parent = ESPHolder

                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.fromScale(1, 1)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 13
                    lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
                    lbl.TextStrokeTransparency = 0.3
                    lbl.Parent = bb

                    it = { hl = hl, bb = bb, lbl = lbl, target = c }
                    ESPItems[p] = it
                end
                local d = cam and math.floor((cam.CFrame.Position - r.Position).Magnitude) or 0
                it.lbl.Text = p.DisplayName .. "\n" .. d .. " m"
            else
                ESPClear(p)
            end
        end
        for p in pairs(ESPItems) do
            if not p.Parent then ESPClear(p) end
        end
        task.wait(0.25)
    end
end)

--// Movement / Fly / Noclip / GodMode
local Orig = {}
local Flying = false
local FlyBV, FlyBG

local function FlyStop()
    if FlyBV then FlyBV:Destroy() FlyBV = nil end
    if FlyBG then FlyBG:Destroy() FlyBG = nil end
    local h = Hum()
    if Flying and h then h.PlatformStand = false end
    Flying = false
end

RunService.RenderStepped:Connect(function()
    local hum, root = Hum(), Root()
    local cam = workspace.CurrentCamera
    if not (hum and root) then return end

    -- WalkSpeed
    if On("WalkSpeedOn") then
        Orig.walk = Orig.walk or hum.WalkSpeed
        hum.WalkSpeed = Config.WalkSpeedValue
    elseif Orig.walk then
        hum.WalkSpeed = Orig.walk
        Orig.walk = nil
    end

    -- JumpPower
    if On("JumpPowerOn") then
        if Orig.jump == nil then
            Orig.jump = hum.JumpPower
            Orig.useJump = hum.UseJumpPower
        end
        hum.UseJumpPower = true
        hum.JumpPower = Config.JumpPowerValue
    elseif Orig.jump ~= nil then
        hum.UseJumpPower = Orig.useJump
        hum.JumpPower = Orig.jump
        Orig.jump = nil
    end

    -- Fly
    if On("Fly") and cam then
        if not FlyBV then
            FlyBV = Instance.new("BodyVelocity")
            FlyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            FlyBV.Velocity = Vector3.zero
            FlyBV.Parent = root
            FlyBG = Instance.new("BodyGyro")
            FlyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            FlyBG.P = 9e4
            FlyBG.Parent = root
        end
        Flying = true
        hum.PlatformStand = true
        local dir = hum.MoveDirection
        local up = 0
        if UIS:IsKeyDown(Enum.KeyCode.E) or hum.Jump then up = up + 1 end
        if UIS:IsKeyDown(Enum.KeyCode.Q) then up = up - 1 end
        local v = Vector3.new(dir.X, up, dir.Z)
        FlyBV.Velocity = v.Magnitude > 0 and v.Unit * Config.FlySpeed or Vector3.zero
        FlyBG.CFrame = CFrame.new(root.Position, root.Position + cam.CFrame.LookVector)
    elseif Flying or FlyBV then
        FlyStop()
    end

    -- Camera spin
    if On("CameraSpin") and cam then
        cam.CFrame = cam.CFrame * CFrame.Angles(0, math.rad(Config.SpinSpeed), 0)
    end
end)

RunService.Heartbeat:Connect(function()
    local hum = Hum()
    if hum and On("GodMode") and hum.Health > 0 and hum.Health < hum.MaxHealth then
        hum.Health = hum.MaxHealth
    end
end)

RunService.Stepped:Connect(function()
    local c = LocalPlayer.Character
    if c and On("Noclip") then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end
end)

local function Unstuck()
    local r = Root()
    if not r then return end
    r.AssemblyLinearVelocity = Vector3.zero
    r.CFrame = r.CFrame + Vector3.new(0, 12, 0)
    local h = Hum()
    if h then
        h.PlatformStand = false
        h:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function TpSpawn()
    local sp = workspace:FindFirstChild("จุดเกิด")
    local part = sp and (sp:IsA("BasePart") and sp or sp:FindFirstChildWhichIsA("BasePart", true))
    if part then
        TpTo(part.Position)
        return true
    end
    return false
end

--// ============================================================
--//  FUN
--// ============================================================
local function ApplyHideName()
    local h = Hum()
    if h then
        h.DisplayDistanceType = On("HideName") and Enum.HumanoidDisplayDistanceType.None
            or Enum.HumanoidDisplayDistanceType.Viewer
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    ApplyHideName()
end)

local function RagdollSelf()
    local h, r = Hum(), Root()
    if h and r then
        h.PlatformStand = true
        r.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), 25, math.random(-20, 20))
        r.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-8, 8), math.random(-8, 8))
        task.delay(2, function()
            local h2 = Hum()
            if h2 and not Flying then
                h2.PlatformStand = false
                h2:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end
end

local function ResetChar()
    local h = Hum()
    if h then h.Health = 0 end
end

local function Rejoin()
    pcall(function()
        if #Players:GetPlayers() <= 1 then
            Teleport:Teleport(game.PlaceId, LocalPlayer)
        else
            Teleport:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
        end
    end)
end

local SpamSound = Instance.new("Sound")
SpamSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
SpamSound.Volume = 0.6
SpamSound.Parent = SoundSvc
task.spawn(function()
    while true do
        if On("SoundSpam") then SpamSound:Play() end
        task.wait(math.max(Config.SoundInterval, 0.1))
    end
end)

LocalPlayer.Idled:Connect(function()
    if On("AntiAFK") then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

--// ============================================================
--//  MacLib UI
--// ============================================================
local Window = MacLib:Window({
    Title       = "RELWX HUB",
    Subtitle    = "Lineage • Sailueatarchiwa",
    Size        = UDim2.fromOffset(868, 650),
    DragStyle   = 1,
    ShowUserInfo= true,
    Keybind     = Enum.KeyCode.RightControl,
    AcrylicBlur = true,
})

-- Global settings (กดปุ่ม globe ที่ sidebar)
Window:GlobalSetting({
    Name     = "UI Blur",
    Default  = true,
    Callback = function(v) Window:SetAcrylicBlurState(v) end,
})
Window:GlobalSetting({
    Name     = "Notifications",
    Default  = true,
    Callback = function(v) Window:SetNotificationsState(v) end,
})
Window:GlobalSetting({
    Name     = "PANIC — หยุดทุกอย่าง",
    Default  = false,
    Callback = function(v)
        if v then
            for k in pairs(Flags) do
                if type(Flags[k]) == "boolean" then Flags[k] = false end
            end
            Config.MasterOn = false
            FlyStop()
            ApplyHideName()
            Window:Notify({
                Title = "PANIC",
                Description = "หยุดทุกฟังก์ชันแล้ว (กดอีกครั้งเพื่อเปิดคืน)",
                Lifetime = 4,
            })
        else
            Config.MasterOn = true
            Flags.AntiAFK = true
        end
    end,
})

local TabGroup   = Window:TabGroup()
local FarmTab    = TabGroup:Tab({ Name = "ฟาร์ม" })
local WeaponTab  = TabGroup:Tab({ Name = "อาวุธ" })
local PlayerTab  = TabGroup:Tab({ Name = "ผู้เล่น" })
local FunTab     = TabGroup:Tab({ Name = "สนุกๆ" })
local ControlTab = TabGroup:Tab({ Name = "ควบคุม" })

--// ------------------------------------------------------------
--//  TAB: ฟาร์ม
--// ------------------------------------------------------------
local FarmL = FarmTab:Section({ Side = "Left" })
local FarmR = FarmTab:Section({ Side = "Right" })

FarmL:Header({ Text = "ออโต้ฟาร์มงาน" })

FarmL:Dropdown({
    Name     = "เลือกงาน",
    Multi    = false,
    Required = true,
    Options  = JobOptions,
    Default  = 1,
    Callback = function(v)
        Config.JobChoice = v or "ทั้งหมด"
        JobCache.t = 0
    end,
})

local FarmToggle
FarmToggle = FarmL:Toggle({
    Name     = "ออโต้ฟาร์มงาน",
    Default  = false,
    Callback = function(v) Flags.AutoFarm = v end,
})

FarmL:Toggle({
    Name     = "วาปไปจุดงานเอง",
    Default  = true,
    Callback = function(v) Config.FarmTP = v end,
})

FarmL:Button({
    Name     = "▶ เริ่มฟาร์ม",
    Callback = function()
        Flags.AutoFarm = true
        FarmToggle:UpdateState(true)
        Window:Notify({ Title = "RELWX", Description = "เริ่มออโต้ฟาร์ม", Lifetime = 2 })
    end,
})

FarmL:Button({
    Name     = "■ หยุดฟาร์ม",
    Callback = function()
        Flags.AutoFarm = false
        FarmToggle:UpdateState(false)
        Window:Notify({ Title = "RELWX", Description = "หยุดออโต้ฟาร์ม", Lifetime = 2 })
    end,
})

FarmL:Button({
    Name     = "วาปไปจุดงานที่เลือก",
    Callback = function()
        if TpToJob() then
            Window:Notify({ Title = "RELWX", Description = "วาปไปจุดงานแล้ว" })
        else
            Window:Notify({ Title = "RELWX", Description = "ไม่พบจุดงานนี้" })
        end
    end,
})

FarmL:Divider()

FarmL:Slider({
    Name      = "หน่วงระหว่างทำงาน",
    Default   = 0.5, Minimum = 0.1, Maximum = 3, Precision = 1,
    Suffix    = " s",
    Callback  = function(v) Config.FarmInterval = v end,
})
FarmL:Slider({
    Name      = "คูลดาวน์ต่อจุด",
    Default   = 4, Minimum = 1, Maximum = 15, Precision = 1,
    Suffix    = " s",
    Callback  = function(v) Config.PromptCooldown = v end,
})
FarmL:Slider({
    Name      = "หน่วงหลังวาป",
    Default   = 0.15, Minimum = 0.05, Maximum = 1, Precision = 2,
    Suffix    = " s",
    Callback  = function(v) Config.TpDelay = v end,
})

FarmR:Header({ Text = "ยิง Prompt / เก็บเหรียญ" })

FarmR:Toggle({
    Name     = "กด ProximityPrompt รอบตัวซ้ำๆ",
    Default  = false,
    Callback = function(v) Flags.PromptSpam = v end,
})
FarmR:Toggle({
    Name     = "ไม่ต้องกดค้าง",
    Default  = true,
    Callback = function(v) Config.InstantPrompt = v end,
})
FarmR:Slider({
    Name      = "ระยะกด Prompt",
    Default   = 20, Minimum = 5, Maximum = 60, Precision = 0,
    Suffix    = " studs",
    Callback  = function(v) Config.SpamRadius = v end,
})
FarmR:Slider({
    Name      = "ความถี่กด Prompt รอบตัว",
    Default   = 0.3, Minimum = 0.1, Maximum = 2, Precision = 1,
    Suffix    = " s",
    Callback  = function(v) Config.SpamInterval = v end,
})

FarmR:Divider()
FarmR:Header({ Text = "เก็บเหรียญ" })

FarmR:Toggle({
    Name     = "เก็บ Coin รอบแมพอัตโนมัติ",
    Default  = false,
    Callback = function(v) Flags.CoinCollect = v end,
})

--// ------------------------------------------------------------
--//  TAB: อาวุธ
--// ------------------------------------------------------------
local WepL = WeaponTab:Section({ Side = "Left" })

WepL:Header({ Text = "อาวุธของฉัน" })

WepL:Input({
    Name              = "ชื่ออาวุธ",
    Placeholder       = "ชื่อ Tool ใน Backpack",
    AcceptedCharacters= "All",
    Callback          = function(v) Config.ToolChoice = v end,
    onChanged         = function(v) Config.ToolChoice = v end,
})

WepL:Button({
    Name     = "ถืออาวุธที่เลือกทันที",
    Callback = function()
        if EquipSelected() then
            Window:Notify({ Title = "RELWX", Description = "ถืออาวุธแล้ว" })
        else
            Window:Notify({ Title = "RELWX", Description = "ไม่พบอาวุธที่เลือก" })
        end
    end,
})

WepL:Button({
    Name     = "ดูรายชื่ออาวุธ (แจ้งเตือน)",
    Callback = function()
        local list = ToolList()
        Window:Notify({
            Title       = "อาวุธใน Backpack",
            Description = table.concat(list, ", "),
            Lifetime    = 8,
        })
    end,
})

WepL:Toggle({
    Name     = "กระสุนไม่จำกัด (ฝั่งเรา)",
    Default  = false,
    Callback = function(v) Flags.UnlimitedAmmo = v end,
})

--// ------------------------------------------------------------
--//  TAB: ผู้เล่น
--// ------------------------------------------------------------
local PlL = PlayerTab:Section({ Side = "Left" })
local PlR = PlayerTab:Section({ Side = "Right" })

PlL:Header({ Text = "เป้าหมาย" })

PlL:Input({
    Name              = "ชื่อผู้เล่น",
    Placeholder       = "Username",
    AcceptedCharacters= "All",
    Callback          = function(v) Config.TargetName = v end,
    onChanged         = function(v) Config.TargetName = v end,
})

PlL:Button({
    Name     = "วาปไปหาผู้เล่น",
    Callback = function()
        if TpToTarget() then
            Window:Notify({ Title = "RELWX", Description = "วาปแล้ว" })
        else
            Window:Notify({ Title = "RELWX", Description = "ไม่พบผู้เล่น" })
        end
    end,
})

PlL:Divider()
PlL:Header({ Text = "การเคลื่อนที่" })

PlL:Toggle({
    Name     = "ปรับความเร็ววิ่ง",
    Default  = false,
    Callback = function(v) Flags.WalkSpeedOn = v end,
})
PlL:Slider({
    Name      = "WalkSpeed",
    Default   = 32, Minimum = 16, Maximum = 120, Precision = 0,
    Callback  = function(v) Config.WalkSpeedValue = v end,
})

PlL:Toggle({
    Name     = "ปรับแรงกระโดด",
    Default  = false,
    Callback = function(v) Flags.JumpPowerOn = v end,
})
PlL:Slider({
    Name      = "JumpPower",
    Default   = 80, Minimum = 50, Maximum = 250, Precision = 0,
    Callback  = function(v) Config.JumpPowerValue = v end,
})

PlR:Header({ Text = "บิน / Noclip / God" })

PlR:Toggle({
    Name     = "โหมดบิน (WASD/E/Q)",
    Default  = false,
    Callback = function(v)
        Flags.Fly = v
        if not v then FlyStop() end
    end,
})
PlR:Slider({
    Name      = "ความเร็วบิน",
    Default   = 60, Minimum = 10, Maximum = 200, Precision = 0,
    Callback  = function(v) Config.FlySpeed = v end,
})

PlR:Toggle({
    Name     = "ทะลุกำแพง (Noclip)",
    Default  = false,
    Callback = function(v) Flags.Noclip = v end,
})
PlR:Toggle({
    Name     = "อมตะ (ฟื้น HP ต่อเนื่อง)",
    Default  = false,
    Callback = function(v) Flags.GodMode = v end,
})

PlR:Divider()
PlR:Header({ Text = "ESP และช่วยเหลือ" })

PlR:Toggle({
    Name     = "ESP ผู้เล่น (สีแดง)",
    Default  = false,
    Callback = function(v) Flags.ESPPlayers = v end,
})

PlR:Button({
    Name     = "แก้ตัวละครติด (Unstuck)",
    Callback = function() Unstuck() end,
})

PlR:Button({
    Name     = "วาปไปจุดเกิด",
    Callback = function()
        if TpSpawn() then
            Window:Notify({ Title = "RELWX", Description = "วาปไปจุดเกิดแล้ว" })
        else
            Window:Notify({ Title = "RELWX", Description = "ไม่พบจุดเกิด" })
        end
    end,
})

PlR:Toggle({
    Name     = "กันหลุดเมื่อ AFK",
    Default  = true,
    Callback = function(v) Flags.AntiAFK = v end,
})

--// ------------------------------------------------------------
--//  TAB: สนุกๆ
--// ------------------------------------------------------------
local FunL = FunTab:Section({ Side = "Left" })
local FunR = FunTab:Section({ Side = "Right" })

FunL:Header({ Text = "ตัวละคร" })

FunL:Button({
    Name     = "Ragdoll 2 วินาที",
    Callback = function() RagdollSelf() end,
})
FunL:Button({
    Name     = "รีเซ็ตตัวละคร",
    Callback = function() ResetChar() end,
})
FunL:Toggle({
    Name     = "ซ่อนชื่อเหนือหัว",
    Default  = false,
    Callback = function(v)
        Flags.HideName = v
        ApplyHideName()
    end,
})

FunL:Divider()
FunL:Header({ Text = "กล้องและเสียง" })

FunL:Toggle({
    Name     = "กล้องหมุน",
    Default  = false,
    Callback = function(v) Flags.CameraSpin = v end,
})
FunL:Slider({
    Name      = "ความเร็วหมุน",
    Default   = 4, Minimum = 1, Maximum = 20, Precision = 0,
    Callback  = function(v) Config.SpinSpeed = v end,
})
FunL:Toggle({
    Name     = "เสียงรัว",
    Default  = false,
    Callback = function(v) Flags.SoundSpam = v end,
})
FunL:Slider({
    Name      = "ความถี่เสียง",
    Default   = 0.4, Minimum = 0.1, Maximum = 2, Precision = 1,
    Suffix    = " s",
    Callback  = function(v) Config.SoundInterval = v end,
})

FunR:Header({ Text = "เซิร์ฟเวอร์" })
FunR:Button({
    Name     = "เข้าเซิร์ฟเวอร์เดิมใหม่ (Rejoin)",
    Callback = function() Rejoin() end,
})

--// ------------------------------------------------------------
--//  TAB: ควบคุม
--// ------------------------------------------------------------
local CtrlL = ControlTab:Section({ Side = "Left" })
local CtrlR = ControlTab:Section({ Side = "Right" })

CtrlL:Header({ Text = "ปุ่มหลัก" })

local MasterToggle
MasterToggle = CtrlL:Toggle({
    Name     = "เปิดใช้งานทุกฟังก์ชัน (Master)",
    Default  = true,
    Callback = function(v)
        Config.MasterOn = v
        if not v then FlyStop() end
    end,
})

CtrlL:Button({
    Name     = "🛑 PANIC — หยุดทุกอย่าง",
    Callback = function()
        for k in pairs(Flags) do
            if type(Flags[k]) == "boolean" then Flags[k] = false end
        end
        Config.MasterOn = false
        if MasterToggle then MasterToggle:UpdateState(false) end
        FlyStop()
        ApplyHideName()
        Window:Notify({
            Title       = "PANIC",
            Description = "หยุดทุกฟังก์ชันแล้ว",
            Lifetime    = 4,
        })
    end,
})

CtrlL:Toggle({
    Name     = "Debug Log",
    Default  = false,
    Callback = function(v) Config.DebugLog = v end,
})

CtrlR:Header({ Text = "สถิติ" })

local StatPlayers = CtrlR:Label({ Text = "ผู้เล่น: -/-" })
local StatJob     = CtrlR:Label({ Text = "งาน: -" })
local StatCount   = CtrlR:Label({ Text = "จำนวนครั้งที่ฟาร์ม: 0" })
local StatTime    = CtrlR:Label({ Text = "เวลาฟาร์ม: -" })

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            StatPlayers:UpdateName(string.format("ผู้เล่น: %d/%d", #Players:GetPlayers(), Players.MaxPlayers))
            StatJob:UpdateName("งาน: " .. tostring(Config.JobChoice))
            StatCount:UpdateName("จำนวนครั้งที่ฟาร์ม: " .. tostring(Stats.farmCount))
            if Stats.farmStart and Flags.AutoFarm then
                local s = math.floor(os.clock() - Stats.farmStart)
                StatTime:UpdateName(string.format("เวลาฟาร์ม: %02d:%02d:%02d",
                    s // 3600, (s % 3600) // 60, s % 60))
            else
                StatTime:UpdateName("เวลาฟาร์ม: -")
            end
        end)
    end
end)

--// ------------------------------------------------------------
--//  START
--// ------------------------------------------------------------
FarmTab:Select()

Window:Notify({
    Title       = "RELWX HUB",
    Description = "โหลดฟังก์ชันสำเร็จ — กด RightControl เพื่อเปิด/ปิด",
    Lifetime    = 5,
})

print("[RELWX] MacLib Edition loaded")
