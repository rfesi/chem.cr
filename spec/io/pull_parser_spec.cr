require "../spec_helper"

alias ParseException = Chem::IO::ParseException

class Parser
  include Chem::IO::PullParser

  def initialize(content : String)
    @input = IO::Memory.new(content)
  end

  def parse; end
end

describe Chem::IO::PullParser do
  describe "#fail" do
    it "fails with message containing line and column" do
      parser = Parser.new "Lorem ipsum\ndolor\nsit amet,\nconsectetur adipiscing."
      parser.read_chars 22
      expect_raises ParseException, "Invalid character at 3:5" do
        parser.fail "Invalid character"
      end
    end
  end

  describe "#peek_char" do
    it "reads a char without modifying io position" do
      parser = Parser.new "Lorem ipsum"
      parser.peek_char.should eq 'L'
      parser.peek_char.should eq 'L'
    end
  end

  describe "#peek_chars" do
    it "reads N characters without modifying io position" do
      parser = Parser.new "Lorem ipsum"
      parser.peek_chars(5).should eq "Lorem"
      parser.peek_chars(5).should eq "Lorem"
    end
  end

  describe "#peek_line" do
    it "reads a line without modifying io position" do
      parser = Parser.new("Lorem ipsum\ndolor sit amet")
      parser.peek_line.should eq "Lorem ipsum"
      parser.peek_line.should eq "Lorem ipsum"
    end
  end

  describe "#prev_char" do
    it "returns the previous char" do
      parser = Parser.new "Lorem ipsum"
      parser.read_chars 10
      parser.prev_char.should eq 'u'
    end

    it "fails at the beginning of io" do
      parser = Parser.new "Lorem ipsum"
      expect_raises ParseException, "Couldn't read previous character" do
        parser.prev_char
      end
    end
  end

  describe "#read_char" do
    it "reads one character" do
      parser = Parser.new "Lorem ipsum"
      parser.read_char.should eq 'L'
      parser.read_char.should eq 'o'
    end

    it "fails at eof" do
      expect_raises IO::EOFError do
        Parser.new("").read_char
      end
    end
  end

  describe "#read_char?" do
    it "returns nil at eof" do
      Parser.new("").read_char?.should be_nil
    end
  end

  describe "#read_char_or_null" do
    it "reads one character" do
      parser = Parser.new "Lorem ipsum"
      parser.read_char_or_null.should eq 'L'
      parser.read_char_or_null.should eq 'o'
    end

    it "returns nil when character is whitespace" do
      parser = Parser.new " Lorem ipsum"
      parser.read_char_or_null.should be_nil
    end
  end

  describe "#read_chars" do
    it "reads N characters" do
      parser = Parser.new "Lorem ipsum"
      parser.read_chars(5).should eq "Lorem"
      parser.read_chars(6).should eq " ipsum"
    end

    it "reads N characters if sentinel is not found" do
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.read_chars(11, stop_at: '\n').should eq "Lorem ipsum"
      parser.read_chars(6).should eq " dolor"
    end

    it "reads less than N characters stopping at sentinel character" do
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.read_chars(11, stop_at: ' ').should eq "Lorem"
      parser.read_chars(6).should eq " ipsum"
    end

    it "fails at eof" do
      expect_raises IO::EOFError do
        Parser.new("").read_chars 10
      end
    end
  end

  describe "#read_chars?" do
    it "returns nil at eof" do
      Parser.new("").read_chars?(10).should be_nil
    end
  end

  describe "#read_chars_or_null" do
    it "reads N characters" do
      parser = Parser.new "Lorem ipsum"
      parser.read_chars_or_null(5).should eq "Lorem"
    end

    it "returns nil when characters are whitespace" do
      Parser.new(" ").read_chars_or_null(1).should be_nil
      Parser.new("    ").read_chars_or_null(4).should be_nil
      Parser.new("  \n  ").read_chars_or_null(5).should be_nil
    end
  end

  describe "#read_float" do
    it "reads a float" do
      Parser.new("-125.35").read_float.should eq -125.35
    end

    it "reads a float from N characters" do
      Parser.new("-125.35").read_float(6).should eq -125.3
    end

    it "reads a float with leading spaces" do
      Parser.new("  -125.35").read_float.should eq -125.35
    end

    it "fails with an invalid float" do
      expect_raises ParseException, "Couldn't read a decimal number at 1:0" do
        Parser.new("abcd").read_float
      end
    end
  end

  describe "#read_int" do
    it "reads an integer from N characters" do
      Parser.new("12574").read_int(4).should eq 1257
    end

    it "reads an integer from less than N characters stopping at sentinel character" do
      Parser.new("125\n74").read_int(5, stop_at: '\n').should eq 125
    end

    it "fails with an invalid integer" do
      expect_raises ParseException, "Couldn't read a number at 1:4" do
        Parser.new("abcd").read_int 4
      end
    end
  end

  describe "#read_int_or_null" do
    it "reads an integer from N characters" do
      Parser.new("12574").read_int_or_null(4).should eq 1257
    end

    it "reads an integer from less than N characters stopping at sentinel character" do
      Parser.new("125\n74").read_int_or_null(5, stop_at: '\n').should eq 125
    end

    it "returns nil if characters are whitespace" do
      Parser.new("  ").read_int_or_null(2).should be_nil
    end

    it "fails with an invalid integer" do
      expect_raises ParseException, "Couldn't read a number at 1:4" do
        Parser.new("abcd").read_int 4
      end
    end
  end

  describe "#read_line" do
    it "reads a line" do
      parser = Parser.new("Lorem ipsum\ndolor sit amet")
      parser.read_line.should eq "Lorem ipsum"
    end

    it "fails at eof" do
      expect_raises IO::EOFError do
        Parser.new("").read_line
      end
    end
  end

  describe "#read_multiple_int" do
    it "reads consecutive integers separated by whitespace" do
      parser = Parser.new "4 8 15 16 23 42"
      parser.read_multiple_int.should eq [4, 8, 15, 16, 23, 42]
    end

    it "returns an empty array if there are no integers" do
      Parser.new("abcd").read_multiple_int.empty?.should be_true
    end
  end

  describe "#rewind" do
    it "moves the io backwards while the previous character passes a predicate" do
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.read_chars 10
      parser.rewind { |char| char.letter? }.read_char.should eq 'i'
    end

    it "does not fail at the beginning of io" do
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.rewind { |char| char.letter? }.read_char.should eq 'L'
    end
  end

  describe "#scan" do
    it "reads characters that match a pattern" do
      parser = Parser.new "Lorem ipsum!\ndolor sit amet"
      parser.scan(/\w/).should eq "Lorem"
    end

    it "returns an empty string if the next character does not match the pattern" do
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.scan(/\d/).should eq ""
    end

    it "reads characters that pass a predicate" do
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.scan { |char| char.letter? }.should eq "Lorem"
    end

    it "returns an empty string if the next character does not pass the predicate" do
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.scan { |char| char.number? }.should eq ""
    end
  end

  describe "#scan_multiple" do
    it "reads consecutive character groups" do
      parser = Parser.new "I you he she it we they. 231345"
      groups = parser.scan_multiple { |char| char.letter? }
      groups.should eq ["I", "you", "he", "she", "it", "we", "they"]
    end
  end

  describe "#scan_until" do
    it "reads characters that does not match a pattern" do
      parser = Parser.new "Lorem ipsum!, dolor sit amet"
      parser.scan_until(/[,!]/).should eq "Lorem ipsum"
      parser.read_char.should eq '!'
    end
  end

  describe "#skip" do
    it "skips characters that pass a predicate" do
      parser = Parser.new "1342,!, ,Lorem ipsum"
      parser.skip { |char| !char.letter? }.read_char.should eq 'L'
    end

    it "skips N characters if they pass the predicate" do
      parser = Parser.new "Lorem ipsum"
      parser.skip(10) { |char| !char.number? }.read_char.should eq 'm'
    end

    it "skips less than N characters stopping at the character that does not pass the predicate" do
      parser = Parser.new "Lorem ipsum"
      parser.skip(10) { |char| char.letter? }.read_char.should eq ' '
    end

    it "skips characters that match a pattern" do
      parser = Parser.new "Lorem ipsum!\ndolor sit amet"
      parser.skip(/[\w\s]/).read_char.should eq '!'
    end
  end

  describe "#skip_char" do
    it "skips a character" do
      parser = Parser.new "Lorem ipsum"
      parser.skip_char.read_char.should eq 'o'
    end
  end

  describe "#skip_chars" do
    it "skips N characters" do
      parser = Parser.new "Lorem ipsum"
      parser.skip_chars(10).read_char.should eq 'm'
    end

    it "skips N characters if sentinel is not found" do
      parser = Parser.new "Lorem ipsum"
      parser.skip_chars(10, stop_at: '\n').read_char.should eq 'm'
    end

    it "skips less than N characters stopping at sentinel character" do
      parser = Parser.new "Lorem ipsum"
      parser.skip_chars(10, stop_at: ' ').read_char.should eq ' '
    end
  end

  describe "#skip_line" do
    it "skips line" do
      parser = Parser.new "Lorem ipsum\ndolor sit amet"
      parser.skip_line.read_char.should eq 'd'
    end
  end

  describe "#skip_whitespace" do
    it "skips whitespace" do
      parser = Parser.new "  \nLorem ipsum"
      parser.skip_whitespace.read_char.should eq 'L'
    end
  end
end
