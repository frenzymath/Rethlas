---
name: preflight-problem-statement
description: Analyze the problem statement before proof search. Check well-posedness, notation clarity, model/variant ambiguity, and whether the target result is known as stated, only known for subclasses, conjectural, open, or still unclear. Use when starting a new problem or when the target statement changes.
---

# Preflight Problem Statement

Run this skill before proof search on a new problem or newly reframed target.

## Input Contract

Read:

- the original problem statement from the input markdown file
- any locally available context that defines the notation
- relevant prior `big_decisions`, `events`, and `failed_paths` if this is a rerun after new evidence

## Procedure

1. Restate the target claim precisely enough to inspect its quantifiers, model assumptions, and notation.
2. Check whether the statement is well-posed:
   - identify undefined symbols, missing hypotheses, unclear scope, or notation collisions
   - decide whether the current wording is proof-search ready
3. Check whether key terms may have multiple standard interpretations:
   - model variants
   - randomness models
   - graph/class restrictions
   - asymptotic conventions or parameter regimes
4. For each potentially ambiguous term, list the standard interpretations that matter and state whether the problem text resolves the choice.
5. Search for the literature status of the target:
   - known as stated
   - known only for subclasses or variants
   - conjectural
   - open
   - unclear from current evidence
6. If the literature only supports subclasses or nearby variants, explicitly distinguish those from the full target statement instead of collapsing them together.
7. Decide the gate status:
   - `pass`: statement is sufficiently clear and the target result status is compatible with writing a final proof blueprint if a proof is later found
   - `blocked_on_ambiguity`: proof search may continue only as exploratory work until the ambiguity is resolved or the target is explicitly reframed
   - `blocked_on_status_mismatch`: the gathered evidence suggests the requested target is not settled as stated, is only known in subclasses, or is conjectural/open
8. If blocked, state exactly what would resolve the block: clarification, narrowed scope, stronger evidence, or a genuinely new proof of an open problem.

## Output Contract

Append the main record to `big_decisions`:

```json
{
  "record_type": "problem_preflight",
  "target_statement": "...",
  "well_posedness": {
    "status": "clear|needs_clarification",
    "issues": ["..."]
  },
  "notation_clarity": {
    "status": "clear|needs_clarification",
    "issues": ["..."]
  },
  "ambiguous_terms": [
    {
      "term": "...",
      "standard_interpretations": ["..."],
      "resolved_by_problem_text": false,
      "impact_on_target": "..."
    }
  ],
  "result_status": "known_as_stated|known_only_in_subclasses|conjectural|open|unclear",
  "status_evidence": [
    {
      "claim": "...",
      "source": "...",
      "scope": "full_target|subclass|variant",
      "relevance": "..."
    }
  ],
  "status_mismatch": {
    "present": false,
    "description": ""
  },
  "gate_status": "pass|blocked_on_ambiguity|blocked_on_status_mismatch",
  "blocking_issues": ["..."],
  "allowed_next_actions": ["..."],
  "required_resolution": ["..."]
}
```

Also append an `events` record:

```json
{
  "event_type": "problem_preflight",
  "gate_status": "pass|blocked_on_ambiguity|blocked_on_status_mismatch",
  "result_status": "known_as_stated|known_only_in_subclasses|conjectural|open|unclear",
  "blocking_issues": ["..."],
  "required_resolution": ["..."]
}
```

If `gate_status` is not `pass`, also append to `failed_paths`:

```json
{
  "record_type": "preflight_gate_block",
  "target_statement": "...",
  "gate_status": "blocked_on_ambiguity|blocked_on_status_mismatch",
  "blocking_issues": ["..."],
  "evidence": ["..."],
  "next_actions": ["..."]
}
```

Update branch state to reflect whether the root target is currently blocked or clear for proof search.

## Tools

- `memory_search`
- `memory_append`
- `branch_update`
- `search_arxiv_theorems`
- Codex built-in web search for terminology, standard variants, and current literature status

## Failure Logging

If the literature/status search is still too weak to classify the target confidently, still append the preflight record with `result_status="unclear"` and `gate_status="blocked_on_status_mismatch"`, and state what evidence is missing.
