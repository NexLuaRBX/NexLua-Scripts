-- NeXLua Hub | Arsenal Edition
-- Aimbot: press E to toggle. Wallhack: press V to toggle.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")

local AIM = false
local ESP = true
local TARGET = nil

local ESP_NAME = "ArsenalHubESP"
local STEP_NAME = "ArsenalHubAim"

-- CLEAN UP PREVIOUS EXECUTIONS
local env = (type(getgenv) == "function"
    and getgenv()) or _G

if type(env.ArsenalHubStop) == "function" then
    pcall(env.ArsenalHubStop)
end

for _, name in ipairs({
    "ArsenalHeadAimlock",
    "ArsenalInstantHeadlock",
    "ArsenalAutoAimlock",
    STEP_NAME
}) do
    RunService:UnbindFromRenderStep(name)
end

local connections = {}

local function listen(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

-- TEAM CHECK
local function isEnemy(player)
    if player == LP then return false end

    if LP.Team == nil then
        return player.Team == nil
    end

    return player.Team ~= nil
        and player.Team ~= LP.Team
end

-- WALLHACK
local function updateESP(player)
    if player == LP then return end

    local char = player.Character
    if not char then return end

    local h = char:FindFirstChild(ESP_NAME)

    if not h then
        h = Instance.new("Highlight")
        h.Name = ESP_NAME
        h.Adornee = char
        h.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop
        h.FillColor = Color3.fromRGB(255, 45, 65)
        h.OutlineColor = Color3.fromRGB(255, 255, 255)
        h.FillTransparency = 0.45
        h.OutlineTransparency = 0
        h.Parent = char
    end

    h.Enabled = ESP and isEnemy(player)
end

local function refreshESP()
    for _, p in ipairs(Players:GetPlayers()) do
        updateESP(p)
    end
end

local function setupPlayer(player)
    if player == LP then return end

    listen(player.CharacterAdded, function()
        updateESP(player)
    end)

    listen(player:GetPropertyChangedSignal("Team"),
        function()
            updateESP(player)
            if TARGET == player and not isEnemy(player) then
                TARGET = nil
            end
        end
    )

    updateESP(player)
end

for _, p in ipairs(Players:GetPlayers()) do
    setupPlayer(p)
end

listen(Players.PlayerAdded, setupPlayer)
listen(LP:GetPropertyChangedSignal("Team"), function()
    TARGET = nil
    refreshESP()
end)

-- AIMBOT: CABEZA
local function getHead(player)
    local char = player.Character
    if not char then return nil end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local head = char:FindFirstChild("Head")

    if not hum or hum.Health <= 0 then
        return nil
    end

    return head
end

-- WALL CHECK
local function visible(player)
    local cam = workspace.CurrentCamera
    local head = getHead(player)

    if not cam or not head then return false end

    local pos, onScreen =
        cam:WorldToViewportPoint(head.Position)

    if not onScreen or pos.Z <= 0 then
        return false
    end

    local origin = cam.CFrame.Position
    local direction = head.Position - origin

    local ignore = {cam}

    if LP.Character then
        table.insert(ignore, LP.Character)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    params.IgnoreWater = true

    local hit = workspace:Raycast(
        origin,
        direction,
        params
    )

    return hit ~= nil
        and hit.Instance:IsDescendantOf(
            player.Character
        )
end

-- FIND THE ENEMY CLOSEST TO THE CROSSHAIR
local function nextTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end

    local center = Vector2.new(
        cam.ViewportSize.X / 2,
        cam.ViewportSize.Y / 2
    )

    local best = nil
    local distance = math.huge

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and visible(p) then
            local head = getHead(p)

            if head then
                local pos =
                    cam:WorldToViewportPoint(head.Position)

                local d = (
                    Vector2.new(pos.X, pos.Y) - center
                ).Magnitude

                if d < distance then
                    distance = d
                    best = p
                end
            end
        end
    end

    return best
end

-- INSTANT AIMBOT + AUTO TARGET SWITCH
RunService:BindToRenderStep(
    STEP_NAME,
    Enum.RenderPriority.Camera.Value + 1,
    function()
        if not AIM then
            TARGET = nil
            return
        end

        local char = LP.Character
        local hum = char and
            char:FindFirstChildOfClass("Humanoid")

        if not hum or hum.Health <= 0 then
            TARGET = nil
            return
        end

        if not TARGET
            or not isEnemy(TARGET)
            or not getHead(TARGET)
            or not visible(TARGET) then

            TARGET = nextTarget()
        end

        if not TARGET then return end

        local head = getHead(TARGET)
        local cam = workspace.CurrentCamera

        if head and cam then
            cam.CFrame = CFrame.lookAt(
                cam.CFrame.Position,
                head.Position
            )
        end
    end
)


-- NeXLua Hub | Compact green GUI
local CHANNEL_URL = "https://www.youtube.com/@NexLuaRBX"
local Theme = {
    panel = Color3.fromRGB(12, 19, 16),
    row = Color3.fromRGB(22, 35, 28),
    border = Color3.fromRGB(39, 127, 72),
    lime = Color3.fromRGB(51, 239, 103),
    white = Color3.fromRGB(244, 252, 247),
    muted = Color3.fromRGB(157, 185, 166),
    off = Color3.fromRGB(108, 58, 65),
    dark = Color3.fromRGB(8, 14, 11)
}

local oldGui = PlayerGui:FindFirstChild("NeXLua_Arsenal_Hub")
if oldGui then oldGui:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "NeXLua_Arsenal_Hub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999999
gui.Parent = PlayerGui

local function rounded(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end
local function outlined(parent, color)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.border
    s.Thickness = 1
    s.Transparency = 0.08
    s.Parent = parent
    return s
end
local function label(parent, value, size, color, bold)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Text = value
    t.TextColor3 = color or Theme.white
    t.TextSize = size or 12
    t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = parent
    return t
end
local function button(parent, value)
    local b = Instance.new("TextButton")
    b.Text = value
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = Theme.white
    b.AutoButtonColor = true
    b.BorderSizePixel = 0
    b.Parent = parent
    return b
end
local function notify(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NeXLua Hub", Text = message, Duration = 4
        })
    end)
end
local function openChannel()
    for _, key in ipairs({"openurl", "open_url", "openbrowser", "open_browser"}) do
        local fn = env[key]
        if type(fn) == "function" then
            local ok = pcall(fn, CHANNEL_URL)
            if ok then return end
        end
    end
    local clipboard = env.setclipboard or env.toclipboard or setclipboard
    if type(clipboard) == "function" and pcall(clipboard, CHANNEL_URL) then
        notify("YouTube link copied to clipboard")
    else
        notify("YouTube: @NexLuaRBX")
    end
end
local function decodeBase64(data)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, #alphabet do lookup[alphabet:sub(i, i)] = i - 1 end
    local result, carry, bits = {}, 0, 0
    for i = 1, #data do
        local num = lookup[data:sub(i, i)]
        if num then
            carry = carry * 64 + num
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local b = math.floor(carry / (2 ^ bits))
                result[#result + 1] = string.char(b % 256)
                carry = carry % (2 ^ bits)
            end
        end
    end
    return table.concat(result)
end
local AVATAR_B64 = [[
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
]]

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(286, 272)
main.Position = UDim2.new(1, -302, 0.22, 0)
main.BackgroundColor3 = Theme.panel
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
rounded(main, 12)
outlined(main)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 57)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = main

local avatarFrame = Instance.new("Frame")
avatarFrame.Size = UDim2.fromOffset(42, 42)
avatarFrame.Position = UDim2.fromOffset(10, 8)
avatarFrame.BackgroundColor3 = Theme.dark
avatarFrame.BorderSizePixel = 0
avatarFrame.ClipsDescendants = true
avatarFrame.Parent = header
rounded(avatarFrame, 21)
outlined(avatarFrame, Theme.lime)

local fallbackLogo = label(avatarFrame, "N", 24, Theme.lime, true)
fallbackLogo.Size = UDim2.fromScale(1, 1)
fallbackLogo.TextXAlignment = Enum.TextXAlignment.Center
fallbackLogo.TextYAlignment = Enum.TextYAlignment.Center

-- Show the NexLua avatar if the executor supports custom image assets.
local writer = env.writefile or writefile
local customAsset = env.getcustomasset or env.getsynasset or getcustomasset or getsynasset
if type(writer) == "function" and type(customAsset) == "function" then
    pcall(function()
        local path = "NeXLua_Arsenal_Avatar.jpg"
        writer(path, decodeBase64(AVATAR_B64))
        local pic = Instance.new("ImageLabel")
        pic.Name = "NexLuaAvatar"
        pic.Size = UDim2.fromScale(1, 1)
        pic.BackgroundTransparency = 1
        pic.ScaleType = Enum.ScaleType.Crop
        pic.Image = customAsset(path)
        pic.Parent = avatarFrame
    end)
end

local heading = label(header, "NeXLua Hub", 16, Theme.white, true)
heading.Position = UDim2.fromOffset(61, 6)
heading.Size = UDim2.fromOffset(158, 24)

local channel = button(header, "YouTube: @NexLuaRBX  >")
channel.Font = Enum.Font.Gotham
channel.TextXAlignment = Enum.TextXAlignment.Left
channel.TextSize = 10
channel.TextColor3 = Theme.lime
channel.BackgroundTransparency = 1
channel.Position = UDim2.fromOffset(61, 31)
channel.Size = UDim2.fromOffset(159, 18)
listen(channel.Activated, openChannel)

local minimize = button(header, "-")
minimize.Size = UDim2.fromOffset(22, 23)
minimize.Position = UDim2.fromOffset(235, 16)
minimize.TextSize = 17
minimize.BackgroundColor3 = Theme.row
rounded(minimize, 6)

local close = button(header, "x")
close.Size = UDim2.fromOffset(22, 23)
close.Position = UDim2.fromOffset(260, 16)
close.TextSize = 13
close.BackgroundColor3 = Theme.row
rounded(close, 6)

local rule = Instance.new("Frame")
rule.BorderSizePixel = 0
rule.BackgroundColor3 = Theme.border
rule.Size = UDim2.new(1, -20, 0, 1)
rule.Position = UDim2.fromOffset(10, 56)
rule.Parent = main

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -57)
body.Position = UDim2.fromOffset(0, 57)
body.BackgroundTransparency = 1
body.Parent = main

local function featureRow(title, detail, y)
    local row = button(body, "")
    row.Size = UDim2.new(1, -20, 0, 68)
    row.Position = UDim2.fromOffset(10, y)
    row.BackgroundColor3 = Theme.row
    rounded(row, 9)
    local name = label(row, title, 14, Theme.white, true)
    name.Position = UDim2.fromOffset(12, 8)
    name.Size = UDim2.new(1, -83, 0, 21)
    local tip = label(row, detail, 10, Theme.muted, false)
    tip.Position = UDim2.fromOffset(12, 35)
    tip.Size = UDim2.new(1, -75, 0, 19)
    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(45, 24)
    track.Position = UDim2.new(1, -56, 0.5, -12)
    track.BackgroundColor3 = Theme.off
    track.Parent = row
    rounded(track, 12)
    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(19, 19)
    knob.Position = UDim2.fromOffset(3, 2)
    knob.BackgroundColor3 = Theme.white
    knob.Parent = track
    rounded(knob, 10)
    return row, track, knob, tip
end

local aimRow, aimTrack, aimKnob, aimTip = featureRow("Aimbot", "PRESS [E] TO ENABLE", 9)
local wallRow, wallTrack, wallKnob = featureRow("Wallhack", "Enemy outlines  |  Press [V]", 86)

local footer = label(body, "E = AIMBOT    V = WALLHACK", 11, Theme.lime, true)
footer.Position = UDim2.fromOffset(12, 166)
footer.Size = UDim2.new(1, -24, 0, 20)
footer.TextXAlignment = Enum.TextXAlignment.Center

local extra = label(body, "RIGHT SHIFT = SHOW / HIDE MENU", 10, Theme.muted, false)
extra.Position = UDim2.fromOffset(12, 187)
extra.Size = UDim2.new(1, -24, 0, 19)
extra.TextXAlignment = Enum.TextXAlignment.Center

local function setVisual(track, knob, on)
    track.BackgroundColor3 = on and Theme.lime or Theme.off
    knob.Position = on and UDim2.fromOffset(23, 2) or UDim2.fromOffset(3, 2)
end
local function updateButtons()
    setVisual(aimTrack, aimKnob, AIM)
    setVisual(wallTrack, wallKnob, ESP)
    aimTip.Text = AIM and "[E]  AIMBOT ENABLED" or "[E]  AIMBOT DISABLED"
    aimTip.TextColor3 = AIM and Theme.lime or Theme.muted
end
local function toggleAim()
    AIM = not AIM
    TARGET = nil
    updateButtons()
end
local function toggleWallhack()
    ESP = not ESP
    refreshESP()
    updateButtons()
end
listen(aimRow.Activated, toggleAim)
listen(wallRow.Activated, toggleWallhack)

local minimized = false
listen(minimize.Activated, function()
    minimized = not minimized
    body.Visible = not minimized
    main.Size = UDim2.fromOffset(286, minimized and 57 or 272)
    minimize.Text = minimized and "+" or "-"
end)

-- Keyboard shortcuts also work while the menu is hidden.
listen(UIS.InputBegan, function(input, processed)
    if processed or UIS:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.E then
        toggleAim()
    elseif input.KeyCode == Enum.KeyCode.V then
        toggleWallhack()
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        main.Visible = not main.Visible
    end
end)

-- Drag the header using mouse or touch.
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
listen(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragInput = input
        dragStart = input.Position
        startPos = main.Position
    end
end)
listen(UIS.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragInput then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
listen(UIS.InputEnded, function(input)
    if input == dragInput or
        (input.UserInputType == Enum.UserInputType.MouseButton1 and
        dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging = false
        dragInput = nil
    end
end)

local stopped = false
local function stopHub()
    if stopped then return end
    stopped = true
    AIM = false
    ESP = false
    TARGET = nil
    RunService:UnbindFromRenderStep(STEP_NAME)
    for _, c in ipairs(connections) do
        if c.Connected then c:Disconnect() end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local h = p.Character:FindFirstChild(ESP_NAME)
            if h then h:Destroy() end
        end
    end
    gui:Destroy()
    if env.ArsenalHubStop == stopHub then env.ArsenalHubStop = nil end
end
listen(close.Activated, stopHub)
env.ArsenalHubStop = stopHub

updateButtons()
refreshESP()
print("[NeXLua Hub] Arsenal loaded | Press E to toggle Aimbot | Press V to toggle Wallhack")
