-- ============================================================================
-- FXMANIFEST.LUA
-- ============================================================================

fx_version 'cerulean'
game 'gta5'

author 'SDMDevHub - Security Camera System'
description 'Advanced camera system with recording and police reporting'
version '1.0.0'

-- Dipendenze
dependencies {
    'es_extended',
    'mysql-async'
}

-- Script lato client
client_scripts {
    'client.lua'
}

-- Script lato server
server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server.lua'
}

-- UI Files
ui_page 'html/index.html'

files {
    'html/index.html'
}
