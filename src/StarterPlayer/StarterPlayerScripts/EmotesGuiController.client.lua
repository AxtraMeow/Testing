--[[
        EmotesGuiController.client.lua

        Builds an R6-only emotes menu with paginated categories, similar in layout to a
        classic "emote wheel": a semi-transparent panel with 8 emote slots arranged
        clockwise around a center pagination control, letting the world show through.

        Emotes are defined in ReplicatedStorage/EmoteData.lua — see that file for how to
        add more emotes/pages.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local EmoteData = require(ReplicatedStorage:WaitForChild("EmoteData"))

-- Clockwise slot positions starting at the top, matching the order emotes are
-- listed for each page: Top, Top-Right, Mid-Right, Bottom-Right, Bottom,
-- Bottom-Left, Mid-Left, Top-Left.
local SLOT_POSITIONS = {
        UDim2.new(0.5, 0, 0.10, 0),
        UDim2.new(0.83, 0, 0.23, 0),
        UDim2.new(0.90, 0, 0.5, 0),
        UDim2.new(0.83, 0, 0.77, 0),
        UDim2.new(0.5, 0, 0.90, 0),
        UDim2.new(0.17, 0, 0.77, 0),
        UDim2.new(0.10, 0, 0.5, 0),
        UDim2.new(0.17, 0, 0.23, 0),
}

--============================================================
-- GUI construction
--============================================================

local emotesGui = Instance.new("ScreenGui")
emotesGui.Name = "EmotesGui"
emotesGui.ResetOnSpawn = false
emotesGui.Enabled = false
emotesGui.Parent = playerGui

-- Small always-visible toggle button
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "ToggleEmotesButton"
toggleButton.Size = UDim2.new(0, 110, 0, 40)
toggleButton.Position = UDim2.new(0, 16, 0, 16)
toggleButton.BackgroundColor3 = Color3.fromRGB(45, 130, 245)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 18
toggleButton.Text = "Emotes"
toggleButton.ZIndex = 2
toggleButton.Parent = emotesGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 8)
toggleCorner.Parent = toggleButton

-- Main panel (semi-transparent so the world shows through, like the reference image)
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.Size = UDim2.new(0, 620, 0, 620)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
panel.BackgroundTransparency = 0.35
panel.Parent = emotesGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.7
panelStroke.Thickness = 1.5
panelStroke.Parent = panel

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -12, 0, 12)
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Text = "X"
closeButton.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- Center pagination controls
local pageControls = Instance.new("Frame")
pageControls.Name = "PageControls"
pageControls.AnchorPoint = Vector2.new(0.5, 0.5)
pageControls.Position = UDim2.new(0.5, 0, 0.42, 0)
pageControls.Size = UDim2.new(0, 200, 0, 50)
pageControls.BackgroundTransparency = 1
pageControls.Parent = panel

local prevPageButton = Instance.new("TextButton")
prevPageButton.Name = "PrevPageButton"
prevPageButton.Size = UDim2.new(0, 44, 0, 44)
prevPageButton.Position = UDim2.new(0, 0, 0.5, -22)
prevPageButton.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
prevPageButton.TextColor3 = Color3.fromRGB(255, 255, 255)
prevPageButton.Font = Enum.Font.GothamBold
prevPageButton.TextSize = 22
prevPageButton.Text = "<"
prevPageButton.Parent = pageControls

local prevCorner = Instance.new("UICorner")
prevCorner.CornerRadius = UDim.new(0, 8)
prevCorner.Parent = prevPageButton

local pageNumberLabel = Instance.new("TextLabel")
pageNumberLabel.Name = "PageNumberLabel"
pageNumberLabel.Size = UDim2.new(0, 112, 0, 44)
pageNumberLabel.Position = UDim2.new(0.5, -56, 0.5, -22)
pageNumberLabel.BackgroundTransparency = 1
pageNumberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
pageNumberLabel.Font = Enum.Font.GothamBold
pageNumberLabel.TextSize = 26
pageNumberLabel.Text = "1"
pageNumberLabel.Parent = pageControls

local nextPageButton = Instance.new("TextButton")
nextPageButton.Name = "NextPageButton"
nextPageButton.Size = UDim2.new(0, 44, 0, 44)
nextPageButton.Position = UDim2.new(1, -44, 0.5, -22)
nextPageButton.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
nextPageButton.TextColor3 = Color3.fromRGB(255, 255, 255)
nextPageButton.Font = Enum.Font.GothamBold
nextPageButton.TextSize = 22
nextPageButton.Text = ">"
nextPageButton.Parent = pageControls

local nextCorner = Instance.new("UICorner")
nextCorner.CornerRadius = UDim.new(0, 8)
nextCorner.Parent = nextPageButton

local categoryLabel = Instance.new("TextLabel")
categoryLabel.Name = "CategoryLabel"
categoryLabel.AnchorPoint = Vector2.new(0.5, 0.5)
categoryLabel.Position = UDim2.new(0.5, 0, 0.52, 0)
categoryLabel.Size = UDim2.new(0, 320, 0, 30)
categoryLabel.BackgroundTransparency = 1
categoryLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
categoryLabel.Font = Enum.Font.GothamBold
categoryLabel.TextSize = 20
categoryLabel.Text = ""
categoryLabel.Parent = panel

-- Emote slot buttons (8 fixed positions, filled per-page)
local slots = {}
for i, slotPosition in ipairs(SLOT_POSITIONS) do
        local slot = Instance.new("Frame")
        slot.Name = "Slot" .. i
        slot.AnchorPoint = Vector2.new(0.5, 0.5)
        slot.Position = slotPosition
        slot.Size = UDim2.new(0, 130, 0, 90)
        slot.BackgroundTransparency = 1
        slot.Visible = false
        slot.Parent = panel

        local icon = Instance.new("TextButton")
        icon.Name = "Icon"
        icon.AnchorPoint = Vector2.new(0.5, 0)
        icon.Position = UDim2.new(0.5, 0, 0, 0)
        icon.Size = UDim2.new(0, 60, 0, 60)
        icon.BackgroundColor3 = Color3.fromRGB(230, 230, 230)
        icon.BackgroundTransparency = 0.15
        icon.AutoButtonColor = true
        icon.Text = ""
        icon.Parent = slot

        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(1, 0)
        iconCorner.Parent = icon

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "NameLabel"
        nameLabel.AnchorPoint = Vector2.new(0.5, 0)
        nameLabel.Position = UDim2.new(0.5, 0, 0, 64)
        nameLabel.Size = UDim2.new(1, 0, 0, 24)
        nameLabel.BackgroundTransparency = 1
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 16
        nameLabel.TextStrokeTransparency = 0.5
        nameLabel.Text = ""
        nameLabel.Parent = slot

        slots[i] = { Frame = slot, Icon = icon, NameLabel = nameLabel }
end

--============================================================
-- Emote playback (R6 only)
--============================================================

local currentTrack = nil

local function stopCurrentEmote()
        if currentTrack then
                currentTrack:Stop(0.15)
                currentTrack = nil
        end
end

local function playEmote(emoteInfo)
        local character = player.Character
        if not character then
                return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
                return
        end

        if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
                warn("[EmotesGui] This emote menu only supports R6 characters.")
                return
        end

        if not emoteInfo.AnimationId or emoteInfo.AnimationId == "" or emoteInfo.AnimationId == "rbxassetid://0" then
                warn(("[EmotesGui] '%s' has no AnimationId set yet — add one in EmoteData.lua"):format(emoteInfo.Name))
                return
        end

        stopCurrentEmote()

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
                animator = Instance.new("Animator")
                animator.Parent = humanoid
        end

        local animation = Instance.new("Animation")
        animation.AnimationId = emoteInfo.AnimationId

        local track = animator:LoadAnimation(animation)
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = emoteInfo.Looped ~= false
        track:Play(0.15)

        currentTrack = track
end

-- Stop the emote automatically if the player starts moving, jumping, etc.
local function hookMovementCancel(character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
                return
        end

        humanoid.Running:Connect(function(speed)
                if speed > 0.5 then
                        stopCurrentEmote()
                end
        end)

        humanoid.Jumping:Connect(stopCurrentEmote)
        humanoid.Seated:Connect(function(isSeated)
                if isSeated then
                        stopCurrentEmote()
                end
        end)
end

if player.Character then
        hookMovementCancel(player.Character)
end
player.CharacterAdded:Connect(function(character)
        stopCurrentEmote()
        hookMovementCancel(character)
end)

--============================================================
-- Pagination / rendering
--============================================================

local currentPageIndex = 1

-- Rebuild slot click connections cleanly each render (avoids stacking duplicate
-- connections when flipping pages back and forth).
local slotConnections = {}

local function clearSlotConnections()
        for _, connection in ipairs(slotConnections) do
                connection:Disconnect()
        end
        slotConnections = {}
end

local function renderPageSafe()
        clearSlotConnections()

        local page = EmoteData[currentPageIndex]
        if not page then
                return
        end

        pageNumberLabel.Text = tostring(currentPageIndex)
        categoryLabel.Text = page.Name

        for i, slot in ipairs(slots) do
                local emoteInfo = page.Emotes[i]
                if emoteInfo then
                        slot.Frame.Visible = true
                        slot.NameLabel.Text = emoteInfo.Name

                        local connection = slot.Icon.MouseButton1Click:Connect(function()
                                playEmote(emoteInfo)
                        end)
                        table.insert(slotConnections, connection)
                else
                        slot.Frame.Visible = false
                        slot.NameLabel.Text = ""
                end
        end
end

prevPageButton.MouseButton1Click:Connect(function()
        currentPageIndex = currentPageIndex - 1
        if currentPageIndex < 1 then
                currentPageIndex = #EmoteData
        end
        renderPageSafe()
end)

nextPageButton.MouseButton1Click:Connect(function()
        currentPageIndex = currentPageIndex + 1
        if currentPageIndex > #EmoteData then
                currentPageIndex = 1
        end
        renderPageSafe()
end)

--============================================================
-- Open / close
--============================================================

toggleButton.MouseButton1Click:Connect(function()
        emotesGui.Enabled = not emotesGui.Enabled
end)

closeButton.MouseButton1Click:Connect(function()
        emotesGui.Enabled = false
end)

-- Press "R" to toggle the emotes menu open/closed.
-- Bound via ContextActionService at High priority (and Sink the input) so the
-- default chat bar (which auto-captures letter keys like R to start typing a
-- message) never gets a chance to steal the keypress first.
local function onToggleEmotesAction(_actionName, inputState)
        if inputState == Enum.UserInputState.Begin then
                emotesGui.Enabled = not emotesGui.Enabled
        end
        return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
        "ToggleEmotesMenu",
        onToggleEmotesAction,
        false,
        Enum.ContextActionPriority.High.Value,
        Enum.KeyCode.R
)

renderPageSafe()
