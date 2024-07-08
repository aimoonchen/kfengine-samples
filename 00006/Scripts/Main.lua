local app = {
    yaw = 0,
    pitch = 0,
    running = false,
    MOVE_SPEED = 4.0,
}

function app:CreateScene(uiscene)
    local scene = Scene()

    -- Create octree, use default volume (-1000, -1000, -1000) to (1000, 1000, 1000)
    scene:CreateComponent(Octree.id)

    -- Create a Zone component for ambient lighting & fog control
    local zoneNode = scene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent(Zone.id)
    zone.bounding_box = math3d.BoundingBox(-1000.0, 1000.0)
    zone.ambient_color = math3d.Color(0.15, 0.15, 0.15)
    zone.fog_color = math3d.Color(1.0, 1.0, 1.0)
    zone.fog_start = 500.0
    zone.fog_end = 750.0

    -- Create a directional light to the world. Enable cascaded shadows on it
    local lightNode = scene:CreateChild("DirectionalLight")
    lightNode.direction = math3d.Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent(Light.id)
    light.light_type = LIGHT_DIRECTIONAL
    light.cast_shadows = true
    light.shadow_bias = BiasParameters(0.00025, 0.5)
    light.shadow_cascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)
    light.specular_intensity = 0.5
    -- Apply slightly overbright lighting to match the skybox
    light.color = math3d.Color(1.2, 1.2, 1.2)

    -- Create skybox. The Skybox component is used like StaticModel, but it will be always located at the camera, giving the
    -- illusion of the box planes being far away. Use just the ordinary Box model and a suitable material, whose shader will
    -- generate the necessary 3D texture coordinates for cube mapping
    local skyNode = scene:CreateChild("Sky")
    skyNode:SetScale(500.0) -- The scale actually does not matter
    local skybox = skyNode:CreateComponent(Skybox.id)
    skybox.model = cache:GetResource("Model", "Models/Box.mdl")
    skybox.material = cache:GetResource("Material", "Materials/Skybox.xml")

    -- Create heightmap terrain
    local terrainNode = scene:CreateChild("Terrain")
    terrainNode.position = math3d.Vector3(0.0, 0.0, 0.0)
    local terrain = terrainNode:CreateComponent(Terrain.id)
    terrain.patch_size = 64
    terrain.spacing = math3d.Vector3(2.0, 0.5, 2.0) -- Spacing between vertices and vertical resolution of the height map
    terrain.smoothing = true
    terrain.height_map = cache:GetResource("Image", "Textures/HeightMap.png")
    terrain.material = cache:GetResource("Material", "Materials/Terrain.xml")
    -- The terrain consists of large triangles, which fits well for occlusion rendering, as a hill can occlude all
    -- terrain patches and other objects behind it
    terrain.occluder = true

    -- Create 1000 boxes in the terrain. Always face outward along the terrain normal
    local NUM_OBJECTS = 1000
    for i = 1, NUM_OBJECTS do
        local objectNode = scene:CreateChild("Box")
        local position = math3d.Vector3(math3d.Random(2000.0) - 1000.0, 0.0, math3d.Random(2000.0) - 1000.0)
        position.y = terrain:GetHeight(position) + 2.25
        objectNode.position = position
        -- Create a rotation quaternion from up vector to terrain normal
        objectNode.rotation = math3d.Quaternion(math3d.Vector3(0.0, 1.0, 0.0), terrain:GetNormal(position))
        objectNode:SetScale(5.0)
        local object = objectNode:CreateComponent(StaticModel.id)
        object.model = cache:GetResource("Model", "Models/Box.mdl")
        object.material = cache:GetResource("Material", "Materials/Stone.xml")
        object.cast_shadows = true
    end

    -- Create a water plane object that is as large as the terrain
    local waterNode = scene:CreateChild("Water")
    waterNode.scale = math3d.Vector3(2048.0, 1.0, 2048.0)
    waterNode.position = math3d.Vector3(0.0, 5.0, 0.0)
    local water = waterNode:CreateComponent(StaticModel.id)
    
    water.model = cache:GetResource("Model", "Models/Plane.mdl")
    local waterMaterial = cache:GetResource("Material", "Materials/Showcase/LitWaterTiled.xml")--:Clone()
    water.material = waterMaterial
    -- Set a different viewmask on the water plane to be able to hide it from the reflection camera
    water.view_mask = 0x80000000
    
    -- create ui
    FairyGUI.UIPackage.AddPackage("UI/Joystick")
    local view = FairyGUI.UIPackage.CreateObject("Joystick", "Main")
    view:GetChild("r_cd"):SetVisible(false)
    view:GetChild("e_cd"):SetVisible(false)
    view:GetChild("d_cd"):SetVisible(false)
    view:GetChild("attack"):SetVisible(false)
    view:GetChild("button_back"):SetVisible(false)
    view:GetChild("button_forward"):SetVisible(false)
    view:GetChild("joystick"):SetVisible(false)
    view:GetChild("joystick_touch"):SetVisible(false)
    view:GetChild("joystick_center"):SetVisible(false)
    --FairyGUI.CreateJoystick(view)

    -- Create the camera. Set far clip to match the fog. Note: now we actually create the camera node outside
    -- the scene, because we want it to be unaffected by scene load / save
    local cameraNode = Node()
    local camera = cameraNode:CreateComponent(Camera.id)
    camera.near_clip = 0.5
    camera.far_clip = 750.0
    -- Set an initial position for the camera scene node above the floor
    cameraNode.position = math3d.Vector3(0.0, 15.0, -20.0)

    self.scene = scene
    self.camera_node = cameraNode
    self.water_node = waterNode
    self.water_material = waterMaterial
    FairyGUI.SetDesignResolutionSize(1280, 720)
    self.ui_view = view
    self.uiscene = uiscene
end

function app:Load(viewport, uiscene)
    if self.running then
        return
    end
    self.running = true
    if not self.scene then
        self:CreateScene(uiscene)
    end
    self:SetupViewport(viewport)
    self:SubscribeToEvents()
end

function app:UnLoad()
    if not self.running then
        return
    end
    self.running = false
    if self.ui_view then
        self.uiscene.groot:RemoveChild(self.ui_view)
    end
    self:UnSubscribeToEvents()
    self.surface:SetViewport(0, nil)
end

function app:GetName()
    return "Terrain and Water"
end

function app:SetupViewport(viewport)
    if not self.surface then
        -- Set up a viewport to the Renderer subsystem so that the 3D scene can be seen
        --self.viewport = Viewport(self.scene, self.camera_node:GetComponent("Camera"))

        local waterNode = self.water_node
        -- Create a mathematical plane to represent the water in calculations
        local waterPlane = math3d.Plane(waterNode.world_rotation * math3d.Vector3(0.0, 1.0, 0.0), waterNode.world_position)
        -- Create a downward biased plane for reflection view clipping. Biasing is necessary to avoid too aggressive clipping
        local waterClipPlane = math3d.Plane(waterNode.world_rotation * math3d.Vector3(0.0, 1.0, 0.0), waterNode.world_position -
            math3d.Vector3(0.0, 0.1, 0.0))

        -- Create camera for water reflection
        -- It will have the same farclip and position as the main viewport camera, but uses a reflection plane to modify
        -- its position when rendering
        local reflectionCameraNode = self.camera_node:CreateChild("")
        local reflectionCamera = reflectionCameraNode:CreateComponent(Camera.id)
        reflectionCamera.near_clip = 0.5
        reflectionCamera.far_clip = 750.0
        reflectionCamera.view_mask = 0x7fffffff -- Hide objects with only bit 31 in the viewmask (the water plane)
        reflectionCamera.auto_aspect_ratio = false
        reflectionCamera.use_reflection = true
        reflectionCamera.reflection_plane = waterPlane
        reflectionCamera.use_clipping = true -- Enable clipping of geometry behind water plane
        reflectionCamera.clip_plane = waterClipPlane
        -- The water reflection texture is rectangular. Set reflection camera aspect ratio to match
        reflectionCamera.aspect_ratio = graphics_system.width / graphics_system.height
        -- View override flags could be used to optimize reflection rendering. For example disable shadows
        --reflectionCamera.viewOverrideFlags = VO_DISABLE_SHADOWS

        -- Create a texture and setup viewport for water reflection. Assign the reflection texture to the diffuse
        -- texture unit of the water material
        local texSize = 1024
        local renderTexture = Texture2D()
        renderTexture:SetSize(texSize, texSize, graphic.TextureFormat.TEX_FORMAT_RGBA8_UNORM, graphic.TextureFlag.BindRenderTarget)
        renderTexture.filter_mode = graphic.FILTER_BILINEAR
        self.reflection_camera = reflectionCamera
        self.render_texture = renderTexture
        self.surface = renderTexture:GetRenderSurface(0)
        self.water_material:SetTexture(graphic.ShaderResources.Reflection0, renderTexture)
        --self.rtt_viewport = Viewport(self.scene, reflectionCamera)
        self.surface:SetViewport(0, self.rtt_viewport)
    end

    -- renderer_system:SetViewport(0, self.viewport)
    viewport:SetScene(self.scene)
    local mainCamera = self.camera_node:GetComponent(Camera.id)
    viewport:SetCamera(mainCamera)
    self.surface:SetViewport(0, Viewport(self.scene, self.reflection_camera))
    if self.ui_view then
        self.uiscene.groot:AddChild(self.ui_view)
    end
end

function app:SubscribeToEvents()
end

function app:UnSubscribeToEvents()
end

function app:OnUpdate(eventType, eventData)
    -- Take the frame time step, which is stored as a float
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
end

function app:UpdateCamera(timeStep)
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
        controlDirection:Normalize()
        self.MOVE_SPEED = 3.0
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

function app:OnSceneUpdate(eventType, eventData)
    -- Take the frame time step, which is stored as a float
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()

    local distortionBias = 0.01;
    local distortionStrength = 0.1;
    local planeNormal = math3d.Vector3.UP;
    local planeRight = self.camera_node.world_right
    local planeForward = planeRight:CrossProduct(planeNormal):Normalized();
    self.water_material:SetShaderParameter("ReflectionPlaneX", Variant(math3d.Vector4(planeRight * distortionStrength, 0.0)));
    self.water_material:SetShaderParameter("ReflectionPlaneY", Variant(math3d.Vector4(planeForward * distortionStrength, distortionBias)));

    -- In case resolution has changed, adjust the reflection camera aspect ratio
    self.reflection_camera.aspect_ratio = graphics_system.width / graphics_system.height

    self:UpdateCamera(timeStep)
end

function app:OnPostUpdate(eventType, eventData)
end

function app:OnPostRenderUpdate(eventType, eventData)
end

return app