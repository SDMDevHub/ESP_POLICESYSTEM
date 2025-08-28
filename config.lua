Config = {}

-- Generale
Config.Locale = 'it'
Config.Debug = false

-- Sistema Telecamere
Config.Cameras = {
    -- Distanza massima di rendering predefinita
    maxRenderDistance = 100.0,
    
    -- FOV predefinito
    defaultFOV = 60.0,
    
    -- Numero massimo di telecamere per giocatore
    maxCamerasPerPlayer = 5,
    
    -- Distanza massima di posizionamento dalla posizione del giocatore
    maxPlacementDistance = 10.0,
    
    -- Modelli di telecamere disponibili
    models = {
        'prop_cctv_cam_01a',
        'prop_cctv_cam_01b',
        'prop_cctv_cam_02a',
        'prop_cctv_cam_03a',
        'prop_cctv_cam_04a',
        'prop_cctv_cam_06a',
        'prop_cctv_cam_07a'
    }
}

-- Sistema Registrazione
Config.Recording = {
    -- Durata massima clip in millisecondi (5 minuti)
    maxClipDuration = 300000,
    
    -- Numero massimo di clip salvabili per giocatore
    maxClipsPerPlayer = 20,
    
    -- Qualità registrazione (placeholder per future implementazioni)
    quality = 'high'
}

-- Sistema Report Polizia
Config.Police = {
    -- Job della polizia (ESX)
    jobs = {'police', 'sheriff', 'fbi'},
    
    -- Tempo di permanenza del blip sulla mappa (in ms)
    blipDuration = 300000, -- 5 minuti
    
    -- Raggio di ricerca automatica sospetti
    suspectSearchRadius = 50.0,
    
    -- Notifiche automatiche
    autoNotify = true
}

-- Sistema Permessi
Config.Permissions = {
    -- Chi può posizionare telecamere
    canPlaceCameras = {'user', 'admin', 'moderator'},
    
    -- Chi può vedere tutte le telecamere
    canViewAllCameras = {'admin', 'moderator'},
    
    -- Chi può cancellare telecamere altrui
    canDeleteAnyCameras = {'admin'},
    
    -- Chi può accedere ai report avanzati
    canAccessAdvancedReports = {'police', 'admin'}
}

-- Database
Config.Database = {
    -- Tabelle del database
    tables = {
        cameras = 'security_cameras',
        clips = 'security_clips',
        sheets = 'security_sheets',
        reports = 'security_reports'
    }
}

-- UI Settings
Config.UI = {
    -- Keybinds predefiniti
    keybinds = {
        placecamera = 'F6',
        cameras = 'F7',
        clipcamera = 'F8',
        sheet = 'F9',
        reportpolice = 'F10'
    },
    
    -- Colori tema
    theme = {
        primary = '#00ff88',
        secondary = '#1e1e1e',
        danger = '#ff4444',
        warning = '#ffaa00'
    }
}

-- Messaggi di notifica
Config.Messages = {
    ['camera_placed'] = 'Telecamera posizionata con successo!',
    ['camera_deleted'] = 'Telecamera rimossa.',
    ['recording_started'] = 'Registrazione iniziata.',
    ['recording_stopped'] = 'Registrazione terminata e clip salvata.',
    ['report_sent'] = 'Report inviato alle forze dell\'ordine.',
    ['sheet_saved'] = 'Sheet salvato nel database.',
    ['no_cameras'] = 'Nessuna telecamera disponibile.',
    ['no_permission'] = 'Non hai il permesso per questa azione.',
    ['max_cameras_reached'] = 'Hai raggiunto il limite massimo di telecamere.',
    ['too_far'] = 'Troppo lontano per posizionare una telecamera.',
    ['invalid_position'] = 'Posizione non valida.',
    ['police_alert'] = 'ALERT SICUREZZA: Situazione sospetta rilevata.'
}
function Config.GetPlayerJob(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        return xPlayer.job.name
    end
    return nil
end

function Config.HasPermission(playerId, permission)
    local job = Config.GetPlayerJob(playerId)
    if not job then return false end
    
    for _, allowedJob in ipairs(Config.Permissions[permission] or {}) do
        if job == allowedJob then
            return true
        end
    end
    
    return false
end

function Config.LogAction(playerId, action, details)
    local playerName = GetPlayerName(playerId)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    
    if Config.Debug then
        print(string.format('[Security Camera] %s - %s (%d): %s - %s', 
            timestamp, playerName, playerId, action, details or 'N/A'))
    end
    
    -- Salva nel database per audit log
    MySQL.Async.execute('INSERT INTO security_logs (player_id, player_name, action, details, timestamp) VALUES (@player_id, @player_name, @action, @details, @timestamp)', {
        ['@player_id'] = playerId,
        ['@player_name'] = playerName,
        ['@action'] = action,
        ['@details'] = details or '',
        ['@timestamp'] = timestamp
    })
end

function Config.SendPoliceAlert(coords, message, evidence)
    local players = ESX.GetPlayers()
    local alertCount = 0
    
    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and Config.IsPoliceJob(xPlayer.job.name) then
            TriggerClientEvent('securitycam:receivePoliceAlert', playerId, {
                coords = coords,
                message = message,
                evidence = evidence,
                timestamp = os.time()
            })
            alertCount = alertCount + 1
        end
    end
    
    Config.LogAction(0, 'POLICE_ALERT_SENT', string.format('Alert sent to %d officers: %s', alertCount, message))
    
    return alertCount > 0
end

function Config.IsPoliceJob(jobName)
    for _, policeJob in ipairs(Config.Police.jobs) do
        if jobName == policeJob then
            return true
        end
    end
    return false
end