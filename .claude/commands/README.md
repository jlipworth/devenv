# Claude Code Custom Commands

This directory contains custom slash commands for Claude Code to help with repository-specific tasks.

## Available Commands

### `/review-scripts`
**Purpose**: Comprehensive review of all shell scripts in the repository

**Use when**:
- Major refactoring completed
- Before a release
- Periodic code quality checks
- Onboarding review for new contributors

**What it checks**:
- Cross-platform compatibility (macOS vs Linux)
- Error handling and safety
- Dependency management
- Code quality and maintainability
- Security concerns
- Known issues and TODOs

**Example**:
```
/review-scripts
```

---

### `/review-changes`
**Purpose**: Quick review of uncommitted changes

**Use when**:
- Before committing code
- After making modifications
- Want to catch issues early

**What it checks**:
- Syntax errors
- Breaking changes
- Cross-platform issues in changes
- Consistency with existing code
- Missing related updates (makefile, arrays, etc.)

**Example**:
```
/review-changes
```

---

### `/review-install-function`
**Purpose**: Detailed review of a specific installation function

**Use when**:
- Adding a new language/tool layer
- Modifying an existing install function
- Debugging installation issues

**What it checks**:
- Proper registration (valid_functions, makefile, install_all)
- Platform handling
- Error handling and logging
- Dependencies and order
- Code quality

**Example**:
```
/review-install-function install_ai_tools
/review-install-function install_python_prereqs
```

---

### `/review-security`
**Purpose**: Security-focused code review

**Use when**:
- Before pushing security-sensitive changes
- Adding new download/install mechanisms
- Modifying SSH or credential handling
- Periodic security audits

**What it checks**:
- Command injection risks
- Privilege escalation
- Network security
- Credential management
- Path traversal
- Input validation

**Example**:
```
/review-security
```

---

## Tips

1. **Combine commands**: Run multiple reviews for comprehensive coverage
   ```
   /review-changes
   /review-security
   ```

2. **Before committing**: Always run `/review-changes` to catch issues early

3. **After adding features**: Use `/review-install-function <function_name>` to ensure completeness

4. **Periodic checks**: Run `/review-scripts` monthly or before releases

5. **Security focus**: Run `/review-security` when modifying:
   - SSH key handling
   - Download mechanisms
   - Sudo operations
   - Credential storage

## Creating New Commands

To add a new custom command:

1. Create a new `.md` file in this directory
2. Name it descriptively (e.g., `test-install.md`)
3. Write clear instructions for what Claude should do
4. Use it with `/command-name` (e.g., `/test-install`)

See existing commands for examples of effective prompts.
