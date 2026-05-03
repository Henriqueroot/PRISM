local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local isRecording = false
local isPlaying = false
local recordedFrames = {}
local currentFrameIndex = 1
local startPositionMarker = nil
local loadedTASData = nil
local recordingConnection = nil
local playbackConnection = nil

local recordingModeEnabled = false
local playbackModeEnabled = false

local savedAutoRotateValue = nil

local recordingStartTimestamp = 0
local playbackStartTimestamp = 0


local tasStorageFolder = "PrismTAS"

local CurrentSaveName = ""
local lastLoadedTASName = ""

local TASFileDropdown
local markerColor = Color3.fromRGB(180, 80, 255)


local tasOptions = {}

local PrismTheme = {
    TextColor = Color3.fromRGB(235, 200, 255),
    Background = Color3.fromRGB(10, 8, 18),
    Topbar = Color3.fromRGB(20, 12, 40),
    Shadow = Color3.fromRGB(0, 0, 0),

    NotificationBackground = Color3.fromRGB(20, 10, 35),
    NotificationActionsBackground = Color3.fromRGB(200, 120, 255),

    TabBackground = Color3.fromRGB(15, 10, 25),
    TabStroke = Color3.fromRGB(120, 70, 200),
    TabBackgroundSelected = Color3.fromRGB(120, 70, 200),
    TabTextColor = Color3.fromRGB(200, 160, 255),
    SelectedTabTextColor = Color3.fromRGB(255, 255, 255),

    ElementBackground = Color3.fromRGB(18, 12, 30),
    ElementBackgroundHover = Color3.fromRGB(30, 20, 50),
    SecondaryElementBackground = Color3.fromRGB(14, 8, 25),

    ElementStroke = Color3.fromRGB(120, 70, 200),
    SecondaryElementStroke = Color3.fromRGB(90, 50, 150),

    SliderBackground = Color3.fromRGB(70, 40, 120),
    SliderProgress = Color3.fromRGB(210, 130, 255),
    SliderStroke = Color3.fromRGB(235, 200, 255),

    ToggleBackground = Color3.fromRGB(14, 8, 25),
    ToggleEnabled = Color3.fromRGB(200, 120, 255),
    ToggleDisabled = Color3.fromRGB(60, 40, 90),
    ToggleEnabledStroke = Color3.fromRGB(235, 200, 255),
    ToggleDisabledStroke = Color3.fromRGB(80, 50, 130),
    ToggleEnabledOuterStroke = Color3.fromRGB(200, 120, 255),
    ToggleDisabledOuterStroke = Color3.fromRGB(60, 40, 90),

    DropdownSelected = Color3.fromRGB(26, 16, 40),
    DropdownUnselected = Color3.fromRGB(18, 12, 30),

    InputBackground = Color3.fromRGB(14, 8, 25),
    InputStroke = Color3.fromRGB(120, 70, 200),
    PlaceholderColor = Color3.fromRGB(150, 120, 190)
}

local Window = Rayfield:CreateWindow({
    Name = "✨ P R I S M | TAS ✨",
    Icon = 13087593204,
    LoadingTitle = "P R I S M - Tool Assisted System",
    LoadingSubtitle = "Desenvolvido por toxicy",
    Theme = PrismTheme,
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "PrismTAS",
        FileName = "Prism_Config"
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})


local RecordTab = Window:CreateTab("🎥 Gravar", 6023426915)
local PlaybackTab = Window:CreateTab("⏱ Reproduzir", 6023426923)
local SettingsTab = Window:CreateTab("⚙ Config", 6031280882)

if not isfolder(tasStorageFolder) then
    makefolder(tasStorageFolder)
end

local function getTASFileListFromDisk()
    local fileList = {}

    if not isfolder(tasStorageFolder) then
        return fileList
    end

    local success, files = pcall(function()
        return listfiles(tasStorageFolder)
    end)

    if not success or not files then
        return fileList
    end

    for _, filePath in ipairs(files) do
        local fileName = filePath:match("([^/\\]+)$")
        if fileName and fileName:match("%.json$") then
            local nameWithoutExtension = fileName:gsub("%.json$", "")
            table.insert(fileList, nameWithoutExtension)
        end
    end

    table.sort(fileList)
    return fileList
end

local function applyDropdownOptions()
    if TASFileDropdown then
        TASFileDropdown:Refresh(tasOptions)
    end
end

local function createStartPositionMarker(position)
    if startPositionMarker then
        startPositionMarker:Destroy()
    end

    local markerPart = Instance.new("Part")
    markerPart.Size = Vector3.new(8, 10, 8)
    markerPart.Position = position
    markerPart.Anchored = true
    markerPart.CanCollide = false
    markerPart.Transparency = 0.3
    markerPart.Color = markerColor
    markerPart.Material = Enum.Material.Neon
    markerPart.Parent = workspace

    startPositionMarker = markerPart
    return markerPart
end

local function captureCurrentFrame()
    local characterCFrame = HumanoidRootPart.CFrame
    local characterVelocity = HumanoidRootPart.AssemblyLinearVelocity
    local humanoidReference = Character:FindFirstChild("Humanoid")
    local isJumping = humanoidReference and humanoidReference:GetState() == Enum.HumanoidStateType.Jumping

    local cameraCFrame = workspace.CurrentCamera.CFrame

    local x, y, z,
        r00, r01, r02,
        r10, r11, r12,
        r20, r21, r22 = characterCFrame:GetComponents()

    local cx, cy, cz,
        cr00, cr01, cr02,
        cr10, cr11, cr12,
        cr20, cr21, cr22 = cameraCFrame:GetComponents()

    local elapsedTime = tick() - recordingStartTimestamp

    table.insert(recordedFrames, {
        cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
        vel = { characterVelocity.X, characterVelocity.Y, characterVelocity.Z },
        jump = isJumping,
        cam = { cx, cy, cz, cr00, cr01, cr02, cr10, cr11, cr12, cr20, cr21, cr22 },
        time = elapsedTime
    })
end

local function beginRecording()
    recordedFrames = {}
    isRecording = true
    currentFrameIndex = 1
    recordingStartTimestamp = tick()

    if recordingConnection then
        recordingConnection:Disconnect()
    end

    recordingConnection = RunService.Heartbeat:Connect(function()
        if isRecording then
            captureCurrentFrame()
        end
    end)

    Rayfield:Notify({
        Title = "PRISM | Gravação",
        Content = "Gravação iniciada.",
        Duration = 2,
        Image = 13087593204
    })
end

local function endRecording()
    isRecording = false

    if recordingConnection then
        recordingConnection:Disconnect()
        recordingConnection = nil
    end

    local totalDuration = #recordedFrames > 0 and recordedFrames[#recordedFrames].time or 0

    Rayfield:Notify({
        Title = "PRISM | Gravação",
        Content = string.format("Gravação parada - %d frames (%.2fs)", #recordedFrames, totalDuration),
        Duration = 3,
        Image = 13087593204
    })
end

local function serializeTASData()
    local HttpService = game:GetService("HttpService")
    local dataStructure = {
        Version = 2,
        Frames = recordedFrames,
        Duration = #recordedFrames > 0 and recordedFrames[#recordedFrames].time or 0
    }
    return HttpService:JSONEncode(dataStructure)
end

local function loadTASFromFile(fileName)
    if not fileName or fileName == "" then
        Rayfield:Notify({
            Title = "PRISM | Erro",
            Content = "Selecione um TAS para carregar.",
            Duration = 2,
            Image = 13087593204
        })
        return false
    end

    local fullFilePath = tasStorageFolder .. "/" .. fileName .. ".json"

    if not isfile(fullFilePath) then
        Rayfield:Notify({
            Title = "PRISM | Erro",
            Content = "Arquivo não encontrado.",
            Duration = 2,
            Image = 13087593204
        })
        return false
    end

    local fileContent = readfile(fullFilePath)
    local HttpService = game:GetService("HttpService")
    local ok, parsedData = pcall(function()
        return HttpService:JSONDecode(fileContent)
    end)

    if ok and parsedData.Frames then
        loadedTASData = parsedData.Frames
        lastLoadedTASName = fileName
        local totalDuration = parsedData.Duration or (#parsedData.Frames > 0 and parsedData.Frames[#parsedData.Frames].time or 0)
        Rayfield:Notify({
            Title = "PRISM | TAS Carregado",
            Content = string.format("'%s' carregado (%d frames, %.2fs)", fileName, #parsedData.Frames, totalDuration),
            Duration = 3,
            Image = 13087593204
        })
        return true
    else
        Rayfield:Notify({
            Title = "PRISM | Erro",
            Content = "Falha ao carregar TAS.",
            Duration = 3,
            Image = 13087593204
        })
        return false
    end
end

local function saveTASToFile(fileName)
    if #recordedFrames == 0 then
        Rayfield:Notify({
            Title = "PRISM | Erro",
            Content = "Nenhum frame para salvar.",
            Duration = 2,
            Image = 13087593204
        })
        return false
    end

    if not fileName or fileName == "" then
        Rayfield:Notify({
            Title = "PRISM | Erro",
            Content = "Digite um nome para o TAS.",
            Duration = 2,
            Image = 13087593204
        })
        return false
    end

    if fileName:match("[\\/:*?\"<>|]") then
        Rayfield:Notify({
            Title = "PRISM | Erro",
            Content = "Nome inválido. Use apenas letras, números, _ e -",
            Duration = 3,
            Image = 13087593204
        })
        return false
    end

    local serializedData = serializeTASData()
    local fullFilePath = tasStorageFolder .. "/" .. fileName .. ".json"

    writefile(fullFilePath, serializedData)

    local totalDuration = #recordedFrames > 0 and recordedFrames[#recordedFrames].time or 0
    Rayfield:Notify({
        Title = "PRISM | Sucesso",
        Content = string.format("TAS '%s' salvo (%d frames, %.2fs)", fileName, #recordedFrames, totalDuration),
        Duration = 3,
        Image = 13087593204
    })

  
    local exists = false
    for _, name in ipairs(tasOptions) do
        if name == fileName then
            exists = true
            break
        end
    end
    if not exists then
        table.insert(tasOptions, fileName)
        table.sort(tasOptions)
        applyDropdownOptions()
    end

    return true
end

local function deleteTASFile(fileName)
    if not fileName or fileName == "" then
        return false
    end

    local fullFilePath = tasStorageFolder .. "/" .. fileName .. ".json"

    if not isfile(fullFilePath) then
        Rayfield:Notify({
            Title = "PRISM | Erro",
            Content = "Arquivo não encontrado.",
            Duration = 2,
            Image = 13087593204
        })
        return false
    end

    delfile(fullFilePath)

    Rayfield:Notify({
        Title = "PRISM | Sucesso",
        Content = "TAS '" .. fileName .. "' deletado.",
        Duration = 2,
        Image = 13087593204
    })

  
    for i, name in ipairs(tasOptions) do
        if name == fileName then
            table.remove(tasOptions, i)
            break
        end
    end
    applyDropdownOptions()

    return true
end

local function interpolateFrames(firstFrame, secondFrame, interpolationAlpha)
    local interpolatedFrame = {}

    if firstFrame.cf and secondFrame.cf then
        local c1 = CFrame.new(
            firstFrame.cf[1], firstFrame.cf[2], firstFrame.cf[3],
            firstFrame.cf[4], firstFrame.cf[5], firstFrame.cf[6],
            firstFrame.cf[7], firstFrame.cf[8], firstFrame.cf[9],
            firstFrame.cf[10], firstFrame.cf[11], firstFrame.cf[12]
        )
        local c2 = CFrame.new(
            secondFrame.cf[1], secondFrame.cf[2], secondFrame.cf[3],
            secondFrame.cf[4], secondFrame.cf[5], secondFrame.cf[6],
            secondFrame.cf[7], secondFrame.cf[8], secondFrame.cf[9],
            secondFrame.cf[10], secondFrame.cf[11], secondFrame.cf[12]
        )
        interpolatedFrame.cf = c1:Lerp(c2, interpolationAlpha)
    end

    if firstFrame.vel and secondFrame.vel then
        interpolatedFrame.vel = Vector3.new(
            firstFrame.vel[1] + (secondFrame.vel[1] - firstFrame.vel[1]) * interpolationAlpha,
            firstFrame.vel[2] + (secondFrame.vel[2] - firstFrame.vel[2]) * interpolationAlpha,
            firstFrame.vel[3] + (secondFrame.vel[3] - firstFrame.vel[3]) * interpolationAlpha
        )
    end

    if firstFrame.cam and secondFrame.cam then
        local camera1 = CFrame.new(
            firstFrame.cam[1], firstFrame.cam[2], firstFrame.cam[3],
            firstFrame.cam[4], firstFrame.cam[5], firstFrame.cam[6],
            firstFrame.cam[7], firstFrame.cam[8], firstFrame.cam[9],
            firstFrame.cam[10], firstFrame.cam[11], firstFrame.cam[12]
        )
        local camera2 = CFrame.new(
            secondFrame.cam[1], secondFrame.cam[2], secondFrame.cam[3],
            secondFrame.cam[4], secondFrame.cam[5], secondFrame.cam[6],
            secondFrame.cam[7], secondFrame.cam[8], secondFrame.cam[9],
            secondFrame.cam[10], secondFrame.cam[11], secondFrame.cam[12]
        )
        interpolatedFrame.cam = camera1:Lerp(camera2, interpolationAlpha)
    end

    interpolatedFrame.jump = interpolationAlpha < 0.5 and firstFrame.jump or secondFrame.jump

    return interpolatedFrame
end

local function startTASPlayback()
    if not loadedTASData or #loadedTASData == 0 then
        Rayfield:Notify({
            Title = "PRISM | Erro",
            Content = "Nenhum TAS carregado.",
            Duration = 2,
            Image = 13087593204
        })
        return
    end

    isPlaying = true
    currentFrameIndex = 1
    playbackStartTimestamp = tick()

    Rayfield:Notify({
        Title = "PRISM | Reprodução",
        Content = "Iniciando reprodução...",
        Duration = 2,
        Image = 13087593204
    })

    if playbackConnection then
        playbackConnection:Disconnect()
    end

    HumanoidRootPart.Anchored = false
    Humanoid.PlatformStand = false

    savedAutoRotateValue = Humanoid.AutoRotate
    Humanoid.AutoRotate = false

    playbackConnection = RunService.Heartbeat:Connect(function()
        if not isPlaying then
            if playbackConnection then
                playbackConnection:Disconnect()
                playbackConnection = nil
            end

            HumanoidRootPart.Anchored = false
            Humanoid.PlatformStand = false

            if savedAutoRotateValue ~= nil then
                Humanoid.AutoRotate = savedAutoRotateValue
            end

            Rayfield:Notify({
                Title = "PRISM | Reprodução",
                Content = "Reprodução finalizada.",
                Duration = 2,
                Image = 13087593204
            })

            if startPositionMarker then
                startPositionMarker:Destroy()
                startPositionMarker = nil
            end

            return
        end

        local currentElapsedTime = tick() - playbackStartTimestamp

        local currentFrameData = nil
        local nextFrameData = nil
        local interpolationValue = 0

        for frameIndex = currentFrameIndex, #loadedTASData do
            if loadedTASData[frameIndex].time <= currentElapsedTime then
                currentFrameData = loadedTASData[frameIndex]
                currentFrameIndex = frameIndex

                if frameIndex < #loadedTASData then
                    nextFrameData = loadedTASData[frameIndex + 1]
                    local timeDifference = nextFrameData.time - currentFrameData.time
                    if timeDifference > 0 then
                        interpolationValue = (currentElapsedTime - currentFrameData.time) / timeDifference
                        interpolationValue = math.clamp(interpolationValue, 0, 1)
                    end
                end
            else
                break
            end
        end

        if currentFrameIndex >= #loadedTASData and currentElapsedTime > loadedTASData[#loadedTASData].time then
            isPlaying = false
            return
        end

        if not currentFrameData then
            return
        end

        local frameToApply = currentFrameData
        if nextFrameData and interpolationValue > 0 then
            frameToApply = interpolateFrames(currentFrameData, nextFrameData, interpolationValue)
        end

        if frameToApply.vel then
            local v
            if type(frameToApply.vel) == "table" then
                v = Vector3.new(frameToApply.vel[1], frameToApply.vel[2], frameToApply.vel[3])
            else
                v = frameToApply.vel
            end
            HumanoidRootPart.AssemblyLinearVelocity = v
        end

        if frameToApply.cf then
            if type(frameToApply.cf) == "table" then
                local d = frameToApply.cf
                HumanoidRootPart.CFrame = CFrame.new(
                    d[1], d[2], d[3],
                    d[4], d[5], d[6],
                    d[7], d[8], d[9],
                    d[10], d[11], d[12]
                )
            else
                HumanoidRootPart.CFrame = frameToApply.cf
            end
        end

        if currentFrameData.jump then
            local humanoidReference = Character:FindFirstChild("Humanoid")
            if humanoidReference and humanoidReference:GetState() ~= Enum.HumanoidStateType.Jumping then
                humanoidReference:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end

        if frameToApply.cam then
            if type(frameToApply.cam) == "table" then
                local c = frameToApply.cam
                workspace.CurrentCamera.CFrame = CFrame.new(
                    c[1], c[2], c[3],
                    c[4], c[5], c[6],
                    c[7], c[8], c[9],
                    c[10], c[11], c[12]
                )
            else
                workspace.CurrentCamera.CFrame = frameToApply.cam
            end
        end
    end)
end

local function stopTASPlayback()
    isPlaying = false

    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end

    HumanoidRootPart.Anchored = false
    Humanoid.PlatformStand = false

    if savedAutoRotateValue ~= nil then
        Humanoid.AutoRotate = savedAutoRotateValue
    end

    if startPositionMarker then
        startPositionMarker:Destroy()
        startPositionMarker = nil
    end

    Rayfield:Notify({
        Title = "PRISM | Reprodução",
        Content = "Reprodução parada.",
        Duration = 2,
        Image = 13087593204
    })
end


RecordTab:CreateParagraph({
    Title = "🎥 Gravação TAS",
    Content = "Ative o modo de gravação e use [E] para iniciar e [Q] para parar.\nFeito por toxicy."
})

local RecordModeToggle = RecordTab:CreateToggle({
    Name = "Ativar Modo de Gravação",
    CurrentValue = false,
    Flag = "ModoGravacao",
    Callback = function(v)
        recordingModeEnabled = v
        if v then
            Rayfield:Notify({
                Title = "PRISM | Gravação",
                Content = "Pressione E para iniciar, Q para parar.",
                Duration = 3,
                Image = 13087593204
            })
        else
            if isRecording then
                endRecording()
            end
        end
    end
})

local FrameCounterLabel = RecordTab:CreateLabel("Frames Gravados: 0")

RecordTab:CreateInput({
    Name = "Nome do TAS",
    CurrentValue = "",
    PlaceholderText = "Digite o nome...",
    RemoveTextAfterFocusLost = false,
    Flag = "SaveName",
    Callback = function(text)
        CurrentSaveName = text or ""
    end
})

RecordTab:CreateButton({
    Name = "💾 Salvar TAS",
    Callback = function()
        saveTASToFile(CurrentSaveName)
    end
})


PlaybackTab:CreateParagraph({
    Title = "⏱ Reproduzir TAS",
    Content = "Selecione um TAS salvo, ative o modo e use [E] para iniciar / [Q] para parar."
})


tasOptions = getTASFileListFromDisk()

TASFileDropdown = PlaybackTab:CreateDropdown({
    Name = "Selecionar TAS",
    Options = tasOptions,
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "TASDropdown",
    Callback = function(option)
        local name = option and option[1]
        if name and name ~= "" then
            loadTASFromFile(name)
        end
    end
})

PlaybackTab:CreateButton({
    Name = "🔄 Atualizar Lista",
    Callback = function()
        local newList = getTASFileListFromDisk()
        if #newList == 0 and #tasOptions > 0 then
            -- executor bugou listfiles, não vamos apagar o que já temos
            Rayfield:Notify({
                Title = "PRISM | Lista",
                Content = "Nenhum arquivo novo encontrado, mantendo lista atual.",
                Duration = 2,
                Image = 13087593204
            })
        else
            tasOptions = newList
            applyDropdownOptions()
            Rayfield:Notify({
                Title = "PRISM | Lista",
                Content = "Lista de TAS atualizada.",
                Duration = 2,
                Image = 13087593204
            })
        end
    end
})

PlaybackTab:CreateButton({
    Name = "🗑 Deletar TAS Selecionado",
    Callback = function()
        if lastLoadedTASName ~= "" then
            deleteTASFile(lastLoadedTASName)
            lastLoadedTASName = ""
        else
            Rayfield:Notify({
                Title = "PRISM | Erro",
                Content = "Nenhum TAS selecionado/carregado.",
                Duration = 2,
                Image = 13087593204
            })
        end
    end
})

local PlaybackModeToggle = PlaybackTab:CreateToggle({
    Name = "Ativar Modo de Reprodução",
    CurrentValue = false,
    Flag = "ModoReproducao",
    Callback = function(v)
        playbackModeEnabled = v
        if v then
            if not loadedTASData or #loadedTASData == 0 then
                Rayfield:Notify({
                    Title = "PRISM | Erro",
                    Content = "Carregue um TAS primeiro.",
                    Duration = 2,
                    Image = 13087593204
                })
                PlaybackModeToggle:Set(false)
                playbackModeEnabled = false
                return
            end

            local firstFrameData = loadedTASData[1]
            if firstFrameData and firstFrameData.cf then
                local startPosition = Vector3.new(firstFrameData.cf[1], firstFrameData.cf[2], firstFrameData.cf[3])
                createStartPositionMarker(startPosition)

                Rayfield:Notify({
                    Title = "PRISM | Reprodução",
                    Content = "Vá até o marcador e aperte E para iniciar.",
                    Duration = 4,
                    Image = 13087593204
                })
            end
        else
            if isPlaying then
                stopTASPlayback()
            end
            if startPositionMarker then
                startPositionMarker:Destroy()
                startPositionMarker = nil
            end
        end
    end
})


SettingsTab:CreateParagraph({
    Title = "⌨ Controles",
    Content = "Gravação: [E] Iniciar | [Q] Parar\nReprodução: [E] Iniciar | [Q] Parar"
})

SettingsTab:CreateParagraph({
    Title = "🧠 Sistema de Sincronização",
    Content = "PRISM TAS usa timestamps para rodar consistente em qualquer FPS."
})

SettingsTab:CreateLabel("PRISM TAS • desenvolvido por toxicy")

SettingsTab:CreateColorPicker({
    Name = "Cor do Marcador",
    Color = markerColor,
    Flag = "MarkerColor",
    Callback = function(color)
        markerColor = color
        if startPositionMarker then
            startPositionMarker.Color = markerColor
        end
    end
})


UserInputService.InputBegan:Connect(function(inputObject, isProcessedByGame)
    if isProcessedByGame then return end

    if inputObject.KeyCode == Enum.KeyCode.E then
        if recordingModeEnabled and not isRecording then
            beginRecording()
        elseif playbackModeEnabled and not isPlaying then
            if loadedTASData and #loadedTASData > 0 then
                local firstFrameData = loadedTASData[1]
                if firstFrameData and firstFrameData.cf then
                    local startPosition = Vector3.new(firstFrameData.cf[1], firstFrameData.cf[2], firstFrameData.cf[3])
                    local distanceToMarker = (HumanoidRootPart.Position - startPosition).Magnitude
                    if distanceToMarker <= 12 then
                        if startPositionMarker then
                            startPositionMarker:Destroy()
                            startPositionMarker = nil
                        end
                        startTASPlayback()
                    else
                        Rayfield:Notify({
                            Title = "PRISM | Erro",
                            Content = "Você precisa estar em cima do marcador.",
                            Duration = 2,
                            Image = 13087593204
                        })
                    end
                end
            end
        end
    elseif inputObject.KeyCode == Enum.KeyCode.Q then
        if recordingModeEnabled and isRecording then
            endRecording()
        elseif playbackModeEnabled and isPlaying then
            stopTASPlayback()
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if isRecording then
        local recordDuration = tick() - recordingStartTimestamp
        FrameCounterLabel:Set(string.format("Frames Gravados: %d (%.2fs)", #recordedFrames, recordDuration))
    end
end)

Rayfield:Notify({
    Title = "✨ P R I S M | toxicy",
    Content = "Sistema carregado com sucesso.",
    Duration = 4,
    Image = 13087593204
})
