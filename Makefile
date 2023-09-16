create-traefik-network-once:
	docker network create --attachable  traefik-public
up:
	docker-compose up -d
down:
	docker-compose down


swarm-create-traefik-network-once:
	docker network create --driver=overlay --attachable  traefik-public

swarm-up:
	docker stack deploy --compose-file=docker-compose.yml traefik
swarm-down:
	docker stack rm traefik
