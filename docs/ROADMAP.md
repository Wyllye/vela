# Roadmap — VELA

Cada etapa só termina quando: o jogo roda do zero num clone limpo, os testes passam no CI, existe um devlog em `docs/devlog/` e tudo está no GitHub.

| Etapa | Foco | Status |
|---|---|---|
| 0 | Fundação: projeto Godot, GDD, roadmap, CI | ✅ concluída |
| 1 | Movimentação + primeira área (Poço do Despertar) | ✅ concluída |
| 2 | Combate e fundamentos do Nen (Ten, Zetsu, Ren) | ⏭️ próxima |
| 3 | Técnicas avançadas (Gyo, En, Shu, Ko, Ken) e a narrativa oculta | ⬜ |
| 4 | Câmara da Água, hexágono e os seis Hatsus | ⬜ |
| 5 | Mundo interligado: Claustro das Velas, mapa, altares e save | ⬜ |
| 6 | Restrições e Juramentos, Contas e Nen póstumo | ⬜ |
| 7 | Chefes: os Mestres e a Abadessa; finais | ⬜ |
| 8 | Passe de arte e áudio por área; trilha reativa | ⬜ |
| 9 | Polimento, menus, acessibilidade e build final | ⬜ |

---

## Etapa 0 — Fundação ✅
- [x] Projeto Godot 4.7 (Compatibility, 1280×720, interpolação de física)
- [x] Input Map (teclado + controle)
- [x] GDD e roadmap
- [x] Testes headless e GitHub Actions (testes + build web para o Pages)

## Etapa 1 — Movimentação ✅
- [x] Física própria em grade (colisão por eixo, plataformas de mão única, espinhos)
- [x] Corrida com aceleração/desaceleração, pulo variável, ápice suave, queda mais pesada
- [x] Coyote time e buffer de pulo
- [x] Passo de Ren (dash) com pulo-cancelado que conserva impulso
- [x] Aderência: deslize e pulo de parede
- [x] Sopro: pulo aéreo
- [x] Golpe do cajado em 3 direções e pogo em espinhos e lanternas
- [x] Correção de canto (cabeça e dash)
- [x] Respawn de perigo no último chão seguro
- [x] Câmera com antecipação, olhar para cima/baixo e tremor
- [x] 4 salas do Poço do Despertar, transições, intro (queda e despertar) e altar final
- [x] Arte procedural da Vela, terreno, parallax, luzes, partículas
- [x] Trilha (título, Poço, Limiar), ambiência e efeitos sonoros
- [x] Inscrições, título de área, pausa com controles, debug (F3)

**Pronto quando:** dá para atravessar as 4 salas só com movimento, sem travar em quina, e a sensação aguenta comparação lado a lado com as referências.

## Etapa 2 — Combate e fundamentos do Nen
- [ ] Vitalidade (gotas de cera) e Aura (chama) no HUD diegético
- [ ] Aura que **vaza** no início; aprender **Ten** num altar do Poço
- [ ] **Zetsu** (furtividade, dano dobrado) e **Ren** (explosão de aura)
- [ ] Custo de aura no dash e no pulo aéreo; "derreter" quando zera
- [ ] Hit-stop, recuo, invencibilidade curta, knockback
- [ ] 3 Ecos básicos (patrulheiro, saltador, voador) com comportamentos ligados a votos
- [ ] Morte, Eco póstumo e recuperação
- [ ] 2 salas novas de combate no Poço

**Pronto quando:** dá para morrer, recuperar o Eco e vencer as salas usando Ten/Zetsu/Ren de forma diferente.

## Etapa 3 — Técnicas avançadas e narrativa oculta
- [ ] **Gyo**: camada de escrita em aura (inclui o glifo já plantado no Poço)
- [ ] **En**: revelar mapa da sala
- [ ] **Shu**, **Ko**, **Ken** no combate
- [ ] Sistema de inscrições e escrita em aura dirigido por dados
- [ ] Primeiro mural de parallax contando o Juramento

## Etapa 4 — A Câmara da Água e os Hatsus
- [ ] Adivinhação da Água (tipo definido pelo estilo de jogo)
- [ ] Hexágono de afinidade e eficiência por categoria
- [ ] Os seis Hatsus como ferramentas de movimento e combate
- [ ] Cor da aura por categoria em toda a arte (chama, rastros, luzes)

## Etapa 5 — Mundo interligado
- [ ] Claustro das Velas (hub) e conexões com as alas
- [ ] Mapa (preenchido por En e por exploração)
- [ ] Altares: descanso, save, respawn
- [ ] Ordem de desbloqueio das habilidades de movimento

## Etapa 6 — Votos, Contas e Nen póstumo completo
- [ ] Votos equipáveis em Pavios, com quebra de voto
- [ ] Contas (moeda) e oferendas em altares
- [ ] Eco póstumo que fica mais forte com o tempo

## Etapa 7 — Chefes e finais
- [ ] Os seis Mestres (um por ala) e a Abadessa
- [ ] Os três finais

## Etapa 8 — Arte e áudio
- [ ] Paleta, props e murais por ala
- [ ] Temas por ala e trilha reativa em camadas
- [ ] Sons dos Ecos e dos chefes

## Etapa 9 — Polimento
- [ ] Menus, opções (volume, remapeamento de teclas, idioma)
- [ ] Acessibilidade (assistência de jogo, contraste, tremor de tela opcional)
- [ ] Builds de desktop e web, performance
