local _, addon = ...
local reminder = {}
addon.BuffReminder = reminder
local frame = CreateFrame('Frame', nil, UIParent)
frame:SetSize(440, 120)
frame:SetFrameStrata('HIGH')
frame:EnableMouse(false)
frame:Hide()
local text = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalHuge')
text:SetPoint('BOTTOM', frame, 'BOTTOM')
text:SetWidth(440)
text:SetJustifyH('CENTER')
text:SetTextColor(1, 0.8, 0.2)
local lastMessage
local function SetBounceOffset(offset)
    text:ClearAllPoints()
    text:SetPoint('BOTTOM', frame, 'BOTTOM', 0, offset)
end
local function StopBounce()
    frame:SetScript('OnUpdate', nil)
    SetBounceOffset(0)
end
local function StartBounce()
    local elapsed = 0
    SetBounceOffset(0)
    frame:SetScript('OnUpdate', function(_, delta)
        elapsed = (elapsed + delta) % 0.4
        SetBounceOffset(8 * math.sin(elapsed * math.pi / 0.4))
    end)
end
function reminder:Update(entries, editing)
    local message = not editing and UnitAffectingCombat('player') and addon.BuffLayoutModel.MissingReminders(entries, addon.Buffs:GetDB().notifyMissingSelfBuffs) or ''
    local parent = BuffIconCooldownViewer
    local compactAnchor, y
    if addon.Compact then compactAnchor, y = addon.Compact:GetReminderAnchor() end
    if message == '' or not parent then
        StopBounce()
        lastMessage = nil
        frame:Hide()
        return
    end
    frame:ClearAllPoints()
    if compactAnchor then
        frame:SetPoint('BOTTOM', compactAnchor, 'CENTER', 0, y + 16)
    else
        frame:SetPoint('BOTTOM', parent, 'TOP', 0, 16)
    end
    text:SetText(message)
    frame:Show()
    if message ~= lastMessage then
        lastMessage = message
        StartBounce()
    end
end
