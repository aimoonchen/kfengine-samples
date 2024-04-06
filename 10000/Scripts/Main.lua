-- require("LuaPanda").start("127.0.0.1",8818);

local Item = require "Item"
local Map = require "Map"
local Utils = require "Utils"
local Timer = require "Timer"
local NPC = require "NPC"
local app = {
    running = false,
    chat_list = {},
    yaw = 0,
    pitch = 30,
    MOVE_SPEED = 6.0,
    character = {},
    rmlui_comp = {}
}
local OutlineTag = "Outline"
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
    graphicNode.scale = math3d.Vector3(0.0025, 0.0025, 0.0025)
    graphicNode:AddTag(OutlineTag)
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
    if app.attack then
        return
    end
    local wp = app.agent:GetNode().world_position
    Item:Start(15, math.floor(wp.z + 6.0) + 1, math.floor(wp.x + 6.0) + 1)

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

local rotation_speed = math3d.Vector3(20.0, 40.0, 60.0)
function app:OnUpdate(eventType, eventData)
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    self.cube:Rotate(rotation_speed.x * timeStep, rotation_speed.y * timeStep, rotation_speed.z * timeStep)
    Timer:Update(timeStep)
    NPC:Update()
    Item:Update(timeStep)
    Map:Update(timeStep)
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
        local _, drawable = Raycast(300)
        if drawable and drawable:GetNode():HasTag(OutlineTag) then
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
                elseif input_system:GetKeyDown(input.KEY_S) then
                    controlDirection = controlDirection + math3d.Vector3.FORWARD
                elseif input_system:GetKeyDown(input.KEY_A) then
                    controlDirection = controlDirection + math3d.Vector3.RIGHT
                elseif input_system:GetKeyDown(input.KEY_D) then
                    controlDirection = controlDirection + math3d.Vector3.LEFT
                end
            end
        end
    end
    
    -- local cameraRotationPitch = self.camera_node:GetParent();
    -- local cameraRotationYaw = cameraRotationPitch:GetParent();
    -- cameraRotationPitch.rotation = math3d.Quaternion(self.pitch, 0.0, 0.0)
    -- cameraRotationYaw.rotation = math3d.Quaternion(0.0, self.yaw, 0.0)
    -- local rotation = cameraRotationYaw.world_rotation
    -- local movementDirection = rotation * controlDirection
    local movementDirection = controlDirection
    local speed = -2.5--input_system:GetKeyDown(input.KEY_SHIFT) and -5.0 or -3.0
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
    local sp = self.camera:WorldToScreenPoint(math3d.Vector3(pos.x - 0.25, pos.y + 1.5, pos.z))
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

local names0 = {
    "Rat",
    "Ox",
    "Tiger",
    "Rabbit/Hare",
    "Dragon",
    "Snake",
    "Horse",
    "Sheep/Goat",
    "Monkey",
    "Rooster",
    "Dog",
    "Pig/Boar"
}
local colors = {
    math3d.Color(0.588, 0.295, 0.0,   1.0),--150, 75, 0
    math3d.Color(0.5,   0.5,   0.5,   1.0),--128, 128, 128
    math3d.Color(1.0,   1.0,   0.0,   1.0),--255, 255, 0
    math3d.Color(0.96,  0.804, 0.678, 1.0),--249, 205, 173
    math3d.Color(0.855, 0.647, 0.125, 1.0),--218, 165, 32
    math3d.Color(0.5,   0.0,   0.5,   1.0),--128，0，128
    math3d.Color(0.0,   0.0,   1.0,   1.0),--0, 0, 255
    math3d.Color(0.0,   1.0,   1.0,   1.0),--0, 255, 255
    math3d.Color(0.0,   1.0,   0.0,   1.0),--0, 255, 0
    math3d.Color(1.0,   0.0,   0.0,   1.0),--255, 0, 0
    math3d.Color(0.295, 0.0,   0.51,  1.0),--75, 0, 130
    math3d.Color(1.0,   0.5,   0.0,   1.0),--255, 128, 0
}
local names1 = {"鼠","牛","虎","兔","龙","蛇","马","羊","猴","鸡","狗","猪"}
local names2 = {"子","丑","寅","卯","辰","巳","午","未","申","酉","戌","亥"}
local names3 = {"甲","乙","丙","丁","戊","己","庚","辛","壬","癸"}
local names4 = {"水瓶","双鱼","白羊","金牛","双子","巨蟹","狮子","处女","天秤","天蝎","射手","摩羯"}
function app.OnUImessage(event)
    local rows = Utils.MultiRandom(1, 12, 8)
    local cols = Utils.MultiRandom(1, 12, 8)
    if event.action == "Rise" then
        Map:StartRise({
            {rows[1], cols[1]},
            {rows[2], cols[2]},
            {rows[3], cols[3]},
            {rows[4], cols[4]}
        })
    elseif event.action == "Fall" then
        Map:StartFall({
            {rows[5], cols[5]},
            {rows[6], cols[6]},
            {rows[7], cols[7]},
            {rows[8], cols[8]}
        })
    elseif event.action == "Flame" then
        Map:StartFlame()
    elseif event.action == "Reset" then
        NPC:ResetChase()
    end
end

function app.StartChase(index)
    NPC:StartChaseTarget(index, app.agent:GetNode())
end

local function CreateMap(scene, size, space)
    local rs = size + space
    local start_x = rs * 0.5 + rs * (#names1 // 2 - 1)
    local location = math3d.Vector3(-start_x, 0.5, -start_x - 1)
    local model = cache:GetResource("Model", "Models/Box.mdl")
    local mtl = cache:GetResource("Material","Materials/DefaultWhite.xml")
    for i, name in ipairs(names1) do
        local node = scene:CreateChild(name)
        node.position = location
        local object = node:CreateComponent(StaticModel.id)
        object:SetModel(model)
        local new_mtl = mtl:Clone()
        -- new_mtl:SetShaderParameter("MatDiffColor", Variant(colors[i]))
        object:SetMaterial(new_mtl)
        object:SetCastShadows(true)

        NPC:CreateNpc(names0[i], math3d.Vector3(location.x, 1, location.z), math3d.Vector3(0.0015, 0.0015, 0.0015), "rifle_idle", colors[i])
        location.x = location.x + rs
    end
    local node = scene:CreateChild("LeftWall")
    node.position = math3d.Vector3(-6.5, 0.5, 0.0)
    node.scale = math3d.Vector3(1, 1, 14)
    local object = node:CreateComponent(StaticModel.id)
    object:SetModel(model)
    object:SetMaterial(mtl:Clone())
    object:SetCastShadows(true)

    node = scene:CreateChild("RightWall")
    node.position = math3d.Vector3(6.5, 0.5, 0.0)
    node.scale = math3d.Vector3(1, 1, 14)
    object = node:CreateComponent(StaticModel.id)
    object:SetModel(model)
    object:SetMaterial(mtl:Clone())
    object:SetCastShadows(true)

    node = scene:CreateChild("BottomWall")
    node.position = math3d.Vector3(0.0, 0.5, 6.5)
    node.scale = math3d.Vector3(12, 1, 1)
    object = node:CreateComponent(StaticModel.id)
    object:SetModel(model)
    object:SetMaterial(mtl:Clone())
    object:SetCastShadows(true)

    Map:Init(scene, start_x)
end

local function CreateWorld(scene)
    local planeNode = scene:GetChild("Ground Plane")
    planeNode:CreateComponent(RigidBody.id)
    local shape = planeNode:CreateComponent(CollisionShape.id)
    shape:SetStaticPlane()

    local node = scene:GetChild("Sphere");
    node:SetEnabled(false)
    node = scene:GetChild("TransparentBox")
    node:SetEnabled(false)
    -- local object = node:GetComponent(StaticModel.id)
    -- -- material animation
    -- local colorAnimation = ValueAnimation()
    -- colorAnimation:SetKeyFrame(0.0, Variant(math3d.Color(1.0, 1.0, 1.0, 1.0)))
    -- colorAnimation:SetKeyFrame(1.0, Variant(math3d.Color(1.0, 0.0, 0.0, 1.0)))
    -- colorAnimation:SetKeyFrame(2.0, Variant(math3d.Color(0.0, 1.0, 0.0, 1.0)))
    -- colorAnimation:SetKeyFrame(3.0, Variant(math3d.Color(0.0, 0.0, 1.0, 1.0)))
    -- colorAnimation:SetKeyFrame(4.0, Variant(math3d.Color(1.0, 1.0, 1.0, 1.0)))
    -- local mtl = object:GetMaterial():Clone()
    -- mtl:SetShaderParameterAnimation("MatDiffColor", colorAnimation)
    -- object:SetMaterial(mtl)

    node = scene:GetChild("Box")
    node.position = math3d.Vector3(0.0, 3.0, 0.0)
    local object = node:GetComponent(StaticModel.id)
    local mtl = cache:GetResource("Material","Materials/GreenTransparent.xml"):Clone()
    mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.0, 1.0, 0.0, 0.5)))
    object:SetMaterial(mtl)
    
    -- local action = ActionBuilder():ShaderParameterFromTo(2.0, "MatDiffColor", Variant(math3d.Color(0.0, 1.0, 0.0, 0.0)), Variant(math3d.Color(0.0, 1.0, 0.0, 1.0))):ShaderParameterFromTo(2.0, "MatDiffColor", Variant(math3d.Color(0.0, 1.0, 0.0, 1.0)), Variant(math3d.Color(0.0, 1.0, 0.0, 0.0))):RepeatForever():Build()
    -- action_manager:AddAction(action, mtl)

    CreateMap(scene, 1, 0.0)
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

function app:CreateSound()
    local bankname = "Sounds/Master.bank"
    local ret = Audio.LoadBank(bankname)
    if not ret then
        print("LoadBank Faied. :", bankname)
    end
    bankname = "Sounds/Master.strings.bank"
    ret = Audio.LoadBank(bankname)
    if not ret then
        print("LoadBank Faied. :", bankname)
    end
    bankname = "Sounds/UI.bank"
    ret = Audio.LoadBank(bankname)
    if not ret then
        print("LoadBank Faied. :", bankname)
    end
    self.sound_attack = Audio.CreateEvent("event:/Scene/attack")
    -- self.sound_click5 = Audio.CreateEvent("event:/UI/click5")
    -- self.sound_mouseclick1 = Audio.CreateEvent("event:/UI/mouseclick1")
    -- self.sound_attack = Audio.CreateEvent("event:/Scene/attack")
end

function app:CreateRMLUI()
    rmlui.LoadFont("Fonts/FZY3JW.TTF", false)
    local uicomp = self.scene:CreateComponent(RmlUIComponent.id)
    uicomp:SetResource("UI/Home.rml", app)
    -- uicomp:SetResource("UI/radial-progress-bar.rml", app)
    -- uicomp:SetResource("UI/flat-buttons.rml", app)
    -- uicomp:SetResource("UI/flat-buttons-2.rml", app)
    -- uicomp:SetResource("UI/checkbox-radio-droplist.rml", app)
    -- uicomp:SetResource("UI/VisualTests/flex_01.rml", app)
    self.rmlui_comp[#self.rmlui_comp + 1] = uicomp
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
    
    local groundNode = scene:GetChild("Ground Plane")
    local scale = 128
    groundNode:SetScale(scale)
    groundNode.position = math3d.Vector3(0.0, -0.05, 0.0)
    local mtl = groundNode:GetComponent(StaticModel.id).material
    mtl:SetShaderParameter("UOffset", Variant(math3d.Vector4(scale / 2, 0.0, 0.0, 0.0)))
    mtl:SetShaderParameter("VOffset", Variant(math3d.Vector4(0.0, scale / 2, 0.0, 0.0)))

    -- scene:CreateComponent(Octree.id)
    self.outline_group = scene:CreateComponent(OutlineGroup.id)
    self.outline_group:SetColor(math3d.Color(0.0,0.7,0.0,1.0))
    self.mesh_line = scene:CreateComponent(MeshLine.id)
    -- self.mesh_line:SetDepthBias(-0.00001)
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

    local astar = AStar()
    astar:SetWorldSize(12, 12)
    -- Manhattan,Euclidean,Octagonal
    astar:SetHeuristic(AStar.Euclidean)
    astar:SetDiagonalMovement(false)
    -- local path = astar:FindPath(0, 0, 20, 20)
    -- for i=1, #path, 2 do
    --     print(path[i], path[i + 1])
    -- end
    self.astar = astar

    --create world
    SpawnCharacter(scene, "Actor", math3d.Vector3(0, 0, -2))
    local agent = scene:GetComponent(CrowdAgent.id, true)
    agent:SetUpdateNodePosition(false)
    local agentNode = agent:GetNode()
    local anim_ctrl = agentNode:GetComponent(AnimationController.id, true)
    self.agent      = agent
    self.anim_ctrl  = anim_ctrl

    NPC:Init(scene, self.astar, self.mesh_line)
    CreateWorld(scene)
    CreateNavi(scene)
    -- create camera
    -- local cryNode = scene:GetChild("Actor", true):CreateChild("Camera Yaw")
    -- cryNode.rotation = math3d.Quaternion(0.0, self.yaw, 0.0)
    -- local crpNode = cryNode:CreateChild("Camera Pitch")
    -- crpNode.position = math3d.Vector3(0.0, 2.0, 0)
    -- crpNode.rotation = math3d.Quaternion(self.pitch, 0.0, 0.0)
    -- local cameraNode = crpNode:CreateChild("Camera")
    local cameraNode = scene:CreateChild("Camera")
    cameraNode.position = math3d.Vector3(0.0, 9.5, -9.5)
    cameraNode:LookAt(math3d.Vector3(0.0, 0.0, -1.25))
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
    attackEmitter.scale = math3d.Vector3(0.1, 0.1, 0.1)
    local attackEffect = attackEmitter:CreateComponent(EffekseerEmitter.id)
    attackEffect:SetEffect("Effekseer/01_Suzuki01/002_sword_effect/sword_effect.efk")
    attackEffect:SetSpeed(1.0)
    attackEffect:SetLooping(false)
    self.attack_emitter = attackEmitter
    self.attack_effect = attackEffect

    -- create sound
    self:CreateSound()
    self:CreateRMLUI()
    --
    self.fadetime = 0.3
    self.action = false
    self.attack = false

    Item:Init(scene)
    self.cube = scene:GetChild("Box")
end

function app:Load(viewport, uiroot)
    if self.running then
        return
    end
    self.running = true
    if not self.scene then
        self:CreateScene(uiroot)
    end
    for _, comp in ipairs(self.rmlui_comp) do
        comp:SetEnabled(true)
    end
    if self.ui_view then
        self.uiscene.groot:AddChild(self.ui_view)
    end
    viewport:SetScene(self.scene)
    local camera = self.camera_node:GetComponent(Camera.id)
    viewport:SetCamera(camera)
    Effekseer.SetCamera(camera)
    self:SubscribeToEvents()
end

-- TODO: move this function to engine scripts
local function unload_module(moduleName)
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
    local filename = "Scripts/"..moduleName
    cache:ReleaseResource(filename..".lua")
    cache:ReleaseResource(filename..".luac")
end

function app:UnLoad()
    if not self.running then
        return
    end
    self.running = false
    if self.ui_view then
        self.uiscene.groot:RemoveChild(self.ui_view)
    end
    for _, comp in ipairs(self.rmlui_comp) do
        comp:SetEnabled(false)
    end
    self:UnSubscribeToEvents()
    Map:StopEffect()
    -- TODO: for same name with 10001 example
    unload_module("NPC")
end

function app:SubscribeToEvents()

end

function app:UnSubscribeToEvents()

end

return app