ESX = nil
local PlayerData = {}
local invOpen, isDead, isCuffed, currentWeapon = false, false, false, nil
local vehStorage = {}
local usingItem = false

function setVehicleTable()
	local vehicleTable = {['adder']=1, ['osiris']=0, ['pfister811']=0, ['penetrator']=0, ['autarch']=0, ['bullet']=0, ['cheetah']=0, ['cyclone']=0, ['voltic']=0, ['reaper']=1, ['entityxf']=0, ['t20']=0, ['taipan']=0, ['tezeract']=0, ['torero']=1, ['turismor']=0, ['fmj']=0, ['infernus ']=0, ['italigtb']=1, ['italigtb2']=1, ['nero2']=0, ['vacca']=1, ['vagner']=0, ['visione']=0, ['prototipo']=0, ['zentorno']=0}
	--[[
		0 = vehicle has no storage
		1 = vehicle storage is in bonnet/hood
	]]
	for k, v in pairs(vehicleTable) do
	getHash = GetHashKey(k)
	vehStorage[getHash] = v
	end
end
setVehicleTable()

-- hsn inventory Hasan.#7803
Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj)
			ESX = obj
		end)
		Citizen.Wait(10)
	end
	while ESX.GetPlayerData().job == nil do
		Citizen.Wait(10)
	end
	PlayerData = ESX.GetPlayerData()
	playerID = GetPlayerServerId(PlayerId())
	ESX.TriggerServerCallback('hsn-inventory:getData',function(data)
		playerName = data.name
		ESX.SetPlayerData('inventory', data.inventory)
		oneSync = data.oneSync
	end)
	while not playerName do Citizen.Wait(100) end
	playerPed = PlayerPedId()
	clearWeapons()
end)

function clearWeapons()
	SetCurrentPedWeapon(playerPed, 'WEAPON_UNARMED', true)
	for k,v in pairs(Config.DurabilityDecreaseAmount) do
		local hash = GetHashKey(k)
		SetPedAmmo(playerPed, hash, 0)
	end
	RemoveAllPedWeapons(playerPed, true)
end

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
end)

local Drops = {}
local currentDrop = nil
local currentDropCoords = nil
local keys = {
	157, 158, 160, 164, 165
}

AddEventHandler('esx:onPlayerDeath', function(data)
	isDead = true
end)

AddEventHandler('esx:onPlayerSpawn', function(spawn)
	isDead = false
end)

AddEventHandler('playerSpawned', function(spawn)
	isDead = false
end)

AddEventHandler('esx_ambulancejob:setDeathStatus', function(status)
	isDead = status
end)


RegisterNetEvent('esx_policejob:handcuff')
AddEventHandler('esx_policejob:handcuff', function()
	isCuffed = not isCuffed
end)

RegisterNetEvent('esx_policejob:unrestrain')
AddEventHandler('esx_policejob:unrestrain', function()
	isCuffed = false
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(3)
		playerPed = PlayerPedId()
		DisableControlAction(0, 37, true)
		DisableControlAction(0, 157, true) -- 1
		DisableControlAction(0, 158, true) -- 2
		DisableControlAction(0, 160, true) -- 3
		DisableControlAction(0, 164, true) -- 4
		DisableControlAction(0, 165, true) -- 5
		DisableControlAction(0, 289, true) -- F2
		for i = 19, 20 do 
			HideHudComponentThisFrame(i) -- remove tab etc.
		end
		if usingItem then
			DisableControlAction(0, 24, true)
			DisableControlAction(0, 25, true)
			DisableControlAction(0, 142, true)
			DisableControlAction(0, 257, true)
		end
		if not invOpen then
			for k, v in pairs(keys) do
				if IsDisabledControlJustReleased(0, v) and not dead and not isCuffed then
					TriggerServerEvent('hsn-inventory:server:useItemfromSlot',k)
				end
			end
		end
		if currentWeapon then
			if IsPedArmed(ped, 6) then
				DisableControlAction(1, 140, true)
				DisableControlAction(1, 141, true)
				DisableControlAction(1, 142, true)
			end
			local shooting = IsPedShooting(playerPed)
			if shooting or (currentWeapon.item.metadata.throwable and IsControlJustReleased(0, 24)) then
				local ammo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
				if ammo == 0 and (currentWeapon.item.name == 'WEAPON_FIREEXTINGUISHER' or currentWeapon.item.name == 'WEAPON_PETROLCAN') then
					ClearPedTasks(playerPed)
					SetCurrentPedWeapon(playerPed, currentWeapon.hash, true)
					SetAmmoInClip(playerPed, currentWeapon.hash, 300)
					TriggerServerEvent('hsn-inventory:server:decreasedurability', playerID, currentWeapon.slot, currentWeapon.item, 300)
				elseif currentWeapon.item.metadata.throwable then
					TriggerServerEvent('hsn-inventory:client:removeItem', currentWeapon.item.name, 1)
				else
					currentWeapon.item.metadata.ammo = ammo
					if ammo == 0 then
						ClearPedSecondaryTask(playerPed)
						SetCurrentPedWeapon(playerPed, currentWeapon.hash, true)
						TriggerServerEvent('hsn-inventory:server:reloadWeapon', currentWeapon)
					end
					--TriggerServerEvent('hsn-inventory:server:decreasedurability', currentWeapon)
				end
			else shooting = false end
		end
	end
end)


RegisterCommand('vehinv', function()
	if not playerName then return end
	if invOpen then return end
	if not isDead and not isCuffed and not IsPedInAnyVehicle(playerPed, false) then
		local vehicle = ESX.Game.GetClosestVehicle()
		local coords = GetEntityCoords(playerPed)
		if not IsPedInAnyVehicle(playerPed) then
			if GetVehicleDoorLockStatus(vehicle) ~= 2 then
				local vehHash = GetEntityModel(vehicle)
				local checkVehicle = vehStorage[vehHash]
				if checkVehicle == 1 then open, vehBone = 4, GetEntityBoneIndexByName(vehicle, 'bonnet')
				elseif checkVehicle == nil then open, vehBone = 5, GetEntityBoneIndexByName(vehicle, 'boot') elseif checkVehicle == 2 then open, vehBone = 5, GetEntityBoneIndexByName(vehicle, 'boot') else --[[no vehicle nearby]] return end
				local vehiclePos = GetWorldPositionOfEntityBone(vehicle, vehBone)
				local pedDistance = #(coords - vehiclePos)
				if (open == 5 and checkVehicle == nil) then if pedDistance < 2.0 then CloseToVehicle = true end elseif (open == 5 and checkVehicle == 2) then if pedDistance < 2.0 then CloseToVehicle = true end elseif open == 4 then if pedDistance < 2.0 then CloseToVehicle = true end end	
				if CloseToVehicle then
					local plate = GetVehicleNumberPlateText(vehicle)
					SetVehicleDoorOpen(vehicle, open, false, false)
					TaskTurnPedToFaceEntity(playerPed, vehicle, -1)
					Citizen.Wait(500)
					TaskStartScenarioInPlace(playerPed, 'PROP_HUMAN_BUM_BIN', 0, true)
					Citizen.Wait(1000)
					OpenTrunk(plate)
					while not invOpen do Citizen.Wait(50) end
					while true do
						Citizen.Wait(50)
						if CloseToVehicle and invOpen and not isCuffed and not isDead then
							coords = GetEntityCoords(playerPed)
							if checkVehicle == 1 then open, vehBone = 4, GetEntityBoneIndexByName(vehicle, 'bonnet')
							elseif checkVehicle == nil then open, vehBone = 5, GetEntityBoneIndexByName(vehicle, 'boot') elseif checkVehicle == 2 then open, vehBone = 5, GetEntityBoneIndexByName(vehicle, 'boot') else return end
							local vehiclePos = GetWorldPositionOfEntityBone(vehicle, vehBone)
							local pedDistance = #(coords - vehiclePos)
							local isClose = false
							if (open == 5 and checkVehicle == nil) then if pedDistance < 2.0 then isClose = true end elseif (open == 5 and checkVehicle == 2) then if pedDistance < 2.0 then isClose = true end elseif open == 4 then if pedDistance < 2.0 then isClose = true end end
							if DoesEntityExist(vehicle) and isClose then
								CloseToVehicle = true
							else break end
						else break end
					end
					CloseToVehicle = false
					lastVehicle = nil
					TriggerEvent('hsn-inventory:client:closeInventory')
					invOpen = false
					currentInventory = nil
					ClearPedTasks(playerPed)
					Citizen.Wait(1200)
					SetVehicleDoorShut(vehicle, open, false)
				end
			else
				TriggerEvent('hsn-inventory:notification','Vehicle is locked',2)
			end
		end
	elseif not isDead and not isCuffed and IsPedInAnyVehicle(playerPed, false) then -- [G]lovebox
		local vehicle = GetVehiclePedIsIn(playerPed, false)
		local plate = GetVehicleNumberPlateText(vehicle)
		OpenGloveBox(plate)
	end
end, false)
	
RegisterCommand('inventory', function()
	if not playerName then return end
	if not isDead and not isCuffed and not invOpen then
		TriggerEvent('randPickupAnim')
		TriggerServerEvent('hsn-inventory:server:openInventory',{type = 'drop',id = currentDrop, coords = currentDropCoords })
	end
end, false)
		
RegisterKeyMapping('inventory', 'Inv: Inventory Open', 'keyboard', 'F2')
RegisterKeyMapping('vehinv', 'Inv: Vehicle Inventory', 'keyboard', 'F3')

OpenGloveBox = function(gloveboxid)
	TriggerServerEvent('hsn-inventory:server:openInventory',{type = 'glovebox',id = 'glovebox-'..gloveboxid})
end
OpenTrunk = function(trunkid)
	TriggerServerEvent('hsn-inventory:server:openInventory',{type = 'trunk',id = 'trunk-'..trunkid})
end

RegisterNetEvent('hsn-inventory:client:openInventory')
AddEventHandler('hsn-inventory:client:openInventory',function(inventory,other)
	if not playerName then return end
	invOpen = true
	ESX.SetPlayerData('inventory', inventory)
	SendNUIMessage({
		message = 'openinventory',
		inventory = inventory,
		slots = Config.PlayerSlot,
		name = playerName..' ['.. playerID ..']',
		maxweight = Config.MaxWeight,
		rightinventory = other
	})
	if not other then movement = true else TriggerServerEvent('hsn-inventory:setcurrentInventory',other) movement = false end
	SetNuiFocusAdvanced(true, true, movement)
	currentInventory = other
end)

RegisterNetEvent('hsn-inventory:client:closeInventory')
AddEventHandler('hsn-inventory:client:closeInventory',function(id)
	invOpen = false
	currentInventory = nil
	SendNUIMessage({
		message = 'close',
	})
	SetNuiFocusAdvanced(false,false)
	TriggerServerEvent('hsn-inventory:removecurrentInventory',id)
end)

RegisterNetEvent('hsn-inventory:client:refreshInventory')
AddEventHandler('hsn-inventory:client:refreshInventory',function(inventory)
	if not playerName then return end
	SendNUIMessage({
		message = 'refresh',
		inventory = inventory,
		slots = Config.PlayerSlot,
		name = playerName..' ['.. playerID ..']',
		maxweight = Config.MaxWeight
	})
end)


RegisterNUICallback('exit',function(data)
	invOpen = false
	currentInventory = nil
	SetNuiFocusAdvanced(false,false)
	TriggerServerEvent('hsn-inventory:server:saveInventory',data)
	TriggerServerEvent('hsn-inventory:removecurrentInventory',data.invid)
end)

--- thread
Citizen.CreateThread(function()
	while true do
		local wait = 1000
		for k,v in pairs(Drops) do
			distance = #(GetEntityCoords(playerPed) - vector3(v.coords.x,v.coords.y,v.coords.z))
			if (invOpen and distance <= 1.2) or distance <= 10.0 then
				wait = 1
				DrawMarker(2, v.coords.x,v.coords.y,v.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 150, 30, 30, 222, false, false, false, true, false, false, false)
				if distance <= 1.2 then
					currentDrop = v.dropid
					currentDropCoords = v.coords
				else
					currentDrop = nil
					currentDropCoords = nil
				end
			end
		end
		if not currentInventory and invOpen and currentDrop then
			invOpen = false
			movement = false
			TriggerServerEvent('hsn-inventory:server:openInventory',{type = 'drop',id = currentDrop, coords = currentDropCoords })
		end
		Citizen.Wait(wait)
	end
end)

RegisterNetEvent('hsn-inventory:client:addItemNotify')
AddEventHandler('hsn-inventory:client:addItemNotify',function(item,text)
	SendNUIMessage({
		message = 'notify',
		item = item,
		text = text
	})
	TriggerServerEvent('hsn-inventory:server:refreshInventory')
end)


DrawText3D = function(coords, text)
	SetDrawOrigin(coords)
	SetTextScale(0.35, 0.35)
	SetTextFont(4)
	SetTextEntry('STRING')
	SetTextCentre(1)
	AddTextComponentString(text)
	DrawText(0.0, 0.0)
	DrawRect(0.0, 0.0125, 0.015 + text:gsub('~.-~', ''):len() / 370, 0.03, 45, 45, 45, 150)
	ClearDrawOrigin()
end

Citizen.CreateThread(function()
	while true do
		local sleepThread = 1000

		while not PlayerData.job do Citizen.Wait(0) end
		for i = 1, #Config.Shops do
			local text = Config.Shops[i].name
			distance = #(GetEntityCoords(PlayerPedId()) - Config.Shops[i].coords)

			if distance <= 5.5 and (not Config.Shops[i].job or Config.Shops[i].job == PlayerData.job.name) then
				sleepThread = 5
				DrawMarker(2, Config.Shops[i].coords.x,Config.Shops[i].coords.y,Config.Shops[i].coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.15, 0.2, 30, 150, 30, 100, false, false, false, true, false, false, false)
				if not invOpen then
					if distance <= 1.5 then
						text = '[~g~E~s~] ' .. Config.Shops[i].name

						if IsControlJustPressed(1,38) and not dead and not isCuffed then
							OpenShop(Config.Shops[i])
						end
					end

					DrawText3D(Config.Shops[i].coords, text)
				end
			end
		end

		for i = 1, #Config.Stashes do
			local text = Config.Stashes[i].name
			distance = #(GetEntityCoords(PlayerPedId()) - Config.Stashes[i].coords)

			if distance <= 5.5 and (not Config.Stashes[i].job or Config.Stashes[i].job == PlayerData.job.name) then
				sleepThread = 5
				DrawMarker(2, Config.Stashes[i].coords.x,Config.Stashes[i].coords.y,Config.Stashes[i].coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.15, 0.2, 30, 30, 150, 100, false, false, false, true, false, false, false)
				
				if not invOpen then
					if distance <= 1.5 then
						text = '[~g~E~s~] ' .. Config.Stashes[i].name

						if IsControlJustPressed(1,38) and not dead and not isCuffed then
							OpenStash(Config.Stashes[i])
						end
					end   

					DrawText3D(Config.Stashes[i].coords, text)
				end
			end
		end

		Citizen.Wait(sleepThread)
	end
end)

Citizen.CreateThread(function()
	while not PlayerData.job do Citizen.Wait(0) end
	for k,v in pairs(Config.Shops) do
		if (not Config.Shops[k].job or Config.Shops[k].job == PlayerData.job.name) then
			local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
			SetBlipSprite(blip, v.blip.id or 1)
			SetBlipDisplay(blip, 4)
			SetBlipScale(blip, v.blip.scale or 0.5)
			SetBlipColour(blip, v.blip.color or 1)
			SetBlipAsShortRange(blip, true)
			BeginTextCommandSetBlipName('STRING')
			AddTextComponentString(v.blip.name or 'Shop')
			EndTextCommandSetBlipName(blip)
		end
	end
end)

OpenShop = function(id)
	TriggerServerEvent('hsn-inventory:server:openInventory',{type = 'shop',id = id})
end

OpenStash = function(id)
	TriggerServerEvent('hsn-inventory:server:OpenStash', {id = id, slots = id.slots, type = 'stash'})
end

RegisterNetEvent('hsn-inventory:Client:addnewDrop')
AddEventHandler('hsn-inventory:Client:addnewDrop',function(coords, drop)
	if not oneSync then -- Receive coords as an entity if not running OneSync
		local entity = GetPlayerPed(GetPlayerFromServerId(coords))
		local pos = GetEntityCoords(entity)
		local offset = GetOffsetFromEntityInWorldCoords(entity, 0, 0.5, 0)
		coords = offset
	end
	Drops[drop] = {
		dropid = drop,
		coords = {
			x = coords.x,
			y = coords.y,
			z = coords.z - 0.3,
		},
	}
end)

function loadAnimDict( dict )
	while ( not HasAnimDictLoaded( dict ) ) do
		RequestAnimDict( dict )
		Citizen.Wait( 5 )
	end
end

RegisterNetEvent('randPickupAnim')
AddEventHandler('randPickupAnim', function()
	loadAnimDict('pickup_object')
	TaskPlayAnim(playerPed,'pickup_object', 'putdown_low',5.0, 1.5, 1.0, 48, 0.0, 0, 0, 0)
	Wait(1000)
	ClearPedSecondaryTask(playerPed)
end)


RegisterNetEvent('hsn-inventory:client:removeDrop')
AddEventHandler('hsn-inventory:client:removeDrop',function(dropid)
	Drops[dropid] = nil
	currentDrop = nil
	currentDropCoords = nil
end)

RegisterNUICallback('UseItem', function(data, cb)
	if data.inv ~= 'Playerinv' then
		return
	end
	TriggerServerEvent('hsn-inventory:server:useItem',data.item)
end)

RegisterNUICallback('saveinventorydata',function(data)
	TriggerServerEvent('hsn-inventory:server:saveInventoryData',data)
end)

RegisterNUICallback('notification', function(data)
	TriggerEvent('hsn-inventory:notification',data.message,data.type)
end)

RegisterNetEvent('hsn-inventory:weapondraw')
AddEventHandler('hsn-inventory:weapondraw', function(item)
	loadAnimDict('reaction@intimidation@1h')
	TaskPlayAnimAdvanced(playerPed, 'reaction@intimidation@1h', 'intro', GetEntityCoords(playerPed, true), 0, 0, GetEntityHeading(playerPed), 8.0, 3.0, -1, 50, 0, 0, 0)
	Citizen.Wait(800)
	if currentWeapon then SetPedAmmo(playerPed, currentWeapon.hash, 0)
	RemoveWeaponFromPed(playerPed, currentWeapon.hash)
	end
	SetCurrentPedWeapon(playerPed, 'WEAPON_UNARMED', true)
	Citizen.Wait(800)
	ClearPedSecondaryTask(playerPed)
	usingItem = false
end)

RegisterNetEvent('hsn-inventory:weaponaway')
AddEventHandler('hsn-inventory:weaponaway', function()
	loadAnimDict('reaction@intimidation@1h')
	TaskPlayAnimAdvanced(playerPed, 'reaction@intimidation@1h', 'outro', GetEntityCoords(playerPed, true), 0, 0, GetEntityHeading(playerPed), 8.0, 3.0, -1, 50, 0, 0, 0)
	SetPedAmmo(playerPed, currentWeapon.hash, 0)
	Citizen.Wait(1600)
	ClearPedSecondaryTask(playerPed)
	if IsPedUsingActionMode(playerPed) then
		SetPedUsingActionMode(playerPed, -1, -1, 1)
	end
	usingItem = false
end)

RegisterNetEvent('hsn-inventory:client:weapon')
AddEventHandler('hsn-inventory:client:weapon',function(item)
	if usingItem then return end
	usingItem = true
	if currentWeapon then TriggerServerEvent('hsn-inventory:server:updateWeapon', currentWeapon.slot, currentWeapon.item) end
	TriggerEvent('hsn-inventory:client:closeInventory')
	local newWeapon = item.metadata.weaponlicense
	local found, wepHash = GetCurrentPedWeapon(playerPed, true)
	if wepHash == -1569615261 then currentWeapon = nil end
	if item.name:find('_T_') then wepHash = GetHashKey(item.name:gsub('_T_', '_')) else wepHash = GetHashKey(item.name) end
	if currentWeapon and currentWeapon.item.metadata.weaponlicense == newWeapon then
		currentWeapon.item.metadata.ammo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
		TriggerEvent('hsn-inventory:weaponaway')
		Citizen.Wait(1600)
		RemoveWeaponFromPed(playerPed, GetHashKey(item.name))
		SetCurrentPedWeapon(playerPed, 'WEAPON_UNARMED', true)
		currentWeapon = nil
		TriggerEvent('hsn-inventory:client:addItemNotify',item,'Holstered')
	else
		TriggerEvent('hsn-inventory:weapondraw',item)
		Citizen.Wait(1600)
		currentWeapon = {}
		currentWeapon.slot = item.slot
		currentWeapon.item = item
		currentWeapon.hash = wepHash
		if item.metadata.throwable then item.metadata.ammo = 1 end
		for k,v in pairs(Config.Ammos) do
			for k2, v2 in pairs(v) do
				if v2 == currentWeapon.hash then currentWeapon.ammotype = k end
			end
		end
		GiveWeaponToPed(playerPed, wepHash, 0, false, false)
		SetCurrentPedWeapon(playerPed, wepHash, true)
		SetPedCurrentWeaponVisible(playerPed, true, false, false, false)
		if item.metadata.weapontint then SetPedWeaponTintIndex(playerPed, item.name, item.metadata.weapontint) end
		if item.metadata.components then
			for k,v in pairs(item.metadata.components) do
				local componentHash = ESX.GetWeaponComponent(item.name, v).hash
				if componentHash then GiveWeaponComponentToPed(playerPed, wepHash, componentHash) end
			end
		end
		TriggerEvent('hsn-inventory:client:addItemNotify',item,'Equipped')
		if currentWeapon.item.name == 'WEAPON_FIREEXTINGUISHER' or currentWeapon.item.name == 'WEAPON_PETROLCAN' then item.metadata.ammo = 300 end
		SetAmmoInClip(playerPed, currentWeapon.hash, item.metadata.ammo)
	end
	TriggerEvent('hsn-inventory:currentWeapon', currentWeapon) -- using for another resource
	Citizen.Wait(100)
	usingItem = false
end)

RegisterNetEvent('hsn-inventory:addAmmo')
AddEventHandler('hsn-inventory:addAmmo',function(item, ammo)
	ammo.count = ESX.Round(ammo.count)
	if currentWeapon and currentWeapon.ammotype == ammo.name and ammo.count > 0 then
		local weapon = currentWeapon.hash
		local maxAmmo = GetWeaponClipSize(weapon)
		local curAmmo = GetAmmoInPedWeapon(playerPed, weapon)
		if curAmmo > maxAmmo then
			SetPedAmmo(playerPed, weapon, maxAmmo)
		elseif curAmmo == maxAmmo then
			return
		else
			local newAmmo = 0
			if curAmmo < maxAmmo then missingAmmo = maxAmmo - curAmmo end
			if missingAmmo > ammo.count then
				newAmmo = ammo.count + curAmmo removeAmmo = ammo.count - curAmmo
			else
				newAmmo = tonumber(maxAmmo) removeAmmo = missingAmmo
			end
			if newAmmo < 0 then newAmmo = 0 end
			SetPedAmmo(playerPed, weapon, newAmmo)
			TaskReloadWeapon(playerPed)
			currentWeapon.item.metadata.ammo = newAmmo
			TriggerServerEvent('hsn-inventory:server:addweaponAmmo',currentWeapon.slot,currentWeapon.item,ammo.name,ammo.count,removeAmmo,newAmmo)
		end
	end
end)


RegisterNetEvent('hsn-inventory:client:checkweapon')
AddEventHandler('hsn-inventory:client:checkweapon',function(item)
	if currentWeapon and currentWeapon.item.metadata.weaponlicense == item.metadata.weaponlicense then
		RemoveWeaponFromPed(playerPed, GetHashKey(item.name))
		SetCurrentPedWeapon(playerPed, 'WEAPON_UNARMED', true)
		currentWeapon = nil
	end
end)

-- DISABLE FOR NOW, works very inconsistently and has issues with duping
--[[RegisterCommand('steal',function()
	local ped = playerPed
	if not IsPedInAnyVehicle(ped, true) and not isDead and not isCuffed then	 
		openTargetInventory()
	end
end)

function openTargetInventory()
	local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
	if closestPlayer ~= -1 and closestDistance <= 2.0 then
		local searchPlayerPed = GetPlayerPed(closestPlayer)
		if IsEntityPlayingAnim(searchPlayerPed, 'random@mugging3', 'handsup_standing_base', 3) or IsEntityPlayingAnim(searchPlayerPed, 'missminuteman_1ig_2', 'handsup_base', 3) or IsEntityPlayingAnim(searchPlayerPed, 'dead', 'dead_a', 3) or IsEntityPlayingAnim(searchPlayerPed, 'mp_arresting', 'idle') then
			TriggerServerEvent('hsn-inventory:server:openTargetInventory', GetPlayerServerId(closestPlayer))
		end
	else
		TriggerEvent('hsn-inventory:notification','There is nobody nearby')
	end
end]]

local nui_focus = {false, false}
function SetNuiFocusAdvanced(hasFocus, hasCursor, allowMovement)
	SetNuiFocus(hasFocus, hasCursor)
	SetNuiFocusKeepInput(hasFocus)
	nui_focus = {hasFocus, hasCursor}
	TriggerEvent('nui:focus', hasFocus, hasCursor)

	if nui_focus[1] then
		if Config.EnableBlur then TriggerScreenblurFadeIn(0) end
		Citizen.CreateThread(function()
			local ticks = 0
			while true do
				Citizen.Wait(0)
				DisableAllControlActions(0)
				if not nui_focus[2] then
					EnableControlAction(0, 1, true)
					EnableControlAction(0, 2, true)
				end
				EnableControlAction(0, 249, true) -- N for PTT
				EnableControlAction(0, 20, true) -- Z for proximity
				if allowMovement then
					EnableControlAction(0, 30, true) -- movement
					EnableControlAction(0, 31, true) -- movement
				end
				if not nui_focus[1] then
					ticks = ticks + 1
					if (IsDisabledControlJustReleased(0, 200, true) or ticks > 20) then
						invOpen = false
						currentInventory = nil
						if Config.EnableBlur then TriggerScreenblurFadeOut(0) end
						break
					end
				end
			end
		end)
	end
end

RegisterNetEvent('hsn-inventory:notification')
AddEventHandler('hsn-inventory:notification',function(message, mtype)
	if message then
		if mtype == 1 then mtype = { ['background-color'] = 'rgba(55,55,175)', ['color'] = 'white' }
		elseif not mtype or mtype == 2 then mtype = { ['background-color'] = 'rgba(175,55,55)', ['color'] = 'white' }
		end
		TriggerEvent('mythic_notify:client:SendAlert', {type = 'inform', text = message, length = 2500,style = mtype})
	end
end)

RegisterCommand('-nui', function()
		TriggerEvent('hsn-inventory:client:closeInventory')
end, false)

AddEventHandler('onResourceStop', function(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		TriggerScreenblurFadeOut(0)
		SetNuiFocusAdvanced(false, false)
		clearWeapons()
	end
end)

RegisterNetEvent('hsn-inventory:useItem')
AddEventHandler('hsn-inventory:useItem',function(item, slot)
	if usingItem or shooting then return end
	ESX.TriggerServerCallback('hsn-inventory:getItem',function(xItem)
		if xItem then
			local data = Config.ItemList[xItem.name]
			if not data or not next(data) then return end
			if xItem.closeonuse then TriggerEvent('hsn-inventory:client:closeInventory') end
			if not data.animDict then data.animDict = 'pickup_object' end
			if not data.anim then data.anim = 'putdown_low' end
			if not data.flags then data.flags = 48 end
			-- Trigger effects before the progress bar
			if data.component then
				if not currentWeapon then return end
				local result, esxWeapon = ESX.GetWeapon(currentWeapon.item.name)
				
				for k,v in ipairs(esxWeapon.components) do
					for k2, v2 in pairs(data.component) do
						if v.hash == v2 then
							component = {name = v.name, hash = v2}
							break
						end
					end
				end
				if not component then TriggerEvent('hsn-inventory:notification','This weapon is incompatible with '..xItem.label,2) return end
				if HasPedGotWeaponComponent(playerPed, currentWeapon.hash, component.hash) then
					TriggerEvent('hsn-inventory:notification','This weapon already has a '..xItem.label,2) return
				end
			end

			if item == 'lockpick' then
				TriggerEvent('esx_lockpick:onUse')
			end

			usingItem = true
			if data.useTime >= 0 then
				usingItem = true
				------------------------------------------------------------------------------------------------
				exports['mythic_progbar']:Progress({
					name = 'useitem',
					duration = data.useTime,
					label = 'Using '..xItem.name,
					useWhileDead = false,
					canCancel = false,
					controlDisables = { disableMovement = data.disableMove, disableCarMovement = false, disableMouse = false, disableCombat = true },
					animation = { animDict = data.animDict, anim = data.anim, flags = data.flags },
					prop = { model = data.model, coords = data.coords, rotation = data.rotation }
				}, function() usingItem = false end)
			else usingItem = false end
			while usingItem do Citizen.Wait(10) end

			if data.hunger then
				if data.hunger > 0 then TriggerEvent('esx_status:add', 'hunger', data.hunger)
				else TriggerEvent('esx_status:remove', 'hunger', data.hunger) end
			end
			if data.thirst then
				if data.thirst > 0 then TriggerEvent('esx_status:add', 'thirst', data.thirst)
				else TriggerEvent('esx_status:remove', 'thirst', data.thirst) end
			end
			if data.consume then TriggerServerEvent('hsn-inventory:client:removeItem', xItem.name, data.consume, xItem.metadata.type, xItem.slot) end
			usingItem = false
			------------------------------------------------------------------------------------------------
				

				if xItem.name == 'bandage' then
					local maxHealth = 200
					local health = GetEntityHealth(playerPed)
					local newHealth = math.min(maxHealth, math.floor(health + maxHealth / 16))
					SetEntityHealth(playerPed, newHealth)
					TriggerEvent('mythic_hospital:client:FieldTreatBleed')
					TriggerEvent('mythic_hospital:client:ReduceBleed')
				end

				if data.component then
					GiveWeaponComponentToPed(playerPed, currentWeapon.item.name, component.hash)
					table.insert(currentWeapon.item.metadata.components, component.name)
					TriggerServerEvent('hsn-inventory:server:updateWeapon', currentWeapon.slot, currentWeapon.item)
				end


				------------------------------------------------------------------------------------------------

		end
	end, item.name, item.metadata.type)
end)
