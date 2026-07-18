--[[
	FreezeEffect.client.lua

	Handles the visual + audio side of the freeze system:
	  • An ice/frost vignette that fades in around the screen edges as the
	    player gets colder.
	  • Screen desaturation / blue tint at high cold levels.
	  • A "warming up" amber flash when the player steps into a heat source.
	  • Subtle breathing / pulse animation on the overlay while cold.

	Everything here is purely cosmetic — damage and cold state live on the server.
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")

local player           = Players.LocalPlayer
local playerGui        = player:WaitForChild("PlayerGui")

-- Wait for remotes (created by FreezeRemotes ModuleScript on the server)
local RS       = game:GetService("ReplicatedStorage")
local folder   = RS:WaitForChild("FreezeSystem", 10)
if not folder then warn("[FreezeEffect] FreezeSystem folder not found in RS") return end

local UpdateCold = folder:WaitForChild("UpdateCold", 10)
local Warming    = folder:WaitForChild("Warming",    10)
if not UpdateCold or not Warming then
	warn("[FreezeEffect] Remotes not found") return
end

-- ── Build GUI ────────────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name            = "FreezeEffectGui"
screenGui.ResetOnSpawn    = false
screenGui.IgnoreGuiInset  = true
screenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder    = 99   -- render above most other GUIs
screenGui.Parent          = playerGui

-- Full-screen container
local container = Instance.new("Frame")
container.Name              = "Container"
container.Size              = UDim2.fromScale(1, 1)
container.Position          = UDim2.fromScale(0, 0)
container.BackgroundColor3  = Color3.new(0, 0, 0)
container.BackgroundTransparency = 1
container.BorderSizePixel   = 0
container.Parent            = screenGui

-- ── Ice vignette (UIGradient fading from icy edges to transparent center) ──

local vignette = Instance.new("Frame")
vignette.Name              = "IceVignette"
vignette.Size              = UDim2.fromScale(1, 1)
vignette.Position          = UDim2.fromScale(0, 0)
vignette.BackgroundColor3  = Color3.fromRGB(180, 220, 255)  -- cool ice blue
vignette.BackgroundTransparency = 1
vignette.BorderSizePixel   = 0
vignette.ZIndex            = 2
vignette.Parent            = container

-- Radial-ish gradient: opaque at edges, transparent in centre
local gradient = Instance.new("UIGradient")
gradient.Color  = ColorSequence.new({
	ColorSequenceKeypoint.new(0,    Color3.fromRGB(180, 220, 255)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(180, 220, 255)),
	ColorSequenceKeypoint.new(1,    Color3.fromRGB(180, 220, 255)),
})
gradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0,    0),      -- edges opaque
	NumberSequenceKeypoint.new(0.38, 0.6),
	NumberSequenceKeypoint.new(0.55, 1),      -- centre fully transparent
	NumberSequenceKeypoint.new(1,    1),
})
gradient.Rotation = 90
gradient.Parent   = vignette

-- ── Blue tint overlay (full-screen) ─────────────────────────────────────────

local tint = Instance.new("Frame")
tint.Name              = "BlueTint"
tint.Size              = UDim2.fromScale(1, 1)
tint.Position          = UDim2.fromScale(0, 0)
tint.BackgroundColor3  = Color3.fromRGB(100, 160, 220)
tint.BackgroundTransparency = 1   -- starts invisible
tint.BorderSizePixel   = 0
tint.ZIndex            = 1
tint.Parent            = container

-- ── Warming flash (amber overlay) ───────────────────────────────────────────

local warmFlash = Instance.new("Frame")
warmFlash.Name              = "WarmFlash"
warmFlash.Size              = UDim2.fromScale(1, 1)
warmFlash.Position          = UDim2.fromScale(0, 0)
warmFlash.BackgroundColor3  = Color3.fromRGB(255, 160, 50)
warmFlash.BackgroundTransparency = 1
warmFlash.BorderSizePixel   = 0
warmFlash.ZIndex            = 3
warmFlash.Parent            = container

-- ── Icy crack/frost texture overlay ─────────────────────────────────────────
-- Uses a built-in Roblox decal. Swap the asset ID for a custom frost texture
-- if you have one.

local frostFrame = Instance.new("Frame")
frostFrame.Name              = "FrostTexture"
frostFrame.Size              = UDim2.fromScale(1, 1)
frostFrame.Position          = UDim2.fromScale(0, 0)
frostFrame.BackgroundTransparency = 1
frostFrame.BorderSizePixel   = 0
frostFrame.ZIndex            = 4
frostFrame.Parent            = container

local frostImage = Instance.new("ImageLabel")
frostImage.Name              = "FrostImage"
frostImage.Size              = UDim2.fromScale(1, 1)
frostImage.Position          = UDim2.fromScale(0, 0)
frostImage.BackgroundTransparency = 1
frostImage.BorderSizePixel   = 0
-- Built-in Roblox frost / ice crack texture (public domain asset)
frostImage.Image             = "rbxassetid://6031094667"
frostImage.ImageColor3       = Color3.fromRGB(180, 220, 255)
frostImage.ImageTransparency = 1   -- starts invisible
frostImage.ScaleType         = Enum.ScaleType.Stretch
frostImage.ZIndex            = 4
frostImage.Parent            = frostFrame

-- ── State ────────────────────────────────────────────────────────────────────

local FREEZE_THRESHOLD = 0.25   -- must match server constant

local currentCold      = 0
local targetCold       = 0
local breathPhase      = 0

-- ── Update visuals ───────────────────────────────────────────────────────────

local function updateVisuals(cold, dt)
	-- Lerp displayed cold toward target for smooth transitions
	currentCold = currentCold + (targetCold - currentCold) * math.min(1, dt * 4)

	if currentCold <= FREEZE_THRESHOLD then
		-- Fully warm — hide everything
		vignette.BackgroundTransparency = 1
		tint.BackgroundTransparency     = 1
		frostImage.ImageTransparency    = 1
		return
	end

	-- Normalise: 0 at threshold → 1 at max cold
	local t = (currentCold - FREEZE_THRESHOLD) / (1 - FREEZE_THRESHOLD)

	-- Pulse the vignette slightly when very cold so it feels "alive"
	breathPhase = breathPhase + dt * 1.2
	local breathe = math.sin(breathPhase) * 0.05 * t

	-- Vignette: fully transparent centre → icy edge opacity grows with cold
	local vignetteEdge = 0 + t * 0.65 + breathe
	vignette.BackgroundTransparency = math.clamp(1 - vignetteEdge * 0.9, 0.1, 1)

	-- Blue tint: starts at 0, peaks at ~0.55 transparency (subtle)
	tint.BackgroundTransparency = math.clamp(1 - t * 0.45, 0.55, 1)

	-- Frost texture: fades in after ~50% cold
	local frostT = math.clamp((t - 0.5) / 0.5, 0, 1)
	frostImage.ImageTransparency = math.clamp(1 - frostT * 0.75, 0.25, 1)
end

-- ── Remote listeners ─────────────────────────────────────────────────────────

UpdateCold.OnClientEvent:Connect(function(cold)
	targetCold = cold
end)

Warming.OnClientEvent:Connect(function()
	-- Brief amber flash to signal the player they are warming up
	local showTween = TweenService:Create(
		warmFlash,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.55 }
	)
	local hideTween = TweenService:Create(
		warmFlash,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	)
	showTween:Play()
	showTween.Completed:Connect(function()
		hideTween:Play()
	end)
end)

-- ── Render loop ──────────────────────────────────────────────────────────────

local lastTime = tick()
game:GetService("RunService").RenderStepped:Connect(function()
	local now = tick()
	local dt  = now - lastTime
	lastTime  = now
	updateVisuals(currentCold, dt)
end)
