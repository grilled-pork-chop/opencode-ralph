import { existsSync, readFileSync, writeFileSync, mkdirSync, unlinkSync } from "fs";
import { dirname, join } from "path";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface RalphState {
  active: boolean;
  iteration: number;
  maxIterations: number;
  sessionId?: string;
  prompt?: string;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const STATE_FILENAME = "ralph-loop.local.md";
const COMPLETION_TAG = /<promise>\s*DONE\s*<\/promise>/is;
const DEFAULT_MAX_ITERATIONS = 100;

// ---------------------------------------------------------------------------
// State file helpers
// ---------------------------------------------------------------------------

function getStateFile(directory: string): string {
  return join(directory, ".ralph-loop", STATE_FILENAME);
}

function parseState(content: string): RalphState {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) {
    return { active: false, iteration: 0, maxIterations: DEFAULT_MAX_ITERATIONS };
  }

  const state: RalphState = {
    active: false,
    iteration: 0,
    maxIterations: DEFAULT_MAX_ITERATIONS,
  };

  for (const line of match[1].split("\n")) {
    const colonIdx = line.indexOf(":");
    if (colonIdx === -1) continue;
    const key = line.slice(0, colonIdx).trim();
    const value = line.slice(colonIdx + 1).trim();

    if (key === "active") state.active = value === "true";
    else if (key === "iteration") state.iteration = parseInt(value) || 0;
    else if (key === "maxIterations") state.maxIterations = parseInt(value) || DEFAULT_MAX_ITERATIONS;
    else if (key === "sessionId" && value) state.sessionId = value;
  }

  const body = content.slice(match[0].length).trim();
  if (body) state.prompt = body;

  return state;
}

function serializeState(state: RalphState): string {
  const lines = [
    "---",
    `active: ${state.active}`,
    `iteration: ${state.iteration}`,
    `maxIterations: ${state.maxIterations}`,
  ];
  if (state.sessionId) lines.push(`sessionId: ${state.sessionId}`);
  lines.push("---");
  if (state.prompt) lines.push("", state.prompt);
  return lines.join("\n");
}

function readState(directory: string): RalphState {
  try {
    const stateFile = getStateFile(directory);
    if (existsSync(stateFile)) {
      return parseState(readFileSync(stateFile, "utf-8"));
    }
  } catch {}
  return { active: false, iteration: 0, maxIterations: DEFAULT_MAX_ITERATIONS };
}

function writeState(directory: string, state: RalphState): void {
  try {
    const stateFile = getStateFile(directory);
    mkdirSync(dirname(stateFile), { recursive: true });
    writeFileSync(stateFile, serializeState(state));
  } catch {}
}

function clearState(directory: string): void {
  try {
    const stateFile = getStateFile(directory);
    if (existsSync(stateFile)) unlinkSync(stateFile);
  } catch {}
}

// ---------------------------------------------------------------------------
// Completion check
// ---------------------------------------------------------------------------

async function isComplete(client: any, sessionId: string, directory: string): Promise<boolean> {
  try {
    const response = await client.session.messages({
      path: { id: sessionId },
      query: { directory },
    });

    const messages: any[] = (response as { data?: any[] }).data ?? [];
    const assistantMessages = messages.filter((msg) => msg.info?.role === "assistant");

    if (assistantMessages.length === 0) return false;

    const lastAssistant = assistantMessages[assistantMessages.length - 1];
    const responseText: string = (lastAssistant.parts ?? [])
      .filter((p: any) => p.type === "text")
      .map((p: any) => p.text ?? "")
      .join("\n");

    return COMPLETION_TAG.test(responseText);
  } catch {}

  return false;
}

// ---------------------------------------------------------------------------
// Plugin
// ---------------------------------------------------------------------------

export default async function RalphLoopPlugin(ctx: any) {
  const directory: string = ctx.directory || process.cwd();
  const client = ctx.client;

  return {
    tool: {
      "ralph-loop": {
        description:
          "Start Ralph Loop - auto-continues until task completion. Use: /ralph-loop <task description>",
        parameters: {
          type: "object",
          properties: {
            task: { type: "string", description: "The task to work on until completion" },
            maxIterations: { type: "number", description: `Maximum iterations (default: ${DEFAULT_MAX_ITERATIONS})` },
          },
          required: ["task"],
        },
        async execute({ task, maxIterations = DEFAULT_MAX_ITERATIONS }: { task: string; maxIterations?: number }) {
          writeState(directory, { active: true, iteration: 0, maxIterations, prompt: task });
          return `Ralph Loop started (max ${maxIterations} iterations).

Task: ${task}

I will auto-continue until the task is complete. When fully done, I will output \`<promise>DONE</promise>\` to signal completion.

Use /cancel-ralph to stop early.`;
        },
      },

      "cancel-ralph": {
        description: "Cancel active Ralph Loop",
        parameters: { type: "object", properties: {} },
        async execute() {
          const state = readState(directory);
          if (!state.active) return "No active Ralph Loop to cancel.";
          clearState(directory);
          return `Ralph Loop cancelled after ${state.iteration} iteration(s).`;
        },
      },

      help: {
        description: "Show Ralph Loop plugin help",
        parameters: { type: "object", properties: {} },
        async execute() {
          return `# Ralph Loop Help

## Available Commands

- \`/ralph-loop <task>\` - Start an auto-continuation loop
- \`/cancel-ralph\` - Stop an active loop

## How It Works

1. Start with: /ralph-loop "Build a REST API"
2. AI works on the task until idle
3. Plugin auto-continues if not complete
4. Loop stops when AI outputs: <promise>DONE</promise>

## State File

Located at: .ralph-loop/ralph-loop.local.md`;
        },
      },
    },

    event: async ({ event }: { event: { type: string; properties?: { sessionID?: string } } }) => {
      if (event.type === "session.deleted") {
        clearState(directory);
        return;
      }

      if (event.type !== "session.idle") return;

      const sessionId = event.properties?.sessionID;
      const state = readState(directory);

      if (!state.active || !sessionId) return;
      if (state.sessionId && state.sessionId !== sessionId) return;

      if (await isComplete(client, sessionId, directory)) {
        clearState(directory);
        return;
      }

      if (state.iteration >= state.maxIterations) {
        clearState(directory);
        return;
      }

      const newState: RalphState = { ...state, iteration: state.iteration + 1, sessionId };
      writeState(directory, newState);

      const continuationPrompt = `[RALPH LOOP - ITERATION ${newState.iteration}/${newState.maxIterations}]

Your previous attempt did not output the completion promise. Continue working on the task.

IMPORTANT:
- Review your progress so far
- Continue from where you left off
- When FULLY complete, output: <promise>DONE</promise>
- Do not stop until the task is truly done

Original task:
${state.prompt ?? "(no task specified)"}`;

      try {
        await client.session.prompt({
          path: { id: sessionId },
          body: { parts: [{ type: "text", text: continuationPrompt }] },
        });
      } catch {}
    },
  };
}