local ADDON_NAME, NS = ...

-- Libraries
NS.HBD = LibStub("HereBeDragons-2.0")

-- Default Settings
local DEFAULT_SETTINGS = {
    minimapEnabled = true,
    worldmapEnabled = true,
    hudEnabled = false,
    dotSize = 4,
    dotSpacing = 15,
    lineThickness = 2,
    waypointLabelSize = 9,
    smartInsertion = false,
    mapToolbarHidden = false,
    routeColors = { 1, 1, 0, 0.3 },
    globalStyle = {
        nodeColor = { 1, 1, 1, 1 },
        nodeSize = 8,
        edgeColor = { 1, 1, 0, 0.3 },
        edgeThickness = 2,
    },
    currentStyle = {
        nodeColor = { 1, 1, 1, 1 },
        nodeSize = 8,
        edgeColor = { 1, 1, 0, 0.3 },
        edgeThickness = 2,
    },
    hudPosition = { point = "CENTER", xOfs = 0, yOfs = 150 },
}

local DEFAULT_MINIMAP_SETTINGS = {
    hide = false,
}

-- Initialize Namespace
NS.MapCache = {}
NS.LockedRoutes = {}
NS.Routes = {}

local InitFrame = CreateFrame("Frame")
InitFrame:RegisterEvent("ADDON_LOADED")
InitFrame:RegisterEvent("PLAYER_LOGIN")

local function DeepMerge(target, source)
    for k, v in pairs(source) do
        if type(v) == "table" then
            if type(target[k]) ~= "table" then target[k] = {} end
            DeepMerge(target[k], v)
        else
            if target[k] == nil then
                target[k] = v
            end
        end
    end
end

NS.Utils = {}
function NS.Utils.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[NS.Utils.DeepCopy(orig_key)] = NS.Utils.DeepCopy(orig_value)
        end
        setmetatable(copy, NS.Utils.DeepCopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

InitFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Initialize SavedVariables
        FarmerRoutesDB = FarmerRoutesDB or {}

        -- We'll just use a "TBC Classic" bucket for now. In a full version, we'd use GetBuildInfo.
        local versionStr = "TBC Classic"
        FarmerRoutesDB[versionStr] = FarmerRoutesDB[versionStr] or {}

        local db = FarmerRoutesDB[versionStr]
        db.settings = db.settings or {}
        db.minimap = db.minimap or {}
        db.mapIDToLocalizedName = db.mapIDToLocalizedName or {}
        db.charData = db.charData or {}

        -- Get character key
        local charName = UnitName("player")
        local realmName = GetRealmName()
        local charKey = charName .. " - " .. realmName

        db.charData[charKey] = db.charData[charKey] or {}
        local charData = db.charData[charKey]
        charData.routes = charData.routes or {}
        charData.lockedRoutes = charData.lockedRoutes or {}

        -- Migration: Move global routes to current character if they exist
        if db.routes and next(db.routes) then
            for name, route in pairs(db.routes) do
                charData.routes[name] = route
            end
            if db.lockedRoutes then
                for name, locked in pairs(db.lockedRoutes) do
                    charData.lockedRoutes[name] = locked
                end
            end
            db.routes = nil
            db.lockedRoutes = nil
            print("|cFFFFFF00FarmerRoutes|r: Migrated global routes to " .. charKey)
        end

        -- Merge Defaults
        DeepMerge(db.settings, DEFAULT_SETTINGS)
        DeepMerge(db.minimap, DEFAULT_MINIMAP_SETTINGS)

        -- Store local references in the namespace for easy access
        NS.DB = db
        NS.Routes = charData.routes
        NS.LockedRoutes = charData.lockedRoutes

        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Populate Zone Cache
        local allMaps = NS.HBD:GetAllMapIDs()
        for _, mapID in ipairs(allMaps) do
            local mapInfo = C_Map.GetMapInfo(mapID)
            if mapInfo and mapInfo.mapType == Enum.UIMapType.Zone then
                -- Verify it's a valid world zone in HBD
                local w, h = NS.HBD:GetZoneSize(mapID)
                if w > 0 and h > 0 then
                    NS.DB.mapIDToLocalizedName[mapID] = mapInfo.name
                    NS.MapCache[mapID] = mapInfo.name
                end
            end
        end

        print("|cFFFFFF00FarmerRoutes|r: Loaded successfully.")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- WoW Flavor Detection
local function DetectFlavor()
    local version, build, date, tocversion = GetBuildInfo()
    if tocversion >= 110000 then return "Retail" end
    if tocversion >= 40000 then return "Cata Classic" end
    if tocversion >= 20000 then return "TBC Classic" end
    return "Classic Era"
end
NS.WOW_FLAVOR = DetectFlavor()

-- Slash Commands
SLASH_FARMERROUTES1 = "/fr"
SLASH_FARMERROUTES2 = "/farmerroutes"
SlashCmdList["FARMERROUTES"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg)
    end
    
    local cmd = (args[1] or ""):lower()
    
    if cmd == "import" then
        if args[2] then
            local str = msg:sub(#args[1] + 2)
            local success, result = NS.ImportExport.ImportRoute(str)
            if success then
                print("|cFFFFFF00FarmerRoutes|r: Imported route '" .. result .. "'")
            else
                print("|cffff0000Import failed:|r " .. tostring(result))
            end
        else
            NS.StringImportExportUI.ShowImport()
        end
    elseif cmd == "export" then
        if args[2] then
            local name = msg:sub(#args[1] + 2)
            NS.StringImportExportUI.ShowExport(name)
        else
            print("Usage: /fr export <route name>")
        end
    elseif cmd == "debug" then
        print("|cFFFFFF00FarmerRoutes Debug:|r")
        local count = 0
        for _ in pairs(NS.Routes) do count = count + 1 end
        print("Total Routes:", count)
        print("WOW Flavor:", NS.WOW_FLAVOR)
    else
        if NS.SettingsUI.Toggle then NS.SettingsUI.Toggle() end
    end
end

_G.FarmerRoutes = NS
