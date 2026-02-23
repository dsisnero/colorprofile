# ColorProfile Port Audit

This document compares the Go source code (in `vendor/`) with the Crystal
implementation (in `src/`). For each Go source file, we list structs, methods,
constants, and note whether they have been ported correctly.

## Summary

- **profile.go**: Mostly ported with differences in cache implementation and
  missing alias constant.
- **env.go**: Ported with some logic differences and missing platform-specific
  functions.
- **env_other.go / env_windows.go**: Partially ported via conditional
  compilation.
- **writer.go**: Ported with significant logic differences and missing
  `NewWriter` signature.
- **Test files**: Need to port `profile_test.go`, `env_test.go`,
  `writer_test.go`.

## profile.go

### Go Structs and Methods

| Type | Name | Description |
|------|------|-------------|
| `type Profile byte` | Profile | Color profile enumeration |
| `const` | Unknown, NoTTY, ASCII, ANSI, ANSI256, TrueColor | Enum constants |
| `const` | Ascii = ASCII | Alias for ASCII (backwards compatibility) |
| `func (p Profile) String() string` | String | Returns string representation |
| `var` | cache map[Profile]map[color.Color]color.Color | Cache for converted colors |
| `var` | mu sync.RWMutex | Mutex for cache |
| `func (p Profile) Convert(c color.Color) color.Color` | Convert | Converts color to profile-supported color |

### Crystal Implementation (`src/colorprofile/profile.cr`)

| Go Feature | Crystal Equivalent | Status | Notes |
|------------|-------------------|--------|-------|
| `type Profile byte` | `enum Profile : UInt8` | ✅ | Exact mapping |
| Constants | `Unknown`, `NoTTY`, `ASCII`, `ANSI`, `ANSI256`, `TrueColor` | ✅ | Same order |
| `Ascii = ASCII` | `def self.ascii` (class method) | ⚠️ | Not a constant alias; could be `Ascii = ASCII` |
| `String()` | `def to_s : String` | ✅ | Logic matches |
| `cache` | `@@cache = Hash(Tuple(Profile, Ansi::PaletteColor), Ansi::PaletteColor).new` | ⚠️ | Different structure; Go cache only for ANSI256/ANSI profiles |
| `mu` | `@@mutex = Mutex.new` | ✅ | Mutex present |
| `Convert` | `def convert(c : Ansi::PaletteColor) : Ansi::PaletteColor?` | ⚠️ | Return type optional; Go returns nil for ASCII/NoTTY; logic differs in caching |
| - | `private def convert_color` | ✅ | Extracted logic |
| - | `def self.cache` and `set_cache` | ❌ | Extra methods not in Go; maybe internal helpers |

### Issues

1. **Cache structure**: Go uses nested map
   `map[Profile]map[color.Color]color.Color` and initializes only for ANSI256
   and ANSI profiles (lines 50-53). Crystal uses a single hash with tuple key,
   not limited to those profiles.
2. **Ascii alias**: Go defines `const Ascii = ASCII`. Crystal defines class
   method `self.ascii`. Should be constant.
3. **Convert signature**: Go returns `color.Color` (interface) which can be
   `nil`. Crystal returns optional `Ansi::PaletteColor?`. That's fine.
4. **Convert logic**: The caching logic differs: Go checks
   `c != nil && cache[p] != nil`. Crystal uses `@@cache[cache_key]?`. Need to
   ensure cache only used for ANSI256/ANSI.
5. **Missing profile values**: Go's `Unknown` is 0, others increment. Crystal
   enum same.

## env.go

### Go Structs and Methods

| Type | Name | Description |
|------|------|-------------|
| `const dumbTerm = "dumb"` | Constant |  |
| `func Detect(output io.Writer, env []string) Profile` | Detect color profile based on terminal output and env |  |
| `func Env(env []string) Profile` | Get profile from environment only |  |
| `func colorProfile(isatty bool, env environ) Profile` | internal |  |
| `func envNoColor(env environ) bool` | internal |  |
| `func cliColor(env environ) bool` | internal |  |
| `func cliColorForced(env environ) bool` | internal |  |
| `func isTTYForced(env environ) bool` | internal |  |
| `func colorTerm(env environ) bool` | internal |  |
| `func envColorProfile(env environ) Profile` | internal |  |
| `func Terminfo(term string) Profile` | public, returns profile based on terminfo |  |
| `func Tmux(env []string) Profile` | public, returns profile based on tmux info |  |
| `func tmux(env environ) Profile` | internal |  |
| `type environ map[string]string` | internal type |  |
| `func newEnviron([]string) environ` | internal |  |
| `func (e environ) lookup(key string) (string, bool)` | method |  |
| `func (e environ) get(key string) string` | method |  |

### Crystal Implementation (`src/colorprofile/env.cr`)

| Go Feature | Crystal Equivalent | Status | Notes |
|------------|-------------------|--------|-------|
| `dumbTerm` | `DUMB_TERM = "dumb"` | ✅ |  |
| `Detect` | `def self.detect(output : IO, env : Array(String)) : Profile` | ✅ | Logic similar |
| `Env` | `def self.env(env : Array(String)) : Profile` | ✅ |  |
| `colorProfile` | `private def self.color_profile` | ✅ | Logic matches |
| `envNoColor` | `private def self.no_color?` | ✅ |  |
| `cliColor` | `private def self.cli_color?` | ✅ |  |
| `cliColorForced` | `private def self.cli_color_forced?` | ✅ |  |
| `isTTYForced` | `private def self.tty_forced?` | ✅ |  |
| `colorTerm` | `private def self.color_term?` | ✅ |  |
| `envColorProfile` | `private def self.env_color_profile` | ✅ | Logic similar; Windows detection via conditional compilation |
| `Terminfo` | `def self.terminfo_profile(term : String) : Profile` | ⚠️ | Implementation differs: Go uses terminfo library, Crystal uses `infocmp` command |
| `Tmux` | `def self.tmux(env : Array(String)) : Profile` | ✅ | Wrapper |
| `tmux` | `private def self.tmux_profile` | ✅ | Logic similar but uses `tmux info` command |
| `type environ` | `alias Environ = Hash(String, String)` | ✅ | Not a distinct type but alias |
| `newEnviron` | `def self.new_environ(environ : Array(String)) : Environ` | ✅ |  |
| `lookup` | Not directly; use `env["TERM"]?` | ⚠️ | No explicit method; but hash provides `[]?` |
| `get` | Not directly; use `env["TERM"]? \|\| ""` | ⚠️ | No explicit method |

### Issues

1. **Terminfo implementation**: Go uses `github.com/xo/terminfo` library to
   query terminfo database. Crystal uses `infocmp -L` command execution. Might
   have different behavior. **Note**: The `shard.yml` already includes
   `terminfo` shard (github: docelic/terminfo) but it's not used. Should replace
   custom infocmp parsing with terminfo shard.
2. **environ methods**: Go defines `lookup` and `get` methods; Crystal uses Hash
   directly. That's fine.
3. **Windows detection**: Go has `windowsColorProfile` in platform-specific
   files. Crystal uses conditional compilation `{% if flag?(:windows) %}` and
   implements similar logic. Need to verify equivalence (see platform-specific
   section).
4. **envColorProfile logic**: Differences in handling Windows and term
   detection. Need to verify edge cases.
5. **Missing terminfo caching**: Go's `Terminfo` function loads terminfo each
   call; Crystal's `terminfo_profile` calls `infocmp` each time. Could add
   caching.
6. **Tmux detection**: Go uses `exec.CommandContext` with `tmux info`. Crystal
   uses backticks. Similar but error handling differs.

## env_other.go and env_windows.go

### Go Platform-Specific

| File | Function | Description |
|------|----------|-------------|
| `env_other.go` | `windowsColorProfile(env map[string]string) (Profile, bool)` | Returns `0, false` (no-op) for non-Windows |
| `env_windows.go` | `windowsColorProfile(env map[string]string) (Profile, bool)` | Windows detection using `windows.RtlGetNtVersionNumbers` and environment variables |

**Go Windows Logic**:

1. If `env["ConEmuANSI"] == "ON"` → `TrueColor, true`
2. Get major and build version via `windows.RtlGetNtVersionNumbers`
3. If `build < 10586 || major < 10`:
   - If `env["ANSICON"]` set:
     - Parse `env["ANSICON_VER"]` as int; if `< 181` → `ANSI, true` else
       `ANSI256, true`
   - Else → `NoTTY, true`
4. If `build < 14931` → `ANSI256, true`
5. Else → `TrueColor, true`

### Crystal Implementation

Crystal uses conditional compilation `{% if flag?(:windows) %}` to include
`windows_color_profile` method. The logic is similar but has differences:

**Crystal Windows Logic** (lines 286-333):

1. If `environ["ConEmuANSI"]? == "ON"` → `Profile::TrueColor`
2. Get major, minor, build via `Ntdll.RtlGetNtVersionNumbers` (mask build high
   bit)
3. If `build < 10586 || major < 10`:
   - If `environ["ANSICON"]?` not nil and not empty:
     - Parse `environ["ANSICON_VER"]?` as int; if `< 181` → `Profile::ANSI` else
       `Profile::ANSI256`
   - Else → `Profile::NoTTY`
4. If `build < 14931` → `Profile::ANSI256`
5. Else → `Profile::TrueColor`

**Differences**:

- Go returns a boolean second parameter indicating success; Crystal returns
  `Profile?` (nil if detection fails). Crystal's method returns `nil` on
  failure, but Go returns `0, false`. Need to ensure caller handles nil.
- Go's `windowsColorProfile` is called only when `term` is empty/dumb or on
  Windows. Crystal's `windows_color_profile` is called in same condition.
- Crystal masks build number with `0x7FFF_FFFF` (removes high bit). Go's
  `windows.RtlGetNtVersionNumbers` returns build with high bit set for release
  builds; does Go mask? Need to check Go's `windows` package implementation.

**Issues**:

1. Verify that Go's `windows.RtlGetNtVersionNumbers` returns build with high bit
   set; if yes, Go may not mask it. The condition `build < 10586` may need
   masking.
2. Ensure ConEmuANSI, ANSICON, ANSICON_VER handling matches exactly
   (case-sensitive?).
3. Crystal returns `nil` if Windows API call fails; Go returns `0, false`.
   Should match.

**Recommendation**:

- Check Go's `windows` package source to see if they mask build number.
- Align return signature: maybe return `Profile?` and treat `nil` as "no
  detection".

## writer.go

### Go Structs and Methods

| Type | Name | Description |
|------|------|-------------|
| `func NewWriter(w io.Writer, environ []string) *Writer` | Constructor |  |
| `type Writer struct` | Contains `Forward io.Writer` and `Profile Profile` |  |
| `func (w *Writer) Write(p []byte) (int, error)` | Write bytes |  |
| `func (w *Writer) WriteString(s string) (int, error)` | Write string |  |
| `func (w *Writer) downsample(p []byte) (int, error)` | internal |  |
| `func handleSgr(w *Writer, p *ansi.Parser, buf *bytes.Buffer)` | internal |  |

### Crystal Implementation (`src/colorprofile/writer.cr`)

| Go Feature | Crystal Equivalent | Status | Notes |
|------------|-------------------|--------|-------|
| `NewWriter` | `def self.new_writer(io : IO, environ : Array(String)? = nil) : Writer` | ⚠️ | Signature differs: optional environ, uses `ENV` if nil |
| `Writer struct` | `class Writer` with properties `forward : IO` and `profile : Profile` | ✅ |  |
| `Write` | `def write(bytes : Bytes) : Int64` | ⚠️ | Return type `Int64` vs `(int, error)`; error handling via exceptions |
| `WriteString` | `def write_string(s : String) : Int64` | ✅ |  |
| `downsample` | `private def downsample(bytes : Bytes) : Int64` | ⚠️ | Logic similar but uses Crystal ANSI parser API differences |
| `handleSgr` | `private def handle_sgr(parser : Ansi::Parser, buffer : IO::Memory)` | ⚠️ | Significant differences in parameter parsing and color conversion |

### Detailed Comparison

#### NewWriter Constructor

| Aspect | Go | Crystal |
|--------|----|---------|
| Signature | `NewWriter(w io.Writer, environ []string) *Writer` | `new_writer(io : IO, environ : Array(String)? = nil) : Writer` |
| Environ default | No default (required) | Optional; if `nil`, uses `ENV` mapping |
| Detection | Calls `Detect(w, environ)` | Calls `detect(io, env)` (same) |
| Return type | `*Writer` (pointer) | `Writer` instance |

**Issue**: Crystal's optional environ changes behavior when `nil`. Should match
Go's explicit requirement. However, Go's `Detect` expects `environ` slice; if
nil, Crystal uses `ENV`. Might be okay but diverges.

#### Write Method

| Aspect | Go | Crystal |
|--------|----|---------|
| Signature | `Write(p []byte) (int, error)` | `write(bytes : Bytes) : Int64` |
| Error handling | Returns error (e.g., from `Forward.Write`) | Raises exception (IO::Error) |
| Return value | Number of bytes written (int) | Number of bytes written as Int64 |
| TrueColor case | Forwards `p` directly | Forwards `bytes` directly |
| NoTTY case | Calls `ansi.Strip(string(p))` | Converts bytes to String, strips, writes slice |
| ASCII/ANSI/ANSI256 | Calls `downsample(p)` | Calls `downsample(bytes)` |
| Invalid profile | Returns error `fmt.Errorf("invalid profile: %v", w.Profile)` | Raises exception `raise "Invalid profile: #{@profile}"` |

**Issues**:

1. Error handling difference: Go returns error, Crystal raises. This changes API
   semantics; callers must rescue instead of checking error.
2. NoTTY case: Go uses `ansi.Strip` on string conversion; Crystal does
   `String.new(bytes)` then `Ansi.strip`. Should be equivalent.
3. Return type: Go returns `int`, Crystal returns `Int64`. Crystal's `IO#write`
   returns `Int64`. Might be okay.

#### downsample Method

| Aspect | Go | Crystal |
|--------|----|---------|
| Signature | `downsample(p []byte) (int, error)` | `downsample(bytes : Bytes) : Int64` |
| Buffer | `bytes.Buffer` | `IO::Memory` |
| State | `var state byte` | `state = 0_u8` |
| Parser | `ansi.GetParser()` (pooled) | `Ansi::Parser.new` (new each time) |
| Loop | `for len(p) > 0` | `while pos < bytes.size` |
| Decoding | `seq, _, read, newState := ansi.DecodeSequence(p, state, parser)` | `seq, _, read, new_state = Ansi.decode_sequence(bytes[pos..-1], state, parser)` |
| CSI+SGR detection | `ansi.HasCsiPrefix(seq) && parser.Command() == 'm'` | `Ansi.has_csi_prefix?(seq) && parser.command == 'm'.ord` |
| Non-SGR bytes | `buf.Write(seq)` | `buffer.write(seq)` |
| Final write | `w.Forward.Write(buf.Bytes())` | `@forward.write(slice)` |

**Issues**:

1. Parser pooling: Go uses `ansi.GetParser()` and
   `defer ansi.PutParser(parser)`. Crystal creates new parser each call. Could
   affect performance but not behavior.
2. Error handling: Go's `buf.Write` returns error; Crystal's `buffer.write`
   raises. Might be fine.
3. Slice handling: Go updates `p = p[read:]`; Crystal increments `pos`.
   Equivalent.

#### handleSgr / handle_sgr

This is the most complex part. Go's `handleSgr` uses `ansi.Style` building
methods (`ForegroundColor`, `BackgroundColor`, `UnderlineColor`). Crystal's
`handle_sgr` builds an array of SGR strings and creates `Ansi::Style` from them.

**Parameter Parsing**:

- Go iterates over `params` slice of `ansi.Param`. Uses `param.Param(0)` to get
  integer.
- Crystal uses `parser.param(i, 0)` returning tuple `(p, more)` and handles
  `MissingParam` sentinel.

**Color Conversion**:

- Go calls `w.Profile.Convert(color)` and passes to style methods.
- Crystal calls `@profile.convert(color)` and uses `color_to_sgr` helper to
  generate SGR string.

**Color Parsing for 38/48/58**:

- Go uses `ansi.ReadStyleColor(params[i:], &c)` which returns number of
  parameters consumed.
- Crystal attempts to use `Ansi.read_style_color` with slice of params; if that
  fails, falls back to old skip logic.

**SGR Generation**:

- Go's `style.String()` produces final SGR sequence.
- Crystal's `Ansi::Style.new(style_attrs).to_s` does similar.

**Differences**:

1. **Fallback skip logic**: Crystal has extra logic to skip parameters when
   `@profile < ANSI`. This may cause mismatched behavior.
2. **MissingParam handling**: Crystal treats `MissingParam` as empty string;
   Go's `param.Param(0)` returns 0? Need to check.
3. **Color mapping**: Crystal's `color_to_sgr` maps `BasicColor` to SGR numbers;
   Go uses `style.ForegroundColor` which does mapping internally.
4. **Default colors**: Go's `style.ForegroundColor(nil)` produces `"39"`.
   Crystal explicitly adds `"39"` or `"49"`.
5. **Bright colors**: Go maps bright foreground colors (90-97) to
   `BasicColor(param - 90 + 8)`. Crystal does `(p - 90 + 8).to_u8`. Same.

**Potential Issues**:

- The fallback skip logic may cause incorrect parameter skipping leading to
  malformed SGR sequences.
- `MissingParam` handling may differ.
- `color_to_sgr` may produce different SGR strings than Go's style methods.

#### Recommendations

1. **Error handling**: Consider changing Crystal's `write` to return
   `Int64 | Exception`? Might break existing code. Better to keep raising
   exceptions but document.
2. **NewWriter signature**: Make environ required; if caller wants ENV, pass
   `ENV.map { |k, v| "#{k}=#{v}" }`.
3. **Parser pooling**: Implement parser pool similar to Go using `class_getter`
   maybe.
4. **handle_sgr refactor**: Use `Ansi::Style` builder methods if available in
   Crystal ANSI shard. Otherwise verify that `color_to_sgr` matches Go's mapping
   exactly.
5. **Test thoroughly**: Ensure all writer test cases pass with exact output.

## Test Files

### Go Test Files

- `profile_test.go` - Tests for Profile conversion and caching.
- `env_test.go` - Tests for environment detection (many cases).
- `writer_test.go` - Tests for Writer downsample behavior.

### Crystal Specs

Crystal spec file `spec/colorprofile_spec.cr` already contains ported tests from
Go test files:

1. **Profile tests**: Basic enum values, to_s, ascii alias, color conversion
   (partial).
2. **Environment detection tests**: Many test cases ported from `env_test.go`
   (see `cases` array). However, some cases are commented with TODO for Windows
   detection.
3. **Writer tests**: Numerous test cases ported from `writer_test.go` (see
   `writer_cases` array). Covers TrueColor, ANSI256, ANSI, ASCII, NoTTY
   profiles.

**Missing Tests**:

| Go Test Function | Status | Notes |
|------------------|--------|-------|
| `TestHexTo256` | ❌ Not ported | Tests color conversion from TrueColor to 256-color palette. Important for accuracy. |
| `TestCache` | ❌ Not ported | Tests caching behavior of profile conversion. |
| `TestDetectionByEnvironment` | ⚠️ Partially ported | Some test cases present in Crystal spec but maybe not all. |
| `TestEnvColorProfile` | ✅ Ported | Covered by environment detection test cases. |
| `TestWriter` | ✅ Ported | Covered by writer test cases. |
| `TestNewWriterPanic` | ❌ Not ported | Tests panic when writer is nil. |
| `TestNewWriterOsEnviron` | ❌ Not ported | Tests behavior when environ is nil (uses os.Environ). |
| Terminfo tests | ❌ Not ported | No explicit test in Go? Should test `Terminfo` function. |
| Tmux tests | ❌ Not ported | No explicit test in Go? Should test `Tmux` function. |
| Windows detection edge cases | ❌ Missing | Need to test Windows-specific logic. |

**Note**: The Crystal spec includes many test cases but may not cover all edge cases from Go tests. Need to compare each test file line by line.

**Issues**:

- Windows detection tests are conditional (`{% if flag?(:windows) %}`) and have
  placeholder values (TrueColor). Need to implement proper Windows detection and
  adjust expected values.
- Some test cases may have been omitted; need to compare line by line with Go
  test files.

**Action**:

1. Compare each Go test file with Crystal spec to ensure all test cases are
   ported.
2. Fix Windows detection and update expected values.
3. Add missing test categories (cache, terminfo, tmux).
4. Ensure test logic matches exactly (same assertions).

## Recommendations

1. **Profile**:
   - Change `Ascii` alias to constant `Ascii = ASCII`.
   - Adjust cache to only store for ANSI256 and ANSI profiles (maybe initialize
     hash per profile).
   - Ensure `convert` caching logic matches Go (check nil, check cache[p]
     existence).
2. **Env**:
   - Consider using a Crystal terminfo shard instead of `infocmp` command for
     better portability.
   - Verify Windows detection logic matches exactly.
3. **Writer**:
   - Align `new_writer` signature to require environ parameter (maybe default to
     `ENV` but explicit).
   - Consider error handling: return `Int64 | Exception`? Might need to match
     Go's error returns.
   - Refactor `handle_sgr` to match Go's logic more closely; leverage Crystal
     ANSI library's `Style` building.
4. **Tests**:
   - Port all Go tests to Crystal specs.
   - Ensure edge cases covered.

## Next Steps

1. Create issues for each discrepancy.
2. Prioritize fixing core logic (profile cache, terminfo, writer error
   handling).
3. Port test files to validate behavior.

## Conclusion

The Crystal port is largely complete with all major functionality implemented. However, there are several discrepancies that need to be addressed to ensure exact behavioral equivalence with the Go source:

1. **Profile**: Cache structure and Ascii alias.
2. **Env**: Terminfo implementation uses `infocmp` instead of terminfo shard; Windows detection needs verification.
3. **Writer**: Error handling semantics differ; `handle_sgr` logic is complex and may not match Go exactly.
4. **Tests**: Several test functions missing, especially for color conversion, caching, and edge cases.

**Recommendation**: Address the high-priority issues (profile cache, terminfo) before releasing. Run the existing Crystal spec suite to ensure no regressions, then add missing tests.

**Quality Gates**: Before finalizing, run `crystal tool format --check`, `ameba --fix`, `ameba`, and `crystal spec` to ensure code quality and test coverage.
