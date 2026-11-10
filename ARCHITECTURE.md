# Mirage Mobile — IAM

Esta primera entrega limita las pantallas al acceso a la cuenta: splash, tres
introducciones, login, registro, confirmación de correo, solicitud de recuperación
y resumen de cuenta autenticada. No construye Home, Closet, outfits ni el avatar.

```text
lib/
  app/                       Composición y dependencias
  iam/
    domain/                  Account, EmailAddress, AuthSession, AuthRepository
    application/             Comandos de cuenta y consulta de sesión
    infrastructure/          Adaptación de JSON y API con Dio
    presentation/            Navegación y pantallas IAM
  shared/
    config/                  Configuración por entorno
    network/                 Dio, timeouts y fallos de transporte
    theme/                   Colores y tipografía
    widgets/                 Campos, botones, marca, avisos y estructura de página
```

El dominio no importa Flutter, Dio ni JSON. `Account` representa la identidad de
la cuenta; `EmailAddress` valida su valor y la sesión se mantiene en memoria.
La aplicación recibe el puerto `AuthRepository`, no conoce Supabase y no decide
rutas HTTP. `DioAuthRepository` implementa ese puerto contra Drogon. La composición
de dependencias vive en `MirageApp`, sin service locators globales.

`IamController` separa las operaciones de escritura de la consulta de cuenta,
coordina el estado de presentación y bloquea envíos duplicados. No se añaden
buses CQRS, bases locales, modelos ORM ni eventos distribuidos al cliente.

## Red y sesiones

Se implementan login, registro, recuperación, reenvío de confirmación, refresh,
consulta `/me` y logout usando los contratos existentes de `/api/v1/auth`.
Los tokens se envían únicamente en operaciones que los requieren; no hay un
Authorization global que pueda filtrarlos a otros hosts o a endpoints públicos.
No se registran contraseñas, cuerpos de respuestas ni tokens en consola.

Una respuesta de registro sin sesión muestra confirmación, sin inventar un
usuario autenticado. Las sesiones próximas a vencer se refrescan antes de
consultar la cuenta o cerrar sesión. El retorno de la app al primer plano vuelve
a consultar la cuenta. Si logout falla por red, la sesión se conserva para
reintentar; no se afirma que el servidor haya cerrado una sesión que no revocó.

No hay persistencia de tokens: reiniciar la app requiere volver a iniciar sesión.
La persistencia futura debe usar almacenamiento seguro de la plataforma, no un
archivo `.env`, preferencias en texto plano ni almacenamiento web accesible por JS.

## Diseño

Fuente: https://www.figma.com/design/91cHpDWFyA9XmEFbw0Y5vN/Untitled

Se implementan W01–W05 de la sección `01-onboarding-home-closet`. Las imágenes e
iconos son exportaciones locales del Figma; `assets-manifest.json` registra sus
archivos, nodos y tamaños. Las fuentes Lora, Inter y el fallback Noto Sans Symbols 2 se incluyen con sus licencias
OFL en `assets/fonts/`; no se descargan durante la ejecución.

Se adapta el layout a Flutter con controles nativos, scroll y teclado. Las
composiciones decorativas mantienen las proporciones del diseño y escalan como
una unidad. Las barras de estado y el indicador de inicio corresponden al SO;
no se dibuja una hora ni una batería falsas. Se aumenta el área táctil de los
enlaces pequeños y se señalan los proveedores sociales no habilitados.

Registro, recuperación, confirmación y resumen de cuenta extienden los mismos
tokens/componentes; no había pantallas independientes de estos flujos en los
nodos W01–W05 consultados. Google y Apple permanecen deshabilitados. El backend
ya acepta tokens Google, pero el cliente móvil aún necesita configuración OAuth
de plataforma y su integración SDK. Apple no está implementado en el backend.

Los correos actuales abren las páginas de confirmación/recuperación del servidor.
Esta entrega no añade deep links móviles ni cambia las URLs de Supabase.

## Verificar

```powershell
flutter analyze
flutter test
dart run tool/check_local_api.dart
flutter build windows --debug --dart-define-from-file=config/local.json
```

Las pruebas usan dobles del repositorio y del transporte HTTP: no crean cuentas
ni envían correos reales. `design_preview_test.dart` genera capturas en
`output/design/` para revisión de las pantallas implementadas.
