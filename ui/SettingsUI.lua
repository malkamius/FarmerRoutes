local ADDON_NAME, NS = ...

NS.SettingsUI = {}
local UI = NS.SettingsUI

local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

--
-- Main Settings Frame
--
local frame = CreateFrame("Frame", "FarmerRoutesSettingsFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(520, 500)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()
tinsert(UISpecialFrames, "FarmerRoutesSettingsFrame") -- Make it ESC closeable

frame.title = frame:CreateFontString(nil, "OVERLAY")
frame.title:SetFontObject("GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER", 0, 0)
frame.title:SetText("FarmerRoutes Settings")

-- ScrollFrame for Routes
local scrollFrame = CreateFrame("ScrollFrame", "FarmerRoutesScrollFrame", frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 10, -30)
scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(340, 10)
scrollFrame:SetScrollChild(content)

local currentTab = "routes"

-- Tab Buttons
local function CreateTab(id, text, xOfs)
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetSize(120, 25)
    btn:SetPoint("BOTTOMLEFT", 10 + xOfs, 10)
    btn:SetText(text)
    btn:SetScript("OnClick", function()
        currentTab = id
        UI.Refresh()
    end)
    return btn
end

local tabRoutes = CreateTab("routes", "Routes", 0)
local tabStyles = CreateTab("styles", "Global Style", 125)
local tabSync = CreateTab("sync", "Characters", 250)
local tabString = CreateTab("string", "Import/Export", 375)

--
-- UI Population
--
function UI.Refresh()
    if not frame:IsShown() then return end

    -- Clear existing children in content
    local children = { content:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    local regions = { content:GetRegions() }
    for _, region in ipairs(regions) do
        region:Hide()
    end

    if currentTab == "routes" then
        UI.RenderRoutes()
    elseif currentTab == "styles" then
        UI.RenderGlobalStyles()
    elseif currentTab == "string" then
        UI.RenderStringIO()
    elseif currentTab == "sync" then
        UI.RenderSync()
    end
end

function UI.RenderRoutes()
    local yOffset = -10
    -- Global Settings Header
    local header1 = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header1:SetPoint("TOPLEFT", 10, yOffset)
    header1:SetText("Global Settings")
    yOffset = yOffset - 25

    -- Toggle Minimap
    local cbMinimap = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cbMinimap:SetPoint("TOPLEFT", 10, yOffset)
    cbMinimap:SetChecked(NS.DB.settings.minimapEnabled)
    cbMinimap.text = cbMinimap:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cbMinimap.text:SetPoint("LEFT", cbMinimap, "RIGHT", 5, 0)
    cbMinimap.text:SetText("Enable Minimap Routes")
    cbMinimap:SetScript("OnClick", function(self)
        NS.DB.settings.minimapEnabled = self:GetChecked()
        if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
    end)

    -- Toggle World Map
    local cbWorldMap = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cbWorldMap:SetPoint("TOPLEFT", 200, yOffset)
    cbWorldMap:SetChecked(NS.DB.settings.worldmapEnabled)
    cbWorldMap.text = cbWorldMap:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cbWorldMap.text:SetPoint("LEFT", cbWorldMap, "RIGHT", 5, 0)
    cbWorldMap.text:SetText("Enable World Map Routes")
    cbWorldMap:SetScript("OnClick", function(self)
        NS.DB.settings.worldmapEnabled = self:GetChecked()
        if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
    end)

    yOffset = yOffset - 30

    -- Toggle HUD
    local cbHUD = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cbHUD:SetPoint("TOPLEFT", 10, yOffset)
    cbHUD:SetChecked(NS.DB.settings.hudEnabled)
    cbHUD.text = cbHUD:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cbHUD.text:SetPoint("LEFT", cbHUD, "RIGHT", 5, 0)
    cbHUD.text:SetText("Enable Navigation Arrow HUD")
    cbHUD:SetScript("OnClick", function(self)
        NS.DB.settings.hudEnabled = self:GetChecked()
        if NS.NavigationHUD then NS.NavigationHUD.UpdateVisibility() end
    end)

    yOffset = yOffset - 40

    -- Route Manager Header
    local header2 = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header2:SetPoint("TOPLEFT", 10, yOffset)
    header2:SetText("Route Manager")

    -- New Empty Route Button
    local btnNew = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnNew:SetSize(80, 22)
    btnNew:SetPoint("TOPRIGHT", -10, yOffset)
    btnNew:SetText("New")
    btnNew:SetScript("OnClick", function()
        local mapID = WorldMapFrame:GetMapID() or 1415 -- fallback
        local name = NS.Data.GenerateNewRouteName(mapID)
        if NS.Data.CreateRoute(name, mapID) then
            if NS.MapEditor then NS.MapEditor.SetEditMode(name) end
            if not WorldMapFrame:IsShown() then ToggleWorldMap() end
            RefreshUI()
        end
    end)

    -- Import String Button
    local btnImportStr = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnImportStr:SetSize(80, 22)
    btnImportStr:SetPoint("RIGHT", btnNew, "LEFT", -5, 0)
    btnImportStr:SetText("Import")
    btnImportStr:SetScript("OnClick", function()
        currentTab = "string"
        UI.Refresh()
    end)

    yOffset = yOffset - 30

    -- List Routes
    for name, route in pairs(NS.Routes) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(340, 24)
        row:SetPoint("TOPLEFT", 10, yOffset)

        -- Visibility Toggle
        local cbVis = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        cbVis:SetSize(24, 24)
        cbVis:SetPoint("LEFT", 0, 0)
        cbVis:SetChecked(route.visible)
        cbVis:SetScript("OnClick", function(self)
            NS.Data.SetRouteVisible(name, self:GetChecked())
            if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
        end)

        -- Name
        local txtName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        txtName:SetPoint("LEFT", cbVis, "RIGHT", 5, 0)
        txtName:SetWidth(150)
        txtName:SetJustifyH("LEFT")
        txtName:SetText(name)

        -- Edit Button (enters edit mode)
        local btnEdit = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnEdit:SetSize(40, 20)
        btnEdit:SetPoint("LEFT", txtName, "RIGHT", 5, 0)
        btnEdit:SetText("Edit")
        btnEdit:SetScript("OnClick", function()
            local route = NS.Routes[name]
            if route then
                if not WorldMapFrame:IsShown() then ToggleWorldMap() end
                WorldMapFrame:SetMapID(route.mapID)
                if NS.MapEditor then
                    NS.MapEditor.SetEditMode(name)
                    NS.MapEditor.ToggleEditing(true)
                end
                if NS.MapToolbar then
                    NS.MapToolbar.Refresh()
                    -- Ensure toolbar is shown
                    if NS.DB.settings.mapToolbarHidden then
                        NS.DB.settings.mapToolbarHidden = false
                        if NS.MapToolbar.toolbarFrame then NS.MapToolbar.toolbarFrame:Show() end
                    end
                end
            end
        end)

        -- Delete Button
        local btnDel = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnDel:SetSize(40, 20)
        btnDel:SetPoint("LEFT", btnEdit, "RIGHT", 5, 0)
        btnDel:SetText("Del")
        btnDel:SetScript("OnClick", function()
            NS.Data.DeleteRoute(name)
            RefreshUI()
            if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
        end)

        -- Export Button
        local btnExp = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnExp:SetSize(40, 20)
        btnExp:SetPoint("LEFT", btnDel, "RIGHT", 5, 0)
        btnExp:SetText("Exp")
        btnExp:SetScript("OnClick", function()
            NS.StringImportExportUI.ShowExport(name)
        end)

        -- Route Style Button
        local btnStyle = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        btnStyle:SetSize(40, 20)
        btnStyle:SetPoint("LEFT", btnExp, "RIGHT", 5, 0)
        btnStyle:SetText("Style")
        btnStyle:SetScript("OnClick", function()
            -- Open World Map and Toolbar for this route
            local route = NS.Routes[name]
            if route then
                if not WorldMapFrame:IsShown() then ToggleWorldMap() end
                WorldMapFrame:SetMapID(route.mapID)
                if NS.MapEditor then
                    NS.MapEditor.SetEditMode(name)
                    NS.MapEditor.ToggleEditing(true)
                end
                if NS.MapToolbar then
                    NS.MapToolbar.Refresh()
                    if NS.DB.settings.mapToolbarHidden then
                        NS.DB.settings.mapToolbarHidden = false
                        if NS.MapToolbar.toolbarFrame then NS.MapToolbar.toolbarFrame:Show() end
                    end
                    if NS.MapToolbar.toolbarFrame.styleDrawer then
                        NS.MapToolbar.toolbarFrame.styleDrawer:Show()
                        NS.MapToolbar.UpdateStyleUI()
                    end
                end
            end
        end)

        yOffset = yOffset - 26
    end

    content:SetHeight(math.abs(yOffset) + 20)
end

function UI.RenderStringIO()
    local yOffset = -10

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText("String Import / Export")
    yOffset = yOffset - 30

    local labelImport = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelImport:SetPoint("TOPLEFT", 10, yOffset)
    labelImport:SetText("Paste string to import:")
    yOffset = yOffset - 20

    local importEditBox = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    importEditBox:SetSize(320, 20)
    importEditBox:SetPoint("TOPLEFT", 10, yOffset)
    importEditBox:SetAutoFocus(false)
    yOffset = yOffset - 30

    local btnImport = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnImport:SetSize(100, 22)
    btnImport:SetPoint("TOPLEFT", 10, yOffset)
    btnImport:SetText("Import")
    btnImport:SetScript("OnClick", function()
        local text = importEditBox:GetText()
        local success, result = NS.ImportExport.ImportRoute(text)
        if success then
            print("|cFFFFFF00FarmerRoutes|r: Imported route '" .. result .. "'")
            UI.Refresh()
            if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
        else
            UI.ShowError("Import Failed: " .. tostring(result))
        end
    end)
    yOffset = yOffset - 40

    local labelExport = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    labelExport:SetPoint("TOPLEFT", 10, yOffset)
    labelExport:SetText("Route export strings:")
    yOffset = yOffset - 20

    for name, _ in pairs(NS.Routes) do
        local btnExp = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        btnExp:SetSize(320, 20)
        btnExp:SetPoint("TOPLEFT", 10, yOffset)
        btnExp:SetText("Export: " .. name)
        btnExp:SetScript("OnClick", function()
            NS.StringImportExportUI.ShowExport(name)
        end)
        yOffset = yOffset - 22
    end

    content:SetHeight(math.abs(yOffset) + 20)
end

function UI.RenderSync()
    local yOffset = -10

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText("Import from Other Characters")
    yOffset = yOffset - 30

    local db = NS.DB
    if not db or not db.charData then return end

    local currentCharKey = UnitName("player") .. " - " .. GetRealmName()
    local charKeys = {}
    for key, _ in pairs(db.charData) do
        if key ~= currentCharKey then table.insert(charKeys, key) end
    end
    table.sort(charKeys)

    if #charKeys == 0 then
        local msg = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        msg:SetPoint("TOPLEFT", 10, yOffset)
        msg:SetText("No other characters found.")
        return
    end

    for _, charKey in ipairs(charKeys) do
        local charData = db.charData[charKey]
        if charData.routes and next(charData.routes) then
            local charHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            charHeader:SetPoint("TOPLEFT", 10, yOffset)
            charHeader:SetText(charKey)
            yOffset = yOffset - 20

            for routeName, _ in pairs(charData.routes) do
                local btn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                btn:SetSize(300, 20)
                btn:SetPoint("TOPLEFT", 20, yOffset)
                btn:SetText(routeName)
                btn:SetScript("OnClick", function()
                    local sourceRoute = charData.routes[routeName]
                    if sourceRoute then
                        local newRoute = NS.Utils.DeepCopy(sourceRoute)
                        local baseName = routeName
                        local name = baseName
                        local i = 1
                        while NS.Routes[name] do
                            name = baseName .. " (" .. i .. ")"
                            i = i + 1
                        end
                        newRoute.name = name
                        NS.Routes[name] = newRoute
                        print("|cFFFFFF00FarmerRoutes|r: Imported '" .. name .. "' from " .. charKey)
                        UI.Refresh()
                    end
                end)
                yOffset = yOffset - 22
            end
            yOffset = yOffset - 10
        end
    end

    content:SetHeight(math.abs(yOffset) + 20)
end

function UI.RenderGlobalStyles()
    local yOffset = -10
    local style = NS.DB.settings.globalStyle

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", 10, yOffset)
    header:SetText("Global Default Style")
    yOffset = yOffset - 20

    local subtext = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtext:SetPoint("TOPLEFT", 10, yOffset)
    subtext:SetText("These settings apply to any route, node, or edge that doesn't have a specific override.")
    yOffset = yOffset - 30

    -- Helper for creating sliders
    local function CreateStyleSlider(name, parent, min, max, label, value, onUpdate)
        local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(1)
        slider:SetValue(value)
        slider:SetObeyStepOnDrag(true)
        _G[slider:GetName() .. 'Low']:SetText(tostring(min))
        _G[slider:GetName() .. 'High']:SetText(tostring(max))
        _G[slider:GetName() .. 'Text']:SetText(label)
        slider:SetScript("OnValueChanged", function(self, v) onUpdate(v) end)
        return slider
    end

    -- Helper for color buttons
    local function CreateColorButton(parent, label, onClick, color)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(80, 22)
        btn:SetText(label)
        btn:SetScript("OnClick", onClick)

        btn.swatch = btn:CreateTexture(nil, "OVERLAY")
        btn.swatch:SetSize(14, 14)
        btn.swatch:SetPoint("LEFT", 5, 0)
        btn.swatch:SetColorTexture(color[1], color[2], color[3], color[4])

        return btn
    end

    -- Node Section
    local nodeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nodeHeader:SetPoint("TOPLEFT", 10, yOffset)
    nodeHeader:SetText("Nodes")
    yOffset = yOffset - 30

    local btnNodeColor = CreateColorButton(content, "  Color", function(self)
        ColorPickerFrame:SetColorRGB(style.nodeColor[1], style.nodeColor[2], style.nodeColor[3])
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - style.nodeColor[4]
        ColorPickerFrame.previousValues = { style.nodeColor[1], style.nodeColor[2], style.nodeColor[3], style.nodeColor
            [4] }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = 1 - OpacitySliderFrame:GetValue()
            style.nodeColor = { r, g, b, a }
            self.swatch:SetColorTexture(r, g, b, a)
            if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
        end
        ColorPickerFrame.swatchFunc = ColorPickerFrame.func
        ColorPickerFrame.opacityFunc = ColorPickerFrame.func
        ColorPickerFrame.cancelFunc = function(prev)
            style.nodeColor = { prev[1], prev[2], prev[3], prev[4] }
            self.swatch:SetColorTexture(prev[1], prev[2], prev[3], prev[4])
            if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
        end
        ColorPickerFrame:Show()
    end, style.nodeColor)
    btnNodeColor:SetPoint("TOPLEFT", 20, yOffset)

    local sliderNodeSize = CreateStyleSlider("FarmerRoutesGlobalNodeSize", content, 4, 24, "Default Size", style
    .nodeSize, function(v)
        style.nodeSize = v
        if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
        if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
    end)
    sliderNodeSize:SetPoint("LEFT", btnNodeColor, "RIGHT", 40, 0)

    yOffset = yOffset - 50

    -- Edge Section
    local edgeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    edgeHeader:SetPoint("TOPLEFT", 10, yOffset)
    edgeHeader:SetText("Edges")
    yOffset = yOffset - 30

    local btnEdgeColor = CreateColorButton(content, "  Color", function(self)
        ColorPickerFrame:SetColorRGB(style.edgeColor[1], style.edgeColor[2], style.edgeColor[3])
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - style.edgeColor[4]
        ColorPickerFrame.previousValues = { style.edgeColor[1], style.edgeColor[2], style.edgeColor[3], style.edgeColor
            [4] }
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = 1 - OpacitySliderFrame:GetValue()
            style.edgeColor = { r, g, b, a }
            self.swatch:SetColorTexture(r, g, b, a)
            if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
        end
        ColorPickerFrame.swatchFunc = ColorPickerFrame.func
        ColorPickerFrame.opacityFunc = ColorPickerFrame.func
        ColorPickerFrame.cancelFunc = function(prev)
            style.edgeColor = { prev[1], prev[2], prev[3], prev[4] }
            self.swatch:SetColorTexture(prev[1], prev[2], prev[3], prev[4])
            if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
        end
        ColorPickerFrame:Show()
    end, style.edgeColor)
    btnEdgeColor:SetPoint("TOPLEFT", 20, yOffset)

    local sliderEdgeThickness = CreateStyleSlider("FarmerRoutesGlobalEdgeThickness", content, 1, 10, "Default Thickness",
        style.edgeThickness, function(v)
        style.edgeThickness = v
        if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
        if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
    end)
    sliderEdgeThickness:SetPoint("LEFT", btnEdgeColor, "RIGHT", 40, 0)

    yOffset = yOffset - 60

    local btnReset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    btnReset:SetSize(200, 25)
    btnReset:SetPoint("TOPLEFT", 10, yOffset)
    btnReset:SetText("Reset to Factory Defaults")
    btnReset:SetScript("OnClick", function()
        NS.DB.settings.globalStyle = {
            nodeColor = { 1, 1, 1, 1 },
            nodeSize = 8,
            edgeColor = { 1, 1, 0, 0.3 },
            edgeThickness = 2,
        }
        UI.Refresh()
        if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
        if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
    end)

    content:SetHeight(math.abs(yOffset) + 50)
end

function UI.ShowError(msg)
    print("|cFFFFFF00FarmerRoutes Error:|r " .. tostring(msg))
end

frame:SetScript("OnShow", UI.Refresh)

--
-- Minimap Button (LibDBIcon)
--
local LDBObj = LDB:NewDataObject("FarmerRoutes", {
    type = "data source",
    text = "FarmerRoutes",
    icon = "Interface\\Icons\\INV_Pick_02",
    OnClick = function(_, button)
        if button == "LeftButton" then
            if IsShiftKeyDown() then
                NS.DB.settings.hudEnabled = not NS.DB.settings.hudEnabled
                if NS.NavigationHUD then NS.NavigationHUD.UpdateVisibility() end
                local status = NS.DB.settings.hudEnabled and "Enabled" or "Disabled"
                print("|cFFFFFF00FarmerRoutes|r: Navigation HUD " .. status)
            else
                if frame:IsShown() then frame:Hide() else frame:Show() end
            end
        end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("FarmerRoutes")
        tooltip:AddLine("Left-Click to toggle Settings")
        tooltip:AddLine("Shift-Left-Click to toggle Navigation HUD")
    end,
})

-- Top map toolbar has been moved to map/MapToolbar.lua

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        if LDBObj then
            DBIcon:Register("FarmerRoutes", LDBObj, NS.DB.minimap)
        end
    end
end)

function UI.Toggle()
    if frame:IsShown() then frame:Hide() else frame:Show() end
end
