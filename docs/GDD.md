# VELA — Documento de Design (GDD)

> Versão 0.2 · outubro de 2026 · nome provisório
> Etapa atual: **2 — Combate e fundamentos do Nen** (ver [ROADMAP](ROADMAP.md))

---

## 1. Visão

**VELA** é um metroidvania 2D sobre uma pequena peregrina de cera — uma vela viva — que cai no Poço de **Vesperal**, um mosteiro-cidade escavado dentro de uma montanha morta. Ali, gerações de praticantes de Nen treinaram até o dia em que todas as chamas se apagaram de uma vez.

> *Movimento fluido de Constance, exploração e combate de Hollow Knight, e o sistema de Nen como coração de tudo — numa história contada só por pedras, velas e o que os mortos deixaram escrito.*

### Pilares

1. **Movimento que dá gosto.** Responsivo, com momentum e encadeamento (dash → pulo → pogo → parede) sem travas.
2. **A aura é tudo.** O Nen é vida, recurso, defesa, chave de exploração e a própria linguagem do mundo.
3. **O mundo conta a história.** Nada de diálogo: inscrições, murais, corpos, objetos e textos escritos em aura.
4. **Beleza melancólica.** Mundo apagado em azul-ardósia; a única cor viva é a aura.

---

## 2. Referências — o que pegamos de cada uma

| Referência | O que inspira | O que **não** copiamos |
|---|---|---|
| **Hollow Knight** | Golpe curto com pogo, mapa interligado, locais de descanso, lore em tabuletas, recuperar o que se perdeu ao morrer | Personagens, reino de insetos, nomes, arte |
| **Constance** | Fluidez e encadeamento de movimentos; movimento que **gasta recurso** e cobra vida quando você abusa; arte pintada e viva | Protagonista, pincel, temas |
| **Hunter x Hunter (Nen)** | Ten, Zetsu, Ren, Hatsu e técnicas avançadas; as 6 categorias e o hexágono; Adivinhação da Água; Restrições e Juramentos; Nen póstumo | Personagens, histórias e Hatsus específicos da obra |

Mundo, personagens, textos, arte e música de VELA são originais. Os nomes do sistema de Nen ficam centralizados em `locale/textos.csv`, fáceis de trocar se o projeto um dia sair do território de jogo de fã.

---

## 3. O mundo: Vesperal

Vesperal é um mosteiro vertical construído para dentro de uma montanha oca. A planta segue o **hexágono do Nen**: no centro fica a Câmara da Água; ao redor, seis alas, uma por categoria, cada uma guardada pelo Nen póstumo do seu Mestre.

```
                 Ala do Punho
               (Intensificação)
     Ala do Arco               Ala do Rio
      (Emissão)              (Transmutação)
                Câmara da Água
     Ala do                    Ala do
   Titereiro                  Artífice
 (Manipulação)              (Conjuração)
                O Sem-Nome
             (Especialização)
```

| Área | Papel | Etapa |
|---|---|---|
| **Poço do Despertar** | Tutorial de movimento e dos fundamentos do Nen; onde a Vela cai | 1–2 ✅ |
| **Claustro das Velas** | Hub; alguém ainda acende as velas aqui — ninguém sabe quem | 5 |
| **Câmara da Água** | Adivinhação da Água; revela o tipo de Nen | 4 |
| **Ala do Punho** | Forjas e pedras partidas | 4–7 |
| **Ala do Rio** | Jardins alagados; aura que vira fio e líquido | 4–7 |
| **Ala do Arco** | Torres de sino e um abismo vertical | 4–7 |
| **Ala do Artífice** | Oficinas cheias de objetos conjurados que nunca sumiram | 4–7 |
| **Ala do Titereiro** | Teatro de marionetes e mecanismos | 4–7 |
| **O Sem-Nome** | Escondida; só aparece para quem usa Gyo | 7 |
| **O Relicário** | Onde a Abadessa fez o Juramento; final | 7 |

---

## 4. A história (contada pelo cenário)

**O que aconteceu.** Os monges de Vesperal eram Velas: seres de cera cuja força vital arde como uma chama no pavio. A primeira lição do mosteiro era simples — *quem deixa a aura escorrer, derrete*.

A **Abadessa** fez um Juramento para proteger Vesperal "até a última chama": prendeu a aura de todos os praticantes num único selo, o **Selo do Hexágono**. Pela lei do Nen, quanto maior a restrição, maior o poder — e a restrição foi total. O selo segurou, mas cobrou o preço: todas as chamas pararam no mesmo instante. É o **Grande Silêncio**. Os corpos viraram cascas de cera fria; as auras, presas ao último voto de cada um, viraram **Ecos** (Nen póstumo) que repetem para sempre o que juraram em vida.

**Quem é a Vela.** Uma noviça que chega de fora pela trilha dos peregrinos e cai no Poço. A queda força a abertura dos seus nós de aura: ela acorda vazando. É a única chama acesa em Vesperal.

**O mistério.** No Claustro, velas aparecem acesas de uma visita para outra. Alguém — ou algum Eco — ainda cumpre o ritual. Nunca o vemos de perto até o fim.

**Finais (planejados).**
1. **Renovar o Juramento** — a Vela se torna o novo selo. Vesperal fica protegida e silenciosa.
2. **Velar os mortos** — a Vela quebra o selo e acende uma vela para cada Mestre, libertando os Ecos. (*Velar* = acender vela e também guardar vigília pelos mortos: o título do jogo é isso.)
3. **Secreto** — exige ter lido toda a escrita em aura do Sem-Nome.

### Como a história é contada

- **Estelas (inscrições):** frases curtas, poéticas, na voz dos monges. Aparecem quando você chega perto, sem botão.
- **Escrita em aura:** visível só com **Gyo**; conta a versão que os monges esconderam (medos, arrependimentos, a verdade sobre o Juramento).
- **Cascas:** onde e como cada monge apagou conta o que aconteceu ali (meditando, fugindo, protegendo alguém).
- **Murais no fundo (parallax):** a história do Juramento em imagens, sem texto.
- **Descrições de itens e votos:** duas ou três linhas de lore cada.
- **Memórias de Eco:** ao libertar um Eco, uma cena silenciosa de silhuetas.
- **Música:** o tema da Abadessa aparece em fragmentos pelas áreas.

Regras: nenhum diálogo, nenhuma cutscene com texto, textos de no máximo três linhas, e toda sala tem pelo menos um detalhe que conta algo.

---

## 5. A protagonista: a Vela

- **Visual:** pequena figura de cera cor de osso, capuz, rosto escuro com dois olhos de brasa, pavio no topo com uma chama de aura. A barra da batina pinga como cera derretida.
- **Arma:** cajado de anéis (*shakujō*). Os anéis tilintam a cada golpe — é o som-assinatura do jogo.
- **Chama como interface:** tamanho e brilho da chama = aura disponível; ela tremula quando a aura está baixa. A cor muda após a Adivinhação da Água.
- **Silhueta clara sobre mundo escuro:** legibilidade em qualquer sala.

---

## 6. O Nen em VELA

### 6.1 Aura e Vitalidade
- **Aura (a chama):** regenera rápido no chão e parado; dash, pulo aéreo e Hatsu gastam aura. Acertar Ecos e quicar devolvem um pouco.
- **Vitalidade (gotas de cera):** a vida, como as máscaras de Hollow Knight. Começa com 5.
- **Derreter (inspirado na tinta de Constance):** dá para continuar usando habilidades com a aura zerada, mas cada uso consome Vitalidade (nunca a última gota).
- **HUD:** a chama da Vela é o medidor; no canto, uma vela pequena repete a chama e mostra as gotas.
- Números em `resources/nen_tuning.tres` (Etapa 2: dash 18, Sopro 14, regeneração 70/34/6 por segundo).

### 6.2 Os quatro princípios
| Técnica | No jogo | Etapa |
|---|---|---|
| **Ten** (envolver) | No começo a aura **vaza** sem parar (a chama segura só 45% e os golpes ferem em dobro); aprender Ten é a primeira lição, no altar do Fundo do Poço. Depois vira o estado padrão | 2 ✅ |
| **Zetsu** (ocultar) | Segurar: a chama apaga, Ecos não te percebem e você atravessa véus de aura; a aura volta rápido; sem dash, Sopro ou Ren; recebe dano dobrado. Golpe num Eco desatento fere mais | 2 ✅ |
| **Ren** (intensificar) | Apertar: a aura explode, racha cascas de aura e afasta Ecos. Segurar: golpe em dobro, mais velocidade, gasto alto | 2 ✅ |
| **Hatsu** (liberar) | A habilidade especial da categoria escolhida (6.4) | 4 |

### 6.3 Técnicas avançadas (chaves de exploração)
| Técnica | No jogo | Etapa |
|---|---|---|
| **Gyo** | Aura nos olhos: revela escrita em aura, plataformas e armadilhas ocultas com In | 3 |
| **In** | Usada pelos Ecos para esconder armadilhas; Gyo revela | 3 |
| **En** | A aura se expande num raio e revela o mapa da sala e itens próximos | 3 |
| **Shu** | Aura no cajado: golpes quebram pedra e alcançam mais longe | 3 |
| **Ko** | Toda a aura num ponto: golpe carregado devastador, sem defesa durante | 3 |
| **Ken** | Defesa total por um instante: aparar/bloquear | 3 |
| **Ryu** | Distribuir aura entre ataque e defesa em tempo real | 6 |

### 6.4 Categorias e o hexágono
Na Câmara da Água, a Vela faz a **Adivinhação da Água** (um copo com água e uma folha). A reação da água revela o tipo, que depende de **como você jogou até ali** — que técnica mais usou, como enfrentou os Ecos. Todos os Hatsus podem ser aprendidos, com eficiência pelo hexágono: **100%** no próprio tipo, **80%** nos vizinhos, **60%** a duas casas, **40%** no oposto. Eficiência muda custo de aura e potência.

Ordem do hexágono: Intensificação → Transmutação → Conjuração → Especialização → Manipulação → Emissão → (volta).

| Categoria | Cor da aura | Hatsu (original) | Uso |
|---|---|---|---|
| Intensificação | âmbar `#FF9A3C` | **Golpe Pleno** | Quebra paredes rachadas; golpe descendente que racha o chão |
| Transmutação | violeta `#B07CFF` | **Fio Vivo** | Fio elástico de aura: gancho em âncoras, balanço, puxar objetos |
| Emissão | celeste `#5CC8FF` | **Sopro de Chama** | Disparo à distância; para baixo, dá impulso (recoil jump) |
| Conjuração | jade `#5FE3A1` | **Degrau** | Conjura uma plataforma temporária (máx. 2) |
| Manipulação | limão `#F5E65B` | **Fio de Marionete** | Controla um pequeno Eco ou objeto por alguns segundos |
| Especialização | pérola `#FFD6F0` | **Vigília** | Rebobina 3 segundos do próprio tempo |

### 6.5 Restrições e Juramentos (Votos)
O equivalente aos amuletos de Hollow Knight. **Votos** são equipados em **Pavios** (slots). Cada voto impõe uma restrição e dá um poder; quanto mais dura a restrição, maior o poder. Quebrar o voto (fazer o que ele proíbe) custa aura máxima até o próximo descanso.

Exemplos: *Voto do Silêncio* (sem Ren; Ko custa metade) · *Voto do Chão* (sem pulo aéreo; dash no chão 50% mais longo) · *Voto da Chama Curta* (−2 de Vitalidade máxima; +40% de dano).

### 6.6 Morte e Nen póstumo
Ao apagar, a Vela deixa um **Eco** de si mesma onde caiu, guardando parte da aura máxima (34%) e as **Contas** (moeda: contas de oração, Etapa 6). Ela renasce no último altar em que descansou. Derrote o próprio Eco para recuperar tudo; apagar de novo antes disso troca o Eco de lugar (a perda não acumula). Quanto mais você demora, mais forte ele fica — o rancor alimenta o Nen póstumo (Etapa 6).

---

## 7. Movimentação

| Habilidade | Origem no Nen | No jogo final | Implementada |
|---|---|---|---|
| Corrida, pulo variável, coyote time, buffer de pulo | — | início | Etapa 1 ✅ |
| Golpe do cajado (lado/cima/baixo) e **pogo** | — | início | Etapa 1 ✅ |
| **Passo de Ren** (dash) | Ren | fim do Poço | Etapa 1 ✅ |
| **Aderência** (deslizar e pular na parede) | Ten nas mãos | Claustro | Etapa 1 ✅ |
| **Sopro** (pulo aéreo) | Emissão básica | Ala do Arco | Etapa 1 ✅ |
| Golpe Pleno descendente | Intensificação | Ala do Punho | Etapa 4 |
| Fio Vivo (balanço) | Transmutação | Ala do Rio | Etapa 4 |
| Degrau conjurado | Conjuração | Ala do Artífice | Etapa 4 |

Na Etapa 1 todas as habilidades de movimento vêm liberadas para testar a sensação; a ordem de desbloqueio entra na Etapa 5.

**Sensação (valores iniciais, ajustáveis em `resources/movement_tuning.tres`):** corrida quase instantânea (acelera em ~0,07 s), pulo de ~4,5 tiles com gravidade maior na queda e "flutuação" no ápice, corte de pulo ao soltar o botão, 0,10 s de coyote time, 0,13 s de buffer, dash de ~4 tiles que conserva parte do impulso, deslize de parede com velocidade limitada e pulo de parede que empurra para longe, pogo que recarrega dash e pulo aéreo, correção de canto de 8 px na cabeça e no dash.

---

## 8. Combate (Etapa 2 em diante)
- Golpe curto com hit-stop, recuo e pogo em inimigos e espinhos. Golpe recebido: empurrão e invencibilidade curta.
- **Ecos** (inimigos) repetem o último voto que fizeram em vida: o comportamento de cada um é um pedaço da história. Enxergam a chama da Vela — no Zetsu, ela some para eles.

| Eco | Voto | Comportamento | Etapa |
|---|---|---|---|
| **Vigia** | guardar o sono dos noviços | patrulha com a lanterna, só vê para a frente, investe contra a chama | 2 ✅ |
| **Saltador** | nunca mais tocar o chão | pula sem parar e salta em cima da chama; dá para quicar nele | 2 ✅ |
| **Mariposa** | velar toda chama acesa | ronda a chama e mergulha nela | 2 ✅ |
| **Eco póstumo** | o da própria Vela | guarda a aura perdida na morte | 2 ✅ |

- **Véus de aura** (só passam no Zetsu) e **cascas de aura** (só o Ren racha) são as primeiras chaves de Nen do mapa.
- Chefes: os seis Mestres e a Abadessa.

---

## 9. Direção de arte
- **Mundo:** azul-ardósia e cinza, pretos profundos, luz fria vinda de cima, névoa.
- **Aura:** a única cor saturada da tela.
- **Profundidade:** 4 a 6 camadas de parallax, névoa animada, poeira no ar, silhuetas escuras em primeiro plano.
- **Formas recorrentes:** arcos pesados, escadarias, sinos, velas, correntes, estandartes rasgados e o hexágono como símbolo.
- **Técnica:** arte procedural desenhada em código (vetorial), shaders e luzes 2D do Godot. Sem pixel art; resolução base 1280×720 com nitidez em qualquer tela.

---

## 10. Música e som
- **Instrumentação:** piano de feltro, cordas em pad, coro etéreo, sinos de templo, tigelas tibetanas, drones graves; ambiência por área (vento, gotas).
- **Temas:** Título, Poço do Despertar, Limiar; um por ala; o tema da Abadessa como leitmotiv.
- **Música como código:** composta e sintetizada em Python (`tools/audio`) e renderizada em OGG. Reprodutível, versionada e editável.
- **Som-assinatura:** os anéis do cajado.
- **Trilha reativa (Etapa 8):** camadas que entram e saem conforme a tensão.

---

## 11. Tecnologia
- **Godot 4.7, GDScript**, renderer Compatibility (PC e navegador).
- **Física de plataforma própria** (grade de tiles + AABB por eixo): determinística, sem tremidas de borda de tile e testável sem abrir o jogo.
- **Salas em JSON com mapa ASCII** (`levels/`), legíveis e editáveis em qualquer editor.
- **Testes headless** (`tests/`) e **CI** no GitHub Actions com build web no GitHub Pages.
- Teclado e controle.
