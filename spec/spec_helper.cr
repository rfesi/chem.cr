require "spec"
require "../src/chem"

alias Atom = Chem::Atom
alias AtomView = Chem::AtomView
alias Constraint = Chem::Constraint
alias Element = Chem::PeriodicTable::Element
alias PDB = Chem::PDB
alias PeriodicTable = Chem::PeriodicTable
alias Vector = Chem::Spatial::Vector

module Spec
  struct CloseExpectation
    def match(actual_value : Array(T)) forall T
      if @expected_value.size != actual_value.size
        raise ArgumentError.new "arrays have different sizes"
      end
      actual_value.zip(@expected_value).all? { |a, b| (a - b).abs <= @delta }
    end

    def match(actual_value : Chem::Spatial::Vector)
      [(actual_value.x - @expected_value.x).abs,
       (actual_value.y - @expected_value.y).abs,
       (actual_value.z - @expected_value.z).abs].all? do |value|
        value <= @delta
      end
    end
  end
end

module Chem::VASP::Poscar
  def self.write_and_read_back(system : System) : System
    io = ::IO::Memory.new
    Poscar.write io, system
    io.rewind
    other = Poscar.parse io
    io.close
    other
  end
end

def fake_residue_with_alternate_conformations
  Chem::System.build do
    residue "SER" do
      atoms "N", "CA", "C", "O"

      conf 'A', occupancy: 0.65 do
        atom "CB", {1.0, 0.0, 0.0}
        atom "OG", {1.0, 0.0, 0.0}
      end

      conf 'B', occupancy: 0.2 do
        atom "CB", {2.0, 0.0, 0.0}
        atom "OG", {2.0, 0.0, 0.0}
      end

      conf 'C', occupancy: 0.1 do
        atom "CB", {3.0, 0.0, 0.0}
        atom "OG", {3.0, 0.0, 0.0}
      end

      conf 'D', occupancy: 0.05 do
        atom "OB", {4.0, 0.0, 0.0}
        atom "CG1", {4.0, 0.0, 0.0}
        atom "CG2", {4.0, 0.0, 0.0}
      end
    end
  end.residues.first
end

# TODO add SystemBuilder?
def fake_system(*, include_bonds = false)
  sys = Chem::System.build do
    title "Asp-Phe Ser"

    chain do
      residue "ASP" do
        atom "N", at: {-2.186, 22.128, 79.139}
        atom "CA", at: {-0.955, 21.441, 78.711}
        atom "C", at: {-0.595, 21.849, 77.252}
        atom "O", at: {-1.461, 21.781, 76.374}
        atom "CB", at: {-1.316, 19.953, 79.003}
        atom "CG", at: {-0.895, 18.952, 77.936}
        atom "OD1", at: {-1.281, 17.738, 78.086}
        atom "OD2", at: {-0.209, 19.223, 76.945}, charge: -1
      end

      residue "PHE" do
        atom "N", at: {0.647, 22.313, 76.991}
        atom "CA", at: {1.092, 22.731, 75.639}
        atom "C", at: {1.006, 21.699, 74.529}
        atom "O", at: {0.990, 22.038, 73.319}
        atom "CB", at: {2.618, 23.255, 75.696}
        atom "CG", at: {2.643, 24.713, 75.877}
        atom "CD1", at: {1.790, 25.237, 76.833}
        atom "CD2", at: {3.242, 25.569, 74.992}
        atom "CE1", at: {1.639, 26.577, 76.996}
        atom "CE2", at: {3.100, 26.930, 75.157}
        atom "CZ", at: {2.331, 27.435, 76.167}
      end
    end

    chain do
      residue "SER" do
        atom "N", at: {7.186, 2.582, 8.445}
        atom "CA", at: {6.500, 1.584, 7.565}
        atom "C", at: {5.382, 2.313, 6.773}
        atom "O", at: {5.213, 2.016, 5.557}
        atom "CB", at: {5.908, 0.462, 8.400}
        atom "OG", at: {6.990, -0.272, 9.012}
      end
    end
  end

  Chem::Topology.guess_topology of: sys if include_bonds

  sys
end
