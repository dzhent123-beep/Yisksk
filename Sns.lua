--// GalaXoR Hub | Murder Mystery 2 | v5
local genv = (getgenv and getgenv()) or _G
if genv.GalaXoR_Unload then pcall(genv.GalaXoR_Unload) end

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")
local TweenService    = game:GetService("TweenService")
local Lighting        = game:GetService("Lighting")
local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser     = game:GetService("VirtualUser")
local CoreGui         = game:GetService("CoreGui")

local LP        = Players.LocalPlayer
local GuiParent = (gethui and gethui()) or CoreGui

--// config: every feature starts OFF
local CFG = {
    Aimbot = false, AimHold = true, AimPart = "Head", AimFov = 150, AimSmooth = 35,
    KillAura = false, AuraRange = 18, AutoGrab = false, AutoFarm = false,
    ESP = false, EspName = true, EspRole = true, EspDist = true, EspGun = true, EspCoin = false, Chams = false,
    Speed = false, WalkSpeed = 40, Fly = false, FlySpeed = 80, Noclip = false, InfJump = false,
    AntiFling = false, AntiAim = false, Fullbright = false, AntiAFK = false,
    MenuHue = 355, MenuSat = 80, MenuSize = 100, MenuOpacity = 0,
}

--// state
local conns      = {}
local timers     = { aura = 0, grab = 0, farm = 0, esp = 0, scan = 0 }
local rmbHeld    = false
local menuOpen   = false
local tpTarget   = nil
local world      = { coins = {}, gun = nil }
local espStore   = {}
local neckBase   = {}
local aaOn       = false
local flyOn      = false
local speedOn    = false
local fbOn       = false
local origLight  = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
}

local function track(c) conns[#conns + 1] = c return c end

--// colors
local function hsv(h, s, v)
    return Color3.fromHSV((h % 360) / 360, math.clamp(s / 100, 0, 1), math.clamp(v / 100, 0, 1))
end
local function accent() return hsv(CFG.MenuHue, CFG.MenuSat, 100) end
local C = {
    bg    = Color3.fromRGB(12, 12, 14),
    panel = Color3.fromRGB(18, 18, 21),
    row   = Color3.fromRGB(26, 26, 30),
    rowH  = Color3.fromRGB(36, 36, 42),
    off   = Color3.fromRGB(52, 52, 58),
    text  = Color3.fromRGB(235, 235, 240),
    dim   = Color3.fromRGB(125, 125, 135),
}

--// repaint registry
local refreshers = {}
local function bind(fn)
    refreshers[#refreshers + 1] = fn
    local ok, err = pcall(fn)
    if not ok then warn("[GalaXoR] " .. tostring(err)) end
end
local function refreshAll()
    for _, f in ipairs(refreshers) do
        local ok, err = pcall(f)
        if not ok then warn("[GalaXoR] " .. tostring(err)) end
    end
end

--// instance helpers
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local function round(o, r)
    new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o)
    return o
end
local function stroke(o, th, col)
    return new("UIStroke", { Thickness = th or 1, Color = col or C.dim,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local orders = setmetatable({}, { __mode = "k" })
local function nextOrder(page)
    orders[page] = (orders[page] or 0) + 1
    return orders[page]
end

--// root gui
local gui = new("ScreenGui", {
    Name = "GalaXoR_UI", ResetOnSpawn = false, DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
if syn and syn.protect_gui then pcall(syn.protect_gui, gui) end
gui.Parent = GuiParent

--// toast
local toastHolder = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16),
    Size = UDim2.fromOffset(300, 200), BackgroundTransparency = 1, ZIndex = 50,
}, gui)
new("UIListLayout", {
    VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, toastHolder)
local toastN = 0
local function toast(msg)
    toastN += 1
    local t = round(new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 51,
        Text = tostring(msg), Font = Enum.Font.GothamMedium, TextSize = 12,
        TextColor3 = C.text, LayoutOrder = toastN,
    }, toastHolder), 6)
    stroke(t, 1, accent())
    task.delay(2.2, function()
        if t then pcall(function() t:Destroy() end) end
    end)
end

--// drag: tap vs drag aware
local function makeDraggable(handle, target, onTap)
    local dragging, moved, startMouse, startPos = false, false, nil, nil
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startMouse, startPos = i.Position, target.Position
        end
    end)
    track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startMouse
            if d.Magnitude > 6 then moved = true end
            if moved then
                target.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end))
    track(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if dragging and not moved and onTap then onTap() end
            dragging = false
        end
    end))
end

--// main window (created before icon so icon can reference it)
local main = round(new("Frame", {
    Name = "Main", Size = UDim2.fromOffset(460, 300), Position = UDim2.new(0.5, -230, 0.5, -150),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, Visible = false, Active = true, ClipsDescendants = true,
}, gui), 8)
local mainScale = new("UIScale", { Scale = 1 }, main)
local mainStroke = stroke(main, 1.5, accent())
bind(function() mainStroke.Color = accent() end)

--// floating square icon
local icon = round(new("Frame", {
    Name = "Icon", Size = UDim2.fromOffset(38, 38), Position = UDim2.new(0, 12, 0.45, 0),
    BackgroundColor3 = C.bg, BorderSizePixel = 0, Active = true, ZIndex = 5,
}, gui), 6)
local iconStroke = stroke(icon, 1.5, accent())
bind(function() iconStroke.Color = accent() end)
local iconLbl = new("TextLabel", {
    BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "G",
    Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = accent(), ZIndex = 6,
}, icon)
bind(function() iconLbl.TextColor3 = accent() end)

--// top bar
local top = round(new("Frame", {
    Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.panel, BorderSizePixel = 0, Active = true, ZIndex = 2,
}, main), 8)
new("Frame", {
    Position = UDim2.new(0, 0, 1, -8), Size = UDim2.new(1, 0, 0, 8),
    BackgroundColor3 = C.panel, BorderSizePixel = 0, ZIndex = 2,
}, top)
local titleLbl = new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(120, 34),
    Text = "GalaXoR", Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = accent(),
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
}, top)
bind(function() titleLbl.TextColor3 = accent() end)
new("TextLabel", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(100, 0), Size = UDim2.fromOffset(80, 34),
    Text = "HUB", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
}, top)
local closeBtn = new("TextButton", {
    BackgroundTransparency = 1, Position = UDim2.new(1, -32, 0, 0), Size = UDim2.fromOffset(32, 34),
    Text = "×", Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = C.dim,
    AutoButtonColor = false, ZIndex = 3,
}, top)

--// sidebar (left) + content (right)
local sidebar = new("Frame", {
    Position = UDim2.fromOffset(0, 34), Size = UDim2.new(0, 116, 1, -34),
    BackgroundColor3 = C.panel, BorderSizePixel = 0,
}, main)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)
new("UIPadding", {
    PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
}, sidebar)
local content = new("Frame", {
    Position = UDim2.fromOffset(124, 42), Size = UDim2.new(1, -134, 1, -50), BackgroundTransparency = 1,
}, main)

local tabBtn, pages, currentTab = {}, {}, nil
local function selectTab(name)
    currentTab = name
    for n, p in pairs(pages) do p.Visible = (n == name) end
    for n, t in pairs(tabBtn) do
        local on = (n == name)
        t.btn.BackgroundColor3 = on and C.rowH or C.panel
        t.lbl.TextColor3 = on and accent() or C.dim
        t.bar.Visible = on
    end
end
bind(function() if currentTab then selectTab(currentTab) end end)

local tabCount = 0
local function makePage(name)
    tabCount += 1
    local btn = round(new("TextButton", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.panel, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false, LayoutOrder = tabCount,
    }, sidebar), 6)
    local bar = round(new("Frame", {
        Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = accent(), BorderSizePixel = 0, Visible = false,
    }, btn), 2)
    bind(function() bar.BackgroundColor3 = accent() end)
    local lbl = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -14, 1, 0),
        Text = name, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, btn)
    tabBtn[name] = { btn = btn, bar = bar, lbl = lbl }
    btn.MouseButton1Click:Connect(function() selectTab(name) end)

    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = accent(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false,
    }, content)
    bind(function() page.ScrollBarImageColor3 = accent() end)
    new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    new("UIPadding", { PaddingRight = UDim.new(0, 4) }, page)
    pages[name] = page
    return page
end

--// components
local function sectionTitle(page, text)
    new("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 14),
        Text = string.upper(text), Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder(page),
    }, page)
end

local function makeRow(page, h)
    return round(new("TextButton", {
        Size = UDim2.new(1, -4, 0, h), BackgroundColor3 = C.row, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false, LayoutOrder = nextOrder(page),
    }, page), 6)
end

local function toggle(page, text, key, cb)
    local r = makeRow(page, 32)
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -66, 1, 0),
        Text = text, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, r)
    local pill = round(new("Frame", {
        Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -44, 0.5, -9),
        BackgroundColor3 = C.off, BorderSizePixel = 0,
    }, r), 9)
    local knob = round(new("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, pill), 7)
    local function render(instant)
        local on = CFG[key] == true
        local info = TweenInfo.new(instant and 0 or 0.16, Enum.EasingStyle.Quart)
        TweenService:Create(pill, info, { BackgroundColor3 = on and accent() or C.off }):Play()
        TweenService:Create(knob, info, {
            Position = on and UDim2.new(1, -16, 0, 2) or UDim2.fromOffset(2, 2),
        }):Play()
    end
    bind(function() render(true) end)
    r.MouseButton1Click:Connect(function()
        CFG[key] = not CFG[key]
        render(false)
        if cb then
            local ok, err = pcall(cb, CFG[key])
            if not ok then toast("error: " .. tostring(err)) end
        end
    end)
end

local function slider(page, text, key, min, max, step, opts)
    opts = opts or {}
    local r = makeRow(page, 44)
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -80, 0, 16),
        Text = text, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, r)
    local val = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -70, 0, 5), Size = UDim2.fromOffset(60, 16),
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, r)
    local bar = round(new("Frame", {
        Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 4),
        BackgroundColor3 = C.off, BorderSizePixel = 0,
    }, r), 2)
    local fill = round(new("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = accent(), BorderSizePixel = 0,
    }, bar), 2)
    if opts.hue then
        new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, hsv(0, 100, 100)),
                ColorSequenceKeypoint.new(0.17, hsv(60, 100, 100)),
                ColorSequenceKeypoint.new(0.33, hsv(120, 100, 100)),
                ColorSequenceKeypoint.new(0.5, hsv(180, 100, 100)),
                ColorSequenceKeypoint.new(0.67, hsv(240, 100, 100)),
                ColorSequenceKeypoint.new(0.83, hsv(300, 100, 100)),
                ColorSequenceKeypoint.new(1, hsv(360, 100, 100)),
            }),
        }, bar)
        fill.BackgroundTransparency = 1
    end
    local knob = round(new("Frame", {
        Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = 3,
    }, fill), 6)

    local function render()
        local p = (CFG[key] - min) / (max - min)
        fill.Size = UDim2.new(math.clamp(p, 0, 1), 0, 1, 0)
        if not opts.hue then fill.BackgroundColor3 = accent() end
        val.Text = string.format("%g", CFG[key])
    end
    bind(render)

    local dragging = false
    local function setFrom(x)
        local w = math.max(bar.AbsoluteSize.X, 1)
        local p = math.clamp((x - bar.AbsolutePosition.X) / w, 0, 1)
        local v = math.clamp(min + math.floor((max - min) * p / step + 0.5) * step, min, max)
        if CFG[key] ~= v then
            CFG[key] = v
            render()
            if opts.cb then
                local ok, err = pcall(opts.cb, v)
                if not ok then toast("error: " .. tostring(err)) end
            end
        end
    end
    local hit = new("TextButton", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 20), Size = UDim2.new(1, -12, 0, 20),
        Text = "", AutoButtonColor = false, ZIndex = 4,
    }, r)
    hit.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFrom(i.Position.X)
        end
    end)
    track(UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            setFrom(i.Position.X)
        end
    end))
end

local function cycle(page, label, key, options)
    local b = makeRow(page, 32)
    new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -120, 1, 0),
        Text = label, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, b)
    local val = new("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(1, -120, 0, 0), Size = UDim2.fromOffset(110, 32),
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right,
    }, b)
    local function render() val.Text = tostring(CFG[key]) end
    render()
    b.MouseButton1Click:Connect(function()
        local idx = 1
        for i, v in ipairs(options) do
            if v == CFG[key] then idx = i break end
        end
        CFG[key] = options[idx % #options + 1]
        render()
    end)
end

local function button(page, text, cb)
    local b = makeRow(page, 30)
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.TextColor3 = C.text
    b.MouseEnter:Connect(function() b.BackgroundColor3 = C.rowH end)
    b.MouseLeave:Connect(function() b.BackgroundColor3 = C.row end)
    b.MouseButton1Click:Connect(function()
        if cb then
            local ok, err = pcall(cb)
            if not ok then toast("error: " .. tostring(err)) end
        end
    end)
end

--// helpers
local canTouch = typeof(firetouchinterest) == "function"
local function getHRP(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(c)
    local h = getHum(c)
    return h ~= nil and h.Health > 0
end
local function ownHRP() return getHRP(LP.Character) end

local function hasTool(p, name)
    local c = p.Character
    if c and c:FindFirstChild(name) then return true end
    local bp = p:FindFirstChildOfClass("Backpack")
    return bp ~= nil and bp:FindFirstChild(name) ~= nil
end
local function roleOf(p)
    if hasTool(p, "Knife") then return "Murderer" end
    if hasTool(p, "Gun") then return "Sheriff" end
    return "Innocent"
end
local function roleColor(role)
    if role == "Murderer" then return Color3.fromRGB(255, 70, 80) end
    if role == "Sheriff" then return Color3.fromRGB(80, 160, 255) end
    return accent()
end
local function findRole(role)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and alive(p.Character) and roleOf(p) == role then return p end
    end
    return nil
end
local function randomPlayer()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and alive(p.Character) then list[#list + 1] = p end
    end
    if #list == 0 then return nil end
    return list[math.random(#list)]
end

local function touch(a, b)
    if not canTouch or not a or not b then return end
    pcall(firetouchinterest, a, b, 0)
    pcall(firetouchinterest, a, b, 1)
end

local function visibleFrom(part, from)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ignore = {}
    if LP.Character then ignore[#ignore + 1] = LP.Character end
    if part.Parent then ignore[#ignore + 1] = part.Parent end
    params.FilterDescendantsInstances = ignore
    return workspace:Raycast(from, part.Position - from, params) == nil
end

--// teleport
local function tpTo(pos)
    local root = ownHRP()
    if root then root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
end
local function tpBehind(part)
    local root = ownHRP()
    if root and part then root.CFrame = part.CFrame * CFrame.new(0, 0, 3) end
end
local function tpToRole(role)
    local p = findRole(role)
    if not p then return toast(role .. " не найден") end
    tpBehind(getHRP(p.Character))
end

--// world scan
local function scanWorld()
    world.coins = {}
    local cont = workspace:FindFirstChild("CoinContainer", true)
    if cont then
        for _, c in ipairs(cont:GetChildren()) do
            local part = c:IsA("BasePart") and c or c:FindFirstChildWhichIsA("BasePart", true)
            if part then world.coins[#world.coins + 1] = part end
        end
    end
    local g = workspace:FindFirstChild("GunDrop", true)
    if g then
        world.gun = g:IsA("BasePart") and g or g:FindFirstChildWhichIsA("BasePart", true)
    else
        world.gun = nil
    end
end
local function nearestCoin(pos)
    local best, bd = nil, math.huge
    for _, part in ipairs(world.coins) do
        if part.Parent then
            local d = (part.Position - pos).Magnitude
            if d < bd then best, bd = part, d end
        end
    end
    return best
end

--// combat
local function equipKnife()
    local c, h = LP.Character, getHum(LP.Character)
    if not c or not h or c:FindFirstChild("Knife") then return end
    local bp = LP:FindFirstChildOfClass("Backpack")
    local k = bp and bp:FindFirstChild("Knife")
    if k and k:IsA("Tool") then pcall(function() h:EquipTool(k) end) end
end

local function doKill(range, root)
    local c = LP.Character
    local knife = c and c:FindFirstChild("Knife")
    local handle = knife and knife:FindFirstChild("Handle")
    if not handle or not root then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and alive(p.Character) then
            local th = getHRP(p.Character)
            if th and (th.Position - root.Position).Magnitude <= range then touch(handle, th) end
        end
    end
end

local function aimTarget(cam)
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, bestD = nil, CFG.AimFov
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and alive(p.Character) then
            local part = p.Character:FindFirstChild(CFG.AimPart) or getHRP(p.Character)
            if part then
                local sp, on = cam:WorldToViewportPoint(part.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestD and visibleFrom(part, cam.CFrame.Position) then
                        best, bestD = part, d
                    end
                end
            end
        end
    end
    return best
end

--// camera step: bound after default camera so the lock sticks
local function camStep()
    if not CFG.Aimbot then return end
    if CFG.AimHold and not rmbHeld then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local part = aimTarget(cam)
    if part then
        local goal = CFrame.lookAt(cam.CFrame.Position, part.Position)
        cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(CFG.AimSmooth / 100, 0.02, 1))
    end
end

--// anti-aim: jitters your head motor (local; replication not guaranteed)
local function getNeck(c)
    local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
    local n = torso and torso:FindFirstChild("Neck")
    if n and n:IsA("Motor6D") then return n end
    return nil
end
local function applyAntiAim(c, now)
    local n = getNeck(c)
    if not n then return end
    if not neckBase[n] then neckBase[n] = n.C0 end
    if CFG.AntiAim then
        local angle = math.rad(((now * 720) % 360) - 180)
        n.C0 = neckBase[n] * CFrame.Angles(0, angle, 0)
    else
        n.C0 = neckBase[n]
    end
end

--// ESP
local function destroyEntry(e)
    if not e then return end
    pcall(function() e.hl:Destroy() end)
    if e.bb then pcall(function() e.bb:Destroy() end) end
end

local function getEntry(key, adornee, labelParent)
    local e = espStore[key]
    if e and e.adornee == adornee and e.hl.Parent then return e end
    if e then destroyEntry(e) end
    local hl = new("Highlight", {
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Adornee = adornee, Parent = gui,
    })
    local bb, lbl
    if labelParent then
        bb = new("BillboardGui", {
            AlwaysOnTop = true, Size = UDim2.fromOffset(220, 20),
            StudsOffset = Vector3.new(0, 2.4, 0), Adornee = labelParent, Parent = labelParent,
        })
        lbl = new("TextLabel", {
            BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold,
            TextSize = 12, TextStrokeTransparency = 0.4, TextColor3 = C.text, Text = "",
        }, bb)
    end
    e = { hl = hl, bb = bb, lbl = lbl, adornee = adornee }
    espStore[key] = e
    return e
end

local function updateESP(myRoot)
    local active = {}
    if CFG.ESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local c = p.Character
                local head = c and c:FindFirstChild("Head")
                local root = getHRP(c)
                if head and root and alive(c) then
                    local role = roleOf(p)
                    local col = (CFG.EspRole and role ~= "Innocent") and roleColor(role) or accent()
                    local e = getEntry(p, c, head)
                    local parts = {}
                    if CFG.EspName then parts[#parts + 1] = p.Name end
                    if CFG.EspRole then parts[#parts + 1] = "[" .. role .. "]" end
                    if CFG.EspDist and myRoot then
                        parts[#parts + 1] = math.floor((root.Position - myRoot.Position).Magnitude) .. "m"
                    end
                    e.lbl.Text = table.concat(parts, "  ")
                    e.lbl.TextColor3 = col
                    e.bb.Enabled = #parts > 0
                    e.hl.Enabled = true
                    e.hl.FillColor = col
                    e.hl.OutlineColor = col
                    e.hl.OutlineTransparency = 0
                    e.hl.FillTransparency = CFG.Chams and 0.5 or 1
                    active[p] = true
                end
            end
        end

        if CFG.EspGun and world.gun and world.gun.Parent then
            local gold = Color3.fromRGB(255, 200, 60)
            local e = getEntry("gun", world.gun, world.gun)
            local d = myRoot and math.floor((world.gun.Position - myRoot.Position).Magnitude) or 0
            e.lbl.Text = "GUN  " .. d .. "m"
            e.lbl.TextColor3 = gold
            e.bb.Enabled = true
            e.hl.Enabled = true
            e.hl.FillColor = gold
            e.hl.OutlineColor = gold
            e.hl.FillTransparency = 0.5
            active["gun"] = true
        end
    end
    for key, e in pairs(espStore) do
        if not active[key] then
            destroyEntry(e)
            espStore[key] = nil
        end
    end
end

--// misc
local function serverHop()
    local req = request or http_request or (syn and syn.request) or (http and http.request)
    if not req then return toast("нет request() в экзекуторе") end
    local ok, res = pcall(req, {
        Url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId),
        Method = "GET",
    })
    if not ok or not res or not res.Body then return toast("список серверов не получен") end
    local ok2, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
    if not ok2 or type(data) ~= "table" or type(data.data) ~= "table" then return toast("битый ответ") end
    local list = {}
    for _, s in ipairs(data.data) do
        if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
            list[#list + 1] = s.id
        end
    end
    if #list == 0 then return toast("свободных серверов нет") end
    pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, list[math.random(#list)], LP)
end

local function rejoin()
    pcall(function() TeleportService:Teleport(game.PlaceId, LP) end)
end

local function fpsBoost()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
    pcall(function() Lighting.GlobalShadows = false end)
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
            pcall(function() d.Enabled = false end)
            n += 1
        end
    end
    toast("boost: " .. n .. " эффектов выключено")
end

--// heartbeat
track(RunService.Heartbeat:Connect(function(dt)
    local now = os.clock()
    local c = LP.Character
    local hum = getHum(c)
    local root = getHRP(c)

    -- fullbright
    if CFG.Fullbright then
        fbOn = true
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    elseif fbOn then
        fbOn = false
        Lighting.Brightness = origLight.Brightness
        Lighting.ClockTime = origLight.ClockTime
        Lighting.Ambient = origLight.Ambient
        Lighting.OutdoorAmbient = origLight.OutdoorAmbient
    end

    if c then applyAntiAim(c, now) end

    if hum and root and hum.Health > 0 then
        -- speed
        if CFG.Speed then
            hum.WalkSpeed = CFG.WalkSpeed
            speedOn = true
        elseif speedOn then
            hum.WalkSpeed = 16
            speedOn = false
        end

        -- fly (CFrame stepping, works on touch via MoveDirection)
        if CFG.Fly then
            hum.PlatformStand = true
            flyOn = true
            local move = hum.MoveDirection
            local up = 0
            if UIS:IsKeyDown(Enum.KeyCode.Space) then up = 1
            elseif UIS:IsKeyDown(Enum.KeyCode.LeftControl) then up = -1 end
            local dir = Vector3.new(move.X, up, move.Z)
            if dir.Magnitude > 1 then dir = dir.Unit end
            root.AssemblyLinearVelocity = Vector3.zero
            root.CFrame = root.CFrame + dir * CFG.FlySpeed * dt
        elseif flyOn then
            hum.PlatformStand = false
            flyOn = false
        end

        -- noclip (also forced while underground-style farming is not used; kept simple)
        if CFG.Noclip then
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end

        -- anti-fling
        if CFG.AntiFling and root.AssemblyLinearVelocity.Magnitude > 220 then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end

        -- kill aura (needs knife equipped)
        if CFG.KillAura and now - timers.aura > 0.06 then
            timers.aura = now
            doKill(CFG.AuraRange, root)
        end

        -- auto grab gun
        if CFG.AutoGrab and now - timers.grab > 0.6 then
            timers.grab = now
            local gun = world.gun
            if gun and gun.Parent and not c:FindFirstChild("Gun") and not hasTool(LP, "Gun") then
                root.CFrame = gun.CFrame + Vector3.new(0, 3, 0)
                touch(root, gun)
            end
        end

        -- auto farm coins
        if CFG.AutoFarm and now - timers.farm > 0.15 then
            timers.farm = now
            local coin = nearestCoin(root.Position)
            if coin then
                root.CFrame = CFrame.new(coin.Position + Vector3.new(0, 2, 0))
                root.AssemblyLinearVelocity = Vector3.zero
                touch(root, coin)
            end
        end
    end

    if now - timers.scan > 1 then
        timers.scan = now
        scanWorld()
    end
    if now - timers.esp > 0.12 then
        timers.esp = now
        updateESP(root)
    end
end))

--// render-step camera
pcall(function()
    RunService:BindToRenderStep("GalaXoRCam", Enum.RenderPriority.Camera.Value + 1, camStep)
end)

--// anti-afk
track(LP.Idled:Connect(function()
    if CFG.AntiAFK then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end))

--// infinite jump
track(UIS.JumpRequest:Connect(function()
    if CFG.InfJump and LP.Character then
        local h = getHum(LP.Character)
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

--// menu open / close animation
local function setMenu(open)
    if open == menuOpen then return end
    menuOpen = open
    local target = CFG.MenuSize / 100
    if open then
        main.Visible = true
        mainScale.Scale = target * 0.85
        main.BackgroundTransparency = 1
        TweenService:Create(mainScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
        TweenService:Create(main, TweenInfo.new(0.2), { BackgroundTransparency = CFG.MenuOpacity / 100 }):Play()
    else
        TweenService:Create(mainScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = target * 0.85 }):Play()
        local fade = TweenService:Create(main, TweenInfo.new(0.16), { BackgroundTransparency = 1 })
        fade:Play()
        fade.Completed:Connect(function()
            if not menuOpen then main.Visible = false end
        end)
    end
end

track(UIS.InputBegan:Connect(function(i, gp)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then rmbHeld = true end
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightShift or i.KeyCode == Enum.KeyCode.Insert then
        setMenu(not menuOpen)
    end
end))
track(UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then rmbHeld = false end
end))

makeDraggable(icon, icon, function() setMenu(not menuOpen) end)
makeDraggable(top, main, nil)
track(closeBtn.MouseButton1Click:Connect(function() setMenu(false) end))

--// unload
local function unload()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    conns = {}
    pcall(function() RunService:UnbindFromRenderStep("GalaXoRCam") end)
    for key, e in pairs(espStore) do destroyEntry(e) espStore[key] = nil end
    for n, o in pairs(neckBase) do
        if n.Parent then pcall(function() n.C0 = o end) end
    end
    Lighting.Brightness = origLight.Brightness
    Lighting.ClockTime = origLight.ClockTime
    Lighting.Ambient = origLight.Ambient
    Lighting.OutdoorAmbient = origLight.OutdoorAmbient
    local h = getHum(LP.Character)
    if h then pcall(function() h.WalkSpeed = 16 h.PlatformStand = false end) end
    pcall(function() gui:Destroy() end)
    genv.GalaXoR_Unload = nil
end
genv.GalaXoR_Unload = unload

--// pages
local function buildPages()
    local combat = makePage("Combat")
    sectionTitle(combat, "Aim")
    toggle(combat, "Aimbot", "Aimbot")
    toggle(combat, "Hold RMB to aim (off on phone)", "AimHold")
    cycle(combat, "Aim bone", "AimPart", { "Head", "Torso", "HumanoidRootPart" })
    slider(combat, "FOV", "AimFov", 20, 500, 5)
    slider(combat, "Smoothing", "AimSmooth", 5, 100, 5)
    sectionTitle(combat, "Melee")
    toggle(combat, "Kill Aura", "KillAura")
    slider(combat, "Aura range", "AuraRange", 5, 60, 1)
    sectionTitle(combat, "Pickup")
    toggle(combat, "Auto Grab Gun", "AutoGrab")

    local visuals = makePage("Visuals")
    sectionTitle(visuals, "ESP")
    toggle(visuals, "ESP", "ESP")
    toggle(visuals, "Name", "EspName")
    toggle(visuals, "Role", "EspRole")
    toggle(visuals, "Distance", "EspDist")
    toggle(visuals, "Gun drop", "EspGun")
    toggle(visuals, "Chams (fill)", "Chams")
    sectionTitle(visuals, "World")
    toggle(visuals, "Fullbright", "Fullbright")

    local move = makePage("Move")
    sectionTitle(move, "Speed & fly")
    toggle(move, "Speed", "Speed")
    slider(move, "Walk speed", "WalkSpeed", 16, 200, 1)
    toggle(move, "Fly (Space / Ctrl)", "Fly")
    slider(move, "Fly speed", "FlySpeed", 20, 250, 5)
    sectionTitle(move, "Physics")
    toggle(move, "Noclip", "Noclip")
    toggle(move, "Infinite Jump", "InfJump")
    toggle(move, "Anti-Fling", "AntiFling")
    toggle(move, "Anti-Aim (head jitter)", "AntiAim")

    local tp = makePage("Teleport")
    sectionTitle(tp, "Roles")
    button(tp, "To Murderer", function() tpToRole("Murderer") end)
    button(tp, "To Sheriff", function() tpToRole("Sheriff") end)
    button(tp, "To random player", function()
        local p = randomPlayer()
        if not p then return toast("нет живых игроков") end
        tpBehind(getHRP(p.Character))
    end)
    sectionTitle(tp, "Target")
    local targetBtn
    targetBtn = button(tp, "Target: none", function()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then list[#list + 1] = p end
        end
        if #list == 0 then
            tpTarget = nil
        else
            local idx = 0
            for i, p in ipairs(list) do
                if p == tpTarget then idx = i end
            end
            tpTarget = list[idx % #list + 1]
        end
        targetBtn.Text = "Target: " .. (tpTarget and tpTarget.Name or "none")
    end)
    button(tp, "To target", function()
        if not tpTarget then return toast("сначала выбери цель") end
        local th = getHRP(tpTarget.Character)
        if not th then return toast("цель без персонажа") end
        tpBehind(th)
    end)
    sectionTitle(tp, "Coins")
    button(tp, "To nearest coin", function()
        local root = ownHRP()
        local coin = root and nearestCoin(root.Position)
        if not coin then return toast("монет не найдено") end
        tpTo(coin.Position)
    end)
    toggle(tp, "Auto Farm Coins", "AutoFarm")

    local misc = makePage("Misc")
    sectionTitle(misc, "Utility")
    toggle(misc, "Anti-AFK", "AntiAFK")
    button(misc, "FPS Booster", fpsBoost)
    button(misc, "Server Hop", serverHop)
    button(misc, "Rejoin", rejoin)

    local cfg = makePage("Config")
    sectionTitle(cfg, "Menu color")
    slider(cfg, "Hue", "MenuHue", 0, 360, 1, { hue = true, cb = refreshAll })
    slider(cfg, "Saturation", "MenuSat", 0, 100, 1, { cb = refreshAll })
    sectionTitle(cfg, "Menu look")
    slider(cfg, "Size %", "MenuSize", 60, 130, 5, {
        cb = function(v) if menuOpen then mainScale.Scale = v / 100 end end,
    })
    slider(cfg, "Opacity %", "MenuOpacity", 0, 70, 1, {
        cb = function(v) if menuOpen then main.BackgroundTransparency = v / 100 end end,
    })
    sectionTitle(cfg, "Session")
    button(cfg, "Unload GalaXoR Hub", unload)
end

buildPages()
selectTab("Combat")
refreshAll()
mainScale.Scale = CFG.MenuSize / 100

--// intro animation
local intro = new("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0, ZIndex = 100,
}, gui)
local introTitle = new("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45),
    Size = UDim2.fromOffset(420, 46), BackgroundTransparency = 1,
    Text = "GalaXoR Hub", Font = Enum.Font.GothamBlack, TextSize = 32,
    TextColor3 = accent(), TextTransparency = 1, ZIndex = 101,
}, intro)
local introBar = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
    Size = UDim2.fromOffset(0, 3), BackgroundColor3 = accent(), BorderSizePixel = 0, ZIndex = 101,
}, intro)
task.spawn(function()
    TweenService:Create(introTitle, TweenInfo.new(0.5), { TextTransparency = 0 }):Play()
    TweenService:Create(introBar, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(240, 3) }):Play()
    task.wait(1.5)
    TweenService:Create(introTitle, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
    TweenService:Create(introBar, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
    local fade = TweenService:Create(intro, TweenInfo.new(0.45), { BackgroundTransparency = 1 })
    fade:Play()
    fade.Completed:Wait()
    pcall(function() intro:Destroy() end)
    toast("GalaXoR Hub · RightShift или G")
end)
