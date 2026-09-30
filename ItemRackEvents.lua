--[[ Default event definitions

	Events can be one of four types:
		Buff : Triggered by PLAYER_AURAS_CHANGED and delayed .3 sec
		Zone : Triggered by ZONE_CHANGED_NEW_AREA or ZONE_CHANGED_INDOORS and delayed .5 sec
		Stance : Triggered by UPDATE_SHAPESHIFT_FORM and not delayed
		Script : User-defined trigger

		Buff and Stance share an attribute :
		  NotInPVP : nil or 1, whether to ignore this event if pvp flag is set

		Buff, Zone and Stance share an attribute :
		  Unequip : nil or 1, whether to unequip the set when condition ends

		Buff has a special case attribute:
		  Anymount: nil or 1, whether the buff is any mount (IsPlayerMounted())

		Zone has a table:
		  Zones : Indexed by name of zone, lookup table for zones to define this event

		Script has its own attributes:
		  Trigger : Event (ie "UNIT_AURA") that triggers the script
		  Script : Actual script run through RunScript

	The set to equip is defined in ItemRackUser.Events.Set, indexed by event name
	The set to equip is nil if it's a Script event.  Sets equip/unequip explicitly
	Whether an event is enabled is in ItemRackuser.Events.Enabled, indexed by event name
]]

-- API Compatibility shims for TBC Anniversary Edition (January 2025+)
local LoadAddOn = LoadAddOn or (C_AddOns and C_AddOns.LoadAddOn)

-- increment this value when default events are changed to deploy them to existing events
ItemRack.EventsVersion = 18

-- default events, loaded when no events exist or ItemRack.EventsVersion is increased
ItemRack.DefaultEvents = {
	["PVP"] = {
		Type = "Zone",
		Unequip = 1,
		Zones = {
			["Alterac Valley"] = 1,
			["Arathi Basin"] = 1,
			["Warsong Gulch"] = 1,
			["Eye of the Storm"] = 1,
			["Ruins of Lordaeron"] = 1,
			["Blade's Edge Arena"] = 1,
			["Nagrand Arena"] = 1,
		}
	},
	["City"] = {
		Type = "Zone",
		Unequip = 1,
		Zones = {
			["Ironforge"] = 1,
			["Stormwind City"] = 1,
			["Darnassus"] = 1,
			["The Exodar"] = 1,
			["Orgrimmar"] = 1,
			["Thunder Bluff"] = 1,
			["Silvermoon City"] = 1,
			["Undercity"] = 1,
			["Shattrath City"] = 1,
			["Dalaran"] = 1,
		}
	},
	["Mounted"] = { Type = "Buff", Unequip = 1, Anymount = 1 },
	["Drinking"] = { Type = "Buff", Unequip = 1, Buff = "Drink" },

	["Evocation"] = { Class = "MAGE", Type = "Buff", Unequip = 1, Buff = "Evocation" },

	["Warrior Battle"] = { Class = "WARRIOR", Type = "Stance", Stance = 1 },
	["Warrior Defensive"] = { Class = "WARRIOR", Type = "Stance", Stance = 2 },
	["Warrior Berserker"] = { Class = "WARRIOR", Type = "Stance", Stance = 3 },

	["Priest Shadowform"] = { Class = "PRIEST", Type = "Stance", Unequip = 1, Stance = 1 },

	["Druid Humanoid"] = { Class = "DRUID", Type = "Stance", Stance = 0 },
	["Druid Bear"] = { Class = "DRUID", Type = "Stance", Stance = 1 },
	["Druid Aquatic"] = { Class = "DRUID", Type = "Stance", Stance = 2 },
	["Druid Cat"] = { Class = "DRUID", Type = "Stance", Stance = 3 },
	["Druid Travel"] = { Class = "DRUID", Type = "Stance", Stance = 4 },
	["Druid Moonkin"] = { Class = "DRUID", Type = "Stance", Stance = "Moonkin Form" },
	["Druid Tree of Life"] = { Class = "DRUID", Type = "Stance", Stance = "Tree of Life" },

	["Rogue Stealth"] = { Class = "ROGUE", Type = "Stance", Unequip = 1, Stance = 1 },

	["Shaman Ghostwolf"] = { Class = "SHAMAN", Type = "Stance", Unequip = 1, Stance = 1 },

	["Swimming"] = {
		["Trigger"] = "MIRROR_TIMER_START",
		["Type"] = "Script",
		["Script"] = "local set = \"Name of set\"\nif IsSwimming() and not IsSetEquipped(set) then\n  EquipSet(set)\n  if not SwimmingEvent then\n    function SwimmingEvent()\n      if not IsSwimming() then\n        ItemRack.StopTimer(\"SwimmingEvent\")\n        UnequipSet(set)\n      end\n    end\n    ItemRack.CreateTimer(\"SwimmingEvent\",SwimmingEvent,.5,1)\n  end\n  ItemRack.StartTimer(\"SwimmingEvent\")\nend\n--[[Equips a set when swimming and breath gauge appears and unequips soon after you stop swimming.]]",
	},

	["Buffs Gained"] = {
		Type = "Script",
		Trigger = "UNIT_AURA",
		Script = "if arg1==\"player\" then\n  IRScriptBuffs = IRScriptBuffs or {}\n  local buffs = IRScriptBuffs\n  for i in pairs(buffs) do\n    if not AuraUtil.FindAuraByName(i,\"player\") then\n      buffs[i] = nil\n    end\n  end\n  local i,b = 1,1\n  while b do\n    b = AuraUtil.FindAuraByName(i,\"player\")\n    if b and not buffs[b] then\n      ItemRack.Print(\"Gained buff: \"..b)\n      buffs[b] = 1\n    end\n    i = i+1\n  end\nend\n--[[For script demonstration purposes. Doesn't equip anything just informs when a buff is gained.]]",
	},

	["After Cast"] = {
		Type = "Script",
		Trigger = "UNIT_SPELLCAST_SUCCEEDED",
		Script = "local spell = \"Name of spell\"\nlocal set = \"Name of set\"\nif arg1==\"player\" and arg2==spell then\n  EquipSet(set)\nend\n\n--[[This event will equip \"Name of set\" when \"Name of spell\" has finished casting.  Change the names for your own use.]]",
	},

	["Nefarian's Lair"] = {
		Type = "Zone",
		Unequip = 1,
		Zones = {
			["Nefarian's Lair"] = 1,
		}
	},
}

-- resetDefault to reload/update default events, resetAll to wipe all events and recreate them
function ItemRack.LoadEvents(resetDefault,resetAll)

	local _, playerClass = UnitClass("player")
	local version = tonumber(ItemRackSettings.EventsVersion) or 0

	if ItemRack.EventsVersion > version then
		resetDefault = 1 -- force a load of default events (leaving custom ones intact)
		ItemRackSettings.EventsVersion = ItemRack.EventsVersion
	end

	if not ItemRackUser.Events or resetAll then
		ItemRackUser.Events = {
			Enabled = {}, -- indexed by name of event, whether an event is enabled
			Set = {} -- indexed by name of event, the set defined for the event, if any
		}
	end

	if not ItemRackEvents or resetAll then
		ItemRackEvents = {}
	end

	if resetDefault or resetAll then
		for i in pairs(ItemRack.DefaultEvents) do
			local eventClass = ItemRack.DefaultEvents[i].Class

			if not eventClass or eventClass == playerClass then
				ItemRack.CopyDefaultEvent(i)
			end
		end
	end

	ItemRack.CleanupEvents()
	if ItemRackOpt then
		ItemRackOpt.PopulateEventList() -- if options loaded, recreate event list there
	end
end

function ItemRack.CopyDefaultEvent(eventName)
	ItemRackEvents[eventName] = {}
	local event = ItemRackEvents[eventName]
	local default = ItemRack.DefaultEvents[eventName]

	for i in pairs(default) do
		if type(default[i])~="table" then
			event[i] = default[i]
		else
			-- recursive scares me :P /chicken
			-- this copies a sub-table. if events ever go one more table deep, do a recursive copy
			event[i] = {}
			for j in pairs(default[i]) do
				event[i][j] = default[i][j]
			end
		end
	end
end

-- clear sets of deleted events, clear events with deleted sets
function ItemRack.CleanupEvents()
	local event = ItemRackUser.Events

	-- go through ItemRackUser.Events.Set for deleted events or sets
	for i in pairs(event.Set) do
		if not ItemRackEvents[i] then
			-- this event no longer exists, remove it
			event.Set[i] = nil
			event.Enabled[i] = nil
		end
		if not ItemRackUser.Sets[event.Set[i]] then
			-- this set no longer exists, remove it
			event.Set[i] = nil
			event.Enabled[i] = nil
		end
	end

	-- go through ItemRackUser.Events.Enabled for deleted events
	for i in pairs(event.Enabled) do
		if not ItemRackEvents[i] then
			-- this event no longer exists, remove it
			event.Set[i] = nil
			event.Enabled[i] = nil
		end
		if event.Enabled[i] == false then
			-- this was disabled but not removed
			event.Enabled[i] = nil
		end
	end
end

function ItemRack.ResetEvents(resetDefault,resetAll)
	if not resetDefault and not resetAll then
		StaticPopupDialogs["ItemRackConfirmResetEvents"] = {
			text = "Do you want to restore just Default events, or wipe All events and restore to default?",
			button1 = "Default", button2 = "Cancel", button3 = "All", timeout = 0, hideOnEscape = 1, whileDead = 1,
			OnAccept = function() ItemRack.ResetEvents(1) end,
			OnAlt = function() ItemRack.ResetEvents(1,1) end,
		}
		StaticPopup_Show("ItemRackConfirmResetEvents")
	else
		ItemRack.LoadEvents(resetDefault,resetAll)
	end
end

function ItemRack.InitEvents()
	ItemRack.LoadEvents()

	ItemRack.CreateTimer("EventsBuffTimer",ItemRack.ProcessBuffEvent,.15)
	ItemRack.CreateTimer("EventsZoneTimer",ItemRack.ProcessZoneEvent,.16)
	ItemRack.CreateTimer("CheckForMountedEvents",ItemRack.CheckForMountedEvents,.5,1)

	if ItemRackButton20Queue then
		ItemRackButton20Queue:SetTexture("Interface\\AddOns\\ItemRack\\ItemRackGear")
	else
		print("ItemRackButton20Queue doesn't exist?")
	end

	ItemRack.RegisterEvents()
end

function ItemRack.RegisterEvents()
	local frame = ItemRackEventProcessingFrame
	frame:UnregisterAllEvents()
	-- Guard: Timer may not exist yet during initial load
	if ItemRack.TimerPool and ItemRack.TimerPool["CheckForMountedEvents"] then
		ItemRack.StopTimer("CheckForMountedEvents")
	end
	ItemRack.ReflectEventsRunning()
	if ItemRackUser.EnableEvents=="OFF" then
		return
	end
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents
	local eventType
	for eventName in pairs(enabled) do
		local ev = events[eventName]
		eventType = ev and ev.Type
		if eventType=="Buff" then
			if not frame:IsEventRegistered("UNIT_AURA") then
				frame:RegisterEvent("UNIT_AURA")
			end
		elseif eventType=="Stance" then
			if not frame:IsEventRegistered("UPDATE_SHAPESHIFT_FORM") then
				frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
			end
		elseif eventType=="Zone" then
			if not frame:IsEventRegistered("ZONE_CHANGED_NEW_AREA") then
				frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
			end
			if not frame:IsEventRegistered("ZONE_CHANGED_INDOORS") then
				frame:RegisterEvent("ZONE_CHANGED_INDOORS")
			end
			-- outdoor subzone changes only fire ZONE_CHANGED; without it, events
			-- keyed on a subzone name never triggered outside raid interiors
			if not frame:IsEventRegistered("ZONE_CHANGED") then
				frame:RegisterEvent("ZONE_CHANGED")
			end
		elseif eventType=="Script" then
			local trigger = ev.Trigger
			-- pcall: an invalid event name in hand-edited saved data must not
			-- abort registration of the remaining events
			if trigger and trigger~="" and not frame:IsEventRegistered(trigger) then
				pcall(frame.RegisterEvent, frame, trigger)
			end
		end
	end
	-- Guard: Timer may not exist yet during initial load
	if ItemRack.TimerPool and ItemRack.TimerPool["CheckForMountedEvents"] then
		ItemRack.StartTimer("CheckForMountedEvents")
	end

	-- During login this initial sweep is deferred: zone text is still "" and
	-- shapeshift forms aren't populated, which made Unequip-flagged zone/stance
	-- sets strip at every login. OnEnterWorld sets the flag and re-runs us.
	if ItemRack.EnteredWorld then
		ItemRack.ProcessStanceEvent()
		ItemRack.ProcessZoneEvent()
		ItemRack.ProcessBuffEvent()
	end
end

function ItemRack.ToggleEvents(self)
	ItemRackUser.EnableEvents = ItemRackUser.EnableEvents=="ON" and "OFF" or "ON"
	if not next(ItemRackUser.Events.Enabled) then
		-- user is turning on events with no events enabled, go to events frame
		-- Options module is now integrated
		ItemRackOptFrame:Show()
		ItemRackOpt.TabOnClick(self,3)
	else
		if ItemRackOptFrame and ItemRackOptFrame:IsVisible() then
			ItemRackOpt.ListScrollFrameUpdate()
		end
	end
	ItemRack.RegisterEvents()
end

--[[ Event processing ]]

local compiledScripts = {} -- compiled Script-event chunks, keyed by script text

function ItemRack.ProcessingFrameOnEvent(self,event,...)
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents
	local startBuff, startZone, startStance, eventType
	local arg1, arg2 = ...;

	for eventName in pairs(enabled) do
		eventType = events[eventName] and events[eventName].Type
		if event=="UNIT_AURA" and eventType=="Buff" and arg1=="player" then
			startBuff = 1
		elseif event=="UPDATE_SHAPESHIFT_FORM" and eventType=="Stance" then
			startStance = 1
		elseif event=="ZONE_CHANGED_NEW_AREA" and eventType=="Zone" then -- if player move to a new area, toggle set change.
			startZone = 1
		elseif event == "ZONE_CHANGED_INDOORS" and eventType == "Zone" and select(2, IsInInstance()) == "raid" then -- if player change subzone in raid instance, toggle set change, else not.
			startZone = 1
		elseif event=="ZONE_CHANGED" and eventType=="Zone" then -- outdoor subzone change (needed for subzone-keyed events)
			startZone = 1
		elseif eventType=="Script" and events[eventName].Trigger==event then
			local script = events[eventName].Script
			local method = compiledScripts[script]
			if method == nil then
				-- legacy scripts read the event args as arg1..arg5; the client no
				-- longer provides those globals, so compile them in as locals
				method = loadstring("local arg1,arg2,arg3,arg4,arg5 = ...; "..script) or false
				compiledScripts[script] = method
			end
			if method then
				pcall(method, ...)
			end
		end
	end
	if startStance then
		ItemRack.ProcessStanceEvent()
	end
	if startBuff and ItemRack.TimerPool and ItemRack.TimerPool["EventsBuffTimer"] then
		ItemRack.StartTimer("EventsBuffTimer")
	end
	if startZone and ItemRack.TimerPool and ItemRack.TimerPool["EventsZoneTimer"] then
		ItemRack.StartTimer("EventsZoneTimer")
	end
end

function ItemRack.GetStanceNumber(name)
	if tonumber(name) then
		return tonumber(name) -- convert: a saved string "1" would never == GetShapeshiftForm()'s number
	end
	for i=1,GetNumShapeshiftForms() do
		if name==select(2,GetShapeshiftFormInfo(i)) then
			return i
		end
	end
end

function ItemRack.ProcessStanceEvent()
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents

	local currentStance = GetShapeshiftForm()
	-- A form the client keeps secret can't be compared: leave the sets as they are
	if ItemRack.IsSecret(currentStance) then return end
	local stance, setname, skip
	-- collect ALL matching events: keeping single variables meant that with two
	-- simultaneously-matching events only the last one pairs() happened to
	-- enumerate won — nondeterministic. All unequips run before all equips.
	local setsToEquip, setsToUnequip = {},{}

	for eventName in pairs(enabled) do
		if events[eventName] and events[eventName].Type=="Stance" then
			skip = nil
			if events[eventName].NotInPVP then
				local _,instanceType = IsInInstance()
				if instanceType=="arena" or instanceType=="pvp" then
					skip = 1
				end
			end
			if not skip then
				stance = ItemRack.GetStanceNumber(events[eventName].Stance)
				setname = ItemRackUser.Events.Set[eventName]
				-- stance is nil when a named form can't be resolved (form data not
				-- loaded yet, eg right after login): indeterminate, don't treat it
				-- as "left the stance" and strip the set
				if stance and setname then
					if stance==currentStance and not ItemRack.IsSetEquipped(setname) then
						-- if this event is for this stance, then we'll want to equip this one
						table.insert(setsToEquip,setname)
					elseif stance~=currentStance and events[eventName].Unequip and ItemRack.IsSetEquipped(setname) then
						-- if this event is for last stance, then we'll want to unequip it
						table.insert(setsToUnequip,setname)
					end
				end
			end
		end
	end
	for i=1,#setsToUnequip do
		ItemRack.UnequipSet(setsToUnequip[i])
	end
	for i=1,#setsToEquip do
		ItemRack.EquipSet(setsToEquip[i])
	end
end

local zoneRetryPending
function ItemRack.ProcessZoneEvent()
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents

	local currentZone = GetRealZoneText()
	local currentSubZone = GetSubZoneText()

	if not currentZone or currentZone=="" then
		-- zone info isn't available yet (fresh login or mid loading screen).
		-- Treating this as "in no zone" wrongly unequipped Unequip-flagged sets;
		-- retry shortly instead. (C_Timer rather than EventsZoneTimer: the timer
		-- system stops a one-shot AFTER its callback, cancelling self re-arms.)
		if not zoneRetryPending then
			zoneRetryPending = true
			C_Timer.After(0.3, function()
				zoneRetryPending = nil
				ItemRack.ProcessZoneEvent()
			end)
		end
		return
	end

	local setname, inZone
	-- collect ALL matching events (see ProcessStanceEvent); unequips before equips
	local setsToEquip, setsToUnequip = {},{}

	for eventName in pairs(enabled) do
		if events[eventName] and events[eventName].Type=="Zone" then
			setname = ItemRackUser.Events.Set[eventName]
			inZone = events[eventName].Zones[currentZone] or events[eventName].Zones[currentSubZone]
			if setname then
				if inZone and not ItemRack.IsSetEquipped(setname) then
					table.insert(setsToEquip,setname)
				elseif not inZone and events[eventName].Unequip and ItemRack.IsSetEquipped(setname) then
					table.insert(setsToUnequip,setname)
				end
			end
		end
	end
	for i=1,#setsToUnequip do
		ItemRack.UnequipSet(setsToUnequip[i])
	end
	for i=1,#setsToEquip do
		ItemRack.EquipSet(setsToEquip[i])
	end
end

--here we observe mounted status and raise an event should it change. UNIT_AURA event seems unreliable for this
local _lastStateMounted = ItemRack.Mounted()
function ItemRack.CheckForMountedEvents()
	if ItemRack.Flag(UnitIsDeadOrGhost("player")) then
		return
	end

	if ItemRackUser.EnableEvents=="OFF" then
		return
	end

	local isPlayerMounted = ItemRack.Mounted()
	if isPlayerMounted == nil then
		return -- the client won't say: keep what was last known
	end
	if isPlayerMounted ~= _lastStateMounted then
		_lastStateMounted = isPlayerMounted
		ItemRack.ProcessBuffEvent()
	end
end

function ItemRack.ProcessBuffEvent()
	local enabled = ItemRackUser.Events.Enabled
	local events = ItemRackEvents

	local buff, setname, isSetEquipped, skip
	-- collect ALL matching events (see ProcessStanceEvent); unequips before equips,
	-- otherwise an unequip enumerated after an equip could restore old gear on top
	-- of the set another buff event just equipped
	local setsToEquip, setsToUnequip = {},{}

	for eventName in pairs(enabled) do
		if events[eventName] and events[eventName].Type=="Buff" then
			skip = nil
			if events[eventName].NotInPVP then
				local _,instanceType = IsInInstance()
				if instanceType=="arena" or instanceType=="pvp" then
					skip = 1
				end
			end
			if events[eventName].NotInPVE then
				local _,instanceType = IsInInstance()
				if instanceType=="party" or instanceType=="raid" then
					skip = 1
				end
			end
			if not skip then
				local known = true
				if events[eventName].Anymount then
					buff = ItemRack.Mounted()
					known = buff ~= nil
				else
					-- Unreadable in combat on Forever: leave this set alone until
					-- the buffs can be seen again.
					known, buff = ItemRack.FindBuff(events[eventName].Buff)
				end
				setname = ItemRackUser.Events.Set[eventName]
				if setname and known then -- an enabled event without a set would spam EquipSet(nil) on every aura change
					isSetEquipped = ItemRack.IsSetEquipped(setname)
					if buff and not isSetEquipped then
						table.insert(setsToEquip,setname)
					elseif not buff and isSetEquipped and events[eventName].Unequip then
						table.insert(setsToUnequip,setname)
					end
				end
			end
		end
	end
	for i=1,#setsToUnequip do
		ItemRack.UnequipSet(setsToUnequip[i])
	end
	for i=1,#setsToEquip do
		ItemRack.EquipSet(setsToEquip[i])
	end
end

function ItemRack.ReflectEventsRunning()
	if ItemRackUser.EnableEvents=="ON" and next(ItemRackUser.Events.Enabled) then
		-- if events enabled and an event is enabled, show gear icon on button 20
		if ItemRackUser.Buttons[20] then
			ItemRackButton20Queue:Show()
		end
	else
		if ItemRackUser.Buttons[20] then
			ItemRackButton20Queue:Hide()
		end
	end
	-- Don't call UpdateCurrentSet here - it causes race conditions during set swaps
	-- The icon is updated by EndSetSwap when swaps complete
end
