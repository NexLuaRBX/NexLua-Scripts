-- NeXLua Hub | Auto Stop V15 | TWO REAL TAPS COMPARISON
-- MOBILE DIAGNOSTIC ONLY. No automatic click, touch simulation, or remote replay.
-- V9 desktop timing and your existing Auto Stop script are NOT modified.
-- Start a new Roblox session to remove hooks from older diagnostic versions.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local WS = game:GetService("Workspace")
local LP = Players.LocalPlayer
local env = (type(getgenv) == "function" and getgenv()) or _G
local pg = LP:WaitForChild("PlayerGui")

if type(env.NeXLuaTapCompareStop) == "function" then pcall(env.NeXLuaTapCompareStop) end
local previous = pg:FindFirstChild("NeXLua_TwoTap_Compare_V15")
if previous then previous:Destroy() end

local S = {alive=true, armed=false, busy=false, captures={}, recent={}, connections={}, hookInstalled=false, current=nil, watchedPart=nil, began=0, run=0}
local function track(signal, callback)
    local conn = signal:Connect(callback)
    table.insert(S.connections, conn)
    return conn
end

local function color(r,g,b) return Color3.fromRGB(r,g,b) end
local function round(obj,r)
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,r)
    c.Parent=obj
end
local gui = Instance.new("ScreenGui")
gui.Name="NeXLua_TwoTap_Compare_V15"
gui.ResetOnSpawn=false
-- Do not mark IgnoreGuiInset=true on mobile: touch positions are aligned with the game.
gui.DisplayOrder=4000
gui.Parent=pg
local panel=Instance.new("Frame")
panel.Size=UDim2.fromOffset(298,222)
panel.Position=UDim2.new(1,-306,0.31,0)
panel.BackgroundColor3=color(10,20,15)
panel.BorderSizePixel=0
panel.Active=true
panel.Parent=gui
round(panel,11)
local border=Instance.new("UIStroke")
border.Color=color(40,202,93)
border.Thickness=1
border.Parent=panel
local function text(value,y,h,size,c)
    local t=Instance.new("TextLabel")
    t.BackgroundTransparency=1
    t.Position=UDim2.fromOffset(11,y)
    t.Size=UDim2.new(1,-22,0,h)
    t.Font=Enum.Font.GothamBold
    t.TextSize=size or 11
    t.TextColor3=c or color(229,245,233)
    t.TextWrapped=true
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.TextYAlignment=Enum.TextYAlignment.Center
    t.Text=value
    t.Parent=panel
    return t
end
text("NeXLua Hub | TWO-TAP CHECK",7,23,14,color(52,231,113))
text("YouTube: @NexLuaRBX",30,19,10,color(162,201,176))
local btn=Instance.new("TextButton")
btn.Size=UDim2.new(1,-22,0,40)
btn.Position=UDim2.fromOffset(11,56)
btn.BackgroundColor3=color(25,132,69)
btn.Font=Enum.Font.GothamBold
btn.TextColor3=color(255,255,255)
btn.TextSize=12
btn.Text="WATCH TWO REAL TAPS"
btn.Parent=panel
round(btn,7)
local st1=text("Ready: sit at your table first.",101,36,11)
local st2=text("Tap 1: --",138,21,10,color(161,201,173))
local st3=text("Tap 2: --",160,21,10,color(161,201,173))
local st4=text("No input will be simulated.",183,30,10,color(95,233,137))

local function ownButton()
    local character=LP.Character
    local hum=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local rootFolder=WS:FindFirstChild("GameStations")
    if not rootFolder then return nil end
    local best, bestD=nil,math.huge
    for _,item in ipairs(rootFolder:GetDescendants()) do
        if item.Name=="Buttons" then
            local p1=item:FindFirstChild("Player1")
            local p2=item:FindFirstChild("Player2")
            local a=p1 and p1:FindFirstChild("Button")
            local b=p2 and p2:FindFirstChild("Button")
            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                local tableModel=item.Parent
                local seat=hum and hum.SeatPart
                if seat and seat:IsDescendantOf(tableModel) then
                    local d1=(seat.Position-a.Position).Magnitude
                    local d2=(seat.Position-b.Position).Magnitude
                    return d1<=d2 and a or b
                end
                for _,p in ipairs({a,b}) do
                    local dist=(p.Position-root.Position).Magnitude
                    if dist<bestD then bestD,best=dist,p end
                end
            end
        end
    end
    return bestD<20 and best or nil
end

local function tappedOwnButton(input)
    if input.UserInputType~=Enum.UserInputType.Touch then return false end
    local part=ownButton()
    if not part then return false end
    local cam=WS.CurrentCamera
    if not cam then return false end
    local v,visible=cam:WorldToViewportPoint(part.Position)
    if not visible or v.Z<=0 then return false end
    local pos=Vector2.new(input.Position.X,input.Position.Y)
    local center=Vector2.new(v.X,v.Y)
    local inset=Vector2.zero
    pcall(function() inset=GuiService:GetGuiInset() end)
    local d=math.min((pos-center).Magnitude,(pos-center-inset).Magnitude)
    if d>115 then return false end
    return true,part
end

local function hashValue(s)
    local h=5381
    for i=1,#s do
        h=(h*33+s:byte(i))%2147483647
    end
    return string.format("%08x",h)
end
local function signature(v,depth)
    depth=depth or 0
    local typ=typeof(v)
    if typ=="buffer" then
        local ok,length=pcall(buffer.len,v)
        if not ok then return "buffer:?" end
        local excerpt={}
        local amount=math.min(length,512)
        for i=0,amount-1 do
            local good,b=pcall(buffer.readu8,v,i)
            if not good then break end
            excerpt[#excerpt+1]=string.char(b)
        end
        return "buffer:"..tostring(length)..":"..hashValue(table.concat(excerpt))
    elseif typ=="string" then
        return "str:"..#v..":"..hashValue(v:sub(1,512))
    elseif typ=="number" or typ=="boolean" or typ=="nil" then
        return typ..":"..tostring(v)
    elseif typ=="Instance" then
        local ok,full=pcall(function() return v:GetFullName() end)
        return "instance:"..(ok and full or v.Name)
    elseif typ=="table" then
        if depth>=2 then return "table:deep" end
        local parts={}
        local count=0
        for k,value in pairs(v) do
            count=count+1
            if count<=24 then
                parts[#parts+1]=tostring(k).."="..signature(value,depth+1)
            end
        end
        table.sort(parts)
        return "table:"..count.."{"..table.concat(parts,";").."}"
    end
    return typ
end
local function captureArgs(...)
    local count=select("#",...)
    local sign={}
    for i=1,math.min(count,12) do
        local v=select(i,...)
        local ok,result=pcall(signature,v,0)
        sign[#sign+1]=ok and result or "arg:error"
    end
    return count,sign
end

local function installHook()
    if S.hookInstalled then return true end
    local hook=env.hookmetamethod or hookmetamethod
    local getMethod=env.getnamecallmethod or getnamecallmethod
    local nc=env.newcclosure or newcclosure
    if type(hook)~="function" or type(getMethod)~="function" then return false end
    local ok=pcall(function()
        local original
        local intercept=function(self,...)
            -- Observe, never replace, the original call.
            if S.alive and S.armed then
                local method=getMethod()
                if (method=="FireServer" or method=="InvokeServer") and typeof(self)=="Instance"
                    and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction") or self:IsA("UnreliableRemoteEvent")) then
                    local now=os.clock()
                    local okArgs,n,args=pcall(captureArgs,...)
                    S.recent[#S.recent+1]={at=now,remote=self,method=method,count=okArgs and n or -1,args=okArgs and args or {"unreadable"}}
                    while #S.recent>40 do table.remove(S.recent,1) end
                end
            end
            return original(self,...)
        end
        original=hook(game,"__namecall",type(nc)=="function" and nc(intercept) or intercept)
        S.hookInstalled=true
    end)
    return ok
end

local function summarize(calls)
    if #calls==0 then return "NO REMOTE",nil end
    -- Prefer the most frequent event immediately following the real tap.
    local grouped={}
    local winner,most=nil,0
    for _,c in ipairs(calls) do
        local key=c.remote:GetFullName().."|"..c.method
        local item=grouped[key]
        if not item then item={count=0,event=c}; grouped[key]=item end
        item.count=item.count+1
        if item.count>most then winner,most=item.event,item.count end
    end
    return (winner and winner.remote.Name or "UNKNOWN").." ("..#calls.." calls)",winner
end

local function compare(a,b)
    if not a or not b then return "COMPARISON INCOMPLETE" end
    if a.remote~=b.remote or a.method~=b.method then
        return "DIFFERENT REMOTE/METHOD - NEEDS REVIEW"
    end
    if a.count~=b.count then
        return "SAME REMOTE; ARG COUNT CHANGED: "..a.count.."/"..b.count
    end
    local changed={}
    for i=1,math.max(#a.args,#b.args) do
        if a.args[i]~=b.args[i] then changed[#changed+1]=tostring(i) end
    end
    if #changed>0 then
        return "SAME REMOTE; CHANGED ARGS: "..table.concat(changed,",")
    end
    return "SAME REMOTE + SAME PAYLOAD (first 512B)"
end

local watchId=0
track(btn.Activated,function()
    if S.armed then return end
    if not ownButton() then
        st1.Text="TABLE NOT FOUND. Sit down first."
        return
    end
    if not installHook() then
        st1.Text="DELTA HOOK UNAVAILABLE"
        return
    end
    S.captures={}
    S.recent={}
    S.armed=true
    S.busy=false
    S.run=S.run+1
    watchId=S.run
    st1.Text="WAITING FOR TAP 1 / 2"
    st2.Text="Tap 1: --"
    st3.Text="Tap 2: --"
    st4.Text="Use the real red button in two rounds."
    btn.Text="WATCHING..."
    task.delay(180,function()
        if S.alive and S.armed and S.run==watchId then
            S.armed=false
            S.busy=false
            btn.Text="WATCH TWO REAL TAPS"
            st1.Text="TIMEOUT. Start the test again."
        end
    end)
end)

track(UIS.InputBegan,function(input)
    if not S.alive or not S.armed or S.busy then return end
    local yes,part=tappedOwnButton(input)
    if not yes then return end
    S.busy=true
    local tapNo=#S.captures+1
    local tapAt=os.clock()
    local matching={}
    for _,call in ipairs(S.recent) do
        if call.at>=tapAt-0.12 and call.at<tapAt then matching[#matching+1]=call end
    end
    st1.Text="CAPTURING TAP "..tapNo.." / 2"
    task.delay(1.08,function()
        if not S.alive then return end
        for _,call in ipairs(S.recent) do
            if call.at>=tapAt and call.at<tapAt+0.9 then
                matching[#matching+1]=call
            end
        end
        local label,best=summarize(matching)
        S.captures[tapNo]=best
        if tapNo==1 then
            st2.Text="Tap 1: "..label
            st1.Text="WAITING FOR TAP 2 / 2 (next round)"
            st4.Text="Make another REAL tap in the next round."
        else
            st3.Text="Tap 2: "..label
            st1.Text="TWO-TAP COMPARISON COMPLETE"
            st4.Text=compare(S.captures[1],S.captures[2])
            S.armed=false
            btn.Text="WATCH TWO REAL TAPS"
        end
        S.busy=false
        S.recent={}
    end)
end)

local dragging,dragRef,dragStart,frameStart=false,nil,nil,nil
track(panel.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch
        and input.Position.Y<panel.AbsolutePosition.Y+50 then
        dragging,dragRef,dragStart,frameStart=true,input,input.Position,panel.Position
    end
end)
track(UIS.InputChanged,function(input)
    if dragging and input==dragRef then
        local d=input.Position-dragStart
        panel.Position=UDim2.new(frameStart.X.Scale,frameStart.X.Offset+d.X,frameStart.Y.Scale,frameStart.Y.Offset+d.Y)
    end
end)
track(UIS.InputEnded,function(input)
    if input==dragRef then dragging,dragRef=false,nil end
end)

env.NeXLuaTapCompareStop=function()
    S.alive=false
    S.armed=false
    for _,conn in ipairs(S.connections) do pcall(function() conn:Disconnect() end) end
    pcall(function() gui:Destroy() end)
end
print("[NeXLua V15] Two real mobile taps diagnostic loaded; no clicks or remote replay.")
