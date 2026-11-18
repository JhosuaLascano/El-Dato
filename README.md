<p align="center">
  <img src="assets/owl.png" width="160" alt="El Dato">
</p>

<h1 align="center">El Dato</h1>
<p align="center"><b>Tu dinero, al dato.</b> Registro de gastos diarios, ahorro y recordatorios — por LA DATA.</p>

---

## ¿Para qué sirve?

**El Dato** es una app para llevar el control de tu dinero día a día, rápida y sin complicaciones:

- **Billetera continua** — tu saldo baja con cada gasto y sube con cada ingreso o pago que recibes.
- **Módulos de gasto** — Comida, Transporte, Ocio, Educación… y puedes crear, editar, reordenar o eliminar los tuyos. Cada gasto lleva descripción y monto.
- **Ahorro con chanchito** — una pestaña con un chanchito dorado que se va llenando hacia tu meta (por ejemplo "Laptop — $800"). Guardar o retirar en un toque; lo ahorrado no cuenta como gasto.
- **Historial y búsqueda** — todo queda guardado por día. Filtra por fechas, módulo o tipo, y busca *"¿qué día gasté en esto?"*.
- **Comparaciones** — semana, mes y últimos 6 meses, con gráficos y los gastos más grandes.
- **Recordatorios** — pagos, tareas y compras con notificaciones reales (doradas en Android), que pueden repetirse diario, semanal o mensual.
- **Respaldo** — exporta e importa toda tu información en un archivo; tus datos se conservan al actualizar la app.
- Interfaz oscura en negro y oro, con animaciones fluidas y optimizada para ir rápido.

## ¿En qué está hecha?

| | |
|---|---|
| **Lenguaje** | [Dart](https://dart.dev) 3 |
| **Framework** | [Flutter](https://flutter.dev) 3.47 (una sola base de código para Android y iPhone) |
| **Base de datos** | SQLite local (`sqflite`) — todo se guarda en el teléfono, sin internet ni cuentas |
| **Gráficos** | `fl_chart` |
| **Notificaciones** | `flutter_local_notifications` |
| **Plataformas** | Android 7+ · iOS 15+ |

## Estructura

```
lib/
├── core/       # tema (colores LA DATA), formato de dinero y fechas
├── data/       # modelos, base de datos SQLite y estado de la app
├── services/   # notificaciones y respaldo
├── screens/    # inicio, historial, ahorro, estadísticas, recordatorios, ajustes
└── widgets/    # componentes reutilizables (chanchito animado, tarjetas, botones)
```

## Compilar

```bash
flutter pub get
flutter build apk --release --split-per-abi   # Android
```

La versión para iPhone se compila sola en GitHub Actions (pestaña **Actions → iOS (.ipa para AltStore)**). Cómo instalarla gratis en el iPhone: [INSTALAR-IPHONE.md](INSTALAR-IPHONE.md).

---

## Descargar

**Versión 1.1.0**

- **Android:** [ElDato-v1.1.0.apk](https://github.com/JhosuaLascano/El-Dato/releases/download/v1.1.0/ElDato-v1.1.0.apk)
- **iPhone:** [ElDato-v1.1.0.ipa](https://github.com/JhosuaLascano/El-Dato/releases/download/v1.1.0/ElDato-v1.1.0.ipa) (se instala con AltStore)

Todas las versiones: [Releases](https://github.com/JhosuaLascano/El-Dato/releases)
