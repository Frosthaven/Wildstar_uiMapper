local UIMAPPERDEMO = Apollo.GetAddon("_uiMapperDEMO")

function UIMAPPERDEMO:BuildConfig(ui)
	--[[
		if we dont use any categories, then the option panel will not
		include the navigation on the left. Useful for single config
		page addons
	--]]
	ui:category("Control Widgets")
	:header("Data-Mapped Widgets")
	:note("These widgets automatically populate with the values they are mapped to from your addon's configuration. When the values are changed by the user, your addon's configuration is also updated.")
	:pagedivider()
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
	:slider({
		label = "Slider Example",
		map   = "sliderExample",
		range = "-100,100",
		onchange = function(wnd)
			ui:log("sliderExample is now " .. self.config.sliderExample)
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
	:pagedivider()
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