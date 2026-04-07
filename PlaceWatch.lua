--[[
	PlaceWatch - Roblox Studio Plugin v0.5.0
	Automatically detect and visualize differences between place snapshots.
	Features: 2-button UI, smart notifications, auto-scan, Discord webhook
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
	return { data = data, timestamp = os.time(), instanceCount = count, placeId = game.PlaceId }
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
local SETTING_WEBHOOK = "PlaceWatch_WebhookUrl"
local SETTING_INTERVAL = "PlaceWatch_Interval"
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local StudioService = game:GetService("StudioService")

local autoSnapshotEnabled = true
local currentFilter = "all" -- all, added, removed, modified
local webhookUrl = ""
local autoInterval = 300 -- seconds (default 5 min)
local autoScanRunning = false
local changeDetectionConnections = {}

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

-- Single row: 2 buttons
buttonBar.Size = UDim2.new(1, 0, 0, 50)
buttonBar.Position = UDim2.new(0, 0, 1, -50)
scrollFrame.Size = UDim2.new(1, 0, 1, -158)

local snapshotBtn = createButton(buttonBar, "Snapshot", UDim2.new(0, 8, 0, 8), UDim2.new(0.5, -12, 0, 34))
local autoBtn = createButton(buttonBar, "Auto: ON", UDim2.new(0.5, 4, 0, 8), UDim2.new(0.5, -12, 0, 34))
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
		-- Invalidate if PlaceId changed
		if saved.placeId and saved.placeId ~= game.PlaceId then
			plugin:SetSetting(SETTING_KEY, nil)
			statusLabel.Text = "Place changed. Click 'Snapshot' to start."
			return
		end
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
-- Notification Intelligence
-- ============================================================
local SCRIPT_CLASSES = {
	Script = true, LocalScript = true, ModuleScript = true,
}
local ALERT_DELETE_THRESHOLD = 5

local function classifyAlert(result)
	-- Check for Script changes (immediate alert)
	for _, entry in ipairs(result.added) do
		if SCRIPT_CLASSES[entry.className] then return "alert", "Script added: " .. entry.path end
	end
	for _, entry in ipairs(result.removed) do
		if SCRIPT_CLASSES[entry.className] then return "alert", "Script removed: " .. entry.path end
	end
	for _, entry in ipairs(result.modified) do
		if SCRIPT_CLASSES[entry.className] then
			for _, c in ipairs(entry.changes) do
				if c.name == "Source" then return "alert", "Script modified: " .. entry.path end
			end
		end
	end
	-- Check for mass deletion
	if result.summary.removed >= ALERT_DELETE_THRESHOLD then
		return "alert", result.summary.removed .. " instances deleted"
	end
	return "normal", nil
end

-- ============================================================
-- Discord Webhook
-- ============================================================
local pendingDiscordResult = nil -- accumulated changes for batched send

local function buildEmbed(result, level, alertReason)
	local s = result.summary
	local placeName = game.Name ~= "" and game.Name or "Untitled Place"
	local placeId = game.PlaceId

	local embedColor = 3447003 -- blue (info)
	local titleSuffix = ""
	if level == "alert" then
		embedColor = 15158332 -- red
		titleSuffix = " [ALERT]"
	elseif level == "warning" then
		embedColor = 16776960 -- yellow
		titleSuffix = " [WARNING]"
	end

	local fields = {}
	if s.added > 0 then
		local lines = {}
		for i, entry in ipairs(result.added) do
			if i > 10 then table.insert(lines, "... +" .. (s.added - 10) .. " more"); break end
			local icon = SCRIPT_CLASSES[entry.className] and "**`+`**" or "`+`"
			table.insert(lines, icon .. " " .. entry.path .. " (" .. entry.className .. ")")
		end
		table.insert(fields, { name = "Added (" .. s.added .. ")", value = table.concat(lines, "\n"), inline = false })
	end
	if s.removed > 0 then
		local lines = {}
		for i, entry in ipairs(result.removed) do
			if i > 10 then table.insert(lines, "... +" .. (s.removed - 10) .. " more"); break end
			local icon = SCRIPT_CLASSES[entry.className] and "**`-`**" or "`-`"
			table.insert(lines, icon .. " " .. entry.path .. " (" .. entry.className .. ")")
		end
		table.insert(fields, { name = "Removed (" .. s.removed .. ")", value = table.concat(lines, "\n"), inline = false })
	end
	if s.modified > 0 then
		local lines = {}
		for i, entry in ipairs(result.modified) do
			if i > 10 then table.insert(lines, "... +" .. (s.modified - 10) .. " more"); break end
			local propChanges = {}
			for _, c in ipairs(entry.changes) do
				table.insert(propChanges, c.name)
			end
			local icon = SCRIPT_CLASSES[entry.className] and "**`~`**" or "`~`"
			table.insert(lines, icon .. " " .. entry.path .. " [" .. table.concat(propChanges, ", ") .. "]")
		end
		table.insert(fields, { name = "Modified (" .. s.modified .. ")", value = table.concat(lines, "\n"), inline = false })
	end

	local desc = string.format("**%s** (PlaceId: %d)\n+%d added / -%d removed / ~%d modified",
		placeName, placeId, s.added, s.removed, s.modified)
	if alertReason then
		desc = desc .. "\n\n" .. alertReason
	end

	return {
		title = "PlaceWatch" .. titleSuffix,
		description = desc,
		color = embedColor,
		fields = fields,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		footer = { text = "PlaceWatch v0.4.0" },
	}
end

local function sendToDiscord(result, level, alertReason)
	if webhookUrl == "" then return end

	local embed = buildEmbed(result, level, alertReason)
	local payload = HttpService:JSONEncode({ embeds = { embed } })

	local ok, err = pcall(function()
		HttpService:PostAsync(webhookUrl, payload, Enum.HttpContentType.ApplicationJson)
	end)
	if ok then
		statusLabel.Text = "[Discord] Notification sent"
	else
		warn("[PlaceWatch] Webhook error: " .. tostring(err))
	end
end

-- ============================================================
-- Auto-scan (periodic + real-time)
-- ============================================================
local pendingChange = false
local accumulatedResult = nil -- accumulated changes between notifications

local function mergeResults(existing, new)
	if not existing then return new end
	-- Merge: take the latest result (full re-diff is more accurate)
	return new
end

local function autoCompare()
	if not lastSnapshot then return end

	local currentSnap = takeSnapshot()
	local result = computeDiff(lastSnapshot, currentSnap)
	local s = result.summary
	local total = s.added + s.removed + s.modified

	if total > 0 then
		lastDiffResult = result
		showResults(result, currentFilter)
		statusLabel.Text = string.format("[Auto] %d changes (+%d -%d ~%d)", total, s.added, s.removed, s.modified)

		-- Smart notification logic
		local level, reason = classifyAlert(result)
		if level == "alert" then
			-- Immediate Discord notification for critical changes
			sendToDiscord(result, "alert", reason)
			accumulatedResult = nil
			-- Update baseline after alert
			lastSnapshot = currentSnap
			plugin:SetSetting(SETTING_KEY, currentSnap)
		else
			-- Accumulate for batched notification (sent on save/interval)
			accumulatedResult = mergeResults(accumulatedResult, result)
		end
	else
		-- No changes, flush accumulated if any
		if accumulatedResult then
			sendToDiscord(accumulatedResult, "normal")
			accumulatedResult = nil
		end
	end
end

-- Send accumulated changes (called on save / manual compare)
local function flushNotification()
	if accumulatedResult then
		sendToDiscord(accumulatedResult, "normal")
		-- Update baseline
		local currentSnap = takeSnapshot()
		lastSnapshot = currentSnap
		plugin:SetSetting(SETTING_KEY, currentSnap)
		accumulatedResult = nil
	end
end

local function startAutoScan()
	if autoScanRunning then return end
	autoScanRunning = true

	task.spawn(function()
		while autoScanRunning and autoSnapshotEnabled do
			task.wait(autoInterval)
			if not autoSnapshotEnabled then break end
			autoCompare()
		end
		autoScanRunning = false
	end)
end

local function stopAutoScan()
	autoScanRunning = false
end

-- Real-time change detection via DescendantAdded/Removing
local function connectChangeDetection()
	for _, conn in ipairs(changeDetectionConnections) do
		conn:Disconnect()
	end
	changeDetectionConnections = {}

	for _, serviceName in ipairs(Config.SCAN_SERVICES) do
		local ok, service = pcall(function()
			return game:GetService(serviceName)
		end)
		if ok and service then
			local c1 = service.DescendantAdded:Connect(function(desc)
				pendingChange = true
				-- Immediate check for Script additions
				if SCRIPT_CLASSES[desc.ClassName] and autoSnapshotEnabled and lastSnapshot then
					task.wait(1)
					autoCompare()
				end
			end)
			local c2 = service.DescendantRemoving:Connect(function(desc)
				pendingChange = true
				-- Immediate check for Script removals
				if SCRIPT_CLASSES[desc.ClassName] and autoSnapshotEnabled and lastSnapshot then
					task.wait(1)
					autoCompare()
				end
			end)
			table.insert(changeDetectionConnections, c1)
			table.insert(changeDetectionConnections, c2)
		end
	end

	-- Debounced change handler for non-critical changes
	task.spawn(function()
		while true do
			task.wait(10) -- check every 10 seconds
			if pendingChange and autoSnapshotEnabled and lastSnapshot then
				pendingChange = false
				task.wait(3) -- debounce
				autoCompare()
			end
		end
	end)
end

-- ============================================================
-- Events
-- ============================================================
toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

-- Snapshot button: save baseline + compare + send to Discord
snapshotBtn.MouseButton1Click:Connect(function()
	if lastSnapshot then
		-- Compare first, then update baseline
		onCompare()
		if lastDiffResult then
			local level, reason = classifyAlert(lastDiffResult)
			sendToDiscord(lastDiffResult, level, reason)
			accumulatedResult = nil
		end
	end
	onSnapshot()
end)

autoBtn.MouseButton1Click:Connect(function()
	autoSnapshotEnabled = not autoSnapshotEnabled
	if autoSnapshotEnabled then
		autoBtn.Text = "Auto: ON"
		autoBtn.BackgroundColor3 = COLORS.added
		if not lastSnapshot then
			onSnapshot()
		end
		startAutoScan()
		statusLabel.Text = "Auto-scan started"
	else
		autoBtn.Text = "Auto: OFF"
		autoBtn.BackgroundColor3 = COLORS.border
		stopAutoScan()
		statusLabel.Text = "Auto-scan stopped"
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

local savedWebhook = plugin:GetSetting(SETTING_WEBHOOK)
if savedWebhook and savedWebhook ~= "" then
	webhookUrl = savedWebhook
end

local savedInterval = plugin:GetSetting(SETTING_INTERVAL)
if savedInterval then
	autoInterval = savedInterval
end

loadSavedSnapshot()

-- _G config listener: check for webhook/interval changes
task.spawn(function()
	while true do
		task.wait(2)
		if _G.PlaceWatchWebhook then
			webhookUrl = _G.PlaceWatchWebhook
			_G.PlaceWatchWebhook = nil
			plugin:SetSetting(SETTING_WEBHOOK, webhookUrl)
			statusLabel.Text = "Webhook connected!"
		end
		if _G.PlaceWatchInterval then
			autoInterval = _G.PlaceWatchInterval
			_G.PlaceWatchInterval = nil
			plugin:SetSetting(SETTING_INTERVAL, autoInterval)
			statusLabel.Text = "Interval: " .. autoInterval .. "s"
			if autoSnapshotEnabled then
				stopAutoScan()
				task.wait(0.1)
				startAutoScan()
			end
		end
		if _G.PlaceWatchWebhookOff then
			webhookUrl = ""
			_G.PlaceWatchWebhookOff = nil
			plugin:SetSetting(SETTING_WEBHOOK, "")
			statusLabel.Text = "Webhook disabled"
		end
	end
end)

-- Start auto features
if autoSnapshotEnabled and lastSnapshot then
	startAutoScan()
end
connectChangeDetection()
