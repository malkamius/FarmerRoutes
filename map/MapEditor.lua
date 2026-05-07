local ADDON_NAME, NS = ...

NS.MapEditor = {}
local Editor = NS.MapEditor

Editor.activeRouteName = nil
Editor.selectedNodeID = nil
Editor.selectedEdge = nil -- {nodeID1, nodeID2}
Editor.draggedNodeID = nil
Editor.isDragging = false
Editor.isEditing = false

-- 
-- Canvas setup
--
local function GetCanvas()
    if WorldMapFrame.GetCanvas then
        return WorldMapFrame:GetCanvas()
    elseif WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
        return WorldMapFrame.ScrollContainer.Child
    end
    return WorldMapFrame
end

local clickFrame

local function GetClickFrame()
    if not clickFrame then
        local canvas = GetCanvas()
        if canvas then
            clickFrame = CreateFrame("Button", "FarmerRoutesEditorClickFrame", canvas)
            clickFrame:SetAllPoints()
            clickFrame:SetFrameLevel(2001) -- Above the drawing layer
            clickFrame:RegisterForClicks("LeftButtonUp", "LeftButtonDown", "RightButtonUp")
            
            clickFrame:SetScript("OnUpdate", function(self)
                if Editor.draggedNodeID and Editor.activeRouteName then
                    local cx, cy = GetCursorPosition()
                    local dist = 0
                    if Editor.dragStartX and Editor.dragStartY then
                        dist = math.sqrt((cx - Editor.dragStartX)^2 + (cy - Editor.dragStartY)^2)
                    end
                    
                    if dist > 2 then
                        Editor.isDragging = true
                        local normX, normY = GetCursorNormalizedCoords()
                        local route = NS.Routes[Editor.activeRouteName]
                        if route and route.nodes[Editor.draggedNodeID] then
                            route.nodes[Editor.draggedNodeID].x = normX
                            route.nodes[Editor.draggedNodeID].y = normY
                            if NS.MapRenderer and NS.MapRenderer.DrawRoutes then
                                NS.MapRenderer.DrawRoutes()
                            end
                            if NS.MinimapRenderer and NS.MinimapRenderer.MarkDirty then
                                NS.MinimapRenderer.MarkDirty()
                            end
                        end
                    end
                end
            end)
        end
    end
    return clickFrame
end

local function GetCursorNormalizedCoords()
    local canvas = GetCanvas()
    local left, bottom, width, height = canvas:GetRect()
    local top = bottom + height
    local x, y = GetCursorPosition()
    local scale = canvas:GetEffectiveScale()
    
    x = x / scale
    y = y / scale
    
    local normX = (x - left) / width
    local normY = (top - y) / height
    
    -- Clamp just in case
    if normX < 0 then normX = 0 end
    if normX > 1 then normX = 1 end
    if normY < 0 then normY = 0 end
    if normY > 1 then normY = 1 end
    
    return normX, normY
end

-- Math Helpers for Hit Detection
local function Distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

local function DistanceToSegment(px, py, x1, y1, x2, y2)
    local l2 = (x2 - x1)^2 + (y2 - y1)^2
    if l2 == 0 then return Distance(px, py, x1, y1) end
    
    local t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / l2
    t = math.max(0, math.min(1, t))
    
    local projX = x1 + t * (x2 - x1)
    local projY = y1 + t * (y2 - y1)
    
    return Distance(px, py, projX, projY)
end

-- Hit Detection
local NODE_HIT_RADIUS = 0.015 -- Normalized radius (approximate)
local EDGE_HIT_RADIUS = 0.010

local function GetHitTargets(normX, normY)
    if not Editor.activeRouteName then return nil, nil end
    local route = NS.Routes[Editor.activeRouteName]
    if not route then return nil, nil end
    
    local hitNodeID = nil
    local hitNodeDist = NODE_HIT_RADIUS
    
    for id, node in pairs(route.nodes) do
        local d = Distance(normX, normY, node.x, node.y)
        if d < hitNodeDist then
            hitNodeDist = d
            hitNodeID = id
        end
    end
    
    if hitNodeID then
        return "node", hitNodeID
    end
    
    -- If no node hit, check edges
    local hitEdge = nil
    local hitEdgeDist = EDGE_HIT_RADIUS
    
    for _, edge in ipairs(route.edges) do
        local n1 = route.nodes[edge[1]]
        local n2 = route.nodes[edge[2]]
        if n1 and n2 then
            local d = DistanceToSegment(normX, normY, n1.x, n1.y, n2.x, n2.y)
            if d < hitEdgeDist then
                hitEdgeDist = d
                hitEdge = edge
            end
        end
    end
    
    if hitEdge then
        return "edge", hitEdge
    end
    
    return nil, nil
end

local function OnMouseDown(self, button)
    if not Editor.activeRouteName then return end
    
    local route = NS.Routes[Editor.activeRouteName]
    if not route then return end
    
    -- Block edits if on the wrong map
    if route.mapID ~= WorldMapFrame:GetMapID() then
        return
    end

    if NS.LockedRoutes[Editor.activeRouteName] then return end
    
    local normX, normY = GetCursorNormalizedCoords()
    local hitType, hitTarget = GetHitTargets(normX, normY)
    
    if button == "LeftButton" then
        local cx, cy = GetCursorPosition()
        Editor.dragStartX = cx
        Editor.dragStartY = cy

        if hitType == "node" then
            if not IsControlKeyDown() then
                Editor.draggedNodeID = hitTarget
            end
        end
    end
end

local function OnMouseUp(self, button)
    if not Editor.activeRouteName then return end
    
    local route = NS.Routes[Editor.activeRouteName]
    if not route then return end
    
    -- Block edits if on the wrong map
    if route.mapID ~= WorldMapFrame:GetMapID() then
        print("|cFFFFFF00FarmerRoutes|r: Cannot edit route. You are not viewing the correct map.")
        return
    end
    
    -- Block edits if locked
    if NS.LockedRoutes[Editor.activeRouteName] then
        print("|cFFFFFF00FarmerRoutes|r: Route is locked. Cannot edit.")
        return
    end

    if button == "LeftButton" and Editor.draggedNodeID then
        local nodeID = Editor.draggedNodeID
        Editor.draggedNodeID = nil
        
        if Editor.isDragging then
            -- Stop dragging
            Editor.selectedNodeID = nodeID
            Editor.selectedEdge = nil
            Editor.isDragging = false
            if NS.MapRenderer and NS.MapRenderer.DrawRoutes then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer and NS.MinimapRenderer.MarkDirty then NS.MinimapRenderer.MarkDirty() end
            return -- Node was dragged, don't execute other click logic
        end
    end

    local normX, normY = GetCursorNormalizedCoords()
    local hitType, hitTarget = GetHitTargets(normX, normY)
    
    if button == "RightButton" then
        -- Delete Target or Clear Selection
        if hitType == "node" then
            NS.Data.DeleteNode(Editor.activeRouteName, hitTarget)
            if Editor.selectedNodeID == hitTarget then Editor.selectedNodeID = nil end
            if NS.MapRenderer and NS.MapRenderer.DrawRoutes then NS.MapRenderer.DrawRoutes() end
        if NS.MinimapRenderer and NS.MinimapRenderer.MarkDirty then NS.MinimapRenderer.MarkDirty() end
        elseif hitType == "edge" then
            NS.Data.DeleteEdge(Editor.activeRouteName, hitTarget[1], hitTarget[2])
            if Editor.selectedEdge == hitTarget then Editor.selectedEdge = nil end
            if NS.MapRenderer and NS.MapRenderer.DrawRoutes then NS.MapRenderer.DrawRoutes() end
        if NS.MinimapRenderer and NS.MinimapRenderer.MarkDirty then NS.MinimapRenderer.MarkDirty() end
        else
            Editor.selectedNodeID = nil
            Editor.selectedEdge = nil
            if NS.MapRenderer and NS.MapRenderer.DrawRoutes then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer and NS.MinimapRenderer.MarkDirty then NS.MinimapRenderer.MarkDirty() end
        end
        return
    end
    
    if button == "LeftButton" then
        if hitType == "node" then
            -- If Control is held, toggle link to it from previously selected node
            if IsControlKeyDown() then
                if Editor.selectedNodeID and Editor.selectedNodeID ~= hitTarget then
                    local route = NS.Routes[Editor.activeRouteName]
                    local edgeRemoved = false
                    if route then
                        for i, edge in ipairs(route.edges) do
                            if (edge[1] == Editor.selectedNodeID and edge[2] == hitTarget) or
                               (edge[1] == hitTarget and edge[2] == Editor.selectedNodeID) then
                                table.remove(route.edges, i)
                                edgeRemoved = true
                                break
                            end
                        end
                        if not edgeRemoved then
                            NS.Data.AddEdge(Editor.activeRouteName, Editor.selectedNodeID, hitTarget, NS.Utils.DeepCopy(NS.DB.settings.currentStyle))
                        end
                    end
                end
                -- After linking, select the target node
                Editor.selectedNodeID = hitTarget
                Editor.selectedEdge = nil
            else
                -- Plain click: select the node
                Editor.selectedNodeID = hitTarget
                Editor.selectedEdge = nil
            end
            
            -- Sample style
            local route = NS.Routes[Editor.activeRouteName]
            if route then
                local style = NS.Data.GetEffectiveNodeStyle(route, hitTarget)
                for k, v in pairs(style) do
                    NS.DB.settings.currentStyle[k] = NS.Utils.DeepCopy(v)
                end
                if NS.MapToolbar and NS.MapToolbar.UpdateStyleUI then NS.MapToolbar.UpdateStyleUI() end
            end
        elseif hitType == "edge" then
            if IsShiftKeyDown() then
                -- Split edge
                local n1 = hitTarget[1]
                local n2 = hitTarget[2]
                local oldStyle = hitTarget.style
                
                NS.Data.DeleteEdge(Editor.activeRouteName, n1, n2)
                local newNodeID = NS.Data.AddNode(Editor.activeRouteName, normX, normY, NS.Utils.DeepCopy(NS.DB.settings.currentStyle))
                if newNodeID then
                    NS.Data.AddEdge(Editor.activeRouteName, n1, newNodeID, oldStyle and NS.Utils.DeepCopy(oldStyle) or NS.Utils.DeepCopy(NS.DB.settings.currentStyle))
                    NS.Data.AddEdge(Editor.activeRouteName, newNodeID, n2, oldStyle and NS.Utils.DeepCopy(oldStyle) or NS.Utils.DeepCopy(NS.DB.settings.currentStyle))
                    Editor.selectedNodeID = newNodeID
                    Editor.selectedEdge = nil
                end
            else
                -- Select edge
                Editor.selectedEdge = hitTarget
                Editor.selectedNodeID = nil
                local route = NS.Routes[Editor.activeRouteName]
                if route then
                    local style = NS.Data.GetEffectiveEdgeStyle(route, hitTarget)
                    for k, v in pairs(style) do
                        NS.DB.settings.currentStyle[k] = NS.Utils.DeepCopy(v)
                    end
                    if NS.MapToolbar and NS.MapToolbar.UpdateStyleUI then NS.MapToolbar.UpdateStyleUI() end
                end
            end
        else
            -- Clicked empty space
            if IsControlKeyDown() then
                -- Add new node if Control is held
                local newNodeID = NS.Data.AddNode(Editor.activeRouteName, normX, normY, NS.Utils.DeepCopy(NS.DB.settings.currentStyle))
                if newNodeID then
                    if Editor.selectedNodeID then
                        -- Create edge from previously selected node to new node
                        NS.Data.AddEdge(Editor.activeRouteName, Editor.selectedNodeID, newNodeID, NS.Utils.DeepCopy(NS.DB.settings.currentStyle))
                    end
                    Editor.selectedNodeID = newNodeID
                    Editor.selectedEdge = nil
                end
            else
                -- Plain click on empty space: clear selection
                -- But only if we didn't move the mouse significantly (e.g. panning)
                local cx, cy = GetCursorPosition()
                local dist = 0
                if Editor.dragStartX and Editor.dragStartY then
                    dist = math.sqrt((cx - Editor.dragStartX)^2 + (cy - Editor.dragStartY)^2)
                end

                if dist < 5 then
                    Editor.selectedNodeID = nil
                    Editor.selectedEdge = nil
                end
            end
        end
        -- Refresh map
        if NS.MapRenderer and NS.MapRenderer.DrawRoutes then NS.MapRenderer.DrawRoutes() end
        if NS.MinimapRenderer and NS.MinimapRenderer.MarkDirty then NS.MinimapRenderer.MarkDirty() end
        if NS.MapToolbar and NS.MapToolbar.UpdateStyleUI then NS.MapToolbar.UpdateStyleUI() end
    end
end

-- Override GetClickFrame again to set the correct scripts
local function GetClickFrame()
    if not clickFrame then
        local canvas = GetCanvas()
        if canvas then
            clickFrame = CreateFrame("Button", "FarmerRoutesEditorClickFrame", canvas)
            clickFrame:SetAllPoints()
            clickFrame:SetFrameStrata("DIALOG")
            clickFrame:SetFrameLevel(10000) -- High level to be above other pins
            clickFrame:RegisterForClicks("LeftButtonUp", "LeftButtonDown", "RightButtonUp")
            clickFrame:SetPropagateMouseClicks(true)
            clickFrame:SetPropagateMouseMotion(true)
            clickFrame:SetScript("OnMouseDown", OnMouseDown)
            clickFrame:SetScript("OnMouseUp", OnMouseUp)
            
            clickFrame:SetScript("OnUpdate", function(self)
                -- Selective Propagation:
                -- If we are over a node/edge, or if Control is held (adding node),
                -- we block propagation so we don't click through to icons or pan the map.
                local normX, normY = GetCursorNormalizedCoords()
                local hitType, hitTarget = GetHitTargets(normX, normY)
                if hitType or IsControlKeyDown() or Editor.draggedNodeID then
                    self:SetPropagateMouseClicks(false)
                else
                    self:SetPropagateMouseClicks(true)
                end

                if Editor.draggedNodeID and Editor.activeRouteName then
                    local cx, cy = GetCursorPosition()
                    local dist = 0
                    if Editor.dragStartX and Editor.dragStartY then
                        dist = math.sqrt((cx - Editor.dragStartX)^2 + (cy - Editor.dragStartY)^2)
                    end
                    
                    if dist > 2 then
                        Editor.isDragging = true
                        local normX, normY = GetCursorNormalizedCoords()
                        local route = NS.Routes[Editor.activeRouteName]
                        if route and route.nodes[Editor.draggedNodeID] then
                            route.nodes[Editor.draggedNodeID].x = normX
                            route.nodes[Editor.draggedNodeID].y = normY
                            if NS.MapRenderer and NS.MapRenderer.DrawRoutes then
                                NS.MapRenderer.DrawRoutes()
                            end
                            if NS.MinimapRenderer and NS.MinimapRenderer.MarkDirty then
                                NS.MinimapRenderer.MarkDirty()
                            end
                        end
                    end
                end
            end)
        end
    end
    return clickFrame
end

--
-- API
--
function Editor.SetEditMode(routeName)
    if routeName and NS.Routes[routeName] then
        Editor.activeRouteName = routeName
        Editor.selectedNodeID = nil
        Editor.selectedEdge = nil
        if Editor.isEditing then
            local cf = GetClickFrame()
            if cf then cf:Show() end
        end
    else
        Editor.activeRouteName = nil
        Editor.selectedNodeID = nil
        Editor.selectedEdge = nil
        if clickFrame then clickFrame:Hide() end
    end
    
    if NS.MapRenderer and NS.MapRenderer.DrawRoutes then NS.MapRenderer.DrawRoutes() end
end

function Editor.ToggleEditing(state)
    if state ~= nil then
        Editor.isEditing = state
    else
        Editor.isEditing = not Editor.isEditing
    end
    
    if Editor.isEditing and Editor.activeRouteName then
        local cf = GetClickFrame()
        if cf then cf:Show() end
    else
        if clickFrame then clickFrame:Hide() end
    end
    
    if NS.MapRenderer and NS.MapRenderer.DrawRoutes then
        NS.MapRenderer.DrawRoutes()
    end
end

function Editor.GetSelectedNode()
    return Editor.selectedNodeID
end

function Editor.GetSelectedEdge()
    return Editor.selectedEdge
end

function Editor.UpdateSelectedStyle(oldStyle)
    if not Editor.activeRouteName then return end
    local route = NS.Routes[Editor.activeRouteName]
    if not route then return end
    
    local style = NS.Utils.DeepCopy(NS.DB.settings.currentStyle)
    
    if Editor.selectedNodeID then
        local node = route.nodes[Editor.selectedNodeID]
        if node then
            node.style = style
        end
    elseif Editor.selectedEdge then
        -- Editor.selectedEdge is a reference to the edge table {node1, node2, style=...}
        Editor.selectedEdge.style = style
    else
        -- No selection: Update route-level style and propagate to matching elements
        route.style = route.style or {}
        
        -- Helper to check if two values are "effectively equal" (for colors and numbers)
        local function IsEquivalent(v1, v2)
            if v1 == v2 then return true end
            if type(v1) == "table" and type(v2) == "table" then
                if #v1 ~= #v2 then return false end
                for i = 1, #v1 do
                    if v1[i] ~= v2[i] then return false end
                end
                return true
            end
            return false
        end

        -- Helper to check if a style matches another style or global style
        local function MatchesOriginal(s, original, globalVal)
            if not s then return true end -- Inheriting
            if IsEquivalent(s, original) then return true end
            if IsEquivalent(s, globalVal) then return true end
            return false
        end

        local global = NS.DB.settings.globalStyle

        -- Update route style
        for k, v in pairs(style) do
            route.style[k] = NS.Utils.DeepCopy(v)
        end

        -- Propagate to nodes
        for _, node in pairs(route.nodes) do
            if node.style then
                if oldStyle then
                    if MatchesOriginal(node.style.nodeColor, oldStyle.nodeColor, global.nodeColor) then
                        node.style.nodeColor = NS.Utils.DeepCopy(style.nodeColor)
                    end
                    if MatchesOriginal(node.style.nodeSize, oldStyle.nodeSize, global.nodeSize) then
                        node.style.nodeSize = style.nodeSize
                    end
                end
            end
        end

        -- Propagate to edges
        for _, edge in ipairs(route.edges) do
            if edge.style then
                if oldStyle then
                    if MatchesOriginal(edge.style.edgeColor, oldStyle.edgeColor, global.edgeColor) then
                        edge.style.edgeColor = NS.Utils.DeepCopy(style.edgeColor)
                    end
                    if MatchesOriginal(edge.style.edgeThickness, oldStyle.edgeThickness, global.edgeThickness) then
                        edge.style.edgeThickness = style.edgeThickness
                    end
                end
            end
        end
    end
    
    if NS.MapRenderer and NS.MapRenderer.DrawRoutes then NS.MapRenderer.DrawRoutes() end
    if NS.MinimapRenderer and NS.MinimapRenderer.MarkDirty then NS.MinimapRenderer.MarkDirty() end
end
