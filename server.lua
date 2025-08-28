local ESX = nil
local cameras = {}
local clips = {}
local sheets = {}

-- Initialize ESX
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Save camera
RegisterServerEvent('securitycam:saveCamera')
AddEventHandler('securitycam:saveCamera', function(cameraData)
    local source = source
    
    -- Save to database (example MySQL)
    MySQL.Async.execute('INSERT INTO security_cameras (coords, rotation, max_distance, fov, owner) VALUES (@coords, @rotation, @max_distance, @fov, @owner)', {
        ['@coords'] = json.encode(cameraData.coords),
        ['@rotation'] = json.encode(cameraData.rotation),
        ['@max_distance'] = cameraData.maxDistance,
        ['@fov'] = cameraData.fov,
        ['@owner'] = cameraData.owner
    })
    
    table.insert(cameras, cameraData)
    
    -- Sync with all clients
    TriggerClientEvent('securitycam:loadCameras', -1, cameras)
end)

-- Richiesta telecamere
RegisterServerEvent('securitycam:requestCameras')
AddEventHandler('securitycam:requestCameras', function()
    local source = source
    
    -- Carica dal database
    MySQL.Async.fetchAll('SELECT * FROM security_cameras', {}, function(results)
        local loadedCameras = {}
        
        for _, camera in ipairs(results) do
            table.insert(loadedCameras, {
                id = camera.id,
                coords = json.decode(camera.coords),
                rotation = json.decode(camera.rotation),
                maxDistance = camera.max_distance,
                fov = camera.fov,
                owner = camera.owner
            })
        end
        
        cameras = loadedCameras
        TriggerClientEvent('securitycam:loadCameras', source, cameras)
    end)
end)

-- Save clip 
RegisterServerEvent('securitycam:saveClip')
AddEventHandler('securitycam:saveClip', function(clipData)
   -- Save to database
    MySQL.Async.execute('INSERT INTO security_clips (camera_id, timestamp, duration, coords) VALUES (@camera_id, @timestamp, @duration, @coords)', {
        ['@camera_id'] = clipData.cameraId,
        ['@timestamp'] = clipData.timestamp,
        ['@duration'] = clipData.duration,
        ['@coords'] = json.encode(clipData.coords)
    })
    
    table.insert(clips, clipData)
end)

-- Report to the police
RegisterServerEvent('securitycam:sendPoliceReport')
AddEventHandler('securitycam:sendPoliceReport', function(reportData)
    local xPlayers = ESX.GetPlayers()
    
    -- Send to all cops online
    for _, playerId in ipairs(xPlayers) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        
        if xPlayer.job.name == 'police' then
            TriggerClientEvent('securitycam:receivePoliceAlert', playerId, reportData)
        end
    end
end)

-- Salva sheet
RegisterServerEvent('securitycam:saveSheet')
AddEventHandler('securitycam:saveSheet', function(sheetData)
    -- Save to database
    MySQL.Async.execute('INSERT INTO security_sheets (title, content, author, timestamp) VALUES (@title, @content, @author, @timestamp)', {
        ['@title'] = sheetData.title,
        ['@content'] = sheetData.content,
        ['@author'] = sheetData.author,
        ['@timestamp'] = sheetData.timestamp
    })
end)
