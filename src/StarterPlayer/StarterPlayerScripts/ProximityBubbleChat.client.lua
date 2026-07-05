--[[
	ProximityBubbleChat.client.lua

	Custom chat bubble system:
		- Bubbles appear slightly above each character's head.
		- Within NEAR_DISTANCE studs of the speaker: full message shown.
		- Between NEAR_DISTANCE and FAR_DISTANCE studs: message replaced with "[ Inaudible ]".
		- Beyond FAR_DISTANCE studs: nothing shown.
		- Visibility/text is recalculated every frame, so bubbles update live as players
		  move closer/farther without needing a new message to be sent.
		- Like Roblox's default bubble chat, up to MAX_STACKED_BUBBLES messages stack
		  above a player's head at once; sending a new message beyond that pushes the
		  oldest one out.

	Requires TextChatService (Roblox's default modern chat system) to be enabled.
	The default built-in bubble chat is disabled here so it doesn't double up with
	this custom one. The default chat window/input bar/topbar icon are disabled
	separately in CustomChatWindow.client.lua.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local LocalPlayer = Players.LocalPlayer

local NEAR_DISTANCE = 18
local FAR_DISTANCE = 28
local BUBBLE_DURATION = 8 -- seconds a message stays alive before it fully expires
local MAX_STACKED_BUBBLES = 3

local FONT = Enum.Font.Gotham
local TEXT_SIZE = 14
local MIN_BUBBLE_WIDTH = 54
local MAX_BUBBLE_WIDTH = 200
local HORIZONTAL_PADDING = 22
local VERTICAL_PADDING = 10
local LINE_HEIGHT = 16
local BUBBLE_CORNER_RADIUS = 10

local BASE_STUDS_OFFSET = 1.15 -- height of the newest (bottom) bubble above the head
local STACK_SLOT_SPACING = 0.62 -- extra height added per older stacked bubble

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
	billboard.Size = UDim2.new(0, MIN_BUBBLE_WIDTH, 0, VERTICAL_PADDING + LINE_HEIGHT)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, BASE_STUDS_OFFSET, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = head

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.new(1, 0, 1, 0)
	background.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	background.BackgroundTransparency = 0
	background.BorderSizePixel = 0
	background.ZIndex = 2
	background.Parent = billboard

	local backgroundCorner = Instance.new("UICorner")
	backgroundCorner.CornerRadius = UDim.new(0, BUBBLE_CORNER_RADIUS)
	backgroundCorner.Parent = background

	-- Small pointer tail: a rotated square whose top half hides behind the
	-- bubble background (lower ZIndex), leaving only the bottom point visible.
	-- Only shown on the newest (bottom-most) bubble in a stack.
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0.5, 0, 1, -3)
	tail.Size = UDim2.new(0, 10, 0, 10)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tail.BorderSizePixel = 0
	tail.ZIndex = 1
	tail.Parent = billboard

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.new(1, -HORIZONTAL_PADDING, 1, -8)
	label.Position = UDim2.new(0.5, 0, 0.5, 0)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(20, 20, 20)
	label.Font = FONT
	label.TextSize = TEXT_SIZE
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 2
	label.Text = ""
	label.Parent = background

	return billboard, label, tail
end

-- Resizes the bubble to snugly fit its text, like Roblox's default chat bubbles.
local function resizeBubbleToText(billboard, text)
	local textBounds = TextService:GetTextSize(
		text,
		TEXT_SIZE,
		FONT,
		Vector2.new(MAX_BUBBLE_WIDTH - HORIZONTAL_PADDING, math.huge)
	)

	local width = math.clamp(textBounds.X + HORIZONTAL_PADDING, MIN_BUBBLE_WIDTH, MAX_BUBBLE_WIDTH)
	local height = math.max(textBounds.Y + VERTICAL_PADDING, VERTICAL_PADDING + LINE_HEIGHT)

	billboard.Size = UDim2.new(0, width, 0, height)
end

--============================================================
-- Per-character message stacks
--============================================================

-- characterStacks[player] = {
--   Character = <Character>,
--   Queue = { [1] = newest entry ... [N] = oldest entry },
-- }
-- entry = { Text, ExpireAt, Billboard, Label, Tail }
local characterStacks = {}

local function repositionQueue(queue)
	for index, entry in ipairs(queue) do
		local slot = index - 1 -- 0 = newest/bottom-most
		entry.Billboard.StudsOffsetWorldSpace = Vector3.new(0, BASE_STUDS_OFFSET + slot * STACK_SLOT_SPACING, 0)
		-- Only the newest (closest to the head) bubble shows the pointer tail.
		entry.Tail.Visible = (slot == 0)
	end
end

local function destroyEntry(entry)
	if entry.Billboard then
		entry.Billboard:Destroy()
	end
end

local function clearStack(player)
	local stack = characterStacks[player]
	if not stack then
		return
	end

	for _, entry in ipairs(stack.Queue) do
		destroyEntry(entry)
	end

	characterStacks[player] = nil
end

local function removeEntry(stack, entry)
	for index, existing in ipairs(stack.Queue) do
		if existing == entry then
			table.remove(stack.Queue, index)
			break
		end
	end
	destroyEntry(entry)
	repositionQueue(stack.Queue)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		clearStack(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function()
		clearStack(player)
	end)
end

Players.PlayerRemoving:Connect(clearStack)

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

	local head = character:FindFirstChild("Head")
	if not head then
		return
	end

	local stack = characterStacks[speaker]
	if not stack or stack.Character ~= character then
		-- Character changed (respawn) since we last saw this player; start fresh.
		if stack then
			clearStack(speaker)
		end
		stack = { Character = character, Queue = {} }
		characterStacks[speaker] = stack
	end

	local billboard, label, tail = createBubble(head)
	resizeBubbleToText(billboard, textChatMessage.Text)
	billboard.Enabled = false -- distance check on the next Heartbeat decides real visibility

	local entry = {
		Text = textChatMessage.Text,
		ExpireAt = os.clock() + BUBBLE_DURATION,
		Billboard = billboard,
		Label = label,
		Tail = tail,
	}

	table.insert(stack.Queue, 1, entry)

	-- Cap the stack like Roblox's default bubble chat: only the most recent
	-- MAX_STACKED_BUBBLES messages stay visible; older ones get pushed out.
	while #stack.Queue > MAX_STACKED_BUBBLES do
		local oldest = table.remove(stack.Queue)
		destroyEntry(oldest)
	end

	repositionQueue(stack.Queue)
end)

--============================================================
-- Continuous distance-based visibility update
--============================================================

RunService.Heartbeat:Connect(function()
	local localCharacter = LocalPlayer.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

	for speaker, stack in pairs(characterStacks) do
		local character = stack.Character
		local speakerRoot = character and character:FindFirstChild("HumanoidRootPart")

		local distance = nil
		if localRoot and speakerRoot then
			distance = (speakerRoot.Position - localRoot.Position).Magnitude
		end

		-- Iterate backwards since entries may be removed (expired) mid-loop.
		for index = #stack.Queue, 1, -1 do
			local entry = stack.Queue[index]

			if os.clock() > entry.ExpireAt then
				removeEntry(stack, entry)
			elseif distance == nil then
				entry.Billboard.Enabled = false
			elseif distance <= NEAR_DISTANCE then
				entry.Billboard.Enabled = true
				if entry.Label.Text ~= entry.Text then
					entry.Label.Text = entry.Text
					resizeBubbleToText(entry.Billboard, entry.Text)
				end
			elseif distance <= FAR_DISTANCE then
				entry.Billboard.Enabled = true
				local inaudibleText = "[ Inaudible ]"
				if entry.Label.Text ~= inaudibleText then
					entry.Label.Text = inaudibleText
					resizeBubbleToText(entry.Billboard, inaudibleText)
				end
			else
				entry.Billboard.Enabled = false
			end
		end

		if #stack.Queue == 0 then
			characterStacks[speaker] = nil
		end
	end
end)
