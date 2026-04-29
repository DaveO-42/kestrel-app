# ANDROID_APP_CONTEXT.md
# Kestrel App – Vollständiger Projektkontext

> Zuletzt aktualisiert: April 2026 | Repo: `DaveO-42/kestrel-app`
> Dieses Dokument dient als Kontext-Transfer für neue Claude-Sessions.

---

## 1. Projektübersicht

**Was ist das?**
Flutter-basierte Android-App als primäre Schnittstelle für das Kestrel-Swing-Trading-System. Ersetzt den bisherigen Telegram-Bot-Workflow vollständig. Kommuniziert read/write mit einem FastAPI-Backend auf einem Raspberry Pi 3B, das seinerseits eine SQLite-Datenbank (`tracker.db`) mit Handelsdaten befüllt.

**Kestrel-Backend (Python)** läuft headless auf dem Pi als `kestrel.service` (systemd) und führt täglich eine Two-Pass-Pipeline aus:
- Pass 1 (~15:00): Screener, Detail-Analyse, Claude-Katalysator-Bewertung, Kaufentscheidung → TelegramBroker (Human-in-the-Loop)
- Pass 2 (~16:00): Monitor, WARN/EXIT-Signale

**Repos:**
- Backend: `DaveO-42/kestrel` → lokal unter `/Users/davidgersdorf/Development/kestrel/`, auf Pi unter `~/kestrel/`
- App: `DaveO-42/kestrel-app`

**Live-Status:** System läuft produktiv seit v0.5.0 (April 2026). Erste echte Position (ROST) ist aktiv.

---

## 2. Technologie-Stack

| Bereich | Technologie | Details |
|---|---|---|
| App | Flutter | Android-first, iOS später möglich |
| Sprache | Dart | Kein TypeScript, kein React Native |
| Backend-API | FastAPI (Python 3.11) | Eigener systemd-Service (`kestrel-api.service`) auf Pi, isoliert von `kestrel.service` |
| Datenbank | SQLite (`tracker.db`) | Nur via FastAPI — niemals direkter Zugriff aus der App |
| Connectivity | Cloudflare Tunnel | Primary: `https://api.kestrel-trading.com` (kein VPN nötig). Tailscale (`100.103.235.113:8000`) als Fallback/Entwicklung |
| Auth | JWT Bearer | Login mit bcrypt-Passwort → Access Token (7d) + Refresh Token (30d), `flutter_secure_storage` |
| Mock-Server | FastAPI lokal | `~/Development/kestrel-mock/` für Entwicklung ohne Pi-Zugriff |
| Charts | Lightweight Charts 4.x | `assets/chart.html` via WebView; Candles + EMA20/EMA50/Entry/Stop-Overlays |
| Notifications | Firebase Cloud Messaging | Implementiert; HARD/WARN/CANDIDATES-Events, Deep Links |
| IDE | Android Studio (Mac) | VS Code wird nicht verwendet |

**Flutter-Dependencies (pubspec.yaml, relevant):**
- `http` – HTTP-Calls zu FastAPI
- `flutter_secure_storage` – JWT-Token-Speicherung
- `firebase_messaging`, `firebase_core` – Push Notifications
- `shared_preferences` – Offline-Cache (`CacheService`)
- `flutter_lints` – Linting

---

## 3. Architektur

### Flutter-Projektstruktur

```
lib/
├── main.dart                              ← App-Einstieg, SplashScreen
├── main_screen.dart                       ← MainScreen + KestrelNav (InheritedWidget) + Settings-Sheet
├── theme/
│   └── kestrel_theme.dart                 ← KestrelColors (einzige Farbquelle), KestrelLogo
├── services/
│   ├── api_service.dart                   ← HTTP-Client, Mock-Toggle, alle Endpoints
│   ├── auth_service.dart                  ← Login, Logout, Token-Refresh, isLoggedIn
│   └── cache_service.dart                 ← Offline-Cache via SharedPreferences
├── screens/
│   ├── splash/splash_screen.dart          ← Animated Progress, Auth-Check, Fade zu Main/Login
│   ├── login/login_screen.dart            ← Passwort-Login, JWT-Flow
│   ├── dashboard/dashboard_screen.dart
│   ├── positions/position_detail_screen.dart ← inkl. Lightweight Chart
│   ├── shortlist/shortlist_screen.dart    ← inkl. Chart-Overlay, Bought-Flow
│   ├── history/history_screen.dart
│   ├── system/system_screen.dart          ← Run-Log, Service-Status, Resume, Shutdown
│   └── lab/
│       ├── lab_screen.dart                ← Tab-Container (Sandbox + Kalender)
│       ├── sandbox_screen.dart            ← Parameter-Backtest mit Job-Polling
│       └── calendar_screen.dart           ← Earnings-Kalender (nächste 14 Tage)
└── widgets/
    ├── info_sheet.dart                    ← Wiederverwendbares Info-Bottom-Sheet
    └── offline_banner.dart                ← Roter Banner bei fehlender Verbindung
```

### Backend-API-Struktur (im Kestrel-Repo)

```
src/api/
├── main.py              ← FastAPI-App, CORS (Cloudflare-Domain), Router-Import, Rate-Limiter
├── auth.py              ← POST /auth/login, /auth/refresh; JWT-Erzeugung, verify_token Dependency
├── db.py                ← SQLite-Helpers (read-only für die meisten Routes)
├── limiter.py           ← slowapi Rate-Limiting (5/min auf /auth/login)
└── routes/
    ├── dashboard.py     ← GET /dashboard, /positions, /positions/{ticker}, /positions/{ticker}/chart
    ├── system.py        ← GET /system/status, /system/health, /runs, /shortlist;
    │                       POST /system/fcm-token, /system/shutdown
    ├── actions.py       ← POST /actions/bought, /sold, /skip, /resume, /trigger-run
    ├── sandbox.py       ← POST /sandbox/run, /sandbox/cancel/{job_id};
    │                       GET /sandbox/status/{job_id}
    └── lab_calendar.py  ← GET /lab/calendar (4h In-Memory-Cache)
```

### Patterns

**KestrelNav (InheritedWidget):** Stellt app-weite Callbacks bereit (`goToSystem()`, `goToSettings()`, `setConnectionError(bool)`, `refreshDashboard()`). Screens nutzen `KestrelNav.of(context)?.setConnectionError(true)` im Fehlerfall.

**IndexedStack Navigation:** `MainScreen` nutzt `IndexedStack` mit 5 Tabs. Navigation per Bottom-Nav-Bar. Tab-Index: 0=Dashboard, 1=Shortlist, 2=History, 3=System, 4=Lab.

**Screen-Pattern:** Alle Screens sind `StatefulWidget` mit `_load()` via `Future.wait([...])`, `RefreshIndicator`, Offline-Fallback via `CacheService`.

**Auth-Flow:** `SplashScreen` prüft `AuthService.isLoggedIn()` → bei fehlendem/abgelaufenem Token Weiterleitung zu `LoginScreen`. Alle API-Calls nutzen JWT Bearer; bei 401 automatischer Token-Refresh, bei erneutem 401 Logout + Redirect.

---

## 4. Backend-Schnittstelle

### Protokoll
- REST/HTTP, JSON
- Basis-URL Produktion: `https://api.kestrel-trading.com` (Cloudflare Tunnel)
- Basis-URL Entwicklung: `http://100.103.235.113:8000` (Tailscale-IP des Pi)
- Basis-URL Mock: `http://10.0.2.2:8000` (Android-Emulator → localhost)
- Timeout: 8 Sekunden
- Auth: `Authorization: Bearer <access_token>` auf allen Endpoints außer `/auth/*` und `/health`

### Mock-Toggle
```dart
// lib/services/api_service.dart
static const bool useMock = false;  // true = assets/mock/*.json
static const String baseUrl = 'https://api.kestrel-trading.com';
```

**Mock-Server starten:**
```bash
cd ~/Development/kestrel-mock && source venv/bin/activate && uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### GET Endpoints

| Endpoint | Rückgabe | Flutter-Methode |
|---|---|---|
| `GET /health` | Liveness-Check | `ApiService.testConnection()` |
| `GET /dashboard` | Budget, Positionen, Drawdown, letzter Run | `ApiService.getDashboard()` |
| `GET /positions` | Liste offener Positionen | `ApiService.getPositions()` |
| `GET /positions/{ticker}` | Einzelne Position (404 wenn nicht offen) | `ApiService.getPosition(ticker)` |
| `GET /positions/{ticker}/chart` | OHLCV-Candles + EMA20/50/Entry/Stop-Overlays (40 Tage) | `ApiService.getPositionChart(ticker)` |
| `GET /shortlist` | Kandidaten aus letztem Run-Log | `ApiService.getShortlist()` |
| `GET /history` | Abgeschlossene Trades (limit/offset) | `ApiService.getHistory()` |
| `GET /history/summary` | Aggregierte Stats (Win%, Avg P&L etc.) | `ApiService.getHistorySummary()` |
| `GET /system/status` | Drawdown %, Pause-Zustand, Services | `ApiService.getSystemStatus()` |
| `GET /system/health` | Service-Ping-Checks (pi, fmp, claude, healthchecks) | `ApiService.getSystemHealth()` |
| `GET /runs` | Letzte Pipeline-Run-Logs | `ApiService.getRuns(limit: 10)` |
| `GET /sandbox/status/{job_id}` | Fortschritt/Ergebnis eines Backtest-Jobs | `ApiService.getSandboxStatus(jobId)` |
| `GET /lab/calendar` | Earnings nächste 14 Tage, getaggt (position/shortlist/universe) | `ApiService.getCalendar()` |

### POST Endpoints

| Endpoint | Beschreibung | Flutter-Methode |
|---|---|---|
| `POST /auth/login` | Passwort → Access + Refresh Token | `AuthService.login(password)` |
| `POST /auth/refresh` | Refresh Token → neuer Access Token | `AuthService.refreshToken()` |
| `POST /actions/bought` | Position nach manuellem Kauf erfassen | `ApiService.postBought(...)` |
| `POST /actions/sold` | Position nach manuellem Verkauf schließen | `ApiService.postSold(...)` |
| `POST /actions/skip` | Shortlist-Kandidat überspringen | `ApiService.postSkip(ticker)` |
| `POST /actions/resume` | Drawdown-Pause aufheben | `ApiService.postResume()` |
| `POST /actions/trigger-run` | Neuen Pipeline-Run starten (409 wenn bereits aktiv) | `ApiService.triggerRun()` |
| `POST /sandbox/run` | Backtest-Job starten → job_id | `ApiService.postSandboxRun(...)` |
| `POST /sandbox/cancel/{job_id}` | Laufenden Backtest-Job abbrechen | `ApiService.cancelSandboxRun(jobId)` |
| `POST /system/fcm-token` | FCM-Token auf Pi hinterlegen | `ApiService.postFcmToken(token)` |
| `POST /system/shutdown` | Pi herunterfahren | `ApiService.postShutdown()` |

### Wichtige Datenfeld-Konventionen

- **Position-Identifier:** `ticker` (String, z.B. `"NVDA"`) — keine numerische ID
- **Kurs:** `last_known_price_eur` + `price_updated_at` — kein Live-Kurs, nur aus letztem Pipeline-Run
- **Chart-Overlays:** Werte in USD (FMP-Daten); App rechnet intern um wenn nötig
- **Shortlist-Status:** `pending` / `confirmed` / `skipped` / `expired`
- **Shortlist-Quelle:** neuestes `logs/run_*.json` auf dem Pi
- **Währung:** Alle EUR-Werte sind fertig konvertiert (FastAPI nutzt FMP für EUR/USD-Rate); App zeigt nur EUR
- **RSI in Signalen:** `signals[].severity` = `INFO` / `WARN` / `HARD`
- **Sandbox-Jobs:** In-Memory auf Pi (kein DB-Zugriff); Status: `running` / `done` / `error` / `cancelled`
- **Earnings-Kalender:** In-Memory-Cache 4h TTL; Tags: `position` / `shortlist` / `universe`

---

## 5. Implementierte Features (Stand v1.2.2 – April 2026)

### ✅ Auth & Splash
Login-Screen mit Passwort-Eingabe → JWT-Flow. Splash prüft Token-Status, leitet zu Login oder MainScreen weiter.

### ✅ Bottom Navigation
5 Tabs: Dashboard · Shortlist · History · System · Lab. `IndexedStack` (keine Rebuilds beim Tab-Wechsel).

### ✅ Globale Mechanismen
- **OfflineBanner:** Roter Streifen unter AppBar bei Verbindungsfehler + Datenalter
- **PauseBanner:** Roter Streifen bei `is_paused: true` — alle Screens, navigiert bei Tap zu System-Tab
- **KestrelNav InheritedWidget:** App-weite State-Propagation
- **Settings-Sheet:** Server-URL, Verbindungstest, Notification-Toggles (FCM Topics)
- **Offline-Cache:** Alle GET-Endpoints via `CacheService` (SharedPreferences) gecacht

### ✅ Dashboard Screen
- Budget-Hero-Card: Gesamtbudget, investiert/verfügbar, Gold-Progress-Bar, Drawdown-Bar
- System-Card: Drawdown %, consecutive Losses, letzter Run
- Positions-Liste mit Traffic-Light-Ampel (Signalfarbe als linke Borderlinie)

### ✅ Position Detail Screen
- Price-Hero: aktueller Kurs, Entry, P&L-Badge
- Lightweight-Chart: Candlestick (40 Tage) + EMA20 (blau) + EMA50 (lila) + Entry-Linie (gold) + Stop-Linie (rot)
- Signal-Badges (HARD/WARN/INFO)
- Verkaufen-Action mit Fill-Preis-Eingabe

### ✅ Shortlist Screen
- Top-Kandidat hervorgehoben (Gold-Akzentlinie)
- Chart-Overlay pro Kandidat (Lightweight Charts)
- Kaufen-Flow: Menge + Fill-Preis → `POST /actions/bought`
- Skip-Funktion → `POST /actions/skip`
- Nach Kauf: Kandidaten-Card wird durch "Gekauft"-Card ersetzt

### ✅ History Screen
- Liste abgeschlossener Trades (chronologisch)
- Aggregierte Stats via `/history/summary`

### ✅ System Screen
- Services-Status (pi, fmp, claude, healthchecks)
- Run-Log (letzte 10 Runs)
- Resume-Button (nur sichtbar wenn pausiert)
- Pi-Shutdown-Button

### ✅ Lab Screen
- **Sandbox-Tab:** Parameter-Backtest (ATR-Multiplikator, RSI-Range, Min-Performance, Jahresauswahl). Asynchroner Job-Polling, Abbrechen-Button, Baseline-Vergleich (vs. Produktions-Parametern 2022–2024), clientseitige Aggregation bei fehlendem Server-Total.
- **Kalender-Tab:** Earnings der nächsten 14 Tage; getaggt nach position / shortlist / universe; Filter-Toggles

---

## 6. Offene Punkte

### TODOs App
- [ ] Trade-Journal: Notizfeld pro Position (offen + geschlossen) für 30-Trade-Review
- [ ] Equity-Kurve in History: P&L-Chart über Zeit
- [ ] Earnings-Warnung in Position Detail: "Nächste Earnings in X Tagen" (< 7 Tage = rot)
- [ ] Budget-Anpassung aus der App: `TOTAL_BUDGET` via POST ändern
- [ ] History: Filter & Sortierung (Ticker, Zeitraum, Win/Loss)
- [ ] Widget-Tests schreiben (ApiService Mock-Mode, CacheService, ShortlistScreen)

### TODOs Backend (FastAPI-Layer)
- [ ] EUR/USD-Rate-Caching optimieren (aktuell bei bestimmten Calls mehrfach FMP-Request)

### Bekannte Einschränkungen
- **Kein Live-Kurs:** `last_known_price_eur` wird nur während Pipeline-Runs aktualisiert.
- **Shortlist veraltet nach Börsenschluss:** `status: expired` ab dem Folgetag.
- **Sandbox begrenzt aussagekräftig:** Backtest nutzt historische FMP-Daten mit Survivorship Bias; dient Orientierung, nicht Optimierung.

---

## 7. Design-Entscheidungen

### Mock-first-Entwicklung
**Entscheidung:** App vollständig gegen lokalen FastAPI-Mock entwickeln, bevor echte Pi-Anbindung.
**Begründung:** Schutz des laufenden Trading-Systems. Der Pi läuft 24/7 produktiv.

### FastAPI als isolierter Layer
**Entscheidung:** Eigener `kestrel-api.service` (systemd), unabhängig von `kestrel.service`.
**Begründung:** API-Server-Absturz darf die Trading-Pipeline nicht stoppen.

### Kein Live-Kurs
**Entscheidung:** Nur `last_known_price_eur` (aus Pipeline-Run), kein separater Kurs-Feed.
**Begründung:** Swing-Positionen über Tage/Wochen — Sekundengenauigkeit nicht erforderlich.

### InheritedWidget statt Provider/Riverpod
**Begründung:** App-State ist minimal. Kein Overhead durch externes Framework gerechtfertigt.

### Card-Labels inside, nie floating
**Begründung:** Konsistenz mit Kestrel-Designsystem, verhindert visuelle Fragmentierung.

### Batch-UI-Änderungen
**Begründung:** Screen-Level-Anpassungen gesammelt in einem Block umsetzen statt Ping-Pong.

---

## 8. Wichtige Learnings

### Was nicht funktioniert hat

**`10.0.2.2` als Mock-URL:** Korrekt für Android-Emulator (mapped auf localhost des Hosts), aber irreführend beim Wechsel auf echte Verbindung.

**Position-ID als Integer:** Frühe API-Spezifikation. Korrigiert zu `ticker` (String). Hätte ohne frühen OpenAPI-Kontrakt zu aufwändigem Refactoring geführt.

**INTERNET Permission fehlt im Release-Build:** Flutter-Templates legen Permission nur in `debug/` und `profile/` an. Fix: in `android/app/src/main/AndroidManifest.xml` eintragen. Bei jedem Flutter-Setup zuerst prüfen.

**Impeller-Renderer:** Shader-Kompilierungsfehler beim Start — behoben, kein Workaround mehr nötig.

### Was verworfen wurde

- RSI als eigenes Feld in Position-Detail (implizit im WARN-Signal enthalten)
- AI Sentiment Gauge (zu vage, kein Handlungsimpuls)
- Panic-Exit-Button in V1 (verschoben auf frühestens V3)
- IBKR als Broker (2FA täglich → nicht automatisierbar)
- Backtesting als zentrales App-Feature (begrenzte Aussagekraft im Sandbox-Format)

---

## 9. Versions-Roadmap

### V1 – Monitoring (abgeschlossen)
Read-only: Dashboard, Position Detail, Shortlist, History, System, Splash.

### V2 – Control (abgeschlossen)
Kaufen, Verkaufen, Skippen, Resume. FCM Push Notifications. JWT-Auth. Cloudflare Tunnel. Lab (Sandbox + Kalender). Charts V2.

### V3 – Broker-Integration (nach 30-Trade-Meilenstein)
Trading 212 API-Integration. Vollautomatische Order-Ausführung.

---

## 10. Kestrel Design-System (Referenz)

### Farbpalette (`lib/theme/kestrel_theme.dart`)

```dart
// Hintergründe
screenBg   = Color(0xFF0F1822)  // Ebene 1: App-Hintergrund
innerBg    = Color(0xFF121C28)  // Ebene 1.5: innere Container
cardBg     = Color(0xFF1B2A3E)  // Ebene 2: Cards
cardBorder = Color(0xFF2E4A6A)  // Card-Kante
appBarBg   = Color(0xFF131F2E)  // AppBar / Nav

// Akzent Gold
gold      = Color(0xFFC9A84C)   // Labels, Nav-aktiv, CTAs
goldLight = Color(0xFFF0D080)   // AppBar-Titel, Score-Pills

// Text-Hierarchie
textPrimary = Color(0xFFE8EEF8) // Zahlen, Ticker, Preise
textGrey    = Color(0xFFC8D4E8) // Labels, Stats
textDimmed  = Color(0xFF6A8AAA) // Sekundäre Info, Timestamps
textHint    = Color(0xFF334D68) // Wirklich unwichtig

// Semantisch (nie zweckentfremden)
green       = Color(0xFF27C97A)  // P&L positiv, Trend intakt
greenBg     = Color(0xFF0D2318)
greenBorder = Color(0xFF1A4A2E)
red         = Color(0xFFE84040)  // P&L negativ, Stop, HARD
redBg       = Color(0xFF2A0D0D)
redBorder   = Color(0xFF5A1A1A)
orange      = Color(0xFFE07820)  // WARN-Signale
```

### Layout-Regeln
- Card-Labels: uppercase, 10px, `#c9a84c`, `letter-spacing: 0.8px`, **innerhalb** der Card
- Gold-Akzentlinie (`border-top: 2px solid #c9a84c`): Budget-Hero, System-Card, Top-Kandidat-Card
- Logo in jeder AppBar: SVG-Piktogramm 26×26px (Detail-Screens: 22×22px)
- Padding: Screen-Content `12px` horizontal, Cards `13px` innen

---

## 11. Umgebung & Setup

### Lokale Entwicklung
```bash
# Mock-Server starten (jede Session)
cd ~/Development/kestrel-mock && source venv/bin/activate && uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Flutter starten
flutter run
```

### Pi-Verbindung
- Cloudflare Tunnel: `https://api.kestrel-trading.com` (primär, kein VPN)
- Tailscale-Fallback: `http://100.103.235.113:8000`
- API-Start auf Pi: `uvicorn src.api.main:app --host 0.0.0.0 --port 8000`

### Umgebungsvariablen (`.env` im Kestrel-Repo)
```
ANTHROPIC_API_KEY=...
FMP_API_KEY=...
MONITOR_TELEGRAM_TOKEN=...
MONITOR_TELEGRAM_CHAT_ID=...
TOTAL_BUDGET=700.0
MIN_POSITION_SIZE=500.0
TRACKER_DB_PATH=tracker.db
LOGS_DIR=logs
APP_PASSWORD_HASH=...   ← bcrypt-Hash: python3 -c "import bcrypt; print(bcrypt.hashpw(b'pw', bcrypt.gensalt()).decode())"
APP_JWT_SECRET=...      ← openssl rand -hex 32
```

---

## 12. Arbeitsweise & Tool-Aufteilung

### Claude Chat (dieses Fenster)
- Architektur- und Designentscheidungen
- Feature-Spezifikationen ausarbeiten
- Komplette Dateien generieren
- Konzepte diskutieren und validieren

### Claude Code (`cd ~/Development/kestrel-app && claude`)
- Konkrete Implementierung direkt im Repo
- Debugging mit Dateizugriff
- Fehler fixen die Datei-Kontext brauchen

### Workflow
1. Design hier im Chat klären
2. Claude Chat generiert Dateien oder formuliert Prompt
3. Claude Code setzt im Repo um

**Wichtig:** Claude Code hat keinen Zugriff auf diesen Chat-Kontext. Relevanter Kontext muss als Prompt mitgegeben werden – Verweis auf `ANDROID_APP_CONTEXT.md` reicht.