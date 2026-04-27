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
6. Añadir `REQUIRE_HTTPS` en `[SECURITY]`, desactivado por defecto. Cuando se activa, el servidor exige conexión segura para todos los endpoints salvo `/version`.
7. Mejorar `/version` para mostrar diagnóstico de seguridad: `USER_ACCESS`, `API_KEY_ACCESS`, `REQUIRE_HTTPS`, tipo de conexión detectado, si se considera segura, y metadatos básicos de TLS/certificado cuando el frontend HTTP los expone.
8. Añadir `SHOWUNAUTHORIZEDPAGE` en `[SECURITY]`, activado por defecto. Si está a `0`, las respuestas de autenticación fallida devuelven `401` con texto simple; si está a `1`, mantienen la página HTML de error pero con código `401`.
9. Hacer que `REQUIRE_HTTPS` devuelva `403` cuando la petición no se considere segura.
10. Añadir un ejemplo runtime completo en `reportmanserver.ini.example` con todas las secciones realmente consumidas por el servidor web.

**Current behavior after implemented changes**
1. Prioridad de autenticación actual:
   `X-ReportmanServer-ApiKey` header -> usuario/contraseña por query string.
2. `/version` sigue abierto incluso con `REQUIRE_HTTPS=1` para permitir diagnóstico de despliegue.
3. La validación de certificado depende del servidor web o proxy frontal. Reportman solo puede reflejar la información publicada en variables CGI/headers; no revalida por sí mismo la cadena de confianza TLS.
4. La autenticación clásica sigue dependiendo de `QueryFields` y del flujo HTML legacy. No existe aún sesión/cookie ni autenticación por `X-ReportmanServer-User` / `X-ReportmanServer-Password`.
5. El paso de parámetros y credenciales del flujo HTML legacy sigue siendo mayoritariamente `GET`-céntrico. El objetivo futuro es soportar ambos métodos, pero dejar `POST` como vía por defecto y `GET` como compatibilidad opcional.

**Pending work: POST by default and optional GET query params**
1. Introducir una configuración runtime `URLGETPARAMS=0` en `reportmanserver.ini`, desactivada por defecto. Cuando `URLGETPARAMS=0`, el flujo web debe funcionar por `POST` por defecto; cuando `URLGETPARAMS=1`, se mantiene la compatibilidad con parámetros por URL.
2. Decidir la ubicación final de la clave. Si no hay una razón fuerte para separarla, agruparla en `[SECURITY]` por su relación directa con exposición de credenciales y parámetros en URL. Si se quiere distinguir semánticamente, podría ir en `[CONFIG]`, pero hay que fijarlo una vez y documentarlo en el ejemplo runtime.
3. Crear helpers comunes para obtener parámetros desde `ContentFields` y `QueryFields` con precedencia clara. Objetivo recomendado:
   `POST/ContentFields` primero y `QueryFields` solo como fallback cuando `URLGETPARAMS=1`.
4. Reemplazar accesos directos a `Request.QueryFields.Values[...]` en `rpwebpages.pas` por helpers centralizados para `username`, `password`, `aliasname`, `reportname`, `LANGUAGE`, `METAFILE`, parámetros `Param*` y flags `NULLParam*`.
5. Cambiar las páginas HTML legacy para que los formularios principales usen `method="post"` en vez de `get`, empezando por login, índice/alias cuando aplique y, sobre todo, la página de parámetros y la ejecución del reporte.
6. Asegurar que el flujo completo de navegación siga funcionando con `POST`: login -> índice -> alias -> parámetros -> execute. El servidor no debe asumir que `aliasname`, `reportname` o credenciales vienen siempre en la query string.
7. Mantener compatibilidad con clientes antiguos o enlaces existentes cuando `URLGETPARAMS=1`, sin cambiar el comportamiento de autenticación por API key header.
8. Cuando `URLGETPARAMS=0`, evitar que usuario, password y parámetros funcionales viajen en la URL. Si hay enlaces que hoy dependen de query string, sustituirlos por formularios `POST` o por una transición controlada entre páginas.
9. Reflejar en `/version` el estado efectivo de `URLGETPARAMS` para diagnóstico de despliegue.
10. Documentar claramente en `reportmanserver.ini.example` que el valor por defecto es `0` y que el uso de `GET` queda como compatibilidad explícita, no como modo recomendado.

**Pending work: IP whitelist**
1. Confirmar primero la fuente de verdad. A día de hoy no existe whitelist de IP implementada en el código de Reportman Web Server. Si Simon o infraestructura hablan de una whitelist existente, probablemente reside en IIS, Apache, firewall, reverse proxy o balanceador.
2. Si se implementa en la aplicación, definir una sección nueva, por ejemplo `[IP_WHITELIST]` o una clave en `[SECURITY]` con una lista explícita de IPs o rangos permitidos.
3. Resolver la IP efectiva de cliente con reglas claras y verificables. Mínimo previsto:
   `REMOTE_ADDR` como origen principal, y `X-Forwarded-For` solo cuando el despliegue detrás de proxy esté expresamente soportado y documentado.
4. Decidir formato admitido: IP exacta, CIDR, rangos simples o lista plana. Empezar por lista plana de IP exacta si se busca mínimo riesgo.
5. Rechazar con `403` cuando la IP no esté permitida.
6. Reflejar en `/version` si la whitelist está activa y qué fuente de IP se está usando para evaluación, sin exponer información sensible innecesaria.
7. Documentar en `reportmanserver.ini.example` cómo activar la whitelist y cómo se interpreta detrás de reverse proxy.

**Pending work: audit log and error log**
1. Mantener el `LOGFILE` actual como destino único inicial para no introducir una infraestructura nueva.
2. Añadir una línea de auditoría por petición relevante con formato consistente y legible. Campos mínimos:
   fecha/hora, resultado, tipo de autenticación, usuario efectivo, alias, reporte, IP efectiva, endpoint, formato de salida, `REQUIRE_HTTPS` activo, y mensaje resumido.
3. Incluir información de error cuando falle una operación. Mínimo:
   mensaje de error y stack trace si existe.
4. Añadir logging explícito de fallos de autenticación y de rechazo por `REQUIRE_HTTPS`, no solo de ejecución de reportes correctos.
5. Decidir si los parámetros del reporte se registran completos o filtrados. Si hay riesgo de exponer datos sensibles, registrar nombres de parámetros y ocultar o truncar valores.
6. Centralizar la generación del texto de auditoría para evitar que unas rutas escriban más contexto que otras.
7. Hacer que el log siga siendo utilizable aunque `SHOWUNAUTHORIZEDPAGE=0`; el usuario puede recibir texto simple pero el servidor debe conservar el detalle del error internamente.

**Suggested implementation order for pending work**
1. Introducir `URLGETPARAMS=0` y centralizar la lectura de parámetros `POST`/`GET` en helpers comunes.
2. Cambiar los formularios HTML del flujo legacy para que `POST` sea el camino principal.
3. Reflejar `URLGETPARAMS` en `/version` y documentarlo en `reportmanserver.ini.example`.
4. Crear un helper para resolver IP efectiva y reutilizarlo tanto para logging como para futura whitelist.
5. Añadir logging de auditoría mínimo por petición, incluyendo errores de autenticación y HTTPS.
6. Extender el log de error con mensaje y stack trace donde existan.
7. Solo después, añadir whitelist de IP con `403`, reutilizando la IP efectiva ya resuelta y registrada.
8. Finalmente, completar la documentación final y la verificación de todos los modos soportados.

**Detailed logging target**
1. Éxito de autenticación por API key:
   registrar usuario efectivo, nombre lógico de API key si es razonable exponerlo internamente, IP efectiva y endpoint solicitado.
2. Éxito de autenticación por usuario clásico:
   registrar usuario efectivo, IP efectiva y endpoint.
3. Ejecución de reporte correcta:
   registrar alias, reporte, formato de salida y duración si es barata de medir.
4. Error funcional o técnico:
   registrar usuario si se llegó a resolver, alias/reporte si estaban presentes, mensaje de error y stack trace.
5. Rechazo por `REQUIRE_HTTPS`:
   registrar IP efectiva, tipo de conexión detectada y raw hints relevantes (`HTTPS`, `SERVER_PORT_SECURE`, `X-Forwarded-Proto`) si ayudan al diagnóstico.

**Verification**
1. Validar que `USER_ACCESS` y `API_KEY_ACCESS` funcionan por separado y combinados.
2. Validar que `SHOWUNAUTHORIZEDPAGE=1` devuelve HTML con código `401` y `SHOWUNAUTHORIZEDPAGE=0` devuelve texto simple con `401`.
3. Validar que `REQUIRE_HTTPS=1` devuelve `403` en HTTP y permite la llamada cuando el frontend marca la petición como HTTPS.
4. Validar que con `URLGETPARAMS=0` el flujo completo web funciona por `POST` sin que usuario, password ni parámetros aparezcan en la URL.
5. Validar que con `URLGETPARAMS=1` siguen funcionando los clientes y enlaces legacy basados en query string.
6. Validar que `/version` refleja correctamente el estado de seguridad y la información TLS que realmente publica el servidor web frontal, incluyendo `URLGETPARAMS` cuando se implemente.
7. Cuando se implemente la whitelist, validar al menos un caso permitido y uno denegado, incluyendo despliegue detrás de proxy si aplica.
8. Cuando se implemente el logging ampliado, validar que se registran tanto éxitos como fallos y que los errores incluyen mensaje y stack trace cuando esté disponible.

**Decisions already taken**
- El header de API key del servidor web es `X-ReportmanServer-ApiKey`, distinto de otros conceptos de API key del repositorio.
- El cambio aplica solo al servidor web CGI/ISAPI.
- No se endurece `CheckPrivileges` ni se cambia el modelo de permisos por alias/grupo.
- La compatibilidad hacia atrás con usuario/contraseña clásica se mantiene por ahora.
- `reportmand7` no se toca.

**Open questions**
1. Si se llega a soportar autenticación por headers de usuario/contraseña además de API key, hay que decidir precedencia exacta respecto al query string y si se documenta solo para clientes programáticos.
2. Antes de implementar whitelist en la aplicación, conviene confirmar si la infraestructura ya aplica una restricción equivalente y dónde.
3. Para el log de parámetros, hay que decidir el nivel de exposición aceptable para no volcar secretos o datos personales en claro.
4. En el cambio a `POST` por defecto, hay que decidir qué endpoints seguirán aceptando `GET` por compatibilidad y durante cuánto tiempo.