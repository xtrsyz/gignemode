ESX.Trace = function(msg)
	if Config.EnableDebug then
		print(('[gigneMode] [^2TRACE^7] %s^7'):format(msg))
	end
end

ESX.SetTimeout = function(msec, cb)
	local id = ESX.TimeoutCount + 1

	SetTimeout(msec, function()
		if ESX.CancelledTimeouts[id] then
			ESX.CancelledTimeouts[id] = nil
		else
			cb()
		end
	end)

	ESX.TimeoutCount = id

	return id
end

ESX.RegisterCommand = function(name, group, cb, allowConsole, suggestion)
	if type(name) == 'table' then
		for k,v in pairs(name) do
			ESX.RegisterCommand(v, group, cb, allowConsole, suggestion)
		end

		return
	end

	if ESX.RegisteredCommands[name] then
		print(('[gigneMode] [^3WARNING^7] An command "%s" is already registered, overriding command'):format(name))

		if ESX.RegisteredCommands[name].suggestion then
			TriggerClientEvent('chat:removeSuggestion', -1, ('/%s'):format(name))
		end
	end

	if suggestion then
		if not suggestion.arguments then suggestion.arguments = {} end
		if not suggestion.help then suggestion.help = '' end

		TriggerClientEvent('chat:addSuggestion', -1, ('/%s'):format(name), suggestion.help, suggestion.arguments)
	end

	ESX.RegisteredCommands[name] = {group = group, cb = cb, allowConsole = allowConsole, suggestion = suggestion}

	RegisterCommand(name, function(playerId, args, rawCommand)
		local command = ESX.RegisteredCommands[name]

		if not command.allowConsole and playerId == 0 then
			print(('[gigneMode] [^3WARNING^7] %s'):format(_U('commanderror_console')))
		else
			local xPlayer, error = ESX.GetPlayerFromId(playerId), nil

			if command.suggestion then
				if command.suggestion.validate then
					if #args ~= #command.suggestion.arguments then
						error = _U('commanderror_argumentmismatch', #args, #command.suggestion.arguments)
					end
				end

				if not error and command.suggestion.arguments then
					local newArgs = {}

					for k,v in pairs(command.suggestion.arguments) do
						if v.type then
							if v.type == 'number' then
								local newArg = tonumber(args[k])

								if newArg then
									newArgs[v.name] = newArg
								else
									error = _U('commanderror_argumentmismatch_number', k)
								end
							elseif v.type == 'player' or v.type == 'playerId' then
								local targetPlayer = tonumber(args[k])

								if args[k] == 'me' then targetPlayer = playerId end

								if targetPlayer then
									local xTargetPlayer = ESX.GetPlayerFromId(targetPlayer)

									if xTargetPlayer then
										if v.type == 'player' then
											newArgs[v.name] = xTargetPlayer
										else
											newArgs[v.name] = targetPlayer
										end
									else
										error = _U('commanderror_invalidplayerid')
									end
								else
									error = _U('commanderror_argumentmismatch_number', k)
								end
							elseif v.type == 'string' then
								newArgs[v.name] = args[k]
							elseif v.type == 'item' then
								if ESX.Items[args[k]] then
									newArgs[v.name] = args[k]
								else
									error = _U('commanderror_invaliditem')
								end
							elseif v.type == 'weapon' then
								if ESX.GetWeapon(args[k]) then
									newArgs[v.name] = string.upper(args[k])
								else
									error = _U('commanderror_invalidweapon')
								end
							elseif v.type == 'any' then
								newArgs[v.name] = args[k]
							end
						end

						if error then break end
					end

					args = newArgs
				end
			end

			if error then
				if playerId == 0 then
					print(('[gigneMode] [^3WARNING^7] %s^7'):format(error))
				else
					xPlayer.triggerEvent('chat:addMessage', {args = {'^1SYSTEM', error}})
				end
			else
				cb(xPlayer or false, args, function(msg)
					if playerId == 0 then
						print(('[gigneMode] [^3WARNING^7] %s^7'):format(msg))
					else
						xPlayer.triggerEvent('chat:addMessage', {args = {'^1SYSTEM', msg}})
					end
				end)
			end
		end
	end, true)

	if type(group) == 'table' then
		for k,v in pairs(group) do
			ExecuteCommand(('add_ace group.%s command.%s allow'):format(v, name))
		end
	else
		ExecuteCommand(('add_ace group.%s command.%s allow'):format(group, name))
	end
end

ESX.ClearTimeout = function(id) ESX.CancelledTimeouts[id] = true end
ESX.GetServerCallbacks = function() return ESX.ServerCallbacks end
ESX.RegisterServerCallback = function(name, cb) ESX.ServerCallbacks[name] = cb end

ESX.TriggerServerCallback = function(name, requestId, source, cb, ...)
	if ESX.ServerCallbacks[name] then
		ESX.ServerCallbacks[name](source, cb, ...)
	else
		print(('[gigneMode] [^3WARNING^7] Server callback "%s" does not exist. Make sure that the server sided file really is loading, an error in that file might cause it to not load.'):format(name))
	end
end

ESX.SavePlayer = function(xPlayer, cb)
	if ESX.DatabaseType == "es+esx" then
		-- Nothing yet ;)
	elseif ESX.DatabaseType == "newesx" then
		local health = {health = xPlayer.getHealth(), armour = xPlayer.getArmour()}
		MySQL.Async.execute([===[
			UPDATE users SET 
				`accounts` = @accounts, 
				`job` = @job, job_grade = @job_grade, 
				`groups` = @groups, 
				`loadout` = @loadout, 
				`position` = @position, 
				`status` = @status, 
				`health` = @health, 
				`inventory` = @inventory 
			WHERE `identifier` = @identifier
			]===], {
			['@accounts'] = json.encode(xPlayer.getAccounts(true)),
			['@job'] = xPlayer.job.name,
			['@job_grade'] = xPlayer.job.grade,
			['@groups'] = json.encode(xPlayer.getGroups()),
			['@loadout'] = json.encode(xPlayer.getLoadout(true)),
			['@position'] = json.encode(xPlayer.getCoords()),
			['@status'] = json.encode(xPlayer.getStatus()),
			['@health'] = json.encode(health),
			['@armour'] = xPlayer.getArmour(),
			['@inventory'] = json.encode(xPlayer.getInventory(true)),
			['@identifier'] = xPlayer.getIdentifier()
		}, cb)
		ESX.SaveBatchs(xPlayer)
	end
end

ESX.SaveBatchs = function(xPlayer)
	Citizen.CreateThread(function()
		local identifier = xPlayer.getIdentifier()
		for k, inventory in pairs(xPlayer.inventory) do
			local LastInventory = ESX.LastInventory[identifier][inventory.name] or {count = 0, batch = {}}
			if LastInventory.count ~= inventory.count then
				for batchNumber, batch in pairs(inventory.batch) do
					if batch == false then
						MySQL.Async.execute('DELETE FROM user_batch WHERE identifier=@identifier AND name=@name AND batch=@batch', {
							['@identifier'] = identifier,
							['@name'] = inventory.name,
							['@batch'] = batchNumber,
						})
						inventory.batch[batchNumber] = nil
						LastInventory.batch[batchNumber] = nil
					else
						if not LastInventory.batch[batchNumber] or LastInventory.batch[batchNumber].count ~= batch.count then
							LastInventory.batch[batchNumber] = {count = batch.count}
							MySQL.Async.execute('INSERT INTO user_batch (identifier, name, batch, count, info) VALUES (@identifier, @name, @batch, @count, @info) ON DUPLICATE KEY UPDATE count = @count, info = @info', {
								['@identifier'] = identifier,
								['@name'] = inventory.name,
								['@batch'] = batchNumber,
								['@count'] = batch.count,
								['@info'] = json.encode(batch.info)
							})
						end
					end					
				end
				LastInventory.count = inventory.count
			end
		end		
	end)
end

ESX.SavePlayers = function(finishedCB)
	CreateThread(function()
		local savedPlayers = 0
		local playersToSave = 0
		local maxTimeout = 20000
		local currentTimeout = 0
	
		-- Save Each player
		for _, xPlayer in pairs(ESX.Players) do
			playersToSave = playersToSave + 1
			ESX.SavePlayer(xPlayer, function(rowsChanged)
				if rowsChanged == 1 then
					savedPlayers = savedPlayers	+ 1
				end
			end)
		end

		-- Call the callback when done
		while true do
			Citizen.Wait(500)
			currentTimeout = currentTimeout + 500
			if playersToSave == savedPlayers then
				finishedCB(true)
				break
			elseif currentTimeout >= maxTimeout then
				finishedCB(false)
				break
			end
		end
	end)
end

ESX.StartDBSync = function()
	function saveData()
		ESX.SavePlayers(function(result)
			if result then
				print('[gigneMode] [^2INFO^7] Automatically saved all player data')
			else
				print('[gigneMode] [^3WARNING^7] Failed to automatically save player data! This may be caused by an internal error on the MySQL server.')
			end
		end)
		SetTimeout(Config.SaveDataInterval, saveData)
	end

	SetTimeout(Config.SaveDataInterval, saveData)
end

ESX.GetPlayers = function()
	local sources = {}

	for k,v in pairs(ESX.Players) do
		table.insert(sources, k)
	end

	return sources
end

ESX.GetPlayerFromId = function(source) return ESX.Players[tonumber(source)] end

ESX.GetPlayerFromIdentifier = function(identifier)
	for k,v in pairs(ESX.Players) do
		if v.identifier == identifier then
			return v
		end
	end
end

ESX.RegisterUsableItem = function(item, cb) ESX.UsableItemsCallbacks[item] = cb end

ESX.UseItem = function(source, item, batchNumber)
	if ESX.UsableItemsCallbacks[item] then
		ESX.UsableItemsCallbacks[item](source, batchNumber)
	end
end

ESX.GetItemLabel = function(item) return ESX.Items[item] and ESX.Items[item].label or 'Unknown' end

ESX.CreatePickup = function(type, name, count, label, playerId, components, tintIndex, batchInfo)
    local pickupId = (ESX.PickupId == 65635 and 0 or ESX.PickupId + 1)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local pedCoords
    
    if ESX.IsInfinity then
        pedCoords = GetEntityCoords(GetPlayerPed(playerId))
    end

    ESX.Pickups[pickupId] = {
        type  = type,
        name  = name,
        count = count,
        label = label,
        batch = batchInfo,
        coords = xPlayer.getCoords(),
    }

    if type == 'item_weapon' then
        ESX.Pickups[pickupId].components = components
        ESX.Pickups[pickupId].tintIndex = tintIndex
    end

    TriggerClientEvent('esx:createPickup', -1, pickupId, label, playerId, type, name, components, tintIndex, ESX.IsInfinity, pedCoords)
    ESX.PickupId = pickupId
end

ESX.DoesJobExist = function(job, grade)
	grade = tostring(grade)

	if job and grade then
		if ESX.Jobs[job] and ESX.Jobs[job].grades[grade] then
			return true
		end
	end

	return false
end

ESX.GetJobs = function() return ESX.Jobs end
ESX.GetItems = function() return ESX.Items end

if ESX.IsOneSync then
	ESX.Game.SpawnVehicle = function(model, coords)
		local vector = type(coords) == "vector4" and coords or type(coords) == "vector3" and vector4(coords, 0.0)
		return CreateVehicle(model, vector.xyzw, true, false)
	end

	ESX.Game.CreatePed = function(pedModel, pedCoords, pedType)
		local vector = type(pedCoords) == "vector4" and pedCoords or type(pedCoords) == "vector3" and vector4(pedCoords, 0.0)
		pedType = pedType ~= nil and pedType or 4
		return CreatePed(pedType, pedModel, vector.xyzw, true)
	end

	ESX.Game.SpawnObject = function(model, coords, dynamic)
		model = type(model) == 'number' and model or GetHashKey(model)
		dynamic = dynamic ~= nil and true or false
		return CreateObjectNoOffset(model, coords.xyz, true, dynamic)
	end
end

ESX.GetBatch = function()
	local waktu = os.time()
	local major = math.floor(waktu / 86400)
	local minor = math.floor((waktu - (major * 86400)) / 28800)
	return major .. minor
end

ESX.IsBatchExpired = function(batch, limit)
	local major = math.floor(batch / 10) * 86400
	local minor = math.fmod(batch, 10) * 28800
	local time = major + minor
	if os.time() - time > limit then
		return true
	else
		return false
	end
end

ESX.GetExpiredTime = function(batch, limit)
	local major = math.floor(batch / 10) * 86400
	local minor = math.fmod(batch, 10) * 28800
	local time = major + minor
	local remain = limit - (os.time() - time)
	return remain
end

ESX.CopyTable = function(data)
	local newTable = {}
	for key, value in pairs(data) do
		if type(value) == 'table' then
			newTable[key] = ESX.CopyTable(value)
		else
			newTable[key] = value
		end
	end
	return newTable
end

ESX.RandomString = function(length)
	if not length or length <= 0 then return '' end
	local charset = {}  do -- [0-9a-zA-Z]
		for c = 48, 57  do table.insert(charset, string.char(c)) end
		for c = 65, 90  do table.insert(charset, string.char(c)) end
		for c = 97, 122 do table.insert(charset, string.char(c)) end
	end
	math.randomseed(os.clock()^5)
	return ESX.RandomString(length - 1) .. charset[math.random(1, #charset)]
end

ESX.Game.GetVehicleProperties = function(entityHandle)
	if DoesEntityExist(entityHandle) then
		local colorPrimary, colorSecondary = GetVehicleColours(entityHandle)
		local pearlescentColor, wheelColor = GetVehicleExtraColours(entityHandle)

		--[[
		local vehicleModel = GetEntityModel(entityHandle)
		local vehicleLabel, extras = GetLabelText(GetDisplayNameFromVehicleModel(vehicleModel)), {}

		if vehicleLabel == 'NULL' then vehicleLabel = GetDisplayNameFromVehicleModel(vehicleModel) end

		for extraId=0, 12 do
			if DoesExtraExist(entityHandle, extraId) then
				local state = IsVehicleExtraTurnedOn(entityHandle, extraId) == 1
				extras[tostring(extraId)] = state
			end
		end
		]]

		return {
			model             = vehicleModel,
			--label             = vehicleLabel,
			label             = 'Unknown Vehicle Label',

			plate             = ESX.Math.Trim(GetVehicleNumberPlateText(entityHandle)),
			plateIndex        = GetVehicleNumberPlateTextIndex(entityHandle),

			bodyHealth        = math.round(GetVehicleBodyHealth(entityHandle), 1),
			engineHealth      = math.round(GetVehicleEngineHealth(entityHandle), 1),
			petrolTankHealth  = math.round(GetVehiclePetrolTankHealth(entityHandle), 1),

			--fuelLevel         = math.round(GetVehicleFuelLevel(entityHandle), 1),
			dirtLevel         = math.round(GetVehicleDirtLevel(entityHandle), 1),
			color1            = colorPrimary,
			color2            = colorSecondary,

			pearlescentColor  = pearlescentColor,
			wheelColor        = wheelColor,

			wheels            = GetVehicleWheelType(entityHandle),
			windowTint        = GetVehicleWindowTint(entityHandle),

			--[[
			xenonColor        = GetVehicleXenonLightsColour(entityHandle),

			neonEnabled       = {
				IsVehicleNeonLightEnabled(entityHandle, 0),
				IsVehicleNeonLightEnabled(entityHandle, 1),
				IsVehicleNeonLightEnabled(entityHandle, 2),
				IsVehicleNeonLightEnabled(entityHandle, 3)
			},

			neonColor         = {GetVehicleNeonLightsColour(entityHandle)},
			extras            = extras,
			tyreSmokeColor    = {GetVehicleTyreSmokeColor(entityHandle)},

			modSpoilers       = GetVehicleMod(entityHandle, 0),
			modFrontBumper    = GetVehicleMod(entityHandle, 1),
			modRearBumper     = GetVehicleMod(entityHandle, 2),
			modSideSkirt      = GetVehicleMod(entityHandle, 3),
			modExhaust        = GetVehicleMod(entityHandle, 4),
			modFrame          = GetVehicleMod(entityHandle, 5),
			modGrille         = GetVehicleMod(entityHandle, 6),
			modHood           = GetVehicleMod(entityHandle, 7),
			modFender         = GetVehicleMod(entityHandle, 8),
			modRightFender    = GetVehicleMod(entityHandle, 9),
			modRoof           = GetVehicleMod(entityHandle, 10),

			modEngine         = GetVehicleMod(entityHandle, 11),
			modBrakes         = GetVehicleMod(entityHandle, 12),
			modTransmission   = GetVehicleMod(entityHandle, 13),
			modHorns          = GetVehicleMod(entityHandle, 14),
			modSuspension     = GetVehicleMod(entityHandle, 15),
			modArmor          = GetVehicleMod(entityHandle, 16),

			modTurbo          = IsToggleModOn(entityHandle, 18),
			modSmokeEnabled   = IsToggleModOn(entityHandle, 20),
			modXenon          = IsToggleModOn(entityHandle, 22),

			modFrontWheels    = GetVehicleMod(entityHandle, 23),
			modBackWheels     = GetVehicleMod(entityHandle, 24),

			modPlateHolder    = GetVehicleMod(entityHandle, 25),
			modVanityPlate    = GetVehicleMod(entityHandle, 26),
			modTrimA          = GetVehicleMod(entityHandle, 27),
			modOrnaments      = GetVehicleMod(entityHandle, 28),
			modDashboard      = GetVehicleMod(entityHandle, 29),
			modDial           = GetVehicleMod(entityHandle, 30),
			modDoorSpeaker    = GetVehicleMod(entityHandle, 31),
			modSeats          = GetVehicleMod(entityHandle, 32),
			modSteeringWheel  = GetVehicleMod(entityHandle, 33),
			modShifterLeavers = GetVehicleMod(entityHandle, 34),
			modAPlate         = GetVehicleMod(entityHandle, 35),
			modSpeakers       = GetVehicleMod(entityHandle, 36),
			modTrunk          = GetVehicleMod(entityHandle, 37),
			modHydrolic       = GetVehicleMod(entityHandle, 38),
			modEngineBlock    = GetVehicleMod(entityHandle, 39),
			modAirFilter      = GetVehicleMod(entityHandle, 40),
			modStruts         = GetVehicleMod(entityHandle, 41),
			modArchCover      = GetVehicleMod(entityHandle, 42),
			modAerials        = GetVehicleMod(entityHandle, 43),
			modTrimB          = GetVehicleMod(entityHandle, 44),
			modTank           = GetVehicleMod(entityHandle, 45),
			modWindows        = GetVehicleMod(entityHandle, 46),
			modStandardLivery = GetVehicleMod(entityHandle, 48),
			]]
			modLivery         = GetVehicleLivery(entityHandle),
			--bulletProofTyres  = not GetVehicleTyresCanBurst(entityHandle)
		}
	else
		return
	end
end

-- https://raw.githubusercontent.com/citizenfx/fivem/master/ext/natives/rpc_spec_natives.lua RPC native list

ESX.Game.SetVehicleProperties = function(entityHandle, props)
	if DoesEntityExist(entityHandle) then
		local colorPrimary, colorSecondary = GetVehicleColours(entityHandle)
		local pearlescentColor, wheelColor = GetVehicleExtraColours(entityHandle)
		--SetVehicleModKit(entityHandle, 0)

		if props.plate then SetVehicleNumberPlateText(entityHandle, props.plate) end -- rpc native
		--if props.plateIndex then SetVehicleNumberPlateTextIndex(entityHandle, props.plateIndex) end
		if props.bodyHealth then SetVehicleBodyHealth(entityHandle, props.bodyHealth + 0.0) end -- rpc native
		--if props.engineHealth then SetVehicleEngineHealth(entityHandle, props.engineHealth + 0.0) end
		--if props.petrolTankHealth then SetVehiclePetrolTankHealth(entityHandle, props.petrolTankHealth + 0.0) end

		if props.fuelLevel then
			--SetVehicleFuelLevel(entityHandle, props.fuelLevel + 0.0)
			--DecorSetFloat(entityHandle, "_FUEL_LEVEL", props.fuelLevel + 0.0) --need this for LegacyFuel setup
		end

		if props.dirtLevel then SetVehicleDirtLevel(entityHandle, props.dirtLevel + 0.0) end -- rpc native
		if props.color1 then SetVehicleColours(entityHandle, props.color1, colorSecondary) end -- rpc native
		if props.color2 then SetVehicleColours(entityHandle, props.color1 or colorPrimary, props.color2) end -- rpc native

		--[[
			--if props.pearlescentColor then SetVehicleExtraColours(entityHandle, props.pearlescentColor, wheelColor) end
			--if props.wheelColor then SetVehicleExtraColours(entityHandle, props.pearlescentColor or pearlescentColor, props.wheelColor) end
			--if props.wheels then SetVehicleWheelType(entityHandle, props.wheels) end
			--if props.windowTint then SetVehicleWindowTint(entityHandle, props.windowTint) end

			if props.neonEnabled then
				SetVehicleNeonLightEnabled(entityHandle, 0, props.neonEnabled[1])
				SetVehicleNeonLightEnabled(entityHandle, 1, props.neonEnabled[2])
				SetVehicleNeonLightEnabled(entityHandle, 2, props.neonEnabled[3])
				SetVehicleNeonLightEnabled(entityHandle, 3, props.neonEnabled[4])
			end

			if props.extras then
				for extraId,enabled in pairs(props.extras) do
					if enabled then
						SetVehicleExtra(entityHandle, tonumber(extraId), 0)
					else
						SetVehicleExtra(entityHandle, tonumber(extraId), 1)
					end
				end
			end

			if props.bulletProofTyres ~= nil then SetVehicleTyresCanBurst(entityHandle, not props.bulletProofTyres) end
			if props.neonColor then SetVehicleNeonLightsColour(entityHandle, props.neonColor[1], props.neonColor[2], props.neonColor[3]) end
			if props.xenonColor then SetVehicleXenonLightsColour(entityHandle, props.xenonColor) end
			if props.modSmokeEnabled then ToggleVehicleMod(entityHandle, 20, true) end
			if props.tyreSmokeColor then SetVehicleTyreSmokeColor(entityHandle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3]) end
			if props.modSpoilers then SetVehicleMod(entityHandle, 0, props.modSpoilers, false) end
			if props.modFrontBumper then SetVehicleMod(entityHandle, 1, props.modFrontBumper, false) end
			if props.modRearBumper then SetVehicleMod(entityHandle, 2, props.modRearBumper, false) end
			if props.modSideSkirt then SetVehicleMod(entityHandle, 3, props.modSideSkirt, false) end
			if props.modExhaust then SetVehicleMod(entityHandle, 4, props.modExhaust, false) end
			if props.modFrame then SetVehicleMod(entityHandle, 5, props.modFrame, false) end
			if props.modGrille then SetVehicleMod(entityHandle, 6, props.modGrille, false) end
			if props.modHood then SetVehicleMod(entityHandle, 7, props.modHood, false) end
			if props.modFender then SetVehicleMod(entityHandle, 8, props.modFender, false) end
			if props.modRightFender then SetVehicleMod(entityHandle, 9, props.modRightFender, false) end
			if props.modRoof then SetVehicleMod(entityHandle, 10, props.modRoof, false) end
			if props.modEngine then SetVehicleMod(entityHandle, 11, props.modEngine, false) end
			if props.modBrakes then SetVehicleMod(entityHandle, 12, props.modBrakes, false) end
			if props.modTransmission then SetVehicleMod(entityHandle, 13, props.modTransmission, false) end
			if props.modHorns then SetVehicleMod(entityHandle, 14, props.modHorns, false) end
			if props.modSuspension then SetVehicleMod(entityHandle, 15, props.modSuspension, false) end
			if props.modArmor then SetVehicleMod(entityHandle, 16, props.modArmor, false) end
			if props.modTurbo then ToggleVehicleMod(entityHandle,  18, props.modTurbo) end
			if props.modXenon then ToggleVehicleMod(entityHandle,  22, props.modXenon) end
			if props.modFrontWheels then SetVehicleMod(entityHandle, 23, props.modFrontWheels, false) end
			if props.modBackWheels then SetVehicleMod(entityHandle, 24, props.modBackWheels, false) end
			if props.modPlateHolder then SetVehicleMod(entityHandle, 25, props.modPlateHolder, false) end
			if props.modVanityPlate then SetVehicleMod(entityHandle, 26, props.modVanityPlate, false) end
			if props.modTrimA then SetVehicleMod(entityHandle, 27, props.modTrimA, false) end
			if props.modOrnaments then SetVehicleMod(entityHandle, 28, props.modOrnaments, false) end
			if props.modDashboard then SetVehicleMod(entityHandle, 29, props.modDashboard, false) end
			if props.modDial then SetVehicleMod(entityHandle, 30, props.modDial, false) end
			if props.modDoorSpeaker then SetVehicleMod(entityHandle, 31, props.modDoorSpeaker, false) end
			if props.modSeats then SetVehicleMod(entityHandle, 32, props.modSeats, false) end
			if props.modSteeringWheel then SetVehicleMod(entityHandle, 33, props.modSteeringWheel, false) end
			if props.modShifterLeavers then SetVehicleMod(entityHandle, 34, props.modShifterLeavers, false) end
			if props.modAPlate then SetVehicleMod(entityHandle, 35, props.modAPlate, false) end
			if props.modSpeakers then SetVehicleMod(entityHandle, 36, props.modSpeakers, false) end
			if props.modTrunk then SetVehicleMod(entityHandle, 37, props.modTrunk, false) end
			if props.modHydrolic then SetVehicleMod(entityHandle, 38, props.modHydrolic, false) end
			if props.modEngineBlock then SetVehicleMod(entityHandle, 39, props.modEngineBlock, false) end
			if props.modAirFilter then SetVehicleMod(entityHandle, 40, props.modAirFilter, false) end
			if props.modStruts then SetVehicleMod(entityHandle, 41, props.modStruts, false) end
			if props.modArchCover then SetVehicleMod(entityHandle, 42, props.modArchCover, false) end
			if props.modAerials then SetVehicleMod(entityHandle, 43, props.modAerials, false) end
			if props.modTrimB then SetVehicleMod(entityHandle, 44, props.modTrimB, false) end
			if props.modTank then SetVehicleMod(entityHandle, 45, props.modTank, false) end
			if props.modWindows then SetVehicleMod(entityHandle, 46, props.modWindows, false) end

			if props.modLivery then SetVehicleLivery(entityHandle, props.modLivery) end
			if props.modStandardLivery then SetVehicleMod(entityHandle, 48, props.modStandardLivery, false) end
		]]
	end
end
