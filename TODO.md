# Kestrel App – TODO

> Dynamische Aufgabenliste. Wird in Claude-Sessions aktualisiert und manuell committed.
> Format: Priorität | Bereich | Aufgabe | Kontext

---

## 🟡 Features – Nächste Schritte

- [ ] **Trade-Journal / Notizen** – Freitextfeld pro Position (offen + geschlossen).
  Primär für die 30-Trade-Review: Dokumentation warum ein Trade funktioniert / nicht funktioniert hat.
  Backend: neue Spalte `notes` in `history`-Tabelle + `PATCH /positions/{ticker}/notes` Endpoint.

- [ ] **Equity-Kurve in History** – P&L-Chart über Zeit statt nur Tabelle.
  Drawdown-Phasen und Performance-Trend auf einen Blick. Daten aus vorhandenen History-Endpoints.

- [ ] **Earnings-Warnung in Position Detail** – "Nächste Earnings in X Tagen" mit Ampelfarbe.
  Grün (> 14 Tage) / Orange (7–14 Tage) / Rot (< 7 Tage = Earnings-Sperre fast erreicht).
  Daten via FMP kommen bereits durch die Pipeline.

- [ ] **Budget-Anpassung aus der App** – `TOTAL_BUDGET` via POST ändern ohne SSH auf den Pi.
  Backend: `POST /system/budget` schreibt neuen Wert in `.env` oder `tracker.db`.

- [ ] **History: Filter & Sortierung** – Nach Ticker, Zeitraum, Win/Loss filtern.
  Aktuell chronologisch ohne Filter.

---

## 🟢 Qualität / Schulden

- [ ] **Widget-Tests schreiben** – Aktuell keine Tests im Frontend.
  Priorität: `ApiService` (Mock-Mode), `CacheService`, `ShortlistScreen` (Bought-Flow).

- [ ] **EUR/USD-Rate-Caching optimieren** – Backend macht bei bestimmten Endpoints
  mehrfach FMP-Requests für die Rate. Einmal pro Session/Stunde reicht.

---

## ✅ Erledigt

- [x] FastAPI-Backend mit GET + POST Endpoints
- [x] Offline-Cache via `CacheService` (SharedPreferences) für alle GET-Endpoints
- [x] `OfflineBanner` mit Datenalter in allen Screens
- [x] `PauseBanner` wenn System pausiert ist
- [x] Action-Endpoints: bought, sold, skip, resume
- [x] Shortlist: Top-Kandidat hervorgehoben, Skip-Funktion, Bought-Flow
- [x] System-Screen: Services-Status, Run-Log, Resume-Button, Pi-Shutdown
- [x] KestrelNav InheritedWidget für app-weite Navigation + Fehler-State
- [x] IndexedStack Navigation mit 5 Tabs (inkl. Lab)
- [x] FCM Push Notifications via Firebase – HARD/WARN/CANDIDATES Events, Deep Links
- [x] Cloudflare Tunnel – App verbindet ohne VPN über HTTPS (`api.kestrel-trading.com`)
- [x] JWT Bearer Auth – Login-Screen, `flutter_secure_storage`, Auto-Refresh
- [x] CORS einschränken – `allow_origins=["https://api.kestrel-trading.com"]` aktiv
- [x] Charts V2: Lightweight Charts (assets/chart.html via WebView)
  Candlestick + EMA20 + EMA50 + Entry-Overlay + Stop-Overlay
  Implementiert in Position Detail und Shortlist
- [x] Manueller Run-Trigger – `POST /actions/trigger-run` (Backend + Frontend implementiert)
  409 wenn bereits ein Run aktiv ist (Lock-File-Check)
- [x] Lab-Tab: Sandbox (Parameter-Backtest mit Job-Polling + Abbrechen) +
  Earnings-Kalender (14 Tage, getaggt nach position/shortlist/universe)
- [x] `--dart-define=USE_MOCK=true` Build-Flag (Impeller-Bug behoben, Flag entfernt)
- [x] `GET /positions/{ticker}/chart` Endpoint (OHLCV + EMA20/50 + Entry/Stop-Overlays)
- [x] Sandbox: Backtest-Ergebnis cachen (kein Re-Run bei Tab-Wechsel)