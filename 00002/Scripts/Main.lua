local app = {
    running = false,
    chat_list = {},
    yaw = 0,
    pitch = 0,
    MOVE_SPEED = 2,
}

function app:GetName()
    return "Demo"
end

function app:OnUpdate(eventType, eventData)
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    for _, item in ipairs(self.chat_list) do
        item.life = item.life + timeStep
        if item.life > 10.0 then
            item.display:SetVisible(false)
        end
    end
end

function app:OnSceneUpdate(eventType, eventData)
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    app:UpdateCamera(timeStep)
end

function app:OnPostUpdate(eventType, eventData)
end

function app:OnPostRenderUpdate(eventType, eventData)
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
        self.MOVE_SPEED = 1
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

local function CreatePBRScene(scene)
    local pipeline = scene:CreateComponent(RenderPipeline.id)
    pipeline:SetAttribute("Color Space", Variant(1))-- 0: GammaLDR, 1: LinearLDR 2: LinearHDR
    pipeline:SetAttribute("Specular Quality", Variant(2)) -- 0: Disabled 1: Simple, 2: Antialiased
    pipeline:SetAttribute("PCF Kernel Size", touchEnabled and Variant(1) or Variant(3))
    pipeline:SetAttribute("Bloom", Variant(true))
    pipeline:SetAttribute("Post Process Antialiasing", touchEnabled and Variant(0) or Variant(2)) -- 0: "None" 1: "FXAA2" 2: "FXAA3"
    pipeline:SetAttribute("VSM Shadow Settings", Variant(math3d.Vector2(0.00015, 0.0)))

    local zone = scene:CreateComponent(Zone.id)
    zone:SetEnabled(true)
    zone.bounding_box = math3d.BoundingBox(-1000.0, 1000.0)
    zone.ambient_color = math3d.Color(0.17273, 0.180021, 0.264286)
    zone.ambient_brightness = 0.0
    zone.background_brightness = 1.0
    zone.shadow_mask = -8
    zone.light_mask = -8
    zone:SetZoneTextureAttr("Textures/Skybox.xml")

    local skyNode = scene:CreateChild("Sky");
    skyNode.rotation = math3d.Quaternion(1.0, 0.0, 0.0, 0.0)
    local skybox = skyNode:CreateComponent(Skybox.id)
    skybox:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    skybox:SetMaterial(cache:GetResource("Material","Materials/Skybox.xml"))

    local lightNode = scene:CreateChild("DirectionalLight")
    --lightNode:SetDirection(Vector3(0.6f, -1.0f, 0.8f)); // The direction vector does not need to be normalized
    lightNode.rotation = math3d.Quaternion(-0.501596, -0.15565, -0.812743, 0.252205)
    local light = lightNode:CreateComponent(Light.id)
    light.light_type = LIGHT_DIRECTIONAL
    light.cast_shadows = true
    light.shadow_cascade = CascadeParameters(5.0, 12.0, 30.0, 100.0, DEFAULT_SHADOWFADESTART)
    --0.000030f
    light.shadow_bias = BiasParameters(DEFAULT_CONSTANTBIAS, DEFAULT_SLOPESCALEDBIAS)
    -- light.shadow_bias = BiasParameters(0.001, DEFAULT_SLOPESCALEDBIAS)
    light.light_mask = -8

    local create_pbr_node = function(name, mdl, mtl, pos, rot, scale)
        local node = scene:CreateChild(name)
        if scale then
            node.scale = scale
        end
        if rot then
            node.rotation = rot
        end
        if pos then
            node.position = pos
        end
        local object = node:CreateComponent(StaticModel.id)
        object:SetModel(cache:GetResource("Model", mdl))
        object:SetMaterial(cache:GetResource("Material", mtl))
        object:SetCastShadows(true)
        return object
    end
    local mtldir = "PBR"
    if GetPlatformName() == "iOS" then
        mtldir = "IOS"
    end
    create_pbr_node("Plane", "Models/Plane.mdl", "Materials/"..mtldir.."/Check.xml", math3d.Vector3(0.0, 0.0, 2.0), math3d.Quaternion(1.0, 0.0, 0.0, 0.0), math3d.Vector3(10.0, 5.0, 10.0))
    --
    local scale = math3d.Vector3(2.0, 2.0, 2.0)
    local rot = math3d.Quaternion(0.0, 0.0, 1.0, 0.0)
    local previewPath = "Models/MaterialPreview.mdl"
    local object = create_pbr_node("Mud", previewPath, "Materials/"..mtldir.."/Mud.xml", math3d.Vector3(0.0, 1.0, 3.0), rot, scale)
    object:SetMaterial(1, cache:GetResource("Material", "Materials/Constant/MetallicR7.xml"))
    object = create_pbr_node("Leather", previewPath, "Materials/"..mtldir.."/Leather.xml", math3d.Vector3(2.0, 1.0, 3.0), rot, scale)
    object:SetMaterial(1, cache:GetResource("Material", "Materials/Constant/MetallicR7.xml"))
    object = create_pbr_node("Sand", previewPath, "Materials/"..mtldir.."/Sand.xml", math3d.Vector3(4.0, 1.0, 3.0), rot, scale)
    object:SetMaterial(1, cache:GetResource("Material", "Materials/Constant/MetallicR7.xml"))
    object = create_pbr_node("Diamond Plate", previewPath, "Materials/"..mtldir.."/DiamonPlate.xml", math3d.Vector3(-2.0, 1.0, 3.0), rot, scale)
    object:SetMaterial(1, cache:GetResource("Material", "Materials/Constant/MetallicR7.xml"))
    object = create_pbr_node("Lead", previewPath, "Materials/"..mtldir.."/Lead.xml", math3d.Vector3(-4.0, 1.0, 3.0), rot, scale)
    object:SetMaterial(1, cache:GetResource("Material", "Materials/Constant/MetallicR7.xml"))
    --
    rot = math3d.Quaternion(0.961313, 0.0, 0.275453, 0.0)
    local spherePath = "Models/Sphere.mdl"
    -- Metallic
    create_pbr_node("Metallic R0", spherePath, "Materials/Constant/MetallicR0.xml", math3d.Vector3(-4.0, 0.5, 1.0), rot)
    create_pbr_node("Metallic R3", spherePath, "Materials/Constant/MetallicR3.xml", math3d.Vector3(-2.0, 0.5, 1.0), rot)
    create_pbr_node("Metallic R5", spherePath, "Materials/Constant/MetallicR5.xml", math3d.Vector3(0.0, 0.5, 1.0), rot)
    create_pbr_node("Metallic R7", spherePath, "Materials/Constant/MetallicR7.xml", math3d.Vector3(2.0, 0.5, 1.0), rot)
    create_pbr_node("Metallic R10", spherePath, "Materials/Constant/MetallicR10.xml", math3d.Vector3(4.0, 0.5, 1.0), rot)
    -- Dielectric
    create_pbr_node("Dielectric R0", spherePath, "Materials/Constant/DielectricR0.xml", math3d.Vector3(-4.0, 0.5, -1.0), rot)
    create_pbr_node("Dielectric R3", spherePath, "Materials/Constant/DielectricR3.xml", math3d.Vector3(-2.0, 0.5, -1.0), rot)
    create_pbr_node("Dielectric R5", spherePath, "Materials/Constant/DielectricR5.xml", math3d.Vector3(0.0, 0.5, -1.0), rot)
    create_pbr_node("Dielectric R7", spherePath, "Materials/Constant/DielectricR7.xml", math3d.Vector3(2.0, 0.5, -1.0), rot)
    create_pbr_node("Dielectric R10", spherePath, "Materials/Constant/DielectricR10.xml", math3d.Vector3(4.0, 0.5, -1.0), rot)
    --
    scale = math3d.Vector3(0.01, 0.01, 0.01)
    rot = math3d.Quaternion(-0.5, -0.5, -0.5, 0.5)
    object = create_pbr_node("Bike", "Models/HoverBike.mdl", "Materials/"..mtldir.."/HoverBikeGlass.xml", math3d.Vector3(0.0, 0.0, 5.0), rot, scale )
    object:SetMaterial(1, cache:GetResource("Material", "Materials/"..mtldir.."/HoverBikeHull.xml"))
end

function ShowMessage(msg)
    local chat_list = app.chat_list
    if #chat_list < 1 then
        for i=1,10,1 do
            local item = FairyGUI.CreateText("")
            item:SetFontSize(20)
            item:SetColor(204, 51, 0)
            app.ui_view:AddChild(item)
            chat_list[#chat_list + 1] = { display = item, life = 0.0 } 
        end
    end
    local item = table.remove(chat_list, #chat_list)
    item.display:SetText("Say: " .. msg)
    item.display:SetVisible(true)
    item.life = 0.0
    table.insert(chat_list, 1, item)
    for i=1,10,1 do
        chat_list[i].display:SetPosition(10, 660 - i * 24)
    end
end

function app:CreateScene(uiscene)
    local scene = Scene()
    scene:CreateComponent(Octree.id)

    --create scene
    CreatePBRScene(scene)

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

    -- create camera
    local cameraNode = scene:CreateChild("Camera")
    cameraNode.position = math3d.Vector3(-8.0, 3.0, 4.0)
    cameraNode:LookAt(math3d.Vector3(0.0, 0.0, 0.0))
    local camera = cameraNode:CreateComponent(Camera.id)
    camera.near_clip = 0.5
    camera.far_clip = 500.0
    

    -- setup viewport
    -- local viewport = Viewport(scene, camera)
    -- renderer_system:SetViewport(0, viewport)

    -- record some data, access in other place
    app.input       = view:GetChild("input")
    app.ui_view     = view
    app.uiscene     = uiscene
    app.scene       = scene
    app.camera_node = cameraNode
    app.camera      = camera
    app.viewport    = viewport
    --app.statistics  = statistics
    --app.ui_scene    = ui_scene
    app.yaw         = cameraNode.rotation:YawAngle()
    app.pitch       = cameraNode.rotation:PitchAngle()
end

function app:SetupViewport(viewport)
    viewport:SetScene(self.scene)
    local camera = self.camera_node:GetComponent(Camera.id)
    viewport:SetCamera(camera)
    
    if self.ui_view then
        self.uiscene.groot:AddChild(self.ui_view)
    end
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
end

function app:SubscribeToEvents()

end

function app:UnSubscribeToEvents()

end

return app