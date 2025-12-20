# Security Review

Perform a security-focused review of shell scripts and configuration files.

## Security Checks

### 1. Command Injection Risks
- Unquoted variables in commands, especially with user input
- Use of `eval` with unsanitized input
- Variables used in shell commands without validation
- Filename handling without quotes

### 2. Privilege Escalation
- Unnecessary use of `sudo`
- Scripts that could be run with elevated privileges unintentionally
- File operations that change permissions
- Installation of packages without user confirmation

### 3. Network Security
- Downloads over HTTP instead of HTTPS
- Remote script execution without verification (curl | bash patterns)
- GPG key verification for package repositories
- Hardcoded URLs that could be compromised

### 4. Credential Management
- SSH keys stored securely?
- Git credentials handling
- API keys or tokens in code or config files
- Proper file permissions on sensitive files

### 5. Path Traversal
- Use of relative paths that could be exploited
- Symlink attacks in temp directories
- File operations without path validation

### 6. Input Validation
- User input used without sanitization
- Environment variables used without validation
- File existence checks before operations
- Proper handling of special characters

## Focus Areas for This Repository

- Remote script downloads in build_emacs30.sh and prereq_packages.sh
- Sudo operations throughout scripts
- Git credential configuration
- Package repository additions (Terraform, Node.js sources)

## Output Format

For each security issue:
1. **Severity**: Critical / High / Medium / Low / Info
2. **Location**: `file:line`
3. **Vulnerability**: Type and description
4. **Exploit Scenario**: How it could be exploited
5. **Fix**: Specific remediation steps
6. **Code Example**: Show vulnerable and fixed versions if helpful

Prioritize critical and high severity issues first.
