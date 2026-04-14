# Kestrel App

> *Hover. Strike. Ride.*

Flutter-basierte Android-App als primäre Schnittstelle für das [Kestrel Swing-Trading-System](https://github.com/DaveO-42/kestrel). Zeigt offene Positionen, Shortlist-Kandidaten, Trade-History und Systemstatus in Echtzeit. Kommuniziert read/write mit einem FastAPI-Backend auf einem Raspberry Pi.

**Live-Status:** v0.5.x – produktiv seit April 2026. Erste echte Position aktiv (ROST).

---

## Stack

| Bereich | Technologie |
|---|---|
| App | Flutter (Android-first) |
| Sprache | Dart |
| Backend-API | FastAPI auf Raspberry Pi 3B |
| Datenbank | SQLite (`tracker.db`) – nur via API, niemals direkt |
| Connectivity | Tailscale VPN (`100.103.235.113:8000`) |
| Mock-Server | FastAPI lokal (`~/Development/kestrel-mock/`) |
| Charts V1 | TradingView WebView Widget |
| IDE | Android Studio (Mac) |

---

## Voraussetzungen

- Flutter (stable channel)
- Android Studio
- Tailscale auf dem Telefon (für Verbindung zum Pi unterwegs)

---

## Setup & lokale Entwicklung

### Mock-Modus (ohne Pi)

```bash
# Mock-Server starten
cd ~/Development/kestrel-mock
source venv/bin/activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

In `lib/services/api_service.dart` Mock-Flag setzen:

```dart
static const bool useMock = false;  // → true für Mock-Assets (JSON-Dateien)
static const String baseUrl = 'http://100.103.235.113:8000';  // Tailscale-IP des Pi
```

Im Emulator zeigt `http://10.0.2.2:8000` auf localhost.

### App bauen & starten

```bash
flutter run
flutter build apk
```

---

## Projektstruktur

```
lib/
├── main.dart                          ← App-Einstieg, SplashScreen
├── main_screen.dart                   ← MainScreen + KestrelNav (InheritedWidget) + Settings-Sheet
├── theme/
│   └── kestrel_theme.dart             ← KestrelColors (einzige Farbquelle), KestrelLogo
├── services/
│   ├── api_service.dart               ← HTTP-Client, Mock-Toggle, alle Endpoints
│   └── cache_service.dart             ← Offline-Cache via shared_preferences
├── screens/
│   ├── splash/splash_screen.dart
│   ├── dashboard/dashboard_screen.dart
│   ├── positions/position_detail_screen.dart
│   ├── shortlist/shortlist_screen.dart
│   ├── history/history_screen.dart
│   └── system/system_screen.dart
└── widgets/
    ├── info_sheet.dart                ← Wiederverwendbares Info-Bottom-Sheet
    ├── offline_banner.dart            ← Roter Banner bei fehlender Verbindung
    └── ...
```

### Key-Patterns

**KestrelNav (InheritedWidget):** App-weite Callbacks (`goToSystem()`, `setConnectionError(bool)`, `refreshDashboard()`). Alle Screens nutzen `KestrelNav.of(context)` für Navigation und Fehlerhandling.

**IndexedStack Navigation:** 4 Tabs – `0=Dashboard`, `1=Shortlist`, `2=History`, `3=System`.

**Screen-Pattern:** Alle Screens sind `StatefulWidget` mit `_load()` via `Future.wait([...])`, `RefreshIndicator` und Offline-Fallback via `CacheService`.

---

## Backend-Schnittstelle

Basis-URL Produktion: `http://100.103.235.113:8000` (Tailscale)  
Timeout: 8 Sekunden | Nur GET + POST in V1

### GET Endpoints

| Endpoint | Beschreibung |
|---|---|
| `GET /dashboard` | Budget, offene Positionen, Drawdown, letzter Run |
| `GET /positions` | Liste offener Positionen |
| `GET /positions/{ticker}` | Einzelne Position (404 wenn nicht offen) |
| `GET /shortlist` | Kandidaten aus letztem Pipeline-Run |
| `GET /history` | Abgeschlossene Trades (limit/offset) |
| `GET /history/summary` | Aggregierte Stats (Win%, Avg P&L etc.) |
| `GET /system/status` | Systemzustand, Pause-Status, Drawdown |
| `GET /runs` | Letzte Pipeline-Runs (limit konfigurierbar) |
| `GET /health` | Liveness-Check |

### POST Endpoints (Actions)

| Endpoint | Beschreibung |
|---|---|
| `POST /actions/bought` | Position nach manuellem Kauf erfassen |
| `POST /actions/sold` | Position nach manuellem Verkauf schließen |
| `POST /actions/skip` | Shortlist-Kandidat überspringen |
| `POST /actions/resume` | Drawdown-Pause aufheben |

---

## Offline-Verhalten

Alle GET-Endpoints cachen ihre Antworten via `CacheService` (SharedPreferences). Bei fehlendem Netzwerk wird der Cache zurückgegeben und ein `OfflineBanner` mit Alter der Daten angezeigt. POST-Aktionen (bought, sold etc.) sind im Offline-Modus nicht verfügbar.

---

## Verwandte Repos

- **Backend:** [DaveO-42/kestrel](https://github.com/DaveO-42/kestrel) – Python-Pipeline auf dem Pi
- **Kontext-Dokument:** `ANDROID_APP_CONTEXT.md` – vollständiger Projekt-Kontext für Claude-Sessions
