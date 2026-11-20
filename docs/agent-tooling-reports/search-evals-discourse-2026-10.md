# Search for agents: evals + discourse, 2025–2026

**Task:** AT-KSQ8 · **Report date:** 2026-10-19 · **Method:** live-source research (HN Algolia API, vendor primaries, npm registry, GitHub API, live benchmark pages). Every claim is date-stamped at its source. Claims that could not be verified live are marked **unverified**. Sources that are affiliate-SEO listicles were found but deliberately excluded from evidentiary claims (flagged in §1.4).

---

## 1. Benchmarks / evals comparing search APIs for agents

### 1.1 The one independent benchmark: Artificial Analysis Search Index

The only neutral, currently-maintained eval found. Launched **2026-08-18** ("Announcing the Artificial Analysis Search Index: Same Agent, Different Search"); live data as of **2026-10-19** covers **29 search API products across 14 providers**. (artificialanalysis.ai/agents/search-api, /articles/search-api, /methodology/search-api — all fetched 2026-10-19)

**Methodology (from their methodology page, fetched 2026-10-19):**
- Provider-swap design: one fixed candidate model (**GPT-5.6 Luna, medium**), one open-source agent harness ("Stirrup") with exactly three tools: `web_search` (provider under test, native payload, max 10 results), `web_fetch`, `finish`. 25-turn budget; no answer = zero score.
- Three benchmarks, equal-weighted into the index: **DeepSearchQA** (900 tasks, LLM-graded F1 over answer sets), **AA-Omniscience** (600 private factual questions, accuracy — measures uplift over parametric knowledge), **BrowseComp** (hard 200-task subset, exact-answer accuracy).
- **Contamination filtering enabled** in both tools (URL/title/snippet and page-text screening; canary strings) — the strongest anti-gaming measure seen in any eval in this space.
- Costs priced at list; latency measured in-tool; model-only baseline and **OpenAI's first-party web_search tool** run as comparison rows.
- Funding posture: Artificial Analysis sells analytics subscriptions; no search vendor funds the benchmark (their about/methodology framing). Providers "contact us to be included" — inclusion is partly voluntary, a coverage caveat.

**Launch leaderboard (2026-08-18, from launch article):**

| Provider | AA Index | DSQA F1 | BrowseComp | Omni | Search $/1k | Time/task |
|---|---|---|---|---|---|---|
| Parallel (advanced) | 75 | 81 | 77 | 67 | $47.93 | 35.9s |
| Exa (auto) | 74 | 78 | 74 | 70 | $65.57 | 26.2s |
| Firecrawl | 73 | 74 | 74 | 73 | $30.48 | 55.0s |
| Parallel (basic) | 73 | 79 | 73 | 68 | $45.14 | 20.4s |
| Exa (fast) | 68 | 76 | 61 | 69 | $78.11 | 20.7s |
| You.com | 68 | 63 | 74 | 66 | $68.93 | 33.7s |
| Parallel (turbo) | 67 | 70 | 75 | 56 | $13.64 | 18.8s |
| Keenable (pro) | 67 | 70 | 66 | 65 | $23.69 | 23.2s |
| Keenable (realtime) | 67 | 70 | 64 | 66 | $26.87 | 15.1s |
| **Tavily (basic)** | **66** | 74 | **59** | 64 | **$126** | 36.3s |
| **Brave (web)** | **65** | 62 | 67 | 65 | $71.61 | 26.6s |
| Model only (no search) | 33 | 45 | 17 | 38 | — | 13.8s |

**Live scores (2026-10-19, extracted from the page's embedded data):** Perplexity and Exa now share the lead — **Exa (auto, dynamic highlights) 80.3**, **Perplexity Search (medium) 80.0**, Exa (lite, dynamic) 79.2, Perplexity (high) 78.9, Perplexity (low) 76.9, Parallel (advanced) 74.8, **Brave (LLM context) 74.6**, You.com (highlights) 74.1, Exa (auto) 73.7, Firecrawl 73.5, Parallel basic/fast 73.2/73.1, Exa instant/fast 68.4, You.com (snippets) 67.6, Parallel turbo 67.1, Keenable pro/realtime 67.0/66.5, **Tavily (basic) 65.6**, Brave (web) 64.6. Perplexity (medium) posts the best single BrowseComp score on the board (0.870).

**What the numbers actually say (with caveats):**
- Search roughly doubles a strong model's score on these benchmarks (33 → 65–80). But spread between best and worst provider is ~15 points, and **response-mode/variant choice swamps vendor identity**: Exa auto+dynamic-highlights 80 vs Exa instant 68; Brave LLM-context 75 vs Brave plain web 65. Two of the same company's tiers differ by 12 points.
- **Tavily (basic)**: mid-pack quality (66), weakest BrowseComp (59 at launch, 58.5 live), and the **highest search-side cost on the board ($126/1k tasks at launch)**. Post-acquisition (§2.2) its positioning has shifted to "web access layer" endpoints.
- **Perplexity**'s Search API — not its deprecated Sonar models — is top-tier on quality since being added (between 2026-08-18 and 2026-10-19), led by multi-hop BrowseComp performance.
- **Provider variant tuning to the benchmark is visible**: "dynamic highlights" tiers that map exactly onto the harness's content-mode standardization appeared after launch and top the board. AA holds settings fixed per provider-result and documents them, but a provider can ship the variant that scores best. Treat single-digit gaps as noise.
- **No Google or Microsoft/Bing first-party web-search product is on the board** (checked in the page data, 2026-10-19). Google's agent-search surface (Gemini grounding, §2.1) is absent from the leading neutral eval — notable coverage gap, possibly self-selection.
- Recency bias: all three benchmarks reward a fresh, broad index (current facts, hard-to-find recent facts, fresh lists). **No eval found measures stale/long-tail/archival retrieval quality for agents** — a genuine open gap; DeepSearchQA's F1-over-lists is the closest proxy for breadth.

### 1.2 Vendor-run but transparent: SearchSpace "Deep Research gauntlet" (2026-06-26)

SearchSpace (itself a budget search vendor) ran 4 providers — Exa, Brave, Tavily, SearchSpace — through 128 open-ended research briefs, LLM-judge pairwise round-robin → per-provider Elo, full win/loss matrix, dossiers and judge reasoning published in a browsable database (searchspace.io/blog/comparing-ai-agent-web-search-providers, fetched 2026-10-19).
- Unusually honest headline for a vendor: "the benchmark plainly shows that **Exa and Brave beat us on quality**" (SearchSpace places itself below them, above Tavily). Claims ~$6.90/M queries vs "Exa's $7,000/M" and 16–230× lower latency; verticals chosen from Menlo Ventures/Sacra revenue data (healthcare, legal, finance, crypto, cybersecurity…).
- Directionally agrees with AA on the Exa > Tavily gap (AA: 74–80 vs 66) and Brave's strength. Discount the cost/latency claims (self-priced), but the open-data design deserves the credit it asks for.

### 1.3 Vendor self-evals (all biased toward the funders; date-stamped)

| Eval | Date | Claim | Funding |
|---|---|---|---|
| Exa, "How Search Quality Shapes RL Outcomes" (Sol Kim, Nitya Sridhar) | 2026-05-13 | RL-trained agents with Exa backend beat Google-SERP-proxy backends (e.g., +3.50±1.55pp final-task accuracy); real error bars, honest SERP-proxy caveat for "Google" | Exa |
| Exa, "WebCode: Search Evals for Coding Agents" (Ahn, Cammany, Sridhar) | 2026-03-23 | Open-sourced coding-search evals (contents quality vs golden screenshot/DOM extraction; retrieval; end-to-end coding); notes OpenAI deprecated SWE-bench Verified over contamination; claims code-search query surge with "particularly large jump at end of 2025" | Exa |
| Exa, "People Search Benchmarks" | 2025-12-18 | (Not read in depth; listed for coverage) | Exa |
| Tavily, "Tavily vs. Claude Web Search: When Native Search Isn't Enough" (L. Wohlgemuth) | 2026-10-06 | On SealQA-Hard (254 Qs, fixed outer model/prompt/budget): Tavily Advanced **+15.3pp accuracy** vs Claude native web search; Tavily Basic 40% fewer tokens; ~half the cost per correct answer (Basic), ~40% less (Advanced) | Tavily (post-Nebius) |
| Brave, "Ask Brave" blind Bradley-Terry Elo (live on brave.com/search/api) | live 2026-10-19 | Ask Brave (Nemotron 3 Ultra, grounded by Brave) 1278 Elo > Grok 1115 > Google AI Mode 941 > ChatGPT 840 > Perplexity 652 — claims open models grounded by Brave beat frontier assistants head-to-head blind | Brave |
| Upstash/Context7, "Context7 vs Claude Code's Web Search" | 2026-05-27 | Across 100 doc queries (5 categories), Context7 cut input tokens ~99%, cost 34.6%, total tokens 36.8%, tool calls 22.8% vs Claude Code's WebSearch/WebFetch (Opus 4.7 agent) | Upstash (owns Context7) |

Pattern worth naming: **every major vendor now self-publishes evals in the same genre** — Elo or pp-accuracy wins over named rivals, on a benchmark chosen by the vendor. The AA index is the only one where the eval host doesn't sell search. Vendor numbers are useful for methodology ideas (Tavily's cost-per-correct-answer framing is genuinely good) but not for rankings.

### 1.4 Excluded as evidence

"Best SERP API" listicles (e.g., simpletechguides.com's SerpAPI-vs-Exa-vs-Tavily comparison, 2025-10-17, surfaced via HN) — affiliate SEO; no methodology. No claim in this report rests on listicles.

---

## 2. Is search-as-a-tool being absorbed by deep-research modes and model-native browsing?

### 2.1 The model-native timeline (all dated; primary sources where possible)

| Date | Event | Source |
|---|---|---|
| 2025-03-20 | **Claude web search** launches (global on all plans 2025-05-27) | anthropic.com/news/web-search |
| 2025-03-23 | Reports Claude's web search appears **Brave-powered** | HN id=43450471 — **unverified** beyond this; neither party confirms on a page I could fetch |
| 2025-05-08 | **Claude Code gains web search** — "Claude can now search the web", v0.2.105 | claude-code CHANGELOG + npm registry timestamp (primary) |
| 2025-05-13/14 | **Bing Search APIs retirement announced**; retired 2025-08-11; Microsoft steers to "Grounding with Bing" | learn.microsoft.com lifecycle announcement (via HN id=44050200) |
| 2025-07-17 | **ChatGPT agent** launches (research + action, browser-in-the-loop) | HN id=44595492 (686 pts) |
| 2025-10-06 | Teardown of Claude Code's web tools: WebFetch = fetch→markdown→**Haiku summarization** (never raw content, domain deny-list, 15-min cache); WebSearch returns links+titles only | mikhail.io/2025/10/claude-code-web-tools/ |
| 2025-10-21 | **ChatGPT Atlas** browser launches | HN id=45702397 (803 pts) |
| 2026-08-20 | **Mistral "Agentic Search"** — retrieval loop over enterprise docs with tools `search/open/navigate/read/grep`; FinanceBench 26.7%→86% | mistral.ai/news/agentic-search/ |
| Live 2026-10-19 | **OpenAI web_search tool**: $10/1k calls (all models); $25/1k (preview, non-reasoning models) | platform.openai.com/docs/pricing; AA methodology states same $10/1k |
| Live 2026-10-19 | **Gemini "Grounding with Google Search"**: 5,000 free calls/month (Gemini 3+), then $14/1k | ai.google.dev/gemini-api/docs/pricing |

The AA benchmark itself now runs **OpenAI Web Search as a first-party comparison row** against swap-in APIs (methodology page, 2026-10-19) — the normalization of model-native search as just another "provider" is itself discourse evidence.

### 2.2 Market-shape events (the API layer consolidates while the UI layer absorbs)

- **Nebius agrees to acquire Tavily — announced 2026-02-10** (nebius.com newsroom, primary). Framing: Tavily's agentic search becomes the grounding layer next to Nebius "Token Factory" inference — "high-performance inference + real-time grounding" as one stack. Deal price **not stated in the primary release**; "$275M" is the press/HN figure (HN id=47024216, 2026-02-15) — treat the number as **press-reported**. Tavily keeps its brand; claims 3M+ monthly SDK downloads, 1M+ developer users, IBM among customers (Nebius release, 2026-02-10).
- **Exa raises $250M Series C at $2.2B valuation, led by a16z — 2026-05-20** (exa.ai/blog/announcing-series-c, primary). Claims to power search for Cursor, Cognition, HubSpot, OpenRouter, Monday.com, 400k+ developers; ~500B URLs tracked; press reports 80B pages indexed with a "Google scale by 2027" target (runtimewire, 2026-08-03 — secondary). Thesis quote: "AI agents will search the web more than humans this year."
- **Perplexity exits the hosted answer-model business**: `sonar-reasoning` removed 2025-12-15; **Sonar Chat Completions deprecated wholesale in July 2026**, migrated to an "Agent API" with presets (fast/medium/high); MCP server v1.0 (2026-07+) moved off Sonar onto Agent API presets (docs.perplexity.ai/changelog, fetched 2026-10-19). Perplexity's **Search API** (fast search, filters, Dec 2025 `max_tokens`/`last_updated_filter` additions) survives as a standalone product and scores near the top of AA's board. Net: the *unit of sale* moved up-stack from "search call + answer model" to "agent loop," while raw search got cheaper to sell separately.
- **Brave segments AI usage contractually**: base-plan ToS "prohibit using responses for AI inference"; a separate AI plan exists (Ask HN id=46822822, 2026-01-30, with Brave plan dashboard link in-thread; brave.com/search/api live 2026-10-19). Brave also sells an **LLM Context API** — which scores 75 on AA vs 65 for its plain web results: agent-specific products, not just agent-permissive ones.

### 2.3 The discourse, read from primary texts

- **The absorption question is now the vendors' #1 FAQ.** Tavily's 2026-10-06 post opens: "Why use Tavily when Claude already has native web search?… For prototypes… that may be all you need." Their answer: control (depth/domains/time-range parameters), observability of what the agent searched, model-portability across vendors, and retrieval quality that reduces token spend (their cost-per-correct-answer framing). This is a vendor arguing against absorption — and its necessity proves the pressure is real.
- **A router/meta layer is emerging**: Telem (route agent search across providers, inspect traces — HN 2026-08-27), OpenWebSearch router (2026-08-17), Librarium (fan-out to many search APIs — 2026-02-23), Scry's congestion-priced programmable search (HN id=49748041, 2026-09-17, 61 pts). When the market starts routing around individual search APIs on price/latency, it is treating them as commodity inputs — the commoditization side of absorption.
- **Practitioners route around first-party search too**: "I reverse-engineered Codex's web search for use with Claude and local models" (HN 2026-08-11); "Use local Chrome as a search API for coding agents" (lsearch, 2026-08-06); "Almanac MCP, turn Claude Code into a Deep Research agent" (HN 2026-04-21). Absorption is bidirectional: harness vendors absorb search; harness users extract it back out.
- **Academic support for "the harness eats the tool"**: "Is Grep All You Need? How Agent Harnesses Reshape Agentic Search" (arXiv 2605.15184, 2026-05-14; authors incl. Anmol Gulati, Vamse Kumar Subbiah) — across Chronos, Claude Code, Codex, and Gemini CLI harnesses, **grep generally beat vector retrieval**, and outcomes depended strongly on harness and tool-presentation style even on identical data. Retrieval quality is increasingly a property of the agent loop, not the retrieval endpoint. Mistral shipping `grep` as a first-class tool in Agentic Search (2026-08-20) is the same signal from a vendor.

**Synthesis (interpretation, clearly labeled):** absorption is real at the *default-tool* layer — Claude, ChatGPT/Atlas, Gemini all ship native search/browsing, and OpenAI/Google price it per-call like an API. But the standalone search API is not dying; it is **consolidating and specializing**: (1) infrastructure arms racing to own an index (Exa's $250M; Nebius buying Tavily for cloud-stack grounding); (2) agent-specific modes and contracts (Brave LLM Context + AI plans); (3) quality/cost competition measured by a now-independent benchmark (AA) that didn't exist 15 months ago. The squeeze is hardest on undifferentiated SERP proxies — Bing's retirement (2025) removed the lazy default, and the AA board's bottom is plain-mode SERP-style results.

---

## 3. Does code/UI/docs search still matter as a separate endpoint?

- **Exa deprecated the dedicated `get_code_context_exa` MCP tool on 2026-04-05** (commit 05f56822, exa-labs/exa-mcp-server — primary). Current MCP default tools are `web_search_exa` + `web_fetch_exa` only (README, checked 2026-10-19); the hosted-MCP marketing page still lists "code search" among capabilities. I.e., the *tool-shaped* code endpoint was folded into general search surfaces.
- **But Exa doubled down on the code/docs vertical**: a "Code & Docs" data-index surface with a dedicated ingestion pipeline for changelogs/issues/SDK docs (docs.exa.ai/docs/search/data/code.md, live 2026-10-19), the open-sourced **WebCode** evals (2026-03-23), and Series C claims of "finetuned special embedding models for code search" plus a code-query surge with a large jump at end-2025 (2026-05-20).
- **Dedicated docs retrieval beats model-native search on economics (vendor-shown)**: Context7 vs Claude Code's WebSearch/WebFetch (2026-05-27): ~99% input-token reduction, ~35% cost reduction, ~23% fewer tool calls on 100 documentation queries. Claude's native WebFetch summarizes via a small model and "never returns raw content" (mikhail.io, 2025-10-06) — exactly the wrong shape for version-precise API docs. Vendor-run, but the mechanism (curated, versioned corpus vs open-web fetch) is plausible and uncontested by any independent test found.
- **Against: the harness-native counter-current.** The arXiv grep paper (2026-05-14) shows grep inside agent harnesses beating vector retrieval for many tasks — for *repository-local* code search, the endpoint is being replaced by the harness itself. Mistral shipping grep in Agentic Search (2026-08-20) reinforces it.

**Verdict:** separate code/docs endpoints survive in two niches — **(a) curated, version-aware documentation** (Context7; Exa's Code & Docs vertical; grep.app still alive as of 2026-10-19, rate-limited but responding) where token economics and freshness dominate, and **(b) structured verticals** (companies/people/financial/legal data — Exa Library, Brave LLM Context). Generic "search code snippets on the web" as a distinct tool (the `get_code_context` shape) is being absorbed from below by harness grep and from above by general agent search — witness Exa's own April 2026 deprecation. Sourcegraph's public code search still resolves (live 2026-10-19) but is JS-only; its current product posture **unverified**.

---

## 4. Unverified / open items

1. **Nebius–Tavily $275M price** — press/HN figure only; not in the primary release (2026-02-10).
2. **Claude web search powered by Brave** — one HN story (2025-03-23); no party confirmation found live.
3. **AA launch→live leaderboard movement** (Parallel 75 → Exa 80 between 2026-08-18 and 2026-10-19; Perplexity joining) — real movement or variant-tuning-to-harness; cannot distinguish from public data. Single-digit provider gaps on AA should not drive procurement.
4. **Google/Microsoft absence from the AA board** — observed fact; whether they declined inclusion or weren't approached is unknown.
5. **No neutral eval of stale/long-tall retrieval** — all live benchmarks reward fresh indexes; archival quality for agents is unmeasured.
6. **Brave AI-plan pricing specifics** — plan exists (dashboard link + thread, 2026-01-30); tiers/prices not fetched.

## 5. Source index (all fetched 2026-10-19 unless noted)

**Primaries:** artificialanalysis.ai (search-api leaderboard + embedded data, articles/search-api, methodology/search-api) · exa.ai/blog (announcing-series-c, rl-search-outcomes, webcode), exa.ai/docs (llms.txt, search/data/code.md, reference/exa-mcp.md), github.com/exa-labs/exa-mcp-server (README, commit history) · nebius.com/newsroom (Tavily acquisition, 2026-02-10) · tavily.com/blog/tavily-vs-claude-web-search-when-native-search-isn-t-enough (2026-10-06) · anthropic.com/news/web-search (2025-03-20) · claude-code CHANGELOG + registry.npmjs.org (v0.2.105 = 2025-05-08) · learn.microsoft.com (Bing retirement, via HN 2025-05) · ai.google.dev/gemini-api/docs/pricing · platform.openai.com/docs/pricing · docs.perplexity.ai/changelog.md · mistral.ai/news/agentic-search/ (2026-08-20) · brave.com/search/api/ · upstash.com/blog/context7-vs-web-search-benchmark (2026-05-27) · searchspace.io/blog/comparing-ai-agent-web-search-providers (2026-06-26) · arxiv.org/abs/2605.15184 (2026-05-14) · mikhail.io/2025/10/claude-code-web-tools/ (2025-10-06)
**HN threads:** 49656926, 49359449 (AA index) · 47024216 (Nebius/Tavily) · 46822822 (Brave AI ToS) · 43450471 (Anthropic/Brave) · 44595492 (ChatGPT agent) · 45702397 (Atlas) · 49748041 (Scry) · 44050200 (Bing retirement)
