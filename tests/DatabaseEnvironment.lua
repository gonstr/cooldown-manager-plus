-- Minimal WoW APIs needed by the real embedded AceDB, not a database mock.
return function(name, realm)
    UnitName = function() return name end
    GetRealmName = function() return realm end
    UnitClass = function() return 'Hunter', 'HUNTER' end
    UnitRace = function() return 'Orc', 'Orc' end
    UnitFactionGroup = function() return 'Horde' end
    GetLocale = function() return 'enUS' end
    GetCurrentRegion = function() return 3 end
    GetCurrentRegionName = function() return 'EU' end
    securecallfunction = function(callback, ...) return callback(...) end
    local originalFrame = CreateFrame
    CreateFrame = function() return {RegisterEvent=function() end, SetScript=function() end} end
    LibStub = nil
    dofile('Libs/LibStub/LibStub.lua')
    dofile('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua')
    dofile('Libs/AceDB-3.0/AceDB-3.0.lua')
    CreateFrame = originalFrame
    local addon = {}
    local file = io.open('Core/Settings.lua')
    assert(file, 'settings storage module must exist')
    file:close()
    assert(loadfile('Core/Settings.lua'))('CooldownManagerPlus', addon)
    return addon.Settings
end
