-- can also implement in cpp
local sample2d = {}
local CAMERA_MIN_DIST = 0.1
local CAMERA_MAX_DIST = 6.0
function sample2d:Init(scene)
    self.scene = scene
end
function sample2d:CreateCollisionShapesFromTMXObjects(tileMapNode, tileMapLayer, info)
    -- Create rigid body to the root node
    local body = tileMapNode:CreateComponent(RigidBody2D.id)
    body:SetBodyType(BodyType2D.STATIC)
    local num = tileMapLayer:GetNumObjects()
    -- Generate physics collision shapes and rigid bodies from the tmx file's objects located in "Physics" layer
    for i = 0, num do
        local tileMapObject = tileMapLayer:GetObject(i) -- Get physics objects
        local objectType = tileMapObject:GetObjectType()
        -- Create collision shape from tmx object
        if objectType == TileMapObjectType2D.RECTANGLE then
            self:CreateRectangleShape(tileMapNode, tileMapObject, tileMapObject:GetSize(), info)
        elseif objectType == TileMapObjectType2D.ELLIPSE then
            self:CreateCircleShape(tileMapNode, tileMapObject, tileMapObject:GetSize().x / 2, info) -- Ellipse is built as a Circle shape as it doesn't exist in Box2D
        elseif objectType == TileMapObjectType2D.POLYGON then
            self:CreatePolygonShape(tileMapNode, tileMapObject)
        elseif objectType == TileMapObjectType2D.POLYLINE then
            self:CreatePolyLineShape(tileMapNode, tileMapObject)
        end
    end
end

function sample2d:CreateRectangleShape(node, object, size, info)
    local shape = node:CreateComponent(CollisionBox2D.id)
    shape:SetSize(size)
    if info.orientation_ == Orientation2D.ORTHOGONAL then
        shape:SetCenter(object:GetPosition() + size / 2)
    else
        shape:SetCenter(object:GetPosition() + math3d.Vector2(info.tile_width / 2, 0.0))
        shape:SetAngle(45.0) -- If our tile map is isometric then shape is losange
    end
    shape:SetFriction(0.8)
    if object:HasProperty("Friction") then
        shape:SetFriction(tonumber(object:GetProperty("Friction")))
    end
    return shape
end

function sample2d:CreateCircleShape(node, object, radius, info)
    local shape = node:CreateComponent(CollisionCircle2D.id)
    local size = object:GetSize()
    if info.orientation_ == Orientation2D.ORTHOGONAL then
        shape:SetCenter(object:GetPosition() + size / 2)
    else
        shape:SetCenter(object:GetPosition() + math3d.Vector2(info.tile_width / 2, 0.0))
    end
    shape:SetRadius(radius)
    shape:SetFriction(0.8)
    if object:HasProperty("Friction") then
        shape:SetFriction(tonumber(object:GetProperty("Friction")))
    end
    return shape
end

function sample2d:CreatePolygonShape(node, object)
    local shape = node:CreateComponent(CollisionPolygon2D.id)
    local numVertices = object:GetNumPoints()
    shape:SetVertexCount(numVertices)
    for i = 0, numVertices do
        shape:SetVertex(i, object:GetPoint(i))
    end
    shape:SetFriction(0.8)
    if object:HasProperty("Friction") then
        shape:SetFriction(tonumber(object:GetProperty("Friction")))
    end
    return shape
end

function sample2d:CreatePolyLineShape(node, object)
    local shape = node:CreateComponent(CollisionChain2D.id)
    local numVertices = object:GetNumPoints()
    shape:SetVertexCount(numVertices)
    for i = 0, numVertices do
        shape:SetVertex(i, object:GetPoint(i))
    end
    shape:SetFriction(0.8)
    if object:HasProperty("Friction") then
        shape:SetFriction(tonumber(object:GetProperty("Friction")))
    end
    return shape
end

function sample2d:CreateCharacter(info, friction, position, scale)
    local spriteNode = self.scene:CreateChild("Imp")
    spriteNode:SetPosition(position)
    spriteNode:SetScale(scale)
    local animatedSprite = spriteNode:CreateComponent(AnimatedSprite2D.id)
    -- Get scml file and Play "idle" anim
    local animationSet = cache:GetResource("AnimationSet2D", "Urho2D/imp/imp.scml")
    animatedSprite:SetAnimationSet(animationSet)
    animatedSprite:SetAnimation("idle")
    animatedSprite:SetLayer(3) -- Put character over tile map (which is on layer 0) and over Orcs (which are on layer 2)
    local impBody = spriteNode:CreateComponent(RigidBody2D.id)
    impBody:SetBodyType(BodyType2D.DYNAMIC)
    impBody:SetAllowSleep(false)
    local shape = spriteNode:CreateComponent(CollisionCircle2D.id)
    shape:SetRadius(1.1) -- Set shape size
    shape:SetFriction(friction) -- Set friction
    shape:SetRestitution(0.1) -- Bounce

    return spriteNode
end

function sample2d:CreateTrigger()
    local node = self.scene:CreateChild() -- Clones will be renamed according to object type
    local body = node:CreateComponent(RigidBody2D.id)
    body:SetBodyType(BodyType2D.STATIC)
    local shape = node:CreateComponent(CollisionBox2D.id) -- Create box shape
    shape:SetTrigger(true)
    return node
end

function sample2d:CreateEnemy()
    local node = self.scene:CreateChild("Enemy")
    local staticSprite = node:CreateComponent(StaticSprite2D.id)
    staticSprite:SetSprite(cache:GetResource("Sprite2D", "Urho2D/Aster.png"))
    local body = node:CreateComponent(RigidBody2D.id)
    body:SetBodyType(BodyType2D.STATIC)
    local shape = node:CreateComponent(CollisionCircle2D.id) -- Create circle shape
    shape:SetRadius(0.25) -- Set radius
    return node
end

function sample2d:CreateOrc()
    local node = self.scene:CreateChild("Orc")
    node:SetScale(self.scene:GetChild("Imp", true):GetScale())
    local animatedSprite = node:CreateComponent(AnimatedSprite2D.id )
    local animationSet = cache:GetResource("AnimationSet2D", "Urho2D/Orc/Orc.scml")
    animatedSprite:SetAnimationSet(animationSet)
    animatedSprite:SetAnimation("run") -- Get scml file and Play "run" anim
    animatedSprite:SetLayer(2) -- Make orc always visible
    local body = node:CreateComponent(RigidBody2D.id)
    local shape = node:CreateComponent(CollisionCircle2D.id)
    shape:SetRadius(1.3) -- Set shape size
    shape:SetTrigger(true)
    return node
end

function sample2d:CreateCoin()
    local node = self.scene:CreateChild("Coin")
    node:SetScale(0.5)
    local animatedSprite = node:CreateComponent(AnimatedSprite2D.id )
    local animationSet = cache:GetResource("AnimationSet2D", "Urho2D/GoldIcon.scml")
    animatedSprite:SetAnimationSet(animationSet) -- Get scml file and Play "idle" anim
    animatedSprite:SetAnimation("idle")
    animatedSprite:SetLayer(4)
    local body = node:CreateComponent(RigidBody2D.id)
    body:SetBodyType(BodyType2D.STATIC)
    local shape = node:CreateComponent(CollisionCircle2D.id) -- Create circle shape
    shape:SetRadius(0.32) -- Set radius
    shape:SetTrigger(true)
    return node
end

function sample2d:CreateMovingPlatform()
    local node = self.scene:CreateChild("MovingPlatform")
    node:SetScale(math3d.Vector3(3.0, 1.0, 0.0))
    local staticSprite = node:CreateComponent(StaticSprite2D.id)
    staticSprite:SetSprite(cache:GetResource("Sprite2D", "Urho2D/Box.png"))
    local body = node:CreateComponent(RigidBody2D.id)
    body:SetBodyType(BodyType2D.STATIC)
    local shape = node:CreateComponent(CollisionBox2D.id) -- Create box shape
    shape:SetSize(math3d.Vector2(0.32, 0.32)) -- Set box size
    shape:SetFriction(0.8) -- Set friction
    return node
end

-- Mover script object class
Mover = ScriptObject()

function Mover:Start()
    self.speed_ = 0.8
    self.currentPathID_ = 1
    self.emitTime_ = 0.0
    self.fightTimer_ = 0.0
    self.flip_ = 0.0
    self.path_ = {}
end

function Mover:SetPath(path)
    self.path_ = path
end

function Mover:Update(timeStep)
    if #self.path_ < 2 then
        return
    end
    local node_ = self.node
    -- Handle Orc states (idle/wounded/fighting)
    if node_:GetName() == "Orc" then
        local animatedSprite = node_:GetComponent(AnimatedSprite2D.id)
        local anim = "run";

        -- Handle wounded state
        if self.emitTime_ > 0.0 then
            self.emitTime_ = self.emitTime_ + timeStep
            anim = "dead"

            -- Handle dead
            if self.emitTime_ >= 3.0 then
                node_:Remove()
                return
            end
        else
            -- Handle fighting state
            if self.fightTimer_ > 0.0 then
                anim = "attack"
                self.flip_ = node_:GetScene():GetChild("Imp", true):GetPosition().x - node_:GetPosition().x
                self.fightTimer_ = self.fightTimer_ + timeStep
                if self.fightTimer_ >= 3.0 then
                    self.fightTimer_ = 0.0 -- Reset
                end
            end
            -- Flip Orc animation according to speed, or player position when fighting
            animatedSprite:SetFlipX(flip_ >= 0.0)
        end
        -- Animate
        if animatedSprite:GetAnimation() ~= anim then
            animatedSprite:SetAnimation(anim)
        end
    end

    -- Don't move if fighting or wounded
    if self.fightTimer_ > 0.0 or self.emitTime_ > 0.0 then
        return
    end
    -- Set direction and move to target
    local dir = self.path_[self.currentPathID_] - node_:GetPosition2D()
    local dirNormal = dir.Normalized()
    node_:Translate(math3d.Vector3(dirNormal.x, dirNormal.y, 0.0) * math3d.Abs(self.speed_) * timeStep)
    self.flip_ = dir.x_;

    -- Check for new target to reach
    if math3d.Abs(dir.Length()) < 0.1 then
        if self.speed_ > 0.0 then
            if self.currentPathID_ + 1 < #self.path_ then
                self.currentPathID_ = self.currentPathID_ + 1
            else
                -- If loop, go to first waypoint, which equates to last one (and never reverse)
                if self.path_[self.currentPathID_] == self.path_[0] then
                    self.currentPathID_ = 1
                    return
                end
                -- Reverse path if not looping
                self.currentPathID_ = self.currentPathID_ - 1
                self.speed_ = -self.speed_;
            end
        else
            if self.currentPathID_ - 1 >= 0 then
                self.currentPathID_ = self.currentPathID_ - 1
            else
                self.currentPathID_ = 1
                self.speed_ = -self.speed_
            end
        end
    end
end

function sample2d:PopulateMovingEntities(movingEntitiesLayer)
    -- Create enemy (will be cloned at each placeholder)
    local enemyNode = self:CreateEnemy()
    local orcNode = self:CreateOrc()
    local platformNode = self:CreateMovingPlatform()
    local num = movingEntitiesLayer:GetNumObjects()
    -- Instantiate enemies and moving platforms at each placeholder (placeholders are Poly Line objects defining a path from points)
    for i = 0, num do
        -- Get placeholder object
        local movingObject = movingEntitiesLayer:GetObject(i) -- Get placeholder object
        if movingObject:GetObjectType() == TileMapObjectType2D.POLYLINE then
            -- Clone the enemy and position it at placeholder point
            local movingClone
            local offset = math3d.Vector2(0.0, 0.0)
            if movingObject:GetType() == "Enemy" then
                movingClone = enemyNode:Clone()
                offset = math3d.Vector2(0.0, -0.32)
            elseif movingObject:GetType() == "Orc" then
                movingClone = orcNode:Clone()
            elseif movingObject:GetType() == "MovingPlatform" then
                movingClone = platformNode:Clone()
            end
            if movingClone then
                movingClone:SetPosition2D(movingObject:GetPoint(0) + offset)

                -- Create script object that handles entity translation along its path
                local mover = movingClone:CreateScriptObject("Mover")

                -- Set path from points
                local path = self:CreatePathFromPoints(movingObject, offset)
                mover.path_ = path

                -- Override default speed
                if movingObject:HasProperty("Speed") then
                    mover.speed_ = tonumber(movingObject:GetProperty("Speed"))
                end
            end
        end
    end

    -- Remove nodes used for cloning purpose
    enemyNode:Remove()
    orcNode:Remove()
    platformNode:Remove()
end

function sample2d:PopulateCoins(coinsLayer)
    -- Create coin (will be cloned at each placeholder)
    local coinNode = self:CreateCoin()
    local num = coinsLayer:GetNumObjects()
    -- Instantiate coins to pick at each placeholder
    for i = 0, num do
        local coinObject = coinsLayer:GetObject(i) -- Get placeholder object
        local coinClone = coinNode:Clone()
        coinClone:SetPosition2D(coinObject:GetPosition() + coinObject:GetSize() / 2 + math3d.Vector2(0.0, 0.16))
    end
    -- Remove node used for cloning purpose
    coinNode:Remove()
end

function sample2d:PopulateTriggers(triggersLayer)
    -- Create trigger node (will be cloned at each placeholder)
    local triggerNode = self:CreateTrigger()
    local num = triggersLayer:GetNumObjects()
    -- Instantiate triggers at each placeholder (Rectangle objects)
    for i = 0, num do
        local triggerObject = triggersLayer:GetObject(i) -- Get placeholder object
        if triggerObject:GetObjectType() == TileMapObjectType2D.RECTANGLE then
            local triggerClone = triggerNode:Clone()
            triggerClone:SetName(triggerObject:GetType())
            local shape = triggerClone:GetComponent(CollisionBox2D.id)
            shape:SetSize(triggerObject:GetSize())
            triggerClone:SetPosition2D(triggerObject:GetPosition() + triggerObject:GetSize() / 2)
        end
    end
end

function sample2d:Zoom(camera)
    local zoom = camera:GetZoom()

    if input_system:GetMouseMoveWheel() ~= 0 then
        zoom = math3d.ClampF(zoom + input_system:GetMouseMoveWheel() * 0.1, CAMERA_MIN_DIST, CAMERA_MAX_DIST)
        camera:SetZoom(zoom)
    end

    if input_system:GetKeyDown(input.KEY_PAGEUP) then
        zoom = math3d.ClampF(zoom * 1.01, CAMERA_MIN_DIST, CAMERA_MAX_DIST)
        camera:SetZoom(zoom)
    end

    if input_system:GetKeyDown(input.KEY_PAGEDOWN) then
        zoom = math3d.ClampF(zoom * 0.99, CAMERA_MIN_DIST, CAMERA_MAX_DIST)
        camera:SetZoom(zoom)
    end

    return zoom
end

function sample2d:CreatePathFromPoints(object, offset)
    local path = {}
    local num = object:GetNumPoints()
    for i = 0, num do
        path.push_back(object:GetPoint(i) + offset)
    end
    return path
end

function sample2d:CreateUIContent(demoTitle, remainingLifes, remainingCoins)

end

function sample2d:HandleExitButton(eventType, eventData)
    -- local engine = GetSubsystem<Engine>()
    -- engine:Exit()
end

function sample2d:SaveScene(initial)
    -- ea::string filename = demoFilename_
    -- if (!initial)
    --     filename += "InGame"
    -- File saveFile(context_, GetSubsystem<FileSystem>():GetProgramDir() + "Data/Scenes/" + filename + ".xml", FILE_WRITE)
    -- self.scene:SaveXML(saveFile)
end

function sample2d:CreateBackgroundSprite(info, scale, texture)
    local node = self.scene:CreateChild("Background")
    node:SetPosition(math3d.Vector3(info.GetMapWidth(), info.GetMapHeight(), 0) / 2)
    node:SetScale(scale)
    local sprite = node:CreateComponent(StaticSprite2D.id)
    sprite:SetSprite(cache:GetResource("Sprite2D", texture))
    sprite:SetColor(math3d.Color(math3d.Random(0.0, 1.0), math3d.Random(0.0, 1.0), math3d.Random(0.0, 1.0), 1.0))
    sprite:SetLayer(-99)
end

function sample2d:SpawnEffect(node)

end

function sample2d:PlaySoundEffect()

end

return sample2d