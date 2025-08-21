# LightFlow

Controller mobile per **8 strisce LED** (FastLED-like).
- Inserisci l’indirizzo IP del microcontrollore e controlla ogni striscia.
- Endpoint usati: `/state`, `/set`, `/sync`.

## Stack
Flutter (Material 3) • Provider • http • shared_preferences • flutter_colorpicker • flutter_staggered_grid_view

## Struttura
```

lib/
app.dart
main.dart
core/
models/strip\_state.dart
services/led\_api.dart
repositories/led\_repository.dart
storage/settings\_store.dart
utils/color\_hex.dart
features/
connect/connect\_page.dart
controller/
controller\_page.dart
controller\_vm.dart
widgets/strip\_card.dart
assets/
icon/
lightflow\_icon\_1024.png
lightflow\_foreground\_1024.png

````

## Setup rapido
```bash
flutter pub get
# (solo prima volta Android) assicurati NDK 27 e cleartext attivo
# (solo iOS) pod install nella cartella ios/
````

### Icone app

Config in `pubspec.yaml` con `flutter_launcher_icons`:

```bash
dart run flutter_launcher_icons
```

## Mock server (sviluppo)

```
cd mock_server
python3 -m venv .venv && source .venv/bin/activate
pip install flask
python server.py
```

* Android Emulator → base URL: `http://10.0.2.2:5000`
* iOS Simulator → `http://127.0.0.1:5000`

## Note piattaforma

* **Android**: `android:usesCleartextTraffic="true"` in debug (Manifest).
* **iOS**: ATS aperto in debug (Info.plist `NSAppTransportSecurity/NSAllowsArbitraryLoads=true`).

## Esecuzione

```bash
flutter run -d <device>
```

## Endpoints attesi

* `GET /state` → `{ used:[...], b:[...], s:[...], c:["RRGGBB", ...] }`
* `GET /set?which=&n=&b=&s=&c=`
* `GET /sync`