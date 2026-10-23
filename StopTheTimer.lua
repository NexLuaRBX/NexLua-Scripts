-- NeXLua Hub | Auto Stop | V18 CALL-SITE TRACE
-- Diagnostic ONLY: captures the call stack of a genuine mobile stop-button tap.
-- Does not replay RemoteEvents, click, simulate input, or change the timer logic.
-- Start a fresh Roblox session before running; older __namecall hooks may persist.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")
local ENV = (type(getgenv)=="function" and getgenv()) or _G

if type(ENV.NeXLuaV18Stop)=="function" then pcall(ENV.NeXLuaV18Stop) end
local old = PG:FindFirstChild("NeXLuaV18Callsite")
if old then old:Destroy() end

local S={alive=true,armed=false,busy=false,hooked=false,events={},connections={},cycle=0}
local function connect(signal,fn)
    local c=signal:Connect(fn)
    S.connections[#S.connections+1]=c
    return c
end
local function color(r,g,b) return Color3.fromRGB(r,g,b) end
local function corner(obj,r)
    local x=Instance.new("UICorner")
    x.CornerRadius=UDim.new(0,r)
    x.Parent=obj
end
local gui=Instance.new("ScreenGui")
gui.Name="NeXLuaV18Callsite"
gui.ResetOnSpawn=false
gui.DisplayOrder=7000
gui.Parent=PG
local panel=Instance.new("Frame")
panel.Name="TracePanel"
panel.Size=UDim2.fromOffset(336,285)
panel.Position=UDim2.new(1,-345,0.19,0)
panel.BackgroundColor3=color(11,20,16)
panel.BorderSizePixel=0
panel.Active=true
panel.Parent=gui
corner(panel,11)
local border=Instance.new("UIStroke")
border.Color=color(38,217,97)
border.Thickness=1
border.Parent=panel
local function label(txt,y,height,size,tint)
    local v=Instance.new("TextLabel")
    v.Position=UDim2.fromOffset(12,y)
    v.Size=UDim2.new(1,-24,0,height)
    v.BackgroundTransparency=1
    v.TextXAlignment=Enum.TextXAlignment.Left
    v.TextYAlignment=Enum.TextYAlignment.Center
    v.TextWrapped=true
    v.Font=Enum.Font.GothamBold
    v.TextSize=size or 11
    v.TextColor3=tint or color(233,249,239)
    v.Text=txt
    v.Parent=panel
    return v
end
label("NeXLua Hub | SOURCE TRACE",7,28,15,color(53,231,117))
label("YouTube: @NexLuaRBX",35,20,10,color(162,207,173))
local button=Instance.new("TextButton")
button.Name="TraceTap"
button.Size=UDim2.new(1,-24,0,42)
button.Position=UDim2.fromOffset(12,62)
button.BackgroundColor3=color(24,130,66)
button.Font=Enum.Font.GothamBold
button.TextColor3=color(255,255,255)
button.TextSize=13
button.Text="TRACE ONE REAL TAP"
button.Parent=panel
corner(button,8)
local message=label("Ready. Sit at a table first.",110,30,12)
local remoteLabel=label("Remote: --",144,30,11,color(171,221,182))
local callsiteLabel=label("Calling script: --",177,30,11,color(171,221,182))
local frame1=label("Caller stack 1: --",209,31,10,color(171,221,182))
local frame2=label("Caller stack 2: --",244,31,10,color(171,221,182))

local function ownButton()
    local character=LP.Character
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local stations=WS:FindFirstChild("GameStations")
    if not stations then return nil end
    local nearest,nearestD=nil,math.huge
    for _,item in ipairs(stations:GetDescendants()) do
        if item.Name=="Buttons" then
            local aNode=item:FindFirstChild("Player1")
            local bNode=item:FindFirstChild("Player2")
            local a=aNode and aNode:FindFirstChild("Button")
            local b=bNode and bNode:FindFirstChild("Button")
            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                local station=item.Parent
                local seat=hum and hum.SeatPart
                if seat and seat:IsDescendantOf(station) then
                    return ((seat.Position-a.Position).Magnitude <= (seat.Position-b.Position).Magnitude) and a or b
                end
                for _,p in ipairs({a,b}) do
                    local d=(root.Position-p.Position).Magnitude
                    if d<nearestD then nearestD,nearest=d,p end
                end
            end
        end
    end
    return nearestD<20 and nearest or nil
end
local function realButtonTouch(input)
    if input.UserInputType~=Enum.UserInputType.Touch then return false end
    local part=ownButton()
    if not part then return false end
    local cam=WS.CurrentCamera
    if not cam then return false end
    local viewport,onScreen=cam:WorldToViewportPoint(part.Position)
    if not onScreen or viewport.Z<=0 then return false end
    local p=Vector2.new(input.Position.X,input.Position.Y)
    local center=Vector2.new(viewport.X,viewport.Y)
    local inset=Vector2.new(0,0)
    pcall(function() inset=GuiService:GetGuiInset() end)
    return math.min((p-center).Magnitude,(p-center-inset).Magnitude)<=115
end
local function abbreviate(v,n)
    v=tostring(v or "?")
    return #v>n and (v:sub(1,n-3).."...") or v
end
-- Snapshots are only script paths / stack names. No payloads, keys, or args are copied.
local function sourceInfo()
    local caller="UNKNOWN"
    local f=ENV.getcallingscript or getcallingscript
    if type(f)=="function" then
        local ok,scriptObject=pcall(f)
        if ok and typeof(scriptObject)=="Instance" then
            caller=scriptObject:GetFullName()
        end
    end
    local stack={}
    local db=debug
    if type(db)=="table" and type(db.info)=="function" then
        for i=3,13 do
            local ok,source,lineno,name=pcall(db.info,i,"sln")
            if ok and source and source~="[C]" then
                local src=tostring(source)
                -- Skip the trace utility frames if they appear.
                if not src:find("NeXLua_AutoStop_V18",1,true) then
                    stack[#stack+1]=src..(type(lineno)=="number" and (":"..tostring(lineno)) or "")..(name and name~="" and (" / "..name) or "")
                    if #stack>=4 then break end
                end
            end
        end
    end
    return caller,stack
end
local function hookCalls()
    if S.hooked then return true end
    local hook=ENV.hookmetamethod or hookmetamethod
    local methodFn=ENV.getnamecallmethod or getnamecallmethod
    local closure=ENV.newcclosure or newcclosure
    if type(hook)~="function" or type(methodFn)~="function" then return false end
    local ok=pcall(function()
        local original
        local intercept=function(self,...)
            if S.alive and S.armed then
                local m=methodFn()
                if (m=="FireServer" or m=="InvokeServer") and typeof(self)=="Instance"
                    and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent")) then
                    local scriptPath,stack=sourceInfo()
                    S.events[#S.events+1]={time=os.clock(),name=self.Name,scriptPath=scriptPath,stack=stack}
                    while #S.events>35 do table.remove(S.events,1) end
                end
            end
            return original(self,...)
        end
        original=hook(game,"__namecall",type(closure)=="function" and closure(intercept) or intercept)
        S.hooked=true
    end)
    return ok
end
connect(button.Activated,function()
    if S.armed then return end
    if not ownButton() then
        message.Text="Own table not found. Sit down first."
        return
    end
    if not hookCalls() then
        message.Text="Delta cannot inspect remote calls."
        return
    end
    S.events={}
    S.armed=true
    S.busy=false
    S.cycle=S.cycle+1
    local thisCycle=S.cycle
    button.Text="WATCHING..."
    message.Text="Tap the real red button ONCE."
    remoteLabel.Text="Remote: --"
    callsiteLabel.Text="Calling script: --"
    frame1.Text="Caller stack 1: --"
    frame2.Text="Caller stack 2: --"
    task.delay(90,function()
        if S.alive and S.armed and S.cycle==thisCycle then
            S.armed=false
            button.Text="TRACE ONE REAL TAP"
            message.Text="Timeout. Try again."
        end
    end)
end)
connect(UIS.InputBegan,function(input)
    if not S.alive or not S.armed or S.busy or not realButtonTouch(input) then return end
    S.busy=true
    local tapTime=os.clock()
    message.Text="Captured touch. Inspecting call site..."
    task.delay(1.05,function()
        if not S.alive then return end
        local chosen=nil
        for _,rec in ipairs(S.events) do
            if rec.time>=tapTime-0.12 and rec.time<tapTime+0.92 then
                -- Favor dataRemoteEvent: earlier real-tap tests identified this name.
                if not chosen or rec.name=="dataRemoteEvent" then chosen=rec end
            end
        end
        if chosen then
            message.Text="TAP CAPTURED | Call site inspection complete"
            remoteLabel.Text="Remote: "..abbreviate(chosen.name,42)
            callsiteLabel.Text="Calling script: "..abbreviate(chosen.scriptPath,60)
            frame1.Text="Caller stack 1: "..abbreviate(chosen.stack[1] or "NOT EXPOSED",65)
            frame2.Text="Caller stack 2: "..abbreviate(chosen.stack[2] or "NOT EXPOSED",65)
        else
            message.Text="NO REMOTE SEEN for the physical tap."
        end
        S.armed=false
        S.busy=false
        button.Text="TRACE ONE REAL TAP"
        S.events={}
    end)
end)

local dragging,ref,started,originalPos=false,nil,nil,nil
connect(panel.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch and input.Position.Y<panel.AbsolutePosition.Y+58 then
        dragging,ref,started,originalPos=true,input,input.Position,panel.Position
    end
end)
connect(UIS.InputChanged,function(input)
    if dragging and input==ref then
        local delta=input.Position-started
        panel.Position=UDim2.new(originalPos.X.Scale,originalPos.X.Offset+delta.X,originalPos.Y.Scale,originalPos.Y.Offset+delta.Y)
    end
end)
connect(UIS.InputEnded,function(input)
    if input==ref then dragging,ref=false,nil end
end)
ENV.NeXLuaV18Stop=function()
    S.alive=false
    S.armed=false
    for _,c in ipairs(S.connections) do pcall(function() c:Disconnect() end) end
    pcall(function() gui:Destroy() end)
end
print("[NeXLua V18] Source trace ready. Observe only; no automatic interactions.")
