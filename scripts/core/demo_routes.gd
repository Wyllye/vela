class_name DemoRoutes
extends RefCounted
## Rotas roteirizadas para a demo gravada (GIF do README) e para testes visuais.
## Cada segmento segura uma ação entre dois instantes (segundos).

const ROUTES := {}


static func get_route(route_name: String) -> Array:
	return ROUTES.get(route_name, [])
