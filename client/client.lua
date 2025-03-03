local Config = require 'config.client'
local Shared = require 'config.shared'

local whiteListLocations = {}
local homelessPed = {}

local placerEntity = nil
local whiteList = nil

local ox_inventory = exports.ox_inventory
local playerState = LocalPlayer.state
local handler = AddEventHandler

--- Functions

--- Function that's triggered when Enter White List Zone Or Updated
---@param location string
---@param tent table
function spawnObject(location, tent)
    if not whiteListLocations[location].entities then
        whiteListLocations[location].entities = {}
    end
    local model = Config.propModel
    lib.requestModel(model, 1000)

    local entity = CreateObject(model, tent.coords.x, tent.coords.y, tent.coords.z + Config.minusZ, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(entity, tent.w)
    FreezeEntityPosition(entity, true)
    whiteListLocations[location].entities[tent.name] = entity

    addEntityInteraction(entity, Config.targetDistance, {
        {
            name = 'red-homelesscamps:addTentTarget'..tent.name,
            label = locale("open_tent"),
            icon = 'fas fa-tents',
            event = 'red-homelesscamps:client:openTent',
            tent = tent,
            distance = Config.targetDistance,
            canInteract = function()
                local playerData = getPlayerData()

                if playerData then
                    if tent.owned == playerData.charId then
                        return true
                    end

                    if table.type(tent.accesses) ~= 'empty' then
                        for i = 1, #tent.accesses do
                            if tent.accesses[i]?.charId == playerData.charId then
                                return true
                            end
                        end
                    end
                end

                return false
            end
        }
    })
end

--- Function that's triggered when player logged in to set whitelist locations .
function setupLocations()
    for location, v in pairs(Config.whiteListLocations) do
        if not whiteListLocations[location] then 
            whiteListLocations[location] = {} 
        end

        local zone = lib.zones.poly({
            points = v.points,
            thickness = v.thickness,
            debug = v.debug,

            onEnter = function()                
                local result = lib.callback.await("red-homelesscamps:server:getLocationTents", 100, location)
                if not result then goto skip end

                for _, tent in pairs(result) do
                    spawnObject(location, tent)
                end
                ::skip::
                if not whiteList then whiteList = location end
            end,

            onExit = function()
                local entities = whiteListLocations[location].entities

                if entities then 
                    for name, entity in pairs(entities) do
                        if DoesEntityExist(entity) then
                            SetEntityAsMissionEntity(entity, true, true)
                            DeleteObject(entity)
    
                            removeEntityInteraction(entity, 'red-homelesscamps:addTentTarget'..name)
                        end
                    end    
                end

                if whiteList then whiteList = nil end
            end
        })


        whiteListLocations[location].zone = zone
    end
end



--- Function that's triggered when the player uses the item : 'homelesscamp'
---@return coords | vector4
function objectPlacer()
    if cache.vehicle or placerEntity then return end
    
    local ped = cache.ped
    local heading = 0.0

    local model = Config.propModel
    lib.requestModel(model, 100)

    local controls = {
        'CONTROLS:   \n',
        'E: Place  \n',
        'X: Cancel  \n',
        '🖱️: Change Heading'
    }

    lib.showTextUI(table.concat(controls), {
        position = 'left-center'
    })

    local entity = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    SetModelAsNoLongerNeeded(model)

    SetEntityAlpha(entity, 150)
    SetEntityCollision(entity, false, false)
    SetEntityInvincible(entity, true)
    FreezeEntityPosition(entity, true)
    SetEntityDrawOutline(entity, true)
    placerEntity = entity

    repeat
        local hit, _, endCoords, _, materialHash = lib.raycast.cam(1, 4) -- Raycast cam .
        if hit then
            if IsControlJustPressed(0, 73) then -- Press X
                lib.hideTextUI()
                DeleteObject(placerEntity)
                placerEntity = nil

                return false
            end

            if IsControlJustPressed(0, 14) then -- Press SCROLL UP
                heading += 5
                if heading > 360 then heading = 360.0 end
            end

            if IsControlJustPressed(0, 15) then -- Press SCROLL DOWN
                heading -= 5
                if heading < 0 then heading = 360.0 end
            end

            if IsControlJustPressed(0, 38) and whiteList then -- Press E
                TaskTurnPedToFaceEntity(ped, placerEntity, 1.0)

                lib.hideTextUI()
                DeleteObject(placerEntity)
                placerEntity = nil

                if lib.progressCircle({
                        duration = 6000,
                        label = locale("put_up"),
                        position = 'bottom',
                        useWhileDead = false,
                        canCancel = true,
                        anim = {
                            scenario = 'WORLD_HUMAN_HAMMERING'  
                        },
                        disable = {
                            car = true,
                            move = true,
                            combat = true
                        },
                    }) then
                        --- Returns Coords | vector4 
                    return vec4(endCoords.x, endCoords.y, endCoords.z, heading)
                else
                    notify(locale("canceled"), 'error')
                    
                    return false
                end
            end

            if not whiteList then
                SetEntityDrawOutlineColor(255, 0, 0, 255)
            else
                SetEntityDrawOutlineColor(0, 0, 0, 50)
            end

            SetEntityCoords(placerEntity, endCoords.x, endCoords.y, endCoords.z)
            SetEntityHeading(placerEntity, heading)
        end

    until not placerEntity
end


--- Function that's triggered when the resource stop .
function destroyTents()
    for location in pairs(whiteListLocations) do
        local zone = whiteListLocations[location].point
        if zone then
            zone:remove()
        end

        local entities = whiteListLocations[location].entities
        if entities then 
            for _, entity in pairs(entities) do
                if DoesEntityExist(entity) then
                    SetEntityAsMissionEntity(entity, true, true)
                    DeleteObject(entity)
                    
                    removeEntityInteraction(entity)
                end
            end    
        end
    end

    if DoesEntityExist(placerEntity) then
        SetEntityAsMissionEntity(placerEntity, true, true)
        DeleteObject(placerEntity)
    end
end

--- Network Events

RegisterNetEvent("red-homelesscamps:client:openDialog", function(data)
    local ped = data.entity

    exports.bl_dialog:showDialog({
        ped = ped,
        dialog = {
            {
                id = 'homeless_first',
                job = locale("dialog.job"),
                name = locale("dialog.name"),
                text = locale("dialog.text"),
                buttons = {
                    {
                        id = 'purchase',
                        label = locale("dialog.buttons.purchase"),
                        close = true,
                        onSelect = function(switchDialog)
                            ::redo::
                            local input = lib.inputDialog(locale("dialog.buttons.purchase"), {
                                {type = 'number', label = locale("amount_of_item"), required = true, min = 1, max = 100}
                            })

                            if input and input[1] then
                                local playerData = getPlayerData()
                                if not playerData then return end 

                                local price = tonumber(input[1]) * Shared.itemPrice 
                                if playerData.money?.cash < tonumber(price) then
                                    notify(locale("no_money"), 'error')
                                    goto redo
                                end

                                TriggerServerEvent("red-homelesscamps:server:purchaseItem", input[1])
                            end
                        end
                    },
                    {
                        id = 'view_locations',
                        label = locale("dialog.buttons.view_locations"),
                        close = true,
                        onSelect = function(switchDialog)
                            local options = {}
                            local locations = Config.whiteListLocations

                            for name, V in pairs(locations) do
                                options[#options+1] = {
                                    title = name,
                                    arrow = true,
                                    icon = 'fas fa-location-crosshairs',
                                    args = name,
                                    onSelect = function(name)
                                        local location = Config.whiteListLocations[name]
                                        if not location then return end 

                                        SetNewWaypoint(location.main.x, location.main.y)
                                        notify(locale("successfully_marked"), 'success')

                                        lib.showContext("view_locations")
                                    end
                                }
                            end

                            lib.registerContext({
                                title = locale("dialog.buttons.view_locations"),
                                id = 'view_locations',
                                options = options
                            })

                            lib.showContext("view_locations")
                        end
                    },
                    {
                        id = 'view_owned_tents',
                        label = locale("dialog.buttons.view_owned_tents"),
                        close = true,
                        onSelect = function(switchDialog)
                            local options = {}
                            local amt = 0
                    
                            local result = lib.callback.await("red-homelesscamps:server:getOwnedTents", 100)
                            if table.type(result) == 'empty' then
                                notify(locale("no_tents"), 'error')
                    
                                return 
                            end
                    
                            for i = 1, #result do
                                amt += 1
                    
                                options[amt] = {
                                    title = locale("tent_id", i),
                                    description = locale("tent_info", result[i].name, result[i].created),
                                    arrow = true,
                                    args = i,
                                    onSelect = function(name)
                                        lib.registerContext({
                                            title = locale("view_info"),
                                            id = 'view_info_context',
                                            menu = 'view_owned_homelesscamps',
                                            options = {
                                                {
                                                    title = locale("info_title"),
                                                    icon = 'fas fa-circle-info',
                                                    metadata = {
                                                        [locale("location_info")] = result[name].location,
                                                        [locale("durability_info")] = result[name].durability
                                                    },
                                                    readOnly = true
                                                },
                                                {
                                                    title = locale("view_gps"),
                                                    icon = 'fas fa-location-crosshairs',
                                                    arrow = true,
                                                    onSelect = function()
                                                        local location = Config.whiteListLocations[result[name].location]
                                                        if not location then return end
                    
                                                        SetNewWaypoint(location.main.x, location.main.y)
                                                        notify(locale("successfully_marked"), 'success')
                    
                                                        lib.showContext("view_info_context")
                                                    end
                                                }
                                            }
                                        })
                    
                                        lib.showContext("view_info_context")
                                    end
                                }
                            end
                    
                    
                            lib.registerContext({
                                title = locale("dialog.buttons.view_owned_tents"),
                                id = 'view_owned_homelesscamps',
                                options = options
                            })
                    
                            lib.showContext("view_owned_homelesscamps")
                        end
                    }
                }
            }
        }
    }) 
end)

RegisterNetEvent("red-homelesscamps:client:repairTent", function(tent)
    local playerData = getPlayerData()

    if not playerData or not tent then return end 
    
    ::redo::
    local input = lib.inputDialog(locale("repair_tent_title", Shared.expire.repairCost), {
        { type = 'slider', required = true, min = 0, max = 100 - tent.durability },
    })

    if input and input[1] then
        local price = tonumber(input[1]) * Shared.expire.repairCost  
        
        if playerData.money?.cash < price then
            notify(locale("no_money"), 'error')
            goto redo -- Redo input .
        end
        
        if lib.progressCircle({
            duration = 6000,
            label = locale("repair_tent"),
            position = 'bottom',
            useWhileDead = false,
            canCancel = true,
            anim = {
                scenario = 'WORLD_HUMAN_HAMMERING'  
            },
            disable = {
                car = true,
                move = true,
                combat = true
            },
        }) then
            TriggerServerEvent("red-homelesscamps:server:repairTent", tent.name, input[1])
        else
            notify(locale("canceld"), 'error')
            TriggerEvent("red-homelesscamps:client:openTent", tent)
        end
    else
        TriggerEvent("red-homelesscamps:client:openTent", tent)
    end
end)

RegisterNetEvent("red-homelesscamps:client:accessManager", function(tent)
    if not tent then return end 

    local options = {}
    options[#options+1] = {
        title = locale("veiw_accesses"),
        description = locale("veiw_accesses_desc"),
        arrow = true,
        icon = 'fas fa-user-group',
        onSelect = function()
            local accesses = {}
            local amt = 0

            if not tent.accesses or #tent.accesses < 1 then 
                notify(locale("no_accesses"), 'error') 
                lib.showContext("access_manager") 
                return 
            end
            
            for i = 1, #tent.accesses do
                amt += 1

                accesses[amt] = {
                    title = ('%s - %s'):format(amt, tent.accesses[i].name),
                    icon = 'fas fa-user',
                    arrow = true,
                    args = tent.accesses[i].charId,
                    onSelect = function(args)
                        local alert = lib.alertDialog({
                            header = locale("homelesscamps"),
                            content = locale("remove_access"),
                            centered = true,
                            cancel = true,
                            labels = {
                                confirm = locale("yes"),
                                cancel = locale("no")
                            }
                        })

                        if alert == 'confirm' then
                            TriggerServerEvent("red-homelesscamps:server:removeAccess", tent.name, args)
                        else
                            lib.showContext("veiw_accesses")
                        end
                    end
                }
            end

            lib.registerContext({
                title = locale("veiw_accesses"),
                id = 'veiw_accesses',
                menu = 'access_manager',
                options = accesses
            })

            lib.showContext('veiw_accesses')
        end
    }

    options[#options+1] = {
        title = locale("give_access"),
        description = locale("give_access_desc"),
        arrow = true,
        icon = 'fas fa-key',
        onSelect = function()
            local closestPlayers = lib.callback.await("red-homelesscamps:server:getClosestPlayers", 200)

            if table.type(closestPlayers) == 'empty' then
                notify(locale("no_nearby"), 'error', 2000)
                lib.showContext("access_manager")
                return 
            end

            local input = lib.inputDialog(locale("give_access"), {
                {
                    type = 'select',
                    label = locale('players'),
                    options = closestPlayers,
                    required = true,
                    searchable = true,
                }
            })

            if input and input[1] then
                TriggerServerEvent("red-homelesscamps:server:giveAccess", tent.name, input[1])
            end
        end
    }

    lib.registerContext({
        title = locale("access_manager"),
        options = options,
        id = 'access_manager',
        menu = 'tent_options'
    })

    lib.showContext("access_manager")
end)

RegisterNetEvent("red-homelesscamps:client:pickupTent", function(tent)
    if not tent then return end 

    local ped = cache.ped
    local animDict, animName = "weapons@first_person@aim_rng@generic@projectile@thermal_charge@", 'plant_floor'
    lib.requestAnimDict(animDict, 100)

    lib.playAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 17)

    if lib.progressCircle({
        duration = 6000,
        label = locale("picked_up"),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
    }) then
        ClearPedTasks(ped)

        TriggerServerEvent("red-homelesscamps:server:pickupTent", tent.name)
    else
        ClearPedTasks(ped)

        notify(locale("canceled"), 'error')
        lib.showContext("tent_options")
    end
end)

RegisterNetEvent("red-homelesscamps:client:openTent", function(data)
    local tent = data.tent
    local playerData = getPlayerData()

    if not playerData or not tent then return end

    local options = {}
    options[#options + 1] = {
        title = locale("open_tent"),
        description = locale("open_tent_desc"),
        icon = 'fas fa-tent',
        arrow = tent.durability > 0,
        disabled = tent.durability <= 0,
        onSelect = function()
            ox_inventory:openInventory('stash', ('homelesscamps-%s'):format(tent.name))
        end
    }

    if playerData.charId == tent.owned then
        options[#options + 1] = {
            title = locale("durability"),
            description = locale("durability_desc", '%'..tostring(tent.durability)),
            icon = 'fas fa-wrench',
            progress = tent.durability > 0 and tent.durability or 100,
            colorScheme = (tent.durability >= 75 and 'green.5' or tent.durability > 25 and 'yellow.5' or 'red.5'),
            args = tent,
            disabled = tent.durability == 100,
            arrow = tent.durability < 100,
            event = 'red-homelesscamps:client:repairTent'
        }

        options[#options + 1] = {
            title = locale("access_manager"),
            description = locale("access_manager_desc"),
            icon = 'fas fa-user-group',
            arrow = true,
            args = tent,
            event = 'red-homelesscamps:client:accessManager'
        }

        options[#options + 1] = {
            title = locale("upgrade_tent"),
            description = locale("upgrade_tent_desc"),
            icon = 'fas fa-pen-to-square',
            arrow = true,
            onSelect = function()
                ::redo::
                local input = lib.inputDialog(locale("upgrade_tent"), {
                    {
                        type = 'number',
                        label = locale("slots"),
                        description = locale("slots_desc", Shared.updGrade.slots['price']),
                        min = 5,
                        max = Shared.updGrade.slots['maximum'],
                        step = 5,
                        required = true
                    },
                    {
                        type = 'slider',
                        label = locale("weight"),
                        min = 10,
                        max = Shared.updGrade.weight['maximum'],
                        required = true,
                        step = 10,
                    }
                })

                if input and input[1] then
                    local total = (Shared.updGrade.slots['price'] * tonumber(input[1])) + (Shared.updGrade.weight['price'] * tonumber(input[2]))
                    if playerData.money?.cash < total then
                        notify(locale("no_money"), 'error')
                        goto redo     -- Redo input .
                    end

                    TriggerServerEvent("red-homelesscamps:server:upgradeTent", tent.name, input[1], input[2])
                else
                    lib.showContext("tent_options")
                end
            end
        }

        options[#options + 1] = {
            title = locale("pickup_tent"),
            description = locale("pickup_tent_desc"),
            icon = 'fa-solid fa-hand',
            arrow = true,
            args = tent,
            event = 'red-homelesscamps:client:pickupTent'
        }
    end

    lib.registerContext({
        title = locale("tent"),
        id = 'tent_options',
        options = options
    })

    lib.showContext('tent_options')
end)


RegisterNetEvent("red-homelesscamps:client:createNewTent", function(tent)
    if tent?.location == whiteList then
        spawnObject(tent.location, tent)
    end
end)

RegisterNetEvent('red-homelesscamps:client:updateTent', function(tent)
    if tent?.location == whiteList then
        local location = whiteListLocations[tent.location]
        if not location then return end 

        local entities = location.entities

        if DoesEntityExist(entities?[tent.name]) then
            SetEntityAsMissionEntity(entities[tent.name], true, true)
            DeleteObject(entities[tent.name])

            removeEntityInteraction(entities[tent.name], 'red-homelesscamps:addTentTarget'..tent.name)
        end

        Wait(100)
        spawnObject(tent.location, tent)
    end
end)

RegisterNetEvent("red-homelesscamps:client:destroyTent", function(location, name)
    if location == whiteList then
        local entities = whiteListLocations[location].entities
        if not entities then return end 
        
        if DoesEntityExist(entities[name]) then
            SetEntityAsMissionEntity(entities[name], true, true)
            DeleteObject(entities[name])
            
            removeEntityInteraction(entities[name], 'red-homelesscamps:addTentTarget'..name)
        end
    end
end)

--- OX Callbacks 

lib.callback.register("red-homelesscamps:client:givePlayerAccess", function(targetName)
    local alert = lib.alertDialog({
        header = locale("homelesscamps"),
        content = locale("access_received", targetName),
        centered = true,
        cancel = true,
        labels = {
            confirm = locale("accept"),
            cancel = locale("decline")
        }
    })

    return alert == 'confirm'
end)

--- Thread 

CreateThread(function()
    while not playerState.isLoggedIn do Wait(200) end

    if Config.homelessPed?.enabled then
        local model, coords, scenairo, radius, distance, blip in Config.homelessPed 

        if blip?.enabled then
            homelessPed.blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(homelessPed.blip, blip.id)
            SetBlipDisplay(homelessPed.blip, 4)
            SetBlipScale(homelessPed.blip, blip.scale)
            SetBlipAsShortRange(homelessPed.blip, true)
            SetBlipColour(homelessPed.blip, blip.colour)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(blip.name)
            EndTextCommandSetBlipName(homelessPed.blip)
        end

        homelessPed.zone = lib.zones.sphere({
            coords = vec3(coords.x, coords.y, coords.z),
            radius = radius,

            onEnter = function()
                lib.requestModel(model, 100)
                local entity = CreatePed(0, model, coords.x, coords.y, coords.z, coords.w, false, false, false)

                if scenairo then
                    TaskStartScenarioInPlace(entity, scenairo, 0, true)
                end

                FreezeEntityPosition(entity, true)
                SetEntityInvincible(entity, true)
                SetBlockingOfNonTemporaryEvents(entity, true)

                addEntityInteraction(entity, distance, {
                    {
                        name = 'red-homelesscamps:addHomelessPedTarget',
                        label = locale("talk_to_ped"),
                        icon = 'fas fa-tent',
                        event = 'red-homelesscamps:client:openDialog',
                        distance = distance
                    }
                })

                homelessPed.entity = entity
            end,

            onExit = function()
                if DoesEntityExist(homelessPed.entity) then
                    SetEntityAsMissionEntity(homelessPed.entity, true, true)
                    DeletePed(homelessPed.entity)

                    removeEntityInteraction(homelessPed.entity, 'red-homelesscamps:addHomelessPedTarget')
                end
            end
        })
    end

    setupLocations()
end)

--- Exports

exports("useItem", function(_, item)
    local success, message = lib.callback.await("red-homelesscamps:server:canUseItem", 200, item)
    if not success then
        notify(message, 'error')
        
        return 
    end

    local coords = objectPlacer()
    if type(coords) ~= 'vector4' then return end

    TriggerServerEvent("red-homelesscamps:server:createNewTent", item, whiteList, coords)
end)

--- Handlers

handler("onResourceStop", function(resource)
    if resource == cache.resource then
        if Config.homelessPed.enabled then
            if DoesEntityExist(homelessPed.entity) then
                SetEntityAsMissionEntity(homelessPed.entity, true, true)     
                DeletePed(homelessPed.entity)

                removeEntityInteraction(homelessPed.entity)
            end

            if homelessPed.zone then
                homelessPed.zone:remove()
            end

            if DoesBlipExist(homelessPed.blip) then
                RemoveBlip(homelessPed.blip)
            end
        end

        destroyTents()
    end
end)


