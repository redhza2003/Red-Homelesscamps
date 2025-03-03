Config = {
    closestDistance = 4.0,

    maxTents = 3,

    blackListItems = {
        --- Add your black list items here .
    },

    default = {
        slots = 10,
        weight = 2
    },
    

    logging = {
        enabled = true,
        type = 'qbox', -- type : ox, qbox, qbcore
        webHook = '' -- Your webHook
    }
}

return Config
