# Conexiones del Reportman Agent: asistente de conexión (plan)

Estado: la fase 1 está decidida y hecha (29-09-2026) salvo el cambio del Hub;
las fases 2 y 3 están pendientes de aprobar. Afecta al diseñador
Delphi (VCL) y al de Lazarus (LCL) por igual, al motor común (`rpdatainfo`) y,
en un punto, al Hub (`C:\desarrollo\ReportmanAI`).

## Situación

- **Qué es una conexión del Agent en un informe**: solo un nombre
  (`DatabaseInfo`, controlador `rpdbHttp`, `LoadParams=True`). La base de
  datos del Hub (`HubDatabaseId`) y la clave (`ApiKey`) se leen de la entrada
  con ese nombre del fichero de conexiones del usuario
  (`dbxconnections.ini` en Windows, `~/.borland/dbxconnections` en Linux).
- **Quién da acceso**:
  - Con la sesión iniciada, el Hub busca la base de datos entre las del
    usuario por su email (`AgentController.RouteToAgent`,
    `FindDatabaseForUser`). El Agent solo comprueba la clave si le llega una
    (`DataActionDispatcher.ValidateApiKey`). Sin clave funciona si la cuenta
    tiene acceso a esa base de datos.
  - Sin sesión (servidor, web, `printreptopdf`), o para quien no tiene acceso
    con su cuenta, la clave es imprescindible. Es lo normal: la clave es el
    secreto que da acceso a una base de datos remota.
- **El asistente de informe nuevo** ya pide bien la conexión, paso a paso:
  ruta (Agent), nombre, clave, base de datos y esquema. Pero solo se abre con
  Archivo > Nuevo.
- **El fallo encontrado en Ubuntu (y también en Windows)**:
  1. El chat de diseño recibe del Hub el informe con la conexión por su
     nombre (`TONI`), sin entrada en el fichero de conexiones.
  2. El motor pide los datos con `HubDatabaseId=0`.
  3. El Hub no encuentra la base de datos y llama a
     `Forbid("No access to this database...")`. ASP.NET toma ese texto como
     nombre de esquema de autenticación, lanza una excepción y responde 500.
  4. Vista previa y Mostrar datos dan "Internal server error 500".
  Funciona después de crear la conexión con el asistente de informe nuevo,
  pero exige saber que hay que hacerlo.

## Objetivo

Que conectar con una base de datos a través del Agent sea igual de guiado en
cualquier momento, no solo al crear un informe, y que una conexión sin
configurar diga qué pasa y lleve al asistente.

## Fase 1: errores claros y el caso del chat de diseño (pequeña)

Decisión (Toni, 29-09-2026): desde el diseñador basta la sesión del usuario y
la clave no es obligatoria. Sin diseñador (`printreptopdf`, servidor), una
conexión sin clave y sin sesión da un error claro. Todo en Delphi y en FPC.

1. **Conexiones que añade el chat de diseño** (hecho):
   `RpEnsureAgentConnections` (en `rpdatainfo`, común). Al aplicar un diseño
   de la IA, cada conexión del Agent del informe que no esté en el fichero de
   conexiones (o esté sin `HubDatabaseId`) se escribe con la base de datos del
   esquema elegido en el chat, y con su clave si ese esquema vino de una
   clave. Las conexiones ya configuradas no se tocan. Prueba en
   HubClientTest; compila en Delphi Win32 y Linux64.
2. **Errores claros en el motor** (hecho, común Delphi/FPC, en
   `TRpDatabaseInfoItem.Connect`): una conexión del Agent no llama al Hub si
   no puede funcionar, y lanza `ERpAgentConnectionError` (en `rpdatahttp`, con
   el nombre de la conexión, para que el diseñador pueda ofrecer el
   asistente en la fase 3):
   - sin `HubDatabaseId`: "La conexión "TONI" (Reportman AI Agent) no está
     configurada en este equipo: no tiene base de datos del Hub..." (id 1824);
   - sin clave y sin sesión: "...no tiene clave de API y no hay ninguna sesión
     de Reportman AI iniciada. Inicie sesión desde el diseñador, o añada la
     clave de API de la conexión en el fichero de conexiones para ejecutar el
     informe sin sesión (printreptopdf, servidor)" (id 1825).
3. **Hub** (hecho en ReportmanAI, commit `83de85a9`, pendiente de desplegar):
   `return Forbid("mensaje")` cuando no hay acceso a la base de datos. Los
   nueve `Forbid(...)`/`Forbid()` del API pasan a un 403 real; comprobado
   con un servidor mínimo con la misma configuración (Forbid: 500 vacío con
   "No authentication handlers are registered"; el arreglo: 403 con el
   motivo).
   - **Por qué da 500**: en ASP.NET `Forbid(...)` no recibe un mensaje sino
     nombres de esquemas de autenticación. El Hub no usa la autenticación de
     ASP.NET (tiene `TokenAuthenticationMiddleware` propio), así que
     `ForbidAsync` lanza una excepción no controlada y la respuesta es un 500
     vacío. Comprobado en producción: `testconnection` anónimo con
     `hubDatabaseId=0` devuelve `HTTP 500, 0 bytes`.
   - **Dónde**: `AgentController.RouteToAgent` (execute sin streaming,
     testconnection, readtables, gettableschema, previewdata, readcolumns,
     readforeignkeys), `schema/save`, la transcripción y
     `DataSessionController` (inicio del canal directo). La variante con
     streaming de `execute` (`RouteToAgentWithKeepaliveAsync`) ya responde bien:
     403 con `{"error": "..."}`.
   - **Cambio**: `StatusCode(StatusCodes.Status403Forbidden, "mensaje")`, como
     los demás errores de `RouteToAgent` (502, 503, 504).
   - **Compatibilidad**: ningún cliente cambia de comportamiento, solo el
     mensaje. Delphi/FPC (`rpdatahttp`), el cliente C# (`HubApiClient`) y la
     web solo tratan aparte el 401 (cierran la sesión); cualquier otro código
     es un error con el texto del cuerpo, sin reintentos. El canal directo
     vuelve a HTTP ante cualquier código que no sea 2xx. Los clientes que usan
     `execute` con streaming ya reciben hoy ese 403. No debe usarse 401:
     cerraría la sesión en todos los clientes.
4. **Registro** (hecho): la clave de un esquema salía en claro en el registro
   del chat de diseño (nueve sitios en Delphi y Lazarus). Ahora
   `RpMaskSecret` (en `rpauthmanager`) muestra solo sus primeros caracteres.

## Fase 2: el asistente de conexión

El asistente actual con un **modo conexión**: la misma ventana y las mismas
páginas, en Delphi y en Lazarus, sin duplicar código.

- **Páginas**:
  1. Ruta: Agent o conexión directa, sin la opción "sin conexión".
  2. Nombre: conexión nueva o existente.
  3. Clave.
  4. Base de datos del Hub.
  5. Esquema.
  6. Parámetros y prueba, en las conexiones directas.
  7. Terminar.
  No tiene la página de la petición a la IA.
- **Al terminar**:
  - guarda la entrada en el fichero de conexiones (lo que ya hace hoy);
  - añade o actualiza la conexión del informe (`DatabaseInfo`);
  - devuelve el nombre, la base de datos, el esquema y la clave a quien lo
    abrió.
- **Datos de partida opcionales**:
  - nombre fijo, para configurar una conexión que ya usa el informe;
  - esquema preseleccionado (el `HubSchemaId` del dataset);
  - clave precargada.
- **Asistente de informe nuevo**: sigue igual; es el modo conexión más la
  página final de la petición a la IA.

## Fase 3: dónde se abre

1. **Configuración de datos > Conexiones**:
   - botón "Asistente..." para una conexión nueva;
   - con una conexión del Agent seleccionada, "Configurar con el asistente".
2. **Diálogo de conexiones**: "Nueva con el asistente".
3. **Al abrir los datos** (vista previa, Mostrar datos, contexto de la IA):
   1. Con una conexión del Agent sin configurar en este equipo, el error de
      1.2 muestra "La conexión TONI usa el Reportman Agent y no está
      configurada en este equipo. ¿Configurarla ahora?".
   2. El asistente se abre en modo conexión, con el nombre fijo y el esquema
      del dataset preseleccionado.
   3. Al terminar, se reintenta.
4. **Tras un diseño de la IA**: 1.1 deja la conexión lista para el diseñador
   (con la sesión, o con la clave si el esquema vino de una). Si quedó sin
   clave, el chat avisa: "Conexión TONI creada con tu sesión; para ejecutar el
   informe sin iniciar sesión (servidor, web) añade una clave", con enlace al
   asistente.

## Fase 4 (aplazada): informe portátil

Guardar el `HubDatabaseId` dentro de la conexión del informe, para que abra
en cualquier equipo con sesión sin configurar nada. Cambia el formato `.rep`
y afecta al motor C# y al Hub. Con las fases 2 y 3 quizá no haga falta:
se decide después de usarlas.

## Pruebas

- **HubClientTest**:
  - `RpEnsureAgentConnections` (hecha);
  - el error claro de una conexión sin configurar, sin llamar al Hub.
- **LclAIChatTest**:
  - el asistente en modo conexión: páginas, nombre fijo, esquema
    preseleccionado, lo que guarda en el fichero y en el informe;
  - los puntos de entrada de la configuración de datos y del diálogo de
    conexiones;
  - la oferta del asistente al abrir datos de una conexión sin configurar.
- **Delphi**: compilación del grupo (Win32, Win64, Linux64).
- **A mano**: el Ubuntu de Hyper-V (XFCE) y Windows con la cuenta real.

## Decisiones pendientes

1. **1.3**: ¿se corrige el Hub en ReportmanAI dentro de este trabajo?
2. **Fases 2 y 3**: ¿adelante?
3. **Fase 4**: ¿queda aplazada?
