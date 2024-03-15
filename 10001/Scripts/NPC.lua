local npc = {

}

local function PutonWeapon(node)
    local rightHandNode = node:GetChild("RightHand1", true)
    local weaponNode = rightHandNode:CreateChild("weapon")
    weaponNode:SetScale(40)
    weaponNode:SetRotation(-90, 0, -180)
    weaponNode:SetPosition(0.0, 1.0, 0.5)
    local prefabReference = weaponNode:CreateComponent(PrefabReference.id)
    prefabReference:SetPrefab(cache:GetResource("PrefabResource", "Models/Weapons/machinegun.glb/Prefab.prefab"))
end

function npc:Init(scene)
    self.scene = scene
    self.anim = {
        idle            = cache:GetResource("Animation", "Models/Blockman/Animations/Idle.ani"),
        rifle_idle      = cache:GetResource("Animation", "Models/Blockman/Animations/RifleIdle.ani"),
        walk            = cache:GetResource("Animation", "Models/Blockman/Animations/Walking.ani"),
        walk_with_rifle = cache:GetResource("Animation", "Models/Blockman/Animations/WalkWithRifle.ani"),
        run             = cache:GetResource("Animation", "Models/Blockman/Animations/StandardRun.ani"),
        laughing        = cache:GetResource("Animation", "Models/Blockman/Animations/Laughing.ani"),
        talking         = cache:GetResource("Animation", "Models/Blockman/Animations/Talking.ani"),
        talking1        = cache:GetResource("Animation", "Models/Blockman/Animations/Talking1.ani"),
    }
    local npcNode = self:CreateNpc("guard1", math3d.Vector3(-15, 0, 5), "walk_with_rifle", math3d.Color(0.5,0.5,1.0,1.0))
    npcNode.rotation = math3d.Quaternion(0,-90,0)
    local patrolDist = 50
    local patrolSpeed = 1.5
    local patrolTime = patrolDist / patrolSpeed
    action_manager:AddAction(
        ActionBuilder():
        RotateBy(1, math3d.Quaternion(0, 180, 0)):
        MoveBy(patrolTime, math3d.Vector3(-patrolDist, 0, 0)):
        RotateBy(1, math3d.Quaternion(0, -180, 0)):
        MoveBy(patrolTime, math3d.Vector3(patrolDist, 0, 0)):
        RepeatForever():Build(),
        npcNode
    )
    PutonWeapon(npcNode)
    npcNode = self:CreateNpc("guard2", math3d.Vector3(15, 0, 5), "walk_with_rifle", math3d.Color(0.5,0.5,1.0,1.0))
    npcNode.rotation = math3d.Quaternion(0,90,0)
    action_manager:AddAction(
        ActionBuilder():
        RotateBy(1, math3d.Quaternion(0, -180, 0)):
        MoveBy(patrolTime, math3d.Vector3(patrolDist, 0, 0)):
        RotateBy(1, math3d.Quaternion(0, 180, 0)):
        MoveBy(patrolTime, math3d.Vector3(-patrolDist, 0, 0)):
        RepeatForever():Build(),
        npcNode
    )
    PutonWeapon(npcNode)
    npcNode = self:CreateNpc("guard1", math3d.Vector3(-10, 0, 6), "rifle_idle", math3d.Color(0.5,1.0,0.5,1.0))
    PutonWeapon(npcNode)
    npcNode = self:CreateNpc("guard2", math3d.Vector3(10, 0, 6), "rifle_idle", math3d.Color(0.5,1.0,0.5,1.0))
    PutonWeapon(npcNode)
end

function npc:CreateGun()
    
end

function npc:CreateNpc(name, pos, idle_anim, color)
    local node = self.scene:CreateChild(name)
    node:AddTag("outline")
    node.position = pos
    node.scale = math3d.Vector3(0.005, 0.005, 0.005)
    local modelObject = node:CreateComponent(AnimatedModel.id)
    modelObject:SetModel(cache:GetResource("Model", "Models/Blockman/Models/blockman.mdl"))
    local mtl = cache:GetResource("Material", "Models/Blockman/Materials/Default.xml"):Clone()
    if color then
        mtl:SetShaderParameter("MatDiffColor", Variant(color))
    end
    modelObject:SetMaterial(mtl)
    modelObject:SetCastShadows(true)
    local animController = node:CreateComponent(AnimationController.id)
    animController:PlayNewExclusive(AnimationParameters(self.anim[idle_anim]):Looped())
    return node
end

return npc