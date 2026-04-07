local DiffEngine = {}
DiffEngine.__index = DiffEngine

function DiffEngine.new()
	local self = setmetatable({}, DiffEngine)
	return self
end

function DiffEngine:compare(oldSnapshot, newSnapshot)
	local result = {
		added = {},
		removed = {},
		modified = {},
		summary = { added = 0, removed = 0, modified = 0 },
	}

	local oldData = oldSnapshot.data
	local newData = newSnapshot.data

	-- Detect removed and modified
	for path, oldEntry in pairs(oldData) do
		local newEntry = newData[path]
		if not newEntry then
			table.insert(result.removed, {
				path = path,
				className = oldEntry.className,
			})
			result.summary.removed = result.summary.removed + 1
		else
			-- Check for property changes
			local changes = {}
			for propName, oldValue in pairs(oldEntry.properties) do
				local newValue = newEntry.properties[propName]
				if newValue ~= oldValue then
					table.insert(changes, {
						name = propName,
						oldValue = oldValue,
						newValue = newValue or "(nil)",
					})
				end
			end
			-- Check for new properties
			for propName, newValue in pairs(newEntry.properties) do
				if oldEntry.properties[propName] == nil then
					table.insert(changes, {
						name = propName,
						oldValue = "(nil)",
						newValue = newValue,
					})
				end
			end

			if #changes > 0 then
				table.insert(result.modified, {
					path = path,
					className = newEntry.className,
					changes = changes,
				})
				result.summary.modified = result.summary.modified + 1
			end
		end
	end

	-- Detect added
	for path, newEntry in pairs(newData) do
		if not oldData[path] then
			table.insert(result.added, {
				path = path,
				className = newEntry.className,
			})
			result.summary.added = result.summary.added + 1
		end
	end

	-- Sort by path for consistent display
	table.sort(result.added, function(a, b) return a.path < b.path end)
	table.sort(result.removed, function(a, b) return a.path < b.path end)
	table.sort(result.modified, function(a, b) return a.path < b.path end)

	return result
end

function DiffEngine:hasChanges(result)
	return result.summary.added > 0
		or result.summary.removed > 0
		or result.summary.modified > 0
end

return DiffEngine
