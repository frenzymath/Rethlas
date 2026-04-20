---
name: recursive-proving
description: Launch one sub-agent per decomposition plan after direct screening has identified the key stuck points for each plan. Use when all current plans have been screened by direct proving, none fully solves the problem, and parallel recursive work is needed.
---

# Recursive Proving

Use this skill when direct proving has failed on the current decomposition plans.

## Input Contract

Read:

- the current set of decomposition plans
- the direct-proving reports and key stuck points for each plan
- the known stuck points from other plans
- the latest relevant `big_decisions`, especially the preflight record for the active goal
- relevant `failed_paths`, `branch_states`, and search results

## Procedure

1. Confirm that the active goal is covered by a preflight record with `gate_status="pass"`. If not, do not launch recursive proving for that goal; append a blocking event and stop this skill.
2. Confirm that all current decomposition plans have already been attempted with `$direct-proving` and that none has fully solved the problem.
3. Spawn one sub-agent per decomposition plan.
4. Give each sub-agent:
   - the full target theorem
   - the assigned decomposition plan
   - the key stuck points for its own plan
   - the key stuck points found in the other plans
   - the instruction to follow `AGENTS.md`
5. Tell each sub-agent to tackle the assigned plan under the instructions in `AGENTS.md`, treating that plan as its starting point rather than restarting the search from zero. If new evidence or discoveries justify it, the sub-agent may refine, extend, or locally revise the plan, but it should preserve continuity with the assigned plan instead of discarding it outright.
6. Tell each sub-agent that it may itself spawn sub-agents recursively if that helps its assigned plan.
7. Require each sub-agent to write progress, failures, and any successful proof development back into the shared memory using the same filename-derived `problem_id` as the MCP `problem_id`.
8. Wait for all sub-agents to finish, then gather their reports.
9. If any plan succeeds, assemble the proof draft from that plan.
10. If all plans fail, hand the collected reports to `$identify-key-failures`.

## Output Contract

Append an `events` record for the recursive round:

```json
{
  "event_type": "recursive_proving_round",
  "plan_ids": ["..."],
  "subagent_ids": ["..."],
  "shared_stuck_points": {
    "plan_id": ["..."]
  },
  "status": "running|completed",
  "successful_plan_ids": ["..."],
  "failed_plan_ids": ["..."]
}
```

Update `branch_states` with the recursive round status and per-plan outcomes.

## Tools

- `memory_search`
- `memory_append`
- `branch_update`
- `search_arxiv_theorems`
- Codex sub-agent tools: `spawn_agent`, `send_input`, `wait_agent`, `close_agent`

## Failure Logging

If every plan fails in the recursive round, append a summary record to `failed_paths` and immediately invoke `$identify-key-failures`.

If recursive proving is blocked by preflight, append an `events` record with `event_type="recursive_proving_blocked_by_preflight"`.
