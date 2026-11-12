# Mirage Mobile

Cliente Flutter de Mirage/ReWear con IAM, Digital Closet, prueba virtual y asistente de recomendaciones. Usa Dio,
arquitectura modular y capas de dominio, aplicación, infraestructura y presentación.
Ver [ARCHITECTURE.md](ARCHITECTURE.md) para alcance y límites.

## Ejecutar localmente

En otra terminal, desde `../iam-service`, inicia el backend:

```powershell
./run-auth.ps1
```

Desde esta carpeta:

```powershell
flutter pub get
Copy-Item config/local.example.json config/local.json  # solo si no existe
./run-local.ps1
```

`config/local.json` ya está preparado en esta PC y está ignorado por Git. Contiene
las URLs públicas de los servicios (IAM 8080, Closet 8081, prueba virtual 8082 y Recommendation 8085). Se lee con
`--dart-define-from-file`; no es un asset ni necesita `flutter_dotenv`.
Las variables compiladas pueden extraerse de una app: nunca pongas secretos,
service_role, contraseñas de BD ni credenciales SMTP allí.

### Android e iOS

Sin override, Android usa `http://10.0.2.2:8080` para acceder a la PC desde el
emulador estándar; iOS simulator/Windows usan `http://127.0.0.1:8080`.
Para un dispositivo físico usa la IP LAN de la PC y el identificador del dispositivo:

```powershell
./run-local.ps1 -Device <device-id> -ApiBaseUrl http://192.168.1.50:8080
```

La PC y el teléfono deben compartir red y el firewall debe permitir la conexión.
HTTP se habilita solo en el manifest Android de debug; las compilaciones release
requieren una URL HTTPS. Android/iOS no se han ejecutado en un dispositivo en esta entrega.

### Web

La UI también puede compilarse como Flutter web, pero el backend actual no tiene
CORS habilitado para el servidor de desarrollo de Flutter. Para probar la API
local usa Windows o un emulador nativo; no se ha abierto CORS globalmente ni se
ha desactivado la seguridad del navegador. La publicación web requerirá un proxy
bajo el mismo origen o una lista explícita de orígenes permitidos.

## Funcionalidad inicial

- Splash y onboarding basados en Figma, con imágenes y fuentes locales.
- Login, registro y reenvío de confirmación de correo.
- Solicitud de recuperación mediante los enlaces web del backend.
- Cuenta autenticada, comprobación de sesión, refresh y logout.
- Validaciones, contraseña visible/oculta, errores de conexión y estados de carga.

Google está conectado en Android; Apple sigue pendiente. La cuenta conecta con el módulo
de avatar y medidas. Tras login o restaurar sesión se abre Home vacío, con la
barra inferior fija del Figma. Solo Home y Profile están habilitados. Closet,
Create y Explore quedan sin funciones y no llaman a otros bounded contexts.
Profile muestra la cuenta, cierre de sesión y **My digital avatar**.

El avatar guardado no se carga ni se vuelve a escanear al entrar en la app.
Solo al abrirlo desde Profile se regenera la vista a partir del JSON guardado.
**Save & continue** guarda y vuelve a Home; si ya está guardado, **Continue to
Home** permite regresar directamente. Un fallo al restaurarlo ofrece reintento,
sin mostrar el formulario de escaneo como si no existiera un avatar.

La sesión se recuerda automáticamente después de iniciar sesión. SharedPreferencesAsync
guarda únicamente la bandera de restauración; flutter_secure_storage conserva
el refresh token. La contraseña, el access token y el perfil no se guardan en
preferencias. Al arrancar se renueva la sesión y se valida `/auth/me` antes de
mostrar la cuenta. Cada rotación actualiza el token persistido; logout o una
sesión rechazada lo eliminan. Un fallo de red conserva el token para reintentar.

Android tiene backup deshabilitado para evitar restaurar credenciales cifradas
sin sus claves del dispositivo. iOS tiene el entitlement de Keychain configurado;
su compilación requiere macOS y no se ha comprobado en este entorno Windows.
Tras añadir estos plugins hay que detener la app y ejecutarla de nuevo; hot
reload no registra plugins nativos nuevos. Inicia sesión una vez para activar
el recuerdo; después puedes cerrar y volver a abrir la app.

Referencias: [SharedPreferences](https://pub.dev/packages/shared_preferences)
y [almacenamiento seguro](https://pub.dev/packages/flutter_secure_storage).

## Google en Android

**Continue with Google** abre el selector nativo con `google_sign_in` y envía
únicamente el ID token a `POST /api/v1/auth/google`. El IAM intercambia ese
token con Supabase; Flutter guarda el refresh token de Mirage en el mismo
almacenamiento seguro del login por correo. No guarda el ID token de Google.
Cerrar el selector no envía peticiones de login ni crea una sesión de Mirage.

El Client ID web público está configurado como `serverClientId` y se comprobó
contra la redirección OAuth de Supabase. Puede cambiarse con
`--dart-define=GOOGLE_WEB_CLIENT_ID=...`. El secreto OAuth permanece en Supabase.
No se necesita `google-services.json` para este flujo con ID explícito.

La credencial Android de Google Cloud debe coincidir con el applicationId
`com.example.miragemobile` y la firma del APK instalado. Debug usa la credencial
que acabas de crear; Release y Google Play requieren registrar sus propias
huellas en el mismo proyecto. Mantener el cliente web en Supabase. No se
cambiaron nonce checks ni otros ajustes del proveedor.

Después de añadir el plugin, detener Flutter y ejecutar de nuevo. El emulador
debe tener Google Play services y una cuenta Google disponible. Por ahora las
pruebas usan las cuentas permitidas en Google Auth Platform. El selector no
está habilitado en iOS, escritorio ni web; necesitan su configuración específica.
Un teléfono real necesita además una URL del IAM accesible desde ese teléfono;
`10.0.2.2` solo comunica el emulador Android con esta PC.

Referencia: [configuración oficial de google_sign_in para Android](https://pub.dev/packages/google_sign_in_android).

```powershell
flutter analyze
flutter test
```
