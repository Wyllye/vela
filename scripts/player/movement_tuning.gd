class_name MovementTuning
extends Resource
## Números que definem a sensação da movimentação.
## Edite em resources/movement_tuning.tres pelo Inspector do Godot.
## Unidades: pixels e segundos (1 tile = 32 px).

@export_group("Corrida")
## Velocidade máxima correndo.
@export var run_speed := 290.0
@export var ground_accel := 4200.0
@export var ground_decel := 5600.0
## Aceleração ao inverter a direção no chão (virada rápida).
@export var turn_accel := 7600.0
@export var air_accel := 3300.0
@export var air_decel := 1900.0
## Desaceleração acima da velocidade máxima (conserva o impulso do dash).
@export var overspeed_decel := 700.0

@export_group("Pulo")
@export var gravity := 2100.0
## Gravidade extra na queda (pulo mais "pesado" na descida).
@export var fall_gravity_mult := 1.55
## Gravidade reduzida perto do ápice enquanto o botão está segurado.
@export var apex_gravity_mult := 0.55
@export var apex_threshold := 90.0
@export var max_fall := 820.0
## Queda máxima segurando para baixo.
@export var fast_fall := 1050.0
@export var jump_velocity := 760.0
## Fração da velocidade que sobra ao soltar o botão subindo.
@export var jump_cut_mult := 0.4
@export var coyote_time := 0.10
@export var jump_buffer := 0.13

@export_group("Sopro (pulo aéreo)")
@export var air_jump_velocity := 690.0
@export var air_jumps := 1

@export_group("Passo de Ren (dash)")
@export var dash_speed := 820.0
@export var dash_time := 0.16
@export var dash_cooldown := 0.30
## Fração da velocidade do dash que sobra quando ele termina.
@export var dash_end_mult := 0.5
## Fração da velocidade do dash mantida ao cancelar com pulo.
@export var dash_jump_keep := 0.72

@export_group("Aderência (parede)")
@export var wall_slide_max := 140.0
@export var wall_jump_vx := 340.0
@export var wall_jump_vy := 720.0
## Tempo em que o controle no ar fica reduzido depois do pulo de parede.
@export var wall_jump_lock := 0.13
@export var wall_coyote := 0.09

@export_group("Golpe e pogo")
@export var pogo_velocity := 650.0
@export var attack_time := 0.22
## Janela em que o golpe acerta.
@export var attack_active := 0.09
@export var attack_cooldown := 0.27
@export var wall_hit_recoil := 140.0

@export_group("Assistências")
## Quantos px a cabeça desliza para contornar uma quina ao pular.
@export var corner_correction := 8.0
## Quantos px o dash sobe para não travar numa quina.
@export var ledge_assist := 8.0
