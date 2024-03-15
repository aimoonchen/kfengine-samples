local app = {
    running = false,
    chat_list = {},
    yaw = 0,
    pitch = 0,
    MOVE_SPEED = 6.0,
}

local useStreaming = false
local streamingDistance = 2
local navigationTiles = {}
local addedTiles = {}

function app:GetName()
    return "Demo"
end

function app:Raycast(maxDistance)
    local pos
    if touchEnabled then
        local state = input_system:GetTouch(0)
        pos = state.position
    else
        pos = input_system:GetMousePosition()
    end 
    local cameraRay = self.camera:GetScreenRay(pos.x / graphics_system.width, pos.y / graphics_system.height)
    -- Pick only geometry objects, not eg. zones or lights, only get the first (closest) hit
    local octree = self.scene:GetComponent(Octree.id)
    local position, drawable = octree:RaycastSingle(cameraRay, graphic.RAY_TRIANGLE, maxDistance, graphic.DRAWABLE_GEOMETRY)
    if drawable then
        return position, drawable
    end

    return nil, nil
end

function app:ToggleStreaming(enabled)
    local navMesh = self.scene:GetComponent(DynamicNavigationMesh.id)
    if enabled then
        local maxTiles = (2 * streamingDistance + 1) * (2 * streamingDistance + 1)
        local boundingBox = navMesh.bounding_box--math3d.BoundingBox(navMesh.bounding_box)
        self:SaveNavigationData()
        navMesh:Allocate(boundingBox, maxTiles)
    else
        navMesh:Build()
    end
end

function app:UpdateStreaming()
    local navMesh = self.scene:GetComponent(DynamicNavigationMesh.id)

    -- Center the navigation mesh at the jacks crowd
    local averageJackPosition = math3d.Vector3(0, 0, 0)
    local jackGroup = self.scene:GetChild("Jacks")
    if jackGroup then
        for i = 0, jackGroup:GetNumChildren()-1 do
            averageJackPosition = averageJackPosition + jackGroup:GetChild(i).world_position
        end
        averageJackPosition = averageJackPosition / jackGroup:GetNumChildren()
    end

    local jackTile = navMesh:GetTileIndex(averageJackPosition)
    local numTiles = navMesh:GetNumTiles()
    local beginTile = math3d.VectorMax(math3d.IntVector2(0, 0), jackTile - math3d.IntVector2(1, 1) * streamingDistance)
    local endTile = math3d.VectorMin(jackTile + math3d.IntVector2(1, 1) * streamingDistance, numTiles - math3d.IntVector2(1, 1))

    -- Remove tiles
    for i, tileIdx in pairs(addedTiles) do
        if not (beginTile.x <= tileIdx.x and tileIdx.x <= endTile.x and beginTile.y <= tileIdx.y and tileIdx.y <= endTile.y) then
            addedTiles[i] = nil
            navMesh:RemoveTile(tileIdx)
        end
    end

    -- Add tiles
    for z = beginTile.y, endTile.y do
        for x = beginTile.x, endTile.x do
            local i = z * numTiles.x + x
            if not navMesh:HasTile(math3d.IntVector2(x, z)) and navigationTiles[i] then
                addedTiles[i] = math3d.IntVector2(x, z)
                navMesh:AddTile(navigationTiles[i])
            end
        end
    end
end

function app:SaveNavigationData()
    local navMesh = self.scene:GetComponent(DynamicNavigationMesh.id)
    navigationTiles = {}
    addedTiles = {}
    local numTiles = navMesh:GetNumTiles()

    for z = 0, numTiles.y - 1 do
        for x = 0, numTiles.x - 1 do
            local i = z * numTiles.x + x
            navigationTiles[i] = navMesh:GetTileData(math3d.IntVector2(x, z))
        end
    end
end

local function SpawnJack(pos, jackGroup)
    local jackNode = jackGroup:CreateChild("Jack")
    jackNode.position = pos
    jackNode:SetScale(0.02)
    local modelObject = jackNode:CreateComponent(AnimatedModel.id)
    -- modelObject:SetModel(cache:GetResource("Model", "Models/Jack.mdl"))
    -- modelObject:SetMaterial(cache:GetResource("Material", "Materials/Jack.xml"))
    modelObject:SetModel(cache:GetResource("Model", "Models/MaleBot/MaleBot.mdl"))
    modelObject:SetMaterial(0, cache:GetResource("Material", "Models/MaleBot/Materials/Body.xml"))
    modelObject:SetMaterial(1, cache:GetResource("Material", "Models/MaleBot/Materials/Joints.xml"))
    modelObject:SetCastShadows(true)
    jackNode:CreateComponent(AnimationController.id)

    -- Create a CrowdAgent component and set its height and realistic max speed/acceleration. Use default radius
    local agent = jackNode:CreateComponent(CrowdAgent.id)
    agent.height = 2.0
    agent.max_speed = 3.0
    agent.max_accel = 5.0
end

function app:SetPathPoint(spawning)
    local hitPos, hitDrawable = self:Raycast(250.0)
    if hitDrawable then
        local navMesh = self.scene:GetComponent(DynamicNavigationMesh.id)
        local pathPos = navMesh:FindNearestPoint(hitPos, math3d.Vector3.ONE)
        local jackGroup = self.scene:GetChild("Jacks")
        if spawning then
            -- Spawn a jack at the target position
            SpawnJack(pathPos, jackGroup)
        else
            -- Set crowd agents target position
            self.scene:GetComponent(CrowdManager.id):SetCrowdTarget(pathPos, jackGroup)
        end
    end
end

function app:OnUpdate(eventType, eventData)
    -- Take the frame time step, which is stored as a float
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()

    -- Move the camera, scale movement with time step
    self:UpdateCamera(timeStep)

    -- Update streaming
    if input_system:GetKeyPress(input.KEY_TAB) then
        useStreaming = not useStreaming
        self:ToggleStreaming(useStreaming)
    end
    if useStreaming then
        self:UpdateStreaming()
    end
end

function app:OnSceneUpdate(eventType, eventData)
    
end

function app:OnPostUpdate(eventType, eventData)
end

function app:OnPostRenderUpdate(eventType, eventData)
    if drawDebug then
        -- Visualize navigation mesh, obstacles and off-mesh connections
        self.scene:GetComponent(DynamicNavigationMesh.id):DrawDebugGeometry(true)
        -- Visualize agents' path and position to reach
        self.scene:GetComponent(CrowdManager.id):DrawDebugGeometry(true)
    end
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

    -- Set destination or teleport with left mouse button
    -- if input_system:GetMouseButtonPress(input.MOUSEB_LEFT) then
    --     self:SetPathPoint(input_system:GetQualifierDown(input.QUAL_SHIFT))
    -- end
    -- Add or remove objects with middle mouse button, then rebuild navigation mesh partially
    if input_system:GetMouseButtonPress(input.MOUSEB_MIDDLE) or input_system:GetKeyPress(input.KEY_O) then
        self:AddOrRemoveObject()
    end
    -- Toggle debug geometry with space
    if input_system:GetKeyPress(input.KEY_SPACE) then
        drawDebug = not drawDebug
    end

    if input_system:GetKeyPress(input.KEY_F1) then
        local v = self.instruction:IsVisible()
        self.instruction:SetVisible(not v)
    end
end

local function CreateMushroom(scene, pos)
    local mushroomNode = scene:CreateChild("Mushroom")
    mushroomNode.position = pos
    mushroomNode.rotation = math3d.Quaternion(0.0, math3d.Random(360.0), 0.0)
    mushroomNode:SetScale(2.0 + math3d.Random(0.5))
    local mushroomObject = mushroomNode:CreateComponent(StaticModel.id)
    mushroomObject:SetModel(cache:GetResource("Model", "Models/Mushroom.mdl"))
    mushroomObject:SetMaterial(cache:GetResource("Material", "Materials/Mushroom.xml"))
    mushroomObject:SetCastShadows(true)

    -- Create the navigation Obstacle component and set its height & radius proportional to scale
    local obstacle = mushroomNode:CreateComponent(Obstacle.id)
    obstacle.radius = mushroomNode.scale.x
    obstacle.height = mushroomNode.scale.y
end

local function CreateBoxOffMeshConnections(navMesh, boxGroup)
    local boxes = boxGroup:GetChildren(false)
    for i, box in ipairs(boxes) do
        local boxPos = box.position
        local boxHalfSize = box.scale.x / 2

        -- Create 2 empty nodes for the start & end points of the connection. Note that order matters only when using one-way/unidirectional connection.
        local connectionStart = box:CreateChild("ConnectionStart")
        connectionStart.world_position = navMesh:FindNearestPoint(boxPos + math3d.Vector3(boxHalfSize, -boxHalfSize, 0)) -- Base of box
        local connectionEnd = connectionStart:CreateChild("ConnectionEnd");
        connectionEnd.world_position = navMesh:FindNearestPoint(boxPos + math3d.Vector3(boxHalfSize, boxHalfSize, 0)) -- Top of box

        -- Create the OffMeshConnection component to one node and link the other node
        local connection = connectionStart:CreateComponent(OffMeshConnection.id)
        connection:SetEndPoint(connectionEnd)
    end
end

local function CreateMovingBarrels(scene, navMesh)
    local barrel = scene:CreateChild("Barrel")
    local model = barrel:CreateComponent(StaticModel.id)
    model:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
    local material = cache:GetResource("Material", "Materials/StoneTiled.xml")
    model:SetMaterial(material)
    material:SetTexture(graphic.ShaderResources.Albedo, cache:GetResource("Texture2D", "Textures/TerrainDetail2.ktx"))
    model:SetCastShadows(true)
    for i = 1, 20 do
        local clone = barrel:Clone()
        local size = 0.5 + math3d.Random(1.0)
        clone.scale = math3d.Vector3(size / 1.5, size * 2.0, size / 1.5)
        clone.position = navMesh:FindNearestPoint(math3d.Vector3(math3d.Random(80.0) - 40.0, size * 0.5, math3d.Random(80.0) - 40.0))
        local agent = clone:CreateComponent(CrowdAgent.id)
        agent.radius = clone.scale.x * 0.5
        agent.height = size
        agent:SetNavigationQuality(NAVIGATIONQUALITY_LOW)
    end
    barrel:Remove()
end

function app:AddOrRemoveObject()
    -- Raycast and check if we hit a mushroom node. If yes, remove it, if no, create a new one
    local hitPos, hitDrawable = self:Raycast(250.0)
    if hitDrawable then
        local hitNode = hitDrawable:GetNode()
        if hitNode.name == "Mushroom" then
            hitNode:Remove()
        elseif hitNode.name == "Jack" then
            hitNode:Remove()
        else
            CreateMushroom(self.scene, hitPos)
        end
    end
end

function app:CreateScene(uiscene)
    local scene = Scene()
    scene:CreateComponent(Octree.id)
    scene:CreateComponent(DebugRenderer.id)
    local zone = scene:CreateComponent(Zone.id)
    zone.bounding_box = math3d.BoundingBox(-1000.0, 1000.0)
    zone.ambient_color = math3d.Color(0.4, 0.4, 0.4)
    -- zone.ambient_brightness = 1.0
    -- zone.background_brightness = 1.0
    -- zone.shadow_mask = -8
    -- zone.light_mask = -8
    zone.fog_color = math3d.Color(0.5, 0.5, 0.7)
    zone.fog_start = 100.0
    zone.fog_end = 300.0

    -- Create scene node & StaticModel component for showing a static plane
    local planeNode = scene:CreateChild("Plane")
    planeNode.scale = math3d.Vector3(100.0, 1.0, 100.0)
    local planeObject = planeNode:CreateComponent(StaticModel.id)
    planeObject.model = cache:GetResource("Model", "Models/Plane.mdl")
    -- planeObject.material = cache:GetResource("Material", "Materials/StoneTiled.xml")
    local mtl = cache:GetResource("Material", "Materials/GridTiled.xml")
    mtl:SetShaderParameter("UOffset", Variant(math3d.Vector4(100.0, 0.0, 0.0, 0.0)))
    mtl:SetShaderParameter("VOffset", Variant(math3d.Vector4(0.0, 100.0, 0.0, 0.0)))
    planeObject:SetMaterial(mtl)

    -- Create a directional light to the world. Enable cascaded shadows on it
    local lightNode = scene:CreateChild("DirectionalLight")
    lightNode.direction = math3d.Vector3(0.6, -1.0, 0.8)
    local light = lightNode:CreateComponent(Light.id)
    light.light_type = LIGHT_DIRECTIONAL
    light.cast_shadows = true
    light.shadow_bias = BiasParameters(0.00025, 0.5)
    -- Set cascade splits at 10, 50 and 200 world units, fade shadows out at 80% of maximum shadow distance
    light.shadow_cascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)

    -- Create randomly sized boxes. If boxes are big enough, make them occluders
    local boxGroup = scene:CreateChild("Boxes");
    for i = 0,  20 do
        local boxNode = boxGroup:CreateChild("Box");
        local size = 1.0 + math3d.Random(10.0);
        boxNode.position = math3d.Vector3(math3d.Random(80.0) - 40.0, size * 0.5, math3d.Random(80.0) - 40.0)
        boxNode:SetScale(size)
        local boxObject = boxNode:CreateComponent(StaticModel.id)
        boxObject:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
        boxObject:SetMaterial(cache:GetResource("Material", "Materials/Stone.xml"))
        boxObject:SetCastShadows(true)
        if size >= 3.0 then
            boxObject:SetOccluder(true)
        end
    end

    -- Create a DynamicNavigationMesh component to the scene root
    local navMesh = scene:CreateComponent(DynamicNavigationMesh.id)
    -- Set small tiles to show navigation mesh streaming
    navMesh:SetTileSize(32)
    -- Enable drawing debug geometry for obstacles and off-mesh connections
    navMesh:SetDrawObstacles(true)
    navMesh:SetDrawOffMeshConnections(true)
    -- Set the agent height large enough to exclude the layers under boxes
    navMesh:SetAgentHeight(10.0)
    -- Set nav mesh cell height to minimum (allows agents to be grounded)
    navMesh:SetCellHeight(0.05)
    -- Create a Navigable component to the scene root. This tags all of the geometry in the scene as being part of the
    -- navigation mesh. By default this is recursive, but the recursion could be turned off from Navigable
    scene:CreateComponent(Navigable.id)
    -- Add padding to the navigation mesh in Y-direction so that we can add objects on top of the tallest boxes
    -- in the scene and still update the mesh correctly
    navMesh:SetPadding(math3d.Vector3(0.0, 10.0, 0.0))
    -- Now build the navigation geometry. This will take some time. Note that the navigation mesh will prefer to use
    -- physics geometry from the scene nodes, as it often is simpler, but if it can not find any (like in this example)
    -- it will use renderable geometry instead
    navMesh:Build()

    -- Create an off-mesh connection to each box to make them climbable (tiny boxes are skipped). A connection is built from 2 nodes.
    -- Note that OffMeshConnections must be added before building the navMesh, but as we are adding Obstacles next, tiles will be automatically rebuilt.
    -- Creating connections post-build here allows us to use FindNearestPoint() to procedurally set accurate positions for the connection
    CreateBoxOffMeshConnections(navMesh, boxGroup)

    -- Create some mushrooms as obstacles. Note that obstacles are non-walkable areas
    for i = 1, 100 do
        CreateMushroom(scene, math3d.Vector3(math3d.Random(90.0) - 45.0, 0.0, math3d.Random(90.0) - 45.0))
    end
    -- Create a CrowdManager component to the scene root
    local crowdManager = scene:CreateComponent(CrowdManager.id)
    local params = crowdManager:GetObstacleAvoidanceParams(0)
    -- Set the params to "High (66)" setting
    params.velBias = 0.5
    params.adaptiveDivs = 7
    params.adaptiveRings = 3
    params.adaptiveDepth = 3
    crowdManager:SetObstacleAvoidanceParams(0, params)

    -- Create some movable barrels. We create them as crowd agents, as for moving entities it is less expensive and more convenient than using obstacles
    CreateMovingBarrels(scene, navMesh)

    -- Create Jack node as crowd agent
    SpawnJack(math3d.Vector3(10.0, 0.0, -20.0), scene:CreateChild("Jacks"))

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
    local instruction = FairyGUI.CreateText("Use WASD keys to move, RMB to rotate view\n"..
    "LMB to set destination, SHIFT+LMB to spawn a Jack\n"..
    "MMB or O key to add obstacles or remove obstacles/agents\n"..
    "F5 to save scene, F7 to load\n"..
    "Tab to toggle navigation mesh streaming\n"..
    "Space to toggle debug geometry\n"..
    "F1 to toggle this instruction text"
    )
    instruction:SetFontSize(24)
    instruction:SetPosition(0, 36)
    view:AddChild(instruction)
    --FairyGUI.CreateJoystick(view)

    -- create camera
    local cameraNode = scene:CreateChild("Camera")
    cameraNode.position = math3d.Vector3(0.0, 15.0, -45.0)
    cameraNode:LookAt(math3d.Vector3(0.0, 0.0, 0.0))
    local camera = cameraNode:CreateComponent(Camera.id)
    camera.near_clip = 0.5
    camera.far_clip = 500.0
    

    -- record some data, access in other place
    app.instruction = instruction
    app.input       = view:GetChild("input")
    app.ui_view     = view
    app.uiscene     = uiscene
    app.scene       = scene
    app.camera_node = cameraNode
    app.camera      = camera
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

local function HandleCrowdAgentFailure(eventType, eventData)
    local node = eventData[ParamType.P_NODE]:GetPtr("Node")
    local agentState = eventData[ParamType.P_CROWD_AGENT_STATE]:GetInt()

    -- If the agent's state is invalid, likely from spawning on the side of a box, find a point in a larger area
    if agentState == CA_STATE_INVALID then
        -- Get a point on the navmesh using more generous extents
        local newPos = app.scene:GetComponent(DynamicNavigationMesh.id):FindNearestPoint(node.position, math3d.Vector3(5, 5, 5))
        -- Set the new node position, CrowdAgent component will automatically reset the state of the agent
        node.position = newPos
    end
end
local WALKING_ANI
local function HandleCrowdAgentReposition(eventType, eventData)
    --local WALKING_ANI = "Models/Jack_Walk.ani"
    if not WALKING_ANI then
        WALKING_ANI = cache:GetResource("Animation", "Models/MaleBot/Walking.ani")
    end
    
    local node = eventData[ParamType.P_NODE]:GetPtr("Node")
    local agent = eventData[ParamType.P_CROWD_AGENT]:GetPtr("CrowdAgent")
    local velocity = eventData[ParamType.P_VELOCITY]:GetVector3();
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat();

    -- Only Jack agent has animation controller
    local animCtrl = node:GetComponent(AnimationController.id)
    if animCtrl then
        local speed = velocity:Length()
        if animCtrl:IsPlaying(WALKING_ANI) then
            local speedRatio = speed / agent.max_speed
            -- Face the direction of its velocity but moderate the turning speed based on the speed ratio and timeStep
            node.rotation = node.rotation:Slerp(math3d.Quaternion(math3d.Vector3.FORWARD, velocity), 10.0 * timeStep * speedRatio)
            -- Throttle the animation speed based on agent speed ratio (ratio = 1 is full throttle)
            -- animCtrl:SetSpeed(WALKING_ANI, speedRatio * 1.5)
            animCtrl:UpdateAnimationSpeed(WALKING_ANI, speedRatio * 1.5)
        else
            -- animCtrl:Play(WALKING_ANI, 0, true, 0.1)
            animCtrl:PlayNewExclusive(AnimationParameters(WALKING_ANI):Layer(0):Looped(), 0.2)
        end

        -- If speed is too low then stop the animation
        if speed < agent.radius then
            animCtrl:Stop(WALKING_ANI, 0.5)
        end
    end
end

local function HandleCrowdAgentFormation(eventType, eventData)
    local index = eventData[ParamType.P_INDEX]:GetUInt()
    local size = eventData[ParamType.P_SIZE]:GetUInt()
    local position = eventData[ParamType.P_POSITION]:GetVector3()

    -- The first agent will always move to the exact position, all other agents will select a random point nearby
    if index > 0 then
        local crowdManager = GetEventSender()
        local agent = eventData[ParamType.P_CROWD_AGENT]:GetPtr("CrowdAgent")
        eventData[ParamType.P_POSITION] = Variant(crowdManager:GetRandomPointInCircle(position, agent.radius, agent.query_filter_type))
    end
end

local function HandleMouseTouchDown(eventType, eventData)
    app:SetPathPoint(input_system:GetQualifierDown(input.QUAL_SHIFT))
end

function app:SubscribeToEvents()
    -- Subscribe HandleCrowdAgentFailure() function for resolving invalidation issues with agents, during which we
    -- use a larger extents for finding a point on the navmesh to fix the agent's position
    SubscribeToEvent("CrowdAgentFailure", HandleCrowdAgentFailure)

    -- Subscribe HandleCrowdAgentReposition() function for controlling the animation
    SubscribeToEvent("CrowdAgentReposition", HandleCrowdAgentReposition)

    -- Subscribe HandleCrowdAgentFormation() function for positioning agent into a formation
    SubscribeToEvent("CrowdAgentFormation", HandleCrowdAgentFormation)
    
    SubscribeToEvent(input_system, "TouchBegin", HandleMouseTouchDown)
    SubscribeToEvent(input_system, "MouseButtonDown", HandleMouseTouchDown)
end

function app:UnSubscribeToEvents()
    -- Subscribe HandleCrowdAgentFailure() function for resolving invalidation issues with agents, during which we
    -- use a larger extents for finding a point on the navmesh to fix the agent's position
    UnSubscribeToEvent("CrowdAgentFailure")

    -- Subscribe HandleCrowdAgentReposition() function for controlling the animation
    UnSubscribeToEvent("CrowdAgentReposition")

    -- Subscribe HandleCrowdAgentFormation() function for positioning agent into a formation
    UnSubscribeToEvent("CrowdAgentFormation")

    UnSubscribeToEvent(input_system, "TouchBegin")
    UnSubscribeToEvent(input_system, "MouseButtonDown")
end

return app