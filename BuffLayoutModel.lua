local _, addon = ...
local model = {}
addon.BuffLayoutModel = model

function model.GetAppearance(active, nativeShown, alwaysShow)
    return nativeShown or alwaysShow, alwaysShow and not active
end

function model.SplitRow(entries, size, spacing, gap)
    local ordered, positions = {}, {}
    for _, group in ipairs({'self', 'target'}) do
        for _, entry in ipairs(entries) do
            if entry.group == group then ordered[#ordered + 1] = entry end
        end
    end
    local split
    for i = 2, #ordered do
        if ordered[i].group ~= ordered[i - 1].group then split = i end
    end
    local width = #ordered * size + math.max(0, #ordered - 1) * spacing
    if split then width = width + gap end
    for i = 1, #ordered do
        positions[i] = -width / 2 + size / 2 + (i - 1) * (size + spacing)
            + (split and i >= split and gap or 0)
    end
    return ordered, positions, split
end


function model.MissingReminders(entries, enabled)
    local names = {}
    for _, entry in ipairs(entries) do
        local notify = addon.Overrides.Resolve(entry.options, 'notifyMissingSelfBuffs', enabled)
        if notify and entry.reminderEligible and entry.knownSelf and entry.readableActive and not entry.active then
            names[#names + 1] = entry.name
        end
    end
    if #names == 0 then return "" end
    if #names == 1 then return names[1] .. " is missing!" end
    if #names == 2 then return names[1] .. " and " .. names[2] .. " are missing!" end
    local last = table.remove(names)
    return table.concat(names, ", ") .. ", and " .. last .. " are missing!"
end
