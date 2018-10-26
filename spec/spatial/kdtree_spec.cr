require "../../spec_helper"

alias KDTree = Chem::Spatial::KDTree

describe Chem::Spatial::KDTree do
  context "toy example" do
    system = Chem::System.build do
      atom at: {4, 3, 0}   # d^2 = 25
      atom at: {3, 0, 0}   # d^2 = 9
      atom at: {-1, 2, 0}  # d^2 = 5
      atom at: {6, 4, 0}   # d^2 = 52
      atom at: {3, -5, 0}  # d^2 = 34
      atom at: {-2, -5, 0} # d^2 = 29
    end

    tree = KDTree.new system.atoms

    describe "#nearest" do
      it "works" do
        tree.nearest(to: Vector.origin, within: 5.5).should eq [2, 1, 0, 5]
      end
    end

    describe "#nearest" do
      it "works" do
        tree.nearest(to: Vector.origin, neighbors: 2).should eq [2, 1]
      end
    end
  end

  context "real example" do
    system = PDB.parse "spec/data/pdb/1h1s.pdb"
    tree = KDTree.new system.atoms

    describe "#find" do
      it "works" do
        tree.nearest(to: Vector[19, 32, 44], neighbors: 1).should eq [9121]
      end
    end

    describe "#find" do
      it "works" do
        tree.nearest(to: Vector[19, 32, 44], within: 3.5).should eq [9121, 1118, 1116, 9120]
      end

      it "works" do
        atom_indices = [] of Int32
        tree.nearest(to: Vector[19, 32, 44], within: 3.5) do |atom_index, distance|
          atom_indices << atom_index
        end
        atom_indices.sort!.should eq [1116, 1118, 9120, 9121]
      end
    end
  end
end
