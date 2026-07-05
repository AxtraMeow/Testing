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

local FONT = Enum.Font.Gotham
local TEXT_SIZE = 14
local MIN_BUBBLE_WIDTH = 46
local MAX_BUBBLE_WIDTH = 180
local HORIZONTAL_PADDING = 20
local VERTICAL_PADDING = 14
local LINE_HEIGHT = 16

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
        billboard.StudsOffsetWorldSpace = Vector3.new(0, 0.9, 0)
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
        backgroundCorner.CornerRadius = UDim.new(1, 0)
        backgroundCorner.Parent = background

        -- Small pointer tail: a rotated square whose top half hides behind the
        -- bubble background (lower ZIndex), leaving only the bottom point visible.
        local tail = Instance.new("Frame")
        tail.Name = "Tail"
        tail.AnchorPoint = Vector2.new(0.5, 0.5)
        tail.Position = UDim2.new(0.5, 0, 1, 0)
        tail.Size = UDim2.new(0, 12, 0, 12)
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

-- Only re-measures/resizes the bubble when the displayed text actually changes
-- (full message <-> "[ Inaudible ]"), avoiding unnecessary work every frame.
local function setBubbleText(data, text)
        if data.Label.Text == text then
                return
        end
        data.Label.Text = text
        resizeBubbleToText(data.Billboard, text)
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

        resizeBubbleToText(billboard, textChatMessage.Text)

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
                                        setBubbleText(data, data.Text)
                                elseif distance <= FAR_DISTANCE then
                                        data.Billboard.Enabled = true
                                        setBubbleText(data, "[ Inaudible ]")
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
