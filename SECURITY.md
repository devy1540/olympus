# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in Olympus, **please do not open a public issue.**

Instead, report it privately:

1. Email: Send details to the repository owner via GitHub's private contact
2. GitHub: Use [Security Advisories](https://github.com/devy1540/olympus/security/advisories/new) to report privately

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response Timeline

- **Acknowledgment**: Within 48 hours
- **Assessment**: Within 7 days
- **Fix release**: Within 30 days for critical issues

### Scope

Olympus is a Claude Code plugin that orchestrates agents via Markdown prompts and shell hooks. The primary security concerns are:

- **Hook injection**: Malicious input that escapes shell commands in `hooks/*.sh`
- **Artifact path traversal**: File paths that escape `.olympus/` boundaries
- **Permission bypass**: Read-only agents writing files through unintended mechanisms
- **Secret exposure**: Sensitive data leaked into `.olympus/` artifacts

### Out of Scope

- Vulnerabilities in Claude Code itself (report to [Anthropic](https://www.anthropic.com/security))
- Issues with MCP servers or external tools
- Social engineering of the LLM (prompt injection against agents)
