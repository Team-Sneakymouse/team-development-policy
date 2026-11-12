# Retired canonical texts

Earlier canonical versions of the files `sync-stubs.ps1` and `sync-stubs.sh` write. The scripts replace an existing file, block or paragraph only when it matches the current canonical text in `adapters/examples/` or one of these, after line endings are normalised and surrounding whitespace is trimmed. Anything else is reported and left alone.

- `bootstrap/`: managed `AGENTS.md` blocks, markers included.
- `legacy-bootstrap/`: the pre-marker bootstrap paragraphs in `AGENTS.md`.
- `claude/`, `copilot/`, `cursor/`: `CLAUDE.md`, `.github/copilot-instructions.md` and `.cursor/rules/team-policy.mdc` pointer stubs.

When you change a canonical file in `adapters/examples/`, copy its current text here first as the next number. Never add a file that carries project-specific instructions: those files must stay as they are and be merged by hand.
