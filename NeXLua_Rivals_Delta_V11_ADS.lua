-- NeXLua Rivals V11 / Delta ADS
-- Mobile AIM: toggle Head Lock and attempt actual weapon ADS/scope. No auto fire.
local __loadedOk, __loadedError = xpcall(function()

--[[
    NeXLua Hub V11 | RIVALS DELTA ADS EDITION
    MINIMAL HEALTH ESP + SMART HEAD LOCK

    Wallhack rojo
    HP minimalista encima de la cabeza
    Aimlock inteligente 360 grados
    TeamID para distinguir aliados
    Cambio automatico de objetivo
    Menu simple: Wallhack / Aimbot
    PC + Movil
]]

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local WS = game:GetService("Workspace")

-- Delta/mobile: avoid running before Roblox has finished loading.
if not game:IsLoaded() then game.Loaded:Wait() end
local LP = Players.LocalPlayer or Players.PlayerAdded:Wait()
local env = _G
if type(getgenv) == "function" then
    local ok, result = pcall(getgenv)
    if ok and type(result) == "table" then env = result end
end

-- Apagar version anterior
if type(env.RivalsESP_Stop) == "function" then
    pcall(env.RivalsESP_Stop)
end

local CFG = {
    Wallhack = true,
    Aimbot = true,
    MaxDistance = 1500,
    SearchDelay = 0.10,
    VisibilityDelay = 0.08,
    OcclusionGrace = 0.15
}

local activo = true
local objetivo = nil
local ultimaVision = 0
local ultimoCheck = 0
local proximaBusqueda = 0

local mobileAimLatched = false
local adsMethod = nil -- "native" (RIVALS touch scope control) or "rmb" (right-click held)
local adsControl = nil
local adsWorking = false  -- input accepted; NOT proof the gun scoped
local adsBusy = false

local highlights = {}
local healthDisplays = {}
local conexiones = {}

local RENDER_NAME = "NeXLuaRivalsSmartAimV11"

local function conectar(signal, callback)
    local c = signal:Connect(callback)
    table.insert(conexiones, c)
    return c
end

--====================================
-- TEAM DETECTION
--====================================

local claves = {
    "TeamID", "TeamId", "TeamName",
    "Team", "Side", "SquadId"
}

local function atributo(pl, key)
    local value = pl:GetAttribute(key)

    if value == nil and pl.Character then
        value = pl.Character:GetAttribute(key)
    end

    return value
end

local function detectarEquipo(pl)
    if pl == LP then return "local" end

    for _, key in ipairs(claves) do
        local a = atributo(LP, key)
        local b = atributo(pl, key)

        if a ~= nil and b ~= nil
            and tostring(a) ~= ""
            and tostring(b) ~= "" then

            return tostring(a) == tostring(b)
                and "aliado" or "enemigo"
        end
    end

    if LP.Team and pl.Team then
        return LP.Team == pl.Team
            and "aliado" or "enemigo"
    end

    if not LP.Neutral and not pl.Neutral then
        return LP.TeamColor == pl.TeamColor
            and "aliado" or "enemigo"
    end

    return "desconocido"
end

local function esEnemigo(pl)
    return pl ~= LP
        and pl.Parent == Players
        and detectarEquipo(pl) == "enemigo"
end

local function humanoide(pl)
    local char = pl.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function estaVivo(pl)
    local hum = humanoide(pl)
    return hum ~= nil and hum.Health > 0
end

local function cabeza(pl)
    local char = pl.Character
    if not char then return nil end

    local head = char:FindFirstChild("Head")

    if head and head:IsA("BasePart") then
        return head
    end

    return nil
end

--====================================
-- CONTENEDORES
--====================================

local folder = Instance.new("Folder")
folder.Name = "NeXLuaRivalsESP_V11"
folder.Parent = WS

local gui = Instance.new("ScreenGui")
gui.Name = "NeXLuaRivalsMenuV11"
gui.ResetOnSpawn = false
gui.DisplayOrder = 999
gui.Parent = LP:WaitForChild("PlayerGui")

local function redondear(obj, radio)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radio)
    corner.Parent = obj
end

--====================================
-- HEALTH ESP MINIMALISTA
--====================================

local function colorVida(p)
    if p > 0.65 then
        return Color3.fromRGB(55, 235, 115)
    elseif p > 0.30 then
        return Color3.fromRGB(255, 210, 45)
    else
        return Color3.fromRGB(255, 65, 65)
    end
end

local function crearVida(pl, head)
    -- Indicador muy pequeno y transparente
    local bb = Instance.new("BillboardGui")
    bb.Name = "MinimalHP"

    bb.Size = UDim2.fromOffset(80, 19)
    bb.StudsOffsetWorldSpace =
        Vector3.new(0, 1.8, 0)

    bb.AlwaysOnTop = true
    bb.MaxDistance = 1500
    bb.Adornee = head
    bb.Parent = gui

    -- Solo texto, sin recuadro de fondo
    local texto = Instance.new("TextLabel")
    texto.Name = "HPText"

    texto.Size = UDim2.new(1, 0, 0, 12)
    texto.BackgroundTransparency = 1

    texto.Text = "100 HP"
    texto.TextSize = 11
    texto.Font = Enum.Font.GothamBold

    texto.TextColor3 =
        Color3.fromRGB(55, 235, 115)

    texto.TextStrokeColor3 =
        Color3.fromRGB(0, 0, 0)

    texto.TextStrokeTransparency = 0.35
    texto.Parent = bb

    -- Barra extremadamente fina
    local fondo = Instance.new("Frame")
    fondo.Name = "HealthTrack"

    fondo.Size = UDim2.fromOffset(64, 3)
    fondo.Position = UDim2.new(0.5, -32, 0, 14)

    fondo.BackgroundColor3 =
        Color3.fromRGB(45, 45, 45)

    fondo.BackgroundTransparency = 0.2
    fondo.BorderSizePixel = 0
    fondo.Parent = bb

    redondear(fondo, 2)

    local fill = Instance.new("Frame")
    fill.Name = "HealthFill"

    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 =
        Color3.fromRGB(55, 235, 115)

    fill.BorderSizePixel = 0
    fill.Parent = fondo

    redondear(fill, 2)

    local data = {
        gui = bb,
        texto = texto,
        fill = fill
    }

    healthDisplays[pl] = data

    return data
end

local function actualizarVida(pl, hum, head)
    local data = healthDisplays[pl]

    if not data or not data.gui.Parent then
        data = crearVida(pl, head)
    end

    data.gui.Adornee = head

    local maxHP = math.max(hum.MaxHealth, 1)
    local hp = math.clamp(hum.Health, 0, maxHP)
    local porcentaje = math.clamp(hp / maxHP, 0, 1)

    local color = colorVida(porcentaje)

    -- Solo HP actual, no numero maximo
    data.texto.Text = tostring(math.ceil(hp)) .. " HP"
    data.texto.TextColor3 = color

    data.fill.Size =
        UDim2.new(porcentaje, 0, 1, 0)

    data.fill.BackgroundColor3 = color
end

--====================================
-- WALLHACK
--====================================

local function limpiarJugador(pl)
    if highlights[pl] then
        highlights[pl]:Destroy()
        highlights[pl] = nil
    end

    if healthDisplays[pl] then
        healthDisplays[pl].gui:Destroy()
        healthDisplays[pl] = nil
    end
end

local function actualizarESP()
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LP then

            local hum = humanoide(pl)
            local head = cabeza(pl)

            local valido =
                CFG.Wallhack
                and esEnemigo(pl)
                and hum ~= nil
                and hum.Health > 0
                and head ~= nil

            if valido then
                local h = highlights[pl]

                if not h or not h.Parent then
                    h = Instance.new("Highlight")
                    h.Name = "EnemyESP"

                    h.DepthMode =
                        Enum.HighlightDepthMode.AlwaysOnTop

                    h.FillTransparency = 0.5
                    h.OutlineTransparency = 0

                    h.FillColor =
                        Color3.fromRGB(255, 45, 45)

                    h.OutlineColor =
                        Color3.fromRGB(255, 0, 0)

                    h.Parent = folder
                    highlights[pl] = h
                end

                h.Adornee = pl.Character
                h.Enabled = true

                actualizarVida(pl, hum, head)
            else
                limpiarJugador(pl)
            end
        end
    end

    for pl in pairs(highlights) do
        if pl.Parent ~= Players then
            limpiarJugador(pl)
        end
    end

    for pl in pairs(healthDisplays) do
        if pl.Parent ~= Players then
            limpiarJugador(pl)
        end
    end
end

--====================================
-- DISTANCIA Y VISIBILIDAD
--====================================

local function distanciaValida(part)
    local char = LP.Character

    local root = char and char:FindFirstChild(
        "HumanoidRootPart"
    )

    if not root then
        return false, math.huge
    end

    local dist =
        (root.Position - part.Position).Magnitude

    return dist <= CFG.MaxDistance, dist
end

local rayParams = RaycastParams.new()
rayParams.FilterType =
    Enum.RaycastFilterType.Exclude

rayParams.IgnoreWater = true

local function lineaLibre(camera, pl, head)
    if not pl.Character then return false end

    local origen = camera.CFrame.Position
    local direccion = head.Position - origen

    if direccion.Magnitude < 0.01 then
        return true
    end

    local excluir = {}

    if LP.Character then
        table.insert(excluir, LP.Character)
    end

    rayParams.FilterDescendantsInstances = excluir

    local hit = WS:Raycast(
        origen,
        direccion,
        rayParams
    )

    return hit == nil
        or hit.Instance:IsDescendantOf(pl.Character)
end

--====================================
-- AIMBOT INTELIGENTE 360
--====================================

local function buscarEnemigo(camera)
    local elegido = nil
    local mejorPuntuacion = math.huge

    local origen = camera.CFrame.Position
    local direccionCamara = camera.CFrame.LookVector

    for _, pl in ipairs(Players:GetPlayers()) do
        if esEnemigo(pl) and estaVivo(pl) then

            local head = cabeza(pl)

            if head then
                local rangoOK, dist =
                    distanciaValida(head)

                if rangoOK then
                    local vector = head.Position - origen

                    if vector.Magnitude > 0.01 then
                        local direccion = vector.Unit

                        local dot = math.clamp(
                            direccionCamara:Dot(direccion),
                            -1,
                            1
                        )

                        local angulo = (1 - dot) / 2

                        local puntuacion =
                            angulo * 0.55
                            + (dist / CFG.MaxDistance) * 0.45

                        if puntuacion < mejorPuntuacion
                            and lineaLibre(camera, pl, head) then

                            elegido = pl
                            mejorPuntuacion = puntuacion
                        end
                    end
                end
            end
        end
    end

    return elegido
end

local function objetivoValido(pl)
    if not pl then return false end
    if not esEnemigo(pl) then return false end
    if not estaVivo(pl) then return false end

    local head = cabeza(pl)
    if not head then return false end

    local rangoOK = distanciaValida(head)
    return rangoOK
end

local function soltarObjetivo()
    objetivo = nil
    ultimaVision = 0
end

local function actualizarAim()
    if not activo or not CFG.Aimbot then
        soltarObjetivo()
        return
    end

    -- On phones the touch toggle is the only aim activation input.
    -- On desktop, preserve the original right-click behavior.
    local presionando = mobileAimLatched
    if not presionando and not UIS.TouchEnabled then
        presionando = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    if not presionando then
        soltarObjetivo()
        return
    end

    local camera = WS.CurrentCamera
    if not camera then return end

    local ahora = os.clock()

    if objetivo and not objetivoValido(objetivo) then
        soltarObjetivo()
    end

    if objetivo
        and ahora - ultimoCheck >= CFG.VisibilityDelay then

        ultimoCheck = ahora

        local head = cabeza(objetivo)

        if head and lineaLibre(camera, objetivo, head) then
            ultimaVision = ahora
        elseif ahora - ultimaVision > CFG.OcclusionGrace then
            soltarObjetivo()
        end
    end

    if not objetivo and ahora >= proximaBusqueda then
        proximaBusqueda = ahora + CFG.SearchDelay

        objetivo = buscarEnemigo(camera)

        if objetivo then
            ultimaVision = ahora
            ultimoCheck = ahora
        end
    end

    if not objetivo then return end

    local head = cabeza(objetivo)

    if not head then
        soltarObjetivo()
        return
    end

    if ahora - ultimaVision >
        CFG.VisibilityDelay + CFG.OcclusionGrace then
        return
    end

    -- Head Aimlock 360
    camera.CFrame = CFrame.lookAt(
        camera.CFrame.Position,
        head.Position
    )
end

local renderConnection
local renderBound = pcall(function()
    RS:UnbindFromRenderStep(RENDER_NAME)
    RS:BindToRenderStep(
        RENDER_NAME,
        Enum.RenderPriority.Camera.Value + 1,
        actualizarAim
    )
end)
if not renderBound then
    renderConnection = RS.RenderStepped:Connect(actualizarAim)
end

--====================================
-- NEXLUA BRANDING / COMPACT MENU
--====================================

local CHANNEL_URL = "https://www.youtube.com/@NexLuaRBX"
-- Optional official Roblox image asset ID for the full resolution avatar.
local AVATAR_ASSET_ID = 0

local THEME = {
    panel = Color3.fromRGB(10, 20, 15),
    row = Color3.fromRGB(19, 35, 27),
    border = Color3.fromRGB(34, 115, 64),
    green = Color3.fromRGB(42, 235, 102),
    darkGreen = Color3.fromRGB(30, 137, 66),
    white = Color3.fromRGB(240, 252, 244),
    muted = Color3.fromRGB(145, 183, 159),
    red = Color3.fromRGB(168, 60, 67)
}

local function round(inst, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = inst
end

local function stroke(inst, color)
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.border
    s.Thickness = 1
    s.Parent = inst
end

local function textLabel(parent, value, size, color, bold)
    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Text = value
    t.TextColor3 = color or THEME.white
    t.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    t.TextSize = size or 12
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = parent
    return t
end

-- 16x16 on-device rendition of the supplied NeXLua logo.
-- No writefile, getcustomasset, base64 decoding or network access required.
local LOGO_PALETTE = {"4AA72E", "2B7419", "225B16", "1B4A11", "123A0C", "0D2E09", "092206", "061A05", "031403", "031003", "030D03", "020A02", "020802", "010501", "010301", "000001"}
local LOGO_PIXELS = {
    "F14DF242122CB41F",
    "1FDB685001059BF1",
    "59E5322100027DC4",
    "DA613454634108AC",
    "D8833856A12112BE",
    "DAC346A56863304C",
    "D89125746643202C",
    "83311F4C6514802C",
    "52E52AFEC416507C",
    "588C747DD424258C",
    "878A74767F965168",
    "889E7B999852350C",
    "888ED77C8BD6610E",
    "17B9CBAEE8A89DE1",
    "1888AB8FBFDB9B72",
    "E21FCCDCADACA13E",
}

local function makeAvatar(parent, size)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.fromOffset(size, size)
    holder.BackgroundColor3 = THEME.panel
    holder.BorderSizePixel = 0
    holder.ClipsDescendants = true
    holder.Parent = parent
    round(holder, size / 2)

    -- Image-independent rendition of the supplied NeXLua avatar.
    local colors = {}
    for i, hex in ipairs(LOGO_PALETTE) do
        colors[i] = Color3.fromRGB(
            tonumber(hex:sub(1, 2), 16),
            tonumber(hex:sub(3, 4), 16),
            tonumber(hex:sub(5, 6), 16)
        )
    end
    for y, row in ipairs(LOGO_PIXELS) do
        for x = 1, 16 do
            local idx = tonumber(row:sub(x, x), 16) + 1
            local px = Instance.new("Frame")
            px.BorderSizePixel = 0
            px.BackgroundColor3 = colors[idx]
            px.Size = UDim2.fromScale(1 / 16, 1 / 16)
            px.Position = UDim2.fromScale((x - 1) / 16, (y - 1) / 16)
            px.Parent = holder
        end
    end

    -- Optional Roblox image asset, if the avatar is uploaded to Roblox.
    if AVATAR_ASSET_ID > 0 then
        local photo = Instance.new("ImageLabel")
        photo.Size = UDim2.fromScale(1, 1)
        photo.BackgroundTransparency = 1
        photo.Image = "rbxassetid://" .. tostring(AVATAR_ASSET_ID)
        photo.ScaleType = Enum.ScaleType.Crop
        photo.Parent = holder
    end
    stroke(holder, THEME.green)
    return holder
end

local function notify(msg)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "NeXLua Hub", Text = msg, Duration = 4
        })
    end)
end

local function openChannel()
    for _, key in ipairs({"openurl", "open_url", "openbrowser", "open_browser"}) do
        local f = env[key]
        if type(f) == "function" then
            local ok = pcall(f, CHANNEL_URL)
            if ok then return end
        end
    end
    local clipboard = env.setclipboard or setclipboard or env.toclipboard
    if type(clipboard) == "function" then
        local ok = pcall(clipboard, CHANNEL_URL)
        if ok then
            notify("Channel link copied. Paste it into your browser.")
            return
        end
    end
    notify("Visit youtube.com/@NexLuaRBX")
end

-- Reuse the already-created ScreenGui from the original Rivals script.
gui.Name = "NeXLua_Rivals_Hub_V11_DeltaADS"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999999

local panel = Instance.new("Frame")
panel.Name = "NeXLuaCompactPanel"
panel.Size = UDim2.fromOffset(274, 202)
-- Mobile: never begin outside the screen edge in narrow portrait mode.
panel.Position = UIS.TouchEnabled and UDim2.new(0.5, -137, 0.13, 0)
    or UDim2.new(1, -289, 0.27, 0)
panel.BackgroundColor3 = THEME.panel
panel.BorderSizePixel = 0
panel.Active = true
panel.Parent = gui
round(panel, 12)
stroke(panel)

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 57)
bar.BackgroundTransparency = 1
bar.Active = true
bar.Parent = panel

local avatar = makeAvatar(bar, 43)
avatar.Position = UDim2.fromOffset(9, 7)

local headerTitle = textLabel(bar, "NeXLua Hub", 16, THEME.white, true)
headerTitle.Position = UDim2.fromOffset(60, 7)
headerTitle.Size = UDim2.fromOffset(151, 22)

local channelButton = Instance.new("TextButton")
channelButton.Size = UDim2.fromOffset(153, 21)
channelButton.Position = UDim2.fromOffset(60, 29)
channelButton.BackgroundTransparency = 1
channelButton.TextXAlignment = Enum.TextXAlignment.Left
channelButton.Text = "YouTube: @NexLuaRBX  >"
channelButton.TextColor3 = THEME.green
channelButton.TextSize = 10
channelButton.Font = Enum.Font.Gotham
channelButton.Parent = bar
conectar(channelButton.Activated, openChannel)

local function smallButton(label, x)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(22, 23)
    b.Position = UDim2.fromOffset(x, 16)
    b.BackgroundColor3 = THEME.row
    b.TextColor3 = THEME.white
    b.Font = Enum.Font.GothamBold
    b.TextSize = 15
    b.Text = label
    b.Parent = bar
    round(b, 6)
    return b
end
local minimizeButton = smallButton("-", 222)
local closeButton = smallButton("x", 247)

local body = Instance.new("Frame")
body.Position = UDim2.fromOffset(0, 58)
body.Size = UDim2.new(1, 0, 1, -58)
body.BackgroundTransparency = 1
body.Parent = panel

local function featureRow(name, detail, y)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -18, 0, 51)
    row.Position = UDim2.fromOffset(9, y)
    row.BackgroundColor3 = THEME.row
    row.Text = ""
    row.Parent = body
    round(row, 8)

    local title = textLabel(row, name, 13, THEME.white, true)
    title.Position = UDim2.fromOffset(10, 6)
    title.Size = UDim2.new(1, -69, 0, 19)

    local sub = textLabel(row, detail, 10, THEME.muted, false)
    sub.Position = UDim2.fromOffset(10, 27)
    sub.Size = UDim2.new(1, -69, 0, 15)

    local track = Instance.new("Frame")
    track.Size = UDim2.fromOffset(39, 21)
    track.Position = UDim2.new(1, -49, .5, -11)
    track.BackgroundColor3 = THEME.red
    track.Parent = row
    round(track, 11)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(17, 17)
    knob.Position = UDim2.fromOffset(2, 2)
    knob.BackgroundColor3 = THEME.white
    knob.Parent = track
    round(knob, 9)
    return row, track, knob
end

local wallRow, wallTrack, wallKnob = featureRow(
    "Wallhack ESP", "Enemy outlines + health", 4
)
local aimRow, aimTrack, aimKnob = featureRow(
    "Head Lock", "PC: RMB / mobile: tap for ADS", 60
)

local footer = textLabel(body, "RIVALS EDITION  •  NEXLUA", 9, THEME.muted, false)
footer.Position = UDim2.fromOffset(12, 117)
footer.Size = UDim2.new(1, -24, 0, 18)
footer.TextXAlignment = Enum.TextXAlignment.Center

local function setVisual(track, knob, enabled)
    track.BackgroundColor3 = enabled and THEME.green or THEME.red
    knob.Position = enabled and UDim2.fromOffset(20, 2)
        or UDim2.fromOffset(2, 2)
end

-- RIVALS mobile has a separate ADS/scope input. A camera lock alone
-- DOES NOT aim down sights and cannot remove a weapon's hip-fire spread.
-- Best effort: use a clearly identified native ADS touch GUI control.
-- If unavailable, try holding the game's right-mouse/secondary action.
-- Delta may restrict these virtual inputs; NEVER simulate a shot.
local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local function isGameADSToggle(b)
    if not b:IsA("GuiButton") or not b.Visible or not b.Active then return false end
    if b:IsDescendantOf(gui) then return false end
    local size = b.AbsoluteSize
    if size.X < 12 or size.Y < 12 then return false end
    local screen = b:FindFirstAncestorOfClass("ScreenGui")
    if not screen or not screen.Enabled then return false end
    local parts = {b.Name}
    local p = b.Parent
    if p and p ~= screen then parts[#parts+1] = p.Name end
    if b:IsA("TextButton") then parts[#parts+1] = b.Text end
    local label = table.concat(parts, " "):lower()
    -- Insist on distinct names: never guess at Fire/Shoot/Reload controls.
    if label:find("shoot", 1, true) or label:find("fire", 1, true)
       or label:find("reload", 1, true) or label:find("grenade", 1, true) then return false end
    for _,token in ipairs({"scope", "scop", "adsbutton", "aimbutton", "aim_btn", "aiming",
                              "aim", "sight", "zoom", "secondarybutton", "secondaryaction"}) do
        if label:find(token, 1, true) then return true end
    end
    return false
end

local function findGameADSButton()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    local best, bestScore = nil, -1
    for _,v in ipairs(pg:GetDescendants()) do
        if isGameADSToggle(v) then
            local name = v.Name:lower()
            local score = name:find("scope", 1, true) and 5
                or name:find("ads", 1, true) and 4
                or name:find("aim", 1, true) and 3 or 1
            local p = v.Parent
            -- Prefer actual HUD controls to settings buttons.
            if p and tostring(p.Name):lower():find("touch", 1, true) then score = score + 2 end
            if score > bestScore then best, bestScore = v, score end
        end
    end
    return best
end

local function tapGameADSButton(b)
    if not VIM or not b or not b.Parent or not isGameADSToggle(b) then return false end
    local p, sz = b.AbsolutePosition, b.AbsoluteSize
    local x = math.floor(p.X + sz.X / 2)
    local y = math.floor(p.Y + sz.Y / 2)
    if x <= 0 or y <= 0 then return false end
    -- Genuine simulated touch input is more relevant to a mobile HUD than RMB.
    local ok = pcall(function() VIM:SendTouchEvent(189, 0, x, y) end)
    if ok then
        task.wait(0.055)
        local ended = pcall(function() VIM:SendTouchEvent(189, 2, x, y) end)
        if ended then return true end
    end
    -- Mouse press on a GUI button is a fallback for executors without touch injection.
    local down = pcall(function() VIM:SendMouseButtonEvent(x, y, 0, true, game, 0) end)
    if not down then return false end
    task.wait(0.045)
    return pcall(function() VIM:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
end

local function sendRMB(down)
    if not VIM then return false end
    local cam = WS.CurrentCamera
    if not cam then return false end
    local sz = cam.ViewportSize
    local x = math.floor(sz.X * 0.5)
    local y = math.floor(sz.Y * 0.5)
    return pcall(function()
        VIM:SendMouseButtonEvent(x, y, 1, down, game, 0)
    end)
end

local function setMobileADS(wanted)
    if adsBusy then return end
    adsBusy = true
    if wanted then
        local native = findGameADSButton()
        if native and tapGameADSButton(native) then
            adsMethod, adsControl, adsWorking = "native", native, true
        elseif sendRMB(true) then
            adsMethod, adsControl, adsWorking = "rmb", nil, true
        else
            adsMethod, adsControl, adsWorking = nil, nil, false
            notify("Head Lock ON, but ADS input is blocked. Use the game's Scope button.")
        end
    else
        if adsMethod == "native" then
            -- The native mobile Scope button usually operates as a toggle.
            tapGameADSButton(adsControl or findGameADSButton())
        elseif adsMethod == "rmb" then
            sendRMB(false)
        end
        adsMethod, adsControl, adsWorking = nil, nil, false
    end
    adsBusy = false
end

-- Mobile: one tap activates the camera lock AND attempts real ADS.
-- Another tap releases it. Automatic firing is intentionally absent.
local mobileBtn = Instance.new("TextButton")
mobileBtn.Name = "NeXLuaMobileAim"
mobileBtn.Size = UDim2.fromOffset(76, 76)
-- Keep the AIM latch away from the left movement joystick.
mobileBtn.Position = UDim2.new(1, -93, 0.52, -38)
mobileBtn.BackgroundColor3 = THEME.red
mobileBtn.BackgroundTransparency = 0.08
mobileBtn.Text = "AIM OFF"
mobileBtn.TextSize = 15
mobileBtn.Font = Enum.Font.GothamBold
mobileBtn.TextColor3 = THEME.white
mobileBtn.Active = true
mobileBtn.Parent = gui
round(mobileBtn, 38)
stroke(mobileBtn)

local function updateMobileAimButton()
    mobileBtn.Text = mobileAimLatched and (adsWorking and "ADS SENT" or "AIM ONLY") or "AIM OFF"
    mobileBtn.TextSize = mobileAimLatched and 12 or 15
    mobileBtn.BackgroundColor3 = mobileAimLatched and THEME.darkGreen or THEME.red
end

local function updateMenu()
    setVisual(wallTrack, wallKnob, CFG.Wallhack)
    setVisual(aimTrack, aimKnob, CFG.Aimbot)
    mobileBtn.Visible = UIS.TouchEnabled and CFG.Aimbot
    if not CFG.Aimbot then
        soltarObjetivo()
        if mobileAimLatched or adsMethod then
            mobileAimLatched = false
            setMobileADS(false)
        end
    end
    updateMobileAimButton()
end

conectar(wallRow.Activated, function()
    CFG.Wallhack = not CFG.Wallhack
    if not CFG.Wallhack then
        for pl in pairs(highlights) do limpiarJugador(pl) end
        for pl in pairs(healthDisplays) do limpiarJugador(pl) end
    end
    updateMenu()
end)
conectar(aimRow.Activated, function()
    CFG.Aimbot = not CFG.Aimbot
    updateMenu()
end)

-- Activated fires once per completed tap. Lifting the finger and
-- moving with the on-screen joystick do not cancel aiming.
conectar(mobileBtn.Activated, function()
    if not CFG.Aimbot or adsBusy then return end
    mobileAimLatched = not mobileAimLatched
    if not mobileAimLatched then soltarObjetivo() end
    -- Execute the native scope action together with NeXLua's camera lock.
    setMobileADS(mobileAimLatched)
    updateMobileAimButton()
end)

-- Minimize without stopping ESP or Head Lock.
local minimized = false
conectar(minimizeButton.Activated, function()
    minimized = not minimized
    body.Visible = not minimized
    panel.Size = UDim2.fromOffset(274, minimized and 57 or 202)
    minimizeButton.Text = minimized and "+" or "-"
end)
conectar(closeButton.Activated, function()
    if type(env.RivalsESP_Stop) == "function" then
        env.RivalsESP_Stop()
    end
end)

-- Drag the window from its header on mouse or touch.
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
conectar(bar.InputBegan, function(input)
    local kind = input.UserInputType
    if kind == Enum.UserInputType.MouseButton1
        or kind == Enum.UserInputType.Touch then
        dragging = true
        dragInput = input
        dragStart = input.Position
        startPos = panel.Position
    end
end)
conectar(UIS.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input == dragInput then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
conectar(UIS.InputEnded, function(input)
    if input == dragInput or
        (input.UserInputType == Enum.UserInputType.MouseButton1
            and dragInput
            and dragInput.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging = false
        dragInput = nil
    end
end)

-- Both are ON from the first execution.
updateMenu()

--====================================
-- DETENER
--====================================

local function detener()
    if not activo then return end

    activo = false
    soltarObjetivo()
    mobileAimLatched = false
    setMobileADS(false) -- ensure virtual secondary input is released on Close/re-execute

    pcall(function() RS:UnbindFromRenderStep(RENDER_NAME) end)
    if renderConnection then renderConnection:Disconnect() end

    for _, c in ipairs(conexiones) do
        c:Disconnect()
    end

    for pl in pairs(highlights) do
        limpiarJugador(pl)
    end

    for pl in pairs(healthDisplays) do
        limpiarJugador(pl)
    end

    folder:Destroy()
    gui:Destroy()

    if env.RivalsESP_Stop == detener then
        env.RivalsESP_Stop = nil
    end

    print("[NeXLua Rivals V11 Delta ADS] Stopped")
end

env.RivalsESP_Stop = detener

--====================================
-- ACTUALIZACION
--====================================

task.spawn(function()
    while activo do
        local ok, err = pcall(actualizarESP)
        if not ok then warn("[NeXLua Rivals] ESP: " .. tostring(err)) end
        task.wait(0.25)
    end
end)

print("===================================")
print("[NeXLua Rivals V11 Delta ADS] Loaded")
print("[Wallhack ESP] Enabled by default")
print("[Head Lock 360] ON by default; mobile tries native Scope/ADS or RMB")
print("[Team recognition] Active")
print("===================================")

end, function(err)
    local message = tostring(err)
    if type(debug) == "table" and type(debug.traceback) == "function" then
        local ok, trace = pcall(debug.traceback, message, 2)
        if ok then message = trace end
    end
    return message
end)
if not __loadedOk then
    warn("[NeXLua Hub] LOAD ERROR: " .. tostring(__loadedError))
    pcall(function()
        local pl = game:GetService("Players").LocalPlayer
        local pg = pl and pl:FindFirstChildOfClass("PlayerGui")
        if not pg then return end
        local existing = pg:FindFirstChild("NeXLua_Delta_Load_Error")
        if existing then existing:Destroy() end
        local screen = Instance.new("ScreenGui")
        screen.Name = "NeXLua_Delta_Load_Error"
        screen.ResetOnSpawn = false
        screen.DisplayOrder = 1000000
        screen.Parent = pg
        local panel = Instance.new("TextLabel")
        panel.Size = UDim2.new(0.85, 0, 0, 115)
        panel.Position = UDim2.new(0.075, 0, 0.2, 0)
        panel.BackgroundColor3 = Color3.fromRGB(20, 27, 23)
        panel.TextColor3 = Color3.fromRGB(75, 255, 134)
        panel.TextWrapped = true
        panel.TextScaled = false
        panel.TextSize = 13
        panel.Font = Enum.Font.GothamBold
        panel.Text = "NeXLua Hub - LOAD ERROR\n" .. tostring(__loadedError):sub(1, 270)
        panel.Parent = screen
        Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
    end)
end
