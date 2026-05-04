local ADDON_NAME, NS = ...

NS.NavigationHUD = {}
local HUD = NS.NavigationHUD

local HBD = NS.HBD

local hudFrame = CreateFrame("Frame", "FarmerRoutesNavigationHUD", UIParent)
hudFrame:SetSize(72, 72) -- Reduced from 80x80
hudFrame:SetPoint("CENTER", 0, 150)
hudFrame:SetMovable(true)
hudFrame:EnableMouse(true)
hudFrame:RegisterForDrag("LeftButton")
hudFrame:Hide()

-- Background Box
local bg = hudFrame:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.4)
bg:SetAlpha(0) -- Transparent by default

local border = hudFrame:CreateTexture(nil, "BORDER")
border:SetPoint("TOPLEFT", -1, 1)
border:SetPoint("BOTTOMRIGHT", 1, -1)
border:SetColorTexture(1, 1, 1, 0.2)
border:SetAlpha(0) -- Transparent by default

-- Hover logic
hudFrame:SetScript("OnEnter", function()
    bg:SetAlpha(1)
    border:SetAlpha(1)
end)
hudFrame:SetScript("OnLeave", function()
    bg:SetAlpha(0)
    border:SetAlpha(0)
end)

-- Draggable logic
hudFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
hudFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    if NS.DB and NS.DB.settings then
        NS.DB.settings.hudPosition = {
            point = point,
            relativePoint = relativePoint,
            xOfs = xOfs,
            yOfs = yOfs
        }
    end
end)

-- Right-click to hide
hudFrame:SetScript("OnMouseDown", function(self, button)
    if button == "RightButton" then
        if NS.DB and NS.DB.settings then
            NS.DB.settings.hudEnabled = false
            HUD.UpdateVisibility()
            print("|cFFFFFF00FarmerRoutes|r: Navigation HUD disabled. Re-enable in settings or via minimap button.")
        end
    end
end)

local arrowTexture = hudFrame:CreateTexture(nil, "OVERLAY")
arrowTexture:SetTexture("Interface\\Minimap\\MinimapArrow")
arrowTexture:SetSize(64, 64)
arrowTexture:SetPoint("CENTER", hudFrame, "CENTER", 0, 5)

local distanceText = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
if distanceText:GetFont() then
    local fontPath, height, flags = distanceText:GetFont()
    distanceText:SetFont(fontPath, height, "OUTLINE")
end
distanceText:SetPoint("TOP", hudFrame, "BOTTOM", 0, 5)

local lastX, lastY = nil, nil
local velocityX, velocityY = 0, 0
local currentTargetNodeID = nil
local lastTargetX, lastTargetY, lastInstance = nil, nil, nil

local function DistSqToSegment(px, py, ax, ay, bx, by)
    local l2 = (bx - ax) ^ 2 + (by - ay) ^ 2
    if l2 == 0 then return (px - ax) ^ 2 + (py - ay) ^ 2 end
    local t = math.max(0, math.min(1, ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / l2))
    local projx = ax + t * (bx - ax)
    local projy = ay + t * (by - ay)
    return (px - projx) ^ 2 + (py - projy) ^ 2
end

local function FindTargetNode()
    local px, py, pInstance = HBD:GetPlayerWorldPosition()
    if not px or not py then return nil, nil, nil end

    -- Update velocity
    if lastX and lastY then
        local dx = px - lastX
        local dy = py - lastY
        -- Exponential moving average for smoothing
        velocityX = velocityX * 0.8 + dx * 0.2
        velocityY = velocityY * 0.8 + dy * 0.2
    end
    lastX, lastY = px, py

    local closestDistSq = math.huge
    local bestEdge = nil
    local bestRoute = nil

    local currentZone = C_Map.GetBestMapForUnit("player")

    for routeName, route in pairs(NS.Routes) do
        if route.visible and route.mapID == currentZone and route.edges and route.nodes then
            for _, edge in ipairs(route.edges) do
                local n1 = route.nodes[edge[1]]
                local n2 = route.nodes[edge[2]]
                if n1 and n2 then
                    local ax, ay = HBD:GetWorldCoordinatesFromZone(n1.x, n1.y, route.mapID)
                    local bx, by = HBD:GetWorldCoordinatesFromZone(n2.x, n2.y, route.mapID)

                    if ax and ay and bx and by then
                        local distSq = DistSqToSegment(px, py, ax, ay, bx, by)
                        if distSq < closestDistSq then
                            closestDistSq = distSq
                            bestEdge = edge
                            bestRoute = route
                        end
                    end
                end
            end
        end
    end

    if bestEdge and bestRoute then
        local n1ID = bestEdge[1]
        local n2ID = bestEdge[2]
        local n1 = bestRoute.nodes[n1ID]
        local n2 = bestRoute.nodes[n2ID]
        local ax, ay = HBD:GetWorldCoordinatesFromZone(n1.x, n1.y, bestRoute.mapID)
        local bx, by = HBD:GetWorldCoordinatesFromZone(n2.x, n2.y, bestRoute.mapID)

        local edgeVx = bx - ax
        local edgeVy = by - ay

        local targetNode = n2
        local speedSq = velocityX ^ 2 + velocityY ^ 2

        -- If moving faster than a very slow crawl
        if speedSq > 0.001 then
            local dot = velocityX * edgeVx + velocityY * edgeVy
            if dot < 0 then
                targetNode = n1
                currentTargetNodeID = n1ID
            else
                currentTargetNodeID = n2ID
            end
        else
            -- If stationary, try to stick to the previous target if it's on this edge
            if currentTargetNodeID == n1ID then
                targetNode = n1
            elseif currentTargetNodeID == n2ID then
                targetNode = n2
            else
                targetNode = n2 -- default to n2
                currentTargetNodeID = n2ID
            end
        end

        local tx, ty = HBD:GetWorldCoordinatesFromZone(targetNode.x, targetNode.y, bestRoute.mapID)

        -- If we are close to the target node, try to look ahead to the next node
        if tx and ty then
            local dx, dy = px - tx, py - ty
            local distSq = dx * dx + dy * dy
            if distSq < 400 then -- 20 yards threshold (20^2)
                local nextNodeID = nil
                local otherNodeID = (currentTargetNodeID == n1ID) and n2ID or n1ID

                -- Look for an edge connected to currentTargetNodeID that isn't the one we're currently on
                for _, edge in ipairs(bestRoute.edges) do
                    if edge[1] == currentTargetNodeID and edge[2] ~= otherNodeID then
                        nextNodeID = edge[2]
                        break
                    elseif edge[2] == currentTargetNodeID and edge[1] ~= otherNodeID then
                        nextNodeID = edge[1]
                        break
                    end
                end

                if nextNodeID then
                    local nextNode = bestRoute.nodes[nextNodeID]
                    if nextNode then
                        local ntx, nty = HBD:GetWorldCoordinatesFromZone(nextNode.x, nextNode.y, bestRoute.mapID)
                        if ntx and nty then
                            tx, ty = ntx, nty
                        end
                    end
                end
            end
        end
        lastTargetX, lastTargetY, lastInstance = tx, ty, pInstance
        return tx, ty, pInstance
    end

    return nil, nil, nil
end

local updateThrottle = 0
hudFrame:SetScript("OnUpdate", function(self, elapsed)
    updateThrottle = updateThrottle + elapsed
    if updateThrottle < 0.05 then return end
    updateThrottle = 0

    local tx, ty, pInstance = FindTargetNode()

    if tx and ty and pInstance then
        local px, py, instance = HBD:GetPlayerWorldPosition()
        if instance == pInstance then
            local angle, distance = HBD:GetWorldVector(instance, px, py, tx, ty)
            if angle and distance then
                local facing = GetPlayerFacing()
                if facing then
                    -- math.pi*2 ensures it's positive, though SetRotation handles negatives
                    local rotation = angle - facing
                    arrowTexture:SetRotation(rotation)
                    distanceText:SetText(math.floor(distance) .. " yd")
                end
            end
        end
    else
        distanceText:SetText("")
    end
end)

function HUD.UpdateVisibility()
    -- Only show if enabled in settings and out of combat
    local show = NS.DB.settings.hudEnabled and not InCombatLockdown()

    -- Check if there are visible routes in the current zone
    local hasVisibleRoutes = false
    local currentZone = C_Map.GetBestMapForUnit("player")
    if currentZone and NS.Routes then
        for _, route in pairs(NS.Routes) do
            if route.visible and route.mapID == currentZone then
                hasVisibleRoutes = true
                break
            end
        end
    end

    if show and hasVisibleRoutes then
        hudFrame:Show()
    else
        hudFrame:Hide()
        lastX, lastY = nil, nil
        velocityX, velocityY = 0, 0
    end
end

-- Event handling to toggle visibility based on combat/zone
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:SetScript("OnEvent", function(self, event)
    HUD.UpdateVisibility()
end)

function HUD.UpdatePosition()
    if NS.DB and NS.DB.settings and NS.DB.settings.hudPosition then
        local pos = NS.DB.settings.hudPosition
        hudFrame:ClearAllPoints()
        hudFrame:SetPoint(pos.point, UIParent, pos.relativePoint or pos.point, pos.xOfs, pos.yOfs)
    end
end

-- Initialize visibility after a short delay so routes and DB have time to load
C_Timer.After(2, function()
    HUD.UpdatePosition()
    HUD.UpdateVisibility()
end)
