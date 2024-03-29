local app = {
    running = false,
    chat_list = {},
    yaw = 0,
    pitch = 30,
    MOVE_SPEED = 6.0,
    character = {}
}

function app:GetName()
    return "Template"
end

local idle_anim
local run_anim
local attack_anim
local function SpawnCharacter(parent, name, pos, init_anim)
    local jackNode = parent:CreateChild("Actor")
    local rotNode = jackNode:CreateChild("Model Rotation")
    local graphicNode = rotNode:CreateChild("Graphics")
    jackNode.position = pos or math3d.Vector3(0.0, 0.0, 0.0)
    graphicNode.scale = math3d.Vector3(0.005, 0.005, 0.005)
    local modelObject = graphicNode:CreateComponent(AnimatedModel.id)
    modelObject:SetModel(cache:GetResource("Model", "Models/Blockman/Models/blockman.mdl"))
    modelObject:SetMaterial(cache:GetResource("Material", "Models/Blockman/Materials/Default.xml"))
    modelObject:SetCastShadows(true)
    local animController = graphicNode:CreateComponent(AnimationController.id)
    if not idle_anim then
        idle_anim = cache:GetResource("Animation", "Models/Blockman/Animations/Idle.ani")
        run_anim = cache:GetResource("Animation", "Models/Blockman/Animations/StandardRun.ani")
        attack_anim = cache:GetResource("Animation", "Models/Blockman/Animations/Punching.ani")
    end
    animController:PlayNewExclusive(AnimationParameters(idle_anim):Looped())
    -- Create a CrowdAgent component and set its height and realistic max speed/acceleration. Use default radius
    local agent = jackNode:CreateComponent(CrowdAgent.id)
    agent.height = 1.0
    agent.radius = 0.2
    agent.max_accel = 30.0
    local uiName = FairyGUI.CreateText(name, math3d.Color(1.0, 1.0, 0.0))
    app.ui_view:AddChild(uiName)
    uiName:SetFontSize(24)
    uiName:SetPivot(0.5, 0.5, true)
    app.actor_name = uiName
end

local function onAttackBtn(eventContext)
    app.action = true
    if app.attack then return end
    app.attack = true
    app.anim_ctrl:Stop(idle_anim, app.fadetime)
    app.anim_ctrl:PlayExisting(AnimationParameters(attack_anim), app.fadetime)
    local character = app.anim_ctrl:GetNode()
    app.attack_emitter.rotation = character.world_rotation
    app.attack_emitter:Rotate(math3d.Quaternion(90.0, 180.0, 0.0))
    local pos = character.world_position + character.world_direction * -1.0
    pos.y = pos.y + 1.5
    app.attack_emitter.world_position = pos
    app.attack_effect:Play()
    app.sound_attack:Start()
end

local function Raycast(maxDistance)
    local pos
    if touchEnabled then
        local state = input_system:GetTouch(0)
        pos = state.position
    else
        pos = input_system:GetMousePosition()
    end 
    -- if click on ui return nil,nil
    --
    local cameraRay = app.camera:GetScreenRay(pos.x / graphics_system.width, pos.y / graphics_system.height)
    -- Pick only geometry objects, not eg. zones or lights, only get the first (closest) hit
    local octree = app.scene:GetComponent(Octree.id)
    local position, drawable = octree:RaycastSingle(cameraRay, graphic.RAY_TRIANGLE, maxDistance, graphic.DRAWABLE_GEOMETRY)
    if drawable then
        return position, drawable
    end

    return nil, nil
end

function app:OnUpdate(eventType, eventData)
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    for _, item in ipairs(self.chat_list) do
        item.life = item.life + timeStep
        if item.life > 10.0 then
            item.display:SetVisible(false)
        end
    end
    
    local click = false
    if touchEnabled and input_system:GetTouch(0) then
        click = true
    else
        click = input_system:GetMouseButtonPress(input.MOUSEB_LEFT)
    end
    if click then
        app.outline_group:ClearDrawables()
        local pos, drawable = Raycast(300)
        if drawable and drawable:GetNode().name ~= "Ground Plane" then
            app.outline_group:AddDrawable(drawable)
        end
    end

    if input_system:GetMouseButtonDown(input.MOUSEB_RIGHT) then
        onAttackBtn()
    end

    local rotationNode = self.anim_ctrl:GetNode():GetParent()
    local controlDirection = math3d.Vector3.ZERO
    if input_system.IsJoystickCapture() then
        controlDirection = math3d.Quaternion(0.0, FairyGUI.GetJoystickRotation() + 180, 0.0) * math3d.Vector3.FORWARD
    else
        if GetPlatformName() == "Android" or GetPlatformName() == "iOS" then
            for i=0, input_system:GetNumTouches()-1 do
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
    local speed = -3.0--input_system:GetKeyDown(input.KEY_SHIFT) and -5.0 or -3.0
    local agent = self.agent
    agent:SetTargetVelocity(movementDirection * speed)

    local actualVelocityFlat = agent:GetActualVelocity() * math3d.Vector3(-1.0, 0.0, -1.0)
    if actualVelocityFlat:Length() > math3d.M_LARGE_EPSILON then
        rotationNode.world_direction = actualVelocityFlat
        self.anim_ctrl:PlayExistingExclusive(AnimationParameters(run_anim):Looped():Speed(actualVelocityFlat:Length() * 0.3), self.fadetime)

        local wp = rotationNode.world_position
        local ray = math3d.Ray(math3d.Vector3(wp.x, 100.0, wp.z), math3d.Vector3(0.0, -1.0, 0.0))
        local hit, position = self.ground:RaycastSingle(ray)
        if hit then
            rotationNode.world_position = position
        end
    else
        if self.attack then
            local ap = self.anim_ctrl:GetLastAnimationParameters(attack_anim)
            if not ap then
                self.anim_ctrl:Stop(attack_anim, self.fadetime)
                self.anim_ctrl:PlayExisting(AnimationParameters(idle_anim):Looped(), self.fadetime)
                self.attack = false
            end
        else
            self.anim_ctrl:PlayExistingExclusive(AnimationParameters(idle_anim):Looped(), self.fadetime)
        end
    end

    local agentNode = agent:GetNode()
    agentNode.world_position = agent:GetPosition() * math3d.Vector3(1.0, 0.0, 1.0)
    -- Update ui name
    local pos = agentNode.world_position
    local sp = self.camera:WorldToScreenPoint(math3d.Vector3(pos.x, pos.y + 2.9, pos.z))
    -- self.actor_name:SetPosition(graphics_system.width * sp.x, graphics_system.height * sp.y)
    -- TODO: fix this, ui resolution 1280X720
    self.actor_name:SetPosition(1280 * sp.x, 720 * sp.y)
end

function app:OnSceneUpdate(eventType, eventData)
end

function app:OnPostUpdate(eventType, eventData)
end

function app:OnPostRenderUpdate(eventType, eventData)
end

function app:UpdateCamera(timeStep)
end

-- Mover script object class
Mover = ScriptObject()

function Mover:Start()
    self.moveSpeed = 0.0
    self.rotationSpeed = 0.0
    self.bounds = math3d.BoundingBox()
end

function Mover:SetParameters(moveSpeed, rotationSpeed, bounds)
    self.moveSpeed = moveSpeed
    self.rotationSpeed = rotationSpeed
    self.bounds = bounds
end

function Mover:Update(timeStep)
    local node = self.node
    node:Translate(math3d.Vector3(0.0, 0.0, 1.0) * self.moveSpeed * timeStep)

    -- If in risk of going outside the plane, rotate the model right
    local pos = node.position
    local bounds = self.bounds
    if pos.x < bounds.min.x or pos.x > bounds.max.x or pos.z < bounds.min.z or pos.z > bounds.max.z then
        node:Yaw(self.rotationSpeed * timeStep)
    end
end

local function CreateWorld(scene)
    local planeNode = scene:GetChild("Ground Plane");
    planeNode:CreateComponent(RigidBody.id)
    local shape = planeNode:CreateComponent(CollisionShape.id)
    shape:SetStaticPlane()

    local node = scene:GetChild("Sphere");
    local object = node:GetComponent(StaticModel.id)
    -- material animation
    local colorAnimation = ValueAnimation()
    colorAnimation:SetKeyFrame(0.0, Variant(math3d.Color(1.0, 1.0, 1.0, 1.0)))
    colorAnimation:SetKeyFrame(1.0, Variant(math3d.Color(1.0, 0.0, 0.0, 1.0)))
    colorAnimation:SetKeyFrame(2.0, Variant(math3d.Color(0.0, 1.0, 0.0, 1.0)))
    colorAnimation:SetKeyFrame(3.0, Variant(math3d.Color(0.0, 0.0, 1.0, 1.0)))
    colorAnimation:SetKeyFrame(4.0, Variant(math3d.Color(1.0, 1.0, 1.0, 1.0)))
    local mtl = object:GetMaterial():Clone()
    mtl:SetShaderParameterAnimation("MatDiffColor", colorAnimation)
    object:SetMaterial(mtl)

    node = scene:GetChild("Box")
    local body = node:CreateComponent(RigidBody.id)
    body:SetKinematic(true)
    shape = node:CreateComponent(CollisionShape.id)
    shape:SetBox(math3d.Vector3.ONE)

    local MODEL_MOVE_SPEED = 2.0
    local MODEL_ROTATE_SPEED = 100.0
    local bounds = math3d.BoundingBox(math3d.Vector3(-8.0, 0.0, -8.0), math3d.Vector3(8.0, 0.0, 8.0))
    -- script object will auto update self
    local sobject = node:CreateScriptObject("Mover")
    sobject:SetParameters(MODEL_MOVE_SPEED, MODEL_ROTATE_SPEED, bounds)

    node = scene:GetChild("Cylinder")
    node.position = math3d.Vector3(-0.8, 2.0, 5.0)
    body = node:CreateComponent(RigidBody.id)
    body.mass = 1.0
    body.friction = 0.75
    shape = node:CreateComponent(CollisionShape.id)
    shape:SetCylinder(1.0, 1.0)
    
    node = scene:CreateChild("Text3D")
    node.position = math3d.Vector3(-1.0, 2.0, 1.5)
    object = node:CreateComponent(Text3D.id)
    object:SetFont("Fonts/FZY3JW.TTF")
    object:SetText("I am not billboard,中文!")
    object:SetColor(math3d.Color(0.0, 0.0, 1.0))
    object:SetOpacity(0.8)
    object:SetFontSize(32)
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

function OnSendMessage()
    ShowMessage(app.input:GetText())
    app.input:SetText("")
end

local function CreateNavi(scene)
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
    scene:GetChild("Ground Plane"):CreateComponent(Navigable.id)
    -- Add padding to the navigation mesh in Y-direction so that we can add objects on top of the tallest boxes
    -- in the scene and still update the mesh correctly
    navMesh:SetPadding(math3d.Vector3(0.0, 10.0, 0.0))
    -- Now build the navigation geometry. This will take some time. Note that the navigation mesh will prefer to use
    -- physics geometry from the scene nodes, as it often is simpler, but if it can not find any (like in this example)
    -- it will use renderable geometry instead
    navMesh:Build()

    local crowdManager = scene:CreateComponent(CrowdManager.id)
    local params = crowdManager:GetObstacleAvoidanceParams(0)
    -- Set the params to "High (66)" setting
    params.velBias = 0.5
    params.adaptiveDivs = 7
    params.adaptiveRings = 3
    params.adaptiveDepth = 3
    crowdManager:SetObstacleAvoidanceParams(0, params)
end

function app:CreateScene(uiscene)
    self.uiscene = uiscene
    self.scene = Scene()
    local scene = self.scene
    scene:LoadXML(cache:GetResource("XMLFile", "Scenes/test.level"))
    local pipeline = scene:GetComponent(RenderPipeline.id)
    pipeline:SetAttribute("PCF Kernel Size", touchEnabled and Variant(1) or Variant(3))
    pipeline:SetAttribute("Post Process Antialiasing", touchEnabled and Variant(0) or Variant(2)) -- 0: "None" 1: "FXAA2" 2: "FXAA3"
    pipeline:SetAttribute("VSM Shadow Settings", Variant(math3d.Vector2(0.00015, 0.0)))
    
    -- scene:CreateComponent(Octree.id)
    self.outline_group = scene:CreateComponent(OutlineGroup.id)
    self.outline_group:SetColor(math3d.Color(0.0,0.7,0.0,1.0))

    -- create ui
    FairyGUI.UIPackage.AddPackage("UI/Joystick")
    local view = FairyGUI.UIPackage.CreateObject("Joystick", "Main")
    view:GetChild("r_cd"):SetVisible(false)
    view:GetChild("e_cd"):SetVisible(false)
    view:GetChild("d_cd"):SetVisible(false)
    view:GetChild("attack"):SetVisible(false)
    view:GetChild("button_back"):SetVisible(false)
    view:GetChild("button_forward"):SetVisible(false)
    view:GetChild("send"):AddEventListener(FairyGUI.EventType.Click, OnSendMessage)
    -- FairyGUI.CreateJoystick(view)
    self.ui_view     = view
    self.input       = view:GetChild("input")

    --create world
    CreateWorld(scene)
    CreateNavi(scene)
    SpawnCharacter(scene, "Actor")
    local agent = scene:GetComponent(CrowdAgent.id, true)
    agent:SetUpdateNodePosition(false)
    local agentNode = agent:GetNode()
    local anim_ctrl = agentNode:GetComponent(AnimationController.id, true)
    self.agent      = agent
    self.anim_ctrl  = anim_ctrl

    -- create camera
    local cryNode = scene:GetChild("Actor", true):CreateChild("Camera Yaw")
    cryNode.rotation = math3d.Quaternion(0.0, self.yaw, 0.0)
    local crpNode = cryNode:CreateChild("Camera Pitch")
    crpNode.position = math3d.Vector3(0.0, 2.0, 0)
    crpNode.rotation = math3d.Quaternion(self.pitch, 0.0, 0.0)
    local cameraNode = crpNode:CreateChild("Camera")
    cameraNode.position = math3d.Vector3(0.0, 0.0, -10.0)
    local camera = cameraNode:CreateComponent(Camera.id)
    
    self.camera         = camera
    self.camera_node    = cameraNode

    -- init actor postion
    local rotationNode = anim_ctrl:GetNode():GetParent()
    local wp = rotationNode.world_position
    local ray = math3d.Ray(math3d.Vector3(wp.x, 100.0, wp.z), math3d.Vector3(0.0, -1.0, 0.0))
    local ground = scene:GetChild("Ground Plane"):GetComponent(StaticModel.id)
    local hit, position = ground:RaycastSingle(ray)
    if hit then
        rotationNode.world_position = position
    end
    self.ground         = ground

    -- create effect
    local attackEmitter = scene:CreateChild("effect2")
    attackEmitter.position = math3d.Vector3.ZERO
    attackEmitter.scale = math3d.Vector3(0.2, 0.2, 0.2)
    local attackEffect = attackEmitter:CreateComponent(EffekseerEmitter.id)
    attackEffect:SetEffect("Effekseer/01_Suzuki01/002_sword_effect/sword_effect.efk")
    attackEffect:SetSpeed(2.0)
    attackEffect:SetLooping(false)
    self.attack_emitter = attackEmitter
    self.attack_effect = attackEffect

    -- create sound
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
    --
    self.fadetime = 0.3
    self.action = false
    self.attack = false
end

function app:Load(viewport, uiroot)
    if self.running then
        return
    end
    self.running = true
    if not self.scene then
        self:CreateScene(uiroot)
    end
    viewport:SetScene(self.scene)
    local camera = self.camera_node:GetComponent(Camera.id)
    viewport:SetCamera(camera)
    Effekseer.SetCamera(camera)
    
    if self.ui_view then
        self.uiscene.groot:AddChild(self.ui_view)
    end
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