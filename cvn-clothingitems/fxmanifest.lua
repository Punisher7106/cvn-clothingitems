fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'cvn-clothingitems'
author 'CVN'
description 'Metadata clothing item handler for ox_inventory and 4bit_appearance'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/outfitbag.lua',
    'client/stations.lua'
}

server_scripts {
    'server/main.lua',
    'server/outfitbag.lua',
    'server/stations.lua'
}
