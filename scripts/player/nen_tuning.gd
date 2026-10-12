class_name NenTuning
extends Resource
## Números do Nen e da vida da Vela: aura, Vitalidade, Ten, Zetsu, Ren e dano.
## Edite em resources/nen_tuning.tres pelo Inspector do Godot.
## Aura em pontos (a chama cheia = aura_max), tempos em segundos.

@export_group("Vitalidade")
## Gotas de cera (a vida).
@export var vitality_max := 5
## Invencibilidade depois de levar um golpe.
@export var invuln_time := 1.1
## Empurrão ao levar um golpe de Eco (x para longe dele, y para cima).
@export var knockback := Vector2(300.0, -330.0)
## Tempo sem controle depois do golpe.
@export var knockback_time := 0.22

@export_group("Aura")
@export var aura_max := 100.0
## Custo do Passo de Ren (dash) e do Sopro (pulo aéreo).
@export var dash_cost := 18.0
@export var air_jump_cost := 14.0
## Regeneração por segundo: parada no chão, andando no chão e no ar.
@export var regen_still := 70.0
@export var regen_moving := 34.0
@export var regen_air := 6.0
## Espera depois de gastar aura antes de voltar a regenerar.
@export var regen_delay := 0.35
## Aura absorvida ao acertar um Eco e ao quicar (pogo) em lanterna ou espinho.
@export var strike_gain := 9.0
@export var pogo_gain := 6.0
## Recuo da Vela ao acertar um Eco de lado.
@export var strike_recoil := 150.0

@export_group("Antes do Ten (aura vazando)")
## Fração da aura máxima que a Vela consegue segurar enquanto vaza.
@export var leak_cap := 0.45
## Aura que escorre por segundo.
@export var leak_rate := 9.0

@export_group("Zetsu")
@export var zetsu_regen := 45.0
## Velocidade de corrida durante o Zetsu (andar escondida).
@export var zetsu_speed_mult := 0.8

@export_group("Ren")
## Aura mínima para abrir o Ren.
@export var ren_min_aura := 10.0
## Custo da explosão ao abrir o Ren.
@export var ren_burst_cost := 12.0
## Aura gasta por segundo enquanto o Ren fica aberto.
@export var ren_drain := 18.0
@export var ren_burst_radius := 120.0
@export var ren_speed_mult := 1.12

@export_group("Eco póstumo")
## Fração da aura máxima que fica com o Eco quando a Vela apaga.
@export var shade_share := 0.34
