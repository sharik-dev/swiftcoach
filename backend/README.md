# swiftcoach backend

Backend HTTP simple pour le frontend iOS avec trois providers IA:

- `codex` via API OpenAI Responses
- `claude` via API Anthropic Messages
- `gemma` via Ollama

## Démarrage

```bash
cd backend
npm install
cp .env.example .env
npm run dev
```

## Variables d'environnement

Renseigne uniquement les providers que tu veux activer:

- `OPENAI_API_KEY`
- `OPENAI_BASE_URL` optionnel, défaut `https://api.openai.com/v1`
- `CODEX_MODEL` optionnel, défaut `gpt-5`
- `OPENAI_TIMEOUT_MS` optionnel, défaut `45000`
- `CODEX_MAX_TOKENS` optionnel, défaut `1024`
- `ANTHROPIC_API_KEY`
- `ANTHROPIC_BASE_URL` optionnel, défaut `https://api.anthropic.com`
- `CLAUDE_MODEL` optionnel, défaut `claude-sonnet-4-20250514`
- `ANTHROPIC_TIMEOUT_MS` optionnel, défaut `45000`
- `CLAUDE_MAX_TOKENS` optionnel, défaut `1024`
- `OLLAMA_BASE_URL` optionnel, défaut `http://127.0.0.1:11434`
- `GEMMA_MODEL` optionnel, défaut `gemma4`
- `OLLAMA_TIMEOUT_MS` optionnel, défaut `120000`
- `OLLAMA_KEEP_ALIVE` optionnel, défaut `30m`
- `GEMMA_MAX_TOKENS` optionnel, défaut `256`

## Contrat API

### `GET /health`

Retourne l'état général et la configuration des providers.

### `GET /providers`

Retourne la liste des providers disponibles côté backend.

### `GET /providers/health`

Teste l'état réel des integrations:

- `codex`: reachability OpenAI
- `claude`: reachability Anthropic
- `gemma`: disponibilité d'Ollama et présence du modèle configuré

### `POST /chat`

Body JSON:

```json
{
  "provider": "codex",
  "message": "Prépare un plan d'entraînement pour 10 km",
  "system": "Tu es un coach sportif concis.",
  "history": [
    { "role": "user", "content": "Je cours 3 fois par semaine." },
    { "role": "assistant", "content": "Quel est ton objectif ?" }
  ],
  "temperature": 0.7,
  "maxTokens": 600
}
```

Réponse:

```json
{
  "provider": "codex",
  "model": "gpt-5",
  "output": "Voici un plan...",
  "usage": {
    "input_tokens": 123,
    "output_tokens": 456
  }
}
```

## Attendu côté frontend iOS

L'app peut:

- charger `GET /providers` au lancement pour afficher les IA configurées
- envoyer le prompt courant vers `POST /chat`
- conserver localement l'historique et le renvoyer dans `history`

Exemple base URL en simulateur iOS:

- `http://127.0.0.1:3000` si le backend tourne sur le port 3000 sur la même machine et que tu utilises le simulateur
- `http://127.0.0.1:3010` si tu l'as lancé localement sur le port 3010
- `http://<IP_LOCALE_DU_MAC>:3000` ou `:3010` sur appareil physique selon le port réellement utilisé
