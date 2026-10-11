local addon = {}
assert(loadfile('Overrides.lua'))('ForeverAddonTest', addon)
local chunk = loadfile('BuffLayoutModel.lua')
assert(chunk, 'buff layout model must exist')
chunk('ForeverAddonTest', addon)
local model = addon.BuffLayoutModel

local shown, gray = model.GetAppearance(false, false, true)
assert(shown and gray, 'always-show missing effect is visible and gray')
shown, gray = model.GetAppearance(true, true, true)
assert(shown and not gray, 'applied effect regains color')
shown, gray = model.GetAppearance(false, false, false)
assert(not shown and not gray, 'native hidden effects remain hidden')
shown, gray = model.GetAppearance(false, true, false)
assert(shown and not gray, 'native always-visible appearance is unchanged without override')

local selfEntry, targetEntry = {group = 'self'}, {group = 'target'}
local ordered, positions, split = model.SplitRow({targetEntry, selfEntry}, 40, 0, 16)
assert(ordered[1] == selfEntry and ordered[2] == targetEntry and split == 2)
assert(positions[1] == -28 and positions[2] == 28, 'centered groups have a 16-unit gap')
local _, singlePositions, singleSplit = model.SplitRow({targetEntry}, 40, 0, 16)
assert(singlePositions[1] == 0 and singleSplit == nil, 'one group has no unnecessary gap')
print('PASS: missing-buff appearance, native defaults, centered self/target grouping')

local entries = {
    {name='Aspect buff', reminderEligible=true, knownSelf=true, readableActive=true, active=false},
    {name='Target effect', reminderEligible=true, knownSelf=false, readableActive=true, active=false},
    {name='Secret buff', reminderEligible=true, knownSelf=true, readableActive=false, active=false},
    {name='Active buff', reminderEligible=true, knownSelf=true, readableActive=true, active=true},
}
assert(addon.BuffLayoutModel.MissingReminders(entries, true) == 'Aspect buff is missing!', 'only confirmed missing self buffs produce reminders')

entries[2].knownSelf = true
assert(addon.BuffLayoutModel.MissingReminders(entries, true) == 'Aspect buff and Target effect are missing!', 'two missing buffs form one message')
entries[3].readableActive = true
assert(addon.BuffLayoutModel.MissingReminders(entries, true) == 'Aspect buff, Target effect, and Secret buff are missing!', 'three missing buffs form a comma-separated message')
assert(addon.BuffLayoutModel.MissingReminders({}, true) == '', 'no missing buffs produce no message')

assert(addon.BuffLayoutModel.MissingReminders(entries, false) == '', 'global notification checkbox disables reminders')
entries[1].reminderEligible=false
assert(not addon.BuffLayoutModel.MissingReminders(entries, true):find('Aspect buff', 1, true), 'ineligible buffs never produce reminders')

entries = {{name='Aspect',reminderEligible=true,knownSelf=true,readableActive=true,active=false,options={notifyMissingSelfBuffs=false}}}
assert(model.MissingReminders(entries, true) == '', 'per-buff exclusion overrides enabled global reminder')
entries[1].options.notifyMissingSelfBuffs = true
assert(model.MissingReminders(entries, false) == 'Aspect is missing!', 'per-buff inclusion overrides disabled global reminder')
entries[1].reminderEligible = false
assert(model.MissingReminders(entries, false) == '', 'override cannot bypass reminder eligibility')
