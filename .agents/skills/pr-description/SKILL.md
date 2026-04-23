# PR Description Skill

Automatically generates clear, structured pull request descriptions based on the diff and commit history of a branch.

## Overview

This skill analyzes the changes in a pull request and produces a well-formatted description including:

- A concise summary of what changed and why
- A categorized list of changes (features, fixes, refactors, etc.)
- Testing notes and any relevant caveats
- References to related issues or tickets when detectable

## Usage

This skill is triggered when a pull request is opened or when a PR description is empty or contains a placeholder.

### Inputs

| Input | Description | Required |
|-------|-------------|----------|
| `base_branch` | The target branch for the PR (e.g. `main`) | Yes |
| `head_branch` | The source branch being merged | Yes |
| `repo_path` | Path to the local repository root | No (defaults to `.`) |
| `max_diff_lines` | Maximum lines of diff to analyze | No (defaults to `500`) |

### Outputs

The skill writes a Markdown-formatted PR description to stdout and optionally updates the PR via the GitHub API if `GITHUB_TOKEN` is set.

## Configuration

Set the following environment variables to enable GitHub API integration:

```bash
export GITHUB_TOKEN=<your_token>
export GITHUB_REPOSITORY=<owner>/<repo>   # e.g. openai/openai-agents-python
export PR_NUMBER=<pr_number>
```

Without these variables the skill runs in **dry-run** mode and prints the generated description to stdout only.

## How It Works

1. Runs `git diff <base>..<head>` to collect the diff.
2. Runs `git log <base>..<head> --oneline` to collect commit messages.
3. Sends the diff summary and commit list to the configured LLM agent.
4. The agent returns structured Markdown following the project's PR template.
5. If GitHub credentials are present, the description is posted via the REST API.

## PR Template

The generated description follows this structure:

```markdown
## Summary
<one-paragraph overview>

## Changes
- **feat**: …
- **fix**: …
- **chore**: …

## Testing
<how the changes were tested or how reviewers can verify them>

## Notes
<any caveats, follow-ups, or links to issues>
```

## Agent Configuration

See [`agents/openai.yaml`](agents/openai.yaml) for the model and prompt settings used by this skill.
