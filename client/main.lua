local isPaused, isDead, pickups = false, false, {}

CreateThread(function()
	while true do
		Citizen.Wait(0)

		if NetworkIsPlayerActive(PlayerId()) then
			TriggerServerEvent('esx:onPlayerJoined')
			break
		end
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(playerData)
	ESX.PlayerLoaded = true
	ESX.PlayerData = playerData
	
	-- Removed some unnecessary statement here checking if you were Michael, it did nothing really.
	-- Was also kind of broken because anyone who has a SP save no using Michael wouldn't even get it.

	local playerPed = PlayerPedId()

	if Config.EnablePvP then
		SetCanAttackFriendly(playerPed, true, false)
		NetworkSetFriendlyFireOption(true)
	end

	-- Using spawnmanager now to spawn the player, this is the right way to do it, and it transitions better.
	spawnPlayer({
		x = playerData.coords.x,
		y = playerData.coords.y,
		z = playerData.coords.z,
		heading = playerData.coords.heading,
		model = Config.DefaultPlayerModel,
		skipFade = true
	}, function()
		TriggerServerEvent('esx:onPlayerSpawn')
		TriggerEvent('esx:onPlayerSpawn')
		TriggerEvent('esx:restoreLoadout')
		StartServerSyncLoops()
	end)
	TriggerEvent('esx:loadingScreenOff')
end)

RegisterNetEvent('esx:setName')
AddEventHandler('esx:setName', function(newName) ESX.SetPlayerData('name', newName) end)

RegisterNetEvent('esx:setGroups')
AddEventHandler('esx:setGroups', function(groups) ESX.PlayerData.groups = groups end)

RegisterNetEvent('esx:setMaxWeight')
AddEventHandler('esx:setMaxWeight', function(newMaxWeight) ESX.PlayerData.maxWeight = newMaxWeight end)

AddEventHandler('esx:onPlayerSpawn', function() isDead = false end)
AddEventHandler('esx:onPlayerDeath', function() isDead = true end)

AddEventHandler('skinchanger:modelLoaded', function()
	while not ESX.PlayerLoaded do
		Citizen.Wait(100)
	end

	TriggerEvent('esx:restoreLoadout')
end)

AddEventHandler('esx:restoreLoadout', function()
	local playerPed = PlayerPedId()
	local ammoTypes = {}
	RemoveAllPedWeapons(playerPed, true)

	for k,v in pairs(ESX.PlayerData.loadout) do
		local weaponName = v.name

		GiveWeaponToPed(playerPed, weaponName, 0, false, false)
		SetPedWeaponTintIndex(playerPed, weaponName, v.tintIndex)

		local ammoType = GetPedAmmoTypeFromWeapon(playerPed, weaponName)

		for k2,v2 in pairs(v.components) do
			local componentHash = ESX.GetWeaponComponent(weaponName, v2).hash
			GiveWeaponComponentToPed(playerPed, weaponName, componentHash)
		end

		if not ammoTypes[ammoType] then
			AddAmmoToPed(playerPed, weaponName, v.ammo)
			ammoTypes[ammoType] = true
		end
	end
end)

RegisterNetEvent('esx:setAccountMoney')
AddEventHandler('esx:setAccountMoney', function(account)
	for k,v in pairs(ESX.PlayerData.accounts) do
		if v.name == account.name then
			ESX.PlayerData.accounts[k] = account
			break
		end
	end

	if Config.EnableHud then
		ESX.UI.HUD.UpdateElement('account_' .. account.name, {
			money = ESX.Math.GroupDigits(account.money)
		})
	end
end)

RegisterNetEvent('esx:addInventoryItem')
AddEventHandler('esx:addInventoryItem', function(item, count, showNotification, newItem)
	local found = false

	for k,v in pairs(ESX.PlayerData.inventory) do
		if v.name == item then
			ESX.UI.ShowInventoryItemNotification(true, v.label, count - v.count)
			ESX.PlayerData.inventory[k].count = count

			found = true
			break
		end
	end

	-- If the item wasn't found in your inventory -> run
	if(found == false and newItem --[[Just a check if there is a newItem]])then
		-- Add item newItem to the players inventory
		ESX.PlayerData.inventory[#ESX.PlayerData.inventory + 1] = newItem

		-- Show a notification that a new item was added
		ESX.UI.ShowInventoryItemNotification(true, newItem.label, count)
	else
		-- Don't show this error for now
		-- print("^1[gigneMode]^7 Error: there is an error while trying to add an item to the inventory, item name: " .. item)
	end

	if showNotification then
		ESX.UI.ShowInventoryItemNotification(true, item, count)
	end

	if ESX.UI.Menu.IsOpen('default', 'es_extended', 'inventory') then
		ESX.ShowInventory()
	end
end)

RegisterNetEvent('esx:removeInventoryItem')
AddEventHandler('esx:removeInventoryItem', function(item, count, showNotification, batch)
	for k,v in pairs(ESX.PlayerData.inventory) do
		if v.name == item then
			ESX.UI.ShowInventoryItemNotification(false, v.label, v.count - count)
			ESX.PlayerData.inventory[k].count = count
			if batch then
				ESX.PlayerData.inventory[k].batch = batch
			end
			break
		end
	end

	if showNotification then
		ESX.UI.ShowInventoryItemNotification(false, item, count)
	end

	if ESX.UI.Menu.IsOpen('default', 'es_extended', 'inventory') then
		ESX.ShowInventory()
	end
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

RegisterNetEvent('esx:addWeapon')
AddEventHandler('esx:addWeapon', function(weaponName, ammo)
	-- Removed PlayerPedId() from being stored in a variable, not needed
	-- when it's only being used once, also doing it in a few
	-- functions below this one
	GiveWeaponToPed(PlayerPedId(), weaponName, ammo, false, false)
end)

RegisterNetEvent('esx:addWeaponComponent')
AddEventHandler('esx:addWeaponComponent', function(weaponName, weaponComponent)
	local componentHash = ESX.GetWeaponComponent(weaponName, weaponComponent).hash
	GiveWeaponComponentToPed(PlayerPedId(), weaponName, componentHash)
end)

RegisterNetEvent('esx:setWeaponAmmo')
AddEventHandler('esx:setWeaponAmmo', function(weaponName, weaponAmmo)
	SetPedAmmo(PlayerPedId(), weaponName, weaponAmmo)
end)

RegisterNetEvent('esx:setWeaponTint')
AddEventHandler('esx:setWeaponTint', function(weaponName, weaponTintIndex)
	SetPedWeaponTintIndex(PlayerPedId(), weaponName, weaponTintIndex)
end)

RegisterNetEvent('esx:removeWeapon')
AddEventHandler('esx:removeWeapon', function(weaponName, ammo)
	local playerPed = PlayerPedId()
	RemoveWeaponFromPed(playerPed, weaponName)
	if ammo then
		local pedAmmo = GetAmmoInPedWeapon(playerPed, weaponName)
		local finalAmmo = math.floor(pedAmmo - ammo)
		SetPedAmmo(playerPed, weaponName, finalAmmo)
	else
		SetPedAmmo(playerPed, weaponName, 0) -- remove leftover ammo
	end
end)

RegisterNetEvent('esx:removeWeaponComponent')
AddEventHandler('esx:removeWeaponComponent', function(weaponName, weaponComponent)
	local componentHash = ESX.GetWeaponComponent(weaponName, weaponComponent).hash
	RemoveWeaponComponentFromPed(PlayerPedId(), weaponName, componentHash)
end)

RegisterNetEvent('esx:teleport')
AddEventHandler('esx:teleport', function(coords)
	-- The coords x, y and z were having 0.0 added to them here to make them floats
	-- Since we are forcing vectors in the teleport function now we don't need to do it
	ESX.Game.Teleport(PlayerPedId(), coords)
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	if Config.EnableHud then
		ESX.UI.HUD.UpdateElement('job', {
			job_label   = job.label,
			grade_label = job.grade_label
		})
	end
end)

RegisterNetEvent('esx:spawnVehicle')
AddEventHandler('esx:spawnVehicle', function(vehicle)
	if IsModelInCdimage(vehicle) then
		local playerPed = PlayerPedId()
		local playerCoords, playerHeading = GetEntityCoords(playerPed), GetEntityHeading(playerPed)

		ESX.Game.SpawnVehicle(vehicle, playerCoords, playerHeading, function(vehicle)
			TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
		end)
	else
		TriggerEvent('chat:addMessage', { args = { '^1SYSTEM', 'Invalid vehicle model.' } })
	end
end)

-- Removed drawing pickups here immediately and decided to add them to a table instead
-- Also made createMissingPickups use the other pickup function instead of having the
-- same code twice, further down we cull pickups when not needed

function AddPickup(pickupId, pickupLabel, pickupCoords, pickupType, pickupName, pickupComponents, pickupTint)
	pickups[pickupId] = {
		label = pickupLabel,
		textRange = false,
		coords = pickupCoords,
		type = pickupType,
		name = pickupName,
		components = pickupComponents,
		tint = pickupTint,
		object = nil,
		deleteNow = false
	}
end

RegisterNetEvent('esx:createPickup')
AddEventHandler('esx:createPickup', function(pickupId, label, playerId, pickupType, name, components, tintIndex, isInfinity, pickupCoords)
	local playerPed, entityCoords, forward, objectCoords
	
	if isInfinity then
		objectCoords = pickupCoords
	else
		playerPed = GetPlayerPed(GetPlayerFromServerId(playerId))
		entityCoords = GetEntityCoords(playerPed)
		forward = GetEntityForwardVector(playerPed)
		objectCoords = (entityCoords + forward * 1.0)
	end

	AddPickup(pickupId, label, objectCoords, pickupType, name, components, tintIndex)
end)

RegisterNetEvent('esx:createMissingPickups')
AddEventHandler('esx:createMissingPickups', function(missingPickups)
	for pickupId, pickup in pairs(missingPickups) do
		AddPickup(pickupId, pickup.label, vec(pickup.coords.x, pickup.coords.y, pickup.coords.z), pickup.type, pickup.name, pickup.components, pickup.tintIndex)
	end
end)

RegisterNetEvent('esx:registerSuggestions')
AddEventHandler('esx:registerSuggestions', function(registeredCommands)
	for name,command in pairs(registeredCommands) do
		if command.suggestion then
			TriggerEvent('chat:addSuggestion', ('/%s'):format(name), command.suggestion.help, command.suggestion.arguments)
		end
	end
end)

RegisterNetEvent('esx:removePickup')
AddEventHandler('esx:removePickup', function(id)
	local pickup = pickups[id]
	if pickup and pickup.object then
		ESX.Game.DeleteObject(pickup.object)
		if pickup.type == 'item_weapon' then
			RemoveWeaponAsset(pickup.name)
		else
			SetModelAsNoLongerNeeded(Config.DefaultPickupModel)
		end
		pickup.deleteNow = true
	end
end)

RegisterNetEvent('esx:deleteVehicle')
AddEventHandler('esx:deleteVehicle', function(radius)
	local playerPed = PlayerPedId()

	if radius and tonumber(radius) then
		radius = tonumber(radius) + 0.01
		local vehicles = ESX.Game.GetVehiclesInArea(GetEntityCoords(playerPed), radius)

		for k,entity in pairs(vehicles) do
			local attempt = 0

			while not NetworkHasControlOfEntity(entity) and attempt < 100 and DoesEntityExist(entity) do
				Citizen.Wait(100)
				NetworkRequestControlOfEntity(entity)
				attempt = attempt + 1
			end

			if DoesEntityExist(entity) and NetworkHasControlOfEntity(entity) then
				ESX.Game.DeleteVehicle(entity)
			end
		end
	else
		local vehicle, attempt = ESX.Game.GetVehicleInDirection(), 0

		if IsPedInAnyVehicle(playerPed, true) then
			vehicle = GetVehiclePedIsIn(playerPed, false)
		end

		while not NetworkHasControlOfEntity(vehicle) and attempt < 100 and DoesEntityExist(vehicle) do
			Citizen.Wait(100)
			NetworkRequestControlOfEntity(vehicle)
			attempt = attempt + 1
		end

		if DoesEntityExist(vehicle) and NetworkHasControlOfEntity(vehicle) then
			ESX.Game.DeleteVehicle(vehicle)
		end
	end
end)

-- Start Anti Cheat
AddEventHandler('onClientResourceStart', function (resourceName)
	if ESX.PlayerLoaded then TriggerServerEvent('onClientResourceStart', resourceName) end
end)

AddEventHandler('onClientResourceStop', function (resourceName)
	if ESX.PlayerLoaded then TriggerServerEvent('onClientResourceStop', resourceName) end
end)
-- End Anti Cheat

-- Pause menu disables HUD display
if Config.EnableHud then
	CreateThread(function()
		while true do
			Citizen.Wait(300)

			if IsPauseMenuActive() and not isPaused then
				isPaused = true
				ESX.UI.HUD.SetDisplay(0.0)
			elseif not IsPauseMenuActive() and isPaused then
				isPaused = false
				ESX.UI.HUD.SetDisplay(1.0)
			end
		end
	end)

	AddEventHandler('esx:loadingScreenOff', function()
		ESX.UI.HUD.SetDisplay(1.0)
	end)
end

CreateThread(function()
	while true do
		Citizen.Wait(0)

		if IsControlJustReleased(0, 289) then
			if IsInputDisabled(0) and not isDead and not ESX.UI.Menu.IsOpen('default', 'es_extended', 'inventory') then
				ESX.ShowInventory()
			end
		end
	end
end)

-- Disable wanted level
if Config.DisableWantedLevel then
	-- Previous they were creating a contstantly running loop to check if the wanted level
	-- changed and then setting back to 0. This is all thats needed to disable a wanted level.
	SetMaxWantedLevel(0)
end

-- Pickups
CreateThread(function()
	while true do
		Citizen.Wait(0)
		local playerPed = PlayerPedId()
		local playerCoords, letSleep = GetEntityCoords(playerPed), true
		-- For whatever reason there was a constant check to get the closest player here when it
		-- wasn't even being used
		
		-- Major refactor here, this culls the pickups if not within range.

		for pickupId, pickup in pairs(pickups) do
			local distance = #(playerCoords - pickup.coords)
			if pickup.deleteNow then
				pickup = nil
			else
				if distance < 50 then
					if not DoesEntityExist(pickup.object) then
						letSleep = false
						if pickup.type == 'item_weapon' then
							ESX.Streaming.RequestWeaponAsset(pickup.name)
							pickup.object = CreateWeaponObject(pickup.name, 50, pickup.coords, true, 1.0, 0)
							SetWeaponObjectTintIndex(pickup.object, pickup.tint)

							for _, comp in pairs(pickup.components) do
								local component = ESX.GetWeaponComponent(pickup.name, comp)
								GiveWeaponComponentToWeaponObject(pickup.object, component.hash)
							end
							
							SetEntityAsMissionEntity(pickup.object, true, false)
							PlaceObjectOnGroundProperly(pickup.object)
							SetEntityRotation(pickup.object, 90.0, 0.0, 0.0)
							local model = GetEntityModel(pickup.object)
							local heightAbove = GetEntityHeightAboveGround(pickup.object)
							local currentCoords = GetEntityCoords(pickup.object)
							local modelDimensionMin, modelDimensionMax = GetModelDimensions(model)
							local size = (modelDimensionMax.y - modelDimensionMin.y) / 2
							SetEntityCoords(pickup.object, currentCoords.x, currentCoords.y, (currentCoords.z - heightAbove) + size)
						else
							ESX.Game.SpawnLocalObject(Config.DefaultPickupModel, pickup.coords, function(obj)
								pickup.object = obj
							end)

							while not pickup.object do
								Citizen.Wait(10)
							end
							
							SetEntityAsMissionEntity(pickup.object, true, false)
							PlaceObjectOnGroundProperly(pickup.object)
						end

						FreezeEntityPosition(pickup.object, true)
						SetEntityCollision(pickup.object, false, true)
					end
				else
					if DoesEntityExist(pickup.object) then
						DeleteObject(pickup.object)
						if pickup.type == 'item_weapon' then
							RemoveWeaponAsset(pickup.name)
						else
							SetModelAsNoLongerNeeded(Config.DefaultPickupModel)
						end
					end
				end
				
				if distance < 5 then
					local label = pickup.label
					letSleep = false

					if distance < 1 then
						if IsControlJustReleased(0, 38) then
							-- Removed the closestDistance check here, not needed
							if IsPedOnFoot(playerPed) and not pickup.textRange then
								pickup.textRange = true

								local dict, anim = 'weapons@first_person@aim_rng@generic@projectile@sticky_bomb@', 'plant_floor'
								-- Lets use our new function instead of manually doing it
								ESX.Game.PlayAnim(dict, anim, true, 1000)
								Citizen.Wait(1000)

								TriggerServerEvent('esx:onPickup', pickupId)
								PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', false)
							end
						end

						label = ('%s~n~%s'):format(label, _U('standard_pickup_prompt'))
					end
					
					local pickupCoords = GetEntityCoords(pickup.object)
					ESX.Game.Utils.DrawText3D(vec(pickupCoords.x, pickupCoords.y, pickupCoords.z + 0.5), label, 1.2, 4)
				elseif pickup.textRange then
					pickup.textRange = false
				end
			end
		end

		if letSleep then
			Citizen.Wait(500)
		end
	end
end)

function StartServerSyncLoops()
	-- keep track of ammo
	Citizen.CreateThread(function()
		while true do
			Citizen.Wait(0)

			if isDead then
				Citizen.Wait(500)
			else
				local playerPed = PlayerPedId()

				if IsPedShooting(playerPed) then
					local _,weaponHash = GetCurrentPedWeapon(playerPed, true)
					local weapon = ESX.GetWeaponFromHash(weaponHash)

					if weapon then
						local ammoCount = GetAmmoInPedWeapon(playerPed, weaponHash)
						TriggerServerEvent('esx:updateWeaponAmmo', weapon.name, ammoCount)
					end
				end
			end
		end
	end)

	-- sync current player coords with server
	Citizen.CreateThread(function()
		local previousCoords = vector3(ESX.PlayerData.coords.x, ESX.PlayerData.coords.y, ESX.PlayerData.coords.z)

		while true do
			Citizen.Wait(1000)
			local playerPed = PlayerPedId()

			if DoesEntityExist(playerPed) then
				local playerCoords = GetEntityCoords(playerPed)
				local distance = #(playerCoords - previousCoords)

				if distance > 1 then
					previousCoords = playerCoords
					local playerHeading = math.round(GetEntityHeading(playerPed), 1)
					local formattedCoords = {x = math.round(playerCoords.x, 1), y = math.round(playerCoords.y, 1), z = math.round(playerCoords.z, 1), heading = playerHeading}
					TriggerServerEvent('esx:updateCoords', formattedCoords)
				end
			end
		end
	end)
end