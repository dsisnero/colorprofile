require "./profile"
require "ansi"

module Colorprofile
  # Writer represents a color profile writer that writes ANSI sequences to the
  # underlying writer.
  class Writer
    property forward : IO
    property profile : Profile

    def initialize(@forward : IO, @profile : Profile)
    end

    # Write writes the given bytes to the underlying writer.
    def write(bytes : Bytes) : Int64
      case @profile
      when Profile::TrueColor
        @forward.write(bytes)
        bytes.size.to_i64
      when Profile::NoTTY
        # Strip ANSI sequences entirely
        text = String.new(bytes)
        stripped = Ansi.strip(text)
        slice = stripped.to_slice
        @forward.write(slice)
        slice.size.to_i64
      when Profile::ASCII, Profile::ANSI, Profile::ANSI256
        downsample(bytes)
      else
        raise "Invalid profile: #{@profile}"
      end
    end

    # WriteString writes the given text to the underlying writer.
    def write_string(s : String) : Int64
      write(s.to_slice)
    end

    # downsample downgrades the given text to the appropriate color profile.
    private def downsample(bytes : Bytes) : Int64
      buffer = IO::Memory.new
      state = 0_u8

      parser = Ansi::Parser.new

      pos = 0
      while pos < bytes.size
        parser.reset
        seq, _, read, new_state = Ansi.decode_sequence(bytes[pos..-1], state, parser)

        if Ansi.has_csi_prefix?(seq) && parser.command == 'm'.ord
          handle_sgr(parser, buffer)
        else
          # If we're not a style SGR sequence, just write the bytes.
          buffer.write(seq)
        end

        pos += read
        state = new_state
      end

      slice = buffer.to_slice
      @forward.write(slice)
      slice.size.to_i64
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def handle_sgr(parser : Ansi::Parser, buffer : IO::Memory)
      style = Ansi::Style.new([] of String)
      params_len = parser.params_len

      i = 0
      while i < params_len
        p, _more = parser.param(i, 0)

        if p == Ansi::ParserTransition::MissingParam
          # Missing parameter (sentinel value)
          style = Ansi::Style.new(style.attrs + [""])
          i += 1
          next
        end

        case p
        when 0
          # SGR default parameter is 0. Append empty string to produce leading semicolon.
          style = Ansi::Style.new(style.attrs + [""])
        when 30, 31, 32, 33, 34, 35, 36, 37 # 8-bit foreground color
          if @profile >= Profile::ANSI
            color = @profile.convert(Ansi::BasicColor.new((p - 30).to_u8))
            if color
              style = style.foreground_color(color.as(Ansi::AnyColor))
            end
          end
        when 38 # 16 or 24-bit foreground color
          # Parse color to know how many parameters to skip
          slice = parser.params[i, params_len - i]
          params_slice = Ansi.to_params(slice)
          n, color = Ansi.read_style_color(params_slice)
          if n > 0
            i += n - 1
            if @profile >= Profile::ANSI && color
              converted = @profile.convert(color)
              style = style.foreground_color(converted.as(Ansi::AnyColor))
            end
          end
        when 39 # default foreground color
          if @profile >= Profile::ANSI
            style = style.foreground_color(nil)
          end
        when 40, 41, 42, 43, 44, 45, 46, 47 # 8-bit background color
          if @profile >= Profile::ANSI
            color = @profile.convert(Ansi::BasicColor.new((p - 40).to_u8))
            if color
              style = style.background_color(color.as(Ansi::AnyColor))
            end
          end
        when 48 # 16 or 24-bit background color
          # Parse color to know how many parameters to skip
          slice = parser.params[i, params_len - i]
          params_slice = Ansi.to_params(slice)
          n, color = Ansi.read_style_color(params_slice)
          if n > 0
            i += n - 1
            if @profile >= Profile::ANSI && color
              converted = @profile.convert(color)
              style = style.background_color(converted.as(Ansi::AnyColor))
            end
          end
        when 49 # default background color
          if @profile >= Profile::ANSI
            style = style.background_color(nil)
          end
        when 58 # 16 or 24-bit underline color
          # Parse color to know how many parameters to skip
          slice = parser.params[i, params_len - i]
          params_slice = Ansi.to_params(slice)
          n, color = Ansi.read_style_color(params_slice)
          if n > 0
            i += n - 1
            if @profile >= Profile::ANSI && color
              converted = @profile.convert(color)
              style = style.underline_color(converted.as(Ansi::AnyColor))
            end
          end
        when 59 # default underline color
          if @profile >= Profile::ANSI
            style = style.underline_color(nil)
          end
        when 90, 91, 92, 93, 94, 95, 96, 97 # 8-bit bright foreground color
          if @profile >= Profile::ANSI
            color = @profile.convert(Ansi::BasicColor.new((p - 90 + 8).to_u8))
            if color
              style = style.foreground_color(color.as(Ansi::AnyColor))
            end
          end
        when 100, 101, 102, 103, 104, 105, 106, 107 # 8-bit bright background color
          if @profile >= Profile::ANSI
            color = @profile.convert(Ansi::BasicColor.new((p - 100 + 8).to_u8))
            if color
              style = style.background_color(color.as(Ansi::AnyColor))
            end
          end
        else
          # If this is not a color attribute, just append it to the style.
          raw = parser.params[i]
          if (raw & Int32::MAX) == Int32::MAX
            style = Ansi::Style.new(style.attrs + [""])
          else
            style = Ansi::Style.new(style.attrs + [p.to_s])
          end
        end

        i += 1
      end

      buffer << style.to_s
    end
  end

  # NewWriter creates a new color profile writer that downgrades color sequences
  # based on the detected color profile.
  #
  # If environ is nil, it will use environment variables from ENV.
  #
  # It queries the given writer to determine if it supports ANSI escape codes.
  # If it does, along with the given environment variables, it will determine
  # the appropriate color profile to use for color formatting.
  #
  # This respects the NO_COLOR, CLICOLOR, and CLICOLOR_FORCE environment variables.
  def self.new_writer(io : IO, environ : Array(String)) : Writer
    Writer.new(io, detect(io, environ))
  end
end
