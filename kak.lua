-- Services
local runService = game:GetService('RunService')
local coregui = game:GetService('CoreGui')
local players = game:GetService('Players')
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera

-- ESP Settings
local esp = {
    enabled = true,
    teamCheck = true,
    visibilityCheck = true,
    outlines = true,
    limitDistance = true,
    shortNames = false,
    maxDistance = 1200,
    fadeFactor = 20,
    arrowRadius = 500,
    arrowSize = 20,
    arrowInfo = true,
    font = 'Plex',
    textSize = 13,
    maxChar = 4,

    -- Colors
    teamColor = Color3.new(0, 1, 0),
    enemyColor = Color3.new(1, 0, 0),
    priorityColor = Color3.new(1, 1, 0),

    -- Toggles
    showBoxes = true,
    showHealthBars = true,
    showNames = true,
    showDistance = true,
    showWeapons = true,
    showArrows = true,
    showChams = true,

    -- Internal
    players = {},
    priorityPlayers = {},
    connections = {},
    visibleCheckParams = {}
}

-- Optimized Functions
local function draw(type, properties)
    local instance = Drawing.new(type)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    return instance
end

local function create(type, properties)
    local instance = Instance.new(type)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    return instance
end

local function raycast(origin, direction, ignoreList)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = ignoreList
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.IgnoreWater = true
    return workspace:Raycast(origin, direction, params)
end

local function checkAlive(player)
    local character = player.Character
    return character and character:FindFirstChild('Humanoid') and character.Humanoid.Health > 0
end

local function checkTeam(player)
    return player.Team ~= localPlayer.Team
end

local function checkVisible(character)
    local head = character:FindFirstChild('Head')
    if not head then return false end
    local ray = raycast(camera.CFrame.Position, (head.Position - camera.CFrame.Position).Unit * 1000, {camera, localPlayer.Character})
    return ray and ray.Instance:IsDescendantOf(character)
end

-- ESP Drawing Functions
local function createESP(player)
    local espObjects = {
        box = draw('Square', {Visible = false, Thickness = 1}),
        boxOutline = draw('Square', {Visible = false, Thickness = 1}),
        healthBar = draw('Square', {Visible = false, Thickness = 1}),
        name = draw('Text', {Visible = false, Size = esp.textSize, Font = Drawing.Fonts[esp.font]}),
        distance = draw('Text', {Visible = false, Size = esp.textSize, Font = Drawing.Fonts[esp.font]}),
        weapon = draw('Text', {Visible = false, Size = esp.textSize, Font = Drawing.Fonts[esp.font]}),
        arrow = draw('Triangle', {Visible = false, Thickness = 1}),
        chams = create('Highlight', {Parent = coregui, Enabled = false})
    }
    esp.players[player] = espObjects
end

local function updateESP(player)
    local espObjects = esp.players[player]
    if not espObjects or not checkAlive(player) then return end

    local character = player.Character
    local rootPart = character:FindFirstChild('HumanoidRootPart')
    local head = character:FindFirstChild('Head')
    if not rootPart or not head then return end

    local isEnemy = checkTeam(player)
    local isVisible = checkVisible(character)
    local distance = (rootPart.Position - camera.CFrame.Position).Magnitude
    local fade = math.clamp(1 - (distance / esp.maxDistance) * esp.fadeFactor, 0, 1)

    -- Box ESP
    if esp.showBoxes then
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        for _, part in pairs(character:GetChildren()) do
            if part:IsA('BasePart') then
                local pos = camera:WorldToViewportPoint(part.Position)
                minX = math.min(minX, pos.X)
                minY = math.min(minY, pos.Y)
                maxX = math.max(maxX, pos.X)
                maxY = math.max(maxY, pos.Y)
            end
        end
        espObjects.box.Visible = true
        espObjects.box.Size = Vector2.new(maxX - minX, maxY - minY)
        espObjects.box.Position = Vector2.new(minX, minY)
        espObjects.box.Color = isEnemy and esp.enemyColor or esp.teamColor
        espObjects.box.Transparency = fade

        espObjects.boxOutline.Visible = esp.outlines
        espObjects.boxOutline.Size = espObjects.box.Size
        espObjects.boxOutline.Position = espObjects.box.Position
        espObjects.boxOutline.Color = Color3.new(0, 0, 0)
        espObjects.boxOutline.Transparency = fade
    end

    -- Health Bar
    if esp.showHealthBars then
        local health = character.Humanoid.Health
        espObjects.healthBar.Visible = true
        espObjects.healthBar.Size = Vector2.new(2, (maxY - minY) * (health / 100))
        espObjects.healthBar.Position = Vector2.new(minX - 5, minY + (maxY - minY) * (1 - health / 100))
        espObjects.healthBar.Color = Color3.new(1 - health / 100, health / 100, 0)
        espObjects.healthBar.Transparency = fade
    end

    -- Name and Distance
    if esp.showNames then
        espObjects.name.Visible = true
        espObjects.name.Text = player.Name
        espObjects.name.Position = Vector2.new(minX + (maxX - minX) / 2 - espObjects.name.TextBounds.X / 2, minY - 20)
        espObjects.name.Color = isEnemy and esp.enemyColor or esp.teamColor
        espObjects.name.Transparency = fade

        if esp.showDistance then
            espObjects.distance.Visible = true
            espObjects.distance.Text = `[{math.floor(distance)}m]`
            espObjects.distance.Position = Vector2.new(minX + (maxX - minX) / 2 - espObjects.distance.TextBounds.X / 2, minY - 35)
            espObjects.distance.Color = isEnemy and esp.enemyColor or esp.teamColor
            espObjects.distance.Transparency = fade
        end
    end

    -- Weapon
    if esp.showWeapons then
        local weapon = character:FindFirstChildOfClass('Tool')
        espObjects.weapon.Visible = weapon ~= nil
        if weapon then
            espObjects.weapon.Text = weapon.Name
            espObjects.weapon.Position = Vector2.new(minX + (maxX - minX) / 2 - espObjects.weapon.TextBounds.X / 2, maxY + 5)
            espObjects.weapon.Color = isEnemy and esp.enemyColor or esp.teamColor
            espObjects.weapon.Transparency = fade
        end
    end

    -- Chams
    if esp.showChams then
        espObjects.chams.Enabled = true
        espObjects.chams.Adornee = character
        espObjects.chams.FillColor = isEnemy and esp.enemyColor or esp.teamColor
        espObjects.chams.OutlineColor = Color3.new(0, 0, 0)
        espObjects.chams.FillTransparency = 0.5
        espObjects.chams.OutlineTransparency = 0
    end

    -- Arrow
    if esp.showArrows and not isVisible then
        local direction = (rootPart.Position - camera.CFrame.Position).Unit
        local angle = math.atan2(direction.Z, direction.X)
        local pos = Vector2.new(math.cos(angle), math.sin(angle)) * esp.arrowRadius + camera.ViewportSize / 2
        espObjects.arrow.Visible = true
        espObjects.arrow.PointA = pos
        espObjects.arrow.PointB = pos - Vector2.new(math.cos(angle + math.rad(30)), math.sin(angle + math.rad(30))) * esp.arrowSize
        espObjects.arrow.PointC = pos - Vector2.new(math.cos(angle - math.rad(30)), math.sin(angle - math.rad(30))) * esp.arrowSize
        espObjects.arrow.Color = isEnemy and esp.enemyColor or esp.teamColor
        espObjects.arrow.Transparency = fade
    end
end

-- Main Loop
runService.RenderStepped:Connect(function()
    for player, espObjects in pairs(esp.players) do
        if player ~= localPlayer and checkAlive(player) then
            updateESP(player)
        else
            for _, obj in pairs(espObjects) do
                obj.Visible = false
            end
            if espObjects.chams then
                espObjects.chams.Enabled = false
            end
        end
    end
end)

-- Player Added/Removed
players.PlayerAdded:Connect(function(player)
    createESP(player)
end)

players.PlayerRemoving:Connect(function(player)
    if esp.players[player] then
        for _, obj in pairs(esp.players[player]) do
            obj:Remove()
        end
        esp.players[player] = nil
    end
end)

-- Initialize ESP for existing players
for _, player in pairs(players:GetPlayers()) do
    if player ~= localPlayer then
        createESP(player)
    end
end

return esp
