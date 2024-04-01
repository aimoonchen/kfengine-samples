local Utils = require "Utils"
local animation = {
    idle            = cache:GetResource("Animation", "Models/Blockman/Animations/Idle.ani"),
    rifle_idle      = cache:GetResource("Animation", "Models/Blockman/Animations/RifleIdle.ani"),
    rifle_run       = cache:GetResource("Animation", "Models/Blockman/Animations/RifleRun.ani"),
    walk            = cache:GetResource("Animation", "Models/Blockman/Animations/Walking.ani"),
    walk_with_rifle = cache:GetResource("Animation", "Models/Blockman/Animations/WalkWithRifle.ani"),
    run             = cache:GetResource("Animation", "Models/Blockman/Animations/StandardRun.ani"),
    laughing        = cache:GetResource("Animation", "Models/Blockman/Animations/Laughing.ani"),
    talking         = cache:GetResource("Animation", "Models/Blockman/Animations/Talking.ani"),
    talking1        = cache:GetResource("Animation", "Models/Blockman/Animations/Talking1.ani"),
}
local m = {
    npc = {}
}


local function PositionToCoord(wp)
    return math.floor(wp.z + 6.0) + 1, math.floor(wp.x + 6.0) + 1
end

local function CoordToPosition(row, col)
    return -5.5 + (col - 1), -5.5 + (row - 1)
end

local function PlayAnim(node, anim_name)
    local animController = node:GetComponent(AnimationController.id)
    animController:PlayNewExclusive(AnimationParameters(animation[anim_name]):Looped())
end

function m:Init(scene, astar)
    self.scene = scene
    self.astar = astar
end

local function PutMachineGun(node)
    local rightHandNode = node:GetChild("RightHand1", true)
    local weaponNode = rightHandNode:CreateChild("weapon")
    weaponNode:SetScale(40)
    weaponNode:SetRotation(-90, 0, -180)
    weaponNode:SetPosition(0.0, 1.0, 0.5)
    local prefabReference = weaponNode:CreateComponent(PrefabReference.id)
    prefabReference:SetPrefab(cache:GetResource("PrefabResource", "Models/Weapons/machinegun.glb/Prefab.prefab"))
end

local names1 = {"鼠","牛","虎","兔","龙","蛇","马","羊","猴","鸡","狗","猪"}
local names2 = {"子","丑","寅","卯","辰","巳","午","未","申","酉","戌","亥"}
function m:CreateNpc(name, pos, scale, anim_name, color)
    local node = self.scene:CreateChild(name)
    self.npc[#self.npc + 1] = {name = name, node = node, coord = {}, target_coord = {}, path = {}}
    node:AddTag("outline")
    node.position = pos
    node.scale = scale
    node.rotation = math3d.Quaternion(0, -180, 0)
    local modelObject = node:CreateComponent(AnimatedModel.id)
    modelObject:SetModel(cache:GetResource("Model", "Models/Blockman/Models/blockman.mdl"))
    local mtl = cache:GetResource("Material", "Models/Blockman/Materials/Default.xml"):Clone()
    if color then
        mtl:SetShaderParameter("MatDiffColor", Variant(color))
    end
    modelObject:SetMaterial(mtl)
    modelObject:SetCastShadows(true)

    node:CreateComponent(AnimationController.id)

    local text_node = node:CreateChild("Text3D")
    local invScale = 1 / scale.x
    text_node.scale = math3d.Vector3(invScale, invScale, invScale)
    local text_object = text_node:CreateComponent(Text3D.id)
    text_object:SetFont("Fonts/FZY3JW.TTF")
    local idx = #self.npc
    text_object:SetText(names2[idx]..names1[idx])
    text_object:SetColor(color)
    text_object:SetFontSize(24)
    local bbsize = text_object:GetBoundingBox():Size()
    text_node.position = math3d.Vector3(-0.5 * bbsize.x * invScale, 1.2 * invScale, 0.0)

    PutMachineGun(node)
    PlayAnim(node, anim_name)
    return node
end

function m:UpdatePath(index)
    local npc = self.npc[index]
    if #npc.coord == 0 then
        return
    end
    local path_list = self.astar:FindPath(npc.coord[1] - 1, npc.coord[2] - 1, npc.target_coord[1] - 1, npc.target_coord[2] - 1)
    if #path_list > 4 then
        local path = {}
        for i=1, #path_list - 2, 2 do
            path[#path + 1] = {path_list[i] + 1, path_list[i + 1] + 1}
        end
        npc.path = path
    end
end

function m:Update(timeStep)
    for index = 1, #self.npc do
        local npc = self.npc[index]
        local row, col = PositionToCoord(npc.target.world_position)
        if #npc.target_coord == 0 or npc.target_coord[1] ~= row or npc.target_coord[2] ~= col then
            npc.target_coord[1] = row
            npc.target_coord[2] = col
            self:UpdatePath(index)
            if npc.action and action_manager:GetNumActions(npc.node) ~= 0 then
                action_manager:CancelAction(npc.action)
                local coord = npc.path[#npc.path]
                if npc.next_coord[1] ~= coord[1] or npc.next_coord[1] ~= coord[1] then
                    local px, pz = CoordToPosition(npc.coord[1], npc.coord[2])
                    local pos = npc.node.position
                    local dx, dz = px - pos.x, pz - pos.z
                    npc.node.direction = math3d.Vector3(-dx, 0, -dz)
                    local abs_dx = math.abs(dx)
                    local abs_dz = math.abs(dz)
                    if abs_dx > 0.1 or abs_dz > 0.1 then
                        npc.action = action_manager:AddAction(ActionBuilder():MoveBy((abs_dx > 0 and abs_dx or abs_dz), math3d.Vector3(dx, 0, dz)):Build(), npc.node)
                    end
                else
                    table.remove(npc.path)
                end
            end
        end
        if #npc.path > 0 and action_manager:GetNumActions(npc.node) == 0 then
            local target = table.remove(npc.path)
            if target then
                npc.coord[1], npc.coord[2] = PositionToCoord(npc.node.world_position)
                local pos = npc.node.position
                local px, pz = CoordToPosition(target[1], target[2])
                local dx, dz = px - pos.x, pz - pos.z
                npc.node.direction = math3d.Vector3(-dx, 0, -dz)
                if #npc.path > 0 then
                    npc.next_coord = target
                    if npc.idle then
                        npc.idle = false
                        PlayAnim(npc.node, "rifle_run")
                    end
                    npc.action = action_manager:AddAction(ActionBuilder():MoveBy(1, math3d.Vector3(dx, 0, dz)):Build(), npc.node)
                else
                    npc.idle = true
                    PlayAnim(npc.node, "rifle_idle")
                end
            end
        end
    end
end

local unique_pos = {}
function m:StartChaseTarget(index, target)
    local npc = self.npc[index]
    if npc.target then
        return
    end

    if not unique_pos.rows then
        unique_pos.rows = Utils.MultiRandom(1, 12, 12)
        unique_pos.cols = Utils.MultiRandom(1, 12, 12)
    end

    npc.target = target
    npc.coord = {unique_pos.rows[index], unique_pos.cols[index]}

    local current_pos = npc.node.position
    local born_pos = math3d.Vector3(-5.5 + unique_pos.cols[index] - 1, 0, -5.5 + unique_pos.rows[index] - 1)
    action_manager:AddAction(
        ActionBuilder():
        MoveBy(0.5, math3d.Vector3(0, 8, 0)):
        JumpBy(math3d.Vector3(born_pos.x - current_pos.x, 0, born_pos.z - current_pos.z)):
        RotateBy(0.01, math3d.Quaternion(0, 180, 0)):
        MoveBy(0.5, math3d.Vector3(0, -8 - current_pos.y, 0)):
        Build(),
        npc.node
    )
    PlayAnim(npc.node, "rifle_run")
end

return m