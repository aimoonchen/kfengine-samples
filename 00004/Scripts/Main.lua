local app = {
    running = false,
}
function app:GetName()
    return "FairyGUI"
end

function AddCloseButton(groot, onClose)
    local closeButton = FairyGUI.UIPackage.CreateObject("MainMenu", "CloseButton");
    if closeButton then
        closeButton:SetPosition(groot:GetWidth() - closeButton:GetWidth() - 10, groot:GetHeight() - closeButton:GetHeight() - 10)
        closeButton:AddRelation(groot, FairyGUI.RelationType.Right_Right)
        closeButton:AddRelation(groot, FairyGUI.RelationType.Bottom_Bottom)
        closeButton:SetSortingOrder(100000)
        closeButton:AddClickListener(onClose)
        groot:AddChild(closeButton);
    end
end
local BasicsScene = {}
local BagScene = {}
local TransitionDemoScene = {}
local VirtualListScene = {}
local LoopListScene = {}
local HitTestScene = {}
local PullToRefreshScene = {}
local ModalWaitingScene = {}
local ChatScene = {}
local ListEffectScene = {}
local ScrollPaneScene = {}
local TreeViewScene = {}
local GuideScene = {}
local CooldownScene = {}
local MenuScene = {}

function MenuScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/MainMenu")
    local view = FairyGUI.UIPackage.CreateObject("MainMenu", "Main")
    self.scene.groot:AddChild(view)
    view:GetChild("n1"):AddClickListener(function (event) FairyGUI.ReplaceScene(BasicsScene:Create()) end)
    view:GetChild("n2"):AddClickListener(function (event) FairyGUI.ReplaceScene(TransitionDemoScene:Create()) end)
    --view:GetChild("n4"):AddClickListener(function (event) FairyGUI.ReplaceScene(VirtualListScene:Create()) end)
    view:GetChild("n5"):AddClickListener(function (event) FairyGUI.ReplaceScene(LoopListScene:Create()) end)
    view:GetChild("n6"):AddClickListener(function (event) FairyGUI.ReplaceScene(HitTestScene:Create()) end)
    view:GetChild("n7"):AddClickListener(function (event) FairyGUI.ReplaceScene(PullToRefreshScene:Create()) end)
    view:GetChild("n8"):AddClickListener(function (event) FairyGUI.ReplaceScene(ModalWaitingScene:Create()) end)
    -- view:GetChild("n9"):AddClickListener(function (event) CreateJoystickScene() end)
    view:GetChild("n10"):AddClickListener(function (event) FairyGUI.ReplaceScene(BagScene:Create()) end)
    view:GetChild("n11"):AddClickListener(function (event) FairyGUI.ReplaceScene(ChatScene:Create()) end)
    view:GetChild("n12"):AddClickListener(function (event) FairyGUI.ReplaceScene(ListEffectScene:Create()) end)
    view:GetChild("n13"):AddClickListener(function (event) FairyGUI.ReplaceScene(ScrollPaneScene:Create()) end)
    view:GetChild("n14"):AddClickListener(function (event) FairyGUI.ReplaceScene(TreeViewScene:Create()) end)
    view:GetChild("n15"):AddClickListener(function (event) FairyGUI.ReplaceScene(GuideScene:Create()) end)
    view:GetChild("n16"):AddClickListener(function (event) FairyGUI.ReplaceScene(CooldownScene:Create()) end)
    local title = FairyGUI.CreateText(app:GetName())
    title:SetFontSize(24)
    title:SetColor(255, 100, 0)
    title:SetPosition(568 - title:GetSize().x / 2, 25)
    view:AddChild(title)
    AddCloseButton(self.scene.groot, function() g_game_return = true end)
    return self.scene
end

local function ReturnMenu(event)
    FairyGUI.ReplaceScene(MenuScene:Create())
end

function TransitionDemoScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/Transition")
    local view = FairyGUI.UIPackage.CreateObject("Transition", "Main")
    self.scene.groot:AddChild(view)
    local groot = self.scene.groot
    local btnGroup = view:GetChild("g0")

    local g1 = FairyGUI.UIPackage.CreateObject("Transition", "BOSS")
    local g2 = FairyGUI.UIPackage.CreateObject("Transition", "BOSS_SKILL")
    local g3 = FairyGUI.UIPackage.CreateObject("Transition", "TRAP")
    local g4 = FairyGUI.UIPackage.CreateObject("Transition", "GoodHit")
    local g5 = FairyGUI.UIPackage.CreateObject("Transition", "PowerUp")
    g5:GetTransition("t0"):SetHook("play_num_now", function()
        FairyGUI.GTween.To(self.startValue, self.endValue, 0.3):OnUpdate(function(tweener)
            g5:GetChild("value"):SetText(tostring(math.floor(tweener:value().x)))
        end)
    end)
    local g6 = FairyGUI.UIPackage.CreateObject("Transition", "PathDemo")
    local play = function(target)
        btnGroup:SetVisible(false)
        groot:AddChild(target)
        target:GetTransition("t0"):Play(function()
            btnGroup:SetVisible(true)
            groot:RemoveChild(target)
        end)
    end
    view:GetChild("btn0"):AddClickListener(function (context) play(g1) end)
    view:GetChild("btn1"):AddClickListener(function (context) play(g2) end)
    view:GetChild("btn2"):AddClickListener(function (context) play(g3) end)
    view:GetChild("btn3"):AddClickListener(function (context)
        btnGroup:SetVisible(false)
        g4:SetPosition(groot:GetWidth() - g4:GetWidth() - 20, 100)
        groot:AddChild(g4)
        g4:GetTransition("t0"):Play(3, 0, function()
            btnGroup:SetVisible(true)
            groot:RemoveChild(g4)
        end)
    end)
    view:GetChild("btn4"):AddClickListener(function (context)
        btnGroup:SetVisible(false)
        g5:SetPosition(20, groot:GetHeight() - g5:GetHeight() - 100)
        groot:AddChild(g5)
        local startValue = 10000
        local add = 1000 + math3d.Random(0, 1) * 2000
        self.endValue = startValue + add
        self.startValue = startValue
        g5:GetChild("value"):SetText(tostring(startValue))
        g5:GetChild("add_value"):SetText(tostring(add))
        g5:GetTransition("t0"):Play(function()
            btnGroup:SetVisible(true)
            groot:RemoveChild(g5)
        end)
    end)
    view:GetChild("btn5"):AddClickListener(function (context) play(g6) end)
    
    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function HitTestScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/HitTest")
    local view = FairyGUI.UIPackage.CreateObject("HitTest", "Main")
    self.scene.groot:AddChild(view)

    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function ModalWaitingScene:Create()
    FairyGUI.SetUIConfig({
        globalModalWaiting = "ui://ModalWaiting/GlobalModalWaiting",
        windowModalWaiting = "ui://ModalWaiting/WindowModalWaiting"
    })
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/ModalWaiting")
    local view = FairyGUI.UIPackage.CreateObject("ModalWaiting", "Main")
    self.scene.groot:AddChild(view)

    local testWin = FairyGUI.Window.Create();
    testWin:SetContentPane(FairyGUI.UIPackage.CreateObject("ModalWaiting", "TestWin"))
    testWin:GetContentPane():GetChild("n1"):AddClickListener(function(event)
        testWin:ShowModalWait();
        self.scene:ScheduleOnce(function(dt) testWin:CloseModalWait() end, 3, "wait")
    end)
    view:GetChild("n0"):AddClickListener(function(event) testWin:Show() end)
    self.scene.groot:ShowModalWait()
    self.scene:ScheduleOnce(function(dt) self.scene.groot:CloseModalWait() end, 3, "wait")

    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function PullToRefreshScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/PullToRefresh")
    local view = FairyGUI.UIPackage.CreateObject("PullToRefresh", "Main")
    self.scene.groot:AddChild(view)

    local list1 = view:GetChild("list1")
    list1:SetItemRenderer(function (index, obj)
        obj:SetText("Item ".. (list1:GetNumItems() - index - 1))
    end)
    list1:SetVirtual()
    list1:SetNumItems(1)
    local header = list1:GetScrollPane():GetHeader()
    local c1 = header:GetController("c1")
    header:AddEventListener(FairyGUI.EventType.SizeChange, function (event)
        if c1:GetSelectedIndex() == 2 or c1:GetSelectedIndex() == 3 then
            return
        end
        if header:GetHeight() > header:GetSourceSize().y then
            c1:SetSelectedIndex(1)
        else
            c1:SetSelectedIndex(0)
        end
    end)
    list1:AddEventListener(FairyGUI.EventType.PullDownRelease, function (event)
        if c1:GetSelectedIndex() ~= 1 then
            return
        end
        c1:SetSelectedIndex(2)
        list1:GetScrollPane():LockHeader(header:GetSourceSize().y)

        self.scene:ScheduleOnce(function(dt)
            list1:SetNumItems(list1:GetNumItems() + 5)
            c1:SetSelectedIndex(3)
            list1:GetScrollPane():LockHeader(35)
            self.scene:ScheduleOnce(function(dt)
                c1:SetSelectedIndex(0)
                list1:GetScrollPane():LockHeader(0)
            end, 2, "pull_down2")
        end, 2, "pull_down1")
    end)

    local list2 = view:GetChild("list2")
    list2:SetItemRenderer(function (index, obj)
        obj:SetText("Item " .. index)
    end)
    list2:SetVirtual()
    list2:SetNumItems(1)
    list2:AddEventListener(FairyGUI.EventType.PullUpRelease, function (event)
        local footer = list2:GetScrollPane():GetFooter()
        footer:GetController("c1"):SetSelectedIndex(1)
        list2:GetScrollPane():LockFooter(footer:GetSourceSize().y)
        self.scene:ScheduleOnce(function(dt)
            list2:SetNumItems(list2:GetNumItems() + 5)
            footer:GetController("c1"):SetSelectedIndex(0)
            list2:GetScrollPane():LockFooter(0)
        end, 2, "pull_up")
    end)

    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function LoopListScene:Create()
    --[[
// 		auto uires_root = context_->GetSubsystem<FileSystem>()->GetProgramDir() + "Data/FairyGUI/Resources";
//         uires_root.replace("/build/", "/");
//         uires_root.replace("/Release/", "/");
//         uires_root.replace("/Debug/", "/");
//   		//cocos2d::FileUtils::getInstance()->addSearchPath(uires_root.c_str());
// 		context->GetSubsystem<ResourceCache>()->AddResourceDir(uires_root);
--]]
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/LoopList")
    local view = FairyGUI.UIPackage.CreateObject("LoopList", "Main")
    self.scene.groot:AddChild(view)
    local list = view:GetChild("list")
    list:SetItemRenderer(function (index, obj)
        obj:SetPivot(0.5, 0.5)
        obj:SetIcon("ui://LoopList/n" .. (index + 1))
    end)
    list:SetVirtualAndLoop()
    list:SetNumItems(5)
    list:AddEventListener(FairyGUI.EventType.Scroll, function (event)
        local midX = list:GetScrollPane():GetPosX() + list:GetViewWidth() / 2
        local cnt = list:NumChildren()
        for i = 0, cnt - 1 do
            local obj = list:GetChildAt(i)
            local dist = math.abs(midX - obj:GetX() - obj:GetWidth() / 2)
            if dist > obj:GetWidth() then
                obj:SetScale(1, 1)
            else
                local ss = 1 + (1 - dist / obj:GetWidth()) * 0.24
                obj:SetScale(ss, ss)
            end
        end
        view:GetChild("n3"):SetText(tostring((list:GetFirstChildInView() + 1) % list:GetNumItems()))
    end)
    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function BagScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/Bag")
    local mainView = FairyGUI.UIPackage.CreateObject("Bag", "Main")
    self.scene.groot:AddChild(mainView)

    local bagView = FairyGUI.UIPackage.CreateObject("Bag", "BagWin")
    local list = bagView:GetChild("list")
    list:AddEventListener(FairyGUI.EventType.ClickItem, function (event)
        local item = event:GetData()
        local n11 = bagView:GetChild("n11")
        n11:SetIcon(item:GetIcon())
        local n13 = bagView:GetChild("n13")
        n13:SetText(item:GetText())
    end)
    list:SetItemRenderer(function (index, obj)
        obj:SetIcon("UI/icons/i" .. tostring(math.random(0, 9)) .. ".png")
        obj:SetText(tostring(math.random(0, 100)))
    end)
    list:SetNumItems(45)

    local bagWindow = FairyGUI.Window.Create()
    bagWindow:SetContentPane(bagView)
    bagWindow:Center(false)
    bagWindow:SetModal(true)
    mainView:GetChild("bagBtn"):AddClickListener(function (context) bagWindow:Show() end)
    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function ChatScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/Emoji")
    local view = FairyGUI.UIPackage.CreateObject("Emoji", "Main")
    self.scene.groot:AddChild(view)
    local list = view:GetChild("list")
    self.messages = {}
    self.AddMsg = function (sender, senderIcon, msg, fromMe)
        local isScrollBottom = list:GetScrollPane():IsBottomMost()
        local newMessage = {}
        newMessage.sender = sender
        newMessage.senderIcon = senderIcon
        newMessage.msg = msg
        newMessage.fromMe = fromMe
        self.messages[#self.messages + 1] = newMessage

        if newMessage.fromMe then
            if #self.messages == 1 or math3d.Random(0, 1) < 0.5 then
                local replyMessage = {}
                replyMessage.sender = "FairyGUI"
                replyMessage.senderIcon = "r1"
                replyMessage.msg = "Today is a good day. [:cool]"
                replyMessage.fromMe = false
                self.messages[#self.messages + 1] = replyMessage
            end
        end
        local offset = #self.messages - 100
        if offset > 0 then
            local messages = {}
            table.move(self.messages, offset + 1, #self.messages, 1, messages)
            self.messages = messages;
        end
        list:SetNumItems(#self.messages)

        if isScrollBottom then
            list:GetScrollPane():ScrollBottom(true)
        end
    end
    
    list:SetVirtual()
    list:SetItemProvider(function (index)
        local msg = self.messages[index + 1]
        if msg.fromMe then
            return "ui://Emoji/chatRight"
        else
            return "ui://Emoji/chatLeft"
        end
    end)
    list:SetItemRenderer(function (index, item)
        local msg = self.messages[index + 1]
        if not msg.fromMe then
            item:GetChild("name"):SetText(msg.sender)
        end
        item:SetIcon("ui://Emoji/" .. msg.senderIcon)
    
        local tf = item:GetChild("msg")
        tf:SetText("")
        tf:SetWidth(tf:GetInitSize().x)
        tf:SetText(FairyGUI.EmojiParser(msg.msg))
        tf:SetWidth(tf:GetTextSize().x)
    end)

    local input = view:GetChild("input")
    input:AddEventListener(FairyGUI.EventType.Submit, function (event)
        local msg = input:GetText()
        if #msg < 1 then
            return
        end
        self.AddMsg("Unity", "r0", msg, true)
        input:SetText("");
    end)

    view:GetChild("btnSend"):AddClickListener(function (context)
        local msg = input:GetText()
        if #msg < 1 then
            return
        end
        self.AddMsg("Unity", "r0", msg, true)
        input:SetText("");
    end)

    local emojiSelectUI = FairyGUI.UIPackage.CreateObject("Emoji", "EmojiSelectUI")
    emojiSelectUI:GetChild("list"):AddEventListener(FairyGUI.EventType.ClickItem, function (context)
        local item = context:GetData()
        input:SetText(input:GetText() .. "[:" .. item:GetText() .. "]")
    end)

    view:GetChild("btnEmoji"):AddClickListener(function (context)
        self.scene.groot:ShowPopup(emojiSelectUI, context:GetSender(), FairyGUI.PopupDirection.UP)
    end)

    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function ListEffectScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/Extension")
    local view = FairyGUI.UIPackage.CreateObject("Extension", "Main")
    self.scene.groot:AddChild(view)

    local list = view:GetChild("mailList")
    for i = 0, 9 do
        local obj = list:AddItemFromPool()
        obj:GetController("c1"):SetSelectedIndex((i % 3 == 0) and 1 or 0)
        obj:GetController("IsRead"):SetSelectedIndex((i % 2 == 0) and 1 or 0)
        obj:GetChild("timeText"):SetText("5 Nov 2015 16:24:33")
        obj:SetTitle("Mail title here")
    end
    list:EnsureBoundsCorrect()
    local delay = 1.0
    for i = 0, 9 do
        local item = list:GetChildAt(i)
        if list:IsChildInView(item) then
            item:SetVisible(false)
            item:GetTransition("t0"):Play(1, delay)
            delay = delay + 0.2
        end
    end
    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function VirtualListScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/VirtualList")
    local view = FairyGUI.UIPackage.CreateObject("VirtualList", "Main")
    self.scene.groot:AddChild(view)

    local list = view:GetChild("mailList")
    list:SetItemRenderer(function (index, obj)
        obj:GetController("c1"):SetSelectedIndex((index % 3 == 0) and 1 or 0)
        obj:GetController("IsRead"):SetSelectedIndex((index % 2 == 0) and 1 or 0);
        obj:GetChild("timeText"):SetText("5 Nov 2015 16:24:33");
        obj:SetText(index .. " Mail title here");
    end)
    list:SetVirtual()
    list:SetNumItems(1000)

    view:GetChild("n6"):AddClickListener(function (context) list:AddSelection(500, true) end)
    view:GetChild("n7"):AddClickListener(function (context) list:GetScrollPane():ScrollTop() end)
    view:GetChild("n8"):AddClickListener(function (context) list:GetScrollPane():ScrollBottom() end)
    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function BasicsScene:Create()
    FairyGUI.SetUIConfig({
        buttonSound = "ui://Basics/click",
        verticalScrollBar = "ui://Basics/ScrollBar_VT",
        horizontalScrollBar = "ui://Basics/ScrollBar_HZ",
        tooltipsWin = "ui://Basics/WindowFrame",
        popupMenu = "ui://Basics/PopupMenu"
    })
    self.scene = FairyGUI.FairyGUIScene()
    self.demoObjects = {}
    FairyGUI.UIPackage.AddPackage("UI/Basics")
    local view = FairyGUI.UIPackage.CreateObject("Basics", "Main")
    self.scene.groot:AddChild(view)
    local backBtn = view:GetChild("btn_Back")
    backBtn:SetVisible(false)
    backBtn:AddClickListener(function (context) self:onClickBack(context) end)
    self.view = view
    self.backBtn = backBtn
    self.demoContainer = view:GetChild("container")
    self.cc = view:GetController("c1")
    local cnt = view:NumChildren()
    for i = 0, cnt-1 do
        local obj = view:GetChildAt(i)
        local group = obj:GetGroup()
        if group and group.name == "btns" then
            obj:AddClickListener(function (context) self:runDemo(context) end);
        end
    end
    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end
function BasicsScene:onClickBack(context)
    self.cc:SetSelectedIndex(0)
    self.backBtn:SetVisible(false)
end
function BasicsScene:runDemo(context)
    local type = string.sub(context:GetSender().name, 5)
    local demoObjects = self.demoObjects
    if not self.demoObjects[type] then
        demoObjects[type] = FairyGUI.UIPackage.CreateObject("Basics", "Demo_" .. type)
    end
    local obj = demoObjects[type]
    self.demoContainer:RemoveChildren()
    self.demoContainer:AddChild(obj)
    self.cc:SetSelectedIndex(1)
    self.backBtn:SetVisible(true)
    if type == "Text" then
        self:playText()
    elseif type == "Depth" then
        self:playDepth()
    elseif type == "Window" then
        self:playWindow()
    elseif type == "Drag&Drop" then
        self:playDragDrop()
    elseif type == "Popup" then
        self:playPopup()
    elseif type == "ProgressBar" then
        self:playProgress()
    end
end
function BasicsScene:playText()
    local obj = self.demoObjects["Text"]
    obj:GetChild("n12"):AddEventListener(FairyGUI.EventType.ClickLink, function(context)
        local t = context:GetSender();
        t:SetText("[img]ui://Basics/pet[/img][color=#FF0000]You click the link[/color]:" + context:GetDataAsString())
    end)
    obj:GetChild("n25"):AddClickListener(function (event) obj:GetChild("n24"):SetText(obj:GetChild("n22"):GetText()) end)
end
function BasicsScene:playPopup()
    if not self.pm then
        local pm = FairyGUI.PopupMenu.Create()
        pm:AddItem("Item 1", function(context) self:onClickMenu(context) end);
        pm:AddItem("Item 2", function(context) self:onClickMenu(context) end);
        pm:AddItem("Item 3", function(context) self:onClickMenu(context) end);
        pm:AddItem("Item 4", function(context) self:onClickMenu(context) end);
        self.pm = pm
    end

    if not self.popupCom then
        local popupCom = FairyGUI.UIPackage.CreateObject("Basics", "Component12")
        popupCom:Center()
        self.popupCom = popupCom
    end
    local obj = self.demoObjects["Popup"]
    obj:GetChild("n0"):AddClickListener(function(context) self.pm:Show(context:GetSender(), FairyGUI.PopupDirection.DOWN) end)
    obj:GetChild("n1"):AddClickListener(function(event) self.scene.groot:ShowPopup(self.popupCom) end);
    obj:AddEventListener(FairyGUI.EventType.RightClick, function(event) self.pm:Show() end)
end

function BasicsScene:onClickMenu(context)
    local item = context:getData()
    print("click %s", item:GetText())
end

function BasicsScene:playWindow()
    -- local obj = self.demoObjects["Window"]
    -- if not self.winA then
    --     self.winA = Window1::Create()
    --     self.winB = Window2::Create()
    --     obj:GetChild("n0"):AddClickListener(function(context) self.winA:Show() end)
    --     obj:GetChild("n1"):AddClickListener(function(context) self.winB:Show() end)
    -- end
end
function BasicsScene:playDepth()
    local obj = self.demoObjects["Depth"]
    local testContainer = obj:GetChild("n22")
    local fixedObj = testContainer:GetChild("n0")
    fixedObj:SetSortingOrder(100)
    fixedObj:SetDraggable(true)

    local numChildren = testContainer:NumChildren();
    local i = 0
    while i < numChildren do
        local child = testContainer:GetChildAt(i);
        if child ~= fixedObj then
            testContainer:RemoveChildAt(i)
            numChildren = numChildren - 1
        else
            i = i + 1
        end
    end
    self.startPos = fixedObj:GetPosition();

    obj:GetChild("btn0"):AddClickListener(function(context)
        local graph = FairyGUI.GGraph()
        self.startPos.x = self.startPos.x + 10;
        self.startPos.y = self.startPos.y + 10;
        graph:SetPosition(self.startPos.x, self.startPos.y);
        graph:DrawRect(150, 150, 1, math3d.Color.BLACK, math3d.Color.RED);
        obj:GetChild("n22"):AddChild(graph);
    end, self.scene)

    obj:GetChild("btn1"):AddClickListener(function(context)
        local graph = FairyGUI.GGraph()
        self.startPos.x = self.startPos.x + 10
        self.startPos.y = self.startPos.y + 10
        graph:SetPosition(self.startPos.x, self.startPos.y);
        graph:DrawRect(150, 150, 1, math3d.Color.BLACK, math3d.Color.GREEN);
        graph:SetSortingOrder(200);
        obj:GetChild("n22"):AddChild(graph);
    end, self.scene)
end

function BasicsScene:playDragDrop()
    local obj = self.demoObjects["Drag&Drop"]
    obj:GetChild("a"):SetDraggable(true);

    local b = obj:GetChild("b")
    b:SetDraggable(true);
    b:AddEventListener(FairyGUI.EventType.DragStart, function(context)
        --Cancel the original dragging, and start a new one with a agent.
        context:PreventDefault()
        FairyGUI.StartDrag(b:GetIcon(), b:GetIcon(), context:GetTouchId())
    end);

    local c = obj:GetChild("c")
    c:SetIcon("");
    c:AddEventListener(FairyGUI.EventType.Drop, function(context) c:SetIcon(context:GetDataAsString()) end)

    local bounds = obj:GetChild("n7");
    local rect = bounds:TransformRect(math3d.Rect(math3d.Vector2.ZERO, bounds:GetSize()), self.scene.groot);
    ---!!Because at this time the container is on the right side of the stage and beginning to move to left(transition), so we need to caculate the final position
    rect.min.x = rect.min.x - obj:GetParent():GetX()
    rect.max.x = rect.max.x - obj:GetParent():GetX()
    local d = obj:GetChild("d")
    d:SetDraggable(true);
    d:SetDragBounds(rect);
end

function BasicsScene:playProgress()
    local obj = self.demoObjects["ProgressBar"]
    self.schedule_id = FairyGUI.ScheduleScriptFunc(function() self:onPlayProgress() end, 0.02, false)
    obj:AddEventListener(FairyGUI.EventType.Exit, function(context) FairyGUI.UnscheduleScriptEntry(self.schedule_id); end)
end

function BasicsScene:onPlayProgress(dt)
    local obj = self.demoObjects["ProgressBar"]
    local cnt = obj:NumChildren();
    for i = 0, cnt - 1 do
        local child = obj:GetChildAt(i)
        if child then
            child:SetValue(child:GetValue() + 1)
            if child:GetValue() > child:GetMax() then
                child:SetValue(child:GetMin())
            end
        end
    end
end

function ScrollPaneScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/ScrollPane")
    local view = FairyGUI.UIPackage.CreateObject("ScrollPane", "Main")
    self.scene.groot:AddChild(view)

    local list = view:GetChild("list")
    list:SetItemRenderer(function (index, obj)
        obj:SetTitle("Item " .. index)
        obj:GetScrollPane():SetPosX(0)
        obj:GetChild("b0"):AddClickListener(function (context) view:GetChild("txt"):SetText("Stick " .. context:GetSender():GetParent():GetText())
        end, self.scene)
        obj:GetChild("b1"):AddClickListener(function (context) view:GetChild("txt"):SetText("Delete " .. context:GetSender():GetParent():GetText())
        end, self.scene)
    end)
    list:SetVirtual()
    list:SetNumItems(1000)
    local root_ui = self.scene.groot
    list:AddEventListener(FairyGUI.EventType.TouchBegin, function (event)
        local cnt = list:NumChildren()
        for i = 0, cnt - 1 do
            local item = list:GetChildAt(i)
            if item:GetScrollPane():GetPosX() ~= 0 then
                if item:GetChild("b0"):IsAncestorOf(root_ui:GetTouchTarget())
                    or item:GetChild("b1"):IsAncestorOf(root_ui:GetTouchTarget()) then
                    return
                end
                item:GetScrollPane():SetPosX(0, true)
                item:GetScrollPane():CancelDragging()
                list:GetScrollPane():CancelDragging()
                break
            end
        end
    end)

    AddCloseButton(root_ui, ReturnMenu)
    return self.scene
end

function TreeViewScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/TreeView")
    local view = FairyGUI.UIPackage.CreateObject("TreeView", "Main")
    self.scene.groot:AddChild(view)

    local tree1 = view:GetChild("tree")
    tree1:AddEventListener(FairyGUI.EventType.ClickItem, function(context)
        local node = context:GetData():TreeNode()
        print("click node ", node:GetText())
    end)

    local tree2 = view:GetChild("tree2")
    tree2:AddEventListener(FairyGUI.EventType.ClickItem, function(context)
        local node = context:GetData():TreeNode()
        print("click node ", node:GetText())
    end)
    tree2:SetItemRenderer(function (node, obj)
        local btn = node:GetCell()
        local tdata = node:GetTable()
        if node:IsFolder() then
            btn:SetText(node:GetData():GetString())
        elseif tdata and #tdata > 0 then
            btn:SetText(tdata[1])
            btn:SetIcon(tdata[2])
        else
            btn:SetIcon("ui://TreeView/file")
            btn:SetText(node:GetData():GetString())
        end
    end)

    local topNode = FairyGUI.GTreeNode.Create(true)
    topNode:SetData(Variant("I'm a top node"))
    tree2:GetRootNode():AddChild(topNode)
    for i = 0, 4 do
        local node = FairyGUI.GTreeNode.Create()
        node:SetData(Variant("Hello " .. i))
        topNode:AddChild(node);
    end

    local aFolderNode = FairyGUI.GTreeNode.Create(true)
    aFolderNode:SetData(Variant("A folder node"))
    topNode:AddChild(aFolderNode);
    for i = 0, 4 do
        local node = FairyGUI.GTreeNode.Create()
        node:SetData(Variant("Good " .. i))
        aFolderNode:AddChild(node);
    end

    for i = 0, 2 do
        local node = FairyGUI.GTreeNode.Create()
        node:SetData(Variant("World " .. i))
        topNode:AddChild(node)
    end

    local anotherTopNode = FairyGUI.GTreeNode.Create()
    anotherTopNode:SetTable({"I'm a top node too", "ui://TreeView/heart"})
    tree2:GetRootNode():AddChild(anotherTopNode)
    
    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function GuideScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/Guide")
    local view = FairyGUI.UIPackage.CreateObject("Guide", "Main")
    self.scene.groot:AddChild(view)

    local root_ui = self.scene.groot
    local guideLayer = FairyGUI.UIPackage.CreateObject("Guide", "GuideLayer")
    guideLayer:MakeFullScreen();
    guideLayer:AddRelation(root_ui, FairyGUI.RelationType.Size)

    local bagBtn = view:GetChild("bagBtn")
    bagBtn:AddClickListener(function (context) guideLayer:RemoveFromParent() end)

    view:GetChild("n2"):AddClickListener(function (context) 
        root_ui:AddChild(guideLayer)
        local rect = bagBtn:TransformRect(math3d.Rect(math3d.Vector2.ZERO, bagBtn:GetSize()), guideLayer)
        local win = guideLayer:GetChild("window")
        win:SetSize(rect:Size())
        FairyGUI.GTween.To(win:GetPosition(), rect.min, 0.5):SetTarget(win, FairyGUI.TweenPropType.Position)
    end)
    AddCloseButton(root_ui, ReturnMenu)
    return self.scene
end

function CooldownScene:Create()
    self.scene = FairyGUI.FairyGUIScene()
    FairyGUI.UIPackage.AddPackage("UI/Cooldown")
    local view = FairyGUI.UIPackage.CreateObject("Cooldown", "Main")
    self.scene.groot:AddChild(view)

    local btn0 = view:GetChild("b0")
    local btn1 = view:GetChild("b1")
    btn0:GetChild("icon"):SetIcon("UI/icons/k0.png")
    btn1:GetChild("icon"):SetIcon("UI/icons/k1.png")

    FairyGUI.GTween.To(0, 100, 5):SetTarget(btn0, FairyGUI.TweenPropType.Progress):SetRepeat(-1)
    FairyGUI.GTween.To(10, 0, 10):SetTarget(btn1, FairyGUI.TweenPropType.Progress):SetRepeat(-1)
    AddCloseButton(self.scene.groot, ReturnMenu)
    return self.scene
end

function app:CreateScene()
    self.scene = Scene()
    --FairyGUI.RegisterFont("default", "fonts/FZY3JW.TTF")
    --FairyGUI:RunWithScene(MenuScene:Create())
end

function app:Load(viewport, uiscene)
    if self.running then
        return
    end
    self.running = true
    if not self.scene then
        self.uiscene = uiscene
        self:CreateScene()
    end
    self:SetupViewport(viewport)
    self:SubscribeToEvents()
end

function app:UnLoad()
    if not self.running then
        return
    end
    self.running = false
    self:UnSubscribeToEvents()
    FairyGUI.SetDesignResolutionSize(1280, 720)
    FairyGUI.ReplaceScene(self.uiscene)
end

function app:SetupViewport(viewport)
    viewport:SetScene(self.scene)
    FairyGUI.SetDesignResolutionSize(1136, 640)
    FairyGUI.ReplaceScene(MenuScene:Create())
end

function app:SubscribeToEvents()
end

function app:UnSubscribeToEvents()
end

function app:OnUpdate(eventType, eventData)
end

function app:OnSceneUpdate(eventType, eventData)
end

function app:OnPostUpdate(eventType, eventData)
end

function app:OnPostRenderUpdate(eventType, eventData)
end

return app