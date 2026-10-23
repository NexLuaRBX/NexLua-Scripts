-- NeXLua Hub | Auto Stop V16 | DYNAMIC ARGUMENT DIAGNOSTIC
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

if type(env.NeXLuaArgDiffStop) == "function" then pcall(env.NeXLuaArgDiffStop) end
local previous = pg:FindFirstChild("NeXLua_ArgDiff_V16")
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
gui.Name="NeXLua_ArgDiff_V16"
gui.ResetOnSpawn=false
-- Do not mark IgnoreGuiInset=true on mobile: touch positions are aligned with the game.
gui.DisplayOrder=4000
gui.Parent=pg
local panel=Instance.new("Frame")
panel.Size=UDim2.fromOffset(332,301)
panel.Position=UDim2.new(1,-343,0.22,0)
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
text("NeXLua Hub | ARGUMENT CHECK",7,23,14,color(52,231,113))
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
local st1=text("Ready: sit at your table first.",101,34,11)
local st2=text("Tap 1: --",137,22,10,color(161,201,173))
local st3=text("Tap 2: --",159,22,10,color(161,201,173))
local st4=text("No input will be simulated.",184,25,10,color(95,233,137))
local st5=text("Changed data type: --",211,24,10,color(177,229,190))
local st6=text("Differences: --",236,26,10,color(177,229,190))
local st7=text("Value/bytes: --",264,30,10,color(177,229,190))

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
-- Snapshot only the first argument, which V15 found to be different.
-- Values remain local to the game session; there is no network upload or replay.
local function snapshotFirst(v)
    local kind=typeof(v)
    local result={kind=kind}
    if kind=="buffer" then
        local ok,n=pcall(buffer.len,v)
        if not ok then result.note="BUFFER READ FAILED";return result end
        result.n=n
        local data={}
        local cap=math.min(n,4096)
        for i=0,cap-1 do
            local readOK,b=pcall(buffer.readu8,v,i)
            if not readOK then break end
            data[#data+1]=b
        end
        result.bytes=data
        result.truncated=n>cap
    elseif kind=="string" then
        result.n=#v
        local data={}
        for i=1,math.min(#v,4096) do data[#data+1]=v:byte(i) end
        result.bytes=data
        result.truncated=#v>4096
    elseif kind=="number" or kind=="boolean" or kind=="nil" then
        result.value=v
    elseif kind=="Instance" then
        local ok,p=pcall(function()return v:GetFullName()end)
        result.value=ok and p or tostring(v)
    else
        -- Tables are represented only by the structural fingerprint.
        -- Never serialise arbitrary userdata or session objects into UI strings.
        local ok,sign=pcall(signature,v,0)
        result.value=ok and sign or kind
    end
    return result
end
local function describeArg(a,b)
    if not a or not b then return "ARG1: not captured","DIFF: unavailable","VALUES: unavailable" end
    if a.kind~=b.kind then
        return "ARG1 TYPES: "..a.kind.." / "..b.kind,"DIFF: type changed","VALUES: see current args"
    end
    local kind=a.kind
    if kind=="buffer" or kind=="string" then
        local n1,n2=a.n or 0,b.n or 0
        local d1,d2=a.bytes or {},b.bytes or {}
        local limit=math.min(#d1,#d2)
        local changed,examples={},{}
        local num=0
        for i=1,limit do
            if d1[i]~=d2[i] then
                num=num+1
                if #changed<8 then changed[#changed+1]=tostring(i) end
                if #examples<4 then examples[#examples+1]=string.format("%d:%02X>%02X",i,d1[i],d2[i]) end
            end
        end
        if n1~=n2 then num=num+math.abs(n1-n2) end
        local suffix=(a.truncated or b.truncated) and " (first 4KB only)" or ""
        return string.upper(kind).." | bytes "..n1.." / "..n2,
            "CHANGED: "..num.." | POS: "..(#changed>0 and table.concat(changed,",") or "none")..suffix,
            "HEX CHANGES: "..(#examples>0 and table.concat(examples,"  ") or "none")
    end
    local function describe(v)
        if v==nil then return "nil" end
        local s=tostring(v)
        return #s>68 and s:sub(1,65).."..." or s
    end
    local v1,v2=describe(a.value),describe(b.value)
    local caption=string.upper(kind).." (argument 1)"
    if kind=="number" then
        local delta=(b.value or 0)-(a.value or 0)
        return caption,"NUMBER DELTA: "..string.format("%.6g",delta),"VALUES: "..v1.." -> "..v2
    end
    return caption,"ARG1 SIGNATURE "..(v1==v2 and "SAME" or "CHANGED"),"VALUES: "..v1.." -> "..v2
end

local function captureArgs(...)
    local count=select("#",...)
    local sign={}
    for i=1,math.min(count,12) do
        local v=select(i,...)
        local ok,result=pcall(signature,v,0)
        sign[#sign+1]=ok and result or "arg:error"
    end
    local first
    if count>=1 then
        local ok,probe=pcall(snapshotFirst,select(1,...))
        first=ok and probe or {kind="unknown",value="snapshot error"}
    end
    return count,sign,first
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
                    local okArgs,n,args,first=pcall(captureArgs,...)
                    S.recent[#S.recent+1]={at=now,remote=self,method=method,count=okArgs and n or -1,args=okArgs and args or {"unreadable"},first=okArgs and first or nil}
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
    st5.Text="Changed data type: --"
    st6.Text="Differences: --"
    st7.Text="Value/bytes: --"
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
            local a,b=S.captures[1],S.captures[2]
            if a and b and a.remote==b.remote and a.method==b.method then
                st5.Text,st6.Text,st7.Text=describeArg(a.first,b.first)
            else
                st5.Text="Argument types unavailable"
                st6.Text="Did not capture same action twice"
                st7.Text="Run test again if needed"
            end
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

env.NeXLuaArgDiffStop=function()
    S.alive=false
    S.armed=false
    for _,conn in ipairs(S.connections) do pcall(function() conn:Disconnect() end) end
    pcall(function() gui:Destroy() end)
end
print("[NeXLua V16] Argument difference diagnostic loaded; no clicks or remote replay.")
