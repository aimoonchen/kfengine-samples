local m = {
    speed = 4
}
local function item_update(item, delta)
    if not item.active then
        return
    end
    local pos = item.node.position
    local finish = false
    if item.dir == 1 then
        pos.z = pos.z + delta
        if pos.z > item.target_pos then
            finish = true
        end
    elseif item.dir == 2 then
        pos.x = pos.x + delta
        if pos.x > item.target_pos then
            finish = true
        end
    elseif item.dir == 3 then
        pos.z = pos.z - delta
        if pos.z < item.target_pos then
            finish = true
        end
    elseif item.dir == 4 then
        pos.x = pos.x - delta
        if pos.x < item.target_pos then
            finish = true
        end
    end
    if finish then
        item.active = false
        item.node:SetEnabled(false)
    else
        item.node.position = pos
    end
end

function m:Init(scene)
    self.scene = scene
    self.items = {{},{},{},{}}
    local pos = math3d.Vector3(0.0, 0.5, 0.0)
    local item = self.items[1]
    item.node = self:CreateItemNode(pos)
    item.target_pos = 5.5
    item.active = false
    item.dir = 1
    item.node:SetEnabled(false)
    item = self.items[2]
    item.node = self:CreateItemNode(pos)
    item.target_pos = 5.5
    item.active = false
    item.dir = 2
    item.node:SetEnabled(false)
    item = self.items[3]
    item.node = self:CreateItemNode(pos)
    item.target_pos = -5.5
    item.active = false
    item.dir = 3
    item.node:SetEnabled(false)
    item = self.items[4]
    item.node = self:CreateItemNode(pos)
    item.target_pos = -5.5
    item.active = false
    item.dir = 4
    item.node:SetEnabled(false)
end

function m:CreateItemNode(pos)
    local node = self.scene:CreateChild("item")
    node.position = pos
    local object = node:CreateComponent(StaticModel.id)
    local model = cache:GetResource("Model", "Models/Box.mdl")
    object:SetModel(model)
    local mtl = cache:GetResource("Material","Materials/GreenTransparent.xml"):Clone()
    mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(1.0, 1.0, 1.0, 0.5)))
    object:SetMaterial(mtl)
    -- object:SetCastShadows(true)
    return node
end

function m:Start(type, row, col)
    local pos = math3d.Vector3(-5.5, 0.5, -5.5)
    pos.x = pos.x + (col - 1)
    pos.z = pos.z + (row - 1)
    if type & 1 ~= 0 then
        self.items[1].node.position = pos
        self.items[1].active = true
        self.items[1].node:SetEnabled(true)
    end
    if type & 2 ~= 0 then
        self.items[2].node.position = pos
        self.items[2].active = true
        self.items[2].node:SetEnabled(true)
    end
    if type & 4 ~= 0 then
        self.items[3].node.position = pos
        self.items[3].active = true
        self.items[3].node:SetEnabled(true)
    end
    if type & 8 ~= 0 then
        self.items[4].node.position = pos
        self.items[4].active = true
        self.items[4].node:SetEnabled(true)
    end
end
function m:Update(time)
    local delta = time * self.speed
    for _, item in ipairs(self.items) do
        item_update(item, delta)
    end
end
return m