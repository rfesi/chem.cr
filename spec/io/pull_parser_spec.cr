require "../spec_helper"

alias ParseException = Chem::IO::ParseException

class Parser
  include Chem::IO::PullParser

  def initialize(content : String)
    @io = IO::Memory.new(content)
  end

  def parse_exception(msg : String)
    raise ParseException.new msg
  end
end

describe Chem::IO::PullParser do
  describe "#check" do
    it "checks current character" do
      parser = Parser.new "Lorem ipsum"
      parser.check('L').should be_true
      parser.check('o').should be_false
      parser.read_char.should eq 'L'
    end

    it "checks current character (block)" do
      parser = Parser.new "Lorem ipsum"
      parser.check(&.letter?).should be_true
      parser.check(&.ascii_lowercase?).should be_false
      parser.read_char.should eq 'L'
    end

    it "checks current characters" do
      parser = Parser.new "Lorem ipsum"
      parser.check("Lorem").should be_true
      parser.check("orem").should be_false
      parser.read_chars(6).should eq "Lorem "
      parser.check("ipsum ").should be_false
    end

    it "returns false at end of file" do
      parser = Parser.new "Lorem ipsum\n"
      parser.read_line
      parser.read_char?.should be_nil
      parser.check("Lorem").should be_false
    end
  end

  describe "#check_in_set" do
    it "checks current character is in charset" do
      parser = Parser.new "Lorem ipsum"
      parser.check_in_set("A-Z").should be_true
      parser.check_in_set("a-z0-9").should be_false
      parser.read_char.should eq 'L'
    end
  end

  describe "#fail" do
    it "fails with message containing line and column" do
      parser = Parser.new "Lorem ipsum\ndolor\nsit amet,\nconsectetur adipiscing."
      parser.read_chars 22
      expect_raises ParseException, "Invalid character" do
        parser.parse_exception "Invalid character"
      end
    end
  end

  describe "#peek" do
    it "reads a character without advancing position" do
      parser = Parser.new "Lorem ipsum"
      parser.peek.should eq 'L'
      parser.peek.should eq 'L'
    end

    it "reads N characters without advancing position" do
      parser = Parser.new "Lorem ipsum"
      parser.peek(5).should eq "Lorem"
      parser.peek(5).should eq "Lorem"
    end

    it "fails at end of file" do
      parser = Parser.new "Lorem ipsum"
      parser.read_line
      expect_raises IO::EOFError do
        parser.peek
      end
    end
  end

  describe "#peek?" do
    it "reads a character without advancing position" do
      parser = Parser.new "Lorem ipsum"
      parser.peek?.should eq 'L'
      parser.peek?.should eq 'L'
    end

    it "reads N characters without advancing position" do
      parser = Parser.new "Lorem ipsum"
      parser.peek?(5).should eq "Lorem"
      parser.peek?(5).should eq "Lorem"
    end

    it "returns nil at end of file" do
      parser = Parser.new "Lorem ipsum"
      parser.read_line
      parser.peek?.should be_nil
    end
  end

  describe "#peek_line" do
    it "reads a line without modifying io position" do
      parser = Parser.new("Lorem ipsum\ndolor sit amet")
      parser.peek_line.should eq "Lorem ipsum"
      parser.peek_line.should eq "Lorem ipsum"
    end

    it "fails at end of line" do
      parser = Parser.new ""
      expect_raises IO::EOFError do
        parser.peek_line
      end
    end
  end

  describe "#peek_line?" do
    it "returns nil at end of file" do
      parser = Parser.new("Lorem ipsum\n")
      parser.read_line
      parser.peek_line?.should be_nil
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

  describe "#read_char_in_set" do
    it "reads a character" do
      parser = Parser.new "Lorem ipsum"
      parser.read_char_in_set("A-Z").should eq 'L'
    end

    it "does not read a character if not in charset" do
      parser = Parser.new "Lorem ipsum"
      parser.read_char_in_set("0-9").should be_nil
      parser.read_char.should eq 'L'
    end

    it "returns nil at end of file" do
      parser = Parser.new "Lorem ipsum"
      parser.read_line
      parser.read_char_in_set("a-z").should be_nil
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
      Parser.new("125.35").read_float.should eq 125.35
      Parser.new("+125.35").read_float.should eq 125.35
      Parser.new("-125.35").read_float.should eq -125.35
      Parser.new("1.2.3.4").read_float.should eq 1.2
    end

    it "reads a float from N characters" do
      Parser.new("-125.35").read_float(6).should eq -125.3
    end

    it "reads a float with leading spaces" do
      Parser.new("  -125.35").read_float.should eq -125.35
    end

    it "reads a float in scientific notation" do
      Parser.new("1e-1").read_float.should eq 0.1
      Parser.new("1E-1").read_float.should eq 0.1
      Parser.new("-1.25e4").read_float.should eq -12_500
      Parser.new("-1.25e-3").read_float.should eq -0.00125
    end

    it "fails with an invalid float" do
      expect_raises ParseException, "Couldn't read a decimal number" do
        Parser.new("abcd").read_float
      end
    end
  end

  describe "#read_int" do
    it "reads an integer" do
      Parser.new("12574").read_int.should eq 12574
    end

    it "reads an integer from N characters" do
      Parser.new("12574").read_int(4).should eq 1257
    end

    it "reads an integer from less than N characters stopping at sentinel character" do
      Parser.new("125\n74").read_int(5, stop_at: '\n').should eq 125
    end

    it "fails with an invalid integer" do
      expect_raises ParseException, "Couldn't read a number" do
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
      expect_raises ParseException, "Couldn't read a number" do
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

    it "reads characters into a IO object" do
      io = IO::Memory.new
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.scan io, &.letter?
      io.to_s.should eq "Lorem"
    end

    it "reads characters that match a pattern into a IO object" do
      io = IO::Memory.new
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.scan io, /[A-Z]/
      io.to_s.should eq "L"
    end
  end

  describe "#scan_in_set" do
    it "reads characters in set" do
      parser = Parser.new "Lorem ipsum dolor sit amet"
      parser.scan_in_set("A-Z").should eq "L"
      parser.scan_in_set("A-Z").should eq ""
      parser.scan_in_set("a-z").should eq "orem"
    end
  end

  describe "#scan_delimited" do
    it "reads character groups delimited by whitespace" do
      parser = Parser.new "I you he she it we they. 231345"
      groups = parser.scan_delimited &.letter?
      groups.should eq ["I", "you", "he", "she", "it", "we", "they"]
    end

    it "reads character groups delimited by a character" do
      parser = Parser.new "a|b||cd|ef  \n1|2|34"
      groups = parser.scan_delimited '|', &.letter?
      groups.should eq ["a", "b", "", "cd", "ef"]
    end

    it "reads character groups delimited by characters" do
      parser = Parser.new "a|b__cd|ef__\n1|2|34"
      groups = parser.scan_delimited_by_set "|_", &.letter?
      groups.should eq ["a", "b", "cd", "ef"]
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
    it "skips a character" do
      parser = Parser.new "Lorem ipsum"
      parser.skip.read_char.should eq 'o'
    end

    it "skips N characters" do
      parser = Parser.new "Lorem ipsum"
      parser.skip(10).read_char.should eq 'm'
    end

    it "skips occurrences of a character" do
      parser = Parser.new "---abcd"
      parser.skip('-').read_char.should eq 'a'
    end

    it "skips N occurrences of a character at most" do
      parser = Parser.new "---abcd"
      parser.skip('-', limit: 2).peek(2).should eq "-a"
      parser.skip('-', limit: 10).read_char.should eq 'a'
    end

    it "skips characters that pass a predicate" do
      parser = Parser.new "1342,!, ,Lorem ipsum"
      parser.skip { |char| !char.letter? }.read_char.should eq 'L'
    end

    it "skips N characters that pass the predicate at most" do
      parser = Parser.new "Lorem ipsum"
      parser.skip(limit: 4, &.letter?).peek(2).should eq "m "
      parser.skip(limit: 10, &.letter?).read_char.should eq ' '
    end

    it "skips characters that match a pattern" do
      parser = Parser.new "Lorem ipsum!\ndolor sit amet"
      parser.skip(/[\w\s]/).read_char.should eq '!'
    end

    it "does not fail at end of file" do
      parser = Parser.new "Lorem ipsum\n"
      parser.read_line
      parser.skip(&.letter?)
    end
  end

  describe "#skip_in_set" do
    it "skips characters in set" do
      parser = Parser.new "Lorem123"
      parser.skip_in_set "A-Za-z"
      parser.read_char?.should eq '1'
    end
  end

  describe "#skip_line" do
    it "skips line" do
      parser = Parser.new "Lorem ipsum\ndolor sit amet"
      parser.skip_line.read_char.should eq 'd'
    end

    it "does not fail at end of file" do
      parser = Parser.new "Lorem ipsum\n"
      parser.read_line
      parser.skip_line
    end
  end

  describe "#skip_spaces" do
    it "skips spaces and tabs only" do
      parser = Parser.new "  \t\nLorem ipsum"
      parser.skip_spaces.read_char.should eq '\n'
    end
  end

  describe "#skip_whitespace" do
    it "skips whitespace" do
      parser = Parser.new "  \nLorem ipsum"
      parser.skip_whitespace.read_char.should eq 'L'
    end
  end
end
