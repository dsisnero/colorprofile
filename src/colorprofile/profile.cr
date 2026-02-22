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

    # Ascii is an alias for the ASCII profile for backwards compatibility.
    def self.ascii
      ASCII
    end

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

      # Do we have a cached color for this profile and color?
      cache_key = {self, c}
      if cached = @@cache[cache_key]?
        return cached
      end

      # If we don't have a cached color, we need to convert it and cache it.
      converted = convert_color(c)
      @@cache[cache_key] = converted if converted
      converted
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

    @@cache = Hash(Tuple(Profile, Ansi::PaletteColor), Ansi::PaletteColor).new
    @@mutex = Mutex.new

    # Cache for color conversions
    def self.cache(profile : Profile, color : Ansi::PaletteColor) : Ansi::PaletteColor?
      @@mutex.synchronize do
        @@cache[{profile, color}]?
      end
    end

    def self.set_cache(profile : Profile, original : Ansi::PaletteColor, converted : Ansi::PaletteColor)
      @@mutex.synchronize do
        @@cache[{profile, original}] = converted
      end
    end
  end
end
