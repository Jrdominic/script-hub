-- language: Luau, file: hub.lua
-- Single-entry hub: work.ink key gate -> detects PlaceId, loads the module
-- for supported games, otherwise shows "Game NOT supported".

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local BASE_URL = "https://raw.githubusercontent.com/Jrdominic/script-hub/main/modules/"
local KEY_LINK = "https://work.ink/1Vwu/syrohub" -- your work.ink key-system link
local KEY_FILE = "SyroHub_key.txt"        -- cached key + first-use timestamp
local FREE_KEY = "Slushboi"               -- built-in key: free, no work.ink needed
local KEY_DURATION = 4 * 3600             -- every key lasts 4h from first use

-- Only supported games — all load the single shared module, which
-- dispatches on PlaceId internally
local GAME_MODULES = {
    [286090429] = "main.lua", -- Arsenal
    [1962086868] = "main.lua", -- Tower of Hell
    [3582763398] = "main.lua", -- Pro Tower of Hell
    [5253186791] = "main.lua", -- Tower of Hell (new place)
}

-- Universe IDs catch private/reserved/banned servers, whose PlaceId differs
local GAME_UNIVERSES = {
    [111958650] = "main.lua", -- Arsenal
    [703124385] = "main.lua", -- Tower of Hell (all places + private servers)
}

--==================================================================
-- HTTP HELPER (executor game:HttpGet first, HttpService fallback)
--==================================================================
local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url) end)
    if ok and type(res) == "string" then return res end
    if HttpService and HttpService.HttpEnabled then
        local ok2, res2 = pcall(function() return HttpService:GetAsync(url) end)
        if ok2 and type(res2) == "string" then return res2 end
    end
    return nil
end

local function notify(text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Script Hub",
            Text = text,
            Duration = 4,
        })
    end)
    print("[Script Hub] " .. text)
end

--==================================================================
-- KEY SYSTEM (work.ink)
--==================================================================
local KeySystem = { valid = false }

local function validateToken(token)
    token = token:gsub("%s+", "") -- trim paste artifacts
    if #token < 8 then return false end
    -- public endpoint, no api key involved
    local res = httpGet("https://work.ink/_api/v2/token/isValid/" .. token)
    if not res then return false end
    local dec, data = pcall(function() return HttpService:JSONDecode(res) end)
    if not dec or type(data) ~= "table" then return false end
    return data.valid == true
end

local function now()
    return (os and os.time) and os.time() or 0
end

local function isFreeKey(key)
    return type(key) == "string" and key:lower() == FREE_KEY:lower()
end

local function keyExpired(firstUse)
    local t = now()
    return t > 0 and firstUse ~= nil and (t - firstUse) >= KEY_DURATION
end

local function fmtLeft(sec)
    return string.format("%dh %02dm", math.floor(sec / 3600), math.floor((sec % 3600) / 60))
end

local function remainingText(firstUse)
    local t = now()
    if t <= 0 or firstUse == nil then return "" end
    local left = KEY_DURATION - (t - firstUse)
    if left <= 0 then return "" end
    return " (" .. fmtLeft(left) .. " left)"
end

local function keyAccepted(key)
    if isFreeKey(key) then return true end
    return validateToken(key)
end

local function readCachedKey()
    if writefile and readfile and isfile and isfile(KEY_FILE) then
        local ok, cached = pcall(readfile, KEY_FILE)
        if ok and type(cached) == "string" then
            -- stored as "key|firstUseTimestamp"; bare keys from older versions have no timestamp
            local key, ts = cached:match("^(.-)|(%d+)%s*$")
            if not key then key, ts = cached, nil end
            key = key:gsub("%s+", "")
            if #key >= 8 or isFreeKey(key) then
                local n = tonumber(ts)
                return key, (n and n > 0) and n or nil
            end
        end
    end
    return nil
end

local function writeCachedKey(key, firstUse)
    if writefile then
        pcall(writefile, KEY_FILE, key .. "|" .. tostring(firstUse or now()))
    end
end

local function keyGate()
    -- 1) cached key
    local cached, firstUse = readCachedKey()
    if cached and keyExpired(firstUse) then
        notify("Cached key expired - 4h limit reached")
        if writefile then pcall(writefile, KEY_FILE, "") end
        cached = nil
    end
    if cached and keyAccepted(cached) then
        -- old-format cache entries have no timestamp: start the 4h clock now
        firstUse = firstUse or now()
        writeCachedKey(cached, firstUse)
        KeySystem.valid = true
        notify("Key accepted (cached)" .. remainingText(firstUse))
        return true
    end

    -- 2) UI — Neverlose style, same theme as Syro Hub
    local Theme = {
        Background   = Color3.fromRGB(24, 24, 30),
        Section      = Color3.fromRGB(18, 18, 23),
        Element      = Color3.fromRGB(34, 34, 42),
        ElementHover = Color3.fromRGB(44, 44, 54),
        Outline      = Color3.fromRGB(48, 48, 58),
        Accent       = Color3.fromRGB(90, 130, 255),
        Text         = Color3.fromRGB(230, 230, 240),
        TextDim      = Color3.fromRGB(150, 150, 160),
    }

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "HubKeyGate"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 9999
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    -- main window
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.fromOffset(380, 250)
    Frame.Position = UDim2.new(0.5, -190, 0.5, -125)
    Frame.BackgroundColor3 = Theme.Background
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Frame.Parent = ScreenGui
    Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)
    local outline = Instance.new("UIStroke", Frame)
    outline.Color = Theme.Outline
    outline.Thickness = 1
    outline.Transparency = 0.4

    -- title bar (same style as the hub window header)
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Theme.Section
    titleBar.BorderSizePixel = 0
    titleBar.Parent = Frame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)

    -- cover the bottom corners of the title bar so only the window is rounded
    local barFix = Instance.new("Frame")
    barFix.Size = UDim2.new(1, 0, 0, 10)
    barFix.Position = UDim2.new(0, 0, 1, -10)
    barFix.BackgroundColor3 = Theme.Section
    barFix.BorderSizePixel = 0
    barFix.Parent = titleBar

    -- accent strip on the left, like the hub tabs
    local accentStrip = Instance.new("Frame")
    accentStrip.Size = UDim2.new(0, 3, 1, -12)
    accentStrip.Position = UDim2.new(0, 12, 0, 6)
    accentStrip.BackgroundColor3 = Theme.Accent
    accentStrip.BorderSizePixel = 0
    accentStrip.Parent = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.fromOffset(24, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Theme.Text
    title.TextSize = 17
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Syro Hub  <font color=\"#5A82FF\">|</font>  Key System"
    title.RichText = true
    title.Parent = titleBar

    -- drag by the title bar
    local dragging, dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    -- key input box (hub-style element)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -24, 0, 34)
    box.Position = UDim2.new(0, 12, 0, 56)
    box.BackgroundColor3 = Theme.Element
    box.TextColor3 = Theme.Text
    box.PlaceholderText = "paste your key here"
    box.PlaceholderColor3 = Theme.TextDim
    box.Text = ""
    box.TextSize = 14
    box.Font = Enum.Font.Gotham
    box.ClearTextOnFocus = false
    box.Parent = Frame
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    local boxStroke = Instance.new("UIStroke", box)
    boxStroke.Color = Theme.Outline
    boxStroke.Thickness = 1
    boxStroke.Transparency = 0.5
    box.Focused:Connect(function()
        boxStroke.Color = Theme.Accent
        boxStroke.Transparency = 0
    end)
    box.FocusLost:Connect(function()
        boxStroke.Color = Theme.Outline
        boxStroke.Transparency = 0.5
    end)

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -24, 0, 22)
    status.Position = UDim2.new(0, 12, 0, 98)
    status.BackgroundTransparency = 1
    status.TextColor3 = Theme.TextDim
    status.TextSize = 13
    status.Font = Enum.Font.Gotham
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Text = "waiting for key..."
    status.Parent = Frame

    local function btnProps(b, text, x, w, col)
        b.Size = UDim2.new(0, w, 0, 32)
        b.Position = UDim2.new(0, x, 0, 136)
        b.BackgroundColor3 = col
        b.TextColor3 = Theme.Text
        b.TextSize = 14
        b.Font = Enum.Font.GothamBold
        b.Text = text
        b.AutoButtonColor = false
        b.Parent = Frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)

        -- hub-style hover feedback
        b.MouseEnter:Connect(function()
            b.BackgroundColor3 = Theme.ElementHover
        end)
        b.MouseLeave:Connect(function()
            b.BackgroundColor3 = col
        end)
    end

    local getKey = Instance.new("TextButton")
    btnProps(getKey, "Get Key", 12, 172, Theme.Element)

    local verify = Instance.new("TextButton")
    btnProps(verify, "Verify Key", 196, 172, Theme.Accent)

    -- "Get Key": copy link to clipboard (executor setclipboard, fallback shows the link)
    getKey.MouseButton1Click:Connect(function()
        local ok = pcall(function() setclipboard(KEY_LINK) end)
        if ok then
            status.Text = "key link copied - paste it in your browser"
            status.TextColor3 = Theme.TextDim
        else
            status.Text = KEY_LINK
            status.TextColor3 = Theme.Accent
        end
        notify("Key link copied to clipboard")
    end)

    local verifying = false
    verify.MouseButton1Click:Connect(function()
        if verifying then return end
        local key = (box.Text or ""):gsub("%s+", "")
        if #key < 8 then
            status.Text = "enter a key first"
            status.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        verifying = true
        status.Text = "verifying..."
        status.TextColor3 = Theme.TextDim
        task.spawn(function()
            if keyAccepted(key) then
                -- keep the original first-use time if this is the same cached key
                local c, ts = readCachedKey()
                local firstUse = (c == key and ts) or now()
                if keyExpired(firstUse) then
                    status.Text = "key expired - 4h limit reached"
                    status.TextColor3 = Color3.fromRGB(255, 100, 100)
                else
                    KeySystem.valid = true
                    writeCachedKey(key, firstUse)
                    status.Text = "key valid!" .. remainingText(firstUse)
                    status.TextColor3 = Theme.Accent
                    task.wait(0.5)
                    ScreenGui:Destroy()
                end
            else
                status.Text = "invalid key - get a new one"
                status.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
            verifying = false
        end)
    end)

    -- block until key verified or the window is closed
    while not KeySystem.valid and ScreenGui.Parent do
        task.wait(0.2)
    end
    if KeySystem.valid then
        while ScreenGui.Parent do task.wait(0.1) end
    end
end

--==================================================================
-- MODULE LOADING
--==================================================================
local function loadModule(moduleName)
    local result = httpGet(BASE_URL .. moduleName)

    if result and #result > 0 then
        -- GitHub 404 pages start with this; catch them before loadstring chokes
        if result:find("404: Not Found", 1, true) then
            notify("Module not found - check BASE_URL / repo path")
            return
        end
        local func, err = loadstring(result)
        if func then
            notify("Loaded module: " .. moduleName)
            func()
        else
            notify("Failed to compile module: " .. tostring(err))
        end
    else
        notify("Failed to fetch module: " .. moduleName)
    end
end

--==================================================================
-- MAIN
--==================================================================
keyGate()

if not KeySystem.valid then return end -- window was closed without a valid key

local placeId = game.PlaceId
local moduleName = GAME_MODULES[placeId] or GAME_UNIVERSES[game.GameId]

if moduleName then
    notify("Game supported. Loading module...")
    loadModule(moduleName)
else
    notify("Game NOT supported")
    -- Fallback UI so the user clearly sees the message
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "HubUnsupported"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.fromOffset(280, 120)
    Frame.Position = UDim2.new(0.5, -140, 0.5, -60)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Frame.Draggable = true
    Frame.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = Frame

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -20, 0, 40)
    label.Position = UDim2.new(0, 10, 0, 10)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 80, 80)
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Text = "Game NOT supported"
    label.Parent = Frame

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -20, 0, 30)
    sub.Position = UDim2.new(0, 10, 0, 60)
    sub.BackgroundTransparency = 1
    sub.TextColor3 = Color3.fromRGB(180, 180, 180)
    sub.TextScaled = true
    sub.Font = Enum.Font.Gotham
    sub.Text = "PlaceId: " .. tostring(placeId)
    sub.Parent = Frame

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(1, -20, 0, 30)
    close.Position = UDim2.new(0, 10, 0, 80)
    close.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    close.TextColor3 = Color3.fromRGB(255, 255, 255)
    close.TextScaled = true
    close.Font = Enum.Font.GothamBold
    close.Text = "Close"
    close.Parent = Frame
    close.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end)
end
