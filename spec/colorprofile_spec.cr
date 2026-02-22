require "./spec_helper"
require "ansi"

describe Colorprofile do
  describe "Profile" do
    it "defines all profile constants" do
      Colorprofile::Profile::Unknown.value.should eq 0
      Colorprofile::Profile::NoTTY.value.should eq 1
      Colorprofile::Profile::ASCII.value.should eq 2
      Colorprofile::Profile::ANSI.value.should eq 3
      Colorprofile::Profile::ANSI256.value.should eq 4
      Colorprofile::Profile::TrueColor.value.should eq 5
    end

    it "converts profiles to strings" do
      Colorprofile::Profile::TrueColor.to_s.should eq "TrueColor"
      Colorprofile::Profile::ANSI256.to_s.should eq "ANSI256"
      Colorprofile::Profile::ANSI.to_s.should eq "ANSI"
      Colorprofile::Profile::ASCII.to_s.should eq "Ascii"
      Colorprofile::Profile::NoTTY.to_s.should eq "NoTTY"
      Colorprofile::Profile::Unknown.to_s.should eq "Unknown"
    end

    it "provides ascii alias" do
      Colorprofile::Profile.ascii.should eq Colorprofile::Profile::ASCII
    end
  end

  describe "color conversion" do
    it "returns nil for NoTTY and ASCII profiles" do
      color = Ansi::Color.new(100_u8, 150_u8, 200_u8)
      Colorprofile::Profile::NoTTY.convert(color).should be_nil
      Colorprofile::Profile::ASCII.convert(color).should be_nil
    end

    it "passes through for TrueColor" do
      color = Ansi::Color.new(100_u8, 150_u8, 200_u8)
      result = Colorprofile::Profile::TrueColor.convert(color)
      result.should eq color
    end
  end

  describe "environment detection" do
    # Test cases from vendor/env_test.go
    cases = [
      {
        name:     "empty",
        environ:  [] of String,
        expected: {% if flag?(:windows) %}
          # TODO: Implement proper Windows detection (issue #2)
          Colorprofile::Profile::TrueColor
        {% else %}
          Colorprofile::Profile::NoTTY
        {% end %},
      },
      {
        name:     "no tty",
        environ:  ["TERM=dumb"],
        expected: Colorprofile::Profile::NoTTY,
      },
      {
        name:     "dumb term, truecolor, not forced",
        environ:  ["TERM=dumb", "COLORTERM=truecolor"],
        expected: Colorprofile::Profile::NoTTY,
      },
      {
        name:     "dumb term, truecolor, forced",
        environ:  ["TERM=dumb", "COLORTERM=truecolor", "CLICOLOR_FORCE=1"],
        expected: Colorprofile::Profile::TrueColor,
      },
      {
        name:     "dumb term, CLICOLOR_FORCE=1",
        environ:  ["TERM=dumb", "CLICOLOR_FORCE=1"],
        expected: {% if flag?(:windows) %}
          Colorprofile::Profile::TrueColor
        {% else %}
          Colorprofile::Profile::ANSI
        {% end %},
      },
      {
        name:     "dumb term, CLICOLOR=1",
        environ:  ["TERM=dumb", "CLICOLOR=1"],
        expected: Colorprofile::Profile::NoTTY,
      },
      {
        name:     "xterm-256color",
        environ:  ["TERM=xterm-256color"],
        expected: Colorprofile::Profile::ANSI256,
      },
      {
        name:     "xterm-256color, CLICOLOR=1",
        environ:  ["TERM=xterm-256color", "CLICOLOR=1"],
        expected: Colorprofile::Profile::ANSI256,
      },
      {
        name:     "xterm-256color, COLORTERM=yes",
        environ:  ["TERM=xterm-256color", "COLORTERM=yes"],
        expected: Colorprofile::Profile::TrueColor,
      },
      {
        name:     "xterm-256color, NO_COLOR=1",
        environ:  ["TERM=xterm-256color", "NO_COLOR=1"],
        expected: Colorprofile::Profile::ASCII,
      },
      {
        name:     "xterm",
        environ:  ["TERM=xterm"],
        expected: Colorprofile::Profile::ANSI,
      },
      {
        name:     "xterm, NO_COLOR=1",
        environ:  ["TERM=xterm", "NO_COLOR=1"],
        expected: Colorprofile::Profile::ASCII,
      },
      {
        name:     "xterm, CLICOLOR=1",
        environ:  ["TERM=xterm", "CLICOLOR=1"],
        expected: Colorprofile::Profile::ANSI,
      },
      {
        name:     "xterm, CLICOLOR_FORCE=1",
        environ:  ["TERM=xterm", "CLICOLOR_FORCE=1"],
        expected: Colorprofile::Profile::ANSI,
      },
      {
        name:     "xterm-16color",
        environ:  ["TERM=xterm-16color"],
        expected: Colorprofile::Profile::ANSI,
      },
      {
        name:     "xterm-color",
        environ:  ["TERM=xterm-color"],
        expected: Colorprofile::Profile::ANSI,
      },
      {
        name:     "xterm-256color, NO_COLOR=1, CLICOLOR_FORCE=1",
        environ:  ["TERM=xterm-256color", "NO_COLOR=1", "CLICOLOR_FORCE=1"],
        expected: Colorprofile::Profile::ASCII,
      },
      {
        name:     "Windows Terminal",
        environ:  ["WT_SESSION=1"],
        expected: {% if flag?(:windows) %}
          Colorprofile::Profile::TrueColor
        {% else %}
          Colorprofile::Profile::NoTTY
        {% end %},
      },
      {
        name:     "Windows Terminal bash.exe",
        environ:  ["TERM=xterm-256color", "WT_SESSION=1"],
        expected: Colorprofile::Profile::TrueColor,
      },
      {
        name:     "screen default",
        environ:  ["TERM=screen"],
        expected: Colorprofile::Profile::ANSI256,
      },
      {
        name:     "screen colorterm",
        environ:  ["TERM=screen", "COLORTERM=truecolor"],
        expected: Colorprofile::Profile::ANSI256,
      },
      {
        name:     "tmux colorterm",
        environ:  ["TERM=tmux", "COLORTERM=truecolor"],
        expected: Colorprofile::Profile::ANSI256,
      },
      {
        name:     "tmux 256color",
        environ:  ["TERM=tmux-256color"],
        expected: Colorprofile::Profile::ANSI256,
      },
      {
        name:     "ignore COLORTERM when no TERM is defined",
        environ:  ["COLORTERM=truecolor"],
        expected: {% if flag?(:windows) %}
          # TODO: Implement proper Windows detection (issue #2)
          Colorprofile::Profile::TrueColor
        {% else %}
          Colorprofile::Profile::NoTTY
        {% end %},
      },
      {
        name:     "direct color xterm terminal",
        environ:  ["TERM=xterm-direct"],
        expected: Colorprofile::Profile::TrueColor,
      },
    ]

    cases.each do |test_case|
      it test_case[:name] do
        profile = Colorprofile.env(test_case[:environ])
        profile.should eq test_case[:expected]
      end
    end
  end

  describe "Writer" do
    it "creates a writer with detected profile" do
      io = IO::Memory.new
      writer = Colorprofile::Writer.new(io, Colorprofile::Profile::ANSI)
      writer.profile.should eq Colorprofile::Profile::ANSI
    end

    it "writes text for TrueColor profile" do
      io = IO::Memory.new
      writer = Colorprofile::Writer.new(io, Colorprofile::Profile::TrueColor)
      writer.write_string("Hello")
      io.to_s.should eq "Hello"
    end
  end
end
