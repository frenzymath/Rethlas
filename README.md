# Rethlas

Rethlas is a natural-language reasoning system for mathematics built around two Codex agents:

- The generation agent reads a math problem from a markdown file and writes an informal proof blueprint.
- The verification agent checks that proof blueprint, produces a structured verdict, and serves as the generation agent's verifier.

The intended deployment order is:

1. Start the verification agent as a local HTTP service.
2. Run the generation agent through Codex.
3. Let the generation agent call the verification service during its proof-and-repair loop.

## Repository Layout

- `agents/generation`: the proof-generation agent
- `agents/verification`: the proof-verification agent

In particular, 
- Original problems are put in `agents/generation/data/`, e.g. unclassified problem `agents/generation/data/example.md`, or classfied problem `agents/generation/data/modrep/modrep.md`, `agents/generation/data/example/example1.md`.
- Zola project to render the results in a static website is in `agents/generation/site/`.

## 1. Install Codex CLI

Install the Codex CLI:

```bash
npm install -g @openai/codex
```


## 2. Clone the Repository

```bash
git clone https://github.com/frenzymath/Rethlas.git
cd Rethlas
```

## 3. Start the Verification Service


```bash
cd agents/verification
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn api.server:app --host 0.0.0.0 --port 8091
```

Using uv
```bash
cd agents/verification
uv venv 
uv pip install -r requirements.txt
uv run uvicorn api.server:app --host 0.0.0.0 --port 8091
```

## 4. Run the Generation Agent on the Included Example


```bash
cd agents/generation
python3 -m venv .venv
source .venv/bin/activate
pip install -r mcp/requirements.txt
./tests/run_example.sh
```

This script:

- reads `agents/generation/data/example.md`
- runs `codex exec` inside `agents/generation`
- resumes the same Codex session for up to `MAX_ITERATIONS` iterations, alternating search-disabled and search-enabled continuation turns
- stops when `agents/generation/results/example/blueprint_verified.md` is produced
- writes iteration logs to `agents/generation/logs/example/iter/`
- writes memory artifacts to `agents/generation/memory/example/`
- writes the draft proof to `agents/generation/results/example/blueprint.md`
- writes the verified proof to `agents/generation/results/example/blueprint_verified.md` if verification succeeds

You can set the maximum number of iterations:

```bash
MAX_ITERATIONS=10 ./tests/run_example.sh
```

## 5. Run Your Own Problem

Put your problem in a markdown file under `agents/generation/data/`. Save that as:

```text
agents/generation/data/my_problem.md
```

Then run:

```bash
cd agents/generation
source .venv/bin/activate
PROBLEM_FILE=data/my_problem.md ./tests/run_example.sh
```

You can group problems in subdirectories under `data/` and the generated artifacts preserve that structure. For example:

```bash
PROBLEM_FILE=data/modrep/modrep.md ./tests/run_example.sh
```

To attach user-provided references to a problem (this is optional; use it when you are working on your own research problem and want to provide the agent with unreleased notes), create a sibling reference directory with the same stem:

```text
agents/generation/data/modrep/modrep.refs/
```

When that directory exists, the generation agent reads its files before using external search.
Reference files may be markdown, LaTeX, plain text, or PDF, but markdown, LaTeX and plain text is prefered over PDF. Actually, PDFs are converted to extracted text under `.extracted/` before the agent runs.

The runner writes:

- iterations to `logs/<problem_id>/iter/`
- durable memory to `memory/<problem_id>/`
- drafts and accepted output to `results/<problem_id>/`

It never overwrites an existing iteration log.

`CODEX_HOME` selects the Codex home used by the wrapper; it otherwise uses `$HOME/.codex`.

## 6. Dry run

Validate paths, settings, prior logs, recovered session ID, next iteration, and pause/stop locations without starting Codex or contacting the verifier:

```sh
DRY_RUN=1 PROBLEM_FILE=data/example.md ./tests/run_example.sh
```

`DRY_RUN` must be `0` or `1`.

## 7. Resume

Run the same command again. The runner scans existing iteration logs, finds the next unused iteration number, recovers the Codex session ID, and resumes that session. `MAX_ITERATIONS` is the number of additional iterations for this invocation.

```sh
MAX_ITERATIONS=4 PROBLEM_FILE=data/example.md ./tests/run_example.sh
```

If logs contain no recoverable session ID or conflicting IDs, the run fails closed. Supply the intended session explicitly only when you have checked it:

```sh
SESSION_ID=replace_with_session_id PROBLEM_FILE=data/example.md ./tests/run_example.sh
```

Use `LOG_DIR` only when deliberately selecting a different log history.

## 8. Pause after the active iteration

While the runner is active, create its pause marker from another terminal:

```sh
mkdir -p agents/generation/results/example
touch agents/generation/results/example/PAUSE_AFTER_ITERATION
```

The current Codex invocation is allowed to finish, then the loop stops before another iteration. Remove the marker before resuming:

```sh
rm agents/generation/results/example/PAUSE_AFTER_ITERATION
```

Set `PAUSE_FILE` to use a different marker. A marker already present at startup is treated as an error so a stale pause cannot silently look like a successful run.

## 9. Search schedule and completion

After the initial turn, odd-numbered iterations disable web and arXiv search; even-numbered iterations allow search. Resumed runs retain this iteration-number schedule. The runner exits successfully when `blueprint_verified.md` exists, or when a requested pause is observed. Exhausting the added iteration budget without a verified proof exits nonzero.

The wrapper invokes Codex with approval and sandbox bypass. Run it only in a checkout and environment you trust, and review the agent instructions and MCP configuration first.

## 10. View Results in the Browser

- `agents/generation/site`: Zola site for browsing results in the browser

Results are markdown files with LaTeX math. To render them properly, a local [Zola](https://www.getzola.org/) site using the [MATbook](https://www.getzola.org/themes/matbook/) theme is included.

### Prerequisites

Install Zola.

Zola can be easily installed using your package manager in terminal. For example, on Mac, you simply run

```bash
brew install zola
```

and on ArchLinux, run

```bash
sudo pacman -S zola
```

For other operating systems, please see [Zola installation](https://www.getzola.org/documentation/getting-started/installation/).

### Serve

From `agents/generation/`:

```bash
./site/serve.sh
```

On first run this automatically clones the [MATbook](https://www.getzola.org/themes/matbook/) theme. Then it syncs all results from `results/` into the site and starts a local server. Open http://localhost:3264 in your browser.

Each problem  in `agents/generation/data/your_category`  will be a section in a chapter called `your_category`, while problems directly in `agents/generation/data` will be under `unclassified` chapter.

### Update the MATbook Theme

```bash
./site/setup_theme.sh
```

This pulls the latest version from the [MATbook repository](https://github.com/srliu3264/MATbook).


