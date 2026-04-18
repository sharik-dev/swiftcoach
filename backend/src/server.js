import "dotenv/config";
import cors from "cors";
import express from "express";

const app = express();
const port = Number(process.env.PORT || 3000);

app.use(cors());
app.use(express.json({ limit: "1mb" }));

const PROVIDERS = {
  codex: {
    model: process.env.CODEX_MODEL || "gpt-5",
    configured: () => Boolean(process.env.OPENAI_API_KEY),
  },
  claude: {
    model: process.env.CLAUDE_MODEL || "claude-sonnet-4-20250514",
    configured: () => Boolean(process.env.ANTHROPIC_API_KEY),
  },
  gemma: {
    model: process.env.GEMMA_MODEL || "gemma4",
    configured: () => Boolean(process.env.OLLAMA_BASE_URL),
  },
};

function getProviderInfo() {
  return Object.entries(PROVIDERS).map(([id, config]) => ({
    id,
    model: config.model,
    configured: config.configured(),
  }));
}

function normalizeHistory(history) {
  if (!Array.isArray(history)) {
    return [];
  }

  return history
    .filter((item) => item && typeof item.role === "string" && typeof item.content === "string")
    .map((item) => ({
      role: item.role,
      content: item.content.trim(),
    }))
    .filter((item) => item.content.length > 0);
}

function buildConversation({ system, history, message }) {
  const normalizedHistory = normalizeHistory(history);
  const trimmedMessage = typeof message === "string" ? message.trim() : "";

  if (!trimmedMessage) {
    throw badRequest("`message` is required.");
  }

  return {
    system: typeof system === "string" && system.trim() ? system.trim() : null,
    messages: [...normalizedHistory, { role: "user", content: trimmedMessage }],
  };
}

function badRequest(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

async function parseError(response) {
  const text = await response.text();
  let detail = text;

  try {
    const json = JSON.parse(text);
    detail = json.error?.message || json.message || text;
  } catch {
    // Keep raw text when upstream did not return JSON.
  }

  return `${response.status} ${response.statusText}: ${detail}`;
}

async function callCodex({ system, messages, temperature, maxTokens }) {
  const response = await fetch(`${process.env.OPENAI_BASE_URL || "https://api.openai.com/v1"}/responses`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: PROVIDERS.codex.model,
      input: [
        ...(system ? [{ role: "system", content: [{ type: "input_text", text: system }] }] : []),
        ...messages.map((message) => ({
          role: message.role,
          content: [{ type: "input_text", text: message.content }],
        })),
      ],
      ...(typeof temperature === "number" ? { temperature } : {}),
      ...(typeof maxTokens === "number" ? { max_output_tokens: maxTokens } : {}),
    }),
  });

  if (!response.ok) {
    throw new Error(await parseError(response));
  }

  const data = await response.json();

  return {
    provider: "codex",
    model: data.model || PROVIDERS.codex.model,
    output: data.output_text || "",
    usage: data.usage || null,
  };
}

async function callClaude({ system, messages, temperature, maxTokens }) {
  const response = await fetch(`${process.env.ANTHROPIC_BASE_URL || "https://api.anthropic.com"}/v1/messages`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": process.env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: PROVIDERS.claude.model,
      system: system || undefined,
      messages: messages.map((message) => ({
        role: message.role === "assistant" ? "assistant" : "user",
        content: message.content,
      })),
      max_tokens: typeof maxTokens === "number" ? maxTokens : 1024,
      temperature: typeof temperature === "number" ? temperature : 0.7,
    }),
  });

  if (!response.ok) {
    throw new Error(await parseError(response));
  }

  const data = await response.json();
  const output = Array.isArray(data.content)
    ? data.content.filter((item) => item.type === "text").map((item) => item.text).join("\n")
    : "";

  return {
    provider: "claude",
    model: data.model || PROVIDERS.claude.model,
    output,
    usage: data.usage || null,
  };
}

async function callGemma({ system, messages, temperature, maxTokens }) {
  const response = await fetch(`${process.env.OLLAMA_BASE_URL || "http://127.0.0.1:11434"}/api/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: PROVIDERS.gemma.model,
      stream: false,
      messages: [
        ...(system ? [{ role: "system", content: system }] : []),
        ...messages,
      ],
      options: {
        ...(typeof temperature === "number" ? { temperature } : {}),
        ...(typeof maxTokens === "number" ? { num_predict: maxTokens } : {}),
      },
    }),
  });

  if (!response.ok) {
    throw new Error(await parseError(response));
  }

  const data = await response.json();

  return {
    provider: "gemma",
    model: data.model || PROVIDERS.gemma.model,
    output: data.message?.content || "",
    usage: data.eval_count
      ? {
          output_tokens: data.eval_count,
          input_tokens: data.prompt_eval_count || null,
        }
      : null,
  };
}

async function runProvider(provider, payload) {
  if (!Object.hasOwn(PROVIDERS, provider)) {
    throw badRequest("Unsupported provider. Use `codex`, `claude`, or `gemma`.");
  }

  if (!PROVIDERS[provider].configured()) {
    throw badRequest(`Provider \`${provider}\` is not configured on the server.`);
  }

  if (provider === "codex") {
    return callCodex(payload);
  }

  if (provider === "claude") {
    return callClaude(payload);
  }

  return callGemma(payload);
}

app.get("/health", (_request, response) => {
  response.json({
    status: "ok",
    providers: getProviderInfo(),
  });
});

app.get("/providers", (_request, response) => {
  response.json({
    providers: getProviderInfo(),
  });
});

app.post("/chat", async (request, response) => {
  try {
    const { provider, message, history, system, temperature, maxTokens } = request.body || {};
    const conversation = buildConversation({ system, history, message });
    const result = await runProvider(provider, {
      ...conversation,
      temperature,
      maxTokens,
    });

    response.json(result);
  } catch (error) {
    const statusCode = error.statusCode || 502;
    response.status(statusCode).json({
      error: error.message || "Unknown server error.",
    });
  }
});

app.use((_request, response) => {
  response.status(404).json({
    error: "Not found.",
  });
});

app.listen(port, () => {
  console.log(`swiftcoach backend listening on http://localhost:${port}`);
});
