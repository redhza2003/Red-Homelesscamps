lib.locale()

---@module 'config.server'
local logging = require 'config.server'.logging

--- Function that's triggerd when send notification for player .
---@param source number Player ID
---@param message string Notify Description
---@param type? 'success', 'error', 'inform'
function notify(source, message, type)
    TriggerClientEvent("ox_lib:notify", source, {
        title = locale("homelesscamps"),
        description = message,
        type = type
    })
end

--- Function that's triggerd when create log for homelesscamps actions .
---@param source number Player ID
---@param event string Log event
---@param message string Log message 
function createLog(source, event, message)
    if logging.type == 'ox_lib' then
        lib.logger(source, event, message)
    elseif logging.type == 'qbox' then 
        logger.log({
            source = 'red-homelesscamps',
            webhook = Config.logging.webHook,
            event = event,
            color = 'yellow',
            message = message
        })

    elseif logging.type == 'qbcore' then
        TriggerEvent('qb-log:server:CreateLog', 'homelesscamps', event, 'yellow', message)
    end
end

