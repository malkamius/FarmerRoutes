local ADDON_NAME, NS = ...

NS.ImportExport = {}
local ImportExport = NS.ImportExport

-- Format Versions:
-- 1: Initial Graph Format (FR!1!wowFlavor!name!mapID!color!nodes!edges)

function ImportExport.ExportRoute(routeName)
    local route = NS.Data.GetRoute(routeName)
    if not route then return nil end

    local color = route.color
    local colorStr = string.format("%.2f,%.2f,%.2f,%.2f", color[1], color[2], color[3], color[4])
    
    local nodeParts = {}
    for id, pos in pairs(route.nodes) do
        table.insert(nodeParts, string.format("%d,%.4f,%.4f", id, pos.x, pos.y))
    end
    local nodesStr = table.concat(nodeParts, ";")
    
    local edgeParts = {}
    for _, edge in ipairs(route.edges) do
        table.insert(edgeParts, string.format("%d,%d", edge[1], edge[2]))
    end
    local edgesStr = table.concat(edgeParts, ";")
    
    local parts = {
        "FR",
        "1", -- Format Version
        NS.WOW_FLAVOR or "Unknown",
        route.name,
        tostring(route.mapID),
        colorStr,
        nodesStr,
        edgesStr
    }
    
    return table.concat(parts, "!")
end

function ImportExport.ImportRoute(str)
    if not str or str == "" then return false, "Empty string" end
    
    if str:find("^FR!") then
        return ImportExport.ImportFR(str)
    elseif str:find("^RP!") then
        return ImportExport.ImportRP(str)
    else
        return false, "Invalid format (missing FR! or RP! prefix)"
    end
end

function ImportExport.ImportFR(str)
    local parts = {}
    for part in str:gmatch("[^!]+") do
        table.insert(parts, part)
    end
    
    if #parts < 8 then return false, "Invalid FR format: missing fields" end
    
    local version = tonumber(parts[2])
    if version ~= 1 then return false, "Unsupported FR version: " .. tostring(version) end
    
    local wowFlavor = parts[3]
    local name = parts[4]
    local mapID = tonumber(parts[5])
    local colorStr = parts[6]
    local nodesStr = parts[7]
    local edgesStr = parts[8]
    
    if not mapID then return false, "Invalid MapID" end
    
    -- Flavor check (optional, but good for warnings)
    if wowFlavor ~= NS.WOW_FLAVOR then
        -- We'll allow it but maybe warn? For now just continue.
    end
    
    -- Parse color
    local r, g, b, a = colorStr:match("([%d%.]+),([%d%.]+),([%d%.]+),([%d%.]+)")
    r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a)
    if not (r and g and b and a) then return false, "Invalid color" end
    
    -- Create route
    local finalName = name
    local i = 1
    while NS.Routes[finalName] do
        finalName = name .. " (" .. i .. ")"
        i = i + 1
    end
    
    NS.Data.CreateRoute(finalName, mapID)
    local route = NS.Data.GetRoute(finalName)
    route.color = {r, g, b, a}
    
    -- Parse nodes
    local maxID = 0
    for nodeStr in nodesStr:gmatch("[^;]+") do
        local id, x, y = nodeStr:match("(%d+),([%d%.]+),([%d%.]+)")
        id, x, y = tonumber(id), tonumber(x), tonumber(y)
        if id and x and y then
            route.nodes[id] = {x = x, y = y}
            if id > maxID then maxID = id end
        end
    end
    route.nextNodeID = maxID + 1
    
    -- Parse edges
    for edgeStr in edgesStr:gmatch("[^;]+") do
        local id1, id2 = edgeStr:match("(%d+),(%d+)")
        id1, id2 = tonumber(id1), tonumber(id2)
        if id1 and id2 and route.nodes[id1] and route.nodes[id2] then
            table.insert(route.edges, {id1, id2})
        end
    end
    
    return true, finalName
end

function ImportExport.ImportRP(str)
    local parts = {}
    for part in str:gmatch("[^!]+") do
        table.insert(parts, part)
    end
    
    -- RP!version!wowFlavor!name!mapID!color!loop!waypoints
    -- Version 1 didn't have wowFlavor: RP!1!name!mapID!color!loop!waypoints
    
    local formatVersion = tonumber(parts[2])
    local name, mapID, colorStr, loopStr, waypointsStr
    
    if formatVersion == 1 then
        if #parts < 7 then return false, "Invalid RP v1 format" end
        name = parts[3]
        mapID = tonumber(parts[4])
        colorStr = parts[5]
        loopStr = parts[6]
        waypointsStr = parts[7]
    elseif formatVersion == 2 then
        if #parts < 8 then return false, "Invalid RP v2 format" end
        name = parts[4]
        mapID = tonumber(parts[5])
        colorStr = parts[6]
        loopStr = parts[7]
        waypointsStr = parts[8]
    else
        return false, "Unsupported RP version: " .. tostring(formatVersion)
    end
    
    if not mapID then return false, "Invalid MapID" end
    
    -- Parse color
    local r, g, b, a = colorStr:match("([%d%.]+),([%d%.]+),([%d%.]+),([%d%.]+)")
    r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a)
    if not (r and g and b and a) then return false, "Invalid color" end
    
    -- Create route
    local finalName = name
    local i = 1
    while NS.Routes[finalName] do
        finalName = name .. " (" .. i .. ")"
        i = i + 1
    end
    
    NS.Data.CreateRoute(finalName, mapID)
    local route = NS.Data.GetRoute(finalName)
    route.color = {r, g, b, a}
    
    -- Parse waypoints and convert to graph
    local lastID = nil
    local firstID = nil
    
    for wpStr in waypointsStr:gmatch("[^;]+") do
        local x, y = wpStr:match("([%d%.]+),([%d%.]+)")
        x, y = tonumber(x), tonumber(y)
        if x and y then
            local nodeID = NS.Data.AddNode(finalName, x, y)
            if not firstID then firstID = nodeID end
            if lastID then
                NS.Data.AddEdge(finalName, lastID, nodeID)
            end
            lastID = nodeID
        end
    end
    
    if loopStr == "1" and lastID and firstID then
        NS.Data.AddEdge(finalName, lastID, firstID)
    end
    
    return true, finalName
end
