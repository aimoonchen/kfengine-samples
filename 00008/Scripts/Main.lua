local app = {
    running = false,
    MOVE_SPEED = 6.0,
    rmlui_component = {}
}

function app:GetName()
    return "Template"
end

local t_prev_fade = 0
function app:OnUpdate(eventType, eventData)
    local timeStep = eventData[ParamType.P_TIMESTEP]:GetFloat()
    t_prev_fade = t_prev_fade + timeStep
    if self.rmlui_animation and t_prev_fade >= 1.4 then
        local document = self.rmlui_animation:GetDocument()
        local el = document:GetElementById("help")
        if el:IsClassSet("fadeout") then
            el:SetClass("fadeout", false)
            el:SetClass("fadein", true)
        elseif el:IsClassSet("fadein") then
            el:SetClass("fadein", false)
            el:SetClass("textalign", true)
        else
            el:SetClass("textalign", false)
            el:SetClass("fadeout", true)
        end
        t_prev_fade = 0;
    end
end

function app:OnSceneUpdate(eventType, eventData)
end

function app:OnPostUpdate(eventType, eventData)
end

function app:OnPostRenderUpdate(eventType, eventData)
end

function app:UpdateCamera(timeStep)
end

function app:CreateScene(uiscene)
    self.scene = Scene()
    g_scene = self.scene
    local scene = self.scene

    scene:CreateComponent(Octree.id)
    -- local zone = scene:CreateComponent(Zone.id)
    -- zone.bounding_box = math3d.BoundingBox(-500.0, 500.0)
    -- zone.background_brightness = 0.5
    -- zone:SetZoneTextureAttr("Textures/DefaultSkybox.xml")

    -- local skyNode = scene:CreateChild("Sky");
    -- local skybox = skyNode:CreateComponent(Skybox.id)
    -- skybox:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    -- skybox:SetMaterial(cache:GetResource("Material","Materials/DefaultSkybox.xml"))

    -- local planeNode = scene:CreateChild("Plane");
    -- planeNode.scale = math3d.Vector3(100.0, 1.0, 100.0)
    -- local planeObject = planeNode:CreateComponent(StaticModel.id)
    -- planeObject:SetModel(cache:GetResource("Model", "Models/Plane.mdl"))
    -- local mtl = cache:GetResource("Material", "Materials/GridTiled.xml")
    -- mtl:SetShaderParameter("UOffset", Variant(math3d.Vector4(100.0, 0.0, 0.0, 0.0)))
    -- mtl:SetShaderParameter("VOffset", Variant(math3d.Vector4(0.0, 100.0, 0.0, 0.0)))
    -- planeObject:SetMaterial(mtl)

    -- local lightNode = scene:CreateChild("DirectionalLight")
    -- lightNode.direction = math3d.Vector3(0.6, -1.0, 0.8) -- The direction vector does not need to be normalized
    -- local light = lightNode:CreateComponent(Light.id)
    -- light.light_type = LIGHT_DIRECTIONAL
    -- light.color = math3d.Color(0.8, 0.8, 0.8)

    local cameraNode = scene:CreateChild("Camera")
    cameraNode.position = math3d.Vector3(0.0, 5.0, -5.0)
    cameraNode:LookAt(math3d.Vector3(0.0, 0.0, 0.0))
    local camera = cameraNode:CreateComponent(Camera.id)
    camera.near_clip = 0.5
    camera.far_clip = 500.0
    self.camera_node    = cameraNode

    -- rmlui.LoadFont("UI/common/LatoLatin-Bold.ttf", false);
    -- rmlui.LoadFont("UI/common/LatoLatin-BoldItalic.ttf", false);
    -- rmlui.LoadFont("UI/common/LatoLatin-Italic.ttf", false);
    -- rmlui.LoadFont("UI/common/LatoLatin-Regular.ttf", false);
    -- rmlui.LoadFont("UI/common/NotoEmoji-Regular.ttf", true);

    rmlui.LoadFont("Fonts/FZY3JW.TTF", false)
    rmlui.LoadFont("UI/common/NotoEmoji-Regular.ttf", true)
    local uicomp = scene:CreateComponent(RmlUIComponent.id)
    uicomp:SetResource("UI/demo.rml", {})
    -- uicomp:SetResource("UI/animation.rml")
    -- self.rmlui_animation = uicomp
    self.rmlui_component[#self.rmlui_component + 1] = uicomp
end

function app:Load(viewport, uiroot)
    if self.running then
        return
    end
    self.running = true
    if not self.scene then
        self:CreateScene(uiroot)
    end
    for _, comp in ipairs(self.rmlui_component) do
        comp:SetEnabled(true)
    end
    viewport:SetScene(self.scene)
    local camera = self.camera_node:GetComponent(Camera.id)
    viewport:SetCamera(camera)
    Effekseer.SetCamera(camera)
    self:SubscribeToEvents()
end

function app:UnLoad()
    if not self.running then
        return
    end
    for _, comp in ipairs(self.rmlui_component) do
        comp:SetEnabled(false)
    end
    self.running = false
    self:UnSubscribeToEvents()
end

function app:SubscribeToEvents()

end

function app:UnSubscribeToEvents()

end

return app