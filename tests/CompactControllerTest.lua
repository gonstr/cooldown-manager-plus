local addon, timers, frames = {}, {}, {}
unpack = table.unpack
local now = 10
local inPlayerCombat = true
UnitAffectingCombat = function() return inPlayerCombat end
local function widget()
    local f = {shown = true, scale = 1, width = 40, height = 40, alpha = 1, scripts = {}}
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:GetLeft() error('screen coordinates are secret in combat') end
    function f:SetClipsChildren(v) self.clipped = v end
    function f:SetColorTexture(...) self.color = {...} end
    function f:GetTop() return self.height / 2 end
    function f:SetAllPoints() end
    function f:SetStatusBarTexture() end
    function f:SetStatusBarColor() end
    function f:SetMinMaxValues() end
    function f:SetValue(value) self.value = value end
    function f:ClearAllPoints() self.point = nil end
    function f:SetPoint(...) self.point = {...} end
    function f:SetScale(s) self.scale = s end
    function f:GetScale() return self.scale end
    function f:GetEffectiveScale() return self.scale end
    function f:SetAlpha(a) self.alpha = a end
    function f:GetAlpha() return self.alpha end
    function f:SetFrameStrata(...) end
    function f:GetFrameStrata() return 'MEDIUM' end
    function f:SetFrameLevel(...) end
    function f:GetFrameLevel() return 1 end
    function f:IsShown() return self.shown end
    function f:SetShown(b) self.shown = b end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsProtected() return false end
    function f:SetTexture(value) self.texture = value end
    function f:SetBlendMode(...) end
    function f:SetTexCoord(...) self.coords = {...} end
    function f:SetVertexColor(...) self.color = {...} end
    function f:RegisterEvent(...) end
    function f:SetScript(name, handler) self.scripts[name] = handler end
    function f:HookScript(name, handler) self.scripts[name] = handler end
    function f:CreateTexture()
        local texture = widget()
        self.textures = self.textures or {}
        self.textures[#self.textures + 1] = texture
        return texture
    end
    return f
end
CreateFrame = function() local f = widget(); frames[#frames + 1] = f; return f end
UIParent = widget()
C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
C_SwingTimer = {}
GetTime = function() return now end
InCombatLockdown = function() return false end
hooksecurefunc = function(object, name, callback)
    local original = object[name]
    object[name] = function(self, ...) original(self, ...); callback(self, ...) end
end
local function viewer(count)
    local f = widget()
    f.iconScale = 1
    f.items = {}
    for i = 1, count do
        local icon = widget()
        icon.layoutIndex = i
        function icon:GetViewerFrame() return f end
        f.items[i] = icon
    end
    f.itemFramePool = {EnumerateActive = function()
        local i = 0
        return function() i = i + 1; return f.items[i] end
    end}
    function f:IsEditing() return self.editing end
    function f:SetIsEditing(b) self.editing = b end
    function f:GetItemContainerFrame() return self end
    function f:Layout() for i, icon in ipairs(self.items) do icon:SetPoint('NATIVE', i) end end
    function f:RefreshData() end
    return f
end
EssentialCooldownViewer, UtilityCooldownViewer, BuffIconCooldownViewer = viewer(3), viewer(5), viewer(2)
local db = {gap = 32, swingSparks = true}
addon.Buffs = {GetDB = function() return db end, Refresh = function() end,
    GetEntries = function() return {
        {key = 1, group = 'player', item = BuffIconCooldownViewer.items[1]},
        {key = 2, group = 'target', item = BuffIconCooldownViewer.items[2]},
    } end}
local nativeBar = widget()
nativeBar.alpha = 0.7
function nativeBar:SetIsInEditMode(b) self.isInEditMode = b end
SwingTimerManagerFrame = {swingTimerFrames = {nativeBar}}
assert(loadfile('Overrides.lua'))('ForeverAddonTest', addon)
assert(loadfile('BuffLayoutModel.lua'))('ForeverAddonTest', addon)
assert(loadfile('CompactModel.lua'))('ForeverAddonTest', addon)
assert(loadfile('CompactLayout.lua'))('RenamedAddon', addon)
local controller = addon.Compact
controller:SetEnabled(true)
local essential = EssentialCooldownViewer.items[1]
local utility = UtilityCooldownViewer.items[1]
assert(essential.scale == 1 and essential.point[5] == 0, 'compact must preserve native icon size')
assert(utility.point[5] == -36, 'row spacing compensates for native icon art padding')
assert(EssentialCooldownViewer.items[2].point[1] == 'LEFT' and EssentialCooldownViewer.items[2].point[2] == essential
    and EssentialCooldownViewer.items[2].point[3] == 'RIGHT' and EssentialCooldownViewer.items[2].point[4] == -4,
    'essential icons attach directly with native art-padding compensation')
assert(UtilityCooldownViewer.items[2].point[2] == utility and UtilityCooldownViewer.items[2].point[4] == -4,
    'utility icons attach directly instead of relying on scaled center distances')
assert(BuffIconCooldownViewer.items[2].point[2] == BuffIconCooldownViewer.items[1], 'buffs are one uninterrupted row')
local fixedEssentialX=essential.point[4]
EssentialCooldownViewer.items[2].shown=false; EssentialCooldownViewer.items[3].shown=false
for i=2,#UtilityCooldownViewer.items do UtilityCooldownViewer.items[i].shown=false end
controller:Apply()
assert(essential.point[4]==fixedEssentialX, 'compact fixed mode retains Essential slots')
db.centerIcons=true
controller:Apply()
assert(essential.point[4]==0 and utility.point[4]==0, 'compact centering applies to Essential and Utility rows too')
for _, item in ipairs(EssentialCooldownViewer.items) do item.shown=true end
for _, item in ipairs(UtilityCooldownViewer.items) do item.shown=true end
db.centerIcons=false; controller:Apply()
local fixedBuffX=BuffIconCooldownViewer.items[1].point[4]
BuffIconCooldownViewer.items[2].shown=false
controller:Apply()
assert(BuffIconCooldownViewer.items[1].point[4]==fixedBuffX, 'compact fixed mode reserves inactive buff slots')
db.centerIcons=true
controller:Apply()
assert(BuffIconCooldownViewer.items[1].point[4]==0, 'compact centered mode centers its single visible buff')
BuffIconCooldownViewer.items[2].shown=true
controller:Apply()
assert(BuffIconCooldownViewer.items[1].point[4]==fixedBuffX, 'compact centered row grows outward as a buff returns')
db.centerIcons=false
EssentialCooldownViewer.iconScale = 1.5
UtilityCooldownViewer.iconScale = 0.75
controller:Apply()
assert(essential.scale == 1.5 and utility.scale == 0.75, 'different native icon sizes are preserved')
assert(EssentialCooldownViewer.items[2].point[4] == -4 and UtilityCooldownViewer.items[2].point[4] == -4,
    'edge anchors compensate padding at non-default scales too')
EssentialCooldownViewer.iconScale, UtilityCooldownViewer.iconScale = 1, 1
controller:Apply()
assert(nativeBar.alpha == 0.7, 'integrated spark leaves default swing timers untouched')
local buffY, utilityY = BuffIconCooldownViewer.items[1].point[5], utility.point[5]
local essentialsHidden = true
addon.Cooldowns = {ShouldDisplayItem = function(_, item)
    return not (essentialsHidden and item:GetViewerFrame() == EssentialCooldownViewer)
end}
controller:Apply()
assert(BuffIconCooldownViewer.items[1].point[5] == buffY,
    'hiding essential cooldowns outside combat must preserve buff row height')
assert(utility.point[5] == utilityY, 'utility row must not move when essentials are hidden')
assert(not frames[3].shown, 'swing timer must not move onto utility icons when essentials are hidden')
assert(frames[3].point[5] == 20, 'hidden swing timer keeps essential-row anchoring')
essentialsHidden = false
controller:Apply()
assert(BuffIconCooldownViewer.items[1].point[5] == buffY and utility.point[5] == utilityY,
    'showing essential cooldowns in combat must preserve other row heights')
frames[1].scripts.OnEvent(frames[1], 'PLAYER_SWING', 2, 0)
frames[3].scripts.OnUpdate()
now = 13
frames[1].scripts.OnEvent(frames[1], 'PLAYER_SWING', 2, 2)
frames[3].scripts.OnUpdate()
local segments = {frames[4], frames[5], frames[6]}
assert(segments[3].point[4] == -3 and segments[1].point[5] == 0.5, 'rounded icons inset horizontal clipping without moving the spark off the border')
local highlight = segments[3].textures[1]
assert(highlight.shown and highlight.width <= 18 and highlight.height == 8, 'spark is a soft rounded highlight')
assert(#segments[1].textures == 2, 'spark has a small core and a separate halo; there is no bar')
assert(highlight.texture=='Interface\\AddOns\\RenamedAddon\\Media\\SwingHighlight', 'spark assets follow installed addon folder name')
local halo = segments[3].textures[2]
assert(halo.shown and halo.width <= 36 and halo.height == 18 and halo.texture:find('SwingHalo', 1, true), 'larger soft halo surrounds the original particle')
frames[1].scripts.OnEvent(frames[1], 'PLAYER_SWING', 1, 1)
now = 13.5
frames[3].scripts.OnUpdate()
assert(segments[3].textures[1].shown, 'off-hand does not replace the ranged timer')
db.iconZoom = true
controller:Apply()
now = 13 + 2 * (1 - 40 / 120)
frames[3].scripts.OnUpdate()
assert(segments[1].textures[1].shown and segments[2].textures[1].shown,
    'touching icons share both halves of the glow at the boundary')
assert(segments[1].textures[1].coords[2] <= 0.51 and segments[2].textures[1].coords[1] >= 0.49,
    'boundary halves retain complementary texture coordinates instead of stretching')
assert(segments[1].point[4] == 0 and segments[1].point[5] == 0, 'compact spark has no inset gap')
controller:SetEnabled(false)
EssentialCooldownViewer.iconPadding = 8
db.iconZoom = false
controller:Apply()
now = 13 + 2 * (1 - 39 / 123)
frames[3].scripts.OnUpdate()
assert(segments[1].textures[1].shown and segments[2].textures[1].shown,
    'normal style keeps the glow continuous across the space between icons')
assert(segments[1].point[4] == 2 and segments[2].point[4] == 2 and segments[3].point[4] == -3,
    'only the outer right end is inset; inner segments meet halfway across the gap')
EssentialCooldownViewer.iconPadding = 0
controller:SetEnabled(true)
now = 18
frames[3].scripts.OnUpdate()
assert(not segments[1].shown and not segments[2].shown and not segments[3].shown, 'expired swing hides every segment')
inPlayerCombat = false
frames[1].scripts.OnEvent(frames[1], 'PLAYER_REGEN_ENABLED')
assert(not frames[3].shown, 'timer hides outside combat')
frames[1].scripts.OnEvent(frames[1], 'PLAYER_SWING', 3, 0)
inPlayerCombat = true
controller:Apply()
frames[3].scripts.OnUpdate()
assert(not segments[1].shown, 'out-of-combat swing does not survive into combat')
frames[1].scripts.OnEvent(frames[1], 'PLAYER_SWING', 2, 0)
frames[3].scripts.OnUpdate()
assert(segments[3].textures[1].shown, 'new combat swing restores the spark')
EssentialCooldownViewer:SetIsEditing(true)
controller:Apply()
assert(nativeBar.alpha == 0.7 and essential.point[1] == 'NATIVE', 'Edit Mode restores original presentation')
EssentialCooldownViewer:SetIsEditing(false)
controller:Apply()
controller:SetEnabled(false)
assert(nativeBar.alpha == 0.7, 'default swing timers stay unchanged with spark enabled')
local savedEssentials = EssentialCooldownViewer.items
EssentialCooldownViewer.items = {savedEssentials[1], savedEssentials[2]}
assert(controller:GetSparkViewer() == UtilityCooldownViewer, 'fewer than three essentials falls back to qualifying utility row')
controller:Apply()
frames[1].scripts.OnEvent(frames[1], 'PLAYER_SWING', 2, 0)
frames[3].scripts.OnUpdate()
assert(frames[3].shown, 'utility fallback renders the spark')
local savedUtilities = UtilityCooldownViewer.items
UtilityCooldownViewer.items = {savedUtilities[1], savedUtilities[2]}
assert(controller:GetSparkViewer() == nil, 'two icons in each row do not meet the minimum')
controller:Apply()
assert(not frames[3].shown, 'no eligible row hides integrated spark')
EssentialCooldownViewer.items, UtilityCooldownViewer.items = {}, {}
controller:Apply()
assert(not frames[3].shown and nativeBar.alpha == 0.7, 'empty spell lists leave native timers available')
EssentialCooldownViewer.items, UtilityCooldownViewer.items = savedEssentials, savedUtilities
controller:SetSparksEnabled(false)
assert(db.swingSparks == false and db.swingStyle == nil, 'checkbox disables spark and clears legacy style')
assert(nativeBar.alpha == 0.7 and essential.scale == 1 and essential.point[1] == 'NATIVE')
assert(utility.scale == 1 and utility.point[1] == 'NATIVE')
assert(not frames[3].shown, 'spark edge must disappear when disabled')
print('PASS: compact placement/scaling, single buff row, native swing alpha restoration, Edit Mode, disable cleanup')
