ESX = {}
ESX.Player = {}

-- as you can see, player data is always populated with defaults
-- this is to prevent script errors, esx itself is never nil but
-- most character related info is waiting for kashacter to choose char.
-- that's why we populate this table with default stuff: so nothing breaks,
-- it also gives a basic understanding what's available within ESX.Player.*

ESX.PlayerData = {
	job = {name = 'unemployed', grade = 0, label = 'Unemployed', grade_label = 'Unemployed'},
	inventory = {}, loadout = {}, accounts = {}, groups = {}, name = 'Unknown Name'
}

ESX.PlayerLoaded = false
ESX.CurrentRequestId = 0
ESX.ServerCallbacks = {}
ESX.TimeoutCallbacks = {}

ESX.UI = {}
ESX.UI.HUD = {}
ESX.UI.HUD.RegisteredElements = {}
ESX.UI.Menu = {}
ESX.UI.Menu.RegisteredTypes = {}
ESX.UI.Menu.Opened = {}

ESX.Game = {}
ESX.Game.Utils = {}

ESX.Scaleform = {}
ESX.Scaleform.Utils = {}

ESX.Streaming = {}

ESX.Status = {}
ESX.GetStatus = function (key) return key and ESX.Status[key] or ESX.Status end
ESX.SetStatus = function (key, value) ESX.Status[key] = value end

ESX.ClearTimeout = function(timeoutId) ESX.TimeoutCallbacks[timeoutId] = nil end

ESX.IsPlayerLoaded = function() return ESX.PlayerLoaded end
ESX.GetPlayerData = function() return ESX.PlayerData end
ESX.SetPlayerData = function(key, val) ESX.PlayerData[key] = val end

ESX.Player.GetName = function() return ESX.PlayerData.name end
ESX.Player.GetInventory = function() return ESX.PlayerData.inventory end
ESX.Player.GetLoadout = function() return ESX.PlayerData.loadout end
ESX.Player.GetAccounts = function() return ESX.PlayerData.accounts end

ESX.Player.GetJob = function() return ESX.PlayerData.job end
ESX.Player.GetJobName = function() return ESX.PlayerData.job.name end
ESX.Player.GetJobLabel = function() return ESX.PlayerData.job.label end
ESX.Player.GetJobGrade = function() return ESX.PlayerData.job.grade end
ESX.Player.GetJobGradeLabel = function() return ESX.PlayerData.job.grade_label end

ESX.Functions = {}

ESX.RegisterFunction = function(name, cb)
	ESX.Functions[name] = cb
end

ESX.Function = function(name, ...)
	if ESX.Functions[name] then
		ESX.Functions[name](...)
	else
		print(('^1[gigneMode]^7 Function "%s" does not exist.'):format(name))
	end
end

-- Add a seperate table for gigneMode functions, but using metatables to limit feature usage on the ESX table
-- This is to provide backward compatablity with ESX but not add new features to the old ESX tables.
-- Note: Please add all new namespaces to ExM _after_ this block
--[[do
    local function processTable(thisTable)
        local thisObject = setmetatable({}, {
            __index = thisTable
        })
        for key, value in pairs(thisTable) do
            if type(value) == "table" then
                thisObject[key] = processTable(value)
            end
        end
        return thisObject
    end
    ExM = processTable(ESX)
end--]]

ESX.SetTimeout = function(msec, cb)
	table.insert(ESX.TimeoutCallbacks, {
		time = GetGameTimer() + msec,
		cb   = cb
	})
	return #ESX.TimeoutCallbacks
end

ESX.ClearTimeout = function(i)
	ESX.TimeoutCallbacks[i] = nil
end

ESX.IsPlayerLoaded = function()
	return ESX.PlayerLoaded
end

ESX.GetPlayerData = function()
	return ESX.PlayerData
end

ESX.SetPlayerData = function(key, val)
	ESX.PlayerData[key] = val
end

ESX.ShowNotification = function(msg, flash, saveToBrief, hudColorIndex)
	if Config.ShowNotification then
		if saveToBrief == nil then saveToBrief = true end
		AddTextEntry('esxNotification', msg)
		BeginTextCommandThefeedPost('esxNotification')
		if hudColorIndex then ThefeedNextPostBackgroundColor(hudColorIndex) end
		EndTextCommandThefeedPostTicker(flash or false, saveToBrief)
	else
		TriggerEvent('showNotification', msg, flash, saveToBrief, hudColorIndex)
	end
end

ESX.ShowAdvancedNotification = function(sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)
	if Config.ShowAdvancedNotification then
		if saveToBrief == nil then saveToBrief = true end
		AddTextEntry('esxAdvancedNotification', msg)
		BeginTextCommandThefeedPost('esxAdvancedNotification')
		if hudColorIndex then ThefeedNextPostBackgroundColor(hudColorIndex) end
		EndTextCommandThefeedPostMessagetext(textureDict, textureDict, false, iconType, sender, subject)
		EndTextCommandThefeedPostTicker(flash or false, saveToBrief)
	else
		TriggerEvent('showAdvancedNotification', sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)
	end
end

ESX.ShowHelpNotification = function(msg, thisFrame, beep, duration)
	if Config.ShowHelpNotification then
		AddTextEntry('esxHelpNotification', msg)

		if thisFrame then
			DisplayHelpTextThisFrame('esxHelpNotification', false)
		else
			if beep == nil then beep = true end
			BeginTextCommandDisplayHelp('esxHelpNotification')
			EndTextCommandDisplayHelp(0, false, beep, duration or -1)
		end
	else
		TriggerEvent('showHelpNotification', msg, thisFrame, beep, duration)
	end
end

ESX.ShowFloatingHelpNotification = function(msg, coords)
	if Config.ShowHelpNotification then
		AddTextEntry('esxFloatingHelpNotification', msg)
		SetFloatingHelpTextWorldPosition(1, coords)
		SetFloatingHelpTextStyle(1, 1, 2, -1, 3, 0)
		BeginTextCommandDisplayHelp('esxFloatingHelpNotification')
		EndTextCommandDisplayHelp(2, false, false, -1)
	else
		TriggerEvent('showFloatingHelpNotification', msg, thisFrame, beep, duration)
	end
end

ESX.DrawSpinner = function(msg)
	AddTextEntry('esxSpinner', msg)
	BeginTextCommandBusyspinnerOn('esxSpinner')
	EndTextCommandBusyspinnerOn(4)
end

ESX.TriggerServerCallback = function(name, cb, ...)
	ESX.ServerCallbacks[ESX.CurrentRequestId] = cb

	TriggerServerEvent('esx:triggerServerCallback', name, ESX.CurrentRequestId, ...)

	if ESX.CurrentRequestId < 65535 then
		ESX.CurrentRequestId = ESX.CurrentRequestId + 1
	else
		ESX.CurrentRequestId = 0
	end
end

ESX.UI.rightInfoNotification = function(label)
	SendNUIMessage({
		action = 'rightInfoNotification',
		add    = label,
	})
end

ESX.UI.HUD.SetDisplay = function(opacity)
	SendNUIMessage({
		action  = 'setHUDDisplay',
		opacity = opacity
	})
end

ESX.UI.HUD.RegisterElement = function(name, index, priority, html, data)
	local found = false

	for i=1, #ESX.UI.HUD.RegisteredElements, 1 do
		if ESX.UI.HUD.RegisteredElements[i] == name then
			found = true
			break
		end
	end

	if found then
		return
	end

	table.insert(ESX.UI.HUD.RegisteredElements, name)

	SendNUIMessage({
		action    = 'insertHUDElement',
		name      = name,
		index     = index,
		priority  = priority,
		html      = html,
		data      = data
	})

	ESX.UI.HUD.UpdateElement(name, data)
end

ESX.UI.HUD.RemoveElement = function(name)
	for i=1, #ESX.UI.HUD.RegisteredElements, 1 do
		if ESX.UI.HUD.RegisteredElements[i] == name then
			table.remove(ESX.UI.HUD.RegisteredElements, i)
			break
		end
	end

	SendNUIMessage({
		action    = 'deleteHUDElement',
		name      = name
	})
end

ESX.UI.HUD.UpdateElement = function(name, data)
	SendNUIMessage({
		action = 'updateHUDElement',
		name   = name,
		data   = data
	})
end

ESX.UI.Menu.RegisterType = function(type, open, close)
	ESX.UI.Menu.RegisteredTypes[type] = {
		open   = open,
		close  = close
	}
end

ESX.UI.Menu.Open = function(type, namespace, name, data, submit, cancel, change, close)
	local menu = {}

	menu.type = type
	menu.namespace = namespace
	menu.name = name
	menu.data = data
	menu.submit = submit
	menu.cancel = cancel
	menu.change = change

	menu.refresh = function() ESX.UI.Menu.RegisteredTypes[type].open(namespace, name, menu.data) end
	menu.setElement = function(i, key, val) menu.data.elements[i][key] = val end
	menu.setElements = function(newElements) menu.data.elements = newElements end
	menu.setTitle = function(val) menu.data.title = val end

	menu.close = function()
		ESX.UI.Menu.RegisteredTypes[type].close(namespace, name)

		for i=1, #ESX.UI.Menu.Opened, 1 do
			if ESX.UI.Menu.Opened[i] then
				if ESX.UI.Menu.Opened[i].type == type and ESX.UI.Menu.Opened[i].namespace == namespace and ESX.UI.Menu.Opened[i].name == name then
					ESX.UI.Menu.Opened[i] = nil
				end
			end
		end

		if close then
			close()
		end
	end

	menu.update = function(query, newData)
		for i=1, #menu.data.elements, 1 do
			local match = true

			for k,v in pairs(query) do
				if menu.data.elements[i][k] ~= v then
					match = false
				end
			end

			if match then
				for k,v in pairs(newData) do
					menu.data.elements[i][k] = v
				end
			end
		end
	end

	menu.removeElement = function(query)
		for i=1, #menu.data.elements, 1 do
			for k,v in pairs(query) do
				if menu.data.elements[i] then
					if menu.data.elements[i][k] == v then
						table.remove(menu.data.elements, i)
						break
					end
				end

			end
		end
	end

	table.insert(ESX.UI.Menu.Opened, menu)
	ESX.UI.Menu.RegisteredTypes[type].open(namespace, name, data)

	return menu
end

ESX.UI.Menu.Close = function(type, namespace, name)
	for i=1, #ESX.UI.Menu.Opened, 1 do
		if ESX.UI.Menu.Opened[i] then
			if ESX.UI.Menu.Opened[i].type == type and ESX.UI.Menu.Opened[i].namespace == namespace and ESX.UI.Menu.Opened[i].name == name then
				ESX.UI.Menu.Opened[i].close()
				ESX.UI.Menu.Opened[i] = nil
			end
		end
	end
end

ESX.UI.Menu.CloseAll = function()
	for i=1, #ESX.UI.Menu.Opened, 1 do
		if ESX.UI.Menu.Opened[i] then
			ESX.UI.Menu.Opened[i].close()
			ESX.UI.Menu.Opened[i] = nil
		end
	end
end

ESX.UI.Menu.GetOpened = function(type, namespace, name)
	for i=1, #ESX.UI.Menu.Opened, 1 do
		if ESX.UI.Menu.Opened[i] then
			if ESX.UI.Menu.Opened[i].type == type and ESX.UI.Menu.Opened[i].namespace == namespace and ESX.UI.Menu.Opened[i].name == name then
				return ESX.UI.Menu.Opened[i]
			end
		end
	end
end

ESX.UI.Menu.GetOpenedMenus = function() return ESX.UI.Menu.Opened end
ESX.UI.Menu.IsOpen = function(type, namespace, name) return ESX.UI.Menu.GetOpened(type, namespace, name) ~= nil end

ESX.UI.ShowInventoryItemNotification = function(add, item, count)
	SendNUIMessage({
		action = 'inventoryNotification',
		add    = add,
		item   = item,
		count  = count
	})
end

ESX.Game.CreatePed = function(pedModel, pedCoords, isNetworked, pedType)
	local vector = type(pedCoords) == "vector4" and pedCoords or type(pedCoords) == "vector3" and vector4(pedCoords, 0.0)
	pedType = pedType ~= nil and pedType or 4
	
	ESX.Streaming.RequestModel(pedModel)
	return CreatePed(pedType, pedModel, vector, isNetworked)
end

ESX.Game.PlayAnim = function(animDict, animName, upperbodyOnly, duration)
	-- Quick simple function to run an animation
	local flags = upperbodyOnly == true and 16 or 0
	local runTime = duration ~= nil and duration or -1
	
	ESX.Streaming.RequestAnimDict(animDict)
	TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, 1.0, runTime, flags, 0.0, false, false, true)
	RemoveAnimDict(animDict)
end

ESX.Game.GetPedMugshot = function(ped, transparent)
	if DoesEntityExist(ped) then
		local mugshot

		if transparent then
			mugshot = RegisterPedheadshotTransparent(ped)
		else
			mugshot = RegisterPedheadshot(ped)
		end

		while not IsPedheadshotReady(mugshot) do
			Citizen.Wait(0)
		end

		return mugshot, GetPedheadshotTxdString(mugshot)
	else
		return
	end
end

ESX.Game.Teleport = function(entity, coords, cb, usePlayerPed)
	entity = usePlayerPed and PlayerPedId() or entity
	local vector = type(coords) == "vector4" and coords or type(coords) == "vector3" and vector4(coords, 0.0) or vec(coords.x, coords.y, coords.z, coords.heading or 0.0)
	
	if DoesEntityExist(entity) then
		local timeout = 0
		RequestCollisionAtCoord(vector.xyz)
		while not HasCollisionLoadedAroundEntity(entity) and timeout < 1000 do
			Citizen.Wait(0)
			timeout = timeout + 1
		end

		timeout = 0

		while IsNetworkLoadingScene() and timeout < 1000 do
			Citizen.Wait(0)
			timeout = timeout + 1
		end

		SetEntityCoords(entity, vector.xyz, false, false, false, false)
		SetEntityHeading(entity, vector.w)
	end

	if cb then
		cb()
	end
end

ESX.Game.RequestNetworkControlOfEntity = function(entityHandle, drawSpinner)
	if entityHandle and DoesEntityExist(entityHandle) then
		if drawSpinner then ESX.DrawSpinner('Requesting entity network control') end
		local attempt = 0

		while DoesEntityExist(entityHandle) and not NetworkHasControlOfEntity(entityHandle) and attempt < 5000 do
			Citizen.Wait(1)
			NetworkRequestControlOfEntity(entityHandle)
			attempt = attempt + 1
		end

		if drawSpinner then BusyspinnerOff() end
		return (DoesEntityExist(entityHandle) and NetworkHasControlOfEntity(entityHandle))
	else
		return false
	end
end

ESX.Game.SpawnObject = function(model, coords, cb, networked, dynamic)
	local vector = type(coords) == "vector3" and coords or vec(coords.x, coords.y, coords.z)
	model = (type(model) == 'number' and model or GetHashKey(model))
	networked = networked == nil and true or false
	dynamic = dynamic ~= nil and true or false
	
	CreateThread(function()
		ESX.Streaming.RequestModel(model)
		local obj = CreateObject(model, vector.xyz, networked, false, dynamic)
		SetModelAsNoLongerNeeded(model)
		if cb then
			cb(obj)
		end
	end)
end

ESX.Game.SpawnLocalObject = function(model, coords, cb)
	-- Why have 2 separate functions for this? Just call the other one with an extra param
	ESX.Game.SpawnObject(model, coords, cb, false)
end

ESX.Game.DeleteEntity = function(entity)
	SetEntityAsMissionEntity(entity, false, true)
	DeleteEntity(entity)
end

ESX.Game.DeleteVehicle = function(vehicle) ESX.Game.DeleteEntity(vehicle) end
ESX.Game.DeleteObject = function(object) ESX.Game.DeleteEntity(object) end

ESX.Game.SpawnVehicle = function(modelName, coords, heading, cb, vehicleProperties)
	local model = (type(modelName) == 'number' and modelName or GetHashKey(modelName))

	ESX.TriggerServerCallback('esx:spawnVehicle', function(entityNetworkId)
		while not NetworkDoesNetworkIdExist(entityNetworkId) do Citizen.Wait(100) end
		local entityHandle = NetworkGetEntityFromNetworkId(entityNetworkId)

		if ESX.Game.RequestNetworkControlOfEntity(entityHandle) then
			SetVehicleNeedsToBeHotwired(entityHandle, false)
			SetVehRadioStation(entityHandle, 'OFF')
			SetVehicleHasBeenOwnedByPlayer(entityHandle, true)
			SetVehicleAutoRepairDisabled(entityHandle, true)

			if vehicleProperties then ESX.Game.SetVehicleProperties(entityHandle, vehicleProperties) end
			if cb then cb(entityHandle) end
		end
	end, model, coords, heading)
end

ESX.Game.SpawnLocalVehicle = function(modelName, coords, heading, cb)
	local model = (type(modelName) == 'number' and modelName or GetHashKey(modelName))

	Citizen.CreateThread(function()
		ESX.Streaming.RequestModel(model)

		local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, false, false)
		local timeout = 0

		SetEntityAsMissionEntity(vehicle, true, false)
		SetVehicleHasBeenOwnedByPlayer(vehicle, true)
		SetVehicleNeedsToBeHotwired(vehicle, false)
		SetVehRadioStation(vehicle, 'OFF')
		SetModelAsNoLongerNeeded(model)
		RequestCollisionAtCoord(coords.x, coords.y, coords.z)
		SetVehicleAutoRepairDisabled(vehicle, true)

		-- we can get stuck here if any of the axies are "invalid"
		while not HasCollisionLoadedAroundEntity(vehicle) and timeout < 2000 do
			Citizen.Wait(0)
			timeout = timeout + 1
		end

		if cb then
			cb(vehicle)
		end
	end)
end

ESX.Game.IsVehicleEmpty = function(vehicle)
	local passengers = GetVehicleNumberOfPassengers(vehicle)
	local driverSeatFree = IsVehicleSeatFree(vehicle, -1)

	return passengers == 0 and driverSeatFree
end

ESX.Game.GetObjects = function()
	local objects = {}

	for object in EnumerateObjects() do
		table.insert(objects, object)
	end

	return objects
end

ESX.Game.GetPlayers = function(onlyOtherPlayers, returnKeyValue, returnPeds)
	local players, myPlayer = {}, PlayerId()

	for k,player in ipairs(GetActivePlayers()) do
		local ped = GetPlayerPed(player)

		if DoesEntityExist(ped) and ((onlyOtherPlayers and player ~= myPlayer) or not onlyOtherPlayers) then
			if returnKeyValue then
				players[player] = ped
			else
				table.insert(players, returnPeds and ped or player)
			end
		end
	end

	return players
end

ESX.Game.GetPeds = function(onlyOtherPeds)
	local peds, myPed = {}, PlayerPedId()

	for ped in EnumeratePeds() do
		if ((onlyOtherPeds and ped ~= myPed) or not onlyOtherPeds) then
			table.insert(peds, ped)
		end
	end

	return peds
end

ESX.Game.GetVehicles = function()
	local vehicles = {}

	for vehicle in EnumerateVehicles() do
		table.insert(vehicles, vehicle)
	end

	return vehicles
end

ESX.Game.GetClosestEntity = function(entities, isPlayerEntities, coords, modelFilter)
	local closestEntity, closestEntityDistance, filteredEntities = -1, -1, nil

	if coords and (type(coords) == 'number' or not coords.x) then
		local _modelFilter = modelFilter
		modelFilter = coords
		coords = _modelFilter
	end

	if modelFilter then
		local filter = {}
		if type(modelFilter) == 'table' then
			for _,model in pairs(modelFilter) do
				local hashModel = (type(model) == 'number' and model or GetHashKey(model))
				filter[hashModel] = model
			end
		elseif modelFilter ~= '' then
			local hashModel = (type(modelFilter) == 'number' and modelFilter or GetHashKey(modelFilter))
			filter[hashModel] = modelFilter
		end
		modelFilter = filter
	end

	if coords then
		coords = vector3(coords.x, coords.y, coords.z)
	else
		local playerPed = PlayerPedId()
		coords = GetEntityCoords(playerPed)
	end

	if modelFilter then
		filteredEntities = {}

		for k,entity in pairs(entities) do
			if modelFilter[GetEntityModel(entity)] then
				table.insert(filteredEntities, entity)
			end
		end
	end

	for k,entity in pairs(filteredEntities or entities) do
		local distance = #(coords - GetEntityCoords(entity))

		if closestEntityDistance == -1 or distance < closestEntityDistance then
			closestEntity, closestEntityDistance = isPlayerEntities and k or entity, distance
		end
	end

	return closestEntity, closestEntityDistance
end

ESX.Game.GetVehicleInDirection = function()
	local playerPed    = PlayerPedId()
	local playerCoords = GetEntityCoords(playerPed)
	local inDirection  = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 5.0, 0.0)
	local rayHandle    = StartShapeTestRay(playerCoords, inDirection, 10, playerPed, 0)
	local numRayHandle, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

	if hit == 1 and GetEntityType(entityHit) == 2 then
		return entityHit
	end
end

ESX.Game.GetClosestObject = function(coords, modelFilter) return ESX.Game.GetClosestEntity(ESX.Game.GetObjects(), false, coords, modelFilter) end
ESX.Game.GetClosestPed = function(coords, modelFilter) return ESX.Game.GetClosestEntity(ESX.Game.GetPeds(true), false, coords, modelFilter) end
ESX.Game.GetClosestPlayer = function(coords) return ESX.Game.GetClosestEntity(ESX.Game.GetPlayers(true, true), true, coords, nil) end
ESX.Game.GetClosestVehicle = function(coords, modelFilter) return ESX.Game.GetClosestEntity(ESX.Game.GetVehicles(), false, coords, modelFilter) end
ESX.Game.GetPlayersInArea = function(coords, maxDistance) return EnumerateEntitiesWithinDistance(ESX.Game.GetPlayers(true, true), true, coords, maxDistance) end
ESX.Game.GetVehiclesInArea = function(coords, maxDistance) return EnumerateEntitiesWithinDistance(ESX.Game.GetVehicles(), false, coords, maxDistance) end
ESX.Game.IsSpawnPointClear = function(coords, maxDistance) return #ESX.Game.GetVehiclesInArea(coords, maxDistance) == 0 end

ESX.Game.GetVehicleProperties = function(vehicle)
	if DoesEntityExist(vehicle) then
		local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
		local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
		local vehicleModel = GetEntityModel(vehicle)
		local vehicleLabel, extras = GetLabelText(GetDisplayNameFromVehicleModel(vehicleModel)), {}

		if vehicleLabel == 'NULL' then vehicleLabel = GetDisplayNameFromVehicleModel(vehicleModel) end

		for id=0, 12 do
			if DoesExtraExist(vehicle, id) then
				local state = IsVehicleExtraTurnedOn(vehicle, id) == 1
				extras[tostring(id)] = state
			end
		end

		return {
			model             = vehicleModel,
			label             = vehicleLabel,

			plate             = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle)),
			plateIndex        = GetVehicleNumberPlateTextIndex(vehicle),

			bodyHealth        = math.round(GetVehicleBodyHealth(vehicle), 1),
			engineHealth      = math.round(GetVehicleEngineHealth(vehicle), 1),
			petrolTankHealth  = math.round(GetVehiclePetrolTankHealth(vehicle), 1),

			fuelLevel         = math.round(GetVehicleFuelLevel(vehicle), 1),
			dirtLevel         = math.round(GetVehicleDirtLevel(vehicle), 1),
			color1            = colorPrimary,
			color2            = colorSecondary,

			pearlescentColor  = pearlescentColor,
			wheelColor        = wheelColor,

			wheels            = GetVehicleWheelType(vehicle),
			windowTint        = GetVehicleWindowTint(vehicle),
			xenonColor        = GetVehicleXenonLightsColour(vehicle),

			neonEnabled       = {
				IsVehicleNeonLightEnabled(vehicle, 0),
				IsVehicleNeonLightEnabled(vehicle, 1),
				IsVehicleNeonLightEnabled(vehicle, 2),
				IsVehicleNeonLightEnabled(vehicle, 3)
			},

			neonColor         = {GetVehicleNeonLightsColour(vehicle)},
			extras            = extras,
			tyreSmokeColor    = {GetVehicleTyreSmokeColor(vehicle)},

			modSpoilers       = GetVehicleMod(vehicle, 0),
			modFrontBumper    = GetVehicleMod(vehicle, 1),
			modRearBumper     = GetVehicleMod(vehicle, 2),
			modSideSkirt      = GetVehicleMod(vehicle, 3),
			modExhaust        = GetVehicleMod(vehicle, 4),
			modFrame          = GetVehicleMod(vehicle, 5),
			modGrille         = GetVehicleMod(vehicle, 6),
			modHood           = GetVehicleMod(vehicle, 7),
			modFender         = GetVehicleMod(vehicle, 8),
			modRightFender    = GetVehicleMod(vehicle, 9),
			modRoof           = GetVehicleMod(vehicle, 10),

			modEngine         = GetVehicleMod(vehicle, 11),
			modBrakes         = GetVehicleMod(vehicle, 12),
			modTransmission   = GetVehicleMod(vehicle, 13),
			modHorns          = GetVehicleMod(vehicle, 14),
			modSuspension     = GetVehicleMod(vehicle, 15),
			modArmor          = GetVehicleMod(vehicle, 16),

			modTurbo          = IsToggleModOn(vehicle, 18),
			modSmokeEnabled   = IsToggleModOn(vehicle, 20),
			modXenon          = IsToggleModOn(vehicle, 22),

			modFrontWheels    = GetVehicleMod(vehicle, 23),
			modBackWheels     = GetVehicleMod(vehicle, 24),

			modPlateHolder    = GetVehicleMod(vehicle, 25),
			modVanityPlate    = GetVehicleMod(vehicle, 26),
			modTrimA          = GetVehicleMod(vehicle, 27),
			modOrnaments      = GetVehicleMod(vehicle, 28),
			modDashboard      = GetVehicleMod(vehicle, 29),
			modDial           = GetVehicleMod(vehicle, 30),
			modDoorSpeaker    = GetVehicleMod(vehicle, 31),
			modSeats          = GetVehicleMod(vehicle, 32),
			modSteeringWheel  = GetVehicleMod(vehicle, 33),
			modShifterLeavers = GetVehicleMod(vehicle, 34),
			modAPlate         = GetVehicleMod(vehicle, 35),
			modSpeakers       = GetVehicleMod(vehicle, 36),
			modTrunk          = GetVehicleMod(vehicle, 37),
			modHydrolic       = GetVehicleMod(vehicle, 38),
			modEngineBlock    = GetVehicleMod(vehicle, 39),
			modAirFilter      = GetVehicleMod(vehicle, 40),
			modStruts         = GetVehicleMod(vehicle, 41),
			modArchCover      = GetVehicleMod(vehicle, 42),
			modAerials        = GetVehicleMod(vehicle, 43),
			modTrimB          = GetVehicleMod(vehicle, 44),
			modTank           = GetVehicleMod(vehicle, 45),
			modWindows        = GetVehicleMod(vehicle, 46),
			modStandardLivery = GetVehicleMod(vehicle, 48),
			modLivery         = GetVehicleLivery(vehicle),
			bulletProofTyres  = not GetVehicleTyresCanBurst(vehicle)
		}
	end
end

ESX.Game.SetVehicleProperties = function(vehicle, props)
	if DoesEntityExist(vehicle) then
		local colorPrimary, colorSecondary = GetVehicleColours(vehicle)
		local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
		SetVehicleModKit(vehicle, 0)
		SetVehicleAutoRepairDisabled(vehicle, true)

		if props.plate then SetVehicleNumberPlateText(vehicle, props.plate) end
		if props.plateIndex then SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex) end
		if props.bodyHealth then SetVehicleBodyHealth(vehicle, props.bodyHealth + 0.0) end
		if props.engineHealth then SetVehicleEngineHealth(vehicle, props.engineHealth + 0.0) end
		if props.petrolTankHealth then SetVehiclePetrolTankHealth(vehicle, props.petrolTankHealth + 0.0) end
		if props.fuelLevel then 
			SetVehicleFuelLevel(vehicle, props.fuelLevel + 0.0)
			DecorSetFloat(vehicle, "_Fuel_Level", props.fuelLevel + 0.0)
		end

		if props.dirtLevel then SetVehicleDirtLevel(vehicle, props.dirtLevel + 0.0) end
		if props.color1 then SetVehicleColours(vehicle, props.color1, colorSecondary) end
		if props.color2 then SetVehicleColours(vehicle, props.color1 or colorPrimary, props.color2) end
		if props.pearlescentColor then SetVehicleExtraColours(vehicle, props.pearlescentColor, wheelColor) end
		if props.wheelColor then SetVehicleExtraColours(vehicle, props.pearlescentColor or pearlescentColor, props.wheelColor) end
		if props.wheels then SetVehicleWheelType(vehicle, props.wheels) end
		if props.windowTint then SetVehicleWindowTint(vehicle, props.windowTint) end

		if props.neonEnabled then
			SetVehicleNeonLightEnabled(vehicle, 0, props.neonEnabled[1])
			SetVehicleNeonLightEnabled(vehicle, 1, props.neonEnabled[2])
			SetVehicleNeonLightEnabled(vehicle, 2, props.neonEnabled[3])
			SetVehicleNeonLightEnabled(vehicle, 3, props.neonEnabled[4])
		end

		if props.extras then
			for id,enabled in pairs(props.extras) do
				if enabled then
					SetVehicleExtra(vehicle, tonumber(id), 0)
				else
					SetVehicleExtra(vehicle, tonumber(id), 1)
				end
			end
		end

		if props.bulletProofTyres ~= nil then SetVehicleTyresCanBurst(vehicle, not props.bulletProofTyres) end
		if props.neonColor then SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3]) end
		if props.xenonColor then SetVehicleXenonLightsColour(vehicle, props.xenonColor) end
		if props.modSmokeEnabled then ToggleVehicleMod(vehicle, 20, true) end
		if props.tyreSmokeColor then SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3]) end
		if props.modSpoilers then SetVehicleMod(vehicle, 0, props.modSpoilers, false) end
		if props.modFrontBumper then SetVehicleMod(vehicle, 1, props.modFrontBumper, false) end
		if props.modRearBumper then SetVehicleMod(vehicle, 2, props.modRearBumper, false) end
		if props.modSideSkirt then SetVehicleMod(vehicle, 3, props.modSideSkirt, false) end
		if props.modExhaust then SetVehicleMod(vehicle, 4, props.modExhaust, false) end
		if props.modFrame then SetVehicleMod(vehicle, 5, props.modFrame, false) end
		if props.modGrille then SetVehicleMod(vehicle, 6, props.modGrille, false) end
		if props.modHood then SetVehicleMod(vehicle, 7, props.modHood, false) end
		if props.modFender then SetVehicleMod(vehicle, 8, props.modFender, false) end
		if props.modRightFender then SetVehicleMod(vehicle, 9, props.modRightFender, false) end
		if props.modRoof then SetVehicleMod(vehicle, 10, props.modRoof, false) end
		if props.modEngine then SetVehicleMod(vehicle, 11, props.modEngine, false) end
		if props.modBrakes then SetVehicleMod(vehicle, 12, props.modBrakes, false) end
		if props.modTransmission then SetVehicleMod(vehicle, 13, props.modTransmission, false) end
		if props.modHorns then SetVehicleMod(vehicle, 14, props.modHorns, false) end
		if props.modSuspension then SetVehicleMod(vehicle, 15, props.modSuspension, false) end
		if props.modArmor then SetVehicleMod(vehicle, 16, props.modArmor, false) end
		if props.modTurbo then ToggleVehicleMod(vehicle,  18, props.modTurbo) end
		if props.modXenon then ToggleVehicleMod(vehicle,  22, props.modXenon) end
		if props.modFrontWheels then SetVehicleMod(vehicle, 23, props.modFrontWheels, false) end
		if props.modBackWheels then SetVehicleMod(vehicle, 24, props.modBackWheels, false) end
		if props.modPlateHolder then SetVehicleMod(vehicle, 25, props.modPlateHolder, false) end
		if props.modVanityPlate then SetVehicleMod(vehicle, 26, props.modVanityPlate, false) end
		if props.modTrimA then SetVehicleMod(vehicle, 27, props.modTrimA, false) end
		if props.modOrnaments then SetVehicleMod(vehicle, 28, props.modOrnaments, false) end
		if props.modDashboard then SetVehicleMod(vehicle, 29, props.modDashboard, false) end
		if props.modDial then SetVehicleMod(vehicle, 30, props.modDial, false) end
		if props.modDoorSpeaker then SetVehicleMod(vehicle, 31, props.modDoorSpeaker, false) end
		if props.modSeats then SetVehicleMod(vehicle, 32, props.modSeats, false) end
		if props.modSteeringWheel then SetVehicleMod(vehicle, 33, props.modSteeringWheel, false) end
		if props.modShifterLeavers then SetVehicleMod(vehicle, 34, props.modShifterLeavers, false) end
		if props.modAPlate then SetVehicleMod(vehicle, 35, props.modAPlate, false) end
		if props.modSpeakers then SetVehicleMod(vehicle, 36, props.modSpeakers, false) end
		if props.modTrunk then SetVehicleMod(vehicle, 37, props.modTrunk, false) end
		if props.modHydrolic then SetVehicleMod(vehicle, 38, props.modHydrolic, false) end
		if props.modEngineBlock then SetVehicleMod(vehicle, 39, props.modEngineBlock, false) end
		if props.modAirFilter then SetVehicleMod(vehicle, 40, props.modAirFilter, false) end
		if props.modStruts then SetVehicleMod(vehicle, 41, props.modStruts, false) end
		if props.modArchCover then SetVehicleMod(vehicle, 42, props.modArchCover, false) end
		if props.modAerials then SetVehicleMod(vehicle, 43, props.modAerials, false) end
		if props.modTrimB then SetVehicleMod(vehicle, 44, props.modTrimB, false) end
		if props.modTank then SetVehicleMod(vehicle, 45, props.modTank, false) end
		if props.modWindows then SetVehicleMod(vehicle, 46, props.modWindows, false) end

		if props.modLivery then
			SetVehicleMod(vehicle, 48, props.modLivery, false)
			SetVehicleLivery(vehicle, props.modLivery)
		end
	end
end

ESX.Game.Utils.DrawText3D = function(coords, text, size, font)
	coords = vector3(coords.x, coords.y, coords.z)

	local camCoords = GetGameplayCamCoords()
	local distance = #(coords - camCoords)

	if not size then size = 1 end
	if not font then font = 0 end

	local scale = (size / distance) * 2
	local fov = (1 / GetGameplayCamFov()) * 100
	scale = scale * fov

	SetTextScale(0.0 * scale, 0.55 * scale)
	SetTextFont(font)
	SetTextColour(255, 255, 255, 255)
	SetTextDropshadow(0, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextCentre(true)

	SetDrawOrigin(coords, 0)
	BeginTextCommandDisplayText('STRING')
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(0.0, 0.0)
	ClearDrawOrigin()
end

RegisterNetEvent('esx:serverCallback')
AddEventHandler('esx:serverCallback', function(requestId, ...)
	ESX.ServerCallbacks[requestId](...)
	ESX.ServerCallbacks[requestId] = nil
end)

RegisterNetEvent('esx:showNotification')
AddEventHandler('esx:showNotification', function(msg, flash, saveToBrief, hudColorIndex)
	ESX.ShowNotification(msg, flash, saveToBrief, hudColorIndex)
end)

RegisterNetEvent('esx:showAdvancedNotification')
AddEventHandler('esx:showAdvancedNotification', function(sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)
	ESX.ShowAdvancedNotification(sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex)
end)

RegisterNetEvent('esx:showHelpNotification')
AddEventHandler('esx:showHelpNotification', function(msg, thisFrame, beep, duration)
	ESX.ShowHelpNotification(msg, thisFrame, beep, duration)
end)

RegisterNetEvent('esx:showInventoryItemNotification')
AddEventHandler('esx:showInventoryItemNotification', function(msg, add) ESX.UI.ShowInventoryItemNotification(add, msg, 1) end)

-- SetTimeout
CreateThread(function()
	while true do
		Wait(0)
		local currTime = GetGameTimer()

		for i=1, #ESX.TimeoutCallbacks, 1 do
			if ESX.TimeoutCallbacks[i] then
				if currTime >= ESX.TimeoutCallbacks[i].time then
					ESX.TimeoutCallbacks[i].cb()
					ESX.TimeoutCallbacks[i] = nil
				end
			end
		end
	end
end)

ESX.Markers = {}
ESX.Markers.Table = {}

ESX.Markers.Add = function(mType, mPos, red, green, blue, alpha, rangeToShow, bobUpAndDown, mScale, mRot, mDir, faceCamera, textureDict, textureName)
	rangeToShow = rangeToShow ~= nil and rangeToShow or 50.0
	mScale = mScale ~= nil and mScale or vec(1, 1, 1)
	mDir = mDir ~= nil and mDir or vec(0, 0, 0)
	mRot = mRot ~= nil and mRot or vec(0, 0, 0)
	bobUpAndDown = bobUpAndDown or false
	faceCamera = faceCamera or false
	textureDict = textureDict or nil
	textureName = textureName or nil
	
	if textureDict ~= nil then
		ESX.Streaming.RequestStreamedTextureDict(textureDict)
	end
	
	local markerData = {
		range = rangeToShow,
		type = mType,
		pos = mPos,
		dir = mDir,
		rot = mRot,
		scale = mScale,
		r = red,
		g = green,
		b = blue,
		a = alpha,
		bob = bobUpAndDown,
		faceCam = faceCamera,
		dict = textureDict,
		name = textureName,
		isInside = false,
		deleteNow = false
	}
	local tableKey = tostring(markerData)
    ESX.Markers.Table[tableKey] = markerData

    return tableKey
end

ESX.Markers.Remove = function(markerKey)
	ESX.Markers.Table[markerKey].deleteNow = true
	local textureDict = ESX.Markers.Table[markerKey].dict
	if textureDict ~= nil then
		SetStreamedTextureDictAsNoLongerNeeded(textureDict)
	end
end

ESX.Markers.In = function(markerKey)
	return ESX.Markers.Table[markerKey].isInside
end

local markerWait = 500
CreateThread(function()
	while true do
		Wait(markerWait)
		local ped = PlayerPedId()
		local pedCoords = GetEntityCoords(ped)
		markerWait = 500
		
		for markerKey, marker in pairs(ESX.Markers.Table) do
			if marker.deleteNow then
				marker = nil
			else
				if #(pedCoords - marker.pos) < marker.range then
					markerWait = 1
					DrawMarker(marker.type, marker.pos, marker.dir, marker.rot, marker.scale, marker.r, marker.g, marker.b, marker.a, marker.bob, marker.faceCam, 0, false, marker.dict, marker.name, false)
				end
				if #(pedCoords - marker.pos) < marker.scale.x then
					marker.isInside = true
				else
					marker.isInside = false
				end
			end
		end
	end
end)