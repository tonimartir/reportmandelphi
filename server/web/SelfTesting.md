# Self Testing Plan

## Objetivo

Crear una nueva pantalla de administracion `Testing` dentro de `repwebexe` para ayudar al usuario a construir y probar llamadas HTTP al propio servidor de informes.

La pantalla debe servir para:

- seleccionar host, puerto, autenticacion y tipo de llamada
- seleccionar un informe existente
- leer el informe y mostrar sus parametros visibles
- construir la peticion HTTP real que ejecuta el informe
- ejecutar la peticion y mostrar el resultado
- si el resultado es PDF, permitir descargar el archivo generado

## Alcance funcional acordado

- La pantalla cuelga de `/admin/testing`.
- El asistente se ejecuta por fases.
- Se soportan llamadas `GET` y `POST`.
- Se soportan autenticacion por `user/password` y por `api key`.
- El formulario debe usar por defecto:
  - `host=localhost`
  - `port=puerto actual efectivo del servidor`
- `URLGETPARAMS` debe considerarse `True` por omision para compatibilidad hacia atras.
- Si `URLGETPARAMS=True`, el servidor acepta actualmente las dos variantes:
  - parametros en `POST`
  - parametros en `GET`
- El asistente debe construir la peticion real, no una simulacion interna distinta.

## Fases

### Fase 1: Pantalla inicial y seleccion del informe

#### Objetivo

Tener la nueva opcion `Testing` en la navegacion admin y una primera pantalla funcional donde el usuario defina el contexto de la llamada y seleccione un informe.

#### Entradas de usuario

- Host
- Port
- Authentication type: `user` o `api`
- Call type: `GET` o `POST`
- User
- Password
- API key
- Lista de todos los informes

#### Reglas

- `Host` debe arrancar con `localhost`.
- `Port` debe arrancar con el puerto actual efectivo cargado por el servidor.
- La lista de informes debe incluir todos los informes disponibles y conservar internamente `aliasname` y `reportname`.
- No se ejecuta ninguna peticion todavia.

#### Entregable

Pantalla `/admin/testing` operativa con el formulario inicial completo.

#### Fin de fase

La fase termina cuando el usuario puede abrir `Testing`, ver todos los informes y pasar al siguiente paso con una seleccion valida.

### Fase 2: Leer el informe y mostrar parametros

#### Objetivo

Leer el informe seleccionado y mostrar sus parametros visibles reutilizando la logica real del servidor.

#### Reglas

- La carga del informe debe reutilizar la misma base funcional que `showparams`.
- Deben mostrarse solo los parametros visibles y no marcados como `NeverVisible`.
- Deben mantenerse los datos elegidos en la fase 1.
- Todavia no se construye ni ejecuta la peticion final.

#### Entregable

Pantalla de segundo paso con el informe seleccionado y sus parametros editables.

#### Fin de fase

La fase termina cuando el usuario puede seleccionar un informe y ver correctamente sus parametros, listo para construir la peticion.

### Fase 3: Construir y visualizar el request

#### Objetivo

Transformar la seleccion y los parametros introducidos en una peticion HTTP completa y visible para el usuario.

#### Salida esperada

- URL
- Tipo de llamada
- Request headers
- Body

#### Reglas

- Debe reflejar la llamada HTTP real que el servidor acepta hoy.
- Si la autenticacion es `user`, deben reflejarse `username` y `password` como los consume el servidor.
- Si la autenticacion es `api`, debe reflejarse el header `X-ReportmanServer-ApiKey`.
- Si la llamada es `GET`, los parametros deben verse en la URL.
- Si la llamada es `POST`, los parametros deben verse en el body.
- Debe existir un boton `Build Request`.
- Todavia no se ejecuta la llamada.

#### Entregable

Vista del request completo, suficiente para que el usuario entienda como invocar el informe desde fuera.

#### Fin de fase

La fase termina cuando el asistente muestra la peticion generada con URL, metodo, headers y body correctos.

### Fase 4: Ejecutar el request

#### Objetivo

Lanzar la peticion HTTP real contra el propio servidor y mostrar el resultado.

#### Salida esperada

- Status code
- Tipo de contenido
- Headers relevantes
- Body si es texto o error
- Boton `Download` si la respuesta correcta es `application/pdf`

#### Reglas

- Debe existir un boton `Test Request`.
- La ejecucion debe hacerse por HTTP real contra el host y puerto seleccionados.
- Si la respuesta es PDF, el sistema debe conservar el resultado para descarga.
- El boton `Download` debe descargar el archivo PDF generado por esa ejecucion.
- Si la respuesta es texto o error, debe mostrarse el contenido al usuario.

#### Entregable

Pantalla final del asistente con resultado de prueba y descarga de PDF cuando proceda.

#### Fin de fase

La fase termina cuando el usuario puede probar la llamada y, si obtiene un PDF correcto, descargarlo desde el propio asistente.

## Orden de implementacion

1. Fase 1: formulario inicial con lista de informes
2. Fase 2: lectura del informe y visualizacion de parametros
3. Fase 3: construccion y visualizacion del request
4. Fase 4: ejecucion real y descarga del PDF

## Criterio de trabajo

- Se ejecuta por fases, sin mezclar objetivos.
- No se pasa a la siguiente fase hasta dejar cerrada la anterior.
- Siempre que sea posible, se reutiliza la logica existente de `showparams`, autenticacion y ejecucion real.
- El objetivo principal de esta pantalla es didactico y operativo: que el usuario entienda exactamente como construir una llamada valida al servidor de informes.