require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_frmMainDaemon()
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
    obj:setName("frmMainDaemon");
    obj:setFormType("sheetTemplate");
    obj:setDataType("Ambesek.Daemon");
    obj:setTitle("Ficha Daemon");
    obj:setAlign("client");
    obj:setTheme("dark");


        



        local function isNewVersion(installed, downloaded)
            local installedVersion = {};
            local installedIndex = 0;
            for i in string.gmatch(installed, "[^%.]+") do
                installedIndex = installedIndex +1;
                installedVersion[installedIndex] = i;
            end

            local downloadedVersion = {};
            local downloadedIndex = 0;
            for i in string.gmatch(downloaded, "[^%.]+") do
                downloadedIndex = downloadedIndex +1;
                downloadedVersion[downloadedIndex] = i;
            end

            for i=1, math.min(installedIndex, downloadedIndex), 1 do 
                if (tonumber(installedVersion[i]) or 0) > (tonumber(downloadedVersion[i]) or 0) then
                    return false;
                elseif (tonumber(installedVersion[i]) or 0) < (tonumber(downloadedVersion[i]) or 0) then
                    return true;
                end;
            end;

            if downloadedIndex > installedIndex then
                return true;
            else
                return false;
            end;
        end;

        local function DoRollDamage(crit)
            sheet.rollDamage = false

            local rolagem = Firecast.interpretarRolagem(sheet.rollDamageValue or "")
            if crit then 
                rolagem = Firecast.interpretarRolagem(sheet.rollDamageValueCrit or "")
            end
            if rolagem.possuiAlgumDado then 
                local mesa = rrpg.getMesaDe(sheet);
                mesa.activeChat:rolarDados(rolagem, "Dano")
            else
                showMessage("No dice.")
            end
        end 

        local function DoRoll(rollText, rollCrit, rollTarget)
            local mesa = rrpg.getMesaDe(sheet);        
            mesa.activeChat:rolarDados("1d100", rollText,
                function (rolado)
                    if rolado.resultado <= rollCrit then
                        mesa.activeChat:enviarMensagem("SUCESSO CRÍTICO =D");
                        if sheet.rollDamage then 
                            DoRollDamage(true)
                        end
                    elseif rolado.resultado >= 95 then
                        mesa.activeChat:enviarMensagem("FALHA CRÍTICA =(");
                    elseif rolado.resultado <= rollTarget then
                        mesa.activeChat:enviarMensagem("SUCESSO =)");
                        if sheet.rollDamage then 
                            DoRollDamage(false)
                        end
                    else
                        mesa.activeChat:enviarMensagem("FALHA =/");
                    end;
                end);
        end

        local function AskToRoll(alternative)
            local text = sheet.rollText or ""
            local value = tonumber(sheet.rollValue) or 0

            local roll = {}
            roll[1] = (value*2)
            roll[2] = (value)
            roll[3] = math.floor(value/2)

            local crit = math.max(math.ceil(value/4),5)

            local options = {}
            options[1] = "Fácil: " .. roll[1]
            options[2] = "Normal: " .. roll[2]
            options[3] = "Difícil: " .. roll[3]

            local resist = sheet.atribResistido
            resist = (resist == true) or (resist == 1) or (resist == "true")
            local passivo = math.abs(tonumber(sheet.atribDefesa) or 0)

            Dialogs.choose("Selecione uma das opções. Crítico: " .. crit, options,
               function(selected, selectedIndex, selectedText)
                    if selected then
                        local rollText = text .. " " .. selectedText
                        local rollCrit = crit
                        local rollTarget = roll[selectedIndex]

                        if resist then
                            if alternative then
                                local ativo = math.floor(value/4)
                                rollTarget = ((ativo - passivo) * 5) + 50
                                rollText = text .. " " .. selectedText .. " [" .. ativo .. "-" .. passivo .. " Resistido = " .. rollTarget .. "%]"
                            else
                                rollTarget = rollTarget + 50 - passivo
                                rollText = rollText .. " [Resistido vs " .. passivo .. " = " .. rollTarget .. "%]"
                            end
                        end

                        DoRoll(rollText, rollCrit, rollTarget)
                    end;
               end)
        end

        local function RolarAtributo()
            local text = sheet.rollText or ""
            local value = tonumber(sheet.rollValue) or 0
            local crit = math.max(math.ceil(value/4),5)

            local resist = sheet.atribResistido
            resist = (resist == true) or (resist == 1) or (resist == "true")

            local raw, label, calcStr
            if resist then
                -- Atributo vs Atributo: dificuldade dobra/divide o ATRIBUTO, depois (ativo-passivo)*5+50
                local passivo = math.abs(tonumber(sheet.atribDefesa) or 0)
                local ativoBase = math.floor(value/4)
                local dif = string.lower(tostring(sheet.atribDificuldade or "normal"))
                local ativo, sufixo
                if dif == "facil" then
                    ativo = ativoBase * 2; sufixo = "Fácil"
                elseif dif == "dificil" then
                    ativo = math.floor(ativoBase / 2); sufixo = "Difícil"
                else
                    ativo = ativoBase; sufixo = "Normal"
                end
                raw = ((ativo - passivo) * 5) + 50
                label = " vs " .. passivo .. " " .. sufixo
                calcStr = "(" .. ativo .. "-" .. passivo .. ")] = " .. raw .. "%"
            else
                local dif = string.lower(tostring(sheet.atribDificuldade or "normal"))
                if dif == "facil" then
                    raw = value*2; label = " Fácil"
                elseif dif == "dificil" then
                    raw = math.floor(value/2); label = " Difícil"
                else
                    raw = value; label = " Normal"
                end
                calcStr = raw .. "%]"
            end

            local rollText = text .. label .. " [" .. calcStr .. " (Crit " .. crit .. ")"

            local mesa = rrpg.getMesaDe(sheet);

            if raw > 100 then
                mesa.activeChat:enviarMensagem(rollText .. "  => SUCESSO AUTOMATICO =D");
                return;
            elseif raw <= 0 then
                mesa.activeChat:enviarMensagem(rollText .. "  => FALHA AUTOMATICA =(");
                return;
            end

            local rollTarget = raw
            mesa.activeChat:rolarDados("1d100", rollText,
                function (rolado)
                    local r = rolado.resultado
                    if r > 95 then
                        mesa.activeChat:enviarMensagem("FALHA CRÍTICA =(");
                    elseif r <= crit then
                        mesa.activeChat:enviarMensagem("SUCESSO CRÍTICO =D");
                        if sheet.rollDamage then DoRollDamage(true) end
                    elseif r <= rollTarget then
                        mesa.activeChat:enviarMensagem("SUCESSO =)");
                        if sheet.rollDamage then DoRollDamage(false) end
                    else
                        mesa.activeChat:enviarMensagem("FALHA =/");
                    end;
                end);
        end

        -- DEBUG FUNCTIONS

        local function dump(o)
           if type(o) == 'table' then
              local s = '{ '
              for k,v in pairs(o) do
                 if type(k) ~= 'number' then k = '"'..k..'"' end
                 s = s .. '['..k..'] = ' .. dump(v) .. ','
              end
              return s .. '} '
           else
              return tostring(o)
           end
        end
        
        local DANO = {
            ["Espada Longa"] = "1d10",
            ["Espada Curta"] = "1d6",
            ["Espada Bastarda"] = "1d10",
            ["Sabre"] = "1d6+2",
            ["Cimitarra Curta"] = "1d6",
            ["Adaga"] = "1d3",
            ["Punhal"] = "1d3",
            ["Waqqif"] = "1d3+1",
            ["Machado de Combate"] = "1d6+3",
            ["Cajado"] = "1d6",
            ["Martelo"] = "1d6",
            ["Lanca"] = "1d10",
            ["Lanca de Justa"] = "1d6",
            ["Arco Longo"] = "1d6+2",
            ["Arco"] = "1d6",
            ["Zarabatana"] = "1",
        }

        local _kitSeq = 0
        local function _kitNome()
            _kitSeq = _kitSeq + 1
            return "kit" .. tostring(os.time()) .. "_" .. tostring(_kitSeq) .. "_" .. tostring(math.random(1000,9999))
        end

        local function _kitAtr(r, n)
            return (tonumber(r[n.."Base"]) or 0) + (tonumber(r[n.."Mod"]) or 0)
        end

        local function _kitArma(r, sel, nome, atk, def, tipo)
            local nd = NDB.createChildNode(r.equipamentos.ataques, _kitNome())
            if nd == nil then return end
            nd.kit = sel
            nd.nome = nome
            nd.periciaArma = atk
            nd.periciaDefesa = def
            nd.dano = DANO[nome] or ""
        end

        local function _kitPericia(r, sel, nome, valor)
            local nd = NDB.createChildNode(r.pericias, _kitNome())
            if nd == nil then return end
            nd.kit = sel
            nd.nome = nome
            nd.atributo = "none"
            nd.constituicao = _kitAtr(r,"constituicao"); nd.forca = _kitAtr(r,"forca"); nd.destreza = _kitAtr(r,"destreza")
            nd.agilidade = _kitAtr(r,"agilidade"); nd.inteligencia = _kitAtr(r,"inteligencia"); nd.vontade = _kitAtr(r,"vontade")
            nd.percepcao = _kitAtr(r,"percepcao"); nd.carisma = _kitAtr(r,"carisma")
            nd.gasto = valor
        end

        local DESC = {
            ["pontos de fe"] = [==[APRIMORAMENTO — PONTOS DE FÉ

Em termos de jogo, a Fé representa os pequenos milagres que um personagem dedicado pode alcançar através da devoção a uma entidade. Qualquer divindade maior de Arton — assim como as várias divindades menores deste mundo — pode conceder estes pequenos milagres a seus adoradores.

Este aprimoramento é obrigatório para personagens clérigos, paladinos ou devotos fervorosos de alguma divindade específica.

1 ponto: Seguidor. 1 ponto de Fé + 1 a cada 2 níveis.
2 pontos: Fiel. 2 pontos de Fé + 1 a cada 2 níveis.
3 pontos: Entusiasta. 3 pontos de Fé + 1 por nível.
4 pontos: Fanático. 5 pontos de Fé + 1 por nível.
5 pontos: Radical. 7 pontos de Fé + 1 por nível.]==],
            ["pontos heroicos"] = [==[PONTOS HERÓICOS

Pontos heróicos funcionam como uma medida abstrata de heroísmo. Não são exatamente pontos de vida extras, mas funcionam na maioria dos casos como tal. São uma espécie de "aura heróica" ou "sorte" que protege o corpo do Personagem de dano quando executa atos de herói (pular de um prédio para outro, ser arrastado por um cavalo, levar seis tiros em uma rodada, enfrentar mais de 2 oponentes ao mesmo tempo e outros atos que humanos normais não conseguiriam fazer saindo inteiros).

POR QUE PONTOS HERÓICOS?
O Sistema Daemon foi desenvolvido para ambientes realistas, onde os humanos são "frágeis" e o dano é mortal — interessante para um RPG de horror (Trevas, Arkanun, Invasão), mas isso impedia os Narradores de envolverem seus Personagens em Campanhas de Ação e Aventura. Os pontos heróicos resolvem isso.

COMO FUNCIONAM?
Funcionam como Pontos de Vida a mais que o personagem possui, mas que só podem ser usados quando ele realiza um ato heróico. O uso não conta como ação na rodada, mas há direito a apenas UMA utilização por rodada. NÃO podem ser usados em condições não-heróicas (dormindo e cortarem sua garganta, comer algo envenenado, levar um tiro pelas costas etc.). A regra do bom senso vale para casos omissos. SEMPRE que possível, é aconselhado usar pelo menos parte dos PHs para absorver dano; o que não for absorvido é dano normal.

QUANDO USAR E QUANDO NÃO USAR
O Narrador decide se permite PHs na campanha. Campanhas de ação/aventura devem usá-los; campanhas de suspense podem desconsiderá-los. Uma vez que os PJs possuam PHs, vilões e NPCs que o Narrador julgar válidos TAMBÉM os terão. PHs estão ligados à capacidade de realizar atos sobre-humanos ou corajosos, não necessariamente "heróicos".

RECUPERANDO PONTOS HERÓICOS
Um humano normal (3D em Força de Vontade) recupera 1 PH a cada 8 horas — é 1 PH por dia por dado de Força de Vontade. A recuperação é independente da de pontos de fé ou de vida. Existem rituais, poderes e efeitos raros que conferem PHs extras temporariamente, e mais raros ainda os que RECUPERAM PHs.

NÍVEIS DO APRIMORAMENTO
1 ponto: Corajoso. 3 PHs iniciais. +1 PH a cada nível. Até 2 PHs por rodada.
2 pontos: Valoroso. 6 PHs iniciais. +1 PH a cada nível. Até 4 PHs por rodada.
3 pontos: Intrépido. 9 PHs iniciais. +1 PH a cada nível. Até 6 PHs por rodada.
4 pontos: Herói. 12 PHs iniciais. +1 PH a cada nível. Até 8 PHs por rodada.
5 pontos: Bárbaro. 15 PHs iniciais. +1 PH a cada nível. Até 10 PHs por rodada.
6 pontos: Super. 18 PHs iniciais. +1 PH a cada nível. Até 12 PHs por rodada.

PONTOS HERÓICOS SOBRENATURAIS
Personagens com background ligado ao sobrenatural (antepassado sobrenatural, superpoderes) podem ter um tipo novo: os PHs sobrenaturais. Usados como os normais, mas contam como aprimoramento diferente — o Personagem pode ter 2, 3 ou 4 pontos em cada um, ultrapassando o limite inicial de 5 por nível. Aptos: filhos de Marte e aliens, lobisomens, vampiros e mortos-vivos, demônios, anjos, dragões, seres de Arcádia, raças de fantasia medieval/futurista, supers e descendentes. O Narrador tem a palavra final.

NOVAS REGRAS
PHs normalmente são pontos de vida extra, mas também servem como "energia" para realizar atos heróicos. Inicialmente o Personagem só converte PH em PV; com o avanço de nível aprende outros esforços, na razão de UM esforço heróico novo por nível (independente de kit ou de o kit ser heróico). Colisões entre esforços (acerto de ataque x acerto de esquiva) se cancelam. Em TODOS os efeitos, como padrão Daemon, arredonde os valores quebrados para CIMA.

ESFORÇOS HERÓICOS
- Ataque extra — 2 PHs: realiza UM ataque extra na rodada (regras de múltiplos ataques).
- Acerto automático (ataque) — 1 PH por 3 níveis do defensor: acerta sem teste. Não vale para "ataque extra".
- Acerto automático (defesa) — 1 PH por 3 níveis do atacante: acerta sem teste.
- Acerto automático (esquiva) — 1 PH por 2 níveis do atacante: acerta sem teste.
- Aumento de Atributo (AGI/CON/DES/FOR/Iniciativa/Índice de Proteção) — variável: +X no atributo até o fim da cena (X = PHs gastos).
- Bônus em combate (ataque) — variável: +5% por PH gasto, até o fim da cena.
- Bônus em combate (defesa) — variável: +10% por PH gasto, até o fim da cena.
- Bônus em combate (esquiva) — variável: +5% por PH gasto, até o fim da cena.
- Defesa extra — 1 PH por defesa: uma ou mais defesas extras na rodada.
- Esquiva extra — 2 PHs por esquiva: uma ou mais esquivas extras na rodada.
- Resistência à magia (dano) — 2 PHs por dado: +Xd6 na absorção de dano mágico até o fim da cena (X = metade dos PHs gastos).
- Resistência à magia (efeito) — 1 PH por 5%: +X% em resistência a efeitos mágicos/sobrenaturais.
- Salto — 1 PH por 3 metros (altura ou distância): grande/longo salto.
- Teste de Resistência (AGI/CON/Força de Vontade) — 1 PH por 2 níveis do ofensor: acerta sem rolar.
- Teste Físico (Camuflagem/Escapismo/Esportes/Furtividade) — 2 PHs: acerta o teste sem rolar.
- Trocar PHs por PMs — 2 PHs para 1 PM.
- Trocar PHs por PsFé — 3 PHs para 2 PsFé.]==],
            ["sortudo"] = [==[SORTUDO
2 pontos: o Personagem é portador de uma sorte incrível. Uma vez por sessão de jogo, o Jogador pode rolar novamente um dado caso tenha falhado em um Teste (qualquer tipo de rolagem). Deve anunciar essa decisão ANTES de rolar os dados — se conseguir logo na primeira tentativa, mesmo assim terá gasto a "sorte" da sessão.
3 pontos: você tem o direito de declarar que um rolamento teve acerto crítico, uma vez por sessão de jogo. Essa decisão deve ser tomada antes de rolar os dados.]==],
            ["alma pura"] = [==[ALMA PURA
Apenas para Personagens cristãos.
2 pontos: Nenhum demônio é capaz de chegar perto do Personagem, muito menos tocá-lo ou atacá-lo enquanto ele mantiver a alma limpa (sem nenhum pecado). O demônio pode permanecer na mesma sala ou dialogar com ele, mas será incapaz de atacá-lo fisicamente. Caso o Personagem quebre algum dos dez mandamentos, sua alma fica maculada por, no mínimo, uma semana e um dia, e os demônios podem atacá-lo nesse período. Ele deve se confessar e pagar a penitência adequada para recuperar a pureza. Magias demoníacas sofrem um redutor de 4D em relação ao Personagem enquanto este mantiver a alma pura.]==],
            ["cacador de demonios"] = [==[CAÇADOR DE DEMÔNIOS OU ANJOS
O Personagem tem a "missão" de caçar e exterminar Anjos ou Demônios por um motivo qualquer (vingança, ódio, dinheiro, um juramento). Passará a vida atrás desse objetivo e sempre se aliará a outros caçadores.
1 ponto: possui Conhecimentos sobre a criatura que caça (Anjos ou Demônios) com até 30%, além de saber como encontrá-los e destruí-los.
2 pontos: Conhecimentos sobre o tipo de criatura com 45%, e conhece outros caçadores. Pode pertencer a uma Sociedade Secreta com este fim (os Magos Atlantes, os Templários, a AGNI ou os Hiotas).]==],
            ["poderes magicos"] = [==[PODERES MÁGICOS
1 ponto: começou a estudar as artes arcanas há muito pouco tempo. Possui 2 pontos de Focus e 1 ponto de Magia.
2 pontos: possui alguns conhecimentos de Magia. 3 pontos de Focus para dividir entre os caminhos que desejar. Começa com 2 pontos de Magia.
3 pontos: Mago. Já praticava as artes arcanas há algum tempo. Começa com 5 pontos de Focus e 3 pontos de Magia.
4 pontos: Mago desenvolvido. 7 pontos de Focus para dividir entre os caminhos, e pelo menos um inimigo mortal a mais (a cargo do Mestre). Possui 5 pontos de Magia.
5 pontos: personagens mais velhos, com muito poder e conhecimento acumulado. Pelo menos DOIS inimigos mortais a mais (a cargo do Mestre). Dispõe de 9 pontos de Focus e 7 pontos de Magia.]==],
            ["contatos e aliados"] = [==[CONTATOS E ALIADOS
Os aliados podem morrer com o tempo; quando isso ocorre, assume-se que o Personagem conseguiu outro aliado no mesmo ramo, ou passou a conhecer um descendente/sucessor. Os contatos têm seus próprios problemas e nem sempre estão à disposição; ocasionalmente cobram favores ou pedem ajuda (fonte de aventuras para o Mestre). Cada Ponto de Contato equivale a alguns pequenos contatos (o Jogador especifica quais) ou a um contato importante (NPC). Cada subgrupo é comprado separadamente.
1 ponto: um aliado importante.
2 pontos: dois aliados importantes.
3 pontos: quatro aliados importantes.
4 pontos: oito aliados importantes.]==],
            ["sociedade secreta"] = [==[SOCIEDADE SECRETA
Obrigatório se o Personagem deseja pertencer ao Arkanun Arcanorum, Escola de Magia ou Ordem de Cavaleiros. Por suas habilidades, você foi recrutado por uma Ordem Mística, onde será treinado e refinará suas aptidões. Como membro, recebe regalias e inimigos. Existem várias ordens (de magos e de cavaleiros); consulte o Mestre sobre benefícios e malefícios de cada uma.
1 ponto: pertence à Sociedade como membro dos círculos externos ou aprendizes.
2 pontos: já possui maior influência, pertencendo aos círculos mais internos (talvez com algum título importante).]==],
            ["biblioteca"] = [==[BIBLIOTECA
O Personagem possui uma vasta biblioteca em seu refúgio (herança, roubada, adquirida ou criada por ele). Se puder consultá-la, ela aumenta seus conhecimentos em alguns assuntos — apenas conhecimentos estudados em livros. Em termos de jogo, triplica (até no máximo 90%) o valor de alguns Subgrupos de Perícias ligados a conhecimentos, especificados na criação do Personagem (podem ser de várias Perícias diferentes).
1 ponto: 2 Subgrupos de Perícias.
2 pontos: 6 Subgrupos.
3 pontos: 10 Subgrupos.
4 pontos: 14 Subgrupos.]==],
            ["recursos"] = [==[RECURSOS E DINHEIRO
Quanto de dinheiro, joias e posses o Personagem reuniu ao longo da vida, incluindo propriedades e fontes de renda que levam tempo para virar dinheiro. Os valores estão em dólares (época atual) e florins (campanhas medievais), ajustáveis conforme a época/local. O Personagem possui ao todo cerca de 50 vezes o valor de sua renda.
1 ponto: renda de até US$ 2.000 (ou 100 florins) mensais.
2 pontos: até US$ 4.000 (ou 200 florins).
3 pontos: até US$ 8.000 (ou 400 florins).
4 pontos: até US$ 16.000 (ou 800 florins).
5 pontos: até US$ 32.000 (ou 1.600 florins).]==],
            ["clero"] = [==[CLERO
1 ponto: o Personagem é um padre ou clérigo responsável por um pequeno templo em um vilarejo ou cidade pequena, encarregado dos fiéis e da organização da comunidade.
2 pontos: é um bispo/clérigo responsável por uma região ou condado, com um templo de tamanho razoável em uma cidade maior; cuida de assuntos mais amplos (como organizar paladinos para missões) e supervisiona os padres da região.
3 pontos: é um arcebispo ou alto sacerdote responsável por grande área e os vários templos nela, com notória influência sobre a política regional.]==],
            ["inocencia"] = [==[INOCÊNCIA
1 ponto: o Personagem tem uma habilidade quase sobrenatural de passar a impressão de ser inocente em qualquer acusação sem testemunhas. Arruma álibis com facilidade, provando que "comprou aquela bolsa na feira local" ou que outra pessoa arrombou a porta.
2 pontos: como o anterior, mas até uma testemunha pode se convencer de que se enganou ao acusá-lo (Teste Normal de Lábia). Também torna Difíceis todos os Testes de Interrogatório contra ele.]==],
        }
        DESC["aliados e contatos"] = DESC["contatos e aliados"]
        DESC["contatos"] = DESC["contatos e aliados"]
        local function _apBase(nome)
            local b = tostring(nome or "")
            b = b:gsub("%s+%d+%s*$", "")
            b = b:gsub("^%s+", ""):gsub("%s+$", "")
            return string.lower(b)
        end

        local function _kitAprim(r, sel, nome)
            local nd = NDB.createChildNode(r.aprimoramentos, _kitNome())
            if nd == nil then return end
            nd.kit = sel
            nd.nome = nome
            nd.custo = 0
            nd.descricao = DESC[_apBase(nome)] or ""
        end

        local function _kitLimpaLista(lista)
            local nodes = NDB.getChildNodes(lista)
            local apagar = {}
            for i=1, #nodes do
                local k = nodes[i].kit
                if k ~= nil and k ~= "" then apagar[#apagar+1] = nodes[i] end
            end
            for i=1, #apagar do NDB.deleteNode(apagar[i]) end
        end

        local function _racaLimpar(r)
            local function limpar(lista)
                local nds = NDB.getChildNodes(lista)
                local apagar = {}
                for i=1, #nds do
                    if nds[i].raca == true then apagar[#apagar+1] = nds[i] end
                end
                for i=1, #apagar do NDB.deleteNode(apagar[i]) end
            end
            limpar(r.pericias)
            limpar(r.periciasArmas)
            limpar(r.equipamentos.ataques)
        end

        local function _racaArma(r, sel, nome, atk, def, tipo)
            local nd = NDB.createChildNode(r.equipamentos.ataques, _kitNome())
            if nd == nil then return end
            nd.raca = true
            nd.nome = nome .. " (racial)"
            nd.periciaArma = atk
            nd.periciaDefesa = def
            nd.dano = DANO[nome] or ""
        end

        local function _racaPericia(r, sel, nome, valor)
            local nd = NDB.createChildNode(r.pericias, _kitNome())
            if nd == nil then return end
            nd.raca = true
            nd.nome = nome
            nd.atributo = "none"
            nd.constituicao = _kitAtr(r,"constituicao"); nd.forca = _kitAtr(r,"forca"); nd.destreza = _kitAtr(r,"destreza")
            nd.agilidade = _kitAtr(r,"agilidade"); nd.inteligencia = _kitAtr(r,"inteligencia"); nd.vontade = _kitAtr(r,"vontade")
            nd.percepcao = _kitAtr(r,"percepcao"); nd.carisma = _kitAtr(r,"carisma")
            nd.gasto = valor
        end

        local function _kitLimpar(r)
            _kitLimpaLista(r.pericias)
            _kitLimpaLista(r.periciasArmas)
            _kitLimpaLista(r.equipamentos.ataques)
            _kitLimpaLista(r.aprimoramentos)
            r.ptsKitPericia = 0
            r.ptsKitAprim = 0
        end

        local KITS = {
            ["guerreiro"] = { p=200, a=2, ap={"Pontos Heroicos 4"}, armas={{"Espada Longa",40,40,"cac"}, {"Machado de Combate",30,20,"cac"}, {"Escolha outra arma",20,10,"cac"}}, per={{"Escolha uma manobra de combate",50}, {"Manipulacao (Intimidacao)",20}, {"Montaria",20}, {"Sobrevivencia (escolha um ambiente)",30}} },
            ["ranger"] = { p=240, a=2, ap={"Pontos Heroicos 4"}, armas={{"Arco Longo",40,0,"dist"}, {"Espada Curta",30,30,"cac"}, {"Adaga",0,20,"cac"}}, per={{"Armadilhas",20}, {"Camuflagem",20}, {"Ciencias (Herbalismo)",10}, {"Furtividade",20}, {"Montaria",30}, {"Rastreio",30}, {"Sobrevivencia (Floresta)",40}} },
            ["guardacostas"] = { p=230, a=2, ap={"Pontos Heroicos 4"}, armas={{"Espada Curta",40,30,"cac"}, {"Adaga",40,20,"cac"}, {"Escolha outra arma",0,30,"cac"}}, per={{"Manobra de Combate (Luta as Cegas)",40}, {"Etiqueta",30}, {"Manipulacao (Intimidacao)",20}, {"Montaria",30}, {"Sobrevivencia (escolha um ambiente)",30}} },
            ["cacadorrecompensas"] = { p=260, a=2, ap={"Pontos Heroicos 4"}, armas={{"Escolha uma arma",30,30,"cac"}}, per={{"Armadilhas",30}, {"Arrombamento",20}, {"Camuflagem",20}, {"Disfarce",20}, {"Furtar",15}, {"Furtividade",25}, {"Manipulacao (Interrogatorio)",25}, {"Manipulacao (Intimidacao)",25}, {"Manipulacao (Labia)",20}, {"Investigacao",40}, {"Rastreio",40}, {"Sobrevivencia (escolha um ambiente)",10}, {"Subterfugio",20}} },
            ["arqueiro"] = { p=200, a=2, ap={"Pontos Heroicos 4"}, armas={{"Escolha um Arco",40,0,"dist"}, {"Espada Curta",20,20,"cac"}}, per={{"Camuflagem",20}, {"Ciencias (Herbalismo)",20}, {"Escutar",30}, {"Furtividade",20}, {"Montaria",30}, {"Rastreio",20}, {"Sobrevivencia (Floresta)",20}} },
            ["paladino"] = { p=380, a=4, ap={"Pontos Heroicos 4", "Pontos de Fe 1", "Sortudo", "Alma Pura", "Status"}, armas={{"Espada Longa",40,40,"cac"}, {"Lanca",40,25,"cac"}, {"Adaga",40,30,"cac"}}, per={{"Etiqueta",30}, {"Heraldica",20}, {"Idiomas (Idioma Nativo)",20}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Latim)",30}, {"Legislacao",30}, {"Manipulacao (Empatia)",20}, {"Manipulacao (Intimidacao)",20}, {"Manipulacao (Lideranca)",20}, {"Montaria",30}, {"Rastreio",20}, {"Religiao",30}, {"Sobrevivencia (Floresta)",20}, {"Sobrevivencia (Montanha)",30}, {"Esquiva",25}} },
            ["mercenario"] = { p=210, a=2, ap={"Pontos Heroicos 4"}, armas={{"Espada Longa",40,40,"cac"}, {"Adaga",20,20,"cac"}, {"Escolha outra arma",20,20,"cac"}}, per={{"Armadilhas",20}, {"Investigacao",20}, {"Manipulacao (Interrogatorio)",20}, {"Primeiros Socorros",20}, {"Rastreio",20}, {"Sobrevivencia (escolha um ambiente)",30}} },
            ["cavaleiro"] = { p=250, a=2, ap={"Pontos Heroicos 4"}, armas={{"Lanca de Justa",40,40,"cac"}, {"Espada Curta",30,20,"cac"}, {"Adaga",20,10,"cac"}}, per={{"Etiqueta",50}, {"Heraldica",50}, {"Ciencias (Historia)",20}, {"Idiomas (Idioma Nativo)",20}, {"Montaria",30}, {"Religiao",20}} },
            ["ladrao"] = { p=250, a=2, ap={"Pontos Heroicos 3"}, armas={{"Adaga",40,20,"cac"}}, per={{"Armadilhas",30}, {"Arrombamento",30}, {"Barganha",10}, {"Camuflagem",20}, {"Disfarce",20}, {"Escapismo",30}, {"Escutar",20}, {"Falsificacao",20}, {"Furtar",40}, {"Furtividade",30}, {"Joalheria",20}, {"Subterfugio",30}} },
            ["ladraotumbas"] = { p=250, a=2, ap={"Pontos Heroicos 3"}, armas={{"Adaga",30,30,"cac"}}, per={{"Armadilhas",40}, {"Arrombamento",30}, {"Barganha",10}, {"Camuflagem",20}, {"Ciencias (Historia)",40}, {"Escapismo",20}, {"Furtar",20}, {"Investigacao",20}, {"Joalheria",20}, {"Linguas Antigas",30}, {"Pesquisa",30}, {"Subterfugio",20}} },
            ["jogador"] = { p=220, a=2, ap={"Pontos Heroicos 2", "Contatos e Aliados 1"}, armas={{"Adaga",20,30,"cac"}}, per={{"Barganha",20}, {"Etiqueta",20}, {"Falsificacao",40}, {"Intimidacao",20}, {"Jogos de Azar",50}, {"Manipulacao (Empatia)",50}, {"Manipulacao (Labia)",30}, {"Subterfugio",30}} },
            ["menestrel"] = { p=220, a=3, ap={"Pontos Heroicos 1", "Contatos e Aliados 2"}, armas={}, per={{"Atuacao",40}, {"Camuflagem",20}, {"Ciencias (Historia)",30}, {"Disfarce",20}, {"Etiqueta",40}, {"Idiomas (Idioma Nativo)",20}, {"Idiomas (Ler e Escrever)",20}, {"Instrumento Musical",50}, {"Investigacao",10}, {"Manipulacao (Labia)",20}, {"Manipulacao (Seducao)",20}, {"Subterfugio",20}} },
            ["menestrelsombrio"] = { p=250, a=3, ap={"Poderes Magicos 1", "Pontos Heroicos 1", "Aliados e Contatos 1"}, armas={}, per={{"Atuacao",40}, {"Camuflagem",20}, {"Ciencias (Historia)",20}, {"Disfarce",30}, {"Etiqueta",30}, {"Falsificacao",20}, {"Idiomas (Idioma Nativo)",20}, {"Idiomas (Ler e Escrever)",20}, {"Instrumento Musical",50}, {"Investigacao",20}, {"Manipulacao (Labia)",30}, {"Manipulacao (Seducao)",30}, {"Subterfugio",20}} },
            ["espiao"] = { p=330, a=3, ap={"Pontos Heroicos 2", "Aliados e Contatos 2", "Sociedade Secreta 1"}, armas={{"Punhal",20,30,"cac"}}, per={{"Arrombamento",40}, {"Camuflagem",40}, {"Disfarce",40}, {"Escapismo",30}, {"Escutar",50}, {"Etiqueta",20}, {"Falsificacao",20}, {"Interrogatorio",30}, {"Manipulacao (Labia)",30}, {"Manipulacao (Tortura)",20}, {"Primeiros Socorros",20}, {"Subterfugio",20}} },
            ["contrabandista"] = { p=200, a=2, ap={"Pontos Heroicos 1", "Aliados e Contatos 3"}, armas={}, per={{"Barganha",50}, {"Empatia",30}, {"Escutar",30}, {"Etiqueta",20}, {"Falsificacao",40}, {"Joalheria",30}, {"Manipulacao (Labia)",30}, {"Navegacao",20}, {"Subterfugio",30}} },
            ["assassino"] = { p=230, a=2, ap={"Pontos Heroicos 2", "Aliados e Contatos 1"}, armas={{"Punhal",30,10,"cac"}, {"Zarabatana",20,0,"dist"}}, per={{"Armadilhas",20}, {"Arrombamento",30}, {"Camuflagem",30}, {"Disfarce",30}, {"Escapismo",20}, {"Falsificacao",10}, {"Furtar",10}, {"Furtividade",30}, {"Sobrevivencia (escolha um ambiente)",20}, {"Subterfugio",10}, {"Venenos",30}} },
            ["alquimista"] = { p=280, a=3, ap={"Poderes Magicos 1", "Pontos Heroicos 1", "Aliados e Contatos 1", "Biblioteca 1", "Recursos 1"}, armas={}, per={{"Barganha",40}, {"Ciencias (Herbalismo)",40}, {"Ciencias Proibidas (Alquimia)",50}, {"Ciencias Proibidas (Cabala)",30}, {"Ciencias Proibidas (Ocultismo)",30}, {"Ciencias Proibidas (Rituais)",30}, {"Idiomas (Hebraico)",20}, {"Idiomas (Ler e Escrever Idioma Nativo)",25}, {"Idiomas (Ler e Escrever Hebraico)",35}, {"Medicina",25}, {"Primeiros Socorros",25}, {"Subterfugio",20}, {"Venenos",30}} },
            ["mercador"] = { p=190, a=2, ap={"Pontos Heroicos 1", "Recursos 3"}, armas={}, per={{"Artes (Atuacao)",10}, {"Barganha",50}, {"Ciencias (Historia)",10}, {"Escutar",10}, {"Etiqueta",30}, {"Falsificacao",10}, {"Joalheria",40}, {"Manipulacao (Empatia)",30}, {"Manipulacao (Labia)",30}, {"Pesquisa",10}, {"Religiao",10}, {"Subterfugio",20}} },
            ["herbalista"] = { p=200, a=3, ap={"Poderes Magicos 2", "Pontos Heroicos 1", "Aliados e Contatos"}, armas={}, per={{"Armadilhas",40}, {"Barganha",30}, {"Ciencias (Herbalismo)",50}, {"Ciencias (Historia)",20}, {"Ciencias Proibidas (Rituais)",20}, {"Etiqueta",10}, {"Heraldica",10}, {"Medicina",20}, {"Primeiros Socorros",20}, {"Sobrevivencia (Floresta)",40}, {"Subterfugio",20}} },
            ["padre"] = { p=190, a=2, ap={"Pontos de Fe 2", "Clero 1", "Recursos 1"}, armas={}, per={{"Barganha",30}, {"Burocracia",10}, {"Ciencias (Historia)",20}, {"Escutar",10}, {"Etiqueta",20}, {"Heraldica",10}, {"Idiomas (Latim)",30}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Ler e Escrever Latim)",20}, {"Manipulacao (Empatia)",30}, {"Manipulacao (Interrogatorio)",20}, {"Religiao",50}} },
            ["druida"] = { p=240, a=3, ap={"Poderes Magicos 2", "Pontos Heroicos 1", "Sociedade Secreta 1"}, armas={{"Cajado",30,30,"cac"}}, per={{"Camuflagem",25}, {"Ciencias (Herbalismo)",20}, {"Ciencias (Teologia)",15}, {"Ciencias Proibidas (Alquimia)",25}, {"Ciencias Proibidas (Astrologia)",20}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Teoria da Magia)",25}, {"Linguagem Secreta",30}, {"Manipulacao (Intimidacao)",20}, {"Navegacao",20}, {"Pesquisa",40}} },
            ["pyros"] = { p=230, a=3, ap={"Poderes Magicos 2"}, armas={{"Escolha uma arma",40,40,"cac"}}, per={{"Armadilhas",20}, {"Ciencias Proibidas (Alquimia)",10}, {"Ciencias Proibidas (Ocultismo)",30}, {"Ciencias Proibidas (Rituais)",30}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Escolha outro Idioma)",30}, {"Manipulacao (Interrogatorio)",20}, {"Manipulacao (Intimidacao)",20}, {"Religiao",30}, {"Sobrevivencia (escolha um ambiente)",30}} },
            ["magosvermelhos"] = { p=210, a=3, ap={"Poderes Magicos 2"}, armas={{"Escolha uma arma",40,40,"cac"}}, per={{"Armadilhas",20}, {"Ciencias Proibidas (Alquimia)",10}, {"Ciencias Proibidas (Ocultismo)",30}, {"Ciencias Proibidas (Rituais)",30}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Escolha outro Idioma)",30}, {"Manipulacao (Interrogatorio)",10}, {"Religiao",30}, {"Sobrevivencia (escolha um ambiente)",30}} },
            ["magosaquos"] = { p=210, a=3, ap={"Poderes Magicos 2", "Pontos de Fe 1"}, armas={}, per={{"Ciencias (Herbalismo)",10}, {"Ciencias Proibidas (Alquimia)",40}, {"Ciencias Proibidas (Arkanun)",30}, {"Ciencias Proibidas (Astrologia)",20}, {"Ciencias Proibidas (Ocultismo)",40}, {"Ciencias Proibidas (Rituais)",40}, {"Ciencias Proibidas (Teoria da Magia)",30}, {"Esportes (Natacao)",30}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Navegacao",10}} },
            ["magosatlantes"] = { p=190, a=3, ap={"Poderes Magicos 2"}, armas={}, per={{"Ciencias (Historia)",30}, {"Ciencias Proibidas (Alquimia)",20}, {"Ciencias Proibidas (Astrologia)",30}, {"Ciencias Proibidas (Atlandida)",50}, {"Ciencias Proibidas (Ocultismo)",40}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Teoria da Magia)",30}, {"Esportes (Natacao)",30}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}} },
            ["yamesh"] = { p=290, a=3, ap={"Poderes Magicos 2", "Pontos de Fe 1"}, armas={}, per={{"Artes (Desenho e Pintura)",10}, {"Ciencias (Herbalismo)",10}, {"Ciencias (Historia)",30}, {"Ciencias Proibidas (Alquimia)",20}, {"Ciencias Proibidas (Astrologia)",20}, {"Ciencias Proibidas (Encantamentos)",20}, {"Ciencias Proibidas (Ocultismo)",40}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Tarot)",30}, {"Ciencias Proibidas (Teoria da Magia)",30}, {"Etiqueta",10}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Latim)",30}, {"Idiomas (Ler e Escrever Latim)",30}, {"Linguagem Secreta",30}, {"Religiao",30}} },
            ["luft"] = { p=250, a=3, ap={"Poderes Magicos 2"}, armas={{"Cajado",30,30,"cac"}}, per={{"Camuflagem",25}, {"Ciencias (Herbalismo)",20}, {"Ciencias (Teologia)",15}, {"Ciencias Proibidas (Alquimia)",35}, {"Ciencias Proibidas (Astrologia)",20}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Teoria da Magia)",25}, {"Etiqueta",10}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Linguagem Secreta",30}, {"Manipulacao (Intimidacao)",20}, {"Navegacao",20}, {"Pesquisa",40}} },
            ["vacuo"] = { p=250, a=3, ap={"Poderes Magicos 2", "Inocencia 1"}, armas={{"Adaga",30,30,"cac"}}, per={{"Camuflagem",25}, {"Ciencias (Historia)",20}, {"Ciencias (Teologia)",15}, {"Ciencias Proibidas (Alquimia)",25}, {"Ciencias Proibidas (Astrologia)",10}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Teoria da Magia)",25}, {"Esportes (Natacao)",30}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Linguagem Secreta",30}, {"Investigacao",20}, {"Manipulacao (Interrogatorio)",20}, {"Manipulacao (Intimidacao)",20}, {"Pesquisa",30}} },
            ["tempestade"] = { p=270, a=3, ap={"Poderes Magicos 2"}, armas={{"Martelo",40,40,"cac"}, {"Adaga",20,20,"cac"}}, per={{"Ciencias (Herbalismo)",10}, {"Ciencias (Teologia)",15}, {"Ciencias Proibidas (Alquimia)",25}, {"Ciencias Proibidas (Astrologia)",20}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Teoria da Magia)",25}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Linguagem Secreta",30}, {"Manipulacao (Intimidacao)",20}, {"Navegacao",20}, {"Pesquisa",30}} },
            ["petros"] = { p=270, a=3, ap={"Poderes Magicos 2", "Pontos de Fe 1"}, armas={{"Cimitarra Curta",40,30,"cac"}, {"Waqqif",30,20,"cac"}}, per={{"Armadilhas",10}, {"Ciencias Proibidas (Alquimia)",20}, {"Ciencias Proibidas (Astrologia)",30}, {"Ciencias Proibidas (Rituais)",30}, {"Idiomas (Arabe)",30}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Manipulacao (Interrogatorio)",30}, {"Manipulacao (Intimidacao)",20}, {"Religiao (Islamismo)",30}, {"Sobrevivencia (Deserto)",30}} },
            ["marmore"] = { p=280, a=3, ap={"Poderes Magicos 2", "Pontos de Fe 1"}, armas={{"Adaga",30,30,"cac"}}, per={{"Manobra de Combate (luta as cegas)",0}, {"Armadilhas",30}, {"Ciencias Proibidas (Alquimia)",20}, {"Ciencias Proibidas (Rituais)",20}, {"Idiomas (Arabe)",30}, {"Idiomas (Ler e Escrever Idioma Nativo)",20}, {"Manipulacao (Interrogatorio)",30}, {"Manipulacao (Intimidacao)",30}, {"Manipulacao (Tortura)",30}, {"Religiao (Ismalismo)",30}, {"Sobrevivencia (escolha um ambiente)",30}} },
            ["corrosivos"] = { p=200, a=3, ap={"Poderes Magicos 2"}, armas={}, per={{"Armadilhas",20}, {"Ciencias Proibidas (Alquimia)",30}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Teoria da Magia)",30}, {"Disfarce",20}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Investigacao",30}, {"Manipulacao (Interrogatorio)",30}, {"Manipulacao (Intimidacao)",30}, {"Pesquisa",30}} },
            ["chronos"] = { p=190, a=3, ap={"Poderes Magicos 2"}, armas={}, per={{"Ciencias (Historia)",30}, {"Ciencias Proibidas (Alquimia)",20}, {"Ciencias Proibidas (Astrologia)",20}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Teoria da Magia)",30}, {"Etiqueta",10}, {"Heraldica",20}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Latim)",30}, {"Idiomas (Ler e Escrever Latim)",30}, {"Religiao",20}} },
            ["tenebras"] = { p=270, a=3, ap={"Poderes Magicos 2"}, armas={{"Adaga",30,30,"cac"}}, per={{"Ciencias (Herbalismo)",20}, {"Ciencias Proibidas (Alquimia)",35}, {"Ciencias Proibidas (Astrologia)",20}, {"Ciencias Proibidas (Rituais)",30}, {"Etiqueta",10}, {"Falsificacao",20}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Latim)",30}, {"Idiomas (Ler e Escrever Latim)",30}, {"Manipulacao (Interrogatorio)",30}, {"Manipulacao (Intimidacao)",20}, {"Manipulacao (Tortura)",40}} },
            ["sombras"] = { p=250, a=3, ap={"Poderes Magicos 2"}, armas={{"Adaga",30,30,"cac"}}, per={{"Ciencias (Herbalismo)",20}, {"Ciencias Proibidas (Alquimia)",35}, {"Ciencias Proibidas (Astrologia)",20}, {"Ciencias Proibidas (Rituais)",30}, {"Falsificacao",20}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Latim)",30}, {"Idiomas (Ler e Escrever Latim)",30}, {"Manipulacao (Interrogatorio)",20}, {"Manipulacao (Intimidacao)",20}, {"Manipulacao (Tortura)",40}} },
            ["salomaomago"] = { p=250, a=5, ap={"Poderes Magicos 3", "Pontos Heroicos 2", "Pontos de Fe 1", "Cacador de Demonios 1"}, armas={}, per={{"Ciencias (Herbalismo)",25}, {"Ciencias Proibidas (Alquimia)",30}, {"Ciencias Proibidas (Ocultismo)",40}, {"Ciencias Proibidas (Seres Sobrenaturais)",40}, {"Ciencias Proibidas (Rituais)",40}, {"Falsificacao",20}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Hebraico)",40}, {"Idiomas (Ler e Escrever Hebraico)",25}, {"Manipulacao (Empatia)",35}, {"Religiao",40}, {"Sobrevivencia (Deserto)",25}} },
            ["salomaoguerreiro"] = { p=250, a=4, ap={"Cacador de Demonios 2", "Pontos Heroicos 4", "Pontos de Fe 1"}, armas={{"Sabre",20,30,"cac"}, {"Lanca",20,25,"cac"}, {"Adaga",20,20,"cac"}}, per={{"Armadilhas",15}, {"Camuflagem",25}, {"Ciencias Proibidas (Seres Sobrenaturais)",30}, {"Esquiva",35}, {"Montaria",40}, {"Rastreio",40}, {"Sobrevivencia (Deserto)",35}} },
            ["isisosiris"] = { p=280, a=3, ap={"Poderes Magicos 2", "Pontos de Fe 1"}, armas={}, per={{"Ciencias (Herbalismo)",25}, {"Ciencias Proibidas (Alquimia)",35}, {"Ciencias Proibidas (Ocultismo)",40}, {"Ciencias Proibidas (Rituais)",40}, {"Ciencias Proibidas (Seres Sobrenaturais)",40}, {"Idiomas (Ler e Escrever Idioma Nativo)",30}, {"Idiomas (Egipcio)",40}, {"Idiomas (Ler e Escrever Egipcio)",25}, {"Manipulacao (Empatia)",30}, {"Primeiros Socorros",25}, {"Religiao",35}, {"Sobrevivencia (Deserto)",30}} },
            ["dragao"] = { p=230, a=3, ap={"Poderes Magicos 2", "Pontos Heroicos 3"}, armas={{"Espada Bastarda",20,30,"cac"}, {"Lanca",20,25,"cac"}, {"Adaga",20,20,"cac"}}, per={{"Esquiva",25}, {"Ciencias Proibidas (Vampiros)",20}, {"Heraldica",20}, {"Manipulacao (Tortura)",20}, {"Montaria",30}, {"Rastreio",20}, {"Sobrevivencia (Deserto)",20}, {"Sobrevivencia (Montanha)",30}} },
            ["cavaleirograal"] = { p=250, a=2, ap={"Pontos Heroicos 4"}, armas={{"Espada Longa",40,30,"cac"}, {"Lanca",30,25,"cac"}, {"Adaga",30,20,"cac"}}, per={{"Esquiva",25}, {"Heraldica",40}, {"Montaria",30}, {"Rastreio",20}, {"Sobrevivencia (Floresta)",30}, {"Sobrevivencia (Montanha)",30}} },
            ["paladinograal"] = { p=380, a=4, ap={"Sortudo", "Alma Pura", "Status", "Pontos de Fe 2", "Pontos Heroicos 4"}, armas={{"Espada Longa",40,40,"cac"}, {"Lanca",40,25,"cac"}, {"Adaga",40,30,"cac"}}, per={{"Esquiva",25}, {"Direito",30}, {"Etiqueta",30}, {"Heraldica",20}, {"Idiomas (Latim)",30}, {"Idiomas (Ler e Escrever)",30}, {"Manipulacao (Empatia)",20}, {"Manipulacao (Lideranca)",20}, {"Manipulacao (Intimidacao)",20}, {"Montaria",30}, {"Rastreio",20}, {"Religiao",30}, {"Sobrevivencia (Floresta)",20}, {"Sobrevivencia (Montanha)",30}} },
            ["brujas"] = { p=285, a=3, ap={"Poderes Magicos 2", "Aliados e Contatos 1", "Biblioteca 1", "Recursos 1"}, armas={}, per={{"Barganha",20}, {"Ciencias (Herbalismo)",40}, {"Ciencias Proibidas (Alquimia)",30}, {"Ciencias Proibidas (Cabala)",30}, {"Ciencias Proibidas (Ocultismo)",30}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Venenos)",30}, {"Idiomas (Idioma Nativo)",25}, {"Idiomas (Ler e Escrever)",35}, {"Manipulacao (Empatia)",20}, {"Manipulacao (Seducao)",50}, {"Medicina",20}, {"Primeiros Socorros",25}, {"Subterfugio",20}} },
            ["hassan"] = { p=300, a=3, ap={"Contatos 1", "Recursos 2", "Pontos de Fe 1"}, armas={{"Sabre",40,30,"cac"}, {"Escolha outra arma",40,30,"cac"}}, per={{"Arrombamento",35}, {"Camuflagem",25}, {"Disfarce",30}, {"Escalada",30}, {"Furtar Objetos",20}, {"Furtividade",40}, {"Herbalismo",20}, {"Religiao",40}, {"Sobrevivencia (Deserto)",30}, {"Venenos",40}} },
            ["barbaro"] = { p=250, a=2, ap={"Pontos Heroicos 4", "Furia"}, armas={{"Machado",40,40,"cac"}, {"Clava",30,20,"cac"}}, per={{"Esquiva",20}, {"Montaria",20}, {"Armadilhas",20}, {"Caca",20}, {"Ciencias (Herbalismo)",10}, {"Esportes (Escalada)",20}, {"Esportes (Natacao)",20}, {"Esportes (Corrida)",20}, {"Rastreio",20}, {"Sobrevivencia (escolha um tipo)",40}, {"Venenos",20}} },
            ["bardo"] = { p=220, a=3, ap={"Pontos Heroicos 1", "Poderes Magicos 1", "Contatos e Aliados 2"}, armas={}, per={{"Artes (Atuacao)",20}, {"Artes (Canto)",30}, {"Artes (Instrumento Musical)",40}, {"Ciencias (Historia)",20}, {"Ciencias Proibidas (Teoria da Magia)",20}, {"Camuflagem",20}, {"Conhecimento (Lendas)",30}, {"Disfarce",20}, {"Etiqueta",20}, {"Idiomas (Idioma Nativo)",10}, {"Idiomas (Ler e Escrever)",10}, {"Investigacao",10}, {"Manipulacao (Diplomacia)",20}, {"Manipulacao (Impressionar)",10}, {"Manipulacao (Labia)",10}, {"Manipulacao (Seducao)",10}, {"Subterfugio",10}} },
            ["clerigo"] = { p=200, a=4, ap={"Pontos Heroicos 2", "Pontos de Fe 4"}, armas={{"Maca",30,30,"cac"}, {"Cajado",20,20,"cac"}}, per={{"Ciencias (Teologia)",40}, {"Conhecimento (area da divindade)",30}, {"Concentracao",30}, {"Etiqueta",30}, {"Primeiros Socorros",30}} },
            ["feiticeiro"] = { p=150, a=2, ap={"Pontos Heroicos 1", "Poderes Magicos 1", "Familiar"}, armas={{"Adaga",10,10,"cac"}, {"Bastao",10,10,"cac"}}, per={{"Esquiva",20}, {"Ciencias Proibidas (Alquimia)",30}, {"Ciencias Proibidas (Ocultismo)",20}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Teoria da Magia)",30}, {"Concentracao",20}, {"Escutar",10}} },
            ["mago"] = { p=200, a=3, ap={"Pontos Heroicos 1", "Poderes Magicos 1", "Familiar"}, armas={{"Bastao",10,10,"cac"}, {"Adaga",10,10,"cac"}}, per={{"Ciencias (Herbalismo)",20}, {"Ciencias Proibidas (Alquimia)",30}, {"Ciencias Proibidas (Astrologia)",20}, {"Ciencias Proibidas (Ocultismo)",20}, {"Ciencias Proibidas (Rituais)",30}, {"Ciencias Proibidas (Teoria da Magia)",30}, {"Concentracao",10}, {"Conhecimentos",20}, {"Investigacao",20}} },
            ["monge"] = { p=250, a=3, ap={"Pontos Heroicos 3", "Ataque Desarmado"}, armas={{"Artes Marciais",40,40,"cac"}, {"Bastao",30,30,"cac"}}, per={{"Concentracao",20}, {"Ciencias (Filosofia)",30}, {"Esquiva",40}, {"Esportes (Acrobacia)",20}, {"Esportes (Salto)",20}, {"Furtividade",20}, {"Manipulacao (Empatia)",20}, {"Manipulacao (Impressionar)",20}, {"Manipulacao (Intimidacao)",20}, {"Subterfugio",30}} },
        }

        local function aplicarKit()
            local r = NDB.getRoot(sheet)
            local sel = r.kitSel
            if sel == nil or sel == "none" then
                showMessage("Selecione um kit primeiro.")
                return
            end
            if r.kitAplicado == sel then
                showMessage("Esse kit ja esta aplicado.")
                return
            end
            local def = KITS[sel]
            if def == nil then
                showMessage("Kit nao encontrado.")
                return
            end

            _kitLimpar(r)

            for i=1, #def.armas do
                local w = def.armas[i]
                _kitArma(r, sel, w[1], w[2], w[3], w[4])
            end
            for i=1, #def.per do
                local pp = def.per[i]
                _kitPericia(r, sel, pp[1], pp[2])
            end
            for i=1, #def.ap do
                _kitAprim(r, sel, def.ap[i])
            end
            r.ptsKitPericia = def.p
            r.ptsKitAprim = def.a
            r.kitAplicado = sel
            r.kitAplicadoTxt = "Kit: " .. sel
            showMessage("Kit aplicado (substituindo o anterior, se houver): -" .. tostring(def.p) .. " Pericia, -" .. tostring(def.a) .. " Aprimoramento.")
        end

        local ARMAS = {
            ["faca"] = { n="Faca", d="1d3", t="Perfuração / Corte", c="cac" },
            ["facadepedra"] = { n="Faca de Pedra", d="1d3", t="Perfuração / Corte", c="cac" },
            ["facadecaca"] = { n="Faca de Caça", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["navaja"] = { n="Navaja", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["punhal"] = { n="Punhal", d="1d3", t="Perfuração / Corte", c="cac" },
            ["punhalmexicano"] = { n="Punhal Mexicano", d="1d3", t="Perfuração / Corte", c="cac" },
            ["punhallongo"] = { n="Punhal Longo", d="1d6", t="Perfuração / Corte", c="cac" },
            ["punhalescoces"] = { n="Punhal Escocês", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["punhalespadaouestilete"] = { n="Punhal-espada ou Estilete", d="1d3+2", t="Perfuração / Corte", c="cac" },
            ["picador"] = { n="Picador", d="1d3", t="Perfuração", c="cac" },
            ["stiletto"] = { n="Stiletto", d="1d3", t="Perfuração", c="cac" },
            ["foicedruidica"] = { n="Foice Druídica", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["baselard"] = { n="Baselard", d="1d6", t="Perfuração / Corte", c="cac" },
            ["drachenzahndentededragao"] = { n="Drachenzahn (Dente de Dragão)", d="1d6", t="Corte", c="cac" },
            ["holbein"] = { n="Holbein", d="1d6", t="Perfuração / Corte", c="cac" },
            ["eberfangerpresasdejavali"] = { n="Eberfänger (Presas de Javali)", d="1d6", t="Perfuração / Corte", c="cac" },
            ["rondel"] = { n="Rondel", d="1d3", t="Perfuração / Corte", c="cac" },
            ["earrondel"] = { n="Ear Rondel", d="1d6", t="Perfuração / Corte", c="cac" },
            ["cinquedea"] = { n="Cinquedea", d="1d6", t="Perfuração / Corte", c="cac" },
            ["garradebasilisco"] = { n="Garra de Basilisco", d="1d3+2", t="Perfuração / Corte", c="cac" },
            ["adagasuica"] = { n="Adaga Suíça", d="1d3", t="Perfuração / Corte", c="cac" },
            ["adagagermanica"] = { n="Adaga Germânica", d="1d3", t="Perfuração / Corte", c="cac" },
            ["hauswehren"] = { n="Hauswehren", d="1d3", t="Perfuração / Corte", c="cac" },
            ["adagadearremesso"] = { n="Adaga de Arremesso", d="1d3", t="Perfuração", c="dist" },
            ["maingaunche"] = { n="Main-gaunche", d="1d3", t="Perfuração / Corte", c="cac" },
            ["canhestro"] = { n="Canhestro", d="1d3", t="Perfuração / Corte", c="cac" },
            ["machete"] = { n="Machete", d="1d6", t="Corte / Perfuração", c="cac" },
            ["cutelo"] = { n="Cutelo", d="1d6", t="Corte", c="cac" },
            ["espadadetreinamento"] = { n="Espada de Treinamento", d="1d6", t="Perfuração", c="cac" },
            ["espadacurta"] = { n="Espada Curta", d="1d6", t="Corte / Perfuração", c="cac" },
            ["gladio"] = { n="Gládio", d="1d6+1", t="Corte / Perfuração", c="cac" },
            ["espadadeassassinos"] = { n="Espada de Assassinos", d="1d6", t="Corte / Perfuração", c="cac" },
            ["espadacurtaitaliana"] = { n="Espada Curta Italiana", d="1d6", t="Corte / Perfuração", c="cac" },
            ["espadafrancesa"] = { n="Espada Francesa", d="1d6", t="Corte / Perfuração", c="cac" },
            ["espadaholandesa"] = { n="Espada Holandesa", d="1d6+1", t="Corte", c="cac" },
            ["arbach"] = { n="Arbach", d="1d6+1", t="Corte / Perfuração / Veneno", c="cac" },
            ["rapier"] = { n="Rapier", d="1d6+1", t="Perfuração", c="cac" },
            ["rapierdeduelos"] = { n="Rapier de Duelos", d="1d6+1", t="Perfuração", c="cac" },
            ["rapierdepiratas"] = { n="Rapier de Piratas", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["florete"] = { n="Florete", d="1d6", t="Perfuração", c="cac" },
            ["floretedemagos"] = { n="Florete de Magos", d="1d6", t="Perfuração", c="cac" },
            ["espadamaconica"] = { n="Espada Maçônica", d="1d6+2", t="Perfuração", c="cac" },
            ["sabre"] = { n="Sabre", d="1d6+2", t="Corte / Perfuração", c="cac" },
            ["sabreescoces"] = { n="Sabre Escocês", d="1d6+2", t="Corte / Perfuração", c="cac" },
            ["sabredepiratas"] = { n="Sabre de Piratas", d="1d6+2", t="Corte / Perfuração", c="cac" },
            ["sabredasamazonas"] = { n="Sabre das Amazonas", d="1d6+2", t="Corte / Perfuração", c="cac" },
            ["hunger"] = { n="Hunger", d="1d6+2", t="Corte / Perfuração", c="cac" },
            ["falchionaustriaco"] = { n="Falchion Austríaco", d="1d6", t="Corte / Perfuração", c="cac" },
            ["falchionitaliano"] = { n="Falchion Italiano", d="1d6", t="Corte / Perfuração", c="cac" },
            ["cutlass"] = { n="Cutlass", d="1d6+1", t="Corte / Perfuração", c="cac" },
            ["dusaggenaval"] = { n="Dusägge Naval", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["dusaggedeinfantaria"] = { n="Dusägge de Infantaria", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["espadacabocesta"] = { n="Espada Cabo-Cesta", d="1d6", t="Perfuração / Corte", c="cac" },
            ["espadalonga"] = { n="Espada Longa", d="1d10", t="Corte / Perfuração", c="cac" },
            ["espadaafricana"] = { n="Espada Africana", d="1d6+1", t="Corte / Perfuração", c="cac" },
            ["broadswordespadalarga"] = { n="Broadsword (Espada Larga)", d="1d10+1", t="Corte / Perfuração", c="cac" },
            ["espadabarbara"] = { n="Espada Bárbara", d="1d10", t="Corte / Perfuração", c="cac" },
            ["espadabastarda"] = { n="Espada Bastarda", d="1d10", t="Corte", c="cac" },
            ["twohandswordespadade2maos"] = { n="Two-hand Sword (Espada de 2 mãos)", d="2d6", t="Corte", c="cac" },
            ["swordofjustice"] = { n="Sword of Justice", d="1d10", t="Corte", c="cac" },
            ["rondrakamm"] = { n="Rondrakamm", d="2d6", t="Corte", c="cac" },
            ["claymore"] = { n="Claymore", d="2d6", t="Corte", c="cac" },
            ["flamberge"] = { n="Flamberge", d="1d10", t="Corte", c="cac" },
            ["montante"] = { n="Montante", d="2d6+2", t="Corte / Esmagamento", c="cac" },
            ["machadodemao"] = { n="Machado de Mão", d="1d6", t="Corte", c="cac" },
            ["machadodelenhador"] = { n="Machado de Lenhador", d="1d6+1", t="Corte", c="cac" },
            ["orknase"] = { n="Orknase", d="1d6+2", t="Corte", c="cac" },
            ["machadinha"] = { n="Machadinha", d="1d3+2", t="Corte", c="dist" },
            ["machadodearremesso"] = { n="Machado de Arremesso", d="1d3+2", t="Corte", c="dist" },
            ["machadodeponta"] = { n="Machado de Ponta", d="1d6", t="Corte", c="cac" },
            ["machadonavalha"] = { n="Machado-Navalha", d="1d6+2", t="Corte", c="cac" },
            ["machadosinuoso"] = { n="Machado Sinuoso", d="1d6+2", t="Corte", c="cac" },
            ["machadomilitar"] = { n="Machado Militar", d="1d6+3", t="Corte", c="cac" },
            ["machadodebatalhacurvo"] = { n="Machado de Batalha Curvo", d="1d6+3", t="Corte", c="cac" },
            ["machadodebatalhareto"] = { n="Machado de Batalha Reto", d="1d6+3", t="Corte", c="cac" },
            ["machadobarbaro"] = { n="Machado Bárbaro", d="1d10", t="Corte", c="cac" },
            ["thorwaler"] = { n="Thorwaler", d="1d10", t="Corte", c="cac" },
            ["machadomolok"] = { n="Machado Molok", d="1d10", t="Corte", c="cac" },
            ["stonecutter"] = { n="Stonecutter", d="1d10", t="Corte", c="cac" },
            ["chicote"] = { n="Chicote", d="1d3", t="Corte", c="cac" },
            ["gatodenovecaudas"] = { n="Gato de Nove Caudas", d="1d3", t="Corte", c="cac" },
            ["maquarri"] = { n="Maquarri", d="1d3", t="Corte", c="cac" },
            ["mangual"] = { n="Mangual", d="1d6+1", t="Esmagamento", c="cac" },
            ["mangualdeguerra"] = { n="Mangual de Guerra", d="1d10", t="Esmagamento", c="cac" },
            ["mangualmetalico"] = { n="Mangual Metálico", d="1d6+1", t="Corte / Esmagamento", c="cac" },
            ["mangualduplo"] = { n="Mangual Duplo", d="1d6+1", t="Esmagamento", c="cac" },
            ["mangualtriplo"] = { n="Mangual Triplo", d="1d6+2", t="Esmagamento", c="cac" },
            ["mangualmilitar"] = { n="Mangual Militar", d="1d6+2", t="Esmagamento", c="cac" },
            ["mangualdecorrente"] = { n="Mangual de Corrente", d="1d6", t="Esmagamento", c="cac" },
            ["correntecombola"] = { n="Corrente com Bola", d="1d10", t="Esmagamento", c="cac" },
            ["mangualdegancho"] = { n="Mangual de Gancho", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["clava"] = { n="Clava", d="1d6", t="Esmagamento", c="cac" },
            ["clavadepedra"] = { n="Clava de Pedra", d="1d6", t="Esmagamento", c="cac" },
            ["clavaespinho"] = { n="Clava-Espinho", d="1d6", t="Esmagamento", c="cac" },
            ["macadeexercito"] = { n="Maça de Exército", d="1d6", t="Esmagamento", c="cac" },
            ["macadeguerra"] = { n="Maça de Guerra", d="1d10", t="Esmagamento", c="cac" },
            ["morningstar"] = { n="Morningstar", d="1d6+1", t="Esmagamento", c="cac" },
            ["macagermanica"] = { n="Maça Germânica", d="1d6", t="Esmagamento", c="cac" },
            ["porrete"] = { n="Porrete", d="1d3+1", t="Esmagamento", c="cac" },
            ["bastao"] = { n="Bastão", d="1d6", t="Esmagamento", c="cac" },
            ["martelodeguerra"] = { n="Martelo de Guerra", d="1d6", t="Esmagamento", c="cac" },
            ["marteloritual"] = { n="Martelo Ritual", d="1d6", t="Esmagamento", c="cac" },
            ["martelodeduascabecas"] = { n="Martelo de Duas Cabeças", d="1d6+2", t="Esmagamento / Perfuração", c="cac" },
            ["awlpike"] = { n="Awl Pike", d="1d6+1", t="Esmagamento", c="cac" },
            ["martelocabecadecorvo"] = { n="Martelo Cabeça-de-Corvo", d="1d6+1", t="Esmagamento", c="cac" },
            ["gruufhai"] = { n="Gruufhai", d="1d10", t="Esmagamento", c="cac" },
            ["arcocurto"] = { n="Arco Curto", d="1d6", t="Perfuração", c="dist" },
            ["arcolongo"] = { n="Arco Longo", d="1d6+2", t="Perfuração", c="dist" },
            ["arcocomposto"] = { n="Arco Composto", d="1d6+2", t="Perfuração", c="dist" },
            ["arcodeguerra"] = { n="Arco de Guerra", d="1d6+2", t="Perfuração", c="dist" },
            ["bestaleve"] = { n="Besta Leve", d="1d6", t="Perfuração", c="dist" },
            ["bestapesada"] = { n="Besta Pesada", d="1d6+2", t="Perfuração", c="dist" },
            ["bestaderepeticao"] = { n="Besta de Repetição", d="1d6", t="Perfuração", c="dist" },
            ["balestra"] = { n="Balestra", d="1d3+1", t="Perfuração / Esmagamento", c="dist" },
            ["lancadegolpe"] = { n="Lança de Golpe", d="1d6+3", t="Perfuração", c="cac" },
            ["lancademao"] = { n="Lança de Mão", d="1d6+1", t="Perfuração", c="dist" },
            ["pike"] = { n="Pike", d="1d6+1", t="Perfuração", c="cac" },
            ["lancamolok"] = { n="Lança Molok", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["partisan"] = { n="Partisan", d="1d6+1", t="Perfuração", c="cac" },
            ["lancademaosemponta"] = { n="Lança de Mão sem Ponta", d="1d6", t="Perfuração", c="dist" },
            ["tridente"] = { n="Tridente", d="1d6", t="Perfuração", c="cac" },
            ["tridenteritual"] = { n="Tridente Ritual", d="1d6", t="Perfuração", c="cac" },
            ["dreizak"] = { n="Dreizak", d="1d6", t="Perfuração", c="cac" },
            ["arpaodepesca"] = { n="Arpão de Pesca", d="1d6", t="Perfuração", c="dist" },
            ["lancadearremesso"] = { n="Lança de Arremesso", d="1d3", t="Perfuração", c="dist" },
            ["lancadeduaspontas"] = { n="Lança de Duas Pontas", d="1d6", t="Perfuração", c="cac" },
            ["sturmsense"] = { n="Sturmsense", d="1d6+1", t="Perfuração", c="cac" },
            ["lancadeguerra"] = { n="Lança de Guerra", d="1d10", t="Perfuração", c="cac" },
            ["halberdlongo"] = { n="Halberd Longo", d="2d6", t="Perfuração / Corte", c="cac" },
            ["glefe"] = { n="Glefe", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["schnitter"] = { n="Schnitter", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["lancamachado"] = { n="Lança-machado", d="1d6+3", t="Perfuração / Corte", c="cac" },
            ["matadragao"] = { n="Mata-dragão", d="1d10", t="Perfuração", c="cac" },
            ["lancadecaca"] = { n="Lança de Caça", d="1d6", t="Perfuração", c="cac" },
            ["lancadehaken"] = { n="Lança de Haken", d="1d10", t="Perfuração", c="cac" },
            ["lancadejusta"] = { n="Lança de Justa", d="1d6", t="Perfuração", c="cac" },
            ["pailos"] = { n="Pailos", d="1d10", t="Perfuração / Corte", c="cac" },
            ["dragonlance"] = { n="Dragonlance", d="2d6", t="Perfuração", c="cac" },
            ["bumerangue"] = { n="Bumerangue", d="1d3", t="Esmagamento / Corte", c="dist" },
            ["socoingles"] = { n="Soco Inglês", d="+2", t="Esmagamento", c="cac" },
            ["gauntletluvadecombate"] = { n="Gauntlet (Luva de Combate)", d="+3", t="Esmagamento", c="cac" },
            ["orchidmaodeveterano"] = { n="Orchid / Mão de Veterano", d="+4", t="Penetração / Esmagamento", c="cac" },
            ["funda"] = { n="Funda", d="1", t="Perfuração / Veneno", c="dist" },
            ["cajadofunda"] = { n="Cajado-funda", d="1d3", t="Esmagamento", c="dist" },
            ["dardo"] = { n="Dardo", d="1d3", t="Perfuração / Veneno", c="dist" },
            ["zarabatana"] = { n="Zarabatana", d="1", t="Perfuração / Veneno", c="dist" },
            ["boleadeira"] = { n="Boleadeira", d="1d3+1", t="Esmagamento", c="dist" },
            ["foice"] = { n="Foice", d="1d6+1", t="Corte / Perfuração", c="cac" },
            ["umabari"] = { n="Umabari", d="1d2", t="Perfuração / Veneno", c="cac" },
            ["saipunhal"] = { n="Sai (Punhal)", d="1d6", t="Perfuração", c="cac" },
            ["kogai"] = { n="Kogai", d="1d2", t="Perfuração / Veneno", c="cac" },
            ["tanto"] = { n="Tanto", d="1d3", t="Perfuração / Corte", c="cac" },
            ["masamune"] = { n="Masamune", d="1d3", t="Perfuração / Corte", c="cac" },
            ["hamidashi"] = { n="Hamidashi", d="1d3", t="Perfuração / Corte", c="cac" },
            ["jitte"] = { n="Jitte", d="1d3", t="Perfuração", c="cac" },
            ["kamafoice"] = { n="Kama (Foice)", d="1d3+1", t="Corte", c="cac" },
            ["bichwa"] = { n="Bichwa", d="1d6", t="Perfuração / Corte / Veneno", c="cac" },
            ["moghul"] = { n="Moghul", d="1d3", t="Perfuração / Corte", c="cac" },
            ["katar"] = { n="Katar", d="1d10", t="Perfuração / Corte", c="cac" },
            ["katardeduaspontas"] = { n="Katar de Duas Pontas", d="1d10", t="Perfuração / Corte", c="cac" },
            ["golok"] = { n="Golok", d="1d6", t="Corte", c="cac" },
            ["khurki"] = { n="Khurki", d="1d6", t="Corte", c="cac" },
            ["leque"] = { n="Leque", d="1d3+2", t="Corte / Veneno", c="cac" },
            ["espinhodeemei"] = { n="Espinho de Emei", d="1d6", t="Perfuração", c="cac" },
            ["espinhodepassaro"] = { n="Espinho de Pássaro", d="1d6", t="Perfuração", c="cac" },
            ["facaborboleta"] = { n="Faca Borboleta", d="1d6", t="Perfuração / Corte", c="cac" },
            ["luadupla"] = { n="Lua Dupla", d="1d6", t="Corte", c="cac" },
            ["garrasdetigre"] = { n="Garras de Tigre", d="1d6", t="Perfuração", c="cac" },
            ["circulodeqiankun"] = { n="Círculo de Qian Kun", d="1d6+1", t="Corte", c="cac" },
            ["tonfa"] = { n="Tonfa", d="1d6", t="Esmagamento", c="cac" },
            ["katana"] = { n="Katana", d="1d10+1", t="Corte / Perfuração", c="cac" },
            ["wakizashi"] = { n="Wakizashi", d="1d6+2", t="Corte / Perfuração", c="cac" },
            ["foratachi"] = { n="Fora Tachi", d="1d10", t="Corte / Perfuração", c="cac" },
            ["espadalongaperiodoyamato"] = { n="Espada Longa (período Yamato)", d="1d10", t="Corte / Perfuração", c="cac" },
            ["espadalongaperiodokoto"] = { n="Espada Longa (período Koto)", d="1d10", t="Corte / Perfuração", c="cac" },
            ["espadalongaperiodomuromashi"] = { n="Espada Longa (período Muromashi)", d="1d10", t="Corte / Perfuração", c="cac" },
            ["nodachi"] = { n="No Dachi", d="2d6+2", t="Corte / Esmagamento", c="cac" },
            ["ninjato"] = { n="Ninja-to", d="1d6+2", t="Corte / Perfuração", c="cac" },
            ["nightwind"] = { n="Nightwind", d="1d10", t="Corte / Perfuração", c="cac" },
            ["zafartakia"] = { n="Zafar Takia", d="1d6+1", t="Corte / Perfuração", c="cac" },
            ["cimitarraindiana"] = { n="Cimitarra Indiana", d="1d6+2", t="Corte / Perfuração", c="cac" },
            ["facao"] = { n="Facão", d="1d6", t="Corte", c="cac" },
            ["facao9argolas"] = { n="Facão 9 Argolas", d="1d6", t="Corte", c="cac" },
            ["tienespadareta"] = { n="Tien (Espada Reta)", d="1d6+2", t="Corte / Perfuração", c="cac" },
            ["naga"] = { n="Naga", d="1d6+1", t="Corte", c="cac" },
            ["buhj"] = { n="Buhj", d="1d10", t="Corte", c="cac" },
            ["tabar"] = { n="Tabar", d="1d6+1", t="Corte", c="cac" },
            ["nunchakulientienkwan"] = { n="Nunchaku / Lien-Tien-Kwan", d="1d6", t="Esmagamento", c="cac" },
            ["santienkwan"] = { n="San-Tien-Kwan", d="1d6+2", t="Esmagamento", c="cac" },
            ["bastaoderato"] = { n="Bastão de Rato", d="1d6", t="Esmagamento", c="cac" },
            ["kawanaga"] = { n="Kawanaga", d="1d3", t="Perfuração / Corte", c="cac" },
            ["kusarigama"] = { n="Kusarigama", d="1d6", t="Perfuração / Corte", c="cac" },
            ["tetsubo"] = { n="Tetsubo", d="1d10", t="Esmagamento", c="cac" },
            ["kanabo"] = { n="Kanabo", d="1d6", t="Esmagamento", c="cac" },
            ["bastaochines"] = { n="Bastão Chinês", d="1d8", t="Esmagamento", c="cac" },
            ["shuriken"] = { n="Shuriken", d="1d3", t="Perfuração / Veneno", c="dist" },
            ["machadochines"] = { n="Machado Chinês", d="1d6", t="Corte", c="cac" },
            ["foicedupla"] = { n="Foice Dupla", d="1d6+1", t="Corte / Perfuração", c="cac" },
            ["martelochines"] = { n="Martelo Chinês", d="1d6", t="Esmagamento", c="cac" },
            ["petjat"] = { n="Petjat", d="1d2", t="Corte", c="cac" },
            ["chemti"] = { n="Chemti", d="1d3", t="Corte", c="cac" },
            ["correntechinesa"] = { n="Corrente Chinesa", d="1d6+2", t="Perfuração", c="cac" },
            ["meteoro"] = { n="Meteoro", d="1d6", t="Perfuração", c="cac" },
            ["kausinke"] = { n="Kau-sin-Ke", d="1d2", t="Corte", c="cac" },
            ["hankyu"] = { n="Han kyu", d="1d6", t="Perfuração", c="dist" },
            ["daikyu"] = { n="Dai kyu", d="1d6+1", t="Perfuração", c="dist" },
            ["kagohankyu"] = { n="Kago hankyu", d="1d6", t="Perfuração", c="dist" },
            ["naginata"] = { n="Naginata", d="1d6", t="Perfuração / Corte", c="cac" },
            ["nagamaki"] = { n="Nagamaki", d="1d6+2", t="Perfuração / Corte", c="cac" },
            ["kumade"] = { n="Kumade", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["yari"] = { n="Yari", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["jumonjiyari"] = { n="Jumonji Yari", d="1d6+1", t="Perfuração / Corte", c="cac" },
            ["sickleyari"] = { n="Sickle Yari", d="1d6", t="Perfuração / Corte", c="cac" },
            ["facaturca"] = { n="Faca Turca", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["keris"] = { n="Keris", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["waqqif"] = { n="Waqqif", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["jambiya"] = { n="Jambiya", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["punhalsudanes"] = { n="Punhal Sudanês", d="1d3", t="Perfuração / Corte", c="cac" },
            ["facaarabe"] = { n="Faca Árabe", d="1d6", t="Perfuração / Corte", c="cac" },
            ["adagafoice"] = { n="Adaga Foice", d="1d3", t="Perfuração / Corte", c="cac" },
            ["khanjar"] = { n="Khanjar", d="1d6", t="Perfuração / Corte", c="cac" },
            ["bichaq"] = { n="Bichaq", d="1d6", t="Perfuração / Corte", c="cac" },
            ["rashaq"] = { n="Rashaq", d="1d6", t="Corte / Perfuração", c="cac" },
            ["espadaturca"] = { n="Espada Turca", d="1d6+1", t="Corte", c="cac" },
            ["slavekillercurta"] = { n="Slavekiller Curta", d="1d6+1", t="Corte / Perfuração", c="cac" },
            ["slavekillerlonga"] = { n="Slavekiller Longa", d="1d10", t="Corte / Perfuração", c="cac" },
            ["espadapersa"] = { n="Espada Persa", d="1d10", t="Corte / Perfuração", c="cac" },
            ["cimitarracurta"] = { n="Cimitarra Curta", d="1d6", t="Corte / Perfuração", c="cac" },
            ["cimitarralonga"] = { n="Cimitarra Longa", d="1d6+1", t="Corte / Perfuração", c="cac" },
            ["kopesh"] = { n="Kopesh", d="1d6+1", t="Corte / Perfuração", c="cac" },
            ["garfopersadeexercito"] = { n="Garfo Persa de Exército", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["tridentepersa"] = { n="Tridente Persa", d="1d3+1", t="Perfuração / Corte", c="cac" },
            ["tuzak"] = { n="Tuzak", d="1d10", t="Corte / Perfuração", c="cac" },
            ["espadafalciforme"] = { n="Espada Falciforme", d="2d6", t="Corte", c="cac" },
            ["yataghan"] = { n="Yataghan", d="1d6", t="Perfuração / Corte", c="cac" },
            ["baltaturco"] = { n="Balta Turco", d="1d6+1", t="Corte", c="cac" },
        }

        local function _normArma(s)
            s = tostring(s or "")
            s = s:lower()
            s = s:gsub("á","a"):gsub("à","a"):gsub("â","a"):gsub("ã","a"):gsub("ä","a")
            s = s:gsub("é","e"):gsub("è","e"):gsub("ê","e"):gsub("ë","e")
            s = s:gsub("í","i"):gsub("ì","i"):gsub("î","i"):gsub("ï","i")
            s = s:gsub("ó","o"):gsub("ò","o"):gsub("ô","o"):gsub("õ","o"):gsub("ö","o")
            s = s:gsub("ú","u"):gsub("ù","u"):gsub("û","u"):gsub("ü","u")
            s = s:gsub("ç","c")
            s = s:gsub("^%s+",""):gsub("%s+$","")
            return s
        end

        local function _addArmaNode(r, a, key)
            local nm = "arma" .. tostring(os.time()) .. "_" .. tostring(math.random(1000,9999))
            local nd = NDB.createChildNode(r.equipamentos.ataques, nm)
            if nd == nil then return end
            nd.nome = a.n
            nd.dano = a.d
            nd.tipo = a.t
            nd.arma = key
            showMessage("Arma adicionada: " .. a.n .. " (" .. a.d .. " / " .. a.t .. ")")
        end

        local function _acharArma(txt)
            local q = _normArma(txt)
            if q == "" then return nil end
            local melhor, melhorNome
            for k, w in pairs(ARMAS) do
                local n = _normArma(w.n)
                if n == q then return k end
                if string.find(n, q, 1, true) ~= nil then
                    if melhor == nil or string.len(w.n) < string.len(melhorNome) then
                        melhor = k; melhorNome = w.n
                    end
                end
            end
            return melhor
        end

        local function aplicarArma()
            local r = NDB.getRoot(sheet)
            local sel = r.armaSel
            if sel ~= nil and sel ~= "none" and ARMAS[sel] ~= nil then
                _addArmaNode(r, ARMAS[sel], sel)
                return
            end
            Dialogs.inputQuery("Buscar arma", "Digite o nome da arma:", "",
                function(txt)
                    local key = _acharArma(txt)
                    if key == nil then
                        showMessage("Nenhuma arma encontrada para: " .. tostring(txt))
                        return
                    end
                    _addArmaNode(r, ARMAS[key], key)
                end)
        end


        local RACAS = {
            ["humano"] = { nome="Humano", custo=0, atr={},
                idioma="Idioma Comum", idioma_valor=30,
                info="Idioma Comum 30%. +5 pontos de pericia no 1o nivel e a cada novo nivel." },
            ["anao"] = { nome="Anao", custo=1, atr={constituicao=2, forca=1, agilidade=-1, carisma=-2},
                idioma="Idioma Anao", idioma_valor=30,
                info="Enxerga no escuro. +10% testes com pedras/metais/cavernas/montanhas. +5% resist. veneno. +15% resist. magia. +5% ataque vs orcs/goblinoides. +5% oficios com pedra/metal. DESV: -15% ao usar item magico; nao pode Poderes Magicos." },
            ["elfo"] = { nome="Elfo", custo=1, atr={agilidade=2, constituicao=-2, carisma=2},
                idioma="Idioma Elfico", idioma_valor=30,
                bonus_armas={{"Arco",10,0,"dist"}, {"Espada Longa",10,0,"cac"}},
                info="Imune a sono e magias similares. Enxerga 2x na penumbra (cores/detalhes). +10% ataque com Arco e Espada Longa." },
            ["gnomo"] = { nome="Gnomo", custo=2, atr={constituicao=2, forca=-2},
                idioma="Idioma Gnomo", idioma_valor=30,
                bonus_pericias={{"Alquimia",10}},
                info="Enxerga 2x na penumbra. +10% resist. ilusoes. +5% ataque vs orcs/goblinoides/kobolds. +10% Alquimia. Ilusionista gasta -1 PM em magias de Luz. DESV: so usa equipamentos de criaturas pequenas." },
            ["meioelfo"] = { nome="Meio-Elfo", custo=1, atr={agilidade=1, constituicao=-1},
                idioma="Idioma Elfico ou Comum", idioma_valor=30,
                info="Escolha Idioma Elfico ou Comum (30%). Enxerga 2x na penumbra (cores/detalhes)." },
            ["halfling"] = { nome="Halfling", custo=1, atr={agilidade=3, destreza=3, forca=-4, constituicao=-2},
                idioma="Idioma Halfling", idioma_valor=30,
                bonus_pericias={{"Furtividade",10}, {"Esportes (Escalada)",10}, {"Arremesso",5}},
                info="Idioma Halfling 30%. +10% Furtividade e Esportes (Escalada). +5% Arremesso (e ataque com armas de arremesso). DESV: so usa equipamentos de criaturas pequenas." },
        }

        local function aplicarRaca()
            local r = NDB.getRoot(sheet)
            local sel = r.racaSel
            if sel == nil or sel == "none" or sel == "" then showMessage("Selecione uma raca primeiro."); return end
            local nova = RACAS[sel]
            if nova == nil then showMessage("Raca nao encontrada."); return end
            if r.racaAplicada == sel then showMessage("Essa raca ja esta aplicada."); return end

            _racaLimpar(r)

            local atribs = {"constituicao","forca","destreza","agilidade","inteligencia","vontade","carisma","percepcao"}
            local antiga = RACAS[r.racaAplicada or ""]
            if antiga ~= nil and antiga.atr ~= nil then
                for i=1,#atribs do local n=atribs[i]; local v=antiga.atr[n]; if v ~= nil then r[n.."Mod"] = (tonumber(r[n.."Mod"]) or 0) - v end end
            end
            if nova.atr ~= nil then
                for i=1,#atribs do local n=atribs[i]; local v=nova.atr[n]; if v ~= nil then r[n.."Mod"] = (tonumber(r[n.."Mod"]) or 0) + v end end
            end

            if nova.idioma then _racaPericia(r, sel, nova.idioma, nova.idioma_valor or 30) end
            if nova.bonus_armas then
                for i=1, #nova.bonus_armas do
                    local w = nova.bonus_armas[i]
                    _racaArma(r, sel, w[1], w[2], w[3], w[4])
                end
            end
            if nova.bonus_pericias then
                for i=1, #nova.bonus_pericias do
                    local p = nova.bonus_pericias[i]
                    _racaPericia(r, sel, "BONUS RACIAL: " .. p[1] .. " +" .. p[2] .. "%", p[2])
                end
            end

            r.raca = nova.nome
            r.racaCusto = nova.custo
            r.racaAplicada = sel

            local custoTotal = nova.custo + (tonumber(r.ptsKitAprim) or 0)
            local paDisponivelEstimado = 5 - custoTotal
            showMessage("Raca: " .. nova.nome .. " (" .. nova.custo .. " PA)\n" ..
                "Custo total: " .. nova.custo .. " PA (raca) + " .. (tonumber(r.ptsKitAprim) or 0) .. " PA (kit) = " .. custoTotal .. " PA\n" ..
                "Pontos de Aprimoramento disponivel estimado: " .. paDisponivelEstimado .. " PA\n\n" ..
                (nova.info or ""))
        end

        local function write(str)
            local mesa = Firecast.getMesaDe(sheet);
            if str then
                mesa.activeChat:escrever(str);
            else
                mesa.activeChat:escrever("String nula");
            end;
        end;
        


 
    


    obj.dataLink1 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink1:setParent(obj);
    obj.dataLink1:setField("roll");
    obj.dataLink1:setName("dataLink1");

    obj.tabControl1 = GUI.fromHandle(_obj_newObject("tabControl"));
    obj.tabControl1:setParent(obj);
    obj.tabControl1:setAlign("client");
    obj.tabControl1:setName("tabControl1");

    obj.tab1 = GUI.fromHandle(_obj_newObject("tab"));
    obj.tab1:setParent(obj.tabControl1);
    obj.tab1:setTitle("Principal");
    obj.tab1:setName("tab1");

    obj.frmPrincipal = GUI.fromHandle(_obj_newObject("form"));
    obj.frmPrincipal:setParent(obj.tab1);
    obj.frmPrincipal:setName("frmPrincipal");
    obj.frmPrincipal:setAlign("client");
    obj.frmPrincipal:setScale(1.25);

    obj.popAprimoramento = GUI.fromHandle(_obj_newObject("popup"));
    obj.popAprimoramento:setParent(obj.frmPrincipal);
    obj.popAprimoramento:setName("popAprimoramento");
    obj.popAprimoramento:setWidth(300);
    obj.popAprimoramento:setHeight(240);
    obj.popAprimoramento:setBackOpacity(0.4);
    obj.popAprimoramento.autoScopeNode = false;

    obj.textEditor1 = GUI.fromHandle(_obj_newObject("textEditor"));
    obj.textEditor1:setParent(obj.popAprimoramento);
    obj.textEditor1:setAlign("client");
    obj.textEditor1:setField("descricao");
    obj.textEditor1:setName("textEditor1");

    obj.scrollBox1 = GUI.fromHandle(_obj_newObject("scrollBox"));
    obj.scrollBox1:setParent(obj.frmPrincipal);
    obj.scrollBox1:setAlign("client");
    obj.scrollBox1:setName("scrollBox1");

    obj.layout1 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout1:setParent(obj.scrollBox1);
    obj.layout1:setAlign("top");
    obj.layout1:setWidth(1015);
    obj.layout1:setHeight(900);
    obj.layout1:setName("layout1");

    obj.image1 = GUI.fromHandle(_obj_newObject("image"));
    obj.image1:setParent(obj.layout1);
    obj.image1:setLeft(0);
    obj.image1:setTop(0);
    obj.image1:setWidth(1015);
    obj.image1:setHeight(900);
    obj.image1:setStyle("stretch");
    obj.image1:setSRC("/FichaDaemon/images/fundo.png");
    obj.image1:setName("image1");

    obj.layout2 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout2:setParent(obj.layout1);
    obj.layout2:setAlign("left");
    obj.layout2:setWidth(300);
    obj.layout2:setMargins({right=5});
    obj.layout2:setName("layout2");

    obj.rectangle1 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle1:setParent(obj.layout2);
    obj.rectangle1:setAlign("top");
    obj.rectangle1:setHeight(185);
    obj.rectangle1:setMargins({bottom=5});
    obj.rectangle1:setColor("#272C36");
    obj.rectangle1:setStrokeColor("#8A6C30");
    obj.rectangle1:setStrokeSize(1);
    obj.rectangle1:setName("rectangle1");

    obj.layout3 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout3:setParent(obj.rectangle1);
    obj.layout3:setAlign("top");
    obj.layout3:setHeight(22);
    obj.layout3:setMargins({top=2,left=5,right=5});
    obj.layout3:setName("layout3");

    obj.label1 = GUI.fromHandle(_obj_newObject("label"));
    obj.label1:setParent(obj.layout3);
    obj.label1:setText("Nome");
    obj.label1:setAlign("left");
    obj.label1:setWidth(90);
    obj.label1:setFontSize(13);
    obj.label1:setFontColor("#D8CBB0");
    obj.label1:setName("label1");

    obj.edit1 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit1:setParent(obj.layout3);
    obj.edit1:setField("nome");
    obj.edit1:setAlign("client");
    obj.edit1:setFontSize(13);
    obj.edit1:setName("edit1");
    obj.edit1:setFontColor("white");

    obj.layout4 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout4:setParent(obj.rectangle1);
    obj.layout4:setAlign("top");
    obj.layout4:setHeight(22);
    obj.layout4:setMargins({top=2,left=5,right=5});
    obj.layout4:setName("layout4");

    obj.label2 = GUI.fromHandle(_obj_newObject("label"));
    obj.label2:setParent(obj.layout4);
    obj.label2:setAlign("left");
    obj.label2:setWidth(35);
    obj.label2:setText("Raça");
    obj.label2:setFontColor("#D8CBB0");
    obj.label2:setName("label2");

    obj.button1 = GUI.fromHandle(_obj_newObject("button"));
    obj.button1:setParent(obj.layout4);
    obj.button1:setAlign("right");
    obj.button1:setWidth(70);
    obj.button1:setText("Aplicar");
    obj.button1:setFontColor("#E6C24A");
    obj.button1:setName("button1");

    obj.comboBox1 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox1:setParent(obj.layout4);
    obj.comboBox1:setAlign("client");
    obj.comboBox1:setField("racaSel");
    obj.comboBox1:setItems({'-','Anao','Elfo','Gnomo','Halfling','Humano','Meio-Elfo'});
    obj.comboBox1:setValues({'none','anao','elfo','gnomo','halfling','humano','meioelfo'});
    obj.comboBox1:setName("comboBox1");

    obj.layout5 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout5:setParent(obj.rectangle1);
    obj.layout5:setAlign("top");
    obj.layout5:setHeight(22);
    obj.layout5:setMargins({top=2,left=5,right=5});
    obj.layout5:setName("layout5");

    obj.label3 = GUI.fromHandle(_obj_newObject("label"));
    obj.label3:setParent(obj.layout5);
    obj.label3:setText("Religião");
    obj.label3:setAlign("left");
    obj.label3:setWidth(90);
    obj.label3:setFontSize(13);
    obj.label3:setFontColor("#D8CBB0");
    obj.label3:setName("label3");

    obj.edit2 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit2:setParent(obj.layout5);
    obj.edit2:setField("religiao");
    obj.edit2:setAlign("client");
    obj.edit2:setFontSize(13);
    obj.edit2:setName("edit2");
    obj.edit2:setFontColor("white");

    obj.layout6 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout6:setParent(obj.rectangle1);
    obj.layout6:setAlign("top");
    obj.layout6:setHeight(22);
    obj.layout6:setMargins({top=2,left=5,right=5});
    obj.layout6:setName("layout6");

    obj.label4 = GUI.fromHandle(_obj_newObject("label"));
    obj.label4:setParent(obj.layout6);
    obj.label4:setAlign("left");
    obj.label4:setWidth(35);
    obj.label4:setText("Kit");
    obj.label4:setFontColor("#D8CBB0");
    obj.label4:setName("label4");

    obj.button2 = GUI.fromHandle(_obj_newObject("button"));
    obj.button2:setParent(obj.layout6);
    obj.button2:setAlign("right");
    obj.button2:setWidth(70);
    obj.button2:setText("Aplicar");
    obj.button2:setFontColor("#E6C24A");
    obj.button2:setName("button2");

    obj.comboBox2 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox2:setParent(obj.layout6);
    obj.comboBox2:setAlign("client");
    obj.comboBox2:setField("kitSel");
    obj.comboBox2:setItems({'-','Alquimista','Arqueiro','Assassino','Barbaro','Bardo','Brujas','Cacador de Recompensas','Casa de Chronos','Cavaleiro','Cavaleiro do Graal','Clerigo','Contrabandista','Druida','Escola de Luft','Escola de Pyros','Escola de Tenebras','Escola de Yamesh','Espiao','Feiticeiro','Guarda-Costas','Guerreiro','Herbalista','Jogador','Ladrao','Ladrao de Tumbas','Mago','Magos Aquos','Magos Atlantes','Magos Corrosivos','Magos da Tempestade','Magos das Sombras','Magos do Vacuo','Magos Petros','Magos Vermelhos','Menestrel','Menestrel Sombrio','Mercador','Mercenario','Monge','Ordem de Salomao (Guerreiro)','Ordem de Salomao (Mago)','Ordem do Dragao','Ordem Marmore','Padre','Paladino','Paladinos do Graal','Ranger','Sociedade de Hassan','Templo de Isis e Osiris'});
    obj.comboBox2:setValues({'none','alquimista','arqueiro','assassino','barbaro','bardo','brujas','cacadorrecompensas','chronos','cavaleiro','cavaleirograal','clerigo','contrabandista','druida','luft','pyros','tenebras','yamesh','espiao','feiticeiro','guardacostas','guerreiro','herbalista','jogador','ladrao','ladraotumbas','mago','magosaquos','magosatlantes','corrosivos','tempestade','sombras','vacuo','petros','magosvermelhos','menestrel','menestrelsombrio','mercador','mercenario','monge','salomaoguerreiro','salomaomago','dragao','marmore','padre','paladino','paladinograal','ranger','hassan','isisosiris'});
    obj.comboBox2:setName("comboBox2");

    obj.layout7 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout7:setParent(obj.rectangle1);
    obj.layout7:setAlign("top");
    obj.layout7:setHeight(22);
    obj.layout7:setMargins({top=2,left=5,right=5});
    obj.layout7:setName("layout7");

    obj.label5 = GUI.fromHandle(_obj_newObject("label"));
    obj.label5:setParent(obj.layout7);
    obj.label5:setText("Kit (Nível)");
    obj.label5:setAlign("left");
    obj.label5:setWidth(90);
    obj.label5:setFontColor("#D8CBB0");
    obj.label5:setName("label5");

    obj.edit3 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit3:setParent(obj.layout7);
    obj.edit3:setField("kit");
    obj.edit3:setAlign("client");
    obj.edit3:setName("edit3");
    obj.edit3:setFontSize(15);
    obj.edit3:setFontColor("white");

    obj.edit4 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit4:setParent(obj.layout7);
    obj.edit4:setField("level");
    obj.edit4:setAlign("right");
    obj.edit4:setWidth(50);
    obj.edit4:setName("edit4");
    obj.edit4:setFontSize(15);
    obj.edit4:setFontColor("white");

    obj.layout8 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout8:setParent(obj.rectangle1);
    obj.layout8:setAlign("top");
    obj.layout8:setHeight(22);
    obj.layout8:setMargins({top=2,left=5,right=5});
    obj.layout8:setName("layout8");

    obj.label6 = GUI.fromHandle(_obj_newObject("label"));
    obj.label6:setParent(obj.layout8);
    obj.label6:setText("Experiência");
    obj.label6:setAlign("client");
    obj.label6:setFontColor("#D8CBB0");
    obj.label6:setName("label6");

    obj.edit5 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit5:setParent(obj.layout8);
    obj.edit5:setField("xpAtual");
    obj.edit5:setAlign("right");
    obj.edit5:setWidth(50);
    obj.edit5:setName("edit5");
    obj.edit5:setFontSize(15);
    obj.edit5:setFontColor("white");

    obj.edit6 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit6:setParent(obj.layout8);
    obj.edit6:setField("xpObjetivo");
    obj.edit6:setAlign("right");
    obj.edit6:setWidth(50);
    obj.edit6:setName("edit6");
    obj.edit6:setFontSize(15);
    obj.edit6:setFontColor("white");

    obj.rectangle2 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle2:setParent(obj.layout2);
    obj.rectangle2:setAlign("top");
    obj.rectangle2:setHeight(245);
    obj.rectangle2:setMargins({bottom=5});
    obj.rectangle2:setColor("#272C36");
    obj.rectangle2:setStrokeColor("#8A6C30");
    obj.rectangle2:setStrokeSize(1);
    obj.rectangle2:setName("rectangle2");

    obj.layout9 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout9:setParent(obj.rectangle2);
    obj.layout9:setAlign("top");
    obj.layout9:setHeight(25);
    obj.layout9:setMargins({top=3,left=5,right=5});
    obj.layout9:setName("layout9");

    obj.comboBox3 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox3:setParent(obj.layout9);
    obj.comboBox3:setAlign("left");
    obj.comboBox3:setWidth(95);
    obj.comboBox3:setField("atribDificuldade");
    obj.comboBox3:setItems({'Facil','Normal','Dificil'});
    obj.comboBox3:setValues({'facil','normal','dificil'});
    obj.comboBox3:setFontColor("white");
    obj.comboBox3:setHorzTextAlign("center");
    obj.comboBox3:setName("comboBox3");

    obj.cbxAtribResist = GUI.fromHandle(_obj_newObject("imageCheckBox"));
    obj.cbxAtribResist:setParent(obj.layout9);
    obj.cbxAtribResist:setName("cbxAtribResist");
    obj.cbxAtribResist:setAlign("left");
    obj.cbxAtribResist:setWidth(24);
    obj.cbxAtribResist:setHeight(24);
    obj.cbxAtribResist:setMargins({left=10,right=3,top=2});
    obj.cbxAtribResist:setField("atribResistido");
    obj.cbxAtribResist:setOptimize(false);
    obj.cbxAtribResist:setOpacity(0.55);
    obj.cbxAtribResist:setImageChecked("/FichaDaemon/images/ic_resist_on.png");
    obj.cbxAtribResist:setImageUnchecked("/FichaDaemon/images/ic_resist_off.png");

    obj.label7 = GUI.fromHandle(_obj_newObject("label"));
    obj.label7:setParent(obj.layout9);
    obj.label7:setAlign("left");
    obj.label7:setWidth(52);
    obj.label7:setText("Resist.");
    obj.label7:setFontColor("#E6C24A");
    obj.label7:setVertTextAlign("center");
    obj.label7:setName("label7");

    obj.edit7 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit7:setParent(obj.layout9);
    obj.edit7:setAlign("left");
    obj.edit7:setWidth(42);
    obj.edit7:setField("atribDefesa");
    obj.edit7:setHorzTextAlign("center");
    obj.edit7:setVertTextAlign("center");
    obj.edit7:setName("edit7");
    obj.edit7:setFontSize(15);
    obj.edit7:setFontColor("white");

    obj.dataLink2 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink2:setParent(obj.rectangle2);
    obj.dataLink2:setField("atribDificuldade");
    obj.dataLink2:setDefaultValue("normal");
    obj.dataLink2:setName("dataLink2");

    obj.layout10 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout10:setParent(obj.rectangle2);
    obj.layout10:setAlign("top");
    obj.layout10:setHeight(24);
    obj.layout10:setMargins({top=3,left=5,right=5});
    obj.layout10:setName("layout10");

    obj.edit8 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit8:setParent(obj.layout10);
    obj.edit8:setField("constituicaoBase");
    obj.edit8:setAlign("right");
    obj.edit8:setWidth(30);
    obj.edit8:setHorzTextAlign("center");
    obj.edit8:setName("edit8");
    obj.edit8:setFontSize(15);
    obj.edit8:setFontColor("white");

    obj.edit9 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit9:setParent(obj.layout10);
    obj.edit9:setField("constituicaoMod");
    obj.edit9:setAlign("right");
    obj.edit9:setWidth(30);
    obj.edit9:setHorzTextAlign("center");
    obj.edit9:setName("edit9");
    obj.edit9:setFontSize(15);
    obj.edit9:setFontColor("white");

    obj.edit10 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit10:setParent(obj.layout10);
    obj.edit10:setField("constituicaoOut");
    obj.edit10:setAlign("right");
    obj.edit10:setWidth(30);
    obj.edit10:setHorzTextAlign("center");
    obj.edit10:setName("edit10");
    obj.edit10:setFontSize(15);
    obj.edit10:setFontColor("white");

    obj.rectangle3 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle3:setParent(obj.layout10);
    obj.rectangle3:setAlign("right");
    obj.rectangle3:setWidth(44);
    obj.rectangle3:setColor("#E6140F0C");
    obj.rectangle3:setStrokeColor("#8A6C30");
    obj.rectangle3:setStrokeSize(1);
    obj.rectangle3:setName("rectangle3");

    obj.label8 = GUI.fromHandle(_obj_newObject("label"));
    obj.label8:setParent(obj.rectangle3);
    obj.label8:setField("constituicaoPerc");
    obj.label8:setAlign("client");
    obj.label8:setHorzTextAlign("center");
    obj.label8:setFontColor("#F2E8CE");
    obj.label8:setName("label8");

    obj.image2 = GUI.fromHandle(_obj_newObject("image"));
    obj.image2:setParent(obj.layout10);
    obj.image2:setAlign("left");
    obj.image2:setWidth(24);
    obj.image2:setMargins({right=4, top=1, bottom=1});
    obj.image2:setStyle("autoFit");
    obj.image2:setSRC("/FichaDaemon/images/ic_constituicao.png");
    obj.image2:setName("image2");

    obj.button3 = GUI.fromHandle(_obj_newObject("button"));
    obj.button3:setParent(obj.layout10);
    obj.button3:setText("Constituição");
    obj.button3:setAlign("client");
    obj.button3:setMargins({right=5});
    obj.button3:setFontColor("#E6C24A");
    obj.button3:setFontSize(12);
    obj.button3:setHorzTextAlign("leading");
    obj.button3:setName("button3");

    obj.dataLink3 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink3:setParent(obj.layout10);
    obj.dataLink3:setFields({'constituicaoBase', 'constituicaoMod', 'constituicaoOut'});
    obj.dataLink3:setName("dataLink3");

    obj.layout11 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout11:setParent(obj.rectangle2);
    obj.layout11:setAlign("top");
    obj.layout11:setHeight(24);
    obj.layout11:setMargins({top=3,left=5,right=5});
    obj.layout11:setName("layout11");

    obj.edit11 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit11:setParent(obj.layout11);
    obj.edit11:setField("forcaBase");
    obj.edit11:setAlign("right");
    obj.edit11:setWidth(30);
    obj.edit11:setHorzTextAlign("center");
    obj.edit11:setName("edit11");
    obj.edit11:setFontSize(15);
    obj.edit11:setFontColor("white");

    obj.edit12 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit12:setParent(obj.layout11);
    obj.edit12:setField("forcaMod");
    obj.edit12:setAlign("right");
    obj.edit12:setWidth(30);
    obj.edit12:setHorzTextAlign("center");
    obj.edit12:setName("edit12");
    obj.edit12:setFontSize(15);
    obj.edit12:setFontColor("white");

    obj.edit13 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit13:setParent(obj.layout11);
    obj.edit13:setField("forcaOut");
    obj.edit13:setAlign("right");
    obj.edit13:setWidth(30);
    obj.edit13:setHorzTextAlign("center");
    obj.edit13:setName("edit13");
    obj.edit13:setFontSize(15);
    obj.edit13:setFontColor("white");

    obj.rectangle4 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle4:setParent(obj.layout11);
    obj.rectangle4:setAlign("right");
    obj.rectangle4:setWidth(44);
    obj.rectangle4:setColor("#E6140F0C");
    obj.rectangle4:setStrokeColor("#8A6C30");
    obj.rectangle4:setStrokeSize(1);
    obj.rectangle4:setName("rectangle4");

    obj.label9 = GUI.fromHandle(_obj_newObject("label"));
    obj.label9:setParent(obj.rectangle4);
    obj.label9:setField("forcaPerc");
    obj.label9:setAlign("client");
    obj.label9:setHorzTextAlign("center");
    obj.label9:setFontColor("#F2E8CE");
    obj.label9:setName("label9");

    obj.image3 = GUI.fromHandle(_obj_newObject("image"));
    obj.image3:setParent(obj.layout11);
    obj.image3:setAlign("left");
    obj.image3:setWidth(24);
    obj.image3:setMargins({right=4, top=1, bottom=1});
    obj.image3:setStyle("autoFit");
    obj.image3:setSRC("/FichaDaemon/images/ic_forca.png");
    obj.image3:setName("image3");

    obj.button4 = GUI.fromHandle(_obj_newObject("button"));
    obj.button4:setParent(obj.layout11);
    obj.button4:setText("Força");
    obj.button4:setAlign("client");
    obj.button4:setMargins({right=5});
    obj.button4:setFontColor("#E6C24A");
    obj.button4:setFontSize(12);
    obj.button4:setHorzTextAlign("leading");
    obj.button4:setName("button4");

    obj.dataLink4 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink4:setParent(obj.layout11);
    obj.dataLink4:setFields({'forcaBase', 'forcaMod', 'forcaOut'});
    obj.dataLink4:setName("dataLink4");

    obj.layout12 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout12:setParent(obj.rectangle2);
    obj.layout12:setAlign("top");
    obj.layout12:setHeight(24);
    obj.layout12:setMargins({top=3,left=5,right=5});
    obj.layout12:setName("layout12");

    obj.edit14 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit14:setParent(obj.layout12);
    obj.edit14:setField("destrezaBase");
    obj.edit14:setAlign("right");
    obj.edit14:setWidth(30);
    obj.edit14:setHorzTextAlign("center");
    obj.edit14:setName("edit14");
    obj.edit14:setFontSize(15);
    obj.edit14:setFontColor("white");

    obj.edit15 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit15:setParent(obj.layout12);
    obj.edit15:setField("destrezaMod");
    obj.edit15:setAlign("right");
    obj.edit15:setWidth(30);
    obj.edit15:setHorzTextAlign("center");
    obj.edit15:setName("edit15");
    obj.edit15:setFontSize(15);
    obj.edit15:setFontColor("white");

    obj.edit16 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit16:setParent(obj.layout12);
    obj.edit16:setField("destrezaOut");
    obj.edit16:setAlign("right");
    obj.edit16:setWidth(30);
    obj.edit16:setHorzTextAlign("center");
    obj.edit16:setName("edit16");
    obj.edit16:setFontSize(15);
    obj.edit16:setFontColor("white");

    obj.rectangle5 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle5:setParent(obj.layout12);
    obj.rectangle5:setAlign("right");
    obj.rectangle5:setWidth(44);
    obj.rectangle5:setColor("#E6140F0C");
    obj.rectangle5:setStrokeColor("#8A6C30");
    obj.rectangle5:setStrokeSize(1);
    obj.rectangle5:setName("rectangle5");

    obj.label10 = GUI.fromHandle(_obj_newObject("label"));
    obj.label10:setParent(obj.rectangle5);
    obj.label10:setField("destrezaPerc");
    obj.label10:setAlign("client");
    obj.label10:setHorzTextAlign("center");
    obj.label10:setFontColor("#F2E8CE");
    obj.label10:setName("label10");

    obj.image4 = GUI.fromHandle(_obj_newObject("image"));
    obj.image4:setParent(obj.layout12);
    obj.image4:setAlign("left");
    obj.image4:setWidth(24);
    obj.image4:setMargins({right=4, top=1, bottom=1});
    obj.image4:setStyle("autoFit");
    obj.image4:setSRC("/FichaDaemon/images/ic_destreza.png");
    obj.image4:setName("image4");

    obj.button5 = GUI.fromHandle(_obj_newObject("button"));
    obj.button5:setParent(obj.layout12);
    obj.button5:setText("Destreza");
    obj.button5:setAlign("client");
    obj.button5:setMargins({right=5});
    obj.button5:setFontColor("#E6C24A");
    obj.button5:setFontSize(12);
    obj.button5:setHorzTextAlign("leading");
    obj.button5:setName("button5");

    obj.dataLink5 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink5:setParent(obj.layout12);
    obj.dataLink5:setFields({'destrezaBase', 'destrezaMod', 'destrezaOut'});
    obj.dataLink5:setName("dataLink5");

    obj.layout13 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout13:setParent(obj.rectangle2);
    obj.layout13:setAlign("top");
    obj.layout13:setHeight(24);
    obj.layout13:setMargins({top=3,left=5,right=5});
    obj.layout13:setName("layout13");

    obj.edit17 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit17:setParent(obj.layout13);
    obj.edit17:setField("agilidadeBase");
    obj.edit17:setAlign("right");
    obj.edit17:setWidth(30);
    obj.edit17:setHorzTextAlign("center");
    obj.edit17:setName("edit17");
    obj.edit17:setFontSize(15);
    obj.edit17:setFontColor("white");

    obj.edit18 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit18:setParent(obj.layout13);
    obj.edit18:setField("agilidadeMod");
    obj.edit18:setAlign("right");
    obj.edit18:setWidth(30);
    obj.edit18:setHorzTextAlign("center");
    obj.edit18:setName("edit18");
    obj.edit18:setFontSize(15);
    obj.edit18:setFontColor("white");

    obj.edit19 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit19:setParent(obj.layout13);
    obj.edit19:setField("agilidadeOut");
    obj.edit19:setAlign("right");
    obj.edit19:setWidth(30);
    obj.edit19:setHorzTextAlign("center");
    obj.edit19:setName("edit19");
    obj.edit19:setFontSize(15);
    obj.edit19:setFontColor("white");

    obj.rectangle6 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle6:setParent(obj.layout13);
    obj.rectangle6:setAlign("right");
    obj.rectangle6:setWidth(44);
    obj.rectangle6:setColor("#E6140F0C");
    obj.rectangle6:setStrokeColor("#8A6C30");
    obj.rectangle6:setStrokeSize(1);
    obj.rectangle6:setName("rectangle6");

    obj.label11 = GUI.fromHandle(_obj_newObject("label"));
    obj.label11:setParent(obj.rectangle6);
    obj.label11:setField("agilidadePerc");
    obj.label11:setAlign("client");
    obj.label11:setHorzTextAlign("center");
    obj.label11:setFontColor("#F2E8CE");
    obj.label11:setName("label11");

    obj.image5 = GUI.fromHandle(_obj_newObject("image"));
    obj.image5:setParent(obj.layout13);
    obj.image5:setAlign("left");
    obj.image5:setWidth(24);
    obj.image5:setMargins({right=4, top=1, bottom=1});
    obj.image5:setStyle("autoFit");
    obj.image5:setSRC("/FichaDaemon/images/ic_agilidade.png");
    obj.image5:setName("image5");

    obj.button6 = GUI.fromHandle(_obj_newObject("button"));
    obj.button6:setParent(obj.layout13);
    obj.button6:setText("Agilidade");
    obj.button6:setAlign("client");
    obj.button6:setMargins({right=5});
    obj.button6:setFontColor("#E6C24A");
    obj.button6:setFontSize(12);
    obj.button6:setHorzTextAlign("leading");
    obj.button6:setName("button6");

    obj.dataLink6 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink6:setParent(obj.layout13);
    obj.dataLink6:setFields({'agilidadeBase', 'agilidadeMod', 'agilidadeOut'});
    obj.dataLink6:setName("dataLink6");

    obj.layout14 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout14:setParent(obj.rectangle2);
    obj.layout14:setAlign("top");
    obj.layout14:setHeight(24);
    obj.layout14:setMargins({top=3,left=5,right=5});
    obj.layout14:setName("layout14");

    obj.edit20 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit20:setParent(obj.layout14);
    obj.edit20:setField("inteligenciaBase");
    obj.edit20:setAlign("right");
    obj.edit20:setWidth(30);
    obj.edit20:setHorzTextAlign("center");
    obj.edit20:setName("edit20");
    obj.edit20:setFontSize(15);
    obj.edit20:setFontColor("white");

    obj.edit21 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit21:setParent(obj.layout14);
    obj.edit21:setField("inteligenciaMod");
    obj.edit21:setAlign("right");
    obj.edit21:setWidth(30);
    obj.edit21:setHorzTextAlign("center");
    obj.edit21:setName("edit21");
    obj.edit21:setFontSize(15);
    obj.edit21:setFontColor("white");

    obj.edit22 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit22:setParent(obj.layout14);
    obj.edit22:setField("inteligenciaOut");
    obj.edit22:setAlign("right");
    obj.edit22:setWidth(30);
    obj.edit22:setHorzTextAlign("center");
    obj.edit22:setName("edit22");
    obj.edit22:setFontSize(15);
    obj.edit22:setFontColor("white");

    obj.rectangle7 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle7:setParent(obj.layout14);
    obj.rectangle7:setAlign("right");
    obj.rectangle7:setWidth(44);
    obj.rectangle7:setColor("#E6140F0C");
    obj.rectangle7:setStrokeColor("#8A6C30");
    obj.rectangle7:setStrokeSize(1);
    obj.rectangle7:setName("rectangle7");

    obj.label12 = GUI.fromHandle(_obj_newObject("label"));
    obj.label12:setParent(obj.rectangle7);
    obj.label12:setField("inteligenciaPerc");
    obj.label12:setAlign("client");
    obj.label12:setHorzTextAlign("center");
    obj.label12:setFontColor("#F2E8CE");
    obj.label12:setName("label12");

    obj.image6 = GUI.fromHandle(_obj_newObject("image"));
    obj.image6:setParent(obj.layout14);
    obj.image6:setAlign("left");
    obj.image6:setWidth(24);
    obj.image6:setMargins({right=4, top=1, bottom=1});
    obj.image6:setStyle("autoFit");
    obj.image6:setSRC("/FichaDaemon/images/ic_inteligencia.png");
    obj.image6:setName("image6");

    obj.button7 = GUI.fromHandle(_obj_newObject("button"));
    obj.button7:setParent(obj.layout14);
    obj.button7:setText("Inteligência");
    obj.button7:setAlign("client");
    obj.button7:setMargins({right=5});
    obj.button7:setFontColor("#E6C24A");
    obj.button7:setFontSize(12);
    obj.button7:setHorzTextAlign("leading");
    obj.button7:setName("button7");

    obj.dataLink7 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink7:setParent(obj.layout14);
    obj.dataLink7:setFields({'inteligenciaBase', 'inteligenciaMod', 'inteligenciaOut'});
    obj.dataLink7:setName("dataLink7");

    obj.layout15 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout15:setParent(obj.rectangle2);
    obj.layout15:setAlign("top");
    obj.layout15:setHeight(24);
    obj.layout15:setMargins({top=3,left=5,right=5});
    obj.layout15:setName("layout15");

    obj.edit23 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit23:setParent(obj.layout15);
    obj.edit23:setField("vontadeBase");
    obj.edit23:setAlign("right");
    obj.edit23:setWidth(30);
    obj.edit23:setHorzTextAlign("center");
    obj.edit23:setName("edit23");
    obj.edit23:setFontSize(15);
    obj.edit23:setFontColor("white");

    obj.edit24 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit24:setParent(obj.layout15);
    obj.edit24:setField("vontadeMod");
    obj.edit24:setAlign("right");
    obj.edit24:setWidth(30);
    obj.edit24:setHorzTextAlign("center");
    obj.edit24:setName("edit24");
    obj.edit24:setFontSize(15);
    obj.edit24:setFontColor("white");

    obj.edit25 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit25:setParent(obj.layout15);
    obj.edit25:setField("vontadeOut");
    obj.edit25:setAlign("right");
    obj.edit25:setWidth(30);
    obj.edit25:setHorzTextAlign("center");
    obj.edit25:setName("edit25");
    obj.edit25:setFontSize(15);
    obj.edit25:setFontColor("white");

    obj.rectangle8 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle8:setParent(obj.layout15);
    obj.rectangle8:setAlign("right");
    obj.rectangle8:setWidth(44);
    obj.rectangle8:setColor("#E6140F0C");
    obj.rectangle8:setStrokeColor("#8A6C30");
    obj.rectangle8:setStrokeSize(1);
    obj.rectangle8:setName("rectangle8");

    obj.label13 = GUI.fromHandle(_obj_newObject("label"));
    obj.label13:setParent(obj.rectangle8);
    obj.label13:setField("vontadePerc");
    obj.label13:setAlign("client");
    obj.label13:setHorzTextAlign("center");
    obj.label13:setFontColor("#F2E8CE");
    obj.label13:setName("label13");

    obj.image7 = GUI.fromHandle(_obj_newObject("image"));
    obj.image7:setParent(obj.layout15);
    obj.image7:setAlign("left");
    obj.image7:setWidth(24);
    obj.image7:setMargins({right=4, top=1, bottom=1});
    obj.image7:setStyle("autoFit");
    obj.image7:setSRC("/FichaDaemon/images/ic_vontade.png");
    obj.image7:setName("image7");

    obj.button8 = GUI.fromHandle(_obj_newObject("button"));
    obj.button8:setParent(obj.layout15);
    obj.button8:setText("Força de Vontade");
    obj.button8:setAlign("client");
    obj.button8:setMargins({right=5});
    obj.button8:setFontColor("#E6C24A");
    obj.button8:setFontSize(12);
    obj.button8:setHorzTextAlign("leading");
    obj.button8:setName("button8");

    obj.dataLink8 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink8:setParent(obj.layout15);
    obj.dataLink8:setFields({'vontadeBase', 'vontadeMod', 'vontadeOut'});
    obj.dataLink8:setName("dataLink8");

    obj.layout16 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout16:setParent(obj.rectangle2);
    obj.layout16:setAlign("top");
    obj.layout16:setHeight(24);
    obj.layout16:setMargins({top=3,left=5,right=5});
    obj.layout16:setName("layout16");

    obj.edit26 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit26:setParent(obj.layout16);
    obj.edit26:setField("percepcaoBase");
    obj.edit26:setAlign("right");
    obj.edit26:setWidth(30);
    obj.edit26:setHorzTextAlign("center");
    obj.edit26:setName("edit26");
    obj.edit26:setFontSize(15);
    obj.edit26:setFontColor("white");

    obj.edit27 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit27:setParent(obj.layout16);
    obj.edit27:setField("percepcaoMod");
    obj.edit27:setAlign("right");
    obj.edit27:setWidth(30);
    obj.edit27:setHorzTextAlign("center");
    obj.edit27:setName("edit27");
    obj.edit27:setFontSize(15);
    obj.edit27:setFontColor("white");

    obj.edit28 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit28:setParent(obj.layout16);
    obj.edit28:setField("percepcaoOut");
    obj.edit28:setAlign("right");
    obj.edit28:setWidth(30);
    obj.edit28:setHorzTextAlign("center");
    obj.edit28:setName("edit28");
    obj.edit28:setFontSize(15);
    obj.edit28:setFontColor("white");

    obj.rectangle9 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle9:setParent(obj.layout16);
    obj.rectangle9:setAlign("right");
    obj.rectangle9:setWidth(44);
    obj.rectangle9:setColor("#E6140F0C");
    obj.rectangle9:setStrokeColor("#8A6C30");
    obj.rectangle9:setStrokeSize(1);
    obj.rectangle9:setName("rectangle9");

    obj.label14 = GUI.fromHandle(_obj_newObject("label"));
    obj.label14:setParent(obj.rectangle9);
    obj.label14:setField("percepcaoPerc");
    obj.label14:setAlign("client");
    obj.label14:setHorzTextAlign("center");
    obj.label14:setFontColor("#F2E8CE");
    obj.label14:setName("label14");

    obj.image8 = GUI.fromHandle(_obj_newObject("image"));
    obj.image8:setParent(obj.layout16);
    obj.image8:setAlign("left");
    obj.image8:setWidth(24);
    obj.image8:setMargins({right=4, top=1, bottom=1});
    obj.image8:setStyle("autoFit");
    obj.image8:setSRC("/FichaDaemon/images/ic_percepcao.png");
    obj.image8:setName("image8");

    obj.button9 = GUI.fromHandle(_obj_newObject("button"));
    obj.button9:setParent(obj.layout16);
    obj.button9:setText("Percepção");
    obj.button9:setAlign("client");
    obj.button9:setMargins({right=5});
    obj.button9:setFontColor("#E6C24A");
    obj.button9:setFontSize(12);
    obj.button9:setHorzTextAlign("leading");
    obj.button9:setName("button9");

    obj.dataLink9 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink9:setParent(obj.layout16);
    obj.dataLink9:setFields({'percepcaoBase', 'percepcaoMod', 'percepcaoOut'});
    obj.dataLink9:setName("dataLink9");

    obj.layout17 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout17:setParent(obj.rectangle2);
    obj.layout17:setAlign("top");
    obj.layout17:setHeight(24);
    obj.layout17:setMargins({top=3,left=5,right=5});
    obj.layout17:setName("layout17");

    obj.edit29 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit29:setParent(obj.layout17);
    obj.edit29:setField("carismaBase");
    obj.edit29:setAlign("right");
    obj.edit29:setWidth(30);
    obj.edit29:setHorzTextAlign("center");
    obj.edit29:setName("edit29");
    obj.edit29:setFontSize(15);
    obj.edit29:setFontColor("white");

    obj.edit30 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit30:setParent(obj.layout17);
    obj.edit30:setField("carismaMod");
    obj.edit30:setAlign("right");
    obj.edit30:setWidth(30);
    obj.edit30:setHorzTextAlign("center");
    obj.edit30:setName("edit30");
    obj.edit30:setFontSize(15);
    obj.edit30:setFontColor("white");

    obj.edit31 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit31:setParent(obj.layout17);
    obj.edit31:setField("carismaOut");
    obj.edit31:setAlign("right");
    obj.edit31:setWidth(30);
    obj.edit31:setHorzTextAlign("center");
    obj.edit31:setName("edit31");
    obj.edit31:setFontSize(15);
    obj.edit31:setFontColor("white");

    obj.rectangle10 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle10:setParent(obj.layout17);
    obj.rectangle10:setAlign("right");
    obj.rectangle10:setWidth(44);
    obj.rectangle10:setColor("#E6140F0C");
    obj.rectangle10:setStrokeColor("#8A6C30");
    obj.rectangle10:setStrokeSize(1);
    obj.rectangle10:setName("rectangle10");

    obj.label15 = GUI.fromHandle(_obj_newObject("label"));
    obj.label15:setParent(obj.rectangle10);
    obj.label15:setField("carismaPerc");
    obj.label15:setAlign("client");
    obj.label15:setHorzTextAlign("center");
    obj.label15:setFontColor("#F2E8CE");
    obj.label15:setName("label15");

    obj.image9 = GUI.fromHandle(_obj_newObject("image"));
    obj.image9:setParent(obj.layout17);
    obj.image9:setAlign("left");
    obj.image9:setWidth(24);
    obj.image9:setMargins({right=4, top=1, bottom=1});
    obj.image9:setStyle("autoFit");
    obj.image9:setSRC("/FichaDaemon/images/ic_carisma.png");
    obj.image9:setName("image9");

    obj.button10 = GUI.fromHandle(_obj_newObject("button"));
    obj.button10:setParent(obj.layout17);
    obj.button10:setText("Carisma");
    obj.button10:setAlign("client");
    obj.button10:setMargins({right=5});
    obj.button10:setFontColor("#E6C24A");
    obj.button10:setFontSize(12);
    obj.button10:setHorzTextAlign("leading");
    obj.button10:setName("button10");

    obj.dataLink10 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink10:setParent(obj.layout17);
    obj.dataLink10:setFields({'carismaBase', 'carismaMod', 'carismaOut'});
    obj.dataLink10:setName("dataLink10");

    obj.rectangle11 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle11:setParent(obj.layout2);
    obj.rectangle11:setAlign("top");
    obj.rectangle11:setHeight(215);
    obj.rectangle11:setMargins({bottom=5});
    obj.rectangle11:setColor("#272C36");
    obj.rectangle11:setStrokeColor("#8A6C30");
    obj.rectangle11:setStrokeSize(1);
    obj.rectangle11:setName("rectangle11");

    obj.layout18 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout18:setParent(obj.rectangle11);
    obj.layout18:setAlign("top");
    obj.layout18:setHeight(25);
    obj.layout18:setMargins({top=5,left=5,right=5});
    obj.layout18:setName("layout18");

    obj.label16 = GUI.fromHandle(_obj_newObject("label"));
    obj.label16:setParent(obj.layout18);
    obj.label16:setAlign("left");
    obj.label16:setWidth(140);
    obj.label16:setText("Pontos");
    obj.label16:setFontColor("#E6C24A");
    obj.label16:setFontSize(14);
    obj.label16:setName("label16");

    obj.label17 = GUI.fromHandle(_obj_newObject("label"));
    obj.label17:setParent(obj.layout18);
    obj.label17:setAlign("left");
    obj.label17:setWidth(50);
    obj.label17:setMargins({left=8});
    obj.label17:setText("Gasto");
    obj.label17:setFontColor("#E6C24A");
    obj.label17:setHorzTextAlign("center");
    obj.label17:setFontSize(11);
    obj.label17:setName("label17");

    obj.label18 = GUI.fromHandle(_obj_newObject("label"));
    obj.label18:setParent(obj.layout18);
    obj.label18:setAlign("left");
    obj.label18:setWidth(50);
    obj.label18:setMargins({left=8});
    obj.label18:setText("Disp.");
    obj.label18:setFontColor("#E6C24A");
    obj.label18:setHorzTextAlign("center");
    obj.label18:setFontSize(11);
    obj.label18:setName("label18");

    obj.layout19 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout19:setParent(obj.rectangle11);
    obj.layout19:setAlign("top");
    obj.layout19:setHeight(25);
    obj.layout19:setMargins({top=5,left=5,right=5});
    obj.layout19:setName("layout19");

    obj.label19 = GUI.fromHandle(_obj_newObject("label"));
    obj.label19:setParent(obj.layout19);
    obj.label19:setText("Atributos");
    obj.label19:setAlign("left");
    obj.label19:setWidth(140);
    obj.label19:setFontColor("#D8CBB0");
    obj.label19:setName("label19");

    obj.rectangle12 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle12:setParent(obj.layout19);
    obj.rectangle12:setAlign("left");
    obj.rectangle12:setWidth(50);
    obj.rectangle12:setMargins({left=8});
    obj.rectangle12:setColor("#272C36");
    obj.rectangle12:setStrokeColor("#8A6C30");
    obj.rectangle12:setStrokeSize(1);
    obj.rectangle12:setName("rectangle12");

    obj.label20 = GUI.fromHandle(_obj_newObject("label"));
    obj.label20:setParent(obj.rectangle12);
    obj.label20:setField("ptsAtributos");
    obj.label20:setAlign("client");
    obj.label20:setHorzTextAlign("center");
    obj.label20:setName("label20");
    obj.label20:setFontColor("white");

    obj.rectangle13 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle13:setParent(obj.layout19);
    obj.rectangle13:setAlign("left");
    obj.rectangle13:setWidth(50);
    obj.rectangle13:setMargins({left=8});
    obj.rectangle13:setColor("#272C36");
    obj.rectangle13:setStrokeColor("#8A6C30");
    obj.rectangle13:setStrokeSize(1);
    obj.rectangle13:setName("rectangle13");

    obj.label21 = GUI.fromHandle(_obj_newObject("label"));
    obj.label21:setParent(obj.rectangle13);
    obj.label21:setField("ptsAtribDisp");
    obj.label21:setAlign("client");
    obj.label21:setHorzTextAlign("center");
    obj.label21:setName("label21");
    obj.label21:setFontColor("white");

    obj.layout20 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout20:setParent(obj.rectangle11);
    obj.layout20:setAlign("top");
    obj.layout20:setHeight(25);
    obj.layout20:setMargins({top=5,left=5,right=5});
    obj.layout20:setName("layout20");

    obj.label22 = GUI.fromHandle(_obj_newObject("label"));
    obj.label22:setParent(obj.layout20);
    obj.label22:setText("Perícias");
    obj.label22:setAlign("left");
    obj.label22:setWidth(140);
    obj.label22:setFontColor("#D8CBB0");
    obj.label22:setName("label22");

    obj.rectangle14 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle14:setParent(obj.layout20);
    obj.rectangle14:setAlign("left");
    obj.rectangle14:setWidth(50);
    obj.rectangle14:setMargins({left=8});
    obj.rectangle14:setColor("#272C36");
    obj.rectangle14:setStrokeColor("#8A6C30");
    obj.rectangle14:setStrokeSize(1);
    obj.rectangle14:setName("rectangle14");

    obj.label23 = GUI.fromHandle(_obj_newObject("label"));
    obj.label23:setParent(obj.rectangle14);
    obj.label23:setField("ptsPericiasTotais");
    obj.label23:setAlign("client");
    obj.label23:setHorzTextAlign("center");
    obj.label23:setName("label23");
    obj.label23:setFontColor("white");

    obj.rectangle15 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle15:setParent(obj.layout20);
    obj.rectangle15:setAlign("left");
    obj.rectangle15:setWidth(50);
    obj.rectangle15:setMargins({left=8});
    obj.rectangle15:setColor("#272C36");
    obj.rectangle15:setStrokeColor("#8A6C30");
    obj.rectangle15:setStrokeSize(1);
    obj.rectangle15:setName("rectangle15");

    obj.label24 = GUI.fromHandle(_obj_newObject("label"));
    obj.label24:setParent(obj.rectangle15);
    obj.label24:setField("ptsPericiaDisp");
    obj.label24:setAlign("client");
    obj.label24:setHorzTextAlign("center");
    obj.label24:setName("label24");
    obj.label24:setFontColor("white");

    obj.layout21 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout21:setParent(obj.rectangle11);
    obj.layout21:setAlign("top");
    obj.layout21:setHeight(25);
    obj.layout21:setMargins({top=5,left=5,right=5});
    obj.layout21:setName("layout21");

    obj.label25 = GUI.fromHandle(_obj_newObject("label"));
    obj.label25:setParent(obj.layout21);
    obj.label25:setText("Aprimoramentos");
    obj.label25:setAlign("left");
    obj.label25:setWidth(140);
    obj.label25:setFontColor("#D8CBB0");
    obj.label25:setName("label25");

    obj.rectangle16 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle16:setParent(obj.layout21);
    obj.rectangle16:setAlign("left");
    obj.rectangle16:setWidth(50);
    obj.rectangle16:setMargins({left=8});
    obj.rectangle16:setColor("#272C36");
    obj.rectangle16:setStrokeColor("#8A6C30");
    obj.rectangle16:setStrokeSize(1);
    obj.rectangle16:setName("rectangle16");

    obj.label26 = GUI.fromHandle(_obj_newObject("label"));
    obj.label26:setParent(obj.rectangle16);
    obj.label26:setField("ptsAprimGasto");
    obj.label26:setAlign("client");
    obj.label26:setHorzTextAlign("center");
    obj.label26:setName("label26");
    obj.label26:setFontColor("white");

    obj.rectangle17 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle17:setParent(obj.layout21);
    obj.rectangle17:setAlign("left");
    obj.rectangle17:setWidth(50);
    obj.rectangle17:setMargins({left=8});
    obj.rectangle17:setColor("#272C36");
    obj.rectangle17:setStrokeColor("#8A6C30");
    obj.rectangle17:setStrokeSize(1);
    obj.rectangle17:setName("rectangle17");

    obj.label27 = GUI.fromHandle(_obj_newObject("label"));
    obj.label27:setParent(obj.rectangle17);
    obj.label27:setField("ptsAprimDisp");
    obj.label27:setAlign("client");
    obj.label27:setHorzTextAlign("center");
    obj.label27:setName("label27");
    obj.label27:setFontColor("white");

    obj.layout22 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout22:setParent(obj.rectangle11);
    obj.layout22:setAlign("top");
    obj.layout22:setHeight(25);
    obj.layout22:setMargins({top=5,left=5,right=5});
    obj.layout22:setName("layout22");

    obj.label28 = GUI.fromHandle(_obj_newObject("label"));
    obj.label28:setParent(obj.layout22);
    obj.label28:setText("Poderes");
    obj.label28:setAlign("left");
    obj.label28:setWidth(140);
    obj.label28:setFontColor("#D8CBB0");
    obj.label28:setName("label28");

    obj.rectangle18 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle18:setParent(obj.layout22);
    obj.rectangle18:setAlign("left");
    obj.rectangle18:setWidth(50);
    obj.rectangle18:setMargins({left=8});
    obj.rectangle18:setColor("#272C36");
    obj.rectangle18:setStrokeColor("#8A6C30");
    obj.rectangle18:setStrokeSize(1);
    obj.rectangle18:setName("rectangle18");

    obj.label29 = GUI.fromHandle(_obj_newObject("label"));
    obj.label29:setParent(obj.rectangle18);
    obj.label29:setField("ptsPoderes");
    obj.label29:setAlign("client");
    obj.label29:setHorzTextAlign("center");
    obj.label29:setName("label29");
    obj.label29:setFontColor("white");

    obj.rectangle19 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle19:setParent(obj.layout22);
    obj.rectangle19:setAlign("left");
    obj.rectangle19:setWidth(50);
    obj.rectangle19:setMargins({left=8});
    obj.rectangle19:setColor("#272C36");
    obj.rectangle19:setStrokeColor("#8A6C30");
    obj.rectangle19:setStrokeSize(1);
    obj.rectangle19:setName("rectangle19");

    obj.label30 = GUI.fromHandle(_obj_newObject("label"));
    obj.label30:setParent(obj.rectangle19);
    obj.label30:setField("poderesDispVazio");
    obj.label30:setAlign("client");
    obj.label30:setHorzTextAlign("center");
    obj.label30:setName("label30");
    obj.label30:setFontColor("white");

    obj.layout23 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout23:setParent(obj.rectangle11);
    obj.layout23:setAlign("top");
    obj.layout23:setHeight(25);
    obj.layout23:setMargins({top=5,left=5,right=5});
    obj.layout23:setName("layout23");

    obj.edit32 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit32:setParent(obj.layout23);
    obj.edit32:setField("iniciativaBonus");
    obj.edit32:setAlign("right");
    obj.edit32:setWidth(50);
    obj.edit32:setHorzTextAlign("center");
    obj.edit32:setName("edit32");
    obj.edit32:setFontSize(15);
    obj.edit32:setFontColor("white");

    obj.rectangle20 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle20:setParent(obj.layout23);
    obj.rectangle20:setAlign("right");
    obj.rectangle20:setWidth(50);
    obj.rectangle20:setColor("#272C36");
    obj.rectangle20:setStrokeColor("#8A6C30");
    obj.rectangle20:setStrokeSize(1);
    obj.rectangle20:setName("rectangle20");

    obj.label31 = GUI.fromHandle(_obj_newObject("label"));
    obj.label31:setParent(obj.rectangle20);
    obj.label31:setField("iniciativa");
    obj.label31:setAlign("client");
    obj.label31:setHorzTextAlign("center");
    obj.label31:setName("label31");
    obj.label31:setFontColor("white");

    obj.image10 = GUI.fromHandle(_obj_newObject("image"));
    obj.image10:setParent(obj.layout23);
    obj.image10:setAlign("left");
    obj.image10:setWidth(22);
    obj.image10:setMargins({right=5, top=1, bottom=1});
    obj.image10:setStyle("autoFit");
    obj.image10:setSRC("/FichaDaemon/images/ic_iniciativa.png");
    obj.image10:setName("image10");

    obj.button11 = GUI.fromHandle(_obj_newObject("button"));
    obj.button11:setParent(obj.layout23);
    obj.button11:setText("Iniciativa");
    obj.button11:setAlign("client");
    obj.button11:setMargins({right=5});
    obj.button11:setName("button11");

    obj.dataLink11 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink11:setParent(obj.layout23);
    obj.dataLink11:setFields({'iniciativaBonus','agilidadeBase','agilidadeMod','agilidadeOut'});
    obj.dataLink11:setName("dataLink11");

    obj.dataLink12 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink12:setParent(obj.rectangle11);
    obj.dataLink12:setFields({'constituicaoBase','forcaBase','destrezaBase','agilidadeBase','inteligenciaBase','vontadeBase','percepcaoBase','carismaBase'});
    obj.dataLink12:setName("dataLink12");

    obj.dataLink13 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink13:setParent(obj.rectangle11);
    obj.dataLink13:setFields({'ptsAtributos','level'});
    obj.dataLink13:setName("dataLink13");

    obj.dataLink14 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink14:setParent(obj.rectangle11);
    obj.dataLink14:setFields({'ptsPericiasArmas','ptsPericias'});
    obj.dataLink14:setName("dataLink14");

    obj.dataLink15 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink15:setParent(obj.rectangle11);
    obj.dataLink15:setFields({'idade','inteligenciaBase','inteligenciaMod','inteligenciaOut','level','ptsPericias','ptsPericiasArmas','ptsKitPericia'});
    obj.dataLink15:setName("dataLink15");

    obj.dataLink16 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink16:setParent(obj.rectangle11);
    obj.dataLink16:setFields({'ptsAprimoramentos','ptsKitAprim','level'});
    obj.dataLink16:setName("dataLink16");

    obj.layout24 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout24:setParent(obj.layout1);
    obj.layout24:setAlign("left");
    obj.layout24:setWidth(300);
    obj.layout24:setMargins({right=5});
    obj.layout24:setName("layout24");

    obj.rectangle21 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle21:setParent(obj.layout24);
    obj.rectangle21:setAlign("top");
    obj.rectangle21:setHeight(155);
    obj.rectangle21:setMargins({bottom=5});
    obj.rectangle21:setColor("#272C36");
    obj.rectangle21:setStrokeColor("#8A6C30");
    obj.rectangle21:setStrokeSize(1);
    obj.rectangle21:setName("rectangle21");

    obj.layout25 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout25:setParent(obj.rectangle21);
    obj.layout25:setAlign("top");
    obj.layout25:setHeight(22);
    obj.layout25:setMargins({top=2,left=5,right=5});
    obj.layout25:setName("layout25");

    obj.label32 = GUI.fromHandle(_obj_newObject("label"));
    obj.label32:setParent(obj.layout25);
    obj.label32:setText("ALTURA");
    obj.label32:setAlign("left");
    obj.label32:setWidth(60);
    obj.label32:setFontSize(13);
    obj.label32:setFontColor("#D8CBB0");
    obj.label32:setName("label32");

    obj.edit33 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit33:setParent(obj.layout25);
    obj.edit33:setField("altura");
    obj.edit33:setAlign("client");
    obj.edit33:setFontSize(13);
    obj.edit33:setName("edit33");
    obj.edit33:setFontColor("white");

    obj.layout26 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout26:setParent(obj.rectangle21);
    obj.layout26:setAlign("top");
    obj.layout26:setHeight(22);
    obj.layout26:setMargins({top=2,left=5,right=5});
    obj.layout26:setName("layout26");

    obj.label33 = GUI.fromHandle(_obj_newObject("label"));
    obj.label33:setParent(obj.layout26);
    obj.label33:setText("PESO");
    obj.label33:setAlign("left");
    obj.label33:setWidth(60);
    obj.label33:setFontSize(13);
    obj.label33:setFontColor("#D8CBB0");
    obj.label33:setName("label33");

    obj.edit34 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit34:setParent(obj.layout26);
    obj.edit34:setField("peso");
    obj.edit34:setAlign("client");
    obj.edit34:setFontSize(13);
    obj.edit34:setName("edit34");
    obj.edit34:setFontColor("white");

    obj.layout27 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout27:setParent(obj.rectangle21);
    obj.layout27:setAlign("left");
    obj.layout27:setWidth(150);
    obj.layout27:setName("layout27");

    obj.layout28 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout28:setParent(obj.layout27);
    obj.layout28:setAlign("top");
    obj.layout28:setHeight(22);
    obj.layout28:setMargins({top=2,left=5,right=5});
    obj.layout28:setName("layout28");

    obj.label34 = GUI.fromHandle(_obj_newObject("label"));
    obj.label34:setParent(obj.layout28);
    obj.label34:setText("IDADE");
    obj.label34:setAlign("left");
    obj.label34:setWidth(60);
    obj.label34:setFontSize(13);
    obj.label34:setFontColor("#D8CBB0");
    obj.label34:setName("label34");

    obj.edit35 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit35:setParent(obj.layout28);
    obj.edit35:setField("idade");
    obj.edit35:setAlign("client");
    obj.edit35:setFontSize(13);
    obj.edit35:setName("edit35");
    obj.edit35:setFontColor("white");

    obj.layout29 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout29:setParent(obj.layout27);
    obj.layout29:setAlign("top");
    obj.layout29:setHeight(22);
    obj.layout29:setMargins({top=2,left=5,right=5});
    obj.layout29:setName("layout29");

    obj.label35 = GUI.fromHandle(_obj_newObject("label"));
    obj.label35:setParent(obj.layout29);
    obj.label35:setText("GÊNERO");
    obj.label35:setAlign("left");
    obj.label35:setWidth(60);
    obj.label35:setFontSize(13);
    obj.label35:setFontColor("#D8CBB0");
    obj.label35:setName("label35");

    obj.edit36 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit36:setParent(obj.layout29);
    obj.edit36:setField("genero");
    obj.edit36:setAlign("client");
    obj.edit36:setFontSize(13);
    obj.edit36:setName("edit36");
    obj.edit36:setFontColor("white");

    obj.layout30 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout30:setParent(obj.layout27);
    obj.layout30:setAlign("top");
    obj.layout30:setHeight(22);
    obj.layout30:setMargins({top=2,left=5,right=5});
    obj.layout30:setName("layout30");

    obj.label36 = GUI.fromHandle(_obj_newObject("label"));
    obj.label36:setParent(obj.layout30);
    obj.label36:setText("OUTROS");
    obj.label36:setAlign("left");
    obj.label36:setWidth(60);
    obj.label36:setFontSize(13);
    obj.label36:setFontColor("#D8CBB0");
    obj.label36:setName("label36");

    obj.edit37 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit37:setParent(obj.layout30);
    obj.edit37:setField("aparenciaOutros");
    obj.edit37:setAlign("client");
    obj.edit37:setFontSize(13);
    obj.edit37:setName("edit37");
    obj.edit37:setFontColor("white");

    obj.layout31 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout31:setParent(obj.rectangle21);
    obj.layout31:setAlign("left");
    obj.layout31:setWidth(150);
    obj.layout31:setName("layout31");

    obj.layout32 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout32:setParent(obj.layout31);
    obj.layout32:setAlign("top");
    obj.layout32:setHeight(22);
    obj.layout32:setMargins({top=2,left=5,right=5});
    obj.layout32:setName("layout32");

    obj.label37 = GUI.fromHandle(_obj_newObject("label"));
    obj.label37:setParent(obj.layout32);
    obj.label37:setText("OLHOS");
    obj.label37:setAlign("left");
    obj.label37:setWidth(60);
    obj.label37:setFontSize(13);
    obj.label37:setFontColor("#D8CBB0");
    obj.label37:setName("label37");

    obj.edit38 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit38:setParent(obj.layout32);
    obj.edit38:setField("aparenciaOlhos");
    obj.edit38:setAlign("client");
    obj.edit38:setFontSize(13);
    obj.edit38:setName("edit38");
    obj.edit38:setFontColor("white");

    obj.layout33 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout33:setParent(obj.layout31);
    obj.layout33:setAlign("top");
    obj.layout33:setHeight(22);
    obj.layout33:setMargins({top=2,left=5,right=5});
    obj.layout33:setName("layout33");

    obj.label38 = GUI.fromHandle(_obj_newObject("label"));
    obj.label38:setParent(obj.layout33);
    obj.label38:setText("PELE");
    obj.label38:setAlign("left");
    obj.label38:setWidth(60);
    obj.label38:setFontSize(13);
    obj.label38:setFontColor("#D8CBB0");
    obj.label38:setName("label38");

    obj.edit39 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit39:setParent(obj.layout33);
    obj.edit39:setField("pele");
    obj.edit39:setAlign("client");
    obj.edit39:setFontSize(13);
    obj.edit39:setName("edit39");
    obj.edit39:setFontColor("white");

    obj.layout34 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout34:setParent(obj.layout31);
    obj.layout34:setAlign("top");
    obj.layout34:setHeight(22);
    obj.layout34:setMargins({top=2,left=5,right=5});
    obj.layout34:setName("layout34");

    obj.label39 = GUI.fromHandle(_obj_newObject("label"));
    obj.label39:setParent(obj.layout34);
    obj.label39:setText("CABELO");
    obj.label39:setAlign("left");
    obj.label39:setWidth(60);
    obj.label39:setFontSize(13);
    obj.label39:setFontColor("#D8CBB0");
    obj.label39:setName("label39");

    obj.edit40 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit40:setParent(obj.layout34);
    obj.edit40:setField("cabelo");
    obj.edit40:setAlign("client");
    obj.edit40:setFontSize(13);
    obj.edit40:setName("edit40");
    obj.edit40:setFontColor("white");

    obj.rectangle22 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle22:setParent(obj.layout24);
    obj.rectangle22:setAlign("top");
    obj.rectangle22:setHeight(245);
    obj.rectangle22:setMargins({bottom=5});
    obj.rectangle22:setColor("#272C36");
    obj.rectangle22:setStrokeColor("#8A6C30");
    obj.rectangle22:setStrokeSize(1);
    obj.rectangle22:setName("rectangle22");

    obj.layout35 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout35:setParent(obj.rectangle22);
    obj.layout35:setAlign("top");
    obj.layout35:setHeight(25);
    obj.layout35:setMargins({top=5,left=5,right=5});
    obj.layout35:setName("layout35");

    obj.button12 = GUI.fromHandle(_obj_newObject("button"));
    obj.button12:setParent(obj.layout35);
    obj.button12:setText("+");
    obj.button12:setAlign("left");
    obj.button12:setWidth(25);
    obj.button12:setName("button12");

    obj.label40 = GUI.fromHandle(_obj_newObject("label"));
    obj.label40:setParent(obj.layout35);
    obj.label40:setAlign("client");
    obj.label40:setText("Aprimoramentos");
    obj.label40:setMargins({left=5});
    obj.label40:setFontColor("#E6C24A");
    obj.label40:setFontSize(14);
    obj.label40:setName("label40");

    obj.aprimoramentos = GUI.fromHandle(_obj_newObject("recordList"));
    obj.aprimoramentos:setParent(obj.rectangle22);
    obj.aprimoramentos:setName("aprimoramentos");
    obj.aprimoramentos:setField("aprimoramentos");
    obj.aprimoramentos:setTemplateForm("frmAprimoramentoItem");
    obj.aprimoramentos:setAlign("client");
    obj.aprimoramentos:setLayout("vertical");
    obj.aprimoramentos:setMinQt(1);
    obj.aprimoramentos:setMargins({top=5,left=5,right=5,bottom=5});

    obj.rectangle23 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle23:setParent(obj.layout24);
    obj.rectangle23:setAlign("top");
    obj.rectangle23:setHeight(245);
    obj.rectangle23:setMargins({bottom=5});
    obj.rectangle23:setColor("#272C36");
    obj.rectangle23:setStrokeColor("#8A6C30");
    obj.rectangle23:setStrokeSize(1);
    obj.rectangle23:setName("rectangle23");

    obj.layout36 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout36:setParent(obj.rectangle23);
    obj.layout36:setAlign("top");
    obj.layout36:setHeight(25);
    obj.layout36:setMargins({top=5,left=5,right=5});
    obj.layout36:setName("layout36");

    obj.button13 = GUI.fromHandle(_obj_newObject("button"));
    obj.button13:setParent(obj.layout36);
    obj.button13:setText("+");
    obj.button13:setAlign("left");
    obj.button13:setWidth(25);
    obj.button13:setName("button13");

    obj.label41 = GUI.fromHandle(_obj_newObject("label"));
    obj.label41:setParent(obj.layout36);
    obj.label41:setAlign("client");
    obj.label41:setText("Poderes");
    obj.label41:setMargins({left=5});
    obj.label41:setFontColor("#E6C24A");
    obj.label41:setFontSize(14);
    obj.label41:setName("label41");

    obj.poderes = GUI.fromHandle(_obj_newObject("recordList"));
    obj.poderes:setParent(obj.rectangle23);
    obj.poderes:setName("poderes");
    obj.poderes:setField("poderes");
    obj.poderes:setTemplateForm("frmAprimoramentoItem");
    obj.poderes:setAlign("client");
    obj.poderes:setLayout("vertical");
    obj.poderes:setMinQt(1);
    obj.poderes:setMargins({top=5,left=5,right=5,bottom=5});

    obj.layout37 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout37:setParent(obj.layout1);
    obj.layout37:setAlign("left");
    obj.layout37:setWidth(405);
    obj.layout37:setMargins({right=5});
    obj.layout37:setName("layout37");

    obj.rectangle24 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle24:setParent(obj.layout37);
    obj.rectangle24:setAlign("top");
    obj.rectangle24:setHeight(405);
    obj.rectangle24:setMargins({bottom=5});
    obj.rectangle24:setColor("#272C36");
    obj.rectangle24:setStrokeColor("#8A6C30");
    obj.rectangle24:setStrokeSize(1);
    obj.rectangle24:setName("rectangle24");

    obj.label42 = GUI.fromHandle(_obj_newObject("label"));
    obj.label42:setParent(obj.rectangle24);
    obj.label42:setLeft(0);
    obj.label42:setTop(112.5);
    obj.label42:setWidth(245);
    obj.label42:setHeight(20);
    obj.label42:setText("Avatar");
    obj.label42:setHorzTextAlign("center");
    obj.label42:setName("label42");
    obj.label42:setFontColor("white");

    obj.image11 = GUI.fromHandle(_obj_newObject("image"));
    obj.image11:setParent(obj.rectangle24);
    obj.image11:setAlign("client");
    obj.image11:setField("avatar");
    obj.image11:setEditable(true);
    obj.image11:setStyle("autoFit");
    obj.image11:setMargins({left=2, right=2, top=2, bottom=2});
    obj.image11:setName("image11");

    obj.rectangle25 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle25:setParent(obj.layout37);
    obj.rectangle25:setAlign("top");
    obj.rectangle25:setHeight(245);
    obj.rectangle25:setMargins({bottom=5});
    obj.rectangle25:setColor("#272C36");
    obj.rectangle25:setStrokeColor("#8A6C30");
    obj.rectangle25:setStrokeSize(1);
    obj.rectangle25:setName("rectangle25");

    obj.layout38 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout38:setParent(obj.rectangle25);
    obj.layout38:setAlign("top");
    obj.layout38:setHeight(25);
    obj.layout38:setMargins({top=5,left=5,right=5});
    obj.layout38:setName("layout38");

    obj.edit41 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit41:setParent(obj.layout38);
    obj.edit41:setField("pv");
    obj.edit41:setAlign("right");
    obj.edit41:setWidth(50);
    obj.edit41:setName("edit41");
    obj.edit41:setFontSize(15);
    obj.edit41:setFontColor("white");

    obj.rectangle26 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle26:setParent(obj.layout38);
    obj.rectangle26:setAlign("right");
    obj.rectangle26:setWidth(50);
    obj.rectangle26:setColor("#272C36");
    obj.rectangle26:setStrokeColor("#8A6C30");
    obj.rectangle26:setStrokeSize(1);
    obj.rectangle26:setName("rectangle26");

    obj.label43 = GUI.fromHandle(_obj_newObject("label"));
    obj.label43:setParent(obj.rectangle26);
    obj.label43:setField("pvTotal");
    obj.label43:setAlign("client");
    obj.label43:setHorzTextAlign("center");
    obj.label43:setFontColor("#F2E8CE");
    obj.label43:setName("label43");

    obj.image12 = GUI.fromHandle(_obj_newObject("image"));
    obj.image12:setParent(obj.layout38);
    obj.image12:setAlign("left");
    obj.image12:setWidth(22);
    obj.image12:setMargins({right=5, top=1, bottom=1});
    obj.image12:setStyle("autoFit");
    obj.image12:setSRC("/FichaDaemon/images/ic_vida.png");
    obj.image12:setName("image12");

    obj.label44 = GUI.fromHandle(_obj_newObject("label"));
    obj.label44:setParent(obj.layout38);
    obj.label44:setText("Pontos de Vida");
    obj.label44:setAlign("client");
    obj.label44:setFontColor("#D8CBB0");
    obj.label44:setName("label44");

    obj.layout39 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout39:setParent(obj.rectangle25);
    obj.layout39:setAlign("top");
    obj.layout39:setHeight(25);
    obj.layout39:setMargins({top=5,left=5,right=5});
    obj.layout39:setName("layout39");

    obj.image13 = GUI.fromHandle(_obj_newObject("image"));
    obj.image13:setParent(obj.layout39);
    obj.image13:setAlign("left");
    obj.image13:setWidth(22);
    obj.image13:setMargins({right=5, top=1, bottom=1});
    obj.image13:setStyle("autoFit");
    obj.image13:setSRC("/FichaDaemon/images/ic_carisma.png");
    obj.image13:setName("image13");

    obj.label45 = GUI.fromHandle(_obj_newObject("label"));
    obj.label45:setParent(obj.layout39);
    obj.label45:setText("Pontos Heróicos");
    obj.label45:setAlign("client");
    obj.label45:setFontColor("#D8CBB0");
    obj.label45:setName("label45");

    obj.edit42 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit42:setParent(obj.layout39);
    obj.edit42:setField("ph");
    obj.edit42:setAlign("right");
    obj.edit42:setWidth(50);
    obj.edit42:setName("edit42");
    obj.edit42:setFontSize(15);
    obj.edit42:setFontColor("white");

    obj.edit43 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit43:setParent(obj.layout39);
    obj.edit43:setField("phTotal");
    obj.edit43:setAlign("right");
    obj.edit43:setWidth(50);
    obj.edit43:setName("edit43");
    obj.edit43:setFontSize(15);
    obj.edit43:setFontColor("white");

    obj.layout40 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout40:setParent(obj.rectangle25);
    obj.layout40:setAlign("top");
    obj.layout40:setHeight(25);
    obj.layout40:setMargins({top=5,left=5,right=5});
    obj.layout40:setName("layout40");

    obj.image14 = GUI.fromHandle(_obj_newObject("image"));
    obj.image14:setParent(obj.layout40);
    obj.image14:setAlign("left");
    obj.image14:setWidth(22);
    obj.image14:setMargins({right=5, top=1, bottom=1});
    obj.image14:setStyle("autoFit");
    obj.image14:setSRC("/FichaDaemon/images/ic_magia.png");
    obj.image14:setName("image14");

    obj.label46 = GUI.fromHandle(_obj_newObject("label"));
    obj.label46:setParent(obj.layout40);
    obj.label46:setText("Pontos de Magia");
    obj.label46:setAlign("client");
    obj.label46:setFontColor("#D8CBB0");
    obj.label46:setName("label46");

    obj.edit44 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit44:setParent(obj.layout40);
    obj.edit44:setField("pm");
    obj.edit44:setAlign("right");
    obj.edit44:setWidth(50);
    obj.edit44:setName("edit44");
    obj.edit44:setFontSize(15);
    obj.edit44:setFontColor("white");

    obj.edit45 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit45:setParent(obj.layout40);
    obj.edit45:setField("pmTotal");
    obj.edit45:setAlign("right");
    obj.edit45:setWidth(50);
    obj.edit45:setName("edit45");
    obj.edit45:setFontSize(15);
    obj.edit45:setFontColor("white");

    obj.layout41 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout41:setParent(obj.rectangle25);
    obj.layout41:setAlign("top");
    obj.layout41:setHeight(25);
    obj.layout41:setMargins({top=5,left=5,right=5});
    obj.layout41:setName("layout41");

    obj.image15 = GUI.fromHandle(_obj_newObject("image"));
    obj.image15:setParent(obj.layout41);
    obj.image15:setAlign("left");
    obj.image15:setWidth(22);
    obj.image15:setMargins({right=5, top=1, bottom=1});
    obj.image15:setStyle("autoFit");
    obj.image15:setSRC("/FichaDaemon/images/ic_vontade.png");
    obj.image15:setName("image15");

    obj.label47 = GUI.fromHandle(_obj_newObject("label"));
    obj.label47:setParent(obj.layout41);
    obj.label47:setText("Pontos de Fé");
    obj.label47:setAlign("client");
    obj.label47:setFontColor("#D8CBB0");
    obj.label47:setName("label47");

    obj.edit46 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit46:setParent(obj.layout41);
    obj.edit46:setField("pf");
    obj.edit46:setAlign("right");
    obj.edit46:setWidth(50);
    obj.edit46:setName("edit46");
    obj.edit46:setFontSize(15);
    obj.edit46:setFontColor("white");

    obj.edit47 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit47:setParent(obj.layout41);
    obj.edit47:setField("pfTotal");
    obj.edit47:setAlign("right");
    obj.edit47:setWidth(50);
    obj.edit47:setName("edit47");
    obj.edit47:setFontSize(15);
    obj.edit47:setFontColor("white");

    obj.layout42 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout42:setParent(obj.rectangle25);
    obj.layout42:setAlign("top");
    obj.layout42:setHeight(25);
    obj.layout42:setMargins({top=5,left=5,right=5});
    obj.layout42:setName("layout42");

    obj.image16 = GUI.fromHandle(_obj_newObject("image"));
    obj.image16:setParent(obj.layout42);
    obj.image16:setAlign("left");
    obj.image16:setWidth(22);
    obj.image16:setMargins({right=5, top=1, bottom=1});
    obj.image16:setStyle("autoFit");
    obj.image16:setSRC("/FichaDaemon/images/ic_inteligencia.png");
    obj.image16:setName("image16");

    obj.label48 = GUI.fromHandle(_obj_newObject("label"));
    obj.label48:setParent(obj.layout42);
    obj.label48:setText("Pontos Psiônicos");
    obj.label48:setAlign("client");
    obj.label48:setFontColor("#D8CBB0");
    obj.label48:setName("label48");

    obj.edit48 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit48:setParent(obj.layout42);
    obj.edit48:setField("psi");
    obj.edit48:setAlign("right");
    obj.edit48:setWidth(50);
    obj.edit48:setName("edit48");
    obj.edit48:setFontSize(15);
    obj.edit48:setFontColor("white");

    obj.edit49 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit49:setParent(obj.layout42);
    obj.edit49:setField("psiTotal");
    obj.edit49:setAlign("right");
    obj.edit49:setWidth(50);
    obj.edit49:setName("edit49");
    obj.edit49:setFontSize(15);
    obj.edit49:setFontColor("white");

    obj.layout43 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout43:setParent(obj.rectangle25);
    obj.layout43:setAlign("top");
    obj.layout43:setHeight(25);
    obj.layout43:setMargins({top=5,left=5,right=5});
    obj.layout43:setName("layout43");

    obj.image17 = GUI.fromHandle(_obj_newObject("image"));
    obj.image17:setParent(obj.layout43);
    obj.image17:setAlign("left");
    obj.image17:setWidth(22);
    obj.image17:setMargins({right=5, top=1, bottom=1});
    obj.image17:setStyle("autoFit");
    obj.image17:setSRC("/FichaDaemon/images/ic_percepcao.png");
    obj.image17:setName("image17");

    obj.label49 = GUI.fromHandle(_obj_newObject("label"));
    obj.label49:setParent(obj.layout43);
    obj.label49:setText("Visão");
    obj.label49:setAlign("client");
    obj.label49:setFontColor("#D8CBB0");
    obj.label49:setName("label49");

    obj.edit50 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit50:setParent(obj.layout43);
    obj.edit50:setField("visao");
    obj.edit50:setAlign("right");
    obj.edit50:setWidth(50);
    obj.edit50:setName("edit50");
    obj.edit50:setFontSize(15);
    obj.edit50:setFontColor("white");

    obj.edit51 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit51:setParent(obj.layout43);
    obj.edit51:setField("visaoTotal");
    obj.edit51:setAlign("right");
    obj.edit51:setWidth(50);
    obj.edit51:setName("edit51");
    obj.edit51:setFontSize(15);
    obj.edit51:setFontColor("white");

    obj.layout44 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout44:setParent(obj.rectangle25);
    obj.layout44:setAlign("top");
    obj.layout44:setHeight(25);
    obj.layout44:setMargins({top=5,left=5,right=5});
    obj.layout44:setName("layout44");

    obj.edit52 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit52:setParent(obj.layout44);
    obj.edit52:setField("bforcaBonus");
    obj.edit52:setAlign("right");
    obj.edit52:setWidth(50);
    obj.edit52:setName("edit52");
    obj.edit52:setFontSize(15);
    obj.edit52:setFontColor("white");

    obj.rectangle27 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle27:setParent(obj.layout44);
    obj.rectangle27:setAlign("right");
    obj.rectangle27:setWidth(50);
    obj.rectangle27:setColor("#272C36");
    obj.rectangle27:setStrokeColor("#8A6C30");
    obj.rectangle27:setStrokeSize(1);
    obj.rectangle27:setName("rectangle27");

    obj.label50 = GUI.fromHandle(_obj_newObject("label"));
    obj.label50:setParent(obj.rectangle27);
    obj.label50:setField("bforcaTotal");
    obj.label50:setAlign("client");
    obj.label50:setHorzTextAlign("center");
    obj.label50:setFontColor("#F2E8CE");
    obj.label50:setName("label50");

    obj.image18 = GUI.fromHandle(_obj_newObject("image"));
    obj.image18:setParent(obj.layout44);
    obj.image18:setAlign("left");
    obj.image18:setWidth(22);
    obj.image18:setMargins({right=5, top=1, bottom=1});
    obj.image18:setStyle("autoFit");
    obj.image18:setSRC("/FichaDaemon/images/ic_bforca.png");
    obj.image18:setName("image18");

    obj.label51 = GUI.fromHandle(_obj_newObject("label"));
    obj.label51:setParent(obj.layout44);
    obj.label51:setText("Bônus de Força");
    obj.label51:setAlign("client");
    obj.label51:setFontColor("#D8CBB0");
    obj.label51:setName("label51");

    obj.layout45 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout45:setParent(obj.rectangle25);
    obj.layout45:setAlign("top");
    obj.layout45:setHeight(25);
    obj.layout45:setMargins({top=5,left=5,right=5});
    obj.layout45:setName("layout45");

    obj.edit53 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit53:setParent(obj.layout45);
    obj.edit53:setField("movimencacaoBonus");
    obj.edit53:setAlign("right");
    obj.edit53:setWidth(50);
    obj.edit53:setName("edit53");
    obj.edit53:setFontSize(15);
    obj.edit53:setFontColor("white");

    obj.rectangle28 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle28:setParent(obj.layout45);
    obj.rectangle28:setAlign("right");
    obj.rectangle28:setWidth(50);
    obj.rectangle28:setColor("#272C36");
    obj.rectangle28:setStrokeColor("#8A6C30");
    obj.rectangle28:setStrokeSize(1);
    obj.rectangle28:setName("rectangle28");

    obj.label52 = GUI.fromHandle(_obj_newObject("label"));
    obj.label52:setParent(obj.rectangle28);
    obj.label52:setField("movimencacaoTotal");
    obj.label52:setAlign("client");
    obj.label52:setHorzTextAlign("center");
    obj.label52:setFontColor("#F2E8CE");
    obj.label52:setName("label52");

    obj.image19 = GUI.fromHandle(_obj_newObject("image"));
    obj.image19:setParent(obj.layout45);
    obj.image19:setAlign("left");
    obj.image19:setWidth(22);
    obj.image19:setMargins({right=5, top=1, bottom=1});
    obj.image19:setStyle("autoFit");
    obj.image19:setSRC("/FichaDaemon/images/ic_agilidade.png");
    obj.image19:setName("image19");

    obj.label53 = GUI.fromHandle(_obj_newObject("label"));
    obj.label53:setParent(obj.layout45);
    obj.label53:setText("Movimentação");
    obj.label53:setAlign("client");
    obj.label53:setFontColor("#D8CBB0");
    obj.label53:setName("label53");

    obj.dataLink17 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink17:setParent(obj.rectangle25);
    obj.dataLink17:setFields({'constituicaoBase','constituicaoMod','constituicaoOut','forcaBase','forcaMod','forcaOut','level'});
    obj.dataLink17:setName("dataLink17");

    obj.dataLink18 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink18:setParent(obj.rectangle25);
    obj.dataLink18:setFields({'movimencacaoBonus','agilidadeBase','agilidadeMod','agilidadeOut'});
    obj.dataLink18:setName("dataLink18");

    obj.dataLink19 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink19:setParent(obj.rectangle25);
    obj.dataLink19:setFields({'bforcaBonus','forcaBase','forcaMod','forcaOut'});
    obj.dataLink19:setName("dataLink19");

    obj.rectangle29 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle29:setParent(obj.layout1);
    obj.rectangle29:setLeft(5);
    obj.rectangle29:setTop(658);
    obj.rectangle29:setWidth(1005);
    obj.rectangle29:setHeight(232);
    obj.rectangle29:setColor("#272C36");
    obj.rectangle29:setStrokeColor("#8A6C30");
    obj.rectangle29:setStrokeSize(1);
    obj.rectangle29:setName("rectangle29");

    obj.layout46 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout46:setParent(obj.rectangle29);
    obj.layout46:setAlign("top");
    obj.layout46:setHeight(25);
    obj.layout46:setMargins({top=5,left=5,right=5});
    obj.layout46:setName("layout46");

    obj.button14 = GUI.fromHandle(_obj_newObject("button"));
    obj.button14:setParent(obj.layout46);
    obj.button14:setText("+");
    obj.button14:setAlign("left");
    obj.button14:setWidth(25);
    obj.button14:setName("button14");

    obj.label54 = GUI.fromHandle(_obj_newObject("label"));
    obj.label54:setParent(obj.layout46);
    obj.label54:setAlign("left");
    obj.label54:setWidth(60);
    obj.label54:setText("Ataque");
    obj.label54:setMargins({left=5});
    obj.label54:setFontColor("#E6C24A");
    obj.label54:setFontSize(14);
    obj.label54:setName("label54");

    obj.layout47 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout47:setParent(obj.rectangle29);
    obj.layout47:setAlign("top");
    obj.layout47:setHeight(20);
    obj.layout47:setMargins({left=5,right=5,top=2,bottom=2});
    obj.layout47:setName("layout47");

    obj.label55 = GUI.fromHandle(_obj_newObject("label"));
    obj.label55:setParent(obj.layout47);
    obj.label55:setAlign("left");
    obj.label55:setWidth(35);
    obj.label55:setText("");
    obj.label55:setFontColor("#8A6C30");
    obj.label55:setFontSize(11);
    obj.label55:setName("label55");

    obj.label56 = GUI.fromHandle(_obj_newObject("label"));
    obj.label56:setParent(obj.layout47);
    obj.label56:setAlign("left");
    obj.label56:setWidth(150);
    obj.label56:setText("NOME");
    obj.label56:setFontColor("#8A6C30");
    obj.label56:setFontSize(11);
    obj.label56:setHorzTextAlign("leading");
    obj.label56:setName("label56");

    obj.label57 = GUI.fromHandle(_obj_newObject("label"));
    obj.label57:setParent(obj.layout47);
    obj.label57:setAlign("left");
    obj.label57:setWidth(65);
    obj.label57:setText("ATAQUE %");
    obj.label57:setFontColor("#8A6C30");
    obj.label57:setFontSize(11);
    obj.label57:setHorzTextAlign("center");
    obj.label57:setName("label57");

    obj.label58 = GUI.fromHandle(_obj_newObject("label"));
    obj.label58:setParent(obj.layout47);
    obj.label58:setAlign("left");
    obj.label58:setWidth(65);
    obj.label58:setText("DEFESA %");
    obj.label58:setFontColor("#8A6C30");
    obj.label58:setFontSize(11);
    obj.label58:setHorzTextAlign("center");
    obj.label58:setName("label58");

    obj.label59 = GUI.fromHandle(_obj_newObject("label"));
    obj.label59:setParent(obj.layout47);
    obj.label59:setAlign("left");
    obj.label59:setWidth(75);
    obj.label59:setText("DEFESA ALVO");
    obj.label59:setFontColor("#8A6C30");
    obj.label59:setFontSize(11);
    obj.label59:setHorzTextAlign("center");
    obj.label59:setName("label59");

    obj.label60 = GUI.fromHandle(_obj_newObject("label"));
    obj.label60:setParent(obj.layout47);
    obj.label60:setAlign("left");
    obj.label60:setWidth(70);
    obj.label60:setText("DANO");
    obj.label60:setFontColor("#8A6C30");
    obj.label60:setFontSize(11);
    obj.label60:setHorzTextAlign("leading");
    obj.label60:setName("label60");

    obj.label61 = GUI.fromHandle(_obj_newObject("label"));
    obj.label61:setParent(obj.layout47);
    obj.label61:setAlign("left");
    obj.label61:setWidth(80);
    obj.label61:setText("TIPO");
    obj.label61:setFontColor("#8A6C30");
    obj.label61:setFontSize(11);
    obj.label61:setHorzTextAlign("leading");
    obj.label61:setName("label61");

    obj.label62 = GUI.fromHandle(_obj_newObject("label"));
    obj.label62:setParent(obj.layout47);
    obj.label62:setAlign("left");
    obj.label62:setWidth(100);
    obj.label62:setText("QTD MUNICAO");
    obj.label62:setFontColor("#8A6C30");
    obj.label62:setFontSize(11);
    obj.label62:setHorzTextAlign("center");
    obj.label62:setName("label62");

    obj.label63 = GUI.fromHandle(_obj_newObject("label"));
    obj.label63:setParent(obj.layout47);
    obj.label63:setAlign("right");
    obj.label63:setWidth(25);
    obj.label63:setText("");
    obj.label63:setFontColor("#8A6C30");
    obj.label63:setFontSize(11);
    obj.label63:setName("label63");

    obj.ataquesPrincipal = GUI.fromHandle(_obj_newObject("recordList"));
    obj.ataquesPrincipal:setParent(obj.rectangle29);
    obj.ataquesPrincipal:setName("ataquesPrincipal");
    obj.ataquesPrincipal:setField("equipamentos.ataques");
    obj.ataquesPrincipal:setTemplateForm("frmAtaquePrincipal");
    obj.ataquesPrincipal:setAlign("client");
    obj.ataquesPrincipal:setMinQt(1);
    obj.ataquesPrincipal:setMargins({top=0,left=5,right=5,bottom=5});

    obj.tab2 = GUI.fromHandle(_obj_newObject("tab"));
    obj.tab2:setParent(obj.tabControl1);
    obj.tab2:setTitle("Perícias / Inventário");
    obj.tab2:setName("tab2");

    obj.frmPericias = GUI.fromHandle(_obj_newObject("form"));
    obj.frmPericias:setParent(obj.tab2);
    obj.frmPericias:setName("frmPericias");
    obj.frmPericias:setAlign("client");

    obj.scrollBox2 = GUI.fromHandle(_obj_newObject("scrollBox"));
    obj.scrollBox2:setParent(obj.frmPericias);
    obj.scrollBox2:setAlign("client");
    obj.scrollBox2:setName("scrollBox2");

    obj.layout48 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout48:setParent(obj.scrollBox2);
    obj.layout48:setAlign("top");
    obj.layout48:setHeight(500);
    obj.layout48:setMargins({left=10,right=10,top=10,bottom=8});
    obj.layout48:setName("layout48");

    obj.rectangle30 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle30:setParent(obj.layout48);
    obj.rectangle30:setAlign("left");
    obj.rectangle30:setWidth(700);
    obj.rectangle30:setColor("#272C36");
    obj.rectangle30:setStrokeColor("#8A6C30");
    obj.rectangle30:setStrokeSize(1);
    obj.rectangle30:setName("rectangle30");

    obj.layout49 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout49:setParent(obj.rectangle30);
    obj.layout49:setAlign("top");
    obj.layout49:setHeight(25);
    obj.layout49:setMargins({top=5,left=5,right=5});
    obj.layout49:setName("layout49");

    obj.button15 = GUI.fromHandle(_obj_newObject("button"));
    obj.button15:setParent(obj.layout49);
    obj.button15:setText("+");
    obj.button15:setAlign("left");
    obj.button15:setWidth(25);
    obj.button15:setName("button15");

    obj.label64 = GUI.fromHandle(_obj_newObject("label"));
    obj.label64:setParent(obj.layout49);
    obj.label64:setAlign("client");
    obj.label64:setText("Perícias");
    obj.label64:setMargins({left=5});
    obj.label64:setFontColor("#E6C24A");
    obj.label64:setFontSize(14);
    obj.label64:setName("label64");

    obj.pericias = GUI.fromHandle(_obj_newObject("recordList"));
    obj.pericias:setParent(obj.rectangle30);
    obj.pericias:setName("pericias");
    obj.pericias:setField("pericias");
    obj.pericias:setTemplateForm("frmPericiaItem");
    obj.pericias:setAlign("client");
    obj.pericias:setLayout("vertical");
    obj.pericias:setMinQt(1);
    obj.pericias:setMargins({top=5,left=5,right=5,bottom=5});

    obj.rectangle31 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle31:setParent(obj.layout48);
    obj.rectangle31:setAlign("client");
    obj.rectangle31:setMargins({left=10});
    obj.rectangle31:setColor("#272C36");
    obj.rectangle31:setStrokeColor("#8A6C30");
    obj.rectangle31:setStrokeSize(1);
    obj.rectangle31:setName("rectangle31");

    obj.layout50 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout50:setParent(obj.rectangle31);
    obj.layout50:setAlign("top");
    obj.layout50:setHeight(50);
    obj.layout50:setMargins({top=4,left=8,right=5});
    obj.layout50:setName("layout50");

    obj.rectangle32 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle32:setParent(obj.layout50);
    obj.rectangle32:setAlign("right");
    obj.rectangle32:setWidth(150);
    obj.rectangle32:setMargins({top=9,bottom=9,right=2});
    obj.rectangle32:setColor("#1B1F27");
    obj.rectangle32:setStrokeColor("#8A6C30");
    obj.rectangle32:setStrokeSize(1);
    obj.rectangle32:setName("rectangle32");

    obj.label65 = GUI.fromHandle(_obj_newObject("label"));
    obj.label65:setParent(obj.rectangle32);
    obj.label65:setAlign("left");
    obj.label65:setWidth(26);
    obj.label65:setText("$");
    obj.label65:setFontColor("#E6C24A");
    lfm_setPropAsString(obj.label65, "fontStyle", "bold");
    obj.label65:setFontSize(16);
    obj.label65:setHorzTextAlign("center");
    obj.label65:setVertTextAlign("center");
    obj.label65:setName("label65");

    obj.edit54 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit54:setParent(obj.rectangle32);
    obj.edit54:setAlign("client");
    obj.edit54:setField("equipamento.dinheiro.pc");
    obj.edit54:setType("number");
    obj.edit54:setFontColor("#F2E8CE");
    obj.edit54:setFontSize(16);
    obj.edit54:setHorzTextAlign("center");
    obj.edit54:setVertTextAlign("center");
    obj.edit54:setName("edit54");
    obj.edit54:setTransparent(true);

    obj.layout51 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout51:setParent(obj.layout50);
    obj.layout51:setAlign("right");
    obj.layout51:setWidth(46);
    obj.layout51:setMargins({right=8});
    obj.layout51:setName("layout51");

    obj.imgBolsaCheia = GUI.fromHandle(_obj_newObject("image"));
    obj.imgBolsaCheia:setParent(obj.layout51);
    obj.imgBolsaCheia:setName("imgBolsaCheia");
    obj.imgBolsaCheia:setLeft(0);
    obj.imgBolsaCheia:setTop(0);
    obj.imgBolsaCheia:setWidth(46);
    obj.imgBolsaCheia:setHeight(46);
    obj.imgBolsaCheia:setStyle("autoFit");
    obj.imgBolsaCheia:setSRC("/FichaDaemon/images/bolsa_cheia.png");
    obj.imgBolsaCheia:setVisible(false);

    obj.imgBolsaMetade = GUI.fromHandle(_obj_newObject("image"));
    obj.imgBolsaMetade:setParent(obj.layout51);
    obj.imgBolsaMetade:setName("imgBolsaMetade");
    obj.imgBolsaMetade:setLeft(0);
    obj.imgBolsaMetade:setTop(0);
    obj.imgBolsaMetade:setWidth(46);
    obj.imgBolsaMetade:setHeight(46);
    obj.imgBolsaMetade:setStyle("autoFit");
    obj.imgBolsaMetade:setSRC("/FichaDaemon/images/bolsa_metade.png");
    obj.imgBolsaMetade:setVisible(false);

    obj.imgBolsaVazia = GUI.fromHandle(_obj_newObject("image"));
    obj.imgBolsaVazia:setParent(obj.layout51);
    obj.imgBolsaVazia:setName("imgBolsaVazia");
    obj.imgBolsaVazia:setLeft(0);
    obj.imgBolsaVazia:setTop(0);
    obj.imgBolsaVazia:setWidth(46);
    obj.imgBolsaVazia:setHeight(46);
    obj.imgBolsaVazia:setStyle("autoFit");
    obj.imgBolsaVazia:setSRC("/FichaDaemon/images/bolsa_vazia.png");
    obj.imgBolsaVazia:setVisible(false);

    obj.label66 = GUI.fromHandle(_obj_newObject("label"));
    obj.label66:setParent(obj.layout50);
    obj.label66:setAlign("client");
    obj.label66:setText("Inventário");
    obj.label66:setVertTextAlign("center");
    lfm_setPropAsString(obj.label66, "fontStyle", "bold");
    obj.label66:setFontColor("#E6C24A");
    obj.label66:setFontSize(14);
    obj.label66:setName("label66");

    obj.horzLine1 = GUI.fromHandle(_obj_newObject("horzLine"));
    obj.horzLine1:setParent(obj.layout50);
    obj.horzLine1:setAlign("bottom");
    obj.horzLine1:setStrokeColor("#E6C24A");
    obj.horzLine1:setStrokeSize(2);
    obj.horzLine1:setName("horzLine1");

    obj.dataLink20 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink20:setParent(obj.rectangle31);
    obj.dataLink20:setField("equipamento.dinheiro.pc");
    obj.dataLink20:setName("dataLink20");

    obj.layout52 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout52:setParent(obj.rectangle31);
    obj.layout52:setAlign("left");
    obj.layout52:setWidth(200);
    obj.layout52:setMargins({left=5,right=5,bottom=5});
    obj.layout52:setName("layout52");

    obj.image20 = GUI.fromHandle(_obj_newObject("image"));
    obj.image20:setParent(obj.layout52);
    obj.image20:setAlign("top");
    obj.image20:setHeight(200);
    obj.image20:setStyle("autoFit");
    obj.image20:setSRC("/FichaDaemon/images/bolsa.png");
    obj.image20:setMargins({top=15});
    obj.image20:setName("image20");

    obj.layout53 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout53:setParent(obj.rectangle31);
    obj.layout53:setAlign("client");
    obj.layout53:setMargins({right=5,bottom=5});
    obj.layout53:setName("layout53");

    obj.layout54 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout54:setParent(obj.layout53);
    obj.layout54:setAlign("top");
    obj.layout54:setHeight(22);
    obj.layout54:setMargins({top=2});
    obj.layout54:setName("layout54");

    obj.label67 = GUI.fromHandle(_obj_newObject("label"));
    obj.label67:setParent(obj.layout54);
    obj.label67:setAlign("left");
    obj.label67:setWidth(200);
    obj.label67:setText("Item");
    lfm_setPropAsString(obj.label67, "fontStyle", "bold");
    obj.label67:setFontColor("#8A6C30");
    obj.label67:setFontSize(11);
    obj.label67:setMargins({left=2});
    obj.label67:setName("label67");

    obj.label68 = GUI.fromHandle(_obj_newObject("label"));
    obj.label68:setParent(obj.layout54);
    obj.label68:setAlign("left");
    obj.label68:setWidth(90);
    obj.label68:setText("Qtd");
    lfm_setPropAsString(obj.label68, "fontStyle", "bold");
    obj.label68:setFontColor("#8A6C30");
    obj.label68:setFontSize(11);
    obj.label68:setHorzTextAlign("center");
    obj.label68:setName("label68");

    obj.button16 = GUI.fromHandle(_obj_newObject("button"));
    obj.button16:setParent(obj.layout54);
    obj.button16:setAlign("right");
    obj.button16:setWidth(25);
    obj.button16:setText("+");
    obj.button16:setName("button16");

    obj.label69 = GUI.fromHandle(_obj_newObject("label"));
    obj.label69:setParent(obj.layout54);
    obj.label69:setAlign("client");
    obj.label69:setText("Descrição / Notas");
    lfm_setPropAsString(obj.label69, "fontStyle", "bold");
    obj.label69:setFontColor("#8A6C30");
    obj.label69:setFontSize(11);
    obj.label69:setMargins({left=5});
    obj.label69:setName("label69");

    obj.bag = GUI.fromHandle(_obj_newObject("recordList"));
    obj.bag:setParent(obj.layout53);
    obj.bag:setName("bag");
    obj.bag:setField("equipamento.bag");
    obj.bag:setTemplateForm("frmBagItem");
    obj.bag:setAlign("client");
    obj.bag:setLayout("vertical");

    obj.tab3 = GUI.fromHandle(_obj_newObject("tab"));
    obj.tab3:setParent(obj.tabControl1);
    obj.tab3:setTitle("Grimório");
    obj.tab3:setName("tab3");

    obj.rectangle33 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle33:setParent(obj.tab3);
    obj.rectangle33:setName("rectangle33");
    obj.rectangle33:setAlign("client");
    obj.rectangle33:setColor("#40000000");
    obj.rectangle33:setXradius(10);
    obj.rectangle33:setYradius(10);

    obj.popMagia = GUI.fromHandle(_obj_newObject("popup"));
    obj.popMagia:setParent(obj.rectangle33);
    obj.popMagia:setName("popMagia");
    obj.popMagia:setWidth(250);
    obj.popMagia:setHeight(400);
    obj.popMagia:setBackOpacity(0.4);
    obj.popMagia.autoScopeNode = false;

    obj.edit55 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit55:setParent(obj.popMagia);
    obj.edit55:setAlign("top");
    obj.edit55:setField("nome");
    obj.edit55:setTextPrompt("NOME DA MAGIA");
    obj.edit55:setHorzTextAlign("center");
    obj.edit55:setName("edit55");
    obj.edit55:setFontSize(15);
    obj.edit55:setFontColor("white");

    obj.flowLayout1 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout1:setParent(obj.popMagia);
    obj.flowLayout1:setAlign("top");
    obj.flowLayout1:setAutoHeight(true);
    obj.flowLayout1:setMaxControlsPerLine(2);
    obj.flowLayout1:setMargins({bottom=4});
    obj.flowLayout1:setHorzAlign("center");
    obj.flowLayout1:setName("flowLayout1");
    obj.flowLayout1:setVertAlign("leading");

    obj.flowPart1 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart1:setParent(obj.flowLayout1);
    obj.flowPart1:setMinWidth(30);
    obj.flowPart1:setMaxWidth(400);
    obj.flowPart1:setHeight(35);
    obj.flowPart1:setName("flowPart1");
    obj.flowPart1:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart1:setVertAlign("leading");

    obj.label70 = GUI.fromHandle(_obj_newObject("label"));
    obj.label70:setParent(obj.flowPart1);
    obj.label70:setAlign("top");
    obj.label70:setFontSize(10);
    obj.label70:setText("Tipo");
    obj.label70:setHorzTextAlign("center");
    obj.label70:setWordWrap(true);
    obj.label70:setTextTrimming("none");
    obj.label70:setAutoSize(true);
    obj.label70:setName("label70");
    obj.label70:setFontColor("#D0D0D0");

    obj.edit56 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit56:setParent(obj.flowPart1);
    obj.edit56:setAlign("client");
    obj.edit56:setField("tipo");
    obj.edit56:setHorzTextAlign("center");
    obj.edit56:setFontSize(12);
    obj.edit56:setName("edit56");
    obj.edit56:setFontColor("white");

    obj.flowPart2 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart2:setParent(obj.flowLayout1);
    obj.flowPart2:setMinWidth(30);
    obj.flowPart2:setMaxWidth(400);
    obj.flowPart2:setHeight(35);
    obj.flowPart2:setName("flowPart2");
    obj.flowPart2:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart2:setVertAlign("leading");

    obj.label71 = GUI.fromHandle(_obj_newObject("label"));
    obj.label71:setParent(obj.flowPart2);
    obj.label71:setAlign("top");
    obj.label71:setFontSize(10);
    obj.label71:setText("Formulação");
    obj.label71:setHorzTextAlign("center");
    obj.label71:setWordWrap(true);
    obj.label71:setTextTrimming("none");
    obj.label71:setAutoSize(true);
    obj.label71:setName("label71");
    obj.label71:setFontColor("#D0D0D0");

    obj.edit57 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit57:setParent(obj.flowPart2);
    obj.edit57:setAlign("client");
    obj.edit57:setField("formulacao");
    obj.edit57:setHorzTextAlign("center");
    obj.edit57:setFontSize(12);
    obj.edit57:setName("edit57");
    obj.edit57:setFontColor("white");

    obj.flowPart3 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart3:setParent(obj.flowLayout1);
    obj.flowPart3:setMinWidth(30);
    obj.flowPart3:setMaxWidth(400);
    obj.flowPart3:setHeight(35);
    obj.flowPart3:setName("flowPart3");
    obj.flowPart3:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart3:setVertAlign("leading");

    obj.label72 = GUI.fromHandle(_obj_newObject("label"));
    obj.label72:setParent(obj.flowPart3);
    obj.label72:setAlign("top");
    obj.label72:setFontSize(10);
    obj.label72:setText("Formas e Caminhos");
    obj.label72:setHorzTextAlign("center");
    obj.label72:setWordWrap(true);
    obj.label72:setTextTrimming("none");
    obj.label72:setAutoSize(true);
    obj.label72:setName("label72");
    obj.label72:setFontColor("#D0D0D0");

    obj.edit58 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit58:setParent(obj.flowPart3);
    obj.edit58:setAlign("client");
    obj.edit58:setField("caminhos");
    obj.edit58:setHorzTextAlign("center");
    obj.edit58:setFontSize(12);
    obj.edit58:setName("edit58");
    obj.edit58:setFontColor("white");

    obj.flowLineBreak1 = GUI.fromHandle(_obj_newObject("flowLineBreak"));
    obj.flowLineBreak1:setParent(obj.flowLayout1);
    obj.flowLineBreak1:setName("flowLineBreak1");

    obj.flowPart4 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart4:setParent(obj.flowLayout1);
    obj.flowPart4:setMinWidth(30);
    obj.flowPart4:setMaxWidth(400);
    obj.flowPart4:setHeight(35);
    obj.flowPart4:setName("flowPart4");
    obj.flowPart4:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart4:setVertAlign("leading");

    obj.label73 = GUI.fromHandle(_obj_newObject("label"));
    obj.label73:setParent(obj.flowPart4);
    obj.label73:setAlign("top");
    obj.label73:setFontSize(10);
    obj.label73:setText("Componentes");
    obj.label73:setHorzTextAlign("center");
    obj.label73:setWordWrap(true);
    obj.label73:setTextTrimming("none");
    obj.label73:setAutoSize(true);
    obj.label73:setName("label73");
    obj.label73:setFontColor("#D0D0D0");

    obj.edit59 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit59:setParent(obj.flowPart4);
    obj.edit59:setAlign("client");
    obj.edit59:setField("componentes");
    obj.edit59:setHorzTextAlign("center");
    obj.edit59:setFontSize(12);
    obj.edit59:setName("edit59");
    obj.edit59:setFontColor("white");

    obj.flowLineBreak2 = GUI.fromHandle(_obj_newObject("flowLineBreak"));
    obj.flowLineBreak2:setParent(obj.flowLayout1);
    obj.flowLineBreak2:setName("flowLineBreak2");

    obj.flowPart5 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart5:setParent(obj.flowLayout1);
    obj.flowPart5:setMinWidth(30);
    obj.flowPart5:setMaxWidth(400);
    obj.flowPart5:setHeight(35);
    obj.flowPart5:setName("flowPart5");
    obj.flowPart5:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart5:setVertAlign("leading");

    obj.label74 = GUI.fromHandle(_obj_newObject("label"));
    obj.label74:setParent(obj.flowPart5);
    obj.label74:setAlign("top");
    obj.label74:setFontSize(10);
    obj.label74:setText("Alcance");
    obj.label74:setHorzTextAlign("center");
    obj.label74:setWordWrap(true);
    obj.label74:setTextTrimming("none");
    obj.label74:setAutoSize(true);
    obj.label74:setName("label74");
    obj.label74:setFontColor("#D0D0D0");

    obj.edit60 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit60:setParent(obj.flowPart5);
    obj.edit60:setAlign("client");
    obj.edit60:setField("alcance");
    obj.edit60:setHorzTextAlign("center");
    obj.edit60:setFontSize(12);
    obj.edit60:setName("edit60");
    obj.edit60:setFontColor("white");

    obj.flowPart6 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart6:setParent(obj.flowLayout1);
    obj.flowPart6:setMinWidth(30);
    obj.flowPart6:setMaxWidth(400);
    obj.flowPart6:setHeight(35);
    obj.flowPart6:setName("flowPart6");
    obj.flowPart6:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart6:setVertAlign("leading");

    obj.label75 = GUI.fromHandle(_obj_newObject("label"));
    obj.label75:setParent(obj.flowPart6);
    obj.label75:setAlign("top");
    obj.label75:setFontSize(10);
    obj.label75:setText("Área");
    obj.label75:setHorzTextAlign("center");
    obj.label75:setWordWrap(true);
    obj.label75:setTextTrimming("none");
    obj.label75:setAutoSize(true);
    obj.label75:setName("label75");
    obj.label75:setFontColor("#D0D0D0");

    obj.edit61 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit61:setParent(obj.flowPart6);
    obj.edit61:setAlign("client");
    obj.edit61:setField("area");
    obj.edit61:setHorzTextAlign("center");
    obj.edit61:setFontSize(12);
    obj.edit61:setName("edit61");
    obj.edit61:setFontColor("white");

    obj.flowPart7 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart7:setParent(obj.flowLayout1);
    obj.flowPart7:setMinWidth(30);
    obj.flowPart7:setMaxWidth(400);
    obj.flowPart7:setHeight(35);
    obj.flowPart7:setName("flowPart7");
    obj.flowPart7:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart7:setVertAlign("leading");

    obj.label76 = GUI.fromHandle(_obj_newObject("label"));
    obj.label76:setParent(obj.flowPart7);
    obj.label76:setAlign("top");
    obj.label76:setFontSize(10);
    obj.label76:setText("Duração");
    obj.label76:setHorzTextAlign("center");
    obj.label76:setWordWrap(true);
    obj.label76:setTextTrimming("none");
    obj.label76:setAutoSize(true);
    obj.label76:setName("label76");
    obj.label76:setFontColor("#D0D0D0");

    obj.edit62 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit62:setParent(obj.flowPart7);
    obj.edit62:setAlign("client");
    obj.edit62:setField("duracao");
    obj.edit62:setHorzTextAlign("center");
    obj.edit62:setFontSize(12);
    obj.edit62:setName("edit62");
    obj.edit62:setFontColor("white");

    obj.flowPart8 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart8:setParent(obj.flowLayout1);
    obj.flowPart8:setMinWidth(30);
    obj.flowPart8:setMaxWidth(400);
    obj.flowPart8:setHeight(35);
    obj.flowPart8:setName("flowPart8");
    obj.flowPart8:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart8:setVertAlign("leading");

    obj.label77 = GUI.fromHandle(_obj_newObject("label"));
    obj.label77:setParent(obj.flowPart8);
    obj.label77:setAlign("top");
    obj.label77:setFontSize(10);
    obj.label77:setText("Teste de Resistência");
    obj.label77:setHorzTextAlign("center");
    obj.label77:setWordWrap(true);
    obj.label77:setTextTrimming("none");
    obj.label77:setAutoSize(true);
    obj.label77:setName("label77");
    obj.label77:setFontColor("#D0D0D0");

    obj.edit63 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit63:setParent(obj.flowPart8);
    obj.edit63:setAlign("client");
    obj.edit63:setField("resistencia");
    obj.edit63:setHorzTextAlign("center");
    obj.edit63:setFontSize(12);
    obj.edit63:setName("edit63");
    obj.edit63:setFontColor("white");

    obj.textEditor2 = GUI.fromHandle(_obj_newObject("textEditor"));
    obj.textEditor2:setParent(obj.popMagia);
    obj.textEditor2:setAlign("client");
    obj.textEditor2:setField("descricao");
    obj.textEditor2:setName("textEditor2");

    obj.scrollBox3 = GUI.fromHandle(_obj_newObject("scrollBox"));
    obj.scrollBox3:setParent(obj.rectangle33);
    obj.scrollBox3:setAlign("client");
    obj.scrollBox3:setName("scrollBox3");

    obj.fraMagiasLayout = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.fraMagiasLayout:setParent(obj.scrollBox3);
    obj.fraMagiasLayout:setAlign("top");
    obj.fraMagiasLayout:setHeight(500);
    obj.fraMagiasLayout:setMargins({left=10, right=10, top=10});
    obj.fraMagiasLayout:setAutoHeight(true);
    obj.fraMagiasLayout:setHorzAlign("center");
    obj.fraMagiasLayout:setLineSpacing(3);
    obj.fraMagiasLayout:setName("fraMagiasLayout");
    obj.fraMagiasLayout:setStepSizes({310, 420, 640, 760, 1150});
    obj.fraMagiasLayout:setMinScaledWidth(300);
    obj.fraMagiasLayout:setVertAlign("leading");

    obj.flowLayout2 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout2:setParent(obj.fraMagiasLayout);
    obj.flowLayout2:setAutoHeight(true);
    obj.flowLayout2:setMaxColumns(3);
    obj.flowLayout2:setHorzAlign("center");
    obj.flowLayout2:setOrientation("vertical");
    obj.flowLayout2:setName("flowLayout2");
    obj.flowLayout2:setStepSizes({310, 420, 640, 760, 860, 960, 1150, 1200, 1600});
    obj.flowLayout2:setMinScaledWidth(300);
    obj.flowLayout2:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowLayout2:setVertAlign("leading");

    obj.rectangle34 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle34:setParent(obj.flowLayout2);
    obj.rectangle34:setWidth(600);
    obj.rectangle34:setHeight(220);
    obj.rectangle34:setColor("#272C36");
    obj.rectangle34:setStrokeColor("#8A6C30");
    obj.rectangle34:setStrokeSize(1);
    obj.rectangle34:setMargins({bottom=5});
    obj.rectangle34:setName("rectangle34");

    obj.label78 = GUI.fromHandle(_obj_newObject("label"));
    obj.label78:setParent(obj.rectangle34);
    obj.label78:setAlign("top");
    obj.label78:setHeight(25);
    obj.label78:setText("CAMINHOS PRIMÁRIOS");
    obj.label78:setMargins({top=5,left=5,right=5,bottom=5});
    obj.label78:setName("label78");
    obj.label78:setFontColor("white");

    obj.layout55 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout55:setParent(obj.rectangle34);
    obj.layout55:setAlign("left");
    obj.layout55:setWidth(150);
    obj.layout55:setMargins({right=5});
    obj.layout55:setName("layout55");

    obj.layout56 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout56:setParent(obj.layout55);
    obj.layout56:setAlign("top");
    obj.layout56:setHeight(25);
    obj.layout56:setMargins({top=5,left=5,right=5});
    obj.layout56:setName("layout56");

    obj.label79 = GUI.fromHandle(_obj_newObject("label"));
    obj.label79:setParent(obj.layout56);
    obj.label79:setText("Focus");
    obj.label79:setAlign("client");
    obj.label79:setFontColor("#D8CBB0");
    obj.label79:setName("label79");

    obj.rectangle35 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle35:setParent(obj.layout56);
    obj.rectangle35:setAlign("right");
    obj.rectangle35:setWidth(50);
    obj.rectangle35:setColor("#272C36");
    obj.rectangle35:setStrokeColor("#8A6C30");
    obj.rectangle35:setStrokeSize(1);
    obj.rectangle35:setName("rectangle35");

    obj.label80 = GUI.fromHandle(_obj_newObject("label"));
    obj.label80:setParent(obj.rectangle35);
    obj.label80:setField("focus");
    obj.label80:setAlign("client");
    obj.label80:setHorzTextAlign("center");
    obj.label80:setName("label80");
    obj.label80:setFontColor("white");

    obj.layout57 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout57:setParent(obj.layout55);
    obj.layout57:setAlign("top");
    obj.layout57:setHeight(25);
    obj.layout57:setMargins({top=5,left=5,right=5});
    obj.layout57:setName("layout57");

    obj.label81 = GUI.fromHandle(_obj_newObject("label"));
    obj.label81:setParent(obj.layout57);
    obj.label81:setText("Entender");
    obj.label81:setAlign("left");
    obj.label81:setWidth(90);
    obj.label81:setFontSize(13);
    obj.label81:setFontColor("#D8CBB0");
    obj.label81:setName("label81");

    obj.edit64 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit64:setParent(obj.layout57);
    obj.edit64:setField("entender");
    obj.edit64:setAlign("client");
    obj.edit64:setFontSize(13);
    obj.edit64:setName("edit64");
    obj.edit64:setFontColor("white");

    obj.layout58 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout58:setParent(obj.layout55);
    obj.layout58:setAlign("top");
    obj.layout58:setHeight(25);
    obj.layout58:setMargins({top=5,left=5,right=5});
    obj.layout58:setName("layout58");

    obj.label82 = GUI.fromHandle(_obj_newObject("label"));
    obj.label82:setParent(obj.layout58);
    obj.label82:setText("Controlar");
    obj.label82:setAlign("left");
    obj.label82:setWidth(90);
    obj.label82:setFontSize(13);
    obj.label82:setFontColor("#D8CBB0");
    obj.label82:setName("label82");

    obj.edit65 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit65:setParent(obj.layout58);
    obj.edit65:setField("controlar");
    obj.edit65:setAlign("client");
    obj.edit65:setFontSize(13);
    obj.edit65:setName("edit65");
    obj.edit65:setFontColor("white");

    obj.layout59 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout59:setParent(obj.layout55);
    obj.layout59:setAlign("top");
    obj.layout59:setHeight(25);
    obj.layout59:setMargins({top=5,left=5,right=5});
    obj.layout59:setName("layout59");

    obj.label83 = GUI.fromHandle(_obj_newObject("label"));
    obj.label83:setParent(obj.layout59);
    obj.label83:setText("Criar");
    obj.label83:setAlign("left");
    obj.label83:setWidth(90);
    obj.label83:setFontSize(13);
    obj.label83:setFontColor("#D8CBB0");
    obj.label83:setName("label83");

    obj.edit66 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit66:setParent(obj.layout59);
    obj.edit66:setField("criar");
    obj.edit66:setAlign("client");
    obj.edit66:setFontSize(13);
    obj.edit66:setName("edit66");
    obj.edit66:setFontColor("white");

    obj.layout60 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout60:setParent(obj.rectangle34);
    obj.layout60:setAlign("left");
    obj.layout60:setWidth(220);
    obj.layout60:setMargins({right=5});
    obj.layout60:setName("layout60");

    obj.layout61 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout61:setParent(obj.layout60);
    obj.layout61:setAlign("top");
    obj.layout61:setHeight(25);
    obj.layout61:setMargins({top=5,left=5,right=5});
    obj.layout61:setName("layout61");

    obj.label84 = GUI.fromHandle(_obj_newObject("label"));
    obj.label84:setParent(obj.layout61);
    obj.label84:setText("Ar");
    obj.label84:setAlign("client");
    obj.label84:setName("label84");
    obj.label84:setFontColor("white");

    obj.edit67 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit67:setParent(obj.layout61);
    obj.edit67:setField("ar");
    obj.edit67:setAlign("right");
    obj.edit67:setWidth(30);
    obj.edit67:setHorzTextAlign("center");
    obj.edit67:setName("edit67");
    obj.edit67:setFontSize(15);
    obj.edit67:setFontColor("white");

    obj.layout62 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout62:setParent(obj.layout61);
    obj.layout62:setAlign("right");
    obj.layout62:setWidth(90);
    obj.layout62:setName("layout62");

    obj.rectangle36 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle36:setParent(obj.layout62);
    obj.rectangle36:setAlign("right");
    obj.rectangle36:setWidth(30);
    obj.rectangle36:setColor("#272C36");
    obj.rectangle36:setStrokeColor("#8A6C30");
    obj.rectangle36:setStrokeSize(1);
    obj.rectangle36:setHint("Entender");
    obj.rectangle36:setName("rectangle36");

    obj.label85 = GUI.fromHandle(_obj_newObject("label"));
    obj.label85:setParent(obj.rectangle36);
    obj.label85:setField("arEntender");
    obj.label85:setAlign("client");
    obj.label85:setHorzTextAlign("center");
    obj.label85:setName("label85");
    obj.label85:setFontColor("white");

    obj.rectangle37 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle37:setParent(obj.layout62);
    obj.rectangle37:setAlign("right");
    obj.rectangle37:setWidth(30);
    obj.rectangle37:setColor("#272C36");
    obj.rectangle37:setStrokeColor("#8A6C30");
    obj.rectangle37:setStrokeSize(1);
    obj.rectangle37:setHint("Controlar");
    obj.rectangle37:setName("rectangle37");

    obj.label86 = GUI.fromHandle(_obj_newObject("label"));
    obj.label86:setParent(obj.rectangle37);
    obj.label86:setField("arControlar");
    obj.label86:setAlign("client");
    obj.label86:setHorzTextAlign("center");
    obj.label86:setName("label86");
    obj.label86:setFontColor("white");

    obj.rectangle38 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle38:setParent(obj.layout62);
    obj.rectangle38:setAlign("right");
    obj.rectangle38:setWidth(30);
    obj.rectangle38:setColor("#272C36");
    obj.rectangle38:setStrokeColor("#8A6C30");
    obj.rectangle38:setStrokeSize(1);
    obj.rectangle38:setHint("Criar");
    obj.rectangle38:setName("rectangle38");

    obj.label87 = GUI.fromHandle(_obj_newObject("label"));
    obj.label87:setParent(obj.rectangle38);
    obj.label87:setField("arCriar");
    obj.label87:setAlign("client");
    obj.label87:setHorzTextAlign("center");
    obj.label87:setName("label87");
    obj.label87:setFontColor("white");

    obj.dataLink21 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink21:setParent(obj.layout61);
    obj.dataLink21:setFields({'ar','entender','controlar','criar'});
    obj.dataLink21:setName("dataLink21");

    obj.layout63 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout63:setParent(obj.layout60);
    obj.layout63:setAlign("top");
    obj.layout63:setHeight(25);
    obj.layout63:setMargins({top=5,left=5,right=5});
    obj.layout63:setName("layout63");

    obj.label88 = GUI.fromHandle(_obj_newObject("label"));
    obj.label88:setParent(obj.layout63);
    obj.label88:setText("Terra");
    obj.label88:setAlign("client");
    obj.label88:setName("label88");
    obj.label88:setFontColor("white");

    obj.edit68 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit68:setParent(obj.layout63);
    obj.edit68:setField("terra");
    obj.edit68:setAlign("right");
    obj.edit68:setWidth(30);
    obj.edit68:setHorzTextAlign("center");
    obj.edit68:setName("edit68");
    obj.edit68:setFontSize(15);
    obj.edit68:setFontColor("white");

    obj.layout64 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout64:setParent(obj.layout63);
    obj.layout64:setAlign("right");
    obj.layout64:setWidth(90);
    obj.layout64:setName("layout64");

    obj.rectangle39 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle39:setParent(obj.layout64);
    obj.rectangle39:setAlign("right");
    obj.rectangle39:setWidth(30);
    obj.rectangle39:setColor("#272C36");
    obj.rectangle39:setStrokeColor("#8A6C30");
    obj.rectangle39:setStrokeSize(1);
    obj.rectangle39:setHint("Entender");
    obj.rectangle39:setName("rectangle39");

    obj.label89 = GUI.fromHandle(_obj_newObject("label"));
    obj.label89:setParent(obj.rectangle39);
    obj.label89:setField("terraEntender");
    obj.label89:setAlign("client");
    obj.label89:setHorzTextAlign("center");
    obj.label89:setName("label89");
    obj.label89:setFontColor("white");

    obj.rectangle40 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle40:setParent(obj.layout64);
    obj.rectangle40:setAlign("right");
    obj.rectangle40:setWidth(30);
    obj.rectangle40:setColor("#272C36");
    obj.rectangle40:setStrokeColor("#8A6C30");
    obj.rectangle40:setStrokeSize(1);
    obj.rectangle40:setHint("Controlar");
    obj.rectangle40:setName("rectangle40");

    obj.label90 = GUI.fromHandle(_obj_newObject("label"));
    obj.label90:setParent(obj.rectangle40);
    obj.label90:setField("terraControlar");
    obj.label90:setAlign("client");
    obj.label90:setHorzTextAlign("center");
    obj.label90:setName("label90");
    obj.label90:setFontColor("white");

    obj.rectangle41 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle41:setParent(obj.layout64);
    obj.rectangle41:setAlign("right");
    obj.rectangle41:setWidth(30);
    obj.rectangle41:setColor("#272C36");
    obj.rectangle41:setStrokeColor("#8A6C30");
    obj.rectangle41:setStrokeSize(1);
    obj.rectangle41:setHint("Criar");
    obj.rectangle41:setName("rectangle41");

    obj.label91 = GUI.fromHandle(_obj_newObject("label"));
    obj.label91:setParent(obj.rectangle41);
    obj.label91:setField("terraCriar");
    obj.label91:setAlign("client");
    obj.label91:setHorzTextAlign("center");
    obj.label91:setName("label91");
    obj.label91:setFontColor("white");

    obj.dataLink22 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink22:setParent(obj.layout63);
    obj.dataLink22:setFields({'terra','entender','controlar','criar'});
    obj.dataLink22:setName("dataLink22");

    obj.layout65 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout65:setParent(obj.layout60);
    obj.layout65:setAlign("top");
    obj.layout65:setHeight(25);
    obj.layout65:setMargins({top=5,left=5,right=5});
    obj.layout65:setName("layout65");

    obj.label92 = GUI.fromHandle(_obj_newObject("label"));
    obj.label92:setParent(obj.layout65);
    obj.label92:setText("Água");
    obj.label92:setAlign("client");
    obj.label92:setName("label92");
    obj.label92:setFontColor("white");

    obj.edit69 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit69:setParent(obj.layout65);
    obj.edit69:setField("agua");
    obj.edit69:setAlign("right");
    obj.edit69:setWidth(30);
    obj.edit69:setHorzTextAlign("center");
    obj.edit69:setName("edit69");
    obj.edit69:setFontSize(15);
    obj.edit69:setFontColor("white");

    obj.layout66 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout66:setParent(obj.layout65);
    obj.layout66:setAlign("right");
    obj.layout66:setWidth(90);
    obj.layout66:setName("layout66");

    obj.rectangle42 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle42:setParent(obj.layout66);
    obj.rectangle42:setAlign("right");
    obj.rectangle42:setWidth(30);
    obj.rectangle42:setColor("#272C36");
    obj.rectangle42:setStrokeColor("#8A6C30");
    obj.rectangle42:setStrokeSize(1);
    obj.rectangle42:setHint("Entender");
    obj.rectangle42:setName("rectangle42");

    obj.label93 = GUI.fromHandle(_obj_newObject("label"));
    obj.label93:setParent(obj.rectangle42);
    obj.label93:setField("aguaEntender");
    obj.label93:setAlign("client");
    obj.label93:setHorzTextAlign("center");
    obj.label93:setName("label93");
    obj.label93:setFontColor("white");

    obj.rectangle43 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle43:setParent(obj.layout66);
    obj.rectangle43:setAlign("right");
    obj.rectangle43:setWidth(30);
    obj.rectangle43:setColor("#272C36");
    obj.rectangle43:setStrokeColor("#8A6C30");
    obj.rectangle43:setStrokeSize(1);
    obj.rectangle43:setHint("Controlar");
    obj.rectangle43:setName("rectangle43");

    obj.label94 = GUI.fromHandle(_obj_newObject("label"));
    obj.label94:setParent(obj.rectangle43);
    obj.label94:setField("aguaControlar");
    obj.label94:setAlign("client");
    obj.label94:setHorzTextAlign("center");
    obj.label94:setName("label94");
    obj.label94:setFontColor("white");

    obj.rectangle44 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle44:setParent(obj.layout66);
    obj.rectangle44:setAlign("right");
    obj.rectangle44:setWidth(30);
    obj.rectangle44:setColor("#272C36");
    obj.rectangle44:setStrokeColor("#8A6C30");
    obj.rectangle44:setStrokeSize(1);
    obj.rectangle44:setHint("Criar");
    obj.rectangle44:setName("rectangle44");

    obj.label95 = GUI.fromHandle(_obj_newObject("label"));
    obj.label95:setParent(obj.rectangle44);
    obj.label95:setField("aguaCriar");
    obj.label95:setAlign("client");
    obj.label95:setHorzTextAlign("center");
    obj.label95:setName("label95");
    obj.label95:setFontColor("white");

    obj.dataLink23 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink23:setParent(obj.layout65);
    obj.dataLink23:setFields({'agua','entender','controlar','criar'});
    obj.dataLink23:setName("dataLink23");

    obj.layout67 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout67:setParent(obj.layout60);
    obj.layout67:setAlign("top");
    obj.layout67:setHeight(25);
    obj.layout67:setMargins({top=5,left=5,right=5});
    obj.layout67:setName("layout67");

    obj.label96 = GUI.fromHandle(_obj_newObject("label"));
    obj.label96:setParent(obj.layout67);
    obj.label96:setText("Fogo");
    obj.label96:setAlign("client");
    obj.label96:setName("label96");
    obj.label96:setFontColor("white");

    obj.edit70 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit70:setParent(obj.layout67);
    obj.edit70:setField("fogo");
    obj.edit70:setAlign("right");
    obj.edit70:setWidth(30);
    obj.edit70:setHorzTextAlign("center");
    obj.edit70:setName("edit70");
    obj.edit70:setFontSize(15);
    obj.edit70:setFontColor("white");

    obj.layout68 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout68:setParent(obj.layout67);
    obj.layout68:setAlign("right");
    obj.layout68:setWidth(90);
    obj.layout68:setName("layout68");

    obj.rectangle45 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle45:setParent(obj.layout68);
    obj.rectangle45:setAlign("right");
    obj.rectangle45:setWidth(30);
    obj.rectangle45:setColor("#272C36");
    obj.rectangle45:setStrokeColor("#8A6C30");
    obj.rectangle45:setStrokeSize(1);
    obj.rectangle45:setHint("Entender");
    obj.rectangle45:setName("rectangle45");

    obj.label97 = GUI.fromHandle(_obj_newObject("label"));
    obj.label97:setParent(obj.rectangle45);
    obj.label97:setField("fogoEntender");
    obj.label97:setAlign("client");
    obj.label97:setHorzTextAlign("center");
    obj.label97:setName("label97");
    obj.label97:setFontColor("white");

    obj.rectangle46 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle46:setParent(obj.layout68);
    obj.rectangle46:setAlign("right");
    obj.rectangle46:setWidth(30);
    obj.rectangle46:setColor("#272C36");
    obj.rectangle46:setStrokeColor("#8A6C30");
    obj.rectangle46:setStrokeSize(1);
    obj.rectangle46:setHint("Controlar");
    obj.rectangle46:setName("rectangle46");

    obj.label98 = GUI.fromHandle(_obj_newObject("label"));
    obj.label98:setParent(obj.rectangle46);
    obj.label98:setField("fogoControlar");
    obj.label98:setAlign("client");
    obj.label98:setHorzTextAlign("center");
    obj.label98:setName("label98");
    obj.label98:setFontColor("white");

    obj.rectangle47 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle47:setParent(obj.layout68);
    obj.rectangle47:setAlign("right");
    obj.rectangle47:setWidth(30);
    obj.rectangle47:setColor("#272C36");
    obj.rectangle47:setStrokeColor("#8A6C30");
    obj.rectangle47:setStrokeSize(1);
    obj.rectangle47:setHint("Criar");
    obj.rectangle47:setName("rectangle47");

    obj.label99 = GUI.fromHandle(_obj_newObject("label"));
    obj.label99:setParent(obj.rectangle47);
    obj.label99:setField("fogoCriar");
    obj.label99:setAlign("client");
    obj.label99:setHorzTextAlign("center");
    obj.label99:setName("label99");
    obj.label99:setFontColor("white");

    obj.dataLink24 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink24:setParent(obj.layout67);
    obj.dataLink24:setFields({'fogo','entender','controlar','criar'});
    obj.dataLink24:setName("dataLink24");

    obj.layout69 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout69:setParent(obj.layout60);
    obj.layout69:setAlign("top");
    obj.layout69:setHeight(25);
    obj.layout69:setMargins({top=5,left=5,right=5});
    obj.layout69:setName("layout69");

    obj.label100 = GUI.fromHandle(_obj_newObject("label"));
    obj.label100:setParent(obj.layout69);
    obj.label100:setText("Luz");
    obj.label100:setAlign("client");
    obj.label100:setName("label100");
    obj.label100:setFontColor("white");

    obj.edit71 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit71:setParent(obj.layout69);
    obj.edit71:setField("luz");
    obj.edit71:setAlign("right");
    obj.edit71:setWidth(30);
    obj.edit71:setHorzTextAlign("center");
    obj.edit71:setName("edit71");
    obj.edit71:setFontSize(15);
    obj.edit71:setFontColor("white");

    obj.layout70 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout70:setParent(obj.layout69);
    obj.layout70:setAlign("right");
    obj.layout70:setWidth(90);
    obj.layout70:setName("layout70");

    obj.rectangle48 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle48:setParent(obj.layout70);
    obj.rectangle48:setAlign("right");
    obj.rectangle48:setWidth(30);
    obj.rectangle48:setColor("#272C36");
    obj.rectangle48:setStrokeColor("#8A6C30");
    obj.rectangle48:setStrokeSize(1);
    obj.rectangle48:setHint("Entender");
    obj.rectangle48:setName("rectangle48");

    obj.label101 = GUI.fromHandle(_obj_newObject("label"));
    obj.label101:setParent(obj.rectangle48);
    obj.label101:setField("luzEntender");
    obj.label101:setAlign("client");
    obj.label101:setHorzTextAlign("center");
    obj.label101:setName("label101");
    obj.label101:setFontColor("white");

    obj.rectangle49 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle49:setParent(obj.layout70);
    obj.rectangle49:setAlign("right");
    obj.rectangle49:setWidth(30);
    obj.rectangle49:setColor("#272C36");
    obj.rectangle49:setStrokeColor("#8A6C30");
    obj.rectangle49:setStrokeSize(1);
    obj.rectangle49:setHint("Controlar");
    obj.rectangle49:setName("rectangle49");

    obj.label102 = GUI.fromHandle(_obj_newObject("label"));
    obj.label102:setParent(obj.rectangle49);
    obj.label102:setField("luzControlar");
    obj.label102:setAlign("client");
    obj.label102:setHorzTextAlign("center");
    obj.label102:setName("label102");
    obj.label102:setFontColor("white");

    obj.rectangle50 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle50:setParent(obj.layout70);
    obj.rectangle50:setAlign("right");
    obj.rectangle50:setWidth(30);
    obj.rectangle50:setColor("#272C36");
    obj.rectangle50:setStrokeColor("#8A6C30");
    obj.rectangle50:setStrokeSize(1);
    obj.rectangle50:setHint("Criar");
    obj.rectangle50:setName("rectangle50");

    obj.label103 = GUI.fromHandle(_obj_newObject("label"));
    obj.label103:setParent(obj.rectangle50);
    obj.label103:setField("luzCriar");
    obj.label103:setAlign("client");
    obj.label103:setHorzTextAlign("center");
    obj.label103:setName("label103");
    obj.label103:setFontColor("white");

    obj.dataLink25 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink25:setParent(obj.layout69);
    obj.dataLink25:setFields({'luz','entender','controlar','criar'});
    obj.dataLink25:setName("dataLink25");

    obj.layout71 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout71:setParent(obj.layout60);
    obj.layout71:setAlign("top");
    obj.layout71:setHeight(25);
    obj.layout71:setMargins({top=5,left=5,right=5});
    obj.layout71:setName("layout71");

    obj.label104 = GUI.fromHandle(_obj_newObject("label"));
    obj.label104:setParent(obj.layout71);
    obj.label104:setText("Trevas");
    obj.label104:setAlign("client");
    obj.label104:setName("label104");
    obj.label104:setFontColor("white");

    obj.edit72 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit72:setParent(obj.layout71);
    obj.edit72:setField("trevas");
    obj.edit72:setAlign("right");
    obj.edit72:setWidth(30);
    obj.edit72:setHorzTextAlign("center");
    obj.edit72:setName("edit72");
    obj.edit72:setFontSize(15);
    obj.edit72:setFontColor("white");

    obj.layout72 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout72:setParent(obj.layout71);
    obj.layout72:setAlign("right");
    obj.layout72:setWidth(90);
    obj.layout72:setName("layout72");

    obj.rectangle51 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle51:setParent(obj.layout72);
    obj.rectangle51:setAlign("right");
    obj.rectangle51:setWidth(30);
    obj.rectangle51:setColor("#272C36");
    obj.rectangle51:setStrokeColor("#8A6C30");
    obj.rectangle51:setStrokeSize(1);
    obj.rectangle51:setHint("Entender");
    obj.rectangle51:setName("rectangle51");

    obj.label105 = GUI.fromHandle(_obj_newObject("label"));
    obj.label105:setParent(obj.rectangle51);
    obj.label105:setField("trevasEntender");
    obj.label105:setAlign("client");
    obj.label105:setHorzTextAlign("center");
    obj.label105:setName("label105");
    obj.label105:setFontColor("white");

    obj.rectangle52 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle52:setParent(obj.layout72);
    obj.rectangle52:setAlign("right");
    obj.rectangle52:setWidth(30);
    obj.rectangle52:setColor("#272C36");
    obj.rectangle52:setStrokeColor("#8A6C30");
    obj.rectangle52:setStrokeSize(1);
    obj.rectangle52:setHint("Controlar");
    obj.rectangle52:setName("rectangle52");

    obj.label106 = GUI.fromHandle(_obj_newObject("label"));
    obj.label106:setParent(obj.rectangle52);
    obj.label106:setField("trevasControlar");
    obj.label106:setAlign("client");
    obj.label106:setHorzTextAlign("center");
    obj.label106:setName("label106");
    obj.label106:setFontColor("white");

    obj.rectangle53 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle53:setParent(obj.layout72);
    obj.rectangle53:setAlign("right");
    obj.rectangle53:setWidth(30);
    obj.rectangle53:setColor("#272C36");
    obj.rectangle53:setStrokeColor("#8A6C30");
    obj.rectangle53:setStrokeSize(1);
    obj.rectangle53:setHint("Criar");
    obj.rectangle53:setName("rectangle53");

    obj.label107 = GUI.fromHandle(_obj_newObject("label"));
    obj.label107:setParent(obj.rectangle53);
    obj.label107:setField("trevasCriar");
    obj.label107:setAlign("client");
    obj.label107:setHorzTextAlign("center");
    obj.label107:setName("label107");
    obj.label107:setFontColor("white");

    obj.dataLink26 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink26:setParent(obj.layout71);
    obj.dataLink26:setFields({'trevas','entender','controlar','criar'});
    obj.dataLink26:setName("dataLink26");

    obj.layout73 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout73:setParent(obj.rectangle34);
    obj.layout73:setAlign("left");
    obj.layout73:setWidth(220);
    obj.layout73:setMargins({right=0});
    obj.layout73:setName("layout73");

    obj.layout74 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout74:setParent(obj.layout73);
    obj.layout74:setAlign("top");
    obj.layout74:setHeight(25);
    obj.layout74:setMargins({top=5,left=5,right=5});
    obj.layout74:setName("layout74");

    obj.label108 = GUI.fromHandle(_obj_newObject("label"));
    obj.label108:setParent(obj.layout74);
    obj.label108:setText("Arkanum");
    obj.label108:setAlign("client");
    obj.label108:setName("label108");
    obj.label108:setFontColor("white");

    obj.edit73 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit73:setParent(obj.layout74);
    obj.edit73:setField("arkanum");
    obj.edit73:setAlign("right");
    obj.edit73:setWidth(30);
    obj.edit73:setHorzTextAlign("center");
    obj.edit73:setName("edit73");
    obj.edit73:setFontSize(15);
    obj.edit73:setFontColor("white");

    obj.layout75 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout75:setParent(obj.layout74);
    obj.layout75:setAlign("right");
    obj.layout75:setWidth(90);
    obj.layout75:setName("layout75");

    obj.rectangle54 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle54:setParent(obj.layout75);
    obj.rectangle54:setAlign("right");
    obj.rectangle54:setWidth(30);
    obj.rectangle54:setColor("#272C36");
    obj.rectangle54:setStrokeColor("#8A6C30");
    obj.rectangle54:setStrokeSize(1);
    obj.rectangle54:setHint("Entender");
    obj.rectangle54:setName("rectangle54");

    obj.label109 = GUI.fromHandle(_obj_newObject("label"));
    obj.label109:setParent(obj.rectangle54);
    obj.label109:setField("arkanumEntender");
    obj.label109:setAlign("client");
    obj.label109:setHorzTextAlign("center");
    obj.label109:setName("label109");
    obj.label109:setFontColor("white");

    obj.rectangle55 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle55:setParent(obj.layout75);
    obj.rectangle55:setAlign("right");
    obj.rectangle55:setWidth(30);
    obj.rectangle55:setColor("#272C36");
    obj.rectangle55:setStrokeColor("#8A6C30");
    obj.rectangle55:setStrokeSize(1);
    obj.rectangle55:setHint("Controlar");
    obj.rectangle55:setName("rectangle55");

    obj.label110 = GUI.fromHandle(_obj_newObject("label"));
    obj.label110:setParent(obj.rectangle55);
    obj.label110:setField("arkanumControlar");
    obj.label110:setAlign("client");
    obj.label110:setHorzTextAlign("center");
    obj.label110:setName("label110");
    obj.label110:setFontColor("white");

    obj.rectangle56 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle56:setParent(obj.layout75);
    obj.rectangle56:setAlign("right");
    obj.rectangle56:setWidth(30);
    obj.rectangle56:setColor("#272C36");
    obj.rectangle56:setStrokeColor("#8A6C30");
    obj.rectangle56:setStrokeSize(1);
    obj.rectangle56:setHint("Criar");
    obj.rectangle56:setName("rectangle56");

    obj.label111 = GUI.fromHandle(_obj_newObject("label"));
    obj.label111:setParent(obj.rectangle56);
    obj.label111:setField("arkanumCriar");
    obj.label111:setAlign("client");
    obj.label111:setHorzTextAlign("center");
    obj.label111:setName("label111");
    obj.label111:setFontColor("white");

    obj.dataLink27 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink27:setParent(obj.layout74);
    obj.dataLink27:setFields({'arkanum','entender','controlar','criar'});
    obj.dataLink27:setName("dataLink27");

    obj.layout76 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout76:setParent(obj.layout73);
    obj.layout76:setAlign("top");
    obj.layout76:setHeight(25);
    obj.layout76:setMargins({top=5,left=5,right=5});
    obj.layout76:setName("layout76");

    obj.label112 = GUI.fromHandle(_obj_newObject("label"));
    obj.label112:setParent(obj.layout76);
    obj.label112:setText("Spiritum");
    obj.label112:setAlign("client");
    obj.label112:setName("label112");
    obj.label112:setFontColor("white");

    obj.edit74 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit74:setParent(obj.layout76);
    obj.edit74:setField("spiritum");
    obj.edit74:setAlign("right");
    obj.edit74:setWidth(30);
    obj.edit74:setHorzTextAlign("center");
    obj.edit74:setName("edit74");
    obj.edit74:setFontSize(15);
    obj.edit74:setFontColor("white");

    obj.layout77 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout77:setParent(obj.layout76);
    obj.layout77:setAlign("right");
    obj.layout77:setWidth(90);
    obj.layout77:setName("layout77");

    obj.rectangle57 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle57:setParent(obj.layout77);
    obj.rectangle57:setAlign("right");
    obj.rectangle57:setWidth(30);
    obj.rectangle57:setColor("#272C36");
    obj.rectangle57:setStrokeColor("#8A6C30");
    obj.rectangle57:setStrokeSize(1);
    obj.rectangle57:setHint("Entender");
    obj.rectangle57:setName("rectangle57");

    obj.label113 = GUI.fromHandle(_obj_newObject("label"));
    obj.label113:setParent(obj.rectangle57);
    obj.label113:setField("spiritumEntender");
    obj.label113:setAlign("client");
    obj.label113:setHorzTextAlign("center");
    obj.label113:setName("label113");
    obj.label113:setFontColor("white");

    obj.rectangle58 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle58:setParent(obj.layout77);
    obj.rectangle58:setAlign("right");
    obj.rectangle58:setWidth(30);
    obj.rectangle58:setColor("#272C36");
    obj.rectangle58:setStrokeColor("#8A6C30");
    obj.rectangle58:setStrokeSize(1);
    obj.rectangle58:setHint("Controlar");
    obj.rectangle58:setName("rectangle58");

    obj.label114 = GUI.fromHandle(_obj_newObject("label"));
    obj.label114:setParent(obj.rectangle58);
    obj.label114:setField("spiritumControlar");
    obj.label114:setAlign("client");
    obj.label114:setHorzTextAlign("center");
    obj.label114:setName("label114");
    obj.label114:setFontColor("white");

    obj.rectangle59 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle59:setParent(obj.layout77);
    obj.rectangle59:setAlign("right");
    obj.rectangle59:setWidth(30);
    obj.rectangle59:setColor("#272C36");
    obj.rectangle59:setStrokeColor("#8A6C30");
    obj.rectangle59:setStrokeSize(1);
    obj.rectangle59:setHint("Criar");
    obj.rectangle59:setName("rectangle59");

    obj.label115 = GUI.fromHandle(_obj_newObject("label"));
    obj.label115:setParent(obj.rectangle59);
    obj.label115:setField("spiritumCriar");
    obj.label115:setAlign("client");
    obj.label115:setHorzTextAlign("center");
    obj.label115:setName("label115");
    obj.label115:setFontColor("white");

    obj.dataLink28 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink28:setParent(obj.layout76);
    obj.dataLink28:setFields({'spiritum','entender','controlar','criar'});
    obj.dataLink28:setName("dataLink28");

    obj.layout78 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout78:setParent(obj.layout73);
    obj.layout78:setAlign("top");
    obj.layout78:setHeight(25);
    obj.layout78:setMargins({top=5,left=5,right=5});
    obj.layout78:setName("layout78");

    obj.label116 = GUI.fromHandle(_obj_newObject("label"));
    obj.label116:setParent(obj.layout78);
    obj.label116:setText("Humanos");
    obj.label116:setAlign("client");
    obj.label116:setName("label116");
    obj.label116:setFontColor("white");

    obj.edit75 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit75:setParent(obj.layout78);
    obj.edit75:setField("humanos");
    obj.edit75:setAlign("right");
    obj.edit75:setWidth(30);
    obj.edit75:setHorzTextAlign("center");
    obj.edit75:setName("edit75");
    obj.edit75:setFontSize(15);
    obj.edit75:setFontColor("white");

    obj.layout79 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout79:setParent(obj.layout78);
    obj.layout79:setAlign("right");
    obj.layout79:setWidth(90);
    obj.layout79:setName("layout79");

    obj.rectangle60 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle60:setParent(obj.layout79);
    obj.rectangle60:setAlign("right");
    obj.rectangle60:setWidth(30);
    obj.rectangle60:setColor("#272C36");
    obj.rectangle60:setStrokeColor("#8A6C30");
    obj.rectangle60:setStrokeSize(1);
    obj.rectangle60:setHint("Entender");
    obj.rectangle60:setName("rectangle60");

    obj.label117 = GUI.fromHandle(_obj_newObject("label"));
    obj.label117:setParent(obj.rectangle60);
    obj.label117:setField("humanosEntender");
    obj.label117:setAlign("client");
    obj.label117:setHorzTextAlign("center");
    obj.label117:setName("label117");
    obj.label117:setFontColor("white");

    obj.rectangle61 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle61:setParent(obj.layout79);
    obj.rectangle61:setAlign("right");
    obj.rectangle61:setWidth(30);
    obj.rectangle61:setColor("#272C36");
    obj.rectangle61:setStrokeColor("#8A6C30");
    obj.rectangle61:setStrokeSize(1);
    obj.rectangle61:setHint("Controlar");
    obj.rectangle61:setName("rectangle61");

    obj.label118 = GUI.fromHandle(_obj_newObject("label"));
    obj.label118:setParent(obj.rectangle61);
    obj.label118:setField("humanosControlar");
    obj.label118:setAlign("client");
    obj.label118:setHorzTextAlign("center");
    obj.label118:setName("label118");
    obj.label118:setFontColor("white");

    obj.rectangle62 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle62:setParent(obj.layout79);
    obj.rectangle62:setAlign("right");
    obj.rectangle62:setWidth(30);
    obj.rectangle62:setColor("#272C36");
    obj.rectangle62:setStrokeColor("#8A6C30");
    obj.rectangle62:setStrokeSize(1);
    obj.rectangle62:setHint("Criar");
    obj.rectangle62:setName("rectangle62");

    obj.label119 = GUI.fromHandle(_obj_newObject("label"));
    obj.label119:setParent(obj.rectangle62);
    obj.label119:setField("humanosCriar");
    obj.label119:setAlign("client");
    obj.label119:setHorzTextAlign("center");
    obj.label119:setName("label119");
    obj.label119:setFontColor("white");

    obj.dataLink29 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink29:setParent(obj.layout78);
    obj.dataLink29:setFields({'humanos','entender','controlar','criar'});
    obj.dataLink29:setName("dataLink29");

    obj.layout80 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout80:setParent(obj.layout73);
    obj.layout80:setAlign("top");
    obj.layout80:setHeight(25);
    obj.layout80:setMargins({top=5,left=5,right=5});
    obj.layout80:setName("layout80");

    obj.label120 = GUI.fromHandle(_obj_newObject("label"));
    obj.label120:setParent(obj.layout80);
    obj.label120:setText("Plantas");
    obj.label120:setAlign("client");
    obj.label120:setName("label120");
    obj.label120:setFontColor("white");

    obj.edit76 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit76:setParent(obj.layout80);
    obj.edit76:setField("plantas");
    obj.edit76:setAlign("right");
    obj.edit76:setWidth(30);
    obj.edit76:setHorzTextAlign("center");
    obj.edit76:setName("edit76");
    obj.edit76:setFontSize(15);
    obj.edit76:setFontColor("white");

    obj.layout81 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout81:setParent(obj.layout80);
    obj.layout81:setAlign("right");
    obj.layout81:setWidth(90);
    obj.layout81:setName("layout81");

    obj.rectangle63 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle63:setParent(obj.layout81);
    obj.rectangle63:setAlign("right");
    obj.rectangle63:setWidth(30);
    obj.rectangle63:setColor("#272C36");
    obj.rectangle63:setStrokeColor("#8A6C30");
    obj.rectangle63:setStrokeSize(1);
    obj.rectangle63:setHint("Entender");
    obj.rectangle63:setName("rectangle63");

    obj.label121 = GUI.fromHandle(_obj_newObject("label"));
    obj.label121:setParent(obj.rectangle63);
    obj.label121:setField("plantasEntender");
    obj.label121:setAlign("client");
    obj.label121:setHorzTextAlign("center");
    obj.label121:setName("label121");
    obj.label121:setFontColor("white");

    obj.rectangle64 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle64:setParent(obj.layout81);
    obj.rectangle64:setAlign("right");
    obj.rectangle64:setWidth(30);
    obj.rectangle64:setColor("#272C36");
    obj.rectangle64:setStrokeColor("#8A6C30");
    obj.rectangle64:setStrokeSize(1);
    obj.rectangle64:setHint("Controlar");
    obj.rectangle64:setName("rectangle64");

    obj.label122 = GUI.fromHandle(_obj_newObject("label"));
    obj.label122:setParent(obj.rectangle64);
    obj.label122:setField("plantasControlar");
    obj.label122:setAlign("client");
    obj.label122:setHorzTextAlign("center");
    obj.label122:setName("label122");
    obj.label122:setFontColor("white");

    obj.rectangle65 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle65:setParent(obj.layout81);
    obj.rectangle65:setAlign("right");
    obj.rectangle65:setWidth(30);
    obj.rectangle65:setColor("#272C36");
    obj.rectangle65:setStrokeColor("#8A6C30");
    obj.rectangle65:setStrokeSize(1);
    obj.rectangle65:setHint("Criar");
    obj.rectangle65:setName("rectangle65");

    obj.label123 = GUI.fromHandle(_obj_newObject("label"));
    obj.label123:setParent(obj.rectangle65);
    obj.label123:setField("plantasCriar");
    obj.label123:setAlign("client");
    obj.label123:setHorzTextAlign("center");
    obj.label123:setName("label123");
    obj.label123:setFontColor("white");

    obj.dataLink30 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink30:setParent(obj.layout80);
    obj.dataLink30:setFields({'plantas','entender','controlar','criar'});
    obj.dataLink30:setName("dataLink30");

    obj.layout82 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout82:setParent(obj.layout73);
    obj.layout82:setAlign("top");
    obj.layout82:setHeight(25);
    obj.layout82:setMargins({top=5,left=5,right=5});
    obj.layout82:setName("layout82");

    obj.label124 = GUI.fromHandle(_obj_newObject("label"));
    obj.label124:setParent(obj.layout82);
    obj.label124:setText("Animais");
    obj.label124:setAlign("client");
    obj.label124:setName("label124");
    obj.label124:setFontColor("white");

    obj.edit77 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit77:setParent(obj.layout82);
    obj.edit77:setField("animais");
    obj.edit77:setAlign("right");
    obj.edit77:setWidth(30);
    obj.edit77:setHorzTextAlign("center");
    obj.edit77:setName("edit77");
    obj.edit77:setFontSize(15);
    obj.edit77:setFontColor("white");

    obj.layout83 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout83:setParent(obj.layout82);
    obj.layout83:setAlign("right");
    obj.layout83:setWidth(90);
    obj.layout83:setName("layout83");

    obj.rectangle66 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle66:setParent(obj.layout83);
    obj.rectangle66:setAlign("right");
    obj.rectangle66:setWidth(30);
    obj.rectangle66:setColor("#272C36");
    obj.rectangle66:setStrokeColor("#8A6C30");
    obj.rectangle66:setStrokeSize(1);
    obj.rectangle66:setHint("Entender");
    obj.rectangle66:setName("rectangle66");

    obj.label125 = GUI.fromHandle(_obj_newObject("label"));
    obj.label125:setParent(obj.rectangle66);
    obj.label125:setField("animaisEntender");
    obj.label125:setAlign("client");
    obj.label125:setHorzTextAlign("center");
    obj.label125:setName("label125");
    obj.label125:setFontColor("white");

    obj.rectangle67 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle67:setParent(obj.layout83);
    obj.rectangle67:setAlign("right");
    obj.rectangle67:setWidth(30);
    obj.rectangle67:setColor("#272C36");
    obj.rectangle67:setStrokeColor("#8A6C30");
    obj.rectangle67:setStrokeSize(1);
    obj.rectangle67:setHint("Controlar");
    obj.rectangle67:setName("rectangle67");

    obj.label126 = GUI.fromHandle(_obj_newObject("label"));
    obj.label126:setParent(obj.rectangle67);
    obj.label126:setField("animaisControlar");
    obj.label126:setAlign("client");
    obj.label126:setHorzTextAlign("center");
    obj.label126:setName("label126");
    obj.label126:setFontColor("white");

    obj.rectangle68 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle68:setParent(obj.layout83);
    obj.rectangle68:setAlign("right");
    obj.rectangle68:setWidth(30);
    obj.rectangle68:setColor("#272C36");
    obj.rectangle68:setStrokeColor("#8A6C30");
    obj.rectangle68:setStrokeSize(1);
    obj.rectangle68:setHint("Criar");
    obj.rectangle68:setName("rectangle68");

    obj.label127 = GUI.fromHandle(_obj_newObject("label"));
    obj.label127:setParent(obj.rectangle68);
    obj.label127:setField("animaisCriar");
    obj.label127:setAlign("client");
    obj.label127:setHorzTextAlign("center");
    obj.label127:setName("label127");
    obj.label127:setFontColor("white");

    obj.dataLink31 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink31:setParent(obj.layout82);
    obj.dataLink31:setFields({'animais','entender','controlar','criar'});
    obj.dataLink31:setName("dataLink31");

    obj.layout84 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout84:setParent(obj.layout73);
    obj.layout84:setAlign("top");
    obj.layout84:setHeight(25);
    obj.layout84:setMargins({top=5,left=5,right=5});
    obj.layout84:setName("layout84");

    obj.label128 = GUI.fromHandle(_obj_newObject("label"));
    obj.label128:setParent(obj.layout84);
    obj.label128:setText("Metamagia");
    obj.label128:setAlign("client");
    obj.label128:setName("label128");
    obj.label128:setFontColor("white");

    obj.edit78 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit78:setParent(obj.layout84);
    obj.edit78:setField("metamagia");
    obj.edit78:setAlign("right");
    obj.edit78:setWidth(30);
    obj.edit78:setHorzTextAlign("center");
    obj.edit78:setName("edit78");
    obj.edit78:setFontSize(15);
    obj.edit78:setFontColor("white");

    obj.layout85 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout85:setParent(obj.layout84);
    obj.layout85:setAlign("right");
    obj.layout85:setWidth(90);
    obj.layout85:setName("layout85");

    obj.rectangle69 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle69:setParent(obj.layout85);
    obj.rectangle69:setAlign("right");
    obj.rectangle69:setWidth(30);
    obj.rectangle69:setColor("#272C36");
    obj.rectangle69:setStrokeColor("#8A6C30");
    obj.rectangle69:setStrokeSize(1);
    obj.rectangle69:setHint("Entender");
    obj.rectangle69:setName("rectangle69");

    obj.label129 = GUI.fromHandle(_obj_newObject("label"));
    obj.label129:setParent(obj.rectangle69);
    obj.label129:setField("metamagiaEntender");
    obj.label129:setAlign("client");
    obj.label129:setHorzTextAlign("center");
    obj.label129:setName("label129");
    obj.label129:setFontColor("white");

    obj.rectangle70 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle70:setParent(obj.layout85);
    obj.rectangle70:setAlign("right");
    obj.rectangle70:setWidth(30);
    obj.rectangle70:setColor("#272C36");
    obj.rectangle70:setStrokeColor("#8A6C30");
    obj.rectangle70:setStrokeSize(1);
    obj.rectangle70:setHint("Controlar");
    obj.rectangle70:setName("rectangle70");

    obj.label130 = GUI.fromHandle(_obj_newObject("label"));
    obj.label130:setParent(obj.rectangle70);
    obj.label130:setField("metamagiaControlar");
    obj.label130:setAlign("client");
    obj.label130:setHorzTextAlign("center");
    obj.label130:setName("label130");
    obj.label130:setFontColor("white");

    obj.rectangle71 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle71:setParent(obj.layout85);
    obj.rectangle71:setAlign("right");
    obj.rectangle71:setWidth(30);
    obj.rectangle71:setColor("#272C36");
    obj.rectangle71:setStrokeColor("#8A6C30");
    obj.rectangle71:setStrokeSize(1);
    obj.rectangle71:setHint("Criar");
    obj.rectangle71:setName("rectangle71");

    obj.label131 = GUI.fromHandle(_obj_newObject("label"));
    obj.label131:setParent(obj.rectangle71);
    obj.label131:setField("metamagiaCriar");
    obj.label131:setAlign("client");
    obj.label131:setHorzTextAlign("center");
    obj.label131:setName("label131");
    obj.label131:setFontColor("white");

    obj.dataLink32 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink32:setParent(obj.layout84);
    obj.dataLink32:setFields({'metamagia','entender','controlar','criar'});
    obj.dataLink32:setName("dataLink32");

    obj.dataLink33 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink33:setParent(obj.rectangle34);
    obj.dataLink33:setFields({'entender','controlar','criar','ar','terra','agua','fogo','luz','trevas','arkanum','spiritum','humanos','plantas','animais','metamagia'});
    obj.dataLink33:setName("dataLink33");

    obj.rectangle72 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle72:setParent(obj.flowLayout2);
    obj.rectangle72:setWidth(585);
    obj.rectangle72:setHeight(220);
    obj.rectangle72:setColor("#272C36");
    obj.rectangle72:setStrokeColor("#8A6C30");
    obj.rectangle72:setStrokeSize(1);
    obj.rectangle72:setMargins({left=5});
    obj.rectangle72:setName("rectangle72");

    obj.label132 = GUI.fromHandle(_obj_newObject("label"));
    obj.label132:setParent(obj.rectangle72);
    obj.label132:setAlign("top");
    obj.label132:setHeight(25);
    obj.label132:setText("CAMINHOS SECUNDÁRIOS");
    obj.label132:setMargins({top=5,left=5,right=5,bottom=5});
    obj.label132:setName("label132");
    obj.label132:setFontColor("white");

    obj.layout86 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout86:setParent(obj.rectangle72);
    obj.layout86:setAlign("left");
    obj.layout86:setWidth(290);
    obj.layout86:setMargins({right=0});
    obj.layout86:setName("layout86");

    obj.layout87 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout87:setParent(obj.layout86);
    obj.layout87:setAlign("top");
    obj.layout87:setHeight(25);
    obj.layout87:setMargins({top=5,left=5,right=5});
    obj.layout87:setName("layout87");

    obj.label133 = GUI.fromHandle(_obj_newObject("label"));
    obj.label133:setParent(obj.layout87);
    obj.label133:setText("Magma");
    obj.label133:setAlign("client");
    obj.label133:setName("label133");
    obj.label133:setFontColor("white");

    obj.rectangle73 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle73:setParent(obj.layout87);
    obj.rectangle73:setAlign("right");
    obj.rectangle73:setWidth(50);
    obj.rectangle73:setColor("#272C36");
    obj.rectangle73:setStrokeColor("#8A6C30");
    obj.rectangle73:setStrokeSize(1);
    obj.rectangle73:setName("rectangle73");

    obj.label134 = GUI.fromHandle(_obj_newObject("label"));
    obj.label134:setParent(obj.rectangle73);
    obj.label134:setField("magma");
    obj.label134:setAlign("client");
    obj.label134:setHorzTextAlign("center");
    obj.label134:setName("label134");
    obj.label134:setFontColor("white");

    obj.layout88 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout88:setParent(obj.layout87);
    obj.layout88:setAlign("right");
    obj.layout88:setWidth(90);
    obj.layout88:setName("layout88");

    obj.rectangle74 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle74:setParent(obj.layout88);
    obj.rectangle74:setAlign("right");
    obj.rectangle74:setWidth(30);
    obj.rectangle74:setColor("#272C36");
    obj.rectangle74:setStrokeColor("#8A6C30");
    obj.rectangle74:setStrokeSize(1);
    obj.rectangle74:setHint("Entender");
    obj.rectangle74:setName("rectangle74");

    obj.label135 = GUI.fromHandle(_obj_newObject("label"));
    obj.label135:setParent(obj.rectangle74);
    obj.label135:setField("magmaEntender");
    obj.label135:setAlign("client");
    obj.label135:setHorzTextAlign("center");
    obj.label135:setName("label135");
    obj.label135:setFontColor("white");

    obj.rectangle75 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle75:setParent(obj.layout88);
    obj.rectangle75:setAlign("right");
    obj.rectangle75:setWidth(30);
    obj.rectangle75:setColor("#272C36");
    obj.rectangle75:setStrokeColor("#8A6C30");
    obj.rectangle75:setStrokeSize(1);
    obj.rectangle75:setHint("Controlar");
    obj.rectangle75:setName("rectangle75");

    obj.label136 = GUI.fromHandle(_obj_newObject("label"));
    obj.label136:setParent(obj.rectangle75);
    obj.label136:setField("magmaControlar");
    obj.label136:setAlign("client");
    obj.label136:setHorzTextAlign("center");
    obj.label136:setName("label136");
    obj.label136:setFontColor("white");

    obj.rectangle76 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle76:setParent(obj.layout88);
    obj.rectangle76:setAlign("right");
    obj.rectangle76:setWidth(30);
    obj.rectangle76:setColor("#272C36");
    obj.rectangle76:setStrokeColor("#8A6C30");
    obj.rectangle76:setStrokeSize(1);
    obj.rectangle76:setHint("Criar");
    obj.rectangle76:setName("rectangle76");

    obj.label137 = GUI.fromHandle(_obj_newObject("label"));
    obj.label137:setParent(obj.rectangle76);
    obj.label137:setField("magmaCriar");
    obj.label137:setAlign("client");
    obj.label137:setHorzTextAlign("center");
    obj.label137:setName("label137");
    obj.label137:setFontColor("white");

    obj.dataLink34 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink34:setParent(obj.layout87);
    obj.dataLink34:setFields({'magma','entender','controlar','criar'});
    obj.dataLink34:setName("dataLink34");

    obj.layout89 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout89:setParent(obj.layout86);
    obj.layout89:setAlign("top");
    obj.layout89:setHeight(25);
    obj.layout89:setMargins({top=5,left=5,right=5});
    obj.layout89:setName("layout89");

    obj.label138 = GUI.fromHandle(_obj_newObject("label"));
    obj.label138:setParent(obj.layout89);
    obj.label138:setText("Fogo Negro e Cinzas");
    obj.label138:setAlign("client");
    obj.label138:setName("label138");
    obj.label138:setFontColor("white");

    obj.rectangle77 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle77:setParent(obj.layout89);
    obj.rectangle77:setAlign("right");
    obj.rectangle77:setWidth(50);
    obj.rectangle77:setColor("#272C36");
    obj.rectangle77:setStrokeColor("#8A6C30");
    obj.rectangle77:setStrokeSize(1);
    obj.rectangle77:setName("rectangle77");

    obj.label139 = GUI.fromHandle(_obj_newObject("label"));
    obj.label139:setParent(obj.rectangle77);
    obj.label139:setField("cinzas");
    obj.label139:setAlign("client");
    obj.label139:setHorzTextAlign("center");
    obj.label139:setName("label139");
    obj.label139:setFontColor("white");

    obj.layout90 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout90:setParent(obj.layout89);
    obj.layout90:setAlign("right");
    obj.layout90:setWidth(90);
    obj.layout90:setName("layout90");

    obj.rectangle78 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle78:setParent(obj.layout90);
    obj.rectangle78:setAlign("right");
    obj.rectangle78:setWidth(30);
    obj.rectangle78:setColor("#272C36");
    obj.rectangle78:setStrokeColor("#8A6C30");
    obj.rectangle78:setStrokeSize(1);
    obj.rectangle78:setHint("Entender");
    obj.rectangle78:setName("rectangle78");

    obj.label140 = GUI.fromHandle(_obj_newObject("label"));
    obj.label140:setParent(obj.rectangle78);
    obj.label140:setField("cinzasEntender");
    obj.label140:setAlign("client");
    obj.label140:setHorzTextAlign("center");
    obj.label140:setName("label140");
    obj.label140:setFontColor("white");

    obj.rectangle79 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle79:setParent(obj.layout90);
    obj.rectangle79:setAlign("right");
    obj.rectangle79:setWidth(30);
    obj.rectangle79:setColor("#272C36");
    obj.rectangle79:setStrokeColor("#8A6C30");
    obj.rectangle79:setStrokeSize(1);
    obj.rectangle79:setHint("Controlar");
    obj.rectangle79:setName("rectangle79");

    obj.label141 = GUI.fromHandle(_obj_newObject("label"));
    obj.label141:setParent(obj.rectangle79);
    obj.label141:setField("cinzasControlar");
    obj.label141:setAlign("client");
    obj.label141:setHorzTextAlign("center");
    obj.label141:setName("label141");
    obj.label141:setFontColor("white");

    obj.rectangle80 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle80:setParent(obj.layout90);
    obj.rectangle80:setAlign("right");
    obj.rectangle80:setWidth(30);
    obj.rectangle80:setColor("#272C36");
    obj.rectangle80:setStrokeColor("#8A6C30");
    obj.rectangle80:setStrokeSize(1);
    obj.rectangle80:setHint("Criar");
    obj.rectangle80:setName("rectangle80");

    obj.label142 = GUI.fromHandle(_obj_newObject("label"));
    obj.label142:setParent(obj.rectangle80);
    obj.label142:setField("cinzasCriar");
    obj.label142:setAlign("client");
    obj.label142:setHorzTextAlign("center");
    obj.label142:setName("label142");
    obj.label142:setFontColor("white");

    obj.dataLink35 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink35:setParent(obj.layout89);
    obj.dataLink35:setFields({'cinzas','entender','controlar','criar'});
    obj.dataLink35:setName("dataLink35");

    obj.layout91 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout91:setParent(obj.layout86);
    obj.layout91:setAlign("top");
    obj.layout91:setHeight(25);
    obj.layout91:setMargins({top=5,left=5,right=5});
    obj.layout91:setName("layout91");

    obj.label143 = GUI.fromHandle(_obj_newObject("label"));
    obj.label143:setParent(obj.layout91);
    obj.label143:setText("Cores e Brilhos");
    obj.label143:setAlign("client");
    obj.label143:setName("label143");
    obj.label143:setFontColor("white");

    obj.rectangle81 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle81:setParent(obj.layout91);
    obj.rectangle81:setAlign("right");
    obj.rectangle81:setWidth(50);
    obj.rectangle81:setColor("#272C36");
    obj.rectangle81:setStrokeColor("#8A6C30");
    obj.rectangle81:setStrokeSize(1);
    obj.rectangle81:setName("rectangle81");

    obj.label144 = GUI.fromHandle(_obj_newObject("label"));
    obj.label144:setParent(obj.rectangle81);
    obj.label144:setField("cores");
    obj.label144:setAlign("client");
    obj.label144:setHorzTextAlign("center");
    obj.label144:setName("label144");
    obj.label144:setFontColor("white");

    obj.layout92 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout92:setParent(obj.layout91);
    obj.layout92:setAlign("right");
    obj.layout92:setWidth(90);
    obj.layout92:setName("layout92");

    obj.rectangle82 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle82:setParent(obj.layout92);
    obj.rectangle82:setAlign("right");
    obj.rectangle82:setWidth(30);
    obj.rectangle82:setColor("#272C36");
    obj.rectangle82:setStrokeColor("#8A6C30");
    obj.rectangle82:setStrokeSize(1);
    obj.rectangle82:setHint("Entender");
    obj.rectangle82:setName("rectangle82");

    obj.label145 = GUI.fromHandle(_obj_newObject("label"));
    obj.label145:setParent(obj.rectangle82);
    obj.label145:setField("coresEntender");
    obj.label145:setAlign("client");
    obj.label145:setHorzTextAlign("center");
    obj.label145:setName("label145");
    obj.label145:setFontColor("white");

    obj.rectangle83 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle83:setParent(obj.layout92);
    obj.rectangle83:setAlign("right");
    obj.rectangle83:setWidth(30);
    obj.rectangle83:setColor("#272C36");
    obj.rectangle83:setStrokeColor("#8A6C30");
    obj.rectangle83:setStrokeSize(1);
    obj.rectangle83:setHint("Controlar");
    obj.rectangle83:setName("rectangle83");

    obj.label146 = GUI.fromHandle(_obj_newObject("label"));
    obj.label146:setParent(obj.rectangle83);
    obj.label146:setField("coresControlar");
    obj.label146:setAlign("client");
    obj.label146:setHorzTextAlign("center");
    obj.label146:setName("label146");
    obj.label146:setFontColor("white");

    obj.rectangle84 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle84:setParent(obj.layout92);
    obj.rectangle84:setAlign("right");
    obj.rectangle84:setWidth(30);
    obj.rectangle84:setColor("#272C36");
    obj.rectangle84:setStrokeColor("#8A6C30");
    obj.rectangle84:setStrokeSize(1);
    obj.rectangle84:setHint("Criar");
    obj.rectangle84:setName("rectangle84");

    obj.label147 = GUI.fromHandle(_obj_newObject("label"));
    obj.label147:setParent(obj.rectangle84);
    obj.label147:setField("coresCriar");
    obj.label147:setAlign("client");
    obj.label147:setHorzTextAlign("center");
    obj.label147:setName("label147");
    obj.label147:setFontColor("white");

    obj.dataLink36 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink36:setParent(obj.layout91);
    obj.dataLink36:setFields({'cores','entender','controlar','criar'});
    obj.dataLink36:setName("dataLink36");

    obj.layout93 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout93:setParent(obj.layout86);
    obj.layout93:setAlign("top");
    obj.layout93:setHeight(25);
    obj.layout93:setMargins({top=5,left=5,right=5});
    obj.layout93:setName("layout93");

    obj.label148 = GUI.fromHandle(_obj_newObject("label"));
    obj.label148:setParent(obj.layout93);
    obj.label148:setText("Fumaça");
    obj.label148:setAlign("client");
    obj.label148:setName("label148");
    obj.label148:setFontColor("white");

    obj.rectangle85 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle85:setParent(obj.layout93);
    obj.rectangle85:setAlign("right");
    obj.rectangle85:setWidth(50);
    obj.rectangle85:setColor("#272C36");
    obj.rectangle85:setStrokeColor("#8A6C30");
    obj.rectangle85:setStrokeSize(1);
    obj.rectangle85:setName("rectangle85");

    obj.label149 = GUI.fromHandle(_obj_newObject("label"));
    obj.label149:setParent(obj.rectangle85);
    obj.label149:setField("fumaca");
    obj.label149:setAlign("client");
    obj.label149:setHorzTextAlign("center");
    obj.label149:setName("label149");
    obj.label149:setFontColor("white");

    obj.layout94 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout94:setParent(obj.layout93);
    obj.layout94:setAlign("right");
    obj.layout94:setWidth(90);
    obj.layout94:setName("layout94");

    obj.rectangle86 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle86:setParent(obj.layout94);
    obj.rectangle86:setAlign("right");
    obj.rectangle86:setWidth(30);
    obj.rectangle86:setColor("#272C36");
    obj.rectangle86:setStrokeColor("#8A6C30");
    obj.rectangle86:setStrokeSize(1);
    obj.rectangle86:setHint("Entender");
    obj.rectangle86:setName("rectangle86");

    obj.label150 = GUI.fromHandle(_obj_newObject("label"));
    obj.label150:setParent(obj.rectangle86);
    obj.label150:setField("fumacaEntender");
    obj.label150:setAlign("client");
    obj.label150:setHorzTextAlign("center");
    obj.label150:setName("label150");
    obj.label150:setFontColor("white");

    obj.rectangle87 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle87:setParent(obj.layout94);
    obj.rectangle87:setAlign("right");
    obj.rectangle87:setWidth(30);
    obj.rectangle87:setColor("#272C36");
    obj.rectangle87:setStrokeColor("#8A6C30");
    obj.rectangle87:setStrokeSize(1);
    obj.rectangle87:setHint("Controlar");
    obj.rectangle87:setName("rectangle87");

    obj.label151 = GUI.fromHandle(_obj_newObject("label"));
    obj.label151:setParent(obj.rectangle87);
    obj.label151:setField("fumacaControlar");
    obj.label151:setAlign("client");
    obj.label151:setHorzTextAlign("center");
    obj.label151:setName("label151");
    obj.label151:setFontColor("white");

    obj.rectangle88 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle88:setParent(obj.layout94);
    obj.rectangle88:setAlign("right");
    obj.rectangle88:setWidth(30);
    obj.rectangle88:setColor("#272C36");
    obj.rectangle88:setStrokeColor("#8A6C30");
    obj.rectangle88:setStrokeSize(1);
    obj.rectangle88:setHint("Criar");
    obj.rectangle88:setName("rectangle88");

    obj.label152 = GUI.fromHandle(_obj_newObject("label"));
    obj.label152:setParent(obj.rectangle88);
    obj.label152:setField("fumacaCriar");
    obj.label152:setAlign("client");
    obj.label152:setHorzTextAlign("center");
    obj.label152:setName("label152");
    obj.label152:setFontColor("white");

    obj.dataLink37 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink37:setParent(obj.layout93);
    obj.dataLink37:setFields({'fumaca','entender','controlar','criar'});
    obj.dataLink37:setName("dataLink37");

    obj.layout95 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout95:setParent(obj.layout86);
    obj.layout95:setAlign("top");
    obj.layout95:setHeight(25);
    obj.layout95:setMargins({top=5,left=5,right=5});
    obj.layout95:setName("layout95");

    obj.label153 = GUI.fromHandle(_obj_newObject("label"));
    obj.label153:setParent(obj.layout95);
    obj.label153:setText("Relâmpagos");
    obj.label153:setAlign("client");
    obj.label153:setName("label153");
    obj.label153:setFontColor("white");

    obj.rectangle89 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle89:setParent(obj.layout95);
    obj.rectangle89:setAlign("right");
    obj.rectangle89:setWidth(50);
    obj.rectangle89:setColor("#272C36");
    obj.rectangle89:setStrokeColor("#8A6C30");
    obj.rectangle89:setStrokeSize(1);
    obj.rectangle89:setName("rectangle89");

    obj.label154 = GUI.fromHandle(_obj_newObject("label"));
    obj.label154:setParent(obj.rectangle89);
    obj.label154:setField("relampagos");
    obj.label154:setAlign("client");
    obj.label154:setHorzTextAlign("center");
    obj.label154:setName("label154");
    obj.label154:setFontColor("white");

    obj.layout96 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout96:setParent(obj.layout95);
    obj.layout96:setAlign("right");
    obj.layout96:setWidth(90);
    obj.layout96:setName("layout96");

    obj.rectangle90 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle90:setParent(obj.layout96);
    obj.rectangle90:setAlign("right");
    obj.rectangle90:setWidth(30);
    obj.rectangle90:setColor("#272C36");
    obj.rectangle90:setStrokeColor("#8A6C30");
    obj.rectangle90:setStrokeSize(1);
    obj.rectangle90:setHint("Entender");
    obj.rectangle90:setName("rectangle90");

    obj.label155 = GUI.fromHandle(_obj_newObject("label"));
    obj.label155:setParent(obj.rectangle90);
    obj.label155:setField("relampagosEntender");
    obj.label155:setAlign("client");
    obj.label155:setHorzTextAlign("center");
    obj.label155:setName("label155");
    obj.label155:setFontColor("white");

    obj.rectangle91 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle91:setParent(obj.layout96);
    obj.rectangle91:setAlign("right");
    obj.rectangle91:setWidth(30);
    obj.rectangle91:setColor("#272C36");
    obj.rectangle91:setStrokeColor("#8A6C30");
    obj.rectangle91:setStrokeSize(1);
    obj.rectangle91:setHint("Controlar");
    obj.rectangle91:setName("rectangle91");

    obj.label156 = GUI.fromHandle(_obj_newObject("label"));
    obj.label156:setParent(obj.rectangle91);
    obj.label156:setField("relampagosControlar");
    obj.label156:setAlign("client");
    obj.label156:setHorzTextAlign("center");
    obj.label156:setName("label156");
    obj.label156:setFontColor("white");

    obj.rectangle92 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle92:setParent(obj.layout96);
    obj.rectangle92:setAlign("right");
    obj.rectangle92:setWidth(30);
    obj.rectangle92:setColor("#272C36");
    obj.rectangle92:setStrokeColor("#8A6C30");
    obj.rectangle92:setStrokeSize(1);
    obj.rectangle92:setHint("Criar");
    obj.rectangle92:setName("rectangle92");

    obj.label157 = GUI.fromHandle(_obj_newObject("label"));
    obj.label157:setParent(obj.rectangle92);
    obj.label157:setField("relampagosCriar");
    obj.label157:setAlign("client");
    obj.label157:setHorzTextAlign("center");
    obj.label157:setName("label157");
    obj.label157:setFontColor("white");

    obj.dataLink38 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink38:setParent(obj.layout95);
    obj.dataLink38:setFields({'relampagos','entender','controlar','criar'});
    obj.dataLink38:setName("dataLink38");

    obj.layout97 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout97:setParent(obj.layout86);
    obj.layout97:setAlign("top");
    obj.layout97:setHeight(25);
    obj.layout97:setMargins({top=5,left=5,right=5});
    obj.layout97:setName("layout97");

    obj.label158 = GUI.fromHandle(_obj_newObject("label"));
    obj.label158:setParent(obj.layout97);
    obj.label158:setText("Gelo");
    obj.label158:setAlign("client");
    obj.label158:setName("label158");
    obj.label158:setFontColor("white");

    obj.rectangle93 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle93:setParent(obj.layout97);
    obj.rectangle93:setAlign("right");
    obj.rectangle93:setWidth(50);
    obj.rectangle93:setColor("#272C36");
    obj.rectangle93:setStrokeColor("#8A6C30");
    obj.rectangle93:setStrokeSize(1);
    obj.rectangle93:setName("rectangle93");

    obj.label159 = GUI.fromHandle(_obj_newObject("label"));
    obj.label159:setParent(obj.rectangle93);
    obj.label159:setField("gelo");
    obj.label159:setAlign("client");
    obj.label159:setHorzTextAlign("center");
    obj.label159:setName("label159");
    obj.label159:setFontColor("white");

    obj.layout98 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout98:setParent(obj.layout97);
    obj.layout98:setAlign("right");
    obj.layout98:setWidth(90);
    obj.layout98:setName("layout98");

    obj.rectangle94 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle94:setParent(obj.layout98);
    obj.rectangle94:setAlign("right");
    obj.rectangle94:setWidth(30);
    obj.rectangle94:setColor("#272C36");
    obj.rectangle94:setStrokeColor("#8A6C30");
    obj.rectangle94:setStrokeSize(1);
    obj.rectangle94:setHint("Entender");
    obj.rectangle94:setName("rectangle94");

    obj.label160 = GUI.fromHandle(_obj_newObject("label"));
    obj.label160:setParent(obj.rectangle94);
    obj.label160:setField("geloEntender");
    obj.label160:setAlign("client");
    obj.label160:setHorzTextAlign("center");
    obj.label160:setName("label160");
    obj.label160:setFontColor("white");

    obj.rectangle95 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle95:setParent(obj.layout98);
    obj.rectangle95:setAlign("right");
    obj.rectangle95:setWidth(30);
    obj.rectangle95:setColor("#272C36");
    obj.rectangle95:setStrokeColor("#8A6C30");
    obj.rectangle95:setStrokeSize(1);
    obj.rectangle95:setHint("Controlar");
    obj.rectangle95:setName("rectangle95");

    obj.label161 = GUI.fromHandle(_obj_newObject("label"));
    obj.label161:setParent(obj.rectangle95);
    obj.label161:setField("geloControlar");
    obj.label161:setAlign("client");
    obj.label161:setHorzTextAlign("center");
    obj.label161:setName("label161");
    obj.label161:setFontColor("white");

    obj.rectangle96 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle96:setParent(obj.layout98);
    obj.rectangle96:setAlign("right");
    obj.rectangle96:setWidth(30);
    obj.rectangle96:setColor("#272C36");
    obj.rectangle96:setStrokeColor("#8A6C30");
    obj.rectangle96:setStrokeSize(1);
    obj.rectangle96:setHint("Criar");
    obj.rectangle96:setName("rectangle96");

    obj.label162 = GUI.fromHandle(_obj_newObject("label"));
    obj.label162:setParent(obj.rectangle96);
    obj.label162:setField("geloCriar");
    obj.label162:setAlign("client");
    obj.label162:setHorzTextAlign("center");
    obj.label162:setName("label162");
    obj.label162:setFontColor("white");

    obj.dataLink39 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink39:setParent(obj.layout97);
    obj.dataLink39:setFields({'gelo','entender','controlar','criar'});
    obj.dataLink39:setName("dataLink39");

    obj.layout99 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout99:setParent(obj.rectangle72);
    obj.layout99:setAlign("left");
    obj.layout99:setWidth(290);
    obj.layout99:setMargins({right=0});
    obj.layout99:setName("layout99");

    obj.layout100 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout100:setParent(obj.layout99);
    obj.layout100:setAlign("top");
    obj.layout100:setHeight(25);
    obj.layout100:setMargins({top=5,left=5,right=5});
    obj.layout100:setName("layout100");

    obj.label163 = GUI.fromHandle(_obj_newObject("label"));
    obj.label163:setParent(obj.layout100);
    obj.label163:setText("Vapores e Poções");
    obj.label163:setAlign("client");
    obj.label163:setName("label163");
    obj.label163:setFontColor("white");

    obj.rectangle97 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle97:setParent(obj.layout100);
    obj.rectangle97:setAlign("right");
    obj.rectangle97:setWidth(50);
    obj.rectangle97:setColor("#272C36");
    obj.rectangle97:setStrokeColor("#8A6C30");
    obj.rectangle97:setStrokeSize(1);
    obj.rectangle97:setName("rectangle97");

    obj.label164 = GUI.fromHandle(_obj_newObject("label"));
    obj.label164:setParent(obj.rectangle97);
    obj.label164:setField("vapores");
    obj.label164:setAlign("client");
    obj.label164:setHorzTextAlign("center");
    obj.label164:setName("label164");
    obj.label164:setFontColor("white");

    obj.layout101 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout101:setParent(obj.layout100);
    obj.layout101:setAlign("right");
    obj.layout101:setWidth(90);
    obj.layout101:setName("layout101");

    obj.rectangle98 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle98:setParent(obj.layout101);
    obj.rectangle98:setAlign("right");
    obj.rectangle98:setWidth(30);
    obj.rectangle98:setColor("#272C36");
    obj.rectangle98:setStrokeColor("#8A6C30");
    obj.rectangle98:setStrokeSize(1);
    obj.rectangle98:setHint("Entender");
    obj.rectangle98:setName("rectangle98");

    obj.label165 = GUI.fromHandle(_obj_newObject("label"));
    obj.label165:setParent(obj.rectangle98);
    obj.label165:setField("vaporesEntender");
    obj.label165:setAlign("client");
    obj.label165:setHorzTextAlign("center");
    obj.label165:setName("label165");
    obj.label165:setFontColor("white");

    obj.rectangle99 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle99:setParent(obj.layout101);
    obj.rectangle99:setAlign("right");
    obj.rectangle99:setWidth(30);
    obj.rectangle99:setColor("#272C36");
    obj.rectangle99:setStrokeColor("#8A6C30");
    obj.rectangle99:setStrokeSize(1);
    obj.rectangle99:setHint("Controlar");
    obj.rectangle99:setName("rectangle99");

    obj.label166 = GUI.fromHandle(_obj_newObject("label"));
    obj.label166:setParent(obj.rectangle99);
    obj.label166:setField("vaporesControlar");
    obj.label166:setAlign("client");
    obj.label166:setHorzTextAlign("center");
    obj.label166:setName("label166");
    obj.label166:setFontColor("white");

    obj.rectangle100 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle100:setParent(obj.layout101);
    obj.rectangle100:setAlign("right");
    obj.rectangle100:setWidth(30);
    obj.rectangle100:setColor("#272C36");
    obj.rectangle100:setStrokeColor("#8A6C30");
    obj.rectangle100:setStrokeSize(1);
    obj.rectangle100:setHint("Criar");
    obj.rectangle100:setName("rectangle100");

    obj.label167 = GUI.fromHandle(_obj_newObject("label"));
    obj.label167:setParent(obj.rectangle100);
    obj.label167:setField("vaporesCriar");
    obj.label167:setAlign("client");
    obj.label167:setHorzTextAlign("center");
    obj.label167:setName("label167");
    obj.label167:setFontColor("white");

    obj.dataLink40 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink40:setParent(obj.layout100);
    obj.dataLink40:setFields({'vapores','entender','controlar','criar'});
    obj.dataLink40:setName("dataLink40");

    obj.layout102 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout102:setParent(obj.layout99);
    obj.layout102:setAlign("top");
    obj.layout102:setHeight(25);
    obj.layout102:setMargins({top=5,left=5,right=5});
    obj.layout102:setName("layout102");

    obj.label168 = GUI.fromHandle(_obj_newObject("label"));
    obj.label168:setParent(obj.layout102);
    obj.label168:setText("Cristais");
    obj.label168:setAlign("client");
    obj.label168:setName("label168");
    obj.label168:setFontColor("white");

    obj.rectangle101 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle101:setParent(obj.layout102);
    obj.rectangle101:setAlign("right");
    obj.rectangle101:setWidth(50);
    obj.rectangle101:setColor("#272C36");
    obj.rectangle101:setStrokeColor("#8A6C30");
    obj.rectangle101:setStrokeSize(1);
    obj.rectangle101:setName("rectangle101");

    obj.label169 = GUI.fromHandle(_obj_newObject("label"));
    obj.label169:setParent(obj.rectangle101);
    obj.label169:setField("cristais");
    obj.label169:setAlign("client");
    obj.label169:setHorzTextAlign("center");
    obj.label169:setName("label169");
    obj.label169:setFontColor("white");

    obj.layout103 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout103:setParent(obj.layout102);
    obj.layout103:setAlign("right");
    obj.layout103:setWidth(90);
    obj.layout103:setName("layout103");

    obj.rectangle102 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle102:setParent(obj.layout103);
    obj.rectangle102:setAlign("right");
    obj.rectangle102:setWidth(30);
    obj.rectangle102:setColor("#272C36");
    obj.rectangle102:setStrokeColor("#8A6C30");
    obj.rectangle102:setStrokeSize(1);
    obj.rectangle102:setHint("Entender");
    obj.rectangle102:setName("rectangle102");

    obj.label170 = GUI.fromHandle(_obj_newObject("label"));
    obj.label170:setParent(obj.rectangle102);
    obj.label170:setField("cristaisEntender");
    obj.label170:setAlign("client");
    obj.label170:setHorzTextAlign("center");
    obj.label170:setName("label170");
    obj.label170:setFontColor("white");

    obj.rectangle103 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle103:setParent(obj.layout103);
    obj.rectangle103:setAlign("right");
    obj.rectangle103:setWidth(30);
    obj.rectangle103:setColor("#272C36");
    obj.rectangle103:setStrokeColor("#8A6C30");
    obj.rectangle103:setStrokeSize(1);
    obj.rectangle103:setHint("Controlar");
    obj.rectangle103:setName("rectangle103");

    obj.label171 = GUI.fromHandle(_obj_newObject("label"));
    obj.label171:setParent(obj.rectangle103);
    obj.label171:setField("cristaisControlar");
    obj.label171:setAlign("client");
    obj.label171:setHorzTextAlign("center");
    obj.label171:setName("label171");
    obj.label171:setFontColor("white");

    obj.rectangle104 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle104:setParent(obj.layout103);
    obj.rectangle104:setAlign("right");
    obj.rectangle104:setWidth(30);
    obj.rectangle104:setColor("#272C36");
    obj.rectangle104:setStrokeColor("#8A6C30");
    obj.rectangle104:setStrokeSize(1);
    obj.rectangle104:setHint("Criar");
    obj.rectangle104:setName("rectangle104");

    obj.label172 = GUI.fromHandle(_obj_newObject("label"));
    obj.label172:setParent(obj.rectangle104);
    obj.label172:setField("cristaisCriar");
    obj.label172:setAlign("client");
    obj.label172:setHorzTextAlign("center");
    obj.label172:setName("label172");
    obj.label172:setFontColor("white");

    obj.dataLink41 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink41:setParent(obj.layout102);
    obj.dataLink41:setFields({'cristais','entender','controlar','criar'});
    obj.dataLink41:setName("dataLink41");

    obj.layout104 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout104:setParent(obj.layout99);
    obj.layout104:setAlign("top");
    obj.layout104:setHeight(25);
    obj.layout104:setMargins({top=5,left=5,right=5});
    obj.layout104:setName("layout104");

    obj.label173 = GUI.fromHandle(_obj_newObject("label"));
    obj.label173:setParent(obj.layout104);
    obj.label173:setText("Lama");
    obj.label173:setAlign("client");
    obj.label173:setName("label173");
    obj.label173:setFontColor("white");

    obj.rectangle105 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle105:setParent(obj.layout104);
    obj.rectangle105:setAlign("right");
    obj.rectangle105:setWidth(50);
    obj.rectangle105:setColor("#272C36");
    obj.rectangle105:setStrokeColor("#8A6C30");
    obj.rectangle105:setStrokeSize(1);
    obj.rectangle105:setName("rectangle105");

    obj.label174 = GUI.fromHandle(_obj_newObject("label"));
    obj.label174:setParent(obj.rectangle105);
    obj.label174:setField("lama");
    obj.label174:setAlign("client");
    obj.label174:setHorzTextAlign("center");
    obj.label174:setName("label174");
    obj.label174:setFontColor("white");

    obj.layout105 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout105:setParent(obj.layout104);
    obj.layout105:setAlign("right");
    obj.layout105:setWidth(90);
    obj.layout105:setName("layout105");

    obj.rectangle106 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle106:setParent(obj.layout105);
    obj.rectangle106:setAlign("right");
    obj.rectangle106:setWidth(30);
    obj.rectangle106:setColor("#272C36");
    obj.rectangle106:setStrokeColor("#8A6C30");
    obj.rectangle106:setStrokeSize(1);
    obj.rectangle106:setHint("Entender");
    obj.rectangle106:setName("rectangle106");

    obj.label175 = GUI.fromHandle(_obj_newObject("label"));
    obj.label175:setParent(obj.rectangle106);
    obj.label175:setField("lamaEntender");
    obj.label175:setAlign("client");
    obj.label175:setHorzTextAlign("center");
    obj.label175:setName("label175");
    obj.label175:setFontColor("white");

    obj.rectangle107 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle107:setParent(obj.layout105);
    obj.rectangle107:setAlign("right");
    obj.rectangle107:setWidth(30);
    obj.rectangle107:setColor("#272C36");
    obj.rectangle107:setStrokeColor("#8A6C30");
    obj.rectangle107:setStrokeSize(1);
    obj.rectangle107:setHint("Controlar");
    obj.rectangle107:setName("rectangle107");

    obj.label176 = GUI.fromHandle(_obj_newObject("label"));
    obj.label176:setParent(obj.rectangle107);
    obj.label176:setField("lamaControlar");
    obj.label176:setAlign("client");
    obj.label176:setHorzTextAlign("center");
    obj.label176:setName("label176");
    obj.label176:setFontColor("white");

    obj.rectangle108 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle108:setParent(obj.layout105);
    obj.rectangle108:setAlign("right");
    obj.rectangle108:setWidth(30);
    obj.rectangle108:setColor("#272C36");
    obj.rectangle108:setStrokeColor("#8A6C30");
    obj.rectangle108:setStrokeSize(1);
    obj.rectangle108:setHint("Criar");
    obj.rectangle108:setName("rectangle108");

    obj.label177 = GUI.fromHandle(_obj_newObject("label"));
    obj.label177:setParent(obj.rectangle108);
    obj.label177:setField("lamaCriar");
    obj.label177:setAlign("client");
    obj.label177:setHorzTextAlign("center");
    obj.label177:setName("label177");
    obj.label177:setFontColor("white");

    obj.dataLink42 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink42:setParent(obj.layout104);
    obj.dataLink42:setFields({'lama','entender','controlar','criar'});
    obj.dataLink42:setName("dataLink42");

    obj.layout106 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout106:setParent(obj.layout99);
    obj.layout106:setAlign("top");
    obj.layout106:setHeight(25);
    obj.layout106:setMargins({top=5,left=5,right=5});
    obj.layout106:setName("layout106");

    obj.label178 = GUI.fromHandle(_obj_newObject("label"));
    obj.label178:setParent(obj.layout106);
    obj.label178:setText("Pó e Corrosão");
    obj.label178:setAlign("client");
    obj.label178:setName("label178");
    obj.label178:setFontColor("white");

    obj.rectangle109 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle109:setParent(obj.layout106);
    obj.rectangle109:setAlign("right");
    obj.rectangle109:setWidth(50);
    obj.rectangle109:setColor("#272C36");
    obj.rectangle109:setStrokeColor("#8A6C30");
    obj.rectangle109:setStrokeSize(1);
    obj.rectangle109:setName("rectangle109");

    obj.label179 = GUI.fromHandle(_obj_newObject("label"));
    obj.label179:setParent(obj.rectangle109);
    obj.label179:setField("corrosao");
    obj.label179:setAlign("client");
    obj.label179:setHorzTextAlign("center");
    obj.label179:setName("label179");
    obj.label179:setFontColor("white");

    obj.layout107 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout107:setParent(obj.layout106);
    obj.layout107:setAlign("right");
    obj.layout107:setWidth(90);
    obj.layout107:setName("layout107");

    obj.rectangle110 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle110:setParent(obj.layout107);
    obj.rectangle110:setAlign("right");
    obj.rectangle110:setWidth(30);
    obj.rectangle110:setColor("#272C36");
    obj.rectangle110:setStrokeColor("#8A6C30");
    obj.rectangle110:setStrokeSize(1);
    obj.rectangle110:setHint("Entender");
    obj.rectangle110:setName("rectangle110");

    obj.label180 = GUI.fromHandle(_obj_newObject("label"));
    obj.label180:setParent(obj.rectangle110);
    obj.label180:setField("corrosaoEntender");
    obj.label180:setAlign("client");
    obj.label180:setHorzTextAlign("center");
    obj.label180:setName("label180");
    obj.label180:setFontColor("white");

    obj.rectangle111 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle111:setParent(obj.layout107);
    obj.rectangle111:setAlign("right");
    obj.rectangle111:setWidth(30);
    obj.rectangle111:setColor("#272C36");
    obj.rectangle111:setStrokeColor("#8A6C30");
    obj.rectangle111:setStrokeSize(1);
    obj.rectangle111:setHint("Controlar");
    obj.rectangle111:setName("rectangle111");

    obj.label181 = GUI.fromHandle(_obj_newObject("label"));
    obj.label181:setParent(obj.rectangle111);
    obj.label181:setField("corrosaoControlar");
    obj.label181:setAlign("client");
    obj.label181:setHorzTextAlign("center");
    obj.label181:setName("label181");
    obj.label181:setFontColor("white");

    obj.rectangle112 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle112:setParent(obj.layout107);
    obj.rectangle112:setAlign("right");
    obj.rectangle112:setWidth(30);
    obj.rectangle112:setColor("#272C36");
    obj.rectangle112:setStrokeColor("#8A6C30");
    obj.rectangle112:setStrokeSize(1);
    obj.rectangle112:setHint("Criar");
    obj.rectangle112:setName("rectangle112");

    obj.label182 = GUI.fromHandle(_obj_newObject("label"));
    obj.label182:setParent(obj.rectangle112);
    obj.label182:setField("corrosaoCriar");
    obj.label182:setAlign("client");
    obj.label182:setHorzTextAlign("center");
    obj.label182:setName("label182");
    obj.label182:setFontColor("white");

    obj.dataLink43 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink43:setParent(obj.layout106);
    obj.dataLink43:setFields({'corrosao','entender','controlar','criar'});
    obj.dataLink43:setName("dataLink43");

    obj.layout108 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout108:setParent(obj.layout99);
    obj.layout108:setAlign("top");
    obj.layout108:setHeight(25);
    obj.layout108:setMargins({top=5,left=5,right=5});
    obj.layout108:setName("layout108");

    obj.label183 = GUI.fromHandle(_obj_newObject("label"));
    obj.label183:setParent(obj.layout108);
    obj.label183:setText("Vácuo");
    obj.label183:setAlign("client");
    obj.label183:setName("label183");
    obj.label183:setFontColor("white");

    obj.rectangle113 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle113:setParent(obj.layout108);
    obj.rectangle113:setAlign("right");
    obj.rectangle113:setWidth(50);
    obj.rectangle113:setColor("#272C36");
    obj.rectangle113:setStrokeColor("#8A6C30");
    obj.rectangle113:setStrokeSize(1);
    obj.rectangle113:setName("rectangle113");

    obj.label184 = GUI.fromHandle(_obj_newObject("label"));
    obj.label184:setParent(obj.rectangle113);
    obj.label184:setField("vacuo");
    obj.label184:setAlign("client");
    obj.label184:setHorzTextAlign("center");
    obj.label184:setName("label184");
    obj.label184:setFontColor("white");

    obj.layout109 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout109:setParent(obj.layout108);
    obj.layout109:setAlign("right");
    obj.layout109:setWidth(90);
    obj.layout109:setName("layout109");

    obj.rectangle114 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle114:setParent(obj.layout109);
    obj.rectangle114:setAlign("right");
    obj.rectangle114:setWidth(30);
    obj.rectangle114:setColor("#272C36");
    obj.rectangle114:setStrokeColor("#8A6C30");
    obj.rectangle114:setStrokeSize(1);
    obj.rectangle114:setHint("Entender");
    obj.rectangle114:setName("rectangle114");

    obj.label185 = GUI.fromHandle(_obj_newObject("label"));
    obj.label185:setParent(obj.rectangle114);
    obj.label185:setField("vacuoEntender");
    obj.label185:setAlign("client");
    obj.label185:setHorzTextAlign("center");
    obj.label185:setName("label185");
    obj.label185:setFontColor("white");

    obj.rectangle115 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle115:setParent(obj.layout109);
    obj.rectangle115:setAlign("right");
    obj.rectangle115:setWidth(30);
    obj.rectangle115:setColor("#272C36");
    obj.rectangle115:setStrokeColor("#8A6C30");
    obj.rectangle115:setStrokeSize(1);
    obj.rectangle115:setHint("Controlar");
    obj.rectangle115:setName("rectangle115");

    obj.label186 = GUI.fromHandle(_obj_newObject("label"));
    obj.label186:setParent(obj.rectangle115);
    obj.label186:setField("vacuoControlar");
    obj.label186:setAlign("client");
    obj.label186:setHorzTextAlign("center");
    obj.label186:setName("label186");
    obj.label186:setFontColor("white");

    obj.rectangle116 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle116:setParent(obj.layout109);
    obj.rectangle116:setAlign("right");
    obj.rectangle116:setWidth(30);
    obj.rectangle116:setColor("#272C36");
    obj.rectangle116:setStrokeColor("#8A6C30");
    obj.rectangle116:setStrokeSize(1);
    obj.rectangle116:setHint("Criar");
    obj.rectangle116:setName("rectangle116");

    obj.label187 = GUI.fromHandle(_obj_newObject("label"));
    obj.label187:setParent(obj.rectangle116);
    obj.label187:setField("vacuoCriar");
    obj.label187:setAlign("client");
    obj.label187:setHorzTextAlign("center");
    obj.label187:setName("label187");
    obj.label187:setFontColor("white");

    obj.dataLink44 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink44:setParent(obj.layout108);
    obj.dataLink44:setFields({'vacuo','entender','controlar','criar'});
    obj.dataLink44:setName("dataLink44");

    obj.layout110 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout110:setParent(obj.layout99);
    obj.layout110:setAlign("top");
    obj.layout110:setHeight(25);
    obj.layout110:setMargins({top=5,left=5,right=5});
    obj.layout110:setName("layout110");

    obj.label188 = GUI.fromHandle(_obj_newObject("label"));
    obj.label188:setParent(obj.layout110);
    obj.label188:setText("Venenos e Ácidos");
    obj.label188:setAlign("client");
    obj.label188:setName("label188");
    obj.label188:setFontColor("white");

    obj.rectangle117 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle117:setParent(obj.layout110);
    obj.rectangle117:setAlign("right");
    obj.rectangle117:setWidth(50);
    obj.rectangle117:setColor("#272C36");
    obj.rectangle117:setStrokeColor("#8A6C30");
    obj.rectangle117:setStrokeSize(1);
    obj.rectangle117:setName("rectangle117");

    obj.label189 = GUI.fromHandle(_obj_newObject("label"));
    obj.label189:setParent(obj.rectangle117);
    obj.label189:setField("venenos");
    obj.label189:setAlign("client");
    obj.label189:setHorzTextAlign("center");
    obj.label189:setName("label189");
    obj.label189:setFontColor("white");

    obj.layout111 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout111:setParent(obj.layout110);
    obj.layout111:setAlign("right");
    obj.layout111:setWidth(90);
    obj.layout111:setName("layout111");

    obj.rectangle118 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle118:setParent(obj.layout111);
    obj.rectangle118:setAlign("right");
    obj.rectangle118:setWidth(30);
    obj.rectangle118:setColor("#272C36");
    obj.rectangle118:setStrokeColor("#8A6C30");
    obj.rectangle118:setStrokeSize(1);
    obj.rectangle118:setHint("Entender");
    obj.rectangle118:setName("rectangle118");

    obj.label190 = GUI.fromHandle(_obj_newObject("label"));
    obj.label190:setParent(obj.rectangle118);
    obj.label190:setField("venenosEntender");
    obj.label190:setAlign("client");
    obj.label190:setHorzTextAlign("center");
    obj.label190:setName("label190");
    obj.label190:setFontColor("white");

    obj.rectangle119 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle119:setParent(obj.layout111);
    obj.rectangle119:setAlign("right");
    obj.rectangle119:setWidth(30);
    obj.rectangle119:setColor("#272C36");
    obj.rectangle119:setStrokeColor("#8A6C30");
    obj.rectangle119:setStrokeSize(1);
    obj.rectangle119:setHint("Controlar");
    obj.rectangle119:setName("rectangle119");

    obj.label191 = GUI.fromHandle(_obj_newObject("label"));
    obj.label191:setParent(obj.rectangle119);
    obj.label191:setField("venenosControlar");
    obj.label191:setAlign("client");
    obj.label191:setHorzTextAlign("center");
    obj.label191:setName("label191");
    obj.label191:setFontColor("white");

    obj.rectangle120 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle120:setParent(obj.layout111);
    obj.rectangle120:setAlign("right");
    obj.rectangle120:setWidth(30);
    obj.rectangle120:setColor("#272C36");
    obj.rectangle120:setStrokeColor("#8A6C30");
    obj.rectangle120:setStrokeSize(1);
    obj.rectangle120:setHint("Criar");
    obj.rectangle120:setName("rectangle120");

    obj.label192 = GUI.fromHandle(_obj_newObject("label"));
    obj.label192:setParent(obj.rectangle120);
    obj.label192:setField("venenosCriar");
    obj.label192:setAlign("client");
    obj.label192:setHorzTextAlign("center");
    obj.label192:setName("label192");
    obj.label192:setFontColor("white");

    obj.dataLink45 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink45:setParent(obj.layout110);
    obj.dataLink45:setFields({'venenos','entender','controlar','criar'});
    obj.dataLink45:setName("dataLink45");

    obj.dataLink46 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink46:setParent(obj.fraMagiasLayout);
    obj.dataLink46:setFields({'ar', 'terra', 'agua', 'fogo', 'luz', 'trevas'});
    obj.dataLink46:setName("dataLink46");

    obj.flowLineBreak3 = GUI.fromHandle(_obj_newObject("flowLineBreak"));
    obj.flowLineBreak3:setParent(obj.fraMagiasLayout);
    obj.flowLineBreak3:setName("flowLineBreak3");

    obj.flowLayout3 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout3:setParent(obj.fraMagiasLayout);
    obj.flowLayout3:setAutoHeight(true);
    obj.flowLayout3:setMaxColumns(3);
    obj.flowLayout3:setHorzAlign("center");
    obj.flowLayout3:setOrientation("vertical");
    obj.flowLayout3:setName("flowLayout3");
    obj.flowLayout3:setStepSizes({310, 420, 640, 760, 860, 960, 1150, 1200, 1600});
    obj.flowLayout3:setMinScaledWidth(300);
    obj.flowLayout3:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowLayout3:setVertAlign("leading");

    obj.flowLayout4 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout4:setParent(obj.flowLayout3);
    obj.flowLayout4:setHeight(100);
    obj.flowLayout4:setAvoidScale(true);
    obj.flowLayout4:setMaxControlsPerLine(1);
    obj.flowLayout4:setAutoHeight(true);
    obj.flowLayout4:setName("flowLayout4");
    obj.flowLayout4:setMargins({left=10, right=10, top=4, bottom=4});
    obj.flowLayout4:setStepSizes({310, 360, 420, 600});
    obj.flowLayout4:setMinScaledWidth(300);
    obj.flowLayout4:setMaxScaledWidth(600);
    obj.flowLayout4:setVertAlign("leading");

    obj.flowPart9 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart9:setParent(obj.flowLayout4);
    obj.flowPart9:setFrameStyle("/FichaDaemon/frames/magicHeader/header0.xml");
    obj.flowPart9:setName("flowPart9");
    obj.flowPart9:setAvoidScale(true);
    obj.flowPart9:setMinScaledWidth(280);
    obj.flowPart9:setMinWidth(300);
    obj.flowPart9:setMaxWidth(600);
    obj.flowPart9:setHeight(80);
    obj.flowPart9:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart9:setVertAlign("leading");

    obj.label193 = GUI.fromHandle(_obj_newObject("label"));
    obj.label193:setParent(obj.flowPart9);
    obj.label193:setFrameRegion("RegiaoSmallTitulo");
    obj.label193:setText("1");
    obj.label193:setName("label193");
    obj.label193:setHorzTextAlign("center");
    obj.label193:setVertTextAlign("center");
    obj.label193:setFontSize(18);
    obj.label193:setFontColor("white");

    obj.label194 = GUI.fromHandle(_obj_newObject("label"));
    obj.label194:setParent(obj.flowPart9);
    obj.label194:setFrameRegion("RegiaoConteudo");
    obj.label194:setText("Circulo 1");
    obj.label194:setFontSize(15);
    obj.label194:setHorzTextAlign("center");
    obj.label194:setVertTextAlign("center");
    obj.label194:setName("label194");
    obj.label194:setFontColor("white");

    obj.flwMagicRecordList1 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flwMagicRecordList1:setParent(obj.flowLayout4);
    obj.flwMagicRecordList1:setMinWidth(300);
    obj.flwMagicRecordList1:setMaxWidth(600);
    obj.flwMagicRecordList1:setMinScaledWidth(280);
    obj.flwMagicRecordList1:setName("flwMagicRecordList1");
    obj.flwMagicRecordList1:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flwMagicRecordList1:setVertAlign("leading");


				



					rawset(self.flwMagicRecordList1, "_recalcHeight", 					
						function ()
							self.flwMagicRecordList1.height = self.rclflwMagicRecordList1.height +
														self.layBottomflwMagicRecordList1.height + 
														self.flwMagicRecordList1.padding.top + self.flwMagicRecordList1.padding.bottom + 7;
						end);
				



			


    obj.rclflwMagicRecordList1 = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclflwMagicRecordList1:setParent(obj.flwMagicRecordList1);
    obj.rclflwMagicRecordList1:setName("rclflwMagicRecordList1");
    obj.rclflwMagicRecordList1:setAlign("top");
    obj.rclflwMagicRecordList1:setField("magias.magias.nivel1");
    obj.rclflwMagicRecordList1:setTemplateForm("frmMagiaItemSemCheckbox");
    obj.rclflwMagicRecordList1:setAutoHeight(true);
    obj.rclflwMagicRecordList1:setMinHeight(5);
    obj.rclflwMagicRecordList1:setHitTest(false);
    obj.rclflwMagicRecordList1:setMargins({left=10, right=10});

    obj.layBottomflwMagicRecordList1 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layBottomflwMagicRecordList1:setParent(obj.flwMagicRecordList1);
    obj.layBottomflwMagicRecordList1:setName("layBottomflwMagicRecordList1");
    obj.layBottomflwMagicRecordList1:setAlign("top");
    obj.layBottomflwMagicRecordList1:setHeight(36);

    obj.btnNovoflwMagicRecordList1 = GUI.fromHandle(_obj_newObject("button"));
    obj.btnNovoflwMagicRecordList1:setParent(obj.layBottomflwMagicRecordList1);
    obj.btnNovoflwMagicRecordList1:setName("btnNovoflwMagicRecordList1");
    obj.btnNovoflwMagicRecordList1:setAlign("left");
    obj.btnNovoflwMagicRecordList1:setText("@@DnD5e.spells.btn.newspell");
    obj.btnNovoflwMagicRecordList1:setWidth(160);
    obj.btnNovoflwMagicRecordList1:setMargins({top=4, bottom=4, left=48});

self.flwMagicRecordList1._recalcHeight();


    obj.flowLayout5 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout5:setParent(obj.flowLayout3);
    obj.flowLayout5:setHeight(100);
    obj.flowLayout5:setAvoidScale(true);
    obj.flowLayout5:setMaxControlsPerLine(1);
    obj.flowLayout5:setAutoHeight(true);
    obj.flowLayout5:setName("flowLayout5");
    obj.flowLayout5:setMargins({left=10, right=10, top=4, bottom=4});
    obj.flowLayout5:setStepSizes({310, 360, 420, 600});
    obj.flowLayout5:setMinScaledWidth(300);
    obj.flowLayout5:setMaxScaledWidth(600);
    obj.flowLayout5:setVertAlign("leading");

    obj.flowPart10 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart10:setParent(obj.flowLayout5);
    obj.flowPart10:setFrameStyle("/FichaDaemon/frames/magicHeader/header0.xml");
    obj.flowPart10:setName("flowPart10");
    obj.flowPart10:setAvoidScale(true);
    obj.flowPart10:setMinScaledWidth(280);
    obj.flowPart10:setMinWidth(300);
    obj.flowPart10:setMaxWidth(600);
    obj.flowPart10:setHeight(80);
    obj.flowPart10:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart10:setVertAlign("leading");

    obj.label195 = GUI.fromHandle(_obj_newObject("label"));
    obj.label195:setParent(obj.flowPart10);
    obj.label195:setFrameRegion("RegiaoSmallTitulo");
    obj.label195:setText("2");
    obj.label195:setName("label195");
    obj.label195:setHorzTextAlign("center");
    obj.label195:setVertTextAlign("center");
    obj.label195:setFontSize(18);
    obj.label195:setFontColor("white");

    obj.label196 = GUI.fromHandle(_obj_newObject("label"));
    obj.label196:setParent(obj.flowPart10);
    obj.label196:setFrameRegion("RegiaoConteudo");
    obj.label196:setText("Circulo 2");
    obj.label196:setFontSize(15);
    obj.label196:setHorzTextAlign("center");
    obj.label196:setVertTextAlign("center");
    obj.label196:setName("label196");
    obj.label196:setFontColor("white");

    obj.flwMagicRecordList2 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flwMagicRecordList2:setParent(obj.flowLayout5);
    obj.flwMagicRecordList2:setMinWidth(300);
    obj.flwMagicRecordList2:setMaxWidth(600);
    obj.flwMagicRecordList2:setMinScaledWidth(280);
    obj.flwMagicRecordList2:setName("flwMagicRecordList2");
    obj.flwMagicRecordList2:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flwMagicRecordList2:setVertAlign("leading");


				



					rawset(self.flwMagicRecordList2, "_recalcHeight", 					
						function ()
							self.flwMagicRecordList2.height = self.rclflwMagicRecordList2.height +
														self.layBottomflwMagicRecordList2.height + 
														self.flwMagicRecordList2.padding.top + self.flwMagicRecordList2.padding.bottom + 7;
						end);
				



			


    obj.rclflwMagicRecordList2 = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclflwMagicRecordList2:setParent(obj.flwMagicRecordList2);
    obj.rclflwMagicRecordList2:setName("rclflwMagicRecordList2");
    obj.rclflwMagicRecordList2:setAlign("top");
    obj.rclflwMagicRecordList2:setField("magias.magias.nivel2");
    obj.rclflwMagicRecordList2:setTemplateForm("frmMagiaItemSemCheckbox");
    obj.rclflwMagicRecordList2:setAutoHeight(true);
    obj.rclflwMagicRecordList2:setMinHeight(5);
    obj.rclflwMagicRecordList2:setHitTest(false);
    obj.rclflwMagicRecordList2:setMargins({left=10, right=10});

    obj.layBottomflwMagicRecordList2 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layBottomflwMagicRecordList2:setParent(obj.flwMagicRecordList2);
    obj.layBottomflwMagicRecordList2:setName("layBottomflwMagicRecordList2");
    obj.layBottomflwMagicRecordList2:setAlign("top");
    obj.layBottomflwMagicRecordList2:setHeight(36);

    obj.btnNovoflwMagicRecordList2 = GUI.fromHandle(_obj_newObject("button"));
    obj.btnNovoflwMagicRecordList2:setParent(obj.layBottomflwMagicRecordList2);
    obj.btnNovoflwMagicRecordList2:setName("btnNovoflwMagicRecordList2");
    obj.btnNovoflwMagicRecordList2:setAlign("left");
    obj.btnNovoflwMagicRecordList2:setText("@@DnD5e.spells.btn.newspell");
    obj.btnNovoflwMagicRecordList2:setWidth(160);
    obj.btnNovoflwMagicRecordList2:setMargins({top=4, bottom=4, left=48});

self.flwMagicRecordList2._recalcHeight();


    obj.flowLayout6 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout6:setParent(obj.flowLayout3);
    obj.flowLayout6:setHeight(100);
    obj.flowLayout6:setAvoidScale(true);
    obj.flowLayout6:setMaxControlsPerLine(1);
    obj.flowLayout6:setAutoHeight(true);
    obj.flowLayout6:setName("flowLayout6");
    obj.flowLayout6:setMargins({left=10, right=10, top=4, bottom=4});
    obj.flowLayout6:setStepSizes({310, 360, 420, 600});
    obj.flowLayout6:setMinScaledWidth(300);
    obj.flowLayout6:setMaxScaledWidth(600);
    obj.flowLayout6:setVertAlign("leading");

    obj.flowPart11 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart11:setParent(obj.flowLayout6);
    obj.flowPart11:setFrameStyle("/FichaDaemon/frames/magicHeader/header0.xml");
    obj.flowPart11:setName("flowPart11");
    obj.flowPart11:setAvoidScale(true);
    obj.flowPart11:setMinScaledWidth(280);
    obj.flowPart11:setMinWidth(300);
    obj.flowPart11:setMaxWidth(600);
    obj.flowPart11:setHeight(80);
    obj.flowPart11:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart11:setVertAlign("leading");

    obj.label197 = GUI.fromHandle(_obj_newObject("label"));
    obj.label197:setParent(obj.flowPart11);
    obj.label197:setFrameRegion("RegiaoSmallTitulo");
    obj.label197:setText("3");
    obj.label197:setName("label197");
    obj.label197:setHorzTextAlign("center");
    obj.label197:setVertTextAlign("center");
    obj.label197:setFontSize(18);
    obj.label197:setFontColor("white");

    obj.label198 = GUI.fromHandle(_obj_newObject("label"));
    obj.label198:setParent(obj.flowPart11);
    obj.label198:setFrameRegion("RegiaoConteudo");
    obj.label198:setText("Circulo 3");
    obj.label198:setFontSize(15);
    obj.label198:setHorzTextAlign("center");
    obj.label198:setVertTextAlign("center");
    obj.label198:setName("label198");
    obj.label198:setFontColor("white");

    obj.flwMagicRecordList3 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flwMagicRecordList3:setParent(obj.flowLayout6);
    obj.flwMagicRecordList3:setMinWidth(300);
    obj.flwMagicRecordList3:setMaxWidth(600);
    obj.flwMagicRecordList3:setMinScaledWidth(280);
    obj.flwMagicRecordList3:setName("flwMagicRecordList3");
    obj.flwMagicRecordList3:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flwMagicRecordList3:setVertAlign("leading");


				



					rawset(self.flwMagicRecordList3, "_recalcHeight", 					
						function ()
							self.flwMagicRecordList3.height = self.rclflwMagicRecordList3.height +
														self.layBottomflwMagicRecordList3.height + 
														self.flwMagicRecordList3.padding.top + self.flwMagicRecordList3.padding.bottom + 7;
						end);
				



			


    obj.rclflwMagicRecordList3 = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclflwMagicRecordList3:setParent(obj.flwMagicRecordList3);
    obj.rclflwMagicRecordList3:setName("rclflwMagicRecordList3");
    obj.rclflwMagicRecordList3:setAlign("top");
    obj.rclflwMagicRecordList3:setField("magias.magias.nivel3");
    obj.rclflwMagicRecordList3:setTemplateForm("frmMagiaItemSemCheckbox");
    obj.rclflwMagicRecordList3:setAutoHeight(true);
    obj.rclflwMagicRecordList3:setMinHeight(5);
    obj.rclflwMagicRecordList3:setHitTest(false);
    obj.rclflwMagicRecordList3:setMargins({left=10, right=10});

    obj.layBottomflwMagicRecordList3 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layBottomflwMagicRecordList3:setParent(obj.flwMagicRecordList3);
    obj.layBottomflwMagicRecordList3:setName("layBottomflwMagicRecordList3");
    obj.layBottomflwMagicRecordList3:setAlign("top");
    obj.layBottomflwMagicRecordList3:setHeight(36);

    obj.btnNovoflwMagicRecordList3 = GUI.fromHandle(_obj_newObject("button"));
    obj.btnNovoflwMagicRecordList3:setParent(obj.layBottomflwMagicRecordList3);
    obj.btnNovoflwMagicRecordList3:setName("btnNovoflwMagicRecordList3");
    obj.btnNovoflwMagicRecordList3:setAlign("left");
    obj.btnNovoflwMagicRecordList3:setText("@@DnD5e.spells.btn.newspell");
    obj.btnNovoflwMagicRecordList3:setWidth(160);
    obj.btnNovoflwMagicRecordList3:setMargins({top=4, bottom=4, left=48});

self.flwMagicRecordList3._recalcHeight();


    obj.flowLayout7 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout7:setParent(obj.flowLayout3);
    obj.flowLayout7:setHeight(100);
    obj.flowLayout7:setAvoidScale(true);
    obj.flowLayout7:setMaxControlsPerLine(1);
    obj.flowLayout7:setAutoHeight(true);
    obj.flowLayout7:setName("flowLayout7");
    obj.flowLayout7:setMargins({left=10, right=10, top=4, bottom=4});
    obj.flowLayout7:setStepSizes({310, 360, 420, 600});
    obj.flowLayout7:setMinScaledWidth(300);
    obj.flowLayout7:setMaxScaledWidth(600);
    obj.flowLayout7:setVertAlign("leading");

    obj.flowPart12 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart12:setParent(obj.flowLayout7);
    obj.flowPart12:setFrameStyle("/FichaDaemon/frames/magicHeader/header0.xml");
    obj.flowPart12:setName("flowPart12");
    obj.flowPart12:setAvoidScale(true);
    obj.flowPart12:setMinScaledWidth(280);
    obj.flowPart12:setMinWidth(300);
    obj.flowPart12:setMaxWidth(600);
    obj.flowPart12:setHeight(80);
    obj.flowPart12:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart12:setVertAlign("leading");

    obj.label199 = GUI.fromHandle(_obj_newObject("label"));
    obj.label199:setParent(obj.flowPart12);
    obj.label199:setFrameRegion("RegiaoSmallTitulo");
    obj.label199:setText("4");
    obj.label199:setName("label199");
    obj.label199:setHorzTextAlign("center");
    obj.label199:setVertTextAlign("center");
    obj.label199:setFontSize(18);
    obj.label199:setFontColor("white");

    obj.label200 = GUI.fromHandle(_obj_newObject("label"));
    obj.label200:setParent(obj.flowPart12);
    obj.label200:setFrameRegion("RegiaoConteudo");
    obj.label200:setText("Circulo 4");
    obj.label200:setFontSize(15);
    obj.label200:setHorzTextAlign("center");
    obj.label200:setVertTextAlign("center");
    obj.label200:setName("label200");
    obj.label200:setFontColor("white");

    obj.flwMagicRecordList4 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flwMagicRecordList4:setParent(obj.flowLayout7);
    obj.flwMagicRecordList4:setMinWidth(300);
    obj.flwMagicRecordList4:setMaxWidth(600);
    obj.flwMagicRecordList4:setMinScaledWidth(280);
    obj.flwMagicRecordList4:setName("flwMagicRecordList4");
    obj.flwMagicRecordList4:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flwMagicRecordList4:setVertAlign("leading");


				



					rawset(self.flwMagicRecordList4, "_recalcHeight", 					
						function ()
							self.flwMagicRecordList4.height = self.rclflwMagicRecordList4.height +
														self.layBottomflwMagicRecordList4.height + 
														self.flwMagicRecordList4.padding.top + self.flwMagicRecordList4.padding.bottom + 7;
						end);
				



			


    obj.rclflwMagicRecordList4 = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclflwMagicRecordList4:setParent(obj.flwMagicRecordList4);
    obj.rclflwMagicRecordList4:setName("rclflwMagicRecordList4");
    obj.rclflwMagicRecordList4:setAlign("top");
    obj.rclflwMagicRecordList4:setField("magias.magias.nivel4");
    obj.rclflwMagicRecordList4:setTemplateForm("frmMagiaItemSemCheckbox");
    obj.rclflwMagicRecordList4:setAutoHeight(true);
    obj.rclflwMagicRecordList4:setMinHeight(5);
    obj.rclflwMagicRecordList4:setHitTest(false);
    obj.rclflwMagicRecordList4:setMargins({left=10, right=10});

    obj.layBottomflwMagicRecordList4 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layBottomflwMagicRecordList4:setParent(obj.flwMagicRecordList4);
    obj.layBottomflwMagicRecordList4:setName("layBottomflwMagicRecordList4");
    obj.layBottomflwMagicRecordList4:setAlign("top");
    obj.layBottomflwMagicRecordList4:setHeight(36);

    obj.btnNovoflwMagicRecordList4 = GUI.fromHandle(_obj_newObject("button"));
    obj.btnNovoflwMagicRecordList4:setParent(obj.layBottomflwMagicRecordList4);
    obj.btnNovoflwMagicRecordList4:setName("btnNovoflwMagicRecordList4");
    obj.btnNovoflwMagicRecordList4:setAlign("left");
    obj.btnNovoflwMagicRecordList4:setText("@@DnD5e.spells.btn.newspell");
    obj.btnNovoflwMagicRecordList4:setWidth(160);
    obj.btnNovoflwMagicRecordList4:setMargins({top=4, bottom=4, left=48});

self.flwMagicRecordList4._recalcHeight();


    obj.flowLayout8 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout8:setParent(obj.flowLayout3);
    obj.flowLayout8:setHeight(100);
    obj.flowLayout8:setAvoidScale(true);
    obj.flowLayout8:setMaxControlsPerLine(1);
    obj.flowLayout8:setAutoHeight(true);
    obj.flowLayout8:setName("flowLayout8");
    obj.flowLayout8:setMargins({left=10, right=10, top=4, bottom=4});
    obj.flowLayout8:setStepSizes({310, 360, 420, 600});
    obj.flowLayout8:setMinScaledWidth(300);
    obj.flowLayout8:setMaxScaledWidth(600);
    obj.flowLayout8:setVertAlign("leading");

    obj.flowPart13 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart13:setParent(obj.flowLayout8);
    obj.flowPart13:setFrameStyle("/FichaDaemon/frames/magicHeader/header0.xml");
    obj.flowPart13:setName("flowPart13");
    obj.flowPart13:setAvoidScale(true);
    obj.flowPart13:setMinScaledWidth(280);
    obj.flowPart13:setMinWidth(300);
    obj.flowPart13:setMaxWidth(600);
    obj.flowPart13:setHeight(80);
    obj.flowPart13:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart13:setVertAlign("leading");

    obj.label201 = GUI.fromHandle(_obj_newObject("label"));
    obj.label201:setParent(obj.flowPart13);
    obj.label201:setFrameRegion("RegiaoSmallTitulo");
    obj.label201:setText("5");
    obj.label201:setName("label201");
    obj.label201:setHorzTextAlign("center");
    obj.label201:setVertTextAlign("center");
    obj.label201:setFontSize(18);
    obj.label201:setFontColor("white");

    obj.label202 = GUI.fromHandle(_obj_newObject("label"));
    obj.label202:setParent(obj.flowPart13);
    obj.label202:setFrameRegion("RegiaoConteudo");
    obj.label202:setText("Circulo 5");
    obj.label202:setFontSize(15);
    obj.label202:setHorzTextAlign("center");
    obj.label202:setVertTextAlign("center");
    obj.label202:setName("label202");
    obj.label202:setFontColor("white");

    obj.flwMagicRecordList5 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flwMagicRecordList5:setParent(obj.flowLayout8);
    obj.flwMagicRecordList5:setMinWidth(300);
    obj.flwMagicRecordList5:setMaxWidth(600);
    obj.flwMagicRecordList5:setMinScaledWidth(280);
    obj.flwMagicRecordList5:setName("flwMagicRecordList5");
    obj.flwMagicRecordList5:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flwMagicRecordList5:setVertAlign("leading");


				



					rawset(self.flwMagicRecordList5, "_recalcHeight", 					
						function ()
							self.flwMagicRecordList5.height = self.rclflwMagicRecordList5.height +
														self.layBottomflwMagicRecordList5.height + 
														self.flwMagicRecordList5.padding.top + self.flwMagicRecordList5.padding.bottom + 7;
						end);
				



			


    obj.rclflwMagicRecordList5 = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclflwMagicRecordList5:setParent(obj.flwMagicRecordList5);
    obj.rclflwMagicRecordList5:setName("rclflwMagicRecordList5");
    obj.rclflwMagicRecordList5:setAlign("top");
    obj.rclflwMagicRecordList5:setField("magias.magias.nivel5");
    obj.rclflwMagicRecordList5:setTemplateForm("frmMagiaItemSemCheckbox");
    obj.rclflwMagicRecordList5:setAutoHeight(true);
    obj.rclflwMagicRecordList5:setMinHeight(5);
    obj.rclflwMagicRecordList5:setHitTest(false);
    obj.rclflwMagicRecordList5:setMargins({left=10, right=10});

    obj.layBottomflwMagicRecordList5 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layBottomflwMagicRecordList5:setParent(obj.flwMagicRecordList5);
    obj.layBottomflwMagicRecordList5:setName("layBottomflwMagicRecordList5");
    obj.layBottomflwMagicRecordList5:setAlign("top");
    obj.layBottomflwMagicRecordList5:setHeight(36);

    obj.btnNovoflwMagicRecordList5 = GUI.fromHandle(_obj_newObject("button"));
    obj.btnNovoflwMagicRecordList5:setParent(obj.layBottomflwMagicRecordList5);
    obj.btnNovoflwMagicRecordList5:setName("btnNovoflwMagicRecordList5");
    obj.btnNovoflwMagicRecordList5:setAlign("left");
    obj.btnNovoflwMagicRecordList5:setText("@@DnD5e.spells.btn.newspell");
    obj.btnNovoflwMagicRecordList5:setWidth(160);
    obj.btnNovoflwMagicRecordList5:setMargins({top=4, bottom=4, left=48});

self.flwMagicRecordList5._recalcHeight();


    obj.flowLayout9 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout9:setParent(obj.flowLayout3);
    obj.flowLayout9:setHeight(100);
    obj.flowLayout9:setAvoidScale(true);
    obj.flowLayout9:setMaxControlsPerLine(1);
    obj.flowLayout9:setAutoHeight(true);
    obj.flowLayout9:setName("flowLayout9");
    obj.flowLayout9:setMargins({left=10, right=10, top=4, bottom=4});
    obj.flowLayout9:setStepSizes({310, 360, 420, 600});
    obj.flowLayout9:setMinScaledWidth(300);
    obj.flowLayout9:setMaxScaledWidth(600);
    obj.flowLayout9:setVertAlign("leading");

    obj.flowPart14 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart14:setParent(obj.flowLayout9);
    obj.flowPart14:setFrameStyle("/FichaDaemon/frames/magicHeader/header0.xml");
    obj.flowPart14:setName("flowPart14");
    obj.flowPart14:setAvoidScale(true);
    obj.flowPart14:setMinScaledWidth(280);
    obj.flowPart14:setMinWidth(300);
    obj.flowPart14:setMaxWidth(600);
    obj.flowPart14:setHeight(80);
    obj.flowPart14:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart14:setVertAlign("leading");

    obj.label203 = GUI.fromHandle(_obj_newObject("label"));
    obj.label203:setParent(obj.flowPart14);
    obj.label203:setFrameRegion("RegiaoSmallTitulo");
    obj.label203:setText("6");
    obj.label203:setName("label203");
    obj.label203:setHorzTextAlign("center");
    obj.label203:setVertTextAlign("center");
    obj.label203:setFontSize(18);
    obj.label203:setFontColor("white");

    obj.label204 = GUI.fromHandle(_obj_newObject("label"));
    obj.label204:setParent(obj.flowPart14);
    obj.label204:setFrameRegion("RegiaoConteudo");
    obj.label204:setText("Circulo 6");
    obj.label204:setFontSize(15);
    obj.label204:setHorzTextAlign("center");
    obj.label204:setVertTextAlign("center");
    obj.label204:setName("label204");
    obj.label204:setFontColor("white");

    obj.flwMagicRecordList6 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flwMagicRecordList6:setParent(obj.flowLayout9);
    obj.flwMagicRecordList6:setMinWidth(300);
    obj.flwMagicRecordList6:setMaxWidth(600);
    obj.flwMagicRecordList6:setMinScaledWidth(280);
    obj.flwMagicRecordList6:setName("flwMagicRecordList6");
    obj.flwMagicRecordList6:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flwMagicRecordList6:setVertAlign("leading");


				



					rawset(self.flwMagicRecordList6, "_recalcHeight", 					
						function ()
							self.flwMagicRecordList6.height = self.rclflwMagicRecordList6.height +
														self.layBottomflwMagicRecordList6.height + 
														self.flwMagicRecordList6.padding.top + self.flwMagicRecordList6.padding.bottom + 7;
						end);
				



			


    obj.rclflwMagicRecordList6 = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclflwMagicRecordList6:setParent(obj.flwMagicRecordList6);
    obj.rclflwMagicRecordList6:setName("rclflwMagicRecordList6");
    obj.rclflwMagicRecordList6:setAlign("top");
    obj.rclflwMagicRecordList6:setField("magias.magias.nivel6");
    obj.rclflwMagicRecordList6:setTemplateForm("frmMagiaItemSemCheckbox");
    obj.rclflwMagicRecordList6:setAutoHeight(true);
    obj.rclflwMagicRecordList6:setMinHeight(5);
    obj.rclflwMagicRecordList6:setHitTest(false);
    obj.rclflwMagicRecordList6:setMargins({left=10, right=10});

    obj.layBottomflwMagicRecordList6 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layBottomflwMagicRecordList6:setParent(obj.flwMagicRecordList6);
    obj.layBottomflwMagicRecordList6:setName("layBottomflwMagicRecordList6");
    obj.layBottomflwMagicRecordList6:setAlign("top");
    obj.layBottomflwMagicRecordList6:setHeight(36);

    obj.btnNovoflwMagicRecordList6 = GUI.fromHandle(_obj_newObject("button"));
    obj.btnNovoflwMagicRecordList6:setParent(obj.layBottomflwMagicRecordList6);
    obj.btnNovoflwMagicRecordList6:setName("btnNovoflwMagicRecordList6");
    obj.btnNovoflwMagicRecordList6:setAlign("left");
    obj.btnNovoflwMagicRecordList6:setText("@@DnD5e.spells.btn.newspell");
    obj.btnNovoflwMagicRecordList6:setWidth(160);
    obj.btnNovoflwMagicRecordList6:setMargins({top=4, bottom=4, left=48});

self.flwMagicRecordList6._recalcHeight();


    obj.flowLayout10 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout10:setParent(obj.flowLayout3);
    obj.flowLayout10:setHeight(100);
    obj.flowLayout10:setAvoidScale(true);
    obj.flowLayout10:setMaxControlsPerLine(1);
    obj.flowLayout10:setAutoHeight(true);
    obj.flowLayout10:setName("flowLayout10");
    obj.flowLayout10:setMargins({left=10, right=10, top=4, bottom=4});
    obj.flowLayout10:setStepSizes({310, 360, 420, 600});
    obj.flowLayout10:setMinScaledWidth(300);
    obj.flowLayout10:setMaxScaledWidth(600);
    obj.flowLayout10:setVertAlign("leading");

    obj.flowPart15 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart15:setParent(obj.flowLayout10);
    obj.flowPart15:setFrameStyle("/FichaDaemon/frames/magicHeader/header0.xml");
    obj.flowPart15:setName("flowPart15");
    obj.flowPart15:setAvoidScale(true);
    obj.flowPart15:setMinScaledWidth(280);
    obj.flowPart15:setMinWidth(300);
    obj.flowPart15:setMaxWidth(600);
    obj.flowPart15:setHeight(80);
    obj.flowPart15:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart15:setVertAlign("leading");

    obj.label205 = GUI.fromHandle(_obj_newObject("label"));
    obj.label205:setParent(obj.flowPart15);
    obj.label205:setFrameRegion("RegiaoSmallTitulo");
    obj.label205:setText("7");
    obj.label205:setName("label205");
    obj.label205:setHorzTextAlign("center");
    obj.label205:setVertTextAlign("center");
    obj.label205:setFontSize(18);
    obj.label205:setFontColor("white");

    obj.label206 = GUI.fromHandle(_obj_newObject("label"));
    obj.label206:setParent(obj.flowPart15);
    obj.label206:setFrameRegion("RegiaoConteudo");
    obj.label206:setText("Circulo 7");
    obj.label206:setFontSize(15);
    obj.label206:setHorzTextAlign("center");
    obj.label206:setVertTextAlign("center");
    obj.label206:setName("label206");
    obj.label206:setFontColor("white");

    obj.flwMagicRecordList7 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flwMagicRecordList7:setParent(obj.flowLayout10);
    obj.flwMagicRecordList7:setMinWidth(300);
    obj.flwMagicRecordList7:setMaxWidth(600);
    obj.flwMagicRecordList7:setMinScaledWidth(280);
    obj.flwMagicRecordList7:setName("flwMagicRecordList7");
    obj.flwMagicRecordList7:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flwMagicRecordList7:setVertAlign("leading");


				



					rawset(self.flwMagicRecordList7, "_recalcHeight", 					
						function ()
							self.flwMagicRecordList7.height = self.rclflwMagicRecordList7.height +
														self.layBottomflwMagicRecordList7.height + 
														self.flwMagicRecordList7.padding.top + self.flwMagicRecordList7.padding.bottom + 7;
						end);
				



			


    obj.rclflwMagicRecordList7 = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclflwMagicRecordList7:setParent(obj.flwMagicRecordList7);
    obj.rclflwMagicRecordList7:setName("rclflwMagicRecordList7");
    obj.rclflwMagicRecordList7:setAlign("top");
    obj.rclflwMagicRecordList7:setField("magias.magias.nivel7");
    obj.rclflwMagicRecordList7:setTemplateForm("frmMagiaItemSemCheckbox");
    obj.rclflwMagicRecordList7:setAutoHeight(true);
    obj.rclflwMagicRecordList7:setMinHeight(5);
    obj.rclflwMagicRecordList7:setHitTest(false);
    obj.rclflwMagicRecordList7:setMargins({left=10, right=10});

    obj.layBottomflwMagicRecordList7 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layBottomflwMagicRecordList7:setParent(obj.flwMagicRecordList7);
    obj.layBottomflwMagicRecordList7:setName("layBottomflwMagicRecordList7");
    obj.layBottomflwMagicRecordList7:setAlign("top");
    obj.layBottomflwMagicRecordList7:setHeight(36);

    obj.btnNovoflwMagicRecordList7 = GUI.fromHandle(_obj_newObject("button"));
    obj.btnNovoflwMagicRecordList7:setParent(obj.layBottomflwMagicRecordList7);
    obj.btnNovoflwMagicRecordList7:setName("btnNovoflwMagicRecordList7");
    obj.btnNovoflwMagicRecordList7:setAlign("left");
    obj.btnNovoflwMagicRecordList7:setText("@@DnD5e.spells.btn.newspell");
    obj.btnNovoflwMagicRecordList7:setWidth(160);
    obj.btnNovoflwMagicRecordList7:setMargins({top=4, bottom=4, left=48});

self.flwMagicRecordList7._recalcHeight();


    obj.flowLayout11 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout11:setParent(obj.flowLayout3);
    obj.flowLayout11:setHeight(100);
    obj.flowLayout11:setAvoidScale(true);
    obj.flowLayout11:setMaxControlsPerLine(1);
    obj.flowLayout11:setAutoHeight(true);
    obj.flowLayout11:setName("flowLayout11");
    obj.flowLayout11:setMargins({left=10, right=10, top=4, bottom=4});
    obj.flowLayout11:setStepSizes({310, 360, 420, 600});
    obj.flowLayout11:setMinScaledWidth(300);
    obj.flowLayout11:setMaxScaledWidth(600);
    obj.flowLayout11:setVertAlign("leading");

    obj.flowPart16 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart16:setParent(obj.flowLayout11);
    obj.flowPart16:setFrameStyle("/FichaDaemon/frames/magicHeader/header0.xml");
    obj.flowPart16:setName("flowPart16");
    obj.flowPart16:setAvoidScale(true);
    obj.flowPart16:setMinScaledWidth(280);
    obj.flowPart16:setMinWidth(300);
    obj.flowPart16:setMaxWidth(600);
    obj.flowPart16:setHeight(80);
    obj.flowPart16:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart16:setVertAlign("leading");

    obj.label207 = GUI.fromHandle(_obj_newObject("label"));
    obj.label207:setParent(obj.flowPart16);
    obj.label207:setFrameRegion("RegiaoSmallTitulo");
    obj.label207:setText("8");
    obj.label207:setName("label207");
    obj.label207:setHorzTextAlign("center");
    obj.label207:setVertTextAlign("center");
    obj.label207:setFontSize(18);
    obj.label207:setFontColor("white");

    obj.label208 = GUI.fromHandle(_obj_newObject("label"));
    obj.label208:setParent(obj.flowPart16);
    obj.label208:setFrameRegion("RegiaoConteudo");
    obj.label208:setText("Circulo 8");
    obj.label208:setFontSize(15);
    obj.label208:setHorzTextAlign("center");
    obj.label208:setVertTextAlign("center");
    obj.label208:setName("label208");
    obj.label208:setFontColor("white");

    obj.flwMagicRecordList8 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flwMagicRecordList8:setParent(obj.flowLayout11);
    obj.flwMagicRecordList8:setMinWidth(300);
    obj.flwMagicRecordList8:setMaxWidth(600);
    obj.flwMagicRecordList8:setMinScaledWidth(280);
    obj.flwMagicRecordList8:setName("flwMagicRecordList8");
    obj.flwMagicRecordList8:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flwMagicRecordList8:setVertAlign("leading");


				



					rawset(self.flwMagicRecordList8, "_recalcHeight", 					
						function ()
							self.flwMagicRecordList8.height = self.rclflwMagicRecordList8.height +
														self.layBottomflwMagicRecordList8.height + 
														self.flwMagicRecordList8.padding.top + self.flwMagicRecordList8.padding.bottom + 7;
						end);
				



			


    obj.rclflwMagicRecordList8 = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclflwMagicRecordList8:setParent(obj.flwMagicRecordList8);
    obj.rclflwMagicRecordList8:setName("rclflwMagicRecordList8");
    obj.rclflwMagicRecordList8:setAlign("top");
    obj.rclflwMagicRecordList8:setField("magias.magias.nivel8");
    obj.rclflwMagicRecordList8:setTemplateForm("frmMagiaItemSemCheckbox");
    obj.rclflwMagicRecordList8:setAutoHeight(true);
    obj.rclflwMagicRecordList8:setMinHeight(5);
    obj.rclflwMagicRecordList8:setHitTest(false);
    obj.rclflwMagicRecordList8:setMargins({left=10, right=10});

    obj.layBottomflwMagicRecordList8 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layBottomflwMagicRecordList8:setParent(obj.flwMagicRecordList8);
    obj.layBottomflwMagicRecordList8:setName("layBottomflwMagicRecordList8");
    obj.layBottomflwMagicRecordList8:setAlign("top");
    obj.layBottomflwMagicRecordList8:setHeight(36);

    obj.btnNovoflwMagicRecordList8 = GUI.fromHandle(_obj_newObject("button"));
    obj.btnNovoflwMagicRecordList8:setParent(obj.layBottomflwMagicRecordList8);
    obj.btnNovoflwMagicRecordList8:setName("btnNovoflwMagicRecordList8");
    obj.btnNovoflwMagicRecordList8:setAlign("left");
    obj.btnNovoflwMagicRecordList8:setText("@@DnD5e.spells.btn.newspell");
    obj.btnNovoflwMagicRecordList8:setWidth(160);
    obj.btnNovoflwMagicRecordList8:setMargins({top=4, bottom=4, left=48});

self.flwMagicRecordList8._recalcHeight();


    obj.flowLayout12 = GUI.fromHandle(_obj_newObject("flowLayout"));
    obj.flowLayout12:setParent(obj.flowLayout3);
    obj.flowLayout12:setHeight(100);
    obj.flowLayout12:setAvoidScale(true);
    obj.flowLayout12:setMaxControlsPerLine(1);
    obj.flowLayout12:setAutoHeight(true);
    obj.flowLayout12:setName("flowLayout12");
    obj.flowLayout12:setMargins({left=10, right=10, top=4, bottom=4});
    obj.flowLayout12:setStepSizes({310, 360, 420, 600});
    obj.flowLayout12:setMinScaledWidth(300);
    obj.flowLayout12:setMaxScaledWidth(600);
    obj.flowLayout12:setVertAlign("leading");

    obj.flowPart17 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flowPart17:setParent(obj.flowLayout12);
    obj.flowPart17:setFrameStyle("/FichaDaemon/frames/magicHeader/header0.xml");
    obj.flowPart17:setName("flowPart17");
    obj.flowPart17:setAvoidScale(true);
    obj.flowPart17:setMinScaledWidth(280);
    obj.flowPart17:setMinWidth(300);
    obj.flowPart17:setMaxWidth(600);
    obj.flowPart17:setHeight(80);
    obj.flowPart17:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flowPart17:setVertAlign("leading");

    obj.label209 = GUI.fromHandle(_obj_newObject("label"));
    obj.label209:setParent(obj.flowPart17);
    obj.label209:setFrameRegion("RegiaoSmallTitulo");
    obj.label209:setText("9");
    obj.label209:setName("label209");
    obj.label209:setHorzTextAlign("center");
    obj.label209:setVertTextAlign("center");
    obj.label209:setFontSize(18);
    obj.label209:setFontColor("white");

    obj.label210 = GUI.fromHandle(_obj_newObject("label"));
    obj.label210:setParent(obj.flowPart17);
    obj.label210:setFrameRegion("RegiaoConteudo");
    obj.label210:setText("Circulo 9");
    obj.label210:setFontSize(15);
    obj.label210:setHorzTextAlign("center");
    obj.label210:setVertTextAlign("center");
    obj.label210:setName("label210");
    obj.label210:setFontColor("white");

    obj.flwMagicRecordList9 = GUI.fromHandle(_obj_newObject("flowPart"));
    obj.flwMagicRecordList9:setParent(obj.flowLayout12);
    obj.flwMagicRecordList9:setMinWidth(300);
    obj.flwMagicRecordList9:setMaxWidth(600);
    obj.flwMagicRecordList9:setMinScaledWidth(280);
    obj.flwMagicRecordList9:setName("flwMagicRecordList9");
    obj.flwMagicRecordList9:setMargins({left=1, right=1, top=2, bottom=2});
    obj.flwMagicRecordList9:setVertAlign("leading");


				



					rawset(self.flwMagicRecordList9, "_recalcHeight", 					
						function ()
							self.flwMagicRecordList9.height = self.rclflwMagicRecordList9.height +
														self.layBottomflwMagicRecordList9.height + 
														self.flwMagicRecordList9.padding.top + self.flwMagicRecordList9.padding.bottom + 7;
						end);
				



			


    obj.rclflwMagicRecordList9 = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclflwMagicRecordList9:setParent(obj.flwMagicRecordList9);
    obj.rclflwMagicRecordList9:setName("rclflwMagicRecordList9");
    obj.rclflwMagicRecordList9:setAlign("top");
    obj.rclflwMagicRecordList9:setField("magias.magias.nivel9");
    obj.rclflwMagicRecordList9:setTemplateForm("frmMagiaItemSemCheckbox");
    obj.rclflwMagicRecordList9:setAutoHeight(true);
    obj.rclflwMagicRecordList9:setMinHeight(5);
    obj.rclflwMagicRecordList9:setHitTest(false);
    obj.rclflwMagicRecordList9:setMargins({left=10, right=10});

    obj.layBottomflwMagicRecordList9 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layBottomflwMagicRecordList9:setParent(obj.flwMagicRecordList9);
    obj.layBottomflwMagicRecordList9:setName("layBottomflwMagicRecordList9");
    obj.layBottomflwMagicRecordList9:setAlign("top");
    obj.layBottomflwMagicRecordList9:setHeight(36);

    obj.btnNovoflwMagicRecordList9 = GUI.fromHandle(_obj_newObject("button"));
    obj.btnNovoflwMagicRecordList9:setParent(obj.layBottomflwMagicRecordList9);
    obj.btnNovoflwMagicRecordList9:setName("btnNovoflwMagicRecordList9");
    obj.btnNovoflwMagicRecordList9:setAlign("left");
    obj.btnNovoflwMagicRecordList9:setText("@@DnD5e.spells.btn.newspell");
    obj.btnNovoflwMagicRecordList9:setWidth(160);
    obj.btnNovoflwMagicRecordList9:setMargins({top=4, bottom=4, left=48});

self.flwMagicRecordList9._recalcHeight();


    obj.tab4 = GUI.fromHandle(_obj_newObject("tab"));
    obj.tab4:setParent(obj.tabControl1);
    obj.tab4:setTitle("Historia");
    obj.tab4:setName("tab4");

    obj.frmTemplateDescription = GUI.fromHandle(_obj_newObject("form"));
    obj.frmTemplateDescription:setParent(obj.tab4);
    obj.frmTemplateDescription:setName("frmTemplateDescription");
    obj.frmTemplateDescription:setAlign("client");

    obj.richEdit1 = GUI.fromHandle(_obj_newObject("richEdit"));
    obj.richEdit1:setParent(obj.frmTemplateDescription);
    obj.richEdit1:setAlign("client");
    obj.richEdit1:setField("background");
    obj.richEdit1.backgroundColor = "#333333";
    obj.richEdit1.defaultFontSize = 12;
    obj.richEdit1.defaultFontColor = "white";
    obj.richEdit1:setName("richEdit1");

    obj.tab5 = GUI.fromHandle(_obj_newObject("tab"));
    obj.tab5:setParent(obj.tabControl1);
    obj.tab5:setTitle("Anotações");
    obj.tab5:setName("tab5");

    obj.frmTemplateNotes = GUI.fromHandle(_obj_newObject("form"));
    obj.frmTemplateNotes:setParent(obj.tab5);
    obj.frmTemplateNotes:setName("frmTemplateNotes");
    obj.frmTemplateNotes:setAlign("client");

    obj.scrollBox4 = GUI.fromHandle(_obj_newObject("scrollBox"));
    obj.scrollBox4:setParent(obj.frmTemplateNotes);
    obj.scrollBox4:setAlign("client");
    obj.scrollBox4:setName("scrollBox4");

    obj.layout112 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout112:setParent(obj.scrollBox4);
    obj.layout112:setAlign("left");
    obj.layout112:setWidth(400);
    obj.layout112:setMargins({right=10});
    obj.layout112:setName("layout112");

    obj.rectangle121 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle121:setParent(obj.layout112);
    obj.rectangle121:setAlign("client");
    obj.rectangle121:setColor("#272C36");
    obj.rectangle121:setXradius(5);
    obj.rectangle121:setYradius(15);
    obj.rectangle121:setCornerType("round");
    obj.rectangle121:setName("rectangle121");

    obj.label211 = GUI.fromHandle(_obj_newObject("label"));
    obj.label211:setParent(obj.rectangle121);
    obj.label211:setAlign("top");
    obj.label211:setHeight(20);
    obj.label211:setText("Anotações");
    obj.label211:setHorzTextAlign("center");
    obj.label211:setName("label211");
    obj.label211:setFontColor("white");

    obj.textEditor3 = GUI.fromHandle(_obj_newObject("textEditor"));
    obj.textEditor3:setParent(obj.rectangle121);
    obj.textEditor3:setAlign("client");
    obj.textEditor3:setField("anotacoes1");
    obj.textEditor3:setMargins({left=10,right=10,bottom=10});
    obj.textEditor3:setName("textEditor3");

    obj.layout113 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout113:setParent(obj.scrollBox4);
    obj.layout113:setAlign("left");
    obj.layout113:setWidth(400);
    obj.layout113:setMargins({right=10});
    obj.layout113:setName("layout113");

    obj.rectangle122 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle122:setParent(obj.layout113);
    obj.rectangle122:setAlign("client");
    obj.rectangle122:setColor("#272C36");
    obj.rectangle122:setXradius(5);
    obj.rectangle122:setYradius(15);
    obj.rectangle122:setCornerType("round");
    obj.rectangle122:setName("rectangle122");

    obj.label212 = GUI.fromHandle(_obj_newObject("label"));
    obj.label212:setParent(obj.rectangle122);
    obj.label212:setAlign("top");
    obj.label212:setHeight(20);
    obj.label212:setText("Anotações");
    obj.label212:setHorzTextAlign("center");
    obj.label212:setName("label212");
    obj.label212:setFontColor("white");

    obj.textEditor4 = GUI.fromHandle(_obj_newObject("textEditor"));
    obj.textEditor4:setParent(obj.rectangle122);
    obj.textEditor4:setAlign("client");
    obj.textEditor4:setField("anotacoes2");
    obj.textEditor4:setMargins({left=10,right=10,bottom=10});
    obj.textEditor4:setName("textEditor4");

    obj.layout114 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout114:setParent(obj.scrollBox4);
    obj.layout114:setAlign("left");
    obj.layout114:setWidth(400);
    obj.layout114:setMargins({right=10});
    obj.layout114:setName("layout114");

    obj.rectangle123 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle123:setParent(obj.layout114);
    obj.rectangle123:setAlign("client");
    obj.rectangle123:setColor("#272C36");
    obj.rectangle123:setXradius(5);
    obj.rectangle123:setYradius(15);
    obj.rectangle123:setCornerType("round");
    obj.rectangle123:setName("rectangle123");

    obj.label213 = GUI.fromHandle(_obj_newObject("label"));
    obj.label213:setParent(obj.rectangle123);
    obj.label213:setAlign("top");
    obj.label213:setHeight(20);
    obj.label213:setText("Anotações");
    obj.label213:setHorzTextAlign("center");
    obj.label213:setName("label213");
    obj.label213:setFontColor("white");

    obj.textEditor5 = GUI.fromHandle(_obj_newObject("textEditor"));
    obj.textEditor5:setParent(obj.rectangle123);
    obj.textEditor5:setAlign("client");
    obj.textEditor5:setField("anotacoes3");
    obj.textEditor5:setMargins({left=10,right=10,bottom=10});
    obj.textEditor5:setName("textEditor5");

    obj.tab6 = GUI.fromHandle(_obj_newObject("tab"));
    obj.tab6:setParent(obj.tabControl1);
    obj.tab6:setTitle("Creditos");
    obj.tab6:setName("tab6");

    obj.frmTemplateCreditos = GUI.fromHandle(_obj_newObject("form"));
    obj.frmTemplateCreditos:setParent(obj.tab6);
    obj.frmTemplateCreditos:setName("frmTemplateCreditos");
    obj.frmTemplateCreditos:setAlign("client");


		



			local function recursiveFindControls(node, controlsList)
				local children = node:getChildren();
				if node:getClassName() == "recordList" then
					children = rclKids(node);
					--write(children[1]:getClassName());

					children = rclKids(children[1]);
				end;
				for i=1, #children, 1 do
					controlsList[#controlsList+1] = children[i];
					recursiveFindControls(children[i], controlsList);
				end;
			end;

			function rclKids(rcl)
				local ret = {};
				local i;
				local childCount = _obj_getProp(rcl.handle, "ChildrenCount");
				local child;
				local childHandle;
				local idxDest = 1;
					
				for i = 0, childCount - 1, 1 do
					childHandle = _gui_getChild(rcl.handle, i);
					
					if (childHandle ~= nil) then							
						child = gui.fromHandle(childHandle);
						
						if (type(child) == "table") then							
							ret[idxDest] = child;
							idxDest = idxDest + 1;
						end
					end;	
				end
				
				return ret;
			end;

			local function findAllControls()
				local controlsList = {self};
				recursiveFindControls(self, controlsList);
				
				return controlsList;
			end;

			local function filterByClass(className, controls)
				local controlsFromClass = {};

				for i=1, #controls, 1 do
					if controls[i]:getClassName() == className then
						controlsFromClass[#controlsFromClass + 1] = controls[i];
					end;
				end;

				return controlsFromClass;
			end;

			local function findClass(className)
				local controls = findAllControls();
				return filterByClass(className, controls);
			end;

			-- Reaplica tema/cores salvos a partir de um root (usado no carregamento da ficha)
			function aplicarCoresDaemon(root, sheetNode)
				if root == nil or sheetNode == nil then return; end;
				if sheetNode.coresAtivas == false then return; end;

				local controls = {root};
				recursiveFindControls(root, controls);

				-- Tema
				local theme = sheetNode.theme;
				if theme == "Claro" then theme = "light"; else theme = "dark"; end;
				local forms = filterByClass("form", controls);
				for i=1, #forms, 1 do forms[i].theme = theme; end;

				-- Fundo e linhas (rectangles)
				local color = sheetNode.colorBackground or "#000000";
				local strokeColor = sheetNode.colorStroke or "#FFFFFF";
				local rectangles = filterByClass("rectangle", controls);
				for i=1, #rectangles, 1 do
					rectangles[i].color = color;
					rectangles[i].strokeColor = strokeColor;
				end;

				-- Fonte
				local fontColor = sheetNode.colorFont or "#FFFFFF";
				local classes = {"edit", "label", "comboBox", "textEditor", "checkBox", "button"};
				for c=1, #classes, 1 do
					local list = filterByClass(classes[c], controls);
					for i=1, #list, 1 do list[i].fontColor = fontColor; end;
				end;
			end;

		


	
	


    obj.scrollBox5 = GUI.fromHandle(_obj_newObject("scrollBox"));
    obj.scrollBox5:setParent(obj.frmTemplateCreditos);
    obj.scrollBox5:setAlign("client");
    obj.scrollBox5:setName("scrollBox5");

    obj.image21 = GUI.fromHandle(_obj_newObject("image"));
    obj.image21:setParent(obj.scrollBox5);
    obj.image21:setLeft(0);
    obj.image21:setTop(0);
    obj.image21:setWidth(250);
    obj.image21:setHeight(250);
    obj.image21:setStyle("autoFit");
    obj.image21:setSRC("/FichaDaemon/images/RPGmeister.jpg");
    obj.image21:setName("image21");

    obj.layout115 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout115:setParent(obj.scrollBox5);
    obj.layout115:setLeft(0);
    obj.layout115:setTop(260);
    obj.layout115:setWidth(200);
    obj.layout115:setHeight(160);
    obj.layout115:setName("layout115");

    obj.rectangle124 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle124:setParent(obj.layout115);
    obj.rectangle124:setAlign("client");
    obj.rectangle124:setColor("#272C36");
    obj.rectangle124:setXradius(5);
    obj.rectangle124:setYradius(15);
    obj.rectangle124:setCornerType("round");
    obj.rectangle124:setName("rectangle124");

    obj.label214 = GUI.fromHandle(_obj_newObject("label"));
    obj.label214:setParent(obj.rectangle124);
    obj.label214:setAlign("top");
    obj.label214:setHeight(20);
    obj.label214:setText("Plugin feito por: ");
    obj.label214:setHorzTextAlign("center");
    obj.label214:setMargins({top=5});
    obj.label214:setName("label214");
    obj.label214:setFontColor("white");

    obj.label215 = GUI.fromHandle(_obj_newObject("label"));
    obj.label215:setParent(obj.rectangle124);
    obj.label215:setAlign("top");
    obj.label215:setHeight(20);
    obj.label215:setText("Vinny (Ambesek)");
    obj.label215:setHorzTextAlign("center");
    obj.label215:setMargins({top=5});
    obj.label215:setName("label215");
    obj.label215:setFontColor("white");

    obj.label216 = GUI.fromHandle(_obj_newObject("label"));
    obj.label216:setParent(obj.rectangle124);
    obj.label216:setAlign("top");
    obj.label216:setHeight(20);
    obj.label216:setText("Consultores: ");
    obj.label216:setHorzTextAlign("center");
    obj.label216:setMargins({top=5});
    obj.label216:setName("label216");
    obj.label216:setFontColor("white");

    obj.label217 = GUI.fromHandle(_obj_newObject("label"));
    obj.label217:setParent(obj.rectangle124);
    obj.label217:setAlign("top");
    obj.label217:setHeight(20);
    obj.label217:setText("Mizuka");
    obj.label217:setHorzTextAlign("center");
    obj.label217:setMargins({top=5});
    obj.label217:setName("label217");
    obj.label217:setFontColor("white");

    obj.label218 = GUI.fromHandle(_obj_newObject("label"));
    obj.label218:setParent(obj.rectangle124);
    obj.label218:setAlign("top");
    obj.label218:setHeight(20);
    obj.label218:setText("Megas1200");
    obj.label218:setHorzTextAlign("center");
    obj.label218:setMargins({top=5});
    obj.label218:setName("label218");
    obj.label218:setFontColor("white");

    obj.layout116 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout116:setParent(obj.scrollBox5);
    obj.layout116:setLeft(0);
    obj.layout116:setTop(430);
    obj.layout116:setWidth(200);
    obj.layout116:setHeight(190);
    obj.layout116:setName("layout116");

    obj.rectangle125 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle125:setParent(obj.layout116);
    obj.rectangle125:setLeft(0);
    obj.rectangle125:setTop(0);
    obj.rectangle125:setWidth(200);
    obj.rectangle125:setHeight(190);
    obj.rectangle125:setColor("#272C36");
    obj.rectangle125:setName("rectangle125");

    obj.label219 = GUI.fromHandle(_obj_newObject("label"));
    obj.label219:setParent(obj.layout116);
    obj.label219:setLeft(0);
    obj.label219:setTop(10);
    obj.label219:setWidth(80);
    obj.label219:setHeight(20);
    obj.label219:setText("Tema:");
    obj.label219:setHorzTextAlign("center");
    obj.label219:setName("label219");
    obj.label219:setFontColor("white");

    obj.comboBox4 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox4:setParent(obj.layout116);
    obj.comboBox4:setLeft(95);
    obj.comboBox4:setTop(10);
    obj.comboBox4:setWidth(90);
    obj.comboBox4:setField("theme");
    obj.comboBox4:setFontColor("white");
    obj.comboBox4:setItems({'Escuro', 'Claro'});
    obj.comboBox4:setHorzTextAlign("center");
    obj.comboBox4:setName("comboBox4");

    obj.dataLink47 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink47:setParent(obj.layout116);
    obj.dataLink47:setField("theme");
    obj.dataLink47:setDefaultValue("Escuro");
    obj.dataLink47:setName("dataLink47");

    obj.label220 = GUI.fromHandle(_obj_newObject("label"));
    obj.label220:setParent(obj.layout116);
    obj.label220:setLeft(0);
    obj.label220:setTop(35);
    obj.label220:setWidth(90);
    obj.label220:setHeight(20);
    obj.label220:setText("Cores: ");
    obj.label220:setHorzTextAlign("center");
    obj.label220:setName("label220");
    obj.label220:setFontColor("white");

    obj.label221 = GUI.fromHandle(_obj_newObject("label"));
    obj.label221:setParent(obj.layout116);
    obj.label221:setLeft(0);
    obj.label221:setTop(60);
    obj.label221:setWidth(90);
    obj.label221:setHeight(20);
    obj.label221:setText("Fundo ");
    obj.label221:setHorzTextAlign("center");
    obj.label221:setName("label221");
    obj.label221:setFontColor("white");

    obj.comboBox5 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox5:setParent(obj.layout116);
    obj.comboBox5:setLeft(95);
    obj.comboBox5:setTop(60);
    obj.comboBox5:setWidth(90);
    obj.comboBox5:setField("colorBackground");
    obj.comboBox5:setItems({'AliceBlue', 'AntiqueWhite', 'Aqua', 'Aquamarine', 'Azure', 'Beige', 'Bisque', 'Black', 'BlanchedAlmond', 'Blue', 'BlueViolet', 'Brown', 'BurlyWood', 'CadetBlue', 'Chartreuse', 'Chocolate', 'Coral', 'CornflowerBlue', 'Cornsilk', 'Crimson', 'Cyan', 'DarkBlue', 'DarkCyan', 'DarkGoldenRod', 'DarkGray', 'DarkGreen', 'DarkKhaki', 'DarkMagenta', 'DarkOliveGreen', 'DarkOrange', 'DarkOrchid', 'DarkRed', 'DarkSalmon', 'DarkSeaGreen', 'DarkSlateBlue', 'DarkSlateGray', 'DarkTurquoise', 'DarkViolet', 'DeepPink', 'DeepSkyBlue', 'DimGray', 'DodgerBlue', 'FireBrick', 'FloralWhite', 'ForestGreen', 'Fuchsia', 'Gainsboro', 'GhostWhite', 'Gold', 'GoldenRod', 'Gray', 'Green', 'GreenYellow', 'HoneyDew', 'HotPink', 'IndianRed ', 'Indigo ', 'Ivory', 'Khaki', 'Lavender', 'LavenderBlush', 'LawnGreen', 'LemonChiffon', 'LightBlue', 'LightCoral', 'LightCyan', 'LightGoldenRodYellow', 'LightGray', 'LightGreen', 'LightPink', 'LightSalmon', 'LightSeaGreen', 'LightSkyBlue', 'LightSlateGray', 'LightSteelBlue', 'LightYellow', 'Lime', 'LimeGreen', 'Linen', 'Magenta', 'Maroon', 'MediumAquaMarine', 'MediumBlue', 'MediumOrchid', 'MediumPurple', 'MediumSeaGreen', 'MediumSlateBlue', 'MediumSpringGreen', 'MediumTurquoise', 'MediumVioletRed', 'MidnightBlue', 'MintCream', 'MistyRose', 'Moccasin', 'NavajoWhite', 'Navy', 'OldLace', 'Olive', 'OliveDrab', 'Orange', 'OrangeRed', 'Orchid', 'PaleGoldenRod', 'PaleGreen', 'PaleTurquoise', 'PaleVioletRed', 'PapayaWhip', 'PeachPuff', 'Peru', 'Pink', 'Plum', 'PowderBlue', 'Purple', 'RebeccaPurple', 'Red', 'RosyBrown', 'RoyalBlue', 'SaddleBrown', 'Salmon', 'SandyBrown', 'SeaGreen', 'SeaShell', 'Sienna', 'Silver', 'SkyBlue', 'SlateBlue', 'SlateGray', 'Snow', 'SpringGreen', 'SteelBlue', 'Tan', 'Teal', 'Thistle', 'Tomato', 'Turquoise', 'Violet', 'Wheat', 'White', 'WhiteSmoke', 'Yellow', 'YellowGreen'});
    obj.comboBox5:setValues({'#F0F8FF', '#FAEBD7', '#00FFFF', '#7FFFD4', '#F0FFFF', '#F5F5DC', '#FFE4C4', '#000000', '#FFEBCD', '#0000FF', '#8A2BE2', '#A52A2A', '#DEB887', '#5F9EA0', '#7FFF00', '#D2691E', '#FF7F50', '#6495ED', '#FFF8DC', '#DC143C', '#00FFFF', '#00008B', '#008B8B', '#B8860B', '#A9A9A9', '#006400', '#BDB76B', '#8B008B', '#556B2F', '#FF8C00', '#9932CC', '#8B0000', '#E9967A', '#8FBC8F', '#483D8B', '#2F4F4F', '#00CED1', '#9400D3', '#FF1493', '#00BFFF', '#696969', '#1E90FF', '#B22222', '#FFFAF0', '#228B22', '#FF00FF', '#DCDCDC', '#F8F8FF', '#FFD700', '#DAA520', '#808080', '#008000', '#ADFF2F', '#F0FFF0', '#FF69B4', '#CD5C5C', '#4B0082', '#FFFFF0', '#F0E68C', '#E6E6FA', '#FFF0F5', '#7CFC00', '#FFFACD', '#ADD8E6', '#F08080', '#E0FFFF', '#FAFAD2', '#D3D3D3', '#90EE90', '#FFB6C1', '#FFA07A', '#20B2AA', '#87CEFA', '#778899', '#B0C4DE', '#FFFFE0', '#00FF00', '#32CD32', '#FAF0E6', '#FF00FF', '#800000', '#66CDAA', '#0000CD', '#BA55D3', '#9370DB', '#3CB371', '#7B68EE', '#00FA9A', '#48D1CC', '#C71585', '#191970', '#F5FFFA', '#FFE4E1', '#FFE4B5', '#FFDEAD', '#000080', '#FDF5E6', '#808000', '#6B8E23', '#FFA500', '#FF4500', '#DA70D6', '#EEE8AA', '#98FB98', '#AFEEEE', '#DB7093', '#FFEFD5', '#FFDAB9', '#CD853F', '#FFC0CB', '#DDA0DD', '#B0E0E6', '#800080', '#663399', '#FF0000', '#BC8F8F', '#4169E1', '#8B4513', '#FA8072', '#F4A460', '#2E8B57', '#FFF5EE', '#A0522D', '#C0C0C0', '#87CEEB', '#6A5ACD', '#708090', '#FFFAFA', '#00FF7F', '#4682B4', '#D2B48C', '#008080', '#D8BFD8', '#FF6347', '#40E0D0', '#EE82EE', '#F5DEB3', '#FFFFFF', '#F5F5F5', '#FFFF00', '#9ACD32'});
    obj.comboBox5:setName("comboBox5");

    obj.dataLink48 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink48:setParent(obj.layout116);
    obj.dataLink48:setField("colorBackground");
    obj.dataLink48:setDefaultValue("#000000");
    obj.dataLink48:setName("dataLink48");

    obj.label222 = GUI.fromHandle(_obj_newObject("label"));
    obj.label222:setParent(obj.layout116);
    obj.label222:setLeft(0);
    obj.label222:setTop(85);
    obj.label222:setWidth(90);
    obj.label222:setHeight(20);
    obj.label222:setText("Linhas ");
    obj.label222:setHorzTextAlign("center");
    obj.label222:setName("label222");
    obj.label222:setFontColor("white");

    obj.comboBox6 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox6:setParent(obj.layout116);
    obj.comboBox6:setLeft(95);
    obj.comboBox6:setTop(85);
    obj.comboBox6:setWidth(90);
    obj.comboBox6:setField("colorStroke");
    obj.comboBox6:setItems({'AliceBlue', 'AntiqueWhite', 'Aqua', 'Aquamarine', 'Azure', 'Beige', 'Bisque', 'Black', 'BlanchedAlmond', 'Blue', 'BlueViolet', 'Brown', 'BurlyWood', 'CadetBlue', 'Chartreuse', 'Chocolate', 'Coral', 'CornflowerBlue', 'Cornsilk', 'Crimson', 'Cyan', 'DarkBlue', 'DarkCyan', 'DarkGoldenRod', 'DarkGray', 'DarkGreen', 'DarkKhaki', 'DarkMagenta', 'DarkOliveGreen', 'DarkOrange', 'DarkOrchid', 'DarkRed', 'DarkSalmon', 'DarkSeaGreen', 'DarkSlateBlue', 'DarkSlateGray', 'DarkTurquoise', 'DarkViolet', 'DeepPink', 'DeepSkyBlue', 'DimGray', 'DodgerBlue', 'FireBrick', 'FloralWhite', 'ForestGreen', 'Fuchsia', 'Gainsboro', 'GhostWhite', 'Gold', 'GoldenRod', 'Gray', 'Green', 'GreenYellow', 'HoneyDew', 'HotPink', 'IndianRed ', 'Indigo ', 'Ivory', 'Khaki', 'Lavender', 'LavenderBlush', 'LawnGreen', 'LemonChiffon', 'LightBlue', 'LightCoral', 'LightCyan', 'LightGoldenRodYellow', 'LightGray', 'LightGreen', 'LightPink', 'LightSalmon', 'LightSeaGreen', 'LightSkyBlue', 'LightSlateGray', 'LightSteelBlue', 'LightYellow', 'Lime', 'LimeGreen', 'Linen', 'Magenta', 'Maroon', 'MediumAquaMarine', 'MediumBlue', 'MediumOrchid', 'MediumPurple', 'MediumSeaGreen', 'MediumSlateBlue', 'MediumSpringGreen', 'MediumTurquoise', 'MediumVioletRed', 'MidnightBlue', 'MintCream', 'MistyRose', 'Moccasin', 'NavajoWhite', 'Navy', 'OldLace', 'Olive', 'OliveDrab', 'Orange', 'OrangeRed', 'Orchid', 'PaleGoldenRod', 'PaleGreen', 'PaleTurquoise', 'PaleVioletRed', 'PapayaWhip', 'PeachPuff', 'Peru', 'Pink', 'Plum', 'PowderBlue', 'Purple', 'RebeccaPurple', 'Red', 'RosyBrown', 'RoyalBlue', 'SaddleBrown', 'Salmon', 'SandyBrown', 'SeaGreen', 'SeaShell', 'Sienna', 'Silver', 'SkyBlue', 'SlateBlue', 'SlateGray', 'Snow', 'SpringGreen', 'SteelBlue', 'Tan', 'Teal', 'Thistle', 'Tomato', 'Turquoise', 'Violet', 'Wheat', 'White', 'WhiteSmoke', 'Yellow', 'YellowGreen'});
    obj.comboBox6:setValues({'#F0F8FF', '#FAEBD7', '#00FFFF', '#7FFFD4', '#F0FFFF', '#F5F5DC', '#FFE4C4', '#000000', '#FFEBCD', '#0000FF', '#8A2BE2', '#A52A2A', '#DEB887', '#5F9EA0', '#7FFF00', '#D2691E', '#FF7F50', '#6495ED', '#FFF8DC', '#DC143C', '#00FFFF', '#00008B', '#008B8B', '#B8860B', '#A9A9A9', '#006400', '#BDB76B', '#8B008B', '#556B2F', '#FF8C00', '#9932CC', '#8B0000', '#E9967A', '#8FBC8F', '#483D8B', '#2F4F4F', '#00CED1', '#9400D3', '#FF1493', '#00BFFF', '#696969', '#1E90FF', '#B22222', '#FFFAF0', '#228B22', '#FF00FF', '#DCDCDC', '#F8F8FF', '#FFD700', '#DAA520', '#808080', '#008000', '#ADFF2F', '#F0FFF0', '#FF69B4', '#CD5C5C', '#4B0082', '#FFFFF0', '#F0E68C', '#E6E6FA', '#FFF0F5', '#7CFC00', '#FFFACD', '#ADD8E6', '#F08080', '#E0FFFF', '#FAFAD2', '#D3D3D3', '#90EE90', '#FFB6C1', '#FFA07A', '#20B2AA', '#87CEFA', '#778899', '#B0C4DE', '#FFFFE0', '#00FF00', '#32CD32', '#FAF0E6', '#FF00FF', '#800000', '#66CDAA', '#0000CD', '#BA55D3', '#9370DB', '#3CB371', '#7B68EE', '#00FA9A', '#48D1CC', '#C71585', '#191970', '#F5FFFA', '#FFE4E1', '#FFE4B5', '#FFDEAD', '#000080', '#FDF5E6', '#808000', '#6B8E23', '#FFA500', '#FF4500', '#DA70D6', '#EEE8AA', '#98FB98', '#AFEEEE', '#DB7093', '#FFEFD5', '#FFDAB9', '#CD853F', '#FFC0CB', '#DDA0DD', '#B0E0E6', '#800080', '#663399', '#FF0000', '#BC8F8F', '#4169E1', '#8B4513', '#FA8072', '#F4A460', '#2E8B57', '#FFF5EE', '#A0522D', '#C0C0C0', '#87CEEB', '#6A5ACD', '#708090', '#FFFAFA', '#00FF7F', '#4682B4', '#D2B48C', '#008080', '#D8BFD8', '#FF6347', '#40E0D0', '#EE82EE', '#F5DEB3', '#FFFFFF', '#F5F5F5', '#FFFF00', '#9ACD32'});
    obj.comboBox6:setName("comboBox6");

    obj.dataLink49 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink49:setParent(obj.layout116);
    obj.dataLink49:setField("colorStroke");
    obj.dataLink49:setDefaultValue("#FFFFFF");
    obj.dataLink49:setName("dataLink49");

    obj.label223 = GUI.fromHandle(_obj_newObject("label"));
    obj.label223:setParent(obj.layout116);
    obj.label223:setLeft(0);
    obj.label223:setTop(110);
    obj.label223:setWidth(90);
    obj.label223:setHeight(20);
    obj.label223:setText("Fonte ");
    obj.label223:setHorzTextAlign("center");
    obj.label223:setName("label223");
    obj.label223:setFontColor("white");

    obj.comboBox7 = GUI.fromHandle(_obj_newObject("comboBox"));
    obj.comboBox7:setParent(obj.layout116);
    obj.comboBox7:setLeft(95);
    obj.comboBox7:setTop(110);
    obj.comboBox7:setWidth(90);
    obj.comboBox7:setField("colorFont");
    obj.comboBox7:setItems({'AliceBlue', 'AntiqueWhite', 'Aqua', 'Aquamarine', 'Azure', 'Beige', 'Bisque', 'Black', 'BlanchedAlmond', 'Blue', 'BlueViolet', 'Brown', 'BurlyWood', 'CadetBlue', 'Chartreuse', 'Chocolate', 'Coral', 'CornflowerBlue', 'Cornsilk', 'Crimson', 'Cyan', 'DarkBlue', 'DarkCyan', 'DarkGoldenRod', 'DarkGray', 'DarkGreen', 'DarkKhaki', 'DarkMagenta', 'DarkOliveGreen', 'DarkOrange', 'DarkOrchid', 'DarkRed', 'DarkSalmon', 'DarkSeaGreen', 'DarkSlateBlue', 'DarkSlateGray', 'DarkTurquoise', 'DarkViolet', 'DeepPink', 'DeepSkyBlue', 'DimGray', 'DodgerBlue', 'FireBrick', 'FloralWhite', 'ForestGreen', 'Fuchsia', 'Gainsboro', 'GhostWhite', 'Gold', 'GoldenRod', 'Gray', 'Green', 'GreenYellow', 'HoneyDew', 'HotPink', 'IndianRed ', 'Indigo ', 'Ivory', 'Khaki', 'Lavender', 'LavenderBlush', 'LawnGreen', 'LemonChiffon', 'LightBlue', 'LightCoral', 'LightCyan', 'LightGoldenRodYellow', 'LightGray', 'LightGreen', 'LightPink', 'LightSalmon', 'LightSeaGreen', 'LightSkyBlue', 'LightSlateGray', 'LightSteelBlue', 'LightYellow', 'Lime', 'LimeGreen', 'Linen', 'Magenta', 'Maroon', 'MediumAquaMarine', 'MediumBlue', 'MediumOrchid', 'MediumPurple', 'MediumSeaGreen', 'MediumSlateBlue', 'MediumSpringGreen', 'MediumTurquoise', 'MediumVioletRed', 'MidnightBlue', 'MintCream', 'MistyRose', 'Moccasin', 'NavajoWhite', 'Navy', 'OldLace', 'Olive', 'OliveDrab', 'Orange', 'OrangeRed', 'Orchid', 'PaleGoldenRod', 'PaleGreen', 'PaleTurquoise', 'PaleVioletRed', 'PapayaWhip', 'PeachPuff', 'Peru', 'Pink', 'Plum', 'PowderBlue', 'Purple', 'RebeccaPurple', 'Red', 'RosyBrown', 'RoyalBlue', 'SaddleBrown', 'Salmon', 'SandyBrown', 'SeaGreen', 'SeaShell', 'Sienna', 'Silver', 'SkyBlue', 'SlateBlue', 'SlateGray', 'Snow', 'SpringGreen', 'SteelBlue', 'Tan', 'Teal', 'Thistle', 'Tomato', 'Turquoise', 'Violet', 'Wheat', 'White', 'WhiteSmoke', 'Yellow', 'YellowGreen'});
    obj.comboBox7:setValues({'#F0F8FF', '#FAEBD7', '#00FFFF', '#7FFFD4', '#F0FFFF', '#F5F5DC', '#FFE4C4', '#000000', '#FFEBCD', '#0000FF', '#8A2BE2', '#A52A2A', '#DEB887', '#5F9EA0', '#7FFF00', '#D2691E', '#FF7F50', '#6495ED', '#FFF8DC', '#DC143C', '#00FFFF', '#00008B', '#008B8B', '#B8860B', '#A9A9A9', '#006400', '#BDB76B', '#8B008B', '#556B2F', '#FF8C00', '#9932CC', '#8B0000', '#E9967A', '#8FBC8F', '#483D8B', '#2F4F4F', '#00CED1', '#9400D3', '#FF1493', '#00BFFF', '#696969', '#1E90FF', '#B22222', '#FFFAF0', '#228B22', '#FF00FF', '#DCDCDC', '#F8F8FF', '#FFD700', '#DAA520', '#808080', '#008000', '#ADFF2F', '#F0FFF0', '#FF69B4', '#CD5C5C', '#4B0082', '#FFFFF0', '#F0E68C', '#E6E6FA', '#FFF0F5', '#7CFC00', '#FFFACD', '#ADD8E6', '#F08080', '#E0FFFF', '#FAFAD2', '#D3D3D3', '#90EE90', '#FFB6C1', '#FFA07A', '#20B2AA', '#87CEFA', '#778899', '#B0C4DE', '#FFFFE0', '#00FF00', '#32CD32', '#FAF0E6', '#FF00FF', '#800000', '#66CDAA', '#0000CD', '#BA55D3', '#9370DB', '#3CB371', '#7B68EE', '#00FA9A', '#48D1CC', '#C71585', '#191970', '#F5FFFA', '#FFE4E1', '#FFE4B5', '#FFDEAD', '#000080', '#FDF5E6', '#808000', '#6B8E23', '#FFA500', '#FF4500', '#DA70D6', '#EEE8AA', '#98FB98', '#AFEEEE', '#DB7093', '#FFEFD5', '#FFDAB9', '#CD853F', '#FFC0CB', '#DDA0DD', '#B0E0E6', '#800080', '#663399', '#FF0000', '#BC8F8F', '#4169E1', '#8B4513', '#FA8072', '#F4A460', '#2E8B57', '#FFF5EE', '#A0522D', '#C0C0C0', '#87CEEB', '#6A5ACD', '#708090', '#FFFAFA', '#00FF7F', '#4682B4', '#D2B48C', '#008080', '#D8BFD8', '#FF6347', '#40E0D0', '#EE82EE', '#F5DEB3', '#FFFFFF', '#F5F5F5', '#FFFF00', '#9ACD32'});
    obj.comboBox7:setName("comboBox7");

    obj.dataLink50 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink50:setParent(obj.layout116);
    obj.dataLink50:setField("colorFont");
    obj.dataLink50:setDefaultValue("#FFFFFF");
    obj.dataLink50:setName("dataLink50");

    obj.checkBox1 = GUI.fromHandle(_obj_newObject("checkBox"));
    obj.checkBox1:setParent(obj.layout116);
    obj.checkBox1:setLeft(10);
    obj.checkBox1:setTop(145);
    obj.checkBox1:setWidth(180);
    obj.checkBox1:setHeight(20);
    obj.checkBox1:setField("coresAtivas");
    obj.checkBox1:setText("Controle de cores ativo");
    obj.checkBox1:setFontColor("white");
    obj.checkBox1:setName("checkBox1");

    obj.dataLink51 = GUI.fromHandle(_obj_newObject("dataLink"));
    obj.dataLink51:setParent(obj.layout116);
    obj.dataLink51:setField("coresAtivas");
    obj.dataLink51:setDefaultValue("false");
    obj.dataLink51:setName("dataLink51");

    obj.label224 = GUI.fromHandle(_obj_newObject("label"));
    obj.label224:setParent(obj.scrollBox5);
    obj.label224:setLeft(300);
    obj.label224:setTop(0);
    obj.label224:setWidth(200);
    obj.label224:setHeight(20);
    obj.label224:setText("");
    obj.label224:setHorzTextAlign("center");
    obj.label224:setField("versionInstalled");
    obj.label224:setName("label224");
    obj.label224:setFontColor("white");

    obj.label225 = GUI.fromHandle(_obj_newObject("label"));
    obj.label225:setParent(obj.scrollBox5);
    obj.label225:setLeft(300);
    obj.label225:setTop(25);
    obj.label225:setWidth(200);
    obj.label225:setHeight(20);
    obj.label225:setText("");
    obj.label225:setHorzTextAlign("center");
    obj.label225:setField("versionDownloaded");
    obj.label225:setName("label225");
    obj.label225:setFontColor("white");

    obj.checkBox2 = GUI.fromHandle(_obj_newObject("checkBox"));
    obj.checkBox2:setParent(obj.scrollBox5);
    obj.checkBox2:setLeft(300);
    obj.checkBox2:setTop(50);
    obj.checkBox2:setWidth(200);
    obj.checkBox2:setHeight(20);
    obj.checkBox2:setField("noUpdate");
    obj.checkBox2:setText("Não pedir para atualizar.");
    obj.checkBox2:setName("checkBox2");

    obj.button17 = GUI.fromHandle(_obj_newObject("button"));
    obj.button17:setParent(obj.scrollBox5);
    obj.button17:setLeft(300);
    obj.button17:setTop(75);
    obj.button17:setWidth(100);
    obj.button17:setText("Change Log");
    obj.button17:setName("button17");

    obj.button18 = GUI.fromHandle(_obj_newObject("button"));
    obj.button18:setParent(obj.scrollBox5);
    obj.button18:setLeft(410);
    obj.button18:setTop(75);
    obj.button18:setWidth(100);
    obj.button18:setText("Atualizar");
    obj.button18:setName("button18");

    obj.label226 = GUI.fromHandle(_obj_newObject("label"));
    obj.label226:setParent(obj.scrollBox5);
    obj.label226:setLeft(300);
    obj.label226:setTop(125);
    obj.label226:setWidth(200);
    obj.label226:setHeight(20);
    obj.label226:setText("Conheça as Mesas:");
    obj.label226:setName("label226");
    obj.label226:setFontColor("white");

    obj.button19 = GUI.fromHandle(_obj_newObject("button"));
    obj.button19:setParent(obj.scrollBox5);
    obj.button19:setLeft(300);
    obj.button19:setTop(150);
    obj.button19:setWidth(100);
    obj.button19:setText("RPGmeister");
    obj.button19:setName("button19");

    obj.button20 = GUI.fromHandle(_obj_newObject("button"));
    obj.button20:setParent(obj.scrollBox5);
    obj.button20:setLeft(410);
    obj.button20:setTop(150);
    obj.button20:setWidth(100);
    obj.button20:setText("Mizukage");
    obj.button20:setName("button20");

    obj.button21 = GUI.fromHandle(_obj_newObject("button"));
    obj.button21:setParent(obj.scrollBox5);
    obj.button21:setLeft(300);
    obj.button21:setTop(200);
    obj.button21:setWidth(100);
    obj.button21:setHeight(20);
    obj.button21:setText("Exportar Ficha");
    obj.button21:setName("button21");

    obj.button22 = GUI.fromHandle(_obj_newObject("button"));
    obj.button22:setParent(obj.scrollBox5);
    obj.button22:setLeft(410);
    obj.button22:setTop(200);
    obj.button22:setWidth(100);
    obj.button22:setHeight(20);
    obj.button22:setText("Importar Ficha");
    obj.button22:setName("button22");

    obj.label227 = GUI.fromHandle(_obj_newObject("label"));
    obj.label227:setParent(obj.scrollBox5);
    obj.label227:setLeft(300);
    obj.label227:setTop(240);
    obj.label227:setWidth(500);
    obj.label227:setHeight(20);
    obj.label227:setText("Creditos de icones:");
    obj.label227:setHorzTextAlign("leading");
    obj.label227:setName("label227");
    obj.label227:setFontColor("white");

    obj.label228 = GUI.fromHandle(_obj_newObject("label"));
    obj.label228:setParent(obj.scrollBox5);
    obj.label228:setLeft(300);
    obj.label228:setTop(262);
    obj.label228:setWidth(600);
    obj.label228:setHeight(20);
    obj.label228:setText("Icone do escudo (Resistido): Flaticon - www.flaticon.com");
    obj.label228:setHorzTextAlign("leading");
    obj.label228:setName("label228");
    obj.label228:setFontColor("white");

    obj._e_event0 = obj:addEventListener("onNodeReady",
        function ()
            -- auto-update desativado (evita baixar a versao oficial do GitHub e conflitar com o build local)
                    -- versao exibida na aba Creditos (estatica, sem fetch remoto)
                    sheet.versionInstalled = "Versão Instalada: 2.0"
                    sheet.versionDownloaded = "Versão Disponível: 2.0"
                    -- reaplica tema/cores salvos ao abrir a ficha (senao volta ao padrao do XML)
                    if aplicarCoresDaemon ~= nil then
                        aplicarCoresDaemon(self, sheet);
                    end;
        end);

    obj._e_event1 = obj.dataLink1:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
                        if sheet.roll then
                            sheet.roll = false
                            AskToRoll()
                        end
        end);

    obj._e_event2 = obj.button1:addEventListener("onClick",
        function (event)
            aplicarRaca()
        end);

    obj._e_event3 = obj.button2:addEventListener("onClick",
        function (event)
            aplicarKit()
        end);

    obj._e_event4 = obj.cbxAtribResist:addEventListener("onMouseEnter",
        function ()
            self.cbxAtribResist.opacity = 1;
        end);

    obj._e_event5 = obj.cbxAtribResist:addEventListener("onMouseLeave",
        function ()
            self.cbxAtribResist.opacity = 0.55;
        end);

    obj._e_event6 = obj.button3:addEventListener("onClick",
        function (event)
            sheet.rollText = "Constituição"
            				sheet.rollValue = tonumber(sheet.constituicaoPerc) or 0
            				RolarAtributo()
        end);

    obj._e_event7 = obj.dataLink3:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local base = (tonumber(sheet.constituicaoBase) or 0)
            				local mod = (tonumber(sheet.constituicaoMod) or 0)
            				local out = (tonumber(sheet.constituicaoOut) or 0)
            				local total = (mod + base + out)
            				sheet.constituicaoPerc = total * 4
            				sheet.constituicaoTotal = total
            
            	            local nodes = NDB.getChildNodes(sheet.periciasArmas); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].constituicao = total
            	            end
            
            	            nodes = NDB.getChildNodes(sheet.pericias); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].constituicao = total
            	            end
        end);

    obj._e_event8 = obj.button4:addEventListener("onClick",
        function (event)
            sheet.rollText = "Força"
            				sheet.rollValue = tonumber(sheet.forcaPerc) or 0
            				RolarAtributo()
        end);

    obj._e_event9 = obj.dataLink4:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local base = (tonumber(sheet.forcaBase) or 0)
            				local mod = (tonumber(sheet.forcaMod) or 0)
            				local out = (tonumber(sheet.forcaOut) or 0)
            				local total = (mod + base + out)
            				sheet.forcaPerc = total * 4
            				sheet.forcaTotal = total
            
            	            local nodes = NDB.getChildNodes(sheet.periciasArmas); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].forca = total
            	            end
            
            	            nodes = NDB.getChildNodes(sheet.pericias); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].forca = total
            	            end
        end);

    obj._e_event10 = obj.button5:addEventListener("onClick",
        function (event)
            sheet.rollText = "Destreza"
            				sheet.rollValue = tonumber(sheet.destrezaPerc) or 0
            				RolarAtributo()
        end);

    obj._e_event11 = obj.dataLink5:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local base = (tonumber(sheet.destrezaBase) or 0)
            				local mod = (tonumber(sheet.destrezaMod) or 0)
            				local out = (tonumber(sheet.destrezaOut) or 0)
            				local total = (mod + base + out)
            				sheet.destrezaPerc = total * 4
            				sheet.destrezaTotal = total
            
            	            local nodes = NDB.getChildNodes(sheet.periciasArmas); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].destreza = total
            	            end
            
            	            nodes = NDB.getChildNodes(sheet.pericias); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].destreza = total
            	            end
        end);

    obj._e_event12 = obj.button6:addEventListener("onClick",
        function (event)
            sheet.rollText = "Agilidade"
            				sheet.rollValue = tonumber(sheet.agilidadePerc) or 0
            				RolarAtributo()
        end);

    obj._e_event13 = obj.dataLink6:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local base = (tonumber(sheet.agilidadeBase) or 0)
            				local mod = (tonumber(sheet.agilidadeMod) or 0)
            				local out = (tonumber(sheet.agilidadeOut) or 0)
            				local total = (mod + base + out)
            				sheet.agilidadePerc = total * 4
            				sheet.agilidadeTotal = total
            
            	            local nodes = NDB.getChildNodes(sheet.periciasArmas); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].agilidade = total
            	            end
            
            	            nodes = NDB.getChildNodes(sheet.pericias); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].agilidade = total
            	            end
        end);

    obj._e_event14 = obj.button7:addEventListener("onClick",
        function (event)
            sheet.rollText = "Inteligência"
            				sheet.rollValue = tonumber(sheet.inteligenciaPerc) or 0
            				RolarAtributo()
        end);

    obj._e_event15 = obj.dataLink7:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local base = (tonumber(sheet.inteligenciaBase) or 0)
            				local mod = (tonumber(sheet.inteligenciaMod) or 0)
            				local out = (tonumber(sheet.inteligenciaOut) or 0)
            				local total = (mod + base + out)
            				sheet.inteligenciaPerc = total * 4
            				sheet.inteligenciaTotal = total
            
            	            local nodes = NDB.getChildNodes(sheet.periciasArmas); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].inteligencia = total
            	            end
            
            	            nodes = NDB.getChildNodes(sheet.pericias); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].inteligencia = total
            	            end
        end);

    obj._e_event16 = obj.button8:addEventListener("onClick",
        function (event)
            sheet.rollText = "Força de Vontade"
            				sheet.rollValue = tonumber(sheet.vontadePerc) or 0
            				RolarAtributo()
        end);

    obj._e_event17 = obj.dataLink8:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local base = (tonumber(sheet.vontadeBase) or 0)
            				local mod = (tonumber(sheet.vontadeMod) or 0)
            				local out = (tonumber(sheet.vontadeOut) or 0)
            				local total = (mod + base + out)
            				sheet.vontadePerc = total * 4
            				sheet.vontadeTotal = total
            
            	            local nodes = NDB.getChildNodes(sheet.periciasArmas); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].vontade = total
            	            end
            
            	            nodes = NDB.getChildNodes(sheet.pericias); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].vontade = total
            	            end
        end);

    obj._e_event18 = obj.button9:addEventListener("onClick",
        function (event)
            sheet.rollText = "Percepção"
            				sheet.rollValue = tonumber(sheet.percepcaoPerc) or 0
            				RolarAtributo()
        end);

    obj._e_event19 = obj.dataLink9:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local base = (tonumber(sheet.percepcaoBase) or 0)
            				local mod = (tonumber(sheet.percepcaoMod) or 0)
            				local out = (tonumber(sheet.percepcaoOut) or 0)
            				local total = (mod + base + out)
            				sheet.percepcaoPerc = total * 4
            				sheet.percepcaoTotal = total
            
            	            local nodes = NDB.getChildNodes(sheet.periciasArmas); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].percepcao = total
            	            end
            
            	            nodes = NDB.getChildNodes(sheet.pericias); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].percepcao = total
            	            end
        end);

    obj._e_event20 = obj.button10:addEventListener("onClick",
        function (event)
            sheet.rollText = "Carisma"
            				sheet.rollValue = tonumber(sheet.carismaPerc) or 0
            				RolarAtributo()
        end);

    obj._e_event21 = obj.dataLink10:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local base = (tonumber(sheet.carismaBase) or 0)
            				local mod = (tonumber(sheet.carismaMod) or 0)
            				local out = (tonumber(sheet.carismaOut) or 0)
            				local total = (mod + base + out)
            				sheet.carismaPerc = total * 4
            				sheet.carismaTotal = total
            
            	            local nodes = NDB.getChildNodes(sheet.periciasArmas); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].carisma = total
            	            end
            
            	            nodes = NDB.getChildNodes(sheet.pericias); 
            	            for i=1, #nodes, 1 do
            	                nodes[i].carisma = total
            	            end
        end);

    obj._e_event22 = obj.button11:addEventListener("onClick",
        function (event)
            local mesa = rrpg.getMesaDe(sheet);                     
            
            			                    mesa.activeChat:rolarDados("1d10+"..(tonumber(sheet.iniciativa) or 0), "Iniciativa")
        end);

    obj._e_event23 = obj.dataLink11:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            								local bonus = (tonumber(sheet.iniciativaBonus) or 0)
            								local total = ((tonumber(sheet.agilidadeBase) or 0) + (tonumber(sheet.agilidadeMod) or 0) + (tonumber(sheet.agilidadeOut) or 0))
            								sheet.iniciativa = (bonus + total)
        end);

    obj._e_event24 = obj.dataLink12:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            							
            							local atrs = {"constituicao","forca","destreza","agilidade","inteligencia","vontade","percepcao","carisma"}
            							local pts = 0
            							for i,v in ipairs(atrs) do
            								pts = pts + (tonumber(sheet[v.."Base"]) or 0)
            							end
            							sheet.ptsAtributos = pts
        end);

    obj._e_event25 = obj.dataLink13:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            							sheet.ptsAtribDisp = (100 + (tonumber(sheet.level) or 0)) - (tonumber(sheet.ptsAtributos) or 0)
        end);

    obj._e_event26 = obj.dataLink14:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            							
            							local atrs = {"ptsPericiasArmas","ptsPericias"}
            							local pts = 0
            							for i,v in ipairs(atrs) do
            								pts = pts + (tonumber(sheet[v]) or 0)
            							end
            							sheet.ptsPericiasTotais = pts
        end);

    obj._e_event27 = obj.dataLink15:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            								local int = (tonumber(sheet.inteligenciaBase) or 0) + (tonumber(sheet.inteligenciaMod) or 0) + (tonumber(sheet.inteligenciaOut) or 0)
            								local teto = 10 * (tonumber(sheet.idade) or 0) + 5 * int
            								if teto > 500 then teto = 500 end
            								teto = teto + 25 * (tonumber(sheet.level) or 0)
            								local gasto = (tonumber(sheet.ptsPericias) or 0) + (tonumber(sheet.ptsPericiasArmas) or 0) + (tonumber(sheet.ptsKitPericia) or 0)
            								sheet.ptsPericiaDisp = teto - gasto
        end);

    obj._e_event28 = obj.dataLink16:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            								local lv = tonumber(sheet.level) or 0
            								local bonus = 0
            								if lv >= 3 then bonus = math.floor((lv - 1) / 2) end
            								sheet.ptsAprimDisp = (5 + bonus) - (tonumber(sheet.ptsKitAprim) or 0) - (tonumber(sheet.ptsAprimoramentos) or 0)
            								sheet.ptsAprimGasto = (tonumber(sheet.ptsAprimoramentos) or 0) + (tonumber(sheet.ptsKitAprim) or 0)
        end);

    obj._e_event29 = obj.button12:addEventListener("onClick",
        function (event)
            self.aprimoramentos:append();
        end);

    obj._e_event30 = obj.aprimoramentos:addEventListener("onCompare",
        function (nodeA, nodeB)
            return utils.compareStringPtBr(nodeA.nome, nodeB.nome)
        end);

    obj._e_event31 = obj.button13:addEventListener("onClick",
        function (event)
            self.poderes:append();
        end);

    obj._e_event32 = obj.poderes:addEventListener("onCompare",
        function (nodeA, nodeB)
            return utils.compareStringPtBr(nodeA.nome, nodeB.nome)
        end);

    obj._e_event33 = obj.image11:addEventListener("onStartDrag",
        function (drag, x, y, event)
            drag:addData("imageURL", sheet.avatar);
        end);

    obj._e_event34 = obj.dataLink17:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            								local con = (tonumber(sheet.constituicaoBase) or 0) + (tonumber(sheet.constituicaoMod) or 0) + (tonumber(sheet.constituicaoOut) or 0)
            								local forca = (tonumber(sheet.forcaBase) or 0) + (tonumber(sheet.forcaMod) or 0) + (tonumber(sheet.forcaOut) or 0)
            								sheet.pvTotal = math.ceil((con + forca)/2.0) + (tonumber(sheet.level) or 0)
        end);

    obj._e_event35 = obj.dataLink18:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            							local total = ((tonumber(sheet.agilidadeBase) or 0) + (tonumber(sheet.agilidadeMod) or 0) + (tonumber(sheet.agilidadeOut) or 0))
            							local bonus = (tonumber(sheet.movimencacaoBonus) or 0)
            
            							local table = {1.5,1.5,2,2,2.5,2.5,3,3,3.5,4,4.5,5,5.5,6,7,8,9,10,11,12,14,16,18,20,22,25,28,30,35,40,45,50,56,63,70,80,90,100,110,125,140,160,180,200,220}
            							local extra = 220
            							if total < 46 and total > 0 then
            								extra = table[total]
            							elseif total < 1 then
            								extra = 0
            							end
            
            							sheet.movimencacaoTotal = extra + bonus
        end);

    obj._e_event36 = obj.dataLink19:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            							local total = ((tonumber(sheet.forcaBase) or 0) + (tonumber(sheet.forcaMod) or 0) + (tonumber(sheet.forcaOut) or 0))
            							local bonus = (tonumber(sheet.bforcaBonus) or 0)
            
            							local table = {-3,-3,-2,-2,-1,-1,-1,-1,0,0,0,0,0,0}
            							local extra = math.floor((total-13)/2)
            							if total < 15 and total > 0 then
            								extra = table[total]
            							elseif total < 1 then
            								extra = 0
            							end
            
            							sheet.bforcaTotal = extra + bonus
        end);

    obj._e_event37 = obj.button14:addEventListener("onClick",
        function (event)
            self.ataquesPrincipal:append();
        end);

    obj._e_event38 = obj.button15:addEventListener("onClick",
        function (event)
            local node = self.pericias:append()
            							if node then
            								local atrs = {"constituicao","forca","destreza","agilidade","inteligencia","vontade","percepcao","carisma"}
            								for i,v in ipairs(atrs) do
            									local base = (tonumber(sheet[v.."Base"]) or 0)
            									local mod = (tonumber(sheet[v.."Mod"]) or 0)
            									node[v] = base + mod
            								end
            							end
        end);

    obj._e_event39 = obj.pericias:addEventListener("onCompare",
        function (nodeA, nodeB)
            local kitA = (nodeA.kit ~= nil and nodeA.kit ~= "") and 1 or 0
            						local kitB = (nodeB.kit ~= nil and nodeB.kit ~= "") and 1 or 0
            						if kitA ~= kitB then return kitA > kitB end
            						return utils.compareStringPtBr(nodeA.nome, nodeB.nome)
        end);

    obj._e_event40 = obj.dataLink20:addEventListener("onChange",
        function (field, oldValue, newValue)
            local v = tonumber(sheet.equipamento.dinheiro.pc) or 0
            						self.imgBolsaCheia.visible  = (v > 100)
            						self.imgBolsaMetade.visible = (v >= 40 and v <= 100)
            						self.imgBolsaVazia.visible  = (v <= 39)
        end);

    obj._e_event41 = obj.button16:addEventListener("onClick",
        function (event)
            self.bag:append()
        end);

    obj._e_event42 = obj.dataLink21:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.ar) or 0)
            
            				if mod==0 then
            					sheet.arEntender = nil
            					sheet.arControlar = nil
            					sheet.arCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.arEntender = entender + mod
            				sheet.arControlar = controlar + mod
            				sheet.arCriar = criar + mod
        end);

    obj._e_event43 = obj.dataLink22:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.terra) or 0)
            
            				if mod==0 then
            					sheet.terraEntender = nil
            					sheet.terraControlar = nil
            					sheet.terraCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.terraEntender = entender + mod
            				sheet.terraControlar = controlar + mod
            				sheet.terraCriar = criar + mod
        end);

    obj._e_event44 = obj.dataLink23:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.agua) or 0)
            
            				if mod==0 then
            					sheet.aguaEntender = nil
            					sheet.aguaControlar = nil
            					sheet.aguaCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.aguaEntender = entender + mod
            				sheet.aguaControlar = controlar + mod
            				sheet.aguaCriar = criar + mod
        end);

    obj._e_event45 = obj.dataLink24:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.fogo) or 0)
            
            				if mod==0 then
            					sheet.fogoEntender = nil
            					sheet.fogoControlar = nil
            					sheet.fogoCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.fogoEntender = entender + mod
            				sheet.fogoControlar = controlar + mod
            				sheet.fogoCriar = criar + mod
        end);

    obj._e_event46 = obj.dataLink25:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.luz) or 0)
            
            				if mod==0 then
            					sheet.luzEntender = nil
            					sheet.luzControlar = nil
            					sheet.luzCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.luzEntender = entender + mod
            				sheet.luzControlar = controlar + mod
            				sheet.luzCriar = criar + mod
        end);

    obj._e_event47 = obj.dataLink26:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.trevas) or 0)
            
            				if mod==0 then
            					sheet.trevasEntender = nil
            					sheet.trevasControlar = nil
            					sheet.trevasCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.trevasEntender = entender + mod
            				sheet.trevasControlar = controlar + mod
            				sheet.trevasCriar = criar + mod
        end);

    obj._e_event48 = obj.dataLink27:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.arkanum) or 0)
            
            				if mod==0 then
            					sheet.arkanumEntender = nil
            					sheet.arkanumControlar = nil
            					sheet.arkanumCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.arkanumEntender = entender + mod
            				sheet.arkanumControlar = controlar + mod
            				sheet.arkanumCriar = criar + mod
        end);

    obj._e_event49 = obj.dataLink28:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.spiritum) or 0)
            
            				if mod==0 then
            					sheet.spiritumEntender = nil
            					sheet.spiritumControlar = nil
            					sheet.spiritumCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.spiritumEntender = entender + mod
            				sheet.spiritumControlar = controlar + mod
            				sheet.spiritumCriar = criar + mod
        end);

    obj._e_event50 = obj.dataLink29:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.humanos) or 0)
            
            				if mod==0 then
            					sheet.humanosEntender = nil
            					sheet.humanosControlar = nil
            					sheet.humanosCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.humanosEntender = entender + mod
            				sheet.humanosControlar = controlar + mod
            				sheet.humanosCriar = criar + mod
        end);

    obj._e_event51 = obj.dataLink30:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.plantas) or 0)
            
            				if mod==0 then
            					sheet.plantasEntender = nil
            					sheet.plantasControlar = nil
            					sheet.plantasCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.plantasEntender = entender + mod
            				sheet.plantasControlar = controlar + mod
            				sheet.plantasCriar = criar + mod
        end);

    obj._e_event52 = obj.dataLink31:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.animais) or 0)
            
            				if mod==0 then
            					sheet.animaisEntender = nil
            					sheet.animaisControlar = nil
            					sheet.animaisCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.animaisEntender = entender + mod
            				sheet.animaisControlar = controlar + mod
            				sheet.animaisCriar = criar + mod
        end);

    obj._e_event53 = obj.dataLink32:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            				local mod = (tonumber(sheet.metamagia) or 0)
            
            				if mod==0 then
            					sheet.metamagiaEntender = nil
            					sheet.metamagiaControlar = nil
            					sheet.metamagiaCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.metamagiaEntender = entender + mod
            				sheet.metamagiaControlar = controlar + mod
            				sheet.metamagiaCriar = criar + mod
        end);

    obj._e_event54 = obj.dataLink33:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            								sheet.focus = (tonumber(sheet.entender) or 0) + 
            												(tonumber(sheet.controlar) or 0) + 
            												(tonumber(sheet.criar) or 0) + 
            												(tonumber(sheet.ar) or 0) + 
            												(tonumber(sheet.terra) or 0) + 
            												(tonumber(sheet.agua) or 0) + 
            												(tonumber(sheet.fogo) or 0) + 
            												(tonumber(sheet.luz) or 0) + 
            												(tonumber(sheet.trevas) or 0) + 
            												(tonumber(sheet.arkanum) or 0) + 
            												(tonumber(sheet.spiritum) or 0) + 
            												(tonumber(sheet.humanos) or 0) + 
            												(tonumber(sheet.plantas) or 0) + 
            												(tonumber(sheet.animais) or 0) + 
            												(tonumber(sheet.metamagia) or 0)
        end);

    obj._e_event55 = obj.dataLink34:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.magma) or 0)
            				if mod==0 then
            					sheet.magmaEntender = nil
            					sheet.magmaControlar = nil
            					sheet.magmaCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.magmaEntender = entender + mod
            				sheet.magmaControlar = controlar + mod
            				sheet.magmaCriar = criar + mod
        end);

    obj._e_event56 = obj.dataLink35:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.cinzas) or 0)
            				if mod==0 then
            					sheet.cinzasEntender = nil
            					sheet.cinzasControlar = nil
            					sheet.cinzasCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.cinzasEntender = entender + mod
            				sheet.cinzasControlar = controlar + mod
            				sheet.cinzasCriar = criar + mod
        end);

    obj._e_event57 = obj.dataLink36:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.cores) or 0)
            				if mod==0 then
            					sheet.coresEntender = nil
            					sheet.coresControlar = nil
            					sheet.coresCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.coresEntender = entender + mod
            				sheet.coresControlar = controlar + mod
            				sheet.coresCriar = criar + mod
        end);

    obj._e_event58 = obj.dataLink37:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.fumaca) or 0)
            				if mod==0 then
            					sheet.fumacaEntender = nil
            					sheet.fumacaControlar = nil
            					sheet.fumacaCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.fumacaEntender = entender + mod
            				sheet.fumacaControlar = controlar + mod
            				sheet.fumacaCriar = criar + mod
        end);

    obj._e_event59 = obj.dataLink38:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.relampagos) or 0)
            				if mod==0 then
            					sheet.relampagosEntender = nil
            					sheet.relampagosControlar = nil
            					sheet.relampagosCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.relampagosEntender = entender + mod
            				sheet.relampagosControlar = controlar + mod
            				sheet.relampagosCriar = criar + mod
        end);

    obj._e_event60 = obj.dataLink39:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.gelo) or 0)
            				if mod==0 then
            					sheet.geloEntender = nil
            					sheet.geloControlar = nil
            					sheet.geloCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.geloEntender = entender + mod
            				sheet.geloControlar = controlar + mod
            				sheet.geloCriar = criar + mod
        end);

    obj._e_event61 = obj.dataLink40:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.vapores) or 0)
            				if mod==0 then
            					sheet.vaporesEntender = nil
            					sheet.vaporesControlar = nil
            					sheet.vaporesCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.vaporesEntender = entender + mod
            				sheet.vaporesControlar = controlar + mod
            				sheet.vaporesCriar = criar + mod
        end);

    obj._e_event62 = obj.dataLink41:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.cristais) or 0)
            				if mod==0 then
            					sheet.cristaisEntender = nil
            					sheet.cristaisControlar = nil
            					sheet.cristaisCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.cristaisEntender = entender + mod
            				sheet.cristaisControlar = controlar + mod
            				sheet.cristaisCriar = criar + mod
        end);

    obj._e_event63 = obj.dataLink42:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.lama) or 0)
            				if mod==0 then
            					sheet.lamaEntender = nil
            					sheet.lamaControlar = nil
            					sheet.lamaCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.lamaEntender = entender + mod
            				sheet.lamaControlar = controlar + mod
            				sheet.lamaCriar = criar + mod
        end);

    obj._e_event64 = obj.dataLink43:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.corrosao) or 0)
            				if mod==0 then
            					sheet.corrosaoEntender = nil
            					sheet.corrosaoControlar = nil
            					sheet.corrosaoCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.corrosaoEntender = entender + mod
            				sheet.corrosaoControlar = controlar + mod
            				sheet.corrosaoCriar = criar + mod
        end);

    obj._e_event65 = obj.dataLink44:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.vacuo) or 0)
            				if mod==0 then
            					sheet.vacuoEntender = nil
            					sheet.vacuoControlar = nil
            					sheet.vacuoCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.vacuoEntender = entender + mod
            				sheet.vacuoControlar = controlar + mod
            				sheet.vacuoCriar = criar + mod
        end);

    obj._e_event66 = obj.dataLink45:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            
            				local mod = (tonumber(sheet.venenos) or 0)
            				if mod==0 then
            					sheet.venenosEntender = nil
            					sheet.venenosControlar = nil
            					sheet.venenosCriar = nil
            					return
            				end
            
            				local entender = (tonumber(sheet.entender) or 0)
            				local controlar = (tonumber(sheet.controlar) or 0)
            				local criar = (tonumber(sheet.criar) or 0)
            
            				sheet.venenosEntender = entender + mod
            				sheet.venenosControlar = controlar + mod
            				sheet.venenosCriar = criar + mod
        end);

    obj._e_event67 = obj.dataLink46:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil then return end
            					local ar = (tonumber(sheet.ar) or 0)
            					local terra = (tonumber(sheet.terra) or 0)
            					local agua = (tonumber(sheet.agua) or 0)
            					local fogo = (tonumber(sheet.fogo) or 0)
            					local luz = (tonumber(sheet.luz) or 0)
            					local trevas = (tonumber(sheet.trevas) or 0)
            
            					sheet.magma = math.min(terra,fogo)
            					sheet.cinzas = math.min(fogo,trevas)
            					sheet.cores = math.min(fogo,luz)
            					sheet.fumaca = math.min(fogo,ar)
            					sheet.relampagos = math.min(luz,ar)
            					sheet.gelo = math.min(agua,ar)
            					sheet.vapores = math.min(agua,luz)
            					sheet.cristais = math.min(terra,luz)
            					sheet.lama = math.min(terra,agua)
            					sheet.corrosao = math.min(terra,trevas)
            					sheet.vacuo = math.min(ar,trevas)
            					sheet.venenos = math.min(agua,trevas)
        end);

    obj._e_event68 = obj.rclflwMagicRecordList1:addEventListener("onResize",
        function ()
            self.flwMagicRecordList1._recalcHeight();
        end);

    obj._e_event69 = obj.btnNovoflwMagicRecordList1:addEventListener("onClick",
        function (event)
            self.rclflwMagicRecordList1:append();
        end);

    obj._e_event70 = obj.rclflwMagicRecordList2:addEventListener("onResize",
        function ()
            self.flwMagicRecordList2._recalcHeight();
        end);

    obj._e_event71 = obj.btnNovoflwMagicRecordList2:addEventListener("onClick",
        function (event)
            self.rclflwMagicRecordList2:append();
        end);

    obj._e_event72 = obj.rclflwMagicRecordList3:addEventListener("onResize",
        function ()
            self.flwMagicRecordList3._recalcHeight();
        end);

    obj._e_event73 = obj.btnNovoflwMagicRecordList3:addEventListener("onClick",
        function (event)
            self.rclflwMagicRecordList3:append();
        end);

    obj._e_event74 = obj.rclflwMagicRecordList4:addEventListener("onResize",
        function ()
            self.flwMagicRecordList4._recalcHeight();
        end);

    obj._e_event75 = obj.btnNovoflwMagicRecordList4:addEventListener("onClick",
        function (event)
            self.rclflwMagicRecordList4:append();
        end);

    obj._e_event76 = obj.rclflwMagicRecordList5:addEventListener("onResize",
        function ()
            self.flwMagicRecordList5._recalcHeight();
        end);

    obj._e_event77 = obj.btnNovoflwMagicRecordList5:addEventListener("onClick",
        function (event)
            self.rclflwMagicRecordList5:append();
        end);

    obj._e_event78 = obj.rclflwMagicRecordList6:addEventListener("onResize",
        function ()
            self.flwMagicRecordList6._recalcHeight();
        end);

    obj._e_event79 = obj.btnNovoflwMagicRecordList6:addEventListener("onClick",
        function (event)
            self.rclflwMagicRecordList6:append();
        end);

    obj._e_event80 = obj.rclflwMagicRecordList7:addEventListener("onResize",
        function ()
            self.flwMagicRecordList7._recalcHeight();
        end);

    obj._e_event81 = obj.btnNovoflwMagicRecordList7:addEventListener("onClick",
        function (event)
            self.rclflwMagicRecordList7:append();
        end);

    obj._e_event82 = obj.rclflwMagicRecordList8:addEventListener("onResize",
        function ()
            self.flwMagicRecordList8._recalcHeight();
        end);

    obj._e_event83 = obj.btnNovoflwMagicRecordList8:addEventListener("onClick",
        function (event)
            self.rclflwMagicRecordList8:append();
        end);

    obj._e_event84 = obj.rclflwMagicRecordList9:addEventListener("onResize",
        function ()
            self.flwMagicRecordList9._recalcHeight();
        end);

    obj._e_event85 = obj.btnNovoflwMagicRecordList9:addEventListener("onClick",
        function (event)
            self.rclflwMagicRecordList9:append();
        end);

    obj._e_event86 = obj.dataLink47:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet == nil or sheet.coresAtivas == false then return end;
            					local theme = sheet.theme;
            					if theme == "Claro" then
            						theme = "light";
            					else
            						theme = "dark";
            					end;
            
            					local forms = findClass("form");
            
            					for i=1, #forms, 1 do 
            						forms[i].theme = theme;
            					end;
        end);

    obj._e_event87 = obj.dataLink48:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil or sheet.coresAtivas == false then return end;
            					local color = sheet.colorBackground or "#000000";
            
            		            local rectangles = findClass("rectangle");
            
            					for i=1, #rectangles, 1 do 
            						rectangles[i].color = color;
            					end;
        end);

    obj._e_event88 = obj.dataLink49:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil or sheet.coresAtivas == false then return end;
            					local strokeColor = sheet.colorStroke or "#FFFFFF";
            
            		            local rectangles = findClass("rectangle");
            
            					for i=1, #rectangles, 1 do 
            						rectangles[i].strokeColor = strokeColor;
            					end;
        end);

    obj._e_event89 = obj.dataLink50:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet==nil or sheet.coresAtivas == false then return end;
            					local fontColor = sheet.colorFont or "#FFFFFF";
            
            					local controls = findAllControls();
            					
            					local edits = filterByClass("edit", controls);
            					for i=1, #edits, 1 do 
            						edits[i].fontColor = fontColor;
            					end;
            
            					local labels = filterByClass("label", controls);
            					for i=1, #labels, 1 do 
            						labels[i].fontColor = fontColor;
            					end;
            
            					local comboBoxs = filterByClass("comboBox", controls);
            					for i=1, #comboBoxs, 1 do 
            						comboBoxs[i].fontColor = fontColor;
            					end;
            
            					local textEditors = filterByClass("textEditor", controls);
            					for i=1, #textEditors, 1 do 
            						textEditors[i].fontColor = fontColor;
            					end;
            
            					local checkBoxs = filterByClass("checkBox", controls);
            					for i=1, #checkBoxs, 1 do 
            						checkBoxs[i].fontColor = fontColor;
            					end;
            
            					local buttons = filterByClass("button", controls);
            					for i=1, #buttons, 1 do 
            						buttons[i].fontColor = fontColor;
            					end;
        end);

    obj._e_event90 = obj.dataLink51:addEventListener("onChange",
        function (field, oldValue, newValue)
            if sheet == nil then return end;
            					if sheet.coresAtivas ~= false and aplicarCoresDaemon ~= nil then
            						aplicarCoresDaemon(self, sheet);
            					end;
        end);

    obj._e_event91 = obj.button17:addEventListener("onClick",
        function (event)
            GUI.openInBrowser('https://github.com/rrpgfirecast/firecast/blob/master/Plugins/Sheets/Ficha%20Daemon/README.md')
        end);

    obj._e_event92 = obj.button18:addEventListener("onClick",
        function (event)
            GUI.openInBrowser('https://github.com/rrpgfirecast/firecast/blob/master/Plugins/Sheets/Ficha%20Daemon/output/Ficha%20Daemon.rpk?raw=true')
        end);

    obj._e_event93 = obj.button19:addEventListener("onClick",
        function (event)
            GUI.openInBrowser('https://my.firecastrpg.com/a?a=pagRWEMesaInfo.actInfoMesa&mesaid=64070');
        end);

    obj._e_event94 = obj.button20:addEventListener("onClick",
        function (event)
            GUI.openInBrowser('https://my.firecast.app/a?a=pagRWEMesaInfo.actInfoMesa&mesaid=224358');
        end);

    obj._e_event95 = obj.button21:addEventListener("onClick",
        function (event)
            local xml = NDB.exportXML(sheet);
            
            				local export = {};
            				local bytes = Utils.binaryEncode(export, "utf8", xml);
            
            				local stream = Utils.newMemoryStream();
            				local bytes = stream:write(export);
            
            				Dialogs.saveFile("Salvar Ficha como XML", stream, "ficha.xml", "application/xml",
            					function()
            						stream:close();
            						showMessage("Ficha Exportada.");
            					end);
        end);

    obj._e_event96 = obj.button22:addEventListener("onClick",
        function (event)
            Dialogs.openFile("Importar Ficha", "application/xml", false, 
            					function(arquivos)
            						local arq = arquivos[1];
            
            						local import = {};
            						local bytes = arq.stream:read(import, arq.stream.size);
            
            						local xml = Utils.binaryDecode(import, "utf8");
            
            						NDB.importXML(sheet, xml);
            					end);
        end);

    function obj:_releaseEvents()
        __o_rrpgObjs.removeEventListenerById(self._e_event96);
        __o_rrpgObjs.removeEventListenerById(self._e_event95);
        __o_rrpgObjs.removeEventListenerById(self._e_event94);
        __o_rrpgObjs.removeEventListenerById(self._e_event93);
        __o_rrpgObjs.removeEventListenerById(self._e_event92);
        __o_rrpgObjs.removeEventListenerById(self._e_event91);
        __o_rrpgObjs.removeEventListenerById(self._e_event90);
        __o_rrpgObjs.removeEventListenerById(self._e_event89);
        __o_rrpgObjs.removeEventListenerById(self._e_event88);
        __o_rrpgObjs.removeEventListenerById(self._e_event87);
        __o_rrpgObjs.removeEventListenerById(self._e_event86);
        __o_rrpgObjs.removeEventListenerById(self._e_event85);
        __o_rrpgObjs.removeEventListenerById(self._e_event84);
        __o_rrpgObjs.removeEventListenerById(self._e_event83);
        __o_rrpgObjs.removeEventListenerById(self._e_event82);
        __o_rrpgObjs.removeEventListenerById(self._e_event81);
        __o_rrpgObjs.removeEventListenerById(self._e_event80);
        __o_rrpgObjs.removeEventListenerById(self._e_event79);
        __o_rrpgObjs.removeEventListenerById(self._e_event78);
        __o_rrpgObjs.removeEventListenerById(self._e_event77);
        __o_rrpgObjs.removeEventListenerById(self._e_event76);
        __o_rrpgObjs.removeEventListenerById(self._e_event75);
        __o_rrpgObjs.removeEventListenerById(self._e_event74);
        __o_rrpgObjs.removeEventListenerById(self._e_event73);
        __o_rrpgObjs.removeEventListenerById(self._e_event72);
        __o_rrpgObjs.removeEventListenerById(self._e_event71);
        __o_rrpgObjs.removeEventListenerById(self._e_event70);
        __o_rrpgObjs.removeEventListenerById(self._e_event69);
        __o_rrpgObjs.removeEventListenerById(self._e_event68);
        __o_rrpgObjs.removeEventListenerById(self._e_event67);
        __o_rrpgObjs.removeEventListenerById(self._e_event66);
        __o_rrpgObjs.removeEventListenerById(self._e_event65);
        __o_rrpgObjs.removeEventListenerById(self._e_event64);
        __o_rrpgObjs.removeEventListenerById(self._e_event63);
        __o_rrpgObjs.removeEventListenerById(self._e_event62);
        __o_rrpgObjs.removeEventListenerById(self._e_event61);
        __o_rrpgObjs.removeEventListenerById(self._e_event60);
        __o_rrpgObjs.removeEventListenerById(self._e_event59);
        __o_rrpgObjs.removeEventListenerById(self._e_event58);
        __o_rrpgObjs.removeEventListenerById(self._e_event57);
        __o_rrpgObjs.removeEventListenerById(self._e_event56);
        __o_rrpgObjs.removeEventListenerById(self._e_event55);
        __o_rrpgObjs.removeEventListenerById(self._e_event54);
        __o_rrpgObjs.removeEventListenerById(self._e_event53);
        __o_rrpgObjs.removeEventListenerById(self._e_event52);
        __o_rrpgObjs.removeEventListenerById(self._e_event51);
        __o_rrpgObjs.removeEventListenerById(self._e_event50);
        __o_rrpgObjs.removeEventListenerById(self._e_event49);
        __o_rrpgObjs.removeEventListenerById(self._e_event48);
        __o_rrpgObjs.removeEventListenerById(self._e_event47);
        __o_rrpgObjs.removeEventListenerById(self._e_event46);
        __o_rrpgObjs.removeEventListenerById(self._e_event45);
        __o_rrpgObjs.removeEventListenerById(self._e_event44);
        __o_rrpgObjs.removeEventListenerById(self._e_event43);
        __o_rrpgObjs.removeEventListenerById(self._e_event42);
        __o_rrpgObjs.removeEventListenerById(self._e_event41);
        __o_rrpgObjs.removeEventListenerById(self._e_event40);
        __o_rrpgObjs.removeEventListenerById(self._e_event39);
        __o_rrpgObjs.removeEventListenerById(self._e_event38);
        __o_rrpgObjs.removeEventListenerById(self._e_event37);
        __o_rrpgObjs.removeEventListenerById(self._e_event36);
        __o_rrpgObjs.removeEventListenerById(self._e_event35);
        __o_rrpgObjs.removeEventListenerById(self._e_event34);
        __o_rrpgObjs.removeEventListenerById(self._e_event33);
        __o_rrpgObjs.removeEventListenerById(self._e_event32);
        __o_rrpgObjs.removeEventListenerById(self._e_event31);
        __o_rrpgObjs.removeEventListenerById(self._e_event30);
        __o_rrpgObjs.removeEventListenerById(self._e_event29);
        __o_rrpgObjs.removeEventListenerById(self._e_event28);
        __o_rrpgObjs.removeEventListenerById(self._e_event27);
        __o_rrpgObjs.removeEventListenerById(self._e_event26);
        __o_rrpgObjs.removeEventListenerById(self._e_event25);
        __o_rrpgObjs.removeEventListenerById(self._e_event24);
        __o_rrpgObjs.removeEventListenerById(self._e_event23);
        __o_rrpgObjs.removeEventListenerById(self._e_event22);
        __o_rrpgObjs.removeEventListenerById(self._e_event21);
        __o_rrpgObjs.removeEventListenerById(self._e_event20);
        __o_rrpgObjs.removeEventListenerById(self._e_event19);
        __o_rrpgObjs.removeEventListenerById(self._e_event18);
        __o_rrpgObjs.removeEventListenerById(self._e_event17);
        __o_rrpgObjs.removeEventListenerById(self._e_event16);
        __o_rrpgObjs.removeEventListenerById(self._e_event15);
        __o_rrpgObjs.removeEventListenerById(self._e_event14);
        __o_rrpgObjs.removeEventListenerById(self._e_event13);
        __o_rrpgObjs.removeEventListenerById(self._e_event12);
        __o_rrpgObjs.removeEventListenerById(self._e_event11);
        __o_rrpgObjs.removeEventListenerById(self._e_event10);
        __o_rrpgObjs.removeEventListenerById(self._e_event9);
        __o_rrpgObjs.removeEventListenerById(self._e_event8);
        __o_rrpgObjs.removeEventListenerById(self._e_event7);
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

        if self.edit77 ~= nil then self.edit77:destroy(); self.edit77 = nil; end;
        if self.edit47 ~= nil then self.edit47:destroy(); self.edit47 = nil; end;
        if self.flowPart2 ~= nil then self.flowPart2:destroy(); self.flowPart2 = nil; end;
        if self.popAprimoramento ~= nil then self.popAprimoramento:destroy(); self.popAprimoramento = nil; end;
        if self.rectangle95 ~= nil then self.rectangle95:destroy(); self.rectangle95 = nil; end;
        if self.label112 ~= nil then self.label112:destroy(); self.label112 = nil; end;
        if self.rectangle85 ~= nil then self.rectangle85:destroy(); self.rectangle85 = nil; end;
        if self.label91 ~= nil then self.label91:destroy(); self.label91 = nil; end;
        if self.label164 ~= nil then self.label164:destroy(); self.label164 = nil; end;
        if self.label218 ~= nil then self.label218:destroy(); self.label218 = nil; end;
        if self.edit70 ~= nil then self.edit70:destroy(); self.edit70 = nil; end;
        if self.edit42 ~= nil then self.edit42:destroy(); self.edit42 = nil; end;
        if self.flowPart7 ~= nil then self.flowPart7:destroy(); self.flowPart7 = nil; end;
        if self.rectangle71 ~= nil then self.rectangle71:destroy(); self.rectangle71 = nil; end;
        if self.rectangle90 ~= nil then self.rectangle90:destroy(); self.rectangle90 = nil; end;
        if self.label115 ~= nil then self.label115:destroy(); self.label115 = nil; end;
        if self.rectangle82 ~= nil then self.rectangle82:destroy(); self.rectangle82 = nil; end;
        if self.layout70 ~= nil then self.layout70:destroy(); self.layout70 = nil; end;
        if self.label161 ~= nil then self.label161:destroy(); self.label161 = nil; end;
        if self.layout116 ~= nil then self.layout116:destroy(); self.layout116 = nil; end;
        if self.edit49 ~= nil then self.edit49:destroy(); self.edit49 = nil; end;
        if self.rectangle74 ~= nil then self.rectangle74:destroy(); self.rectangle74 = nil; end;
        if self.rectangle37 ~= nil then self.rectangle37:destroy(); self.rectangle37 = nil; end;
        if self.label67 ~= nil then self.label67:destroy(); self.label67 = nil; end;
        if self.label118 ~= nil then self.label118:destroy(); self.label118 = nil; end;
        if self.edit27 ~= nil then self.edit27:destroy(); self.edit27 = nil; end;
        if self.layout75 ~= nil then self.layout75:destroy(); self.layout75 = nil; end;
        if self.dataLink32 ~= nil then self.dataLink32:destroy(); self.dataLink32 = nil; end;
        if self.label180 ~= nil then self.label180:destroy(); self.label180 = nil; end;
        if self.layout111 ~= nil then self.layout111:destroy(); self.layout111 = nil; end;
        if self.comboBox6 ~= nil then self.comboBox6:destroy(); self.comboBox6 = nil; end;
        if self.checkBox1 ~= nil then self.checkBox1:destroy(); self.checkBox1 = nil; end;
        if self.rectangle32 ~= nil then self.rectangle32:destroy(); self.rectangle32 = nil; end;
        if self.rectangle121 ~= nil then self.rectangle121:destroy(); self.rectangle121 = nil; end;
        if self.comboBox3 ~= nil then self.comboBox3:destroy(); self.comboBox3 = nil; end;
        if self.edit9 ~= nil then self.edit9:destroy(); self.edit9 = nil; end;
        if self.label62 ~= nil then self.label62:destroy(); self.label62 = nil; end;
        if self.image19 ~= nil then self.image19:destroy(); self.image19 = nil; end;
        if self.layout37 ~= nil then self.layout37:destroy(); self.layout37 = nil; end;
        if self.edit65 ~= nil then self.edit65:destroy(); self.edit65 = nil; end;
        if self.label185 ~= nil then self.label185:destroy(); self.label185 = nil; end;
        if self.label174 ~= nil then self.label174:destroy(); self.label174 = nil; end;
        if self.layout59 ~= nil then self.layout59:destroy(); self.layout59 = nil; end;
        if self.label69 ~= nil then self.label69:destroy(); self.label69 = nil; end;
        if self.dataLink38 ~= nil then self.dataLink38:destroy(); self.dataLink38 = nil; end;
        if self.edit60 ~= nil then self.edit60:destroy(); self.edit60 = nil; end;
        if self.dataLink5 ~= nil then self.dataLink5:destroy(); self.dataLink5 = nil; end;
        if self.rectangle106 ~= nil then self.rectangle106:destroy(); self.rectangle106 = nil; end;
        if self.rectangle110 ~= nil then self.rectangle110:destroy(); self.rectangle110 = nil; end;
        if self.label173 ~= nil then self.label173:destroy(); self.label173 = nil; end;
        if self.rectangle38 ~= nil then self.rectangle38:destroy(); self.rectangle38 = nil; end;
        if self.layout52 ~= nil then self.layout52:destroy(); self.layout52 = nil; end;
        if self.label39 ~= nil then self.label39:destroy(); self.label39 = nil; end;
        if self.edit3 ~= nil then self.edit3:destroy(); self.edit3 = nil; end;
        if self.button8 ~= nil then self.button8:destroy(); self.button8 = nil; end;
        if self.image17 ~= nil then self.image17:destroy(); self.image17 = nil; end;
        if self.layout60 ~= nil then self.layout60:destroy(); self.layout60 = nil; end;
        if self.flowPart10 ~= nil then self.flowPart10:destroy(); self.flowPart10 = nil; end;
        if self.label45 ~= nil then self.label45:destroy(); self.label45 = nil; end;
        if self.tab1 ~= nil then self.tab1:destroy(); self.tab1 = nil; end;
        if self.layout57 ~= nil then self.layout57:destroy(); self.layout57 = nil; end;
        if self.layout18 ~= nil then self.layout18:destroy(); self.layout18 = nil; end;
        if self.edit6 ~= nil then self.edit6:destroy(); self.edit6 = nil; end;
        if self.button3 ~= nil then self.button3:destroy(); self.button3 = nil; end;
        if self.layout67 ~= nil then self.layout67:destroy(); self.layout67 = nil; end;
        if self.dataLink41 ~= nil then self.dataLink41:destroy(); self.dataLink41 = nil; end;
        if self.image1 ~= nil then self.image1:destroy(); self.image1 = nil; end;
        if self.flowLayout6 ~= nil then self.flowLayout6:destroy(); self.flowLayout6 = nil; end;
        if self.flwMagicRecordList7 ~= nil then self.flwMagicRecordList7:destroy(); self.flwMagicRecordList7 = nil; end;
        if self.flowPart17 ~= nil then self.flowPart17:destroy(); self.flowPart17 = nil; end;
        if self.label40 ~= nil then self.label40:destroy(); self.label40 = nil; end;
        if self.label128 ~= nil then self.label128:destroy(); self.label128 = nil; end;
        if self.rectangle63 ~= nil then self.rectangle63:destroy(); self.rectangle63 = nil; end;
        if self.label9 ~= nil then self.label9:destroy(); self.label9 = nil; end;
        if self.layout15 ~= nil then self.layout15:destroy(); self.layout15 = nil; end;
        if self.label33 ~= nil then self.label33:destroy(); self.label33 = nil; end;
        if self.button6 ~= nil then self.button6:destroy(); self.button6 = nil; end;
        if self.dataLink44 ~= nil then self.dataLink44:destroy(); self.dataLink44 = nil; end;
        if self.rclflwMagicRecordList3 ~= nil then self.rclflwMagicRecordList3:destroy(); self.rclflwMagicRecordList3 = nil; end;
        if self.layout7 ~= nil then self.layout7:destroy(); self.layout7 = nil; end;
        if self.rectangle49 ~= nil then self.rectangle49:destroy(); self.rectangle49 = nil; end;
        if self.label156 ~= nil then self.label156:destroy(); self.label156 = nil; end;
        if self.label209 ~= nil then self.label209:destroy(); self.label209 = nil; end;
        if self.dataLink51 ~= nil then self.dataLink51:destroy(); self.dataLink51 = nil; end;
        if self.rclflwMagicRecordList6 ~= nil then self.rclflwMagicRecordList6:destroy(); self.rclflwMagicRecordList6 = nil; end;
        if self.rectangle64 ~= nil then self.rectangle64:destroy(); self.rectangle64 = nil; end;
        if self.button18 ~= nil then self.button18:destroy(); self.button18 = nil; end;
        if self.button21 ~= nil then self.button21:destroy(); self.button21 = nil; end;
        if self.edit31 ~= nil then self.edit31:destroy(); self.edit31 = nil; end;
        if self.layout2 ~= nil then self.layout2:destroy(); self.layout2 = nil; end;
        if self.label151 ~= nil then self.label151:destroy(); self.label151 = nil; end;
        if self.flowLayout8 ~= nil then self.flowLayout8:destroy(); self.flowLayout8 = nil; end;
        if self.layout42 ~= nil then self.layout42:destroy(); self.layout42 = nil; end;
        if self.label122 ~= nil then self.label122:destroy(); self.label122 = nil; end;
        if self.label203 ~= nil then self.label203:destroy(); self.label203 = nil; end;
        if self.label7 ~= nil then self.label7:destroy(); self.label7 = nil; end;
        if self.button16 ~= nil then self.button16:destroy(); self.button16 = nil; end;
        if self.flowLayout11 ~= nil then self.flowLayout11:destroy(); self.flowLayout11 = nil; end;
        if self.layBottomflwMagicRecordList8 ~= nil then self.layBottomflwMagicRecordList8:destroy(); self.layBottomflwMagicRecordList8 = nil; end;
        if self.rclflwMagicRecordList9 ~= nil then self.rclflwMagicRecordList9:destroy(); self.rclflwMagicRecordList9 = nil; end;
        if self.richEdit1 ~= nil then self.richEdit1:destroy(); self.richEdit1 = nil; end;
        if self.frmTemplateNotes ~= nil then self.frmTemplateNotes:destroy(); self.frmTemplateNotes = nil; end;
        if self.rectangle43 ~= nil then self.rectangle43:destroy(); self.rectangle43 = nil; end;
        if self.frmTemplateCreditos ~= nil then self.frmTemplateCreditos:destroy(); self.frmTemplateCreditos = nil; end;
        if self.layout45 ~= nil then self.layout45:destroy(); self.layout45 = nil; end;
        if self.label127 ~= nil then self.label127:destroy(); self.label127 = nil; end;
        if self.edit10 ~= nil then self.edit10:destroy(); self.edit10 = nil; end;
        if self.label206 ~= nil then self.label206:destroy(); self.label206 = nil; end;
        if self.label81 ~= nil then self.label81:destroy(); self.label81 = nil; end;
        if self.layBottomflwMagicRecordList7 ~= nil then self.layBottomflwMagicRecordList7:destroy(); self.layBottomflwMagicRecordList7 = nil; end;
        if self.label11 ~= nil then self.label11:destroy(); self.label11 = nil; end;
        if self.rectangle8 ~= nil then self.rectangle8:destroy(); self.rectangle8 = nil; end;
        if self.edit15 ~= nil then self.edit15:destroy(); self.edit15 = nil; end;
        if self.label25 ~= nil then self.label25:destroy(); self.label25 = nil; end;
        if self.layout48 ~= nil then self.layout48:destroy(); self.layout48 = nil; end;
        if self.label84 ~= nil then self.label84:destroy(); self.label84 = nil; end;
        if self.dataLink29 ~= nil then self.dataLink29:destroy(); self.dataLink29 = nil; end;
        if self.layBottomflwMagicRecordList2 ~= nil then self.layBottomflwMagicRecordList2:destroy(); self.layBottomflwMagicRecordList2 = nil; end;
        if self.layout88 ~= nil then self.layout88:destroy(); self.layout88 = nil; end;
        if self.layout96 ~= nil then self.layout96:destroy(); self.layout96 = nil; end;
        if self.rectangle5 ~= nil then self.rectangle5:destroy(); self.rectangle5 = nil; end;
        if self.label28 ~= nil then self.label28:destroy(); self.label28 = nil; end;
        if self.label57 ~= nil then self.label57:destroy(); self.label57 = nil; end;
        if self.edit57 ~= nil then self.edit57:destroy(); self.edit57 = nil; end;
        if self.dataLink24 ~= nil then self.dataLink24:destroy(); self.dataLink24 = nil; end;
        if self.label192 ~= nil then self.label192:destroy(); self.label192 = nil; end;
        if self.textEditor3 ~= nil then self.textEditor3:destroy(); self.textEditor3 = nil; end;
        if self.layout24 ~= nil then self.layout24:destroy(); self.layout24 = nil; end;
        if self.label100 ~= nil then self.label100:destroy(); self.label100 = nil; end;
        if self.label132 ~= nil then self.label132:destroy(); self.label132 = nil; end;
        if self.scrollBox1 ~= nil then self.scrollBox1:destroy(); self.scrollBox1 = nil; end;
        if self.layout83 ~= nil then self.layout83:destroy(); self.layout83 = nil; end;
        if self.rectangle2 ~= nil then self.rectangle2:destroy(); self.rectangle2 = nil; end;
        if self.label50 ~= nil then self.label50:destroy(); self.label50 = nil; end;
        if self.layout93 ~= nil then self.layout93:destroy(); self.layout93 = nil; end;
        if self.label195 ~= nil then self.label195:destroy(); self.label195 = nil; end;
        if self.label221 ~= nil then self.label221:destroy(); self.label221 = nil; end;
        if self.pericias ~= nil then self.pericias:destroy(); self.pericias = nil; end;
        if self.rectangle55 ~= nil then self.rectangle55:destroy(); self.rectangle55 = nil; end;
        if self.layout23 ~= nil then self.layout23:destroy(); self.layout23 = nil; end;
        if self.label105 ~= nil then self.label105:destroy(); self.label105 = nil; end;
        if self.label139 ~= nil then self.label139:destroy(); self.label139 = nil; end;
        if self.dataLink15 ~= nil then self.dataLink15:destroy(); self.dataLink15 = nil; end;
        if self.label146 ~= nil then self.label146:destroy(); self.label146 = nil; end;
        if self.layout104 ~= nil then self.layout104:destroy(); self.layout104 = nil; end;
        if self.btnNovoflwMagicRecordList4 ~= nil then self.btnNovoflwMagicRecordList4:destroy(); self.btnNovoflwMagicRecordList4 = nil; end;
        if self.label224 ~= nil then self.label224:destroy(); self.label224 = nil; end;
        if self.imgBolsaVazia ~= nil then self.imgBolsaVazia:destroy(); self.imgBolsaVazia = nil; end;
        if self.rectangle27 ~= nil then self.rectangle27:destroy(); self.rectangle27 = nil; end;
        if self.rectangle17 ~= nil then self.rectangle17:destroy(); self.rectangle17 = nil; end;
        if self.label77 ~= nil then self.label77:destroy(); self.label77 = nil; end;
        if self.rectangle58 ~= nil then self.rectangle58:destroy(); self.rectangle58 = nil; end;
        if self.label143 ~= nil then self.label143:destroy(); self.label143 = nil; end;
        if self.dataLink12 ~= nil then self.dataLink12:destroy(); self.dataLink12 = nil; end;
        if self.edit78 ~= nil then self.edit78:destroy(); self.edit78 = nil; end;
        if self.layout99 ~= nil then self.layout99:destroy(); self.layout99 = nil; end;
        if self.layout101 ~= nil then self.layout101:destroy(); self.layout101 = nil; end;
        if self.btnNovoflwMagicRecordList1 ~= nil then self.btnNovoflwMagicRecordList1:destroy(); self.btnNovoflwMagicRecordList1 = nil; end;
        if self.label210 ~= nil then self.label210:destroy(); self.label210 = nil; end;
        if self.rectangle98 ~= nil then self.rectangle98:destroy(); self.rectangle98 = nil; end;
        if self.rectangle20 ~= nil then self.rectangle20:destroy(); self.rectangle20 = nil; end;
        if self.rectangle12 ~= nil then self.rectangle12:destroy(); self.rectangle12 = nil; end;
        if self.label92 ~= nil then self.label92:destroy(); self.label92 = nil; end;
        if self.layout78 ~= nil then self.layout78:destroy(); self.layout78 = nil; end;
        if self.label169 ~= nil then self.label169:destroy(); self.label169 = nil; end;
        if self.edit75 ~= nil then self.edit75:destroy(); self.edit75 = nil; end;
        if self.edit41 ~= nil then self.edit41:destroy(); self.edit41 = nil; end;
        if self.flowPart4 ~= nil then self.flowPart4:destroy(); self.flowPart4 = nil; end;
        if self.label215 ~= nil then self.label215:destroy(); self.label215 = nil; end;
        if self.rectangle97 ~= nil then self.rectangle97:destroy(); self.rectangle97 = nil; end;
        if self.label110 ~= nil then self.label110:destroy(); self.label110 = nil; end;
        if self.rectangle19 ~= nil then self.rectangle19:destroy(); self.rectangle19 = nil; end;
        if self.label97 ~= nil then self.label97:destroy(); self.label97 = nil; end;
        if self.rectangle87 ~= nil then self.rectangle87:destroy(); self.rectangle87 = nil; end;
        if self.label166 ~= nil then self.label166:destroy(); self.label166 = nil; end;
        if self.flowPart9 ~= nil then self.flowPart9:destroy(); self.flowPart9 = nil; end;
        if self.rectangle77 ~= nil then self.rectangle77:destroy(); self.rectangle77 = nil; end;
        if self.rectangle92 ~= nil then self.rectangle92:destroy(); self.rectangle92 = nil; end;
        if self.label163 ~= nil then self.label163:destroy(); self.label163 = nil; end;
        if self.edit22 ~= nil then self.edit22:destroy(); self.edit22 = nil; end;
        if self.label98 ~= nil then self.label98:destroy(); self.label98 = nil; end;
        if self.layout72 ~= nil then self.layout72:destroy(); self.layout72 = nil; end;
        if self.dataLink37 ~= nil then self.dataLink37:destroy(); self.dataLink37 = nil; end;
        if self.layout114 ~= nil then self.layout114:destroy(); self.layout114 = nil; end;
        if self.checkBox2 ~= nil then self.checkBox2:destroy(); self.checkBox2 = nil; end;
        if self.rectangle35 ~= nil then self.rectangle35:destroy(); self.rectangle35 = nil; end;
        if self.rectangle124 ~= nil then self.rectangle124:destroy(); self.rectangle124 = nil; end;
        if self.label61 ~= nil then self.label61:destroy(); self.label61 = nil; end;
        if self.rectangle89 ~= nil then self.rectangle89:destroy(); self.rectangle89 = nil; end;
        if self.edit25 ~= nil then self.edit25:destroy(); self.edit25 = nil; end;
        if self.layout77 ~= nil then self.layout77:destroy(); self.layout77 = nil; end;
        if self.layout34 ~= nil then self.layout34:destroy(); self.layout34 = nil; end;
        if self.dataLink30 ~= nil then self.dataLink30:destroy(); self.dataLink30 = nil; end;
        if self.label186 ~= nil then self.label186:destroy(); self.label186 = nil; end;
        if self.rectangle30 ~= nil then self.rectangle30:destroy(); self.rectangle30 = nil; end;
        if self.edit28 ~= nil then self.edit28:destroy(); self.edit28 = nil; end;
        if self.edit63 ~= nil then self.edit63:destroy(); self.edit63 = nil; end;
        if self.layout31 ~= nil then self.layout31:destroy(); self.layout31 = nil; end;
        if self.rectangle105 ~= nil then self.rectangle105:destroy(); self.rectangle105 = nil; end;
        if self.rectangle115 ~= nil then self.rectangle115:destroy(); self.rectangle115 = nil; end;
        if self.label176 ~= nil then self.label176:destroy(); self.label176 = nil; end;
        if self.dataLink49 ~= nil then self.dataLink49:destroy(); self.dataLink49 = nil; end;
        if self.image12 ~= nil then self.image12:destroy(); self.image12 = nil; end;
        if self.dataLink7 ~= nil then self.dataLink7:destroy(); self.dataLink7 = nil; end;
        if self.rectangle100 ~= nil then self.rectangle100:destroy(); self.rectangle100 = nil; end;
        if self.rectangle112 ~= nil then self.rectangle112:destroy(); self.rectangle112 = nil; end;
        if self.tab2 ~= nil then self.tab2:destroy(); self.tab2 = nil; end;
        if self.layout50 ~= nil then self.layout50:destroy(); self.layout50 = nil; end;
        if self.layout62 ~= nil then self.layout62:destroy(); self.layout62 = nil; end;
        if self.edit5 ~= nil then self.edit5:destroy(); self.edit5 = nil; end;
        if self.image15 ~= nil then self.image15:destroy(); self.image15 = nil; end;
        if self.dataLink2 ~= nil then self.dataLink2:destroy(); self.dataLink2 = nil; end;
        if self.image2 ~= nil then self.image2:destroy(); self.image2 = nil; end;
        if self.edit69 ~= nil then self.edit69:destroy(); self.edit69 = nil; end;
        if self.flowLayout5 ~= nil then self.flowLayout5:destroy(); self.flowLayout5 = nil; end;
        if self.flowPart12 ~= nil then self.flowPart12:destroy(); self.flowPart12 = nil; end;
        if self.label43 ~= nil then self.label43:destroy(); self.label43 = nil; end;
        if self.label178 ~= nil then self.label178:destroy(); self.label178 = nil; end;
        if self.layout55 ~= nil then self.layout55:destroy(); self.layout55 = nil; end;
        if self.layout16 ~= nil then self.layout16:destroy(); self.layout16 = nil; end;
        if self.label30 ~= nil then self.label30:destroy(); self.label30 = nil; end;
        if self.button1 ~= nil then self.button1:destroy(); self.button1 = nil; end;
        if self.edit39 ~= nil then self.edit39:destroy(); self.edit39 = nil; end;
        if self.dataLink9 ~= nil then self.dataLink9:destroy(); self.dataLink9 = nil; end;
        if self.image7 ~= nil then self.image7:destroy(); self.image7 = nil; end;
        if self.layout69 ~= nil then self.layout69:destroy(); self.layout69 = nil; end;
        if self.dataLink43 ~= nil then self.dataLink43:destroy(); self.dataLink43 = nil; end;
        if self.flwMagicRecordList5 ~= nil then self.flwMagicRecordList5:destroy(); self.flwMagicRecordList5 = nil; end;
        if self.rclflwMagicRecordList1 ~= nil then self.rclflwMagicRecordList1:destroy(); self.rclflwMagicRecordList1 = nil; end;
        if self.rectangle61 ~= nil then self.rectangle61:destroy(); self.rectangle61 = nil; end;
        if self.layout13 ~= nil then self.layout13:destroy(); self.layout13 = nil; end;
        if self.label35 ~= nil then self.label35:destroy(); self.label35 = nil; end;
        if self.button4 ~= nil then self.button4:destroy(); self.button4 = nil; end;
        if self.edit32 ~= nil then self.edit32:destroy(); self.edit32 = nil; end;
        if self.dataLink46 ~= nil then self.dataLink46:destroy(); self.dataLink46 = nil; end;
        if self.layout5 ~= nil then self.layout5:destroy(); self.layout5 = nil; end;
        if self.image8 ~= nil then self.image8:destroy(); self.image8 = nil; end;
        if self.label154 ~= nil then self.label154:destroy(); self.label154 = nil; end;
        if self.label49 ~= nil then self.label49:destroy(); self.label49 = nil; end;
        if self.rclflwMagicRecordList4 ~= nil then self.rclflwMagicRecordList4:destroy(); self.rclflwMagicRecordList4 = nil; end;
        if self.edit18 ~= nil then self.edit18:destroy(); self.edit18 = nil; end;
        if self.label2 ~= nil then self.label2:destroy(); self.label2 = nil; end;
        if self.button13 ~= nil then self.button13:destroy(); self.button13 = nil; end;
        if self.label89 ~= nil then self.label89:destroy(); self.label89 = nil; end;
        if self.edit37 ~= nil then self.edit37:destroy(); self.edit37 = nil; end;
        if self.rectangle40 ~= nil then self.rectangle40:destroy(); self.rectangle40 = nil; end;
        if self.label19 ~= nil then self.label19:destroy(); self.label19 = nil; end;
        if self.layout40 ~= nil then self.layout40:destroy(); self.layout40 = nil; end;
        if self.label124 ~= nil then self.label124:destroy(); self.label124 = nil; end;
        if self.label5 ~= nil then self.label5:destroy(); self.label5 = nil; end;
        if self.button14 ~= nil then self.button14:destroy(); self.button14 = nil; end;
        if self.label205 ~= nil then self.label205:destroy(); self.label205 = nil; end;
        if self.rectangle45 ~= nil then self.rectangle45:destroy(); self.rectangle45 = nil; end;
        if self.label12 ~= nil then self.label12:destroy(); self.label12 = nil; end;
        if self.label20 ~= nil then self.label20:destroy(); self.label20 = nil; end;
        if self.edit12 ~= nil then self.edit12:destroy(); self.edit12 = nil; end;
        if self.label87 ~= nil then self.label87:destroy(); self.label87 = nil; end;
        if self.layBottomflwMagicRecordList1 ~= nil then self.layBottomflwMagicRecordList1:destroy(); self.layBottomflwMagicRecordList1 = nil; end;
        if self.label108 ~= nil then self.label108:destroy(); self.label108 = nil; end;
        if self.label17 ~= nil then self.label17:destroy(); self.label17 = nil; end;
        if self.label27 ~= nil then self.label27:destroy(); self.label27 = nil; end;
        if self.edit17 ~= nil then self.edit17:destroy(); self.edit17 = nil; end;
        if self.aprimoramentos ~= nil then self.aprimoramentos:destroy(); self.aprimoramentos = nil; end;
        if self.label58 ~= nil then self.label58:destroy(); self.label58 = nil; end;
        if self.edit54 ~= nil then self.edit54:destroy(); self.edit54 = nil; end;
        if self.dataLink27 ~= nil then self.dataLink27:destroy(); self.dataLink27 = nil; end;
        if self.poderes ~= nil then self.poderes:destroy(); self.poderes = nil; end;
        if self.label131 ~= nil then self.label131:destroy(); self.label131 = nil; end;
        if self.ataquesPrincipal ~= nil then self.ataquesPrincipal:destroy(); self.ataquesPrincipal = nil; end;
        if self.layout86 ~= nil then self.layout86:destroy(); self.layout86 = nil; end;
        if self.rectangle7 ~= nil then self.rectangle7:destroy(); self.rectangle7 = nil; end;
        if self.label55 ~= nil then self.label55:destroy(); self.label55 = nil; end;
        if self.edit51 ~= nil then self.edit51:destroy(); self.edit51 = nil; end;
        if self.dataLink22 ~= nil then self.dataLink22:destroy(); self.dataLink22 = nil; end;
        if self.layout94 ~= nil then self.layout94:destroy(); self.layout94 = nil; end;
        if self.label190 ~= nil then self.label190:destroy(); self.label190 = nil; end;
        if self.popMagia ~= nil then self.popMagia:destroy(); self.popMagia = nil; end;
        if self.rectangle50 ~= nil then self.rectangle50:destroy(); self.rectangle50 = nil; end;
        if self.layout26 ~= nil then self.layout26:destroy(); self.layout26 = nil; end;
        if self.label106 ~= nil then self.label106:destroy(); self.label106 = nil; end;
        if self.label134 ~= nil then self.label134:destroy(); self.label134 = nil; end;
        if self.scrollBox3 ~= nil then self.scrollBox3:destroy(); self.scrollBox3 = nil; end;
        if self.layout81 ~= nil then self.layout81:destroy(); self.layout81 = nil; end;
        if self.layout91 ~= nil then self.layout91:destroy(); self.layout91 = nil; end;
        if self.layout109 ~= nil then self.layout109:destroy(); self.layout109 = nil; end;
        if self.btnNovoflwMagicRecordList9 ~= nil then self.btnNovoflwMagicRecordList9:destroy(); self.btnNovoflwMagicRecordList9 = nil; end;
        if self.scrollBox4 ~= nil then self.scrollBox4:destroy(); self.scrollBox4 = nil; end;
        if self.textEditor5 ~= nil then self.textEditor5:destroy(); self.textEditor5 = nil; end;
        if self.label227 ~= nil then self.label227:destroy(); self.label227 = nil; end;
        if self.rectangle28 ~= nil then self.rectangle28:destroy(); self.rectangle28 = nil; end;
        if self.rectangle57 ~= nil then self.rectangle57:destroy(); self.rectangle57 = nil; end;
        if self.label74 ~= nil then self.label74:destroy(); self.label74 = nil; end;
        if self.label144 ~= nil then self.label144:destroy(); self.label144 = nil; end;
        if self.dataLink17 ~= nil then self.dataLink17:destroy(); self.dataLink17 = nil; end;
        if self.layout102 ~= nil then self.layout102:destroy(); self.layout102 = nil; end;
        if self.btnNovoflwMagicRecordList2 ~= nil then self.btnNovoflwMagicRecordList2:destroy(); self.btnNovoflwMagicRecordList2 = nil; end;
        if self.label212 ~= nil then self.label212:destroy(); self.label212 = nil; end;
        if self.rectangle25 ~= nil then self.rectangle25:destroy(); self.rectangle25 = nil; end;
        if self.rectangle11 ~= nil then self.rectangle11:destroy(); self.rectangle11 = nil; end;
        if self.layout28 ~= nil then self.layout28:destroy(); self.layout28 = nil; end;
        if self.label71 ~= nil then self.label71:destroy(); self.label71 = nil; end;
        if self.label141 ~= nil then self.label141:destroy(); self.label141 = nil; end;
        if self.edit76 ~= nil then self.edit76:destroy(); self.edit76 = nil; end;
        if self.edit44 ~= nil then self.edit44:destroy(); self.edit44 = nil; end;
        if self.flowPart1 ~= nil then self.flowPart1:destroy(); self.flowPart1 = nil; end;
        if self.label217 ~= nil then self.label217:destroy(); self.label217 = nil; end;
        if self.label113 ~= nil then self.label113:destroy(); self.label113 = nil; end;
        if self.rectangle84 ~= nil then self.rectangle84:destroy(); self.rectangle84 = nil; end;
        if self.label90 ~= nil then self.label90:destroy(); self.label90 = nil; end;
        if self.dataLink19 ~= nil then self.dataLink19:destroy(); self.dataLink19 = nil; end;
        if self.edit43 ~= nil then self.edit43:destroy(); self.edit43 = nil; end;
        if self.flowPart6 ~= nil then self.flowPart6:destroy(); self.flowPart6 = nil; end;
        if self.edit73 ~= nil then self.edit73:destroy(); self.edit73 = nil; end;
        if self.rectangle72 ~= nil then self.rectangle72:destroy(); self.rectangle72 = nil; end;
        if self.rectangle91 ~= nil then self.rectangle91:destroy(); self.rectangle91 = nil; end;
        if self.label116 ~= nil then self.label116:destroy(); self.label116 = nil; end;
        if self.rectangle81 ~= nil then self.rectangle81:destroy(); self.rectangle81 = nil; end;
        if self.label95 ~= nil then self.label95:destroy(); self.label95 = nil; end;
        if self.label160 ~= nil then self.label160:destroy(); self.label160 = nil; end;
        if self.flowLineBreak3 ~= nil then self.flowLineBreak3:destroy(); self.flowLineBreak3 = nil; end;
        if self.rectangle75 ~= nil then self.rectangle75:destroy(); self.rectangle75 = nil; end;
        if self.label64 ~= nil then self.label64:destroy(); self.label64 = nil; end;
        if self.label119 ~= nil then self.label119:destroy(); self.label119 = nil; end;
        if self.edit20 ~= nil then self.edit20:destroy(); self.edit20 = nil; end;
        if self.layout74 ~= nil then self.layout74:destroy(); self.layout74 = nil; end;
        if self.layout39 ~= nil then self.layout39:destroy(); self.layout39 = nil; end;
        if self.dataLink35 ~= nil then self.dataLink35:destroy(); self.dataLink35 = nil; end;
        if self.label183 ~= nil then self.label183:destroy(); self.label183 = nil; end;
        if self.layout112 ~= nil then self.layout112:destroy(); self.layout112 = nil; end;
        if self.comboBox5 ~= nil then self.comboBox5:destroy(); self.comboBox5 = nil; end;
        if self.rectangle78 ~= nil then self.rectangle78:destroy(); self.rectangle78 = nil; end;
        if self.rectangle33 ~= nil then self.rectangle33:destroy(); self.rectangle33 = nil; end;
        if self.rectangle122 ~= nil then self.rectangle122:destroy(); self.rectangle122 = nil; end;
        if self.comboBox2 ~= nil then self.comboBox2:destroy(); self.comboBox2 = nil; end;
        if self.label63 ~= nil then self.label63:destroy(); self.label63 = nil; end;
        if self.label184 ~= nil then self.label184:destroy(); self.label184 = nil; end;
        if self.edit66 ~= nil then self.edit66:destroy(); self.edit66 = nil; end;
        if self.layout36 ~= nil then self.layout36:destroy(); self.layout36 = nil; end;
        if self.rectangle108 ~= nil then self.rectangle108:destroy(); self.rectangle108 = nil; end;
        if self.label175 ~= nil then self.label175:destroy(); self.label175 = nil; end;
        if self.bag ~= nil then self.bag:destroy(); self.bag = nil; end;
        if self.layout58 ~= nil then self.layout58:destroy(); self.layout58 = nil; end;
        if self.label189 ~= nil then self.label189:destroy(); self.label189 = nil; end;
        if self.edit61 ~= nil then self.edit61:destroy(); self.edit61 = nil; end;
        if self.layout33 ~= nil then self.layout33:destroy(); self.layout33 = nil; end;
        if self.rectangle107 ~= nil then self.rectangle107:destroy(); self.rectangle107 = nil; end;
        if self.rectangle117 ~= nil then self.rectangle117:destroy(); self.rectangle117 = nil; end;
        if self.label170 ~= nil then self.label170:destroy(); self.label170 = nil; end;
        if self.rectangle39 ~= nil then self.rectangle39:destroy(); self.rectangle39 = nil; end;
        if self.label38 ~= nil then self.label38:destroy(); self.label38 = nil; end;
        if self.layout61 ~= nil then self.layout61:destroy(); self.layout61 = nil; end;
        if self.button9 ~= nil then self.button9:destroy(); self.button9 = nil; end;
        if self.image10 ~= nil then self.image10:destroy(); self.image10 = nil; end;
        if self.dataLink1 ~= nil then self.dataLink1:destroy(); self.dataLink1 = nil; end;
        if self.rectangle102 ~= nil then self.rectangle102:destroy(); self.rectangle102 = nil; end;
        if self.flowPart11 ~= nil then self.flowPart11:destroy(); self.flowPart11 = nil; end;
        if self.label46 ~= nil then self.label46:destroy(); self.label46 = nil; end;
        if self.rectangle69 ~= nil then self.rectangle69:destroy(); self.rectangle69 = nil; end;
        if self.layout56 ~= nil then self.layout56:destroy(); self.layout56 = nil; end;
        if self.layout64 ~= nil then self.layout64:destroy(); self.layout64 = nil; end;
        if self.edit7 ~= nil then self.edit7:destroy(); self.edit7 = nil; end;
        if self.flwMagicRecordList6 ~= nil then self.flwMagicRecordList6:destroy(); self.flwMagicRecordList6 = nil; end;
        if self.dataLink50 ~= nil then self.dataLink50:destroy(); self.dataLink50 = nil; end;
        if self.flowLayout7 ~= nil then self.flowLayout7:destroy(); self.flowLayout7 = nil; end;
        if self.rectangle119 ~= nil then self.rectangle119:destroy(); self.rectangle119 = nil; end;
        if self.label41 ~= nil then self.label41:destroy(); self.label41 = nil; end;
        if self.flowPart14 ~= nil then self.flowPart14:destroy(); self.flowPart14 = nil; end;
        if self.rectangle62 ~= nil then self.rectangle62:destroy(); self.rectangle62 = nil; end;
        if self.tab5 ~= nil then self.tab5:destroy(); self.tab5 = nil; end;
        if self.layout14 ~= nil then self.layout14:destroy(); self.layout14 = nil; end;
        if self.label32 ~= nil then self.label32:destroy(); self.label32 = nil; end;
        if self.button7 ~= nil then self.button7:destroy(); self.button7 = nil; end;
        if self.dataLink45 ~= nil then self.dataLink45:destroy(); self.dataLink45 = nil; end;
        if self.flwMagicRecordList3 ~= nil then self.flwMagicRecordList3:destroy(); self.flwMagicRecordList3 = nil; end;
        if self.layout8 ~= nil then self.layout8:destroy(); self.layout8 = nil; end;
        if self.image5 ~= nil then self.image5:destroy(); self.image5 = nil; end;
        if self.flowLayout2 ~= nil then self.flowLayout2:destroy(); self.flowLayout2 = nil; end;
        if self.rectangle48 ~= nil then self.rectangle48:destroy(); self.rectangle48 = nil; end;
        if self.label157 ~= nil then self.label157:destroy(); self.label157 = nil; end;
        if self.rclflwMagicRecordList7 ~= nil then self.rclflwMagicRecordList7:destroy(); self.rclflwMagicRecordList7 = nil; end;
        if self.rectangle67 ~= nil then self.rectangle67:destroy(); self.rectangle67 = nil; end;
        if self.image21 ~= nil then self.image21:destroy(); self.image21 = nil; end;
        if self.layout11 ~= nil then self.layout11:destroy(); self.layout11 = nil; end;
        if self.label37 ~= nil then self.label37:destroy(); self.label37 = nil; end;
        if self.edit30 ~= nil then self.edit30:destroy(); self.edit30 = nil; end;
        if self.layout3 ~= nil then self.layout3:destroy(); self.layout3 = nil; end;
        if self.label152 ~= nil then self.label152:destroy(); self.label152 = nil; end;
        if self.flowLayout9 ~= nil then self.flowLayout9:destroy(); self.flowLayout9 = nil; end;
        if self.layout43 ~= nil then self.layout43:destroy(); self.layout43 = nil; end;
        if self.label121 ~= nil then self.label121:destroy(); self.label121 = nil; end;
        if self.label200 ~= nil then self.label200:destroy(); self.label200 = nil; end;
        if self.button11 ~= nil then self.button11:destroy(); self.button11 = nil; end;
        if self.flowLayout10 ~= nil then self.flowLayout10:destroy(); self.flowLayout10 = nil; end;
        if self.layBottomflwMagicRecordList9 ~= nil then self.layBottomflwMagicRecordList9:destroy(); self.layBottomflwMagicRecordList9 = nil; end;
        if self.edit35 ~= nil then self.edit35:destroy(); self.edit35 = nil; end;
        if self.flwMagicRecordList9 ~= nil then self.flwMagicRecordList9:destroy(); self.flwMagicRecordList9 = nil; end;
        if self.rectangle42 ~= nil then self.rectangle42:destroy(); self.rectangle42 = nil; end;
        if self.layout46 ~= nil then self.layout46:destroy(); self.layout46 = nil; end;
        if self.label126 ~= nil then self.label126:destroy(); self.label126 = nil; end;
        if self.label207 ~= nil then self.label207:destroy(); self.label207 = nil; end;
        if self.label82 ~= nil then self.label82:destroy(); self.label82 = nil; end;
        if self.layBottomflwMagicRecordList4 ~= nil then self.layBottomflwMagicRecordList4:destroy(); self.layBottomflwMagicRecordList4 = nil; end;
        if self.rectangle47 ~= nil then self.rectangle47:destroy(); self.rectangle47 = nil; end;
        if self.label158 ~= nil then self.label158:destroy(); self.label158 = nil; end;
        if self.label10 ~= nil then self.label10:destroy(); self.label10 = nil; end;
        if self.label22 ~= nil then self.label22:destroy(); self.label22 = nil; end;
        if self.edit14 ~= nil then self.edit14:destroy(); self.edit14 = nil; end;
        if self.layout49 ~= nil then self.layout49:destroy(); self.layout49 = nil; end;
        if self.edit59 ~= nil then self.edit59:destroy(); self.edit59 = nil; end;
        if self.label85 ~= nil then self.label85:destroy(); self.label85 = nil; end;
        if self.label198 ~= nil then self.label198:destroy(); self.label198 = nil; end;
        if self.layBottomflwMagicRecordList3 ~= nil then self.layBottomflwMagicRecordList3:destroy(); self.layBottomflwMagicRecordList3 = nil; end;
        if self.layout89 ~= nil then self.layout89:destroy(); self.layout89 = nil; end;
        if self.label15 ~= nil then self.label15:destroy(); self.label15 = nil; end;
        if self.rectangle4 ~= nil then self.rectangle4:destroy(); self.rectangle4 = nil; end;
        if self.label29 ~= nil then self.label29:destroy(); self.label29 = nil; end;
        if self.label56 ~= nil then self.label56:destroy(); self.label56 = nil; end;
        if self.edit56 ~= nil then self.edit56:destroy(); self.edit56 = nil; end;
        if self.dataLink25 ~= nil then self.dataLink25:destroy(); self.dataLink25 = nil; end;
        if self.label193 ~= nil then self.label193:destroy(); self.label193 = nil; end;
        if self.layout25 ~= nil then self.layout25:destroy(); self.layout25 = nil; end;
        if self.label103 ~= nil then self.label103:destroy(); self.label103 = nil; end;
        if self.label133 ~= nil then self.label133:destroy(); self.label133 = nil; end;
        if self.imgBolsaCheia ~= nil then self.imgBolsaCheia:destroy(); self.imgBolsaCheia = nil; end;
        if self.layout84 ~= nil then self.layout84:destroy(); self.layout84 = nil; end;
        if self.rectangle1 ~= nil then self.rectangle1:destroy(); self.rectangle1 = nil; end;
        if self.label53 ~= nil then self.label53:destroy(); self.label53 = nil; end;
        if self.edit53 ~= nil then self.edit53:destroy(); self.edit53 = nil; end;
        if self.dataLink20 ~= nil then self.dataLink20:destroy(); self.dataLink20 = nil; end;
        if self.layout92 ~= nil then self.layout92:destroy(); self.layout92 = nil; end;
        if self.label196 ~= nil then self.label196:destroy(); self.label196 = nil; end;
        if self.rectangle52 ~= nil then self.rectangle52:destroy(); self.rectangle52 = nil; end;
        if self.label222 ~= nil then self.label222:destroy(); self.label222 = nil; end;
        if self.layout20 ~= nil then self.layout20:destroy(); self.layout20 = nil; end;
        if self.label79 ~= nil then self.label79:destroy(); self.label79 = nil; end;
        if self.label104 ~= nil then self.label104:destroy(); self.label104 = nil; end;
        if self.dataLink14 ~= nil then self.dataLink14:destroy(); self.dataLink14 = nil; end;
        if self.label136 ~= nil then self.label136:destroy(); self.label136 = nil; end;
        if self.label149 ~= nil then self.label149:destroy(); self.label149 = nil; end;
        if self.layout107 ~= nil then self.layout107:destroy(); self.layout107 = nil; end;
        if self.btnNovoflwMagicRecordList7 ~= nil then self.btnNovoflwMagicRecordList7:destroy(); self.btnNovoflwMagicRecordList7 = nil; end;
        if self.label225 ~= nil then self.label225:destroy(); self.label225 = nil; end;
        if self.rectangle26 ~= nil then self.rectangle26:destroy(); self.rectangle26 = nil; end;
        if self.rectangle14 ~= nil then self.rectangle14:destroy(); self.rectangle14 = nil; end;
        if self.label76 ~= nil then self.label76:destroy(); self.label76 = nil; end;
        if self.rectangle59 ~= nil then self.rectangle59:destroy(); self.rectangle59 = nil; end;
        if self.label142 ~= nil then self.label142:destroy(); self.label142 = nil; end;
        if self.dataLink11 ~= nil then self.dataLink11:destroy(); self.dataLink11 = nil; end;
        if self.layout98 ~= nil then self.layout98:destroy(); self.layout98 = nil; end;
        if self.layout100 ~= nil then self.layout100:destroy(); self.layout100 = nil; end;
        if self.rectangle99 ~= nil then self.rectangle99:destroy(); self.rectangle99 = nil; end;
        if self.rectangle23 ~= nil then self.rectangle23:destroy(); self.rectangle23 = nil; end;
        if self.rectangle13 ~= nil then self.rectangle13:destroy(); self.rectangle13 = nil; end;
        if self.label73 ~= nil then self.label73:destroy(); self.label73 = nil; end;
        if self.label168 ~= nil then self.label168:destroy(); self.label168 = nil; end;
        if self.label214 ~= nil then self.label214:destroy(); self.label214 = nil; end;
        if self.edit74 ~= nil then self.edit74:destroy(); self.edit74 = nil; end;
        if self.edit46 ~= nil then self.edit46:destroy(); self.edit46 = nil; end;
        if self.flowPart3 ~= nil then self.flowPart3:destroy(); self.flowPart3 = nil; end;
        if self.rectangle94 ~= nil then self.rectangle94:destroy(); self.rectangle94 = nil; end;
        if self.label111 ~= nil then self.label111:destroy(); self.label111 = nil; end;
        if self.rectangle86 ~= nil then self.rectangle86:destroy(); self.rectangle86 = nil; end;
        if self.label96 ~= nil then self.label96:destroy(); self.label96 = nil; end;
        if self.label165 ~= nil then self.label165:destroy(); self.label165 = nil; end;
        if self.frmTemplateDescription ~= nil then self.frmTemplateDescription:destroy(); self.frmTemplateDescription = nil; end;
        if self.edit71 ~= nil then self.edit71:destroy(); self.edit71 = nil; end;
        if self.flowPart8 ~= nil then self.flowPart8:destroy(); self.flowPart8 = nil; end;
        if self.label219 ~= nil then self.label219:destroy(); self.label219 = nil; end;
        if self.rectangle70 ~= nil then self.rectangle70:destroy(); self.rectangle70 = nil; end;
        if self.rectangle93 ~= nil then self.rectangle93:destroy(); self.rectangle93 = nil; end;
        if self.flowLineBreak1 ~= nil then self.flowLineBreak1:destroy(); self.flowLineBreak1 = nil; end;
        if self.edit23 ~= nil then self.edit23:destroy(); self.edit23 = nil; end;
        if self.layout71 ~= nil then self.layout71:destroy(); self.layout71 = nil; end;
        if self.label114 ~= nil then self.label114:destroy(); self.label114 = nil; end;
        if self.rectangle83 ~= nil then self.rectangle83:destroy(); self.rectangle83 = nil; end;
        if self.tabControl1 ~= nil then self.tabControl1:destroy(); self.tabControl1 = nil; end;
        if self.edit48 ~= nil then self.edit48:destroy(); self.edit48 = nil; end;
        if self.dataLink36 ~= nil then self.dataLink36:destroy(); self.dataLink36 = nil; end;
        if self.label162 ~= nil then self.label162:destroy(); self.label162 = nil; end;
        if self.layout115 ~= nil then self.layout115:destroy(); self.layout115 = nil; end;
        if self.rectangle36 ~= nil then self.rectangle36:destroy(); self.rectangle36 = nil; end;
        if self.rectangle125 ~= nil then self.rectangle125:destroy(); self.rectangle125 = nil; end;
        if self.label66 ~= nil then self.label66:destroy(); self.label66 = nil; end;
        if self.rectangle88 ~= nil then self.rectangle88:destroy(); self.rectangle88 = nil; end;
        if self.edit26 ~= nil then self.edit26:destroy(); self.edit26 = nil; end;
        if self.layout76 ~= nil then self.layout76:destroy(); self.layout76 = nil; end;
        if self.dataLink33 ~= nil then self.dataLink33:destroy(); self.dataLink33 = nil; end;
        if self.label181 ~= nil then self.label181:destroy(); self.label181 = nil; end;
        if self.layout110 ~= nil then self.layout110:destroy(); self.layout110 = nil; end;
        if self.comboBox7 ~= nil then self.comboBox7:destroy(); self.comboBox7 = nil; end;
        if self.rectangle31 ~= nil then self.rectangle31:destroy(); self.rectangle31 = nil; end;
        if self.rectangle120 ~= nil then self.rectangle120:destroy(); self.rectangle120 = nil; end;
        if self.edit8 ~= nil then self.edit8:destroy(); self.edit8 = nil; end;
        if self.edit29 ~= nil then self.edit29:destroy(); self.edit29 = nil; end;
        if self.image18 ~= nil then self.image18:destroy(); self.image18 = nil; end;
        if self.layout30 ~= nil then self.layout30:destroy(); self.layout30 = nil; end;
        if self.edit64 ~= nil then self.edit64:destroy(); self.edit64 = nil; end;
        if self.rectangle114 ~= nil then self.rectangle114:destroy(); self.rectangle114 = nil; end;
        if self.label177 ~= nil then self.label177:destroy(); self.label177 = nil; end;
        if self.label68 ~= nil then self.label68:destroy(); self.label68 = nil; end;
        if self.dataLink39 ~= nil then self.dataLink39:destroy(); self.dataLink39 = nil; end;
        if self.image13 ~= nil then self.image13:destroy(); self.image13 = nil; end;
        if self.dataLink4 ~= nil then self.dataLink4:destroy(); self.dataLink4 = nil; end;
        if self.rectangle101 ~= nil then self.rectangle101:destroy(); self.rectangle101 = nil; end;
        if self.rectangle111 ~= nil then self.rectangle111:destroy(); self.rectangle111 = nil; end;
        if self.label172 ~= nil then self.label172:destroy(); self.label172 = nil; end;
        if self.layout53 ~= nil then self.layout53:destroy(); self.layout53 = nil; end;
        if self.layout63 ~= nil then self.layout63:destroy(); self.layout63 = nil; end;
        if self.edit2 ~= nil then self.edit2:destroy(); self.edit2 = nil; end;
        if self.image16 ~= nil then self.image16:destroy(); self.image16 = nil; end;
        if self.dataLink3 ~= nil then self.dataLink3:destroy(); self.dataLink3 = nil; end;
        if self.flowPart13 ~= nil then self.flowPart13:destroy(); self.flowPart13 = nil; end;
        if self.label44 ~= nil then self.label44:destroy(); self.label44 = nil; end;
        if self.label179 ~= nil then self.label179:destroy(); self.label179 = nil; end;
        if self.tab6 ~= nil then self.tab6:destroy(); self.tab6 = nil; end;
        if self.layout54 ~= nil then self.layout54:destroy(); self.layout54 = nil; end;
        if self.layout19 ~= nil then self.layout19:destroy(); self.layout19 = nil; end;
        if self.layout66 ~= nil then self.layout66:destroy(); self.layout66 = nil; end;
        if self.button2 ~= nil then self.button2:destroy(); self.button2 = nil; end;
        if self.cbxAtribResist ~= nil then self.cbxAtribResist:destroy(); self.cbxAtribResist = nil; end;
        if self.edit38 ~= nil then self.edit38:destroy(); self.edit38 = nil; end;
        if self.image6 ~= nil then self.image6:destroy(); self.image6 = nil; end;
        if self.flowLayout1 ~= nil then self.flowLayout1:destroy(); self.flowLayout1 = nil; end;
        if self.dataLink40 ~= nil then self.dataLink40:destroy(); self.dataLink40 = nil; end;
        if self.flwMagicRecordList4 ~= nil then self.flwMagicRecordList4:destroy(); self.flwMagicRecordList4 = nil; end;
        if self.flowPart16 ~= nil then self.flowPart16:destroy(); self.flowPart16 = nil; end;
        if self.label129 ~= nil then self.label129:destroy(); self.label129 = nil; end;
        if self.rectangle60 ~= nil then self.rectangle60:destroy(); self.rectangle60 = nil; end;
        if self.label8 ~= nil then self.label8:destroy(); self.label8 = nil; end;
        if self.layout12 ~= nil then self.layout12:destroy(); self.layout12 = nil; end;
        if self.label34 ~= nil then self.label34:destroy(); self.label34 = nil; end;
        if self.frmPrincipal ~= nil then self.frmPrincipal:destroy(); self.frmPrincipal = nil; end;
        if self.button5 ~= nil then self.button5:destroy(); self.button5 = nil; end;
        if self.flwMagicRecordList1 ~= nil then self.flwMagicRecordList1:destroy(); self.flwMagicRecordList1 = nil; end;
        if self.layout6 ~= nil then self.layout6:destroy(); self.layout6 = nil; end;
        if self.label155 ~= nil then self.label155:destroy(); self.label155 = nil; end;
        if self.rclflwMagicRecordList2 ~= nil then self.rclflwMagicRecordList2:destroy(); self.rclflwMagicRecordList2 = nil; end;
        if self.label208 ~= nil then self.label208:destroy(); self.label208 = nil; end;
        if self.dataLink47 ~= nil then self.dataLink47:destroy(); self.dataLink47 = nil; end;
        if self.rclflwMagicRecordList5 ~= nil then self.rclflwMagicRecordList5:destroy(); self.rclflwMagicRecordList5 = nil; end;
        if self.rectangle65 ~= nil then self.rectangle65:destroy(); self.rectangle65 = nil; end;
        if self.label3 ~= nil then self.label3:destroy(); self.label3 = nil; end;
        if self.button12 ~= nil then self.button12:destroy(); self.button12 = nil; end;
        if self.button19 ~= nil then self.button19:destroy(); self.button19 = nil; end;
        if self.button20 ~= nil then self.button20:destroy(); self.button20 = nil; end;
        if self.edit36 ~= nil then self.edit36:destroy(); self.edit36 = nil; end;
        if self.layout1 ~= nil then self.layout1:destroy(); self.layout1 = nil; end;
        if self.label150 ~= nil then self.label150:destroy(); self.label150 = nil; end;
        if self.label18 ~= nil then self.label18:destroy(); self.label18 = nil; end;
        if self.layout41 ~= nil then self.layout41:destroy(); self.layout41 = nil; end;
        if self.label123 ~= nil then self.label123:destroy(); self.label123 = nil; end;
        if self.label6 ~= nil then self.label6:destroy(); self.label6 = nil; end;
        if self.label202 ~= nil then self.label202:destroy(); self.label202 = nil; end;
        if self.rclflwMagicRecordList8 ~= nil then self.rclflwMagicRecordList8:destroy(); self.rclflwMagicRecordList8 = nil; end;
        if self.flowLayout12 ~= nil then self.flowLayout12:destroy(); self.flowLayout12 = nil; end;
        if self.button17 ~= nil then self.button17:destroy(); self.button17 = nil; end;
        if self.rectangle44 ~= nil then self.rectangle44:destroy(); self.rectangle44 = nil; end;
        if self.layout44 ~= nil then self.layout44:destroy(); self.layout44 = nil; end;
        if self.label21 ~= nil then self.label21:destroy(); self.label21 = nil; end;
        if self.edit11 ~= nil then self.edit11:destroy(); self.edit11 = nil; end;
        if self.label80 ~= nil then self.label80:destroy(); self.label80 = nil; end;
        if self.layBottomflwMagicRecordList6 ~= nil then self.layBottomflwMagicRecordList6:destroy(); self.layBottomflwMagicRecordList6 = nil; end;
        if self.label16 ~= nil then self.label16:destroy(); self.label16 = nil; end;
        if self.label24 ~= nil then self.label24:destroy(); self.label24 = nil; end;
        if self.rectangle9 ~= nil then self.rectangle9:destroy(); self.rectangle9 = nil; end;
        if self.edit16 ~= nil then self.edit16:destroy(); self.edit16 = nil; end;
        if self.dataLink28 ~= nil then self.dataLink28:destroy(); self.dataLink28 = nil; end;
        if self.layout87 ~= nil then self.layout87:destroy(); self.layout87 = nil; end;
        if self.layout97 ~= nil then self.layout97:destroy(); self.layout97 = nil; end;
        if self.rectangle6 ~= nil then self.rectangle6:destroy(); self.rectangle6 = nil; end;
        if self.label54 ~= nil then self.label54:destroy(); self.label54 = nil; end;
        if self.edit50 ~= nil then self.edit50:destroy(); self.edit50 = nil; end;
        if self.textEditor2 ~= nil then self.textEditor2:destroy(); self.textEditor2 = nil; end;
        if self.dataLink23 ~= nil then self.dataLink23:destroy(); self.dataLink23 = nil; end;
        if self.label191 ~= nil then self.label191:destroy(); self.label191 = nil; end;
        if self.rectangle51 ~= nil then self.rectangle51:destroy(); self.rectangle51 = nil; end;
        if self.scrollBox5 ~= nil then self.scrollBox5:destroy(); self.scrollBox5 = nil; end;
        if self.layout27 ~= nil then self.layout27:destroy(); self.layout27 = nil; end;
        if self.label101 ~= nil then self.label101:destroy(); self.label101 = nil; end;
        if self.label135 ~= nil then self.label135:destroy(); self.label135 = nil; end;
        if self.layout82 ~= nil then self.layout82:destroy(); self.layout82 = nil; end;
        if self.layout90 ~= nil then self.layout90:destroy(); self.layout90 = nil; end;
        if self.rectangle3 ~= nil then self.rectangle3:destroy(); self.rectangle3 = nil; end;
        if self.label51 ~= nil then self.label51:destroy(); self.label51 = nil; end;
        if self.layout108 ~= nil then self.layout108:destroy(); self.layout108 = nil; end;
        if self.label194 ~= nil then self.label194:destroy(); self.label194 = nil; end;
        if self.btnNovoflwMagicRecordList8 ~= nil then self.btnNovoflwMagicRecordList8:destroy(); self.btnNovoflwMagicRecordList8 = nil; end;
        if self.label220 ~= nil then self.label220:destroy(); self.label220 = nil; end;
        if self.rectangle54 ~= nil then self.rectangle54:destroy(); self.rectangle54 = nil; end;
        if self.layout22 ~= nil then self.layout22:destroy(); self.layout22 = nil; end;
        if self.label138 ~= nil then self.label138:destroy(); self.label138 = nil; end;
        if self.dataLink16 ~= nil then self.dataLink16:destroy(); self.dataLink16 = nil; end;
        if self.label147 ~= nil then self.label147:destroy(); self.label147 = nil; end;
        if self.layout105 ~= nil then self.layout105:destroy(); self.layout105 = nil; end;
        if self.btnNovoflwMagicRecordList5 ~= nil then self.btnNovoflwMagicRecordList5:destroy(); self.btnNovoflwMagicRecordList5 = nil; end;
        if self.label211 ~= nil then self.label211:destroy(); self.label211 = nil; end;
        if self.rectangle24 ~= nil then self.rectangle24:destroy(); self.rectangle24 = nil; end;
        if self.rectangle16 ~= nil then self.rectangle16:destroy(); self.rectangle16 = nil; end;
        if self.layout29 ~= nil then self.layout29:destroy(); self.layout29 = nil; end;
        if self.label70 ~= nil then self.label70:destroy(); self.label70 = nil; end;
        if self.label140 ~= nil then self.label140:destroy(); self.label140 = nil; end;
        if self.dataLink13 ~= nil then self.dataLink13:destroy(); self.dataLink13 = nil; end;
        if self.edit45 ~= nil then self.edit45:destroy(); self.edit45 = nil; end;
        if self.fraMagiasLayout ~= nil then self.fraMagiasLayout:destroy(); self.fraMagiasLayout = nil; end;
        if self.label216 ~= nil then self.label216:destroy(); self.label216 = nil; end;
        if self.rectangle21 ~= nil then self.rectangle21:destroy(); self.rectangle21 = nil; end;
        if self.label93 ~= nil then self.label93:destroy(); self.label93 = nil; end;
        if self.layout79 ~= nil then self.layout79:destroy(); self.layout79 = nil; end;
        if self.dataLink18 ~= nil then self.dataLink18:destroy(); self.dataLink18 = nil; end;
        if self.edit40 ~= nil then self.edit40:destroy(); self.edit40 = nil; end;
        if self.flowPart5 ~= nil then self.flowPart5:destroy(); self.flowPart5 = nil; end;
        if self.edit72 ~= nil then self.edit72:destroy(); self.edit72 = nil; end;
        if self.rectangle73 ~= nil then self.rectangle73:destroy(); self.rectangle73 = nil; end;
        if self.imgBolsaMetade ~= nil then self.imgBolsaMetade:destroy(); self.imgBolsaMetade = nil; end;
        if self.rectangle96 ~= nil then self.rectangle96:destroy(); self.rectangle96 = nil; end;
        if self.flowLineBreak2 ~= nil then self.flowLineBreak2:destroy(); self.flowLineBreak2 = nil; end;
        if self.rectangle18 ~= nil then self.rectangle18:destroy(); self.rectangle18 = nil; end;
        if self.label94 ~= nil then self.label94:destroy(); self.label94 = nil; end;
        if self.label117 ~= nil then self.label117:destroy(); self.label117 = nil; end;
        if self.rectangle80 ~= nil then self.rectangle80:destroy(); self.rectangle80 = nil; end;
        if self.label167 ~= nil then self.label167:destroy(); self.label167 = nil; end;
        if self.rectangle76 ~= nil then self.rectangle76:destroy(); self.rectangle76 = nil; end;
        if self.label65 ~= nil then self.label65:destroy(); self.label65 = nil; end;
        if self.label182 ~= nil then self.label182:destroy(); self.label182 = nil; end;
        if self.edit21 ~= nil then self.edit21:destroy(); self.edit21 = nil; end;
        if self.label99 ~= nil then self.label99:destroy(); self.label99 = nil; end;
        if self.layout38 ~= nil then self.layout38:destroy(); self.layout38 = nil; end;
        if self.layout73 ~= nil then self.layout73:destroy(); self.layout73 = nil; end;
        if self.dataLink34 ~= nil then self.dataLink34:destroy(); self.dataLink34 = nil; end;
        if self.layout113 ~= nil then self.layout113:destroy(); self.layout113 = nil; end;
        if self.comboBox4 ~= nil then self.comboBox4:destroy(); self.comboBox4 = nil; end;
        if self.rectangle79 ~= nil then self.rectangle79:destroy(); self.rectangle79 = nil; end;
        if self.rectangle34 ~= nil then self.rectangle34:destroy(); self.rectangle34 = nil; end;
        if self.rectangle123 ~= nil then self.rectangle123:destroy(); self.rectangle123 = nil; end;
        if self.comboBox1 ~= nil then self.comboBox1:destroy(); self.comboBox1 = nil; end;
        if self.label60 ~= nil then self.label60:destroy(); self.label60 = nil; end;
        if self.edit24 ~= nil then self.edit24:destroy(); self.edit24 = nil; end;
        if self.edit67 ~= nil then self.edit67:destroy(); self.edit67 = nil; end;
        if self.layout35 ~= nil then self.layout35:destroy(); self.layout35 = nil; end;
        if self.dataLink31 ~= nil then self.dataLink31:destroy(); self.dataLink31 = nil; end;
        if self.label187 ~= nil then self.label187:destroy(); self.label187 = nil; end;
        if self.rectangle109 ~= nil then self.rectangle109:destroy(); self.rectangle109 = nil; end;
        if self.label188 ~= nil then self.label188:destroy(); self.label188 = nil; end;
        if self.edit62 ~= nil then self.edit62:destroy(); self.edit62 = nil; end;
        if self.layout32 ~= nil then self.layout32:destroy(); self.layout32 = nil; end;
        if self.rectangle104 ~= nil then self.rectangle104:destroy(); self.rectangle104 = nil; end;
        if self.rectangle116 ~= nil then self.rectangle116:destroy(); self.rectangle116 = nil; end;
        if self.label171 ~= nil then self.label171:destroy(); self.label171 = nil; end;
        if self.horzLine1 ~= nil then self.horzLine1:destroy(); self.horzLine1 = nil; end;
        if self.edit1 ~= nil then self.edit1:destroy(); self.edit1 = nil; end;
        if self.dataLink48 ~= nil then self.dataLink48:destroy(); self.dataLink48 = nil; end;
        if self.image11 ~= nil then self.image11:destroy(); self.image11 = nil; end;
        if self.dataLink6 ~= nil then self.dataLink6:destroy(); self.dataLink6 = nil; end;
        if self.rectangle103 ~= nil then self.rectangle103:destroy(); self.rectangle103 = nil; end;
        if self.rectangle113 ~= nil then self.rectangle113:destroy(); self.rectangle113 = nil; end;
        if self.label47 ~= nil then self.label47:destroy(); self.label47 = nil; end;
        if self.tab3 ~= nil then self.tab3:destroy(); self.tab3 = nil; end;
        if self.rectangle68 ~= nil then self.rectangle68:destroy(); self.rectangle68 = nil; end;
        if self.layout51 ~= nil then self.layout51:destroy(); self.layout51 = nil; end;
        if self.layout65 ~= nil then self.layout65:destroy(); self.layout65 = nil; end;
        if self.edit4 ~= nil then self.edit4:destroy(); self.edit4 = nil; end;
        if self.image14 ~= nil then self.image14:destroy(); self.image14 = nil; end;
        if self.edit68 ~= nil then self.edit68:destroy(); self.edit68 = nil; end;
        if self.image3 ~= nil then self.image3:destroy(); self.image3 = nil; end;
        if self.frmPericias ~= nil then self.frmPericias:destroy(); self.frmPericias = nil; end;
        if self.flowLayout4 ~= nil then self.flowLayout4:destroy(); self.flowLayout4 = nil; end;
        if self.rectangle118 ~= nil then self.rectangle118:destroy(); self.rectangle118 = nil; end;
        if self.label42 ~= nil then self.label42:destroy(); self.label42 = nil; end;
        if self.flowPart15 ~= nil then self.flowPart15:destroy(); self.flowPart15 = nil; end;
        if self.tab4 ~= nil then self.tab4:destroy(); self.tab4 = nil; end;
        if self.image20 ~= nil then self.image20:destroy(); self.image20 = nil; end;
        if self.layout17 ~= nil then self.layout17:destroy(); self.layout17 = nil; end;
        if self.label31 ~= nil then self.label31:destroy(); self.label31 = nil; end;
        if self.layout68 ~= nil then self.layout68:destroy(); self.layout68 = nil; end;
        if self.dataLink42 ~= nil then self.dataLink42:destroy(); self.dataLink42 = nil; end;
        if self.dataLink8 ~= nil then self.dataLink8:destroy(); self.dataLink8 = nil; end;
        if self.layout9 ~= nil then self.layout9:destroy(); self.layout9 = nil; end;
        if self.image4 ~= nil then self.image4:destroy(); self.image4 = nil; end;
        if self.flowLayout3 ~= nil then self.flowLayout3:destroy(); self.flowLayout3 = nil; end;
        if self.flwMagicRecordList2 ~= nil then self.flwMagicRecordList2:destroy(); self.flwMagicRecordList2 = nil; end;
        if self.rectangle66 ~= nil then self.rectangle66:destroy(); self.rectangle66 = nil; end;
        if self.layout10 ~= nil then self.layout10:destroy(); self.layout10 = nil; end;
        if self.label36 ~= nil then self.label36:destroy(); self.label36 = nil; end;
        if self.edit33 ~= nil then self.edit33:destroy(); self.edit33 = nil; end;
        if self.layout4 ~= nil then self.layout4:destroy(); self.layout4 = nil; end;
        if self.image9 ~= nil then self.image9:destroy(); self.image9 = nil; end;
        if self.label153 ~= nil then self.label153:destroy(); self.label153 = nil; end;
        if self.label48 ~= nil then self.label48:destroy(); self.label48 = nil; end;
        if self.label120 ~= nil then self.label120:destroy(); self.label120 = nil; end;
        if self.edit19 ~= nil then self.edit19:destroy(); self.edit19 = nil; end;
        if self.label1 ~= nil then self.label1:destroy(); self.label1 = nil; end;
        if self.button10 ~= nil then self.button10:destroy(); self.button10 = nil; end;
        if self.label88 ~= nil then self.label88:destroy(); self.label88 = nil; end;
        if self.label201 ~= nil then self.label201:destroy(); self.label201 = nil; end;
        if self.edit34 ~= nil then self.edit34:destroy(); self.edit34 = nil; end;
        if self.flwMagicRecordList8 ~= nil then self.flwMagicRecordList8:destroy(); self.flwMagicRecordList8 = nil; end;
        if self.button22 ~= nil then self.button22:destroy(); self.button22 = nil; end;
        if self.rectangle41 ~= nil then self.rectangle41:destroy(); self.rectangle41 = nil; end;
        if self.layout47 ~= nil then self.layout47:destroy(); self.layout47 = nil; end;
        if self.label125 ~= nil then self.label125:destroy(); self.label125 = nil; end;
        if self.label204 ~= nil then self.label204:destroy(); self.label204 = nil; end;
        if self.label4 ~= nil then self.label4:destroy(); self.label4 = nil; end;
        if self.button15 ~= nil then self.button15:destroy(); self.button15 = nil; end;
        if self.label83 ~= nil then self.label83:destroy(); self.label83 = nil; end;
        if self.layBottomflwMagicRecordList5 ~= nil then self.layBottomflwMagicRecordList5:destroy(); self.layBottomflwMagicRecordList5 = nil; end;
        if self.rectangle46 ~= nil then self.rectangle46:destroy(); self.rectangle46 = nil; end;
        if self.label159 ~= nil then self.label159:destroy(); self.label159 = nil; end;
        if self.label13 ~= nil then self.label13:destroy(); self.label13 = nil; end;
        if self.label23 ~= nil then self.label23:destroy(); self.label23 = nil; end;
        if self.edit13 ~= nil then self.edit13:destroy(); self.edit13 = nil; end;
        if self.edit58 ~= nil then self.edit58:destroy(); self.edit58 = nil; end;
        if self.label86 ~= nil then self.label86:destroy(); self.label86 = nil; end;
        if self.label199 ~= nil then self.label199:destroy(); self.label199 = nil; end;
        if self.label109 ~= nil then self.label109:destroy(); self.label109 = nil; end;
        if self.label228 ~= nil then self.label228:destroy(); self.label228 = nil; end;
        if self.label14 ~= nil then self.label14:destroy(); self.label14 = nil; end;
        if self.label26 ~= nil then self.label26:destroy(); self.label26 = nil; end;
        if self.textEditor1 ~= nil then self.textEditor1:destroy(); self.textEditor1 = nil; end;
        if self.label59 ~= nil then self.label59:destroy(); self.label59 = nil; end;
        if self.edit55 ~= nil then self.edit55:destroy(); self.edit55 = nil; end;
        if self.dataLink26 ~= nil then self.dataLink26:destroy(); self.dataLink26 = nil; end;
        if self.label102 ~= nil then self.label102:destroy(); self.label102 = nil; end;
        if self.label130 ~= nil then self.label130:destroy(); self.label130 = nil; end;
        if self.layout85 ~= nil then self.layout85:destroy(); self.layout85 = nil; end;
        if self.layout95 ~= nil then self.layout95:destroy(); self.layout95 = nil; end;
        if self.label52 ~= nil then self.label52:destroy(); self.label52 = nil; end;
        if self.label197 ~= nil then self.label197:destroy(); self.label197 = nil; end;
        if self.edit52 ~= nil then self.edit52:destroy(); self.edit52 = nil; end;
        if self.dataLink21 ~= nil then self.dataLink21:destroy(); self.dataLink21 = nil; end;
        if self.textEditor4 ~= nil then self.textEditor4:destroy(); self.textEditor4 = nil; end;
        if self.label223 ~= nil then self.label223:destroy(); self.label223 = nil; end;
        if self.rectangle53 ~= nil then self.rectangle53:destroy(); self.rectangle53 = nil; end;
        if self.layout21 ~= nil then self.layout21:destroy(); self.layout21 = nil; end;
        if self.label78 ~= nil then self.label78:destroy(); self.label78 = nil; end;
        if self.label107 ~= nil then self.label107:destroy(); self.label107 = nil; end;
        if self.scrollBox2 ~= nil then self.scrollBox2:destroy(); self.scrollBox2 = nil; end;
        if self.layout80 ~= nil then self.layout80:destroy(); self.layout80 = nil; end;
        if self.label137 ~= nil then self.label137:destroy(); self.label137 = nil; end;
        if self.label148 ~= nil then self.label148:destroy(); self.label148 = nil; end;
        if self.layout106 ~= nil then self.layout106:destroy(); self.layout106 = nil; end;
        if self.btnNovoflwMagicRecordList6 ~= nil then self.btnNovoflwMagicRecordList6:destroy(); self.btnNovoflwMagicRecordList6 = nil; end;
        if self.label226 ~= nil then self.label226:destroy(); self.label226 = nil; end;
        if self.rectangle29 ~= nil then self.rectangle29:destroy(); self.rectangle29 = nil; end;
        if self.rectangle15 ~= nil then self.rectangle15:destroy(); self.rectangle15 = nil; end;
        if self.label75 ~= nil then self.label75:destroy(); self.label75 = nil; end;
        if self.rectangle56 ~= nil then self.rectangle56:destroy(); self.rectangle56 = nil; end;
        if self.label145 ~= nil then self.label145:destroy(); self.label145 = nil; end;
        if self.dataLink10 ~= nil then self.dataLink10:destroy(); self.dataLink10 = nil; end;
        if self.layout103 ~= nil then self.layout103:destroy(); self.layout103 = nil; end;
        if self.btnNovoflwMagicRecordList3 ~= nil then self.btnNovoflwMagicRecordList3:destroy(); self.btnNovoflwMagicRecordList3 = nil; end;
        if self.label213 ~= nil then self.label213:destroy(); self.label213 = nil; end;
        if self.rectangle22 ~= nil then self.rectangle22:destroy(); self.rectangle22 = nil; end;
        if self.rectangle10 ~= nil then self.rectangle10:destroy(); self.rectangle10 = nil; end;
        if self.label72 ~= nil then self.label72:destroy(); self.label72 = nil; end;
        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newfrmMainDaemon()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_frmMainDaemon();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _frmMainDaemon = {
    newEditor = newfrmMainDaemon, 
    new = newfrmMainDaemon, 
    name = "frmMainDaemon", 
    dataType = "Ambesek.Daemon", 
    formType = "sheetTemplate", 
    formComponentName = "form", 
    cacheMode = "none", 
    title = "Ficha Daemon", 
    description=""};

frmMainDaemon = _frmMainDaemon;
Firecast.registrarForm(_frmMainDaemon);
Firecast.registrarDataType(_frmMainDaemon);

return _frmMainDaemon;
