--[=[
	This represents a list of key bindings for a specific mode. While this is a useful object to query
	for showing icons and input hints to the user, in general, it is recommended that binding occur
	at the list level instead of at the input mode level. That way, if the user switches to another input
	mode then input is immediately processed.

	@class InputKeyMap
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local ValueObject = require("ValueObject")
local InputModeType = require("InputModeType")

local InputKeyMap = setmetatable({}, BaseObject)
InputKeyMap.ClassName = "InputKeyMap"
InputKeyMap.__index = InputKeyMap

function InputKeyMap.new(inputModeType, inputTypes)
	assert(InputModeType.isInputModeType(inputModeType), "Bad inputModeType")
	assert(type(inputTypes) == "table" or inputTypes == nil, "Bad inputTypes")

	local self = setmetatable(BaseObject.new(), InputKeyMap)

	self._inputModeType = assert(inputModeType, "No inputModeType")

	self._defaultInputTypes = inputTypes or {}

	self._inputType = ValueObject.new(self._defaultInputTypes)
	self._maid:GiveTask(self._inputType)

	return self
end

--[=[
	Gets the input mode for this keymap. This will not change.
]=]
function InputKeyMap:GetInputModeType()
	return self._inputModeType
end

function InputKeyMap:SetInputTypesList(inputTypes)
	assert(type(inputTypes) == "table", "Bad inputTypes")

	self._inputType.Value = inputTypes
end

function InputKeyMap:GetDefaultInputTypesList()
	return self._defaultInputTypes
end

function InputKeyMap:RestoreDefault()
	self._inputType.Value = self._defaultInputTypes
end

function InputKeyMap:ObserveInputTypesList()
	return self._inputType:Observe()
end

function InputKeyMap:GetInputTypesList()
	return self._inputType.Value
end

return InputKeyMap