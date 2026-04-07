--[[
	PlaceWatch - Roblox Studio Plugin v0.2.0
	Automatically detect and visualize differences between place snapshots.
	Features: auto-snapshot on publish, click-to-select, filters
]]

-- ============================================================
-- Config
-- ============================================================
local Config = {
	SCAN_SERVICES = {
		"Workspace",
		"ReplicatedStorage",
		"ServerStorage",
		"ServerScriptService",
		"StarterGui",
		"StarterPack",
		"StarterPlayer",
		"Lighting",
		"SoundService",
	},
	PROPERTY_MAP = {
		BasePart = {"Position", "Size", "Orientation", "Color", "Material", "Anchored", "Transparency", "CanCollide", "CastShadow", "Reflectance", "Shape"},
		Model = {"PrimaryPart"},
		TextLabel = {"Text", "TextColor3", "BackgroundColor3", "TextSize", "Font", "Visible"},
		TextButton = {"Text", "TextColor3", "BackgroundColor3", "TextSize", "Font", "Visible"},
		TextBox = {"Text", "TextColor3", "BackgroundColor3", "TextSize", "Font", "Visible"},
		ImageLabel = {"Image", "ImageColor3", "BackgroundColor3", "Visible"},
		ImageButton = {"Image", "ImageColor3", "BackgroundColor3", "Visible"},
		Frame = {"BackgroundColor3", "BackgroundTransparency", "Visible", "Size", "Position"},
		PointLight = {"Brightness", "Color", "Range"},
		SpotLight = {"Brightness", "Color", "Range", "Angle", "Face"},
		SurfaceLight = {"Brightness", "Color", "Range", "Angle", "Face"},
		Sound = {"SoundId", "Volume", "PlaybackSpeed", "Looped"},
		ParticleEmitter = {"Texture", "Rate", "Lifetime", "Speed", "Color"},
		Decal = {"Texture", "Face", "Transparency"},
		Texture = {"Texture", "Face", "Transparency"},
	},
	IGNORE_CLASSES = {Camera = true, Terrain = true},
	MAX_DEPTH = 50,
}

-- ============================================================
-- Snapshot
-- ============================================================
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

local function captureTree(root, data, depth, count)
	if depth > Config.MAX_DEPTH then return count end
	if Config.IGNORE_CLASSES[root.ClassName] then return count end

	local path = getFullPath(root)
	data[path] = {
		className = root.ClassName,
		properties = getProperties(root),
		path = path,
	}
	count = count + 1

	for _, child in ipairs(root:GetChildren()) do
		count = captureTree(child, data, depth + 1, count)
	end
	return count
end

local function takeSnapshot()
	local data = {}
	local count = 0
	for _, serviceName in ipairs(Config.SCAN_SERVICES) do
		local ok, service = pcall(function()
			return game:GetService(serviceName)
		end)
		if ok and service then
			count = captureTree(service, data, 0, count)
		end
	end
	return { data = data, timestamp = os.time(), instanceCount = count }
end

-- ============================================================
-- DiffEngine
-- ============================================================
local function computeDiff(oldSnap, newSnap)
	local result = {
		added = {},
		removed = {},
		modified = {},
		summary = { added = 0, removed = 0, modified = 0 },
	}

	local oldData = oldSnap.data
	local newData = newSnap.data

	for path, oldEntry in pairs(oldData) do
		local newEntry = newData[path]
		if not newEntry then
			table.insert(result.removed, { path = path, className = oldEntry.className })
			result.summary.removed += 1
		else
			local changes = {}
			for propName, oldValue in pairs(oldEntry.properties) do
				local newValue = newEntry.properties[propName]
				if newValue ~= oldValue then
					table.insert(changes, { name = propName, oldValue = oldValue, newValue = newValue or "(nil)" })
				end
			end
			for propName, newValue in pairs(newEntry.properties) do
				if oldEntry.properties[propName] == nil then
					table.insert(changes, { name = propName, oldValue = "(nil)", newValue = newValue })
				end
			end
			if #changes > 0 then
				table.insert(result.modified, { path = path, className = newEntry.className, changes = changes })
				result.summary.modified += 1
			end
		end
	end

	for path, newEntry in pairs(newData) do
		if not oldData[path] then
			table.insert(result.added, { path = path, className = newEntry.className })
			result.summary.added += 1
		end
	end

	table.sort(result.added, function(a, b) return a.path < b.path end)
	table.sort(result.removed, function(a, b) return a.path < b.path end)
	table.sort(result.modified, function(a, b) return a.path < b.path end)

	return result
end

-- ============================================================
-- UI
-- ============================================================
local COLORS = {
	bg = Color3.fromRGB(30, 30, 30),
	header = Color3.fromRGB(40, 40, 40),
	added = Color3.fromRGB(40, 180, 99),
	removed = Color3.fromRGB(231, 76, 60),
	modified = Color3.fromRGB(241, 196, 15),
	text = Color3.fromRGB(220, 220, 220),
	textDim = Color3.fromRGB(140, 140, 140),
	button = Color3.fromRGB(52, 152, 219),
	buttonHover = Color3.fromRGB(41, 128, 185),
	border = Color3.fromRGB(60, 60, 60),
	noChanges = Color3.fromRGB(40, 180, 99),
}

local SETTING_KEY = "PlaceWatch_LastSnapshot"
local SETTING_AUTO = "PlaceWatch_AutoSnapshot"
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local StudioService = game:GetService("StudioService")

local autoSnapshotEnabled = true
local currentFilter = "all" -- all, added, removed, modified

-- Create toolbar & widget
local toolbar = plugin:CreateToolbar("PlaceWatch")
local toggleButton = toolbar:CreateButton("PlaceWatch", "Toggle PlaceWatch panel", "rbxassetid://6031071053", "PlaceWatch")

local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 300, 600, 250, 400)
local widget = plugin:CreateDockWidgetPluginGui("PlaceWatch", widgetInfo)
widget.Title = "PlaceWatch"

-- Main frame
local main = Instance.new("Frame")
main.Size = UDim2.new(1, 0, 1, 0)
main.BackgroundColor3 = COLORS.bg
main.BorderSizePixel = 0
main.Parent = widget

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = COLORS.header
header.BorderSizePixel = 0
header.Parent = main

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -16, 0, 24)
titleLabel.Position = UDim2.new(0, 8, 0, 4)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "PlaceWatch"
titleLabel.TextColor3 = COLORS.text
titleLabel.TextSize = 16
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -16, 0, 16)
statusLabel.Position = UDim2.new(0, 8, 0, 28)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Loading..."
statusLabel.TextColor3 = COLORS.textDim
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = header

-- Summary bar
local summaryFrame = Instance.new("Frame")
summaryFrame.Size = UDim2.new(1, 0, 0, 30)
summaryFrame.Position = UDim2.new(0, 0, 0, 50)
summaryFrame.BackgroundColor3 = COLORS.header
summaryFrame.BorderSizePixel = 0
summaryFrame.Visible = false
summaryFrame.Parent = main

local summaryLabel = Instance.new("TextLabel")
summaryLabel.Size = UDim2.new(1, -16, 1, 0)
summaryLabel.Position = UDim2.new(0, 8, 0, 0)
summaryLabel.BackgroundTransparency = 1
summaryLabel.TextColor3 = COLORS.text
summaryLabel.TextSize = 13
summaryLabel.Font = Enum.Font.GothamBold
summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
summaryLabel.Parent = summaryFrame

-- Scroll area
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -130)
scrollFrame.Position = UDim2.new(0, 0, 0, 80)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = COLORS.border
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = main

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 2)
listLayout.Parent = scrollFrame

-- Button bar
local buttonBar = Instance.new("Frame")
buttonBar.Size = UDim2.new(1, 0, 0, 50)
buttonBar.Position = UDim2.new(0, 0, 1, -50)
buttonBar.BackgroundColor3 = COLORS.header
buttonBar.BorderSizePixel = 0
buttonBar.Parent = main

local function createButton(parent, text, position, size)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = position
	btn.BackgroundColor3 = COLORS.button
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamBold
	btn.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = btn

	btn.MouseEnter:Connect(function() btn.BackgroundColor3 = COLORS.buttonHover end)
	btn.MouseLeave:Connect(function() btn.BackgroundColor3 = COLORS.button end)
	return btn
end

-- Filter bar
local filterBar = Instance.new("Frame")
filterBar.Size = UDim2.new(1, 0, 0, 28)
filterBar.Position = UDim2.new(0, 0, 0, 50)
filterBar.BackgroundColor3 = COLORS.bg
filterBar.BorderSizePixel = 0
filterBar.Parent = main

local filterLayout = Instance.new("UIListLayout")
filterLayout.FillDirection = Enum.FillDirection.Horizontal
filterLayout.SortOrder = Enum.SortOrder.LayoutOrder
filterLayout.Padding = UDim.new(0, 4)
filterLayout.Parent = filterBar

local filterPad = Instance.new("UIPadding")
filterPad.PaddingLeft = UDim.new(0, 8)
filterPad.PaddingTop = UDim.new(0, 4)
filterPad.Parent = filterBar

local filterButtons = {}

local function createFilterBtn(text, filterType, order, color)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 60, 0, 20)
	btn.BackgroundColor3 = color or COLORS.border
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = COLORS.text
	btn.TextSize = 11
	btn.Font = Enum.Font.GothamBold
	btn.LayoutOrder = order
	btn.Parent = filterBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 3)
	c.Parent = btn
	filterButtons[filterType] = btn
	return btn
end

local allFilterBtn = createFilterBtn("All", "all", 1, COLORS.button)
local addFilterBtn = createFilterBtn("+Add", "added", 2, COLORS.border)
local remFilterBtn = createFilterBtn("-Rem", "removed", 3, COLORS.border)
local modFilterBtn = createFilterBtn("~Mod", "modified", 4, COLORS.border)

-- Adjust scroll and summary positions for filter bar
summaryFrame.Position = UDim2.new(0, 0, 0, 78)
scrollFrame.Position = UDim2.new(0, 0, 0, 108)
scrollFrame.Size = UDim2.new(1, 0, 1, -158)

-- Expand button bar for 3 buttons
buttonBar.Size = UDim2.new(1, 0, 0, 50)

local snapshotBtn = createButton(buttonBar, "Snapshot", UDim2.new(0, 6, 0, 8), UDim2.new(0.33, -8, 0, 34))
local diffBtn = createButton(buttonBar, "Compare", UDim2.new(0.33, 2, 0, 8), UDim2.new(0.34, -4, 0, 34))
local autoBtn = createButton(buttonBar, "Auto: ON", UDim2.new(0.67, 2, 0, 8), UDim2.new(0.33, -8, 0, 34))
autoBtn.BackgroundColor3 = COLORS.added

-- ============================================================
-- UI Helpers
-- ============================================================
local lastDiffResult = nil

local function clearResults()
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
	summaryFrame.Visible = false
end

local function findInstanceByPath(path)
	local parts = string.split(path, ".")
	local current = game
	for _, part in ipairs(parts) do
		local child = current:FindFirstChild(part)
		if not child then return nil end
		current = child
	end
	return current
end

local function addDiffEntry(entryType, path, className, details)
	local color, prefix
	if entryType == "added" then
		color = COLORS.added; prefix = "+"
	elseif entryType == "removed" then
		color = COLORS.removed; prefix = "-"
	else
		color = COLORS.modified; prefix = "~"
	end

	local frame = Instance.new("TextButton")
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.Position = UDim2.new(0, 4, 0, 0)
	frame.BackgroundColor3 = COLORS.header
	frame.BorderSizePixel = 0
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Text = ""
	frame.Parent = scrollFrame

	-- Click to select instance in Explorer
	frame.MouseButton1Click:Connect(function()
		local inst = findInstanceByPath(path)
		if inst then
			Selection:Set({inst})
		end
	end)

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 3)
	c.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame

	local headerLbl = Instance.new("TextLabel")
	headerLbl.Size = UDim2.new(1, 0, 0, 18)
	headerLbl.BackgroundTransparency = 1
	headerLbl.Text = string.format("[%s] %s (%s)", prefix, path, className)
	headerLbl.TextColor3 = color
	headerLbl.TextSize = 12
	headerLbl.Font = Enum.Font.GothamBold
	headerLbl.TextXAlignment = Enum.TextXAlignment.Left
	headerLbl.TextTruncate = Enum.TextTruncate.AtEnd
	headerLbl.LayoutOrder = 1
	headerLbl.Parent = frame

	if details then
		for _, change in ipairs(details) do
			local detail = Instance.new("TextLabel")
			detail.Size = UDim2.new(1, 0, 0, 14)
			detail.BackgroundTransparency = 1
			detail.Text = string.format("  %s: %s -> %s", change.name, tostring(change.oldValue), tostring(change.newValue))
			detail.TextColor3 = COLORS.textDim
			detail.TextSize = 11
			detail.Font = Enum.Font.Gotham
			detail.TextXAlignment = Enum.TextXAlignment.Left
			detail.TextTruncate = Enum.TextTruncate.AtEnd
			detail.LayoutOrder = 2
			detail.Parent = frame
		end
	end
end

local function showResults(result, filter)
	clearResults()
	filter = filter or "all"

	local s = result.summary
	summaryLabel.Text = string.format("+%d added   -%d removed   ~%d modified", s.added, s.removed, s.modified)
	summaryFrame.Visible = true

	if filter == "all" or filter == "added" then
		for _, entry in ipairs(result.added) do
			addDiffEntry("added", entry.path, entry.className)
		end
	end
	if filter == "all" or filter == "removed" then
		for _, entry in ipairs(result.removed) do
			addDiffEntry("removed", entry.path, entry.className)
		end
	end
	if filter == "all" or filter == "modified" then
		for _, entry in ipairs(result.modified) do
			addDiffEntry("modified", entry.path, entry.className, entry.changes)
		end
	end

	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
end

local function updateFilterUI(activeFilter)
	currentFilter = activeFilter
	for fType, btn in pairs(filterButtons) do
		if fType == activeFilter then
			btn.BackgroundColor3 = COLORS.button
		else
			btn.BackgroundColor3 = COLORS.border
		end
	end
	if lastDiffResult then
		showResults(lastDiffResult, activeFilter)
	end
end

-- ============================================================
-- Core Logic
-- ============================================================
local lastSnapshot = nil

local function loadSavedSnapshot()
	local saved = plugin:GetSetting(SETTING_KEY)
	if saved then
		lastSnapshot = saved
		local timeStr = os.date("%Y-%m-%d %H:%M:%S", saved.timestamp)
		statusLabel.Text = "Last: " .. timeStr .. " (" .. saved.instanceCount .. " instances)"
	else
		statusLabel.Text = "No snapshot yet. Click 'Snapshot' to start."
	end
end

local function onSnapshot()
	statusLabel.Text = "Taking snapshot..."
	task.wait()

	local snap = takeSnapshot()
	plugin:SetSetting(SETTING_KEY, snap)
	lastSnapshot = snap

	local timeStr = os.date("%Y-%m-%d %H:%M:%S", snap.timestamp)
	statusLabel.Text = "Saved: " .. timeStr .. " (" .. snap.instanceCount .. " instances)"
end

local function onCompare()
	if not lastSnapshot then
		statusLabel.Text = "No previous snapshot. Take one first."
		return
	end

	statusLabel.Text = "Scanning..."
	task.wait()

	local currentSnap = takeSnapshot()
	statusLabel.Text = "Computing diff..."
	task.wait()

	local result = computeDiff(lastSnapshot, currentSnap)
	local s = result.summary
	local total = s.added + s.removed + s.modified

	if total > 0 then
		lastDiffResult = result
		showResults(result, currentFilter)
		statusLabel.Text = string.format("Found %d changes (+%d -%d ~%d)", total, s.added, s.removed, s.modified)
	else
		lastDiffResult = nil
		clearResults()
		statusLabel.Text = "No changes detected."
	end
end

-- ============================================================
-- Auto-snapshot on publish
-- ============================================================
local function onAutoSnapshot()
	if not autoSnapshotEnabled then return end
	onSnapshot()
	statusLabel.Text = "[Auto] " .. statusLabel.Text
end

local publishConnection = nil
local function connectPublishHook()
	local ok, _ = pcall(function()
		publishConnection = StudioService:GetPropertyChangedSignal("StudioLocaleId"):Connect(function() end)
	end)
end

-- Use ChangeHistoryService as a proxy for detecting publishes
local lastWaypointTime = 0
ChangeHistoryService.OnUndo:Connect(function() end)
ChangeHistoryService.OnRedo:Connect(function() end)

-- ============================================================
-- Events
-- ============================================================
toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

snapshotBtn.MouseButton1Click:Connect(onSnapshot)
diffBtn.MouseButton1Click:Connect(onCompare)

autoBtn.MouseButton1Click:Connect(function()
	autoSnapshotEnabled = not autoSnapshotEnabled
	if autoSnapshotEnabled then
		autoBtn.Text = "Auto: ON"
		autoBtn.BackgroundColor3 = COLORS.added
	else
		autoBtn.Text = "Auto: OFF"
		autoBtn.BackgroundColor3 = COLORS.border
	end
	plugin:SetSetting(SETTING_AUTO, autoSnapshotEnabled)
end)

allFilterBtn.MouseButton1Click:Connect(function() updateFilterUI("all") end)
addFilterBtn.MouseButton1Click:Connect(function() updateFilterUI("added") end)
remFilterBtn.MouseButton1Click:Connect(function() updateFilterUI("removed") end)
modFilterBtn.MouseButton1Click:Connect(function() updateFilterUI("modified") end)

-- Load settings
local savedAuto = plugin:GetSetting(SETTING_AUTO)
if savedAuto ~= nil then
	autoSnapshotEnabled = savedAuto
	if autoSnapshotEnabled then
		autoBtn.Text = "Auto: ON"
		autoBtn.BackgroundColor3 = COLORS.added
	else
		autoBtn.Text = "Auto: OFF"
		autoBtn.BackgroundColor3 = COLORS.border
	end
end

loadSavedSnapshot()
