# Devlog — Etapa 1: Movimentação

> 11/10/2026 · Godot 4.7.2 · 27 testes passando

## O que entrou

**Física própria em grade.** A Vela não usa `CharacterBody2D`: a colisão é feita contra a grade de tiles da sala (`LevelGrid`), um eixo por vez, varrendo todas as células do caminho. Motivos:
- nada de "engasgar" em emenda de tile, que é comum com corpos físicos em tilemaps;
- controle total sobre plataformas de mão única, espinhos, portas e correção de quina;
- determinismo — a mesma entrada dá o mesmo resultado, o que deixa a física testável sem abrir o jogo.

**Controle da Vela** (`scripts/player/player.gd`) — uma máquina de estados (`NORMAL`, `DASH`, `HURT`, `RESPAWN`, `INTRO_FALL`, `WAKE`, `ENTER`, `REST`) com:

| Mecânica | Como ficou |
|---|---|
| Corrida | 290 px/s, acelera em ~0,07 s, inverte a direção em ~0,04 s |
| Pulo | ~4,5 tiles segurando; soltar corta a subida (×0,4); gravidade ×0,55 perto do ápice e ×1,55 na queda |
| Coyote time / buffer | 0,10 s / 0,13 s |
| Passo de Ren (dash) | 820 px/s por 0,16 s (~4 tiles); 1 no ar; pulo no meio do dash conserva 72% da velocidade |
| Aderência | deslize limitado a 140 px/s; pulo de parede empurra 340 px/s para longe com 0,13 s de controle reduzido — dá para escalar uma parede só |
| Sopro (pulo aéreo) | 1 por voo; recarrega no chão, na parede e no pogo |
| Golpe e pogo | golpe para baixo no ar quica 650 px/s em espinhos e lanternas e recarrega dash e Sopro |
| Assistências | correção de quina de 8 px na cabeça e no dash |
| Perigo | espinho → empurrão, fade, volta ao último chão seguro |

Todos esses números estão em `resources/movement_tuning.tres`.

**O Poço do Despertar** — 4 salas: o *Fundo do Poço* (queda da intro, primeira estela, fosso), a *Galeria dos Noviços* (vãos que pedem pulo + dash e um poço de escalada com espinhos nas paredes), a *Câmara das Lanternas* (chão de espinhos, sete lanternas para quicar, a ilha do monge que acendia as lanternas) e o *Altar do Limiar* (descanso e fim da etapa).

**Arte, luz e som** — tudo gerado em código: a Vela é desenhada com polígonos e animada por molas; o terreno usa um shader que escurece a pedra pela distância da borda e deixa a rocha profunda translúcida para o mosteiro aparecer atrás; o fundo tem colossos encapuzados, arcos, pilares, névoa e feixes de luz. A trilha (título, Poço, Limiar) e a ambiência foram compostas e sintetizadas em Python.

## Decisões

- **Todas as habilidades de movimento vêm liberadas** nesta etapa para testar a sensação. A ordem de desbloqueio (Passo de Ren no fim do Poço, Aderência no Claustro, Sopro na Ala do Arco) entra na Etapa 5.
- **Salas em JSON + ASCII** em vez de TileMap: dá para desenhar e revisar sala em qualquer editor e os testes validam tudo. Se um editor visual fizer falta, dá para criar um plugin que desenha a sala no editor do Godot.
- **Renderer Compatibility**, para o mesmo build rodar no PC e no navegador (GitHub Pages).

## Bugs que os testes e as capturas pegaram

- As molas da animação explodiam com passo de tempo grande (0,1 s), e a Vela sumia. Agora integram em subpassos de 8 ms.
- Polígonos de estandarte com pontos repetidos falhavam na triangulação.
- O fundo de alvenaria cobria tudo e escondia a profundidade; virou painéis com vãos.

## Próximo: Etapa 2

Combate e os fundamentos do Nen: Vitalidade e Aura na chama, a aura que **vaza** até a Vela aprender **Ten**, **Zetsu** e **Ren**, custo de aura no dash e no Sopro, os primeiros Ecos (inimigos) e a morte com Eco póstumo.
