require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_frmAtaquePrincipal()
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
    obj:setName("frmAtaquePrincipal");
    obj:setHeight(25);
    obj:setWidth(950);
    obj:setMargins({top=2});


		



		local function askForDelete()
			Dialogs.confirmYesNo("Deseja realmente apagar esse ataque?",
								 function (confirmado)
									if confirmado then
										NDB.deleteNode(self.sheet);
									end;
								 end);
		end;

		local function rolarDano(mesa, nome, critico)
			local root = NDB.getRoot(sheet);
			local bforca = tonumber(root.bforcaTotal) or 0;
			local dano = sheet.dano or "";
			if dano == "" then return; end;

			local expr, lbl;
			if critico then
				expr = dano .. " + " .. dano .. " + " .. (bforca * 2);
				lbl = "Dano CRITICO - " .. nome;
			else
				expr = dano .. " + " .. bforca;
				lbl = "Dano - " .. nome;
			end;

			local rd = Firecast.interpretarRolagem(expr);
			if (rd ~= nil) and rd.possuiAlgumDado then
				mesa.activeChat:rolarDados(rd, lbl);
			end;
		end;

		local function doRoll(mesa, rollText, rollCrit, rollTarget, nome)
			mesa.activeChat:rolarDados("1d100", rollText,
				function (rolado)
					local r = rolado.resultado;
					if r <= rollCrit then
						mesa.activeChat:enviarMensagem("SUCESSO CRITICO =D");
						rolarDano(mesa, nome, true);
					elseif r >= 95 then
						mesa.activeChat:enviarMensagem("FALHA CRITICA =(");
					elseif r <= rollTarget then
						mesa.activeChat:enviarMensagem("SUCESSO =)");
						rolarDano(mesa, nome, false);
					else
						mesa.activeChat:enviarMensagem("FALHA =/");
					end;
				end);
		end;

		local function rolarAtaque()
			local personagem = Firecast.getPersonagemDe(sheet);
			if personagem == nil then return; end;
			local mesa = personagem.mesa;
			if not ((personagem.dono == mesa.meuJogador) or (mesa.meuJogador.isMestre)) then
				showMessage("Voce nao pode rolar para este personagem.");
				return;
			end;

			local root = NDB.getRoot(sheet);
			local value = tonumber(sheet.periciaArma) or 0;
			local nome = sheet.nome or "Arma";
			local dif = string.lower(tostring(root.atribDificuldade or "normal"));

			local alvoBase, sufixo;
			if dif == "facil" then
				alvoBase = value * 2; sufixo = "Facil";
			elseif dif == "dificil" then
				alvoBase = math.floor(value / 2); sufixo = "Dificil";
			else
				alvoBase = value; sufixo = "Normal";
			end;

			local crit = math.max(math.ceil(value / 4), 5);
			local rollText = "Ataque - " .. nome .. " " .. sufixo;

			local _resist = root.atribResistido; _resist = (_resist == true) or (_resist == 1) or (_resist == "true");
			if _resist then
				local def = math.abs(tonumber(sheet.defesaAlvo) or 0);
				local alvo = alvoBase + 50 - def;
				local rt = rollText .. " [" .. alvoBase .. "+50-" .. def .. " = " .. alvo .. "%] (Crit " .. crit .. ")";
				if alvo >= 100 then
					mesa.activeChat:enviarMensagem(rt .. " -> SUCESSO AUTOMATICO =D");
					rolarDano(mesa, nome, false);
					return;
				elseif alvo <= 0 then
					mesa.activeChat:enviarMensagem(rt .. " -> FALHA AUTOMATICA =/");
					return;
				end;
				doRoll(mesa, rt, crit, alvo, nome);
			else
				doRoll(mesa, rollText .. " [" .. alvoBase .. "%] (Crit " .. crit .. ")", crit, alvoBase, nome);
			end;
		end;
		



	


    obj.button1 = GUI.fromHandle(_obj_newObject("button"));
    obj.button1:setParent(obj);
    obj.button1:setAlign("left");
    obj.button1:setWidth(35);
    obj.button1:setFontColor("#E6C24A");
    obj.button1:setName("button1");

    obj.image1 = GUI.fromHandle(_obj_newObject("image"));
    obj.image1:setParent(obj.button1);
    obj.image1:setAlign("client");
    obj.image1:setHeight(20);
    obj.image1:setWidth(20);
    obj.image1:setStyle("autoFit");
    obj.image1:setSRC("/FichaDaemon/images/ic_dadod20.png");
    obj.image1:setName("image1");

    obj.rectangle1 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle1:setParent(obj);
    obj.rectangle1:setAlign("left");
    obj.rectangle1:setWidth(150);
    obj.rectangle1:setColor("#1B1F27");
    obj.rectangle1:setStrokeColor("#4A5365");
    obj.rectangle1:setStrokeSize(1);
    obj.rectangle1:setMargins({top=3,bottom=3});
    obj.rectangle1:setName("rectangle1");

    obj.edit1 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit1:setParent(obj.rectangle1);
    obj.edit1:setAlign("client");
    obj.edit1:setField("nome");
    obj.edit1:setVertTextAlign("center");
    obj.edit1:setHorzTextAlign("leading");
    obj.edit1:setMargins({left=4,right=4});
    obj.edit1:setName("edit1");
    obj.edit1:setFontSize(15);
    obj.edit1:setFontColor("white");
    obj.edit1:setTransparent(true);

    obj.rectangle2 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle2:setParent(obj);
    obj.rectangle2:setAlign("left");
    obj.rectangle2:setWidth(65);
    obj.rectangle2:setColor("#1B1F27");
    obj.rectangle2:setStrokeColor("#4A5365");
    obj.rectangle2:setStrokeSize(1);
    obj.rectangle2:setMargins({top=3,bottom=3});
    obj.rectangle2:setName("rectangle2");

    obj.edit2 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit2:setParent(obj.rectangle2);
    obj.edit2:setAlign("client");
    obj.edit2:setField("periciaArma");
    obj.edit2:setType("number");
    obj.edit2:setVertTextAlign("center");
    obj.edit2:setHorzTextAlign("center");
    obj.edit2:setName("edit2");
    obj.edit2:setFontSize(15);
    obj.edit2:setFontColor("white");
    obj.edit2:setTransparent(true);

    obj.rectangle3 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle3:setParent(obj);
    obj.rectangle3:setAlign("left");
    obj.rectangle3:setWidth(65);
    obj.rectangle3:setColor("#1B1F27");
    obj.rectangle3:setStrokeColor("#4A5365");
    obj.rectangle3:setStrokeSize(1);
    obj.rectangle3:setMargins({top=3,bottom=3});
    obj.rectangle3:setName("rectangle3");

    obj.edit3 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit3:setParent(obj.rectangle3);
    obj.edit3:setAlign("client");
    obj.edit3:setField("periciaDefesa");
    obj.edit3:setType("number");
    obj.edit3:setVertTextAlign("center");
    obj.edit3:setHorzTextAlign("center");
    obj.edit3:setName("edit3");
    obj.edit3:setFontSize(15);
    obj.edit3:setFontColor("white");
    obj.edit3:setTransparent(true);

    obj.rectangle4 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle4:setParent(obj);
    obj.rectangle4:setAlign("left");
    obj.rectangle4:setWidth(75);
    obj.rectangle4:setColor("#1B1F27");
    obj.rectangle4:setStrokeColor("#4A5365");
    obj.rectangle4:setStrokeSize(1);
    obj.rectangle4:setMargins({top=3,bottom=3});
    obj.rectangle4:setName("rectangle4");

    obj.edit4 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit4:setParent(obj.rectangle4);
    obj.edit4:setAlign("client");
    obj.edit4:setField("defesaAlvo");
    obj.edit4:setType("number");
    obj.edit4:setVertTextAlign("center");
    obj.edit4:setHorzTextAlign("center");
    obj.edit4:setName("edit4");
    obj.edit4:setFontSize(15);
    obj.edit4:setFontColor("white");
    obj.edit4:setTransparent(true);

    obj.rectangle5 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle5:setParent(obj);
    obj.rectangle5:setAlign("left");
    obj.rectangle5:setWidth(70);
    obj.rectangle5:setColor("#1B1F27");
    obj.rectangle5:setStrokeColor("#4A5365");
    obj.rectangle5:setStrokeSize(1);
    obj.rectangle5:setMargins({top=3,bottom=3});
    obj.rectangle5:setName("rectangle5");

    obj.edit5 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit5:setParent(obj.rectangle5);
    obj.edit5:setAlign("client");
    obj.edit5:setField("dano");
    obj.edit5:setVertTextAlign("center");
    obj.edit5:setHorzTextAlign("leading");
    obj.edit5:setMargins({left=4,right=4});
    obj.edit5:setName("edit5");
    obj.edit5:setFontSize(15);
    obj.edit5:setFontColor("white");
    obj.edit5:setTransparent(true);

    obj.rectangle6 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle6:setParent(obj);
    obj.rectangle6:setAlign("left");
    obj.rectangle6:setWidth(80);
    obj.rectangle6:setColor("#1B1F27");
    obj.rectangle6:setStrokeColor("#4A5365");
    obj.rectangle6:setStrokeSize(1);
    obj.rectangle6:setMargins({top=3,bottom=3});
    obj.rectangle6:setName("rectangle6");

    obj.edit6 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit6:setParent(obj.rectangle6);
    obj.edit6:setAlign("client");
    obj.edit6:setField("tipo");
    obj.edit6:setVertTextAlign("center");
    obj.edit6:setHorzTextAlign("leading");
    obj.edit6:setMargins({left=4,right=4});
    obj.edit6:setName("edit6");
    obj.edit6:setFontSize(15);
    obj.edit6:setFontColor("white");
    obj.edit6:setTransparent(true);

    obj.rectangle7 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle7:setParent(obj);
    obj.rectangle7:setAlign("left");
    obj.rectangle7:setWidth(100);
    obj.rectangle7:setColor("#1B1F27");
    obj.rectangle7:setStrokeColor("#4A5365");
    obj.rectangle7:setStrokeSize(1);
    obj.rectangle7:setMargins({top=3,bottom=3});
    obj.rectangle7:setName("rectangle7");

    obj.edit7 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit7:setParent(obj.rectangle7);
    obj.edit7:setAlign("client");
    obj.edit7:setField("qtMunicao");
    obj.edit7:setVertTextAlign("center");
    obj.edit7:setHorzTextAlign("center");
    obj.edit7:setName("edit7");
    obj.edit7:setFontSize(15);
    obj.edit7:setFontColor("white");
    obj.edit7:setTransparent(true);

    obj.button2 = GUI.fromHandle(_obj_newObject("button"));
    obj.button2:setParent(obj);
    obj.button2:setAlign("right");
    obj.button2:setWidth(25);
    obj.button2:setText("X");
    obj.button2:setFontColor("#E6140F");
    lfm_setPropAsString(obj.button2, "fontStyle", "bold");
    obj.button2:setName("button2");

    obj._e_event0 = obj.button1:addEventListener("onClick",
        function (event)
            rolarAtaque();
        end);

    obj._e_event1 = obj.button2:addEventListener("onClick",
        function (event)
            askForDelete();
        end);

    function obj:_releaseEvents()
        __o_rrpgObjs.removeEventListenerById(self._e_event1);
        __o_rrpgObjs.removeEventListenerById(self._e_event0);
    end;

    obj._oldLFMDestroy = obj.destroy;

    function obj:destroy() 
        self:_releaseEvents();

        if (self.handle ~= 0) and (self.setNodeDatabase ~= nil) then
          self:setNodeDatabase(nil);
        end;

        if self.rectangle5 ~= nil then self.rectangle5:destroy(); self.rectangle5 = nil; end;
        if self.button2 ~= nil then self.button2:destroy(); self.button2 = nil; end;
        if self.rectangle1 ~= nil then self.rectangle1:destroy(); self.rectangle1 = nil; end;
        if self.edit4 ~= nil then self.edit4:destroy(); self.edit4 = nil; end;
        if self.button1 ~= nil then self.button1:destroy(); self.button1 = nil; end;
        if self.edit3 ~= nil then self.edit3:destroy(); self.edit3 = nil; end;
        if self.rectangle6 ~= nil then self.rectangle6:destroy(); self.rectangle6 = nil; end;
        if self.rectangle2 ~= nil then self.rectangle2:destroy(); self.rectangle2 = nil; end;
        if self.edit7 ~= nil then self.edit7:destroy(); self.edit7 = nil; end;
        if self.edit2 ~= nil then self.edit2:destroy(); self.edit2 = nil; end;
        if self.rectangle7 ~= nil then self.rectangle7:destroy(); self.rectangle7 = nil; end;
        if self.rectangle3 ~= nil then self.rectangle3:destroy(); self.rectangle3 = nil; end;
        if self.edit1 ~= nil then self.edit1:destroy(); self.edit1 = nil; end;
        if self.rectangle4 ~= nil then self.rectangle4:destroy(); self.rectangle4 = nil; end;
        if self.edit6 ~= nil then self.edit6:destroy(); self.edit6 = nil; end;
        if self.image1 ~= nil then self.image1:destroy(); self.image1 = nil; end;
        if self.edit5 ~= nil then self.edit5:destroy(); self.edit5 = nil; end;
        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newfrmAtaquePrincipal()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_frmAtaquePrincipal();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _frmAtaquePrincipal = {
    newEditor = newfrmAtaquePrincipal, 
    new = newfrmAtaquePrincipal, 
    name = "frmAtaquePrincipal", 
    dataType = "", 
    formType = "undefined", 
    formComponentName = "form", 
    cacheMode = "none", 
    title = "", 
    description=""};

frmAtaquePrincipal = _frmAtaquePrincipal;
Firecast.registrarForm(_frmAtaquePrincipal);

return _frmAtaquePrincipal;
