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
    it "detects profile from environment" do
      # Test with minimal environment
      env = ["TERM=xterm-256color"]
      profile = Colorprofile.env(env)
      profile.should be >= Colorprofile::Profile::ANSI
    end

    it "respects NO_COLOR" do
      env = ["TERM=xterm-256color", "NO_COLOR=1"]
      profile = Colorprofile.env(env)
      profile.should eq Colorprofile::Profile::ASCII
    end

    it "respects CLICOLOR_FORCE" do
      env = ["CLICOLOR_FORCE=1"]
      profile = Colorprofile.env(env)
      profile.should be >= Colorprofile::Profile::ANSI
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
