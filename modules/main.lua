--[[
    Syro Hub | main module — every game's script lives in this one file.
    hub.lua fetches this after the key gate; it dispatches on game.PlaceId.
    To add a game: add its PlaceId -> function entry in SCRIPTS below.
]]

local SCRIPTS = {}

--==================================================================
-- ARSENAL (PlaceId 286090429)
--==================================================================
SCRIPTS[286090429] = function()
--[[
    Syro Hub | Arsenal
    Aimbot (hold RMB) / ESP (outline box + health bar + tracers) / Infinite Ammo / Rapid Fire
    UI: Rayfield
    Run via executor (Synapse/ScriptWare/Fluxus/etc.)
]]

--==================================================================
-- CONFIG
--==================================================================
local Config = {
    Aimbot        = true,
    AimFOV        = 150,
    AimSmooth     = 4,
    HitPart       = "Head",
    DrawFOVCirc   = true,

    ESP           = true,
    Tracers       = true,

    InfAmmo       = false,
    RapidFire     = false,
    FireCap       = 12,   -- shots per second cap
}

--==================================================================
-- RAYFIELD
--==================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Syro Hub",
    LoadingTitle = "Syro Hub",
    LoadingSubtitle = "arsenal edition",
    ConfigurationSettings = { SaveSettings = true, ConfigFolder = "SyroHub" },
    ConfigurationSaving = { Enabled = true, FolderName = "SyroHub", FileName = "arsenal" },
    KeySystem = false,
})

local CombatTab = Window:CreateTab("Combat")
local EspTab    = Window:CreateTab("ESP")
local MiscTab   = Window:CreateTab("Misc")

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Camera      = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

Rayfield:Notify({ Title = "Syro Hub", Content = "loaded — hold RMB to aim", Duration = 5 })

--==================================================================
-- DRAWING — ESP / FOV CIRCLE
--==================================================================
if Drawing then
    local function newDraw(class, props)
        local d = Drawing.new(class)
        for k, v in pairs(props) do d[k] = v end
        return d
    end

    local fovCircle = newDraw("Circle", {
        Visible = false, Thickness = 1, Filled = false,
        Radius = Config.AimFOV, Color = Color3.new(1, 1, 1), Transparency = 0.6,
    })

    local espStore = {}

    local function getEsp(plr)
        if espStore[plr] then return espStore[plr] end
        local e = {
            box     = newDraw("Square", { Thickness = 1, Filled = false, Visible = false }),
            boxBg   = newDraw("Square", { Thickness = 1, Filled = true,  Visible = false, Transparency = 0.4 }),
            hpBarBg = newDraw("Square", { Thickness = 1, Filled = true,  Visible = false,
                         Color = Color3.fromRGB(0, 0, 0), Transparency = 0.3 }),
            hpBar   = newDraw("Square", { Thickness = 1, Filled = true,  Visible = false }),
            tracer  = newDraw("Line",   { Thickness = 1, Visible = false }),
        }
        espStore[plr] = e
        plr.AncestryChanged:Connect(function(_, parent)
            if not parent then
                for _, d in pairs(e) do pcall(function() d:Remove() end) end
                espStore[plr] = nil
            end
        end)
        return e
    end

    -- Roblox WorldToViewportPoint, origin top-left
    local function w2s(pos)
        local sp, on = Camera:WorldToViewportPoint(pos)
        return Vector2.new(sp.X, sp.Y), on
    end

    RunService.RenderStepped:Connect(function()
        fovCircle.Radius = Config.AimFOV
        fovCircle.Position = UserInputService:GetMouseLocation()
        fovCircle.Visible = Config.Aimbot and Config.DrawFOVCirc

        local myTeam = LocalPlayer.Team
        for plr, e in pairs(espStore) do
            local char = plr.Character
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")
            local show = false

            if Config.ESP and char and hum and hrp and hum.Health > 0
            and (Camera.CFrame.Position - hrp.Position).Magnitude <= 2000 then
                local pos, on = w2s(hrp.Position)
                if on then
                    show = true
                    local topPos = w2s(hrp.Position + Vector3.new(0, 3, 0))
                    local botPos = w2s(hrp.Position - Vector3.new(0, 3, 0))
                    local h = math.abs(topPos.Y - botPos.Y)
                    local w = h / 2
                    local col = (plr.Team == myTeam)
                        and Color3.fromRGB(80, 200, 255)
                        or Color3.fromRGB(255, 255, 255)

                    e.box.Visible = true
                    e.box.Size = Vector2.new(w, h)
                    e.box.Position = Vector2.new(pos.X - w/2, topPos.Y)
                    e.box.Color = col

                    e.boxBg.Visible = true
                    e.boxBg.Size = e.box.Size
                    e.boxBg.Position = e.box.Position
                    e.boxBg.Color = col

                    local hpFrac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    local barW, barGap = 3, 4
                    e.hpBarBg.Visible = true
                    e.hpBarBg.Size = Vector2.new(barW, h)
                    e.hpBarBg.Position = Vector2.new(pos.X - w/2 - barGap - barW, topPos.Y)

                    e.hpBar.Visible = true
                    e.hpBar.Size = Vector2.new(barW, h * hpFrac)
                    e.hpBar.Position = Vector2.new(e.hpBarBg.Position.X, topPos.Y + h * (1 - hpFrac))
                    e.hpBar.Color = Color3.fromRGB(255 * (1 - hpFrac), 255 * hpFrac, 0)

                    e.tracer.Visible = Config.Tracers
                    e.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    e.tracer.To = Vector2.new(pos.X, botPos.Y)
                    e.tracer.Color = col
                end
            end

            if not show then
                e.box.Visible = false
                e.boxBg.Visible = false
                e.hpBar.Visible = false
                e.hpBarBg.Visible = false
                e.tracer.Visible = false
            end
        end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then getEsp(plr) end
        end
    end)

    Players.PlayerAdded:Connect(getEsp)
end

--==================================================================
-- AIMBOT — hold RMB
--==================================================================
local function getTargets()
    local out = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Team ~= LocalPlayer.Team then
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local part = char:FindFirstChild(Config.HitPart) or char:FindFirstChild("Head")
                if part then
                    out[#out + 1] = { part = part }
                end
            end
        end
    end
    return out
end

RunService.RenderStepped:Connect(function()
    if not Config.Aimbot
    or not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        return
    end

    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, Config.AimFOV
    for _, e in ipairs(getTargets()) do
        local sp, on = Camera:WorldToViewportPoint(e.part.Position)
        if on then
            local d = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
            if d < bestDist then best, bestDist = e, d end
        end
    end

    if best then
        local goal = CFrame.lookAt(Camera.CFrame.Position, best.part.Position)
        Camera.CFrame = Camera.CFrame:Lerp(goal, 1 / math.max(Config.AimSmooth, 1))
    end
end)

--==================================================================
-- HEAP SWEEP ENGINE (shared by inf ammo + rapid fire)
--==================================================================
local Sweep = {
    AMMO_KEY = { ammo = true, clip = true, mag = true, magazine = true,
                 currentammo = true, ammocount = true, magazineammo = true,
                 bullets = true, ammoinclip = true },
    -- gates that block the next shot: cooldowns, delays, charge/wind-up timers
    GATE_KEY = { cooldown = true, cooldowntime = true, delay = true,
                 firedelay = true, shotdelay = true, shottimer = true,
                 nextfire = true, nextshot = true, timebetweenshots = true,
                 charge = true, chargetime = true, chargeup = true,
                 windup = true, drawtime = true, warmup = true, firereadytime = true },
    DENY_KEY = { health = true, maxhealth = true, walkspeed = true, jumppower = true,
                 firerate = true, damage = true, range = true, spread = true,
                 recoil = true, bloom = true, maxammo = true },
    RELOAD_NAMES = { reload = true, reloaded = true, reloadweapon = true, requestreload = true },

    instances  = {},  -- candidate ammo IntValue/NumberValue
    gcFields   = {},  -- [table] = { [key] = "ammo" | "gate" }
    lockState  = {},  -- [container] = { [key] = { locked, max } }
    refs       = {},  -- ammo refs
    gateRefs   = {},  -- rapid fire gate refs
    lastSweep  = 0,
    sweepCount = 0,
}

local function lockFor(container, key)
    local c = Sweep.lockState[container]
    if not c then c = {}; Sweep.lockState[container] = c end
    local s = c[key]
    if not s then s = { locked = false, max = 0 }; c[key] = s end
    return s
end

local function ammoRoots()
    local char = LocalPlayer.Character
    local roots = {}
    if char then
        roots[#roots + 1] = char
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then roots[#roots + 1] = tool end
    end
    local vm = Camera:FindFirstChild(LocalPlayer.Name)
    if vm then roots[#roots + 1] = vm end
    return roots
end

local function gcSweep()
    local ok, objs = pcall(function() return getgc(true) end)
    if not ok or type(objs) ~= "table" then return end
    Sweep.sweepCount = Sweep.sweepCount + 1

    for _, obj in ipairs(objs) do
        if type(obj) == "table" then
            local kinds = Sweep.gcFields[obj]
            local n = 0
            for k, v in pairs(obj) do
                n = n + 1
                if n > 128 then break end
                if type(v) == "number" then
                    local kl = string.lower(tostring(k))
                    local kind = nil
                    if Sweep.AMMO_KEY[kl] and not Sweep.DENY_KEY[kl] then
                        kind = "ammo"
                    elseif Sweep.GATE_KEY[kl] and not Sweep.DENY_KEY[kl] then
                        kind = "gate"
                    end
                    if kind then
                        if not kinds then kinds = {}; Sweep.gcFields[obj] = kinds end
                        kinds[k] = kind
                    end
                end
            end
        elseif typeof(obj) == "Instance" and (obj:IsA("IntValue") or obj:IsA("NumberValue")) then
            local root = obj:FindFirstAncestorOfClass("Model")
                or obj:FindFirstAncestorOfClass("Camera")
            if root and (root == LocalPlayer.Character or root == Camera) then
                Sweep.instances[obj] = true
            end
        end
    end
end

local function buildRefs()
    table.clear(Sweep.refs)
    table.clear(Sweep.gateRefs)

    for inst in pairs(Sweep.instances) do
        if inst.Parent then
            Sweep.refs[#Sweep.refs + 1] = {
                get = function() return inst.Value end,
                set = function(x) inst.Value = x end,
                label = inst:GetFullName(),
                prev = nil, before = nil,
                container = inst, key = "", state = lockFor(inst, ""),
            }
        else
            Sweep.instances[inst] = nil
            Sweep.lockState[inst] = nil
        end
    end

    for t, keys in pairs(Sweep.gcFields) do
        for k, kind in pairs(keys) do
            if kind == "ammo" then
                Sweep.refs[#Sweep.refs + 1] = {
                    get = function() return t[k] end,
                    set = function(x) t[k] = x end,
                    label = "gc:" .. tostring(k),
                    prev = nil, before = nil,
                    container = t, key = k, state = lockFor(t, k),
                }
            else
                Sweep.gateRefs[#Sweep.gateRefs + 1] = {
                    get = function() return t[k] end,
                    set = function(x) t[k] = x end,
                    container = t, key = k,
                }
            end
        end
    end
end

local function sweep()
    gcSweep()
    buildRefs()
    Sweep.lastSweep = os.clock()
end

--==================================================================
-- INFINITE AMMO — behavioral lock + clamp + remote hooks
--==================================================================
local InfAmmo = { notified = false, lastShot = 0 }

local function notifyLock(label)
    if InfAmmo.notified then return end
    InfAmmo.notified = true
    Rayfield:Notify({ Title = "Syro Hub", Content = "ammo locked: " .. label, Duration = 4 })
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp or not Config.InfAmmo then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        for _, r in ipairs(Sweep.refs) do
            r.before = r.get()
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not Config.InfAmmo then return end
    if os.clock() - Sweep.lastSweep > 3 then sweep() end

    for _, r in ipairs(Sweep.refs) do
        local v = r.get()
        if type(v) == "number" then
            local dropped = (r.prev ~= nil and v < r.prev)
                or (r.before ~= nil and v < r.before)
            if dropped then
                r.state.locked = true
                r.state.max = math.max(r.state.max, v + 1, r.prev or 0, r.before or 0)
                InfAmmo.lastShot = os.clock()
                notifyLock(r.label)
            end
            r.before = nil
            r.prev = v

            if r.state.locked then
                if v > r.state.max then r.state.max = v end
                if v < r.state.max then r.set(r.state.max) end
            end
        end
    end
end)

local function rewriteNums(t, mags)
    for k, v in pairs(t) do
        if type(v) == "number" then
            for _, m in ipairs(mags) do
                if v == m.cur then t[k] = m.max; break end
            end
        elseif type(v) == "table" then
            rewriteNums(v, mags)
        end
    end
end

if hookmetamethod then
    local old
    old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if Config.InfAmmo and (method == "FireServer" or method == "InvokeServer") then
            if typeof(self) == "Instance"
            and Sweep.RELOAD_NAMES[string.lower(self.Name)] then
                return
            end
            local args = { ... }
            for _, a in ipairs(args) do
                if type(a) == "string"
                and Sweep.RELOAD_NAMES[string.lower(a)] then
                    return
                end
            end

            local mags = {}
            for _, r in ipairs(Sweep.refs) do
                if r.state.locked then
                    local cur = r.get()
                    if r.state.max > cur then
                        mags[#mags + 1] = { cur = cur, max = r.state.max }
                    end
                end
            end
            if #mags > 0 then rewriteNums(args, mags) end
            return old(self, unpack(args))
        end

        return old(self, ...)
    end))
end

--==================================================================
-- RAPID FIRE — gate zeroing while LMB held, originals restored on release
--==================================================================
-- No click synthesis. While LMB is physically held, every gate field
-- (cooldown / delay / charge / windup) in weapon state is set to 0 each
-- heartbeat — the fire gate is always open, so the gun fires as fast as its
-- animation allows. On release, originals are restored. Charge weapons
-- (bow, rocket launcher) get their charge zeroed too -> instant ready.
-- A shots-per-second cap is enforced via the behavioral shot detector
-- (locked ammo dropping = a shot happened).

local Rapid = { holding = false, origs = {} }

local function captureOrigs()
    for _, r in ipairs(Sweep.gateRefs) do
        local c = Rapid.origs[r.container]
        if not c then c = {}; Rapid.origs[r.container] = c end
        if c[r.key] == nil then
            local v = r.get()
            if type(v) == "number" then c[r.key] = v end
        end
    end
end

local function restoreOrigs()
    for _, r in ipairs(Sweep.gateRefs) do
        local c = Rapid.origs[r.container]
        if c and c[r.key] ~= nil then
            r.set(c[r.key])
            c[r.key] = nil
        end
    end
end

local function zeroGates()
    for _, r in ipairs(Sweep.gateRefs) do
        r.set(0)
    end
end

UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not gp then
        Rapid.holding = true
        if Config.RapidFire then captureOrigs() end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Rapid.holding = false
        restoreOrigs() -- never leave gates zeroed: no ghost fire after release
    end
end)

RunService.Heartbeat:Connect(function()
    if not Config.RapidFire or not Rapid.holding then return end
    if os.clock() - Sweep.lastSweep > 3 then sweep() end

    -- shots-per-second cap: skip zeroing until enough time passed since last shot
    local haveShotDetector = false
    for _, r in ipairs(Sweep.refs) do
        if r.state.locked then haveShotDetector = true; break end
    end
    if haveShotDetector then
        local minInterval = 1 / math.max(Config.FireCap, 1)
        if os.clock() - InfAmmo.lastShot < minInterval then return end
    end

    captureOrigs() -- no-op for already-captured fields
    zeroGates()
end)

--==================================================================
-- UI WIRING
--==================================================================
CombatTab:CreateSection("Aimbot")

CombatTab:CreateToggle({
    Name = "Aimbot (hold RMB)",
    CurrentValue = Config.Aimbot,
    Flag = "SyroAimbot",
    Callback = function(v) Config.Aimbot = v end,
})

CombatTab:CreateSlider({
    Name = "Aim FOV",
    Range = { 20, 500 },
    Increment = 1,
    Suffix = "px",
    CurrentValue = Config.AimFOV,
    Flag = "SyroAimFOV",
    Callback = function(v) Config.AimFOV = v end,
})

CombatTab:CreateSlider({
    Name = "Smoothing",
    Range = { 1, 20 },
    Increment = 1,
    Suffix = "x",
    CurrentValue = Config.AimSmooth,
    Flag = "SyroAimSmooth",
    Callback = function(v) Config.AimSmooth = v end,
})

CombatTab:CreateDropdown({
    Name = "Hit Part",
    Options = { "Head", "HumanoidRootPart", "Torso" },
    CurrentOption = { "Head" },
    MultipleOptions = false,
    Flag = "SyroHitPart",
    Callback = function(o)
        Config.HitPart = (typeof(o) == "table") and o[1] or o
    end,
})

CombatTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = Config.DrawFOVCirc,
    Flag = "SyroFOVCircle",
    Callback = function(v) Config.DrawFOVCirc = v end,
})

EspTab:CreateSection("ESP")

EspTab:CreateToggle({
    Name = "ESP (outline box + health bar)",
    CurrentValue = Config.ESP,
    Flag = "SyroESP",
    Callback = function(v) Config.ESP = v end,
})

EspTab:CreateToggle({
    Name = "Tracers",
    CurrentValue = Config.Tracers,
    Flag = "SyroTracers",
    Callback = function(v) Config.Tracers = v end,
})

MiscTab:CreateSection("Misc")

MiscTab:CreateToggle({
    Name = "Infinite Ammo",
    CurrentValue = Config.InfAmmo,
    Flag = "SyroInfAmmo",
    Callback = function(v)
        Config.InfAmmo = v
        if v then
            InfAmmo.notified = false
            task.spawn(function()
                task.wait(0.2)
                sweep()
            end)
        end
    end,
})

MiscTab:CreateToggle({
    Name = "Rapid Fire",
    CurrentValue = Config.RapidFire,
    Flag = "SyroRapidFire",
    Callback = function(v)
        Config.RapidFire = v
        if v then
            if os.clock() - Sweep.lastSweep > 3 then sweep() end
            if Rapid.holding then captureOrigs() end
        else
            restoreOrigs()
        end
    end,
})

MiscTab:CreateSlider({
    Name = "Rapid Fire Speed",
    Range = { 2, 30 },
    Increment = 1,
    Suffix = " shots/s",
    CurrentValue = Config.FireCap,
    Flag = "SyroFireCap",
    Callback = function(v) Config.FireCap = v end,
})

print("[Syro Hub] loaded — hold RMB to aim, F9 for console")
end

--==================================================================
-- TOWER OF HELL (PlaceIds 1962086868, 3582763398, 5253186791)
--==================================================================
local function towerOfHell()
--[[
    Syro Hub | Tower of Hell — self-contained UI (no external lib)
    Run via executor (Synapse/ScriptWare/Fluxus/etc.)
    RightShift toggles the UI.
]]

--==================================================================
-- SERVICES
--==================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Lighting         = game:GetService("Lighting")
local VirtualUser      = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

--==================================================================
-- STATE
--==================================================================
local Config = {
    Fullbright      = false,
    FOV             = 70,

    AutoWin         = false,
    AutoWinInterval = 30,
    AutoWinFlySpeed = 20,   -- studs per second (fixed)
}

local Unloaded    = false
local Connections = {}

local function Connect(sig, fn)
    local c = sig:Connect(fn)
    Connections[#Connections + 1] = c
    return c
end

--==================================================================
-- SELF-CONTAINED UI
--==================================================================
local function getGuiParent()
    local ok, ui = pcall(function() return gethui and gethui() end)
    if ok and ui then return ui end
    ok, ui = pcall(function() return game:GetService("CoreGui") end)
    if ok and ui then return ui end
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("SyroHubGui")
    if old then old:Destroy() end
    return pg
end

local gui = Instance.new("ScreenGui")
gui.Name = "SyroHubGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 9999
pcall(function() gui.Parent = getGuiParent() end)
if not gui.Parent then return end

local Theme = {
    Bg       = Color3.fromRGB(18, 18, 22),
    Sidebar  = Color3.fromRGB(14, 14, 17),
    Element  = Color3.fromRGB(28, 28, 34),
    ElementH = Color3.fromRGB(38, 38, 46),
    Accent   = Color3.fromRGB(90, 130, 255),
    Text     = Color3.fromRGB(235, 235, 240),
    TextDim  = Color3.fromRGB(140, 140, 150),
}

-- main window
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(720, 520)
Main.Position = UDim2.new(0.5, -360, 0.5, -260)
Main.BackgroundColor3 = Theme.Bg
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = gui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -90, 0, 34)
Title.Position = UDim2.fromOffset(14, 0)
Title.BackgroundTransparency = 1
Title.Text = "Syro Hub"
Title.TextColor3 = Theme.Accent
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Main

local HideBtn = Instance.new("TextButton")
HideBtn.Size = UDim2.fromOffset(26, 26)
HideBtn.Position = UDim2.new(1, -32, 0, 4)
HideBtn.BackgroundColor3 = Theme.Element
HideBtn.Text = "_"
HideBtn.TextColor3 = Theme.Text
HideBtn.Font = Enum.Font.GothamBold
HideBtn.TextSize = 14
HideBtn.Parent = Main
Instance.new("UICorner", HideBtn).CornerRadius = UDim.new(0, 6)

HideBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
end)

-- dragging (grab the title bar)
local dragging, dragStart, startPos
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)
Connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
Connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- rightshift toggle (no gameProcessed filter — works even with the mouse over the UI)
Connect(UserInputService.InputBegan, function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        Main.Visible = not Main.Visible
    end
end)

-- sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -34)
Sidebar.Position = UDim2.fromOffset(0, 34)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main
do
    local l = Instance.new("UIListLayout", Sidebar)
    l.Padding = UDim.new(0, 4)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    local pad = Instance.new("UIPadding", Sidebar)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingTop = UDim.new(0, 8)
end

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -130, 1, -34)
Content.Position = UDim2.fromOffset(130, 34)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent = Main

-- notify (bottom-right popup)
local function Notify(text, dur)
    dur = dur or 4
    local n = Instance.new("TextLabel")
    n.Size = UDim2.fromOffset(300, 40)
    n.Position = UDim2.new(1, -320, 1, 50)
    n.BackgroundColor3 = Theme.Element
    n.TextColor3 = Theme.Text
    n.TextSize = 14
    n.Font = Enum.Font.Gotham
    n.TextWrapped = true
    n.Text = text
    n.Parent = gui
    Instance.new("UICorner", n).CornerRadius = UDim.new(0, 6)
    TweenService:Create(n, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, -320, 1, -60) }):Play()
    task.delay(dur, function()
        TweenService:Create(n, TweenInfo.new(0.3), { Position = UDim2.new(1, -320, 1, 50), TextTransparency = 1, BackgroundTransparency = 1 }):Play()
        task.wait(0.35)
        n:Destroy()
    end)
end

--==================================================================
-- TAB / ELEMENT BUILDERS
--==================================================================
local Tabs = {}
local currentTab

local function makeSection(tabContent, name, side, order)
    local sec = Instance.new("Frame")
    sec.Size = UDim2.new(0.5, -8, 1, -10)
    sec.Position = side == "Right" and UDim2.new(0.5, 4, 0, 5) or UDim2.fromOffset(6, 5)
    sec.BackgroundTransparency = 1
    sec.LayoutOrder = order
    sec.Parent = tabContent

    local layout = Instance.new("UIListLayout", sec)
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = Theme.TextDim
    label.TextSize = 13
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = 0
    label.Parent = sec
    return sec
end

local function newRow(sec, height, order)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, height or 26)
    row.BackgroundColor3 = Theme.Element
    row.Text = ""
    row.AutoButtonColor = true
    row.LayoutOrder = order or 1
    row.Parent = sec
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)
    return row
end

local function addToggle(sec, name, order, default, cb)
    local row = newRow(sec, 26, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.Position = UDim2.fromOffset(10, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 14
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = row

    local state = Instance.new("TextLabel")
    state.Size = UDim2.fromOffset(44, 20)
    state.Position = UDim2.new(1, -50, 0.5, -10)
    state.BackgroundColor3 = default and Theme.Accent or Theme.ElementH
    state.Text = default and "ON" or "OFF"
    state.TextColor3 = default and Color3.new(1, 1, 1) or Theme.TextDim
    state.TextSize = 12
    state.Font = Enum.Font.GothamBold
    state.Parent = row
    Instance.new("UICorner", state).CornerRadius = UDim.new(0, 4)

    local value = default
    row.MouseButton1Click:Connect(function()
        value = not value
        state.Text = value and "ON" or "OFF"
        state.BackgroundColor3 = value and Theme.Accent or Theme.ElementH
        state.TextColor3 = value and Color3.new(1, 1, 1) or Theme.TextDim
        cb(value)
    end)
    return row
end

local function addSlider(sec, name, order, min, max, default, suffix, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = Theme.Element
    row.BorderSizePixel = 0
    row.LayoutOrder = order or 1
    row.Parent = sec
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 16)
    lbl.Position = UDim2.fromOffset(10, 3)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Theme.Text
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped = true
    lbl.Parent = row

    local value = default
    local function setText() lbl.Text = string.format("%s: %d %s", name, value, suffix or "") end
    setText()

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -20, 0, 8)
    bar.Position = UDim2.new(0, 10, 0, 24)
    bar.BackgroundColor3 = Theme.ElementH
    bar.BorderSizePixel = 0
    bar.Parent = row
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

    local sliding = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
        end
    end)
    Connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    Connect(UserInputService.InputChanged, function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            value = math.floor(min + rel * (max - min) + 0.5)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            setText()
            cb(value)
        end
    end)
    return row
end

local function addButton(sec, name, order, cb)
    local row = newRow(sec, 26, order)
    row.Text = name
    row.TextColor3 = Theme.Text
    row.TextSize = 14
    row.Font = Enum.Font.GothamMedium
    row.MouseButton1Click:Connect(cb)
    return row
end

local function addLabel(sec, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.TextDim
    lbl.TextSize = 13
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder = order or 1
    lbl.Parent = sec
    return lbl
end

local function createTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.BackgroundColor3 = Theme.Sidebar
    btn.Text = (icon or "") .. "  " .. name
    btn.TextColor3 = Theme.TextDim
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamMedium
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = Sidebar

    local content = Instance.new("Frame")
    content.Size = UDim2.fromScale(1, 1)
    content.BackgroundTransparency = 1
    content.Visible = false
    content.Parent = Content

    local t = { Button = btn, Content = content }
    btn.MouseButton1Click:Connect(function()
        for _, tab in pairs(Tabs) do
            tab.Content.Visible = false
            tab.Button.BackgroundColor3 = Theme.Sidebar
            tab.Button.TextColor3 = Theme.TextDim
        end
        content.Visible = true
        btn.BackgroundColor3 = Theme.Element
        btn.TextColor3 = Theme.Accent
        currentTab = t
    end)
    Tabs[#Tabs + 1] = t
    return t
end

--==================================================================
-- UI BUILD (forward-declared callbacks defined further below)
--==================================================================
local flyToFinish, FullbrightRestore, Unload

local visualsTab  = createTab("Visuals")
local towerTab    = createTab("Tower")
local settingsTab = createTab("Settings")

-- Visuals
local worldSec = makeSection(visualsTab.Content, "World", "Left", 1)
addToggle(worldSec, "Fullbright", 1, false, function(v)
    Config.Fullbright = v
    if not v then FullbrightRestore() end
end)

local camSec = makeSection(visualsTab.Content, "Camera", "Right", 1)
addSlider(camSec, "Field of View", 1, 30, 120, 70, "fov", function(v) Config.FOV = v end)

-- Tower
local autoWinSec = makeSection(towerTab.Content, "Auto Win", "Left", 1)
addToggle(autoWinSec, "Auto Win (fly up)", 1, false, function(v) Config.AutoWin = v end)
addButton(autoWinSec, "Win Now (fly)", 2, function()
    task.spawn(function()
        local ok = flyToFinish(true)
        if not ok then Notify("Win Now failed — no finish part found") end
    end)
end)

-- Settings
local utilSec = makeSection(settingsTab.Content, "Utility", "Left", 1)
addLabel(utilSec, "Hide/show UI: RightShift", 1)
addButton(utilSec, "Unload Syro Hub", 2, function() Unload() end)

-- activate first tab
visualsTab.Content.Visible = true
visualsTab.Button.BackgroundColor3 = Theme.Element
visualsTab.Button.TextColor3 = Theme.Accent

--==================================================================
-- FULLBRIGHT RESTORE
--==================================================================
local OrigLighting = {
    Brightness     = Lighting.Brightness,
    Ambient        = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ClockTime      = Lighting.ClockTime,
    FogEnd         = Lighting.FogEnd,
    GlobalShadows  = Lighting.GlobalShadows,
}

function FullbrightRestore()
    for k, v in pairs(OrigLighting) do Lighting[k] = v end
end

--==================================================================
-- AUTO WIN  (noclip fly straight into the finish door)
--==================================================================
local FINISH_NAMES = { finish = true, victory = true, win = true, endzone = true, goal = true, door = true }

local function findFinish()
    local tower = workspace:FindFirstChild("Tower") or workspace
    local best, bestY = nil, -math.huge
    for _, d in ipairs(tower:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = string.lower(d.Name)
            if FINISH_NAMES[n] or string.find(n, "finish", 1, true) or string.find(n, "door", 1, true) then
                if d.Position.Y > bestY then
                    best, bestY = d, d.Position.Y
                end
            end
        end
    end
    if not best then
        -- fallback: highest white-ish part = ToH's glowing white door
        for _, d in ipairs(tower:GetDescendants()) do
            if d:IsA("BasePart") then
                local c = d.Color
                if c.R > 0.85 and c.G > 0.85 and c.B > 0.85 and d.Position.Y > bestY then
                    best, bestY = d, d.Position.Y
                end
            end
        end
    end
    return best
end

-- every part that could be carrying the win's Touched listener (the door
-- is usually a model: sensor parts inside it, not the frame you see)
local function findFinishParts()
    local tower = workspace:FindFirstChild("Tower") or workspace
    local parts = {}
    for _, d in ipairs(tower:GetDescendants()) do
        if d:IsA("BasePart") then
            local n = string.lower(d.Name)
            if FINISH_NAMES[n] or string.find(n, "finish", 1, true) or string.find(n, "door", 1, true) then
                parts[#parts + 1] = d
            elseif d.Parent and d.Parent:IsA("Model") then
                local pn = string.lower(d.Parent.Name)
                if string.find(pn, "finish", 1, true) or string.find(pn, "door", 1, true) then
                    parts[#parts + 1] = d
                end
            end
        end
    end
    return parts
end

local flying = false

flyToFinish = function(manual)
    if flying or Unloaded then return false end

    flying = true
    local reached  = false
    local noclipped = {}
    local startedAt = os.clock()

    local function noclip(char)
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
                noclipped[p] = true
            end
        end
    end

    local function restoreCollide()
        for p in pairs(noclipped) do
            if p and p.Parent then p.CanCollide = true end
        end
        table.clear(noclipped)
    end

    local finish  = nil
    local hoverPos = nil   -- frozen position while waiting for the tower to reset

    while not Unloaded do
        -- keep flying while the toggle is on; manual flights end when they land or time out
        if not (manual or Config.AutoWin) then break end
        if manual and os.clock() - startedAt > 60 then break end

        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildOfClass("Humanoid")

        if not (char and hrp and hum) then
            -- dead / respawning: hold the flight (auto) or give up (manual)
            if manual then break end
            task.wait(0.5)
        else
            -- refresh the finish if it despawned (tower reset); if there's
            -- still none, HOVER in place instead of breaking and falling
            if not (finish and finish.Parent) then
                finish = findFinish()
                hoverPos = nil
            end

            noclip(char)

            if finish then
                hoverPos = nil
                local pos   = hrp.Position
                local delta = finish.Position - pos
                local dist  = delta.Magnitude

                if dist < math.max(finish.Size.Magnitude * 0.5, 3) then
                    reached = true
                    -- DON'T break and drop — stay noclipped, stand INSIDE
                    -- the door's cframe (exactly like the open-source auto-win
                    -- scripts do) and hammer the touch on every finish part
                    -- with every limb, so the win's Touched listener fires
                    local finishParts = findFinishParts()
                    local pinUntil = os.clock() + 3
                    while not Unloaded and os.clock() < pinUntil do
                        local c2 = LocalPlayer.Character
                        local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                        if not (h2 and finish.Parent) then break end
                        noclip(c2)
                        h2.AssemblyLinearVelocity = Vector3.zero
                        h2.CFrame = finish.CFrame
                        -- hammer: every finish part x every character limb
                        pcall(function()
                            for _, fp in ipairs(finishParts) do
                                if fp.Parent then
                                    for _, limb in ipairs(c2:GetChildren()) do
                                        if limb:IsA("BasePart") then
                                            firetouchinterest(limb, fp, 0)
                                            firetouchinterest(limb, fp, 1)
                                        end
                                    end
                                end
                            end
                        end)
                        RunService.Heartbeat:Wait()
                    end
                    break
                end

                local speed = Config.AutoWinFlySpeed or 20
                local step  = math.min(speed * (RunService.Heartbeat:Wait()), dist)
                -- velocity carries the motion too, so gravity can't pull us
                -- down between cframe updates
                hrp.AssemblyLinearVelocity = delta.Unit * speed
                hrp.CFrame = CFrame.new(pos + delta.Unit * step)
            else
                -- no finish yet: freeze mid-air, don't fall
                local _ = RunService.Heartbeat:Wait()
                if not hoverPos then hoverPos = hrp.Position end
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = CFrame.new(hoverPos)
            end
        end
    end

    restoreCollide()

    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end

    flying = false
    return reached
end

task.spawn(function()
    while not Unloaded do
        if Config.AutoWin then
            flyToFinish()
            task.wait(Config.AutoWinInterval)
        else
            task.wait(1)
        end
    end
end)
--==================================================================
-- GOD MODE  (built in, always on)
--==================================================================
Connect(RunService.Heartbeat, function()
    if Unloaded then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    -- god mode: built in, always on — killbricks and void can't kill you
    if hum.MaxHealth ~= math.huge then hum.MaxHealth = math.huge end
    hum.Health = math.huge
end)

--==================================================================
-- ANTI-AFK
--==================================================================
Connect(LocalPlayer.Idled, function()
    if Unloaded then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

--==================================================================
-- VISUALS
--==================================================================
Connect(RunService.RenderStepped, function()
    if Unloaded then return end
    Camera.FieldOfView = Config.FOV
end)

Connect(RunService.Heartbeat, function()
    if Unloaded or not Config.Fullbright then return end
    Lighting.Brightness = 2
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.ClockTime = 14
    Lighting.FogEnd = 1e6
    Lighting.GlobalShadows = false
end)

--==================================================================
-- UNLOAD
--==================================================================
function Unload()
    Unloaded = true
    Config.AutoWin = false
    Config.Fullbright = false
    FullbrightRestore()
    Camera.FieldOfView = 70
    -- restore god-mode edits
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.MaxHealth == math.huge then
        hum.MaxHealth = 100
        hum.Health = 100
    end
    for i = 1, #Connections do Connections[i]:Disconnect() end
    table.clear(Connections)
    gui:Destroy()
end

--==================================================================
-- LOADER  (no backdrop — card floats over the game, then fades)
--==================================================================
Main.Visible = false

local Loader = Instance.new("Frame")
Loader.Name = "Loader"
Loader.Size = UDim2.fromScale(1, 1)
Loader.BackgroundTransparency = 1   -- no background, card floats over the game
Loader.BorderSizePixel = 0
Loader.ZIndex = 50
Loader.Parent = gui

local LCard = Instance.new("Frame")
LCard.Size = UDim2.fromOffset(360, 180)
LCard.Position = UDim2.new(0.5, -180, 0.5, -90)
LCard.BackgroundColor3 = Theme.Sidebar
LCard.BorderSizePixel = 0
LCard.ZIndex = 51
LCard.Parent = Loader
Instance.new("UICorner", LCard).CornerRadius = UDim.new(0, 10)

local LTitle = Instance.new("TextLabel")
LTitle.Size = UDim2.new(1, 0, 0, 40)
LTitle.Position = UDim2.fromOffset(0, 24)
LTitle.BackgroundTransparency = 1
LTitle.Text = "Syro Hub"
LTitle.TextColor3 = Theme.Accent
LTitle.TextSize = 30
LTitle.Font = Enum.Font.GothamBold
LTitle.ZIndex = 52
LTitle.Parent = LCard

local LSub = Instance.new("TextLabel")
LSub.Size = UDim2.new(1, 0, 0, 18)
LSub.Position = UDim2.fromOffset(0, 62)
LSub.BackgroundTransparency = 1
LSub.Text = "Tower of Hell"
LSub.TextColor3 = Theme.TextDim
LSub.TextSize = 14
LSub.Font = Enum.Font.Gotham
LSub.ZIndex = 52
LSub.Parent = LCard

local LBarBg = Instance.new("Frame")
LBarBg.Size = UDim2.new(1, -60, 0, 8)
LBarBg.Position = UDim2.new(0, 30, 0, 104)
LBarBg.BackgroundColor3 = Theme.ElementH
LBarBg.BorderSizePixel = 0
LBarBg.ZIndex = 52
LBarBg.Parent = LCard
Instance.new("UICorner", LBarBg).CornerRadius = UDim.new(0, 4)

local LBar = Instance.new("Frame")
LBar.Size = UDim2.new(0, 0, 1, 0)
LBar.BackgroundColor3 = Theme.Accent
LBar.BorderSizePixel = 0
LBar.ZIndex = 53
LBar.Parent = LBarBg
Instance.new("UICorner", LBar).CornerRadius = UDim.new(0, 4)

local LStatus = Instance.new("TextLabel")
LStatus.Size = UDim2.new(1, 0, 0, 16)
LStatus.Position = UDim2.new(0, 0, 0, 126)
LStatus.BackgroundTransparency = 1
LStatus.Text = "initializing..."
LStatus.TextColor3 = Theme.TextDim
LStatus.TextSize = 12
LStatus.Font = Enum.Font.Gotham
LStatus.ZIndex = 52
LStatus.Parent = LCard

task.spawn(function()
    local steps = {
        { 0.25, "checking environment" },
        { 0.55, "building ui" },
        { 0.80, "hooking services" },
        { 1.00, "ready" },
    }
    for _, s in ipairs(steps) do
        LStatus.Text = s[2] .. "..."
        TweenService:Create(LBar, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(s[1], 0, 1, 0) }):Play()
        task.wait(0.5)
    end
    task.wait(0.4)
    local fade2 = TweenService:Create(LCard, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
    fade2:Play()
    for _, d in ipairs({ LTitle, LSub, LStatus }) do
        TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
    end
    TweenService:Create(LBarBg, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(LBar, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    task.wait(0.45)
    Loader:Destroy()
    if not Unloaded then
        Main.Visible = true
        Notify("Syro Hub loaded — RightShift toggles the UI", 5)
    end
end)

--==================================================================
-- READY
--==================================================================
print("[Syro Hub] tower of hell loaded (self-contained UI) — RightShift to toggle")
end

SCRIPTS[1962086868] = towerOfHell -- Tower of Hell
SCRIPTS[3582763398] = towerOfHell -- Pro Tower of Hell
SCRIPTS[5253186791] = towerOfHell -- Tower of Hell (new place id)

--==================================================================
-- DISPATCH
--==================================================================
local fn = SCRIPTS[game.PlaceId]
if fn then
    fn()
else
    warn("[Syro Hub] no module for PlaceId " .. tostring(game.PlaceId))
end
