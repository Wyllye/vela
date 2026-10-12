<div align="center">

# VELA

**Um metroidvania sobre aura, votos e velas apagadas.**

Você é uma peregrina de cera — uma vela viva, com uma chama de aura no pavio e um cajado de anéis —
que cai em **Vesperal**, o mosteiro-cidade onde todos os praticantes de Nen se apagaram de uma vez.

![Câmara dos Votos: Ren, golpes e pogo contra Saltadores e Mariposas](docs/img/combate.gif)

*Etapa 2 · Combate e fundamentos do Nen* — [Roadmap](docs/ROADMAP.md) · [Documento de design](docs/GDD.md) · Devlogs: [Etapa 1](docs/devlog/etapa-01.md) · [Etapa 2](docs/devlog/etapa-02.md)

</div>

---

## Jogar

**No navegador:** <https://wyllye.github.io/vela/> (publicado pelo GitHub Actions a cada push na `main`).

**No Godot:**
1. Instale o [Godot 4.7](https://godotengine.org/download) (versão padrão, sem .NET).
2. Abra o Godot → **Importar** → escolha o `project.godot` desta pasta.
3. Aperte **F5**.

## Controles

| Ação | Teclado | Controle |
|---|---|---|
| Mover / mirar | ← → ↑ ↓ ou WASD | Analógico / direcional |
| Pular (segure para ir mais alto) | Z ou Espaço | A |
| Golpe do cajado (↓ no ar = pogo) | X ou J | X |
| Passo de Ren (dash) | C ou K | RB / RT |
| **Zetsu** (segurar): apaga a chama | Shift | LB / LT |
| **Ren** (segurar): explode a aura | V ou L | Y |
| Descansar / meditar no altar | ↑ | ↑ |
| Pausa | Esc ou P | Start |
| Música liga/desliga | M | — |
| Depuração (hitbox, números) | F3 | — |

## O que já existe

**Etapa 2 — combate e fundamentos do Nen**
- **Vitalidade e Aura:** 5 gotas de cera e a chama da Vela, que é o medidor da aura. Dash e Sopro gastam aura; com a chama zerada, eles derretem uma gota.
- **Ten, Zetsu e Ren:** a Vela acorda com a aura vazando e aprende o **Ten** no primeiro altar. **Zetsu** apaga a chama: os Ecos não a veem e véus de aura deixam passar, mas os golpes ferem em dobro. **Ren** explode a aura: racha cascas de aura, afasta os Ecos e dobra o golpe do cajado.
- **Os Ecos**, presos ao último voto: o **Vigia** que patrulha com a lanterna e investe, o **Saltador** que nunca toca o chão, a **Mariposa** que mergulha na chama — e o **Eco póstumo** da própria Vela, que guarda a aura dela quando ela apaga.
- **Combate** com hit-stop, recuo, empurrão e invencibilidade curta; golpe pelas costas fere mais.
- **Morte e renascimento:** a Vela renasce no último altar e precisa vencer o próprio Eco para recuperar a aura.
- **Duas salas novas:** o Dormitório dos Noviços (Zetsu) e a Câmara dos Votos (Ren). Agora são 6 salas, com 3 altares de lição.
- **50 testes automáticos** de física, Nen, combate e salas, rodando no CI.

**Etapa 1 — movimentação**
- Corrida que chega à velocidade máxima em ~0,07 s, pulo variável, *coyote time*, *buffer* de pulo, **Passo de Ren** (dash), **Aderência** (parede), **Sopro** (pulo aéreo), golpe em 3 direções, **pogo** e correção de quina.
- **Arte procedural:** a Vela, o terreno, os Ecos, os fundos, a luz e as partículas são desenhados em código — sem nenhuma imagem pronta.
- **Música e som compostos em código:** piano de feltro, cordas, coro, sinos e tigelas tibetanas sintetizados em Python (`tools/audio`), mais 41 efeitos. O som do jogo é o tilintar dos anéis do cajado.

![Dormitório dos Noviços: no Zetsu, por trás do Vigia e através do véu](docs/img/zetsu.gif)

![Câmara das Lanternas: pogo de lanterna em lanterna](docs/img/lanternas.gif)

## Como o projeto está organizado

```
levels/            salas em JSON com mapa ASCII (legenda em levels/README.md)
locale/textos.csv  todos os textos do jogo, inclusive os nomes do sistema de Nen
resources/         movement_tuning.tres e nen_tuning.tres — os números do movimento, do Nen e do dano
scenes/            main.tscn (jogo) e player.tscn (a Vela)
scripts/
  core/            física em grade (LevelGrid), controles, dados das salas, pilotos das demos
  player/          controle da Vela (movimento, Nen, dano), desenho procedural, rastro do dash
  ecos/            os Ecos: Vigia, Saltador, Mariposa e o Eco póstumo
  world/           montagem das salas, terreno, véus e cascas de aura, fundos, névoa, luz, props
  camera/  ui/  fx/  autoload/
shaders/           pedra, névoa, feixes de luz, vinheta
tests/             testes headless (godot --headless -s res://tests/run_tests.gd)
tools/             gerador do Input Map e a síntese da trilha (tools/audio)
docs/              GDD, roadmap e devlog de cada etapa
```

## Mexendo no jogo

- **Sensação do movimento:** abra `resources/movement_tuning.tres` no Inspector do Godot. Cada número tem descrição (velocidade, gravidade, coyote time, dash...).
- **Nen e dano:** `resources/nen_tuning.tres` (custos de aura, regeneração, Zetsu, Ren, invencibilidade, Eco póstumo).
- **Salas:** edite os mapas em `levels/*.json` — `#` é rocha, `=` plataforma, `^` espinho, `~` véu, `*` casca, `V` `S` `M` são Ecos, outras letras são objetos. A legenda completa está em [`levels/README.md`](levels/README.md).
- **Textos:** `locale/textos.csv`.
- **Música e efeitos:** `python3 tools/audio/build_audio.py` regenera tudo (precisa de numpy, scipy e ffmpeg).
- **Testes:** `godot --headless --path . --import` e depois `godot --headless --path . -s res://tests/run_tests.gd`.
- **Ver uma sala direto:** `godot --path . -- --room=lanternas --at=6,6` (pula título e intro). Opções: `--nen=none|ten|zetsu|all` (técnicas aprendidas), `--vit=1` (gotas), `--demo=combate` (a Vela luta sozinha).

## Créditos

- Jogo de fã, sem fins comerciais. O sistema de habilidades é inspirado no **Nen** de *Hunter x Hunter*, de Yoshihiro Togashi. Mundo, personagens, textos, arte e música de VELA são originais.
- Referências de jogo: *Hollow Knight* (Team Cherry) e *Constance* (btf).
- Fontes: [Cinzel](https://github.com/NDISCOVER/Cinzel) e [Cormorant Garamond](https://github.com/CatharsisFonts/Cormorant), sob a SIL Open Font License (`assets/fonts/`).
- Feito em [Godot Engine](https://godotengine.org).
