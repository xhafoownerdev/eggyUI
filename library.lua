local cloneref = cloneref or function(o) return o end
local gethui = gethui or function()
	return cloneref(game:GetService("CoreGui"))
end
local _getmouse = getmouse
local getmouse = _getmouse and cloneref(_getmouse) or nil

local game = cloneref(game)

local UserInputService   = cloneref(game:GetService("UserInputService"))
local TweenService       = cloneref(game:GetService("TweenService"))
local RunService         = cloneref(game:GetService("RunService"))
local Players            = cloneref(game:GetService("Players"))
local GuiService         = cloneref(game:GetService("GuiService"))
local HttpService        = cloneref(game:GetService("HttpService"))
local CoreGui            = cloneref(game:GetService("CoreGui"))
local StarterGui         = cloneref(game:GetService("StarterGui"))
local MarketplaceService = cloneref(game:GetService("MarketplaceService"))
local Lighting           = cloneref(game:GetService("Lighting"))
local TextService        = cloneref(game:GetService("TextService"))

local LocalPlayer = cloneref(Players.LocalPlayer)

local function getMouseLocation()
	if getmouse then
		local ok, m = pcall(getmouse)
		if ok and m then
			m = cloneref(m)
			return Vector2.new(m.X, m.Y)
		end
	end
	return UserInputService:GetMouseLocation()
end

local Theme = {
	-- surfaces
	Header        = Color3.fromRGB(10, 18, 20),
	HeaderTab     = Color3.fromRGB(24, 40, 44),
	Footer        = Color3.fromRGB(11, 19, 21),
	Background    = Color3.fromRGB(14, 24, 27),
	Sidebar       = Color3.fromRGB(16, 28, 31),
	SubTabActive  = Color3.fromRGB(28, 48, 52),
	Groupbox      = Color3.fromRGB(20, 34, 38),
	GroupboxLine  = Color3.fromRGB(38, 58, 64),
	Element       = Color3.fromRGB(26, 42, 46),
	ElementBorder = Color3.fromRGB(48, 72, 78),

	-- accents
	Accent        = Color3.fromRGB(102, 224, 208),
	AccentDim     = Color3.fromRGB(56, 155, 145),

	-- body text
	Text          = Color3.fromRGB(220, 230, 232),
	TextDim       = Color3.fromRGB(130, 155, 160),
	TextDark      = Color3.fromRGB(80, 100, 105),

	-- "Blurred" wordmark (window logo + watermark brand)
	BrandText     = Color3.fromRGB(245, 250, 252),
	BrandAccent   = Color3.fromRGB(90, 236, 220),

	-- top tabs
	TabActive     = Color3.fromRGB(108, 228, 214),
	TabInactive   = Color3.fromRGB(128, 128, 128),
	TabHover      = Color3.fromRGB(170, 200, 205),

	-- general + sub-tab text
	Hover         = Color3.fromRGB(200, 214, 218),
	SubTabText    = Color3.fromRGB(132, 157, 162),
	SubTabTextActive = Color3.fromRGB(96, 230, 214),

	-- watermark content (FPS / game) Ã¢â‚¬â€ separate from brand wordmark
	WatermarkText    = Color3.fromRGB(218, 228, 230),
	WatermarkTextDim = Color3.fromRGB(120, 148, 154),

	-- keybind list
	KeybindTitle    = Color3.fromRGB(226, 234, 236),
	KeybindText     = Color3.fromRGB(208, 220, 222),
	KeybindTextDim  = Color3.fromRGB(118, 118, 120),
	KeybindActive   = Color3.fromRGB(88, 220, 205),
}

-- frozen copy of the built-in Default; never mutated by presets / disk / configs
local DefaultTheme = {}
for key, color in pairs(Theme) do
	DefaultTheme[key] = color
end

local function Create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		inst[k] = v
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function Corner(radius, parent)
	return Create("UICorner", { CornerRadius = UDim.new(0, radius or 4), Parent = parent })
end

local function Stroke(color, thickness, parent)
	return Create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function Padding(px, parent)
	return Create("UIPadding", {
		PaddingLeft   = UDim.new(0, px),
		PaddingRight  = UDim.new(0, px),
		PaddingTop    = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		Parent = parent,
	})
end

-- Global animation settings -- every Tween() in the library goes through
-- these. SpeedScale multiplies durations (0.5 = twice as fast, 2 = slower);
-- Style / Direction override the easing for all UI tweens.
-- TargetFPS caps theme flushes + manual RenderStepped loops (drag, etc.).
local Anim = {
	SpeedScale = 1.5,
	Style      = Enum.EasingStyle.Quart,
	Direction  = Enum.EasingDirection.Out,
	TargetFPS  = 240,
}

local function frameInterval()
	return 1 / (Anim.TargetFPS or 240)
end

-- RenderStepped connection that runs at most TargetFPS times per second.
local function connectCapped(callback)
	local acc = 0
	return RunService.RenderStepped:Connect(function(dt)
		acc += dt
		local step = frameInterval()
		if acc < step then return end
		-- drop backlog so we never catch up with a burst of updates
		acc = acc % step
		callback(step)
	end)
end

local function Tween(inst, time, props, style)
	local t = TweenService:Create(inst,
		TweenInfo.new((time or 0.12) * Anim.SpeedScale, style or Anim.Style, Anim.Direction),
		props)
	t:Play()
	return t
end

-- soft bloom used by toggles / sliders (assigned after asset cache is ready)
local GLOW_IMAGE
local BLOOM_ASSET_ID = 5028857084

local function MakeGlow(parent, opts)
	opts = opts or {}
	local host = Create("Frame", {
		Name = "Bloom",
		Parent = parent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = math.max(0, (parent.ZIndex or 1) - 1),
		Active = false,
		Interactable = false,
	})
	host:SetAttribute("_noFade", true)

	local scaleType = opts.ScaleType or Enum.ScaleType.Fit
	local layers = {}
	local specs = opts.Specs or {
		{ pad = 10, off = 0.28 },
		{ pad = 22, off = 0.48 },
		{ pad = 38, off = 0.68 },
	}
	for i, spec in ipairs(specs) do
		local glowProps = {
			Name = "Layer" .. i,
			Parent = host,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = GLOW_IMAGE,
			ImageColor3 = opts.Color or Theme.Accent,
			ImageTransparency = opts.Transparency ~= nil and opts.Transparency or 1,
			ScaleType = scaleType,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, spec.pad * 2, 1, spec.pad * 2),
			ZIndex = host.ZIndex,
			Active = false,
			Interactable = false,
		}
		if scaleType == Enum.ScaleType.Slice then
			glowProps.SliceCenter = Rect.new(Vector2.new(21, 21), Vector2.new(79, 79))
		end
		local glow = Create("ImageLabel", glowProps)
		glow:SetAttribute("_bloomOff", spec.off)
		glow:SetAttribute("_noFade", true)
		glow:SetAttribute("_shownCached", true)
		glow:SetAttribute("_shown_ImageTransparency", glow.ImageTransparency)
		layers[i] = glow
	end

	local bloom = { Host = host, Layers = layers }
	function bloom.Set(on, intensity)
		intensity = intensity or 1
		for _, glow in ipairs(layers) do
			local off = glow:GetAttribute("_bloomOff") or 0.5
			local target = on and math.clamp(off / intensity, 0, 0.92) or 1
			Tween(glow, 0.14, { ImageTransparency = target, ImageColor3 = Theme.Accent })
			glow:SetAttribute("_shown_ImageTransparency", target)
		end
	end
	if opts.On ~= nil then bloom.Set(opts.On, opts.Intensity) end
	return bloom
end

local function SetGlow(bloom, on, intensity)
	if type(bloom) == "table" and bloom.Set then
		bloom.Set(on, intensity)
	end
end

local FadeProps = {
	TextLabel   = { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" },
	TextButton  = { "TextTransparency", "TextStrokeTransparency", "BackgroundTransparency" },
	TextBox     = { "TextTransparency", "BackgroundTransparency" },
	ImageLabel  = { "ImageTransparency", "BackgroundTransparency" },
	ImageButton = { "ImageTransparency", "BackgroundTransparency" },
	Frame       = { "BackgroundTransparency" },
	ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
	UIStroke    = { "Transparency" },
}

local function cacheShown(root)
	for _, d in ipairs(root:GetDescendants()) do
		local props = FadeProps[d.ClassName]
		if props and d:GetAttribute("_noFade") == nil and d:GetAttribute("_shownCached") == nil then
			for _, p in ipairs(props) do
				local ok, v = pcall(function() return d[p] end)
				if ok then d:SetAttribute("_shown_" .. p, v) end
			end
			d:SetAttribute("_shownCached", true)
		end
	end
end

local function fadePage(root, fadeIn, time)
	time = time or 0.16
	cacheShown(root)
	for _, d in ipairs(root:GetDescendants()) do
		local props = FadeProps[d.ClassName]
		if props and d:GetAttribute("_noFade") == nil then
			local goal = {}
			for _, p in ipairs(props) do
				if fadeIn then
					local cached = d:GetAttribute("_shown_" .. p)
					goal[p] = (cached ~= nil) and cached or 0
				else
					goal[p] = 1
				end
			end
			TweenService:Create(d,
				TweenInfo.new(time * Anim.SpeedScale, Anim.Style, Anim.Direction),
				goal):Play()
		end
	end
end

local Library = {}
Library.__index = Library
Library.Theme = Theme
Library.Anim = Anim          -- animation settings (SpeedScale / Style / Direction)
Library.Windows = {}
Library.Flags = {}          -- flag -> value store
Library.FlagSetters = {}    -- flag -> Set function (used by the config system)
Library.FlagDefaults = {}   -- flag -> default value (reset missing flags on config load)
Library.Toggled = true
Library.OpenDropdown = nil   -- the currently-open dropdown (only one at a time)
Library.OpenColorPicker = nil -- the currently-open colorpicker popup (only one at a time)
Library.OpenKeybindMenu = nil -- the currently-open keybind activation-mode menu
Library.CopiedColor = nil -- colorpicker copy/paste clipboard { Color, Alpha }

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
	and input.UserInputType ~= Enum.UserInputType.MouseButton2
	and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if gameProcessed then return end
	if Library.OpenDropdown then Library.OpenDropdown.Close() end
	if Library.OpenColorPicker then Library.OpenColorPicker.Close() end
	if Library.OpenKeybindMenu then Library.OpenKeybindMenu.CloseMenu() end
end)

Library.Folders = {
	Root    = "blurred",
	Assets  = "blurred/assets",
	Icons   = "blurred/assets/icons",
	Fonts   = "blurred/assets/fonts",
	Configs = "blurred/configs",
	Themes  = "blurred/themes",
}
do
	local function ensure(path)
		if makefolder and (not isfolder or not isfolder(path)) then
			pcall(makefolder, path)
		end
	end
	ensure(Library.Folders.Root)
	ensure(Library.Folders.Assets)
	ensure(Library.Folders.Icons)
	ensure(Library.Folders.Fonts)
	ensure(Library.Folders.Configs)
	ensure(Library.Folders.Themes)
end

-- Download/cache helpers. Image assets prefer storing the numeric id on disk
-- and using rbxassetid:// (Roblox CDN), because assetdelivery binaries often
-- aren't valid for getcustomasset as .png.
local function extractAssetId(ref)
	if ref == nil then return nil end
	if type(ref) == "number" then return tostring(math.floor(ref)) end
	if type(ref) ~= "string" then return nil end
	return string.match(ref, "(%d+)")
end

local function hasFs()
	return writefile ~= nil and readfile ~= nil and isfile ~= nil
end

local function readIdFile(path)
	if not (hasFs() and isfile(path)) then return nil end
	local ok, data = pcall(readfile, path)
	if not ok or type(data) ~= "string" then return nil end
	return string.match(data, "(%d+)")
end

local function writeIdFile(path, id)
	if hasFs() and writefile and id then
		pcall(writefile, path, tostring(id))
	end
end

local function GetCachedAsset(assetRef, fileName)
	local id = extractAssetId(assetRef)
	local idPath = Library.Folders.Assets .. "/" .. fileName .. ".id"
	local binPath = Library.Folders.Assets .. "/" .. fileName

	-- prefer previously saved id
	local stored = readIdFile(idPath)
	if stored then id = stored end
	if id then writeIdFile(idPath, id) end

	-- optional binary cache via getcustomasset (glow, etc.)
	if id and hasFs() and getcustomasset then
		local function tryCustom()
			if not isfile(binPath) then return nil end
			local ok, result = pcall(getcustomasset, binPath)
			if ok and type(result) == "string" and result ~= "" then
				return result
			end
			return nil
		end
		local custom = tryCustom()
		if custom then return custom end

		local urls = {
			"https://assetdelivery.roblox.com/v1/asset/?id=" .. id,
			"https://www.roblox.com/asset/?id=" .. id,
		}
		for _, url in ipairs(urls) do
			local ok, data = pcall(function() return game:HttpGet(url) end)
			if ok and type(data) == "string" and #data > 32 then
				-- skip XML/HTML error pages
				local head = string.sub(data, 1, 64):lower()
				if not string.find(head, "<?xml", 1, true)
					and not string.find(head, "<html", 1, true)
					and not string.find(head, "<!doctype", 1, true)
					and not string.find(head, "<roblox", 1, true) then
					pcall(writefile, binPath, data)
					custom = tryCustom()
					if custom then return custom end
				end
			end
		end
	end

	if id then return "rbxassetid://" .. id end
	return type(assetRef) == "string" and assetRef or nil
end

Library.GetCachedAsset = GetCachedAsset
GLOW_IMAGE = GetCachedAsset(BLOOM_ASSET_ID, "bloom.png")
Library.BloomImage = GLOW_IMAGE

-- Download a remote URL once into blurred/assets, then load via getcustomasset.
local function GetCachedUrl(url, fileName)
	local path = Library.Folders.Assets .. "/" .. fileName
	if hasFs() and isfile(path) and getcustomasset then
		local ok, result = pcall(getcustomasset, path)
		if ok and type(result) == "string" and result ~= "" then
			return result
		end
	end
	if hasFs() and writefile and url then
		local ok, data = pcall(function() return game:HttpGet(url) end)
		if ok and type(data) == "string" and #data > 32 then
			pcall(writefile, path, data)
			if getcustomasset then
				local ok2, result = pcall(getcustomasset, path)
				if ok2 and type(result) == "string" and result ~= "" then
					return result
				end
			end
		end
	end
	return url
end

Library.GetCachedUrl = GetCachedUrl

--============================================================
--// THEME EDITING (realtime)
--   SetThemeColor swaps every GUI property that currently uses
--   the old color for the new one. Swaps are batched and flushed
--   on RenderStepped at up to Anim.TargetFPS (default 240).
--============================================================
-- known classes -> the color properties we theme (avoids pcall spam)
local CLASS_COLOR_PROPS = {
	Frame          = { "BackgroundColor3" },
	CanvasGroup    = { "BackgroundColor3" },
	TextLabel      = { "BackgroundColor3", "TextColor3" },
	TextButton     = { "BackgroundColor3", "TextColor3" },
	TextBox        = { "BackgroundColor3", "TextColor3", "PlaceholderColor3" },
	ImageLabel     = { "BackgroundColor3", "ImageColor3" },
	ImageButton    = { "BackgroundColor3", "ImageColor3" },
	ScrollingFrame = { "BackgroundColor3", "ScrollBarImageColor3" },
	UIStroke       = { "Color" },
}

local function packColor(c)
	return math.floor(c.R * 255 + 0.5) * 65536
	     + math.floor(c.G * 255 + 0.5) * 256
	     + math.floor(c.B * 255 + 0.5)
end

local pendingSwaps = {}     -- key -> { old = displayed color, new = target }
local flushScheduled = false
local lastFlushClock = 0

-- "Blurred" wordmark: accent B, white lurred (always)
local function colorRgbTag(c)
	return string.format("rgb(%d,%d,%d)",
		math.floor(c.R * 255 + 0.5),
		math.floor(c.G * 255 + 0.5),
		math.floor(c.B * 255 + 0.5))
end

local function textAccentGradient()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.BrandText),
		ColorSequenceKeypoint.new(1, Theme.BrandAccent),
	})
end

local function logoWordmark(accent)
	local a = accent or Theme.BrandAccent
	local hex = colorRgbTag(a)
	local textHex = colorRgbTag(Theme.BrandText)
	return string.format('<font color="%s">B</font><font color="%s">lurred</font>', hex, textHex)
end

local function footerDiscordMark(accent)
	local hex = colorRgbTag(accent or Theme.Accent)
	return string.format('discord.gg/<font color="%s">blurblur</font>', hex)
end

local function footerSiteMark(accent)
	local hex = colorRgbTag(accent or Theme.Accent)
	return string.format('soblurry<font color="%s">.xyz</font>', hex)
end

local function flushThemeSwaps()
	flushScheduled = false
	lastFlushClock = os.clock()
	-- packed old color -> new color, one lookup per property
	local map = {}
	local accentNew = nil
	for key, sw in pairs(pendingSwaps) do
		if packColor(sw.old) ~= packColor(sw.new) then
			map[packColor(sw.old)] = sw.new
		end
		if key == "Accent" then accentNew = sw.new end
	end
	pendingSwaps = {}
	if not next(map) and not accentNew then return end

	for _, w in ipairs(Library.Windows) do
		for _, d in ipairs(w.ScreenGui:GetDescendants()) do
			local props = CLASS_COLOR_PROPS[d.ClassName]
			if props then
				for _, p in ipairs(props) do
					local repl = map[packColor(d[p])]
					if repl then d[p] = repl end
				end
			end
		end
		-- keep tab color caches on Theme keys (not only Accent)
		for _, t in ipairs(w.Tabs) do
			t.ColorActive = Theme.TabActive
			t.ColorInactive = Theme.TabInactive
		end
		if w.LogoGrad then
			local seq = textAccentGradient()
			w.LogoGrad.Color = seq
			if w.LogoLineGrad then w.LogoLineGrad.Color = seq end
		end
		if w.LogoText then
			w.LogoText.Text = w.TitleText or "Blurred"
		end
		if w.FooterLeftLabel and w.FooterLeftRich then
			w.FooterLeftLabel.Text = footerDiscordMark(Theme.Accent)
		end
		if w.FooterRightLabel and w.FooterRightRich then
			w.FooterRightLabel.Text = footerSiteMark(Theme.Accent)
		end
		-- Re-sync tab + sub-tab colors from their known state. Tab labels/icons
		-- are colored by short tweens (hover/select) which may still be running
		-- toward the OLD accent -- starting a new tween on the same property
		-- cancels the stale one, so tween (don't set) to the correct color.
		for _, t in ipairs(w.Tabs) do
			local isActive = (w.ActiveTab == t)
			local col = isActive and Theme.TabActive or Theme.TabInactive
			if t._paint then
				t._paint(col, true)
			else
				Tween(t.Label, 0.04, { TextColor3 = col })
				Tween(t.IconLbl, 0.04, { ImageColor3 = col })
			end
			for _, st in ipairs(t.SubTabs) do
				local stActive = (t.ActiveSubTab == st)
				Tween(st.SidebarLabel, 0.04, {
					TextColor3 = stActive and Theme.SubTabTextActive or Theme.SubTabText
				})
			end
		end
		if w.SubTabIndicator then
			w.SubTabIndicator.BackgroundColor3 = Theme.Accent
		end
		-- watermark brand gradients
		if w._watermarkBrandGrads then
			local seq = textAccentGradient()
			for _, g in ipairs(w._watermarkBrandGrads) do
				if g and g.Parent then g.Color = seq end
			end
		end
	end
	if Library.SaveActiveTheme then
		Library.SaveActiveTheme()
	end
end

-- Theme color flushes run on RenderStepped, capped at Anim.TargetFPS (default 240).
RunService.RenderStepped:Connect(function()
	if not flushScheduled then return end
	if os.clock() - lastFlushClock < frameInterval() then return end
	flushThemeSwaps()
end)

function Library:SetThemeColor(key, color)
	local old = Theme[key]
	if old == nil then return end
	Theme[key] = color
	-- remember the color that's still on screen; keep updating the target
	local sw = pendingSwaps[key]
	if sw then sw.new = color
	else pendingSwaps[key] = { old = old, new = color } end
	flushScheduled = true
	-- keep Theme* colorpickers' internal HSV / swatch in sync with the live color
	-- (silent: do not re-fire SetThemeColor via the picker's Callback)
	local flag = "Theme" .. key
	local setter = Library.FlagSetters[flag]
	if setter then
		setter(color, nil, false)
	end
end

-- preset themes; each entry lists only the keys it overrides.
-- NOTE: every key inside a preset must have a UNIQUE color -- theme updates
-- swap "old color -> new color" across the GUI, so two keys sharing a color
-- would start overwriting each other's elements.
Library.Presets = {
	-- Every key must use a UNIQUE Color3 within a preset (theme flush swaps by color).
	["Default"] = {
		Accent = Color3.fromRGB(102, 224, 208), AccentDim = Color3.fromRGB(56, 155, 145),
		Header = Color3.fromRGB(10, 18, 20), HeaderTab = Color3.fromRGB(24, 40, 44),
		Footer = Color3.fromRGB(11, 19, 21),
		Background = Color3.fromRGB(14, 24, 27), Sidebar = Color3.fromRGB(16, 28, 31),
		SubTabActive = Color3.fromRGB(28, 48, 52), Groupbox = Color3.fromRGB(20, 34, 38),
		GroupboxLine = Color3.fromRGB(38, 58, 64), Element = Color3.fromRGB(26, 42, 46),
		ElementBorder = Color3.fromRGB(48, 72, 78),
		Text = Color3.fromRGB(220, 230, 232), TextDim = Color3.fromRGB(130, 155, 160),
		TextDark = Color3.fromRGB(80, 100, 105),
		BrandText = Color3.fromRGB(245, 250, 252), BrandAccent = Color3.fromRGB(90, 236, 220),
		TabActive = Color3.fromRGB(108, 228, 214), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(170, 200, 205), Hover = Color3.fromRGB(200, 214, 218),
		SubTabText = Color3.fromRGB(132, 157, 162), SubTabTextActive = Color3.fromRGB(96, 230, 214),
		WatermarkText = Color3.fromRGB(218, 228, 230), WatermarkTextDim = Color3.fromRGB(120, 148, 154),
		KeybindTitle = Color3.fromRGB(226, 234, 236), KeybindText = Color3.fromRGB(208, 220, 222),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(88, 220, 205),
	},
	["Gamesense"] = {
		Accent = Color3.fromRGB(163, 190, 60), AccentDim = Color3.fromRGB(110, 130, 45),
		Header = Color3.fromRGB(12, 12, 12), HeaderTab = Color3.fromRGB(30, 30, 30),
		Footer = Color3.fromRGB(13, 13, 13),
		Background = Color3.fromRGB(17, 17, 17), Sidebar = Color3.fromRGB(21, 21, 21),
		SubTabActive = Color3.fromRGB(34, 34, 34), Groupbox = Color3.fromRGB(25, 25, 25),
		GroupboxLine = Color3.fromRGB(42, 42, 42), Element = Color3.fromRGB(31, 31, 31),
		ElementBorder = Color3.fromRGB(55, 55, 55),
		Text = Color3.fromRGB(210, 210, 210), TextDim = Color3.fromRGB(140, 140, 140),
		TextDark = Color3.fromRGB(90, 90, 90),
		BrandText = Color3.fromRGB(230, 225, 225), BrandAccent = Color3.fromRGB(155, 198, 66),
		TabActive = Color3.fromRGB(169, 194, 64), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(186, 200, 135), Hover = Color3.fromRGB(195, 198, 200),
		SubTabText = Color3.fromRGB(142, 142, 142), SubTabTextActive = Color3.fromRGB(159, 196, 64),
		WatermarkText = Color3.fromRGB(208, 208, 208), WatermarkTextDim = Color3.fromRGB(132, 134, 135),
		KeybindTitle = Color3.fromRGB(216, 214, 214), KeybindText = Color3.fromRGB(200, 202, 202),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(151, 186, 57),
	},
	["Fatality"] = {
		Accent = Color3.fromRGB(197, 63, 101), AccentDim = Color3.fromRGB(140, 45, 75),
		Header = Color3.fromRGB(18, 14, 30), HeaderTab = Color3.fromRGB(35, 28, 55),
		Footer = Color3.fromRGB(19, 15, 31),
		Background = Color3.fromRGB(24, 19, 40), Sidebar = Color3.fromRGB(28, 22, 46),
		SubTabActive = Color3.fromRGB(42, 34, 66), Groupbox = Color3.fromRGB(31, 25, 52),
		GroupboxLine = Color3.fromRGB(50, 40, 78), Element = Color3.fromRGB(38, 31, 62),
		ElementBorder = Color3.fromRGB(62, 50, 95),
		Text = Color3.fromRGB(230, 220, 240), TextDim = Color3.fromRGB(150, 135, 170),
		TextDark = Color3.fromRGB(95, 80, 115),
		BrandText = Color3.fromRGB(250, 235, 255), BrandAccent = Color3.fromRGB(189, 71, 107),
		TabActive = Color3.fromRGB(203, 67, 105), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(213, 141, 170), Hover = Color3.fromRGB(215, 208, 230),
		SubTabText = Color3.fromRGB(152, 137, 172), SubTabTextActive = Color3.fromRGB(193, 69, 105),
		WatermarkText = Color3.fromRGB(228, 218, 238), WatermarkTextDim = Color3.fromRGB(142, 129, 165),
		KeybindTitle = Color3.fromRGB(236, 224, 244), KeybindText = Color3.fromRGB(220, 212, 232),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(185, 59, 98),
	},
	["Neverlose"] = {
		Accent = Color3.fromRGB(0, 168, 255), AccentDim = Color3.fromRGB(0, 110, 180),
		Header = Color3.fromRGB(8, 12, 20), HeaderTab = Color3.fromRGB(18, 28, 42),
		Footer = Color3.fromRGB(9, 14, 22),
		Background = Color3.fromRGB(12, 16, 26), Sidebar = Color3.fromRGB(14, 20, 32),
		SubTabActive = Color3.fromRGB(22, 34, 52), Groupbox = Color3.fromRGB(16, 24, 38),
		GroupboxLine = Color3.fromRGB(32, 48, 70), Element = Color3.fromRGB(20, 30, 46),
		ElementBorder = Color3.fromRGB(40, 60, 88),
		Text = Color3.fromRGB(210, 225, 245), TextDim = Color3.fromRGB(120, 145, 175),
		TextDark = Color3.fromRGB(70, 90, 115),
		BrandText = Color3.fromRGB(230, 240, 255), BrandAccent = Color3.fromRGB(0, 176, 255),
		TabActive = Color3.fromRGB(6, 172, 255), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(105, 196, 250), Hover = Color3.fromRGB(195, 213, 235),
		SubTabText = Color3.fromRGB(122, 147, 177), SubTabTextActive = Color3.fromRGB(0, 174, 255),
		WatermarkText = Color3.fromRGB(208, 223, 243), WatermarkTextDim = Color3.fromRGB(112, 139, 170),
		KeybindTitle = Color3.fromRGB(216, 229, 249), KeybindText = Color3.fromRGB(200, 217, 237),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(0, 164, 252),
	},
	["Onetap"] = {
		Accent = Color3.fromRGB(255, 140, 50), AccentDim = Color3.fromRGB(190, 95, 30),
		Header = Color3.fromRGB(16, 14, 12), HeaderTab = Color3.fromRGB(36, 30, 24),
		Footer = Color3.fromRGB(17, 15, 13),
		Background = Color3.fromRGB(20, 18, 16), Sidebar = Color3.fromRGB(24, 21, 18),
		SubTabActive = Color3.fromRGB(40, 34, 28), Groupbox = Color3.fromRGB(28, 24, 20),
		GroupboxLine = Color3.fromRGB(48, 42, 36), Element = Color3.fromRGB(34, 29, 24),
		ElementBorder = Color3.fromRGB(58, 50, 42),
		Text = Color3.fromRGB(235, 225, 210), TextDim = Color3.fromRGB(160, 145, 125),
		TextDark = Color3.fromRGB(100, 90, 75),
		BrandText = Color3.fromRGB(255, 240, 225), BrandAccent = Color3.fromRGB(247, 148, 56),
		TabActive = Color3.fromRGB(255, 144, 54), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(245, 182, 130), Hover = Color3.fromRGB(220, 213, 200),
		SubTabText = Color3.fromRGB(162, 147, 127), SubTabTextActive = Color3.fromRGB(251, 146, 54),
		WatermarkText = Color3.fromRGB(233, 223, 208), WatermarkTextDim = Color3.fromRGB(152, 139, 120),
		KeybindTitle = Color3.fromRGB(241, 229, 214), KeybindText = Color3.fromRGB(225, 217, 202),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(243, 136, 47),
	},
	["Aimware"] = {
		Accent = Color3.fromRGB(255, 70, 70), AccentDim = Color3.fromRGB(180, 40, 40),
		Header = Color3.fromRGB(14, 10, 10), HeaderTab = Color3.fromRGB(32, 20, 20),
		Footer = Color3.fromRGB(15, 11, 11),
		Background = Color3.fromRGB(18, 14, 14), Sidebar = Color3.fromRGB(22, 16, 16),
		SubTabActive = Color3.fromRGB(38, 24, 24), Groupbox = Color3.fromRGB(26, 18, 18),
		GroupboxLine = Color3.fromRGB(50, 32, 32), Element = Color3.fromRGB(32, 22, 22),
		ElementBorder = Color3.fromRGB(62, 40, 40),
		Text = Color3.fromRGB(240, 220, 220), TextDim = Color3.fromRGB(170, 140, 140),
		TextDark = Color3.fromRGB(110, 85, 85),
		BrandText = Color3.fromRGB(255, 235, 235), BrandAccent = Color3.fromRGB(247, 78, 76),
		TabActive = Color3.fromRGB(255, 74, 74), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(247, 145, 145), Hover = Color3.fromRGB(225, 208, 210),
		SubTabText = Color3.fromRGB(172, 142, 142), SubTabTextActive = Color3.fromRGB(251, 76, 74),
		WatermarkText = Color3.fromRGB(238, 218, 218), WatermarkTextDim = Color3.fromRGB(162, 134, 135),
		KeybindTitle = Color3.fromRGB(246, 224, 224), KeybindText = Color3.fromRGB(230, 212, 212),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(243, 66, 67),
	},
	["Ocean"] = {
		Accent = Color3.fromRGB(64, 196, 255), AccentDim = Color3.fromRGB(30, 130, 180),
		Header = Color3.fromRGB(6, 22, 36), HeaderTab = Color3.fromRGB(12, 40, 62),
		Footer = Color3.fromRGB(7, 24, 38),
		Background = Color3.fromRGB(8, 28, 44), Sidebar = Color3.fromRGB(10, 34, 52),
		SubTabActive = Color3.fromRGB(16, 52, 78), Groupbox = Color3.fromRGB(12, 38, 58),
		GroupboxLine = Color3.fromRGB(28, 70, 100), Element = Color3.fromRGB(14, 46, 70),
		ElementBorder = Color3.fromRGB(36, 88, 120),
		Text = Color3.fromRGB(200, 235, 255), TextDim = Color3.fromRGB(110, 170, 200),
		TextDark = Color3.fromRGB(60, 110, 140),
		BrandText = Color3.fromRGB(220, 250, 255), BrandAccent = Color3.fromRGB(56, 204, 255),
		TabActive = Color3.fromRGB(70, 200, 255), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(132, 215, 255), Hover = Color3.fromRGB(185, 223, 245),
		SubTabText = Color3.fromRGB(112, 172, 202), SubTabTextActive = Color3.fromRGB(60, 202, 255),
		WatermarkText = Color3.fromRGB(198, 233, 253), WatermarkTextDim = Color3.fromRGB(102, 164, 195),
		KeybindTitle = Color3.fromRGB(206, 239, 255), KeybindText = Color3.fromRGB(190, 227, 247),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(52, 192, 252),
	},
	["Crimson"] = {
		Accent = Color3.fromRGB(255, 55, 90), AccentDim = Color3.fromRGB(180, 30, 55),
		Header = Color3.fromRGB(22, 8, 12), HeaderTab = Color3.fromRGB(48, 16, 24),
		Footer = Color3.fromRGB(24, 9, 14),
		Background = Color3.fromRGB(28, 10, 16), Sidebar = Color3.fromRGB(34, 12, 20),
		SubTabActive = Color3.fromRGB(56, 18, 30), Groupbox = Color3.fromRGB(40, 14, 22),
		GroupboxLine = Color3.fromRGB(72, 28, 40), Element = Color3.fromRGB(48, 16, 26),
		ElementBorder = Color3.fromRGB(90, 36, 50),
		Text = Color3.fromRGB(255, 225, 230), TextDim = Color3.fromRGB(190, 140, 150),
		TextDark = Color3.fromRGB(120, 75, 85),
		BrandText = Color3.fromRGB(255, 240, 245), BrandAccent = Color3.fromRGB(247, 63, 96),
		TabActive = Color3.fromRGB(255, 59, 94), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(255, 140, 160), Hover = Color3.fromRGB(240, 213, 220),
		SubTabText = Color3.fromRGB(192, 142, 152), SubTabTextActive = Color3.fromRGB(251, 61, 94),
		WatermarkText = Color3.fromRGB(253, 223, 228), WatermarkTextDim = Color3.fromRGB(182, 134, 145),
		KeybindTitle = Color3.fromRGB(255, 229, 234), KeybindText = Color3.fromRGB(245, 217, 222),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(243, 51, 87),
	},
	["Forest"] = {
		Accent = Color3.fromRGB(90, 200, 120), AccentDim = Color3.fromRGB(50, 140, 75),
		Header = Color3.fromRGB(10, 18, 12), HeaderTab = Color3.fromRGB(20, 38, 24),
		Footer = Color3.fromRGB(11, 20, 13),
		Background = Color3.fromRGB(12, 22, 14), Sidebar = Color3.fromRGB(14, 28, 18),
		SubTabActive = Color3.fromRGB(24, 46, 30), Groupbox = Color3.fromRGB(16, 32, 20),
		GroupboxLine = Color3.fromRGB(34, 60, 40), Element = Color3.fromRGB(20, 40, 26),
		ElementBorder = Color3.fromRGB(44, 76, 52),
		Text = Color3.fromRGB(215, 240, 220), TextDim = Color3.fromRGB(130, 170, 140),
		TextDark = Color3.fromRGB(75, 105, 85),
		BrandText = Color3.fromRGB(235, 255, 235), BrandAccent = Color3.fromRGB(82, 208, 126),
		TabActive = Color3.fromRGB(96, 204, 124), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(152, 220, 170), Hover = Color3.fromRGB(200, 228, 210),
		SubTabText = Color3.fromRGB(132, 172, 142), SubTabTextActive = Color3.fromRGB(86, 206, 124),
		WatermarkText = Color3.fromRGB(213, 238, 218), WatermarkTextDim = Color3.fromRGB(122, 164, 135),
		KeybindTitle = Color3.fromRGB(221, 244, 224), KeybindText = Color3.fromRGB(205, 232, 212),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(78, 196, 117),
	},
	["Midnight"] = {
		Accent = Color3.fromRGB(120, 100, 255), AccentDim = Color3.fromRGB(75, 60, 180),
		Header = Color3.fromRGB(8, 8, 18), HeaderTab = Color3.fromRGB(20, 20, 40),
		Footer = Color3.fromRGB(9, 9, 20),
		Background = Color3.fromRGB(10, 10, 22), Sidebar = Color3.fromRGB(12, 12, 28),
		SubTabActive = Color3.fromRGB(24, 24, 50), Groupbox = Color3.fromRGB(14, 14, 32),
		GroupboxLine = Color3.fromRGB(36, 36, 68), Element = Color3.fromRGB(18, 18, 40),
		ElementBorder = Color3.fromRGB(48, 48, 88),
		Text = Color3.fromRGB(225, 225, 255), TextDim = Color3.fromRGB(150, 150, 190),
		TextDark = Color3.fromRGB(95, 95, 130),
		BrandText = Color3.fromRGB(245, 240, 255), BrandAccent = Color3.fromRGB(112, 108, 255),
		TabActive = Color3.fromRGB(126, 104, 255), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(172, 162, 255), Hover = Color3.fromRGB(210, 213, 245),
		SubTabText = Color3.fromRGB(152, 152, 192), SubTabTextActive = Color3.fromRGB(116, 106, 255),
		WatermarkText = Color3.fromRGB(223, 223, 253), WatermarkTextDim = Color3.fromRGB(142, 144, 185),
		KeybindTitle = Color3.fromRGB(231, 229, 255), KeybindText = Color3.fromRGB(215, 217, 247),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(108, 96, 252),
	},
	["Solar"] = {
		Accent = Color3.fromRGB(255, 200, 60), AccentDim = Color3.fromRGB(190, 140, 30),
		Header = Color3.fromRGB(20, 16, 8), HeaderTab = Color3.fromRGB(42, 34, 14),
		Footer = Color3.fromRGB(22, 18, 9),
		Background = Color3.fromRGB(26, 20, 10), Sidebar = Color3.fromRGB(32, 24, 12),
		SubTabActive = Color3.fromRGB(52, 40, 18), Groupbox = Color3.fromRGB(36, 28, 14),
		GroupboxLine = Color3.fromRGB(70, 55, 28), Element = Color3.fromRGB(44, 34, 16),
		ElementBorder = Color3.fromRGB(88, 70, 34),
		Text = Color3.fromRGB(255, 245, 210), TextDim = Color3.fromRGB(190, 170, 110),
		TextDark = Color3.fromRGB(120, 105, 60),
		BrandText = Color3.fromRGB(255, 255, 225), BrandAccent = Color3.fromRGB(247, 208, 66),
		TabActive = Color3.fromRGB(255, 204, 64), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(255, 222, 135), Hover = Color3.fromRGB(240, 233, 200),
		SubTabText = Color3.fromRGB(192, 172, 112), SubTabTextActive = Color3.fromRGB(251, 206, 64),
		WatermarkText = Color3.fromRGB(253, 243, 208), WatermarkTextDim = Color3.fromRGB(182, 164, 105),
		KeybindTitle = Color3.fromRGB(255, 249, 214), KeybindText = Color3.fromRGB(245, 237, 202),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(243, 196, 57),
	},
	["Nord"] = {
		Accent = Color3.fromRGB(136, 192, 208), AccentDim = Color3.fromRGB(80, 130, 150),
		Header = Color3.fromRGB(36, 41, 51), HeaderTab = Color3.fromRGB(52, 60, 74),
		Footer = Color3.fromRGB(38, 44, 54),
		Background = Color3.fromRGB(46, 52, 64), Sidebar = Color3.fromRGB(50, 56, 68),
		SubTabActive = Color3.fromRGB(64, 72, 88), Groupbox = Color3.fromRGB(54, 60, 74),
		GroupboxLine = Color3.fromRGB(76, 86, 106), Element = Color3.fromRGB(59, 66, 82),
		ElementBorder = Color3.fromRGB(94, 105, 128),
		Text = Color3.fromRGB(236, 239, 244), TextDim = Color3.fromRGB(160, 170, 185),
		TextDark = Color3.fromRGB(100, 110, 125),
		BrandText = Color3.fromRGB(255, 254, 255), BrandAccent = Color3.fromRGB(128, 200, 214),
		TabActive = Color3.fromRGB(142, 196, 212), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(186, 215, 226), Hover = Color3.fromRGB(221, 227, 234),
		SubTabText = Color3.fromRGB(162, 172, 187), SubTabTextActive = Color3.fromRGB(132, 198, 212),
		WatermarkText = Color3.fromRGB(234, 237, 242), WatermarkTextDim = Color3.fromRGB(152, 164, 180),
		KeybindTitle = Color3.fromRGB(242, 243, 248), KeybindText = Color3.fromRGB(226, 231, 236),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(124, 188, 205),
	},
	["Catppuccin"] = {
		Accent = Color3.fromRGB(203, 166, 247), AccentDim = Color3.fromRGB(150, 110, 200),
		Header = Color3.fromRGB(24, 24, 37), HeaderTab = Color3.fromRGB(40, 40, 58),
		Footer = Color3.fromRGB(26, 26, 40),
		Background = Color3.fromRGB(30, 30, 46), Sidebar = Color3.fromRGB(34, 34, 50),
		SubTabActive = Color3.fromRGB(50, 50, 72), Groupbox = Color3.fromRGB(36, 36, 54),
		GroupboxLine = Color3.fromRGB(60, 60, 84), Element = Color3.fromRGB(42, 42, 62),
		ElementBorder = Color3.fromRGB(78, 78, 105),
		Text = Color3.fromRGB(205, 214, 244), TextDim = Color3.fromRGB(147, 153, 178),
		TextDark = Color3.fromRGB(100, 105, 130),
		BrandText = Color3.fromRGB(225, 229, 255), BrandAccent = Color3.fromRGB(195, 174, 253),
		TabActive = Color3.fromRGB(209, 170, 251), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(204, 190, 245), Hover = Color3.fromRGB(190, 202, 234),
		SubTabText = Color3.fromRGB(149, 155, 180), SubTabTextActive = Color3.fromRGB(199, 172, 251),
		WatermarkText = Color3.fromRGB(203, 212, 242), WatermarkTextDim = Color3.fromRGB(139, 147, 173),
		KeybindTitle = Color3.fromRGB(211, 218, 248), KeybindText = Color3.fromRGB(195, 206, 236),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(191, 162, 244),
	},
	["Dracula"] = {
		Accent = Color3.fromRGB(189, 147, 249), AccentDim = Color3.fromRGB(130, 95, 190),
		Header = Color3.fromRGB(30, 31, 41), HeaderTab = Color3.fromRGB(48, 50, 66),
		Footer = Color3.fromRGB(32, 33, 44),
		Background = Color3.fromRGB(40, 42, 54), Sidebar = Color3.fromRGB(44, 46, 60),
		SubTabActive = Color3.fromRGB(58, 60, 78), Groupbox = Color3.fromRGB(46, 48, 62),
		GroupboxLine = Color3.fromRGB(72, 74, 96), Element = Color3.fromRGB(54, 56, 74),
		ElementBorder = Color3.fromRGB(88, 90, 115),
		Text = Color3.fromRGB(248, 248, 242), TextDim = Color3.fromRGB(170, 170, 185),
		TextDark = Color3.fromRGB(110, 110, 130),
		BrandText = Color3.fromRGB(255, 255, 255), BrandAccent = Color3.fromRGB(181, 155, 255),
		TabActive = Color3.fromRGB(195, 151, 253), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(218, 197, 245), Hover = Color3.fromRGB(233, 236, 232),
		SubTabText = Color3.fromRGB(172, 172, 187), SubTabTextActive = Color3.fromRGB(185, 153, 253),
		WatermarkText = Color3.fromRGB(246, 246, 240), WatermarkTextDim = Color3.fromRGB(162, 164, 180),
		KeybindTitle = Color3.fromRGB(254, 252, 246), KeybindText = Color3.fromRGB(238, 240, 234),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(177, 143, 246),
	},
	["Rose Pine"] = {
		Accent = Color3.fromRGB(235, 111, 146), AccentDim = Color3.fromRGB(170, 70, 100),
		Header = Color3.fromRGB(25, 23, 36), HeaderTab = Color3.fromRGB(42, 39, 58),
		Footer = Color3.fromRGB(27, 25, 38),
		Background = Color3.fromRGB(31, 29, 46), Sidebar = Color3.fromRGB(35, 33, 52),
		SubTabActive = Color3.fromRGB(52, 48, 72), Groupbox = Color3.fromRGB(38, 35, 56),
		GroupboxLine = Color3.fromRGB(64, 58, 88), Element = Color3.fromRGB(44, 40, 64),
		ElementBorder = Color3.fromRGB(80, 72, 108),
		Text = Color3.fromRGB(224, 222, 244), TextDim = Color3.fromRGB(155, 150, 180),
		TextDark = Color3.fromRGB(100, 95, 125),
		BrandText = Color3.fromRGB(244, 237, 255), BrandAccent = Color3.fromRGB(227, 119, 152),
		TabActive = Color3.fromRGB(241, 115, 150), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(229, 166, 195), Hover = Color3.fromRGB(209, 210, 234),
		SubTabText = Color3.fromRGB(157, 152, 182), SubTabTextActive = Color3.fromRGB(231, 117, 150),
		WatermarkText = Color3.fromRGB(222, 220, 242), WatermarkTextDim = Color3.fromRGB(147, 144, 175),
		KeybindTitle = Color3.fromRGB(230, 226, 248), KeybindText = Color3.fromRGB(214, 214, 236),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(223, 107, 143),
	},
	["Tokyo Night"] = {
		Accent = Color3.fromRGB(122, 162, 247), AccentDim = Color3.fromRGB(70, 105, 180),
		Header = Color3.fromRGB(20, 22, 32), HeaderTab = Color3.fromRGB(36, 40, 56),
		Footer = Color3.fromRGB(22, 24, 34),
		Background = Color3.fromRGB(26, 27, 38), Sidebar = Color3.fromRGB(30, 32, 44),
		SubTabActive = Color3.fromRGB(46, 50, 68), Groupbox = Color3.fromRGB(34, 36, 50),
		GroupboxLine = Color3.fromRGB(58, 62, 84), Element = Color3.fromRGB(40, 42, 58),
		ElementBorder = Color3.fromRGB(72, 78, 105),
		Text = Color3.fromRGB(192, 202, 245), TextDim = Color3.fromRGB(130, 140, 175),
		TextDark = Color3.fromRGB(80, 90, 120),
		BrandText = Color3.fromRGB(212, 217, 255), BrandAccent = Color3.fromRGB(114, 170, 253),
		TabActive = Color3.fromRGB(128, 166, 251), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(157, 182, 246), Hover = Color3.fromRGB(177, 190, 235),
		SubTabText = Color3.fromRGB(132, 142, 177), SubTabTextActive = Color3.fromRGB(118, 168, 251),
		WatermarkText = Color3.fromRGB(190, 200, 243), WatermarkTextDim = Color3.fromRGB(122, 134, 170),
		KeybindTitle = Color3.fromRGB(198, 206, 249), KeybindText = Color3.fromRGB(182, 194, 237),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(110, 158, 244),
	},
	["Gruvbox"] = {
		Accent = Color3.fromRGB(215, 153, 33), AccentDim = Color3.fromRGB(160, 110, 20),
		Header = Color3.fromRGB(29, 32, 33), HeaderTab = Color3.fromRGB(50, 48, 40),
		Footer = Color3.fromRGB(32, 30, 28),
		Background = Color3.fromRGB(40, 40, 40), Sidebar = Color3.fromRGB(45, 42, 38),
		SubTabActive = Color3.fromRGB(60, 56, 48), Groupbox = Color3.fromRGB(50, 48, 44),
		GroupboxLine = Color3.fromRGB(80, 75, 65), Element = Color3.fromRGB(55, 52, 46),
		ElementBorder = Color3.fromRGB(95, 88, 75),
		Text = Color3.fromRGB(235, 219, 178), TextDim = Color3.fromRGB(168, 153, 132),
		TextDark = Color3.fromRGB(110, 100, 85),
		BrandText = Color3.fromRGB(255, 234, 193), BrandAccent = Color3.fromRGB(207, 161, 39),
		TabActive = Color3.fromRGB(221, 157, 37), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(225, 186, 105), Hover = Color3.fromRGB(220, 207, 168),
		SubTabText = Color3.fromRGB(170, 155, 134), SubTabTextActive = Color3.fromRGB(211, 159, 37),
		WatermarkText = Color3.fromRGB(233, 217, 176), WatermarkTextDim = Color3.fromRGB(160, 147, 127),
		KeybindTitle = Color3.fromRGB(241, 223, 182), KeybindText = Color3.fromRGB(225, 211, 170),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(203, 149, 30),
	},
	["Monokai"] = {
		Accent = Color3.fromRGB(249, 38, 114), AccentDim = Color3.fromRGB(180, 25, 80),
		Header = Color3.fromRGB(30, 31, 28), HeaderTab = Color3.fromRGB(50, 52, 46),
		Footer = Color3.fromRGB(32, 33, 30),
		Background = Color3.fromRGB(39, 40, 34), Sidebar = Color3.fromRGB(44, 45, 38),
		SubTabActive = Color3.fromRGB(60, 62, 52), Groupbox = Color3.fromRGB(48, 49, 42),
		GroupboxLine = Color3.fromRGB(75, 78, 65), Element = Color3.fromRGB(54, 56, 46),
		ElementBorder = Color3.fromRGB(92, 95, 78),
		Text = Color3.fromRGB(248, 248, 242), TextDim = Color3.fromRGB(170, 170, 155),
		TextDark = Color3.fromRGB(110, 110, 95),
		BrandText = Color3.fromRGB(255, 255, 255), BrandAccent = Color3.fromRGB(241, 46, 120),
		TabActive = Color3.fromRGB(255, 42, 118), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(248, 143, 178), Hover = Color3.fromRGB(233, 236, 232),
		SubTabText = Color3.fromRGB(172, 172, 157), SubTabTextActive = Color3.fromRGB(245, 44, 118),
		WatermarkText = Color3.fromRGB(246, 246, 240), WatermarkTextDim = Color3.fromRGB(162, 164, 150),
		KeybindTitle = Color3.fromRGB(254, 252, 246), KeybindText = Color3.fromRGB(238, 240, 234),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(237, 34, 111),
	},
	["Ice"] = {
		Accent = Color3.fromRGB(180, 230, 255), AccentDim = Color3.fromRGB(100, 170, 210),
		Header = Color3.fromRGB(18, 28, 36), HeaderTab = Color3.fromRGB(32, 50, 64),
		Footer = Color3.fromRGB(20, 30, 38),
		Background = Color3.fromRGB(22, 34, 44), Sidebar = Color3.fromRGB(26, 40, 52),
		SubTabActive = Color3.fromRGB(40, 60, 76), Groupbox = Color3.fromRGB(28, 44, 56),
		GroupboxLine = Color3.fromRGB(50, 78, 98), Element = Color3.fromRGB(34, 52, 66),
		ElementBorder = Color3.fromRGB(64, 98, 120),
		Text = Color3.fromRGB(230, 245, 255), TextDim = Color3.fromRGB(150, 185, 210),
		TextDark = Color3.fromRGB(90, 125, 150),
		BrandText = Color3.fromRGB(250, 255, 255), BrandAccent = Color3.fromRGB(172, 238, 255),
		TabActive = Color3.fromRGB(186, 234, 255), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(205, 237, 255), Hover = Color3.fromRGB(215, 233, 245),
		SubTabText = Color3.fromRGB(152, 187, 212), SubTabTextActive = Color3.fromRGB(176, 236, 255),
		WatermarkText = Color3.fromRGB(228, 243, 253), WatermarkTextDim = Color3.fromRGB(142, 179, 205),
		KeybindTitle = Color3.fromRGB(236, 249, 255), KeybindText = Color3.fromRGB(220, 237, 247),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(168, 226, 252),
	},
	["Lavender"] = {
		Accent = Color3.fromRGB(186, 150, 255), AccentDim = Color3.fromRGB(130, 95, 200),
		Header = Color3.fromRGB(22, 18, 32), HeaderTab = Color3.fromRGB(40, 32, 58),
		Footer = Color3.fromRGB(24, 20, 34),
		Background = Color3.fromRGB(28, 22, 40), Sidebar = Color3.fromRGB(32, 26, 46),
		SubTabActive = Color3.fromRGB(48, 38, 68), Groupbox = Color3.fromRGB(36, 28, 52),
		GroupboxLine = Color3.fromRGB(64, 50, 90), Element = Color3.fromRGB(42, 34, 60),
		ElementBorder = Color3.fromRGB(80, 64, 110),
		Text = Color3.fromRGB(235, 225, 255), TextDim = Color3.fromRGB(165, 150, 195),
		TextDark = Color3.fromRGB(105, 90, 135),
		BrandText = Color3.fromRGB(255, 240, 255), BrandAccent = Color3.fromRGB(178, 158, 255),
		TabActive = Color3.fromRGB(192, 154, 255), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(210, 187, 255), Hover = Color3.fromRGB(220, 213, 245),
		SubTabText = Color3.fromRGB(167, 152, 197), SubTabTextActive = Color3.fromRGB(182, 156, 255),
		WatermarkText = Color3.fromRGB(233, 223, 253), WatermarkTextDim = Color3.fromRGB(157, 144, 190),
		KeybindTitle = Color3.fromRGB(241, 229, 255), KeybindText = Color3.fromRGB(225, 217, 247),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(174, 146, 252),
	},
	["Neon"] = {
		Accent = Color3.fromRGB(255, 90, 170), AccentDim = Color3.fromRGB(190, 50, 120),
		Header = Color3.fromRGB(12, 10, 14), HeaderTab = Color3.fromRGB(30, 22, 34),
		Footer = Color3.fromRGB(14, 11, 16),
		Background = Color3.fromRGB(16, 14, 20), Sidebar = Color3.fromRGB(20, 16, 26),
		SubTabActive = Color3.fromRGB(36, 26, 44), Groupbox = Color3.fromRGB(24, 18, 30),
		GroupboxLine = Color3.fromRGB(50, 36, 60), Element = Color3.fromRGB(28, 22, 36),
		ElementBorder = Color3.fromRGB(66, 48, 78),
		Text = Color3.fromRGB(245, 230, 240), TextDim = Color3.fromRGB(175, 145, 170),
		TextDark = Color3.fromRGB(115, 90, 110),
		BrandText = Color3.fromRGB(255, 245, 255), BrandAccent = Color3.fromRGB(247, 98, 176),
		TabActive = Color3.fromRGB(255, 94, 174), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(250, 160, 205), Hover = Color3.fromRGB(230, 218, 230),
		SubTabText = Color3.fromRGB(177, 147, 172), SubTabTextActive = Color3.fromRGB(251, 96, 174),
		WatermarkText = Color3.fromRGB(243, 228, 238), WatermarkTextDim = Color3.fromRGB(167, 139, 165),
		KeybindTitle = Color3.fromRGB(251, 234, 244), KeybindText = Color3.fromRGB(235, 222, 232),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(243, 86, 167),
	},
	["Sand"] = {
		Accent = Color3.fromRGB(210, 170, 110), AccentDim = Color3.fromRGB(150, 115, 70),
		Header = Color3.fromRGB(28, 24, 18), HeaderTab = Color3.fromRGB(48, 42, 32),
		Footer = Color3.fromRGB(30, 26, 20),
		Background = Color3.fromRGB(34, 30, 24), Sidebar = Color3.fromRGB(40, 34, 28),
		SubTabActive = Color3.fromRGB(58, 50, 40), Groupbox = Color3.fromRGB(44, 38, 30),
		GroupboxLine = Color3.fromRGB(72, 62, 48), Element = Color3.fromRGB(50, 44, 34),
		ElementBorder = Color3.fromRGB(90, 78, 60),
		Text = Color3.fromRGB(240, 230, 210), TextDim = Color3.fromRGB(175, 160, 135),
		TextDark = Color3.fromRGB(115, 100, 80),
		BrandText = Color3.fromRGB(255, 245, 225), BrandAccent = Color3.fromRGB(202, 178, 116),
		TabActive = Color3.fromRGB(216, 174, 114), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(225, 200, 160), Hover = Color3.fromRGB(225, 218, 200),
		SubTabText = Color3.fromRGB(177, 162, 137), SubTabTextActive = Color3.fromRGB(206, 176, 114),
		WatermarkText = Color3.fromRGB(238, 228, 208), WatermarkTextDim = Color3.fromRGB(167, 154, 130),
		KeybindTitle = Color3.fromRGB(246, 234, 214), KeybindText = Color3.fromRGB(230, 222, 202),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(198, 166, 107),
	},
	["Mint"] = {
		Accent = Color3.fromRGB(110, 230, 190), AccentDim = Color3.fromRGB(60, 160, 130),
		Header = Color3.fromRGB(12, 22, 20), HeaderTab = Color3.fromRGB(22, 42, 38),
		Footer = Color3.fromRGB(13, 24, 22),
		Background = Color3.fromRGB(14, 26, 24), Sidebar = Color3.fromRGB(16, 32, 28),
		SubTabActive = Color3.fromRGB(26, 50, 44), Groupbox = Color3.fromRGB(18, 36, 32),
		GroupboxLine = Color3.fromRGB(36, 68, 58), Element = Color3.fromRGB(22, 44, 38),
		ElementBorder = Color3.fromRGB(46, 84, 72),
		Text = Color3.fromRGB(220, 245, 235), TextDim = Color3.fromRGB(135, 180, 165),
		TextDark = Color3.fromRGB(80, 115, 105),
		BrandText = Color3.fromRGB(240, 255, 250), BrandAccent = Color3.fromRGB(102, 238, 196),
		TabActive = Color3.fromRGB(116, 234, 194), TabInactive = Color3.fromRGB(128, 128, 128),
		TabHover = Color3.fromRGB(165, 237, 212), Hover = Color3.fromRGB(205, 233, 225),
		SubTabText = Color3.fromRGB(137, 182, 167), SubTabTextActive = Color3.fromRGB(106, 236, 194),
		WatermarkText = Color3.fromRGB(218, 243, 233), WatermarkTextDim = Color3.fromRGB(127, 174, 160),
		KeybindTitle = Color3.fromRGB(226, 249, 239), KeybindText = Color3.fromRGB(210, 237, 227),
		KeybindTextDim = Color3.fromRGB(118, 118, 120), KeybindActive = Color3.fromRGB(98, 226, 187),
	},
}

function Library:ApplyPreset(name)
	local preset = Library.Presets[name]
	if not preset then return end
	-- apply each key independently (full preset tables; unique colors per key)
	for key in pairs(Theme) do
		local color = preset[key]
		if typeof(color) == "Color3" then
			Library:SetThemeColor(key, color)
		end
	end
end

-- force every Theme key back to the built-in Default (ignores disk / last session)
function Library:ResetTheme()
	for key, color in pairs(DefaultTheme) do
		if Theme[key] ~= nil and typeof(color) == "Color3" then
			Library:SetThemeColor(key, color)
		end
	end
end

local function serializeThemeTable(src)
	local out = {}
	for key, color in pairs(src) do
		if typeof(color) == "Color3" then
			out[key] = { R = color.R, G = color.G, B = color.B }
		end
	end
	return out
end

local function saveThemeFile(name, src)
	if not hasFs() then return end
	local path = Library.Folders.Themes .. "/" .. name .. ".json"
	pcall(writefile, path, HttpService:JSONEncode(serializeThemeTable(src)))
end

local function loadThemeFile(name)
	if not hasFs() then return nil end
	local path = Library.Folders.Themes .. "/" .. name .. ".json"
	if not isfile(path) then return nil end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(data) ~= "table" then return nil end
	local out = {}
	for key, v in pairs(data) do
		if type(v) == "table" and v.R and v.G and v.B then
			out[key] = Color3.new(v.R, v.G, v.B)
		end
	end
	return out
end

-- seed preset theme files; always boot on the built-in Default (never restore active.json)
do
	-- keep Theme locked to the frozen Default before any UI is built
	for key, color in pairs(DefaultTheme) do
		Theme[key] = color
	end
	-- keep Presets.Default identical to the frozen original
	if Library.Presets and Library.Presets.Default then
		for key, color in pairs(DefaultTheme) do
			Library.Presets.Default[key] = color
		end
	end
	for name, preset in pairs(Library.Presets) do
		saveThemeFile(string.lower(name), preset)
	end
	-- overwrite stale active.json so the next write isn't confused by an old theme
	saveThemeFile("active", DefaultTheme)
end

Library.DefaultTheme = DefaultTheme
Library.SaveActiveTheme = function()
	saveThemeFile("active", Theme)
end

-- export current theme as JSON (clipboard + return string)
function Library:ExportTheme()
	local payload = {
		Version = 1,
		Type = "BlurredTheme",
		Theme = serializeThemeTable(Theme),
	}
	local encoded = HttpService:JSONEncode(payload)
	local copied = false
	if setclipboard then
		copied = pcall(setclipboard, encoded)
	elseif toclipboard then
		copied = pcall(toclipboard, encoded)
	end
	if copied then
		Library:Notify("Theme exported to clipboard")
	else
		Library:Notify("Theme export ready (clipboard unavailable)")
	end
	return encoded
end

-- import a full theme from JSON string / table / clipboard
function Library:ImportTheme(source)
	local raw = source
	if raw == nil or raw == true then
		-- pull from clipboard when called with no args
		if getclipboard then
			local ok, v = pcall(getclipboard)
			if ok then raw = v end
		end
	end
	local data = raw
	if type(raw) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if not ok or type(decoded) ~= "table" then
			Library:Notify("Invalid theme JSON")
			return false
		end
		data = decoded
	end
	if type(data) ~= "table" then
		Library:Notify("No theme data to import")
		return false
	end
	-- accept { Theme = {...} } wrapper or a flat color map
	local colors = data.Theme
	if type(colors) ~= "table" then
		colors = data
	end
	local applied = 0
	for key, v in pairs(colors) do
		local color = nil
		if typeof(v) == "Color3" then
			color = v
		elseif type(v) == "table" and v.R and v.G and v.B then
			-- 0-1 floats or 0-255 ints
			if v.R > 1 or v.G > 1 or v.B > 1 then
				color = Color3.fromRGB(v.R, v.G, v.B)
			else
				color = Color3.new(v.R, v.G, v.B)
			end
		end
		if color and Theme[key] ~= nil then
			Library:SetThemeColor(key, color)
			applied += 1
		end
	end
	if applied > 0 then
		if Library.SaveActiveTheme then Library.SaveActiveTheme() end
		Library:Notify("Theme imported (" .. applied .. " colors)")
		return true
	end
	Library:Notify("Theme import failed")
	return false
end

local Icons = { _map = {}, _cache = {} }
do
	local URL = "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"
	local mapPath = Library.Folders.Assets .. "/icons_map.lua"
	local function loadMap(src)
		local ok, map = pcall(function() return loadstring(src)() end)
		if ok and type(map) == "table" and (map["check"] or map["search"] or next(map)) then
			return map
		end
		return nil
	end
	local map
	if hasFs() and isfile(mapPath) then
		local okRead, src = pcall(readfile, mapPath)
		if okRead and type(src) == "string" then
			map = loadMap(src)
		end
	end
	if not map then
		local okHttp, src = pcall(function() return game:HttpGet(URL) end)
		if okHttp and type(src) == "string" then
			map = loadMap(src)
			if map and hasFs() and writefile then
				pcall(writefile, mapPath, src)
			end
		end
	end
	if map then
		Icons._map = map
	end
end
function Icons.Get(name)
	if not name then return nil end
	if Icons._cache[name] then return Icons._cache[name] end
	local raw = Icons._map[name]
	if not raw then return nil end

	-- persist the asset id to blurred/assets/icons/<name>.id, then read it back
	local id = extractAssetId(raw)
	local idPath = Library.Folders.Icons .. "/" .. name .. ".id"
	if id then
		local stored = readIdFile(idPath)
		if stored then
			id = stored
		else
			writeIdFile(idPath, id)
		end
		raw = "rbxassetid://" .. id
	end

	Icons._cache[name] = raw
	return raw
end
Library.Icons = Icons

local CustomFont = {}
do
	function CustomFont:New(Name, Weight, Style, Data)
		local jsonPath = Library.Folders.Fonts .. "/" .. Name .. ".json"
		local ttfPath  = Library.Folders.Fonts .. "/" .. Name .. ".ttf"

		if isfile and isfile(jsonPath) and getcustomasset then
			local ok, font = pcall(function() return Font.new(getcustomasset(jsonPath)) end)
			if ok and font then return font end
		end

		if not (isfile and isfile(ttfPath)) then
			pcall(function()
				writefile(ttfPath, game:HttpGet(Data.Url))
			end)
		end

		if not (isfile and isfile(ttfPath) and getcustomasset) then
			return nil
		end

		local FontData = {
			name = Name,
			faces = { {
				name = "Regular",
				weight = Weight,
				style = Style,
				assetId = getcustomasset(ttfPath),
			} },
		}
		pcall(writefile, jsonPath, HttpService:JSONEncode(FontData))
		local ok, font = pcall(function() return Font.new(getcustomasset(jsonPath)) end)
		if ok then return font end
	end

	function CustomFont:Get(Name)
		local jsonPath = Library.Folders.Fonts .. "/" .. Name .. ".json"
		if isfile and isfile(jsonPath) and getcustomasset then
			local ok, font = pcall(function() return Font.new(getcustomasset(jsonPath)) end)
			if ok then return font end
		end
	end
end

-- FontFace requires a Font object (Enum.Font breaks Inter / custom faces).
do
	local okGotham, gotham = pcall(Font.new, "rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
	Library.Font = (okGotham and gotham) or Font.fromEnum(Enum.Font.GothamMedium)

	local okInter, inter = pcall(Font.new, "rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
	if okInter and inter then
		Library.Font = inter
	end
end
pcall(function()
	CustomFont:New("ProggyTiny", 400, "Normal", {
		Url = "https://github.com/fcambus/proggy-tiles/raw/master/fonts/proggy-tiny.ttf",
	})
end)
Library.CustomFont = CustomFont

local function getGuiParent()
	local ok, hui = pcall(gethui)
	if ok and hui then return cloneref(hui) end
	if CoreGui then return CoreGui end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function MakeDraggable(handle, target)
	-- Smooth drag: lerp toward a goal each frame, but only while moving.
	local dragging = false
	local dragStart, startPos
	local goalPos = target.Position
	local currentPos = target.Position
	local activeInput = nil
	local renderConn = nil

	local function setGoalFrom(inputPos)
		local delta = inputPos - dragStart
		goalPos = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end

	local function stopDragLoop()
		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
	end

	local function startDragLoop()
		if renderConn then return end
		renderConn = connectCapped(function(dt)
			if not target.Parent then
				stopDragLoop()
				return
			end

			local a = 1 - math.exp(-dt * 18)
			local cx, cy = currentPos.X, currentPos.Y
			local gx, gy = goalPos.X, goalPos.Y
			currentPos = UDim2.new(
				cx.Scale + (gx.Scale - cx.Scale) * a,
				cx.Offset + (gx.Offset - cx.Offset) * a,
				cy.Scale + (gy.Scale - cy.Scale) * a,
				cy.Offset + (gy.Offset - cy.Offset) * a
			)

			local dx = math.abs(currentPos.X.Offset - goalPos.X.Offset)
			local dy = math.abs(currentPos.Y.Offset - goalPos.Y.Offset)
			if not dragging and dx < 0.25 and dy < 0.25 then
				currentPos = goalPos
				target.Position = currentPos
				stopDragLoop()
				return
			end

			target.Position = currentPos
		end)
	end

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			activeInput = input
			dragStart = input.Position
			startPos = goalPos
			currentPos = target.Position
			startDragLoop()
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					activeInput = nil
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			setGoalFrom(input.Position)
			startDragLoop()
		elseif input == activeInput then
			setGoalFrom(input.Position)
			startDragLoop()
		end
	end)
end

function Library:CreateWindow(opts)
	opts = opts or {}
	local titleText    = opts.Title    or "Blurred"
	local subTitleText = opts.SubTitle or ""
	local footerLeft   = opts.FooterLeft
	local footerRight  = opts.FooterRight
	local size         = opts.Size or Vector2.new(760, 560)
	local logoImage    = opts.Logo   -- optional; nil => "Blurred" wordmark
	local logoLetter   = opts.LogoText or string.sub(titleText, 1, 1)

	local function resolveImage(v)
		if not v or v == "" then return nil end
		if string.match(v, "^rbxassetid://") or string.match(v, "^rbxasset://")
		or string.match(v, "^http") then
			return v
		end
		return Icons.Get(v)
	end
	local logoAsset = resolveImage(logoImage)

	local SIDEBAR_W = 140
	local SEARCH_W = 120
	local HEADER_H = 56

	local ScreenGui = Create("ScreenGui", {
		Name = "Blurred",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
		DisplayOrder = 999,
	})
	pcall(function() ScreenGui.Parent = getGuiParent() end)
	if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

	-- Full-screen modal sink: unlocks cursor and blocks game click-through while menu is open
	local MenuSink = Create("TextButton", {
		Name = "MenuInputSink",
		Parent = ScreenGui,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		Active = true,
		Selectable = false,
		Visible = Library.Toggled ~= false,
		ZIndex = 1,
	})

	local Main = Create("Frame", {
		Name = "Main",
		Parent = ScreenGui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, size.X, 0, size.Y),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		ZIndex = 10,
		Active = true,
	})
	Corner(6, Main)
	Stroke(Color3.fromRGB(10, 10, 10), 1, Main)

	local Header = Create("Frame", {
		Name = "Header",
		Parent = Main,
		Size = UDim2.new(1, 0, 0, HEADER_H),
		BackgroundColor3 = Theme.Header,
		BorderSizePixel = 0,
	})
	Corner(6, Header)
	Create("Frame", {
		Parent = Header,
		Position = UDim2.new(0, 0, 1, -8),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Theme.Header,
		BorderSizePixel = 0,
	})
	-- vertical rule aligning header logo column with the sidebar
	Create("Frame", {
		Parent = Header, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(0, SIDEBAR_W, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10), BorderSizePixel = 0,
	})
	MakeDraggable(Header, Main)

	local LogoImage = Create("ImageLabel", {
		Name = "LogoImage",
		Parent = Header,
		Position = UDim2.new(0, SIDEBAR_W / 2, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 36, 0, 36),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = logoAsset or "", ScaleType = Enum.ScaleType.Fit,
		Visible = (logoAsset ~= nil),
	})

	-- centered wordmark with textÃ¢â€ â€™accent gradient + underline
	local LogoWrap = Create("Frame", {
		Name = "LogoWrap",
		Parent = Header,
		Position = UDim2.new(0, SIDEBAR_W / 2, 0.5, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Visible = (logoAsset == nil),
	})
	local LogoText = Create("TextLabel", {
		Name = "LogoText",
		Parent = LogoWrap,
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		FontFace = Library.Font,
		Text = titleText,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local LogoGrad = Create("UIGradient", {
		Parent = LogoText,
		Color = textAccentGradient(),
		Rotation = 0,
	})
	local LogoLine = Create("Frame", {
		Name = "LogoLine",
		Parent = LogoWrap,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, 3),
		Size = UDim2.new(1, 0, 0, 1),
	})
	local LogoLineGrad = Create("UIGradient", {
		Parent = LogoLine,
		Color = textAccentGradient(),
		Rotation = 0,
	})
	local LogoRow = nil

	local TabBar = Create("Frame", {
		Name = "TabBar",
		Parent = Header,
		Position = UDim2.new(0, SIDEBAR_W + 8, 0, 0),
		Size = UDim2.new(1, -(SIDEBAR_W + 8) - (SEARCH_W + 28), 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	})
	Create("UIListLayout", {
		Parent = TabBar,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	})

	local SearchBox = Create("Frame", {
		Name = "SearchBox",
		Parent = Header,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, SEARCH_W, 0, 26),
		BackgroundColor3 = Color3.fromRGB(235, 235, 235),
		BorderSizePixel = 0,
	})
	Corner(3, SearchBox)

	local Search = Create("TextBox", {
		Name = "Search",
		Parent = SearchBox,
		Size = UDim2.new(1, -28, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = Library.Font,
		PlaceholderText = "Search",
		PlaceholderColor3 = Color3.fromRGB(120, 120, 120),
		Text = "",
		TextColor3 = Color3.fromRGB(20, 20, 20),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
	})
	Create("UIPadding", {
		Parent = Search,
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 4),
	})

	Create("ImageLabel", {
		Name = "SearchIcon",
		Parent = SearchBox,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -7, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		Image = Library.Icons.Get("search") or "",
		ImageColor3 = Color3.fromRGB(100, 100, 100),
		ScaleType = Enum.ScaleType.Fit,
	})

	local Body = Create("Frame", {
		Name = "Body",
		Parent = Main,
		Position = UDim2.new(0, 0, 0, HEADER_H),
		Size = UDim2.new(1, 0, 1, -HEADER_H - 28),
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
	})

	local Sidebar = Create("Frame", {
		Name = "Sidebar",
		Parent = Body,
		Size = UDim2.new(0, SIDEBAR_W, 1, 0),
		BackgroundColor3 = Theme.Sidebar,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	Create("Frame", { -- divider
		Parent = Sidebar, AnchorPoint = Vector2.new(1,0),
		Position = UDim2.new(1,0,0,0), Size = UDim2.new(0,1,1,0),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10), BorderSizePixel = 0,
	})
	local SubTabList = Create("Frame", {
		Parent = Sidebar, BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0),
	})
	Create("UIListLayout", {
		Parent = SubTabList, SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
	})
	Padding(0, SubTabList)

	-- shared active-subtab accent pill (slides + stretch/squish between entries)
	local SUBTAB_IND_W, SUBTAB_IND_H, SUBTAB_IND_X = 9, 11, -6
	local SubTabIndicator = Create("Frame", {
		Name = "SubTabIndicator",
		Parent = Sidebar, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, SUBTAB_IND_X, 0, 15),
		Size = UDim2.new(0, SUBTAB_IND_W, 0, SUBTAB_IND_H),
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		ZIndex = 5,
	})
	Corner(6, SubTabIndicator)

	local Content = Create("Frame", {
		Name = "Content",
		Parent = Body,
		Position = UDim2.new(0, SIDEBAR_W, 0, 0),
		Size = UDim2.new(1, -SIDEBAR_W, 1, 0),
		BackgroundTransparency = 1,
	})

	local Overlay = Create("Frame", {
		Name = "Overlay",
		Parent = Main,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 50,
	})
	-- invisible full-window sink so open popups (colorpickers) don't click through
	local PopupBlocker = Create("TextButton", {
		Name = "PopupBlocker",
		Parent = Overlay,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		Active = true,
		ZIndex = 65,
	})
	PopupBlocker.MouseButton1Click:Connect(function()
		if Library.OpenColorPicker then Library.OpenColorPicker.Close() end
		if Library.OpenDropdown then Library.OpenDropdown.Close() end
		if Library.OpenKeybindMenu then Library.OpenKeybindMenu.CloseMenu() end
	end)

	local Footer = Create("Frame", {
		Name = "Footer",
		Parent = Main,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Theme.Footer,
		BorderSizePixel = 0,
	})
	Corner(6, Footer)
	Create("Frame", { -- mask top corners
		Parent = Footer, Size = UDim2.new(1,0,0,8),
		BackgroundColor3 = Theme.Footer, BorderSizePixel = 0,
	})
	local FooterLeft = Create("TextLabel", {
		Parent = Footer, BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(0.6, 0, 1, 0),
		FontFace = Library.Font, TextSize = 13, TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = footerLeft == nil,
		Text = footerLeft or footerDiscordMark(Theme.Accent),
	})
	local FooterRight = Create("TextLabel", {
		Parent = Footer, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1,0),
		Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.4, 0, 1, 0),
		FontFace = Library.Font, TextSize = 13, TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Right,
		RichText = footerRight == nil,
		Text = footerRight or footerSiteMark(Theme.Accent),
	})

	local Window = {
		ScreenGui   = ScreenGui,
		MenuSink    = MenuSink,
		Main        = Main,
		Header      = Header,
		TabBar      = TabBar,
		Search      = Search,
		Sidebar     = Sidebar,
		SubTabList  = SubTabList,
		SubTabIndicator = SubTabIndicator,
		Content     = Content,
		Overlay     = Overlay,
		PopupBlocker = PopupBlocker,
		Footer      = Footer,
		FooterLeftLabel = FooterLeft,
		FooterRightLabel = FooterRight,
		FooterLeftRich = footerLeft == nil,
		FooterRightRich = footerRight == nil,
		TitleText = titleText,
		LogoImage   = LogoImage,
		LogoWrap    = LogoWrap,
		LogoText    = LogoText,
		LogoGrad    = LogoGrad,
		LogoLineGrad = LogoLineGrad,
		LogoRow     = LogoRow,
		Tabs        = {},
		ActiveTab   = nil,
		Keybinds    = {},        -- registered keybinds (for the keybind list)
		_keybindListeners = {},  -- KeybindList refreshers
		_subTabIndToken = 0,
		_resolveImage = resolveImage,
		_introDone  = opts.Intro == false,
		_introFloats = {},
	}

	-- world blur behind overlays while the menu is open
	do
		local BLUR_MAX = opts.MenuBlurSize or 22
		local blurFx = nil
		pcall(function()
			for _, c in ipairs(Lighting:GetChildren()) do
				if c:IsA("BlurEffect") and c.Name == "BlurredMenuBlur" then
					c:Destroy()
				end
			end
			blurFx = Instance.new("BlurEffect")
			blurFx.Name = "BlurredMenuBlur"
			blurFx.Size = 0
			blurFx.Enabled = true
			blurFx.Parent = Lighting
		end)
		Window._menuBlur = blurFx
		function Window._setMenuBlur(on, ramp)
			if not blurFx or not blurFx.Parent then return end
			if on then
				blurFx.Enabled = true
				if ramp then
					blurFx.Size = 0
					TweenService:Create(blurFx,
						TweenInfo.new(1.35 * Anim.SpeedScale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Size = BLUR_MAX }):Play()
				else
					TweenService:Create(blurFx,
						TweenInfo.new(0.45 * Anim.SpeedScale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
						{ Size = BLUR_MAX }):Play()
				end
			else
				TweenService:Create(blurFx,
					TweenInfo.new(0.35 * Anim.SpeedScale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = 0 }):Play()
			end
		end
		function Window._destroyMenuBlur()
			if blurFx then
				pcall(function() blurFx:Destroy() end)
				blurFx = nil
				Window._menuBlur = nil
			end
		end
		-- if intro is skipped, blur immediately while menu starts open
		if Window._introDone and Library.Toggled then
			task.defer(function()
				Window._setMenuBlur(true, true)
				Library:Notify("Blurred has initialized")
			end)
		end
	end


	-- called by makeKeybind for every keybind created; keeps any open
	-- KeybindList in sync as binds are added / changed / triggered.
	function Window._registerKeybind(kb)
		table.insert(Window.Keybinds, kb)
		kb.OnChange = function()
			for _, refresh in ipairs(Window._keybindListeners) do refresh() end
		end
		for _, refresh in ipairs(Window._keybindListeners) do refresh() end
	end

	-- Watermark / keybind list register here so the intro can float them in
	-- only after the launch sequence fully finishes.
	function Window._registerIntroFloat(frame, targetPos, startPos, api)
		if Window._introDone or not frame then return end
		frame.Visible = false
		table.insert(Window._introFloats, {
			Frame = frame,
			Target = targetPos or frame.Position,
			Start = startPos or UDim2.new(0.5, 0, 0.5, 0),
			Api = api,
			PendingVisible = true,
		})
	end

	Search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(Search.Text)
		if Window.ActiveTab and Window.ActiveTab.ActiveSubTab then
			Window.ActiveTab.ActiveSubTab:_filter(q)
		end
	end)

	--------------------------------------------------------------
	-- INTRO LAUNCHER  (Launch Ã¢â€ â€™ ring % Ã¢â€ â€™ greeting Ã¢â€ â€™ main UI)
	--------------------------------------------------------------
	if not Window._introDone then
		Main.Visible = false

		local userName = LocalPlayer.DisplayName or LocalPlayer.Name or "User"
		local greeting = opts.IntroGreeting or ("Hello, " .. userName)

		-- Frame (not CanvasGroup) keeps text sharp
		local Launcher = Create("Frame", {
			Name = "Launcher", Parent = ScreenGui,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 100,
		})
		Window._launcher = Launcher

		-- compact panel: Blurred title sits right above Launch
		local LaunchPanel = Create("Frame", {
			Name = "LaunchPanel", Parent = Launcher,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 236, 0, 132),
			BackgroundColor3 = Theme.Background,
			BorderSizePixel = 0,
			ZIndex = 101,
		})
		Corner(8, LaunchPanel)
		local panelStroke = Stroke(Color3.fromRGB(10, 10, 10), 1, LaunchPanel)

		local PanelHeader = Create("Frame", {
			Name = "Header", Parent = LaunchPanel,
			Size = UDim2.new(1, 0, 0, 22),
			BackgroundColor3 = Theme.Header,
			BorderSizePixel = 0,
			ZIndex = 102,
		})
		Corner(8, PanelHeader)
		Create("Frame", {
			Parent = PanelHeader,
			Position = UDim2.new(0, 0, 1, -8),
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = Theme.Header,
			BorderSizePixel = 0,
			ZIndex = 102,
		})

		local BrandWrap = Create("Frame", {
			Name = "BrandWrap", Parent = LaunchPanel,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -78),
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			ZIndex = 103,
		})
		local BrandLabel = Create("TextLabel", {
			Name = "Brand", Parent = BrandWrap,
			BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.XY,
			FontFace = Library.Font,
			Text = titleText or "Blurred",
			TextSize = 22,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeTransparency = 1,
			ZIndex = 103,
		})
		Create("UIGradient", {
			Parent = BrandLabel,
			Color = textAccentGradient(),
			Rotation = 0,
		})
		local BrandLine = Create("Frame", {
			Name = "BrandLine", Parent = BrandWrap,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, 2),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 103,
		})
		Create("UIGradient", {
			Parent = BrandLine,
			Color = textAccentGradient(),
			Rotation = 0,
		})

		-- black/grey Launch button + soft hover
		local BTN_W, BTN_H = 170, 40
		local BTN_BG = Color3.fromRGB(32, 32, 34)
		local BTN_HOVER = Color3.fromRGB(48, 48, 52)
		local BTN_BORDER = Color3.fromRGB(70, 70, 74)
		local checkIcon = Library.Icons.Get("check") or ""

		local LaunchBtn = Create("TextButton", {
			Name = "LaunchButton", Parent = LaunchPanel,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -22),
			Size = UDim2.new(0, BTN_W, 0, BTN_H),
			BackgroundColor3 = BTN_BG,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ClipsDescendants = true,
			ZIndex = 103,
		})
		Corner(14, LaunchBtn)
		local launchStroke = Stroke(BTN_BORDER, 1, LaunchBtn)
		local btnScale = Create("UIScale", { Scale = 1, Parent = LaunchBtn })
		local HoverGlow = Create("Frame", {
			Name = "HoverGlow", Parent = LaunchBtn,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 104,
		})
		Corner(14, HoverGlow)
		local LaunchText = Create("TextLabel", {
			Name = "Label", Parent = LaunchBtn,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			FontFace = Library.Font,
			Text = "Launch",
			TextSize = 15,
			TextColor3 = Color3.fromRGB(210, 210, 214),
			TextStrokeTransparency = 1,
			ZIndex = 105,
		})

		local launching = false
		LaunchBtn.MouseEnter:Connect(function()
			if launching then return end
			Tween(LaunchBtn, 0.28, { BackgroundColor3 = BTN_HOVER })
			Tween(LaunchText, 0.28, { TextColor3 = Color3.fromRGB(255, 255, 255) })
			Tween(launchStroke, 0.28, { Color = Color3.fromRGB(120, 120, 126) })
			Tween(HoverGlow, 0.32, { BackgroundTransparency = 0.92 })
			Tween(btnScale, 0.28, { Scale = 1.03 })
		end)
		LaunchBtn.MouseLeave:Connect(function()
			if launching then return end
			Tween(LaunchBtn, 0.32, { BackgroundColor3 = BTN_BG })
			Tween(LaunchText, 0.32, { TextColor3 = Color3.fromRGB(210, 210, 214) })
			Tween(launchStroke, 0.32, { Color = BTN_BORDER })
			Tween(HoverGlow, 0.35, { BackgroundTransparency = 1 })
			Tween(btnScale, 0.32, { Scale = 1 })
		end)

		-- logo + bare white check (fade in/out together)
		local launchLogoUrl = "https://files.catbox.moe/5tlbqc.png"
		local launchLogoAsset = GetCachedUrl(launchLogoUrl, "watermark_icon.png")
		local LaunchLogo = Create("ImageLabel", {
			Name = "LaunchLogo", Parent = LaunchPanel,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.42, 0),
			Size = UDim2.new(0, 52, 0, 52),
			BackgroundTransparency = 1,
			Image = launchLogoAsset,
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Visible = false,
			ZIndex = 106,
		})
		local CheckMark = Create("ImageLabel", {
			Name = "CheckIcon", Parent = LaunchPanel,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -32),
			Size = UDim2.new(0, 22, 0, 22),
			BackgroundTransparency = 1,
			Image = checkIcon,
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Fit,
			Visible = false,
			ZIndex = 106,
		})
		local checkScale = Create("UIScale", { Scale = 0.85, Parent = CheckMark })

		-- leftÃ¢â€ â€™right loading bar, centered in panel
		local ProgressHost = Create("Frame", {
			Name = "Progress", Parent = LaunchPanel,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.55, 0),
			Size = UDim2.new(0, 160, 0, 36),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 107,
		})
		local PercentLabel = Create("TextLabel", {
			Parent = ProgressHost, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			FontFace = Library.Font, TextSize = 12,
			Text = "0%", TextColor3 = Color3.fromRGB(160, 160, 166),
			TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 108,
		})
		local BarTrack = Create("Frame", {
			Name = "Track", Parent = ProgressHost,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = Color3.fromRGB(36, 36, 40),
			BorderSizePixel = 0,
			ClipsDescendants = true,
			ZIndex = 107,
		})
		Corner(2, BarTrack)
		local BarFill = Create("Frame", {
			Name = "Fill", Parent = BarTrack,
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			ZIndex = 108,
		})
		Corner(2, BarFill)

		-- greeting dead-center in the panel
		local HelloLabel = Create("TextLabel", {
			Name = "Greeting", Parent = LaunchPanel,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(1, -28, 0, 28),
			BackgroundTransparency = 1,
			FontFace = Library.Font, TextSize = 17,
			Text = greeting, TextColor3 = Theme.Text,
			TextTransparency = 1, TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			Visible = false, ZIndex = 107,
		})

		local function setBarProgress(p)
			p = math.clamp(p, 0, 1)
			BarFill.Size = UDim2.new(p, 0, 1, 0)
		end

		LaunchBtn.MouseButton1Click:Connect(function()
			if launching or Window._introDone then return end
			launching = true
			task.spawn(function()
				local function aborted()
					return Window._unloaded or not Launcher.Parent
				end
				local function waitT(t)
					task.wait(t * Anim.SpeedScale)
					return aborted()
				end

				-- soft fade brand
				Tween(BrandLabel, 0.3, { TextTransparency = 1 })
				Tween(BrandLine, 0.3, { BackgroundTransparency = 1 })
				if waitT(0.28) then return end
				BrandWrap.Visible = false

				-- gentle press
				Tween(HoverGlow, 0.22, { BackgroundTransparency = 0.88 })
				Tween(btnScale, 0.26, { Scale = 1.06 })
				Tween(LaunchBtn, 0.26, { BackgroundColor3 = BTN_HOVER })
				Tween(LaunchText, 0.26, { TextColor3 = Color3.fromRGB(255, 255, 255) })
				if waitT(0.28) then return end

				-- dissolve button Ã¢â€ â€™ bare white check
				Tween(LaunchText, 0.18, { TextTransparency = 1 })
				Tween(HoverGlow, 0.2, { BackgroundTransparency = 1 })
				Tween(launchStroke, 0.22, { Transparency = 1 })
				Tween(btnScale, 0.32, { Scale = 0.7 })
				Tween(LaunchBtn, 0.32, {
					BackgroundTransparency = 1,
					Size = UDim2.new(0, BTN_H, 0, BTN_H),
				})
				if waitT(0.28) then return end
				LaunchBtn.Visible = false

				LaunchLogo.Visible = true
				LaunchLogo.ImageTransparency = 1
				CheckMark.Position = UDim2.new(0.5, 0, 1, -32)
				CheckMark.Visible = true
				checkScale.Scale = 0.7
				Tween(LaunchLogo, 0.32, { ImageTransparency = 0 })
				Tween(CheckMark, 0.32, { ImageTransparency = 0 })
				Tween(checkScale, 0.36, { Scale = 1 })
				if waitT(0.38) then return end

				-- subtle nod: -30Ã‚Â° then settle
				Tween(CheckMark, 0.34, { Rotation = -30 })
				if waitT(0.36) then return end
				Tween(CheckMark, 0.4, { Rotation = 0 })
				if waitT(0.42) then return end

				-- logo + check out Ã¢â€ â€™ bar in (panel stays)
				Tween(LaunchLogo, 0.28, { ImageTransparency = 1 })
				Tween(CheckMark, 0.28, { ImageTransparency = 1 })
				Tween(checkScale, 0.28, { Scale = 0.9 })
				if waitT(0.3) then return end
				LaunchLogo.Visible = false
				CheckMark.Visible = false

				ProgressHost.Visible = true
				PercentLabel.Text = "0%"
				setBarProgress(0)
				BarFill.BackgroundTransparency = 0
				BarTrack.BackgroundTransparency = 0
				Tween(PercentLabel, 0.28, { TextTransparency = 0 })

				local duration = 1.7
				local t0 = os.clock()
				local done = false
				local progConn
				progConn = connectCapped(function()
					if done or aborted() then
						done = true
						if progConn then progConn:Disconnect() progConn = nil end
						return
					end
					local t = math.clamp((os.clock() - t0) / (duration * Anim.SpeedScale), 0, 1)
					-- smoothstep
					local eased = t * t * (3 - 2 * t)
					setBarProgress(eased)
					PercentLabel.Text = tostring(math.floor(eased * 100 + 0.5)) .. "%"
					if t >= 1 then
						PercentLabel.Text = "100%"
						done = true
						if progConn then progConn:Disconnect() progConn = nil end
					end
				end)
				while not done do
					if aborted() then
						if progConn then progConn:Disconnect() end
						return
					end
					task.wait()
				end
				if aborted() then return end
				if waitT(0.18) then return end

				Tween(PercentLabel, 0.28, { TextTransparency = 1 })
				Tween(BarFill, 0.3, { BackgroundTransparency = 1 })
				Tween(BarTrack, 0.3, { BackgroundTransparency = 1 })
				if waitT(0.32) then return end
				ProgressHost.Visible = false

				-- Hello, Name Ã¢â‚¬â€ exact center, fade only (no scale)
				HelloLabel.Visible = true
				HelloLabel.TextTransparency = 1
				Tween(HelloLabel, 0.55, { TextTransparency = 0 })
				if waitT(1.15) then return end

				Tween(HelloLabel, 0.5, { TextTransparency = 1 })
				if waitT(0.52) then return end
				HelloLabel.Visible = false

				-- stretch panel Ã¢â€ â€™ main window
				local morphT = 0.62
				Tween(LaunchPanel, morphT, { Size = UDim2.new(0, size.X, 0, size.Y) })
				Tween(PanelHeader, morphT, { Size = UDim2.new(1, 0, 0, HEADER_H) })
				if waitT(morphT + 0.04) then return end

				local mainScale = Create("UIScale", { Scale = 0.985, Parent = Main })
				local mainBg = Main.BackgroundTransparency
				Main.BackgroundTransparency = 1
				Main.Visible = Library.Toggled
				if Main.Visible then
					fadePage(Main, false, 0)
					fadePage(Main, true, 0.45)
					Tween(Main, 0.45, { BackgroundTransparency = mainBg })
					Tween(mainScale, 0.45, { Scale = 1 })
				end
				Tween(LaunchPanel, 0.4, { BackgroundTransparency = 1 })
				Tween(panelStroke, 0.4, { Transparency = 1 })
				Tween(PanelHeader, 0.4, { BackgroundTransparency = 1 })
				for _, d in ipairs(LaunchPanel:GetDescendants()) do
					if d:IsA("Frame") and d.BackgroundTransparency < 1 then
						Tween(d, 0.4, { BackgroundTransparency = 1 })
					elseif d:IsA("UIStroke") then
						Tween(d, 0.4, { Transparency = 1 })
					end
				end
				if waitT(0.45) then return end

				if Window._setMenuBlur then
					Window._setMenuBlur(true, true)
				end

				Window._introDone = true
				for _, entry in ipairs(Window._introFloats) do
					local fr = entry.Frame
					if fr and fr.Parent then
						local want = entry.PendingVisible
						if entry.Api and entry.Api._pendingVisible ~= nil then
							want = entry.Api._pendingVisible
						end
						if want then
							fr.Position = entry.Start
							fr.Visible = true
							local bg0 = fr.BackgroundTransparency
							fr.BackgroundTransparency = 1
							Tween(fr, 0.6, {
								Position = entry.Target,
								BackgroundTransparency = bg0,
							})
							for _, d in ipairs(fr:GetDescendants()) do
								if d:IsA("TextLabel") or d:IsA("TextButton") then
									local tt = d.TextTransparency
									d.TextTransparency = 1
									Tween(d, 0.55, { TextTransparency = tt })
								elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
									local it = d.ImageTransparency
									d.ImageTransparency = 1
									Tween(d, 0.55, { ImageTransparency = it })
								elseif d:IsA("UIStroke") then
									local st = d.Transparency
									d.Transparency = 1
									Tween(d, 0.55, { Transparency = st })
								elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
									local bt = d.BackgroundTransparency
									d.BackgroundTransparency = 1
									Tween(d, 0.55, { BackgroundTransparency = bt })
								end
							end
						else
							fr.Visible = false
						end
					end
				end

				if waitT(0.55) then return end
				Window._introFloats = {}
				if Launcher and Launcher.Parent then Launcher:Destroy() end
				Window._launcher = nil

				Library:Notify("Blurred has initialized")
			end)
		end)
	end


	setmetatable(Window, { __index = Library._WindowMethods })
	table.insert(Library.Windows, Window)
	-- the menu starts open: hide core gui + unlock the mouse now
	if Library.Toggled and Library._applyMenuOpenState then
		Library._applyMenuOpenState()
	end
	return Window
end

Library._WindowMethods = {}

local SUBTAB_IND_W, SUBTAB_IND_H, SUBTAB_IND_X = 9, 11, -6

function Library._WindowMethods:_moveSubTabIndicator(SubTab, animate)
	local ind = self.SubTabIndicator
	if not ind or not SubTab or not SubTab.SidebarButton then return end
	local btn = SubTab.SidebarButton
	if not btn.Visible then
		Tween(ind, 0.12, { BackgroundTransparency = 1 })
		return
	end

	local function targetY()
		local sidebar = self.Sidebar
		return (btn.AbsolutePosition.Y - sidebar.AbsolutePosition.Y) + btn.AbsoluteSize.Y * 0.5
	end

	self._subTabIndToken = (self._subTabIndToken or 0) + 1
	local token = self._subTabIndToken

	local function settle(y)
		if self._subTabIndToken ~= token then return end
		Tween(ind, 0.16, {
			Position = UDim2.new(0, SUBTAB_IND_X, 0, y),
			Size = UDim2.new(0, SUBTAB_IND_W, 0, SUBTAB_IND_H),
			BackgroundTransparency = 0,
		}, Enum.EasingStyle.Back)
	end

	if not animate then
		task.defer(function()
			if self._subTabIndToken ~= token then return end
			local y = targetY()
			ind.Position = UDim2.new(0, SUBTAB_IND_X, 0, y)
			ind.Size = UDim2.new(0, SUBTAB_IND_W, 0, SUBTAB_IND_H)
			ind.BackgroundTransparency = 0
		end)
		return
	end

	-- wait one frame so AbsolutePosition is current after visibility changes
	task.defer(function()
		if self._subTabIndToken ~= token then return end
		local y = targetY()
		local curY = ind.Position.Y.Offset
		local dist = math.abs(y - curY)
		local wasHidden = ind.BackgroundTransparency > 0.5

		if wasHidden or dist < 1 then
			ind.Position = UDim2.new(0, SUBTAB_IND_X, 0, y)
			ind.Size = UDim2.new(0, SUBTAB_IND_W, 0, SUBTAB_IND_H)
			Tween(ind, 0.14, { BackgroundTransparency = 0 })
			return
		end

		-- stretch toward the midpoint, then squish into the target
		local midY = (curY + y) * 0.5
		local stretchH = math.clamp(dist * 0.85 + SUBTAB_IND_H, SUBTAB_IND_H + 6, 48)
		Tween(ind, 0.09, {
			Position = UDim2.new(0, SUBTAB_IND_X, 0, midY),
			Size = UDim2.new(0, SUBTAB_IND_W - 2, 0, stretchH),
			BackgroundTransparency = 0,
		}, Enum.EasingStyle.Quad)
		task.delay(0.09 * (Anim.SpeedScale or 1), function()
			settle(targetY())
		end)
	end)
end

function Library._WindowMethods:AddTab(name, icon)
	local Window = self

	local PAD_X = 8
	local ICON_SIZE = 16
	local LABEL_GAP = 6
	local EXPAND_T = 0.14
	local EXPAND_STYLE = Enum.EasingStyle.Quart

	local iconAsset = icon and Library.Icons.Get(icon) or nil
	local collapsedW = PAD_X * 2 + ICON_SIZE

	-- estimate label width; refine async with FontFace bounds when possible
	local labelW = math.max(20, math.ceil(#tostring(name) * 7.2))
	task.spawn(function()
		local ok, size = pcall(function()
			local p = Instance.new("GetTextBoundsParams")
			p.Text = name
			p.Size = 13
			p.Font = Library.Font
			p.Width = 10000
			return TextService:GetTextBoundsAsync(p)
		end)
		if ok and typeof(size) == "Vector2" then
			labelW = math.max(12, math.ceil(size.X))
			if Label then
				Label.Size = UDim2.new(0, labelW, 1, 0)
			end
			if Tab and Tab._expanded then
				setExpanded(true, true)
			end
		end
	end)

	local Btn = Create("TextButton", {
		Name = "Tab_" .. name,
		Parent = Window.TabBar,
		Size = UDim2.new(0, collapsedW, 1, 0),
		BackgroundColor3 = Theme.HeaderTab,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})

	local IconLbl = Create("ImageLabel", {
		Parent = Btn, BackgroundTransparency = 1,
		Position = UDim2.new(0, PAD_X, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
		Image = iconAsset or "", ImageColor3 = Theme.TabInactive,
		ScaleType = Enum.ScaleType.Fit,
		Visible = (iconAsset ~= nil),
		ZIndex = 3,
	})
	-- letter fallback when no lucide icon was provided
	local LetterLbl = nil
	if not iconAsset then
		LetterLbl = Create("TextLabel", {
			Parent = Btn, BackgroundTransparency = 1,
			Position = UDim2.new(0, PAD_X, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
			FontFace = Library.Font, TextSize = 13,
			Text = string.upper(string.sub(name, 1, 1)),
			TextColor3 = Theme.TabInactive,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		})
	end

	-- clip mask: grows open to wipe-reveal solid text (no transparency dissolve)
	local LabelClip = Create("Frame", {
		Name = "LabelClip", Parent = Btn,
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.new(0, PAD_X + ICON_SIZE + LABEL_GAP, 0, 0),
		Size = UDim2.new(0, 0, 1, 0),
		ClipsDescendants = true,
		ZIndex = 2,
	})
	local Label = Create("TextLabel", {
		Parent = LabelClip, BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(0, labelW, 1, 0),
		FontFace = Library.Font, TextSize = 13, Text = name,
		TextColor3 = Theme.TabInactive,
		TextTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 2,
	})

	local Tab
	local setExpanded

	Tab = {
		Window   = Window,
		Name     = name,
		Button   = Btn,
		IconLbl  = IconLbl,
		LetterLbl = LetterLbl,
		Label    = Label,
		LabelClip = LabelClip,
		IconSize = ICON_SIZE,
		ColorInactive = Theme.TabInactive,
		ColorActive   = Theme.TabActive,
		SubTabs  = {},
		ActiveSubTab = nil,
		_expanded = false,
	}
	setmetatable(Tab, { __index = Library._TabMethods })

	local function expandedW()
		return collapsedW + LABEL_GAP + labelW
	end

	setExpanded = function(on, instant)
		Tab._expanded = on
		local tw = on and expandedW() or collapsedW
		local lw = on and labelW or 0
		-- icon stays left; button growth shoves following tab icons right
		if instant then
			Btn.Size = UDim2.new(0, tw, 1, 0)
			LabelClip.Size = UDim2.new(0, lw, 1, 0)
			Label.TextTransparency = 0
		else
			Tween(Btn, EXPAND_T, { Size = UDim2.new(0, tw, 1, 0) }, EXPAND_STYLE)
			Tween(LabelClip, EXPAND_T, { Size = UDim2.new(0, lw, 1, 0) }, EXPAND_STYLE)
			Label.TextTransparency = 0
		end
	end

	local function paint(col, instant)
		if instant then
			Label.TextColor3 = col
			IconLbl.ImageColor3 = col
			if LetterLbl then LetterLbl.TextColor3 = col end
		else
			Tween(Label, 0.1, { TextColor3 = col })
			Tween(IconLbl, 0.1, { ImageColor3 = col })
			if LetterLbl then Tween(LetterLbl, 0.1, { TextColor3 = col }) end
		end
	end
	Tab._paint = paint
	Tab._setExpanded = setExpanded

	Btn.MouseEnter:Connect(function()
		Tab._hovered = true
		setExpanded(true, false)
		if Window.ActiveTab ~= Tab then
			Tween(Btn, 0.1, { BackgroundTransparency = 0.55 })
			paint(Theme.TabHover, false)
		end
	end)
	Btn.MouseLeave:Connect(function()
		Tab._hovered = false
		local active = (Window.ActiveTab == Tab)
		-- active tab keeps its name revealed
		if not active then
			setExpanded(false, false)
		end
		Tween(Btn, 0.1, { BackgroundTransparency = active and 0.7 or 1 })
		paint(active and Theme.TabActive or Theme.TabInactive, false)
	end)
	Btn.MouseButton1Click:Connect(function()
		Window:_selectTab(Tab)
	end)

	table.insert(Window.Tabs, Tab)
	if not Window.ActiveTab then
		Window:_selectTab(Tab)
	end
	return Tab
end

function Library._WindowMethods:_selectTab(Tab)
	if Library.OpenDropdown then Library.OpenDropdown.Close() end
	if Library.OpenColorPicker then Library.OpenColorPicker.Close() end
	if Library.OpenKeybindMenu then Library.OpenKeybindMenu.CloseMenu() end
	local outgoing = self.ActiveTab
	local switching = (outgoing ~= nil and outgoing ~= Tab)

	-- find the page currently on screen (belongs to the outgoing tab) so we
	-- can fade IT out too, instead of hard-hiding it.
	local outgoingPage
	if switching and outgoing.ActiveSubTab then
		local p = outgoing.ActiveSubTab.Page
		if p.Visible then outgoingPage = p end
	end

	for _, t in ipairs(self.Tabs) do
		local active = (t == Tab)
		Tween(t.Button, 0.15, { BackgroundTransparency = active and 0.7 or 1 })
		local col = active and Theme.TabActive or Theme.TabInactive
		if t._paint then
			t._paint(col, false)
		else
			Tween(t.Label, 0.15, { TextColor3 = col })
			Tween(t.IconLbl, 0.15, { ImageColor3 = col })
		end
		-- keep active (or hovered) tab name open; collapse others
		if t._setExpanded then
			t._setExpanded(active or t._hovered, false)
		end
		-- show/hide the sub-tab column. Hide other tabs' pages instantly, EXCEPT
		-- the outgoing page (we fade that one out below).
		for _, st in ipairs(t.SubTabs) do
			st.SidebarButton.Visible = active
			if not active and st.Page ~= outgoingPage then
				st.Page.Visible = false
			end
		end
	end

	self.ActiveTab = Tab

	local function revealNew()
		if Tab.ActiveSubTab == nil and Tab.SubTabs[1] then
			Tab:_selectSubTab(Tab.SubTabs[1], true)
		elseif Tab.ActiveSubTab then
			Tab:_selectSubTab(Tab.ActiveSubTab, true)
		end
	end

	if outgoingPage then
		-- fade the outgoing tab's content out, then reveal + fade in the new tab's
		fadePage(outgoingPage, false, 0.12)
		task.delay(0.12, function()
			outgoingPage.Visible = false
			revealNew()
		end)
	else
		revealNew()
	end
end

function Library._WindowMethods:SetMasterSwitch(cfg)
	cfg = cfg or {}
	local value = cfg.Default or false
	local flag  = cfg.Flag

	local Holder = Create("Frame", {
		Name = "MasterSwitch",
		Parent = self.Sidebar,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0,
	})
	Create("Frame", {
		Parent = Holder, Size = UDim2.new(1,0,0,1),
		BackgroundColor3 = Color3.fromRGB(10, 10, 10), BorderSizePixel = 0,
	})
	local Box = Create("TextButton", {
		Parent = Holder, Text = "",
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 16, 0, 16),
		BackgroundColor3 = Theme.Element,
		AutoButtonColor = false, BorderSizePixel = 0,
	})
	Corner(3, Box)
	Stroke(Theme.ElementBorder, 1, Box)
	Box.ClipsDescendants = false

	local BoxShine = Create("Frame", {
		Name = "ShellShine",
		Parent = Box,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
		Active = false,
		Interactable = false,
	})
	Corner(3, BoxShine)
	Create("UIGradient", {
		Parent = BoxShine,
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.72),
			NumberSequenceKeypoint.new(0.45, 0.92),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	local Fill = Create("Frame", {
		Name = "Fill",
		Parent = Box,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = value and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	})
	Corner(3, Fill)

	local FillShine = Create("Frame", {
		Name = "Shine",
		Parent = Fill,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 5,
		Active = false,
		Interactable = false,
	})
	Corner(3, FillShine)
	Create("UIGradient", {
		Parent = FillShine,
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.4, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.4, 0.72),
			NumberSequenceKeypoint.new(1, 0.95),
		}),
	})
	local FillSpecular = Create("Frame", {
		Name = "Specular",
		Parent = Fill,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.42, 0),
		ZIndex = 6,
		Active = false,
		Interactable = false,
	})
	Corner(3, FillSpecular)
	Create("UIGradient", {
		Parent = FillSpecular,
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.55, 0.78),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	local Glow = MakeGlow(Box, {
		On = value,
		Intensity = 1.35,
		Specs = {
			{ pad = 12, off = 0.18 },
			{ pad = 24, off = 0.36 },
			{ pad = 40, off = 0.58 },
		},
	})
	if Glow and Glow.Host then
		Glow.Host.ZIndex = 1
	end
	Create("TextLabel", {
		Parent = Holder, BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -40, 1, 0),
		FontFace = Library.Font, TextSize = 13, Text = cfg.Text or "Master Switch",
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	})

	local function set(v)
		value = v
		Tween(Fill, 0.18, { Size = value and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 0, 0) })
		SetGlow(Glow, value, 1)
		if flag then Library.Flags[flag] = value end
		if cfg.Callback then cfg.Callback(value) end
	end
	Box.MouseButton1Click:Connect(function() set(not value) end)
	if flag then Library.Flags[flag] = value end
	if cfg.Callback then task.spawn(cfg.Callback, value) end
	return { Set = set, Get = function() return value end }
end

-- While the menu is open: hide the Roblox core gui, free/unlock the mouse,
-- and sink all world input so only the UI + overlay are interactable.
local savedCoreGui = nil       -- true = core gui was enabled before we hid it
local savedMouseBehavior = nil
local savedMouseIcon = nil     -- MouseIconEnabled before we forced it on
local savedOverrideIcon = nil
local mouseKeeper = nil        -- forces mouse visible/unlocked every frame while open

local function setMenuSinks(visible)
	for _, w in ipairs(Library.Windows) do
		local sink = w.MenuSink
		if sink then
			sink.Visible = visible and true or false
			sink.Modal = visible and true or false
			sink.Active = visible and true or false
		end
	end
end

local function applyMenuOpenState()
	if savedCoreGui == nil then
		local ok, enabled = pcall(function()
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.All)
		end)
		savedCoreGui = ok and enabled or true
	end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

	if savedMouseBehavior == nil then
		savedMouseBehavior = UserInputService.MouseBehavior
	end
	if savedMouseIcon == nil then
		savedMouseIcon = UserInputService.MouseIconEnabled
	end
	pcall(function()
		if savedOverrideIcon == nil and UserInputService.OverrideMouseIconBehavior ~= nil then
			savedOverrideIcon = UserInputService.OverrideMouseIconBehavior
		end
		UserInputService.OverrideMouseIconBehavior = Enum.OverrideMouseIconBehavior.ForceShow
	end)

	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	setMenuSinks(true)

	-- games re-lock/hide the mouse every frame; keep forcing free cursor + modal sink
	if not mouseKeeper then
		mouseKeeper = RunService.RenderStepped:Connect(function()
			if not Library.Toggled then return end
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
			if not UserInputService.MouseIconEnabled then
				UserInputService.MouseIconEnabled = true
			end
			pcall(function()
				UserInputService.OverrideMouseIconBehavior = Enum.OverrideMouseIconBehavior.ForceShow
			end)
			for _, w in ipairs(Library.Windows) do
				local sink = w.MenuSink
				if sink then
					if not sink.Visible then sink.Visible = true end
					if not sink.Modal then sink.Modal = true end
					if not sink.Active then sink.Active = true end
				end
			end
		end)
	end
end

local function applyMenuClosedState()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, savedCoreGui ~= false)
	end)
	savedCoreGui = nil
	if mouseKeeper then
		mouseKeeper:Disconnect()
		mouseKeeper = nil
	end
	setMenuSinks(false)
	if savedMouseBehavior ~= nil then
		UserInputService.MouseBehavior = savedMouseBehavior
		savedMouseBehavior = nil
	end
	if savedMouseIcon ~= nil then
		UserInputService.MouseIconEnabled = savedMouseIcon
		savedMouseIcon = nil
	end
	pcall(function()
		if savedOverrideIcon ~= nil then
			UserInputService.OverrideMouseIconBehavior = savedOverrideIcon
			savedOverrideIcon = nil
		else
			UserInputService.OverrideMouseIconBehavior = Enum.OverrideMouseIconBehavior.None
		end
	end)
end
Library._applyMenuOpenState = applyMenuOpenState
Library._applyMenuClosedState = applyMenuClosedState

function Library._WindowMethods:Toggle()
	-- if the UI has been unloaded, the toggle bind must not touch anything
	-- (mouse state / core gui would otherwise still get flipped)
	if self._unloaded or not self.ScreenGui or not self.ScreenGui.Parent then return end
	-- block menu toggle until the launch intro finishes
	if not self._introDone then return end
	Library.Toggled = not Library.Toggled
	self.Main.Visible = Library.Toggled
	if self.MenuSink then
		self.MenuSink.Visible = Library.Toggled
		self.MenuSink.Modal = Library.Toggled
		self.MenuSink.Active = Library.Toggled
	end
	if Library.Toggled then
		applyMenuOpenState()
		if self._setMenuBlur then self._setMenuBlur(true, false) end
	else
		applyMenuClosedState()
		if self._setMenuBlur then self._setMenuBlur(false, false) end
	end
end

-- Fully unload: restore mouse / core gui state and destroy the gui.
function Library._WindowMethods:Unload()
	if self._unloaded then return end
	self._unloaded = true
	applyMenuClosedState()
	if self._destroyMenuBlur then self._destroyMenuBlur() end
	if self.ScreenGui then self.ScreenGui:Destroy() end
end

-- change the top-left logo after creation.
-- accepts rbxassetid://, an http url, or a lucide icon name; nil restores the letter badge.
function Library._WindowMethods:SetLogo(image)
	local asset = self._resolveImage(image)
	self.LogoImage.Image = asset or ""
	self.LogoImage.Visible = (asset ~= nil)
	local showWordmark = (asset == nil)
	if self.LogoRow then self.LogoRow.Visible = showWordmark end
	if self.LogoText then self.LogoText.Visible = showWordmark end
end

-- Floating "Keybinds" list. Shows every registered keybind that currently
-- has a key bound as a centered "Name [Key]" row -- grayed out when inactive,
-- lit up while the bind is active. Draggable by its title bar.
-- Returns { Frame, SetVisible }.
function Library._WindowMethods:CreateKeybindList(cfg)
	cfg = cfg or {}
	local Window = self

	local targetPos = cfg.Position or UDim2.new(0, 16, 0.5, 0)
	local Holder = Create("Frame", {
		Name = "KeybindList", Parent = Window.ScreenGui,
		AnchorPoint = cfg.AnchorPoint or Vector2.new(0, 0.5),
		Position = targetPos,
		Size = UDim2.new(0, cfg.Width or 180, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Background, BorderSizePixel = 0,
	})
	Corner(5, Holder)
	Stroke(Color3.fromRGB(10, 10, 10), 1, Holder)

	local TitleBar = Create("Frame", {
		Parent = Holder, Name = "TitleBar",
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = Theme.Groupbox, BorderSizePixel = 0,
	})
	Corner(5, TitleBar)
	Create("Frame", { -- mask bottom rounded corners
		Parent = TitleBar, Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Theme.Groupbox, BorderSizePixel = 0,
	})
	Create("TextLabel", {
		Parent = TitleBar, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		FontFace = Library.Font, TextSize = 13, Text = cfg.Title or "Keybinds",
		TextColor3 = Theme.KeybindTitle, TextXAlignment = Enum.TextXAlignment.Center,
	})
	MakeDraggable(TitleBar, Holder)

	local ListFrame = Create("Frame", {
		Parent = Holder, Name = "List", BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Create("UIListLayout", { Parent = ListFrame, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	Create("UIPadding", {
		Parent = ListFrame,
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8),
	})

	local Empty = Create("TextLabel", {
		Parent = ListFrame, BackgroundTransparency = 1, LayoutOrder = -1,
		Size = UDim2.new(1, 0, 0, 16),
		FontFace = Library.Font, TextSize = 12, Text = "No keybinds",
		TextColor3 = Theme.TextDark, TextXAlignment = Enum.TextXAlignment.Center,
	})


	-- bold face for the key text (falls back to the regular face)
	local BoldFont = Library.Font
	pcall(function()
		BoldFont = Font.new(Library.Font.Family, Enum.FontWeight.Bold)
	end)

	local rowFor = {}  -- kb -> row (created on demand, animated in)
	local function makeRow(kb)
		local Row = Create("Frame", {
			Parent = ListFrame, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0), ClipsDescendants = true,
		})
		local Name = Create("TextLabel", {
			Parent = Row, BackgroundTransparency = 1,
			Size = UDim2.new(1, -60, 0, 16),
			FontFace = Library.Font, TextSize = 12, Text = "",
			TextColor3 = Theme.KeybindTextDim, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextTransparency = 1,
		})
		local Key = Create("TextLabel", {
			Parent = Row, BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 56, 0, 16),
			FontFace = BoldFont, TextSize = 12, Text = "",
			TextColor3 = Theme.KeybindTextDim, TextXAlignment = Enum.TextXAlignment.Right,
			TextTransparency = 1,
		})
		-- appear animation: row expands open while the text fades + slides in
		Name.Position = UDim2.new(0, -8, 0, 0)
		Tween(Row, 0.18, { Size = UDim2.new(1, 0, 0, 16) })
		Tween(Name, 0.22, { TextTransparency = 0, Position = UDim2.new(0, 0, 0, 0) })
		Tween(Key, 0.25, { TextTransparency = 0 })
		local row = { Frame = Row, Name = Name, Key = Key }
		rowFor[kb] = row
		return row
	end

	local displayMode = cfg.DisplayMode or "All"   -- "All" | "Active"
	local emptyShown = true

	local function refresh()
		local shown = 0
		for _, kb in ipairs(Window.Keybinds) do
			local bind = kb.Get()
			local hasBind = bind and (bind.Key or bind.Mouse)
			local on = kb.GetState()
			-- "Active" mode lists only currently-active binds; Hidden binds
			-- (e.g. the menu toggle) never show
			local shouldShow = hasBind and not kb.Hidden
				and (displayMode ~= "Active" or on)
			local row = rowFor[kb]
			if shouldShow then
				shown = shown + 1
				if not row then row = makeRow(kb) end
				row.Shown = true
				row.Frame.Visible = true
				row.Frame.LayoutOrder = shown
				row.Name.Text = kb.Name
				row.Key.Text = kb.KeyText()
				-- expand open + fade text in (also recovers from a mid-collapse)
				Tween(row.Frame, 0.22, { Size = UDim2.new(1, 0, 0, 16) })
				Tween(row.Name, 0.22, {
					TextTransparency = 0, Position = UDim2.new(0, 0, 0, 0),
					TextColor3 = on and Theme.KeybindActive or Theme.KeybindTextDim,
				})
				Tween(row.Key, 0.22, {
					TextTransparency = 0,
					TextColor3 = on and Theme.KeybindActive or Theme.KeybindTextDim,
				})
			elseif row and row.Shown then
				-- collapse shut while the text fades + slides out
				row.Shown = false
				Tween(row.Frame, 0.22, { Size = UDim2.new(1, 0, 0, 0) })
				Tween(row.Name, 0.18, { TextTransparency = 1, Position = UDim2.new(0, -8, 0, 0) })
				Tween(row.Key, 0.15, { TextTransparency = 1 })
				task.delay(0.24, function()
					if not row.Shown then row.Frame.Visible = false end
				end)
			end
		end
		-- fade + collapse the "No keybinds" placeholder instead of snapping
		local wantEmpty = (shown == 0)
		if wantEmpty ~= emptyShown then
			emptyShown = wantEmpty
			if wantEmpty then
				Empty.Visible = true
				Tween(Empty, 0.25, { TextTransparency = 0, Size = UDim2.new(1, 0, 0, 16) })
			else
				Tween(Empty, 0.2, { TextTransparency = 1, Size = UDim2.new(1, 0, 0, 0) })
				task.delay(0.22, function()
					if not emptyShown then Empty.Visible = false end
				end)
			end
		end
	end

	table.insert(Window._keybindListeners, refresh)
	refresh()

	local api = { Frame = Holder, _pendingVisible = true }
	-- park near center until the intro floats this list into place
	if Window._registerIntroFloat and not Window._introDone then
		Window._registerIntroFloat(Holder, targetPos, UDim2.new(0.5, -(cfg.Width or 180) / 2, 0.5, 0), api)
	end
	-- accepts both api:SetVisible(v) and api.SetVisible(v)
	function api.SetVisible(a, b)
		local v
		if b == nil and type(a) ~= "table" then v = a else v = b end
		v = v and true or false
		-- stay hidden until the launch intro fully finishes
		if not Window._introDone then
			api._pendingVisible = v
			Holder.Visible = false
			return
		end
		Holder.Visible = v
	end
	-- "All" shows every bound key; "Active" shows only currently-active ones
	function api.SetDisplayMode(a, b)
		local m
		if b == nil and type(a) ~= "table" then m = a else m = b end
		if m == "Active Only" then m = "Active" end
		displayMode = (m == "Active") and "Active" or "All"
		refresh()
	end
	function api.Refresh() refresh() end
	return api
end

--------------------------------------------------------------
-- WATERMARK  (semi-rounded: logo + Blurred | FPS | game name)
--------------------------------------------------------------
function Library._WindowMethods:CreateWatermark(cfg)
	cfg = cfg or {}
	local Window = self
	local iconUrl = cfg.Icon or "https://files.catbox.moe/5tlbqc.png"
	local iconAsset = GetCachedUrl(iconUrl, cfg.IconFile or "watermark_icon.png")
	local gameName = cfg.GameName
	if not gameName or gameName == "" then
		local ok, name = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId).Name end)
		gameName = (ok and name) or game.Name or "Roblox"
	end
	local gameSub = cfg.GameSub or ("Place " .. tostring(game.PlaceId))

	local WM_H = 40
	local targetPos = cfg.Position or UDim2.new(0.5, 0, 0, 48)
	local Holder = Create("Frame", {
		Name = "Watermark", Parent = Window.ScreenGui,
		AnchorPoint = cfg.AnchorPoint or Vector2.new(0.5, 0),
		Position = targetPos,
		Size = UDim2.new(0, 120, 0, WM_H),
		BackgroundColor3 = Theme.Background, BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	Corner(5, Holder)
	Stroke(Color3.fromRGB(10, 10, 10), 1, Holder)

	-- inner content sizes itself; holder width tweens to match (smooth grow/shrink)
	local Content = Create("Frame", {
		Name = "Content", Parent = Holder, BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
	})
	Create("UIListLayout", {
		Parent = Content,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	})
	Create("UIPadding", {
		Parent = Content,
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 12),
	})

	local function makeDivider(order)
		return Create("Frame", {
			Parent = Content, LayoutOrder = order, BorderSizePixel = 0,
			Size = UDim2.new(0, 1, 0, 22),
			BackgroundColor3 = Theme.GroupboxLine,
		})
	end

	local function makeStack(order, topText, bottomText, topColor)
		local Col = Create("Frame", {
			Parent = Content, LayoutOrder = order, BackgroundTransparency = 1,
			Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		})
		Create("UIListLayout", {
			Parent = Col, FillDirection = Enum.FillDirection.Vertical,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0),
		})
		local Top = Create("TextLabel", {
			Parent = Col, BackgroundTransparency = 1, LayoutOrder = 1,
			Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X,
			FontFace = Library.Font, TextSize = 13, Text = topText,
			TextColor3 = topColor or Theme.WatermarkText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		local Bottom = Create("TextLabel", {
			Parent = Col, BackgroundTransparency = 1, LayoutOrder = 2,
			Size = UDim2.new(0, 0, 0, 12), AutomaticSize = Enum.AutomaticSize.X,
			FontFace = Library.Font, TextSize = 11, Text = bottomText,
			TextColor3 = Theme.WatermarkTextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
		return Top, Bottom
	end

	-- brand: bigger logo, tight gap, text optically centered
	local ICON_SZ, ICON_GAP = 26, 4
	local Brand = Create("Frame", {
		Parent = Content, LayoutOrder = 1, BackgroundTransparency = 1,
		Size = UDim2.new(0, ICON_SZ + ICON_GAP + 60, 1, 0),
	})
	local Icon = Create("ImageLabel", {
		Name = "Icon", Parent = Brand, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(0, ICON_SZ, 0, ICON_SZ),
		Image = iconAsset or "", ImageColor3 = Color3.fromRGB(255, 255, 255),
		ScaleType = Enum.ScaleType.Fit,
	})
	local BrandWrap = Create("Frame", {
		Name = "BrandWrap", Parent = Brand, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, ICON_SZ + ICON_GAP, 0.5, -1),
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
	})
	local BrandLabel = Create("TextLabel", {
		Name = "Brand", Parent = BrandWrap, BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		FontFace = Library.Font, TextSize = 15,
		Text = "Blurred",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	local BrandGrad = Create("UIGradient", {
		Parent = BrandLabel,
		Color = textAccentGradient(),
		Rotation = 0,
	})
	local BrandLine = Create("Frame", {
		Name = "BrandLine", Parent = BrandWrap,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, 2),
		Size = UDim2.new(1, 0, 0, 1),
	})
	local BrandLineGrad = Create("UIGradient", {
		Parent = BrandLine,
		Color = textAccentGradient(),
		Rotation = 0,
	})
	local function syncBrandWidth()
		Brand.Size = UDim2.new(0, ICON_SZ + ICON_GAP + BrandWrap.AbsoluteSize.X, 1, 0)
	end
	BrandWrap:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncBrandWidth)
	task.defer(syncBrandWidth)

	makeDivider(2)
	local FpsTop = makeStack(3, "0", "FPS", Theme.WatermarkText)
	makeDivider(4)
	local GameTop = makeStack(5, gameName, gameSub, Theme.WatermarkText)

	MakeDraggable(Holder, Holder)

	local function syncHolderWidth(instant)
		local w = math.max(Content.AbsoluteSize.X, 80)
		if instant then
			Holder.Size = UDim2.new(0, w, 0, WM_H)
		else
			Tween(Holder, 0.22, { Size = UDim2.new(0, w, 0, WM_H) })
		end
	end
	Content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		syncHolderWidth(false)
	end)
	task.defer(function() syncHolderWidth(true) end)

	-- register brand gradients so theme flush can refresh them
	Window._watermarkBrandGrads = Window._watermarkBrandGrads or {}
	table.insert(Window._watermarkBrandGrads, BrandGrad)
	table.insert(Window._watermarkBrandGrads, BrandLineGrad)

	-- keep brand wordmark in sync when brand colors change + live FPS
	local brandText, brandAccent = Theme.BrandText, Theme.BrandAccent
	local frames, last = 0, os.clock()
	local fpsConn = connectCapped(function()
		frames = frames + 1
		local now = os.clock()
		if now - last >= 0.4 then
			FpsTop.Text = tostring(math.floor(frames / (now - last) + 0.5))
			frames = 0
			last = now
			task.defer(function() syncHolderWidth(false) end)
		end
		if Theme.BrandText ~= brandText or Theme.BrandAccent ~= brandAccent then
			brandText, brandAccent = Theme.BrandText, Theme.BrandAccent
			local seq = textAccentGradient()
			BrandGrad.Color = seq
			BrandLineGrad.Color = seq
			task.defer(syncBrandWidth)
		end
	end)

	local api = { Frame = Holder, Icon = Icon, _pendingVisible = true }
	-- park near center until the intro floats this watermark into place
	if Window._registerIntroFloat and not Window._introDone then
		Window._registerIntroFloat(Holder, targetPos, UDim2.new(0.5, 0, 0.5, -WM_H / 2), api)
	end
	function api.SetText(a, b)
		-- kept for API compat; brand is always the Blurred wordmark
	end
	function api.SetGameName(a, b)
		local v = (b == nil and type(a) ~= "table") and a or b
		GameTop.Text = tostring(v or "")
	end
	function api.SetVisible(a, b)
		local v = (b == nil and type(a) ~= "table") and a or b
		v = v and true or false
		-- stay hidden until the launch intro fully finishes
		if not Window._introDone then
			api._pendingVisible = v
			Holder.Visible = false
			return
		end
		Holder.Visible = v
	end
	function api.Destroy()
		if fpsConn then fpsConn:Disconnect() fpsConn = nil end
		Holder:Destroy()
	end
	return api
end

Library._TabMethods = {}

function Library._TabMethods:AddSubTab(name)
	local Tab = self
	local Window = Tab.Window

	-- sidebar entry
	local SBtn = Create("TextButton", {
		Name = "SubTab_" .. name,
		Parent = Window.SubTabList,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.SubTabActive,
		BackgroundTransparency = 1,
		AutoButtonColor = false, Text = "", BorderSizePixel = 0,
		Visible = (Window.ActiveTab == Tab),
	})
	local SLabel = Create("TextLabel", {
		Parent = SBtn, BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -18, 1, 0),
		FontFace = Library.Font, TextSize = 13, Text = name, TextColor3 = Theme.SubTabText,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- scrollable content page (two columns)
	local Page = Create("ScrollingFrame", {
		Name = "Page_" .. name,
		Parent = Window.Content,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	})
	Padding(10, Page)

	-- Two equal columns laid out by a HORIZONTAL UIListLayout on the page.
	-- Using a list layout (instead of manual Position + AutomaticSize on each
	-- column) prevents the AutomaticSize width feedback that made the left
	-- column overflow and overlap the right one.
	local GUTTER = 12 -- space between the left and right sections

	Create("UIListLayout", {
		Parent = Page,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, GUTTER),
	})

	local Left = Create("Frame", {
		Name = "Left", Parent = Page, BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.new(0.5, -GUTTER / 2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Create("UIListLayout", { Parent = Left, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })

	local Right = Create("Frame", {
		Name = "Right", Parent = Page, BackgroundTransparency = 1,
		LayoutOrder = 2,
		Size = UDim2.new(0.5, -GUTTER / 2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Create("UIListLayout", { Parent = Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) })

	local SubTab = {
		Tab = Tab, Window = Window, Name = name,
		SidebarButton = SBtn, SidebarLabel = SLabel,
		Page = Page, Left = Left, Right = Right,
		Groupboxes = {},
	}
	setmetatable(SubTab, { __index = Library._SubTabMethods })

	SBtn.MouseEnter:Connect(function()
		if Tab.ActiveSubTab ~= SubTab then Tween(SLabel, 0.1, { TextColor3 = Theme.Hover }) end
	end)
	SBtn.MouseLeave:Connect(function()
		if Tab.ActiveSubTab ~= SubTab then Tween(SLabel, 0.1, { TextColor3 = Theme.SubTabText }) end
	end)
	SBtn.MouseButton1Click:Connect(function() Tab:_selectSubTab(SubTab) end)

	table.insert(Tab.SubTabs, SubTab)
	if not Tab.ActiveSubTab and Window.ActiveTab == Tab then
		Tab:_selectSubTab(SubTab)
	end
	return SubTab
end

function Library._TabMethods:_selectSubTab(SubTab, forceFade)
	if Library.OpenDropdown then Library.OpenDropdown.Close() end
	if Library.OpenColorPicker then Library.OpenColorPicker.Close() end
	if Library.OpenKeybindMenu then Library.OpenKeybindMenu.CloseMenu() end
	local previous = self.ActiveSubTab
	local switching = forceFade or (previous ~= SubTab)

	for _, st in ipairs(self.SubTabs) do
		local active = (st == SubTab)
		Tween(st.SidebarLabel, 0.12, { TextColor3 = active and Theme.SubTabTextActive or Theme.SubTabText })
		Tween(st.SidebarButton, 0.12, { BackgroundTransparency = active and 0 or 1 })
	end

	self.ActiveSubTab = SubTab
	local ind = self.Window.SubTabIndicator
	local shouldAnimate = ind and ind.BackgroundTransparency < 0.5
	self.Window:_moveSubTabIndicator(SubTab, shouldAnimate)

	-- content transition: fade the old page out, then fade the new one in.
	local function showNew()
		SubTab.Page.Visible = true
		fadePage(SubTab.Page, false, 0)    -- start hidden
		fadePage(SubTab.Page, true, 0.16)  -- fade in
	end

	if switching and previous and previous ~= SubTab and previous.Page.Visible then
		local old = previous.Page
		fadePage(old, false, 0.12)         -- fade out
		task.delay(0.12, function()
			if old ~= SubTab.Page then old.Visible = false end
			-- hide any other lingering pages in this tab
			for _, st in ipairs(self.SubTabs) do
				if st ~= SubTab then st.Page.Visible = false end
			end
			showNew()
		end)
	else
		-- no visible previous page (e.g. fresh tab switch): just fade the new one in
		for _, st in ipairs(self.SubTabs) do
			if st ~= SubTab then st.Page.Visible = false end
		end
		showNew()
	end
end

--============================================================
--// SUB-TAB METHODS  (Groupboxes)
--============================================================
Library._SubTabMethods = {}

local function makeGroupbox(SubTab, parentColumn, title)
	local Box = Create("Frame", {
		Name = "Groupbox_" .. title,
		Parent = parentColumn,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Groupbox,
		BorderSizePixel = 0,
	})
	Corner(5, Box)
	Stroke(Theme.GroupboxLine, 1, Box)

	Create("TextLabel", {
		Parent = Box, Name = "Title", BackgroundTransparency = 1,
		Position = UDim2.new(0, 12, 0, 8), Size = UDim2.new(1, -24, 0, 16),
		FontFace = Library.Font, TextSize = 14, Text = title, TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local Container = Create("Frame", {
		Parent = Box, Name = "Container", BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 30), Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Create("UIListLayout", { Parent = Container, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) })
	Create("UIPadding", {
		Parent = Container, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
	})

	local Groupbox = {
		SubTab = SubTab, Frame = Box, Container = Container, Rows = {},
	}
	setmetatable(Groupbox, { __index = Library._GroupboxMethods })
	table.insert(SubTab.Groupboxes, Groupbox)
	return Groupbox
end

function Library._SubTabMethods:AddLeftGroupbox(title)
	return makeGroupbox(self, self.Left, title)
end
function Library._SubTabMethods:AddRightGroupbox(title)
	return makeGroupbox(self, self.Right, title)
end

--------------------------------------------------------------
-- TABBOX (nested tabs inside a column, groupbox-sized)
--------------------------------------------------------------
Library._TabboxMethods = {}

local function makeTabbox(SubTab, parentColumn)
	local Box = Create("Frame", {
		Name = "Tabbox",
		Parent = parentColumn,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Groupbox,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	Corner(5, Box)
	Stroke(Theme.GroupboxLine, 1, Box)

	local TabBar = Create("Frame", {
		Parent = Box, Name = "TabBar",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	Corner(5, TabBar)
	Create("Frame", { -- mask bottom rounded corners
		Parent = TabBar, Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
	})

	local Body = Create("Frame", {
		Parent = Box, Name = "Body", BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 28),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})

	local Tabbox = {
		SubTab = SubTab, Frame = Box, TabBar = TabBar, Body = Body,
		Tabs = {}, ActiveTab = nil,
	}
	setmetatable(Tabbox, { __index = Library._TabboxMethods })
	return Tabbox
end

function Library._SubTabMethods:AddLeftTabbox()
	return makeTabbox(self, self.Left)
end
function Library._SubTabMethods:AddRightTabbox()
	return makeTabbox(self, self.Right)
end

function Library._TabboxMethods:AddTab(name)
	local Tabbox = self
	local count = #Tabbox.Tabs + 1

	local TabBtn = Create("TextButton", {
		Parent = Tabbox.TabBar, AutoButtonColor = false,
		Text = name,
		FontFace = Library.Font, TextSize = 12,
		TextColor3 = Theme.TabInactive,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0,
	})

	local Container = Create("Frame", {
		Parent = Tabbox.Body, Name = "Tab_" .. name,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	})
	Create("UIListLayout", { Parent = Container, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) })
	Create("UIPadding", {
		Parent = Container, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10),
	})

	local TabPage = {
		SubTab = Tabbox.SubTab, Frame = Container, Container = Container, Rows = {},
		_tabBtn = TabBtn,
	}
	setmetatable(TabPage, { __index = Library._GroupboxMethods })
	table.insert(Tabbox.SubTab.Groupboxes, TabPage)
	table.insert(Tabbox.Tabs, TabPage)

	local function resizeTabs()
		local n = #Tabbox.Tabs
		for i, t in ipairs(Tabbox.Tabs) do
			t._tabBtn.Size = UDim2.new(1 / n, 0, 1, 0)
			t._tabBtn.Position = UDim2.new((i - 1) / n, 0, 0, 0)
		end
	end
	resizeTabs()

	local function select()
		if Tabbox.ActiveTab == TabPage then return end
		for _, t in ipairs(Tabbox.Tabs) do
			local active = (t == TabPage)
			t.Container.Visible = active
			Tween(t._tabBtn, 0.12, { TextColor3 = active and Theme.TabActive or Theme.TabInactive })
		end
		Tabbox.ActiveTab = TabPage
	end

	TabBtn.MouseButton1Click:Connect(select)
	TabBtn.MouseEnter:Connect(function()
		if Tabbox.ActiveTab ~= TabPage then
			Tween(TabBtn, 0.1, { TextColor3 = Theme.TabHover })
		end
	end)
	TabBtn.MouseLeave:Connect(function()
		if Tabbox.ActiveTab ~= TabPage then
			Tween(TabBtn, 0.1, { TextColor3 = Theme.TabInactive })
		end
	end)

	if not Tabbox.ActiveTab then select() end
	return TabPage
end

-- search filter across all rows in the active sub-tab
function Library._SubTabMethods:_filter(query)
	for _, gb in ipairs(self.Groupboxes) do
		for _, row in ipairs(gb.Rows) do
			if query == "" then
				row.Frame.Visible = true
			else
				row.Frame.Visible = string.find(string.lower(row.SearchText or ""), query, 1, true) ~= nil
			end
		end
	end
end


Library._GroupboxMethods = {}

local function registerRow(Groupbox, frame, searchText)
	table.insert(Groupbox.Rows, { Frame = frame, SearchText = searchText })
end

function Library._GroupboxMethods:AddToggle(cfg)
	cfg = cfg or {}
	local Groupbox = self
	local value = cfg.Default or false
	local flag  = cfg.Flag
	local TOGGLE_W, GAP = 16, 8

	local Row = Create("Frame", {
		Parent = self.Container, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = false,
	})
	local Line = Create("Frame", {
		Parent = Row, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
		ClipsDescendants = false,
	})
	-- feature name on the left, checkbox on the right
	local Label = Create("TextLabel", {
		Parent = Line, Name = "Label", BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, -(TOGGLE_W + GAP), 1, 0),
		FontFace = Library.Font, TextSize = 13, Text = cfg.Text or "Toggle",
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Active = true,
	})
	local Box = Create("TextButton", {
		Parent = Line, Name = "Toggle", Text = "",
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, TOGGLE_W, 0, TOGGLE_W),
		BackgroundColor3 = Theme.Element,
		AutoButtonColor = false, BorderSizePixel = 0,
		ZIndex = 2,
	})
	Corner(3, Box)
	Stroke(Theme.ElementBorder, 1, Box)
	Box.ClipsDescendants = false

	-- subtle glass sheen on the empty checkbox shell
	local BoxShine = Create("Frame", {
		Name = "ShellShine",
		Parent = Box,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 3,
		Active = false,
		Interactable = false,
	})
	Corner(3, BoxShine)
	Create("UIGradient", {
		Parent = BoxShine,
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.72),
			NumberSequenceKeypoint.new(0.45, 0.92),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	local Fill = Create("Frame", {
		Name = "Fill",
		Parent = Box,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = value and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 4,
	})
	Corner(3, Fill)

	-- gloss / specular on the filled accent (matches colorpicker shine)
	local FillShine = Create("Frame", {
		Name = "Shine",
		Parent = Fill,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 5,
		Active = false,
		Interactable = false,
	})
	Corner(3, FillShine)
	Create("UIGradient", {
		Parent = FillShine,
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.4, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(0.4, 0.72),
			NumberSequenceKeypoint.new(1, 0.95),
		}),
	})
	local FillSpecular = Create("Frame", {
		Name = "Specular",
		Parent = Fill,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.42, 0),
		ZIndex = 6,
		Active = false,
		Interactable = false,
	})
	Corner(3, FillSpecular)
	Create("UIGradient", {
		Parent = FillSpecular,
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.55, 0.78),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	-- Bloom on the checkbox itself (not the fill) so it reads like the Boxes glow
	local Glow = MakeGlow(Box, {
		On = value,
		Intensity = 1.35,
		Specs = {
			{ pad = 12, off = 0.18 },
			{ pad = 24, off = 0.36 },
			{ pad = 40, off = 0.58 },
		},
	})
	if Glow and Glow.Host then
		Glow.Host.ZIndex = 1
	end

	local Desc
	if cfg.Description then
		Desc = Create("TextLabel", {
			Parent = Row, BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, -(TOGGLE_W + GAP), 0, 14),
			FontFace = Library.Font, TextSize = 12, Text = cfg.Description,
			TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y,
		})
	end

	local Window = self.SubTab.Window
	local sideHolder
	local sideCount = 0
	local settingsOpen = false
	local SettingsHost
	local SettingsPanel
	local SettingsInner
	local SettingsLayout
	local SettingsAnimToken = 0
	local CogBtn
	local CogIcon

	local function syncLabelWidth()
		local sideW = (sideHolder and sideHolder.AbsoluteSize.X) or 0
		local pad = TOGGLE_W + GAP + ((sideW > 0) and (sideW + GAP) or 0)
		Label.Size = UDim2.new(1, -pad, 1, 0)
	end

	local function ensureHolder()
		if not sideHolder then
			-- sits just left of the checkbox
			sideHolder = Create("Frame", {
				Parent = Line, BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -(TOGGLE_W + GAP), 0.5, 0),
				Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
			})
			Create("UIListLayout", {
				Parent = sideHolder, FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
			})
			sideHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncLabelWidth)
		end
		sideCount = sideCount + 1
		task.defer(syncLabelWidth)
		return sideCount
	end

	local function setCogColor(col)
		if not CogIcon then return end
		if CogIcon:IsA("ImageLabel") then
			CogIcon.ImageColor3 = col
		else
			CogIcon.TextColor3 = col
		end
	end

	local function measureSettingsHeight()
		if SettingsLayout then
			return math.max(0, SettingsLayout.AbsoluteContentSize.Y)
		end
		if SettingsInner then
			return math.max(0, SettingsInner.AbsoluteSize.Y)
		end
		return 0
	end

	local function snapSettingsHeight(h)
		SettingsHost.Size = UDim2.new(1, 0, 0, h)
	end

	local function syncSettingsVisibility(animate)
		if not SettingsHost then return end
		local show = settingsOpen and value
		setCogColor(settingsOpen and Theme.Accent or Theme.TextDim)
		if CogIcon then
			Tween(CogIcon, 0.32, { Rotation = settingsOpen and 90 or 0 }, Enum.EasingStyle.Quint)
		end

		SettingsAnimToken += 1
		local token = SettingsAnimToken

		local function finishOpen(h)
			if token ~= SettingsAnimToken then return end
			snapSettingsHeight(h)
			if SettingsInner then
				SettingsInner.Position = UDim2.new(0, 0, 0, 0)
				if SettingsInner:IsA("CanvasGroup") then
					SettingsInner.GroupTransparency = 0
				end
			end
		end

		local function finishClose()
			if token ~= SettingsAnimToken then return end
			snapSettingsHeight(0)
			SettingsHost.Visible = false
			if SettingsInner then
				SettingsInner.Position = UDim2.new(0, 0, 0, -8)
				if SettingsInner:IsA("CanvasGroup") then
					SettingsInner.GroupTransparency = 1
				end
			end
		end

		if show then
			SettingsHost.Visible = true
			-- allow layout to resolve content size before measuring
			local function openToMeasured()
				if token ~= SettingsAnimToken then return end
				local h = measureSettingsHeight()
				if h < 1 then
					task.defer(openToMeasured)
					return
				end
				if animate == false then
					finishOpen(h)
					return
				end
				local fromH = SettingsHost.AbsoluteSize.Y
				if fromH < 1 then
					snapSettingsHeight(0)
					if SettingsInner then
						SettingsInner.Position = UDim2.new(0, 0, 0, -10)
						if SettingsInner:IsA("CanvasGroup") then
							SettingsInner.GroupTransparency = 1
						end
					end
				end
				local expand = Tween(SettingsHost, 0.34, { Size = UDim2.new(1, 0, 0, h) }, Enum.EasingStyle.Quint)
				if SettingsInner then
					Tween(SettingsInner, 0.34, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
					if SettingsInner:IsA("CanvasGroup") then
						Tween(SettingsInner, 0.28, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
					end
				end
				expand.Completed:Connect(function()
					if token == SettingsAnimToken and settingsOpen and value then
						finishOpen(measureSettingsHeight())
					end
				end)
			end
			task.defer(openToMeasured)
		else
			if animate == false or not SettingsHost.Visible then
				finishClose()
				return
			end
			local collapse = Tween(SettingsHost, 0.26, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint)
			if SettingsInner then
				Tween(SettingsInner, 0.26, { Position = UDim2.new(0, 0, 0, -8) }, Enum.EasingStyle.Quint)
				if SettingsInner:IsA("CanvasGroup") then
					Tween(SettingsInner, 0.2, { GroupTransparency = 1 }, Enum.EasingStyle.Quad)
				end
			end
			collapse.Completed:Connect(function()
				if token == SettingsAnimToken and not (settingsOpen and value) then
					finishClose()
				end
			end)
		end
	end

	local function ensureSettingsHost()
		if SettingsHost then return SettingsHost end
		SettingsHost = Create("Frame", {
			Name = "Settings",
			Parent = Row,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, Desc and 40 or 22),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			Visible = false,
			ClipsDescendants = true,
		})

		local okCanvas, canvas = pcall(function()
			return Create("CanvasGroup", {
				Name = "Inner",
				Parent = SettingsHost,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				GroupTransparency = 1,
				Position = UDim2.new(0, 0, 0, -8),
			})
		end)
		if okCanvas and canvas then
			SettingsInner = canvas
		else
			SettingsInner = Create("Frame", {
				Name = "Inner",
				Parent = SettingsHost,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.new(0, 0, 0, -8),
			})
		end

		SettingsLayout = Create("UIListLayout", {
			Parent = SettingsInner,
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
		SettingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if not SettingsHost or not SettingsHost.Visible then return end
			if not (settingsOpen and value) then return end
			-- keep height in sync while open (e.g. nested dropdowns growing)
			local h = measureSettingsHeight()
			if math.abs(SettingsHost.AbsoluteSize.Y - h) > 1 then
				Tween(SettingsHost, 0.2, { Size = UDim2.new(1, 0, 0, h) }, Enum.EasingStyle.Quart)
			end
		end)

		SettingsPanel = SettingsInner
		return SettingsHost
	end

	local function ensureCog()
		if CogBtn then return end
		local order = ensureHolder()
		CogBtn = Create("TextButton", {
			Name = "SettingsCog",
			Parent = sideHolder,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(0, 16, 0, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = order,
			ZIndex = 3,
		})
		local iconAsset = (Library.Icons and (Library.Icons.Get("settings") or Library.Icons.Get("sliders-horizontal"))) or ""
		if iconAsset ~= "" then
			CogIcon = Create("ImageLabel", {
				Parent = CogBtn,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				Image = iconAsset,
				ImageColor3 = Theme.TextDim,
				ScaleType = Enum.ScaleType.Fit,
				Rotation = 0,
			})
		else
			CogIcon = Create("TextLabel", {
				Parent = CogBtn,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				FontFace = Library.Font,
				TextSize = 13,
				Text = "âš™",
				TextColor3 = Theme.TextDim,
				TextXAlignment = Enum.TextXAlignment.Center,
				Rotation = 0,
			})
		end
		CogBtn.MouseButton1Click:Connect(function()
			if not value then return end
			settingsOpen = not settingsOpen
			ensureSettingsHost()
			syncSettingsVisibility(true)
		end)
		CogBtn.MouseEnter:Connect(function()
			setCogColor(Theme.Accent)
		end)
		CogBtn.MouseLeave:Connect(function()
			setCogColor(settingsOpen and Theme.Accent or Theme.TextDim)
		end)
	end

	local function withSettingsContainer(fn)
		ensureCog()
		ensureSettingsHost()
		local prev = Groupbox.Container
		Groupbox.Container = SettingsPanel
		local result = fn()
		Groupbox.Container = prev
		syncSettingsVisibility(false)
		return result
	end

	local obj = {}
	obj.Text = cfg.Text
	local function set(v)
		value = v and true or false
		Tween(Fill, 0.18, { Size = value and UDim2.new(1, 0, 1, 0) or UDim2.new(0, 0, 0, 0) })
		SetGlow(Glow, value, 1.35)
		if not value then
			settingsOpen = false
		end
		syncSettingsVisibility(true)
		if flag then Library.Flags[flag] = value end
		if cfg.Callback then cfg.Callback(value) end
	end
	Box.MouseButton1Click:Connect(function() set(not value) end)
	Label.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then set(not value) end
	end)

	if flag then
		Library.Flags[flag] = value
		Library.FlagDefaults[flag] = value
		Library.FlagSetters[flag] = set
	end
	if cfg.Callback then task.spawn(cfg.Callback, value) end
	registerRow(self, Row, (cfg.Text or "") .. " " .. (cfg.Description or ""))

	function obj:AddColorpicker(ccfg)
		local order = ensureHolder()
		ccfg = ccfg or {}; ccfg.LayoutOrder = order
		return makeColorpicker(sideHolder, Window, ccfg)
	end
	function obj:AddKeybind(kcfg)
		local order = ensureHolder()
		kcfg = kcfg or {}; kcfg.LayoutOrder = order
		return makeKeybind(sideHolder, Window, kcfg, obj)  -- owner = this toggle
	end
	function obj:AddDropdown(dcfg)
		return withSettingsContainer(function()
			return Library._GroupboxMethods.AddDropdown(Groupbox, dcfg)
		end)
	end
	function obj:AddSlider(scfg)
		return withSettingsContainer(function()
			return Library._GroupboxMethods.AddSlider(Groupbox, scfg)
		end)
	end
	function obj:AddToggle(tcfg)
		return withSettingsContainer(function()
			return Library._GroupboxMethods.AddToggle(Groupbox, tcfg)
		end)
	end
	function obj:AddDivider()
		return withSettingsContainer(function()
			return Library._GroupboxMethods.AddDivider(Groupbox)
		end)
	end
	function obj:OpenSettings(on)
		if on == nil then on = true end
		if not value and on then return end
		settingsOpen = on and true or false
		ensureSettingsHost()
		ensureCog()
		syncSettingsVisibility(true)
	end

	obj.Set = set
	obj.Get = function() return value end
	obj.Frame = Row
	return obj
end


function Library._GroupboxMethods:AddSlider(cfg)
	cfg = cfg or {}
	local min, max = cfg.Min or 0, cfg.Max or 100
	local decimals = cfg.Decimals or 0
	local value = math.clamp(cfg.Default or min, min, max)
	local flag  = cfg.Flag
	local suffix = cfg.Suffix or ""

	local function round(v)
		local mult = 10 ^ decimals
		return math.floor(v * mult + 0.5) / mult
	end

	local Row = Create("Frame", {
		Parent = self.Container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40),
	})
	Create("TextLabel", {
		Parent = Row, BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 0, 16),
		FontFace = Library.Font, TextSize = 13, Text = cfg.Text or "Slider",
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local ValueLbl = Create("TextLabel", {
		Parent = Row, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 60, 0, 16),
		FontFace = Library.Font, TextSize = 13, Text = tostring(round(value)) .. suffix,
		TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Right,
	})

	local TrackWrap = Create("Frame", {
		Parent = Row, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 20), Size = UDim2.new(1, 0, 0, 20),
		ClipsDescendants = false, ZIndex = 2,
	})
	local Track = Create("Frame", {
		Parent = TrackWrap, BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 6),
		ClipsDescendants = false, ZIndex = 2,
	})
	Corner(3, Track)
	local Fill = Create("Frame", {
		Parent = Track, BackgroundColor3 = Theme.Accent, BorderSizePixel = 0,
		Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
		ClipsDescendants = false, ZIndex = 2,
	})
	Corner(3, Fill)
	local FillGlow = MakeGlow(Fill, {
		On = true,
		Intensity = 0.85,
		Specs = {
			{ pad = 6, off = 0.22 },
			{ pad = 14, off = 0.40 },
			{ pad = 24, off = 0.58 },
		},
	})
	-- vertical bar knob (semi-rounded / pill ends)
	local Knob = Create("Frame", {
		Parent = Track, BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
		Size = UDim2.new(0, 5, 0, 14), ZIndex = 4,
	})
	Corner(3, Knob)
	local KnobGlow = MakeGlow(Knob, {
		On = true,
		Intensity = 0.9,
		Specs = {
			{ pad = 6, off = 0.24 },
			{ pad = 12, off = 0.42 },
			{ pad = 20, off = 0.58 },
		},
	})

	local function apply(v, fire)
		value = math.clamp(round(v), min, max)
		local alpha = (value - min) / (max - min)
		Tween(Fill, 0.05, { Size = UDim2.new(alpha, 0, 1, 0) })
		Tween(Knob, 0.05, { Position = UDim2.new(alpha, 0, 0.5, 0) })
		ValueLbl.Text = tostring(value) .. suffix
		if flag then Library.Flags[flag] = value end
		if fire ~= false and cfg.Callback then cfg.Callback(value) end
	end

	local dragging = false
	local function fromX(x)
		local alpha = math.clamp((x - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
		apply(min + (max - min) * alpha)
	end
	local function beginDrag(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; fromX(i.Position.X)
		end
	end
	TrackWrap.InputBegan:Connect(beginDrag)
	Track.InputBegan:Connect(beginDrag)
	Knob.InputBegan:Connect(beginDrag)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			fromX(i.Position.X)
		end
	end)

	if flag then
		Library.Flags[flag] = value
		Library.FlagDefaults[flag] = value
		Library.FlagSetters[flag] = function(v) apply(v) end
	end
	if cfg.Callback then task.spawn(cfg.Callback, value) end
	registerRow(self, Row, cfg.Text or "")

	return {
		Set = function(v) apply(v) end,
		Get = function() return value end,
		Frame = Row,
	}
end

function makeColorpicker(holder, Window, cfg)
	cfg = cfg or {}
	local flag  = cfg.Flag
	local default = cfg.Default or Color3.fromRGB(255, 255, 255)
	local h, s, v = default:ToHSV()
	local alpha = cfg.Transparency or cfg.Alpha or 0   -- 0 = opaque, 1 = fully transparent

	local SWATCH_W, SWATCH_H = 30, 16

	-- the swatch button that lives on the row
	local Swatch = Create("TextButton", {
		Parent = holder, Text = "", AutoButtonColor = false,
		Size = UDim2.new(0, SWATCH_W, 0, SWATCH_H),
		BackgroundColor3 = default, BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = cfg.LayoutOrder or 1,
	})
	Corner(4, Swatch)
	Stroke(Theme.ElementBorder, 1, Swatch)

	-- soft top-edge shine / gloss
	local Shine = Create("Frame", {
		Name = "Shine",
		Parent = Swatch,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = (Swatch.ZIndex or 1) + 1,
		Active = false,
		Interactable = false,
	})
	Corner(4, Shine)
	Create("UIGradient", {
		Parent = Shine,
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.35, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 180, 180)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.42),
			NumberSequenceKeypoint.new(0.38, 0.78),
			NumberSequenceKeypoint.new(1, 0.96),
		}),
	})
	local Specular = Create("Frame", {
		Name = "Specular",
		Parent = Swatch,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Size = UDim2.new(1, 0, 0.38, 0),
		ZIndex = (Swatch.ZIndex or 1) + 2,
		Active = false,
		Interactable = false,
	})
	Corner(4, Specular)
	Create("UIGradient", {
		Parent = Specular,
		Rotation = 0,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	----------------------------------------------------------------
	-- Popup (floats on the overlay, above everything, unclipped)
	----------------------------------------------------------------
	local PAD = 8
	local POP_W = 200
	local SV_H  = 120
	local BAR_W = 12
	-- CanvasGroup so the whole popup can fade in/out via GroupTransparency.
	local Pop = Create("CanvasGroup", {
		Name = "ColorPopup", Parent = Window.Overlay, Active = true,
		BackgroundColor3 = Theme.Groupbox, BorderSizePixel = 0,
		GroupTransparency = 1,
		Size = UDim2.new(0, POP_W, 0, 0), Visible = false, ZIndex = 70,
	})
	Corner(5, Pop)
	-- UIStroke ignores CanvasGroup.GroupTransparency, fade it separately
	local PopStroke = Stroke(Theme.ElementBorder, 1, Pop)
	PopStroke.Transparency = 1

	-- SV box. Base = pure hue; a white overlay gives the saturation axis
	-- (white at left -> hue at right) and a black overlay gives the value
	-- axis (transparent at top -> black at bottom). Active=true so clicks on
	-- it are sunk by the GUI and don't trip the outside-close handler.
	local SV = Create("Frame", {
		Parent = Pop, ZIndex = 71, BorderSizePixel = 0, Active = true,
		Position = UDim2.new(0, PAD, 0, PAD),
		Size = UDim2.new(0, POP_W - PAD*3 - BAR_W*2 - 6, 0, SV_H),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
	})
	Corner(3, SV)
	local SVWhite = Create("Frame", {   -- white -> clear (saturation), horizontal
		Parent = SV, ZIndex = 72, BorderSizePixel = 0, Active = true,
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1,1,1),
	})
	Corner(3, SVWhite)
	Create("UIGradient", { Parent = SVWhite,
		Color = ColorSequence.new(Color3.new(1,1,1)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	})
	local SVBlack = Create("Frame", {   -- clear -> black (value), vertical
		Parent = SV, ZIndex = 73, BorderSizePixel = 0, Active = true,
		Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0,0,0),
	})
	Corner(3, SVBlack)
	Create("UIGradient", { Parent = SVBlack, Rotation = 90,
		Color = ColorSequence.new(Color3.new(0,0,0)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }),
	})
	local SVCursor = Create("Frame", {
		Parent = SV, ZIndex = 74, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = Color3.new(1,1,1),
	})
	Corner(4, SVCursor)
	Stroke(Color3.new(0,0,0), 1, SVCursor)

	-- Hue bar (vertical rainbow)
	local Hue = Create("Frame", {
		Parent = Pop, ZIndex = 71, BorderSizePixel = 0, Active = true,
		Position = UDim2.new(0, POP_W - PAD - BAR_W*2 - 6, 0, PAD),
		Size = UDim2.new(0, BAR_W, 0, SV_H), BackgroundColor3 = Color3.new(1,1,1),
	})
	Corner(3, Hue)
	Create("UIGradient", { Parent = Hue, Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0,    1, 1)),
			ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
			ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
			ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
			ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
			ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
			ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1,    1, 1)),
		}),
	})
	local HueKnob = Create("Frame", {
		Parent = Hue, ZIndex = 72, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, h, 0),
		Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = Color3.new(1,1,1),
	})
	Corner(2, HueKnob)
	Stroke(Color3.new(0,0,0), 1, HueKnob)

	-- Alpha bar (color -> transparent, checker-less simple gradient)
	local Alpha = Create("Frame", {
		Parent = Pop, ZIndex = 71, BorderSizePixel = 0, Active = true,
		Position = UDim2.new(0, POP_W - PAD - BAR_W, 0, PAD),
		Size = UDim2.new(0, BAR_W, 0, SV_H), BackgroundColor3 = default,
	})
	Corner(3, Alpha)
	local AlphaGrad = Create("UIGradient", { Parent = Alpha, Rotation = 90,
		Color = ColorSequence.new(default),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	})
	local AlphaKnob = Create("Frame", {
		Parent = Alpha, ZIndex = 72, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, alpha, 0),
		Size = UDim2.new(1, 4, 0, 4), BackgroundColor3 = Color3.new(1,1,1),
	})
	Corner(2, AlphaKnob)
	Stroke(Color3.new(0,0,0), 1, AlphaKnob)

	-- Hex box
	local Hex = Create("TextBox", {
		Parent = Pop, ZIndex = 71, BorderSizePixel = 0,
		Position = UDim2.new(0, PAD, 0, PAD + SV_H + 8),
		Size = UDim2.new(1, -PAD*2, 0, 22),
		BackgroundColor3 = Theme.Element, ClearTextOnFocus = false,
		FontFace = Library.Font, TextSize = 13, TextColor3 = Theme.Text,
		Text = "#" .. default:ToHex(),
	})
	Corner(3, Hex)
	Stroke(Theme.ElementBorder, 1, Hex)

	-- Copy / Paste row
	local BTN_H = 22
	local BtnRow = Create("Frame", {
		Parent = Pop, ZIndex = 71, BackgroundTransparency = 1, BorderSizePixel = 0,
		Position = UDim2.new(0, PAD, 0, PAD + SV_H + 8 + 22 + 6),
		Size = UDim2.new(1, -PAD*2, 0, BTN_H),
	})
	Create("UIListLayout", {
		Parent = BtnRow,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	})
	local btnW = math.floor((POP_W - PAD * 2 - 6) / 2)
	local function makeCpBtn(text, order)
		local btn = Create("TextButton", {
			Parent = BtnRow, ZIndex = 72, AutoButtonColor = false,
			Size = UDim2.new(0, btnW, 1, 0), LayoutOrder = order,
			BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
			FontFace = Library.Font, TextSize = 12, TextColor3 = Theme.Text,
			Text = text,
		})
		Corner(3, btn)
		Stroke(Theme.ElementBorder, 1, btn)
		btn.MouseEnter:Connect(function()
			Tween(btn, 0.1, { BackgroundColor3 = Theme.SubTabActive, TextColor3 = Theme.Accent })
		end)
		btn.MouseLeave:Connect(function()
			Tween(btn, 0.1, { BackgroundColor3 = Theme.Element, TextColor3 = Theme.Text })
		end)
		return btn
	end
	local CopyBtn = makeCpBtn("Copy", 1)
	local PasteBtn = makeCpBtn("Paste", 2)

	local function popHeight() return PAD + SV_H + 8 + 22 + 6 + BTN_H + PAD end

	----------------------------------------------------------------
	-- state / apply
	----------------------------------------------------------------
	local cp = {}
	local function currentColor() return Color3.fromHSV(h, s, v) end

	local function redraw()
		local col = currentColor()
		Swatch.BackgroundColor3 = col
		SV.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		SVCursor.Position = UDim2.new(s, 0, 1 - v, 0)
		HueKnob.Position = UDim2.new(0.5, 0, h, 0)
		Alpha.BackgroundColor3 = col
		AlphaGrad.Color = ColorSequence.new(col)
		AlphaKnob.Position = UDim2.new(0.5, 0, alpha, 0)
		Hex.Text = "#" .. col:ToHex()
		-- reflect transparency on the swatch too (blends toward row bg)
		Swatch.BackgroundTransparency = alpha * 0.85
		if Shine then Shine.BackgroundTransparency = alpha * 0.5 end
		if Specular then Specular.BackgroundTransparency = 0.15 + alpha * 0.7 end
	end

	local function fire()
		if flag then
			Library.Flags[flag] = currentColor()
			Library.Flags[flag .. "Transparency"] = alpha
		end
		if cfg.Callback then cfg.Callback(currentColor(), alpha) end
	end

	-- fireCb == false updates swatch/HSV/flags without invoking Callback
	-- (used when ApplyPreset / SetThemeColor syncs Theme* pickers)
	local function set(color, a, fireCb)
		if color then h, s, v = color:ToHSV() end
		if a ~= nil then alpha = math.clamp(a, 0, 1) end
		redraw()
		if flag then
			Library.Flags[flag] = currentColor()
			Library.Flags[flag .. "Transparency"] = alpha
		end
		if fireCb ~= false and cfg.Callback then
			cfg.Callback(currentColor(), alpha)
		end
	end
	cp.Set = set
	cp.Get = function() return currentColor() end
	cp.GetAlpha = function() return alpha end
	cp.Frame = Swatch

	local function flashBtn(btn, ok)
		local col = ok and Theme.Accent or Color3.fromRGB(220, 70, 70)
		Tween(btn, 0.08, { TextColor3 = col })
		task.delay(0.35, function()
			if btn and btn.Parent then
				Tween(btn, 0.15, { TextColor3 = Theme.Text })
			end
		end)
	end

	CopyBtn.MouseButton1Click:Connect(function()
		local col = currentColor()
		Library.CopiedColor = { Color = col, Alpha = alpha }
		local hex = "#" .. col:ToHex()
		if setclipboard then
			pcall(setclipboard, hex)
		elseif toclipboard then
			pcall(toclipboard, hex)
		end
		flashBtn(CopyBtn, true)
	end)

	PasteBtn.MouseButton1Click:Connect(function()
		local pasted = false
		if Library.CopiedColor and Library.CopiedColor.Color then
			set(Library.CopiedColor.Color, Library.CopiedColor.Alpha)
			pasted = true
		else
			local clip
			if getclipboard then
				local ok, v = pcall(getclipboard)
				if ok then clip = v end
			end
			if type(clip) == "string" then
				local ok, col = pcall(function()
					return Color3.fromHex((clip:gsub("#", ""):gsub("%s+", "")))
				end)
				if ok and col then
					set(col, alpha)
					pasted = true
				end
			end
		end
		flashBtn(PasteBtn, pasted)
	end)

	----------------------------------------------------------------
	-- open / close
	----------------------------------------------------------------
	local pickerOpen = false
	local function baseXY()
		local sp, ss = Swatch.AbsolutePosition, Swatch.AbsoluteSize
		local op = Window.Overlay.AbsolutePosition
		local x = sp.X - op.X + ss.X - POP_W          -- right-align popup to swatch
		local y = sp.Y - op.Y + ss.Y + 6
		return math.max(0, x), y
	end
	local function layout()
		local x, y = baseXY()
		Pop.Position = UDim2.new(0, x, 0, y)
		Pop.Size = UDim2.new(0, POP_W, 0, popHeight())
	end
	local close
	local function open()
		if pickerOpen then return end
		if Library.OpenDropdown then Library.OpenDropdown.Close() end
		if Library.OpenColorPicker and Library.OpenColorPicker ~= cp then
			Library.OpenColorPicker.Close()
		end
		pickerOpen = true
		Library.OpenColorPicker = cp
		if Window.PopupBlocker then Window.PopupBlocker.Visible = true end
		layout(); redraw()
		-- fade + slide in: start a few px up and fully transparent, settle down
		local x, y = baseXY()
		Pop.Visible = true
		Pop.GroupTransparency = 1
		PopStroke.Transparency = 1
		Pop.Position = UDim2.new(0, x, 0, y - 6)
		Tween(Pop, 0.16, { GroupTransparency = 0, Position = UDim2.new(0, x, 0, y) })
		Tween(PopStroke, 0.16, { Transparency = 0 })
	end
	close = function()
		if not pickerOpen then return end
		pickerOpen = false
		if Library.OpenColorPicker == cp then Library.OpenColorPicker = nil end
		if Window.PopupBlocker and not Library.OpenColorPicker then
			Window.PopupBlocker.Visible = false
		end
		-- fade + slide out (outline too), then hide
		local x, y = baseXY()
		Tween(Pop, 0.14, { GroupTransparency = 1, Position = UDim2.new(0, x, 0, y - 6) })
		Tween(PopStroke, 0.14, { Transparency = 1 })
		task.delay(0.15, function()
			if not pickerOpen then Pop.Visible = false end
		end)
	end
	cp.Close = close
	cp.IsOpen = function() return pickerOpen end

	Swatch.MouseButton1Click:Connect(function()
		if pickerOpen then
			close()
		elseif Library.OpenColorPicker then
			-- another picker is open: swallow the click (don't open this one
			-- underneath a popup's sliders), just close the open picker
			Library.OpenColorPicker.Close()
		else
			open()
		end
	end)
	Swatch:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		if pickerOpen then layout() end
	end)

	----------------------------------------------------------------
	-- drag handling (same pattern as AddSlider)
	----------------------------------------------------------------
	local dragTarget = nil  -- "sv" | "hue" | "alpha"
	local function applyDrag(px, py)
		if dragTarget == "sv" then
			s = math.clamp((px - SV.AbsolutePosition.X) / SV.AbsoluteSize.X, 0, 1)
			v = 1 - math.clamp((py - SV.AbsolutePosition.Y) / SV.AbsoluteSize.Y, 0, 1)
		elseif dragTarget == "hue" then
			h = math.clamp((py - Hue.AbsolutePosition.Y) / Hue.AbsoluteSize.Y, 0, 1)
		elseif dragTarget == "alpha" then
			alpha = math.clamp((py - Alpha.AbsolutePosition.Y) / Alpha.AbsoluteSize.Y, 0, 1)
		end
		redraw(); fire()
	end
	local function bindDrag(frame, kind)
		frame.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragTarget = kind; applyDrag(i.Position.X, i.Position.Y)
			end
		end)
	end
	bindDrag(SV, "sv"); bindDrag(SVWhite, "sv"); bindDrag(SVBlack, "sv")
	bindDrag(Hue, "hue"); bindDrag(Alpha, "alpha")
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragTarget = nil
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragTarget and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			applyDrag(i.Position.X, i.Position.Y)
		end
	end)

	Hex.FocusLost:Connect(function()
		local ok, col = pcall(function()
			return Color3.fromHex((Hex.Text:gsub("#", "")))
		end)
		if ok and col then h, s, v = col:ToHSV() end
		redraw(); if ok then fire() end
	end)

	redraw()
	if flag then
		Library.Flags[flag] = currentColor()
		Library.Flags[flag .. "Transparency"] = alpha
		Library.FlagDefaults[flag] = currentColor()
		Library.FlagDefaults[flag .. "Transparency"] = alpha
		-- config setter: accepts {R,G,B in 0-1} table or Color3 + optional alpha
		-- third arg fireCb=false skips Callback (used by SetThemeColor sync)
		Library.FlagSetters[flag] = function(v, a, fireCb)
			if typeof(v) == "Color3" then set(v, a, fireCb)
			elseif type(v) == "table" and v.R then set(Color3.new(v.R, v.G, v.B), a or v.A, fireCb) end
		end
	end
	return cp
end

--------------------------------------------------------------
-- KEYBIND (reusable builder)
--   Semi-rounded pill: ( mode-icon | key )
--   Click icon  = Hold / Toggle / Always menu
--   Click key   = capture next key / mouse button
--   `owner` (optional) is the Toggle object it drives.
--------------------------------------------------------------
-- friendly short names for common keys
local KEY_NAMES = {
	[Enum.KeyCode.LeftControl]="LCtrl", [Enum.KeyCode.RightControl]="RCtrl",
	[Enum.KeyCode.LeftShift]="LShift", [Enum.KeyCode.RightShift]="RShift",
	[Enum.KeyCode.LeftAlt]="LAlt", [Enum.KeyCode.RightAlt]="RAlt",
	[Enum.KeyCode.Space]="Space", [Enum.KeyCode.Return]="Enter",
}
local MOUSE_NAMES = {
	[Enum.UserInputType.MouseButton1]="MB1",
	[Enum.UserInputType.MouseButton2]="MB2",
	[Enum.UserInputType.MouseButton3]="MB3",
}
local function keyDisplay(bind)
	if not bind then return "-" end
	if bind.Mouse then return MOUSE_NAMES[bind.Mouse] or "Mouse" end
	if bind.Key then return KEY_NAMES[bind.Key] or bind.Key.Name end
	return "-"
end

function makeKeybind(holder, Window, cfg, owner)
	cfg = cfg or {}
	local flag = cfg.Flag
	local MODES = { "Hold", "Toggle", "Always" }
	local mode = cfg.Mode or "Toggle"
	local active = false
	local noModeMenu = cfg.NoModeMenu == true

	local bind
	do
		local d = cfg.Default
		if typeof and typeof(d) == "EnumItem" then
			if d.EnumType == Enum.KeyCode then bind = { Key = d }
			elseif d.EnumType == Enum.UserInputType then bind = { Mouse = d } end
		elseif type(d) == "table" then
			bind = d
		end
	end

	-- match toggle checkbox: 16px tall, Corner(3) semi-round
	local PILL_H = 16
	local ICON_SZ = 12
	local keyboardIcon = Library.Icons.Get(cfg.Icon or "keyboard") or ""
	local Pill = Create("Frame", {
		Parent = holder,
		Size = UDim2.new(0, 0, 0, PILL_H),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Element,
		BorderSizePixel = 0,
		LayoutOrder = cfg.LayoutOrder or 1,
	})
	Corner(3, Pill)
	Stroke(Theme.ElementBorder, 1, Pill)
	Create("UIListLayout", {
		Parent = Pill,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})
	Create("UIPadding", {
		Parent = Pill,
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 6),
	})

	-- left: keyboard icon (opens Hold / Toggle / Always)
	local ModeBtn = Create("TextButton", {
		Parent = Pill, AutoButtonColor = false, Text = "",
		Size = UDim2.new(0, ICON_SZ + 2, 1, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0,
		LayoutOrder = 1, ZIndex = 2,
	})
	local ModeIcon = Create("ImageLabel", {
		Parent = ModeBtn, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, ICON_SZ, 0, ICON_SZ),
		Image = keyboardIcon,
		ImageColor3 = Theme.TextDim,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	})

	local SpL = Create("Frame", {
		Parent = Pill, LayoutOrder = 2, BackgroundTransparency = 1,
		Size = UDim2.new(0, 4, 1, 0),
	})
	local Div = Create("Frame", {
		Parent = Pill, LayoutOrder = 3, BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 0, PILL_H - 6),
		BackgroundColor3 = Theme.ElementBorder,
		BackgroundTransparency = 0.15,
		ZIndex = 2,
	})
	local SpR = Create("Frame", {
		Parent = Pill, LayoutOrder = 4, BackgroundTransparency = 1,
		Size = UDim2.new(0, 4, 1, 0),
	})

	-- right: key label / capture hit area
	local KeyBtn = Create("TextButton", {
		Parent = Pill, AutoButtonColor = false, Text = "",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1, BorderSizePixel = 0,
		LayoutOrder = 5, ZIndex = 2,
	})
	local KeyLabel = Create("TextLabel", {
		Parent = KeyBtn, BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Library.Font, TextSize = 11,
		Text = keyDisplay(bind),
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})

	local kb = {}
	local capturing = false
	local function notify()
		if kb.OnChange then kb.OnChange() end
	end

	local refreshText
	local captureAnim = nil
	local function stopCaptureAnim()
		if captureAnim then captureAnim:Disconnect() captureAnim = nil end
	end

	refreshText = function(skipAnim)
		local color = (capturing or active) and Theme.Accent or Theme.TextDim
		ModeIcon.Image = keyboardIcon
		if skipAnim == true then
			ModeIcon.ImageColor3 = color
			KeyLabel.TextColor3 = color
		else
			Tween(ModeIcon, 0.12, { ImageColor3 = color })
			Tween(KeyLabel, 0.12, { TextColor3 = color })
		end
		if capturing then
			KeyLabel.TextColor3 = Theme.Accent
			if not captureAnim then
				local t0 = os.clock()
				captureAnim = connectCapped(function()
					local n = math.floor(((os.clock() - t0) / 0.35) % 3) + 1
					KeyLabel.Text = string.rep(".", n)
				end)
			end
		else
			stopCaptureAnim()
			KeyLabel.Text = keyDisplay(bind)
		end
	end

	local function fire()
		if flag then Library.Flags[flag] = active end
		if cfg.Callback then cfg.Callback(active, mode) end
		if owner and owner.Set then owner.Set(active) end
	end

	local function setActive(state)
		if active == state then return end
		active = state
		refreshText()
		fire()
		notify()
	end

	----------------------------------------------------------------
	-- mode menu (icon click only)
	----------------------------------------------------------------
	local MENU_W = 96
	local MENU_H = #MODES * 20 + 6
	local Menu = Create("CanvasGroup", {
		Name = "KeybindMenu", Parent = Window.Overlay, Active = true,
		BackgroundColor3 = Theme.Groupbox, BorderSizePixel = 0, GroupTransparency = 1,
		Size = UDim2.new(0, MENU_W, 0, MENU_H), Visible = false, ZIndex = 80,
	})
	Corner(5, Menu)
	local MenuStroke = Stroke(Theme.ElementBorder, 1, Menu)
	Create("UIListLayout", { Parent = Menu, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) })
	Create("UIPadding", {
		Parent = Menu, PaddingTop = UDim.new(0,3), PaddingBottom = UDim.new(0,3),
		PaddingLeft = UDim.new(0,3), PaddingRight = UDim.new(0,3),
	})

	local menuOpen = false
	local modeButtons = {}
	local function refreshModeMenu()
		for m, b in pairs(modeButtons) do
			b.TextColor3 = (m == mode) and Theme.Accent or Theme.TextDim
		end
	end
	local closeMenu
	local function setMode(m)
		mode = m
		refreshModeMenu()
		if mode == "Always" then
			setActive(true)
		elseif mode == "Hold" then
			active = false
			refreshText()
			if flag then Library.Flags[flag] = active end
			notify()
		else
			if owner and owner.Get then
				active = owner.Get() == true
			end
			refreshText()
			if flag then Library.Flags[flag] = active end
			notify()
		end
		if flag then Library.Flags[flag .. "Mode"] = mode end
		notify()
	end
	for i, m in ipairs(MODES) do
		local MB = Create("TextButton", {
			Parent = Menu, Active = true, AutoButtonColor = false, LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 20),
			BackgroundColor3 = Theme.Element, BackgroundTransparency = 1,
			FontFace = Library.Font, TextSize = 12, Text = m,
			TextColor3 = Theme.TextDim, ZIndex = 81, BorderSizePixel = 0,
		})
		Corner(3, MB)
		modeButtons[m] = MB
		MB.MouseEnter:Connect(function()
			Tween(MB, 0.12, { BackgroundTransparency = 0.85 })
			if mode ~= m then Tween(MB, 0.12, { TextColor3 = Theme.Text }) end
		end)
		MB.MouseLeave:Connect(function()
			Tween(MB, 0.12, { BackgroundTransparency = 1 })
			if mode ~= m then Tween(MB, 0.12, { TextColor3 = Theme.TextDim }) end
		end)
		MB.MouseButton1Click:Connect(function()
			setMode(m)
			closeMenu()
		end)
	end
	local function menuXY()
		local pp, ps = Pill.AbsolutePosition, Pill.AbsoluteSize
		local op = Window.Overlay.AbsolutePosition
		return pp.X - op.X + ps.X - MENU_W, pp.Y - op.Y + ps.Y + 4
	end
	local function openMenu()
		if menuOpen or noModeMenu then return end
		if Library.OpenKeybindMenu and Library.OpenKeybindMenu ~= kb then
			Library.OpenKeybindMenu.CloseMenu()
		end
		menuOpen = true
		Library.OpenKeybindMenu = kb
		refreshModeMenu()
		local x, y = menuXY()
		Menu.Visible = true
		Menu.GroupTransparency = 1
		MenuStroke.Transparency = 1
		Menu.Position = UDim2.new(0, x, 0, y - 6)
		Menu.Size = UDim2.new(0, MENU_W, 0, math.floor(MENU_H * 0.6))
		Tween(Menu, 0.16, {
			GroupTransparency = 0,
			Position = UDim2.new(0, x, 0, y),
			Size = UDim2.new(0, MENU_W, 0, MENU_H),
		})
		Tween(MenuStroke, 0.16, { Transparency = 0 })
	end
	closeMenu = function()
		if not menuOpen then return end
		menuOpen = false
		if Library.OpenKeybindMenu == kb then Library.OpenKeybindMenu = nil end
		local x, y = menuXY()
		Tween(Menu, 0.13, {
			GroupTransparency = 1,
			Position = UDim2.new(0, x, 0, y - 6),
		})
		Tween(MenuStroke, 0.13, { Transparency = 1 })
		task.delay(0.14 * (Anim.SpeedScale or 1), function()
			if not menuOpen then
				MenuStroke.Transparency = 1
				Menu.Visible = false
			end
		end)
	end
	kb.CloseMenu = closeMenu

	ModeBtn.MouseEnter:Connect(function()
		if not (capturing or active) then Tween(ModeIcon, 0.12, { ImageColor3 = Theme.Text }) end
	end)
	ModeBtn.MouseLeave:Connect(function()
		if not (capturing or active) then Tween(ModeIcon, 0.12, { ImageColor3 = Theme.TextDim }) end
	end)
	ModeBtn.MouseButton1Click:Connect(function()
		if noModeMenu then return end
		if menuOpen then closeMenu() else openMenu() end
	end)

	KeyBtn.MouseEnter:Connect(function()
		if not capturing then Tween(KeyLabel, 0.12, { TextColor3 = Theme.Text }) end
	end)
	KeyBtn.MouseLeave:Connect(function()
		if not capturing then
			local color = active and Theme.Accent or Theme.TextDim
			Tween(KeyLabel, 0.12, { TextColor3 = color })
		end
	end)
	KeyBtn.MouseButton1Click:Connect(function()
		if capturing then return end
		if menuOpen then closeMenu() end
		capturing = true
		-- ignore the same MB1 that opened capture
		local ignoreClick = true
		task.defer(function() ignoreClick = false end)
		kb._ignoreCaptureClick = function()
			return ignoreClick
		end
		refreshText()
	end)

	----------------------------------------------------------------
	-- global input listener
	----------------------------------------------------------------
	local function matches(input)
		if not bind then return false end
		if bind.Key and input.KeyCode == bind.Key then return true end
		if bind.Mouse and input.UserInputType == bind.Mouse then return true end
		return false
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if capturing then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					bind = nil
				else
					bind = { Key = input.KeyCode }
				end
				capturing = false
				refreshText()
				if flag then Library.Flags[flag] = active end
				notify()
				return
			elseif MOUSE_NAMES[input.UserInputType] then
				if input.UserInputType == Enum.UserInputType.MouseButton1
					and kb._ignoreCaptureClick and kb._ignoreCaptureClick() then
					return
				end
				bind = { Mouse = input.UserInputType }
				capturing = false
				refreshText()
				notify()
				return
			end
		end

		if gameProcessed then return end
		if mode == "Always" then return end
		if matches(input) then
			if mode == "Hold" then
				setActive(true)
			elseif mode == "Toggle" then
				setActive(not active)
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if mode == "Hold" and matches(input) then
			setActive(false)
		end
	end)

	kb.Get = function() return bind end
	kb.GetState = function() return active end
	kb.GetMode = function() return mode end
	kb.SetMode = setMode
	kb.Frame = Pill
	kb.Name = cfg.Text or (owner and owner.Text) or "Keybind"
	kb.Hidden = cfg.Hidden == true
	kb.KeyText = function() return keyDisplay(bind) end
	kb.Set = function(b) bind = b; refreshText(false); notify() end
	kb.Serialize = function()
		return {
			Key   = bind and bind.Key and bind.Key.Name or nil,
			Mouse = bind and bind.Mouse and bind.Mouse.Name or nil,
			Mode  = mode,
		}
	end
	kb.Deserialize = function(data)
		if type(data) ~= "table" then return end
		local newBind = nil
		if data.Key and Enum.KeyCode[data.Key] then
			newBind = { Key = Enum.KeyCode[data.Key] }
		elseif data.Mouse and Enum.UserInputType[data.Mouse] then
			newBind = { Mouse = Enum.UserInputType[data.Mouse] }
		end
		bind = newBind
		if data.Mode and (data.Mode == "Hold" or data.Mode == "Toggle" or data.Mode == "Always") then
			mode = data.Mode
			if mode == "Always" then
				active = true
			elseif mode == "Toggle" and owner and owner.Get then
				active = owner.Get() == true
			elseif mode == "Hold" then
				active = false
			end
			if flag then
				Library.Flags[flag] = active
				Library.Flags[flag .. "Mode"] = mode
			end
		end
		refreshText(false)
		notify()
	end
	if flag then
		Library.FlagSetters[flag .. "_Bind"] = kb.Deserialize
		Library.KeybindsByFlag = Library.KeybindsByFlag or {}
		Library.KeybindsByFlag[flag] = kb
	end

	if mode == "Always" then active = true end
	if owner and owner.Get and mode == "Toggle" then
		active = owner.Get() == true
	end
	refreshText(true)
	if flag then
		Library.Flags[flag] = active
		Library.Flags[flag .. "Mode"] = mode
	end
	if cfg.Callback and mode == "Always" then task.spawn(cfg.Callback, true, mode) end

	if owner and owner.Set then
		local rawSet = owner.Set
		owner.Set = function(v)
			rawSet(v)
			local on = v == true
			if mode ~= "Hold" and active ~= on then
				active = on
				refreshText()
				if flag then Library.Flags[flag] = active end
				notify()
			end
		end
	end

	if Window._registerKeybind then Window._registerKeybind(kb) end
	return kb
end

--------------------------------------------------------------
-- COLORPICKER (standalone groupbox row: text left, swatch right)
--------------------------------------------------------------
function Library._GroupboxMethods:AddColorpicker(cfg)
	cfg = cfg or {}
	local Window = self.SubTab.Window
	local Row = Create("Frame", {
		Parent = self.Container, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
	})
	Create("TextLabel", {
		Parent = Row, BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, -24, 1, 0),
		FontFace = Library.Font, TextSize = 13, Text = cfg.Text or "Color",
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	})
	local Holder = Create("Frame", {
		Parent = Row, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 30, 1, 0),
	})
	local cp = makeColorpicker(Holder, Window, cfg)
	registerRow(self, Row, cfg.Text or "")
	cp.Frame = Row
	return cp
end

--------------------------------------------------------------
-- DROPDOWN
--------------------------------------------------------------
function Library._GroupboxMethods:AddDropdown(cfg)
	cfg = cfg or {}
	local values = cfg.Values or {}
	local multi  = cfg.Multi == true
	local flag   = cfg.Flag
	local Window = self.SubTab.Window
	local open   = false
	local placeholder = cfg.Placeholder or "..."

	-- selection state:
	--   single -> `value` holds the chosen option
	--   multi  -> `selectedSet` is a set {opt=true}, `selectedList` keeps order
	local value        -- single-select current value
	local selectedSet  = {}
	local selectedList = {}
	if multi then
		local def = cfg.Default
		if type(def) == "table" then
			for _, opt in ipairs(def) do
				if selectedSet[opt] == nil then
					selectedSet[opt] = true
					table.insert(selectedList, opt)
				end
			end
		end
	else
		value = cfg.Default or values[1]
	end

	local function isSelected(opt)
		if multi then return selectedSet[opt] == true end
		return opt == value
	end
	local function displayText()
		if multi then
			if #selectedList == 0 then return placeholder end
			return table.concat(selectedList, ", ")
		end
		return tostring(value or placeholder)
	end
	local function currentValue()
		if multi then
			local out = {}
			for _, opt in ipairs(selectedList) do out[#out+1] = opt end
			return out
		end
		return value
	end

	local Row = Create("Frame", {
		Parent = self.Container, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40),
		ClipsDescendants = false,
	})
	if cfg.Text then
		Create("TextLabel", {
			Parent = Row, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			FontFace = Library.Font, TextSize = 13, Text = cfg.Text,
			TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local Btn = Create("TextButton", {
		Parent = Row, Text = "", AutoButtonColor = false,
		Position = UDim2.new(0, 0, 0, cfg.Text and 18 or 0),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
	})
	Corner(3, Btn)
	Stroke(Theme.ElementBorder, 1, Btn)
	local Selected = Create("TextLabel", {
		Parent = Btn, BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -28, 1, 0),
		FontFace = Library.Font, TextSize = 13, Text = displayText(), TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	})
	-- lucide chevron icon (rotates 180Ãƒâ€šÃ‚Â° when the dropdown is open)
	local Arrow = Create("ImageLabel", {
		Parent = Btn, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		Image = Library.Icons.Get("chevron-down") or "",
		ImageColor3 = Theme.TextDim, ScaleType = Enum.ScaleType.Fit,
	})

	----------------------------------------------------------------
	-- Popup list -- lives on the window Overlay so it floats above the
	-- content and isn't clipped by the scrolling frame.
	----------------------------------------------------------------
	local GAP = 6            -- spacing between button and popup
	local ITEM_H = 24
	local List = Create("Frame", {
		Name = "DropdownList",
		Parent = Window.Overlay,
		BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
		Size = UDim2.new(0, 0, 0, 0),
		Visible = false, ZIndex = 60,
		BackgroundTransparency = 1,
	})
	Corner(4, List)
	local listStroke = Stroke(Theme.ElementBorder, 1, List)
	listStroke.Transparency = 1
	Create("UIListLayout", { Parent = List, SortOrder = Enum.SortOrder.LayoutOrder })
	Create("UIPadding", { Parent = List, PaddingTop = UDim.new(0,3), PaddingBottom = UDim.new(0,3) })

	-- position/size the popup under the button in absolute coords
	local function layout()
		local bp, bs = Btn.AbsolutePosition, Btn.AbsoluteSize
		local op = Window.Overlay.AbsolutePosition
		List.Size = UDim2.new(0, bs.X, 0, #values * ITEM_H + 6)
		List.Position = UDim2.new(0, bp.X - op.X, 0, bp.Y - op.Y + bs.Y + GAP)
	end

	local items = {}  -- opt -> { Item, Label, Highlight }

	local function refreshHighlights()
		for opt, it in pairs(items) do
			local sel = isSelected(opt)
			Tween(it.Highlight, 0.15, { BackgroundTransparency = sel and 0.82 or 1 })
			Tween(it.Label, 0.15, { TextColor3 = sel and Theme.Accent or Theme.TextDim })
		end
	end

	local function commit()
		Selected.Text = displayText()
		refreshHighlights()
		if flag then Library.Flags[flag] = currentValue() end
		if cfg.Callback then cfg.Callback(currentValue()) end
	end

	-- single-select: replace value. `set` accepts a value (single) or, for a
	-- multi dropdown, an array of values to select.
	local function set(v)
		if multi then
			selectedSet, selectedList = {}, {}
			if type(v) == "table" then
				for _, opt in ipairs(v) do
					if selectedSet[opt] == nil then
						selectedSet[opt] = true
						table.insert(selectedList, opt)
					end
				end
			end
		else
			value = v
		end
		commit()
	end

	-- multi-select: flip one option's membership (keeps insertion order)
	local function toggleOption(opt)
		if selectedSet[opt] then
			selectedSet[opt] = nil
			for i, o in ipairs(selectedList) do
				if o == opt then table.remove(selectedList, i) break end
			end
		else
			selectedSet[opt] = true
			table.insert(selectedList, opt)
		end
		commit()
	end

	local closeFns = {}
	local function close()
		if not open then return end
		open = false
		if Library.OpenDropdown == closeFns then Library.OpenDropdown = nil end
		Tween(Arrow, 0.18, { Rotation = 0 })
		-- collapse + slide up + fade out
		local bp, bs = Btn.AbsolutePosition, Btn.AbsoluteSize
		local op = Window.Overlay.AbsolutePosition
		Tween(List, 0.14, {
			Position = UDim2.new(0, bp.X - op.X, 0, bp.Y - op.Y + bs.Y + GAP - 6),
			Size = UDim2.new(0, bs.X, 0, math.floor(#values * ITEM_H * 0.5)),
			BackgroundTransparency = 1,
		})
		Tween(listStroke, 0.12, { Transparency = 1 })
		for _, it in pairs(items) do
			Tween(it.Label, 0.12, { TextTransparency = 1 })
			Tween(it.Highlight, 0.12, { BackgroundTransparency = 1 })
		end
		task.delay(0.15, function()
			if not open then List.Visible = false end
		end)
	end
	closeFns.Close = close
	closeFns.Button = Btn
	closeFns.List = List

	local function openList()
		if open then return end
		-- close any other open dropdown first
		if Library.OpenDropdown and Library.OpenDropdown ~= closeFns then
			Library.OpenDropdown.Close()
		end
		open = true
		Library.OpenDropdown = closeFns
		layout()
		Tween(Arrow, 0.18, { Rotation = 180 })
		List.Visible = true
		-- start slightly collapsed + shifted up + transparent, then expand/fall/fade in
		local bp, bs = Btn.AbsolutePosition, Btn.AbsoluteSize
		local op = Window.Overlay.AbsolutePosition
		local finalPos = UDim2.new(0, bp.X - op.X, 0, bp.Y - op.Y + bs.Y + GAP)
		List.Position = UDim2.new(0, bp.X - op.X, 0, bp.Y - op.Y + bs.Y + GAP - 8)
		List.Size = UDim2.new(0, bs.X, 0, math.floor(#values * ITEM_H * 0.4))
		List.BackgroundTransparency = 1
		Tween(List, 0.2, {
			Position = finalPos,
			Size = UDim2.new(0, bs.X, 0, #values * ITEM_H + 6),
			BackgroundTransparency = 0,
		})
		Tween(listStroke, 0.2, { Transparency = 0 })
		for _, it in pairs(items) do
			it.Label.TextTransparency = 1
			Tween(it.Label, 0.22, { TextTransparency = 0 })
		end
		refreshHighlights()
	end

	local function buildItems()
		for _, it in pairs(items) do it.Item:Destroy() end
		items = {}
		for i, opt in ipairs(values) do
			local Item = Create("TextButton", {
				Parent = List, Text = "", AutoButtonColor = false,
				Size = UDim2.new(1, 0, 0, ITEM_H), BackgroundTransparency = 1,
				ZIndex = 61, LayoutOrder = i,
			})
			-- selection/hover highlight bar behind the label
			local Highlight = Create("Frame", {
				Parent = Item, BorderSizePixel = 0, ZIndex = 61,
				Size = UDim2.new(1, -6, 1, -2), Position = UDim2.new(0, 3, 0, 1),
				BackgroundColor3 = Theme.Accent, BackgroundTransparency = 1,
			})
			Corner(3, Highlight)
			local IL = Create("TextLabel", {
				Parent = Item, BackgroundTransparency = 1,
				Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(1, -12, 1, 0),
				FontFace = Library.Font, TextSize = 13, Text = tostring(opt),
				TextColor3 = Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 62,
			})
			items[opt] = { Item = Item, Label = IL, Highlight = Highlight }

			Item.MouseEnter:Connect(function()
				if not isSelected(opt) then
					Tween(Highlight, 0.12, { BackgroundTransparency = 0.92 })
					Tween(IL, 0.12, { TextColor3 = Theme.Text })
				end
			end)
			Item.MouseLeave:Connect(function()
				if not isSelected(opt) then
					Tween(Highlight, 0.12, { BackgroundTransparency = 1 })
					Tween(IL, 0.12, { TextColor3 = Theme.TextDim })
				end
			end)
			Item.MouseButton1Click:Connect(function()
				if multi then
					-- toggle membership and keep the list open for more picks
					toggleOption(opt)
				else
					value = opt
					commit()
					close()
				end
			end)
		end
	end
	buildItems()

	-- replace the option list (drops selections that no longer exist)
	local function setValues(newValues)
		values = newValues or {}
		if multi then
			local keep, keepList = {}, {}
			for _, opt in ipairs(values) do
				if selectedSet[opt] then keep[opt] = true; table.insert(keepList, opt) end
			end
			selectedSet, selectedList = keep, keepList
		else
			local found = false
			for _, opt in ipairs(values) do
				if opt == value then found = true break end
			end
			if not found then value = nil end
		end
		buildItems()
		if open then layout() end
		commit()
	end

	Btn.MouseButton1Click:Connect(function()
		if open then close() else openList() end
	end)
	-- keep the popup glued to the button if the window is dragged while open
	Btn:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		if open then layout() end
	end)

	if flag then Library.Flags[flag] = currentValue() end
	if cfg.Callback then
		local v = currentValue()
		if multi or v ~= nil then task.spawn(cfg.Callback, v) end
	end
	registerRow(self, Row, cfg.Text or "")

	local ddObj = {
		Set = set,
		Get = currentValue,
		SetValues = setValues,
		Close = close,
		Frame = Row,
	}
	if flag then
		Library.FlagDefaults[flag] = currentValue()
		Library.FlagSetters[flag] = set
	end
	return ddObj
end

--------------------------------------------------------------
-- LABEL
--------------------------------------------------------------
function Library._GroupboxMethods:AddLabel(text, cfg)
	cfg = cfg or {}
	local Lbl = Create("TextLabel", {
		Parent = self.Container, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Library.Font, TextSize = 12, Text = text,
		TextColor3 = cfg.Color or Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	})
	registerRow(self, Lbl, text)

	local obj = {
		Frame = Lbl,
		Set = function(t) Lbl.Text = t end,
	}

	-- attach one or more colorpickers / keybinds to the right of the label.
	-- Shared holder so they stack together right-aligned.
	local Window = self.SubTab.Window
	local sideHolder
	local sideCount = 0
	local function ensureHolder()
		if not sideHolder then
			sideHolder = Create("Frame", {
				Parent = Lbl, BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X,
			})
			Create("UIListLayout", {
				Parent = sideHolder, FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
			})
		end
		sideCount = sideCount + 1
		return sideCount
	end
	function obj:AddColorpicker(ccfg)
		local order = ensureHolder()
		ccfg = ccfg or {}; ccfg.LayoutOrder = order
		return makeColorpicker(sideHolder, Window, ccfg)
	end
	function obj:AddKeybind(kcfg)
		local order = ensureHolder()
		kcfg = kcfg or {}; kcfg.LayoutOrder = order
		return makeKeybind(sideHolder, Window, kcfg, nil)  -- label has no owner toggle
	end

	return obj
end

--------------------------------------------------------------
-- DIVIDER
--------------------------------------------------------------
function Library._GroupboxMethods:AddDivider()
	local Row = Create("Frame", {
		Parent = self.Container, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 10),
	})
	Create("Frame", {
		Parent = Row, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.GroupboxLine, BorderSizePixel = 0,
	})
	registerRow(self, Row, "")
	return { Frame = Row }
end

--------------------------------------------------------------
-- BUTTON (+ Sub Button via :AddButton)
--------------------------------------------------------------
function Library._GroupboxMethods:AddButton(cfg)
	cfg = cfg or {}

	local Row = Create("Frame", {
		Parent = self.Container, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 26),
	})
	Create("UIListLayout", {
		Parent = Row, FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
	})

	local buttons = {}

	local function makeBtn(bcfg, order)
		bcfg = bcfg or {}
		local Btn = Create("TextButton", {
			Parent = Row, AutoButtonColor = false, LayoutOrder = order,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Theme.Element, BorderSizePixel = 0,
			FontFace = Library.Font, TextSize = 13,
			Text = bcfg.Text or "Button", TextColor3 = Theme.Text,
		})
		Corner(3, Btn)
		Stroke(Theme.ElementBorder, 1, Btn)
		Btn.MouseEnter:Connect(function() Tween(Btn, 0.12, { BackgroundColor3 = Theme.AccentDim }) end)
		Btn.MouseLeave:Connect(function() Tween(Btn, 0.12, { BackgroundColor3 = Theme.Element }) end)
		Btn.MouseButton1Click:Connect(function()
			if bcfg.Callback then bcfg.Callback() end
		end)
		table.insert(buttons, Btn)
		local n = #buttons
		for _, b in ipairs(buttons) do
			b.Size = UDim2.new(1 / n, n > 1 and -3 or 0, 1, 0)
		end
		return Btn
	end

	makeBtn(cfg, 1)
	registerRow(self, Row, cfg.Text or "")

	local obj = { Frame = Row }
	function obj:AddButton(bcfg)
		makeBtn(bcfg, #buttons + 1)
		return obj
	end
	return obj
end

--------------------------------------------------------------
-- TEXTBOX (label on top, input below)
--------------------------------------------------------------
function Library._GroupboxMethods:AddTextbox(cfg)
	cfg = cfg or {}
	local flag = cfg.Flag

	local hasLabel = cfg.Text ~= nil
	local Row = Create("Frame", {
		Parent = self.Container, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, hasLabel and 40 or 22),
	})
	if hasLabel then
		Create("TextLabel", {
			Parent = Row, BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			FontFace = Library.Font, TextSize = 13, Text = cfg.Text,
			TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	local Input = Create("TextBox", {
		Parent = Row, BorderSizePixel = 0, ClearTextOnFocus = false,
		Position = UDim2.new(0, 0, 0, hasLabel and 18 or 0),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = Theme.Element,
		FontFace = Library.Font, TextSize = 13,
		Text = cfg.Default or "",
		PlaceholderText = cfg.Placeholder or "",
		PlaceholderColor3 = Theme.TextDark,
		TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
	})
	Corner(3, Input)
	local stroke = Stroke(Theme.ElementBorder, 1, Input)
	Create("UIPadding", { Parent = Input, PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) })

	Input.Focused:Connect(function() Tween(stroke, 0.12, { Color = Theme.Accent }) end)
	Input.FocusLost:Connect(function(enterPressed)
		Tween(stroke, 0.12, { Color = Theme.ElementBorder })
		if flag then Library.Flags[flag] = Input.Text end
		if cfg.Callback then cfg.Callback(Input.Text, enterPressed) end
	end)

	local function set(text)
		Input.Text = tostring(text or "")
		if flag then Library.Flags[flag] = Input.Text end
	end

	if flag then
		Library.Flags[flag] = Input.Text
		Library.FlagSetters[flag] = set
	end
	registerRow(self, Row, cfg.Text or "")
	return {
		Frame = Row,
		Set = set,
		Get = function() return Input.Text end,
		Input = Input,
	}
end

--============================================================
--// NOTIFICATIONS
--   Library:Notify("Config saved") -- top-right stack.
--   Soft fade + slight slide; no scale (avoids AutomaticSize jitter).
--============================================================
local NotifyGui, NotifyHolder
local notifySeq = 0
local NOTIFY_IN  = 0.38
local NOTIFY_OUT = 0.32

local function notifyTween(inst, time, props, style, dir)
	return TweenService:Create(inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
		props)
end

local function ensureNotifyGui()
	if NotifyGui and NotifyGui.Parent then return end
	NotifyGui = Create("ScreenGui", {
		Name = "BlurredNotify",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 1000,
		IgnoreGuiInset = true,
	})
	pcall(function() NotifyGui.Parent = getGuiParent() end)
	if not NotifyGui.Parent then NotifyGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
	NotifyHolder = Create("Frame", {
		Parent = NotifyGui, BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.new(0, 300, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = false,
	})
	Create("UIListLayout", {
		Parent = NotifyHolder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
end

function Library:Notify(text, duration)
	duration = duration or 3
	ensureNotifyGui()
	notifySeq = notifySeq + 1
	local order = notifySeq

	local Toast = Create("Frame", {
		Parent = NotifyHolder,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 280, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = -order,
	})

	local Inner = Create("CanvasGroup", {
		Parent = Toast,
		BackgroundColor3 = Theme.Groupbox,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		GroupTransparency = 1,
		BackgroundTransparency = 0.06,
	})
	Corner(6, Inner)
	local stroke = Stroke(Theme.GroupboxLine, 1, Inner)
	stroke.Transparency = 0.4

	local Label = Create("TextLabel", {
		Parent = Inner, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Library.Font, TextSize = 13,
		Text = tostring(text),
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	Create("UIPadding", {
		Parent = Inner,
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
	})
	Create("UISizeConstraint", {
		Parent = Label,
		MaxSize = Vector2.new(252, 160),
	})

	-- slide in from the right + fade (no scale)
	Inner.Position = UDim2.new(0, 14, 0, 0)
	local tin = notifyTween(Inner, NOTIFY_IN, {
		GroupTransparency = 0,
		Position = UDim2.new(0, 0, 0, 0),
	})
	local sin = notifyTween(stroke, NOTIFY_IN, { Transparency = 0.4 })
	tin:Play(); sin:Play()

	task.delay(duration, function()
		if not Toast.Parent then return end
		local tout = notifyTween(Inner, NOTIFY_OUT, {
			GroupTransparency = 1,
			Position = UDim2.new(0, 10, 0, 0),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local sout = notifyTween(stroke, NOTIFY_OUT, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tout:Play(); sout:Play()
		task.delay(NOTIFY_OUT + 0.04, function()
			if Toast.Parent then Toast:Destroy() end
		end)
	end)
end

--============================================================
--// CONFIG SYSTEM
--   JSON configs in blurred/configs. Serializes Library.Flags
--   (skipping internal flags), keybind binds/modes, theme colors
--   and animation settings. Autoload name stored in blurred/autoload.txt.
--============================================================
local Config = {}
Library.Config = Config

local CONFIG_DIR = Library.Folders.Configs
local AUTOLOAD_FILE = Library.Folders.Root .. "/autoload.txt"

local function hasFileApi()
	return writefile ~= nil and readfile ~= nil and isfile ~= nil
end

local function configPath(name)
	return CONFIG_DIR .. "/" .. name .. ".json"
end

-- Flags we never write into configs (config-UI state itself)
Config.IgnoredFlags = {}

local function serializeValue(v)
	if typeof(v) == "Color3" then
		return { __type = "Color3", R = v.R, G = v.G, B = v.B }
	end
	if typeof(v) == "EnumItem" then
		return { __type = "EnumItem", EnumType = tostring(v.EnumType), Name = v.Name }
	end
	if type(v) == "table" then
		local out = {}
		local n = 0
		for i, x in ipairs(v) do
			out[i] = serializeValue(x)
			n += 1
		end
		if n > 0 then return out end
		for k, x in pairs(v) do
			out[tostring(k)] = serializeValue(x)
		end
		return out
	end
	return v
end

local function deserializeValue(v)
	if type(v) ~= "table" then return v end
	if v.__type == "Color3" then
		return Color3.new(v.R, v.G, v.B)
	end
	if v.__type == "EnumItem" and v.EnumType and v.Name then
		local enumObj = Enum[v.EnumType]
		if enumObj and enumObj[v.Name] then
			return enumObj[v.Name]
		end
		return v
	end
	local hasNumeric = false
	for k in pairs(v) do
		if type(k) == "number" then hasNumeric = true break end
	end
	if hasNumeric then
		local out = {}
		for i, x in ipairs(v) do
			out[i] = deserializeValue(x)
		end
		return out
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = deserializeValue(x)
	end
	return out
end

local function cloneDefault(v)
	if typeof(v) == "Color3" then return v end
	if type(v) == "table" then
		local out = {}
		for i, x in ipairs(v) do out[i] = deserializeValue(serializeValue(x)) end
		for k, x in pairs(v) do
			if type(k) ~= "number" then out[k] = deserializeValue(serializeValue(x)) end
		end
		return out
	end
	return v
end

local function isKnownFlag(flag)
	if Config.IgnoredFlags[flag] then return false end
	if string.find(flag, "_Bind$") then return false end
	return Library.FlagSetters[flag] ~= nil or Library.FlagDefaults[flag] ~= nil
end

function Config.List()
	local out = {}
	if listfiles then
		local ok, files = pcall(listfiles, CONFIG_DIR)
		if ok then
			for _, f in ipairs(files) do
				local name = string.match(f, "([^/\\]+)%.json$")
				if name then table.insert(out, name) end
			end
		end
	end
	table.sort(out)
	return out
end

function Config.Save(name)
	if not hasFileApi() or not name or name == "" then return false end
	local data = { Version = 1, Flags = {}, Keybinds = {}, Theme = {}, Anim = {} }
	for flag, value in pairs(Library.Flags) do
		if isKnownFlag(flag) then
			data.Flags[flag] = serializeValue(value)
		end
	end
	if Library.KeybindsByFlag then
		for flag, kb in pairs(Library.KeybindsByFlag) do
			if kb and kb.Serialize then
				data.Keybinds[flag] = kb.Serialize()
			end
		end
	end
	for key, color in pairs(Theme) do
		data.Theme[key] = serializeValue(color)
	end
	data.Anim.SpeedScale = Anim.SpeedScale
	data.Anim.TargetFPS = Anim.TargetFPS
	data.Anim.Style = Anim.Style.Name
	data.Anim.Direction = Anim.Direction.Name
	local ok = pcall(writefile, configPath(name), HttpService:JSONEncode(data))
	if ok and Library.SaveActiveTheme then
		saveThemeFile(name, Theme)
		Library.SaveActiveTheme()
	end
	Library:Notify(ok and ('Config "' .. name .. '" saved') or "Failed to save config")
	return ok
end

function Config.Load(name, opts)
	if not hasFileApi() or not name or name == "" then return false end
	opts = opts or {}
	local skipTheme = opts.SkipTheme == true
	local path = configPath(name)
	if not isfile(path) then return false end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(data) ~= "table" then return false end

	local flags = type(data.Flags) == "table" and data.Flags or {}

	local function isThemeFlag(flag)
		return type(flag) == "string" and string.sub(flag, 1, 5) == "Theme"
	end

	local function applyFlag(flag, v)
		if not isKnownFlag(flag) then return end
		local setter = Library.FlagSetters[flag]
		local value = deserializeValue(v)
		if setter then
			if typeof(value) == "Color3" then
				local alpha = flags[flag .. "Transparency"]
				if alpha == nil then alpha = Library.FlagDefaults[flag .. "Transparency"] end
				pcall(setter, value, alpha)
			else
				pcall(setter, value)
			end
		else
			Library.Flags[flag] = value
		end
	end

	-- Reset every known flag to its UI default before applying the saved config
	for flag, default in pairs(Library.FlagDefaults) do
		if isKnownFlag(flag) and not string.find(flag, "Transparency$") then
			applyFlag(flag, default)
		end
	end
	-- Themes are preset-only: apply ThemePreset, never per-key custom colors.
	-- Autoload skips theme so every execute boots on the original Default look.
	if not skipTheme then
		if flags.ThemePreset ~= nil then
			applyFlag("ThemePreset", flags.ThemePreset)
		end
	end
	if type(data.Anim) == "table" then
		if type(data.Anim.SpeedScale) == "number" then Anim.SpeedScale = data.Anim.SpeedScale end
		if type(data.Anim.TargetFPS) == "number" then
			Anim.TargetFPS = math.clamp(math.floor(data.Anim.TargetFPS + 0.5), 60, 240)
		end
		if data.Anim.Style and Enum.EasingStyle[data.Anim.Style] then
			Anim.Style = Enum.EasingStyle[data.Anim.Style]
		end
		if data.Anim.Direction and Enum.EasingDirection[data.Anim.Direction] then
			Anim.Direction = Enum.EasingDirection[data.Anim.Direction]
		end
	end
	-- Apply saved values (only known flags with registered setters / defaults)
	for flag, v in pairs(flags) do
		if flag == "ThemePreset" then
			-- already handled above (or skipped on autoload)
		elseif isThemeFlag(flag) then
			-- ignore Theme* colorpicker flags (themes are preset-only)
		else
			applyFlag(flag, v)
		end
	end
	if type(data.Keybinds) == "table" and Library.KeybindsByFlag then
		for flag, kbData in pairs(data.Keybinds) do
			local kb = Library.KeybindsByFlag[flag]
			if kb then pcall(kb.Deserialize, kbData) end
		end
	end
	Library:Notify('Config "' .. name .. '" loaded')
	return true
end

function Config.Delete(name)
	if not name or name == "" then return false end
	if delfile and isfile and isfile(configPath(name)) then
		local ok = pcall(delfile, configPath(name))
		Library:Notify(ok and ('Config "' .. name .. '" deleted') or "Failed to delete config")
		return ok
	end
	return false
end

function Config.SetAutoload(name)
	if not hasFileApi() then return false end
	if name and name ~= "" then
		local ok = pcall(writefile, AUTOLOAD_FILE, name)
		if ok then Library:Notify('Autoload set to "' .. name .. '"') end
		return ok
	elseif delfile and isfile and isfile(AUTOLOAD_FILE) then
		local ok = pcall(delfile, AUTOLOAD_FILE)
		if ok then Library:Notify("Autoload disabled") end
		return ok
	end
	return false
end

function Config.GetAutoload()
	if not hasFileApi() or not isfile(AUTOLOAD_FILE) then return nil end
	local ok, name = pcall(readfile, AUTOLOAD_FILE)
	if ok and name and name ~= "" then return name end
	return nil
end

-- call after building your UI: loads the autoload config if one is set
-- Theme is intentionally skipped so every execute boots on the original Default look.
-- Manual Config.Load(name) still restores the saved theme.
function Config.Autoload()
	local name = Config.GetAutoload()
	if name then return Config.Load(name, { SkipTheme = true }), name end
	return false, nil
end

return Library
