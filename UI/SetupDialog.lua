local _, addon = ...
local dialogs = {}
addon.SetupDialog = dialogs
local exportInstruction = 'Copy this string to share your Blizzard layout and CM Plus settings.'
local importInstruction = 'Paste a settings string to import a Blizzard layout and CM Plus settings.'

function dialogs:Create(owner)
    local dialog = CreateFrame('Frame', nil, owner, 'BackdropTemplate')
    dialog:SetSize(470, 370)
    dialog:SetPoint('CENTER', UIParent, 'CENTER')
    dialog:SetFrameStrata('DIALOG')
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',
        edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',tile=true,tileSize=32,edgeSize=16,
        insets={left=4,right=4,top=4,bottom=4}})
    local title = dialog:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
    title:SetPoint('TOPLEFT', dialog, 'TOPLEFT', 20, -18)
    local close = CreateFrame('Button', nil, dialog, 'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT', dialog, 'TOPRIGHT', -3, -3)
    close:SetScript('OnClick', function() dialog:Hide() end)
    local status = dialog:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    status:SetPoint('TOPLEFT', dialog, 'TOPLEFT', 20, -50)
    status:SetWidth(425)
    status:SetJustifyH('LEFT')
    status:SetWordWrap(true)
    local scroll = CreateFrame('ScrollFrame', nil, dialog, 'ScrollFrameTemplate')
    scroll:SetPoint('TOPLEFT', status, 'BOTTOMLEFT', 0, -10)
    scroll:SetPoint('BOTTOMRIGHT', dialog, 'BOTTOMRIGHT', -40, 55)
    local inputBorder = CreateFrame('Frame', nil, dialog, 'BackdropTemplate')
    inputBorder:SetAllPoints(scroll)
    inputBorder:SetFrameLevel(math.max(0, scroll:GetFrameLevel()-1))
    inputBorder:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',
        edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,
        insets={left=3,right=3,top=3,bottom=3}})
    inputBorder:SetBackdropColor(0.02,0.02,0.02,0.9)
    inputBorder:SetBackdropBorderColor(0.5,0.5,0.5,1)
    local edit = CreateFrame('EditBox', nil, scroll)
    edit:SetPoint('TOPLEFT', scroll, 'TOPLEFT', 0, 0)
    edit:EnableMouse(true)
    edit:EnableKeyboard(true)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(GameFontHighlightSmall)
    edit:SetWidth(400)
    edit:SetHeight(140)
    edit:SetTextInsets(4,4,4,4)
    edit:SetMaxLetters(200000)
    scroll:SetScrollChild(edit)
    scroll:EnableMouse(true)
    scroll:SetScript('OnMouseDown', function() edit:SetFocus() end)
    edit:SetScript('OnMouseDown', function() edit:SetFocus() end)
    local measure = dialog:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    measure:SetWidth(390)
    measure:SetWordWrap(true)
    measure:Hide()
    local action = CreateFrame('Button', nil, dialog, 'UIPanelButtonTemplate')
    action:SetSize(150, 26)
    action:SetPoint('BOTTOMRIGHT', dialog, 'BOTTOMRIGHT', -20, 16)
    local cancel = CreateFrame('Button', nil, dialog, 'UIPanelButtonTemplate')
    cancel:SetSize(100, 26)
    cancel:SetPoint('RIGHT', action, 'LEFT', -10, 0)
    cancel:SetText(CANCEL or 'Cancel')
    cancel:SetScript('OnClick', function() dialog:Hide() end)
    dialog.edit, dialog.status, dialog.action = edit, status, action
    edit:SetScript('OnEscapePressed', function() dialog:Hide() end)
    dialog:SetScript('OnHide', function() edit:ClearFocus() end)
    edit:SetScript('OnTextChanged', function()
        measure:SetText(edit:GetText())
        edit:SetHeight(math.max(140, measure:GetStringHeight()+16))
        scroll:UpdateScrollChildRect()
        if dialog.mode=='import' then
            status:SetText(importInstruction)
        end
    end)
    action:SetScript('OnClick', function()
        if dialog.mode=='export' then
            edit:SetFocus(); edit:HighlightText()
            status:SetText(exportInstruction)
        else
            local ok, message = addon.SettingsTransfer:Import(edit:GetText())
            if not ok then status:SetText(message) else dialog:Hide() end
        end
    end)
    function dialog:OpenImport()
        self.mode='import'
        edit:SetText('')
        title:SetText('Import settings')
        action:SetEnabled(true)
        action:SetText('Import')
        status:SetText(importInstruction)
        self:Show(); edit:SetFocus()
    end
    function dialog:OpenExport()
        self.mode='export'
        local text, message=addon.SettingsTransfer:Export()
        edit:SetText(text or '')
        title:SetText('Export settings')
        status:SetText(text and exportInstruction or message)
        action:SetText('Select string')
        action:SetEnabled(text~=nil)
        self:Show(); edit:SetFocus(); edit:HighlightText()
    end
    dialog:Hide()
    return dialog
end
