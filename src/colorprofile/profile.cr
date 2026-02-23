require "ansi"

# Profile is a color profile: NoTTY, Ascii, ANSI, ANSI256, or TrueColor.
module Colorprofile
  enum Profile : UInt8
    # Unknown is a profile that represents the absence of a profile.
    Unknown
    # NoTTY is a profile with no terminal support.
    NoTTY
    # ASCII is a profile with no color support.
    ASCII
    # ANSI is a profile with 16 colors (4-bit).
    ANSI
    # ANSI256 is a profile with 256 colors (8-bit).
    ANSI256
    # TrueColor is a profile with 16 million colors (24-bit).
    TrueColor

    # String returns the string representation of a Profile.
    def to_s : String
      case self
      when TrueColor
        "TrueColor"
      when ANSI256
        "ANSI256"
      when ANSI
        "ANSI"
      when ASCII
        "Ascii"
      when NoTTY
        "NoTTY"
      else
        "Unknown"
      end
    end

    # Convert transforms a given Color to a Color supported within the Profile.
    def convert(c : Ansi::PaletteColor) : Ansi::PaletteColor?
      if self <= ASCII
        return
      end
      if self == TrueColor
        # TrueColor is a passthrough.
        return c
      end

      CACHE_LOCK.synchronize do
        if profile_cache = CACHE[self]?
          if cached = profile_cache[c]?
            return cached
          end
        end

        converted = convert_color(c)

        if profile_cache = CACHE[self]?
          profile_cache[c] = converted unless profile_cache.has_key?(c)
        end

        converted
      end
    end

    private def convert_color(c : Ansi::PaletteColor) : Ansi::PaletteColor
      case c
      when Ansi::BasicColor
        c
      when Ansi::IndexedColor
        if self == ANSI
          Ansi.convert_16(c)
        else
          c
        end
      else
        case self
        when ANSI256
          Ansi.convert_256(c)
        when ANSI
          Ansi.convert_16(c)
        else
          c
        end
      end
    end
  end

  # Ascii is an alias for the ASCII profile for backwards compatibility.
  Ascii = Profile::ASCII

  # Cache for color conversions, matches Go structure: map[Profile]map[color.Color]color.Color
  # Initialized only for ANSI256 and ANSI profiles (TrueColor doesn't cache, ASCII/NoTTY don't convert)
  private CACHE = begin
    hash = Hash(Profile, Hash(Ansi::PaletteColor, Ansi::PaletteColor)).new
    hash[Profile::ANSI256] = Hash(Ansi::PaletteColor, Ansi::PaletteColor).new
    hash[Profile::ANSI] = Hash(Ansi::PaletteColor, Ansi::PaletteColor).new
    hash
  end

  # Mutex for cache access (simpler than Go's sync.RWMutex but functionally correct)
  private CACHE_LOCK = Mutex.new
end
