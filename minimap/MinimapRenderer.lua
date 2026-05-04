local ADDON_NAME, NS = ...

NS.MinimapRenderer = {}
local Renderer = NS.MinimapRenderer

local HBDPins = LibStub("HereBeDragons-Pins-2.0")

--
-- Minimap Constants
--
local MINIMAP_DIAMETERS = {
    indoor = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
    outdoor = { [0] = 466.66, [1] = 400, [2] = 333.33, [3] = 266.66, [4] = 200, [5] = 133.33 },
}

local function GetCurrentMinimapDiameter()
    local zoom = Minimap:GetZoom()
    local isOutdoor = GetCVar("minimapZoom") + 0 == zoom
    local type = isOutdoor and "outdoor" or "indoor"
    return MINIMAP_DIAMETERS[type][zoom] or 466.66
end

local function GetDynamicSpacing()
    local diameter = GetCurrentMinimapDiameter()
    local minimapWidth = Minimap:GetWidth()
    local dotSize = NS.DB.settings.dotSize or 4

    -- Target 50% overlap for a very solid, smooth line.
    local targetPixelSpacing = dotSize * 0.5
    local yardsPerPixel = diameter / minimapWidth
    return targetPixelSpacing * yardsPerPixel
end

--
-- Object Pooling
--
local dotPool = {}
local activeDots = {}

local function AcquireDot()
    local dot = table.remove(dotPool)
    if not dot then
        dot = CreateFrame("Frame", nil, Minimap)
        dot:SetSize(8, 8)
        -- Set low frame level to stay behind player arrow
        dot:SetFrameLevel(Minimap:GetFrameLevel() + 1)

        dot.tex = dot:CreateTexture(nil, "ARTWORK")
        dot.tex:SetAllPoints()
        dot.tex:SetColorTexture(1, 1, 1, 1)

        dot.mask = dot:CreateMaskTexture()
        dot.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        dot.mask:SetAllPoints(dot.tex)
        dot.tex:AddMaskTexture(dot.mask)
    end
    dot:Show()
    table.insert(activeDots, dot)
    return dot
end

local function ReleaseAllDots()
    for _, dot in ipairs(activeDots) do
        dot:Hide()
        table.insert(dotPool, dot)
    end
    HBDPins:RemoveAllMinimapIcons(Renderer)
    table.wipe(activeDots)
end

--
-- Interpolation
--
local function InterpolateEdge(mapID, n1, n2, dotSpacing)
    local points = {}
    local wX1, wY1 = NS.HBD:GetWorldCoordinatesFromZone(n1.x, n1.y, mapID)
    local wX2, wY2 = NS.HBD:GetWorldCoordinatesFromZone(n2.x, n2.y, mapID)

    if not wX1 or not wX2 then return points end

    local dist = math.sqrt((wX2 - wX1) ^ 2 + (wY2 - wY1) ^ 2)
    local numDots = math.floor(dist / dotSpacing)

    if numDots <= 1 then
        table.insert(points, { x = n1.x, y = n1.y })
        table.insert(points, { x = n2.x, y = n2.y })
        return points
    end

    for i = 0, numDots do
        local t = i / numDots
        table.insert(points, {
            x = n1.x + (n2.x - n1.x) * t,
            y = n1.y + (n2.y - n1.y) * t
        })
    end

    return points
end

local routePoints = {}

function Renderer.RecalculateRoutePoints(routeName)
    local route = NS.Routes[routeName]
    if not route or not route.visible then
        routePoints[routeName] = nil
        return
    end

    routePoints[routeName] = {}
    local spacing = GetDynamicSpacing()
    local mapID = route.mapID

    for _, edge in ipairs(route.edges) do
        local n1 = route.nodes[edge[1]]
        local n2 = route.nodes[edge[2]]
        if n1 and n2 then
            local style = NS.Data.GetEffectiveEdgeStyle(route, edge)
            local er, eg, eb, ea = unpack(style.edgeColor)
            local es = style.edgeThickness

            local points = InterpolateEdge(mapID, n1, n2, spacing)
            for _, pt in ipairs(points) do
                table.insert(routePoints[routeName], {
                    x = pt.x,
                    y = pt.y,
                    mapID = mapID,
                    r = er,
                    g = eg,
                    b = eb,
                    a = ea,
                    size = es
                })
            end
        end
    end
end

function Renderer.RecalculateAll(currentMapID)
    routePoints = {}
    for name, route in pairs(NS.Routes) do
        if route.visible and route.mapID == currentMapID then
            Renderer.RecalculateRoutePoints(name)
        end
    end
end

--
-- Drawing
--
local isDirty = true
function Renderer.MarkDirty()
    isDirty = true
end

function Renderer.RedrawMinimap()
    ReleaseAllDots()
    if not NS.DB.settings.minimapEnabled then return end

    local currentMapID = NS.HBD:GetPlayerZone()
    if not currentMapID then return end

    Renderer.RecalculateAll(currentMapID)

    local dotSize = NS.DB.settings.dotSize or 4

    for _, points in pairs(routePoints) do
        for _, pt in ipairs(points) do
            local dot = AcquireDot()
            local size = pt.size or dotSize
            dot:SetSize(size, size)
            local displayAlpha = pt.a
            if size > 4 then
                displayAlpha = displayAlpha * (2 / (size * 8))
            end
            dot.tex:SetColorTexture(pt.r, pt.g, pt.b, displayAlpha)
            -- We already filtered by mapID in RecalculateAll, so these points are all in currentMapID
            HBDPins:AddMinimapIconMap(Renderer, dot, pt.mapID, pt.x, pt.y, false, false)
        end
    end
end

local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if isDirty then
        Renderer.RedrawMinimap()
        isDirty = false
    end
end)

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
EventFrame:RegisterEvent("ZONE_CHANGED")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
EventFrame:SetScript("OnEvent", function(self, event)
    Renderer.MarkDirty()
end)
