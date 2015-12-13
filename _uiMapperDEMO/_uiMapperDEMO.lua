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
	uiMapperLib = "uiMapper:0.8.2",
	defaults = {},
	config   = {},
}

function UIMAPPERDEMO:GetDefaults()
	return {
		checkboxExample = true,
		inputExample    = "Hello World",
		comboExample    = "Yellow",

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

-- BUILD CONFIG PANEL -------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
function UIMAPPERDEMO:BuildConfig(ui)
	--[[
		if we dont use any categories, then the option panel will not
		include the navigation on the left. Useful for single config
		page addons
	--]]
	ui:category("Control Widgets")
	:header("Data-Mapped Widgets")
	:note("These widgets automatically populate with the values they are mapped to from your addon's configuration. When the values are changed by the user, your addon's configuration is also updated.")
	:check({
		label = "Checkbox Example",
		map   = "checkboxExample",
		onchange = function(wnd)
			ui:log("checkboxExample is now " .. tostring(self.config.checkboxExample))
		end,
	})
	:input({
		label = "Input Example",
		map   = "inputExample",
		onchange = function(wnd)
			ui:log("inputExample is now " .. self.config.inputExample)
		end,
	})
	:choicetable("Foods", {
		{"Apple",  "Red"   },
		{"Lime",   "Green" },
		{"Banana", "Yellow"},
		{"Peacan", "Brown" },
		{"None",   false   },
	})
	:combo({
		label   = "Combobox Example",
		map     = "comboExample",
		choices = "Foods",
		onchange = function(wnd)
			ui:log(wnd:GetText() .. " was chosen, so comboExample is now " .. tostring(self.config.comboExample))
		end,
	})
	:color({
		label  = "Color Hex Example",
		map    = "colorHexExample",
		format = "hex",
		dec    = false,
		onchange = function(wnd)
			ui:log("colorHexExample is now " .. self.config.colorHexExample)
		end,
	})
	:color({
		label  = "Color RGBA Example +Alpha",
		map    = "colorRGBAExample",
		format = "rgba",
		dec    = false, -- if true will return from 0-1 instead of 0-255
		alpha  = true,  -- enables setting opacity
		onchange = function(wnd)
			ui:log("colorHexExample is now {r="..self.config.colorRGBAExample.r..",g="..self.config.colorRGBAExample.g..",b="..self.config.colorRGBAExample.b..",a="..self.config.colorRGBAExample.a.."}")
		end,
	})
	:color({
		label  = "Color Table Example +Alpha",
		map    = "colorTableExample",
		format = "table",
		dec    = false, -- if true will return from 0-1 instead of 0-255
		alpha  = true,  -- enables setting opacity
		onchange = function(wnd)
			ui:log("colorTableExample is now {"..self.config.colorTableExample[1]..","..self.config.colorTableExample[2]..","..self.config.colorTableExample[3]..","..self.config.colorTableExample[4].."}")
		end,
	})
	:header("Extra Widgets")
	:note("These are extra widgets that are not mapped to your addon's configuration but useful none the less")
	:button({
		label = "Button Example",
		onclick = function(wnd)
			ui:log("Button Example Was Clicked!")
		end,
	})

	-- credits page -----------------------------------------
	---------------------------------------------------------
	:navdivider()
	:category("Credits")
	:header("Developer Credits")
	:note("Developed by Frosthaven, and available freely to all.\n \nSpecial thanks to everyone on the Wildstar forums for their support!")
end

-- CREATE INSTANCE ----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
local UIMAPPERDEMOInst = UIMAPPERDEMO:new()
UIMAPPERDEMOInst:Init()
