local app = {
    yaw = 0,
    pitch = 0,
    MOVE_SPEED = 4.0,
    effects = {},
    running = false,
}

local function do_create_effect(filename, position)
    local emitter = app.scene:CreateChild("effect2")
    emitter.position = position
    local effect = emitter:CreateComponent(EffekseerEmitter.id)
    effect:SetEffect(filename)
    effect:SetLooping(true)
    app.effects[#app.effects + 1] = effect
end

local function CreateEffect()
    do_create_effect("Effekseer/00_Basic/Laser03.efk",  math3d.Vector3(-15.0, 5.0, 12.0))
    do_create_effect("Effekseer/02_Tktk03/ToonWater.efk",  math3d.Vector3(-6.0, 0.1, 2.0))
    do_create_effect("Effekseer/00_Basic/Simple_Turbulence_Fireworks.efk",  math3d.Vector3(0.0, -16.0, 0.0))
    do_create_effect("Effekseer/01_Suzuki01/002_sword_effect/sword_effect.efk",  math3d.Vector3(9.0, 0.1, -8.0))
    do_create_effect("Effekseer/01_Suzuki01/001_magma_effect/aura.efk",  math3d.Vector3(-20.0, 8, 8.0))
    do_create_effect("Effekseer/00_Version16/Aura01.efk",  math3d.Vector3(-10.0, 0.1, -10.0))
    do_create_effect("Effekseer/00_Version16/Barrior01.efk",  math3d.Vector3(0.0, 0.1, -8.0))
    do_create_effect("Effekseer/02_Tktk03/Light.efk", math3d.Vector3(15.0, 0.1, 4.0) )
end

function app:GetName()
    return "Effect"
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

function app:CreateScene(uiscene)
    local scene = Scene()
    self.scene = scene
    -- Create the Octree component to the scene. This is required before adding any drawable components, or else nothing will
    -- show up. The default octree volume will be from (-1000, -1000, -1000) to (1000, 1000, 1000) in world coordinates it
    -- is also legal to place objects outside the volume but their visibility can then not be checked in a hierarchically
    -- optimizing manner
    scene:CreateComponent(Octree.id)

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

    local lightNode = scene:CreateChild("DirectionalLight")
    lightNode.direction = math3d.Vector3(0.6, -1.0, 0.8) -- The direction vector does not need to be normalized
    local light = lightNode:CreateComponent(Light.id)
    light.light_type = LIGHT_DIRECTIONAL

    CreateEffect()
    -- local skyNode = scene:CreateChild("Sky")
    -- skyNode:SetScale(500.0) -- The scale actually does not matter
    -- local skybox = skyNode:CreateComponent(Skybox.id)
    -- skybox.model = cache:GetResource("Model", "Models/Box.mdl")
    -- skybox.material = cache:GetResource("Material", "Materials/Skybox.xml")

    -- Create a scene node for the camera, which we will move around
    -- The camera will use default settings (1000 far clip distance, 45 degrees FOV, set aspect ratio automatically)
    local cameraNode = scene:CreateChild("Camera")
    local camera = cameraNode:CreateComponent(Camera.id)
    -- Set an initial position for the camera scene node above the plane
    cameraNode.position = math3d.Vector3(0.0, 15.0, -25.0)
    cameraNode:LookAt(math3d.Vector3.ZERO)
    self.camera_node = cameraNode
    self.uiscene = uiscene
    
end

function app:Load(viewport, uicreator)
    if self.running then
        return
    end
    self.running = true
    if not self.scene then
        self:CreateScene(uicreator)
    end
    self:SetupViewport(viewport)
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
    Effekseer.SetCamera(nil)
end

function app:CreateInstructions()

end

function app:SetupViewport(viewport)
    -- Set up a viewport to the Renderer subsystem so that the 3D scene can be seen. We need to define the scene and the camera
    -- at minimum. Additionally we could configure the viewport screen size and the rendering path (eg. forward / deferred) to
    -- use, but now we just use full screen and default render path configured in the engine command line options
    -- if not self.viewport then
    --     self.viewport = Viewport(self.scene, self.camera_node:GetComponent("Camera"))
    -- end
    -- renderer_system:SetViewport(0, self.viewport)
    viewport:SetScene(self.scene)
    local camera = self.camera_node:GetComponent(Camera.id)
    viewport:SetCamera(camera)
    Effekseer.SetCamera(camera)
    
    if self.ui_view then
        self.uisene.groot:AddChild(self.ui_view)
    end
end

function app:SubscribeToEvents()
end

function app:UnSubscribeToEvents()
end

function app:OnUpdate(eventType, eventData)
end

function app:OnSceneUpdate(eventType, eventData)
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    app:UpdateCamera(timeStep)
end
function app:OnPostUpdate(eventType, eventData)
end

function app:OnPostRenderUpdate(eventType, eventData)
end
return app