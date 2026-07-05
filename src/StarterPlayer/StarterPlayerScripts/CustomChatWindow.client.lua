--[[
	CustomChatWindow.client.lua

	Minimal custom chat input — this is intentionally just a typing box, with no
	visible message log/history, so no one can read anyone else's past chat
	messages from a UI panel. The only place chat text is ever shown is the
	proximity-limited speech bubble above each character's head
	(see ProximityBubbleChat.client.lua), which already gates visibility by
	distance.

	Positioned where Roblox's default chat input used to sit (bottom-left,
	just above the hotbar).

	Roblox's default chat window/input bar/topbar icon are disabled so only
	this custom input box is shown; the underlying TextChatService pipeline
	(channels, filtering/moderation, replication) is left fully intact.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

--============================================================
-- Fully disable Roblox's default chat (window, input bar, and the topbar
-- chat icon), keeping only the underlying TextChatService pipeline.
--============================================================

local chatWindowConfiguration = TextChatService:FindFirstChild("ChatWindowConfiguration")
if chatWindowConfiguration then
	chatWindowConfiguration.Enabled = false
end

local chatInputBarConfiguration = TextChatService:FindFirstChild("ChatInputBarConfiguration")
if chatInputBarConfiguration then
	chatInputBarConfiguration.Enabled = false
end

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)

--============================================================
-- Input bar (positioned where the default chat box used to be)
--============================================================

local chatGui = Instance.new("ScreenGui")
chatGui.Name = "CustomChatUI"
chatGui.ResetOnSpawn = false
chatGui.IgnoreGuiInset = false
chatGui.Parent = playerGui

local inputBar = Instance.new("Frame")
inputBar.Name = "InputBar"
inputBar.AnchorPoint = Vector2.new(0, 1)
inputBar.Position = UDim2.new(0, 12, 1, -46)
inputBar.Size = UDim2.new(0, 280, 0, 32)
inputBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
inputBar.BackgroundTransparency = 0.45
inputBar.Parent = chatGui

local inputBarCorner = Instance.new("UICorner")
inputBarCorner.CornerRadius = UDim.new(0, 8)
inputBarCorner.Parent = inputBar

local inputBox = Instance.new("TextBox")
inputBox.Name = "InputBox"
inputBox.Size = UDim2.new(1, -20, 1, -6)
inputBox.Position = UDim2.new(0, 10, 0, 3)
inputBox.BackgroundTransparency = 1
inputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
inputBox.PlaceholderText = "Say something to chat..."
inputBox.PlaceholderColor3 = Color3.fromRGB(190, 190, 190)
inputBox.Font = Enum.Font.Gotham
inputBox.TextSize = 14
inputBox.TextXAlignment = Enum.TextXAlignment.Left
inputBox.ClearTextOnFocus = false
inputBox.Text = ""
inputBox.Parent = inputBar

--============================================================
-- Sending messages
--============================================================

local function getGeneralTextChannel()
	local textChannels = TextChatService:WaitForChild("TextChannels")
	return textChannels:WaitForChild("RBXGeneral")
end

local generalChannel = getGeneralTextChannel()

local function sendCurrentMessage()
	local text = inputBox.Text
	if text and #text:gsub("%s", "") > 0 then
		generalChannel:SendAsync(text)
	end
	inputBox.Text = ""
end

inputBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		sendCurrentMessage()
	end
end)

-- Focus the input bar with Enter or "/", like default Roblox chat, without
-- letting any other system swallow the keystroke first.
local function onFocusChatAction(_actionName, inputState)
	if inputState == Enum.UserInputState.Begin then
		if not inputBox:IsFocused() then
			inputBox:CaptureFocus()
		end
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
	"FocusCustomChatInput",
	onFocusChatAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.Slash,
	Enum.KeyCode.Return
)
