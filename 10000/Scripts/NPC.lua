local Utils = require "Utils"

local m = {
    anim = {
        idle            = cache:GetResource("Animation", "Models/Blockman/Animations/Idle.ani"),
        rifle_idle      = cache:GetResource("Animation", "Models/Blockman/Animations/RifleIdle.ani"),
        rifle_run       = cache:GetResource("Animation", "Models/Blockman/Animations/RifleRun.ani"),
        walk            = cache:GetResource("Animation", "Models/Blockman/Animations/Walking.ani"),
        walk_with_rifle = cache:GetResource("Animation", "Models/Blockman/Animations/WalkWithRifle.ani"),
        run             = cache:GetResource("Animation", "Models/Blockman/Animations/StandardRun.ani"),
        laughing        = cache:GetResource("Animation", "Models/Blockman/Animations/Laughing.ani"),
        talking         = cache:GetResource("Animation", "Models/Blockman/Animations/Talking.ani"),
        talking1        = cache:GetResource("Animation", "Models/Blockman/Animations/Talking1.ani"),
    },
    npc = {}
}


local function GetCoord(node)
    local wp = node.world_position
    return math.floor(wp.z + 6.0) + 1, math.floor(wp.x + 6.0) + 1
end

function m:Init(scene, character, astar)
    self.scene = scene
    self.character = character
    self.astar = astar
    local row, col = GetCoord(character)
    self.char_coord = {row, col}
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
function m:CreateNpc(name, pos, scale, anim_anim, color)
    local node = self.scene:CreateChild(name)
    self.npc[#self.npc + 1] = {node = node, coord = {}, target_coord = {}, path = {}, finish = false}
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
    local animController = node:CreateComponent(AnimationController.id)
    animController:PlayNewExclusive(AnimationParameters(self.anim[anim_anim]):Looped())

    return node
end

function m:UpdatePath(index)
    local npc = self.npc[index]
    local path_list = self.astar:FindPath(npc.coord[1] - 1, npc.coord[2] - 1, self.char_coord[1] - 1, self.char_coord[2] - 1)
    local path = {}
    print(npc.coord[1] - 1, npc.coord[2] - 1)
    print(self.char_coord[1] - 1, self.char_coord[2] - 1)
    for i=3, #path_list, 2 do
        path[#path + 1] = {path_list[i] + 1, path_list[i + 1] + 1}
    end
    npc.path = path
end

local function GetPositionByCoord(row, col)
    return -5.5 + (col - 1), -5.5 + (row - 1)
end

function m:Update(timeStep)
    local row, col = GetCoord(self.character)
    local coord_dirty = false
    if self.char_coord[1] ~= row or self.char_coord[2] ~= col then
        self.char_coord[1] = row
        self.char_coord[2] = col
        coord_dirty = true
    end
    if coord_dirty then
        for index = 1, #self.npc do
            self:UpdatePath(index)
        end
    end
    for index = 1, #self.npc do
        local npc = self.npc[index]
        if not npc.finish and action_manager:GetNumActions(npc.node) == 0 then
            local target = table.remove(npc.path)
            if target then
                npc.target_coord = target
                local pos = npc.node.position
                local px, pz = GetPositionByCoord(target[1], target[2])
                action_manager:AddAction(ActionBuilder():MoveBy(1, math3d.Vector3(px - pos.x, 0, pz - pos.z)):Build(), npc.node)
            end
            if #npc.path == 0 then
                npc.finish = true
            end
        end
    end
end

local fight_count = 0
local unique_pos = {}
function m:OnBossFight(index)
    if fight_count >= 12 then
        return
    end
    if not unique_pos.rows then
        unique_pos.rows = Utils.MultiRandom(1, 12, 12)
        unique_pos.cols = Utils.MultiRandom(1, 12, 12)
    end
    local npc = self.npc[index]
    npc.coord = {unique_pos.rows[index], unique_pos.cols[index]}
    self.char_coord[1], self.char_coord[2] = GetCoord(self.character)
    self:UpdatePath(index)

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
    local animController = npc.node:CreateComponent(AnimationController.id)
    animController:PlayNewExclusive(AnimationParameters(self.anim["rifle_run"]):Looped())

    fight_count = fight_count + 1
end

return m