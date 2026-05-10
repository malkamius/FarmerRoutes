local ADDON_NAME, NS = ...

NS.MapRenderer = {}
local Renderer = NS.MapRenderer

--
-- Canvas setup
--
local function GetCanvas()
    if WorldMapFrame.GetCanvas then
        return WorldMapFrame:GetCanvas()
    elseif WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child then
        return WorldMapFrame.ScrollContainer.Child
    end
    return WorldMapFrame -- Fallback
end

local drawLayer

local function GetDrawLayer()
    if not drawLayer then
        local canvas = GetCanvas()
        if canvas then
            drawLayer = CreateFrame("Frame", "FarmerRoutesWorldMapLayer", canvas)
            drawLayer:SetAllPoints(canvas)
            drawLayer:SetFrameStrata("FULLSCREEN")
            drawLayer:SetFrameLevel(2000)
        end
    end
    return drawLayer
end

--
-- Object Pooling
--
local linePool = {}
local activeLines = {}

local nodePool = {}
local activeNodes = {}

local function AcquireLine()
    local line = table.remove(linePool)
    if not line then
        local dl = GetDrawLayer()
        if not dl then return end
        line = dl:CreateLine(nil, "OVERLAY")
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

local function AcquireNode()
    local node = table.remove(nodePool)
    if not node then
        local dl = GetDrawLayer()
        if not dl then return end
        node = CreateFrame("Frame", nil, dl)
        node:SetSize(8, 8)

        -- Inner color
        node.tex = node:CreateTexture(nil, "OVERLAY")
        node.tex:SetAllPoints()
        node.tex:SetColorTexture(1, 1, 1, 1)

        -- Border
        node.border = node:CreateTexture(nil, "BORDER")
        node.border:SetPoint("TOPLEFT", -1, 1)
        node.border:SetPoint("BOTTOMRIGHT", 1, -1)
        node.border:SetColorTexture(0, 0, 0, 1)

        -- Circular Mask
        node.mask = node:CreateMaskTexture()
        node.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        node.mask:SetAllPoints(node.tex)
        node.tex:AddMaskTexture(node.mask)

        node.borderMask = node:CreateMaskTexture()
        node.borderMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        node.borderMask:SetAllPoints(node.border)
        node.border:AddMaskTexture(node.borderMask)
    end
    node:Show()
    table.insert(activeNodes, node)
    return node
end

local function ReleaseAllNodes()
    for _, node in ipairs(activeNodes) do
        node:Hide()
        table.insert(nodePool, node)
    end
    table.wipe(activeNodes)
end

--
-- Rendering Logic
--
local lastDrawnMapID = nil

function Renderer.DrawRoutes()
    if not WorldMapFrame:IsShown() then return end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then return end

    -- Only clear and redraw if we really need to, but for now we'll redraw on every call
    ReleaseAllLines()
    ReleaseAllNodes()

    local canvas = GetCanvas()
    local canvasWidth = canvas:GetWidth()
    local canvasHeight = canvas:GetHeight()

    local selectedNodeID = NS.MapEditor and NS.MapEditor.GetSelectedNode() or nil
    local selectedEdge = NS.MapEditor and NS.MapEditor.GetSelectedEdge() or nil
    local activeRouteName = NS.MapEditor and NS.MapEditor.activeRouteName or nil

    -- Safety check if canvas size is 0 (can happen while loading)
    if canvasWidth == 0 or canvasHeight == 0 then return end

    local settings = NS.DB.settings
    if not settings.worldmapEnabled then return end

    for routeName, route in pairs(NS.Routes) do
        if (route.visible or routeName == activeRouteName) and route.mapID == mapID then
            local r, g, b, a = unpack(route.color)
            local isEditingRoute = (routeName == activeRouteName)
            if isEditingRoute then a = 1.0 end -- Fully opaque if editing

            -- Draw Edges (Lines)
            for _, edge in ipairs(route.edges) do
                local node1 = route.nodes[edge[1]]
                local node2 = route.nodes[edge[2]]

                if node1 and node2 then
                    local line = AcquireLine()

                    local isSelectedEdge = (routeName == activeRouteName) and selectedEdge and
                        ((selectedEdge[1] == edge[1] and selectedEdge[2] == edge[2]) or (selectedEdge[1] == edge[2] and selectedEdge[2] == edge[1]))

                    local style = NS.Data.GetEffectiveEdgeStyle(route, edge)

                    if isSelectedEdge and NS.MapEditor.isEditing and isEditingRoute then
                        local r, g, b, a = unpack(style.edgeColor)
                        line:SetColorTexture(r, g, b, a)
                        line:SetThickness(style.edgeThickness + 6)
                    else
                        local r, g, b, a = unpack(style.edgeColor)
                        line:SetColorTexture(r, g, b, a)
                        line:SetThickness(style.edgeThickness + (NS.MapEditor.isEditing and isEditingRoute and 4 or 2))
                    end

                    line:SetDrawLayer("OVERLAY", 7)

                    -- Convert normalized coordinates to canvas coordinates
                    local x1 = node1.x * canvasWidth
                    local y1 = -node1.y * canvasHeight
                    local x2 = node2.x * canvasWidth
                    local y2 = -node2.y * canvasHeight

                    line:ClearAllPoints()
                    line:SetStartPoint("TOPLEFT", canvas, x1, y1)
                    line:SetEndPoint("TOPLEFT", canvas, x2, y2)
                    line:Show()
                end
            end

            -- Draw Nodes
            for id, nodeData in pairs(route.nodes) do
                local node = AcquireNode()
                local style = NS.Data.GetEffectiveNodeStyle(route, id)

                local nr, ng, nb, na = unpack(style.nodeColor)
                local ns = style.nodeSize

                -- if isEditingRoute then na = 1.0 end

                node.tex:SetColorTexture(nr, ng, nb, na)

                local isSelectedNode = (routeName == activeRouteName) and (id == selectedNodeID)

                if isSelectedNode then
                    node:SetSize(ns + 6, ns + 6)
                    node.border:SetColorTexture(1, 0.9, 0, 0.8)
                else
                    node:SetSize(ns, ns)
                    node.border:SetColorTexture(0.65, 0.65, 0.65, 0.6)
                end

                local x = nodeData.x * canvasWidth
                local y = -nodeData.y * canvasHeight

                local dl = GetDrawLayer()
                node:SetPoint("CENTER", dl, "TOPLEFT", x, y)
            end
        end
    end

    lastDrawnMapID = mapID
end

function Renderer.Clear()
    ReleaseAllLines()
    ReleaseAllNodes()
    lastDrawnMapID = nil
end

--
-- Event Hooks
--
local EventFrame = CreateFrame("Frame")

-- Wait until PLAYER_LOGIN to hook into the map frame reliably
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Hook Map Changes
        hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
            Renderer.DrawRoutes()
        end)

        -- Hook Map Show/Hide
        WorldMapFrame:HookScript("OnShow", function()
            Renderer.DrawRoutes()
        end)

        WorldMapFrame:HookScript("OnHide", function()
            Renderer.Clear()
        end)
    end
end)
