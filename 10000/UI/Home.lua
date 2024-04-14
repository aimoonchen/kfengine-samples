local Timer = require "Timer"
local time_index = 1
local time_name = {"子时-鼠","丑时-牛","寅时-虎","卯时-兔","辰时-龙","巳时-蛇","午时-马","未时-羊","申时-猴","酉时-鸡","戌时-狗","亥时-猪"}
Home = Home or {
    datamodel = rmlui.context:OpenDataModel("HomeData", {
        title = time_name[time_index],
        time_percent = 0,
    })
}

local sound_mouseclick1 = "event:/UI/mouseclick1"
local time = 0

function Home.Update(timeStep, document)
    time = time + timeStep
    local percent = time / 5
    Home.datamodel.time_percent = (percent > 1) and 1 or percent
end

function Home.OnPostLoad(document)
    --init data
    local comp = rmlui.GetRmlUIComponent(document)
    comp:AddUpdateListener(Home.Update)
    Home.rmlui_omponent = comp
    Home.uicontext = rmlui.uicontext[Home.rmlui_omponent:GetResource()]
    Home.timer = Timer:AddTimer(5, function ()
        Home.datamodel.title = time_name[time_index]
        Home.uicontext.StartChase(time_index)
        time_index = time_index < #time_name and time_index + 1 or 1
        time = 0
    end)
end

function Home.OnUnload(document)
    -- rmlui.context:CloseDataModel(Home.datamodel, "HomeData")
    Timer:DelTimer(Home.timer)
    time_index = 1
    time = 0
end

function Home.OnSpell(event, element)
    local el = event.target_element
    Home.uicontext.OnUImessage({action=el.id})
    if el.id == "Reset" then
        time_index = 1
    end
    -- onAttackBtn()
    Audio.Play(sound_mouseclick1)
end