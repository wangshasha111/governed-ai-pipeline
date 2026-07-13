# Automation Leverage Analysis

*Companion to [`workflow-map.md`](workflow-map.md). Each step of the developer workflow is
scored with the **Automation Leverage Framework** to decide where an AI command pays off most.*

## Scoring framework

Each workflow step is rated on four axes:

- **Frequency** — how often the step recurs (`daily` / `weekly` / `monthly`).
- **Time per occurrence** — minutes spent each time (from the workflow map).
- **AI capability** — how well current AI tooling can do the work (`low` / `med` / `high` / `very high`).
- **ROI score (1–10)** — composite of the three above: *how much leverage do we get per unit of
  effort to automate it?* Roughly `ROI ≈ frequency_weight × time × ai_capability`, normalised to 1–10.

A step scores high only when **all three** align: it happens often, it eats real time, *and* AI
can actually do it well. A slow-but-rare step, or a frequent-but-AI-can't-help step, both score low.

## The scorecard

| # | Step | Frequency | Time / occ. | AI capability | ROI (1–10) |
|---|------|-----------|------------:|---------------|:----------:|
| 1 | Ticket Pickup | daily | 10 min | low | **2** |
| 2 | Understanding | daily | 45 min | high | **7** |
| 3 | Implementation | daily | 120 min | high | **6** |
| 4 | **Testing** | daily | 60 min | very high | **9** |
| 5 | **Review** | daily | 40 min | very high | **9** |
| 6 | **Merge (commit + PR + changelog)** | daily | 15 min | very high | **8** |
| 7 | Deploy | weekly | 25 min | med | **5** |

### Why each score

- **Ticket Pickup (2)** — daily, but short and mostly human judgement (priority, stakeholder
  intent). AI can summarise a thread but can't decide what matters. Low leverage.
- **Understanding (7)** — daily and expensive; AI is strong at code search and explanation. High
  value, but it's *assistive* (still needs a human in the loop), not a one-shot command — so it
  rides along inside the other commands rather than being its own target.
- **Implementation (6)** — the biggest time sink, and AI helps a lot, but it's inherently
  interactive and creative. Already well-served by Claude Code in-editor; hard to reduce to a
  single deterministic command. Real but diffuse leverage.
- **Testing (9)** — daily, 60 min, and *highly* mechanical: generating test cases, fixtures and
  headless acceptance runs from existing code is squarely in AI's wheelhouse. Top target.
- **Review (9)** — daily, 40 min, and pattern-driven (correctness bugs, cross-module
  regressions, style). AI review is fast, tireless, and catches the blind spots self-review
  misses. Top target.
- **Merge (8)** — daily, short, but *every single change* needs a good commit message, PR body
  and changelog entry (a hard team rule). Perfectly templatable. High leverage precisely
  because it's frequent and rote.
- **Deploy (5)** — only weekly and already scripted; the risky parts (branch→env discipline,
  staging isolation) are judgement calls where AI assists but shouldn't act autonomously.
  Medium leverage.

## Top 3 automation targets

Ranked by ROI, the three steps to build commands for:

### 🥇 1. Review → `/review`
**ROI 9.** Runs on every change, every day. AI review is genuinely at "very high" capability:
it catches correctness bugs, cross-module ripple regressions (the recurring hazard in a codebase
whose domain modules share one computation core), and convention violations far faster and more
consistently than tired self-review. Removing reviewer-latency alone reclaims a big chunk of the
40 min.

### 🥈 2. Testing → `/test-gen`
**ROI 9.** Also daily, and even more mechanical. Generating pytest cases, fixtures and headless
acceptance checks from the code that was just written is exactly what AI does well — and it
directly attacks the "tests are tedious to write" pain point. Turns 60 min of grind into a
review-and-adjust pass.

### 🥉 3. Merge / ship path → `/commit` + `/ship`
**ROI 8.** Short per occurrence but *unavoidable on every change*, rule-bound (commit
conventions, mandatory changelog entry, branch→env discipline) and fully templatable. One
command that writes the commit message, the PR body and the changelog entry — and refuses to
push when review or tests are red — removes the most repetitive, error-prone friction in the
whole flow.

### Why these three (and not Understanding/Implementation)

Understanding and Implementation score respectably, but they are **assistive and interactive** —
best served by Claude Code sitting *inside* the editing loop, not by a discrete slash command.
The Top 3 are chosen because they are **discrete, repeated, rule-bound sub-tasks** that a single
command can own end to end:

| Target | Command | Attacks |
|--------|---------|---------|
| Review | `/review` | reviewer latency, self-review blind spots, convention regressions |
| Testing | `/test-gen` | tedious test authoring, missing acceptance coverage |
| Merge / ship | `/commit`, `/ship` | commit & PR messages, changelog discipline, manual ship steps |

Together they cover the **~115 min/day** of the most automatable work in the developer's flow.
`/onboard` is a fourth command outside this ranking: it doesn't run daily, but it targets the
same "Understanding" cost — paid once per new hire instead of once per change.
