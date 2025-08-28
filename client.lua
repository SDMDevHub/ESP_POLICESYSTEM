local ESX = nil
local cameras = {}
local currentCamera = nil
local isInCameraMode = false
local isPlacingCamera = false
local isRecording = false
local recordingStartTime = 0
local recordings = {}
local cameraUI = false

-- Inizializzazione ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end
end)

-- ============================================================================
-- SISTEMA POSIZIONAMENTO TELECAMERE
-- ============================================================================

-- Comando per posizionare telecamera
RegisterCommand('placecamera', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    -- Apri UI per impostazioni telecamera
    openCameraSetupUI(coords, heading)
end, false)

-- Funzione per aprire UI setup telecamera
function openCameraSetupUI(coords, heading)
    isPlacingCamera = true
    
    -- Invia dati a NUI
    SendNUIMessage({
        type = 'openCameraSetup',
        coords = coords,
        heading = heading
    })
    
    SetNuiFocus(true, true)
    cameraUI = true
end

-- Callback NUI per confermare posizionamento
RegisterNUICallback('confirmCameraPlacement', function(data, cb)
    local cameraData = {
        id = #cameras + 1,
        coords = vector3(data.x, data.y, data.z),
        rotation = vector3(data.rotX, data.rotY, data.rotZ),
        maxDistance = data.maxDistance or 50.0,
        fov = data.fov or 60.0,
        owner = GetPlayerServerId(PlayerId())
    }
    
    -- Crea telecamera fisica nel mondo
    createPhysicalCamera(cameraData)
    
    -- Salva nel server
    TriggerServerEvent('securitycam:saveCamera', cameraData)
    
    table.insert(cameras, cameraData)
    
    SetNuiFocus(false, false)
    cameraUI = false
    isPlacingCamera = false
    
    ESX.ShowNotification('Telecamera posizionata con successo!')
    cb('ok')
end)

-- Crea oggetto telecamera fisica
function createPhysicalCamera(cameraData)
    local model = `prop_cctv_cam_01a`
    RequestModel(model)
    
    while not HasModelLoaded(model) do
        Citizen.Wait(1)
    end
    
    local camera = CreateObject(model, cameraData.coords.x, cameraData.coords.y, cameraData.coords.z, true, true, true)
    SetEntityRotation(camera, cameraData.rotation.x, cameraData.rotation.y, cameraData.rotation.z, 2, true)
    FreezeEntityPosition(camera, true)
    
    cameraData.object = camera
end

-- ============================================================================
-- SISTEMA VISUALIZZAZIONE TELECAMERE
-- ============================================================================

-- Comando per aprire pannello telecamere
RegisterCommand('cameras', function()
    if #cameras == 0 then
        ESX.ShowNotification('Nessuna telecamera disponibile')
        return
    end
    
    openCameraPanel()
end, false)

-- Apri pannello controllo telecamere
function openCameraPanel()
    SendNUIMessage({
        type = 'openCameraPanel',
        cameras = cameras
    })
    
    SetNuiFocus(true, true)
    cameraUI = true
end

-- Callback per visualizzare telecamera
RegisterNUICallback('viewCamera', function(data, cb)
    local cameraId = data.cameraId
    viewCamera(cameraId)
    cb('ok')
end)

-- Visualizza telecamera specifica
function viewCamera(cameraId)
    local cameraData = cameras[cameraId]
    if not cameraData then return end
    
    -- Crea telecamera script
    currentCamera = CreateCameraWithParams("DEFAULT_SCRIPTED_CAMERA", 
        cameraData.coords.x, cameraData.coords.y, cameraData.coords.z + 2.0,
        cameraData.rotation.x, cameraData.rotation.y, cameraData.rotation.z,
        cameraData.fov, false, 0)
    
    SetCamActive(currentCamera, true)
    RenderScriptCams(true, true, 1000, true, true)
    
    isInCameraMode = true
    
    -- UI overlay telecamera
    SendNUIMessage({
        type = 'cameraView',
        cameraId = cameraId,
        cameraData = cameraData
    })
    
    SetNuiFocus(false, false)
    cameraUI = false
    
    -- Thread controlli telecamera
    Citizen.CreateThread(function()
        while isInCameraMode do
            Citizen.Wait(0)
            
            -- Controlli telecamera
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) -- Mouse look
            EnableControlAction(0, 2, true) -- Mouse look
            EnableControlAction(0, 200, true) -- ESC
            
            -- Esci con ESC
            if IsControlJustPressed(0, 200) then
                exitCameraMode()
            end
            
            -- Zoom
            if IsControlPressed(0, 21) then -- Shift
                SetCamFov(currentCamera, 20.0)
            else
                SetCamFov(currentCamera, cameraData.fov)
            end
        end
    end)
end

-- Esci dalla modalità telecamera
function exitCameraMode()
    if currentCamera then
        SetCamActive(currentCamera, false)
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(currentCamera, true)
        currentCamera = nil
    end
    
    isInCameraMode = false
    
    SendNUIMessage({
        type = 'closeCameraView'
    })
end

-- ============================================================================
-- SISTEMA REGISTRAZIONE CLIP
-- ============================================================================

-- Comando per menu clip
RegisterCommand('clipcamera', function()
    openClipMenu()
end, false)

-- Apri menu clip
function openClipMenu()
    SendNUIMessage({
        type = 'openClipMenu',
        recordings = recordings
    })
    
    SetNuiFocus(true, true)
    cameraUI = true
end

-- Inizia registrazione
RegisterNUICallback('startRecording', function(data, cb)
    if not isInCameraMode then
        cb('error')
        return
    end
    
    isRecording = true
    recordingStartTime = GetGameTimer()
    
    ESX.ShowNotification('Registrazione iniziata')
    
    SendNUIMessage({
        type = 'recordingStatus',
        recording = true
    })
    
    cb('ok')
end)

-- Ferma registrazione
RegisterNUICallback('stopRecording', function(data, cb)
    if not isRecording then
        cb('error')
        return
    end
    
    local recordingDuration = GetGameTimer() - recordingStartTime
    local clipData = {
        id = #recordings + 1,
        cameraId = data.cameraId,
        timestamp = os.time(),
        duration = recordingDuration,
        coords = cameras[data.cameraId].coords
    }
    
    table.insert(recordings, clipData)
    
    -- Salva clip nel server
    TriggerServerEvent('securitycam:saveClip', clipData)
    
    isRecording = false
    recordingStartTime = 0
    
    ESX.ShowNotification('Clip salvata!')
    
    SendNUIMessage({
        type = 'recordingStatus',
        recording = false
    })
    
    cb('ok')
end)
-- ============================================================================
-- SISTEMA SHEET ESX
-- ============================================================================

-- Comando per aprire sheet
RegisterCommand('sheet', function()
    openSheetUI()
end, false)

-- Apri UI sheet
function openSheetUI()
    SendNUIMessage({
        type = 'openSheet'
    })
    
    SetNuiFocus(true, true)
    cameraUI = true
end

-- Callback salva sheet
RegisterNUICallback('saveSheet', function(data, cb)
    local sheetData = {
        title = data.title,
        content = data.content,
        author = GetPlayerName(PlayerId()),
        timestamp = os.time()
    }
    
    -- Salva nel server
    TriggerServerEvent('securitycam:saveSheet', sheetData)
    
    ESX.ShowNotification('Sheet salvato!')
    
    SetNuiFocus(false, false)
    cameraUI = false
    
    cb('ok')
end)

-- ============================================================================
-- EVENTI SERVER
-- ============================================================================

-- Carica telecamere dal server
RegisterNetEvent('securitycam:loadCameras')
AddEventHandler('securitycam:loadCameras', function(serverCameras)
    cameras = serverCameras
    
    -- Crea oggetti fisici per tutte le telecamere
    for _, cameraData in ipairs(cameras) do
        createPhysicalCamera(cameraData)
    end
end)

-- Ricevi notifica polizia
RegisterNetEvent('securitycam:receivePoliceAlert')
AddEventHandler('securitycam:receivePoliceAlert', function(reportData)
    ESX.ShowNotification('~r~ALERT SICUREZZA~w~: ' .. reportData.description)
    
    -- Crea blip sulla mappa
    local blip = AddBlipForCoord(reportData.coords.x, reportData.coords.y, reportData.coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 1.0)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Security Alert")
    EndTextCommandSetBlipName(blip)
    
    -- Rimuovi blip dopo 5 minuti
    Citizen.SetTimeout(300000, function()
        RemoveBlip(blip)
    end)
end)

-- Thread principale
Citizen.CreateThread(function()
    -- Carica telecamere all'avvio
    TriggerServerEvent('securitycam:requestCameras')
    
    while true do
        Citizen.Wait(0)
        
        -- Chiudi UI con ESC
        if cameraUI and IsControlJustPressed(0, 200) then
            SetNuiFocus(false, false)
            cameraUI = false
            
            SendNUIMessage({
                type = 'closeAllUI'
            })
        end
    end
end)
function Config.GetNearbyPlayers(coords, radius)
    local players = {}
    local myCoords = coords or GetEntityCoords(PlayerPedId())
    
    for _, playerId in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(playerId)
        local targetCoords = GetEntityCoords(targetPed)
        local distance = #(myCoords - targetCoords)
        
        if distance <= radius and playerId ~= PlayerId() then
            table.insert(players, {
                id = playerId,
                ped = targetPed,
                coords = targetCoords,
                distance = distance,
                name = GetPlayerName(playerId)
            })
        end
    end
    
    return players
end

function Config.CreateBlip(coords, sprite, color, text, duration)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 161)
    SetBlipColour(blip, color or 1)
    SetBlipScale(blip, 1.0)
    SetBlipAsShortRange(blip, true)
    
    if text then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(text)
        EndTextCommandSetBlipName(blip)
    end
    
    if duration then
        Citizen.SetTimeout(duration, function()
            RemoveBlip(blip)
        end)
    end
    
    return blip
end

function Config.ShowAdvancedNotification(title, message, duration, type)
    local notifType = type or 'info'
    local colors = {
        success = '~g~',
        error = '~r~',
        warning = '~y~',
        info = '~b~'
    }
    
    local color = colors[notifType] or colors.info
    
    SetNotificationTextEntry("STRING")
    AddTextComponentString(color .. title .. '~w~\n' .. message)
    DrawNotification(false, true)
    
    if duration then
        Citizen.SetTimeout(duration * 1000, function()
          
        end)
    end
end