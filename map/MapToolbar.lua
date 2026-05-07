local ADDON_NAME, NS = ...

NS.MapToolbar = {}
local Toolbar = NS.MapToolbar

local mapButton
Toolbar.toolbarFrame = nil
local currentXOffset = 0

local function GetToolbarAnchor()
    return WorldMapFrame
end

local function ResetToolbarPosition()
    if Toolbar.toolbarFrame then
        local anchor = GetToolbarAnchor()
        Toolbar.toolbarFrame:ClearAllPoints()
        Toolbar.toolbarFrame:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 20)
        NS.DB.settings.toolbarPosition = nil
    end
end

local function SaveToolbarPosition()
    if Toolbar.toolbarFrame then
        local anchor = GetToolbarAnchor()
        local s = Toolbar.toolbarFrame:GetEffectiveScale()
        local as = anchor:GetEffectiveScale()
        local x, y = Toolbar.toolbarFrame:GetCenter()
        local ax, ay = anchor:GetCenter()

        if x and y and ax and ay then
            local xOfs = (x * s - ax * as) / s
            local yOfs = (y * s - ay * as) / s

            NS.DB.settings.toolbarPosition = {
                point = "CENTER",
                relativePoint = "CENTER",
                xOfs = xOfs,
                yOfs = yOfs
            }
        end
    end
end

local function UpdateToolbarUI()
    local frame = Toolbar.toolbarFrame
    if not frame then return end

    if NS.MapEditor.activeRouteName then
        local route = NS.Routes[NS.MapEditor.activeRouteName]
        if frame.routeDropdown then UIDropDownMenu_SetText(frame.routeDropdown, NS.MapEditor.activeRouteName) end
        if frame.nameEditBox then
            frame.nameEditBox:SetText(NS.MapEditor.activeRouteName)
            frame.nameEditBox:Enable()
        end
        if frame.btnDelete then
            frame.btnDelete:Enable()
            frame.btnDelete:GetNormalTexture():SetDesaturated(false)
        end
        if frame.btnRouteVis then
            frame.btnRouteVis:Enable()
            frame.btnRouteVis:GetNormalTexture():SetDesaturated(false)
            if route and route.visible == false then
                frame.btnRouteVis:SetNormalTexture("Interface\\Icons\\INV_Misc_Eye_02")
            else
                frame.btnRouteVis:SetNormalTexture("Interface\\Icons\\INV_Misc_Eye_01")
            end
        end
    else
        if frame.routeDropdown then UIDropDownMenu_SetText(frame.routeDropdown, "None") end
        if frame.nameEditBox then
            frame.nameEditBox:SetText("")
            frame.nameEditBox:Disable()
        end
        if frame.btnDelete then
            frame.btnDelete:Disable()
            frame.btnDelete:GetNormalTexture():SetDesaturated(true)
        end
        if frame.btnRouteVis then
            frame.btnRouteVis:Disable()
            frame.btnRouteVis:GetNormalTexture():SetDesaturated(true)
            frame.btnRouteVis:SetNormalTexture("Interface\\Icons\\INV_Misc_Eye_01")
        end
    end

    -- Update Edit Mode Button Visuals
    if frame.btnEditMode then
        if NS.MapEditor.isEditing then
            frame.btnEditMode.activeTex:Show()
            frame.btnEditMode:SetNormalTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        else
            frame.btnEditMode.activeTex:Hide()
            frame.btnEditMode:SetNormalTexture("Interface\\Icons\\INV_Misc_Wrench_01")
        end
    end
end

local function Dropdown_OnClick(self)
    local routeName = self.value
    UIDropDownMenu_SetSelectedValue(Toolbar.toolbarFrame.routeDropdown, routeName)
    NS.MapEditor.SetEditMode(routeName)

    -- Switch to the route's map if one is selected
    if routeName then
        local route = NS.Routes[routeName]
        if route and route.mapID and WorldMapFrame:GetMapID() ~= route.mapID then
            WorldMapFrame:SetMapID(route.mapID)
        end
    end

    UpdateToolbarUI()
end

local function InitializeDropdown(self, level)
    local info = UIDropDownMenu_CreateInfo()

    -- "None" option
    info.text = "None"
    info.value = nil
    info.func = Dropdown_OnClick
    info.checked = (NS.MapEditor.activeRouteName == nil)
    UIDropDownMenu_AddButton(info, level)

    -- List all routes
    -- Sort routes by name for better UX
    local sortedNames = {}
    for name, _ in pairs(NS.Routes) do
        table.insert(sortedNames, name)
    end
    table.sort(sortedNames)

    for _, name in ipairs(sortedNames) do
        local route = NS.Routes[name]
        local displayName = name
        if route and route.visible == false then
            displayName = "|cff888888" .. name .. " (Hidden)|r"
        end
        info.text = displayName
        info.value = name
        info.func = Dropdown_OnClick
        info.checked = (NS.MapEditor.activeRouteName == name)
        UIDropDownMenu_AddButton(info, level)
    end
end

StaticPopupDialogs["FARMERROUTES_CONFIRM_DELETE_ROUTE"] = {
    text = "Are you sure you want to delete the route '%s'?",
    button1 = YES,
    button2 = NO,
    OnAccept = function(self, data)
        local routeName = data
        if NS.Data.DeleteRoute(routeName) then
            print("|cFFFFFF00FarmerRoutes|r: Deleted route: " .. routeName)
            if NS.MapEditor.activeRouteName == routeName then
                NS.MapEditor.SetEditMode(nil)
            end

            -- Refresh UI
            Toolbar.Refresh()

            -- Redraw Map
            if NS.MapRenderer and NS.MapRenderer.DrawRoutes then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer and NS.MinimapRenderer.MarkDirty then NS.MinimapRenderer.MarkDirty() end
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function UpdateMapButtonPosition()
    if not mapButton then return end

    local xOffset = 35 -- Starting offset (covers standard Close button)

    local parents = { WorldMapFrame }
    if WorldMapScrollFrame then table.insert(parents, WorldMapScrollFrame) end
    if WorldMapFrame.ScrollContainer then table.insert(parents, WorldMapFrame.ScrollContainer) end

    for _, p in ipairs(parents) do
        local children = { p:GetChildren() }
        for _, child in ipairs(children) do
            -- Only check visible buttons or frames that might be icons
            if child:IsShown() and child ~= mapButton and (child:IsObjectType("Button") or (child:GetWidth() and child:GetWidth() < 100)) then
                for i = 1, child:GetNumPoints() do
                    local point, relativeTo, relativePoint, x, y = child:GetPoint(i)

                    -- Check if this frame is anchored to WorldMapFrame or its scroll containers
                    local isAnchoredToMap = false
                    for _, targetParent in ipairs(parents) do
                        if relativeTo == targetParent or (relativeTo and relativeTo.GetName and relativeTo:GetName() == targetParent:GetName()) then
                            isAnchoredToMap = true
                            break
                        end
                    end

                    if isAnchoredToMap and (point == "TOPRIGHT" or relativePoint == "TOPRIGHT") then
                        local width = child:GetWidth() or 0
                        local absX = math.abs(x or 0)
                        local edge = absX + width
                        if edge > xOffset then
                            xOffset = edge
                        end
                    end
                end
            end
        end
    end

    -- Also check known global frames that might be parented elsewhere but anchored to the map
    local globalFrames = { "QuestHelperWorldMapButton", "AtlasMapButton", "AtlasLoot_MapButton" }
    for _, name in ipairs(globalFrames) do
        local f = _G[name]
        if f and f:IsShown() then
            for i = 1, f:GetNumPoints() do
                local point, relativeTo, relativePoint, x, y = f:GetPoint(i)
                local isAnchoredToMap = false
                for _, targetParent in ipairs(parents) do
                    if relativeTo == targetParent or (relativeTo and relativeTo.GetName and relativeTo:GetName() == targetParent:GetName()) then
                        isAnchoredToMap = true
                        break
                    end
                end
                if isAnchoredToMap and (point == "TOPRIGHT" or relativePoint == "TOPRIGHT") then
                    local width = f:GetWidth() or 0
                    local absX = math.abs(x or 0)
                    local edge = absX + width
                    if edge > xOffset then
                        xOffset = edge
                    end
                end
            end
        end
    end

    if xOffset ~= currentXOffset then
        mapButton:ClearAllPoints()
        mapButton:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -(xOffset + 10), -25)
        currentXOffset = xOffset
    end
end

local updateTimer = 0
local totalUpdateDuration = 0
local function MapButton_OnUpdate(self, elapsed)
    updateTimer = updateTimer + elapsed
    totalUpdateDuration = totalUpdateDuration + elapsed

    if updateTimer >= 0.5 then
        UpdateMapButtonPosition()
        updateTimer = 0
    end

    -- Stop polling after 10 seconds to save performance
    if totalUpdateDuration > 10 then
        self:SetScript("OnUpdate", nil)
    end
end

function Toolbar.Init()
    -- Create the Map Button
    mapButton = CreateFrame("Button", "FarmerRoutesMapButton", WorldMapFrame)
    mapButton:SetSize(32, 32)
    mapButton:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", -40, -25) -- Adjust as needed
    mapButton:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
    mapButton:SetNormalTexture("Interface\\Icons\\INV_Pick_02")
    mapButton:SetPushedTexture("Interface\\Icons\\INV_Pick_02")
    mapButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    -- Ensure position is correct based on other top-right icons
    UpdateMapButtonPosition()
    WorldMapFrame:HookScript("OnShow", function()
        UpdateMapButtonPosition()
        updateTimer = 0
        totalUpdateDuration = 0
        mapButton:SetScript("OnUpdate", MapButton_OnUpdate)
    end)

    WorldMapFrame:HookScript("OnHide", function()
        mapButton:SetScript("OnUpdate", nil)
        if NS.MapEditor then
            NS.MapEditor.ToggleEditing(false)
            Toolbar.Refresh()
        end
    end)

    -- Disable edit mode on map change
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
        if NS.MapEditor and NS.MapEditor.isEditing then
            NS.MapEditor.ToggleEditing(false)
            Toolbar.Refresh()
        end
    end)

    mapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mapButton:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            -- Reset position
            ResetToolbarPosition()
            print("|cFFFFFF00FarmerRoutes|r: Toolbar position reset.")
        else
            -- Toggle visibility
            NS.DB.settings.mapToolbarHidden = not NS.DB.settings.mapToolbarHidden
            if NS.DB.settings.mapToolbarHidden then
                Toolbar.toolbarFrame:Hide()
            else
                Toolbar.toolbarFrame:Show()
            end
        end
    end)

    mapButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("FarmerRoutes Editor")
        GameTooltip:AddLine("Left-Click to toggle toolbar", 1, 1, 1)
        GameTooltip:AddLine("Right-Click to reset toolbar position", 1, 1, 1)
        GameTooltip:Show()
    end)
    mapButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Create the Toolbar Frame
    Toolbar.toolbarFrame = CreateFrame("Frame", "FarmerRoutesMapToolbar", WorldMapFrame, "BackdropTemplate")
    local toolbarFrame = Toolbar.toolbarFrame
    toolbarFrame:SetSize(550, 40)
    toolbarFrame:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
    toolbarFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })

    -- Load or set default position
    local savedPos = NS.DB.settings.toolbarPosition
    if savedPos then
        toolbarFrame:ClearAllPoints()
        toolbarFrame:SetPoint(savedPos.point, GetToolbarAnchor(), savedPos.relativePoint, savedPos.xOfs, savedPos.yOfs)
    else
        ResetToolbarPosition()
    end

    -- Dragging
    toolbarFrame:SetMovable(true)
    toolbarFrame:EnableMouse(true)
    toolbarFrame:RegisterForDrag("LeftButton")
    toolbarFrame:SetScript("OnDragStart", toolbarFrame.StartMoving)
    toolbarFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveToolbarPosition()

        -- Re-anchor immediately to ensure GetPoint() etc are relative to our anchor
        local pos = NS.DB.settings.toolbarPosition
        if pos then
            self:ClearAllPoints()
            self:SetPoint(pos.point, GetToolbarAnchor(), pos.relativePoint, pos.xOfs, pos.yOfs)
        end
    end)

    -- Dropdown
    local routeDropdown = CreateFrame("Frame", "FarmerRoutesToolbarDropdown", toolbarFrame, "UIDropDownMenuTemplate")
    routeDropdown:SetPoint("LEFT", toolbarFrame, "LEFT", -5, -2)
    UIDropDownMenu_SetWidth(routeDropdown, 120)
    UIDropDownMenu_Initialize(routeDropdown, InitializeDropdown)
    UIDropDownMenu_SetText(routeDropdown, "None")
    toolbarFrame.routeDropdown = routeDropdown

    -- EditBox for renaming
    local nameEditBox = CreateFrame("EditBox", nil, toolbarFrame, "InputBoxTemplate")
    nameEditBox:SetSize(120, 20)
    nameEditBox:SetPoint("LEFT", routeDropdown, "RIGHT", -5, 2)
    nameEditBox:SetAutoFocus(false)
    nameEditBox:Disable()

    nameEditBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if NS.MapEditor.activeRouteName then
            local newName = self:GetText()
            if newName ~= NS.MapEditor.activeRouteName and newName ~= "" then
                local success = NS.Data.RenameRoute(NS.MapEditor.activeRouteName, newName)
                if success then
                    NS.MapEditor.activeRouteName = newName
                    UpdateToolbarUI()
                    if NS.MapRenderer and NS.MapRenderer.DrawRoutes then NS.MapRenderer.DrawRoutes() end
                    print("|cFFFFFF00FarmerRoutes|r: Route renamed to " .. newName)
                else
                    print("|cFFFFFF00FarmerRoutes|r: Failed to rename route. Name might be invalid or already exist.")
                    self:SetText(NS.MapEditor.activeRouteName)
                end
            end
        end
    end)

    nameEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if NS.MapEditor.activeRouteName then
            self:SetText(NS.MapEditor.activeRouteName)
        end
    end)

    toolbarFrame.nameEditBox = nameEditBox

    -- New Route Button
    local btnAdd = CreateFrame("Button", nil, toolbarFrame)
    btnAdd:SetSize(24, 24)
    btnAdd:SetPoint("LEFT", nameEditBox, "RIGHT", 5, 0)
    btnAdd:SetNormalTexture("Interface\\Icons\\INV_Misc_Note_01")
    btnAdd:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btnAdd:SetScript("OnClick", function()
        local mapID = WorldMapFrame:GetMapID() or 1415
        local name = NS.Data.GenerateNewRouteName(mapID)
        if NS.Data.CreateRoute(name, mapID) then
            -- Update UI
            UIDropDownMenu_Initialize(toolbarFrame.routeDropdown, InitializeDropdown)
            UIDropDownMenu_SetSelectedValue(toolbarFrame.routeDropdown, name)
            NS.MapEditor.SetEditMode(name)
            UpdateToolbarUI()
            print("|cFFFFFF00FarmerRoutes|r: Created new route: " .. name)

            -- Focus the edit box so the user can immediately rename it
            nameEditBox:SetFocus()
            nameEditBox:HighlightText()
        end
    end)
    btnAdd:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("New Route")
        GameTooltip:Show()
    end)
    btnAdd:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Delete Route Button
    local btnDelete = CreateFrame("Button", nil, toolbarFrame)
    btnDelete:SetSize(24, 24)
    btnDelete:SetPoint("LEFT", btnAdd, "RIGHT", 5, 0)
    btnDelete:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    btnDelete:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btnDelete:SetScript("OnClick", function()
        if NS.MapEditor.activeRouteName then
            StaticPopup_Show("FARMERROUTES_CONFIRM_DELETE_ROUTE", NS.MapEditor.activeRouteName, nil,
                NS.MapEditor.activeRouteName)
        end
    end)
    btnDelete:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Delete Route")
        if not NS.MapEditor.activeRouteName then
            GameTooltip:AddLine("No route selected.", 1, 0, 0)
        end
        GameTooltip:Show()
    end)
    btnDelete:SetScript("OnLeave", function() GameTooltip:Hide() end)
    toolbarFrame.btnDelete = btnDelete

    -- Edit Mode Button
    local btnEditMode = CreateFrame("Button", nil, toolbarFrame)
    toolbarFrame.btnEditMode = btnEditMode
    btnEditMode:SetSize(24, 24)
    btnEditMode:SetPoint("LEFT", btnDelete, "RIGHT", 5, 0)
    btnEditMode:SetNormalTexture("Interface\\Icons\\INV_Misc_Wrench_01")
    btnEditMode:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    -- Highlight to show it's active
    btnEditMode.activeTex = btnEditMode:CreateTexture(nil, "OVERLAY")
    btnEditMode.activeTex:SetAllPoints()
    btnEditMode.activeTex:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    btnEditMode.activeTex:SetBlendMode("ADD")

    btnEditMode:SetScript("OnClick", function()
        -- If we have an active route and are turning on edit mode,
        -- ensure we are on the correct map.
        if not NS.MapEditor.isEditing and NS.MapEditor.activeRouteName then
            local route = NS.Routes[NS.MapEditor.activeRouteName]
            if route and route.mapID and WorldMapFrame:GetMapID() ~= route.mapID then
                WorldMapFrame:SetMapID(route.mapID)
            end
        end

        NS.MapEditor.ToggleEditing()
        UpdateToolbarUI()
        if NS.MapEditor.isEditing then
            print("|cFFFFFF00FarmerRoutes|r: Edit Mode Enabled.")
        else
            print("|cFFFFFF00FarmerRoutes|r: Edit Mode Disabled.")
        end
    end)
    btnEditMode:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggle Edit Mode")
        GameTooltip:AddLine("Enables modifying the map route.", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click (node): Select/Drag node", 0.0, 1.0, 0.0)
        GameTooltip:AddLine("Ctrl+Left-Click (empty space): Add node", 0.0, 1.0, 0.0)
        GameTooltip:AddLine("Ctrl+Left-Click (node): Toggle edge to selected node", 1.0, 1.0, 0.0)
        GameTooltip:AddLine("Right-Click: Delete node/edge", 1.0, 0.0, 0.0)
        GameTooltip:Show()
    end)
    btnEditMode:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Per-Route Visibility Button
    local btnRouteVis = CreateFrame("Button", nil, toolbarFrame)
    btnRouteVis:SetSize(24, 24)
    btnRouteVis:SetPoint("LEFT", btnEditMode, "RIGHT", 5, 0)
    btnRouteVis:SetNormalTexture("Interface\\Icons\\INV_Misc_Eye_01")
    btnRouteVis:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btnRouteVis:SetScript("OnClick", function()
        if NS.MapEditor.activeRouteName then
            local route = NS.Routes[NS.MapEditor.activeRouteName]
            if route then
                NS.Data.SetRouteVisible(NS.MapEditor.activeRouteName, not route.visible)
                UpdateToolbarUI()
                if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
            end
        end
    end)
    btnRouteVis:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Route Visibility")
        GameTooltip:AddLine("Toggle visibility for the selected route.", 1, 1, 1)
        GameTooltip:Show()
    end)
    btnRouteVis:SetScript("OnLeave", function() GameTooltip:Hide() end)
    toolbarFrame.btnRouteVis = btnRouteVis

    -- Toggle All Visibility Button
    local btnVis = CreateFrame("Button", nil, toolbarFrame)
    btnVis:SetSize(24, 24)
    btnVis:SetPoint("LEFT", btnRouteVis, "RIGHT", 5, 0)
    btnVis:SetNormalTexture("Interface\\Icons\\INV_Misc_Eye_01")
    btnVis:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    -- Overlay for "All" toggle to distinguish it
    btnVis.allLabel = btnVis:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btnVis.allLabel:SetPoint("BOTTOM", btnVis, "BOTTOM", 0, -5)
    btnVis.allLabel:SetText("All")
    btnVis.allLabel:SetTextColor(1, 1, 1, 1)

    btnVis:SetScript("OnClick", function()
        NS.DB.settings.worldmapEnabled = not NS.DB.settings.worldmapEnabled
        if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
    end)
    btnVis:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggle All Routes")
        GameTooltip:AddLine("Global visibility for all routes on the map.", 1, 1, 1)
        GameTooltip:Show()
    end)
    btnVis:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Import Button
    local btnImport = CreateFrame("Button", nil, toolbarFrame)
    btnImport:SetSize(24, 24)
    btnImport:SetPoint("LEFT", btnVis, "RIGHT", 5, 0)
    btnImport:SetNormalTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
    btnImport:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btnImport:SetScript("OnClick", function()
        if NS.SettingsUI and NS.SettingsUI.ShowTab then
            NS.SettingsUI.ShowTab("sync")
        end
    end)
    btnImport:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Import Routes")
        GameTooltip:AddLine("Import routes from other characters.", 1, 1, 1)
        GameTooltip:Show()
    end)
    btnImport:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Settings Gear
    local btnSettings = CreateFrame("Button", nil, toolbarFrame)
    btnSettings:SetSize(24, 24)
    btnSettings:SetPoint("LEFT", btnImport, "RIGHT", 5, 0)
    btnSettings:SetNormalTexture("Interface\\Icons\\INV_Gizmo_02")
    btnSettings:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btnSettings:SetScript("OnClick", function()
        if FarmerRoutesSettingsFrame then
            if FarmerRoutesSettingsFrame:IsShown() then
                FarmerRoutesSettingsFrame:Hide()
            else
                FarmerRoutesSettingsFrame:Show()
            end
        end
    end)
    btnSettings:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Open Full Settings")
        GameTooltip:Show()
    end)
    btnSettings:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Style Button
    local btnStyle = CreateFrame("Button", nil, toolbarFrame)
    btnStyle:SetSize(24, 24)
    btnStyle:SetPoint("LEFT", btnSettings, "RIGHT", 5, 0)
    btnStyle:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
    btnStyle:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
    btnStyle:SetScript("OnClick", function()
        if toolbarFrame.styleDrawer:IsShown() then
            toolbarFrame.styleDrawer:Hide()
        else
            toolbarFrame.styleDrawer:Show()
            Toolbar.UpdateStyleUI()
        end
    end)
    btnStyle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Style Settings")
        GameTooltip:AddLine("Configure node and edge appearance.", 1, 1, 1)
        GameTooltip:Show()
    end)
    btnStyle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    toolbarFrame.btnStyle = btnStyle

    -- Style Drawer
    local styleDrawer = CreateFrame("Frame", nil, toolbarFrame, "BackdropTemplate")
    styleDrawer:SetSize(400, 110)
    styleDrawer:SetPoint("TOP", toolbarFrame, "BOTTOM", 0, -2)
    styleDrawer:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    styleDrawer:Hide()
    toolbarFrame.styleDrawer = styleDrawer

    -- Helper for creating sliders
    local function CreateStyleSlider(name, parent, min, max, label)
        local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
        slider:SetMinMaxValues(min, max)
        slider:SetValueStep(1)
        slider:SetObeyStepOnDrag(true)
        _G[slider:GetName() .. 'Low']:SetText(tostring(min))
        _G[slider:GetName() .. 'High']:SetText(tostring(max))
        _G[slider:GetName() .. 'Text']:SetText(label)
        return slider
    end

    -- Helper for color buttons
    local function CreateColorButton(parent, label, onClick)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetSize(80, 22)
        btn:SetText(label)
        btn:SetScript("OnClick", onClick)

        btn.swatch = btn:CreateTexture(nil, "OVERLAY")
        btn.swatch:SetSize(14, 14)
        btn.swatch:SetPoint("LEFT", 5, 0)
        btn.swatch:SetColorTexture(1, 1, 1, 1)

        return btn
    end

    -- Node Styling
    local nodeLabel = styleDrawer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nodeLabel:SetPoint("TOPLEFT", 10, -10)
    nodeLabel:SetText("Node:")

    local btnNodeColor = CreateColorButton(styleDrawer, "  Color", function()
        local style = NS.DB.settings.currentStyle
        if not style.nodeColor then return end -- Safety check
        ColorPickerFrame:SetColorRGB(style.nodeColor[1], style.nodeColor[2], style.nodeColor[3])
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - style.nodeColor[4]
        ColorPickerFrame.previousValues = { style.nodeColor[1], style.nodeColor[2], style.nodeColor[3], style.nodeColor
            [4] }
        ColorPickerFrame.func = function()
            local oldStyle = NS.Utils.DeepCopy(NS.DB.settings.currentStyle)
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = 1 - OpacitySliderFrame:GetValue()
            style.nodeColor = { r, g, b, a }
            Toolbar.UpdateStyleUI()
            if NS.MapEditor and NS.MapEditor.UpdateSelectedStyle then NS.MapEditor.UpdateSelectedStyle(oldStyle) end
        end
        ColorPickerFrame.swatchFunc = ColorPickerFrame.func
        ColorPickerFrame.opacityFunc = ColorPickerFrame.func
        ColorPickerFrame.cancelFunc = function(prev)
            style.nodeColor = { prev[1], prev[2], prev[3], prev[4] }
            Toolbar.UpdateStyleUI()
        end
        ColorPickerFrame:Show()
    end)
    btnNodeColor:SetPoint("LEFT", nodeLabel, "RIGHT", 10, 0)
    styleDrawer.btnNodeColor = btnNodeColor

    local sliderNodeSize = CreateStyleSlider("FarmerRoutesNodeSizeSlider", styleDrawer, 4, 24, "Size")
    sliderNodeSize:SetPoint("LEFT", btnNodeColor, "RIGHT", 20, 0)
    sliderNodeSize:SetScript("OnValueChanged", function(self, value)
        local oldStyle = NS.Utils.DeepCopy(NS.DB.settings.currentStyle)
        NS.DB.settings.currentStyle.nodeSize = value
        if NS.MapEditor and NS.MapEditor.UpdateSelectedStyle then NS.MapEditor.UpdateSelectedStyle(oldStyle) end
    end)
    styleDrawer.sliderNodeSize = sliderNodeSize

    -- Edge Styling
    local edgeLabel = styleDrawer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    edgeLabel:SetPoint("TOPLEFT", 10, -45)
    edgeLabel:SetText("Edge:")

    local btnEdgeColor = CreateColorButton(styleDrawer, "  Color", function()
        local style = NS.DB.settings.currentStyle
        -- Ensure defaults if missing
        if not style.edgeColor then return end -- Safety check

        ColorPickerFrame:SetColorRGB(style.edgeColor[1], style.edgeColor[2], style.edgeColor[3])
        ColorPickerFrame.hasOpacity = true
        ColorPickerFrame.opacity = 1 - style.edgeColor[4]
        ColorPickerFrame.previousValues = { style.edgeColor[1], style.edgeColor[2], style.edgeColor[3], style.edgeColor
            [4] }
        ColorPickerFrame.func = function()
            local oldStyle = NS.Utils.DeepCopy(NS.DB.settings.currentStyle)
            local r, g, b = ColorPickerFrame:GetColorRGB()
            local a = 1 - OpacitySliderFrame:GetValue()
            style.edgeColor = { r, g, b, a }
            Toolbar.UpdateStyleUI()
            if NS.MapEditor and NS.MapEditor.UpdateSelectedStyle then NS.MapEditor.UpdateSelectedStyle(oldStyle) end
        end
        ColorPickerFrame.swatchFunc = ColorPickerFrame.func
        ColorPickerFrame.opacityFunc = ColorPickerFrame.func
        ColorPickerFrame.cancelFunc = function(prev)
            style.edgeColor = { prev[1], prev[2], prev[3], prev[4] }
            Toolbar.UpdateStyleUI()
        end
        ColorPickerFrame:Show()
    end)
    btnEdgeColor:SetPoint("LEFT", edgeLabel, "RIGHT", 10, 0)
    styleDrawer.btnEdgeColor = btnEdgeColor

    local sliderEdgeThickness = CreateStyleSlider("FarmerRoutesEdgeThicknessSlider", styleDrawer, 1, 10, "Thickness")
    sliderEdgeThickness:SetPoint("LEFT", btnEdgeColor, "RIGHT", 20, 0)
    sliderEdgeThickness:SetScript("OnValueChanged", function(self, value)
        local oldStyle = NS.Utils.DeepCopy(NS.DB.settings.currentStyle)
        NS.DB.settings.currentStyle.edgeThickness = value
        if NS.MapEditor and NS.MapEditor.UpdateSelectedStyle then NS.MapEditor.UpdateSelectedStyle(oldStyle) end
    end)
    styleDrawer.sliderEdgeThickness = sliderEdgeThickness

    function Toolbar.UpdateStyleUI()
        local isNodeSelected = (NS.MapEditor and NS.MapEditor.selectedNodeID ~= nil)
        local isEdgeSelected = (NS.MapEditor and NS.MapEditor.selectedEdge ~= nil)
        local noSelection = not isNodeSelected and not isEdgeSelected

        -- Update Enable/Disable State
        -- Node controls are enabled if no selection or if a node is selected.
        -- If an edge is selected, node controls are disabled.
        local nodeEnabled = noSelection or isNodeSelected
        styleDrawer.btnNodeColor:SetEnabled(nodeEnabled)
        local nodeTex = styleDrawer.btnNodeColor:GetNormalTexture()
        if nodeTex then nodeTex:SetDesaturated(not nodeEnabled) end
        styleDrawer.sliderNodeSize:SetEnabled(nodeEnabled)
        local nodeSliderText = _G[styleDrawer.sliderNodeSize:GetName() .. "Text"]
        if nodeSliderText then nodeSliderText:SetAlpha(nodeEnabled and 1 or 0.5) end

        -- Edge controls are enabled if no selection, if an edge is selected,
        -- OR if a node is selected (per user request to set next edge style).
        local edgeEnabled = noSelection or isEdgeSelected or isNodeSelected
        styleDrawer.btnEdgeColor:SetEnabled(edgeEnabled)
        local edgeTex = styleDrawer.btnEdgeColor:GetNormalTexture()
        if edgeTex then edgeTex:SetDesaturated(not edgeEnabled) end
        styleDrawer.sliderEdgeThickness:SetEnabled(edgeEnabled)
        local edgeSliderText = _G[styleDrawer.sliderEdgeThickness:GetName() .. "Text"]
        if edgeSliderText then edgeSliderText:SetAlpha(edgeEnabled and 1 or 0.5) end

        if noSelection then
            -- If no selection, just use currentStyle
            local style = NS.DB.settings.currentStyle
            styleDrawer.btnNodeColor.swatch:SetColorTexture(style.nodeColor[1], style.nodeColor[2], style.nodeColor[3],
                style.nodeColor[4])
            styleDrawer.sliderNodeSize:SetValue(style.nodeSize)
            styleDrawer.btnEdgeColor.swatch:SetColorTexture(style.edgeColor[1], style.edgeColor[2], style.edgeColor[3],
                style.edgeColor[4])
            styleDrawer.sliderEdgeThickness:SetValue(style.edgeThickness)
            return
        end

        local route = NS.Routes[NS.MapEditor.activeRouteName]
        local nodeStyle, edgeStyle

        if route then
            nodeStyle = NS.Data.GetEffectiveNodeStyle(route, NS.MapEditor.selectedNodeID)
            edgeStyle = NS.Data.GetEffectiveEdgeStyle(route, NS.MapEditor.selectedEdge)
        else
            nodeStyle = NS.DB.settings.currentStyle
            edgeStyle = NS.DB.settings.currentStyle
        end

        if nodeStyle.nodeColor then
            styleDrawer.btnNodeColor.swatch:SetColorTexture(nodeStyle.nodeColor[1], nodeStyle.nodeColor[2],
                nodeStyle.nodeColor[3], nodeStyle.nodeColor[4])
        end
        styleDrawer.sliderNodeSize:SetValue(nodeStyle.nodeSize or 8)

        if edgeStyle.edgeColor then
            styleDrawer.btnEdgeColor.swatch:SetColorTexture(edgeStyle.edgeColor[1], edgeStyle.edgeColor[2],
                edgeStyle.edgeColor[3], edgeStyle.edgeColor[4])
        end
        styleDrawer.sliderEdgeThickness:SetValue(edgeStyle.edgeThickness or 2)
    end

    -- Add some utility buttons to the bottom of the drawer
    local btnSetRoute = CreateFrame("Button", nil, styleDrawer, "UIPanelButtonTemplate")
    btnSetRoute:SetSize(120, 22)
    btnSetRoute:SetPoint("BOTTOMLEFT", 10, 10)
    btnSetRoute:SetText("Set Route Def")
    btnSetRoute:SetScript("OnClick", function()
        if NS.MapEditor.activeRouteName then
            local route = NS.Routes[NS.MapEditor.activeRouteName]
            if route then
                route.style = NS.Utils.DeepCopy(NS.DB.settings.currentStyle)
                print("|cFFFFFF00FarmerRoutes|r: Route default style updated.")
            end
        end
    end)
    btnSetRoute:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Set Route Default")
        GameTooltip:AddLine(
        "Saves current style as the default for all nodes/edges in this route (that don't have overrides).", 1, 1, 1)
        GameTooltip:Show()
    end)
    btnSetRoute:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local btnClear = CreateFrame("Button", nil, styleDrawer, "UIPanelButtonTemplate")
    btnClear:SetSize(120, 22)
    btnClear:SetPoint("LEFT", btnSetRoute, "RIGHT", 10, 0)
    btnClear:SetText("Clear Override")
    btnClear:SetScript("OnClick", function()
        if NS.MapEditor.activeRouteName then
            local route = NS.Routes[NS.MapEditor.activeRouteName]
            if NS.MapEditor.selectedNodeID then
                local node = route.nodes[NS.MapEditor.selectedNodeID]
                if node then node.style = nil end
            elseif NS.MapEditor.selectedEdge then
                NS.MapEditor.selectedEdge.style = nil
            end
            -- Refresh
            Toolbar.UpdateStyleUI()
            if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
            if NS.MinimapRenderer then NS.MinimapRenderer.MarkDirty() end
        end
    end)
    btnClear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Clear Override")
        GameTooltip:AddLine(
        "Removes individual style from selected item, making it inherit from the route or global default.", 1, 1, 1)
        GameTooltip:Show()
    end)
    btnClear:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdateToolbarUI()

    if NS.DB.settings.mapToolbarHidden then
        Toolbar.toolbarFrame:Hide()
    else
        Toolbar.toolbarFrame:Show()
    end
end

function Toolbar.Refresh()
    if Toolbar.toolbarFrame then
        UIDropDownMenu_Initialize(Toolbar.toolbarFrame.routeDropdown, InitializeDropdown)
        UpdateToolbarUI()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        Toolbar.Init()
    end
end)
