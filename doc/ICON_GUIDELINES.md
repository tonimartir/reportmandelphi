# Directrices y Reglas para Iconos en Report Manager (LCL / Lazarus)

Este documento define la arquitectura y las reglas obligatorias para que los iconos de las barras de herramientas, árboles y paneles del diseñador visual LCL nunca se vean borrosos.

---

## 1. Causas del Problema (Por qué se veían borrosos)

1. **Desajuste de dimensiones nativas vs ImageList (19x19 vs 20x20)**:
   - Los 33 iconos originales de Report Manager en Delphi son PNGs de **19x19 píxeles**.
   - Si `AImageList.Width` y `Height` se fijaban en 20x20, la rutina interna de LCL (`TCustomImageList.ScaleImage`) detectaba que `SourceRect <> TargetRect` y ejecutaba `TFPImageCanvas.StretchDraw` de 19 a 20 píxeles.
   - El reescalado fraccional de 1 píxel (19 -> 20) destruye los bordes y crea una interpolación bilineal borrosa en todos los iconos.

2. **Herencia de `DesignTimePPI = 120` desde Delphi DFM**:
   - En monitores con escala al 100% (96 DPI), un formulario con `DesignTimePPI = 120` es auto-reescalado por la LCL al iniciar por un factor de `96 / 120 = 0.8`.
   - Esto reducía los ImageLists de 20x20 a 16x16 píxeles, provocando una segunda pasada de reescalado destructivo.

3. **Inclusión de iconos de mayor resolución (32x32) sin resampleador con canal Alfa**:
   - Iconos añadidos recientemente (`redo32.png`, `undo32.png`, `chatia32.png`) tienen resoluciones de 32x32 o 25x25 píxeles.
   - Al insertarlos directamente en un ImageList más pequeño, LCL saltaba píxeles mediante un muestreo nearest-neighbor básico, rompiendo curvas y dejando líneas dentadas y halos oscuros.

---

## 2. Las 6 Reglas de Oro (Obligatorias)

### Regla 1: Dimensión Base Canónica (19x19 px a 96 DPI)
- La resolución base para todos los iconos de la barra de herramientas a escala 100% (96 DPI) es **19x19 píxeles**.
- Todos los `TImageList` vinculados a toolbars o árboles de componentes deben configurarse con:
  ```pascal
  AImageList.Width := 19;
  AImageList.Height := 19;
  ```

### Regla 2: Formulario siempre en `DesignTimePPI = 96`
- Todos los formularios `.lfm` en Lazarus/LCL deben tener:
  ```lfm
  DesignTimePPI = 96
  ```
- **Nunca** utilizar `DesignTimePPI = 120` (artefacto habitual de la conversión directa desde formularios de Delphi en monitores de 125%).

### Regla 3: Mapeo 1:1 Pixel-Perfect (Sin Interpolación)
- Cuando el tamaño del icono origen coincide con el del `ImageList` (19x19), la LCL ejecuta:
  ```pascal
  if (SourceRect.Right - SourceRect.Left = TargetWidth) and
     (SourceRect.Bottom - SourceRect.Top = TargetHeight) then
    ScFI := FI;
  ```
  Esto copia los píxeles directos 1:1 sin activar ningún filtro de interpolación, garantizando nitidez absoluta.

### Regla 4: Downsampling con Alfa Premultiplicado para Iconos Grandes
- Si un icono nuevo proviene de una fuente de alta resolución (p.ej. 32x32, 48x48, 64x64):
  - **Nunca** usar `StretchDraw` básico.
  - Usar la función de ingesta `ResamplePngToTarget` de `rpmdimageslcl.pas`.
  - Esta función aplica un filtro de caja/área promedio con **Alfa Premultiplicado** (`R*A, G*A, B*A, A`) y des-premultiplicación final:
    - Evita el efecto de "halo oscuro" en los bordes transparentes.
    - Suaviza las curvas de forma anti-aliased perfecta manteniendo la nitidez de trazo.

### Regla 5: Centrado con Margen Transparente para Iconos Pequeños
- Si se suministra un icono más pequeño que el lienzo de destino (p.ej. 16x16 dentro de 19x19):
  - **Nunca estirar** de 16 a 19 (el estiramiento fraccional emborrona el pixel art).
  - Centrarlo a escala 1:1 con `(Target - Source) div 2` rellenando el fondo con transparencia completa.

### Regla 6: Formato PNG RGBA de 32 bits (Canal Alfa Real)
- Todos los iconos deben ser archivos PNG de 32 bits con canal alfa de 8 bits (256 niveles de opacidad).
- No usar paletas indexadas de 1 bit de transparencia ni máscaras de color fijo (magenta/fucsia).

---

## 3. Pipeline de Carga en `rpmdimageslcl.pas`

Para añadir iconos nuevos a cualquier `TImageList`, utilizar siempre el procedimiento centralizado:

```pascal
AddPngToImageList(AImageList, APng);
```

Este procedimiento aplica automáticamente:
1. Si `APng` mide 19x19 y el `ImageList` mide 19x19: inserción 1:1 directa.
2. Si `APng` es mayor: downsampling de alta calidad con alfa premultiplicado.
3. Si `APng` es menor: centrado 1:1 con relleno transparente.
4. Si el sistema opera a 200% High-DPI (38x38): escalado exacto sin distorsión.

---

## 4. Checklist para Nuevos Iconos

1. Diseñar el icono preferentemente a **19x19 píxeles** (o en múltiplos enteros como **38x38 píxeles** para High-DPI).
2. Exportar como PNG RGBA de 32 bits con fondo transparente.
3. Convertir a stream hexadecimal o cargar desde recurso PNG.
4. Insertar a través de `AddPngToImageList`.
5. Ejecutar la auto-prueba de verificación:
   ```cmd
   tests\fpc\LclDesignerTest\LclDesignerTest.exe --selftest
   ```
