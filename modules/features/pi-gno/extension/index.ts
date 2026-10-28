/**
 * gno-memory — shared declarative memory for pi.
 *
 * Port of the hermes-gno-memory provider shape (gno integrations/, needs
 * gno >= 1.41.0) onto pi's extension API:
 *
 *   before_agent_start (user prompt) -> `gno recall --json` with the prompt
 *     text; recalled facts are injected as a custom message for that run
 *     (pi's pre-prompt channel; the hermes provider uses its prefetch slot).
 *   gno_remember tool -> `gno remember --json` with propose/add/supersede
 *     gating; the session's latest recall receipt rides along (--receipt)
 *     so gno can fence a recalled span replayed as a new fact.
 *
 * The store is the SHARED host state reached via the GNO_CONFIG_DIR /
 * GNO_DATA_DIR / GNO_CACHE_DIR environment (mortlake gno.nix session
 * variables -> /var/lib/gno) — the same facts hermes sees, never a second
 * per-agent store. If those variables are missing the extension says so
 * instead of silently touching a per-user store.
 *
 * Scopes follow the house scheme: base scopes env/prefs/practice plus
 * project:<slug> derived from the git root of the working directory
 * (~/src/mortlake -> project:mortlake).
 *
 * gno failures (binary missing, version below the pin, timeout, malformed
 * JSON, non-zero exit) disable recall injection for the session with one
 * visible notice; the session continues without memory, like the hermes
 * provider.
 */
import { execFile } from "node:child_process";
import { existsSync } from "node:fs";
import { rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { StringEnum } from "@earendil-works/pi-ai";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const MIN_GNO_VERSION = [1, 41, 0];
const CALLER = "pi";
const COLLECTION = "memory";
const TIMEOUT_MS = 15_000;
const MAX_FACTS = 8;
const MAX_TOKENS = 512;
const BASE_SCOPES = ["env", "prefs", "practice"] as const;
const PREVIEW_CHARS = 80;

interface GnoFact {
	text?: string;
	uri?: string;
	contentHash?: string;
	recordId?: string;
	scopes?: string[];
	supersedes?: unknown;
	similarity?: number;
	match?: string;
}

interface GnoRecallResult {
	facts?: GnoFact[];
	receipt?: Record<string, unknown>;
	retrieval?: { mode?: string; semanticUnavailable?: string };
}

interface RememberOutcome {
	outcome?: string;
	record?: GnoFact;
	candidates?: GnoFact[];
}

interface CliFailure {
	error: string;
	kind: string;
	code?: string;
	memoryCode?: string;
}

const REMEMBER_HINT =
	"Nothing was written. Re-call with decision='add' to store a new fact, " +
	"or decision='supersede' with a candidate's uri and contentHash to replace it.";

// ---------------------------------------------------------------------------
// gno subprocess bridge
// ---------------------------------------------------------------------------

const KIND_NOT_FOUND = "gno_not_found";
const KIND_VERSION_UNSUPPORTED = "gno_version_unsupported";
const KIND_TIMEOUT = "gno_timeout";
const KIND_MALFORMED_JSON = "gno_malformed_json";
const KIND_COMMAND_FAILED = "gno_command_failed";

function cliFailure(kind: string, error: string, extra: Record<string, string> = {}): CliFailure {
	return { kind, error, ...extra };
}

function runGno(args: string[]): Promise<{ payload: Record<string, unknown> | null; failure: CliFailure | null }> {
	return new Promise((resolvePromise) => {
		execFile("gno", args, { timeout: TIMEOUT_MS, maxBuffer: 16 * 1024 * 1024 }, (error, stdout) => {
			const text = (stdout ?? "").toString().trim();
			let payload: Record<string, unknown> | null = null;
			if (text) {
				try {
					const parsed: unknown = JSON.parse(text);
					if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
						payload = parsed as Record<string, unknown>;
					}
				} catch {
					payload = null;
				}
			}
			if (error) {
				const err = error as NodeJS.ErrnoException & { killed?: boolean; code?: string | number };
				if (err.code === "ENOENT") {
					resolvePromise({ payload: null, failure: cliFailure(KIND_NOT_FOUND, "gno binary not found on PATH") });
					return;
				}
				if (err.killed) {
					resolvePromise({ payload: null, failure: cliFailure(KIND_TIMEOUT, `gno ${args[0]} timed out after ${TIMEOUT_MS / 1000}s`) });
					return;
				}
			}
			if (error && payload && typeof payload.error === "object" && payload.error !== null) {
				const gnoError = payload.error as { message?: string; code?: string; details?: { memoryCode?: string } };
				resolvePromise({
					payload,
					failure: cliFailure(
						KIND_COMMAND_FAILED,
						String(gnoError.message ?? `gno ${args[0]} failed`),
						{ code: String(gnoError.code ?? ""), memoryCode: String(gnoError.details?.memoryCode ?? "") },
					),
				});
				return;
			}
			if (error) {
				resolvePromise({ payload: null, failure: cliFailure(KIND_COMMAND_FAILED, `gno ${args[0]} failed: ${error.message}`) });
				return;
			}
			if (!payload) {
				resolvePromise({ payload: null, failure: cliFailure(KIND_MALFORMED_JSON, `gno ${args[0]} returned malformed JSON`) });
				return;
			}
			resolvePromise({ payload, failure: null });
		});
	});
}

function parseVersion(raw: string): number[] | null {
	const match = /(\d+)\.(\d+)\.(\d+)/.exec(raw ?? "");
	if (!match) return null;
	return match.slice(1).map(Number);
}

async function checkGnoVersion(): Promise<{ version: string } | { failure: CliFailure }> {
	const result = await new Promise<{ stdout: string; error: Error | null }>((resolvePromise) => {
		execFile("gno", ["--version"], { timeout: TIMEOUT_MS }, (error, stdout) => {
			resolvePromise({ stdout: (stdout ?? "").toString().trim(), error: error ?? null });
		});
	});
	const found = parseVersion(result.stdout);
	if (result.error || !found) {
		return {
			failure: cliFailure(
				result.error && (result.error as NodeJS.ErrnoException).code === "ENOENT"
					? KIND_NOT_FOUND
					: KIND_COMMAND_FAILED,
				`could not read gno version (${result.error?.message ?? (result.stdout || "no output")})`,
			),
		};
	}
	const min = MIN_GNO_VERSION;
	if (found.length < 3 || found[0] < min[0] || (found[0] === min[0] && found[1] < min[1])) {
		return {
			failure: cliFailure(
				KIND_VERSION_UNSUPPORTED,
				`gno ${found.join(".")} is below the minimum ${min.join(".")} required for remember/recall`,
			),
		};
	}
	return { version: found.join(".") };
}

function scopeArgs(scopes: readonly string[]): string[] {
	return scopes.flatMap((scope) => ["--scope", scope]);
}

function recallArgs(query: string, scopes: readonly string[], session: string): string[] {
	return [
		"recall",
		query,
		...scopeArgs(scopes),
		"--collection",
		COLLECTION,
		"--max-facts",
		String(MAX_FACTS),
		"--max-tokens",
		String(MAX_TOKENS),
		"--caller",
		CALLER,
		"--session",
		session,
		"--json",
	];
}

function rememberArgs(
	text: string,
	decision: "" | "add" | "supersede",
	scopes: readonly string[],
	session: string,
	predecessor: { uri: string; hash: string },
	source: string,
	receiptPath: string,
): string[] {
	const args = ["remember", text, ...scopeArgs(scopes), "--collection", COLLECTION];
	if (decision === "add") args.push("--add");
	if (decision === "supersede") args.push("--supersede", predecessor.uri, "--predecessor-hash", predecessor.hash);
	if (source) args.push("--source", source);
	if (receiptPath) args.push("--receipt", receiptPath);
	args.push("--caller", CALLER, "--session", session, "--json");
	return args;
}

// ---------------------------------------------------------------------------
// Scope selection
// ---------------------------------------------------------------------------

/** lowercase [a-z0-9-] slug of a directory name. */
function slugify(name: string): string {
	const slug = name
		.toLowerCase()
		.replace(/[^a-z0-9]+/g, "-")
		.replace(/^-+|-+$/g, "");
	return slug || "default";
}

/**
 * project:<slug> from the enclosing git root (falls back to the cwd
 * basename), so a pi session in ~/src/mortlake shares project:mortlake
 * with the hermes gateway regardless of which worktree it sits in.
 */
function projectScope(cwd: string): string {
	let dir = resolve(cwd);
	for (;;) {
		if (existsSync(join(dir, ".git"))) return `project:${slugify(basename(dir))}`;
		const parent = dirname(dir);
		if (parent === dir) break;
		dir = parent;
	}
	return `project:${slugify(basename(resolve(cwd)))}`;
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

interface RememberArgs {
	text: string;
	decision: "propose" | "add" | "supersede";
	predecessor_uri?: string;
	predecessor_hash?: string;
	source?: string;
}

function factSummary(fact: GnoFact): Record<string, unknown> {
	const text = String(fact.text ?? "");
	const summary: Record<string, unknown> = {
		uri: fact.uri ?? "",
		recordId: fact.recordId ?? "",
		contentHash: fact.contentHash ?? "",
		scopes: fact.scopes ?? [],
		preview: text.slice(0, PREVIEW_CHARS) + (text.length > PREVIEW_CHARS ? "..." : ""),
	};
	if (fact.supersedes) summary["supersedes"] = fact.supersedes;
	if (typeof fact.similarity === "number") {
		summary["similarity"] = fact.similarity;
		summary["match"] = fact.match ?? "";
	}
	return summary;
}

function summarizeRemember(result: RememberOutcome): Record<string, unknown> {
	const summary: Record<string, unknown> = { outcome: String(result.outcome ?? "") };
	if (result.record && typeof result.record === "object") summary["record"] = factSummary(result.record);
	if (Array.isArray(result.candidates)) {
		summary["candidates"] = result.candidates.filter((c) => c && typeof c === "object").map(factSummary);
		summary["hint"] = REMEMBER_HINT;
	}
	return summary;
}

export default function gnoMemory(pi: ExtensionAPI): void {
	let gnoVersion = "";
	let disabledReason = "";
	let availabilityChecked = false;
	let unavailableNoticeShown = false;
	let lexicalWarned = false;
	let lastReceipt: Record<string, unknown> | null = null;

	const ensureAvailable = async (): Promise<boolean> => {
		if (availabilityChecked) return !disabledReason;
		availabilityChecked = true;
		if (!process.env.GNO_CONFIG_DIR) {
			disabledReason =
				"GNO_CONFIG_DIR is not set — the shared store (/var/lib/gno via mortlake gno.nix session variables) " +
				"is not wired into this launch path";
			return false;
		}
		const version = await checkGnoVersion();
		if ("failure" in version) {
			disabledReason = version.failure.error;
			return false;
		}
		gnoVersion = version.version;
		return true;
	};

	pi.registerTool({
		name: "gno_remember",
		label: "gno remember",
		description:
			"Store ONE durable fact in gno memory. Call this only when the user states something worth keeping " +
			"across sessions (a decision, a preference, a stable fact). Nothing is stored automatically. " +
			"Scopes are fixed per session (env/prefs/practice plus the current project scope). " +
			"decision='propose' (default) writes nothing and returns matching existing facts; 'add' writes a new " +
			"fact; 'supersede' replaces an existing fact and requires the predecessor's uri and contentHash from " +
			"a recalled fact.",
		promptSnippet: "gno_remember — store one durable fact in gno memory (propose/add/supersede gating)",
		promptGuidelines: [
			"gno memory is active: relevant facts are recalled into each turn automatically. Nothing is stored " +
				"automatically: to keep a fact across sessions, call gno_remember deliberately (propose first when " +
				"unsure, add for a new fact, supersede to replace a recalled fact using its uri and contentHash).",
		],
		parameters: Type.Object({
			text: Type.String({ description: "The fact, as one self-contained sentence." }),
			decision: Type.Optional(StringEnum(["propose", "add", "supersede"] as const)),
			predecessor_uri: Type.Optional(Type.String({ description: "gno:// uri of the fact being superseded." })),
			predecessor_hash: Type.Optional(Type.String({ description: "contentHash of the fact being superseded." })),
			source: Type.Optional(Type.String({ description: "Optional free-text evidence for the fact." })),
		}),
		execute: async (_toolCallId, params, _signal, _onUpdate, ctx) => {
			if (!(await ensureAvailable())) {
				return {
					content: [{ type: "text", text: JSON.stringify({ error: `GNO memory unavailable: ${disabledReason}` }) }],
					details: { error: disabledReason },
					isError: true,
				};
			}
			const args = params as RememberArgs;
			const text = (args.text ?? "").trim();
			if (!text) {
				return { content: [{ type: "text", text: JSON.stringify({ error: "text is required" }) }], details: { error: "text is required" }, isError: true };
			}
			const decision = (args.decision ?? "propose").toLowerCase();
			if (decision !== "propose" && decision !== "add" && decision !== "supersede") {
				return {
					content: [{ type: "text", text: JSON.stringify({ error: "decision must be propose, add, or supersede" }) }],
					details: { error: "invalid decision" },
					isError: true,
				};
			}
			const predecessorUri = (args.predecessor_uri ?? "").trim();
			const predecessorHash = (args.predecessor_hash ?? "").trim();
			if (decision === "supersede" && !(predecessorUri && predecessorHash)) {
				return {
					content: [{ type: "text", text: JSON.stringify({ error: "supersede requires predecessor_uri and predecessor_hash from a recalled fact" }) }],
					details: { error: "supersede requires predecessor_uri and predecessor_hash" },
					isError: true,
				};
			}

			const session = ctx.sessionManager.getSessionId();
			const scopes = [...BASE_SCOPES, projectScope(ctx.cwd)];

			// Receipt fencing: the latest recall receipt goes with the write so
			// gno can reject a recalled span replayed as a "new" fact.
			let receiptPath = "";
			if (lastReceipt) {
				receiptPath = join(tmpdir(), `pi-gno-receipt-${process.pid}-${Date.now()}.json`);
				try {
					await writeFile(receiptPath, JSON.stringify({ receipt: lastReceipt }), { mode: 0o600 });
				} catch {
					receiptPath = "";
				}
			}
			try {
				const cliArgs = rememberArgs(
					text,
					decision === "propose" ? "" : decision,
					scopes,
					session,
					{ uri: predecessorUri, hash: predecessorHash },
					(args.source ?? "").trim(),
					receiptPath,
				);
				const { payload, failure } = await runGno(cliArgs);
				if (failure) {
					return {
						content: [{ type: "text", text: JSON.stringify({ error: failure.error, kind: failure.kind, code: failure.code, memoryCode: failure.memoryCode }) }],
						details: failure,
						isError: true,
					};
				}
				const summary = summarizeRemember((payload ?? {}) as RememberOutcome);
				return {
					content: [{ type: "text", text: JSON.stringify(summary, null, 2) }],
					details: summary,
					structuredContent: summary as unknown as Record<string, never>,
				};
			} finally {
				if (receiptPath) await rm(receiptPath, { force: true }).catch(() => {});
			}
		},
	});

	pi.on("before_agent_start", async (event, ctx) => {
		if (event.messageType !== "user") return undefined;
		const query = (event.prompt ?? "").trim();
		if (!query) return undefined;

		if (!(await ensureAvailable())) {
			// One visible notice per session, mirroring the hermes provider's
			// unavailable system-prompt block; later turns stay silent.
			if (unavailableNoticeShown) return undefined;
			unavailableNoticeShown = true;
			return {
				message: {
					customType: "gno-memory",
					content: `GNO memory unavailable: ${disabledReason}. The session continues without memory.`,
					display: true,
				},
			};
		}

		const session = ctx.sessionManager.getSessionId();
		const scopes = [...BASE_SCOPES, projectScope(ctx.cwd)];
		const { payload, failure } = await runGno(recallArgs(query, scopes, session));
		if (failure) {
			// Recall is best-effort prefetch: skip the turn, keep the session.
			console.error(`[gno-memory] recall skipped: ${failure.error}`);
			return undefined;
		}
		const result = (payload ?? {}) as GnoRecallResult;

		if (!lexicalWarned && result.retrieval?.mode === "lexical") {
			lexicalWarned = true;
			console.error(
				`[gno-memory] recall is lexical-only (${result.retrieval.semanticUnavailable ?? "no vectors"}); ` +
					`run \`gno embed ${COLLECTION}\` so recall can also match by meaning.`,
			);
		}
		if (result.receipt && typeof result.receipt === "object") lastReceipt = result.receipt;

		const facts = Array.isArray(result.facts) ? result.facts : [];
		const lines: string[] = [];
		for (const fact of facts) {
			const factText = String(fact?.text ?? "").trim();
			if (!factText) continue;
			lines.push(`- ${factText} [${fact?.uri ?? ""}] (contentHash ${fact?.contentHash ?? ""})`);
		}
		if (!lines.length) return undefined;
		return {
			message: {
				customType: "gno-memory",
				content: `GNO memory (scopes: ${scopes.join(", ")}):\n${lines.join("\n")}`,
				display: true,
			},
		};
	});
}
