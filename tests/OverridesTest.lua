local addon = {}
assert(loadfile('Overrides.lua'))('CooldownManagerPlus', addon)
local overrides = addon.Overrides
assert(overrides.Resolve({}, 'combatOnly', true), 'unset inherits enabled global')
assert(not overrides.Resolve({combatOnly=false}, 'combatOnly', true), 'explicit false overrides global')
assert(overrides.Resolve({combatOnly=true}, 'combatOnly', false), 'explicit true overrides global')
local db = {effects={[1]={alwaysShow=true}}}
overrides.Set(db, 'buff', 1, 'notifyMissingSelfBuffs', false)
assert(db.effects[1].alwaysShow and not db.effects[1].notifyMissingSelfBuffs, 'preserve existing always-show option')
overrides.Set(db, 'spell', 1, 'combatOnly', true)
assert(not db.effects[1].combatOnly and db.spellOverrides[1].combatOnly, 'spell and buff options stay separate')
overrides.Set(db, 'spell', 1, 'combatOnly', nil)
assert(overrides.Count('spell', overrides.Get(db, 'spell', 1)) == 0, 'Follow global removes override')
assert(overrides.Count('buff', db.effects[1]) == 2, 'explicit false counts as an override')
overrides.Reset(db, 'buff', 1)
assert(overrides.Count('buff', overrides.Get(db, 'buff', 1)) == 0, 'reset clears every override for entry')
print('PASS: override inheritance, scope separation, counts, reset and existing selections')
