require "../spec_helper"

describe Chem::Spatial::Grid do
  describe ".[]" do
    it "creates an empty grid" do
      grid = Grid[10, 20, 30]
      grid.dim.should eq({10, 20, 30})
      grid.bounds.should eq Bounds.zero
      grid.to_a.should eq Array(Float64).new(10*20*30, 0.0)
    end
  end

  describe ".atom_distance" do
    it "returns a grid having distances to nearest atom" do
      st = Chem::Structure.build do
        atom :C, V[1, 0, 0]
        atom :C, V[0, 0, 1]
      end

      Grid.atom_distance(st, {3, 3, 3}, Bounds[2, 2, 2]).to_a.should be_close [
        1.0, 0.0, 1.0,
        1.414, 1.0, 1.414,
        2.236, 2.0, 2.236,

        0.0, 1.0, 1.414,
        1.0, 1.414, 1.732,
        2.0, 2.236, 2.449,

        1.0, 1.414, 2.236,
        1.414, 1.732, 2.449,
        2.236, 2.449, 3.0,
      ], 1e-3
    end

    it "returns a grid having distances to nearest atom" do
      st = Chem::Structure.build(guess_topology: false) do
        lattice 2, 2, 2
        atom :C, V[1, 1, 1]
        atom :C, V[1.5, 0.5, 0.5]
      end

      Grid.atom_distance(st, {4, 4, 4}, Bounds[2, 2, 2]).to_a.should be_close [
        0.866, 0.726, 1.093, 0.866, 0.726, 0.553, 0.986, 0.726, 1.093, 0.986, 1.106,
        1.093, 0.866, 0.726, 1.093, 0.866, 1.093, 0.986, 1.106, 1.093, 0.986, 0.577,
        0.577, 0.986, 1.106, 0.577, 0.577, 1.106, 1.093, 0.986, 1.106, 1.093, 0.726,
        0.553, 0.986, 0.726, 0.553, 0.289, 0.577, 0.553, 0.986, 0.577, 0.577, 0.986,
        0.726, 0.553, 0.986, 0.726, 0.866, 0.726, 1.093, 0.866, 0.726, 0.553, 0.986,
        0.726, 1.093, 0.986, 1.106, 1.093, 0.866, 0.726, 1.093, 0.866,
      ], 1e-3
    end
  end

  describe ".atom_distance_like" do
    it "returns a grid with the same bounds and shape of another grid" do
      structure = Chem::Structure.build do
        atom :C, V[1, 0, 0]
        atom :C, V[0, 0, 1]
      end

      info = Grid::Info.new Bounds[1.5, 2.135, 6.12], {10, 10, 10}
      grid = Grid.atom_distance structure, info.dim, info.bounds
      Grid.atom_distance_like(info, structure).should eq grid
    end
  end

  describe ".build" do
    it "builds a grid" do
      grid = Grid.build({2, 3, 2}, Bounds.zero) do |buffer|
        12.times do |i|
          buffer[i] = i.to_f ** 2
        end
      end
      grid.to_a.should eq Array(Float64).new(12) { |i| i.to_f ** 2 }
    end
  end

  describe ".empty_like" do
    it "returns a zero-filled grid with the same bounds and shape of another grid" do
      grid = Grid.empty_like make_grid(3, 5, 10, Bounds[1.5, 3, 1.3])
      grid.bounds.should eq Bounds[1.5, 3, 1.3]
      grid.dim.should eq({3, 5, 10})
      grid.to_a.minmax.should eq({0, 0})
    end

    it "returns a zero-filled grid with the same bounds and shape of another grid info" do
      grid = Grid.empty_like Grid::Info.new(Bounds[2, 2, 4], {20, 20, 20})
      grid.bounds.should eq Bounds[2, 2, 4]
      grid.dim.should eq({20, 20, 20})
      grid.to_a.minmax.should eq({0, 0})
    end
  end

  describe ".fill_like" do
    it "returns a filled grid with the same bounds and shape of another grid" do
      grid = Grid.fill_like make_grid(3, 5, 10, Bounds[1.5, 3, 1.3]), 5.0
      grid.bounds.should eq Bounds[1.5, 3, 1.3]
      grid.dim.should eq({3, 5, 10})
      grid.to_a.minmax.should eq({5, 5})
    end

    it "returns a filled grid with the same bounds and shape of another grid info" do
      grid = Grid.fill_like Grid::Info.new(Bounds[2, 2, 4], {20, 20, 20}), 23.4
      grid.bounds.should eq Bounds[2, 2, 4]
      grid.dim.should eq({20, 20, 20})
      grid.to_a.minmax.should eq({23.4, 23.4})
    end
  end

  describe ".new" do
    it "initializes a grid" do
      grid = Grid.new({2, 3, 2}, Bounds[1, 1, 1])
      grid.dim.should eq({2, 3, 2})
      grid.ni.should eq 2
      grid.nj.should eq 3
      grid.nk.should eq 2
      grid.resolution.should eq({1, 0.5, 1})
      grid.to_a.should eq Array(Float64).new(12, 0.0)
    end

    it "initializes a grid with an initial value" do
      grid = Grid.new({2, 3, 2}, Bounds.zero, initial_value: 3.14)
      grid.to_a.should eq Array(Float64).new 12, 3.14
    end

    it "initializes a grid with a block" do
      grid = Grid.new({2, 3, 2}, Bounds.zero) { |i, j, k| i * 100 + j * 10 + k }
      grid.to_a.should eq [0, 1, 10, 11, 20, 21, 100, 101, 110, 111, 120, 121]
    end
  end

  describe ".vdw_mask" do
    it "returns a vdW mask" do
      st = Chem::Structure.build do
        atom :C, V[1, 0, 0]
        atom :C, V[0, 0, 1]
      end

      actual = [] of V
      Grid.vdw_mask(st, {6, 6, 6}, Bounds[2, 2, 2], 0.02).each_with_coords do |ele, vec|
        actual << vec if ele == 1
      end
      actual.should be_close [
        V[0.4, 1.6, 0.4],
        V[0.4, 1.6, 1.6],
        V[0.8, 1.2, 2.0],
        V[1.2, 0.8, 2.0],
        V[1.6, 0.4, 1.6],
        V[1.6, 1.6, 0.4],
        V[2.0, 0.8, 1.2],
        V[2.0, 1.2, 0.8],
      ], 1e-3
    end
  end

  describe ".vdw_mask_like" do
    it "returns a grid with the same bounds and shape of another grid" do
      structure = Chem::Structure.build do
        atom :C, V[1, 0, 0]
        atom :C, V[0, 0, 1]
      end

      info = Grid::Info.new Bounds[1.5, 2.135, 6.12], {10, 10, 10}
      grid = Grid.vdw_mask structure, info.dim, info.bounds
      Grid.vdw_mask_like(info, structure).should eq grid
    end
  end

  describe "#==" do
    it "returns true when grids are equal" do
      grid = make_grid(3, 5, 4, Bounds.new(V[0, 1, 3], V[30, 20, 25]))
      other = make_grid(3, 5, 4, Bounds.new(V[0, 1, 3], V[30, 20, 25]))
      grid.should eq other
    end

    it "returns false when grids have different number of points" do
      Grid[5, 7, 10].should_not eq Grid[5, 7, 9]
    end

    it "returns false when grids have different bounds" do
      grid = make_grid(5, 5, 5, Bounds.new(V[0, 1, 3], V[30, 20, 25]))
      other = make_grid(5, 5, 5, Bounds.zero)
      grid.should_not eq other
    end

    it "returns false when grids have different elements" do
      make_grid(5, 5, 5).should_not eq make_grid(5, 5, 5) { |i| i + 1 }
    end
  end

  describe "#+" do
    it "sums a grid with a number" do
      (make_grid(2, 2, 2) + 10).to_a.should eq [10, 11, 12, 13, 14, 15, 16, 17]
    end

    it "sums two grids" do
      (make_grid(2, 2, 2) + make_grid(2, 2, 2)).to_a.should eq [0, 2, 4, 6, 8, 10, 12, 14]
    end

    it "fails when grids have different shape" do
      expect_raises ArgumentError do
        Grid[2, 2, 2] + Grid[3, 2, 2]
      end
    end
  end

  describe "#[]" do
    it "fails when indexes are out of bounds" do
      expect_raises(IndexError) { make_grid(2, 3, 2)[2, 24, 0] }
    end

    it "fails when coordinates are out of bounds" do
      grid = make_grid 10, 10, 10, Bounds[2, 3, 4]
      expect_raises(IndexError) { grid[V[2, 5, -0.5]] }
    end
  end

  describe "#[]?" do
    it "returns the value at the indexes" do
      grid = make_grid 2, 3, 2
      grid[0, 0, 0]?.should eq 0
      grid[0, 1, 1]?.should eq 3
      grid[1, 2, 0]?.should eq 10
      grid[1, 2, 1]?.should eq 11
      grid[0, -3, -2]?.should eq 0
      grid[-1, -1, -1]?.should eq 11
    end

    it "returns the value at the coordinates" do
      grid = make_grid 6, 11, 9, Bounds.new(V[2, 3, 4], S[1, 1, 1])
      grid[V[2, 3, 4]]?.should eq 0
      grid[V[2.2, 3.6, 4.25]]?.should eq 155
      grid[V[3, 4, 5]]?.should eq 593
    end

    it "returns the value close to the coordinates" do
      grid = make_grid 6, 10, 8, Bounds.new(V[2, 3, 4], S[1, 1, 1])
      grid[V[2.51, 3.505, 4.51]]?.should eq 284 # no interpolation
      grid[V[2.65, 3.24, 4.97]]?.should eq 263  # no interpolation
    end

    it "returns nil when indexes are out of bounds" do
      grid = make_grid 2, 3, 2
      grid[3, 5, 10]?.should be_nil
      grid[-10, 1, 1]?.should be_nil
    end

    it "returns nil when coordinates are out of bounds" do
      grid = make_grid 10, 10, 10, Bounds[2, 3, 4]
      grid[V[2, 5, -0.5]]?.should be_nil
    end
  end

  describe "#[]=" do
    it "sets a value at the indexes" do
      grid = make_grid 10, 10, 10
      grid[4, 7, 1] = 1234
      grid[4, 7, 1].should eq 1234
    end
  end

  describe "#coords_at" do
    it "fails when indexes are out of bounds" do
      grid = make_grid 10, 10, 10, Bounds.new(V[1, 2, 3], S[10, 20, 30])
      expect_raises(IndexError) { grid.coords_at 20, 35, 1 }
    end
  end

  describe "#coords_at?" do
    it "returns the coordinates at indexes" do
      grid = make_grid 11, 11, 11, Bounds.new(V[1, 2, 3], S[10, 20, 30])
      grid.coords_at?(0, 0, 0).should eq V[1, 2, 3]
      grid.coords_at?(10, 10, 10).should eq V[11, 22, 33]
      grid.coords_at?(3, 5, 0).should eq V[4, 12, 3]
    end

    it "returns the coordinates at indexes (non-orthogonal)" do
      grid = make_grid 11, 11, 11, Bounds.new(V[1, 2, 3], S[10, 10, 5], 90, 90, 120)
      grid.coords_at?(0, 0, 0).should eq V[1, 2, 3]
      grid.coords_at?(10, 10, 10).not_nil!.should be_close V[6, 10.660, 8], 1e-3
      grid.coords_at?(3, 5, 0).not_nil!.should be_close V[1.5, 6.330, 3], 1e-3
    end

    it "returns nil when indexes are out of bounds" do
      grid = make_grid 10, 10, 10, Bounds.new(V[1, 2, 3], S[10, 20, 30])
      grid.coords_at?(20, 35, 1).should be_nil
    end
  end

  describe "#dup" do
    it "returns a copy" do
      grid = make_grid(3, 5, 4, Bounds.new(V[0, 1, 3], V[30, 20, 25]))
      other = grid.dup
      other.should_not be grid
      other.should eq grid
    end
  end

  describe "#each" do
    it "yields each element" do
      ary = [] of Float64
      make_grid(2, 3, 1) { |i, j, k| i * 100 + j * 10 + k }.each { |ele| ary << ele }
      ary.should eq [0, 10, 20, 100, 110, 120]
    end
  end

  describe "#each_coords" do
    it "yields each coordinates" do
      ary = [] of Vector
      Grid.new({2, 2, 2}, Bounds.new(V[1, 2, 3], S[3, 3, 3])).each_coords do |vec|
        ary << vec
      end

      ary.should eq [
        V[1, 2, 3], V[1, 2, 6], V[1, 5, 3], V[1, 5, 6], V[4, 2, 3], V[4, 2, 6],
        V[4, 5, 3], V[4, 5, 6],
      ]
    end
  end

  describe "#each_index" do
    it "yields each index" do
      ary = [] of Grid::Index
      Grid[2, 2, 2].each_index { |i, j, k| ary << {i, j, k} }
      ary.should eq [
        {0, 0, 0}, {0, 0, 1}, {0, 1, 0}, {0, 1, 1}, {1, 0, 0}, {1, 0, 1}, {1, 1, 0},
        {1, 1, 1},
      ]
    end

    it "yields each index within a cutoff distance of a given position" do
      grid = Grid.new({5, 10, 20}, Bounds.new(V[1, 2, 3], S[2, 2, 2]))
      vec, cutoff = V[2, 3, 5], 0.5

      expected = [] of Grid::Index
      grid.each_index do |i, j, k|
        d = Chem::Spatial.squared_distance grid.coords_at(i, j, k), vec
        expected << {i, j, k} if d < cutoff**2
      end

      ary = [] of Grid::Index
      grid.each_index(vec, cutoff) { |i, j, k| ary << {i, j, k} }
      ary.sort!.should eq expected.sort!
    end
  end

  describe "#each_with_coords" do
    it "yields each element with its coordinates" do
      hash = {} of Vector => Float64
      grid = make_grid(3, 2, 1, Bounds.new(V[1, 2, 3], S[2, 1, 1])) do |i, j, k|
        i * 100 + j * 10 + k
      end
      grid.each_with_coords { |ele, vec| hash[vec] = ele }
      hash.should eq({
        V[1, 2, 3] => 0,
        V[1, 3, 3] => 10,
        V[2, 2, 3] => 100,
        V[2, 3, 3] => 110,
        V[3, 2, 3] => 200,
        V[3, 3, 3] => 210,
      })
    end
  end

  describe "#each_with_index" do
    it "yields each element with its index" do
      hash = {} of Grid::Index => Float64
      grid = make_grid(2, 3, 1) { |i, j, k| i * 100 + j * 10 + k }
      grid.each_with_index { |ele, i, j, k| hash[{i, j, k}] = ele }
      hash.should eq({
        {0, 0, 0} => 0,
        {0, 1, 0} => 10,
        {0, 2, 0} => 20,
        {1, 0, 0} => 100,
        {1, 1, 0} => 110,
        {1, 2, 0} => 120,
      })
    end
  end

  describe "#index" do
    it "returns the index at the coordinates" do
      grid = make_grid 6, 10, 8, Bounds.new(V[2, 3, 4], S[1, 1, 1])
      grid.index(V[2, 3, 4]).should eq({0, 0, 0})
      grid.index(V[3, 4, 5]).should eq({5, 9, 7})
      grid.index(V[2.45, 3.4, 4.4]).should eq({2, 4, 3})
      grid.index(V[2.16, 3.75, 4.87]).should eq({1, 7, 6})
    end

    it "returns the index at the coordinates (non-orthogonal)" do
      grid = make_grid 11, 11, 11, Bounds.new(V[4, 3, 2], S[5, 5, 4], 90, 100, 90)
      grid.index(V[4, 3, 2]).should eq({0, 0, 0})
      grid.index(V[8.305, 8, 5.939]).should eq({10, 10, 10})
      grid.index(V[4.5, 6.21, 2.63]).should eq({1, 6, 2})
      grid.index(V[7.4, 4.91, 5.4]).should eq({8, 4, 9})
    end

    it "returns nil when coordinates are out of bounds" do
      make_grid(8, 8, 8, Bounds[7, 1, 2]).index(V[7.1, 0.5, 1.2]).should be_nil
    end
  end

  describe "#index!" do
    it "fails when coordinates are out of bounds" do
      grid = make_grid(8, 8, 8, Bounds[7, 1, 2])
      expect_raises(IndexError) { grid.index! V[7.1, 0.5, 1.2] }
    end
  end

  describe "#map" do
    it "returns a grid yielding each element" do
      grid = make_grid(2, 3, 1)
      other = grid.map &.**(2)
      grid.to_a.should eq [0, 1, 2, 3, 4, 5]
      other.to_a.should eq [0, 1, 4, 9, 16, 25]
      other.bounds.should eq Bounds.zero
    end
  end

  describe "#map!" do
    it "modifies a grid yielding each element" do
      grid = make_grid(2, 3, 1)
      grid.map! &.**(2)
      grid.to_a.should eq [0, 1, 4, 9, 16, 25]
    end
  end

  describe "#map_with_coords" do
    it "modifies the grid yielding each element and its coordinates" do
      grid = make_grid 3, 2, 1, Bounds.new(V[1, 2, 3], S[2, 1, 1])
      other = grid.map_with_coords { |ele, vec| ele + vec.x * 100 + vec.y * 10 + vec.z }
      grid.to_a.should eq [0, 1, 2, 3, 4, 5]
      other.to_a.should eq [123, 134, 225, 236, 327, 338]
      other.bounds.should eq Bounds.new(V[1, 2, 3], S[2, 1, 1])
    end
  end

  describe "#map_with_coords!" do
    it "modifies the grid yielding each element and its coordinates" do
      grid = make_grid 3, 2, 1, Bounds.new(V[1, 2, 3], S[2, 1, 1])
      grid.map_with_coords! { |ele, vec| ele + vec.x * 100 + vec.y * 10 + vec.z }
      grid.to_a.should eq [123, 134, 225, 236, 327, 338]
    end
  end

  describe "#map_with_index" do
    it "modifies the grid yielding each element and its index" do
      grid = make_grid 2, 3, 1
      other = grid.map_with_index { |ele, i, j, k| i * 1000 + j * 100 + k * 10 + ele }
      grid.to_a.should eq [0, 1, 2, 3, 4, 5]
      other.to_a.should eq [0, 101, 202, 1003, 1104, 1205]
      other.bounds.should eq Bounds.zero
    end
  end

  describe "#map_with_index!" do
    it "modifies the grid yielding each element and its index" do
      grid = make_grid 2, 3, 1
      grid.map_with_index! { |ele, i, j, k| i * 1000 + j * 100 + k * 10 + ele }
      grid.to_a.should eq [0, 101, 202, 1003, 1104, 1205]
    end
  end

  describe "#mask" do
    it "returns a masked grid by a number" do
      grid = make_grid(2, 2, 2) { |i, j, k| i + j + k }
      grid.mask(2).to_a.should eq [0, 0, 0, 1, 0, 1, 1, 0]
      grid.to_a.should eq [0, 1, 1, 2, 1, 2, 2, 3]
    end

    it "returns a masked grid by a range" do
      grid = make_grid(2, 2, 3) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
      grid.mask(2..4.5).to_a.should eq [0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0]
      grid.to_a.should eq [1, 2, 3, 2, 4, 6, 2, 4, 6, 4, 8, 12]
    end

    it "returns a masked grid with a block" do
      grid = make_grid(2, 2, 3) { |i, j, k| (i + 1) / (j + 1) * (k + 1) }
      grid.mask(&.<(2)).to_a.should eq [1, 0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0]
      grid.to_a.should eq [1, 2, 3, 0.5, 1, 1.5, 2, 4, 6, 1, 2, 3]
    end
  end

  describe "#mask!" do
    it "masks a grid in-place by a number" do
      grid = make_grid(2, 3, 2) { |i, j, k| i + j + k }
      grid.mask! 3
      grid.to_a.should eq [0, 0, 0, 0, 0, 3, 0, 0, 0, 3, 3, 0]
    end

    it "masks a grid in-place by a range" do
      grid = make_grid(2, 3, 2) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
      grid.mask! 3..10
      grid.to_a.should eq [0, 0, 0, 4, 3, 6, 0, 4, 4, 8, 6, 0]
    end

    it "masks a grid in-place with a block" do
      grid = make_grid(2, 3, 2) { |i, j, k| (i + 1) * (j + 1) * (k + 1) }
      grid.mask! &.>(4.1)
      grid.to_a.should eq [0, 0, 0, 0, 0, 6, 0, 0, 0, 8, 6, 12]
    end
  end

  describe "#ni" do
    it "returns the number of points along the first axis" do
      make_grid(2, 6, 1).ni.should eq 2
    end
  end

  describe "#nj" do
    it "returns the number of points along the second axis" do
      make_grid(2, 6, 1).nj.should eq 6
    end
  end

  describe "#nk" do
    it "returns the number of points along the third axis" do
      make_grid(2, 6, 1).nk.should eq 1
    end
  end

  describe "#resolution" do
    it "returns the spacing for each axis" do
      make_grid(10, 10, 10, Bounds[1, 2, 3]).resolution.should eq({1/9, 2/9, 3/9})
    end
  end

  describe "#size" do
    it "returns the number of points" do
      make_grid(2, 5, 10).size.should eq 100
    end
  end

  describe "#step" do
    it "returns a smaller grid" do
      grid = make_grid(4, 4, 4, Bounds[1, 1, 1]).step 2, 3, 2
      grid.dim.should eq({2, 2, 2})
      grid.resolution.should eq({1, 1, 1})
      grid.to_a.should eq [0, 2, 12, 14, 32, 34, 44, 46]
    end
  end

  describe "#to_a" do
    it "returns an array containing all elements" do
      make_grid(2, 2, 2).to_a.should eq (0..7).to_a
    end
  end
end
