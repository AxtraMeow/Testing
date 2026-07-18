--[[
	FreezeRemotes.lua  (ModuleScript in ReplicatedStorage)

	Creates and exposes the RemoteEvents used by the freeze system.
	Require this module on both server and client to get the same
	event references without hard-coding paths everywhere.
]]

local RS = game:GetService("ReplicatedStorage")

local function getOrCreate(className, name, parent)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local folder = getOrCreate("Folder", "FreezeSystem", RS)

return {
	-- Server → Client: sends current cold level (0–1) so the client
	-- can update the visual overlay.
	UpdateCold  = getOrCreate("RemoteEvent", "UpdateCold",  folder),

	-- Server → Client: tells the client to flash a "you're warming up"
	-- tint briefly so the player gets feedback near a heat source.
	Warming     = getOrCreate("RemoteEvent", "Warming",     folder),
}
