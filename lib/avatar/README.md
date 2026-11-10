# Avatar local

Módulo separado de IAM: `domain` valida la entrada y define el repositorio;
`application` ejecuta el comando y consulta el trabajo; `infrastructure`
envía multipart con Dio; `presentation` selecciona fotos y muestra el GLB con
Babylon local dentro de WebView (Android/iOS).

Desde Profile: **My digital avatar**. Si existe uno guardado se abre desde su
JSON; no se solicita otra foto. Si no existe, elegir cuerpo completo, ingresar
altura/peso, aceptar el procesamiento y pulsar **Create avatar**. Selfie y
lateral son opcionales y permanecen en memoria de esta pantalla. No se usan
para reconstruir cara, textura ni fusionar varias vistas. Solo se sube la foto
corporal. El bearer de la sesión se obtiene del IAM y se usa para vincular y
guardar el resultado; nunca se pasa a la WebView ni se incluye en URLs.

Backend desde `iam-service`:

```powershell
./avatar-worker/run-sam-mobile.ps1
```

Flutter usa `http://10.0.2.2:8093` en el emulador Android y
`http://127.0.0.1:8093` en iOS local. Se puede indicar `AVATAR_BASE_URL` mediante
`--dart-define`, limitado a esos hosts locales. Se necesitan los pesos y el
entorno CUDA descritos en `avatar-worker/SAM_SETUP.md`. Reiniciar Flutter
completamente después de añadir los plugins; hot reload no registra plugins
nativos nuevos.

El servidor solo escucha loopback. No funciona desde un teléfono físico sin
un túnel o gateway que todavía no se ha implementado. La opción se deshabilita
en release: antes de publicar necesita un gateway, autorización también para
las previsualizaciones temporales y límites por usuario. Guardar, ajustar y
reabrir sí comprueban identidad y sesión activa mediante IAM y RLS.

Los trabajos expiran a los diez minutos; el modelo vive en memoria y los
archivos temporales de entrada se eliminan al completar/fallar la inferencia.
Solo **Save & continue** conserva la foto: JPEG sin EXIF/GPS, en el bucket
privado `mirage-avatar-photos`. `avatar_profiles` guarda un JSON de unos 5 KB
con 45 parámetros de forma, 204 parámetros MHR, versión de pesos, altura,
contornos estimados, valores corregidos y preferencia de ajuste. El GLB de
unos 886 KB solo se genera para visualizar y caduca; no se sube a Supabase.
Los archivos temporales que genere el selector nativo pertenecen a la caché
del sistema. La primera carga puede tardar y la
API admite dos trabajos retenidos y una inferencia CUDA a la vez.

SAM estima la identidad; MHR reconstruye en pose neutra y la altura declarada
calibra la escala. Los perímetros se obtienen de secciones cerradas del torso
a fracciones de altura (pecho .72, cintura .60, cadera .52). Son proxies
geométricos sin validación antropométrica, no localizadores anatómicos.
Hombros queda manual. El peso no se transforma arbitrariamente en perímetros.

**Refine Body Profile** abre W19 de Figma: altura, pecho, cintura, caderas,
hombros opcionales y Fitted / Regular / Oversized. Continue aplica ajustes
visuales suaves por secciones; no hace una nueva inferencia ni garantiza
ajuste de ropa. **Save & continue** conserva las correcciones y regresa a Home.
**Continue to Home** regresa directamente si ya estaba guardado. Reabrir el
módulo carga el JSON y regenera el GLB con MHR, sin volver a analizar la foto.
Las fotos antiguas no se borran automáticamente al guardar una nueva.
El fitting room y la generación de imágenes de estilos aún no se implementan.

Migración aplicada: `20261110000127_avatar_body_profile.sql`. RLS exige dueño
y sesión activa en tabla y Storage. El bucket no es público. `/api/avatar/photo`
permite recuperar la foto propia autenticada para futuras funciones de estilos.
El guardado se probó con transporte simulado y las políticas se inspeccionaron
en Supabase; falta verificarlo desde tu sesión real en el móvil.

Verificaciones:

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```
