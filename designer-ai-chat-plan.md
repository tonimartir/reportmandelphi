## Plan: Reportman.Reporting.Design First

El primer paso de esta arquitectura será crear `Reportman.Reporting.Design` dentro del repositorio C# de Reportman. Esta biblioteca no depende de IA. Su responsabilidad será única y explícita: recibir un `Report`, validar y aplicar operaciones sobre él, y actualizar `UndoCue` en consecuencia. Toda la lógica de modificación real del informe debe concentrarse aquí. La IA y los distintos diseñadores serán consumidores de esta capacidad, no su lugar de definición.

El patrón objetivo para los hosts será simple: Delphi, el diseñador C# y el diseñador Angular enviarán el informe completo serializado junto con la instrucción del chat, y recibirán el informe completo ya modificado. La API usará `Reportman.Reporting.Design` como motor autoritativo de edición.

**Steps**
1. Crear `Reportman.Reporting.Design` en la solución C# de Reportman como nueva biblioteca de edición determinista. Debe depender de `Reportman.Reporting` y no de ningún proyecto IA. Este paso bloquea el resto.
2. Definir dentro de `Reportman.Reporting.Design` el modelo interno de operación de edición sobre `Report`. Mínimo recomendado: `ReportEditOperation`, `ReportEditProperty`, `ReportEditResult`, `ReportEditIssue`. Estas clases son internas al dominio de diseño y no tienen que vivir en `Reportman.AI.Query`. *Depende de 1*.
3. Implementar el validador semántico de operaciones contra un `Report` real. Debe comprobar existencia de nombres internos, padres válidos, compatibilidad entre tipo de objeto y propiedad, reglas estructurales de secciones/subreports y referencias a datasets/campos. *Depende de 2*.
4. Implementar el aplicador de operaciones sobre `Report`. Debe soportar al menos altas, bajas y modificaciones simples, y registrar `UndoCue` de forma coherente con los cambios aplicados. *Depende de 2 y 3*.
5. Definir el caso `report new` como operación de reinicialización del documento dentro del flujo de diseño. La biblioteca debe poder partir de un informe vacío o recién creado y seguir aplicando cambios en el mismo pipeline. *Depende de 4*.
6. Implementar un constructor de contexto del informe a partir de `Report`, suficiente para alimentar después a la IA: estructura, selección lógica, datasets, params, aliases y propiedades relevantes. Esta parte sigue siendo no-IA; solo describe el informe. *Depende de 1 y 4*.
7. Integrar `Reportman.Reporting.Design` en la API. La API debe deserializar el informe recibido, llamar al modelo IA para decidir cambios y delegar siempre en `Reportman.Reporting.Design` la validación y aplicación real. *Depende de 3, 4 y 6*.
8. Definir el contrato HTTP principal como `report in / report out`: el host envía el informe serializado completo y la petición del chat, y recibe el informe completo ya modificado, más explicación, warnings y opcionalmente un resumen de cambios. *Depende de 7*.
9. Adaptar Delphi al patrón nuevo usando el informe completo como frontera. Delphi no tendrá que aplicar operaciones IA localmente; enviará el informe y recargará el resultado. *Depende de 8*.
10. Adaptar el diseñador Angular al mismo patrón. Como ya utiliza el motor C# para ejecución en backend, podrá usar también esta misma capacidad de edición asistida sin reimplementar la semántica del informe en TypeScript. *Depende de 8*.
11. Integrar después el diseñador C# con `Reportman.Reporting.Design`, primero para edición no-IA y luego para chat IA, de modo que Delphi, WinForms y Angular converjan sobre la misma semántica de cambios. *Depende de 4 y 8*.
12. Limitar el primer alcance funcional a operaciones seguras y frecuentes: crear estructura básica, secciones, labels, expressions y cambios simples de propiedades. Dejar fuera charts complejos, maquetación avanzada y escenarios muy anidados hasta estabilizar el flujo. *Depende de 4*.

**Relevant files and projects**
- `c:\desarrollo\danzai\comunnt\reportman\Reportman.Reporting\BaseReport.cs` — base del modelo del informe y punto natural de integración con la edición.
- `c:\desarrollo\danzai\comunnt\reportman\Reportman.Reporting\Report.cs` — objeto principal sobre el que actuará `Reportman.Reporting.Design`.
- `c:\desarrollo\danzai\comunnt\reportman\Reportman.Reporting\UndoCue.cs` — estado de undo/redo que debe actualizar la nueva biblioteca.
- `c:\desarrollo\danzai\comunnt\reportman\Reportman.Designer\FrameMainDesigner.cs` — host WinForms que más adelante consumirá la nueva biblioteca.
- `c:\desarrollo\danzai\comunnt\reportman\Reportman.Designer\DesignerInterface.cs` — referencia de semántica de edición actualmente mezclada con UI.
- `c:\desarrollo\danzai\comunnt\reportman\Reportman.Designer\UndoCuePanel.cs` — referencia visual del undo actual en C#.
- `C:\desarrollo\ReportmanAI\Reportman.AI.Api` — API que deberá depender de `Reportman.Reporting.Design` para materializar cambios.
- `c:\desarrollo\prog\toni\reportman\rpdatahttp.pas` — transporte Delphi para consumir la nueva llamada de modificación de informe.
- `c:\desarrollo\prog\toni\reportman\designer-ai-chat-plan.md` — copia visible de este plan.

**Verification**
1. Crear un `Report` en C# y comprobar que `Reportman.Reporting.Design` puede aplicarle operaciones sin depender de IA ni de UI.
2. Verificar que cada cambio aplicado actualiza `UndoCue` correctamente y que undo/redo sigue funcionando después de la modificación.
3. Confirmar que la validación detecta operaciones inválidas antes de tocar el informe.
4. Confirmar que la API puede recibir un informe serializado, deserializarlo, modificarlo mediante `Reportman.Reporting.Design` y devolverlo sin pérdida de información.
5. Probar que Delphi puede reemplazar el informe actual por el informe devuelto sin corromper estructura ni estado persistente.
6. Repetir el mismo flujo desde Angular con el informe completo como frontera.

**Decisions**
- `Reportman.Reporting.Design` será el primer paso y el núcleo autoritativo de edición del informe.
- `Reportman.Reporting.Design` no depende de IA; solo conoce `Report`, operaciones de edición, validación y `UndoCue`.
- La API sí dependerá de `Reportman.Reporting.Design`, porque la edición real se resolverá en C#.
- Los hosts Delphi, C# y Angular usarán el mismo patrón: enviar informe completo, recibir informe completo.
- `Reportman.AI.Query` no necesita convertirse en la frontera principal de edición del informe para este caso.
- La edición asistida por IA pasa a ser una capacidad del sistema de diseño, no una lógica especial embebida en cada host.

**Further Considerations**
1. Mantener separadas dentro de `Reportman.Reporting.Design` la lógica de contexto, la validación y la aplicación de cambios, aunque vivan en el mismo proyecto.
2. Aunque el contrato principal sea `report in / report out`, conviene devolver también warnings y un resumen de cambios para diagnóstico y UI.
3. La estabilidad real de esta arquitectura dependerá de la serialización cruzada Delphi/C# del informe y de `UndoCue`.

**Initial Scope of Reportman.Reporting.Design**
- Recibir un `Report` cargado.
- Validar operaciones contra el modelo real.
- Aplicar operaciones sobre el informe.
- Actualizar `UndoCue` según los cambios realizados.
- Construir contexto del informe para consumo por la IA.
- No depender de proveedores IA, prompts, streaming ni transporte HTTP.