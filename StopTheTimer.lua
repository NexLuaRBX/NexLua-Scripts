-- NeXLua Hub | Auto Stop V14 | Real Mobile Tap Probe
-- Diagnostic only. Does not click, invoke remotes, or alter the V9 timer.
-- Run in a FRESH GAME SESSION without V10-V13 active.
local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local GuiService = game:GetService('GuiService')
local WS = game:GetService('Workspace')
local LP = Players.LocalPlayer
local env = (type(getgenv) == 'function' and getgenv()) or _G
local spy = env.NeXLuaStopTapProbe or {}
env.NeXLuaStopTapProbe = spy
if type(spy.Stop) == 'function' then pcall(spy.Stop) end
spy.active = false
spy.capture = nil
spy.before = nil
spy.installed = spy.installed or false
spy.connections = {}
spy.watchConns = {}

local function track(signal, fn)
    local c = signal:Connect(fn)
    table.insert(spy.connections, c)
    return c
end
local function trackWatch(signal, fn)
    local c = signal:Connect(fn)
    table.insert(spy.watchConns,c)
    return c
end
local function clearWatch()
    for _,c in ipairs(spy.watchConns) do pcall(function() c:Disconnect() end) end
    spy.watchConns = {}
end
local function C(r,g,b) return Color3.fromRGB(r,g,b) end
local function corner(obj, r)
    local v = Instance.new('UICorner')
    v.CornerRadius = UDim.new(0,r)
    v.Parent = obj
end
local pg = LP:WaitForChild('PlayerGui')
local oldGui = pg:FindFirstChild('NeXLua_TapProbe_V14')
if oldGui then oldGui:Destroy() end
local gui = Instance.new('ScreenGui')
gui.Name = 'NeXLua_TapProbe_V14'
gui.ResetOnSpawn = false
gui.DisplayOrder = 4000
gui.IgnoreGuiInset = false
gui.Parent = pg
local frame = Instance.new('Frame')
frame.Size = UDim2.fromOffset(292,183)
frame.Position = UDim2.new(1,-300,0.34,0)
frame.BackgroundColor3 = C(12,20,16)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui
corner(frame,10)
local border = Instance.new('UIStroke')
border.Color = C(40,210,98)
border.Thickness = 1
border.Parent = frame
local function text(value,y,height,size,color)
    local t = Instance.new('TextLabel')
    t.BackgroundTransparency = 1
    t.Position = UDim2.fromOffset(10,y)
    t.Size = UDim2.new(1,-20,0,height)
    t.Font = Enum.Font.GothamBold
    t.TextSize = size or 12
    t.TextColor3 = color or C(235,250,239)
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.TextWrapped = true
    t.Text = value
    t.Parent = frame
    return t
end
text('NeXLua Hub | MOBILE TAP CHECK',9,20,14,C(61,235,110))
text('YouTube: @NexLuaRBX',32,17,10,C(150,197,164))
local arm = Instance.new('TextButton')
arm.Size = UDim2.new(1,-20,0,37)
arm.Position = UDim2.fromOffset(10,57)
arm.BackgroundColor3 = C(21,132,65)
arm.Text = 'WATCH ONE REAL TAP'
arm.Font = Enum.Font.GothamBold
arm.TextSize = 12
arm.TextColor3 = C(255,255,255)
arm.Parent = frame
corner(arm,7)
local status = text('Sit at your table, then press WATCH.',101,40,11)
local detail = text('No automatic input will be sent.',144,30,10,C(148,191,162))

local function show(s,d)
    if status and status.Parent then status.Text = s end
    if d and detail and detail.Parent then detail.Text = d end
end

local function ownButton()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass('Humanoid')
    local root = char and char:FindFirstChild('HumanoidRootPart')
    if not root then return nil end
    local folder = WS:FindFirstChild('GameStations')
    if not folder then return nil end
    local best, distance = nil, math.huge
    for _,obj in ipairs(folder:GetDescendants()) do
        if obj.Name == 'Buttons' then
            local p1 = obj:FindFirstChild('Player1')
            local p2 = obj:FindFirstChild('Player2')
            local a = p1 and p1:FindFirstChild('Button')
            local b = p2 and p2:FindFirstChild('Button')
            if a and b and a:IsA('BasePart') and b:IsA('BasePart') then
                local station = obj.Parent
                local seat = hum and hum.SeatPart
                if seat and seat:IsDescendantOf(station) then
                    local da = (seat.Position-a.Position).Magnitude
                    local db = (seat.Position-b.Position).Magnitude
                    return da < db and a or b
                end
                for _,candidate in ipairs({a,b}) do
                    local d = (root.Position-candidate.Position).Magnitude
                    if d < distance then
                        distance = d
                        best = candidate
                    end
                end
            end
        end
    end
    if distance < 20 then return best end
    return nil
end

local function detectorsFor(part)
    local result, seen = {}, {}
    for _,obj in ipairs(part:GetDescendants()) do
        if obj:IsA('ClickDetector') then
            seen[obj] = true
            table.insert(result,obj)
        end
    end
    local p = part
    for _=1,2 do
        p = p.Parent
        if not p then break end
        local d = p:FindFirstChildOfClass('ClickDetector')
        if d and not seen[d] then
            seen[d] = true
            table.insert(result,d)
        end
    end
    return result
end

local function installSpy()
    if spy.installed then return true end
    local hook = env.hookmetamethod or hookmetamethod
    local method = env.getnamecallmethod or getnamecallmethod
    local nc = env.newcclosure or newcclosure
    if type(hook) ~= 'function' or type(method) ~= 'function' then
        return false
    end
    local ok = pcall(function()
        local old
        local fn = function(self,...)
            -- Only record names, never payloads. Nothing is replayed.
            if spy.active then
                local m = method()
                if (m == 'FireServer' or m == 'InvokeServer') and typeof(self) == 'Instance' then
                    if self:IsA('RemoteEvent') or self:IsA('RemoteFunction')
                        or self:IsA('UnreliableRemoteEvent') then
                        local name = self.Name
                        local cap = spy.capture
                        if cap and os.clock() - cap.started < 0.85 then
                            cap.calls[name] = (cap.calls[name] or 0) + 1
                        elseif spy.before then
                            spy.before[name] = (spy.before[name] or 0) + 1
                        end
                    end
                end
            end
            return old(self,...)
        end
        old = hook(game,'__namecall',type(nc)=='function' and nc(fn) or fn)
        spy.installed = true
    end)
    return ok
end

local function touchNearButton(input,part)
    if input.UserInputType ~= Enum.UserInputType.Touch then return false end
    local camera = WS.CurrentCamera
    if not camera then return false end
    local v,visible = camera:WorldToViewportPoint(part.Position)
    if not visible or v.Z <= 0 then return false end
    local xy = Vector2.new(input.Position.X,input.Position.Y)
    local center = Vector2.new(v.X,v.Y)
    local inset = Vector2.zero
    pcall(function() inset = GuiService:GetGuiInset() end)
    return math.min((xy-center).Magnitude,(xy-center-inset).Magnitude) < 135
end

spy.Stop = function()
    spy.active = false
    spy.capture, spy.before = nil,nil
    clearWatch()
    for _,c in ipairs(spy.connections) do pcall(function() c:Disconnect() end) end
    spy.connections = {}
    pcall(function() gui:Destroy() end)
end

local watchId = 0
track(arm.Activated,function()
    if spy.active then
        show('Already watching: tap the red button.', 'One manual touch only.')
        return
    end
    clearWatch()
    local part = ownButton()
    if not part then
        show('TABLE NOT FOUND','Sit down at a table and press WATCH again.')
        return
    end
    local hookOK = installSpy()
    spy.active = true
    spy.before = {}
    spy.capture = nil
    local nativeFired = false
    local nativeDetectors = detectorsFor(part)
    watchId = watchId + 1
    local thisWatch = watchId
    local tapStarted = false
    for _,d in ipairs(nativeDetectors) do
        trackWatch(d.MouseClick,function(who)
            if who == LP then nativeFired = true end
        end)
    end
    trackWatch(UIS.InputBegan,function(input)
        if tapStarted or not spy.active or not touchNearButton(input,part) then return end
        tapStarted = true
        spy.capture = {started = os.clock(), calls = {}}
        show('REAL TAP DETECTED', 'Checking native ClickDetector and remote events...')
        task.delay(1.10,function()
            if thisWatch ~= watchId then return end
            local cap = spy.capture
            local entries = {}
            if cap then
                for name,count in pairs(cap.calls) do
                    local beforeCount = (spy.before and spy.before[name]) or 0
                    entries[#entries+1] = {name=name,count=count,before=beforeCount}
                end
            end
            table.sort(entries,function(a,b) return a.count>b.count end)
            local native = #nativeDetectors == 0 and 'NO DETECTOR' or
                (nativeFired and 'DETECTOR FIRED' or 'DETECTOR NOT FIRED')
            local remote = #entries == 0 and 'NO REMOTE' or entries[1].name
            show(native..' | '..remote,
                'Remotes: '..tostring(#entries)..' | Spy: '..(hookOK and 'OK' or 'BLOCKED')..
                ' | Earlier traffic: '..(entries[1] and tostring(entries[1].before) or '0'))
            spy.active = false
            clearWatch()
        end)
    end)
    show('WATCHING YOUR RED BUTTON',
        'Detector nodes: '..#nativeDetectors..' | Remote spy: '..(hookOK and 'READY' or 'UNAVAILABLE'))
    task.delay(24,function()
        if thisWatch == watchId and spy.active and not tapStarted then
            spy.active = false
            clearWatch()
            show('TIMEOUT', 'Press WATCH and tap the red button on your turn.')
        end
    end)
end)

-- Drag from the header, without changing input device mode.
local dragging, dragRef, first, origin = false,nil,nil,nil
track(frame.InputBegan,function(input)
    if input.UserInputType == Enum.UserInputType.Touch and input.Position.Y < frame.AbsolutePosition.Y+50 then
        dragging,dragRef,first,origin = true,input,input.Position,frame.Position
    end
end)
track(UIS.InputChanged,function(input)
    if dragging and input == dragRef then
        local d = input.Position-first
        frame.Position = UDim2.new(origin.X.Scale,origin.X.Offset+d.X,origin.Y.Scale,origin.Y.Offset+d.Y)
    end
end)
track(UIS.InputEnded,function(input)
    if input == dragRef then dragging,dragRef = false,nil end
end)
print('[NeXLua V14] Manual Tap Probe ready: no remote replay or simulated clicks.')
