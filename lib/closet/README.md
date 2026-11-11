# Closet

Módulo del armario digital: ver, agregar y editar prendas, armar un outfit de hasta 3 piezas
y generar una vista previa con IA sobre una foto del usuario. Misma forma que `avatar/`:
`domain` (prendas y puertos), `application` (controladores), `infrastructure` (Dio),
`presentation` (pantallas del diseño de Figma).

## Pantallas

| Pantalla | Archivo |
| --- | --- |
| My Closet (tab Closet) | `presentation/closet_screen.dart` |
| Tops / Bottoms / Shoes / Accessories | `presentation/category_screen.dart` |
| Detalle de prenda, Add to Outfit | `presentation/item_detail_screen.dart` |
| Add New Item / Edit Item | `presentation/add_item_screen.dart` |
| Ready to Try, Creating your look, Your AI Look, Compare Look | `presentation/try_on_screens.dart` |

## Servicios que necesita (en la PC)

- IAM `:8080` (login), Digital Closet `:8081` (prendas) y su worker de visualización `:8082`
  (ver el README de `digital-closet-service`). El token es el mismo de IAM.
- Emulador Android: `10.0.2.2` en lugar de `127.0.0.1`. Las direcciones salen de
  `API_BASE_URL` cambiando el puerto; se pueden fijar con
  `--dart-define=CLOSET_BASE_URL=http://10.0.2.2:8081/api/v1` y
  `--dart-define=TRYON_BASE_URL=http://10.0.2.2:8082/api/v1`.
- La foto de la persona sale de la que el usuario elige en "Ready to Try" (queda en memoria,
  `avatar/application/person_photo.dart`) o, si no hay, de su avatar guardado en IAM.

## Qué hay y qué no

Hecho: lista por grupo con conteos, búsqueda, filtro por color y orden, alta con foto (cámara o
galería, se sube por una URL firmada), edición, borrado, bandeja de outfit y las cuatro
pantallas de la prueba de look.

Del diseño que **todavía no existe en el servidor** y por eso no está en la app: marca y talla,
"last worn", favoritos, reconocimiento de prendas con IA ("Meet your new piece"), insignias
3D/AR, guardar y compartir looks. "Outerwear" y "One piece" se listan junto a Tops.

## Pruebas

```powershell
flutter test --no-pub test/closet_logic_test.dart test/closet_screens_test.dart
```
## Modelos 3D de accesorios

En **Closet → Add Item**, agrega una foto, elige **Accessory** y selecciona
**Glasses**, **Sunglasses**, **Cap** o **Hat**. En el detalle del accesorio,
abre **View in 3D** y toca **Create 3D model**. El visor permite girar y ampliar
el modelo. Si cambias la foto en **Edit Item**, la app te permite actualizarlo.

La foto se sube primero a Digital Closet. Virtual Try-On recupera la foto
asociada al accesorio y entrega el GLB autenticado en
`/api/v1/try-on/garments/{id}/model`. El visor recibe los bytes del GLB y
las credenciales de Supabase se configuran en el backend.

En el emulador Android, `ACCESSORY_3D_BASE_URL` usa por defecto
`http://10.0.2.2:8000/api/v1/try-on`. Si IAM se ejecuta en otro puerto,
por ejemplo 18080, inicia Flutter con
`--dart-define=API_BASE_URL=http://10.0.2.2:18080`. Si Digital Closet devuelve
URLs firmadas con `127.0.0.1:54421` para Supabase local, ejecuta
`adb reverse tcp:54421 tcp:54421`.

Para probar únicamente el envío multipart contra un Virtual Try-On en modo
local, inicia una compilación debug con
`--dart-define=ACCESSORY_3D_LOCAL_UPLOAD=true`. El visor ofrecerá elegir una
foto y enviará el campo `image` al API.
