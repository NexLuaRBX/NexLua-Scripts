-- NeXLua | Arsenal Mobile Handler Check
-- Read-only. Does not send touch, keyboard, or mouse events.
local Players = game:GetService('Players')
local UIS = game:GetService('UserInputService')
local player = Players.LocalPlayer
local gui = player:WaitForChild('PlayerGui')
local env = (type(getgenv)=='function' and getgenv()) or _G
if type(env.NeXLuaHandlerCheckStop)=='function' then pcall(env.NeXLuaHandlerCheckStop) end
local root = gui:FindFirstChild('GUI')
local mobile = root and root:FindFirstChild('Mobile')
local tablet = mobile and mobile:FindFirstChild('Tablet')
local fire = tablet and tablet:FindFirstChild('ShootFrame')
local gc = (type(getconnections)=='function' and getconnections) or (type(env.getconnections)=='function' and env.getconnections)
local function describe(sig)
    if not sig then return 'not found' end
    if type(gc)~='function' then return 'getconnections unavailable' end
    local ok,result=pcall(gc,sig)
    if not ok then return 'inaccessible: '..tostring(result) end
    if type(result)~='table' then return 'unsupported result' end
    local enabled=0
    for _,c in pairs(result) do
        if c.Enabled~=false then enabled=enabled+1 end
    end
    return tostring(#result)..' connections ('..enabled..' enabled)'
end
local function event(obj,key)
    if not obj then return nil end
    local ok,v=pcall(function() return obj[key] end)
    return ok and v or nil
end
local function snapshot()
    local lines={'NeXLua Arsenal Mobile Handler Check',
        'TouchEnabled: '..tostring(UIS.TouchEnabled),
        'ShootFrame found: '..tostring(fire~=nil),
        'ShootFrame type: '..(fire and fire.ClassName or 'none'),
        'ShootFrame Visible: '..(fire and tostring(fire.Visible) or 'none'),
        'ShootFrame Active: '..(fire and tostring(fire.Active) or 'none'),
        'getconnections: '..tostring(type(gc)=='function'),
    }
    local events={'Activated','TouchTap','MouseButton1Down','MouseButton1Up','MouseButton1Click','InputBegan','InputEnded'}
    for _,key in ipairs(events) do
        lines[#lines+1]='ShootFrame.'..key..': '..describe(event(fire,key))
    end
    for _,key in ipairs({'TouchStarted','TouchEnded','InputBegan','InputEnded'}) do
        lines[#lines+1]='UserInputService.'..key..': '..describe(event(UIS,key))
    end
    lines[#lines+1]='NOTE: These counts do not reveal which callback fires the gun.'
    return table.concat(lines,'\n')
end
local existing = gui:FindFirstChild('NeXLua_Handler_Check')
if existing then existing:Destroy() end
local ui=Instance.new('ScreenGui');ui.Name='NeXLua_Handler_Check';ui.ResetOnSpawn=false;ui.Parent=gui
local panel=Instance.new('Frame');panel.Size=UDim2.fromOffset(270,126);panel.Position=UDim2.fromOffset(8,80);panel.BackgroundColor3=Color3.fromRGB(12,24,16);panel.Parent=ui
Instance.new('UICorner',panel).CornerRadius=UDim.new(0,10)
local stroke=Instance.new('UIStroke',panel);stroke.Color=Color3.fromRGB(50,225,100)
local title=Instance.new('TextLabel');title.BackgroundTransparency=1;title.Size=UDim2.fromOffset(250,35);title.Position=UDim2.fromOffset(10,8);title.Text='NeXLua | MOBILE FIRE CHECK';title.TextColor3=Color3.fromRGB(80,255,132);title.TextSize=13;title.Font=Enum.Font.GothamBold;title.Parent=panel
local msg=Instance.new('TextLabel');msg.BackgroundTransparency=1;msg.Size=UDim2.fromOffset(246,23);msg.Position=UDim2.fromOffset(12,44);msg.Text='Read-only: no input simulation';msg.TextColor3=Color3.new(1,1,1);msg.TextSize=11;msg.Parent=panel
local copy=Instance.new('TextButton');copy.Size=UDim2.fromOffset(140,35);copy.Position=UDim2.fromOffset(14,78);copy.BackgroundColor3=Color3.fromRGB(30,120,62);copy.Text='COPY REPORT';copy.Font=Enum.Font.GothamBold;copy.TextColor3=Color3.new(1,1,1);copy.TextSize=12;copy.Parent=panel
local close=Instance.new('TextButton');close.Size=UDim2.fromOffset(92,35);close.Position=UDim2.fromOffset(165,78);close.BackgroundColor3=Color3.fromRGB(55,72,62);close.Text='CLOSE';close.Font=Enum.Font.GothamBold;close.TextColor3=Color3.new(1,1,1);close.TextSize=12;close.Parent=panel
copy.Activated:Connect(function()
    local report=snapshot()
    local clipboard = (type(setclipboard)=='function' and setclipboard) or (type(env.setclipboard)=='function' and env.setclipboard)
    local ok=type(clipboard)=='function' and pcall(clipboard,report)
    if ok then msg.Text='Report copied' else msg.Text='Clipboard unavailable; check console';print(report) end
end)
local function stop() if ui then ui:Destroy() end;env.NeXLuaHandlerCheckStop=nil end
env.NeXLuaHandlerCheckStop=stop
close.Activated:Connect(stop)
print('[NeXLua] Mobile handler diagnostic loaded')
