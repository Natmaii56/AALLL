--// ============================================================
--//  RELWX HUB  |  Durian Garden
--//  - ปรับขนาดตามหน้าจออัตโนมัติ (+ ปรับเพิ่ม/ลดเองได้ในตั้งค่า)
--//  - ทุกอย่างผูกกับ Config และเซฟอัตโนมัติ
--//  - เพิ่มฟังก์ชันใหม่: ดูหัวข้อ "ADD YOUR FUNCTIONS"
--// ============================================================

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")

-- ฟอนต์ UI  (เปลี่ยนได้: "Montserrat" | "BuilderSans" | "Gotham")
local UI_FONT = "Montserrat"
local function E(name)
    local ok, v = pcall(function()
        return Enum.Font[name]
    end)
    return ok and v or Enum.Font.Gotham
end
local FontFamilies = {
    Montserrat = { R = E("Montserrat"), M = E("MontserratMedium"), B = E("MontserratBold") },
    BuilderSans = { R = E("BuilderSans"), M = E("BuilderSansMedium"), B = E("BuilderSansBold") },
    Gotham = { R = Enum.Font.Gotham, M = Enum.Font.GothamMedium, B = Enum.Font.GothamBold },
}
local FNT = FontFamilies[UI_FONT] or FontFamilies.Gotham

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- เสียงตอนกดเปิด/ปิด (เปลี่ยน ID ได้ตามชอบ เช่น "rbxassetid://1234567")
local SOUND_ON = "rbxasset://sounds/switch.wav"
local SOUND_OFF = "rbxasset://sounds/button.wav"
local SOUND_FALLBACK = "rbxasset://sounds/electronicpingshort.wav" -- ใช้ถ้าเสียงข้างบนโหลดไม่ได้

--==================================================
-- CONFIG  (Auto Save / Auto Load)
--==================================================

local CONFIG_FILE = "RELWX_DURIAN_Config.json"

local Defaults = {
    -- สี
    UIAccentColor = "#C9CBD3",
    UIBackgroundColor = "#0A0A0C",
    UIButtonColor = "#232328",
    FloatingButtonColor = "#101012",
    FloatingBorderColor = "#E4E4EA",
    FloatingGlowColor = "#8E8E98",
    -- ฟังก์ชัน (ฟาร์มทุเรียน)
    AutoHarvest = false,
    AutoPlant = false,
    AutoWater = false,
    AutoSell = false,
    AutoSeed = false,
    AutoBag = false,
    AutoPads = false,
    AutoRebirth = false,
    ReturnHome = true,
    WaterEvery = 25,
    HarvestDelay = 120,
    SellEvery = 45,
    SeedEvery = 120,
    SeedBuyCount = 3,
    RebirthEvery = 30,
    TPSpeed = 400,
    GodAll = false,
    AntiAFK = false,
    AntiAFK2 = false,
    AntiKick = false,
    SafeMode = false,
    ESPFruit = false,
    FPSBoost = false,
    FullBright = false,
    RemoteLog = false,
    -- Durian Garden
    HarvestMethod = 1,
    CatchWait = 300,
    MutOnly = false,
    HT_Puangmanee = true,
    HT_Kradumthong = true,
    HT_Chanee = true,
    HT_Kanyao = true,
    WaterPerTree = 3,
    WaterSpeed = 120,
    SellTruck = false,
    SellSpeed = 180,
    SellPoint = "",
    BuyQty = 1,
    BuySeed_Kradumthong = true,
    BuySeed_Chanee = false,
    BuySeed_Puangmanee = false,
    BuySeed_Kanyao = false,
    BuySeed_Nokyip = false,
    BuySeed_Monthong = false,
    ESPMut = false,
    -- ระบบ
    SoundEnabled = true,
    StatsVisible = true,
    UIScalePercent = 100,
    -- สถานะ UI
    LastTab = "Home",
    WindowVisible = true,
    Maximized = false,
    CollapsedSections = "",
    WindowX = 0.5,
    WindowY = 0.5,
    FloatX = 0.04,
    FloatY = 0.25,
    StatsX = 0.5,
    StatsY = 0.045,
}

local Config = {}
for k, v in pairs(Defaults) do
    Config[k] = v
end

local LoadedFromFile = false

local function LoadConfig()
    if not (isfile and readfile) then
        return
    end
    local ok, exists = pcall(isfile, CONFIG_FILE)
    if not (ok and exists) then
        return
    end
    pcall(function()
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            for k, v in pairs(Defaults) do
                if type(data[k]) == type(v) then
                    Config[k] = data[k]
                end
            end
            LoadedFromFile = true
        end
    end)
end

LoadConfig()
for _, k in ipairs({ "WindowX", "WindowY" }) do
    Config[k] = math.clamp(Config[k], 0.05, 0.95)
end
for _, k in ipairs({ "FloatX", "FloatY", "StatsX", "StatsY" }) do
    Config[k] = math.clamp(Config[k], 0.02, 0.98)
end
Config.UIScalePercent = math.clamp(Config.UIScalePercent, 60, 120)

local SaveHooks = {}
local SaveToken = 0

local function Fire(state)
    for _, h in ipairs(SaveHooks) do
        pcall(h, state)
    end
end

local function WriteNow()
    if not writefile then
        return "unsupported"
    end
    local ok = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
    end)
    return ok and "saved" or "failed"
end

local function SaveConfig(instant)
    SaveToken = SaveToken + 1
    local token = SaveToken
    Fire("saving")
    local function commit()
        if token ~= SaveToken then
            return
        end
        local result = WriteNow()
        Fire(result)
        if result == "saved" then
            task.delay(1.8, function()
                if token == SaveToken then
                    Fire("idle")
                end
            end)
        end
    end
    if instant then
        commit()
    else
        task.delay(0.3, commit)
    end
end

local function SetConfig(key, value)
    if Config[key] == value then
        return
    end
    Config[key] = value
    SaveConfig()
end

--==================================================
-- THEME  (ทุกสีใน UI คำนวณจาก Config และอัปเดตสดทันที)
--==================================================

local function RGB(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function Lum(c)
    return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function Hex(key, fallback)
    local ok, c = pcall(Color3.fromHex, Config[key])
    return ok and c or fallback
end

local Theme = {}

local function ComputeTheme()
    local bg = Hex("UIBackgroundColor", RGB(8, 8, 8))
    local dark = Lum(bg) < 0.5
    local to = dark and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
    Theme.Bg = bg
    Theme.Surface = bg:Lerp(to, 0.05)
    Theme.Surface2 = bg:Lerp(to, 0.095)
    Theme.Stroke = bg:Lerp(to, 0.17)
    Theme.Text = dark and RGB(244, 244, 244) or RGB(20, 20, 20)
    Theme.Sub = Theme.Text:Lerp(bg, 0.32)
    Theme.Muted = Theme.Text:Lerp(bg, 0.58)
    Theme.Accent = Hex("UIAccentColor", RGB(190, 190, 190))
    Theme.OnAccent = Lum(Theme.Accent) > 0.55 and RGB(15, 15, 15) or RGB(255, 255, 255)
    Theme.Button = Hex("UIButtonColor", RGB(36, 36, 36))
    local h, s, v = Theme.Accent:ToHSV()
    if s < 0.12 then
        Theme.Accent2 = Theme.Accent:Lerp(Color3.fromRGB(96, 104, 128), 0.6) -- เทา: ไล่เป็นเหล็กอมฟ้า
    else
        Theme.Accent2 = Color3.fromHSV((h + 0.12) % 1, s, math.max(v, 0.6))
    end
end

ComputeTheme()

local ThemeHooks = {}

local function OnTheme(fn)
    ThemeHooks[#ThemeHooks + 1] = fn
    pcall(fn)
end

local function Bind(obj, prop, key)
    OnTheme(function()
        obj[prop] = Theme[key]
    end)
end

local function ApplyTheme()
    ComputeTheme()
    for _, fn in ipairs(ThemeHooks) do
        pcall(fn)
    end
end

--==================================================
-- HELPERS
--==================================================

local Orders = setmetatable({}, { __mode = "k" })
local function Next(parent)
    Orders[parent] = (Orders[parent] or 0) + 1
    return Orders[parent]
end

local function New(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props or {}) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local function Corner(parent, radius)
    return New("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function Stroke(parent, color, thickness, transparency)
    return New("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function Pad(parent, l, r, t, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
    }, parent)
end

local function List(parent, padding)
    return New("UIListLayout", {
        Padding = UDim.new(0, padding or 0),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, parent)
end

local function Text(parent, text, size, font, color, align)
    local l = New("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = text or "",
        TextSize = size or 13,
        Font = font or FNT.R,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    if type(color) == "string" then
        Bind(l, "TextColor3", color)
    elseif color then
        l.TextColor3 = color
    end
    return l
end

local function Tween(obj, t, props, style, dir)
    local tw = TweenService:Create(
        obj,
        TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    )
    tw:Play()
    return tw
end

local function Apply(obj, animate, props)
    if animate then
        Tween(obj, 0.16, props)
    else
        for k, v in pairs(props) do
            obj[k] = v
        end
    end
end

local function Panel(parent, size, class)
    local f = New(class or "Frame", { BorderSizePixel = 0, LayoutOrder = Next(parent) }, parent)
    if class == "TextButton" then
        f.Text = ""
        f.AutoButtonColor = false
    end
    if size then
        f.Size = size
    end
    Bind(f, "BackgroundColor3", "Surface")
    Corner(f, 12)
    Bind(Stroke(f, Theme.Stroke, 1, 0.4), "Color", "Stroke")
    New("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.76, 0.76, 0.76)),
        Rotation = 90,
    }, f)
    local hi = New("Frame", {
        Size = UDim2.new(1, -28, 0, 1),
        Position = UDim2.fromOffset(14, 0),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.9,
        BorderSizePixel = 0,
    }, f)
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, hi)
    return f
end

local function HoverRow(btn)
    local st = btn:FindFirstChildOfClass("UIStroke")
    btn.MouseEnter:Connect(function()
        Tween(btn, 0.12, { BackgroundColor3 = Theme.Surface2 })
        if st then
            Tween(st, 0.12, { Transparency = 0.05 })
        end
    end)
    local sc
    if btn:IsA("GuiButton") then
        sc = New("UIScale", { Scale = 1 }, btn)
        btn.MouseButton1Down:Connect(function()
            Tween(sc, 0.08, { Scale = 0.982 })
        end)
        btn.MouseButton1Up:Connect(function()
            Tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
        end)
    end
    btn.MouseLeave:Connect(function()
        Tween(btn, 0.12, { BackgroundColor3 = Theme.Surface })
        if st then
            Tween(st, 0.12, { Transparency = 0.4 })
        end
        if sc then
            Tween(sc, 0.12, { Scale = 1 })
        end
    end)
end

-- ชั้นสีไล่เฉดอ่อนๆ ของ accent ใช้ตกแต่งการ์ด
-- ไล่เฉด Accent -> Accent2 (วัตถุที่ใช้ต้องตั้ง BackgroundColor3 เป็นสีขาว)
local function AccentGrad(parent, rotation)
    local g = New("UIGradient", { Rotation = rotation or 0 }, parent)
    OnTheme(function()
        g.Color = ColorSequence.new(Theme.Accent, Theme.Accent2)
    end)
    return g
end

local function Tint(parent)
    local t = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, parent)
    Corner(t, 12)
    local g = AccentGrad(t, 25)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.8),
        NumberSequenceKeypoint.new(1, 1),
    })
    return t
end

local function IsPointer(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

-- ไอคอนวาดด้วย Frame (ไม่พึ่งรูป/asset) คืนค่าฟังก์ชันเปลี่ยนสี
local function Icon(parent, kind, x, y)
    local box = New("Frame", {
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(x, y),
        BackgroundTransparency = 1,
    }, parent)
    local parts = {}
    local function rect(px, py, w, h, r, rot)
        local f = New("Frame", {
            Size = UDim2.fromOffset(w, h),
            Position = UDim2.fromOffset(px, py),
            BorderSizePixel = 0,
            Rotation = rot or 0,
        }, box)
        Corner(f, r or 1)
        parts[#parts + 1] = { f = f }
        return f
    end
    if kind == "grid" then
        rect(1, 1, 7, 7, 2)
        rect(10, 1, 7, 7, 2)
        rect(1, 10, 7, 7, 2)
        rect(10, 10, 7, 7, 2)
    elseif kind == "sliders" then
        rect(1, 2, 16, 2, 1)
        rect(1, 8, 11, 2, 1)
        rect(1, 14, 14, 2, 1)
    elseif kind == "close" then
        rect(1, 8, 16, 2, 1, 45)
        rect(1, 8, 16, 2, 1, -45)
    elseif kind == "max" then
        local r = New("Frame", {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.fromOffset(3, 3),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, box)
        Corner(r, 3)
        parts[#parts + 1] = { stroke = Stroke(r, Color3.new(1, 1, 1), 2, 0) }
    else -- ring (settings)
        local r = New("Frame", {
            Size = UDim2.fromOffset(16, 16),
            Position = UDim2.fromOffset(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, box)
        Corner(r, 8)
        parts[#parts + 1] = { stroke = Stroke(r, Color3.new(1, 1, 1), 2, 0) }
        rect(7, 7, 4, 4, 2)
    end
    return function(c)
        for _, p in ipairs(parts) do
            if p.stroke then
                p.stroke.Color = c
            else
                p.f.BackgroundColor3 = c
            end
        end
    end
end

--==================================================
-- ROOT GUI
--==================================================

pcall(function()
    for _, v in ipairs(PlayerGui:GetChildren()) do
        if v.Name == "RELWX_UI" or v.Name == "RELWX_Floating" or v.Name == "RELWX_Stats"
            or v.Name == "TwoSki_RideAPet_Floating" then
            v:Destroy()
        end
    end
end)

local Screen = New("ScreenGui", {
    Name = "RELWX_UI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999998,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui)

-- เก็บ connection ทั้งหมดไว้ ตัดทิ้งตอน UI ถูกทำลาย (รันสคริปต์ซ้ำได้ไม่ค้าง)
local Conns = {}
local function Track(c)
    Conns[#Conns + 1] = c
    return c
end
Screen.Destroying:Connect(function()
    for _, c in ipairs(Conns) do
        pcall(function()
            c:Disconnect()
        end)
    end
end)

local BW, BH = 740, 580 -- ขนาดออกแบบ (ปรับตามจอผ่าน UIScale)
local SW = 172 -- ความกว้าง sidebar

local function ViewSize()
    local s = Screen.AbsoluteSize
    if s.X > 0 and s.Y > 0 then
        return s
    end
    return workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
end

local function TargetScale()
    local v = ViewSize()
    local fit = math.min(v.X * 0.97 / BW, v.Y * 0.95 / BH)
    local base = math.min(fit * (Config.Maximized and 1 or 0.92), Config.Maximized and 1.4 or 1.1)
    local s = base * (Config.UIScalePercent / 100)
    return math.clamp(s, 0.3, math.max(0.3, fit))
end

local Main = New("CanvasGroup", {
    Name = "Main",
    Size = UDim2.fromOffset(BW, BH),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.WindowX, Config.WindowY),
    BorderSizePixel = 0,
    BackgroundTransparency = 0.04,
    GroupTransparency = 1,
    Active = true,
    Visible = false,
}, Screen)
Bind(Main, "BackgroundColor3", "Bg")
Corner(Main, 18)

-- แสงพื้นหลัง (aurora) มุมซ้ายบน / ขวาล่าง
local function Aurora(key, rot)
    local f = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, Main)
    Bind(f, "BackgroundColor3", key)
    Corner(f, 18)
    New("UIGradient", {
        Rotation = rot,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.82),
            NumberSequenceKeypoint.new(0.55, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, f)
end
Aurora("Accent", 35)
Aurora("Accent2", 215)

-- ฝุ่นแสงลอยช้าๆ เป็นพื้นหลัง
local Dust = New("Frame", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ClipsDescendants = true,
}, Main)
for i = 1, 16 do
    local sz = math.random(2, 4)
    local x = math.random()
    local p = New("Frame", {
        Size = UDim2.fromOffset(sz, sz),
        Position = UDim2.fromScale(x, 1.05),
        BorderSizePixel = 0,
        BackgroundTransparency = 0.55 + math.random() * 0.3,
    }, Dust)
    Corner(p, 2)
    Bind(p, "BackgroundColor3", (i % 2 == 0) and "Accent" or "Accent2")
    local dur = 9 + math.random() * 9
    TweenService:Create(
        p,
        TweenInfo.new(dur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, false, math.random() * 5),
        { Position = UDim2.fromScale(math.clamp(x + (math.random() - 0.5) * 0.15, 0, 1), -0.05) }
    ):Play()
end

local MainStroke = Stroke(Main, Color3.new(1, 1, 1), 1.5, 0)
local MainGrad = New("UIGradient", { Rotation = 0 }, MainStroke)
OnTheme(function()
    MainGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Stroke),
        ColorSequenceKeypoint.new(0.35, Theme.Accent),
        ColorSequenceKeypoint.new(0.65, Theme.Accent2),
        ColorSequenceKeypoint.new(1, Theme.Stroke),
    })
end)
TweenService:Create(
    MainGrad,
    TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
    { Rotation = 360 }
):Play()
local MainScale = New("UIScale", { Scale = TargetScale() }, Main)

-- เงา + แสงเรืองใต้หน้าต่าง
local Shadow = New("Frame", {
    Size = UDim2.fromOffset(BW, BH),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    ZIndex = 0,
    Visible = false,
}, Screen)
local ShadowScale = New("UIScale", { Scale = 1 }, Shadow)
local ShadowLayers = {}
for i, g in ipairs({ 8, 20, 36, 56 }) do
    local l = New("Frame", {
        Size = UDim2.new(1, g * 2, 1, g * 2),
        Position = UDim2.fromOffset(-g, -g + 10),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(0, 0, 0),
    }, Shadow)
    Corner(l, 18 + g)
    ShadowLayers[i] = { f = l, base = 0.82 + i * 0.03 }
end
local ShadowGlow = New("Frame", {
    Size = UDim2.new(1, 40, 1, 40),
    Position = UDim2.fromOffset(-20, -20),
    BorderSizePixel = 0,
}, Shadow)
Corner(ShadowGlow, 38)
Bind(ShadowGlow, "BackgroundColor3", "Accent")
ShadowLayers[#ShadowLayers + 1] = { f = ShadowGlow, base = 0.95 }

Track(RunService.RenderStepped:Connect(function()
    local vis = Main.Visible
    Shadow.Visible = vis
    if not vis then
        return
    end
    Shadow.Position = Main.Position
    Shadow.Size = Main.Size
    ShadowScale.Scale = MainScale.Scale
    local a = Main.GroupTransparency
    for _, l in ipairs(ShadowLayers) do
        l.f.BackgroundTransparency = 1 - (1 - l.base) * (1 - a)
    end
end))

-- เส้นแสงด้านบนหน้าต่าง
local TopGlow = New("Frame", {
    Size = UDim2.new(0.8, 0, 0, 1),
    Position = UDim2.fromScale(0.1, 0),
    BorderSizePixel = 0,
}, Main)
Bind(TopGlow, "BackgroundColor3", "Accent")
New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    }),
}, TopGlow)

local Opening = false

local function ApplyScale(animate)
    if Opening then
        return
    end
    if animate and Main.Visible then
        Tween(MainScale, 0.25, { Scale = TargetScale() }, Enum.EasingStyle.Quint)
    else
        MainScale.Scale = TargetScale()
    end
end

Track(Screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    ApplyScale(false)
end))

-- เปิด/ปิดหน้าต่างพร้อมเอฟเฟกต์ (ปิดแบบสโลว์: ค่อยๆ จางและหดลง)
-- เสียงเปิด/ปิด (ถ้าไฟล์เสียงโหลดไม่ขึ้น จะสลับไปใช้เสียงสำรองให้เอง)
local function PlayToggleSound(on, big)
    if not Config.SoundEnabled then
        return
    end
    pcall(function()
        local function play(id, vol, speed)
            local s = Instance.new("Sound")
            s.SoundId = id
            s.Volume = vol
            s.PlaybackSpeed = speed
            s.Parent = SoundService
            s:Play()
            Debris:AddItem(s, 2.5)
            return s
        end
        local speed = (on and 1.18 or 0.86) * (big and 0.85 or 1)
        local s = play(on and SOUND_ON or SOUND_OFF, big and 0.7 or 0.6, speed)
        task.delay(0.35, function()
            if s.Parent and s.TimeLength == 0 then
                play(SOUND_FALLBACK, 0.55, on and 1.35 or 0.85)
            end
        end)
    end)
end

-- ===== FX: วงคลื่น / ประกายไฟ / ลำแสง =====
local function FloatCenter()
    local s = Screen.AbsoluteSize
    return s.X * Config.FloatX, s.Y * Config.FloatY
end

local function FxRing(cx, cy, size, thick, dur, color)
    local r = New("Frame", {
        Size = UDim2.fromOffset(6, 6),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cx, cy),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 60,
    }, Screen)
    Corner(r, 9999)
    local st = Stroke(r, color or Theme.Accent, thick, 0.05)
    Tween(r, dur, { Size = UDim2.fromOffset(size, size) }, Enum.EasingStyle.Quint)
    Tween(st, dur, { Transparency = 1, Thickness = 0.5 }, Enum.EasingStyle.Quad)
    Debris:AddItem(r, dur + 0.15)
end

local function FxSparks(cx, cy, spread, count, dist)
    for i = 1, count do
        local ang = math.random() * math.pi * 2
        local d = dist * (0.45 + math.random() * 0.8)
        local sz = math.random(3, 6)
        local px = cx + (math.random() - 0.5) * spread
        local col = (i % 3 == 0) and Color3.new(1, 1, 1) or ((i % 2 == 0) and Theme.Accent or Theme.Accent2)
        local p = New("Frame", {
            Size = UDim2.fromOffset(sz, sz),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(px, cy),
            BorderSizePixel = 0,
            BackgroundColor3 = col,
            ZIndex = 61,
        }, Screen)
        Corner(p, 3)
        local dur = 0.45 + math.random() * 0.45
        Tween(p, dur, {
            Position = UDim2.fromOffset(px + math.cos(ang) * d, cy + math.sin(ang) * d * 0.85),
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(1, 1),
        }, Enum.EasingStyle.Quint)
        Debris:AddItem(p, dur + 0.15)
    end
end

local function FxBeam(cx, cy, w)
    local b = New("Frame", {
        Size = UDim2.fromOffset(w, 4),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cx, cy),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 62,
    }, Screen)
    New("UICorner", { CornerRadius = UDim.new(0.5, 0) }, b)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Theme.Accent2),
            ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
            ColorSequenceKeypoint.new(1, Theme.Accent),
        }),
    }, b)
    Stroke(b, Theme.Accent, 5, 0.65)
    Debris:AddItem(b, 2)
    return b
end

local AnimToken = 0

-- เปิด: บินออกจากปุ่ม RX แล้วขยายเป็นหน้าต่าง + วงคลื่น
local function PlayOpen()
    AnimToken = AnimToken + 1
    local token = AnimToken
    Opening = true
    local t = TargetScale()
    local fx, fy = FloatCenter()

    MainStroke.Thickness = 1.5
    Main.Size = UDim2.fromOffset(BW, BH)
    Main.Position = UDim2.fromOffset(fx, fy)
    Main.GroupTransparency = 1
    MainScale.Scale = t * 0.12
    Main.Visible = true

    PlayToggleSound(true, true)
    FxRing(fx, fy, 120, 3, 0.55)
    FxSparks(fx, fy, 6, 12, 60)

    Tween(Main, 0.3, { GroupTransparency = 0 })
    Tween(Main, 0.6, { Position = UDim2.fromScale(Config.WindowX, Config.WindowY) }, Enum.EasingStyle.Quint)
    Tween(MainScale, 0.65, { Scale = t }, Enum.EasingStyle.Back)

    task.delay(0.5, function()
        if token ~= AnimToken then
            return
        end
        local ap, asz = Main.AbsolutePosition, Main.AbsoluteSize
        FxRing(ap.X + asz.X / 2, ap.Y + asz.Y / 2, math.max(asz.X, asz.Y) * 1.05, 2, 0.7, Theme.Accent2)
    end)
    task.delay(0.68, function()
        if token == AnimToken then
            Opening = false
        end
    end)
end

-- ปิด: ตัวหน้าต่างพองเล็กน้อย -> ยุบเป็นเส้นแสง -> หดเป็นจุด + ประกายไฟ -> บินเข้าปุ่ม RX แล้วปล่อยคลื่น
local function PlayClose()
    AnimToken = AnimToken + 1
    local token = AnimToken
    Opening = true
    PlayToggleSound(false, true)

    local s0 = MainScale.Scale
    local function alive()
        return token == AnimToken
    end

    -- 1) พองเล็กน้อย + ขอบสว่างวาบ
    Tween(MainScale, 0.14, { Scale = s0 * 1.03 }, Enum.EasingStyle.Sine)
    Tween(MainStroke, 0.3, { Thickness = 3.5 }, Enum.EasingStyle.Sine)

    -- 2) ยุบแนวตั้งเป็นเส้นบางๆ
    task.delay(0.14, function()
        if not alive() then
            return
        end
        Tween(Main, 0.36, { Size = UDim2.fromOffset(BW, 5) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        Tween(MainScale, 0.36, { Scale = s0 * 0.97 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
    end)

    -- 3) เส้นแสงวาบ -> หดเป็นจุด + วงคลื่น + ประกายไฟ
    task.delay(0.5, function()
        if not alive() then
            return
        end
        local ap, asz = Main.AbsolutePosition, Main.AbsoluteSize
        local cx, cy = ap.X + asz.X / 2, ap.Y + asz.Y / 2
        local w = math.max(asz.X, 40)

        Main.Visible = false
        Main.Size = UDim2.fromOffset(BW, BH)
        Main.Position = UDim2.fromScale(Config.WindowX, Config.WindowY)
        MainScale.Scale = s0
        MainStroke.Thickness = 1.5

        local beam = FxBeam(cx, cy, w)
        FxRing(cx, cy, w * 0.75, 3, 0.6)
        FxRing(cx, cy, w * 0.45, 2, 0.5, Theme.Accent2)
        FxSparks(cx, cy, w, 28, 150 * math.max(s0, 0.6))
        Tween(beam, 0.26, { Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)

        -- 4) จุดแสงบินเข้าปุ่ม RX
        task.delay(0.28, function()
            local fx, fy = FloatCenter()
            Tween(beam, 0.36, {
                Position = UDim2.fromOffset(fx, fy),
                Size = UDim2.fromOffset(8, 8),
            }, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
            task.delay(0.36, function()
                beam:Destroy()
                FxRing(fx, fy, 100, 3, 0.55)
                FxSparks(fx, fy, 6, 12, 50)
                if alive() then
                    Opening = false
                end
            end)
        end)
    end)
end

local function SetWindow(visible)
    SetConfig("WindowVisible", visible)
    if visible then
        PlayOpen()
    else
        PlayClose()
    end
end

-- ลากหน้าต่าง/ปุ่ม/วิดเจ็ต แล้วเซฟตำแหน่งเป็นสัดส่วนหน้าจอ
local function SavePosition(target, kx, ky)
    local s = Screen.AbsoluteSize
    if s.X <= 0 or s.Y <= 0 then
        return
    end
    local c = target.AbsolutePosition + target.AbsoluteSize / 2
    local fx = math.clamp(c.X / s.X, 0.02, 0.98)
    local fy = math.clamp(c.Y / s.Y, 0.02, 0.98)
    target.Position = UDim2.fromScale(fx, fy)
    SetConfig(kx, math.floor(fx * 10000) / 10000)
    SetConfig(ky, math.floor(fy * 10000) / 10000)
end

local function MakeDraggable(handle, target, kx, ky, onClick)
    local dragging, dragInput, startPos, startCenter, moved = false, nil, nil, nil, false

    handle.InputBegan:Connect(function(input)
        if IsPointer(input) then
            dragging = true
            moved = false
            dragInput = input
            startPos = input.Position
            startCenter = target.AbsolutePosition + target.AbsoluteSize / 2
        end
    end)

    Track(UIS.InputChanged:Connect(function(input)
        if not dragging or not IsMove(input) then
            return
        end
        if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
            return
        end
        local d = input.Position - startPos
        if d.Magnitude > 8 then
            moved = true
        end
        if moved then
            local s = Screen.AbsoluteSize
            target.Position = UDim2.fromOffset(
                math.clamp(startCenter.X + d.X, 0, s.X),
                math.clamp(startCenter.Y + d.Y, 0, s.Y)
            )
        end
    end))

    Track(UIS.InputEnded:Connect(function(input)
        if dragging and IsPointer(input) then
            if input.UserInputType == Enum.UserInputType.Touch and input ~= dragInput then
                return
            end
            dragging = false
            if moved then
                SavePosition(target, kx, ky)
            elseif onClick then
                onClick()
            end
        end
    end))
end

-- แจ้งเตือนเล็กๆ ด้านล่างจอ (Toast)
local ActiveToast
local function Toast(text, on)
    if ActiveToast then
        ActiveToast:Destroy()
        ActiveToast = nil
    end
    local t = New("TextLabel", {
        Size = UDim2.fromOffset(0, 38),
        AutomaticSize = Enum.AutomaticSize.X,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, 48),
        BorderSizePixel = 0,
        Text = text,
        TextSize = 12,
        Font = FNT.M,
        BackgroundColor3 = Theme.Surface2,
        TextColor3 = Theme.Text,
        ZIndex = 300,
    }, Screen)
    Corner(t, 19)
    Stroke(t, Theme.Accent, 1, 0.55)
    Pad(t, 38, 18, 0, 0)
    local dot = New("Frame", {
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.new(0, -24, 0.5, -4),
        BorderSizePixel = 0,
        BackgroundColor3 = (on == true) and RGB(70, 200, 120) or (on == false and Theme.Muted or Theme.Accent),
    }, t)
    Corner(dot, 4)
    ActiveToast = t
    Tween(t, 0.35, { Position = UDim2.new(0.5, 0, 1, -26) }, Enum.EasingStyle.Back)
    task.delay(1.7, function()
        if ActiveToast == t then
            Tween(t, 0.25, { Position = UDim2.new(0.5, 0, 1, 48) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(0.3, function()
                t:Destroy()
                if ActiveToast == t then
                    ActiveToast = nil
                end
            end)
        end
    end)
end

--==================================================
-- SAVE STATUS PILL
--==================================================

local SaveStates = {
    idle = { "Auto Save", nil },
    saving = { "กำลังบันทึก...", RGB(240, 190, 60) },
    saved = { "บันทึกแล้ว", RGB(70, 200, 120) },
    failed = { "บันทึกไม่ได้", RGB(235, 75, 90) },
    unsupported = { "ไม่รองรับไฟล์", RGB(235, 75, 90) },
}

local function StatusPill(parent, width)
    local pill = New("Frame", { Size = UDim2.fromOffset(width or 108, 26), BorderSizePixel = 0 }, parent)
    Bind(pill, "BackgroundColor3", "Surface2")
    Corner(pill, 13)
    Bind(Stroke(pill, Theme.Stroke, 1, 0.3), "Color", "Stroke")

    local dot = New("Frame", {
        Size = UDim2.fromOffset(8, 8),
        Position = UDim2.new(0, 11, 0.5, -4),
        BorderSizePixel = 0,
    }, pill)
    Corner(dot, 4)

    local label = Text(pill, "", 10, FNT.M, "Sub")
    label.Position = UDim2.fromOffset(26, 0)
    label.Size = UDim2.new(1, -30, 1, 0)

    local current = "idle"
    local function render()
        local s = SaveStates[current]
        label.Text = s[1]
        dot.BackgroundColor3 = s[2] or Theme.Accent
    end
    OnTheme(render)

    SaveHooks[#SaveHooks + 1] = function(state)
        current = state
        render()
    end
    return pill
end

--==================================================
-- FPS / MS WIDGET (เล็ก ลากได้ แยกจากหน้าต่างหลัก)
--==================================================

local StatsGui = New("ScreenGui", {
    Name = "RELWX_Stats",
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    IgnoreGuiInset = true,
    Enabled = Config.StatsVisible,
}, PlayerGui)

local StatsBox = New("Frame", {
    Size = UDim2.fromOffset(152, 30),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.StatsX, Config.StatsY),
    BorderSizePixel = 0,
    BackgroundTransparency = 0.1,
    Active = true,
}, StatsGui)
Bind(StatsBox, "BackgroundColor3", "Surface")
Corner(StatsBox, 15)
Bind(Stroke(StatsBox, Theme.Stroke, 1, 0.2), "Color", "Stroke")

local FpsLabel = Text(StatsBox, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Center)
FpsLabel.RichText = true
FpsLabel.Size = UDim2.new(0.5, -1, 1, 0)

local MsLabel = Text(StatsBox, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Center)
MsLabel.RichText = true
MsLabel.Position = UDim2.new(0.5, 1, 0, 0)
MsLabel.Size = UDim2.new(0.5, -1, 1, 0)

local StatsDivider = New("Frame", {
    Size = UDim2.fromOffset(1, 14),
    Position = UDim2.new(0.5, 0, 0.5, -7),
    BorderSizePixel = 0,
}, StatsBox)
Bind(StatsDivider, "BackgroundColor3", "Stroke")

MakeDraggable(StatsBox, StatsBox, "StatsX", "StatsY")

local Metrics = { fps = 60, ping = 0 }

do
    local frames, acc = 0, 0
    Track(RunService.RenderStepped:Connect(function(dt)
        frames = frames + 1
        acc = acc + dt
        if acc >= 0.5 then
            Metrics.fps = math.floor(frames / acc + 0.5)
            frames, acc = 0, 0
        end
    end))
end

local function GetPing()
    local ok, v = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return (ok and type(v) == "number") and math.floor(v + 0.5) or 0
end

local function Level(value, good, mid, higherIsBetter)
    local g, m, b = RGB(70, 200, 120), RGB(240, 190, 60), RGB(235, 75, 90)
    if higherIsBetter then
        return value >= good and g or (value >= mid and m or b)
    end
    return value <= good and g or (value <= mid and m or b)
end

local function RefreshStats()
    Metrics.ping = GetPing()
    local fc = Level(Metrics.fps, 50, 30, true)
    local mc = Level(Metrics.ping, 80, 160, false)
    local muted = "#" .. Theme.Muted:ToHex()
    FpsLabel.Text = string.format(
        '<font color="#%s"><b>%d</b></font> <font color="%s">FPS</font>',
        fc:ToHex(), Metrics.fps, muted
    )
    MsLabel.Text = string.format(
        '<font color="#%s"><b>%d</b></font> <font color="%s">MS</font>',
        mc:ToHex(), Metrics.ping, muted
    )
end

--==================================================
-- TOP BAR
--==================================================

local Top = New("Frame", {
    Size = UDim2.new(1, 0, 0, 60),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, Main)

local TopLine = New("Frame", {
    Size = UDim2.new(1, -24, 0, 1),
    Position = UDim2.new(0, 12, 1, -1),
    BorderSizePixel = 0,
    BackgroundColor3 = Color3.new(1, 1, 1),
}, Top)
do
    local g = AccentGrad(TopLine, 0)
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.95),
        NumberSequenceKeypoint.new(0.5, 0.15),
        NumberSequenceKeypoint.new(1, 0.95),
    })
end

Top.ClipsDescendants = true
local Shine = New("Frame", {
    Size = UDim2.new(0, 120, 1, 0),
    Position = UDim2.new(-0.3, 0, 0, 0),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
}, Top)
New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.93),
        NumberSequenceKeypoint.new(1, 1),
    }),
}, Shine)
TweenService:Create(
    Shine,
    TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 4),
    { Position = UDim2.new(1.1, 0, 0, 0) }
):Play()

local Badge = New("Frame", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.fromOffset(16, 13),
    BorderSizePixel = 0,
}, Top)
Badge.BackgroundColor3 = Color3.new(1, 1, 1)
AccentGrad(Badge, 45)
Corner(Badge, 10)
Bind(Stroke(Badge, Theme.Accent, 1.5, 0.65), "Color", "Accent")
local BadgeText = Text(Badge, "RX", 13, FNT.B, nil, Enum.TextXAlignment.Center)
BadgeText.Size = UDim2.fromScale(1, 1)
Bind(BadgeText, "TextColor3", "OnAccent")

local Brand = Text(Top, "", 15, FNT.B, "Text")
Brand.RichText = true
OnTheme(function()
    Brand.Text = 'RELWX <font color="#' .. Theme.Accent:ToHex() .. '">HUB</font>'
end)
Brand.Position = UDim2.fromOffset(60, 10)
Brand.Size = UDim2.new(1, -270, 0, 22)

local BrandSub = Text(Top, tostring(game.Name or ""), 10, FNT.R, "Muted")
BrandSub.Position = UDim2.fromOffset(60, 31)
BrandSub.Size = UDim2.new(1, -270, 0, 16)

local function WindowButton(kind, xOffset, danger)
    local b = New("TextButton", {
        Size = UDim2.fromOffset(32, 32),
        Position = UDim2.new(1, xOffset, 0.5, -16),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, Top)
    Corner(b, 10)
    Bind(b, "BackgroundColor3", "Surface2")
    local paint = Icon(b, kind, 7, 7)
    OnTheme(function()
        paint(Theme.Sub)
    end)
    b.MouseEnter:Connect(function()
        Tween(b, 0.12, { BackgroundColor3 = danger and RGB(200, 70, 80) or Theme.Button })
        paint(danger and RGB(255, 255, 255) or Theme.Text)
    end)
    b.MouseLeave:Connect(function()
        Tween(b, 0.12, { BackgroundColor3 = Theme.Surface2 })
        paint(Theme.Sub)
    end)
    return b
end

local MaxBtn = WindowButton("max", -86, false)
local CloseBtn = WindowButton("close", -48, true)
CloseBtn.MouseButton1Click:Connect(function()
    SetWindow(false)
end)

MakeDraggable(Top, Main, "WindowX", "WindowY")

MaxBtn.MouseButton1Click:Connect(function()
    SetConfig("Maximized", not Config.Maximized)
    SetConfig("WindowX", 0.5)
    SetConfig("WindowY", 0.5)
    Tween(Main, 0.3, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
    ApplyScale(true)
end)

--==================================================
-- SIDEBAR (หมวดหมู่)
--==================================================

local Rail = New("Frame", {
    Size = UDim2.new(0, SW, 1, -80),
    Position = UDim2.fromOffset(12, 68),
    BorderSizePixel = 0,
}, Main)
Bind(Rail, "BackgroundColor3", "Surface")
Corner(Rail, 14)
Bind(Stroke(Rail, Theme.Stroke, 1, 0.4), "Color", "Stroke")

local CatList = New("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -80),
    Position = UDim2.fromOffset(8, 10),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    ScrollBarImageTransparency = 0.3,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never,
}, Rail)
Bind(CatList, "ScrollBarImageColor3", "Accent")
List(CatList, 4)
Pad(CatList, 0, 4, 1, 1)

local UserBox = New("Frame", {
    Size = UDim2.new(1, -16, 0, 52),
    Position = UDim2.new(0, 8, 1, -60),
    BorderSizePixel = 0,
}, Rail)
Bind(UserBox, "BackgroundColor3", "Surface2")
Corner(UserBox, 12)

local Avatar = New("ImageLabel", {
    Size = UDim2.fromOffset(34, 34),
    Position = UDim2.new(0, 9, 0.5, -17),
    BorderSizePixel = 0,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=60&h=60",
}, UserBox)
Corner(Avatar, 17)
Bind(Avatar, "BackgroundColor3", "Button")
Bind(Stroke(Avatar, Theme.Accent, 1.5, 0.2), "Color", "Accent")
Bind(Stroke(UserBox, Theme.Stroke, 1, 0.5), "Color", "Stroke")
local Online = New("Frame", {
    Size = UDim2.fromOffset(10, 10),
    Position = UDim2.new(0, 36, 0.5, 7),
    BorderSizePixel = 0,
    BackgroundColor3 = RGB(70, 200, 120),
    ZIndex = 3,
}, UserBox)
Corner(Online, 5)
Bind(Stroke(Online, Theme.Surface2, 2, 0), "Color", "Surface2")

local UName = Text(UserBox, LocalPlayer.DisplayName, 12, FNT.B, "Text")
UName.Position = UDim2.fromOffset(52, 9)
UName.Size = UDim2.new(1, -58, 0, 18)
local UTag = Text(UserBox, "@" .. LocalPlayer.Name, 10, FNT.R, "Muted")
UTag.Position = UDim2.fromOffset(52, 27)
UTag.Size = UDim2.new(1, -58, 0, 14)

local Pages = {}
local TabList = {}

local function CatGroup(name)
    local l = Text(CatList, name, 10, FNT.B, "Muted")
    l.Size = UDim2.new(1, 0, 0, 26)
    l.LayoutOrder = Next(CatList)
    Pad(l, 10, 0, 6, 0)
    return l
end

local CurrentTab = nil
local function SelectTab(id)
    if not Pages[id] then
        id = "Home"
    end
    SetConfig("LastTab", id)
    local changed = id ~= CurrentTab
    CurrentTab = id
    for pid, page in pairs(Pages) do
        page.Visible = (pid == id)
    end
    if changed then
        local p = Pages[id]
        p.Position = UDim2.fromOffset(0, 16)
        Tween(p, 0.32, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
    end
    for _, t in ipairs(TabList) do
        t.active = (t.id == id)
        t.paint()
    end
end

local function Category(name, id, iconKind)
    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = Next(CatList),
    }, CatList)
    Corner(b, 11)
    local bst = Stroke(b, Theme.Accent, 1, 1)

    local ind = New("Frame", {
        Size = UDim2.fromOffset(3, 8),
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 4, 0.5, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, b)
    Corner(ind, 2)

    local setIcon = Icon(b, iconKind, 16, 12)

    local lbl = Text(b, name, 13, FNT.M)
    lbl.Position = UDim2.fromOffset(44, 0)
    lbl.Size = UDim2.new(1, -48, 1, 0)
    lbl.TextColor3 = Theme.Sub

    local tab = { id = id, active = false, hover = false }
    function tab.paint()
        Tween(b, 0.15, {
            BackgroundColor3 = tab.active and Theme.Accent or Theme.Button,
            BackgroundTransparency = tab.active and 0.84 or (tab.hover and 0.5 or 1),
        })
        Tween(bst, 0.15, { Color = Theme.Accent, Transparency = tab.active and 0.55 or 1 })
        Tween(lbl, 0.15, { TextColor3 = tab.active and Theme.Text or Theme.Sub })
        Tween(ind, 0.15, {
            BackgroundColor3 = Theme.Accent,
            BackgroundTransparency = tab.active and 0 or 1,
            Size = tab.active and UDim2.fromOffset(3, 22) or UDim2.fromOffset(3, 8),
        })
        setIcon(tab.active and Theme.Accent or Theme.Sub)
    end
    TabList[#TabList + 1] = tab
    OnTheme(tab.paint)

    b.MouseEnter:Connect(function()
        tab.hover = true
        tab.paint()
    end)
    b.MouseLeave:Connect(function()
        tab.hover = false
        tab.paint()
    end)
    b.MouseButton1Click:Connect(function()
        SelectTab(id)
    end)
    return b
end

--==================================================
-- PAGES
--==================================================

local Body = New("Frame", {
    Size = UDim2.new(1, -(SW + 36), 1, -80),
    Position = UDim2.fromOffset(SW + 24, 68),
    BackgroundTransparency = 1,
}, Main)

local function MakePage(id, title, subtitle)
    local page = New("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
    }, Body)
    Bind(page, "ScrollBarImageColor3", "Stroke")
    List(page, 8)
    Pad(page, 0, 8, 0, 14)

    local head = New("Frame", {
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
        LayoutOrder = Next(page),
    }, page)
    local t = Text(head, title, 22, FNT.B, "Text")
    t.Size = UDim2.new(1, 0, 0, 28)
    local s = Text(head, subtitle or "", 11, FNT.R, "Muted")
    s.Position = UDim2.fromOffset(0, 29)
    s.Size = UDim2.new(1, 0, 0, 18)
    local hb = New("Frame", {
        Size = UDim2.fromOffset(36, 3),
        Position = UDim2.fromOffset(0, 53),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, head)
    Corner(hb, 2)
    AccentGrad(hb, 0)

    Pages[id] = page
    return page
end

-- Section แบบพับ/ขยายได้ (จำสถานะไว้ใน Config)
local Collapsed = {}
for id in string.gmatch(Config.CollapsedSections, "[^|]+") do
    Collapsed[id] = true
end
local function SaveCollapsed()
    local t = {}
    for id, v in pairs(Collapsed) do
        if v then
            t[#t + 1] = id
        end
    end
    table.sort(t)
    SetConfig("CollapsedSections", table.concat(t, "|"))
end

local SectionsByPage = {}
local CurrentSection = nil

local function Section(page, title)
    local hdr = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        LayoutOrder = Next(page),
    }, page)

    local bar = New("Frame", {
        Size = UDim2.fromOffset(3, 14),
        Position = UDim2.new(0, 2, 0.5, -7),
        BorderSizePixel = 0,
    }, hdr)
    Corner(bar, 2)
    bar.BackgroundColor3 = Color3.new(1, 1, 1)
    AccentGrad(bar, 90)

    local hl = New("Frame", {
        Size = UDim2.new(1, -4, 0, 1),
        Position = UDim2.new(0, 2, 1, -1),
        BorderSizePixel = 0,
    }, hdr)
    Bind(hl, "BackgroundColor3", "Stroke")
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, hl)

    local label = Text(hdr, title, 13, FNT.B, "Text")
    label.Position = UDim2.fromOffset(14, 0)
    label.Size = UDim2.new(1, -44, 1, 0)

    -- ลูกศร (วาดด้วยเส้น 2 เส้น)
    local chev = New("Frame", {
        Size = UDim2.fromOffset(14, 14),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        BackgroundTransparency = 1,
    }, hdr)
    local c1 = New("Frame", {
        Size = UDim2.fromOffset(8, 2), Position = UDim2.fromOffset(1, 6), Rotation = 45, BorderSizePixel = 0,
    }, chev)
    local c2 = New("Frame", {
        Size = UDim2.fromOffset(8, 2), Position = UDim2.fromOffset(6, 6), Rotation = -45, BorderSizePixel = 0,
    }, chev)
    Corner(c1, 1)
    Corner(c2, 1)
    OnTheme(function()
        c1.BackgroundColor3 = Theme.Muted
        c2.BackgroundColor3 = Theme.Muted
    end)

    local sec = { label = hdr, items = {}, collapsed = Collapsed[title] == true }
    function sec.refresh(animate)
        for _, it in ipairs(sec.items) do
            it.frame.Visible = it.matched and not sec.collapsed
        end
        local rot = sec.collapsed and -90 or 0
        if animate then
            Tween(chev, 0.18, { Rotation = rot })
        else
            chev.Rotation = rot
        end
    end
    sec.refresh(false)

    hdr.MouseButton1Click:Connect(function()
        sec.collapsed = not sec.collapsed
        Collapsed[title] = sec.collapsed
        SaveCollapsed()
        sec.refresh(true)
    end)

    CurrentSection = sec
    SectionsByPage[page] = SectionsByPage[page] or {}
    table.insert(SectionsByPage[page], sec)
    return sec
end

local function Register(row, search)
    local sec = CurrentSection
    if sec then
        table.insert(sec.items, { frame = row, search = string.lower(search or ""), matched = true })
        sec.refresh(false)
    end
end

local Refreshers = {}

--==================================================
-- COMPONENTS: Toggle / Slider / ColorRow
--==================================================

local FuncToggles = {}
local UpdateSummary = function() end

local function Toggle(page, opts)
    local row = Panel(page, UDim2.new(1, 0, 0, 64), "TextButton")
    HoverRow(row)
    Register(row, opts.title .. " " .. (opts.desc or ""))
    local rowStroke = row:FindFirstChildOfClass("UIStroke")

    local title = Text(row, opts.title, 13, FNT.M, "Text")
    title.Position = UDim2.fromOffset(18, 11)
    title.Size = UDim2.new(1, -96, 0, 20)

    local desc = Text(row, opts.desc or "", 11, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(18, 33)
    desc.Size = UDim2.new(1, -96, 0, 18)

    local strip = New("Frame", {
        Size = UDim2.fromOffset(3, 26),
        Position = UDim2.new(0, 4, 0.5, -13),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, row)
    Corner(strip, 2)
    AccentGrad(strip, 90)

    local glow = New("Frame", {
        Size = UDim2.fromOffset(62, 40),
        Position = UDim2.new(1, -71, 0.5, -20),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, row)
    Corner(glow, 20)
    AccentGrad(glow, 0)

    local track = New("Frame", {
        Size = UDim2.fromOffset(48, 26),
        Position = UDim2.new(1, -64, 0.5, -13),
        BorderSizePixel = 0,
    }, row)
    Corner(track, 13)
    local tStroke = Stroke(track, Theme.Stroke, 1, 0.2)
    Bind(tStroke, "Color", "Stroke")

    local fill = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
    }, track)
    Corner(fill, 13)
    AccentGrad(fill, 0)

    local knob = New("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = UDim2.fromOffset(3, 3),
        BorderSizePixel = 0,
    }, track)
    Corner(knob, 10)

    local state = Config[opts.key] == true

    if page ~= Pages["Settings"] and page ~= Pages["Home"] then
        FuncToggles[#FuncToggles + 1] = function()
            return state
        end
    end

    local function render(animate)
        Apply(track, animate, { BackgroundColor3 = Theme.Button })
        Apply(fill, animate, { BackgroundTransparency = state and 0 or 1 })
        Apply(glow, animate, { BackgroundTransparency = state and 0.82 or 1 })
        Apply(knob, animate, {
            Position = state and UDim2.fromOffset(25, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = state and Theme.OnAccent or Theme.Sub,
        })
        Apply(strip, animate, { BackgroundTransparency = state and 0 or 1 })
        Apply(tStroke, animate, { Color = state and Theme.Accent or Theme.Stroke })
        if rowStroke then
            Apply(rowStroke, animate, {
                Color = state and Theme.Accent or Theme.Stroke,
                Transparency = state and 0.55 or 0.4,
            })
        end
        UpdateSummary()
    end
    OnTheme(function()
        render(false)
    end)

    local function set(v, fire)
        state = v
        SetConfig(opts.key, v)
        render(true)
        if fire then
            PlayToggleSound(v)
            if opts.callback then
                task.spawn(opts.callback, v)
            end
        end
    end

    row.MouseButton1Click:Connect(function()
        set(not state, true)
    end)

    Refreshers[#Refreshers + 1] = function()
        state = Config[opts.key] == true
        render(false)
        if opts.callback then
            task.spawn(opts.callback, state)
        end
    end

    if opts.callback then
        task.defer(opts.callback, state)
    end

    return {
        Get = function()
            return state
        end,
        Set = function(v)
            set(v, true)
        end,
    }
end

local function Slider(page, opts)
    local min, max, step = opts.min, opts.max, opts.step or 1
    local row = Panel(page, UDim2.new(1, 0, 0, 78))
    Register(row, opts.title .. " " .. (opts.desc or ""))

    local title = Text(row, opts.title, 13, FNT.M, "Text")
    title.Position = UDim2.fromOffset(16, 10)
    title.Size = UDim2.new(1, -110, 0, 20)

    local desc = Text(row, opts.desc or "", 11, FNT.R, "Muted")
    desc.Position = UDim2.fromOffset(16, 31)
    desc.Size = UDim2.new(1, -110, 0, 16)

    local pill = New("Frame", {
        Size = UDim2.fromOffset(82, 22),
        Position = UDim2.new(1, -98, 0, 9),
        BorderSizePixel = 0,
    }, row)
    Corner(pill, 11)
    Bind(pill, "BackgroundColor3", "Surface2")
    Bind(Stroke(pill, Theme.Accent, 1, 0.6), "Color", "Accent")
    local val = Text(row, "", 12, FNT.B, "Accent", Enum.TextXAlignment.Center)
    val.Position = UDim2.new(1, -98, 0, 9)
    val.Size = UDim2.fromOffset(82, 22)

    local bar = New("Frame", {
        Size = UDim2.new(1, -32, 0, 6),
        Position = UDim2.fromOffset(16, 60),
        BorderSizePixel = 0,
    }, row)
    Corner(bar, 3)
    Bind(bar, "BackgroundColor3", "Button")

    local fill = New("Frame", {
        Size = UDim2.fromScale(0, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, bar)
    Corner(fill, 3)
    AccentGrad(fill, 0)

    local knob = New("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        BorderSizePixel = 0,
    }, bar)
    Corner(knob, 8)
    Bind(knob, "BackgroundColor3", "Text")
    Bind(Stroke(knob, Theme.Accent, 3, 0), "Color", "Accent")

    local hit = New("TextButton", {
        Size = UDim2.new(1, -32, 0, 30),
        Position = UDim2.fromOffset(16, 48),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, row)

    local value = Config[opts.key]

    local function show()
        local a = (value - min) / (max - min)
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.fromScale(a, 0.5)
        val.Text = string.format("%g", value) .. (opts.suffix or "")
    end

    local function setValue(v, fire)
        v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
        if v == value and fire then
            return
        end
        value = v
        show()
        if fire then
            SetConfig(opts.key, v)
            if opts.callback then
                task.spawn(opts.callback, v)
            end
        end
    end

    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        setValue(min + (max - min) * a, true)
    end

    hit.InputBegan:Connect(function(input)
        if IsPointer(input) then
            dragging = true
            page.ScrollingEnabled = false
            Tween(knob, 0.12, { Size = UDim2.fromOffset(21, 21) })
            fromX(input.Position.X)
        end
    end)
    Track(UIS.InputChanged:Connect(function(input)
        if dragging and IsMove(input) then
            fromX(input.Position.X)
        end
    end))
    Track(UIS.InputEnded:Connect(function(input)
        if dragging and IsPointer(input) then
            dragging = false
            page.ScrollingEnabled = true
            Tween(knob, 0.12, { Size = UDim2.fromOffset(16, 16) })
        end
    end))

    value = math.clamp(value, min, max)
    show()

    Refreshers[#Refreshers + 1] = function()
        value = math.clamp(Config[opts.key], min, max)
        show()
        if opts.callback then
            task.spawn(opts.callback, value)
        end
    end

    if opts.callback then
        task.defer(opts.callback, value)
    end
end

-- ============================================================
--  COLOR PICKER v2  (สี่เหลี่ยมเฉด + แถบ Hue + HEX + พรีเซ็ต)
--  เปลี่ยนสีแล้วเซฟอัตโนมัติผ่าน SetConfig เหมือนเดิม
-- ============================================================
local PaletteColors = {
    "FFFFFF", "BEBEBE", "6B6B76", "2A2A33", "0E0E14", "000000", "8B5CF6", "6366F1",
    "3B82F6", "22D3EE", "10B981", "84CC16", "FACC15", "FB923C", "EF4444", "EC4899",
}

local ActiveOverlay, ActivePopup
local PaletteConns = {}

local function ClosePalette()
    for _, c in ipairs(PaletteConns) do
        pcall(function()
            c:Disconnect()
        end)
    end
    PaletteConns = {}
    if ActiveOverlay then
        ActiveOverlay:Destroy()
        ActiveOverlay = nil
    end
    if ActivePopup then
        ActivePopup:Destroy()
        ActivePopup = nil
    end
end

-- รวมการอัปเดตธีมให้เหลือครั้งเดียวต่อเฟรม (ลากสีแล้วไม่หน่วง)
local themePending = false
local function QueueTheme()
    if themePending then
        return
    end
    themePending = true
    task.defer(function()
        themePending = false
        ApplyTheme()
    end)
end

local function OpenPalette(title, key, onPick)
    ClosePalette()

    ActiveOverlay = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 150,
    }, Screen)
    Tween(ActiveOverlay, 0.2, { BackgroundTransparency = 0.45 })
    ActiveOverlay.MouseButton1Click:Connect(ClosePalette)

    local PW, PH = 240, 304
    local pop = New("CanvasGroup", {
        Size = UDim2.fromOffset(PW, PH),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel = 0,
        GroupTransparency = 1,
        ZIndex = 160,
        Active = true,
    }, Screen)
    Corner(pop, 16)
    Stroke(pop, Theme.Accent, 1.5, 0.35)
    local vs = ViewSize()
    New("UIScale", { Scale = math.clamp((vs.Y - 24) / PH, 0.5, 1) }, pop)
    ActivePopup = pop
    Tween(pop, 0.2, { GroupTransparency = 0 })

    -- สีเริ่มต้นจาก Config
    local okc, c0 = pcall(Color3.fromHex, Config[key])
    if not okc then
        c0 = Color3.new(1, 1, 1)
    end
    local H, S, V = c0:ToHSV()

    -- หัวข้อ + พรีวิว + ปุ่มปิด
    local ttl = Text(pop, title or "เลือกสี", 13, FNT.B, Theme.Text)
    ttl.Position = UDim2.fromOffset(14, 10)
    ttl.Size = UDim2.new(1, -130, 0, 20)

    local prev = New("Frame", {
        Size = UDim2.fromOffset(36, 18),
        Position = UDim2.fromOffset(PW - 82, 11),
        BorderSizePixel = 0,
    }, pop)
    Corner(prev, 6)
    Stroke(prev, Color3.new(1, 1, 1), 1, 0.75)

    local closeB = New("TextButton", {
        Size = UDim2.fromOffset(24, 24),
        Position = UDim2.fromOffset(PW - 38, 8),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "×",
        TextSize = 18,
        Font = FNT.B,
        TextColor3 = Theme.Sub,
        AutoButtonColor = false,
    }, pop)
    Corner(closeB, 8)
    closeB.MouseButton1Click:Connect(ClosePalette)

    -- สี่เหลี่ยมเลือก Saturation / Value
    local sv = New("Frame", {
        Size = UDim2.fromOffset(PW - 28, 124),
        Position = UDim2.fromOffset(14, 40),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.fromHSV(H, 1, 1),
    }, pop)
    Corner(sv, 10)
    local wf = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, sv)
    Corner(wf, 10)
    New("UIGradient", { Transparency = NumberSequence.new(0, 1) }, wf)
    local bf = New("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(0, 0, 0),
    }, sv)
    Corner(bf, 10)
    New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }, bf)
    local svCur = New("Frame", {
        Size = UDim2.fromOffset(16, 16),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, sv)
    Corner(svCur, 8)
    Stroke(svCur, Color3.new(1, 1, 1), 2.5, 0)
    local svHit = New("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, sv)

    -- แถบ Hue
    local hue = New("Frame", {
        Size = UDim2.fromOffset(PW - 28, 14),
        Position = UDim2.fromOffset(14, 176),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, pop)
    Corner(hue, 7)
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
        }),
    }, hue)
    local hueCur = New("Frame", {
        Size = UDim2.fromOffset(18, 18),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BorderSizePixel = 0,
    }, hue)
    Corner(hueCur, 9)
    Stroke(hueCur, Color3.new(1, 1, 1), 2.5, 0)
    local hueHit = New("TextButton", {
        Size = UDim2.new(1, 0, 1, 12),
        Position = UDim2.fromOffset(0, -6),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    }, hue)

    -- ช่อง HEX
    local box = New("TextBox", {
        Size = UDim2.fromOffset(PW - 28, 30),
        Position = UDim2.fromOffset(14, 202),
        BackgroundColor3 = Theme.Surface2,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "#RRGGBB",
        ClearTextOnFocus = false,
        TextSize = 12,
        Font = FNT.M,
        TextColor3 = Theme.Text,
        PlaceholderColor3 = Theme.Muted,
    }, pop)
    Corner(box, 9)
    Stroke(box, Theme.Stroke, 1, 0.3)

    local function render(fromBox)
        local c = Color3.fromHSV(H, S, V)
        sv.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        svCur.Position = UDim2.fromScale(S, 1 - V)
        hueCur.Position = UDim2.fromScale(H, 0.5)
        hueCur.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
        prev.BackgroundColor3 = c
        if not fromBox then
            box.Text = "#" .. string.upper(c:ToHex())
        end
        return c
    end
    local function commit(fromBox)
        onPick(render(fromBox))
    end
    render(false)

    -- ลาก (รองรับเมาส์/ทัช, ชดเชย GuiInset อัตโนมัติ)
    local function bindDrag(hit, onMove)
        local dragging, dInput = false, nil
        local off = Vector2.zero
        hit.InputBegan:Connect(function(input)
            if not IsPointer(input) then
                return
            end
            local p = Vector2.new(input.Position.X, input.Position.Y)
            local a, sz = hit.AbsolutePosition, hit.AbsoluteSize
            local inset = GuiService:GetGuiInset()
            local q = p + inset
            local inside = q.X >= a.X and q.X <= a.X + sz.X and q.Y >= a.Y and q.Y <= a.Y + sz.Y
            off = inside and inset or Vector2.zero
            dragging = true
            dInput = input
            onMove(p + off)
        end)
        PaletteConns[#PaletteConns + 1] = UIS.InputChanged:Connect(function(input)
            if dragging and IsMove(input) then
                if input.UserInputType == Enum.UserInputType.Touch and input ~= dInput then
                    return
                end
                onMove(Vector2.new(input.Position.X, input.Position.Y) + off)
            end
        end)
        PaletteConns[#PaletteConns + 1] = UIS.InputEnded:Connect(function(input)
            if dragging and IsPointer(input) then
                if input.UserInputType == Enum.UserInputType.Touch and input ~= dInput then
                    return
                end
                dragging = false
            end
        end)
    end

    bindDrag(svHit, function(pos)
        S = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
        V = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
        commit(false)
    end)
    bindDrag(hueHit, function(pos)
        H = math.clamp((pos.X - hue.AbsolutePosition.X) / math.max(1, hue.AbsoluteSize.X), 0, 1)
        commit(false)
    end)

    box.FocusLost:Connect(function()
        local h = string.match(box.Text, "^%s*#?(%x%x%x%x%x%x)%s*$")
        if h then
            H, S, V = Color3.fromHex(h):ToHSV()
            commit(false)
        else
            box.TextColor3 = RGB(235, 75, 90)
            task.delay(0.8, function()
                if box.Parent then
                    box.TextColor3 = Theme.Text
                    render(false)
                end
            end)
        end
    end)

    -- สีสำเร็จรูป
    for i, hexv in ipairs(PaletteColors) do
        local c = Color3.fromHex(hexv)
        local sw = New("TextButton", {
            Size = UDim2.fromOffset(22, 22),
            Position = UDim2.fromOffset(14 + ((i - 1) % 8) * 27, 244 + math.floor((i - 1) / 8) * 28),
            BackgroundColor3 = c,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
        }, pop)
        Corner(sw, 11)
        Stroke(sw, Color3.new(1, 1, 1), 1, 0.8)
        sw.MouseButton1Click:Connect(function()
            H, S, V = c:ToHSV()
            commit(false)
        end)
    end
end

local ColorRefreshers = {}

local function ColorRow(page, title, key)
    local row = Panel(page, UDim2.new(1, 0, 0, 50), "TextButton")
    HoverRow(row)
    Register(row, title)

    local t = Text(row, title, 12, FNT.M, "Text")
    t.Position = UDim2.fromOffset(18, 0)
    t.Size = UDim2.new(1, -176, 1, 0)

    local hexLabel = Text(row, "", 10, FNT.M, "Muted", Enum.TextXAlignment.Right)
    hexLabel.Position = UDim2.new(1, -152, 0, 0)
    hexLabel.Size = UDim2.fromOffset(84, 50)

    local swatch = New("Frame", {
        Size = UDim2.fromOffset(44, 24),
        Position = UDim2.new(1, -60, 0.5, -12),
        BorderSizePixel = 0,
    }, row)
    Corner(swatch, 8)
    Stroke(swatch, Color3.new(1, 1, 1), 1, 0.7)

    local function refresh()
        swatch.BackgroundColor3 = Hex(key, RGB(100, 100, 100))
        hexLabel.Text = string.upper(tostring(Config[key]))
    end
    refresh()
    Refreshers[#Refreshers + 1] = refresh
    ColorRefreshers[#ColorRefreshers + 1] = refresh

    row.MouseButton1Click:Connect(function()
        OpenPalette(title, key, function(c)
            SetConfig(key, "#" .. string.upper(c:ToHex()))
            refresh()
            QueueTheme()
        end)
    end)
end

-- ธีมสำเร็จรูป: แตะครั้งเดียวเปลี่ยนทั้ง UI + ปุ่ม RX (เซฟอัตโนมัติ)
local ThemePresets = {
    { "Graphite", "#C9CBD3", "#0A0A0C", "#232328" },
    { "Violet", "#8B5CF6", "#09090D", "#1C1C26" },
    { "Crimson", "#F43F5E", "#0B0708", "#26151A" },
    { "Cyber", "#22D3EE", "#06090C", "#122029" },
    { "Toxic", "#4ADE80", "#060A07", "#13211A" },
    { "Sunset", "#FB923C", "#0C0805", "#271A10" },
}

local function ThemeGrid(page)
    local holder = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = Next(page),
    }, page)
    New("UIGridLayout", {
        CellSize = UDim2.new(1 / 3, -7, 0, 56),
        CellPadding = UDim2.fromOffset(10, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, holder)
    Register(holder, "ธีม theme preset สำเร็จรูป")

    for _, p in ipairs(ThemePresets) do
        local card = Panel(holder, nil, "TextButton")
        HoverRow(card)

        local function dot(hex, x)
            local d = New("Frame", {
                Size = UDim2.fromOffset(22, 22),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, x, 0.5, 0),
                BorderSizePixel = 0,
                BackgroundColor3 = Color3.fromHex(hex),
            }, card)
            Corner(d, 11)
            Stroke(d, Color3.new(1, 1, 1), 1, 0.8)
        end
        dot(p[3], 12)
        dot(p[4], 24)
        dot(p[2], 36)

        local n = Text(card, p[1], 12, FNT.M, "Text")
        n.Position = UDim2.fromOffset(68, 0)
        n.Size = UDim2.new(1, -74, 1, 0)

        card.MouseButton1Click:Connect(function()
            SetConfig("UIAccentColor", p[2])
            SetConfig("UIBackgroundColor", p[3])
            SetConfig("UIButtonColor", p[4])
            SetConfig("FloatingButtonColor", p[3])
            SetConfig("FloatingBorderColor", p[2])
            SetConfig("FloatingGlowColor", p[2])
            for _, fn in ipairs(ColorRefreshers) do
                pcall(fn)
            end
            QueueTheme()
            Toast("ใช้ธีม " .. p[1])
        end)
    end
end

--==================================================
-- HOME
--==================================================

local Home = MakePage("Home", "หน้าหลัก", "ภาพรวมและข้อมูลเซิร์ฟเวอร์")

-- การ์ดต้อนรับ
local Hero = Panel(Home, UDim2.new(1, 0, 0, 84))
Tint(Hero)
local HeroSub = Text(Hero, "", 11, FNT.M, "Muted")
HeroSub.Position = UDim2.fromOffset(20, 14)
HeroSub.Size = UDim2.new(0.6, 0, 0, 16)
local HeroName = Text(Hero, LocalPlayer.DisplayName, 24, FNT.B, Color3.new(1, 1, 1))
HeroName.Position = UDim2.fromOffset(20, 32)
HeroName.Size = UDim2.new(0.6, 0, 0, 38)
AccentGrad(HeroName, 0)
local HeroClock = Text(Hero, "", 26, FNT.B, "Text", Enum.TextXAlignment.Right)
HeroClock.Position = UDim2.new(0.5, 0, 0, 16)
HeroClock.Size = UDim2.new(0.5, -20, 0, 34)
local HeroDate = Text(Hero, "", 10, FNT.M, "Muted", Enum.TextXAlignment.Right)
HeroDate.Position = UDim2.new(0.5, 0, 0, 52)
HeroDate.Size = UDim2.new(0.5, -20, 0, 16)

-- การ์ดแมพ (รูปไอคอนแมพจริงจาก Roblox)
local MapImage = "rbxthumb://type=GameIcon&id=" .. tostring(game.GameId) .. "&w=150&h=150"

local MapCard = Panel(Home, UDim2.new(1, 0, 0, 116))
MapCard.ClipsDescendants = true

local MapBG = New("ImageLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Image = MapImage,
    ScaleType = Enum.ScaleType.Crop,
    ImageTransparency = 0.86,
}, MapCard)
Corner(MapBG, 12)

local MapFade = New("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, MapCard)
Bind(MapFade, "BackgroundColor3", "Surface")
New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0.7),
    }),
}, MapFade)
Corner(MapFade, 12)
Tint(MapCard)

local MapIcon = New("ImageLabel", {
    Size = UDim2.fromOffset(84, 84),
    Position = UDim2.fromOffset(16, 16),
    BorderSizePixel = 0,
    Image = MapImage,
    ScaleType = Enum.ScaleType.Crop,
}, MapCard)
Corner(MapIcon, 16)
Bind(MapIcon, "BackgroundColor3", "Button")
Bind(Stroke(MapIcon, Theme.Stroke, 1.5, 0.1), "Color", "Stroke")

local MapName = Text(MapCard, tostring(game.Name or "Unknown"), 17, FNT.B, "Text")
MapName.Position = UDim2.fromOffset(112, 16)
MapName.Size = UDim2.new(1, -128, 0, 26)

local MapBy = Text(MapCard, "กำลังโหลดข้อมูลแมพ...", 11, FNT.R, "Muted")
MapBy.Position = UDim2.fromOffset(112, 43)
MapBy.Size = UDim2.new(1, -128, 0, 16)

local Chips = New("Frame", {
    Size = UDim2.new(1, -128, 0, 24),
    Position = UDim2.fromOffset(112, 72),
    BackgroundTransparency = 1,
}, MapCard)
New("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Chips)

local function Chip(text)
    local c = New("TextLabel", {
        Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
        Text = text,
        TextSize = 10,
        Font = FNT.M,
        LayoutOrder = Next(Chips),
    }, Chips)
    Bind(c, "BackgroundColor3", "Surface2")
    Bind(c, "TextColor3", "Sub")
    Corner(c, 12)
    Pad(c, 10, 10, 0, 0)
    return c
end

local ChipPlace = Chip("ID " .. tostring(game.PlaceId))
local ChipPlayers = Chip("ผู้เล่น -/-")

task.spawn(function()
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info then
            if info.Name and info.Name ~= "" then
                MapName.Text = tostring(info.Name)
                BrandSub.Text = tostring(info.Name)
            end
            if info.Creator and info.Creator.Name then
                MapBy.Text = "โดย " .. tostring(info.Creator.Name)
            else
                MapBy.Text = ""
            end
        end
    end)
end)

local function Stat(parent, label, size)
    local c = Panel(parent, size)
    local bar = New("Frame", {
        Size = UDim2.fromOffset(3, 18),
        Position = UDim2.fromOffset(0, 12),
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
    }, c)
    Corner(bar, 2)
    AccentGrad(bar, 90)
    local l = Text(c, label, 10, FNT.M, "Muted")
    l.Position = UDim2.fromOffset(16, 11)
    l.Size = UDim2.new(1, -30, 0, 14)
    local v = Text(c, "-", 14, FNT.B, "Text")
    v.Position = UDim2.fromOffset(16, 30)
    v.Size = UDim2.new(1, -30, 0, 22)
    return v
end

local Grid = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    LayoutOrder = Next(Home),
}, Home)
New("UIGridLayout", {
    CellSize = UDim2.new(0.5, -5, 0, 64),
    CellPadding = UDim2.fromOffset(10, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Grid)

local StatPlayer = Stat(Grid, "ผู้เล่น")
local StatTime = Stat(Grid, "เวลาในเซิร์ฟ")
local StatFps = Stat(Grid, "FPS")
local StatPing = Stat(Grid, "Ping")

-- กราฟ FPS ย้อนหลัง
local PerfCard = Panel(Home, UDim2.new(1, 0, 0, 120))
Tint(PerfCard)
local PerfTitle = Text(PerfCard, "ประสิทธิภาพ (FPS)", 12, FNT.B, "Text")
PerfTitle.Position = UDim2.fromOffset(18, 12)
PerfTitle.Size = UDim2.new(0.5, 0, 0, 18)
local PerfAvg = Text(PerfCard, "", 11, FNT.M, "Sub", Enum.TextXAlignment.Right)
PerfAvg.Position = UDim2.new(0.5, 0, 0, 12)
PerfAvg.Size = UDim2.new(0.5, -18, 0, 18)
local PerfBars = New("Frame", {
    Size = UDim2.new(1, -36, 0, 68),
    Position = UDim2.fromOffset(18, 40),
    BackgroundTransparency = 1,
}, PerfCard)

local PERF_N = 36
local PerfBar, PerfHist = {}, {}
for i = 1, PERF_N do
    local b = New("Frame", {
        Size = UDim2.new(1 / PERF_N, -2, 0, 2),
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new((i - 1) / PERF_N, 1, 1, 0),
        BorderSizePixel = 0,
        BackgroundTransparency = 1,
    }, PerfBars)
    Corner(b, 2)
    PerfBar[i] = b
    PerfHist[i] = 0
end

local function PerfUpdate()
    table.remove(PerfHist, 1)
    PerfHist[#PerfHist + 1] = Metrics.fps
    local peak, sum, cnt = 60, 0, 0
    for _, v in ipairs(PerfHist) do
        if v > peak then
            peak = v
        end
        if v > 0 then
            sum = sum + v
            cnt = cnt + 1
        end
    end
    for i, v in ipairs(PerfHist) do
        local b = PerfBar[i]
        b.Size = UDim2.new(1 / PERF_N, -2, math.clamp(v / peak, 0.04, 1), 0)
        b.BackgroundColor3 = Level(v, 50, 30, true)
        b.BackgroundTransparency = v == 0 and 1 or 0.08
    end
    PerfAvg.Text = "เฉลี่ย " .. tostring(cnt > 0 and math.floor(sum / cnt + 0.5) or 0) .. " FPS"
end

local sessionStart = os.time()

local function RefreshHome()
    local hr = tonumber(os.date("%H")) or 12
    HeroSub.Text = (hr >= 5 and hr < 12 and "อรุณสวัสดิ์")
        or (hr >= 12 and hr < 17 and "สวัสดีตอนบ่าย")
        or (hr >= 17 and hr < 21 and "สวัสดีตอนเย็น")
        or "ราตรีสวัสดิ์"
    HeroClock.Text = os.date("%H:%M")
    HeroDate.Text = os.date("%d / %m / %Y")
    local sec = math.max(0, os.time() - sessionStart)
    StatPlayer.Text = LocalPlayer.DisplayName
    StatTime.Text = string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor((sec % 3600) / 60), sec % 60)
    StatFps.Text = tostring(Metrics.fps)
    StatFps.TextColor3 = Level(Metrics.fps, 50, 30, true)
    StatPing.Text = tostring(Metrics.ping) .. " ms"
    StatPing.TextColor3 = Level(Metrics.ping, 80, 160, false)
    ChipPlayers.Text = string.format("ผู้เล่น %d/%d", #Players:GetPlayers(), Players.MaxPlayers)
    PerfUpdate()
end

task.spawn(function()
    while Screen.Parent do
        RefreshStats()
        RefreshHome()
        task.wait(0.5)
    end
end)

--==================================================
-- FUNCTIONS
--==================================================

local Functions = MakePage("Farm", "ฟาร์มทุเรียน", "เก็บ  •  ปลูก  •  รดน้ำ  •  เซฟอัตโนมัติ")

;(function()
local ok, err = pcall(function()
    local PFarm = Functions
    local PShop = MakePage("Shop", "ขาย / ซื้อ / อัปเกรด", "ขายทุเรียน  •  ซื้อเมล็ด  •  Rebirth  •  ซื้อแปลง")
    local PAll = MakePage("AllIn", "ไก่ตัน (ALL-IN-ONE)", "เปิดปุ่มเดียว ทำฟาร์มทุเรียนอัตโนมัติทั้งวงจร")
    local PTele = MakePage("Teleport", "วาป", "วาปไปฐาน  •  บ่อน้ำ  •  ร้านเมล็ด  •  ที่ขาย")
    local PSafe = MakePage("Safe", "ป้องกัน", "Anti-AFK  •  Anti-Kick  •  Safe Mode  •  ย้ายเซิร์ฟ")
    local PExtra = MakePage("Extra", "เครื่องมือเสริม", "ESP ทุเรียนสุก  •  FPS  •  สว่างเต็มที่")
    local PSys = MakePage("System", "ระบบ", "ตัวเรียนรู้คำสั่ง  •  ตรวจระบบ")

    local Handles = {}
    local RawToggle = Toggle
    local function Toggle(page, opts)
        local h = RawToggle(page, opts)
        Handles[opts.key] = h
        return h
    end

    local RS = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local TeleportService = game:GetService("TeleportService")
    local Remotes = RS:FindFirstChild("Remotes") or RS:WaitForChild("Remotes", 10)

    local function Button(page, opts)
        local row = Panel(page, UDim2.new(1, 0, 0, 60), "TextButton")
        HoverRow(row)
        Register(row, opts.title .. " " .. (opts.desc or ""))
        local t = Text(row, opts.title, 13, FNT.M, "Text")
        t.Position = UDim2.fromOffset(18, 10)
        t.Size = UDim2.new(1, -130, 0, 20)
        local d = Text(row, opts.desc or "", 11, FNT.R, "Muted")
        d.Position = UDim2.fromOffset(18, 32)
        d.Size = UDim2.new(1, -130, 0, 18)
        local pill = New("Frame", {
            Size = UDim2.fromOffset(78, 30),
            Position = UDim2.new(1, -94, 0.5, -15),
            BorderSizePixel = 0,
            BackgroundColor3 = Color3.new(1, 1, 1),
        }, row)
        Corner(pill, 15)
        AccentGrad(pill, 0)
        local pt = Text(pill, opts.text or "RUN", 11, FNT.B, "OnAccent", Enum.TextXAlignment.Center)
        pt.Size = UDim2.fromScale(1, 1)
        row.MouseButton1Click:Connect(function()
            pt.Text = "DONE"
            task.delay(0.8, function()
                pt.Text = opts.text or "RUN"
            end)
            if opts.callback then
                task.spawn(opts.callback)
            end
        end)
    end

    ----------------------------------------------------------------
    -- ตัวช่วย
    ----------------------------------------------------------------
    local function Notify(msg)
        pcall(Toast, msg, true)
    end
    local lastStatus, lastStatusT = "", 0
    local function Status(msg)
        if msg ~= lastStatus and tick() - lastStatusT > 3 then
            lastStatus, lastStatusT = msg, tick()
            Notify(msg)
        end
        if Config.RemoteLog then
            print("[RELWX][status]", msg)
        end
    end
    local function dbg(...)
        if Config.RemoteLog then
            print("[RELWX]", ...)
        end
    end
    local function Root()
        local c = LocalPlayer.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end
    local function Dist(a, b)
        return (a - b).Magnitude
    end
    local function ZeroVel(r)
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
    end
    local function PosOf(inst)
        if not inst then
            return nil
        end
        if inst:IsA("BasePart") then
            return inst.Position
        end
        local ok2, cf = pcall(function()
            return inst:GetPivot()
        end)
        return ok2 and cf.Position or nil
    end

    local function MakeLoop(name, interval, fn)
        local id = 0
        return function(on)
            id = id + 1
            if not on then
                return
            end
            local my = id
            task.spawn(function()
                while id == my do
                    local ok2, e2 = pcall(fn)
                    if not ok2 then
                        dbg(name, e2)
                    end
                    local iv = interval
                    if type(iv) == "function" then
                        iv = iv()
                    end
                    if Config.SafeMode then
                        iv = iv * (0.85 + math.random() * 0.4)
                    end
                    task.wait(iv)
                end
            end)
        end
    end

    ----------------------------------------------------------------
    -- ตัวเรียนรู้คำสั่งของเกม (Remote Learner)
    ----------------------------------------------------------------
    local Learned = {}
    local OwnCall = false
    local NOISY = {}

    local function CopyArg(v)
        if type(v) == "table" then
            local t = {}
            for k, x in pairs(v) do
                t[k] = CopyArg(x)
            end
            return t
        end
        return v
    end
    local function FmtArgs(args)
        local out = {}
        for i = 1, args.n do
            local a = args[i]
            if typeof(a) == "Instance" then
                out[#out + 1] = a:GetFullName()
            elseif type(a) == "table" then
                out[#out + 1] = "{table}"
            else
                out[#out + 1] = tostring(a)
            end
        end
        return table.concat(out, ", ")
    end
    local function Capture(remote, method, args)
        local name = remote.Name
        local copy = { n = args.n }
        for i = 1, args.n do
            copy[i] = CopyArg(args[i])
        end
        local L = Learned[name]
        if not L then
            L = { count = 0 }
            Learned[name] = L
        end
        L.args = copy
        L.count = L.count + 1
        if Config.RemoteLog and not NOISY[name] then
            print(string.format("[RELWX][%s] %s(%s)", method, name, FmtArgs(copy)))
        end
    end

    local HookOK = false
    pcall(function()
        if not (hookmetamethod and getnamecallmethod) then
            return
        end
        local old
        local function hook(self, ...)
            local m = getnamecallmethod()
            if (m == "Kick" or m == "kick") and self == LocalPlayer and Config.AntiKick then
                return
            end
            if (m == "FireServer" or m == "InvokeServer") and not OwnCall and typeof(self) == "Instance" then
                if self.Parent == Remotes then
                    local packed = table.pack(...)
                    task.defer(Capture, self, m, packed)
                end
            end
            return old(self, ...)
        end
        old = hookmetamethod(game, "__namecall", newcclosure and newcclosure(hook) or hook)
        HookOK = true
    end)

    local function FireRaw(name, ...)
        local r = Remotes and Remotes:FindFirstChild(name)
        if not r then
            return false
        end
        OwnCall = true
        local ok2 = pcall(function(...)
            if r:IsA("RemoteFunction") then
                task.spawn(function(...)
                    pcall(r.InvokeServer, r, ...)
                end, ...)
            else
                r:FireServer(...)
            end
        end, ...)
        OwnCall = false
        return ok2
    end
    local function HasLearned(name)
        return Learned[name] ~= nil
    end

    ----------------------------------------------------------------
    -- ฐานของเรา / แปลง / ทุเรียน
    ----------------------------------------------------------------
    local baseCache, baseT = nil, 0
    local function MyBase()
        if baseCache and baseCache.Parent and tick() - baseT < 5 then
            return baseCache
        end
        baseT = tick()
        baseCache = nil
        local map = Workspace:FindFirstChild("Map")
        local bases = map and map:FindFirstChild("Bases")
        if bases then
            for _, b in ipairs(bases:GetChildren()) do
                if b:GetAttribute("OwnerUserId") == LocalPlayer.UserId or b:GetAttribute("OwnerName") == LocalPlayer.Name then
                    baseCache = b
                    break
                end
            end
        end
        return baseCache
    end
    local function SlotsOf(base)
        local it = base and base:FindFirstChild("Items")
        local out = {}
        if not it then
            return out
        end
        local plots = {}
        for _, c in ipairs(it:GetChildren()) do
            if c.Name:match("^FarmPlot") then
                plots[#plots + 1] = c
            end
        end
        table.sort(plots, function(a, b)
            return a.Name < b.Name
        end)
        for _, fp in ipairs(plots) do
            local sl = fp:FindFirstChild("Slots")
            if sl then
                local list = sl:GetChildren()
                table.sort(list, function(a, b)
                    return a.Name < b.Name
                end)
                for _, s in ipairs(list) do
                    out[#out + 1] = s
                end
            end
        end
        return out
    end
    local function SlotPrompt(slot)
        local ps = slot:FindFirstChild("PlantSpot")
        return ps and ps:FindFirstChildOfClass("ProximityPrompt"), ps
    end
    local function IsPlanted(slot)
        return slot:FindFirstChild("Tree") ~= nil
    end
    local function SlotInfoText(slot)
        local ps = slot:FindFirstChild("PlantSpot")
        local info = ps and ps:FindFirstChild("Info")
        local sub = info and info:FindFirstChild("Sub")
        local ti = info and info:FindFirstChild("Title")
        return (ti and ti.Text or ""), (sub and sub.Text or "")
    end
    -- พรอมต์เก็บเกี่ยวที่สุกแล้วในฐานเรา
    local function RipePrompts(base)
        local out = {}
        for _, slot in ipairs(SlotsOf(base)) do
            local fr = slot:FindFirstChild("Fruits")
            if fr then
                for _, d in ipairs(fr:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Name == "Harvest" and d:GetAttribute("Unripe") ~= true and d.Enabled then
                        out[#out + 1] = d
                    end
                end
            end
        end
        return out
    end

    local function FirePrompt(prompt)
        if not prompt then
            return false
        end
        pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
            prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 20)
        end)
        if fireproximityprompt then
            return pcall(fireproximityprompt, prompt)
        end
        return false
    end

    local function TP(pos)
        local r = Root()
        if r and r.Anchored then
            pcall(function()
                r.Anchored = false
            end)
        end
        if not r then
            return false
        end
        if Config.SafeMode and Dist(r.Position, pos) > Config.TPSpeed * 0.6 then
            -- เดินเป็นช่วง ๆ ลดโอกาสถูกดึงกลับ
            local guard = 0
            while guard < 400 do
                guard = guard + 1
                r = Root()
                if not r then
                    return false
                end
                local d = Dist(r.Position, pos)
                if d <= 4 then
                    break
                end
                local dt = RunService.Heartbeat:Wait()
                r.CFrame = CFrame.new(r.Position + (pos - r.Position).Unit * math.min(d, Config.TPSpeed * dt))
                ZeroVel(r)
            end
            return true
        end
        r.CFrame = CFrame.new(pos)
        ZeroVel(r)
        return true
    end

    local function FindIn(root, className, name)
        if not root then
            return nil
        end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA(className) and (not name or d.Name == name) then
                return d
            end
        end
        return nil
    end
    local promptCache = {}
    local function MapPrompt(name)
        local c = promptCache[name]
        if c and c.Parent then
            return c
        end
        local map = Workspace:FindFirstChild("Map")
        local wh = map and map:FindFirstChild("DurianWarehouse")
        local p = FindIn(wh, "ProximityPrompt", name)
        if p then
            promptCache[name] = p
        end
        return p
    end
    local function BasePrompt(name)
        local b = MyBase()
        return FindIn(b, "ProximityPrompt", name)
    end

    local homeT = 0
    local function GoHome()
        local b = MyBase()
        local sp = b and b:FindFirstChild("SpawnPad")
        local pos = PosOf(sp)
        if pos then
            TP(pos + Vector3.new(0, 4, 0))
        end
    end
    local function GoPrompt(p, up)
        local part = p and p.Parent
        local pos = part and PosOf(part)
        if not pos then
            return false
        end
        TP(pos + Vector3.new(3, up or 2, 0))
        task.wait(0.25)
        return true
    end

    ----------------------------------------------------------------
    -- วงจรฟาร์ม
    ----------------------------------------------------------------
    local Stats = { harvested = 0, sold = 0, planted = 0 }
    local last = { water = 0, sell = 0, seed = 0, pads = 0, rebirth = 0, bag = 0 }

    -- แทนที่เป้าหมายใน args ที่เรียนรู้ ด้วยแปลง/ผลไม้ใหม่
    local function SlotOfInst(inst)
        local o = inst
        while o and o.Parent do
            if o.Parent.Name == "Slots" then
                return o
            end
            o = o.Parent
        end
        return nil
    end
    local function Replay(name, slot, fruitModel)
        local L = Learned[name]
        if not L then
            return false
        end
        local src = L.args
        local args = { n = src.n }
        local slotIdx = slot and tonumber(slot.Name:match("%d+"))
        for i = 1, src.n do
            local a = src[i]
            local ty = typeof(a)
            if slot and ty == "Instance" and a.Parent and SlotOfInst(a) then
                if a.Name:match("^Fruit_%d+$") and fruitModel then
                    args[i] = fruitModel
                else
                    args[i] = slot
                end
            elseif slot and ty == "string" and a:match("^Slot%d+$") then
                args[i] = slot.Name
            elseif slotIdx and ty == "number" and src.n <= 3 and a >= 1 and a <= 12 and a == math.floor(a) then
                args[i] = slotIdx
            else
                args[i] = a
            end
        end
        return FireRaw(name, table.unpack(args, 1, args.n))
    end

    local Tried = setmetatable({}, { __mode = "k" })
    -- ตรึงตัวละครกลางอากาศไม่ให้ร่วงตอนเก็บทุเรียนบนยอดต้น
    local function Hold(on)
        local r = Root()
        if r then
            pcall(function()
                r.Anchored = on
                ZeroVel(r)
            end)
        end
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then
            pcall(function()
                h.PlatformStand = on
            end)
        end
    end
    local GMsg = "-"

    ----------------------------------------------------------------
    -- เก็บทุเรียน (วิธีเดียวกับ Durian Garden): TAP / Remote / ผสม / อัตโนมัติ
    -- Remote จริง: CatchReady:FireServer() -> HarvestFruit:FireServer(<Harvest ProximityPrompt>)
    ----------------------------------------------------------------
    local function PromptPos(p)
        local a = p.Parent
        if a and a:IsA("Attachment") then
            return a.WorldPosition
        end
        if a and a:IsA("BasePart") then
            return a.Position
        end
        local m = p:FindFirstAncestorOfClass("Model")
        return m and PosOf(m)
    end
    local function FruitOf(prompt, base)
        local cur = prompt.Parent
        while cur and cur ~= base do
            if cur.Name:match("^Fruit_%d+$") then
                local typ
                for _, c in ipairs(cur:GetChildren()) do
                    local t = c.Name:match("^Durian_Fruit_(.+)$")
                    if t then
                        typ = t
                        break
                    end
                end
                return cur, typ
            end
            cur = cur.Parent
        end
        return nil, nil
    end
    local function ScanFruits(base)
        local list, ripe, total = {}, 0, 0
        if not base then
            return list, 0, 0
        end
        for _, d in ipairs(base:GetDescendants()) do
            if d.Name == "Harvest" and d:IsA("ProximityPrompt") then
                total = total + 1
                if d.Enabled and d:GetAttribute("Unripe") ~= true then
                    local fruit, typ = FruitOf(d, base)
                    ripe = ripe + 1
                    list[#list + 1] = { p = d, fruit = fruit, typ = typ, mut = fruit and fruit:GetAttribute("Mutation") }
                end
            end
        end
        return list, ripe, total
    end
    local function PassFilter(e)
        if e.typ and Config["HT_" .. e.typ] == false then
            return false
        end
        if Config.MutOnly and not e.mut then
            return false
        end
        return true
    end
    local function IsGone(p, fruit)
        if not p.Parent or not p:IsDescendantOf(Workspace) then
            return true
        end
        if fruit and not fruit.Parent then
            return true
        end
        if not p.Enabled then
            return true
        end
        return p:GetAttribute("Unripe") == true
    end
    local function WaitGone(p, fruit, t)
        local t0 = os.clock()
        while os.clock() - t0 < t do
            if IsGone(p, fruit) then
                return true
            end
            task.wait(0.2)
        end
        return IsGone(p, fruit)
    end
    -- ยืนใต้ผล (ในระยะกดของพรอมต์)
    local function UnderFruit(p, fruit)
        local pos = PromptPos(p)
        if not pos then
            return nil
        end
        local maxd = p.MaxActivationDistance or 10
        local y = pos.Y - maxd * 0.5
        local ex = { LocalPlayer.Character }
        local slotM = fruit and fruit:FindFirstAncestorOfClass("Model")
        if slotM then
            ex[#ex + 1] = slotM
        elseif fruit then
            ex[#ex + 1] = fruit
        end
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = ex
        local hit = Workspace:Raycast(pos, Vector3.new(0, -300, 0), params)
        if hit then
            local gy = hit.Position.Y + 3
            if pos.Y - gy <= maxd - 1 then
                y = gy
            end
        end
        return Vector3.new(pos.X, y, pos.Z)
    end

    local function TapPrompt(p)
        pcall(function()
            p.RequiresLineOfSight = false
        end)
        local ok2 = false
        if fireproximityprompt then
            ok2 = pcall(fireproximityprompt, p)
        end
        if not ok2 then
            ok2 = pcall(function()
                p:InputHoldBegin()
                task.wait(math.max(p.HoldDuration, 0) + 0.05)
                p:InputHoldEnd()
            end)
        end
        return ok2
    end
    local function SendRemotes(p)
        if not (Remotes and Remotes:FindFirstChild("HarvestFruit")) then
            return false
        end
        FireRaw("CatchReady")
        task.wait(math.max(0, Config.CatchWait) / 1000)
        return FireRaw("HarvestFruit", p)
    end
    local bestM = 2
    local METHODS = {
        [2] = {
            name = "กด [TAP]", wait = 4.0,
            run = function(p)
                TapPrompt(p)
                task.wait(0.3)
                Hold(false)
                return true
            end,
        },
        [3] = { name = "Remote", wait = 1.5, run = function(p) return SendRemotes(p) end },
        [4] = {
            name = "[TAP] + Remote", wait = 3.0,
            run = function(p)
                TapPrompt(p)
                task.wait(0.6)
                Hold(false)
                return SendRemotes(p)
            end,
        },
    }
    local function HarvestOne(e)
        local p, fruit = e.p, e.fruit
        local order
        local hm = Config.HarvestMethod
        if hm == 1 then
            order = { bestM }
            for _, m in ipairs({ 2, 3, 4 }) do
                if m ~= bestM then
                    order[#order + 1] = m
                end
            end
        else
            order = { METHODS[hm] and hm or 2 }
        end
        for _, m in ipairs(order) do
            local M = METHODS[m]
            if p.Parent then
                M.run(p)
                if WaitGone(p, fruit, M.wait) then
                    bestM = m
                    GMsg = "เก็บสำเร็จด้วย " .. M.name
                    return true
                end
            end
        end
        GMsg = "เก็บไม่สำเร็จ (ลองครบทุกวิธี) — ลองเพิ่ม 'หน่วงจับ' หรือเลือกวิธีเอง"
        return false
    end

    local Skip = setmetatable({}, { __mode = "k" })
    local function SlotOfEntry(e)
        local folder = e.fruit and e.fruit.Parent
        return (folder and folder.Parent) or e.p.Parent
    end
    local function EntryOK(e)
        local p = e.p
        return p.Parent and p.Enabled and p:GetAttribute("Unripe") ~= true and PassFilter(e) and (Skip[p] or 0) < tick()
    end
    local function HarvestEntry(e)
        local pos = UnderFruit(e.p, e.fruit)
        Hold(false)
        if pos then
            TP(pos)
        end
        Hold(true)
        task.wait(0.05)
        local ok2, res = pcall(HarvestOne, e)
        Hold(false)
        if ok2 and res then
            Stats.harvested = Stats.harvested + 1
            Stats.hn = (Stats.hn or 0) + 1
        else
            Stats.fails = (Stats.fails or 0) + 1
            Skip[e.p] = tick() + 10
            if not ok2 then
                GMsg = "error: " .. tostring(res)
            end
        end
        task.wait(math.max(0.03, Config.HarvestDelay / 1000))
        return ok2 and res
    end
    -- เก็บทีละต้น: เก็บผลสุกของต้นหนึ่งให้หมดก่อนไปต้นถัดไป (ต้นใกล้ตัวก่อน)
    local function HarvestPass(base)
        local list = ScanFruits(base)
        local groups, order = {}, {}
        for _, e in ipairs(list) do
            local sl = SlotOfEntry(e)
            if sl and PassFilter(e) then
                if not groups[sl] then
                    groups[sl] = {}
                    order[#order + 1] = sl
                end
                table.insert(groups[sl], e)
            end
        end
        if #order == 0 then
            return 0
        end
        local r0 = Root()
        local dist = {}
        for _, sl in ipairs(order) do
            local okp, cf = pcall(function()
                return sl:GetPivot()
            end)
            dist[sl] = (okp and r0) and (cf.Position - r0.Position).Magnitude or math.huge
        end
        table.sort(order, function(x, y)
            return dist[x] < dist[y]
        end)
        local n = 0
        for _, sl in ipairs(order) do
            if not Config.AutoHarvest then
                break
            end
            local cur, passes = groups[sl], 0
            while cur and #cur > 0 and passes < 5 and Config.AutoHarvest do
                passes = passes + 1
                for _, e in ipairs(cur) do
                    if not Config.AutoHarvest then
                        break
                    end
                    if EntryOK(e) and HarvestEntry(e) then
                        n = n + 1
                    end
                end
                local again = {}
                for _, e2 in ipairs((ScanFruits(base))) do
                    if SlotOfEntry(e2) == sl and EntryOK(e2) then
                        again[#again + 1] = e2
                    end
                end
                cur = again
            end
        end
        Hold(false)
        if n > 0 then
            GoHome()
            Status("เก็บทุเรียน " .. n .. " ลูก (รวม " .. Stats.harvested .. ")")
        end
        return n
    end
    -- เครื่องมือ (Tool) ในกระเป๋า: เมล็ด / บัวรดน้ำ  (เกมให้ "ถือเมล็ดเพื่อปลูก" และ "ถือบัวรดน้ำแล้วคลิกดิน")
    local NOT_SEED = { "bat", "headlamp", "shovel", "water", "can", "backpack", "bag", "hoe", "durian", "fruit", "ทุเรียน" }
    local function AllTools()
        local list = {}
        for _, c in ipairs({ LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack") }) do
            if c then
                for _, t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") then
                        list[#list + 1] = t
                    end
                end
            end
        end
        return list
    end
    local function FindTool(kind)
        local fallback
        for _, t in ipairs(AllTools()) do
            local n = string.lower(t.Name)
            if kind == "water" then
                if n:find("water") then
                    return t
                end
            else
                local tip = string.lower(t.ToolTip or "")
                if n:find("seed") or n:find("เมล็ด") or tip:find("seed") or tip:find("plant") then
                    return t
                end
                local skip = false
                for _, w in ipairs(NOT_SEED) do
                    if n:find(w, 1, true) then
                        skip = true
                    end
                end
                if not skip and not fallback then
                    fallback = t
                end
            end
        end
        return kind == "seed" and fallback or nil
    end
    local function Equip(tool)
        if not tool then
            return false
        end
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not h then
            return false
        end
        if tool.Parent ~= c then
            pcall(function()
                h:EquipTool(tool)
            end)
            task.wait(0.25)
        end
        return tool.Parent == c
    end
    local function UseTool(tool)
        pcall(function()
            tool:Activate()
        end)
    end

    local function PlantPass(base)
        local n = 0
        local hasEmpty = false
        for _, slot in ipairs(SlotsOf(base)) do
            if not IsPlanted(slot) then
                hasEmpty = true
            end
        end
        if not hasEmpty then
            return 0
        end
        local seed = FindTool("seed")
        if not seed then
            Status("ไม่มีเมล็ดในกระเป๋า — ซื้อเมล็ดก่อน (เปิด Auto ซื้อเมล็ด)")
            return 0
        end
        for _, slot in ipairs(SlotsOf(base)) do
            if not Config.AutoPlant then
                break
            end
            if not IsPlanted(slot) then
                seed = FindTool("seed")
                if not seed then
                    break
                end
                local p, ps = SlotPrompt(slot)
                if p and ps then
                    TP(ps.Position + Vector3.new(3, 3, 0))
                    Equip(seed)
                    task.wait(0.2)
                    FirePrompt(p)
                    UseTool(seed)
                    task.wait(0.35)
                    if HasLearned("FarmAction") then
                        Replay("FarmAction", slot)
                    end
                    n = n + 1
                end
            end
        end
        Stats.planted = Stats.planted + n
        return n
    end

    ----------------------------------------------------------------
    -- รดน้ำแบบ Durian Garden: ถือบัว -> เติมที่บ่อ -> เดินรอบโคนต้น -> Water:FireServer("Water", Vector3)
    ----------------------------------------------------------------
    local WRING = 3
    local estLeft = 0
    local function GetCan()
        return FindTool("water")
    end
    local function CanCharges(can)
        local c, m = ((can and can.Name) or ""):match("(%d+)%s*/%s*(%d+)")
        if c then
            return tonumber(c), tonumber(m)
        end
        return nil, nil
    end
    local function GroundPoint(pos)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LocalPlayer.Character }
        local hit = Workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -60, 0), params)
        return hit and hit.Position or pos
    end
    local function ChargesLeft()
        local c = CanCharges(GetCan())
        if c ~= nil then
            return c
        end
        return estLeft
    end
    local function FillCan(base)
        local can = GetCan()
        if not can then
            return false, "ไม่พบบัวรดน้ำ"
        end
        local well = BasePrompt("FillPrompt")
        local pos = well and PromptPos(well)
        if not pos then
            return false, "ไม่พบบ่อน้ำ"
        end
        TP(pos + Vector3.new(0, 3, 0))
        pcall(function()
            well.RequiresLineOfSight = false
        end)
        for attempt = 1, 4 do
            Equip(GetCan())
            FirePrompt(well)
            task.wait(math.max(well.HoldDuration or 0, 0) + 0.4)
            local c, m = CanCharges(GetCan())
            if c ~= nil then
                if c >= m then
                    return true, "เติมน้ำเต็มแล้ว"
                end
            elseif attempt >= 2 then
                estLeft = 3
                return true, "เติมน้ำแล้ว"
            end
        end
        local c = CanCharges(GetCan())
        if c ~= nil and c > 0 then
            return true, "เติมน้ำได้บางส่วน"
        end
        return false, "เติมน้ำที่บ่อไม่สำเร็จ"
    end
    local function SprayAt(center, k, n)
        local ang = (k - 1) * (2 * math.pi / n) + 0.6
        local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
        local target = GroundPoint(center + dir * WRING)
        local stand = GroundPoint(center + dir * (WRING + 2.5)) + Vector3.new(0, 3, 0)
        TP(stand)
        local r = Root()
        if r then
            pcall(function()
                r.CFrame = CFrame.lookAt(stand, Vector3.new(target.X, stand.Y, target.Z))
            end)
        end
        Equip(GetCan())
        if not FireRaw("Water", "Water", Vector3.new(target.X, target.Y, target.Z)) then
            return false
        end
        if GetCan() and CanCharges(GetCan()) == nil then
            estLeft = estLeft - 1
        end
        task.wait(0.35)
        return true
    end
    local function WaterPass(base)
        if not GetCan() then
            GMsg = "(รดน้ำ) ไม่พบบัวรดน้ำในกระเป๋า"
            Status("ไม่พบบัวรดน้ำในกระเป๋า")
            return
        end
        local ok2, why = FillCan(base)
        if not ok2 then
            GMsg = "(รดน้ำ) " .. why
            return
        end
        local n = math.max(1, Config.WaterPerTree)
        local watered, aborted = 0, false
        for _, slot in ipairs(SlotsOf(base)) do
            if not Config.AutoWater or aborted then
                break
            end
            local spot = slot:FindFirstChild("PlantSpot")
            if spot and spot:IsA("BasePart") and IsPlanted(slot) then
                for k = 1, n do
                    if ChargesLeft() <= 0 then
                        local ok3, why3 = FillCan(base)
                        if not ok3 then
                            GMsg = "(รดน้ำ) " .. why3
                            aborted = true
                            break
                        end
                    end
                    SprayAt(spot.Position, k, n)
                end
                if not aborted then
                    watered = watered + 1
                end
            end
        end
        if not aborted then
            GMsg = "(รดน้ำ) รดแล้ว " .. watered .. " ต้น"
        end
    end

    ----------------------------------------------------------------
    -- ขาย: กระเป๋า (Cargo:FireServer("Sell") ซ้ำ) หรือรถบรรทุก (LOAD ALL -> ขับไปพ่อค้า)
    ----------------------------------------------------------------
    local DURIAN_KEYS = { "Puangmanee", "Kradumthong", "Chanee", "Kanyao", "Durian" }
    local function CountDurians()
        local n = 0
        for _, c in ipairs({ LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character }) do
            if c then
                for _, t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") then
                        for _, k in ipairs(DURIAN_KEYS) do
                            if t.Name:find(k) then
                                n = n + 1
                                break
                            end
                        end
                    end
                end
            end
        end
        return n
    end
    local selling = false
    local function SellBackpack()
        if selling then
            return true, 0
        end
        local r1 = Remotes and Remotes:FindFirstChild("Cargo")
        local r2 = Remotes and Remotes:FindFirstChild("SellDurians")
        if not (r1 or r2) then
            return false, 0
        end
        selling = true
        local before = CountDurians()
        local total = math.clamp(before + 2, 5, 40)
        local sent = 0
        for _ = 1, total do
            if r1 then
                FireRaw("Cargo", "Sell")
            else
                FireRaw("SellDurians")
            end
            sent = sent + 1
            task.wait(0.15)
            if sent >= 5 and before > 0 and CountDurians() == 0 then
                break
            end
        end
        selling = false
        return true, sent
    end

    local Truck = (function()
        local VIM
        pcall(function()
            VIM = game:GetService("VirtualInputManager")
        end)
        local function Hum()
            return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        end
        local function TweenTo(cf, speed)
            local r = Root()
            if not r then
                return false
            end
            local t = math.clamp((r.Position - cf.Position).Magnitude / (speed or 120), 0.05, 12)
            r.Anchored = true
            local tw = TweenService:Create(r, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = cf })
            tw:Play()
            tw.Completed:Wait()
            r.Anchored = false
            ZeroVel(r)
            return true
        end
        local function Path(root, ...)
            local cur = root
            for _, n in ipairs({ ... }) do
                if not cur then
                    return nil
                end
                cur = cur:FindFirstChild(n)
            end
            return cur
        end
        local function MyVehicle()
            local base = MyBase()
            local parking = base and Path(base, "Items", "Parking")
            if parking then
                for _, m in ipairs(parking:GetChildren()) do
                    if m:IsA("Model") and m:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                        return m
                    end
                end
            end
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("Model") and d:GetAttribute("VehicleId") and d:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
                    return d
                end
            end
            return nil
        end
        local function TweenVehicle(veh, pos)
            local seat = veh:FindFirstChild("DriverSeat", true)
            local start = veh:GetPivot()
            local goal = CFrame.new(pos) * start.Rotation
            local dur = math.clamp((start.Position - pos).Magnitude / math.max(30, Config.SellSpeed), 0.1, 12)
            local t0 = os.clock()
            while true do
                local a = math.clamp((os.clock() - t0) / dur, 0, 1)
                veh:PivotTo(start:Lerp(goal, a))
                if seat then
                    seat.AssemblyLinearVelocity = Vector3.zero
                    seat.AssemblyAngularVelocity = Vector3.zero
                end
                if a >= 1 then
                    break
                end
                RunService.Heartbeat:Wait()
            end
        end
        local function SitIn(veh)
            local seat = veh:FindFirstChild("DriverSeat", true)
            local hum = Hum()
            if not (seat and hum) then
                return false
            end
            if hum.SeatPart == seat then
                return true
            end
            for _ = 1, 3 do
                TweenTo(seat.CFrame + Vector3.new(0, 2, 0), Config.SellSpeed)
                pcall(function()
                    seat:Sit(hum)
                end)
                local t0 = os.clock()
                while os.clock() - t0 < 1 do
                    if hum.SeatPart == seat then
                        return true
                    end
                    task.wait(0.05)
                end
                for _, d in ipairs(veh:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Name ~= "CargoPrompt" then
                        local t = ((d.ActionText or "") .. " " .. (d.ObjectText or "")):lower()
                        if t:find("drive") or t:find("enter") then
                            FirePrompt(d)
                        end
                    end
                end
                task.wait(0.2)
                if hum.SeatPart == seat then
                    return true
                end
            end
            return hum.SeatPart == seat
        end
        local function StandUp()
            local hum = Hum()
            if hum and hum.SeatPart then
                hum.Sit = false
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                end)
                task.wait(0.2)
            end
        end
        local function GuiShown(o)
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            while o and o ~= pg do
                if o:IsA("GuiObject") and not o.Visible then
                    return false
                end
                if o:IsA("ScreenGui") and not o.Enabled then
                    return false
                end
                o = o.Parent
            end
            return true
        end
        local function NormText(t)
            t = tostring(t or ""):gsub("<[^>]+>", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
            return t:upper()
        end
        local function FindBtn(txt)
            local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
            if not pg then
                return nil
            end
            local want = NormText(txt)
            for _, d in ipairs(pg:GetDescendants()) do
                if (d:IsA("TextButton") or d:IsA("TextLabel")) and NormText(d.Text) == want and GuiShown(d) then
                    local b = d:IsA("TextButton") and d or d:FindFirstAncestorWhichIsA("GuiButton")
                    return b or d
                end
            end
            return nil
        end
        local function TapCenter(b)
            if not VIM then
                return false
            end
            return pcall(function()
                local pos, size = b.AbsolutePosition, b.AbsoluteSize
                local inset = GuiService:GetGuiInset()
                local x = pos.X + size.X / 2
                local y = pos.Y + size.Y / 2 + inset.Y
                VIM:SendTouchEvent(1, 0, x, y)
                task.wait(0.05)
                VIM:SendTouchEvent(1, 2, x, y)
                VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
            end)
        end
        local function ClickBtn(b)
            local fired = false
            local node = b
            for _ = 1, 3 do
                if not node or not node:IsA("GuiObject") then
                    break
                end
                for _, sig in ipairs({ "MouseButton1Click", "Activated", "MouseButton1Down", "MouseButton1Up" }) do
                    local ok2, ev = pcall(function()
                        return node[sig]
                    end)
                    if ok2 and ev then
                        if getconnections then
                            local ok3, conns = pcall(getconnections, ev)
                            if ok3 and conns then
                                for _, c in ipairs(conns) do
                                    if pcall(function() c:Fire() end) then
                                        fired = true
                                    end
                                end
                            end
                        elseif firesignal then
                            if pcall(firesignal, ev) then
                                fired = true
                            end
                        end
                    end
                end
                node = node:FindFirstAncestorWhichIsA("GuiButton")
            end
            TapCenter(b)
            return fired
        end
        local function LoadTruck(veh)
            local before = veh:GetAttribute("LoadCount") or 0
            local bag0 = CountDurians()
            if bag0 == 0 then
                if before > 0 then
                    return true, "ในรถมีของอยู่แล้ว"
                end
                return false, "ไม่มีทุเรียนในกระเป๋า"
            end
            local prompts = {}
            for _, d in ipairs(veh:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Name == "CargoPrompt" then
                    prompts[#prompts + 1] = d
                end
            end
            if #prompts == 0 then
                return false, "ไม่พบ CargoPrompt ที่รถ"
            end
            local r = Root()
            table.sort(prompts, function(a, b)
                local pa, pb = PromptPos(a), PromptPos(b)
                if not (pa and pb and r) then
                    return false
                end
                return (pa - r.Position).Magnitude < (pb - r.Position).Magnitude
            end)
            local btn
            for _, prompt in ipairs(prompts) do
                local pos = PromptPos(prompt)
                if pos then
                    TweenTo(CFrame.new(pos + Vector3.new(0, 3, 0)), Config.SellSpeed)
                end
                pcall(function()
                    prompt.RequiresLineOfSight = false
                end)
                for _ = 1, 2 do
                    pcall(fireproximityprompt, prompt)
                    local t0 = os.clock()
                    while os.clock() - t0 < 2 do
                        btn = FindBtn("LOAD ALL")
                        if btn then
                            break
                        end
                        task.wait(0.1)
                    end
                    if btn then
                        break
                    end
                end
                if btn then
                    break
                end
            end
            if not btn then
                return false, "เปิดหน้าต่างรถแล้วไม่เจอปุ่ม LOAD ALL"
            end
            local loaded = false
            for _ = 1, 3 do
                ClickBtn(btn)
                local t0 = os.clock()
                while os.clock() - t0 < 1.2 do
                    if (veh:GetAttribute("LoadCount") or 0) > before or CountDurians() < bag0 then
                        loaded = true
                        break
                    end
                    task.wait(0.1)
                end
                if loaded then
                    break
                end
                btn = FindBtn("LOAD ALL") or btn
            end
            local x = FindBtn("X") or FindBtn("✕") or FindBtn("×")
            if x then
                ClickBtn(x)
            end
            if not loaded then
                return false, "กด LOAD ALL แล้วของไม่ขึ้นรถ"
            end
            return true, "ใส่ของขึ้นรถแล้ว"
        end
        local function FindSellPrompt(veh)
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("ProximityPrompt") and not (veh and d:IsDescendantOf(veh)) then
                    local t = ((d.ActionText or "") .. " " .. (d.ObjectText or "")):lower()
                    if t:find("sell") and (t:find("truck") or t:find("load")) then
                        return d
                    end
                end
            end
            return nil
        end
        local function SavedPoint()
            local x, y, z = tostring(Config.SellPoint or ""):match("^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
            if x then
                return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
            end
            return nil
        end
        local function FindBuyerPos(veh)
            local sp0 = SavedPoint()
            if sp0 then
                return sp0
            end
            local sp = FindSellPrompt(veh)
            if sp then
                local pos = PromptPos(sp)
                if pos then
                    return pos
                end
            end
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("TextLabel") and (d.Text or ""):lower():find("durian buyer") then
                    local g = d:FindFirstAncestorOfClass("BillboardGui")
                    local a = g and (g.Adornee or g.Parent)
                    if a and a:IsA("Attachment") then
                        return a.WorldPosition
                    end
                    if a and a:IsA("BasePart") then
                        return a.Position
                    end
                end
            end
            local map = Workspace:FindFirstChild("Map")
            local bases = map and map:FindFirstChild("Bases")
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("BasePart") and not (bases and d:IsDescendantOf(bases)) then
                    local n = d.Name:lower()
                    if n:find("buyer") or n:find("sellzone") or n:find("selltruck") then
                        return d.Position
                    end
                end
            end
            return nil
        end
        local function SellAtBuyer(veh)
            local function emptied()
                return (veh:GetAttribute("LoadCount") or 0) == 0
            end
            local t0 = os.clock()
            while os.clock() - t0 < 1 and not veh:GetAttribute("InZone") do
                task.wait(0.05)
            end
            task.wait(0.1)
            local sp = FindSellPrompt(veh)
            if sp then
                FirePrompt(sp)
                t0 = os.clock()
                while os.clock() - t0 < 2.5 do
                    if emptied() then
                        return true
                    end
                    task.wait(0.1)
                end
            end
            if Remotes and Remotes:FindFirstChild("Cargo") then
                FireRaw("Cargo", "Sell")
                t0 = os.clock()
                while os.clock() - t0 < 2 do
                    if emptied() then
                        return true
                    end
                    task.wait(0.2)
                end
            end
            return emptied()
        end
        local function Sell()
            local veh = MyVehicle()
            local r, hum = Root(), Hum()
            if not (veh and r and hum) then
                return false, "ไม่พบรถของคุณ"
            end
            local homeChar = r.CFrame
            local homeVeh = veh:GetPivot()
            local ok2, res, msg = pcall(function()
                local okLoad, whyLoad = LoadTruck(veh)
                if not okLoad then
                    return false, whyLoad
                end
                if not SitIn(veh) then
                    return false, "ขึ้นนั่งรถไม่สำเร็จ"
                end
                local pos = FindBuyerPos(veh)
                if not pos then
                    return false, "ไม่พบจุดพ่อค้า — ไปยืนในโซนขายแล้วกด 'บันทึกจุดขาย'"
                end
                TweenVehicle(veh, pos + Vector3.new(0, 3, 0))
                task.wait(0.1)
                if SellAtBuyer(veh) then
                    return true, "ขายด้วยรถสำเร็จ"
                end
                return false, "ถึงพ่อค้าแต่ขายไม่สำเร็จ — ลองบันทึกจุดขายใหม่"
            end)
            pcall(function()
                if hum.SeatPart then
                    TweenVehicle(veh, homeVeh.Position)
                end
                StandUp()
                TweenTo(homeChar, Config.SellSpeed)
            end)
            if not ok2 then
                return false, "error: " .. tostring(res)
            end
            return res, msg
        end
        local function SavePoint()
            local hum = Hum()
            local veh = MyVehicle()
            local pos
            if hum and hum.SeatPart and veh and hum.SeatPart:IsDescendantOf(veh) then
                pos = veh:GetPivot().Position
            else
                local r = Root()
                pos = r and r.Position
            end
            if not pos then
                return false
            end
            Config.SellPoint = string.format("%.2f,%.2f,%.2f", pos.X, pos.Y, pos.Z)
            pcall(SaveConfig)
            return true
        end
        return { sell = Sell, vehicle = MyVehicle, savePoint = SavePoint, tweenTo = TweenTo }
    end)()

    local function SellTrip()
        if Config.SellTruck and Truck.vehicle() then
            local ok2, msg = Truck.sell()
            GMsg = "(ขายรถ) " .. tostring(msg)
            if ok2 then
                Stats.sold = Stats.sold + 1
            end
            Status(GMsg)
            return
        end
        if Remotes and (Remotes:FindFirstChild("Cargo") or Remotes:FindFirstChild("SellDurians")) then
            local ok2, n = SellBackpack()
            if ok2 then
                Stats.sold = Stats.sold + 1
                GMsg = "(ขาย) ส่งคำสั่งขาย " .. n .. " ครั้ง"
                Status("ขายทุเรียนแล้ว (ครั้งที่ " .. Stats.sold .. ")")
            end
            return
        end
        local p = MapPrompt("SellPrompt")
        if not p then
            Status("หาจุดขายทุเรียนไม่เจอ")
            return
        end
        GoPrompt(p, 2)
        FirePrompt(p)
        Stats.sold = Stats.sold + 1
        task.wait(0.4)
    end

    ----------------------------------------------------------------
    -- ร้านเมล็ด / ซื้อของ : SeedShop:FireServer("Buy", "<id>")
    ----------------------------------------------------------------
    local Shop = (function()
        local function Norm(n)
            n = tostring(n):lower():gsub("^fert_", ""):gsub("^gear_", ""):gsub("[%s_]", ""):gsub("seed$", "")
            return n
        end
        local function ToolCount(t)
            for _, a in ipairs({ "Count", "Amount", "Qty", "Quantity", "Stack", "Uses" }) do
                local v = t:GetAttribute(a)
                if type(v) == "number" then
                    return v
                end
                local c = t:FindFirstChild(a)
                if c and (c:IsA("IntValue") or c:IsA("NumberValue")) then
                    return c.Value
                end
            end
            return tonumber(t.Name:match("[xX](%d+)%s*$")) or 1
        end
        local function OwnedCount(label, id)
            local k1, k2 = Norm(label), Norm(id)
            local total = 0
            for _, c in ipairs({ LocalPlayer:FindFirstChildOfClass("Backpack"), LocalPlayer.Character }) do
                if c then
                    for _, t in ipairs(c:GetChildren()) do
                        if t:IsA("Tool") then
                            local n1 = t.Name:gsub("%s*%[.-%]", "")
                            n1 = n1:gsub("%s*[xX]%d+%s*$", "")
                            local nk = Norm(n1)
                            if nk == k1 or nk == k2 then
                                total = total + ToolCount(t)
                            end
                        end
                    end
                end
            end
            return total
        end
        local function GetCash()
            for _, k in ipairs({ "Cash", "Money", "Coins" }) do
                local v = LocalPlayer:GetAttribute(k)
                if type(v) == "number" then
                    return v
                end
            end
            local ls = LocalPlayer:FindFirstChild("leaderstats")
            if ls then
                for _, k in ipairs({ "Cash", "Money", "Coins" }) do
                    local c = ls:FindFirstChild(k)
                    if c and type(c.Value) == "number" then
                        return c.Value
                    end
                end
            end
            return nil
        end
        local function FindNpc()
            local map = Workspace:FindFirstChild("Map")
            local wh = map and map:FindFirstChild("DurianWarehouse")
            local npc = wh and wh:FindFirstChild("ShanaKung")
            if npc then
                return npc
            end
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d.Name == "ShanaKung" and (d:IsA("Model") or d:IsA("BasePart")) then
                    return d
                end
            end
            return nil
        end
        local function FindDealer()
            return Workspace:FindFirstChild("Traveler_Guy")
        end
        local function StandBefore(npc, partName)
            local target = (partName and npc:FindFirstChild(partName, true)) or npc
            local okP, cf = pcall(function()
                return target:GetPivot()
            end)
            if not okP then
                return nil
            end
            local pos, look = cf.Position, cf.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, 1)
            return pos + flat * 5 + Vector3.new(0, 3, 0), pos
        end
        local function GoNpc(npc, partName)
            local r = Root()
            if not (r and npc) then
                return false
            end
            local stand, pos = StandBefore(npc, partName)
            if not stand then
                return false
            end
            TP(stand)
            r = Root()
            if r then
                pcall(function()
                    r.CFrame = CFrame.lookAt(stand, Vector3.new(pos.X, stand.Y, pos.Z))
                end)
            end
            return true
        end
        -- ซื้อ 1 ครั้ง ตรวจผลจากเงินที่ลด/ของที่เพิ่ม; ไม่ได้ผลจะวาร์ปไปหน้า NPC แล้วกลับ
        local function BuyNear(id, label)
            local npc = FindNpc()
            local prompt = npc and npc:FindFirstChild("ShopPrompt", true)
            local function snap()
                return GetCash(), OwnedCount(label, id)
            end
            local function bought(c0, o0)
                local c, o = snap()
                return (c ~= nil and c0 ~= nil and c < c0) or (o > o0)
            end
            local function try()
                local c0, o0 = snap()
                if prompt and fireproximityprompt then
                    pcall(function()
                        prompt.MaxActivationDistance = math.max(prompt.MaxActivationDistance, 1000)
                        prompt.RequiresLineOfSight = false
                    end)
                    pcall(fireproximityprompt, prompt)
                    task.wait(0.35)
                end
                FireRaw("SeedShop", "Buy", id)
                local t0 = os.clock()
                while os.clock() - t0 < 1.2 do
                    if bought(c0, o0) then
                        return true
                    end
                    task.wait(0.1)
                end
                return bought(c0, o0)
            end
            local ok2 = try()
            local how = "ซื้อจากที่เดิม"
            if not ok2 then
                local r = Root()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if r and npc and not (hum and hum.SeatPart) then
                    local saved = r.CFrame
                    if GoNpc(npc, "BlazerGuy_Mesh") then
                        task.wait(0.25)
                        ok2 = try()
                        how = "วาร์ปไปซื้อแล้วกลับ"
                    end
                    local r2 = Root()
                    if r2 then
                        r2.CFrame = saved
                    end
                end
            end
            return ok2, how
        end
        local function Buy(id, label, qty)
            qty = math.max(1, qty or 1)
            local ok2, how = BuyNear(id, label)
            if not ok2 then
                return false, "ซื้อ " .. label .. " ไม่สำเร็จ (เงินไม่พอ/สินค้าหมด/เซิร์ฟเวอร์ไม่รับ)"
            end
            for _ = 2, qty do
                FireRaw("SeedShop", "Buy", id)
                task.wait(0.15)
            end
            return true, "ซื้อ " .. label .. " x" .. qty .. " (" .. how .. ")"
        end
        return { buy = Buy, findNpc = FindNpc, findDealer = FindDealer, goNpc = GoNpc, cash = GetCash, owned = OwnedCount }
    end)()

    local SEED_IDS = { "Kradumthong", "Chanee", "Puangmanee", "Kanyao", "Nokyip", "Monthong" }
    local function SeedTrip()
        local any = false
        for _, id in ipairs(SEED_IDS) do
            if Config["BuySeed_" .. id] then
                any = true
                local ok2, msg = Shop.buy(id, id .. " Seed", Config.SeedBuyCount)
                GMsg = "(ซื้อเมล็ด) " .. msg
                if not ok2 then
                    Status(msg)
                end
                task.wait(0.3)
            end
        end
        if not any then
            Status("ยังไม่ได้เลือกเมล็ดที่จะซื้อ (หน้า ร้านค้า)")
        end
    end
    local function PadsPass(base)
        for _, d in ipairs(base:GetChildren()) do
            if d.Name:match("^BuyPad_") and d:GetAttribute("Active") == true then
                local hb = d:FindFirstChild("Hitbox")
                if hb and hb:IsA("BasePart") then
                    local r = Root()
                    if r and firetouchinterest then
                        pcall(function()
                            firetouchinterest(r, hb, 0)
                            task.wait(0.1)
                            firetouchinterest(r, hb, 1)
                        end)
                    end
                    TP(hb.Position + Vector3.new(0, 3, 0))
                    task.wait(0.6)
                end
            end
        end
    end

    local function AnyFarmOn()
        return Config.AutoHarvest or Config.AutoPlant or Config.AutoWater or Config.AutoSell or Config.AutoSeed
            or Config.AutoPads or Config.AutoRebirth or Config.AutoBag
    end

    local function FarmTick()
        if not AnyFarmOn() then
            task.wait(0.5)
            return
        end
        local r = Root()
        if not r then
            task.wait(0.5)
            return
        end
        local base = MyBase()
        if not base then
            Status("ไม่พบฐานของคุณ (รอเกมโหลด)")
            task.wait(1)
            return
        end
        local moved = false
        if Config.AutoSeed and tick() - last.seed > Config.SeedEvery then
            last.seed = tick()
            SeedTrip()
            moved = true
        end
        if Config.AutoPlant then
            if PlantPass(base) > 0 then
                moved = true
            end
        end
        if Config.AutoWater and tick() - last.water > Config.WaterEvery then
            last.water = tick()
            WaterPass(base)
            moved = true
        end
        if Config.AutoHarvest then
            if HarvestPass(base) > 0 then
                moved = true
            end
        end
        if Config.AutoSell and tick() - last.sell > Config.SellEvery then
            last.sell = tick()
            SellTrip()
            moved = true
        end
        if Config.AutoPads and tick() - last.pads > 10 then
            last.pads = tick()
            PadsPass(base)
            moved = true
        end
        if Config.AutoRebirth and tick() - last.rebirth > Config.RebirthEvery then
            last.rebirth = tick()
            FireRaw("Rebirth")
            Status("ส่งคำสั่ง Rebirth")
        end
        if Config.AutoBag and tick() - last.bag > 30 then
            last.bag = tick()
            if HasLearned("BagUpgrade") then
                local L = Learned.BagUpgrade
                FireRaw("BagUpgrade", table.unpack(L.args, 1, L.args.n))
            else
                FireRaw("BagUpgrade")
            end
        end
        if moved and Config.ReturnHome then
            GoHome()
        end
        task.wait(0.4)
    end

    local farmRunning = false
    local function Ensure()
        if farmRunning then
            return
        end
        farmRunning = true
        task.spawn(function()
            while true do
                local ok2, e2 = pcall(FarmTick)
                if not ok2 then
                    dbg("Farm", e2)
                    task.wait(1)
                end
            end
        end)
    end
    local function T(page, key, title, desc)
        Toggle(page, {
            key = key,
            title = title,
            desc = desc,
            callback = function(v)
                if v then
                    Ensure()
                end
            end,
        })
    end

    ----------------------------------------------------------------
    -- UI : ฟาร์ม
    ----------------------------------------------------------------
    Section(PFarm, "ฟาร์มทุเรียน (ฐานของคุณ)")
    T(PFarm, "AutoHarvest", "Auto เก็บทุเรียน", "วาปไปเก็บทุเรียนที่สุกแล้วทุกลูกในฐานเรา (ข้ามลูกที่ยังดิบ)")
    T(PFarm, "AutoPlant", "Auto ปลูก", "เจอแปลงว่างก็กดปลูกให้ (ซื้อ/เลือกเมล็ดไว้ก่อน)")
    T(PFarm, "AutoWater", "Auto รดน้ำ", "ไปตักน้ำที่บ่อ แล้วรดต้นที่ปลูกอยู่")
    Slider(PFarm, {
        key = "WaterEvery", title = "รดน้ำทุก (วินาที)", desc = "ความถี่ในการรดน้ำ",
        min = 5, max = 120, step = 1, suffix = "s", callback = function() end,
    })
    Slider(PFarm, {
        key = "HarvestDelay", title = "ดีเลย์เก็บต่อลูก (ms)", desc = "ยิ่งต่ำยิ่งเร็ว (เสี่ยงขึ้น)",
        min = 30, max = 800, step = 10, suffix = "", callback = function() end,
    })
    Toggle(PFarm, {
        key = "ReturnHome", title = "กลับฐานหลังทำเสร็จ", desc = "วาปกลับจุดเกิดของฐานหลังแต่ละรอบ",
        callback = function() end,
    })
    Slider(PFarm, {
        key = "TPSpeed", title = "ความเร็ววาป (Safe Mode)", desc = "ใช้เมื่อเปิด Safe Mode (studs/วินาที)",
        min = 60, max = 1000, step = 10, suffix = "", callback = function() end,
    })

    ----------------------------------------------------------------
    -- UI : ขาย / ซื้อ / อัปเกรด
    ----------------------------------------------------------------
    Section(PShop, "ขายทุเรียน")
    T(PShop, "AutoSell", "Auto ขายทุเรียน", "วาปไปที่ Flex_Guy กดขาย แล้วกลับฐาน")
    Slider(PShop, {
        key = "SellEvery", title = "ขายทุก (วินาที)", desc = "ระยะห่างระหว่างการขาย",
        min = 10, max = 300, step = 5, suffix = "s", callback = function() end,
    })
    Button(PShop, {
        title = "ขายตอนนี้", desc = "วาปไปขายทันที 1 ครั้ง", text = "SELL",
        callback = function()
            SellTrip()
            GoHome()
        end,
    })
    Section(PShop, "ซื้อเมล็ด")
    T(PShop, "AutoSeed", "Auto ซื้อเมล็ด", "ไปร้านเมล็ดแล้วซื้อซ้ำ (ซื้อเองหนึ่งครั้งก่อนให้สคริปต์จำ)")
    Slider(PShop, {
        key = "SeedEvery", title = "ซื้อทุก (วินาที)", desc = "ระยะห่างการไปร้านเมล็ด",
        min = 20, max = 600, step = 10, suffix = "s", callback = function() end,
    })
    Slider(PShop, {
        key = "SeedBuyCount", title = "ซื้อกี่ครั้งต่อรอบ", desc = "จำนวนครั้งที่ส่งคำสั่งซื้อ",
        min = 1, max = 20, step = 1, suffix = "", callback = function() end,
    })
    Section(PShop, "อัปเกรด / Rebirth")
    T(PShop, "AutoBag", "Auto อัปเกรดกระเป๋า", "ส่งคำสั่งอัปเกรดกระเป๋าทุก 30 วิ (หักเงินในเกม)")
    T(PShop, "AutoPads", "Auto ซื้อแปลง/ยุ้งฉาง (BuyPad)", "ไปยืนบนแท่นซื้อที่เปิดอยู่ในฐานเรา (หักเงิน)")
    T(PShop, "AutoRebirth", "Auto Rebirth", "⚠ รีเซ็ตความคืบหน้า! เปิดเมื่อมั่นใจ (ทำ Rebirth เองหนึ่งครั้งให้สคริปต์จำ)")
    Slider(PShop, {
        key = "RebirthEvery", title = "Rebirth ทุก (วินาที)", desc = "ระยะห่างการส่งคำสั่ง Rebirth",
        min = 10, max = 600, step = 10, suffix = "s", callback = function() end,
    })

    ----------------------------------------------------------------
    -- UI : Durian Garden (ตัวกรอง / วิธีเก็บ / รดน้ำ / ขายรถ / ร้านค้า)
    ----------------------------------------------------------------
    Section(PFarm, "สถานะ")
    do
        local SP = Panel(PFarm, UDim2.new(1, 0, 0, 74))
        local ST = Text(SP, "", 12, FNT.M, "Muted")
        ST.Position = UDim2.fromOffset(18, 8)
        ST.Size = UDim2.new(1, -36, 1, -16)
        ST.TextWrapped = true
        ST.TextYAlignment = Enum.TextYAlignment.Top
        task.spawn(function()
            while true do
                pcall(function()
                    local base = MyBase()
                    if base then
                        local _, ripe, total = ScanFruits(base)
                        ST.Text = string.format("ฐาน: %s | สุกพร้อมเก็บ: %d / %d ลูก\nเก็บได้: %d | พลาด: %d | ขาย: %d\n%s",
                            base.Name, ripe, total, Stats.harvested, Stats.fails or 0, Stats.sold, GMsg)
                    else
                        ST.Text = "ไม่พบฐานของคุณ — ต้องมีฐานก่อน"
                    end
                end)
                task.wait(2)
            end
        end)
    end

    Section(PFarm, "ตัวกรองทุเรียน / วิธีเก็บ")
    for _, ty in ipairs({ "Puangmanee", "Kradumthong", "Chanee", "Kanyao" }) do
        Toggle(PFarm, { key = "HT_" .. ty, title = "เก็บพันธุ์ " .. ty, desc = "ปิด = ข้ามทุเรียนพันธุ์นี้", callback = function() end })
    end
    Toggle(PFarm, { key = "MutOnly", title = "เก็บเฉพาะมิวเทชัน (Gold/Diamond)", desc = "ข้ามทุเรียนธรรมดา", callback = function() end })
    Slider(PFarm, {
        key = "HarvestMethod", title = "วิธีเก็บ (1=อัตโนมัติ 2=TAP 3=Remote 4=ผสม)",
        desc = "อัตโนมัติ = ลองทุกวิธีแล้วจำวิธีที่ได้ผล", min = 1, max = 4, step = 1, suffix = "", callback = function() end,
    })
    Slider(PFarm, {
        key = "CatchWait", title = "หน่วงจับ CatchReady→Harvest (ms)", desc = "ใช้กับวิธี Remote",
        min = 0, max = 1500, step = 50, suffix = "", callback = function() end,
    })
    Slider(PFarm, {
        key = "WaterPerTree", title = "จำนวนครั้งรดต่อต้น", desc = "เกมมี 3 จุดน้ำต่อต้น",
        min = 1, max = 6, step = 1, suffix = "", callback = function() end,
    })

    Section(PShop, "ขายด้วยรถบรรทุก (ทางเลือก)")
    Toggle(PShop, {
        key = "SellTruck", title = "ขายด้วยรถ", desc = "ใส่ของ LOAD ALL → ขับไปพ่อค้า → ขาย → กลับ (ไม่มีรถ = ขายจากกระเป๋า)",
        callback = function() end,
    })
    Slider(PShop, {
        key = "SellSpeed", title = "ความเร็วรถ/ตัวละครตอนขาย", desc = "studs/วินาที", min = 60, max = 400, step = 10, suffix = "", callback = function() end,
    })
    Button(PShop, {
        title = "บันทึกจุดขาย", desc = "ไปยืน (หรือนั่งรถ) ในโซนพ่อค้า แล้วกด", text = "SAVE",
        callback = function()
            Notify(Truck.savePoint() and "บันทึกจุดขายแล้ว" or "บันทึกไม่ได้")
        end,
    })
    Button(PShop, {
        title = "ขายด้วยรถตอนนี้", desc = "ทดสอบขายด้วยรถ 1 รอบ", text = "SELL",
        callback = function()
            local ok2, msg = Truck.sell()
            Notify(tostring(msg))
        end,
    })
    local RebirthArmed = 0
    Button(PShop, {
        title = "Rebirth ตอนนี้ (กด 2 ครั้งเพื่อยืนยัน)", desc = "⚠ รีเซ็ตความคืบหน้า! Rebirth:InvokeServer()", text = "REBIRTH",
        callback = function()
            if tick() - RebirthArmed < 6 then
                RebirthArmed = 0
                FireRaw("Rebirth")
                Notify("ส่งคำสั่ง Rebirth แล้ว")
            else
                RebirthArmed = tick()
                Notify("กดอีกครั้งภายใน 6 วินาทีเพื่อยืนยัน Rebirth")
            end
        end,
    })

    -- ไฮไลต์ทุเรียนมิวเทชัน (Gold = เหลือง, Diamond = ฟ้า)
    local mutEsp = {}
    local MutSet = MakeLoop("ESPMut", 2, function()
        local base = MyBase()
        if not base then
            return
        end
        for _, d in ipairs(base:GetDescendants()) do
            if d:IsA("Model") and d.Name:match("^Fruit_%d+$") then
                local mut = d:GetAttribute("Mutation")
                if mut and not mutEsp[d] then
                    local h = Instance.new("Highlight")
                    h.Name = "RELWX_MUT"
                    h.FillTransparency = 0.5
                    h.OutlineTransparency = 0
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillColor = (mut == "Diamond") and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(255, 200, 0)
                    h.OutlineColor = Color3.new(1, 1, 1)
                    h.Parent = d
                    mutEsp[d] = h
                end
            end
        end
        for m, h in pairs(mutEsp) do
            if not m.Parent or not m:GetAttribute("Mutation") then
                pcall(function() h:Destroy() end)
                mutEsp[m] = nil
            end
        end
    end)
    Toggle(PExtra, {
        key = "ESPMut", title = "ไฮไลต์ทุเรียนมิวเทชัน", desc = "เหลือง = Gold / ฟ้า = Diamond (ในฐานเรา)",
        callback = function(v)
            MutSet(v)
            if not v then
                for m, h in pairs(mutEsp) do
                    pcall(function() h:Destroy() end)
                    mutEsp[m] = nil
                end
            end
        end,
    })

    -- หน้าร้านค้า
    local PGShop = MakePage("GShop", "ร้านค้า (Seed Shop)", "ซื้อเมล็ด  •  ปุ๋ย  •  โทนิค  •  ปืนน้ำ  (ไม่มีปุ่ม Robux)")
    Section(PGShop, "จำนวนที่ซื้อต่อครั้ง")
    Slider(PGShop, {
        key = "BuyQty", title = "จำนวน", desc = "กดซื้อครั้งเดียวส่งคำสั่งซื้อกี่ชิ้น", min = 1, max = 50, step = 1, suffix = "", callback = function() end,
    })
    Section(PGShop, "เมล็ดที่ Auto ซื้อ (เปิด Auto ซื้อเมล็ดในหน้า ขาย/ซื้อ)")
    for _, id in ipairs(SEED_IDS) do
        Toggle(PGShop, { key = "BuySeed_" .. id, title = "Auto ซื้อ " .. id, desc = "รวมในรอบ Auto ซื้อเมล็ด", callback = function() end })
    end
    local SHOP_ITEMS = {
        { "เมล็ดพันธุ์", {
            { "Kradumthong", "Kradumthong Seed", "$40", "โต 3 นาที · ผล ~$15" },
            { "Chanee", "Chanee Seed", "$200", "โต 6 นาที · ผล ~$60" },
            { "Puangmanee", "Puangmanee Seed", "$800", "โต 12 นาที · ผล ~$160" },
            { "Kanyao", "Kanyao Seed", "$2,500", "โต 30 นาที · ผล ~$450" },
            { "Nokyip", "Nokyip Seed", "$7,500", "โต 1 ชม. · ผล ~$1,200" },
            { "Monthong", "Monthong Seed", "$20,000", "โต 2 ชม. · ผล ~$3,500" },
        } },
        { "ปุ๋ย / โทนิค", {
            { "Fert_Basic", "Basic Fertilizer", "$500", "เร่งต้น 2 นาที" },
            { "Fert_Super", "Super Fertilizer", "$5,000", "เร่งต้น 8 นาที" },
            { "Fert_Mega", "Mega Fertilizer", "$10,000", "เร่งต้น 30 นาที" },
            { "Fert_TonicBasic", "Basic Tree Tonic", "$500", "ออกผลเพิ่ม 20 ครั้ง" },
            { "Fert_TonicSuper", "Super Tree Tonic", "$5,000", "ผลเพิ่ม 20 + หนักขึ้น" },
            { "Fert_TonicMega", "Mega Tree Tonic", "$10,000", "ผลเพิ่ม 20 + หนักมาก" },
        } },
        { "ปืนน้ำ / ต้นกล้า", {
            { "Fert_Gun_Pistol", "Splash Pistol", "$3,000", "10 นัด" },
            { "Fert_Gun_Shotgun", "Twin Soaker", "$12,000", "ลำกล้องคู่" },
            { "Fert_RubberSapling", "Rubber Sapling", "$1,500", "ปลูกในแปลงยาง" },
        } },
    }
    local buyBusy = false
    for _, cat in ipairs(SHOP_ITEMS) do
        Section(PGShop, cat[1])
        for _, it in ipairs(cat[2]) do
            local id, label, price, desc = it[1], it[2], it[3], it[4]
            Button(PGShop, {
                title = label .. "  " .. price, desc = desc, text = "BUY",
                callback = function()
                    if buyBusy then
                        Notify("กำลังซื้ออยู่ รอสักครู่")
                        return
                    end
                    buyBusy = true
                    local okp, _, msg = pcall(Shop.buy, id, label, Config.BuyQty)
                    buyBusy = false
                    Notify(okp and tostring(msg) or "ซื้อไม่สำเร็จ")
                end,
            })
        end
    end

    ----------------------------------------------------------------
    ----------------------------------------------------------------
    -- ไก่ตัน
    ----------------------------------------------------------------
    local ALL_ON = { "AutoSeed", "AutoPlant", "AutoWater", "AutoHarvest", "AutoSell", "ReturnHome", "AntiAFK", "AntiKick", "ESPFruit" }
    local function SetMany(list, v)
        for _, k in ipairs(list) do
            local h = Handles[k]
            if h and h.Set then
                h.Set(v)
            else
                Config[k] = v
            end
        end
    end
    Section(PAll, "ปุ่มเดียวจบ")
    Toggle(PAll, {
        key = "GodAll",
        title = "ไก่ตัน: ฟาร์มทุเรียนครบวงจร",
        desc = "ซื้อเมล็ด → ปลูก → รดน้ำ → เก็บ → ขาย วนไปเรื่อย ๆ + กัน AFK/Kick + ไฮไลต์ทุเรียนสุก",
        callback = function(v)
            SetMany(ALL_ON, v)
            if v then
                Ensure()
                Notify("เปิดไก่ตัน: ฟาร์มทุเรียนอัตโนมัติ")
            else
                Notify("ปิดไก่ตันแล้ว")
            end
        end,
    })
    Button(PAll, {
        title = "PANIC ปิดทุกอย่าง", desc = "ปิดฟังก์ชันฟาร์ม/ซื้อ/Rebirth ทั้งหมดทันที", text = "STOP",
        callback = function()
            SetMany({ "AutoSeed", "AutoPlant", "AutoWater", "AutoHarvest", "AutoSell", "AutoBag", "AutoPads", "AutoRebirth", "GodAll" }, false)
            Notify("หยุดทุกอย่างแล้ว")
        end,
    })

    ----------------------------------------------------------------
    -- วาป
    ----------------------------------------------------------------
    Section(PTele, "วาปไปจุดสำคัญ")
    local function TeleBtn(title, desc, getPos)
        Button(PTele, {
            title = title, desc = desc, text = "GO",
            callback = function()
                local pos = getPos()
                if pos then
                    TP(pos + Vector3.new(0, 4, 0))
                else
                    Notify("หาจุดนี้ไม่เจอ")
                end
            end,
        })
    end
    TeleBtn("ฐานของฉัน", "จุดเกิดในฐาน", function()
        local b = MyBase()
        return b and PosOf(b:FindFirstChild("SpawnPad"))
    end)
    TeleBtn("แปลงปลูก", "กลางแปลงทุเรียน", function()
        local b = MyBase()
        local it = b and b:FindFirstChild("Items")
        return PosOf(it and it:FindFirstChild("FarmPlot") and it.FarmPlot:FindFirstChild("Root"))
    end)
    TeleBtn("บ่อน้ำ", "จุดตักน้ำ", function()
        local p = BasePrompt("FillPrompt")
        return p and PosOf(p.Parent)
    end)
    TeleBtn("ร้านเมล็ด (ShanaKung)", "ซื้อเมล็ด", function()
        local p = MapPrompt("ShopPrompt")
        return p and PosOf(p.Parent)
    end)
    TeleBtn("จุดขายทุเรียน (Flex_Guy)", "ขายทุเรียน", function()
        local p = MapPrompt("SellPrompt")
        return p and PosOf(p.Parent)
    end)
    TeleBtn("โรงรถ", "Garage", function()
        local p = BasePrompt("GaragePrompt")
        return p and PosOf(p.Parent)
    end)
    TeleBtn("หีบเก็บของ", "StorageChest ในกระท่อม", function()
        local p = BasePrompt("ChestPrompt")
        return p and PosOf(p.Parent)
    end)
    Button(PTele, {
        title = "NPC ร้านเมล็ด (ShanaKung)", desc = "ยืนหน้า NPC", text = "GO",
        callback = function()
            Notify(Shop.goNpc(Shop.findNpc(), "BlazerGuy_Mesh") and "วาร์ปแล้ว" or "ไม่พบ NPC ร้านเมล็ด")
        end,
    })
    Button(PTele, {
        title = "NPC Car Dealer (Traveler_Guy)", desc = "ยืนหน้า NPC", text = "GO",
        callback = function()
            local npc = Shop.findDealer()
            Notify((npc and Shop.goNpc(npc, "RootPart")) and "วาร์ปแล้ว" or "ไม่พบ NPC Car Dealer")
        end,
    })
    TeleBtn("ลานจอดรถ", "Parking ในฐาน", function()
        local b = MyBase()
        local it = b and b:FindFirstChild("Items")
        return PosOf(it and it:FindFirstChild("Parking"))
    end)
    Button(PTele, {
        title = "จุดขาย (ที่บันทึกไว้)", desc = "วาร์ปไปจุดที่บันทึกในหน้า ขาย/ซื้อ", text = "GO",
        callback = function()
            local x, y, z = tostring(Config.SellPoint):match("^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
            if x then
                TP(Vector3.new(tonumber(x), tonumber(y) + 4, tonumber(z)))
            else
                Notify("ยังไม่ได้บันทึกจุดขาย")
            end
        end,
    })

    ----------------------------------------------------------------
    -- ป้องกัน
    ----------------------------------------------------------------
    Section(PSafe, "ป้องกัน")
    pcall(function()
        local VU = game:GetService("VirtualUser")
        LocalPlayer.Idled:Connect(function()
            if Config.AntiAFK then
                pcall(function()
                    VU:CaptureController()
                    VU:ClickButton2(Vector2.new())
                end)
            end
        end)
    end)
    Toggle(PSafe, {
        key = "AntiAFK", title = "Anti-AFK", desc = "กันโดนเตะเพราะไม่ขยับ",
        callback = function() end,
    })
    local AfkJ = MakeLoop("AfkJitter", 55, function()
        local r = Root()
        if r then
            r.CFrame = r.CFrame * CFrame.new(0.05, 0, 0)
        end
    end)
    Toggle(PSafe, {
        key = "AntiAFK2", title = "Anti-AFK แบบแรง", desc = "ขยับตัวละครเล็กน้อยทุก ~1 นาที",
        callback = function(v) AfkJ(v) end,
    })
    Toggle(PSafe, {
        key = "AntiKick", title = "Anti-Kick", desc = "ดักคำสั่ง Kick ฝั่งไคลเอนต์ (ต้อง executor รองรับ hook)",
        callback = function() end,
    })
    Toggle(PSafe, {
        key = "SafeMode", title = "Safe Mode", desc = "วาปเป็นช่วง ๆ + สุ่มดีเลย์ให้ดูเป็นธรรมชาติ",
        callback = function() end,
    })
    local function ServerHop()
        local ok2, res = pcall(function()
            local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", game.PlaceId)
            local data = HttpService:JSONDecode(game:HttpGet(url))
            for _, s in ipairs(data.data or {}) do
                if s.id ~= game.JobId and s.playing < s.maxPlayers - 1 then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
                    return true
                end
            end
            return false
        end)
        if not ok2 or not res then
            Notify("หาเซิร์ฟเวอร์ใหม่ไม่เจอ")
        end
    end
    Button(PSafe, { title = "ย้ายเซิร์ฟเวอร์ (Server Hop)", desc = "ไปเซิร์ฟเวอร์สาธารณะอื่น", text = "HOP", callback = ServerHop })
    Button(PSafe, {
        title = "Rejoin", desc = "เข้าเซิร์ฟเวอร์เดิมใหม่", text = "GO",
        callback = function()
            pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
        end,
    })

    ----------------------------------------------------------------
    -- เครื่องมือเสริม
    ----------------------------------------------------------------
    Section(PExtra, "ESP / ภาพ")
    local esp = {}
    local EspSet = MakeLoop("ESP", 1, function()
        local base = MyBase()
        if not base then
            return
        end
        local alive = {}
        for _, p in ipairs(RipePrompts(base)) do
            local part = p.Parent
            local model = part and part:FindFirstAncestorWhichIsA("Model")
            while model and not model.Name:match("^Fruit_%d+$") do
                model = model.Parent and model.Parent:IsA("Model") and model.Parent or nil
            end
            model = model or part
            if model then
                alive[model] = true
                if not esp[model] then
                    local h = Instance.new("Highlight")
                    h.FillColor = model:GetAttribute("Mutation") and Color3.fromRGB(255, 200, 40) or Color3.fromRGB(90, 255, 120)
                    h.FillTransparency = 0.45
                    h.OutlineColor = Color3.new(1, 1, 1)
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Parent = model
                    esp[model] = h
                end
            end
        end
        for m, h in pairs(esp) do
            if not alive[m] or not m.Parent then
                pcall(function() h:Destroy() end)
                esp[m] = nil
            end
        end
    end)
    Toggle(PExtra, {
        key = "ESPFruit", title = "ไฮไลต์ทุเรียนสุก", desc = "เขียว = สุก / ทอง = ทุเรียนกลายพันธุ์ (Mutation)",
        callback = function(v)
            EspSet(v)
            if not v then
                for m, h in pairs(esp) do
                    pcall(function() h:Destroy() end)
                    esp[m] = nil
                end
            end
        end,
    })
    local fpsSaved = false
    Toggle(PExtra, {
        key = "FPSBoost", title = "FPS Boost", desc = "ลดคุณภาพกราฟิก/ปิดเอฟเฟกต์ เพื่อให้ลื่นขึ้น",
        callback = function(v)
            if not v then
                return
            end
            pcall(function()
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end)
            local L = game:GetService("Lighting")
            L.GlobalShadows = false
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke") or d:IsA("Fire") then
                    d.Enabled = false
                end
            end
        end,
    })
    Toggle(PExtra, {
        key = "FullBright", title = "สว่างเต็มที่", desc = "ปรับแสงให้สว่างตลอด",
        callback = function(v)
            if v then
                local L = game:GetService("Lighting")
                L.Brightness = 2
                L.ClockTime = 14
                L.FogEnd = 1e6
                L.GlobalShadows = false
            end
        end,
    })

    ----------------------------------------------------------------
    -- ระบบ
    ----------------------------------------------------------------
    Section(PSys, "ตัวเรียนรู้คำสั่ง / ตรวจระบบ")
    Toggle(PSys, {
        key = "RemoteLog", title = "แสดง Log คำสั่งที่เกมส่ง", desc = "พิมพ์ชื่อ+args ของคำสั่งที่คุณกดเองลง Console (F9)",
        callback = function() end,
    })
    Button(PSys, {
        title = "ตรวจระบบ (Diagnose)", desc = "พิมพ์สถานะฐาน แปลง ทุเรียนสุก และคำสั่งที่เรียนรู้ ลง Console (F9)", text = "CHECK",
        callback = function()
            local b = MyBase()
            local names = {}
            for n, L in pairs(Learned) do
                names[#names + 1] = n .. "x" .. L.count
            end
            table.sort(names)
            print("[RELWX][DIAG] hook=", HookOK, "base=", b and b.Name or "nil", "learned=", table.concat(names, ","))
            if b then
                for _, slot in ipairs(SlotsOf(b)) do
                    local ti, su = SlotInfoText(slot)
                    print("[RELWX][DIAG]", slot.Name, "planted=", IsPlanted(slot), ti, "|", su)
                end
                print("[RELWX][DIAG] ripe prompts=", #RipePrompts(b),
                    "fill=", BasePrompt("FillPrompt") ~= nil, "sell=", MapPrompt("SellPrompt") ~= nil, "shop=", MapPrompt("ShopPrompt") ~= nil)
            end
            Notify("พิมพ์ผลตรวจลง Console แล้ว (F9)")
        end,
    })
    Button(PSys, {
        title = "แสดงคำสั่งที่เรียนรู้แล้ว", desc = "ดูว่าสคริปต์จำคำสั่งอะไรไปบ้าง", text = "LIST",
        callback = function()
            local names = {}
            for n, L in pairs(Learned) do
                names[#names + 1] = n .. " x" .. L.count .. "  (" .. FmtArgs(L.args) .. ")"
            end
            table.sort(names)
            print("[RELWX] learned:\n" .. table.concat(names, "\n"))
            Notify(HookOK and ("เรียนรู้แล้ว " .. #names .. " คำสั่ง") or "executor ไม่รองรับตัวดักจับ")
        end,
    })

    print("[RELWX] Durian features loaded | hook=" .. tostring(HookOK))
end)
if not ok then
    warn("[RELWX] features error: " .. tostring(err))
end
end)()

--==================================================
-- SETTINGS
--==================================================

local Settings = MakePage("Settings", "ตั้งค่า", "ปรับแต่งหน้าตา RELWX  •  เปลี่ยนแล้วเซฟทันที")

Section(Settings, "ระบบ")

Toggle(Settings, {
    key = "SoundEnabled",
    title = "เสียงตอนเปิด/ปิดฟังก์ชัน",
    desc = "เล่นเสียงสั้นๆ เมื่อกดสวิตช์",
})

Toggle(Settings, {
    key = "StatsVisible",
    title = "แสดง FPS / MS",
    desc = "กล่องเล็กลากย้ายตำแหน่งได้",
    callback = function(v)
        StatsGui.Enabled = v
    end,
})

Slider(Settings, {
    key = "UIScalePercent",
    title = "ขนาดหน้าต่าง",
    desc = "ปรับเพิ่มจากขนาดอัตโนมัติตามหน้าจอ",
    min = 60,
    max = 120,
    step = 5,
    suffix = "%",
    callback = function()
        ApplyScale(true)
    end,
})

Section(Settings, "ธีมสำเร็จรูป")
ThemeGrid(Settings)

Section(Settings, "ธีม UI")
ColorRow(Settings, "สีหลัก UI", "UIAccentColor")
ColorRow(Settings, "สีพื้นหลัง UI", "UIBackgroundColor")
ColorRow(Settings, "สีปุ่ม UI", "UIButtonColor")

Section(Settings, "ปุ่มลอย RX")
ColorRow(Settings, "สีปุ่ม RX", "FloatingButtonColor")
ColorRow(Settings, "สีขอบ RX", "FloatingBorderColor")
ColorRow(Settings, "สี Glow RX", "FloatingGlowColor")

Section(Settings, "Config")

local CfgCard = Panel(Settings, UDim2.new(1, 0, 0, 64))
local CfgTitle = Text(CfgCard, "บันทึกอัตโนมัติ", 13, FNT.M, "Text")
CfgTitle.Position = UDim2.fromOffset(16, 11)
CfgTitle.Size = UDim2.new(1, -140, 0, 20)
local CfgDesc = Text(
    CfgCard,
    writefile and CONFIG_FILE or "executor นี้ไม่รองรับการเขียนไฟล์",
    10,
    FNT.R,
    "Muted"
)
CfgDesc.Position = UDim2.fromOffset(16, 33)
CfgDesc.Size = UDim2.new(1, -140, 0, 18)
local CfgPill = StatusPill(CfgCard, 108)
CfgPill.AnchorPoint = Vector2.new(1, 0.5)
CfgPill.Position = UDim2.new(1, -14, 0.5, 0)

local ResetRow = Panel(Settings, UDim2.new(1, 0, 0, 50), "TextButton")
HoverRow(ResetRow)
local ResetLabel = Text(ResetRow, "รีเซ็ตการตั้งค่าทั้งหมด", 12, FNT.M, RGB(235, 90, 100))
ResetLabel.Position = UDim2.fromOffset(16, 0)
ResetLabel.Size = UDim2.new(1, -32, 1, 0)

local FloatApplyPosition

local resetArmed = false
ResetRow.MouseButton1Click:Connect(function()
    if not resetArmed then
        resetArmed = true
        ResetLabel.Text = "กดอีกครั้งเพื่อยืนยันการรีเซ็ต"
        task.delay(3, function()
            resetArmed = false
            ResetLabel.Text = "รีเซ็ตการตั้งค่าทั้งหมด"
        end)
        return
    end
    resetArmed = false
    ResetLabel.Text = "รีเซ็ตการตั้งค่าทั้งหมด"

    for k, v in pairs(Defaults) do
        Config[k] = v
    end
    Collapsed = {}
    for _, secs in pairs(SectionsByPage) do
        for _, sec in ipairs(secs) do
            sec.collapsed = false
            sec.refresh(true)
        end
    end
    ApplyTheme()
    for _, fn in ipairs(Refreshers) do
        pcall(fn)
    end
    Tween(Main, 0.3, { Position = UDim2.fromScale(Config.WindowX, Config.WindowY) }, Enum.EasingStyle.Quint)
    ApplyScale(true)
    if FloatApplyPosition then
        FloatApplyPosition()
    end
    StatsBox.Position = UDim2.fromScale(Config.StatsX, Config.StatsY)
    StatsGui.Enabled = Config.StatsVisible
    SelectTab(Config.LastTab)
    SaveConfig(true)
    Toast("รีเซ็ตการตั้งค่าแล้ว")
end)

--==================================================
-- SIDEBAR CATEGORIES
--==================================================

CatGroup("เมนูหลัก")
Category("หน้าหลัก", "Home", "grid")
Category("ไก่ตัน ALL-IN-ONE", "AllIn", "ring")
Category("ฟาร์มทุเรียน", "Farm", "sliders")
Category("ขาย / ซื้อ / อัปเกรด", "Shop", "grid")
Category("ร้านค้า (Seed Shop)", "GShop", "grid")
Category("วาป", "Teleport", "ring")
Category("ป้องกัน", "Safe", "sliders")
Category("เครื่องมือเสริม", "Extra", "grid")
Category("ระบบ", "System", "grid")
CatGroup("ตั้งค่า")
Category("ตั้งค่า", "Settings", "ring")

--==================================================
-- FLOATING RX BUTTON
--==================================================

local ToggleGui = New("ScreenGui", {
    Name = "RELWX_Floating",
    ResetOnSpawn = false,
    DisplayOrder = 999999,
    IgnoreGuiInset = true,
}, PlayerGui)

local Float = New("Frame", {
    Size = UDim2.fromOffset(48, 48),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(Config.FloatX, Config.FloatY),
    BackgroundTransparency = 1,
    Active = true,
}, ToggleGui)

local Glow = New("Frame", {
    Size = UDim2.new(1, 8, 1, 8),
    Position = UDim2.fromScale(0.5, 0.5),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
}, Float)
Corner(Glow, 15)
local GlowStroke = Stroke(Glow, RGB(145, 145, 145), 3, 0.2)

local RX = New("TextButton", {
    Size = UDim2.fromScale(1, 1),
    Text = "RX",
    TextSize = 15,
    Font = FNT.B,
    BorderSizePixel = 0,
    AutoButtonColor = false,
    Active = true,
}, Float)
Corner(RX, 13)
local RXStroke = Stroke(RX, RGB(255, 255, 255), 2, 0.05)
local RXGrad = New("UIGradient", {
    Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.85),
        NumberSequenceKeypoint.new(1, 0),
    }),
}, RXStroke)
TweenService:Create(
    RXGrad,
    TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
    { Rotation = 360 }
):Play()

OnTheme(function()
    local bg = Hex("FloatingButtonColor", RGB(18, 18, 18))
    RX.BackgroundColor3 = bg
    RX.TextColor3 = Lum(bg) > 0.55 and RGB(15, 15, 15) or RGB(255, 255, 255)
    RXStroke.Color = Hex("FloatingBorderColor", RGB(255, 255, 255))
    GlowStroke.Color = Hex("FloatingGlowColor", RGB(145, 145, 145))
end)

TweenService:Create(
    GlowStroke,
    TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
    { Transparency = 0.65 }
):Play()

FloatApplyPosition = function()
    Float.Position = UDim2.fromScale(Config.FloatX, Config.FloatY)
end

MakeDraggable(RX, Float, "FloatX", "FloatY", function()
    SetWindow(not Config.WindowVisible)
end)

--==================================================
-- START
--==================================================

SelectTab(Config.LastTab)
RefreshStats()
RefreshHome()

if Config.WindowVisible then
    PlayOpen()
end

if not LoadedFromFile then
    SaveConfig(true) -- สร้างไฟล์ Config ครั้งแรก
end

print("[RELWX] UI v7 Loaded" .. (LoadedFromFile and " (Config loaded)" or " (new Config)"))
