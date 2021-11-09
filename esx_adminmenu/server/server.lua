ESX = nil
BanList = {}
vMenuList = {}

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

ESX.RegisterServerCallback('esx_CuriaMenu:getGroup', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	cb(xPlayer.getGroup())
end)

RegisterServerEvent('esx_CuriaMenu:checkAllowed')
AddEventHandler('esx_CuriaMenu:checkAllowed', function()
	if IsPlayerAceAllowed(source, "adminmenu") then
		TriggerClientEvent("esx_CuriaMenu:StaffUI", source)
    end
end)

MySQL.ready(function()
	local vMenuFetch = MySQL.Sync.fetchAll('SELECT * FROM vmenu')
	for i=1, #vMenuFetch, 1 do
		local identifier = vMenuFetch[i].identifier
		local groupType = vMenuFetch[i].type
		local days = vMenuFetch[i].days
		local targetName = vMenuFetch[i].targetname
		if days ~= math.floor(-1) then
			if (tonumber(vMenuFetch[i].expirydate)) < os.time() then
				MySQL.Async.execute('DELETE FROM vmenu WHERE identifier = @identifier', {['@identifier'] = identifier})
				PerformHttpRequest(Config.vMenuHook, function(err, text, headers) end, 'POST', json.encode({embeds={{title='vMenu Expired',description=targetName.." vMenu expired.",color=17499}}}), { ['Content-Type'] = 'application/json' })
			else
				table.insert(vMenuList, {identifier = identifier, group = groupType})
			end
		else
			table.insert(vMenuList, {identifier = identifier, group = groupType})
		end
	end
end)

AddEventHandler('playerConnecting', function (playerName,setKickReason)
	local license,steamID,liveid,xblid,discord,playerip  = "n/a","n/a","n/a","n/a","n/a","n/a"

	for k,v in ipairs(GetPlayerIdentifiers(source))do
		if string.sub(v, 1, string.len("license:")) == "license:" then
			license = v
		elseif string.sub(v, 1, string.len("steam:")) == "steam:" then
			steamID = v
		elseif string.sub(v, 1, string.len("live:")) == "live:" then
			liveid = v
		elseif string.sub(v, 1, string.len("xbl:")) == "xbl:" then
			xblid  = v
		elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
			discord = v
		elseif string.sub(v, 1, string.len("ip:")) == "ip:" then
			playerip = v
		end
	end

	if tostring(discord) == nil or tostring(discord) == "n/a" then
		if Config.CheckDiscord then
			for _,d in pairs(Config.DiscordAllowed) do
				if tostring(steamID) == d then
					break
				else
					setKickReason(Config.CheckDiscordMessage)
					CancelEvent()
					break
				end
			end
		end
	end

	if (Banlist == {}) then
		Citizen.Wait(1000)
	end

	for i=1, #BanList, 1 do
		if ((tostring(BanList[i].license)) == tostring(license) 
			or (tostring(BanList[i].identifier)) == tostring(steamID) 
			or (tostring(BanList[i].liveid)) == tostring(liveid) 
			or (tostring(BanList[i].xblid)) == tostring(xblid) 
			or (tostring(BanList[i].discord)) == tostring(discord) 
			--[[or (tostring(BanList[i].playerip)) == tostring(playerip)]]) 
		then
			if (tonumber(BanList[i].permanent)) == 1 then
				setKickReason(BanList[i].reason..'\nDuration: Permanent')
				CancelEvent()
				break
			elseif (tonumber(BanList[i].expiration)) > os.time() then
				local tempsrestant = (((tonumber(BanList[i].expiration)) - os.time())/60)
				if tempsrestant >= 1440 then
					local day        = (tempsrestant / 60) / 24
					local hrs        = (day - math.floor(day)) * 24
					local minutes    = (hrs - math.floor(hrs)) * 60
					local txtday     = math.floor(day)
					local txthrs     = math.floor(hrs)
					local txtminutes = math.ceil(minutes)
					setKickReason(BanList[i].reason.."\nTime Remaining: "..txtday.." Days "..txthrs.." Hours "..txtminutes.." Minutes")
					CancelEvent()
					break
				elseif tempsrestant >= 60 and tempsrestant < 1440 then
					local day        = (tempsrestant / 60) / 24
					local hrs        = tempsrestant / 60
					local minutes    = (hrs - math.floor(hrs)) * 60
					local txtday     = math.floor(day)
					local txthrs     = math.floor(hrs)
					local txtminutes = math.ceil(minutes)
					setKickReason(BanList[i].reason.."\nTime Remaining: "..txthrs.." Hours "..txtminutes.." Minutes")
					CancelEvent()
					break
				elseif tempsrestant < 60 then
					local txtday     = 0
					local txthrs     = 0
					local txtminutes = math.ceil(tempsrestant)
					setKickReason(BanList[i].reason.."\nTime Remaining: "..txtminutes .." Minutes")
					CancelEvent()
					break
				end
			elseif (tonumber(BanList[i].expiration)) < os.time() and (tonumber(BanList[i].permanent)) == 0 then
				deletebanned(license)
				break
			end
		end
	end
	
	for m=1, #vMenuList, 1 do
		if tostring(steamID) == tostring(vMenuList[m].identifier) then
			ExecuteCommand('add_principal identifier.'..tostring(vMenuList[m].identifier).." group." ..tostring(vMenuList[m].group))
		end
	end
end)

AddEventHandler('es:playerLoaded',function(source)
	CreateThread(function()
	Wait(5000)
		local license,steamID,liveid,xblid,discord,playerip
		local playername = GetPlayerName(source)

		for k,v in ipairs(GetPlayerIdentifiers(source))do
			if string.sub(v, 1, string.len("license:")) == "license:" then
				license = v
			elseif string.sub(v, 1, string.len("steam:")) == "steam:" then
				steamID = v
			elseif string.sub(v, 1, string.len("live:")) == "live:" then
				liveid = v
			elseif string.sub(v, 1, string.len("xbl:")) == "xbl:" then
				xblid  = v
			elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
				discord = v
			elseif string.sub(v, 1, string.len("ip:")) == "ip:" then
				playerip = v
			end
		end

		MySQL.Async.fetchAll('SELECT * FROM `baninfo` WHERE `license` = @license', {
			['@license'] = license
		}, function(data)
		local found = false
			for i=1, #data, 1 do
				if data[i].license == license then
					found = true
				end
			end
			if not found then
				MySQL.Async.execute('INSERT INTO baninfo (license,identifier,liveid,xblid,discord,playerip,playername) VALUES (@license,@identifier,@liveid,@xblid,@discord,@playerip,@playername)', 
					{ 
					['@license']    = license,
					['@identifier'] = steamID,
					['@liveid']     = liveid,
					['@xblid']      = xblid,
					['@discord']    = discord,
					['@playerip']   = playerip,
					['@playername'] = playername
					},
					function ()
				end)
			else
				MySQL.Async.execute('UPDATE `baninfo` SET `identifier` = @identifier, `liveid` = @liveid, `xblid` = @xblid, `discord` = @discord, `playerip` = @playerip, `playername` = @playername WHERE `license` = @license', 
					{ 
					['@license']    = license,
					['@identifier'] = steamID,
					['@liveid']     = liveid,
					['@xblid']      = xblid,
					['@discord']    = discord,
					['@playerip']   = playerip,
					['@playername'] = playername
					},
					function ()
				end)
			end
		end)
	end)
end)

-- Commands
TriggerEvent('es:addGroupCommand', 'priorities', 'superadmin', function(source, args, user)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    local prios = MySQL.Sync.fetchAll('SELECT e.name,p.power,p.expiredays,p.steamId FROM priority p,users e WHERE e.identifier = p.steamId ORDER BY p.adddate DESC')
    local tmp = {}
    for k,v in pairs(prios) do
        local current = os.time()
        local days = v.expiredays
        local expire = current+(60*60*24*days)   
        if days ~= -1 then
            table.insert(tmp,{steamId = v.steamId ,name = v.name , power = v.power, expireat = os.date('%Y-%m-%d %H:%M:%S', expire)})
        else
            table.insert(tmp,{steamId = v.steamId ,name = v.name , power = v.power, expireat = "Î Î¿ÏÎ­"})
        end
    end
    if #tmp > 0 then
        TriggerClientEvent('esx_CuriaMenu:showPrios', src, tmp)
    else
        TriggerClientEvent('rio:showNotification', src, "~y~No priorities in Database")
    end
end)

TriggerEvent('es:addGroupCommand', 'ban', Config.Ban, function(source, args, user)
	local license,identifier,liveid,xblid,discord,playerip
	local target    = tonumber(args[1])
	local duree     = tonumber(args[2])
	local reason    = table.concat(args, " ",3)
	local canBan 	= true
	
	if args[1] then
		if target and target > 0 then
			local ping = GetPlayerPing(target)
			if ping and ping > 0 then
				local targetplayername = GetPlayerName(target)
				if reason == "" then
					reason = 'No reason Provided'
				end
				
				for k,v in ipairs(GetPlayerIdentifiers(target))do
					if string.sub(v, 1, string.len("license:")) == "license:" then
						license = v
					elseif string.sub(v, 1, string.len("steam:")) == "steam:" then
						identifier = v
					elseif string.sub(v, 1, string.len("live:")) == "live:" then
						liveid = v
					elseif string.sub(v, 1, string.len("xbl:")) == "xbl:" then
						xblid  = v
					elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
						discord = v
					elseif string.sub(v, 1, string.len("ip:")) == "ip:" then
						playerip = v
					end
				end

				for k,v in pairs(Config.CannotBeBanned) do
					if identifier == v then
						canBan = false
						break
					end
				end
			
				if not canBan then
					TriggerClientEvent('rio:showNotification', source, 'Access denied.')
				else
					local sourceplayername = GetPlayerName(source)
					local reason2 = 'You have been banned from the server!\n\nName: '..GetPlayerName(target)..'\nHex: '..identifier..'\n\nBanned From: '..sourceplayername..'\nReason: '..reason
					if duree > 0 then
						ban(source,license,identifier,liveid,xblid,discord,playerip,targetplayername,sourceplayername,duree,reason2,0)
						DropPlayer(target, reason2)
						TriggerEvent('esx_CuriaMenu:sendDiscord', sourceplayername..' banned '..targetplayername..'\nDuration: '..duree..'\nReason: '..reason)
					else
						ban(source,license,identifier,liveid,xblid,discord,playerip,targetplayername,sourceplayername,duree,reason2,1)
						DropPlayer(target, reason2)
						TriggerEvent('esx_CuriaMenu:sendDiscord', sourceplayername..' permanently banned '..targetplayername..'\nReason: '..reason)
					end
				end
			else
				TriggerClientEvent('rio:showNotification', source, 'Invalid ID')
			end
		else
			TriggerClientEvent('rio:showNotification', source, 'Invalid ID')
		end
	else
		TriggerClientEvent('rio:showNotification', source, '/ban (id) (hours) (reason)')
	end
end)

-- Player Options
ESX.RegisterServerCallback('esx_CuriaMenu:SearchDbForName', function(source, cb, searchedName)
	local userList = MySQL.Sync.fetchAll('SELECT * FROM users')
	local playerNames = {}
	local searchedNames = {}

	for i=1, #userList, 1 do
		local resultNames = string.find(userList[i].name, searchedName)
		if resultNames ~= nil then
			table.insert(searchedNames, {name = userList[i].name, identifier = userList[i].identifier})
		end
	end

	if #searchedNames > 0 then
		for k=1, #searchedNames, 1 do
			table.insert(playerNames, {
				name = searchedNames[k].name,
				identifier = searchedNames[k].identifier		
			})
		end
		cb(playerNames)
	else
		cb(nil)
	end
end)


RegisterNetEvent('esx_CuriaMenu:addBlackMoney')
AddEventHandler('esx_CuriaMenu:addBlackMoney', function(id, amount)
	local xPlayer = ESX.GetPlayerFromId(source)
	local xTarget = ESX.GetPlayerFromId(id)
	
	if xTarget ~= nil and xPlayer.getGroup() ~= 'user' then
		xTarget.setAccountMoney('black_money', amount)
	end
end)

ESX.RegisterServerCallback('esx_CuriaMenu:getrents', function(source, cb)
	TriggerEvent('rio_ownedproperty:getOwnedProperties', function(properties)
		local xPlayers  = ESX.GetPlayers()
		local rentedProp = {}

		for i=1, #properties, 1 do
			for j=1, #xPlayers, 1 do
				local xPlayer = ESX.GetPlayerFromId(xPlayers[j])

				if xPlayer.identifier == properties[i].owner then
					table.insert(rentedProp, {
						name  = xPlayer.name,
						price = properties[i].price
					})
				end
			end
		end

		cb(rentedProp)
	end)
end)

RegisterNetEvent('esx_CuriaMenu:getHomeInv')
AddEventHandler('esx_CuriaMenu:getHomeInv', function(id)
	local xPlayer    = ESX.GetPlayerFromId(id)
	local blackMoney = 0
	local items      = {}
	local weapons    = {}
	local playerName = GetPlayerName(id)

	TriggerEvent('esx_addonaccount:getAccount', 'property_black_money', xPlayer.identifier, function(account)
		blackMoney = account.money
	end)

	TriggerEvent('esx_addoninventory:getInventory', 'property', xPlayer.identifier, function(inventory)
		items = inventory.items
	end)

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
		weapons = store.get('weapons') or {}
	end)
	
	TriggerClientEvent('esx_CuriaMenu:openInv', source, items, weapons, blackMoney, playerName, id)
end)

RegisterNetEvent('esx_CuriaMenu:getOffHomeInv')
AddEventHandler('esx_CuriaMenu:getOffHomeInv', function(identifier)
	local pSource = source
	local blackMoney = 0
	local items      = {}
	local weapons    = {}

	local result = MySQL.Sync.fetchAll("SELECT * FROM users WHERE identifier = @identifier", {['@identifier'] = identifier})
	if result[1] ~= nil then
		playerName = result[1].name
	end

	TriggerEvent('esx_addonaccount:getAccount', 'property_black_money', identifier, function(account)
		blackMoney = account.money
	end)

	TriggerEvent('esx_addoninventory:getInventory', 'property', identifier, function(inventory)
		items = inventory.items
	end)

	TriggerEvent('esx_datastore:getDataStore', 'property', identifier, function(store)
		weapons = store.get('weapons') or {}
	end)

	TriggerClientEvent('esx_CuriaMenu:openInv', pSource, items, weapons, blackMoney, playerName)
end)

RegisterNetEvent('esx_CuriaMenu:removeItem')
AddEventHandler('esx_CuriaMenu:removeItem', function(owner, type, item, count)
	local xPlayer = ESX.GetPlayerFromId(source)
	local xPlayerOwner = ESX.GetPlayerFromId(owner)

	if type == 'item_standard' then
		TriggerEvent('esx_addoninventory:getInventory', 'property', xPlayerOwner.identifier, function(inventory)
			local inventoryItem = inventory.getItem(item)

			inventory.removeItem(item, count)
		end)
	elseif type == 'item_account' then
		TriggerEvent('esx_addonaccount:getAccount', 'property_' .. item, xPlayerOwner.identifier, function(account)
			account.removeMoney(count)
		end)
	elseif type == 'item_weapon' then
		TriggerEvent('esx_datastore:getDataStore', 'property', xPlayerOwner.identifier, function(store)
			local storeWeapons = store.get('weapons') or {}
			local weaponName   = nil

			for i=1, #storeWeapons, 1 do
				if storeWeapons[i].name == item then
					weaponName = storeWeapons[i].name

					table.remove(storeWeapons, i)
					break
				end
			end

			store.set('weapons', storeWeapons)
		end)
	end
end)

RegisterNetEvent('esx_CuriaMenu:getBillings')
AddEventHandler('esx_CuriaMenu:getBillings', function(id)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(id)
	
	MySQL.Async.fetchAll('SELECT * FROM billing WHERE identifier = @identifier', {
		['@identifier'] = xPlayer.identifier
	}, function(result)
		local bills = {}
		for i=1, #result, 1 do
			table.insert(bills, {
				label      = result[i].label,
				amount     = result[i].amount,
				name       = result[i].sender,
				id         = result[i].id			
			})
		end
		TriggerClientEvent('esx_CuriaMenu:printBillings', _source, bills)
	end)
end)

RegisterNetEvent('esx_CuriaMenu:deleteBill')
AddEventHandler('esx_CuriaMenu:deleteBill', function(id)
	local xPlayer = ESX.GetPlayerFromId(source)
	
	MySQL.Async.execute('DELETE from billing WHERE id = @id', {
		['@id'] = id
	}, function(rowsChanged)
		TriggerClientEvent('rio:showNotification', xPlayer.source, 'Bill deleted')
	end)
end)

RegisterNetEvent('esx_CuriaMenu:BanPlayer')
AddEventHandler('esx_CuriaMenu:BanPlayer', function(id, duration, banreason, resource)
	local license,identifier,liveid,xblid,discord,playerip
	local target    = tonumber(id)
	local duree     = tonumber(duration)
	local reason    = banreason
	local canBan = true
	
	local targetplayername = GetPlayerName(target)
	for k,v in ipairs(GetPlayerIdentifiers(target))do
		if string.sub(v, 1, string.len("license:")) == "license:" then
			license = v
		elseif string.sub(v, 1, string.len("steam:")) == "steam:" then
			identifier = v
		elseif string.sub(v, 1, string.len("live:")) == "live:" then
			liveid = v
		elseif string.sub(v, 1, string.len("xbl:")) == "xbl:" then
			xblid  = v
		elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
			discord = v
		elseif string.sub(v, 1, string.len("ip:")) == "ip:" then
			playerip = v
		end
	end

	for k,v in pairs(Config.CannotBeBanned) do
		if identifier == v then
			canBan = false
			break
		end
	end
		
	if resource == nil then
		if not canBan then
			TriggerClientEvent('rio:showNotification', source, 'Access denied.')
		else
			local sourceplayername = GetPlayerName(source)
			local reason2 = 'You have been banned from the server!\n\nName: '..GetPlayerName(target)..'\nHex: '..identifier..'\n\nBanned From: '..sourceplayername..'\nReason: '..reason
			if duree > 0 then
				ban(source,license,identifier,liveid,xblid,discord,playerip,targetplayername,sourceplayername,duree,reason2,0)
				DropPlayer(target, reason2)
			else
				ban(source,license,identifier,liveid,xblid,discord,playerip,targetplayername,sourceplayername,duree,reason2,1)
				DropPlayer(target, reason2)
			end
		end
	else
		local sourceplayername = 'Anticheat'
		local reason2 = 'You have been automatically banned from the server!\n\nName: '..GetPlayerName(target)..'\nHex: '..identifier..'\n\nBanned From: '..sourceplayername..'\nReason: '..reason
		if duree > 0 then
			ban(source,license,identifier,liveid,xblid,discord,playerip,targetplayername,sourceplayername,duree,reason2,0)
			DropPlayer(target, reason2)
		else
			ban(source,license,identifier,liveid,xblid,discord,playerip,targetplayername,sourceplayername,duree,reason2,1)
			DropPlayer(target, reason2)
		end
	end
end)

RegisterNetEvent('esx_CuriaMenu:OffLineBan')
AddEventHandler('esx_CuriaMenu:OffLineBan', function(steam, duration, banreason)
	local identifier       = tostring(steam)
	local duree            = tonumber(duration)
	local reason           = banreason
	local sourceplayername = GetPlayerName(source)
	local canBan = true

	for k,v in pairs(Config.CannotBeBanned) do
		if identifier == v then
			canBan = false
			break
		end
	end

	if not canBan then
		TriggerClientEvent('rio:showNotification', source, 'Access denied.')
	else
		MySQL.Async.fetchAll('SELECT * FROM baninfo WHERE identifier = @identifier', {
			['@identifier'] = identifier
		}, function(data)
			if duree > 0 then
				local reason2 = 'You have been banned from the server!\n\nName: '..data[1].playername..'\nHex: '..data[1].identifier..'\n\nBanned From: '..sourceplayername..'\nReason: '..reason
				ban(source,data[1].license,data[1].identifier,data[1].liveid,data[1].xblid,data[1].discord,data[1].playerip,data[1].playername,sourceplayername,duree,reason2,0) --Timed ban here
				TriggerEvent('esx_CuriaMenu:sendDiscord', sourceplayername ..' banned '..data[1].playername..' for '..duree..' hours. Reason: '..reason)
			else
				local reason2 = 'You have been banned from the server!\n\nName: '..data[1].playername..'\nHex: '..data[1].identifier..'\n\nBanned From: '..sourceplayername..'\nReason: '..reason
				ban(source,data[1].license,data[1].identifier,data[1].liveid,data[1].xblid,data[1].discord,data[1].playerip,data[1].playername,sourceplayername,duree,reason2,1) --Perm ban here
				TriggerEvent('esx_CuriaMenu:sendDiscord', sourceplayername ..' permanently banned '..data[1].playername..'. Reason: '..reason)
			end
		end)
	end
end)

RegisterNetEvent('esx_CuriaMenu:getBannedPlayers')
AddEventHandler('esx_CuriaMenu:getBannedPlayers', function(name)
	local src = source
	local bans = MySQL.Sync.fetchAll('SELECT * FROM banlist')
	local list = {}
	
	for i=1, #bans, 1 do
		table.insert(list, {
			targetplayername = bans[i].targetplayername,
			reason 			 = bans[i].reason		
		})
	end
	
	TriggerClientEvent('esx_CuriaMenu:showBanned', src, list)
end)

RegisterNetEvent('esx_CuriaMenu:unBan')
AddEventHandler('esx_CuriaMenu:unBan', function(targetplayername)
	MySQL.Async.execute('DELETE FROM banlist WHERE targetplayername = @targetplayername', {
	  ['@targetplayername']  = targetplayername
	}, function ()
		loadBanList()
	end)
end)

function ban(source,license,identifier,liveid,xblid,discord,playerip,targetplayername,sourceplayername,duree,reason,permanent)
	MySQL.Async.fetchAll('SELECT * FROM banlist WHERE targetplayername = @playername', {
		['@playername'] = targetplayername
	}, function(data)
		if not data[1] then
			local expiration = duree * 3600
			local timeat     = os.time()
			local added      = os.date()

			if expiration < os.time() then
				expiration = os.time()+expiration
			end
			
			table.insert(BanList, {
				license    		 = license,
				identifier 		 = identifier,
				liveid     		 = liveid,
				xblid      		 = xblid,
				discord    		 = discord,
				playerip   		 = playerip,
				reason     		 = reason,
				targetplayername = targetplayername,
				sourceplayername = sourceplayername,
				expiration 		 = expiration,
				permanent  		 = permanent
			  })

			MySQL.Async.execute('INSERT INTO banlist (license,identifier,liveid,xblid,discord,playerip,targetplayername,sourceplayername,reason,expiration,timeat,permanent) VALUES (@license,@identifier,@liveid,@xblid,@discord,@playerip,@targetplayername,@sourceplayername,@reason,@expiration,@timeat,@permanent)', { 
				['@license']          = license,
				['@identifier']       = identifier,
				['@liveid']           = liveid,
				['@xblid']            = xblid,
				['@discord']          = discord,
				['@playerip']         = playerip,
				['@targetplayername'] = targetplayername,
				['@sourceplayername'] = sourceplayername,
				['@reason']           = reason,
				['@expiration']       = expiration,
				['@timeat']           = timeat,
				['@permanent']        = permanent,
				}, function ()
			end)

			if permanent == 0 then
				TriggerClientEvent('rio:showNotification', source, "Banned: "..targetplayername.." for "..duree.." hours for reason: "..reason)
			else
				TriggerClientEvent('rio:showNotification', source, "Permanently Banned: "..targetplayername.." for "..reason)
			end

			MySQL.Async.execute(
				'INSERT INTO banlisthistory (license,identifier,liveid,xblid,discord,playerip,targetplayername,sourceplayername,reason,added,expiration,timeat,permanent) VALUES (@license,@identifier,@liveid,@xblid,@discord,@playerip,@targetplayername,@sourceplayername,@reason,@added,@expiration,@timeat,@permanent)',
				{ 
				['@license']          = license,
				['@identifier']       = identifier,
				['@liveid']           = liveid,
				['@xblid']            = xblid,
				['@discord']          = discord,
				['@playerip']         = playerip,
				['@targetplayername'] = targetplayername,
				['@sourceplayername'] = sourceplayername,
				['@reason']           = reason,
				['@added']            = added,
				['@expiration']       = expiration,
				['@timeat']           = timeat,
				['@permanent']        = permanent,
				}, function ()
			end)
			
			BanListHistoryLoad = false
		end
	end)
end

function loadBanList()
	MySQL.Async.fetchAll(
		'SELECT * FROM banlist',
		{},
		function (data)
		BanList = {}

		for i=1, #data, 1 do
			table.insert(BanList, {
				license    		 = data[i].license,
				identifier 		 = data[i].identifier,
				liveid     		 = data[i].liveid,
				xblid      		 = data[i].xblid,
				discord    		 = data[i].discord,
				playerip   		 = data[i].playerip,
				reason     		 = data[i].reason,
				targetplayername = data[i].targetplayername,
				sourceplayername = data[i].sourceplayername,
				expiration 		 = data[i].expiration,
				permanent 		 = data[i].permanent
			})
		end
    end)
end

function deletebanned(license) 
	MySQL.Async.execute(
	'DELETE FROM banlist WHERE license=@license',
	{
		['@license']  = license
	},
	function ()
		loadBanList()
	end)
end

-- Vehicle Options
RegisterNetEvent('esx_CuriaMenu:getgarage')
AddEventHandler('esx_CuriaMenu:getgarage', function(id)
	local ownedCars = {}
	local xPlayer = ESX.GetPlayerFromId(id)
	local _source = source
	
	MySQL.Async.fetchAll('SELECT * FROM owned_vehicles WHERE owner = @owner', {
		['@owner'] = xPlayer.getIdentifier()
	}, function(data)
		for _,v in pairs(data) do
			local vehicle = json.decode(v.vehicle)
			table.insert(ownedCars, {vehicle = vehicle, plate = v.plate})
		end
		TriggerClientEvent('esx_CuriaMenu:printCars', _source, ownedCars)
	end)
end)

RegisterServerEvent('esx_CuriaMenu:setVehicleOwnedPlayerId')
AddEventHandler('esx_CuriaMenu:setVehicleOwnedPlayerId', function(playerId, vehicleProps, vehName)
	local vSource = source
	local xPlayer = ESX.GetPlayerFromId(vSource)
	local xTarget = ESX.GetPlayerFromId(playerId)

	MySQL.Async.execute('INSERT INTO owned_vehicles (owner, plate, vehicle) VALUES (@owner, @plate, @vehicle)',
	{
		['@owner']   = xTarget.identifier,
		['@plate']   = vehicleProps.plate,
		['@vehicle'] = json.encode(vehicleProps)
	}, function(rowsChanged)
		TriggerClientEvent('rio:showNotification', playerId, 'A vehicle with plate ~y~'..vehicleProps.plate..'~s~ now belongs to ~b~you~s~')
		TriggerClientEvent('rio:showNotification', playerId, GetPlayerName(vSource)..' gifted you a '..vehName)
		TriggerClientEvent('rio:showNotification', vSource, 'You gifted '..vehName..' to '..GetPlayerName(playerId))
	end)
end)

RegisterNetEvent('esx_CuriaMenu:deletecar')
AddEventHandler('esx_CuriaMenu:deletecar', function(plate)
	MySQL.Async.execute('DELETE FROM owned_vehicles WHERE plate = @plate', {
		['@plate'] = plate
	})
end)

ESX.RegisterServerCallback('esx_CuriaMenu:getDonatorCars', function(source, cb, id)
	local donateCars = {}
	
	MySQL.Async.fetchAll('SELECT * FROM '..Config.DonatorVehicleTableInDatabase..' WHERE category = @category', {
		['@category'] = Config.DonatorVehiclesCategoryNamesInDatabase
	}, function(data)
		for i=1, #data, 1 do
			table.insert(donateCars, {
				label = data[i].name,
				spawn = data[i].model			
			})
		end
		cb(donateCars)
	end)
end)

-- Staff Utilities
RegisterNetEvent('esx_CuriaMenu:addvMenu')
AddEventHandler('esx_CuriaMenu:addvMenu', function(identifier, groupType, days)
	local _source = source
	local current = os.time()
	local expiredate = (current + (math.floor(60)*math.floor(60)*math.floor(24)*days))
	local xPlayer = ESX.GetPlayerFromId(_source)
	local targetName = MySQL.Sync.fetchAll("SELECT * FROM users WHERE identifier = @identifier", {['@identifier'] = identifier})
	
	MySQL.Async.execute('DELETE FROM vmenu WHERE identifier = @identifier', {['@identifier'] = identifier})
	
	Citizen.Wait(500)
	
	MySQL.Async.execute('INSERT INTO vmenu (identifier,type,adder,targetname,adddate,expirydate,days) VALUES (@identifier,@type,@adder,@targetname,@adddate,@expirydate,@days)',{['@identifier'] = identifier,['@type'] = groupType,['@adder'] = GetPlayerName(_source),['@targetname'] = targetName[1].name,['@days'] = days, ['@adddate'] = os.time(), ['@expirydate'] = expiredate},function(rowsChanged)
        if rowsChanged == 1 then
			table.insert(vMenuList, {identifier = identifier, group = groupType})
            PerformHttpRequest(Config.vMenuHook, function(err, text, headers) end, 'POST', json.encode({embeds={{title='vMenu Added',description=xPlayer.getName().." added vMenu to "..identifier.."/"..targetName[1].name.." for "..days.." days",color=17499}}}), { ['Content-Type'] = 'application/json' })
			TriggerClientEvent('rio:showNotification', _source, "~g~Added~s~ vMenu for ~p~"..targetName.."~s~!")
		else
            TriggerClientEvent('rio:showNotification', _source, "~r~An error has occured")
        end
    end)
end)

RegisterNetEvent('esx_CuriaMenu:showvMenu')
AddEventHandler('esx_CuriaMenu:showvMenu', function()
	local _source = source
	local vMenuFetch = MySQL.Sync.fetchAll('SELECT * FROM vmenu')
    local vMenuList2 = {}
    for k,v in pairs(vMenuFetch) do
        local days = v.days
		local expire = v.expirydate
        if days ~= -1 then
            table.insert(vMenuList2,{steamId = v.identifier ,name = v.targetname, group = v.type, expireat = os.date('%Y-%m-%d %H:%M:%S', expire)})
        else
            table.insert(vMenuList2,{steamId = v.identifier ,name = v.targetname, group = v.type, expireat = "Î Î¿ÏÎ­"})
        end
    end
    if #vMenuList2 > 0 then
        TriggerClientEvent('esx_CuriaMenu:showvMenuList', _source, vMenuList2)
    else
        TriggerClientEvent('rio:showNotification', _source, "~y~No vMenu in Database")
    end
end)

RegisterNetEvent('esx_CuriaMenu:deletevMenu')
AddEventHandler('esx_CuriaMenu:deletevMenu', function(identifier, targetName, groupT)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local playerName = xPlayer.getName()
	
	MySQL.Async.execute('DELETE FROM vmenu WHERE identifier = @identifier',{['@identifier'] = identifier},function(rowsChanged)
        if rowsChanged >= 1 then
			for k,v in pairs(vMenuList) do
				if v.identifier == identifier then
					table.remove(vMenuList, k)
					break
				end
			end
			ExecuteCommand('remove_principal identifier.'..identifier.." group." ..groupT)
            PerformHttpRequest(Config.vMenuHook, function(err, text, headers) end, 'POST', json.encode({embeds={{title='vMenu Deleted',description=playerName.." deleted "..targetName.."\'s vMenu",color=17499}}}), { ['Content-Type'] = 'application/json' })
            TriggerClientEvent('rio:showNotification', _source, "~g~Deleted~s~ vMenu to ~p~"..playerName.."~s~!")
        else
            TriggerClientEvent('rio:showNotification', _source, "~r~An error has occured")
        end
    end)
end)

RegisterNetEvent('esx_CuriaMenu:showPriority')
AddEventHandler('esx_CuriaMenu:showPriority', function(id)
	local src = source
	local prios = MySQL.Sync.fetchAll('SELECT * FROM priority')
    local tmp = {}
    for k,v in pairs(prios) do
        local current = os.time()
        local days = v.expiredays
        local expire = current+(60*60*24*days)   
        if days ~= -1 then
            table.insert(tmp,{steamId = v.steamId ,name = v.name , power = v.power, expireat = os.date('%Y-%m-%d %H:%M:%S', expire)})
        else
            table.insert(tmp,{steamId = v.steamId ,name = v.name , power = v.power, expireat = "Î Î¿ÏÎ­"})
        end
    end
    if #tmp > 0 then
        TriggerClientEvent('esx_CuriaMenu:showPrios', src, tmp)
    else
        TriggerClientEvent('rio:showNotification', src, "~y~No priorities in Database")
    end
end)

RegisterNetEvent('esx_CuriaMenu:sendDiscord')
AddEventHandler('esx_CuriaMenu:sendDiscord', function(message)
	local embeds = {
		{
			["title"]=message,
			["type"]="rich",
			["color"]=2061822,
		}
	}
	if message == nil or message == '' then return FALSE end
	PerformHttpRequest(Config.BanWebhook, function(err, text, headers) end, 'POST', json.encode({ username = name,embeds = embeds}), { ['Content-Type'] = 'application/json' })
end)