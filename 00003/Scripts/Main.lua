local app = {
    yaw = 0,
    pitch = 0,
    running = false,
    textures_enabled = true
}

function onTextureCheckbox(eventContext)
    local agentNode = app.agent:GetNode()
    local animController = agentNode:GetComponent(AnimationController.id, true)
    local animModel = animController:GetNode():GetComponent(AnimatedModel.id)
    app.textures_enabled = not app.textures_enabled
    if app.textures_enabled then
        animModel:SetMaterial(cache:GetResource("Material", "Models/Mutant/Materials/mutant_M.xml"))
    else
        animModel:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"))
    end
end

function app:GetName()
    return "BakedLighting"
end

function app:CreateScene(uiscene)
    local scene = Scene()

    -- Load scene content prepared in the editor (XML format). GetFile() returns an open file from the resource system
    -- which scene.LoadXML() will read
    scene:LoadXML(cache:GetResource("XMLFile", "Scenes/BakedLightingExample.xml"))
    -- In Lua the file returned by GetFile() needs to be deleted manually
    --file:delete()

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

    local camera = scene:GetComponent(Camera.id, true)
    local cameraNode = camera:GetNode()

    local navMesh = scene:GetComponent(NavigationMesh.id, true)
    local ret = navMesh:Build()

    local agent = scene:GetComponent(CrowdAgent.id, true)
    agent:SetUpdateNodePosition(false)

    local agentNode = agent:GetNode()
    local animController = agentNode:GetComponent(AnimationController.id, true)

    self.idle_anim = cache:GetResource("Animation", "Models/Mutant/Mutant_Idle0.ani")
    self.run_anim = cache:GetResource("Animation", "Models/Mutant/Mutant_Run.ani")
    animController:PlayNewExclusive(AnimationParameters(self.idle_anim):Looped())

    local crowdManager = scene:GetComponent(CrowdManager.id)
    local params = crowdManager:GetObstacleAvoidanceParams(0);
    params.weightToi = 0.0001;
    crowdManager:SetObstacleAvoidanceParams(0, params);

    local cameraRotationPitch = cameraNode:GetParent()
    local cameraRotationYaw = cameraRotationPitch:GetParent()
    self.yaw        = cameraRotationYaw.world_rotation:YawAngle()
    self.pitch      = cameraRotationPitch.world_rotation:PitchAngle()
    self.ui_view    = view
    self.uiscene     = uiscene
    self.scene      = scene
    self.agent      = agent
    self.camera_node = cameraNode
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

function app:SetupViewport(viewport)
    viewport:SetScene(self.scene)
    viewport:SetCamera(self.camera_node:GetComponent(Camera.id))
    
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
    local agentNode = self.agent:GetNode()
    local animController = agentNode:GetComponent(AnimationController.id, true)
    local rotationNode = animController:GetNode():GetParent()
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
            
                                -- Construct new orientation for the camera scene node from yaw and pitch; roll is fixed to zero
                                -- self.camera_node.rotation = math3d.Quaternion(self.pitch, self.yaw, 0)
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

    -- local agentNode = agent:GetNode()
    -- local animController = agentNode:GetComponent("AnimationController", true)
    -- local rotationNode = animController:GetNode():GetParent()
    local actualVelocityFlat = agent:GetActualVelocity() * math3d.Vector3(1.0, 0.0, 1.0)

    if actualVelocityFlat:Length() > math3d.M_LARGE_EPSILON then
        rotationNode.world_direction = actualVelocityFlat
        animController:PlayExistingExclusive(AnimationParameters(self.run_anim):Looped():Speed(actualVelocityFlat:Length() * 0.3), 0.2)
    else
        animController:PlayExistingExclusive(AnimationParameters(self.idle_anim):Looped(), 0.2)
    end

    agentNode.world_position = agent:GetPosition() * math3d.Vector3(1.0, 0.0, 1.0)
    if input_system:GetKeyPress(input.KEY_TAB) then
        local animModel = animController:GetNode():GetComponent(AnimatedModel.id)
        self.textures_enabled = not self.textures_enabled
        if self.textures_enabled then
            animModel:SetMaterial(cache:GetResource("Material", "Models/Mutant/Materials/mutant_M.xml"))
        else
            animModel:SetMaterial(cache:GetResource("Material", "Materials/DefaultWhite.xml"))
        end
    end
end

function app:OnSceneUpdate(eventType, eventData)
end

function app:OnPostUpdate(eventType, eventData)
end

function app:OnPostRenderUpdate(eventType, eventData)
end

return app