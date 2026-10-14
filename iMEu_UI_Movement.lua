--============================================================================--
--  iMEu UI — Speed / Noclip / Jump Panel (single-file, no require)
--
--  ใช้งาน: วางไฟล์นี้ใน LocalScript (StarterPlayerScripts) หรือรันใน Executor
--  ปุ่มเปิด/ปิด UI: ค่าเริ่มต้น RightShift (ปรับได้ที่ TOGGLE_KEY)
--
--  โครงสร้างตาม iMEu module เดิม: Validate, Scope, Signal, Memory,
--  StorageAdapter, RuntimeAdapter, Core, iMEu + Service "UI" เพิ่ม
--============================================================================--

local TOGGLE_KEY = Enum.KeyCode.RightShift -- เปลี่ยนเป็น LeftControl หรือ F ก็ได้

local Validate = (function()
local Validate = {}

function Validate.NonEmptyString(value, maxBytes)
	return type(value) == "string"
		and #value > 0
		and #value <= maxBytes
		and value:find("%S") ~= nil
end

function Validate.FiniteNumber(value)
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

function Validate.IntegerInRange(value, minimum, maximum)
	return Validate.FiniteNumber(value)
		and value % 1 == 0
		and value >= minimum
		and value <= maximum
end

function Validate.StorageKey(value)
	return type(value) == "string"
		and #value >= 1
		and #value <= 64
		and value:match("^[%w_%.%-]+$") ~= nil
end

function Validate.ServiceName(value)
	return type(value) == "string"
		and #value >= 1
		and #value <= 64
		and value:match("^[%a_][%w_]*$") ~= nil
end

return table.freeze(Validate)
end)()

local Scope = (function()
local Scope = {}
Scope.__index = Scope

local function dispose(resource)
	local kind = typeof(resource)
	if kind == "RBXScriptConnection" then
		resource:Disconnect()
	elseif kind == "Instance" then
		resource:Destroy()
	elseif type(resource) == "function" then
		resource()
	elseif type(resource) == "table" then
		if type(resource.Destroy) == "function" then
			resource:Destroy()
		elseif type(resource.Disconnect) == "function" then
			resource:Disconnect()
		else
			error("Resource has no Destroy() or Disconnect() method")
		end
	else
		error("Unsupported cleanup resource: " .. kind)
	end
end

local function supported(resource)
	local kind = typeof(resource)
	return kind == "RBXScriptConnection"
		or kind == "Instance"
		or type(resource) == "function"
		or (
			type(resource) == "table"
			and (
				type(resource.Destroy) == "function"
				or type(resource.Disconnect) == "function"
			)
		)
end

function Scope.new()
	return setmetatable({
		_items = {},
		_nextId = 0,
		_destroyed = false,
	}, Scope)
end

function Scope:IsDestroyed()
	return self._destroyed
end

function Scope:Add(resource)
	assert(supported(resource), "Unsupported cleanup resource")
	if self._destroyed then
		local ok, problem = pcall(dispose, resource)
		if not ok then
			warn("[iMEu/Scope] " .. tostring(problem))
		end
		return resource, nil
	end
	self._nextId += 1
	local id = self._nextId
	self._items[id] = resource
	return resource, id
end

function Scope:Remove(id, shouldDispose)
	local resource = self._items[id]
	if resource == nil then
		return false
	end
	self._items[id] = nil
	if shouldDispose then
		local ok, problem = pcall(dispose, resource)
		if not ok then
			warn("[iMEu/Scope] " .. tostring(problem))
		end
	end
	return true
end

function Scope:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for id = self._nextId, 1, -1 do
		local resource = self._items[id]
		self._items[id] = nil
		if resource ~= nil then
			local ok, problem = pcall(dispose, resource)
			if not ok then
				warn("[iMEu/Scope] " .. tostring(problem))
			end
		end
	end
	table.clear(self._items)
end

return Scope
end)()

local Signal = (function()
local Signal = {}
Signal.__index = Signal

function Signal.new(onError)
	assert(
		onError == nil or type(onError) == "function",
		"onError must be a function"
	)
	return setmetatable({
		_listeners = {},
		_nextId = 0,
		_destroyed = false,
		_onError = onError,
	}, Signal)
end

function Signal:Connect(callback)
	assert(not self._destroyed, "Cannot connect to a destroyed signal")
	assert(type(callback) == "function", "Callback must be a function")
	self._nextId += 1
	local id = self._nextId
	local owner = self
	local connection = { Connected = true }
	local entry = { Callback = callback, Connection = connection }
	self._listeners[id] = entry
	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		owner._listeners[id] = nil
	end
	return connection
end

function Signal:Fire(...)
	if self._destroyed then
		return
	end
	local args = table.pack(...)
	local pending = {}
	for _, entry in pairs(self._listeners) do
		table.insert(pending, entry)
	end
	for _, entry in ipairs(pending) do
		task.defer(function()
			if self._destroyed or not entry.Connection.Connected then
				return
			end
			local ok, problem = pcall(
				entry.Callback,
				table.unpack(args, 1, args.n)
			)
			if not ok then
				if self._onError then
					local handled, handlerProblem = pcall(
						self._onError,
						tostring(problem)
					)
					if not handled then
						warn("[iMEu/Signal] " .. tostring(handlerProblem))
					end
				else
					warn("[iMEu/Signal] " .. tostring(problem))
				end
			end
		end)
	end
end

function Signal:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, entry in pairs(self._listeners) do
		entry.Connection.Connected = false
	end
	table.clear(self._listeners)
end

return Signal
end)()

local Memory = (function()
local Memory = {}
Memory.__index = Memory

function Memory.new(options)
	options = options or {}
	assert(type(options) == "table", "Memory options must be a table")
	local maxEntries = options.MaxEntries or 64
	local maxValueBytes = options.MaxValueBytes or 65536
	local maxTotalBytes = options.MaxTotalBytes or 1048576
	assert(Validate.IntegerInRange(maxEntries, 1, 10000), "Invalid MaxEntries")
	assert(Validate.IntegerInRange(maxValueBytes, 1, 1048576), "Invalid MaxValueBytes")
	assert(Validate.IntegerInRange(maxTotalBytes, 1, 16777216), "Invalid MaxTotalBytes")
	return setmetatable({
		Capabilities = {
			Name = "Session memory",
			Persistent = false,
			Scope = "Client session",
		},
		_values = {},
		_count = 0,
		_bytes = 0,
		_maxEntries = maxEntries,
		_maxValueBytes = maxValueBytes,
		_maxTotalBytes = maxTotalBytes,
		_destroyed = false,
	}, Memory)
end

function Memory:_check(key)
	assert(not self._destroyed, "Storage driver is destroyed")
	assert(Validate.StorageKey(key), "Invalid storage key")
end

function Memory:Get(key)
	self:_check(key)
	return true, self._values[key]
end

function Memory:Set(key, value)
	self:_check(key)
	assert(type(value) == "string", "Storage values must be strings")
	if #value > self._maxValueBytes then
		return false, "Value exceeds the per-entry byte limit"
	end
	local previous = self._values[key]
	if previous == nil and self._count >= self._maxEntries then
		return false, "Storage entry limit reached"
	end
	local previousBytes = if previous ~= nil then #previous else 0
	local nextBytes = self._bytes - previousBytes + #value
	if nextBytes > self._maxTotalBytes then
		return false, "Storage total byte limit reached"
	end
	self._values[key] = value
	self._bytes = nextBytes
	if previous == nil then
		self._count += 1
	end
	return true
end

function Memory:Remove(key)
	self:_check(key)
	local previous = self._values[key]
	if previous ~= nil then
		self._bytes -= #previous
		self._count -= 1
		self._values[key] = nil
	end
	return true
end

function Memory:List()
	assert(not self._destroyed, "Storage driver is destroyed")
	local keys = {}
	for key in pairs(self._values) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return true, keys
end

function Memory:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	table.clear(self._values)
	self._count = 0
	self._bytes = 0
end

return Memory
end)()

local StorageAdapter = (function()
local StorageAdapter = {}
StorageAdapter.__index = StorageAdapter

local REQUIRED_METHODS = { "Get", "Set", "Remove", "List" }

function StorageAdapter.new(driver)
	assert(type(driver) == "table", "Storage driver must be a table")
	for _, name in ipairs(REQUIRED_METHODS) do
		assert(
			type(driver[name]) == "function",
			"Storage driver is missing " .. name .. "()"
		)
	end
	local capabilities = driver.Capabilities or {}
	assert(type(capabilities) == "table", "Invalid storage capabilities")
	local name = capabilities.Name or "Custom storage"
	local scope = capabilities.Scope or "Unspecified"
	assert(Validate.NonEmptyString(name, 80), "Invalid storage name")
	assert(Validate.NonEmptyString(scope, 80), "Invalid storage scope")
	assert(
		capabilities.Persistent == nil
			or type(capabilities.Persistent) == "boolean",
		"Persistent must be a boolean"
	)
	return setmetatable({
		_driver = driver,
		_destroyed = false,
		_capabilities = table.freeze({
			Name = name,
			Scope = scope,
			Persistent = capabilities.Persistent == true,
			CanRead = true,
			CanWrite = true,
			CanRemove = true,
			CanList = true,
		}),
	}, StorageAdapter)
end

function StorageAdapter:GetCapabilities()
	return self._capabilities
end

function StorageAdapter:_invoke(method, ...)
	if self._destroyed then
		return false, "Storage adapter is destroyed"
	end
	local result = table.pack(pcall(
		self._driver[method],
		self._driver,
		...
	))
	if not result[1] then
		return false, "Storage driver exception: " .. tostring(result[2])
	end
	if self._destroyed then
		return false, "Storage adapter was destroyed during the operation"
	end
	if type(result[2]) ~= "boolean" then
		return false, "Storage driver returned an invalid result"
	end
	if result[2] == false then
		return false, tostring(result[3] or "Storage operation failed")
	end
	return true, result[3]
end

function StorageAdapter:Get(key)
	if not Validate.StorageKey(key) then
		return false, "Invalid storage key"
	end
	local ok, value = self:_invoke("Get", key)
	if not ok then
		return false, value
	end
	if value ~= nil and type(value) ~= "string" then
		return false, "Storage driver returned a non-string value"
	end
	return true, value
end

function StorageAdapter:Set(key, value)
	if not Validate.StorageKey(key) then
		return false, "Invalid storage key"
	end
	if type(value) ~= "string" then
		return false, "Storage values must be strings"
	end
	return self:_invoke("Set", key, value)
end

function StorageAdapter:Remove(key)
	if not Validate.StorageKey(key) then
		return false, "Invalid storage key"
	end
	return self:_invoke("Remove", key)
end

function StorageAdapter:List()
	local ok, keys = self:_invoke("List")
	if not ok then
		return false, keys
	end
	if type(keys) ~= "table" then
		return false, "Storage driver returned an invalid key list"
	end
	local length = #keys
	if length > 10000 then
		return false, "Storage driver returned too many keys"
	end
	local count = 0
	local seen = {}
	local copy = {}
	for index, key in pairs(keys) do
		count += 1
		if not Validate.IntegerInRange(index, 1, length) then
			return false, "Storage key list must be a dense array"
		end
		if not Validate.StorageKey(key) or seen[key] then
			return false, "Storage key list contains an invalid or duplicate key"
		end
		seen[key] = true
		copy[index] = key
	end
	if count ~= length then
		return false, "Storage key list must be a dense array"
	end
	table.sort(copy)
	return true, copy
end

function StorageAdapter:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if type(self._driver.Destroy) == "function" then
		local ok, problem = pcall(self._driver.Destroy, self._driver)
		if not ok then
			warn("[iMEu/Storage] " .. tostring(problem))
		end
	end
end

return StorageAdapter
end)()

local RuntimeAdapter = (function()
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local RuntimeAdapter = {}
RuntimeAdapter.__index = RuntimeAdapter

local function observe(callback)
	local ok, result = pcall(callback)
	if not ok then
		return nil
	end
	return result
end

local function observationState(value)
	if value == nil then
		return "Unknown"
	end
	return if value then "Available" else "Unavailable"
end

function RuntimeAdapter.new()
	return setmetatable({}, RuntimeAdapter)
end

function RuntimeAdapter:GetReport(storageCapabilities)
	local isClient = observe(function()
		return RunService:IsClient()
	end)
	local isStudio = observe(function()
		return RunService:IsStudio()
	end)
	local touch = observe(function()
		return UserInputService.TouchEnabled
	end)
	local keyboard = observe(function()
		return UserInputService.KeyboardEnabled
	end)
	local gamepad = observe(function()
		return UserInputService.GamepadEnabled
	end)
	local playerGui = observe(function()
		local player = Players.LocalPlayer
		return player ~= nil
			and player:FindFirstChildOfClass("PlayerGui") ~= nil
	end)
	local inset = observe(function()
		GuiService:GetGuiInset()
		return true
	end)
	local json = observe(function()
		return HttpService:JSONDecode('{"ok":true}').ok == true
	end)
	local tween = observe(function()
		return typeof(TweenService) == "Instance"
	end)

	local report = {
		{
			Name = "Environment",
			State = if isClient == true then "Available" else "Unavailable",
			Detail = if isStudio == true
				then "Roblox Studio; client UI requires Play mode"
				else "Roblox runtime; executor identity is not inferred",
		},
		{
			Name = "PlayerGui",
			State = observationState(playerGui),
			Detail = "Documented client GUI parent; readiness can change",
		},
		{
			Name = "TweenService",
			State = observationState(tween),
			Detail = "Documented UI tween service",
		},
		{
			Name = "Touch input",
			State = observationState(touch),
			Detail = "Device capability, not a phone/tablet classification",
		},
		{
			Name = "Keyboard input",
			State = observationState(keyboard),
			Detail = "Keyboard capability observed through UserInputService",
		},
		{
			Name = "Gamepad input",
			State = observationState(gamepad),
			Detail = "Capability observed; gamepad navigation is not implemented yet",
		},
		{
			Name = "GUI inset query",
			State = observationState(inset),
			Detail = "Safe-area layout will also use ScreenGui inset behavior",
		},
		{
			Name = "JSON serialization",
			State = observationState(json),
			Detail = "Structured data only; no configuration code execution",
		},
		{
			Name = "Client DataStore access",
			State = "Unsupported",
			Detail = "Persistent player data requires an authorized server workflow",
		},
		{
			Name = "Local filesystem",
			State = "Unsupported",
			Detail = "No documented Roblox client filesystem driver is installed",
		},
		{
			Name = "Web-hosted icons",
			State = "Unsupported",
			Detail = "HTML packages and arbitrary web images are not GUI assets",
		},
		{
			Name = "Delta / Wave / Arceus X",
			State = "Untested",
			Detail = "No executor-specific functions are called or assumed",
		},
	}

	if storageCapabilities then
		table.insert(report, {
			Name = "Storage",
			State = "Available",
			Detail = storageCapabilities.Name
				.. "; "
				.. storageCapabilities.Scope
				.. "; "
				.. (
					if storageCapabilities.Persistent
					then "persistence declared by driver"
					else "not persistent"
				),
		})
	end

	return report
end

return RuntimeAdapter
end)()

local Core = (function()
local Core = {}
Core.__index = Core

local MAX_DIAGNOSTICS = 80

function Core.new(options)
	options = options or {}
	assert(type(options) == "table", "Core options must be a table")

	local self = setmetatable({
		_factories = {},
		_services = {},
		_serviceScopes = {},
		_serviceOrder = {},
		_resolving = {},
		_resolutionStack = {},
		_diagnostics = {},
		_destroyed = false,
		_rootScope = Scope.new(),
	}, Core)

	self.Error = Signal.new(function(problem)
		warn("[iMEu/Error listener] " .. problem)
	end)

	self.ServiceAdded = Signal.new(function(problem)
		self:ReportError("ServiceAdded", problem)
	end)

	self._rootScope:Add(self.Error)
	self._rootScope:Add(self.ServiceAdded)

	self:RegisterService("Runtime", function()
		return RuntimeAdapter.new()
	end)

	self:RegisterService("Storage", function(_, scope)
		local driver = options.StorageDriver or Memory.new(
			options.MemoryStorage
		)

		local ownershipId

		if type(driver) == "table" and type(driver.Destroy) == "function" then
			local _, id = scope:Add(driver)
			ownershipId = id
		end

		local adapter = StorageAdapter.new(driver)

		if ownershipId then
			scope:Remove(ownershipId, false)
		end

		return adapter
	end)

	return self
end

function Core:IsDestroyed()
	return self._destroyed
end

function Core:RegisterService(name, factory)
	assert(not self._destroyed, "Application is destroyed")
	assert(Validate.ServiceName(name), "Invalid service name")
	assert(type(factory) == "function", "Service factory must be a function")
	assert(self._factories[name] == nil, "Service already registered: " .. name)
	self._factories[name] = factory
end

function Core:HasService(name)
	return self._factories[name] ~= nil
end

function Core:GetService(name)
	assert(not self._destroyed, "Application is destroyed")
	assert(Validate.ServiceName(name), "Invalid service name")

	local existing = self._services[name]
	if existing ~= nil then
		return existing
	end

	local factory = self._factories[name]
	assert(factory ~= nil, "Unknown service: " .. name)

	if self._resolving[name] then
		error(
			"Service dependency cycle: "
				.. table.concat(self._resolutionStack, " -> ")
				.. " -> "
				.. name,
			2
		)
	end

	local scope = Scope.new()
	self._resolving[name] = true
	table.insert(self._resolutionStack, name)

	local ok, result = pcall(factory, self, scope)

	self._resolving[name] = nil
	table.remove(self._resolutionStack)

	if not ok then
		scope:Destroy()
		self:ReportError(name, result)
		error("Could not construct service " .. name .. ": " .. tostring(result), 2)
	end

	if type(result) ~= "table" then
		scope:Destroy()
		error("Service " .. name .. " must return a table", 2)
	end

	if self._destroyed then
		if type(result.Destroy) == "function" then
			scope:Add(result)
		end
		scope:Destroy()
		error("Application was destroyed during service construction", 2)
	end

	if type(result.Destroy) == "function" then
		scope:Add(result)
	end

	self._services[name] = result
	self._serviceScopes[name] = scope
	table.insert(self._serviceOrder, name)

	self.ServiceAdded:Fire(name, result)
	return result
end

function Core:ReportError(source, message)
	if self._destroyed then
		return
	end
	local entry = table.freeze({
		Source = tostring(source),
		Message = tostring(message),
		Timestamp = DateTime.now().UnixTimestampMillis,
	})
	table.insert(self._diagnostics, entry)
	if #self._diagnostics > MAX_DIAGNOSTICS then
		table.remove(self._diagnostics, 1)
	end
	warn("[iMEu/" .. entry.Source .. "] " .. entry.Message)
	self.Error:Fire(entry)
end

function Core:GetDiagnostics()
	local copy = {}
	for index, entry in ipairs(self._diagnostics) do
		copy[index] = {
			Source = entry.Source,
			Message = entry.Message,
			Timestamp = entry.Timestamp,
		}
	end
	return copy
end

function Core:SafeCall(source, callback, ...)
	if self._destroyed then
		return table.pack(false, "Application is destroyed")
	end
	if type(callback) ~= "function" then
		local message = "Callback must be a function"
		self:ReportError(source, message)
		return table.pack(false, message)
	end
	local result = table.pack(pcall(callback, ...))
	if not result[1] then
		self:ReportError(source, result[2])
	end
	return result
end

function Core:GetRuntimeReport()
	local runtime = self:GetService("Runtime")
	local storage = self:GetService("Storage")
	return runtime:GetReport(storage:GetCapabilities())
end

function Core:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._rootScope:Destroy()
	for index = #self._serviceOrder, 1, -1 do
		local name = self._serviceOrder[index]
		self._serviceScopes[name]:Destroy()
	end
	table.clear(self._serviceOrder)
	table.clear(self._serviceScopes)
	table.clear(self._services)
	table.clear(self._factories)
	table.clear(self._diagnostics)
end

return Core
end)()

local iMEu = (function()
local RunService = game:GetService("RunService")

local iMEu = {
	Name = "iMEu",
	Version = "0.1.0",
}

local application = nil

function iMEu:Initialize(options)
	assert(RunService:IsClient(), "iMEu must initialize from a LocalScript")

	if application and not application:IsDestroyed() then
		assert(
			options == nil,
			"iMEu is already initialized; destroy it before changing options"
		)
		return application
	end

	local candidate = Core.new(options)

	local ok, problem = pcall(function()
		candidate:GetService("Runtime")
		candidate:GetService("Storage")
	end)

	if not ok then
		candidate:Destroy()
		error("iMEu initialization failed: " .. tostring(problem), 2)
	end

	application = candidate
	return application
end

function iMEu:IsInitialized()
	return application ~= nil and not application:IsDestroyed()
end

function iMEu:GetService(name)
	return self:Initialize():GetService(name)
end

function iMEu:RegisterService(name, factory)
	self:Initialize():RegisterService(name, factory)
end

function iMEu:GetRuntimeReport()
	return self:Initialize():GetRuntimeReport()
end

function iMEu:Destroy()
	local previous = application
	application = nil
	if previous then
		previous:Destroy()
	end
end

return table.freeze(iMEu)
end)()

--============================================================================--
--  Service: UI — สร้างหน้าต่างควบคุม Speed / Noclip / Jump
--  ลงทะเบียนผ่าน Core:RegisterService("UI", ...) ตามสถาปัตยกรรมเดิม
--============================================================================--

iMEu:RegisterService("UI", function(core, scope)
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local UI = {}
	UI.__index = UI

	local DEFAULT_SPEED = 16
	local DEFAULT_JUMPPOWER = 50

	local state = {
		speed = DEFAULT_SPEED,
		jump = DEFAULT_JUMPPOWER,
		noclip = false,
	}

	-- โหลดค่าที่เคยบันทึกไว้จาก Memory Storage
	local storage = core:GetService("Storage")
	local okSpeed, savedSpeed = storage:Get("ui.speed")
	local okJump, savedJump = storage:Get("ui.jump")
	local okNoclip, savedNoclip = storage:Get("ui.noclip")
	if okSpeed and savedSpeed then
		state.speed = tonumber(savedSpeed) or DEFAULT_SPEED
	end
	if okJump and savedJump then
		state.jump = tonumber(savedJump) or DEFAULT_JUMPPOWER
	end
	if okNoclip and savedNoclip then
		state.noclip = savedNoclip == "1"
	end

	-- ScreenGui หลัก
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "iMEuUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui
	scope:Add(screenGui)

	-- ปุ่มลอยเปิด/ปิดแผง
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "Toggle"
	toggleButton.Size = UDim2.fromOffset(44, 44)
	toggleButton.Position = UDim2.new(1, -60, 0.5, -22)
	toggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleButton.Text = "⚙"
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.TextSize = 20
	toggleButton.AutoButtonColor = true
	toggleButton.Parent = screenGui
	scope:Add(toggleButton)

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, 10)
	toggleCorner.Parent = toggleButton

	-- แผงหลัก
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(260, 300)
	panel.Position = UDim2.new(0.5, -130, 0.5, -150)
	panel.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = screenGui
	scope:Add(panel)

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(70, 70, 90)
	panelStroke.Thickness = 1.5
	panelStroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 36)
	title.BackgroundTransparency = 1
	title.Text = "iMEu — Movement"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.Parent = panel

	-- Helper: สร้างแถว Slider
	local function makeSliderRow(labelText, min, max, defaultValue, yPos, callback)
		local row = Instance.new("Frame")
		row.Name = labelText
		row.Size = UDim2.new(1, -24, 0, 56)
		row.Position = UDim2.new(0, 12, 0, yPos)
		row.BackgroundTransparency = 1
		row.Parent = panel

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, 18)
		label.BackgroundTransparency = 1
		label.Text = labelText
		label.TextColor3 = Color3.fromRGB(200, 200, 210)
		label.Font = Enum.Font.Gotham
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = row

		local valueLabel = Instance.new("TextLabel")
		valueLabel.Size = UDim2.new(0, 50, 0, 18)
		valueLabel.Position = UDim2.new(1, -50, 0, 0)
		valueLabel.BackgroundTransparency = 1
		valueLabel.Text = tostring(defaultValue)
		valueLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
		valueLabel.Font = Enum.Font.GothamBold
		valueLabel.TextSize = 13
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.Parent = row

		local sliderBg = Instance.new("Frame")
		sliderBg.Size = UDim2.new(1, 0, 0, 6)
		sliderBg.Position = UDim2.new(0, 0, 0, 30)
		sliderBg.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
		sliderBg.BorderSizePixel = 0
		sliderBg.Parent = row

		local sliderBgCorner = Instance.new("UICorner")
		sliderBgCorner.CornerRadius = UDim.new(1, 0)
		sliderBgCorner.Parent = sliderBg

		local fill = Instance.new("Frame")
		fill.Size = UDim2.new((defaultValue - min) / (max - min), 0, 1, 0)
		fill.BackgroundColor3 = Color3.fromRGB(90, 160, 255)
		fill.BorderSizePixel = 0
		fill.Parent = sliderBg

		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fill

		local knob = Instance.new("TextButton")
		knob.Size = UDim2.fromOffset(16, 16)
		knob.Position = UDim2.new((defaultValue - min) / (max - min), -8, 0.5, -8)
		knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		knob.Text = ""
		knob.BorderSizePixel = 0
		knob.Parent = sliderBg

		local knobCorner = Instance.new("UICorner")
		knobCorner.CornerRadius = UDim.new(1, 0)
		knobCorner.Parent = knob

		local dragging = false

		local function updateFromX(x)
			local relative = math.clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
			local value = math.floor(min + relative * (max - min) + 0.5)
			value = math.clamp(value, min, max)
			fill.Size = UDim2.new(relative, 0, 1, 0)
			knob.Position = UDim2.new(relative, -8, 0.5, -8)
			valueLabel.Text = tostring(value)
			callback(value)
		end

		knob.MouseButton1Down:Connect(function()
			dragging = true
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement) then
				updateFromX(input.Position.X)
			end
		end)

		sliderBg.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				updateFromX(input.Position.X)
			end
		end)

		return row
	end

	-- Helper: สร้างปุ่ม Toggle
	local function makeToggleRow(labelText, defaultOn, yPos, callback)
		local row = Instance.new("Frame")
		row.Name = labelText
		row.Size = UDim2.new(1, -24, 0, 30)
		row.Position = UDim2.new(0, 12, 0, yPos)
		row.BackgroundTransparency = 1
		row.Parent = panel

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -60, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = labelText
		label.TextColor3 = Color3.fromRGB(200, 200, 210)
		label.Font = Enum.Font.Gotham
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = row

		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(48, 22)
		btn.Position = UDim2.new(1, -48, 0.5, -11)
		btn.BackgroundColor3 = if defaultOn
			then Color3.fromRGB(80, 200, 120)
			else Color3.fromRGB(60, 60, 70)
		btn.Text = if defaultOn then "ON" else "OFF"
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 12
		btn.BorderSizePixel = 0
		btn.Parent = row

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = btn

		local current = defaultOn

		btn.MouseButton1Click:Connect(function()
			current = not current
			btn.BackgroundColor3 = if current
				then Color3.fromRGB(80, 200, 120)
				else Color3.fromRGB(60, 60, 70)
			btn.Text = if current then "ON" else "OFF"
			callback(current)
		end)

		return row
	end

	-- สร้าง UI แต่ละแถว
	makeSliderRow("WalkSpeed", 16, 500, state.speed, 46, function(value)
		state.speed = value
		storage:Set("ui.speed", tostring(value))
	end)

	makeSliderRow("JumpPower", 50, 500, state.jump, 112, function(value)
		state.jump = value
		storage:Set("ui.jump", tostring(value))
	end)

	makeToggleRow("Noclip (งูๆปลาๆ)", state.noclip, 178, function(on)
		state.noclip = on
		storage:Set("ui.noclip", if on then "1" else "0")
	end)

	-- ปุ่ม Reset
	local resetBtn = Instance.new("TextButton")
	resetBtn.Size = UDim2.new(1, -24, 0, 30)
	resetBtn.Position = UDim2.new(0, 12, 0, 224)
	resetBtn.BackgroundColor3 = Color3.fromRGB(200, 80, 80)
	resetBtn.Text = "Reset to Default"
	resetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextSize = 13
	resetBtn.BorderSizePixel = 0
	resetBtn.Parent = panel
	scope:Add(resetBtn)

	local resetCorner = Instance.new("UICorner")
	resetCorner.CornerRadius = UDim.new(0, 8)
	resetCorner.Parent = resetBtn

	resetBtn.MouseButton1Click:Connect(function()
		state.speed = DEFAULT_SPEED
		state.jump = DEFAULT_JUMPPOWER
		state.noclip = false
		storage:Remove("ui.speed")
		storage:Remove("ui.jump")
		storage:Remove("ui.noclip")
		-- รีเฟรช UI
		for _, child in ipairs(panel:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		makeSliderRow("WalkSpeed", 16, 500, state.speed, 46, function(value)
			state.speed = value
			storage:Set("ui.speed", tostring(value))
		end)
		makeSliderRow("JumpPower", 50, 500, state.jump, 112, function(value)
			state.jump = value
			storage:Set("ui.jump", tostring(value))
		end)
		makeToggleRow("Noclip (งูๆปลาๆ)", state.noclip, 178, function(on)
			state.noclip = on
			storage:Set("ui.noclip", if on then "1" else "0")
		end)
	end)

	-- ลากแผง (drag)
	local draggingPanel = false
	local dragStart, panelStart

	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingPanel = true
			dragStart = input.Position
			panelStart = panel.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingPanel = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if draggingPanel and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			panel.Position = UDim2.new(
				panelStart.X.Scale, panelStart.X.Offset + delta.X,
				panelStart.Y.Scale, panelStart.Y.Offset + delta.Y
			)
		end
	end)

	-- เปิด/ปิดแผง
	local panelOpen = false
	local function setPanel(open)
		panelOpen = open
		panel.Visible = open
		if open then
			panel.BackgroundTransparency = 1
			TweenService:Create(panel, TweenInfo.new(0.2), {
				BackgroundTransparency = 0,
			}):Play()
		end
	end

	toggleButton.MouseButton1Click:Connect(function()
		setPanel(not panelOpen)
	end)

	-- ปุ่มลัดคีย์บอร์ด
	scope:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			setPanel(not panelOpen)
		end
	end))

	-- ใส่ค่าเริ่มต้นให้ตัวละคร
	local function applyToCharacter(char)
		local humanoid = char:WaitForChild("Humanoid")
		humanoid.WalkSpeed = state.speed
		humanoid.JumpPower = state.jump
	end

	if player.Character then
		task.spawn(applyToCharacter, player.Character)
	end
	scope:Add(player.CharacterAdded:Connect(function(char)
		task.spawn(applyToCharacter, char)
	end))

	-- Loop หลัก: อัปเดตค่า + Noclip
	scope:Add(RunService.Heartbeat:Connect(function()
		local char = player.Character
		if not char then
			return
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if humanoid.WalkSpeed ~= state.speed then
				humanoid.WalkSpeed = state.speed
			end
			if humanoid.JumpPower ~= state.jump then
				humanoid.JumpPower = state.jump
			end
		end
		if state.noclip then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end))

	function UI:Destroy()
		-- Core จะจัดการ scope ให้อัตโนมัติผ่าน service scope
	end

	return UI
end)

--============================================================================--
--  DEMO: Initialize + เปิด UI ทันที
--============================================================================--

do
	local ok, problem = pcall(function()
		local app = iMEu:Initialize()

		print(string.format(
			"[iMEu] Initialized %s v%s",
			iMEu.Name,
			iMEu.Version
		))

		local ui = app:GetService("UI")
		print("[iMEu] UI service ready — กด RightShift เพื่อเปิด/ปิดแผง")

		local storage = app:GetService("Storage")
		local setOk, setErr = storage:Set("demo.key", "hello-iMEu")
		local getOk, value = storage:Get("demo.key")
		print(string.format(
			"[iMEu] Storage roundtrip: set=%s get=%s value=%q",
			tostring(setOk),
			tostring(getOk),
			tostring(value)
		))
	end)

	if not ok then
		warn("[iMEu] Demo failed: " .. tostring(problem))
	end
end

return iMEu
