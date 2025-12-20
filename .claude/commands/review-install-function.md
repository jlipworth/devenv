# Review Installation Function

Review a specific installation function in prereq_packages.sh for correctness and completeness.

**Usage**: `/review-install-function <function_name>`

Example: `/review-install-function install_python_prereqs`

## Checklist

1. **Function Registration**
   - Is the function in the `valid_functions` array?
   - Is it called in `install_all()` if it should be?
   - Does it have a corresponding makefile target?

2. **Platform Handling**
   - Handles both macOS and Linux appropriately?
   - Uses correct package manager variables ($INSTALL_CMD, $NODE_CMD, $PIP_CMD, etc.)?
   - Platform-specific packages properly gated with OS checks?

3. **Error Handling**
   - Uses `is_installed()` check before installing?
   - Has appropriate error messages with `|| echo "Error..."`?
   - Logs with appropriate levels (INFO, SUCCESS, WARNING, ERROR)?

4. **Dependencies**
   - All required packages included?
   - Dependencies installed in correct order?
   - Uses correct installation method for each tool type?

5. **Code Quality**
   - Consistent with other install functions?
   - Clear variable names?
   - Appropriate comments for non-obvious steps?
   - No duplicated code that could use common_utils?

6. **Testing Considerations**
   - What could go wrong on a fresh install?
   - Are there version conflicts to watch for?
   - Network failures handled gracefully?

## Output

Provide a detailed review with:
- Checklist results (✓ or ✗ for each item)
- Specific issues found with line numbers
- Recommendations for improvements
- Comparison with similar functions if helpful
