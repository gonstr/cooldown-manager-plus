local addonName, addon = ...
local compact = {}
addon.Compact = compact
local model = addon.CompactModel
local frame = CreateFrame('Frame', nil, UIParent)
local anchor = CreateFrame('Frame', nil, UIParent)
anchor:SetSize(1, 1)
local edge = CreateFrame('Frame', nil, UIParent)
edge:SetSize(1, 1)
edge:Hide()
local currentSwing
local continuousSpark = false
local glowWidth, glowHeight = 18, 8
local haloWidth, haloHeight = 36, 18
local swingSegments = setmetatable({}, {__mode = 'k'})
local activeSegments = {}
local function HideSegments()
    for _, segment in pairs(swingSegments) do segment.clip:Hide() end
end
local function PrepareSegments(items, spacing, inset)
    local sideInset = continuousSpark and 0 or 3
    local cursor = 0
    HideSegments()
    activeSegments = {}
    for index, item in ipairs(items) do
        local itemScale = item:GetEffectiveScale() / edge:GetEffectiveScale()
        local itemWidth = item:GetWidth() * itemScale
        local segment = swingSegments[item]
        if not segment and not InCombatLockdown() then
            local clip = CreateFrame('Frame', nil, edge)
            clip:SetClipsChildren(true)
            local glow = clip:CreateTexture(nil, 'OVERLAY', nil, 1)
            glow:SetTexture('Interface\\AddOns\\' .. addonName .. '\\Media\\SwingHighlight')
            glow:SetBlendMode('ADD')
            glow:SetSize(glowWidth, glowHeight)
            local halo = clip:CreateTexture(nil, 'OVERLAY', nil, 0)
            halo:SetTexture('Interface\\AddOns\\' .. addonName .. '\\Media\\SwingHalo')
            halo:SetBlendMode('ADD')
            halo:SetSize(haloWidth, haloHeight)
            segment = {clip = clip, glow = glow, halo = halo, item = item}
            swingSegments[item] = segment
        end
        if segment then
            local icon = item.Icon or item
            segment.scale = itemScale
            -- Partition the whole row at the midpoint between adjacent icons.
            -- Only the outer ends are inset; the glow stays continuous inside.
            local leftInset = index == 1 and sideInset or -spacing / (2 * itemScale)
            local rightInset = index == #items and sideInset or -spacing / (2 * itemScale)
            segment.left = cursor + leftInset * itemScale
            segment.right = cursor + itemWidth - rightInset * itemScale
            segment.clip:SetScale(itemScale)
            segment.clip:ClearAllPoints()
            segment.clip:SetPoint('TOPLEFT', icon, 'TOPLEFT', leftInset, -inset)
            segment.clip:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', -rightInset, inset)
            activeSegments[#activeSegments + 1] = segment
        end
        cursor = cursor + itemWidth + spacing
    end
end
local function DrawSegments(progress)
    if not progress then HideSegments(); return end
    -- Screen-space coordinates become secret in combat. Use only the logical
    -- layout measured in PrepareSegments; anchors handle actual screen placement.
    local left, right
    for _, segment in ipairs(activeSegments) do
        left = math.min(left or segment.left, segment.left)
        right = math.max(right or segment.right, segment.right)
    end
    if not left then return end
    local position = left + (1 - progress) * (right - left)
    for _, segment in ipairs(activeSegments) do
        if segment.left then
            local scale = segment.scale
            local center = (position - segment.left) / scale
            local iconWidth = (segment.right - segment.left) / scale
            local function DrawGlow(texture, width)
                texture:ClearAllPoints()
                local start = math.max(0, center - width / 2)
                local finish = math.min(iconWidth, center + width / 2)
                local visible = finish > start
                if visible then
                    texture:SetWidth(math.max(0.001, finish - start))
                    texture:SetTexCoord((start - center + width / 2) / width, (finish - center + width / 2) / width, 0, 1)
                    texture:SetPoint('CENTER', segment.clip, 'TOPLEFT', (start + finish) / 2, 0)
                end
                texture:SetShown(visible)
            end
            DrawGlow(segment.glow, glowWidth)
            DrawGlow(segment.halo, haloWidth)
            segment.clip:Show()
        end
    end
end

local hooked = setmetatable({}, {__mode = 'k'})
local changedItems = setmetatable({}, {__mode = 'k'})
local applying, queued, sparkWidth = false, false, 0

local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function GetViewers()
    return {EssentialCooldownViewer, UtilityCooldownViewer, BuffIconCooldownViewer}
end

local function IsEditing()
    for _, viewer in ipairs(GetViewers()) do
        if viewer:IsEditing() then return true end
    end
    return false
end

local function Items(viewer, includeCombatHidden, includeInactive)
    local items = {}
    if viewer and viewer.itemFramePool then
        for item in viewer.itemFramePool:EnumerateActive() do
            if (item:IsShown() or includeInactive) and (includeCombatHidden or not addon.Cooldowns or addon.Cooldowns:ShouldDisplayItem(item)) then
                items[#items + 1] = item
            end
        end
    end
    table.sort(items, function(a, b) return (a.layoutIndex or 0) < (b.layoutIndex or 0) end)
    return items
end

local function Movable(item)
    return not (InCombatLockdown() and item:IsProtected())
end

local function PlaceRow(items, positions, y, split)
    for i, item in ipairs(items) do
        if Movable(item) then
            local viewer = item:GetViewerFrame()
            item:SetScale(viewer and viewer.iconScale or item:GetScale())
            changedItems[item] = true
            item:ClearAllPoints()
            if i == 1 or i == split then
                item:SetPoint('CENTER', anchor, 'CENTER', positions[i] / item:GetScale(), y / item:GetScale())
            else
                -- Match Blizzard's -4px art-padding compensation. Direct edge
                -- anchoring keeps adjacent icons together at every icon scale.
                item:SetPoint('LEFT', items[i - 1], 'RIGHT', addon.Buffs:GetDB().iconZoom and 0 or -4, 0)
            end
        end
    end
end

function compact:QueueUpdate()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        compact:Apply()
    end)
end

local function RestoreItems()
    local touched = {}
    for item in pairs(changedItems) do
        if Movable(item) then
            local viewer = item:GetViewerFrame()
            if viewer then
                item:SetScale(viewer.iconScale or 1)
                touched[viewer] = true
            end
            changedItems[item] = nil
        end
    end
    for viewer in pairs(touched) do
        if not (InCombatLockdown() and viewer:IsProtected()) then
            viewer:GetItemContainerFrame():Layout()
        end
    end
end

function compact:GetSparkViewer()
    -- Count configured frames, including essentials hidden outside combat.
    if #Items(EssentialCooldownViewer, true) >= 3 then return EssentialCooldownViewer end
    if #Items(UtilityCooldownViewer, true) >= 3 then return UtilityCooldownViewer end
end

function compact:Apply()
    if applying then return end
    applying = true
    local db = addon.Buffs:GetDB()
    local essential = EssentialCooldownViewer
    local available = essential ~= nil and not IsEditing()
    local compactEnabled = db.compact == true and available
    local sparksEnabled = db.swingSparks == true and C_SwingTimer ~= nil and available
    if not compactEnabled then RestoreItems() end
    if not compactEnabled and not sparksEnabled then
        edge:Hide()
        HideSegments()
        applying = false
        return
    end
    local essentials = Items(essential, not db.centerIcons, not db.centerIcons)
    local utilities = Items(UtilityCooldownViewer, not db.centerIcons, not db.centerIcons)
    local function NativeSize(items, viewer)
        local first = items[1]
        return first and first:GetWidth() * (viewer.iconScale or first:GetScale()) or 0
    end
    -- Visibility filtering must not collapse the essential row's layout space.
    -- Reserve its native icon height so buffs and utility stay put out of combat.
    local essentialSize = NativeSize(Items(essential, true), essential)
    local utilitySize = NativeSize(Items(UtilityCooldownViewer, true), UtilityCooldownViewer)
    local buffItems = Items(BuffIconCooldownViewer)
    if not db.centerIcons then
        -- Fixed mode retains every tracked slot, including inactive buffs.
        buffItems = {}
        for _, entry in ipairs(addon.Buffs:GetEntries()) do
            buffItems[#buffItems + 1] = entry.item
        end
    end
    local buffSize = NativeSize(buffItems, BuffIconCooldownViewer)
    local artPadding = db.iconZoom and 0 or -4
    local essentialSpacing = artPadding * (essential.iconScale or 1)
    local utilitySpacing = artPadding * (UtilityCooldownViewer and UtilityCooldownViewer.iconScale or 1)
    local buffSpacing = artPadding * (BuffIconCooldownViewer and BuffIconCooldownViewer.iconScale or 1)
    local geometry = model.Geometry(#essentials, #utilities, essentialSize, essentialSpacing, 10, utilitySize, buffSize)
    self.reminderY = geometry.buffY + buffSize / 2
    geometry.utilityX = model.RowPositions(#utilities, utilitySize, utilitySpacing)
    geometry.utilityY = -(essentialSize + utilitySize) / 2 + math.min(-essentialSpacing, -utilitySpacing)
    anchor:ClearAllPoints()
    anchor:SetPoint('CENTER', essential, 'CENTER')
    anchor:SetScale(essential:GetEffectiveScale() / UIParent:GetEffectiveScale())
    if compactEnabled then
        PlaceRow(essentials, geometry.essentialX, 0)
        PlaceRow(utilities, geometry.utilityX, geometry.utilityY)
        local buffPositions = model.RowPositions(#buffItems, buffSize, buffSpacing)
        local split
        if db.separateBuffs then
            buffItems, buffPositions, split = addon.Buffs:GetSplitLayout(buffItems, buffSize, buffSpacing)
        end
        PlaceRow(buffItems, buffPositions, geometry.buffY, split)
    end

    local shownViewer = self:GetSparkViewer()
    local shownItems = shownViewer and Items(shownViewer) or {}
    local utilityFallback = shownViewer == UtilityCooldownViewer
    local rowY = utilityFallback and geometry.utilityY or 0
    local rowSize = utilityFallback and utilitySize or essentialSize
    local rowSpacing = utilityFallback and utilitySpacing or essentialSpacing
    local _, rowWidth = model.RowPositions(#shownItems, rowSize, rowSpacing)
    sparkWidth = #shownItems >= 3 and (compactEnabled and rowWidth or shownViewer:GetWidth()) or 0
    edge:ClearAllPoints()
    if compactEnabled then
        edge:SetPoint('CENTER', anchor, 'CENTER', 0, rowY + rowSize / 2)
    else
        edge:SetPoint('CENTER', shownViewer or essential, 'TOP', 0, 0)
    end
    edge:SetScale(anchor:GetScale())
    edge:SetWidth(math.max(1, sparkWidth))
    edge:SetFrameStrata((shownViewer or essential):GetFrameStrata())
    edge:SetFrameLevel((shownViewer or essential):GetFrameLevel() + 20)
    edge:SetAlpha(1)
    continuousSpark = db.iconZoom == true
    local swingViewer = shownViewer or essential
    PrepareSegments(shownItems, compactEnabled and rowSpacing
        or ((swingViewer.iconPadding or 0) + artPadding) * (swingViewer.iconScale or 1),
        continuousSpark and 0 or 0.5)
    local inCombat = UnitAffectingCombat('player')
    local timerShown = sparksEnabled and sparkWidth > 0 and shownViewer and shownViewer:IsShown() and inCombat
    edge:SetShown(timerShown)
    if addon.BuffReminder then addon.BuffReminder:Update(addon.Buffs:GetEntries(), false) end
    applying = false
end

function compact:GetReminderAnchor()
    if addon.Buffs:GetDB().compact and self.reminderY then return anchor, self.reminderY end
end

function compact:SetEnabled(enabled)
    addon.Buffs:GetDB().compact = enabled
    self:Apply()
    addon.Buffs:Refresh()
end

function compact:SetSparksEnabled(enabled)
    addon.Buffs:GetDB().swingSparks = enabled == true
    addon.Buffs:GetDB().swingStyle = nil
    if not enabled then
        currentSwing = nil
        HideSegments()
    end
    self:Apply()
    addon.Buffs:Refresh()
end

local function Attach()
    for _, viewer in ipairs(GetViewers()) do
        if not hooked[viewer] and viewer.itemFramePool then
            hooked[viewer] = true
            hooksecurefunc(viewer:GetItemContainerFrame(), 'Layout', function() compact:Apply() end)
            hooksecurefunc(viewer, 'RefreshData', function() compact:QueueUpdate() end)
            hooksecurefunc(viewer, 'SetIsEditing', function() compact:QueueUpdate() end)
            viewer:HookScript('OnShow', function() compact:QueueUpdate() end)
            viewer:HookScript('OnHide', function() compact:QueueUpdate() end)
        end
    end
end

edge:SetScript('OnUpdate', function()
    if not UnitAffectingCombat('player') then
        HideSegments()
        edge:Hide()
        currentSwing = nil
        return
    end
    local swing = currentSwing
    local progress = swing and model.SwingProgress(swing.start, swing.duration, GetTime())
    DrawSegments(progress)
    if not progress then currentSwing = nil end
end)

frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('ADDON_LOADED')
frame:RegisterEvent('PLAYER_ENTERING_WORLD')
frame:RegisterEvent('PLAYER_REGEN_ENABLED')
frame:RegisterEvent('PLAYER_REGEN_DISABLED')
frame:RegisterEvent('WEAPON_SLOT_CHANGED')
if C_SwingTimer then frame:RegisterEvent('PLAYER_SWING') end
frame:SetScript('OnEvent', function(_, event, duration, swingType)
    if event == 'PLAYER_SWING' then
        if UnitAffectingCombat('player') and addon.Buffs:GetDB().swingSparks and Readable(duration) and Readable(swingType)
            and type(duration) == 'number' and duration > 0 and (swingType == 0 or swingType == 2) then
            currentSwing = {start = GetTime(), duration = duration, kind = swingType}
        end
        return
    elseif event == 'PLAYER_REGEN_ENABLED' or event == 'PLAYER_ENTERING_WORLD' then
        currentSwing = nil
        HideSegments()
        if event == 'PLAYER_REGEN_ENABLED' then
            edge:Hide()
            compact:Apply()
        end
    elseif event == 'WEAPON_SLOT_CHANGED' then
        local main, off, ranged = UnitAttackSpeed('player')
        local durations = {[0] = main, [1] = off, [2] = ranged}
        if currentSwing then
            local equipped = durations[currentSwing.kind]
            if Readable(equipped) and type(equipped) == 'number' and equipped > 0 then
                currentSwing.start, currentSwing.duration = GetTime(), equipped
            else
                currentSwing = nil
            end
        end
    end
    Attach()
    compact:QueueUpdate()
end)
Attach()
