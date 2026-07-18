--[[
	FreezeSystem.server.lua
	
	Freeze / hypothermia system:
	  • Every player slowly gets colder the longer they are in the game.
	  • Cold is tracked as a value from 0 (warm) → 1 (fully frozen).
	  • While cold < FREEZE_THRESHOLD nothing happens visually (client handles that).
	  • Once fully frozen (cold == 1) the player takes DAMAGE_PER_TICK damage every
	    DAMAGE_INTERVAL seconds until they warm up or die.
	  • Any BasePart inside the Workspace folder named "HeatSources" warms nearby
	    players.  Place campfires, fireplaces, lava pools, etc. there in Studio.

	TUNING:
	  COLD_RATE          – how fast cold increases per second (1 = full cold in 1 s)
	  WARM_RATE          – how fast heat sources warm per second when in range
	  FREEZE_THRESHOLD   – cold value at which the screen effect starts (0–1)
	  HEAT_RADIUS        – studs from a heat source that count as "near it"
	  DAMAGE_PER_TICK    – HP lost per tick while fully frozen
	  DAMAGE_INTERVAL    – seconds between damage ticks while fully frozen
	  UPDATE_INTERVAL    – how often the server loop runs (seconds)
	  GRACE_PERIOD       – seconds after spawn before freezing begins
]]

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local Workspace     = game:GetService("Workspace")

-- ── Tuning ────────────────────────────────────────────────────────────────────
local COLD_RATE        = 1 / 30   -- fully frozen after 30 seconds without warmth
local WARM_RATE        = 1 / 8    -- fully warmed after 8 seconds near a heat source
local FREEZE_THRESHOLD = 0.25     -- screen effect starts at 25% cold
local HEAT_RADIUS      = 18       -- studs
local DAMAGE_PER_TICK  = 5        -- HP per damage tick
local DAMAGE_INTERVAL  = 2        -- seconds between damage ticks
local UPDATE_INTERVAL  = 0.1      -- server loop tick rate
local GRACE_PERIOD     = 5        -- seconds before cold starts building
-- ─────────────────────────────────────────────────────────────────────────────

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("FreezeRemotes"))

-- Per-player state
-- { cold: number, damageTimer: number, spawnTime: number }
local playerData = {}

-- ── Heat source helpers ───────────────────────────────────────────────────────

local function getHeatSources()
	local folder = Workspace:FindFirstChild("HeatSources")
	if not folder then return {} end
	return folder:GetChildren()
end

local function getNearestHeatDistance(rootPos)
	local nearest = math.huge
	for _, part in ipairs(getHeatSources()) do
		if part:IsA("BasePart") then
			local d = (part.Position - rootPos).Magnitude
			if d < nearest then nearest = d end
		end
	end
	return nearest
end

-- ── Player lifecycle ──────────────────────────────────────────────────────────

local function onPlayerAdded(player)
	playerData[player] = {
		cold        = 0,
		damageTimer = 0,
		spawnTime   = tick(),
	}
end

local function onPlayerRemoving(player)
	playerData[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- catch players already in game when this script runs
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

-- ── Main loop ─────────────────────────────────────────────────────────────────

local lastTick = tick()

RunService.Heartbeat:Connect(function()
	local now = tick()
	local dt  = now - lastTick
	lastTick  = now

	-- throttle to UPDATE_INTERVAL to avoid spamming remotes
	-- (we accumulate dt and fire when enough time has passed)
	for player, data in pairs(playerData) do
		local character = player.Character
		local humanoid  = character and character:FindFirstChildOfClass("Humanoid")
		local root      = character and character:FindFirstChild("HumanoidRootPart")

		-- Skip dead or not-yet-spawned players
		if not humanoid or humanoid.Health <= 0 or not root then
			continue
		end

		-- Grace period after spawn/respawn
		if (now - data.spawnTime) < GRACE_PERIOD then
			-- Reset cold on fresh spawn so respawning isn't an instant death
			data.cold = 0
			Remotes.UpdateCold:FireClient(player, 0)
			continue
		end

		local nearHeat = getNearestHeatDistance(root.Position) < HEAT_RADIUS

		if nearHeat then
			-- Warm up
			local prevCold = data.cold
			data.cold = math.max(0, data.cold - WARM_RATE * dt)
			data.damageTimer = 0
			-- Notify client of warmth feedback when crossing from cold → warming
			if prevCold > FREEZE_THRESHOLD and data.cold <= FREEZE_THRESHOLD then
				Remotes.Warming:FireClient(player)
			end
		else
			-- Get colder
			data.cold = math.min(1, data.cold + COLD_RATE * dt)
		end

		-- Push cold level to client (client throttles its own rendering)
		Remotes.UpdateCold:FireClient(player, data.cold)

		-- Apply damage when fully frozen
		if data.cold >= 1 then
			data.damageTimer = data.damageTimer + dt
			if data.damageTimer >= DAMAGE_INTERVAL then
				data.damageTimer = 0
				humanoid:TakeDamage(DAMAGE_PER_TICK)
			end
		else
			data.damageTimer = 0
		end
	end
end)

-- Reset spawn time whenever a character is added (respawn)
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		if playerData[player] then
			playerData[player].spawnTime   = tick()
			playerData[player].cold        = 0
			playerData[player].damageTimer = 0
		end
	end)
end)

-- Also wire up CharacterAdded for players already in-game
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		if playerData[player] then
			playerData[player].spawnTime   = tick()
			playerData[player].cold        = 0
			playerData[player].damageTimer = 0
		end
	end)
end
