# Pruebas del probador virtual de lentes (RA) y del modelado 3D

Guía para levantar todo en local (Windows) y probar el flujo completo: foto de unos
lentes → modelo 3D (.glb) → prueba en la cara con la cámara → calibración.

Detalle técnico del probador: [lib/face_try_on/README.md](lib/face_try_on/README.md).
Detalle del servicio 3D: `virtual-try-on-service/README.md`.

## Qué corre y dónde

| Pieza | Puerto | Repositorio | Necesario para |
|---|---|---|---|
| Supabase local de IAM | 54321 | iam-service | Iniciar sesión |
| Supabase local del armario | 54421 | digital-closet-service | Prendas y fotos |
| IAM (Drogon) | **8090** (ver nota) | iam-service | Iniciar sesión |
| Digital Closet | 8081 | digital-closet-service | Prendas, fotos y dueño de cada prenda |
| virtual-try-on-service (Docker + GPU) | 8000 | virtual-try-on-service | Generar modelos 3D y guardar calibraciones |
| App Flutter | — | mirage-mobile (rama `feat/3D`) | Todo |

> **Nota sobre el puerto de IAM.** El puerto 8080 está ocupado en el equipo de
> desarrollo por otro proyecto (`evolution_api`). IAM se levanta en **8090** y la app se
> ejecuta con `--dart-define=API_BASE_URL=http://10.0.2.2:8090`. Si en tu equipo 8080
> está libre, puedes usar 8080 y omitir el `--dart-define`. Mientras IAM no esté en 8080
> no funciona guardar el avatar (su worker llama a `127.0.0.1:8080`); el probador de
> lentes no se ve afectado.

Para probar solo el filtro con los **3 lentes DEMO** basta con Supabase de IAM + IAM.
Para el modelado 3D hace falta todo.

## 1. Requisitos

- Docker Desktop con WSL2 y soporte de GPU NVIDIA.
- GPU NVIDIA: SPAR3D en modo de bajo consumo usa unos 7 GB de VRAM. Con 6 GB puede
  fallar al cargar; ver [Problemas frecuentes](#problemas-frecuentes).
- Token de Hugging Face con acceso aceptado a `stabilityai/stable-point-aware-3d`
  (en `virtual-try-on-service/.env`, `HF_TOKEN`).
- IAM y Digital Closet compilados en `out\build\x64-debug-vcpkg\` (ver sus README).
- Flutter del proyecto: `mirage\.tools\flutter` (3.47). El `flutter` del PATH puede ser
  más antiguo y no cumplir la versión de Dart de `pubspec.yaml`.
- Android SDK con un emulador (AVD) o un teléfono Android con depuración USB.

## 2. Levantar los servicios (PowerShell, una ventana por servicio)

Comprobar Supabase (los contenedores suelen quedar corriendo):

```powershell
docker ps --format "{{.Names}}" | Select-String "supabase_kong"
# Deben aparecer supabase_kong_mirage-iam-local y supabase_kong_mirage-closet-local.
# Si falta el de IAM:  cd iam-service; supabase start
```

IAM:

```powershell
cd C:\Users\mikas\OneDrive\Documentos\ChatGPT\mirage\iam-service
.\run-auth.ps1 -Port 8090
```

Digital Closet:

```powershell
cd C:\Users\mikas\OneDrive\Documentos\ChatGPT\mirage\digital-closet-service
.\run.ps1
```

virtual-try-on-service (la primera vez construye la imagen: 15-30 minutos):

```powershell
cd C:\Users\mikas\OneDrive\Documentos\ChatGPT\mirage\virtual-try-on-service
docker compose up --build
# Listo cuando el log muestra "Modelo cargado".
```

Verificar:

```powershell
curl.exe -s -o NUL -w "IAM %{http_code}\n" -X POST http://localhost:8090/api/v1/auth/login -H "Content-Type: application/json" -d "{}"   # 400 = vivo
curl.exe -s -o NUL -w "Closet %{http_code}\n" http://localhost:8081/health                                                              # 200
curl.exe -s http://localhost:8000/health                                                                                                 # {"status":"ok"}
```

## 3. Emulador con la webcam del PC

El AVD debe usar la webcam como cámara frontal (la cámara simulada no tiene cara).

1. Ver las webcams disponibles:
   ```powershell
   & "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -webcam-list
   ```
2. En `%USERPROFILE%\.android\avd\<AVD>.avd\config.ini` poner
   `hw.camera.front=webcam0` (o en Android Studio: Device Manager → Edit → Show Advanced
   Settings → Camera → Front: Webcam0).
3. Arrancar en frío la primera vez después del cambio:
   ```powershell
   & "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd Pixel_7 -no-snapshot-load
   ```
   En cmd: `"%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Pixel_7 -no-snapshot-load`

Cierra Teams, Zoom o el navegador si están usando la webcam: Windows la entrega a una
sola aplicación.

## 4. Ejecutar la app

```powershell
cd C:\Users\mikas\OneDrive\Documentos\ChatGPT\mirage\mirage-mobile
git checkout feat/3D
..\.tools\flutter\bin\flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8090
```

En un teléfono físico, `10.0.2.2` no sirve: usa la IP del PC en la red local
(`--dart-define=API_BASE_URL=http://<IP-del-PC>:8090`) y abre los puertos 8090, 8081 y
8000 en el firewall de Windows.

## 5. Flujo de prueba del modelado 3D

1. Inicia sesión.
2. **Closet → +**: crea un accesorio con categoría `ACCESSORY` y subcategoría
   `GLASSES`, `EYEGLASSES` o `SUNGLASSES`, con una foto de los lentes **de frente, a la
   altura de los lentes y con las patillas abiertas**.
3. Abre el accesorio → **View in 3D** → **Create 3D model**. Tarda de segundos a un par
   de minutos según la GPU. Al terminar se ve el modelo y se puede girar.
4. En el mismo detalle → **Try on (AR)**: se abre el probador con esos lentes
   seleccionados (también aparecen en **Home → Try on glasses**).
5. Mira a la cámara: los lentes deben aparecer sobre la cara y seguir la cabeza.
6. Foto: botón redondo → **Save photo** (se guarda en `Pictures/Mirage`).
7. Calibración (solo builds debug): botón de ajustes arriba a la derecha.
   - Los puntos verdes (puente nasal y comisuras de los ojos) deben caer sobre la cara.
   - Ajusta Up / Forward / Scale / Tilt hasta que los lentes asienten bien.
   - **Save fit for this model** guarda el ajuste en el servicio
     (`PUT /garments/{id}/model/ar-fit`); desde entonces todos reciben ese ajuste.
   - Regenerar el modelo descarta su calibración.

Qué anotar en cada prueba: subcategoría, si la foto cumplía las condiciones, tiempo de
generación, si el modelo se ve completo (marco, cristales, puente), si asienta sin
calibrar y, si se calibró, los valores guardados. Los valores que funcionen para la
mayoría de modelos son candidatos para `AR_FIT_GLASSES` en el `.env` del servicio.

## 6. Comprobar el servicio 3D sin la app

Con un token de IAM (`<token>`) y el ID de una prenda (`<id>`):

```powershell
curl.exe -X POST "http://localhost:8000/api/v1/try-on/garments/<id>/model" -H "Authorization: Bearer <token>"
curl.exe "http://localhost:8000/api/v1/try-on/garments/<id>/model/info" -H "Authorization: Bearer <token>"
curl.exe -X PUT "http://localhost:8000/api/v1/try-on/garments/<id>/model/ar-fit" -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d "{\"offset_m\": [0, 0.004, 0.007], \"scale\": 1.0, \"pitch_deg\": 0}"
```

Swagger: http://localhost:8000/docs (botón **Authorize** para el token).

## Problemas frecuentes

| Síntoma | Causa probable | Qué hacer |
|---|---|---|
| El login falla en la app | IAM no está en el puerto que usa la app | Revisa `--dart-define=API_BASE_URL` y que IAM responda |
| "Could not reach the 3D service" | virtual-try-on-service apagado o cargando | Espera "Modelo cargado"; `curl.exe http://localhost:8000/health` |
| `INSUFFICIENT_GPU_MEMORY` o el contenedor se cae al cargar | Menos de 8 GB de VRAM | En `.env`: `RECON_MODEL=sf3d` y `docker compose up --build` (requiere acceso a `stabilityai/stable-fast-3d` en Hugging Face) |
| En el probador la cámara se ve negra | Webcam ocupada o AVD sin `webcam0` | Cierra otras apps de cámara; revisa `hw.camera.front` |
| Los lentes no aparecen pero la cámara sí | No se detecta la cara | Más luz, cara de frente; `adb logcat -s FaceTracker CameraSource Filament` |
| Va lento en el emulador | La GPU del emulador no sirve para MediaPipe y pasa a CPU (~15-20 FPS) | Normal; en un teléfono real va más fluido |
| "This accessory has no AR-ready 3D model yet" | El modelo no está generado o falló | Genera el modelo desde **View in 3D** |
