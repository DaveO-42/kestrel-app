# Kestrel App – Changelog

Format: MAJOR.MINOR.PATCH
- MAJOR – fundamentale Navigation/Architektur-Änderungen
- MINOR – neue Screens oder Features
- PATCH – Bugfixes, UI-Anpassungen

---

## [1.3.1] – 2026-05-16
- Paper-Tab: Run-Log für H (clientseitig gefiltert nach hypothesis-Feld, Alle-Tab zeigt alle Runs)
- Paper-Tab: Hypothesen-Beschreibung im collapsible Strategie-Abschnitt für C, H und Alle

## [1.3.0] – 2026-05-16
- Paper-Tab: Sub-Tabs C / H / Alle für Hypothese H
  - Segmented Control innerhalb des Paper-Tabs (C | H | Alle)
  - H-Positionen zeigen Z-Score bei Entry und Haltedauer (Tag X / 10)
  - Hypothesis-Badge (gold / lila) sichtbar im Alle-Tab
  - Kombinierte Summary für Alle-Tab (gewichtete Mittelwerte)
  - Clientseitiges Filtern bis Backend-Update, danach Query-Parameter

## [1.2.7] – 2026-05-15
- Trigger-Run-Button auch im Empty-State der Shortlist verfügbar (kein Stale-Flag mehr als Voraussetzung)

## [1.2.6] – 2026-05-12
- Fix: OfflineBanner im Lab zeigte "unbekannt" – jeder Tab zeigt jetzt sein eigenes Datenalter korrekt an
- Fix: Run-Log Datum wurde nicht angezeigt (Feldname-Mismatch `timestamp` → `run_at`)
- Run-Log: Tap auf Zeile zeigt reject_summary-Breakdown (Gate-Ablehnungen)

## [1.2.5] – 2026-05-01
- Earnings-Warnung in Position Detail (gold: 7–14 Tage, orange + "Sperre aktiv": <7 Tage)

## [1.2.3] – 2026-04-29
- Equity-Kurve in History: P&L-Chart über Zeit, Drawdown-Phasen sichtbar

## [1.2.2] – 2026-04-29
- Sandbox: Backtest-Ergebnis cachen (kein Re-Run bei Tab-Wechsel)

## [1.2.1] – 2026-04-28
- Sandbox: Abbrechen-Button für laufende Backtest-Jobs
- Redesign

## [1.2.0] – 2026-04-28
- Neuer Tab "Lab" mit Sandbox (Parameter-Backtest) und Earnings-Kalender (14 Tage)
- Sandbox: asynchrones Job-Polling, Baseline-Vergleich, clientseitige Aggregation

## [1.1.1] – 2026-04-27
- Trigger-Run: nach Verkauf kann noch am gleichen Tag ein neuer Run gestartet werden
- Post-Sell-Dialog + Lockfile-Logik

## [1.0.2] – 2026-04-26
- Auth-Header auf alle GET-Endpoints ergänzt (Fix stille 401-Fehler)
- Rate Limiting + CORS auf Cloudflare-Domain eingeschränkt

## [1.0.1] – 2026-04-24
- Fix: Chart-Overlay in Shortlist (Höhe/Rendering)

## [0.8.4] – 2026-04-23
- Pi-Shutdown-Button im System-Screen
- Chart in Position Detail (Candlestick + EMA20/50 + Entry/Stop-Overlays)
- Fix Position Detail: fehlende Felder

## [0.8.3] – 2026-04-22
- Verbindung auf Cloudflare Tunnel umgestellt (kein Tailscale mehr nötig)
- JWT Bearer Auth: Login-Screen, flutter_secure_storage, Auto-Refresh

## [0.8.2] – 2026-04-22
- Charts V2 in Shortlist: Lightweight Charts (Candlestick + EMA20/50)
- Fix: FCM-Topic-Toggles funktional

## [0.8.1] – 2026-04-20
- Fix: Claude-Bewertung fehlte in Shortlist-Card
- BoughtSheet: Trade-Parameter vorausgefüllt
- Nach Kauf: Kandidaten-Card wird durch "Gekauft"-Card ersetzt

## [0.8.0] – 2026-04-18
- FCM Push Notifications: HARD/WARN/CANDIDATES Events, Deep Links

## [0.7.2] – 2026-04-17
- Fix: Shortlist-Darstellung wenn Pass 2 alle Kandidaten filtert

## [0.7.1] – 2026-04-16
- Run-Log Detail Screen im System-Tab

## [0.7.0] – 2026-04-13
- Kaufen/Verkaufen/Skippen Actions implementiert (BoughtSheet, SoldSheet)
- Service Health Anzeige im System-Screen

## [0.6.1] – 2026-04-08
- Fix: Shortlist-Darstellung bei fehlendem Budget
- Offene Position erhält Kurs aus letztem Run

## [0.6.0] – 2026-04-08
- Alle Screens gegen echte FastAPI verbunden (Tailscale)
- Offline-Cache via CacheService (SharedPreferences)
- OfflineBanner + PauseBanner

## [0.5.1] – 2026-04-08
- Flutter auf echte API umgestellt, Key-Mismatches gefixt

## [0.5.0] – 2026-04-08
- Live-Betrieb gestartet (erste echte Position ROST)
- Grundstruktur: Dashboard, Shortlist, History, System, Position Detail
- KestrelNav InheritedWidget, IndexedStack Navigation