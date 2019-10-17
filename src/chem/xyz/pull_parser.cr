module Chem::XYZ
  @[IO::FileType(format: XYZ, ext: [:xyz])]
  class PullParser < IO::Parser
    include IO::PullParser

    def each_structure(&block : Structure ->)
      until eof?
        yield parse
        skip_whitespace
      end
    end

    def parse : Structure
      Structure.build do |builder|
        skip_whitespace
        n_atoms = read_int
        skip_line
        builder.title read_line.strip
        n_atoms.times { builder.atom self }
      end
    end

    def skip_structure
      skip_whitespace
      n_atoms = read_int
      (n_atoms + 2).times { skip_line }
    end
  end
end
