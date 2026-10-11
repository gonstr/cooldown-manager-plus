local _, addon = ...
local settings = {}
addon.Settings = settings

local defaults = {profile = {
    centerIcons=false, separateBuffs=false, classAuraStyle=false,
    compact=false, iconZoom=false, swingSparks=false,
    essentialOnlyCombat=false, utilityOnlyCombat=false,
    notifyMissingSelfBuffs=false, replaceCooldownTimers=false,
    hideDuplicateBuffs=false, effects={}, spellOverrides={},
}}
settings.defaults = defaults.profile

function settings:GetDB()
    if self.database and self.database.sv == CooldownManagerPlusDB then
        return self.database.profile
    end
    local saved = CooldownManagerPlusDB
    if type(saved) ~= 'table' or type(saved.profiles) ~= 'table' then
        CooldownManagerPlusDB = {}
    end
    self.database = LibStub('AceDB-3.0'):New('CooldownManagerPlusDB', defaults)
    local _, class = UnitClass('player')
    self.database.profile.characterClass = class
    return self.database.profile
end

function settings:GetCharacters()
    self:GetDB()
    local current = self.database:GetCurrentProfile()
    local characters = {}
    for _, name in ipairs(self.database:GetProfiles()) do
        if name ~= current then characters[#characters + 1] = name end
    end
    table.sort(characters)
    return characters
end

function settings:CanCopyOverrides(name)
    local current = self:GetDB()
    local source = self.database.profiles[name]
    return source and source.characterClass ~= nil and source.characterClass == current.characterClass
end

function settings:CopyCharacter(name)
    if InCombatLockdown and InCombatLockdown() then return false, 'Leave combat before copying settings.' end
    self:GetDB()
    if name == self.database:GetCurrentProfile() or not self.database.profiles[name] then
        return false, 'Choose another saved character.'
    end
    local compatible = self:CanCopyOverrides(name)
    local _, class = UnitClass('player')
    self.database:CopyProfile(name)
    local profile = self.database.profile
    profile.characterClass = class
    for _, field in ipairs({'effects', 'spellOverrides'}) do
        for id in pairs(profile[field]) do
            local info = compatible and C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
                and C_CooldownViewer.GetCooldownViewerCooldownInfo(id)
            if not info then profile[field][id] = nil end
        end
    end
    self:Apply()
    return true
end

function settings:Apply()
    local profile = self:GetDB()
    if addon.IconStyle then addon.IconStyle:QueueUpdate() end
    if addon.Compact then addon.Compact:SetSparksEnabled(profile.swingSparks) end
    if addon.Cooldowns then addon.Cooldowns:QueueUpdate() end
    if addon.Buffs then addon.Buffs:Refresh() end
    if addon.TimerLayer then addon.TimerLayer:Refresh() end
end

function settings:Reset()
    if InCombatLockdown and InCombatLockdown() then return false, 'Leave combat before resetting settings.' end
    self:GetDB()
    self.database:ResetProfile()
    local _, class = UnitClass('player')
    self.database.profile.characterClass = class
    self:Apply()
    return true
end

function settings:Replace(values)
    self:GetDB()
    self.database:ResetProfile()
    local profile = self.database.profile
    for key, value in pairs(values) do profile[key] = value end
    local _, class = UnitClass('player')
    profile.characterClass = class
end
