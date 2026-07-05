-- GuiController.client.lua
-- Creates a simple GUI with a button. Clicking the button opens a second GUI.

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== First GUI: contains the "Open" button =====
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "MainGui"
mainGui.ResetOnSpawn = false
mainGui.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Name = "OpenButton"
openButton.Size = UDim2.new(0, 160, 0, 50)
openButton.Position = UDim2.new(0.5, -80, 0.1, 0)
openButton.BackgroundColor3 = Color3.fromRGB(45, 130, 245)
openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openButton.Font = Enum.Font.GothamBold
openButton.TextSize = 20
openButton.Text = "Open"
openButton.Parent = mainGui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 10)
openCorner.Parent = openButton

-- ===== Second GUI: shown when the button is clicked =====
local secondGui = Instance.new("ScreenGui")
secondGui.Name = "SecondGui"
secondGui.ResetOnSpawn = false
secondGui.Enabled = false
secondGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Panel"
frame.Size = UDim2.new(0, 320, 0, 220)
frame.Position = UDim2.new(0.5, -160, 0.5, -110)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
frame.Parent = secondGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 14)
frameCorner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "Second GUI"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = frame

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 120, 0, 40)
closeButton.Position = UDim2.new(0.5, -60, 1, -60)
closeButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Text = "Close"
closeButton.Parent = frame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 10)
closeCorner.Parent = closeButton

-- ===== Behavior =====
openButton.MouseButton1Click:Connect(function()
	secondGui.Enabled = true
end)

closeButton.MouseButton1Click:Connect(function()
	secondGui.Enabled = false
end)
