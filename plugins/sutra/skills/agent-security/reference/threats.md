# Agent threat reference

The incidents and frameworks behind `/sutra:agent-security`. Each entry gives
what happened, the vector, the mitigation, and the source. Section numbers
refer to the procedure in [../SKILL.md](../SKILL.md).

## The lethal trifecta

- **What:** an agent with access to private data, exposure to untrusted
  content, and the ability to communicate externally can be tricked into
  stealing that data.
- **Vector:** instructions in content the agent reads direct it to collect the
  private data and send it out through any outbound channel.
- **Mitigation:** never combine all three in one session; remove a leg.
  Guardrail products are not a reliable fix. Section 1.
- **Source:** Simon Willison,
  https://simonwillison.net/2025/Jun/16/the-lethal-trifecta/

## GitHub MCP issue injection

- **What:** a prompt injection in a public GitHub issue led an agent using the
  GitHub MCP server to read the user's private repositories and publish their
  contents in a public pull request.
- **Vector:** one session held all three legs: public issue text, access to
  private repositories, and the ability to open pull requests. The flaw is
  architectural, not a bug in the server code.
- **Mitigation:** scope the token to the repository the task needs, and keep a
  session that reads public issues away from private access. Sections 1, 2.
- **Source:** Invariant Labs,
  https://invariantlabs.ai/blog/mcp-github-vulnerability

## MCP tool poisoning and rug pulls

- **What:** instructions hidden in an MCP tool's description or schema, which
  the model reads and the user does not. A rug pull changes a tool definition
  after the user approved it.
- **Vector:** the server's own tool metadata. A poisoned description can also
  change how the agent uses a different, trusted tool (shadowing), so the
  malicious tool need not be called.
- **Mitigation:** read the full tool descriptions, pin the server and its
  tools to a version, keep untrusted servers out of sessions that use trusted
  ones, and re-review after every update. Sections 2, 4.
- **Source:** Invariant Labs,
  https://invariantlabs.ai/blog/mcp-security-notification-tool-poisoning-attacks

## Rules File Backdoor

- **What:** attackers hide instructions in AI agent rule files with invisible
  Unicode that humans cannot see but the model reads.
- **Vector:** zero-width joiners, bidirectional text markers, and other
  invisible characters in the rule files of Cursor and GitHub Copilot. Any
  instruction file an agent loads works the same way.
- **Mitigation:** audit rule files, review them with the scrutiny given to
  executable code, and detect hidden characters with the section 3 scan. With
  `sutra-harness` installed, its security floor also scans instruction files
  at session start. Sections 3, 7.
- **Source:** Pillar Security,
  https://www.pillar.security/blog/new-vulnerability-in-github-copilot-and-cursor-how-hackers-can-weaponize-code-agents

## Trojan Source (CVE-2021-42574)

- **What:** Unicode bidirectional control characters make source display in a
  different order than the compiler reads it.
- **Vector:** a reviewer approves what the editor shows, and the compiler
  builds what the file stores.
- **Mitigation:** flag bidirectional controls in source and review the stored
  characters. With `sutra-harness` installed, its security floor reports them
  in files Claude writes or opens with Read. Section 3.
- **Source:** https://trojansource.codes/

## Unicode tag characters

- **What:** the Tags block (U+E0000-U+E007F) mirrors printable ASCII (U+E0041
  is TAG LATIN CAPITAL LETTER A) and renders as nothing, so a model can
  receive text a reviewer cannot see.
- **Vector:** any text the agent reads: a file, an issue, a web page, or a
  tool description.
- **Mitigation:** the section 3 scan finds tag characters in files, and with
  `sutra-harness` installed its security floor reports them; decode a hit by
  subtracting 0xE0000 from each code point. Section 3.
- **Source:** the Unicode Tags chart,
  https://www.unicode.org/charts/PDF/UE0000.pdf

## Nx "s1ngularity" compromise

- **What:** malicious Nx package versions ran a postinstall script that
  searched the machine for secrets, tried local AI coding CLIs to help, and
  published the results to a public GitHub repository.
- **Vector:** the attackers took the project's npm token through a GitHub
  Actions workflow injection, then shipped an install-time script that ran
  with each user's privileges.
- **Mitigation:** pin dependency versions and read install scripts, and never
  put pull request text into a shell step of a workflow that runs with secrets
  (the Nx workflow used `pull_request_target`, which runs with the target
  branch's permissions). The postmortem's remediation: check your GitHub
  security log for unexpected repositories, revoke GitHub CLI access and
  refresh GitHub tokens, and check shell config for suspicious additions.
  Sections 6, 7, 8.
- **Source:** https://nx.dev/blog/s1ngularity-postmortem

## ToxicSkills

- **What:** Snyk's scan of 3,984 agent skills found 534 (13.4 percent) with a
  critical issue and 76 confirmed malicious payloads.
- **Vector:** a skill is instructions plus scripts that run with the agent's
  privileges, so installing one installs code.
- **Mitigation:** read every file in a skill before installing it, pin it,
  and re-review after updates. Section 4.
- **Source:** Snyk,
  https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/

## Claude Code advisories

- **What:** Claude Code itself ships security fixes, for example
  GHSA-xq4m-mc3c-vvg3, a shell-parsing bypass of read-only validation, fixed
  in 1.0.93.
- **Vector:** a flaw in the agent's own command validation.
- **Mitigation:** keep Claude Code current, and treat permission rules as one
  layer beneath the sandbox or a container, not the only boundary. Section 5.
- **Source:** https://github.com/advisories/GHSA-xq4m-mc3c-vvg3

## OWASP risk lists

The OWASP Top 10 for LLM Applications 2025 includes LLM01 Prompt Injection,
LLM03 Supply Chain, and LLM06 Excessive Agency
(https://genai.owasp.org/llm-top-10/). OWASP also publishes a Top 10 for
Agentic Applications
(https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/).

| OWASP risk | Sutra control | Skill section |
| --- | --- | --- |
| LLM01 Prompt Injection | Untrusted input treated as data, and the section 3 scan for hidden characters. With `sutra-harness`: the untrusted-content card after the first WebFetch or WebSearch, and hidden-Unicode warnings on files Claude writes or opens with Read and on instruction files at session start | 1, 2, 3 |
| LLM03 Supply Chain | The vetting procedure for plugins, MCP servers, and skills; `/sutra:security-hygiene` for dependencies | 4, 7 |
| LLM06 Excessive Agency | Read-only subagents limited to Read, Grep, and Glob; deny rules, the sandbox, and scoped tokens | 1, 5, 6 |

## Claude Code behavior the skill relies on

- Plugin capabilities, review commands, and uninstall:
  https://code.claude.com/docs/en/plugins/security
- Plugin component files and manifest keys:
  https://code.claude.com/docs/en/plugins/components
- Prompt-injection safeguards, the working-directory boundary, and MCP review:
  https://code.claude.com/docs/en/security
- Read deny rules, Bash rule limits, and what `claude -p` runs without trust:
  https://code.claude.com/docs/en/permissions
- Sandbox scope and settings: https://code.claude.com/docs/en/sandboxing
- `--dangerously-skip-permissions` in a container and egress restriction:
  https://code.claude.com/docs/en/devcontainer
- Command hooks run shell commands with your full permissions:
  https://code.claude.com/docs/en/hooks
