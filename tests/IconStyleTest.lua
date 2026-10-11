local addon, db = {}, {}
addon.Buffs = {GetDB = function() return db end}
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
C_Timer = {After = function(_, callback) callback() end}
local chunk = loadfile('IconStyle.lua')
assert(chunk, 'icon styling must exist')
chunk('ForeverAddonTest', addon)
local mask = {GetObjectType = function() return 'MaskTexture' end,
    GetAtlas = function() return 'UI-HUD-CoolDownManager-Mask' end}
local border = {alpha = 0.7, GetObjectType = function() return 'Texture' end,
    GetAtlas = function() return 'UI-HUD-CoolDownManager-IconOverlay' end}
function border:GetAlpha() return self.alpha end
function border:SetAlpha(value) self.alpha = value end
local icon = {coords = {0.02, 0.98, 0.03, 0.97}, masks = {[mask] = true}}
function icon:GetTexCoord() return table.unpack(self.coords) end
function icon:SetTexCoord(...) self.coords = {...} end
function icon:RemoveMaskTexture(value) self.masks[value] = nil end
function icon:AddMaskTexture(value) self.masks[value] = true end
local item = {Icon = icon, GetRegions = function() return mask, border end}
local edges = {}
function item:CreateTexture()
    local edge = {points = {}}
    function edge:SetColorTexture(...) self.color = {...} end
    function edge:SetPoint(...) self.points[#self.points + 1] = {...} end
    function edge:SetHeight(value) self.height = value end
    function edge:SetWidth(value) self.width = value end
    function edge:SetShown(value) self.shown = value end
    edges[#edges + 1] = edge
    return edge
end
addon.IconStyle:ApplyItem(item, true)
assert(icon.coords[1] == 0.15 and icon.coords[2] == 0.85 and icon.coords[3] == 0.15 and icon.coords[4] == 0.85)
assert(not icon.masks[mask] and border.alpha == 0, 'zoom removes native mask and decorative border')
assert(#edges == 4, 'zoom adds four black border edges')
for _, edge in ipairs(edges) do
    assert(edge.shown and edge.color[1] == 0 and edge.color[4] == 1)
    assert(edge.height == 1 or edge.width == 1, 'border is one unit thick')
    assert(#edge.points == 2 and edge.points[1][2] == icon, 'border follows icon bounds')
end
addon.IconStyle:ApplyItem(item, true)
assert(#edges == 4, 'repeated enable reuses border textures')
addon.IconStyle:ApplyItem(item, false)
for _, edge in ipairs(edges) do assert(not edge.shown, 'zoom border hides when disabled') end
assert(icon.coords[1] == 0.02 and icon.coords[3] == 0.03, 'original crop must be restored')
assert(icon.masks[mask] and border.alpha == 0.7, 'original mask and border opacity must be restored')
print('PASS: 30% crop, thin black border, repeated enable, exact restoration')
