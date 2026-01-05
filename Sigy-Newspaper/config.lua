Config = {}

--[[
    SIGY DELIVERY JOBS - MULTI-JOB CONFIGURATION
    Add as many delivery jobs as you want!
    Each job has its own NPCs, items, locations, and rewards.
]]

-- =====================================================
-- GLOBAL SETTINGS (applies to all jobs)
-- =====================================================
Config.GlobalSettings = {
    minDistanceBetweenDeliveries = 10.0,  -- Minimum distance between delivery points
    defaultDeliveryRadius = 2.5,           -- How close player needs to be to deliver
}

-- =====================================================
-- JOB DEFINITIONS - ADD YOUR JOBS HERE!
-- =====================================================
Config.Jobs = {

    --[[
        ========================================
        NEWSPAPER DELIVERY JOB
        ========================================
    ]]
    ['newspaper'] = {
        enabled = true,
        label = "Newspaper Delivery",

        -- Item to deliver (must exist in your items database)
        item = 'newspaper',
        itemLabel = 'Newspaper',

        -- Job Boss NPC (where you start and end the job)
        bossNPC = {
            model = `u_m_m_bwmstablehand_01`,
            coords = vector3(2697.61, -1384.70, 46.34),
            heading = 330.0,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
            blip = {
                sprite = 'blip_camp_tent',
                scale = 0.8,
                name = 'Newspaper Boss',
            },
        },

        -- Pickup NPC locations (one is randomly selected 50/50)
        pickupLocations = {
            {
                model = `s_m_m_barber_01`,
                coords = vector3(2674.85, -1403.56, 46.37),
                heading = 206.17,
            },
            {
                model = `s_m_m_barber_01`,
                coords = vector3(2753.95, -1386.57, 46.25),
                heading = 25.62,
            },
        },
        pickupBlip = {
            sprite = 'blip_camp_tent',
            scale = 0.6,
            name = 'Newspaper Pickup',
        },

        -- Customer NPC model (spawned at delivery locations)
        customerNPC = {
            model = `u_m_m_bwmstablehand_01`,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },

        -- Predefined dropoff locations (NPCs will spawn here)
        dropoffLocations = {
            { coords = vector3(2829.80, -1309.06, 46.71), heading = 190.28 },
            { coords = vector3(2758.30, -1314.24, 47.60), heading = 142.94 },
            { coords = vector3(2704.63, -1256.24, 49.79), heading = 4.35 },
            { coords = vector3(2625.01, -1255.26, 52.48), heading = 134.18 },
            { coords = vector3(2621.86, -1216.93, 53.25), heading = 50.17 },
        },

        -- Job settings
        settings = {
            deliveryCountMin = 5,       -- Minimum deliveries per job (matches dropoff locations)
            deliveryCountMax = 5,       -- Maximum deliveries per job (matches dropoff locations)
            paymentPerItemMin = 3.00,   -- Minimum payment per item delivered ($3)
            paymentPerItemMax = 10.00,  -- Maximum payment per item delivered ($10)
        },

        -- Messages (customize for RP flavor)
        messages = {
            startJob = "Go to the pickup location to collect your newspapers!",
            pickupItems = "Deliver the newspapers to the marked locations!",
            delivered = "deliveries remaining.",
            allDelivered = "Return to the Newspaper Boss for payment!",
            noItems = "You don't have any newspapers to deliver!",
            jobComplete = "Thanks for the hard work! Here's your pay.",
        },
    },

    --[[
        ========================================
        MAIL DELIVERY JOB (EXAMPLE)
        ========================================
        Uncomment and customize to enable!
    ]]
    --[[
    ['mail'] = {
        enabled = true,
        label = "Mail Delivery",

        item = 'mail',
        itemLabel = 'Mail',

        bossNPC = {
            model = `s_m_m_sdpostmaster_01`,
            coords = vector3(2753.12, -1221.45, 50.23),  -- Change to your location
            heading = 180.0,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
            blip = {
                sprite = 'blip_camp_tent',
                scale = 0.8,
                name = 'Post Office',
            },
        },

        pickupNPC = {
            model = `s_m_m_sdpostmaster_01`,
            coords = vector3(2755.50, -1223.10, 50.23),  -- Change to your location
            heading = 0.0,
            blip = {
                sprite = 'blip_camp_tent',
                scale = 0.6,
                name = 'Mail Pickup',
            },
        },

        customerNPC = {
            model = `a_m_m_townfolk_01`,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },

        dropoff = {
            radius = 150.0,
            minRadius = 40.0,
        },

        settings = {
            deliveryCountMin = 3,
            deliveryCountMax = 8,
            paymentPerItemMin = 3.00,
            paymentPerItemMax = 7.00,
        },

        messages = {
            startJob = "Head to the mail room to collect packages!",
            pickupItems = "Deliver the mail to the marked houses!",
            delivered = "deliveries remaining.",
            allDelivered = "Return to the Post Office for payment!",
            noItems = "You don't have any mail to deliver!",
            jobComplete = "Good job, postman! Here's your wages.",
        },
    },
    ]]

    --[[
        ========================================
        MILK DELIVERY JOB (EXAMPLE)
        ========================================
        Uncomment and customize to enable!
    ]]
    --[[
    ['milk'] = {
        enabled = true,
        label = "Milk Delivery",

        item = 'milk_bottle',
        itemLabel = 'Milk Bottle',

        bossNPC = {
            model = `a_m_m_rancher_01`,
            coords = vector3(1234.56, -789.01, 45.00),  -- Change to your ranch location
            heading = 90.0,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
            blip = {
                sprite = 'blip_camp_tent',
                scale = 0.8,
                name = 'Dairy Farm',
            },
        },

        pickupNPC = {
            model = `a_m_m_rancher_01`,
            coords = vector3(1236.00, -790.00, 45.00),  -- Change to your location
            heading = 270.0,
            blip = {
                sprite = 'blip_camp_tent',
                scale = 0.6,
                name = 'Milk Storage',
            },
        },

        customerNPC = {
            model = `a_f_m_townfolk_01`,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        },

        dropoff = {
            radius = 200.0,
            minRadius = 50.0,
        },

        settings = {
            deliveryCountMin = 4,
            deliveryCountMax = 8,
            paymentPerItemMin = 1.50,
            paymentPerItemMax = 4.00,
        },

        messages = {
            startJob = "Pick up the milk bottles from the storage!",
            pickupItems = "Deliver fresh milk to the townsfolk!",
            delivered = "bottles remaining.",
            allDelivered = "Head back to the farm for your pay!",
            noItems = "You don't have any milk bottles!",
            jobComplete = "Fine work! The townsfolk appreciate fresh milk.",
        },
    },
    ]]

}

-- =====================================================
-- ANIMATIONS (shared across all jobs)
-- =====================================================
Config.Animations = {
    pickup = {
        dict = 'amb_misc@world_human_door_knock@male_a@idle_c',
        anim = 'idle_h',
        duration = 2000,
    },
    dropoff = {
        dict = 'amb_misc@world_human_door_knock@male_a@idle_c',
        anim = 'idle_h',
        duration = 1500,
    },
}
