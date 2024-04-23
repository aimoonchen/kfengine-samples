local app = {
    running = false,
    yaw = -90,
    pitch = 30,
    MOVE_SPEED = 6.0,
}

function app:GetName()
    return "EmptyScene"
end

local idle_anim
local run_anim
local attack_anim
local function SpawnJack(pos, jackNode)
    local rotNode = jackNode:CreateChild("Model Rotation")
    local graphicNode = rotNode:CreateChild("Graphics")
    jackNode.position = pos
    local modelObject = graphicNode:CreateComponent(AnimatedModel.id)
    modelObject:SetModel(cache:GetResource("Model", "Models/Mutant/Mutant.mdl"))
    modelObject:SetMaterial(0, cache:GetResource("Material", "Models/Mutant/Materials/mutant_M.xml"))
    modelObject:SetCastShadows(true)
    local animController = graphicNode:CreateComponent(AnimationController.id)
    if not idle_anim then
        idle_anim = cache:GetResource("Animation", "Models/Mutant/Mutant_Idle0.ani")
        run_anim = cache:GetResource("Animation", "Models/Mutant/Mutant_Run.ani")
        attack_anim = cache:GetResource("Animation", "Models/Mutant/Mutant_Punch.ani")
    end
    animController:PlayNewExclusive(AnimationParameters(idle_anim):Looped())
    -- Create a CrowdAgent component and set its height and realistic max speed/acceleration. Use default radius
    local agent = jackNode:CreateComponent(CrowdAgent.id)
    agent.height = 1.0
    agent.radius = 0.2
    agent.max_accel = 30.0
end

local Navigables = {
    "Combined_Mesh__root__scene__5_51",
    "Combined_Mesh__root__scene__103",
    "Combined_Mesh__root__scene__5_26"
}
local Obstacle = {
    
}

local function Raycast(maxDistance)
    local pos
    if touchEnabled then
        local state = input_system:GetTouch(0)
        pos = state.position
    else
        pos = input_system:GetMousePosition()
    end 
    local cameraRay = app.camera:GetScreenRay(pos.x / graphics_system.width, pos.y / graphics_system.height)
    -- Pick only geometry objects, not eg. zones or lights, only get the first (closest) hit
    local octree = app.scene:GetComponent(Octree.id)
    local position, drawable = octree:RaycastSingle(cameraRay, graphic.RAY_TRIANGLE, maxDistance, graphic.DRAWABLE_GEOMETRY)
    if drawable then
        return position, drawable
    end
    return nil, nil
end

local function do_create_effect(filename, position)
    local emitter = app.scene:CreateChild("effect2")
    local effect = emitter:CreateComponent(EffekseerEmitter.id)
    effect:SetEffect(filename)
    effect:SetLooping(true)
    app.effects[#app.effects + 1] = effect
    emitter.position = position
    emitter.scale = math3d.Vector3(0.5, 0.5, 0.5)
    return emitter, effect
end

function app:CreateEffect()
    local emitter, effect = do_create_effect("Effekseer/01_Suzuki01/002_sword_effect/sword_effect.efk",  math3d.Vector3(9.0, 0.1, -8.0))
    emitter.scale = math3d.Vector3(0.2, 0.2, 0.2)
    -- effect:SetSpeed(2.0)
    effect:SetLooping(false)
    self.attack_emitter = emitter
    self.attack_effect = effect
    local _, efk1 = do_create_effect("Effekseer/01_Suzuki01/001_magma_effect/aura.efk",  math3d.Vector3(3.8, 0.9, 15.0))
    efk1:SetCullBoundingBox(math3d.BoundingBox(math3d.Vector3(-1.0, -1.0, -1.0), math3d.Vector3(1.0, 1.0, 1.0)))
    local _, efk2 = do_create_effect("Effekseer/01_Suzuki01/001_magma_effect/aura.efk",  math3d.Vector3(9.3, 1.1, 11.7))
    efk2:SetCullBoundingBox(math3d.BoundingBox(math3d.Vector3(-1.0, -1.0, -1.0), math3d.Vector3(1.0, 1.0, 1.0)))
    local emitter2, efk3 = do_create_effect("Effekseer/00_Version16/Aura01.efk",  math3d.Vector3(-19.0, 1.6, 15.0))
    efk3:SetCullBoundingBox(math3d.BoundingBox(math3d.Vector3(-2.0, 0.0, -2.0), math3d.Vector3(2.0, 4.0, 2.0)))
    emitter2.scale = math3d.Vector3(1.2, 1.2, 1.2)
    local _, efk4 = do_create_effect("Effekseer/00_Version16/Barrior01.efk",  math3d.Vector3(30, 0.0, 20.0))
    efk4:SetCullBoundingBox(math3d.BoundingBox(math3d.Vector3(-4.0, 0.0, -4.0), math3d.Vector3(4.0, 4.0, 4.0)))
end

local function reset_cd(mask)
    mask.cd = false
end

local function start_cd(mask)
    mask.time = 0.0
    mask.cd = true
    mask.left:SetValue(100)
end
function onAttackR(eventContext)
    app.action = true
    if app.mask_button.r.cd then return end
    start_cd(app.mask_button.r)
    app.speed = 3.0
    app.target_dist = 8.0
end

function onAttackE(eventContext)
    app.action = true
    if app.mask_button.e.cd then return end
    start_cd(app.mask_button.e)
end

function onAttackD(eventContext)
    app.action = true
    if app.mask_button.d.cd then return end
    start_cd(app.mask_button.d)
end

local function update_mask(timeStep)
    for _, mask in pairs(app.mask_button) do
        if mask.cd then
            mask.time = mask.time + timeStep
            local cd_value = mask.time / mask.cdtime
            mask.left:SetValue((1 - cd_value) * 100)
            if cd_value >= 1.0 then
                reset_cd(mask)
            end
        end
    end
end

local function onAttackBtn(eventContext)
    app.action = true
    if app.attack then return end
    app.attack = true
    app.anim_ctrl:Stop(idle_anim, app.fadetime)
    app.anim_ctrl:PlayExisting(AnimationParameters(attack_anim))
    local character = app.anim_ctrl:GetNode()
    app.attack_emitter.rotation = character.world_rotation
    app.attack_emitter:Rotate(math3d.Quaternion(90.0, 180.0, 0.0))
    local pos = character.world_position + character.world_direction * -1.0
    pos.y = pos.y + 0.7
    app.attack_emitter.world_position = pos
    app.attack_effect:Play()
    app.sound_attack:Start()
end

function app:OnUpdate(eventType, eventData)
    -- Take the frame time step, which is stored as a float
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    update_mask(timeStep)
    -- local click = false
    -- if touchEnabled and input_system:GetTouch(0) then
    --     click = true
    -- else
    --     click = input_system:GetMouseButtonPress(input.MOUSEB_RIGHT)
    -- end
    -- if click then
    --     app.outline_group:ClearDrawables()
    --     local pos, drawable = Raycast(300)
    --     if drawable and drawable:GetNode().name ~= "Combined_Mesh__root__scene__5_51" then
    --         app.outline_group:AddDrawable(drawable)
    --     end
    -- end

    if input_system:GetMouseButtonDown(input.MOUSEB_RIGHT) then
        onAttackBtn()
    end

    local rotationNode = self.anim_ctrl:GetNode():GetParent()
    local controlDirection = math3d.Vector3(0.0, 0.0, 0.0)
    if input_system.IsJoystickCapture() then
        controlDirection = math3d.Quaternion(0.0, input_system.GetJoystickDegree() - 90, 0.0) * math3d.Vector3.FORWARD
    else
        if touchEnabled then
            for i=0, input_system:GetNumTouches()-1 do
                if input_system.GetJoystickTouchID() ~= i then
                    local state = input_system:GetTouch(i)
                    --if not state.touchedElement then -- Touch on empty space
                        if state.delta.x ~= 0 or state.delta.y ~= 0 then
                            local camera = self.camera_node:GetComponent(Camera.id)
                            if camera then
                                self.yaw = math3d.ModF(self.yaw + TOUCH_SENSITIVITY * camera.fov / graphics_system.height * state.delta.x, 360.0)
                                self.pitch = math3d.ClampF(self.pitch + TOUCH_SENSITIVITY * camera.fov / graphics_system.height * state.delta.y, -89.0, 89.0)
                            end
                        end
                    --end
                    break
                end
            end
        else
            if input_system:GetMouseButtonDown(input.MOUSEB_LEFT) and not FairyGUI.IsFocusUI() then
                local rotationSensitivity = 0.1
                local mouseMove = input_system:GetMouseMove()
                self.yaw = math3d.ModF(self.yaw + mouseMove.x * rotationSensitivity, 360.0)
                self.pitch = math3d.ClampF(self.pitch + mouseMove.y * rotationSensitivity, -89.0, 89.0)
            end
            if not FairyGUI.IsInputing() then
                if input_system:GetKeyDown(input.KEY_W) then
                    controlDirection = controlDirection + math3d.Vector3.BACK
                end
                if input_system:GetKeyDown(input.KEY_S) then
                    controlDirection = controlDirection + math3d.Vector3.FORWARD
                end
                if input_system:GetKeyDown(input.KEY_A) then
                    controlDirection = controlDirection + math3d.Vector3.RIGHT
                end
                if input_system:GetKeyDown(input.KEY_D) then
                    controlDirection = controlDirection + math3d.Vector3.LEFT
                end
            end
        end
    end
    local cameraRotationPitch = self.camera_node:GetParent();
    local cameraRotationYaw = cameraRotationPitch:GetParent();
    cameraRotationPitch.rotation = math3d.Quaternion(self.pitch, 0.0, 0.0)
    cameraRotationYaw.rotation = math3d.Quaternion(0.0, self.yaw, 0.0)
    local rotation = cameraRotationYaw.world_rotation
    local movementDirection = rotation * controlDirection
    local speed = input_system:GetKeyDown(input.KEY_SHIFT) and -5.0 or -3.0

    local agent = self.agent
    agent:SetTargetVelocity(movementDirection * speed)

    local actualVelocityFlat = agent:GetActualVelocity() * math3d.Vector3(-1.0, 0.0, -1.0)
    if actualVelocityFlat:Length() > math3d.M_LARGE_EPSILON then
        rotationNode.world_direction = actualVelocityFlat
        self.anim_ctrl:PlayExistingExclusive(AnimationParameters(run_anim):Looped():Speed(actualVelocityFlat:Length() * 0.3), 0.2)

        local wp = rotationNode.world_position
        local ray = math3d.Ray(math3d.Vector3(wp.x, 100.0, wp.z), math3d.Vector3(0.0, -1.0, 0.0))
        local hit, position = self.ground[1]:RaycastSingle(ray)
        if not hit and ray:HitDistance(self.ground[1]:GetWorldBoundingBox()) > 200 then
            hit, position = self.ground[2]:RaycastSingle(ray)
            if not hit then
                hit, position = self.ground[#self.ground]:RaycastSingle(ray)
            end
        end
        if hit then
            rotationNode.world_position = position
        end
    else
        if self.attack then
            local ap = self.anim_ctrl:GetLastAnimationParameters(attack_anim)
            if not ap then
                self.anim_ctrl:Stop(attack_anim)
                self.anim_ctrl:PlayExisting(AnimationParameters(idle_anim):Looped())
                self.attack = false
            end
        else
            self.anim_ctrl:PlayExistingExclusive(AnimationParameters(idle_anim):Looped(), 0.2)
        end
    end

    local agentNode = self.agent:GetNode()
    agentNode.world_position = agent:GetPosition() * math3d.Vector3(1.0, 0.0, 1.0)
    if input_system:GetKeyPress(input.KEY_TAB) then
        local animModel = self.anim_ctrl:GetNode():GetComponent(AnimatedModel.id)
        self.textures_enabled = not self.textures_enabled
        if self.textures_enabled then
            animModel:SetMaterial(cache:GetResource("Material", "Models/Mutant/Materials/mutant_M.xml"))
        else
            animModel:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"))
        end
    end
end

function app:OnSceneUpdate(eventType, eventData)
    -- local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    -- app:UpdateCamera(timeStep)
end

function app:OnPostUpdate(eventType, eventData)
end

function app:OnPostRenderUpdate(eventType, eventData)
    -- self.scene:GetComponent(DynamicNavigationMesh.id):DrawDebugGeometry(true)
end

function app:UpdateCamera(timeStep)

end

function app:CreateScene(uiscene)
    --create scene
    local scene = Scene()
    -- scene:CreateComponent(Octree.id)

    scene:LoadXML(cache:GetResource("XMLFile", "Scenes/scene_01.xml"))

    local pipeline = scene:CreateComponent(RenderPipeline.id)
    pipeline:SetAttribute("Color Space", Variant(0))-- 0: GammaLDR, 1: LinearLDR 2: LinearHDR
    -- pipeline:SetAttribute("Specular Quality", Variant(2)) -- 0: Disabled 1: Simple, 2: Antialiased
    pipeline:SetAttribute("PCF Kernel Size", touchEnabled and Variant(1) or Variant(3))
    -- pipeline:SetAttribute("Bloom", Variant(true))
    pipeline:SetAttribute("Post Process Antialiasing", touchEnabled and Variant(0) or Variant(2)) -- 0: "None" 1: "FXAA2" 2: "FXAA3"
    pipeline:SetAttribute("VSM Shadow Settings", Variant(math3d.Vector2(0.00015, 0.0)))

    self.outline_group = scene:CreateComponent(OutlineGroup.id)
    self.outline_group:SetColor(math3d.Color(0.0,0.7,0.0,1.0))

    local skyNode = scene:CreateChild("Sky")
    skyNode:SetScale(500.0) -- The scale actually does not matter
    local skybox = skyNode:CreateComponent(Skybox.id)
    skybox.model = cache:GetResource("Model", "Models/Box.mdl")
    skybox.material = cache:GetResource("Material", "Materials/Sky.xml")

    -- Create a DynamicNavigationMesh component to the scene root
    local navMesh = scene:CreateComponent(DynamicNavigationMesh.id)
    -- Set small tiles to show navigation mesh streaming
    navMesh:SetTileSize(32)
    -- navMesh:SetTileSize(16)
    -- Enable drawing debug geometry for obstacles and off-mesh connections
    navMesh:SetDrawObstacles(true)
    navMesh:SetDrawOffMeshConnections(true)
    -- Set the agent height large enough to exclude the layers under boxes
    navMesh:SetAgentHeight(10.0)
    -- Set nav mesh cell height to minimum (allows agents to be grounded)
    navMesh:SetCellHeight(0.05)
    -- Create a Navigable component to the scene root. This tags all of the geometry in the scene as being part of the
    -- navigation mesh. By default this is recursive, but the recursion could be turned off from Navigable
    --scene:CreateComponent(Navigable.id)
    for _, navigable in ipairs(Navigables) do
        scene:GetChild(navigable):CreateComponent(Navigable.id)
    end
    -- Add padding to the navigation mesh in Y-direction so that we can add objects on top of the tallest boxes
    -- in the scene and still update the mesh correctly
    navMesh:SetPadding(math3d.Vector3(0.0, 10.0, 0.0))
    -- Now build the navigation geometry. This will take some time. Note that the navigation mesh will prefer to use
    -- physics geometry from the scene nodes, as it often is simpler, but if it can not find any (like in this example)
    -- it will use renderable geometry instead
    navMesh:Build()

    -- Create a CrowdManager component to the scene root
    local crowdManager = scene:CreateComponent(CrowdManager.id)
    local params = crowdManager:GetObstacleAvoidanceParams(0)
    -- Set the params to "High (66)" setting
    params.velBias = 0.5
    params.adaptiveDivs = 7
    params.adaptiveRings = 3
    params.adaptiveDepth = 3
    crowdManager:SetObstacleAvoidanceParams(0, params)
    
    SpawnJack(math3d.Vector3(0.0, 0.0, 25.0), scene:CreateChild("Actor"))

    local agent = scene:GetComponent(CrowdAgent.id, true)
    agent:SetUpdateNodePosition(false)

    local zoneNode = scene:GetChild("Zone")
    local zone = zoneNode:GetComponent(Zone.id)
    -- zone.ambient_color = math3d.Color(0.7, 0.7, 0.8)
    zone.ambient_color = math3d.Color(0.4, 0.4, 0.4)

    local lightNode = scene:GetChild("GlobalLight")
    lightNode.direction = math3d.Vector3(0.0, -1.0, -1.0)
    local light = lightNode:GetComponent(Light.id)
    -- light.color = math3d.Color(0.7, 0.7, 0.8)
    light.color = math3d.Color(0.6, 0.6, 0.6)
    light.cast_shadows = true
    light.shadow_bias = BiasParameters(DEFAULT_CONSTANTBIAS, DEFAULT_SLOPESCALEDBIAS)
    light.shadow_cascade = CascadeParameters(5.0, 12.0, 30.0, 100.0, DEFAULT_SHADOWFADESTART)

    -- local zone = scene:CreateComponent(Zone.id)
    -- zone:SetEnabled(true)
    -- zone.bounding_box = math3d.BoundingBox(-1000.0, 1000.0)
    -- zone.ambient_color = math3d.Color(0.4, 0.4, 0.4)
    -- zone.ambient_brightness = 1.0
    -- zone.fog_color = math3d.Color(0.5, 0.5, 0.7)
    -- zone.fog_start = 100.0
    -- zone.fog_end = 300.0

    -- local lightNode = scene:CreateChild("DirectionalLight")
    -- lightNode.direction = math3d.Vector3(0.6, -1.0, 0.8) -- The direction vector does not need to be normalized
    -- local light = lightNode:CreateComponent(Light.id)
    -- light.light_type = LIGHT_DIRECTIONAL
    -- light.color = math3d.Color(0.6, 0.6, 0.6)
    
    -- local planeNode = scene:CreateChild("Plane");
    -- planeNode.scale = math3d.Vector3(100.0, 1.0, 100.0)
    -- local planeObject = planeNode:CreateComponent(StaticModel.id)
    -- planeObject:SetModel(cache:GetResource("Model", "Models/Plane.mdl"))
    -- local mtl = cache:GetResource("Material", "Materials/GridTiled.xml")
    -- --UVTransform: offset, rotation, repeat
    -- mtl:SetUVTransform(math3d.Vector2.ZERO, 0.0, math3d.Vector2(100.0, 100.0))
    -- -- mtl:SetShaderParameter("UOffset", Variant(math3d.Vector4(100.0, 0.0, 0.0, 0.0)))
    -- -- mtl:SetShaderParameter("VOffset", Variant(math3d.Vector4(0.0, 100.0, 0.0, 0.0)))
    -- planeObject:SetMaterial(mtl)

    -- CreateTower(scene)
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
    -- action
    self.action = false
    self.attack = false
    self.mask_button = {
        d = {
            cdtime = 5.0,
            cd = false,
            time = 0.0
        },
        e = {
            cdtime = 8.0,
            cd = false,
            time = 0.0
        },
        r = {
            cdtime = 10.0,
            cd = false,
            time = 0.0
        }
    }
    local r = self.mask_button.r
    r.left = view:GetChild("r_cd")
    r.left:SetTouchable(true)
    r.left:SetVisible(true)
    r.left:AddEventListener(FairyGUI.EventType.TouchBegin, onAttackR)

    local e = self.mask_button.e
    e.left = view:GetChild("e_cd")
    e.left:SetTouchable(true)
    e.left:SetVisible(true)
    e.left:AddEventListener(FairyGUI.EventType.TouchBegin, onAttackE)

    local d = self.mask_button.d
    d.left = view:GetChild("d_cd")
    d.left:SetTouchable(true)
    d.left:SetVisible(true)
    d.left:AddEventListener(FairyGUI.EventType.TouchBegin, onAttackD)

    self.attack_button = view:GetChild("attack")
    self.attack_button:SetVisible(true)
    self.attack_button:AddEventListener(FairyGUI.EventType.TouchBegin, onAttackBtn)

    -- create camera
    local cryNode = scene:GetChild("Actor", true):CreateChild("Camera Rotation Yaw")
    cryNode.rotation = math3d.Quaternion(0.0, self.yaw, 0.0)
    local crpNode = cryNode:CreateChild("Camera Rotation Pitch")
    crpNode.position = math3d.Vector3(0.0, 1.1, 0)
    crpNode.rotation = math3d.Quaternion(self.pitch, 0.0, 0.0)
    local cameraNode = crpNode:CreateChild("Camera")
    cameraNode.position = math3d.Vector3(0.0, 0.0, -10.0)
    local camera = cameraNode:CreateComponent(Camera.id)
    

    local cameraRotationPitch = cameraNode:GetParent()
    local cameraRotationYaw = cameraRotationPitch:GetParent()
    self.ui_view    = view
    self.uiscene     = uiscene
    self.scene       = scene
    self.camera_node = cameraNode
    self.camera      = camera
    self.agent       = agent
    self.ground     = {
        scene:GetChild("Combined_Mesh__root__scene__5_26", true):GetComponent(StaticModel.id),
        scene:GetChild("Combined_Mesh__root__scene__103", true):GetComponent(StaticModel.id),
        scene:GetChild("Combined_Mesh__root__scene__5_51", true):GetComponent(StaticModel.id)
    }
    self.fadetime = 0.3
    self.effects = {}
    local agentNode = agent:GetNode()
    local anim_ctrl = agentNode:GetComponent(AnimationController.id, true)
    self.anim_ctrl = anim_ctrl

    local rotationNode = anim_ctrl:GetNode():GetParent()
    local wp = rotationNode.world_position
    local ray = math3d.Ray(math3d.Vector3(wp.x, 100.0, wp.z), math3d.Vector3(0.0, -1.0, 0.0))
    local hit, position = self.ground[#self.ground]:RaycastSingle(ray)
    if hit then
        rotationNode.world_position = position
    end

    self:CreateEffect()
    local bankname = "Sounds/Master.bank"
    local ret = Audio.LoadBank(bankname)
    if not ret then
        print("LoadBank Faied. :", bankname)
    end
    local bankname = "Sounds/Master.strings.bank"
    ret = Audio.LoadBank(bankname)
    if not ret then
        print("LoadBank Faied. :", bankname)
    end
    self.sound_attack = Audio.CreateEvent("event:/Scene/attack")
end

function app:Load(viewport, uiscene)
    if self.running then
        return
    end
    self.running = true
    if not self.scene then
        self:CreateScene(uiscene)
    end
    viewport:SetScene(self.scene)
    local camera = self.camera_node:GetComponent(Camera.id)
    viewport:SetCamera(camera)
    Effekseer.SetCamera(camera)
    
    if self.ui_view then
        self.uiscene.groot:AddChild(self.ui_view)
    end
    self:SubscribeToEvents()
    for _, e in ipairs(self.effects) do
        e:Play()
    end
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
    for _, e in ipairs(self.effects) do
        e:Stop()
    end
end

function app:SubscribeToEvents()

end

function app:UnSubscribeToEvents()

end

return app