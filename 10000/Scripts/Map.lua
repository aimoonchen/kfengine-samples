local m = {}

function m:Init(scene, start_x)
    self.scene = scene
    local map_color = {math3d.Color(0.25, 0.25, 0.25, 1.0), math3d.Color(0.5, 0.5, 0.5, 1.0)}
    local model = cache:GetResource("Model", "Models/Box.mdl")
    local mtl = cache:GetResource("Material","Materials/DefaultWhite.xml")
    self.map = {}
    for i = 1, 12 do
        local row = {}
        local position = math3d.Vector3(0.0, -0.5, -start_x + (i - 1))
        for j = 1, 12 do
            local map_node = {}
            local node = scene:CreateChild("")
            position.x = -start_x + (j - 1)
            node.position = position
            local object = node:CreateComponent(StaticModel.id)
            object:SetModel(model)
            local new_mtl = mtl:Clone()
            local ci = ((i % 2) == 0) and 1 or 2
            if (j % 2) == 0 then
                if ci > 1 then
                    ci = ci - 1
                else
                    ci = ci + 1
                end
            end
            new_mtl:SetShaderParameter("MatDiffColor", Variant(map_color[ci]))
            object:SetMaterial(new_mtl)
            object:SetCastShadows(true)
            map_node.color = map_color[ci]
            map_node.node = node
            row[#row + 1] = map_node
        end
        self.map[#self.map+1] = row
    end
end

function m:Start(coords)
    if self.last_coords then
        for _, coord in ipairs(self.last_coords) do
            local map_node = self.map[coord[2]][coord[1]]
            local node = map_node.node
            local pos = node.position
            node.position = math3d.Vector3(pos.x, -0.5, pos.z)
            local object = node:GetComponent(StaticModel.id)
            local mtl = object:GetMaterial()
            mtl:SetShaderParameter("MatDiffColor", Variant(map_node.color))
        end
    end
    for _, coord in ipairs(coords) do
        local map_node = self.map[coord[2]][coord[1]]
        action_manager:CancelAllActionsFromTarget(map_node.node)
        local action = ActionBuilder():MoveBy(1.0, math3d.Vector3(0, 1, 0)):Build()
        action_manager:AddAction(action, map_node.node)
        local object = map_node.node:GetComponent(StaticModel.id)
        local mtl = object:GetMaterial()
        mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.0, 0.0, 1.0, 1.0)))
    end
    self.last_coords = coords
end
return m