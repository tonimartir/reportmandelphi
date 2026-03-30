## Plan: ReportMan AI Multiplataforma

Replantear la integración de IA para que la lógica principal no viva dentro de ningún diseñador concreto. El núcleo debe residir en `C:\desarrollo\ReportmanAI\Reportman.AI.Api`, los contratos compartidos en `C:\desarrollo\ReportmanAI\Reportman.AI.Query`, y Delphi/C#/web deben actuar como adaptadores finos que serializan contexto, envían una única petición principal de IA y aplican localmente las operaciones devueltas con su propio sistema nativo de undo/historial.

**Steps**
1. Definir la frontera arquitectónica principal: la IA no opera directamente sobre forms, frames ni controles VCL/WPF/web. Opera sobre contratos compartidos de contexto y operaciones de edición de informe. Esta decisión bloquea el resto.
2. Crear en `C:\desarrollo\ReportmanAI\Reportman.AI.Query` los contratos comunes del sistema. Mínimo recomendado: `ReportDesignContext`, `DesignSelectionContext`, `AIDesignRequest`, `AIDesignResponse`, `DesignOperation`, `DesignOperationProperty`, `DesignValidationIssue`. *Depende de 1*.
3. Definir la interfaz `IAIReportEditor` en `C:\desarrollo\ReportmanAI\Reportman.AI.Query` como superficie local y determinista para aplicar operaciones sobre un informe ya cargado. Su responsabilidad no debe ser llamar a la IA, sino resolver nombres, validar operaciones y ejecutarlas por lotes. *Depende de 2*.
4. Separar explícitamente NL-to-SQL del flujo de edición de informes. Crear o mantener un contrato aparte como `INLToSqlService` en el backend compartido, sin mezclarlo con `IAIReportEditor`. Si `nltosqlcontroller` se reutiliza, debe hacerlo como servicio especializado, no como centro de toda la arquitectura. *Depende de 2*.
5. Implementar en `C:\desarrollo\ReportmanAI\Reportman.AI.Api` un servicio orquestador único para diseño asistido por IA. Debe recibir contexto serializado del informe, construir el prompt, ejecutar una sola llamada principal al modelo y devolver una respuesta estructurada con operaciones, avisos y texto explicativo. *Depende de 2 y 4*.
6. Diseñar el DSL de operaciones como contrato multiplataforma y no como API Delphi-específica. El núcleo debe usar operaciones `Add`, `Remove` y `Modify`, con destino explícito, nombres internos estables, clase lógica del objeto y array de propiedades `{name, value}`. *Depende de 2 y 5*.
7. Definir el pipeline host-agnostic completo: el host extrae contexto local del informe, llama a la API compartida, recibe operaciones, las valida contra su modelo local mediante `IAIReportEditor`, las aplica en lote y registra undo/historial con su mecanismo nativo. *Depende de 3, 5 y 6*.
8. Implementar primero un adaptador Delphi mínimo que convierta el estado actual del diseñador en `ReportDesignContext` y traduzca `DesignOperation` a operaciones locales undoables. Debe reutilizar `UndoCue`, pero sin mover la inteligencia del sistema al diseñador. *Depende de 7*.
9. Diseñar desde el principio adaptadores equivalentes para futuro diseñador C# y diseñador web TypeScript. No hace falta implementarlos todavía, pero sí fijar las expectativas del contrato para que el backend no dependa de detalles Delphi como nombres de clases VCL o units. *Depende de 2, 6 y 7*.
10. Modelar el caso `report new` como una operación previa local del host, no como un modo aparte de la IA. Si el usuario pide un informe nuevo, el host crea o reinicia el documento y luego ejecuta el mismo flujo normal de modificación con contexto limpio. *Depende de 7*.
11. Limitar el primer alcance funcional a operaciones seguras y comunes: estructura base, secciones, labels, expressions, propiedades simples y enlaces de dataset. Dejar fuera en la primera fase los casos complejos como charts avanzados, diseño gráfico fino o subreports muy anidados. *Depende de 6 y 7*.
12. Añadir validación robusta en el backend y en cada host: no aplicar operaciones con referencias inexistentes, no inventar datasets/campos, rechazar propiedades no válidas para cada `className`, y devolver errores de validación claros antes de tocar el documento. *Depende de 5, 6 y 7*.
13. Definir soporte de explicación y previsualización: la respuesta puede incluir texto natural para el usuario, pero las modificaciones reales solo deben venir por la parte estructurada del contrato. *Depende de 5 y 6*.
14. Preparar verificación cruzada entre hosts con un conjunto compartido de casos de prueba sobre contratos JSON. La misma petición y el mismo contexto deben producir operaciones equivalentes para Delphi, C# y web, salvo diferencias deliberadas de capacidades. *Depende de 6, 7 y 9*.

**Relevant files**
- `C:\desarrollo\ReportmanAI\Reportman.AI.Api` — backend principal donde debe vivir la orquestación común de IA para edición de informes.
- `C:\desarrollo\ReportmanAI\Reportman.AI.Query` — contratos compartidos, DTOs, interfaz `IAIReportEditor` y separación con `INLToSqlService`.
- `c:\desarrollo\prog\toni\reportman\rpdatahttp.pas` — referencia para el transporte actual Delphi hacia servicios externos.
- `c:\desarrollo\prog\toni\reportman\rpauthmanager.pas` — autenticación y estado de usuario reutilizable desde el host Delphi.
- `c:\desarrollo\prog\toni\reportman\rpmdundocue.pas` — mecanismo actual de undo local, a reutilizar por el adaptador Delphi al aplicar operaciones.
- `c:\desarrollo\prog\toni\reportman\rpmdcueviewvcl.pas` — visualización del historial/undo en Delphi, que debe reflejar cambios aplicados localmente.
- `c:\desarrollo\prog\toni\reportman\rpmdfdesignvcl.pas` — fuente principal para extraer selección, estructura visible y contexto del diseñador Delphi.
- `c:\desarrollo\prog\toni\reportman\rpmdobjinspvcl.pas` — referencia para propiedades, selección y edición local del informe.
- `c:\desarrollo\prog\toni\reportman\rpmdfstrucvcl.pas` — referencia útil para obtener jerarquía de subreports, sections y componentes desde Delphi.
- `c:\desarrollo\prog\toni\reportman\designer-ai-chat-plan.md` — copia visible en la raíz que debe reflejar este enfoque multiplataforma.

**Verification**
1. Validar que los contratos de `Reportman.AI.Query` no contienen tipos ni dependencias de VCL, WPF ni TypeScript.
2. Verificar que `AIDesignRequest` permite representar el mismo informe desde Delphi y desde futuros hosts sin pérdida de contexto esencial.
3. Confirmar que una respuesta `AIDesignResponse` con operaciones `Add` / `Remove` / `Modify` puede aplicarse localmente en Delphi sin llamadas extra de IA.
4. Probar el flujo `report new` como prepaso local seguido del mismo pipeline normal de modificación.
5. Comprobar que NL-to-SQL puede evolucionar aparte sin tocar el contrato base de edición del informe.
6. Validar que operaciones inválidas fallan antes de modificar el documento y generan mensajes de validación útiles.
7. Preparar al menos varios ejemplos JSON canónicos y verificar que serían consumibles por Delphi, C# y web.

**Decisions**
- La arquitectura principal deja de estar centrada en el diseñador VCL. Delphi pasa a ser un consumidor del sistema, no su lugar de definición.
- `C:\desarrollo\ReportmanAI\Reportman.AI.Api` será el punto central de orquestación de IA para edición de informes.
- `C:\desarrollo\ReportmanAI\Reportman.AI.Query` será la frontera de contratos compartidos entre backend y hosts.
- `IAIReportEditor` debe ser local, determinista y pequeña: validar, resolver y aplicar operaciones; no decidir prompts ni hacer routing de IA.
- No hace falta un `IAReportAssistant` adicional como otra capa de IA. Es más simple y portable usar una sola llamada principal al modelo y coordinación local determinista.
- `INLToSqlService` debe mantenerse separado del flujo de edición del informe.
- El DSL inicial debe seguir siendo genérico: `Add`, `Remove`, `Modify`, `className`, `name`, destino y `properties` como array `{name, value}`.
- Los hosts deben conservar su propio undo/historial. La IA propone operaciones; cada host las aplica con sus mecanismos nativos.
- El primer host a implementar puede ser Delphi, pero el contrato se diseña para sobrevivir al paso a C# y web sin rehacer el backend.

**Further Considerations**
1. Decidir pronto si `className` será un nombre lógico multiplataforma (`Label`, `Expression`, `Section`) o una mezcla con nombres internos de ReportMan. Recomendación: usar nombres lógicos estables y mapearlos localmente en cada host.
2. Decidir si `IAIReportEditor` debe vivir solo como interfaz .NET o si además conviene publicar un esquema JSON independiente como fuente de verdad. Recomendación: el esquema JSON debe ser la frontera real multiplataforma; la interfaz puede ser una ayuda interna en .NET.
3. Definir pronto el catálogo inicial de propiedades permitidas por tipo de objeto para evitar respuestas ambiguas del modelo.

**Operation JSON**
- Estructura base recomendada por operación:
  - `operation`: `Add` | `Remove` | `Modify`
  - `name`: nombre interno único del objeto cuando ya existe
  - `className`: tipo lógico multiplataforma, por ejemplo `Report`, `SubReport`, `Section`, `Label`, `Expression`
  - `parentName`: contenedor lógico cuando aplique
  - `properties`: array de objetos `{ "name": string, "value": any }`
- Reglas globales:
  - posiciones y tamaños en twips
  - no inventar nombres de datasets, campos ni sections
  - usar solo propiedades válidas para el `className`
  - no aplicar cambios destructivos si la validación local falla
- Ejemplo conceptual:
  - `{ "operation": "Modify", "name": "EXP_CLIENT_TOTAL", "className": "Expression", "properties": [{"name":"Left","value":1440},{"name":"Top","value":720},{"name":"Width","value":2880},{"name":"Expression","value":"Customers.Total"}] }`
- El contrato debe seguir siendo pequeño; la complejidad específica de cada host debe resolverse en el adaptador local, no en la respuesta de IA.