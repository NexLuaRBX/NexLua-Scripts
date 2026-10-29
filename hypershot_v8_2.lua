-- HYPERSHOT V8.2 | ESP + AIM CON OBJETIVO FIJO
-- Mantiene el objetivo hasta que muera, desaparezca o quede oculto.
-- Adquiere el mas cercano en distancia real entre los que estan
-- visibles y dentro del radio de la mira. No dispara automaticamente.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local WS = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local ENV = (getgenv and getgenv()) or _G

-- Cerrar instancias anteriores (sin cerrar la misma dos veces)
local alreadyStopped = {}
for _, key in ipairs({
    "HS_V82_STOP", "HS_V81_STOP", "HS_V8_STOP", "HS_V72_STOP", "HS_V71_STOP",
    "HS_V7_STOP", "HS_V6_STOP", "HS_V5_STOP", "HS_V4_STOP",
    "HS_PANEL_STOP", "HS_AIM_STOP", "HS_ESP_STOP"
}) do
    local fn = ENV[key]
    if type(fn) == "function" and not alreadyStopped[fn] then
        alreadyStopped[fn] = true
        pcall(fn)
    end
end

local running = true
local espOn = true
local aimOn = true
local radii = {70, 110, 180}
local radiusIndex = 2
local RENDER_KEY = "HS_V82_AIM_RENDER"
local RED = Color3.fromRGB(255, 20, 40)
local WHITE = Color3.fromRGB(255, 255, 255)
local visuals = {}
local lastError = "ninguno"

local espStats = {enemies = 0, bots = 0, marked = 0, parts = 0}
local aimStats = {
    team = "?", heads = 0, onscreen = 0, inRadius = 0,
    blocked = 0, selected = "ninguno", selectedPixels = -1,
    nearest = "ninguno", nearestPixels = -1,
    obstacle = "ninguno", active = false,
}
local aimFrames = 0
local lastAimName = "ninguno"
local lastAimDegrees = 0
local lastAimTime = -1

-- Objetivo persistente: solo se libera por muerte, desaparicion,
-- cambio de equipo, pared/obstaculo u ON/OFF del aimlock.
local lockedTarget = nil
local lockSince = -1
local locksAcquired = 0
local lastLockName = "ninguno"
local lastUnlockReason = "ninguno"
local lastReleasedName = "ninguno"
local lastLockDistance = -1

local function releaseTarget(reason)
    if lockedTarget then
        lastReleasedName = lockedTarget.model.Name
        lastUnlockReason = reason or "liberado"
    end
    lockedTarget = nil
    lockSince = -1
    lastLockDistance = -1
end

local function getEntities()
    return WS:FindFirstChild("Entities")
end

local function isSelf(model)
    local owner = model:GetAttribute("OwnerUserId")
    return (owner ~= nil and tostring(owner) == tostring(LP.UserId))
        or (model.Name == LP.Name and model:GetAttribute("Bot") ~= true)
end

local function getTeam()
    local folder = getEntities()
    if folder then
        for _, model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") and isSelf(model) then
                local team = model:GetAttribute("Team")
                if team ~= nil then
                    return tostring(team), model
                end
            end
        end
    end
    local team = LP:GetAttribute("Team")
    return team ~= nil and tostring(team) or nil, nil
end

local function isBot(model)
    return model:GetAttribute("Bot") == true
        or model.Name:sub(-5) == "__Bot"
end

local function isEnemy(model, myTeam)
    if not myTeam or isSelf(model) then return false end
    local team = model:GetAttribute("Team")
    if team == nil then return false end
    team = tostring(team)
    if myTeam == "-1" then return team == "-1" end
    return team ~= "-1" and team ~= myTeam
end

local function alive(model)
    if not model or not model:IsA("Model")
        or not model:IsDescendantOf(WS)
        or model:GetAttribute("LobbyCharacter") == true then
        return false
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
        and model:FindFirstChild("HumanoidRootPart") ~= nil
end

local function headOf(model)
    local head = model:FindFirstChild("Head", true)
    return head and head:IsA("BasePart") and head or nil
end

-- Panel: izquierda, sin tapar la mira
local gui = Instance.new("ScreenGui")
gui.Name = "HypershotV82"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999

local parent = CoreGui
if type(gethui) == "function" then
    local ok, value = pcall(gethui)
    if ok and typeof(value) == "Instance" then parent = value end
end
if not pcall(function() gui.Parent = parent end) then
    gui.Parent = LP:WaitForChild("PlayerGui")
end

-- ESP: jugadores y bots. Sin texto de nombres/distancias.
local function removeESP(model)
    local v = visuals[model]
    if not v then return end
    if v.highlight then pcall(function() v.highlight:Destroy() end) end
    for _, pair in pairs(v.parts) do
        for _, decoration in ipairs(pair) do
            pcall(function() decoration:Destroy() end)
        end
    end
    visuals[model] = nil
end

local function clearESP()
    for model in pairs(visuals) do removeESP(model) end
end

local function addBotPart(v, part)
    if v.parts[part] or not part:IsA("BasePart")
        or part.Name == "HumanoidRootPart"
        or part.Transparency >= 0.95 then
        return
    end
    local outline = Instance.new("BoxHandleAdornment")
    outline.Name = "HS_V82_Outline"
    outline.Adornee = part
    outline.Size = part.Size + Vector3.new(0.13, 0.13, 0.13)
    outline.Color3 = WHITE
    outline.Transparency = 0.12
    outline.AlwaysOnTop = true
    outline.ZIndex = 1
    outline.Parent = gui

    local fill = Instance.new("BoxHandleAdornment")
    fill.Name = "HS_V82_Fill"
    fill.Adornee = part
    fill.Size = part.Size + Vector3.new(0.02, 0.02, 0.02)
    fill.Color3 = RED
    fill.Transparency = 0.40
    fill.AlwaysOnTop = true
    fill.ZIndex = 2
    fill.Parent = gui
    v.parts[part] = {outline, fill}
end

local function addESP(model)
    local v = visuals[model]
    if not v then
        local h = Instance.new("Highlight")
        h.Name = "__HS_V82_Highlight"
        h.Adornee = model
        h.FillColor = RED
        h.OutlineColor = WHITE
        h.FillTransparency = 0.35
        h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Enabled = true
        h.Parent = model
        v = {highlight = h, bot = isBot(model), parts = {}}
        visuals[model] = v
    end
    if v.bot then
        for _, part in ipairs(model:GetChildren()) do
            if part:IsA("BasePart") then addBotPart(v, part) end
        end
        for part, decorations in pairs(v.parts) do
            if not part:IsDescendantOf(model) then
                for _, adornment in ipairs(decorations) do
                    adornment:Destroy()
                end
                v.parts[part] = nil
            end
        end
    end
end

local function scanESP()
    local folder = getEntities()
    local team = getTeam()
    local wanted = {}
    local count = {enemies = 0, bots = 0, marked = 0, parts = 0}
    if folder and team then
        for _, model in ipairs(folder:GetChildren()) do
            if alive(model) and isEnemy(model, team) then
                count.enemies = count.enemies + 1
                if isBot(model) then count.bots = count.bots + 1 end
                if espOn then
                    wanted[model] = true
                    addESP(model)
                end
            end
        end
    end
    for model in pairs(visuals) do
        if not wanted[model] then removeESP(model) end
    end
    for _, v in pairs(visuals) do
        count.marked = count.marked + 1
        for _ in pairs(v.parts) do count.parts = count.parts + 1 end
    end
    espStats = count
end

-- Visibilidad estricta: un objeto solido entre la camara
-- y la cabeza evita activar el aimlock.
local function canSee(camera, model, head, ownModel)
    local origin = camera.CFrame.Position
    local direction = head.Position - origin
    if direction.Magnitude < 0.01 then return false, nil end

    local excludes = {camera}
    if LP.Character then table.insert(excludes, LP.Character) end
    if ownModel then table.insert(excludes, ownModel) end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = excludes
    params.IgnoreWater = true
    params.RespectCanCollide = true

    local hit = WS:Raycast(origin, direction, params)
    if not hit or hit.Instance:IsDescendantOf(model) then
        return true, nil
    end
    return false, hit.Instance
end

-- Seleccionar objetivo:
-- 1) Si hay uno fijado, conservarlo mientras siga vivo y visible.
-- 2) Si no, elegir entre los que estan dentro del radio y visibles.
-- 3) Entre candidatos, priorizar distancia REAL (studs), no pixeles.
local function selectTarget()
    local camera = WS.CurrentCamera
    local folder = getEntities()
    local team, ownModel = getTeam()
    local s = {
        team = team or "?", heads = 0, onscreen = 0, inRadius = 0,
        blocked = 0, selected = "ninguno", selectedPixels = -1,
        selectedStuds = -1, nearest = "ninguno", nearestPixels = -1,
        nearestStuds = -1, obstacle = "ninguno", active = false,
        locked = false,
    }

    if not camera or not folder or not team then
        releaseTarget("sin camara / Entities / equipo")
        aimStats = s
        return nil, camera
    end

    -- Verificar ANTES el objetivo ya fijado. No exigir que este
    -- dentro del radio otra vez, para evitar cambios involuntarios.
    if lockedTarget then
        local m = lockedTarget.model
        local h = m and headOf(m)
        if not m or not alive(m) then
            releaseTarget("muerto o eliminado")
        elseif not isEnemy(m, team) then
            releaseTarget("ya no es enemigo")
        elseif not h then
            releaseTarget("cabeza desaparecida")
        else
            local visible, obstacle = canSee(camera, m, h, ownModel)
            if not visible then
                local why = obstacle and obstacle:GetFullName() or "obstaculo"
                releaseTarget("bloqueado por: " .. why)
            else
                lockedTarget.head = h
            end
        end
    end

    local center = Vector2.new(camera.ViewportSize.X / 2,
        camera.ViewportSize.Y / 2)
    local bestTarget = nil
    local bestStuds = math.huge
    local bestPixels = math.huge
    local nearestPixels = math.huge
    local nearestBlockedPixels = math.huge
    local radius = radii[radiusIndex]

    for _, model in ipairs(folder:GetChildren()) do
        if alive(model) and isEnemy(model, team) then
            local head = headOf(model)
            if head then
                s.heads = s.heads + 1
                local p, onscreen = camera:WorldToViewportPoint(head.Position)
                if onscreen and p.Z > 0 then
                    s.onscreen = s.onscreen + 1
                    local pixels = (Vector2.new(p.X, p.Y) - center).Magnitude
                    local root = model:FindFirstChild("HumanoidRootPart")
                    if root then
                        local bp, bon = camera:WorldToViewportPoint(root.Position)
                        if bon and bp.Z > 0 then
                            pixels = math.min(pixels,
                                (Vector2.new(bp.X, bp.Y) - center).Magnitude)
                        end
                    end
                    local studs = (head.Position - camera.CFrame.Position).Magnitude
                    if pixels < nearestPixels then
                        nearestPixels = pixels
                        s.nearest = model.Name
                        s.nearestPixels = math.floor(pixels)
                        s.nearestStuds = math.floor(studs)
                    end

                    if pixels <= radius then
                        s.inRadius = s.inRadius + 1
                        local visible, obstacle = canSee(camera, model, head, ownModel)
                        if visible then
                            if studs < bestStuds or
                                (math.abs(studs - bestStuds) < 0.01 and pixels < bestPixels) then
                                bestStuds = studs
                                bestPixels = pixels
                                bestTarget = {model = model, head = head}
                            end
                        else
                            s.blocked = s.blocked + 1
                            if obstacle and pixels < nearestBlockedPixels then
                                nearestBlockedPixels = pixels
                                s.obstacle = obstacle:GetFullName()
                            end
                        end
                    end
                end
            end
        end
    end

    if not lockedTarget and bestTarget then
        lockedTarget = bestTarget
        lockSince = os.clock()
        locksAcquired = locksAcquired + 1
        lastLockName = bestTarget.model.Name
    end

    if lockedTarget then
        local model, head = lockedTarget.model, lockedTarget.head
        s.locked = true
        s.selected = model.Name
        s.selectedStuds = math.floor(
            (head.Position - camera.CFrame.Position).Magnitude)
        lastLockDistance = s.selectedStuds
        local p = camera:WorldToViewportPoint(head.Position)
        if p.Z > 0 then
            s.selectedPixels = math.floor(
                (Vector2.new(p.X, p.Y) - center).Magnitude)
        end
    end

    aimStats = s
    return lockedTarget, camera
end

-- Aimlock directo de V8.1: continuo sobre el MISMO objetivo.
-- Si no hay objetivo valido, no se escribe Camera.CFrame.
local function updateAim()
    if not aimOn then
        aimStats.active = false
        return
    end
    local target, camera = selectTarget()
    if not target or not camera then
        aimStats.active = false
        return
    end
    if not target.head:IsDescendantOf(WS) then
        releaseTarget("cabeza eliminada")
        aimStats.active = false
        return
    end
    local current = camera.CFrame
    local direction = target.head.Position - current.Position
    if direction.Magnitude < 0.01 then
        aimStats.active = false
        return
    end

    local desired = CFrame.lookAt(current.Position, target.head.Position)
    local dot = math.clamp(current.LookVector:Dot(desired.LookVector), -1, 1)
    camera.CFrame = desired
    aimStats.active = true
    aimFrames = aimFrames + 1
    lastAimName = target.model.Name
    lastAimDegrees = math.deg(math.acos(dot))
    lastAimTime = os.clock()
end

-- Menu izquierdo
local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(275, 297)
panel.Position = UDim2.new(0, 12, 0, 110)
panel.BackgroundColor3 = Color3.fromRGB(21, 24, 35)
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
local border = Instance.new("UIStroke", panel)
border.Color = Color3.fromRGB(45, 125, 235)
border.Thickness = 1.5

local function label(text, y, height, size)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -16, 0, height)
    l.Position = UDim2.fromOffset(8, y)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = WHITE
    l.Font = Enum.Font.GothamBold
    l.TextSize = size or 12
    l.TextWrapped = true
    l.Parent = panel
    return l
end

label("HYPERSHOT V8.2 | OBJETIVO FIJO", 8, 25, 14)
local statusLabel = label("ESP ON | AIM ON", 37, 21, 13)
local statsLabel = label("Buscando enemigos...", 60, 44, 12)

local function button(text, y, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -16, 0, 36)
    b.Position = UDim2.fromOffset(8, y)
    b.BackgroundColor3 = color
    b.TextColor3 = WHITE
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.Parent = panel
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    return b
end

local espButton = button("WALLHACK: ON", 106, Color3.fromRGB(35, 145, 85))
local aimButton = button("AIMLOCK: ON", 148, Color3.fromRGB(35, 145, 85))
local radiusButton = button("RADIO: 110 PX", 190, Color3.fromRGB(55, 105, 200))
local copyButton = button("COPIAR DIAGNOSTICO", 232, Color3.fromRGB(45, 110, 210))

local function updatePanel()
    statusLabel.Text = string.format("ESP %s | AIM %s",
        espOn and "ON" or "OFF", aimOn and "ON" or "OFF")
    statsLabel.Text = string.format(
        "Enemigos: %d | Bots: %d | ESP: %d\nCerca: %d | Bloqueados: %d\nApuntando: %s",
        espStats.enemies, espStats.bots, espStats.marked,
        aimStats.inRadius, aimStats.blocked,
        aimStats.active and aimStats.selected or "LIBRE"
    )
    espButton.Text = espOn and "WALLHACK: ON" or "WALLHACK: OFF"
    aimButton.Text = aimOn and "AIMLOCK: ON" or "AIMLOCK: OFF"
    espButton.BackgroundColor3 = espOn
        and Color3.fromRGB(35, 145, 85) or Color3.fromRGB(165, 50, 60)
    aimButton.BackgroundColor3 = aimOn
        and Color3.fromRGB(35, 145, 85) or Color3.fromRGB(165, 50, 60)
    radiusButton.Text = "RADIO: " .. radii[radiusIndex] .. " PX"
end

espButton.MouseButton1Click:Connect(function()
    espOn = not espOn
    if not espOn then clearESP() end
    pcall(scanESP)
    updatePanel()
end)

aimButton.MouseButton1Click:Connect(function()
    aimOn = not aimOn
    if not aimOn then
        releaseTarget("aimlock desactivado")
        aimStats.active = false
    end
    updatePanel()
end)

radiusButton.MouseButton1Click:Connect(function()
    radiusIndex = radiusIndex % #radii + 1
    updatePanel()
end)

local function diagnostic()
    local lines = {}
    local function add(value) lines[#lines + 1] = tostring(value) end
    add("=== HYPERSHOT V8.2 DIAGNOSTICO ===")
    add("PlaceId: " .. game.PlaceId)
    add("Team: " .. aimStats.team)
    add("Streaming: " .. tostring(WS.StreamingEnabled))
    add("Wallhack ON: " .. tostring(espOn))
    add("Aimlock ON: " .. tostring(aimOn))
    add("Radius: " .. radii[radiusIndex])
    add("Camera exists: " .. tostring(WS.CurrentCamera ~= nil))
    add("")
    add("--- WALLHACK ---")
    add("Enemies: " .. espStats.enemies)
    add("Bots: " .. espStats.bots)
    add("ESP active: " .. espStats.marked)
    add("Bot body parts: " .. espStats.parts)
    add("")
    add("--- AIMLOCK CONTINUO ---")
    add("Heads: " .. aimStats.heads)
    add("Onscreen: " .. aimStats.onscreen)
    add("Inside radius: " .. aimStats.inRadius)
    add("Blocked: " .. aimStats.blocked)
    add("Nearest: " .. aimStats.nearest)
    add("Nearest pixels: " .. aimStats.nearestPixels)
    add("Selected: " .. aimStats.selected)
    add("Selected pixels: " .. aimStats.selectedPixels)
    add("Selected distance (studs): " .. (aimStats.selectedStuds or -1))
    add("Locked: " .. tostring(lockedTarget ~= nil))
    add("Locked target: " .. (lockedTarget and lockedTarget.model.Name or "ninguno"))
    add("Locks acquired: " .. locksAcquired)
    add("Last acquired target: " .. lastLockName)
    add("Last released target: " .. lastReleasedName)
    add("Lock duration (seconds): " .. (lockSince >= 0
        and string.format("%.2f", os.clock() - lockSince) or "0"))
    add("Last unlock reason: " .. lastUnlockReason)
    add("Nearest candidate distance (studs): " .. (aimStats.nearestStuds or -1))
    add("Currently moving camera: " .. tostring(aimStats.active))
    add("Aim frames applied (cumulative): " .. aimFrames)
    add("Last aim target: " .. lastAimName)
    add("Last aim degrees: " .. string.format("%.3f", lastAimDegrees))
    add("Seconds since last aim: " .. (lastAimTime < 0
        and "nunca" or string.format("%.2f", os.clock() - lastAimTime)))
    add("")
    add("--- VISIBILIDAD ---")
    add("Nearest obstacle: " .. aimStats.obstacle)
    add("Last error: " .. lastError)
    add("=== FIN ===")
    return table.concat(lines, "\n")
end

copyButton.MouseButton1Click:Connect(function()
    local ok, report = pcall(diagnostic)
    if not ok then
        copyButton.Text = "ERROR AL GENERAR"
        return
    end
    local clipboard = setclipboard or toclipboard
    if type(clipboard) == "function" and pcall(clipboard, report) then
        copyButton.Text = "DIAGNOSTICO COPIADO"
    else
        print(report)
        copyButton.Text = "DIAGNOSTICO EN CONSOLA"
    end
end)

local function stopAll()
    running = false
    espOn = false
    aimOn = false
    releaseTarget("script detenido")
    pcall(function() RunService:UnbindFromRenderStep(RENDER_KEY) end)
    clearESP()
    pcall(function() gui:Destroy() end)
end

ENV.HS_V82_STOP = stopAll
ENV.HS_V81_STOP = stopAll
ENV.HS_V8_STOP = stopAll
ENV.HS_PANEL_STOP = stopAll
ENV.HS_AIM_STOP = stopAll

RunService:BindToRenderStep(RENDER_KEY,
    Enum.RenderPriority.Camera.Value + 2,
    function()
        if not running then return end
        local ok, err = pcall(updateAim)
        if not ok then lastError = "AIM: " .. tostring(err) end
    end)

task.spawn(function()
    while running do
        local ok, err = pcall(scanESP)
        if not ok then lastError = "ESP: " .. tostring(err) end
        pcall(updatePanel)
        task.wait(0.5)
    end
end)

pcall(scanESP)
pcall(selectTarget)
updatePanel()
print("[HYPERSHOT V8.2] ESP + aim fijo, priorizando distancia real")
