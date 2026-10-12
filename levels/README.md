# Salas

Cada sala é um JSON com metadados e um mapa ASCII (1 caractere = 1 tile de 32 px).
Edite em qualquer editor de texto; todas as linhas precisam ter o mesmo tamanho
(os testes conferem isso).

## Legenda do mapa

| Caractere | O que é |
|---|---|
| `#` | Rocha sólida |
| `.` | Vazio |
| `=` | Plataforma de mão única (sobe por baixo; ↓ + pulo desce) |
| `^` `v` `<` `>` | Espinhos — a ponta aponta para essa direção |
| `~` | Véu de aura — parede, menos para a Vela no Zetsu |
| `*` | Casca de aura — parede que a explosão do Ren racha (a casca inteira de uma vez) |
| `0`–`9` | Porta (célula vazia na borda da sala, liga com outra sala) |
| `P` | Onde a Vela cai no começo do jogo |
| `T` | Estela com inscrição (textos em `texts`, na ordem de leitura) |
| `A` | Altar de descanso (e de lição, ver `altar_lesson`) |
| `o` | Lanterna de aura (pendura no teto acima; aceita pogo) |
| `c` / `C` | Vela acesa / grupo de três velas |
| `m` / `x` | Casca de monge meditando / caída |
| `b` / `h` | Estandarte / corrente pendurados no teto acima |
| `g` | Escrita em aura (aparece com Gyo, na Etapa 3) |
| `r` | Pedras soltas |
| `V` | Eco Vigia (patrulha o chão perto de onde está) |
| `S` | Eco Saltador |
| `M` | Eco Mariposa (voadora; paira no meio da célula) |

## Campos do JSON

| Campo | Para quê |
|---|---|
| `id` | Nome do arquivo, usado nas portas |
| `area_title` | Chave do título mostrado ao acordar (só na primeira sala da área) |
| `music` / `ambience` | Faixas em `assets/audio/music/` |
| `palette` | Paleta de cores (`scripts/world/palettes.gd`) |
| `seed` | Semente dos detalhes procedurais (pedrinhas, fundo, velas) |
| `altar_lesson` | O que o altar da sala ensina ao meditar: `ten`, `zetsu`, `ren` ou `end` (fim da etapa); ensina também as lições anteriores que faltarem |
| `doors` | `"1": {"to": "galeria", "door": "1"}` — a porta 1 leva à porta 1 da galeria |
| `texts` | Chaves de `locale/textos.csv` para as estelas `T` |
| `light_shafts` | Feixes de luz: `x`, `y` em tiles, largura `w`, comprimento `len`, `angle` em graus |
