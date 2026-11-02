-- NeXLua | Mobile Fire Diagnostic
-- Read-only: does not fire weapons, synthesize input, or modify the camera.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = (type(getgenv) == "function" and getgenv()) or _G

if type(env.NeXLuaFireDiagnosticStop) == "function" then
    pcall(env.NeXLuaFireDiagnosticStop)
end

local connections = {}
local trackedButtons, trackedTools = {}, {}
local alive = true
local function listen(signal, callback)
    local conn = signal:Connect(callback)
    connections[#connections + 1] = conn
    return conn
end

local old = playerGui:FindFirstChild("NeXLua_Mobile_Fire_Check")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "NeXLua_Mobile_Fire_Check"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000010
gui.Parent = playerGui

local function make(class, parent, props)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local panel = make("Frame", gui, {
    Name = "Panel",
    Size = UDim2.fromOffset(276, 202),
    Position = UDim2.fromOffset(8, 70),
    BackgroundColor3 = Color3.fromRGB(12, 22, 16),
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
})
make("UICorner", panel, {CornerRadius = UDim.new(0, 9)})
make("UIStroke", panel, {Color = Color3.fromRGB(52, 233, 105), Thickness = 1.4})
local title = make("TextLabel", panel, {
    Position = UDim2.fromOffset(10, 7), Size = UDim2.fromOffset(226, 20),
    BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(105, 255, 144), TextSize = 13,
    Text = "NeXLua | MOBILE FIRE CHECK",
})
local info = make("TextLabel", panel, {
    Position = UDim2.fromOffset(10, 29), Size = UDim2.fromOffset(256, 20),
    BackgroundTransparency = 1, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = Color3.fromRGB(205, 223, 210), TextSize = 11,
    Text = "Tap Arsenal's FIRE button 3 times",
})
local status = make("TextLabel", panel, {
    Position = UDim2.fromOffset(10, 51), Size = UDim2.fromOffset(256, 107),
    BackgroundTransparency = 1, Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextColor3 = Color3.fromRGB(237, 248, 241), TextSize = 12,
    TextWrapped = true,
    Text = "Listening for real touches...",
})
local copy = make("TextButton", panel, {
    Position = UDim2.fromOffset(10, 167), Size = UDim2.fromOffset(199, 27),
    BorderSizePixel = 0, Font = Enum.Font.GothamBold,
    BackgroundColor3 = Color3.fromRGB(22, 131, 71),
    TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12,
    Text = "COPY REPORT",
})
make("UICorner", copy, {CornerRadius = UDim.new(0, 6)})
local close = make("TextButton", panel, {
    Position = UDim2.fromOffset(220, 167), Size = UDim2.fromOffset(46, 27),
    BorderSizePixel = 0, Font = Enum.Font.GothamBold,
    BackgroundColor3 = Color3.fromRGB(36, 50, 42),
    TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12,
    Text = "X",
})
make("UICorner", close, {CornerRadius = UDim.new(0, 6)})

local touchCount, processedCount, guiActivatedCount = 0, 0, 0
local toolActivatedCount = 0
local lastTouch = "none"
local lastGuiButton = "none"
local lastTool = "none"
local lastTouchProcessed = false
local activatedLog = {}
local function shortName(obj)
    if not obj then return "none" end
    local pieces, node = {}, obj
    for _ = 1, 4 do
        if not node or node == playerGui then break end
        table.insert(pieces, 1, tostring(node.Name))
        node = node.Parent
    end
    return table.concat(pieces, "/") .. " [" .. tostring(obj.ClassName) .. "]"
end
local function findEquippedTool()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChildWhichIsA("Tool")
end

local function trackTool(item)
    if not item:IsA("Tool") or trackedTools[item] then return end
    trackedTools[item] = true
    listen(item.Activated, function()
        if not alive then return end
        toolActivatedCount = toolActivatedCount + 1
        lastTool = item.Name
    end)
end
local function trackButton(item)
    if not item:IsA("GuiButton") or item:IsDescendantOf(gui)
        or trackedButtons[item] then return end
    trackedButtons[item] = true
    listen(item.Activated, function()
        if not alive then return end
        guiActivatedCount = guiActivatedCount + 1
        lastGuiButton = shortName(item)
        if #activatedLog < 12 then
            activatedLog[#activatedLog + 1] = lastGuiButton
        end
    end)
end
for _, descendant in ipairs(playerGui:GetDescendants()) do
    trackButton(descendant)
end
listen(playerGui.DescendantAdded, trackButton)

local function watchCharacter(char)
    for _, item in ipairs(char:GetChildren()) do trackTool(item) end
    listen(char.ChildAdded, trackTool)
end
if player.Character then watchCharacter(player.Character) end
listen(player.CharacterAdded, watchCharacter)

-- Only observe physical touches. Never generate touch or mouse events.
listen(UIS.TouchStarted, function(input, processed)
    if not alive then return end
    local p = input.Position
    local pos = panel.AbsolutePosition
    local sz = panel.AbsoluteSize
    if p.X >= pos.X and p.X <= pos.X + sz.X
        and p.Y >= pos.Y and p.Y <= pos.Y + sz.Y then return end
    touchCount = touchCount + 1
    if processed then processedCount = processedCount + 1 end
    lastTouchProcessed = processed == true
    local ok, objects = pcall(function()
        return playerGui:GetGuiObjectsAtPosition(p.X, p.Y)
    end)
    lastTouch = "none (no GUI hit)"
    if ok and type(objects) == "table" then
        for _, item in ipairs(objects) do
            if item ~= gui and not item:IsDescendantOf(gui) then
                lastTouch = shortName(item)
                break
            end
        end
    end
end)

local function actionNames()
    local names = {}
    local ok, actions = pcall(function() return CAS:GetAllBoundActionInfo() end)
    if ok and type(actions) == "table" then
        for name in pairs(actions) do
            local key = tostring(name):lower()
            if key:find("fire", 1, true) or key:find("shoot", 1, true)
                or key:find("attack", 1, true) or key:find("weapon", 1, true)
                or key:find("trigger", 1, true) then
                names[#names + 1] = tostring(name)
            end
        end
    end
    table.sort(names)
    return (#names > 0) and table.concat(names, ", ") or "none found"
end

local function report()
    local tool = findEquippedTool()
    local lines = {
        "NeXLua Mobile Fire Diagnostic",
        "TouchEnabled: " .. tostring(UIS.TouchEnabled),
        "Real outside-panel touches: " .. touchCount,
        "Processed touches: " .. processedCount,
        "Last touch processed: " .. tostring(lastTouchProcessed),
        "Last GUI under real finger: " .. lastTouch,
        "GUI Activated events seen: " .. guiActivatedCount,
        "Last GUI Activated: " .. lastGuiButton,
        "Equipped Roblox Tool: " .. (tool and tool.Name or "none"),
        "Tool.Activated events seen: " .. toolActivatedCount,
        "Last Tool.Activated: " .. lastTool,
        "Possible ContextAction bindings: " .. actionNames(),
        "GUI Activated samples: " .. table.concat(activatedLog, " | "),
    }
    return table.concat(lines, "\n")
end

listen(copy.Activated, function()
    local data = report()
    local clipboard = env.setclipboard or setclipboard or env.toclipboard or toclipboard
    if type(clipboard) == "function" and pcall(clipboard, data) then
        copy.Text = "REPORT COPIED!"
    else
        print(data)
        copy.Text = "REPORT IN CONSOLE"
    end
end)

local stop
stop = function()
    if not alive then return end
    alive = false
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    if env.NeXLuaFireDiagnosticStop == stop then
        env.NeXLuaFireDiagnosticStop = nil
    end
end
env.NeXLuaFireDiagnosticStop = stop
listen(close.Activated, stop)

task.spawn(function()
    while alive do
        local tool = findEquippedTool()
        status.Text = table.concat({
            "Real touches: " .. touchCount .. " / processed: " .. processedCount,
            "Finger on: " .. lastTouch,
            "GUI Activated: " .. guiActivatedCount,
            "Tool: " .. (tool and tool.Name or "none"),
            "Tool.Activated: " .. toolActivatedCount,
            "Action: " .. actionNames(),
        }, "\n")
        task.wait(0.5)
    end
end)
print("[NeXLua] Mobile fire diagnostic ready. Tap the real fire button and COPY REPORT.")
