# gymapplogbook — note per Claude

## ⚠️ REGOLA CRITICA: il QR pubblico
- Il QR distribuito a **migliaia di persone** punta a
  **`https://rdagmr98.github.io/gymapplogbook/download.html`** → questo file **deve esistere SEMPRE**.
- È una landing che reindirizza in base al dispositivo: Android → Google Play
  (`com.gianmarco.gym_app`), iOS → `https://rdagmr98.github.io/GymApp/`, desktop → 2 pulsanti.
- **La sorgente è `web/download.html`** (su `main`). Flutter copia tutto ciò che sta in `web/`
  dentro `build/web/` ad ogni build, quindi il deploy lo include automaticamente.
- ❌ NON cancellare/rinominare `web/download.html`.
- ❌ NON rinominare la repo o cambiare l'URL Pages (romperebbe il QR già stampato).

## Deploy (come funziona)
- Push su `main` → workflow `.github/workflows/web-deploy.yml` →
  `flutter build web --base-href "/gymapplogbook/" --release` →
  deploy di `build/web` su `gh-pages` (peaceiris/actions-gh-pages) → live su GitHub Pages.
- ⚠️ Ogni deploy **rigenera da zero** `gh-pages`: per questo i file vanno tenuti in sorgente (`web/`),
  non aggiunti a mano su `gh-pages` (verrebbero cancellati al primo rebuild).
- Verifica post-deploy: aprire `https://rdagmr98.github.io/gymapplogbook/download.html` (deve dare 200).
- Pages è ora su build type **`legacy`** (serve i file statici di `gh-pages` grazie al `.nojekyll`).
  Motivo: col tipo "workflow" il push di peaceiris (fatto con `GITHUB_TOKEN`) **non** innescava il deploy sul CDN
  (regola GitHub: i push con `GITHUB_TOKEN` non fanno partire altri workflow) → i deploy restavano bloccati.
  Con `legacy` ogni push su `gh-pages` ripubblica in automatico. Per forzare a mano:
  `gh api -X POST repos/rdagmr98/gymapplogbook/pages/builds`.

## Storico
- **2026-06-17**: il commit `ef2490a` (rebuild app v1.0.5+3002) ha rigenerato `gh-pages`
  cancellando `download.html`, che prima viveva solo su `gh-pages` (non in sorgente) → QR in 404.
  Risolto spostando il file in `web/download.html` (commit `11737d9`), così è incluso in ogni build.
  Inoltre Pages è stato portato da build type "workflow" a **"legacy"** perché i deploy via peaceiris
  (push con `GITHUB_TOKEN`) non si pubblicavano più sul CDN.
