function CreateESXPlayer(userData)
	local self = {}

	self.accounts = userData.accounts
	self.coords = userData.coords
	self.identifier = userData.identifier
	self.inventory = userData.inventory
	self.job = userData.job
	self.loadout = userData.loadout
	self.playerId = userData.playerId
	self.source = userData.playerId -- deprecated, use playerId instead!
	self.variables = {}
	self.weight = userData.weight
	self.maxWeight = Config.MaxWeight

	self.health = userData.health
	self.armour = userData.armour
	self.name = userData.name
	self.skin = userData.skin
	self.status = userData.status
	self.phoneNumber = userData.phoneNumber
	self.groups = userData.groups

	for group,v in pairs(self.groups) do
		ExecuteCommand(('add_principal identifier.%s group.%s'):format(self.identifier, group))
	end

	self.triggerEvent = function(eventName, ...)
		TriggerClientEvent(eventName, self.source, ...)
	end

	self.logEvent = function(eventName, ...)
		TriggerEvent(eventName, self.source, ...)
	end

	self.setCoords = function(coords)
		self.updateCoords(coords)
		self.triggerEvent('esx:teleport', coords)
	end

	self.updateCoords = function(coords)
		self.coords = {x = math.round(coords.x, 1), y = math.round(coords.y, 1), z = math.round(coords.z, 1), heading = math.round(coords.heading or 0.0, 1)}
	end

	self.getCoords = function(vector)
		local playerPed = GetPlayerPed(self.playerId)
		local playerCoords = GetEntityCoords(playerPed)

		if playerCoords then
			if vector then
				return ESX.Math.FormatCoordsTable(playerCoords, 'vector3')
			else
				return ESX.Math.FormatCoordsTable(playerCoords, 'table')
			end
		else
			if vector then
				return vector3(self.coords.x, self.coords.y, self.coords.z)
			else
				return self.coords
			end
		end
	end

	self.kick = function(reason)
		DropPlayer(self.source, reason)
	end

	self.getBank = function()
		return self.getAccount('bank').money
	end

	self.removeBank = function(money, detail)
		self.removeAccountMoney('bank', money, detail)
	end

	self.addBank = function(money, detail)
		self.addAccountMoney('bank', money, detail)
	end

	self.setMoney = function(money, recursion)
		money = math.round(money)
		self.setAccountMoney('money', money, recursion)

		if(recursion ~= true)then
			TriggerEvent("es:getPlayerFromId", self.source, function(user) user.setMoney(money) end)
		end
	end

	self.getMoney = function() return self.getAccount('money').money end

	self.addMoney = function(money, recursion)
		money = math.round(money)
		self.addAccountMoney('money', money, recursion)

		if(recursion ~= true)then
			TriggerEvent("es:getPlayerFromId", self.source, function(user) user.addMoney(money, true) end)
		end
	end

	self.removeMoney = function(money, recursion)
		if(recursion ~= true)then
			TriggerEvent("es:getPlayerFromId", self.source, function(user) user.removeMoney(money, true) end)
		end

		money = math.round(money)
		self.removeAccountMoney('money', money, recursion)
	end

	self.getAccountBalance = function(accountName)
		local account = self.getAccount(accountName)

		if account then
			return account.money
		else
			return 0
		end
	end

	self.getIdentifier = function(steamDec)
		if steamDec then
			return tonumber(string.sub(self.identifier, 7, -1), 16)
		else
			return self.identifier
		end
	end

	self.addGroup = function(group)
		if self.groups[group] then
			return false
		else
			self.groups[group] = true
			self.triggerEvent('esx:setGroups', self.groups)
			ExecuteCommand(('add_principal identifier.%s group.%s'):format(self.identifier, group))
			return true
		end
	end

	self.removeGroup = function(group)
		if self.groups[group] then
			if group == 'user' then
				return false
			else
				self.groups[group] = nil
				self.triggerEvent('esx:setGroups', self.groups)
				ExecuteCommand(('remove_principal identifier.%s group.%s'):format(self.identifier, group))
				return true
			end
		else
			return false
		end
	end

	self.getGroups = function() return self.groups end

	self.set = function(k, v, recursion)
		if(recursion ~= true)then
			TriggerEvent("es:getPlayerFromId", self.source, function(user) if(user)then user.set(k, v) end end)
		end

		self.variables[k] = v
	end

	self.get = function(k) return self.variables[k] end

	self.getAccounts = function(minimal, keyValue)
		if minimal then
			local minimalAccounts = {}

			for k,v in ipairs(self.accounts) do
				minimalAccounts[v.name] = v.money
			end

			return minimalAccounts
		elseif keyValue then
			local minimalAccounts = {}

			for k,v in ipairs(self.accounts) do
				minimalAccounts[v.name] = v
			end

			return minimalAccounts
		else
			return self.accounts
		end
	end

	self.getAccount = function(account)
		for k,v in ipairs(self.accounts) do
			if v.name == account then
				return v
			end
		end
	end

	self.getInventory = function(minimal, keyValue)
		if minimal then
			local minimalInventory = {}

			for k,v in ipairs(self.inventory) do
				if v.count > 0 then
					minimalInventory[v.name] = v.count
				end
			end

			return minimalInventory
		elseif keyValue then
			local minimalInventory = {}

			for k,v in ipairs(self.inventory) do
				minimalInventory[v.name] = v
			end

			return minimalInventory
		else
			return self.inventory
		end
	end

	self.getJob = function() return self.job end

	self.getLoadout = function(minimal)
		if minimal then
			local minimalLoadout = {}

			for k,v in ipairs(self.loadout) do
				minimalLoadout[v.name] = {ammo = v.ammo, quality = v.quality, serial = v.serial}
				if v.tintIndex > 0 then minimalLoadout[v.name].tintIndex = v.tintIndex end

				if #v.components > 0 then
					local components = {}

					for k2,component in ipairs(v.components) do
						if component ~= 'clip_default' then
							table.insert(components, component)
						end
					end

					if #components > 0 then
						minimalLoadout[v.name].components = components
					end
				end
			end

			return minimalLoadout
		else
			return self.loadout
		end
	end

	self.setAccountMoney = function(accountName, money, detail)
		if money >= 0 then
			local account = self.getAccount(accountName)

			if account then
				local prevMoney = account.money
				local newMoney = math.round(money)
				account.money = newMoney

				self.triggerEvent('esx:setAccountMoney', account)
				self.logEvent('log:setAccountMoney', account, prevMoney, detail)
			end
		end
	end

	self.addAccountMoney = function(accountName, money, detail)
		if money > 0 then
			local account = self.getAccount(accountName)

			if account then
				local newMoney = account.money + math.round(money)
				account.money = newMoney

				self.triggerEvent('esx:setAccountMoney', account)
				self.logEvent('log:addAccountMoney', account, money, detail)
			end
		end
	end

	self.removeAccountMoney = function(accountName, money, detail)
		if money > 0 then
			local account = self.getAccount(accountName)

			if account then
				local newMoney = account.money - math.round(money)
				account.money = newMoney

				self.triggerEvent('esx:setAccountMoney', account)
				self.logEvent('log:removeAccountMoney', account, money, detail)
			end
		end
	end

	self.getInventoryItem = function(name)
		local found = false
		local newItem

		for k,v in ipairs(self.inventory) do
			if v.name == name then
				found = true
				return v
			end
		end

		-- Ran only if the item wasn't found in your inventory
		local item = ESX.Items[name]

		-- if item exists -> run
		if(item)then
			-- Create new item
			newItem = {}
			for key,val in pairs(item) do
				newItem[key] = val
			end
			newItem.count = 0
			newItem.batch = {}
			newItem.batchCount = 0
			newItem.usable = ESX.UsableItemsCallbacks[name] ~= nil

			-- Insert into players inventory
			table.insert(self.inventory, newItem)

			-- Return the item that was just added
			return newItem
		end

		return
	end

	self.hasItem = function(item) return self.getInventoryItem(item).count >= 1 end

	self.addInventoryItem = function(name, count, itemBatch)
		local item = self.getInventoryItem(name)

		if item then
			count = math.round(count)
			item.count = item.count + count
			if itemBatch then
				if not itemBatch.batch then
					itemBatch.batch = ESX.GetBatch()
				end
				if item.batch[itemBatch.batch] then
					item.batch[itemBatch.batch].count = item.batch[itemBatch.batch].count + count
				else
					if itemBatch.lifetime and not itemBatch.expiredtime then
						itemBatch.expiredtime = os.time() + itemBatch.lifetime
					end
					item.batch[itemBatch.batch] = {count = count, info = itemBatch}
				end
				item.batchCount = item.batchCount + count
			end
			self.weight = self.weight + (item.weight * count)

			TriggerEvent('esx:onAddInventoryItem', self.source, item.name, item.count, item.batch)
			self.triggerEvent('esx:addInventoryItem', item.name, item.count, false, item)
			return true
		end
	end

	self.removeInventoryItem = function(name, count, batchNumber)
		local item = self.getInventoryItem(name)

		if item then
			count = math.round(count)
			local newCount = item.count - count

			if newCount >= 0 then
				item.count = newCount
				batchNumber = not batchNumber and self.get('removeBatch') or batchNumber
				if batchNumber and item.batch[batchNumber] then
					local batchCount = item.batch[batchNumber].count - count
					if batchCount > 0 then
						item.batch[batchNumber].count = batchCount
					else
						item.batch[batchNumber] = nil
					end
					item.batchCount = item.batchCount - count
				end

				if newCount == 0 then
					item.batch = {}
					item.batchCount = 0
				end

				self.weight = self.weight - (item.weight * count)

				TriggerEvent('esx:onRemoveInventoryItem', self.source, item.name, item.count, batchNumber)
				self.triggerEvent('esx:removeInventoryItem', item.name, item.count, false, item.batch)
				return true
			end
		end
	end

	self.setInventoryItem = function(name, count)
		local item = self.getInventoryItem(name)

		if item and count >= 0 then
			count = math.round(count)

			if count > item.count then
				self.addInventoryItem(item.name, count - item.count)
			else
				self.removeInventoryItem(item.name, item.count - count)
			end
		end
	end

	self.getWeight = function() return self.weight end
	self.getMaxWeight = function() return self.maxWeight end

	self.canCarryItems = function(data)
		local currentWeight = self.weight
		if data then
			for _,v in pairs(data) do
				if ESX.Items[v.name].limit and ESX.Items[v.name].limit ~= -1 then
					if v.count > ESX.Items[v.name].limit then
						return false
					elseif (self.getInventoryItem(v.name).count + v.count) > ESX.Items[v.name].limit then
						return false
					end
				end
				currentWeight = currentWeight+(ESX.Items[v.name].weight*v.count)
			end
		end

		return currentWeight <= self.maxWeight
	end

	self.canCarryItem = function(name, count)
		if ESX.Items[name].limit and ESX.Items[name].limit ~= -1 then
			if count > ESX.Items[name].limit then
				return false
			elseif (self.getInventoryItem(name).count + count) > ESX.Items[name].limit then
				return false
			end
		end
		local currentWeight, itemWeight = self.weight, ESX.Items[name].weight
		local newWeight = currentWeight + (itemWeight * count)
		return newWeight <= self.maxWeight
	end

	self.canSwapItem = function(firstItem, firstItemCount, testItem, testItemCount)
		local firstItemObject = self.getInventoryItem(firstItem)
		local testItemObject = self.getInventoryItem(testItem)

		if ESX.Items[testItem].limit and ESX.Items[testItem].limit ~= -1 and testItemObject.count + testItemCount > ESX.Items[testItem].limit then
			return false
		else
			if firstItemObject.count >= firstItemCount then
				local weightWithoutFirstItem = math.round(self.weight - (firstItemObject.weight * firstItemCount))
				local weightWithTestItem = math.round(weightWithoutFirstItem + (testItemObject.weight * testItemCount))
				return weightWithTestItem <= self.maxWeight
			end
		end

		return false
	end

	-- xPlayer.canSwapItems({bread=2,meat=1}, {burger=1})
	self.canSwapItems = function(oldItems, newItems)
		local weightWithoutFirstItem, weightChangeItems = self.weight, 0
		for name,count in pairs(newItems) do
			local item = self.getInventoryItem(name)
			if ESX.Items[name].limit and ESX.Items[name].limit ~= -1 and item.count + count > ESX.Items[name].limit then
				return false
			end
			weightChangeItems = weightChangeItems + (item.weight * count)
		end

		for name,count in pairs(oldItems) do
			local item = self.getInventoryItem(name)
			if item.count >= count then				
				weightWithoutFirstItem = weightWithoutFirstItem - (item.weight * count)
			else
				return false
			end
		end

		local weightWithTestItem = math.round(weightWithoutFirstItem + weightChangeItems)
		return weightWithTestItem <= self.maxWeight
	end

	self.swapItems = function(removeItems, addItems)
		if type(removeItems) ~= 'table' then removeItems = {[removeItems] = 1} end
		if type(addItems) ~= 'table' then addItems = {[addItems] = 1} end
		if self.canSwapItems(removeItems, addItems) then
			for name,count in pairs(removeItems) do
				self.removeInventoryItem(name, count)
			end
			for name,count in pairs(addItems) do
				self.addInventoryItem(name, count)
			end
			return true
		end
		return false
	end

	self.setMaxWeight = function(newWeight)
		self.maxWeight = newWeight
		self.triggerEvent('esx:setMaxWeight', self.maxWeight)
	end

	self.setJob = function(job, grade)
		grade = tostring(grade)
		local lastJob = json.decode(json.encode(self.job))

		if ESX.DoesJobExist(job, grade) then
			local jobObject, gradeObject = ESX.Jobs[job], ESX.Jobs[job].grades[grade]

			self.job.id    = jobObject.id
			self.job.name  = jobObject.name
			self.job.label = jobObject.label

			self.job.grade        = tonumber(grade)
			self.job.grade_name   = gradeObject.name
			self.job.grade_label  = gradeObject.label
			self.job.grade_salary = gradeObject.salary

			if gradeObject.skin_male then
				self.job.skin_male = json.decode(gradeObject.skin_male)
			else
				self.job.skin_male = {}
			end

			if gradeObject.skin_female then
				self.job.skin_female = json.decode(gradeObject.skin_female)
			else
				self.job.skin_female = {}
			end

			TriggerEvent('esx:setJob', self.source, self.job, lastJob)
			self.triggerEvent('esx:setJob', self.job)
		else
			print(('[gigneMode] [^3WARNING^7] Ignoring invalid .setJob() usage for "%s"'):format(self.identifier))
		end
	end

	self.addWeapon = function(weaponName, ammo, itemInfo)
		if not self.hasWeapon(weaponName) then
			local weaponLabel = ESX.GetWeaponLabel(weaponName)
			local quality = itemInfo and itemInfo.quality or 100
			local serial = itemInfo and itemInfo.serial or ESX.RandomString(8)

			table.insert(self.loadout, {
				name = weaponName,
				ammo = ammo,
				quality = quality,
				batch = serial,
				serial = serial,
				label = weaponLabel,
				components = {},
				tintIndex = 0
			})

			self.triggerEvent('esx:addWeapon', weaponName, ammo)
			self.showInventoryItemNotification(weaponLabel, true)
		else
			self.addInventoryItem(weaponName, ammo, itemInfo)
		end
	end

	self.addWeaponComponent = function(weaponName, weaponComponent)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			local component = ESX.GetWeaponComponent(weaponName, weaponComponent)

			if component then
				if not self.hasWeaponComponent(weaponName, weaponComponent) then
					table.insert(self.loadout[loadoutNum].components, weaponComponent)
					self.triggerEvent('esx:addWeaponComponent', weaponName, weaponComponent)
					self.showInventoryItemNotification(component.label, true)
				end
			end
		end
	end

	self.addWeaponAmmo = function(weaponName, ammoCount)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			weapon.ammo = weapon.ammo + ammoCount
			self.triggerEvent('esx:setWeaponAmmo', weaponName, weapon.ammo)
		end
	end

	self.removeWeaponAmmo = function(weaponName, ammoCount)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			weapon.ammo = weapon.ammo - ammoCount
			self.triggerEvent('esx:setWeaponAmmo', weaponName, weapon.ammo)
		end
	end

	self.updateWeaponAmmo = function(weaponName, ammoCount)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			if ammoCount < weapon.ammo then
				weapon.ammo = ammoCount
			end
		end
	end

	self.updateWeaponQuality = function(weaponName, quality)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			weapon.quality = quality
		end
	end

	self.setWeaponTint = function(weaponName, weaponTintIndex)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			local weaponNum, weaponObject = ESX.GetWeapon(weaponName)

			if weaponObject.tints and weaponObject.tints[weaponTintIndex] then
				self.loadout[loadoutNum].tintIndex = weaponTintIndex
				self.triggerEvent('esx:setWeaponTint', weaponName, weaponTintIndex)
				self.showInventoryItemNotification(weaponObject.tints[weaponTintIndex], true)
			end
		end
	end

	self.getWeaponTint = function(weaponName)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			return weapon.tintIndex
		end

		return 0
	end

	self.removeWeapon = function(weaponName, ammo)
		local weaponLabel

		if self.loadout[weaponName] ~= nil then
			weaponLabel = self.loadout[weaponName].label

			for k2,v2 in ipairs(self.loadout[weaponName].components) do
				self.removeWeaponComponent(weaponName, v2)
			end

			self.loadout[weaponName] = nil

			self.triggerEvent('esx:removeWeapon', weaponName, ammo)
			self.showInventoryItemNotification(weaponLabel, false)
		end
	end

	self.removeWeaponComponent = function(weaponName, weaponComponent)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			local component = ESX.GetWeaponComponent(weaponName, weaponComponent)

			if component then
				if self.hasWeaponComponent(weaponName, weaponComponent) then
					for k,v in ipairs(self.loadout[weaponName].components) do
						if v == weaponComponent then
							table.remove(self.loadout[weaponName].components, k)
							break
						end
					end

					self.triggerEvent('esx:removeWeaponComponent', weaponName, weaponComponent)
					self.showInventoryItemNotification(component.label, false)
				end
			end
		end
	end

	self.hasWeaponComponent = function(weaponName, weaponComponent)
		local weapon = self.getWeapon(weaponName)

		if weapon then
			for k,v in ipairs(weapon.components) do
				if v == weaponComponent then
					return true
				end
			end

			return false
		else
			return false
		end
	end

	self.hasWeapon = function(weaponName)
		if self.loadout[weaponName] then
			return true
		else
			return false
		end
	end

	self.getWeapon = function(weaponName) return self.loadout[weaponName] end
	self.showNotification = function(msg, flash, saveToBrief, hudColorIndex) self.triggerEvent('esx:showNotification', msg, flash, saveToBrief, hudColorIndex) end
	self.showHelpNotification = function(msg, thisFrame, beep, duration) self.triggerEvent('esx:showHelpNotification', msg, thisFrame, beep, duration) end
	self.showAdvancedNotification = function(sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex) self.triggerEvent('esx:showAdvancedNotification', sender, subject, msg, textureDict, iconType, flash, saveToBrief, hudColorIndex) end
	self.showInventoryItemNotification = function(msg, add) self.triggerEvent('esx:showInventoryItemNotification', msg, add) end
	self.save = function(cb) ESX.SavePlayer(self, cb) end

	self.isAceAllowed = function(object) return IsPlayerAceAllowed(self.playerId, object) end

	self.getName = function() return self.name end

	self.setName = function(_name)
		self.name = _name
		TriggerEvent('esx:setName', self.playerId, self.name)
	end

	self.getHealth = function() return self.health end
	self.getArmour = function() return self.armour end
	self.setArmour = function(newArmour)
		self.armour = newArmour
		self.triggerEvent('esx:setArmour', self.armour)
	end	
	self.updateHealth = function(_health, _armour)
		self.health = _health
		self.armour = _armour
	end

	self.setSkin = function(newSkin) self.skin = newSkin end
	self.getSkin = function() return self.skin end
	self.getStatus = function() return self.status end
	self.setStatus = function(newStatus) self.status = newStatus end
	self.getPhoneNumber = function() return self.phoneNumber end

	return self
end
