--[[
	EmoteData.lua

	This is where you register emotes for the Emotes GUI.
	R6 ONLY: every AnimationId here must be an animation authored/exported for the R6 rig.

	HOW TO ADD A NEW EMOTE:
		1. Upload/own the animation on Roblox and copy its Asset Id.
		2. Add a new entry to the "Emotes" list of any page below, e.g.:
			{ Name = "Wave", AnimationId = "rbxassetid://1234567890" }
		3. That's it — the GUI automatically places it in the next open slot.

	HOW TO ADD A NEW PAGE:
		Just add another table to the top-level list, following the same shape:
			{
				Name = "My New Category",
				Emotes = { ... up to 8 emotes ... },
			}

	NOTE: Each page supports up to 8 emote slots, laid out clockwise starting at the
	top (Top, Top-Right, Mid-Right, Bottom-Right, Bottom, Bottom-Left, Mid-Left, Top-Left),
	matching the order emotes are listed in the "Emotes" table. Looping is on by default
	since these are meant to be held poses — set Looped = false on an emote entry if you
	want a one-shot animation instead.
]]

return {
	{
		Name = "Standing / Poses",
		Emotes = {
			{ Name = "Salute", AnimationId = "rbxassetid://0" },
			{ Name = "Cross Arms", AnimationId = "rbxassetid://0" },
			{ Name = "Back Cross", AnimationId = "rbxassetid://0" },
			{ Name = "Scratch Head", AnimationId = "rbxassetid://0" },
			{ Name = "Thinking", AnimationId = "rbxassetid://0" },
			{ Name = "Surrender", AnimationId = "rbxassetid://0" },
			{ Name = "Shrug 1", AnimationId = "rbxassetid://0" },
			{ Name = "Shrug 2", AnimationId = "rbxassetid://0" },
		},
	},

	{
		Name = "Dances",
		Emotes = {
			-- Add dance emotes here using the same pattern, for example:
			-- { Name = "Dance 1", AnimationId = "rbxassetid://0000000" },
		},
	},
}
