local app = {
    running = false,
    chat_list = {},
    yaw = 0,
    pitch = 0,
    MOVE_SPEED = 6.0,
    character = {}
}

function app:GetName()
    return "Demo"
end

local function UpdateCharacterName()
    for _, char in ipairs(app.character) do
        local pos = char[1].world_position
        local sp = app.camera:WorldToScreenPoint(math3d.Vector3(pos.x, pos.y + 3.0, pos.z))
        -- char[2]:SetPosition(graphics_system.width * sp.x, graphics_system.height * sp.y)
        -- TODO: fix this, ui resolution : 1280X720
        char[2]:SetPosition(1280 * sp.x, 720 * sp.y)
    end
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
        if drawable and drawable:GetNode().name ~= "Plane" then
            app.outline_group:AddDrawable(drawable)
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
            UpdateCharacterName()
        end
    end
    local move = false
    local controlDirection = math3d.Vector3(0.0, 0.0, 0.0)
    if input_system.IsJoystickCapture() then
        controlDirection = math3d.Quaternion(0.0, input_system.GetJoystickDegree() - 90, 0.0) * math3d.Vector3.BACK
        controlDirection:Normalize()
        self.MOVE_SPEED = 4.0
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
        UpdateCharacterName()
    end
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

local function GetColor()
    return math3d.Color(math3d.Random(), math3d.Random(), math3d.Random(), 1.0)
end

local function get_mud_mtl()
    local mtl = cache:GetResource("Material", "Materials/Constant/GlossyWhiteDielectric.xml"):Clone()
    mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.75, 0.75, 0.73, 1.0)))
    mtl:SetShaderParameter("Roughness", Variant(0.7))
    mtl:SetShaderParameter("Metallic", Variant(0.0))
    return mtl
end

local function CreateStep(scene)
    for i = 1, 10 do
        local stepNode = scene:CreateChild("Step")
        stepNode.scale = math3d.Vector3(4.0, 0.4 * i, 0.4)
        stepNode.position = math3d.Vector3(-8.0, 0.2 * i, 9.3 - (10 - i) * 0.4)
        local object = stepNode:CreateComponent(StaticModel.id)
        object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        object:SetCastShadows(true)
        object:SetMaterial(get_mud_mtl())
        
        local body = stepNode:CreateComponent(RigidBody.id)
        body.friction = 0.75
        body.contact_threshold = 0.1
        local shape = stepNode:CreateComponent(CollisionShape.id)
        shape:SetBox(math3d.Vector3.ONE)
        shape.margin = 0.01
    end
end

local function CreateWall(scene, scale, position)
    local northNode = scene:CreateChild("NorthWall")
    northNode.scale = scale
    northNode.position = position
    local object = northNode:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    object:SetCastShadows(true)
    object:SetMaterial(get_mud_mtl())
    
    local body = northNode:CreateComponent(RigidBody.id)
    body.friction = 0.75
    body.contact_threshold = 0.1
    local shape = northNode:CreateComponent(CollisionShape.id)
    shape:SetBox(math3d.Vector3.ONE)
    shape.margin = 0.01
end

local function CreateSeeSaw(scene)
    local seeSawParent = scene:CreateChild("SeeSawParent")
    seeSawParent.position = math3d.Vector3(-1.0, 1.0, -5.0)
    seeSawParent:SetTags("Untagged")

    local seeSawFrame = seeSawParent:CreateChild("SeeSawFrame")
    seeSawFrame:SetTags("Untagged")
    local other_body = seeSawFrame:CreateComponent(RigidBody.id)
    other_body.contact_threshold = 0.1

    local seeSawNode = seeSawParent:CreateChild("SeeSaw")
    seeSawNode:SetTags("Untagged")
    seeSawNode.scale = math3d.Vector3(3.0, 0.1, 0.5)
    local object = seeSawNode:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    object:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"):Clone())
    object:GetMaterial():SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.0, 0.75, 0.75, 1.0)))
    object:SetCastShadows(true)
    local body = seeSawNode:CreateComponent(RigidBody.id)
    body.mass = 1.0
    body.friction = 0.75
    body.contact_threshold = 0.1
    local shape = seeSawNode:CreateComponent(CollisionShape.id)
    shape:SetBox(math3d.Vector3.ONE)
    shape.margin = 0.01

    local constraint = seeSawNode:CreateComponent(Constraint.id)
    constraint.constraint_type = CONSTRAINT_HINGE
    constraint:SetAxis(math3d.Vector3(0.0, 0.0, 1.0))
    constraint:SetOtherAxis(math3d.Vector3(0.0, 0.0, 1.0))
    constraint.high_limit = math3d.Vector2(45.0, 0.0)
    constraint.low_limit = math3d.Vector2(-45.0, 0.0)
    constraint.disable_collision = true
    constraint:SetOtherBody(other_body)

    local baseNode = seeSawParent:CreateChild("SeeSawBase")
    baseNode.scale = math3d.Vector3(1.4, 1.4, 0.4)
    baseNode.rotation = math3d.Quaternion(math3d.Vector3(0.0, 0.0, 45.0))
    baseNode.position = math3d.Vector3(0.0, -1.05, 0.0)
    local object = baseNode:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    object:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"):Clone())
    object:GetMaterial():SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.75, 0.75, 0.0, 1.0)))
    object:SetCastShadows(true)
end

local function CreateDoor(scene)
    -- local doorPrefab = cache:GetResource("XMLFile", "Prefabs/Door.xml")
    -- local objectNode = scene:CreateChild("Door")
    -- objectNode.position = math3d.Vector3(2.0, 0.5,-2.0)
    -- local prefabReference = objectNode:CreateComponent(PrefabReference.id)
    -- prefabReference:SetPrefab(doorPrefab)

    local doorParent = scene:CreateChild("DoorParent")
    doorParent:SetTags("Untagged")
    
    local doorFrame = doorParent:CreateChild("DoorFrame")
    doorFrame.position = math3d.Vector3(0.0, 2.0, 0.0)
    doorFrame:SetTags("Untagged")
    local other_body = doorFrame:CreateComponent(RigidBody.id)
    other_body.contact_threshold = 0.1

    local doorNode = doorParent:CreateChild("Door")
    doorNode:SetTags("Untagged")
    doorNode.scale = math3d.Vector3(2.0, 4.0, 0.2)
    doorNode.position = math3d.Vector3(1.0, 2.0, 0.0)
    local object = doorNode:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    object:SetMaterial(cache:GetResource("Material", "Materials/DefaultGrey.xml"))
    object:SetCastShadows(true)
    local body = doorNode:CreateComponent(RigidBody.id)
    body.mass = 1.0
    body.contact_threshold = 0.1
    local shape = doorNode:CreateComponent(CollisionShape.id)
    shape:SetBox(math3d.Vector3.ONE)
    shape.margin = 0.01

    local constraint = doorNode:CreateComponent(Constraint.id)
    constraint.constraint_type = CONSTRAINT_HINGE
    constraint.rotation = math3d.Quaternion(0.707107, 0.707107, 0.0, 0.0)
    constraint.position = math3d.Vector3(-1.0, 0.0, 0.0)
    constraint.other_rotation = math3d.Quaternion(0.707107, 0.707107, 0.0, 0.0)
    constraint.high_limit = math3d.Vector2(90.0, 0.0)
    constraint.low_limit = math3d.Vector2(-90.0, 0.0)
    constraint.disable_collision = true
    constraint:SetOtherBody(other_body)
end

local function SpawnBoxObject(scene, scale, position)
    local boxNode = scene:CreateChild("SmallBox")
    boxNode.scale = scale
    boxNode.position = position
    local object = boxNode:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    object:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"):Clone())
    object:GetMaterial():SetShaderParameter("MatDiffColor", Variant(GetColor()))
    object:SetCastShadows(true)
    local body = boxNode:CreateComponent(RigidBody.id)
    body.mass = 0.25
    body.friction = 0.75
    local shape = boxNode:CreateComponent(CollisionShape.id)
    shape:SetBox(math3d.Vector3.ONE)
    -- local OBJECT_VELOCITY = 10.0
    -- shape.linear_velocity = math3d.Vector3(0.0, 1.0, 0.0) * OBJECT_VELOCITY
end

local action_nodes = {}
local function CreateAction(scene)
    local AddActionNode = function (type, pos, action)
        local node = scene:CreateChild("Action")
        node.position = pos
        local object = node:CreateComponent(StaticModel.id)
        object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        object:SetCastShadows(true)

        local textNode = node:CreateChild("type")
        textNode.position = math3d.Vector3(-0.5, 1.5, 0.0)
        local textObject = textNode:CreateComponent(Text3D.id)
        textObject:SetFont("Fonts/FZY3JW.TTF")
        textObject:SetText(type)
        textObject:SetColor(math3d.Color(0.5, 1.0, 0.5))
        textObject:SetOpacity(0.8)
        textObject:SetFontSize(48)

        action_nodes[#action_nodes + 1] = {action, node}
    end
    
    local pos = math3d.Vector3(-17.25, 0.5, -15.0)
    local step = 2.25
    local offset = math3d.Vector3(0.0, 0.0, 4.0)
    local neg_offset = math3d.Vector3(0.0, 0.0, -4.0)
    AddActionNode("Linear", pos, ActionBuilder():MoveBy(1.5, offset):DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("BackIn", pos, ActionBuilder():MoveBy(1.5, offset):BackIn():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("BackOut", pos, ActionBuilder():MoveBy(1.5, offset):BackOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("BackInOut", pos, ActionBuilder():MoveBy(1.5, offset):BackInOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("BounceOut", pos, ActionBuilder():MoveBy(1.5, offset):BounceOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("BounceIn", pos, ActionBuilder():MoveBy(1.5, offset):BounceIn():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("BounceInOut", pos, ActionBuilder():MoveBy(1.5, offset):BounceInOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("SineOut", pos, ActionBuilder():MoveBy(1.5, offset):SineOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("SineIn", pos, ActionBuilder():MoveBy(1.5, offset):SineIn():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("SineInOut", pos, ActionBuilder():MoveBy(1.5, offset):SineInOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("ExponentialOut", pos, ActionBuilder():MoveBy(1.5, offset):ExponentialOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("ExponentialIn", pos, ActionBuilder():MoveBy(1.5, offset):ExponentialIn():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("ExponentialInOut", pos, ActionBuilder():MoveBy(1.5, offset):ExponentialInOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("ElasticIn", pos, ActionBuilder():MoveBy(1.5, offset):ElasticIn():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("ElasticOut", pos, ActionBuilder():MoveBy(1.5, offset):ElasticOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("ElasticInOut", pos, ActionBuilder():MoveBy(1.5, offset):ElasticInOut():DelayTime(1.5):JumpBy(neg_offset):RepeatForever():Build())
    pos.x = pos.x + step
    AddActionNode("MultiAction", math3d.Vector3(10.5, 4.5, -10.0), ActionBuilder():MoveBy(2.5, math3d.Vector3(0.0, 0.0, 20.0)):MoveBy(2.5, math3d.Vector3(-21.0, 0.0, 0.0)):MoveBy(2.5, math3d.Vector3(0.0, 0.0, -20.0)):JumpBy(math3d.Vector3(21.0, 0.0, 0.0)):RepeatForever():Build())
    for _, action in ipairs(action_nodes) do
        action_manager:AddAction(action[1], action[2])
    end
end

local function CreateProceduralSky(scene)
    scene:CreateComponent(PhysicsWorld.id)
    local pipeline = scene:CreateComponent(RenderPipeline.id)
    -- rp:SetSettings({
    --     ColorSpace = render_pipeline.LinearLDR,
    --     PCFKernelSize = 5,
    --     Antialiasing = render_pipeline.FXAA3,
    -- })
    pipeline:SetAttribute("Color Space", Variant(1))-- 0: GammaLDR, 1: LinearLDR 2: LinearHDR
    -- pipeline:SetAttribute("Specular Quality", Variant(2)) -- 0: Disabled 1: Simple, 2: Antialiased
    pipeline:SetAttribute("PCF Kernel Size", touchEnabled and Variant(1) or Variant(3))
    -- pipeline:SetAttribute("Bloom", Variant(true))
    pipeline:SetAttribute("Post Process Antialiasing", touchEnabled and Variant(0) or Variant(2)) -- 0: "None" 1: "FXAA2" 2: "FXAA3"
    pipeline:SetAttribute("VSM Shadow Settings", Variant(math3d.Vector2(0.00015, 0.0)))

    local zone = scene:CreateComponent(Zone.id)
    -- zone.position = math3d.Vector3(-1, 2, 1)
    zone:SetEnabled(true)
    zone.bounding_box = math3d.BoundingBox(-1000.0, 1000.0)
    -- zone.ambient_color = math3d.Color(0.5, 0.5, 0.5)
    -- zone.ambient_brightness = 1.0
    zone.background_brightness = 0.5
    -- zone.background_brightness = 1.0
    -- zone.shadow_mask = -8
    -- zone.light_mask = -8
    -- zone.fog_color = math3d.Color(0.5, 0.5, 0.7)
    -- zone.fog_start = 100.0
    -- zone.fog_end = 300.0

    zone:SetZoneTextureAttr("Textures/DefaultSkybox.xml")

    local skyNode = scene:CreateChild("Sky");
    -- skyNode.position = math3d.Vector3(-1.0, 2.0, 1.0)
    skyNode.rotation = math3d.Quaternion(1.0, 0.0, 0.0, 0.0)
    local skybox = skyNode:CreateComponent(Skybox.id)
    skybox:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    skybox:SetMaterial(cache:GetResource("Material","Materials/DefaultSkybox.xml"))

    local planeNode = scene:CreateChild("Plane");
    planeNode.scale = math3d.Vector3(100.0, 1.0, 100.0)
    local planeObject = planeNode:CreateComponent(StaticModel.id)
    planeObject:SetModel(cache:GetResource("Model", "Models/Plane.mdl"))
    local mtl = cache:GetResource("Material", "Materials/GridTiled.xml")
    mtl:SetShaderParameter("UOffset", Variant(math3d.Vector4(100.0, 0.0, 0.0, 0.0)))
    mtl:SetShaderParameter("VOffset", Variant(math3d.Vector4(0.0, 100.0, 0.0, 0.0)))
    planeObject:SetMaterial(mtl)
    planeNode:CreateComponent(RigidBody.id)
    local shape = planeNode:CreateComponent(CollisionShape.id)
    shape:SetStaticPlane()
    --
    CreateWall(scene, math3d.Vector3(20.0, 4.0, 1.0), math3d.Vector3(0.0, 2.0, 10.0))
    CreateWall(scene, math3d.Vector3(1.0, 4.0, 21.0), math3d.Vector3(10.5, 2.0, 0.0))
    CreateWall(scene, math3d.Vector3(1.0, 4.0, 21.0), math3d.Vector3(-10.5, 2.0, 0.0))
    CreateWall(scene, math3d.Vector3(20.0, 1.0, 1.0), math3d.Vector3(0.0, 0.5, -9.5))
    CreateStep(scene)
    SpawnBoxObject(scene, math3d.Vector3(2.0, 2.0, 2.0), math3d.Vector3(-3.0, 10.0, -3.0))
    SpawnBoxObject(scene, math3d.Vector3(1.5, 1.5, 1.5), math3d.Vector3(0.0, 10.0, -3.0))
    SpawnBoxObject(scene, math3d.Vector3(2.0, 2.0, 2.0), math3d.Vector3(3.0, 10.0, -3.0))
    CreateDoor(scene)
    SpawnBoxObject(scene, math3d.Vector3(1, 1, 1), math3d.Vector3(-2.0, 5.0, -5.0))
    SpawnBoxObject(scene, math3d.Vector3(1, 1, 1), math3d.Vector3(0.2, 5.0, -5.0))
    CreateSeeSaw(scene)
    CreateAction(scene)
    -- local skymtl = Material("sky/vs_sky_landscape", "sky/fs_sky_landscape", "base")
    -- planeObject:SetMaterial(skymtl);
    -- planeObject:SetMaterial(cache:GetResource<Material>("Materials/StoneTiled.xml"));

    -- local skynode = scene:CreateChild("sky")
    -- sky_ = skynode:CreateComponent(ProceduralSky.id)
    -- sky_:Init(32, 32, ProceduralSky.June, 15.0)
    -- graphics_system:SetSky(sky_)

    --dummy light
    local lightNode = scene:CreateChild("DirectionalLight")
    lightNode.direction = math3d.Vector3(0.6, -1.0, 0.8) -- The direction vector does not need to be normalized
    local light = lightNode:CreateComponent(Light.id)
    light.light_type = LIGHT_DIRECTIONAL
    -- light.color = math3d.Color(0.5, 0.5, 0.5)
    light.cast_shadows = true
    light.shadow_bias = BiasParameters(DEFAULT_CONSTANTBIAS, DEFAULT_SLOPESCALEDBIAS)
    light.shadow_cascade = CascadeParameters(5.0, 12.0, 30.0, 100.0, DEFAULT_SHADOWFADESTART)

    ---[[
    node = scene:CreateChild("Sphere");
    node.scale = math3d.Vector3(2.0, 2.0, 2.0)
    node.position = math3d.Vector3(0.0, 2.0, -3.0)
    object = node:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    object:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"))
    object:SetCastShadows(true)
    -- object:SetMaterial(skymtl:Clone())
    local body = node:CreateComponent(RigidBody.id)
    body.mass = 1.0
    body.friction = 0.75
    -- body.contact_threshold = 0.1
    local shape = node:CreateComponent(CollisionShape.id)
    shape:SetSphere(1.0)
    -- shape.margin = 0.01
    -- material animation
    local colorAnimation = ValueAnimation()
    colorAnimation:SetKeyFrame(0.0, Variant(math3d.Color(1.0, 1.0, 1.0, 1.0)))
    colorAnimation:SetKeyFrame(1.0, Variant(math3d.Color(1.0, 0.0, 0.0, 1.0)))
    colorAnimation:SetKeyFrame(2.0, Variant(math3d.Color(0.0, 1.0, 0.0, 1.0)))
    colorAnimation:SetKeyFrame(3.0, Variant(math3d.Color(0.0, 0.0, 1.0, 1.0)))
    colorAnimation:SetKeyFrame(4.0, Variant(math3d.Color(1.0, 1.0, 1.0, 1.0)))
    local mtl = object:GetMaterial()
    mtl:SetShaderParameterAnimation("MatDiffColor", colorAnimation)

    node = scene:CreateChild("Box")
    node.position = math3d.Vector3(1.0, 0.5, -3.0)
    object = node:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    object:SetCastShadows(true)
    -- object:SetMaterial(skymtl:Clone())
    body = node:CreateComponent(RigidBody.id)
    body:SetKinematic(true)
    shape = node:CreateComponent(CollisionShape.id)
    shape:SetBox(math3d.Vector3.ONE)

    local MODEL_MOVE_SPEED = 2.5
    local MODEL_ROTATE_SPEED = 100.0
    local bounds = math3d.BoundingBox(math3d.Vector3(-7.0, 0.0, -7.0), math3d.Vector3(7.0, 0.0, 7.0))
    -- script object will auto update self
    local sobject = node:CreateScriptObject("Mover")
    sobject:SetParameters(MODEL_MOVE_SPEED, MODEL_ROTATE_SPEED, bounds)

    node = scene:CreateChild("Pyramid")
    node.scale = math3d.Vector3(2.0, 2.0, 2.0)
    node.position = math3d.Vector3(2.0, 2.0, -1.0)
    object = node:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Pyramid.mdl"))
    object:SetCastShadows(true)
    -- object:SetMaterial(skymtl:Clone())
    body = node:CreateComponent(RigidBody.id)
    body.mass = 1.0
    body.friction = 0.75
    shape = node:CreateComponent(CollisionShape.id)
    shape:SetConvexHull(object.model)

    node = scene:CreateChild("Cylinder")
    node.scale = math3d.Vector3(2.0, 2.0, 2.0)
    node.position = math3d.Vector3(0.0, 2.0, 5.0)
    object = node:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    object:SetCastShadows(true)
    -- object:SetMaterial(skymtl:Clone())
    body = node:CreateComponent(RigidBody.id)
    body.mass = 1.0
    body.friction = 0.75
    shape = node:CreateComponent(CollisionShape.id)
    shape:SetCylinder(1.0, 1.0)

    node = scene:CreateChild("TransparentBox")
    node.position = math3d.Vector3(0.0, 2.0, 2.0)
    node.scale = math3d.Vector3(8.0, 4.0, 0.8)
    object = node:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    object:SetCastShadows(true)
    object:SetMaterial(cache:GetResource("Material","Materials/Constant/MattTransparentGreen.xml"))

    node = scene:CreateChild("Text3D")
    node.position = math3d.Vector3(-2.0, 3.0, 1.5)
    object = node:CreateComponent(Text3D.id)
    object:SetFont("Fonts/FZY3JW.TTF")
    object:SetText("Bullet Physics!")
    object:SetColor(math3d.Color(0.0, 0.0, 1.0))
    object:SetOpacity(0.8)
    object:SetFontSize(72)
    --]]
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
    -- local bp = BiasParameters(DEFAULT_CONSTANTBIAS, DEFAULT_SLOPESCALEDBIAS)
    -- light:SetShadowBias(bp)
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

    create_pbr_node("Plane", "Models/Plane.mdl", "Materials/PBR/Check.xml", math3d.Vector3(0.0, 0.0, 2.0), math3d.Quaternion(1.0, 0.0, 0.0, 0.0), math3d.Vector3(10.0, 5.0, 10.0))
    --
    local scale = math3d.Vector3(2.0, 2.0, 2.0)
    local rot = math3d.Quaternion(0.0, 0.0, 1.0, 0.0)
    local previewPath = "Models/MaterialPreview.mdl"
    local object = create_pbr_node("Mud", previewPath, "Materials/PBR/Mud.xml", math3d.Vector3(0.0, 1.0, 3.0), rot, scale)
    object:SetMaterial(1, cache:GetResource("Material", "Materials/Constant/MetallicR7.xml"))
    object = create_pbr_node("Leather", previewPath, "Materials/PBR/Leather.xml", math3d.Vector3(2.0, 1.0, 3.0), rot, scale)
    object:SetMaterial(1, cache:GetResource("Material", "Materials/Constant/MetallicR7.xml"))
    object = create_pbr_node("Sand", previewPath, "Materials/PBR/Sand.xml", math3d.Vector3(4.0, 1.0, 3.0), rot, scale)
    object:SetMaterial(1, cache:GetResource("Material", "Materials/Constant/MetallicR7.xml"))
    object = create_pbr_node("Diamond Plate", previewPath, "Materials/PBR/DiamonPlate.xml", math3d.Vector3(-2.0, 1.0, 3.0), rot, scale)
    object:SetMaterial(1, cache:GetResource("Material", "Materials/Constant/MetallicR7.xml"))
    object = create_pbr_node("Lead", previewPath, "Materials/PBR/Lead.xml", math3d.Vector3(-4.0, 1.0, 3.0), rot, scale)
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
    object = create_pbr_node("Bike", "Models/HoverBike.mdl", "Materials/PBR/HoverBikeGlass.xml", math3d.Vector3(0.0, 0.0, 5.0), rot, scale )
    object:SetMaterial(1, cache:GetResource("Material", "Materials/PBR/HoverBikeHull.xml"))
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

local function SpawnRoblox(parent, name, pos, init_anim)
    init_anim = init_anim or "Idle"
    local node = parent:CreateChild(name)
    node.position = pos
    node.scale = math3d.Vector3(0.005, 0.005, 0.005)
    local object = node:CreateComponent(AnimatedModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Blockman/Models/blockman.mdl"))
    object:SetCastShadows(true)
    object:SetMaterial(cache:GetResource("Material","Models/Blockman/Materials/Default.xml"))
    local walk_anim = cache:GetResource("Animation", "Models/Blockman/Animations/"..init_anim..".ani")
    local anim_ctl = node:CreateComponent(AnimationController.id)
    anim_ctl:PlayNewExclusive(AnimationParameters(walk_anim):Looped())
    --
    local npcName = FairyGUI.CreateText(name, math3d.Color(1.0, 1.0, 0.0))
    npcName:SetFontSize(24)
    app.ui_view:AddChild(npcName)
    npcName:SetPivot(0.5, 0.5, true)
    return {node, npcName}
end

local function CreateTower(scene)
    local num = 24
    local angle = 15 -- 360 / num
    local ba = 4
    local bb = 3
    local ta = 2.7
    local tb = 2
    local offset = math3d.Vector3(0.7, 0.0, -0.7)
    local basepoint = {}
    local toppoint = {}
    local height = 46
    for i = 1, num, 1 do
        local rad = (i - 1) * angle * math.pi / 180
        local pos = math3d.Quaternion(-45, math3d.Vector3(0.0, 1.0, 0.0)) * math3d.Vector3(bb * math.sin(rad), 0.0, ba * math.cos(rad))
        basepoint[#basepoint + 1] = pos + offset
        toppoint[#toppoint + 1] = math3d.Vector3(tb * math.sin(rad), height, ta * math.cos(rad))
    end

    local tower = scene:CreateChild("CantonTower")
    tower.position = math3d.Vector3(0.0, 0.0, 16.0)
    for i = 1, num, 1 do
        local bidx = i - 5
        if bidx < 1 then
            bidx = bidx + 24
        end
        local dir = toppoint[i] - basepoint[bidx]
        dir:Normalize()
        local rot = math3d.Quaternion()
        rot:FromRotationTo(math3d.Vector3(0.0, 1.0, 0.0), dir)
        local cylinderNode = tower:CreateChild("Cylinder" .. i)
        local cylinderObject = cylinderNode:CreateComponent(StaticModel.id)
        cylinderObject:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
        cylinderObject:SetMaterial(cache:GetResource("Material", "Materials/RainbowTest.xml"):Clone())
        -- cylinderObject:GetMaterial():SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.8, 0.8, 0.8, 1.0)))
        -- cRainbow: strength, speed, angle
        cylinderObject:GetMaterial():SetShaderParameter("Rainbow", Variant(math3d.Color(0.8, 0.15, -45.0, 0.0)))
        cylinderObject:SetCastShadows(true)
        local tran0 = math3d.Matrix3x4(math3d.Vector3(0.0, height * 0.5, 0.0), math3d.Quaternion.IDENTITY, math3d.Vector3(0.25, height, 0.25))
        local tran1 = math3d.Matrix3x4(basepoint[bidx], rot, math3d.Vector3.ONE)
        cylinderNode.local_matrix = tran1 * tran0
    end

    local mainNode = tower:CreateChild("Cylinder")
    mainNode.scale = math3d.Vector3(1.5, height, 1.5)
    mainNode.position = math3d.Vector3(0.0, height * 0.5, 0.0)
    local mainObject = mainNode:CreateComponent(StaticModel.id)
    mainObject:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    mainObject:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"):Clone())
    mainObject:GetMaterial():SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.8, 0.8, 0.8, 1.0)))
    mainObject:SetCastShadows(true)

    local pyramidNode = tower:CreateChild("Pyramid")
    pyramidNode.scale = math3d.Vector3(0.4, 14.0, 0.4)
    pyramidNode.position = math3d.Vector3(0.0, height + 7.0, 0.0)
    local pyramidObject = pyramidNode:CreateComponent(StaticModel.id)
    pyramidObject:SetModel(cache:GetResource("Model", "Models/Pyramid.mdl"))
    pyramidObject:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"):Clone())
    pyramidObject:GetMaterial():SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.6, 0.6, 0.6, 1.0)))
    pyramidObject:SetCastShadows(true)

    local ceilNode = tower:CreateChild("Cylinder")
    ceilNode.scale = math3d.Vector3(3.2, 3.0, 4.32)
    ceilNode.position = math3d.Vector3(0.0, 44, 0.0)
    local ceilObject = ceilNode:CreateComponent(StaticModel.id)
    ceilObject:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    ceilObject:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"):Clone())
    ceilObject:GetMaterial():SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.8, 0.8, 0.8, 1.0)))
    ceilObject:SetCastShadows(true)

    local hallNode = tower:CreateChild("Cylinder")
    hallNode.scale = math3d.Vector3(6.4, 4.0, 4.8)
    hallNode.rotation = math3d.Quaternion(45, math3d.Vector3(0.0, 1.0, 0.0))
    hallNode.position = math3d.Vector3(0.0, 2, 0.0) + offset
    local hallObject = hallNode:CreateComponent(StaticModel.id)
    hallObject:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    hallObject:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"):Clone())
    hallObject:GetMaterial():SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.8, 0.8, 0.8, 1.0)))
    hallObject:SetCastShadows(true)
end

local function CreateStage(scene, pos)
    local stageNode = scene:CreateChild("Stage")
    stageNode.scale = math3d.Vector3(9.0, 1.0, 9.0)
    stageNode.position = pos
    local stageObject = stageNode:CreateComponent(StaticModel.id)
    stageObject:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    stageObject:SetMaterial(cache:GetResource("Material", "Models/Blockman/Materials/Default.xml"):Clone())
    stageObject:SetCastShadows(true)
    local mtl = stageObject:GetMaterial()
    mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.6, 0.3, 0.3, 1.0)))
    mtl:SetShaderParameter("Metallic", Variant(1.0))
    mtl:SetShaderParameter("Roughness", Variant(0.6))
    app.character[#app.character + 1] = SpawnRoblox(scene, "Piano", math3d.Vector3(pos.x - 3.0, pos.y + 0.5, pos.z), "PianoPlaying")
    app.character[#app.character + 1] = SpawnRoblox(scene, "Drum", math3d.Vector3(pos.x, pos.y + 0.5, pos.z + 2.0), "PlayingDrums")
    app.character[#app.character + 1] = SpawnRoblox(scene, "Guitar", math3d.Vector3(pos.x + 3.0, pos.y + 0.5, pos.z), "GuitarPlaying")
    app.character[#app.character + 1] = SpawnRoblox(scene, "Singer", math3d.Vector3(pos.x - 1.0, pos.y + 0.5, pos.z - 2.0), "Singing")
end

function app:CreateScene(uiscene)
    local scene = Scene()
    scene:CreateComponent(Octree.id)

    --create scene
    -- CreatePBRScene(scene)
    CreateProceduralSky(scene)
    CreateTower(scene)
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
    view:GetChild("joystick"):SetVisible(false)
    view:GetChild("joystick_touch"):SetVisible(false)
    view:GetChild("joystick_center"):SetVisible(false)
    view:GetChild("send"):AddEventListener(FairyGUI.EventType.Click, OnSendMessage)
    --FairyGUI.CreateJoystick(view)

    -- create camera
    local cameraNode = scene:CreateChild("Camera")
    cameraNode.position = math3d.Vector3(0.0, 10.0, -35.0)
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
    CreateStage(scene, math3d.Vector3(0.0, 0.5, -20.0))
    UpdateCharacterName()
end

function app:SetupViewport(viewport)
    viewport:SetScene(self.scene)
    local camera = self.camera_node:GetComponent(Camera.id)
    viewport:SetCamera(camera)
    
    if self.ui_view then
        self.uiscene.groot:AddChild(self.ui_view)
    end
end

function app:Load(viewport, uiroot)
    if self.running then
        return
    end
    self.running = true
    if not self.scene then
        self:CreateScene(uiroot)
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