local addon, db, combat = {}, {centerIcons=true}, false
local secret={}
issecretvalue=function(v) return v==secret end
InCombatLockdown=function() return combat end
hooksecurefunc=function(object,name,fn)
    local original=object[name]
    object[name]=function(self,...) original(self,...); fn(self,...) end
end
local function viewer(count,stride)
    local v={items={},iconPadding=10,stride=stride or count}
    function v:GetCenter() return 100,100 end
    function v:GetEffectiveScale() return 1 end
    function v:GetItemContainerFrame() return self end
    function v:IsEditing() return self.editing end
    function v:IsHorizontal() return not self.vertical end
    function v:GetStride() return self.stride end
    function v:GetAdditionalPaddingOffset() return -4 end
    for i=1,count do
        local item={shown=true,alpha=1,layoutIndex=i,point={'CENTER',v,'CENTER',(i-1)%v.stride*46-23, -math.floor((i-1)/v.stride)*46}}
        function item:GetCenter() return 100+self.point[4],100+self.point[5] end
        function item:GetEffectiveScale() return 1 end
        function item:GetNumPoints() return 1 end
        function item:GetPoint() return table.unpack(self.point) end
        function item:ClearAllPoints() end
        function item:SetPoint(...) self.point={...} end
        function item:IsShown() return self.shown end
        function item:GetEffectiveAlpha() return self.alpha end
        function item:IsProtected() return self.protected end
        function item:GetWidth() return 40 end
        function item:GetHeight() return 40 end
        v.items[i]=item
    end
    function v:Layout()
        for i,item in ipairs(self.items) do item.point={'CENTER',self,'CENTER',(i-1)%self.stride*46-23,-math.floor((i-1)/self.stride)*46} end
    end
    v.itemFramePool={EnumerateActive=function()
        local i=0
        return function() i=i+1; return v.items[i] end
    end}
    return v
end
addon.Buffs={GetDB=function() return db end}
addon.Cooldowns={ShouldDisplayItem=function(_,item) return not item.filtered end,
    GetEntries=function(_,v)
        local entries={}
        for i,item in ipairs(v.items) do entries[i]={item=item,order=i} end
        return entries
    end}
assert(loadfile('CenteredRows.lua'))('CooldownManagerPlus',addon)
local essential,utility=viewer(4,2),viewer(2)
local function apply(v) addon.CenteredRows:Apply(v,addon.Cooldowns:GetEntries(v)) end
apply(essential); apply(utility)
essential.items[2].shown=false; utility.items[2].filtered=true
apply(essential); apply(utility)
assert(essential.items[1].point[4]==0 and utility.items[1].point[4]==0, 'Essential and Utility center independently without hidden slots')
assert(essential.items[3].point[4]==-23 and essential.items[3].point[5]==-46, 'native second row keeps its vertical position')
essential.items[2].shown=true
apply(essential)
assert(essential.items[1].point[4]==-23 and essential.items[2].point[4]==23, 'row grows equally outward')
db.centerIcons=false
apply(essential); apply(utility)
assert(utility.items[1].point[4]==-23 and utility.items[2].point[4]==23, 'disabling restores original native anchors including hidden icons')
db.centerIcons=true; utility.items[2].filtered=false; utility.items[2].alpha=secret
apply(utility)
assert(utility.items[1].point[4]==0, 'secret alpha is never compared')
utility.editing=true; apply(utility)
assert(utility.items[1].point[4]==-23, 'Edit Mode restores native anchors')
utility.editing=false; utility.items[2].alpha=0; utility:Layout()
assert(utility.items[1].point[4]==0, 'native relayout refreshes snapshots and reapplies centering')
db.centerIcons=false; apply(utility)
assert(utility.items[1].point[4]==-23, 'fresh native snapshots restore after relayout')
combat=true; utility.items[1].protected=true; db.centerIcons=true
apply(utility)
assert(utility.items[1].point[4]==-23, 'protected icons are not moved during combat')
print('PASS: independent Essential/Utility row centering, growth, filtering, multirow layout, restoration and combat safety')
