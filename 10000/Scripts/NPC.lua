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

local m = {}

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

function m:Init(scene, astar, mesh_line)
    self.scene = scene
    self.astar = astar
    self.mesh_line = mesh_line
    local linedesc = MeshLineDesc()
    linedesc.width = 15
    linedesc.attenuation = false
    linedesc.depth = true
    linedesc.cache = true
    linedesc.color = math3d.Color(0.2, 1.0, 0.2, 0.3)
    linedesc.depth_bias = 0.001
    self.linedesc = linedesc
    local nocache_linedesc = MeshLineDesc()
    nocache_linedesc.width = 15
    nocache_linedesc.attenuation = false
    nocache_linedesc.depth = true
    nocache_linedesc.cache = true
    nocache_linedesc.color = math3d.Color(0.2, 1.0, 0.2, 0.3)
    nocache_linedesc.depth_bias = 0.001
    self.nocache_linedesc = nocache_linedesc
    self.npc = {}
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
    self.npc[#self.npc + 1] = {born_pos = pos, name = name, node = node, coord = {}, target_coord = {}, path = {}}
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
        local linePoint = {}
        local pc = #path_list
        for i=1, pc, 2 do
            local row, col = path_list[i] + 1, path_list[i + 1] + 1
            if i < pc - 1 then
                path[#path + 1] = {row, col}
            end
            if i > 1 then
                local x, z = CoordToPosition(row, col)
                linePoint[#linePoint + 1] = math3d.Vector3(x, 0, z)
            end
        end
        npc.path = path
        if npc.navi_line then
            self.mesh_line:RemoveLine(npc.navi_line)
        end
        local line = self.mesh_line:AddLine(linePoint, self.linedesc)
        -- line.model_mat = math3d.Matrix3x4(math3d.Vector3(position.x, 0.0, position.z), math3d.Quaternion.IDENTITY, 1.0)
        line.visible = false
        npc.navi_line = line
    end
end

function m:Update(timeStep)
    for index = 1, #self.npc do
        local npc = self.npc[index]
        if not npc.target then
            goto continue
        end
        local row, col = PositionToCoord(npc.target.world_position)
        if npc.target_coord[1] ~= row or npc.target_coord[2] ~= col then
            npc.target_coord[1], npc.target_coord[2] = row, col
            self:UpdatePath(index)
            if npc.action and action_manager:GetNumActions(npc.node) ~= 0 then
                local coord = npc.path[#npc.path]
                if npc.next_coord[1] ~= coord[1] or npc.next_coord[2] ~= coord[2] then
                    action_manager:CancelAction(npc.action)
                    npc.action = nil
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
                    if self.show_path and npc.navi_line and not npc.navi_line.visible then
                        npc.navi_line.visible = true
                    end
                else
                    npc.idle = true
                    PlayAnim(npc.node, "rifle_idle")
                    if npc.navi_line then
                        self.mesh_line:RemoveLine(npc.navi_line)
                    end
                end
            end
        end
        ::continue::
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

function m:ResetChase()
    for _, npc in ipairs(self.npc) do
        action_manager:CompleteAllActionsOnTarget(npc.node)
        npc.action = nil
        npc.target = nil
        npc.node.position = npc.born_pos
        npc.node.rotation = math3d.Quaternion(0, -180, 0)
        npc.coord = {}
        npc.path = {}
        npc.target_coord = {}
        npc.idle = true
        if npc.navi_line then
            npc.navi_line.visible = false
        end
        PlayAnim(npc.node, "rifle_idle")
    end
end

function m:ShowPath()
    if not self.show_path then
        self.show_path = true
    else
        self.show_path = false
    end
    for _, npc in ipairs(self.npc) do
        if npc.navi_line then
            npc.navi_line.visible = self.show_path
        end
    end
end

return m