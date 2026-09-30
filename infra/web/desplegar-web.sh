#!/usr/bin/env bash
# =============================================================================
# DESPLEGAR reportman.es: copiar la web del repositorio y repuntar el enlace.
# =============================================================================
# SIN ROOT Y SIN CONSTRUIR NADA, y las dos cosas son deliberadas:
#
#   NO PIDE ROOT porque no hay servicio que parar --nginx solo lee ficheros--, el sitio vive en
#   ~/webs/reportman-es, que es del usuario, y el nginx que lo sirve es un contenedor que lo monta
#   de solo lectura. Publicar es repuntar un enlace; no hay ni recarga.
#
#   NO CONSTRUYE porque el HTML del repositorio ES el artefacto: esta web no se genera. Existe
#   `doc/_build/build-docs.mjs`, pero es una herramienta de AUTORIA que reescribe las paginas EN
#   SITIO --dentro del repositorio-- cuando se cambia la navegacion, y se lanza a mano. Correrla
#   desde el despliegue modificaria el arbol de trabajo a espaldas de quien despliega.
#
# Uso:  infra/web/desplegar-web.sh [--sin-pull] [--seco]
#
#   --sin-pull  no toca git: publica lo que ya hay en el arbol
#   --seco      dice QUE publicaria y para. No toca el enlace.
#
# VOLVER ATRAS:  ls -1t ~/webs/reportman-es/releases   y luego, desde ~/webs/reportman-es:
#                ln -s releases/<el bueno> .a && mv -T .a actual
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$AQUI/../.." && pwd)"                 # reportmandelphi
# LA RAIZ DE LA WEB ES doc/, y no es una carpeta de documentacion mal puesta: ahi viven index.html,
# company.html, download.html, sus gemelas en castellano (indexes.html, companyes.html…) y las
# carpetas doc/, docnet/, tutorial/ y training/. Asi se sirve hoy en el host viejo.
WEB="$REPO/doc"
RAIZ="${WEB_RAIZ:-$HOME/webs/reportman-es}"
URL="${RMW_URL:-http://192.168.100.2:5083/}"
CONSERVAR="${RMW_CONSERVAR:-5}"

pull=1; seco=0
while [ $# -gt 0 ]; do
  case "$1" in
    --sin-pull) pull=0; shift ;;
    --seco) seco=1; shift ;;
    *) echo "Argumento desconocido: $1" >&2; exit 2 ;;
  esac
done

[ -d "$RAIZ/releases" ] || { echo "Falta $RAIZ. Corre una vez:  $AQUI/preparar-web.sh" >&2; exit 1; }
[ -s "$WEB/index.html" ] || { echo "No encuentro $WEB/index.html." >&2; exit 1; }

if [ "$pull" = 1 ]; then
  echo "==> Trayendo el codigo"
  git -C "$REPO" pull --ff-only --quiet
fi
echo "    $(git -C "$REPO" rev-parse --short HEAD)  $(git -C "$REPO" log -1 --format=%s | cut -c1-60)"

sello="$(date -u +%Y%m%dT%H%M%SZ)-$(git -C "$REPO" rev-parse --short HEAD)"
release="$RAIZ/releases/$sello"
ficheros="$(find "$WEB" -type f -not -path "$WEB/_build/*" | wc -l)"

if [ "$seco" = 1 ]; then
  echo "==> Seco: aqui pararia."
  echo "    publicaria  $sello  ($ficheros ficheros, $(du -sh --exclude=_build "$WEB" | cut -f1))"
  echo "    sirviendo   $(readlink "$RAIZ/actual" 2>/dev/null || echo nada)"
  exit 0
fi

echo "==> Publicando $sello  ($ficheros ficheros)"
mkdir -p "$release"
# _build FUERA, y lo dice el propio sitio: doc/robots.txt lleva «Disallow: /_build/  # Build tooling
# (not part of the published site)». Si no es parte del sitio publicado, no se publica --hoy en el
# host viejo si esta, porque se sube un zip de la carpeta entera--.
rsync -a --exclude='_build/' "$WEB/" "$release/"
chmod -R a+rX "$release"

# ENLACE RELATIVO (se resuelve tambien dentro del contenedor) y ATOMICO: `mv -T` es un rename, asi
# que no hay un instante sin `actual` --justo cuando nginx puede estar resolviendolo--.
( cd "$RAIZ" && ln -s "releases/$sello" .actual.nuevo && mv -T .actual.nuevo actual )

echo "==> Comprobando"
fallos=0
for ruta in / /indexes.html /company.html /download.html /doc/ /docnet/ /robots.txt /sitemap.xml; do
  codigo="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "${URL%/}$ruta" || true)"
  printf '    %-16s %s\n' "$ruta" "$codigo"
  [ "$codigo" = 200 ] || fallos=$((fallos + 1))
done
# Y que _build NO se sirva, que es lo que se acaba de excluir.
codigo="$(curl -s -o /dev/null -m 10 -w '%{http_code}' "${URL%/}/_build/build-docs.mjs" || true)"
printf '    %-16s %s (tiene que ser 404)\n' "/_build/" "$codigo"
[ "$codigo" = 404 ] || fallos=$((fallos + 1))
if [ "$fallos" != 0 ]; then
  echo "    $fallos comprobacion(es) mal. El enlace YA apunta al release nuevo; la receta para volver esta en la cabecera." >&2
  exit 1
fi

while IFS= read -r v; do
  [ -n "$v" ] || continue
  [ "$(readlink -f "$v")" = "$(readlink -f "$RAIZ/actual")" ] && continue
  rm -rf "$v"
done < <(ls -1dt "$RAIZ"/releases/*/ 2>/dev/null | tail -n +$((CONSERVAR + 1)))

echo "==> $sello desplegado. Quedan $(ls -1d "$RAIZ"/releases/*/ 2>/dev/null | wc -l) release(s)."
