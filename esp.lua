return (function()
if getgenv().EspLibrary and getgenv().EspLibrary.Unload then
    pcall(getgenv().EspLibrary.Unload, getgenv().EspLibrary)
end

local CloneRef = (typeof(cloneref) == 'function' and cloneref) or function(Object) return Object end

local GetService = setmetatable({}, {
    __index = function(_, Name)
        return CloneRef(game:GetService(Name));
    end;
})

local Workspace, Players, RunService, HttpService, ContentProvider = GetService["Workspace"], GetService["Players"], GetService["RunService"], GetService["HttpService"], GetService["ContentProvider"];
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local function GetCamera()
    if not Camera or Camera.Parent == nil then
        Camera = Workspace.CurrentCamera
    end

    return Camera
end

local FindFirstChildOfClass, FindFirstChild = game.FindFirstChildOfClass, game.FindFirstChild

local FighterBridge = (function()
    local Controller
    local ControllerLoaded = false
    local Started = false

    local function Start()
        if Started then
            return
        end

        Started = true

        task.spawn(function()
            local Ok, Result = pcall(function()
                local PlayerScripts = LocalPlayer:WaitForChild('PlayerScripts', 15)
                local Controllers = PlayerScripts and PlayerScripts:FindFirstChild('Controllers')
                local Module = Controllers and Controllers:FindFirstChild('FighterController')

                return Module and require(Module) or nil
            end)

            Controller = Ok and Result or false
            ControllerLoaded = true
        end)
    end

    local function GetController()
        if not ControllerLoaded or not Controller then
            return nil
        end

        return Controller
    end

    local function ResolveTeamValue(Player, Entity)
        local Team

        if Entity and Entity.GetAttribute then
            Team = Entity:GetAttribute('Team')
            if Team == nil then
                Team = Entity:GetAttribute('TeamID')
            end
        end

        if Team == nil and Player then
            Team = Player:GetAttribute('Team')
        end

        if Team == nil and Player then
            Team = Player:GetAttribute('TeamID')
        end

        return Team
    end

    local function IsEnemyPlayer(Player, Data)
        if Player == LocalPlayer then
            return false
        end

        local Character = Player.Character
        local Entity = Data and Data.ClientFighter and Data.ClientFighter.Entity

        if Entity and Entity.Character then
            Character = Entity.Character
        end

        if not Character or not Character:FindFirstChild('HumanoidRootPart') then
            return false
        end

        -- Prefer Team (Terrorists / CounterTerrorists), fall back to TeamID
        local LocalTeam = ResolveTeamValue(LocalPlayer, nil)
        local TheirTeam = ResolveTeamValue(Player, Entity)

        if LocalTeam ~= nil and TheirTeam ~= nil then
            return TheirTeam ~= LocalTeam
        end

        -- If either side has no team yet, don't treat as enemy (avoids flashing teammates)
        return false
    end

    local function ReadItemName(Item)
        if type(Item) == 'table' and type(Item.Name) == 'string' and Item.Name ~= '' then
            return Item.Name
        end

        return nil
    end

    local function ResolveFighter(Player, Data)
        if Player == LocalPlayer then
            return nil
        end

        local Now = os.clock()
        local CachedFighter = Data.ClientFighter

        if CachedFighter and CachedFighter.Player ~= Player then
            CachedFighter = nil
            Data.ClientFighter = nil
        end

        if CachedFighter and (Data._fighterLookupAt or 0) > Now then
            return CachedFighter
        end

        Data._fighterLookupAt = Now + 0.25

        local FighterController = GetController()

        if not FighterController or not FighterController.GetFighter then
            return CachedFighter
        end

        local Ok, Fighter = pcall(FighterController.GetFighter, FighterController, Player)

        if Ok and Fighter and Fighter.IsLocalPlayer ~= true then
            Data.ClientFighter = Fighter
            return Fighter
        end

        return CachedFighter
    end

    local function DecodeCurrentEquipped(Player)
        local Raw = Player:GetAttribute('CurrentEquipped')

        if type(Raw) ~= 'string' or Raw == '' then
            return nil
        end

        local Ok, Decoded = pcall(HttpService.JSONDecode, HttpService, Raw)

        if Ok and type(Decoded) == 'table' then
            return Decoded
        end

        return nil
    end

    local function GetEquippedWeaponName(Player, Data)
        if Player == LocalPlayer then
            return 'none'
        end

        local Decoded = DecodeCurrentEquipped(Player)

        if Decoded and type(Decoded.Name) == 'string' and Decoded.Name ~= '' then
            return Decoded.Name
        end

        local Fighter = ResolveFighter(Player, Data)

        if not Fighter then
            return 'none'
        end

        return ReadItemName(Fighter.Item)
            or ReadItemName(Fighter.EquippedItem)
            or 'none'
    end

    local function GetEquippedAmmoText(Player)
        if Player == LocalPlayer then
            return 'ammo : 0/0'
        end

        local Decoded = DecodeCurrentEquipped(Player)

        if not Decoded then
            return 'ammo : 0/0'
        end

        -- Rounds = current magazine, Capacity = mag size
        local CurrentMag = tonumber(Decoded.Rounds) or 0
        local MagSize = tonumber(Decoded.Capacity) or 0

        return string.format('ammo : %d/%d', CurrentMag, MagSize)
    end

    local function ClearPlayerCache(Data)
        if not Data then
            return
        end

        Data.ClientFighter = nil
        Data._fighterLookupAt = nil
    end

    return {
        Start = Start,
        IsEnemyPlayer = IsEnemyPlayer,
        GetEquippedWeaponName = GetEquippedWeaponName,
        GetEquippedAmmoText = GetEquippedAmmoText,
        ClearPlayerCache = ClearPlayerCache,
        -- EspTrier always renders (no in-duel gate)
        IsLocalFighterActive = function()
            return true
        end,
    }
end)()

local NewVector3, NewVector2, Dim, Dim2, DimOffset = Vector3.new, Vector2.new, UDim.new, UDim2.new, UDim2.fromOffset;
local NumSeq = NumberSequence.new;
local NumKey = NumberSequenceKeypoint.new;

local Format, Spawn, Clear, Floor, Clamp, Abs, Tan, Rad, Huge, Remove, Exp = string.format, task.spawn, table.clear, math.floor, math.clamp, math.abs, math.tan, math.rad, math.huge, table.remove, math.exp;
local Frame, ZeroVector3, CameraPosition, CachedFocalLength, ViewPortY, Updates = 1 / 240, NewVector3(0,0,0), NewVector3(0,0,0), 0, 0, 0;

local function SetGameIdentity()
    if typeof(setthreadidentity) == 'function' then
        setthreadidentity(8)
    end
end

local function HideEspEntry(Data)
    if not Data or not Data['Objects'] then
        return
    end

    local Objects = Data['Objects']

    pcall(function()
        if Objects['TargetHolder'] and Objects['TargetHolder'].Visible then
            Objects['TargetHolder'].Visible = false
        end

        if Objects['SkeletonRoot'] and Objects['SkeletonRoot'].Visible then
            Objects['SkeletonRoot'].Visible = false
        end
    end)
end
local BAR_TWEEN_SPEED = 28
local BAR_SNAP_THRESHOLD = 0.001

local function LerpBarValue(Current, Target, DeltaTime)
    if Abs(Target - Current) <= BAR_SNAP_THRESHOLD then
        return Target
    end

    local Alpha = 1 - Exp(-BAR_TWEEN_SPEED * DeltaTime)
    return Current + (Target - Current) * Alpha
end

local function GetBarDisplayThickness(MaxThickness, Ratio)
    local Max = MaxThickness or 1
    Ratio = Clamp(Ratio or 0, 0, 1)

    if Max <= 1 then
        return 1
    end

    return 1 + (Max - 1) * Ratio
end

local White = Color3.fromRGB(255, 255, 255)
local DEFAULT_ANIM_SPEED = 1
local BASE_GRADIENT_RATE = 0.25
local SPIN_DEGREES_PER_SECOND = 140
local GradientScrollClock = 0
local LastGradientTick = os.clock()

local WeaponIconCache = {}
local WeaponModuleCache = {}

local function GetWeaponIcon(name)
    if type(name) ~= 'string' or name == '' or name == 'none' then
        return nil
    end

    if WeaponIconCache[name] ~= nil then
        local cached = WeaponIconCache[name]
        return cached ~= false and cached or nil
    end

    local ok, icon = pcall(function()
        -- BloxStrike: ReplicatedStorage.Database.Custom.Weapons[name].Icon
        local Database = ReplicatedStorage:FindFirstChild('Database') or ReplicatedStorage:FindFirstChild('database')
        if not Database then
            return nil
        end
        local Custom = Database:FindFirstChild('Custom')
        if not Custom then
            return nil
        end
        local Weapons = Custom:FindFirstChild('Weapons')
        if not Weapons then
            return nil
        end
        local data = Weapons:FindFirstChild(name)
        if not data then
            return nil
        end

        local mod = WeaponModuleCache[name]
        if mod == nil then
            local rok, required = pcall(require, data)
            if rok and type(required) == 'table' then
                mod = required
                WeaponModuleCache[name] = mod
            else
                WeaponModuleCache[name] = false
                return nil
            end
        elseif mod == false then
            return nil
        end

        return mod.Icon
    end)

    if ok and type(icon) == 'string' and icon ~= '' then
        WeaponIconCache[name] = icon
        return icon
    end

    WeaponIconCache[name] = false
    return nil
end

-- Aspect / size bias so long guns (AWP) read wider than pistols
local function GetWeaponIconAspect(name)
    local lower = string.lower(tostring(name or ''))
    if lower:find('awp', 1, true) or lower:find('ssg', 1, true) or lower:find('scout', 1, true) then
        return 2.35, 1.05 -- wide, slightly taller
    end
    if lower:find('auto', 1, true) or lower:find('ak', 1, true) or lower:find('m4', 1, true)
        or lower:find('galil', 1, true) or lower:find('famas', 1, true)
        or lower:find('aug', 1, true) or lower:find('sg', 1, true)
        or lower:find('mp', 1, true) or lower:find('p90', 1, true)
        or lower:find('ump', 1, true) or lower:find('mac', 1, true)
        or lower:find('nova', 1, true) or lower:find('xm', 1, true)
        or lower:find('mag', 1, true) or lower:find('negev', 1, true)
        or lower:find('m249', 1, true) or lower:find('sawed', 1, true) then
        return 1.95, 1.0
    end
    if lower:find('deagle', 1, true) or lower:find('usp', 1, true) or lower:find('glock', 1, true)
        or lower:find('p250', 1, true) or lower:find('five', 1, true) or lower:find('tec', 1, true)
        or lower:find('cz', 1, true) or lower:find('dual', 1, true) or lower:find('revolver', 1, true)
        or lower:find('knife', 1, true) or lower:find('bayonet', 1, true) then
        return 1.35, 0.92
    end
    if lower:find('grenade', 1, true) or lower:find('flash', 1, true) or lower:find('smoke', 1, true)
        or lower:find('molotov', 1, true) or lower:find('incendiary', 1, true)
        or lower:find('decoy', 1, true) or lower:find('c4', 1, true) then
        return 1.15, 0.95
    end
    return 1.75, 1.0
end

local function GetWeaponIconPixelSize(name, distance, maxHeight)
    maxHeight = maxHeight or 14
    -- Bucket distance so icon size does not thrash every frame (jitter)
    local DistBucket = Floor((tonumber(distance) or 0) / 12) * 12
    local distScale = Clamp(DistBucket / 85, 0.48, 1.0)
    local aspectW, aspectH = GetWeaponIconAspect(name)
    local h = Floor(maxHeight * distScale * aspectH + 0.5)
    local w = Floor(h * aspectW + 0.5)
    h = Clamp(h, 7, 20)
    w = Clamp(w, 10, 46)
    return w, h
end

local function GetCfgAnimSpeed(Cfg)
    return Clamp(Cfg.AnimSpeed or DEFAULT_ANIM_SPEED, 0.05, 10)
end

local function GetGradientTime(Cfg)
    return GradientScrollClock * GetCfgAnimSpeed(Cfg)
end

local function StepGradientScrollClock(DeltaTime)
    GradientScrollClock += DeltaTime * BASE_GRADIENT_RATE
end

local function GetCfgColor1(Cfg, Fallback)
    return Cfg.Color1 or Cfg.Top or Cfg.Color or Fallback or White
end

local function GetCfgColor2(Cfg, Fallback)
    return Cfg.Color2 or Cfg.Bot or Fallback or White
end

local function GetScrollPhase(Cfg)
    local Time = GetGradientTime(Cfg)
    return Time - math.floor(Time)
end

local function OffsetColorSequence(Original, Offset)
    local Keypoints = {}

    for _, Keypoint in ipairs(Original.Keypoints) do
        table.insert(Keypoints, ColorSequenceKeypoint.new((Keypoint.Time + Offset) % 1, Keypoint.Value))
    end

    table.sort(Keypoints, function(A, B)
        return A.Time < B.Time
    end)

    local First = Keypoints[1]
    local Last = Keypoints[#Keypoints]
    local GapBefore = First.Time
    local GapAfter = 1 - Last.Time
    local GapTotal = GapBefore + GapAfter
    local Blend = GapTotal > 0 and (GapBefore / GapTotal) or 0
    local WrapColor = First.Value:Lerp(Last.Value, Blend)

    if First.Time ~= 0 then
        table.insert(Keypoints, 1, ColorSequenceKeypoint.new(0, WrapColor))
    end

    if Last.Time ~= 1 then
        table.insert(Keypoints, ColorSequenceKeypoint.new(1, WrapColor))
    end

    return ColorSequence.new(Keypoints)
end

local function OffsetNumberSequence(Original, Offset)
    local Keypoints = {}

    for _, Keypoint in ipairs(Original.Keypoints) do
        table.insert(Keypoints, NumberSequenceKeypoint.new((Keypoint.Time + Offset) % 1, Keypoint.Value))
    end

    table.sort(Keypoints, function(A, B)
        return A.Time < B.Time
    end)

    local First = Keypoints[1]
    local Last = Keypoints[#Keypoints]
    local GapBefore = First.Time
    local GapAfter = 1 - Last.Time
    local GapTotal = GapBefore + GapAfter
    local Blend = GapTotal > 0 and (GapBefore / GapTotal) or 0
    local WrapValue = First.Value + (Last.Value - First.Value) * Blend

    if First.Time ~= 0 then
        table.insert(Keypoints, 1, NumberSequenceKeypoint.new(0, WrapValue))
    end

    if Last.Time ~= 1 then
        table.insert(Keypoints, NumberSequenceKeypoint.new(1, WrapValue))
    end

    return NumberSequence.new(Keypoints)
end

local function BuildTwoColorScrollBase(Cfg)
    local Color1 = GetCfgColor1(Cfg)
    local Color2 = GetCfgColor2(Cfg)

    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color1),
        ColorSequenceKeypoint.new(0.5, Color2),
        ColorSequenceKeypoint.new(1, Color1),
    })
end

local function BuildTwoColorTransparencyBase(TransparencyA, TransparencyB)
    return NumSeq({
        NumKey(0, TransparencyA),
        NumKey(0.5, TransparencyB),
        NumKey(1, TransparencyA),
    })
end

local function BuildHealthScrollBase(Cfg)
    local Top = Cfg.Top or Color3.fromRGB(0, 255, 0)
    local Mid = Cfg.Mid or Color3.fromRGB(255, 255, 0)
    local Bot = Cfg.Bot or Color3.fromRGB(255, 0, 0)

    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, Top),
        ColorSequenceKeypoint.new(1 / 3, Mid),
        ColorSequenceKeypoint.new(2 / 3, Bot),
        ColorSequenceKeypoint.new(1, Top),
    })
end

local function SetTwoColorSequence(Gradient, Cfg)
    local Color1 = GetCfgColor1(Cfg)
    local Color2 = GetCfgColor2(Cfg)

    Gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color1),
        ColorSequenceKeypoint.new(1, Color2),
    })
end

local StaticGradientCache = setmetatable({}, { __mode = 'k' })

local function ApplyScrollingGradient(Gradient, Cfg, BaseRotation, TransparencyA, TransparencyB)
    Gradient.Rotation = BaseRotation or 0
    Gradient.Offset = Vector2.new(0, 0)

    local Phase = GetScrollPhase(Cfg)
    Gradient.Color = OffsetColorSequence(BuildTwoColorScrollBase(Cfg), Phase)

    if TransparencyA ~= nil and TransparencyB ~= nil then
        Gradient.Transparency = OffsetNumberSequence(
            BuildTwoColorTransparencyBase(TransparencyA, TransparencyB),
            Phase
        )
    end
end

local function ApplyTwoColorGradient(Gradient, Cfg, BaseRotation, TransparencyA, TransparencyB)
    if not Gradient then
        return
    end

    BaseRotation = BaseRotation or 0

    if not Cfg.Animate then
        local Color1 = GetCfgColor1(Cfg, White)
        local Color2 = GetCfgColor2(Cfg, White)
        local Prev = StaticGradientCache[Gradient]
        if not Prev or Prev.C1 ~= Color1 or Prev.C2 ~= Color2 or Prev.Rot ~= BaseRotation then
            SetTwoColorSequence(Gradient, Cfg)
            Gradient.Rotation = BaseRotation
            Gradient.Offset = Vector2.new(0, 0)
            StaticGradientCache[Gradient] = { C1 = Color1, C2 = Color2, Rot = BaseRotation }
        end
        return
    end

    -- Animating — drop static cache so a later static pass re-applies
    StaticGradientCache[Gradient] = nil

    local Mode = Cfg.Mode or 'Scroll'

    if Mode == 'Spin' then
        SetTwoColorSequence(Gradient, Cfg)
        Gradient.Rotation = BaseRotation + GetGradientTime(Cfg) * SPIN_DEGREES_PER_SECOND
        Gradient.Offset = Vector2.new(0, 0)
    elseif Mode == 'Scroll' then
        ApplyScrollingGradient(Gradient, Cfg, BaseRotation, TransparencyA, TransparencyB)
    else
        SetTwoColorSequence(Gradient, Cfg)
        Gradient.Rotation = BaseRotation
        Gradient.Offset = Vector2.new(0, 0)
    end
end

local function ShouldUseScrollingTransparency(Cfg)
    return Cfg.Animate and (Cfg.Mode or 'Scroll') == 'Scroll'
end

local function SyncGradientTransparency(Gradient, Cfg, TransparencyA, TransparencyB, LastKey, Data)
    if not Gradient or TransparencyA == nil or TransparencyB == nil then
        return
    end

    if ShouldUseScrollingTransparency(Cfg) then
        return
    end

    local T1 = TransparencyA
    local T2 = TransparencyB

    if Data[LastKey .. 'T1'] ~= T1 or Data[LastKey .. 'T2'] ~= T2 then
        Gradient.Transparency = NumSeq({NumKey(0, T1), NumKey(1, T2)})
        Data[LastKey .. 'T1'] = T1
        Data[LastKey .. 'T2'] = T2
    end
end

local function GetPingPongPhase(Cfg)
    local Time = GetGradientTime(Cfg)
    local Cycle = Time % 2

    if Cycle > 1 then
        return 2 - Cycle
    end

    return Cycle
end

local function ApplyHealthBarGradient(Gradient, Cfg)
    if not Gradient then
        return
    end

    local Top = Cfg.Top or Color3.fromRGB(0, 255, 0)
    local Mid = Cfg.Mid or Color3.fromRGB(255, 255, 0)
    local Bot = Cfg.Bot or Color3.fromRGB(255, 0, 0)

    Gradient.Rotation = 90

    local Mode = Cfg.Mode or 'None'
    if Mode == 'None' and Cfg.ScrollColors then
        Mode = 'Scroll'
    end

    local Animate = Cfg.Animate == true or (Mode ~= 'None' and Mode ~= nil)

    if not Animate or Mode == 'None' then
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Top),
            ColorSequenceKeypoint.new(0.5, Mid),
            ColorSequenceKeypoint.new(1, Bot),
        })
        Gradient.Offset = Vector2.new(0, 0)
        return
    end

    if Mode == 'PingPong' then
        local Phase = GetPingPongPhase(Cfg) * 0.85
        Gradient.Color = OffsetColorSequence(BuildHealthScrollBase(Cfg), Phase)
        Gradient.Offset = Vector2.new(0, 0)
    elseif Mode == 'Pulse' then
        local Pulse = (math.sin(GetGradientTime(Cfg) * math.pi * 2) + 1) * 0.5
        local Hot = Mid:Lerp(Top, Pulse)
        local Cool = Bot:Lerp(Mid, Pulse)
        Gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Hot),
            ColorSequenceKeypoint.new(0.5, Mid:Lerp(Hot, 0.35)),
            ColorSequenceKeypoint.new(1, Cool),
        })
        Gradient.Offset = Vector2.new(0, 0)
    else
        -- Scroll (default animated)
        local Phase = GetScrollPhase(Cfg)
        Gradient.Color = OffsetColorSequence(BuildHealthScrollBase(Cfg), Phase)
        Gradient.Offset = Vector2.new(0, 0)
    end
end

local DEFAULT_FLAG_LABELS = {
    Walking = 'Walking',
    Jumping = 'Jumping',
    Swimming = 'Swimming',
}

local function TrimText(Text)
    if type(Text) ~= 'string' then
        return ''
    end

    return (Text:match('^%s*(.-)%s*$'))
end

local function GetFlagDisplayText(FlagCfg, DefaultLabel)
    local Text = TrimText(FlagCfg.Text)

    if Text ~= '' then
        return Text
    end

    return DefaultLabel
end

local function GetNameDisplayText(NameCfg, DisplayName)
    local Text = TrimText(NameCfg.Text)

    if Text ~= '' then
        return Text
    end

    return DisplayName
end

local SKELETON_LINE_COUNT = 14

local R15_BONES = {
    { 'Head', 'UpperTorso' },
    { 'UpperTorso', 'LowerTorso' },
    { 'UpperTorso', 'LeftUpperArm' },
    { 'LeftUpperArm', 'LeftLowerArm' },
    { 'LeftLowerArm', 'LeftHand' },
    { 'UpperTorso', 'RightUpperArm' },
    { 'RightUpperArm', 'RightLowerArm' },
    { 'RightLowerArm', 'RightHand' },
    { 'LowerTorso', 'LeftUpperLeg' },
    { 'LeftUpperLeg', 'LeftLowerLeg' },
    { 'LeftLowerLeg', 'LeftFoot' },
    { 'LowerTorso', 'RightUpperLeg' },
    { 'RightUpperLeg', 'RightLowerLeg' },
    { 'RightLowerLeg', 'RightFoot' },
}

local R6_BONES = {
    { 'Head', 'Torso' },
    { 'Torso', 'Left Arm' },
    { 'Torso', 'Right Arm' },
    { 'Torso', 'Left Leg' },
    { 'Torso', 'Right Leg' },
}

local function GetSkeletonBoneLinks(Character, Humanoid)
    if Humanoid and Humanoid.RigType == Enum.HumanoidRigType.R6 then
        return R6_BONES
    end

    if Character and Character:FindFirstChild('UpperTorso') then
        return R15_BONES
    end

    return R6_BONES
end

local function SetScreenLineFrame(Line, X1, Y1, X2, Y2, Thickness, ExtendLength)
    local DX = X2 - X1
    local DY = Y2 - Y1
    local Length = math.sqrt(DX * DX + DY * DY)

    if Length < 1 then
        Line.Visible = false
        return false
    end

    Line.AnchorPoint = NewVector2(0.5, 0.5)
    Line.Position = DimOffset((X1 + X2) * 0.5, (Y1 + Y2) * 0.5)
    Line.Size = DimOffset(Length + (ExtendLength or 0), Thickness)
    Line.Rotation = math.deg(math.atan2(DY, DX))
    Line.Visible = true

    return true
end

local function SetPixelLineFrame(Line, X1, Y1, X2, Y2, Thickness)
    local DX = X2 - X1
    local DY = Y2 - Y1
    local Length = math.sqrt(DX * DX + DY * DY)

    if Length < 1 then
        Line.Visible = false
        return false
    end

    Thickness = math.max(Floor(Thickness + 0.5), 1)
    Length = math.max(Floor(Length + 0.5), 1)

    Line.AnchorPoint = NewVector2(0.5, 0.5)
    Line.Position = DimOffset(Floor((X1 + X2) * 0.5 + 0.5), Floor((Y1 + Y2) * 0.5 + 0.5))
    Line.Size = DimOffset(Length, Thickness)
    Line.Rotation = math.deg(math.atan2(DY, DX))
    Line.Visible = true

    return true
end

local BOX_GLOW_PAD_LEFT = 21
local BOX_GLOW_PAD_TOP = 21
local BOX_GLOW_PAD_RIGHT = 20
local BOX_GLOW_PAD_BOTTOM = 20
local BOX_GLOW_PAD_X = BOX_GLOW_PAD_LEFT + BOX_GLOW_PAD_RIGHT
local BOX_GLOW_PAD_Y = BOX_GLOW_PAD_TOP + BOX_GLOW_PAD_BOTTOM

local function WorldToViewportPoint(Cam, Position)
    return Cam:WorldToViewportPoint(Position)
end

local function GetScreenPoint(Cam, WorldPos, ViewportFrame)
    if ViewportFrame then
        local Size = ViewportFrame.AbsoluteSize

        if Size.X < 2 or Size.Y < 2 then
            return nil, false
        end

        local Local = Cam.CFrame:PointToObjectSpace(WorldPos)

        if Local.Z >= -0.05 then
            return nil, false
        end

        local Focal = Size.Y / (2 * Tan(Rad(Cam.FieldOfView * 0.5)))
        local ScreenX = Size.X * 0.5 + (-Local.X / Local.Z) * Focal
        local ScreenY = Size.Y * 0.5 + (-Local.Y / Local.Z) * Focal

        return NewVector3(ScreenX, ScreenY, -Local.Z), true
    end

    return WorldToViewportPoint(Cam, WorldPos)
end

local function CameraCache()
    local Cam = GetCamera()

    if not Cam then
        return
    end

    ViewPortY = Cam.ViewportSize.Y;
    CachedFocalLength = ViewPortY / (2 * Tan(Rad(Cam.FieldOfView) * 0.5));
end

CameraCache();

do
    local Cam = GetCamera()

    if Cam then
        Cam:GetPropertyChangedSignal('FieldOfView'):Connect(CameraCache)
        Cam:GetPropertyChangedSignal('ViewportSize'):Connect(CameraCache)
    end

    Workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
        Camera = Workspace.CurrentCamera
        CameraCache()
    end)
end

local EspLibrary = {
    ['Directory'] = 'Esp',
    ['Cache'] = {},
    ['Holder'] = nil,
    ['Threads'] = {},
    ['Connections'] = {},

    ['Table'] = {
        ['Enabled'] = false,
        ['ShowLocalPlayer'] = false,
        ['TeamCheck'] = true,
        ['Distance'] = 7520,
        ['RefreshRate'] = 240,
        ['Font'] = 'TahomaBold',
        ['FontSize'] = 12,
        ['FontType'] = 'none',

        ['Boxes'] = {
            ['Enabled'] = true,
            ['DynamicBoxes'] = true,
            ['Type'] = "2D",
            ['Rotation'] = 90,

            ['Bounding Box'] = {
                ['Enabled'] = true,
                ['IncludeAcsessories'] = false,
                ['BoxX'] = 0,
                ['BoxY'] = 0,
            },

            ['Box Glow'] = {
                ['Enabled'] = false,
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
                ['Transparency'] = {0.75, 0.75},
            },

            ['Gradients'] = {
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Spin',
                ['AnimSpeed'] = 1,
            },

            ['Filled'] = {
                ['Enabled'] = false,
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
                ['Transparency'] = {1, 0.65},
            },
        },

        ['Bars'] = {
            ['Health Bar'] = {
                ['Enabled'] = false,
                ['Top'] = Color3.fromRGB(0, 255, 0),
                ['Mid'] = Color3.fromRGB(255, 255, 0),
                ['Bot'] = Color3.fromRGB(255, 0, 0),
                ['ScrollColors'] = false,
                ['Animate'] = false,
                ['Mode'] = 'None',
                ['AnimSpeed'] = 1,
                ['Thickness'] = 1,
                ['FontSize'] = 9,
            },

            ['Health Numbers'] = {
                ['Enabled'] = false,
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
                ['Offset'] = 10,
            },
        },

        ['Skeleton'] = {
            ['Enabled'] = false,
            ['Color1'] = White,
            ['Color2'] = White,
            ['Animate'] = false,
            ['Mode'] = 'Scroll',
            ['AnimSpeed'] = 1,
            ['Thickness'] = 1,
            ['HeadDot'] = {
                ['Enabled'] = false,
                ['Color'] = White,
                ['Size'] = 5,
            },
        },
        ['Texts'] = {
            ['Name'] = {
                ['Enabled'] = false,
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
                ['FontSize'] = 12,
                ['Text'] = '',
            },

            ['Distance'] = {
                ['Enabled'] = false,
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
                ['FontSize'] = 9,
            },

            ['Weapon'] = {
                ['Enabled'] = false,
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
                ['FontSize'] = 9,
                ['ShowText'] = true,
                ['ShowIcon'] = true,
                ['IconMaxHeight'] = 14,
            },
        },

        ['Flags'] = {
            ['Enabled'] = false,
            ['FontSize'] = 9,

            ['Ammo'] = {
                ['Enabled'] = false,
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
            },

            ['Walking'] = {
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
                ['Text'] = '',
            },
            ['Jumping'] = {
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
                ['Text'] = '',
            },
            ['Swimming'] = {
                ['Color1'] = White,
                ['Color2'] = White,
                ['Animate'] = false,
                ['Mode'] = 'Scroll',
                ['AnimSpeed'] = 1,
                ['Text'] = '',
            },
        },

        ['Chams'] = {
            ['Enabled'] = false,
            ['Color1'] = Color3.fromRGB(255, 0, 0), -- Main fill
            ['Color2'] = Color3.fromRGB(255, 255, 255), -- Glow / XRay
            ['GlowEnabled'] = true,
            ['Transparency'] = 0.5, -- fill transparency (0 solid → 1 invisible)
            ['GlowTransparency'] = 0, -- glow transparency (0 solid → 1 invisible; ~0 uses XRay -1)
            ['GlowStrength'] = 5, -- color boost multiplier for glow adorn
            ['GlowSize'] = 0.03, -- glow adorn size offset (studs)
            ['Animate'] = false,
            ['Mode'] = 'None',
            ['AnimSpeed'] = 1,
        },
    }
}

local Table = EspLibrary['Table'];
local RuntimeActive = false
local LoopsStarted = false
local PlayersInitialized = false

local Fonts = {}

local DefaultFallbackFont = Enum.Font.Roboto

local function MakeFontFace(AssetId, Fallback)
    if AssetId and Font and Font.new then
        local Ok, Face = pcall(Font.new, AssetId, Enum.FontWeight.Regular, Enum.FontStyle.Normal)

        if Ok and Face then
            return Face
        end
    end

    local Ok, Face = pcall(Font.fromEnum, Fallback or DefaultFallbackFont)

    if Ok and Face then
        return Face
    end

    return Font.fromEnum(DefaultFallbackFont)
end

do
    local HasFiles = isfile and writefile and getcustomasset and game and game.HttpGet

    local function FontsRegister(Name, Weight, Style, Asset)
        if not HasFiles then
            return nil
        end

        local Ok, Result = pcall(function()
            if not isfile(Asset.Id) then
                local FontData = game:HttpGet(Asset.Url)

                if type(FontData) ~= 'string' or #FontData == 0 then
                    return nil
                end

                writefile(Asset.Id, FontData)
            end

            if isfile(Name .. '.font') and delfile then
                pcall(delfile, Name .. '.font')
            end

            local Info = {
                name = Name,
                faces = {
                    {
                        name = 'Normal',
                        weight = Weight,
                        style = Style,
                        assetId = getcustomasset(Asset.Id),
                    },
                },
            }

            writefile(Name .. '.font', HttpService:JSONEncode(Info))
            return getcustomasset(Name .. '.font')
        end)

        return Ok and Result or nil
    end

    if HasFiles then
        local FontJobs = {
            { Key = 'Tahoma', Name = 'Tahoma', Weight = 400, Style = 'Normal', Id = 'Tahoma.ttf', Url = 'https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/fs-tahoma-8px.ttf' },
            { Key = 'XPTahoma', Name = 'XPTahoma', Weight = 400, Style = 'Normal', Id = 'Tahoma8PTBOLD.ttf', Url = 'https://github.com/sametexe001/luas/raw/refs/heads/main/fonts/TAHOMA-8PT-BOLD-WINDOWS-XP.TTF' },
            { Key = 'SmallestPixel', Name = 'SmallestPixel', Weight = 400, Style = 'Normal', Id = 'smallest_pixel-7.ttf', Url = 'https://raw.githubusercontent.com/sametexe001/luas/main/smallest_pixel-7.ttf' },
            { Key = 'ProggyTiny', Name = 'ProggyTiny', Weight = 400, Style = 'Normal', Id = 'ProggyTinyyyy.ttf', Url = 'https://github.com/i77lhm/storage/raw/refs/heads/main/fonts/ProggyTiny.ttf' },
            { Key = 'ProggyClean', Name = 'ProggyClean', Weight = 400, Style = 'Normal', Id = 'ProggyClean.ttf', Url = 'https://github.com/i77lhm/storage/raw/main/fonts/ProggyClean.ttf' },
        }

        function EspLibrary:LoadFontsAsync()
            if self._fontsLoadStarted or self._fontsReady then
                return
            end

            self._fontsLoadStarted = true

            task.spawn(function()
                for Index, Job in ipairs(FontJobs) do
                    Fonts[Job.Key] = FontsRegister(Job.Name, Job.Weight, Job.Style, {
                        Id = Job.Id,
                        Url = Job.Url,
                    })

                    if Index % 2 == 0 then
                        task.wait(0.05)
                    end
                end

                EspLibrary.ProggyTiny = MakeFontFace(Fonts.ProggyTiny, Enum.Font.Code)
                EspLibrary.TahomaBold = MakeFontFace(Fonts.XPTahoma, Enum.Font.Roboto)
                EspLibrary.ProggyClean = MakeFontFace(Fonts.ProggyClean, Enum.Font.Code)
                EspLibrary.Tahoma = MakeFontFace(Fonts.Tahoma, Enum.Font.Roboto)
                EspLibrary.SmallestPixel = MakeFontFace(Fonts.SmallestPixel, Enum.Font.Code)
                EspLibrary._fontsReady = true

                if RuntimeActive then
                    EspLibrary:ApplyFonts()
                end
            end)
        end
    else
        function EspLibrary:LoadFontsAsync()
        end
    end

    EspLibrary.ProggyTiny = MakeFontFace(Fonts.ProggyTiny, Enum.Font.Code)
    EspLibrary.TahomaBold = MakeFontFace(Fonts.XPTahoma, Enum.Font.Roboto)
    EspLibrary.ProggyClean = MakeFontFace(Fonts.ProggyClean, Enum.Font.Code)
    EspLibrary.Tahoma = MakeFontFace(Fonts.Tahoma, Enum.Font.Roboto)
    EspLibrary.SmallestPixel = MakeFontFace(Fonts.SmallestPixel, Enum.Font.Code)
end

local FONT_RESOLVERS = {
    TahomaBold = function() return EspLibrary.TahomaBold end,
    Tahoma = function() return EspLibrary.Tahoma end,
    SmallestPixel = function() return EspLibrary.SmallestPixel end,
    ProggyTiny = function() return EspLibrary.ProggyTiny end,
    ProggyClean = function() return EspLibrary.ProggyClean end,
}

for _, EnumFont in ipairs(Enum.Font:GetEnumItems()) do
    local Name = EnumFont.Name

    if not FONT_RESOLVERS[Name] then
        FONT_RESOLVERS[Name] = function()
            local Ok, Face = pcall(Font.fromEnum, EnumFont)

            if Ok and Face then
                return Face
            end

            return EspLibrary.TahomaBold
        end
    end
end

function EspLibrary:GetFontFace(Name)
    local Resolver = FONT_RESOLVERS[Name] or FONT_RESOLVERS.TahomaBold
    local Ok, Face = pcall(Resolver)

    if Ok and Face then
        return Face
    end

    return self.TahomaBold
end

function EspLibrary:GetFontNames()
    local Names = {}

    for Name in pairs(FONT_RESOLVERS) do
        Names[#Names + 1] = Name
    end

    table.sort(Names)
    return Names
end

function EspLibrary:GetTextSize(Key)
    local Fallback = Table.FontSize or 12

    if Key == 'TargetName' then
        return Table.Texts.Name.FontSize or Fallback
    elseif Key == 'Distance' then
        return Table.Texts.Distance.FontSize or Fallback
    elseif Key == 'Weapon' then
        return Table.Texts.Weapon.FontSize or Fallback
    elseif Key == 'HealthBarText' then
        return Table.Bars['Health Bar'].FontSize or Fallback
    elseif Key == 'AmmoFlag' then
        -- Same letter-height limit as health bar text
        return Table.Bars['Health Bar'].FontSize or Table.Flags.FontSize or Fallback
    elseif Key == 'WalkFlag' or Key == 'JumpFlag' or Key == 'SwimmingFlag' then
        return Table.Flags.FontSize or Fallback
    end

    return Fallback
end

function EspLibrary:ApplyFontToObjects(Objects)
    if not Objects then
        return
    end

    local Face = self:GetFontFace(Table.Font)
    local Labels = {
        'TargetName', 'Distance', 'Weapon', 'AmmoFlag', 'WalkFlag', 'JumpFlag',
        'SwimmingFlag', 'HealthBarText',
    }

    for _, Key in ipairs(Labels) do
        local Label = Objects[Key]

        if Label and Label:IsA('TextLabel') then
            Label.FontFace = Face
            Label.TextSize = self:GetTextSize(Key)
        end
    end
end

function EspLibrary:ApplyFonts()
    for _, Data in pairs(self.Cache) do
        self:ApplyFontToObjects(Data.Objects)
    end

    if self.PreviewData then
        self:ApplyFontToObjects(self.PreviewData.Objects)
    end
end

function EspLibrary:ApplyFont(Name)
    if Name then
        Table.Font = Name
    end

    self:ApplyFonts()
end

EspLibrary.__index = EspLibrary;

function EspLibrary:CreateObjects(Name, Prop)
    local New = Instance.new(Name);

    for Property, Value in pairs(Prop or {}) do
        New[Property] = Value;
    end;
            
    return New;
end

function EspLibrary:CreateThreads(Name, Signal, Callback)
    local Connection = Signal:Connect(Callback);
    self.Threads[Name] = Connection;
    return Connection;
end

local HolderParent = (gethui and gethui()) or CloneRef(game:GetService("CoreGui"))
local ProtectGui = protectgui or (syn and syn.protect_gui) or function() end

local ChamsFolder = nil

local function GetChamsFolder()
    if not ChamsFolder then
        ChamsFolder = Instance.new('Folder')
        ChamsFolder.Name = 'EspChams'
        ChamsFolder.Parent = Workspace
    end

    return ChamsFolder
end

function EspLibrary:EnsureHolder()
    if self.Holder then
        return
    end

    self.Holder = self:CreateObjects("ScreenGui", {
        Name = "\n",
        Parent = HolderParent,
        ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        ResetOnSpawn = false,
        DisplayOrder = 10000,
        IgnoreGuiInset = true,
    })
    ProtectGui(self.Holder)
end
local CHAMS_REFRESH_INTERVAL = 1.25
local CHAMS_MAX_REFRESH_PER_FRAME = 2

local ChamsRefreshQueue = {}
local ChamsRefreshQueued = {}

local function AreChamsFullyApplied(ChamsData, Character)
    if not ChamsData or not Character or not Character.Parent then
        return false
    end

    if ChamsData.Adorn then
        return ChamsData.Character == Character
    end

    return false
end

local function DequeueChamsRefresh(Data)
    ChamsRefreshQueued[Data] = nil

    for Index = #ChamsRefreshQueue, 1, -1 do
        if ChamsRefreshQueue[Index] == Data then
            Remove(ChamsRefreshQueue, Index)
        end
    end
end

local function QueueChamsRefresh(Data, Force)
    if not Data or not Data['Character'] then
        return
    end

    if ChamsRefreshQueued[Data] then
        return
    end

    ChamsRefreshQueued[Data] = true
    ChamsRefreshQueue[#ChamsRefreshQueue + 1] = Data
end

local function ProcessChamsRefreshQueue(Limit)
    local Processed = 0

    while Processed < Limit and #ChamsRefreshQueue > 0 do
        local Data = Remove(ChamsRefreshQueue, 1)
        ChamsRefreshQueued[Data] = nil

        if Data['Character'] and Data['Character'].Parent then
            local Player = Data['Player']
            local ShouldShow = Table['Enabled']
                and Table['Chams']['Enabled']
                and Data['Alive']
                and Data['RootPart'] ~= nil
                and Player ~= nil
                and Player ~= LocalPlayer
                and FighterBridge.IsEnemyPlayer(Player, Data)

            if ShouldShow and Data['RootPart'] then
                local Distance = Floor((CameraPosition - Data['RootPart'].Position).Magnitude)

                if Distance > Table['Distance'] then
                    ShouldShow = false
                end
            end

            if ShouldShow then
                EspLibrary:SetupChams(Data, Data['Character'])
                Data['LastChamsRefresh'] = os.clock()
            else
                EspLibrary:RemoveChams(Data)
            end
        end

        Processed += 1
    end
end

pcall(function()
    setfflag('AdornShadingAPI', 'true')
end)

local InstanceNew, CFrameNew, Vec3 = Instance.new, CFrame.new, Vector3.new

local function RemoveAdorns(Part)
    if not Part then
        return
    end

    local Children = Part:GetChildren()

    for i = 1, #Children do
        local Obj = Children[i]
        local Name = Obj.Name

        if Name == 'Chams' or Name == 'Glow' or Name == 'ChamsFill' or Name == 'ChamsGlow' then
            Obj:Destroy()
        end
    end
end

local function ClearCharacterAdorns(Character)
    if not Character then
        return
    end

    for _, Part in ipairs(Character:GetChildren()) do
        if Part:IsA('BasePart') then
            RemoveAdorns(Part)
        end
    end
end

local function CreateAdornment(Part, Type, Color, Trans, ZIndex, SizeOffset, Extra)
    Extra = Extra or {}

    local Ad

    if Type == 'Cylinder' then
        Ad = InstanceNew('CylinderHandleAdornment')
        Ad.Height = Part.Size.Y + (Extra.HeightOffset or 0)
        Ad.Radius = (Part.Size.X * 0.5) + (Extra.RadiusOffset or 0)
        Ad.CFrame = CFrameNew(Vec3(), Vec3(0, 1, 0))
    else
        Ad = InstanceNew('BoxHandleAdornment')
        Ad.Size = Part.Size + (SizeOffset or Vec3(0, 0, 0))
    end

    Ad.Name = Extra.Name or 'Chams'
    Ad.AlwaysOnTop = true
    Ad.ZIndex = ZIndex
    Ad.Adornee = Part
    Ad.Color3 = Color
    Ad.Transparency = Trans or 0

    if Extra.Shading then
        pcall(function()
            Ad.Shading = Extra.Shading
        end)
    end

    Ad.Parent = Part
    return Ad
end

local function GetAnimatedChamsColors(Cfg)
    local Main = Cfg.Color1 or Cfg.Main or Color3.new(1, 0, 0)
    local Glow = Cfg.Color2 or Cfg.Glow or Color3.new(1, 1, 1)
    local Mode = Cfg.Mode or 'None'

    if not Cfg.Animate or Mode == 'None' then
        return Main, Glow
    end

    if Mode == 'PingPong' then
        local Phase = GetPingPongPhase(Cfg)
        return Main:Lerp(Glow, Phase), Glow:Lerp(Main, Phase)
    end

    if Mode == 'Pulse' then
        local Phase = (math.sin(GetGradientTime(Cfg) * math.pi * 2) + 1) * 0.5
        return Main:Lerp(Glow, Phase), Glow
    end

    if Mode == 'Rainbow' then
        local Hue = GetScrollPhase(Cfg)
        return Color3.fromHSV(Hue, 1, 1), Color3.fromHSV((Hue + 0.5) % 1, 0.85, 1)
    end

    -- Scroll: shift blend over time
    local Phase = GetScrollPhase(Cfg)
    return Main:Lerp(Glow, Phase), Glow:Lerp(Main, Phase)
end

local function SetAdornChamsColors(Character, MainColor, GlowColor, FillTrans, GlowTrans, GlowStrength)
    if not Character then
        return
    end

    local Strength = Clamp(tonumber(GlowStrength) or 5, 0.5, 15)
    local GlowBoost = Color3.new(
        math.min(GlowColor.R * Strength, 5),
        math.min(GlowColor.G * Strength, 5),
        math.min(GlowColor.B * Strength, 5)
    )
    if FillTrans == nil then FillTrans = 0.5 end
    if GlowTrans == nil then GlowTrans = -1 end

    for _, Part in ipairs(Character:GetChildren()) do
        if Part:IsA('BasePart') then
            local Children = Part:GetChildren()

            for i = 1, #Children do
                local Obj = Children[i]

                if Obj.Name == 'ChamsFill' then
                    Obj.Color3 = MainColor
                    Obj.Transparency = FillTrans
                elseif Obj.Name == 'ChamsGlow' then
                    Obj.Color3 = GlowBoost
                    Obj.Transparency = GlowTrans
                end
            end
        end
    end
end

local function ResolveGlowTransparency(GlowOpacityOrTrans)
    -- Accept opacity 0-1 (preferred) or legacy transparency
    local t = GlowOpacityOrTrans
    if t == nil then
        return -1
    end
    -- If value looks like opacity passed as 1-transparency from UI Opacity slider,
    -- callers pass Transparency already.
    if t <= 0.001 then
        return -1 -- fully visible XRay style
    end
    return Clamp(t, 0, 1)
end

local function ApplyAdornChamsToCharacter(Character, MainColor, GlowColor, Trans, GlowEnabled, GlowTrans, GlowStrength, GlowSize)
    if not Character then
        return
    end

    MainColor = MainColor or Color3.new(1, 0, 0)
    GlowColor = GlowColor or Color3.new(1, 1, 1)
    Trans = Trans or 0.5
    if GlowEnabled == nil then
        GlowEnabled = true
    end
    GlowTrans = ResolveGlowTransparency(GlowTrans)

    local Strength = Clamp(tonumber(GlowStrength) or 5, 0.5, 15)
    local SizePad = Clamp(tonumber(GlowSize) or 0.03, 0.005, 0.12)
    local GlowBoost = Color3.new(
        math.min(GlowColor.R * Strength, 5),
        math.min(GlowColor.G * Strength, 5),
        math.min(GlowColor.B * Strength, 5)
    )
    local GlowPad = Vec3(SizePad, SizePad, SizePad)
    local FillPad = Vec3(SizePad * 0.65, SizePad * 0.65, SizePad * 0.65)

    local XRayShading = nil
    pcall(function()
        XRayShading = Enum.AdornShading.XRayShaded
    end)

    for _, Part in ipairs(Character:GetChildren()) do
        if not Part:IsA('BasePart') or Part.Transparency >= 1 then
            continue
        end

        RemoveAdorns(Part)

        local IsHead = Part.Name == 'Head' or Part.Name == 'FakeHead'
        local Type = IsHead and 'Cylinder' or 'Box'

        if GlowEnabled then
            CreateAdornment(
                Part,
                Type,
                GlowBoost,
                GlowTrans,
                IsHead and 10 or 9,
                GlowPad,
                { Shading = XRayShading, Name = 'ChamsGlow' }
            )
        end

        CreateAdornment(
            Part,
            Type,
            MainColor,
            Trans,
            10,
            FillPad,
            { Name = 'ChamsFill' }
        )
    end
end

function EspLibrary:RemoveChams(Data)
    if not Data then
        return
    end

    DequeueChamsRefresh(Data)

    local ChamsData = Data['Chams']

    if ChamsData then
        if ChamsData.LOS then
            pcall(function()
                ChamsData.LOS:Destroy()
            end)
        end

        if ChamsData.OCC then
            pcall(function()
                ChamsData.OCC:Destroy()
            end)
        end

        if ChamsData.Model then
            pcall(function()
                ChamsData.Model:Destroy()
            end)
        end
    end

    ClearCharacterAdorns(Data['Character'])
    Data['Chams'] = nil
    Data['LastChamsRefresh'] = nil
end

function EspLibrary:SetupChams(Data, Character)
    self:RemoveChams(Data)

    if not Character or not Character.Parent then
        return
    end

    if not Table['Enabled'] or not Table['Chams']['Enabled'] then
        return
    end

    local Player = Data and Data['Player']

    -- Never cham teammates / local player
    if not Player or Player == LocalPlayer or not FighterBridge.IsEnemyPlayer(Player, Data) then
        return
    end

    local Config = Table['Chams']
    local GlowEnabled = Config.GlowEnabled ~= false
    local MainColor, GlowColor = GetAnimatedChamsColors(Config)
    local FillTrans = Config.Transparency or 0.5
    local GlowTrans = ResolveGlowTransparency(Config.GlowTransparency)
    local GlowStrength = Config.GlowStrength or 5
    local GlowSize = Config.GlowSize or 0.03
    ApplyAdornChamsToCharacter(
        Character,
        MainColor,
        GlowColor,
        FillTrans,
        GlowEnabled,
        GlowTrans,
        GlowStrength,
        GlowSize
    )

    Data['Chams'] = {
        Adorn = true,
        Character = Character,
        GlowEnabled = GlowEnabled,
        FillTrans = FillTrans,
        GlowTrans = GlowTrans,
        GlowStrength = GlowStrength,
        GlowSize = GlowSize,
    }
    Data['LastChamsRefresh'] = os.clock()
end

function EspLibrary:UpdateChams(Data)
    local Player = Data and Data['Player']
    local ShouldShow = Table['Enabled']
        and Table['Chams']['Enabled']
        and Data['Alive']
        and Data['RootPart'] ~= nil
        and Player ~= nil
        and Player ~= LocalPlayer
        and FighterBridge.IsEnemyPlayer(Player, Data)

    if ShouldShow and Data['RootPart'] then
        local Distance = Floor((CameraPosition - Data['RootPart'].Position).Magnitude)

        if Distance > Table['Distance'] then
            ShouldShow = false
        end
    end

    if not ShouldShow then
        if Data['Chams'] then
            self:RemoveChams(Data)
        else
            ClearCharacterAdorns(Data['Character'])
        end

        return
    end

    local Now = os.clock()
    local ChamsData = Data['Chams']
    local Config = Table['Chams']
    local GlowEnabled = Config.GlowEnabled ~= false
    local FillTrans = Config.Transparency or 0.5
    local GlowTrans = ResolveGlowTransparency(Config.GlowTransparency)
    local GlowStrength = Config.GlowStrength or 5
    local GlowSize = Config.GlowSize or 0.03

    -- Live color animation without rebuilding adornments
    if ChamsData and ChamsData.Character and Config.Animate and Config.Mode and Config.Mode ~= 'None' then
        local MainColor, GlowColor = GetAnimatedChamsColors(Config)
        SetAdornChamsColors(
            ChamsData.Character,
            MainColor,
            GlowColor,
            FillTrans,
            GlowTrans,
            GlowStrength
        )
    end

    if (Now - (Data['LastChamsCheck'] or 0)) >= 0.35 then
        Data['LastChamsCheck'] = Now

        local NeedsRefresh = not ChamsData
            or ChamsData.Character ~= Data['Character']
            or ChamsData.GlowEnabled ~= GlowEnabled
            or ChamsData.FillTrans ~= FillTrans
            or ChamsData.GlowTrans ~= GlowTrans
            or ChamsData.GlowStrength ~= GlowStrength
            or ChamsData.GlowSize ~= GlowSize
            or not Data['LastChamsRefresh']
            or (Now - Data['LastChamsRefresh']) >= CHAMS_REFRESH_INTERVAL

        if NeedsRefresh then
            QueueChamsRefresh(Data, true)
        end
    end
end

function EspLibrary:ClearAllChams()
    for _, Data in pairs(self['Cache']) do
        self:RemoveChams(Data)
    end

    table.clear(ChamsRefreshQueue)

    for Key in pairs(ChamsRefreshQueued) do
        ChamsRefreshQueued[Key] = nil
    end

    -- Sweep any leftover adorns on all characters
    for _, Player in ipairs(Players:GetPlayers()) do
        ClearCharacterAdorns(Player.Character)
    end
end

function EspLibrary:ApplyChamsSettings()
    for _, Data in pairs(self['Cache']) do
        if Table['Enabled'] and Table['Chams']['Enabled'] and Data['Character'] then
            QueueChamsRefresh(Data, true)
        elseif Data['Chams'] or Data['Character'] then
            self:RemoveChams(Data)
        end
    end
end

function EspLibrary:InitEsp(Data, HolderParent)
    local Objects = Data.Objects
    local RootParent = HolderParent or self.Holder

    local function AttachTextGradient(ParentObject, Key)
        Objects[Key .. "Gradient"] = self:CreateObjects("UIGradient", {
            Parent = ParentObject,
            Rotation = 0,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, White),
                ColorSequenceKeypoint.new(1, White),
            }),
            Transparency = NumSeq({NumKey(0, 0), NumKey(1, 0)}),
        })
        ParentObject.TextColor3 = White
    end

    do
        Objects["TargetHolder"] = self:CreateObjects("Frame", {
            Parent = RootParent,
            Visible = false,
            BackgroundTransparency = 1,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(0, 0, 0, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["TopHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["TargetHolder"],
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = true,
            BackgroundTransparency = 1,
            AnchorPoint = NewVector2(0, 1),
            Position = Dim2(0, -2, 0, -5),
            Size = Dim2(1, 4, 0, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["BottomHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["TargetHolder"],
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = true,
            BackgroundTransparency = 1,
            Position = Dim2(0, -2, 1, 0),
            Size = Dim2(1, 4, 0, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["LeftHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["TargetHolder"],
            AutomaticSize = Enum.AutomaticSize.X,
            Visible = true,
            BackgroundTransparency = 1,
            AnchorPoint = NewVector2(1, 0),
            Position = Dim2(0, -5, 0, -2),
            Size = Dim2(0, 0, 1, 4),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["RightHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["TargetHolder"],
            AutomaticSize = Enum.AutomaticSize.X,
            Visible = true,
            BackgroundTransparency = 1,
            Position = Dim2(1, 5, 0, -2),
            Size = Dim2(0, 0, 1, 4),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })
    end

    do
        Objects["TopTextHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["TopHolder"],
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = true,
            BackgroundTransparency = 1,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(1, 0, 0, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["BottomTextHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["BottomHolder"],
            LayoutOrder = 2,
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = true,
            BackgroundTransparency = 1,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(1, 0, 0, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["LeftTextHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["LeftHolder"],
            AutomaticSize = Enum.AutomaticSize.XY,
            Visible = true,
            BackgroundTransparency = 1,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(1, 0, 0, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["RightTextHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["RightHolder"],
            LayoutOrder = 2,
            AutomaticSize = Enum.AutomaticSize.XY,
            Visible = true,
            BackgroundTransparency = 1,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(0, 0, 0, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })
    end

    do
        Objects["LeftBarHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["LeftHolder"],
            AutomaticSize = Enum.AutomaticSize.X,
            Visible = false,
            BackgroundTransparency = 1,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(0, 0, 1, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["BottomBarHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["BottomHolder"],
            LayoutOrder = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = false,
            BackgroundTransparency = 1,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(1, 0, 0, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })
    end

    do
        self:CreateObjects("UIListLayout", {
            Parent = Objects["TopTextHolder"],
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = Dim(0, 1),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["BottomTextHolder"],
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = Dim(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["LeftTextHolder"],
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = Dim(0, 0),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["RightTextHolder"],
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            Padding = Dim(0, 0),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["LeftBarHolder"],
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = Dim(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["BottomBarHolder"],
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Padding = Dim(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["TopHolder"],
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            Padding = Dim(0, 1),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["BottomHolder"],
            Padding = Dim(0, 1),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["LeftHolder"],
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            Padding = Dim(0, 1),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["RightHolder"],
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            Padding = Dim(0, 1),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
    end

    do
        self:CreateObjects("UIPadding", {
            Parent = Objects["TopTextHolder"],
            PaddingBottom = Dim(0, 0),
        })

        self:CreateObjects("UIPadding", {
            Parent = Objects["BottomTextHolder"],
            PaddingTop = Dim(0, 1)
        })

        self:CreateObjects("UIPadding", {
            Parent = Objects["LeftTextHolder"],
            PaddingTop = Dim(0, -3),
        })

        self:CreateObjects("UIPadding", {
            Parent = Objects["RightTextHolder"],
            PaddingTop = Dim(0, -3),
        })

        self:CreateObjects("UIPadding", {
            Parent = Objects["LeftBarHolder"],
            PaddingRight = Dim(0, 0),
        })

        self:CreateObjects("UIPadding", {
            Parent = Objects["BottomBarHolder"],
            PaddingTop = Dim(0, 2),
        })

        self:CreateObjects("UIPadding", {
            Parent = Objects["LeftHolder"],
            PaddingRight = Dim(0, 1),
        })
    end

    do
        Objects["BoxGlow"] = self:CreateObjects("ImageLabel", {
            Parent = Objects["TargetHolder"],
            Image = "rbxassetid://110204605000367",
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(NewVector2(21, 21), NewVector2(79, 79)),
            ImageTransparency = 0.65,
            ResampleMode = Enum.ResamplerMode.Pixelated,
            Visible = true,
            BackgroundTransparency = 1,
            Position = Dim2(0, -BOX_GLOW_PAD_LEFT, 0, -BOX_GLOW_PAD_TOP),
            Size = Dim2(0, 0, 0, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["BoxGlowGradient"] = self:CreateObjects("UIGradient", {
            Parent = Objects["BoxGlow"],
            Rotation = 0,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
            }),
            Transparency = NumSeq({NumKey(0, 0), NumKey(1, 0)}),
        })

        self:CreateObjects("UIPadding", {
            Parent = Objects["BoxGlow"],
            PaddingTop = Dim(0, BOX_GLOW_PAD_TOP),
            PaddingBottom = Dim(0, BOX_GLOW_PAD_BOTTOM),
            PaddingLeft = Dim(0, BOX_GLOW_PAD_LEFT),
            PaddingRight = Dim(0, BOX_GLOW_PAD_RIGHT),
        })

        Objects["BoxOutlineHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["BoxGlow"],
            Visible = false,
            BackgroundTransparency = 1,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(1, 0, 1, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["BoxOutline"] = self:CreateObjects("UIStroke", {
            Parent = Objects["BoxOutlineHolder"],
            Thickness = 3,
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        Objects["BoxOutlineGradient"] = self:CreateObjects("UIGradient", {
            Parent = Objects["BoxOutline"],
            Rotation = 0,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
            }),
            Transparency = NumSeq({NumKey(0, 0), NumKey(1, 0)}),
        })

        Objects["BoxInlineHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["BoxGlow"],
            Visible = false,
            BackgroundTransparency = 1,
            Position = Dim2(0, -1, 0, -1),
            Size = Dim2(1, 2, 1, 2),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["BoxInline"] = self:CreateObjects("UIStroke", {
            Parent = Objects["BoxInlineHolder"],
            Color = Color3.fromRGB(255, 255, 255),
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        Objects["BoxInlineGradient"] = self:CreateObjects("UIGradient", {
            Parent = Objects["BoxInline"],
            Rotation = 0,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
            }),
            Transparency = NumSeq({NumKey(0, 0), NumKey(1, 0)}),
        })

        Objects["BoxFill"] = self:CreateObjects("Frame", {
            Parent = Objects["BoxGlow"],
            Visible = false,
            BackgroundTransparency = 0,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(1, 0, 1, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        Objects["BoxFillGradient"] = self:CreateObjects("UIGradient", {
            Parent = Objects["BoxFill"],
            Rotation = 0,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 0, 0)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
            }),
            Transparency = NumSeq({NumKey(0, 1), NumKey(1, 1)}),
        })

        Objects["CornerHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["BoxGlow"],
            Visible = false,
            BackgroundTransparency = 1,
            Position = Dim2(0, -1, 0, -1),
            Size = Dim2(1, 2, 1, 2),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        })

        -- One connected L per corner (Path2D). Fallback: solid overlapping arms in one Frame.
        local Path2D_Ok = false
        do
            local Ok, Inst = pcall(Instance.new, "Path2D")
            if Ok and Inst then
                Path2D_Ok = true
                Inst:Destroy()
            end
        end

        for i = 1, 4 do
            if Path2D_Ok then
                local Outline = Instance.new("Path2D")
                Outline.Name = "CornerOutline_" .. i
                Outline.Thickness = 3
                Outline.Color3 = Color3.fromRGB(0, 0, 0)
                Outline.Visible = false
                Outline.ZIndex = 1
                Outline.Parent = Objects["CornerHolder"]
                Objects["CornerOutline_" .. i] = Outline

                local Path = Instance.new("Path2D")
                Path.Name = "CornerPath_" .. i
                Path.Thickness = 1
                Path.Color3 = White
                Path.Visible = false
                Path.ZIndex = 2
                Path.Parent = Objects["CornerHolder"]
                Objects["CornerPath_" .. i] = Path
            else
                local Corner = self:CreateObjects("Frame", {
                    Parent = Objects["CornerHolder"],
                    Visible = false,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Size = Dim2(0.3, 0, 0.3, 0),
                    ZIndex = 2,
                })
                Objects["Corner_" .. i] = Corner

                -- Single visual L: two solid arms that share the corner pixel (no separate strokes)
                Objects["CornerH_" .. i] = self:CreateObjects("Frame", {
                    Parent = Corner,
                    BackgroundTransparency = 0,
                    BorderSizePixel = 0,
                    BackgroundColor3 = White,
                    Size = Dim2(1, 0, 0, 1),
                    Position = Dim2(0, 0, 0, 0),
                    ZIndex = 2,
                })
                Objects["CornerV_" .. i] = self:CreateObjects("Frame", {
                    Parent = Corner,
                    BackgroundTransparency = 0,
                    BorderSizePixel = 0,
                    BackgroundColor3 = White,
                    Size = Dim2(0, 1, 1, 0),
                    Position = Dim2(0, 0, 0, 0),
                    ZIndex = 2,
                })
            end
        end

        Objects["UsePath2DCorners"] = Path2D_Ok

        -- World-space 3D box (SelectionBox)
        Objects["Box3D"] = Instance.new("SelectionBox")
        Objects["Box3D"].Name = "EspBox3D"
        Objects["Box3D"].Color3 = White
        Objects["Box3D"].LineThickness = 0.03
        Objects["Box3D"].SurfaceTransparency = 1
        Objects["Box3D"].Visible = false
        Objects["Box3D"].Adornee = nil
        Objects["Box3D"].Parent = Objects["TargetHolder"]
    end

    do
        Objects["HealthBarOutline"] = self:CreateObjects("Frame", {
            Parent = Objects["LeftBarHolder"],
            ZIndex = 5,
            LayoutOrder = 0,
            Visible = false,
            BackgroundTransparency = 0,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(0, 1, 1, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            ClipsDescendants = false,
        })

        self:CreateObjects("UIStroke", {
            Parent = Objects["HealthBarOutline"],
            Thickness = 1,
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        Objects["HealthBar"] = self:CreateObjects("Frame", {
            Parent = Objects["HealthBarOutline"],
            ZIndex = 6,
            AnchorPoint = NewVector2(0, 1),
            Position = Dim2(0, 0, 1, 0),
            Size = Dim2(1, 0, 1, 0),
            BorderSizePixel = 0,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            ClipsDescendants = true,
        })

        Objects["HealthBarGradient"] = self:CreateObjects("UIGradient", {
            Parent = Objects["HealthBar"],
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Table['Bars']['Health Bar']['Top']),
                ColorSequenceKeypoint.new(0.5, Table['Bars']['Health Bar']['Mid']),
                ColorSequenceKeypoint.new(1, Table['Bars']['Health Bar']['Bot']),
            }),
            Transparency = NumSeq({NumKey(0, 0), NumKey(1, 0)}),
        })

        Objects["HealthBarText"] = self:CreateObjects("TextLabel", {
            Parent = Objects["HealthBarOutline"],
            FontFace = EspLibrary.SmallestPixel,
            TextSize = 9,
            ZIndex = 10,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Text = "",
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            AnchorPoint = NewVector2(0.5, 0.5),
            Position = Dim2(0.5, 0, 1, 0),
            BorderSizePixel = 0,
            Visible = false,
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = Dim2(0, 0, 0, 0),
        })

        self:CreateObjects("UIStroke", {
            Parent = Objects["HealthBarText"],
            Color = Color3.fromRGB(0, 0, 0),
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        AttachTextGradient(Objects["HealthBarText"], "HealthBarText")
    end

    do
        Objects["SkeletonRoot"] = self:CreateObjects("Frame", {
            Parent = RootParent,
            Visible = false,
            BackgroundTransparency = 1,
            Position = Dim2(0, 0, 0, 0),
            Size = Dim2(1, 0, 1, 0),
            BorderSizePixel = 0,
            ZIndex = 1,
        })

        for Index = 1, SKELETON_LINE_COUNT do
            Objects["SkeletonLine_" .. Index] = self:CreateObjects("Frame", {
                Parent = Objects["SkeletonRoot"],
                Visible = false,
                BackgroundTransparency = 0,
                BackgroundColor3 = White,
                BorderSizePixel = 0,
                ZIndex = 2,
            })

            Objects["SkeletonLineGrad_" .. Index] = self:CreateObjects("UIGradient", {
                Parent = Objects["SkeletonLine_" .. Index],
                Rotation = 0,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, White),
                    ColorSequenceKeypoint.new(1, White),
                }),
                Transparency = NumSeq({ NumKey(0, 0), NumKey(1, 0) }),
            })
        end

        Objects["HeadDotLine"] = self:CreateObjects("Frame", {
            Parent = Objects["SkeletonRoot"],
            Visible = false,
            BackgroundTransparency = 0,
            BackgroundColor3 = White,
            BorderSizePixel = 0,
            ZIndex = 3,
        })

        Objects["HeadDot"] = self:CreateObjects("Frame", {
            Parent = Objects["SkeletonRoot"],
            Visible = false,
            BackgroundTransparency = 1,
            BackgroundColor3 = White,
            BorderSizePixel = 0,
            AnchorPoint = NewVector2(0.5, 0.5),
            ZIndex = 4,
        })

        self:CreateObjects("UICorner", {
            Parent = Objects["HeadDot"],
            CornerRadius = UDim.new(1, 0),
        })

        Objects["HeadDotStroke"] = self:CreateObjects("UIStroke", {
            Parent = Objects["HeadDot"],
            Color = White,
            Thickness = 1.5,
            Transparency = 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            LineJoinMode = Enum.LineJoinMode.Round,
        })
    end

    do
        Objects["TargetName"] = self:CreateObjects("TextLabel", {
            Parent = Objects["TopTextHolder"],
            FontFace = EspLibrary.TahomaBold,
            TextSize = 12,
            LayoutOrder = 2,
            TextColor3 = White,
            Text = "",
            TextXAlignment = Enum.TextXAlignment.Center,
            BorderSizePixel = 0,
            Visible = false,
            BackgroundTransparency = 1,
            ZIndex = 5,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = Dim2(0, 0, 0, 0),
        })

        self:CreateObjects("UIStroke", {
            Parent = Objects["TargetName"],
            Color = Color3.fromRGB(0, 0, 0),
            LineJoinMode = Enum.LineJoinMode.Miter,
        })
        AttachTextGradient(Objects["TargetName"], "TargetName")

        Objects["Distance"] = self:CreateObjects("TextLabel", {
            Parent = Objects["BottomTextHolder"],
            FontFace = EspLibrary.SmallestPixel,
            TextSize = 9,
            LayoutOrder = 2,
            TextColor3 = White,
            Text = "",
            TextXAlignment = Enum.TextXAlignment.Center,
            BorderSizePixel = 0,
            Visible = false,
            BackgroundTransparency = 1,
            ZIndex = 5,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = Dim2(0, 0, 0, 0),
        })

        self:CreateObjects("UIStroke", {
            Parent = Objects["Distance"],
            Color = Color3.fromRGB(0, 0, 0),
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        AttachTextGradient(Objects["Distance"], "Distance")

        Objects["AmmoFlag"] = self:CreateObjects("TextLabel", {
            Parent = Objects["RightTextHolder"],
            FontFace = EspLibrary.SmallestPixel,
            TextSize = Table.Bars['Health Bar'].FontSize or 9,
            LayoutOrder = 0,
            TextColor3 = Color3.fromRGB(80, 160, 255),
            Text = "ammo : 0/0",
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            BorderSizePixel = 0,
            Visible = false,
            BackgroundTransparency = 1,
            ZIndex = 5,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = Dim2(0, 0, 0, 0),
        })

        self:CreateObjects("UIStroke", {
            Parent = Objects["AmmoFlag"],
            Color = Color3.fromRGB(0, 0, 0),
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        AttachTextGradient(Objects["AmmoFlag"], "AmmoFlag")

        Objects["WalkFlag"] = self:CreateObjects("TextLabel", {
            Parent = Objects["RightTextHolder"],
            FontFace = EspLibrary.SmallestPixel,
            TextSize = 9,
            LayoutOrder = 1,
            TextColor3 = White,
            Text = GetFlagDisplayText(Table['Flags']['Walking'], DEFAULT_FLAG_LABELS.Walking),
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            Visible = false,
            BackgroundTransparency = 1,
            ZIndex = 5,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = Dim2(0, 0, 0, 0),
        })

        self:CreateObjects("UIStroke", {
            Parent = Objects["WalkFlag"],
            Color = Color3.fromRGB(0, 0, 0),
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        AttachTextGradient(Objects["WalkFlag"], "WalkFlag")

        Objects["JumpFlag"] = self:CreateObjects("TextLabel", {
            Parent = Objects["RightTextHolder"],
            FontFace = EspLibrary.SmallestPixel,
            TextSize = 9,
            LayoutOrder = 2,
            TextColor3 = White,
            Text = GetFlagDisplayText(Table['Flags']['Jumping'], DEFAULT_FLAG_LABELS.Jumping),
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            Visible = false,
            BackgroundTransparency = 1,
            ZIndex = 5,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = Dim2(0, 0, 0, 0),
        })

        self:CreateObjects("UIStroke", {
            Parent = Objects["JumpFlag"],
            Color = Color3.fromRGB(0, 0, 0),
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        AttachTextGradient(Objects["JumpFlag"], "JumpFlag")

        Objects["SwimmingFlag"] = self:CreateObjects("TextLabel", {
            Parent = Objects["RightTextHolder"],
            FontFace = EspLibrary.SmallestPixel,
            TextSize = 9,
            LayoutOrder = 4,
            TextColor3 = White,
            Text = GetFlagDisplayText(Table['Flags']['Swimming'], DEFAULT_FLAG_LABELS.Swimming),
            TextXAlignment = Enum.TextXAlignment.Left,
            BorderSizePixel = 0,
            Visible = false,
            BackgroundTransparency = 1,
            ZIndex = 5,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = Dim2(0, 0, 0, 0),
        })

        self:CreateObjects("UIStroke", {
            Parent = Objects["SwimmingFlag"],
            Color = Color3.fromRGB(0, 0, 0),
            LineJoinMode = Enum.LineJoinMode.Miter,
        })

        AttachTextGradient(Objects["SwimmingFlag"], "SwimmingFlag")

        Objects["WeaponStack"] = self:CreateObjects("Frame", {
            Parent = Objects["BottomTextHolder"],
            LayoutOrder = 3,
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = false,
            BackgroundTransparency = 1,
            Size = Dim2(1, 0, 0, 0),
            BorderSizePixel = 0,
        })

        self:CreateObjects("UIListLayout", {
            Parent = Objects["WeaponStack"],
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Top,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = Dim(0, 1),
        })

        Objects["WeaponIconHolder"] = self:CreateObjects("Frame", {
            Parent = Objects["WeaponStack"],
            LayoutOrder = 1,
            Visible = false,
            BackgroundTransparency = 1,
            AnchorPoint = NewVector2(0.5, 0),
            Size = Dim2(0, 28, 0, 14),
            BorderSizePixel = 0,
        })

        Objects["WeaponIconShadow"] = self:CreateObjects("ImageLabel", {
            Parent = Objects["WeaponIconHolder"],
            BackgroundTransparency = 1,
            AnchorPoint = NewVector2(0.5, 0.5),
            Position = Dim2(0.5, 1, 0.5, 2),
            Size = Dim2(1, 0, 1, 0),
            Image = "",
            ImageColor3 = Color3.fromRGB(0, 0, 0),
            ImageTransparency = 0.35,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 4,
            Visible = true,
            BorderSizePixel = 0,
        })

        Objects["WeaponIcon"] = self:CreateObjects("ImageLabel", {
            Parent = Objects["WeaponIconHolder"],
            BackgroundTransparency = 1,
            AnchorPoint = NewVector2(0.5, 0.5),
            Position = Dim2(0.5, 0, 0.5, 0),
            Size = Dim2(1, 0, 1, 0),
            Image = "",
            ImageColor3 = White,
            ImageTransparency = 0,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 5,
            Visible = true,
            BorderSizePixel = 0,
        })

        Objects["Weapon"] = self:CreateObjects("TextLabel", {
            Parent = Objects["WeaponStack"],
            FontFace = EspLibrary.SmallestPixel,
            TextSize = 9,
            LayoutOrder = 2,
            TextColor3 = White,
            Text = "none",
            TextXAlignment = Enum.TextXAlignment.Center,
            BorderSizePixel = 0,
            Visible = false,
            BackgroundTransparency = 1,
            ZIndex = 5,
            AutomaticSize = Enum.AutomaticSize.XY,
            Size = Dim2(0, 0, 0, 0),
        })

        self:CreateObjects("UIStroke", {
            Parent = Objects["Weapon"],
            Color = Color3.fromRGB(0, 0, 0),
            LineJoinMode = Enum.LineJoinMode.Miter,
        })
        AttachTextGradient(Objects["Weapon"], "Weapon")
    end

    self:ApplyFontToObjects(Objects)
end

-- Sharp L corners as one polyline each (scale relative to CornerHolder)
local Zero_Tangent = UDim2.new(0, 0, 0, 0)
local function Corner_Point(X_Scale, X_Off, Y_Scale, Y_Off)
    local Pos = UDim2.new(X_Scale, X_Off, Y_Scale, Y_Off)
    if typeof(Path2DControlPoint) == 'function' or (type(Path2DControlPoint) == 'table' and Path2DControlPoint.new) then
        return Path2DControlPoint.new(Pos, Zero_Tangent, Zero_Tangent)
    end
    return Pos
end

local function Build_Corner_Points(Index, Arm)
    Arm = Arm or 0.28
    if Index == 1 then -- top-left ┌
        return {
            Corner_Point(0, 0, Arm, 0),
            Corner_Point(0, 0, 0, 0),
            Corner_Point(Arm, 0, 0, 0),
        }
    elseif Index == 2 then -- top-right ┐
        return {
            Corner_Point(1 - Arm, 0, 0, 0),
            Corner_Point(1, 0, 0, 0),
            Corner_Point(1, 0, Arm, 0),
        }
    elseif Index == 3 then -- bottom-left └
        return {
            Corner_Point(0, 0, 1 - Arm, 0),
            Corner_Point(0, 0, 1, 0),
            Corner_Point(Arm, 0, 1, 0),
        }
    end
    -- bottom-right ┘
    return {
        Corner_Point(1 - Arm, 0, 1, 0),
        Corner_Point(1, 0, 1, 0),
        Corner_Point(1, 0, 1 - Arm, 0),
    }
end

-- Frame fallback: one L unit per corner (arms share the corner, no outline strokes)
local CornerFrameLayout = {
    { -- TL
        Pos = Dim2(0, 0, 0, 0), Anchor = NewVector2(0, 0),
        H = Dim2(1, 0, 0, 1), HP = Dim2(0, 0, 0, 0), HA = NewVector2(0, 0),
        V = Dim2(0, 1, 1, 0), VP = Dim2(0, 0, 0, 0), VA = NewVector2(0, 0),
    },
    { -- TR
        Pos = Dim2(1, 0, 0, 0), Anchor = NewVector2(1, 0),
        H = Dim2(1, 0, 0, 1), HP = Dim2(0, 0, 0, 0), HA = NewVector2(0, 0),
        V = Dim2(0, 1, 1, 0), VP = Dim2(1, 0, 0, 0), VA = NewVector2(1, 0),
    },
    { -- BL
        Pos = Dim2(0, 0, 1, 0), Anchor = NewVector2(0, 1),
        H = Dim2(1, 0, 0, 1), HP = Dim2(0, 0, 1, 0), HA = NewVector2(0, 1),
        V = Dim2(0, 1, 1, 0), VP = Dim2(0, 0, 0, 0), VA = NewVector2(0, 0),
    },
    { -- BR
        Pos = Dim2(1, 0, 1, 0), Anchor = NewVector2(1, 1),
        H = Dim2(1, 0, 0, 1), HP = Dim2(0, 0, 1, 0), HA = NewVector2(0, 1),
        V = Dim2(0, 1, 1, 0), VP = Dim2(1, 0, 0, 0), VA = NewVector2(1, 0),
    },
}

local function Hide_Corner_Objects(Objects)
    if Objects['UsePath2DCorners'] then
        for i = 1, 4 do
            local Path = Objects['CornerPath_' .. i]
            local Outline = Objects['CornerOutline_' .. i]
            if Path and Path.Visible then
                Path.Visible = false
            end
            if Outline and Outline.Visible then
                Outline.Visible = false
            end
        end
    else
        for i = 1, 4 do
            local Corner = Objects['Corner_' .. i]
            if Corner and Corner.Visible then
                Corner.Visible = false
            end
        end
    end
end

function EspLibrary:CalculateBox(Data, ViewportCamera, ViewportFrame)
    local Cam = ViewportCamera or GetCamera()

    if not Cam then
        return nil, nil, nil, nil, false
    end

    local VpY = ViewportFrame and ViewportFrame.AbsoluteSize.Y or Cam.ViewportSize.Y

    if VpY < 2 then
        return nil, nil, nil, nil, false
    end

    local BoundingBox = Table['Boxes']['Bounding Box']
    local RootPart = Data['RootPart']

    if not RootPart then
        return nil, nil, nil, nil, false
    end

    -- Preview keeps the heavier path for the menu character model
    if Data['IsPreview'] and ViewportFrame and Data['Character'] then
        local Children = Data['Children']
        local IncludeAccessories = Data['IncludeAccessories']
        local ScrMinX2, ScrMinY2 = Huge, Huge
        local ScrMaxX2, ScrMaxY2 = -Huge, -Huge
        local HasValidParts = false

        if Children then
            for _, Part in ipairs(Children) do
                if Part:IsA('BasePart') and Part.Transparency ~= 1 and Part ~= RootPart then
                    local Parent = Part.Parent

                    if Parent and (IncludeAccessories or not Parent:IsA('Accessory')) then
                        local Pos = Part.Position
                        local HalfY = Part.Size.Y * 0.5
                        local HalfX = Part.Size.X * 0.5
                        local Right = Cam.CFrame.RightVector
                        local Up = Cam.CFrame.UpVector
                        local SamplePoints = {
                            Pos,
                            Pos + Up * HalfY,
                            Pos - Up * HalfY,
                            Pos + Right * HalfX,
                            Pos - Right * HalfX,
                        }

                        for _, WorldPos in ipairs(SamplePoints) do
                            local PartScreen, PartOnScreen = GetScreenPoint(Cam, WorldPos, ViewportFrame)

                            if PartOnScreen and PartScreen and PartScreen.Z > 0 then
                                HasValidParts = true
                                if PartScreen.X < ScrMinX2 then ScrMinX2 = PartScreen.X end
                                if PartScreen.X > ScrMaxX2 then ScrMaxX2 = PartScreen.X end
                                if PartScreen.Y < ScrMinY2 then ScrMinY2 = PartScreen.Y end
                                if PartScreen.Y > ScrMaxY2 then ScrMaxY2 = PartScreen.Y end
                            end
                        end
                    end
                end
            end
        end

        if HasValidParts then
            local PadX = BoundingBox['BoxX']
            local PadY = BoundingBox['BoxY']
            local W = (ScrMaxX2 - ScrMinX2) + PadX
            local H = (ScrMaxY2 - ScrMinY2) + PadY

            return W, H, ScrMinX2 - (PadX * 0.5), ScrMinY2 - (PadY * 0.5), true
        end

        local VpW = ViewportFrame.AbsoluteSize.X
        local VpH = ViewportFrame.AbsoluteSize.Y
        local W = VpW * 0.52
        local H = VpH * 0.82

        return W, H, (VpW - W) * 0.5, (VpH - H) * 0.5, true
    end

    -- Fast landmark box: locked to head/torso/limbs every frame (smooth, no lag)
    if Table['Boxes']['DynamicBoxes'] then
        local Character = Data['Character']

        if not Character then
            return nil, nil, nil, nil, false
        end

        local Right = Cam.CFrame.RightVector
        local Up = Cam.CFrame.UpVector
        local ScrMinX, ScrMinY = Huge, Huge
        local ScrMaxX, ScrMaxY = -Huge, -Huge
        local HasValidParts = false

        local function expandPart(Part)
            if not Part or not Part:IsA('BasePart') or Part.Transparency >= 1 then
                return
            end

            local Pos = Part.Position
            local HalfX = Part.Size.X * 0.5
            local HalfY = Part.Size.Y * 0.5
            local SamplePoints = {
                Pos,
                Pos + Up * HalfY,
                Pos - Up * HalfY,
                Pos + Right * HalfX,
                Pos - Right * HalfX,
            }

            for i = 1, #SamplePoints do
                local PartScreen, PartOnScreen = GetScreenPoint(Cam, SamplePoints[i], ViewportFrame)

                if PartOnScreen and PartScreen and PartScreen.Z > 0 then
                    HasValidParts = true
                    if PartScreen.X < ScrMinX then ScrMinX = PartScreen.X end
                    if PartScreen.X > ScrMaxX then ScrMaxX = PartScreen.X end
                    if PartScreen.Y < ScrMinY then ScrMinY = PartScreen.Y end
                    if PartScreen.Y > ScrMaxY then ScrMaxY = PartScreen.Y end
                end
            end
        end

        expandPart(Character:FindFirstChild('Head'))
        expandPart(RootPart)
        expandPart(Character:FindFirstChild('UpperTorso') or Character:FindFirstChild('Torso'))
        expandPart(Character:FindFirstChild('LeftHand') or Character:FindFirstChild('Left Arm'))
        expandPart(Character:FindFirstChild('RightHand') or Character:FindFirstChild('Right Arm'))
        expandPart(Character:FindFirstChild('LeftFoot') or Character:FindFirstChild('Left Leg'))
        expandPart(Character:FindFirstChild('RightFoot') or Character:FindFirstChild('Right Leg'))
        expandPart(Character:FindFirstChild('LowerTorso'))

        if not HasValidParts then
            return nil, nil, nil, nil, false
        end

        local PadX = BoundingBox['BoxX']
        local PadY = BoundingBox['BoxY']
        local W = (ScrMaxX - ScrMinX) + PadX
        local H = (ScrMaxY - ScrMinY) + PadY

        return W, H, ScrMinX - (PadX * 0.5), ScrMinY - (PadY * 0.5), true
    end

    local RootScreen, OnScreen = GetScreenPoint(Cam, RootPart.Position, ViewportFrame)

    if not OnScreen then
        return nil, nil, nil, nil, false
    end

    local Scale = (RootPart.Size.Y * VpY) / (RootScreen.Z * 2)
    local W, H = 3 * Scale, 4.5 * Scale

    return W, H, RootScreen.X - (W * 0.5), RootScreen.Y - (H * 0.5), OnScreen
end

function EspLibrary:AddTarget(Player)
    if Player == LocalPlayer and not Table['ShowLocalPlayer'] then
        return
    end;

    if self.Cache[Player] then
        return
    end;

    self:EnsureHolder()

    local Data = {
        ['Player'] = Player,
        ['Objects'] = {},
        ['Conns'] = {},
        ['Character'] = nil,
        ['RootPart'] = nil,
        ['Humanoid'] = nil,
        ['Children'] = nil,
        ['Health'] = 0,
        ['MaxHealth'] = 100,
        ['CurrentTool'] = nil,
        ['ClientFighter'] = nil,
        ['Alive'] = false,
        ['LastW'] = nil,
        ['LastH'] = nil,
        ['LastX'] = nil,
        ['LastY'] = nil,
        ['WalkActive'] = false,
        ['JumpActive'] = false,
        ['FallingActive'] = false,
        ['SwimmingActive'] = false,
        ['IncludeAccessories'] = Table['Boxes']['Bounding Box']['IncludeAcsessories'],
        ['LastGlowTop'] = nil,
        ['LastGlowBot'] = nil,
        ['LastGlowT1'] = nil,
        ['LastGlowT2'] = nil,
        ['LastGradTop'] = nil,
        ['LastGradBot'] = nil,
        ['LastFillTop'] = nil,
        ['LastFillBot'] = nil,
        ['LastFillT1'] = nil,
        ['LastFillT2'] = nil,
        ['LastDist'] = nil,
        ['LastDistColor'] = nil,
        ['LastDisplayName'] = nil,
        ['LastNameColor'] = nil,
        ['LastHealthTop'] = nil,
        ['LastHealthMid'] = nil,
        ['LastHealthBot'] = nil,
        ['LastHealthFloor'] = nil,
        ['LastRatio'] = nil,
        ['DisplayHealthRatio'] = 1,
        ['LastBarUpdate'] = os.clock(),
        ['LastWeapon'] = nil,
    }
    self:InitEsp(Data);
    self['Cache'][Player] = Data;

    local HealthHandler = {}; do
        function HealthHandler.BindHealth(Humanoid)
            if Data['Conns']['Health'] then
                Data['Conns']['Health']:Disconnect()
            end

            if Data['Conns']['Died'] then
                Data['Conns']['Died']:Disconnect()
            end

            Data['Humanoid'] = Humanoid
            Data['Health'] = Humanoid.Health
            Data['MaxHealth'] = Humanoid.MaxHealth
            Data['Alive'] = Humanoid.Health > 0
            Data['DisplayHealthRatio'] = Clamp(Humanoid.Health / math.max(Humanoid.MaxHealth, 1), 0, 1)
            Data['LastBarUpdate'] = os.clock()

            Data['Conns']['Health'] = Humanoid.HealthChanged:Connect(function(NewHealth)
                Data['Alive'] = NewHealth > 0
                Data['Health'] = NewHealth
            end)

            Data['Conns']['Died'] = Humanoid.Died:Connect(function()
                Data['Alive'] = false
                Data['Health'] = 0
            end)
        end

        Data['BindHealth'] = HealthHandler.BindHealth;
    end

    local ChildHandler = {}; do
        function ChildHandler.BindChildren(Character)
            if Data['Conns']['ChildAdded'] then
                Data['Conns']['ChildAdded']:Disconnect();
            end;

            if Data['Conns']['ChildRemoved'] then
                Data['Conns']['ChildRemoved']:Disconnect();
            end;

            local Children = Character:GetChildren();
            Data['Children'] = Children;

            Data['Conns']['ChildAdded'] = Character.ChildAdded:Connect(function(Child)
                Children[#Children + 1] = Child;
            end)

            Data['Conns']['ChildRemoved'] = Character.ChildRemoved:Connect(function(Child)
                for I = #Children, 1, -1 do
                    if Children[I] == Child then
                        Remove(Children, I);
                        break;
                    end;
                end
            end)

        end

        Data['BindChildren'] = ChildHandler.BindChildren;
    end

    local FlagsHandler = {}; do
        function FlagsHandler.BindFlags(Humanoid)
            if Data['Conns']['MoveDir'] then
                Data['Conns']['MoveDir']:Disconnect();
            end;

            if Data['Conns']['StateChange'] then
                Data['Conns']['StateChange']:Disconnect();
            end;

            local Objects = Data['Objects']
            Data['JumpActive'] = false;
            Data['WalkActive'] = false;
            Data['FallingActive'] = false;
            Data['SwimmingActive'] = false;

            Objects['WalkFlag'].Visible = false;
            Objects['JumpFlag'].Visible = false;
            Objects['SwimmingFlag'].Visible = false;

            local FlagsEnabled = Table['Flags']['Enabled']

            Data['Conns']['MoveDir'] = Humanoid:GetPropertyChangedSignal('MoveDirection'):Connect(function()
                local Walking = Humanoid.MoveDirection ~= ZeroVector3;

                if Walking and not Data['WalkActive'] then
                    Data['WalkActive'] = true;

                    if Data['JumpActive'] then
                        Objects['WalkFlag'].LayoutOrder = 2;
                    else
                        Objects['WalkFlag'].LayoutOrder = 1;
                        Objects['JumpFlag'].LayoutOrder = 2;
                    end

                    Objects['WalkFlag'].Visible = FlagsEnabled
                elseif not Walking and Data['WalkActive'] then
                    Data['WalkActive'] = false;
                    Objects['WalkFlag'].Visible = false;

                    if Data['JumpActive'] then
                        Objects['JumpFlag'].LayoutOrder = 1;
                    end
                end
            end)

            Data['Conns']['StateChange'] = Humanoid.StateChanged:Connect(function(_, NewState)
                if NewState == Enum.HumanoidStateType.Freefall and not Data['JumpActive'] then
                    Data['JumpActive'] = true;

                    if Data['WalkActive'] then
                        Objects['JumpFlag'].LayoutOrder = 2;
                    else
                        Objects['JumpFlag'].LayoutOrder = 1;
                        Objects['WalkFlag'].LayoutOrder = 2;
                    end

                    Objects['JumpFlag'].Visible = FlagsEnabled
                elseif NewState ~= Enum.HumanoidStateType.Jumping and Data['JumpActive'] then
                    Data['JumpActive'] = false;
                    Objects['JumpFlag'].Visible = false;

                    if Data['WalkActive'] then
                        Objects['WalkFlag'].LayoutOrder = 1;
                    end
                end

                if NewState == Enum.HumanoidStateType.Swimming and not Data['SwimmingActive'] then
                    Data['SwimmingActive'] = true;
                    Objects['SwimmingFlag'].Visible = FlagsEnabled
                elseif NewState ~= Enum.HumanoidStateType.Swimming and Data['SwimmingActive'] then
                    Data['SwimmingActive'] = false;
                    Objects['SwimmingFlag'].Visible = false;
                end
            end)
        end

        Data['BindFlags'] = FlagsHandler.BindFlags;
    end

    local CharacterHandler = {}; do
        function CharacterHandler.OnCharacter(Character)
            EspLibrary:RemoveChams(Data);

            Data['Character'] = Character;
            Data['RootPart'] = nil;
            Data['Humanoid'] = nil;
            Data['Children'] = nil;
            Data['ClientFighter'] = nil;
            Data['CurrentTool'] = nil;
            FighterBridge.ClearPlayerCache(Data);
            Data['Alive'] = false;
            Data['WalkActive'] = false;
            Data['JumpActive'] = false;
            Data['FallingActive'] = false;
            Data['SwimmingActive'] = false;

            if not Character or not Character.Parent then
                return;
            end;

            local RootPart = FindFirstChild(Character, "HumanoidRootPart");

            if not RootPart then
                RootPart = Character:WaitForChild('HumanoidRootPart', 10);
            end

            local Humanoid = FindFirstChildOfClass(Character, 'Humanoid');

            if not Humanoid then
                Humanoid = Character:WaitForChild('Humanoid', 10);
            end;

            if not RootPart or not Humanoid then
                return;
            end;

            if not Character.Parent then
                return;
            end;

            Data['RootPart'] = RootPart;
            Data['Humanoid'] = Humanoid;

            Data['BindChildren'](Character);
            Data['BindHealth'](Humanoid);
            Data['BindFlags'](Humanoid);
            QueueChamsRefresh(Data, true)
        end

        Data['Conns']['CharAdded'] = Player.CharacterAdded:Connect(function(Character)
            task.defer(CharacterHandler.OnCharacter, Character)
        end)

        if Player.Character and Player.Character.Parent then
            task.defer(CharacterHandler.OnCharacter, Player.Character)
        end
    end
end

function EspLibrary:RemoveTarget(Player)
    local Data = self['Cache'][Player];

    if not Data then
        return;
    end;

    for _, Connections in pairs(Data['Conns']) do
        Connections:Disconnect()
    end;

    Clear(Data['Conns']);

    if Data['Objects']['SkeletonRoot'] then
        Data['Objects']['SkeletonRoot']:Destroy();
    end

    if Data['Objects']['TargetHolder'] then
        Data['Objects']['TargetHolder']:Destroy();
    end;

    self:RemoveChams(Data);

    Clear(Data['Objects']);
    self['Cache'][Player] = nil;
end

function EspLibrary:StepBarRatios(Data, DeltaTime)
    local TargetHealth = 0

    if Data['Alive'] then
        TargetHealth = Clamp((Data['Health'] or 0) / math.max(Data['MaxHealth'] or 100, 1), 0, 1)
    end

    local CurrentHealth = Data['DisplayHealthRatio']

    if CurrentHealth == nil then
        CurrentHealth = TargetHealth
    end

    Data['DisplayHealthRatio'] = LerpBarValue(CurrentHealth, TargetHealth, DeltaTime)

    return Abs(Data['DisplayHealthRatio'] - TargetHealth) > BAR_SNAP_THRESHOLD
end

function EspLibrary:UpdateSkeleton(Player, Data, ViewportCamera, ViewportFrame)
    local Objects = Data['Objects']
    local SkCfg = Table['Skeleton']
    local Root = Objects['SkeletonRoot']
    local HeadDotCfg = SkCfg['HeadDot'] or {}
    local HeadDot = Objects['HeadDot']
    local HeadDotLine = Objects['HeadDotLine']

    local function HideHeadDot()
        if HeadDot and HeadDot.Visible then
            HeadDot.Visible = false
        end

        if HeadDotLine and HeadDotLine.Visible then
            HeadDotLine.Visible = false
        end
    end

    local function HideSkeleton()
        if Root.Visible then
            Root.Visible = false
        end

        for Index = 1, SKELETON_LINE_COUNT do
            local Line = Objects['SkeletonLine_' .. Index]

            if Line.Visible then
                Line.Visible = false
            end
        end

        HideHeadDot()
    end

    if not SkCfg['Enabled'] or not Data['Character'] or not Data['Alive'] or not Data['RootPart'] then
        HideSkeleton()
        return
    end

    if Player ~= LocalPlayer and not FighterBridge.IsEnemyPlayer(Player, Data) then
        HideSkeleton()
        return
    end

    if not ViewportFrame then
        local Distance = Floor((CameraPosition - Data['RootPart'].Position).Magnitude)

        if Distance > Table['Distance'] then
            HideSkeleton()
            return
        end
    end

    local Cam = ViewportCamera or GetCamera()

    if not Cam then
        return
    end

    local Character = Data['Character']
    local Humanoid = Data['Humanoid']
    local BoneLinks = GetSkeletonBoneLinks(Character, Humanoid)
    local Thickness = math.max(Floor((SkCfg['Thickness'] or 1) + 0.5), 1)
    local VisibleLines = 0

    Root.Visible = true

    for Index = 1, SKELETON_LINE_COUNT do
        local Line = Objects['SkeletonLine_' .. Index]
        local Link = BoneLinks[Index]

        if not Link then
            if Line.Visible then
                Line.Visible = false
            end
        else
            local PartA = Character:FindFirstChild(Link[1])
            local PartB = Character:FindFirstChild(Link[2])

            if PartA and PartB then
                local ScreenA, OnA = GetScreenPoint(Cam, PartA.Position, ViewportFrame)
                local ScreenB, OnB = GetScreenPoint(Cam, PartB.Position, ViewportFrame)

                if OnA and OnB and ScreenA and ScreenB and ScreenA.Z > 0 and ScreenB.Z > 0 then
                    if SetPixelLineFrame(Line, ScreenA.X, ScreenA.Y, ScreenB.X, ScreenB.Y, Thickness) then
                        ApplyTwoColorGradient(Objects['SkeletonLineGrad_' .. Index], SkCfg, Line.Rotation)
                        VisibleLines += 1
                    end
                elseif Line.Visible then
                    Line.Visible = false
                end
            elseif Line.Visible then
                Line.Visible = false
            end
        end
    end

    -- Head circle (scaled to projected head size) + collar connection
    if HeadDotCfg['Enabled'] and HeadDot and HeadDotLine then
        local Head = Character:FindFirstChild('Head')
        local Collar = Character:FindFirstChild('UpperTorso') or Character:FindFirstChild('Torso')
        local DotColor = HeadDotCfg['Color'] or White

        if Head and Collar then
            local ScreenHead, OnHead = GetScreenPoint(Cam, Head.Position, ViewportFrame)
            local ScreenCollar, OnCollar = GetScreenPoint(Cam, Collar.Position, ViewportFrame)

            if OnHead and OnCollar and ScreenHead and ScreenCollar and ScreenHead.Z > 0 and ScreenCollar.Z > 0 then
                -- Project head radius into screen space so the circle matches full head size
                local HeadRadius = math.max(Head.Size.X, Head.Size.Y, Head.Size.Z) * 0.5
                local EdgeWorld = Head.Position + Cam.CFrame.RightVector * HeadRadius
                local ScreenEdge, OnEdge = GetScreenPoint(Cam, EdgeWorld, ViewportFrame)

                local Diameter
                if OnEdge and ScreenEdge and ScreenEdge.Z > 0 then
                    local DX = ScreenEdge.X - ScreenHead.X
                    local DY = ScreenEdge.Y - ScreenHead.Y
                    local RadiusPx = math.sqrt(DX * DX + DY * DY)
                    Diameter = math.max(Floor(RadiusPx * 2 + 0.5), 2)
                else
                    -- Fallback: approximate from depth / FOV when edge projection fails
                    local Depth = math.max(ScreenHead.Z, 0.1)
                    local ViewportH = (ViewportFrame and ViewportFrame.AbsoluteSize.Y) or Cam.ViewportSize.Y
                    local Focal = ViewportH / (2 * math.tan(math.rad(Cam.FieldOfView * 0.5)))
                    Diameter = math.max(Floor((HeadRadius * 2 / Depth) * Focal + 0.5), 2)
                end

                -- Connect collar line to the bottom edge of the head circle (not through the center)
                local RadiusPx = Diameter * 0.5
                local CircleBottomX = ScreenHead.X
                local CircleBottomY = ScreenHead.Y + RadiusPx
                if SetPixelLineFrame(HeadDotLine, CircleBottomX, CircleBottomY, ScreenCollar.X, ScreenCollar.Y, Thickness) then
                    HeadDotLine.BackgroundColor3 = DotColor
                end

                HeadDot.Size = DimOffset(Diameter, Diameter)
                HeadDot.Position = DimOffset(Floor(ScreenHead.X + 0.5), Floor(ScreenHead.Y + 0.5))
                HeadDot.BackgroundTransparency = 1
                if Objects['HeadDotStroke'] then
                    Objects['HeadDotStroke'].Color = DotColor
                    local StrokeThickness = math.clamp(Diameter * 0.06, 1.25, 2.5)
                    Objects['HeadDotStroke'].Thickness = StrokeThickness
                end
                HeadDot.Visible = true
                VisibleLines += 1
            else
                HideHeadDot()
            end
        else
            HideHeadDot()
        end
    else
        HideHeadDot()
    end

    if VisibleLines == 0 and Root.Visible then
        Root.Visible = false
    end
end

function EspLibrary:Update(Player, Data, ViewportCamera, ViewportFrame)
    local Objects = Data['Objects']

    if not Data['RootPart'] then
        if Objects['TargetHolder'].Visible then
            Objects['TargetHolder'].Visible = false
        end

        self:UpdateSkeleton(Player, Data, ViewportCamera, ViewportFrame)
        return
    end

    if Player ~= LocalPlayer and not FighterBridge.IsEnemyPlayer(Player, Data) then
        if Objects['TargetHolder'].Visible then
            Objects['TargetHolder'].Visible = false
        end

        self:UpdateSkeleton(Player, Data, ViewportCamera, ViewportFrame)
        return
    end

    local Now = os.clock()
    local DeltaTime = math.min(Now - (Data['LastBarUpdate'] or Now), 0.1)
    Data['LastBarUpdate'] = Now
    local BarsSettling = self:StepBarRatios(Data, DeltaTime)

    if not Data['Alive'] and not BarsSettling then
        if Objects['TargetHolder'].Visible then
            Objects['TargetHolder'].Visible = false
        end

        self:UpdateSkeleton(Player, Data, ViewportCamera, ViewportFrame)
        return
    end

    local RootPos = Data['RootPart'].Position
    local Distance = ViewportCamera and 50 or Floor((CameraPosition - RootPos).Magnitude)

    if not ViewportCamera and Distance > Table['Distance'] then
        if Objects['TargetHolder'].Visible then
            Objects['TargetHolder'].Visible = false
        end

        self:UpdateSkeleton(Player, Data, ViewportCamera, ViewportFrame)
        return
    end

    local IsPreview = Data['IsPreview'] == true

    if IsPreview and ViewportFrame then
        local VpSize = ViewportFrame.AbsoluteSize

        if Data['LastVpW'] ~= VpSize.X or Data['LastVpH'] ~= VpSize.Y then
            Data['LastW'] = nil
            Data['LastH'] = nil
            Data['LastX'] = nil
            Data['LastY'] = nil
            Data['LastVpW'] = VpSize.X
            Data['LastVpH'] = VpSize.Y
        end

        local TextsCfgCheck = Table['Texts']
        local FlagsCfgCheck = Table['Flags']
        local HealthCfgCheck = Table['Bars']['Health Bar']
        local SkeletonCfgCheck = Table['Skeleton']
        local BoxesCfgCheck = Table['Boxes']
        local AnyEnabled = BoxesCfgCheck['Enabled']
            or BoxesCfgCheck['Box Glow']['Enabled']
            or BoxesCfgCheck['Filled']['Enabled']
            or SkeletonCfgCheck['Enabled']
            or TextsCfgCheck['Name']['Enabled']
            or TextsCfgCheck['Distance']['Enabled']
            or TextsCfgCheck['Weapon']['Enabled']
            or HealthCfgCheck['Enabled']
            or FlagsCfgCheck['Enabled']

        if not AnyEnabled then
            if Objects['TargetHolder'].Visible then
                Objects['TargetHolder'].Visible = false
            end
            return
        end
    end

    local W, H, X, Y, OnScreen = self:CalculateBox(Data, ViewportCamera, ViewportFrame)

    if IsPreview and ViewportFrame and Data['Character'] and (not OnScreen or not W) then
        local VpW = ViewportFrame.AbsoluteSize.X
        local VpH = ViewportFrame.AbsoluteSize.Y

        if VpW >= 2 and VpH >= 2 then
            W = VpW * 0.52
            H = VpH * 0.82
            X = (VpW - W) * 0.5
            Y = (VpH - H) * 0.5
            OnScreen = true
        end
    end

    if not OnScreen or not W then
        if Objects['TargetHolder'].Visible then
            Objects['TargetHolder'].Visible = false
        end

        self:UpdateSkeleton(Player, Data, ViewportCamera, ViewportFrame)
        return
    end

    -- Sub-pixel lock: no Floor snap so overlays stay glued to enemies
    if not Objects['TargetHolder'].Visible then
        Objects['TargetHolder'].Visible = true
    end

    Objects['TargetHolder'].Position = DimOffset(X, Y)
    Objects['TargetHolder'].Size = DimOffset(W, H)
    Objects['BoxGlow'].Size = DimOffset(W + BOX_GLOW_PAD_X, H + BOX_GLOW_PAD_Y)
    Data['LastX'] = X
    Data['LastY'] = Y
    Data['LastW'] = W
    Data['LastH'] = H

    local BoxesCfg = Table['Boxes']
    local TextsCfg = Table['Texts']
    local BoxesEnabled = BoxesCfg['Enabled']
    local GlowEnabled = BoxesCfg['Enabled'] and BoxesCfg['Box Glow']['Enabled']
    local FillEnabled = BoxesCfg['Enabled'] and BoxesCfg['Filled']['Enabled']

    if IsPreview then
        BoxesEnabled = BoxesCfg['Enabled'] or BoxesCfg['Box Glow']['Enabled'] or BoxesCfg['Filled']['Enabled']
        GlowEnabled = BoxesCfg['Box Glow']['Enabled']
        FillEnabled = BoxesCfg['Filled']['Enabled']
    end

    if GlowEnabled then
        if Objects['BoxGlow'].ImageTransparency ~= 0 then
            Objects['BoxGlow'].ImageTransparency = 0
        end

        local GlowCfg = BoxesCfg['Box Glow']
        local T1 = GlowCfg['Transparency'][1]
        local T2 = GlowCfg['Transparency'][2]

        ApplyTwoColorGradient(Objects['BoxGlowGradient'], GlowCfg, 0, T1, T2)
        SyncGradientTransparency(Objects['BoxGlowGradient'], GlowCfg, T1, T2, 'Glow', Data)
    else
        if Objects['BoxGlow'].ImageTransparency ~= 1 then
            Objects['BoxGlow'].ImageTransparency = 1
        end
    end

    if BoxesEnabled then
        local BoxType = BoxesCfg['Type']

        if BoxType == "3D" then
            if Objects['BoxOutlineHolder'] and Objects['BoxOutlineHolder'].Visible then
                Objects['BoxOutlineHolder'].Visible = false
            end
            if Objects['BoxInlineHolder'] and Objects['BoxInlineHolder'].Visible then
                Objects['BoxInlineHolder'].Visible = false
            end
            if Objects['BoxFill'] and Objects['BoxFill'].Visible then
                Objects['BoxFill'].Visible = false
            end
            if Objects['CornerHolder'] and Objects['CornerHolder'].Visible then
                Objects['CornerHolder'].Visible = false
            end
            Hide_Corner_Objects(Objects)

            local Box3D = Objects['Box3D']
            if Box3D then
                local Char = Data['Character']
                local GradCfg = BoxesCfg['Gradients']
                Box3D.Color3 = (GradCfg and GradCfg.Color1) or White
                Box3D.SurfaceColor3 = (GradCfg and GradCfg.Color2) or White
                Box3D.Adornee = Char
                Box3D.Visible = Char ~= nil
            end
        elseif BoxType == "Corner" then
            if Objects['Box3D'] then
                Objects['Box3D'].Visible = false
                Objects['Box3D'].Adornee = nil
            end
            if Objects['BoxOutlineHolder'].Visible then
                Objects['BoxOutlineHolder'].Visible = false
            end
            if Objects['BoxInlineHolder'].Visible then
                Objects['BoxInlineHolder'].Visible = false
            end
            if Objects['BoxFill'].Visible then
                Objects['BoxFill'].Visible = false
            end

            if not Objects['CornerHolder'].Visible then
                Objects['CornerHolder'].Visible = true
            end

            local GradCfg = BoxesCfg['Gradients']
            local CornerColor = GetCfgColor1(GradCfg, White)
            local Arm = 0.28

            if Objects['UsePath2DCorners'] then
                for i = 1, 4 do
                    local Path = Objects['CornerPath_' .. i]
                    local Outline = Objects['CornerOutline_' .. i]
                    local Points = Build_Corner_Points(i, Arm)
                    if Outline then
                        pcall(function()
                            Outline:SetControlPoints(Points)
                        end)
                        Outline.Color3 = Color3.fromRGB(0, 0, 0)
                        Outline.Thickness = 3
                        Outline.Visible = true
                    end
                    if Path then
                        pcall(function()
                            Path:SetControlPoints(Points)
                        end)
                        Path.Color3 = CornerColor
                        Path.Thickness = 1
                        Path.Visible = true
                    end
                end
            else
                for i = 1, 4 do
                    local Corner = Objects['Corner_' .. i]
                    local Layout = CornerFrameLayout[i]
                    local H = Objects['CornerH_' .. i]
                    local V = Objects['CornerV_' .. i]
                    if Corner and Layout then
                        Corner.Position = Layout.Pos
                        Corner.AnchorPoint = Layout.Anchor
                        Corner.Size = Dim2(Arm, 0, Arm, 0)
                        Corner.Visible = true
                    end
                    if H and Layout then
                        H.Size = Layout.H
                        H.Position = Layout.HP
                        H.AnchorPoint = Layout.HA
                        H.BackgroundColor3 = CornerColor
                        H.Visible = true
                    end
                    if V and Layout then
                        V.Size = Layout.V
                        V.Position = Layout.VP
                        V.AnchorPoint = Layout.VA
                        V.BackgroundColor3 = CornerColor
                        V.Visible = true
                    end
                end
            end
        else
            if Objects['Box3D'] then
                Objects['Box3D'].Visible = false
                Objects['Box3D'].Adornee = nil
            end
            if Objects['CornerHolder'].Visible then
                Objects['CornerHolder'].Visible = false
            end
            Hide_Corner_Objects(Objects)

            if not Objects['BoxOutlineHolder'].Visible then
                Objects['BoxOutlineHolder'].Visible = true
            end

            if not Objects['BoxInlineHolder'].Visible then
                Objects['BoxInlineHolder'].Visible = true
            end

            ApplyTwoColorGradient(Objects['BoxInlineGradient'], BoxesCfg['Gradients'], 0)
            ApplyTwoColorGradient(Objects['BoxOutlineGradient'], BoxesCfg['Gradients'], 0)

            if FillEnabled then
                if not Objects['BoxFill'].Visible then
                    Objects['BoxFill'].Visible = true
                end

                local FillCfg = BoxesCfg['Filled']
                local FillT1 = FillCfg['Transparency'][1]
                local FillT2 = FillCfg['Transparency'][2]

                ApplyTwoColorGradient(Objects['BoxFillGradient'], FillCfg, 0, FillT1, FillT2)
                SyncGradientTransparency(Objects['BoxFillGradient'], FillCfg, FillT1, FillT2, 'Fill', Data)
            else
                if Objects['BoxFill'].Visible then
                    Objects['BoxFill'].Visible = false
                end
            end
        end
    else
        if Objects['Box3D'] then
            Objects['Box3D'].Visible = false
            Objects['Box3D'].Adornee = nil
        end
        if Objects['BoxOutlineHolder'].Visible then
            Objects['BoxOutlineHolder'].Visible = false
        end

        if Objects['BoxInlineHolder'].Visible then
            Objects['BoxInlineHolder'].Visible = false
        end

        if Objects['BoxFill'].Visible then
            Objects['BoxFill'].Visible = false
        end

        if Objects['CornerHolder'].Visible then
            Objects['CornerHolder'].Visible = false
        end

        Hide_Corner_Objects(Objects)
    end

    if TextsCfg['Name']['Enabled'] then
        if not Objects['TargetName'].Visible then
            Objects['TargetName'].Visible = true
        end

        local DisplayName = typeof(Player) == 'Instance' and Player.DisplayName or Player.DisplayName
        local NameText = GetNameDisplayText(TextsCfg['Name'], DisplayName)

        if Data['LastDisplayName'] ~= NameText then
            Objects['TargetName'].Text = NameText
            Data['LastDisplayName'] = NameText
        end

        ApplyTwoColorGradient(Objects['TargetNameGradient'], TextsCfg['Name'], 0)
        Objects['TargetName'].TextColor3 = White
    else
        if Objects['TargetName'].Visible then
            Objects['TargetName'].Visible = false
        end
    end

    if TextsCfg['Distance']['Enabled'] then
        if not Objects['Distance'].Visible then
            Objects['Distance'].Visible = true
        end

        if Data['LastDist'] ~= Distance then
            Objects['Distance'].Text = Format('%dst', Distance)
            Data['LastDist'] = Distance
        end

        ApplyTwoColorGradient(Objects['DistanceGradient'], TextsCfg['Distance'], 0)
        Objects['Distance'].TextColor3 = White
    else
        if Objects['Distance'].Visible then
            Objects['Distance'].Visible = false
        end
    end

    local HealthCfg = Table['Bars']['Health Bar']
    local HealthNumbersCfg = Table['Bars']['Health Numbers']
    local ShowHealthBar = HealthCfg['Enabled'] == true
    local ShowHealthNumbers = HealthNumbersCfg['Enabled'] == true

    if ShowHealthBar or ShowHealthNumbers then
        local Health = Data['Health'] or 0
        local MaxHealth = Data['MaxHealth'] or 100
        local Ratio = Data['DisplayHealthRatio'] or Clamp(Health / MaxHealth, 0, 1)
        local HealthThickness = GetBarDisplayThickness(HealthCfg['Thickness'], Ratio)

        if Data['LastHealthDisplayThickness'] ~= HealthThickness then
            Objects['HealthBarOutline'].Size = Dim2(0, HealthThickness, 1, 0)
            Data['LastHealthDisplayThickness'] = HealthThickness
        end

        if not Objects['LeftBarHolder'].Visible then
            Objects['LeftBarHolder'].Visible = true
        end

        if not Objects['HealthBarOutline'].Visible then
            Objects['HealthBarOutline'].Visible = true
        end

        if ShowHealthBar then
            if not Objects['HealthBar'].Visible then
                Objects['HealthBar'].Visible = true
            end
            Objects['HealthBar'].Size = Dim2(1, 0, Ratio, 0)
            ApplyHealthBarGradient(Objects['HealthBarGradient'], HealthCfg)
        elseif Objects['HealthBar'].Visible then
            Objects['HealthBar'].Visible = false
        end

        if ShowHealthNumbers then
            local FlooredHealth = Floor(Ratio * MaxHealth)
            local NumberOffset = HealthNumbersCfg['Offset'] or 10
            -- Only show health numbers when below full health
            local ShouldShowNumber = FlooredHealth < 100

            if ShouldShowNumber then
                if not Objects['HealthBarText'].Visible then
                    Objects['HealthBarText'].Visible = true
                end

                if Data['LastHealthFloor'] ~= FlooredHealth then
                    Objects['HealthBarText'].Text = Format('%d', FlooredHealth)
                    Objects['HealthBarText'].Position = Dim2(1, -NumberOffset, 1 - Ratio, 1)
                    Data['LastHealthFloor'] = FlooredHealth
                elseif Data['LastRatio'] ~= Ratio or Data['LastHealthNumberOffset'] ~= NumberOffset then
                    Objects['HealthBarText'].Position = Dim2(1, -NumberOffset, 1 - Ratio, 1)
                    Data['LastHealthNumberOffset'] = NumberOffset
                end

                ApplyTwoColorGradient(Objects['HealthBarTextGradient'], HealthNumbersCfg, 0)
                Objects['HealthBarText'].TextColor3 = White
                Data['LastRatio'] = Ratio
            elseif Objects['HealthBarText'].Visible then
                Objects['HealthBarText'].Visible = false
            end
        elseif Objects['HealthBarText'].Visible then
            Objects['HealthBarText'].Visible = false
        end
    else
        if Objects['HealthBarOutline'].Visible then
            Objects['HealthBarOutline'].Visible = false
        end

        if Objects['HealthBarText'].Visible then
            Objects['HealthBarText'].Visible = false
        end

        if Objects['LeftBarHolder'].Visible then
            Objects['LeftBarHolder'].Visible = false
        end
    end

    local WeaponCfg = TextsCfg['Weapon']

    if WeaponCfg['Enabled'] and Player ~= LocalPlayer then
        local ShowText = WeaponCfg['ShowText'] ~= false
        local ShowIcon = WeaponCfg['ShowIcon'] ~= false
        local CurrentTool = FighterBridge.GetEquippedWeaponName(Player, Data)
        local Stack = Objects['WeaponStack']
        local IconHolder = Objects['WeaponIconHolder']
        local Icon = Objects['WeaponIcon']
        local IconShadow = Objects['WeaponIconShadow']
        local WeaponLabel = Objects['Weapon']

        if Stack and not Stack.Visible then
            Stack.Visible = true
        end

        if Data['LastWeapon'] ~= CurrentTool then
            if WeaponLabel then
                WeaponLabel.Text = CurrentTool
            end
            Data['LastWeapon'] = CurrentTool
            Data['LastWeaponIcon'] = nil
        end

        if ShowIcon and Icon and IconHolder then
            local iconAsset = GetWeaponIcon(CurrentTool)
            if iconAsset then
                if Data['LastWeaponIcon'] ~= iconAsset then
                    Icon.Image = iconAsset
                    if IconShadow then
                        IconShadow.Image = iconAsset
                    end
                    Data['LastWeaponIcon'] = iconAsset
                end

                local maxH = WeaponCfg['IconMaxHeight'] or 16
                local w, h = GetWeaponIconPixelSize(CurrentTool, Distance, maxH)
                if Data['LastWeaponIconW'] ~= w or Data['LastWeaponIconH'] ~= h then
                    IconHolder.Size = DimOffset(w, h)
                    Data['LastWeaponIconW'] = w
                    Data['LastWeaponIconH'] = h
                end

                local iconColor = GetCfgColor1(WeaponCfg, White)
                Icon.ImageColor3 = iconColor
                IconHolder.Visible = true
            else
                IconHolder.Visible = false
            end
        elseif IconHolder then
            IconHolder.Visible = false
        end

        if ShowText and WeaponLabel then
            if not WeaponLabel.Visible then
                WeaponLabel.Visible = true
            end
            ApplyTwoColorGradient(Objects['WeaponGradient'], WeaponCfg, 0)
            WeaponLabel.TextColor3 = White
        elseif WeaponLabel and WeaponLabel.Visible then
            WeaponLabel.Visible = false
        end

        -- Hide whole stack if neither mode is showing anything
        if Stack then
            local any = (IconHolder and IconHolder.Visible) or (WeaponLabel and WeaponLabel.Visible)
            Stack.Visible = any and true or false
        end
    else
        if Objects['WeaponStack'] and Objects['WeaponStack'].Visible then
            Objects['WeaponStack'].Visible = false
        end
        if Objects['Weapon'] and Objects['Weapon'].Visible then
            Objects['Weapon'].Visible = false
        end
        if Objects['WeaponIconHolder'] and Objects['WeaponIconHolder'].Visible then
            Objects['WeaponIconHolder'].Visible = false
        end
    end

    local FlagsCfg = Table['Flags']
    local AmmoCfg = FlagsCfg['Ammo']

    if AmmoCfg and AmmoCfg['Enabled'] and Player ~= LocalPlayer and Objects['AmmoFlag'] then
        if not Objects['AmmoFlag'].Visible then
            Objects['AmmoFlag'].Visible = true
        end

        local AmmoText = FighterBridge.GetEquippedAmmoText(Player)
        local AmmoColor = AmmoCfg.Color1 or Color3.fromRGB(80, 160, 255)
        local HealthFontSize = Table.Bars['Health Bar'].FontSize or 9

        if Objects['AmmoFlag'].TextSize ~= HealthFontSize then
            Objects['AmmoFlag'].TextSize = HealthFontSize
        end

        if Data['LastAmmoFlagText'] ~= AmmoText then
            Objects['AmmoFlag'].Text = AmmoText
            Data['LastAmmoFlagText'] = AmmoText
        end

        if Objects['AmmoFlagGradient'] then
            Objects['AmmoFlagGradient'].Enabled = false
        end

        Objects['AmmoFlag'].TextColor3 = AmmoColor
    elseif Objects['AmmoFlag'] and Objects['AmmoFlag'].Visible then
        Objects['AmmoFlag'].Visible = false
    end

    if FlagsCfg['Enabled'] then
        Objects['WalkFlag'].Visible = Data['WalkActive'] == true
        Objects['JumpFlag'].Visible = Data['JumpActive'] == true
        Objects['SwimmingFlag'].Visible = Data['SwimmingActive'] == true
    else
        Objects['WalkFlag'].Visible = false
        Objects['JumpFlag'].Visible = false
        Objects['SwimmingFlag'].Visible = false
    end

    if Objects['WalkFlag'].Visible then
        local WalkCfg = FlagsCfg['Walking']
        local WalkText = GetFlagDisplayText(WalkCfg, DEFAULT_FLAG_LABELS.Walking)

        if Data['LastWalkFlagText'] ~= WalkText then
            Objects['WalkFlag'].Text = WalkText
            Data['LastWalkFlagText'] = WalkText
        end

        ApplyTwoColorGradient(Objects['WalkFlagGradient'], WalkCfg, 0)
        Objects['WalkFlag'].TextColor3 = White
    end

    if Objects['JumpFlag'].Visible then
        local JumpCfg = FlagsCfg['Jumping']
        local JumpText = GetFlagDisplayText(JumpCfg, DEFAULT_FLAG_LABELS.Jumping)

        if Data['LastJumpFlagText'] ~= JumpText then
            Objects['JumpFlag'].Text = JumpText
            Data['LastJumpFlagText'] = JumpText
        end

        ApplyTwoColorGradient(Objects['JumpFlagGradient'], JumpCfg, 0)
        Objects['JumpFlag'].TextColor3 = White
    end

    if Objects['SwimmingFlag'].Visible then
        local SwimCfg = FlagsCfg['Swimming']
        local SwimText = GetFlagDisplayText(SwimCfg, DEFAULT_FLAG_LABELS.Swimming)

        if Data['LastSwimFlagText'] ~= SwimText then
            Objects['SwimmingFlag'].Text = SwimText
            Data['LastSwimFlagText'] = SwimText
        end

        ApplyTwoColorGradient(Objects['SwimmingFlagGradient'], SwimCfg, 0)
        Objects['SwimmingFlag'].TextColor3 = White
    end

    self:UpdateSkeleton(Player, Data, ViewportCamera, ViewportFrame)
end

do
    local ESP_RENDER_BIND = 'BlurredEspRenderer'

    local function StopLoops()
        local ChamsConn = EspLibrary.Threads['ChamsRefresh']

        if ChamsConn then
            ChamsConn:Disconnect()
            EspLibrary.Threads['ChamsRefresh'] = nil
        end

        pcall(function()
            RunService:UnbindFromRenderStep(ESP_RENDER_BIND)
        end)
        EspLibrary.Threads['Renderer'] = nil

        LoopsStarted = false
    end

    local function EnsureLoops()
        if LoopsStarted then
            return
        end

        LoopsStarted = true
        if type(Table['RefreshRate']) ~= 'number' or Table['RefreshRate'] <= 0 then
            Table['RefreshRate'] = 120
        else
            Table['RefreshRate'] = Clamp(Table['RefreshRate'], 30, 240)
        end

        EspLibrary:CreateThreads('ChamsRefresh', RunService.Heartbeat, function()
            if not RuntimeActive or not Table['Enabled'] then
                return
            end

            if not FighterBridge.IsLocalFighterActive() then
                return
            end

            SetGameIdentity()
            ProcessChamsRefreshQueue(CHAMS_MAX_REFRESH_PER_FRAME)
        end)

        -- After Camera: uses this frame's poses so ESP never lags behind enemies
        local LastHeavyTick = 0
        RunService:BindToRenderStep(ESP_RENDER_BIND, Enum.RenderPriority.Camera.Value + 1, function()
            if not RuntimeActive then
                return
            end

            SetGameIdentity()

            if not FighterBridge.IsLocalFighterActive() or not Table['Enabled'] then
                for _, Data in pairs(EspLibrary['Cache']) do
                    HideEspEntry(Data)
                end
                return
            end

            local Now = os.clock()
            Updates = Now
            local GradientDt = math.min(Now - LastGradientTick, 0.05)
            LastGradientTick = Now
            StepGradientScrollClock(GradientDt)

            local Cam = GetCamera()
            if Cam then
                CameraPosition = Cam.CFrame.Position
            end

            -- Chams / heavy extras at RefreshRate; boxes/text stay every frame for smoothness
            local HeavyInterval = 1 / Table['RefreshRate']
            local DoHeavy = (Now - LastHeavyTick) >= HeavyInterval
            if DoHeavy then
                LastHeavyTick = Now
            end

            local ChamsOn = Table['Chams']['Enabled'] == true
            for Player, Data in pairs(EspLibrary['Cache']) do
                if Player ~= LocalPlayer then
                    EspLibrary:Update(Player, Data)
                    if ChamsOn and DoHeavy then
                        EspLibrary:UpdateChams(Data)
                    end
                end
            end
        end)

        EspLibrary.Threads['Renderer'] = true
    end

    function EspLibrary:InitializePlayers()
        if PlayersInitialized then
            return
        end

        PlayersInitialized = true

        task.spawn(function()
            local PlayerList = Players:GetPlayers()
            local Step = math.clamp(5 / math.max(#PlayerList, 1), 0.05, 0.25)

            for Index, Player in ipairs(PlayerList) do
                if not RuntimeActive then
                    break
                end

                self:AddTarget(Player)

                if Index % 2 == 0 then
                    task.wait(Step)
                end
            end
        end)
    end

    function EspLibrary:Activate()
        if RuntimeActive then
            return
        end

        RuntimeActive = true
        Table['Enabled'] = true

        EnsureLoops()
        FighterBridge.Start()
        self:LoadFontsAsync()

        if PlayersInitialized then
            task.spawn(function()
                for _, Player in ipairs(Players:GetPlayers()) do
                    if RuntimeActive then
                        self:AddTarget(Player)
                    end
                end
            end)
        else
            self:InitializePlayers()
        end
    end

    function EspLibrary:Deactivate()
        if not RuntimeActive then
            return
        end

        RuntimeActive = false
        Table['Enabled'] = false

        for _, Data in pairs(self['Cache']) do
            local Objects = Data['Objects']

            if Objects and Objects['TargetHolder'] and Objects['TargetHolder'].Visible then
                Objects['TargetHolder'].Visible = false
            end

            if Objects and Objects['SkeletonRoot'] then
                Objects['SkeletonRoot'].Visible = false
            end
        end

        StopLoops()
        self:ClearAllChams()
    end

    function EspLibrary:StartPlayers()
        self:Activate()
    end

    function EspLibrary:IsStarted()
        return RuntimeActive
    end

    EspLibrary:CreateThreads('PlayerAdded', Players.PlayerAdded, function(Player)
        if RuntimeActive then
            EspLibrary:AddTarget(Player)
        end
    end)

    EspLibrary:CreateThreads('PlayerRemoving', Players.PlayerRemoving, function(Player)
        EspLibrary:RemoveTarget(Player)
    end)
end


function EspLibrary:GetTable()
    return Table
end

function EspLibrary:IsEnemyPlayer(Player)
    local Data = (self['Cache'] and self['Cache'][Player]) or {}
    return FighterBridge.IsEnemyPlayer(Player, Data)
end

function EspLibrary:CreatePreview(ParentFrame, Options)
    Options = Options or {}
    local SyncFrame = Options.SyncFrame or ParentFrame
    local BoundsFrame = Options.BoundsFrame or SyncFrame
    local ClipFrame = Options.ClipFrame
    local TopFrame = Options.TopFrame or BoundsFrame
    local IsActive = Options.IsActive
    local WindowHolder = Options.WindowHolder
    local BackgroundColor = Options.BackgroundColor or Color3.fromRGB(18, 18, 18)

    local function FindScreenGui(Gui)
        local Current = Gui

        while Current do
            if Current:IsA('ScreenGui') then
                return Current
            end

            Current = Current.Parent
        end

        return nil
    end

    local AnchorGui = Options.GuiParent or FindScreenGui(SyncFrame) or HolderParent
    local PreviewLookAt = NewVector3(0, 1, 0)
    local PreviewCamPos = NewVector3(0, 1.5, 8)
    local PreviewFov = 58
    local PreviewLayerZ = 30
    local PreviewEspZ = 5

    local function IsGuiChainVisible(Gui)
        local Current = Gui

        while Current do
            if Current:IsA('GuiObject') and not Current.Visible then
                return false
            end

            if Current:IsA('ScreenGui') and not Current.Enabled then
                return false
            end

            Current = Current.Parent
        end

        return true
    end

    local function ApplyModelRotation(Character, YRadians)
        local Pivot = Character:GetPivot()

        Character:PivotTo(CFrame.new(Pivot.Position) * CFrame.Angles(0, YRadians, 0))
    end

    local function CollectCharacterChildren(Character)
        local Out = {}

        if not Character then
            return Out
        end

        for _, Descendant in ipairs(Character:GetDescendants()) do
            Out[#Out + 1] = Descendant
        end

        Out[#Out + 1] = Character

        return Out
    end

    local function AddAsset(Assets, AssetId)
        if type(AssetId) == 'string' and AssetId ~= '' then
            Assets[#Assets + 1] = AssetId
        end
    end

    local function PreloadTextures(Model)
        local Assets = {}

        for _, Descendant in ipairs(Model:GetDescendants()) do
            if Descendant:IsA('Decal') or Descendant:IsA('Texture') then
                AddAsset(Assets, Descendant.Texture)
            elseif Descendant:IsA('Shirt') then
                AddAsset(Assets, Descendant.ShirtTemplate)
            elseif Descendant:IsA('Pants') then
                AddAsset(Assets, Descendant.PantsTemplate)
            elseif Descendant:IsA('ShirtGraphic') then
                AddAsset(Assets, Descendant.Graphic)
            elseif Descendant:IsA('MeshPart') then
                AddAsset(Assets, Descendant.MeshId)
                AddAsset(Assets, Descendant.TextureID)
            elseif Descendant:IsA('SpecialMesh') then
                AddAsset(Assets, Descendant.MeshId)
                AddAsset(Assets, Descendant.TextureId)
            elseif Descendant:IsA('CharacterMesh') then
                AddAsset(Assets, Descendant.MeshId)
            elseif Descendant:IsA('SurfaceAppearance') then
                AddAsset(Assets, Descendant.ColorMap)
                AddAsset(Assets, Descendant.NormalMap)
                AddAsset(Assets, Descendant.MetalnessMap)
                AddAsset(Assets, Descendant.RoughnessMap)
            elseif Descendant:IsA('Accessory') then
                local Handle = Descendant:FindFirstChild('Handle')

                if Handle then
                    for _, Child in ipairs(Handle:GetDescendants()) do
                        if Child:IsA('Decal') or Child:IsA('Texture') then
                            AddAsset(Assets, Child.Texture)
                        elseif Child:IsA('SpecialMesh') then
                            AddAsset(Assets, Child.MeshId)
                            AddAsset(Assets, Child.TextureId)
                        elseif Child:IsA('MeshPart') then
                            AddAsset(Assets, Child.MeshId)
                            AddAsset(Assets, Child.TextureID)
                        elseif Child:IsA('SurfaceAppearance') then
                            AddAsset(Assets, Child.ColorMap)
                            AddAsset(Assets, Child.NormalMap)
                            AddAsset(Assets, Child.MetalnessMap)
                            AddAsset(Assets, Child.RoughnessMap)
                        end
                    end
                end
            end
        end

        pcall(ContentProvider.PreloadAsync, ContentProvider, { Model })
        pcall(ContentProvider.PreloadAsync, ContentProvider, Model:GetDescendants())

        if #Assets > 0 then
            pcall(ContentProvider.PreloadAsync, ContentProvider, Assets)
        end
    end

    local function BoostPreviewZIndex(Root, BaseZ)
        if Root:IsA('GuiObject') then
            Root.ZIndex = BaseZ
        end

        local Offset = 1

        for _, Descendant in ipairs(Root:GetDescendants()) do
            if Descendant:IsA('GuiObject') then
                Descendant.ZIndex = BaseZ + Offset
                Offset = Offset + 1
            end
        end
    end

    local Model = nil
    local ViewportCamera = nil

    local function ClearViewportScene(Viewport)
        for _, Child in ipairs(Viewport:GetChildren()) do
            if Child:IsA('WorldModel') or Child:IsA('Camera') then
                Child:Destroy()
            end
        end

        ViewportCamera = nil
    end

    local function SetupPreviewCamera(Viewport, Character)
        local NewCamera = Instance.new('Camera')
        NewCamera.Parent = Viewport
        Viewport.CurrentCamera = NewCamera
        ViewportCamera = NewCamera

        if Character then
            local BbCf, BbSize = Character:GetBoundingBox()
            local Center = BbCf.Position
            local Dist = math.max(BbSize.X, BbSize.Y, BbSize.Z) * 1.15

            NewCamera.CFrame = CFrame.new(Center + NewVector3(0, BbSize.Y * 0.08, Dist), Center + NewVector3(0, BbSize.Y * 0.05, 0))
            NewCamera.FieldOfView = PreviewFov
        else
            NewCamera.CFrame = CFrame.new(PreviewCamPos, PreviewLookAt)
            NewCamera.FieldOfView = PreviewFov
        end

        return NewCamera
    end

    local function PrepareCharacterModel(Character)
        local HRP = Character:FindFirstChild('HumanoidRootPart')

        if not HRP then
            return false
        end

        local Humanoid = Character:FindFirstChildOfClass('Humanoid')

        if not Humanoid then
            Humanoid = Instance.new('Humanoid')
            Humanoid.Parent = Character
        end

        Humanoid.RigType = Enum.HumanoidRigType.R15
        Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

        for _, Descendant in ipairs(Character:GetDescendants()) do
            if Descendant:IsA('BasePart') then
                if Descendant.Name == 'HumanoidRootPart' then
                    Descendant.Transparency = 1
                else
                    Descendant.Transparency = 0
                    Descendant.Reflectance = 0

                    if Descendant.Material == Enum.Material.SmoothPlastic then
                        Descendant.Material = Enum.Material.Plastic
                    end
                end

                Descendant.Anchored = true
                Descendant.CanCollide = false
                Descendant.CastShadow = false
            elseif Descendant:IsA('Script') or Descendant:IsA('LocalScript') or Descendant:IsA('Animator') then
                Descendant:Destroy()
            end
        end

        HRP.Anchored = true
        HRP.CanCollide = false
        HRP.Transparency = 1

        for _, Accessory in ipairs(Character:GetChildren()) do
            if Accessory:IsA('Accessory') then
                local Handle = Accessory:FindFirstChild('Handle')

                if Handle then
                    Handle.Anchored = true
                    Handle.CanCollide = false
                    Handle.Transparency = 0
                end
            end
        end

        local Animate = Character:FindFirstChild('Animate')

        if Animate then
            Animate:Destroy()
        end

        Character.PrimaryPart = HRP

        local BbCf, BbSize = Character:GetBoundingBox()
        local FeetY = BbCf.Position.Y - (BbSize.Y * 0.5)
        local Offset = NewVector3(0, -FeetY, 0)

        for _, Descendant in ipairs(Character:GetDescendants()) do
            if Descendant:IsA('BasePart') then
                Descendant.CFrame = Descendant.CFrame + Offset
            end
        end

        ApplyModelRotation(Character, math.pi)

        return true
    end

    local function MountCharacter(Viewport, Character)
        if not Character or not Character:FindFirstChild('HumanoidRootPart') then
            return nil
        end

        ClearViewportScene(Viewport)

        if not PrepareCharacterModel(Character) then
            return nil
        end

        PreloadTextures(Character)

        local NewWorldModel = Instance.new('WorldModel')
        NewWorldModel.Parent = Viewport
        Character.Parent = NewWorldModel

        SetupPreviewCamera(Viewport, Character)
        RunService.RenderStepped:Wait()

        return Character
    end

    local function LoadAvatarModel()
        if not LocalPlayer then
            return nil
        end

        local function FromDescription(Description)
            if not Description then
                return nil
            end

            local Ok, Created = pcall(Players.CreateHumanoidModelFromDescription, Players, Description, Enum.HumanoidRigType.R15)

            if Ok and Created then
                Created.Name = 'PreviewAvatar'
                return Created
            end

            return nil
        end

        if LocalPlayer.Character then
            local Humanoid = LocalPlayer.Character:FindFirstChildOfClass('Humanoid')

            if Humanoid then
                local Ok, Description = pcall(function()
                    return Humanoid:GetAppliedDescription()
                end)

                if Ok then
                    local ModelFromApplied = FromDescription(Description)

                    if ModelFromApplied then
                        return ModelFromApplied
                    end
                end
            end
        end

        local OkDesc, Description = pcall(Players.GetHumanoidDescriptionFromUserId, Players, LocalPlayer.UserId)

        if OkDesc then
            local ModelFromUser = FromDescription(Description)

            if ModelFromUser then
                return ModelFromUser
            end
        end

        local OkUser, UserModel = pcall(Players.CreateHumanoidModelFromUserId, Players, LocalPlayer.UserId)

        if OkUser and UserModel then
            UserModel.Name = 'PreviewAvatar'
            return UserModel
        end

        return nil
    end

    local function CreateFallbackRig(Viewport)
        ClearViewportScene(Viewport)

        local NewWorldModel = Instance.new('WorldModel')
        NewWorldModel.Parent = Viewport

        local Rig = self:CreateObjects('Model', {
            Name = 'PreviewRig',
            Parent = NewWorldModel,
        })

        local HRP = self:CreateObjects('Part', {
            Name = 'HumanoidRootPart',
            Parent = Rig,
            Size = NewVector3(2, 2, 1),
            Anchored = true,
            CanCollide = false,
            Transparency = 1,
            Position = ZeroVector3,
        })

        local Parts = {
            { 'UpperTorso', NewVector3(2, 1.5, 1), NewVector3(0, 0.75, 0), Color3.fromRGB(163, 162, 165) },
            { 'Head', NewVector3(1.2, 1.2, 1.2), NewVector3(0, 2.1, 0), Color3.fromRGB(234, 184, 146) },
            { 'LowerTorso', NewVector3(2, 1, 1), NewVector3(0, -1, 0), Color3.fromRGB(99, 95, 98) },
            { 'LeftUpperLeg', NewVector3(1, 1.2, 1), NewVector3(-0.55, -1.8, 0), Color3.fromRGB(99, 95, 98) },
            { 'RightUpperLeg', NewVector3(1, 1.2, 1), NewVector3(0.55, -1.8, 0), Color3.fromRGB(99, 95, 98) },
            { 'LeftLowerLeg', NewVector3(1, 1.2, 1), NewVector3(-0.55, -3.1, 0), Color3.fromRGB(99, 95, 98) },
            { 'RightLowerLeg', NewVector3(1, 1.2, 1), NewVector3(0.55, -3.1, 0), Color3.fromRGB(99, 95, 98) },
            { 'LeftUpperArm', NewVector3(1, 1.2, 1), NewVector3(-1.45, 0.9, 0), Color3.fromRGB(163, 162, 165) },
            { 'RightUpperArm', NewVector3(1, 1.2, 1), NewVector3(1.45, 0.9, 0), Color3.fromRGB(163, 162, 165) },
        }

        for _, Entry in ipairs(Parts) do
            self:CreateObjects('Part', {
                Name = Entry[1],
                Parent = Rig,
                Size = Entry[2],
                Position = Entry[3],
                Color = Entry[4],
                Anchored = true,
                CanCollide = false,
            })
        end

        self:CreateObjects('Humanoid', {
            Parent = Rig,
            Health = 100,
            MaxHealth = 100,
        })

        Rig.PrimaryPart = HRP
        PrepareCharacterModel(Rig)
        SetupPreviewCamera(Viewport, Rig)

        return Rig
    end

    local function ApplyPreviewModel(NewModel, PreviewData)
        if not NewModel then
            return
        end

        local Root = NewModel:FindFirstChild('HumanoidRootPart') or NewModel.PrimaryPart
        local Hum = NewModel:FindFirstChildOfClass('Humanoid')

        PreviewData['Character'] = NewModel
        PreviewData['RootPart'] = Root
        PreviewData['Humanoid'] = Hum
        PreviewData['Children'] = CollectCharacterChildren(NewModel)
        PreviewData['Health'] = Hum and Hum.Health or 100
        PreviewData['MaxHealth'] = Hum and Hum.MaxHealth or 100
        PreviewData['Alive'] = true
        PreviewData['LastW'] = nil
        PreviewData['LastH'] = nil
        PreviewData['LastX'] = nil
        PreviewData['LastY'] = nil
    end

    local function TryLoadCharacter(Viewport)
        if LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart') then
            LocalPlayer.Character.Archivable = true

            local Ok, Cloned = pcall(function()
                return LocalPlayer.Character:Clone()
            end)

            if Ok and Cloned then
                local Mounted = MountCharacter(Viewport, Cloned)

                if Mounted then
                    return Mounted
                end
            end
        end

        local AvatarModel = LoadAvatarModel()

        if AvatarModel then
            local Mounted = MountCharacter(Viewport, AvatarModel)

            if Mounted then
                return Mounted
            end
        end

        return nil
    end

    local Mount = self:CreateObjects('Frame', {
        Parent = ParentFrame,
        Size = Dim2(1, 0, 1, 0),
        Position = Dim2(0, 0, 0, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = PreviewLayerZ,
    })

    local Viewport
    local Overlay

    local function ApplySectionBackground()
        if not Viewport then
            return
        end

        local SectionFrame = SyncFrame and SyncFrame.Parent

        if SectionFrame and SectionFrame:IsA('Frame') then
            Viewport.BackgroundColor3 = SectionFrame.BackgroundColor3
        else
            Viewport.BackgroundColor3 = BackgroundColor
        end
    end

    local function SetPreviewVisible(Visible)
        if Viewport then
            Viewport.Visible = Visible
        end
    end

    Viewport = self:CreateObjects('ViewportFrame', {
        Parent = AnchorGui,
        Visible = false,
        Position = DimOffset(0, 0),
        Size = DimOffset(100, 100),
        BackgroundColor3 = BackgroundColor,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = PreviewLayerZ,
        Ambient = Color3.fromRGB(220, 220, 220),
        LightColor = Color3.fromRGB(255, 255, 255),
        LightDirection = Vector3.new(-0.35, -0.75, -0.55),
    })

    Overlay = self:CreateObjects('Frame', {
        Parent = Viewport,
        Visible = true,
        Position = Dim2(0, 0, 0, 0),
        Size = Dim2(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = false,
        ZIndex = PreviewEspZ,
    })

    ApplySectionBackground()

    local function GetPreviewBounds()
        local Frame = BoundsFrame or Mount

        if not Frame then
            return nil
        end

        local Pos = Frame.AbsolutePosition
        local Size = Frame.AbsoluteSize
        local MinX = Pos.X
        local MinY = Pos.Y
        local MaxX = Pos.X + Size.X
        local MaxY = Pos.Y + Size.Y

        if ClipFrame then
            local ClipPos = ClipFrame.AbsolutePosition
            local ClipSize = ClipFrame.AbsoluteSize

            MinX = math.max(MinX, ClipPos.X)
            MinY = math.max(MinY, ClipPos.Y)
            MaxX = math.min(MaxX, ClipPos.X + ClipSize.X)
            MaxY = math.min(MaxY, ClipPos.Y + ClipSize.Y)
        end

        if TopFrame then
            MinY = math.max(MinY, TopFrame.AbsolutePosition.Y)
        end

        local Width = MaxX - MinX
        local Height = MaxY - MinY

        if Width < 2 or Height < 2 then
            return nil
        end

        return MinX, MinY, Width, Height
    end

    local function ShouldRenderPreview()
        if WindowHolder and not WindowHolder.Visible then
            SetPreviewVisible(false)
            return false
        end

        if IsActive and not IsActive() then
            SetPreviewVisible(false)
            return false
        end

        if not IsGuiChainVisible(SyncFrame) then
            SetPreviewVisible(false)
            return false
        end

        local MinX, MinY, Width, Height = GetPreviewBounds()

        if not MinX then
            SetPreviewVisible(false)
            return false
        end

        SetPreviewVisible(true)

        local BoundsPos = DimOffset(Floor(MinX + 0.5), Floor(MinY + 0.5))
        local BoundsSize = DimOffset(Floor(Width + 0.5), Floor(Height + 0.5))

        Viewport.Position = BoundsPos
        Viewport.Size = BoundsSize
        ApplySectionBackground()

        return true
    end

    local PreviewPlayer = { DisplayName = 'Preview', Name = 'Preview' }
    local PreviewData

    PreviewData = {
        ['Player'] = PreviewPlayer,
        ['Objects'] = {},
        ['Conns'] = {},
        ['Character'] = nil,
        ['RootPart'] = nil,
        ['Humanoid'] = nil,
        ['Children'] = {},
        ['Health'] = 100,
        ['MaxHealth'] = 100,
        ['CurrentTool'] = 'none',
        ['Alive'] = true,
        ['IsPreview'] = true,
        ['IncludeAccessories'] = Table['Boxes']['Bounding Box']['IncludeAcsessories'],
        ['LastW'] = nil,
        ['LastH'] = nil,
        ['LastX'] = nil,
        ['LastY'] = nil,
        ['LastGlowTop'] = nil,
        ['LastGlowBot'] = nil,
        ['LastGlowT1'] = nil,
        ['LastGlowT2'] = nil,
        ['LastGradTop'] = nil,
        ['LastGradBot'] = nil,
        ['LastFillTop'] = nil,
        ['LastFillBot'] = nil,
        ['LastFillT1'] = nil,
        ['LastFillT2'] = nil,
        ['LastDist'] = nil,
        ['LastDistColor'] = nil,
        ['LastDisplayName'] = nil,
        ['LastNameColor'] = nil,
        ['LastHealthTop'] = nil,
        ['LastHealthMid'] = nil,
        ['LastHealthBot'] = nil,
        ['LastHealthFloor'] = nil,
        ['LastRatio'] = nil,
        ['LastWeapon'] = nil,
    }

    self:InitEsp(PreviewData, Overlay)
    self.PreviewData = PreviewData
    BoostPreviewZIndex(PreviewData['Objects']['TargetHolder'], PreviewEspZ)
    self:ApplyFontToObjects(PreviewData.Objects)
    BoostPreviewZIndex(PreviewData['Objects']['TargetHolder'], PreviewEspZ)

    local PreviewAlive = true
    local ReloadRequested = true
    local Reloading = false
    local LastReloadAttempt = 0
    local LastSourceCharacter = nil
    local CharacterWatchConns = {}

    local function RequestReload()
        ReloadRequested = true
    end

    local function ClearCharacterWatch()
        for _, Conn in ipairs(CharacterWatchConns) do
            Conn:Disconnect()
        end

        Clear(CharacterWatchConns)
    end

    local function WatchSourceCharacter(Character)
        if Character == LastSourceCharacter then
            return
        end

        ClearCharacterWatch()
        LastSourceCharacter = Character

        if not Character then
            return
        end

        CharacterWatchConns[#CharacterWatchConns + 1] = Character.ChildAdded:Connect(RequestReload)
        CharacterWatchConns[#CharacterWatchConns + 1] = Character.ChildRemoved:Connect(RequestReload)
        CharacterWatchConns[#CharacterWatchConns + 1] = Character.DescendantAdded:Connect(RequestReload)
        CharacterWatchConns[#CharacterWatchConns + 1] = Character.DescendantRemoving:Connect(RequestReload)
    end

    local function ReloadPreviewModel()
        if Reloading or not PreviewAlive or not Viewport then
            return
        end

        local Now = os.clock()

        if Now - LastReloadAttempt < 0.75 then
            return
        end

        Reloading = true
        ReloadRequested = false
        LastReloadAttempt = Now

        local Loaded = TryLoadCharacter(Viewport)

        if not Loaded and LocalPlayer then
            task.wait(0.25)
            Loaded = TryLoadCharacter(Viewport)
        end

        if not Loaded then
            Loaded = CreateFallbackRig(Viewport)
        end

        if Loaded and PreviewAlive then
            Model = Loaded
            WatchSourceCharacter(LocalPlayer and LocalPlayer.Character or nil)
            ApplyPreviewModel(Model, PreviewData)
            self:ApplyFontToObjects(PreviewData.Objects)
            BoostPreviewZIndex(PreviewData['Objects']['TargetHolder'], PreviewEspZ)
        end

        Reloading = false
    end

    if LocalPlayer then
        PreviewData['Conns']['PreviewCharAdded'] = LocalPlayer.CharacterAdded:Connect(function(Character)
            WatchSourceCharacter(Character)
            RequestReload()
        end)

        PreviewData['Conns']['PreviewCharRemoving'] = LocalPlayer.CharacterRemoving:Connect(function()
            RequestReload()
        end)

        WatchSourceCharacter(LocalPlayer.Character)
    end

    Spawn(function()
        local Deadline = os.clock() + 8

        while (BoundsFrame.AbsoluteSize.X < 50 or BoundsFrame.AbsoluteSize.Y < 50) and os.clock() < Deadline do
            RunService.RenderStepped:Wait()
        end

        if LocalPlayer and not LocalPlayer.Character then
            LocalPlayer.CharacterAdded:Wait()
            task.wait(0.5)
        end

        ReloadPreviewModel()
    end)

    local PreviewConn = RunService.RenderStepped:Connect(function()
        if not ShouldRenderPreview() then
            return
        end

        if ReloadRequested or (LocalPlayer and LocalPlayer.Character ~= LastSourceCharacter) then
            Spawn(ReloadPreviewModel)
        end

        if not Model or not ViewportCamera then
            return
        end

        PreviewData['IncludeAccessories'] = Table['Boxes']['Bounding Box']['IncludeAcsessories']
        PreviewData['Children'] = CollectCharacterChildren(Model)

        local Now = os.clock()
        local GradientDt = math.min(Now - LastGradientTick, 0.1)
        LastGradientTick = Now
        StepGradientScrollClock(GradientDt)

        local SavedCameraPosition = CameraPosition
        CameraPosition = ViewportCamera.CFrame.Position
        self:Update(PreviewPlayer, PreviewData, ViewportCamera, Viewport)
        CameraPosition = SavedCameraPosition
    end)

    return {
        Destroy = function()
            PreviewAlive = false
            PreviewConn:Disconnect()
            self.PreviewData = nil
            ClearCharacterWatch()

            for _, Conn in pairs(PreviewData['Conns']) do
                Conn:Disconnect()
            end

            Clear(PreviewData['Conns'])

            if PreviewData['Objects']['TargetHolder'] then
                PreviewData['Objects']['TargetHolder']:Destroy()
            end

            ClearViewportScene(Viewport)

            if Viewport then
                Viewport:Destroy()
            end

            Mount:Destroy()
        end,
    }
end

do
    function EspLibrary:Unload()
        self:Deactivate()

        for Player in pairs(self['Cache']) do
            self:RemoveTarget(Player);
        end;

        for _, Conn in pairs(self['Connections']) do
            Conn:Disconnect();
        end;

        Clear(self['Connections']);

        for _, Conn in pairs(self['Threads']) do
            if typeof(Conn) == 'RBXScriptConnection' then
                Conn:Disconnect()
            end
        end

        pcall(function()
            RunService:UnbindFromRenderStep('BlurredEspRenderer')
        end)

        Clear(self['Threads']);

        if self['Holder'] then
            self['Holder']:Destroy();
            self['Holder'] = nil;
        end;

        if ChamsFolder then
            ChamsFolder:Destroy();
            ChamsFolder = nil;
        end;

        table.clear(ChamsRefreshQueue);

        for Key in pairs(ChamsRefreshQueued) do
            ChamsRefreshQueued[Key] = nil;
        end;

        RuntimeActive = false;
        LoopsStarted = false;
        PlayersInitialized = false;

        Clear(self['Cache']);
    end
end

getgenv().EspLibrary = EspLibrary
return EspLibrary
end)()
