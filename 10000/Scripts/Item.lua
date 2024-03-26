local Map = require "Scripts/Map"
local m = {
    speed = 4
}
local function item_update(item, delta)
    if not item.active then
        return
    end
    local pos = item.node.position
    local finish = false
    local last_coord_row
    local last_coord_col
    if item.dir == 1 then
        pos.z = pos.z + delta
        if pos.z > item.target_pos then
            finish = true
        else
            local new_coord = math.floor(pos.z + 6.0) + 1
            if new_coord ~= item.coord[1] then
                last_coord_row, last_coord_col = item.coord[1], item.coord[2]
                item.coord[1] = new_coord
            end
        end
    elseif item.dir == 2 then
        pos.x = pos.x + delta
        if pos.x > item.target_pos then
            finish = true
        else
            local new_coord = math.floor(pos.x + 6.0) + 1
            if new_coord ~= item.coord[2] then
                last_coord_row, last_coord_col = item.coord[1], item.coord[2]
                item.coord[2] = new_coord
            end
        end
    elseif item.dir == 3 then
        pos.z = pos.z - delta
        if pos.z < item.target_pos then
            finish = true
        else
            local new_coord = math.floor(pos.z + 6.0) + 1
            if new_coord ~= item.coord[1] then
                last_coord_row, last_coord_col = item.coord[1], item.coord[2]
                item.coord[1] = new_coord
            end
        end
    elseif item.dir == 4 then
        pos.x = pos.x - delta
        if pos.x < item.target_pos then
            finish = true
        else
            local new_coord = math.floor(pos.x + 6.0) + 1
            if new_coord ~= item.coord[2] then
                last_coord_row, last_coord_col = item.coord[1], item.coord[2]
                item.coord[2] = new_coord
            end
        end
    end
    if finish then
        item.active = false
        item.node:SetEnabled(false)
        Map:ShowGrid(item.coord[1], item.coord[2], false)
    else
        item.node.position = pos
        if last_coord_row then
            Map:ShowGrid(last_coord_row, last_coord_col, false)
            Map:ShowGrid(item.coord[1], item.coord[2], true)
        end
    end
end

function m:Init(scene)
    self.scene = scene
    self.items = {}
    local pos = math3d.Vector3(0.0, 0.5, 0.0)
    for i = 1, 4 do
        local item = {}
        item.node = self:CreateItemNode(pos)
        item.target_pos = (i > 2) and -5.5 or 5.5
        item.active = false
        item.dir = i
        item.coord = {1,1}
        self.items[#self.items + 1] = item
    end
end

function m:CreateItemNode(pos)
    local node = self.scene:CreateChild("item")
    node.position = pos
    local object = node:CreateComponent(StaticModel.id)
    local model = cache:GetResource("Model", "Models/Box.mdl")
    object:SetModel(model)
    local mtl = cache:GetResource("Material","Materials/GreenTransparent.xml"):Clone()
    mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.0, 1.0, 0.0, 0.5)))
    object:SetMaterial(mtl)
    node:SetEnabled(false)
    return node
end

local function init_item(item, pos, row, col)
    item.node.position = pos
    item.active = true
    item.node:SetEnabled(true)
    item.coord[1], item.coord[2] = row, col
end

function m:Start(type, row, col)
    local pos = math3d.Vector3(-5.5, 0.5, -5.5)
    pos.x = pos.x + (col - 1)
    pos.z = pos.z + (row - 1)
    if type & 1 ~= 0 then
        init_item(self.items[1], pos, row, col)
    end
    if type & 2 ~= 0 then
        init_item(self.items[2], pos, row, col)
    end
    if type & 4 ~= 0 then
        init_item(self.items[3], pos, row, col)
    end
    if type & 8 ~= 0 then
        init_item(self.items[4], pos, row, col)
    end
    Map:ShowGrid(row, col, true)
end

function m:Update(time)
    local delta = time * self.speed
    for _, item in ipairs(self.items) do
        item_update(item, delta)
    end
end

return m