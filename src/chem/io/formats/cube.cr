module Chem::Cube
  @[IO::FileType(format: Cube, ext: %w(cube))]
  class Parser < Spatial::Grid::Parser
    include IO::AsciiParser

    BOHR_TO_ANGS = 0.529177210859

    def info : Spatial::Grid::Info
      skip_lines 2
      n_atoms = read_int
      raise ::IO::Error.new "Cube with multiple densities not supported" if n_atoms < 0

      origin = read_vector * BOHR_TO_ANGS
      nx, i = read_int, read_vector * BOHR_TO_ANGS
      ny, j = read_int, read_vector * BOHR_TO_ANGS
      nz, k = read_int, read_vector * BOHR_TO_ANGS
      skip_lines n_atoms + 1
      bounds = Spatial::Bounds.new origin, i * nx, j * ny, k * nz
      Spatial::Grid::Info.new bounds, {nx, ny, nz}
    end

    def parse : Spatial::Grid
      grid_info = info
      Spatial::Grid.build(grid_info.dim, grid_info.bounds) do |buffer|
        (grid_info.dim[0] * grid_info.dim[1] * grid_info.dim[2]).times do |i|
          buffer[i] = read_float
        end
      end
    end
  end

  @[IO::FileType(format: Cube, ext: %w(cube))]
  class Writer < IO::Writer(Spatial::Grid)
    ANGS_TO_BOHR = 1.88972612478289694072

    def initialize(input : ::IO | Path | String,
                   @atoms : AtomCollection,
                   sync_close : Bool = false)
      super input
    end

    def write(grid : Spatial::Grid) : Nil
      check_open
      write_header grid
      write_atoms
      write_array grid
    end

    private def write_array(grid : Spatial::Grid) : Nil
      i = 0
      grid.each do |ele|
        i += 1
        format "%13.5E", ele
        @io << '\n' if i % 6 == 0
      end
      @io << '\n' unless i % 6 == 0
    end

    private def write_atoms : Nil
      @atoms.each_atom do |atom|
        formatl "%5d%12.6f%12.6f%12.6f%12.6f",
          atom.atomic_number,
          atom.partial_charge,
          atom.x * ANGS_TO_BOHR,
          atom.y * ANGS_TO_BOHR,
          atom.z * ANGS_TO_BOHR
      end
    end

    private def write_header(grid : Spatial::Grid) : Nil
      origin = grid.origin * ANGS_TO_BOHR
      i = grid.bounds.i / grid.nx * ANGS_TO_BOHR
      j = grid.bounds.j / grid.ny * ANGS_TO_BOHR
      k = grid.bounds.k / grid.nz * ANGS_TO_BOHR

      @io.puts "CUBE FILE GENERATED WITH CHEM.CR"
      @io.puts "OUTER LOOP: X, MIDDLE LOOP: Y, INNER LOOP: Z"
      formatl "%5d%12.6f%12.6f%12.6f", @atoms.n_atoms, origin.x, origin.y, origin.z
      formatl "%5d%12.6f%12.6f%12.6f", grid.dim[0], i.x, i.y, i.z
      formatl "%5d%12.6f%12.6f%12.6f", grid.dim[1], j.x, j.y, j.z
      formatl "%5d%12.6f%12.6f%12.6f", grid.dim[2], k.x, k.y, k.z
    end
  end
end