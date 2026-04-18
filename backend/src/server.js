import "dotenv/config";
import { promisify } from "node:util";
import { execFile as execFileCallback, spawn } from "node:child_process";
import cors from "cors";
import express from "express";

const app = express();
const port = Number(process.env.PORT || 3000);
const execFile = promisify(execFileCallback);

app.use(cors());
app.use(express.json({ limit: "1mb" }));

const DEFAULT_MAX_TOKENS = {
  codex: Number(process.env.CODEX_MAX_TOKENS || 1024),
  claude: Number(process.env.CLAUDE_MAX_TOKENS || 1024),
  gemma: Number(process.env.GEMMA_MAX_TOKENS || 256),
};

const REQUEST_TIMEOUT_MS = {
  codex: Number(process.env.OPENAI_TIMEOUT_MS || 45000),
  claude: Number(process.env.ANTHROPIC_TIMEOUT_MS || 45000),
  gemma: Number(process.env.OLLAMA_TIMEOUT_MS || 120000),
};

const PROVIDERS = {
  codex: {
    model: process.env.CODEX_MODEL || "gpt-5",
    configured: () => Boolean(process.env.OPENAI_API_KEY || process.env.CODEX_USE_CLI !== "0"),
  },
  claude: {
    model: process.env.CLAUDE_MODEL || "claude-sonnet-4-20250514",
    configured: () => Boolean(process.env.ANTHROPIC_API_KEY || process.env.CLAUDE_USE_CLI !== "0"),
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
    transport: getProviderTransport(id),
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

function upstreamError(message, statusCode = 502) {
  const error = new Error(message);
  error.statusCode = statusCode;
  return error;
}

function getProviderTransport(provider) {
  if (provider === "codex") {
    return process.env.OPENAI_API_KEY ? "openai_api" : "codex_cli";
  }

  if (provider === "claude") {
    return process.env.ANTHROPIC_API_KEY ? "anthropic_api" : "claude_cli";
  }

  return "ollama";
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

async function fetchWithTimeout(url, options, timeoutMs) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(url, {
      ...options,
      signal: controller.signal,
    });
  } catch (error) {
    if (error.name === "AbortError") {
      throw upstreamError(`Upstream request timed out after ${timeoutMs} ms.`, 504);
    }

    throw upstreamError(error.message || "Unable to reach upstream provider.");
  } finally {
    clearTimeout(timeout);
  }
}

function getMaxTokens(provider, requestedMaxTokens) {
  if (typeof requestedMaxTokens === "number" && Number.isFinite(requestedMaxTokens) && requestedMaxTokens > 0) {
    return Math.floor(requestedMaxTokens);
  }

  return DEFAULT_MAX_TOKENS[provider];
}

function extractOpenAIOutputText(data) {
  if (typeof data.output_text === "string" && data.output_text.trim()) {
    return data.output_text;
  }

  if (!Array.isArray(data.output)) {
    return "";
  }

  return data.output
    .flatMap((item) => Array.isArray(item.content) ? item.content : [])
    .filter((item) => item.type === "output_text" && typeof item.text === "string")
    .map((item) => item.text)
    .join("\n");
}

function buildCliPrompt({ system, messages }) {
  const sections = [];

  if (system) {
    sections.push(`System:\n${system}`);
  }

  for (const message of messages) {
    const role = message.role === "assistant" ? "Assistant" : "User";
    sections.push(`${role}:\n${message.content}`);
  }

  sections.push("Respond with the assistant reply only.");
  return sections.join("\n\n");
}

async function runCommand(command, args, timeoutMs) {
  try {
    return await execFile(command, args, {
      cwd: process.cwd(),
      timeout: timeoutMs,
      maxBuffer: 10 * 1024 * 1024,
    });
  } catch (error) {
    if (error.killed) {
      throw upstreamError(`${command} timed out after ${timeoutMs} ms.`, 504);
    }

    const detail = error.stderr?.trim() || error.stdout?.trim() || error.message;
    throw upstreamError(detail || `Unable to execute ${command}.`);
  }
}

async function runCommandWithInput(command, args, input, timeoutMs) {
  return await new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: process.cwd(),
      stdio: ["pipe", "pipe", "pipe"],
      env: process.env,
    });

    let stdout = "";
    let stderr = "";
    let settled = false;
    const timeout = setTimeout(() => {
      settled = true;
      child.kill("SIGTERM");
      reject(upstreamError(`${command} timed out after ${timeoutMs} ms.`, 504));
    }, timeoutMs);

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => {
      if (settled) {
        return;
      }

      settled = true;
      clearTimeout(timeout);
      reject(upstreamError(error.message || `Unable to execute ${command}.`));
    });

    child.on("close", (code) => {
      if (settled) {
        return;
      }

      settled = true;
      clearTimeout(timeout);

      if (code !== 0) {
        reject(upstreamError(stderr.trim() || stdout.trim() || `${command} exited with code ${code}.`));
        return;
      }

      resolve({ stdout, stderr });
    });

    child.stdin.end(input);
  });
}

function parseCodexCliOutput(stdout) {
  const lines = stdout.split("\n").map((line) => line.trim()).filter(Boolean);
  let output = "";
  let usage = null;

  for (const line of lines) {
    try {
      const event = JSON.parse(line);

      if (event.type === "item.completed" && event.item?.type === "agent_message" && typeof event.item.text === "string") {
        output = event.item.text;
      }

      if (event.type === "turn.completed" && event.usage) {
        usage = {
          input_tokens: event.usage.input_tokens ?? null,
          output_tokens: event.usage.output_tokens ?? null,
          cached_input_tokens: event.usage.cached_input_tokens ?? null,
        };
      }
    } catch {
      // Ignore non-JSON lines.
    }
  }

  return { output, usage };
}

async function callCodexCli({ system, messages }) {
  const prompt = buildCliPrompt({ system, messages });
  const args = [
    "exec",
    "--skip-git-repo-check",
    "--sandbox",
    "read-only",
    "--json",
    "-",
  ];

  const { stdout, stderr } = await runCommandWithInput(
    process.env.CODEX_CLI_COMMAND || "codex",
    args,
    prompt,
    REQUEST_TIMEOUT_MS.codex,
  );
  const parsed = parseCodexCliOutput(`${stdout}\n${stderr}`);

  return {
    provider: "codex",
    model: PROVIDERS.codex.model,
    output: parsed.output,
    usage: parsed.usage,
  };
}

async function callClaudeCli({ system, messages }) {
  const prompt = buildCliPrompt({ system, messages });
  const args = [
    "-p",
    "--output-format",
    "json",
    "--permission-mode",
    "default",
    "--model",
    process.env.CLAUDE_CLI_MODEL || "sonnet",
    prompt,
  ];

  const { stdout } = await runCommand(process.env.CLAUDE_CLI_COMMAND || "claude", args, REQUEST_TIMEOUT_MS.claude);
  const data = JSON.parse(stdout);

  return {
    provider: "claude",
    model: data.model ?? process.env.CLAUDE_CLI_MODEL ?? "sonnet",
    output: data.result || "",
    usage: data.usage
      ? {
          input_tokens: data.usage.input_tokens ?? null,
          output_tokens: data.usage.output_tokens ?? null,
        }
      : null,
  };
}

async function checkProviderHealth(provider) {
  try {
    if (!PROVIDERS[provider].configured()) {
      return {
        id: provider,
        configured: false,
        reachable: false,
        status: "not_configured",
      };
    }

    if (provider === "gemma") {
      const response = await fetchWithTimeout(
        `${process.env.OLLAMA_BASE_URL || "http://127.0.0.1:11434"}/api/tags`,
        { method: "GET" },
        Math.min(REQUEST_TIMEOUT_MS.gemma, 10000),
      );

      if (!response.ok) {
        throw new Error(await parseError(response));
      }

      const data = await response.json();
      const installed = Array.isArray(data.models)
        && data.models.some((model) => model.name === PROVIDERS.gemma.model || model.model === PROVIDERS.gemma.model);

      return {
        id: provider,
        configured: true,
        reachable: true,
        status: installed ? "ready" : "model_missing",
      };
    }

    if (provider === "codex") {
      if (!process.env.OPENAI_API_KEY) {
        await runCommand(process.env.CODEX_CLI_COMMAND || "codex", ["login", "status"], Math.min(REQUEST_TIMEOUT_MS.codex, 10000));

        return {
          id: provider,
          configured: true,
          reachable: true,
          status: "ready",
          transport: "codex_cli",
        };
      }

      const response = await fetchWithTimeout(
        `${process.env.OPENAI_BASE_URL || "https://api.openai.com/v1"}/models`,
        {
          method: "GET",
          headers: {
            Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
          },
        },
        Math.min(REQUEST_TIMEOUT_MS.codex, 10000),
      );

      if (!response.ok) {
        throw new Error(await parseError(response));
      }

      return {
        id: provider,
        configured: true,
        reachable: true,
        status: "ready",
        transport: "openai_api",
      };
    }

    if (provider === "claude" && !process.env.ANTHROPIC_API_KEY) {
      await runCommand(process.env.CLAUDE_CLI_COMMAND || "claude", ["auth", "status"], Math.min(REQUEST_TIMEOUT_MS.claude, 10000));

      return {
        id: provider,
        configured: true,
        reachable: true,
        status: "ready",
        transport: "claude_cli",
      };
    }

    const response = await fetchWithTimeout(
      `${process.env.ANTHROPIC_BASE_URL || "https://api.anthropic.com"}/v1/messages`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": process.env.ANTHROPIC_API_KEY,
          "anthropic-version": "2023-06-01",
        },
        body: JSON.stringify({
          model: PROVIDERS.claude.model,
          max_tokens: 1,
          messages: [{ role: "user", content: "ping" }],
        }),
      },
      Math.min(REQUEST_TIMEOUT_MS.claude, 10000),
    );

    if (!response.ok) {
      throw new Error(await parseError(response));
    }

    return {
      id: provider,
      configured: true,
      reachable: true,
      status: "ready",
      transport: "anthropic_api",
    };
  } catch (error) {
    return {
      id: provider,
      configured: true,
      reachable: false,
      status: "error",
      error: error.message,
    };
  }
}

async function callCodex({ system, messages, temperature, maxTokens }) {
  if (!process.env.OPENAI_API_KEY) {
    return callCodexCli({ system, messages, temperature, maxTokens });
  }

  const response = await fetchWithTimeout(`${process.env.OPENAI_BASE_URL || "https://api.openai.com/v1"}/responses`, {
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
      max_output_tokens: getMaxTokens("codex", maxTokens),
    }),
  }, REQUEST_TIMEOUT_MS.codex);

  if (!response.ok) {
    throw new Error(await parseError(response));
  }

  const data = await response.json();
  const output = extractOpenAIOutputText(data);

  return {
    provider: "codex",
    model: data.model || PROVIDERS.codex.model,
    output,
    usage: data.usage || null,
  };
}

async function callClaude({ system, messages, temperature, maxTokens }) {
  if (!process.env.ANTHROPIC_API_KEY) {
    return callClaudeCli({ system, messages, temperature, maxTokens });
  }

  const response = await fetchWithTimeout(`${process.env.ANTHROPIC_BASE_URL || "https://api.anthropic.com"}/v1/messages`, {
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
      max_tokens: getMaxTokens("claude", maxTokens),
      temperature: typeof temperature === "number" ? temperature : 0.7,
    }),
  }, REQUEST_TIMEOUT_MS.claude);

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

async function callGemmaOnce({ system, messages, temperature, maxTokens }) {
  const response = await fetchWithTimeout(`${process.env.OLLAMA_BASE_URL || "http://127.0.0.1:11434"}/api/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: PROVIDERS.gemma.model,
      stream: false,
      think: false,
      messages: [
        ...(system ? [{ role: "system", content: system }] : []),
        ...messages,
      ],
      options: {
        ...(typeof temperature === "number" ? { temperature } : {}),
        num_predict: getMaxTokens("gemma", maxTokens),
      },
      keep_alive: process.env.OLLAMA_KEEP_ALIVE || "30m",
    }),
  }, REQUEST_TIMEOUT_MS.gemma);

  if (!response.ok) {
    throw new Error(await parseError(response));
  }

  const data = await response.json();

  return data;
}

async function callGemma({ system, messages, temperature, maxTokens }) {
  const requestedMaxTokens = getMaxTokens("gemma", maxTokens);
  let data = await callGemmaOnce({
    system,
    messages,
    temperature,
    maxTokens: requestedMaxTokens,
  });

  if (!data.message?.content?.trim() && requestedMaxTokens < 512) {
    data = await callGemmaOnce({
      system,
      messages,
      temperature,
      maxTokens: Math.min(requestedMaxTokens * 2, 512),
    });
  }

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

app.get("/providers/health", async (_request, response) => {
  const providers = await Promise.all(
    Object.keys(PROVIDERS).map((provider) => checkProviderHealth(provider))
  );

  response.json({ providers });
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

app.post("/exercise/generate", async (request, response) => {
  try {
    const { provider, topic, difficulty, userPrompt } = request.body || {};
    if (!provider) throw badRequest("`provider` is required.");

    const system = `You are a Swift coding coach. Generate a Swift coding exercise and return ONLY valid JSON (no markdown):
{"id":"kebab-slug","topic":"French topic","difficulty":"Débutant|Intermédiaire|Avancé","title":"French title","brief":"Description in French (2–4 sentences)","constraints":["constraint"],"examples":[{"input":"...","output":"...","note":null}],"signature":"func name(_ p: Type) -> Return","starterCode":"func name(_ p: Type) -> Return {\\n    // TODO\\n    return []\\n}","hints":["hint1 no spoiler","hint2","hint3"]}`;

    const message = userPrompt || `Create a ${difficulty || "intermediate"} Swift exercise about ${topic || "algorithms"}.`;
    const result = await runProvider(provider, { system, messages: [{ role: "user", content: message }], maxTokens: 1200 });
    response.json({ raw: result.output, provider: result.provider, model: result.model });
  } catch (error) {
    response.status(error.statusCode || 502).json({ error: error.message || "Unknown server error." });
  }
});

app.post("/review", async (request, response) => {
  try {
    const { provider, exerciseID, code, consoleOutput, languageHint } = request.body || {};
    if (!provider) throw badRequest("`provider` is required.");
    if (!code) throw badRequest("`code` is required.");

    const lang = languageHint || "French";
    const system = `You are a Swift coding coach. Review the code and return ONLY valid JSON (no markdown):
{"summary":"brief in ${lang}","state":"success|resolved|error","annotations":[{"line":1,"kind":"error|praise|nit|suggestion","title":"Short title","body":"Explanation in ${lang}"}]}
Line numbers must match the actual code.`;

    const message = `Exercise: ${exerciseID || "unknown"}\nConsole:\n${consoleOutput || "(none)"}\n\nCode:\n${code}`;
    const result = await runProvider(provider, { system, messages: [{ role: "user", content: message }], maxTokens: 800 });
    response.json({ raw: result.output, provider: result.provider, model: result.model });
  } catch (error) {
    response.status(error.statusCode || 502).json({ error: error.message || "Unknown server error." });
  }
});

app.post("/hint", async (request, response) => {
  try {
    const { provider, exerciseID, code, userMessage } = request.body || {};
    if (!provider) throw badRequest("`provider` is required.");

    const system = `You are a Swift coding coach. Give ONE concise hint in French without revealing the full solution. Return only the hint text, no JSON, no markdown.`;
    const parts = [`Exercise: ${exerciseID || "unknown"}`];
    if (code) parts.push(`Current code:\n${code}`);
    if (userMessage) parts.push(`User question: ${userMessage}`);

    const result = await runProvider(provider, { system, messages: [{ role: "user", content: parts.join("\n\n") }], maxTokens: 200 });
    response.json({ hint: result.output.trim(), provider: result.provider, model: result.model });
  } catch (error) {
    response.status(error.statusCode || 502).json({ error: error.message || "Unknown server error." });
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
