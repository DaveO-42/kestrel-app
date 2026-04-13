# ANDROID_APP_CONTEXT.md
# Kestrel App – Vollständiger Projektkontext

> Erstellt: April 2026 | Repo: `DaveO-42/kestrel-app`
> Dieses Dokument dient als Kontext-Transfer für neue Claude-Sessions.

---

## 1. Projektübersicht

**Was ist das?**
Flutter-basierte Android-App als primäre Schnittstelle für das Kestrel-Swing-Trading-System. Ersetzt den bisherigen Telegram-Bot-Workflow vollständig. Läuft read-only gegen ein FastAPI-Backend auf einem Raspberry Pi 3B, das seinerseits eine SQLite-Datenbank (`tracker.db`) mit Handelsdaten befüllt.

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
| Datenbank | SQLite (`tracker.db`) | Read-only via FastAPI — niemals direkter Zugriff aus der App |
| Connectivity | Tailscale VPN | Pi von unterwegs über `100.103.235.113:8000` erreichbar |
| Mock-Server | FastAPI lokal | `~/Development/kestrel-mock/` für Entwicklung ohne Pi-Zugriff |
| Charts V1 | TradingView WebView Widget | Eingebettet per WebView |
| Charts V2 | Lightweight Charts + FMP-Daten | Geplant: Entry/Stop-Overlays |
| Notifications V2 | Firebase Cloud Messaging | Geplant: ersetzt Telegram |
| IDE | Android Studio (Mac) | VS Code wird nicht verwendet |
| Build-Flag | `--no-enable-impeller` | Pflicht – Shader-Kompilierungsbug auf aktuellem Flutter/Mac-Setup |

**Flutter-Dependencies (pubspec.yaml, relevant):**
- `http` – HTTP-Calls zu FastAPI
- `flutter_lints` – Linting

---

## 3. Architektur

### Flutter-Projektstruktur

```
lib/
├── main.dart                          ← App-Einstieg, SplashScreen
├── main_screen.dart                   ← MainScreen + KestrelNav (InheritedWidget) + Settings-Sheet
├── theme/
│   └── kestrel_theme.dart             ← KestrelColors (einzige Farbquelle), KestrelLogo
├── services/
│   └── api_service.dart               ← HTTP-Client, Mock-Toggle, alle Endpoints
├── screens/
│   ├── splash/splash_screen.dart      ← Animated Progress, Fade zu MainScreen
│   ├── dashboard/dashboard_screen.dart
│   ├── positions/position_detail_screen.dart
│   ├── shortlist/shortlist_screen.dart
│   ├── history/history_screen.dart
│   └── system/system_screen.dart
└── widgets/
    └── info_sheet.dart                ← Wiederverwendbares Info-Bottom-Sheet
```

### Backend-API-Struktur (im Kestrel-Repo)

```
src/api/
├── main.py                  ← FastAPI-App, CORS, Router-Import
├── db.py                    ← SQLite-Helpers (read-only)
└── routes/
    ├── dashboard.py         ← GET /dashboard, /positions, /positions/{ticker}
    └── system.py            ← GET /system/status, /history, /history/summary, /runs, /shortlist
```

### Patterns

**KestrelNav (InheritedWidget):** Stellt app-weite Callbacks bereit (`goToSystem()`, `goToSettings()`, `setConnectionError(bool)`, `connectionError` bool). Screens nutzen `KestrelNav.of(context)?.setConnectionError(true)` im Fehlerfall.

**IndexedStack Navigation:** `MainScreen` nutzt `IndexedStack` mit 4 Tabs. Navigation per Bottom-Nav-Bar. Tab-Index: 0=Dashboard, 1=Shortlist, 2=History, 3=System.

**Screen-Pattern:** Alle Screens sind `StatefulWidget` mit `_load()` via `Future.wait([...])`, `RefreshIndicator`, Error-Handling über `KestrelNav.setConnectionError`.

---

## 4. Backend-Schnittstelle

### Protokoll
- REST/HTTP, JSON
- Basis-URL Produktion: `http://100.103.235.113:8000` (Tailscale-IP des Pi)
- Basis-URL Mock: `http://10.0.2.2:8000` (Android-Emulator → localhost)
- Timeout: 8 Sekunden
- Nur GET-Methoden in V1

### Mock-Toggle
```dart
// lib/services/api_service.dart
static const bool useMock = false;  // true = assets/mock/*.json
static const String baseUrl = 'http://100.103.235.113:8000';
```

**Mock-Server starten:**
```bash
cd ~/Development/kestrel-mock && source venv/bin/activate && uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Endpoints (alle implementiert)

| Endpoint | Methode | Rückgabe | Flutter-Methode |
|---|---|---|---|
| `/dashboard` | GET | Budget, Positionen, Drawdown, letzter Run | `ApiService.getDashboard()` |
| `/positions` | GET | Liste offener Positionen | `ApiService.getPositions()` |
| `/positions/{ticker}` | GET | Einzelne Position (404 wenn nicht offen) | `ApiService.getPosition(ticker)` |
| `/shortlist` | GET | Kandidaten aus letztem Run-Log | `ApiService.getShortlist()` |
| `/history` | GET | Abgeschlossene Trades (limit/offset) | `ApiService.getHistory()` |
| `/history/summary` | GET | Aggregierte Stats (Win%, Avg P&L etc.) | `ApiService.getHistorySummary()` |
| `/system/status` | GET | Drawdown %, Pause-Zustand | `ApiService.getSystemStatus()` |
| `/runs` | GET | Letzte Pipeline-Run-Logs | `ApiService.getRuns(limit: 10)` |
| `/health` | GET | Liveness-Check | `ApiService.testConnection()` |

### Wichtige Datenfeld-Konventionen

- **Position-Identifier:** `ticker` (String, z.B. `"NVDA"`) — keine numerische ID
- **Kurs:** `last_known_price_eur` + `price_updated_at` — kein Live-Kurs, nur aus letztem Pipeline-Run
- **Shortlist-Status:** `pending` / `confirmed` / `skipped` / `expired` (abgeleitet aus `run_date` vs. heute)
- **Shortlist-Quelle:** neuestes `logs/run_*.json` auf dem Pi
- **Währung:** Alle EUR-Werte sind fertig konvertiert (FastAPI nutzt FMP für EUR/USD-Rate); App zeigt nur EUR
- **RSI in Signalen:** `signals[].severity` = `INFO` / `WARN` / `HARD`

### Geplanter Endpoint (noch nicht implementiert)

```yaml
GET /system/health
Response:
  checked_at: datetime
  services:
    - name: string          # pi | fmp | claude | healthchecks | sec_edgar
      status: string        # ok | degraded | error | unknown
      latency_ms: int|null
      last_checked_at: datetime
      message: string|null
```
Degraded-Schwellen: FMP >2000ms, Claude >5000ms, SEC EDGAR >3000ms.

---

## 5. Implementierte Features (V1 – Stand April 2026)

### ✅ Splash Screen
Animierter Ladebalken (0% → 100%), Kestrel-Logo + Name, Fade-Transition zu MainScreen.

### ✅ Bottom Navigation
4 Tabs mit Icons: Dashboard · Shortlist · History · System. `IndexedStack` (keine Rebuilds beim Tab-Wechsel).

### ✅ Globale Mechanismen
- **ErrorBanner:** Roter Streifen unter AppBar bei Verbindungsfehler
- **PauseBanner:** Roter Streifen bei `is_paused: true` — alle Screens, navigiert bei Tap zu System-Tab
- **KestrelNav InheritedWidget:** App-weite State-Propagation
- **Settings-Sheet:** Server-URL-Anzeige, Verbindungstest mit Latenz-Feedback

### ✅ Dashboard Screen
- Budget-Hero-Card: 28px Gesamtbudget, investiert/verfügbar, Gold-Progress-Bar, Drawdown-Bar (orange ab 70%)
- System-Card: Drawdown %, consecutive Losses, letzter Ping, letzter Run
- Positions-Liste: Ticker, Entry/Stop, P&L (abs + %), Gesamtwert
- **Traffic-Light-Ampel:** 3px farbige Linke Borderlinie pro Zeile basierend auf `signals[].severity`
  - 🟢 Grün = keine aktiven Signale
  - 🟠 Orange = mindestens ein `WARN`-Signal
  - 🔴 Rot = mindestens ein `HARD`-Signal

### ✅ Position Detail Screen
- Price-Hero: 32px aktueller Kurs, Entry-Preis, P&L-Badge
- **Price Range Bar:** Stop–Entry–Kurs visuell als farbige Segmente
  - Plus-Zustand (Kurs > Entry): Rot (Stop-Zone) → Rot gedimmt (Risiko) → Grün (Gewinn) → Track (Potenzial)
  - Minus-Zustand (Kurs < Entry): Rot → Rot gedimmt → Orange gedimmt → Track
  - Entry-Position berechnet: `8% + ((entry-stop)/(kurs-stop)) × 84%`
- Trade-Parameter-Card: Entry-Datum, Stück, ATR, Stop initial, Stop aktuell, Höchstkurs, Stop-Modus-Badge
- Signal-Card: HARD/WARN/INFO Badges mit zugehörigen Beschreibungen
- Katalysator-Card: Earnings-Beat + Claude-Analyse
- HARD-Alert-Banner (rot, sticky) wenn HARD-Signal aktiv
- „Verkaufen →"-Button (V2-Platzhalter, Gold-CTA, sticky am unteren Rand)

### ✅ Shortlist Screen
- Status-Badge in AppBar: pending / confirmed / skipped / expired
- Pause-Banner wenn System pausiert
- Kandidaten-Cards mit Gold-`border-top`: Ticker, Score, Sektor, 4W-Performance, EPS-Surprise
- Claude-Box (linker Gold-Akzentstreifen): `katalysator_intakt`, `katalysator_eingeschaetzt`, `gegenargumente`, `gap_risiko`
- Trade-Parameter-Box: RSI, EMA20, EMA50, Steigung
- Aktions-Buttons (Kaufen/Skippen) als V2-Platzhalter

### ✅ History Screen
- P&L-Hero: Gesamtgewinn/-verlust, Win-Rate, Avg P&L
- Trade-Liste absteigend nach Datum: Ticker, Entry/Exit-Datum, Haltedauer, P&L
- Summary-Stats-Card

### ✅ System Screen
- Pause-Card (nur wenn `is_paused: true`): Grund, Datum, Resume-Button (V2-Platzhalter)
- Drawdown-Card: aktueller Drawdown vs. 25%-Limit
- Run-Log: letzte 10 Pipeline-Runs mit Zeit, Shortlist-Count, Order-Status-Badge

---

## 6. Offene TODOs & bekannte Probleme

### TODOs V1 (App)
- [ ] `GET /system/health` Endpoint im Backend implementieren → Service-Health-Card auf System-Screen aktivieren
- [ ] Traffic-Light-Logik: Kurs ≤ 5% über Stop → Rot (aktuell nur via Signal-Severity)
- [ ] Charts: TradingView WebView Widget auf Position Detail Screen einbauen
- [ ] Settings-Sheet: Server-URL konfigurierbar machen (aktuell hardcoded)
- [ ] `useMock = false` und `baseUrl` sollten aus einer Config-Datei kommen, nicht hardcoded sein

### TODOs Backend (FastAPI-Layer)
- [ ] `GET /system/health` implementieren (Service-Ping-Checks in `system_state`-Tabelle cachen)
- [ ] `kestrel-api.service` als systemd-Service auf Pi deployen und durchtesten
- [ ] EUR/USD-Rate-Caching optimieren (aktuell bei jedem API-Call ein FMP-Request)

### Bekannte Probleme / Einschränkungen
- **Kein Live-Kurs:** `last_known_price_eur` wird nur während Pipeline-Runs aktualisiert. App zeigt immer den Kurs des letzten Runs, nicht Echtzeit.
- **Impeller deaktiviert:** `--no-enable-impeller` erforderlich — Shader-Kompilierungsbug auf aktuellem Flutter/Mac-Setup. Bei Flutter-Update prüfen ob Problem behoben.
- **Shortlist veraltet nach Börsenschluss:** `status: expired` ab dem Folgetag — App zeigt leere Shortlist außerhalb von Handelstagen.
- **`useMock`-Flag ist hardcoded:** Muss manuell geändert werden für Mock vs. echte Verbindung.

---

## 7. Design-Entscheidungen

### Mock-first-Entwicklung
**Entscheidung:** App vollständig gegen lokalen FastAPI-Mock entwickeln, bevor echte Pi-Anbindung.
**Begründung:** Schutz des laufenden Trading-Systems. Der Pi läuft 24/7 produktiv. Fehler in der App dürfen den `kestrel.service` nicht beeinflussen.

### API-Kontrakt vor Implementierung
**Entscheidung:** `kestrel_api.yaml` (OpenAPI) als verbindlicher Kontrakt definiert, bevor ein einziger Screen gebaut wurde.
**Begründung:** Verhindert Mid-Development-Überraschungen bei Datenformaten. Korrekturen wurden frühzeitig erkannt (z.B. `ticker` als String statt numerische ID).

### FastAPI als isolierter Layer
**Entscheidung:** Eigener `kestrel-api.service` (systemd), unabhängig von `kestrel.service`.
**Begründung:** API-Server-Absturz darf die Trading-Pipeline nicht stoppen. Getrennte Prozesse, getrennte Verantwortlichkeiten.

### Kein Live-Kurs in V1
**Entscheidung:** Nur `last_known_price_eur` (aus Pipeline-Run), kein separater Kurs-Feed.
**Begründung:** Kein kostenpflichtiger Real-Time-Datenfeed nötig für reine Monitoring-App. Kestrel handelt Swing-Positionen über Tage/Wochen – Sekundengenauigkeit nicht erforderlich.

### InheritedWidget statt Provider/Riverpod
**Entscheidung:** `KestrelNav` als natives Flutter `InheritedWidget` für App-State.
**Begründung:** App-State ist minimal (Verbindungsfehler, Tab-Navigation). Kein Overhead durch externes State-Management-Framework gerechtfertigt.

### Design: Card-Labels inside, nie floating
**Entscheidung:** Alle Section-Labels (z.B. „OFFENE POSITIONEN") befinden sich **innerhalb** der Card, nie als freistehende Header darüber.
**Begründung:** Konsistenz mit Kestrel-Designsystem, verhindert visuelle Fragmentierung.

### Batch-UI-Änderungen
**Entscheidung:** Screen-Level-Anpassungen werden gesammelt und in einem Block umgesetzt.
**Begründung:** Verhindert endlose Ping-Pong-Iterationen. Volle Screen-Architektur erst definieren, dann implementieren.

---

## 8. Wichtige Learnings

### Was nicht funktioniert hat

**Impeller-Renderer:** Shader-Kompilierungsfehler beim Start auf dem aktuellen Flutter/Mac-Setup. Lösung: `--no-enable-impeller` als permanentes Run-Flag. Bei Flutter-Upgrades erneut prüfen.

**`10.0.2.2` als Mock-URL:** Korrekt für Android-Emulator (mapped auf localhost des Hosts), aber irreführend. Sobald `useMock = false` gesetzt wird, muss die echte Pi-Tailscale-IP verwendet werden. Das Flag und die URL sind aktuell hardcoded — fehleranfällig.

**Position-ID als Integer:** Frühe API-Spezifikation nutzte numerische IDs. Korrigiert zu `ticker` (String), da Kestrel intern immer Ticker als Identifier verwendet. Hätte ohne frühen Kontrakt zu aufwändigen Refactorings geführt.

### Was verworfen wurde

**RSI direkt in Trade-Parameter:** Entschieden, RSI **nicht** als eigenes Feld in Position-Detail zu zeigen — es ist bereits implizit im WARN-Signal enthalten. Doppelte Info vermieden.

**Consecutive-Loss-Counter auf System-Screen:** Gehört auf Dashboard (Systemübersicht), nicht auf System-Tab. Verworfen um Redundanz zu vermeiden.

**AI Sentiment Gauge:** Aus Falcon-Command-Design-Referenz evaluiert. Verworfen — zu vage, kein konkreter Handlungsimpuls für Nutzer.

**Panic-Exit-Button in V1:** Evaluiert, verschoben auf frühestens V2. V1 ist bewusst read-only.

**IBKR als Broker:** Technisch implementierbar, aber Client Portal API erfordert 2FA bei jedem Session-Reset (täglich Mitternacht MEZ). Nicht vollautomatisierbar für Privatanleger ohne OAuth. → Trading 212 als Favorit für V3.

---

## 9. Versions-Roadmap

### V1 – Read-only (in Arbeit / nahezu abgeschlossen)
Alle Screens implementiert: Dashboard, Position Detail, Shortlist, History, System, Splash, Navigation. Echte Pi-Verbindung aktiv.

### V2 – Control (geplant)
- Kaufen, Verkaufen, Skippen, Resume als App-Actions
- FCM Push Notifications (Shortlist-Alert, WARN, HARD)
- Telegram vollständig ersetzen

### V3 – Broker-Integration (nach 30-Trade-Meilenstein)
- Trading 212 API-Integration (Beta-API, API-Key reicht, kostenlos)
- Vollautomatische Order-Ausführung

---

## 10. Kestrel Design-System (Referenz)

### Farbpalette (`lib/theme/kestrel_theme.dart`)

```dart
// Hintergründe
screenBg   = Color(0xFF0F1822)  // Ebene 1: App-Hintergrund
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
green  = Color(0xFF27C97A)  // P&L positiv, Trend intakt
red    = Color(0xFFE84040)  // P&L negativ, Stop, HARD
orange = Color(0xFFE07820)  // WARN-Signale
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

# Flutter starten (Impeller deaktiviert)
flutter run --no-enable-impeller
```

## 12. Arbeitsweise & Tool-Aufteilung
### Claude Chat (dieses Fenster):
- Architektur- und Designentscheidungen
- Feature-Spezifikationen ausarbeiten
- Komplette Dateien generieren
- Konzepte diskutieren und validieren

### Claude Code (cd ~/Development/kestrel_app && claude):
- Konkrete Implementierung direkt im Repo
- Debugging mit Dateizugriff
- Fehler fixen die Datei-Kontext brauchen

### Workflow:
1. Design hier im Chat klären
2. Claude Chat generiert Dateien oder formuliert Prompt
3. Claude Code setzt im Repo um

Wichtig: Claude Code hat keinen Zugriff auf diesen Chat-Kontext. Relevanter Kestrel-Kontext muss bei Bedarf als Prompt mitgegeben werden – z.B. Verweis auf ANDROID_APP_CONTEXT.md und TRADING_RULES.md.

### Pi-Verbindung (Tailscale)
- Pi-IP (Tailscale): `100.103.235.113`
- API-Port: `8000`
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
```
