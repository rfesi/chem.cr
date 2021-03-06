module Chem::VASP
  module GridParser
    def info : Spatial::Grid::Info
      skip_line
      scale = read_float
      i, j, k = scale * read_vector, scale * read_vector, scale * read_vector
      skip_atoms
      nx, ny, nz = read_int, read_int, read_int

      bounds = Spatial::Bounds.new Spatial::Vector.origin, i, j, k
      Spatial::Grid::Info.new bounds, {nx, ny, nz}
    end

    private def read_array(info : Spatial::Grid::Info,
                           & : Float64 -> Float64) : Spatial::Grid
      nx, ny, nz = info.dim
      nyz = ny * nz
      Spatial::Grid.build(info) do |buffer|
        nz.times do |k|
          ny.times do |j|
            nx.times do |i|
              buffer[i * nyz + j * nz + k] = yield read_float
            end
          end
        end
      end
    end

    private def skip_atoms : Nil
      n_atoms = 0
      n_elements = 0
      loop do
        if (str = read_word)[0].number?
          n_atoms += str.to_i
          n_elements -= 1
          break if n_elements == 0
        else
          n_elements += 1
        end
      end
      skip_line
      skip_line if (char = peek) && char.in_set?("sS")
      skip_line
      n_atoms.times { skip_line }
    end
  end

  module GridWriter
    @write_header = true

    def initialize(input : ::IO | Path | String,
                   @structure : Structure,
                   *,
                   sync_close : Bool = false)
      super input, sync_close: sync_close
    end

    # Writes a formatted number to the IO following Fortran's scientific
    # notation convention.
    #
    # Numbers always start with a leading zero (e.g., "0.123E+00" vs
    # "1.230E-01"), which is replaced by a minus sign for negative
    # numbers (e.g., "-.123" vs "-0.123"). This ensures that the minus
    # sign doesn't change number width, e.g., "0.123" and "-.123".
    private def format_array_element(value : Float64) : Nil
      if value == 0
        @io.printf "%18.11E", value
      else
        s = sprintf "%.10E", value
        if value > 0
          exp = s[13..].to_i + 1
          @io << " 0." << s[0] << s[2..11]
        else
          exp = s[14..].to_i + 1
          @io << " -." << s[1] << s[3..12]
        end
        @io << 'E'
        @io << (exp < 0 ? '-' : '+')
        @io.printf "%02d", exp.abs
      end
    end

    private def incompatible_expcetion : Nil
      raise ArgumentError.new("Incompatible structure and grid")
    end

    private def write_array(grid : Spatial::Grid, & : Float64 -> Float64) : Nil
      @io.puts
      nx, ny, nz = grid.dim
      formatl "%5d%5d%5d", nx, ny, nz
      grid.size.times do |i_|
        i = i_ % nx
        j = (i_ // nx) % ny
        k = i_ // (ny * nx)
        format_array_element(yield grid.unsafe_fetch({i, j, k}))
        @io << '\n' if (i_ + 1) % 5 == 0
      end
      @io << '\n' unless grid.size % 5 == 0
    end

    private def write_header : Nil
      return unless @write_header
      @structure.to_poscar(@io)
      @write_header = false
    end
  end
end
