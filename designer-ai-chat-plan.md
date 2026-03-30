## Plan: Designer AI Chat

Integrar un chat de IA persistente en el diseñador principal de Report Manager, reutilizando la infraestructura ya creada para autenticación, selección de modelo/agente, streaming y chat contextual, pero ampliándola para operar sobre el informe completo. El flujo será único: modificar el informe actual. Si el usuario pide crear uno nuevo, el sistema ejecutará antes `report new` y continuará por el mismo pipeline de modificación, siempre con cambios aplicados de forma segura y compatibles con UndoCue.

**Steps**
1. Añadir un panel lateral compartido para IA y cola de deshacer en el diseñador principal dentro de `c:\desarrollo\prog\toni\reportman\rpmdfmainvcl.pas` y `c:\desarrollo\prog\toni\reportman\rpmdfmainvcl.dfm`, siguiendo el patrón ya usado para `fcuepanel` y `fcuesplitter`. El panel debe contener ambas vistas en pestañas distintas, con la pestaña del chat activa por omisión al abrir la interfaz. Su ciclo de vida debe seguir gestionado desde `CreateInterface` / `FreeInterface`. *Bloquea el resto*.
2. Crear un frame específico para chat de diseñador, preferiblemente en un nuevo archivo VCL reutilizable, tomando como base `c:\desarrollo\prog\toni\reportman\rpfrmexpressionchatvcl.pas` y `c:\desarrollo\prog\toni\reportman\rpfrmaiselectionvcl.pas`. Debe conservar: login embebido, selección de tier/agente, streaming asíncrono, botones de enviar/aplicar/limpiar y layout adaptable. Debe excluir lo específico del diálogo de expresiones. *Depende de 1*.
3. Definir una capa de contexto de diseño que el chat pueda consultar antes de cada prompt. Esa capa debe exponer: estructura del informe (subreports, sections, componentes), selección actual del diseñador, datasets/aliases/campos disponibles, parámetros, y posiblemente propiedades visuales relevantes. El contexto debe construirse desde el estado del diseñador/report actual sin acoplar el chat a controles visuales concretos. *Depende de 2*.
4. Diseñar un contrato de prompts y respuestas para un único flujo de trabajo: modificar el informe actual. Si el usuario pide crear uno nuevo, el sistema hará `report new` antes de procesar la solicitud y seguirá exactamente el mismo pipeline. Separar claramente respuestas informativas de respuestas aplicables. Para cambios aplicables, la IA debe devolver una representación estructurada de acciones sobre el diseñador, no solo texto libre. *Depende de 3*.
5. Integrar la aplicación de cambios con UndoCue usando la arquitectura existente del repositorio. Toda operación sugerida por IA que modifique el informe debe traducirse a operaciones undoables (`add`, `modify`, `remove`, `reorder`) y refrescar inmediatamente el cue view. Esto incluye creación de secciones, componentes, cambios de propiedades y enlaces a datasets. *Depende de 4*.
6. Implementar un pipeline de aplicación incremental para el diseñador principal: previsualizar la propuesta, validar referencias (dataset, alias, componente, section), aplicar cambios por lotes coherentes y abortar con mensaje claro si alguna referencia no existe. Recomendación: empezar por un subconjunto seguro de operaciones y ampliar después. *Depende de 5*.
7. Añadir soporte para resetear el informe cuando el usuario pida uno nuevo: ejecutar `report new`, reconstruir el contexto base del diseñador y continuar la petición como una modificación normal del informe recién creado. *Depende de 5 y 6*.
8. Añadir soporte de contexto para modificación del informe actual: cuando exista selección actual o contexto activo, el chat debe poder operar sobre componentes concretos, secciones concretas o el informe entero. Recomendación: enriquecer el contexto con selección, jerarquía y nombres internos, no solo captions. *Depende de 3, 5 y 6*.
9. Reutilizar la infraestructura de autenticación y carga de agentes existente (`TRpAuthManager`, `TFRpAISelectionVCL`, patrón `TThread.CreateAnonymousThread` + `PostMessage`) para que el panel de diseñador no reimplemente login ni refresco de agentes. *Paralelo con 2 una vez fijada la API del frame*.
10. Añadir verificación y seguridad operativa: no aplicar cambios destructivos sin representación estructurada válida, tolerar respuestas parciales, descartar resultados obsoletos de prompts anteriores, y mantener el diseñador usable mientras llega la respuesta. *Depende de 4, 5 y 6*.

**Relevant files**
- `c:\desarrollo\prog\toni\reportman\rpmdfmainvcl.pas` — `TFRpMainFVCL`, `CreateInterface`, `FreeInterface`, `EnsureUndoCue`, `RefreshCueView`; punto de entrada del panel de IA en el diseñador principal.
- `c:\desarrollo\prog\toni\reportman\rpmdfmainvcl.dfm` — layout base del diseñador; referencia para acoplar nuevo panel/splitter sin romper la distribución actual.
- `c:\desarrollo\prog\toni\reportman\rpfrmexpressionchatvcl.pas` — patrón reutilizable de chat, auth, AI selection, streaming y carga asíncrona de agentes.
- `c:\desarrollo\prog\toni\reportman\rpfrmaiselectionvcl.pas` — selector común de proveedor/modo/agente y estado de créditos.
- `c:\desarrollo\prog\toni\reportman\rpauthmanager.pas` — autenticación global y estado del usuario.
- `c:\desarrollo\prog\toni\reportman\rpdatahttp.pas` — transporte HTTP para prompts/respuestas/streaming.
- `c:\desarrollo\prog\toni\reportman\rpmdundocue.pas` — integración obligatoria para aplicar cambios undoables sugeridos por IA.
- `c:\desarrollo\prog\toni\reportman\rpmdcueviewvcl.pas` — visualización del cue/undo, a refrescar tras cambios aplicados por IA.
- `c:\desarrollo\prog\toni\reportman\rpmdfdesignvcl.pas` — acceso al frame/canvas del diseñador y posible fuente del contexto de selección actual.
- `c:\desarrollo\prog\toni\reportman\rpmdobjinspvcl.pas` y `c:\desarrollo\prog\toni\reportman\rpmdfstrucvcl.pas` — referencias para selección, estructura y edición actual del informe.

**Verification**
1. Abrir el diseñador principal y comprobar que el panel de IA aparece y desaparece junto con `CreateInterface` / `FreeInterface` sin fugas visuales ni AVs.
2. Verificar login, carga de agentes y selección de tier/agente usando la misma cuenta ya soportada por Monaco y el diálogo de expresiones.
3. En un informe vacío, pedir a la IA crear una estructura básica y comprobar que el resultado se aplica mediante operaciones undoables y queda reflejado en el cue view.
4. En un informe existente, pedir una modificación localizada y comprobar que solo se alteran los elementos referidos y que Undo/Redo revierte/aplica correctamente.
5. Forzar respuestas inválidas o incompletas y comprobar que el diseñador no queda corrupto, que se informa al usuario y que no se aplican cambios parciales inseguros.
6. Validar que el panel sigue siendo usable mientras hay prompts en curso y que respuestas obsoletas no pisan estado más reciente.
7. Compilar al menos los archivos nuevos del chat del diseñador y `rpmdfmainvcl.pas`; idealmente compilar el proyecto/paquete VCL completo afectado.

**Decisions**
- El chat del diseñador debe ser específico del informe completo; no conviene reutilizar tal cual el frame de expresiones porque ese frame arrastra semántica y UI orientadas a expresiones. Sí conviene reutilizar sus patrones internos.
- Los cambios aplicados por IA deben ser estructurados y undoables; texto libre sin traducción a operaciones no es suficiente para modificar el informe con seguridad. El DSL inicial debe ser mínimo: un array de operaciones con tipo `Add`, `Remove` o `Modify`, nombre del objeto cuando aplique y bloque de propiedades. `Modify` debe aceptar varias propiedades a la vez (`set-properties`), no cambios atómicos demasiado finos.
- El soporte inicial debe priorizar operaciones seguras y comunes: resetear con `report new` cuando el usuario lo pida, y después añadir/modificar estructura base, labels, expressions y propiedades, antes de cubrir casos complejos como charts o subreports anidados complejos.
- La experiencia debe tener un único flujo de modificación, con contexto del diseñador y de la selección activa; crear un informe nuevo será solo un caso especial que empieza con `report new`.
- El chat de IA y la cola de deshacer deben compartir un único panel lateral en la banda derecha, organizados en pestañas separadas. La pestaña activa por omisión debe ser la del chat.
- Los botones Undo y Redo deben salir del panel de la cola y pasar a la barra de herramientas principal del diseñador, para que queden accesibles de forma directa y coherente con el resto de acciones frecuentes.
- Mantener una copia visible del plan en la raíz del repositorio para otros agentes y herramientas del workspace; esa copia debe reflejar fielmente este plan persistente y actualizarse cuando cambien las decisiones arquitectónicas.

**Further Considerations**
1. Diseñar la integración visual del panel compartido para que el cambio entre pestañas Chat y UndoCue no reste demasiado ancho útil al canvas. Recomendación: mantener una cabecera de pestañas simple y conservar el splitter actual de la banda derecha.
2. Definir pronto el formato del contexto serializado del informe. Recomendación: JSON jerárquico por subreport -> section -> component, con nombres internos estables y metadatos de datasets/fields aparte.
3. Definir pronto el formato de “acciones aplicables” devueltas por IA. Recomendación: array ordenado de operaciones `Add` / `Remove` / `Modify`, con propiedades útiles por tipo de objeto y reglas globales explícitas en el prompt, por ejemplo que posición y tamaño se expresan en twips.

**Operation JSON**
- Estructura base recomendada por operación:
  - `operation`: `Add` | `Remove` | `Modify`
  - `name`: `UniqueObjectName` (vacío o `null` para objetos nuevos si el runtime genera el nombre)
  - `className`: tipo lógico del objeto, por ejemplo `Expression`, `Label`, `Section`, `SubReport`
  - `properties`: array de pares propiedad/valor para mantener el formato genérico
- Recomendación práctica: serializar `properties` como array de objetos `{ "name": string, "value": any }` en lugar de tuplas posicionales, porque es más robusto para validación, evolución del esquema y parsing en Delphi.
- Para que `Add` sea realmente aplicable de forma genérica, conviene añadir al menos un dato de contenedor o destino, por ejemplo `parentName` o `sectionName`, ya que un objeto nuevo necesita saber dónde crearse.
- Para `Remove` y `Modify`, `name` debe referirse siempre al nombre interno único del objeto, no al caption visible.
- Reglas globales del prompt: posiciones y tamaños en twips; no inventar nombres de datasets/campos/sections; usar solo propiedades válidas para `className`; omitir propiedades irrelevantes en vez de rellenarlas con valores ficticios.
- Ejemplo conceptual:
  - `{ "operation": "Modify", "name": "EXP_CLIENT_TOTAL", "className": "Expression", "properties": [{"name":"Left","value":1440},{"name":"Top","value":720},{"name":"Width","value":2880},{"name":"Expression","value":"Customers.Total"}] }`
- Decisión: el DSL inicial debe seguir siendo genérico y pequeño; la semántica específica de cada tipo de objeto vendrá dada por el catálogo de propiedades permitidas en el prompt y por la validación local antes de traducir a operaciones reales y a UndoCue.