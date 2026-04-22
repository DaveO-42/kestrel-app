# Kestrel App – TODO

> Dynamische Aufgabenliste. Wird in Claude-Sessions aktualisiert und manuell committed.
> Format: Priorität | Bereich | Aufgabe | Kontext

---

## 🟠 Kurzfristig

- [ ] **CORS einschränken** – Abhängig vom Backend-Task

---

## 🟡 Features – V2

- [ ] **Charts V2: Lightweight Charts + FMP-Daten** – Ersetzt TradingView WebView.
  Entry-Preis und Stop-Level als Overlays direkt im Chart einzeichnen.
  Abhängigkeit: FMP-Key muss aus Backend durchgereicht werden oder App nutzt eigenen Key.

- [ ] **Push Notifications via Firebase Cloud Messaging** – Ersetzt Telegram-Alerts vollständig.
  EXIT/WARN-Signale sollen direkt auf dem Telefon ankommen, nicht mehr nur per Telegram.
  Voraussetzung: Firebase-Projekt anlegen, `firebase_messaging`-Package, Backend-seitiger FCM-Push.

- [ ] **Position Detail: Stop-Update anzeigen** – Wenn Pass 2 den Trailing Stop angepasst hat,
  soll der neue Stop-Wert in der Position-Detail-Ansicht sofort sichtbar sein.
  Aktuell nur über Dashboard-Refresh erkennbar.

- [ ] **History: Filter & Sortierung** – Nach Ticker, Zeitraum, P&L filtern.
  Aktuell chronologisch, kein Filter.

---

## 🟢 Qualität / Schulden

- [ ] **Widget-Tests schreiben** – Aktuell keine Tests im Frontend.
  Priorität: `ApiService` (Mock-Mode), `CacheService`, `ShortlistScreen` (Bought-Flow).

- [ ] **`useMock` Build-Flag** – Aktuell hardcodiert in `api_service.dart`.
  Besser: `--dart-define=USE_MOCK=true` als Build-Argument damit Mock-Modus ohne Code-Änderung aktivierbar.

- [ ] **CORS in `src/api/main.py` einschränken** – Aktuell `allow_origins=["*"]`.
  Sobald Cloudflare-Domain bekannt ist: auf App-Origin beschränken.

- [x] **`--no-enable-impeller` Flag entfernen** – Bug behoben, Flag nicht mehr nötig.

---

## ✅ Erledigt

- [x] FastAPI-Backend mit GET + POST Endpoints
- [x] Offline-Cache via `CacheService` (SharedPreferences) für alle GET-Endpoints
- [x] `OfflineBanner` mit Datenalter in allen Screens
- [x] `PauseBanner` wenn System pausiert ist
- [x] Action-Endpoints: bought, sold, skip, resume
- [x] Shortlist: Top-Kandidat hervorgehoben, Skip-Funktion, Bought-Flow
- [x] System-Screen: Services-Status, Run-Log, Resume-Button
- [x] KestrelNav InheritedWidget für app-weite Navigation + Fehler-State
- [x] IndexedStack Navigation mit 4 Tabs
- [x] TradingView Chart via WebView in Position Detail
- [x] Tailscale-Connectivity (Tailscale-IP hardcodiert)
- [x] FCM Push Notifications via Firebase – ersetzt Telegram parallel.
     Token-Handling, HARD/WARN/CANDIDATES Events, Deep Links implementiert.
- [x] Cloudflare Tunnel – App verbindet ohne VPN über HTTPS
- [x] JWT Bearer Auth – Login-Screen, flutter_secure_storage, Auto-Refresh