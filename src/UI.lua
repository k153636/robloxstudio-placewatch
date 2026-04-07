local UI = {}
UI.__index = UI

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
}

function UI.new(plugin)
	local self = setmetatable({}, UI)
	self.plugin = plugin

	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		false,
		300,
		600,
		250,
		400
	)
	self.widget = plugin:CreateDockWidgetPluginGui("PlaceWatch", widgetInfo)
	self.widget.Title = "PlaceWatch"

	self:buildUI()
	return self
end

function UI:buildUI()
	-- Main container
	local main = Instance.new("Frame")
	main.Size = UDim2.new(1, 0, 1, 0)
	main.BackgroundColor3 = COLORS.bg
	main.BorderSizePixel = 0
	main.Parent = self.widget

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = COLORS.header
	header.BorderSizePixel = 0
	header.Parent = main

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Position = UDim2.new(0, 8, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "PlaceWatch"
	title.TextColor3 = COLORS.text
	title.TextSize = 16
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	self.statusLabel = Instance.new("TextLabel")
	self.statusLabel.Size = UDim2.new(1, -16, 0, 16)
	self.statusLabel.Position = UDim2.new(0, 8, 0, 28)
	self.statusLabel.BackgroundTransparency = 1
	self.statusLabel.Text = "Ready"
	self.statusLabel.TextColor3 = COLORS.textDim
	self.statusLabel.TextSize = 12
	self.statusLabel.Font = Enum.Font.Gotham
	self.statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.statusLabel.Parent = header

	-- Summary bar
	self.summaryFrame = Instance.new("Frame")
	self.summaryFrame.Size = UDim2.new(1, 0, 0, 30)
	self.summaryFrame.Position = UDim2.new(0, 0, 0, 50)
	self.summaryFrame.BackgroundColor3 = COLORS.header
	self.summaryFrame.BorderSizePixel = 0
	self.summaryFrame.Visible = false
	self.summaryFrame.Parent = main

	self.summaryLabel = Instance.new("TextLabel")
	self.summaryLabel.Size = UDim2.new(1, -16, 1, 0)
	self.summaryLabel.Position = UDim2.new(0, 8, 0, 0)
	self.summaryLabel.BackgroundTransparency = 1
	self.summaryLabel.TextColor3 = COLORS.text
	self.summaryLabel.TextSize = 13
	self.summaryLabel.Font = Enum.Font.GothamBold
	self.summaryLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.summaryLabel.Parent = self.summaryFrame

	-- Scroll area for diff results
	self.scrollFrame = Instance.new("ScrollingFrame")
	self.scrollFrame.Size = UDim2.new(1, 0, 1, -130)
	self.scrollFrame.Position = UDim2.new(0, 0, 0, 80)
	self.scrollFrame.BackgroundTransparency = 1
	self.scrollFrame.BorderSizePixel = 0
	self.scrollFrame.ScrollBarThickness = 6
	self.scrollFrame.ScrollBarImageColor3 = COLORS.border
	self.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	self.scrollFrame.Parent = main

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = self.scrollFrame

	-- Button bar
	local buttonBar = Instance.new("Frame")
	buttonBar.Size = UDim2.new(1, 0, 0, 50)
	buttonBar.Position = UDim2.new(0, 0, 1, -50)
	buttonBar.BackgroundColor3 = COLORS.header
	buttonBar.BorderSizePixel = 0
	buttonBar.Parent = main

	self.snapshotBtn = self:createButton(buttonBar, "Snapshot", UDim2.new(0, 8, 0, 8), UDim2.new(0.5, -12, 0, 34))
	self.diffBtn = self:createButton(buttonBar, "Compare", UDim2.new(0.5, 4, 0, 8), UDim2.new(0.5, -12, 0, 34))
end

function UI:createButton(parent, text, position, size)
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

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = COLORS.buttonHover
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = COLORS.button
	end)

	return btn
end

function UI:setStatus(text)
	self.statusLabel.Text = text
end

function UI:showSummary(result)
	local s = result.summary
	self.summaryLabel.Text = string.format(
		"+%d added   -%d removed   ~%d modified",
		s.added, s.removed, s.modified
	)
	self.summaryFrame.Visible = true
end

function UI:clearResults()
	for _, child in ipairs(self.scrollFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

function UI:addDiffEntry(entryType, path, className, details)
	local color, prefix
	if entryType == "added" then
		color = COLORS.added
		prefix = "+"
	elseif entryType == "removed" then
		color = COLORS.removed
		prefix = "-"
	else
		color = COLORS.modified
		prefix = "~"
	end

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -8, 0, 0)
	frame.Position = UDim2.new(0, 4, 0, 0)
	frame.BackgroundColor3 = COLORS.header
	frame.BorderSizePixel = 0
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.Parent = self.scrollFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = frame

	-- Header line
	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, 0, 0, 18)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = string.format("[%s] %s (%s)", prefix, path, className)
	headerLabel.TextColor3 = color
	headerLabel.TextSize = 12
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.TextTruncate = Enum.TextTruncate.AtEnd
	headerLabel.LayoutOrder = 1
	headerLabel.Parent = frame

	-- Detail lines (for modified)
	if details then
		for _, change in ipairs(details) do
			local detail = Instance.new("TextLabel")
			detail.Size = UDim2.new(1, 0, 0, 14)
			detail.BackgroundTransparency = 1
			detail.Text = string.format("  %s: %s → %s", change.name, tostring(change.oldValue), tostring(change.newValue))
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

function UI:showResults(result)
	self:clearResults()
	self:showSummary(result)

	for _, entry in ipairs(result.added) do
		self:addDiffEntry("added", entry.path, entry.className)
	end
	for _, entry in ipairs(result.removed) do
		self:addDiffEntry("removed", entry.path, entry.className)
	end
	for _, entry in ipairs(result.modified) do
		self:addDiffEntry("modified", entry.path, entry.className, entry.changes)
	end

	-- Update canvas size
	local layout = self.scrollFrame:FindFirstChildOfClass("UIListLayout")
	if layout then
		self.scrollFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end
end

function UI:toggle()
	self.widget.Enabled = not self.widget.Enabled
end

return UI
