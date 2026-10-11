local _, addon = ...
local rows = {}
addon.CenteredRows = rows
local originals = setmetatable({}, {__mode='k'})
local hooked = setmetatable({}, {__mode='k'})
local unpackValues = unpack or table.unpack
local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end
local function Movable(item)
    return not (InCombatLockdown() and item:IsProtected())
end
local function Capture(item, viewer)
    local x, y = item:GetCenter()
    local vx, vy = viewer:GetCenter()
    if not Readable(x) or not Readable(y) or not Readable(vx) or not Readable(vy)
        or not x or not y or not vx or not vy then return end
    local scale, viewerScale = item:GetEffectiveScale(), viewer:GetEffectiveScale()
    local state = {points={}, x=x*scale-vx*viewerScale, y=y*scale-vy*viewerScale}
    for i=1,item:GetNumPoints() do state.points[i]={item:GetPoint(i)} end
    return state
end
local function Restore(item)
    local state = originals[item]
    if state and Movable(item) then
        item:ClearAllPoints()
        for _, point in ipairs(state.points) do item:SetPoint(unpackValues(point)) end
        originals[item] = nil
    end
end
function rows:Apply(viewer, entries)
    if not viewer then return end
    local container = viewer:GetItemContainerFrame()
    if not hooked[container] then
        hooked[container] = true
        hooksecurefunc(container, 'Layout', function()
            -- Blizzard just supplied fresh native anchors. Never call its layout
            -- or data-refresh methods from an addon callback to restore them.
            for item in viewer.itemFramePool:EnumerateActive() do originals[item]=nil end
            rows:Apply(viewer, addon.Cooldowns:GetEntries(viewer))
        end)
    end
    local db = addon.Buffs:GetDB()
    if not db.centerIcons or db.compact or viewer:IsEditing() then
        for item in viewer.itemFramePool:EnumerateActive() do Restore(item) end
        return
    end
    local horizontal = not viewer.IsHorizontal or viewer:IsHorizontal()
    local stride = viewer.GetStride and viewer:GetStride() or #entries
    stride = math.max(1, stride or #entries)
    local groups = {}
    for _, entry in ipairs(entries) do
        local item = entry.item
        if Movable(item) and not originals[item] then originals[item]=Capture(item, viewer) end
        local alpha = item:GetEffectiveAlpha()
        if originals[item] and item:IsShown() and Readable(alpha) and alpha > 0
            and addon.Cooldowns:ShouldDisplayItem(item) then
            local index = math.floor(((entry.order or 0)-1)/stride)
            groups[index] = groups[index] or {}
            groups[index][#groups[index]+1] = item
        end
    end
    local padding = ((viewer.iconPadding or 0)
        + (viewer.GetAdditionalPaddingOffset and viewer:GetAdditionalPaddingOffset() or -4)) * viewer:GetEffectiveScale()
    for _, group in pairs(groups) do
        local width = math.max(0,#group-1)*padding
        for _, item in ipairs(group) do
            width = width + (horizontal and item:GetWidth() or item:GetHeight()) * item:GetEffectiveScale()
        end
        local first, last = originals[group[1]], originals[group[#group]]
        local axis = horizontal and 'x' or 'y'
        local direction = last[axis] < first[axis] and -1 or 1
        local cursor = -width/2
        for _, item in ipairs(group) do
            local scale = item:GetEffectiveScale()
            local size = (horizontal and item:GetWidth() or item:GetHeight()) * scale
            local center = direction*(cursor+size/2)
            if Movable(item) then
                local state = originals[item]
                item:ClearAllPoints()
                item:SetPoint('CENTER',viewer,'CENTER',(horizontal and center or state.x)/scale,
                    (horizontal and state.y or center)/scale)
            end
            cursor = cursor + size + padding
        end
    end
end
