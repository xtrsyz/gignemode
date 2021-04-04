RegisterNetEvent('esx:onPlayerJoined')
AddEventHandler('esx:onPlayerJoined', function()
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(playerId)

	if xPlayer then
		print(('[ESX] [^3WARNING^7] Player id "%s^7" who already is connected has been called ^3onPlayerJoined^7 on. ' ..
			'Will save player and query new character from database.'):format(playerId))

		ESX.SavePlayer(xPlayer, function()
			ESX.Players[playerId] = nil
			onPlayerJoined(playerId)
		end)
	else
		onPlayerJoined(playerId)
	end
end)

function onPlayerJoined(playerId)
	local identifier
	local license
	
	for k,v in pairs(GetPlayerIdentifiers(playerId)) do
		if string.match(v, Config.PrimaryIdentifier) then
			identifier = v
		end
		if string.match(v, 'license:') then
			license = v
		end
	end

	if identifier then
		if ESX.GetPlayerFromIdentifier(identifier) then
			DropPlayer(playerId, ('there was an error loading your character!\nError code: identifier-active-ingame\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s'):format(identifier))
		else
			MySQL.Async.fetchScalar('SELECT 1 FROM users WHERE identifier = @identifier', {
				['@identifier'] = identifier
			}, function(result)
				if result then
					loadESXPlayer(identifier, playerId)
				else
					local accounts = {}

					for account,money in pairs(Config.StartingAccountMoney) do
						accounts[account] = money
					end

					MySQL.Async.execute('INSERT INTO users (accounts, identifier, license) VALUES (@accounts, @identifier, @license)', {
						['@accounts'] = json.encode(accounts),
						['@identifier'] = identifier,
						['@license'] = license,						
					}, function(rowsChanged)
						loadESXPlayer(identifier, playerId)
						TriggerEvent('esx:onPlayerCreated', playerId)
					end)
				end
			end)
		end
	else
		DropPlayer(playerId, 'there was an error loading your character!\nError code: identifier-missing-ingame\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.')
	end
end

AddEventHandler('playerConnecting', function(name, setCallback, deferrals)
	deferrals.defer()
	local playerId, identifier = source
	Citizen.Wait(100)

	for k,v in pairs(GetPlayerIdentifiers(playerId)) do
		if string.match(v, Config.PrimaryIdentifier) then
			identifier = v
			break
		end
	end

	if not ESX.DatabaseReady then
		deferrals.update("The database is not initialized, please wait...")
		while not ESX.DatabaseReady do
			Citizen.Wait(1000)
		end
	end

	if identifier then
		if ESX.GetPlayerFromIdentifier(identifier) then
			deferrals.done(('There was an error loading your character!\nError code: identifier-active\n\nThis error is caused by a player on this server who has the same identifier as you have. Make sure you are not playing on the same Rockstar account.\n\nYour Rockstar identifier: %s'):format(identifier))
		else
			deferrals.done()
		end
	else
		deferrals.done('There was an error loading your character!\nError code: identifier-missing\n\nThe cause of this error is not known, your identifier could not be found. Please come back later or report this problem to the server administration team.')
	end
end)


function loadESXPlayer(identifier, playerId)
	local tasks = {}
	local batch = {}
	local batchCount = {}
	local userData = {
		playerId = playerId,
		identifier = identifier,
		accounts = {},
		inventory = {},
		job = {},
		loadout = {},
		playerName = GetPlayerName(playerId),
		weight = 0
	}

	table.insert(tasks, function(cb)
		MySQL.Async.fetchAll('SELECT * FROM user_batch WHERE identifier = @identifier', {
			['@identifier'] = identifier
		}, function(result)
			for _,value in pairs(result) do
				if not batch[value.name] then 
					batch[value.name] = {}
					batchCount[value.name] = 0
				end
				batch[value.name][value.batch] = {count = value.count, info = json.decode(value.info)}
				batchCount[value.name] = batchCount[value.name] + value.count
			end
			cb()
		end)
	end)

	table.insert(tasks, function(cb)
		MySQL.Async.fetchAll([===[
			SELECT accounts, job, job_grade, groups, loadout, position, inventory,
				name, skin, status, health
			FROM users 
			WHERE identifier = @identifier
		]===], {
			['@identifier'] = identifier
		}, function(result)
			local job, grade, jobObject, gradeObject = result[1].job, tostring(result[1].job_grade)
			local foundAccounts, foundItems = {}, {}
			local health = json.encode(result[1].health)

			userData.name = result[1].name
			userData.health = health.health
			userData.armour = health.armour

			-- Skin
			if result[1].skin and result[1].skin ~= '' then
				local skin = json.decode(result[1].skin)

				if skin then
					userData.skin = skin
				end
			end

			-- Status
			if result[1].status and result[1].status ~= '' then
				local status = json.decode(result[1].status)

				if status then
					userData.status = status
				end
			end

			-- Accounts
			if result[1].accounts and result[1].accounts ~= '' then
				local accounts = json.decode(result[1].accounts)

				for account,money in pairs(accounts) do
					foundAccounts[account] = money
				end
			end

			for account,label in pairs(Config.Accounts) do
				table.insert(userData.accounts, {
					name = account,
					money = foundAccounts[account] or Config.StartingAccountMoney[account] or 0,
					label = label
				})
			end

			-- Job
			if ESX.DoesJobExist(job, grade) then
				jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]
			else
				print(('[gigneMode] [^3WARNING^7] Ignoring invalid job for %s [job: %s, grade: %s]'):format(identifier, job, grade))
				job, grade = 'unemployed', '0'
				jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]
			end

			userData.job.id = jobObject.id
			userData.job.name = jobObject.name
			userData.job.label = jobObject.label

			userData.job.grade = tonumber(grade)
			userData.job.grade_name = gradeObject.name
			userData.job.grade_label = gradeObject.label
			userData.job.grade_salary = gradeObject.salary

			userData.job.skin_male = {}
			userData.job.skin_female = {}

			if gradeObject.skin_male then userData.job.skin_male = json.decode(gradeObject.skin_male) end
			if gradeObject.skin_female then userData.job.skin_female = json.decode(gradeObject.skin_female) end

			-- Inventory
			if result[1].inventory and result[1].inventory ~= '' then
				local inventory = json.decode(result[1].inventory)

				for name,count in pairs(inventory) do
					local item = ESX.Items[name]

					if item then
						foundItems[name] = count
					else
						print(('[gigneMode] [^3WARNING^7] Ignoring invalid item "%s" for "%s"'):format(name, identifier))
					end
				end
			end

			for name,item in pairs(ESX.Items) do
				local count = foundItems[name] or 0
				if count > 0 then
					userData.weight = userData.weight + (item.weight * count)
					local newItem = {}
					for key,val in pairs(item) do
						newItem[key] = val
					end
					newItem.count = count
					newItem.usable = ESX.UsableItemsCallbacks[name] ~= nil
					table.insert(userData.inventory, newItem)
				end
			end

			table.sort(userData.inventory, function(a, b)
				return a.label < b.label
			end)

			-- Groups
			if result[1].groups and result[1].groups ~= '' then
				local groups = json.decode(result[1].groups)
				userData.groups = groups
			else
				userData.groups = {['user'] = true}
			end

			-- Loadout
			if result[1].loadout and result[1].loadout ~= '' then
				local loadout = json.decode(result[1].loadout)

				for name,weapon in pairs(loadout) do
					local label = ESX.GetWeaponLabel(name)

					if label then
						if not weapon.components then weapon.components = {} end
						if not weapon.tintIndex then weapon.tintIndex = 0 end

						table.insert(userData.loadout, {
							name = name,
							ammo = weapon.ammo,
							quality = weapon.quality,
							serial = weapon.serial,
							label = label,
							components = weapon.components,
							tintIndex = weapon.tintIndex
						})
					end
				end
			end

			-- Position
			if result[1].position and result[1].position ~= '' then
				userData.coords = json.decode(result[1].position)
			else
				print('[gigneMode] [^3WARNING^7] Column "position" in "users" table is missing required default value. Using backup coords, fix your database.')
				userData.coords = Config.FirstSpawnCoords
			end

			cb()
		end)
	end)

	Async.parallel(tasks, function(results)
		ESX.LastInventory[playerId] = {}
		for k,v in pairs(userData.inventory) do
			if batch[v.name] then
				v.batch = batch[v.name]
				v.batchCount = batchCount[v.name]
			else
				v.batch = {}
				v.batchCount = 0
			end
			ESX.LastInventory[playerId][v.name] = {count = v.count, batch = ESX.CopyTable(v.batch)}
		end

		local xPlayer = CreateESXPlayer(userData)
		ESX.Players[playerId] = xPlayer
		TriggerEvent('esx:playerLoaded', playerId, xPlayer)

		xPlayer.triggerEvent('esx:playerLoaded', {
			inventory = xPlayer.getInventory(false, true),
			maxWeight = xPlayer.getMaxWeight(),
			loadout = xPlayer.getLoadout(),
			accounts = xPlayer.getAccounts(false, true),
			coords = xPlayer.coords,
			identifier = xPlayer.getIdentifier(),
			job = xPlayer.getJob(),
			money = xPlayer.getMoney(), -- deprecated
			skin = xPlayer.getSkin(),
			status = xPlayer.getStatus()
		})

		xPlayer.triggerEvent('esx:setGroups', userData.groups)
		xPlayer.triggerEvent('esx:createMissingPickups', ESX.Pickups)
		xPlayer.triggerEvent('esx:registerSuggestions', ESX.RegisteredCommands)
		print(('[gigneMode] [^2INFO^7] A player with name "%s^7" has connected to the server with assigned player id %s'):format(xPlayer.getName(), playerId))
	end)
end

-- Start Anti Cheat
ESX.Resources = {}
ESX.AntiCheat = true

Citizen.CreateThread(function()
	for k,v in pairs(Config.Resources) do
		ESX.Resources[v] = true;
	end
end)
	
AddEventHandler('onResourceStart', function(resourceName)
	ESX.Resources[resourceName] = true;
end)

AddEventHandler('onResourceStop', function (resourceName)
	ESX.AntiCheat = false
	ESX.Resources[resourceName] = false;
	Citizen.CreateThread(function()
		Citizen.Wait(3000)
		ESX.AntiCheat = true
	end)
end)

RegisterServerEvent('onClientResourceStart')
AddEventHandler('onClientResourceStart', function (resourceName)
	if not ESX.Resources[resourceName] then
		print('The resource ' .. resourceName .. ' has been started on the client.')
		TriggerEvent('gigne:antiCheat', source, 'onClientResourceStart: ' .. resourceName .. ' has been started on the client.')
	end
end)

RegisterServerEvent('onClientResourceStop')
AddEventHandler('onClientResourceStop', function (resourceName)
	if ESX.AntiCheat and ESX.Resources[resourceName] then
		print('The resource ' .. resourceName .. ' has been stopped on the client.')
		TriggerEvent('gigne:antiCheat', source, 'onClientResourceStop: ' .. resourceName .. ' has been stopped on the client.')
	end
end)

ESX.RegisterCommand('reslist', 'admin', function(xPlayer, args, showError)
	for k,v in pairs(ESX.Resources) do
		print('-- ' .. k)
	end
end, false, {help = ''})
-- End Anti Cheat

AddEventHandler('playerDropped', function(reason)
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(playerId)
	local identifier = xPlayer.getIdentifier()

	if xPlayer then
		TriggerEvent('esx:playerDropped', playerId, reason)

		ESX.SavePlayer(xPlayer, function()
			ESX.LastInventory[identifier] = nil
			ESX.Players[playerId] = nil
		end)
	end
end)

RegisterNetEvent('esx:updateCoords')
AddEventHandler('esx:updateCoords', function(coords)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer then
		xPlayer.updateCoords(coords)
	end
end)

RegisterNetEvent('esx:updateHealth')
AddEventHandler('esx:updateHealth', function(health, armour)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer then
		if type(health) == 'number' and type(armour) == 'number' then
			xPlayer.updateHealth(health, armour)
		end
	end
end)

RegisterNetEvent('esx:updateWeaponAmmo')
AddEventHandler('esx:updateWeaponAmmo', function(weaponName, ammoCount)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer then
		xPlayer.updateWeaponAmmo(weaponName, ammoCount)
	end
end)

RegisterNetEvent('esx:giveInventoryItem')
AddEventHandler('esx:giveInventoryItem', function(target, type, itemName, itemCount, item)
	local playerId = source
	local sourceXPlayer = ESX.GetPlayerFromId(playerId)
	local targetXPlayer = ESX.GetPlayerFromId(target)

	local targetName, sourceName
	if Config.HidePlayerName then
		targetName = "Someone"
		sourceName = "Someone"
	else
		targetName = targetXPlayer.name
		sourceName = sourceXPlayer.name
	end

	if type == 'item_standard' then
		local sourceItem = sourceXPlayer.getInventoryItem(itemName)
		local targetItem = targetXPlayer.getInventoryItem(itemName)

		if itemCount > 0 and sourceItem.count >= itemCount then
			if targetXPlayer.canCarryItem(itemName, itemCount) then

				local batchInfo = item and item.info or false
				local batchNumber = item and item.batch or false
				sourceXPlayer.removeInventoryItem(itemName, itemCount, batchNumber)
				targetXPlayer.addInventoryItem   (itemName, itemCount, batchInfo)

				sourceXPlayer.showNotification(_U('gave_item', itemCount, sourceItem.label, targetName))
				targetXPlayer.showNotification(_U('received_item', itemCount, sourceItem.label, sourceName))
			else
				sourceXPlayer.showNotification(_U('ex_inv_lim', targetName))
			end
		else
			sourceXPlayer.showNotification(_U('imp_invalid_quantity'))
		end
	elseif type == 'item_account' then
		if itemCount > 0 and sourceXPlayer.getAccount(itemName).money >= itemCount then
			sourceXPlayer.removeAccountMoney(itemName, itemCount)
			targetXPlayer.addAccountMoney   (itemName, itemCount)

			sourceXPlayer.showNotification(_U('gave_account_money', ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName], targetName))
			targetXPlayer.showNotification(_U('received_account_money', ESX.Math.GroupDigits(itemCount), Config.Accounts[itemName], sourceName))
		else
			sourceXPlayer.showNotification(_U('imp_invalid_amount'))
		end
	elseif type == 'item_weapon' then
		if sourceXPlayer.hasWeapon(itemName) then
			local weaponLabel = ESX.GetWeaponLabel(itemName)

			if not targetXPlayer.hasWeapon(itemName) then
				local _, weapon = sourceXPlayer.getWeapon(itemName)
				local _, weaponObject = ESX.GetWeapon(itemName)
				itemCount = weapon.ammo

				sourceXPlayer.removeWeapon(itemName)
				targetXPlayer.addWeapon(itemName, itemCount)

				if weaponObject.ammo and itemCount > 0 then
					local ammoLabel = weaponObject.ammo.label
					sourceXPlayer.showNotification(_U('gave_weapon_withammo', weaponLabel, itemCount, ammoLabel, targetName))
					targetXPlayer.showNotification(_U('received_weapon_withammo', weaponLabel, itemCount, ammoLabel, sourceName))
				else
					sourceXPlayer.showNotification(_U('gave_weapon', weaponLabel, targetName))
					targetXPlayer.showNotification(_U('received_weapon', weaponLabel, sourceName))
				end
			else
				sourceXPlayer.showNotification(_U('gave_weapon_hasalready', targetName, weaponLabel))
				targetXPlayer.showNotification(_U('received_weapon_hasalready', sourceName, weaponLabel))
			end
		end
	elseif type == 'item_ammo' then
		if sourceXPlayer.hasWeapon(itemName) then
			local weaponNum, weapon = sourceXPlayer.getWeapon(itemName)

			if targetXPlayer.hasWeapon(itemName) then
				local _, weaponObject = ESX.GetWeapon(itemName)

				if weaponObject.ammo then
					local ammoLabel = weaponObject.ammo.label

					if weapon.ammo >= itemCount then
						sourceXPlayer.removeWeaponAmmo(itemName, itemCount)
						targetXPlayer.addWeaponAmmo(itemName, itemCount)

						sourceXPlayer.showNotification(_U('gave_weapon_ammo', itemCount, ammoLabel, weapon.label, targetName))
						targetXPlayer.showNotification(_U('received_weapon_ammo', itemCount, ammoLabel, weapon.label, sourceName))
					end
				end
			else
				sourceXPlayer.showNotification(_U('gave_weapon_noweapon', targetName))
				targetXPlayer.showNotification(_U('received_weapon_noweapon', sourceName, weapon.label))
			end
		end
	end
end)

RegisterNetEvent('esx:removeInventoryItem')
AddEventHandler('esx:removeInventoryItem', function(type, itemName, itemCount, item)
	local playerId = source
	local xPlayer = ESX.GetPlayerFromId(source)
	local batchNumber = item and item.batch or false
	local itemInfo = item and item.info or false
	if type == 'item_standard' then
		if itemCount == nil or itemCount < 1 then
			xPlayer.showNotification(_U('imp_invalid_quantity'))
		else
			local xItem = xPlayer.getInventoryItem(itemName)

			if (itemCount > xItem.count or xItem.count < 1) then
				xPlayer.showNotification(_U('imp_invalid_quantity'))
			else
				xPlayer.removeInventoryItem(itemName, itemCount, batchNumber)
				local pickupLabel = ('~y~%s~s~ [~b~%s~s~]'):format(xItem.label, itemCount)
				ESX.CreatePickup('item_standard', itemName, itemCount, pickupLabel, playerId, nil, nil, itemInfo)
				xPlayer.showNotification(_U('threw_standard', itemCount, xItem.label))
			end
		end
	elseif type == 'item_account' then
		if itemCount == nil or itemCount < 1 then
			xPlayer.showNotification(_U('imp_invalid_amount'))
		else
			local account = xPlayer.getAccount(itemName)

			if (itemCount > account.money or account.money < 1) then
				xPlayer.showNotification(_U('imp_invalid_amount'))
			else
				xPlayer.removeAccountMoney(itemName, itemCount)
				local pickupLabel = ('~y~%s~s~ [~g~%s~s~]'):format(account.label, _U('locale_currency', ESX.Math.GroupDigits(itemCount)))
				ESX.CreatePickup('item_account', itemName, itemCount, pickupLabel, playerId)
				xPlayer.showNotification(_U('threw_account', ESX.Math.GroupDigits(itemCount), string.lower(account.label)))
			end
		end
	elseif type == 'item_weapon' then
		itemName = string.upper(itemName)
		local _, weapon = xPlayer.getWeapon(itemName)
		local _, weaponObject = ESX.GetWeapon(itemName)
		local pickupLabel

		if itemInfo and itemInfo.serial ~= weapon.serial then
			local xItem = xPlayer.getInventoryItem(itemName)

			if (itemCount > xItem.count or xItem.count < 1) then
				xPlayer.showNotification(_U('imp_invalid_quantity'))
			else
				xPlayer.removeInventoryItem(itemName, itemCount, batchNumber)
				if weaponObject.ammo and xItem.count > 0 then
					local ammoLabel = weaponObject.ammo.label
					pickupLabel = ('~y~%s~s~ [~g~%s~s~]'):format(xItem.label, xItem.count)
					xPlayer.showNotification(_U('threw_weapon_ammo', xItem.label, xItem.count, ammoLabel))
				else
					pickupLabel = ('~y~%s~s~'):format(xItem.label)
					xPlayer.showNotification(_U('threw_weapon', xItem.label))
				end

				ESX.CreatePickup('item_weapon', itemName, xItem.count, pickupLabel, playerId, itemInfo.components, itemInfo.tintIndex, itemInfo)
			end
		else
			if xPlayer.hasWeapon(itemName) then
				xPlayer.removeWeapon(itemName)
				if weaponObject.ammo and weapon.ammo > 0 then
					local ammoLabel = weaponObject.ammo.label
					pickupLabel = ('~y~%s~s~ [~g~%s~s~]'):format(weapon.label, weapon.ammo)
					xPlayer.showNotification(_U('threw_weapon_ammo', weapon.label, weapon.ammo, ammoLabel))
				else
					pickupLabel = ('~y~%s~s~'):format(weapon.label)
					xPlayer.showNotification(_U('threw_weapon', weapon.label))
				end
				itemInfo = {batch = weapon.serial, quality = weapon.quality, serial = weapon.serial, count = weapon.ammo, components = weapon.components, tintIndex = weapon.tintIndex}
				ESX.CreatePickup('item_weapon', itemName, weapon.ammo, pickupLabel, playerId, weapon.components, weapon.tintIndex, itemInfo)
			end
		end		
	end
end)

RegisterNetEvent('esx:useItem')
AddEventHandler('esx:useItem', function(itemName, item)
	local xPlayer = ESX.GetPlayerFromId(source)
	local count = xPlayer.getInventoryItem(itemName).count
	local batchNumber = item and item.batch or nil
	xPlayer.set('removeBatch', batchNumber)

	if count > 0 then
		ESX.UseItem(source, itemName, batchNumber)
	else
		xPlayer.showNotification(_U('act_imp'))
	end
end)

RegisterNetEvent('esx:onPickup')
AddEventHandler('esx:onPickup', function(id)
	local pickup, xPlayer, success = ESX.Pickups[id], ESX.GetPlayerFromId(source)

	if pickup then
		if pickup.type == 'item_standard' then
			if xPlayer.canCarryItem(pickup.name, pickup.count) then
				xPlayer.addInventoryItem(pickup.name, pickup.count, pickup.batch)
				success = true
			else
				xPlayer.showNotification(_U('threw_cannot_pickup'))
			end
		elseif pickup.type == 'item_account' then
			success = true
			xPlayer.addAccountMoney(pickup.name, pickup.count)
		elseif pickup.type == 'item_weapon' then
			if xPlayer.hasWeapon(pickup.name) then
				xPlayer.showNotification(_U('threw_weapon_already'))
			else
				success = true
				xPlayer.addWeapon(pickup.name, pickup.count, pickup.batch)
				xPlayer.setWeaponTint(pickup.name, pickup.tintIndex)

				for k,v in pairs(pickup.components) do
					xPlayer.addWeaponComponent(pickup.name, v)
				end
			end
		end

		if success then
			ESX.Pickups[id] = nil
			TriggerClientEvent('esx:removePickup', -1, id)
		end
	end
end)

ESX.RegisterServerCallback('esx:getPlayerData', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		loadout      = xPlayer.getLoadout(),
		money        = xPlayer.getMoney()
	})
end)

ESX.RegisterServerCallback('esx:getOtherPlayerData', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	cb({
		identifier   = xPlayer.identifier,
		accounts     = xPlayer.getAccounts(),
		inventory    = xPlayer.getInventory(),
		job          = xPlayer.getJob(),
		loadout      = xPlayer.getLoadout(),
		money        = xPlayer.getMoney()
	})
end)

ESX.RegisterServerCallback('esx:getPlayerNames', function(source, cb, players)
	players[source] = nil

	for playerId,v in pairs(players) do
		local xPlayer = ESX.GetPlayerFromId(playerId)

		if xPlayer then
			players[playerId] = xPlayer.getName()
		else
			players[playerId] = nil
		end
	end

	cb(players)
end)

ESX.RegisterServerCallback('esx:spawnVehicle', function(playerId, cb, model, coords, heading)
	local entityHandle = Citizen.InvokeNative(GetHashKey('CREATE_AUTOMOBILE'), model, coords, heading)
	cb(NetworkGetNetworkIdFromEntity(entityHandle))
end)

AddEventHandler("esx:setAccountMoney", function(user, value, detail) ESX.GetPlayerFromId(user).setAccountMoney(value, detail) end)
AddEventHandler("esx:addAccountMoney", function(user, value, detail) ESX.GetPlayerFromId(user).addAccountMoney(value, detail) end)
AddEventHandler("esx:removeAccountMoney", function(user, value, detail) ESX.GetPlayerFromId(user).addAccountMoney(value, detail) end)

-- Add support for EssentialMode >6.4.x
AddEventHandler("es:setMoney", function(user, value) ESX.GetPlayerFromId(user).setMoney(value, true) end)
AddEventHandler("es:addMoney", function(user, value) ESX.GetPlayerFromId(user).addMoney(value, true) end)
AddEventHandler("es:removeMoney", function(user, value) ESX.GetPlayerFromId(user).removeMoney(value, true) end)
AddEventHandler("es:set", function(user, key, value) ESX.GetPlayerFromId(user).set(key, value, true) end)

AddEventHandler("es_db:doesUserExist", function(identifier, cb)
	cb(true)
end)

AddEventHandler('es_db:retrieveUser', function(identifier, cb, tries)
	tries = tries or 0

	if(tries < 500)then
		tries = tries + 1
		local player = ESX.GetPlayerFromIdentifier(identifier)

		if player then
			cb({permission_level = 0, money = player.getMoney(), bank = 0, identifier = player.identifier, license = player.get("license"), group = player.group, roles = ""}, false, true)
		else
			Citizen.SetTimeout(100, function()
				TriggerEvent("es_db:retrieveUser", identifier, cb, tries)
			end)
		end
	end
end)
