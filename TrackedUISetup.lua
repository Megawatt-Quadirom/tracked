 
require "Window"
require "Apollo"

require "Item"
require "Unit"
require "GameLib"
require "CColor"

 
-----------------------------------------------------------------------------------------------
-- Tracked Module Definition
-----------------------------------------------------------------------------------------------
local TrackedUISetup = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function TrackedUISetup.new(tracked)
   	local self = setmetatable({}, { __index = TrackedUISetup })
	self.tracked = tracked
	
    return self
end

function TrackedUISetup:Init()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("Tracked.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function Tracked:OnDocLoaded()
	
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "TrackedForm", nil, self)
	
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end	
	
		
		self.grid = self.wndMain:FindChild("Grid")
		self.grid:AddRow("Test", "", nil)
	
	end
end

function TrackedUISetup:Setup()
  
end

