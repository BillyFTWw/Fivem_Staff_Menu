ESX = nil
local isStaff = false
local group
local MenuPosition = Config.MenuPosition

rightPosition = {x = 1350, y = 200}
leftPosition = {x = 0, y = 200}
menuPosition = {x = 0, y = 200}

if MenuPosition == "right" then
    menuPosition = rightPosition
elseif MenuPosition == "left" then
    menuPosition = leftPosition
end

CuriaPool = NativeUI.CreatePool()

function KeyboardInput(TextEntry, ExampleText, MaxStringLenght)

	-- TextEntry		-->	The Text above the typing field in the black square
	-- ExampleText		-->	An Example Text, what it should say in the typing field
	-- MaxStringLenght	-->	Maximum String Lenght

	AddTextEntry('FMMC_KEY_TIP1', TextEntry) --Sets the Text above the typing field in the black square
	DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", ExampleText, "", "", "", MaxStringLenght) --Actually calls the Keyboard Input
	blockinput = true --Blocks new input while typing if **blockinput** is used

	while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do --While typing is not aborted and not finished, this loop waits
		Citizen.Wait(0)
	end
		
	if UpdateOnscreenKeyboard() ~= 2 then
		local result = GetOnscreenKeyboardResult() --Gets the result of the typing
		Citizen.Wait(500) --Little Time Delay, so the Keyboard won't open again if you press enter to finish the typing
		blockinput = false --This unblocks new Input when typing is done
		return result --Returns the result
	else
		Citizen.Wait(500) --Little Time Delay, so the Keyboard won't open again if you press enter to finish the typing
		blockinput = false --This unblocks new Input when typing is done
	end
end

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
	end
end)

RegisterNetEvent('rio:playerLoaded')
AddEventHandler('rio:playerLoaded', function(xPlayer)
	ESX.TriggerServerCallback('esx_CuriaMenu:getGroup',function(answer)
		group = answer
	end)
end)

function CheckPermissions(action)
	local acessTable = {}
	local minAcessGroup = "enabled"
	if action == 'GiveCarToGarage' then
		minAcessGroup = Config.GiveCarToGarage 
	elseif action == 'SpawnDonateCars' then
		minAcessGroup = Config.SpawnDonateCars
	elseif action == 'RepairVehicle' then
		minAcessGroup = Config.RepairVehicle
	elseif action == 'DeleteVehicle' then
		minAcessGroup = Config.DeleteVehicle
	elseif action == 'SetMeDriver' then
		minAcessGroup = Config.SetMeDriver
	elseif action == 'GiveBlackMoney' then
		minAcessGroup = Config.GiveBlackMoney
	elseif action == 'SendToJail' then
		minAcessGroup = Config.SendToJail
	elseif action == 'SetPassenger' then
		minAcessGroup = Config.SetPassenger
	elseif action == 'Ban' then
		minAcessGroup = Config.Ban
	elseif action == 'UnBan' then
		minAcessGroup = Config.UnBan
	elseif action == 'GetRentedHomes' then
		minAcessGroup = Config.GetRentedHomes
	elseif action == 'GetHomeItems' then
		minAcessGroup = Config.GetHomeItems
	elseif action == 'GetPlayerBillings' then
		minAcessGroup = Config.GetPlayerBillings
	elseif action == 'ManageGarageVehicles' then
		minAcessGroup = Config.ManageGarageVehicles
	elseif action == 'SendToCommunityService' then
		minAcessGroup = Config.SendToCommunityService
	elseif action == 'OpenMenu' then
		minAcessGroup = Config.OpenMenu
	elseif action == 'vMenu' then
		minAcessGroup = Config.vMenu
	elseif action == 'Priority' then
		minAcessGroup = Config.Priority
	end
	local foundGroup = false
	for k,v in pairs(Config.AllowedGroups) do
		if v == minAcessGroup then
			foundGroup = true
			--return true
		end
		if foundGroup then
			table.insert(acessTable,v)
		end
	end
	for k,v in pairs(acessTable) do
		if group == v then
			return true
		end
	end
	return false
end

function SetVehicleMaxMods(vehicle)

	local props = {
	  modEngine       = 3,
	  modBrakes       = 2,
	  modTransmission = 2,
	  modSuspension   = 3,
	  modTurbo        = true,
	}
  
	ESX.Game.SetVehicleProperties(vehicle, props)
	SetVehicleColours(vehicle,0,0)
	SetVehicleExtraColours(vehicle,0,0)
end

RegisterNetEvent('esx_CuriaMenu:StaffUI')
AddEventHandler('esx_CuriaMenu:StaffUI', function()
	local SpawnDonateCar,RepairItem,DeleteVItem,DriverItem,BMMoneyItem,JailItem,UnJailItem,PassengerItem,OnlineBan,OfflineBan,UnBanList,GetRents,GetHomeInventory,vMenu,DeletevMenu
	local GetBillings,ComServ,EndComServ,getInv,GarageItem,GiveCarID,GetOffHomeInventory
	mainMenu = NativeUI.CreateMenu("Staff Menu","~r~Coded By Curia",menuPosition["x"], menuPosition["y"])
	CuriaPool:Add(mainMenu)
	local PlayersSub = CuriaPool:AddSubMenu(mainMenu,"~g~Player Options","",menuPosition["x"], menuPosition["y"]) --playerSubMenu
	local CarSub = CuriaPool:AddSubMenu(mainMenu,"~b~Vehicle Options","",menuPosition["x"], menuPosition["y"]) --VehicleSubMenu
	local StaffUtilities = CuriaPool:AddSubMenu(mainMenu,"~r~Staff Utilities","",menuPosition["x"], menuPosition["y"]) --staffutilitiesSubMenu
	if CheckPermissions('RepairVehicle') then
		RepairItem = NativeUI.CreateItem("~o~Repair & Clean", "~o~Repair and Clean Vehicle")
		CarSub.SubMenu:AddItem(RepairItem)
	end
	if CheckPermissions('DeleteVehicle') then
		DeleteVItem = NativeUI.CreateItem("~r~Delete Vehicle", "~r~Delete The Vehicle If no Driver is Inside.")
		CarSub.SubMenu:AddItem(DeleteVItem)
	end
	if CheckPermissions('SetMeDriver') then
		DriverItem = NativeUI.CreateItem("~p~Set Me Driver", "~p~Sets you as driver to the closest Vehicle if no driver exists.")
		CarSub.SubMenu:AddItem(DriverItem)
	end
	if CheckPermissions('SetPassenger') then
		PassengerItem = NativeUI.CreateItem("~g~Set Me Passenger", "~g~Sets you as driver to the closest Vehicle if no driver exists.")
		CarSub.SubMenu:AddItem(PassengerItem)
	end
	if CheckPermissions('SpawnDonateCars') then
		SpawnDonateCar = NativeUI.CreateItem("~b~Spawn DonateCars","~b~Spawn all donate cars from a list.")
		CarSub.SubMenu:AddItem(SpawnDonateCar)
	end
	if CheckPermissions('GiveCarToGarage') then
		GiveCarID = NativeUI.CreateItem("~o~Give Car to Garage ID", "~o~Give a car to players garage.")
		CarSub.SubMenu:AddItem(GiveCarID)
	end
	if CheckPermissions('GiveBlackMoney') then
		BMMoneyItem = NativeUI.CreateItem("~o~Give Black Money", "~o~Gives Black Money to Id.")
		PlayersSub.SubMenu:AddItem(BMMoneyItem)
	end
	if CheckPermissions('SendToJail') then
		JailItem = NativeUI.CreateItem("~b~Jail Player ID", "~b~Send Id to Jail.")
		UnJailItem = NativeUI.CreateItem("~p~Unjail Player ID", "~p~Release Id to Jail.")
		PlayersSub.SubMenu:AddItem(JailItem)
		PlayersSub.SubMenu:AddItem(UnJailItem)
	end	
	if CheckPermissions('SendToCommunityService') then
		ComServ = NativeUI.CreateItem("~g~Send Community Service ID", "~g~Send Id Community Service.")
		EndComServ = NativeUI.CreateItem("~r~End Community Service ID", "~r~End Id Community Service.")
		PlayersSub.SubMenu:AddItem(ComServ)
		PlayersSub.SubMenu:AddItem(EndComServ)
	end
	if CheckPermissions('ManageGarageVehicles') then
		GarageItem = NativeUI.CreateItem("~y~Show Garage Vehicles ID", "~y~Get Garage Vehicles Of Player Id and delete them if you want.")
		CarSub.SubMenu:AddItem(GarageItem)
	end
	if CheckPermissions('GetRentedHomes') then
		GetRents = NativeUI.CreateItem("~g~Get Rented Homes", "~g~Gives you the homes an id has rented")
		PlayersSub.SubMenu:AddItem(GetRents)
	end
	if CheckPermissions('GetHomeItems') then
		GetHomeInventory = NativeUI.CreateItem("~y~Get Home Inventory", "~y~Gives you the home inventory of a player")
		GetOffHomeInventory = NativeUI.CreateItem("~y~Get Offline Home Inventory", "~y~Gives you the home inventory of a player offline")
		PlayersSub.SubMenu:AddItem(GetHomeInventory)
		PlayersSub.SubMenu:AddItem(GetOffHomeInventory)
	end
	if CheckPermissions('GetPlayerBillings') then
		GetBillings = NativeUI.CreateItem("~b~Get Billings", "~b~Gives you the billings of an id")
		PlayersSub.SubMenu:AddItem(GetBillings)
	end
	if CheckPermissions('vMenu') then
		vMenu = NativeUI.CreateItem("~g~Add vMenu", "~g~Adds vMenu Permissions")
		DeletevMenu = NativeUI.CreateItem("~r~Remove vMenu", "~r~Removes vMenu Permissions")
		StaffUtilities.SubMenu:AddItem(vMenu)
		StaffUtilities.SubMenu:AddItem(DeletevMenu)
	end
	if CheckPermissions('Priority') then
		Priority = NativeUI.CreateItem("~g~Add Priority", "~g~Adds Priority")
		DeletePriority = NativeUI.CreateItem("~r~Remove Priority", "~r~Removes Priority")
		StaffUtilities.SubMenu:AddItem(Priority)
		StaffUtilities.SubMenu:AddItem(DeletePriority)
	end
	if CheckPermissions('Ban') then
		OnlineBan = NativeUI.CreateItem("~o~âOnline Banâ", "~o~Ban player.")
		OfflineBan = NativeUI.CreateItem("~p~âOFFline Banâ", "~p~Offline Ban player.")
		StaffUtilities.SubMenu:AddItem(OnlineBan)	
		StaffUtilities.SubMenu:AddItem(OfflineBan)	
	end
	if CheckPermissions('UnBan') then
		UnBanList = NativeUI.CreateItem("~b~âUnBan Listâ", "~b~UnBan player list.")
		StaffUtilities.SubMenu:AddItem(UnBanList)	
	end
	
	CuriaPool:MouseControlsEnabled(false)
	CuriaPool:ControlDisablingEnabled(false)
	PlayersSub.SubMenu.OnItemSelect = function(menu, item)
		if item == GetBillings then
			id = KeyboardInput("Add Id For Billings",GetPlayerServerId(PlayerId()),4)
			if id ~= nil and id ~= "" then
				TriggerServerEvent('esx_CuriaMenu:getBillings',tonumber(id))
			end
		elseif item == BMMoneyItem then
			local continue = true
			id = KeyboardInput("Add Id to give black money",GetPlayerServerId(PlayerId()),3)
			if id == "" then
				continue = false
			end
			if continue then
				money = KeyboardInput("Add Black Money","",15)
			end
			if continue then
				TriggerServerEvent('esx_CuriaMenu:addBlackMoney',tonumber(id),tonumber(money))
			end
		elseif item == GetHomeInventory then
			id = KeyboardInput("Add Id to get inventory",GetPlayerServerId(PlayerId()),3)
			if id ~= nil and id ~= "" then
				TriggerServerEvent('esx_CuriaMenu:getHomeInv',tonumber(id))
			end
		elseif item == GetOffHomeInventory then
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'Search',
			{
				title = "ÎÎ½Î±Î¶Î®ÏÎ·ÏÎ· ÎÎ½ÏÎ¼Î±ÏÎ¿Ï",
			},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					CuriaPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~r~Coded By Curia",menuPosition["x"], menuPosition["y"])
					CuriaPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_CuriaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							CuriaPool:MouseControlsEnabled(false)
							CuriaPool:ControlDisablingEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								TriggerServerEvent('esx_CuriaMenu:getOffHomeInv',item:Description())
							end
						else
							ESX.ShowNotification('~r~Invalid~s~ Name')
						end
					end,tostring(data2.value))				
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
			end, function (data2, menu)
				menu.close()
			end)
		elseif item == JailItem then
			local jail = true
			id = KeyboardInput("Add Id to teleport to jail","",3)
			jailTime = KeyboardInput("Add Jail Minutes","",5)
			reason = KeyboardInput("Add Reason","",40)
			if tonumber(id) > 0 and tonumber(jailTime) > 0 then
				TriggerServerEvent("rio-qalle-jail:jailPlayer",tonumber(id),tonumber(jailTime),reason)
			else
				ESX.ShowNotification("~r~Wrong Input Detected")
			end
		elseif item == UnJailItem then
			local continue = true
			local id = KeyboardInput("Add ID",GetPlayerServerId(PlayerId()),4)
			if id == nil or tonumber(id) == 0 then
				continue = false
			end
			if continue then
				TriggerServerEvent('rio-qalle-jail:unJailPlayer2', tonumber(id))
			end
		elseif item == ComServ then
			local continue = true
			local id = KeyboardInput("Add ID",GetPlayerServerId(PlayerId()),4)
			if id == nil or tonumber(id) == 0 then
				continue = false
			end
			local swipes 
			if continue then
				swipes = KeyboardInput("Add Swipes","",3)
			end
			local reason
			if swipes == nil or tonumber(swipes) <= 0 then
				continue = false
				ESX.ShowNotification("Too Few Swipes or wrong ID")
			end
			if continue then
				TriggerServerEvent('rio_communityservice:sendToCommunityService', tonumber(id), tonumber(swipes))
			end
		elseif item == EndComServ then
			local continue = true
			local id = KeyboardInput("Add ID",GetPlayerServerId(PlayerId()),4)
			if id == nil or tonumber(id) == 0 then
				continue = false
			end
			if continue then
				TriggerServerEvent('rio_communityservice:endCommunityServiceCommand', tonumber(id))
			end
		elseif item == GetRents then
			CuriaPool:CloseAllMenus()
			getRentMenu = NativeUI.CreateMenu("~y~Rents","~r~Coded By Curia",menuPosition["x"], menuPosition["y"])
			CuriaPool:Add(getRentMenu)
			ESX.TriggerServerCallback('esx_CuriaMenu:getrents',function(result)
				local rents = {}
				for k = 1, #result do
					rents[k] = NativeUI.CreateItem(result[k].name, '$'..result[k].price)
					getRentMenu:AddItem(rents[k])
				end
				CuriaPool:MouseControlsEnabled(false)
				CuriaPool:ControlDisablingEnabled(false)
				getRentMenu:Visible(not getRentMenu:Visible())
				getRentMenu.OnItemSelect = function(menu, item)
					print(item:Description())
				end
			end)
		end
	end
	CarSub.SubMenu.OnItemSelect = function(menu, item)
		if item == RepairItem then
			local vehicle = ESX.Game.GetClosestVehicle()
			SetVehicleUndriveable(vehicle,false)
			SetVehicleBodyHealth(vehicle,1000)
			SetVehicleDeformationFixed(vehicle)
			SetVehicleEngineHealth(vehicle, 1000)
			SetVehicleEngineOn( vehicle, true, true )
			SetVehicleFixed(vehicle)
			SetVehicleOnGroundProperly(vehicle)
			SetVehicleGravity(vehicle, true)
			SetVehicleDirtLevel(vehicle, 0)
		elseif item == GiveCarID then
			local id = KeyboardInput("ID to GiveCar","",10)
			if id == nil or id == "" then
				ESX.ShowNotification("Invalid ID")
			else
				local vehicle	   = ESX.Game.GetClosestVehicle()
				local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
				local newPlate     = GeneratePlate()
				vehicleProps.plate = newPlate
				SetVehicleNumberPlateText(vehicle, newPlate)
				local vehname = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
				vehname = string.lower(vehname)
				TriggerServerEvent('esx_CuriaMenu:setVehicleOwnedPlayerId',id,vehicleProps,vehname)
			end
		elseif item == DeleteVItem then
			local vehicle = ESX.Game.GetClosestVehicle()
			SetPedIntoVehicle(GetPlayerPed(-1),vehicle,-1)
			NetworkRequestControlOfEntity(vehicle)
			SetEntityCollision(vehicle,false,false)
			SetEntityAlpha(vehicle,0.0,true)
			SetEntityAsMissionEntity(vehicle,true,true)
			SetEntityAsNoLongerNeeded(vehicle)
			DeleteEntity(vehicle)
		elseif item == DriverItem then
			local vehicle = ESX.Game.GetClosestVehicle()
			if IsVehicleSeatFree(vehicle,-1) then
				SetPedIntoVehicle(GetPlayerPed(-1),vehicle,-1)
				ESX.ShowNotification('~g~Setted as Driver to the nearby vehicle~g~')
			else
				ESX.ShowNotification('~r~Nearby Vehicle not Free!~r~')
			end
		elseif item == PassengerItem then
			local vehicle = ESX.Game.GetClosestVehicle()
			if seat == nil then
				seat = 0 
			elseif tonumber(seat) == 3 then
				seat = 1
			elseif tonumber(seat) == 4 then
				seat = 2
			end
			if IsVehicleSeatFree(vehicle,seat) then
				SetPedIntoVehicle(GetPlayerPed(-1),vehicle,seat)
				ESX.ShowNotification('~g~Setted as Passenger to the nearby vehicle~g~')
			else
				ESX.ShowNotification('~r~Nearby Vehicle has a passenger!~r~')
			end
		elseif item == GarageItem then
			id = KeyboardInput("Add Id for garage",GetPlayerServerId(PlayerId()),3)
			TriggerServerEvent('esx_CuriaMenu:getgarage',tonumber(id))
		elseif item == SpawnDonateCar then
			CuriaPool:CloseAllMenus()
			DonateCarMenu = NativeUI.CreateMenu("~y~DonateCars","~r~Coded By Curia",menuPosition["x"], menuPosition["y"])
			CuriaPool:Add(DonateCarMenu)
			ESX.TriggerServerCallback('esx_CuriaMenu:getDonatorCars',function(cars)
				local DCS = {}
				for k = 1, #cars do
					DCS[k] = NativeUI.CreateItem(cars[k].label, cars[k].spawn)
					DonateCarMenu:AddItem(DCS[k])
				end
				CuriaPool:MouseControlsEnabled(false)
				CuriaPool:ControlDisablingEnabled(false)
				DonateCarMenu:Visible(not mainMenu:Visible())
				DonateCarMenu.OnItemSelect = function(menu, item)
					local ped = GetPlayerPed(-1)
					local coords = GetEntityCoords(ped)
					local heading = GetEntityHeading(ped)
					if GetVehiclePedIsUsing(ped) ~= 0 then
						ESX.Game.DeleteVehicle(GetVehiclePedIsUsing(ped))
					end
					ESX.Game.SpawnVehicle(item:Description(), coords, heading,function(vehicle)
						TaskWarpPedIntoVehicle(ped, vehicle, -1)
						SetVehicleMaxMods(vehicle)
					end)
				end
			end)
		end
	end
	StaffUtilities.SubMenu.OnItemSelect = function(menu, item)
		if item == vMenu then
			local continue = true
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'Search',
			{
				title = "ÎÎ½Î±Î¶Î®ÏÎ·ÏÎ· ÎÎ½ÏÎ¼Î±ÏÎ¿Ï",
			},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					CuriaPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~r~Coded By Curia",menuPosition["x"], menuPosition["y"])
					CuriaPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_CuriaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							CuriaPool:MouseControlsEnabled(false)
							CuriaPool:ControlDisablingEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								local type =  KeyboardInput("Add Type","",20)
								if type == nil or type == "" then
									continue = false
								end
								local expire
								if continue then
									expire = KeyboardInput("Expire","Never",50)
									if expire == "Never" then
										expire = -1
									else
										expire = tonumber(expire)
									end
									if expire == 0 then
										continue = false
									end
								end
								if continue then
									if type == 'donator' or type == 'trial' or type == 'helper' or type == 'supporter' or type == 'admin' or type == 'owner' then 
										TriggerServerEvent('esx_CuriaMenu:addvMenu',item:Description(),type,expire)
									else
										ESX.ShowNotification("vMenu Types: donator, trial, helper, supporter, admin, owner")
									end
								end
							end
						else
							ESX.ShowNotification('~r~Invalid~s~ Name')
						end
					end,tostring(data2.value))				
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == DeletevMenu then
			CuriaPool:CloseAllMenus()
			TriggerServerEvent('esx_CuriaMenu:showvMenu')
		elseif item == Priority then
			local continue = true
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'Search',
			{
				title = "ÎÎ½Î±Î¶Î®ÏÎ·ÏÎ· ÎÎ½ÏÎ¼Î±ÏÎ¿Ï",
			},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					CuriaPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By Curia",menuPosition["x"], menuPosition["y"])
					CuriaPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_CuriaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							CuriaPool:MouseControlsEnabled(false)
							CuriaPool:ControlDisablingEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								local power =  KeyboardInput("Add Power","0",3)
								if power == nil or power == "" then
									continue = false
								end
								local days
								if continue then
									days = KeyboardInput("Add Days","Leave This For Non Expiration",100)
									if days == "Leave This For Non Expiration" then
										days = -1
									else
										days = tonumber(days)
									end
								end
								if continue then
									TriggerServerEvent("esx_CuriaMenu:addPriority",item:Description(),power,days)
								end
							end
						else
							ESX.ShowNotification('~r~Invalid~s~ Name')
						end
					end,tostring(data2.value))				
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == DeletePriority then
			CuriaPool:CloseAllMenus()
			TriggerServerEvent('esx_CuriaMenu:showPriority')
		elseif item == OfflineBan then
			local continue = true
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'Search',
			{
				title = "ÎÎ½Î±Î¶Î®ÏÎ·ÏÎ· ÎÎ½ÏÎ¼Î±ÏÎ¿Ï",
			},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					CuriaPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~r~Coded By Curia",menuPosition["x"], menuPosition["y"])
					CuriaPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_CuriaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							CuriaPool:MouseControlsEnabled(false)
							CuriaPool:ControlDisablingEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								local hours = KeyboardInput("Add Hours","Leave This For Perma Ban",100)
								if hours == "Leave This For Perma Ban" then
									hours = -1
								else
									hours = tonumber(hours)
								end
								if hours == 0 then
									continue = false
								end
								local reason =  KeyboardInput("Add Reason","",200)
								if reason == nil or reason == "" then
									continue = false
								end
								if continue then
									local myname = GetPlayerName(PlayerId())
									TriggerServerEvent('esx_CuriaMenu:OffLineBan',item:Description(),hours,reason)
								end
							end
						else
							ESX.ShowNotification('~r~Invalid~s~ Name')
						end
					end,tostring(data2.value))
					
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
				
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == OnlineBan then
			CuriaPool:CloseAllMenus()
			PlayersMenu = NativeUI.CreateMenu("~y~Players","~r~Coded By Curia",menuPosition["x"], menuPosition["y"])
			CuriaPool:Add(PlayersMenu)
				local playerList = {}
				local list = getPlayersList()
				for k = 1, #list do
					playerList[k] = NativeUI.CreateItem(list[k].name, list[k].id)
					PlayersMenu:AddItem(playerList[k])
				end
				CuriaPool:MouseControlsEnabled(false)
				CuriaPool:ControlDisablingEnabled(false)
				PlayersMenu:Visible(not mainMenu:Visible())
				PlayersMenu.OnItemSelect = function(menu, item)
				local continue = true
				local hours = KeyboardInput("Add Hours","Leave This For Perma Ban",100)
				if hours == "Leave This For Perma Ban" then
					hours = -1
				else
					hours = tonumber(hours)
				end
				if hours == 0 then
					continue = false
				end
				local reason =  KeyboardInput("Add Reason","",200)
				if reason == nil or reason == "" then
					continue = false
				end
				if continue then
					local myname = GetPlayerName(PlayerId())
					local target = item:Text()
					TriggerServerEvent('esx_CuriaMenu:BanPlayer',item:Description(),hours,reason)
					if hours == -1 then
						TriggerServerEvent('esx_CuriaMenu:sendDiscord', myname ..' permanently banned '..GetPlayerName(target)..' for '..reason)
					else
						TriggerServerEvent('esx_CuriaMenu:sendDiscord', myname ..' banned '..GetPlayerName(target)..' for '..hours..' hours. Reason: '..reason)
					end
				end
			end
		elseif item == UnBanList then
			CuriaPool:CloseAllMenus()
			TriggerServerEvent('esx_CuriaMenu:getBannedPlayers')
		end
	end
	
	CuriaPool:RefreshIndex()

	mainMenu:Visible(not mainMenu:Visible())
end)

Citizen.CreateThread(function()
	Citizen.Wait(1000)	
	while true do
		CuriaPool:ProcessMenus()
		if IsControlPressed(0, Config.MenuKey) then
			CuriaPool:CloseAllMenus()
			Citizen.Wait(100)
			TriggerServerEvent('esx_CuriaMenu:checkAllowed')
		end
	  	Citizen.Wait(0)
	end
end)

function getPlayersList()

	local players = ESX.Game.GetPlayers()
	local data = {}

	for i=1, #players, 1 do

		local _data = {
			id = GetPlayerServerId(players[i]),
			name = GetPlayerName(players[i])
		}
		table.insert(data, _data)
	end
	return data
end

RegisterNetEvent('esx_CuriaMenu:showBanned')
AddEventHandler('esx_CuriaMenu:showBanned', function(db)
	local luckyId
	local elements = {}
	for i=1, #db do
		table.insert(elements,{label = db[i].targetplayername, value = i})
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'BannedPlayers',
	{
		title    = "Banned Players",
		align    = 'center',
		elements = elements,
	},
	function(data, menu)
		menu.close()
		luckyId = data.current.value
		elements = {}
		if db[data.current.value].reason == "" then
			table.insert(elements,{label = "No reason provided.", value = data.current.value})
		else
			table.insert(elements,{label = db[data.current.value].reason, value = data.current.value})
		end
		
		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'BannedPlayers',
		{
			title    = "Reason",
			align    = 'center',
			elements = elements,
		},
		function(data, menu)
			menu.close()
			elements = {}
			table.insert(elements,{label = "No", value = 'no'})
			table.insert(elements,{label = "Yes", value = 'yes'})
			ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), '',
			{
				title    = "Do you want to unban him?",
				align    = 'center',
				elements = elements,
			},
			function(data, menu)
				menu.close()
				if data.current.value == 'yes' then
					TriggerServerEvent('esx_CuriaMenu:unBan',db[luckyId].targetplayername)
					ESX.ShowNotification('~y~Succesfully unbanned '..db[luckyId].targetplayername)
					local myname = GetPlayerName(PlayerId())
					TriggerServerEvent('esx_CuriaMenu:sendDiscord', myname ..' unbanned '.. db[luckyId].targetplayername)
				end
			end)			
		end)
	end, function(data, menu)
		menu.close()
	end)
	luckyId = nil
end)

RegisterNetEvent('esx_CuriaMenu:openInv')
AddEventHandler('esx_CuriaMenu:openInv', function(items,weapons,blackmoney,playerName,targetId)
	CuriaPool:CloseAllMenus()
	local elements = {}

	if blackmoney > 0 then
		table.insert(elements,{label = '-------<font color = "red">Black Money</font>-------', value = 0})
		table.insert(elements, {
			label = 'Black Money: '..ESX.Math.GroupDigits(blackmoney),
			type = 'item_account',
			value = 'black_money'
		})
	end
		
	if #items > 0 then
		table.insert(elements,{label = '<font color = "green">-------Items-------</font>', value = 0})
	end
	for k,v in pairs(items) do
		if v.count > 0 then
			table.insert(elements, {
				label = v.name .. ' x' .. v.count,
				type = 'item_standard',
				value = v.name
			})
		end
	end
	
	if #weapons > 0 then
		table.insert(elements,{label = '<font color = "yellow">-------Weapons-------</font>', value = 0})
	end
	for k,v in pairs(weapons) do
		table.insert(elements, {
			label = ESX.GetWeaponLabel(v.name),
			type  = 'item_weapon',
			value = v.name
		})
	end

	if targetId ~= nil then
		format = playerName..'['..targetId..'] Home Inventory'
	else
		format = playerName..' Home Inventory'
	end

	ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'Inventory', {
		title    = format,
		align    = 'center',
		elements = elements
	}, function(data, menu)
		if data.current.type == 'item_weapon' then
			menu.close()

			TriggerServerEvent('esx_CuriaMenu:removeItem', targetId, data.current.type, data.current.value)
			ESX.SetTimeout(300, function()
				TriggerServerEvent('esx_CuriaMenu:getHomeInv', targetId)
			end)
		else
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'get_item_count', {
				title = 'Î Î¿ÏÏÏÎ·ÏÎ±'
			}, function(data2, menu)
				local quantity = tonumber(data2.value)
				if quantity == nil then
					ESX.ShowNotification('Invalid quantity')
				else
					menu.close()
					TriggerServerEvent('esx_CuriaMenu:removeItem', targetId, data.current.type, data.current.value, quantity)
					ESX.SetTimeout(300, function()
						TriggerServerEvent('esx_CuriaMenu:getHomeInv', targetId)
					end)
				end
			end, function(data2,menu)
				menu.close()
			end)
		end
	end, function(data, menu)
		menu.close()
	end)
end)

RegisterNetEvent('esx_CuriaMenu:printBillings')
AddEventHandler('esx_CuriaMenu:printBillings',function(data)
	CuriaPool:CloseAllMenus()	
	local itemChosen
	local bills = {}
	for i = 1, #data do
		table.insert(bills,{label = "Name:  "..data[i].label.."["..data[i].amount.."]      Sender: "..data[i].name, value = data[i].id})
	end
	ESX.UI.Menu.CloseAll()
	billMenu = ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'Bills',
    {
        title    = 'ÎÎ¿Î³Î±ÏÎ¹Î±ÏÎ¼Î¿Î¯',
        align    = 'center',
        elements = bills
    },
	function(data, menu)
		itemChosen = data.current.value
		menu.close()
		local Confirmation = {}
		table.insert(Confirmation,{label = "ÎÏÎ¹", value = "no"})
		table.insert(Confirmation,{label = "ÎÎ±Î¯", value = "yes"})
		confirmMenu = ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'ConfirmMenu',
		{
			title    = 'ÎÎ¹Î±Î³ÏÎ±ÏÎ®;',
			align    = 'center',
			elements = Confirmation
		},
		function(data, menu)
			menu.close()
			TriggerServerEvent('esx_CuriaMenu:deleteBill',itemChosen)
		end,function(data,menu)
		menu.close()
	end)
	end, function(data,menu)
		menu.close()
	end)
end)

RegisterNetEvent('esx_CuriaMenu:printCars')
AddEventHandler('esx_CuriaMenu:printCars',function(data)
	CuriaPool:CloseAllMenus()	
	local PLATE
	local NAME
	local cars = {}
	for i = 1, #data do
		table.insert(cars,{label = "Name:  "..tostring(GetDisplayNameFromVehicleModel(tonumber(data[i].vehicle.model))).."      Plate: "..data[i].plate, value = data[i].plate})
	end
	ESX.UI.Menu.CloseAll()
	carMenu = ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'Cars',
    {
    	title    = 'ÎÎ¼Î¬Î¾Î¹Î±',
        align    = 'center',
        elements = cars
    },
	function(data, menu)
		menu.close()
		PLATE = data.current.value
		NAME = data.current.label
		local Options = {}
		table.insert(Options,{label = "ÎÎ¹Î±Î³ÏÎ±ÏÎ®;", value = "delete"})
		carMenu = ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'Cars',
		{
			title    = 'Options',
			align    = 'center',
			elements = Options
		},
		function(data, menu)
			menu.close()
			if data.current.value == 'delete' then
				local prompt = {}
				table.insert(prompt,{label = "No" ,value = "no"})
				table.insert(prompt,{label = "Yes" ,value = "yes"})

				carMenu = ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'Delete',
				{
					title    = 'Delete?',
					align    = 'center',
					elements = prompt
				},
				function(data, menu)
					menu.close()
					if data.current.value == "yes" then
						TriggerServerEvent('esx_CuriaMenu:deletecar',PLATE)
						ESX.ShowNotification("~g~Vehicle Deleted From Database")
					end
				end, function (data, menu)
					menu.close()
				end)
			end
		end, function(data,menu)
			menu.close()
		end)
	end, function(data,menu)
		menu.close()
	end)
end)

RegisterNetEvent('esx_CuriaMenu:showvMenuList')
AddEventHandler('esx_CuriaMenu:showvMenuList',function(vmenulist)
    if #vmenulist > 0 then
        local elements = {}
        table.insert(elements,{label = "<font color='yellow'>ÎÎ½Î¿Î¼Î±   |   </font> <font color='green'>ÎÏÎ¯ÏÎµÎ´Î¿   |   </font> <font color='orange'>ÎÎ®Î¾Î·</font>", value = ""})
        for k,v in pairs(vmenulist) do
            table.insert(elements,{label = "<font color='yellow'>"..v.name.."</font>    |   <font color='green'>"..v.group.."</font>    |   <font color='orange'>"..v.expireat.."</font>", value = v.steamId, name = v.name, group = v.group})
        end
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'priorities',
        {
            title    = 'Priorities',
            align    = 'center',
            elements = elements
        },
        function(data, menu)
            if data.current.value ~= "" then
                menu.close()
                local steamId = data.current.value
                local Name = data.current.name
				local groupType = data.current.group
                local Confirmation = {}
                table.insert(Confirmation,{label = "<font color='red'>Yes</font>", value = "yes"})
                table.insert(Confirmation,{label = "<font color='green'>No</font>", value = "no"})
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'ConfirmMenu',
                {
                    title    = 'Delete?',
                    align    = 'center',
                    elements = Confirmation
                },
                function(data2, menu2)
                    menu2.close()
                    if data2.current.value == "yes" then
                        TriggerServerEvent('esx_CuriaMenu:deletevMenu',steamId,Name,groupType)
                        menu.close()
                    end
                end, function(data2,menu2)
                    menu2.close()
                end)
            end
        end, function(data,menu)
            menu.close()
        end)
    end
end)

RegisterNetEvent('esx_CuriaMenu:showPrios')
AddEventHandler('esx_CuriaMenu:showPrios',function(prios)
    if #prios > 0 then
        local elements = {}
        table.insert(elements,{label = "<font color='yellow'>ÎÎ½Î¿Î¼Î±   |   </font> <font color='green'>ÎÏÎ¯ÏÎµÎ´Î¿   |   </font> <font color='orange'>ÎÎ®Î¾Î·</font>", value = ""})
        for k,v in pairs(prios) do
            table.insert(elements,{label = "<font color='yellow'>"..v.name.."</font>    |   <font color='green'>"..v.power.."</font>    |   <font color='orange'>"..v.expireat.."</font>", value = v.steamId, name = v.name})
        end
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'priorities',
        {
            title    = 'Priorities',
            align    = 'center',
            elements = elements
        },
        function(data, menu)
            if data.current.value ~= "" then
                menu.close()
                local steamId = data.current.value
                local Name = data.current.name
                local Confirmation = {}
                table.insert(Confirmation,{label = "<font color='yellow'>ÎÎÎ</font>", value = "yes"})
                table.insert(Confirmation,{label = "<font color='green'>ÎÎ§Î</font>", value = "no"})
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'ConfirmMenu',
                {
                    title    = 'Delete?',
                    align    = 'center',
                    elements = Confirmation
                },
                function(data2, menu2)
                    menu2.close()
                    if data1.current.value == "yes" then
                        TriggerServerEvent('esx_CuriaMenu:deletePriority', steamId, Name)
                        menu.close()
                    end
                end, function(data2,menu2)
                    menu2.close()
                end)
            end
        end, function(data,menu)
            menu.close()
        end)
    end
end)

local NumberCharset = {}
local Charset = {}

for i = 48,  57 do table.insert(NumberCharset, string.char(i)) end

for i = 65,  90 do table.insert(Charset, string.char(i)) end
for i = 97, 122 do table.insert(Charset, string.char(i)) end

function GeneratePlate()
	local generatedPlate
	local doBreak = false

	while true do
		Citizen.Wait(2)
		math.randomseed(GetGameTimer())
		if Config.PlateUseSpace then
			generatedPlate = string.upper(GetRandomLetter(Config.PlateLetters) .. ' ' .. GetRandomNumber(Config.PlateNumbers))
		else
			generatedPlate = string.upper(GetRandomLetter(Config.PlateLetters) .. GetRandomNumber(Config.PlateNumbers))
		end

		ESX.TriggerServerCallback('rio_vehicleshop:isPlateTaken', function (isPlateTaken)
			if not isPlateTaken then
				doBreak = true
			end
		end, generatedPlate)

		if doBreak then
			break
		end
	end

	return generatedPlate
end

function GetRandomNumber(length)
	Citizen.Wait(1)
	math.randomseed(GetGameTimer())
	if length > 0 then
		return GetRandomNumber(length - 1) .. NumberCharset[math.random(1, #NumberCharset)]
	else
		return ''
	end
end

function GetRandomLetter(length)
	Citizen.Wait(1)
	math.randomseed(GetGameTimer())
	if length > 0 then
		return GetRandomLetter(length - 1) .. Charset[math.random(1, #Charset)]
	else
		return ''
	end
end