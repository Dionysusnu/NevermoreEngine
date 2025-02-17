--[=[
	@class UIConverter
]=]

local require = require(script.Parent.loader).load(script)

local RobloxApiDump = require("RobloxApiDump")
local BaseObject = require("BaseObject")
local Promise = require("Promise")
local PromiseUtils = require("PromiseUtils")
local UIConverterNeverSkipProps = require("UIConverterNeverSkipProps")

local UIConverter = setmetatable({}, BaseObject)
UIConverter.ClassName = "UIConverter"
UIConverter.__index = UIConverter

function UIConverter.new()
	local self = setmetatable(BaseObject.new(), UIConverter)

	self._apiDump = RobloxApiDump.new()
	self._maid:GiveTask(self._apiDump)

	self._promiseDefaultValueCache = {}
	self._propertyPromisesForClass = {}

	return self
end

function UIConverter:PromiseProperties(instance, overrideMap)
	assert(typeof(instance) == "Instance", "Bad instance")
	assert(type(overrideMap) == "table", "Bad overrideMap")

	return self._apiDump:PromiseClass(instance.ClassName)
		:Then(function(class)
			if class:IsService() then
				-- TODO: Mount here
				return Promise.rejected(("%q is a service and cannot be created"):format(class:GetClassName()))
			end

			if class:IsNotCreatable() then
				-- Just don't include this
				return Promise.resolved(nil)
			end

			return self._maid:GivePromise(self:PromisePropertiesForClass(class:GetClassName()))
				:Then(function(properties)
					local map = {}
					local promises = {}


					for _, property in pairs(properties) do
						self._maid:GivePromise(self:PromiseDefaultValue(class, property, overrideMap))
							:Then(function(defaultValue)
								local currentValue = instance[property:GetName()]
								if currentValue ~= defaultValue then
									map[property:GetName()] = currentValue
								end
							end)
					end

					-- Make sure we also include these properties for authoring
					local neverSkip = UIConverterNeverSkipProps[class:GetClassName()]
					if neverSkip then
						for propertyName, _ in pairs(neverSkip) do
							map[propertyName] = instance[propertyName]
						end
					end

					return PromiseUtils.all(promises)
						:Then(function()
							return map
						end)
				end)

		end)
end

function UIConverter:PromiseCanClone(instance)
	assert(typeof(instance) == "Instance", "Bad instance")

	return self._apiDump:PromiseClass(instance.ClassName)
		:Then(function(class)
			return not class:IsNotCreatable()
		end)
end

function UIConverter:PromisePropertiesForClass(className)
	assert(type(className) == "string", "Bad className")

	if self._propertyPromisesForClass[className] then
		return self._propertyPromisesForClass[className]
	end

	self._propertyPromisesForClass[className] = self._maid:GivePromise(self._apiDump:PromiseClass(className))
		:Then(function(class)
			return class:PromiseProperties()
		end)
		:Then(function(allProperties)
			local valid = {}
			for _, property in pairs(allProperties) do
				if not (property:IsHidden()
						or property:IsReadOnly()
						or property:IsNotScriptable()
						or property:IsDeprecated()
						or property:IsWriteNotAccessibleSecurity()
						or property:IsReadNotAccessibleSecurity()
						or property:IsWriteLocalUserSecurity()
						or property:IsReadLocalUserSecurity())
					then

					table.insert(valid, property)
				end
			end
			return valid
		end)
	return self._propertyPromisesForClass[className]
end

function UIConverter:PromiseDefaultValue(class, property, overrideMap)
	assert(type(class) == "table", "Bad class")
	assert(type(property) == "table", "Bad property")
	assert(type(overrideMap) == "table", "Bad overrideMap")

	local propertyName = property:GetName()
	local className = class:GetClassName()

	if property:IsReadLocalUserSecurity() then
		return Promise.resolved(nil)
	end

	if class:IsNotCreatable() then
		return Promise.resolved(nil)
	end

	if not self._promiseDefaultValueCache[className] then
		self._promiseDefaultValueCache[className] = {}
	end

	if self._promiseDefaultValueCache[className][propertyName] then
		return self._promiseDefaultValueCache[className][propertyName]
	end

	local properties = overrideMap[class:GetClassName()]
	if properties and properties[propertyName] then
		self._promiseDefaultValueCache[className][propertyName] = Promise.resolved(properties[propertyName])
	else
		local inst = Instance.new(className)
		self._promiseDefaultValueCache[className][propertyName] = Promise.resolved(inst[propertyName])
		inst:Destroy()
	end

	return self._promiseDefaultValueCache[className][propertyName]
end


return UIConverter