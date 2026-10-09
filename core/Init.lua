local ADDON_NAME, NS = ...

-- Libraries
NS.HBD = LibStub("HereBeDragons-2.0")

-- Default Settings
local DEFAULT_SETTINGS = {
    minimapEnabled = true,
    worldmapEnabled = true,
    hudEnabled = false,
    mapToolbarHidden = false,
    routeColors = { 1, 1, 0, 0.3 },
    globalStyle = {
        nodeColor = { 1, 1, 1, 0.5 },
        nodeSize = 5,
        edgeColor = { 1, 1, 0, 0.3 },
        edgeThickness = 4,
    },
    currentStyle = {
        nodeColor = { 1, 1, 1, 0.5 },
        nodeSize = 5,
        edgeColor = { 1, 1, 0, 0.3 },
        edgeThickness = 4,
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

-- WoW Flavor Detection
local function DetectFlavor()
    local version, build, date, tocversion = GetBuildInfo()
    if (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT) or (tocversion >= 16000 and tocversion < 17000) then return "Forever" end
    if tocversion >= 110000 then return "Retail" end
    if tocversion >= 40000 then return "Cata Classic" end
    if tocversion >= 20000 then return "TBC Classic" end
    return "Classic Era"
end
NS.WOW_FLAVOR = DetectFlavor()

-- Character Key Helper (Supports standard realms and WoW Forever regional rulesets)
function NS.Utils.GetCharacterKey()
    local charName
    if UnitNameUnmodified then
        local name, surname = UnitNameUnmodified("player")
        if surname and surname ~= "" then
            charName = name .. " " .. tostring(surname)
        else
            charName = name
        end
    end
    if not charName or charName == "" then
        charName = UnitName("player") or "Player"
    end

    local realmKey
    if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        if C_GameRules and C_GameRules.IsGameRuleActive then
            if Enum.GameRule and Enum.GameRule.HardcoreRuleset and C_GameRules.IsGameRuleActive(Enum.GameRule.HardcoreRuleset) then
                realmKey = "Hardcore"
            elseif Enum.GameRule and Enum.GameRule.RPRuleset and C_GameRules.IsGameRuleActive(Enum.GameRule.RPRuleset) then
                realmKey = "RP"
            elseif Enum.GameRule and Enum.GameRule.PvPRuleset and C_GameRules.IsGameRuleActive(Enum.GameRule.PvPRuleset) then
                realmKey = "PvP"
            else
                realmKey = "PvE"
            end
        else
            realmKey = "Forever"
        end
    else
        realmKey = GetRealmName()
        if not realmKey or realmKey == "" then
            realmKey = "Default"
        end
    end

    return charName .. " - " .. realmKey
end

-- Cross-version Color Picker wrapper (supports modern 10.2.5+/11.0+/Forever SetupColorPickerAndShow and legacy clients)
function NS.Utils.ShowColorPicker(options)
    local r = options.r or 1
    local g = options.g or 1
    local b = options.b or 1
    local a = options.a or 1
    local hasOpacity = options.hasOpacity ~= false
    local onColorChanged = options.onColorChanged
    local onCancel = options.onCancel

    if ColorPickerFrame.SetupColorPickerAndShow then
        local info = {
            r = r,
            g = g,
            b = b,
            hasOpacity = hasOpacity,
            opacity = a,
            swatchFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newA = hasOpacity and (ColorPickerFrame:GetColorAlpha() or 1) or 1
                if onColorChanged then
                    onColorChanged(newR, newG, newB, newA)
                end
            end,
            opacityFunc = function()
                local newR, newG, newB = ColorPickerFrame:GetColorRGB()
                local newA = hasOpacity and (ColorPickerFrame:GetColorAlpha() or 1) or 1
                if onColorChanged then
                    onColorChanged(newR, newG, newB, newA)
                end
            end,
            cancelFunc = function(prev)
                local prevR = (type(prev) == "table" and (prev.r or prev[1])) or r
                local prevG = (type(prev) == "table" and (prev.g or prev[2])) or g
                local prevB = (type(prev) == "table" and (prev.b or prev[3])) or b
                local prevA = (type(prev) == "table" and (prev.a or prev[4])) or a
                if onCancel then
                    onCancel(prevR, prevG, prevB, prevA)
                elseif onColorChanged then
                    onColorChanged(prevR, prevG, prevB, prevA)
                end
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame.hasOpacity = hasOpacity
        ColorPickerFrame.opacity = 1 - a
        ColorPickerFrame.previousValues = { r, g, b, a }
        ColorPickerFrame.func = function()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            local newA = hasOpacity and (1 - OpacitySliderFrame:GetValue()) or 1
            if onColorChanged then
                onColorChanged(newR, newG, newB, newA)
            end
        end
        ColorPickerFrame.swatchFunc = ColorPickerFrame.func
        ColorPickerFrame.opacityFunc = ColorPickerFrame.func
        ColorPickerFrame.cancelFunc = function(prev)
            local prevR = (type(prev) == "table" and (prev[1] or prev.r)) or r
            local prevG = (type(prev) == "table" and (prev[2] or prev.g)) or g
            local prevB = (type(prev) == "table" and (prev[3] or prev.b)) or b
            local prevA = (type(prev) == "table" and (prev[4] or prev.a)) or a
            if onCancel then
                onCancel(prevR, prevG, prevB, prevA)
            elseif onColorChanged then
                onColorChanged(prevR, prevG, prevB, prevA)
            end
        end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

InitFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Initialize SavedVariables
        FarmerRoutesDB = FarmerRoutesDB or {}

        local versionStr = NS.WOW_FLAVOR
        FarmerRoutesDB[versionStr] = FarmerRoutesDB[versionStr] or {}

        local db = FarmerRoutesDB[versionStr]
        db.settings = db.settings or {}
        db.minimap = db.minimap or {}
        db.mapIDToLocalizedName = db.mapIDToLocalizedName or {}
        db.charData = db.charData or {}

        -- Get character key
        local charKey = NS.Utils.GetCharacterKey()

        db.charData[charKey] = db.charData[charKey] or {}
        local charData = db.charData[charKey]
        charData.routes = charData.routes or {}
        charData.lockedRoutes = charData.lockedRoutes or {}

        -- Migration from legacy TBC Classic bucket if current character profile is empty
        if not next(charData.routes) and FarmerRoutesDB["TBC Classic"] and FarmerRoutesDB["TBC Classic"].charData then
            local legacyChar = FarmerRoutesDB["TBC Classic"].charData[charKey]
            if not legacyChar then
                local plainName = UnitName("player")
                for k, v in pairs(FarmerRoutesDB["TBC Classic"].charData) do
                    if k:find("^" .. plainName .. " %-") then
                        legacyChar = v
                        break
                    end
                end
            end
            if legacyChar and legacyChar.routes and next(legacyChar.routes) then
                charData.routes = NS.Utils.DeepCopy(legacyChar.routes)
                if legacyChar.lockedRoutes then
                    charData.lockedRoutes = NS.Utils.DeepCopy(legacyChar.lockedRoutes)
                end
                print("|cFFFFFF00FarmerRoutes|r: Imported routes from legacy profile into " .. versionStr)
            end
        end

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

        print("|cFFFFFF00FarmerRoutes|r: Loaded successfully (" .. NS.WOW_FLAVOR .. ").")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

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
