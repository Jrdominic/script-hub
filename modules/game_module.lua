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
