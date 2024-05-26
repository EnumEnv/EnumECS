--[[
Developed by EnumEnv (2024)

Copyright 2024 Enum Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
associated documentation files (the “Software”), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, subject to the 
following conditions:

The above copyright notice and this permission notice shall be 
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND 
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

-- Services --
local CollectionService = game:GetService("CollectionService")

--- The class for EnumECS
--- @class EnumECS
local EnumECS = {}
EnumECS.__index = EnumECS

-- Types --
export type Component = {
	Init: () -> (),
	Deinit: () -> ()
}

export type ObjectComponentsType = { [string]: { [Instance]: Component } } -- tag: object , component
export type LoadedComponentsType = { [string]: Component }   			   -- tag , component

-- Tables --
local LoadedComponents: LoadedComponentsType = {}
local ObjectComponents: ObjectComponentsType = {}

-- Local Functions --
--- The function that initiates a loaded component onto a object which is/gets tagged.
--- @param tag --> string -- The tag to look for/is assigned.
--- @param object --> Instance -- The object to initiate the component onto.
--- @return void
local function OnTagged(tag: string, object: Instance)
	assert(LoadedComponents[tag], "Could not find a loaded component for the tag",tag)
	
	-- Getting Existing Data --
	local loadedComponent = LoadedComponents[tag]
	
	-- Creating New Data --
	local componentForObject = table.clone(loadedComponent)
	componentForObject.__index = componentForObject
	
	-- Initiating and Storing --
	componentForObject:Init(object)
	ObjectComponents[tag][object] = componentForObject
end

--- The function that deinitiates a loaded component which is already on a object which got untagged.
--- @param tag --> string -- The tag to look for/is (un)assigned
--- @param object --> Instance -- The object to deinitiate the component from.
--- @return void
local function OnUnTagged(tag: string, object: Instance)
	assert(ObjectComponents[tag], "Could not find a loaded object tag for the tag",tag)
	assert(ObjectComponents[tag][object], "Object isn't registered onto the tag (",tag,")")
	
	-- Getting Existing Data --
	local loadedObjectComponent = ObjectComponents[tag][object]
	
	-- Wiping Data --
	loadedObjectComponent:Deinit(object)
	ObjectComponents[tag][object] = nil
end

-- Module --
--- Creates a new component managed by a module and a tag.
--- @param module --> ModuleScript -- The module for the entity component.
--- @param tag --> string -- The tag to be assigned for the component.
--- @return void
function EnumECS.NewComponent(module: ModuleScript, tag: string)
	assert(not LoadedComponents[tag], "Tag for",tag,"already exists.")
	
	-- Creating Info Data For Tag/Component --
	ObjectComponents[tag] = {}
	LoadedComponents[tag] = require(module)
	
	-- Check For Pre-Existing Tags --
	for _,object in CollectionService:GetTagged(tag) do
		OnTagged(tag, object)
	end
	
	-- Check Once Added/Removed --
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(object)
		OnTagged(tag, object)
	end)
	
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(object)
		OnUnTagged(tag, object)
	end)
end

--- Removes the loaded component, as well as the objects loaded with it.
--- @param tag --> string -- The tag assigned to the loaded component to be removed.
--- @return void
function EnumECS.RemoveLoadedComponent(tag: string)
	-- Remove The Loaded Component --
	LoadedComponents[tag] = nil
	
	-- Unload From Objects --
	for object,component in ObjectComponents[tag] do
		if component.Deinit then
			component:Deinit(object)
		end
		
		-- Remove Object --
		ObjectComponents[tag][object] = nil
	end
	
	-- Remove Object Tag --
	ObjectComponents[tag] = nil
end

--- Removes/deinits a component loaded onto a object.
--- @param tag --> string -- The component tag to remove from the object.
--- @param object --> Instance -- The object to remove the component from.
--- @param removeTag --> boolean -- Whether or not to remove the tag from the object.
--- @return void
function EnumECS.RemoveObjectComponent(tag: string, object: Instance, removeTag: boolean)
	assert(ObjectComponents[tag], "Could not find a data for tag",tag)
	assert(ObjectComponents[tag][object], "Could not find object component data for object",object)
	assert(ObjectComponents[tag][object].Deinit, "Could not find the :Deinit function on",tag,object)
	
	-- Deinit --
	local objectComponent = ObjectComponents[tag][object]
	objectComponent:Deinit(object)
	
	-- Remove Tag --
	if removeTag and object:HasTag(tag) then
		object:RemoveTag(tag)
	end
end

--- Waits for a specific object to recieve a component of a specific tag.
--- @param tag --> string -- The tag/component to wait for.
--- @param object --> Instance -- The object to wait for the tag to be assigned to.
--- @return Component (:Init(), :Deinit(), ...)
function EnumECS.WaitForObjectComponent(tag: string, object: Instance): Component
	assert(LoadedComponents[tag], "The component for the entirety of the tag has not been loaded yet.")
	assert(ObjectComponents[tag], "Could not find a data for tag",tag)
	
	-- Wait For Object Component --
	repeat
		task.wait()
	until ObjectComponents[tag][object]
	
	-- Return The Component --
	return ObjectComponents[tag][object]
end

--- Waits for a specific component tag to be loaded.
--- @param tag --> string -- The tag/component to wait to be loaded.
--- @return void
function EnumECS.WaitForLoadedComponent(tag: string)
	repeat
		task.wait()
	until LoadedComponents[tag]
end

--- Returns the component of a object on a specific tag.
--- @param tag --> string -- The tag to look for.
--- @param object --> Instance -- The object the tag should be looked for on.
--- @return Component (:Init(), :Deinit(), ...)
function EnumECS.GetObjectComponent(tag: string, object: Instance)
	if not ObjectComponents[tag][object] then
		return
	end
	
	return ObjectComponents[tag][object]
end

-- End --
return EnumECS
