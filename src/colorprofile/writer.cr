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
      style_attrs = [] of String
      params_len = parser.params_len

      i = 0
      while i < params_len
        p, _more = parser.param(i, 0)

        if p == Ansi::ParserTransition::MissingParam
          # Missing parameter (sentinel value)
          style_attrs << ""
          i += 1
          next
        end

        case p
        when 0
          # SGR default parameter is 0. Append empty string to produce leading semicolon.
          style_attrs << ""
          i += 1
          next
        when 30, 31, 32, 33, 34, 35, 36, 37 # 8-bit foreground color
          if @profile < Profile::ANSI
            i += 1
            next
          end
          color = @profile.convert(Ansi::BasicColor.new((p - 30).to_u8))
          if color
            style_attrs << color_to_sgr(color, :foreground)
          end
        when 38 # 16 or 24-bit foreground color
          if @profile < Profile::ANSI
            # Parse color to know how many parameters to skip
            slice = parser.params[i, params_len - i]
            params_slice = Ansi.to_params(slice)
            n, _ = Ansi.read_style_color(params_slice)
            if n > 0
              i += n
              next
            else
              # Fallback to old skip logic
              if i + 1 < params_len
                color_type = parser.param(i + 1, 0)[0]
                case color_type
                when 5 # 256 color
                  i += 3 if i + 2 < params_len
                when 2 # True color (RGB)
                  i += 5 if i + 4 < params_len
                else
                  i += 1
                end
              end
              next
            end
          end
          # Parse color using ANSI library (supports ITU format)
          slice = parser.params[i, params_len - i]
          params_slice = Ansi.to_params(slice)
          n, color = Ansi.read_style_color(params_slice)
          if n > 0 && color
            converted = @profile.convert(color)
            if converted
              style_attrs << color_to_sgr(converted, :foreground)
            end
            i += n
            next
          end
        when 39 # default foreground color
          if @profile < Profile::ANSI
            i += 1
            next
          end
          style_attrs << "39"
        when 40, 41, 42, 43, 44, 45, 46, 47 # 8-bit background color
          if @profile < Profile::ANSI
            i += 1
            next
          end
          color = @profile.convert(Ansi::BasicColor.new((p - 40).to_u8))
          if color
            style_attrs << color_to_sgr(color, :background)
          end
        when 48 # 16 or 24-bit background color
          if @profile < Profile::ANSI
            # Parse color to know how many parameters to skip
            slice = parser.params[i, params_len - i]
            params_slice = Ansi.to_params(slice)
            n, _ = Ansi.read_style_color(params_slice)
            if n > 0
              i += n
              next
            else
              # Fallback to old skip logic
              if i + 1 < params_len
                color_type = parser.param(i + 1, 0)[0]
                case color_type
                when 5 # 256 color
                  i += 3 if i + 2 < params_len
                when 2 # True color (RGB)
                  i += 5 if i + 4 < params_len
                else
                  i += 1
                end
              end
              next
            end
          end
          # Parse color using ANSI library (supports ITU format)
          slice = parser.params[i, params_len - i]
          params_slice = Ansi.to_params(slice)
          n, color = Ansi.read_style_color(params_slice)
          if n > 0 && color
            converted = @profile.convert(color)
            if converted
              style_attrs << color_to_sgr(converted, :background)
            end
            i += n
            next
          end
        when 49 # default background color
          if @profile < Profile::ANSI
            i += 1
            next
          end
          style_attrs << "49"
        when 58 # 16 or 24-bit underline color
          if @profile < Profile::ANSI
            # Parse color to know how many parameters to skip
            slice = parser.params[i, params_len - i]
            params_slice = Ansi.to_params(slice)
            n, _ = Ansi.read_style_color(params_slice)
            if n > 0
              i += n
              next
            else
              # Fallback to old skip logic
              if i + 1 < params_len
                color_type = parser.param(i + 1, 0)[0]
                case color_type
                when 5 # 256 color
                  i += 3 if i + 2 < params_len
                when 2 # True color (RGB)
                  i += 5 if i + 4 < params_len
                else
                  i += 1
                end
              end
              next
            end
          end
          # Parse color using ANSI library (supports ITU format)
          slice = parser.params[i, params_len - i]
          params_slice = Ansi.to_params(slice)
          n, color = Ansi.read_style_color(params_slice)
          if n > 0 && color
            converted = @profile.convert(color)
            if converted
              style_attrs << color_to_sgr(converted, :underline)
            end
            i += n
            next
          end
        when 59 # default underline color
          if @profile < Profile::ANSI
            i += 1
            next
          end
          style_attrs << "59"
        when 90, 91, 92, 93, 94, 95, 96, 97 # 8-bit bright foreground color
          if @profile < Profile::ANSI
            i += 1
            next
          end
          color = @profile.convert(Ansi::BasicColor.new((p - 90 + 8).to_u8))
          if color
            style_attrs << color_to_sgr(color, :foreground)
          end
        when 100, 101, 102, 103, 104, 105, 106, 107 # 8-bit bright background color
          if @profile < Profile::ANSI
            i += 1
            next
          end
          color = @profile.convert(Ansi::BasicColor.new((p - 100 + 8).to_u8))
          if color
            style_attrs << color_to_sgr(color, :background)
          end
        else
          # If this is not a color attribute, just append it as a string.
          raw = parser.params[i]
          if (raw & Int32::MAX) == Int32::MAX
            style_attrs << ""
          else
            style_attrs << p.to_s
          end
        end

        i += 1
      end

      style = Ansi::Style.new(style_attrs)
      buffer << style.to_s
    end

    # ameba:disable Metrics/CyclomaticComplexity
    private def color_to_sgr(color : Ansi::PaletteColor, type : Symbol) : String
      case type
      when :foreground
        case color
        when Ansi::BasicColor
          if color.value < 8
            (30 + color.value).to_s
          else
            (90 + (color.value - 8)).to_s
          end
        when Ansi::IndexedColor
          "38;5;#{color.value}"
        when Ansi::Color
          "38;2;#{color.r};#{color.g};#{color.b}"
        else
          ""
        end
      when :background
        case color
        when Ansi::BasicColor
          if color.value < 8
            (40 + color.value).to_s
          else
            (100 + (color.value - 8)).to_s
          end
        when Ansi::IndexedColor
          "48;5;#{color.value}"
        when Ansi::Color
          "48;2;#{color.r};#{color.g};#{color.b}"
        else
          ""
        end
      when :underline
        case color
        when Ansi::BasicColor
          "58;5;#{color.value}"
        when Ansi::IndexedColor
          "58;5;#{color.value}"
        when Ansi::Color
          "58;2;#{color.r};#{color.g};#{color.b}"
        else
          ""
        end
      else
        ""
      end
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
  def self.new_writer(io : IO, environ : Array(String)? = nil) : Writer
    env = environ || ENV.map { |k, v| "#{k}=#{v}" }
    Writer.new(io, detect(io, env))
  end
end
