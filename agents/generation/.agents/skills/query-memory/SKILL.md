---
name: query-memory
description: Retrieve previously saved immediate conclusions, toy examples, counterexamples, failed paths, branch states, big decisions, or events from memory. Use when you want to check whether earlier conclusions, examples, counterexamples, failed paths, branch states, big decisions, or events can bring insight to the current question, claim, subgoal, or branch decision, or when you want to test a claim against previously saved counterexamples.
---


# Query Memory

Use this skill when you want to check whether earlier conclusions, examples, counterexamples, failed paths, branch states, big decisions, or events can bring insight to the current question, claim, subgoal, or branch decision, or when you want to test a claim against previously saved counterexamples.

## Input Contract

Read:

- the current question, claim, subgoal, or branch decision
- the specific type of prior artifact you want to recover
- the most relevant channel list, chosen from:
  - `immediate_conclusions`
  - `toy_examples`
  - `counterexamples`
  - `failed_paths`
  - `branch_states`
  - `big_decisions`
  - `events`

## Procedure

1. Form a concrete natural-language query describing the information you want to recover.
2. Choose the smallest relevant list of channels instead of searching everything by default.
3. Call `memory_search(problem_id, query, channels=..., limit_per_channel=...)`.
4. Inspect the top hits in each requested channel.
5. Summarize the useful retrieved items and explain how they affect the current proof state.
6. If no useful item is found, say that clearly and then switch to another appropriate skill.

## Output Contract

Append a summary record to `events`:

```json
{
  "event_type": "query_memory",
  "query": "...",
  "channels": ["counterexamples", "failed_paths", "big_decisions"],
  "limit_per_channel": 10,
  "results_summary": ["..."],
  "useful_hits": [
    {
      "channel": "counterexamples",
      "score": 0.0,
      "why_relevant": "...",
      "record_excerpt": "..."
    }
  ],
  "branch_id": "optional",
  "subgoal_id": "optional"
}
```

## MCP Tools

- `memory_search`
- `memory_append`

## Failure Logging

If the retrieval is not useful, append an `events` record with:

- `event_type="query_memory_stalled"`
- the attempted query
- the channels searched
- the reason the retrieved items were not useful
