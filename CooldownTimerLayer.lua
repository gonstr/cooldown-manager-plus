local _, addon = ...
local controller = {}
addon.TimerLayer = controller
local layers = setmetatable({}, {__mode = 'k'})
local ticker
local frame = CreateFrame('Frame')
local function Readable(value)
    return not (issecretvalue and issecretvalue(value))
end
local function Restore(state)
    state.active = false
    state.overlay:Hide()
    if state.alpha ~= nil then
        state.native:SetAlpha(state.alpha)
        state.alpha = nil
    end
end
local function GetSupportedSpell(item)
    local info = item:GetCooldownInfo()
    if not info or not Readable(info.charges) or info.charges
        or not Readable(info.equipSlot) or info.equipSlot
        or not Readable(info.spellCategoryID) or info.spellCategoryID then return end
    local spellID = info.overrideSpellID
    if not Readable(spellID) then return end
    spellID = spellID or info.spellID
    if Readable(spellID) and type(spellID) == 'number' then return spellID end
end

function controller:IsEnabledFor(item)
    local id = item:GetCooldownID()
    if not Readable(id) or type(id) ~= 'number' or not GetSupportedSpell(item) then return false end
    local db = addon.Buffs:GetDB()
    return addon.Overrides.Resolve(addon.Overrides.Get(db, 'spell', id), 'replaceCooldownTimers', db.replaceCooldownTimers)
end

function controller:SupportsItem(item)
    return item ~= nil and C_Spell.GetSpellCooldownDuration ~= nil and GetSupportedSpell(item) ~= nil
end

function controller:IsReplacing(item)
    return layers[item] and layers[item].active == true or false
end
local function NewLayer(item)
    local native = item.Cooldown
    if not native or InCombatLockdown() then return end
    local overlay = CreateFrame('Cooldown', nil, item, 'CooldownFrameTemplate')
    overlay:SetAllPoints(native)
    overlay:SetFrameLevel(native:GetFrameLevel() + 1)
    overlay:SetDrawBling(false)
    overlay:SetDrawEdge(false)
    overlay:SetDrawSwipe(true)
    -- Match the native viewer's icon-shaped swipe; the template default is circular.
    overlay:SetSwipeTexture('Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe')
    overlay:SetSwipeColor(0, 0, 0, 0.7)
    overlay:EnableMouse(false)
    overlay:Hide()
    local state = {native = native, overlay = overlay}
    layers[item] = state
    return state
end
function controller:Apply()
    local seen = {}
    for _, viewer in pairs({EssentialCooldownViewer, UtilityCooldownViewer}) do
            if viewer.itemFramePool then
                for item in viewer.itemFramePool:EnumerateActive() do
                    local state = layers[item]
                    local spellID = GetSupportedSpell(item)
                    -- First experiment covers ordinary spell cooldowns only.
                    -- Keep native item/category/charge displays until separately validated.
                    if self:IsEnabledFor(item) and spellID
                        and not viewer:IsEditing() then
                        state = state or NewLayer(item)
                        if state then
                            local duration = C_Spell.GetSpellCooldownDuration(spellID, true)
                            state.overlay:SetHideCountdownNumbers(state.native:GetHideCountdownNumbers())
                            if duration then
                                state.overlay:SetCooldownFromDurationObject(duration)
                            else
                                state.overlay:Clear()
                            end
                            -- Opacity hides only the visual timer. Native updates and
                            -- OnCooldownDone continue with their original methods intact.
                            if state.alpha == nil then state.alpha = state.native:GetAlpha() end
                            state.overlay:SetAlpha(state.alpha)
                            state.native:SetAlpha(0)
                            state.overlay:Show()
                            state.active = true
                            seen[item] = true
                        end
                    end
                end
            end
        end
    for item, state in pairs(layers) do
        if not seen[item] then Restore(state) end
    end
    if addon.Buffs.QueueUpdate then addon.Buffs:QueueUpdate() end
end
local function SafeApply()
    local ok, err = pcall(controller.Apply, controller)
    if not ok then
        addon.Buffs:GetDB().replaceCooldownTimers = false
        for _, options in pairs(addon.Buffs:GetDB().spellOverrides or {}) do
            options.replaceCooldownTimers = nil
        end
        if ticker then ticker:Cancel(); ticker = nil end
        for _, state in pairs(layers) do Restore(state) end
        print('CooldownManagerPlus: experimental timer replacement stopped: ' .. tostring(err))
    end
end
function controller:SetEnabled(enabled)
    if enabled and not C_Spell.GetSpellCooldownDuration then
        print('CooldownManagerPlus: cooldown duration API unavailable in this build.')
        return
    end
    addon.Buffs:GetDB().replaceCooldownTimers = enabled == true
    self:Refresh()
end

function controller:SetOverride(id, enabled)
    if enabled and not C_Spell.GetSpellCooldownDuration then return end
    addon.Overrides.Set(addon.Buffs:GetDB(), 'spell', id, 'replaceCooldownTimers', enabled)
    self:Refresh()
end

function controller:Refresh()
    if ticker then ticker:Cancel(); ticker = nil end
    SafeApply()
    local db = addon.Buffs:GetDB()
    local enabled = db.replaceCooldownTimers == true
    for _, options in pairs(db.spellOverrides or {}) do
        enabled = enabled or options.replaceCooldownTimers == true
    end
    if enabled then
        ticker = C_Timer.NewTicker(0.1, SafeApply)
    end
end
frame:RegisterEvent('PLAYER_LOGIN')
frame:RegisterEvent('PLAYER_REGEN_ENABLED')
frame:SetScript('OnEvent', function()
    controller:SetEnabled(addon.Buffs:GetDB().replaceCooldownTimers == true)
end)
