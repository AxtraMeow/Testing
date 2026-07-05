--[[
        CustomChatWindow.client.lua

        Fully custom chat window UI, replacing Roblox's default chat window:
                - Small icon row (chat toggle, menu, notifications) above a rounded,
                  semi-transparent input bar, similar to a minimal modern HUD chat.
                - Clicking/focusing the input bar lets you type and send a message.
                - Clicking the chat icon toggles a scrollable recent-message log.
                - Messages sent here flow through TextChatService like normal, so the
                  proximity-based chat bubbles (ProximityBubbleChat.client.lua) still work.

        The default TextChatService chat window is disabled so only this custom UI
        is shown.
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local ContextActionService = game:GetService("ContextActionService")

local LocalPlayer = Players.LocalPlayer
local playerGui = LocalPlayer:WaitForChild("PlayerGui")

--============================================================
-- Fully disable Roblox's default chat (window, input bar, and the topbar
-- chat icon), keeping only the underlying TextChatService pipeline (channels,
-- filtering/moderation, MessageReceived, etc.) so it can drive our own UI.
--============================================================

local chatWindowConfiguration = TextChatService:FindFirstChild("ChatWindowConfiguration")
if chatWindowConfiguration then
        chatWindowConfiguration.Enabled = false
end

local chatInputBarConfiguration = TextChatService:FindFirstChild("ChatInputBarConfiguration")
if chatInputBarConfiguration then
        chatInputBarConfiguration.Enabled = false
end

-- Removes the default chat icon/window from the top bar as well, so no trace
-- of the built-in chat UI remains on screen.
pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)

--============================================================
-- Root GUI
--============================================================

local chatGui = Instance.new("ScreenGui")
chatGui.Name = "CustomChatUI"
chatGui.ResetOnSpawn = false
chatGui.IgnoreGuiInset = false
chatGui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0, 1)
root.Position = UDim2.new(0, 16, 1, -16)
root.Size = UDim2.new(0, 260, 0, 76)
root.BackgroundTransparency = 1
root.Parent = chatGui

--============================================================
-- Icon row (chat toggle / menu / notifications)
--============================================================

local iconRow = Instance.new("Frame")
iconRow.Name = "IconRow"
iconRow.Size = UDim2.new(0, 96, 0, 26)
iconRow.Position = UDim2.new(0, 4, 0, 0)
iconRow.BackgroundTransparency = 1
iconRow.Parent = root

local iconLayout = Instance.new("UIListLayout")
iconLayout.FillDirection = Enum.FillDirection.Horizontal
iconLayout.Padding = UDim.new(0, 8)
iconLayout.VerticalAlignment = Enum.VerticalAlignment.Center
iconLayout.Parent = iconRow

local function createIconButton(name)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.new(0, 26, 0, 26)
        button.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        button.BackgroundTransparency = 0.35
        button.AutoButtonColor = true
        button.Text = ""
        button.Parent = iconRow

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = button

        return button
end

-- Chat bubble icon (toggles the recent-message log)
local chatIconButton = createIconButton("ChatIcon")

local chatIconGlyph = Instance.new("Frame")
chatIconGlyph.Name = "Glyph"
chatIconGlyph.AnchorPoint = Vector2.new(0.5, 0.5)
chatIconGlyph.Position = UDim2.new(0.5, 0, 0.45, 0)
chatIconGlyph.Size = UDim2.new(0, 14, 0, 11)
chatIconGlyph.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
chatIconGlyph.BackgroundTransparency = 0.05
chatIconGlyph.Parent = chatIconButton

local chatIconGlyphCorner = Instance.new("UICorner")
chatIconGlyphCorner.CornerRadius = UDim.new(0, 4)
chatIconGlyphCorner.Parent = chatIconGlyph

local chatIconTail = Instance.new("Frame")
chatIconTail.Name = "Tail"
chatIconTail.AnchorPoint = Vector2.new(0.5, 0)
chatIconTail.Position = UDim2.new(0.3, 0, 1, -2)
chatIconTail.Size = UDim2.new(0, 6, 0, 6)
chatIconTail.Rotation = 45
chatIconTail.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
chatIconTail.BackgroundTransparency = 0.05
chatIconTail.ZIndex = 0
chatIconTail.Parent = chatIconButton

-- Menu icon (hamburger, decorative placeholder)
local menuIconButton = createIconButton("MenuIcon")

local menuLayout = Instance.new("UIListLayout")
menuLayout.FillDirection = Enum.FillDirection.Vertical
menuLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
menuLayout.VerticalAlignment = Enum.VerticalAlignment.Center
menuLayout.Padding = UDim.new(0, 3)
menuLayout.Parent = menuIconButton

for i = 1, 3 do
        local bar = Instance.new("Frame")
        bar.Name = "Bar" .. i
        bar.Size = UDim2.new(0, 14, 0, 2)
        bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bar.BackgroundTransparency = 0.05
        bar.BorderSizePixel = 0
        bar.Parent = menuIconButton

        local barCorner = Instance.new("UICorner")
        barCorner.CornerRadius = UDim.new(1, 0)
        barCorner.Parent = bar
end

-- Notifications icon (bell, decorative placeholder)
local bellIconButton = createIconButton("NotificationsIcon")

local bellBody = Instance.new("Frame")
bellBody.Name = "Body"
bellBody.AnchorPoint = Vector2.new(0.5, 0.5)
bellBody.Position = UDim2.new(0.5, 0, 0.42, 0)
bellBody.Size = UDim2.new(0, 12, 0, 11)
bellBody.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
bellBody.BackgroundTransparency = 0.05
bellBody.Parent = bellIconButton

local bellBodyCorner = Instance.new("UICorner")
bellBodyCorner.CornerRadius = UDim.new(1, 0)
bellBodyCorner.Parent = bellBody

local bellClapper = Instance.new("Frame")
bellClapper.Name = "Clapper"
bellClapper.AnchorPoint = Vector2.new(0.5, 0)
bellClapper.Position = UDim2.new(0.5, 0, 0.78, 0)
bellClapper.Size = UDim2.new(0, 4, 0, 4)
bellClapper.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
bellClapper.BackgroundTransparency = 0.05
bellClapper.Parent = bellIconButton

local bellClapperCorner = Instance.new("UICorner")
bellClapperCorner.CornerRadius = UDim.new(1, 0)
bellClapperCorner.Parent = bellClapper

--============================================================
-- Recent-message log (toggled by the chat icon)
--============================================================

local logFrame = Instance.new("Frame")
logFrame.Name = "MessageLog"
logFrame.AnchorPoint = Vector2.new(0, 1)
logFrame.Position = UDim2.new(0, 0, 0, -8)
logFrame.Size = UDim2.new(0, 260, 0, 160)
logFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
logFrame.BackgroundTransparency = 0.4
logFrame.Visible = false
logFrame.Parent = root

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 10)
logCorner.Parent = logFrame

local logScroll = Instance.new("ScrollingFrame")
logScroll.Name = "Scroll"
logScroll.Size = UDim2.new(1, -12, 1, -12)
logScroll.Position = UDim2.new(0, 6, 0, 6)
logScroll.BackgroundTransparency = 1
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 4
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.Parent = logFrame

local logListLayout = Instance.new("UIListLayout")
logListLayout.FillDirection = Enum.FillDirection.Vertical
logListLayout.Padding = UDim.new(0, 2)
logListLayout.SortOrder = Enum.SortOrder.LayoutOrder
logListLayout.Parent = logScroll

local MAX_LOG_MESSAGES = 50

local function appendLogMessage(speakerName, text)
        local row = Instance.new("TextLabel")
        row.Name = "Message"
        row.Size = UDim2.new(1, 0, 0, 0)
        row.AutomaticSize = Enum.AutomaticSize.Y
        row.BackgroundTransparency = 1
        row.TextColor3 = Color3.fromRGB(255, 255, 255)
        row.TextWrapped = true
        row.Font = Enum.Font.Gotham
        row.TextSize = 14
        row.TextXAlignment = Enum.TextXAlignment.Left
        row.RichText = true
        row.Text = string.format('<b>%s:</b> %s', speakerName, text)
        row.LayoutOrder = os.time()
        row.Parent = logScroll

        while #logScroll:GetChildren() - 1 > MAX_LOG_MESSAGES do
                local oldest = logScroll:FindFirstChildOfClass("TextLabel")
                if oldest then
                        oldest:Destroy()
                else
                        break
                end
        end
end

chatIconButton.MouseButton1Click:Connect(function()
        logFrame.Visible = not logFrame.Visible
end)

--============================================================
-- Input bar (styled like the reference image)
--============================================================

local inputBar = Instance.new("Frame")
inputBar.Name = "InputBar"
inputBar.AnchorPoint = Vector2.new(0, 1)
inputBar.Position = UDim2.new(0, 0, 1, 0)
inputBar.Size = UDim2.new(0, 260, 0, 34)
inputBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
inputBar.BackgroundTransparency = 0.45
inputBar.Parent = root

local inputBarCorner = Instance.new("UICorner")
inputBarCorner.CornerRadius = UDim.new(1, 0)
inputBarCorner.Parent = inputBar

local inputBox = Instance.new("TextBox")
inputBox.Name = "InputBox"
inputBox.Size = UDim2.new(1, -24, 1, -6)
inputBox.Position = UDim2.new(0, 14, 0, 3)
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

--============================================================
-- Populate the log with incoming messages
--============================================================

TextChatService.MessageReceived:Connect(function(textChatMessage)
        local textSource = textChatMessage.TextSource
        local speakerName = "System"

        if textSource then
                local speaker = Players:GetPlayerByUserId(textSource.UserId)
                if speaker then
                        speakerName = speaker.Name
                end
        end

        appendLogMessage(speakerName, textChatMessage.Text)
end)
