local json = require "json"
local netlua = require "NetProxy"

lobby = {
    entry = "Main",
    game_index = 0,
    yaw = 0,
    pitch = 0,
    MOVE_SPEED = 10.0,
}
TOUCH_SENSITIVITY = 2
local frame_count_ = 0
local text_time_ = 0.0
local dc_ = 0
local tri_ = 0


local function Raycast(maxDistance)
    local pos = input_system:GetMousePosition()
    -- if click on ui return nil,nil
    --
    local cameraRay = lobby.camera:GetScreenRay(pos.x / graphics_system.width, pos.y / graphics_system.height)
    -- Pick only geometry objects, not eg. zones or lights, only get the first (closest) hit
    local octree = lobby.scene:GetComponent(Octree.id)
    local position, drawable = octree:RaycastSingle(cameraRay, graphic.RAY_TRIANGLE, maxDistance, graphic.DRAWABLE_GEOMETRY)
    if drawable then
        return position, drawable
    end

    return nil, nil
end

function lobby:OnUpdate(eventType, eventData)
    -- statistics
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    text_time_ = text_time_ + timeStep
    frame_count_ = frame_count_ + 1
    if text_time_ > 0.5 and self.statistics then
        -- local dc = graphics_system:GetNumBatches()
        -- local tri = graphics_system:GetNumPrimitives()
        -- if dc_ ~= dc or tri_ ~= tri then
        --     dc_ = dc
        --     tri_ = tri
            local stats = graphics_system:GetStats()
            self.statistics:SetText("FPS: "..math.floor(frame_count_/text_time_)..", "..stats)
        -- end
        frame_count_ = 0
        text_time_ = 0.0
    end
    if g_game_return then
        -- TODO: for fairygui test
        self:UnLoad()
        g_game_return = false
        return
    end
    if self.current_game and self.current_game.OnUpdate then
        self.current_game:OnUpdate(eventType, eventData)
        return
    end
    -- hit test
    local click = false
    if touchEnabled and input_system:GetTouch(0) then
        click = true
    else
        click = input_system:GetMouseButtonPress(input.MOUSEB_LEFT)
    end
    if click then
        local pos, drawable = Raycast(300)
        if drawable then
            if drawable:GetNode().name == "ClearCache" then
                filesystem:RemoveDir(self.game_dir, true)
                action_manager:AddAction(ActionBuilder():ScaleBy(0.5, math3d.Vector3(2, 2, 2)):SineInOut():ScaleBy(0.5, math3d.Vector3(0.5, 0.5, 0.5)):SineInOut():Build(), drawable:GetNode())
            end
            -- print("Hit a object : ", drawable:GetNode().name)
        end
    end
end

function lobby:OnSceneUpdate(eventType, eventData)
    if self.current_game and self.current_game.OnSceneUpdate then
        self.current_game:OnSceneUpdate(eventType, eventData)
        return
    end
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    self:UpdateCamera(timeStep)
end

function lobby:OnPostUpdate(eventType, eventData)
    if self.current_game and self.current_game.OnPostUpdate then
        self.current_game:OnPostUpdate(eventType, eventData)
        return
    end
end

function lobby:OnPostRenderUpdate(eventType, eventData)
    if self.current_game and self.current_game.OnPostRenderUpdate then
        self.current_game:OnPostRenderUpdate(eventType, eventData)
        return
    end
end

function do_unload(moduleName)
    for key, _ in pairs(package.preload) do
        if string.find(tostring(key), moduleName) == 1 then
            package.preload[key] = nil
        end
    end
    for key, _ in pairs(package.loaded) do
        if string.find(tostring(key), moduleName) == 1 then
            package.loaded[key] = nil
        end
    end
end

function lobby:UnLoad()
    if not self.current_game then
        return
    end
    self.current_game:UnLoad()
    if self.game_index > 0 then
        virtual_filesystem:Unmount(self.current_game_dir)
        local pkg = self.current_game_dir.."/data.pak"
        if filesystem:FileExists(pkg) then
            virtual_filesystem:Unmount(pkg)
        end
        self.current_game_dir = nil
        self.game_index = 0
    end
    self.current_game = nil
    do_unload("Main")
    -- if not self.use_package then
        cache:ReleaseResource("Scripts/Main.lua")
        cache:ReleaseResource("Scripts/Main.luac")
        -- cache:ReleaseAllResources()
    -- end
    --
    self.ui_scene.groot:RemoveChild(self.close_button)
    self.ui_scene.groot:AddChild(self.ui_view)
    self.viewport:SetScene(self.scene)
    self.viewport:SetCamera(self.camera_node:GetComponent(Camera.id))
end

function lobby:LoadGame(solo)
    if self.current_game then
        return
    end
    self:ShowDownloadProgress(false)
    if not solo then
        self.ui_scene.groot:AddChild(self.close_button)
    end
    if self.current_game_dir then
        virtual_filesystem:MountDir(self.current_game_dir)
        local pkg = self.current_game_dir.."/data.pak"
        if filesystem:FileExists(pkg) then
            virtual_filesystem:MountPackage(pkg)
        end
    end
    local game = require(self.entry)
    game:Load(self.viewport, self.ui_scene)
    self.current_game = game
end

function lobby:ShowDownloadProgress(show, progress)
    self.downloadtips:SetVisible(show)
    if show then
        self.downloadtips:SetText("Get resources from server..."..progress)
    end
end

function lobby:UpdateCamera(timeStep)
    if not FairyGUI.IsFocusUI() then
        local update = false
        if touchEnabled then
            for i=0, input_system:GetNumTouches()-1 do
                if input_system.GetJoystickTouchID() ~= i then
                    local state = input_system:GetTouch(i)
                    if state.delta.x or state.delta.y then
                        local camera = self.camera_node:GetComponent(Camera.id)
                        if not camera then
                            return
                        end
                        self.yaw = self.yaw + TOUCH_SENSITIVITY * camera.fov / graphics_system.height * state.delta.x
                        self.pitch = math3d.ClampF(self.pitch + TOUCH_SENSITIVITY * camera.fov / graphics_system.height * state.delta.y, -90.0, 90.0)
                        update = true
                    end
                    break
                end
            end
        elseif input_system:GetMouseButtonDown(input.MOUSEB_RIGHT) then
            -- Mouse sensitivity as degrees per pixel
            local MOUSE_SENSITIVITY = 0.1
            -- Use this frame's mouse motion to adjust camera node yaw and pitch. Clamp the pitch between -90 and 90 degrees
            local mouseMove = input_system.mouseMove
            self.yaw = self.yaw + MOUSE_SENSITIVITY * mouseMove.x
            self.pitch = math3d.ClampF(self.pitch + MOUSE_SENSITIVITY * mouseMove.y, -90.0, 90.0)
            update = true
        end
        if update then
            -- Construct new orientation for the camera scene node from yaw and pitch. Roll is fixed to zero
            self.camera_node.rotation = math3d.Quaternion(self.pitch, self.yaw, 0.0)
        end
    end
    local move = false
    local controlDirection = math3d.Vector3(0.0, 0.0, 0.0)
    if input_system.IsJoystickCapture() then
        controlDirection = math3d.Quaternion(0.0, input_system.GetJoystickDegree() - 90, 0.0) * math3d.Vector3.BACK
        move = true
    elseif not FairyGUI.IsInputing() then
        if input_system:GetKeyDown(input.KEY_W) then
            controlDirection = math3d.Vector3.FORWARD
            move = true
        end
        if input_system:GetKeyDown(input.KEY_S) then
            controlDirection = math3d.Vector3.BACK
            move = true
        end
        if input_system:GetKeyDown(input.KEY_A) then
            controlDirection = math3d.Vector3.LEFT
            move = true
        end
        if input_system:GetKeyDown(input.KEY_D) then
            controlDirection = math3d.Vector3.RIGHT
            move = true
        end
    end
    if move then
        self.camera_node:Translate(controlDirection * self.MOVE_SPEED * timeStep)
    end
end

function lobby:OnGameList(gamelist)
    local list = self.ui_view:GetChild("mailList")
    list:SetItemRenderer(function (index, obj)
        --obj:GetController("c1"):SetSelectedIndex((index % 3 == 0) and 1 or 0)
        --obj:GetController("IsRead"):SetSelectedIndex((index % 2 == 0) and 1 or 0);
        obj:GetChild("timeText"):SetText("Author: " .. gamelist[index + 1].author);
        obj:SetText(gamelist[index + 1].name);
    end)
    list:SetVirtual()
    list:SetNumItems(#gamelist)
    for _, v in ipairs(gamelist) do
        v.resource_dir = self.game_dir.."/"..v.id
        if not filesystem:DirExists(v.resource_dir) then
            filesystem:CreateDir(v.resource_dir)
        end
    end
    self.gamelist = gamelist
end

function lobby:LoadRequest(id, solo)
    self.ui_scene.groot:RemoveChild(self.ui_view)
    local localpath = self.game_dir.."/"..id
    local remotepath = "https://kfengine.com/Games/"..id
    if not filesystem:FileExists(localpath.."/fileinfo.json") then
        netlua:FetchFile(remotepath.."/fileinfo.json",
            function(fileinfo) netlua:DownloadAssets(remotepath, localpath, fileinfo) end,
            function() self:LoadGame() end,
            function(current, total) self:ShowDownloadProgress(true, current.."/"..total) end)
    else
        self:LoadGame(solo)
    end
end

function lobby:CreateScene()
    -- create scene
    local scene = Scene()
    scene:CreateComponent(Octree.id)
    local pipeline = scene:CreateComponent(RenderPipeline.id)
    -- rp:SetSettings({
    --     ColorSpace = render_pipeline.LinearLDR,
    --     PCFKernelSize = 5,
    --     Antialiasing = render_pipeline.FXAA3,
    -- })
    pipeline:SetAttribute("Color Space", Variant(0))-- 0: GammaLDR, 1: LinearLDR 2: LinearHDR
    -- pipeline:SetAttribute("Specular Quality", Variant(2)) -- 0: Disabled 1: Simple, 2: Antialiased
    pipeline:SetAttribute("PCF Kernel Size", touchEnabled and Variant(1) or Variant(3))
    -- pipeline:SetAttribute("Bloom", Variant(true))
    pipeline:SetAttribute("Post Process Antialiasing", touchEnabled and Variant(0) or Variant(2)) -- 0: "None" 1: "FXAA2" 2: "FXAA3"
    pipeline:SetAttribute("VSM Shadow Settings", Variant(math3d.Vector2(0.00015, 0.0)))

    local zone = scene:CreateComponent(Zone.id)
    zone.bounding_box = math3d.BoundingBox(-1000.0, 1000.0)
    zone.ambient_color = math3d.Color(0.5, 0.5, 0.5)
    zone.ambient_brightness = 1.0
    -- zone.background_brightness = 1.0
    -- zone.shadow_mask = -8
    -- zone.light_mask = -8
    zone.fog_color = math3d.Color(0.5, 0.5, 0.5)
    zone.fog_start = 100.0
    zone.fog_end = 300.0

    local planeNode = scene:CreateChild("Plane");
    planeNode.scale = math3d.Vector3(100.0, 1.0, 100.0)
    local plane = planeNode:CreateComponent(StaticModel.id)
    plane:SetModel(cache:GetResource("Model", "Models/Plane.mdl"))
    local mtl = cache:GetResource("Material", "Materials/GridTiled.xml")
    mtl:SetShaderParameter("UOffset", Variant(math3d.Vector4(100.0, 0.0, 0.0, 0.0)))
    mtl:SetShaderParameter("VOffset", Variant(math3d.Vector4(0.0, 100.0, 0.0, 0.0)))
    plane:SetMaterial(mtl)

    local lightNode = scene:CreateChild("DirectionalLight")
    lightNode.direction = math3d.Vector3(0.6, -1.0, 0.8) -- The direction vector does not need to be normalized
    local light = lightNode:CreateComponent(Light.id)
    light.light_type = LIGHT_DIRECTIONAL
    light.color = math3d.Color(0.5, 0.5, 0.5)
    light.cast_shadows = true
    light.shadow_bias = BiasParameters(DEFAULT_CONSTANTBIAS, DEFAULT_SLOPESCALEDBIAS)
    -- light.shadow_cascade = CascadeParameters(5.0, 12.0, 30.0, 100.0, DEFAULT_SHADOWFADESTART)
    light.shadow_cascade = CascadeParameters(33.0, 100.0, 233.0, 500.0, DEFAULT_SHADOWFADESTART)
    -- test
    -- local testNode = scene:CreateChild("TestBox")
    -- testNode.scale = math3d.Vector3(6.0, 6.0, 6.0)
    -- testNode.position = math3d.Vector3(0.0, 3.0, -4.0)
    -- local testrObject = testNode:CreateComponent(StaticModel.id)
    -- testrObject:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    -- testrObject:SetCastShadows(true)

    -- create ui
    FairyGUI.RegisterFont("default", "Fonts/FZY3JW.TTF")
    FairyGUI.SetDesignResolutionSize(1280, 720)
    FairyGUI.UIPackage.AddPackage("UI/VirtualList")
    local view = FairyGUI.UIPackage.CreateObject("VirtualList", "Main")
    local statistics = FairyGUI.CreateText("DC: TRI:")
    statistics:SetFontSize(24)
    local downloadtips = FairyGUI.CreateText("Get resources from server...0/0")
    downloadtips:SetColor(0, 200, 0)
    downloadtips:SetFontSize(40)
    downloadtips:SetVisible(false)
    local ui_scene = FairyGUI.FairyGUIScene()
    local groot = ui_scene.groot
    downloadtips:SetPosition((groot:GetWidth() - downloadtips:GetWidth()) * 0.5 - 50, (groot:GetHeight() - downloadtips:GetHeight()) * 0.5)
    groot:AddChild(statistics)
    groot:AddChild(downloadtips)
    groot:AddChild(view)
    local closeButton = FairyGUI.UIPackage.CreateObject("VirtualList", "CloseButton");
    if closeButton then
        closeButton:SetPosition((groot:GetWidth() - closeButton:GetWidth()) * 0.5, 10)
        closeButton:AddRelation(groot, FairyGUI.RelationType.Right_Right)
        closeButton:AddRelation(groot, FairyGUI.RelationType.Bottom_Bottom)
        closeButton:SetSortingOrder(100000)
        closeButton:AddClickListener(function()
            self:UnLoad()
        end)
        self.close_button = closeButton
    end

    view:GetChild("play"):AddClickListener(function (context)
        local list = self.ui_view:GetChild("mailList")
        local index = list:GetSelectedIndex()
        if index >= 0 then
            local gidx = index + 1
            self.game_index = gidx
            self.current_game_dir = self.gamelist[gidx].resource_dir
            self:LoadRequest(self.gamelist[gidx].id)
        end
    end)

    local node = scene:CreateChild("ClearCache")
    node.rotation = math3d.Quaternion(0, 45, 0)
    node.position = math3d.Vector3(0.0, 0.5, 0.0)
    local object = node:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    object:SetCastShadows(true)
    local textNode = node:CreateChild("ClearCache")
    textNode.rotation = math3d.Quaternion(0, -45, 0)
    textNode.position = math3d.Vector3(-2.2, 0.8, 0.0)
    local textObject = textNode:CreateComponent(Text3D.id)
    textObject:SetFont("Fonts/FZY3JW.TTF")
    textObject:SetText("ClearCache")
    textObject:SetColor(math3d.Color(0.5, 1.0, 0.5))
    textObject:SetOpacity(0.8)
    textObject:SetFontSize(64)

    FairyGUI.ReplaceScene(ui_scene)
    -- create camera
    local cameraNode = scene:CreateChild("Camera")
    cameraNode.position = math3d.Vector3(0.0, 10.0, -15.0)
    cameraNode:LookAt(math3d.Vector3(0.0, 0.0, 0.0))
    local camera = cameraNode:CreateComponent(Camera.id)
    camera.near_clip = 0.1
    camera.far_clip = 500

    -- setup viewport
    local viewport = Viewport(scene, camera)
    renderer_system:SetViewport(0, viewport)
    self.ui_view     = view
    self.scene       = scene
    self.camera_node = cameraNode
    self.camera      = camera
    self.viewport    = viewport
    self.statistics  = statistics
    self.downloadtips = downloadtips
    self.ui_scene    = ui_scene
    self.yaw         = cameraNode.rotation:YawAngle()
    self.pitch       = cameraNode.rotation:PitchAngle()
    if touchEnabled then
        input_system.CreateJoystick(math3d.IntVector2(512, 512), 1.0)
    end
end

function lobby:GetGameList()
    netlua:FetchFile("https://kfengine.com/Games/gamelist.json", function(gamelist) self:OnGameList(gamelist) end)
end

local function GetDownloadDir(platform)
    if platform == "Android" or platform == "Web" or platform == "iOS" then
        return filesystem:GetAppPreferencesDir("KFEngine", "KFPlayer") .. "Games"
    elseif platform == "Windows" then
        return filesystem:GetProgramDir() .. "Assets/Games"
    end
end

function lobby:Init()
    self.platform = GetPlatformName()
    if self.platform == "Android" or self.platform == "iOS" then
        touchEnabled = true
    end
    self:CreateScene()
    self.game_dir = GetDownloadDir(self.platform)
    self.userid = GetUserID()
    if self.userid > 0 then
        self.current_game_dir = self.game_dir.."/"..self.userid
        self:LoadRequest(self.userid, true)
    else
        self:GetGameList()
    end
end

return lobby