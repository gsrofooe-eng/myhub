

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

do
	local old = playerGui:FindFirstChild("NexusClient")
	if old then old:Destroy() end
end

-- =====================================================
-- THEME + CORE HELPERS
-- =====================================================
local WIN_W, WIN_H = 740, 480

local BG = Color3.fromRGB(10, 12, 16)
local PANEL = Color3.fromRGB(18, 21, 28)
local CARD = Color3.fromRGB(26, 30, 40)
local HOVER = Color3.fromRGB(34, 39, 52)
local OFFCOL = Color3.fromRGB(60, 66, 80)
local TEXT = Color3.fromRGB(235, 238, 245)
local SUB = Color3.fromRGB(135, 142, 158)
local RED = Color3.fromRGB(255, 80, 90)

local accent = Color3.fromRGB(0, 255, 120)
local accentObjs = {}
local unloaded = false
local globalConns = {}

local TI = {
	fast = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	ease = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	slow = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	back = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	quint = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	exit = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
}

local function tween(obj, props, info)
	local t = TweenService:Create(obj, info or TI.ease, props)
	t:Play()
	return t
end

local function reg(obj, prop)
	table.insert(accentObjs, { obj, prop })
	obj[prop] = accent
	return obj
end

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function corner(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o)
end

local orderCounter = 0
local function nextOrder()
	orderCounter += 1
	return orderCounter
end

local function bind(signal, fn)
	local c = signal:Connect(fn)
	table.insert(globalConns, c)
	return c
end

local function getHum()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function typing()
	return UIS:GetFocusedTextBox() ~= nil
end

local function isPress(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function hover(btn, normal, over)
	btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = over }, TI.fast) end)
	btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = normal }, TI.fast) end)
end

local function pressFx(btn)
	local sc = new("UIScale", {}, btn)
	btn.MouseButton1Down:Connect(function()
		tween(sc, { Scale = 0.96 }, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end)
	local function up() tween(sc, { Scale = 1 }, TI.back) end
	btn.MouseButton1Up:Connect(up)
	btn.MouseLeave:Connect(up)
end

local function findPlayer(text)
	if not text then return nil end
	text = text:lower()
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and (plr.Name:lower():find(text, 1, true) or plr.DisplayName:lower():find(text, 1, true)) then
			return plr
		end
	end
end

local function getPing()
	local ping = "n/a"
	pcall(function()
		ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) .. " ms"
	end)
	return ping
end

-- =====================================================
-- SHARED STATE
-- =====================================================
local cfg = {
	flySpeed = 60, walkSpeed = 50, jumpPower = 120, spinSpeed = 20, zoom = 520,
	gravity = 196, time = 14, sprint = 2, dash = 90, glide = 12, fov = 70,
	zoomFov = 30, freecam = 60, orbit = 20, bloom = 10, sat = 0, contrast = 0,
	hue = 200, cycle = 30,
	climb = 35, hip = 8, camX = 0, camY = 0, blink = 25, blur = 10, dof = 60, rays = 25,
	exposure = 0, brightness = 20, fogDist = 400, disco = 20, snow = 300, rainRate = 600,
	tintHue = 0, tintAlpha = 15, bars = 12, quality = 5, toastTime = 2,
	size = 100, aura = 25, nameDist = 2000,
}

local S = {
	speedOn = false, jumpOn = false, flyOn = false, freecam = false, ctp = false,
	cd = false, afk = false, wide = false, grav = false, timeOn = false,
	followTarget = nil, respawnHere = false, lastAlive = nil, notifications = true,
}

local NORMAL_SPEED, NORMAL_JUMP = 16, 50

local F = {}              -- feature functions
local UI = {}             -- gui references and gui functions
local modules = {}
local keyActions = {}
local sliderSetters = {}
local waypoints = {}
local hudRows = {}

-- =====================================================
-- LOG, TOASTS, MODULE STATE
-- =====================================================
local function log(text)
	if UI.footer then UI.footer.Text = "> " .. text end
end

local function notify(text, good)
	if unloaded or not S.notifications or not UI.toasts then return end

	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	}, UI.toasts)
	local toast = new("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		Position = UDim2.new(0, 290, 0, 0),
		BackgroundColor3 = PANEL,
	}, wrap)
	corner(toast, 8)
	new("UIStroke", { Color = OFFCOL, Thickness = 1 }, toast)
	local bar = new("Frame", {
		Size = UDim2.new(0, 4, 1, -14),
		Position = UDim2.new(0, 7, 0, 7),
		BackgroundColor3 = (good == false) and RED or accent,
		BorderSizePixel = 0,
	}, toast)
	corner(bar, 2)
	new("TextLabel", {
		Size = UDim2.new(1, -26, 1, 0),
		Position = UDim2.new(0, 20, 0, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = TEXT,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, toast)

	tween(wrap, { Size = UDim2.new(1, 0, 0, 44) }, TI.slow)
	tween(toast, { Position = UDim2.new(0, 0, 0, 0) }, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out))

	task.delay(cfg.toastTime, function()
		if not wrap.Parent then return end
		local t1 = tween(toast, { Position = UDim2.new(0, 290, 0, 0) }, TI.exit)
		t1.Completed:Wait()
		if not wrap.Parent then return end
		local t2 = tween(wrap, { Size = UDim2.new(1, 0, 0, 0) }, TI.ease)
		t2.Completed:Wait()
		wrap:Destroy()
	end)
end

local function refreshHud(m)
	if not UI.hud or m.def.noHud then return end
	local row = hudRows[m]
	if m.on then
		if not row then
			row = new("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = m.name .. " ",
				TextColor3 = accent,
				Font = Enum.Font.Code,
				TextSize = 15,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				TextXAlignment = Enum.TextXAlignment.Right,
				LayoutOrder = -#m.name,
				ClipsDescendants = true,
			}, UI.hud)
			hudRows[m] = row
		end
		tween(row, { Size = UDim2.new(1, 0, 0, 18), TextTransparency = 0, TextStrokeTransparency = 0.5 }, TI.quint)
	elseif row then
		tween(row, { Size = UDim2.new(1, 0, 0, 0), TextTransparency = 1, TextStrokeTransparency = 1 }, TI.exit)
	end
end

local function setModule(m, on, silent)
	m.on = on
	if m.refresh then m.refresh() end
	local ok, err = pcall(m.def.onToggle, on)
	if not ok then
		warn("[NEXUS] " .. m.name .. ": " .. tostring(err))
		log("error in " .. string.lower(m.name))
		notify(m.name .. " failed", false)
	elseif not silent then
		log((on and "injecting " or "detached ") .. string.lower(m.name) .. (on and "..." or ""))
		notify(m.name .. (on and " enabled" or " disabled"), on)
	end
	refreshHud(m)
end

-- =====================================================
-- FEATURES: PLAYER STATS
-- =====================================================
function F.captureDefaults()
	local hum = getHum()
	if hum then
		NORMAL_SPEED = hum.WalkSpeed
		NORMAL_JUMP = hum.UseJumpPower and hum.JumpPower or 50
	end
end

function F.baseSpeed()
	return S.speedOn and cfg.walkSpeed or NORMAL_SPEED
end

function F.applyStats()
	local hum = getHum()
	if not hum then return end
	hum.UseJumpPower = true
	hum.WalkSpeed = F.baseSpeed()
	hum.JumpPower = S.jumpOn and cfg.jumpPower or NORMAL_JUMP
end

F.captureDefaults()

-- =====================================================
-- FEATURES: MOVEMENT
-- =====================================================

-- Fly (upright, smooth, no spinning)
do
	local bv, bg, conn

	local function cleanup()
		if conn then conn:Disconnect() conn = nil end
		if bv then bv:Destroy() bv = nil end
		if bg then bg:Destroy() bg = nil end
		local hum = getHum()
		if hum then hum.PlatformStand = false end
	end

	local function start()
		local root, hum = getRoot(), getHum()
		if not root or not hum then return end

		bv = new("BodyVelocity", {
			MaxForce = Vector3.new(1e6, 1e6, 1e6),
			Velocity = Vector3.zero,
		}, root)
		bg = new("BodyGyro", {
			MaxTorque = Vector3.new(1e7, 1e7, 1e7),
			P = 1e5,
			D = 1e3,
			CFrame = root.CFrame,
		}, root)
		hum.PlatformStand = true

		local smooth = Vector3.zero
		conn = RunService.RenderStepped:Connect(function(dt)
			local r = getRoot()
			if not r or not bv or not bg then return end
			local cam = workspace.CurrentCamera

			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.05 then
				bg.CFrame = CFrame.lookAt(r.Position, r.Position + flat)
			end
			r.AssemblyAngularVelocity = Vector3.zero

			local dir = Vector3.zero
			if not typing() and not S.freecam then
				if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
				if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
				if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
				if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
				if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
				if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
			end
			local target = dir.Magnitude > 0 and dir.Unit * cfg.flySpeed or Vector3.zero
			smooth = smooth:Lerp(target, 1 - math.exp(-dt * 10))
			bv.Velocity = smooth
		end)
	end

	function F.fly(on)
		S.flyOn = on
		cleanup()
		if on then start() end
	end

	function F.flyRestart()
		if S.flyOn then
			cleanup()
			start()
		end
	end
end

-- Noclip
do
	local conn
	function F.noclip(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = RunService.Stepped:Connect(function()
				local c = player.Character
				if not c then return end
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide = false end
				end
			end)
		end
	end
end

-- Infinite jump
do
	local conn
	function F.infJump(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = UIS.JumpRequest:Connect(function()
				local hum = getHum()
				if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
			end)
		end
	end
end

-- Bunny hop (hold Space)
do
	local conn
	function F.bunny(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = RunService.Heartbeat:Connect(function()
				local hum = getHum()
				if hum and not typing() and UIS:IsKeyDown(Enum.KeyCode.Space)
					and hum.FloorMaterial ~= Enum.Material.Air then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end)
		end
	end
end

-- Sprint (hold Left Shift)
do
	local conn
	function F.sprint(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = RunService.Heartbeat:Connect(function()
				local hum = getHum()
				if not hum or S.freecam then return end
				local held = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and not typing()
				hum.WalkSpeed = F.baseSpeed() * (held and cfg.sprint or 1)
			end)
		else
			F.applyStats()
		end
	end
end

-- Dash (action)
do
	local last = 0
	function F.dash()
		if os.clock() - last < 1 then return end
		local root = getRoot()
		if not root then return end
		last = os.clock()
		local look = workspace.CurrentCamera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.05 then flat = root.CFrame.LookVector end
		root.AssemblyLinearVelocity = flat.Unit * cfg.dash + Vector3.new(0, 15, 0)
	end
end

-- Glide (slow fall)
do
	local conn
	function F.glide(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = RunService.Heartbeat:Connect(function()
				local root, hum = getRoot(), getHum()
				if root and hum and hum.FloorMaterial == Enum.Material.Air then
					local v = root.AssemblyLinearVelocity
					if v.Y < -cfg.glide then
						root.AssemblyLinearVelocity = Vector3.new(v.X, -cfg.glide, v.Z)
					end
				end
			end)
		end
	end
end

-- Spin bot
do
	local conn
	function F.spin(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = RunService.RenderStepped:Connect(function(dt)
				if S.flyOn then return end
				local root = getRoot()
				if root then root.CFrame = root.CFrame * CFrame.Angles(0, cfg.spinSpeed * dt, 0) end
			end)
		end
	end
end

-- Click teleport (hold T and click)
bind(UIS.InputBegan, function(input, processed)
	if unloaded or processed or not S.ctp then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.T) then
		local root = getRoot()
		if root and mouse.Hit then
			S.lastPos = root.CFrame
			root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
			log("teleported")
		end
	end
end)

-- Float (walk on air)
do
	local conn, part
	function F.float(on)
		if conn then conn:Disconnect() conn = nil end
		if part then part:Destroy() part = nil end
		if not on then return end

		local char = player.Character
		local root = getRoot()
		if not char or not root then return end

		local cf, size = char:GetBoundingBox()
		local floatY = cf.Position.Y - size.Y / 2 - 0.5

		part = new("Part", {
			Size = Vector3.new(8, 1, 8),
			Anchored = true,
			CanQuery = false,
			CanTouch = false,
			Material = Enum.Material.Neon,
			Color = accent,
			Transparency = 0.8,
		}, workspace)

		conn = RunService.Heartbeat:Connect(function(dt)
			local r = getRoot()
			if not r or not part then return end
			if not typing() then
				if UIS:IsKeyDown(Enum.KeyCode.Space) then floatY += 30 * dt end
				if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then floatY -= 30 * dt end
			end
			part.CFrame = CFrame.new(r.Position.X, floatY, r.Position.Z)
		end)
	end
end

-- Anti void
do
	local conn, lastSafe
	function F.antiVoid(on)
		if conn then conn:Disconnect() conn = nil end
		if not on then return end
		conn = RunService.Heartbeat:Connect(function()
			local root, hum = getRoot(), getHum()
			if not root or not hum then return end
			if hum.FloorMaterial ~= Enum.Material.Air then lastSafe = root.CFrame end
			if root.Position.Y < workspace.FallenPartsDestroyHeight + 60 and lastSafe then
				root.AssemblyLinearVelocity = Vector3.zero
				root.CFrame = lastSafe + Vector3.new(0, 4, 0)
				log("anti-void saved you")
			end
		end)
	end
end

-- Ghost mode (hide your own character)
do
	local conn
	function F.ghost(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = RunService.RenderStepped:Connect(function()
				local c = player.Character
				if not c then return end
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end
				end
			end)
		else
			local c = player.Character
			if c then
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") then p.LocalTransparencyModifier = 0 end
				end
			end
		end
	end
end

-- Rainbow skin (your own character, local only)
do
	local conn, saved, hue = nil, {}, 0
	function F.rainbowSkin(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = RunService.Heartbeat:Connect(function(dt)
				hue = (hue + dt * 0.3) % 1
				local c = player.Character
				if not c then return end
				local col = Color3.fromHSV(hue, 0.8, 1)
				for _, p in ipairs(c:GetDescendants()) do
					if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
						if saved[p] == nil then saved[p] = p.Color end
						p.Color = col
					end
				end
			end)
		else
			for p, col in pairs(saved) do
				pcall(function() p.Color = col end)
			end
			saved = {}
		end
	end
end

-- Follow a player
do
	local conn
	function F.setFollow(plr)
		if conn then conn:Disconnect() conn = nil end
		S.followTarget = plr
		if not plr then return end
		conn = RunService.Heartbeat:Connect(function()
			local root = getRoot()
			local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if root and r then root.CFrame = r.CFrame * CFrame.new(0, 0, 4) end
		end)
	end
end

-- =====================================================
-- FEATURES: VISUALS
-- =====================================================

-- ESP
do
	local on_ = false
	local objs, conns = {}, {}
	local added, removed, loop

	local function remove(plr)
		local o = objs[plr]
		if o then
			if o.hl then o.hl:Destroy() end
			if o.tag then o.tag:Destroy() end
			objs[plr] = nil
		end
	end

	local function add(plr)
		if plr == player then return end
		remove(plr)
		local char = plr.Character
		if not char then return end

		local hl = new("Highlight", {
			FillColor = accent,
			FillTransparency = 0.65,
			OutlineColor = Color3.new(1, 1, 1),
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		}, char)

		local tag, label
		local head = char:FindFirstChild("Head")
		if head then
			tag = new("BillboardGui", {
				Size = UDim2.new(0, 150, 0, 48),
				StudsOffset = Vector3.new(0, 2.8, 0),
				AlwaysOnTop = true,
				Adornee = head,
			}, head)
			label = new("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				TextColor3 = accent,
				TextStrokeTransparency = 0.4,
				Font = Enum.Font.Code,
				TextSize = 13,
				Text = plr.Name,
			}, tag)
		end
		objs[plr] = { hl = hl, tag = tag, label = label }
	end

	local function hook(plr)
		if plr == player then return end
		if conns[plr] then conns[plr]:Disconnect() end
		conns[plr] = plr.CharacterAdded:Connect(function()
			task.wait(0.3)
			if on_ then add(plr) end
		end)
		if plr.Character then add(plr) end
	end

	function F.esp(on)
		on_ = on
		if on then
			for _, plr in ipairs(Players:GetPlayers()) do hook(plr) end
			added = Players.PlayerAdded:Connect(hook)
			removed = Players.PlayerRemoving:Connect(function(plr)
				remove(plr)
				if conns[plr] then conns[plr]:Disconnect() conns[plr] = nil end
			end)
			local last = 0
			loop = RunService.Heartbeat:Connect(function()
				if os.clock() - last < 0.2 then return end
				last = os.clock()
				local myRoot = getRoot()
				if not myRoot then return end
				for plr, o in pairs(objs) do
					local c = plr.Character
					local r = c and c:FindFirstChild("HumanoidRootPart")
					local h = c and c:FindFirstChildOfClass("Humanoid")
					if r and o.label then
						local d = (r.Position - myRoot.Position).Magnitude
						local hp = h and math.floor(h.Health) or 0
						o.label.Text = plr.Name .. "\n" .. math.floor(d) .. " studs | " .. hp .. " hp"
					end
				end
			end)
		else
			if added then added:Disconnect() added = nil end
			if removed then removed:Disconnect() removed = nil end
			if loop then loop:Disconnect() loop = nil end
			for _, c in pairs(conns) do c:Disconnect() end
			conns = {}
			for plr in pairs(objs) do remove(plr) end
		end
	end
end

-- Tracers
do
	local objs = {}
	local myAtt, loop

	local function clear()
		for _, o in pairs(objs) do
			if o.att then o.att:Destroy() end
			if o.beam then o.beam:Destroy() end
		end
		objs = {}
		if myAtt then myAtt:Destroy() myAtt = nil end
	end

	function F.tracers(on)
		if loop then loop:Disconnect() loop = nil end
		clear()
		if not on then return end

		local last = 0
		loop = RunService.Heartbeat:Connect(function()
			if os.clock() - last < 0.3 then return end
			last = os.clock()
			local root = getRoot()
			if not root then return end
			if not myAtt or myAtt.Parent ~= root then
				if myAtt then myAtt:Destroy() end
				myAtt = new("Attachment", {}, root)
			end

			local seen = {}
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= player then
					local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if r then
						seen[plr] = true
						local o = objs[plr]
						if not o or not o.att or o.att.Parent ~= r then
							if o then
								if o.att then o.att:Destroy() end
								if o.beam then o.beam:Destroy() end
							end
							local att = new("Attachment", {}, r)
							local beam = new("Beam", {
								Attachment0 = myAtt,
								Attachment1 = att,
								Width0 = 0.12,
								Width1 = 0.12,
								FaceCamera = true,
								LightEmission = 1,
								Color = ColorSequence.new(accent),
								Transparency = NumberSequence.new(0.2),
							}, workspace)
							objs[plr] = { att = att, beam = beam }
						else
							o.beam.Attachment0 = myAtt
							o.beam.Color = ColorSequence.new(accent)
						end
					end
				end
			end
			for plr, o in pairs(objs) do
				if not seen[plr] then
					if o.att then o.att:Destroy() end
					if o.beam then o.beam:Destroy() end
					objs[plr] = nil
				end
			end
		end)
	end
end

-- X-ray
do
	local set, conn = {}, nil

	local function xray(inst)
		if not inst:IsA("BasePart") or inst:IsA("Terrain") then return end
		local model = inst:FindFirstAncestorOfClass("Model")
		if model and model:FindFirstChildOfClass("Humanoid") then return end
		set[inst] = true
		inst.LocalTransparencyModifier = 0.65
	end

	function F.xray(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = workspace.DescendantAdded:Connect(xray)
			task.spawn(function()
				local n = 0
				for _, inst in ipairs(workspace:GetDescendants()) do
					xray(inst)
					n += 1
					if n % 400 == 0 then task.wait() end
				end
			end)
		else
			for inst in pairs(set) do
				pcall(function() inst.LocalTransparencyModifier = 0 end)
			end
			set = {}
		end
	end
end

-- Wide zoom
do
	local orig = player.CameraMaxZoomDistance
	function F.wideZoom(on)
		S.wide = on
		player.CameraMaxZoomDistance = on and cfg.zoom or orig
	end
end

-- Hold zoom (hold Z)
do
	local conn
	function F.holdZoom(on)
		if conn then conn:Disconnect() conn = nil end
		local cam = workspace.CurrentCamera
		if on then
			conn = RunService.RenderStepped:Connect(function(dt)
				local held = UIS:IsKeyDown(Enum.KeyCode.Z) and not typing()
				local target = held and cfg.zoomFov or cfg.fov
				cam.FieldOfView = cam.FieldOfView + (target - cam.FieldOfView) * (1 - math.exp(-dt * 12))
			end)
		elseif cam then
			cam.FieldOfView = cfg.fov
		end
	end
end

-- Freecam
do
	local conn, yaw, pitch, pos, camType

	function F.freecam(on)
		S.freecam = on
		if conn then conn:Disconnect() conn = nil end
		local cam = workspace.CurrentCamera
		if on then
			camType = cam.CameraType
			local rx, ry = cam.CFrame:ToOrientation()
			pitch, yaw, pos = rx, ry, cam.CFrame.Position
			cam.CameraType = Enum.CameraType.Scriptable
			local hum = getHum()
			if hum then hum.WalkSpeed = 0 hum.JumpPower = 0 end

			conn = RunService.RenderStepped:Connect(function(dt)
				if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
					UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
					local d = UIS:GetMouseDelta()
					yaw -= d.X * 0.003
					pitch = math.clamp(pitch - d.Y * 0.003, -1.5, 1.5)
				else
					UIS.MouseBehavior = Enum.MouseBehavior.Default
				end

				local rot = CFrame.fromOrientation(pitch, yaw, 0)
				local dir = Vector3.zero
				if not typing() then
					if UIS:IsKeyDown(Enum.KeyCode.W) then dir += rot.LookVector end
					if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= rot.LookVector end
					if UIS:IsKeyDown(Enum.KeyCode.D) then dir += rot.RightVector end
					if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= rot.RightVector end
					if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
					if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
				end
				if dir.Magnitude > 0 then pos += dir.Unit * cfg.freecam * dt end
				cam.CFrame = CFrame.new(pos) * rot
			end)
		else
			UIS.MouseBehavior = Enum.MouseBehavior.Default
			cam.CameraType = camType or Enum.CameraType.Custom
			local hum = getHum()
			if hum then cam.CameraSubject = hum end
			F.applyStats()
		end
	end
end

-- Orbit camera
do
	local conn, angle = nil, 0
	function F.orbit(on)
		if conn then conn:Disconnect() conn = nil end
		local cam = workspace.CurrentCamera
		if on then
			cam.CameraType = Enum.CameraType.Scriptable
			conn = RunService.RenderStepped:Connect(function(dt)
				local root = getRoot()
				if not root then return end
				angle += dt * cfg.orbit / 10
				local off = Vector3.new(math.cos(angle) * 14, 5, math.sin(angle) * 14)
				cam.CFrame = CFrame.lookAt(root.Position + off, root.Position)
			end)
		else
			cam.CameraType = Enum.CameraType.Custom
			local hum = getHum()
			if hum then cam.CameraSubject = hum end
		end
	end
end

-- =====================================================
-- FEATURES: WORLD
-- =====================================================
do
	local saved
	function F.fullbright(on)
		if on then
			saved = {
				Brightness = Lighting.Brightness,
				ClockTime = Lighting.ClockTime,
				FogEnd = Lighting.FogEnd,
				GlobalShadows = Lighting.GlobalShadows,
				Ambient = Lighting.Ambient,
				OutdoorAmbient = Lighting.OutdoorAmbient,
			}
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 1e6
			Lighting.GlobalShadows = false
			Lighting.Ambient = Color3.fromRGB(200, 200, 200)
			Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
		elseif saved then
			for k, v in pairs(saved) do
				pcall(function() Lighting[k] = v end)
			end
			saved = nil
		end
	end
end

do
	local orig = workspace.Gravity
	function F.gravity(on)
		S.grav = on
		if on then orig = workspace.Gravity end
		workspace.Gravity = on and cfg.gravity or orig
	end
end

do
	local orig = Lighting.ClockTime
	function F.timeChanger(on)
		S.timeOn = on
		if on then orig = Lighting.ClockTime end
		Lighting.ClockTime = on and cfg.time or orig
	end
end

do
	local conn
	function F.timeCycle(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = RunService.Heartbeat:Connect(function(dt)
				Lighting.ClockTime = (Lighting.ClockTime + dt * cfg.cycle / 60) % 24
			end)
		end
	end
end

do
	local fog, atm = nil, {}
	function F.noFog(on)
		if on then
			fog = { FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd }
			Lighting.FogStart = 1e6
			Lighting.FogEnd = 1e6
			for _, a in ipairs(Lighting:GetChildren()) do
				if a:IsA("Atmosphere") then
					atm[a] = { Density = a.Density, Haze = a.Haze }
					a.Density = 0
					a.Haze = 0
				end
			end
		else
			if fog then
				Lighting.FogStart = fog.FogStart
				Lighting.FogEnd = fog.FogEnd
				fog = nil
			end
			for a, v in pairs(atm) do
				pcall(function() a.Density = v.Density a.Haze = v.Haze end)
			end
			atm = {}
		end
	end
end

do
	local fx
	function F.bloom(on)
		if fx then fx:Destroy() fx = nil end
		if on then
			fx = new("BloomEffect", { Intensity = cfg.bloom / 10, Size = 24, Threshold = 0.9 }, Lighting)
		end
	end
	function F.bloomUpdate()
		if fx then fx.Intensity = cfg.bloom / 10 end
	end
end

do
	local fx
	function F.grade(on)
		if fx then fx:Destroy() fx = nil end
		if on then
			fx = new("ColorCorrectionEffect", {
				Saturation = cfg.sat / 100,
				Contrast = cfg.contrast / 100,
			}, Lighting)
		end
	end
	function F.gradeUpdate()
		if fx then
			fx.Saturation = cfg.sat / 100
			fx.Contrast = cfg.contrast / 100
		end
	end
end

do
	local saved
	local function apply()
		local c = Color3.fromHSV(cfg.hue / 360, 0.65, 0.85)
		Lighting.Ambient = c
		Lighting.OutdoorAmbient = c
	end
	function F.ambientTint(on)
		if on then
			saved = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
			apply()
		elseif saved then
			Lighting.Ambient = saved.Ambient
			Lighting.OutdoorAmbient = saved.OutdoorAmbient
			saved = nil
		end
	end
	function F.ambientUpdate()
		if saved then apply() end
	end
end

-- =====================================================
-- FEATURES: PERFORMANCE
-- =====================================================

-- No textures
do
	local saved, conn = {}, nil

	local function strip(inst)
		if saved[inst] or inst:IsA("Terrain") then return end
		if inst:IsA("Decal") or inst:IsA("Texture") then
			saved[inst] = { Transparency = inst.Transparency }
			inst.Transparency = 1
		elseif inst:IsA("MeshPart") then
			saved[inst] = { TextureID = inst.TextureID, Material = inst.Material }
			inst.TextureID = ""
			inst.Material = Enum.Material.SmoothPlastic
		elseif inst:IsA("BasePart") then
			saved[inst] = { Material = inst.Material }
			inst.Material = Enum.Material.SmoothPlastic
		elseif inst:IsA("SurfaceAppearance") then
			saved[inst] = { Parent = inst.Parent }
			inst.Parent = nil
		end
	end

	function F.noTextures(on)
		if on then
			for _, inst in ipairs(workspace:GetDescendants()) do strip(inst) end
			conn = workspace.DescendantAdded:Connect(strip)
		else
			if conn then conn:Disconnect() conn = nil end
			for inst, props in pairs(saved) do
				for name, value in pairs(props) do
					pcall(function() inst[name] = value end)
				end
			end
			table.clear(saved)
		end
	end
end

-- Super FPS
do
	local saved, conns, restore = {}, {}, {}
	local token = 0

	local function remember(inst, prop)
		local t = saved[inst]
		if not t then t = {} saved[inst] = t end
		if t[prop] == nil then t[prop] = inst[prop] end
	end

	local function isOtherCharacter(model)
		if not model then return false end
		local plr = Players:GetPlayerFromCharacter(model)
		return plr ~= nil and plr ~= player
	end

	local function optimize(inst)
		if inst:IsA("Terrain") then return end
		if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
			or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles")
			or inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight")
			or inst:IsA("PostEffect") or inst:IsA("Clouds") then
			remember(inst, "Enabled")
			inst.Enabled = false
		elseif inst:IsA("Atmosphere") then
			remember(inst, "Density")
			inst.Density = 0
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			remember(inst, "Transparency")
			inst.Transparency = 1
		elseif inst:IsA("SurfaceAppearance") then
			remember(inst, "Parent")
			inst.Parent = nil
		elseif inst:IsA("Accessory") or inst:IsA("Clothing") or inst:IsA("ShirtGraphic") then
			if isOtherCharacter(inst.Parent) then
				remember(inst, "Parent")
				inst.Parent = nil
			end
		elseif inst:IsA("MeshPart") then
			remember(inst, "RenderFidelity")
			remember(inst, "CastShadow")
			remember(inst, "Material")
			remember(inst, "Reflectance")
			remember(inst, "TextureID")
			inst.RenderFidelity = Enum.RenderFidelity.Performance
			inst.CastShadow = false
			inst.Material = Enum.Material.SmoothPlastic
			inst.Reflectance = 0
			inst.TextureID = ""
		elseif inst:IsA("BasePart") then
			remember(inst, "CastShadow")
			remember(inst, "Material")
			remember(inst, "Reflectance")
			inst.CastShadow = false
			inst.Material = Enum.Material.SmoothPlastic
			inst.Reflectance = 0
		end
	end

	local function setGlobal(obj, prop, value)
		pcall(function()
			local old = obj[prop]
			obj[prop] = value
			table.insert(restore, function()
				pcall(function() obj[prop] = old end)
			end)
		end)
	end

	function F.superFps(on)
		token += 1
		local my = token
		if on then
			setGlobal(Lighting, "GlobalShadows", false)
			setGlobal(Lighting, "EnvironmentSpecularScale", 0)
			setGlobal(Lighting, "EnvironmentDiffuseScale", 0)
			setGlobal(Lighting, "ShadowSoftness", 0)

			local terrain = workspace.Terrain
			setGlobal(terrain, "Decoration", false)
			setGlobal(terrain, "WaterWaveSize", 0)
			setGlobal(terrain, "WaterWaveSpeed", 0)
			setGlobal(terrain, "WaterReflectance", 0)

			pcall(function()
				local rendering = settings().Rendering
				setGlobal(rendering, "QualityLevel", Enum.QualityLevel.Level01)
				setGlobal(rendering, "MeshPartDetailLevel", Enum.MeshPartDetailLevel.Level04)
			end)

			conns = {
				workspace.DescendantAdded:Connect(optimize),
				Lighting.DescendantAdded:Connect(optimize),
			}
			task.spawn(function()
				local n = 0
				for _, root in ipairs({ workspace, Lighting }) do
					for _, inst in ipairs(root:GetDescendants()) do
						if token ~= my then return end
						optimize(inst)
						n += 1
						if n % 300 == 0 then task.wait() end
					end
				end
			end)
		else
			for _, c in ipairs(conns) do c:Disconnect() end
			conns = {}
			for _, undo in ipairs(restore) do undo() end
			restore = {}
			for inst, props in pairs(saved) do
				for name, value in pairs(props) do
					pcall(function() inst[name] = value end)
				end
			end
			table.clear(saved)
		end
	end
end

do
	local saved
	function F.noShadows(on)
		if on then
			saved = Lighting.GlobalShadows
			Lighting.GlobalShadows = false
		elseif saved ~= nil then
			Lighting.GlobalShadows = saved
			saved = nil
		end
	end
end

do
	local saved, conn = {}, nil
	local function kill(inst)
		if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
			or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
			if saved[inst] == nil then saved[inst] = inst.Enabled end
			inst.Enabled = false
		end
	end
	function F.noParticles(on)
		if on then
			for _, inst in ipairs(workspace:GetDescendants()) do kill(inst) end
			conn = workspace.DescendantAdded:Connect(kill)
		else
			if conn then conn:Disconnect() conn = nil end
			for inst, was in pairs(saved) do
				pcall(function() inst.Enabled = was end)
			end
			saved = {}
		end
	end
end

-- =====================================================
-- FEATURES: MISC
-- =====================================================
bind(player.Idled, function()
	if S.afk and not unloaded then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end)

function F.spectate(plr)
	local cam = workspace.CurrentCamera
	if plr and plr.Character then
		local h = plr.Character:FindFirstChildOfClass("Humanoid")
		if h then
			cam.CameraSubject = h
			notify("Viewing " .. plr.Name)
			log("spectating " .. plr.Name)
			return
		end
	end
	local h = getHum()
	if h then cam.CameraSubject = h end
end

function F.tpTo(plr)
	local root = getRoot()
	local r = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if root and r then
		S.lastPos = root.CFrame
		root.CFrame = r.CFrame * CFrame.new(0, 0, 3)
		notify("Teleported to " .. plr.Name)
		log("teleported to " .. plr.Name)
	end
end

-- Click delete (hold R and click, local only)
do
	local deleted = {}
	bind(UIS.InputBegan, function(input, processed)
		if unloaded or processed or not S.cd then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.R) then
			local t = mouse.Target
			if t and not (player.Character and t:IsDescendantOf(player.Character)) and not t:IsA("Terrain") then
				table.insert(deleted, { inst = t, parent = t.Parent })
				t.Parent = nil
				log("deleted " .. t.Name)
			end
		end
	end)

	function F.restoreDeleted()
		local last = table.remove(deleted)
		if last and last.inst then
			pcall(function() last.inst.Parent = last.parent end)
			notify("Restored " .. last.inst.Name)
		else
			notify("Nothing to restore", false)
		end
	end
end

-- Volume
function F.getVolume()
	local ok, v = pcall(function() return UserSettings():GetService("UserGameSettings").MasterVolume end)
	return ok and math.floor(v * 100 + 0.5) or 100
end

function F.setVolume(v)
	pcall(function() UserSettings():GetService("UserGameSettings").MasterVolume = v / 100 end)
end

-- Respawn where you died
bind(RunService.Heartbeat, function()
	if not S.respawnHere then return end
	local hum, root = getHum(), getRoot()
	if hum and root and hum.Health > 0 then S.lastAlive = root.CFrame end
end)

-- Waypoints
do
	local counter = 0

	function F.saveWaypoint(name)
		local root = getRoot()
		if not root then return end
		counter += 1
		name = name or ("WP" .. counter)
		table.insert(waypoints, { name = name, cf = root.CFrame })
		notify("Saved " .. name)
		if UI.rebuildWaypoints then UI.rebuildWaypoints() end
	end

	function F.goWaypoint(w)
		local root = getRoot()
		if root and w then
			root.CFrame = w.cf
			notify("Teleported to " .. w.name)
		end
	end

	function F.tpSpawn()
		local root = getRoot()
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		if root and spawn then
			root.CFrame = spawn.CFrame + Vector3.new(0, 5, 0)
			notify("Teleported to spawn")
		else
			notify("No spawn found", false)
		end
	end
end

-- Respawn handling
bind(player.CharacterAdded, function(char)
	char:WaitForChild("Humanoid")
	char:WaitForChild("HumanoidRootPart")
	F.captureDefaults()
	F.applyStats()
	if S.flyOn and not unloaded then
		task.wait(0.2)
		F.flyRestart()
	end
	if S.respawnHere and S.lastAlive and not unloaded then
		task.wait(0.4)
		local r = getRoot()
		if r then r.CFrame = S.lastAlive end
	end
end)

-- =====================================================
-- EXTRA FEATURES
-- =====================================================
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")

-- Hip height
do
	local orig
	function F.hipHeight(on)
		local hum = getHum()
		if not hum then return end
		if on then
			if orig == nil then orig = hum.HipHeight end
			hum.HipHeight = cfg.hip
		elseif orig ~= nil then
			hum.HipHeight = orig
			orig = nil
		end
	end
	function F.hipUpdate()
		local hum = getHum()
		if hum and orig ~= nil then hum.HipHeight = cfg.hip end
	end
end

-- Camera offset
do
	local active = false
	function F.camOffset(on)
		active = on
		local hum = getHum()
		if hum then hum.CameraOffset = on and Vector3.new(cfg.camX, cfg.camY, 0) or Vector3.zero end
	end
	function F.camOffsetUpdate()
		local hum = getHum()
		if hum and active then hum.CameraOffset = Vector3.new(cfg.camX, cfg.camY, 0) end
	end
end

-- Anti ragdoll
do
	local states = { Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown }
	function F.antiRagdoll(on)
		local hum = getHum()
		if not hum then return end
		for _, st in ipairs(states) do
			pcall(function() hum:SetStateEnabled(st, not on) end)
		end
	end
end

-- Wall climb (hold Space against a wall)
do
	local conn
	function F.wallClimb(on)
		if conn then conn:Disconnect() conn = nil end
		if not on then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		conn = RunService.Heartbeat:Connect(function()
			local root = getRoot()
			if not root or not player.Character then return end
			if typing() or not UIS:IsKeyDown(Enum.KeyCode.Space) then return end
			params.FilterDescendantsInstances = { player.Character }
			local hit = workspace:Raycast(root.Position, root.CFrame.LookVector * 3, params)
			if hit then
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(v.X, cfg.climb, v.Z)
			end
		end)
	end
end

-- Blink forward
do
	local last = 0
	function F.blink()
		if os.clock() - last < 0.5 then return end
		local root = getRoot()
		if not root then return end
		last = os.clock()
		S.lastPos = root.CFrame
		root.CFrame = root.CFrame + root.CFrame.LookVector * cfg.blink
	end
end

-- Platforms (local only)
do
	local parts = {}
	function F.platform()
		local root = getRoot()
		if not root then return end
		local part = new("Part", {
			Size = Vector3.new(14, 1, 14),
			Anchored = true,
			Material = Enum.Material.Neon,
			Color = accent,
			Transparency = 0.35,
			CFrame = root.CFrame * CFrame.new(0, -3.5, 0),
		}, workspace)
		table.insert(parts, part)
		notify("Platform placed")
	end
	function F.clearPlatforms()
		for _, part in ipairs(parts) do part:Destroy() end
		parts = {}
		notify("Platforms removed")
	end
end

function F.sit()
	local hum = getHum()
	if hum then hum.Sit = true end
end

function F.showPos()
	local root = getRoot()
	if root then
		local p = root.Position
		notify(string.format("XYZ %d, %d, %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z)))
	end
end

-- Hide other players
do
	local conn
	local function apply(v)
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then
				for _, part in ipairs(plr.Character:GetDescendants()) do
					if part:IsA("BasePart") then
						pcall(function() part.LocalTransparencyModifier = v end)
					end
				end
			end
		end
	end
	function F.hidePlayers(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			local last = 0
			conn = RunService.Heartbeat:Connect(function()
				if os.clock() - last < 0.25 then return end
				last = os.clock()
				apply(1)
			end)
		else
			apply(0)
		end
	end
end

-- Hide name tags
do
	local conn
	local saved = {}
	function F.hideNames(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			local last = 0
			conn = RunService.Heartbeat:Connect(function()
				if os.clock() - last < 0.5 then return end
				last = os.clock()
				for _, plr in ipairs(Players:GetPlayers()) do
					local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
					if h and h.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
						saved[h] = h.DisplayDistanceType
						h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
					end
				end
			end)
		else
			for h, v in pairs(saved) do
				pcall(function() h.DisplayDistanceType = v end)
			end
			saved = {}
		end
	end
end

-- Post effects
do
	local fx
	function F.blur(on)
		if fx then fx:Destroy() fx = nil end
		if on then fx = new("BlurEffect", { Size = cfg.blur }, Lighting) end
	end
	function F.blurUpdate()
		if fx then fx.Size = cfg.blur end
	end
end

do
	local fx
	function F.dof(on)
		if fx then fx:Destroy() fx = nil end
		if on then
			fx = new("DepthOfFieldEffect", {
				FarIntensity = 0.6, NearIntensity = 0, InFocusRadius = 20, FocusDistance = cfg.dof,
			}, Lighting)
		end
	end
	function F.dofUpdate()
		if fx then fx.FocusDistance = cfg.dof end
	end
end

do
	local fx
	function F.sunRays(on)
		if fx then fx:Destroy() fx = nil end
		if on then fx = new("SunRaysEffect", { Intensity = cfg.rays / 100, Spread = 0.8 }, Lighting) end
	end
	function F.sunRaysUpdate()
		if fx then fx.Intensity = cfg.rays / 100 end
	end
end

-- Lighting property modules (restore on off)
do
	local function prop(name, valueFn)
		local saved, active = nil, false
		local function toggle(on)
			active = on
			if on then
				saved = Lighting[name]
				Lighting[name] = valueFn()
			elseif saved ~= nil then
				Lighting[name] = saved
				saved = nil
			end
		end
		local function update()
			if active then Lighting[name] = valueFn() end
		end
		return toggle, update
	end
	F.exposure, F.exposureUpdate = prop("ExposureCompensation", function() return cfg.exposure / 10 end)
	F.brightness, F.brightnessUpdate = prop("Brightness", function() return cfg.brightness / 10 end)
	F.fogDist, F.fogDistUpdate = prop("FogEnd", function() return cfg.fogDist end)
end

-- No sky
do
	local saved = {}
	function F.noSky(on)
		if on then
			for _, sky in ipairs(Lighting:GetChildren()) do
				if sky:IsA("Sky") then
					saved[sky] = sky.CelestialBodiesShown
					sky.CelestialBodiesShown = false
				end
			end
			local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
			if clouds then
				saved[clouds] = clouds.Enabled
				clouds.Enabled = false
			end
		else
			for obj, v in pairs(saved) do
				pcall(function()
					if obj:IsA("Sky") then obj.CelestialBodiesShown = v else obj.Enabled = v end
				end)
			end
			saved = {}
		end
	end
end

-- Disco lights
do
	local conn, hue, saved = nil, 0, nil
	function F.disco(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			saved = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
			conn = RunService.Heartbeat:Connect(function(dt)
				hue = (hue + dt * cfg.disco / 20) % 1
				local c = Color3.fromHSV(hue, 0.8, 1)
				Lighting.Ambient = c
				Lighting.OutdoorAmbient = c
			end)
		elseif saved then
			Lighting.Ambient = saved.Ambient
			Lighting.OutdoorAmbient = saved.OutdoorAmbient
			saved = nil
		end
	end
end

-- Weather (snow and rain follow your camera)
do
	local function makeWeather(rateKey, props)
		local part, conn
		return function(on)
			if conn then conn:Disconnect() conn = nil end
			if part then part:Destroy() part = nil end
			if not on then return end
			part = new("Part", {
				Size = Vector3.new(90, 1, 90),
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Transparency = 1,
			}, workspace)
			local em = new("ParticleEmitter", {
				Rate = cfg[rateKey],
				Lifetime = NumberRange.new(props.life),
				Speed = NumberRange.new(props.speed),
				EmissionDirection = Enum.NormalId.Bottom,
				SpreadAngle = Vector2.new(props.spread, props.spread),
				Size = NumberSequence.new(props.size),
				Color = ColorSequence.new(props.color),
				Transparency = NumberSequence.new(props.transp),
				LightEmission = props.light,
				Acceleration = Vector3.new(0, -props.gravity, 0),
				Orientation = props.orient or Enum.ParticleOrientation.FacingCamera,
			}, part)
			conn = RunService.Heartbeat:Connect(function()
				local cam = workspace.CurrentCamera
				if part and cam then
					part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 35, 0))
					em.Rate = cfg[rateKey]
				end
			end)
		end
	end
	F.snow = makeWeather("snow", {
		life = 3, speed = 8, spread = 20, size = 0.25, color = Color3.new(1, 1, 1),
		transp = 0.2, light = 0.3, gravity = 4,
	})
	F.rainfall = makeWeather("rainRate", {
		life = 1.2, speed = 60, spread = 3, size = 0.6, color = Color3.fromRGB(170, 200, 255),
		transp = 0.45, light = 0.1, gravity = 40, orient = Enum.ParticleOrientation.VelocityParallel,
	})
end

-- Graphics quality + no grass
do
	local orig
	local function apply(on)
		pcall(function()
			local r = settings().Rendering
			if on then
				if orig == nil then orig = r.QualityLevel end
				r.QualityLevel = Enum.QualityLevel["Level" .. string.format("%02d", cfg.quality)]
			elseif orig ~= nil then
				r.QualityLevel = orig
				orig = nil
			end
		end)
	end
	function F.quality(on) apply(on) end
	function F.qualityUpdate()
		if orig ~= nil then apply(true) end
	end
end

do
	local orig
	function F.noGrass(on)
		local t = workspace.Terrain
		if on then
			orig = t.Decoration
			t.Decoration = false
		elseif orig ~= nil then
			t.Decoration = orig
			orig = nil
		end
	end
end

-- Auto rejoin when disconnected
do
	local conn
	function F.autoRejoin(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = GuiService.ErrorMessageChanged:Connect(function()
				if unloaded then return end
				task.wait(1)
				pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
			end)
		end
	end
end

-- Hide parts of the default Roblox UI
function F.coreGui(kind)
	return function(on)
		pcall(function() StarterGui:SetCoreGuiEnabled(kind, not on) end)
	end
end

-- Spectate next / previous
do
	local idx = 0
	function F.spectateStep(dir)
		local list = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then table.insert(list, plr) end
		end
		if #list == 0 then
			notify("No players found", false)
			return
		end
		idx = ((idx - 1 + dir) % #list) + 1
		F.spectate(list[idx])
	end
end

-- Panic: turn every module off
function F.panic()
	for _, m in ipairs(modules) do
		if m.on and not m.def.keep and not m.def.noHud then setModule(m, false, true) end
	end
	notify("Everything turned off")
end

-- =====================================================
-- MORE FEATURES
-- =====================================================

-- Attach to a player (head sit, piggyback, front, orbit, above)
do
	local conn, mode, angle = nil, "Head", 0
	F.attachModes = { "Head", "Back", "Front", "Orbit", "Above" }

	function F.setAttachMode(m) mode = m end
	function F.getAttachMode() return mode end

	function F.attach(plr)
		if conn then conn:Disconnect() conn = nil end
		S.attachTarget = plr
		if not plr then
			local hum = getHum()
			if hum then hum.Sit = false end
			return
		end
		conn = RunService.Heartbeat:Connect(function(dt)
			local root, hum = getRoot(), getHum()
			local tc = plr.Character
			local tr = tc and tc:FindFirstChild("HumanoidRootPart")
			local th = tc and tc:FindFirstChild("Head")
			if not root or not tr then return end

			local cf
			if mode == "Head" then
				cf = (th or tr).CFrame * CFrame.new(0, 2.2, 0)
			elseif mode == "Back" then
				cf = tr.CFrame * CFrame.new(0, 0.4, 1.2)
			elseif mode == "Front" then
				local pos = (tr.CFrame * CFrame.new(0, 0, -4)).Position
				cf = CFrame.lookAt(pos, tr.Position)
			elseif mode == "Orbit" then
				angle += dt * 2.5
				local pos = tr.Position + Vector3.new(math.cos(angle) * 7, 1, math.sin(angle) * 7)
				cf = CFrame.lookAt(pos, tr.Position)
			else
				cf = tr.CFrame * CFrame.new(0, 10, 0)
			end

			root.CFrame = cf
			root.AssemblyLinearVelocity = Vector3.zero
			if hum and (mode == "Head" or mode == "Back") then hum.Sit = true end
		end)
	end
end

-- Camera goes through walls
do
	local orig
	function F.camThrough(on)
		if on then
			if orig == nil then orig = player.DevCameraOcclusionMode end
			player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
		elseif orig ~= nil then
			player.DevCameraOcclusionMode = orig
			orig = nil
		end
	end
end

-- Allow zooming all the way in
do
	local orig
	function F.closeZoom(on)
		if on then
			if orig == nil then orig = player.CameraMinZoomDistance end
			player.CameraMinZoomDistance = 0.5
		elseif orig ~= nil then
			player.CameraMinZoomDistance = orig
			orig = nil
		end
	end
end

-- Auto walk
do
	local NAME = "NexusAutoWalk"
	local bound = false
	function F.autoWalk(on)
		if bound then
			RunService:UnbindFromRenderStep(NAME)
			bound = false
		end
		if on then
			RunService:BindToRenderStep(NAME, Enum.RenderPriority.Character.Value + 5, function()
				local hum = getHum()
				if hum and not typing() and not S.flyOn and not S.freecam then
					hum:Move(Vector3.new(0, 0, -1), true)
				end
			end)
			bound = true
		end
	end
end

-- Auto jump
do
	local conn
	function F.autoJump(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			conn = RunService.Heartbeat:Connect(function()
				local hum = getHum()
				if hum and hum.MoveDirection.Magnitude > 0 and hum.FloorMaterial ~= Enum.Material.Air then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end)
		end
	end
end

-- Freeze yourself in place
function F.freezeMe(on)
	local root = getRoot()
	if root then root.Anchored = on end
end

-- Character size (R15, only you see it)
do
	local names = { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" }
	local saved = {}
	local active = false

	local function apply(v)
		local hum = getHum()
		if not hum then return end
		for _, n in ipairs(names) do
			local val = hum:FindFirstChild(n)
			if val and val:IsA("NumberValue") then
				if saved[n] == nil then saved[n] = val.Value end
				val.Value = v
			end
		end
	end

	function F.charSize(on)
		active = on
		if on then
			apply(cfg.size / 100)
		else
			local hum = getHum()
			if hum then
				for n, v in pairs(saved) do
					local val = hum:FindFirstChild(n)
					if val then val.Value = v end
				end
			end
			saved = {}
		end
	end

	function F.charSizeUpdate()
		if active then apply(cfg.size / 100) end
	end
end

-- Light aura
do
	local light
	function F.aura(on)
		if light then light:Destroy() light = nil end
		local root = getRoot()
		if on and root then
			light = new("PointLight", { Color = accent, Brightness = 4, Range = cfg.aura }, root)
		end
	end
	function F.auraUpdate()
		if light then light.Range = cfg.aura end
	end
end

-- Trail
do
	local trail, a0, a1
	function F.trail(on)
		if trail then trail:Destroy() trail = nil end
		if a0 then a0:Destroy() a0 = nil end
		if a1 then a1:Destroy() a1 = nil end
		local root = getRoot()
		if on and root then
			a0 = new("Attachment", { Position = Vector3.new(0, 1, 0) }, root)
			a1 = new("Attachment", { Position = Vector3.new(0, -1, 0) }, root)
			trail = new("Trail", {
				Attachment0 = a0,
				Attachment1 = a1,
				Lifetime = 1,
				LightEmission = 1,
				FaceCamera = true,
				Color = ColorSequence.new(accent, Color3.new(1, 1, 1)),
				Transparency = NumberSequence.new(0.1, 1),
			}, root)
		end
	end
end

-- Night vision
do
	local fx
	function F.nightVision(on)
		if fx then fx:Destroy() fx = nil end
		if on then
			fx = new("ColorCorrectionEffect", {
				TintColor = Color3.fromRGB(120, 255, 120),
				Brightness = 0.25,
				Contrast = 0.2,
				Saturation = -0.3,
			}, Lighting)
		end
	end
end

-- Go back to where you were before the last teleport
function F.goBack()
	local root = getRoot()
	if root and S.lastPos then
		local cur = root.CFrame
		root.CFrame = S.lastPos
		S.lastPos = cur
		notify("Went back")
	else
		notify("No previous position", false)
	end
end

-- Far name tags (raises how far away Roblox shows names and health)
do
	local conn
	local saved = {}

	local function apply()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
				if h then
					if saved[h] == nil then
						saved[h] = { h.NameDisplayDistance, h.HealthDisplayDistance }
					end
					h.NameDisplayDistance = cfg.nameDist
					h.HealthDisplayDistance = cfg.nameDist
				end
			end
		end
	end

	function F.farNames(on)
		if conn then conn:Disconnect() conn = nil end
		if on then
			apply()
			local last = 0
			conn = RunService.Heartbeat:Connect(function()
				if os.clock() - last < 0.5 then return end
				last = os.clock()
				apply()
			end)
		else
			for h, v in pairs(saved) do
				pcall(function()
					h.NameDisplayDistance = v[1]
					h.HealthDisplayDistance = v[2]
				end)
			end
			saved = {}
		end
	end

	function F.farNamesUpdate()
		if conn then apply() end
	end
end

-- =====================================================
-- GUI: ROOT + OVERLAYS
-- =====================================================
UI.gui = new("ScreenGui", {
	Name = "NexusClient",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 50,
}, playerGui)

-- Draggable HUD elements (with a global lock)
UI.locked = false
UI.lastDragMove = 0
do
	local items = {}
	local drag

	function UI.makeDraggable(obj, grip)
		grip = grip or obj
		local item = { obj = obj, base = obj.Position, cur = Vector2.zero, target = Vector2.zero }
		table.insert(items, item)

		local stroke = new("UIStroke", {
			Thickness = 1.5,
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}, grip)
		reg(stroke, "Color")

		grip.MouseEnter:Connect(function()
			if not UI.locked then tween(stroke, { Transparency = 0.2 }, TI.fast) end
		end)
		grip.MouseLeave:Connect(function()
			tween(stroke, { Transparency = 1 }, TI.fast)
		end)
		grip.InputBegan:Connect(function(input)
			if UI.locked or not isPress(input) then return end
			drag = {
				item = item,
				start = Vector2.new(input.Position.X, input.Position.Y),
				base = item.target,
				moved = false,
			}
		end)
		return item
	end

	bind(UIS.InputChanged, function(input)
		if not drag then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local delta = Vector2.new(input.Position.X, input.Position.Y) - drag.start
		if delta.Magnitude > 4 then drag.moved = true end
		if drag.moved then
			drag.item.target = drag.base + delta
			UI.lastDragMove = os.clock()
		end
	end)

	bind(UIS.InputEnded, function(input)
		if isPress(input) then drag = nil end
	end)

	bind(RunService.RenderStepped, function(dt)
		local a = 1 - math.exp(-dt * 16)
		for _, it in ipairs(items) do
			if it.obj.Parent then
				it.cur = it.cur:Lerp(it.target, a)
				if (it.target - it.cur).Magnitude < 0.05 then it.cur = it.target end
				it.obj.Position = UDim2.new(
					it.base.X.Scale, it.base.X.Offset + it.cur.X,
					it.base.Y.Scale, it.base.Y.Offset + it.cur.Y)
			end
		end
	end)

	function UI.resetLayout()
		for _, it in ipairs(items) do it.target = Vector2.zero end
	end

	function UI.updateHandles()
		if UI.toastHandle then UI.toastHandle.Visible = UI.menuOpen and not UI.locked end
	end
end

-- Screen tint
do
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, UI.gui)
	local active = false
	local function apply()
		frame.BackgroundColor3 = Color3.fromHSV(cfg.tintHue / 360, 0.7, 1)
		frame.BackgroundTransparency = 1 - cfg.tintAlpha / 100
	end
	function F.screenTint(on)
		active = on
		frame.Visible = on
		if on then apply() end
	end
	function F.tintUpdate()
		if active then apply() end
	end
end

-- Cinematic bars
do
	local top = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	}, UI.gui)
	local bottom = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
	}, UI.gui)
	local active = false
	local function apply()
		local size = active and UDim2.new(1, 0, cfg.bars / 100, 0) or UDim2.new(1, 0, 0, 0)
		tween(top, { Size = size }, TI.quint)
		tween(bottom, { Size = size }, TI.quint)
	end
	function F.bars(on)
		active = on
		apply()
	end
	function F.barsUpdate()
		if active then apply() end
	end
end

-- Compass
do
	local label = new("TextLabel", {
		Size = UDim2.new(0, 160, 0, 24),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.Code,
		TextSize = 14,
		Text = "",
		Visible = false,
	}, UI.gui)
	corner(label, 6)
	reg(label, "TextColor3")
	local names = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
	UI.makeDraggable(label)
	local conn
	function F.compass(on)
		if conn then conn:Disconnect() conn = nil end
		label.Visible = on
		if on then
			conn = RunService.RenderStepped:Connect(function()
				local cam = workspace.CurrentCamera
				if not cam then return end
				local look = cam.CFrame.LookVector
				local deg = math.deg(math.atan2(look.X, -look.Z)) % 360
				local idx = math.floor((deg + 22.5) / 45) % 8 + 1
				label.Text = string.format("%s  %d deg", names[idx], math.floor(deg))
			end)
		end
	end
end

-- Clock HUD
do
	local label = new("TextLabel", {
		Size = UDim2.new(0, 230, 0, 24),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.Code,
		TextSize = 13,
		Text = "",
		Visible = false,
	}, UI.gui)
	corner(label, 6)
	reg(label, "TextColor3")
	local started = os.clock()
	UI.makeDraggable(label)
	local conn
	function F.clockHud(on)
		if conn then conn:Disconnect() conn = nil end
		label.Visible = on
		if on then
			local last = 0
			conn = RunService.Heartbeat:Connect(function()
				if os.clock() - last < 0.5 then return end
				last = os.clock()
				local sec = math.floor(os.clock() - started)
				label.Text = string.format("%s   session %02d:%02d", os.date("%H:%M:%S"),
					math.floor(sec / 60), sec % 60)
			end)
		end
	end
end

-- Matrix rain
do
	local frame = new("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
	}, UI.gui)

	local cols = {}
	local chars = "01ABCDEFGHJKLMNPQRSTUVWXYZ#$%&@"
	local ROWS, SIZE = 28, 14

	local function rand(n)
		local t = {}
		for i = 1, n do
			local k = math.random(1, #chars)
			t[i] = chars:sub(k, k)
		end
		return table.concat(t, "\n")
	end

	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local count = math.clamp(math.floor(vp.X / 26), 10, 56)
	for i = 1, count do
		local lbl = new("TextLabel", {
			Size = UDim2.new(0, 18, 0, ROWS * SIZE),
			Position = UDim2.new(0, (i - 1) * 26, 0, -math.random(0, 500)),
			BackgroundTransparency = 1,
			Text = rand(ROWS),
			Font = Enum.Font.Code,
			TextSize = SIZE,
			TextTransparency = 0.55,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, frame)
		reg(lbl, "TextColor3")
		table.insert(cols, { lbl = lbl, x = (i - 1) * 26, y = -math.random(0, 500), speed = math.random(90, 240) })
	end

	local conn
	function F.rain(on)
		if conn then conn:Disconnect() conn = nil end
		frame.Visible = on
		if on then
			conn = RunService.Heartbeat:Connect(function(dt)
				local vpY = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720
				for _, c in ipairs(cols) do
					c.y += c.speed * dt
					if c.y > vpY then
						c.y = -ROWS * SIZE
						c.lbl.Text = rand(ROWS)
					end
					c.lbl.Position = UDim2.new(0, c.x, 0, c.y)
				end
			end)
		end
	end
end

-- Crosshair
do
	local crosshair = new("Frame", {
		Size = UDim2.new(0, 24, 0, 24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 1,
		Visible = false,
	}, UI.gui)
	for _, spec in ipairs({
		{ UDim2.new(0, 2, 0, 8), UDim2.new(0.5, -1, 0, 0) },
		{ UDim2.new(0, 2, 0, 8), UDim2.new(0.5, -1, 1, -8) },
		{ UDim2.new(0, 8, 0, 2), UDim2.new(0, 0, 0.5, -1) },
		{ UDim2.new(0, 8, 0, 2), UDim2.new(1, -8, 0.5, -1) },
	}) do
		reg(new("Frame", { Size = spec[1], Position = spec[2], BorderSizePixel = 0 }, crosshair), "BackgroundColor3")
	end
	function F.crosshair(on) crosshair.Visible = on end
end

-- Module list (top right, animated rows)
UI.hud = new("Frame", {
	Size = UDim2.new(0, 220, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	BackgroundTransparency = 1,
}, UI.gui)
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, UI.hud)
UI.hudMark = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 18),
	BackgroundTransparency = 1,
	Text = "NEXUS v7 ",
	Font = Enum.Font.Code,
	TextSize = 15,
	TextStrokeTransparency = 0.5,
	TextXAlignment = Enum.TextXAlignment.Right,
	LayoutOrder = -100000,
}, UI.hud)
reg(UI.hudMark, "TextColor3")
UI.makeDraggable(UI.hud)

-- Notifications (bottom right)
UI.toasts = new("Frame", {
	Size = UDim2.new(0, 240, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -10),
	BackgroundTransparency = 1,
}, UI.gui)
new("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Bottom,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, UI.toasts)
UI.toastHandle = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundColor3 = PANEL,
	Text = "[ notifications - drag me ]",
	TextColor3 = SUB,
	Font = Enum.Font.Code,
	TextSize = 12,
	LayoutOrder = -1000000,
	Visible = false,
}, UI.toasts)
corner(UI.toastHandle, 6)
UI.makeDraggable(UI.toasts, UI.toastHandle)

-- FPS counter
UI.currentFps = 0
do
	local label = new("TextLabel", {
		Size = UDim2.new(0, 90, 0, 24),
		Position = UDim2.new(0, 12, 0, 48),
		BackgroundColor3 = PANEL,
		Font = Enum.Font.Code,
		TextSize = 13,
		Text = "-- FPS",
		Visible = false,
	}, UI.gui)
	corner(label, 6)
	reg(label, "TextColor3")

	UI.makeDraggable(label)

	local frames, last = 0, os.clock()
	bind(RunService.RenderStepped, function()
		frames += 1
		local now = os.clock()
		if now - last >= 0.5 then
			UI.currentFps = math.floor(frames / (now - last) + 0.5)
			frames = 0
			last = now
			if label.Visible then label.Text = UI.currentFps .. " FPS" end
		end
	end)

	function F.fpsCounter(on) label.Visible = on end
end

-- Info HUD (bottom left)
do
	local label = new("TextLabel", {
		Size = UDim2.new(0, 240, 0, 76),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Visible = false,
	}, UI.gui)
	corner(label, 8)
	reg(label, "TextColor3")
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10) }, label)
	UI.makeDraggable(label)

	local conn
	function F.infoHud(on)
		if conn then conn:Disconnect() conn = nil end
		label.Visible = on
		if on then
			local last = 0
			conn = RunService.Heartbeat:Connect(function()
				if os.clock() - last < 0.1 then return end
				last = os.clock()
				local root = getRoot()
				if not root then return end
				local p, v = root.Position, root.AssemblyLinearVelocity
				label.Text = string.format("XYZ    %d, %d, %d\nSpeed  %d studs/s\nPing   %s\nFPS    %d",
					math.floor(p.X), math.floor(p.Y), math.floor(p.Z), math.floor(v.Magnitude), getPing(), UI.currentFps)
			end)
		end
	end
end

-- Inspector (what is under your mouse)
do
	local label = new("TextLabel", {
		Size = UDim2.new(0, 460, 0, 24),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.15,
		Font = Enum.Font.Code,
		TextSize = 12,
		Text = "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = false,
	}, UI.gui)
	corner(label, 6)
	reg(label, "TextColor3")

	UI.makeDraggable(label)

	local conn
	function F.inspector(on)
		if conn then conn:Disconnect() conn = nil end
		label.Visible = on
		if on then
			local last = 0
			conn = RunService.Heartbeat:Connect(function()
				if os.clock() - last < 0.1 then return end
				last = os.clock()
				local t = mouse.Target
				label.Text = t and (t:GetFullName() .. "  [" .. t.ClassName .. "]") or "(nothing)"
			end)
		end
	end
end

-- Open button
UI.openBtn = new("TextButton", {
	Size = UDim2.new(0, 100, 0, 30),
	Position = UDim2.new(0, 12, 0, 12),
	BackgroundColor3 = PANEL,
	Font = Enum.Font.Code,
	TextSize = 14,
	Text = "[ NEXUS ]",
	AutoButtonColor = false,
}, UI.gui)
corner(UI.openBtn, 6)
reg(UI.openBtn, "TextColor3")
reg(new("UIStroke", { Thickness = 1 }, UI.openBtn), "Color")
hover(UI.openBtn, PANEL, HOVER)
pressFx(UI.openBtn)
UI.makeDraggable(UI.openBtn)

-- =====================================================
-- GUI: MAIN WINDOW
-- =====================================================
UI.tabNames = {
	"Movement", "Visuals", "World", "Players", "Teleport",
	"Performance", "Console", "Misc", "Settings",
}
UI.pages = {}
UI.currentTab = "Movement"
UI.menuOpen = false
UI.menuKey = Enum.KeyCode.RightShift
UI.baseTransp = 0
UI.uiBase = 1
UI.autoBase = 1
UI.overConsole = false

do
	local gui = UI.gui

	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	UI.autoBase = math.clamp(math.min(vp.X / (WIN_W + 60), vp.Y / (WIN_H + 60)), 0.5, 1)
	UI.uiBase = UI.autoBase

	-- shadow
	local shadow = new("Frame", {
		Size = UDim2.new(0, WIN_W + 40, 0, WIN_H + 40),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	corner(shadow, 22)
	local shadowScale = new("UIScale", {}, shadow)

	-- window (CanvasGroup so the whole thing can fade)
	local window = new("CanvasGroup", {
		Size = UDim2.new(0, WIN_W, 0, WIN_H),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = BG,
		GroupTransparency = 1,
		Visible = false,
	}, gui)
	corner(window, 12)
	reg(new("UIStroke", { Thickness = 1.5 }, window), "Color")
	local uiScale = new("UIScale", { Scale = UI.uiBase }, window)
	UI.window = window

	-- title bar
	local titleBar = new("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
	}, window)

	local titleText = new("TextLabel", {
		Size = UDim2.new(0, 160, 1, 0),
		Position = UDim2.new(0, 16, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 19,
		Text = "NEXUS CLIENT",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, titleBar)
	reg(titleText, "TextColor3")

	new("TextLabel", {
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.new(0, 172, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextColor3 = SUB,
		Text = "v7.0  |  injected",
		TextXAlignment = Enum.TextXAlignment.Left,
	}, titleBar)

	local closeBtn = new("TextButton", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -38, 0, 6),
		BackgroundColor3 = CARD,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = "X",
		AutoButtonColor = false,
	}, titleBar)
	corner(closeBtn, 6)
	hover(closeBtn, CARD, RED)
	pressFx(closeBtn)

	-- title glitch
	task.spawn(function()
		local base = titleText.Text
		local chars = "01#@$%&?"
		while gui.Parent do
			task.wait(math.random(4, 8))
			for _ = 1, 5 do
				if not gui.Parent then return end
				local s = ""
				for i = 1, #base do
					if base:sub(i, i) ~= " " and math.random() < 0.35 then
						local k = math.random(1, #chars)
						s ..= chars:sub(k, k)
					else
						s ..= base:sub(i, i)
					end
				end
				titleText.Text = s
				task.wait(0.05)
			end
			titleText.Text = base
		end
	end)

	-- footer
	local footer = new("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.new(0, 0, 1, -28),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
	}, window)
	UI.footer = new("TextLabel", {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 14, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "> ready",
	}, footer)
	reg(UI.footer, "TextColor3")

	-- sidebar with a sliding highlight
	local sidebar = new("Frame", {
		Size = UDim2.new(0, 160, 1, -68),
		Position = UDim2.new(0, 0, 0, 40),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
	}, window)

	local hl = new("Frame", {
		Size = UDim2.new(1, -16, 0, 34),
		Position = UDim2.new(0, 8, 0, 8),
		BackgroundColor3 = CARD,
	}, sidebar)
	corner(hl, 6)
	local hlBar = reg(new("Frame", {
		Size = UDim2.new(0, 3, 0, 18),
		Position = UDim2.new(0, 0, 0.5, -9),
		BorderSizePixel = 0,
	}, hl), "BackgroundColor3")
	corner(hlBar, 2)

	local list = new("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, sidebar)
	new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, list)
	new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	-- content area
	local content = new("Frame", {
		Size = UDim2.new(1, -160, 1, -68),
		Position = UDim2.new(0, 160, 0, 40),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
	}, window)

	local holders, tabBtns = {}, {}
	local smooth = UIS.MouseEnabled and not UIS.TouchEnabled

	function UI.selectTab(name)
		UI.overConsole = false
		local idx = 1
		for i, n in ipairs(UI.tabNames) do
			if n == name then idx = i end
		end
		UI.currentTab = name
		for n, h in pairs(holders) do
			if n == name then
				if not h.Visible then
					h.Position = UDim2.new(0, 22, 0, 0)
					h.GroupTransparency = 1
					h.Visible = true
					tween(h, { Position = UDim2.new(0, 0, 0, 0), GroupTransparency = 0 }, TI.quint)
				end
			else
				h.Visible = false
			end
		end
		tween(hl, { Position = UDim2.new(0, 8, 0, 8 + (idx - 1) * 37) }, TI.quint)
		for n, b in pairs(tabBtns) do
			tween(b, { TextColor3 = (n == name) and accent or SUB })
		end
	end

	for _, name in ipairs(UI.tabNames) do
		local holder = new("CanvasGroup", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Visible = false,
		}, content)
		local page = new("ScrollingFrame", {
			Size = UDim2.new(1, -12, 1, -12),
			Position = UDim2.new(0, 6, 0, 6),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollingEnabled = not smooth,
		}, holder)
		reg(page, "ScrollBarImageColor3")
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)
		new("UIPadding", { PaddingRight = UDim.new(0, 8) }, page)
		holders[name] = holder
		UI.pages[name] = page

		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = HOVER,
			BackgroundTransparency = 1,
			Font = Enum.Font.Code,
			TextSize = 14,
			TextColor3 = SUB,
			Text = name,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = false,
			LayoutOrder = nextOrder(),
		}, list)
		new("UIPadding", { PaddingLeft = UDim.new(0, 14) }, btn)
		corner(btn, 6)
		tabBtns[name] = btn

		btn.MouseButton1Click:Connect(function() UI.selectTab(name) end)
		btn.MouseEnter:Connect(function()
			if UI.currentTab ~= name then tween(btn, { BackgroundTransparency = 0.55 }, TI.fast) end
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, { BackgroundTransparency = 1 }, TI.fast)
		end)
	end

	-- smooth mouse wheel scrolling
	if smooth then
		local targets = {}
		bind(UIS.InputChanged, function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
			if not window.Visible or UI.overConsole then return end
			local page = UI.pages[UI.currentTab]
			if not page then return end
			local m = UIS:GetMouseLocation()
			local p, s = window.AbsolutePosition, window.AbsoluteSize
			if m.X < p.X or m.X > p.X + s.X or m.Y < p.Y or m.Y > p.Y + s.Y then return end
			local maxY = math.max(0, page.AbsoluteCanvasSize.Y - page.AbsoluteWindowSize.Y)
			local base = targets[page] or page.CanvasPosition.Y
			targets[page] = math.clamp(base - input.Position.Z * 90, 0, maxY)
		end)
		bind(RunService.RenderStepped, function(dt)
			for page, tgt in pairs(targets) do
				local maxY = math.max(0, page.AbsoluteCanvasSize.Y - page.AbsoluteWindowSize.Y)
				tgt = math.clamp(tgt, 0, maxY)
				targets[page] = tgt
				local cur = page.CanvasPosition.Y
				if math.abs(tgt - cur) > 0.3 then
					page.CanvasPosition = Vector2.new(0, cur + (tgt - cur) * (1 - math.exp(-dt * 14)))
				end
			end
		end)
	end

	-- keep the mouse wheel from zooming the game camera while it is over the menu
	do
		local CAS = game:GetService("ContextActionService")
		local savedMin, savedMax, lockedDist, releaseAt

		local function overWindow()
			if not window.Visible then return false end
			local m = UIS:GetMouseLocation()
			local p, sz = window.AbsolutePosition, window.AbsoluteSize
			return m.X >= p.X and m.X <= p.X + sz.X and m.Y >= p.Y and m.Y <= p.Y + sz.Y
		end

		-- layer 1: swallow the wheel before the camera sees it
		CAS:BindActionAtPriority("NexusWheel", function()
			if overWindow() then return Enum.ContextActionResult.Sink end
			return Enum.ContextActionResult.Pass
		end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseWheel)

		-- layer 2: briefly freeze the zoom distance in case the camera still reacts
		local function release()
			if savedMin ~= nil then
				pcall(function()
					if player.CameraMaxZoomDistance == lockedDist then player.CameraMaxZoomDistance = savedMax end
					if player.CameraMinZoomDistance == lockedDist then player.CameraMinZoomDistance = savedMin end
				end)
			end
			savedMin, savedMax, lockedDist, releaseAt = nil, nil, nil, nil
		end

		function UI.blockZoom()
			local cam = workspace.CurrentCamera
			if not cam then return end
			if savedMin == nil then
				savedMin, savedMax = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
				lockedDist = math.clamp((cam.CFrame.Position - cam.Focus.Position).Magnitude, savedMin, savedMax)
				pcall(function()
					player.CameraMinZoomDistance = lockedDist
					player.CameraMaxZoomDistance = lockedDist
				end)
			end
			releaseAt = os.clock() + 0.25
		end

		bind(UIS.InputChanged, function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel and overWindow() then
				UI.blockZoom()
			end
		end)

		bind(RunService.Heartbeat, function()
			if releaseAt and os.clock() > releaseAt then release() end
		end)

		function UI.unbindWheel()
			release()
			CAS:UnbindAction("NexusWheel")
		end
	end

	-- dragging (the window glides toward the cursor)
	local target, cur = Vector2.zero, Vector2.zero
	local drag, lift = nil, 0
	UI.minimized = false

	function UI.resetPos()
		if UI.minimized and UI.setMinimized then UI.setMinimized(false) end
		target = Vector2.zero
	end

	local minBtn = new("TextButton", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -72, 0, 6),
		BackgroundColor3 = CARD,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Text = "-",
		AutoButtonColor = false,
	}, titleBar)
	corner(minBtn, 6)
	hover(minBtn, CARD, HOVER)
	pressFx(minBtn)

	function UI.setMinimized(on)
		if UI.minimized == on then return end
		UI.minimized = on
		local h = on and 40 or WIN_H
		local shift = (WIN_H - 40) / 2 * UI.uiBase
		target = target + Vector2.new(0, on and -shift or shift)
		tween(window, { Size = UDim2.new(0, WIN_W, 0, h) }, TI.quint)
		tween(shadow, { Size = UDim2.new(0, WIN_W + 40, 0, h + 40) }, TI.quint)
		minBtn.Text = on and "+" or "-"
		if on then
			sidebar.Visible = false
			content.Visible = false
			footer.Visible = false
		else
			task.delay(0.22, function()
				if not UI.minimized then
					sidebar.Visible = true
					content.Visible = true
					footer.Visible = true
				end
			end)
		end
	end

	minBtn.MouseButton1Click:Connect(function() UI.setMinimized(not UI.minimized) end)

	-- double click the title bar to minimize or restore
	local lastTitleClick = 0
	titleBar.InputBegan:Connect(function(input)
		if isPress(input) then
			if os.clock() - lastTitleClick < 0.3 then UI.setMinimized(not UI.minimized) end
			lastTitleClick = os.clock()
		end
	end)

	titleBar.InputBegan:Connect(function(input)
		if isPress(input) and not UI.locked then
			drag = { start = Vector2.new(input.Position.X, input.Position.Y), base = target }
		end
	end)

	bind(UIS.InputChanged, function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if UI.activeSlider then UI.activeSlider(input) end
		if drag then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - drag.start
			local nt = drag.base + delta
			local size = gui.AbsoluteSize
			target = Vector2.new(
				math.clamp(nt.X, -size.X / 2 + 120, size.X / 2 - 120),
				math.clamp(nt.Y, -size.Y / 2 + 40, size.Y / 2 - 40))
		end
	end)

	bind(UIS.InputEnded, function(input)
		if isPress(input) then
			UI.activeSlider = nil
			drag = nil
		end
	end)

	bind(RunService.RenderStepped, function(dt)
		cur = cur:Lerp(target, 1 - math.exp(-dt * 16))
		if (target - cur).Magnitude < 0.05 then cur = target end
		lift += ((drag and 1 or 0) - lift) * (1 - math.exp(-dt * 12))
		window.Position = UDim2.new(0.5, cur.X, 0.5, cur.Y)
		shadow.Position = UDim2.new(0.5, cur.X, 0.5, cur.Y + 10 + 12 * lift)
		shadowScale.Scale = uiScale.Scale * (1 + 0.02 * lift)
	end)

	-- open / close
	local token = 0
	function UI.showMenu(on)
		UI.menuOpen = on
		UI.updateHandles()
		token += 1
		local my = token
		if on then
			window.Visible = true
			shadow.Visible = true
			uiScale.Scale = UI.uiBase * 0.92
			tween(uiScale, { Scale = UI.uiBase }, TI.back)
			tween(window, { GroupTransparency = UI.baseTransp }, TI.slow)
			tween(shadow, { BackgroundTransparency = 0.6 }, TI.slow)
		else
			local t = tween(window, { GroupTransparency = 1 }, TI.exit)
			tween(uiScale, { Scale = UI.uiBase * 0.95 }, TI.exit)
			tween(shadow, { BackgroundTransparency = 1 }, TI.exit)
			t.Completed:Connect(function()
				if token == my then
					window.Visible = false
					shadow.Visible = false
				end
			end)
		end
	end

	function UI.applyScale()
		if UI.menuOpen then tween(uiScale, { Scale = UI.uiBase }) end
	end

	UI.openBtn.MouseButton1Click:Connect(function()
		if os.clock() - UI.lastDragMove < 0.25 then return end
		UI.showMenu(not UI.menuOpen)
	end)
	closeBtn.MouseButton1Click:Connect(function() UI.showMenu(false) end)
end

-- =====================================================
-- BUILDERS
-- =====================================================

-- shared slider animator (knobs glide to their value)
local sliderAnims = {}
bind(RunService.RenderStepped, function(dt)
	local a = 1 - math.exp(-dt * 22)
	for _, s in ipairs(sliderAnims) do
		if math.abs(s.t - s.c) > 0.0004 then
			s.c += (s.t - s.c) * a
			s.fill.Size = UDim2.new(s.c, 0, 1, 0)
			s.knob.Position = UDim2.new(s.c, 0, 0.5, 0)
		end
	end
end)

local function makeSlider(parent, label, min, max, default, onChange)
	local box = new("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	}, parent)
	local lbl = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		TextColor3 = SUB,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, box)
	local track = new("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 0, 26),
		BackgroundColor3 = OFFCOL,
		BorderSizePixel = 0,
	}, box)
	corner(track, 3)
	local fill = reg(new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, track), "BackgroundColor3")
	corner(fill, 3)
	local knob = new("Frame", {
		Size = UDim2.new(0, 14, 0, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = TEXT,
		BorderSizePixel = 0,
	}, track)
	corner(knob, 7)

	local anim = { t = 0, c = 0, fill = fill, knob = knob }
	table.insert(sliderAnims, anim)

	local function set(v, instant)
		v = math.clamp(math.floor(v + 0.5), min, max)
		local a = (v - min) / (max - min)
		anim.t = a
		if instant then
			anim.c = a
			fill.Size = UDim2.new(a, 0, 1, 0)
			knob.Position = UDim2.new(a, 0, 0.5, 0)
		end
		lbl.Text = label .. ": " .. v
		onChange(v)
	end
	sliderSetters[label:lower()] = set

	local function fromInput(input)
		local a = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		set(min + a * (max - min))
	end

	box.InputBegan:Connect(function(input)
		if isPress(input) then
			UI.activeSlider = fromInput
			fromInput(input)
			tween(knob, { Size = UDim2.new(0, 18, 0, 18) }, TI.fast)
		end
	end)
	box.InputEnded:Connect(function(input)
		if isPress(input) then tween(knob, { Size = UDim2.new(0, 14, 0, 14) }, TI.back) end
	end)

	set(default, true)
	return box
end

local function makeCard(tab)
	local card = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = CARD,
		LayoutOrder = nextOrder(),
	}, UI.pages[tab])
	corner(card, 8)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
	}, card)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	return card
end

local function makeTitle(parent, text)
	return new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
	}, parent)
end

local function addModule(tab, def)
	local m = { name = def.name, key = def.key, on = false, def = def }
	local card = makeCard(tab)

	local header = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = nextOrder(),
	}, card)
	header.MouseEnter:Connect(function() tween(card, { BackgroundColor3 = HOVER }, TI.fast) end)
	header.MouseLeave:Connect(function() tween(card, { BackgroundColor3 = CARD }, TI.fast) end)

	new("TextLabel", {
		Size = UDim2.new(1, -110, 0, 20),
		BackgroundTransparency = 1,
		Text = def.name,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, header)
	new("TextLabel", {
		Size = UDim2.new(1, -110, 0, 14),
		Position = UDim2.new(0, 0, 0, 21),
		BackgroundTransparency = 1,
		Text = def.desc or "",
		TextColor3 = SUB,
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, header)
	if def.key then
		new("TextLabel", {
			Size = UDim2.new(0, 44, 0, 20),
			Position = UDim2.new(1, -96, 0.5, -10),
			BackgroundTransparency = 1,
			Text = "[" .. def.key.Name .. "]",
			TextColor3 = SUB,
			Font = Enum.Font.Code,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, header)
	end

	local track = new("Frame", {
		Size = UDim2.new(0, 38, 0, 20),
		Position = UDim2.new(1, -38, 0.5, -10),
		BackgroundColor3 = OFFCOL,
	}, header)
	corner(track, 10)
	local knob = new("Frame", {
		Size = UDim2.new(0, 16, 0, 16),
		Position = UDim2.new(0, 2, 0.5, -8),
		BackgroundColor3 = TEXT,
	}, track)
	corner(knob, 8)

	function m.refresh(instant)
		local trackColor = m.on and accent or OFFCOL
		local knobPos = m.on and UDim2.new(0, 20, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
		if instant then
			track.BackgroundColor3 = trackColor
			knob.Position = knobPos
		else
			tween(track, { BackgroundColor3 = trackColor })
			tween(knob, { Position = knobPos }, TI.back)
		end
	end

	header.MouseButton1Click:Connect(function()
		setModule(m, not m.on)
	end)

	for _, s in ipairs(def.sliders or {}) do
		makeSlider(card, s.label, s.min, s.max, s.default, s.onChange)
	end

	table.insert(modules, m)
	if def.default then
		m.on = true
		m.refresh(true)
		pcall(def.onToggle, true)
		refreshHud(m)
	end
	return m
end

local function addButton(tab, label, onClick, key)
	local card = makeCard(tab)
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = OFFCOL,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Text = key and (label .. "   [" .. key.Name .. "]") or label,
		AutoButtonColor = false,
		LayoutOrder = nextOrder(),
	}, card)
	corner(btn, 6)
	hover(btn, OFFCOL, Color3.fromRGB(80, 88, 106))
	pressFx(btn)
	btn.MouseButton1Click:Connect(onClick)
	if key then table.insert(keyActions, { key = key, fn = onClick }) end
	return btn
end

local function addSliderCard(tab, label, min, max, default, onChange)
	local card = makeCard(tab)
	makeSlider(card, label, min, max, default, onChange)
end

local function smallBtn(parent, text, pos)
	local b = new("TextButton", {
		Size = UDim2.new(0, 60, 0, 28),
		Position = pos,
		BackgroundColor3 = OFFCOL,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Text = text,
		AutoButtonColor = false,
	}, parent)
	corner(b, 6)
	hover(b, OFFCOL, Color3.fromRGB(80, 88, 106))
	pressFx(b)
	return b
end

local function makeTextRow(card, placeholder)
	local box = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = BG,
		TextColor3 = TEXT,
		PlaceholderText = placeholder,
		PlaceholderColor3 = SUB,
		Font = Enum.Font.Code,
		TextSize = 13,
		ClearTextOnFocus = false,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
	}, card)
	corner(box, 6)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, box)
	return box
end

-- accent color (fades everywhere)
local function setAccent(color, instant)
	accent = color
	for _, e in ipairs(accentObjs) do
		local obj, prop = e[1], e[2]
		if obj and obj.Parent then
			if instant then
				pcall(function() obj[prop] = accent end)
			else
				pcall(function() tween(obj, { [prop] = accent }, TweenInfo.new(0.3)) end)
			end
		end
	end
	for _, m in ipairs(modules) do
		if m.refresh then m.refresh(true) end
	end
	for _, row in pairs(hudRows) do
		row.TextColor3 = accent
	end
	UI.selectTab(UI.currentTab)
end

-- =====================================================
-- MENU CONTENT: MOVEMENT
-- =====================================================
do
	addModule("Movement", {
		name = "Fly", key = Enum.KeyCode.F, desc = "WASD to move, Space up, Ctrl down",
		onToggle = F.fly,
		sliders = { { label = "Fly speed", min = 20, max = 200, default = 60,
			onChange = function(v) cfg.flySpeed = v end } },
	})

	addModule("Movement", { name = "Noclip", key = Enum.KeyCode.N, desc = "Walk through walls", onToggle = F.noclip })

	addModule("Movement", {
		name = "Speed Hack", key = Enum.KeyCode.X, desc = "Run faster",
		onToggle = function(on) S.speedOn = on F.applyStats() end,
		sliders = { { label = "Walk speed", min = 16, max = 200, default = 50,
			onChange = function(v) cfg.walkSpeed = v if S.speedOn then F.applyStats() end end } },
	})

	addModule("Movement", {
		name = "Sprint", desc = "Hold Left Shift to run faster",
		onToggle = F.sprint,
		sliders = { { label = "Sprint boost", min = 12, max = 50, default = 20,
			onChange = function(v) cfg.sprint = v / 10 end } },
	})

	addModule("Movement", {
		name = "Super Jump", key = Enum.KeyCode.J, desc = "Jump higher",
		onToggle = function(on) S.jumpOn = on F.applyStats() end,
		sliders = { { label = "Jump power", min = 50, max = 300, default = 120,
			onChange = function(v) cfg.jumpPower = v if S.jumpOn then F.applyStats() end end } },
	})

	addModule("Movement", { name = "Infinite Jump", key = Enum.KeyCode.G, desc = "Jump again in mid-air", onToggle = F.infJump })
	addModule("Movement", { name = "Bunny Hop", key = Enum.KeyCode.H, desc = "Hold Space to keep jumping", onToggle = F.bunny })

	addModule("Movement", {
		name = "Glide", desc = "Fall slowly while in the air",
		onToggle = F.glide,
		sliders = { { label = "Glide speed", min = 2, max = 40, default = 12,
			onChange = function(v) cfg.glide = v end } },
	})

	addModule("Movement", { name = "Float", key = Enum.KeyCode.V, desc = "Walk on air. Space raises, Ctrl lowers", onToggle = F.float })
	addModule("Movement", { name = "Click Teleport", desc = "Hold T and click to teleport", onToggle = function(on) S.ctp = on end })

	addModule("Movement", {
		name = "Spin Bot", key = Enum.KeyCode.K, desc = "Spin your character",
		onToggle = F.spin,
		sliders = { { label = "Spin speed", min = 5, max = 60, default = 20,
			onChange = function(v) cfg.spinSpeed = v end } },
	})

	addModule("Movement", { name = "Anti Void", desc = "Teleports you back if you fall out of the map", onToggle = F.antiVoid })

	addButton("Movement", "Dash", F.dash, Enum.KeyCode.Q)
	addSliderCard("Movement", "Dash power", 40, 250, 90, function(v) cfg.dash = v end)
end

-- =====================================================
-- MENU CONTENT: VISUALS
-- =====================================================
do
	addModule("Visuals", { name = "ESP", key = Enum.KeyCode.B, desc = "Outlines, names, distance and health", onToggle = F.esp })
	addModule("Visuals", { name = "Tracers", key = Enum.KeyCode.Y, desc = "Lines from you to every player", onToggle = F.tracers })
	addModule("Visuals", { name = "X-Ray", key = Enum.KeyCode.U, desc = "See through walls and parts", onToggle = F.xray })
	addModule("Visuals", { name = "Crosshair", desc = "Adds a crosshair to the screen center", onToggle = F.crosshair })
	addModule("Visuals", { name = "Matrix Rain", key = Enum.KeyCode.M, desc = "Falling code across the screen", onToggle = F.rain })

	addModule("Visuals", {
		name = "Freecam", key = Enum.KeyCode.C,
		desc = "Fly the camera. Right-click drag to look",
		onToggle = F.freecam,
		sliders = { { label = "Freecam speed", min = 10, max = 300, default = 60,
			onChange = function(v) cfg.freecam = v end } },
	})

	addModule("Visuals", {
		name = "Orbit Camera", desc = "Camera circles around you",
		onToggle = F.orbit,
		sliders = { { label = "Orbit speed", min = 2, max = 60, default = 20,
			onChange = function(v) cfg.orbit = v end } },
	})

	addModule("Visuals", {
		name = "Hold Zoom", desc = "Hold Z to zoom in like a scope",
		onToggle = F.holdZoom,
		sliders = { { label = "Zoom FOV", min = 5, max = 60, default = 30,
			onChange = function(v) cfg.zoomFov = v end } },
	})

	addModule("Visuals", {
		name = "Wide Zoom", desc = "Scroll the camera way out",
		onToggle = F.wideZoom,
		sliders = { { label = "Max zoom", min = 128, max = 520, default = 520,
			onChange = function(v) cfg.zoom = v if S.wide then player.CameraMaxZoomDistance = v end end } },
	})

	addSliderCard("Visuals", "Field of view", 40, 120,
		math.floor((workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70) + 0.5),
		function(v)
			cfg.fov = v
			local cam = workspace.CurrentCamera
			if cam then cam.FieldOfView = v end
		end)
end

-- =====================================================
-- MENU CONTENT: WORLD
-- =====================================================
do
	addModule("World", { name = "Fullbright", key = Enum.KeyCode.L, desc = "Removes darkness and fog", onToggle = F.fullbright })
	addModule("World", { name = "No Fog", desc = "Clears fog and atmosphere haze", onToggle = F.noFog })

	addModule("World", {
		name = "Gravity", desc = "Change how heavy the world feels",
		onToggle = F.gravity,
		sliders = { { label = "Gravity", min = 10, max = 300, default = 196,
			onChange = function(v) cfg.gravity = v if S.grav then workspace.Gravity = v end end } },
	})

	addModule("World", {
		name = "Time Changer", desc = "Set the time of day",
		onToggle = F.timeChanger,
		sliders = { { label = "Time of day", min = 0, max = 24, default = 14,
			onChange = function(v) cfg.time = v if S.timeOn then Lighting.ClockTime = v end end } },
	})

	addModule("World", {
		name = "Time Cycle", desc = "Day and night keep moving",
		onToggle = F.timeCycle,
		sliders = { { label = "Cycle speed", min = 1, max = 120, default = 30,
			onChange = function(v) cfg.cycle = v end } },
	})

	addModule("World", {
		name = "Bloom Glow", desc = "Makes bright things glow",
		onToggle = F.bloom,
		sliders = { { label = "Bloom intensity", min = 0, max = 50, default = 10,
			onChange = function(v) cfg.bloom = v F.bloomUpdate() end } },
	})

	addModule("World", {
		name = "Color Grading", desc = "Saturation and contrast",
		onToggle = F.grade,
		sliders = {
			{ label = "Saturation", min = -100, max = 100, default = 0,
				onChange = function(v) cfg.sat = v F.gradeUpdate() end },
			{ label = "Contrast", min = -100, max = 100, default = 0,
				onChange = function(v) cfg.contrast = v F.gradeUpdate() end },
		},
	})

	addModule("World", {
		name = "Ambient Tint", desc = "Tints the whole world's lighting",
		onToggle = F.ambientTint,
		sliders = { { label = "Ambient hue", min = 0, max = 360, default = 200,
			onChange = function(v) cfg.hue = v F.ambientUpdate() end } },
	})
end

-- =====================================================
-- MENU CONTENT: PLAYERS
-- =====================================================
do
	local actions = makeCard("Players")
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	}, actions)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, row)

	local function wideBtn(text, onClick)
		local b = new("TextButton", {
			Size = UDim2.new(1 / 3, -6, 1, 0),
			BackgroundColor3 = OFFCOL,
			TextColor3 = TEXT,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			Text = text,
			AutoButtonColor = false,
		}, row)
		corner(b, 6)
		hover(b, OFFCOL, Color3.fromRGB(80, 88, 106))
		pressFx(b)
		b.MouseButton1Click:Connect(onClick)
	end

	wideBtn("TP Nearest", function()
		local root = getRoot()
		if not root then return end
		local best, bestD = nil, math.huge
		for _, plr in ipairs(Players:GetPlayers()) do
			local r = plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local d = (r.Position - root.Position).Magnitude
				if d < bestD then best, bestD = plr, d end
			end
		end
		if best then F.tpTo(best) else notify("No players found", false) end
	end)
	wideBtn("TP Random", function()
		local choices = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player and plr.Character then table.insert(choices, plr) end
		end
		if #choices > 0 then F.tpTo(choices[math.random(1, #choices)]) else notify("No players found", false) end
	end)
	wideBtn("Reset Camera", function()
		F.spectate(nil)
		F.setFollow(nil)
		F.attach(nil)
		if UI.rebuildPlayers then UI.rebuildPlayers() end
		notify("Camera and follow reset")
	end)

	local listCard = makeCard("Players")

	function UI.rebuildPlayers()
		for _, c in ipairs(listCard:GetChildren()) do
			if c.Name == "Row" or c.Name == "Empty" then c:Destroy() end
		end
		local count = 0
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= player then
				count += 1
				local r = new("Frame", {
					Name = "Row",
					Size = UDim2.new(1, 0, 0, 34),
					BackgroundTransparency = 1,
					LayoutOrder = nextOrder(),
				}, listCard)
				new("TextLabel", {
					Size = UDim2.new(1, -274, 1, 0),
					BackgroundTransparency = 1,
					Text = plr.DisplayName .. " (@" .. plr.Name .. ")",
					TextColor3 = TEXT,
					Font = Enum.Font.Gotham,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, r)
				local tpB = smallBtn(r, "TP", UDim2.new(1, -264, 0.5, -14))
				local viewB = smallBtn(r, "View", UDim2.new(1, -198, 0.5, -14))
				local folB = smallBtn(r, S.followTarget == plr and "Stop" or "Follow", UDim2.new(1, -132, 0.5, -14))
				local attB = smallBtn(r, S.attachTarget == plr and "Detach" or "Attach", UDim2.new(1, -66, 0.5, -14))
				attB.MouseButton1Click:Connect(function()
					if S.attachTarget == plr then
						F.attach(nil)
						notify("Detached")
					else
						F.attach(plr)
						notify(F.getAttachMode() .. " attach: " .. plr.Name)
					end
					UI.rebuildPlayers()
				end)
				tpB.MouseButton1Click:Connect(function() F.tpTo(plr) end)
				viewB.MouseButton1Click:Connect(function() F.spectate(plr) end)
				folB.MouseButton1Click:Connect(function()
					if S.followTarget == plr then
						F.setFollow(nil)
						notify("Stopped following")
					else
						F.setFollow(plr)
						notify("Following " .. plr.Name)
					end
					UI.rebuildPlayers()
				end)
			end
		end
		if count == 0 then
			new("TextLabel", {
				Name = "Empty",
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "No other players in the server",
				TextColor3 = SUB,
				Font = Enum.Font.Code,
				TextSize = 13,
				LayoutOrder = nextOrder(),
			}, listCard)
		end
	end

	bind(Players.PlayerAdded, function() task.wait(0.5) UI.rebuildPlayers() end)
	bind(Players.PlayerRemoving, function(plr)
		if S.followTarget == plr then F.setFollow(nil) end
		if S.attachTarget == plr then F.attach(nil) end
		task.defer(UI.rebuildPlayers)
	end)
	UI.rebuildPlayers()
end

-- =====================================================
-- MENU CONTENT: TELEPORT
-- =====================================================
do
	local card = makeCard("Teleport")
	makeTitle(card, "Go to coordinates")
	local box = makeTextRow(card, "x y z   (example: 0 50 0)")
	local go = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = OFFCOL,
		TextColor3 = TEXT,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Text = "Teleport",
		AutoButtonColor = false,
		LayoutOrder = nextOrder(),
	}, card)
	corner(go, 6)
	hover(go, OFFCOL, Color3.fromRGB(80, 88, 106))
	pressFx(go)
	go.MouseButton1Click:Connect(function()
		local nums = {}
		for n in box.Text:gmatch("-?%d+%.?%d*") do table.insert(nums, tonumber(n)) end
		local root = getRoot()
		if #nums >= 3 and root then
			root.CFrame = CFrame.new(nums[1], nums[2], nums[3])
			notify("Teleported")
		else
			notify("Use: x y z", false)
		end
	end)

	addButton("Teleport", "Save Waypoint", function() F.saveWaypoint() end, Enum.KeyCode.O)
	addButton("Teleport", "Teleport to Spawn", F.tpSpawn)
	addModule("Teleport", {
		name = "Respawn Where I Died", desc = "After dying you respawn at the spot you died",
		onToggle = function(on) S.respawnHere = on end,
	})

	local wpCard = makeCard("Teleport")
	function UI.rebuildWaypoints()
		for _, c in ipairs(wpCard:GetChildren()) do
			if c.Name == "Row" or c.Name == "Empty" then c:Destroy() end
		end
		if #waypoints == 0 then
			new("TextLabel", {
				Name = "Empty",
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = "No waypoints saved yet (press O to save one)",
				TextColor3 = SUB,
				Font = Enum.Font.Code,
				TextSize = 13,
				LayoutOrder = nextOrder(),
			}, wpCard)
			return
		end
		for i, w in ipairs(waypoints) do
			local r = new("Frame", {
				Name = "Row",
				Size = UDim2.new(1, 0, 0, 34),
				BackgroundTransparency = 1,
				LayoutOrder = nextOrder(),
			}, wpCard)
			new("TextLabel", {
				Size = UDim2.new(1, -140, 1, 0),
				BackgroundTransparency = 1,
				Text = w.name,
				TextColor3 = TEXT,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			}, r)
			local goB = smallBtn(r, "Go", UDim2.new(1, -132, 0.5, -14))
			local delB = smallBtn(r, "Delete", UDim2.new(1, -66, 0.5, -14))
			goB.MouseButton1Click:Connect(function() F.goWaypoint(w) end)
			delB.MouseButton1Click:Connect(function()
				table.remove(waypoints, i)
				UI.rebuildWaypoints()
			end)
		end
	end
	UI.rebuildWaypoints()
end

-- =====================================================
-- MENU CONTENT: PERFORMANCE
-- =====================================================
do
	addModule("Performance", { name = "Super FPS", key = Enum.KeyCode.P, desc = "Strips shadows, effects, detail and textures", onToggle = F.superFps })
	addModule("Performance", { name = "No Textures", desc = "Flat plastic look. Textures restore when off", onToggle = F.noTextures })
	addModule("Performance", { name = "No Shadows", desc = "Turns off global shadows", onToggle = F.noShadows })
	addModule("Performance", { name = "No Particles", desc = "Disables particles, trails, fire and smoke", onToggle = F.noParticles })
	addModule("Performance", { name = "FPS Counter", desc = "Shows your frame rate", onToggle = F.fpsCounter })
	addModule("Performance", {
		name = "Blank Screen", desc = "Stops 3D rendering (AFK mode). Toggle off to return",
		onToggle = function(on) pcall(function() RunService:Set3dRenderingEnabled(not on) end) end,
	})
end

-- =====================================================
-- MENU CONTENT: MISC
-- =====================================================
do
	addModule("Misc", { name = "Anti AFK", desc = "Stops the idle kick after 20 minutes", default = true, keep = true, onToggle = function(on) S.afk = on end })
	addModule("Misc", { name = "Ghost Mode", desc = "Hides your own character on your screen", onToggle = F.ghost })
	addModule("Misc", { name = "Rainbow Skin", desc = "Your character cycles through colors (local)", onToggle = F.rainbowSkin })
	addModule("Misc", { name = "Info HUD", desc = "Coordinates, speed, ping and FPS on screen", onToggle = F.infoHud })
	addModule("Misc", { name = "Inspector", desc = "Shows the name of whatever your mouse is over", onToggle = F.inspector })
	addModule("Misc", { name = "Click Delete", desc = "Hold R and click a part to remove it (local only)", onToggle = function(on) S.cd = on end })

	addButton("Misc", "Restore Deleted Part", F.restoreDeleted)
	addSliderCard("Misc", "Volume", 0, 100, F.getVolume(), F.setVolume)

	local rejoining = false
	local rejoinBtn
	rejoinBtn = addButton("Misc", "Rejoin Server", function()
		if rejoining then return end
		rejoining = true
		rejoinBtn.Text = "Rejoining..."
		log("rejoining server...")
		local ok = pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
		end)
		if not ok then
			pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
		end
	end)

	addButton("Misc", "Server Hop", function()
		notify("Joining a new server...")
		pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
	end)

	bind(TeleportService.TeleportInitFailed, function(failedPlayer)
		if failedPlayer ~= player then return end
		pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
		task.wait(5)
		rejoining = false
		rejoinBtn.Text = "Rejoin Server"
	end)

	addButton("Misc", "Reset Character", function()
		local hum = getHum()
		if hum then hum.Health = 0 end
		notify("Character reset")
	end)

	local card = makeCard("Misc")
	makeTitle(card, "Server info")
	local info = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 1,
		TextColor3 = SUB,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LayoutOrder = nextOrder(),
	}, card)

	task.spawn(function()
		while UI.gui.Parent and not unloaded do
			local job = game.JobId ~= "" and game.JobId:sub(1, 13) .. "..." or "studio"
			info.Text = string.format(
				"Players:  %d / %d\nPing:     %s\nFPS:      %d\nUptime:   %d min\nPlace ID: %d\nJob ID:   %s",
				#Players:GetPlayers(), Players.MaxPlayers, getPing(), UI.currentFps,
				math.floor(workspace.DistributedGameTime / 60), game.PlaceId, job)
			task.wait(1)
		end
	end)
end

-- =====================================================
-- MENU CONTENT: SETTINGS
-- =====================================================
do
	addModule("Settings", { name = "Module List", desc = "Shows enabled modules on the right", default = true, noHud = true, onToggle = function(on) UI.hud.Visible = on end })
	addModule("Settings", { name = "Notifications", desc = "Pop-ups when you toggle a module", default = true, noHud = true, onToggle = function(on) S.notifications = on end })

	do
		local conn, hue = nil, 0
		addModule("Settings", {
			name = "Rainbow Accent", desc = "Cycles the menu colors", noHud = true,
			onToggle = function(on)
				if conn then conn:Disconnect() conn = nil end
				if on then
					local last = 0
					conn = RunService.Heartbeat:Connect(function(dt)
						hue = (hue + dt * 0.12) % 1
						if os.clock() - last > 0.08 then
							last = os.clock()
							setAccent(Color3.fromHSV(hue, 0.75, 1), true)
						end
					end)
				end
			end,
		})
	end

	local card = makeCard("Settings")
	makeTitle(card, "Accent color")
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = nextOrder(),
	}, card)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, row)
	local colors = {
		Color3.fromRGB(0, 255, 120), Color3.fromRGB(70, 150, 255), Color3.fromRGB(170, 100, 255),
		Color3.fromRGB(255, 70, 90), Color3.fromRGB(255, 160, 40), Color3.fromRGB(0, 230, 255),
	}
	for _, c in ipairs(colors) do
		local b = new("TextButton", {
			Size = UDim2.new(0, 30, 0, 30), BackgroundColor3 = c, Text = "", AutoButtonColor = false,
		}, row)
		corner(b, 15)
		b.MouseEnter:Connect(function() tween(b, { Size = UDim2.new(0, 34, 0, 34) }, TI.fast) end)
		b.MouseLeave:Connect(function() tween(b, { Size = UDim2.new(0, 30, 0, 30) }, TI.fast) end)
		b.MouseButton1Click:Connect(function()
			setAccent(c)
			log("accent color changed")
		end)
	end

	addSliderCard("Settings", "UI size", 60, 130, 100, function(v)
		UI.uiBase = UI.autoBase * v / 100
		UI.applyScale()
	end)

	local help = makeCard("Settings")
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundTransparency = 1,
		TextColor3 = SUB,
		Font = Enum.Font.Code,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "Menu key: RightShift\nFly / Float / Freecam: Space up, Ctrl down\nSprint: hold Left Shift   Dash: Q\nHold Zoom: hold Z\nClick Teleport: hold T + click\nClick Delete: hold R + click\nSave waypoint: O\nDrag the title bar to move the window",
		LayoutOrder = nextOrder(),
	}, help)

	do
		local moreColors = {
			Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 120, 200),
			Color3.fromRGB(120, 255, 60), Color3.fromRGB(255, 90, 30), Color3.fromRGB(110, 110, 255),
		}
		local card2 = makeCard("Settings")
		makeTitle(card2, "More colors")
		local row2 = new("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, card2)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, row2)
		for _, c in ipairs(moreColors) do
			local b = new("TextButton", {
				Size = UDim2.new(0, 30, 0, 30), BackgroundColor3 = c, Text = "", AutoButtonColor = false,
			}, row2)
			corner(b, 15)
			b.MouseEnter:Connect(function() tween(b, { Size = UDim2.new(0, 34, 0, 34) }, TI.fast) end)
			b.MouseLeave:Connect(function() tween(b, { Size = UDim2.new(0, 30, 0, 30) }, TI.fast) end)
			b.MouseButton1Click:Connect(function()
				setAccent(c)
				log("accent color changed")
			end)
		end

		local r = math.floor(accent.R * 255 + 0.5)
		local g = math.floor(accent.G * 255 + 0.5)
		local bl = math.floor(accent.B * 255 + 0.5)
		addSliderCard("Settings", "Accent red", 0, 255, r, function(v) r = v setAccent(Color3.fromRGB(r, g, bl), true) end)
		addSliderCard("Settings", "Accent green", 0, 255, g, function(v) g = v setAccent(Color3.fromRGB(r, g, bl), true) end)
		addSliderCard("Settings", "Accent blue", 0, 255, bl, function(v) bl = v setAccent(Color3.fromRGB(r, g, bl), true) end)

		addSliderCard("Settings", "Menu opacity", 50, 100, 100, function(v)
			UI.baseTransp = 1 - v / 100
			if UI.menuOpen and UI.window then
				tween(UI.window, { GroupTransparency = UI.baseTransp }, TI.fast)
			end
		end)
		addSliderCard("Settings", "Toast seconds", 1, 8, 2, function(v) cfg.toastTime = v end)

		local keys = {
			Enum.KeyCode.RightShift, Enum.KeyCode.Insert, Enum.KeyCode.RightControl,
			Enum.KeyCode.Home, Enum.KeyCode.Delete,
		}
		local idx = 1
		local keyBtn
		keyBtn = addButton("Settings", "Menu key: RightShift (click to change)", function()
			idx = idx % #keys + 1
			UI.menuKey = keys[idx]
			keyBtn.Text = "Menu key: " .. keys[idx].Name .. " (click to change)"
			notify("Menu key is now " .. keys[idx].Name)
		end)

		addButton("Settings", "Reset window position", function()
			UI.resetPos()
			notify("Window position reset")
		end)
		addButton("Settings", "Panic: turn everything off", F.panic, Enum.KeyCode.End)
	end

	addModule("Settings", {
		name = "Lock GUI Positions", desc = "Stops the window and HUD elements from being dragged",
		noHud = true,
		onToggle = function(on)
			UI.locked = on
			UI.updateHandles()
		end,
	})
	addButton("Settings", "Reset all GUI positions", function()
		UI.resetLayout()
		UI.resetPos()
		notify("GUI positions reset")
	end)

	addButton("Settings", "Unload Client", function()
		unloaded = true
		for _, m in ipairs(modules) do
			if m.on then pcall(m.def.onToggle, false) end
		end
		F.setFollow(nil)
		F.attach(nil)
		F.spectate(nil)
		if UI.unbindWheel then UI.unbindWheel() end
		for _, c in ipairs(globalConns) do c:Disconnect() end
		UI.gui:Destroy()
	end)
end

-- =====================================================
-- MENU CONTENT: EXTRAS
-- =====================================================
do
	-- Movement
	addModule("Movement", {
		name = "Wall Climb", desc = "Hold Space against a wall to climb it",
		onToggle = F.wallClimb,
		sliders = { { label = "Climb speed", min = 10, max = 100, default = 35,
			onChange = function(v) cfg.climb = v end } },
	})
	addModule("Movement", {
		name = "Hip Height", desc = "Make your character taller or shorter",
		onToggle = F.hipHeight,
		sliders = { { label = "Hip height", min = 0, max = 30, default = 8,
			onChange = function(v) cfg.hip = v F.hipUpdate() end } },
	})
	addModule("Movement", {
		name = "Camera Offset", desc = "Shift where the camera sits",
		onToggle = F.camOffset,
		sliders = {
			{ label = "Camera X", min = -10, max = 10, default = 0,
				onChange = function(v) cfg.camX = v F.camOffsetUpdate() end },
			{ label = "Camera Y", min = -10, max = 10, default = 0,
				onChange = function(v) cfg.camY = v F.camOffsetUpdate() end },
		},
	})
	addModule("Movement", { name = "Anti Ragdoll", desc = "Stops you from being knocked down", onToggle = F.antiRagdoll })
	addButton("Movement", "Blink Forward", F.blink, Enum.KeyCode.Period)
	addSliderCard("Movement", "Blink distance", 5, 100, 25, function(v) cfg.blink = v end)
	addButton("Movement", "Place Platform (local)", F.platform)
	addButton("Movement", "Remove Platforms", F.clearPlatforms)
	addButton("Movement", "Sit Down", F.sit)
	addButton("Movement", "Show My Position", F.showPos)

	-- Visuals
	addModule("Visuals", { name = "Hide Players", desc = "Makes every other player invisible to you", onToggle = F.hidePlayers })
	addModule("Visuals", { name = "Hide Name Tags", desc = "Removes the names above heads", onToggle = F.hideNames })
	addModule("Visuals", { name = "Compass", desc = "Shows which way you are facing", onToggle = F.compass })
	addModule("Visuals", {
		name = "Screen Tint", desc = "Colors your whole screen",
		onToggle = F.screenTint,
		sliders = {
			{ label = "Tint color", min = 0, max = 360, default = 0,
				onChange = function(v) cfg.tintHue = v F.tintUpdate() end },
			{ label = "Tint strength", min = 0, max = 60, default = 15,
				onChange = function(v) cfg.tintAlpha = v F.tintUpdate() end },
		},
	})
	addModule("Visuals", {
		name = "Cinematic Bars", desc = "Black bars on the top and bottom",
		onToggle = F.bars,
		sliders = { { label = "Bar size", min = 5, max = 30, default = 12,
			onChange = function(v) cfg.bars = v F.barsUpdate() end } },
	})
	addModule("Visuals", {
		name = "Blur", desc = "Blurs the whole screen",
		onToggle = F.blur,
		sliders = { { label = "Blur size", min = 0, max = 40, default = 10,
			onChange = function(v) cfg.blur = v F.blurUpdate() end } },
	})
	addModule("Visuals", {
		name = "Depth of Field", desc = "Blurs things far from the focus point",
		onToggle = F.dof,
		sliders = { { label = "Focus distance", min = 5, max = 300, default = 60,
			onChange = function(v) cfg.dof = v F.dofUpdate() end } },
	})

	-- World
	addModule("World", {
		name = "Exposure", desc = "Makes the whole scene brighter or darker",
		onToggle = F.exposure,
		sliders = { { label = "Exposure", min = -50, max = 50, default = 0,
			onChange = function(v) cfg.exposure = v F.exposureUpdate() end } },
	})
	addModule("World", {
		name = "Brightness", desc = "Lighting brightness",
		onToggle = F.brightness,
		sliders = { { label = "Brightness level", min = 0, max = 100, default = 20,
			onChange = function(v) cfg.brightness = v F.brightnessUpdate() end } },
	})
	addModule("World", {
		name = "Custom Fog", desc = "Set how far you can see",
		onToggle = F.fogDist,
		sliders = { { label = "Fog distance", min = 30, max = 2000, default = 400,
			onChange = function(v) cfg.fogDist = v F.fogDistUpdate() end } },
	})
	addModule("World", { name = "No Sky", desc = "Hides sun, moon, stars and clouds", onToggle = F.noSky })
	addModule("World", {
		name = "Disco Lights", desc = "Lighting cycles through colors",
		onToggle = F.disco,
		sliders = { { label = "Disco speed", min = 1, max = 100, default = 20,
			onChange = function(v) cfg.disco = v end } },
	})
	addModule("World", {
		name = "Sun Rays", desc = "Adds light beams from the sun",
		onToggle = F.sunRays,
		sliders = { { label = "Sun ray strength", min = 0, max = 100, default = 25,
			onChange = function(v) cfg.rays = v F.sunRaysUpdate() end } },
	})
	addModule("World", {
		name = "Snowfall", desc = "Snow falls around you",
		onToggle = F.snow,
		sliders = { { label = "Snow amount", min = 20, max = 1500, default = 300,
			onChange = function(v) cfg.snow = v end } },
	})
	addModule("World", {
		name = "Rainfall", desc = "Rain falls around you",
		onToggle = F.rainfall,
		sliders = { { label = "Rain amount", min = 50, max = 2500, default = 600,
			onChange = function(v) cfg.rainRate = v end } },
	})

	do
		local card = makeCard("World")
		makeTitle(card, "Gravity presets")
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, card)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, row)
		local function preset(text, v)
			local b = new("TextButton", {
				Size = UDim2.new(0, 70, 1, 0),
				BackgroundColor3 = OFFCOL,
				TextColor3 = TEXT,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = text,
				AutoButtonColor = false,
			}, row)
			corner(b, 6)
			hover(b, OFFCOL, Color3.fromRGB(80, 88, 106))
			pressFx(b)
			b.MouseButton1Click:Connect(function()
				local setter = sliderSetters["gravity"]
				if setter then setter(v) end
				for _, m in ipairs(modules) do
					if m.name == "Gravity" and not m.on then setModule(m, true, true) end
				end
				notify("Gravity set to " .. v)
			end)
		end
		preset("Moon", 30)
		preset("Mars", 75)
		preset("Earth", 196)
		preset("Heavy", 350)
	end

	-- Players
	do
		local card = makeCard("Players")
		makeTitle(card, "Spectate")
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, card)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, row)
		local function stepBtn(text, dir)
			local b = new("TextButton", {
				Size = UDim2.new(0.5, -4, 1, 0),
				BackgroundColor3 = OFFCOL,
				TextColor3 = TEXT,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = text,
				AutoButtonColor = false,
			}, row)
			corner(b, 6)
			hover(b, OFFCOL, Color3.fromRGB(80, 88, 106))
			pressFx(b)
			b.MouseButton1Click:Connect(function() F.spectateStep(dir) end)
		end
		stepBtn("< Previous player", -1)
		stepBtn("Next player >", 1)
	end

	-- Performance
	addModule("Performance", {
		name = "Graphics Quality", desc = "Force a graphics quality level (1 is lowest)",
		onToggle = F.quality,
		sliders = { { label = "Graphics level", min = 1, max = 21, default = 5,
			onChange = function(v) cfg.quality = v F.qualityUpdate() end } },
	})
	addModule("Performance", { name = "No Grass", desc = "Turns off terrain grass", onToggle = F.noGrass })

	-- Misc
	addModule("Misc", { name = "Auto Rejoin", desc = "Rejoins automatically if you get disconnected", onToggle = F.autoRejoin })
	addModule("Misc", { name = "Clock HUD", desc = "Real time and how long you have played", onToggle = F.clockHud })
	addModule("Misc", { name = "Hide Player List", desc = "Hides the Roblox leaderboard", onToggle = F.coreGui(Enum.CoreGuiType.PlayerList) })
	addModule("Misc", { name = "Hide Chat", desc = "Hides the Roblox chat window", onToggle = F.coreGui(Enum.CoreGuiType.Chat) })
	addModule("Misc", { name = "Hide Backpack", desc = "Hides the Roblox hotbar", onToggle = F.coreGui(Enum.CoreGuiType.Backpack) })

	do
		local card = makeCard("Misc")
		makeTitle(card, "Notes (cleared when you leave)")
		local box = new("TextBox", {
			Size = UDim2.new(1, 0, 0, 90),
			BackgroundColor3 = BG,
			TextColor3 = TEXT,
			PlaceholderText = "type anything here...",
			PlaceholderColor3 = SUB,
			Font = Enum.Font.Code,
			TextSize = 13,
			ClearTextOnFocus = false,
			Text = "",
			MultiLine = true,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = nextOrder(),
		}, card)
		corner(box, 6)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }, box)
	end
end

-- =====================================================
-- MENU CONTENT: MORE
-- =====================================================
do
	addModule("Movement", { name = "Auto Walk", desc = "Keeps walking forward by itself", onToggle = F.autoWalk })
	addModule("Movement", { name = "Auto Jump", desc = "Jumps whenever you walk", onToggle = F.autoJump })
	addModule("Movement", { name = "Freeze Me", desc = "Locks your character in place", onToggle = F.freezeMe })

	addModule("Visuals", { name = "Camera Through Walls", desc = "The camera ignores walls", onToggle = F.camThrough })
	addModule("Visuals", { name = "Close Zoom", desc = "Lets you zoom all the way into first person", onToggle = F.closeZoom })
	addModule("Visuals", {
		name = "Light Aura", desc = "A glow around you (only you see it)",
		onToggle = F.aura,
		sliders = { { label = "Aura range", min = 8, max = 60, default = 25,
			onChange = function(v) cfg.aura = v F.auraUpdate() end } },
	})
	addModule("Visuals", { name = "Trail", desc = "A glowing trail behind you (only you see it)", onToggle = F.trail })

	addModule("World", { name = "Night Vision", desc = "Bright green tinted vision", onToggle = F.nightVision })

	addModule("Misc", {
		name = "Character Size", desc = "Scale your character (R15 only, only you see it)",
		onToggle = F.charSize,
		sliders = { { label = "Size percent", min = 40, max = 400, default = 100,
			onChange = function(v) cfg.size = v F.charSizeUpdate() end } },
	})

	addButton("Teleport", "Go Back (undo last teleport)", F.goBack, Enum.KeyCode.Backspace)

	-- Attach mode picker (goes to the top of the Players tab)
	do
		local card = makeCard("Players")
		card.LayoutOrder = 0
		makeTitle(card, "Attach mode (head sit and more)")
		local row = new("Frame", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			LayoutOrder = nextOrder(),
		}, card)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, row)

		local btns = {}
		local function refresh()
			for name, b in pairs(btns) do
				local sel = F.getAttachMode() == name
				tween(b, {
					BackgroundColor3 = sel and accent or OFFCOL,
					TextColor3 = sel and Color3.new(0, 0, 0) or TEXT,
				}, TI.fast)
			end
		end
		for _, name in ipairs(F.attachModes) do
			local b = new("TextButton", {
				Size = UDim2.new(0.2, -5, 1, 0),
				BackgroundColor3 = OFFCOL,
				TextColor3 = TEXT,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Text = name,
				AutoButtonColor = false,
			}, row)
			corner(b, 6)
			pressFx(b)
			btns[name] = b
			b.MouseButton1Click:Connect(function()
				F.setAttachMode(name)
				refresh()
			end)
		end
		refresh()

		new("TextLabel", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = "Pick a mode, then press Attach next to a player. Head = sit on their head, Back = piggyback.",
			TextColor3 = SUB,
			Font = Enum.Font.Gotham,
			TextSize = 11,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = nextOrder(),
		}, card)

		local det = addButton("Players", "Detach", function()
			F.attach(nil)
			UI.rebuildPlayers()
			notify("Detached")
		end)
		det.Parent.LayoutOrder = 1
	end
end

-- =====================================================
-- MENU CONTENT: NAME TAGS
-- =====================================================
addModule("Visuals", {
	name = "Far Name Tags", desc = "See player names and health from very far away",
	onToggle = F.farNames,
	sliders = { { label = "Name distance", min = 100, max = 10000, default = 2000,
		onChange = function(v) cfg.nameDist = v F.farNamesUpdate() end } },
})

-- =====================================================
-- MENU CONTENT: CONSOLE
-- =====================================================
do
	local out
	local function cprint(text, color)
		if not out then return end
		new("TextLabel", {
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Text = text,
			TextColor3 = color or SUB,
			Font = Enum.Font.Code,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
		}, out)
		local labels = {}
		for _, c in ipairs(out:GetChildren()) do
			if c:IsA("TextLabel") then table.insert(labels, c) end
		end
		if #labels > 80 then labels[1]:Destroy() end
		task.defer(function() out.CanvasPosition = Vector2.new(0, 1e6) end)
	end

	local function norm(s)
		return (s:lower():gsub("[^%w]", ""))
	end

	local aliases = {
		speed = "speedhack", jump = "superjump", infjump = "infinitejump", ctp = "clickteleport",
		spin = "spinbot", rain = "matrixrain", matrix = "matrixrain", fps = "fpscounter",
		blank = "blankscreen", afk = "antiafk", void = "antivoid", rainbow = "rainbowaccent",
		zoom = "widezoom", textures = "notextures", bhop = "bunnyhop", cam = "freecam",
		orbit = "orbitcamera", fog = "nofog", bloom = "bloomglow", grade = "colorgrading",
		tint = "ambienttint", cycle = "timecycle", ghost = "ghostmode", skin = "rainbowskin",
		hud = "infohud", delete = "clickdelete", shadows = "noshadows", particles = "noparticles",
		respawn = "respawnwhereidied", time = "timechanger",
		farnames = "farnametags", nametags = "farnametags",
		snow = "snowfall", rainfall = "rainfall", wall = "wallclimb", climb = "wallclimb",
		ragdoll = "antiragdoll", bars = "cinematicbars", hip = "hipheight", dof = "depthoffield",
		quality = "graphicsquality", sky = "nosky", disco = "discolights", rays = "sunrays",
		players = "hideplayers", names = "hidenametags", clock = "clockhud", grass = "nograss",
		rejoinauto = "autorejoin", tintscreen = "screentint", camoffset = "cameraoffset",
	}

	local function findModule(word)
		local n = norm(word)
		n = aliases[n] or n
		for _, m in ipairs(modules) do
			if norm(m.name) == n then return m end
		end
	end

	local sliderCmds = {
		speed = { "walk speed", "Speed Hack" },
		jump = { "jump power", "Super Jump" },
		flyspeed = { "fly speed", "Fly" },
		spinspeed = { "spin speed", "Spin Bot" },
		gravity = { "gravity", "Gravity" },
		time = { "time of day", "Time Changer" },
		zoom = { "max zoom", "Wide Zoom" },
		fov = { "field of view", nil },
		sprint = { "sprint boost", "Sprint" },
		glide = { "glide speed", "Glide" },
		dash = { "dash power", nil },
		freecam = { "freecam speed", "Freecam" },
		bloom = { "bloom intensity", "Bloom Glow" },
		volume = { "volume", nil },
		namedist = { "name distance", "Far Name Tags" },
		hip = { "hip height", "Hip Height" },
		blur = { "blur size", "Blur" },
		snow = { "snow amount", "Snowfall" },
		rain = { "rain amount", "Rainfall" },
		fog = { "fog distance", "Custom Fog" },
		exposure = { "exposure", "Exposure" },
		climb = { "climb speed", "Wall Climb" },
		blink = { "blink distance", nil },
	}

	local cmds = {}

	cmds.help = function()
		cprint("commands:", accent)
		cprint("  list                - show all modules", SUB)
		cprint("  <module> [on|off]   - toggle a module (fly, esp, bhop...)", SUB)
		cprint("  speed/jump/flyspeed/gravity/time/fov/zoom/dash <number>", SUB)
		cprint("  tp <player>   view <player>   unview", SUB)
		cprint("  to <x> <y> <z>      - teleport to coordinates", SUB)
		cprint("  wp save [name]  /  wp go <name>  /  wp list", SUB)
		cprint("  spawn   rejoin   clear", SUB)
	end

	cmds.list = function()
		for _, m in ipairs(modules) do
			cprint(string.format("  %-22s %s", m.name, m.on and "ON" or "off"), m.on and accent or SUB)
		end
	end

	cmds.clear = function()
		for _, c in ipairs(out:GetChildren()) do
			if c:IsA("TextLabel") then c:Destroy() end
		end
	end

	cmds.tp = function(args)
		local plr = findPlayer(args[1])
		if plr then F.tpTo(plr) cprint("teleported to " .. plr.Name, accent)
		else cprint("player not found", RED) end
	end

	cmds.view = function(args)
		local plr = findPlayer(args[1])
		if plr then F.spectate(plr) cprint("viewing " .. plr.Name, accent)
		else cprint("player not found", RED) end
	end

	cmds.unview = function()
		F.spectate(nil)
		cprint("camera reset", accent)
	end

	cmds.to = function(args)
		local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
		local root = getRoot()
		if x and y and z and root then
			root.CFrame = CFrame.new(x, y, z)
			cprint(string.format("teleported to %d, %d, %d", math.floor(x), math.floor(y), math.floor(z)), accent)
		else
			cprint("usage: to <x> <y> <z>", RED)
		end
	end

	cmds.spawn = function()
		F.tpSpawn()
		cprint("teleported to spawn", accent)
	end

	cmds.wp = function(args)
		local sub = args[1]
		if sub == "save" then
			F.saveWaypoint(args[2])
			cprint("waypoint saved", accent)
		elseif sub == "go" then
			for _, w in ipairs(waypoints) do
				if w.name:lower() == (args[2] or ""):lower() then
					F.goWaypoint(w)
					cprint("teleported to " .. w.name, accent)
					return
				end
			end
			cprint("waypoint not found", RED)
		elseif sub == "list" then
			if #waypoints == 0 then cprint("no waypoints", SUB) end
			for _, w in ipairs(waypoints) do cprint("  " .. w.name, SUB) end
		else
			cprint("usage: wp save [name] | wp go <name> | wp list", RED)
		end
	end

	cmds.rejoin = function()
		cprint("rejoining...", accent)
		pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end)
	end

	cmds.panic = function()
		F.panic()
		cprint("everything turned off", accent)
	end

	cmds.sit = function()
		F.sit()
		cprint("sitting", accent)
	end

	cmds.pos = function()
		local root = getRoot()
		if root then
			local p = root.Position
			cprint(string.format("position: %d, %d, %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z)), accent)
		end
	end

	cmds.blink = function()
		F.blink()
		cprint("blinked forward", accent)
	end

	cmds.attach = function(args)
		local plr = findPlayer(args[1])
		if not plr then
			cprint("player not found", RED)
			return
		end
		if args[2] then
			for _, name in ipairs(F.attachModes) do
				if name:lower() == args[2]:lower() then F.setAttachMode(name) end
			end
		end
		F.attach(plr)
		cprint(F.getAttachMode() .. " attach: " .. plr.Name, accent)
	end

	cmds.detach = function()
		F.attach(nil)
		cprint("detached", accent)
	end

	cmds.headsit = function(args)
		local plr = findPlayer(args[1])
		if not plr then
			cprint("player not found", RED)
			return
		end
		F.setAttachMode("Head")
		F.attach(plr)
		cprint("sitting on " .. plr.Name .. "'s head", accent)
	end

	cmds.back = function()
		F.goBack()
		cprint("went back", accent)
	end

	local function run(text)
		local words = {}
		for w in text:gmatch("%S+") do table.insert(words, w) end
		if #words == 0 then return end
		local first = words[1]:lower()
		local args = { table.unpack(words, 2) }

		local sc = sliderCmds[first]
		if sc and tonumber(args[1]) then
			local setter = sliderSetters[sc[1]]
			if setter then setter(tonumber(args[1])) end
			if sc[2] then
				local m = findModule(sc[2])
				if m and not m.on then setModule(m, true, true) end
			end
			cprint(first .. " set to " .. args[1], accent)
			return
		end

		if cmds[first] then
			cmds[first](args)
			return
		end

		for i = #words, 1, -1 do
			local m = findModule(table.concat(words, "", 1, i))
			if m then
				local state = words[i + 1] and words[i + 1]:lower()
				local want = not m.on
				if state == "on" then want = true elseif state == "off" then want = false end
				setModule(m, want)
				cprint(m.name .. " -> " .. (want and "ON" or "OFF"), want and accent or SUB)
				return
			end
		end

		cprint("unknown command. type help", RED)
	end

	local page = UI.pages["Console"]
	out = new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, 270),
		BackgroundColor3 = Color3.fromRGB(6, 8, 10),
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		LayoutOrder = nextOrder(),
	}, page)
	corner(out, 8)
	reg(out, "ScrollBarImageColor3")
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, out)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8),
	}, out)
	out.MouseEnter:Connect(function() UI.overConsole = true end)
	out.MouseLeave:Connect(function() UI.overConsole = false end)

	local box = new("TextBox", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = CARD,
		TextColor3 = TEXT,
		PlaceholderText = "type a command... (try: help)",
		PlaceholderColor3 = SUB,
		Font = Enum.Font.Code,
		TextSize = 14,
		ClearTextOnFocus = false,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
	}, page)
	corner(box, 8)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10) }, box)

	box.FocusLost:Connect(function(enter)
		if not enter then return end
		local txt = box.Text
		box.Text = ""
		if txt ~= "" then
			cprint("> " .. txt, TEXT)
			local ok, err = pcall(run, txt)
			if not ok then cprint("error: " .. tostring(err), RED) end
		end
		task.defer(function() box:CaptureFocus() end)
	end)

	cprint("NEXUS console ready. type help", accent)
end

-- =====================================================
-- INPUT + BOOT
-- =====================================================
bind(UIS.InputBegan, function(input, processed)
	if unloaded or processed then return end
	if input.KeyCode == UI.menuKey then
		UI.showMenu(not UI.menuOpen)
		return
	end
	if typing() then return end
	for _, m in ipairs(modules) do
		if m.key and input.KeyCode == m.key then
			setModule(m, not m.on)
		end
	end
	for _, a in ipairs(keyActions) do
		if input.KeyCode == a.key then a.fn() end
	end
end)

UI.selectTab("Movement")

-- injection splash
task.spawn(function()
	local splash = new("CanvasGroup", {
		Size = UDim2.new(0, 380, 0, 150),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundColor3 = BG,
		GroupTransparency = 1,
	}, UI.gui)
	corner(splash, 12)
	reg(new("UIStroke", { Thickness = 1.5 }, splash), "Color")
	local sc = new("UIScale", { Scale = 0.85 }, splash)
	tween(sc, { Scale = 1 }, TI.back)
	tween(splash, { GroupTransparency = 0 }, TI.slow)

	reg(new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 50),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = 26,
		Text = "NEXUS CLIENT",
	}, splash), "TextColor3")

	local status = new("TextLabel", {
		Size = UDim2.new(1, -40, 0, 20),
		Position = UDim2.new(0, 20, 0, 70),
		BackgroundTransparency = 1,
		TextColor3 = SUB,
		Font = Enum.Font.Code,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, splash)

	local barBack = new("Frame", {
		Size = UDim2.new(1, -40, 0, 8),
		Position = UDim2.new(0, 20, 0, 105),
		BackgroundColor3 = OFFCOL,
		BorderSizePixel = 0,
	}, splash)
	corner(barBack, 4)
	local bar = reg(new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, barBack), "BackgroundColor3")
	corner(bar, 4)

	local steps = {
		"loading modules...",
		"hooking renderer...",
		"injecting payload...",
		"injection successful",
	}
	for i, s in ipairs(steps) do
		status.Text = "> " .. s
		tween(bar, { Size = UDim2.new(i / #steps, 0, 1, 0) },
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		task.wait(0.5)
	end

	tween(sc, { Scale = 0.9 }, TI.exit)
	local t = tween(splash, { GroupTransparency = 1 }, TI.exit)
	t.Completed:Wait()
	splash:Destroy()
	UI.showMenu(true)
	notify("NEXUS injected successfully")
	log("injected successfully. press RightShift to hide")
end)
