local _, addon = ...
local model = {}
addon.CompactModel = model

function model.SwingProgress(start, duration, now)
    if duration <= 0 or now >= start + duration then return nil end
    return math.max(0, (now - start) / duration)
end

function model.RowPositions(count, size, spacing)
    local width = math.max(0, count * size + math.max(0, count - 1) * spacing)
    local positions = {}
    for i = 1, count do
        positions[i] = -width / 2 + size / 2 + (i - 1) * (size + spacing)
    end
    return positions, width
end

function model.Geometry(essentialCount, utilityCount, size, spacing, buffGap, utilitySize, buffSize)
    utilitySize = utilitySize or size
    buffSize = buffSize or size
    local essentials, width = model.RowPositions(essentialCount, size, spacing)
    local utility = model.RowPositions(utilityCount, utilitySize, spacing)
    return {
        essentialX = essentials, utilityX = utility,
        essentialY = 0, utilityY = -(size + utilitySize) / 2 - spacing,
        buffY = (size + buffSize) / 2 + buffGap, sparkY = size / 2,
        sparkWidth = width,
    }
end
