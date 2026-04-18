# Backend Contract

Ce document formalise le contrat HTTP minimal attendu par `swiftcoach`.

## Base URL

- configurable dans l'app
- exemple local: `http://127.0.0.1:3000`

Toutes les routes ci-dessous sont relatives a cette base URL.

## Erreurs

Le backend peut renvoyer un body JSON explicite:

```json
{
  "error": "Provider not configured"
}
```

Quand ce body est present:
- l'app l'affiche comme erreur backend explicite

Quand ce body est absent:
- l'app affiche un message HTTP normalise selon le status code

En cas d'indisponibilite reseau:
- l'app remonte une erreur de connexion distincte

## `GET /providers`

Retourne les providers exposes par le backend.

Response:

```json
{
  "providers": [
    {
      "id": "codex",
      "model": "gpt-5.4",
      "configured": true
    },
    {
      "id": "claude",
      "model": "claude-sonnet-4.5",
      "configured": false
    }
  ]
}
```

## `POST /chat`

Usage:
- chat libre
- generation de feedback textuel simple

Request:

```json
{
  "provider": "codex",
  "message": "Review this code",
  "system": "You are a concise Swift coach."
}
```

Response:

```json
{
  "provider": "codex",
  "model": "gpt-5.4",
  "output": "Ta solution est correcte..."
}
```

## `POST /exercise/generate`

Usage:
- creer un exercice depuis un theme, un niveau, ou un brief utilisateur

Request:

```json
{
  "provider": "codex",
  "topic": "dictionnaires",
  "difficulty": "intermediaire",
  "userPrompt": "Je veux un exercice Swift centre sur les hash maps."
}
```

Response:

```json
{
  "exercise": {
    "id": "two-sum",
    "topic": "Algorithmes",
    "difficulty": "Intermediaire",
    "title": "Two Sum",
    "brief": "Retourne les indices...",
    "constraints": ["2 <= nums.count"],
    "examples": [
      {
        "input": "nums = [2,7,11,15], target = 9",
        "output": "[0, 1]",
        "note": "solution unique"
      }
    ],
    "signature": "func twoSum(_ nums: [Int], _ target: Int) -> [Int]"
  },
  "starterCode": "func twoSum(...) -> [Int] { }",
  "hints": ["Pense au complement"]
}
```

## `POST /review`

Usage:
- revue structuree du code d'un exercice

Request:

```json
{
  "provider": "codex",
  "exerciseID": "two-sum",
  "code": "func twoSum(...) { }",
  "consoleOutput": "Build complete!",
  "languageHint": "French"
}
```

Response:

```json
{
  "summary": "La solution compile.",
  "state": "success",
  "annotations": [
    {
      "line": 4,
      "kind": "suggestion",
      "title": "Nommage",
      "body": "Renomme `n` en `value`."
    }
  ],
  "hint": "Ajoute des assertions sur les exemples."
}
```

Valeurs attendues pour `state`:
- `writing`
- `hint`
- `error`
- `success`
- `resolved`

## `POST /hint`

Usage:
- demander un indice contextuel sans spoiler la solution

Request:

```json
{
  "provider": "codex",
  "exerciseID": "two-sum",
  "code": "func twoSum(...) { }",
  "userMessage": "Je bloque sur la structure de donnees"
}
```

Response:

```json
{
  "hint": "Cherche le complement dans un dictionnaire valeur -> index."
}
```

## `POST /compile` (optionnel)

Usage:
- execution ou compilation distante

Request:

```json
{
  "language": "swift",
  "filename": "twosum.swift",
  "code": "func twoSum(...) { }"
}
```

Response:

```json
{
  "success": true,
  "stdout": "[0, 1]",
  "stderr": "",
  "exitCode": 0
}
```
