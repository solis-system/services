
# Getion Serveur Solis


## Submodules
```bash
# Mettre a jours les submodules
make init_submodule
```

## Container
```bash
# Demarrer tous les containers
make up

# Eteindre tous les container
make down
```
## labels
```yml
labels:
  base:
    container_name: base
    image: ""
    labels:
      caddy: "${DOMAIN}"
      caddy.reverse_proxy: "{{upstreams 80}}"
    volumes:
      -
    environment:
      -
    ports:
      - ""
    restart: always
    networks:
      - proxy-network
```
