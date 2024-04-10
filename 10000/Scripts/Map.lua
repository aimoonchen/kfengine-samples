local Timer = require "Timer"
local m = {}

local function create_cube(scene, position, color, translucent)
    local node = scene:CreateChild("")
    node.position = position
    local object = node:CreateComponent(StaticModel.id)
    object:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local mtl = translucent and cache:GetResource("Material","Materials/GreenTransparent.xml"):Clone() or cache:GetResource("Material","Materials/DefaultWhite.xml"):Clone()
    mtl:SetShaderParameter("MatDiffColor", Variant(color))
    object:SetMaterial(mtl)
    object:SetCastShadows(true)
    return node
end

local function create_effect(scene, name, filename, position, scale)
    local emitter = scene:CreateChild(name or "effect")
    emitter.position = position
    emitter.scale = scale or math3d.Vector3.ONE
    local effect = emitter:CreateComponent(EffekseerEmitter.id)
    effect:SetEffect(filename)
    effect:SetLooping(false)
    return effect
end

local function reset_shield(effect)
    effect:Stop()
    local node = effect:GetNode()
    node.position = math3d.Vector3(-5.5 + math.random(0, 11), 0, -5.5 + math.random(0, 11))
    effect:Play()
end

function m:Init(scene, start_x)
    self.grid_alpha_anim = {}
    self.scene = scene
    self.mesh_line = scene:GetComponent(MeshLine.id)
    local grid_linedesc = MeshLineDesc()
    grid_linedesc.width = 4
    grid_linedesc.world_space = false
    grid_linedesc.depth = true
    grid_linedesc.cache = true
    grid_linedesc.color = math3d.Color(1.0, 1.0, 0.0, 0.8)
    grid_linedesc.depth_bias = 0.001
    self.grid_linedesc = grid_linedesc

    local size = 1
    local gap = 0.1
    local round = 0.1
    local map_color = {math3d.Color(0.25, 0.25, 0.25, 1.0), math3d.Color(0.5, 0.5, 0.5, 1.0)}
    self.map = {}
    self.cubes = {}
    self.grids = {}
    for i = 1, 12 do
        local map_row = {}
        local ceil_row = {}
        local grid_row = {}
        local position = math3d.Vector3(0.0, -0.5, -start_x + (i - 1))
        for j = 1, 12 do
            position.x = -start_x + (j - 1)
            -- grid
            local grid = self.mesh_line:AddGrid(1, 1, size, gap, round, grid_linedesc)
            grid.model_mat = math3d.Matrix3x4(math3d.Vector3(position.x, 0.0, position.z), math3d.Quaternion.IDENTITY, 1.0)
            grid.visible = false
            grid_row[#grid_row + 1] = grid

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

            local node = create_cube(scene, math3d.Vector3(position.x, position.y, position.z), math3d.Color(0.5, 0.0, 0.0, 1.0), true)
            node:SetEnabled(false)
            ceil_row[#ceil_row + 1] = {
                node = node,
                color = math3d.Color(0.5, 0.0, 0.0, 1.0)
            }
        end
        self.map[#self.map + 1] = map_row
        self.cubes[#self.cubes + 1] = ceil_row
        self.grids[#self.grids + 1] = grid_row
    end
    local fireball1 = create_effect(scene, "fireball1", "Effekseer/01_Suzuki01/001_magma_effect/aura.efk", math3d.Vector3(-5.5 + 5, 0.5, -5.5 + 5), math3d.Vector3(0.25, 0.25, 0.25))
    local fireball2 = create_effect(scene, "fireball2", "Effekseer/01_Suzuki01/001_magma_effect/aura.efk", math3d.Vector3(-5.5 + 6, 0.5, -5.5 + 6), math3d.Vector3(0.25, 0.25, 0.25))
    local shield1 = create_effect(scene, "shield1", "Effekseer/00_Version16/Barrior01.efk", math3d.Vector3(-5.5 + 4, 0.0, -5.5 + 8), math3d.Vector3(0.15, 0.15, 0.15))
    local shield2 = create_effect(scene, "shield2", "Effekseer/00_Version16/Barrior01.efk", math3d.Vector3(-5.5 + 7, 0.0, -5.5 + 8), math3d.Vector3(0.15, 0.15, 0.15))
    self.effects = {
        fireball1 = fireball1,
        fireball2 = fireball2,
        shield1 = shield1,
        shield2 = shield2,
        flame = create_effect(scene, "flame", "Effekseer/01_Pierre01/Flame.efk", math3d.Vector3(0, 0.5, 0))
    }
    shield1:SetSpeed(0.5)
    shield2:SetSpeed(0.5)
    local action1 = ActionBuilder():MoveBy(2.5, math3d.Vector3(0, 0, -5)):MoveBy(0.5, math3d.Vector3(-1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, 11)):MoveBy(0.5, math3d.Vector3(-1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, -11)):MoveBy(0.5, math3d.Vector3(-1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, 11)):MoveBy(0.5, math3d.Vector3(-1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, -11)):MoveBy(0.5, math3d.Vector3(-1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, 11)):JumpBy(math3d.Vector3(5, 0.0, -6))
        :RepeatForever():Build()
    action_manager:AddAction(action1, fireball1:GetNode())
    local action2 = ActionBuilder():MoveBy(2.5, math3d.Vector3(0, 0, 5)):MoveBy(0.5, math3d.Vector3(1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, -11)):MoveBy(0.5, math3d.Vector3(1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, 11)):MoveBy(0.5, math3d.Vector3(1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, -11)):MoveBy(0.5, math3d.Vector3(1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, 11)):MoveBy(0.5, math3d.Vector3(1, 0, 0))
        :MoveBy(5.0, math3d.Vector3(0, 0, -11)):JumpBy(math3d.Vector3(-5, 0.0, 6))
        :RepeatForever():Build()
    action_manager:AddAction(action2, fireball2:GetNode())
    for _, e in pairs(self.effects) do
        e:Play()
    end
    self.shield_timer = Timer:AddTimer(4, function ()
        reset_shield(self.effects.shield1)
        reset_shield(self.effects.shield2)
    end, 0, 4)
    -- Timer:AddTimer(15, function () self.effects.flame:Play() end, 0, 15)
end

function m:Clean()
    Timer:DelTimer(self.shield_timer)
end

function m:ShowGrid(row, col, visible)
    self.grids[row][col].visible = visible
end

function m:ResetCubes(active_coords)
    if not active_coords then
        return
    end
    local c = active_coords[1]
    local cn = self.cubes[c[1]][c[2]]
    if action_manager:GetNumActions(cn.node) == 0 then
        for _, coord in ipairs(active_coords) do
            local ceil_node = self.cubes[coord[1]][coord[2]]
            ceil_node.node:SetEnabled(false)
            self:ShowGrid(coord[1], coord[2], false)
        end
        return true
    end
end

function m:Update(timeStep)
    if #self.grid_alpha_anim > 0 then
        for i = #self.grid_alpha_anim, 1, -1 do
            local anim = self.grid_alpha_anim[i]
            if anim.counter > 0 then
                anim.current = anim.current + timeStep
                if anim.current >= anim.interval then
                    anim.forward = not anim.forward
                    anim.current = anim.current - anim.interval
                    anim.counter = anim.counter - 1
                end
                if anim.counter == 0 then
                    for _, coord in ipairs(anim.coords) do
                        local grid = self.grids[coord[1]][coord[2]]
                        grid.color = self.grid_linedesc.color
                        grid.visible = false
                        anim.on_finish(coord[1], coord[2])
                    end
                    table.remove(self.grid_alpha_anim, i)
                else
                    for _, coord in ipairs(anim.coords) do
                        local grid = self.grids[coord[1]][coord[2]]
                        local color = self.grid_linedesc.color
                        local alpha = anim.forward and anim.current * 4 or (1 - anim.current * 4)
                        grid.color = math3d.Color(color.r, color.g, color.b, alpha)
                    end
                end
            end
        end
    else
        if self:ResetCubes(self.last_rise_coords) then
            self.last_rise_coords = nil
        end
        if self:ResetCubes(self.last_fall_coords) then
            self.last_fall_coords = nil
        end
    end
end

function m:StartFlame()
    self.effects.flame:Play()
end

function m:do_rise(row, col)
    local ceil_node = self.cubes[row][col]
    local pos = ceil_node.node.position
    ceil_node.node.position = math3d.Vector3(pos.x, -0.5, pos.z)
    ceil_node.node:SetEnabled(true)
    local action = ActionBuilder():MoveBy(1.0, math3d.Vector3(0, 1, 0)):ExponentialIn():DelayTime(1.5):JumpBy(math3d.Vector3(0, -1, 0)):Build()
    action_manager:AddAction(action, ceil_node.node)

    local object = ceil_node.node:GetComponent(StaticModel.id)
    local mtl = object:GetMaterial()
    mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.0, 0.0, 0.8, 1.0)))
    local color_action = ActionBuilder():DelayTime(1.5):ShaderParameterFromTo(1.0, "MatDiffColor", Variant(math3d.Color(0.0, 0.0, 0.8, 1.0)), Variant(math3d.Color(0.0, 0.0, 0.8, 0.0))):Build()
    action_manager:AddAction(color_action, mtl)
end

function m:CreateAlphaAnim(coords, on_finish)
    for _, coord in ipairs(coords) do
        self.grids[coord[1]][coord[2]].visible = true
    end
    self.grid_alpha_anim[#self.grid_alpha_anim + 1] = {
        current = 0,
        counter = 4,
        interval = 0.25, -- 1/counter
        forward = true,
        on_finish = on_finish,
        coords = coords
    }
end

function m:StartRise(coords)
    if self.last_rise_coords then
        return
    end
    self:CreateAlphaAnim(coords, function(row, col) self:do_rise(row, col) end)
    -- for _, coord in ipairs(coords) do
    --     self:do_rise(coord[1], coord[2])
    -- end
    self.last_rise_coords = coords
end

function m:do_fall(row, col)
    local ceil_node = self.cubes[row][col]
    local pos = ceil_node.node.position
    ceil_node.node.position = math3d.Vector3(pos.x, 2.5, pos.z)
    ceil_node.node:SetEnabled(true)
    local action = ActionBuilder():MoveBy(1.0, math3d.Vector3(0.0, -2.0, 0.0)):BackIn():DelayTime(1.5):Build()
    action_manager:AddAction(action, ceil_node.node)

    local object = ceil_node.node:GetComponent(StaticModel.id)
    local mtl = object:GetMaterial()
    mtl:SetShaderParameter("MatDiffColor", Variant(math3d.Color(0.5, 0.0, 0.0, 0.0)))
    local color_action = ActionBuilder():ShaderParameterFromTo(0.5, "MatDiffColor", Variant(math3d.Color(0.5, 0.0, 0.0, 0.0)), Variant(math3d.Color(0.5, 0.0, 0.0, 1.0)))
        :DelayTime(1.5)
        :ShaderParameterFromTo(0.5, "MatDiffColor", Variant(math3d.Color(0.5, 0.0, 0.0, 1.0)), Variant(math3d.Color(0.5, 0.0, 0.0, 0.0)))
        :Build()
    action_manager:AddAction(color_action, mtl)
end

function m:StartFall(coords)
    if self.last_fall_coords then
        return
    end
    self:CreateAlphaAnim(coords, function(row, col) self:do_fall(row, col) end)
    -- for _, coord in ipairs(coords) do
    --     self:do_fall(coord[1], coord[2])
    -- end
    self.last_fall_coords = coords
end

function m:StopEffect()
    for _, e in pairs(self.effects) do
        e:Stop()
    end
end
return m