module Chem::Spatial
  # TODO: add support for non-cubic grids (use lattice instead of bounds?)
  #       - i to coords: origin.x + (i / nx) * lattice.a
  #       - coords to i: ?
  # TODO: implement functionality from vmd's volmap
  class Grid
    alias Dimensions = Tuple(Int32, Int32, Int32)
    alias Index = Tuple(Int32, Int32, Int32)
    record Info, bounds : Bounds, dim : Dimensions

    getter bounds : Bounds
    getter dim : Dimensions

    @buffer : Pointer(Float64)

    delegate includes?, origin, volume, to: @bounds

    def initialize(@dim : Dimensions, @bounds : Bounds)
      check_dim
      @buffer = Pointer(Float64).malloc size
    end

    def initialize(@dim : Dimensions, @bounds : Bounds, initial_value : Float64)
      check_dim
      @buffer = Pointer(Float64).malloc size, initial_value
    end

    def self.[](ni : Int, nj : Int, nk : Int) : self
      new({ni.to_i, nj.to_i, nk.to_i}, Bounds.zero)
    end

    def self.atom_distance(structure : Structure,
                           dim : Dimensions,
                           bounds : Bounds? = nil) : self
      grid = new dim, (bounds || structure.coords.bounds)
      kdtree = KDTree.new structure
      grid.map_with_coords! do |_, vec|
        Math.sqrt kdtree.nearest_with_distance(vec)[1]
      end
    end

    # Returns a grid filled with the distances to the nearest atom. It will have the
    # same bounds and points as *other*.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # info = Grid::Info.new Bounds[1.5, 2.135, 6.12], {10, 10, 10}
    # grid = Grid.atom_distance structure, info.dim, info.bounds
    # Grid.atom_distance_like(info, structure) == grid # => true
    # ```
    def self.atom_distance_like(other : self | Info, structure : Structure) : self
      atom_distance structure, other.dim, other.bounds
    end

    # Creates a new `Grid` with *info* and yields a buffer to be filled.
    #
    # This method is **unsafe**, but it is usually used to initialize the buffer in a
    # linear fashion, e.g., reading values from a file.
    #
    # ```
    # Grid.build(Grid.info("/path/to/file")) do |buffer, size|
    #   size.times do |i|
    #     buffer[i] = read_value
    #   end
    # end
    # ```
    def self.build(info : Info, & : Pointer(Float64), Int32 ->) : self
      grid = empty_like info
      yield grid.to_unsafe, grid.size
      grid
    end

    def self.build(dim : Dimensions,
                   bounds : Bounds,
                   &block : Pointer(Float64), Int32 ->) : self
      grid = new dim, bounds
      yield grid.to_unsafe, grid.size
      grid
    end

    # Returns a zero-filled grid with the same bounds and points as *other*.
    #
    # ```
    # grid = Grid.from_dx "/path/to/grid"
    # other = Grid.empty_like grid
    # other.bounds == grid.bounds # => true
    # other.dim == grid.dim       # => true
    # other.to_a.minmax           # => {0.0, 0.0}
    # ```
    def self.empty_like(other : self | Info) : self
      new other.dim, other.bounds
    end

    # Returns a grid with the same bounds and points as *other* filled with *value*.
    #
    # ```
    # grid = Grid.from_dx "/path/to/grid"
    # other = Grid.fill_like grid, 2345.123
    # other.bounds == grid.bounds # => true
    # other.dim == grid.dim       # => true
    # other.to_a.minmax           # => {2345.123, 2345.123}
    # ```
    def self.fill_like(other : self | Info, value : Number) : self
      new other.dim, other.bounds, value.to_f
    end

    def self.info(path : Path | String) : Info
      info path, IO::FileFormat.from_filename File.basename(path)
    end

    def self.info(input : ::IO | Path | String, format : IO::FileFormat) : Info
      {% begin %}
        case format
        {% for parser in Parser.subclasses.select(&.annotation(IO::FileType)) %}
          when .{{parser.annotation(IO::FileType)[:format].id.underscore.id}}?
            {{parser}}.new(input).info
        {% end %}
        else
          raise ArgumentError.new "#{format} not supported for Grid"
        end
      {% end %}
    end

    def self.new(dim : Dimensions,
                 bounds : Bounds,
                 &block : Int32, Int32, Int32 -> Number)
      new(dim, bounds).map_with_index! do |_, i, j, k|
        (yield i, j, k).to_f
      end
    end

    # TODO: add more tests
    # FIXME: check delta calculation (grid.resolution.min / 2 shouldn't be enough?)
    def self.vdw_mask(structure : Structure,
                      dim : Dimensions,
                      bounds : Bounds? = nil,
                      delta : Float64 = 0.02) : self
      grid = new dim, (bounds || structure.coords.bounds)
      delta = Math.min delta, grid.resolution.min / 2
      kdtree = KDTree.new structure
      vdw_cutoff = structure.each_atom.max_of &.vdw_radius
      # grid.map_with_coords! do |_, vec|
      #   value = 0
      #   kdtree.each_neighbor(vec, within: vdw_cutoff) do |atom, d|
      #     next if value < 0
      #     d = Math.sqrt(d) - atom.vdw_radius
      #     if d < -delta
      #       value = -1
      #     elsif d < delta
      #       value = 1
      #     end
      #   end
      #   value.clamp(0, 1)
      # end
      structure.each_atom do |atom|
        grid.each_index(atom.coords, atom.vdw_radius + delta) do |i, j, k, d|
          too_close = false
          kdtree.each_neighbor(grid.coords_at(i, j, k), within: vdw_cutoff) do |other, od|
            too_close = true if Math.sqrt(od) < other.vdw_radius - delta
          end
          grid[i, j, k] = 1 if !too_close && (d - atom.vdw_radius).abs < delta
        end
      end
      grid
    end

    # Returns a grid mask with the points at the vdW spheres set to 1. It will have the
    # same bounds and points as *other*.
    #
    # ```
    # structure = Structure.read "path/to/file"
    # info = Grid::Info.new Bounds[5.213, 6.823, 10.352], {20, 25, 40}
    # grid = Grid.vdw_mask structure, info.dim, info.bounds
    # Grid.vdw_mask_like(info, structure) == grid # => true
    # ```
    def self.vdw_mask_like(other : self | Info,
                           structure : Structure,
                           delta : Float64 = 0.02) : self
      vdw_mask structure, other.dim, other.bounds, delta
    end

    def ==(rhs : self) : Bool
      return false unless @dim == rhs.dim && @bounds == rhs.bounds
      size.times do |i|
        return false if unsafe_fetch(i) != rhs.unsafe_fetch(i)
      end
      true
    end

    {% for op in %w(+ - * /) %}
      def {{op.id}}(rhs : Number) : self
        Grid.build(@dim, @bounds) do |buffer|
          size.times do |i|
            buffer[i] = unsafe_fetch(i) {{op.id}} rhs
          end
        end
      end

      def {{op.id}}(rhs : self) : self
        raise ArgumentError.new "Incompatible grid" unless @dim == rhs.dim
        Grid.build(@dim, @bounds) do |buffer|
          size.times do |i|
            buffer[i] = unsafe_fetch(i) {{op.id}} rhs.unsafe_fetch(i)
          end
        end
      end
    {% end %}

    @[AlwaysInline]
    def [](i : Int, j : Int, k : Int) : Float64
      self[i, j, k]? || raise IndexError.new
    end

    @[AlwaysInline]
    def [](vec : Vector) : Float64
      self[vec]? || raise IndexError.new
    end

    @[AlwaysInline]
    def []?(i : Int, j : Int, k : Int) : Float64?
      if i_ = internal_index?(i, j, k)
        unsafe_fetch i_
      else
        nil
      end
    end

    # TODO: add interpolation (check ARBInterp)
    @[AlwaysInline]
    def []?(vec : Vector) : Float64?
      if index = index(vec)
        unsafe_fetch index[0], index[1], index[2]
      end
    end

    @[AlwaysInline]
    def []=(i : Int, j : Int, k : Int, value : Float64) : Float64
      raise IndexError.new unless i_ = internal_index?(i, j, k)
      @buffer[i_] = value
    end

    def coords_at(i : Int, j : Int, k : Int) : Vector
      coords_at?(i, j, k) || raise IndexError.new
    end

    def coords_at?(i : Int, j : Int, k : Int) : Vector?
      return unless internal_index?(i, j, k)
      unsafe_coords_at i, j, k
    end

    def dup : self
      Grid.build(@dim, @bounds) do |buffer|
        buffer.copy_from @buffer, size
      end
    end

    def each(& : Float64 ->) : Nil
      size.times do |i_|
        yield unsafe_fetch(i_)
      end
    end

    def each_coords(& : Vector ->) : Nil
      each_index do |i, j, k|
        yield unsafe_coords_at(i, j, k)
      end
    end

    def each_index(& : Int32, Int32, Int32 ->) : Nil
      ni.times do |i|
        nj.times do |j|
          nk.times do |k|
            yield i, j, k
          end
        end
      end
    end

    def each_index(vec : Vector, cutoff : Number, & : Int32, Int32, Int32, Float64 ->) : Nil
      return unless index = index(vec)
      di, dj, dk = resolution.map { |ele| (cutoff / ele).to_i }
      cutoff *= cutoff
      ((index[0] - di - 1)..(index[0] + di + 1)).clamp(0..ni - 1).each do |i|
        ((index[1] - dj - 1)..(index[1] + dj + 1)).clamp(0..nj - 1).each do |j|
          ((index[2] - dk - 1)..(index[2] + dk + 1)).clamp(0..nk - 1).each do |k|
            d = Spatial.squared_distance vec, unsafe_coords_at(i, j, k)
            yield i, j, k, Math.sqrt(d) if d < cutoff
          end
        end
      end
    end

    def each_with_coords(& : Float64, Vector ->) : Nil
      each_index do |i, j, k|
        yield unsafe_fetch(i, j, k), unsafe_coords_at(i, j, k)
      end
    end

    def each_with_index(& : Float64, Int32, Int32, Int32 ->) : Nil
      each_index do |i, j, k|
        yield unsafe_fetch(i, j, k), i, j, k
      end
    end

    def index(vec : Vector) : Index?
      return unless bounds.includes? vec
      vec = (vec - origin).to_fractional bounds.basis
      (vec * @dim.map &.-(1)).round.to_t.map &.to_i
    end

    def index!(vec : Vector) : Index
      index(vec) || raise IndexError.new
    end

    def map(& : Float64 -> Float64) : self
      dup.map! do |ele|
        yield ele
      end
    end

    def map!(& : Float64 -> Float64) : self
      @buffer.map!(size) { |ele| yield ele }
      self
    end

    def map_with_coords(& : Float64, Vector -> Number) : self
      dup.map_with_coords! do |ele, vec|
        yield ele, vec
      end
    end

    def map_with_coords!(& : Float64, Vector -> Number) : self
      size.times do |i_|
        i, j, k = raw_to_index i_
        @buffer[i_] = (yield @buffer[i_], unsafe_coords_at(i, j, k)).to_f
      end
      self
    end

    def map_with_index(& : Float64, Int32, Int32, Int32 -> Number) : self
      dup.map_with_index! do |ele, i, j, k|
        yield ele, i, j, k
      end
    end

    def map_with_index!(& : Float64, Int32, Int32, Int32 -> Number) : self
      size.times do |i_|
        i, j, k = raw_to_index i_
        @buffer[i_] = (yield @buffer[i_], i, j, k).to_f
      end
      self
    end

    # Returns a grid mask. Elements for which the passed block returns `true` are set to
    # 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[10, 10, 10]) { |i, j, k| i + j + k }
    # grid.to_a              # => [0, 1, 1, 2, 1, 2, 2, 3]
    # grid.mask(&.>(1)).to_a # => [0, 0, 0, 1, 0, 1, 1, 1]
    # grid.to_a              # => [0, 1, 1, 2, 1, 2, 2, 3]
    # ```
    def mask(& : Float64 -> Bool) : self
      map { |ele| (yield ele) ? 1.0 : 0.0 }
    end

    # Returns a grid mask. Elements for which `pattern === element` returns `true` are
    # set to 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 3}, Bounds[1, 1, 1]) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
    # grid.to_a              # => [1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12]
    # grid.mask(2..4.5).to_a # => [0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0]
    # grid.to_a              # => [1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12]
    # ```
    def mask(pattern) : self
      mask { |ele| pattern === ele }
    end

    # Returns a grid mask. Elements for which `(value - ele).abs <= delta` returns
    # `true` are set to 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 3}, Bounds[1, 1, 1]) { |i, j, k| (i + 1) * (j + 1) * (k + 1) / 5 }
    # grid.to_a              # => [0.2, 0.4, 0.6, 0.4, 0.8, 1.2, 0.4, 0.8, 1.2, 0.8, 1.6, 2.4]
    # grid.mask(1, 0.5).to_a # => [0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 0]
    # grid.to_a              # => [0.2, 0.4, 0.6, 0.4, 0.8, 1.2, 0.4, 0.8, 1.2, 0.8, 1.6, 2.4]
    # ```
    def mask(value : Number, delta : Number) : self
      mask (value - delta)..(value + delta)
    end

    # Masks a grid by the passed block. Elements for which the passed block returns
    # `false` are set to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid * grid.mask
    # { ... }`.
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[10, 10, 10]) { |i, j, k| i + j + k }
    # grid.to_a # => [0, 1, 1, 2, 1, 2, 2, 3]
    # grid.mask! &.>(1)
    # grid.to_a # => [0, 0, 0, 2, 0, 2, 2, 3]
    # ```
    def mask!(& : Float64 -> Bool) : self
      map! { |ele| (yield ele) ? ele : 0.0 }
    end

    # Masks a grid by *pattern*. Elements for which `pattern === element` returns
    # `false` are set to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid *
    # grid.mask(pattern)`
    #
    # ```
    # grid = Grid.new({2, 2, 3}, Bounds[1, 1, 1]) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
    # grid.to_a # => [1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12]
    # grid.mask! 2..4.5
    # grid.to_a # => [0, 2, 3, 2, 4, 0, 2, 4, 0, 4, 0, 0]
    # ```
    def mask!(pattern) : self
      mask! { |ele| pattern === ele }
    end

    # Masks a grid by *value*+/-*delta*. Elements for which `(value - ele).abs > delta`
    # returns `true` are set to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid * grid.mask(value,
    # delta)`
    #
    # ```
    # grid = Grid.new({2, 2, 3}, Bounds[1, 1, 1]) { |i, j, k| (i + j + k) / 5 }
    # grid.to_a # => [0.0, 0.2, 0.4, 0.2, 0.4, 0.6, 0.2, 0.4, 0.6, 0.4, 0.6, 0.8]
    # grid.mask! 0.5, 0.1
    # grid.to_a # => [0.0, 0.0, 0.4, 0.0, 0.4, 0.6, 0.0, 0.4, 0.6, 0.4, 0.6, 0.0]
    # ```
    def mask!(value : Number, delta : Number) : self
      mask! (value - delta)..(value + delta)
    end

    # Returns a grid mask. Indexes for which the passed block returns `true` are set to
    # 1, otherwise 0.
    #
    # Grid masks are very useful to deal with multiple grids, and when points are to be
    # selected based on one grid only.
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[10, 10, 10]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a                                    # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_index { |i, j, k| k == 1 }.to_a # => [0, 1, 0, 1, 0, 1, 0, 1]
    # grid.to_a                                    # => [0, 1, 2, 3, 4, 5, 6, 7]
    # ```
    def mask_by_index(& : Int32, Int32, Int32 -> Bool) : self
      map_with_index { |_, i, j, k| (yield i, j, k) ? 1.0 : 0.0 }
    end

    # Masks a grid by index. Indexes for which the passed block returns `false` are set
    # to 0.
    #
    # Optimized version of creating a mask and applying it to the same grid, but avoids
    # creating intermediate grids. This is equivalent to `grid = grid *
    # grid.mask_by_index { ... }`
    #
    # ```
    # grid = Grid.new({2, 2, 2}, Bounds[1, 1, 1]) { |i, j, k| i * 4 + j * 2 + k }
    # grid.to_a # => [0, 1, 2, 3, 4, 5, 6, 7]
    # grid.mask_by_index! { |i, j, k| i == 1 }
    # grid.to_a # => [0, 0, 0, 0, 4, 5, 6, 7]
    # ```
    def mask_by_index!(& : Int32, Int32, Int32 -> Bool) : self
      map_with_index! { |ele, i, j, k| (yield i, j, k) ? ele : 0.0 }
    end

    def ni : Int32
      dim[0]
    end

    def nj : Int32
      dim[1]
    end

    def nk : Int32
      dim[2]
    end

    def resolution : Tuple(Float64, Float64, Float64)
      {ni == 1 ? 0.0 : bounds.i.size / (ni - 1),
       nj == 1 ? 0.0 : bounds.j.size / (nj - 1),
       nk == 1 ? 0.0 : bounds.k.size / (nk - 1)}
    end

    def size : Int32
      ni * nj * nk
    end

    def step(n : Int) : self
      step n, n, n
    end

    def step(di : Int, dj : Int, dk : Int) : self
      raise ArgumentError.new "Invalid step size" unless di > 0 && dj > 0 && dk > 0
      new_ni = ni // di
      new_ni += 1 if new_ni % di > 0
      new_nj = nj // dj
      new_nj += 1 if new_nj % dj > 0
      new_nk = nk // dk
      new_nk += 1 if new_nk % dk > 0
      Grid.new({new_ni, new_nj, new_nk}, bounds) do |i, j, k|
        unsafe_fetch i * di, j * dj, k * dk
      end
    end

    def to_a : Array(Float64)
      Array(Float64).build(size) do |buffer|
        buffer.copy_from @buffer, size
        size
      end
    end

    def to_unsafe : Pointer(Float64)
      @buffer
    end

    @[AlwaysInline]
    def unsafe_fetch(i : Int, j : Int, k : Int) : Float64
      to_unsafe[unsafe_index(i, j, k)]
    end

    private def check_dim : Nil
      raise ArgumentError.new "Invalid dimensions" unless dim.all?(&.>(0))
    end

    private def internal_index?(i : Int, j : Int, k : Int) : Int32?
      i += ni if i < 0
      j += nj if j < 0
      k += nk if k < 0
      if 0 <= i < ni && 0 <= j < nj && 0 <= k < nk
        unsafe_index i, j, k
      else
        nil
      end
    end

    @[AlwaysInline]
    private def raw_to_index(i_ : Int) : Index
      i = i_ // (nj * nk)
      j = (i_ // nk) % nj
      k = i_ % nk
      {i, j, k}
    end

    @[AlwaysInline]
    private def unsafe_coords_at(i : Int, j : Int, k : Int) : Vector
      vi = ni == 1 ? Vector.zero : bounds.i / (ni - 1)
      vj = nj == 1 ? Vector.zero : bounds.j / (nj - 1)
      vk = nk == 1 ? Vector.zero : bounds.k / (nk - 1)
      origin + i * vi + j * vj + k * vk
    end

    @[AlwaysInline]
    protected def unsafe_fetch(i : Int) : Float64
      @buffer[i]
    end

    @[AlwaysInline]
    private def unsafe_index(i : Int, j : Int, k : Int) : Int
      i * nj * nk + j * nk + k
    end
  end
end
