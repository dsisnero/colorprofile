# colorprofile

[![Crystal CI](https://github.com/dsisnero/colorprofile/workflows/Crystal%20CI/badge.svg)](https://github.com/dsisnero/colorprofile/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A simple, powerful—and at times magical—library for detecting terminal color
profiles and performing color (and CSI) degradation.

This is a Crystal port of [github.com/charmbracelet/colorprofile](https://github.com/charmbracelet/colorprofile).
The original Go source code is available in the `vendor/` directory as a git
submodule.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     colorprofile:
       github: dsisnero/colorprofile
   ```

2. Run `shards install`

## Usage

### Detecting the terminal's color profile

Detecting the terminal's color profile is easy.

```crystal
require "colorprofile"

# Detect the color profile.
profile = Colorprofile.detect(STDOUT, ENV.to_h)

# Comment on the profile.
case profile
when Colorprofile::Profile::TrueColor
  puts "You know, your colors are quite fancy."
when Colorprofile::Profile::ANSI256
  puts "You know, your colors are quite 1990s fancy."
when Colorprofile::Profile::ANSI
  puts "You know, your colors are quite normcore."
when Colorprofile::Profile::ASCII
  puts "You know, your colors are quite ancient."
when Colorprofile::Profile::NoTTY
  puts "You know, your colors are quite naughty!"
end
```

### Downsampling colors

When necessary, colors can be downsampled to a given profile.

```crystal
profile = Colorprofile.detect(STDOUT, ENV.to_h)
color = Color::RGBA.new(0x6b, 0x50, 0xff, 0xff) # #6b50ff

# Downsample to the detected profile, when necessary.
converted_color = profile.convert(color)

# Or manually convert to a given profile.
ansi256_color = Colorprofile::Profile::ANSI256.convert(color)
ansi_color = Colorprofile::Profile::ANSI.convert(color)
no_color = Colorprofile::Profile::ASCII.convert(color)
no_ansi = Colorprofile::Profile::NoTTY.convert(color)
```

### Automatic downsampling with a Writer

You can also magically downsample colors in ANSI output, when necessary. If
output is not a TTY, ANSI will be dropped entirely.

```crystal
my_fancy_ansi = "\e[38;2;107;80;255mCute \e[1;3mpuppy!!\e[m"

# Automatically downsample for the terminal at stdout.
writer = Colorprofile::Writer.new(STDOUT, ENV.to_h)
writer.write(my_fancy_ansi.to_slice)

# Downsample to 4-bit ANSI.
writer.profile = Colorprofile::Profile::ANSI
writer.write(my_fancy_ansi.to_slice)

# Ascii-fy, no colors.
writer.profile = Colorprofile::Profile::ASCII
writer.write(my_fancy_ansi.to_slice)

# Strip ANSI altogether.
writer.profile = Colorprofile::Profile::NoTTY
writer.write(my_fancy_ansi.to_slice) # not as fancy
```

## Development

Run `make help` to see available targets:

- `make install` - Install dependencies
- `make test` - Run tests
- `make format` - Format code
- `make lint` - Run linter (ameba)

## Contributing

1. Fork it (<https://github.com/dsisnero/colorprofile/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Attribution

This project is a Crystal port of the Go library
[charmbracelet/colorprofile](https://github.com/charmbracelet/colorprofile).
All credit for the original design and implementation goes to the Charmbracelet
team.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Contributors

- [Dominic Sisneros](https://github.com/dsisnero) - creator and maintainer of
the Crystal port
