local city = {
    camera_collision_layer = 2,
    cell_size = 1.0,
    map_size = 1024,
    scale = 1.0,
    node_map = {}
}

function city:get_center_pos(location, size)
    local half_map_size = self.map_size * 0.5
    local half_cell_size = self.cell_size * 0.5
    return (location - half_map_size) * self.cell_size - half_cell_size + ((size - 1) * half_cell_size)
end

local function CreateBuilding(scene, path, scale, name, physics)
    local node = scene:CreateChild(name)
    -- local obstacle = node:CreateComponent(Obstacle.id)
    -- obstacle.radius = node.scale.x
    -- obstacle.height = node.scale.y
    local prefabReference = node:CreateComponent(PrefabReference.id)
    prefabReference:SetPrefab(cache:GetResource("PrefabResource", path))
    prefabReference:InlineConservative()
    local comps = node:GetComponents(StaticModel.id, true)
    local bbox
    for i = 1, #comps do
        local bb = comps[i]:GetWorldBoundingBox()
        if not bbox then
            bbox = bb
        else
            bbox:Merge(bb)
        end
    end
    if physics then
        node:CreateComponent(Navigable.id)
        local body = node:CreateComponent(RigidBody.id)
        body.collision_layer = city.camera_collision_layer
        local shape = node:CreateComponent(CollisionShape.id)
        local sz = bbox:Size()
        shape:SetBox(sz, math3d.Vector3(0, sz.y * 0.5, 0), math3d.Quaternion.IDENTITY)
    end
    node:SetScale(scale)
    return node, math3d.BoundingBox(bbox.min * scale, bbox.max * scale)
end

function city:PlaceBuilding(row, col, node, bbox, height)
    local bboxsize = bbox:Size()
    local size_x = math.ceil(bboxsize.x/self.cell_size)
    local size_z = math.ceil(bboxsize.z/self.cell_size)
    node:SetPosition(self:get_center_pos(col, size_x), height or 0, self:get_center_pos(row, size_z))
    local info = {
        row = row,
        col = col,
        size_x = size_x,
        size_z = size_z,
        offset_x = (self.cell_size - math.fmod(bboxsize.x, self.cell_size)) * 0.5,
        offset_z = (self.cell_size - math.fmod(bboxsize.z, self.cell_size)) * 0.5,
        path = path,
        bbox = bbox,
        scene_node = node,
        children = node:GetChildren(true)
    }
    self.node_map[node.id] = info
    for r = row, size_z do
        for c = col, size_x do
            self.building[r][c] = info
            self.mask[r][c] = false
        end
    end
end
local physic_mtl = {
    aluminum    = { base = math3d.Color(0.960,0.961,0.964,1.0), specular = math3d.Color(0.987,0.991,0.995,1.0), metalness = 1.0 },
    brass       = { base = math3d.Color(0.949,0.901,0.690,1.0), specular = math3d.Color(0.995,0.989,0.928,1.0), metalness = 1.0 },
    gold        = { base = math3d.Color(0.975,0.894,0.645,1.0), specular = math3d.Color(0.999,0.992,0.881,1.0), metalness = 1.0 },
    iron        = { base = math3d.Color(0.755,0.743,0.733,1.0), specular = math3d.Color(0.780,0.761,0.789,1.0), metalness = 1.0 },
    lead        = { base = math3d.Color(0.816,0.813,0.822,1.0), specular = math3d.Color(0.908,0.910,0.937,1.0), metalness = 1.0 },
    silver      = { base = math3d.Color(0.983,0.977,0.965,1.0), specular = math3d.Color(1.000,0.999,0.999,1.0), metalness = 1.0 },
    copper      = { base = math3d.Color(0.967,0.866,0.738,1.0), specular = math3d.Color(0.998,0.981,0.918,1.0), metalness = 1.0 },
    chocolate   = { base = math3d.Color(0.439,0.334,0.272,1.0), metalness = 0.0, ior = 1.5 },
    charcoal    = { base = math3d.Color(0.152,0.152,0.152,1.0), metalness = 0.0, ior = 1.5 },
    bone        = { base = math3d.Color(0.903,0.903,0.835,1.0), metalness = 0.0, ior = 1.5 },
    brick       = { base = math3d.Color(0.549,0.341,0.274,1.0), metalness = 0.0, ior = 1.5 },
    concrete    = { base = math3d.Color(0.742,0.742,0.742,1.0), metalness = 0.0, ior = 1.5 },
    sand        = { base = math3d.Color(0.694,0.655,0.518,1.0), metalness = 0.0, ior = 1.5 },
    snow        = { base = math3d.Color(0.931,0.931,0.931,1.0), metalness = 0.0, ior = 1.3098 },
    milk        = { base = math3d.Color(0.914,0.913,0.844,1.0), metalness = 0.0, ior = 1.348 },
}
local physic_mtl_linear = {
    aluminum    = { base = math3d.Color(0.912,0.914,0.920,1.0), specular = math3d.Color(0.970,0.979,0.988,1.0), metalness = 1.0 },
    brass       = { base = math3d.Color(0.887,0.789,0.434,1.0), specular = math3d.Color(0.988,0.976,0.843,1.0), metalness = 1.0 },
    gold        = { base = math3d.Color(0.944,0.776,0.373,1.0), specular = math3d.Color(0.998,0.981,0.751,1.0), metalness = 1.0 },
    iron        = { base = math3d.Color(0.531,0.512,0.496,1.0), specular = math3d.Color(0.571,0.540,0.586,1.0), metalness = 1.0 },
    lead        = { base = math3d.Color(0.632,0.626,0.641,1.0), specular = math3d.Color(0.803,0.808,0.862,1.0), metalness = 1.0 },
    silver      = { base = math3d.Color(0.962,0.949,0.922,1.0), specular = math3d.Color(0.999,0.998,0.998,1.0), metalness = 1.0 },
    copper      = { base = math3d.Color(0.926,0.721,0.504,1.0), specular = math3d.Color(0.996,0.957,0.823,1.0), metalness = 1.0 },
    chocolate   = { base = math3d.Color(0.162,0.091,0.060,1.0), metalness = 0.0, ior = 1.5 },
    charcoal    = { base = math3d.Color(0.020,0.020,0.020,1.0), metalness = 0.0, ior = 1.5 },
    bone        = { base = math3d.Color(0.793,0.793,0.664,1.0), metalness = 0.0, ior = 1.5 },
    brick       = { base = math3d.Color(0.262,0.095,0.061,1.0), metalness = 0.0, ior = 1.5 },
    concrete    = { base = math3d.Color(0.510,0.510,0.510,1.0), metalness = 0.0, ior = 1.5 },
    sand        = { base = math3d.Color(0.440,0.386,0.231,1.0), metalness = 0.0, ior = 1.5 },
    snow        = { base = math3d.Color(0.850,0.850,0.850,1.0), metalness = 0.0, ior = 1.3098 },
    milk        = { base = math3d.Color(0.815,0.813,0.682,1.0), metalness = 0.0, ior = 1.348 },
}
local function iorToF0(transmittedIor, incidentIor)
    local value = (transmittedIor - incidentIor) / (transmittedIor + incidentIor)
    return value * value
end
function city:CreateProgramModel(material, pos, name)
    local node = self.scene:CreateChild(name)
    node.position = pos
    local object = node:CreateComponent(StaticModel.id)
    object:SetModel(Model.CreateRock(math.floor(math3d.Random(1000)), math.floor(5)))
    local mtl = cache:GetResource("Material", "Materials/Constant/MetallicR5.xml"):Clone()
    mtl:SetShaderParameter("MatDiffColor", Variant(material.base))
    mtl:SetShaderParameter("MatSpecColor", Variant(material.specular or math3d.Color(0,0,0,0)))
    -- TODO:fix web bug
    -- mtl:SetShaderParameter("Roughness", Variant(material.roughness or 0.0))
    -- -- mtl:SetShaderParameter("DielectricReflectance", Variant(material.ior and iorToF0(math.max(1.0, material.ior), 1.0) or 0.0))
    -- mtl:SetShaderParameter("Metallic", Variant(material.metalness or 0.0))
    object:SetMaterial(mtl)
    object:SetCastShadows(true)
    return node
end

function city:Init(scene)
    self.scene = scene
    self.mesh_line = scene:GetComponent(MeshLine.id)
    local mask = {}
    local building = {}
    for r = 1, self.map_size do
        local rm = {}
        local rb = {}
        for c = 1, self.map_size do
            rm[#rm + 1] = true
            rb[#rb + 1] = {}
        end
        mask[#mask + 1] = rm
        building[#building + 1] = rb
    end
    self.mask = mask
    self.building = building
    local car_scale = 8
    local node, bbox = CreateBuilding(self.scene, "Models/Roads/road_roundabout.glb/Prefab.prefab", car_scale, "road_roundabout", false)
    self:PlaceBuilding(501, 501, node, bbox)
    node, bbox = CreateBuilding(self.scene, "Models/Roads/light_curvedCross.glb/Prefab.prefab", 10, "light_curvedCross", false)
    self:PlaceBuilding(511, 511, node, bbox)
    local south_gate_col
    for i = 1, 20 do
        local node, bbox
        if i == 9 then
            south_gate_col = 525 + (i - 1) * car_scale
            node, bbox = CreateBuilding(self.scene, "Models/Roads/road_intersection.glb/Prefab.prefab", car_scale, "road_intersection", false)
            node:SetRotation(0, 180, 0)
        else
            node, bbox = CreateBuilding(self.scene, "Models/Roads/road_straight.glb/Prefab.prefab", car_scale, "road_straight_r"..i, false)
        end
        self:PlaceBuilding(509, 525 + (i - 1) * car_scale, node, bbox)
        node, bbox = CreateBuilding(self.scene, "Models/Roads/road_straight.glb/Prefab.prefab", car_scale, "road_straight_l"..i, false)
        self:PlaceBuilding(509, 493 - (i - 1) * car_scale, node, bbox)

        if i == 4 or i == 8 or i == 12 then
            node, bbox = CreateBuilding(self.scene, "Models/Roads/light_curved.glb/Prefab.prefab", car_scale, "light_curved", false)
            node.rotation = math3d.Quaternion(0, 180, 0)
            self:PlaceBuilding(516, 525 + (i - 1) * car_scale, node, bbox)
            node, bbox = CreateBuilding(self.scene, "Models/Roads/light_curved.glb/Prefab.prefab", car_scale, "light_curved", false)
            node.rotation = math3d.Quaternion(0, 180, 0)
            self:PlaceBuilding(516, 493 - (i - 1) * car_scale, node, bbox)
            --
            node, bbox = CreateBuilding(self.scene, "Models/Roads/light_curved.glb/Prefab.prefab", car_scale, "light_curved", false)
            self:PlaceBuilding(508, 525 + (i - 1) * car_scale, node, bbox)
            node, bbox = CreateBuilding(self.scene, "Models/Roads/light_curved.glb/Prefab.prefab", car_scale, "light_curved", false)
            self:PlaceBuilding(508, 493 - (i - 1) * car_scale, node, bbox)
        end
    end
    local west_gate_row
    for i = 1, 20 do
        local node, bbox
        if i == 6 then
            west_gate_row = 525 + (i - 1) * car_scale
            node, bbox = CreateBuilding(self.scene, "Models/Roads/road_intersection.glb/Prefab.prefab", car_scale, "road_intersection"..i, false)
            node:SetRotation(0, 270, 0)
        else
            node, bbox = CreateBuilding(self.scene, "Models/Roads/road_straight.glb/Prefab.prefab", car_scale, "road_straight_t"..i, false)
            node:SetRotation(0, 90, 0)
        end
        self:PlaceBuilding(525 + (i - 1) * car_scale, 509, node, bbox)
        node, bbox = CreateBuilding(self.scene, "Models/Roads/road_straight.glb/Prefab.prefab", car_scale, "road_straight_b"..i, false)
        node:SetRotation(0, 90, 0)
        self:PlaceBuilding(493 - (i - 1) * car_scale, 509, node, bbox)

        if i == 4 or i == 8 or i == 12 then
            node, bbox = CreateBuilding(self.scene, "Models/Roads/light_curved.glb/Prefab.prefab", car_scale, "light_curved", false)
            node.rotation = math3d.Quaternion(0, 90, 0)
            self:PlaceBuilding(525 + (i - 1) * car_scale, 508, node, bbox)
            node, bbox = CreateBuilding(self.scene, "Models/Roads/light_curved.glb/Prefab.prefab", car_scale, "light_curved", false)
            node.rotation = math3d.Quaternion(0, 90, 0)
            self:PlaceBuilding(493 - (i - 1) * car_scale, 508, node, bbox)
            --
            node, bbox = CreateBuilding(self.scene, "Models/Roads/light_curved.glb/Prefab.prefab", car_scale, "light_curved", false)
            node.rotation = math3d.Quaternion(0, -90, 0)
            self:PlaceBuilding(525 + (i - 1) * car_scale, 517, node, bbox)
            node, bbox = CreateBuilding(self.scene, "Models/Roads/light_curved.glb/Prefab.prefab", car_scale, "light_curved", false)
            node.rotation = math3d.Quaternion(0, -90, 0)
            self:PlaceBuilding(493 - (i - 1) * car_scale, 517, node, bbox)
        end
    end

    ---[[
    local city_buildings = {
        {
            --small
            "Models/Buildings/small_buildingA.glb/Prefab.prefab",
            "Models/Buildings/small_buildingB.glb/Prefab.prefab",
            "Models/Buildings/small_buildingC.glb/Prefab.prefab",
            "Models/Buildings/small_buildingD.glb/Prefab.prefab",
            "Models/Buildings/small_buildingE.glb/Prefab.prefab",
            "Models/Buildings/small_buildingF.glb/Prefab.prefab",
        },
        {
            --large
            "Models/Buildings/large_buildingA.glb/Prefab.prefab",
            "Models/Buildings/large_buildingB.glb/Prefab.prefab",
            "Models/Buildings/large_buildingC.glb/Prefab.prefab",
            "Models/Buildings/large_buildingD.glb/Prefab.prefab",
            "Models/Buildings/large_buildingE.glb/Prefab.prefab",
            "Models/Buildings/large_buildingF.glb/Prefab.prefab",
            "Models/Buildings/large_buildingG.glb/Prefab.prefab",
        },
        {
            --low
            "Models/Buildings/low_buildingA.glb/Prefab.prefab",
            "Models/Buildings/low_buildingB.glb/Prefab.prefab",
            "Models/Buildings/low_buildingC.glb/Prefab.prefab",
            "Models/Buildings/low_buildingD.glb/Prefab.prefab",
            "Models/Buildings/low_buildingE.glb/Prefab.prefab",
            "Models/Buildings/low_buildingF.glb/Prefab.prefab",
            "Models/Buildings/low_buildingG.glb/Prefab.prefab",
            "Models/Buildings/low_buildingH.glb/Prefab.prefab",
            "Models/Buildings/low_buildingI.glb/Prefab.prefab",
            "Models/Buildings/low_buildingJ.glb/Prefab.prefab",
            "Models/Buildings/low_buildingK.glb/Prefab.prefab",
            "Models/Buildings/low_buildingL.glb/Prefab.prefab",
            "Models/Buildings/low_buildingM.glb/Prefab.prefab",
            "Models/Buildings/low_buildingN.glb/Prefab.prefab",
        },
        {
            --skyscraper
            "Models/Buildings/skyscraperA.glb/Prefab.prefab",
            "Models/Buildings/skyscraperB.glb/Prefab.prefab",
            "Models/Buildings/skyscraperC.glb/Prefab.prefab",
            "Models/Buildings/skyscraperD.glb/Prefab.prefab",
            "Models/Buildings/skyscraperE.glb/Prefab.prefab",
            "Models/Buildings/skyscraperF.glb/Prefab.prefab",
        },
    }
    local maxz = 0
    local row_center, col_center = 0, 592
    local start_row, start_col = 520, 0
    local gapcol = 4 * self.cell_size
    local gaprow = 10 * self.cell_size
    for i = 1, #city_buildings do
        start_col = col_center + 7
        maxz = 0
        local count = #city_buildings[i]
        local midcol = math.ceil(count / 2)
        for j = 1, count do
            local nd, bbox = CreateBuilding(self.scene, city_buildings[i][j], 10, "building"..i..j, true)
            nd:AddTag("building")
            local bboxsize = bbox:Size()
            local sizex = math.ceil(bboxsize.x/self.cell_size)
            local sizez = math.ceil(bboxsize.z/self.cell_size)
            maxz = (sizez > maxz) and sizez or maxz
            if j <= midcol then
                self:PlaceBuilding(start_row, start_col, nd, bbox)
                if j == midcol then
                    start_col = col_center - 6 -- col: 128|129, 6 cell for road 512 + 256
                else
                    start_col = start_col + sizex + gapcol
                end
            else
                start_col = start_col - sizex
                self:PlaceBuilding(start_row, start_col, nd, bbox)
                start_col = start_col - gapcol
            end
        end
        start_row = start_row + maxz + gaprow + (i == 2 and 8 or 0)
    end
    --]]
    node, bbox = CreateBuilding(self.scene, "Models/Roads/road_crossroad.glb/Prefab.prefab", car_scale, "road_crossroad", false)
    self:PlaceBuilding(west_gate_row, south_gate_col, node, bbox)
    for i = 1, 15 do
        local col = 517 + (i - 1) * car_scale
        if col ~= south_gate_col then
            node, bbox = CreateBuilding(self.scene, "Models/Roads/road_straight.glb/Prefab.prefab", car_scale, "road_straight", false)
            self:PlaceBuilding(west_gate_row, col, node, bbox)
        end
    end
    for i = 1, 15 do
        local row = 517 + (i - 1) * car_scale
        if row ~= west_gate_row then
            node, bbox = CreateBuilding(self.scene, "Models/Roads/road_straight.glb/Prefab.prefab", car_scale, "road_straight", false)
            node:SetRotation(0, 90, 0)
            self:PlaceBuilding(row, south_gate_col, node, bbox)
        end
    end
    ---[[urban
    local urban_buildings = {
        "Models/Urban/house_type01.glb/Prefab.prefab",
        "Models/Urban/house_type02.glb/Prefab.prefab",
        "Models/Urban/house_type03.glb/Prefab.prefab",
        "Models/Urban/house_type04.glb/Prefab.prefab",
        "Models/Urban/house_type05.glb/Prefab.prefab",
        "Models/Urban/house_type06.glb/Prefab.prefab",
        "Models/Urban/house_type07.glb/Prefab.prefab",
        "Models/Urban/house_type08.glb/Prefab.prefab",
        "Models/Urban/house_type09.glb/Prefab.prefab",
        "Models/Urban/house_type10.glb/Prefab.prefab",
        "Models/Urban/house_type11.glb/Prefab.prefab",
        "Models/Urban/house_type12.glb/Prefab.prefab",
        "Models/Urban/house_type13.glb/Prefab.prefab",
        "Models/Urban/house_type14.glb/Prefab.prefab",
        "Models/Urban/house_type15.glb/Prefab.prefab",
        "Models/Urban/house_type16.glb/Prefab.prefab",
        "Models/Urban/house_type17.glb/Prefab.prefab",
        "Models/Urban/house_type18.glb/Prefab.prefab",
        "Models/Urban/house_type19.glb/Prefab.prefab",
        "Models/Urban/house_type20.glb/Prefab.prefab",
        "Models/Urban/house_type21.glb/Prefab.prefab",
    }
    start_row, start_col = 520, 400
    local dim = 22
    for i = 1, 4 do
        for j = 1, 5 do
            node, bbox = CreateBuilding(self.scene, urban_buildings[(i - 1) * 5 + j], 10, "urban"..i..j, true)
            node:AddTag("building")
            self:PlaceBuilding(start_row + (i - 1) * dim, (start_col + (j - 1) * dim), node, bbox)
        end
    end
    --]]
    self.gold = self:CreateProgramModel(physic_mtl_linear.gold, math3d.Vector3(0, 8, 0), "gold")
    self.gold:AddTag("outline")
    --
    self.cars = {
        ambulance           = { path = "Models/Cars/ambulance.glb/Prefab.prefab" },
        truck               = { path = "Models/Cars/truck.glb/Prefab.prefab" },
        firetruck           = { path = "Models/Cars/firetruck.glb/Prefab.prefab" },
        truck_flat          = { path = "Models/Cars/truckFlat.glb/Prefab.prefab" },
        police              = { path = "Models/Cars/police.glb/Prefab.prefab" },
        van                 = { path = "Models/Cars/van.glb/Prefab.prefab" },
        tractor_police      = { path = "Models/Cars/tractorPolice.glb/Prefab.prefab" },
        -- tractor             = { path = "Models/Cars/tractor.glb/Prefab.prefab" },
        -- sedan_sports        = { path = "Models/Cars/sedanSports.glb/Prefab.prefab" },
        -- suv                 = { path = "Models/Cars/suv.glb/Prefab.prefab" },
        -- delivery_flat       = { path = "Models/Cars/deliveryFlat.glb/Prefab.prefab" },
        -- tractor_shovel      = { path = "Models/Cars/tractorShovel.glb/Prefab.prefab" },
        -- sedan               = { path = "Models/Cars/sedan.glb/Prefab.prefab" },
        -- suv_luxury          = { path = "Models/Cars/suvLuxury.glb/Prefab.prefab" },
        -- garbage_truck       = { path = "Models/Cars/garbageTruck.glb/Prefab.prefab" },
        -- taxi                = { path = "Models/Cars/taxi.glb/Prefab.prefab" },
        -- race                = { path = "Models/Cars/race.glb/Prefab.prefab" },
        -- race_future         = { path = "Models/Cars/raceFuture.glb/Prefab.prefab" },
        -- delivery            = { path = "Models/Cars/delivery.glb/Prefab.prefab" },
        -- hatchback_sports    = { path = "Models/Cars/hatchbackSports.glb/Prefab.prefab" },
    }
    local i = 1
    self.cars_array = {}
    for k, v in pairs(self.cars) do
        node, bbox = CreateBuilding(self.scene, v.path, 2, k, false)
        node:AddTag("car")
        v.node = node
        -- if i > 10 then
        --     self:PlaceBuilding(492, (520 + (i - 11) * 6), node, bbox)
        -- else
        --     self:PlaceBuilding(502, (520 + (i - 1) * 6), node, bbox)
        -- end
        -- i = i + 1
        node.position = math3d.Vector3(2.0, 0, 150.0)
        self.cars_array[#self.cars_array + 1] = node
    end
    self.current_car_id = 1
    self.scene:GetComponent(DynamicNavigationMesh.id):Build()
    self:CreateCar()
end
function city:CreateCar()
    local speed = 15
    local straight = 142
    local radius = 6
    local straight_time = straight / speed
    local radius_time0 = 0.8
    local radius_time1 = 0.8
    if not self.dispatch_time then
        self.dispatch_time = 0
        self.dispatch_count = #self.cars_array
        self.dispatch_interval_time = (0.2 * 16 + straight_time * 8 + radius_time0 * 4 + radius_time1 * 4) / self.dispatch_count
    end
    local node = self.cars_array[self.current_car_id]
    -- node.position = math3d.Vector3(2.0, 0, 150.0)
    action_manager:AddAction(
        ActionBuilder():
        MoveBy(straight_time, math3d.Vector3(0, 0, -straight)):
        RotateBy(0.2, math3d.Quaternion(0, -45, 0)):MoveBy(radius_time0, math3d.Vector3(radius, 0, -radius)):RotateBy(0.2, math3d.Quaternion(0, -45, 0)):
        MoveBy(straight_time, math3d.Vector3(straight, 0, 0)):
        RotateBy(0.2, math3d.Quaternion(0, 90, 0)):MoveBy(radius_time1, math3d.Vector3(0, 0, -4)):RotateBy(0.2, math3d.Quaternion(0, 90, 0)):
        MoveBy(straight_time, math3d.Vector3(-straight, 0, 0)):
        RotateBy(0.2, math3d.Quaternion(0, -45, 0)):MoveBy(radius_time0, math3d.Vector3(-radius, 0, -radius)):RotateBy(0.2, math3d.Quaternion(0, -45, 0)):
        MoveBy(straight_time, math3d.Vector3(0, 0, -straight)):
        RotateBy(0.2, math3d.Quaternion(0, 90, 0)):MoveBy(radius_time1, math3d.Vector3(-4, 0, 0)):RotateBy(0.2, math3d.Quaternion(0, 90, 0)):
        MoveBy(straight_time, math3d.Vector3(0, 0, straight)):
        RotateBy(0.2, math3d.Quaternion(0, -45, 0)):MoveBy(radius_time0, math3d.Vector3(-radius, 0, radius)):RotateBy(0.2, math3d.Quaternion(0, -45, 0)):
        MoveBy(straight_time, math3d.Vector3(-straight, 0, 0)):
        RotateBy(0.2, math3d.Quaternion(0, 90, 0)):MoveBy(radius_time1, math3d.Vector3(0, 0, 4)):RotateBy(0.2, math3d.Quaternion(0, 90, 0)):
        MoveBy(straight_time, math3d.Vector3(straight, 0, 0)):
        RotateBy(0.2, math3d.Quaternion(0, -45, 0)):MoveBy(radius_time0, math3d.Vector3(radius, 0, radius)):RotateBy(0.2, math3d.Quaternion(0, -45, 0)):
        MoveBy(straight_time, math3d.Vector3(0, 0, straight)):
        RotateBy(0.2, math3d.Quaternion(0, 90, 0)):MoveBy(radius_time1, math3d.Vector3(4, 0, 0)):RotateBy(0.2, math3d.Quaternion(0, 90, 0)):
        RepeatForever():Build(),
        node
    )
    self.current_car_id = self.current_car_id + 1
end

local rotation_speed = math3d.Vector3(10.0, 20.0, 30.0)
function city:Update(timeStep)
    if not self.scene then
        return
    end
    if self.current_car_id <= self.dispatch_count then
        self.dispatch_time = self.dispatch_time + timeStep
        if self.dispatch_time >= self.dispatch_interval_time then
            self:CreateCar()
            self.dispatch_time = 0
        end
    end
    self.gold:Rotate(rotation_speed.x * timeStep, rotation_speed.y * timeStep, rotation_speed.z * timeStep)
end

function city:GetGrid(row, col)
    local key = row..col
    if not self.grids then
        self.grids = {}
    end
    if not self.grids[key] then
        if not self.grid_linedesc then
            local grid_linedesc = MeshLineDesc()
            grid_linedesc.width = 8
            grid_linedesc.attenuation = false
            grid_linedesc.depth = true
            grid_linedesc.cache = true
            grid_linedesc.color = math3d.Color(0.0, 1.0, 0.0, 0.5)
            grid_linedesc.depth_bias = 0.05
            self.grid_linedesc = grid_linedesc
        end
        local size = 1
        local gap = 0.1
        local round = 0.1
        self.grids[key] = self.mesh_line:AddGrid(row, col, size, gap, round, self.grid_linedesc)
    end
    return self.grids[key]
end

function city:OnClick(node)
    if not node or not node:HasTag("building") then
        if self.selected_building then
            self.selected_building.grid.visible = false
            self.selected_building = nil
        end
        return
    end
    local building = self.node_map[node.id]
    if building then
        if self.selected_building == building then
            return
        end
        if not building.grid then
            building.grid = self:GetGrid(building.size_z, building.size_x)
        end
        building.grid.model_mat = math3d.Matrix3x4(node.world_position, math3d.Quaternion.IDENTITY, 1.0)
        building.grid.visible = true
        if self.selected_building then
            self.selected_building.grid.visible = false
        end
        self.selected_building = building
    end
end

return city