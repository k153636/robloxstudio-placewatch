local Config = require(script.Parent.Config)

local Snapshot = {}
Snapshot.__index = Snapshot

function Snapshot.new()
	local self = setmetatable({}, Snapshot)
	self.data = {}
	self.timestamp = os.time()
	self.instanceCount = 0
	return self
end

local function getFullPath(instance)
	local parts = {}
	local current = instance
	while current and current ~= game do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local function getProperties(instance)
	local props = {}
	props["Name"] = instance.Name
	props["ClassName"] = instance.ClassName

	for className, propList in pairs(Config.PROPERTY_MAP) do
		if instance:IsA(className) then
			for _, propName in ipairs(propList) do
				local ok, value = pcall(function()
					return instance[propName]
				end)
				if ok and value ~= nil then
					if typeof(value) == "Vector3" then
						props[propName] = string.format("%.2f, %.2f, %.2f", value.X, value.Y, value.Z)
					elseif typeof(value) == "Color3" then
						props[propName] = string.format("%.2f, %.2f, %.2f", value.R, value.G, value.B)
					elseif typeof(value) == "UDim2" then
						props[propName] = tostring(value)
					elseif typeof(value) == "EnumItem" then
						props[propName] = tostring(value)
					elseif typeof(value) == "Instance" then
						props[propName] = value:GetFullName()
					else
						props[propName] = tostring(value)
					end
				end
			end
		end
	end

	return props
end

local function shouldIgnore(instance)
	for _, className in ipairs(Config.IGNORE_CLASSES) do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

function Snapshot:captureInstance(instance, depth)
	if depth > Config.MAX_DEPTH then return end
	if shouldIgnore(instance) then return end

	local path = getFullPath(instance)
	local props = getProperties(instance)

	self.data[path] = {
		className = instance.ClassName,
		properties = props,
		path = path,
		childCount = #instance:GetChildren(),
	}
	self.instanceCount = self.instanceCount + 1

	for _, child in ipairs(instance:GetChildren()) do
		self:captureInstance(child, depth + 1)
	end
end

function Snapshot:capture()
	self.data = {}
	self.instanceCount = 0
	self.timestamp = os.time()

	for _, serviceName in ipairs(Config.SCAN_SERVICES) do
		local ok, service = pcall(function()
			return game:GetService(serviceName)
		end)
		if ok and service then
			self:captureInstance(service, 0)
		end
	end

	return self
end

function Snapshot:serialize()
	return {
		data = self.data,
		timestamp = self.timestamp,
		instanceCount = self.instanceCount,
	}
end

function Snapshot.deserialize(saved)
	local self = setmetatable({}, Snapshot)
	self.data = saved.data or {}
	self.timestamp = saved.timestamp or 0
	self.instanceCount = saved.instanceCount or 0
	return self
end

return Snapshot
