local _, addon = ...
local style = {}
addon.IconStyle = style
local originals = setmetatable({}, {__mode = 'k'})
local hooked = setmetatable({}, {__mode = 'k'})
local zoomBorders = setmetatable({}, {__mode = 'k'})
local queued
local frame = CreateFrame('Frame')
local unpackValues = unpack or table.unpack

local function SetZoomBorder(item, enabled)
    local edges = zoomBorders[item]
    if enabled and not edges then
        edges = {}
        for _, side in ipairs({'TOP', 'BOTTOM', 'LEFT', 'RIGHT'}) do
            local edge = item:CreateTexture(nil, 'OVERLAY', nil, 7)
            edge:SetColorTexture(0, 0, 0, 1)
            if side == 'TOP' or side == 'BOTTOM' then
                edge:SetPoint(side .. 'LEFT', item.Icon, side .. 'LEFT')
                edge:SetPoint(side .. 'RIGHT', item.Icon, side .. 'RIGHT')
                edge:SetHeight(1)
            else
                edge:SetPoint('TOP' .. side, item.Icon, 'TOP' .. side)
                edge:SetPoint('BOTTOM' .. side, item.Icon, 'BOTTOM' .. side)
                edge:SetWidth(1)
            end
            edges[#edges + 1] = edge
        end
        zoomBorders[item] = edges
    end
    if edges then
        for _, edge in ipairs(edges) do edge:SetShown(enabled) end
    end
end

function style:ApplyItem(item, enabled)
    local icon = item.Icon
    if not icon or not icon.SetTexCoord then return end
    local original = originals[item]
    if enabled then
        if not original then
            original = {coords = {icon:GetTexCoord()}, masks = {}, borders = {}}
            for _, region in ipairs({item:GetRegions()}) do
                local atlas = region.GetAtlas and region:GetAtlas()
                if region:GetObjectType() == 'MaskTexture' and atlas == 'UI-HUD-CoolDownManager-Mask' then
                    original.masks[#original.masks + 1] = region
                elseif atlas == 'UI-HUD-CoolDownManager-IconOverlay' then
                    original.borders[region] = region:GetAlpha()
                end
            end
            originals[item] = original
            for _, mask in ipairs(original.masks) do icon:RemoveMaskTexture(mask) end
        end
        -- Crop 15% from every edge: display the central 70% of the texture.
        icon:SetTexCoord(0.15, 0.85, 0.15, 0.85)
        for border in pairs(original.borders) do border:SetAlpha(0) end
    elseif original then
        icon:SetTexCoord(unpackValues(original.coords))
        for _, mask in ipairs(original.masks) do icon:AddMaskTexture(mask) end
        for border, alpha in pairs(original.borders) do border:SetAlpha(alpha) end
        originals[item] = nil
    end
    SetZoomBorder(item, enabled)
end

function style:Apply()
    local enabled = addon.Buffs:GetDB().iconZoom == true
    for _, viewer in pairs({EssentialCooldownViewer, UtilityCooldownViewer, BuffIconCooldownViewer}) do
        if viewer.itemFramePool then
            for item in viewer.itemFramePool:EnumerateActive() do
                if not hooked[item] then
                    hooked[item] = true
                    hooksecurefunc(item, 'RefreshSpellTexture', function() style:QueueUpdate() end)
                end
                self:ApplyItem(item, enabled)
            end
        end
    end
end

function style:QueueUpdate()
    if queued then return end
    queued = true
    C_Timer.After(0, function() queued = false; style:Apply() end)
end

function style:SetEnabled(enabled)
    addon.Buffs:GetDB().iconZoom = enabled
    self:Apply()
    addon.Compact:QueueUpdate()
end

frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('ADDON_LOADED')
frame:SetScript('OnEvent', function()
    for _, viewer in pairs({EssentialCooldownViewer, UtilityCooldownViewer, BuffIconCooldownViewer}) do
        if not hooked[viewer] and viewer.itemFramePool then
            hooked[viewer] = true
            hooksecurefunc(viewer, 'RefreshData', function() style:QueueUpdate() end)
        end
    end
    style:QueueUpdate()
end)
