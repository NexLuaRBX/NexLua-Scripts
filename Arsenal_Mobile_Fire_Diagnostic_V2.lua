-- NeXLua Mobile Fire Diagnostic V2
-- Observes one real touch on Arsenal's fire control. Does not generate inputs.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local env = (type(getgenv) == "function" and getgenv()) or _G
if type(env.NeXLuaMobileDiagnosticV2Stop) == "function" then
    pcall(env.NeXLuaMobileDiagnosticV2Stop)
end
local alive, armed, captured = true, false, false
local connections = {}
local function listen(event, fn)
    local c = event:Connect(fn)
    connections[#connections + 1] = c
    return c
end
local function make(class, parent, props)
    local object = Instance.new(class)
    for k, v in pairs(props) do object[k] = v end
    object.Parent = parent
    return object
end
local oldGui = playerGui:FindFirstChild("NeXLua_Mobile_Fire_Diag_V2")
if oldGui then pcall(function() oldGui:Destroy() end) end
local gui = make("ScreenGui", playerGui, {
    Name = "NeXLua_Mobile_Fire_Diag_V2",
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    DisplayOrder = 1000010,
})
local panel = make("Frame", gui, {
    Name = "Panel",
    Size = UDim2.fromOffset(286, 190),
    Position = UDim2.fromOffset(6, 62),
    BackgroundColor3 = Color3.fromRGB(10, 23, 15),
    BorderSizePixel = 0,
    Active = true,
})
make("UICorner", panel, {CornerRadius = UDim.new(0, 10)})
make("UIStroke", panel, {Color = Color3.fromRGB(57, 240, 109), Thickness = 1.4})
make("TextLabel", panel, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(270, 22),
    Text = "NeXLua | FIRE TOUCH CHECK V2",
    Font = Enum.Font.GothamBold, TextSize = 13,
    TextColor3 = Color3.fromRGB(93, 255, 147),
    TextXAlignment = Enum.TextXAlignment.Left,
})
local status = make("TextLabel", panel, {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 30), Size = UDim2.fromOffset(266, 83),
    Text = "1. Tap ARM NEXT TOUCH\n2. Tap Arsenal's FIRE button once\n3. Tap COPY REPORT",
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top, Font = Enum.Font.Gotham,
    TextSize = 12, TextColor3 = Color3.fromRGB(219, 240, 226),
})
local function button(text, x, width, color)
    local b = make("TextButton", panel, {
        Text = text, Position = UDim2.fromOffset(x, 143),
        Size = UDim2.fromOffset(width, 32), BackgroundColor3 = color,
        BorderSizePixel = 0, TextColor3 = Color3.new(1, 1, 1),
        TextSize = 11, Font = Enum.Font.GothamBold,
    })
    make("UICorner", b, {CornerRadius = UDim.new(0, 6)})
    return b
end
local arm = button("ARM TOUCH", 10, 91, Color3.fromRGB(22, 129, 69))
local copy = button("COPY REPORT", 108, 114, Color3.fromRGB(22, 129, 69))
local close = button("X", 229, 47, Color3.fromRGB(47, 63, 49))

local report = "NeXLua Mobile Fire Touch Diagnostic V2\nNo touch captured yet."
local function path(object)
    if not object then return "none" end
    local p, nodes = object, {}
    for _ = 1, 8 do
        if not p then break end
        table.insert(nodes, 1, p.Name .. "[" .. p.ClassName .. "]")
        if p == playerGui or p == CoreGui then break end
        p = p.Parent
    end
    return table.concat(nodes, "/")
end
local function surfaceInfo(object)
    local result = path(object)
    if object:IsA("GuiObject") then
        result = result .. " | Active=" .. tostring(object.Active)
            .. " Z=" .. tostring(object.ZIndex)
            .. " Visible=" .. tostring(object.Visible)
    end
    return result
end
local function getStack(root, x, y, label)
    local lines = {"--- " .. label .. " ---"}
    local ok, items = pcall(function() return root:GetGuiObjectsAtPosition(x, y) end)
    if not ok then
        lines[#lines + 1] = "Not accessible"
        return lines
    end
    local count = 0
    for _, obj in ipairs(items) do
        if obj ~= gui and not obj:IsDescendantOf(gui) then
            count = count + 1
            lines[#lines + 1] = tostring(count) .. ". " .. surfaceInfo(obj)
            if count >= 8 then break end
        end
    end
    if count == 0 then lines[#lines + 1] = "No visible GUI objects at touch" end
    return lines
end
local function findAmmo()
    local matches = {}
    for _, obj in ipairs(playerGui:GetDescendants()) do
        if obj:IsA("TextLabel") and obj.Visible then
            local t = obj.Text or ""
            if (#t <= 28) and (
                t:match("^%s*%d+%s*/%s*%d+%s*$")
                or (obj.Name:lower():find("ammo", 1, true))
            ) then
                matches[#matches + 1] = path(obj) .. " = " .. t
                if #matches >= 5 then break end
            end
        end
    end
    if #matches == 0 then return "Not found (may be drawn elsewhere)" end
    return table.concat(matches, " | ")
end
local function connectionCount(event)
    local func = env.getconnections or getconnections
    if type(func) ~= "function" then return "not available" end
    local ok, cs = pcall(func, event)
    if ok and type(cs) == "table" then return tostring(#cs) end
    return "unknown"
end
local activeInput, startTime
listen(UserInputService.TouchStarted, function(input, processed)
    if not alive or not armed or captured then return end
    local p = input.Position
    local pos, size = panel.AbsolutePosition, panel.AbsoluteSize
    if p.X >= pos.X and p.X <= pos.X + size.X and p.Y >= pos.Y and p.Y <= pos.Y + size.Y then
        return
    end
    armed, captured, activeInput, startTime = false, true, input, os.clock()
    local lines = {
        "NeXLua Mobile Fire Touch Diagnostic V2",
        "TouchEnabled: " .. tostring(UserInputService.TouchEnabled),
        "Touch position: " .. math.floor(p.X) .. ", " .. math.floor(p.Y),
        "Game processed touch: " .. tostring(processed),
        "Touch input type: " .. tostring(input.UserInputType),
        "Equipped Roblox Tool: " .. (player.Character and (
            (player.Character:FindFirstChildWhichIsA("Tool") and player.Character:FindFirstChildWhichIsA("Tool").Name)
            or "none") or "no character"),
        "Ammo GUI before shot: " .. findAmmo(),
        "UserInputService.TouchStarted listeners: " .. connectionCount(UserInputService.TouchStarted),
    }
    local groupA = getStack(playerGui, p.X, p.Y, "PlayerGui under FIRE finger")
    for _, line in ipairs(groupA) do lines[#lines + 1] = line end
    local groupB = getStack(CoreGui, p.X, p.Y, "CoreGui under FIRE finger")
    for _, line in ipairs(groupB) do lines[#lines + 1] = line end
    local snapshots = table.concat(lines, "\n")
    report = snapshots .. "\nTouch duration: waiting for release"
    status.Text = "Captured real touch at " .. math.floor(p.X) .. ", " .. math.floor(p.Y)
        .. "\nRelease FIRE, then COPY REPORT."
    arm.Text = "RE-ARM"
    task.delay(0.6, function()
        if alive and captured then
            report = report .. "\nAmmo GUI after shot: " .. findAmmo()
        end
    end)
end)
listen(UserInputService.TouchEnded, function(input)
    if input ~= activeInput or not captured then return end
    report = report:gsub("Touch duration: waiting for release", "Touch duration: " ..
        string.format("%.3f s", os.clock() - startTime))
    activeInput = nil
end)
listen(arm.Activated, function()
    armed, captured = true, false
    activeInput, startTime = nil, nil
    arm.Text = "ARMED..."
    status.Text = "Now tap Arsenal's actual FIRE button once.\nDon't tap other controls first."
end)
listen(copy.Activated, function()
    local clipboard = env.setclipboard or setclipboard or env.toclipboard or toclipboard
    if type(clipboard) == "function" and pcall(clipboard, report) then
        copy.Text = "COPIED!"
    else
        print(report)
        copy.Text = "IN CONSOLE"
    end
end)
local function stop()
    if not alive then return end
    alive = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
    if env.NeXLuaMobileDiagnosticV2Stop == stop then env.NeXLuaMobileDiagnosticV2Stop = nil end
end
listen(close.Activated, stop)
env.NeXLuaMobileDiagnosticV2Stop = stop
print("[NeXLua] Mobile touch diagnostic V2 ready (read-only)")
