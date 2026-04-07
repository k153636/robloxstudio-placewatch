local Config = {}

Config.SCAN_SERVICES = {
	"Workspace",
	"ReplicatedStorage",
	"ServerStorage",
	"ServerScriptService",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Lighting",
	"SoundService",
}

Config.PROPERTY_MAP = {
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
}

Config.IGNORE_CLASSES = {
	"Camera",
	"Terrain",
}

Config.MAX_DEPTH = 50

return Config
