require "./profile"
require "ansi"
require "terminfo"

module Colorprofile
  DUMB_TERM = "dumb"

  # environ is a map of environment variables.
  alias Environ = Hash(String, String)

  # new_environ returns a new environment map from a slice of environment
  # variables.
  def self.new_environ(environ : Array(String)) : Environ
    env = Environ.new
    environ.each do |e|
      parts = e.split("=", 2)
      value = parts.size == 2 ? parts[1] : ""
      env[parts[0]] = value
    end
    env
  end

  # Detect returns the color profile based on the terminal output, and
  # environment variables. This respects NO_COLOR, CLICOLOR, and CLICOLOR_FORCE
  # environment variables.
  #
  # The rules as follows:
  #   - TERM=dumb is always treated as NoTTY unless CLICOLOR_FORCE=1 is set.
  #   - If COLORTERM=truecolor, and the profile is not NoTTY, it gets upgraded to TrueColor.
  #   - Using any 256 color terminal (e.g. TERM=xterm-256color) will set the profile to ANSI256.
  #   - Using any color terminal (e.g. TERM=xterm-color) will set the profile to ANSI.
  #   - Using CLICOLOR=1 without TERM defined should be treated as ANSI if the
  #     output is a terminal.
  #   - NO_COLOR takes precedence over CLICOLOR/CLICOLOR_FORCE, and will disable
  #     colors but not text decoration, i.e. bold, italic, faint, etc.
  #
  # See https://no-color.org/ and https://bixense.com/clicolors/ for more information.
  def self.detect(output : IO, env : Array(String)) : Profile
    environ = new_environ(env)
    isatty = tty_forced?(environ) || output.tty?
    term = environ["TERM"]?
    is_dumb = term.nil? || term == DUMB_TERM
    env_profile = color_profile(isatty, environ)

    if env_profile == Profile::TrueColor || no_color?(environ)
      # We already know we have TrueColor, or NO_COLOR is set.
      return env_profile
    end

    if isatty && !is_dumb
      terminfo_profile = terminfo_profile(term.to_s)
      tmux_profile = tmux_profile(environ)

      # Color profile is the maximum of env, terminfo, and tmux.
      return max_profile(env_profile, max_profile(terminfo_profile, tmux_profile))
    end

    env_profile
  end

  # Env returns the color profile based on the terminal environment variables.
  # This respects NO_COLOR, CLICOLOR, and CLICOLOR_FORCE environment variables.
  def self.env(env : Array(String)) : Profile
    color_profile(true, new_environ(env))
  end

  # ameba:disable Metrics/CyclomaticComplexity
  private def self.color_profile(isatty : Bool, environ : Environ) : Profile
    term = environ["TERM"]?
    is_dumb = term.nil? || term == DUMB_TERM
    env_profile = env_color_profile(environ)

    if !isatty || is_dumb
      # Check if the output is a terminal.
      # Treat dumb terminals as NoTTY
      profile = Profile::NoTTY
    else
      profile = env_profile
    end

    if no_color?(environ) && isatty
      if profile > Profile::ASCII
        profile = Profile::ASCII
      end
      return profile
    end

    if cli_color_forced?(environ)
      if profile < Profile::ANSI
        profile = Profile::ANSI
      end
      if env_profile > profile
        profile = env_profile
      end
      return profile
    end

    if cli_color?(environ)
      if isatty && !is_dumb && profile < Profile::ANSI
        profile = Profile::ANSI
      end
    end

    profile
  end

  # no_color? returns true if the environment variables explicitly disable color output
  # by setting NO_COLOR (https://no-color.org/).
  private def self.no_color?(environ : Environ) : Bool
    no_color = environ["NO_COLOR"]?
    return false if no_color.nil?
    no_color == "1" || no_color.downcase == "true"
  end

  private def self.cli_color?(environ : Environ) : Bool
    cli_color = environ["CLICOLOR"]?
    return false if cli_color.nil?
    cli_color == "1" || cli_color.downcase == "true"
  end

  private def self.cli_color_forced?(environ : Environ) : Bool
    cli_color_force = environ["CLICOLOR_FORCE"]?
    return false if cli_color_force.nil?
    cli_color_force == "1" || cli_color_force.downcase == "true"
  end

  private def self.tty_forced?(environ : Environ) : Bool
    skip = environ["TTY_FORCE"]?
    return false if skip.nil?
    skip == "1" || skip.downcase == "true"
  end

  private def self.color_term?(environ : Environ) : Bool
    color_term = environ["COLORTERM"]? || ""
    color_term = color_term.downcase
    color_term == "truecolor" || color_term == "24bit" ||
      color_term == "yes" || color_term == "true"
  end

  # env_color_profile returns the color profile inferred from the environment.
  private def self.env_color_profile(environ : Environ) : Profile
    term = environ["TERM"]?
    if term.nil? || term.empty? || term == DUMB_TERM
      profile = Profile::NoTTY
      {% if flag?(:windows) %}
        # Use Windows API to detect color profile. Windows Terminal and
        # cmd.exe don't define $TERM.
        if wcp = windows_color_profile(environ)
          profile = wcp
        end
      {% end %}
    else
      profile = Profile::ANSI
    end

    case
    when term.to_s.includes?("alacritty"),
         term.to_s.includes?("contour"),
         term.to_s.includes?("foot"),
         term.to_s.includes?("ghostty"),
         term.to_s.includes?("kitty"),
         term.to_s.includes?("rio"),
         term.to_s.includes?("st"),
         term.to_s.includes?("wezterm")
      return Profile::TrueColor
    when term.to_s.starts_with?("tmux"), term.to_s.starts_with?("screen")
      if profile < Profile::ANSI256
        profile = Profile::ANSI256
      end
    when term.to_s.starts_with?("xterm")
      if profile < Profile::ANSI
        profile = Profile::ANSI
      end
    end

    if environ["WT_SESSION"]? && !environ["WT_SESSION"].empty?
      # Windows Terminal supports TrueColor
      return Profile::TrueColor
    end

    if environ["GOOGLE_CLOUD_SHELL"]? == "1" || environ["GOOGLE_CLOUD_SHELL"]? == "true"
      return Profile::TrueColor
    end

    # GNU Screen doesn't support TrueColor
    # Tmux doesn't support $COLORTERM
    if color_term?(environ) && !term.to_s.starts_with?("screen") && !term.to_s.starts_with?("tmux")
      return Profile::TrueColor
    end

    if term.to_s.ends_with?("256color") && profile < Profile::ANSI256
      profile = Profile::ANSI256
    end

    # Direct color terminals support true colors.
    if term.to_s.ends_with?("direct")
      return Profile::TrueColor
    end

    profile
  end

  # Terminfo returns the color profile based on the terminal's terminfo
  # database. This relies on the Tc and RGB capabilities to determine if the
  # terminal supports TrueColor.
  # If term is empty or "dumb", it returns NoTTY.
  def self.terminfo_profile(term : String) : Profile
    if term.empty? || term == "dumb"
      return Profile::NoTTY
    end

    begin
      ti = Terminfo::Data.new(term: term)
      # Check extended boolean capabilities
      if ti.extended_booleans["Tc"]? || ti.extended_booleans["RGB"]?
        return Profile::TrueColor
      end
    rescue
      # terminfo load failed
    end

    Profile::ANSI
  end

  # Tmux returns the color profile based on `tmux info` output. Tmux supports
  # overriding the terminal's color capabilities, so this function will return
  # the color profile based on the tmux configuration.
  def self.tmux(env : Array(String)) : Profile
    tmux_profile(new_environ(env))
  end

  # tmux returns the color profile based on the tmux environment variables.
  private def self.tmux_profile(environ : Environ) : Profile
    tmux = environ["TMUX"]?
    if tmux.nil? || tmux.empty?
      # Not in tmux
      return Profile::NoTTY
    end

    # Check if tmux has either Tc or RGB capabilities. Otherwise, return
    # ANSI256.
    profile = Profile::ANSI256

    begin
      output = `tmux info 2>&1`
      if output.includes?("Tc") || output.includes?("RGB")
        if output.includes?("true")
          profile = Profile::TrueColor
        end
      end
    rescue
      # Ignore errors from tmux command
    end

    profile
  end

  private def self.max_profile(a : Profile, b : Profile) : Profile
    a > b ? a : b
  end

  {% if flag?(:windows) %}
    @[Link("ntdll")]
    lib Ntdll
      fun RtlGetNtVersionNumbers(major : UInt32*, minor : UInt32*, build : UInt32*) : Void
    end

    # Windows-specific color profile detection
    private def self.windows_color_profile(environ : Environ) : Profile?
      if environ["ConEmuANSI"]? == "ON"
        return Profile::TrueColor
      end

      version = windows_version
      return nil unless version
      major, minor, build = version

      if build < 10586 || major < 10
        # No ANSI support before WindowsNT 10 build 10586
        if !environ["ANSICON"]?.nil? && !environ["ANSICON"]?.empty?
          ansicon_ver = environ["ANSICON_VER"]?
          if ansicon_ver && !ansicon_ver.empty?
            cv = ansicon_ver.to_i? || 0
            if cv < 181
              # No 8 bit color support before ANSICON 1.81
              return Profile::ANSI
            end
            return Profile::ANSI256
          else
            # ANSICON_VER missing or empty
            return Profile::ANSI
          end
        end
        return Profile::NoTTY
      end

      if build < 14931
        # No true color support before build 14931
        return Profile::ANSI256
      end

      Profile::TrueColor
    end

    # Get Windows version numbers (major, minor, build)
    # Returns nil if version detection fails
    private def self.windows_version : {Int32, Int32, Int32}?
      major = 0_u32
      minor = 0_u32
      build = 0_u32
      Ntdll.RtlGetNtVersionNumbers(pointerof(major), pointerof(minor), pointerof(build))
      # The build number has a high bit set for release builds, mask it out
      build &= 0x7FFF_FFFF
      {major.to_i32, minor.to_i32, build.to_i32}
    rescue
      # If Windows API call fails, return nil
      nil
    end
  {% end %}
end
