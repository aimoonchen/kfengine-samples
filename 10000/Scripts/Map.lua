local m = {}

local function create_cube(scene, position, color)
    local node = scene:CreateChild("")
    node.position = position
    local object = node:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local mtl = cache:GetResource("Material","Materials/DefaultWhite.xml"):Clone()
    mtl:SetShaderParameter("MatDiffColor", Variant(color))
    object:SetMaterial(mtl)
    object:SetCastShadows(true)
    return node
end
function m:Init(scene, start_x)
    self.scene = scene
    local map_color = {math3d.Color(0.25, 0.25, 0.25, 1.0), math3d.Color(0.5, 0.5, 0.5, 1.0)}
    self.map = {}
    self.ceil = {}
    for i = 1, 12 do
        local map_row = {}
        local ceil_row = {}
        local position = math3d.Vector3(0.0, -0.5, -start_x + (i - 1))
        for j = 1, 12 do
            position.x = -start_x + (j - 1)
            local ci = ((i % 2) == 0) and 1 or 2
            if (j % 2) == 0 then
                if ci > 1 then
                    ci = ci - 1
                else
                    ci = ci + 1
                end
            end
            map_row[#map_row + 1] = {
                color = map_color[ci],
                node = create_cube(scene, position, map_color[ci])
            }

            local node = create_cube(scene, math3d.Vector3(position.x, position.y + 3.0, position.z), math3d.Color(0.5, 0.0, 0.0, 1.0))
            node:SetEnabled(false)
            ceil_row[#ceil_row + 1] = {
                node = node
            }
        end
        self.map[#self.map+1] = map_row
        self.ceil[#self.ceil+1] = ceil_row
    end
end
function m:Update()
    if self.last_rise_coords then
        local c = self.last_rise_coords[1]
        local cn = self.map[c[1]][c[2]]
        if action_manager:GetNumActions(cn.node) == 0 then
            for _, coord in ipairs(self.last_rise_coords) do
                local map_node = self.map[coord[1]][coord[2]]
                local node = map_node.node
                local pos = node.position
                node.position = math3d.Vector3(pos.x, -0.5, pos.z)
                local object = node:GetComponent(StaticModel.id)
                local mtl = object:GetMaterial()
                mtl:SetShaderParameter("MatDiffColor", Variant(map_node.color))
            end
            self.last_rise_coords = nil
        end
    end
    
    if self.last_fall_coords then
        local c = self.last_fall_coords[1]
        local cn = self.ceil[c[1]][c[2]]
        if action_manager:GetNumActions(cn.node) == 0 then
            for _, coord in ipairs(self.last_fall_coords) do
                local ceil_node = self.ceil[coord[1]][coord[2]]
                local pos = ceil_node.node.position
                ceil_node.node.position = math3d.Vector3(pos.x, pos.y + 2, pos.z)
                ceil_node.node:SetEnabled(false)
            end
            self.last_fall_coords = nil
        end
    end
end
function m:StartRise(coords)
    if self.last_rise_coords then
        return
    end
    for _, coord in ipairs(coords) do
        local map_node = self.map[coord[1]][coord[2]]
        -- action_manager:CancelAllActionsFromTarget(map_node.node)
        local action = ActionBuilder():MoveBy(1.0, math3d.Vector3(0, 1, 0)):ExponentialIn():DelayTime(1.0):JumpBy(math3d.Vector3(0, -1, 0)):Build()
        action_manager:AddAction(action, map_node.node)
        local object = map_node.node:GetComponent(StaticModel.id)
        local mtl = object:GetMaterial()
        mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.0, 0.0, 0.8, 1.0)))
    end
    self.last_rise_coords = coords
end

function m:StartFall(coords)
    if self.last_fall_coords then
        return
    end
    for _, coord in ipairs(coords) do
        local ceil_node = self.ceil[coord[1]][coord[2]]
        ceil_node.node:SetEnabled(true)
        -- action_manager:CancelAllActionsFromTarget(ceil_node.node)
        local action = ActionBuilder():MoveBy(1.0, math3d.Vector3(0.0, -2.0, 0.0)):BackIn():DelayTime(1.0):Build()
        action_manager:AddAction(action, ceil_node.node)
    end
    self.last_fall_coords = coords
end

return m