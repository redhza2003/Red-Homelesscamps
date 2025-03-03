local Config = require 'config.server'
local Shared = require 'config.shared'

local homelesscamps = {}
local ox_inventory = exports.ox_inventory


--- Functions 

-- Forked From qbx_core .
---@deprecated use lib.string.random from ox_lib
function RandomInt(length)
    if length <= 0 then return '' end

    ---@diagnostic disable-next-line: deprecated
    return RandomInt(length - 1) .. lib.string.random('1')
end

---@param charId string Player Identifier 
---@return unique id string
function getUniqueStash(charId)
    local str = ''
    for i = 1, 5, 2 do str = str .. RandomInt(i)  end

    return charId .. tostring(str)
end


--- Fetch homelesscamps from the data base.
function fetchHomelessCamps()
    local result = MySQL.query.await('SELECT name, owned, coords, location, weight, slots, durability, accesses, UNIX_TIMESTAMP(created) FROM homelesscamps')
    if result and result[1] then
        for _, data in pairs(result) do
            exports.ox_inventory:RegisterStash(('homelesscamps-%s'):format(data.name), locale("stash_label"), tonumber(data.slots), tonumber(data.weight) * 1000)
            homelesscamps[data.name] = {
                name = data.name,
                owned = data.owned,
                coords = json.decode(data.coords),
                location = data.location,
                weight = data.weight,
                slots = data.slots,
                durability = data.durability,
                accesses = json.decode(data.accesses),
                created = os.date("%Y-%m-%d", data.created)
            }
        end
    end
end

--- Calculate all homelesscamps durability .
function calcDurability()
    for id, data in pairs(homelesscamps) do
        if data?.durability > 0 then
            if math.random(100) == Shared.expire.chance then
                local deGrade = math.random(Shared.expire.decay['min'], Shared.expire.decay['max'])
                homelesscamps[id].durability = math.max(data.durability - deGrade, 0)
                MySQL.prepare.await("UPDATE homelesscamps SET durability = ? WHERE name = ?", {homelesscamps[id].durability, id})
                TriggerClientEvent("red-homelesscamps:client:updateTent", -1, homelesscamps[id])
            end
        end
    end
end

--- Network Events

RegisterNetEvent("red-homelesscamps:server:createNewTent", function(item, location, coords)
    local src = source
    local player = getPlayer(src)
    
    if not player or not item then return end
    
    local durability, stashId, weight, slots, accesses in item.metadata

    if ox_inventory:RemoveItem(source, Shared.itemName, 1, item.metadata, item.slot) then
        local stash = {
            id = stashId or getUniqueStash(player.charId),
            slots = slots or Config.default.slots, -- Default
            weight = weight or Config.default.weight
        }
        
        if stash.id then 
            local success = MySQL.insert.await("INSERT INTO homelesscamps (name, owned, coords, location, weight, slots, durability, accesses) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", { stash.id, player.charId, json.encode(coords), location, stash.weight, stash.slots, durability or 100, json.encode(accesses or {})})

            if success then
                local currentTime = os.time()

                local newData = {name = stash.id, owned = player.charId, coords = coords, location = location, weight = stash.weight, slots = stash.slots, durability = durability or 100, accesses = accesses or {}, created = os.date("%Y-%m-%d", currentTime)}
                homelesscamps[stash.id] = newData

                ox_inventory:RegisterStash(('homelesscamps-%s'):format(stash.id), locale("stash_label"), stash.slots, tonumber(stash.weight) * 1000)
                TriggerClientEvent("red-homelesscamps:client:createNewTent", -1, newData)

                if Config.logging.enabled then
                    createLog(src, 'Create New Tent', ('player info : (name : %s, identifier : %s, id : %s) tent : (name : %s, location : %s, coords : %s)'):format(player.name, player.charId, src, stash.id, location, coords))
                end
            end 
        end
    end
end)

RegisterNetEvent("red-homelesscamps:server:purchaseItem", function(amount)
    local src = source
    local player = getPlayer(src)
    if not player then return end

    local price = Shared.itemPrice * amount
    if player.money?.cash < price then return end 

    if removeMoney(src, 'cash', price) then
        ox_inventory:AddItem(src, Shared.itemName, amount)
        notify(src, locale("got_item", Shared.itemName), 'success')
    
        if Config.logging.enabled then
            createLog(src, 'Pruchase ' .. Shared.itemName, ('player info : (name : %s, identifier : %s, id : %s) pruchase info : (item : %s, amount : %s, price : %s) '):format(player.name, player.charId, src, Shared.itemName, amount, price))
        end        
    end
end)

RegisterNetEvent("red-homelesscamps:server:upgradeTent", function(name, slots, weight)
    local src = source
    local player = getPlayer(src)

    if not player or not homelesscamps[name] then return end 

    local total = (weight * Shared.updGrade.weight['price']) + (slots * Shared.updGrade.slots['price'])
    if player.money.cash < total then return end 

    if removeMoney(src, 'cash', total) then
        local success = MySQL.prepare.await("UPDATE homelesscamps SET weight = ?, slots = ? WHERE name = ?", {weight, slots, name})
        
        if success then
            notify(src, locale("successfully_upgradetent"), 'success')

            homelesscamps[name].weight += weight
            homelesscamps[name].slots += slots
            exports.ox_inventory:RegisterStash(('homelesscamps-%s'):format(name), locale("stash_label"), homelesscamps[name].slots, homelesscamps[name].weight * 1000)
    
            TriggerEvent("red-homelesscamps:client:updateTent", -1, homelesscamps[name]) 

            if Config.logging.enabled then
                createLog(src, 'Upgrade Tent', ('player info : (name : %s, identifier : %s, id : %s) tent : (name : %s, location : %s, newWeight : %s, newSlots : %s)'):format(player.name, player.charId, src, name, homelesscamps[name].location, homelesscamps[name].weight, homelesscamps[name].slots))
            end
        end
    end
end)

RegisterNetEvent("red-homelesscamps:server:giveAccess", function(name, targetId)
    local src = source
    local player = getPlayer(src)
    
    if not player or not homelesscamps[name] then return end 

    local target = getPlayer(targetId)
    if not target then return end 

    local success, hasAccess = pcall(function()
        if table.type(homelesscamps[name].accesses) == 'empty' then return false end

        for i = 1, #homelesscamps[name].accesses do
            if homelesscamps[name].accesses[i]?.charId == target.charId then
                return true 
            end
        end
    end)

    if hasAccess then
        notify(src, locale("person_has_access"), 'error')

        return 
    end

    local accepted = lib.callback.await("red-homelesscamps:client:givePlayerAccess", targetId, player.name)
    if accepted then
        homelesscamps[name].accesses[#homelesscamps[name].accesses + 1] = {charId = target.charId, name = target.name}

        local success = MySQL.prepare.await("UPDATE homelesscamps SET accesses = ? WHERE name = ?", {json.encode(homelesscamps[name].accesses), name})
        
        if success then
            notify(src, locale("successfully_gaveAccess", target.name), 'sucess')
    
            TriggerClientEvent("red-homelesscamps:client:updateTent", src, homelesscamps[name])
            TriggerClientEvent("red-homelesscamps:client:updateTent", targetId, homelesscamps[name])
    
            if Config.logging.enabled then
                createLog(src, 'Give Access', ('player info : (name : %s, identifier : %s, id : %s) gaved access : (name : %s, identifier : %s) tent : (name : %s, location : %s)'):format(player.name, player.charId, src, target.name, target.charId, name, homelesscamps[name].location))
            end 
        end
    else
        notify(src, locale("decline_access", target.name), 'error')
    end
end)

RegisterNetEvent("red-homelesscamps:server:removeAccess", function(name, charId)
    local src = source
    local player = getPlayer(src)

    if not player or not homelesscamps[name] then return end 

    local success, removed = pcall(function()
        for i = 1, #homelesscamps[name].accesses do
            local access = homelesscamps[name].accesses[i]
            
            if access then
                if access.charId == charId then
                    homelesscamps[name].accesses[i] = nil
                    return true
                end
            end
        end
    end)

    if removed then
        local success = MySQL.prepare.await("UPDATE homelesscamps SET accesses = ? WHERE name = ?", {json.encode(homelesscamps[name].accesses), name})
        
        if success then
            notify(src, locale("successfully_removeaccess", charId), 'sucess')
            TriggerClientEvent("red-homelesscamps:client:updateTent", src, homelesscamps[name])
    
            local target = getByCharId(charId)
            if not target then return end 
    
            notify(target.src, locale("removedaccess", player.charId), 'sucess')
            TriggerClientEvent("red-homelesscamps:client:updateTent", target.src, homelesscamps[name])
        
            if Config.logging.enabled then
                createLog(src, 'Remove Access', ('player info : (name : %s, identifier : %s, id : %s) removed access : (name : %s, identifier : %s) tent : (name : %s, location : %s)'):format(player.name, player.charId, src, target.name, target.charId, name, homelesscamps[name].location))
            end 
        end
    end    
end)

RegisterNetEvent("red-homelesscamps:server:repairTent", function(name, count)
    local src = source
    local player = getPlayer(src)

    if not player or not homelesscamps[name] then return end 

    local price = Shared.expire.repairCost * count
    if player.money?.cash < price then return end 

    if removeMoney(src, 'cash', price) then
        homelesscamps[name].durability += count
        local success = MySQL.prepare.await("UPDATE homelesscamps SET durability = ? WHERE name = ?", {homelesscamps[name].durability, name})
    
        if success then
            notify(src, locale("successfully_repaired"), 'sucess')
            TriggerClientEvent("red-homelesscamps:client:updateTent", -1, homelesscamps[name])

            if Config.logging.enabled then
                createLog(src, 'Repair Tent', ('player info : (name : %s, identifier : %s, id : %s) tent : (name : %s, location : %s, newDurability : %s)'):format(player.name, player.charId, src, name, homelesscamps[name].location, homelesscamps[name].durability))
            end  
        end        
    end
end)

RegisterNetEvent("red-homelesscamps:server:pickupTent", function(name)
    local src = source
    local player = getPlayer(src)

    if not player or not homelesscamps[name] then return end 

    local location, durability, weight, slots, accesses in homelesscamps[name]

    if durability > 0 then
        local metadata = { durability = durability, stashId = name, weight = weight, slots = slots, accesses = accesses}
        ox_inventory:AddItem(src, Shared.itemName, 1, metadata, false)
    else
        notify(src, locale("unusable"), 'error')
    end

    local response = MySQL.query.await("DELETE FROM homelesscamps WHERE name = ?", { name })

    if response then
        TriggerClientEvent("red-homelesscamps:client:destroyTent", -1, location, name)
        notify(src, locale("successfully_pickedup"), 'sucess')

        if Config.logging.enabled then
            createLog(src, 'PickUP Tent', ('player info : (name : %s, identifier : %s, id : %s) picked up tent : (name : %s, location : %s, durability : %s)'):format(player.name, player.charId, src, name, location, durability))
        end
        homelesscamps[name] = nil 
    end
end)

--- OX Callbacks 

lib.callback.register("red-homelesscamps:server:canUseItem", function(source, item)
    local src = source
    local player = getPlayer(src)

    if not player or not item then return false, 'Faiied to use item' end 

    if item.metadata?.durability then 
        if item.metadata.durability <= 5 then
            return false, locale("low_durability") 
        end     
    end

    if table.type(homelesscamps) ~= 'empty' then
        local tentsCreated = 0
        for _, data in pairs(homelesscamps) do
            if data?.owned == player.charId then
                tentsCreated += 1        
            end
        end 
        
        if tentsCreated >= Config.maxTents then 
            return false, locale("exceeding_max") 
        end  
    end


    return true 
end)

lib.callback.register("red-homelesscamps:server:getLocationTents", function(_, location)
    local cacheData = {}

    if table.type(homelesscamps) == 'empty' then return false end 

    for id, data in pairs(homelesscamps) do
        if data?.location == location then
            cacheData[id] = data
        end
    end

    return cacheData 
end)

lib.callback.register("red-homelesscamps:server:getOwnedTents", function(source)
    local src = source
    local player = getPlayer(src)
    if not player then return end 

    local createdTents = {}

    for id, data in pairs(homelesscamps) do
        if data?.owned == player.charId then
            createdTents[#createdTents+1] = data
        end
    end

    return createdTents
end)

lib.callback.register("red-homelesscamps:server:getClosestPlayers", function(source)
    local src = source
    local player = getPlayer(src)
    if not player then return end 

    local players = {}

    local playerPed = GetPlayerPed(src)
    local closestPlayers = lib.getNearbyPlayers(GetEntityCoords(playerPed), Config.closestDistance)
    if #closestPlayers < 1 then return false end 

    for i = 1, #closestPlayers do
        local playerId = closestPlayers[i].id
        local target = getPlayer(playerId)
        
        if target then
            if playerId ~= src then 
                players[i] = {
                    label = target.name ..' ['..playerId..']', 
                    value = playerId
                }    
            end
        end
    end
    
    return players 
end)


--- OX CORN

if Shared.expire?.enabled then
    --- Durability is updated at both 11am and 23pm o'clock
    lib.cron.new('* 11,23 * * *', calcDurability)
end


--- Swap Hook 

--- Prevent items from Config.blackListItems
ox_inventory:registerHook('swapItems', function(payload)
    local items = Config.blackListItems

    for i = 1, #items do
        local item = items[i]

        if item then
            if payload.fromSlot?.name == item then
                return false 
            end
        end
    end

    return true 
end, { inventoryFilter = {'^homelesscamps-%w+'} })

--- Command 

lib.addCommand('setDurability', {
    help = 'Set homelesscamp durability',
    params = {
        {
            name = 'name',
            type = 'string',
            help = 'Name of the tent, You can get the name from your db',
        },
        {
            name = 'durability',
            type = 'number',
            help = 'New durability for the tent',
        }
    },
    restricted = 'group.admin'
}, function(source, args, raw)
    local src = source
    local player = getPlayer(src)

    if not player or not homelesscamps[args.name] then return end

    MySQL.prepare.await("UPDATE homelesscamps SET durability = ? WHERE name = ?", {args.durability, args.name})
    homelesscamps[args.name].durability = args.durability

    TriggerClientEvent("red-homelesscamps:client:updateTent", -1, homelesscamps[args.name])
end)

--- Threads 

CreateThread(function()
    fetchHomelessCamps()
end)


--- MySQL Ready 

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `homelesscamps` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `name` VARCHAR(255) NOT NULL DEFAULT '',
            `owned` VARCHAR(45) NOT NULL DEFAULT '',
            `coords` TEXT DEFAULT NULL,
            `location` VARCHAR(255) NOT NULL DEFAULT '',
            `weight` BIGINT DEFAULT NULL,
            `slots` BIGINT DEFAULT NULL,
            `durability` BIGINT DEFAULT NULL,
            `accesses` TEXT COLLATE 'utf8mb3_general_ci' DEFAULT NULL,
            `created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`) USING BTREE
        ) ENGINE=InnoDB AUTO_INCREMENT=42 DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
    ]])
end)
