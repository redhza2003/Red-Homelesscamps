lib.locale()

function notify(message, type)
    lib.notify({
        title = locale("homelesscamps"),
        description = message,
        type = type
    })
end

function addEntityInteraction(entity, distance, options)
    if GetResourceState("ox_target") == "started" then
        return exports.ox_target:addLocalEntity(entity, options)
    elseif GetResourceState("qb-target") == "started" then
        return exports['qb-target']:AddTargetEntity(entity, {
            options = options,
            distance = distance
        })
    end
end

function removeEntityInteraction(entity, name)
    if GetResourceState("ox_Target") == "started" then
        exports.ox_target:removeLocalEntity(entity, name)
    elseif GetResourceState("qb-target") == "started" then
        exports['qb-target']:RemvoeTargetEntity(entity)
    end
end