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

    # Test cases from vendor/writer_test.go
    writers = {
      Colorprofile::Profile::TrueColor => ->(io : IO) { Colorprofile::Writer.new(io, Colorprofile::Profile::TrueColor) },
      Colorprofile::Profile::ANSI256   => ->(io : IO) { Colorprofile::Writer.new(io, Colorprofile::Profile::ANSI256) },
      Colorprofile::Profile::ANSI      => ->(io : IO) { Colorprofile::Writer.new(io, Colorprofile::Profile::ANSI) },
      Colorprofile::Profile::ASCII     => ->(io : IO) { Colorprofile::Writer.new(io, Colorprofile::Profile::ASCII) },
      Colorprofile::Profile::NoTTY     => ->(io : IO) { Colorprofile::Writer.new(io, Colorprofile::Profile::NoTTY) },
    }

    writer_cases = [
      {
        name:               "empty",
        input:              "",
        expected_truecolor: "",
        expected_ansi256:   "",
        expected_ansi:      "",
        expected_ascii:     "",
      },
      {
        name:               "no styles",
        input:              "hello world",
        expected_truecolor: "hello world",
        expected_ansi256:   "hello world",
        expected_ansi:      "hello world",
        expected_ascii:     "hello world",
      },
      {
        name:               "simple style attributes",
        input:              "hello \e[1mworld\e[m",
        expected_truecolor: "hello \e[1mworld\e[m",
        expected_ansi256:   "hello \e[1mworld\e[m",
        expected_ansi:      "hello \e[1mworld\e[m",
        expected_ascii:     "hello \e[1mworld\e[m",
      },
      {
        name:               "simple ansi color fg",
        input:              "hello \e[31mworld\e[m",
        expected_truecolor: "hello \e[31mworld\e[m",
        expected_ansi256:   "hello \e[31mworld\e[m",
        expected_ansi:      "hello \e[31mworld\e[m",
        expected_ascii:     "hello \e[mworld\e[m",
      },
      {
        name:               "default fg color after ansi color",
        input:              "\e[31mhello \e[39mworld\e[m",
        expected_truecolor: "\e[31mhello \e[39mworld\e[m",
        expected_ansi256:   "\e[31mhello \e[39mworld\e[m",
        expected_ansi:      "\e[31mhello \e[39mworld\e[m",
        expected_ascii:     "\e[mhello \e[mworld\e[m",
      },
      {
        name:               "ansi color fg and bg",
        input:              "\e[31;42mhello world\e[m",
        expected_truecolor: "\e[31;42mhello world\e[m",
        expected_ansi256:   "\e[31;42mhello world\e[m",
        expected_ansi:      "\e[31;42mhello world\e[m",
        expected_ascii:     "\e[mhello world\e[m",
      },
      {
        name:               "bright ansi color fg and bg",
        input:              "\e[91;102mhello world\e[m",
        expected_truecolor: "\e[91;102mhello world\e[m",
        expected_ansi256:   "\e[91;102mhello world\e[m",
        expected_ansi:      "\e[91;102mhello world\e[m",
        expected_ascii:     "\e[mhello world\e[m",
      },
      {
        name:               "simple 256 color fg",
        input:              "hello \e[38;5;196mworld\e[m",
        expected_truecolor: "hello \e[38;5;196mworld\e[m",
        expected_ansi256:   "hello \e[38;5;196mworld\e[m",
        expected_ansi:      "hello \e[91mworld\e[m",
        expected_ascii:     "hello \e[mworld\e[m",
      },
      {
        name:               "256 color bg",
        input:              "\e[48;5;196mhello world\e[m",
        expected_truecolor: "\e[48;5;196mhello world\e[m",
        expected_ansi256:   "\e[48;5;196mhello world\e[m",
        expected_ansi:      "\e[101mhello world\e[m",
        expected_ascii:     "\e[mhello world\e[m",
      },
      {
        name:               "simple true color bg",
        input:              "hello \e[38;2;255;133;55mworld\e[m",
        expected_truecolor: "hello \e[38;2;255;133;55mworld\e[m",
        expected_ansi256:   "hello \e[38;5;209mworld\e[m",
        expected_ansi:      "hello \e[91mworld\e[m",
        expected_ascii:     "hello \e[mworld\e[m",
      },
      {
        name:               "itu true color bg",
        input:              "hello \e[38:2::255:133:55mworld\e[m",
        expected_truecolor: "hello \e[38:2::255:133:55mworld\e[m",
        expected_ansi256:   "hello \e[38;5;209mworld\e[m",
        expected_ansi:      "hello \e[91mworld\e[m",
        expected_ascii:     "hello \e[mworld\e[m",
      },
      {
        name:               "simple ansi 256 color bg",
        input:              "hello \e[48:5:196mworld\e[m",
        expected_truecolor: "hello \e[48:5:196mworld\e[m",
        expected_ansi256:   "hello \e[48;5;196mworld\e[m",
        expected_ansi:      "hello \e[101mworld\e[m",
        expected_ascii:     "hello \e[mworld\e[m",
      },
      {
        name:               "simple missing param",
        input:              "\e[31mhello \e[;1mworld",
        expected_truecolor: "\e[31mhello \e[;1mworld",
        expected_ansi256:   "\e[31mhello \e[;1mworld",
        expected_ansi:      "\e[31mhello \e[;1mworld",
        expected_ascii:     "\e[mhello \e[;1mworld",
      },
      {
        name:               "color with other attributes",
        input:              "\e[1;38;5;204mhello \e[38;5;204mworld\e[m",
        expected_truecolor: "\e[1;38;5;204mhello \e[38;5;204mworld\e[m",
        expected_ansi256:   "\e[1;38;5;204mhello \e[38;5;204mworld\e[m",
        expected_ansi:      "\e[1;91mhello \e[91mworld\e[m",
        expected_ascii:     "\e[1mhello \e[mworld\e[m",
      },
    ]

    writer_cases.each do |test_case|
      writers.each do |profile, writer_fn|
        it "#{test_case[:name]} (#{profile})" do
          io = IO::Memory.new
          writer = writer_fn.call(io)
          writer.write_string(test_case[:input])

          expected = case profile
                     when Colorprofile::Profile::TrueColor
                       test_case[:expected_truecolor]
                     when Colorprofile::Profile::ANSI256
                       test_case[:expected_ansi256]
                     when Colorprofile::Profile::ANSI
                       test_case[:expected_ansi]
                     when Colorprofile::Profile::ASCII
                       test_case[:expected_ascii]
                     when Colorprofile::Profile::NoTTY
                       Ansi.strip(test_case[:input])
                     else
                       ""
                     end

          io.to_s.should eq expected
        end
      end
    end
  end
end
