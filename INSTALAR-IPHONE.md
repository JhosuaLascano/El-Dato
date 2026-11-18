# El Dato en iPhone (gratis, con AltStore)

Necesitas: tu PC con Windows, tu iPhone, el cable USB y un Apple ID (el mismo de tu iPhone sirve).

---

## Paso 1 · Conseguir el archivo `ElDato.ipa` (lo compila GitHub)

1. Entra a tu repositorio **el-dato** en github.com → pestaña **Actions**.
2. A la izquierda elige **"iOS (.ipa para AltStore)"** → botón **Run workflow** → **Run workflow**.
3. Espera unos 10–15 minutos hasta que aparezca el check verde.
4. Abre esa ejecución, baja hasta **Artifacts** y descarga **ElDato-iOS** (es un .zip).
5. Descomprímelo: adentro está `ElDato-v1.2.0.ipa`.

> Cada vez que cambiemos la app y se suba a GitHub, se compila sola; solo repites los pasos 3–5.

## Paso 2 · Preparar la PC (una sola vez)

1. Instala **iTunes** e **iCloud** descargándolos **desde la web de Apple** (apple.com), *no* desde la Microsoft Store — AltServer no funciona con las versiones de la Store.
2. Descarga **AltServer para Windows** desde **altstore.io** e instálalo.
3. Abre AltServer: aparece un rombo en la bandeja del sistema (junto al reloj, puede estar en la flechita ^).

## Paso 3 · Instalar AltStore en el iPhone (una sola vez)

1. Conecta el iPhone por cable. Si pregunta **"¿Confiar en esta computadora?"** → Confiar.
2. Abre iTunes, selecciona el iPhone y marca **"Sincronizar con este iPhone por Wi‑Fi"** → Aplicar. (Esto permite la renovación automática.)
3. Clic en el rombo de AltServer → **Install AltStore** → elige tu iPhone → escribe tu Apple ID y contraseña.
   (La contraseña va directo a Apple; AltStore no la guarda en ningún otro lado.)
4. En el iPhone:
   - **Ajustes → General → VPN y gestión de dispositivos** → toca tu Apple ID → **Confiar**.
   - **Ajustes → Privacidad y seguridad → Modo de desarrollador** → actívalo y reinicia (iOS 16 o superior).

## Paso 4 · Instalar El Dato

1. Pasa `ElDato-v1.2.0.ipa` al iPhone: guárdalo en **iCloud Drive** (desde iCloud para Windows o icloud.com) o envíatelo por correo/WhatsApp y toca **"Guardar en Archivos"**.
2. Abre **AltStore** en el iPhone → pestaña **My Apps** → botón **+** arriba a la izquierda → elige el `.ipa`.
3. Listo: aparece **El Dato** con el búho en tu pantalla de inicio.

## Cada 7 días: renovar

- **Automático:** si AltServer está abierto en la PC y el iPhone está en el mismo Wi‑Fi, AltStore renueva solo (en segundo plano, a veces mientras carga).
- **Manual (1 toque):** abre AltStore → **My Apps** → **Refresh All**.
- Si se te pasa y la app no abre, solo renueva: **tus datos no se borran**.

## Pasar tus datos desde Android

1. En el Android: El Dato → Ajustes → **Compartir respaldo** (o Guardar en el teléfono) y envíatelo.
2. En el iPhone: guarda el archivo en **Archivos** → El Dato → Ajustes → **Importar respaldo** → elígelo.

## Para saber

- Las notificaciones en iPhone usan el ícono del búho; Apple no permite cambiar su color como en Android.
- Para actualizar la app, instala el nuevo `.ipa` desde AltStore igual que la primera vez: **se conservan los datos** (usa siempre el mismo Apple ID).
- Con Apple ID gratis puedes tener máximo 3 apps de este tipo instaladas (AltStore cuenta como una).

## Agregar el widget

1. En la pantalla de inicio, mantén presionado un espacio vacío hasta que las apps se muevan.
2. Toca **+** (arriba a la izquierda) → busca **El Dato**.
3. Elige el tamaño: **pequeño** (saldo + botón), **mediano** o **grande** (saldo, "Agregar gasto" y tus pendientes) → **Agregar widget**.
4. Abre El Dato una vez para que el widget cargue tus datos.

Al tocar **Agregar gasto** se abre directo la pantalla para anotar el gasto; al tocar un pendiente se abre la pestaña de recordatorios.
