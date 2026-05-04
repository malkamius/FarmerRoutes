local ADDON_NAME, NS = ...

NS.StringImportExportUI = {}
local UI = NS.StringImportExportUI

local importFrame
local exportFrame

function UI.CreateImportFrame()
    if importFrame then return importFrame end

    local f = CreateFrame("Frame", "FarmerRoutesStringImportFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(450, 300)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    
    f.TitleText:SetText("FarmerRoutes Import")
    
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 20, -40)
    label:SetText("Paste route string here (Ctrl+V):")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "InputScrollFrameTemplate")
    scrollFrame:SetSize(410, 150)
    scrollFrame:SetPoint("TOPLEFT", 20, -60)
    
    f.editBox = scrollFrame.EditBox
    f.editBox:SetWidth(410)
    f.editBox:SetMaxLetters(0)
    
    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetSize(120, 25)
    importBtn:SetPoint("BOTTOM", 0, 20)
    importBtn:SetText("Import")
    
    importBtn:SetScript("OnClick", function()
        local text = f.editBox:GetText()
        local success, result = NS.ImportExport.ImportRoute(text)
        if success then
            print("|cFFFFFF00FarmerRoutes|r: Imported route '" .. result .. "'")
            if NS.MapToolbar and NS.MapToolbar.Refresh then NS.MapToolbar.Refresh() end
            if NS.MapRenderer then NS.MapRenderer.DrawRoutes() end
            f:Hide()
        else
            UI.ShowError("Import Failed: " .. tostring(result))
        end
    end)
    
    importFrame = f
    return f
end

function UI.CreateExportFrame()
    if exportFrame then return exportFrame end

    local f = CreateFrame("Frame", "FarmerRoutesStringExportFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(450, 300)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    
    f.TitleText:SetText("FarmerRoutes Export")
    
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 20, -40)
    label:SetText("Copy route string (Ctrl+C):")
    
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "InputScrollFrameTemplate")
    scrollFrame:SetSize(410, 180)
    scrollFrame:SetPoint("TOPLEFT", 20, -60)
    
    f.editBox = scrollFrame.EditBox
    f.editBox:SetWidth(410)
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(120, 25)
    closeBtn:SetPoint("BOTTOM", 0, 20)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    exportFrame = f
    return f
end

function UI.ShowImport()
    local f = UI.CreateImportFrame()
    f.editBox:SetText("")
    f:Show()
    f.editBox:SetFocus()
end

function UI.ShowExport(routeName)
    local str = NS.ImportExport.ExportRoute(routeName)
    if not str then return end
    
    local f = UI.CreateExportFrame()
    f.editBox:SetText(str)
    f:Show()
    f.editBox:HighlightText()
    f.editBox:SetFocus()
end

function UI.ShowError(msg)
    StaticPopup_Show("FARMERROUTES_ERROR", msg)
end

-- Error Popup
StaticPopupDialogs["FARMERROUTES_ERROR"] = {
    text = "%s",
    button1 = "OK",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}
