# Swift Coach — Prototype export

A dark-IDE Swift learning prototype with desktop + mobile shells, an LLM coach panel, annotated code review, and tweakable layouts.

## Stack
- Single HTML entry (`Swift Coach.html`) loading React 18.3.1 + Babel standalone via CDN.
- Five JSX modules in `src/` attached as `<script type="text/babel">`, communicating via `window.*` globals (no ES modules).
- Fonts: Inter (UI), JetBrains Mono (editor). Loaded from Google Fonts.
- State: local React state + `localStorage` for shell (desktop/mobile) and demo state.

## Features
- **Desktop shell**: 3-column — coach chat sidebar, code editor + console, feedback panel.
- **Mobile shell**: stacked brief + editor + bottom-sheet feedback, with a custom Swift toolbar above a mock iOS keyboard.
- **Demo states** (commutable via top-right select): `writing`, `hint`, `error`, `success`, `resolved`. Each swaps the code buffer, annotations, and console output.
- **Tweaks** (bottom-right panel, toggled by host `__activate_edit_mode` message):
  - `annotationStyle`: `gutter` | `inline` | `margin`
  - `feedbackPosition`: `right` | `bottom` | `overlay` (desktop only)
- **Mock Swift syntax highlighter** (`src/highlight.jsx`) — keyword / type / function-call / string / number / comment / op tokens.

## File layout
```
Swift Coach.html       # entry
src/
  data.jsx             # mock exercise, code buffers, annotations, console lines, chat thread
  highlight.jsx        # Swift tokenizer → HTML spans (.tk-kw, .tk-type, ...)
  desktop.jsx          # window.Desktop — sidebar + editor + console + feedback panel
  mobile.jsx           # window.Mobile — iPhone frame + brief + editor + bottom sheet + keyboard
  app.jsx              # shell switch, state machine, tweaks panel, render root
```

---

## `Swift Coach.html`

```html
<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Swift Coach — Prototype</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600;700&display=swap">
<style>
  :root {
    --bg: #16161c;
    --bg-2: #1c1c24;
    --bg-3: #22222c;
    --bg-4: #2a2a36;
    --line: #32323f;
    --line-soft: #262630;
    --ink: #e8e8ee;
    --ink-2: #b4b4c2;
    --ink-3: #75758a;
    --ink-4: #4a4a5a;

    --accent: oklch(0.72 0.14 35);        /* ambre chaud */
    --accent-2: oklch(0.75 0.14 200);     /* cyan */
    --accent-3: oklch(0.72 0.16 320);     /* magenta */
    --accent-4: oklch(0.78 0.14 140);     /* vert */
    --accent-5: oklch(0.78 0.14 80);      /* jaune */

    --danger: oklch(0.68 0.2 25);
    --ok: oklch(0.72 0.17 150);

    --mono: "JetBrains Mono", ui-monospace, SFMono-Regular, Menlo, monospace;
    --ui: "Inter", system-ui, -apple-system, sans-serif;
  }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; background: #0d0d12; color: var(--ink); font-family: var(--ui); -webkit-font-smoothing: antialiased; }
  body { min-height: 100vh; overflow-x: hidden; }

  /* Scrollbars */
  ::-webkit-scrollbar { width: 10px; height: 10px; }
  ::-webkit-scrollbar-track { background: transparent; }
  ::-webkit-scrollbar-thumb { background: #2a2a36; border-radius: 10px; border: 2px solid transparent; background-clip: padding-box; }
  ::-webkit-scrollbar-thumb:hover { background: #3a3a46; border: 2px solid transparent; background-clip: padding-box; }

  button { font-family: inherit; }

  /* Shell toggler */
  .shell-switch {
    position: fixed; bottom: 16px; left: 16px;
    z-index: 9999;
    background: rgba(22,22,28,.92); backdrop-filter: blur(14px);
    border: 1px solid var(--line); border-radius: 999px;
    padding: 4px; display: inline-flex; gap: 2px; align-items: center;
    font-size: 12px; letter-spacing: 0.02em;
    box-shadow: 0 10px 30px rgba(0,0,0,.4);
  }
  .shell-switch button {
    background: transparent; border: 0; color: var(--ink-2);
    padding: 6px 14px; border-radius: 999px; cursor: pointer;
    font-weight: 500; font-family: var(--ui);
  }
  .shell-switch button.active { background: var(--ink); color: #111; }

  /* Tweaks panel */
  .tweaks {
    position: fixed; right: 16px; bottom: 16px; z-index: 9998;
    max-height: calc(100vh - 40px); overflow: auto;
    width: 280px;
    background: rgba(22,22,28,.92); backdrop-filter: blur(18px);
    border: 1px solid var(--line); border-radius: 14px;
    padding: 14px 16px 16px;
    font-size: 12px;
    box-shadow: 0 20px 60px rgba(0,0,0,.45);
    display: none;
  }
  .tweaks.open { display: block; }
  .tweaks h4 { margin: 0 0 10px; font-size: 11px; letter-spacing: 0.14em; text-transform: uppercase; color: var(--ink-3); font-weight: 600; }
  .tweaks .row { margin-bottom: 12px; }
  .tweaks .row:last-child { margin-bottom: 0; }
  .tweaks label.title { display: block; font-size: 11px; color: var(--ink-2); margin-bottom: 6px; font-weight: 500; }
  .tweaks .seg { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 2px; background: var(--bg); border: 1px solid var(--line); border-radius: 8px; padding: 2px; }
  .tweaks .seg button { background: transparent; color: var(--ink-2); border: 0; padding: 7px 6px; border-radius: 6px; cursor: pointer; font-size: 11px; }
  .tweaks .seg button.active { background: var(--bg-4); color: var(--ink); }

  #root { min-height: 100vh; }
</style>
</head>
<body>
<div id="root"></div>

<script type="application/json" id="tweak-defaults">
/*EDITMODE-BEGIN*/{
  "annotationStyle": "inline",
  "feedbackPosition": "right"
}/*EDITMODE-END*/
</script>

<script src="https://unpkg.com/react@18.3.1/umd/react.development.js" integrity="sha384-hD6/rw4ppMLGNu3tX5cjIb+uRZ7UkRJ6BPkLpg4hAu/6onKUg4lLsHAs9EBPT82L" crossorigin="anonymous"></script>
<script src="https://unpkg.com/react-dom@18.3.1/umd/react-dom.development.js" integrity="sha384-u6aeetuaXnQ38mYT8rp6sbXaQe3NL9t+IBXmnYxwkUI2Hw4bsp2Wvmx4yRQF1uAm" crossorigin="anonymous"></script>
<script src="https://unpkg.com/@babel/standalone@7.29.0/babel.min.js" integrity="sha384-m08KidiNqLdpJqLq95G/LEi8Qvjl/xUYll3QILypMoQ65QorJ9Lvtp2RXYGBFj1y" crossorigin="anonymous"></script>

<script type="text/babel" src="src/data.jsx"></script>
<script type="text/babel" src="src/highlight.jsx"></script>
<script type="text/babel" src="src/desktop.jsx"></script>
<script type="text/babel" src="src/mobile.jsx"></script>
<script type="text/babel" src="src/app.jsx"></script>
</body>
</html>

```

## `src/data.jsx`

```jsx
// Données mockées pour le prototype

const EXERCISE = {
  id: "twosum",
  topic: "Algorithmes",
  difficulty: "Intermédiaire",
  title: "Two Sum — version Swifty",
  brief: "Étant donné un tableau d'entiers `nums` et un entier `target`, retourne les indices des deux nombres dont la somme vaut `target`. Tu peux supposer qu'il existe exactement une solution, et tu ne peux pas utiliser le même élément deux fois.",
  constraints: [
    "2 ≤ nums.count ≤ 10⁴",
    "−10⁹ ≤ nums[i] ≤ 10⁹",
    "Solution en O(n) attendue",
  ],
  examples: [
    { input: "nums = [2, 7, 11, 15], target = 9", output: "[0, 1]", note: "nums[0] + nums[1] == 9" },
    { input: "nums = [3, 2, 4], target = 6", output: "[1, 2]" },
  ],
  signature: "func twoSum(_ nums: [Int], _ target: Int) -> [Int]",
};

const STARTER_CODE = `func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
    var seen: [Int: Int] = [:]
    for (i, n) in nums.enumerated() {
        let complement = target - n
        if let j = seen[complement] {
            return [j, i]
        }
        seen[n] = i
    }
    return []
}

let result = twoSum([2, 7, 11, 15], 9)
print(result)`;

const CODE_WITH_ERROR = `func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
    var seen: [Int: Int] = [:]
    for (i, n) in nums.enumerated() {
        let complement = target - n
        if let j = seen[complement]
            return [j, i]
        }
        seen[n] = i
    }
    return []
}

let result = twoSum([2, 7, 11, 15], 9)
print(result)`;

const CODE_RESOLVED = `func twoSum(_ nums: [Int], _ target: Int) -> [Int] {
    var indexByValue: [Int: Int] = [:]
    for (index, value) in nums.enumerated() {
        let complement = target - value
        if let matchIndex = indexByValue[complement] {
            return [matchIndex, index]
        }
        indexByValue[value] = index
    }
    return []
}

// Vérification rapide
assert(twoSum([2, 7, 11, 15], 9) == [0, 1])
assert(twoSum([3, 2, 4], 6) == [1, 2])
print("✓ tous les cas passent")`;

// Annotations par ligne (1-indexed) selon l'état
const ANNOTATIONS_SUCCESS = [
  {
    line: 2,
    kind: "praise",
    title: "Bon choix de structure",
    body: "Un dictionnaire pour mémoriser `valeur → index` donne bien du O(n). C'est la solution canonique.",
  },
  {
    line: 4,
    kind: "nit",
    title: "Nommage",
    body: "`complement` est clair. `n` et `i` sont un peu trop abrégés — `value`, `index` rendraient le code plus lisible à la relecture.",
  },
  {
    line: 10,
    kind: "suggestion",
    title: "Cas limite",
    body: "Que retourner si aucun couple n'existe ? `[]` est acceptable mais un `[Int]?` (optionnel) communiquerait mieux l'absence.",
  },
];

const ANNOTATIONS_ERROR = [
  {
    line: 5,
    kind: "error",
    title: "Accolade manquante",
    body: "`if let j = seen[complement]` ouvre un bloc conditionnel mais il manque le `{`. Swift attend un bloc après la condition.",
  },
];

const CONSOLE_SUCCESS = [
  { kind: "cmd", text: "swift run twosum.swift" },
  { kind: "out", text: "Compiling twosum.swift…" },
  { kind: "out", text: "Build complete! (0.42s)" },
  { kind: "out", text: "[0, 1]" },
  { kind: "ok",  text: "Process exited with code 0" },
];

const CONSOLE_ERROR = [
  { kind: "cmd", text: "swift run twosum.swift" },
  { kind: "out", text: "Compiling twosum.swift…" },
  { kind: "err", text: "twosum.swift:5:38: error: expected '{' after 'if' condition" },
  { kind: "err", text: "        if let j = seen[complement]" },
  { kind: "err", text: "                                     ^" },
  { kind: "err", text: "Build failed (1 error)" },
];

const CONSOLE_RESOLVED = [
  { kind: "cmd", text: "swift run twosum.swift" },
  { kind: "out", text: "Compiling twosum.swift…" },
  { kind: "out", text: "Build complete! (0.38s)" },
  { kind: "out", text: "✓ tous les cas passent" },
  { kind: "ok",  text: "Process exited with code 0" },
];

const CHAT_THREAD = [
  {
    who: "user",
    text: "Je veux un exo swift intermédiaire sur les dictionnaires.",
    time: "14:02",
  },
  {
    who: "coach",
    text: "Parfait. Je te propose **Two Sum** version Swifty : un classique d'entretien qui met en valeur l'usage efficace de `[Int: Int]` pour passer de O(n²) à O(n). J'ai chargé l'énoncé dans le panneau de gauche et un squelette dans l'éditeur.",
    time: "14:02",
  },
  {
    who: "user",
    text: "Ok j'attaque.",
    time: "14:03",
  },
];

const HINTS = [
  "Pense à ce que tu veux **retrouver rapidement** pendant le parcours du tableau : pour chaque `n`, tu cherches `target − n`.",
  "Un `Dictionary<Int, Int>` te donne une recherche en O(1) moyen. Clé : la valeur déjà vue. Valeur : son index.",
  "Parcours `nums.enumerated()`. À chaque itération : si le complément existe déjà dans le dico → retourne les deux indices. Sinon, stocke l'élément courant.",
];

window.APP_DATA = {
  EXERCISE,
  STARTER_CODE,
  CODE_WITH_ERROR,
  CODE_RESOLVED,
  ANNOTATIONS_SUCCESS,
  ANNOTATIONS_ERROR,
  CONSOLE_SUCCESS,
  CONSOLE_ERROR,
  CONSOLE_RESOLVED,
  CHAT_THREAD,
  HINTS,
};

```

## `src/highlight.jsx`

```jsx
// Petit highlighter Swift — assez pour un proto crédible

const SWIFT_KEYWORDS = new Set([
  "func","var","let","return","if","else","for","in","while","guard","switch","case","default",
  "struct","class","enum","protocol","extension","import","public","private","internal","fileprivate",
  "static","final","init","self","Self","throws","throw","try","as","is","nil","true","false",
  "async","await","do","catch","defer","break","continue","where","typealias","inout","mutating"
]);

const SWIFT_TYPES = new Set([
  "Int","String","Double","Float","Bool","Array","Dictionary","Set","Any","AnyObject","Void","Character","Optional"
]);

function escapeHtml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function highlightSwift(src) {
  // Tokenize naïvement mais correctement pour nos besoins
  // 1) on remplace chaînes et commentaires en premier avec placeholders, puis on colorie le reste
  const tokens = [];
  let i = 0;
  while (i < src.length) {
    const c = src[i];
    // line comment
    if (c === "/" && src[i+1] === "/") {
      let j = src.indexOf("\n", i);
      if (j === -1) j = src.length;
      tokens.push({ t: "cm", v: src.slice(i, j) });
      i = j;
      continue;
    }
    // string
    if (c === '"') {
      let j = i + 1;
      while (j < src.length && src[j] !== '"') {
        if (src[j] === "\\" && j + 1 < src.length) j += 2;
        else j++;
      }
      j = Math.min(j + 1, src.length);
      tokens.push({ t: "str", v: src.slice(i, j) });
      i = j;
      continue;
    }
    // number
    if (/\d/.test(c)) {
      let j = i + 1;
      while (j < src.length && /[\d_.]/.test(src[j])) j++;
      tokens.push({ t: "num", v: src.slice(i, j) });
      i = j;
      continue;
    }
    // identifier
    if (/[A-Za-z_]/.test(c)) {
      let j = i + 1;
      while (j < src.length && /[A-Za-z0-9_]/.test(src[j])) j++;
      const word = src.slice(i, j);
      let t = "id";
      if (SWIFT_KEYWORDS.has(word)) t = "kw";
      else if (SWIFT_TYPES.has(word)) t = "type";
      else if (/^[A-Z]/.test(word)) t = "type";
      // function call detection
      else if (src[j] === "(") t = "fn";
      tokens.push({ t, v: word });
      i = j;
      continue;
    }
    // operators & punctuation
    if (/[+\-*/%=<>!&|^~?:]/.test(c)) {
      let j = i + 1;
      while (j < src.length && /[+\-*/%=<>!&|^~?:]/.test(src[j])) j++;
      tokens.push({ t: "op", v: src.slice(i, j) });
      i = j;
      continue;
    }
    // punctuation
    if (/[{}()\[\],.;]/.test(c)) {
      tokens.push({ t: "punct", v: c });
      i++;
      continue;
    }
    // whitespace / default
    tokens.push({ t: "ws", v: c });
    i++;
  }

  return tokens.map(tok => {
    const v = escapeHtml(tok.v);
    switch (tok.t) {
      case "kw": return `<span class="tk-kw">${v}</span>`;
      case "type": return `<span class="tk-type">${v}</span>`;
      case "fn": return `<span class="tk-fn">${v}</span>`;
      case "str": return `<span class="tk-str">${v}</span>`;
      case "num": return `<span class="tk-num">${v}</span>`;
      case "cm": return `<span class="tk-cm">${v}</span>`;
      case "op": return `<span class="tk-op">${v}</span>`;
      case "punct": return `<span class="tk-punct">${v}</span>`;
      default: return v;
    }
  }).join("");
}

// Split par ligne en préservant le highlight ligne par ligne
function highlightLines(src) {
  return src.split("\n").map(line => highlightSwift(line));
}

window.highlightSwift = highlightSwift;
window.highlightLines = highlightLines;

```

## `src/desktop.jsx`

```jsx
// Desktop — sidebar chat | éditeur sombre | feedback

const { useState, useEffect, useRef, useMemo } = React;

// ---------- petits helpers ----------

function Avatar({ who }) {
  const initials = who === "coach" ? "SC" : "ME";
  const bg = who === "coach" ? "linear-gradient(135deg, oklch(0.72 0.14 35), oklch(0.72 0.16 320))" : "#32323f";
  return (
    <div style={{
      width: 24, height: 24, borderRadius: 6,
      background: bg, color: "#111", fontSize: 10, fontWeight: 700,
      display: "grid", placeItems: "center",
      fontFamily: "var(--mono)", letterSpacing: "0.02em",
      flexShrink: 0,
    }}>{initials}</div>
  );
}

function Pill({ children, tone = "neutral" }) {
  const tones = {
    neutral: { bg: "#2a2a36", color: "#b4b4c2", border: "#32323f" },
    warm:    { bg: "rgba(212,130,75,.12)",  color: "oklch(0.78 0.14 50)",  border: "rgba(212,130,75,.3)" },
    cyan:    { bg: "rgba(90,200,230,.1)",   color: "oklch(0.82 0.12 200)", border: "rgba(90,200,230,.25)" },
    green:   { bg: "rgba(120,200,130,.1)",  color: "oklch(0.82 0.14 150)", border: "rgba(120,200,130,.25)" },
    red:     { bg: "rgba(230,100,110,.1)",  color: "oklch(0.8 0.16 25)",   border: "rgba(230,100,110,.3)" },
  };
  const t = tones[tone] || tones.neutral;
  return (
    <span style={{
      display: "inline-flex", alignItems: "center", gap: 6,
      padding: "3px 9px", borderRadius: 999,
      background: t.bg, color: t.color, border: `1px solid ${t.border}`,
      fontSize: 11, fontWeight: 500, letterSpacing: 0.01,
    }}>{children}</span>
  );
}

// ---------- Sidebar gauche : chat avec le coach ----------

function CoachSidebar({ thread, onSendThematic, state, onSetState }) {
  const [draft, setDraft] = useState("");
  const scrollRef = useRef(null);

  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [thread]);

  return (
    <aside style={{
      width: 300, flexShrink: 0,
      background: "#14141a",
      borderRight: "1px solid var(--line-soft)",
      display: "flex", flexDirection: "column",
      minHeight: 0,
    }}>
      {/* header */}
      <div style={{ padding: "14px 16px", borderBottom: "1px solid var(--line-soft)", display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{
          width: 26, height: 26, borderRadius: 7,
          background: "linear-gradient(135deg, oklch(0.72 0.14 35), oklch(0.72 0.16 320))",
          display: "grid", placeItems: "center",
          fontFamily: "var(--mono)", fontSize: 11, fontWeight: 700, color: "#111",
        }}>SC</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 13, fontWeight: 600, letterSpacing: 0.01 }}>Swift Coach</div>
          <div style={{ fontSize: 11, color: "var(--ink-3)" }}>
            <span style={{ display: "inline-block", width: 6, height: 6, borderRadius: 999, background: "var(--ok)", marginRight: 6, verticalAlign: "middle" }} />
            en ligne
          </div>
        </div>
        <button style={iconBtn}>⋯</button>
      </div>

      {/* thread */}
      <div ref={scrollRef} style={{ flex: 1, overflowY: "auto", padding: "14px 14px 8px" }}>
        <div style={{ fontSize: 10, color: "var(--ink-4)", letterSpacing: "0.14em", textTransform: "uppercase", textAlign: "center", margin: "4px 0 14px" }}>Aujourd'hui · 14:02</div>
        {thread.map((m, i) => (
          <Bubble key={i} msg={m} />
        ))}

        {/* Suggestions rapides si state = idle */}
        {state === "writing" && (
          <div style={{ marginTop: 8 }}>
            <div style={{ fontSize: 10, color: "var(--ink-4)", letterSpacing: "0.14em", textTransform: "uppercase", margin: "10px 4px 8px" }}>Demande un thème</div>
            {["Dictionnaires", "Optionals", "Protocols", "async/await", "Tri & recherche"].map(t => (
              <button key={t} onClick={() => onSendThematic(t)} style={{
                display: "block", width: "100%", textAlign: "left",
                padding: "9px 12px", marginBottom: 6,
                background: "#1c1c24", border: "1px solid var(--line-soft)",
                borderRadius: 8, color: "var(--ink-2)", cursor: "pointer",
                fontSize: 12, fontFamily: "var(--ui)",
                transition: "all .15s",
              }}
              onMouseEnter={e => { e.currentTarget.style.background = "#22222c"; e.currentTarget.style.color = "var(--ink)"; }}
              onMouseLeave={e => { e.currentTarget.style.background = "#1c1c24"; e.currentTarget.style.color = "var(--ink-2)"; }}
              >
                <span style={{ color: "var(--accent)", marginRight: 8, fontFamily: "var(--mono)" }}>/</span>
                {t}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* composer */}
      <div style={{ padding: 12, borderTop: "1px solid var(--line-soft)" }}>
        <div style={{
          background: "#1c1c24", border: "1px solid var(--line-soft)", borderRadius: 10,
          padding: "8px 10px", display: "flex", gap: 8, alignItems: "flex-end",
        }}>
          <textarea
            value={draft}
            onChange={e => setDraft(e.target.value)}
            placeholder="Demande un exo, un thème…"
            rows={1}
            style={{
              flex: 1, resize: "none", background: "transparent", border: 0, outline: 0,
              color: "var(--ink)", fontFamily: "var(--ui)", fontSize: 13, lineHeight: 1.5,
              minHeight: 20, maxHeight: 80,
            }}
          />
          <button
            onClick={() => { if (draft.trim()) { onSendThematic(draft.trim()); setDraft(""); } }}
            style={{
              background: draft.trim() ? "var(--accent)" : "#2a2a36",
              color: draft.trim() ? "#111" : "var(--ink-3)",
              border: 0, borderRadius: 7, padding: "6px 10px",
              cursor: draft.trim() ? "pointer" : "default", fontSize: 12, fontWeight: 600,
              fontFamily: "var(--mono)",
            }}
          >↵</button>
        </div>
        <div style={{ display: "flex", gap: 10, marginTop: 8, fontSize: 10, color: "var(--ink-4)" }}>
          <span><kbd style={kbdS}>⌘</kbd><kbd style={kbdS}>↵</kbd> envoyer</span>
          <span><kbd style={kbdS}>/</kbd> thèmes</span>
        </div>
      </div>
    </aside>
  );
}

const kbdS = {
  fontFamily: "var(--mono)", fontSize: 10,
  padding: "1px 5px", background: "#22222c", border: "1px solid var(--line-soft)",
  borderRadius: 4, marginRight: 2, color: "var(--ink-3)",
};

const iconBtn = {
  background: "transparent", border: 0, color: "var(--ink-3)",
  width: 24, height: 24, borderRadius: 6, cursor: "pointer", fontSize: 16,
};

function Bubble({ msg }) {
  const isCoach = msg.who === "coach";
  return (
    <div style={{ display: "flex", gap: 8, marginBottom: 14, alignItems: "flex-start" }}>
      <Avatar who={msg.who} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 11, color: "var(--ink-3)", marginBottom: 3, display: "flex", justifyContent: "space-between" }}>
          <span style={{ fontWeight: 600, color: isCoach ? "var(--accent)" : "var(--ink-2)" }}>
            {isCoach ? "Coach" : "Moi"}
          </span>
          <span>{msg.time}</span>
        </div>
        <div style={{ fontSize: 13, lineHeight: 1.55, color: "var(--ink)" }}
             dangerouslySetInnerHTML={{ __html: formatMd(msg.text) }} />
      </div>
    </div>
  );
}

function formatMd(s) {
  return s
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/`([^`]+)`/g, '<code style="font-family:var(--mono);font-size:12px;background:#22222c;padding:1px 5px;border-radius:4px;color:oklch(0.82 0.12 200);">$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<b style="color:var(--ink);font-weight:600;">$1</b>');
}

// ---------- Énoncé (petit panneau en haut de l'éditeur OU dans sidebar) ----------

function BriefCard({ exercise }) {
  return (
    <div style={{
      background: "linear-gradient(180deg, #1c1c24, #181820)",
      border: "1px solid var(--line-soft)", borderRadius: 10,
      padding: 18, margin: "14px 16px 0",
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10, flexWrap: "wrap" }}>
        <Pill tone="warm">{exercise.topic}</Pill>
        <Pill tone="cyan">{exercise.difficulty}</Pill>
        <span style={{ fontSize: 11, color: "var(--ink-4)", marginLeft: "auto", fontFamily: "var(--mono)" }}>#{exercise.id}</span>
      </div>
      <h2 style={{ margin: "0 0 10px", fontSize: 19, fontWeight: 600, letterSpacing: "-0.01em" }}>{exercise.title}</h2>
      <p style={{ margin: 0, fontSize: 13, lineHeight: 1.6, color: "var(--ink-2)" }}
         dangerouslySetInnerHTML={{ __html: formatMd(exercise.brief) }} />

      <div style={{ marginTop: 14, fontSize: 11, color: "var(--ink-3)", letterSpacing: "0.12em", textTransform: "uppercase", marginBottom: 6 }}>Contraintes</div>
      <ul style={{ margin: 0, padding: 0, listStyle: "none", display: "flex", flexDirection: "column", gap: 4 }}>
        {exercise.constraints.map((c, i) => (
          <li key={i} style={{ fontFamily: "var(--mono)", fontSize: 12, color: "var(--ink-2)" }}>
            <span style={{ color: "var(--accent)", marginRight: 8 }}>›</span>{c}
          </li>
        ))}
      </ul>

      <div style={{ marginTop: 14, fontSize: 11, color: "var(--ink-3)", letterSpacing: "0.12em", textTransform: "uppercase", marginBottom: 6 }}>Exemples</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
        {exercise.examples.map((ex, i) => (
          <div key={i} style={{ background: "#14141a", border: "1px solid var(--line-soft)", borderRadius: 8, padding: 10, fontFamily: "var(--mono)", fontSize: 12 }}>
            <div style={{ color: "var(--ink-3)" }}><span style={{ color: "var(--ink-4)" }}>in  </span>{ex.input}</div>
            <div style={{ color: "var(--accent-4)" }}><span style={{ color: "var(--ink-4)" }}>out </span>{ex.output}</div>
            {ex.note && <div style={{ color: "var(--ink-4)", marginTop: 4, fontSize: 11 }}>// {ex.note}</div>}
          </div>
        ))}
      </div>
    </div>
  );
}

// ---------- Éditeur central ----------

function Editor({ code, annotations, annotationStyle, onRun, onHint, state, setState }) {
  const lines = useMemo(() => window.highlightLines(code), [code]);
  const annByLine = useMemo(() => {
    const m = {};
    annotations.forEach(a => { (m[a.line] = m[a.line] || []).push(a); });
    return m;
  }, [annotations]);

  return (
    <div style={{
      flex: 1, minWidth: 0, minHeight: 0,
      background: "var(--bg)",
      display: "flex", flexDirection: "column",
    }}>
      {/* tab bar */}
      <div style={{
        height: 34, background: "#14141a", borderBottom: "1px solid var(--line-soft)",
        display: "flex", alignItems: "flex-end", paddingLeft: 6,
      }}>
        <div style={{
          background: "var(--bg)", borderTop: "2px solid var(--accent)",
          padding: "6px 14px 8px", fontSize: 12, fontFamily: "var(--mono)",
          color: "var(--ink)", display: "flex", alignItems: "center", gap: 8,
          borderLeft: "1px solid var(--line-soft)", borderRight: "1px solid var(--line-soft)",
        }}>
          <span style={{ color: "var(--accent)" }}>●</span>
          twosum.swift
          <span style={{ color: "var(--ink-4)", marginLeft: 4 }}>×</span>
        </div>
        <div style={{ marginLeft: "auto", padding: "0 12px", color: "var(--ink-4)", fontSize: 11, fontFamily: "var(--mono)" }}>
          Swift 5.10 · UTF-8 · LF
        </div>
      </div>

      {/* editor body */}
      <div style={{ flex: 1, overflow: "auto", position: "relative" }}>
        <pre style={{
          margin: 0, fontFamily: "var(--mono)", fontSize: 13, lineHeight: "22px",
          color: "var(--ink)",
        }}>
          {lines.map((html, idx) => {
            const lineNum = idx + 1;
            const anns = annByLine[lineNum] || [];
            const hasError = anns.some(a => a.kind === "error");
            const hasAnn = anns.length > 0;
            const color = {
              error: "var(--danger)",
              praise: "var(--accent-4)",
              nit: "var(--accent-5)",
              suggestion: "var(--accent-2)",
            };
            return (
              <div key={idx} style={{
                display: "flex",
                background: hasError ? "rgba(230,100,110,.06)" : "transparent",
                borderLeft: hasError ? "2px solid var(--danger)" : "2px solid transparent",
              }}>
                <div style={{
                  width: 54, textAlign: "right", padding: "0 12px 0 8px",
                  color: hasAnn ? "var(--ink-2)" : "var(--ink-4)",
                  userSelect: "none", flexShrink: 0,
                  position: "relative",
                }}>
                  {hasAnn && annotationStyle === "gutter" && (
                    <span style={{
                      position: "absolute", left: 6, top: 3,
                      width: 14, height: 14, borderRadius: 4,
                      background: color[anns[0].kind] || "var(--accent)",
                      color: "#111", fontSize: 9, fontWeight: 700, fontFamily: "var(--mono)",
                      display: "grid", placeItems: "center",
                    }}>{anns[0].kind[0].toUpperCase()}</span>
                  )}
                  {lineNum}
                </div>
                <div style={{ flex: 1, paddingRight: 16, minWidth: 0 }}>
                  <span dangerouslySetInnerHTML={{ __html: html || "&nbsp;" }} />

                  {/* annotations inline style pill */}
                  {annotationStyle === "inline" && hasAnn && (
                    <div style={{ marginTop: 4, marginBottom: 6, display: "flex", flexDirection: "column", gap: 4 }}>
                      {anns.map((a, i) => (
                        <div key={i} style={{
                          display: "inline-flex", alignItems: "flex-start", gap: 8,
                          padding: "6px 10px 7px",
                          background: tint(a.kind, 0.08),
                          border: `1px solid ${tint(a.kind, 0.35)}`,
                          borderLeft: `3px solid ${tint(a.kind, 1)}`,
                          borderRadius: 6, maxWidth: 520,
                          fontFamily: "var(--ui)", fontSize: 12, lineHeight: 1.5,
                        }}>
                          <span style={{ fontFamily: "var(--mono)", fontSize: 10, fontWeight: 700, color: tint(a.kind, 1), textTransform: "uppercase", letterSpacing: "0.1em", flexShrink: 0, marginTop: 1 }}>
                            {labelOf(a.kind)}
                          </span>
                          <span style={{ color: "var(--ink-2)" }}>
                            <b style={{ color: "var(--ink)", fontWeight: 600 }}>{a.title}.</b> {a.body}
                          </span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </pre>

        {/* margin notes style: stickies flottants à droite de l'éditeur */}
        {annotationStyle === "margin" && annotations.length > 0 && (
          <div style={{
            position: "absolute", top: 0, right: 0, width: 230,
            padding: "8px 12px", pointerEvents: "none",
          }}>
            {annotations.map((a, i) => (
              <div key={i} style={{
                pointerEvents: "auto",
                background: tint(a.kind, 0.1), border: `1px solid ${tint(a.kind, 0.4)}`,
                borderRadius: 8, padding: "8px 10px", marginBottom: 8,
                fontSize: 11, lineHeight: 1.5, position: "relative",
                transform: `translateY(${(a.line - 1) * 22 - 8}px)`,
              }}>
                <div style={{ fontFamily: "var(--mono)", fontSize: 9, fontWeight: 700, color: tint(a.kind, 1), textTransform: "uppercase", letterSpacing: "0.1em", marginBottom: 2 }}>
                  L{a.line} · {labelOf(a.kind)}
                </div>
                <div style={{ color: "var(--ink-2)" }}>{a.body}</div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* action bar */}
      <div style={{
        height: 44, borderTop: "1px solid var(--line-soft)", background: "#14141a",
        display: "flex", alignItems: "center", padding: "0 12px", gap: 8,
      }}>
        <button onClick={onRun} style={{
          background: "var(--accent)", color: "#111", border: 0, borderRadius: 7,
          padding: "7px 14px", fontWeight: 600, fontSize: 12, cursor: "pointer",
          display: "inline-flex", alignItems: "center", gap: 6, fontFamily: "var(--ui)",
        }}>
          <span style={{ fontSize: 10 }}>▶</span> Compiler & exécuter
        </button>
        <button onClick={onHint} style={{
          background: "transparent", color: "var(--ink-2)", border: "1px solid var(--line)",
          borderRadius: 7, padding: "6px 12px", fontSize: 12, cursor: "pointer", fontFamily: "var(--ui)",
        }}>Demander un indice</button>

        <div style={{ marginLeft: "auto", display: "flex", gap: 14, fontSize: 11, color: "var(--ink-4)", fontFamily: "var(--mono)" }}>
          <span>Ln 4, Col 29</span>
          <span>{code.split("\n").length} lignes</span>
          <span style={{ color: state === "error" ? "var(--danger)" : state === "success" || state === "resolved" ? "var(--ok)" : "var(--ink-4)" }}>
            ● {state === "error" ? "échec build" : state === "success" ? "build ok" : state === "resolved" ? "résolu" : "prêt"}
          </span>
        </div>
      </div>
    </div>
  );
}

function labelOf(kind) {
  return {
    error: "Erreur",
    praise: "Bien",
    nit: "Nit",
    suggestion: "Piste",
  }[kind] || kind;
}
function tint(kind, a) {
  const map = {
    error: `oklch(0.68 0.2 25 / ${a})`,
    praise: `oklch(0.75 0.14 150 / ${a})`,
    nit: `oklch(0.78 0.14 80 / ${a})`,
    suggestion: `oklch(0.78 0.12 200 / ${a})`,
  };
  return map[kind] || `oklch(0.72 0.14 35 / ${a})`;
}

// ---------- Console ----------

function Console({ lines, height = 180 }) {
  return (
    <div style={{
      height, flexShrink: 0,
      background: "#0d0d12", borderTop: "1px solid var(--line-soft)",
      display: "flex", flexDirection: "column",
    }}>
      <div style={{
        height: 30, display: "flex", alignItems: "center", padding: "0 12px",
        borderBottom: "1px solid var(--line-soft)", fontSize: 11, color: "var(--ink-3)",
        letterSpacing: "0.1em", textTransform: "uppercase",
      }}>
        <span style={{ color: "var(--ink-2)", fontWeight: 600 }}>Console</span>
        <span style={{ marginLeft: 12, color: "var(--ink-4)" }}>swift-driver 5.10</span>
        <span style={{ marginLeft: "auto", fontFamily: "var(--mono)", textTransform: "none", letterSpacing: 0 }}>clear ⌫</span>
      </div>
      <div style={{ flex: 1, overflow: "auto", padding: "8px 12px", fontFamily: "var(--mono)", fontSize: 12, lineHeight: 1.6 }}>
        {lines.map((l, i) => (
          <div key={i} style={{
            color: l.kind === "err" ? "oklch(0.78 0.18 25)"
                : l.kind === "ok" ? "oklch(0.82 0.14 150)"
                : l.kind === "cmd" ? "var(--ink)"
                : "var(--ink-2)",
          }}>
            {l.kind === "cmd" && <span style={{ color: "var(--accent)", marginRight: 6 }}>$</span>}
            {l.text}
          </div>
        ))}
      </div>
    </div>
  );
}

// ---------- Panneau feedback (right / bottom / overlay) ----------

function FeedbackPanel({ state, annotations, consoleLines, onHint, feedbackPosition }) {
  const summary = state === "error"
    ? { tone: "red", title: "Build échoué", body: "Une erreur de syntaxe bloque la compilation. Je l'ai pointée dans le code." }
    : state === "success"
    ? { tone: "green", title: "Build OK", body: "Sortie attendue `[0, 1]` obtenue. Quelques remarques de lisibilité avant de valider." }
    : state === "resolved"
    ? { tone: "green", title: "Résolu ✓", body: "Tous les tests passent. Refactor propre, prêt pour l'exercice suivant." }
    : state === "hint"
    ? { tone: "warm", title: "Indice", body: "Je te donne un coup de pouce sans spoiler la solution." }
    : { tone: "neutral", title: "Prêt", body: "Compile quand tu veux. J'analyse ton code dès que tu lances." };

  const [tab, setTab] = useState("review"); // review | chat
  const hints = window.APP_DATA.HINTS;

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%", minHeight: 0 }}>
      <div style={{ padding: "14px 16px 10px", borderBottom: "1px solid var(--line-soft)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 8 }}>
          <span style={{ fontSize: 10, letterSpacing: "0.14em", textTransform: "uppercase", color: "var(--ink-3)", fontWeight: 600 }}>Feedback</span>
          <Pill tone={summary.tone === "red" ? "red" : summary.tone === "green" ? "green" : summary.tone === "warm" ? "warm" : "neutral"}>
            {summary.title}
          </Pill>
          <span style={{ marginLeft: "auto", fontSize: 11, color: "var(--ink-4)" }}>il y a {state === "idle" ? "–" : "quelques secondes"}</span>
        </div>
        <div style={{ fontSize: 13, color: "var(--ink-2)", lineHeight: 1.55 }}>{summary.body}</div>
      </div>

      {/* tabs */}
      <div style={{ display: "flex", gap: 0, borderBottom: "1px solid var(--line-soft)", padding: "0 10px" }}>
        {[
          { id: "review", label: "Revue", count: annotations.length },
          { id: "chat", label: "Chat", count: null },
        ].map(t => (
          <button key={t.id} onClick={() => setTab(t.id)} style={{
            background: "transparent", border: 0,
            padding: "10px 12px",
            fontSize: 12, fontWeight: 500,
            color: tab === t.id ? "var(--ink)" : "var(--ink-3)",
            borderBottom: tab === t.id ? "2px solid var(--accent)" : "2px solid transparent",
            cursor: "pointer", fontFamily: "var(--ui)",
            display: "inline-flex", gap: 6, alignItems: "center",
          }}>
            {t.label}
            {t.count != null && <span style={{ fontFamily: "var(--mono)", fontSize: 10, background: "#22222c", padding: "1px 6px", borderRadius: 999, color: "var(--ink-2)" }}>{t.count}</span>}
          </button>
        ))}
      </div>

      <div style={{ flex: 1, overflow: "auto" }}>
        {tab === "review" ? (
          <div style={{ padding: "12px 14px" }}>
            {annotations.length === 0 ? (
              <div style={{ color: "var(--ink-3)", fontSize: 13, padding: "32px 0", textAlign: "center" }}>
                Aucune remarque pour le moment.<br/>
                <span style={{ color: "var(--ink-4)", fontSize: 12 }}>Compile ton code pour déclencher une revue.</span>
              </div>
            ) : (
              <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                {annotations.map((a, i) => (
                  <ReviewItem key={i} ann={a} />
                ))}
              </div>
            )}

            {state === "hint" && (
              <div style={{
                marginTop: 14, padding: 12,
                background: "rgba(212,130,75,.08)", border: "1px solid rgba(212,130,75,.3)",
                borderRadius: 8,
              }}>
                <div style={{ fontSize: 10, color: "var(--accent)", letterSpacing: "0.14em", textTransform: "uppercase", fontWeight: 700, marginBottom: 6 }}>Indices progressifs</div>
                {hints.map((h, i) => (
                  <div key={i} style={{ fontSize: 12, color: "var(--ink-2)", lineHeight: 1.55, paddingLeft: 20, position: "relative", marginBottom: 8 }}>
                    <span style={{ position: "absolute", left: 0, top: 0, fontFamily: "var(--mono)", color: "var(--accent)", fontWeight: 700 }}>{i + 1}.</span>
                    <span dangerouslySetInnerHTML={{ __html: formatMd(h) }} />
                  </div>
                ))}
              </div>
            )}
          </div>
        ) : (
          <div style={{ padding: "12px 14px" }}>
            <FeedbackChat state={state} />
          </div>
        )}
      </div>

      {feedbackPosition !== "right" && (
        <div style={{ padding: 10, borderTop: "1px solid var(--line-soft)", display: "flex", gap: 8 }}>
          <button onClick={onHint} style={ghostBtn}>indice</button>
          <button style={ghostBtn}>solution</button>
          <button style={{ ...ghostBtn, marginLeft: "auto" }}>exo suivant →</button>
        </div>
      )}
    </div>
  );
}

const ghostBtn = {
  background: "transparent", color: "var(--ink-2)", border: "1px solid var(--line)",
  borderRadius: 7, padding: "6px 12px", fontSize: 12, cursor: "pointer", fontFamily: "var(--ui)",
};

function ReviewItem({ ann }) {
  return (
    <div style={{
      border: `1px solid ${tint(ann.kind, 0.35)}`,
      background: tint(ann.kind, 0.06),
      borderRadius: 10, padding: 12,
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 6 }}>
        <span style={{
          width: 20, height: 20, borderRadius: 5,
          background: tint(ann.kind, 1), color: "#111",
          fontFamily: "var(--mono)", fontSize: 11, fontWeight: 700,
          display: "grid", placeItems: "center",
        }}>{ann.kind[0].toUpperCase()}</span>
        <span style={{ fontSize: 13, fontWeight: 600, color: "var(--ink)" }}>{ann.title}</span>
        <span style={{ marginLeft: "auto", fontFamily: "var(--mono)", fontSize: 11, color: "var(--ink-4)" }}>L{ann.line}</span>
      </div>
      <div style={{ fontSize: 12, lineHeight: 1.55, color: "var(--ink-2)" }}
           dangerouslySetInnerHTML={{ __html: formatMd(ann.body) }} />
    </div>
  );
}

function FeedbackChat({ state }) {
  const msgs = state === "error"
    ? [
        { who: "coach", text: "Le parseur Swift s'arrête ligne 5 : après un `if let … = expr`, il veut explicitement le `{`. Ajoute-le et relance.", time: "à l'instant" },
        { who: "user", text: "Ah oui bête erreur. Corrigé.", time: "à l'instant" },
      ]
    : state === "success"
    ? [
        { who: "coach", text: "Bravo, la logique est bonne. Deux petites choses : renomme `n`/`i` pour la lisibilité, et pose-toi la question du type de retour si aucune solution n'existe.", time: "à l'instant" },
        { who: "user", text: "Je fais le renommage puis je regarde pour l'optionnel.", time: "à l'instant" },
      ]
    : state === "resolved"
    ? [
        { who: "coach", text: "Parfait. On enchaîne sur une variante : **ThreeSum** (trouver trois nombres). Tu veux que je charge l'énoncé ?", time: "à l'instant" },
      ]
    : [
        { who: "coach", text: "J'ai chargé l'énoncé. Prends le temps de lire, commence quand tu veux.", time: "14:02" },
      ];
  return (
    <div>
      {msgs.map((m, i) => <Bubble key={i} msg={m} />)}
    </div>
  );
}

// ---------- Shell desktop ----------

function Desktop({ tweaks, onChangeState, state, code, setCode, consoleLines, annotations }) {
  const feedbackPos = tweaks.feedbackPosition;
  const { EXERCISE, CHAT_THREAD } = window.APP_DATA;

  const [thread, setThread] = useState(CHAT_THREAD);

  function sendThematic(t) {
    setThread(prev => [
      ...prev,
      { who: "user", text: t, time: "maintenant" },
      { who: "coach", text: `Ok, je te prépare un exercice sur **${t}**. Je garde celui en cours ouvert pour l'instant.`, time: "maintenant" },
    ]);
  }

  const editorBlock = (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0, minHeight: 0 }}>
      <BriefCard exercise={EXERCISE} />
      <div style={{ flex: 1, display: "flex", flexDirection: "column", minHeight: 0, padding: "12px 16px 0" }}>
        <div style={{ flex: 1, border: "1px solid var(--line-soft)", borderRadius: 10, overflow: "hidden", display: "flex", flexDirection: "column", minHeight: 0 }}>
          <Editor
            code={code}
            annotations={annotations}
            annotationStyle={tweaks.annotationStyle}
            state={state}
            setState={onChangeState}
            onRun={() => onChangeState(state === "error" ? "success" : state === "success" ? "resolved" : "success")}
            onHint={() => onChangeState("hint")}
          />
          <Console lines={consoleLines} height={160} />
        </div>
        <div style={{ height: 16 }} />
      </div>
    </div>
  );

  const feedbackBlock = (
    <div style={{ background: "#14141a", display: "flex", flexDirection: "column", minHeight: 0 }}>
      <FeedbackPanel
        state={state}
        annotations={annotations}
        consoleLines={consoleLines}
        feedbackPosition={feedbackPos}
        onHint={() => onChangeState("hint")}
      />
    </div>
  );

  return (
    <div style={{ display: "flex", height: "100vh", minHeight: 0, background: "#0d0d12" }}>
      <CoachSidebar thread={thread} onSendThematic={sendThematic} state={state} />

      {feedbackPos === "right" && (
        <>
          {editorBlock}
          <div style={{ width: 360, flexShrink: 0, borderLeft: "1px solid var(--line-soft)", minHeight: 0 }}>
            {feedbackBlock}
          </div>
        </>
      )}

      {feedbackPos === "bottom" && (
        <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
          {editorBlock}
          <div style={{ height: 280, borderTop: "1px solid var(--line-soft)", flexShrink: 0 }}>
            {feedbackBlock}
          </div>
        </div>
      )}

      {feedbackPos === "overlay" && (
        <>
          {editorBlock}
          <div style={{
            position: "fixed", top: 70, right: 20, bottom: 20, width: 380,
            background: "rgba(22,22,28,.96)", backdropFilter: "blur(18px)",
            border: "1px solid var(--line)", borderRadius: 14, overflow: "hidden",
            boxShadow: "0 30px 80px rgba(0,0,0,.5)",
            zIndex: 10,
          }}>
            {feedbackBlock}
          </div>
        </>
      )}
    </div>
  );
}

window.Desktop = Desktop;

```

## `src/mobile.jsx`

```jsx
// Mobile — stack vertical avec clavier custom Swift

const { useState: useStateM, useRef: useRefM, useMemo: useMemoM } = React;

function MobileFrame({ children }) {
  return (
    <div style={{
      minHeight: "100vh",
      display: "grid", placeItems: "start center",
      padding: "40px 20px 40px",
      background: "radial-gradient(ellipse at top, #1a1a24, #07070b 60%)",
    }}>
      <div style={{
        width: 390, height: 844, position: "relative",
        borderRadius: 48, padding: 10,
        background: "linear-gradient(180deg, #2a2a36, #16161c)",
        boxShadow: "0 40px 80px rgba(0,0,0,.6), inset 0 0 0 1px #32323f",
      }}>
        <div style={{
          position: "absolute", top: 18, left: "50%", transform: "translateX(-50%)",
          width: 110, height: 32, borderRadius: 20, background: "#0d0d12", zIndex: 10,
        }} />
        <div style={{
          width: "100%", height: "100%", borderRadius: 40, overflow: "hidden",
          background: "var(--bg)", position: "relative",
          display: "flex", flexDirection: "column",
        }}>
          {children}
        </div>
      </div>
    </div>
  );
}

function StatusBar() {
  return (
    <div style={{
      height: 54, flexShrink: 0, display: "flex", alignItems: "flex-end",
      justifyContent: "space-between", padding: "0 28px 10px",
      fontSize: 14, fontWeight: 600, color: "var(--ink)", fontFamily: "var(--ui)",
    }}>
      <span>9:41</span>
      <span style={{ display: "flex", gap: 6, alignItems: "center", fontSize: 12 }}>
        <span>●●●●</span>
        <span style={{ fontFamily: "var(--mono)" }}>5G</span>
        <span style={{
          width: 22, height: 11, border: "1.5px solid var(--ink)", borderRadius: 3, position: "relative",
        }}>
          <span style={{ position: "absolute", inset: 1, background: "var(--ink)", borderRadius: 1 }} />
        </span>
      </span>
    </div>
  );
}

function MobileHeader({ state, onHint }) {
  return (
    <div style={{
      padding: "6px 16px 10px",
      borderBottom: "1px solid var(--line-soft)",
      background: "#14141a",
      display: "flex", alignItems: "center", gap: 10,
    }}>
      <button style={{ background: "transparent", border: 0, color: "var(--ink-2)", fontSize: 18, padding: 0, cursor: "pointer" }}>‹</button>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13, fontWeight: 600, color: "var(--ink)", lineHeight: 1.2 }}>Two Sum — Swifty</div>
        <div style={{ fontSize: 10, color: "var(--ink-3)", fontFamily: "var(--mono)", letterSpacing: 0.02 }}>Algorithmes · intermédiaire</div>
      </div>
      <button onClick={onHint} style={{
        background: "rgba(212,130,75,.12)", color: "oklch(0.82 0.14 50)",
        border: "1px solid rgba(212,130,75,.3)", borderRadius: 999,
        padding: "5px 11px", fontSize: 11, fontWeight: 600, cursor: "pointer",
      }}>indice</button>
    </div>
  );
}

function MobileBrief({ exercise, collapsed, onToggle }) {
  return (
    <div style={{
      padding: "12px 16px", background: "#181820",
      borderBottom: "1px solid var(--line-soft)",
    }}>
      <div onClick={onToggle} style={{ display: "flex", alignItems: "center", gap: 8, cursor: "pointer" }}>
        <span style={{ fontSize: 10, letterSpacing: "0.14em", textTransform: "uppercase", color: "var(--accent)", fontWeight: 700 }}>Énoncé</span>
        <span style={{ fontSize: 10, color: "var(--ink-4)", marginLeft: "auto" }}>{collapsed ? "déployer" : "réduire"}</span>
        <span style={{ color: "var(--ink-3)", fontSize: 12, transform: collapsed ? "rotate(-90deg)" : "rotate(0)", transition: "transform .2s" }}>▾</span>
      </div>
      {!collapsed && (
        <div style={{ marginTop: 8 }}>
          <div style={{ fontSize: 14, fontWeight: 600, marginBottom: 6, lineHeight: 1.3 }}>Deux entiers qui somment à `target`</div>
          <div style={{ fontSize: 12, color: "var(--ink-2)", lineHeight: 1.55 }}
               dangerouslySetInnerHTML={{ __html: window.formatMdMobile(exercise.brief) }} />
          <div style={{
            marginTop: 10, background: "#14141a", border: "1px solid var(--line-soft)",
            borderRadius: 8, padding: 8, fontFamily: "var(--mono)", fontSize: 11,
          }}>
            <div style={{ color: "var(--ink-3)" }}><span style={{ color: "var(--ink-4)" }}>in  </span>[2, 7, 11, 15], 9</div>
            <div style={{ color: "oklch(0.82 0.14 150)" }}><span style={{ color: "var(--ink-4)" }}>out </span>[0, 1]</div>
          </div>
        </div>
      )}
    </div>
  );
}

window.formatMdMobile = function(s) {
  return s
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/`([^`]+)`/g, '<code style="font-family:var(--mono);font-size:11px;background:#22222c;padding:0 4px;border-radius:3px;color:oklch(0.82 0.12 200);">$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<b style="color:var(--ink);font-weight:600;">$1</b>');
};

function MobileEditor({ code, annotations, annotationStyle }) {
  const lines = useMemoM(() => window.highlightLines(code), [code]);
  const annByLine = useMemoM(() => {
    const m = {};
    annotations.forEach(a => { (m[a.line] = m[a.line] || []).push(a); });
    return m;
  }, [annotations]);

  return (
    <div style={{ flex: 1, overflow: "auto", background: "var(--bg)" }}>
      <pre style={{
        margin: 0, fontFamily: "var(--mono)", fontSize: 11, lineHeight: "18px",
        color: "var(--ink)",
      }}>
        {lines.map((html, idx) => {
          const lineNum = idx + 1;
          const anns = annByLine[lineNum] || [];
          const hasError = anns.some(a => a.kind === "error");
          const hasAnn = anns.length > 0;
          return (
            <div key={idx} style={{
              display: "flex",
              background: hasError ? "rgba(230,100,110,.07)" : "transparent",
              borderLeft: hasError ? "2px solid oklch(0.68 0.2 25)" : "2px solid transparent",
            }}>
              <div style={{
                width: 30, textAlign: "right", padding: "0 8px 0 4px",
                color: hasAnn ? "var(--ink-2)" : "var(--ink-4)",
                userSelect: "none", flexShrink: 0, position: "relative",
              }}>
                {hasAnn && (
                  <span style={{
                    position: "absolute", left: 3, top: 3,
                    width: 10, height: 10, borderRadius: 3,
                    background: anns[0].kind === "error" ? "oklch(0.68 0.2 25)"
                      : anns[0].kind === "praise" ? "oklch(0.72 0.17 150)"
                      : anns[0].kind === "nit" ? "oklch(0.78 0.14 80)"
                      : "oklch(0.75 0.14 200)",
                  }} />
                )}
                {lineNum}
              </div>
              <div style={{ flex: 1, paddingRight: 10, minWidth: 0 }}>
                <span dangerouslySetInnerHTML={{ __html: html || "&nbsp;" }} />
                {hasAnn && annotationStyle === "inline" && (
                  <div style={{ margin: "4px 0 6px", display: "flex", flexDirection: "column", gap: 3 }}>
                    {anns.map((a, i) => (
                      <div key={i} style={{
                        padding: "5px 8px",
                        background: window.tintMob(a.kind, 0.1),
                        border: `1px solid ${window.tintMob(a.kind, 0.35)}`,
                        borderLeft: `3px solid ${window.tintMob(a.kind, 1)}`,
                        borderRadius: 5,
                        fontFamily: "var(--ui)", fontSize: 11, lineHeight: 1.45,
                        color: "var(--ink-2)",
                      }}>
                        <b style={{ color: window.tintMob(a.kind, 1), fontSize: 9, fontFamily: "var(--mono)", textTransform: "uppercase", letterSpacing: "0.1em", marginRight: 5 }}>
                          {a.kind}
                        </b>
                        {a.body}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </pre>
    </div>
  );
}

window.tintMob = function(kind, a) {
  const map = {
    error: `oklch(0.68 0.2 25 / ${a})`,
    praise: `oklch(0.75 0.14 150 / ${a})`,
    nit: `oklch(0.78 0.14 80 / ${a})`,
    suggestion: `oklch(0.78 0.12 200 / ${a})`,
  };
  return map[kind] || `oklch(0.72 0.14 35 / ${a})`;
};

function MobileFeedbackSheet({ state, annotations, open, onToggle }) {
  const summary = state === "error"
    ? { tone: "oklch(0.78 0.18 25)", label: "Build échoué", icon: "✕" }
    : state === "success"
    ? { tone: "oklch(0.82 0.14 150)", label: "Build OK · 3 remarques", icon: "✓" }
    : state === "resolved"
    ? { tone: "oklch(0.82 0.14 150)", label: "Exercice résolu", icon: "✓" }
    : state === "hint"
    ? { tone: "oklch(0.82 0.14 50)", label: "Indice disponible", icon: "?" }
    : { tone: "var(--ink-3)", label: "En attente d'exécution", icon: "•" };

  return (
    <div style={{
      position: "absolute", left: 0, right: 0,
      bottom: 0, zIndex: 5,
      background: "#14141a",
      borderTop: "1px solid var(--line)",
      borderTopLeftRadius: 14, borderTopRightRadius: 14,
      transform: open ? "translateY(0)" : "translateY(calc(100% - 56px))",
      transition: "transform .3s cubic-bezier(.2,.8,.2,1)",
      maxHeight: "70%", display: "flex", flexDirection: "column",
      boxShadow: "0 -10px 30px rgba(0,0,0,.4)",
    }}>
      <button onClick={onToggle} style={{
        height: 56, flexShrink: 0, background: "transparent", border: 0,
        display: "flex", alignItems: "center", gap: 10, padding: "0 16px",
        cursor: "pointer", color: "var(--ink)", fontFamily: "var(--ui)",
      }}>
        <div style={{
          width: 36, height: 4, borderRadius: 4, background: "#32323f",
          position: "absolute", top: 8, left: "50%", transform: "translateX(-50%)",
        }} />
        <span style={{
          width: 24, height: 24, borderRadius: 7, background: summary.tone, color: "#111",
          display: "grid", placeItems: "center", fontWeight: 700, fontSize: 12,
        }}>{summary.icon}</span>
        <div style={{ flex: 1, textAlign: "left" }}>
          <div style={{ fontSize: 10, color: "var(--ink-3)", letterSpacing: "0.12em", textTransform: "uppercase", fontWeight: 600 }}>Feedback coach</div>
          <div style={{ fontSize: 13, fontWeight: 600 }}>{summary.label}</div>
        </div>
        <span style={{ color: "var(--ink-3)" }}>{open ? "▾" : "▴"}</span>
      </button>

      <div style={{ flex: 1, overflow: "auto", padding: "4px 14px 20px" }}>
        {annotations.length === 0 ? (
          <div style={{ color: "var(--ink-3)", fontSize: 12, padding: 20, textAlign: "center" }}>
            Compile ton code pour déclencher la revue.
          </div>
        ) : (
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {annotations.map((a, i) => (
              <div key={i} style={{
                background: window.tintMob(a.kind, 0.08),
                border: `1px solid ${window.tintMob(a.kind, 0.3)}`,
                borderRadius: 10, padding: 10,
              }}>
                <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 4 }}>
                  <span style={{
                    width: 18, height: 18, borderRadius: 4,
                    background: window.tintMob(a.kind, 1), color: "#111",
                    fontFamily: "var(--mono)", fontSize: 10, fontWeight: 700,
                    display: "grid", placeItems: "center",
                  }}>{a.kind[0].toUpperCase()}</span>
                  <span style={{ fontSize: 12, fontWeight: 600 }}>{a.title}</span>
                  <span style={{ marginLeft: "auto", fontFamily: "var(--mono)", fontSize: 10, color: "var(--ink-4)" }}>L{a.line}</span>
                </div>
                <div style={{ fontSize: 11.5, color: "var(--ink-2)", lineHeight: 1.5 }}
                     dangerouslySetInnerHTML={{ __html: window.formatMdMobile(a.body) }} />
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function SwiftToolbar({ onKey }) {
  const keys = [
    { label: "tab", v: "    " },
    { label: "{", v: "{" },
    { label: "}", v: "}" },
    { label: "(", v: "(" },
    { label: ")", v: ")" },
    { label: "[", v: "[" },
    { label: "]", v: "]" },
    { label: "->", v: "-> " },
    { label: "let", v: "let " },
    { label: "var", v: "var " },
    { label: "func", v: "func " },
    { label: ":", v: ": " },
    { label: ",", v: ", " },
    { label: "?", v: "?" },
    { label: "!", v: "!" },
    { label: "\"", v: "\"" },
  ];
  return (
    <div style={{
      flexShrink: 0, background: "#1c1c24", borderTop: "1px solid var(--line-soft)",
      padding: "6px 8px", display: "flex", gap: 5, overflowX: "auto",
    }}>
      {keys.map(k => (
        <button key={k.label} onClick={() => onKey(k.v)} style={{
          background: "#22222c", border: "1px solid var(--line-soft)",
          color: "var(--ink)", fontFamily: "var(--mono)", fontSize: 12,
          padding: "7px 11px", borderRadius: 6, cursor: "pointer",
          flexShrink: 0, minWidth: 32,
        }}>{k.label}</button>
      ))}
    </div>
  );
}

function MobileKeyboard() {
  // Approximation d'un clavier iOS sombre
  const rows = [
    ["q","w","e","r","t","y","u","i","o","p"],
    ["a","s","d","f","g","h","j","k","l"],
    ["z","x","c","v","b","n","m"],
  ];
  return (
    <div style={{
      flexShrink: 0, background: "#2c2c38", padding: "8px 4px 8px",
      borderTop: "1px solid #0d0d12",
    }}>
      {rows.map((row, i) => (
        <div key={i} style={{
          display: "flex", gap: 5, justifyContent: "center", marginBottom: 6,
          paddingLeft: i === 1 ? 18 : 0, paddingRight: i === 1 ? 18 : 0,
        }}>
          {i === 2 && (
            <button style={kbKey(34)}>⇧</button>
          )}
          {row.map(k => (
            <button key={k} style={kbKey(31)}>{k}</button>
          ))}
          {i === 2 && <button style={kbKey(34)}>⌫</button>}
        </div>
      ))}
      <div style={{ display: "flex", gap: 5, justifyContent: "center", padding: "0 4px" }}>
        <button style={{ ...kbKey(50), fontSize: 12, fontWeight: 500 }}>123</button>
        <button style={{ ...kbKey(50), fontSize: 16 }}>🌐</button>
        <button style={{ ...kbKey(140), fontSize: 13, background: "#4a4a5a" }}>space</button>
        <button style={{ ...kbKey(60), fontSize: 12, background: "var(--accent)", color: "#111", fontWeight: 600 }}>↵</button>
      </div>
      <div style={{ height: 18, display: "flex", justifyContent: "center", paddingTop: 6 }}>
        <div style={{ width: 120, height: 4, borderRadius: 4, background: "var(--ink)" }} />
      </div>
    </div>
  );
}

function kbKey(width) {
  return {
    minWidth: width, width, height: 40,
    background: "#4a4a5a", color: "var(--ink)",
    border: 0, borderRadius: 5,
    fontSize: 17, fontFamily: "var(--ui)",
    boxShadow: "0 1px 0 #0d0d12",
    cursor: "pointer",
  };
}

function Mobile({ tweaks, state, onChangeState, code, setCode, annotations }) {
  const { EXERCISE } = window.APP_DATA;
  const [briefCollapsed, setBriefCollapsed] = useStateM(false);
  const [sheetOpen, setSheetOpen] = useStateM(state !== "idle" && state !== "writing");

  // Ouvre la sheet quand le state change vers un feedback
  React.useEffect(() => {
    if (state === "error" || state === "success" || state === "resolved" || state === "hint") {
      setSheetOpen(true);
    }
  }, [state]);

  function insertAtEnd(v) {
    setCode(c => c + v);
  }

  return (
    <MobileFrame>
      <StatusBar />
      <MobileHeader state={state} onHint={() => onChangeState("hint")} />
      <MobileBrief exercise={EXERCISE} collapsed={briefCollapsed} onToggle={() => setBriefCollapsed(v => !v)} />

      <div style={{ padding: "8px 12px 4px", borderBottom: "1px solid var(--line-soft)", background: "#14141a", display: "flex", alignItems: "center", gap: 8 }}>
        <span style={{ fontSize: 10, letterSpacing: "0.14em", textTransform: "uppercase", color: "var(--accent)", fontWeight: 700 }}>twosum.swift</span>
        <span style={{ fontFamily: "var(--mono)", fontSize: 9, color: "var(--ink-4)", marginLeft: "auto" }}>
          {code.split("\n").length} ln · swift 5.10
        </span>
        <button onClick={() => onChangeState(state === "error" ? "success" : "resolved")} style={{
          background: "var(--accent)", color: "#111", border: 0, borderRadius: 6,
          padding: "4px 10px", fontSize: 10, fontWeight: 700, cursor: "pointer",
        }}>▶ RUN</button>
      </div>

      <MobileEditor code={code} annotations={annotations} annotationStyle={tweaks.annotationStyle} />

      <SwiftToolbar onKey={insertAtEnd} />
      <MobileKeyboard />

      <MobileFeedbackSheet
        state={state}
        annotations={annotations}
        open={sheetOpen}
        onToggle={() => setSheetOpen(v => !v)}
      />
    </MobileFrame>
  );
}

window.Mobile = Mobile;

```

## `src/app.jsx`

```jsx
// App shell — switch desktop/mobile, state machine, tweaks

const { useState: useStateA, useEffect: useEffectA } = React;

function readTweakDefaults() {
  try {
    const raw = document.getElementById("tweak-defaults").textContent;
    const m = raw.match(/\/\*EDITMODE-BEGIN\*\/([\s\S]*?)\/\*EDITMODE-END\*\//);
    return JSON.parse(m[1]);
  } catch {
    return { annotationStyle: "inline", feedbackPosition: "right" };
  }
}

function App() {
  // Persist shell (mobile/desktop) and demo state
  const [shell, setShell] = useStateA(() => localStorage.getItem("sc.shell") || "desktop");
  const [demoState, setDemoState] = useStateA(() => localStorage.getItem("sc.state") || "success");
  // success | error | resolved | hint | writing | idle

  const [tweaks, setTweaks] = useStateA(readTweakDefaults);
  const [tweaksOpen, setTweaksOpen] = useStateA(false);

  useEffectA(() => { localStorage.setItem("sc.shell", shell); }, [shell]);
  useEffectA(() => { localStorage.setItem("sc.state", demoState); }, [demoState]);

  // Edit-mode bridge
  useEffectA(() => {
    function onMsg(e) {
      const d = e.data || {};
      if (d.type === "__activate_edit_mode") setTweaksOpen(true);
      if (d.type === "__deactivate_edit_mode") setTweaksOpen(false);
    }
    window.addEventListener("message", onMsg);
    window.parent.postMessage({ type: "__edit_mode_available" }, "*");
    return () => window.removeEventListener("message", onMsg);
  }, []);

  function updateTweak(key, value) {
    setTweaks(prev => {
      const next = { ...prev, [key]: value };
      window.parent.postMessage({ type: "__edit_mode_set_keys", edits: { [key]: value } }, "*");
      return next;
    });
  }

  // Derive code + annotations + console from state
  const { STARTER_CODE, CODE_WITH_ERROR, CODE_RESOLVED,
          ANNOTATIONS_SUCCESS, ANNOTATIONS_ERROR,
          CONSOLE_SUCCESS, CONSOLE_ERROR, CONSOLE_RESOLVED } = window.APP_DATA;

  const scenario = {
    writing:  { code: STARTER_CODE,     ann: [],                  cons: [{ kind: "out", text: "// prêt. lance la compilation quand tu veux." }] },
    idle:     { code: STARTER_CODE,     ann: [],                  cons: [{ kind: "out", text: "// prêt. lance la compilation quand tu veux." }] },
    success:  { code: STARTER_CODE,     ann: ANNOTATIONS_SUCCESS, cons: CONSOLE_SUCCESS },
    error:    { code: CODE_WITH_ERROR,  ann: ANNOTATIONS_ERROR,   cons: CONSOLE_ERROR },
    resolved: { code: CODE_RESOLVED,    ann: [],                  cons: CONSOLE_RESOLVED },
    hint:     { code: STARTER_CODE,     ann: [],                  cons: [{ kind: "out", text: "// demande un indice, je te donne un coup de pouce sans spoiler." }] },
  };

  const current = scenario[demoState] || scenario.success;
  const [code, setCode] = useStateA(current.code);

  useEffectA(() => {
    setCode(current.code);
  }, [demoState]);

  return (
    <>
      {/* shell switch */}
      <div className="shell-switch">
        <button className={shell === "desktop" ? "active" : ""} onClick={() => setShell("desktop")}>Desktop</button>
        <button className={shell === "mobile" ? "active" : ""} onClick={() => setShell("mobile")}>Mobile</button>
        <span style={{ width: 1, background: "var(--line)", margin: "4px 4px" }} />
        <select
          value={demoState}
          onChange={e => setDemoState(e.target.value)}
          style={{
            background: "transparent", border: 0, color: "var(--ink-2)",
            fontFamily: "var(--ui)", fontSize: 12, padding: "4px 8px", cursor: "pointer",
            outline: "none",
          }}
        >
          <option value="writing">État : en écriture</option>
          <option value="hint">État : indice demandé</option>
          <option value="error">État : erreur compilation</option>
          <option value="success">État : succès + feedback</option>
          <option value="resolved">État : résolu</option>
        </select>
      </div>

      {/* Tweaks panel */}
      <div className={"tweaks" + (tweaksOpen ? " open" : "")}>
        <h4>Tweaks</h4>
        <div className="row">
          <label className="title">Style des annotations LLM</label>
          <div className="seg">
            {["gutter", "inline", "margin"].map(v => (
              <button key={v} className={tweaks.annotationStyle === v ? "active" : ""} onClick={() => updateTweak("annotationStyle", v)}>
                {v === "gutter" ? "gutter" : v === "inline" ? "inline" : "marge"}
              </button>
            ))}
          </div>
          <div style={{ fontSize: 10, color: "var(--ink-4)", marginTop: 6, lineHeight: 1.4 }}>
            {tweaks.annotationStyle === "gutter" && "Pastille dans la gouttière, détails à droite."}
            {tweaks.annotationStyle === "inline" && "Encart juste sous la ligne concernée."}
            {tweaks.annotationStyle === "margin" && "Sticky flottant en marge droite."}
          </div>
        </div>
        <div className="row">
          <label className="title">Position du panneau feedback</label>
          <div className="seg">
            {["right", "bottom", "overlay"].map(v => (
              <button key={v} className={tweaks.feedbackPosition === v ? "active" : ""} onClick={() => updateTweak("feedbackPosition", v)}>
                {v === "right" ? "droite" : v === "bottom" ? "bas" : "overlay"}
              </button>
            ))}
          </div>
          <div style={{ fontSize: 10, color: "var(--ink-4)", marginTop: 6, lineHeight: 1.4 }}>
            Uniquement sur desktop. Sur mobile, le feedback est toujours en bottom sheet.
          </div>
        </div>
      </div>

      {shell === "desktop" ? (
        <window.Desktop
          tweaks={tweaks}
          state={demoState}
          onChangeState={setDemoState}
          code={code}
          setCode={setCode}
          consoleLines={current.cons}
          annotations={current.ann}
        />
      ) : (
        <window.Mobile
          tweaks={tweaks}
          state={demoState}
          onChangeState={setDemoState}
          code={code}
          setCode={setCode}
          annotations={current.ann}
        />
      )}
    </>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);

```

