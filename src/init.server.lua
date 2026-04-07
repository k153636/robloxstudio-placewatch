--[[
	PlaceWatch - Roblox Studio Plugin
	Automatically detect and visualize differences between place snapshots.
]]

local Snapshot = require(script.Snapshot)
local DiffEngine = require(script.DiffEngine)
local UI = require(script.UI)

local SETTING_KEY = "PlaceWatch_LastSnapshot"

-- Create toolbar
local toolbar = plugin:CreateToolbar("PlaceWatch")
local toggleButton = toolbar:CreateButton(
	"PlaceWatch",
	"Toggle PlaceWatch panel",
	"rbxassetid://6031071053",
	"PlaceWatch"
)

-- Initialize UI
local ui = UI.new(plugin)
local diffEngine = DiffEngine.new()
local lastSnapshot = nil

-- Load saved snapshot
local function loadSavedSnapshot()
	local saved = plugin:GetSetting(SETTING_KEY)
	if saved then
		lastSnapshot = Snapshot.deserialize(saved)
		local timeStr = os.date("%Y-%m-%d %H:%M:%S", lastSnapshot.timestamp)
		ui:setStatus("Last snapshot: " .. timeStr .. " (" .. lastSnapshot.instanceCount .. " instances)")
	else
		ui:setStatus("No snapshot yet. Click 'Snapshot' to start.")
	end
end

-- Take snapshot
local function takeSnapshot()
	ui:setStatus("Taking snapshot...")

	local snapshot = Snapshot.new()
	snapshot:capture()

	plugin:SetSetting(SETTING_KEY, snapshot:serialize())
	lastSnapshot = snapshot

	local timeStr = os.date("%Y-%m-%d %H:%M:%S", snapshot.timestamp)
	ui:setStatus("Snapshot saved: " .. timeStr .. " (" .. snapshot.instanceCount .. " instances)")
end

-- Compare current state with last snapshot
local function compareWithLast()
	if not lastSnapshot then
		ui:setStatus("No previous snapshot. Take one first.")
		return
	end

	ui:setStatus("Scanning current state...")

	local currentSnapshot = Snapshot.new()
	currentSnapshot:capture()

	ui:setStatus("Computing differences...")

	local result = diffEngine:compare(lastSnapshot, currentSnapshot)

	if diffEngine:hasChanges(result) then
		ui:showResults(result)
		local s = result.summary
		ui:setStatus(string.format(
			"Found %d changes (+%d -%d ~%d)",
			s.added + s.removed + s.modified,
			s.added, s.removed, s.modified
		))
	else
		ui:clearResults()
		ui:setStatus("No changes detected.")
	end
end

-- Connect events
toggleButton.Click:Connect(function()
	ui:toggle()
end)

ui.snapshotBtn.MouseButton1Click:Connect(takeSnapshot)
ui.diffBtn.MouseButton1Click:Connect(compareWithLast)

-- Initialize
loadSavedSnapshot()
