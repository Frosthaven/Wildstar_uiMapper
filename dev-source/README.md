#DEV-SOURCE README. COVERS AND TRACKS UNRELEASED CONTENT/FEATURES

# Wildstar uiMapper
uiMapper is a template-based UI generator for creating options and binding them to data for use with Wildstar LUA addon development. This was originally an inside project for the addon developer Frosthaven, but has been made public for anyone who could find it useful.

### Changelog
0.9
   - Added :slider() method
   - Added :pagedivider() method

0.8.2
   - Comboboxes will now reset the scroll position when being constructed

0.8.1
   - Comboboxes will now automatically set to the first option if the addon provides an invalid choice
   
0.8
   - Several layout adjustments to the base template
   - Fixed a potential issue where resetting defaults without any active options could cause a silent error

0.7
   - Added option to reset defaults by passing defaults param when calling :new()

0.6
   - Fixed an issue where choicetables with boolean values weren't being detected
   - Added alpha slider option to the :color() method

### Developer Notes
Currently, uiMapper is in developer pre-release. Although it has been tested in various environments and conditions and is out in the wild with the author's own addons, no guarantees can be made. At this time, please refrain from putting special characters in your variable names or categories, and avoid placing 'uiMapper_' in them as well, as the engine is currently hard coded to use that as a reference pointer to the ui elements.

### Todo
Some features I'd like to add when I get the time:
   - Better Backdrop for transparent color swatches
   - Providing default values for easy reset of addon options
   - Slider control widgets
   - Changing dropdown boxes into grid windows
   - Overall code improvements and cleanup

## Screenshots
![Full Panel](http://puu.sh/lvKma/824f4029d9.png)
![Smaller Panel](http://puu.sh/lvE29/e8aa996f28.png)

## Installation
1. Copy the _uiMapper folder from _uiMapperDEMO into your addon's folder. The release consists of two files, **core.lua** and **panel.xml**
   - The folder layout should be
   ```
   ../Wildstar/Addons/Myaddon/
      myaddon.lua
      myaddon.xml
      toc.xml
      _uiMapper/
           core.lua
           panel.xml
   ```
2. Include the uiMapper core in the top your **toc.xml** file
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <Addon Author="AuthorName" APIVersion="11" Name="MyAddon" Description="SomeDescription">
       <!-- uiMapper -->
       <Script Name="_uiMapper\core.lua"/>
       <!-- /uiMapper -->

       <Script Name="myaddon.lua"/>
       <Form Name="myaddon.xml"/>
   </Addon>
   ```
3. List uiMapper as a dependancy in your **Init** event
    ```lua
    function Addon:Init()
        --etc
        
        local tDependencies = {
           "uiMapper:0.8.2", --this name needs to match the name listed at the top of core.lua
        }
        
        --etc
    end
    ```
4. You are now ready to use uiMapper!

## Getting Started
uiMapper works by registering your addon first, and then passing the workspace back to you when the ui is ready to be built. It does this so that saved variables are in place before the options panel is constructed. Let's look at the bread and butter call, which should be placed at the bottom of your addon's **OnLoad** event.

```lua
function myaddon:OnLoad()
    --etc
    
  local uiMapper = Apollo.GetPackage("uiMapper:0.8.2").tPackage
  --change "uiMapper:0.8.2" to whatever you used in your dependancy check
  --which is what is found at the top of core.lua
  
  self.ui  = uiMapper:new({
    container = self,                     --this is where your addon settings are stored
    defaults  = self.defaults             --the variable layout needs to match your container layout perfectly
    name      = "uiMapper Example",       --the name of the addon
    author    = "Frosthaven",             --the author of the addon
    version   = "1.1-dev",                --any version information about your addon
    slash     = "uiconfig"                --optional slash command to open the ui panel
    onshow    = function(ui)
      --config panel opened               --optional events: onshow, onhide, ondefault
    end,
    onhide    = function(ui)
      --config panel closed
    end,
    ondefault = function(ui)
      --default settings have been applied
    end,
  }):build(function(ui)
      --this is your ui workspace
      --refer to methods below for
      --how to build an interface
  end)
end
```

But remember, chaining methods is merely optional (more on this below)! The following will accomplish the same thing:
```lua
 --inside of OnLoad
 self.ui = uiMapper:new({
    --etc
 })

 --and then somewhere else in your code
 self.ui:build(function(ui) {
    --this is your ui workspace
 })
```

And now with the magic function call done and our UI ready to be built, on to...

## METHODS: An Introduction
All builder methods in the API listed below should be placed inside of your ui workspace as demonstrated above.
Methods in uiMapper support chaining. All of these are the same:
```lua
ui:category("Another Page")
ui:header("Display Options")
```
```lua
ui:category("Another Page"):header("Display Options")
```
```lua
ui:category("Another Page")
:header("Display Options")
```
Some methods only require a string input, but most require a parameter table. The most common parameter for uiMapper is map. when a UI control is altered, uiMapper will look in the container you provided initially to find the variable to change. For instance if you have the setting **self.isEnabled**, and you provided **self** as the container, the map value required to find the setting would be **'isEnabled'**. uiMapper also supports nested variables, so the map **'config.style.fontcolor'** would look in self.config.style.fontcolor.
## METHODS: API
This is a list of all methods currently in uiMapper that are provided to your ui workspace


### :category(```"string"```)
```lua
ui:category("General Settings")
```
This method sets the current category and creates the category page. All methods following this call will go into the specified category. If you do not specify a category before any other methods, uiMapper assumes you aren't using any categories and will remove page navigation from the option panel.

---
### :navdivider()
```lua
ui:navdivider()
```
This method adds a horizontal divider under your current category button in the navigation panel

---
### :header(```"string"```)
```lua
ui:header("Display Options")
```
This method creates a centered title header on the current category page.

---
### :note(```"string"```)
```lua
ui:note("The options below change the font size")
```
This method creates a note on the page. Notes can be any string length and will word-wrap

---
### :check(```{table}```)
```lua
--sets variable to boolean result
--provides the checkbox wndControl
ui:check({
   label = "Enable Crit Notifications",
   map   = "enableCritNotifications",
   onchange = function(wndControlCheckbox)
      --the checkbox option has changed
   end,
})
```
This method creates a checkbox in the config panel, and supports the onchange parameter callback.

---
### :input(```{table}```)
```lua
--sets variable to string result
--provides the input box wndControl
ui:input({
   label = "Custom Harvesting Text",
   map   = "customHarvestText",
   onchange = function(wndControlInputBox)
      --the text in the input box has changed
   end,
})
```
This method creates a text input box in the config panel, and supports the onchange parameter callback.

---
### :button(```{table}```)
```lua
--sets nothing
--provides the button wndControl
ui:button({
   label = "Enable Crit Notifications",
   onclick = function(wndControlButton)
      --the button was clicked
   end,
})
```
This method creates a button with no mapping. Useful for creating interactivity.

---
### :choicetable(```"string"```,```{table}```)
```lua
--with :combo(), will set variable to the assigned value
ui:choicetable("fruits", {
 {'banana', 'yellow'},
 {'apple',  'red'   },
 {'grape',  'purple'},
})
```
This method registers a named table of choices and associated values for use with comboboxes. Labels on the left (apple) and their associated values are on the right (red). If no value is provided, the label is assumed to be the value.

---
### :combo(```{table}```)
```lua
--with :choicetable(), will set variable to the assigned value
ui:combo({
   label   = "What's your favorite fruit color?",
   choices = "fruit"
   map     = "selectedColor",
   onitemadded = function(wndControlItem)
      --an entry from your choice table was added
   end,
   onpopulated = function(wndControlList)
      --all entries from your choice table have been added
   end,
   onchange = function(wndControlButton)
      --a dropdown item was chosen
   end,
})
```
This method creates a dropdown menu using a named set of choices defined with :choicetable() and provides several event callbacks

---
### :color(```{table}```)
```lua
--sets variable to a formatted color response
ui:color({
   label  = "Pick a color",
   map    = "theColorPicked",
   format = "hex",            --hex "FFFFFF"   rgba {r=255,g=255,b=255,a=1}   table {255, 255, 255,1)
   dec    = true,             --numbers will go from 0-1 instead of 0-255
   alpha  = true,             --enable the alpha channel for this color
   onchange = function(wndControlButton)
      --the user has selected a color from the color picker
   end,
})
```
This method creates a color picker button the user can use to select a color from. The format will be auto-detected from your mapped variable.

The optional dec parameter defaults to false unless set to true, and formats the color levels between 0-1 instead of 0-255.

Best practices suggest picking a format you want to work with and not mixing and matching them as you update your addon, but the optional format parameter can ensure you get a specific format back in most cases.

The optional alpha parameter defaults to false unless set to true, and enables an alpha channel slider for the color. This parameter will be ignored if you are using hex color format.

---
### :slider(```{table}```)
```lua
--sets variable to number value
ui:slider({
   label  = "Pick A Number",
   map    = "numberPicked",
   range  = "0,100"           --define the lowest and highest number
   onchange = function(wndControl)
      --the value of the slider has changed
   end,
})
```
Not yet implimented

---

## Examples
Currently, uiMapper is used in the following addons:

[FrostMod Threat Ball](http://www.curse.com/ws-addons/wildstar/238126-frostmod-threatball)

[FrostMod CombatText](http://www.curse.com/ws-addons/wildstar/238429-frostmod-combattext)

## Developers
Frosthaven ([Frosthaven on Twitter](http://twitter.com/thefrosthaven))
send me a tweet if you use uiMapper for your next project and I'll link it under the examples section!
