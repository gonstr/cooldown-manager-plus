local _, addon = ...
local adapter = {}
addon.NativeSettingsTransfer = adapter

local function Context()
    local settings = CooldownViewerSettings
    if not settings or not settings.GetLayoutManager or not CooldownViewerUtil
        or not CooldownViewerUtil.GetCurrentClassAndSpecTag or not C_CooldownViewer
        or not C_CooldownViewer.GetLayoutData or not C_CooldownViewer.SetLayoutData
        or not CooldownManagerLayout_GetID or not CooldownManagerLayout_GetName then
        return nil
    end
    return settings:GetLayoutManager()
end
local function Busy()
    return InCombatLockdown and InCombatLockdown()
end

function adapter:Export()
    local ok, result = pcall(function()
        local manager = assert(Context())
        local tag = assert(CooldownViewerUtil.GetCurrentClassAndSpecTag())
        local layout = manager:GetActiveLayout(Enum.CDMLayoutMode.AccessOnly)
        return {specTag=tag, specText=CooldownViewerUtil.GetClassAndSpecTagText(tag),
            layoutName=layout and CooldownManagerLayout_GetName(layout) or 'Starter Layout',
            blizzard=layout and manager:GetSerializer():SerializeLayouts(CooldownManagerLayout_GetID(layout)) or ''}
    end)
    if not ok then return nil, 'Layout export is unavailable in this build.' end
    return result
end

function adapter:Prepare(payload)
    if Busy() then return nil, 'Leave combat before importing settings.' end
    local ok, result, message = pcall(function()
        local live = assert(Context())
        if live:HasPendingChanges() then return nil, 'Close and reopen Cooldown Manager to save its current changes first.' end
        if payload.specTag~=CooldownViewerUtil.GetCurrentClassAndSpecTag() then
            return nil, 'Switch to the matching class and specialization before importing.'
        end
        assert(CooldownViewerLayoutManagerMixin and CooldownViewerDataStoreSerializationMixin)
        -- Never deserialize into the live manager: its writes and notifications
        -- can taint Blizzard's item data. Only these new objects are modified.
        local manager = CreateFromMixins(CooldownViewerLayoutManagerMixin)
        manager.SetHasPendingChanges = function(self, pending) self.hasPendingChanges=pending end
        manager.NotifyListeners = function() end
        local serializer = CreateFromMixins(CooldownViewerDataStoreSerializationMixin)
        manager:Init({}, serializer)
        local saved = C_CooldownViewer.GetLayoutData()
        serializer:Init(manager, {
            GetSerializedData=function() return saved end,
            SetSerializedData=function(_, value) saved=value end,
            ClearSerializedData=function() saved='' end,
        })
        if payload.blizzard=='' then
            manager:UseDefaultLayout()
        else
            if manager:AreLayoutsFullyMaxed() then return nil, 'Delete a Blizzard layout before importing another.' end
            local ids = manager:CreateLayoutsFromSerializedData(payload.blizzard)
            if type(ids)~='table' or #ids~=1 then return nil, 'The string must contain one valid Blizzard layout.' end
            local layout = manager:GetLayout(ids[1])
            if not layout or CooldownManagerLayout_GetClassAndSpecTag(layout)~=payload.specTag
                or not manager:SetActiveLayout(layout) then
                return nil, 'The Blizzard layout is incompatible with this specialization.'
            end
        end
        return assert(serializer:SerializeLayouts())
    end)
    if not ok then return nil, 'Unable to read the Blizzard layout in these settings.' end
    return result, message
end

function adapter:Commit(data)
    if Busy() then return false, 'Leave combat before importing settings.' end
    local ok, result = pcall(function()
        local manager = assert(Context())
        if manager:HasPendingChanges() then return false end
        C_CooldownViewer.SetLayoutData(data)
        return C_CooldownViewer.GetLayoutData()==data
    end)
    if not ok or not result then return false, 'Unable to save the Blizzard layout. Settings were not imported.' end
    return true
end
