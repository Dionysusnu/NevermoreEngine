--[=[
	@class SettingProperty
]=]

local require = require(script.Parent.loader).load(script)

local SettingRegistryServiceShared = require("SettingRegistryServiceShared")
local Rx = require("Rx")

local SettingProperty = {}
SettingProperty.ClassName = "SettingProperty"
SettingProperty.__index = SettingProperty

function SettingProperty.new(serviceBag, player, definition)
	local self = setmetatable({}, SettingProperty)

	self._serviceBag = assert(serviceBag, "No serviceBag")
	self._bridge = self._serviceBag:GetService(SettingRegistryServiceShared)

	self._player = assert(player, "No player")
	self._definition = assert(definition, "No definition")

	self:_promisePlayerSettings():Then(function(playerSettings)
		playerSettings:EnsureInitialized(self._definition:GetSettingName(), self._definition:GetDefaultValue())
	end)

	return self
end

function SettingProperty:Observe()
	return self:_observePlayerSettings():Pipe({
		Rx.where(function(settings)
			return settings ~= nil
		end);
		Rx.take(1);
		Rx.switchMap(function()
			-- Ensure we're loaded first and then register for real.
			return self:_observePlayerSettings()
		end);
		Rx.switchMap(function(playerSettings)
			if not playerSettings then
				-- Don't emit until we have a value
				return Rx.of(self._definition:GetDefaultValue())
			else
				return playerSettings:ObserveValue(self._definition:GetSettingName(), self._definition:GetDefaultValue())
			end
		end);
	})
end

function SettingProperty:__index(index)
	if index == "Value" then
		local settings = self:_getPlayerSettings()
		if settings then
			return settings:GetValue(self._definition:GetSettingName(), self._definition:GetDefaultValue())
		else
			return self._definition:GetDefaultValue()
		end
	elseif index == "Changed" then
		return {
			Connect = function(callback)
				return self:Observe():Pipe({
					-- TODO: Handle scenario where we're loading and .Value changes because of what
					-- we queried.
					Rx.skip(1);
				}):Subscribe(callback)
			end;
		}
	elseif index == "DefaultValue" then
		return self._definition:GetDefaultValue()
	elseif SettingProperty[index] then
		return SettingProperty[index]
	else
		error(("%q is not a member of SettingProperty %s"):format(tostring(index), self._definition:GetSettingName()))
	end
end

function SettingProperty:__newindex(index, value)
	if index == "Value" then
		self:SetValue(value)
	elseif index == "DefaultValue" or index == "Changed" or SettingProperty[index] then
		error(("Cannot set %q"):format(tostring(index)))
	else
		rawset(self, index, value)
	end
end

function SettingProperty:SetValue(value)
	local settings = self:_getPlayerSettings()
	if settings then
		settings:SetValue(self._definition:GetSettingName(), value)
	else
		warn("Cannot set setting value. Use :PromiseSetValue() to ensure value is set after load.")
	end
end

function SettingProperty:PromiseValue()
	return self:_promisePlayerSettings()
		:Then(function(playerSettings)
			return playerSettings:GetValue(self._definition:GetSettingName(), self._definition:GetDefaultValue())
		end)
end

function SettingProperty:PromiseSetValue(value)
	return self:_promisePlayerSettings()
		:Then(function(playerSettings)
			playerSettings:SetValue(self._definition:GetSettingName(), value)
		end)
end

function SettingProperty:RestoreDefault()
	local settings = self:_getPlayerSettings()
	if settings then
		settings:RestoreDefault(self._definition:GetSettingName(), self._definition:GetDefaultValue())
	else
		warn("Cannot set setting value. Use :PromiseSetValue() to ensure value is set after load.")
	end
end

function SettingProperty:_observePlayerSettings()
	return self._bridge:ObservePlayerSettings(self._player)
end

function SettingProperty:_getPlayerSettings()
	return self._bridge:GetPlayerSettings(self._player)
end

function SettingProperty:_promisePlayerSettings()
	return self._bridge:PromisePlayerSettings(self._player)
end



return SettingProperty