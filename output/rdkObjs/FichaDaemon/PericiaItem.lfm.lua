require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_frmPericiaItem()
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
    obj:setName("frmPericiaItem");
    obj:setHeight(25);
    obj:setWidth(350);
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
	



	


    obj.edit1 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit1:setParent(obj);
    obj.edit1:setAlign("client");
    obj.edit1:setVertTextAlign("center");
    obj.edit1:setField("nome");
    obj.edit1:setName("edit1");

    obj.button1 = GUI.fromHandle(_obj_newObject("button"));
    obj.button1:setParent(obj);
    obj.button1:setAlign("right");
    obj.button1:setWidth(30);
    obj.button1:setText("i");
    obj.button1:setName("button1");

    obj.layout1 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout1:setParent(obj);
    obj.layout1:setAlign("right");
    obj.layout1:setWidth(230);
    obj.layout1:setName("layout1");

    obj.comboBox1 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox1:setParent(obj.layout1);
    obj.comboBox1:setAlign("left");
    obj.comboBox1:setWidth(75);
    obj.comboBox1:setField("atributo");
    obj.comboBox1:setItems({'CON','FR','DEX','AGI','INT','WILL','PER','CAR','-'});
    obj.comboBox1:setValues({'constituicao','forca','destreza','agilidade','inteligencia','vontade','percepcao','carisma','none'});
    obj.comboBox1:setName("comboBox1");

    obj.layout2 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout2:setParent(obj.layout1);
    obj.layout2:setAlign("right");
    obj.layout2:setWidth(155);
    obj.layout2:setName("layout2");

    obj.layout3 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout3:setParent(obj.layout2);
    obj.layout3:setAlign("left");
    obj.layout3:setWidth(100);
    obj.layout3:setName("layout3");

    obj.rectangle1 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle1:setParent(obj.layout3);
    obj.rectangle1:setAlign("right");
    obj.rectangle1:setWidth(50);
    obj.rectangle1:setColor("#272C36");
    obj.rectangle1:setStrokeColor("#8A6C30");
    obj.rectangle1:setStrokeSize(1);
    obj.rectangle1:setName("rectangle1");

    obj.label1 = GUI.fromHandle(_obj_newObject("label"));
    obj.label1:setParent(obj.rectangle1);
    obj.label1:setField("total");
    obj.label1:setAlign("client");
    obj.label1:setHorzTextAlign("center");
    obj.label1:setName("label1");

    obj.edit2 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit2:setParent(obj.layout3);
    obj.edit2:setAlign("left");
    obj.edit2:setWidth(50);
    obj.edit2:setField("gasto");
    obj.edit2:setType("number");
    obj.edit2:setVertTextAlign("center");
    obj.edit2:setHorzTextAlign("center");
    obj.edit2:setName("edit2");

    obj.button2 = GUI.fromHandle(_obj_newObject("button"));
    obj.button2:setParent(obj.layout2);
    obj.button2:setText("R");
    obj.button2:setAlign("right");
    obj.button2:setWidth(25);
    obj.button2:setName("button2");

    obj.dataLink1 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink1:setParent(obj.layout2);
    obj.dataLink1:setFields({'atributo','constituicao','forca','destreza','agilidade','inteligencia','vontade','percepcao','carisma','none','gasto'});
    obj.dataLink1:setName("dataLink1");

    obj.button3 = GUI.fromHandle(_obj_newObject("button"));
    obj.button3:setParent(obj.layout2);
    obj.button3:setAlign("right");
    obj.button3:setWidth(30);
    obj.button3:setText("X");
    obj.button3:setName("button3");

    obj.dataLink2 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink2:setParent(obj);
    obj.dataLink2:setFields({'gasto'});
    obj.dataLink2:setName("dataLink2");

    obj._e_event0 = obj.button1:addEventListener("onClick",
        function (event)
            showHabilidadePopup();
        end);

    obj._e_event1 = obj.button2:addEventListener("onClick",
        function (event)
            local node = NDB.getRoot(sheet)
            					node.rollText = sheet.nome or "pericia"
            					node.rollValue = tonumber(sheet.total) or 0
            					node.roll = true
        end);

    obj._e_event2 = obj.dataLink1:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            					local atr = sheet.atributo or "none"
            					sheet.total = (tonumber(sheet.gasto) or 0) + (tonumber(sheet[atr]) or 0)
        end);

    obj._e_event3 = obj.button3:addEventListener("onClick",
        function (event)
            askForDelete();
        end);

    obj._e_event4 = obj.dataLink2:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            			local node = NDB.getRoot(sheet)
            			local nodes = NDB.getChildNodes(node.pericias)
            			local pts = 0
            			for i=1, #nodes, 1 do
            				if nodes[i].kit == nil or nodes[i].kit == "" then
            					pts = pts + (tonumber(nodes[i].gasto) or 0)
            				end
            			end
            
            			node.ptsPericias = pts
        end);

    function obj:_releaseEvents()
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
        if self.dataLink1 ~= nil then self.dataLink1:destroy(); self.dataLink1 = nil; end;
        if self.rectangle1 ~= nil then self.rectangle1:destroy(); self.rectangle1 = nil; end;
        if self.button1 ~= nil then self.button1:destroy(); self.button1 = nil; end;
        if self.label1 ~= nil then self.label1:destroy(); self.label1 = nil; end;
        if self.layout3 ~= nil then self.layout3:destroy(); self.layout3 = nil; end;
        if self.edit2 ~= nil then self.edit2:destroy(); self.edit2 = nil; end;
        if self.layout2 ~= nil then self.layout2:destroy(); self.layout2 = nil; end;
        if self.edit1 ~= nil then self.edit1:destroy(); self.edit1 = nil; end;
        if self.button3 ~= nil then self.button3:destroy(); self.button3 = nil; end;
        if self.comboBox1 ~= nil then self.comboBox1:destroy(); self.comboBox1 = nil; end;
        if self.layout1 ~= nil then self.layout1:destroy(); self.layout1 = nil; end;
        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newfrmPericiaItem()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_frmPericiaItem();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _frmPericiaItem = {
    newEditor = newfrmPericiaItem, 
    new = newfrmPericiaItem, 
    name = "frmPericiaItem", 
    dataType = "", 
    formType = "undefined", 
    formComponentName = "form", 
    cacheMode = "none", 
    title = "", 
    description=""};

frmPericiaItem = _frmPericiaItem;
Firecast.registrarForm(_frmPericiaItem);

return _frmPericiaItem;
