# Asistente flotante

El círculo rosa aparece en las pantallas autenticadas. Abre un panel adaptable
que conserva el borrador y la conversación al minimizarlo. El historial se guarda
en Recommendation, no en el teléfono; al abrir una nueva sesión se recupera el
chat más reciente. El menú permite abrir los últimos 20 chats o empezar otro.

`lib/recommendation/` contiene el cliente HTTP, el controlador y el panel.
`lib/app/authenticated_shell.dart` mantiene el panel por encima del navegador
autenticado, incluso en detalle de prenda y prueba virtual. Al salir de la cuenta
se elimina ese navegador y se cancela el cliente de chat.

Se reutiliza la sesión de IAM. El cliente envía mensajes con UUID, impide envíos
simultáneos y conserva el mismo texto e identificador al reintentar un envío que
falló. El tiempo de espera es 180 segundos: recuperación y modelo son servicios
remotos. Mensajes: 2000 bytes UTF-8; chat: 20 turnos, según el contrato del backend.

Las propuestas usan `recommendation.outfits` y sus snapshots `garments`. El botón
**Probar en mi clóset** vuelve a consultar Closet con la sesión del usuario y exige
las mismas revisiones, disponibilidad e imágenes. Acepta hasta tres prendas, el
límite del proveedor de visualización. No interpreta URLs ni acciones del texto
del modelo. Si hay un look diferente en preparación, pide confirmar el reemplazo.
Después abre **Ready to Try**, donde el usuario elige su foto, acepta el consentimiento
y pulsa **Generate My Look**. El chat no envía fotos ni genera imágenes automáticamente.

**Referencias consultadas** muestra los ejemplos Polyvore y criterios de estilo
devueltos por Recommendation, con fuente, licencia y atribución. Son evidencia
recuperada, no prendas del usuario ni garantía de compatibilidad estética.

También muestra `web_references` cuando el agente consulta `search_fashion_web`.
La fuente es FashionStylist (abril de 2026), con enlace al archivo y licencia
CC-BY-NC-4.0. Es inspiración de un repositorio autorizado, no búsqueda web general
ni tendencias en tiempo real. La consulta ocurre en Recommendation; Flutter no
contacta GitHub ni recibe sus archivos completos.

## Configuración

`RECOMMENDATION_BASE_URL` es el origen y prefijo de API, por ejemplo
`http://127.0.0.1:8085/api/v1`. Si no se configura, se deriva del host de IAM con
puerto 8085. `CLOSET_BASE_URL` y `TRYON_BASE_URL` funcionan de igual manera.
En release deben configurarse URLs HTTPS de los servicios desplegados.
Neon, NVIDIA y Supabase mantienen sus claves exclusivamente en los backends.

Para iniciar los servicios y el cliente Windows en esta PC:

```powershell
../run-local-stack.ps1 -OpenApp
```

Añadir `-WithAvatar` para levantar también el prototipo SAM local (8093).

Pruebas: `flutter analyze --no-pub` y `flutter test --no-pub`. La prueba real
es opcional: preparar la sesión privada con `../recommendation-service/postman/prepare_session.py`,
definir `MIRAGE_LIVE=1` en el proceso y ejecutar `flutter test test/recommendation_live_test.dart`.
Esa prueba crea una conversación real en la cuenta de pruebas y llama al modelo.
Las pruebas normales utilizan dobles y no consumen cuotas de NVIDIA.
