require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_frmPericiaArmaItem()
    local obj = GUI.fromHandle(_obj_newObject("form"));
    local self = obj;
    local sheet = nil;

    rawset(obj, "_oldSetNodeObjectFunction", obj.setNodeObject);

    function obj:setNodeObject(nodeObject)
        sheet = nodeObject;
        self.sheet = nodeObject;
        self:_oldSetNodeObjectFunction(nodeObject);
    end;

    function obj:setNodeDatabase(nodeObject)
        self:setNodeObject(nodeObject);
    end;

    _gui_assignInitialParentForForm(obj.handle);
    obj:beginUpdate();
    obj:setName("frmPericiaArmaItem");
    obj:setHeight(25);
    obj:setWidth(850);
    obj:setMargins({top=2});

 
		


			
		local function askForDelete()
			Dialogs.confirmYesNo("Deseja realmente apagar?",
								 function (confirmado)
									if confirmado then
										NDB.deleteNode(sheet);
									end;
								 end);
		end;

		local function showHabilidadePopup()
			local pop = self:findControlByName("popAprimoramento");
				
			if pop ~= nil then
				pop:setNodeObject(self.sheet);
				pop:showPopupEx("right", self);
			else
				showMessage("Ops, bug.. nao encontrei o popup para exibir");
			end;				
		end;
	



	


    obj.button1 = GUI.fromHandle(_obj_newObject("button"));
    obj.button1:setParent(obj);
    obj.button1:setAlign("left");
    obj.button1:setWidth(30);
    obj.button1:setText("i");
    obj.button1:setFontColor("#D8CBB0");
    obj.button1:setName("button1");

    obj.edit1 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit1:setParent(obj);
    obj.edit1:setAlign("left");
    obj.edit1:setWidth(160);
    obj.edit1:setField("nome");
    obj.edit1:setVertTextAlign("center");
    obj.edit1:setHorzTextAlign("leading");
    obj.edit1:setName("edit1");

    obj.comboBox1 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox1:setParent(obj);
    obj.comboBox1:setAlign("left");
    obj.comboBox1:setWidth(50);
    obj.comboBox1:setField("atributo");
    obj.comboBox1:setItems({'DEX','AGI'});
    obj.comboBox1:setValues({'destreza', 'agilidade'});
    obj.comboBox1:setHorzTextAlign("center");
    obj.comboBox1:setName("comboBox1");

    obj.comboBox2 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox2:setParent(obj);
    obj.comboBox2:setAlign("left");
    obj.comboBox2:setWidth(60);
    obj.comboBox2:setField("tipo");
    obj.comboBox2:setItems({'C.a.C','Dist'});
    obj.comboBox2:setHorzTextAlign("center");
    obj.comboBox2:setName("comboBox2");

    obj.edit2 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit2:setParent(obj);
    obj.edit2:setAlign("left");
    obj.edit2:setWidth(35);
    obj.edit2:setField("gastoAtk");
    obj.edit2:setType("number");
    obj.edit2:setVertTextAlign("center");
    obj.edit2:setHorzTextAlign("center");
    obj.edit2:setName("edit2");

    obj.button2 = GUI.fromHandle(_obj_newObject("button"));
    obj.button2:setParent(obj);
    obj.button2:setAlign("left");
    obj.button2:setWidth(25);
    obj.button2:setText("R");
    obj.button2:setFontColor("#E6C24A");
    obj.button2:setName("button2");

    obj.rectangle1 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle1:setParent(obj);
    obj.rectangle1:setAlign("left");
    obj.rectangle1:setWidth(55);
    obj.rectangle1:setColor("#272C36");
    obj.rectangle1:setStrokeColor("#8A6C30");
    obj.rectangle1:setStrokeSize(1);
    obj.rectangle1:setName("rectangle1");

    obj.label1 = GUI.fromHandle(_obj_newObject("label"));
    obj.label1:setParent(obj.rectangle1);
    obj.label1:setField("totalAtk");
    obj.label1:setAlign("client");
    obj.label1:setHorzTextAlign("center");
    obj.label1:setFontColor("#D8CBB0");
    obj.label1:setName("label1");

    obj.rectangle2 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle2:setParent(obj);
    obj.rectangle2:setAlign("left");
    obj.rectangle2:setWidth(55);
    obj.rectangle2:setColor("#272C36");
    obj.rectangle2:setStrokeColor("#8A6C30");
    obj.rectangle2:setStrokeSize(1);
    obj.rectangle2:setName("rectangle2");

    obj.label2 = GUI.fromHandle(_obj_newObject("label"));
    obj.label2:setParent(obj.rectangle2);
    obj.label2:setField("totalDef");
    obj.label2:setAlign("client");
    obj.label2:setHorzTextAlign("center");
    obj.label2:setFontColor("#D8CBB0");
    obj.label2:setName("label2");

    obj.button3 = GUI.fromHandle(_obj_newObject("button"));
    obj.button3:setParent(obj);
    obj.button3:setAlign("left");
    obj.button3:setWidth(25);
    obj.button3:setText("R");
    obj.button3:setFontColor("#E6C24A");
    obj.button3:setName("button3");

    obj.button4 = GUI.fromHandle(_obj_newObject("button"));
    obj.button4:setParent(obj);
    obj.button4:setAlign("right");
    obj.button4:setWidth(25);
    obj.button4:setText("X");
    obj.button4:setFontColor("#E6140F0C");
    obj.button4:setName("button4");

    obj.dataLink1 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink1:setParent(obj);
    obj.dataLink1:setFields({'tipo','atributo','destreza','agilidade','gastoAtk'});
    obj.dataLink1:setName("dataLink1");

    obj.dataLink2 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink2:setParent(obj);
    obj.dataLink2:setFields({'tipo','atributo','destreza','agilidade','gastoDef'});
    obj.dataLink2:setName("dataLink2");

    obj.dataLink3 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink3:setParent(obj);
    obj.dataLink3:setFields({'gastoAtk','gastoDef'});
    obj.dataLink3:setName("dataLink3");

    obj._e_event0 = obj.button1:addEventListener("onClick",
        function (event)
            showHabilidadePopup();
        end);

    obj._e_event1 = obj.button2:addEventListener("onClick",
        function (event)
            local node = NDB.getRoot(sheet)
            			node.rollText = sheet.nome or "ataque"
            			node.rollValue = tonumber(sheet.totalAtk) or 0
            			node.roll = true
            			node.rollDamage = true
            			node.rollDamageValue = sheet.dano
            			node.rollDamageValueCrit = sheet.critico
        end);

    obj._e_event2 = obj.button3:addEventListener("onClick",
        function (event)
            local node = NDB.getRoot(sheet)
            			node.rollText = sheet.nome or "defesa"
            			node.rollValue = tonumber(sheet.totalDef) or 0
            			node.roll = true
        end);

    obj._e_event3 = obj.button4:addEventListener("onClick",
        function (event)
            askForDelete();
        end);

    obj._e_event4 = obj.dataLink1:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            			local atr = sheet.atributo or "none"
            			local gasto = (tonumber(sheet.gastoAtk) or 0)
            			if sheet.tipo == "Dist" then
            				gasto = math.floor(gasto/2)
            			end
            			sheet.totalAtk = gasto + (tonumber(sheet[atr]) or 0)
        end);

    obj._e_event5 = obj.dataLink2:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            			local atr = sheet.atributo or "none"
            			local gasto = (tonumber(sheet.gastoDef) or 0)
            			if sheet.tipo == "Dist" then
            				gasto = math.floor(gasto/2)
            			end
            			sheet.totalDef = gasto + (tonumber(sheet[atr]) or 0)
        end);

    obj._e_event6 = obj.dataLink3:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            			local node = NDB.getRoot(sheet)
            			local nodes = NDB.getChildNodes(node.periciasArmas)
            			local pts = 0
            			for i=1, #nodes, 1 do
            				if nodes[i].kit == nil or nodes[i].kit == "" then
            					pts = pts + (tonumber(nodes[i].gastoAtk) or 0)
            					pts = pts + (tonumber(nodes[i].gastoDef) or 0)
            				end
            			end
            			node.ptsPericiasArmas = pts
        end);

    function obj:_releaseEvents()
        __o_rrpgObjs.removeEventListenerById(self._e_event6);
        __o_rrpgObjs.removeEventListenerById(self._e_event5);
        __o_rrpgObjs.removeEventListenerById(self._e_event4);
        __o_rrpgObjs.removeEventListenerById(self._e_event3);
        __o_rrpgObjs.removeEventListenerById(self._e_event2);
        __o_rrpgObjs.removeEventListenerById(self._e_event1);
        __o_rrpgObjs.removeEventListenerById(self._e_event0);
    end;

    obj._oldLFMDestroy = obj.destroy;

    function obj:destroy() 
        self:_releaseEvents();

        if (self.handle ~= 0) and (self.setNodeDatabase ~= nil) then
          self:setNodeDatabase(nil);
        end;

        if self.dataLink2 ~= nil then self.dataLink2:destroy(); self.dataLink2 = nil; end;
        if self.button2 ~= nil then self.button2:destroy(); self.button2 = nil; end;
        if self.label2 ~= nil then self.label2:destroy(); self.label2 = nil; end;
        if self.dataLink1 ~= nil then self.dataLink1:destroy(); self.dataLink1 = nil; end;
        if self.rectangle1 ~= nil then self.rectangle1:destroy(); self.rectangle1 = nil; end;
        if self.comboBox2 ~= nil then self.comboBox2:destroy(); self.comboBox2 = nil; end;
        if self.button1 ~= nil then self.button1:destroy(); self.button1 = nil; end;
        if self.label1 ~= nil then self.label1:destroy(); self.label1 = nil; end;
        if self.rectangle2 ~= nil then self.rectangle2:destroy(); self.rectangle2 = nil; end;
        if self.edit2 ~= nil then self.edit2:destroy(); self.edit2 = nil; end;
        if self.dataLink3 ~= nil then self.dataLink3:destroy(); self.dataLink3 = nil; end;
        if self.button4 ~= nil then self.button4:destroy(); self.button4 = nil; end;
        if self.edit1 ~= nil then self.edit1:destroy(); self.edit1 = nil; end;
        if self.button3 ~= nil then self.button3:destroy(); self.button3 = nil; end;
        if self.comboBox1 ~= nil then self.comboBox1:destroy(); self.comboBox1 = nil; end;
        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newfrmPericiaArmaItem()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_frmPericiaArmaItem();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _frmPericiaArmaItem = {
    newEditor = newfrmPericiaArmaItem, 
    new = newfrmPericiaArmaItem, 
    name = "frmPericiaArmaItem", 
    dataType = "", 
    formType = "undefined", 
    formComponentName = "form", 
    cacheMode = "none", 
    title = "", 
    description=""};

frmPericiaArmaItem = _frmPericiaArmaItem;
Firecast.registrarForm(_frmPericiaArmaItem);

return _frmPericiaArmaItem;
