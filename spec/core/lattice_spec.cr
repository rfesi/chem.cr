require "../spec_helper"

alias Lattice = Chem::Lattice

describe Chem::Lattice do
  describe ".new" do
    it "succeeds with vectors" do
      lattice = Lattice.new Vector[8.77, 0, 0],
        Vector[3.19616011, 8.94620370, 0],
        Vector[4.29605592, -0.71878676, 24.35353874],
        Vector[1, 2, 3]
      lattice.size.should be_close S[8.77, 9.5, 24.740], 1e-8
      lattice.alpha.should be_close 88.22, 1e-8
      lattice.beta.should be_close 80.00, 1e-7
      lattice.gamma.should be_close 70.34, 1e-7
      lattice.origin.should eq V[1, 2, 3]
    end

    it "succeeds with size and angles" do
      lattice = Lattice.new 74.23, 135.35, 148.46, 90, 90, 90
      lattice.a.should be_close Vector[74.23, 0, 0], 1e-8
      lattice.b.should be_close Vector[0, 135.35, 0], 1e-8
      lattice.c.should be_close Vector[0, 0, 148.46], 1e-8
      lattice.alpha.should eq 90
      lattice.beta.should eq 90
      lattice.gamma.should eq 90
      lattice.origin.should eq V.origin
    end

    it "succeeds with sizes (orthorhombic box)" do
      lattice = Lattice.new 74.23, 135.35, 148.46, origin: V[1, 2, 3]
      lattice.a.should be_close Vector[74.23, 0, 0], 1e-8
      lattice.b.should be_close Vector[0, 135.35, 0], 1e-8
      lattice.c.should be_close Vector[0, 0, 148.46], 1e-8
      lattice.alpha.should eq 90
      lattice.beta.should eq 90
      lattice.gamma.should eq 90
      lattice.origin.should eq V[1, 2, 3]
    end
  end

  describe ".[]" do
    it "works" do
      expected = Lattice.new Vector[74.23, 0, 0],
        Vector[0, 135.35, 0],
        Vector[0, 0, 148.46]
      Lattice[74.23, 135.35, 148.46] == expected
    end
  end

  describe "#change_coords" do
    it "converts Cartesian to fractional coordinates" do
      lattice = Chem::Lattice.new 10, 20, 30
      lattice.change_coords(V.zero).should eq V.zero
      lattice.change_coords(V[1, 2, 3]).should be_close V[0.1, 0.1, 0.1], 1e-15
      lattice.change_coords(V[2, 3, 15]).should be_close V[0.2, 0.15, 0.5], 1e-15

      lattice.a = 20
      lattice.change_coords(V[1, 2, 3]).should be_close V[0.05, 0.1, 0.1], 1e-15
    end

    it "converts Cartesian to fractional coordinates (non-origin)" do
      lattice = Chem::Lattice.new 10, 20, 30, origin: V[1, 2, 3]
      lattice.change_coords(V[1, 2, 3]).should eq V.zero
      lattice.change_coords(V[6, 12, 18]).should be_close V[0.5, 0.5, 0.5], 1e-15
    end
  end

  describe "#includes?" do
    it "tells if a vector is within the primary unit cell" do
      Lattice[10, 20, 30].includes?(V[1, 2, 3]).should be_true
      Lattice.new(6, 3, 23, origin: V[1, 2, 3]).includes?(V[3, 2.1, 20]).should be_true
      Lattice[10, 20, 30].includes?(V[-1, 2, 3]).should be_false
      Lattice.new(6, 3, 23, origin: V[1, 2, 3]).includes?(V[2.4, 1.8, 23.1]).should be_false
    end

    it "tells if a vector is within the primary unit cell (non-orthogonal)" do
      lattice = Lattice.new 23.803, 23.828, 5.387, 90, 90, 120
      lattice.includes?(V[10, 20, 2]).should be_true
      lattice.includes?(V[0, 0, 0]).should be_true
      lattice.includes?(V[30, 30, 10]).should be_false
      lattice.includes?(V[-3, 10, 2]).should be_true
      lattice.includes?(V[-3, 2, 2]).should be_false
    end
  end

  describe "#revert_coords" do
    it "converts fractional to Cartesian coordinates" do
      lattice = Chem::Lattice.new 20, 20, 16
      lattice.revert_coords(V[0.5, 0.65, 1]).should be_close V[10, 13, 16], 1e-15
      lattice.revert_coords(V[1.5, 0.23, 0.9]).should be_close V[30, 4.6, 14.4], 1e-15

      lattice.b /= 2
      lattice.revert_coords(V[0.5, 0.65, 1]).should be_close V[10, 6.5, 16], 1e-15

      lattice = Chem::Lattice.new(
        V[8.497, 0.007, 0.031],
        V[10.148, 42.359, 0.503],
        V[7.296, 2.286, 53.093])
      lattice.revert_coords(V[0.724, 0.04, 0.209]).should be_close V[8.083, 2.177, 11.139], 1e-3
    end

    it "converts fractional to Cartesian coordinates (non-origin)" do
      lattice = Chem::Lattice.new 20, 20, 16, origin: V[5, 1, 13]
      lattice.revert_coords(V[0.5, 0.65, 1]).should be_close V[15, 14, 29], 1e-15
      lattice.revert_coords(V[1.5, 0.23, 0.9]).should be_close V[35, 5.6, 27.4], 1e-15
    end
  end

  describe "#volume" do
    it "returns lattice's volume" do
      Lattice[10, 20, 30].volume.should eq 6_000
      Lattice.new(5, 5, 8, 90, 90, 120).volume.should be_close 173.2050807569, 1e-10
      Lattice.new(1, 2, 3, beta: 101.2).volume.should be_close 5.8857309321, 1e-10
    end
  end
end
