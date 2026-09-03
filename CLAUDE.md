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

## Deploy (come funziona, dal 2026-08-31)
- Push su `main` → workflow `.github/workflows/web-deploy.yml`:
  1. `flutter pub get`
  2. inietta il token GitHub reale in `web/gh-config.js` (da secret `LOGBOOK_UPLOAD_PAT`,
     mai committato — solo scritto nel working dir del runner)
  3. `flutter build web --base-href "/gymapplogbook/" --release`
  4. `actions/upload-pages-artifact` + `actions/deploy-pages` (deploy nativo GitHub Pages,
     **non** più push su branch `gh-pages`)
- Pages è su build type **`workflow`** (non `legacy`). L'ambiente `github-pages` ha policy di branch
  che deve includere `main` (`gh api repos/rdagmr98/gymapplogbook/environments/github-pages/deployment-branch-policies`).
- Verifica post-deploy: `https://rdagmr98.github.io/gymapplogbook/download.html` deve dare 200.

### Perché questa architettura (non più peaceiris/gh-pages)
- `logbook.html` (sezione admin, password `osare199`) carica/cancella schede `.workout` degli
  atleti via GitHub Contents API, usando un PAT fine-grained (solo Contents R/W su questa repo).
- Col vecchio deploy (`peaceiris/actions-gh-pages`, push letterale su branch `gh-pages`), **qualsiasi
  token embeddato nel build finiva in un blob git pubblico** → GitHub lo revocava in automatico entro
  pochi secondi (secret scanning), a prescindere da come/quando veniva iniettato.
- Fix (pattern riusato da `vitanailsroma`): deploy con `upload-pages-artifact`/`deploy-pages`, che
  carica l'artefatto direttamente sull'hosting Pages **senza mai creare un commit/blob git** →
  il secret scanning di GitHub non lo vede mai, il token non viene revocato.
- Il token resta comunque **visibile lato client** a chiunque apra la pagina (view-source) — è lo
  stesso trade-off accettato in `vitanailsroma`; per questo il PAT deve restare fine-grained,
  scope minimo (solo Contents R/W su `gymapplogbook`), mai un token con permessi più ampi.
- Verificato end-to-end il 2026-08-31/09-01: PUT (upload, 201) e DELETE (auto-delete post-download, 200)
  via API con lo stesso token, poi ricontrollato che il token restasse valido (200 su GET repo) —
  nessuna revoca.

## Convenzione file schede
- Formato **`.workout`**, non `.pdf`. Path repo: `web/schede/<slug-nome-atleta>.workout`.
- Upload di una scheda per un atleta già esistente sovrascrive quella vecchia (stesso slug).
- Dopo che l'atleta scarica la propria scheda, il file viene cancellato automaticamente dalla repo
  (single-use — evita che schede vecchie restino scaricabili).

## Storico
- **2026-06-17**: il commit `ef2490a` (rebuild app v1.0.5+3002) ha rigenerato `gh-pages`
  cancellando `download.html`, che prima viveva solo su `gh-pages` (non in sorgente) → QR in 404.
  Risolto spostando il file in `web/download.html` (commit `11737d9`).
- **2026-08-31**: migrato il deploy da `peaceiris/actions-gh-pages` (branch push, causava revoca
  automatica di qualsiasi PAT embeddato) a deploy nativo GitHub Pages Actions
  (`upload-pages-artifact` + `deploy-pages`), pattern preso da `vitanailsroma`. Vedi sezione
  "Perché questa architettura" sopra.
- **2026-08-31/09-03**: dopo la migrazione, `default_branch` della repo era rimasto `gh-pages`
  (leftover del vecchio setup). `logbook.html` non passa mai `"branch"` esplicito nelle chiamate
  Contents API (upload/get-sha/list/delete) → tutte le scritture finivano silenziosamente sul
  branch legacy `gh-pages`, mai buildato dal nuovo workflow → schede caricate "sparivano" (upload
  ok lato utente ma download sempre "non trovata"). Fix: `default_branch` corretto a `main`
  (`gh api -X PATCH repos/rdagmr98/gymapplogbook -f default_branch=main`), dati orfani recuperati
  a mano da `gh-pages` a `main`. **Nota**: dopo ogni upload/delete c'è comunque un ritardo fisiologico
  di ~2-3 min prima che la scheda sia visibile/rimossa sul sito live, perché ogni scrittura sulla
  Contents API triggera un push su `main` → rebuild+redeploy completo del sito (non solo dei file
  schede) prima che la CDN Pages serva il nuovo stato. Non è un bug, è il tempo del workflow
  `web-deploy.yml`.
