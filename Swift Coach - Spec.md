# Swift Coach — Spécification produit

> App d'apprentissage et d'entraînement Swift pilotée par un LLM coach.
> L'utilisateur demande un exercice par thématique, code dans un éditeur sombre, compile, et reçoit un feedback détaillé (annotations + chat) du coach.

---

## 1. Vision

Un environnement **léger, focalisé, IDE-like** où un développeur Swift intermédiaire peut :

1. Demander au coach LLM un exercice sur une thématique précise (dictionnaires, optionals, async/await, protocols, tri, etc.).
2. Lire un énoncé clair avec exemples et contraintes.
3. Coder sa solution Swift avec coloration syntaxique.
4. Compiler et exécuter son code (retour console).
5. Recevoir **deux types de feedback complémentaires** : annotations ligne-par-ligne dans le code et un chat conversationnel pour creuser.
6. Demander des indices progressifs quand il est bloqué.
7. Enchaîner les exercices dans la même session de coaching.

Cible : **développeurs Swift intermédiaires** qui veulent s'entraîner seuls avec un coach patient, exigeant sur le style, et disponible sur desktop comme mobile (trajets, pauses café).

---

## 2. Direction esthétique

- **IDE classique sombre original** — inspiration Xcode, mais identité propre (pas un clone).
- Palette base bleu-noir profond : `#0d0d12` → `#16161c` → `#1c1c24` → `#22222c`.
- Accents en `oklch()` avec une chroma/lightness cohérente sur toute la palette :
  - Ambre chaud (accent principal) : `oklch(0.72 0.14 35)`
  - Cyan : `oklch(0.75 0.14 200)`
  - Magenta : `oklch(0.72 0.16 320)`
  - Vert (succès) : `oklch(0.78 0.14 140)`
  - Rouge (erreur) : `oklch(0.68 0.2 25)`
- Type : **Inter** pour l'UI, **JetBrains Mono** pour l'éditeur et la console.
- Densité modérée, coins arrondis 8–14px, bordures fines `#262630` / `#32323f`.

---

## 3. Architecture produit

### 3.1 Deux shells

| Shell | Layout | Cas d'usage |
|---|---|---|
| **Desktop** | 3 colonnes : sidebar chat (300px) · éditeur central (flex) · panneau feedback (360px) | session longue, clavier physique, focus |
| **Mobile** | Stack vertical : header · énoncé déployable · éditeur · barre Swift · clavier · bottom-sheet feedback | review rapide, pratique en mobilité |

### 3.2 Modèle d'état

Un exercice en cours a toujours un **état de revue** parmi :

- `writing` — l'utilisateur écrit son code, pas encore de compilation.
- `idle` — identique, à l'ouverture de l'exercice.
- `error` — build échoué, au moins une annotation `error`.
- `success` — build ok + remarques non bloquantes (`praise`, `nit`, `suggestion`).
- `resolved` — tous les tests passent, pas de remarque, prêt à passer au suivant.
- `hint` — l'utilisateur a cliqué « indice », panneau d'indices progressifs visible.

Chaque état définit : `code`, `annotations[]`, `consoleLines[]`, message de synthèse du coach.

### 3.3 Annotations LLM

Chaque annotation porte :

- `line` — numéro de ligne (1-indexé) dans le buffer courant.
- `kind` — `error` | `praise` | `nit` | `suggestion`.
- `title` — titre court (ex : « Cas limite »).
- `body` — texte markdown léger (gras + code inline).

Rendues de 3 manières (au choix via Tweaks) :

- **gutter** — pastille de couleur dans la gouttière, corps affiché côté panneau.
- **inline** — encart collé juste sous la ligne concernée, border-left de couleur.
- **margin** — sticky flottant en marge droite de l'éditeur.

---

## 4. Features — Desktop

### 4.1 Sidebar gauche — Coach chat
- En-tête avec avatar gradient + indicateur présence (pastille verte).
- Historique de conversation avec bulles `user` / `coach`, markdown léger (`**gras**`, `` `code` ``).
- **Suggestions de thématiques** en slash-commands quand l'utilisateur est en `writing` : Dictionnaires, Optionals, Protocols, async/await, Tri & recherche. Cliquables.
- **Composer** bas : textarea + bouton envoi, raccourcis `⌘↵` envoyer, `/` thèmes.
- Envoi d'un thème → nouveau message user + réponse coach mockée, nouvel exercice chargé (à câbler côté API réelle).

### 4.2 Colonne centrale — Énoncé + éditeur + console

**Carte énoncé** (haut de la colonne) :
- Pills métadonnées : topic (ambre), difficulté (cyan), id (mono).
- Titre de l'exercice.
- Description markdown.
- Liste **contraintes** (mono, chevron `›` ambre).
- **Exemples** en cartes mono : `in`, `out`, note optionnelle.

**Éditeur** :
- Tab bar avec indicateur actif (barre haute ambre) + nom du fichier `.swift`.
- Gouttière numérotée, lignes à erreur surlignées en rouge translucide.
- Coloration syntaxique Swift (keywords, types, fonctions, strings, numbers, commentaires, ops).
- Rendu des annotations selon le style Tweak choisi.
- **Action bar** bas : bouton `▶ Compiler & exécuter`, bouton `Demander un indice`, indicateurs Ln/Col, nb lignes, état du build.

**Console** (sous l'éditeur, hauteur 160px) :
- En-tête `CONSOLE · swift-driver 5.10` + action `clear`.
- Lignes typées : `cmd` (prompt `$` ambre), `out` (neutre), `err` (rouge), `ok` (vert).

### 4.3 Panneau feedback (droite — position par défaut)

- **Header** : pill de statut (tone selon state), message de synthèse humain.
- **Tabs** :
  - `Revue` (avec badge nombre d'annotations) : liste de cards par annotation, couleurs selon kind, numéro de ligne `L#` en mono.
  - `Chat` : mini-thread contextuel au state actuel (quand l'état change, de nouvelles répliques du coach apparaissent).
- Si `state === "hint"` : encart indices progressifs numérotés.
- Position alternative via Tweak : **bottom** (panneau horizontal bas) ou **overlay** (card flottante top-right, glass effect).

---

## 5. Features — Mobile

### 5.1 Frame iPhone-like
- Châssis arrondi `390×844`, dynamic island mockée, bezel gradient.
- StatusBar : heure 9:41, réseau, 5G, icône batterie.

### 5.2 Header
- Back button, titre exercice, metadata mono (`Algorithmes · intermédiaire`), bouton **indice** pill ambre.

### 5.3 Énoncé déployable
- Section réductible (toggle « déployer / réduire »), pill ambre `ÉNONCÉ`.
- Brief + exemple mono compact.

### 5.4 Éditeur mobile
- Bandeau avec nom de fichier + compteur lignes + bouton **▶ RUN** ambre compact.
- Rendu code identique (font-size 11px, line-height 18px), annotations inline condensées.
- Pastille colorée dans la gouttière par ligne annotée.

### 5.5 Barre d'outils Swift custom (au-dessus du clavier)
- Scroll horizontal de touches **spécifiques à Swift** : `tab`, `{`, `}`, `(`, `)`, `[`, `]`, `->`, `let`, `var`, `func`, `:`, `,`, `?`, `!`, `"`.
- Chaque touche insère le token à la fin du buffer (mock — à brancher sur un vrai caret pour prod).

### 5.6 Clavier système mock
- QWERTY sombre type iOS, 3 rangées de lettres + ligne système (`123`, 🌐, `space`, `↵` ambre).
- Home indicator blanc en bas.

### 5.7 Bottom sheet feedback
- Fermée : bande 56px en bas avec icône d'état coloré + label (`Build OK · 3 remarques`, `Build échoué`, …).
- Ouverte : remonte à 70% de hauteur, même liste de cards que le panneau desktop.
- S'ouvre automatiquement quand le state passe en `error` / `success` / `resolved` / `hint`.

---

## 6. Tweaks (panneau bottom-right, toggle via host)

| Clé | Valeurs | Effet |
|---|---|---|
| `annotationStyle` | `gutter` \| `inline` \| `margin` | Style d'affichage des annotations LLM dans l'éditeur |
| `feedbackPosition` | `right` \| `bottom` \| `overlay` | Emplacement du panneau feedback (desktop uniquement) |

Les changements sont persistés via `postMessage({type: "__edit_mode_set_keys"})` → le bloc JSON `EDITMODE-BEGIN/END` dans `Swift Coach.html` est réécrit côté hôte.

---

## 7. Highlighter Swift

Tokenizer maison (`src/highlight.jsx`) couvrant :

- **Keywords** : `func`, `var`, `let`, `return`, `if`, `else`, `for`, `in`, `while`, `guard`, `switch`, `case`, `default`, `struct`, `class`, `enum`, `protocol`, `extension`, `import`, `public`, `private`, `internal`, `fileprivate`, `static`, `final`, `init`, `self`, `Self`, `throws`, `throw`, `try`, `as`, `is`, `nil`, `true`, `false`, `async`, `await`, `do`, `catch`, `defer`, `break`, `continue`, `where`, `typealias`, `inout`, `mutating`.
- **Types** built-in : `Int`, `String`, `Double`, `Float`, `Bool`, `Array`, `Dictionary`, `Set`, `Any`, `AnyObject`, `Void`, `Character`, `Optional` + tout identifier capitalisé.
- **Fonctions** : détection heuristique `identifier(` → classe `tk-fn`.
- **Strings** : double-quote + échappement `\`.
- **Nombres** : entiers, décimaux, underscore séparateur.
- **Commentaires** : `//` jusqu'à fin de ligne.
- **Opérateurs / ponctuation** séparés.

Sortie : un tableau de chaînes HTML, une par ligne source, avec spans `.tk-*`.

---

## 8. Stack technique

- **Entrée unique** : `Swift Coach.html` charge React 18.3.1 + Babel standalone + Google Fonts, puis 5 scripts `type="text/babel"`.
- **Modules JSX** (dans `src/`) exposent leurs composants sur `window` (pas d'ES modules — contrainte Babel standalone) :
  - `data.jsx` → `window.APP_DATA`
  - `highlight.jsx` → `window.highlightSwift`, `window.highlightLines`
  - `desktop.jsx` → `window.Desktop`
  - `mobile.jsx` → `window.Mobile`, `window.tintMob`, `window.formatMdMobile`
  - `app.jsx` → monte `<App>` dans `#root`
- **Persistance** : `localStorage` pour shell courant (`sc.shell`) et state démo (`sc.state`).
- **Communication hôte** via `window.postMessage` pour activer/désactiver le mode Tweaks et persister les valeurs.

---

## 9. Fonctionnalités à câbler pour la prod

| # | Feature | Notes |
|---|---|---|
| 1 | Appel LLM réel pour générer un exercice sur un thème | `window.claude.complete` ou backend ; prompt structuré retournant `{brief, constraints, examples, starter, tests}` |
| 2 | Appel LLM pour la revue après compilation | Donner code + sortie compilateur ; retourne `annotations[]` structurées |
| 3 | Compilation Swift serveur | Sandbox distant (Docker / wasm Swift) ; stream stdout/stderr |
| 4 | Éditeur saisissable réel | Remplacer `<pre>` par CodeMirror / Monaco en mode Swift, brancher sur un state contrôlé |
| 5 | Saisie mobile | Relier toolbar Swift + clavier système à un vrai caret dans l'éditeur |
| 6 | Historique de session | Sauvegarder chaque exercice + tentatives + feedbacks (Supabase / SQLite) |
| 7 | Auth utilisateur | Pour reprendre la session sur desktop ↔ mobile |
| 8 | Indices progressifs « à la demande » | Chaque clic révèle un indice suivant ; coût de score visible |
| 9 | Système de progression | Stats par thématique, niveau, streak |
| 10 | Mode solution | Le coach propose un diff vers une solution idiomatique après résolution |

---

## 10. Copy & ton

- Français familier-pro, tutoiement (« tu »).
- Le coach est **exigeant mais bienveillant** : félicite quand c'est propre, pointe les nits, suggère des pistes d'amélioration sans imposer.
- Évite le jargon inutile, préfère des formulations concrètes ancrées dans le code de l'utilisateur.
- Markdown léger autorisé dans les bulles et annotations : `**gras**` et `` `code` ``.

---

## 11. États de démonstration livrés dans le proto

| State | Scénario Swift |
|---|---|
| `writing` | Squelette Two Sum, curseur utilisateur, pas de revue |
| `hint` | Code inchangé, panneau indices 3 niveaux |
| `error` | Two Sum avec `if let` sans `{` → erreur parse ligne 5 |
| `success` | Two Sum correct mais nommages trop courts → 3 remarques (praise + nit + suggestion) |
| `resolved` | Two Sum refactoré, asserts passés, prêt pour exo suivant |
