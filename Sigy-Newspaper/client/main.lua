--[[
    Sigy-DeliveryJobs Client
    Multi-Job Delivery System for RSG Framework (RedM)
    Version 3.0.0
]]

local RSGCore = exports['rsg-core']:GetCoreObject()

-- =====================================================
-- STATE MANAGEMENT (per job)
-- =====================================================
local ActiveJobs = {}      -- Tracks active job state per job type
local SpawnedNPCs = {}     -- Tracks all spawned NPCs { [jobId] = { boss = ped, pickup = ped } }
local JobBlips = {}        -- Tracks permanent blips { [jobId] = { boss = blip } }

-- Initialize state for a job
local function InitJobState(jobId)
    if not ActiveJobs[jobId] then
        ActiveJobs[jobId] = {
            active = false,
            itemsCollected = false,
            currentDeliveries = {},
            deliveryBlips = {},
            deliveryNPCs = {},
            deliveryZones = {},
            deliveriesCompleted = 0,
        }
    end
    return ActiveJobs[jobId]
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

-- Get proper ground Z coordinate with multiple checks
local function GetGroundZ(x, y, startZ)
    local groundZ = startZ
    local found = false

    for height = startZ + 10.0, startZ - 10.0, -1.0 do
        local foundGround, z = GetGroundZFor_3dCoord(x, y, height, false)
        if foundGround then
            groundZ = z
            found = true
            break
        end
    end

    return found, groundZ
end

-- Spawn NPC with proper ground placement
local function SpawnNPC(model, coords, heading, scenario)
    local modelHash = model
    if type(modelHash) ~= 'number' then modelHash = joaat(modelHash) end

    -- Try to resolve model; if missing, attempt string->hash fallback
    if not IsModelInCdimage(modelHash) then
        local alt = nil
        if type(model) ~= 'number' then
            alt = joaat(tostring(model))
        end
        if alt and IsModelInCdimage(alt) then
            modelHash = alt
        else
            print('[Sigy-DeliveryJobs] Model not found in game data: ' .. tostring(model) .. ' — falling back to a default pedestrian model')
            modelHash = joaat('u_m_m_bwmstablehand_01')
        end
    end

    print('[Sigy-DeliveryJobs] Requesting model: ' .. modelHash)
    lib.requestModel(modelHash, 5000)

    if not HasModelLoaded(modelHash) then
        print('[Sigy-DeliveryJobs] Failed to load model: ' .. tostring(model))
        return nil
    end

    print('[Sigy-DeliveryJobs] Model loaded, creating ped at ' .. tostring(coords))

    -- Create ped at the specified coords
    local pedHeading = heading or (coords.w or 0.0)
    local ped = CreatePed(modelHash, coords.x, coords.y, coords.z, pedHeading, false, false, 0, 0)

    if not DoesEntityExist(ped) then
        print('[Sigy-DeliveryJobs] Failed to create ped')
        return nil
    end

    print('[Sigy-DeliveryJobs] Ped created: ' .. ped)

    -- Make NPC visible immediately
    SetEntityVisible(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetRandomOutfitVariation(ped, true)
    SetPedCanBeTargetted(ped, false)

    -- Place on ground properly
    PlaceEntityOnGroundProperly(ped, true)

    -- Start scenario if provided
    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end

    print('[Sigy-DeliveryJobs] NPC fully spawned and visible')

    return ped
end

-- Create blip
local function CreateJobBlip(coords, sprite, scale, name)
    local blip = BlipAddForCoords(1664425300, coords)
    if not blip then return nil end

    SetBlipSprite(blip, joaat(sprite), true)
    SetBlipScale(blip, scale)
    SetBlipName(blip, name)

    return blip
end

-- Remove blip
local function RemoveJobBlip(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

-- Check if player has item
local function HasItem(item, amount)
    return exports['rsg-inventory']:HasItem(item, amount or 1)
end

-- =====================================================
-- SPAWN VALIDATION FUNCTIONS
-- =====================================================

local function IsValidSpawnPosition(coords)
    -- Check if position is in water using native
    local inWater = Citizen.InvokeNative(0xCF086519E060298B, coords.x, coords.y, coords.z)
    if inWater then
        return false
    end

    local startPos = vector3(coords.x, coords.y, coords.z + 2.0)
    local endPos = vector3(coords.x, coords.y, coords.z - 1.0)
    local ray = StartShapeTestRay(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y, endPos.z, 1 + 16, PlayerPedId(), 0)
    local _, hit, _, _, _ = GetShapeTestResult(ray)

    if hit then
        local testOffset = 0.5
        local foundNearby1, z1 = GetGroundZFor_3dCoord(coords.x + testOffset, coords.y, coords.z + 5.0, false)
        local foundNearby2, z2 = GetGroundZFor_3dCoord(coords.x - testOffset, coords.y, coords.z + 5.0, false)

        if foundNearby1 and foundNearby2 then
            if math.abs(z1 - z2) > 1.5 then
                return false
            end
        end
        return true
    end

    return false
end

local function IsPositionBlocked(coords)
    local startPos = vector3(coords.x, coords.y, coords.z + 0.5)
    local endPos = vector3(coords.x, coords.y, coords.z + 10.0)
    local ray = StartShapeTestRay(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y, endPos.z, 1 + 16, PlayerPedId(), 0)
    local _, hit, _, _, _ = GetShapeTestResult(ray)
    return hit
end

local function GetRandomPointInRadius(centerCoords, minRadius, maxRadius, maxAttempts)
    maxAttempts = maxAttempts or 10

    for _ = 1, maxAttempts do
        local angle = math.random() * 2 * math.pi
        local distance = minRadius + math.random() * (maxRadius - minRadius)
        local x = centerCoords.x + math.cos(angle) * distance
        local y = centerCoords.y + math.sin(angle) * distance

        local found, groundZ = GetGroundZ(x, y, centerCoords.z)

        if found then
            local testCoords = vector3(x, y, groundZ)
            if IsValidSpawnPosition(testCoords) and not IsPositionBlocked(testCoords) then
                return testCoords, true
            end
        end
    end

    -- Fallback
    local fallbackAngle = math.random() * 2 * math.pi
    local fallbackDist = minRadius + 5.0
    local fallbackX = centerCoords.x + math.cos(fallbackAngle) * fallbackDist
    local fallbackY = centerCoords.y + math.sin(fallbackAngle) * fallbackDist
    local _, fallbackZ = GetGroundZ(fallbackX, fallbackY, centerCoords.z)

    return vector3(fallbackX, fallbackY, fallbackZ or centerCoords.z), false
end

-- Select delivery locations from predefined list
local function SelectDeliveries(jobConfig)
    local selected = {}

    print('[Sigy-DeliveryJobs] SelectDeliveries called')

    -- Use predefined locations if available
    if jobConfig.dropoffLocations and #jobConfig.dropoffLocations > 0 then
        print('[Sigy-DeliveryJobs] Using ' .. #jobConfig.dropoffLocations .. ' predefined dropoff locations')
        for i, loc in ipairs(jobConfig.dropoffLocations) do
            print('[Sigy-DeliveryJobs] Adding dropoff #' .. i .. ': ' .. tostring(loc.coords))
            table.insert(selected, {
                coords = loc.coords,
                heading = loc.heading or 0.0,
                index = i
            })
        end
    else
        -- Fallback to random generation if no predefined locations
        local bossCoords = jobConfig.bossNPC.coords
        local minRadius = jobConfig.dropoff and jobConfig.dropoff.minRadius or 30.0
        local maxRadius = jobConfig.dropoff and jobConfig.dropoff.radius or 100.0
        local count = math.random(jobConfig.settings.deliveryCountMin, jobConfig.settings.deliveryCountMax)
        local usedPositions = {}
        local minDistanceBetween = Config.GlobalSettings.minDistanceBetweenDeliveries

        for i = 1, count do
            local validPosition = false
            local coords = nil
            local attempts = 0

            while not validPosition and attempts < 20 do
                attempts = attempts + 1
                coords, validPosition = GetRandomPointInRadius(bossCoords, minRadius, maxRadius, 5)

                if validPosition and coords then
                    for _, usedPos in ipairs(usedPositions) do
                        if #(coords - usedPos) < minDistanceBetween then
                            validPosition = false
                            break
                        end
                    end
                end
            end

            if coords then
                table.insert(usedPositions, coords)
                table.insert(selected, { coords = coords, heading = 0.0, index = i })
            end
        end
    end

    return selected
end

-- Calculate random payment for a job
local function CalculatePayment(jobConfig, numDeliveries)
    local total = 0
    for _ = 1, numDeliveries do
        local payment = math.random(
            jobConfig.settings.paymentPerItemMin * 100,
            jobConfig.settings.paymentPerItemMax * 100
        ) / 100
        total = total + payment
    end
    return total
end

-- =====================================================
-- JOB FUNCTIONS
-- =====================================================

-- Deliver an item at a location
local function DeliverItem(jobId, deliveryIndex)
    local jobConfig = Config.Jobs[jobId]
    local jobState = ActiveJobs[jobId]
    if not jobConfig or not jobState then return end

    local locIndex = nil
    for i, loc in ipairs(jobState.currentDeliveries) do
        if loc.deliveryIndex == deliveryIndex then
            locIndex = i
            break
        end
    end

    if not locIndex then
        lib.notify({ title = 'Error', description = 'Delivery location not found!', type = 'error' })
        return
    end

    local loc = jobState.currentDeliveries[locIndex]

    if not HasItem(jobConfig.item, 1) then
        lib.notify({ title = 'No Items', description = jobConfig.messages.noItems, type = 'error' })
        return
    end

    lib.requestAnimDict(Config.Animations.dropoff.dict, 5000)
    TaskPlayAnim(PlayerPedId(), Config.Animations.dropoff.dict, Config.Animations.dropoff.anim, 8.0, -8.0, Config.Animations.dropoff.duration, 1, 0, false, false, false)
    Wait(Config.Animations.dropoff.duration)
    ClearPedTasks(PlayerPedId())

    TriggerServerEvent('Sigy-DeliveryJobs:server:removeItem', jobId)

    jobState.deliveriesCompleted = jobState.deliveriesCompleted + 1

    -- Remove blip
    if loc.blip then
        RemoveJobBlip(loc.blip)
    end

    -- Remove NPC
    if loc.npc and DoesEntityExist(loc.npc) then
        exports.ox_target:removeLocalEntity(loc.npc)
        DeleteEntity(loc.npc)
    end

    table.remove(jobState.currentDeliveries, locIndex)

    if #jobState.currentDeliveries == 0 then
        lib.notify({ title = 'All Delivered!', description = jobConfig.messages.allDelivered, type = 'success' })

        local returnBlip = CreateJobBlip(jobConfig.bossNPC.coords, jobConfig.bossNPC.blip.sprite, 0.8, 'Return to Boss')
        if returnBlip then
            table.insert(jobState.deliveryBlips, returnBlip)
        end
    else
        lib.notify({ title = 'Delivered!', description = #jobState.currentDeliveries .. ' ' .. jobConfig.messages.delivered, type = 'info' })
    end
end

-- Start a specific job
local function StartJob(jobId)
    local jobConfig = Config.Jobs[jobId]
    local jobState = InitJobState(jobId)

    if jobState.active then
        lib.notify({ title = jobConfig.label, description = 'You already have this job active!', type = 'error' })
        return
    end

    -- Check if player has any other delivery job active
    for otherId, otherState in pairs(ActiveJobs) do
        if otherState.active then
            lib.notify({ title = 'Job Active', description = 'Finish your current delivery job first!', type = 'error' })
            return
        end
    end

    jobState.active = true
    jobState.itemsCollected = false
    jobState.deliveriesCompleted = 0

    -- Use predefined locations or random generation
    jobState.currentDeliveries = SelectDeliveries(jobConfig)

    print('[Sigy-DeliveryJobs] Job started with ' .. #jobState.currentDeliveries .. ' delivery locations')

    for i, loc in ipairs(jobState.currentDeliveries) do
        loc.deliveryIndex = i
        print('[Sigy-DeliveryJobs] Delivery #' .. i .. ': ' .. tostring(loc.coords) .. ' heading: ' .. tostring(loc.heading))
    end

    lib.notify({ title = jobConfig.label, description = jobConfig.messages.startJob, type = 'info' })

    -- Add pickup blip - randomly select one location if multiple exist
    local pickupCoords, pickupBlipConfig
    if jobConfig.pickupLocations and #jobConfig.pickupLocations > 0 then
        -- Randomly select one of the pickup locations (50/50 or equal chance)
        local selectedIndex = math.random(1, #jobConfig.pickupLocations)
        local selectedPickup = jobConfig.pickupLocations[selectedIndex]
        pickupCoords = selectedPickup.coords
        pickupBlipConfig = jobConfig.pickupBlip
        jobState.selectedPickupIndex = selectedIndex -- Store which one was selected
    elseif jobConfig.pickupNPC then
        pickupCoords = jobConfig.pickupNPC.coords
        pickupBlipConfig = jobConfig.pickupNPC.blip
    end

    if pickupCoords and pickupBlipConfig then
        local pickupBlip = CreateJobBlip(pickupCoords, pickupBlipConfig.sprite, pickupBlipConfig.scale, pickupBlipConfig.name)
        if pickupBlip then
            table.insert(jobState.deliveryBlips, pickupBlip)
        end
    end
end

-- Pickup items for a job
local function PickupItems(jobId)
    local jobConfig = Config.Jobs[jobId]
    local jobState = ActiveJobs[jobId]
    if not jobConfig or not jobState or not jobState.active or jobState.itemsCollected then return end

    lib.requestAnimDict(Config.Animations.pickup.dict, 5000)
    TaskPlayAnim(PlayerPedId(), Config.Animations.pickup.dict, Config.Animations.pickup.anim, 8.0, -8.0, Config.Animations.pickup.duration, 1, 0, false, false, false)
    Wait(Config.Animations.pickup.duration)
    ClearPedTasks(PlayerPedId())

    TriggerServerEvent('Sigy-DeliveryJobs:server:giveItems', jobId, #jobState.currentDeliveries)

    jobState.itemsCollected = true

    -- Clear pickup blip
    for _, blip in ipairs(jobState.deliveryBlips) do
        RemoveJobBlip(blip)
    end
    jobState.deliveryBlips = {}

    lib.notify({ title = 'Items Collected', description = jobConfig.messages.pickupItems, type = 'success' })

    print('[Sigy-DeliveryJobs] Creating ' .. #jobState.currentDeliveries .. ' delivery points...')

    -- Create delivery points with NPCs
    for i, loc in ipairs(jobState.currentDeliveries) do
        print('[Sigy-DeliveryJobs] Creating delivery point #' .. i .. ' at ' .. tostring(loc.coords))

        local blip = CreateJobBlip(loc.coords, 'blip_camp_tent', 0.6, 'Delivery #' .. i)
        if blip then
            loc.blip = blip
            table.insert(jobState.deliveryBlips, blip)
            print('[Sigy-DeliveryJobs] Blip created for delivery #' .. i)
        else
            print('[Sigy-DeliveryJobs] ERROR: Failed to create blip for delivery #' .. i)
        end

        -- Use predefined heading if available, otherwise random
        local npcHeading = loc.heading or math.random(0, 360)
        print('[Sigy-DeliveryJobs] Spawning customer NPC at delivery #' .. i .. ' with heading ' .. npcHeading)

        local npc = SpawnNPC(jobConfig.customerNPC.model, loc.coords, npcHeading, jobConfig.customerNPC.scenario)
        if npc then
            loc.npc = npc
            print('[Sigy-DeliveryJobs] Customer NPC spawned for delivery #' .. i .. ' (entity: ' .. npc .. ')')

            local capturedIndex = loc.deliveryIndex
            local capturedJobId = jobId
            local capturedItem = jobConfig.item

            exports.ox_target:addLocalEntity(npc, {
                {
                    name = 'sigy_delivery_' .. jobId .. '_' .. capturedIndex,
                    label = 'Deliver ' .. jobConfig.itemLabel,
                    icon = 'fas fa-newspaper',
                    distance = 3.0,
                    canInteract = function()
                        local state = ActiveJobs[capturedJobId]
                        return state and state.active and state.itemsCollected and HasItem(capturedItem, 1)
                    end,
                    onSelect = function()
                        DeliverItem(capturedJobId, capturedIndex)
                    end,
                },
            })
            print('[Sigy-DeliveryJobs] ox_target added for delivery #' .. i)
        else
            print('[Sigy-DeliveryJobs] ERROR: Failed to spawn customer NPC for delivery #' .. i)
        end
    end

    print('[Sigy-DeliveryJobs] All delivery points created!')
end

-- Finish a job and get paid
local function FinishJob(jobId)
    local jobConfig = Config.Jobs[jobId]
    local jobState = ActiveJobs[jobId]
    if not jobConfig or not jobState or not jobState.active then return end

    if #jobState.currentDeliveries > 0 then
        lib.notify({ title = 'Not Complete', description = 'You still have ' .. #jobState.currentDeliveries .. ' deliveries!', type = 'error' })
        return
    end

    if jobState.deliveriesCompleted == 0 then
        lib.notify({ title = 'Not Complete', description = 'You haven\'t delivered anything!', type = 'error' })
        return
    end

    local payment = CalculatePayment(jobConfig, jobState.deliveriesCompleted)
    TriggerServerEvent('Sigy-DeliveryJobs:server:completeJob', jobId, payment)

    -- Reset job state
    for _, blip in ipairs(jobState.deliveryBlips) do
        RemoveJobBlip(blip)
    end

    ActiveJobs[jobId] = nil
    InitJobState(jobId)
end

-- Cancel a job
local function CancelJob(jobId)
    local jobConfig = Config.Jobs[jobId]
    local jobState = ActiveJobs[jobId]
    if not jobConfig or not jobState or not jobState.active then return end

    -- Cleanup
    for _, blip in ipairs(jobState.deliveryBlips) do
        RemoveJobBlip(blip)
    end

    for _, loc in ipairs(jobState.currentDeliveries) do
        if loc.npc and DoesEntityExist(loc.npc) then
            exports.ox_target:removeLocalEntity(loc.npc)
            DeleteEntity(loc.npc)
        end
    end

    ActiveJobs[jobId] = nil
    InitJobState(jobId)

    lib.notify({ title = jobConfig.label, description = 'Job cancelled.', type = 'error' })
end

local isSetup = false

-- =====================================================
-- SETUP - SPAWN ALL JOB NPCS
-- =====================================================

local function SetupAllJobs()
    if isSetup then return end
    isSetup = true
    print('[Sigy-DeliveryJobs] Setting up all delivery jobs...')

    for jobId, jobConfig in pairs(Config.Jobs) do
        if jobConfig.enabled then
            print('[Sigy-DeliveryJobs] Setting up job: ' .. jobId)

            InitJobState(jobId)
            SpawnedNPCs[jobId] = {}

            -- Spawn Boss NPC
            local bossNPC = SpawnNPC(
                jobConfig.bossNPC.model,
                jobConfig.bossNPC.coords,
                jobConfig.bossNPC.heading,
                jobConfig.bossNPC.scenario
            )

            if bossNPC then
                SpawnedNPCs[jobId].boss = bossNPC

                local capturedJobId = jobId

                exports.ox_target:addLocalEntity(bossNPC, {
                    {
                        name = 'sigy_job_start_' .. jobId,
                        label = 'Start ' .. jobConfig.label,
                        icon = 'fas fa-briefcase',
                        distance = 2.5,
                        canInteract = function()
                            local state = ActiveJobs[capturedJobId]
                            return not state or not state.active
                        end,
                        onSelect = function()
                            StartJob(capturedJobId)
                        end,
                    },
                    {
                        name = 'sigy_job_finish_' .. jobId,
                        label = 'Collect Payment',
                        icon = 'fas fa-dollar-sign',
                        distance = 2.5,
                        canInteract = function()
                            local state = ActiveJobs[capturedJobId]
                            return state and state.active and #state.currentDeliveries == 0 and state.deliveriesCompleted > 0
                        end,
                        onSelect = function()
                            FinishJob(capturedJobId)
                        end,
                    },
                    {
                        name = 'sigy_job_cancel_' .. jobId,
                        label = 'Quit Job',
                        icon = 'fas fa-times',
                        distance = 2.5,
                        canInteract = function()
                            local state = ActiveJobs[capturedJobId]
                            return state and state.active
                        end,
                        onSelect = function()
                            CancelJob(capturedJobId)
                        end,
                    },
                })

                -- Create permanent boss blip
                local bossBlip = CreateJobBlip(
                    jobConfig.bossNPC.coords,
                    jobConfig.bossNPC.blip.sprite,
                    jobConfig.bossNPC.blip.scale,
                    jobConfig.bossNPC.blip.name
                )
                JobBlips[jobId] = { boss = bossBlip }

                print('[Sigy-DeliveryJobs] Boss NPC spawned for: ' .. jobId)
            end

            -- Spawn Pickup NPC(s) - supports multiple locations with random selection
            if jobConfig.pickupLocations and #jobConfig.pickupLocations > 0 then
                -- Spawn NPCs at ALL pickup locations
                SpawnedNPCs[jobId].pickupNPCs = {}
                for i, pickupLoc in ipairs(jobConfig.pickupLocations) do
                    local pickupNPC = SpawnNPC(
                        pickupLoc.model,
                        pickupLoc.coords,
                        pickupLoc.heading,
                        nil
                    )

                    if pickupNPC then
                        table.insert(SpawnedNPCs[jobId].pickupNPCs, pickupNPC)

                        local capturedJobId = jobId

                        exports.ox_target:addLocalEntity(pickupNPC, {
                            {
                                name = 'sigy_job_pickup_' .. jobId .. '_' .. i,
                                label = 'Pick Up ' .. jobConfig.itemLabel .. 's',
                                icon = 'fas fa-box',
                                distance = 2.5,
                                canInteract = function()
                                    local state = ActiveJobs[capturedJobId]
                                    return state and state.active and not state.itemsCollected
                                end,
                                onSelect = function()
                                    PickupItems(capturedJobId)
                                end,
                            },
                        })

                        print('[Sigy-DeliveryJobs] Pickup NPC #' .. i .. ' spawned for: ' .. jobId)
                    end
                end
            elseif jobConfig.pickupNPC then
                -- Legacy single pickup NPC support
                local pickupNPC = SpawnNPC(
                    jobConfig.pickupNPC.model,
                    jobConfig.pickupNPC.coords,
                    jobConfig.pickupNPC.heading,
                    nil
                )

                if pickupNPC then
                    SpawnedNPCs[jobId].pickup = pickupNPC

                    local capturedJobId = jobId

                    exports.ox_target:addLocalEntity(pickupNPC, {
                        {
                            name = 'sigy_job_pickup_' .. jobId,
                            label = 'Pick Up ' .. jobConfig.itemLabel .. 's',
                            icon = 'fas fa-box',
                            distance = 2.5,
                            canInteract = function()
                                local state = ActiveJobs[capturedJobId]
                                return state and state.active and not state.itemsCollected
                            end,
                            onSelect = function()
                                PickupItems(capturedJobId)
                            end,
                        },
                    })

                    print('[Sigy-DeliveryJobs] Pickup NPC spawned for: ' .. jobId)
                end
            end
        end
    end

    print('[Sigy-DeliveryJobs] All jobs setup complete!')
end

-- =====================================================
-- INITIALIZATION
-- =====================================================

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(1000)
    SetupAllJobs()
end)

CreateThread(function()
    Wait(5000)
    if not isSetup and RSGCore.Functions.GetPlayerData().citizenid then
        SetupAllJobs()
    end
end)

-- =====================================================
-- CLEANUP ON RESOURCE STOP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- Delete all spawned NPCs
    for jobId, npcs in pairs(SpawnedNPCs) do
        if npcs.boss and DoesEntityExist(npcs.boss) then
            exports.ox_target:removeLocalEntity(npcs.boss)
            DeleteEntity(npcs.boss)
        end
        if npcs.pickup and DoesEntityExist(npcs.pickup) then
            exports.ox_target:removeLocalEntity(npcs.pickup)
            DeleteEntity(npcs.pickup)
        end
        -- Handle multiple pickup NPCs
        if npcs.pickupNPCs then
            for _, pickupNPC in ipairs(npcs.pickupNPCs) do
                if DoesEntityExist(pickupNPC) then
                    exports.ox_target:removeLocalEntity(pickupNPC)
                    DeleteEntity(pickupNPC)
                end
            end
        end
    end

    -- Delete all delivery NPCs and blips
    for jobId, state in pairs(ActiveJobs) do
        if state.deliveryBlips then
            for _, blip in ipairs(state.deliveryBlips) do
                RemoveJobBlip(blip)
            end
        end
        if state.currentDeliveries then
            for _, loc in ipairs(state.currentDeliveries) do
                if loc.npc and DoesEntityExist(loc.npc) then
                    exports.ox_target:removeLocalEntity(loc.npc)
                    DeleteEntity(loc.npc)
                end
            end
        end
    end

    -- Delete permanent blips
    for jobId, blips in pairs(JobBlips) do
        if blips.boss then RemoveJobBlip(blips.boss) end
    end

    lib.hideTextUI()
    print('[Sigy-DeliveryJobs] Resource stopped, cleanup complete')
end)
