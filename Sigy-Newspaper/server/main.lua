--[[
    Sigy-DeliveryJobs Server
    Multi-Job Delivery System for RSG Framework (RedM)
    Version 3.0.0
]]

local RSGCore = exports['rsg-core']:GetCoreObject()

-- =====================================================
-- EVENTS
-- =====================================================

-- Give items to player for a specific job
RegisterNetEvent('Sigy-DeliveryJobs:server:giveItems', function(jobId, amount)
    local source = source
    local Player = RSGCore.Functions.GetPlayer(source)

    if not Player then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Player data not found.',
            type = 'error'
        })
        return
    end

    local jobConfig = Config.Jobs[jobId]
    if not jobConfig then
        print('[Sigy-DeliveryJobs] Invalid job ID: ' .. tostring(jobId))
        return
    end

    -- Validate amount
    amount = tonumber(amount) or 5
    if amount < 1 then amount = 1 end
    if amount > 20 then amount = 20 end

    -- Give the job-specific item
    local success = Player.Functions.AddItem(jobConfig.item, amount)

    if success then
        TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[jobConfig.item], 'add', amount)

        TriggerClientEvent('ox_lib:notify', source, {
            title = jobConfig.label,
            description = 'You picked up ' .. amount .. ' ' .. jobConfig.itemLabel .. 's.',
            type = 'success'
        })

        print('[Sigy-DeliveryJobs] Gave ' .. amount .. ' ' .. jobConfig.item .. ' to player ' .. Player.PlayerData.citizenid)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Could not add items to inventory.',
            type = 'error'
        })
    end
end)

-- Remove one item from player for a specific job
RegisterNetEvent('Sigy-DeliveryJobs:server:removeItem', function(jobId)
    local source = source
    local Player = RSGCore.Functions.GetPlayer(source)

    if not Player then return end

    local jobConfig = Config.Jobs[jobId]
    if not jobConfig then
        print('[Sigy-DeliveryJobs] Invalid job ID: ' .. tostring(jobId))
        return
    end

    -- Check if player has item
    local hasItem = Player.Functions.GetItemByName(jobConfig.item)

    if hasItem and hasItem.amount >= 1 then
        Player.Functions.RemoveItem(jobConfig.item, 1)
        TriggerClientEvent('rsg-inventory:client:ItemBox', source, RSGCore.Shared.Items[jobConfig.item], 'remove', 1)
        print('[Sigy-DeliveryJobs] Player delivered 1 ' .. jobConfig.item)
    else
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = jobConfig.messages.noItems,
            type = 'error'
        })
    end
end)

-- Complete job and pay player
RegisterNetEvent('Sigy-DeliveryJobs:server:completeJob', function(jobId, payment)
    local source = source
    local Player = RSGCore.Functions.GetPlayer(source)

    if not Player then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Error',
            description = 'Player data not found.',
            type = 'error'
        })
        return
    end

    local jobConfig = Config.Jobs[jobId]
    if not jobConfig then
        print('[Sigy-DeliveryJobs] Invalid job ID: ' .. tostring(jobId))
        return
    end

    -- Validate payment is reasonable (anti-cheat)
    payment = tonumber(payment) or 0
    local maxPossiblePayment = jobConfig.settings.deliveryCountMax * jobConfig.settings.paymentPerItemMax
    if payment < 0 then payment = 0 end
    if payment > maxPossiblePayment then
        print('[Sigy-DeliveryJobs] Suspicious payment detected from ' .. Player.PlayerData.citizenid .. ': $' .. payment)
        payment = maxPossiblePayment
    end

    -- Round to 2 decimal places
    payment = math.floor(payment * 100) / 100

    -- Add money to player
    Player.Functions.AddMoney('cash', payment, 'delivery-job-' .. jobId)

    -- Notify player
    TriggerClientEvent('ox_lib:notify', source, {
        title = jobConfig.label .. ' Complete!',
        description = jobConfig.messages.jobComplete .. ' ($' .. string.format("%.2f", payment) .. ')',
        type = 'success'
    })

    print('[Sigy-DeliveryJobs] Paid $' .. payment .. ' to ' .. Player.PlayerData.citizenid .. ' for ' .. jobId .. ' job')
end)

-- =====================================================
-- STARTUP
-- =====================================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    print('^2[Sigy-DeliveryJobs]^7 Server loaded - Multi-Job Delivery System')

    -- Print enabled jobs
    local enabledCount = 0
    for jobId, jobConfig in pairs(Config.Jobs) do
        if jobConfig.enabled then
            print('^2[Sigy-DeliveryJobs]^7 Job enabled: ' .. jobId .. ' (' .. jobConfig.label .. ')')
            enabledCount = enabledCount + 1
        end
    end

    print('^2[Sigy-DeliveryJobs]^7 Total jobs enabled: ' .. enabledCount)
end)
