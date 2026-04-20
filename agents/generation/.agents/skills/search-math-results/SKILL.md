---
name: search-math-results
description: Find relevant math results, constructions, examples, counterexamples, and background references for a statement. Use when you need context for a new problem, supporting references for constructing examples or counterexamples, or external results while proving subgoals.
---

# Search Math Results

Use this skill as the default retrieval workflow for mathematical background and related results.

## Input Contract

Read:

- the current target statement, subgoal, lemma, or claim
- the latest preflight findings when they exist
- the search intent:
  - `theorem`
  - `construction`
  - `example`
  - `counterexample`
  - `background`
- relevant branch/subgoal context from memory

## Procedure

1. Start with `search_arxiv_theorems`.
2. When using `search_arxiv_theorems`, phrase the query as a complete mathematical statement whenever possible.
3. Inspect the returned items and decide whether they are useful for the current need.
4. If a useful theorem/example/counterexample is found and it comes from a paper, download that paper into the workspace, extract its text, and read the extracted text before relying on the result.
5. If a useful theorem is found, do not stop at the statement alone. Read the proof of that theorem as well and extract any techniques, constructions, reductions, or proof patterns that may help with the current target statement.
6. Expand the definitions and concepts appearing in that theorem using the surrounding context of the paper, and check carefully whether the theorem is actually applicable to the current situation. Be explicit about terminology that may shift across contexts.
7. Keep all downloaded PDFs and extracted text files inside `downloads/` in the current working directory.
8. Record not only what the theorem says, but also what its proof suggests for the current problem.
9. When the search is supporting preflight or reveals a mismatch, explicitly record:
   - terminology/model variants that could change the target statement
   - whether the literature supports the full target, only subclasses, or only nearby variants
   - whether the result appears conjectural, open, or still unclear
10. If the theorem search returns no useful information, switch to Codex's built-in web search.
11. Use the built-in web search either to look for specific math results or to gather background information, terminology, standard references, and canonical constructions/examples/counterexamples.
12. If the built-in web search reveals a useful paper, again download it, extract its text, and read the relevant extracted text before using it in reasoning.
13. If the built-in web search reveals a useful theorem, also read its proof, expand its local definitions from the paper context, and extract the techniques that look adaptable to the current statement.
14. Summarize the most useful findings and explain why they matter for the current proof state.
15. If a result may later be used in a proof, preserve its full statement and source identifiers so downstream proof steps can cite it explicitly.

## Usefulness Test

Treat theorem-search results as useful only if they do at least one of the following:

- provide a theorem/lemma/definition close to the target statement
- provide a construction/example/counterexample that can be adapted
- suggest a standard technique or reformulation relevant to the current branch

If the results are vague, off-topic, or too weak to guide the next step, fall back to the built-in web search.

## Output Contract

Append a summary record to `events`:

```json
{
  "event_type": "search_math_results",
  "query": "...",
  "search_intent": "theorem|construction|example|counterexample|background",
  "primary_tool": "search_arxiv_theorems",
  "fallback_used": false,
  "terminology_variants": [
    {
      "term": "...",
      "variants": ["..."],
      "why_it_matters": "..."
    }
  ],
  "status_assessment": {
    "result_status": "known_as_stated|known_only_in_subclasses|conjectural|open|unclear",
    "scope_notes": ["..."],
    "mismatch_risks": ["..."]
  },
  "results_summary": ["..."],
  "useful_references": [
    {
      "title": "...",
      "complete_statement": "...",
      "url_or_id": "...",
      "paper_id": "...",
      "arxiv_id": "...",
      "theorem_id": "...",
      "local_pdf_path": "optional",
      "local_text_path": "optional",
      "expanded_definitions": ["paper-context expansions of terms/concepts used in the statement"],
      "applicability_check": ["why the statement does or does not apply in the current setting"],
      "proof_insights": ["optional extracted techniques or ideas from the proof"],
      "why_useful": "..."
    }
  ],
  "branch_id": "optional",
  "subgoal_id": "optional"
}
```

## MCP Tools

- `search_arxiv_theorems`
- `memory_append`
- `memory_search`

## Failure Logging

If neither theorem search nor web search yields useful information, append an `events` record with:

- `event_type="search_math_results_stalled"`
- the attempted queries
- the reason the results were not useful
