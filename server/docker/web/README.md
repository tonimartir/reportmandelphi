# Reportman Web Server — Docker Build & Publish Guide

Instrucciones para construir y publicar la imagen Docker de `repwebexe`
en Docker Hub, siguiendo el mismo flujo base usado en `ReportmanAI/Installer/DOCKER.md`.

## Registro previsto

| Registro | URL imagen |
|---|---|
| Docker Hub | `tonimartir/reportman-web` |

Si finalmente quieres otro nombre de repositorio en Docker Hub, solo cambia la parte de `docker tag` y `docker push`.

---

## Arquitectura de la imagen

- El proceso principal del contenedor es `repwebexe -selfhosted`.
- El puerto HTTP lo controla `REPORTMAN_HTTP_PORT` y por defecto es `8080`.
- `dbxdrivers.conf` y `dbxconnections.conf` viven en `/usr/local/etc`.
- `reportmanserver` en Linux termina resolviendose en `${HOME}/.etc.reportmanserver`.
- En esta imagen `HOME=/var/lib/reportman`, asi que el fichero de servidor queda en `/var/lib/reportman/.etc.reportmanserver`.

---

## Requisitos previos

### 1. Docker en WSL2

```bash
docker --version
```

### 2. Login en Docker Hub

```bash
docker login
# Introducir usuario: tonimartir
# Introducir contraseña o Access Token de https://hub.docker.com/settings/security
```

> El login queda guardado en `~/.docker/config.json` dentro de WSL.

---

## Archivos esperados antes del build

El `Dockerfile` no compila Delphi. Empaqueta un binario Linux ya generado.

Antes de construir la imagen, deja el ejecutable Linux aqui:

- `server/docker/web/artifacts/linux64/repwebexe`

Y usa como `dbxdrivers` base el fichero del repo:

- `repman/dbxdrivers.ini`

Preparacion minima:

```bash
cd /mnt/c/desarrollo/prog/toni/reportman
mkdir -p server/docker/web/artifacts/linux64
ls -l server/docker/web/artifacts/linux64/repwebexe
```

---

## Flujo completo: nueva version

### Paso 1 — Definir la version

```bash
VERSION="1.0.0"
```

### Paso 2 — Construir la imagen desde WSL

```bash
cd /mnt/c/desarrollo/prog/toni/reportman

docker build \
  -f server/docker/web/Dockerfile \
  -t reportman-web:${VERSION} \
  -t reportman-web:latest \
  .
```

Si quieres usar otra ruta para el binario Linux:

```bash
docker build \
  -f server/docker/web/Dockerfile \
  --build-arg REPWEBEXE_SOURCE=server/web/Linux64/Release/repwebexe \
  -t reportman-web:${VERSION} \
  -t reportman-web:latest \
  .
```

### Paso 3 — Verificar la imagen localmente

```bash
docker images | grep reportman-web

docker run --rm \
  -p 8080:8080 \
  -e REPORTMAN_HTTP_PORT=8080 \
  -v repweb_etc:/usr/local/etc \
  -v repweb_home:/var/lib/reportman \
  -v repweb_logs:/var/log/reportman \
  reportman-web:${VERSION}
```

Resultado esperado:

- `dbxdrivers.conf` y `dbxconnections.conf` persisten en `repweb_etc`
- `reportmanserver` persiste en `repweb_home`
- el panel admin queda accesible en `http://localhost:8080/admin/login`

---

## Publicar en Docker Hub

```bash
VERSION="1.0.0"

docker tag reportman-web:${VERSION} tonimartir/reportman-web:${VERSION}
docker tag reportman-web:latest     tonimartir/reportman-web:latest

docker push tonimartir/reportman-web:${VERSION}
docker push tonimartir/reportman-web:latest
```

Comprueba el resultado en:

https://hub.docker.com/r/tonimartir/reportman-web

---

## Script preparado para WSL

Tambien tienes un script listo en:

- `server/docker/web/scripts/publish-docker-wsl.sh`

Uso minimo:

```bash
bash /mnt/c/desarrollo/prog/toni/reportman/server/docker/web/scripts/publish-docker-wsl.sh 1.0.0
```

Variables utiles:

```bash
DOCKER_HUB_REPO=tonimartir/reportman-web \
LOCAL_IMAGE_NAME=reportman-web \
REPWEBEXE_SOURCE=server/docker/web/artifacts/linux64/repwebexe \
PUSH_LATEST=1 \
bash /mnt/c/desarrollo/prog/toni/reportman/server/docker/web/scripts/publish-docker-wsl.sh 1.0.0
```

Si solo quieres publicar la etiqueta de versión y no `latest`:

```bash
PUSH_LATEST=0 \
bash /mnt/c/desarrollo/prog/toni/reportman/server/docker/web/scripts/publish-docker-wsl.sh 1.0.0
```

---

## Script completo para WSL

```bash
set -e
VERSION="1.0.0"

echo "=== [1/3] Build ==="
docker build \
  -f /mnt/c/desarrollo/prog/toni/reportman/server/docker/web/Dockerfile \
  -t reportman-web:${VERSION} \
  -t reportman-web:latest \
  /mnt/c/desarrollo/prog/toni/reportman

echo "=== [2/3] Tag Docker Hub ==="
docker tag reportman-web:${VERSION} tonimartir/reportman-web:${VERSION}
docker tag reportman-web:latest     tonimartir/reportman-web:latest

echo "=== [3/3] Push Docker Hub ==="
docker push tonimartir/reportman-web:${VERSION}
docker push tonimartir/reportman-web:latest

echo "=== Publicación completada: ${VERSION} ==="
```

---

## Ficheros persistentes relevantes

- `/usr/local/etc/dbxdrivers.conf`
- `/usr/local/etc/dbxconnections.conf`
- `/var/lib/reportman/.etc.reportmanserver`

---

## Como ejecutaria un usuario final la imagen publicada

```bash
docker run -d \
  -p 8080:8080 \
  -e REPORTMAN_HTTP_PORT=8080 \
  -v repweb_etc:/usr/local/etc \
  -v repweb_home:/var/lib/reportman \
  -v repweb_logs:/var/log/reportman \
  --name reportman-web \
  --restart unless-stopped \
  tonimartir/reportman-web:latest
```

---

## Notas operativas

- Si necesitas TLS, routing o autenticacion perimetral, pon un reverse proxy fuera del contenedor.
- Si el binario Linux requiere librerias adicionales, ajusta la lista de `apt-get install` del `Dockerfile` segun la build real.
- El puerto publicado por Docker y el puerto interno deben coincidir con `REPORTMAN_HTTP_PORT`.
- Si quieres fijar version en producción, usa `tonimartir/reportman-web:<VERSION>` en lugar de `latest`.