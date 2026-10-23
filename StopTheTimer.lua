-- NeXLua Hub | Auto Stop V13 | MOBILE TAP LEARN + V9 PC CORE
-- Blind Estimate stays ON exactly as in the original V7.
-- Appearance: compact English NeXLua menu, YouTube and latency correction.
-- No extra timers or modified trigger conditions.

-- AUTO STOP TIMER V7 | DETECCION DESDE EL PRIMER TURNO
-- Adaptado al informe aportado por el usuario: GameStations/.../Buttons/PlayerN/Button
-- y Timer/PlayerN/SurfaceGui/TimerText; GameUI.SecondsToSet.
-- No probado dentro del juego: no se garantiza precision ni aceptacion de clics.
-- MESA: toma la mesa real de Humanoid.SeatPart u Occupant; como respaldo,
-- compara distancias con suficiente separacion; tambien aprende de un clic manual.
-- BLOQUEO: despues de encontrar tu sitio NUNCA lee el reloj de otra mesa.
-- PRIMER TURNO: observa TU reloj ANTES de que aparezca el aviso.
-- Un reloj que sube permite reengancharse incluso si la ronda ya empezo.
-- BLIND: lee Text aunque SurfaceGui.Enabled=false; si se congela,
-- extrapola desde el ultimo dato; sin datos usa un retraso aproximado.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()
local env = (type(getgenv) == "function" and getgenv()) or _G

for _, k in ipairs({"AutoStopTimerCleanup", "AutoStopV4Cleanup", "AutoStopV5Cleanup", "AutoStopV6Cleanup", "AutoStopV7Cleanup", "NeXLuaAutoStopCleanup", "AutoStopCleanup", "StopTimerDiagCleanup"}) do
    if type(env[k]) == "function" then pcall(env[k]) end
end

local conns, timerConn = {}, nil
local active, blindEstimate, pressed = false, true, false
local correctionMs = 0
local station, side, buttonPart, timerLabel = nil, nil, nil, nil
local stationSource, selectionPending, selectionSince = "--", nil, 0
local lastManual = nil
local myTurn, turnAt, goal, epoch = false, nil, nil, nil
local lastTimerValue, lastTimerAt, timeSource = nil, nil, "--"
-- Sensor permanente del reloj de TU asiento, independiente del aviso de turno.
local rawValue, rawAt, sensorEpoch, sensorMoves, sensorMoveAt = nil, nil, nil, 0, nil
local turnSource = "--"
local calibratedThisRound = false
local lastClick = "Sin clic"
local startupDelay = tonumber(env.AutoStopV6Delay) or 3.22
local delaySamples = tonumber(env.AutoStopV6Samples) or 0
local lastUI, lastScan, lastBind = 0, 0, 0
local gui

local function charParts()
    local c = player.Character
    if not c then return nil, nil, nil end
    return c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart"), c
end

local function guiVisible(obj)
    if not obj or not obj.Parent then return false end
    local p = obj
    while p and p ~= pg and p ~= Workspace do
        if p:IsA("GuiObject") and not p.Visible then return false end
        if p:IsA("LayerCollector") and not p.Enabled then return false end
        p = p.Parent
    end
    return true
end

local function getGameUI()
    return pg:FindFirstChild("GameUI")
end

local function parseNumber(s)
    s = tostring(s or ""):gsub("<[^>]->", ""):gsub(",", ".")
    local n = tonumber(s:match("([%d]+%.?[%d]*)"))
    if n and n >= 0 and n <= 60 then return n end
end

local function readGoal()
    local ui = getGameUI()
    if not ui or not guiVisible(ui) then return nil end
    local o = ui:FindFirstChild("SecondsToSet", true)
    if not o then return nil end
    local n
    if o:IsA("TextLabel") or o:IsA("TextButton") then
        n = parseNumber(o.Text)
    elseif o:IsA("NumberValue") or o:IsA("IntValue") then
        n = tonumber(o.Value)
    end
    return (n and n > 0 and n <= 30) and n or nil
end

local function turnNotice()
    local ui = getGameUI()
    if not ui or not guiVisible(ui) then return false end
    local ours, theirs = false, false
    for _, item in ipairs(pg:GetDescendants()) do
        if (item:IsA("TextLabel") or item:IsA("TextButton")) and guiVisible(item) then
            local txt = tostring(item.Text):upper():gsub("<[^>]->", "")
            txt = txt:gsub("[^%w%s]", " "):gsub("%s+", " ")
            if txt:find("OPPONENT S TURN", 1, true)
                or txt:find("OPPONENTS TURN", 1, true)
                or txt:find("OPPONENT TURN", 1, true) then
                theirs = true
            elseif txt:find("YOUR TURN", 1, true)
                or txt:find("ITS YOUR TURN", 1, true) then
                ours = true
            end
        end
    end
    if theirs then return false end
    if ours then return true end
    -- Ausencia de aviso != confirmacion del siguiente turno.
    return nil
end

local function findButtons(st)
    local bs = st:FindFirstChild("Buttons")
    local p1 = bs and bs:FindFirstChild("Player1")
    local p2 = bs and bs:FindFirstChild("Player2")
    local b1 = p1 and p1:FindFirstChild("Button")
    local b2 = p2 and p2:FindFirstChild("Button")
    if b1 and b1:IsA("BasePart") and b2 and b2:IsA("BasePart") then
        return b1, b2
    end
    return nil, nil
end

local function gameStations()
    local root = Workspace:FindFirstChild("GameStations")
    local result = {}
    if not root then return result end
    for _, inst in ipairs(root:GetDescendants()) do
        if inst.Name == "Buttons" and inst.Parent then
            local st = inst.Parent
            local a, b = findButtons(st)
            if a and b then
                result[#result + 1] = {st = st, b1 = a, b2 = b}
            end
        end
    end
    return result
end

local function seatSide(seat, pair)
    local node = seat
    while node and node ~= pair.st do
        if node.Name == "Player1" then return "Player1" end
        if node.Name == "Player2" then return "Player2" end
        node = node.Parent
    end
    local d1 = (seat.Position - pair.b1.Position).Magnitude
    local d2 = (seat.Position - pair.b2.Position).Magnitude
    if math.abs(d1 - d2) >= 1.0 then
        return d1 < d2 and "Player1" or "Player2"
    end
    return nil
end

local function getCandidate(pairs)
    local humanoid, root = charParts()
    if not humanoid or not root then return nil end
    local seat = humanoid.SeatPart

    -- Fuente de mayor confianza: SeatPart / Seat.Occupant, si son descendientes de una mesa.
    for _, pair in ipairs(pairs) do
        if seat and seat:IsDescendantOf(pair.st) then
            local which = seatSide(seat, pair)
            if which then
                return {st = pair.st, side = which, button = which == "Player1" and pair.b1 or pair.b2, why = "SILLA"}
            end
        end
        for _, child in ipairs(pair.st:GetDescendants()) do
            if (child:IsA("Seat") or child:IsA("VehicleSeat"))
                and child.Occupant == humanoid then
                local which = seatSide(child, pair)
                if which then
                    return {st = pair.st, side = which, button = which == "Player1" and pair.b1 or pair.b2, why = "OCUPANTE"}
                end
            end
        end
    end

    -- Si ya pulsaste manualmente, esa pieza identifica el lado real sin calibracion especial.
    if lastManual and os.clock() - lastManual.at <= 90 then
        local b = lastManual.button
        if b and b.Parent and (root.Position - b.Position).Magnitude < 24 then
            return {st = lastManual.st, side = lastManual.side, button = b, why = "CLIC MANUAL"}
        end
    end

    -- Ultimo recurso: distancia del personaje a los botones de TODAS las mesas.
    -- Requiere cercania y margen frente a la segunda opcion; no adivina si es ambiguo.
    local best, second = nil, math.huge
    for _, pair in ipairs(pairs) do
        for i, b in ipairs({pair.b1, pair.b2}) do
            local d = (root.Position - b.Position).Magnitude
            if not best or d < best.dist then
                second = best and best.dist or math.huge
                best = {st = pair.st, side = "Player" .. i, button = b, why = "CERCANIA", dist = d}
            elseif d < second then
                second = d
            end
        end
    end
    if best and best.dist <= 13 and second - best.dist >= 2.5 then
        return best
    end
    return nil
end

local function resetTiming()
    epoch, lastTimerValue, lastTimerAt, timeSource = nil, nil, nil, "--"
    pressed = false
    -- NO borrar el sensor: podria llevar contando el primer turno antes del aviso.
end

-- Llamado aunque la GUI aun no haya anunciado "YOUR TURN".
-- NO consulta relojes de otras mesas: solo el TimerText ligado a station/side.
local function acceptTime(n, now)
    if not station or not timerLabel or not n or n < 0 or n > 45 then return end
    if rawValue ~= nil then
        local dv = n - rawValue
        local dt = now - (rawAt or now)
        if dv < -0.45 then
            -- El contador se reinicio: nunca arrastrar el tiempo de la ronda anterior.
            sensorMoves, sensorEpoch, sensorMoveAt = 0, nil, nil
            epoch = nil
            if myTurn then pressed = false end
        elseif dv >= 0.009 and dv <= dt + 0.35 and dt > 0 then
            if sensorMoveAt and now - sensorMoveAt > 0.6 then
                sensorMoves = 0
            end
            sensorMoves = math.min(sensorMoves + 1, 10)
            sensorMoveAt = now
            sensorEpoch = now - n
            -- Dos cambios crecientes validan un reloj activo; incluso si lo
            -- detectamos ya por 3, 4 o 7 segundos, no exigimos empezar en cero.
            if myTurn and goal and not pressed and sensorMoves >= 2 then
                if not calibratedThisRound and turnAt and turnSource == "AVISO" and n <= 2.5 then
                    local delay = sensorEpoch - turnAt
                    if delay >= 0.6 and delay <= 6.5 then
                        startupDelay = (delaySamples == 0) and delay or startupDelay * 0.72 + delay * 0.28
                        delaySamples = math.min(delaySamples + 1, 100)
                        env.AutoStopV6Delay, env.AutoStopV6Samples = startupDelay, delaySamples
                        calibratedThisRound = true
                    end
                end
                if not epoch or math.abs((now - epoch) - n) > 0.3 then
                    epoch = sensorEpoch
                else
                    epoch = epoch * 0.80 + sensorEpoch * 0.20
                end
                timeSource = "RELOJ REAL"
            end
            lastTimerValue, lastTimerAt = n, now
        end
    end
    if rawValue ~= n then
        rawValue, rawAt = n, now
    end
end

local function bindClock()
    if timerConn then timerConn:Disconnect() timerConn = nil end
    timerLabel = nil
    resetTiming()
    rawValue, rawAt, sensorEpoch, sensorMoves, sensorMoveAt = nil, nil, nil, 0, nil
    if not station or not side then return end
    local t = station:FindFirstChild("Timer")
    local p = t and t:FindFirstChild(side)
    local sf = p and p:FindFirstChild("SurfaceGui", true)
    local label = sf and sf:FindFirstChild("TimerText", true)
    if label and label:IsA("TextLabel") then
        timerLabel = label
        timerConn = label:GetPropertyChangedSignal("Text"):Connect(function()
            acceptTime(parseNumber(label.Text), os.clock())
        end)
        acceptTime(parseNumber(label.Text), os.clock())
    end
end

local function assign(candidate)
    local changed = candidate and (station ~= candidate.st or side ~= candidate.side)
    if not candidate then
        if station then
            station, side, buttonPart, stationSource = nil, nil, nil, "--"
            bindClock()
        end
        return
    end
    station, side, buttonPart, stationSource = candidate.st, candidate.side, candidate.button, candidate.why
    if changed or (not timerLabel or not timerLabel.Parent) then bindClock() end
end

local function holdingValid()
    local _, root = charParts()
    if not station or not buttonPart or not buttonPart.Parent or not root then return false end
    return (root.Position - buttonPart.Position).Magnitude <= 25
end

local function scanBinding(now)
    local candidate = getCandidate(gameStations())
    if station and not holdingValid() then assign(nil) end
    if not candidate then
        selectionPending = nil
        return
    end
    if station == candidate.st and side == candidate.side then
        stationSource = candidate.why
        selectionPending = nil
        return
    end
    -- Nunca saltar de mesa por un movimiento del personaje EN PLENA RONDA.
    if station and myTurn and holdingValid()
        and candidate.why ~= "SILLA" and candidate.why ~= "OCUPANTE" then return end
    local key = candidate.st:GetFullName() .. "/" .. candidate.side
    if candidate.why == "SILLA" or candidate.why == "OCUPANTE" then
        assign(candidate)
        selectionPending = nil
        return
    end
    if selectionPending ~= key then
        selectionPending = key
        selectionSince = now
    elseif now - selectionSince >= (myTurn and 0.18 or 0.40) then
        assign(candidate)
        selectionPending = nil
    end
end

local function pointForButton()
    if not station or not buttonPart or not buttonPart.Parent then return nil, nil, "SIN BOTON PROPIO" end
    local cam = Workspace.CurrentCamera
    if not cam then return nil, nil, "SIN CAMARA" end
    local v, visible = cam:WorldToViewportPoint(buttonPart.Position)
    if not visible or v.Z <= 0 then return nil, nil, "BOTON FUERA DE PANTALLA" end
    local inset = Vector2.new(0, 0)
    pcall(function() inset = GuiService:GetGuiInset() end)
    return math.floor(v.X + inset.X), math.floor(v.Y + inset.Y), "PIEZA " .. side
end

-- =============================================================
-- MOBILE: learn the game-originated remote from ONE REAL touch.
-- No fake PC/touch input is sent on phones. The recorder never
-- uploads or saves recorded arguments outside this game session.
-- PC click implementation below remains the unchanged V9 path.
-- =============================================================
local mobileSpy = env.NeXLuaAutoStopMobileSpy
if type(mobileSpy) ~= "table" then
    mobileSpy = {}
    env.NeXLuaAutoStopMobileSpy = mobileSpy
end
mobileSpy.pending = nil
mobileSpy.armed = false
mobileSpy.learned = nil
mobileSpy.lastStatus = "LEARN MOBILE TAP FIRST"
local learnStatusLabel = nil
local function learnStatus(msg)
    mobileSpy.lastStatus = msg
    if learnStatusLabel then learnStatusLabel.Text = msg end
end

-- Hook once; re-execution reuses the same capture router.
local function prepareCaptureHook()
    if mobileSpy.installed then return true end
    local hook = env.hookmetamethod or hookmetamethod
    local getMethod = env.getnamecallmethod or getnamecallmethod
    local makeClosure = env.newcclosure or newcclosure
    if type(hook) ~= "function" or type(getMethod) ~= "function" then
        return false, "DELTA: REMOTE CAPTURE NOT AVAILABLE"
    end
    local ok, err = pcall(function()
        local original
        local listener = function(self, ...)
            local p = mobileSpy.pending
            if p and os.clock() - p.started < 0.85 and #p.calls < 50 then
                local method = getMethod()
                if (method == "FireServer" or method == "InvokeServer")
                    and typeof(self) == "Instance" then
                    local class = self.ClassName
                    if class == "RemoteEvent" or class == "UnreliableRemoteEvent"
                        or class == "RemoteFunction" then
                        p.calls[#p.calls + 1] = {
                            remote = self, method = method,
                            args = table.pack(...), elapsed = os.clock() - p.started
                        }
                    end
                end
            end
            return original(self, ...)
        end
        original = hook(game, "__namecall",
            type(makeClosure) == "function" and makeClosure(listener) or listener)
        mobileSpy.installed = true
    end)
    if not ok then return false, "CAPTURE HOOK ERROR: " .. tostring(err):sub(1, 55) end
    return true
end

local function candidateScore(c, ownerSide, st, ownPart)
    local n = string.lower(c.remote.Name or "")
    local parentName = c.remote.Parent and string.lower(c.remote.Parent.Name) or ""
    local s = n .. " " .. parentName
    local score = 0
    if s:find("stop") or s:find("button") or s:find("press")
        or s:find("click") or s:find("timer") or s:find("interact") then
        score = score + 12
    elseif s:find("action") or s:find("event") then
        score = score + 2
    end
    if s:find("chat") or s:find("ping") or s:find("heartbeat") then score = score - 10 end
    for i = 1, c.args.n do
        local v = c.args[i]
        if v == st or v == ownPart then score = score + 8 end
        if type(v) == "string" then
            local lower = string.lower(v)
            if lower == string.lower(ownerSide or "") then score = score + 8 end
            if lower:find("stop", 1, true) or lower:find("button", 1, true)
                or lower:find("press", 1, true) then score = score + 8 end
        end
    end
    return score
end

local function finishMobileCapture(p)
    if mobileSpy.pending ~= p then return end
    mobileSpy.pending = nil
    if #p.calls == 0 then
        learnStatus("NO REMOTE SEEN - POSSIBLE SERVER CLICKDETECTOR")
        return
    end
    local best, bestScore, distinct = nil, -999, {}
    for _, event in ipairs(p.calls) do
        local key = tostring(event.remote) .. ":" .. event.method
        distinct[key] = true
        local score = candidateScore(event, p.side, p.station, p.button)
        if score > bestScore then
            best, bestScore = event, score
        end
    end
    local total = 0
    for _ in pairs(distinct) do total = total + 1 end
    -- One unique remote is unambiguous. Multiple generic remotes are not.
    if total > 1 and bestScore < 8 then
        learnStatus("FOUND " .. total .. " REMOTES - CANNOT IDENTIFY BUTTON")
        return
    end
    mobileSpy.learned = {
        remote = best.remote, method = best.method, args = best.args,
        station = p.station, side = p.side
    }
    learnStatus("LEARNED: " .. best.remote.Name:sub(1, 23)
        .. " (UNVERIFIED)")
end

local function mobileTouchNearOwnButton(input)
    if not mobileSpy.armed or os.clock() > (mobileSpy.deadline or 0) then return end
    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    if not station or not side or not buttonPart or not buttonPart.Parent then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local projected, visible = cam:WorldToViewportPoint(buttonPart.Position)
    if not visible or projected.Z <= 0 then return end
    local xy = Vector2.new(input.Position.X, input.Position.Y)
    local v = Vector2.new(projected.X, projected.Y)
    local inset = Vector2.new(0, 0)
    pcall(function() inset = GuiService:GetGuiInset() end)
    local distance = math.min((xy - v).Magnitude, (xy - v - inset).Magnitude)
    if distance > 105 then return end
    mobileSpy.armed = false
    local p = {
        started = os.clock(), calls = {},
        station = station, side = side, button = buttonPart
    }
    mobileSpy.pending = p
    learnStatus("RECORDING MANUAL TAP...")
    -- This tap is the user's genuine action. Do not issue another click.
    if myTurn then
        pressed = true
        lastClick = "MANUAL TOUCH/" .. side
    end
    task.delay(1.05, function() finishMobileCapture(p) end)
end
conns[#conns + 1] = UIS.InputBegan:Connect(mobileTouchNearOwnButton)

local function clickOwnButton()
    if UIS.TouchEnabled then
        local learned = mobileSpy.learned
        if not learned then return false, "TAP LEARNING REQUIRED" end
        if learned.station ~= station or learned.side ~= side then
            return false, "TABLE/SIDE CHANGED - LEARN AGAIN"
        end
        if not learned.remote or not learned.remote.Parent then
            return false, "REMOTE EXPIRED - LEARN AGAIN"
        end
        local ok, err = pcall(function()
            if learned.method == "FireServer" then
                learned.remote:FireServer(table.unpack(learned.args, 1, learned.args.n))
            elseif learned.method == "InvokeServer" then
                learned.remote:InvokeServer(table.unpack(learned.args, 1, learned.args.n))
            end
        end)
        if ok then
            learnStatus("REMOTE SENT: " .. learned.remote.Name:sub(1, 22)
                .. " (UNCONFIRMED)")
            return true, "LEARNED REMOTE (UNCONFIRMED)"
        end
        learnStatus("REMOTE ERROR: " .. tostring(err):sub(1, 40))
        return false, "REMOTE REJECTED"
    end
    local x, y, method = pointForButton()
    if not x then return false, method end
    -- VirtualInputManager primero: mueve y pulsa en las coordenadas del boton de TU lado.
    local ok = pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendMouseMoveEvent(x, y, game)
        vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
        vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    if ok then return true, "VIM/" .. method end
    if type(mousemoveabs) == "function" and type(mouse1click) == "function" then
        local moved = pcall(mousemoveabs, x, y)
        if moved and pcall(mouse1click) then return true, "mouse1click/" .. method end
    end
    return false, "EXECUTOR NO PERMITE CLIC"
end

local function setTurn(newTurn, now, why)
    if newTurn == true and not myTurn then
        myTurn, turnAt = true, now
        goal = nil -- nunca heredar objetivo de otra ronda
        calibratedThisRound = false
        resetTiming()
        turnSource = why or "GUI"
        -- Si el reloj ya estaba aumentando ANTES del aviso, recuperar el inicio.
        if sensorEpoch and sensorMoves >= 2 and sensorMoveAt
            and now - sensorMoveAt < 0.35 then
            epoch = sensorEpoch
            timeSource = "RELOJ REAL (INICIO RECUPERADO)"
        end
    elseif newTurn == false and myTurn then
        myTurn, turnAt, goal = false, nil, nil
        turnSource = "--"
        resetTiming()
    end
end

-- Aprender automaticamente del clic manual sobre Buttons.PlayerN.Button.
conns[#conns + 1] = UIS.InputBegan:Connect(function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local target = mouse.Target
    if not target or target.Name ~= "Button" then return end
    local seat = target.Parent
    local buttons = seat and seat.Parent
    local st = buttons and buttons.Parent
    if not st or not buttons or buttons.Name ~= "Buttons" or not seat then return end
    if seat.Name ~= "Player1" and seat.Name ~= "Player2" then return end
    local root = select(2, charParts())
    if not root or (root.Position - target.Position).Magnitude > 25 then return end
    lastManual = {st = st, side = seat.Name, button = target, at = os.clock()}
    -- No enviar un segundo clic si el usuario pulso manualmente en su ronda.
    if myTurn and station == st and side == seat.Name then
        pressed = true
        lastClick = "MANUAL/" .. seat.Name
    end
end)

-- =============================================================
-- NeXLua Hub | Auto Stop (compact, English)
-- Based on the original AutoStopTimer V7 detection and timing.
-- Blind Estimate is permanently ON; there is no toggle.
-- =============================================================
local CHANNEL_URL = "https://www.youtube.com/@NexLuaRBX"
local C = {
    panel = Color3.fromRGB(12, 17, 17),
    dark = Color3.fromRGB(23, 34, 32),
    border = Color3.fromRGB(39, 159, 79),
    green = Color3.fromRGB(49, 237, 111),
    white = Color3.fromRGB(242, 250, 243),
    muted = Color3.fromRGB(157, 185, 165),
    red = Color3.fromRGB(114, 45, 56),
}

local function corners(inst, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = inst
end
local function stroke(inst, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = 0.18
    s.Parent = inst
end
local function notify(message)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NeXLua Hub", Text = message, Duration = 4
        })
    end)
end
local function visitChannel()
    local launched = false
    -- A browser launcher is not available in every executor.
    for _, name in ipairs({"openurl", "open_url", "openbrowser", "open_browser"}) do
        local f = env[name]
        if type(f) == "function" then
            local ok = pcall(f, CHANNEL_URL)
            if ok then launched = true break end
        end
    end
    if not launched then
        local copy = env.setclipboard or setclipboard or env.toclipboard
        if type(copy) == "function" then
            pcall(copy, CHANNEL_URL)
            notify("Channel link copied. Paste it into your browser.")
        else
            notify("Visit youtube.com/@NexLuaRBX")
        end
    end
end

-- Original avatar embedded; a 16x16 image built from UI pixels is fallback.
local avatarSource
local AVATAR_ASSET_ID = 0 -- Replace with an uploaded Roblox image ID, if available.
if AVATAR_ASSET_ID > 0 then
    avatarSource = "rbxassetid://" .. tostring(AVATAR_ASSET_ID)
else
    local writer = env.writefile or writefile
    local asset = env.getcustomasset or env.getsynasset or getcustomasset or getsynasset
    if type(writer) == "function" and type(asset) == "function" then
        pcall(function()
            local b64 = [[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]]
            local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            local decoded, chunk, bits = {}, 0, 0
            for i = 1, #b64 do
                local char = b64:sub(i, i)
                local n = alphabet:find(char, 1, true)
                if n then
                    chunk = chunk * 64 + n - 1
                    bits = bits + 6
                    if bits >= 8 then
                        bits = bits - 8
                        local div = 2 ^ bits
                        local byte = math.floor(chunk / div)
                        decoded[#decoded + 1] = string.char(byte)
                        chunk = chunk % div
                    end
                end
            end
            local path = "NeXLua_Avatar_Logo.jpg"
            writer(path, table.concat(decoded))
            avatarSource = asset(path)
        end)
    end
end
local LOGO_PALETTE = {"86DE5B", "51B236", "488E35", "248219", "346A26", "226519", "1C5316", "0F3F0B", "0D320B", "082806", "061E05", "031803", "031303", "010B01", "010501", "010101"}
local LOGO_PIXELS = {
    "EFFA4C3111116DEE",
    "DFB65520000039FF",
    "F9347264211011AF",
    "974486537445401B",
    "BC44C767A5262103",
    "EE54789966892310",
    "DA2456C67A855430",
    "A7316858A8531430",
    "44316E389C413910",
    "8F857DFDDD237301",
    "DDCB98EEE6137107",
    "9DE985C8CCA46335",
    "BEF99AB8867AAAB2",
    "BBE99CCCB9754574",
    "BBDDA8ACBBED8751",
    "BFEDDDBADCBEBEBA",
}

local g = Instance.new("ScreenGui")
g.Name = "NeXLua_AutoStop_Hub"
g.ResetOnSpawn = false
g.IgnoreGuiInset = true
g.DisplayOrder = 950
g.Parent = pg
gui = g

local frame = Instance.new("Frame")
frame.Name = "CompactHub"
frame.Size = UDim2.fromOffset(284, UIS.TouchEnabled and 224 or 161)
frame.Position = UDim2.new(1, -300, .25, 0)
frame.BackgroundColor3 = C.panel
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = g
corners(frame, 12)
stroke(frame, C.border)

local avatar = Instance.new("Frame")
avatar.Position = UDim2.fromOffset(9, 7)
avatar.Size = UDim2.fromOffset(42, 42)
avatar.BackgroundColor3 = C.dark
avatar.BorderSizePixel = 0
avatar.ClipsDescendants = true
avatar.Parent = frame
corners(avatar, 21)
stroke(avatar, C.green)
local logoColors = {}
for i, code in ipairs(LOGO_PALETTE) do
    logoColors[i] = Color3.fromRGB(
        tonumber(code:sub(1,2),16),
        tonumber(code:sub(3,4),16),
        tonumber(code:sub(5,6),16)
    )
end
for y, line in ipairs(LOGO_PIXELS) do
    for x=1,16 do
        local pixel = Instance.new("Frame")
        pixel.Size = UDim2.new(1/16, 0, 1/16, 0)
        pixel.Position = UDim2.fromScale((x-1)/16, (y-1)/16)
        pixel.BorderSizePixel = 0
        pixel.BackgroundColor3 = logoColors[(tonumber(line:sub(x,x),16) or 0)+1]
        pixel.Parent = avatar
    end
end
if avatarSource then
    local picture = Instance.new("ImageLabel")
    picture.Size = UDim2.fromScale(1, 1)
    picture.BackgroundTransparency = 1
    picture.Image = avatarSource
    picture.ScaleType = Enum.ScaleType.Crop
    picture.Visible = false
    picture.Parent = avatar
    pcall(function()
        picture.Visible = picture.IsLoaded
        local c = picture:GetPropertyChangedSignal("IsLoaded"):Connect(function()
            picture.Visible = picture.IsLoaded
        end)
        table.insert(conns, c)
    end)
end

local title = Instance.new("TextLabel")
title.Size = UDim2.fromOffset(160, 25)
title.Position = UDim2.fromOffset(58, 6)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "NeXLua Hub"
title.TextSize = 17
title.TextColor3 = C.white
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local channel = Instance.new("TextButton")
channel.Position = UDim2.fromOffset(58, 31)
channel.Size = UDim2.fromOffset(157, 16)
channel.BackgroundTransparency = 1
channel.Font = Enum.Font.Gotham
channel.Text = "YouTube: @NexLuaRBX  >"
channel.TextSize = 10
channel.TextXAlignment = Enum.TextXAlignment.Left
channel.TextColor3 = C.green
channel.Parent = frame
conns[#conns+1] = channel.MouseButton1Click:Connect(visitChannel)

local function smallHeaderButton(txt, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(23, 23)
    b.Position = UDim2.fromOffset(x, 13)
    b.BackgroundColor3 = C.dark
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = C.muted
    b.TextSize = 14
    b.Parent = frame
    corners(b, 6)
    return b
end
local minimize = smallHeaderButton("-", 231)
local close = smallHeaderButton("X", 257)

local separator = Instance.new("Frame")
separator.Position = UDim2.fromOffset(8, 55)
separator.Size = UDim2.fromOffset(268, 1)
separator.BorderSizePixel = 0
separator.BackgroundColor3 = C.border
separator.BackgroundTransparency = 0.5
separator.Parent = frame

local controls = Instance.new("Frame")
controls.Position = UDim2.fromOffset(0, 57)
controls.Size = UDim2.fromOffset(284, UIS.TouchEnabled and 166 or 102)
controls.BackgroundTransparency = 1
controls.Parent = frame

local function action(txt, x, y, w, h)
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x, y)
    b.Size = UDim2.fromOffset(w, h)
    b.BorderSizePixel = 0
    b.BackgroundColor3 = C.dark
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = C.white
    b.TextSize = 14
    b.Parent = controls
    corners(b, 8)
    return b
end
local toggle = action("AUTO STOP: OFF", 10, 2, 264, 43)
local minus = action("-5 ms", 10, 52, 89, 40)
local plus = action("+5 ms", 185, 52, 89, 40)

-- Mobile-only training control. Requires one manual red-button press.
local learnTap = action("LEARN MOBILE TAP", 10, 100, 264, 28)
learnTap.TextSize = 12
learnTap.Visible = UIS.TouchEnabled
learnStatusLabel = Instance.new("TextLabel")
learnStatusLabel.Position = UDim2.fromOffset(10, 132)
learnStatusLabel.Size = UDim2.fromOffset(264, 25)
learnStatusLabel.BackgroundTransparency = 1
learnStatusLabel.Font = Enum.Font.Gotham
learnStatusLabel.Text = mobileSpy.lastStatus
learnStatusLabel.TextColor3 = C.muted
learnStatusLabel.TextSize = 10
learnStatusLabel.TextWrapped = true
learnStatusLabel.TextXAlignment = Enum.TextXAlignment.Center
learnStatusLabel.Parent = controls
learnStatusLabel.Visible = UIS.TouchEnabled

local offsetLine = Instance.new("TextLabel")
offsetLine.Position = UDim2.fromOffset(102, 55)
offsetLine.Size = UDim2.fromOffset(80, 35)
offsetLine.BackgroundTransparency = 1
offsetLine.TextColor3 = C.green
offsetLine.Font = Enum.Font.GothamBold
offsetLine.TextSize = 12
offsetLine.Text = "0 ms"
offsetLine.Parent = controls

local function paintToggle()
    toggle.Text = active and "AUTO STOP: ON" or "AUTO STOP: OFF"
    toggle.BackgroundColor3 = active and Color3.fromRGB(23, 130, 63) or C.dark
    toggle.TextColor3 = active and C.white or C.muted
end
local function paintOffset()
    offsetLine.Text = string.format("%+d ms", correctionMs)
end
paintToggle()
paintOffset()

conns[#conns+1] = toggle.MouseButton1Click:Connect(function()
    active = not active
    paintToggle()
end)
conns[#conns + 1] = learnTap.Activated:Connect(function()
    local ok, reason = prepareCaptureHook()
    if not ok then learnStatus(reason) return end
    active = false -- manual calibration must never race the auto press
    paintToggle()
    mobileSpy.learned = nil
    mobileSpy.pending = nil
    mobileSpy.armed = true
    mobileSpy.deadline = os.clock() + 25
    learnStatus("NOW TAP YOUR RED BUTTON ONCE")
    task.delay(25, function()
        if mobileSpy.armed then
            mobileSpy.armed = false
            learnStatus("LEARN TIMEOUT - TRY AGAIN")
        end
    end)
end)
conns[#conns+1] = minus.MouseButton1Click:Connect(function()
    correctionMs = math.clamp(correctionMs - 5, -150, 150)
    paintOffset()
end)
conns[#conns+1] = plus.MouseButton1Click:Connect(function()
    correctionMs = math.clamp(correctionMs + 5, -150, 150)
    paintOffset()
end)

local minimized = false
conns[#conns+1] = minimize.MouseButton1Click:Connect(function()
    minimized = not minimized
    controls.Visible = not minimized
    separator.Visible = not minimized
    frame.Size = UDim2.fromOffset(284, minimized and 56 or (UIS.TouchEnabled and 224 or 161))
    minimize.Text = minimized and "+" or "-"
end)
conns[#conns+1] = close.MouseButton1Click:Connect(function()
    if type(env.AutoStopV7Cleanup) == "function" then
        env.AutoStopV7Cleanup()
    end
end)

-- Legacy V7 status fields are deliberately kept as lightweight, hidden
-- data holders. They preserve all original state update paths without
-- cluttering the visible NeXLua interface.
local mesa, lado, tiempos, estado, metodo, diagnostico =
    {Text = ""}, {Text = ""}, {Text = ""},
    {Text = ""}, {Text = ""}, {Text = ""}

local loop = RunService.Heartbeat:Connect(function()
    local now = os.clock()

    -- Detectar mesa y lado pronto, sin esperar al aviso del primer turno.
    if now - lastBind >= 0.15 then
        lastBind = now
        scanBinding(now)
    end

    if now - lastScan >= 0.09 then
        lastScan = now
        local notice = turnNotice()
        local candidateGoal = readGoal()

        if notice == true then
            setTurn(true, now, "AVISO")
        elseif notice == false then
            setTurn(false, now, "RIVAL")
        elseif not myTurn and station and side and holdingValid()
            and candidateGoal and sensorEpoch and sensorMoves >= 2
            and sensorMoveAt and now - sensorMoveAt < 0.30 then
            -- Cuando el aviso falta en la primera ronda, los cambios
            -- del reloj DE TU ASIENTO + objetivo indican tu turno.
            setTurn(true, now, "RELOJ DEL ASIENTO")
        end

        if myTurn and candidateGoal then
            if goal and goal ~= candidateGoal then
                resetTiming()
            end
            goal = candidateGoal
            -- Al recibir tarde el objetivo, aprovechar el sensor preiniciado.
            if not epoch and sensorEpoch and sensorMoves >= 2
                and sensorMoveAt and now - sensorMoveAt < 0.45 then
                epoch = sensorEpoch
                timeSource = "RELOJ REAL (RECUPERADO)"
            end
        end
    end

    if myTurn and turnAt and now - turnAt > 36 then
        setTurn(false, now, "EXPIRADO")
    end

    -- Leer SOLO el Text de tu mesa y lado, incluso si la interfaz esta oculta.
    -- Si ya se conoce epoch, la cuenta avanza sin leer otros cronometros.
    local predicted, mode = nil, "NO INICIADO"
    if myTurn and station and goal then
        if epoch then
            predicted = now - epoch
            mode = (lastTimerAt and now - lastTimerAt < 0.35)
                and "RELOJ REAL" or "RELOJ INTERNO"
        elseif blindEstimate and turnAt then
            predicted = now - turnAt - startupDelay
            mode = "BLIND APROXIMADO"
        end
    end

    if active and myTurn and station and side and goal and not pressed and predicted
        and predicted >= 0 and holdingValid() then
        local delta = (goal - correctionMs / 1000) - predicted
        if delta <= 0 and delta > -0.16 then
            local success, how = clickOwnButton()
            if success then pressed = true end
            lastClick = success and ("ENVIADO/" .. how) or ("ERROR/" .. how)
        end
    end

    if now - lastUI >= 0.15 then
        lastUI = now
        local shortStation = station and station:GetFullName():gsub("^Workspace%.GameStations%.", "") or "NO DETECTADA"
        mesa.Text = "Mesa: " .. shortStation
        lado.Text = "Lado: " .. (side or "--") .. "  |  Metodo: " .. stationSource
        tiempos.Text = string.format("Objetivo: %s  |  Reloj: %s", goal and string.format("%.2f", goal) or "--", predicted and string.format("%.2f", math.max(0, predicted)) or "--")
        if not active then
            estado.Text = "Estado: desactivado"
        elseif not station then
            estado.Text = "Estado: esperando silla / posicion clara"
        elseif not timerLabel then
            estado.Text = "Estado: reloj de tu mesa no encontrado"
        elseif not myTurn then
            estado.Text = "Estado: esperando tu turno"
        elseif not goal then
            estado.Text = "Estado: sin objetivo (no pulsa)"
        elseif pressed then
            estado.Text = "Estado: clic enviado (sin confirmacion)"
        else
            estado.Text = "Estado: " .. mode .. "  |  inicio ~" .. string.format("%.2f", startupDelay) .. "s"
        end
        metodo.Text = "Clic: " .. lastClick
        local sensorStatus = sensorMoveAt and now - sensorMoveAt < 0.35 and "ACTIVO" or "ESPERANDO"
        diagnostico.Text = "Turno: " .. (myTurn and turnSource or "NO") .. " | Sensor: " .. sensorStatus
    end
end)
conns[#conns + 1] = loop

env.AutoStopV7Cleanup = function()
    mobileSpy.pending = nil
    mobileSpy.armed = false
    mobileSpy.learned = nil
    if timerConn then pcall(function() timerConn:Disconnect() end) end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if gui then pcall(function() gui:Destroy() end) end
end
env.AutoStopTimerCleanup = env.AutoStopV7Cleanup
env.NeXLuaAutoStopCleanup = env.AutoStopV7Cleanup
print("[NeXLua Hub V13] V9 timer stable; mobile learns game remote from a manual tap.")
