local Timer = require "Scripts/Timer"
local time_index = 1
local time_name = {"子鼠","丑牛","寅虎","卯兔","辰龙","巳蛇","午马","未羊","申猴","酉鸡","戌狗","亥猪"}
Home = Home or {
    datamodel = rmlui.context:OpenDataModel("HomeData", {
        title = time_name[time_index]
    })
}

local sound_mouseclick1 = "event:/UI/mouseclick1"

function Home.Update(timeStep, document)

end

function Home.OnPostLoad(document)
    --init data
    local comp = rmlui.GetRmlUIComponent(document)
    comp:AddUpdateListener(Home.Update)
    Home.rmlui_omponent = comp
    Home.uicontext = rmlui.uicontext[Home.rmlui_omponent:GetResource()]
    Timer:AddTimer(5, function ()
        Home.datamodel.title = time_name[time_index]
        time_index = time_index < #time_name and time_index + 1 or 1
    end)
end

function Home.OnUnload(document)
    -- rmlui.context:CloseDataModel(Home.datamodel, "HomeData")
end

function Home.OnAttack(event, element)
    -- Home.uicontext.OnUImessage({action="Attack"})
    -- onAttackBtn()
    Audio.Play(sound_mouseclick1)
end