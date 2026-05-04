local ADDON_NAME, NS = ...

NS.Data = {}
local Data = NS.Data

-- Data model for a route:
-- {
--   name = "String",
--   mapID = 123,
--   color = {r, g, b, a},
--   visible = true,
--   nextNodeID = 1,
--   nodes = {
--     [1] = {x = 0.5, y = 0.5, style = {nodeColor={r,g,b,a}, nodeSize=8}},
--     [2] = {x = 0.6, y = 0.5, style = {nodeColor={r,g,b,a}, nodeSize=8}},
--   },
--   edges = {
--     -- Arrays of {nodeID1, nodeID2, style = {edgeColor={r,g,b,a}, edgeThickness=2}}
--     {1, 2, style = {edgeColor={r,g,b,a}, edgeThickness=2}},
--   }
-- }

--
-- Routes
--

function Data.CreateRoute(name, mapID)
    if not name or name == "" or NS.Routes[name] then return false end
    
    local defaultColor = NS.DB.settings.routeColors
    
    NS.Routes[name] = {
        name = name,
        mapID = mapID,
        color = {defaultColor[1], defaultColor[2], defaultColor[3], defaultColor[4]},
        visible = true,
        nextNodeID = 1,
        nodes = {},
        edges = {}
    }
    
    return true
end

function Data.GenerateNewRouteName(mapID)
    local mapInfo = C_Map.GetMapInfo(mapID)
    local zoneName = mapInfo and mapInfo.name or "New Route"
    
    -- Count routes in this zone
    local count = 0
    for _, route in pairs(NS.Routes) do
        if route.mapID == mapID then
            count = count + 1
        end
    end
    
    local name
    local i = count + 1
    repeat
        name = zoneName .. " " .. i
        i = i + 1
    until not NS.Routes[name]
    
    return name
end

function Data.GetRoute(name)
    return NS.Routes[name]
end

function Data.DeleteRoute(name)
    if NS.LockedRoutes[name] then return false end
    NS.Routes[name] = nil
    return true
end

function Data.RenameRoute(oldName, newName)
    if NS.LockedRoutes[oldName] or NS.Routes[newName] or newName == "" then return false end
    
    local route = NS.Routes[oldName]
    route.name = newName
    NS.Routes[newName] = route
    NS.Routes[oldName] = nil
    
    -- Also move lock status if it exists
    if NS.LockedRoutes[oldName] then
        NS.LockedRoutes[newName] = true
        NS.LockedRoutes[oldName] = nil
    end
    
    return true
end

--
-- Nodes
--

function Data.AddNode(routeName, x, y, style)
    local route = NS.Routes[routeName]
    if not route or NS.LockedRoutes[routeName] then return nil end
    
    local id = route.nextNodeID
    route.nextNodeID = route.nextNodeID + 1
    
    route.nodes[id] = {x = x, y = y, style = style}
    return id
end

function Data.DeleteNode(routeName, nodeID)
    local route = NS.Routes[routeName]
    if not route or NS.LockedRoutes[routeName] then return false end
    if not route.nodes[nodeID] then return false end
    
    route.nodes[nodeID] = nil
    
    -- Remove any edges connected to this node
    for i = #route.edges, 1, -1 do
        local edge = route.edges[i]
        if edge[1] == nodeID or edge[2] == nodeID then
            table.remove(route.edges, i)
        end
    end
    
    return true
end

--
-- Edges
--

-- Check if an edge already exists between two nodes
function Data.HasEdge(routeName, nodeID1, nodeID2)
    local route = NS.Routes[routeName]
    if not route then return false end
    
    for i, edge in ipairs(route.edges) do
        if (edge[1] == nodeID1 and edge[2] == nodeID2) or 
           (edge[1] == nodeID2 and edge[2] == nodeID1) then
            return i, edge
        end
    end
    
    return false
end

function Data.AddEdge(routeName, nodeID1, nodeID2, style)
    local route = NS.Routes[routeName]
    if not route or NS.LockedRoutes[routeName] then return false end
    
    -- Ensure both nodes exist
    if not route.nodes[nodeID1] or not route.nodes[nodeID2] then return false end
    
    -- Ensure edge doesn't already exist
    if Data.HasEdge(routeName, nodeID1, nodeID2) then return false end
    
    table.insert(route.edges, {nodeID1, nodeID2, style = style})
    return true
end

function Data.DeleteEdge(routeName, nodeID1, nodeID2)
    local route = NS.Routes[routeName]
    if not route or NS.LockedRoutes[routeName] then return false end
    
    local index = Data.HasEdge(routeName, nodeID1, nodeID2)
    if index then
        table.remove(route.edges, index)
        return true
    end
    
    return false
end

--
-- Locking
--

function Data.SetRouteLock(name, locked)
    if not NS.Routes[name] then return false end
    NS.LockedRoutes[name] = locked or nil
    return true
end

function Data.IsRouteLocked(name)
    return NS.LockedRoutes[name] == true
end

--
-- Visibility & Color
--

function Data.SetRouteVisible(name, visible)
    local route = NS.Routes[name]
    if not route or NS.LockedRoutes[name] then return false end
    route.visible = visible
    return true
end

function Data.SetRouteColor(name, r, g, b, a)
    local route = NS.Routes[name]
    if not route or NS.LockedRoutes[name] then return false end
    route.color = {r, g, b, a}
    return true
end

--
-- Style Inheritance
--

function Data.GetEffectiveNodeStyle(route, nodeID)
    local node = route.nodes[nodeID]
    local global = NS.DB.settings.globalStyle
    local rs = route.style
    local ns = node and node.style
    
    return {
        nodeColor = (ns and ns.nodeColor) or (rs and rs.nodeColor) or global.nodeColor,
        nodeSize = (ns and ns.nodeSize) or (rs and rs.nodeSize) or global.nodeSize,
    }
end

function Data.GetEffectiveEdgeStyle(route, edge)
    local global = NS.DB.settings.globalStyle
    local rs = route.style
    local es = edge and edge.style
    
    return {
        edgeColor = (es and es.edgeColor) or (rs and rs.edgeColor) or global.edgeColor,
        edgeThickness = (es and es.edgeThickness) or (rs and rs.edgeThickness) or global.edgeThickness,
    }
end
