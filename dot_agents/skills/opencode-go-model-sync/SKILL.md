---
name: opencode-go-model-sync
description: Synchronizes OpenCode Go model lists with the local opencode client config and the local bifrost proxy config on rock-3a. Use when the user asks to update opencode models, add new OpenCode Go models, refresh model lists, or keep configs in sync with upstream.
---

# OpenCode Go Model Sync

This skill synchronizes the model lists from the OpenCode Go API with two local configs:

1. `dot_config/opencode/opencode.jsonc` in the chezmoi dotfiles repo (`~/.local/share/chezmoi`)
2. `files/bifrost-config.json` in the rock-3a repo (`~/code/rock-3a`)

## When to Use This Skill

Use this skill when the user:

- Asks to "update opencode models"
- Asks to "add new models" from OpenCode Go
- Wants to sync the local bifrost proxy model list
- Mentions new models appeared on `https://opencode.ai/zen/go/v1/models`
- Wants both configs kept in sync

## Sources of Truth

- **Model list API**: `https://opencode.ai/zen/go/v1/models`
- **Pricing/docs**: `https://opencode.ai/docs/go`

## Files to Update

| File | Repo | Purpose |
|------|------|---------|
| `dot_config/opencode/opencode.jsonc` | `~/.local/share/chezmoi` | OpenCode client provider/model definitions |
| `files/bifrost-config.json` | `~/code/rock-3a` | Bifrost proxy allowed-model lists per provider |

## Step-by-Step Workflow

### 1. Fetch Upstream Model List

Use the `fetch` tool on `https://opencode.ai/zen/go/v1/models` to get the current model IDs.

### 2. Identify Providers

Map each model ID to the correct provider based on the OpenCode Go docs endpoint table:

- **OpenAI-compatible endpoint** (`/zen/go/v1/chat/completions`) → `opencode-go` provider
  - Examples: `glm-*`, `kimi-*`, `deepseek-*`, `mimo-*`, `hy3-preview`
- **Anthropic endpoint** (`/zen/go/v1/messages`) → `opencode-go-anthropic` provider
  - Examples: `minimax-*`, `qwen3.*`
- **Free models** (`/zen` endpoint) → `opencode-go-free` provider
  - Examples: `*-free`

### 3. Update the OpenCode Client Config

Edit `dot_config/opencode/opencode.jsonc`:

- Add missing models under the correct provider's `models` object.
- Use the existing entry for the same model family as a template for:
  - `family`
  - `cost` (from docs pricing table)
  - `limit` (`context` and `output` token limits)
  - `modalities`
  - `reasoning` and `interleaved` when the model supports reasoning
- Free models have zero cost, no reasoning, and typically `output: 16384`.
- Preserve existing formatting and alphabetical/version ordering within families.

### 4. Update the Bifrost Proxy Config

Edit `files/bifrost-config.json` in `~/code/rock-3a`:

- Add the new model ID to the `models` array of the matching provider under `providers.<provider>.keys[0].models`.
- Keep the array in the same order as the OpenCode client config when possible.

### 5. Validate JSON/JSONC

Verify both files remain valid (opencode.jsonc is JSON with comments; bifrost-config.json is strict JSON).

### 6. Commit and Push Both Repos

For each repo, in order:

1. `git status` and `git diff` to review changes.
2. Stage only the relevant files.
3. Commit with a clear, concise message (e.g., "Add GLM-5.2 to opencode and bifrost configs").
4. `git pull --rebase` if the remote has moved.
5. `git push origin main`.

## Example: Adding GLM-5.2

1. Fetch API and see `glm-5.2` is missing locally.
2. Add to `dot_config/opencode/opencode.jsonc` under `provider.bifrost.models`:

```json
"opencode-go/glm-5.2": {
  "name": "GLM-5.2",
  "family": "glm",
  "status": "active",
  "reasoning": true,
  "interleaved": { "field": "reasoning_content" },
  "cost": { "input": 1.4, "output": 4.4, "cache_read": 0.26 },
  "limit": { "context": 202752, "output": 32768 },
  "modalities": { "input": ["text"], "output": ["text"] }
}
```

3. Add `"glm-5.2"` to `providers.opencode-go.keys[0].models` in `files/bifrost-config.json`.
4. Commit and push both repos.

## Common Pitfalls

- **Do not** assume all models use the same endpoint. Always check the docs endpoint table.
- **Do not** forget the bifrost proxy config. The client config and proxy config must agree.
- **Do not** commit unrelated changes in either repo.
- Free models are served from `https://opencode.ai/zen` (not `/zen/go`), so they belong to the `opencode-go-free` provider in bifrost.

## Notes

- The default model in opencode.jsonc is currently `bifrost/opencode-go/deepseek-v4-flash`. Changing the default requires an explicit user request.
- If the remote repo has moved ahead, rebase before pushing.
