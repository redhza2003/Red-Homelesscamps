if GetResourceState("qbx_core") == 'started' then
    local playerData = exports.qbx_core:GetPlayerData()

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        playerData = exports['qbx_core']:GetPlayerData()
    end)

    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(newJob)
        playerData = exports['qbx_core']:GetPlayerData()
    end)

    RegisterNetEvent("QBCore:Client:OnMoneyChange", function(account, amount, action)
        playerData = exports['qbx_core']:GetPlayerData()
    end)

    ---@return playerData table
    function getPlayerData()
        if not playerData then return end

        return {
            name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname,
            money = playerData.money,
            charId = playerData.citizenid,
            groups = {
                [playerData.job.name] = playerData.job.grade.level,
                [playerData.gang.name] = playerData.gang.grade.level
            }
        }
    end
elseif GetResourceState("qb-core") == 'started' then
    local QBCore = exports['qb-core']:GetCoreObject()
    local playerData = QBCore.Functions.GetPlayerData()

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        playerData = QBCore.Functions.GetPlayerData()
    end)

    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(newJob)
        playerData = QBCore.Functions.GetPlayerData()
    end)

    RegisterNetEvent("QBCore:Client:OnMoneyChange", function(account, amount, action)
        playerData = QBCore.Functions.GetPlayerData()
    end)

    ---@return playerData table
    function getPlayerData()
        if not playerData then return end

        return {
            name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname,
            money = playerData.money,
            charId = playerData.citizenid,
            groups = {
                [playerData.job.name] = playerData.job.grade.level,
                [playerData.gang.name] = playerData.gang.grade.level
            }
        }
    end
end
