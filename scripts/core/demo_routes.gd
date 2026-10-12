class_name DemoRoutes
extends RefCounted
## Rotas roteirizadas para a demo gravada (GIF do README) e para testes visuais.
## Cada segmento segura uma ação entre dois instantes (segundos).

const ROUTES := {
	# Galeria dos Noviços: corrida, pulo no vão, pulo + Passo de Ren no vão
	# grande, estela na base do poço e pulo duplo.
	"galeria": [
		{"from": 0.0, "to": 3.78, "action": "move_right"},
		{"from": 0.72, "to": 0.95, "action": "jump"},
		{"from": 1.70, "to": 1.95, "action": "jump"},
		{"from": 1.92, "to": 1.96, "action": "dash"},
		{"from": 5.30, "to": 5.62, "action": "jump"},
		{"from": 5.78, "to": 6.05, "action": "jump"},
		{"from": 6.38, "to": 6.50, "action": "move_up"},
		{"from": 6.40, "to": 6.44, "action": "attack"},
	],
	# Altar do Limiar: chega, descansa e mostra o fim da etapa.
	"limiar": [
		{"from": 0.0, "to": 0.55, "action": "move_right"},
		{"from": 1.2, "to": 1.3, "action": "move_up"},
	],
}


static func get_route(route_name: String) -> Array:
	return ROUTES.get(route_name, [])


## Entrada da demo: rota roteirizada; nas lanternas, o piloto que quica; em
## "combate", o piloto que enfrenta os Ecos da sala.
static func make_input(route_name: String, player: Player, room: Room) -> PlayerInput:
	if route_name == "lanternas":
		var pilot := DemoPilot.new()
		pilot.player = player
		pilot.lanterns = room.strikeables
		return pilot
	if route_name == "combate":
		var fighter := CombatPilot.new()
		fighter.player = player
		fighter.ecos = room.ecos
		return fighter
	var si := ScriptedInput.new()
	si.timeline = get_route(route_name)
	return si
