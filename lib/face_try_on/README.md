# Probador virtual de lentes (RA facial)

Primer filtro de realidad aumentada de Mirage: el usuario se prueba **lentes** en la
cara con la cámara frontal, como un filtro de TikTok o Instagram. Todo se procesa en el
teléfono; las imágenes de la cámara no salen del dispositivo. Solo Android en esta versión.
No incluye ropa ni detección de cuerpo completo.

Entradas: tarjeta **Try on glasses** en Home y botón **Try on (AR)** en el detalle de
un accesorio de lentes (`GLASSES`, `EYEGLASSES`, `SUNGLASSES`). Si ese accesorio todavía
no tiene modelo AR_READY, el aviso ofrece **Create 3D model**: abre el visor 3D, que lo
genera, y al volver se recarga el catálogo.

## Arquitectura

```text
lib/face_try_on/
  domain/glasses.dart                      GlassesFit (ajuste facial) y GlassesOption
  application/ports.dart                   Puertos: FaceTryOnEngine, FaceTryOnSession, GlassesCatalog
  application/glasses_try_on_controller.dart  Permiso, catálogo, modelo activo, tracking, foto
  infrastructure/android_face_try_on_engine.dart  Canales hacia Kotlin + PlatformView
  infrastructure/closet_glasses_catalog.dart      Lentes AR_READY del armario + modelos de prueba
  presentation/glasses_try_on_screen.dart         Pantalla: cámara, carrusel, captura

android/app/src/main/kotlin/com/example/miragemobile/facetryon/
  FaceTryOnPlugin.kt   Canal mirage/face_try_on: permiso de cámara, ajustes, guardar en galería
  FaceTryOnView.kt     PlatformView: vista previa + render + overlay de depuración + captura
  CameraSource.kt      CameraX frontal; vista previa y análisis comparten un ViewPort
  FaceTracker.kt       MediaPipe Face Landmarker (LIVE_STREAM, GPU con fallback a CPU)
  PoseSmoother.kt      Filtro One Euro sobre traslación, escala y rotación (cuaternión)
  GlassesRenderer.kt   Filament + gltfio sobre un TextureView transparente
```

Flujo por frame: CameraX → bitmap recortado a lo que muestra la vista previa →
MediaPipe (matriz de transformación facial, en cm) → suavizado → Filament coloca el GLB:

```
modelo = poseFacial · T(landmark 6 + offset) · Rx(inclinación) · S(100 · escala)
```

La cámara de Filament usa el FOV vertical de 63° de MediaPipe, así que la matriz se
usa sin conversiones. MediaPipe recibe la imagen sin espejar; la vista previa (CameraX)
y la capa 3D (`scaleX = -1`) se espejan igual, como un selfie.

## Contrato del modelo GLB

Lo produce virtual-try-on-service (`postprocess.py`): glTF binario, metros, Y arriba,
frente hacia +Z, 14 cm de ancho y origen en el centro del puente **a la altura del
centro de los cristales** (plano frontal). La app lleva ese origen al **landmark 6** de
MediaPipe (puente nasal, donde apoyan los lentes). El landmark 168 está entre las cejas:
anclar ahí dejaba los cristales ~8 mm por encima de los ojos.

El probador usa la **variante sin patillas** (`GET /garments/{id}/model?variant=ar`): en
la cara quedarían detrás de la cabeza y se verían flotando. El visor 3D usa el modelo
completo. Las dos variantes tienen el mismo origen y tamaño. Los lentes generados antes
de la variante reciben el completo (regenerarlos la crea).

`GlassesFit` es el ajuste fino por modelo. Por defecto (calculado con el modelo canónico
de MediaPipe: landmark 6 en y = 2.47 cm, centro de los ojos en y = 2.62 cm):

```json
{"anchor": "nose_bridge", "offset_m": [0, 0.0015, 0.002], "scale": 1.0, "pitch_deg": 0}
```

+1.5 mm deja los cristales a la altura de los ojos y +2 mm, el frente ~12 mm delante de
la córnea. La escala viene de la pose de MediaPipe (que se adapta a la cara): 14 cm es
~90 % de la distancia entre sienes del modelo canónico.

`ClosetGlassesCatalog` lee el campo `ar_fit` de `GET /garments/models?ids=…`: el
ajuste calibrado del modelo o, si no tiene, el por defecto de la categoría
(`AR_FIT_GLASSES` en el servicio). Si el servicio no lo envía, se usan los valores
por defecto de `GlassesFit`, que son los mismos.

## Modelos de prueba

`assets/try_on/*.glb` se generan con `tool/make_sample_glasses.py` y siguen el mismo
contrato. Se muestran con la etiqueta DEMO en builds debug o con
`--dart-define=TRY_ON_SAMPLES=true`. Si el servicio 3D no responde, el probador sigue
funcionando con ellos.

## Calibración (debug)

El botón de ajustes de la pantalla muestra los FPS, los landmarks 6 (ancla), 33/263
(esquinas de los ojos) y 159/386 (párpados superiores) sobre la
cámara y controles para subir, adelantar, escalar e inclinar los lentes. Con un
accesorio del armario, **Save fit for this model** envía
`PUT /garments/{id}/model/ar-fit` y desde entonces el servicio devuelve ese ajuste
(`source: calibrated`). Los modelos DEMO no se guardan. Regenerar el modelo descarta
su calibración.

## Dependencias Android

CameraX 1.6.2, MediaPipe tasks-vision 0.10.35 (`assets/face_landmarker.task`, sin
comprimir) y Filament/gltfio 1.75.1 (la 1.76+ exige compileSdk 37, que AGP 8.11 no
admite). Permisos: `CAMERA` y `WRITE_EXTERNAL_STORAGE` solo hasta Android 9.

## Verificar

```powershell
flutter analyze
flutter test test/face_try_on_test.dart
flutter build apk --debug --dart-define-from-file=config/local.json
```

La alineación de los lentes con la cara solo se puede validar en un teléfono físico:
la cámara del emulador muestra una escena virtual sin rostro.
