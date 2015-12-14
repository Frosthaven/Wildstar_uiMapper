local MAJOR = "uiMapper:0.9"
MINOR = 1
--[[-------------------------------------------------------------------------------------------
	Client Lua Script for _uiMapper

	Copyright (c) Frosthaven. All rights reserved
	http://twitter.com/thefrosthaven

	This library is responsible for:
		- Quickly generating robust option panels on the fly
		- Integrating addons into the game's UI
		- Mapping option panel controls directly to data
		- Hopefully, being pretty awesome?

	TODO:
		- add text multiline control
		- figure out way to limit text input to maxchar
		- figure out way to change text input colors
		- update sync to work with all control types (ongoing)
		- add a reset all button on the panel (eventually)
			- would need addon to send a table containing default variables
---------------------------------------------------------------------------------------------]]

-- LOADING ------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
local Lib = Apollo.GetPackage(MAJOR) and Apollo.GetPackage(MAJOR).tPackage or {}
if Lib and (Lib._VERSION or 0) >= MINOR then
	return -- no upgrade is needed
end

Lib._VERSION = MINOR

-- SHARED VALUES ------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
--naming conventions
Lib.conventions = {
	navPrefix     = "uiMapper_Nav_",
	pagePrefix    = "uiMapper_Page_",
	controlPrefix = "uiMapper_Control_",
	comboListSep  = "\\",
}

-- INSTANTIATION ------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
function Lib:new(params)
    o = {}
    setmetatable(o, self)
    self.__index = self

    --register the initial meta data
    o.meta = {
    	container = params.container,
    	defaults  = params.defaults,
    	name      = params.name,
		author    = params.author,
		version   = params.version,
		slash     = params.slash,
		callbacks = {
			onshow    = params.onshow,
			onhide    = params.onhide,
			ondefault = params.ondefault,
		},
	}

    return o
end

-- INITIALIZATION -----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
function Lib:build(callback)
	--the user is requesting to build, so let's set the workspace for them
	--the build method requires a callback
	if not callback or type(callback) ~= 'function' then
		return
	end

	--store the callback so we can let the user know when we're ready
	self.callback = callback

	--load our config template
	self.xmlDoc = XmlDoc.CreateFromFile("_uiMapper/panel.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)

	return self
end

-- UIMAPPER EVENTS ----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
function Lib:OnDocLoaded()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "uiMapperForm", nil, self)

		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the uiMapper window for some reason.")
			return
		end

		--config panel setup
		self:PrepareWindow()
		self.wndMain:Show(false, true)

		--slash command setup
		if self.meta.slash then
			local slashLabel = self.wndMain:FindChild("SlashCommand")
			slashLabel:SetText("/" .. self.meta.slash)
			slashLabel:Invoke()
			Apollo.RegisterSlashCommand(self.meta.slash, "OnSlashCommand", self)
		end
		if self.callback and type(self.callback) == 'function' then
			--set up the workspace for this ui
			self.callback(self)
		end
	end
end

-- CONTROL EVENTS -----------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
--main panel
function Lib:OnMainWindowHide(wndHandle, wndControl)
	if wndControl:GetName() ~= self.wndMain:GetName() then return end
	if self.meta.callbacks.onhide and type(self.meta.callbacks.onhide) == 'function' then
		self.meta.callbacks.onhide(self)
	end
end

function Lib:OnMainWindowShow(wndHandle, wndControl)
	if wndControl:GetName() ~= self.wndMain:GetName() then return end
	if self.meta.callbacks.onshow and type(self.meta.callbacks.onshow) == 'function' then
		self.meta.callbacks.onshow(self)
	end
end

function Lib:OnSlashCommand()
	if self.wndMain:IsVisible() then
		self.wndMain:Close()
	else
		self.wndMain:Invoke()
	end
end

function Lib:OnWindowMouseDown(wndHandle)
	wndHandle:ToFront()
end

function Lib:OnWindowClose(wndHandle)
	self:CloseAllPopups()
	self.wndMain:Close()
end

function Lib:OnComboListClose(wndHandle)
	wndHandle:GetParent():Close()
end

function Lib:DisablePanels()
	self.wndMain:FindChild("Blocker"):Invoke()
	self.wndMain:FindChild("ContentRegion"):Enable(false)
end

function Lib:EnablePanels()
	self.wndMain:FindChild("Blocker"):Show(false, true)
	self.wndMain:FindChild("ContentRegion"):Enable(true)
end

--defaults
function Lib:OnRestoreDefaultsButtonClick(wndHandle)
	wndHandle:GetParent():FindChild("PopupRestoreDefaults"):Show(true, true)
end

function Lib:OnRestoreDefaultsCancel(wndHandle)
	wndHandle:GetParent():Close()
end

function Lib:OnRestoreDefaultsConfirm(wndHandle)
	--set our mapped values to our default values

	for k, v in pairs(self.mappings) do
		--does a default exist for this value?
		self:RestoreDefaultFromMap(k)
	end

	--run any callbacks
	if self.meta.callbacks.ondefault and type(self.meta.callbacks.ondefault) == 'function' then
		self.meta.callbacks.ondefault(self)
	end

	--reload the ui
	RequestReloadUI()
end

--navigation
function Lib:OnNavChange(wndHandle)
	--show the options page associated with this nav button
	--strip out our prefix for the exact category name
	local categoryName  = wndHandle:GetName():gsub(self.conventions.navPrefix,"")
	local pageContainer = self:GetPageByCategory(categoryName)

	self:ClearOtherNavigation(categoryName)
	pageContainer:Invoke()
	self:CloseAllPopups()
end

--checkbox
function Lib:OnCheckChange(wndHandle)
	local map  = wndHandle:GetName():gsub(self.conventions.controlPrefix,"")
	local data = self:LookupMap(map)

	--update the user's variable
	local value = wndHandle:IsChecked()
	self:SetMapped(map, value)

	--onchange callback
	if data.callbacks.onchange and type(data.callbacks.onchange) == 'function' then
		data.callbacks.onchange(wndHandle)
	end
end

--input
function Lib:OnInputChange(wndHandle)
	local map  = wndHandle:GetName():gsub(self.conventions.controlPrefix,"")
	local data = self:LookupMap(map)

	--update the user's variable
	local value = wndHandle:GetText()

	if (data.format == "number") then
		value = tonumber(value)
	end

	--update the user's variable
	self:SetMapped(map, value)

	--onchange callback
	if data.callbacks.onchange and type(data.callbacks.onchange) == 'function' then
		data.callbacks.onchange(wndHandle)
	end
end

--custom button
function Lib:OnButtonClick(wndHandle)
	local name = wndHandle:GetName()
	if self.buttons[name] and type(self.buttons[name]) == 'function' then
		self.buttons[name](wndHandle)
	end
end

--slider
function Lib:OnSliderUpdate(wndHandle)
	local map = wndHandle:GetParent():GetName():gsub(self.conventions.controlPrefix,"")
	local data = self:LookupMap(map)
	local editbox = wndHandle:GetParent():FindChild("editbox")
	local nValue = math.floor(tonumber(wndHandle:GetValue()))

	editbox:SetText(nValue)

	--update the user's variable
	self:SetMapped(map, tonumber(nValue))

	--callback
	if data.callbacks.onchange and type(data.callbacks.onchange) == 'function' then
		data.callbacks.onchange(wndHandle)
	end
end

function Lib:OnSliderEditboxUpdate(wndHandle)
	local map = wndHandle:GetParent():GetName():gsub(self.conventions.controlPrefix,"")
	local data = self:LookupMap(map)
	local slider = wndHandle:GetParent():FindChild("slider")
	local nValue = tonumber(wndHandle:GetText())

	--validate the input, but make sure we allow negative sign entry "-"
	if wndHandle:GetText() == "-" then
		nValue = data.lrange
	else
		if type(nValue) == "nil" then
			nValue = data.hrange
			wndHandle:SetText(data.hrange)
		elseif nValue < tonumber(data.lrange) then
			nValue = tonumber(data.lrange)
			wndHandle:SetText(data.lrange)
		elseif nValue > tonumber(data.hrange) then
			nValue = tonumber(data.hrange)
			wndHandle:SetText(data.hrange)
		end
	end

	slider:SetValue(tonumber(nValue))

	--update the user's variable
	self:SetMapped(map, tonumber(nValue))

	--callback
	if data.callbacks.onchange and type(data.callbacks.onchange) == 'function' then
		data.callbacks.onchange(wndHandle)
	end
end

--combo button
function Lib:OnComboButtonClick(wndHandle)
	local map = wndHandle:GetName():gsub(self.conventions.controlPrefix,"")
	local data = self:LookupMap(map)

	--register this map for the combolist
	self.useComboMap = map

	--prepare the popup
	local popup = self.wndMain:FindChild("PopupMultiChoice")
	local panel = self.wndMain:FindChild("MultiChoiceRegion")
	popup:FindChild("label"):SetText(data.label)

	--destroy all combobox entries
	for k, option in pairs(panel:GetChildren()) do
		option:Destroy()
	end

	--populate our items
	for k, v in pairs(self.choices[data.choices]) do
		--v[1] is label, v[2] is value
		local control  = Apollo.LoadForm(self.xmlDoc, "controlComboOption", panel, self)
		if control then
			local button = control:FindChild("button")

			button:SetText(v[1])

			if data.callbacks.onitemadded and type(data.callbacks.onitemadded) == 'function' then
				data.callbacks.onitemadded(button)
			end

			panel:ArrangeChildrenVert()
			panel:SetVScrollPos(0)
		end
	end
	if data.callbacks.onpopulated and type(data.callbacks.onpopulated) == 'function' then
		data.callbacks.onpopulated(panel)
	end
	popup:Invoke()
end

function Lib:OnComboOptionClick(wndHandle)
	local data = self:LookupMap(self.useComboMap)
	local source = self.wndMain:FindChild(self.conventions.controlPrefix .. self.useComboMap)
	local label = wndHandle:GetText()
	local value = self:GetComboValueByLabel(data.choices, label)

	--update the source button
	source:SetText(label)

	--update the user's variable
	self:SetMapped(self.useComboMap, value)

	--close the popup
	self.wndMain:FindChild("PopupMultiChoice"):Close()

	--onchange callback
	if data.callbacks.onchange and type(data.callbacks.onchange) == 'function' then
		data.callbacks.onchange(source)
	end
end

--color button
function Lib:OnColorButtonClick(wndHandle)
	local map = wndHandle:GetName():gsub(self.conventions.controlPrefix,"")
	local data = self:LookupMap(map)
	local swatch = self.wndMain:FindChild(self.conventions.controlPrefix .. map):FindChild("Inner")
	local picker = self.wndMain:FindChild("ColorPicker")
	local slider = self.wndMain:FindChild("PopupColorPicker"):FindChild("FillOpacitySlider")

	self.useColorMap = map

	--prepare the popup
	local opacity = swatch:GetBGOpacity()
	slider:SetValue(opacity*100)
	self:OnFillOpacityChanged(slider, slider, opacity*100)

	if data.alpha and data.format ~= 'hex' then
		self.wndMain:FindChild("PopupColorPicker:OpacitySlider"):Show(true, true)
		self:GrowColorPicker()
	else
		self.wndMain:FindChild("PopupColorPicker:OpacitySlider"):Show(false, true)
		self:ShrinkColorPicker()
	end

	self.wndMain:FindChild("PopupColorPicker:label"):SetText(data.label)

	--set the dialogue colors using the button swatch
	local color = swatch:GetBGColor()
	self:SetColorPicker(color)
	self:OnColorPickerChange(picker, picker, color)

	--show the popup
	self.wndMain:FindChild("PopupColorPicker"):Show(true,true)
end

function Lib:OnColorPickerCancel(wndHandle)
	wndHandle:GetParent():Close()
end

function Lib:OnRGBColorChange(wndHandle)
	local container = wndHandle:GetParent()
	local rgbColor = {}
	rgbColor.r = tonumber(container:FindChild("R_EditBox"):GetText())
	rgbColor.g = tonumber(container:FindChild("G_EditBox"):GetText())
	rgbColor.b = tonumber(container:FindChild("B_EditBox"):GetText())

	--set the hex edit box
	container:FindChild("Hex_EditBox"):SetText(self:RGBtoHEX(rgbColor))

	--update the preview
	container:FindChild("ColorPreview:Inner"):SetBGColor({rgbColor.r/255.0, rgbColor.g/255.0, rgbColor.b/255.0, 1.0})

	--set the color picker
	self:SetColorPicker(rgbColor)
end

function Lib:OnColorPickerChange(wndHandle, wndControl, crNewColor)
	local colorpickerContainer = wndControl:GetParent()

	local nRed = math.floor(crNewColor.r * 255.0)
	local nGreen = math.floor(crNewColor.g * 255.0)
	local nBlue = math.floor(crNewColor.b * 255.0)

	local acolor = ApolloColor.new(nRed, nGreen, nBlue)

	--set the edit boxes
	colorpickerContainer:FindChild("R_EditBox"):SetText(nRed)
	colorpickerContainer:FindChild("G_EditBox"):SetText(nGreen)
	colorpickerContainer:FindChild("B_EditBox"):SetText(nBlue)
	colorpickerContainer:FindChild("Hex_EditBox"):SetText(self:RGBtoHEX({r = nRed, g = nGreen, b = nBlue}))

	--update the preview
	colorpickerContainer:FindChild("ColorPreview:Inner"):SetBGColor({crNewColor.r, crNewColor.g, crNewColor.b, 1.0})
end

function Lib:OnHexColorChange(wndControl)
	--set r, g, b labels and picker
	local hex       = wndControl:GetText()
	local container = wndControl:GetParent()
	local rgbColor  = self:HEXtoRGB(hex)

	--set the edit boxes
	container:FindChild("R_EditBox"):SetText(rgbColor.r)
	container:FindChild("G_EditBox"):SetText(rgbColor.g)
	container:FindChild("B_EditBox"):SetText(rgbColor.b)

	--set the color picker
	self:SetColorPicker(rgbColor)

	--update the preview
	container:FindChild("ColorPreview:Inner"):SetBGColor({rgbColor.r/255.0, rgbColor.g/255.0, rgbColor.b/255.0, 1.0})
end

function Lib:OnColorPickerApply(wndHandle, wndControl)
	--what color did we select?
	local map    = self.useColorMap
	local data   = self:LookupMap(map)
	local color  = wndHandle:GetParent():FindChild("ColorPreview:Inner"):GetBGColor()
	local swatch = self.wndMain:FindChild(self.conventions.controlPrefix .. self.useColorMap):FindChild("Inner")
	local opacity = self.wndMain:FindChild("PopupColorPicker"):FindChild("FillOpacitySlider"):GetValue()/100

	--color here is in dec format {1, 1, 1, 1}
	swatch:SetBGColor(color)
	swatch:SetBGOpacity(opacity)

	--which format did we want?
	local returnColor
	if data.format == 'hex' then
		returnColor = wndHandle:GetParent():FindChild("Hex_EditBox"):GetText()
	elseif data.format == 'rgba' then
		returnColor = {r=color.r, g=color.g, b=color.b, a=opacity}
	elseif data.format == 'table' then
		returnColor = {[1]=color.r, [2]=color.g, [3]=color.b, [4]=opacity}
	end

	--are we using decimal values?
	if data.format == 'table' and not data.dec then
		returnColor[1] = math.floor(returnColor[1]*255)
		returnColor[2] = math.floor(returnColor[2]*255)
		returnColor[3] = math.floor(returnColor[3]*255)
	elseif data.format == 'rgba' and not data.dec then
		returnColor.r = math.floor(returnColor.r * 255)
		returnColor.g = math.floor(returnColor.g * 255)
		returnColor.b = math.floor(returnColor.b * 255)
	end

	--update the user's variable
	self:SetMapped(map, returnColor)

	--close the popup
	wndHandle:GetParent():Close()

	if data.callbacks.onchange and type(data.callbacks.onchange) == 'function' then
		data.callbacks.onchange(swatch)
	end
end

function Lib:OnFillOpacityChanged(wndHandle, wndControl, fNewValue)
	local swatch  = wndHandle:GetParent():GetParent():FindChild("ColorPreview:Inner")
	local editbox = wndHandle:GetParent():GetParent():FindChild("FillOpacityEditbox")
	swatch:SetBGOpacity(fNewValue/100, 0.0)
	editbox:SetText(math.floor(fNewValue))
end

function Lib:OnFillOpacityEditChanged(wndHandle, wndControl)
	local slider = self.wndMain:FindChild("PopupColorPicker"):FindChild("FillOpacitySlider")
	local value
	local numType = type(tonumber(wndControl:GetText()))
	if numType == 'number' then
		value = tonumber(wndControl:GetText())
		if value > 100 then
			value = 100
		elseif value < 0 then
			value = 0
		end
	else
		value = 0
	end
	slider:SetValue(value)
end

-- EXTERNAL BUILDER METHODS -------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
function Lib:category(name)
	--set our selected category, creating it if it doesn't exist
	local category = self:GetPageByCategory(name) or self:NewCategory(name)
	self.useCategory = name

	--register this category for navigation
	self.categories = self.categories or {}
	self.categories[name] = true

	return self
end

function Lib:header(text)
	self:CategoryCheck()
	local page = self:GetPageByCategory(self.useCategory):FindChild("ContentRegion")
	local control = Apollo.LoadForm(self.xmlDoc, "controlHeader", page, self)
	if control then
		control:SetText(text)
		page:ArrangeChildrenVert()
	end

	return self
end

function Lib:note(text)
	self:CategoryCheck()
	local page = self:GetPageByCategory(self.useCategory):FindChild("ContentRegion")
	local control = Apollo.LoadForm(self.xmlDoc, "controlNote", page, self)
	if control then
		local note = control:FindChild("note")
		note:SetText(text)

		--notes should resize to show the entire string
		nWidth, nHeight = note:SetHeightToContentHeight()
		nHeight = nHeight + 10
		nLeft, nTop, nRight, nBottom = control:GetAnchorOffsets()
		control:SetAnchorOffsets(nLeft, nTop, nRight, nTop + nHeight + 3)

		page:ArrangeChildrenVert()
	end

	return self
end

function Lib:check(params)
	self:CategoryCheck()
	local page = self:GetPageByCategory(self.useCategory):FindChild("ContentRegion")
	local control = Apollo.LoadForm(self.xmlDoc, "controlCheckbox", page, self)
	if control then
		local checkbox = control:FindChild("checkbox")
		checkbox:SetText(params.label)

		--map this control
		if params.map then
			local mValue = self:GetMapped(params.map)

			--initialize the element
			checkbox:SetName(self.conventions.controlPrefix .. params.map)
			checkbox:SetCheck(mValue)

			--save our mapping
			self:RegisterMap(params.map, {
				ctype = "checkbox",
				value = mValue,
				callbacks = {
					onchange = params.onchange
				},
			})
		end

		page:ArrangeChildrenVert()
	end

	return self
end

function Lib:input(params)
	self:CategoryCheck()
	local page = self:GetPageByCategory(self.useCategory):FindChild("ContentRegion")
	local control = Apollo.LoadForm(self.xmlDoc, "controlInput", page, self)
	if control then
		local label   = control:FindChild("label")
		local editbox = control:FindChild("editbox")

		label:SetText(params.label)

		--map this control
		if params.map then
			local mValue = self:GetMapped(params.map)

			--initialize the element
			editbox:SetName(self.conventions.controlPrefix .. params.map)
			editbox:SetText(mValue)

			--save our mapping
			self:RegisterMap(params.map, {
				ctype = "input",
				value = mValue,
				format = params.format,
				callbacks = {
					onchange = params.onchange
				},
			})
		end
		page:ArrangeChildrenVert()
	end

	return self
end

function Lib:button(params)
	self:CategoryCheck()
	local page = self:GetPageByCategory(self.useCategory):FindChild("ContentRegion")
	local control = Apollo.LoadForm(self.xmlDoc, "controlButton", page, self)
	if control then
		local button = control:FindChild("button")
		button:SetText(params.label)

		self.buttons = self.buttons or {}
		local count = 0
		for _ in pairs(self.buttons) do count = count + 1 end
		local name = self.conventions.controlPrefix .. count
		button:SetName(name)
		self.buttons[name] = params.onclick

		page:ArrangeChildrenVert()
	end

	return self
end

--choice table
function Lib:choicetable(name, list)
	--store the choices
	self.choices = self.choices or {}
	self.choices[name] = list

	return self
end

--slider
function Lib:slider(params)
	self:CategoryCheck()
	local page = self:GetPageByCategory(self.useCategory):FindChild("ContentRegion")
	local control = Apollo.LoadForm(self.xmlDoc, "controlSlider", page, self)
	if control then
		local slider  = control:FindChild("slider")
		local editbox = control:FindChild("editbox")
		local label   = control:FindChild("label")

		label:SetText(params.label)

		local range = self:str_split(params.range)
		local lrange = tonumber(range[1])
		local hrange = tonumber(range[2])

		slider:SetMinMax(tonumber(range[1]), tonumber(range[2]))

		--map this control
		if params.map then
			local mValue = self:GetMapped(params.map)

			--initialize the element
			--for sliders we need to change the container name
			slider:GetParent():SetName(self.conventions.controlPrefix .. params.map)

			--validate the current value against the provided range
			if type(tonumber(mValue)) == "nil" then
				mValue = hrange
			elseif mValue < lrange then
				mValue = lrange
			elseif mValue > hrange then
				mValue = hrange
			end
			self:SetMapped(params.map, mValue)

			editbox:SetText(mValue)
			slider:SetValue(mValue)

			--save our mapping
			self:RegisterMap(params.map, {
				ctype     = "slider",
				value     = mValue,
				label     = params.label,
				lrange    = lrange,
				hrange    = hrange,
				callbacks = {
					onchange = params.onchange,
				},
			})
		end
		page:ArrangeChildrenVert()
	end

	return self
end

--radiogroup
function Lib:radiogroup(params)
	self:CategoryCheck()
	return self
end

--combobox / dropdown
function Lib:combo(params)
	self:CategoryCheck()
	local page = self:GetPageByCategory(self.useCategory):FindChild("ContentRegion")
	local control = Apollo.LoadForm(self.xmlDoc, "controlComboButton", page, self)
	if control then
		local button = control:FindChild("button")
		local label  = control:FindChild("label")

		label:SetText(params.label)

		--map this control
		if params.map then
			local mValue = self:GetMapped(params.map)

			--initialize the element
			button:SetName(self.conventions.controlPrefix .. params.map)

			--lets set the initial button text to the mapped value's name
			local foundSetting = false
			for k, v in pairs(self.choices[params.choices]) do
				--if there is no value, then set the value to the label
				if v[2] == nil then v[2] = v[1] end

				--is this entry the current set value?
				if (v[2] == mValue) then
					--we found the entry that matches
					button:SetText(tostring(v[1]))
					foundSetting = true
				end
			end
			if not foundSetting then
				--invalid setting found, lets use the first entry
				--this can happen if an addon author removes a feature
				--that was once available in the choicetable provided
				button:SetText(tostring(self.choices[params.choices][1][1]))
				self:SetMapped(params.map, self.choices[params.choices][1][2])
			end

			--save our mapping
			self:RegisterMap(params.map, {
				ctype     = "combo",
				value     = mValue,
				label     = params.label,
				choices   = params.choices,
				callbacks = {
					onchange    = params.onchange,
					onitemadded = params.onitemadded,
					onpopulated = params.onpopulated,
				},
			})
		end
		page:ArrangeChildrenVert()
	end

	return self
end

function Lib:color(params)
	self:CategoryCheck()
	local page = self:GetPageByCategory(self.useCategory):FindChild("ContentRegion")
	local control = Apollo.LoadForm(self.xmlDoc, "controlColor", page, self)
	if control then
		local mValue = self:GetMapped(params.map)
		local label  = control:FindChild("label")
		local button = control:FindChild("Button")
		local swatch = control:FindChild("Inner")

		params.dec = params.dec or false
		local dFormat = self:DetectColorFormat(mValue)

		--lets get our rgba value using the detected color format
		local rgba
		if dFormat == 'hex' then
			rgba = self:HEXtoRGB(mValue)
		elseif dFormat == 'rgba' then
			rgba = {r=mValue.r, g=mValue.g, b=mValue.b, a=mValue.a or 1}
		elseif dFormat == 'table' then
			rgba = {r=mValue[1], g=mValue[2], b=mValue[3], a=mValue[4] or 1}
		end

		if not params.dec then
			--we need to convert the params to use dec for the preview swatch
			rgba.r = rgba.r/255
			rgba.g = rgba.g/255
			rgba.b = rgba.b/255
		end

		--initialize the control
		swatch:SetBGColor({tonumber(rgba.r), tonumber(rgba.g), tonumber(rgba.b) ,1})
		if params.alpha then
			swatch:SetBGOpacity(rgba.a)
		else
			swatch:SetBGOpacity(1)
		end
		label:SetText(params.label)

		if (params.map) then
			--initialize the control
			button:SetName(self.conventions.controlPrefix .. params.map)

			--save our mapping
			self:RegisterMap(params.map, {
				ctype  = "color",
				label  = params.label,
				value  = mValue,
				dec    = params.dec,
				alpha  = params.alpha,
				format = params.format or dFormat,
				color  = rgba,
				callbacks = {
					onchange = params.onchange
				},
			})
		end

		page:ArrangeChildrenVert()
	end
	
	return self
end
--page divider
function Lib:pagedivider(params)
	self:CategoryCheck()
	local page = self:GetPageByCategory(self.useCategory):FindChild("ContentRegion")
	local divider = Apollo.LoadForm(self.xmlDoc, "dividerPage", page, self)
	if divider then
		page:ArrangeChildrenVert()
	end

	return self
end

--nav divider
function Lib:navdivider(params)
	local navList = self.wndMain:FindChild("NavScroller")
	local navItem = Apollo.LoadForm(self.xmlDoc, "dividerNav", navList, self)
	if navItem then
		navItem:SetName(self.conventions.navPrefix .. "divider")
		navList:ArrangeChildrenVert()
	end

	return self
end

-- INTERNAL BUILDER METHODS -------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
function Lib:ShrinkColorPicker()
	self.wndMain:FindChild("PopupColorPicker"):SetAnchorOffsets(-418, 99, -100, 470)
end

function Lib:GrowColorPicker()
	self.wndMain:FindChild("PopupColorPicker"):SetAnchorOffsets(-418, 90, -100, 498)
end

function Lib:ShrinkPanel()
	--shrink the options panel to a smaller frame
	self.wndMain:FindChild("NavScroller"):Show(false, true)
	self.wndMain:FindChild("Divider"):Show(false, true)

	nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	self.wndMain:SetAnchorOffsets(nLeft, nTop, -810, nBottom)

	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("ContentRegion"):GetAnchorOffsets()
	self.wndMain:FindChild("ContentRegion"):SetAnchorOffsets(30, nTop, nRight, nBottom)

	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("TitleBG"):GetAnchorOffsets()
	self.wndMain:FindChild("TitleBG"):SetAnchorOffsets(50, nTop, -50, nBottom)

	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("Blocker"):GetAnchorOffsets()
	self.wndMain:FindChild("Blocker"):SetAnchorOffsets(28, nTop, nRight, nBottom)

	nLeft, nTop, nRight, nBottom = self.wndMain:FindChild("BGArt"):GetAnchorOffsets()
	self.wndMain:FindChild("BGArt"):SetAnchorOffsets(19, nTop, nRight, nBottom)
end

function Lib:NewCategory(name)
	local navList = self.wndMain:FindChild("NavScroller")
	local navItem = Apollo.LoadForm(self.xmlDoc, "NavPrimary", navList, self)
	local button  = navItem:FindChild("NavBtn")
	if navItem then
		--set the name and text
		button:SetName(self.conventions.navPrefix .. name)
		button:SetText(name)

		--rearrange the list
		navList:ArrangeChildrenVert()

		--create the content panel
		self:CreatePageForCategory(name)
	end
end

function Lib:CreatePageForCategory(name)
	--where are we placing this new panel?
	local contentRegion   = self.wndMain:FindChild("ContentRegion")
	local contentScroller = Apollo.LoadForm(self.xmlDoc, "NavPage", contentRegion, self)
	if contentScroller then
		--lets name the panel and default it to hidden
		contentScroller:SetName(self.conventions.pagePrefix .. name)
		contentScroller:Show(false, true)
	end

	if not self.hasCategory then
		--this is our first category, so lets activate the button
		--and show the page manually, because it wont happen otherwise
		local button = self.wndMain:FindChild(self.conventions.navPrefix .. name)
		button:SetCheck(true)
		contentScroller:Invoke()
		self.hasCategory = true
	end
end

-- HELPERS ------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
function Lib:SetColorPicker(rgbColor)
	local picker  = self.wndMain:FindChild("PopupColorPicker:ColorPicker")
	local preview = self.wndMain:FindChild("PopupColorPicker:ColorPreview:Inner")
	local nColor  = ApolloColor.new(rgbColor.r, rgbColor.g, rgbColor.b)
	picker:SetColor(nColor)
end

function Lib:RGBtoHEX(rgbColor)
	local r, g, b

	local r = self:_RGBtoHEX(rgbColor.r)
	local g = self:_RGBtoHEX(rgbColor.g)
	local b = self:_RGBtoHEX(rgbColor.b)
	return r .. g .. b
end

function Lib:_RGBtoHEX(rgbStub)
	local hexadecimal = ''
	local hex = ''
	while(rgbStub > 0)do
		local index = math.fmod(rgbStub, 16) + 1
		rgbStub = math.floor(rgbStub / 16)
		hex = string.sub('0123456789ABCDEF', index, index) .. hex			
	end
	if(string.len(hex) == 0)then
		hex = '00'
	elseif(string.len(hex) == 1)then
		hex = '0' .. hex
	end
	hexadecimal = hexadecimal .. hex
	return hexadecimal
end

function Lib:HEXtoRGB(hexColor)
	local newColor = {}
	newColor.r = tonumber("0x"..hexColor:sub(1,2))
	newColor.g = tonumber("0x"..hexColor:sub(3,4))
	newColor.b = tonumber("0x"..hexColor:sub(5,6))
	newColor.a = 1
    return newColor
end

function Lib:str_split(text, sep)
	local sep, fields = sep or ",", {}
	local pattern = string.format("([^%s]+)", sep)
	text:gsub(pattern, function(c) fields[#fields+1] = c end)
	return fields
end

function Lib:CategoryCheck()
	if not self.useCategory then
		local name = "Settings"
		local category = self:GetPageByCategory(name) or self:NewCategory(name)
		self.useCategory = name
		self:ShrinkPanel()
	end
end

function Lib:GetMapped(map)
	local v = self.meta.container
	for w in string.gfind(map, "[%w_]+") do
		v = v[w]
	end
	return v
end

function Lib:GetDefault(map)
	local v = self.meta.defaults
	for w in string.gfind(map, "[%w_]+") do
		v = v[w]
	end
	return v
end

function Lib:RestoreDefaultFromMap(map)
	--get default first
	local default = self:GetDefault(map)
	--now update our mapping
	if default ~= nil then
		self:SetMapped(map, default)
	end
end

function Lib:SetMapped(map, value)
	local t = self.meta.container
	for w, d in string.gfind(map, "([%w_]+)(.?)") do
		if d == "." then
			if t[w] == nil then
				-- this should always exist, but we could
				-- set t = {} to force the table to exist
				-- if we decide to get crazy with the
				-- function usage
				break
			else
				t = t[w]
			end
		else
			t[w] = value
		end
	end
end

function Lib:RegisterMap(map, data)
	self.mappings = self.mappings or {}
	self.mappings[map] = data
end

function Lib:LookupMap(map)
	return self.mappings[map]
end

function Lib:DetectColorFormat(mValue)
	if type(mValue) == 'string' then
		return "hex"
	elseif type(mValue) == 'table' and mValue.r ~= nil then
		return "rgba"
	else
		return "table"
	end

	return nil
end

function Lib:GetComboValueByLabel(choicesName, label)
	for k, v in pairs(self.choices[choicesName]) do
		if (v[1] == label) then
			return v[2]
		end
	end

	return nil
end

function Lib:ClearOtherNavigation(name)
	for k, v in pairs(self.categories) do
		if name ~= k then
			local button = self.wndMain:FindChild(self.conventions.navPrefix .. k)
			local page   = self:GetPageByCategory(k)
			button:SetCheck(false)
			page:Close()
		end
	end
end

function Lib:GetPageByCategory(name)
	local pageName = self.conventions.pagePrefix .. name
	local panel    = self.wndMain:FindChild(pageName) or false
	local inner    = false
	if panel then
		--found the panel
		inner = panel:FindChild("ContentRegion") or false
	end
	return panel
end

function Lib:PrepareWindow()
	--this will populate the new config window with meta data
	self.wndMain:FindChild('Title'):SetText(self.meta.name)
	self.wndMain:FindChild('Author'):SetText("Author: " .. self.meta.author or "")
	self.wndMain:FindChild('Version'):SetText("Version: " ..self.meta.version or "")

	if self.meta.defaults then
		self.wndMain:FindChild('DefaultsButton'):Show(true, true)
	end
end

function Lib:CloseAllPopups()
	self.wndMain:FindChild("PopupColorPicker"):Close()
	self.wndMain:FindChild("PopupMultiChoice"):Close()
	self.wndMain:FindChild("PopupRestoreDefaults"):Close()
end

function Lib:log(msg)
	ChatSystemLib.PostOnChannel(2, "[uiMapper]: " .. msg)
end

-- Register Package ---------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------
Apollo.RegisterPackage(Lib, MAJOR, MINOR, {})