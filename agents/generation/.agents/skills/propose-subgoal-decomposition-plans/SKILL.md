---
name: propose-subgoal-decomposition-plans
description: Propose multiple subgoal decomposition plans for the current theorem using the information already gathered. Use when enough information has been collected from examples, counterexamples, search results, and previous failures to break the problem into several materially different plans.
---

# Propose Subgoal Decomposition Plans

Use this skill when the agent has enough context to propose several viable decomposition plans.

## Input Contract

Read:

- the current target theorem or branch goal
- relevant `immediate_conclusions`, `toy_examples`, and `counterexamples`
- relevant `failed_paths` and `branch_states`
- the latest relevant `big_decisions` and `events`, especially the preflight record
- recent search results and useful references from `events`

## Procedure

1. Confirm that the latest preflight record for the active goal has `gate_status="pass"`, or that the active goal is an explicitly narrowed variant whose scope was approved in a later preflight record.
2. If the preflight gate is blocked for the active goal, do not propose decomposition plans for that goal as if it were settled. Instead append a blocking `events` record and return.
3. Gather the current information that materially constrains the problem: useful examples, failed claims, known obstructions, and relevant search results.
4. Propose materially different decomposition plans.
5. For each plan, state:
   - the main idea of the plan
   - the ordered subgoals
   - why this plan is plausible given the current information
   - which earlier failures or counterexamples it tries to avoid
6. Hand each plan to `$direct-proving` for a quick screening pass.

## Output Contract

Append one record per plan to `subgoals`:

```json
{
  "plan_id": "...",
  "record_type": "decomposition_plan",
  "goal": "...",
  "preflight_basis": "identifier or summary of the passing preflight record",
  "plan_summary": "...",
  "subgoals": ["..."],
  "motivation": ["..."],
  "uses_information_from": {
    "examples": ["..."],
    "counterexamples": ["..."],
    "key_failures": ["..."],
    "search_results": ["..."]
  },
  "status": "proposed|screening|screened|selected|failed|solved",
  "branch_id": "optional"
}
```

Also append an `events` record summarizing the new plan set.

## MCP Tools

- `memory_search`
- `memory_append`
- `branch_update`
- `search_arxiv_theorems`

## Failure Logging

If the agent cannot yet propose meaningful decomposition plans, append an `events` record with:

- `event_type="decomposition_plans_not_ready"`
- the missing information
- the blockers that prevent proposing plans

If the latest preflight gate blocks the active goal, append an `events` record with:

- `event_type="decomposition_plans_blocked_by_preflight"`
- the blocking preflight issues
- the target statement and active scope
