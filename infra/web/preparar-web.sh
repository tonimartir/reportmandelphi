#!/usr/bin/env bash
# =============================================================================
# PREPARAR LA VM PARA SERVIR reportman.es. Una vez, y SIN ROOT.
# =============================================================================
# NI UNA ORDEN CON sudo, y eso es una decision, no una casualidad: servir ficheros estaticos no
# necesita ningun privilegio. Lo que lo pedia era la FORMA de servirlos --un nginx de paquete
# obliga a `apt-get install`, a escribir en /etc/nginx y a una carpeta en /opt--, asi que la forma
# es la que cambia: nginx en un contenedor, como reportman-web en el :8080. El sitio vive en
# ~/webs/reportman-es, que es del usuario.
#
# Uso:  infra/web/preparar-web.sh
#
# Es idempotente: se puede volver a correr para recrear el contenedor tras editar el vhost.
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RAIZ="${WEB_RAIZ:-$HOME/webs/reportman-es}"
URL="${RMW_URL:-http://192.168.100.2:5083/}"
export WEB_RAIZ="$RAIZ"          # lo lee docker-compose.yml para el montaje

command -v docker >/dev/null || { echo "Falta docker." >&2; exit 1; }
# `docker ps` y no `id -nG`: lo que importa no es figurar en el grupo, es que el socket conteste
# --en una sesion abierta antes de entrar en el grupo, el grupo esta y el permiso no--.
docker ps >/dev/null 2>&1 || { echo "Docker no contesta sin sudo. Si acabas de entrar en el grupo docker, vuelve a entrar en la sesion." >&2; exit 1; }

echo "==> $RAIZ"
mkdir -p "$RAIZ/releases"
chmod 755 "$RAIZ" "$RAIZ/releases"   # el nginx del contenedor no corre como tu: tiene que poder leer

# UN RELEASE VACIO PARA QUE EL SITIO EXISTA DESDE YA: sin `actual`, nginx arranca igual pero cada
# peticion da un 500 --el root no existe-- y eso se confunde con una configuracion mala.
if [ ! -e "$RAIZ/actual" ]; then
  mkdir -p "$RAIZ/releases/00000000T000000Z-vacio"
  printf 'Sin desplegar todavia.\n' > "$RAIZ/releases/00000000T000000Z-vacio/index.html"
  # RELATIVO: dentro del contenedor el sitio se monta en /srv/sitio, asi que un enlace a
  # /home/toni/... no se resolveria. `ln -s releases/x actual` vale en los dos lados.
  ( cd "$RAIZ" && ln -s "releases/00000000T000000Z-vacio" actual )
fi

echo "==> El contenedor"
docker compose -f "$AQUI/docker-compose.yml" up -d
# `nginx -t` DESPUES de levantarlo y con el mismo fichero montado: si el vhost esta mal, el
# contenedor se reinicia en bucle y sin esto lo unico que se ve es un 'restarting'.
docker exec web-reportman-es nginx -t

echo "==> Comprobando $URL"
for _ in $(seq 20); do
  codigo="$(curl -s -o /dev/null -m 5 -w '%{http_code}' "$URL" || true)"
  [ "$codigo" = 200 ] && break
  sleep 1
done
[ "${codigo:-}" = 200 ] || { echo "    contesta ${codigo:-nada}. Mira: docker logs web-reportman-es" >&2; exit 1; }
echo "    responde 200"

echo "==> Listo. Ahora:  $AQUI/desplegar-web.sh"
