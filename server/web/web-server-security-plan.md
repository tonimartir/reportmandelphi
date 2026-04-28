## Plan: Reportman Web Server Security and Audit

Este plan documenta el estado actual y el trabajo pendiente del servidor web CGI/ISAPI de Reportman en `server/web`. El alcance es exclusivamente el flujo HTTP legacy de `repwebserver.dll`, `repwebexe.exe` y variantes CGI/ISAPI que comparten `rpwebpages.pas`. No incluye el servidor TCP de `server/app` ni la rama legacy `reportmand7`.

**Current scope and files**
- `c:\desarrollo\prog\toni\reportman\server\web\rpwebpages.pas` — autenticación, autorización, páginas HTML, diagnóstico `/version` y ejecución de reportes.
- `c:\desarrollo\prog\toni\reportman\server\web\rpwebmodule.pas` — entrada WebModule y routing hacia `TRpWebPageLoader`.
- `c:\desarrollo\prog\toni\reportman\server\web\reportmanserver.ini.example` — ejemplo de configuración runtime del servidor web.

**Implemented changes**
1. Añadir autenticación por cabecera `X-ReportmanServer-ApiKey` para CGI/ISAPI. La resolución de identidad ya acepta API key por header y mantiene compatibilidad con usuario/contraseña clásica según configuración.
2. Introducir configuración `[SECURITY]` con `USER_ACCESS` y `API_KEY_ACCESS`, ambas activadas por defecto si no están presentes en el `.ini`.
3. Añadir las secciones `[SERVERAPIKEYS]` y `[SERVERAPIKEYUSERS]` al modelo de configuración para mapear una API key lógica a un usuario interno existente.
4. Mantener el modelo actual de privilegios por usuario, grupos y alias sin endurecer `CheckPrivileges`. Si no hay grupos en usuario o alias, el comportamiento sigue siendo permisivo como hasta ahora.
5. Adaptar el flujo HTML para que, cuando la autenticación llega por API key header, no se propaguen `username/password` en campos ocultos del formulario de parámetros.
6. Mejorar `/version` para mostrar diagnóstico de seguridad: `USER_ACCESS`, `API_KEY_ACCESS`, tipo de conexión detectado, si se considera segura, y metadatos básicos de TLS/certificado cuando el frontend HTTP los expone.
7. Añadir `SHOWUNAUTHORIZEDPAGE` en `[SECURITY]`, activado por defecto. Si está a `0`, las respuestas de autenticación fallida devuelven `401` con texto simple; si está a `1`, mantienen la página HTML de error pero con código `401`.
8. Añadir un ejemplo runtime completo en `reportmanserver.ini.example` con todas las secciones realmente consumidas por el servidor web.
9. Añadir `URLGETPARAMS` en `[SECURITY]`, desactivado por defecto. El servidor lee `POST/ContentFields` primero y solo acepta fallback por URL/query string cuando `URLGETPARAMS=1`.
10. Duplicar las plantillas legacy `GET` como `rplogin_get.html`, `rpindex_get.html`, `rpalias_get.html` y `rpparams_get.html`.
13. Convertir las plantillas actuales `rplogin.html` y `rpparams.html` a formularios `POST`.
14. Cambiar la generación dinámica de navegación de aliases y reportes para usar formularios `POST` por defecto, conservando enlaces con query string solo cuando `URLGETPARAMS=1`.
15. Añadir al log de ejecución de reportes el usuario, nombre lógico de API key, fecha/hora, informe ejecutado, parámetros finales serializados en JSON, `REMOTE_ADDR` y `X-Forwarded-For`.
16. Añadir `[CONFIG]LOG_JSON`, activo por defecto. Cuando está activo, el servidor escribe dos ficheros: el `LOGFILE` CSV y un segundo fichero JSON Lines con extensión `.jsonl`.

**Current behavior after implemented changes**
1. Prioridad de autenticación actual:
   `X-ReportmanServer-ApiKey` header -> usuario/contraseña por query string.
2. `/version` sigue abierto para permitir diagnóstico de despliegue.
3. La validación de certificado depende del servidor web o proxy frontal. Reportman solo puede reflejar la información publicada en variables CGI/headers; no revalida por sí mismo la cadena de confianza TLS.
4. La autenticación clásica sigue dependiendo de `QueryFields` y del flujo HTML legacy. No existe aún sesión/cookie ni autenticación por `X-ReportmanServer-User` / `X-ReportmanServer-Password`.
5. El paso de parámetros y credenciales del flujo HTML legacy soporta `POST` por defecto y conserva `GET` como compatibilidad opcional mediante `URLGETPARAMS=1` y plantillas `_get`.

**Pending work: POST by default and duplicated GET pages**
1. Introducir una configuración runtime `URLGETPARAMS=0` en `reportmanserver.ini`, desactivada por defecto. Cuando `URLGETPARAMS=0`, el flujo web debe funcionar por `POST` por defecto; cuando `URLGETPARAMS=1`, se mantiene la compatibilidad con parámetros por URL.
2. Decidir la ubicación final de la clave. Si no hay una razón fuerte para separarla, agruparla en `[SECURITY]` por su relación directa con exposición de credenciales y parámetros en URL. Si se quiere distinguir semánticamente, podría ir en `[CONFIG]`, pero hay que fijarlo una vez y documentarlo en el ejemplo runtime.
3. Crear helpers comunes para obtener parámetros desde `ContentFields` y `QueryFields` con precedencia clara. Objetivo recomendado:
   `POST/ContentFields` primero y `QueryFields` solo como fallback cuando `URLGETPARAMS=1`.
4. Reemplazar accesos directos a `Request.QueryFields.Values[...]` en `rpwebpages.pas` por helpers centralizados para `username`, `password`, `aliasname`, `reportname`, `LANGUAGE`, `METAFILE`, parámetros `Param*` y flags `NULLParam*`.
5. Convertir las páginas HTML actuales a `POST` por defecto. Las plantillas actuales (`rplogin.html`, `rpindex.html`, `rpalias.html`, `rpparams.html`) deben dejar de generar enlaces o formularios que propaguen usuario, password o parámetros por URL, y deben pasar los valores necesarios a la siguiente página mediante formularios `method="post"` y campos ocultos.
6. Crear duplicados específicos de las páginas para modo `GET` legacy. Nombres propuestos:
   `rplogin_get.html`, `rpindex_get.html`, `rpalias_get.html`, `rpparams_get.html`. Estos duplicados conservan la semántica actual basada en URL/query string para clientes antiguos o despliegues que activen `URLGETPARAMS=1`.
7. Actualizar `TRpWebPageLoader` para escoger la plantilla correcta según `URLGETPARAMS`: páginas actuales para `POST` por defecto, páginas `_get` cuando `URLGETPARAMS=1`.
8. Hacer lo mismo con las plantillas HTML embebidas en código. El fallback interno debe tener variante `POST` por defecto y variante `GET` legacy, para que el comportamiento sea consistente aunque `PAGESDIR` no esté configurado.
9. Asegurar que el flujo completo de navegación funcione con `POST`: login -> índice -> alias -> parámetros -> execute. El servidor no debe asumir que `aliasname`, `reportname` o credenciales vienen siempre en la query string.
10. Mantener compatibilidad con clientes antiguos o enlaces existentes cuando `URLGETPARAMS=1`, sin cambiar el comportamiento de autenticación por API key header.
11. Cuando `URLGETPARAMS=0`, evitar que usuario, password y parámetros funcionales viajen en la URL. Los enlaces actuales que dependen de query string deben convertirse en formularios `POST` o botones submit con campos ocultos.
12. Reflejar en `/version` el estado efectivo de `URLGETPARAMS` para diagnóstico de despliegue.
13. Documentar claramente en `reportmanserver.ini.example` que el valor por defecto es `0`, que las páginas actuales son `POST`, y que las páginas `_get` quedan como compatibilidad explícita, no como modo recomendado.

**Pending work: audit log, IP log and error log**
1. Mantener `LOGFILE` como ruta base del log CSV y, cuando `LOG_JSON=1`, generar junto a él un segundo fichero JSON Lines con la misma base y extensión `.jsonl`.
2. Añadir una línea de auditoría por petición relevante con formato consistente y parseable en columnas CSV. Campos mínimos:
   fecha/hora, resultado, tipo de autenticación, usuario efectivo, alias, reporte, IP efectiva, endpoint, formato de salida, `error_message` y `stack_trace`.
3. Cuando `LOG_JSON=1`, escribir además un fichero JSON Lines append-only. Cada registro es un objeto JSON independiente en una línea, para poder añadir registros sin reescribir un array JSON completo.
4. Resolver la IP efectiva de cliente con reglas claras y verificables. Mínimo previsto:
   registrar siempre `REMOTE_ADDR` y `X-Forwarded-For`. `REMOTE_ADDR` es la conexión vista por el servidor web; `X-Forwarded-For` queda como dato diagnóstico y solo debe tratarse como origen real cuando el despliegue detrás de proxy esté expresamente documentado.
5. Incluir información de error en todos los errores capturables del flujo web, no solo en ejecución de reportes. Deben registrarse como dos columnas separadas:
   `error_message` con `E.Message` y `stack_trace` con `E.StackTrace` cuando exista.
6. Añadir logging explícito de fallos de autenticación, errores cargando configuración, errores cargando reportes, errores asignando parámetros, errores de validación de parámetros y errores generando la respuesta.
7. Decidir si los parámetros del reporte se registran completos o filtrados. Si hay riesgo de exponer datos sensibles, registrar nombres de parámetros y ocultar o truncar valores.
8. Centralizar la generación del texto de auditoría para evitar que unas rutas escriban más contexto que otras.
9. Hacer que el log siga siendo utilizable aunque `SHOWUNAUTHORIZEDPAGE=0`; el usuario puede recibir texto simple pero el servidor debe conservar el detalle del error internamente.

**Pending work: stack trace capture**
1. Confirmar y habilitar stack traces en los ejecutables/librerías web. Actualmente `rpwebpages.pas` tiene `jclDebug` comentado, por lo que el plan no debe asumir que JCLDebug ya está activo para el web server.
2. En Windows/Delphi, revisar la configuración JCLDebug usada en otros módulos del repo y activar el stack tracking equivalente para el servidor web si aplica al target compilado.
3. En Linux, replicar en los programas web el patrón ya usado por `printreptopdf`: incluir `rplinuxexceptionhandler` y llamar `InitStackTraceExceptionHandling` bajo `LINUX` + `DEBUG` antes de procesar peticiones.
4. Revisar los puntos de entrada web:
   `repwebexe.dpr`, `repweb.dpr` y cualquier variante Linux/CGI aplicable. `repwebserver.dpr` es ISAPI/Windows y no debe usar el handler Linux.
5. En el log, guardar siempre las dos columnas aunque no haya stack trace. Si `E.StackTrace` viene vacío, `stack_trace` debe quedar vacío o con un marcador explícito, pero no mezclado dentro de `error_message`.
6. En la página HTML de error se puede mantener el comportamiento actual, pero el log estructurado debe ser la fuente completa para auditoría y diagnóstico.

**Suggested implementation order for pending work**
1. Introducir `URLGETPARAMS=0` y centralizar la lectura de parámetros `POST`/`GET` en helpers comunes.
2. Duplicar las plantillas actuales a variantes `_get` antes de cambiar su comportamiento, para preservar el flujo legacy.
3. Cambiar las plantillas actuales y los fallbacks embebidos para que `POST` sea el camino principal.
4. Actualizar `TRpWebPageLoader` para seleccionar plantillas actuales o `_get` según `URLGETPARAMS`.
5. Reflejar `URLGETPARAMS` en `/version` y documentarlo en `reportmanserver.ini.example`.
6. Crear un helper para resolver IP efectiva y reutilizarlo en todo el logging.
7. Revisar y habilitar captura de stack traces: JCLDebug donde corresponda y `rplinuxexceptionhandler` en Linux siguiendo el patrón de `printreptopdf`.
8. Añadir logging de auditoría mínimo por petición, incluyendo errores de autenticación y HTTPS.
9. Extender el log de error con columnas separadas `error_message` y `stack_trace`.
10. Finalmente, completar la documentación final y la verificación de todos los modos soportados.

**Detailed logging target**
1. Éxito de autenticación por API key:
   registrar usuario efectivo, nombre lógico de API key si es razonable exponerlo internamente, IP efectiva y endpoint solicitado.
2. Éxito de autenticación por usuario clásico:
   registrar usuario efectivo, IP efectiva y endpoint.
3. Ejecución de reporte correcta:
   registrar usuario, nombre lógico de API key si aplica, `REMOTE_ADDR`, `X-Forwarded-For`, alias, reporte, parámetros finales en JSON, formato de salida y duración si es barata de medir.
4. Error funcional o técnico:
   registrar usuario si se llegó a resolver, alias/reporte si estaban presentes, IP efectiva, `error_message` y `stack_trace` en columnas separadas.
5. Errores antes de resolver usuario:
   registrar IP efectiva, endpoint, `error_message` y `stack_trace`; dejar usuario, alias y reporte vacíos si todavía no son conocidos.

**Verification**
1. Validar que `USER_ACCESS` y `API_KEY_ACCESS` funcionan por separado y combinados.
2. Validar que `SHOWUNAUTHORIZEDPAGE=1` devuelve HTML con código `401` y `SHOWUNAUTHORIZEDPAGE=0` devuelve texto simple con `401`.
3. Validar que con `URLGETPARAMS=0` el flujo completo web funciona por `POST` sin que usuario, password ni parámetros aparezcan en la URL.
4. Validar que con `URLGETPARAMS=1` se usan las páginas `_get` y siguen funcionando los clientes y enlaces legacy basados en query string.
5. Validar que `/version` refleja correctamente el estado de seguridad y la información TLS que realmente publica el servidor web frontal, incluyendo `URLGETPARAMS` cuando se implemente.
7. Validar que `/version` refleja `LOG_JSON`, la ruta CSV de `LOGFILE` y la ruta efectiva del fichero JSON Lines.
8. Cuando se implemente el logging ampliado, validar que se registran tanto éxitos como fallos y que todos los errores capturables incluyen columnas `error_message` y `stack_trace`.
9. Validar en Windows que el stack trace aparece cuando JCLDebug esté activo para el target web.
10. Validar en Linux que el stack trace aparece usando `rplinuxexceptionhandler` del mismo modo que `printreptopdf`.

**Decisions already taken**
- El header de API key del servidor web es `X-ReportmanServer-ApiKey`, distinto de otros conceptos de API key del repositorio.
- El cambio aplica solo al servidor web CGI/ISAPI.
- No se endurece `CheckPrivileges` ni se cambia el modelo de permisos por alias/grupo.
- La compatibilidad hacia atrás con usuario/contraseña clásica se mantiene por ahora.
- `reportmand7` no se toca.

**Open questions**
1. Si se llega a soportar autenticación por headers de usuario/contraseña además de API key, hay que decidir precedencia exacta respecto al query string y si se documenta solo para clientes programáticos.
2. Para el log de parámetros, hay que decidir el nivel de exposición aceptable para no volcar secretos o datos personales en claro.
3. En el cambio a `POST` por defecto, hay que decidir durante cuánto tiempo se mantendrán las páginas `_get` y si serán parte estable del producto o solo una transición legacy.
4. Para IP efectiva detrás de proxy, el log ya debe incluir tanto `REMOTE_ADDR` como `X-Forwarded-For`; queda pendiente decidir qué frontend es confiable antes de tratar `X-Forwarded-For` como origen real.