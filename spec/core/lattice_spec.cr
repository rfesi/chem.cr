require "../spec_helper"

describe Chem::Lattice do
  describe "#a=" do
    it "sets the size of the first basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.a = 20
      lattice.basis.should eq Basis.new(S[20, 20, 30])
    end
  end

  describe "#b=" do
    it "sets the size of the second basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.b = 5
      lattice.basis.should eq Basis.new(S[10, 5, 30])
    end
  end

  describe "#c=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.c = 4
      lattice.basis.should eq Basis.new(S[10, 20, 4])
    end
  end

  describe "#i=" do
    it "sets the size of the first basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.i = V[1, 2, 3]
      lattice.basis.should eq Basis.new(V[1, 2, 3], V[0, 20, 0], V[0, 0, 30])
    end
  end

  describe "#j=" do
    it "sets the size of the second basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.j = V[1, 2, 3]
      lattice.basis.should eq Basis.new(V[10, 0, 0], V[1, 2, 3], V[0, 0, 30])
    end
  end

  describe "#k=" do
    it "sets the size of the third basis vector" do
      lattice = Lattice.new(S[10, 20, 30])
      lattice.k = V[1, 2, 3]
      lattice.basis.should eq Basis.new(V[10, 0, 0], V[0, 20, 0], V[1, 2, 3])
    end
  end

  describe "#volume" do
    it "returns lattice's volume" do
      Lattice.new(S[10, 20, 30]).volume.should eq 6_000
      Lattice.new(S[5, 5, 8], 90, 90, 120).volume.should be_close 173.2050807569, 1e-10
      Lattice.new(S[1, 2, 3], beta: 101.2).volume.should be_close 5.8857309321, 1e-10
    end
  end
end
