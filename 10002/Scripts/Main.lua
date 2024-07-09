local sample2d = require "Sample2D"

local RUN_SPEED = 5 --input_system:GetKeyDown(input.KEY_SHIFT) and -5.0 or -3.0
local app = {
    running = false,
    camera_dist = CAMERA_INITIAL_DIST,
    draw_debug = false,
    enable_shadow = true,
}

function app:GetName()
    return "Demo2D"
end

function app:OnUpdate(eventType, eventData)
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()

    local wheel = input_system:GetMouseMoveWheel()
    if wheel ~= 0 then
        self.camera_dist = math3d.ClampF(self.camera_dist - wheel * 0.25, CAMERA_MIN_DIST, CAMERA_MAX_DIST)
        self.camera_node.position = math3d.Vector3(0.0, 0.0, -self.camera_dist)
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
                        end
                    --end
                    break
                end
            end
        else
            if input_system:GetMouseButtonDown(input.MOUSEB_LEFT) then
                local rotationSensitivity = 0.1
                local mouseMove = input_system:GetMouseMove()
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

local MOVE_SPEED_X = 4.0

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
    elseif not moveDir.Equals(math3d.Vector3.ZERO) then
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
        self.timer_ = 0.0

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

local PIXEL_SIZE = 0.01
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

local function HandleCollisionBegin(eventType, eventData)
    -- Get colliding node
    --local hitNode = static_cast<Node*>(eventData[PhysicsBeginContact2D::P_NODEA].GetPtr())
    local hitNode = eventData[ParamType.P_NODEA].GetPtr()
    if hitNode:GetName() == "Imp" then
        hitNode = eventData[ParamType.P_NODEB].GetPtr()
    end
    local nodeName = hitNode:GetName()
    local character2DNode = app.scene:GetChild("Imp", true)

    -- Handle coins picking
    if nodeName == "Coin" then
        hitNode:Remove()
        app.character2d.remainingCoins_ = app.character2d.remainingCoins_ - 1
        -- auto* ui = GetSubsystem<UI>()
        -- if self.character2d:remainingCoins_ == 0 then
        --     Text* instructions = static_cast<Text*>(GetUIRoot():GetChild("Instructions", true))
        --     instructions:SetText("!!! You have all the coins !!!")
        -- end
        -- Text* coinsText = static_cast<Text*>(GetUIRoot():GetChild("CoinsText", true))
        -- coinsText:SetText(ea::to_string(self.character2d:remainingCoins_)) -- Update coins UI counter
        -- sample2d:PlaySoundEffect("Powerup.wav")
    end

    -- Handle interactions with enemies
    if nodeName == "Orc" then
        local animatedSprite = character2DNode:GetComponent(AnimatedSprite2D.id)
        local deltaX = character2DNode:GetPosition().x_ - hitNode:GetPosition().x_

        -- Orc killed if character is fighting in its direction when the contact occurs
        if animatedSprite:GetAnimation() == "attack" and (deltaX < 0 == animatedSprite:GetFlipX()) then
            -- static_cast<Mover*>(hitNode:GetComponent<Mover>()):emitTime_ = 1
            hitNode:GetGetScriptObject().emitTime_ = 1
            if not hitNode:GetChild("Emitter", true) then
                hitNode:GetComponent("RigidBody2D"):Remove() -- Remove Orc's body
                -- sample2d:SpawnEffect(hitNode)
                -- sample2d:PlaySoundEffect("BigExplosion.wav")
            end
        -- Player killed if not fighting in the direction of the Orc when the contact occurs
        else
            if not character2DNode:GetChild("Emitter", true) then
                app.character2d.wounded_ = true
                if nodeName == "Orc" then
                    local orc = hitNode:GetScriptObject()
                    orc.fightTimer_ = 1
                end
                -- sample2d:SpawnEffect(character2DNode)
                -- sample2d:PlaySoundEffect("BigExplosion.wav")
            end
        end
    end
end

local function HandlePostUpdate(eventType, eventData)
    if not app.character2d then
        return
    end
    local character2DNode = app.character2d:GetNode()
    local pos = character2DNode:GetPosition()
    app.camera_node:SetPosition(math3d.Vector3(pos.x, pos.y, -10.0)) -- Camera tracks character
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
    self:UnSubscribeToEvents()
end

function app:SubscribeToEvents()
    SubscribeToEvent("PhysicsBeginContact2D", HandleCollisionBegin)
end

function app:UnSubscribeToEvents()
    UnSubscribeToEvent("PhysicsBeginContact2D")
end

return app