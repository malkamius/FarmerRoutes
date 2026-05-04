local ADDON_NAME, NS = ...

NS.MinimapRenderer = {}
local Renderer = NS.MinimapRenderer

local HBD = LibStub("HereBeDragons-2.0")

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

--
-- Object Pooling
--
local linePool = {}
local activeLines = {}
local activeEdges = {}

local function AcquireLine()
    local line = table.remove(linePool)
    if not line then
        line = Minimap:CreateLine(nil, "OVERLAY")
        line:SetDrawLayer("OVERLAY", 7)
    end
    line:Show()
    table.insert(activeLines, line)
    return line
end

local function ReleaseAllLines()
    for _, line in ipairs(activeLines) do
        line:Hide()
        table.insert(linePool, line)
    end
    table.wipe(activeLines)
end

--
-- Math Clipping
--
local function ClipLineToCircle(x1, y1, x2, y2, radius)
    local dx = x2 - x1
    local dy = y2 - y1
    
    local a = dx*dx + dy*dy
    if a == 0 then
        if x1*x1 + y1*y1 <= radius*radius then
            return x1, y1, x2, y2
        else
            return nil
        end
    end
    
    local b = 2 * (x1*dx + y1*dy)
    local c = x1*x1 + y1*y1 - radius*radius
    
    local discriminant = b*b - 4*a*c
    if discriminant < 0 then
        return nil -- No intersection
    end
    
    local sqrtDisc = math.sqrt(discriminant)
    local t1 = (-b - sqrtDisc) / (2*a)
    local t2 = (-b + sqrtDisc) / (2*a)
    
    local tStart = math.max(0, math.min(t1, t2))
    local tEnd = math.min(1, math.max(t1, t2))
    
    if tStart > 1 or tEnd < 0 or tStart > tEnd then
        return nil -- Segment is outside the circle
    end
    
    return x1 + tStart*dx, y1 + tStart*dy, x1 + tEnd*dx, y1 + tEnd*dy
end

local function ClipLineToRectangle(x1, y1, x2, y2, w, h)
    local t0, t1 = 0, 1
    local dx = x2 - x1
    local dy = y2 - y1
    
    local function clip(p, q)
        if p == 0 and q < 0 then return false end
        if p < 0 then
            local r = q / p
            if r > t1 then return false end
            if r > t0 then t0 = r end
        elseif p > 0 then
            local r = q / p
            if r < t0 then return false end
            if r < t1 then t1 = r end
        end
        return true
    end
    
    if clip(-dx, x1 + w) and
       clip(dx, w - x1) and
       clip(-dy, y1 + h) and
       clip(dy, h - y1) then
        return x1 + t0*dx, y1 + t0*dy, x1 + t1*dx, y1 + t1*dy
    end
    return nil
end

--
-- Rendering Logic
--
local isDirty = true
function Renderer.MarkDirty()
    isDirty = true
end

function Renderer.RecalculateAll(currentMapID)
    activeEdges = {}
    for name, route in pairs(NS.Routes) do
        if route.visible and route.mapID == currentMapID then
            for _, edge in ipairs(route.edges) do
                local n1 = route.nodes[edge[1]]
                local n2 = route.nodes[edge[2]]
                if n1 and n2 then
                    local style = NS.Data.GetEffectiveEdgeStyle(route, edge)
                    
                    local wx1, wy1 = HBD:GetWorldCoordinatesFromZone(n1.x, n1.y, currentMapID)
                    local wx2, wy2 = HBD:GetWorldCoordinatesFromZone(n2.x, n2.y, currentMapID)
                    
                    if wx1 and wx2 then
                        table.insert(activeEdges, {
                            r = style.edgeColor[1],
                            g = style.edgeColor[2],
                            b = style.edgeColor[3],
                            a = style.edgeColor[4],
                            thickness = style.edgeThickness,
                            wX1 = wx1, wY1 = wy1,
                            wX2 = wx2, wY2 = wy2
                        })
                    end
                end
            end
        end
    end
end

function Renderer.RedrawMinimap()
    ReleaseAllLines()
    if not NS.DB.settings.minimapEnabled then return end

    local currentMapID = HBD:GetPlayerZone()
    if not currentMapID then return end

    Renderer.RecalculateAll(currentMapID)
end

--
-- OnUpdate
--
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function(self, elapsed)
    if isDirty then
        Renderer.RedrawMinimap()
        isDirty = false
    end
    
    if not NS.DB.settings.minimapEnabled or #activeEdges == 0 then return end
    
    local px, py, instanceID = HBD:GetPlayerWorldPosition()
    if not px or not py then return end
    
    local facing = GetPlayerFacing() or 0
    local rotateMinimap = GetCVar("rotateMinimap") == "1"
    
    local mapRadius = GetCurrentMinimapDiameter() / 2
    local minimapWidth = Minimap:GetWidth() / 2
    local minimapHeight = Minimap:GetHeight() / 2
    local displayRadius = math.min(minimapWidth, minimapHeight)
    
    local sinFacing, cosFacing = 0, 1
    if rotateMinimap then
        sinFacing = math.sin(facing)
        cosFacing = math.cos(facing)
    end
    
    -- Sync number of lines to active edges
    while #activeLines < #activeEdges do
        AcquireLine()
    end
    while #activeLines > #activeEdges do
        local line = table.remove(activeLines)
        line:Hide()
        table.insert(linePool, line)
    end
    
    for i, edge in ipairs(activeEdges) do
        local line = activeLines[i]
        
        -- Start point
        local xDist1, yDist1 = px - edge.wX1, py - edge.wY1
        if rotateMinimap then
            local dx, dy = xDist1, yDist1
            xDist1 = dx * cosFacing - dy * sinFacing
            yDist1 = dx * sinFacing + dy * cosFacing
        end
        local pixelX1 = (xDist1 / mapRadius) * minimapWidth
        local pixelY1 = -(yDist1 / mapRadius) * minimapHeight
        
        -- End point
        local xDist2, yDist2 = px - edge.wX2, py - edge.wY2
        if rotateMinimap then
            local dx, dy = xDist2, yDist2
            xDist2 = dx * cosFacing - dy * sinFacing
            yDist2 = dx * sinFacing + dy * cosFacing
        end
        local pixelX2 = (xDist2 / mapRadius) * minimapWidth
        local pixelY2 = -(yDist2 / mapRadius) * minimapHeight
        
        -- Clip to Minimap Radius to prevent lines bleeding outside UI
        local cx1, cy1, cx2, cy2
        local isRound = true
        if GetMinimapShape then
            isRound = (GetMinimapShape() and GetMinimapShape() == "ROUND")
        end
        
        if isRound then
            cx1, cy1, cx2, cy2 = ClipLineToCircle(pixelX1, pixelY1, pixelX2, pixelY2, displayRadius)
        else
            cx1, cy1, cx2, cy2 = ClipLineToRectangle(pixelX1, pixelY1, pixelX2, pixelY2, minimapWidth, minimapHeight)
        end
        
        if cx1 then
            line:SetStartPoint("CENTER", Minimap, cx1, cy1)
            line:SetEndPoint("CENTER", Minimap, cx2, cy2)
            
            line:SetThickness(edge.thickness or 4)
            line:SetColorTexture(edge.r, edge.g, edge.b, edge.a)
            line:Show()
        else
            line:Hide()
        end
    end
end)

--
-- Events
--
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
EventFrame:RegisterEvent("ZONE_CHANGED")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
EventFrame:SetScript("OnEvent", function(self, event)
    Renderer.MarkDirty()
end)
