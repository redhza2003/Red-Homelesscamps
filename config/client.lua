Config = {
    propModel = 'prop_skid_tent_01',

    targetDistance = 3.0,
    
    minusZ = -0.9,

    homelessPed = {
        enabled = true,
        model = 'a_m_o_tramp_01',
        coords = vec4(141.90, -1190.17, 29.07, 93.14),
        scenairo = 'WORLD_HUMAN_SEAT_WALL',
        
        radius = 10.0,
        distance = 3.0,

        blip = {
            enabled = true,
            id = 364,
            colour = 0,
            scale = 0.9,
            name = 'Homeless Camps'
        }
    },

    whiteListLocations = {
        ['STRAWBERRY'] = {
            main = vec2(154.09, -1211.9),
            debug = false,
            points = {
                vec3(185.10000610352, -1234.0, 30.2),
                vec3(182.0, -1183.0, 30.2),
                vec3(122.0, -1179.0, 30.2),
                vec3(124.0, -1232.0, 30.2),
            },
            thickness = 4.9,
        },

        ['MOUNT CHILIAD'] = {
            main = vec2(1454.65, 6353.76),
            debug = false,
            points = {
                vec3(1491.0, 6369.0, 24.0),
                vec3(1483.0, 6352.0, 24.0),
                vec3(1473.0, 6345.0, 24.0),
                vec3(1422.0, 6322.0, 24.0),
                vec3(1413.0, 6341.0, 24.0),
                vec3(1416.0, 6361.0, 24.0),
            },
            thickness = 4.0,
        }
    }
}

return Config