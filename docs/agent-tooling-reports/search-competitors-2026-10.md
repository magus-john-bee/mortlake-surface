# Agent Search API Competitors — 2026 Landscape

**Task:** AT-KT58 (agent-tooling) · **Researched:** 2026-10-19, all live sources fetched same day unless noted
**Scope:** competitive landscape of web-search APIs sold to AI-agent builders. Exa deep-dive = TH6H; evals/discourse = KSQ8.
**Method:** HN Algolia (founder/critical threads), vendor primary sources (pricing pages, docs, blogs, changelogs). Listicles used only where flagged.

---

## TL;DR — what changed and why it matters

1. **The legacy SERP-API era is ending at both incumbents.** Microsoft retired the Bing Search APIs on **Aug 11, 2025** (announced May 2025). Google's Custom Search JSON API is **closed to new customers and discontinues Jan 1, 2027** (Google docs, fetched 2026-10-19). The scrapers that filled that gap (SerpApi, Serper, SearchAPI.io) are alive but now sit in a defensive segment.
2. **Consolidation started.** Nebius agreed to acquire **Tavily** (announced **Feb 10, 2026**; value undisclosed per Nebius release — press/HN reported $275M, unverified against primary). Exa raised a **$250M Series C** (Jun 2026, after $85M Series B Sep 2025). Firecrawl announced a **$75M Series B** + "Alexandria" pivot from scraping to a broader web-data platform (site banner, Oct 2026).
3. **A price war settled the market around $1–7/1k queries.** Parallel launched **Fast mode at $1/1k** (Aug 21, 2026); Perplexity's Search API is **$5/1k ($1/1k Fast)**; Exa's tiers run **$4–12/1k**; new entrant Keenable prices at **$4/1k with up to 50 results** (Aug 2026). Frontier-lab bundled search (OpenAI, Anthropic $10/1k; Gemini grounding $14/1k) is 2–10x above the specialists.
4. **Brave became the volume story of agentic search.** ~700k OpenClaw users by **Apr 1, 2026** (Brave blog); "1M+ OpenClaw & Hermes sign-ups" (Brave site, Oct 2026). Agents must use Brave's dedicated **AI Inference plan** — standard-plan ToS prohibits AI inference (Ask HN, Jan 30, 2026).
5. **The category got an independent benchmark.** Artificial Analysis runs a live **Search API Index** (DeepSearchQA / BrowseComp / AA-Omniscience; data through Oct 19, 2026) — vendors now quote it (Parallel: "#3, Aug 2026").
6. **A 2026 counter-trend: routing and self-hosting.** Multi-provider routers (Telem, Aug 2026), Tavily-compatible self-hosted APIs (Sifthound, Sep 2026), single-binary Firecrawl alternatives (Draco, FastCRW), SearXNG-based AgentSearch. Plus experimental pricing: Scry's congestion-priced SQL-over-index (Sep 2026).

---

## Pricing snapshot (all fetched 2026-10-19 from vendor pages unless noted)

| Vendor / product | Search price | Notes, free tier |
|---|---|---|
| **Exa** (Search API) | Lite **$4** · Auto **$7** · Deep **$12** /1k; Answer $5/1k; +$1/1k per result >10 | Contents $1/1k pages; Monitors $15/1k; $10 free credits/mo |
| **Tavily** | **$8/1k** PAYG ($0.008/credit) | Free 1,000 credits/mo; $30/mo = 4k credits; 100k credits for startups; free for students |
| **Brave Search API** | Search **$5/1k** (50 QPS); Answers $4/1k + $5/M tokens | $5 free credits/mo; **separate AI Inference plan required for agents** (price unverified — dashboard-gated) |
| **Parallel Search** | Fast **$1/1k** (Aug 21, 2026); default tier ~$5/1k (third-party report) | ~700ms latency claim; "10x cheaper than frontier labs' default search" |
| **Perplexity Search API** | **$5/1k** (up to 5 queries/request); Fast **$1/1k** | Also Agent-API `web_search` tool $2.50/1k (fast $1/1k); Orchestrator token-priced, no per-request fee |
| **Linkup** | Search **$5–6/1k** ($0.005–0.006/req; Fast/Standard/Deep) | 4,000 free queries; Fetch $1–6/1k; async Research $0.25–2.50/run; SOC 2 Type II; private-cloud deploy |
| **Kagi Search API** | **$12/1k** | Extract $4/1k pages; public preview since May 23, 2026; billed at $100 accumulation |
| **Keenable** | **$4/1k**, up to 50 results | Launched Aug 2026; own 100B+ page index; claims p50 <200ms |
| **You.com** | **$5 CPM** (docs banner) | Free MCP server for agents (since ~Feb 2026); Finance Research API |
| **Firecrawl** (search endpoint) | ≈ **$1.66/1k searches** ($83/mo Standard = 100k credits = 50k searches; $0.83/1k pages scraped) | 1,000 free credits; Alexandria data providers (people data, SaaS connectors, Oct 2026) |
| **OpenAI web search tool** | **$10/1k** calls + content tokens at model rates | All models; pricing page |
| **Anthropic web search** | **$10/1k** searches + token costs | Server tool `web_search_20260209` (Feb 2026 version); errors not billed; code execution free when used with search |
| **Google Gemini grounding** | **$14/1k** after 5,000 free/mo | Grounding w/ Maps also $14/1k; shared across Gemini 3+ models |
| **Google Custom Search JSON** | $5/1k (100 free/day) | **Closed to new customers; discontinues Jan 1, 2027** |
| **SerpApi** | $25/mo = 1k; $75/mo = 5k (**$15/1k** at Developer) | U.S. Legal Shield ($2M coverage); now sells Google **AI Mode** & **AI Overview** APIs |
| **SearchAPI.io** | $4 → $3 → **$2.5/1k** by volume | 100 free; also proxies Perplexity & ChatGPT results |
| **Serper** | unverified live (JS pricing page); 2,500 free queries verified | "World's fastest & cheapest Google SERP API" positioning; ~$1/1k widely reported (listicle-tier, unverified) |
| **Jina (s.jina.ai)** | not verified live | "Search Foundation" positioning |

---

## Segment analysis

### A. Agent-native search startups (the core competitive set)

**Exa** — the reference competitor others benchmark against ("market leader" per Keenable's founder, Aug 2026). Endpoint-tiered pricing (Lite/Auto/Deep $4/$7/$12) with per-result overage above 10 results; Contents, Answer ($5/1k), Monitors, Agent ($0.012–$1.00/run). $250M Series C (Jun 2026). Recent "Exa 3.0" quality push (exa.ai, Oct 2026). *Deep dive in TH6H.*

**Tavily → Nebius** — the first real consolidation event. Nebius positions Tavily's search alongside its "Token Factory" inference: reasoning + grounding in one cloud platform (Nebius newsroom, Feb 10, 2026). Pricing page still live and unchanged in shape (credit-based, $8/1k PAYG) as of Oct 19, 2026 — no post-acquisition repricing yet. Risk to watch: Tavily's developer brand surviving inside a Nebius bundle. In Brave's self-published FreshQA run, Tavily is the most expensive per correct answer ($89/1k questions vs Brave's $18) — vendor-run numbers, treat accordingly.

**Brave** — claims "world's largest agentic search": ~700k OpenClaw users (Apr 1, 2026 blog), 1M+ OpenClaw & Hermes sign-ups, 100s of millions of daily queries, 150B cumulative, "zero dependencies on Google or Bing" (site, Oct 2026). Search $5/1k, Answers $4/1k + $5/M tokens, an "LLM Context API" for token-efficient results, and a Jan 2026-confirmed **AI Inference plan** gating agent use. Cites AIMultiple independent testing where Brave (14.89) edges Firecrawl (14.58), Exa (14.39), Tavily (13.67) — vendor-cited; KSQ8 should pull the primary. New Place Search endpoint (Feb 2026) targets Google Maps use cases at "6–7x less" cost.

**Parallel** — the aggressive discounter. Fast mode at $1/1k launched Aug 21, 2026 explicitly "as intelligent models get cheaper, web search needs to follow"; cites #3 on Artificial Analysis Search Index (Aug 2026). Trusted-by list includes Granola, Lovable, Harvey (site, Oct 2026). Positioning has widened from search API to "web infrastructure for AI agents" (search, extract, monitor, research).

**Linkup** — EU (French) player; SimpleQA-grounded accuracy marketing; differentiates on compliance: SOC 2 Type II on all plans, ZDR, and a **run-the-index-in-your-own-cloud** enterprise option (site, Oct 2026). $5–6/1k search, async Research runs $0.25–2.50.

**Kagi** — entered the market late but deliberately: Search API public preview May 23, 2026 (changelog); $12/1k premium pricing consistent with its consumer positioning ("highest quality results"); Extract at $4/1k. Lenses/domain-ranking personalization are its unique API feature.

**Keenable** — newest credible entrant (Aug 25, 2026 Show HN): own 100B+ page index, $4/1k with up to 50 results per query, sub-200ms p50 claim, founders ex-Amazon Alexa grounding + ex-Yandex search. Publishes a live comparative benchmark ("needle"). Contention: claims Parallel and Brave "may be using the same underlying search index" — unverified allegation, but consistent with Brave/Parallel both using the same index supplier; flag for follow-up.

**You.com** — pivoted from consumer search to "real-time web intelligence" APIs (Search/Answer/Contents/Research/Finance) at $5 CPM; notably ships a **free MCP search server** for agents (Show HN Feb 2026) — a land-grab via agent tooling rather than pricing.

**Firecrawl** — expanded from scraping into search + structured data. Alexandria (Oct 2026) adds live people/contact data, SaaS connectors (Notion, Slack, Figma, Stripe) and niche feeds behind one API + "Universal Scrape." $75M Series B. Appears in Brave's cited AIMultiple agent-quality ranking (2nd, above Exa) — search quality is now table stakes even for scrape-first vendors.

### B. Frontier labs bundling search into model APIs

- **OpenAI**: web search tool at **$10/1k calls** + content tokens at model rates, all models (pricing page, Oct 2026). Bundled search competes on convenience, not price.
- **Anthropic**: same **$10/1k searches** + tokens; `web_search_20260209` server-side tool (Feb 2026 refresh); free code-execution when paired with search/fetch; domain restriction controls.
- **Google**: Gemini API grounding **$14/1k** (5k free/mo) — the most expensive mainstream option; meanwhile the cheap legacy CSE JSON API ($5/1k) is being **sunset for new customers by Jan 1, 2027**, effectively pushing small users to Gemini grounding or third parties.
- **Perplexity**: the labs-vendor hybrid. Sonar API launched Jan 21, 2025; by Oct 2026 it's a platform — Orchestrator API (token-only pricing, no per-request fee), Agent API hosting third-party models (OpenAI/Anthropic/Google/xAI/…) with a $2.50/1k web_search tool, standalone Search API at $5/1k ($1/1k Fast, up to 5 queries per billed request), Embeddings, and a Decisions API. Perplexity is selling search *and* the models that consume it.

### C. SERP-scraping incumbents (post-Bing, pre-CSE-sunset beneficiaries)

- **SerpApi**: premium-priced ($15/1k at Developer tier), differentiated by "U.S. Legal Shield" ($2M legal coverage) and **new Google AI Mode / AI Overview scraping APIs** — selling the AI layer itself.
- **SearchAPI.io**: $2.5–4/1k, and now resells/proxies **Perplexity and ChatGPT results** as engines — arbitrageurs of the new layer.
- **Serper**: cheapest known (~$1/1k widely reported — unverified live; JS-gated pricing), 2,500 free queries; generic Google SERP results, no agent-specific features.
- These vendors inherit Bing/CSE refugees but face structural risk: Google ToS hostility and the specialists' better unit economics for agents.

### D. Adjacent / emerging (2026 vintage)

- **Routers**: Telem (Aug 2026) — route agent search across providers and inspect traces; a hedge against vendor lock-in and price churn.
- **Self-hosted**: Sifthound (Tavily-compatible, Sep 2026); Draco (single-binary Rust Firecrawl alternative, Aug 2026, 15 pts on HN); FastCRW (6MB binary, Jul 2026); AgentSearch (SearXNG wrapper, Apr 2026). Signal: teams bristle at per-query rent on commodity crawling.
- **Experimental**: Scry (Sep 2026, 61 pts HN) — 500TB NVMe index queryable by SQL/Datalog with congestion-based micro-auction pricing; free when uncongested. Novel economics, unproven reliability.
- **Cost disruptors**: SearchSpace claims "70x cheaper than Exa" (Jun 2026 HN, zero traction, unsubstantiated); Crustdata (YC F24) sells token-efficient search for agent budgets (Feb 2026).

---

## Claims register (provenance & confidence)

| Claim | Source (date) | Confidence |
|---|---|---|
| Bing Search APIs retired Aug 11, 2025 | Microsoft learn/azure + The Register (May 2025) | High |
| CSE JSON API closed to new customers, ends Jan 1, 2027 | developers.google.com/custom-search/v1/overview (fetched 2026-10-19) | High |
| Nebius–Tavily deal announced Feb 10, 2026; value undisclosed | nebius.com newsroom (fetched 2026-10-19) | High |
| "$275M" deal value | HN submission title (2026-02-15); absent from Nebius release | Medium — press-reported only |
| Exa $85M Series B (Sep 2025), $250M Series C (Jun 2026) | HN titles → exa.ai/blog | High (TH6H verifies) |
| Brave ~700k OpenClaw users | brave.com/blog/openclaw (Apr 1, 2026) | High (vendor metric) |
| Brave standard ToS bans AI inference; AI plan required | Ask HN 46822822 + commenters (Jan 30, 2026) | High; AI-plan price unverified |
| AIMultiple ranking Brave>Firecrawl>Exa>Tavily | Brave site citing AIMultiple (Oct 2026) | Medium — vendor-cited, primary not pulled |
| FreshQA cost figures ($18 vs $49/$84/$89) | Brave site, "methodology public" | Medium — self-published |
| Parallel Fast $1/1k, Aug 21, 2026 | parallel.ai/blog/parallel-search-fast | High |
| Keenable $4/1k, 50 results; Parallel ~$5/1k | Keenable founder HN 49435555 (Aug 25, 2026) | Medium — founder-posted |
| Parallel/Brave share an index | Keenable founder benchmark hint (Aug 2026) | Low — unverified allegation |
| OpenAI $10/1k, Anthropic $10/1k, Gemini $14/1k | vendor pricing pages (2026-10-19) | High |
| Perplexity Search $5/1k, Fast $1/1k, web_search tool $2.50/1k | docs.perplexity.ai/guides/pricing (2026-10-19) | High |
| Artificial Analysis Search Index live (DeepSearchQA, BrowseComp, AA-Omniscience) | artificialanalysis.ai/agents/search-api (data Oct 19, 2026) | High (leaderboard values JS-gated) |
| Serper ~$1/1k | listicles/word-of-mouth only | Low — unverified live |
| Cloudflare acquired Firecrawl | **disconfirmed** — no HN story, no mention on firecrawl.dev (Oct 2026) | N/A — do not repeat |

---

## Implications for our agent-tooling decisions

- **Switching costs are low and falling** (similar REST shapes, MCP servers everywhere, routers like Telem) — multi-provider support is cheap insurance against the churn this market is showing (Tavily acquisition, CSE sunset, Brave plan-gating).
- **Price benchmark for budgeting:** specialist search at $1–5/1k vs lab-bundled at $10–14/1k. If an agent does ~20 searches/task, search cost is $0.02–0.10/task on specialists vs $0.20–0.28 on lab tools — material at scale.
- **Brave's AI-plan gating** is a compliance trap: the free/standard tier's no-AI-inference clause means agents must be on the AI plan; verify plan terms before defaulting OpenClaw/Hermes-style agents to Brave.
- **Watch**: whether Nebius rebrands/reprices Tavily in 2026 H2; whether the Artificial Analysis index becomes the neutral tiebreaker (KSQ8 task); whether Keenable's index-sharing claim about Parallel/Brave gets corroborated.

*End of report — AT-KT58.*
