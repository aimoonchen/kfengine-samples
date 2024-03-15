local city = require "Scripts/City"
local npc = require "Scripts/NPC"
local CAMERA_MIN_DIST <const> = 5
local CAMERA_INITIAL_DIST <const> = 30
local CAMERA_MAX_DIST <const> = 100
local CAMERA_TARGET_HEIGHT <const> = 2.0
local RUN_SPEED = 5 --input_system:GetKeyDown(input.KEY_SHIFT) and -5.0 or -3.0
local app = {
    running = false,
    chat_list = {},
    yaw = 0,
    pitch = 30,
    character = {},
    camera_dist = CAMERA_INITIAL_DIST,
    draw_debug = false,
    run_speed = -RUN_SPEED,
    enable_shadow = true,
    enable_daynight = false,
    pause_day_time = true,
    daytime = 8.5,
    daytime_delta = 0.0,
    daytime_interval = 0.04,--25 frames per second
    daytime_speed = 0.05,
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
    graphicNode:AddTag("outline")
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
-- global function shared by rmlui lua
-- TODO: communicate between gameplay and rmlui
function onAttackBtn(eventContext)
    if app.attack or app.agent:GetActualVelocity():Length() > math3d.M_LARGE_EPSILON then
        return
    end
    app.attack = true
    app.attack_time = attack_anim.length
    app.anim_ctrl:PlayExistingExclusive(AnimationParameters(attack_anim):KeepOnCompletion(), app.fadetime)
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

local light_rotation_speed = 1

function app:OnCameraCollision()
    local aimPoint = self.camera_node.parent.world_position
    local rayDir = self.camera_node.world_position - self.camera_node.parent.world_position
    local rayDistance = self.camera_dist;
    local result = self.physics_world:RaycastSingle(math3d.Ray(aimPoint, rayDir), rayDistance, city.camera_collision_layer)
    if result.rigid_body then
        rayDistance = math.min(rayDistance, result.distance)
    end
    rayDistance = math3d.ClampF(rayDistance, CAMERA_MIN_DIST, CAMERA_MAX_DIST)
    self.camera_node.position = math3d.Vector3(0.0, 0.0, -rayDistance)-- -self.camera_dist)
    -- self.camera_node:SetPosition(aimPoint + rayDir * rayDistance)
    -- self.camera_node:SetRotation(dir)
end

function app:update_daytime(dt)
    self.daytime = dt
    self.procedural_sky:SetTime(self.daytime);
    self.light_node.world_direction = self.procedural_sky:GetSunDirection()
    self.light.color = self.procedural_sky:GetSunLuminanceGamma()
end

function app:OnUpdate(eventType, eventData)
    self:OnCameraCollision()
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    city:Update(timeStep)

    -- self.light_node:Rotate(0, 0, light_rotation_speed * timeStep, TS_WORLD)
    -- local angles = self.light_node.rotation:EulerAngles()
    -- -- local wdir = self.light_node.world_direction
    -- if angles.x < 15 then
    --     light_rotation_speed = -light_rotation_speed
    -- end
    if self.enable_daynight and not self.pause_day_time then
        self.daytime_delta = self.daytime_delta + timeStep
        if self.daytime_delta >= self.daytime_interval then
            self:update_daytime(math.fmod(self.daytime + self.daytime_delta * self.daytime_speed, 24.0))
            self.daytime_delta = 0.0
            -- local skyluminance = self.procedural_sky:GetSkyLuminance()
            -- if self.enable_shadow then
            --     if self.daytime >= 18.0 then
            --         self.enable_shadow = false
            --         self.light.cast_shadows = self.enable_shadow
            --     end
            -- else
            --     if (self.daytime > 6.0 and self.daytime < 18.0) then
            --         self.enable_shadow = true
            --         self.light.cast_shadows = self.enable_shadow
            --     end
            -- end
            -- print(self.daytime, skyluminance.x, skyluminance.y, skyluminance.z)
        end
    end
    local wheel = input_system:GetMouseMoveWheel()
    if wheel ~= 0 then
        self.camera_dist = math3d.ClampF(self.camera_dist - wheel * 0.25, CAMERA_MIN_DIST, CAMERA_MAX_DIST)
        self.camera_node.position = math3d.Vector3(0.0, 0.0, -self.camera_dist)
    end
    --[[ meshline test
    if not self.line_desc then
        -- color, opacity, width, attenuation, depth, repeat, visibility, texture, alpha_texture
        self.line_desc = MeshLineDesc()
        self.line_desc.width = 10
        self.line_desc.attenuation = false
        -- self.line_desc.depth = true
        -- self.line_desc.alpha_fade = math3d.Vector2(0.2, 0.0)
        self.line_desc.model_mat = math3d.Matrix3x4(math3d.Vector3(0.0, 5.0, 0.0), math3d.Quaternion.IDENTITY, 1.0)
        -- self.line_desc.width = 0.2
        -- self.line_desc.attenuation = true
        
        -- self.line_desc.cache = true
        -- local lineHeight = 2.0
        -- self.l0 = self.mesh_line:AddLine(math3d.Vector3(-5.0, lineHeight, 0.0), math3d.Vector3(5.0, lineHeight, 0.0), self.line_desc)
        -- self.l1 = self.mesh_line:AddLine(math3d.Vector3(0.0, lineHeight, -5.0), math3d.Vector3(0.0, lineHeight, 5.0), self.line_desc)
        local size = 1.0
        local grid_linedesc = MeshLineDesc()
        grid_linedesc.width = 8
        grid_linedesc.attenuation = false
        grid_linedesc.depth = false
        grid_linedesc.cache = true
        grid_linedesc.color = math3d.Color(1.0, 0.0, 0.0, 0.5)
        local round = 0.1
        local grid_points0 = {
            math3d.Vector3(-0.5 * size,         0.0, -0.5 * size + round),
            math3d.Vector3(-0.5 * size,         0.0, 0.5 * size - round),
            math3d.Vector3(-0.5 * size + round, 0.0, 0.5 * size),
            math3d.Vector3(0.5 * size - round,  0.0, 0.5 * size),
            math3d.Vector3(0.5 * size,          0.0, 0.5 * size - round),
            math3d.Vector3(0.5 * size,          0.0, -0.5 * size + round),
            math3d.Vector3(0.5 * size - round,  0.0, -0.5 * size),
            math3d.Vector3(-0.5 * size + round, 0.0, -0.5 * size),
            math3d.Vector3(-0.5 * size,         0.0, -0.5 * size + round)
        }
        local grid_points1 = {
            math3d.Vector3(-0.5 * size, -0.5 * size, 0.0),
            math3d.Vector3(-0.5 * size, 0.5 * size, 0.0),
            math3d.Vector3(0.5 * size, 0.5 * size, 0.0),
            math3d.Vector3(0.5 * size, -0.5 * size, 0.0),
            math3d.Vector3(-0.5 * size, -0.5 * size, 0.0)
        }
        grid_linedesc.model_mat = math3d.Matrix3x4(math3d.Vector3(0.0, 8.0, 0.0), math3d.Quaternion.IDENTITY, 1.0)
        self.mesh_line:BeginLines()
        self.mesh_line:AppendLine(grid_points0)
        self.mesh_line:AppendLine(grid_points1)
        self.test_grid0 = self.mesh_line:EndLines(grid_linedesc)
        grid_linedesc.model_mat = math3d.Matrix3x4(math3d.Vector3(0.0, 5.0, 0.0), math3d.Quaternion.IDENTITY, 1.0)
        self.test_grid1 = self.mesh_line:AddLine(grid_points0, grid_linedesc)
        grid_linedesc.model_mat = math3d.Matrix3x4(math3d.Vector3(0.0, 3.0, 0.0), math3d.Quaternion.IDENTITY, 1.0)
        --row, col, size, gap, round
        self.test_grid2 = self.mesh_line:AddGrid(5, 5, 2, 0.2, 0.2, grid_linedesc)
    end
    local lineHeight = 2.5
    self.mesh_line:AddLine(math3d.Vector3(-5.0, lineHeight, 0.0), math3d.Vector3(5.0, lineHeight, 0.0), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(0.0, lineHeight, -5.0), math3d.Vector3(0.0, lineHeight, 5.0), self.line_desc)

    self.mesh_line:AddLine(math3d.Vector3(-5.0, lineHeight, -5.0), math3d.Vector3(5.0, lineHeight, 5.0), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(-5.0, lineHeight, 5.0), math3d.Vector3(5.0, lineHeight, -5.0), self.line_desc)

    self.mesh_line:AddLine(math3d.Vector3(-5.0, -5.0 + lineHeight, 0.0), math3d.Vector3(5.0, 5.0 + lineHeight, 0.0), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(-5.0, 5.0 + lineHeight, 0.0),  math3d.Vector3(5.0, -5.0 + lineHeight, 0.0), self.line_desc)
    if not self.points0 then
        local points0 = {}
        for i = -180, 180 do
            points0[#points0 + 1] = math3d.Vector3(0.025 * i, math.sin(i * 3.14159 / 180) * 2.0 + lineHeight, 0)
        end
        self.points0 = points0
    end
    self.mesh_line:AddLine(self.points0, self.line_desc)
    if not self.points1 then
        local points1 = {}
        for i = -180, 180 do
            points1[#points1 + 1] = math3d.Vector3(0.025 * i, math.cos(i * 3.14159 / 180) * 2.0 + lineHeight, 0)
        end
        self.points1 = points1
    end
    self.mesh_line:AddLine(self.points1, self.line_desc)
    local scale = 2.0
    self.mesh_line:AddLine(math3d.Vector3(-1.0 * scale, lineHeight, -1.0 * scale), math3d.Vector3(-1.0 * scale, lineHeight, 1.0 * scale), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(-0.5 * scale, lineHeight, -1.0 * scale), math3d.Vector3(-0.5 * scale, lineHeight, 1.0 * scale), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(0.0 * scale,  lineHeight, -1.0 * scale),  math3d.Vector3(0.0 * scale,  lineHeight, 1.0 * scale), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(0.5 * scale,  lineHeight, -1.0 * scale),  math3d.Vector3(0.5 * scale,  lineHeight, 1.0 * scale), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(1.0 * scale,  lineHeight, -1.0 * scale),  math3d.Vector3(1.0 * scale,  lineHeight, 1.0 * scale), self.line_desc)
    
    self.mesh_line:AddLine(math3d.Vector3(-1 * scale, lineHeight, -1.0 * scale), math3d.Vector3(1.0 * scale, lineHeight, -1.0 * scale), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(-1 * scale, lineHeight, -0.5 * scale), math3d.Vector3(1.0 * scale, lineHeight, -0.5 * scale), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(-1 * scale, lineHeight, 0.0 * scale),  math3d.Vector3(1.0 * scale, lineHeight, 0.0 * scale), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(-1 * scale, lineHeight, 0.5 * scale),  math3d.Vector3(1.0 * scale, lineHeight, 0.5 * scale), self.line_desc)
    self.mesh_line:AddLine(math3d.Vector3(-1 * scale, lineHeight, 1.0 * scale),  math3d.Vector3(1.0 * scale, lineHeight, 1.0 * scale), self.line_desc)
    --]]
    for _, item in ipairs(self.chat_list) do
        item.life = item.life + timeStep
        if item.life > 10.0 then
            item.display:SetVisible(false)
        end
    end

    if self.attack then
        self.attack_time = self.attack_time - timeStep
        if self.attack_time <= 0 then
            self.anim_ctrl:PlayExistingExclusive(AnimationParameters(idle_anim):Looped(), self.fadetime)
            self.attack = false
        end
    else
        local actualVelocityFlat = self.agent:GetActualVelocity() * math3d.Vector3(-1.0, 0.0, -1.0)
        if actualVelocityFlat:Length() > math3d.M_LARGE_EPSILON then
            if not self.anim_ctrl:IsPlaying(run_anim) then
                self.anim_ctrl:PlayExistingExclusive(AnimationParameters(run_anim):Looped(), self.fadetime)
            end
            local rotationNode = self.anim_ctrl:GetNode():GetParent()
            rotationNode.world_direction = actualVelocityFlat
            local wp = rotationNode.world_position
            local ray = math3d.Ray(math3d.Vector3(wp.x, 100.0, wp.z), math3d.Vector3(0.0, -1.0, 0.0))
            local hit, position = self.ground:RaycastSingle(ray)
            if hit then
                rotationNode.world_position = position
            end
        elseif not self.anim_ctrl:IsPlaying(idle_anim) then
            self.anim_ctrl:PlayExistingExclusive(AnimationParameters(idle_anim):Looped(), self.fadetime)
        end
    end

    if rmlui.context:IsMouseInteracting() or FairyGUI.IsFocusUI() then
        return
    end
    local click = false
    if touchEnabled and input_system:GetTouch(0) then
        click = true
    else
        click = input_system:GetMouseButtonPress(input.MOUSEB_LEFT)
    end
    if click then
        app.outline_group:ClearDrawables()
        local hitPos, hitDrawable = Raycast(300)
        if hitDrawable then
            if hitDrawable:GetNode():HasTag("outline") then
                -- Outline
                app.outline_group:AddDrawable(hitDrawable)
            end
            -- -- Decal
            -- -- Check if target scene node already has a DecalSet component. If not, create now
            -- local targetNode = hitDrawable:GetNode()
            -- local decal = targetNode:GetComponent(DecalSet.id)
            -- if not decal then
            --     decal = targetNode:CreateComponent(DecalSet.id)
            --     decal.material = cache:GetResource("Material", "Materials/UrhoDecalAlpha.xml")
            -- end
            -- --[[
            -- Add a square decal to the decal set using the geometry of the drawable that was hit, orient it to face the camera,
            -- use full texture UV's (0,0) to (1,1). Note that if we create several decals to a large object (such as the ground
            -- plane) over a large area using just one DecalSet component, the decals will all be culled as one unit. If that is
            -- undesirable, it may be necessary to create more than one DecalSet based on the distance
            -- --]]
            -- decal:AddDecal(hitDrawable, hitPos, self.camera_node.rotation, 0.5, 1.0, 1.0, math3d.Vector2.ZERO, math3d.Vector2.ONE)
        end
        city:OnClick(hitDrawable and hitDrawable:GetNode() or nil)
    end

    if input_system:GetMouseButtonDown(input.MOUSEB_RIGHT) then
        onAttackBtn()
    end

    local controlDirection = math3d.Vector3.ZERO
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
            if input_system:GetMouseButtonDown(input.MOUSEB_LEFT) then
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
    
    local agent = self.agent
    agent:SetTargetVelocity(movementDirection * self.run_speed)

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
    if self.draw_debug then
        self.physics_world:DrawDebugGeometry(true)
        -- -- Visualize navigation mesh, obstacles and off-mesh connections
        -- self.scene:GetComponent(DynamicNavigationMesh.id):DrawDebugGeometry(true)
        -- -- Visualize agents' path and position to reach
        -- self.scene:GetComponent(CrowdManager.id):DrawDebugGeometry(true)
    end
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
    local planeNode = scene:CreateChild("Ground Plane");
    local body = planeNode:CreateComponent(RigidBody.id)
    body.collision_layer = city.camera_collision_layer
    local shape = planeNode:CreateComponent(CollisionShape.id)
    shape:SetStaticPlane()
    do
        scene:RemoveChild(scene:GetChild("Box"))
        scene:RemoveChild(scene:GetChild("TransparentBox"))
        scene:RemoveChild(scene:GetChild("Sphere"))
        scene:RemoveChild(scene:GetChild("Cylinder"))
        return
    end
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

function app:CreateEffect()
    -- bone name of charactor
    --[[
        HumanoidRootPart
        LowerTorso1
        RightUpperLeg1
        RightLowerLeg1
        RightFoot1
        LeftUpperLeg1
        LeftLowerLeg1
        LeftFoot1
        UpperTorso1
        RightUpperArm1
        RightLowerArm1
        RightHand1
        LeftUpperArm1
        LeftLowerArm1
        LeftHand1
        Head1
    --]]
    local rightHandNode = self.agent:GetNode():GetChild("RightHand1", true)
    local emitter = rightHandNode:CreateChild("effect")
    -- emitter.position = math3d.Vector3(0.0, 2.0, 0.0)
    emitter.scale = math3d.Vector3(0.5, 0.5, 0.5)
    local effect = emitter:CreateComponent(EffekseerEmitter.id)
    effect:SetEffect("Effekseer/01_Suzuki01/001_magma_effect/aura.efk")
    effect:SetLooping(true)
    effect:Play()
    self.emitter = emitter
    self.effect = effect
end

function app:CreateRMLUI()
    rmlui.LoadFont("Fonts/FZY3JW.TTF", false);
    local uicomp = self.scene:CreateComponent(RmlUIComponent.id)
    
    -- uicomp:SetResource("UI/Invaders/options.rml", app)
    uicomp:SetResource("UI/Viewer.rml", app)
    -- uicomp:SetResource("UI/List.rml", app)
    -- uicomp:SetResource("UI/Invaders/main_menu.rml", app)
    -- uicomp:SetResource("UI/Tests/VisualTests/flex_03_scroll.rml")
    self.rmlui_comp = uicomp
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
    self.sound_click5 = Audio.CreateEvent("event:/UI/click5")
    self.sound_mouseclick1 = Audio.CreateEvent("event:/UI/mouseclick1")
    self.sound_attack = Audio.CreateEvent("event:/Scene/attack")
end

function app:CreateScene(uiscene)
    self.uiscene = uiscene
    self.scene = Scene()
    local scene = self.scene
    scene:LoadXML(cache:GetResource("XMLFile", "Scenes/test.level"))
    self.physics_world = scene:CreateComponent(PhysicsWorld.id)
    scene:CreateComponent(DebugRenderer.id)
    self.mesh_line = scene:CreateComponent(MeshLine.id)
    local pipeline = scene:GetComponent(RenderPipeline.id)
    pipeline:SetAttribute("PCF Kernel Size", touchEnabled and Variant(1) or Variant(3))
    pipeline:SetAttribute("Post Process Antialiasing", touchEnabled and Variant(0) or Variant(2)) -- 0: "None" 1: "FXAA2" 2: "FXAA3"
    pipeline:SetAttribute("VSM Shadow Settings", Variant(math3d.Vector2(0.00015, 0.0)))
    local lightNode = scene:GetChild("Global Light")
    local light = lightNode:GetComponent(Light.id)
    --6.7%, 13.3%, 26.7%, 53.3%
    light.shadow_cascade = CascadeParameters(67, 200, 467, 1000, DEFAULT_SHADOWFADESTART)
    -- light.shadow_cascade = CascadeParameters(100, 0, 0, 0, DEFAULT_SHADOWFADESTART)
    self.light_node = lightNode
    self.light = light
    self.light.cast_shadows = self.enable_shadow
    if GetPlatformName() ~= "Web" then
        self.enable_daynight = true
    end
    if self.enable_daynight then
        scene:GetChild("Skybox"):SetEnabled(false)
        local zone = scene:GetChild("Global Zone"):GetComponent(Zone.id)
        zone:SetZoneTextureAttr("")
        local skynode = scene:CreateChild("ProceduralSky")
        local proceduralSky = skynode:CreateComponent(ProceduralSky.id)
        -- zone:SetProceduralSky(proceduralSky)
        -- zone.ambient_color = math3d.Color(0.4, 0.4, 0.4)
        --northDir:{0.0, 0.0, -1.0}
        proceduralSky:Init(32, 32, ProceduralSky.June, self.daytime, 256, math3d.Vector3(0.0, 0.0, -1.0))
        -- proceduralSky:SetBackgroundBrightness(0.1)
        -- prosky:Init(32, 32, ProceduralSky.June, 8.5)
        self.procedural_sky = proceduralSky
        --
        self.light_node.world_direction = self.procedural_sky:GetSunDirection()
        self.light.color = self.procedural_sky:GetSunLuminanceGamma()
    end
    local groundNode = scene:GetChild("Ground Plane")
    local scale = 512
    groundNode:SetScale(scale)
    local mtl = groundNode:GetComponent(StaticModel.id).material
    mtl:SetShaderParameter("UOffset", Variant(math3d.Vector4(scale / 2, 0.0, 0.0, 0.0)))
    mtl:SetShaderParameter("VOffset", Variant(math3d.Vector4(0.0, scale / 2, 0.0, 0.0)))

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
    view:GetChild("joystick"):SetVisible(false)
    view:GetChild("joystick_touch"):SetVisible(false)
    view:GetChild("joystick_center"):SetVisible(false)
    view:GetChild("send"):AddEventListener(FairyGUI.EventType.Click, OnSendMessage)
    --FairyGUI.CreateJoystick(view)
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
    crpNode.position = math3d.Vector3(0.0, CAMERA_TARGET_HEIGHT, 0)
    crpNode.rotation = math3d.Quaternion(self.pitch, 0.0, 0.0)
    local cameraNode = crpNode:CreateChild("Camera")
    cameraNode.position = math3d.Vector3(0.0, 0.0, -self.camera_dist)
    local camera = cameraNode:CreateComponent(Camera.id)
    camera.near_clip = 1
    camera.far_clip = 1000
    
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
    local attackEmitter = scene:CreateChild("attackeffect")
    attackEmitter.position = math3d.Vector3.ZERO
    attackEmitter.scale = math3d.Vector3(0.2, 0.2, 0.2)
    local attackEffect = attackEmitter:CreateComponent(EffekseerEmitter.id)
    attackEffect:SetEffect("Effekseer/01_Suzuki01/002_sword_effect/sword_effect.efk")
    attackEffect:SetSpeed(2.0)
    attackEffect:SetLooping(false)
    self.attack_emitter = attackEmitter
    self.attack_effect = attackEffect

    -- sound
    self:CreateSound()
    -- rmlui
    self:CreateRMLUI()
    -- effect bind to right hand
    self:CreateEffect()
    --
    self.fadetime = 0.3
    self.attack = false
    self.city = city
    city:Init(scene)
    npc:Init(scene)
    -- local rockNode = scene:CreateChild("Rock0")
    -- rockNode.position = math3d.Vector3(0, 3, 0)
    -- local rockObject = rockNode:CreateComponent(StaticModel.id)
    -- rockObject:SetModel(Model.CreateRock(math.floor(math3d.Random(1000)), math.floor(5)))
    -- local mtl = cache:GetResource("Material", "Materials/Constant/MetallicR5.xml"):Clone()
    -- mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.944, 0.776, 0.373, 1)))
    -- mtl:SetShaderParameter("MatSpecColor", Variant(math3d.Color(0.998,0.981,0.751, 1)))
    -- mtl:SetShaderParameter("Roughness", Variant(0.5))
    -- mtl:SetShaderParameter("Metallic", Variant(1.0))
    -- rockObject:SetMaterial(mtl)
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
    if self.rmlui_comp then
        self.rmlui_comp:SetEnabled(true)
    end
    if self.effect then
        self.effect:Play()
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
    if self.rmlui_comp then
        self.rmlui_comp:SetEnabled(false)
    end
    if self.effect then
        self.effect:Stop()
    end
    self:UnSubscribeToEvents()
end

function app:SubscribeToEvents()

end

function app:UnSubscribeToEvents()

end

function onWeapon(path)
    local rightHandNode = app.agent:GetNode():GetChild("RightHand1", true)
    local prefabNode = rightHandNode:GetChild("weapon")
    local prefabReference
    if not prefabNode then
        prefabNode = rightHandNode:CreateChild("weapon")
        prefabNode:SetScale(30)
        prefabNode:SetRotation(-90, 0, -180)
        prefabNode:SetPosition(0,0.7,0)
        prefabReference = prefabNode:CreateComponent(PrefabReference.id)
    else
        prefabReference = prefabNode:GetComponent(PrefabReference.id)
    end
    if path then
        prefabReference:SetEnabled(true)
        prefabReference:SetPrefab(cache:GetResource("PrefabResource", path))
    else
        prefabReference:SetEnabled(false)
    end
end

function app:OnUImessage(msg)
    if msg.action == "CreatePrefab" then

    elseif msg.action == "Attack" then
        onAttackBtn()
    elseif msg.action == "Weapon" then
        onWeapon(msg.data)
    end
end

function app:PauseDayTime(b)
    self.pause_day_time = b
end

function app:GetDayTime()
    return self.daytime
end

function app:SetDayTime(dt)
    if not self.enable_daynight then
        return
    end
    if dt == self.daytime then
        return
    end
    self:update_daytime(dt)
    self.daytime_delta = self.daytime_interval
end

return app