# Review Recent Changes

Review the most recent changes in the repository for potential issues before committing.

## Process

1. Run `git status` and `git diff` to see what has changed
2. For each modified file, analyze:
   - Syntax errors or typos
   - Breaking changes to existing functionality
   - Cross-platform compatibility issues (macOS vs Linux)
   - Proper error handling for new code
   - Consistency with existing code style
   - Missing updates to related files (e.g., adding to makefile but not to valid_functions array)

3. Check for common mistakes:
   - Added functions not included in makefile or valid_functions
   - Package manager variables used incorrectly
   - Missing quotes around variables
   - Paths that assume specific OS
   - New dependencies not documented

## Output

Provide:
- **Summary**: Overall assessment (Ready to commit / Needs fixes / Major issues)
- **Issues Found**: List any problems with severity and file:line
- **Suggestions**: Improvements or best practices
- **Related Updates Needed**: Other files that should be updated based on changes
