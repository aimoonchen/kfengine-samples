local sample2d = require "Sample2D"

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
    local rayDistance = self.camera_dist
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
    self.procedural_sky:SetTime(self.daytime)
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
    
    local cameraRotationPitch = self.camera_node:GetParent()
    local cameraRotationYaw = cameraRotationPitch:GetParent()
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


CharacterIsometric = ScriptObject()

local MOVE_SPEED_X<const> = 4.0

function CharacterIsometric:Start()
    -- Flag when player is wounded.
    self.wounded_ = false
    -- Flag when player is dead.
    self.killed_ = false
    -- Timer for particle emitter duration.
    self.timer_ = 0.0
    -- Number of coins in the current level.
    self.maxCoins_ = 0
    -- Counter for remaining coins to pick.
    self.remainingCoins_ = 0
    -- Counter for remaining lifes.
    self.remainingLifes_ = 3
    -- Scaling factor based on tiles' aspect ratio (definitively set at tile map creation).
    self.moveSpeedScale_ = 1.0
    -- Camera's zoom (used to scale movement speed based on camera zoom).
    self.zoom_ = 0.0
end
function CharacterIsometric:Update(timeStep)
    -- Handle wounded/killed states
    if self.killed_ then
        return
    end
    if self.wounded_ then
        self:HandleWoundedState(timeStep)
        return
    end

    local animatedSprite = self.node:GetComponent(AnimatedSprite2D.id)

    -- Set direction
    local moveDir = math3d.Vector3.ZERO -- Reset
    local speedX = math3d.Clamp(MOVE_SPEED_X / self.zoom_, 0.4, 1.0)
    local speedY = speedX

    if input_system:GetKeyDown(KEY_A) or input_system:GetKeyDown(KEY_LEFT) then
        moveDir = moveDir + math3d.Vector3.LEFT * speedX
        animatedSprite:SetFlipX(false) -- Flip sprite (reset to default play on the X axis)
    end
    if input_system:GetKeyDown(KEY_D) or input_system:GetKeyDown(KEY_RIGHT) then
        moveDir = moveDir + math3d.Vector3.RIGHT * speedX
        animatedSprite:SetFlipX(true) -- Flip sprite (flip animation on the X axis)
    end

    if not moveDir.Equals(math3d.Vector3.ZERO) then
        speedY = speedX * self.moveSpeedScale_
    end
    if input_system:GetKeyDown(KEY_W) or input_system:GetKeyDown(KEY_UP) then
        moveDir = moveDir + math3d.Vector3.UP * speedY
    end
    if input_system:GetKeyDown(KEY_S) or input_system:GetKeyDown(KEY_DOWN) then
        moveDir = moveDir + math3d.Vector3.DOWN * speedY
    end
    -- Move
    if not moveDir.Equals(math3d.Vector3.ZERO) then
        self.node:Translate(moveDir * timeStep)
    end
    -- Animate
    if input_system:GetKeyDown(KEY_SPACE) then
        if animatedSprite:GetAnimation() ~= "attack" then
            animatedSprite:SetAnimation("attack", LM_FORCE_LOOPED)
        end
    elseif !moveDir.Equals(math3d.Vector3.ZERO) then
        if animatedSprite:GetAnimation() ~= "run" then
            animatedSprite:SetAnimation("run")
        end
    elseif animatedSprite:GetAnimation() ~= "idle" then
        animatedSprite:SetAnimation("idle")
    end
end
function CharacterIsometric:HandleWoundedState(timeStep)
    local node_ = self.node
    local body = node_:GetComponent(RigidBody2D.id)
    local animatedSprite = node_:GetComponent(AnimatedSprite2D.id)
    
    -- Play "hit" animation in loop
    if animatedSprite:GetAnimation() ~= "hit" then
        animatedSprite:SetAnimation("hit", LoopMode2D.FORCE_LOOPED)
    end
    -- Update timer
    self.timer_ = self.timer_ + timeStep

    if self.timer_ > 2.0 then
        -- Reset timer
        timer_ = 0.0

        -- Clear forces (should be performed by setting linear velocity to zero, but currently doesn't work)
        body:SetLinearVelocity(math3d.Vector2.ZERO)
        body:SetAwake(false)
        body:SetAwake(true)

        -- Remove particle emitter
        node_:GetChild("Emitter", true):Remove()

        -- Update lifes UI and counter
        self.remainingLifes_ = self.remainingLifes_ - 1

        -- local ui = GetSubsystem<UI>()
        -- Text* lifeText = static_cast<Text*>(GetSubsystem<UI>():GetRoot():GetChild("LifeText", true))
        -- lifeText:SetText(ea::to_string(remainingLifes_)) -- Update lifes UI counter

        -- Reset wounded state
        self.wounded_ = false

        -- Handle death
        if self.remainingLifes_ == 0 then
            self:HandleDeath()
            return
        end

        -- Re-position the character to the nearest point
        if node_:GetPosition().x_ < 15.0 then
            node_:SetPosition(math3d.Vector3(-5.0, 11.0, 0.0))
        else
            node_:SetPosition(math3d.Vector3(18.8, 9.2, 0.0))
        end
    end
end
function CharacterIsometric:HandleDeath()
    local body = self.node:GetComponent(RigidBody2D.id)
    local animatedSprite = self.node:GetComponent(AnimatedSprite2D.id)

    -- Set state to 'killed'
    self.killed_ = true

    -- Update UI elements
    -- local ui = GetSubsystem<UI>()
    -- Text* instructions = static_cast<Text*>(ui:GetRoot():GetChild("Instructions", true))
    -- instructions:SetText("!!! GAME OVER !!!")
    -- static_cast<Text*>(ui:GetRoot():GetChild("ExitButton", true)):SetVisible(true)
    -- static_cast<Text*>(ui:GetRoot():GetChild("PlayButton", true)):SetVisible(true)

    -- Show mouse cursor so that we can click
    input_system:SetMouseVisible(true)

    -- Put character outside of the scene and magnify him
    self.node_:SetPosition(math3d.Vector3(-20.0, 0.0, 0.0))
    self.node_:SetScale(1.2)

    -- Play death animation once
    if animatedSprite:GetAnimation() ~= "dead" then
        animatedSprite:SetAnimation("dead")
    end
end


function app:CreateRMLUI()
    rmlui.LoadFont("Fonts/FZY3JW.TTF", false)
    local uicomp = self.scene:CreateComponent(RmlUIComponent.id)
    uicomp:SetResource("UI/Viewer.rml", app)
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
local PIXEL_SIZE <const> = 0.01
function app:CreateScene(uiscene)
    self.uiscene = uiscene
    self.scene = Scene()
    local scene = self.scene
    scene:CreateComponent(Octree.id)
    scene:CreateComponent(DebugRenderer.id)
    local physicsWorld = scene:CreateComponent(PhysicsWorld2D.id)
    physicsWorld:SetGravity(math3d.Vector2(0.0, 0.0))

    local cameraNode = scene:CreateChild("Camera")
    local camera = cameraNode:CreateComponent(Camera.id)
    camera:SetOrthographic(true)
    self.camera         = camera
    self.camera_node    = cameraNode
    camera:SetOrthoSize(graphics_system.height * PIXEL_SIZE)
    camera:SetZoom(2.0 * math.min(graphics_system.width / 1280.0, graphics_system.height() / 800.0))


    local tmxFile = cache:GetResource("TmxFile2D", "Urho2D/Tilesets/atrium.tmx")
    local tileMapNode = scene:CreateChild("TileMap")
    local tileMap = tileMapNode:CreateComponent(TileMap2D.id)
    tileMap:SetTmxFile(tmxFile)
    local info = tileMap:GetInfo()

    local spriteNode = sample2d:CreateCharacter(info, 0.0, math3d.Vector3(-5.0, 11.0, 0.0), 0.15)
    local character2d = spriteNode:CreateScriptObject("CharacterIsometric")
    self.character2d = character2d
    character2d.moveSpeedScale_ = info.tileHeight_ / info.tileWidth_
    character2d.zoom_ = camera:GetZoom()

    local tileMapLayer = tileMap:GetLayer(tileMap:GetNumLayers() - 1)
    sample2d:CreateCollisionShapesFromTMXObjects(tileMapNode, tileMapLayer, info)
    sample2d:PopulateMovingEntities(tileMap:GetLayer(tileMap:GetNumLayers() - 2))
    local coinsLayer = tileMap:GetLayer(tileMap:GetNumLayers() - 3)
    sample2d:PopulateCoins(coinsLayer)

    character2d.remainingCoins_ = coinsLayer:GetNumObjects()
    character2d.maxCoins_ = coinsLayer:GetNumObjects()
end

function app:HandleCollisionBegin(eventType, eventData)
    -- Get colliding node
    local hitNode = static_cast<Node*>(eventData[PhysicsBeginContact2D::P_NODEA].GetPtr())
    if hitNode:GetName() == "Imp" then
        hitNode = static_cast<Node*>(eventData[PhysicsBeginContact2D::P_NODEB].GetPtr())
    end
    local nodeName = hitNode:GetName()
    local character2DNode = self.scene:GetChild("Imp", true)

    -- Handle coins picking
    if nodeName == "Coin" then
        hitNode:Remove()
        self.character2d.remainingCoins_ = self.character2d.remainingCoins_ - 1
        -- auto* ui = GetSubsystem<UI>()
        -- if self.character2d:remainingCoins_ == 0 then
        --     Text* instructions = static_cast<Text*>(GetUIRoot():GetChild("Instructions", true))
        --     instructions:SetText("!!! You have all the coins !!!")
        -- end
        -- Text* coinsText = static_cast<Text*>(GetUIRoot():GetChild("CoinsText", true))
        -- coinsText:SetText(ea::to_string(self.character2d:remainingCoins_)) -- Update coins UI counter
        sample2d:PlaySoundEffect("Powerup.wav")
    end

    -- Handle interactions with enemies
    if nodeName == "Orc" then
        local animatedSprite = character2DNode:GetComponent(AnimatedSprite2D.id)
        local deltaX = character2DNode:GetPosition().x_ - hitNode:GetPosition().x_

        -- Orc killed if character is fighting in its direction when the contact occurs
        if animatedSprite:GetAnimation() == "attack" and (deltaX < 0 == animatedSprite:GetFlipX()) then
            -- static_cast<Mover*>(hitNode:GetComponent<Mover>()):emitTime_ = 1
            hitNode:GetGetScriptObject().emitTime_ = 1
            if !hitNode:GetChild("Emitter", true) then
                hitNode:GetComponent("RigidBody2D"):Remove() -- Remove Orc's body
                -- sample2d:SpawnEffect(hitNode)
                -- sample2d:PlaySoundEffect("BigExplosion.wav")
            end
        -- Player killed if not fighting in the direction of the Orc when the contact occurs
        else
            if !character2DNode:GetChild("Emitter", true) then
                self.character2d.wounded_ = true
                if nodeName == "Orc" then
                    local orc = static_cast<Mover*>(hitNode:GetComponent<Mover>())
                    orc.fightTimer_ = 1
                end
                sample2d:SpawnEffect(character2DNode)
                sample2d:PlaySoundEffect("BigExplosion.wav")
            end
        end
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
    if self.rmlui_comp then
        self.rmlui_comp:SetEnabled(false)
    end
    if self.effect then
        self.effect:Stop()
    end
    self:UnSubscribeToEvents()
    -- TODO: for same name with 10000 example
    unload_module("NPC")
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