-----------------------------------------------------------------------------------------------
-- Client Lua Script for Tracked
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
-- http://lua-users.org/wiki/StringLibraryTutorial

require "Window"
require "Apollo"
--

require "Item"
require "Unit"
require "GameLib"
require "CColor"

--require "TrackedUISetup" 

-----------------------------------------------------------------------------------------------
-- Tracked Module Definition
-----------------------------------------------------------------------------------------------
local Tracked = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Tracked:new(o)
    o = o or {}

    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

	self.whiteList = {
		[0] = "Heartichoke", 
		[1] = "Octopod" 
	}
	
	--- Copys
	
	self.bgColor = CColor.new(0,1,0,1)
	self.intermediateColor = CColor.new(0, 0, 1, 1)
	self.complementaryColor = CColor.new(1, 0, 1, 1)
	self.clearDistance = 0 --20
	self.target = nil
	

	self.rotation = 0
	self.updateRotation = true
	self.isVisible = false
	self.distance = 10

	-- Core
	self.units = {}; -- trackable units
	self.marker = {}; -- collection of markers on screen
	self.currentUnit = nil;
	self.zoneId = nil;
	self.isEnabled = false;

	-- Nameplate
	self.nameplate = nil;
	
	-- Grid
	self.selectedGridItemIndex = 0;		
	
    return o;
end

function Tracked:Init()
	local bHasConfigureFunction = false;
	local strConfigureButtonText = "";
	local tDependencies = {};
  
	Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

function Tracked:Initialize()
	for i = 0, 20 do		
		self.marker[i] = Apollo.LoadForm(self.xmlDoc, "Marker", "InWorldHudStratum", self);		
		self.marker[i]:Show(false, true);
	end
	
	self.nameplate = Apollo.LoadForm(self.xmlDoc, "Nameplate", "InWorldHudStratum", self);
	self:ToggleNameplate();
		
	self:CacheMarkerOffsets();
end
 
function Tracked:ReInit()
	-- Reset vars
	self.units = {};
	self.zoneId = nil;
	self.nameplate = nil;
	self.currentUnit = nil;	
	
	-- Call methods	
	self:SetNameplateTarget("", nil);
	self:ToggleNameplate();
	self:HideMarkers();
end

-----------------------------------------------------------------------------------------------
-- Tracked OnLoad
-----------------------------------------------------------------------------------------------
function Tracked:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("Tracked.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)	
	
	Apollo.RegisterEventHandler("ZoneCompletionUpdated", "OnZoneCompletionUpdated", self)
	
	Apollo.RegisterEventHandler("OnSave", "OnSave", self)
	Apollo.RegisterEventHandler("OnRestore", "OnRestore", self)
		
	Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
	Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)
	
	Apollo.RegisterEventHandler("GridSelChange", "OnGridSelChange", self)
end

-----------------------------------------------------------------------------------------------
-- Tracked Core Functions & Callbacks
-----------------------------------------------------------------------------------------------
function Tracked:OnSlashCommand()
	self.wndMain:Invoke()
end

function Tracked:OnDocLoaded()
	
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "TrackedForm", nil, self)
	
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end	

		self:SetupUI()
		
		self:Initialize()
		
		self.wndMain:Show(false,true)
					
		
		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
	
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("tracked", "OnSlashCommand", self)
		Apollo.RegisterSlashCommand("t", "OnSlashCommand", self)
	
		self.timer = ApolloTimer.Create(0.03, true, "OnTimer", self)
	end
end

-----------------------------------------------------------------------------------------------
-- Store & Load data
-----------------------------------------------------------------------------------------------
function Tracked:OnSave(eType)

	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return nil
	end

	local storageObject = {
		activeListTest1 = self.whiteList
	}
	
	return storageObject
end

function Tracked:OnRestore(eType, savedData)
	
    if savedData.activeListTest1 ~= nil then
		self.whiteList = savedData.activeListTest1
		-- --self:LoadPositions()
	end

end

-----------------------------------------------------------------------------------------------
-- UI STUFF
-----------------------------------------------------------------------------------------------
function Tracked:SetupUI() 

	-- User input stuff
	self.grid = self.wndMain:FindChild("GridFrame"):FindChild("Grid");
	
	self:RenderGridItems();
	
end

function Tracked:OnAddItem()

	local typedInName = self.wndMain:FindChild("InputBG"):FindChild("EditBoxTrackResource"):GetText()

	if typedInName ~= nil and typedInName ~= "Type in unit to track" then
		self.grid:AddRow(typedInName , "", nil)
		
		
		--table.insert(Tracked.Items, typedInName)
		--self.itemList[0] = typedInName 
		
		self.whiteList[(table.getn(self.whiteList) + 1)] = typedInName;
		
		
		self.wndMain:FindChild("InputBG"):FindChild("EditBoxTrackResource"):SetText("")
		
		
		self:OnSave(GameLib.CodeEnumAddonSaveLevel.Character)
	end

end

function Tracked:RenderGridItems()

	if self.grid == nil then
		return nil
	end

	self.grid:DeleteAll()
	
	for i = 0, table.getn(self.whiteList) do
		self.grid:AddRow(self.whiteList[i], "", nil)
	end

end

-----------------------------------------------------------------------------------------------
-- Program loop logic
-----------------------------------------------------------------------------------------------
function Tracked:OnTimer()

	if self.isEnabled then
		self:CheckState();
	end
	
end

function Tracked:CheckState()	

	if GameLib.GetPlayerUnit() == nil then
		return false;
	end
	
	local closestTarget = nil;
	local closestDistance = nil;
	local playerUnit = GameLib.GetPlayerUnit();
	local playerPos = playerUnit:GetPosition();
	local playerVec = Vector3.New(playerPos.x, playerPos.y, playerPos.z);

	if playerUnit ~= nil then	
		if self.units ~= nil then 		
			local closest = self:GetTarget();
					
			if closest ~= nil and closest:GetPosition() ~= nil then
				local closestVec = Vector3.New(closest:GetPosition().x, closest:GetPosition().y, closest:GetPosition().z);
					
				if playerVec ~= nil and closestVec ~= nil then
					-- Line
					self:DrawLineBetween(playerVec, closestVec);
				end				
			end
		end
	end
	
end

-----------------------------------------------------------------------------------------------
-- TrackedForm Buttons
-----------------------------------------------------------------------------------------------
function Tracked:OnOK()
	self.wndMain:Close(); -- hide the window
end

function Tracked:OnRemoveItem( wndHandler, wndControl, eMouseButton)

	if self.selectedGridItemIndex == 0 then
		return false;
	end

	table.remove(self.whiteList, self.selectedGridItemIndex - 1);
			
	self:RenderGridItems();
	self:OnSave(GameLib.CodeEnumAddonSaveLevel.Character);
	
	self.selectedGridItemIndex = 0;
end

function Tracked:OnPressEnableButton()
	
end

function Tracked:OnEnableButtonCheck( wndHandler, wndControl, eMouseButton )
	self.isEnabled = true;
	self:ToggleNameplate();
end


function Tracked:OnEnableButtonUnCheck( wndHandler, wndControl, eMouseButton )
	self.isEnabled = false;
	self:ToggleNameplate();
end

-----------------------------------------------------------------------------------------------
-- Event Listeners
-----------------------------------------------------------------------------------------------
function Tracked:OnUnitCreated(unit)

	if not self:indexOf(unit:GetName(), self.whiteList) then
		return false;
	end	
	
	if GameLib.GetPlayerUnit() == nil then
		return false;
	end
	
	if unit:GetType() == 'Harvest' and unit:CanBeHarvestedBy(GameLib.GetPlayerUnit()) then	
		self.units[unit:GetId()] = unit;
	end
end

function Tracked:OnUnitDestroyed(unit)

	if GameLib.GetPlayerUnit() == nil then
		return false;
	end

	if unit:GetType() == 'Harvest' and unit:CanBeHarvestedBy(GameLib.GetPlayerUnit()) then
		self:RemoveLine(unit:GetId());
		
		self.units[unit:GetId()] = nil;
	end
end

function Tracked:OnGridSelChange(wndHandle, wndControl, row, col)
	self.selectedGridItemIndex = row;
end

function Tracked:OnZoneCompletionUpdated(zoneId)

	if self.zoneId == nil or self.zoneId ~= zoneId then		
		self:ReInit();	
		
		self.zoneId = zoneId;	
	end

end

-----------------------------------------------------------------------------------------------
-- Nameplate
-----------------------------------------------------------------------------------------------
function Tracked:SetNameplateTarget(targetName, distance)
 			
	local dist = 0	

	if distance ~= nil then
		dist = math.floor(math.floor(distance) / 2)
		self.nameplate:SetText("Found: " .. targetName .. "(" .. dist .. "m)")
	else 
		self.nameplate:SetText("Searching...")
	end
	

end

function Tracked:ToggleNameplate()
	self.nameplate:Show(self.isEnabled, self.isEnabled);	
end
-----------------------------------------------------------------------------------------------
-- Copy/pasted stuff
-----------------------------------------------------------------------------------------------
function Tracked:GetTarget()
	local closestTarget = nil
	local closestDistance = nil
	local playerUnit = GameLib.GetPlayerUnit()
	
	if playerUnit ~= nil then
		local playerPos = playerUnit:GetPosition()
		local playerVec = Vector3.New(playerPos.x, playerPos.y, playerPos.z)

		for _, target in pairs(self.units) do
			local distance = self:GetDistanceToTarget(playerVec, target)
			if not closestTarget or distance < closestDistance then
				closestTarget = target
				closestDistance = distance
				
				-- Set nameplate data
				self.currentUnit = closestTarget
				self:SetNameplateTarget(closestTarget:GetName(), distance)
			end
		end
	end
	
	return closestTarget
end

function Tracked:GetDistanceToTarget(playerVec, target)
	if Vector3.Is(target) then
		return (playerVec - target):Length()
	elseif Unit.is(target) then
		local targetPos = target:GetPosition()
		if targetPos == nil then
			return 0
		end
		local targetVec = Vector3.New(targetPos.x, targetPos.y, targetPos.z)
		return (playerVec - targetVec):Length()
	else
		local targetVec = Vector3.New(target.x, target.y, target.z)
		return (playerVec - targetVec):Length()
	end
end

function Tracked:CacheMarkerOffsets()
	for i = 0, 20 do
		self.marker[i]:SetData(Vector3.New(
			self.distance * math.cos(((2 * math.pi) / 20) * i),
			0,
			self.distance * math.sin(((2 * math.pi) / 20) * i)))
	end
end

function Tracked:DrawLineBetween(playerVec, targetVec)

	--if self.updateRotation then
	--	self.rotation = self:CalculateRotation(targetVec, playerVec)
	--	self.updateRotation = false
	--end

	local totalDistance = (playerVec - targetVec):Length()
	local color
	for i = 0, 20 do
		local fraction = (i+1)/21

		if self.marker[i] ~= nil then
			self.marker[i]:SetWorldLocation(Vector3.InterpolateLinear(playerVec, targetVec, fraction))
			self.marker[i]:Show(true, true)
		end
		
	end
end

function Tracked:HideMarkers() 
	for i = 0, 20 do
		self.marker[i]:Show(false, false)
	end
end

function Tracked:RemoveLine(unitId) 

	self:SetNameplateTarget("", nil);

	if self.currentUnit == nil then 
		self:HideMarkers();
		return;
	end

	if unitId == self.currentUnit:GetId() then
		--self.currentUnit = nil		
		self:HideMarkers();		
	end

end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------
function Tracked:logToWindow(message) 
	if self.wndMain ~= nil then
		local text = self.wndMain:FindChild("Text"):GetText()
		self.wndMain:FindChild("Text"):SetText(text .. " \n" .. message)
	end	
end

function Tracked:indexOf(unitName, list)
	for key, value in pairs(list) do
		if string.find(unitName, value) ~= nil then
			return key
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Tracked Instance
-----------------------------------------------------------------------------------------------
local TrackedInst = Tracked:new()
TrackedInst:Init()
