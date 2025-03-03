fx_version 'cerulean'
game 'gta5'

name 'Red Homelesscamps.'
Author '@red_20031'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
}

files {
    'config/*.lua',
    'locales/en.json'
}

client_scripts {
    'bridge/**/client.lua',
    'client/utils.lua',
    'client/client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/**/server.lua',
    'server/utils.lua',
    'server/server.lua'
}

lua54 'yes'
