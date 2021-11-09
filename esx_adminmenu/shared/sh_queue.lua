if not IsDuplicityVersion() then
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0)
            if NetworkIsSessionStarted() then
                TriggerServerEvent("Queue:playerActivated")
                return
            end
        end
    end)
    return
end

local Queue = {}
-- EDIT THESE IN SERVER.CFG + OTHER OPTIONS IN CONFIG.LUA
Queue.MaxPlayers =  GetConvarInt("sv_maxclients")
Queue.Debug = GetConvar("sv_debugqueue", "true") == "true" and true or false
Queue.DisplayQueue = GetConvar("sv_displayqueue", "true") == "true" and true or false
Queue.InitHostName = GetConvar("sv_hostname")


-- This is needed because msgpack will break when tables are too large
local _Queue = {}
_Queue.QueueList = {}
_Queue.PlayerList = {}
_Queue.PlayerCount = 0
_Queue.Priority = {}
_Queue.DaysLeft = {}
_Queue.Connecting = {}
_Queue.JoinCbs = {}
_Queue.TempPriority = {}
ESX = nil
_Queue.JoinDelay = GetGameTimer() + Config.JoinDelay and Config.JoinDelay or 0

local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local print = print
local string_len = string.len
local string_sub = string.sub
local string_format = string.format
local string_lower = string.lower
local math_abs = math.abs
local math_floor = math.floor
local math_random = math.random
local os_time = os.time
local table_insert = table.insert
local table_remove = table.remove
local isWaitingForElites = true
local entryCounter = 0
local serverStarting = true


Queue.InitHostName = Queue.InitHostName ~= "default FXServer" and Queue.InitHostName or false

for id, power in pairs(Config.SteamPriority) do
    _Queue.Priority[string_lower(id)] = power
end


TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)


RegisterCommand('refreshpriority', function(source, args)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer.getGroup() == 'superadmin' then
        local priorityTable = MySQL.Sync.fetchAll('SELECT * FROM priority')
        for k,v in pairs(priorityTable) do
            
            local steamId = string_lower(v.steamId)
            local power = tonumber(v.power)
            _Queue.Priority[steamId] = power
        end
    end
end)

MySQL.ready(function()
	local current = os.time()
    local priorityTable = MySQL.Sync.fetchAll('SELECT e.name,p.steamId,p.power,p.adder, p.adddate, p.expiredays FROM priority p, users e WHERE e.identifier = p.steamId')
    for k,v in pairs(priorityTable) do
        local days = v.expiredays
        local supposedToExipre = v.adddate + (math.floor(60)*math.floor(60)*math.floor(24)*days)
        local daysLeft = math.floor(((supposedToExipre - current)/math.floor(60)/math.floor(60)/math.floor(24))+0.5)
        
        if days ~= math.floor(-1) then
            local deleteThreshold = current-(math.floor(60)*math.floor(60)*math.floor(24)*days)   
            if tonumber(v.adddate) < deleteThreshold then
                PerformHttpRequest(Config.LogWebhook, function(err, text, headers) end, 'POST', json.encode({embeds={{title='Priority Expired',description=v.name.."/"..v.steamId.."\nPower: "..v.power.."\n Expire: "..os.date('%Y-%m-%d %H:%M:%S', supposedToExipre).."\nMachine Date: "..os.date('%Y-%m-%d %H:%M:%S', os.time()),color=17499}}}), { ['Content-Type'] = 'application/json' })
				MySQL.Async.execute("DELETE FROM `priority` where adddate < @threshold and steamId = @steamId",{['@threshold'] = deleteThreshold,['@steamId'] = v.steamId})
            end
        end
        local steamId = string_lower(v.steamId)
        if days == math.floor(-1) then
            _Queue.DaysLeft[steamId] = math.floor(-1)
        else
            _Queue.DaysLeft[steamId] = daysLeft
        end
        local power = tonumber(v.power)
        _Queue.Priority[steamId] = power
    end

    local users = MySQL.Sync.fetchAll('SELECT identifier,job FROM users')
    for k,v in pairs(users) do
        local power = IsPriorityJob(v.job)
        if tonumber(power) > math.floor(0) then
            if _Queue.Priority[v.identifier] == nil then
                _Queue.Priority[v.identifier] = power
            else
                if tonumber(power) > _Queue.Priority[v.identifier] then
                    _Queue.Priority[v.identifier] = power
                end
            end
        end
    end

    serverStarting = false
    print("Priorities Loaded!!")
end)

RegisterServerEvent("esx_CuriaMenu:deletePriority")
AddEventHandler("esx_CuriaMenu:deletePriority", function(steamId,targetName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local playerName = xPlayer.getName()

    if xPlayer.getGroup() == 'superadmin' then
        MySQL.Async.execute('DELETE FROM priority WHERE steamId = @steamId',{['@steamId'] = steamId},function(rowsChanged)
            if rowsChanged >= 1 then
                _Queue.Priority[steamId] = nil
                PerformHttpRequest(Config.LogWebhook, function(err, text, headers) end, 'POST', json.encode({embeds={{title='Priority Deleted',description=playerName.." deleted "..targetName.."\\s priority",color=17499}}}), { ['Content-Type'] = 'application/json' })
                TriggerClientEvent('rio:showNotification', src, "~r~Deleted~s~ ~g~Priority~s~ for ~p~"..playerName.."~s~!")
            else
                TriggerClientEvent('rio:showNotification', src, "~r~An error has occured")
            end
        end)
        
    else
        TriggerClientEvent('rio:showNotification', src, "~r~Superadmin required to do this")
    end
end)

RegisterServerEvent("esx_CuriaMenu:addPriority")
AddEventHandler("esx_CuriaMenu:addPriority", function(steamId,power,days)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    _Queue.Priority[string_lower(steamId)] = tonumber(power)
    local sourceSteam = GetPlayerIdentifiers(source)[1]
    local priorityTable = MySQL.Sync.fetchAll('SELECT e.name,p.steamId,p.power,p.adder, p.adddate, p.expiredays FROM priority p, users e WHERE e.identifier = p.steamId and p.steamId = @identifier',{['@identifier'] = steamId})
    local tmp = MySQL.Sync.fetchAll('SELECT name FROM users WHERE identifier = @identifier',{['@identifier'] = steamId})
    local name
    if #tmp > 0 then
        name = tmp[1].name
    else
        name = 'failed'
    end
    if priorityTable[1] ~= nil then
        MySQL.Async.execute('UPDATE priority SET power = @power ,adder = @adder,expiredays = @expiredays WHERE steamId = @steamId',{['@steamId'] = steamId,['@power'] = tonumber(power),['@adder'] = sourceSteam,['@expiredays'] = days},function(rowsChanged)
            if rowsChanged == 1 then
                PerformHttpRequest(Config.LogWebhook, function(err, text, headers) end, 'POST', json.encode({embeds={{title='Modified Priority',description=xPlayer.getName().." modified priority of : "..steamId.."/"..name.."\nInfo\nPower: "..tonumber(power).."\nDays: "..days,color=17499}}}), { ['Content-Type'] = 'application/json' })
                TriggerClientEvent('rio:showNotification', src, "~r~Modified~s~ ~g~Priority~s~ for ~p~"..tmp.."~s~!")
            else
                TriggerClientEvent('rio:showNotification', src, "~r~An error has occured")
            end
        end)
    else
        MySQL.Async.execute('INSERT INTO priority (name,steamId,power,adder,expiredays,adddate) VALUES (@name,@steamId,@power,@adder,@days,@adddate)',{['@name'] = name,['@steamId'] = steamId,['@power'] = tonumber(power),['@adder'] = sourceSteam,['@days'] = days, ['@adddate'] = os.time()},function(rowsChanged)
            if rowsChanged == 1 then
                TriggerClientEvent('rio:showNotification', src, "~r~Added~s~ ~g~Priority~s~ for ~p~"..tmp.."~s~!")
                PerformHttpRequest(Config.LogWebhook, function(err, text, headers) end, 'POST', json.encode({embeds={{title='Added Priority',description=xPlayer.getName().." added priority of power: "..tonumber(power).." to "..steamId.."/"..name.." for "..days.." days",color=17499}}}), { ['Content-Type'] = 'application/json' })
            else
                TriggerClientEvent('rio:showNotification', src, "~r~An error has occured")
            end
        end)
    end
end)

function Queue:DebugPrint(msg)
    if Queue.Debug then
        msg = "^3QUEUE: ^0" .. tostring(msg) .. "^7"
        print(msg)
    end
end

function Queue:HexIdToSteamId(hexId)
    local cid = math_floor(tonumber(string_sub(hexId, math.floor(7)), math.floor(16)))
	local steam64 = math_floor(tonumber(string_sub( cid, math.floor(2))))
	local a = steam64 % math.floor(2) == math.floor(0) and math.floor(0) or math.floor(1)
	local b = math_floor(math_abs(6561197960265728 - steam64 - a) / math.floor(2))
	local sid = "steam_0:"..a..":"..(a == math.floor(1) and b -math.floor(1) or b)
    return sid
end

function Queue:IsSteamRunning(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if string_sub(id, math.floor(1), math.floor(5)) == "steam" then
            return true
        end
    end
    
    return false
end

function Queue:GetPlayerCount()
    return _Queue.PlayerCount
end

function Queue:GetSize()
    return #_Queue.QueueList
end

function Queue:ConnectingSize()
    return #_Queue.Connecting
end

function Queue:GetQueueList()
    return _Queue.QueueList
end

function Queue:GetPriorityList()
    return _Queue.Priority
end

function Queue:GetPlayerList()
    return _Queue.PlayerList
end

function Queue:GetTempPriorityList()
    return _Queue.TempPriority
end

function Queue:GetConnectingList()
    return _Queue.Connecting
end

function Queue:IsInQueue(ids, rtnTbl, bySource, connecting)
    local connList = Queue:GetConnectingList()
    local queueList = Queue:GetQueueList()

    for genericKey1, genericValue1 in ipairs(connecting and connList or queueList) do
        local inQueue = false

        if not bySource then
            for genericKey2, genericValue2 in ipairs(genericValue1.ids) do
                if inQueue then break end

                for genericKey3, genericValue3 in ipairs(ids) do
                    if genericValue3 == genericValue2 then inQueue = true break end
                end
            end
        else
            inQueue = ids == genericValue1.source
        end

        if inQueue then
            if rtnTbl then
                return genericKey1, connecting and connList[genericKey1] or queueList[genericKey1]
            end

            return true
        end
    end

    return false
end

function Queue:IsPriority(ids)
    local prio = false
    local tempPower, tempEnd = Queue:HasTempPriority(ids)
    local prioList = Queue:GetPriorityList()

    for _, id in ipairs(ids) do
        id = string_lower(id)

        if prioList[id] then prio = prioList[id] break end

        if string_sub(id, 1, 5) == "steam" then
            local steamid = Queue:HexIdToSteamId(id)
            if prioList[steamid] then prio = prioList[steamid] break end
        end
    end

    if tempPower or prio then
        if tempPower and prio then
            return tempPower > prio and tempPower or prio
        else
            return tempPower or prio
        end
    end

    return false
end

function ShowCard(deferrals,priorityType,daysLeft,pos,time)

    if daysLeft == nil then
        if priorityType == "none" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Normal Priority",
                        "horizontalAlignment": "Center",
                        "color": "Accent"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    }
                ]
            }]==])
        elseif priorityType == "bronze" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Bronze Priority",
                        "horizontalAlignment": "Center",
                        "color": "Good"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    }
                ]
            }]==])
        elseif priorityType == "silver" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Silver Priority",
                        "horizontalAlignment": "Center",
                        "color": "Warning"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    }
                ]
            }]==])
        elseif priorityType == "gold" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Gold Priority",
                        "horizontalAlignment": "Center",
                        "color": "Attention"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    }
                ]
            }]==])
        elseif priorityType == "staff" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Staff Priority",
                        "horizontalAlignment": "Center",
                        "color": "Dark"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    }
                ]
            }]==])
        end
    elseif daysLeft == math.floor(-1) then
        if priorityType == "none" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Normal Priority",
                        "horizontalAlignment": "Center",
                        "color": "Accent"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    }
                ]
            }]==])
        elseif priorityType == "bronze" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Bronze Priority",
                        "horizontalAlignment": "Center",
                        "color": "Good"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Never Expires",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        elseif priorityType == "silver" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Silver Priority",
                        "horizontalAlignment": "Center",
                        "color": "Warning"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Never Expires",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        elseif priorityType == "gold" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Gold Priority",
                        "horizontalAlignment": "Center",
                        "color": "Attention"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Never Expires",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        elseif priorityType == "staff" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Staff Priority",
                        "horizontalAlignment": "Center",
                        "color": "Dark"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Never Expires",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        end

    elseif daysLeft <= math.floor(0) then
        if priorityType == "none" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Normal Priority",
                        "horizontalAlignment": "Center",
                        "color": "Accent"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    }
                ]
            }]==])
        elseif priorityType == "bronze" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Bronze Priority",
                        "horizontalAlignment": "Center",
                        "color": "Good"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Expires Today",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        elseif priorityType == "silver" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Silver Priority",
                        "horizontalAlignment": "Center",
                        "color": "Warning"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Expires Today",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        elseif priorityType == "gold" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Gold Priority",
                        "horizontalAlignment": "Center",
                        "color": "Attention"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Expires Today",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        elseif priorityType == "staff" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Staff Priority",
                        "horizontalAlignment": "Center",
                        "color": "Dark"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Expires Today",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Staff Priority",
                        "horizontalAlignment": "Center",
                        "color": "Dark"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Expires Today",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        end
    else
        if priorityType == "none" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Normal Priority",
                        "horizontalAlignment": "Center",
                        "color": "Accent"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    }
                ]
            }]==])
        elseif priorityType == "bronze" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Bronze Priority",
                        "horizontalAlignment": "Center",
                        "color": "Good"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Expires In ]==]..daysLeft..[==[ days",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        elseif priorityType == "silver" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Silver Priority",
                        "horizontalAlignment": "Center",
                        "color": "Warning"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Expires In ]==]..daysLeft..[==[ days",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        elseif priorityType == "gold" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Gold Priority",
                        "horizontalAlignment": "Center",
                        "color": "Attention"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Expires In ]==]..daysLeft..[==[ days",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        elseif priorityType == "staff" then
            deferrals.presentCard([==[{
                "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                "type": "AdaptiveCard",
                "version": "1.2",
                "body": [
                    {
                        "type": "TextBlock",
                        "size": "Medium",
                        "weight": "Bolder",
                        "text": "Staff Priority",
                        "horizontalAlignment": "Center",
                        "color": "Dark"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..time..[==[",
                        "wrap": true,
                        "horizontalAlignment": "Center",
                        "separator": true,
                        "fontType": "Default",
                        "size": "Medium",
                        "weight": "Bolder"
                    },
                    {
                        "type": "TextBlock",
                        "text": "]==]..pos..[==[/]==]..Queue:GetSize()..[==[",
                        "horizontalAlignment": "Center",
                        "size": "ExtraLarge",
                        "weight": "Bolder",
                        "color": "Warning",
                        "fontType": "Monospace"
                    },
                    {
                        "type": "Container",
                        "separator": true,
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": "Expires In ]==]..daysLeft..[==[ days",
                                "spacing": "Large",
                                "fontType": "Monospace",
                                "weight": "Bolder",
                                "color": "Accent",
                                "wrap": true,
                                "horizontalAlignment": "Right",
                                "separator": true
                            }
                        ],
                        "backgroundImage": {
                            "horizontalAlignment": "Center"
                        }
                    }
                ]
            }]==])
        end
    end
    
end


function Queue:HasTempPriority(ids)
    local tmpPrio = Queue:GetTempPriorityList()

    for _, id in pairs(ids) do
        id = string_lower(id)

        if tmpPrio[id] then return tmpPrio[id].power, tmpPrio[id].endTime, id end

        if string_sub(id, math.floor(1), math.floor(5)) == "steam" then
            local steamid = Queue:HexIdToSteamId(id)
            if tmpPrio[steamid] then return tmpPrio[steamid].power, tmpPrio[steamid].endTime, id end
        end
    end

    return false
end

function Queue:AddToQueue(ids, connectTime, name, src, deferrals)
    if Queue:IsInQueue(ids) then return end

    local tmp = {
        source = src,
        ids = ids,
        name = name,
        priority = Queue:IsPriority(ids) or (src == "debug" and math_random(0, 15)),
        timeout = math.floor(0),
        deferrals = deferrals,
        firstconnect = connectTime,
        queuetime = function() return (os_time() - connectTime) end
    }

    local _pos = false
    local queueCount = Queue:GetSize() + math.floor(1)
    local queueList = Queue:GetQueueList()

    for pos, data in ipairs(queueList) do
        if tmp.priority then
            if not data.priority then
                _pos = pos
            else
                if tmp.priority > data.priority then
                    _pos = pos
                end
            end

            if _pos then
                --Queue:DebugPrint(string_format("%s[%s] was prioritized and placed %d/%d in queue", tmp.name, ids[1], _pos, queueCount))
                break
            end
        end
    end

    if not _pos then
        _pos = Queue:GetSize() + 1
        --Queue:DebugPrint(string_format("%s[%s] was placed %d/%d in queue", tmp.name, ids[1], _pos, queueCount))
    end

    table_insert(queueList, _pos, tmp)
end

function Queue:RemoveFromQueue(ids, bySource, byIndex)
    local queueList = Queue:GetQueueList()

    if byIndex then
        if queueList[byIndex] then
            table_remove(queueList, byIndex)
        end

        return
    end

    if Queue:IsInQueue(ids, false, bySource) then
        local pos, data = Queue:IsInQueue(ids, true, bySource)
        table_remove(queueList, pos)
    end
end

function Queue:TempSize()
    local count = math.floor(0)

    for _pos, data in pairs(Queue:GetQueueList()) do
        if Queue:HasTempPriority(data.ids) then count = count + math.floor(1) end
    end

    return count > 0 and count or false
end

function Queue:IsInConnecting(ids, bySource, refresh)
    local inConnecting, tbl = Queue:IsInQueue(ids, refresh and true or false, bySource and true or false, true)

    if not inConnecting then return false end

    if refresh and inConnecting and tbl then
        Queue:GetConnectingList()[inConnecting].timeout = math.floor(0)
    end

    return true
end

function Queue:RemoveFromConnecting(ids, bySource, byIndex)
    local connList = Queue:GetConnectingList()

    if byIndex then
        if connList[byIndex] then
            table_remove(connList, byIndex)
        end

        return
    end

    for genericKey1, genericValue1 in ipairs(connList) do
        local inConnecting = false

        if not bySource then
            for genericKey2, genericValue2 in ipairs(genericValue1.ids) do
                if inConnecting then break end

                for genericKey3, genericValue3 in ipairs(ids) do
                    if genericValue3 == genericValue2 then inConnecting = true break end
                end
            end
        else
            inConnecting = ids == genericValue1.source
        end

        if inConnecting then
            table_remove(connList, genericKey1)
            return true
        end
    end

    return false
end

function Queue:AddToConnecting(ids, ignorePos, autoRemove, done)
    local function remove()
        if not autoRemove then return end

        done(Config.Language.connectingerr)
        Queue:RemoveFromConnecting(ids)
        Queue:RemoveFromQueue(ids)
        Queue:DebugPrint("Player could not be added to the connecting list")
    end

    local connList = Queue:GetConnectingList()

    if Queue:ConnectingSize() + Queue:GetPlayerCount() + math.floor(1) > Queue.MaxPlayers then remove() return false end
    
    if ids[1] == "debug" then
        table_insert(connList, {source = ids[1], ids = ids, name = ids[1], firstconnect = ids[1], priority = ids[1], timeout = math.floor(0)})
        return true
    end

    if Queue:IsInConnecting(ids) then Queue:RemoveFromConnecting(ids) end

    local pos, data = Queue:IsInQueue(ids, true)
    if not ignorePos and (not pos or pos > 1) then remove() return false end

    table_insert(connList, data)
    Queue:RemoveFromQueue(ids)

    return true
end

function Queue:GetIds(src)
    local ids = GetPlayerIdentifiers(src)
    local ip = GetPlayerEndpoint(src)

    ids = (ids and ids[1]) and ids or (ip and {"ip:" .. ip} or false)
    ids = ids ~= nil and ids or false

    if ids and #ids > 1 then
        for k, id in ipairs(ids) do
            if string_sub(id, math.floor(1), math.floor(3)) == "ip:" and not Queue:IsPriority({id}) then table_remove(ids, k) end
        end
    end

    return ids
end

function Queue:AddPriority(id, power, temp)
    if not id then return false end

    if type(id) == "table" then
        for _id, power in pairs(id) do
            if _id and type(_id) == "string" and power and type(power) == "number" then
                Queue:GetPriorityList()[_id] = power
            else
                Queue:DebugPrint("Error adding a priority id, invalid data passed")
                return false
            end
        end

        return true
    end

    power = (power and type(power) == "number") and power or 10

    if temp then
        local tempPower, tempEnd, tempId = Queue:HasTempPriority({id})
        id = tempId or id

        Queue:GetTempPriorityList()[string_lower(id)] = {power = power, endTime = os_time() + temp} 
    else
        Queue:GetPriorityList()[string_lower(id)] = power
    end
    
    return true
end

function Queue:RemovePriority(id)
    if not id then return false end
    id = string_lower(id)
    Queue:GetPriorityList()[id] = nil
    return true
end

function Queue:UpdatePosData(src, ids, deferrals)
    local pos, data = Queue:IsInQueue(ids, true)
    data.source = src
    data.ids = ids
    data.timeout = 0
    data.firstconnect = os_time()
    data.name = GetPlayerName(src)
    data.deferrals = deferrals
end

function Queue:NotFull(firstJoin)
    local canJoin = Queue:GetPlayerCount() + Queue:ConnectingSize() < Queue.MaxPlayers
    if firstJoin and canJoin then canJoin = Queue:GetSize() <= 1 end
    return canJoin
end

function Queue:SetPos(ids, newPos)
    if newPos <= 0 or newPos > Queue:GetSize() then return false end

    local pos, data = Queue:IsInQueue(ids, true)
    local queueList = Queue:GetQueueList()

    table_remove(queueList, pos)
    table_insert(queueList, newPos, data)
end

function Queue:CanJoin(src, cb)
    local allow = true

    for _, data in ipairs(_Queue.JoinCbs) do
        local await = true

        data.func(src, function(reason)
            if reason and type(reason) == "string" then allow = false cb(reason) end
            await = false
        end)

        while await do Citizen.Wait(0) end

        if not allow then return end
    end

    if allow then cb(false) end
end

function Queue:OnJoin(cb, resource)
    if not cb then return end

    local tmp = {resource = resource, func = cb}
    table_insert(_Queue.JoinCbs, tmp)
end

exports("GetQueueExports", function()
    return Queue
end)

local function playerConnect(name, setKickReason, deferrals)
    local src = source
    
    local ids = Queue:GetIds(src)
    local name = GetPlayerName(src)
    local connectTime = os_time()
    local connecting = true


    deferrals.defer()
    
    Citizen.CreateThread(function()
        while connecting do
            Citizen.Wait(100)
            if not connecting then return end
            if not isWaitingForElites then
                --deferrals.update(Config.Language.connecting)
            end
        end
    end)

    Citizen.Wait(500)
    local PWR = _Queue.Priority[ids[1]]
    if PWR == nil then
        PWR = "null"
    end
    if not src then 
        return
    end


    playerIP = GetPlayerEP(src)
    if placed ~= nil then
        if string.match(playerIP, ":") then
            playerIP = splitString(playerIP, ":")[1]
        end
    end
    for k,v in pairs(Config.PriorityIps) do
        if v.ip == playerIP then
            Queue:AddPriority(ids[1], v.power, Config.GraceTime) 
        end
    end
    local function done(msg, _deferrals)
        connecting = false

        local deferrals = _deferrals or deferrals

        if msg then deferrals.update(tostring(msg) or "") end

        Citizen.Wait(500)
        Citizen.CreateThread(function()
            if not msg then
                deferrals.done()
                if Config.EnableGrace and ids ~= nil then 
                    Queue:AddPriority(ids[1], Config.GracePower, Config.GraceTime) 
                end
            else
                deferrals.done(tostring(msg) or "") CancelEvent()
            end
        end)
        return
    end

    local function update(msg, _deferrals)
        local deferrals = _deferrals or deferrals
        connecting = false
        deferrals.update(tostring(msg) or "")
    end

    if not ids then
        -- prevent joining
        done(Config.Language.iderr)
        CancelEvent()
        Queue:DebugPrint("Dropped " .. name .. ", couldn't retrieve any of their id's")
        return
    end

    if Config.RequireSteam and not Queue:IsSteamRunning(src) then
        -- prevent joining
        done(Config.Language.steam)
        CancelEvent()
        return
    end

    local allow

    Queue:CanJoin(src, function(reason)
        if reason == nil or allow ~= nil then return end
        if reason == false or #_Queue.JoinCbs <= 0 then allow = true return end

        if reason then
            -- prevent joining
            allow = false
            done(reason and tostring(reason) or "You were blocked from joining")
            Queue:RemoveFromQueue(ids)
            Queue:RemoveFromConnecting(ids)
            Queue:DebugPrint(string_format("%s[%s] was blocked from joining; Reason: %s", name, ids[1], reason))
            CancelEvent()
            return
        end

        allow = true
       
    end) 

    while allow == nil do Citizen.Wait(0) end
    if not allow then return end

    if serverStarting then
        while serverStarting do
            deferrals.update(string.format("Loading Database.. Please Wait"))
            Wait(1000)
        end
        --deferrals.update(Config.Language.connecting)
    end

    if Config.PriorityOnly and not Queue:IsPriority(ids) then done(Config.Language.wlonly) return end
    if Config.PriorityOnlyOnStartup and not Queue:IsPriority(ids) then 
        deferrals.defer()
        while isWaitingForElites do
            Wait(1000)
            local seconds = tonumber((Config.PriorityOnlyOnStartupTime*60)-entryCounter)
            if seconds > 59 then
                local minutes = tonumber(seconds/60)
                seconds = seconds % math.floor(60)
                deferrals.update(string.format("Hello %s. Please wait %d:%d While Players With Priority Connecting.", name,math.floor(minutes),math.floor(seconds)))
            else
                deferrals.update(string.format("Hello %s. Please wait %d While Players With Priority Connecting.", name,seconds))
            end           
        end
    end

    local rejoined = false

    if Queue:IsInConnecting(ids, false, true) then
        Queue:RemoveFromConnecting(ids)

        if Queue:NotFull() then
            -- let them in the server

            if not Queue:IsInQueue(ids) then
                Queue:AddToQueue(ids, connectTime, name, src, deferrals)
            end

            local added = Queue:AddToConnecting(ids, true, true, done)
            if not added then CancelEvent() return end
            done()

            return
        else
            rejoined = true
        end
    end

    if Queue:IsInQueue(ids) then
        rejoined = true
        Queue:UpdatePosData(src, ids, deferrals)
        --Queue:DebugPrint(string_format("%s[%s] has rejoined queue after cancelling", name, ids[1]))
    else
        Queue:AddToQueue(ids, connectTime, name, src, deferrals)

        if rejoined then
            Queue:SetPos(ids, math.floor(1))
            rejoined = false
        end
    end

    local pos, data = Queue:IsInQueue(ids, true)
    
    if not pos or not data then
        done(Config.Language.err .. " [1]")

        Queue:RemoveFromQueue(ids)
        Queue:RemoveFromConnecting(ids)

        CancelEvent()
        return
    end

    if Queue:NotFull(true) and _Queue.JoinDelay <= GetGameTimer() then
        -- let them in the server
        local added = Queue:AddToConnecting(ids, true, true, done)
        if not added then CancelEvent() return end

        done()
        --Queue:DebugPrint(name .. "[" .. ids[1] .. "] is loading into the server")

        return
    end

    local power = _Queue.Priority[ids[1]]
	local show = _Queue.DaysLeft[ids[1]]
	Wait(50)
	if power == nil or power < 60 then
		ShowCard(deferrals,"none",show,pos,"00:00:00")
	elseif power >= 60 and power < 70 then
		ShowCard(deferrals,"bronze",show,pos,"00:00:00")
	elseif power >= 70 and power < 80 then
		ShowCard(deferrals,"silver",show,pos,"00:00:00")
	elseif power >= 80 and power < 92 then
		ShowCard(deferrals,"gold",show,pos,"00:00:00")
	elseif power >= 92 then
		ShowCard(deferrals,"staff",show,pos,"00:00:00")
	end
	--[[ if show == nil then
		update(string_format("~g~Test"..Config.Language.pos .. ((Queue:TempSize() and Config.ShowTemp) and " (" .. Queue:TempSize() .. " temp)" or "00:00:00"), pos, Queue:GetSize(), ""))
	else
		update(string_format("~g~Test"..Config.Language.pos .. ((Queue:TempSize() and Config.ShowTemp) and " (" .. Queue:TempSize() .. " temp)" or "00:00:00").." Days Left: "..show, pos, Queue:GetSize(), ""))
    end  ]]

    --if rejoined then return end

    while true do
        Citizen.Wait(500)

        local pos, data = Queue:IsInQueue(ids, true)

        local function remove(msg)
            if data then
                if msg then
                    update(msg, data.deferrals)
                end

                Queue:RemoveFromQueue(data.source, true)
                Queue:RemoveFromConnecting(data.source, true)
            else
                Queue:RemoveFromQueue(ids)
                Queue:RemoveFromConnecting(ids)
            end
        end

        if not data or not data.deferrals or not data.source or not pos then
            remove("[Queue] Removed from queue, queue data invalid :(")
           -- Queue:DebugPrint(tostring(name .. "[" .. ids[1] .. "] was removed from the queue because they had invalid data"))
            return
        end

        local endPoint = GetPlayerEndpoint(data.source)
        if not endPoint then data.timeout = data.timeout + 0.5 else data.timeout = 0 end

        if data.timeout >= Config.QueueTimeOut and os_time() - connectTime > 5 then
            remove("[Queue] Removed due to timeout")
            --Queue:DebugPrint(name .. "[" .. ids[1] .. "] was removed from the queue because they timed out")
            return
        end

        if pos <= 1 and Queue:NotFull() and _Queue.JoinDelay <= GetGameTimer() then
            -- let them in the server
            local added = Queue:AddToConnecting(ids)

            update(Config.Language.joining, data.deferrals)
            Citizen.Wait(500)

            if not added then
                done(Config.Language.connectingerr)
                CancelEvent()
                return
            end

            done(nil, data.deferrals)

            if Config.EnableGrace and ids ~= nil then Queue:AddPriority(ids[1], Config.GracePower, Config.GraceTime) end

            Queue:RemoveFromQueue(ids)
            --Queue:DebugPrint(name .. "[" .. ids[1] .. "] is loading into the server")
            return
        end

        local seconds = data.queuetime()
        local qTime = string_format("%02d", math_floor((seconds % 86400) / 3600)) .. ":" .. string_format("%02d", math_floor((seconds % 3600) / 60)) .. ":" .. string_format("%02d", math_floor(seconds % 60))
        local power = _Queue.Priority[ids[1]]
        local show = _Queue.DaysLeft[ids[1]]
        Wait(50)
        if power == nil or power < 60 then
            ShowCard(deferrals,"none",show,pos,qTime)
        elseif power >= 60 and power < 70 then
            ShowCard(deferrals,"bronze",show,pos,qTime)
        elseif power >= 70 and power < 80 then
            ShowCard(deferrals,"silver",show,pos,qTime)
        elseif power >= 80 and power < 92 then
            ShowCard(deferrals,"gold",show,pos,qTime)
        elseif power >= 92 then
            ShowCard(deferrals,"staff",show,pos,qTime)
        end

    end
end


AddEventHandler("playerConnecting", playerConnect)

Citizen.CreateThread(function()
    local function remove(data, pos, msg)
        if data and data.source then
            Queue:RemoveFromQueue(data.source, true)
            Queue:RemoveFromConnecting(data.source, true)
        elseif pos then
            table_remove(Queue:GetQueueList(), pos)
        end
    end

    while true do
        Citizen.Wait(1000)
    
        local i = 1
    
        while i <= Queue:ConnectingSize() do
            local data = Queue:GetConnectingList()[i]
    
            local endPoint = GetPlayerEndpoint(data.source)
    
            data.timeout = data.timeout + 1
    
            if ((data.timeout >= 300 and not endPoint) or data.timeout >= Config.ConnectTimeOut) and data.source ~= "debug" and os_time() - data.firstconnect > 5 then
                remove(data)
                --Queue:DebugPrint(data.name .. "[" .. data.ids[1] .. "] was removed from the connecting queue because they timed out")
            else
                i = i + 1
            end
        end

        for id, data in pairs(Queue:GetTempPriorityList()) do
            if os_time() >= data.endTime then
                Queue:GetTempPriorityList()[id] = nil
            end
        end
    
        Queue.MaxPlayers = GetConvarInt("sv_maxclients")
        Queue.Debug = GetConvar("sv_debugqueue", "true") == "true" and true or false
        Queue.DisplayQueue = GetConvar("sv_displayqueue", "true") == "true" and true or false

        local qCount = Queue:GetSize()

        if Queue.DisplayQueue then
            if Queue.InitHostName then
                SetConvar("sv_hostname", (qCount > 0 and "[" .. tostring(qCount) .. "] " or "") .. Queue.InitHostName)
            else
                Queue.InitHostName = GetConvar("sv_hostname")
                Queue.InitHostName = Queue.InitHostName ~= "default FXServer" and Queue.InitHostName or false
            end
        end
    end
end)

RegisterServerEvent("Queue:playerActivated")
AddEventHandler("Queue:playerActivated", function()
    local src = source
    local ids = Queue:GetIds(src)

    if not Queue:GetPlayerList()[src] then
        _Queue.PlayerCount = Queue:GetPlayerCount() + 1
        Queue:GetPlayerList()[src] = true
        Queue:RemoveFromQueue(ids)
        Queue:RemoveFromConnecting(ids)
    end
end)

AddEventHandler("playerDropped", function()
    local src = source
    local ids = Queue:GetIds(src)

    if Queue:GetPlayerList()[src] then
        _Queue.PlayerCount = Queue:GetPlayerCount() - 1
        Queue:GetPlayerList()[src] = nil
        Queue:RemoveFromQueue(ids)
        Queue:RemoveFromConnecting(ids)
        if Config.EnableGrace then Queue:AddPriority(ids[1], Config.GracePower, Config.GraceTime) end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if Queue.DisplayQueue and Queue.InitHostName and resource == GetCurrentResourceName() then SetConvar("sv_hostname", Queue.InitHostName) end
    
    for k, data in ipairs(_Queue.JoinCbs) do
        if data.resource == resource then
            table_remove(_Queue.JoinCbs, k)
        end
    end
end)

AddEventHandler("onResourceStarting", function(resource)
    if resource == "hardcap" or resource == "connectqueue" then CancelEvent() return end
end)

StopResource("hardcap")
StopResource("connectqueue")

local testAdds = 0
local commands = {}

commands.addq = function()
    Queue:DebugPrint("ADDED DEBUG QUEUE")
    Queue:AddToQueue({"steam:110000103fd1bb1"..testAdds}, os_time(), "TestAdd: " .. testAdds, "debug")
    testAdds = testAdds + 1
end

commands.removeq = function(args)
    args[1] = tonumber(args[1])
    local name = Queue:GetQueueList()[args[1]] and Queue:GetQueueList()[args[1]].name or nil
    Queue:RemoveFromQueue(nil, nil, args[1])
    Queue:DebugPrint("REMOVED " .. tostring(name) .. " FROM THE QUEUE")
end

commands.printq = function()
    Queue:DebugPrint("CURRENT QUEUE LIST")

    for pos, data in ipairs(Queue:GetQueueList()) do
        Queue:DebugPrint(pos .. ": [src: " .. data.source .. "] " .. data.name .. "[" .. data.ids[1] .. "] | Priority: " .. (tostring(data.priority and data.priority or false)) .. " | Last Msg: " .. (data.source ~= "debug" and GetPlayerLastMsg(data.source) or "debug") .. " | Timeout: " .. data.timeout .. " | Queue Time: " .. data.queuetime() .. " Seconds")
    end
end

commands.addc = function()
    Queue:AddToConnecting({"debug"})
    Queue:DebugPrint("ADDED DEBUG CONNECTING QUEUE")
end

commands.removec = function(args)
    args[1] = tonumber(args[1])
    local name = Queue:GetConnectingList()[args[1]] and Queue:GetConnectingList()[args[1]].name or nil
    Queue:RemoveFromConnecting(nil, nil, args[1])
    Queue:DebugPrint("REMOVED " .. tostring(name) .. " FROM THE CONNECTING LIST")
end

commands.printc = function()
    Queue:DebugPrint("CURRENT CONNECTING LIST")

    for pos, data in ipairs(Queue:GetConnectingList()) do
        Queue:DebugPrint(pos .. ": [src: " .. data.source .. "] " .. data.name .. "[" .. data.ids[1] .. "] | Priority: " .. (tostring(data.priority and data.priority or false)) .. " | Last Msg: " .. (data.source ~= "debug" and GetPlayerLastMsg(data.source) or "debug") .. " | Timeout: " .. data.timeout)
    end
end

commands.printl = function()
    for k, joined in pairs(Queue:GetPlayerList()) do
        Queue:DebugPrint(k .. ": " .. tostring(joined))
    end
end

commands.printp = function()
    Queue:DebugPrint("CURRENT PRIORITY LIST")

    for id, power in pairs(Queue:GetPriorityList()) do
        Queue:DebugPrint(id .. ": " .. tostring(power))
    end
end

commands.printcount = function()
    Queue:DebugPrint("Player Count: " .. Queue:GetPlayerCount())
end

commands.printtp = function()
    Queue:DebugPrint("CURRENT TEMP PRIORITY LIST")

    for k, data in pairs(Queue:GetTempPriorityList()) do
        Queue:DebugPrint(k .. ": Power: " .. tostring(data.power) .. " | EndTime: " .. tostring(data.endTime) .. " | CurTime: " .. tostring(os_time()))
    end
end

commands.removetp = function(args)
    if not args[1] then return end

    Queue:GetTempPriorityList()[args[1]] = nil
    Queue:DebugPrint("REMOVED " .. args[1] .. " FROM THE TEMP PRIORITY LIST")
end

commands.setpos = function(args)
    if not args[1] or not args[2] then return end

    args[1], args[2] = tonumber(args[1]), tonumber(args[2])

    local data = Queue:GetQueueList()[args[1]]

    Queue:SetPos(data.ids, args[2])

    Queue:DebugPrint("SET " .. data.name .. "'s QUEUE POSITION TO: " .. args[2])
end

commands.setdata = function(args)
    if not args[1] or not args[2] or not args[3] then return end
    args[1] = tonumber(args[1])

    local num = tonumber(args[3])
    local data = Queue:GetQueueList()[args[1]]

    if args[2] == "queuetime" then
        local time = data.queuetime()
        local dif = time - num

        data.firstconnect = data.firstconnect + dif
        data.queuetime = function() return (os_time() - data.firstconnect) end
    else
        data[args[2]] = num and num or args[3]
    end

    Queue:DebugPrint("SET " .. data.name .. "'s " .. args[2] .. " DATA TO " .. args[3])
end

commands.commands = function()
    for cmd, func in pairs(commands) do
        Queue:DebugPrint(tostring(cmd))
    end
end

AddEventHandler("rconCommand", function(command, args)
    if command == "queue" and commands[args[1]] then
        command = args[1]
        table_remove(args, 1)
        commands[command](args)
        CancelEvent()
    end
end)

function IsPriorityJob(jobName)
    for k,v in pairs(Config.PriorityJobs) do
        if jobName == v.job then
            return v.power
        end
    end
    return 0
end



CreateThread(function()
    Wait(1000)
    while true do
        entryCounter = entryCounter + 1
        if entryCounter == Config.PriorityOnlyOnStartupTime * 60 then
            isWaitingForElites = false
            break
        end
        Wait(1000)
    end
end)