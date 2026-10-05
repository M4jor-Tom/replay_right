---
description: Execute a functional browser command against the keyfarm jailed browser while maintaining the mirrored Playwright script.
argument-hint: <functional-command.md> [cookies-dir] [script.ts]
---

# keyfarm-maintain

You maintain a Playwright script (`run(page)`) so it stays a deterministic mirror
of a hand-written **functional command**, while executing that command against
keyfarm's **jailed Firefox** browser.

**Inputs** (from `$ARGUMENTS`, with defaults):
- functional command file (required) — natural-language browser steps
- cookies dir — default `./cookies`
- target script — default `./task.ts`

**Do this:**

1. **Read** the functional command file. Note its numbered steps and Success criteria.
2. **Ensure a warm profile.** If the cookies dir has no session for the target
   site, tell the user to open `nix run .#browser -- <cookies-dir>`, log in by
   hand, and close it. Do not automate credential entry.
   Note: in a downstream consumer flake, `apps.default` alone won't expose this —
   the consumer flake must also re-export keyfarm's `browser` app (see
   `templates/consumer-flake.nix`) for `nix run .#browser` to resolve.
3. **Explore live.** Use the jailed Firefox to inspect the page and iterate with
   small `run(page)` scripts to work out selectors and flow for each step. Prefer
   resilient locators (roles/text) over brittle CSS.
4. **Mirror into the script.** Create or update the target `run(page)` script so
   each functional step maps to a code block prefixed `// step N:` matching the
   functional command's numbering. Keep it minimal — no dead branches.
5. **Verify deterministically.** Close the headful browser (profile is single-lock),
   then run `nix run .#run -- <cookies-dir> <script.ts>`. It must complete and the
   Success criteria must hold. Iterate until green.
6. **Report** the mirror status: which steps are covered, anything the functional
   command left ambiguous, and any authentication or browser challenges encountered.

**Rules:**
- Never weaken the jail or profile isolation to "make it work."
- The functional command is the source of intent; the script is its deterministic
  shadow. If they drift, fix the script, and flag the functional command if a step
  is now wrong.
- Turnstile is not solvable by clicking/vision. A warm profile may help; if blocked,
  report it and do not add captcha-solving.
