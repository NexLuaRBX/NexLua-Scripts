--[[
NeXLua Hub | OneShot — V12 Mobile Fire Test
Original OneShot V9 ESP/Head Aim mechanics retained.
No subscription gate. Optional YouTube recommendation: @NexLuaRBX.
Avatar is embedded with pixel-art fallback for executors without custom assets.
]]

-- ONESHOT V9 CORE | NeXLua compact interface
-- Self-contained script. Original two game features retained.
-- Detects players and additional workspace character models.
-- Head Aim moves the camera only; it cannot guarantee hits through walls.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G
local BIND = "OneShot_V9_Aim"
print("[NeXLua V11] Starting...")

-- Cerrar versiones anteriores, incluido el Auto Dodge de la V8.
for _, key in ipairs({
    "OS_HEAD_V2", "OS_CLICK_AIM_V3", "OS_ESP_AIM_V4",
    "OS_ESP_AIM_V5", "OS_ESP_AIM_V6", "OS_ESP_AIM_V7",
    "OS_ESP_AIM_V8", "OS_ESP_AIM_V9",
    "OS_NEXLUA_ONESHOT_V10", "OS_NEXLUA_ONESHOT_V11", "OS_NEXLUA_ONESHOT_V12"
}) do
    local old = ENV[key]
    if old then
        old.Enabled = false
        old.Aim = false
        old.ESP = false
        old.Dodge = false
        if type(old.Stop) == "function" then
            pcall(old.Stop)
        end
    end
end
for _, name in ipairs({
    "OneShotHeadAim", "OneShot_HeadAim_V2",
    "OneShot_ClickAim_V3", "OneShot_V4_AIM",
    "OneShot_V5_Aim", "OneShot_V6_Aim",
    "OneShot_V7_Aim", "OneShot_V8_Aim",
    "OneShot_V8_Dodge", BIND
}) do
    pcall(function() RS:UnbindFromRenderStep(name) end)
end

local S = {
    Running = true,
    ESP = false,
    Aim = false,
    Shooting = false,
    Target = nil,
    NextSearch = 0,
    Detected = {},  -- [Model] = "JUGADOR" o "MODELO"
    Marks = {},     -- [Model] = Highlight
    Connections = {}
}
ENV.OS_ESP_AIM_V9 = S
ENV.OS_NEXLUA_ONESHOT_V12 = S

local function connect(signal, callback)
    local c = signal:Connect(callback)
    table.insert(S.Connections, c)
    return c
end

local function headOf(model)
    local head = model:FindFirstChild("Head")
        or model:FindFirstChild("Head", true)
    return (head and head:IsA("BasePart")) and head or nil
end

local function humanoidOf(model)
    return model:FindFirstChildOfClass("Humanoid")
end

local function isAlive(model)
    if not model or not model:IsDescendantOf(WS) then return false end
    local hum = humanoidOf(model)
    return hum == nil or hum.Health > 0
end

local function isPlayerModel(model)
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char and (model == char or model:IsDescendantOf(char)) then
            return true
        end
    end
    return false
end

local function isMyModel(model)
    local char = LP.Character
    return char ~= nil and (model == char or model:IsDescendantOf(char))
end

-- Importante: no limitar la busqueda a Players:GetPlayers().
local function isExtraCharacter(model)
    if not model:IsA("Model") or isPlayerModel(model)
        or isMyModel(model) or not model:IsDescendantOf(WS) then
        return false
    end
    if humanoidOf(model) then
        return headOf(model) ~= nil
    end
    local head = model:FindFirstChild("Head")
    local root = model:FindFirstChild("HumanoidRootPart")
    return head ~= nil and head:IsA("BasePart")
        and root ~= nil and root:IsA("BasePart")
end

local function removeMark(model)
    local mark = S.Marks[model]
    if mark then
        mark:Destroy()
        S.Marks[model] = nil
    end
end

local function updateMark(model, kind)
    if not S.ESP or not model:IsDescendantOf(WS) then
        removeMark(model)
        return
    end

    local mark = S.Marks[model]
    if not mark or not mark.Parent or mark.Adornee ~= model then
        removeMark(model)
        mark = Instance.new("Highlight")
        mark.Name = "OneShot_V9_ESP"
        mark.Adornee = model
        mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        mark.FillTransparency = 0.63
        mark.OutlineTransparency = 0
        mark.Parent = model
        S.Marks[model] = mark
    end

    -- Rojo: jugador del servidor; violeta: personaje extra del mapa.
    mark.FillColor = kind == "JUGADOR"
        and Color3.fromRGB(255, 46, 67)
        or Color3.fromRGB(182, 72, 255)
    mark.OutlineColor = Color3.fromRGB(255, 255, 255)
    mark.Enabled = true
end

local function scanCharacters()
    local found = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if player ~= LP and char and char:IsDescendantOf(WS) then
            found[char] = "JUGADOR"
        end
    end

    -- Igual que en la V7: buscar los modelos adicionales del escenario.
    for _, item in ipairs(WS:GetDescendants()) do
        local model
        if item:IsA("Humanoid") and item.Parent:IsA("Model") then
            model = item.Parent
        elseif item:IsA("BasePart") and item.Name == "Head"
            and item.Parent:IsA("Model") then
            model = item.Parent
        end

        if model and not found[model] and isExtraCharacter(model) then
            found[model] = "MODELO"
        end
    end

    S.Detected = found

    for model in pairs(S.Marks) do
        if not found[model] then removeMark(model) end
    end

    if S.ESP then
        for model, kind in pairs(found) do
            updateMark(model, kind)
        end
    else
        for model in pairs(S.Marks) do
            removeMark(model)
        end
    end
end

local function canSee(model, head)
    local camera = WS.CurrentCamera
    if not camera then return false end

    local exclusions = {camera}
    if LP.Character then
        table.insert(exclusions, LP.Character)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclusions
    params.IgnoreWater = true

    local origin = camera.CFrame.Position
    local hit = WS:Raycast(origin, head.Position - origin, params)
    return hit == nil or hit.Instance:IsDescendantOf(model)
end

local function findTarget()
    local camera = WS.CurrentCamera
    if not camera then return nil end

    local center = camera.ViewportSize / 2
    local closest, bestDistance = nil, math.huge

    for model in pairs(S.Detected) do
        if isAlive(model) then
            local head = headOf(model)
            if head then
                local pos, onScreen = camera:WorldToViewportPoint(head.Position)
                if onScreen and pos.Z > 0 then
                    local distance = (
                        Vector2.new(pos.X, pos.Y) - center
                    ).Magnitude

                    if distance < bestDistance and canSee(model, head) then
                        closest = model
                        bestDistance = distance
                    end
                end
            end
        end
    end

    return closest
end

local function validTarget(model)
    if not model or not S.Detected[model] or not isAlive(model) then
        return false
    end
    local head = headOf(model)
    return head ~= nil and canSee(model, head)
end

local function aimWhileShooting()
    if not S.Running or not S.Aim or not S.Shooting then return end
    local camera = WS.CurrentCamera
    if not camera then return end

    if not validTarget(S.Target) then
        S.Target = nil
    end

    if not S.Target and os.clock() >= S.NextSearch then
        S.Target = findTarget()
        S.NextSearch = os.clock() + 0.12
    end

    if S.Target then
        local head = headOf(S.Target)
        if head then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, head.Position)
        end
    end
end

-- ========================================
-- NEXLUA HUB | COMPACT GAME INTERFACE
-- ========================================
local CHANNEL_URL = "https://www.youtube.com/@NexLuaRBX"
local LOGO_ASSET_ID = 0 -- Optional Roblox asset ID if you uploaded the image

local C = {
    dark = Color3.fromRGB(10, 16, 14),
    panel = Color3.fromRGB(15, 24, 21),
    row = Color3.fromRGB(23, 35, 30),
    line = Color3.fromRGB(43, 95, 62),
    lime = Color3.fromRGB(46, 239, 102),
    dim = Color3.fromRGB(157, 183, 166),
    white = Color3.fromRGB(244, 255, 247),
    off = Color3.fromRGB(100, 113, 105)
}

local function corner(obj, px)
    local item = Instance.new("UICorner")
    item.CornerRadius = UDim.new(0, px or 8)
    item.Parent = obj
    return item
end

local function outline(obj)
    local stroke = Instance.new("UIStroke")
    stroke.Color = C.line
    stroke.Thickness = 1
    stroke.Transparency = 0.15
    stroke.Parent = obj
end

local function label(parent, words, size, color, bold)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = words
    l.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextColor3 = color or C.white
    l.TextSize = size or 13
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function toast(msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NeXLua Hub", Text = msg, Duration = 5
        })
    end)
end

local function visitChannel()
    -- Roblox LocalScripts cannot universally open external browsers.
    for _, name in ipairs({"openurl", "open_url", "openbrowser", "open_browser"}) do
        local fn = ENV[name]
        if type(fn) == "function" then
            local ok = pcall(fn, CHANNEL_URL)
            if ok then return end
        end
    end
    local copy = ENV.setclipboard or ENV.toclipboard or setclipboard
    if type(copy) == "function" and pcall(copy, CHANNEL_URL) then
        toast("YouTube link copied. Open it in your browser!")
    else
        toast("YouTube: @NexLuaRBX")
    end
end

local function base64decode(data)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local dict = {}
    for i=1,#chars do dict[chars:sub(i,i)] = i - 1 end
    local bytes, carry, bits = {}, 0, 0
    for i=1,#data do
        local n = dict[data:sub(i,i)]
        if n then
            carry = carry * 64 + n
            bits += 6
            if bits >= 8 then
                bits -= 8
                local b = math.floor(carry / (2^bits))
                bytes[#bytes+1] = string.char(b % 256)
                carry = carry % (2^bits)
            end
        end
    end
    return table.concat(bytes)
end

-- Embedded avatar from the supplied NeXLua picture (no external hosting).
local AVATAR_B64 = [[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]]
local avatarSource
if LOGO_ASSET_ID > 0 then
    avatarSource = "rbxassetid://" .. tostring(LOGO_ASSET_ID)
else
    local write = ENV.writefile or writefile
    local getAsset = ENV.getcustomasset or ENV.getsynasset or getcustomasset or getsynasset
    if type(write) == "function" and type(getAsset) == "function" then
        pcall(function()
            local filename = "NeXLua_OneShot_Avatar.jpg"
            write(filename, base64decode(AVATAR_B64))
            avatarSource = getAsset(filename)
        end)
    end
end
AVATAR_B64 = nil

-- Guaranteed 24x24 fallback: the actual user's avatar rendered as GUI pixels.
local LOGO_PALETTE = {"4AA72E", "2B7419", "225B16", "1B4A11", "123A0C", "0D2E09", "092206", "061A05", "031403", "031003", "030D03", "020A02", "020802", "010501", "010301", "000001"}
local LOGO_PIXELS = {
    "F714FDF4244213223CBC419F",
    "714FEDD25420022119CAE418",
    "16FDEB6385100110159BBF41",
    "5F9ED53522110000027ADCF4",
    "FCD95237355423200008ADDF",
    "DDA671374534643441018ADC",
    "DC88733B8556A51261102BCE",
    "ECAC723776795556603008AE",
    "DAAC73456A756686633404AC",
    "D989512457946864332502DC",
    "CA966413F339D844213402DB",
    "88333113F41C6A51148102AC",
    "522ED524AFFECF414650079C",
    "14CED8A97BACA71476203AAB",
    "5C88EC7847BDD642242158AC",
    "8B78FA78477678F9565516E8",
    "79A9EF77CC877535688B3056",
    "8789AE76B9A998853236507C",
    "87888ED9779C89BD9664104E",
    "9A99FDA9DA88998EA8E8822D",
    "1B7BE9CEBA8EEE8AC899DE51",
    "1188E8AEB8AFB8FDBB9AB712",
    "F11ADEDAAABB9ABCCCABB13F",
    "EF217FCBCDECADDADCA613FE",
}
local function addAvatar(parent)
    local holder = Instance.new("Frame")
    holder.Name = "NeXLuaAvatar"
    holder.Size = UDim2.fromOffset(42, 42)
    holder.Position = UDim2.fromOffset(8, 7)
    holder.BackgroundColor3 = C.dark
    holder.ClipsDescendants = true
    holder.Parent = parent
    corner(holder, 21)
    local rgbColors = {}
    for i, hex in ipairs(LOGO_PALETTE) do
        rgbColors[i] = Color3.fromRGB(
            tonumber(hex:sub(1,2),16),
            tonumber(hex:sub(3,4),16),
            tonumber(hex:sub(5,6),16)
        )
    end
    for y, row in ipairs(LOGO_PIXELS) do
        for x=1,24 do
            local index = tonumber(row:sub(x,x),16)+1
            local p = Instance.new("Frame")
            p.BackgroundColor3 = rgbColors[index]
            p.BorderSizePixel = 0
            p.Size = UDim2.new(1/24, 0, 1/24, 0)
            p.Position = UDim2.fromScale((x-1)/24, (y-1)/24)
            p.Parent = holder
        end
    end
    if avatarSource then
        local overlay = Instance.new("ImageLabel")
        overlay.BackgroundTransparency = 1
        overlay.Size = UDim2.fromScale(1,1)
        overlay.ScaleType = Enum.ScaleType.Crop
        overlay.Image = avatarSource
        overlay.Visible = false
        overlay.Parent = holder
        pcall(function()
            overlay.Visible = overlay.IsLoaded
            connect(overlay:GetPropertyChangedSignal("IsLoaded"), function()
                overlay.Visible = overlay.IsLoaded
            end)
        end)
    end
    return holder
end

local parent = LP:WaitForChild("PlayerGui")
-- Use PlayerGui directly for consistent visibility in Velocity.
for _, guiName in ipairs({"OneShot_V9_Menu", "NeXLua_OneShot_V10", "NeXLua_OneShot_V11", "NeXLua_OneShot_V12"}) do
    local oldGui = parent:FindFirstChild(guiName)
    if oldGui then oldGui:Destroy() end
end

local gui = Instance.new("ScreenGui")
gui.Name = "NeXLua_OneShot_V12"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
gui.Parent = parent
S.gui = gui

local frame = Instance.new("Frame")
frame.Name = "CompactHub"
frame.Size = UDim2.fromOffset(276, 188)
frame.Position = UDim2.new(1, -290, 0.24, 0)
frame.BackgroundColor3 = C.panel
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
corner(frame, 12)
outline(frame)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 55)
header.BackgroundTransparency = 1
header.Active = true
header.Parent = frame
addAvatar(header)

local hubTitle = label(header, "NeXLua Hub", 16, C.white, true)
hubTitle.Position = UDim2.fromOffset(58, 7)
hubTitle.Size = UDim2.fromOffset(134, 24)
local channel = Instance.new("TextButton")
channel.Name = "YouTubeChannel"
channel.BackgroundTransparency = 1
channel.Position = UDim2.fromOffset(58, 31)
channel.Size = UDim2.fromOffset(151, 17)
channel.Text = "YouTube: @NexLuaRBX  >"
channel.Font = Enum.Font.Gotham
channel.TextSize = 10
channel.TextColor3 = C.lime
channel.TextXAlignment = Enum.TextXAlignment.Left
channel.Parent = header
connect(channel.Activated, visitChannel)

local function headButton(words, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(23, 24)
    b.Position = UDim2.fromOffset(x, 12)
    b.BackgroundColor3 = C.row
    b.TextColor3 = C.white
    b.Text = words
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.Parent = header
    corner(b, 6)
    return b
end
local minButton = headButton("-", 222)
local closeButton = headButton("x", 249)

local body = Instance.new("Frame")
body.Position = UDim2.fromOffset(0, 57)
body.Size = UDim2.new(1, 0, 1, -57)
body.BackgroundTransparency = 1
body.Parent = frame

local function toggleRow(y, words, subtitle)
    local row = Instance.new("TextButton")
    row.Position = UDim2.fromOffset(9, y)
    row.Size = UDim2.new(1, -18, 0, 48)
    row.BackgroundColor3 = C.row
    row.BorderSizePixel = 0
    row.Text = ""
    row.Parent = body
    corner(row, 8)
    outline(row)
    local main = label(row, words, 13, C.white, true)
    main.Position = UDim2.fromOffset(10, 6)
    main.Size = UDim2.fromOffset(165, 18)
    local desc = label(row, subtitle, 10, C.dim, false)
    desc.Position = UDim2.fromOffset(10, 27)
    desc.Size = UDim2.fromOffset(178, 15)
    local status = label(row, "OFF", 11, C.off, true)
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.Position = UDim2.new(1, -59, 0, 12)
    status.Size = UDim2.fromOffset(48, 24)
    status.BackgroundColor3 = C.dark
    status.BackgroundTransparency = 0
    corner(status, 7)
    return row, status
end

local espRow, espStatus = toggleRow(0, "Wallhack ESP", "Players + workspace models")
local aimRow, aimStatus = toggleRow(53, "Head Aim", "PC: click  •  Mobile: native fire")
local foot = label(body, UIS.TouchEnabled and "MOBILE TEST: WAITING FOR FIRE" or "OneShot  •  NeXLua Edition", 9, C.dim, false)
foot.TextXAlignment = Enum.TextXAlignment.Center
foot.Position = UDim2.fromOffset(9, 109)
foot.Size = UDim2.new(1, -18, 0, 17)

local function paint(status, enabled)
    status.Text = enabled and "ON" or "OFF"
    status.BackgroundColor3 = enabled and C.lime or C.dark
    status.TextColor3 = enabled and C.dark or C.off
end
connect(espRow.Activated, function()
    S.ESP = not S.ESP
    scanCharacters()
    paint(espStatus, S.ESP)
end)
connect(aimRow.Activated, function()
    S.Aim = not S.Aim
    S.Shooting = false
    S.Target = nil
    if UIS.TouchEnabled then foot.Text = S.Aim and "MOBILE TEST: WAITING FOR FIRE" or "MOBILE TEST: HEAD AIM OFF" end
    paint(aimStatus, S.Aim)
end)

-- Minimize to a small draggable header without disabling toggles.
local minimized = false
connect(minButton.Activated, function()
    minimized = not minimized
    body.Visible = not minimized
    frame.Size = UDim2.fromOffset(276, minimized and 55 or 188)
    minButton.Text = minimized and "+" or "-"
end)
connect(closeButton.Activated, function()
    if type(S.Stop) == "function" then S.Stop() end
end)

local function overMenu()
    local mouse = UIS:GetMouseLocation()
    local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
    return mouse.X >= pos.X and mouse.X <= pos.X + size.X
       and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y
end

-- V12: mobile uses the game's REAL fire controls; never simulate mouse or keyboard.
-- This test keeps the existing camera logic and ESP untouched.
local activeTouch = nil
local shotSource = nil
local trackedTools = {}

local function diagnostic(message)
    if UIS.TouchEnabled then
        foot.Text = "MOBILE TEST: " .. message
        print("[NeXLua OneShot V12] " .. message)
    end
end

local function startShot(source)
    if not S.Running or not S.Aim then
        diagnostic("HEAD AIM IS OFF")
        return
    end
    S.Shooting = true
    shotSource = source
    S.Target = findTarget()
    S.NextSearch = 0
    diagnostic("FIRE " .. source .. " / TARGET " .. (S.Target and "YES" or "NO"))
    aimWhileShooting()
end

local function stopShot(source)
    if shotSource ~= source then return end
    shotSource = nil
    S.Shooting = false
    S.Target = nil
end

local function inHub(point)
    local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
    return point.X >= pos.X and point.X <= pos.X + size.X
       and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

local function isFireButtonAt(point)
    -- Recognize actual game GUI controls by accessible names/text.
    -- Other touches (movement, camera, jump, chat) will not engage the aim.
    local ok, elements = pcall(function()
        return parent:GetGuiObjectsAtPosition(point.X, point.Y)
    end)
    if not ok or type(elements) ~= "table" then return false end
    for _, hit in ipairs(elements) do
        local node = hit
        for _ = 1, 4 do
            if not node or node == parent then break end
            if node:IsA("GuiObject") then
                local name = tostring(node.Name):lower()
                local txt = ""
                if node:IsA("TextButton") or node:IsA("TextLabel") then
                    txt = tostring(node.Text):lower()
                end
                local fire = name:find("shoot", 1, true)
                    or name:find("fire", 1, true)
                    or name:find("trigger", 1, true)
                    or txt == "shoot" or txt == "fire"
                if fire then return true end
            end
            node = node.Parent
        end
    end
    return false
end

-- PC behaviour is identical to V11. Mobile ignores synthetic mouse actions.
connect(UIS.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if UIS.TouchEnabled then return end
        if not S.Aim or overMenu() or UIS:GetFocusedTextBox() then return end
        startShot("PC")
    elseif input.UserInputType == Enum.UserInputType.Touch and UIS.TouchEnabled then
        local point = input.Position
        if inHub(point) then return end
        if isFireButtonAt(point) then
            activeTouch = input
            startShot("FIRE BUTTON")
        elseif S.Aim then
            if not S.Shooting then diagnostic("TOUCH OK / FIRE UNKNOWN") end
        end
    end
end)
connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not UIS.TouchEnabled then
        stopShot("PC")
    elseif input == activeTouch then
        activeTouch = nil
        stopShot("FIRE BUTTON")
    end
end)

-- Roblox Tool.Activated also supports touch, if OneShot uses Tool weapons.
local function trackTool(tool)
    if not tool:IsA("Tool") or trackedTools[tool] then return end
    trackedTools[tool] = true
    connect(tool.Activated, function()
        if tool.Parent == LP.Character then startShot("TOOL") end
    end)
    connect(tool.Deactivated, function()
        stopShot("TOOL")
    end)
end
local function bindCharacter(character)
    for _, child in ipairs(character:GetChildren()) do
        trackTool(child)
    end
    connect(character.ChildAdded, trackTool)
end
if LP.Character then bindCharacter(LP.Character) end
connect(LP.CharacterAdded, bindCharacter)

RS:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 5, function()
    if S.Shooting then aimWhileShooting() end
end)

-- Drag the hub by the header.
local dragging, dragStart, startPosition, dragTouch = false, nil, nil, nil
connect(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragTouch = input
        dragStart = input.Position
        startPosition = frame.Position
    end
end)
connect(UIS.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input == dragTouch then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
        )
    end
end)
connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input == dragTouch then
        dragging = false
        dragTouch = nil
    end
end)


-- Detectar jugadores nuevos y modelos extra sin mostrar diagnostico.
task.spawn(function()
    while S.Running and gui.Parent do
        scanCharacters()
        task.wait(3)
    end
end)

-- Limpieza al ejecutar otra version (o manualmente desde getgenv()).
S.Stop = function()
    if not S.Running then return end
    S.Running = false
    S.Aim, S.ESP, S.Shooting = false, false, false
    S.Target = nil
    RS:UnbindFromRenderStep(BIND)
    for model in pairs(S.Marks) do
        removeMark(model)
    end
    for _, connection in ipairs(S.Connections) do
        connection:Disconnect()
    end
    gui:Destroy()
end

scanCharacters()
print("[NeXLua OneShot V12] Mobile fire detection test ready.")
