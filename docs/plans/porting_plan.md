# Colorprofile Porting Plan

This document tracks the complete port of `github.com/charmbracelet/colorprofile` from Go to Crystal.

## Overview

The Go colorprofile library provides terminal color profile detection and automatic color downsampling. This port uses the `dsisnero/ansi` Crystal library for ANSI handling.

## Source Files Analysis

### 1. `profile.go`

**Constants:**
- [x] `Unknown Profile = iota` - Profile enum variant
- [x] `NoTTY` - Profile enum variant
- [x] `ASCII` - Profile enum variant
- [x] `ANSI` - Profile enum variant
- [x] `ANSI256` - Profile enum variant
- [x] `TrueColor` - Profile enum variant
- [x] `Ascii = ASCII` - Backwards compatibility alias

**Global Variables:**
- [x] `cache` - Color conversion cache (map[Profile]map[color.Color]color.Color)
- [x] `mu` - RWMutex for cache synchronization

**Types:**
- [x] `Profile` - byte enum for color profiles

**Methods:**
- [x] `(p Profile) String() string` - Returns string representation
- [x] `(p Profile) Convert(c color.Color) color.Color` - Converts color to profile's supported colors

**Port Status:** COMPLETE
**Crystal Location:** `src/colorprofile/profile.cr`

---

### 2. `env.go`

**Constants:**
- [x] `dumbTerm = "dumb"` - Constant for dumb terminal check

**Types:**
- [x] `environ` - map[string]string alias for environment variables

**Functions:**
- [x] `Detect(output io.Writer, env []string) Profile` - Detects profile from output and env
- [x] `Env(env []string) Profile` - Returns profile from environment only
- [x] `colorProfile(isatty bool, env environ) Profile` - Internal profile detection logic
- [x] `envNoColor(env environ) bool` - Checks NO_COLOR env var
- [x] `cliColor(env environ) bool` - Checks CLICOLOR env var
- [x] `cliColorForced(env environ) bool` - Checks CLICOLOR_FORCE env var
- [x] `isTTYForced(env environ) bool` - Checks TTY_FORCE env var
- [x] `colorTerm(env environ) bool` - Checks COLORTERM env var for truecolor
- [x] `envColorProfile(env environ) Profile` - Infers profile from environment
- [x] `Terminfo(term string) Profile` - Returns profile based on terminfo database [Blocking issue: #1](https://github.com/dsisnero/colorprofile/issues/1) | BD: colorprofile-d62
- [x] `Tmux(env []string) Profile` - Returns profile based on tmux info output
- [x] `tmux(env environ) Profile` - Internal tmux detection

**Type Methods:**
- [x] `(e environ) lookup(key string) (string, bool)` - Lookup env var with existence check
- [x] `(e environ) get(key string) string` - Get env var (empty if not exists)

**Port Status:** PARTIALLY COMPLETE
**Crystal Location:** `src/colorprofile/env.cr`
**Blocking Issue:** [#1](https://github.com/dsisnero/colorprofile/issues/1) | **BD Issue:** colorprofile-d62

**Notes:**
- Terminfo database lookup not fully implemented (depends on external library)
- Tmux detection uses command execution

---

### 3. `env_other.go`

**Functions:**
- [x] `windowsColorProfile(env map[string]string) (Profile, bool)` - Platform stub for non-Windows

**Port Status:** COMPLETE
**Crystal Location:** `src/colorprofile/env.cr` (using Crystal compile-time flags)

---

### 4. `env_windows.go`

**Functions:**
- [ ] `windowsColorProfile(env map[string]string) (Profile, bool)` - Windows-specific detection
  - [ ] ConEmuANSI check
  - [ ] Windows version detection via RtlGetNtVersionNumbers
  - [ ] ANSICON version checking
  - [ ] Build number-based profile detection

**Port Status:** NOT PORTED
**Crystal Location:** `src/colorprofile/env.cr` (simplified version exists)
**Blocking Issue:** [#2](https://github.com/dsisnero/colorprofile/issues/2) | **BD Issue:** colorprofile-adg

**Notes:**
- Requires Windows-specific APIs
- Currently has simplified implementation that assumes TrueColor

---

### 5. `writer.go`

**Functions:**
- [x] `NewWriter(w io.Writer, environ []string) *Writer` - Creates new Writer with detected profile
- [x] `handleSgr(w *Writer, p *ansi.Parser, buf *bytes.Buffer)` - Handles SGR sequences

**Types:**
- [x] `Writer` - struct with Forward (io.Writer) and Profile fields

**Methods:**
- [x] `(w *Writer) Write(p []byte) (int, error)` - Writes bytes with color downsampling
- [x] `(w *Writer) downsample(p []byte) (int, error)` - Performs actual downsampling
- [x] `(w *Writer) WriteString(s string) (n int, err error)` - Writes string

**Port Status:** COMPLETE
**Crystal Location:** `src/colorprofile/writer.cr`

**Notes:**
- All SGR handling implemented (foreground, background, underline colors)
- Supports 3/4-bit, 8-bit, and 24-bit colors
- Handles bright colors (90-97, 100-107)

---

### 6. `doc.go`

**Port Status:** NOT NEEDED
**Notes:** Package documentation - covered in README.md

---

## Test Files Analysis

### 1. `profile_test.go`

**Test Functions:**
- [x] `TestHexTo256(t *testing.T)` - Tests color conversion to 256 colors
  - [x] "white" - White color conversion
  - [x] "offwhite" - Off-white color conversion
  - [x] "slightly brighter than offwhite" - Edge case
  - [x] "red" - Red color conversion
  - [x] "silver foil" - Gray conversion edge case
  - [x] "silver chalice" - Gray conversion edge case
  - [x] "slightly closer to silver foil" - Edge case
  - [x] "slightly closer to silver chalice" - Edge case
  - [x] "gray" - Gray conversion
- [x] `TestDetectionByEnvironment(t *testing.T)` - Tests profile detection
  - [x] "TERM is set to dumb"
  - [x] "TERM set to xterm"
  - [x] "TERM is set to rio"
  - [x] "TERM set to xterm-256color"
- [x] `TestCache(t *testing.T)` - Tests color caching
  - [x] "red" - Red color caching
  - [x] "grey" - Grey color caching
  - [x] "white" - White color caching
  - [x] "light burgundy" - Indexed color caching
  - [x] "truecolor" - TrueColor passthrough
  - [x] "offwhite" - Offwhite conversion

**Port Status:** PARTIALLY COMPLETE
**Crystal Location:** `spec/colorprofile_spec.cr`
**Blocking Issue:** [#5](https://github.com/dsisnero/colorprofile/issues/5) | **BD Issue:** colorprofile-8m2

**Notes:**
- Basic enum tests ported
- Full color conversion tests with colorful library needed

---

### 2. `env_test.go`

**Test Functions:**
- [x] `TestEnvColorProfile(t *testing.T)` - Tests environment-based detection
  - [x] "empty" - Empty environment
  - [x] "no tty" - TERM=dumb
  - [x] "dumb term, truecolor, not forced" - COLORTERM=truecolor
  - [x] "dumb term, truecolor, forced" - With CLICOLOR_FORCE
  - [x] "dumb term, CLICOLOR_FORCE=1"
  - [x] "dumb term, CLICOLOR=1"
  - [x] "xterm-256color"
  - [x] "xterm-256color, CLICOLOR=1"
  - [x] "xterm-256color, COLORTERM=yes"
  - [x] "xterm-256color, NO_COLOR=1"
  - [x] "xterm"
  - [x] "xterm, NO_COLOR=1"
  - [x] "xterm, CLICOLOR=1"
  - [x] "xterm, CLICOLOR_FORCE=1"
  - [x] "xterm-16color"
  - [x] "xterm-color"
  - [x] "xterm-256color, NO_COLOR=1, CLICOLOR_FORCE=1"
  - [x] "Windows Terminal" - WT_SESSION
  - [x] "Windows Terminal bash.exe"
  - [x] "screen default" - TERM=screen
  - [x] "screen colorterm" - screen with COLORTERM
  - [x] "tmux colorterm" - tmux with COLORTERM
  - [x] "tmux 256color" - tmux-256color
  - [x] "ignore COLORTERM when no TERM is defined"
  - [x] "direct color xterm terminal" - xterm-direct

**Port Status:** COMPLETE
**Crystal Location:** `spec/colorprofile_spec.cr` (all 24 test cases ported and passing)
**Blocking Issue:** [#3](https://github.com/dsisnero/colorprofile/issues/3) | **BD Issue:** colorprofile-vl8

---

### 3. `writer_test.go`

**Test Functions:**
- [ ] `TestWriter(t *testing.T)` - Tests Writer functionality
  - [ ] "empty"
  - [ ] "no styles"
  - [ ] "simple style attributes" (bold)
  - [ ] "simple ansi color fg" (31m)
  - [ ] "default fg color after ansi color" (39m)
  - [ ] "ansi color fg and bg" (31;42m)
  - [ ] "bright ansi color fg and bg" (91;102m)
  - [ ] "simple 256 color fg" (38;5;196m)
  - [ ] "256 color bg" (48;5;196m)
  - [ ] "simple true color bg" (38;2;255;133;55m)
  - [ ] "itu true color bg" (38:2::255:133:55m)
  - [ ] "simple ansi 256 color bg" (48:5:196m)
  - [ ] "simple missing param"
  - [ ] "color with other attributes"
- [ ] `TestNewWriterPanic(t *testing.T)` - Tests NewWriter doesn't panic
- [ ] `TestNewWriterOsEnviron(t *testing.T)` - Tests with os.Environ()
- [ ] `BenchmarkWriter(b *testing.B)` - Performance benchmark

**Port Status:** NOT PORTED
**Crystal Location:** Need comprehensive writer tests
**Blocking Issue:** [#4](https://github.com/dsisnero/colorprofile/issues/4) | **BD Issue:** colorprofile-13l

---

## Example Files

### 1. `examples/colors/main.go`

**Functions:**
- [ ] `printBlock(c ansi.Color, fg ansi.Color)` - Prints colored blocks
- [ ] `main()` - Displays color palette

**Port Status:** NOT PORTED
**Notes:** Example/demo code - nice to have but not critical

---

### 2. `examples/profile/main.go`

**Functions:**
- [ ] `colorToHex(c color.Color) string` - Converts color to hex string
- [ ] `main()` - Demonstrates profile detection and conversion

**Port Status:** NOT PORTED
**Notes:** Example/demo code - nice to have but not critical

---

### 3. `examples/writer/writer.go`

**Functions:**
- [ ] `main()` - Stdin to stdout color degradation pipe

**Port Status:** NOT PORTED
**Notes:** Example/demo code - nice to have but not critical

---

## Port Completion Summary

### Core Functionality

| Component | Status | Notes |
|-----------|--------|-------|
| Profile enum | COMPLETE | All profiles defined |
| Profile.String() | COMPLETE | String representations |
| Profile.Convert() | COMPLETE | With caching |
| Detect() | COMPLETE | Environment detection |
| Env() | COMPLETE | Environment-only detection |
| Writer | COMPLETE | With downsampling |
| NewWriter() | COMPLETE | Factory function |
| Writer.Write() | COMPLETE | All profiles handled |
| Writer.WriteString() | COMPLETE | Implemented |
| Terminfo() | PARTIAL | Stub implementation |
| Tmux() | COMPLETE | Command execution |

### Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Unix/Linux | COMPLETE | Full support |
| macOS | COMPLETE | Full support |
| Windows | PARTIAL | Simplified detection ([#2](https://github.com/dsisnero/colorprofile/issues/2)) | BD: colorprofile-adg |

### Test Coverage

| Test File | Status | Coverage |
|-----------|--------|----------|
| profile_test.go | PARTIAL | Basic tests only ([#5](https://github.com/dsisnero/colorprofile/issues/5)) | BD: colorprofile-8m2 |
| env_test.go | COMPLETE | 24 test cases ported and passing ([#3](https://github.com/dsisnero/colorprofile/issues/3)) | BD: colorprofile-vl8 (closed) |
| writer_test.go | NOT STARTED | 14 test cases ([#4](https://github.com/dsisnero/colorprofile/issues/4)) + benchmarks ([#6](https://github.com/dsisnero/colorprofile/issues/6)) | BD: colorprofile-13l (tests), colorprofile-kjg (benchmarks) |

### Examples

| Example | Status | Priority |
|---------|--------|----------|
| colors | NOT PORTED | Low ([#7](https://github.com/dsisnero/colorprofile/issues/7)) | BD: colorprofile-dvm |
| profile | NOT PORTED | Low ([#7](https://github.com/dsisnero/colorprofile/issues/7)) | BD: colorprofile-dvm |
| writer | NOT PORTED | Low ([#7](https://github.com/dsisnero/colorprofile/issues/7)) | BD: colorprofile-dvm |

---

## Remaining Work

### High Priority

1. **✅ Port all env_test.go test cases (24 tests)** ([#3](https://github.com/dsisnero/colorprofile/issues/3)) | BD: colorprofile-vl8 (closed)
   - Environment variable combinations
   - Platform-specific behaviors
   - Edge cases

2. **Port all writer_test.go test cases (14+ tests)** ([#4](https://github.com/dsisnero/colorprofile/issues/4)) | BD: colorprofile-13l
   - ANSI sequence handling
   - Color downsampling verification
   - Edge cases with missing params
   - ITU color format support

3. **Complete Windows support** ([#2](https://github.com/dsisnero/colorprofile/issues/2)) | BD: colorprofile-adg
   - Full windowsColorProfile implementation
   - Windows API integration
   - Windows-specific tests

### Medium Priority

4. **Complete profile_test.go** ([#5](https://github.com/dsisnero/colorprofile/issues/5)) | BD: colorprofile-8m2
   - Hex color conversion tests
   - Color caching verification
   - Edge cases with colorful library

5. **Add benchmarks** ([#6](https://github.com/dsisnero/colorprofile/issues/6)) | BD: colorprofile-kjg
   - Writer performance benchmarks
   - Color conversion benchmarks
   - Compare with Go implementation

### Low Priority

6. **Port examples** ([#7](https://github.com/dsisnero/colorprofile/issues/7)) | BD: colorprofile-dvm
   - Colors palette display
   - Profile detection demo
   - Stdin/stdout pipe example

7. **Terminfo database support** ([#1](https://github.com/dsisnero/colorprofile/issues/1)) | BD: colorprofile-d62
   - Full terminfo integration
   - Tc/RGB capability detection

---

## Dependencies

### Go Dependencies (Original)

- `github.com/charmbracelet/x/ansi` - ANSI escape sequences
- `github.com/charmbracelet/x/term` - Terminal detection
- `github.com/lucasb-eyer/go-colorful` - Color manipulation
- `github.com/xo/terminfo` - Terminfo database
- `golang.org/x/sys/windows` - Windows APIs

### Crystal Dependencies (Port)

- `dsisnero/ansi` - ANSI library (already ported)
- `dsisnero/colorful` - Color manipulation (via ansi)

### Test Dependencies

- Crystal Spec framework (built-in)
- Additional test helpers as needed

---

## Notes

1. **Caching Strategy**: The Go implementation uses a two-level cache (Profile -> Color -> Color). The Crystal port maintains this structure using a Hash with tuple keys.

2. **Platform Differences**: Crystal uses compile-time flags (`flag?(:windows)`) instead of Go's build tags.

3. **Error Handling**: Go uses multiple return values (value, error). Crystal uses exceptions or nilable returns.

4. **Type System**: Crystal's type system is more expressive with union types, which simplifies some color type handling.

5. **String vs Bytes**: Go uses `[]byte` for raw data. Crystal uses `Bytes` (alias for `Slice(UInt8)`) or `String` depending on context.

---

## How to Use This Plan

1. Check the box when a function/feature is fully ported and tested
2. Update the Status column as work progresses
3. Add notes for any deviations from the Go implementation
4. Track test coverage alongside implementation
5. Mark Windows-specific items with [WINDOWS] tag

## Last Updated

2026-02-22

## Port Maintainer

Dominic Sisneros <dsisnero@gmail.com>
