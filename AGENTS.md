# Agent Instructions

This is a port of golang <https://github.com/charmbracelet/colorprofile> to
Crystal language. Since it is a port, all logic must match the golang
implementation only differing in Crystal language idioms and libs. If you have
a question, the go code is the source of truth. We want to port all go code and
go tests. The golang src is available at ./vendor/

## Project Structure

The Go colorprofile library consists of:

- `profile.go` - Profile type definition and Convert method
- `env.go` - Color profile detection from environment variables and TTY
- `env_other.go` / `env_windows.go` - Platform-specific implementations
- `writer.go` - Writer for automatic color downsampling
- Test files (`*_test.go`)

## Go Dependencies

The Go library depends on:
- `github.com/charmbracelet/x/ansi` - ANSI escape sequence parsing
- `github.com/charmbracelet/x/term` - Terminal detection
- `github.com/lucasb-eyer/go-colorful` - Color manipulation
- `github.com/xo/terminfo` - Terminfo database access
- `golang.org/x/sys/windows` - Windows-specific APIs

For Crystal, we need to find equivalent shards or port these dependencies.

## Crystal Development Guidelines

This is a Crystal port of the Go code from `./vendor/`. Follow Crystal idioms
and best practices:

- Use Crystal's built-in formatter: `crystal tool format`
- Use ameba for linting: `ameba --fix` then `ameba` to verify
- Prefer Crystal's standard library over custom implementations
- Use Crystal's type system effectively (avoid unnecessary `as` casts)
- Follow Crystal naming conventions (snake_case for methods/variables, CamelCase
  for classes/modules)
- Write specs for new functionality using Crystal's built-in spec framework

### Test Porting Guidelines

When porting Go tests to Crystal specs:

1. **Port test logic exactly** - Don't adjust test assertions or expected values
2. **Use Crystal idioms for structure** - Convert Go test tables to Crystal `it`
   blocks
3. **Mark missing functionality as pending** - Use `pending` for tests that
   can't run yet
4. **Follow Go test patterns** - Maintain the same test coverage and edge cases
5. **Verify against Go implementation** - Ensure Crystal behavior matches Go
   exactly

## File System Guidelines

- Use `./temp` directory for temporary files created during testing or
  development
- Never commit temporary files to git (they are already in `.gitignore`)
- Clean up temporary files after use (the `make clean` rule removes `./temp`
  contents)

## Quality Gates

Before committing changes, run these quality gates:

```bash
crystal tool format --check
ameba --fix
ameba
crystal spec
```

Ensure no formatting issues remain, all ameba errors are fixed, and all tests
pass before committing.

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT
complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs
   follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:

   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```

5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**

- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
