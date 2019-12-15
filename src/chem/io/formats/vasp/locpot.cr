module Chem::VASP::Locpot
  @[IO::FileType(format: Locpot, ext: [:locpot])]
  class Parser < IO::Parser(Spatial::Grid)
    include IO::AsciiParser
    include GridParser

    def parse : Spatial::Grid
      nx, ny, nz, bounds = read_header
      read_array nx, ny, nz, bounds, &.itself
    end
  end

  @[IO::FileType(format: Locpot, ext: [:locpot])]
  class Writer < IO::Writer(Spatial::Grid)
    include GridWriter

    def write(grid : Spatial::Grid) : Nil
      write_header
      write_array(grid, &.itself)
    end
  end
end
