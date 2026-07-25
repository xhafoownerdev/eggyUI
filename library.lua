--[[
	eggtech UI Library
	SnakeCase API | Squared | 700x400
	Theme: light pink / periwinkle gradient accents
	Font: BuilderSansExtraBold
]]

-- Use Lua's `type` to validate `typeof` — a polluted typeof table causes "attempt to call a table value"
local Type_Of = type
if type(typeof) == "function" then
	Type_Of = typeof
end

local function Is_Function(Value)
	return type(Value) == "function"
end

local function Safe_Call(Fn, ...)
	if not Is_Function(Fn) then
		return false, nil
	end
	return pcall(Fn, ...)
end

-- `type()` returns "userdata" for enums; never rely on Type_Of == "EnumItem"
local function Is_Enum_Item(Value, Enum_Type)
	if Value == nil then
		return false
	end
	local Ok, Result = pcall(function()
		if Value.EnumType == nil or Value.Name == nil then
			return false
		end
		if Enum_Type ~= nil then
			return Value.EnumType == Enum_Type
		end
		return true
	end)
	return Ok and Result == true
end

local function Is_KeyCode(Key)
	return Is_Enum_Item(Key, Enum.KeyCode) and Key ~= Enum.KeyCode.Unknown
end

local Mouse_Bind_Types = {
	[Enum.UserInputType.MouseButton1] = "mb1",
	[Enum.UserInputType.MouseButton2] = "mb2",
}

local Mouse_Bind_Aliases = {
	mb1 = Enum.UserInputType.MouseButton1,
	m1 = Enum.UserInputType.MouseButton1,
	mouse1 = Enum.UserInputType.MouseButton1,
	mousebutton1 = Enum.UserInputType.MouseButton1,
	mb2 = Enum.UserInputType.MouseButton2,
	m2 = Enum.UserInputType.MouseButton2,
	mouse2 = Enum.UserInputType.MouseButton2,
	mousebutton2 = Enum.UserInputType.MouseButton2,
}

local function Is_Mouse_Bind(Key)
	return Mouse_Bind_Types[Key] ~= nil
end

local function Is_Bind(Key)
	return Is_KeyCode(Key) or Is_Mouse_Bind(Key)
end

local function Bind_Name(Key)
	if Is_Mouse_Bind(Key) then
		return Mouse_Bind_Types[Key]
	end
	if Is_KeyCode(Key) then
		return Key.Name:lower()
	end
	return "none"
end

local function Parse_Bind(Value)
	if Is_Bind(Value) then
		return Value
	end
	if Type_Of(Value) ~= "string" then
		return Enum.KeyCode.Unknown
	end
	local Name = Value:gsub("%s+", ""):lower()
	if Name == "" or Name == "none" or Name == "unknown" then
		return Enum.KeyCode.Unknown
	end
	if Mouse_Bind_Aliases[Name] then
		return Mouse_Bind_Aliases[Name]
	end
	local Ok, Found = pcall(function()
		return Enum.KeyCode[Value]
	end)
	if Ok and Is_KeyCode(Found) then
		return Found
	end
	for _, Item in ipairs(Enum.KeyCode:GetEnumItems()) do
		if Item.Name:lower() == Name then
			return Item
		end
	end
	local Ok_Ui, Ui = pcall(function()
		return Enum.UserInputType[Value]
	end)
	if Ok_Ui and Is_Mouse_Bind(Ui) then
		return Ui
	end
	return Enum.KeyCode.Unknown
end

local function Input_Matches_Bind(Input, Bind)
	if not Input or not Is_Bind(Bind) then
		return false
	end
	if Is_Mouse_Bind(Bind) then
		return Input.UserInputType == Bind
	end
	return Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode == Bind
end

local Clone_Ref = function(Obj)
	return Obj
end
if Is_Function(cloneref) then
	Clone_Ref = cloneref
elseif type(cloneref) == "table" then
	local Ok_MT, MT = pcall(getmetatable, cloneref)
	if Ok_MT and type(MT) == "table" then
		local Call = MT.__call
		if Is_Function(Call) then
			Clone_Ref = cloneref
		end
	end
end

local function Safe_Service(Name)
	return Clone_Ref(game:GetService(Name))
end

local Players = Safe_Service("Players")
local UserInputService = Safe_Service("UserInputService")
local TweenService = Safe_Service("TweenService")
local RunService = Safe_Service("RunService")
local TextService = Safe_Service("TextService")
local HttpService = Safe_Service("HttpService")
local CoreGui = Safe_Service("CoreGui")
local Workspace = Safe_Service("Workspace")

local LocalPlayer = Clone_Ref(Players.LocalPlayer)
local Mouse = Clone_Ref(LocalPlayer:GetMouse())

local function Get_Camera()
	local Cam = Workspace.CurrentCamera
	return Cam and Clone_Ref(Cam) or nil
end

local function Get_Mouse_Location()
	local Ok, Pos = pcall(function()
		return UserInputService:GetMouseLocation()
	end)
	if Ok and Pos ~= nil and Pos.X ~= nil and Pos.Y ~= nil then
		return Pos
	end
	return Vector2.new(Mouse.X, Mouse.Y)
end

--------------------------------------------------------------------
-- Theme / Fonts
--------------------------------------------------------------------
local Theme = {
	Background = Color3.fromRGB(14, 14, 18),
	Window = Color3.fromRGB(18, 18, 24),
	Panel = Color3.fromRGB(22, 22, 30),
	Groupbox = Color3.fromRGB(20, 20, 28),
	Border = Color3.fromRGB(48, 48, 62),
	Border_Light = Color3.fromRGB(68, 68, 88),
	Accent = Color3.fromRGB(232, 168, 210),
	Accent_Mid = Color3.fromRGB(186, 170, 230),
	Accent_End = Color3.fromRGB(150, 170, 235),
	Accent_Dim = Color3.fromRGB(140, 120, 180),
	Text = Color3.fromRGB(228, 228, 238),
	Text_Dim = Color3.fromRGB(150, 150, 168),
	Text_Dark = Color3.fromRGB(100, 100, 118),
	Toggle_Off = Color3.fromRGB(36, 36, 48),
	Toggle_On = Color3.fromRGB(232, 168, 210),
	Slider_Back = Color3.fromRGB(30, 30, 40),
	Slider_Fill = Color3.fromRGB(200, 168, 220),
	Input_Back = Color3.fromRGB(16, 16, 22),
	Hover = Color3.fromRGB(34, 34, 46),
	Shine = Color3.fromRGB(255, 255, 255),
}

local Brand_Font
do
	local From_Enum = (Font and Font.fromEnum) or nil
	if Is_Function(From_Enum) then
		local Ok, Font_Face = Safe_Call(From_Enum, Enum.Font.BuilderSansExtraBold)
		if Ok and Font_Face then
			Brand_Font = Font_Face
		end
	end
	if not Brand_Font and Font and Is_Function(Font.new) then
		local Ok, Font_Face = Safe_Call(
			Font.new,
			"rbxasset://fonts/families/BuilderSans.json",
			Enum.FontWeight.ExtraBold,
			Enum.FontStyle.Normal
		)
		if Ok and Font_Face then
			Brand_Font = Font_Face
		end
	end
	if not Brand_Font then
		-- last resort: any available face
		if Is_Function(From_Enum) then
			local Ok, Font_Face = Safe_Call(From_Enum, Enum.Font.GothamBold)
			Brand_Font = Ok and Font_Face or nil
		end
	end
	if not Brand_Font then
		error("eggtech: failed to resolve UI font")
	end
end
local Fonts = {
	Main = Brand_Font,
	Medium = Brand_Font,
	Bold = Brand_Font,
	Segoe = Brand_Font,
	Code = Brand_Font,
}

local Font_Choices = {}
local Font_Map = {}

local From_Enum = Font and Font.fromEnum
for _, Font_Enum in ipairs(Enum.Font:GetEnumItems()) do
	if Font_Enum ~= Enum.Font.Unknown then
		local Name = Font_Enum.Name
		if Is_Function(From_Enum) then
			local Ok, Face = Safe_Call(From_Enum, Font_Enum)
			if Ok and Face then
				Font_Map[Name] = Face
				table.insert(Font_Choices, Name)
			end
		end
	end
end
table.sort(Font_Choices, function(A, B)
	return A:lower() < B:lower()
end)

-- Force brand font everywhere
Fonts.Main = Brand_Font
Fonts.Medium = Brand_Font
Fonts.Bold = Brand_Font
Fonts.Segoe = Brand_Font
Fonts.Code = Brand_Font
Font_Map["BuilderSansExtraBold"] = Brand_Font

--------------------------------------------------------------------
-- Library
--------------------------------------------------------------------
local Library = {
	Flags = {},
	Options = {},
	Keybinds = {},
	Connections = {},
	Windows = {},
	Text_Objects = setmetatable({}, { __mode = "k" }),
	Current_Font = Brand_Font,
	Open_Dropdown = nil,
	Open_Color_Picker = nil,
	Copied_Color = nil,
	Copied_Hex = nil,
	Cursor_Enabled = false,
	UI_Open = false,
	Unloaded = false,
	Config_Folder = "eggytechy",
}

local function Protect_Gui(Gui)
	if Is_Function(gethui) then
		local Ok, Hui = Safe_Call(gethui)
		if Ok and Hui then
			Gui.Parent = Hui
			return Gui
		end
	end
	if type(syn) == "table" and Is_Function(syn.protect_gui) then
		Safe_Call(syn.protect_gui, Gui)
		Gui.Parent = CoreGui
		return Gui
	end
	if Is_Function(protectgui) then
		Safe_Call(protectgui, Gui)
	end
	local Ok = pcall(function()
		Gui.Parent = CoreGui
	end)
	if not Ok or not Gui.Parent then
		Gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
	return Gui
end

local function Create(Class, Props, Children)
	local Obj = Instance.new(Class)
	for Prop, Value in pairs(Props or {}) do
		if Prop ~= "Parent" then
			Obj[Prop] = Value
		end
	end
	for _, Child in ipairs(Children or {}) do
		Child.Parent = Obj
	end
	if Props and Props.Parent then
		Obj.Parent = Props.Parent
	end
	if Obj:IsA("TextLabel") or Obj:IsA("TextButton") or Obj:IsA("TextBox") then
		Library.Text_Objects[Obj] = true
		Obj.FontFace = Library.Current_Font or Brand_Font
	end
	return Obj
end

function Library:Set_Font(Font_Name)
	local Font_Face = Font_Map[Font_Name] or Brand_Font
	Library.Current_Font = Font_Face
	Fonts.Main = Font_Face
	Fonts.Medium = Font_Face
	Fonts.Bold = Font_Face
	Fonts.Segoe = Font_Face
	Fonts.Code = Font_Face
	for Text_Object in pairs(Library.Text_Objects) do
		if Text_Object.Parent then
			Text_Object.FontFace = Font_Face
		else
			Library.Text_Objects[Text_Object] = nil
		end
	end
	return true
end

function Library:Get_Fonts()
	if Is_Function(table.clone) then
		return table.clone(Font_Choices)
	end
	local Copy = {}
	for i, V in ipairs(Font_Choices) do
		Copy[i] = V
	end
	return Copy
end

--------------------------------------------------------------------
-- Config helpers (eggytechy folder)
--------------------------------------------------------------------
local function Register_Option(Flag, Type, Api)
	if not Flag or not Api then
		return
	end
	Library.Options[Flag] = {
		Type = Type,
		Api = Api,
	}
end

local function Config_Path(Name)
	Name = tostring(Name or "default"):gsub("[^%w%-%_]", "")
	if Name == "" then
		Name = "default"
	end
	return Library.Config_Folder .. "/" .. Name .. ".json", Name
end

local function Ensure_Config_Folder()
	if Type_Of(isfolder) ~= "function" or Type_Of(makefolder) ~= "function" then
		return Type_Of(writefile) == "function"
	end
	local Acc = ""
	for Part in string.gmatch(tostring(Library.Config_Folder), "[^/\\]+") do
		Acc = (Acc == "") and Part or (Acc .. "/" .. Part)
		if not isfolder(Acc) then
			pcall(makefolder, Acc)
		end
	end
	return true
end

local function Is_Color3(Value)
	if Value == nil then
		return false
	end
	if Type_Of(Value) == "Color3" then
		return true
	end
	local Ok = pcall(function()
		return Value.R + Value.G + Value.B
	end)
	return Ok == true
end

local function Serialize_Value(Type, Value)
	if Type == "Color" then
		if Is_Color3(Value) then
			return {
				R = math.floor(Value.R * 255 + 0.5),
				G = math.floor(Value.G * 255 + 0.5),
				B = math.floor(Value.B * 255 + 0.5),
			}
		end
		return Value
	elseif Type == "Keybind" then
		if Type_Of(Value) == "table" then
			return {
				Key = Value.Key or "Unknown",
				Mode = Value.Mode or "Toggle",
			}
		end
		return { Key = "Unknown", Mode = "Toggle" }
	elseif Type == "MultiDropdown" then
		if Type_Of(Value) == "table" then
			local Out = {}
			for i, V in ipairs(Value) do
				Out[i] = V
			end
			return Out
		end
		return {}
	end
	return Value
end

local function Deserialize_Value(Type, Value)
	if Type == "Color" then
		if Type_Of(Value) == "table" and Value.R then
			return Color3.fromRGB(Value.R or 0, Value.G or 0, Value.B or 0)
		elseif Type_Of(Value) == "string" then
			local Hex = Value:gsub("#", "")
			if #Hex == 6 then
				return Color3.fromRGB(
					tonumber(Hex:sub(1, 2), 16) or 0,
					tonumber(Hex:sub(3, 4), 16) or 0,
					tonumber(Hex:sub(5, 6), 16) or 0
				)
			end
		end
		return Theme.Accent
	elseif Type == "Keybind" then
		if Type_Of(Value) == "table" then
			return Value
		end
		return { Key = "Unknown", Mode = "Toggle" }
	end
	return Value
end

function Library:Get_Config_List()
	local List = {}
	if not Ensure_Config_Folder() or Type_Of(listfiles) ~= "function" then
		return List
	end
	local Ok, Files = pcall(listfiles, Library.Config_Folder)
	if not Ok or Type_Of(Files) ~= "table" then
		return List
	end
	for _, Path in ipairs(Files) do
		local Name = tostring(Path):gsub("\\", "/"):match("([^/]+)%.json$")
		if Name then
			table.insert(List, Name)
		end
	end
	table.sort(List, function(A, B)
		return A:lower() < B:lower()
	end)
	return List
end

function Library:Save_Config(Name)
	local Path, Clean = Config_Path(Name or Library.Flags.config_name)
	if not Ensure_Config_Folder() or Type_Of(writefile) ~= "function" then
		return false, "filesystem unavailable"
	end
	local Data = {
		__eggtech = true,
		__name = Clean,
		flags = {},
	}
	for Flag, Opt in pairs(Library.Options) do
		if Flag ~= "config_list" then
			local Ok, Value = pcall(function()
				return Opt.Api:Get()
			end)
			if Ok then
				Data.flags[Flag] = Serialize_Value(Opt.Type, Value)
			end
		end
	end
	local Ok, Encoded = pcall(function()
		return HttpService:JSONEncode(Data)
	end)
	if not Ok then
		return false, "encode failed"
	end
	local Write_Ok, Err = pcall(writefile, Path, Encoded)
	if not Write_Ok then
		return false, Err
	end
	if Library.Flags then
		Library.Flags.config_name = Clean
	end
	return true, Clean
end

function Library:Load_Config(Name)
	local Path, Clean = Config_Path(Name or Library.Flags.config_list or Library.Flags.config_name)
	if Type_Of(readfile) ~= "function" then
		return false, "filesystem unavailable"
	end
	if Type_Of(isfile) == "function" and not isfile(Path) then
		return false, "config not found"
	end
	local Ok, Raw = pcall(readfile, Path)
	if not Ok or Type_Of(Raw) ~= "string" then
		return false, "config not found"
	end
	local Dec_Ok, Data = pcall(function()
		return HttpService:JSONDecode(Raw)
	end)
	if not Dec_Ok or Type_Of(Data) ~= "table" then
		return false, "invalid config"
	end
	local Flags = Data.flags or Data
	for Flag, Value in pairs(Flags) do
		if Flag ~= "__eggtech" and Flag ~= "__name" and Flag ~= "config_list" then
			local Opt = Library.Options[Flag]
			if Opt and Opt.Api and Opt.Api.Set then
				local Val = Deserialize_Value(Opt.Type, Value)
				pcall(function()
					Opt.Api:Set(Val)
				end)
			end
		end
	end
	if Library.Options.config_name and Library.Options.config_name.Api then
		pcall(function()
			Library.Options.config_name.Api:Set(Clean)
		end)
	end
	if Library.Options.config_list and Library.Options.config_list.Api then
		pcall(function()
			Library.Options.config_list.Api:Set(Clean)
		end)
	end
	return true, Clean
end

function Library:Overwrite_Config(Name)
	return Library:Save_Config(Name or Library.Flags.config_list or Library.Flags.config_name)
end

function Library:Delete_Config(Name)
	local Path, Clean = Config_Path(Name or Library.Flags.config_list)
	if Type_Of(delfile) ~= "function" then
		return false, "delete unavailable"
	end
	local Ok, Err = pcall(delfile, Path)
	if not Ok then
		return false, Err
	end
	return true, Clean
end

function Library:Refresh_Config_List()
	return Library:Get_Config_List()
end

local function Round(Num, Places)
	local Mult = 10 ^ (Places or 0)
	return math.floor(Num * Mult + 0.5) / Mult
end

local function Clamp(Val, Min, Max)
	return math.max(Min, math.min(Max, Val))
end

local function Connect(Signal, Fn)
	local Conn = Signal:Connect(Fn)
	table.insert(Library.Connections, Conn)
	return Conn
end

local function Tween(Obj, Props, Time, Style, Dir)
	local Info = TweenInfo.new(Time or 0.15, Style or Enum.EasingStyle.Quart, Dir or Enum.EasingDirection.Out)
	local T = TweenService:Create(Obj, Info, Props)
	T:Play()
	return T
end

local function Make_Draggable(Frame, Handle)
	Handle = Handle or Frame
	local Dragging, Drag_Start, Start_Pos

	Connect(Handle.InputBegan, function(Input)
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Dragging = true
			Drag_Start = Input.Position
			Start_Pos = Frame.Position
			Input.Changed:Connect(function()
				if Input.UserInputState == Enum.UserInputState.End then
					Dragging = false
				end
			end)
		end
	end)

	Connect(UserInputService.InputChanged, function(Input)
		if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
			local Delta = Input.Position - Drag_Start
			Frame.Position = UDim2.new(
				Start_Pos.X.Scale,
				Start_Pos.X.Offset + Delta.X,
				Start_Pos.Y.Scale,
				Start_Pos.Y.Offset + Delta.Y
			)
		end
	end)
end

local function Stroke(Parent, Color, Thickness)
	return Create("UIStroke", {
		Parent = Parent,
		Color = Color or Theme.Border,
		Thickness = Thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Pink → periwinkle top accent bar (like reference)
local function Accent_Bar(Parent, Z)
	local Bar = Create("Frame", {
		Parent = Parent,
		Name = "Accent_Bar",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = Z or ((Parent.ZIndex or 1) + 1),
	})
	Create("UIGradient", {
		Parent = Bar,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.Accent),
			ColorSequenceKeypoint.new(0.5, Theme.Accent_Mid),
			ColorSequenceKeypoint.new(1, Theme.Accent_End),
		}),
	})
	return Bar
end

-- Soft diagonal shine overlay for toggles / buttons / swatches
local function Shiny(Parent, Z)
	local Shine = Create("Frame", {
		Parent = Parent,
		Name = "Shine",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0.55, 0),
		ZIndex = Z or ((Parent.ZIndex or 1) + 2),
	})
	Create("UIGradient", {
		Parent = Shine,
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.45, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
	return Shine
end

--------------------------------------------------------------------
-- Icons (rbxassetid via cloneref'd ContentProvider preload)
--------------------------------------------------------------------
local ContentProvider = Safe_Service("ContentProvider")

local Icons = {
	egg = "rbxassetid://117851493400222",
	keyboard = "rbxassetid://121474456068237",
	activity = "rbxassetid://94212016861936",
	user = "rbxassetid://81589895647169",
	hammer = "rbxassetid://83545120140895",
	clock = "rbxassetid://121808839832144",
	cpu = "rbxassetid://77549309870247",
	crown = "rbxassetid://127843403295538",
	zap = "rbxassetid://130551565616516",
	settings = "rbxassetid://80758916183665",
	mouse_pointer = "rbxassetid://117093892862228",
	pointer = "rbxassetid://92615117311099",
}

local function Resolve_Asset(Ref)
	if Ref == nil or Ref == "" then
		return ""
	end
	local Str = tostring(Ref)
	if Str:sub(1, 13) == "rbxassetid://" or Str:sub(1, 11) == "rbxasset://" then
		return Str
	end
	local Id = Str:match("%d+")
	if Id then
		return "rbxassetid://" .. Id
	end
	return Str
end

function Library:Get_Icon(Name_Or_Id)
	if Icons[Name_Or_Id] then
		return Icons[Name_Or_Id]
	end
	return Resolve_Asset(Name_Or_Id)
end

local function Make_Icon(Parent, Icon_Id, Props)
	Props = Props or {}
	local Resolved = Resolve_Asset(Icon_Id)
	local Img = Create("ImageLabel", {
		Parent = Parent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = Resolved,
		ImageColor3 = Props.Color or Theme.Text,
		Size = Props.Size or UDim2.new(0, 14, 0, 14),
		Position = Props.Position or UDim2.new(0, 0, 0.5, -7),
		AnchorPoint = Props.AnchorPoint or Vector2.new(0, 0),
		ZIndex = Props.ZIndex or ((Parent.ZIndex or 1) + 1),
	})
	-- preload through cloneref'd ContentProvider (no writefile/getcustomasset)
	pcall(function()
		ContentProvider:PreloadAsync({ Img })
	end)
	return Img
end

local function Next_Order(Container)
	Container._Order = (Container._Order or 0) + 1
	return Container._Order
end

--------------------------------------------------------------------
-- Screen Gui Root
--------------------------------------------------------------------
local Screen_Gui = Protect_Gui(Create("ScreenGui", {
	Name = "eggtech_UI_" .. HttpService:GenerateGUID(false),
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 2147483647,
}))

-- Always-on-top layers (must beat color pickers ~220, tips ~250, etc.)
local Z_NOTIFY = 50000
local Z_CURSOR = 60000

--------------------------------------------------------------------
-- Animated brand title (slow smooth scrolling gradient)
--------------------------------------------------------------------
local Gradient_Colors = {
	Theme.Accent,
	Theme.Accent_Mid,
	Theme.Accent_End,
	Color3.fromRGB(255, 200, 230),
	Color3.fromRGB(170, 190, 255),
	Theme.Accent,
}

local function Sample_Gradient(T)
	-- T wraps 0..1 along the color loop
	T = T % 1
	local Segs = #Gradient_Colors - 1
	local Scaled = T * Segs
	local Idx = math.floor(Scaled) + 1
	local Alpha = Scaled - math.floor(Scaled)
	local A = Gradient_Colors[Idx]
	local B = Gradient_Colors[math.min(Idx + 1, #Gradient_Colors)]
	return A:Lerp(B, Alpha)
end

local function Create_Animated_Title(Parent, Text_Size, Z)
	Text_Size = Text_Size or 14
	Z = Z or 3

	local Holder = Create("Frame", {
		Parent = Parent,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(1, -40, 1, 0),
		ZIndex = Z,
	})
	Create("UIListLayout", {
		Parent = Holder,
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	local Animated = {}
	local Order = 0

	local function Add_Animated(Text)
		for i = 1, #Text do
			Order += 1
			local Char = Text:sub(i, i)
			local Label = Create("TextLabel", {
				Parent = Holder,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				FontFace = Brand_Font,
				Text = Char,
				TextColor3 = Sample_Gradient((Order - 1) / math.max(#Text, 1)),
				TextSize = Text_Size,
				LayoutOrder = Order,
				ZIndex = Z + 1,
			})
			if Char == " " then
				Label.Size = UDim2.new(0, 5, 1, 0)
				Label.AutomaticSize = Enum.AutomaticSize.None
			end
			table.insert(Animated, Label)
		end
	end

	-- eggtech | geteggtech  (gradient)  +  .xyz (white)
	Add_Animated("eggtech | geteggtech")

	Create("TextLabel", {
		Parent = Holder,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		FontFace = Brand_Font,
		Text = ".xyz",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = Text_Size,
		LayoutOrder = Order + 1,
		ZIndex = Z + 1,
	})

	local Count = math.max(#Animated, 1)
	local Title_Acc = 0
	Connect(RunService.Heartbeat, function(Dt)
		Title_Acc += Dt or 0
		if Title_Acc < (1 / 30) then
			return
		end
		Title_Acc = 0
		if not Holder.Parent or not Holder.Visible then
			return
		end
		local Scroll = tick() * 0.12
		for i, Label in ipairs(Animated) do
			Label.TextColor3 = Sample_Gradient(Scroll + (i - 1) / Count)
		end
	end)

	return Holder
end

--------------------------------------------------------------------
-- Custom cursor — exact eggyUI cursor.png, gradient tinted
--------------------------------------------------------------------
local CURSOR_URL = "https://raw.githubusercontent.com/xhafoownerdev/eggyUI/main/cursor.png"

local function Cursor_Http_Get(Url)
	local Requesters = {
		type(syn) == "table" and syn.request,
		type(http) == "table" and http.request,
		type(fluxus) == "table" and fluxus.request,
		http_request,
		request,
	}
	for _, Fn in ipairs(Requesters) do
		if Is_Function(Fn) then
			local Ok, Res = pcall(Fn, { Url = Url, Method = "GET" })
			if Ok and type(Res) == "table" then
				local Body = Res.Body or Res.body
				if type(Body) == "string" and #Body > 0 then
					return Body
				end
			end
		end
	end
	local Ok, Body = pcall(function()
		return game:HttpGet(Url)
	end)
	if Ok and type(Body) == "string" and #Body > 0 then
		return Body
	end
	return nil
end

local function Resolve_Cursor_Image()
	if not Is_Function(getcustomasset) or not Is_Function(writefile) then
		return nil
	end

	local Path = (Library.Config_Folder or "eggytechy") .. "/cursor.png"
	local function Load_Custom()
		local Ok, Asset = pcall(getcustomasset, Path)
		if Ok and type(Asset) == "string" and Asset ~= "" then
			return Asset
		end
		return nil
	end

	-- Reuse the cached PNG when it's already a valid image on disk
	if Is_Function(isfile) then
		local Exists = false
		pcall(function()
			Exists = isfile(Path)
		end)
		if Exists then
			local Valid = true
			if Is_Function(readfile) then
				local Ok_Read, Data = pcall(readfile, Path)
				Valid = Ok_Read and type(Data) == "string" and Data:sub(1, 8) == "\137PNG\r\n\26\n"
			end
			if Valid then
				local Cached = Load_Custom()
				if Cached then
					return Cached
				end
			end
		end
	end

	local Data = Cursor_Http_Get(CURSOR_URL)
	if type(Data) ~= "string" or Data:sub(1, 8) ~= "\137PNG\r\n\26\n" then
		return nil
	end

	Ensure_Config_Folder()
	local Write_Ok = pcall(writefile, Path, Data)
	if not Write_Ok then
		return nil
	end
	return Load_Custom()
end

local Cursor_Image_Id = Resolve_Cursor_Image() or Icons.mouse_pointer

local Cursor_Root = Create("Frame", {
	Parent = Screen_Gui,
	Name = "Custom_Cursor",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.new(0, 22, 0, 26),
	-- Tip sits on the mouse position
	AnchorPoint = Vector2.new(0.06, 0.04),
	Visible = false,
	ZIndex = Z_CURSOR,
})

local function Make_Cursor_Layer(Z, Size_Pad, Pos_Pad, Color, Transparency)
	return Create("ImageLabel", {
		Parent = Cursor_Root,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = Cursor_Image_Id or "",
		ImageColor3 = Color,
		ImageTransparency = Transparency or 0,
		Size = UDim2.new(1, Size_Pad, 1, Size_Pad),
		Position = UDim2.new(0, Pos_Pad, 0, Pos_Pad),
		ZIndex = Z,
		ScaleType = Enum.ScaleType.Fit,
		Visible = Cursor_Image_Id ~= nil,
	})
end

-- Thin dark edge for definition
local Cursor_Rim = Make_Cursor_Layer(Z_CURSOR + 1, 2, -1, Color3.fromRGB(18, 16, 26), 0.25)

-- Solid triangle with periwinkle (tip) → light pink (base)
local Cursor_Fill = Make_Cursor_Layer(Z_CURSOR + 2, 0, 0, Color3.fromRGB(255, 255, 255), 0)
local Cursor_Grad = Create("UIGradient", {
	Parent = Cursor_Fill,
	Rotation = 118,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Accent_End),
		ColorSequenceKeypoint.new(0.5, Theme.Accent_Mid),
		ColorSequenceKeypoint.new(1, Theme.Accent),
	}),
})

-- Bright tip highlight (keeps it looking sharp/pointy)
local Cursor_Tip = Make_Cursor_Layer(Z_CURSOR + 3, -2, 1, Color3.fromRGB(255, 255, 255), 0.55)
Create("UIGradient", {
	Parent = Cursor_Tip,
	Rotation = 118,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.28, 0.65),
		NumberSequenceKeypoint.new(1, 1),
	}),
})

local Cursor_Grad_Scroll = 0
Connect(RunService.Heartbeat, function(Dt)
	if not Library.Cursor_Enabled or not Cursor_Grad.Parent then
		return
	end
	Cursor_Grad_Scroll = (Cursor_Grad_Scroll + (Dt or 0) * 0.4) % 1
	local T = Cursor_Grad_Scroll
	local function Mix(A, B, Alpha)
		return Color3.new(
			A.R + (B.R - A.R) * Alpha,
			A.G + (B.G - A.G) * Alpha,
			A.B + (B.B - A.B) * Alpha
		)
	end
	local A1 = math.sin(T * math.pi * 2) * 0.5 + 0.5
	local A2 = math.sin((T + 0.33) * math.pi * 2) * 0.5 + 0.5
	Cursor_Grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Mix(Theme.Accent_End, Theme.Accent_Mid, A1)),
		ColorSequenceKeypoint.new(0.5, Mix(Theme.Accent_Mid, Theme.Accent, A2)),
		ColorSequenceKeypoint.new(1, Mix(Theme.Accent, Theme.Accent_End, 1 - A1)),
	})
end)

local function Set_Custom_Cursor(Enabled)
	Library.Cursor_Enabled = Enabled and true or false
	Cursor_Root.Visible = Library.Cursor_Enabled
	UserInputService.MouseIconEnabled = not Library.Cursor_Enabled
end

Connect(RunService.RenderStepped, function()
	if not Library.Cursor_Enabled then
		return
	end
	local Pos = Get_Mouse_Location()
	Cursor_Root.Position = UDim2.new(0, Pos.X, 0, Pos.Y)
end)

Library.Set_Custom_Cursor = Set_Custom_Cursor

--------------------------------------------------------------------
-- Watermark
--------------------------------------------------------------------
function Library:Create_Watermark(Options)
	Options = Options or {}
	local Uid = Options.Uid or 1
	local Brand = Options.Name or "eggtech"

	local Frame = Create("Frame", {
		Parent = Screen_Gui,
		Name = "Watermark",
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0, 240, 0, 24),
		ZIndex = 100,
	})
	Stroke(Frame, Theme.Border)
	Accent_Bar(Frame, 102)

	-- Brand name gets its own per-character scrolling gradient
	local Brand_Holder = Create("Frame", {
		Parent = Frame,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 2),
		Size = UDim2.new(0, 0, 1, -2),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 101,
	})
	Create("UIListLayout", {
		Parent = Brand_Holder,
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local Brand_Chars = {}
	for i = 1, #Brand do
		local Char = Brand:sub(i, i)
		local Label = Create("TextLabel", {
			Parent = Brand_Holder,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			FontFace = Fonts.Main,
			Text = Char,
			TextColor3 = Sample_Gradient((i - 1) / math.max(#Brand, 1)),
			TextSize = 12,
			LayoutOrder = i,
			ZIndex = 102,
		})
		if Char == " " then
			Label.AutomaticSize = Enum.AutomaticSize.None
			Label.Size = UDim2.new(0, 5, 1, 0)
		end
		table.insert(Brand_Chars, Label)
	end

	local Brand_Count = math.max(#Brand_Chars, 1)
	local Brand_Acc = 0
	Connect(RunService.Heartbeat, function(Dt)
		Brand_Acc += Dt or 0
		if Brand_Acc < (1 / 30) then
			return
		end
		Brand_Acc = 0
		if not Frame.Visible or not Frame.Parent then
			return
		end
		local Scroll = tick() * 0.12
		for i, Label in ipairs(Brand_Chars) do
			Label.TextColor3 = Sample_Gradient(Scroll + (i - 1) / Brand_Count)
		end
	end)

	local Label = Create("TextLabel", {
		Parent = Frame,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 2),
		Size = UDim2.new(0, 0, 1, -2),
		AutomaticSize = Enum.AutomaticSize.X,
		FontFace = Fonts.Main,
		Text = "",
		TextColor3 = Theme.Text,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 101,
	})

	Make_Draggable(Frame)

	local Api = {}
	function Api:Set_Text(New)
		-- Brand is rendered separately; pad the stats text past it
		local Brand_W = Brand_Holder.AbsoluteSize.X
		if Brand_W <= 0 then
			Brand_W = TextService:GetTextSize(Brand, 12, Enum.Font.BuilderSansExtraBold, Vector2.new(1000, 22)).X
		end
		Label.Position = UDim2.new(0, 10 + Brand_W, 0, 2)
		Label.Text = New
		local Bounds = TextService:GetTextSize(New, 12, Enum.Font.BuilderSansExtraBold, Vector2.new(1000, 22))
		-- Tight fit: left pad + brand + stats + right pad
		Frame.Size = UDim2.new(0, 10 + Brand_W + Bounds.X + 10, 0, 24)
	end
	function Api:Set_Visible(V)
		Frame.Visible = V
	end
	function Api:Set_Uid(New)
		Uid = New
	end

	Api:Set_Text(string.format("  |  fps: 0  |  uid : %s", tostring(Uid)))
	-- Recalc once AbsoluteSize is available
	task.defer(function()
		Api:Set_Text(string.format("  |  fps: 0  |  uid : %s", tostring(Uid)))
	end)

	local Frames, Last = 0, tick()
	Connect(RunService.RenderStepped, function()
		Frames += 1
		if tick() - Last >= 1 then
			Api:Set_Text(string.format("  |  fps: %d  |  uid : %s", Frames, tostring(Uid)))
			Frames = 0
			Last = tick()
		end
	end)

	Library.Watermark = Api
	return Api
end

--------------------------------------------------------------------
-- Keybind Frame (filter via Library UI: all / active)
--------------------------------------------------------------------
function Library:Create_Keybind_Frame(Options)
	Options = Options or {}

	local Row_H = 14
	local Row_Gap = 3
	local Title_H = 26
	local Pad_Bottom = 10
	local Frame_W = 170
	local Filter_Mode = "all" -- "all" | "active"

	local Frame = Create("Frame", {
		Parent = Screen_Gui,
		Name = "Keybind_Frame",
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 12, 0.5, -70),
		Size = UDim2.new(0, Frame_W, 0, Title_H + Pad_Bottom),
		Active = true,
		ClipsDescendants = false,
		ZIndex = 100,
	})
	Stroke(Frame, Theme.Border)
	Accent_Bar(Frame, 102)

	local Title_Bar = Create("Frame", {
		Parent = Frame,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1, 0, 0, 24),
		Active = true,
		ZIndex = 101,
	})
	Create("Frame", {
		Parent = Title_Bar,
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 102,
	})

	Create("TextLabel", {
		Parent = Title_Bar,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -36, 1, 0),
		FontFace = Fonts.Medium,
		Text = Options.Title or "Keybinds",
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 103,
	})

	Make_Icon(Title_Bar, Icons.keyboard, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		Color = Color3.fromRGB(255, 255, 255),
		ZIndex = 103,
	})

	local List_Wrap = Create("Frame", {
		Parent = Frame,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 8, 0, Title_H + 2),
		Size = UDim2.new(1, -16, 0, 0),
		ClipsDescendants = true,
		ZIndex = 101,
	})

	local List = Create("Frame", {
		Parent = List_Wrap,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 102,
	})

	Make_Draggable(Frame, Title_Bar)

	local Rows = {}
	local Order = {}
	local Api = {}
	local Anim_Token = 0

	local function Should_Show(Entry)
		if Filter_Mode == "active" then
			return Entry.Active
		end
		return true
	end

	local function Target_List_Height()
		local N = 0
		for _, Name in ipairs(Order) do
			local Entry = Rows[Name]
			if Entry and Should_Show(Entry) then
				N += 1
			end
		end
		if N <= 0 then
			return 0
		end
		return N * Row_H + (N - 1) * Row_Gap
	end

	local function Frame_Height_For(List_H)
		return Title_H + 2 + List_H + Pad_Bottom
	end

	local function Relayout(Animate)
		Anim_Token += 1
		local Token = Anim_Token
		local Y = 0
		local Dur = Animate and 0.24 or 0

		for _, Name in ipairs(Order) do
			local Entry = Rows[Name]
			if Entry and Entry.Row and Entry.Row.Parent then
				local Show = Should_Show(Entry)
				if Show then
					local Pos = UDim2.new(0, 0, 0, Y)
					local Size = UDim2.new(1, 0, 0, Row_H)
					Entry.Row.Visible = true
					if Animate then
						Tween(Entry.Row, { Position = Pos, Size = Size }, Dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
						Tween(Entry.Name, { TextTransparency = 0 }, Dur * 0.85)
						Tween(Entry.Key, { TextTransparency = 0 }, Dur * 0.85)
					else
						Entry.Row.Position = Pos
						Entry.Row.Size = Size
						Entry.Name.TextTransparency = 0
						Entry.Key.TextTransparency = 0
					end
					Y += Row_H + Row_Gap
				else
					if Animate then
						Tween(Entry.Name, { TextTransparency = 1 }, Dur * 0.5)
						Tween(Entry.Key, { TextTransparency = 1 }, Dur * 0.5)
						Tween(Entry.Row, { Size = UDim2.new(1, 0, 0, 0) }, Dur, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
					else
						Entry.Name.TextTransparency = 1
						Entry.Key.TextTransparency = 1
						Entry.Row.Size = UDim2.new(1, 0, 0, 0)
						Entry.Row.Visible = false
					end
				end
			end
		end

		local List_H = Target_List_Height()
		local Frame_H = Frame_Height_For(List_H)
		if Animate then
			Tween(List_Wrap, { Size = UDim2.new(1, -16, 0, List_H) }, Dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			Tween(Frame, { Size = UDim2.new(0, Frame_W, 0, Frame_H) }, Dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			task.delay(Dur, function()
				if Token ~= Anim_Token then
					return
				end
				for _, Name in ipairs(Order) do
					local Entry = Rows[Name]
					if Entry and Entry.Row and Entry.Row.Parent and not Should_Show(Entry) then
						Entry.Row.Visible = false
					end
				end
			end)
		else
			List_Wrap.Size = UDim2.new(1, -16, 0, List_H)
			Frame.Size = UDim2.new(0, Frame_W, 0, Frame_H)
			for _, Name in ipairs(Order) do
				local Entry = Rows[Name]
				if Entry and Entry.Row and not Should_Show(Entry) then
					Entry.Row.Visible = false
				end
			end
		end
	end

	local function Set_Filter(Mode, Animate)
		Filter_Mode = (Mode == "active") and "active" or "all"
		Relayout(Animate ~= false)
	end

	function Api:Add(Name, Key_Text)
		if Rows[Name] then
			Rows[Name].Key.Text = "[" .. Key_Text .. "]"
			return
		end

		local Row = Create("Frame", {
			Parent = List,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 0, 0),
			ClipsDescendants = true,
			Visible = false,
			ZIndex = 102,
		})
		local N = Create("TextLabel", {
			Parent = Row,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.62, 0, 0, Row_H),
			FontFace = Fonts.Main,
			Text = Name,
			TextColor3 = Theme.Text_Dim,
			TextTransparency = 1,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 103,
		})
		local K = Create("TextLabel", {
			Parent = Row,
			BackgroundTransparency = 1,
			Position = UDim2.new(0.62, 0, 0, 0),
			Size = UDim2.new(0.38, 0, 0, Row_H),
			FontFace = Fonts.Code,
			Text = "[" .. Key_Text .. "]",
			TextColor3 = Theme.Text_Dim,
			TextTransparency = 1,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 103,
		})
		Rows[Name] = { Row = Row, Name = N, Key = K, Active = false }
		table.insert(Order, Name)
		Relayout(true)
	end

	function Api:Set_Active(Name, Is_Active)
		local Entry = Rows[Name]
		if not Entry then
			return
		end
		local Was = Entry.Active
		Entry.Active = Is_Active and true or false
		-- Active binds: bright name + accent key
		Entry.Name.TextColor3 = Entry.Active and Theme.Text or Theme.Text_Dim
		Entry.Key.TextColor3 = Entry.Active and Theme.Accent or Theme.Text_Dim
		if Entry.Active then
			Entry.Name.TextTransparency = 0
			Entry.Key.TextTransparency = 0
		end
		if Filter_Mode == "active" and Was ~= Entry.Active then
			Relayout(true)
		end
	end

	function Api:Remove(Name)
		if not Rows[Name] then
			return
		end
		Rows[Name].Row:Destroy()
		Rows[Name] = nil
		for i, N in ipairs(Order) do
			if N == Name then
				table.remove(Order, i)
				break
			end
		end
		Relayout(true)
	end

	function Api:Set_Filter(Mode)
		Set_Filter(Mode, true)
	end

	function Api:Get_Filter()
		return Filter_Mode
	end

	function Api:Set_Visible(V)
		Frame.Visible = V
	end

	Set_Filter("all", false)
	Library.Keybind_Frame = Api
	return Api
end

--------------------------------------------------------------------
-- Control builders
--------------------------------------------------------------------
local function Build_Controls(Container, Content)
	local Controls = {}

	function Controls:Add_Label(Text)
		local Order = Next_Order(Container)
		local Label = Create("TextLabel", {
			Parent = Content,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 18),
			FontFace = Fonts.Main,
			Text = Text or "label",
			TextColor3 = Theme.Text_Dim,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = Order,
			ZIndex = 5,
		})
		local Api = {}
		function Api:Set_Text(T)
			Label.Text = T
		end
		return Api
	end

	function Controls:Add_Divider()
		local Order = Next_Order(Container)
		local Holder = Create("Frame", {
			Parent = Content,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 12),
			LayoutOrder = Order,
			ZIndex = 5,
		})
		-- Semi-gradient hairline: fades out at both ends
		local Line = Create("Frame", {
			Parent = Holder,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Size = UDim2.new(1, 0, 0, 1),
			ZIndex = 5,
		})
		Create("UIGradient", {
			Parent = Line,
			Color = ColorSequence.new(Theme.Border_Light),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.18, 0.4),
				NumberSequenceKeypoint.new(0.5, 0.28),
				NumberSequenceKeypoint.new(0.82, 0.4),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
		return Holder
	end

	function Controls:Add_Toggle(Options)
		Options = Options or {}
		local Flag = Options.Flag
		local Default = Options.Default or false
		local Callback = Options.Callback or function() end
		local Order = Next_Order(Container)

		if Flag then
			Library.Flags[Flag] = Default
		end

		local Holder = Create("Frame", {
			Parent = Content,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 20),
			LayoutOrder = Order,
			ZIndex = 5,
		})

		local Box = Create("TextButton", {
			Parent = Holder,
			BackgroundColor3 = Default and Theme.Toggle_On or Theme.Toggle_Off,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 9, 0, 9),
			Position = UDim2.new(0, 0, 0.5, -4),
			Text = "",
			AutoButtonColor = false,
			ClipsDescendants = true,
			ZIndex = 6,
		})
		Stroke(Box, Theme.Border_Light)
		local Box_Shine = Shiny(Box, 8)

		local Text_Label = Create("TextLabel", {
			Parent = Holder,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 16, 0, 0),
			Size = UDim2.new(1, -16, 1, 0),
			FontFace = Fonts.Main,
			Text = Options.Text or Options.Name or "toggle",
			TextColor3 = Theme.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
		})

		local Hit = Create("TextButton", {
			Parent = Holder,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 14, 0, 0),
			Size = UDim2.new(1, -14, 1, 0),
			Text = "",
			ZIndex = 5,
		})

		local State = Default
		local function Set(Val, Fire)
			State = Val and true or false
			Tween(Box, { BackgroundColor3 = State and Theme.Toggle_On or Theme.Toggle_Off }, 0.12)
			Box_Shine.BackgroundTransparency = State and 0.55 or 0.78
			if Flag then
				Library.Flags[Flag] = State
			end
			if Fire ~= false then
				Callback(State)
			end
		end
		Set(Default, false)

		Connect(Box.MouseButton1Click, function()
			Set(not State)
		end)
		Connect(Hit.MouseButton1Click, function()
			Set(not State)
		end)

		local Api = {}
		function Api:Set(Val)
			Set(Val)
		end
		function Api:Get()
			return State
		end

		-- Inline extras: pickers sit on the same row, right-aligned
		local Inline_Count = 0
		local function Reserve_Inline_Slot(Width)
			Inline_Count += 1
			local Used = Inline_Count * (Width + 4)
			Text_Label.Size = UDim2.new(1, -16 - Used, 1, 0)
			Hit.Size = UDim2.new(1, -14 - Used, 1, 0)
			return -Used
		end

		function Api:Add_Color_Picker(Picker_Options)
			Picker_Options = Picker_Options or {}
			Picker_Options.Attach = {
				Holder = Holder,
				X = Reserve_Inline_Slot(28),
			}
			return Controls:Add_Color_Picker(Picker_Options)
		end

		Register_Option(Flag, "Toggle", Api)
		return Api
	end

	function Controls:Add_Button(Options)
		Options = Options or {}
		local Callback = Options.Callback or function() end
		local Order = Next_Order(Container)

		local Btn = Create("TextButton", {
			Parent = Content,
			BackgroundColor3 = Theme.Input_Back,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -4, 0, 22),
			FontFace = Fonts.Medium,
			Text = Options.Text or Options.Name or "button",
			TextColor3 = Theme.Text,
			TextSize = 12,
			AutoButtonColor = false,
			ClipsDescendants = true,
			LayoutOrder = Order,
			ZIndex = 5,
		})
		Stroke(Btn, Theme.Border)
		Shiny(Btn, 8)

		Connect(Btn.MouseEnter, function()
			Tween(Btn, { BackgroundColor3 = Theme.Hover }, 0.12)
		end)
		Connect(Btn.MouseLeave, function()
			Tween(Btn, { BackgroundColor3 = Theme.Input_Back }, 0.12)
		end)
		Connect(Btn.MouseButton1Click, function()
			Callback()
		end)

		local Api = {}
		function Api:Set_Text(T)
			Btn.Text = T
		end
		return Api
	end

	function Controls:Add_Sub_Button(Options)
		Options = Options or {}
		local Callback = Options.Callback or function() end
		local Order = Next_Order(Container)

		local Holder = Create("Frame", {
			Parent = Content,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 22),
			LayoutOrder = Order,
			ZIndex = 5,
		})

		local function Make_Half(Pos, Size, Text)
			local B = Create("TextButton", {
				Parent = Holder,
				BackgroundColor3 = Theme.Input_Back,
				BorderSizePixel = 0,
				Position = Pos,
				Size = Size,
				FontFace = Fonts.Medium,
				Text = Text,
				TextColor3 = Theme.Text,
				TextSize = 11,
				AutoButtonColor = false,
				ClipsDescendants = true,
				ZIndex = 6,
			})
			Stroke(B, Theme.Border)
			Shiny(B, 9)
			Connect(B.MouseEnter, function()
				Tween(B, { BackgroundColor3 = Theme.Hover }, 0.12)
			end)
			Connect(B.MouseLeave, function()
				Tween(B, { BackgroundColor3 = Theme.Input_Back }, 0.12)
			end)
			return B
		end

		local Left_Btn = Make_Half(UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -2, 1, 0), Options.Text or Options.Left_Text or "sub")
		local Right_Btn = Make_Half(UDim2.new(0.5, 2, 0, 0), UDim2.new(0.5, -2, 1, 0), Options.Sub_Text or Options.Right_Text or "button")

		Connect(Left_Btn.MouseButton1Click, function()
			if Options.Left_Callback then
				Options.Left_Callback()
			else
				Callback("left")
			end
		end)
		Connect(Right_Btn.MouseButton1Click, function()
			if Options.Right_Callback then
				Options.Right_Callback()
			else
				Callback("right")
			end
		end)

		return { Left = Left_Btn, Right = Right_Btn }
	end

	function Controls:Add_Slider(Options)
		Options = Options or {}
		local Min = Options.Min or 0
		local Max = Options.Max or 100
		local Default = Clamp(Options.Default or Min, Min, Max)
		local Decimals = Options.Decimals or 0
		local Suffix = Options.Suffix or ""
		local Flag = Options.Flag
		local Callback = Options.Callback or function() end
		local Order = Next_Order(Container)

		if Flag then
			Library.Flags[Flag] = Default
		end

		local Holder = Create("Frame", {
			Parent = Content,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 36),
			LayoutOrder = Order,
			ZIndex = 5,
		})

		Create("TextLabel", {
			Parent = Holder,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -48, 0, 14),
			FontFace = Fonts.Main,
			Text = Options.Text or Options.Name or "slider",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
		})

		local Value_Label = Create("TextLabel", {
			Parent = Holder,
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -48, 0, 0),
			Size = UDim2.new(0, 48, 0, 14),
			FontFace = Fonts.Code,
			Text = tostring(Default) .. Suffix,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 6,
		})

		-- Clean track (same state language as text fields)
		local Bar = Create("Frame", {
			Parent = Holder,
			BackgroundColor3 = Theme.Input_Back,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 18),
			Size = UDim2.new(1, 0, 0, 10),
			ClipsDescendants = true,
			ZIndex = 6,
		})
		local Bar_Stroke = Stroke(Bar, Theme.Border)

		local Range = math.max(Max - Min, 1e-9)

		local Fill = Create("Frame", {
			Parent = Bar,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Size = UDim2.new((Default - Min) / Range, 0, 1, 0),
			ZIndex = 7,
		})
		Create("UIGradient", {
			Parent = Fill,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.Accent),
				ColorSequenceKeypoint.new(0.5, Theme.Accent_Mid),
				ColorSequenceKeypoint.new(1, Theme.Accent_End),
			}),
		})

		local Hit = Create("TextButton", {
			Parent = Bar,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			ZIndex = 9,
		})

		local Value = Default
		local Sliding = false
		local Hovered = false

		local function Apply_Bar_Style()
			local Bg, Stroke_Col
			if Sliding then
				Bg = Theme.Hover
				Stroke_Col = Theme.Accent_Mid
			elseif Hovered then
				Bg = Color3.fromRGB(28, 28, 38)
				Stroke_Col = Theme.Border_Light
			else
				Bg = Theme.Input_Back
				Stroke_Col = Theme.Border
			end
			Tween(Bar, { BackgroundColor3 = Bg }, 0.16)
			Tween(Bar_Stroke, { Color = Stroke_Col }, 0.16)
		end
		Apply_Bar_Style()

		local function Set(Val, Fire, Instant)
			Value = Round(Clamp(Val, Min, Max), Decimals)
			local Pct = Clamp((Value - Min) / Range, 0, 1)
			if Instant then
				Fill.Size = UDim2.new(Pct, 0, 1, 0)
			else
				Tween(Fill, { Size = UDim2.new(Pct, 0, 1, 0) }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
			Value_Label.Text = tostring(Value) .. Suffix
			if Flag then
				Library.Flags[Flag] = Value
			end
			if Fire ~= false then
				Callback(Value)
			end
		end
		Set(Default, false, true)

		local function From_X(X)
			local Rel = Clamp((X - Bar.AbsolutePosition.X) / math.max(Bar.AbsoluteSize.X, 1), 0, 1)
			Set(Min + (Max - Min) * Rel, true, false)
		end

		Connect(Hit.MouseEnter, function()
			Hovered = true
			if not Sliding then
				Apply_Bar_Style()
			end
		end)
		Connect(Hit.MouseLeave, function()
			Hovered = false
			if not Sliding then
				Apply_Bar_Style()
			end
		end)

		Connect(Hit.InputBegan, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				Sliding = true
				Apply_Bar_Style()
				From_X(Input.Position.X)
			end
		end)
		Connect(UserInputService.InputEnded, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 and Sliding then
				Sliding = false
				Apply_Bar_Style()
			end
		end)
		Connect(UserInputService.InputChanged, function(Input)
			if Sliding and Input.UserInputType == Enum.UserInputType.MouseMovement then
				From_X(Input.Position.X)
			end
		end)

		local Api = {}
		function Api:Set(Val)
			Set(Val, true, false)
		end
		function Api:Get()
			return Value
		end
		Register_Option(Flag, "Slider", Api)
		return Api
	end

	function Controls:Add_Input(Options)
		Options = Options or {}
		local Flag = Options.Flag
		local Default = Options.Default or ""
		local Callback = Options.Callback or function() end
		local Order = Next_Order(Container)

		if Flag then
			Library.Flags[Flag] = Default
		end

		local Holder = Create("Frame", {
			Parent = Content,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 38),
			LayoutOrder = Order,
			ZIndex = 5,
		})

		Create("TextLabel", {
			Parent = Holder,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14),
			FontFace = Fonts.Main,
			Text = Options.Text or Options.Name or "input",
			TextColor3 = Theme.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
		})

		local Field = Create("Frame", {
			Parent = Holder,
			BackgroundColor3 = Theme.Input_Back,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 16),
			Size = UDim2.new(1, 0, 0, 20),
			ClipsDescendants = true,
			ZIndex = 6,
		})
		local Field_Stroke = Stroke(Field, Theme.Border)

		local Pad_L = 8
		local Display = Create("TextLabel", {
			Parent = Field,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, Pad_L, 0, 0),
			Size = UDim2.new(1, -(Pad_L * 2), 1, 0),
			FontFace = Fonts.Main,
			Text = Default,
			TextColor3 = Theme.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 7,
		})

		local Placeholder = Create("TextLabel", {
			Parent = Field,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, Pad_L, 0, 0),
			Size = UDim2.new(1, -(Pad_L * 2), 1, 0),
			FontFace = Fonts.Main,
			Text = Options.Placeholder or "...",
			TextColor3 = Theme.Text_Dark,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = Default == "",
			ZIndex = 7,
		})

		-- Solid gradient caret (no blink) — sits after newest text, tweens on move
		local Caret = Create("Frame", {
			Parent = Field,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, Pad_L, 0.5, 0),
			Size = UDim2.new(0, 2, 0, 12),
			Visible = false,
			ZIndex = 9,
		})
		local Caret_Grad = Create("UIGradient", {
			Parent = Caret,
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.Accent),
				ColorSequenceKeypoint.new(0.5, Theme.Accent_Mid),
				ColorSequenceKeypoint.new(1, Theme.Accent_End),
			}),
		})

		-- Invisible TextBox for input; hides the native throbbing caret
		local Box = Create("TextBox", {
			Parent = Field,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, Pad_L, 0, 0),
			Size = UDim2.new(1, -(Pad_L * 2), 1, 0),
			FontFace = Fonts.Main,
			Text = Default,
			PlaceholderText = "",
			TextColor3 = Theme.Input_Back,
			TextTransparency = 1,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			ClipsDescendants = true,
			ZIndex = 10,
		})

		local Focused = false
		local Hovered = false
		local Caret_Scroll = 0

		local function Apply_Field_Style()
			local Bg, Stroke_Col, Text_Col
			if Focused then
				Bg = Theme.Hover
				Stroke_Col = Theme.Accent_Mid
				Text_Col = Color3.fromRGB(255, 255, 255)
			elseif Hovered then
				Bg = Color3.fromRGB(28, 28, 38)
				Stroke_Col = Theme.Border_Light
				Text_Col = Theme.Text
			else
				Bg = Theme.Input_Back
				Stroke_Col = Theme.Border
				Text_Col = Theme.Text
			end
			Tween(Field, { BackgroundColor3 = Bg }, 0.16)
			Tween(Field_Stroke, { Color = Stroke_Col }, 0.16)
			Tween(Display, { TextColor3 = Text_Col }, 0.16)
		end

		local function Measure_Before_Caret()
			local Text = Box.Text or ""
			local Cursor = Box.CursorPosition
			if Type_Of(Cursor) ~= "number" or Cursor < 1 then
				Cursor = #Text + 1
			end
			local Before = string.sub(Text, 1, math.clamp(Cursor - 1, 0, #Text))
			local Bounds = TextService:GetTextSize(
				Before,
				12,
				Enum.Font.BuilderSansExtraBold,
				Vector2.new(10000, 40)
			)
			return Pad_L + Bounds.X
		end

		local function Sync_Display(Animate_Caret)
			Display.Text = Box.Text
			Placeholder.Visible = (Box.Text == "" and not Focused)
			local X = Measure_Before_Caret()
			local Max_X = math.max(Pad_L, Field.AbsoluteSize.X - Pad_L - 2)
			X = math.clamp(X, Pad_L, Max_X)
			if Animate_Caret then
				Tween(Caret, { Position = UDim2.new(0, X, 0.5, 0) }, 0.12, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			else
				Caret.Position = UDim2.new(0, X, 0.5, 0)
			end
		end

		local function Set_Focused(On)
			Focused = On and true or false
			Caret.Visible = Focused
			Apply_Field_Style()
			Sync_Display(true)
			if Focused then
				Tween(Caret, { Size = UDim2.new(0, 2, 0, 12), BackgroundTransparency = 0 }, 0.12)
			else
				Tween(Caret, { Size = UDim2.new(0, 2, 0, 8), BackgroundTransparency = 0.35 }, 0.12)
			end
		end

		Apply_Field_Style()
		Sync_Display(false)

		Connect(Field.MouseEnter, function()
			Hovered = true
			if not Focused then
				Apply_Field_Style()
			end
		end)
		Connect(Field.MouseLeave, function()
			Hovered = false
			if not Focused then
				Apply_Field_Style()
			end
		end)
		Connect(Box.MouseEnter, function()
			Hovered = true
			if not Focused then
				Apply_Field_Style()
			end
		end)
		Connect(Box.MouseLeave, function()
			Hovered = false
			if not Focused then
				Apply_Field_Style()
			end
		end)

		Connect(Box.Focused, function()
			Set_Focused(true)
		end)
		Connect(Box.FocusLost, function()
			Set_Focused(false)
			if Flag then
				Library.Flags[Flag] = Box.Text
			end
			Callback(Box.Text)
		end)

		Connect(Box:GetPropertyChangedSignal("Text"), function()
			if Flag then
				Library.Flags[Flag] = Box.Text
			end
			Sync_Display(true)
		end)

		Connect(Box:GetPropertyChangedSignal("CursorPosition"), function()
			if Focused then
				Sync_Display(true)
			end
		end)

		Connect(RunService.RenderStepped, function(Dt)
			if not Focused or not Caret.Visible then
				return
			end
			-- Animate gradient along the caret (solid bar, no throb/blink)
			Caret_Scroll = (Caret_Scroll + Dt * 1.8) % 1
			local T = Caret_Scroll
			local function Mix(A, B, Alpha)
				return Color3.new(
					A.R + (B.R - A.R) * Alpha,
					A.G + (B.G - A.G) * Alpha,
					A.B + (B.B - A.B) * Alpha
				)
			end
			local A1 = math.sin(T * math.pi * 2) * 0.5 + 0.5
			Caret_Grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Mix(Theme.Accent, Theme.Accent_Mid, A1)),
				ColorSequenceKeypoint.new(0.5, Mix(Theme.Accent_Mid, Theme.Accent_End, 1 - A1)),
				ColorSequenceKeypoint.new(1, Mix(Theme.Accent_End, Theme.Accent, A1)),
			})
		end)

		local Api = {}
		function Api:Set(T)
			Box.Text = tostring(T or "")
			if Flag then
				Library.Flags[Flag] = Box.Text
			end
			Sync_Display(true)
			Callback(Box.Text)
		end
		function Api:Get()
			return Box.Text
		end
		Register_Option(Flag, "Input", Api)
		return Api
	end

	function Controls:Add_Dropdown(Options)
		Options = Options or {}
		local Values = Options.Values or { "one", "two", "three" }
		local Default = Options.Default or Values[1]
		local Flag = Options.Flag
		local Callback = Options.Callback or function() end
		local Multi = Options.Multi or false
		local Order = Next_Order(Container)

		if Flag then
			Library.Flags[Flag] = Multi and (Type_Of(Default) == "table" and Default or {}) or Default
		end

		local Holder = Create("Frame", {
			Parent = Content,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 38),
			LayoutOrder = Order,
			ZIndex = 5,
		})

		Create("TextLabel", {
			Parent = Holder,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 14),
			FontFace = Fonts.Main,
			Text = Options.Text or Options.Name or (Multi and "multi dropdown" or "dropdown"),
			TextColor3 = Theme.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
		})

		local Selected = Multi and {} or Default
		if Multi and Type_Of(Default) == "table" then
			for _, V in ipairs(Default) do
				Selected[V] = true
			end
		end

		local function Selected_Text()
			if Multi then
				local T = {}
				for _, V in ipairs(Values) do
					if Selected[V] then
						table.insert(T, V)
					end
				end
				return #T > 0 and table.concat(T, ", ") or "none"
			end
			return tostring(Selected)
		end

		local Main_Btn = Create("TextButton", {
			Parent = Holder,
			BackgroundColor3 = Theme.Input_Back,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 16),
			Size = UDim2.new(1, 0, 0, 20),
			FontFace = Fonts.Main,
			Text = "  " .. Selected_Text(),
			TextColor3 = Theme.Text,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			ClipsDescendants = true,
			ZIndex = 6,
		})
		Stroke(Main_Btn, Theme.Border)

		-- Pointing finger: up when closed, down when open
		local Chevron = Make_Icon(Main_Btn, Icons.pointer, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0, 12, 0, 12),
			Color = Theme.Text_Dim,
			ZIndex = 8,
		})
		Chevron.Rotation = 0 -- pointing up (closed)

		local function Set_Chevron(Is_Open)
			Tween(Chevron, {
				Rotation = Is_Open and 180 or 0,
				ImageColor3 = Is_Open and Theme.Accent or Theme.Text_Dim,
			}, 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		end

		-- Dropdown list stacks under the button (animated height)
		local Drop_Wrap = Create("Frame", {
			Parent = Holder,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 38),
			Size = UDim2.new(1, 0, 0, 0),
			ClipsDescendants = true,
			Visible = false,
			ZIndex = 40,
		})

		-- Anchored to the clip's bottom edge: revealed/hidden by the clip's
		-- height alone, so the panel + text never desync (no jitter/ghosting).
		local Drop = Create("Frame", {
			Parent = Drop_Wrap,
			BackgroundColor3 = Theme.Panel,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 0),
			ZIndex = 41,
		})
		Stroke(Drop, Theme.Border)

		local Drop_List = Create("ScrollingFrame", {
			Parent = Drop,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 2,
			ScrollBarImageColor3 = Theme.Accent_Mid,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			BorderSizePixel = 0,
			ZIndex = 42,
		})
		Create("UIListLayout", {
			Parent = Drop_List,
			SortOrder = Enum.SortOrder.LayoutOrder,
		})

		local Open = false
		local Item_H = 20
		local Max_Visible = 5
		local Anim_Token = 0

		local function Target_Height()
			return math.min(#Values, Max_Visible) * Item_H
		end

		local function Close()
			if not Open then
				return
			end
			Open = false
			Anim_Token += 1

			-- Hide the list instantly (no slide-up), then collapse the holder.
			Set_Chevron(false)
			Drop_Wrap.Visible = false
			Drop_Wrap.Size = UDim2.new(1, 0, 0, 0)
			Tween(Holder, { Size = UDim2.new(1, -4, 0, 38) }, 0.16)

			if Library.Open_Dropdown == Close then
				Library.Open_Dropdown = nil
			end
		end

		local function Refresh_Items()
			for _, C in ipairs(Drop_List:GetChildren()) do
				if C:IsA("TextButton") then
					C:Destroy()
				end
			end
			for i, Val in ipairs(Values) do
				local Is_On = Multi and Selected[Val] or Selected == Val
				local Item = Create("TextButton", {
					Parent = Drop_List,
					BackgroundColor3 = Is_On and Theme.Hover or Theme.Panel,
					BackgroundTransparency = Is_On and 0 or 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 0, Item_H),
					FontFace = Fonts.Main,
					Text = "  " .. Val,
					TextColor3 = Is_On and Theme.Accent or Theme.Text,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					AutoButtonColor = false,
					ClipsDescendants = true,
					LayoutOrder = i,
					ZIndex = 43,
				})
				Connect(Item.MouseEnter, function()
					if not (Multi and Selected[Val] or Selected == Val) then
						Item.BackgroundTransparency = 0
						Item.BackgroundColor3 = Theme.Hover
					end
				end)
				Connect(Item.MouseLeave, function()
					local On = Multi and Selected[Val] or Selected == Val
					Item.BackgroundTransparency = On and 0 or 1
					Item.TextColor3 = On and Theme.Accent or Theme.Text
				end)
				Connect(Item.MouseButton1Click, function()
					if Multi then
						Selected[Val] = not Selected[Val]
						local Out = {}
						for _, V in ipairs(Values) do
							if Selected[V] then
								table.insert(Out, V)
							end
						end
						if Flag then
							Library.Flags[Flag] = Out
						end
						Main_Btn.Text = "  " .. Selected_Text()
						Refresh_Items()
						Callback(Out)
					else
						Selected = Val
						if Flag then
							Library.Flags[Flag] = Val
						end
						Main_Btn.Text = "  " .. Selected_Text()
						Close()
						Callback(Val)
					end
				end)
			end
		end

		local function Open_Drop()
			if Library.Open_Dropdown and Library.Open_Dropdown ~= Close then
				Library.Open_Dropdown()
			end
			Open = true
			Anim_Token += 1
			Library.Open_Dropdown = Close
			Refresh_Items()
			local H = Target_Height()

			Drop_Wrap.Visible = true
			Drop_Wrap.Size = UDim2.new(1, 0, 0, 0)
			-- Fixed full-height panel anchored to the clip bottom; reveal by
			-- growing the clip only (single tween = perfectly synced).
			Drop.Size = UDim2.new(1, 0, 0, H)

			Set_Chevron(true)
			Tween(Drop_Wrap, { Size = UDim2.new(1, 0, 0, H) }, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			Tween(Holder, { Size = UDim2.new(1, -4, 0, 38 + H + 4) }, 0.22)
		end

		Connect(Main_Btn.MouseButton1Click, function()
			if Open then
				Close()
			else
				Open_Drop()
			end
		end)

		local Api = {}
		function Api:Set(Val)
			if Multi then
				Selected = {}
				for _, V in ipairs(Val or {}) do
					Selected[V] = true
				end
			else
				Selected = Val
			end
			Main_Btn.Text = "  " .. Selected_Text()
			if Flag then
				if Multi then
					local Out = {}
					for _, V in ipairs(Values) do
						if Selected[V] then
							table.insert(Out, V)
						end
					end
					Library.Flags[Flag] = Out
					Callback(Out)
				else
					Library.Flags[Flag] = Selected
					Callback(Selected)
				end
			end
			if Open then
				Refresh_Items()
			end
		end
		function Api:Get()
			if Multi then
				local Out = {}
				for _, V in ipairs(Values) do
					if Selected[V] then
						table.insert(Out, V)
					end
				end
				return Out
			end
			return Selected
		end
		function Api:Set_Values(New_Values)
			Values = New_Values or {}
			if Multi then
				local Keep = {}
				for _, V in ipairs(Values) do
					if Selected[V] then
						Keep[V] = true
					end
				end
				Selected = Keep
			else
				local Found = false
				for _, V in ipairs(Values) do
					if V == Selected then
						Found = true
						break
					end
				end
				if not Found then
					Selected = Values[1]
				end
			end
			Main_Btn.Text = "  " .. Selected_Text()
			if Flag then
				Library.Flags[Flag] = Api:Get()
			end
			if Open then
				Refresh_Items()
			end
		end
		function Api:Close()
			Close()
		end
		Register_Option(Flag, Multi and "MultiDropdown" or "Dropdown", Api)
		return Api
	end

	function Controls:Add_Multi_Dropdown(Options)
		Options = Options or {}
		Options.Multi = true
		return Controls:Add_Dropdown(Options)
	end

	function Controls:Add_Color_Picker(Options)
		Options = Options or {}
		local Default = Options.Default or Theme.Accent
		local Flag = Options.Flag
		local Callback = Options.Callback or function() end
		local Order = Next_Order(Container)
		-- Attach = { Holder = <existing row frame>, X = <right-aligned offset> }
		local Attach = Options.Attach

		if Flag then
			Library.Flags[Flag] = Default
		end

		local Holder
		if Attach and Attach.Holder then
			Holder = Attach.Holder
		else
			Holder = Create("Frame", {
				Parent = Content,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -4, 0, 20),
				LayoutOrder = Order,
				ZIndex = 5,
			})

			Create("TextLabel", {
				Parent = Holder,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -34, 1, 0),
				FontFace = Fonts.Main,
				Text = Options.Text or Options.Name or "color picker",
				TextColor3 = Theme.Text,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6,
			})
		end

		-- Compact square-ish swatch (closer in, not wide)
		local Swatch = Create("TextButton", {
			Parent = Holder,
			BackgroundColor3 = Default,
			BorderSizePixel = 0,
			Position = UDim2.new(1, (Attach and Attach.X) or -28, 0.5, -7),
			Size = UDim2.new(0, 28, 0, 14),
			Text = "",
			AutoButtonColor = false,
			ClipsDescendants = true,
			ZIndex = 12,
		})
		Stroke(Swatch, Theme.Border_Light)
		Shiny(Swatch, 9)

		local Color = Default
		local Picker_Open = false
		local H, S, V = Color:ToHSV()

		-- Full-screen modal input sink: no controls behind the picker can be clicked.
		local Picker_Blocker = Create("TextButton", {
			Parent = Screen_Gui,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, 0),
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			AutoButtonColor = false,
			Active = true,
			Modal = true,
			Visible = false,
			ZIndex = 219,
		})

		local Picker = Create("Frame", {
			Parent = Screen_Gui,
			BackgroundColor3 = Theme.Window,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 220, 0, 148),
			Visible = false,
			Active = true,
			ZIndex = 220,
			ClipsDescendants = true,
		})
		Stroke(Picker, Theme.Border)

		-- Copy / paste live inside the picker, vertically left of the color area.
		local function Vertical_Btn(Text, X)
			local B = Create("TextButton", {
				Parent = Picker,
				BackgroundColor3 = Theme.Input_Back,
				BorderSizePixel = 0,
				Position = UDim2.new(0, X, 0, 12),
				Size = UDim2.new(0, 16, 0, 94),
				FontFace = Fonts.Main,
				Text = Text,
				TextColor3 = Theme.Text_Dim,
				TextSize = 8,
				TextWrapped = true,
				AutoButtonColor = false,
				ZIndex = 221,
			})
			Stroke(B, Theme.Border)
			Connect(B.MouseEnter, function()
				B.TextColor3 = Theme.Accent
				Tween(B, { BackgroundColor3 = Theme.Hover }, 0.1)
			end)
			Connect(B.MouseLeave, function()
				B.TextColor3 = Theme.Text_Dim
				Tween(B, { BackgroundColor3 = Theme.Input_Back }, 0.1)
			end)
			return B
		end

		local Copy_Btn = Vertical_Btn("c\no\np\ny", 10)
		local Paste_Btn = Vertical_Btn("p\na\ns\nt\ne", 30)

		local Reset_Btn = Create("TextButton", {
			Parent = Picker,
			BackgroundColor3 = Theme.Input_Back,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 10, 0, 116),
			Size = UDim2.new(0, 36, 0, 20),
			FontFace = Fonts.Main,
			Text = "reset",
			TextColor3 = Theme.Text_Dim,
			TextSize = 9,
			AutoButtonColor = false,
			ZIndex = 221,
		})
		Stroke(Reset_Btn, Theme.Border)
		Connect(Reset_Btn.MouseEnter, function()
			Reset_Btn.TextColor3 = Theme.Accent
			Tween(Reset_Btn, { BackgroundColor3 = Theme.Hover }, 0.1)
		end)
		Connect(Reset_Btn.MouseLeave, function()
			Reset_Btn.TextColor3 = Theme.Text_Dim
			Tween(Reset_Btn, { BackgroundColor3 = Theme.Input_Back }, 0.1)
		end)

		-- Saturation / Value box: hue background + white(left) + black(bottom) gradients
		local Sat_Val = Create("Frame", {
			Parent = Picker,
			BackgroundColor3 = Color3.fromHSV(H, 1, 1),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 52, 0, 12),
			Size = UDim2.new(0, 132, 0, 94),
			Active = true,
			ZIndex = 221,
		})
		Stroke(Sat_Val, Theme.Border)

		local White_Overlay = Create("Frame", {
			Parent = Sat_Val,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 222,
		})
		Create("UIGradient", {
			Parent = White_Overlay,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})

		local Black_Overlay = Create("Frame", {
			Parent = Sat_Val,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			ZIndex = 223,
		})
		Create("UIGradient", {
			Parent = Black_Overlay,
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
		})

		-- Small square cursor showing current color position
		local SV_Cursor = Create("Frame", {
			Parent = Sat_Val,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(0, 6, 0, 6),
			ZIndex = 224,
		})
		Stroke(SV_Cursor, Color3.fromRGB(0, 0, 0), 1)

		-- Hue bar: full spectrum, vertical
		local Hue_Bar = Create("Frame", {
			Parent = Picker,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 192, 0, 12),
			Size = UDim2.new(0, 20, 0, 94),
			Active = true,
			ZIndex = 221,
		})
		Stroke(Hue_Bar, Theme.Border)
		Create("UIGradient", {
			Parent = Hue_Bar,
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.000, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.500, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1.000, Color3.fromRGB(255, 0, 0)),
			}),
		})

		local Hue_Cursor = Create("Frame", {
			Parent = Hue_Bar,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, 0),
			Size = UDim2.new(1, 4, 0, 3),
			ZIndex = 224,
		})
		Stroke(Hue_Cursor, Color3.fromRGB(0, 0, 0), 1)

		local Hex_Box = Create("TextBox", {
			Parent = Picker,
			BackgroundColor3 = Theme.Input_Back,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 52, 0, 116),
			Size = UDim2.new(0, 160, 0, 20),
			FontFace = Fonts.Code,
			Text = "",
			TextColor3 = Theme.Text,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			ClearTextOnFocus = false,
			ZIndex = 221,
		})
		Stroke(Hex_Box, Theme.Border)

		local function Apply(Fire)
			Color = Color3.fromHSV(H, S, V)
			Swatch.BackgroundColor3 = Color
			Sat_Val.BackgroundColor3 = Color3.fromHSV(H, 1, 1)
			SV_Cursor.Position = UDim2.new(S, 0, 1 - V, 0)
			Hue_Cursor.Position = UDim2.new(0.5, 0, H, 0)
			local R = math.floor(Color.R * 255 + 0.5)
			local G = math.floor(Color.G * 255 + 0.5)
			local B = math.floor(Color.B * 255 + 0.5)
			Hex_Box.Text = string.format("#%02X%02X%02X", R, G, B)
			if Flag then
				Library.Flags[Flag] = Color
			end
			if Fire ~= false then
				Callback(Color)
			end
		end
		Apply(false)

		local function Color_To_Hex(C)
			return string.format(
				"#%02X%02X%02X",
				math.floor(C.R * 255 + 0.5),
				math.floor(C.G * 255 + 0.5),
				math.floor(C.B * 255 + 0.5)
			)
		end

		local function Hex_To_Color(Hex)
			Hex = tostring(Hex or ""):gsub("#", "")
			if #Hex ~= 6 then
				return nil
			end
			local R = tonumber(Hex:sub(1, 2), 16)
			local G = tonumber(Hex:sub(3, 4), 16)
			local B = tonumber(Hex:sub(5, 6), 16)
			if R and G and B then
				return Color3.fromRGB(R, G, B)
			end
			return nil
		end

		Connect(Copy_Btn.MouseButton1Click, function()
			local Hex = Color_To_Hex(Color)
			Library.Copied_Color = Color
			Library.Copied_Hex = Hex
			if Is_Function(setclipboard) then
				Safe_Call(setclipboard, Hex)
			elseif Is_Function(toclipboard) then
				Safe_Call(toclipboard, Hex)
			end
			Library:Notify("copied " .. Hex)
		end)

		Connect(Paste_Btn.MouseButton1Click, function()
			local Pasted = Library.Copied_Color
			local Clip = nil
			if Is_Function(getclipboard) then
				local Ok_Clip, Value = Safe_Call(getclipboard)
				if Ok_Clip then
					Clip = Value
				end
			end
			if type(Clip) == "string" then
				local Parsed = Hex_To_Color(Clip)
				if Parsed then
					Pasted = Parsed
				end
			end
			if Pasted then
				H, S, V = Pasted:ToHSV()
				Apply()
				Library:Notify("pasted " .. Color_To_Hex(Pasted))
			else
				Library:Notify("nothing to paste")
			end
		end)

		Connect(Reset_Btn.MouseButton1Click, function()
			H, S, V = 0, 0, 1
			Apply()
			Library:Notify("color reset to white")
		end)

		local function Update_SV(Pos)
			local Rel = Pos - Sat_Val.AbsolutePosition
			S = Clamp(Rel.X / math.max(Sat_Val.AbsoluteSize.X, 1), 0, 1)
			V = 1 - Clamp(Rel.Y / math.max(Sat_Val.AbsoluteSize.Y, 1), 0, 1)
			Apply()
		end

		local function Update_Hue(Pos)
			local Rel = Pos - Hue_Bar.AbsolutePosition
			H = Clamp(Rel.Y / math.max(Hue_Bar.AbsoluteSize.Y, 1), 0, 1)
			Apply()
		end

		local function In_Bounds(Frame, Pos)
			local P, Sz = Frame.AbsolutePosition, Frame.AbsoluteSize
			return Pos.X >= P.X and Pos.X <= P.X + Sz.X and Pos.Y >= P.Y and Pos.Y <= P.Y + Sz.Y
		end

		local Drag_SV, Drag_Hue = false, false
		Connect(UserInputService.InputBegan, function(Input)
			if Input.UserInputType ~= Enum.UserInputType.MouseButton1 or not Picker.Visible then
				return
			end
			local Pos = Vector2.new(Input.Position.X, Input.Position.Y)
			if In_Bounds(Sat_Val, Pos) then
				Drag_SV = true
				Update_SV(Pos)
			elseif In_Bounds(Hue_Bar, Pos) then
				Drag_Hue = true
				Update_Hue(Pos)
			end
		end)
		Connect(UserInputService.InputEnded, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				Drag_SV, Drag_Hue = false, false
			end
		end)
		Connect(UserInputService.InputChanged, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement then
				local Pos = Vector2.new(Input.Position.X, Input.Position.Y)
				if Drag_SV then
					Update_SV(Pos)
				elseif Drag_Hue then
					Update_Hue(Pos)
				end
			end
		end)

		Connect(Hex_Box.FocusLost, function()
			local Hex = Hex_Box.Text:gsub("#", "")
			if #Hex == 6 then
				local R = tonumber(Hex:sub(1, 2), 16)
				local G = tonumber(Hex:sub(3, 4), 16)
				local B = tonumber(Hex:sub(5, 6), 16)
				if R and G and B then
					H, S, V = Color3.fromRGB(R, G, B):ToHSV()
					Apply()
				end
			end
		end)

		local Picker_Token = 0
		local function Close_Picker()
			if not Picker_Open then
				return
			end
			Picker_Open = false
			Picker_Token += 1
			local Token = Picker_Token
			Drag_SV, Drag_Hue = false, false
			Tween(Picker, { Size = UDim2.new(0, 220, 0, 0) }, 0.15)
			task.delay(0.15, function()
				if Token == Picker_Token and not Picker_Open then
					Picker.Visible = false
					Picker_Blocker.Visible = false
				end
			end)
			if Library.Open_Color_Picker == Close_Picker then
				Library.Open_Color_Picker = nil
			end
		end

		local function Open_Picker()
			if Library.Open_Color_Picker and Library.Open_Color_Picker ~= Close_Picker then
				Library.Open_Color_Picker()
			end
			Picker_Open = true
			Picker_Token += 1
			Library.Open_Color_Picker = Close_Picker

			local Cam = Get_Camera()
			local Viewport = Cam and Cam.ViewportSize or Vector2.new(1920, 1080)
			local X = Clamp(Swatch.AbsolutePosition.X - 140, 4, Viewport.X - 224)
			local Y = Clamp(Swatch.AbsolutePosition.Y + 20, 4, Viewport.Y - 152)
			Picker.Position = UDim2.new(0, X, 0, Y)
			Picker_Blocker.Visible = true
			Picker.Visible = true
			Picker.Size = UDim2.new(0, 220, 0, 0)
			Tween(Picker, { Size = UDim2.new(0, 220, 0, 148) }, 0.2)
		end

		Connect(Picker_Blocker.MouseButton1Click, Close_Picker)
		Connect(Swatch.MouseButton1Click, function()
			if Picker_Open then
				Close_Picker()
			else
				Open_Picker()
			end
		end)

		local Api = {}
		function Api:Set(C)
			if Type_Of(C) == "string" then
				local Hex = C:gsub("#", "")
				if #Hex == 6 then
					C = Color3.fromRGB(
						tonumber(Hex:sub(1, 2), 16) or 0,
						tonumber(Hex:sub(3, 4), 16) or 0,
						tonumber(Hex:sub(5, 6), 16) or 0
					)
				else
					return
				end
			elseif Type_Of(C) == "table" and C.R then
				if C.R <= 1 and C.G <= 1 and C.B <= 1 then
					C = Color3.new(C.R, C.G, C.B)
				else
					C = Color3.fromRGB(C.R, C.G, C.B)
				end
			end
			if Type_Of(C) ~= "Color3" then
				return
			end
			H, S, V = C:ToHSV()
			Apply(false)
			Callback(Color)
		end
		function Api:Get()
			return Color
		end
		function Api:Close()
			Close_Picker()
		end
		Register_Option(Flag, "Color", Api)
		return Api
	end

	function Controls:Add_Key_Picker(Options)
		Options = Options or {}
		local Default = Options.Default or Enum.KeyCode.Unknown
		local Flag = Options.Flag
		local Mode = Options.Mode or "Toggle"
		local Callback = Options.Callback or function() end
		local Order = Next_Order(Container)

		local function Key_Name(Key)
			return Bind_Name(Key)
		end

		if Flag then
			Library.Flags[Flag] = false
		end

		local Holder = Create("Frame", {
			Parent = Content,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -4, 0, 18),
			LayoutOrder = Order,
			ZIndex = 5,
		})

		local Bind_Label = Options.Text or Options.Name or "key picker"

		Create("TextLabel", {
			Parent = Holder,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -28, 1, 0),
			FontFace = Fonts.Main,
			Text = Bind_Label,
			TextColor3 = Theme.Text,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 6,
		})

		-- Keyboard icon only; hover tooltip shows the bind
		local Key_Btn = Create("TextButton", {
			Parent = Holder,
			BackgroundColor3 = Theme.Input_Back,
			BorderSizePixel = 0,
			Position = UDim2.new(1, -20, 0.5, -9),
			Size = UDim2.new(0, 20, 0, 18),
			Text = "",
			AutoButtonColor = false,
			ClipsDescendants = true,
			ZIndex = 6,
		})
		Stroke(Key_Btn, Theme.Border)
		Shiny(Key_Btn, 9)

		Make_Icon(Key_Btn, Icons.keyboard, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = UDim2.new(0, 12, 0, 12),
			Color = Color3.fromRGB(255, 255, 255),
			ZIndex = 8,
		})

		local Tip = Create("Frame", {
			Parent = Screen_Gui,
			BackgroundColor3 = Theme.Window,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 0, 0, 22),
			Visible = false,
			ZIndex = 250,
			AutomaticSize = Enum.AutomaticSize.X,
		})
		Stroke(Tip, Theme.Border)
		local Tip_Label = Create("TextLabel", {
			Parent = Tip,
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			FontFace = Fonts.Main,
			Text = "",
			TextColor3 = Theme.Text,
			TextSize = 11,
			ZIndex = 251,
		})
		Create("UIPadding", {
			Parent = Tip,
			PaddingRight = UDim.new(0, 8),
		})

		local Current_Key = Parse_Bind(Default)
		local Active = false
		local Picking = false
		local Pick_Ignore_Until = 0

		local function Tip_Text()
			return string.format("%s  ·  [%s]  ·  %s", Bind_Label, Key_Name(Current_Key), Mode:lower())
		end

		local function Show_Tip()
			Tip_Label.Text = Tip_Text()
			Tip.Visible = true
			local Pos = Get_Mouse_Location()
			Tip.Position = UDim2.new(0, Pos.X + 14, 0, Pos.Y + 14)
		end

		Connect(Key_Btn.MouseEnter, Show_Tip)
		Connect(Key_Btn.MouseMoved, function()
			if Tip.Visible then
				local Pos = Get_Mouse_Location()
				Tip.Position = UDim2.new(0, Pos.X + 14, 0, Pos.Y + 14)
			end
		end)
		Connect(Key_Btn.MouseLeave, function()
			Tip.Visible = false
		end)

		Library.Keybinds[Bind_Label] = { Key_Name = Key_Name(Current_Key), Active = false }
		if Library.Keybind_Frame then
			Library.Keybind_Frame:Add(Bind_Label, Key_Name(Current_Key))
		end

		local function Sync_Keybind_List()
			Library.Keybinds[Bind_Label] = Library.Keybinds[Bind_Label] or {}
			Library.Keybinds[Bind_Label].Key_Name = Key_Name(Current_Key)
			if Library.Keybind_Frame then
				Library.Keybind_Frame:Add(Bind_Label, Key_Name(Current_Key))
			end
		end

		local function Set_Active(Val)
			Active = Val
			if Flag then
				Library.Flags[Flag] = Active
			end
			if Library.Keybinds[Bind_Label] then
				Library.Keybinds[Bind_Label].Active = Active
			end
			if Library.Keybind_Frame then
				Library.Keybind_Frame:Set_Active(Bind_Label, Active)
			end
			Callback(Active, Mode)
		end

		if Mode == "Always" then
			Set_Active(true)
		end

		local Popup_Open = false
		local Popup_Blocker = Create("TextButton", {
			Parent = Screen_Gui,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			Text = "",
			AutoButtonColor = false,
			Active = true,
			Visible = false,
			ZIndex = 239,
		})

		local Popup = Create("Frame", {
			Parent = Screen_Gui,
			BackgroundColor3 = Theme.Window,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 128, 0, 98),
			Visible = false,
			Active = true,
			ZIndex = 240,
			ClipsDescendants = true,
		})
		Stroke(Popup, Theme.Border)

		local Mode_Buttons = {}
		local Modes = { "Hold", "Toggle", "Always" }

		local function Refresh_Modes()
			for _, M in ipairs(Modes) do
				local B = Mode_Buttons[M]
				local On = (Mode == M)
				B.BackgroundColor3 = On and Theme.Hover or Theme.Input_Back
				B.TextColor3 = On and Theme.Accent or Theme.Text
			end
		end

		for i, M in ipairs(Modes) do
			local B = Create("TextButton", {
				Parent = Popup,
				BackgroundColor3 = Theme.Input_Back,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 8, 0, 8 + (i - 1) * 20),
				Size = UDim2.new(1, -16, 0, 18),
				FontFace = Fonts.Main,
				Text = M:lower(),
				TextColor3 = Theme.Text,
				TextSize = 11,
				AutoButtonColor = false,
				ZIndex = 243,
			})
			Stroke(B, Theme.Border)
			Mode_Buttons[M] = B
			Connect(B.MouseButton1Click, function()
				Mode = M
				Refresh_Modes()
				if Mode == "Always" then
					Set_Active(true)
				elseif Mode == "Hold" then
					Set_Active(false)
				end
				if Tip.Visible then
					Tip_Label.Text = Tip_Text()
				end
			end)
		end

		local Keybind_Area = Create("TextButton", {
			Parent = Popup,
			BackgroundColor3 = Theme.Input_Back,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 8, 0, 72),
			Size = UDim2.new(1, -16, 0, 18),
			FontFace = Fonts.Code,
			Text = "",
			TextColor3 = Theme.Accent,
			TextSize = 10,
			AutoButtonColor = false,
			ZIndex = 243,
		})
		Stroke(Keybind_Area, Theme.Border_Light)
		Make_Icon(Keybind_Area, Icons.keyboard, {
			Position = UDim2.new(0, 5, 0.5, -6),
			Size = UDim2.new(0, 12, 0, 12),
			Color = Color3.fromRGB(255, 255, 255),
			ZIndex = 244,
		})

		local function Refresh_Key_Text()
			Keybind_Area.Text = "        [" .. (Picking and "..." or Key_Name(Current_Key)) .. "]"
			if Tip.Visible then
				Tip_Label.Text = Tip_Text()
			end
		end
		Refresh_Key_Text()

		local function Close_Popup()
			if not Popup_Open then
				return
			end
			Popup_Open = false
			Picking = false
			Refresh_Key_Text()
			Popup_Blocker.Visible = false
			Tween(Popup, { Size = UDim2.new(0, 128, 0, 0) }, 0.15)
			task.delay(0.15, function()
				if not Popup_Open then
					Popup.Visible = false
				end
			end)
			if Library.Open_Dropdown == Close_Popup then
				Library.Open_Dropdown = nil
			end
		end

		local function Open_Popup()
			if Library.Open_Dropdown and Library.Open_Dropdown ~= Close_Popup then
				Library.Open_Dropdown()
			end
			Popup_Open = true
			Library.Open_Dropdown = Close_Popup
			Refresh_Modes()
			Refresh_Key_Text()
			local Cam = Get_Camera()
			local Viewport = Cam and Cam.ViewportSize or Vector2.new(1920, 1080)
			local X = Clamp(Key_Btn.AbsolutePosition.X + Key_Btn.AbsoluteSize.X - 128, 4, Viewport.X - 132)
			local Y = Clamp(Key_Btn.AbsolutePosition.Y + 20, 4, Viewport.Y - 102)
			Popup.Position = UDim2.new(0, X, 0, Y)
			Popup_Blocker.Visible = true
			Popup.Visible = true
			Popup.Size = UDim2.new(0, 128, 0, 0)
			Tween(Popup, { Size = UDim2.new(0, 128, 0, 98) }, 0.18)
		end

		Connect(Popup_Blocker.MouseButton1Click, Close_Popup)

		Connect(Key_Btn.MouseButton1Click, function()
			if Popup_Open then
				Close_Popup()
			else
				Open_Popup()
			end
		end)

		Connect(Keybind_Area.MouseButton1Click, function()
			Picking = true
			-- Ignore the click that started listening so MB1 isn't instantly bound
			Pick_Ignore_Until = tick() + 0.2
			Refresh_Key_Text()
		end)

		local function Apply_Picked(Bind)
			Current_Key = Bind
			Sync_Keybind_List()
			Picking = false
			Refresh_Key_Text()
		end

		Connect(UserInputService.InputBegan, function(Input)
			if Picking then
				if tick() < Pick_Ignore_Until then
					return
				end
				if Input.UserInputType == Enum.UserInputType.Keyboard then
					if Input.KeyCode == Enum.KeyCode.Escape then
						Apply_Picked(Enum.KeyCode.Unknown)
					elseif Is_KeyCode(Input.KeyCode) then
						Apply_Picked(Input.KeyCode)
					end
					return
				end
				if Is_Mouse_Bind(Input.UserInputType) then
					Apply_Picked(Input.UserInputType)
					return
				end
				return
			end

			-- Don't block on GameProcessed — only skip while typing in a text box
			if UserInputService:GetFocusedTextBox() then
				return
			end

			if Input_Matches_Bind(Input, Current_Key) then
				if Mode == "Hold" then
					Set_Active(true)
				elseif Mode == "Toggle" then
					Set_Active(not Active)
				elseif Mode == "Always" then
					Set_Active(true)
				end
			end
		end)

		Connect(UserInputService.InputEnded, function(Input)
			if Mode == "Hold" and Input_Matches_Bind(Input, Current_Key) then
				Set_Active(false)
			end
		end)

		local Api = {}
		function Api:Set_Key(Key)
			Current_Key = Parse_Bind(Key)
			Refresh_Key_Text()
			Sync_Keybind_List()
		end
		function Api:Set_Mode(M)
			Mode = M
			Refresh_Modes()
			if Mode == "Always" then
				Set_Active(true)
			elseif Mode == "Hold" then
				Set_Active(false)
			end
		end
		function Api:Set(Data)
			if Type_Of(Data) == "table" then
				if Data.Mode then
					Mode = Data.Mode
					Refresh_Modes()
				end
				if Data.Key then
					Current_Key = Parse_Bind(Data.Key)
					Refresh_Key_Text()
					Sync_Keybind_List()
				end
				if Mode == "Always" then
					Set_Active(true)
				elseif Type_Of(Data.Active) == "boolean" then
					Set_Active(Data.Active)
				elseif Mode == "Hold" then
					Set_Active(false)
				end
			elseif Is_Bind(Data) or Type_Of(Data) == "string" then
				Api:Set_Key(Data)
			elseif Type_Of(Data) == "boolean" then
				Set_Active(Data)
			end
		end
		function Api:Get()
			return {
				Key = Is_Bind(Current_Key) and Bind_Name(Current_Key) or "Unknown",
				Mode = Mode,
			}
		end
		function Api:Get_Active()
			return Active
		end
		function Api:Get_Key()
			return Current_Key
		end
		Register_Option(Flag, "Keybind", Api)
		return Api
	end

	return Controls
end

--------------------------------------------------------------------
-- Groupbox — clean boxed section, title in flow (no floating header)
--------------------------------------------------------------------
local function Create_Groupbox(Parent, Title_Text, Side)
	local Box = Create("Frame", {
		Parent = Parent,
		BackgroundColor3 = Theme.Groupbox,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		ZIndex = 3,
	})
	Stroke(Box, Theme.Border)
	Accent_Bar(Box, 5)

	local Content = Create("Frame", {
		Parent = Box,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 12),
		Size = UDim2.new(1, -20, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 4,
	})
	Create("UIListLayout", {
		Parent = Content,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	})
	Create("UIPadding", {
		Parent = Box,
		PaddingBottom = UDim.new(0, 12),
	})

	-- Title lives in the content list so it can't float into the tab bar
	if Title_Text and Title_Text ~= "" then
		Create("TextLabel", {
			Parent = Content,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			FontFace = Fonts.Bold,
			Text = Title_Text,
			TextColor3 = Theme.Text,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 0,
			ZIndex = 5,
		})
	end

	local Container = { _Order = 1, Side = Side }
	local Controls = Build_Controls(Container, Content)
	Controls.Frame = Box
	Controls.Content = Content

	-- Divider under every groupbox title
	Controls:Add_Divider()

	return Controls
end

--------------------------------------------------------------------
-- Tabbox — full-width text-only tab highlights
--------------------------------------------------------------------
local function Create_Tabbox(Parent)
	local Outer = Create("Frame", {
		Parent = Parent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 2,
	})

	local Tab_Bar = Create("Frame", {
		Parent = Outer,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 3,
	})
	-- Bottom hairline under sub tabs
	local Tab_Line = Create("Frame", {
		Parent = Tab_Bar,
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 3,
	})

	local Tab_Row = Create("Frame", {
		Parent = Tab_Bar,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -1),
		ZIndex = 4,
	})
	local Tab_Layout = Create("UIListLayout", {
		Parent = Tab_Row,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 0),
	})

	local Body = Create("ScrollingFrame", {
		Parent = Outer,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 28),
		Size = UDim2.new(1, 0, 1, -28),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = Theme.Accent_Mid,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 3,
	})

	local Page_Host = Create("Frame", {
		Parent = Body,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 3,
	})
	Create("UIPadding", {
		Parent = Page_Host,
		PaddingTop = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 8),
	})

	local Tabs = {}
	local Active = nil
	local Api = {}

	local function Reflow_Tabs()
		local Count = math.max(#Tabs, 1)
		for _, T in ipairs(Tabs) do
			T.Button.Size = UDim2.new(1 / Count, 0, 1, 0)
		end
	end

	function Api:Add_Tab(Name)
		local Btn = Create("TextButton", {
			Parent = Tab_Row,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, 0, 1, 0),
			FontFace = Fonts.Medium,
			Text = Name,
			TextColor3 = Theme.Text_Dim,
			TextSize = 12,
			AutoButtonColor = false,
			LayoutOrder = #Tabs + 1,
			ZIndex = 5,
		})

		local Page = Create("Frame", {
			Parent = Page_Host,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = false,
			ZIndex = 3,
		})

		local Columns = Create("Frame", {
			Parent = Page,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -2, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 3,
		})
		Create("UIListLayout", {
			Parent = Columns,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
			VerticalAlignment = Enum.VerticalAlignment.Top,
		})

		local Left_Col = Create("Frame", {
			Parent = Columns,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 1,
			ZIndex = 3,
		})
		Create("UIListLayout", {
			Parent = Left_Col,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		})

		local Right_Col = Create("Frame", {
			Parent = Columns,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -6, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			ZIndex = 3,
		})
		Create("UIListLayout", {
			Parent = Right_Col,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		})

		local Tab_Api = {
			Name = Name,
			Button = Btn,
			Page = Page,
		}

		function Tab_Api:Add_Left_Groupbox(Title)
			return Create_Groupbox(Left_Col, Title, "left")
		end

		function Tab_Api:Add_Right_Groupbox(Title)
			return Create_Groupbox(Right_Col, Title, "right")
		end

		function Tab_Api:Show()
			if Active then
				Active.Page.Visible = false
				Active.Button.TextColor3 = Theme.Text_Dim
			end
			Active = Tab_Api
			Page.Visible = true
			Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end

		Connect(Btn.MouseButton1Click, function()
			Tab_Api:Show()
		end)
		Connect(Btn.MouseEnter, function()
			if Active ~= Tab_Api then
				Btn.TextColor3 = Theme.Text
			end
		end)
		Connect(Btn.MouseLeave, function()
			if Active ~= Tab_Api then
				Btn.TextColor3 = Theme.Text_Dim
			end
		end)

		table.insert(Tabs, Tab_Api)
		Reflow_Tabs()
		if #Tabs == 1 then
			Tab_Api:Show()
		end
		return Tab_Api
	end

	return Api
end

--------------------------------------------------------------------
-- Window
--------------------------------------------------------------------
function Library:Create_Window(Options)
	Options = Options or {}
	local Title_Text = Options.Title or "eggtech"
	local Width = Options.Width or 700
	local Height = Options.Height or 550

	local Window_Frame = Create("Frame", {
		Parent = Screen_Gui,
		Name = "Window",
		BackgroundColor3 = Theme.Window,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, -Width / 2, 0.5, -Height / 2),
		Size = UDim2.new(0, Width, 0, Height),
		Active = true,
		ZIndex = 1,
	})
	Stroke(Window_Frame, Theme.Border)
	Accent_Bar(Window_Frame, 10)

	-- Fullscreen modal sink: unlocks mouse + blocks world clicks while UI is open.
	-- ZIndex 0 so window/overlays (watermark, keybinds, notifs) stay above and clickable.
	local Modal_Sink = Create("TextButton", {
		Parent = Screen_Gui,
		Name = "Modal_Sink",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		Active = true,
		Visible = false,
		ZIndex = 0,
		Selectable = false,
	})

	local Title_Bar = Create("Frame", {
		Parent = Window_Frame,
		BackgroundColor3 = Theme.Background,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 2),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 2,
	})

	-- Left: build : developer
	Create("TextLabel", {
		Parent = Title_Bar,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(0, 180, 1, 0),
		FontFace = Fonts.Main,
		Text = "build : " .. (Options.Build or "developer"),
		TextColor3 = Theme.Text_Dim,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})

	-- Right: time : subscription
	local Time_Label = Create("TextLabel", {
		Parent = Title_Bar,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.new(0, 200, 1, 0),
		FontFace = Fonts.Main,
		Text = "time : " .. (Options.Sub_Time or "lifetime"),
		TextColor3 = Theme.Text_Dim,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	})

	-- Centered brand title: eggtech | geteggtech.xyz
	Create_Animated_Title(Title_Bar, 13, 3)

	Make_Draggable(Window_Frame, Title_Bar)

	-- Main tabs: full-width, text only + highlight
	local Main_Tab_Bar = Create("Frame", {
		Parent = Window_Frame,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 0, 28),
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = 2,
	})
	Create("Frame", {
		Parent = Main_Tab_Bar,
		BackgroundColor3 = Theme.Border,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 2,
	})

	local Main_Tab_Row = Create("Frame", {
		Parent = Main_Tab_Bar,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -1),
		ZIndex = 3,
	})
	Create("UIListLayout", {
		Parent = Main_Tab_Row,
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})

	local Content_Host = Create("Frame", {
		Parent = Window_Frame,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 8, 0, 60),
		Size = UDim2.new(1, -16, 1, -68),
		ZIndex = 2,
	})
	Stroke(Content_Host, Theme.Border)

	local Window = {
		Frame = Window_Frame,
		Tabs = {},
		Active_Tab = nil,
	}

	local function Sync_UI_Input()
		local Open = Window_Frame.Visible
		Library.UI_Open = Open
		Modal_Sink.Visible = Open
		Set_Custom_Cursor(Open)
		if Open then
			pcall(function()
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end)
			pcall(function()
				UserInputService.OverrideMouseIconBehavior = Enum.OverrideMouseIconBehavior.None
			end)
		end
	end
	Sync_UI_Input()
	Connect(Window_Frame:GetPropertyChangedSignal("Visible"), Sync_UI_Input)

	-- Keep mouse unlocked while menu is open (games scripts often re-lock every frame)
	Connect(RunService.RenderStepped, function()
		if Window_Frame.Visible then
			pcall(function()
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end)
		end
	end)

	local Toggle_Key = Options.Toggle_Key or Enum.KeyCode.RightShift
	Connect(UserInputService.InputBegan, function(Input)
		if Input.KeyCode ~= Toggle_Key then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		Window_Frame.Visible = not Window_Frame.Visible
	end)

	function Window:Set_Visible(V)
		Window_Frame.Visible = V
	end

	function Window:Set_Sub_Time(New)
		Time_Label.Text = "time : " .. tostring(New)
	end

	function Window:Set_Build(New)
		-- build label is static; expose for convenience
		Options.Build = New
	end

	local function Reflow_Main_Tabs()
		local Count = math.max(#Window.Tabs, 1)
		for _, T in ipairs(Window.Tabs) do
			T.Button.Size = UDim2.new(1 / Count, 0, 1, 0)
		end
	end

	function Window:Add_Tab(Name)
		local Tab_Btn = Create("TextButton", {
			Parent = Main_Tab_Row,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(0.5, 0, 1, 0),
			FontFace = Fonts.Medium,
			Text = Name,
			TextColor3 = Theme.Text_Dim,
			TextSize = 13,
			AutoButtonColor = false,
			LayoutOrder = #Window.Tabs + 1,
			ZIndex = 4,
		})

		local Page = Create("Frame", {
			Parent = Content_Host,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 1, -14),
			Position = UDim2.new(0, 6, 0, 8),
			Visible = false,
			ZIndex = 3,
		})

		local Tab_Api = {
			Name = Name,
			Button = Tab_Btn,
			Page = Page,
		}

		function Tab_Api:Add_Tabbox()
			return Create_Tabbox(Page)
		end

		function Tab_Api:Show()
			if Window.Active_Tab then
				Window.Active_Tab.Page.Visible = false
				Window.Active_Tab.Button.TextColor3 = Theme.Text_Dim
			end
			Window.Active_Tab = Tab_Api
			Page.Visible = true
			Tab_Btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		end

		Connect(Tab_Btn.MouseButton1Click, function()
			Tab_Api:Show()
		end)
		Connect(Tab_Btn.MouseEnter, function()
			if Window.Active_Tab ~= Tab_Api then
				Tab_Btn.TextColor3 = Theme.Text
			end
		end)
		Connect(Tab_Btn.MouseLeave, function()
			if Window.Active_Tab ~= Tab_Api then
				Tab_Btn.TextColor3 = Theme.Text_Dim
			end
		end)

		table.insert(Window.Tabs, Tab_Api)
		Reflow_Main_Tabs()
		if #Window.Tabs == 1 then
			Tab_Api:Show()
		end
		return Tab_Api
	end

	table.insert(Library.Windows, Window)
	return Window
end

--------------------------------------------------------------------
-- Notifications (top-right stack, shove-down on new)
--------------------------------------------------------------------
local Notify_Stack = {}
local Notify_Pad_X = 14
local Notify_Pad_Y = 14
local Notify_Gap = 8
local Notify_Token = 0

local function Layout_Notifications()
	local Y = Notify_Pad_Y
	for _, Entry in ipairs(Notify_Stack) do
		if Entry.Frame and Entry.Frame.Parent then
			Tween(Entry.Frame, { Position = UDim2.new(1, -Notify_Pad_X, 0, Y) }, 0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
			Y += Entry.Height + Notify_Gap
		end
	end
end

local function Remove_Notification(Entry)
	if Entry.Removed then
		return
	end
	Entry.Removed = true

	for i, E in ipairs(Notify_Stack) do
		if E == Entry then
			table.remove(Notify_Stack, i)
			break
		end
	end

	local N = Entry.Frame
	if N and N.Parent then
		Tween(N, { BackgroundTransparency = 1 }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		if Entry.Label then
			Tween(Entry.Label, { TextTransparency = 1 }, 0.22)
		end
		if Entry.Stroke then
			Tween(Entry.Stroke, { Transparency = 1 }, 0.22)
		end
		if Entry.Bar then
			Tween(Entry.Bar, { BackgroundTransparency = 1 }, 0.22)
		end
		task.delay(0.24, function()
			if N.Parent then
				N:Destroy()
			end
		end)
	end

	Layout_Notifications()
end

function Library:Notify(Text, Duration)
	Duration = Duration or 3
	Text = tostring(Text or "")
	Notify_Token += 1
	local Token = Notify_Token

	local Bounds = TextService:GetTextSize(Text, 12, Enum.Font.BuilderSansExtraBold, Vector2.new(380, 200))
	local Width = math.clamp(Bounds.X + 26, 140, 420)
	local Height = math.max(28, Bounds.Y + 14)

	-- Squared panel, anchored to the top-right (always above UI popups)
	local N = Create("Frame", {
		Parent = Screen_Gui,
		Name = "Notification",
		BackgroundColor3 = Theme.Window,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Notify_Pad_X, 0, Notify_Pad_Y - 12),
		Size = UDim2.new(0, Width, 0, Height),
		ZIndex = Z_NOTIFY,
	})
	local Edge = Stroke(N, Theme.Border)
	Edge.Transparency = 1

	local Bar = Accent_Bar(N, Z_NOTIFY + 2)
	Bar.BackgroundTransparency = 1

	local Label = Create("TextLabel", {
		Parent = N,
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 2),
		Size = UDim2.new(1, -20, 1, -2),
		FontFace = Fonts.Main,
		Text = Text,
		TextColor3 = Theme.Text,
		TextTransparency = 1,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		ZIndex = Z_NOTIFY + 1,
	})

	local Entry = {
		Frame = N,
		Label = Label,
		Stroke = Edge,
		Bar = Bar,
		Height = Height,
		Token = Token,
		Removed = false,
	}

	-- New toast lands at the top; existing ones get shoved down
	table.insert(Notify_Stack, 1, Entry)
	Layout_Notifications()

	Tween(N, { BackgroundTransparency = 0 }, 0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	Tween(Label, { TextTransparency = 0 }, 0.28)
	Tween(Edge, { Transparency = 0 }, 0.28)
	Tween(Bar, { BackgroundTransparency = 0 }, 0.28)

	task.delay(Duration, function()
		if Entry.Token == Token and not Entry.Removed then
			Remove_Notification(Entry)
		end
	end)

	return Entry
end

function Library:Get_Flag(Flag)
	return Library.Flags[Flag]
end

function Library:Unload()
	Set_Custom_Cursor(false)
	for _, Conn in ipairs(Library.Connections) do
		pcall(function()
			Conn:Disconnect()
		end)
	end
	Screen_Gui:Destroy()
	Library.Unloaded = true
end

--------------------------------------------------------------------
-- Demo (disabled — use bloxstrike.lua as the entry script)
--------------------------------------------------------------------
local function Build_Demo()
	-- kept for manual testing: Library callers should build their own window
end

-- Build_Demo()
return Library
