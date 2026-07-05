--[[
	ProximityBubbleChat.client.lua

	Custom chat bubble system:
		- Bubbles appear slightly above each character's head.
		- Within NEAR_DISTANCE studs of the speaker: full message shown.
		- Between NEAR_DISTANCE and FAR_DISTANCE studs: message replaced with "[ Inaudible ]".
		- Beyond FAR_DISTANCE studs: nothing shown.
		- Visibility/text is recalculated every frame, so bubbles update live as players
		  move closer/farther without needing a new message to be sent.

	Requires TextChatService (Roblox's default modern chat system) to be enabled.
	The default built-in bubble chat is disabled here so it doesn't double up with
	this custom one; the classic top-left chat window is left untouched.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local LocalPlayer = Players.LocalPlayer

local NEAR_DISTANCE = 18
local FAR_DISTANCE = 28
local BUBBLE_DURATION = 8 -- seconds a message stays alive before it fully expires

-- Turn off Roblox's default bubble chat so only our custom bubbles are shown.
local bubbleChatConfiguration = TextChatService:FindFirstChild("BubbleChatConfiguration")
if bubbleChatConfiguration then
	bubbleChatConfiguration.Enabled = false
end

--============================================================
-- Bubble creation
--============================================================

local function createBubble(head)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CustomChatBubble"
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 220, 0, 56)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = head

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	background.BackgroundTransparency = 0.1
	background.Parent = billboard

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0, 12)
	backgroundCorner.Parent = background

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, -14, 1, -10)
	label.Position = UDim2.new(0, 7, 0, 5)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(25, 25, 25)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = ""
	label.Parent = background

	return billboard, label
end

local function getOrCreateBubble(character)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil, nil
	end

	local existing = head:FindFirstChild("CustomChatBubble")
	if existing then
		return existing, existing:FindFirstChild("Background") and existing.Background:FindFirstChild("Text")
	end

	return createBubble(head)
end

--============================================================
-- Active message tracking
--============================================================

-- activeMessages[player] = { Text, ExpireAt, Billboard, Label, Character }
local activeMessages = {}

local function clearMessage(player)
	local data = activeMessages[player]
	if data and data.Billboard then
		data.Billboard.Enabled = false
	end
	activeMessages[player] = nil
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		clearMessage(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		clearMessage(player)
	end)
end

Players.PlayerRemoving:Connect(clearMessage)

--============================================================
-- Listen for chat messages
--============================================================

TextChatService.MessageReceived:Connect(function(textChatMessage)
	local textSource = textChatMessage.TextSource
	if not textSource then
		-- System messages (joins/leaves/etc.) have no TextSource; ignore them.
		return
	end

	local speaker = Players:GetPlayerByUserId(textSource.UserId)
	if not speaker then
		return
	end

	local character = speaker.Character
	if not character then
		return
	end

	local billboard, label = getOrCreateBubble(character)
	if not billboard or not label then
		return
	end

	activeMessages[speaker] = {
		Text = textChatMessage.Text,
		ExpireAt = os.clock() + BUBBLE_DURATION,
		Billboard = billboard,
		Label = label,
		Character = character,
	}
end)

--============================================================
-- Continuous distance-based visibility update
--============================================================

RunService.Heartbeat:Connect(function()
	local localCharacter = LocalPlayer.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

	for speaker, data in pairs(activeMessages) do
		if os.clock() > data.ExpireAt then
			clearMessage(speaker)
		elseif localRoot and data.Character then
			local speakerRoot = data.Character:FindFirstChild("HumanoidRootPart")
			if speakerRoot then
				local distance = (speakerRoot.Position - localRoot.Position).Magnitude

				if distance <= NEAR_DISTANCE then
					data.Billboard.Enabled = true
					data.Label.Text = data.Text
				elseif distance <= FAR_DISTANCE then
					data.Billboard.Enabled = true
					data.Label.Text = "[ Inaudible ]"
				else
					data.Billboard.Enabled = false
				end
			else
				data.Billboard.Enabled = false
			end
		else
			data.Billboard.Enabled = false
		end
	end
end)
