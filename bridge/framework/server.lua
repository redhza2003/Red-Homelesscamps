if GetResourceState("qbx_core") == 'started' then
    ---@module 'config.server.logging'
    local logging = require 'config.server'.logging
    if logging?.type == 'qbox' then
        --@module '@qbx_core.modules.logger'
        logger = require '@qbx_core.modules.logger'
    end

    --- Returns Player Data .
    ---@param source number Player ID
    ---@return playerData table
    function getPlayer(source)
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return end

        return {
            src = source,
            name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            charId = player.PlayerData.citizenid,
            money = player.PlayerData.money,
            groups = {
                [player.PlayerData.job.name] = player.PlayerData.job.grade.level,
                [player.PlayerData.gang.name] = player.PlayerData.gang.grade.level
            }
        }
    end

    --- Returns Player Data .
    ---@param charId string Player CharID
    ---@return playerData table
    function getByCharId(charId)
        local player = exports.qbx_core:GetPlayerByCitizenId(charId)
        if not player then return end

        return {
            src = player.PlayerData.source,
            name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            charId = player.PlayerData.citizenid,
            money = player.PlayerData.money,
            groups = {
                [player.PlayerData.job.name] = player.PlayerData.job.grade.level,
                [player.PlayerData.gang.name] = player.PlayerData.gang.grade.level
            }
        }
    end

    ---@param source number Player ID
    ---@param account? 'bank', 'cash'
    ---@param amount number Add Amount
    function removeMoney(source, account, amount)
        local player = exports.qbx_core:GetPlayer(source)
        if not player then return end

        return player.Functions.RemoveMoney(account, amount)
    end
elseif GetResourceState("qb-core") == 'started' then
    local QBCore = exports['qb-core']:GetCoreObject()

    --- Returns Player Data .
    ---@param source number Player ID
    ---@return playerData table
    function getPlayer(source)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return end

        return {
            src = source,
            name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            charId = player.PlayerData.citizenid,
            money = player.PlayerData.money,
            groups = {
                [player.PlayerData.job.name] = player.PlayerData.job.grade.level,
                [player.PlayerData.gang.name] = player.PlayerData.gang.grade.level
            }
        }
    end

    --- Returns Player Data .
    ---@param charId string Player CharID
    ---@return playerData table
    function getByCharId(charId)
        local player = QBCore.Functions.GetPlayerByCitizenId(charId)
        if not player then return end

        return {
            src = player.PlayerData.source,
            name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname,
            charId = player.PlayerData.citizenid,
            money = player.PlayerData.money,
            groups = {
                [player.PlayerData.job.name] = player.PlayerData.job.grade.level,
                [player.PlayerData.gang.name] = player.PlayerData.gang.grade.level
            }
        }
    end

    ---@param source number Player ID
    ---@param account? 'bank', 'cash'
    ---@param amount number Add Amount
    function removeMoney(source, account, amount)
        local player = QBCore.Functions.GetPlayer(source)
        if not player then return end

        return player.Functions.RemoveMoney(account, amount)
    end
end
