-----------------------------------------------------------------------------------------------
-- Client Lua Script for FrostMod_ThreatBall
-- Author: Frosthaven
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "GameLib"
require "Window"
 
-- DEFINITION ---------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
local UIMAPPERDEMO = {
	uiMapperLib = "uiMapper:0.9",
	defaults = {},
	config   = {},
}

function UIMAPPERDEMO:GetDefaults()
	return {
		checkboxExample = true,
		inputExample    = "Hello World",
		comboExample    = "Yellow",
		sliderExample   = 0,

		colorHexExample   = "FF0000",
		colorRGBAExample  = {r=0,g=255,b=0,a=1},
		colorTableExample = {0,0,255,1},
	}
end

-- INITIALIZATION -----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
function UIMAPPERDEMO:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function UIMAPPERDEMO:Init()
	local bHasConfigureFunction = true
	local strConfigureButtonText = "uiMapper DEMO"
	local tDependencies = {
		self.uiMapperLib
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function UIMAPPERDEMO:OnConfigure()
	if self.ui then
		self.ui.wndMain:Show(true,true)
	end
end

-- ADDON LOADED -------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
function UIMAPPERDEMO:OnLoad()
	-- load default settings -------------------------------------------
	--------------------------------------------------------------------
	self.defaults = self:GetDefaults()
	self.config   = self:GetDefaults()

	-- initialize our ui -----------------------------------------------
	--------------------------------------------------------------------
	local uiMapper = Apollo.GetPackage(self.uiMapperLib).tPackage
	self.ui  = uiMapper:new({
		container = self.config,
		defaults  = self.defaults,
		name      = "uiMapper DEMO",
		author    = "Frosthaven",
		version   = "Demo-" .. self.uiMapperLib,
		slash     = "uimapper",
		onshow    = function(ui)
			ui:log("config panel shown")
		end,
		onhide    = function(ui)
			ui:log("config panel hidden")
		end,
		ondefault = function(ui)
			ui:log("defaults applied")
		end,
	}):build(function(ui)
		self:BuildConfig(ui)
	end)
end

function UIMAPPERDEMO:OnSave(eLevel)
	if (eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character) then
		return nil
	end

	--save the entire config area
	return self.config
end

function UIMAPPERDEMO:OnRestore(eLevel, saved)
	if (eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character) then
		return nil
	end

	for k, v in pairs(self.config) do
		if saved[k] ~= nil then
			self.config[k] = saved[k]
		end
	end
end

-- CREATE INSTANCE ----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
local UIMAPPERDEMOInst = UIMAPPERDEMO:new()
UIMAPPERDEMOInst:Init()
