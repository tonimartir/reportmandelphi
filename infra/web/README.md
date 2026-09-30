# `reportman.es`, servida desde la VM

Hasta el 30-09-2026 esta web vivía en **otro host** (91.134.113.42), con un nginx ajeno y un
despliegue a mano: `doc/dev/upload.txt` todavía explica cómo subir un `doc.zip` por `scp` y
descomprimirlo entrando por **telnet a SourceForge**. El resultado previsible es que lo publicado se
quedaba atrás: la versión del 20-06-2026 anunciaba Report Manager **4.0.10** cuando el repositorio ya
iba por la **4.0.16** y con Lazarus.

Ahora se sirve desde esta VM, donde vive el repositorio, con el mismo reparto que
`ai.reportman.es` y `erpaisoftware.com`: el anfitrión Windows es la IP pública, su IIS termina el
TLS (win-acme) y hace de **proxy inverso**; por el conmutador privado sólo viaja HTTP.

    Internet ──443──> IIS (anfitrión, win-acme) ──80──> 192.168.100.2:5083 ──> nginx ──> ~/webs/reportman-es/actual

## La raíz de la web es `doc/`

No es una carpeta de documentación mal puesta: ahí están `index.html`, `company.html`,
`download.html`, sus gemelas en castellano (`indexes.html`, `companyes.html`…) y las carpetas
`doc/`, `docnet/`, `tutorial/` y `training/`. Son **921 ficheros** y 37 MB.

**No se construye nada.** El HTML del repositorio *es* el artefacto. Existe
`doc/_build/build-docs.mjs`, pero es una herramienta de **autoría**: reescribe las páginas **en
sitio**, dentro del repositorio, cuando cambia la navegación, y se lanza a mano. El despliegue no la
llama — hacerlo modificaría el árbol de trabajo a espaldas de quien despliega.

**`_build/` no se publica**, y no es una decisión mía: lo dice el propio sitio en
`doc/robots.txt` — «*Build tooling (not part of the published site)*». El despliegue lo excluye y
comprueba que `/_build/build-docs.mjs` devuelve 404. En el host viejo sí estaba, porque allí se subía
un zip de la carpeta entera.

## Nada pide root

| Fichero | Cuándo | Qué hace |
|---|---|---|
| `preparar-web.sh` | una vez | `~/webs/reportman-es`, un release vacío, `docker compose up -d`, `nginx -t`, comprobar |
| `docker-compose.yml` | la usa la anterior | el contenedor `web-reportman-es`: `192.168.100.2:5083`, el sitio montado **de sólo lectura** |
| `reportman-es.conf` | montado, no instalado | el vhost: `:5083`, raíz en `actual`, `.webmanifest` con su tipo |
| `desplegar-web.sh` | cada publicación | pull → release (sin `_build`) → **repuntar `actual`** → comprobar nueve rutas → poda |

    infra/web/preparar-web.sh           # una vez
    infra/web/desplegar-web.sh --seco   # dice qué publicaría
    infra/web/desplegar-web.sh          # publica

Publicar es repuntar un enlace relativo con `mv -T` (un rename: nunca hay un instante sin `actual`).
Volver atrás son dos órdenes, en la cabecera del guion, y se guardan los cinco últimos releases.

## Lo que falta para que el dominio apunte aquí

1. **Sitio nuevo en el IIS del anfitrión**, carpeta física vacía, bindings :80 para `reportman.es` y
   `www.reportman.es`, **win-acme para los dos nombres**, y el `web.config` de proxy a
   `http://192.168.100.2:5083` — el mismo patrón que los otros dos, con la regla del reto ACME
   primera y con `stopProcessing`.
2. **DNS**: los registros `A` de `reportman.es` y `www.reportman.es` pasan de `91.134.113.42` a
   `51.178.118.23`.

### Y una cosa que NO se puede mover con ellos

**`mail.reportman.es` vive en el host viejo** (`91.134.113.42`), y es por donde entra
`info@reportman.es` — el contacto legal declarado en el aviso legal de las dos webs comerciales y en
la declaración responsable del art. 15.2.a). Tiene su **propio registro `A`**, así que mover el apex
y el `www` no lo toca; pero **el día que ese host se apague, el buzón se va con él**, y con el buzón
la dirección de contacto que consta en un documento fiscal. Antes de dar de baja ese servidor hay que
mover el correo y volver a publicar la declaración.

## Comprobado antes de proponer el cambio (30-09-2026)

- **Las 541 URL del sitemap** responden 200 en la VM. Una no: `/doc/mfeatures.html`, que **ya daba
  404 en el host viejo** — se borró en `18d6fee` («drop mfeatures») y quedó anunciada en el sitemap.
  Se ha quitado de ahí, que es lo que tocaba: una URL muerta en el sitemap es un 404 que le sirves a
  Google tú mismo.
- **No hay binarios que migrar**: las descargas de `download.html` van a GitHub, SourceForge y Docker
  Hub, no a ficheros alojados en el host.
- Quedan **cuatro enlaces internos roto** en la documentación .NET (`docnet/api/Reportman.html` y dos
  namespaces más, que el generador de API no emite, y un `href` vacío en `doc/axtivexcomp.html`).
  Están igual de roto en el host viejo: no son de esta mudanza, pero ahí quedan anotados.
