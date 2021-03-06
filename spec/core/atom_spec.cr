require "../spec_helper"

describe Chem::Atom do
  describe "#<=>" do
    it "compares based on serial" do
      atoms = load_file("5e5v.pdb").atoms
      (atoms[0] <=> atoms[1]).<(0).should be_true
      (atoms[1] <=> atoms[1]).should eq 0
      (atoms[2] <=> atoms[1]).>(0).should be_true
    end
  end

  describe "#===" do
    atom = Structure.build(guess_topology: false) { atom "NG1", V[0, 0, 0] }.atoms[0]

    it "tells if atom matches atom type" do
      (atom === Topology::AtomType.new("NG1")).should be_true
      (atom === Topology::AtomType.new("NG1", element: "O")).should be_false
      (atom === Topology::AtomType.new("CA")).should be_false
    end

    it "tells if atom matches element" do
      (atom === PeriodicTable::N).should be_true
      (atom === PeriodicTable::O).should be_false
    end
  end

  describe "#each_bonded_atom" do
    structure = Structure.build do
      atom :I, V[-1, 0, 0]
      atom :C, V[0, 0, 0]
      atom :N, V[1, 0, 0]
      bond "I1", "C1"
      bond "C1", "N1", order: 3
    end

    it "yields bonded atoms" do
      ary = [] of Atom
      structure.atoms[1].each_bonded_atom { |atom| ary << atom }
      ary.map(&.name).should eq ["I1", "N1"]
    end

    it "returns an iterator of bonded atoms" do
      structure.atoms[1].each_bonded_atom.map(&.name).to_a.should eq ["I1", "N1"]
    end
  end

  describe "#match?" do
    it "tells if atom matches atom type" do
      atom = Structure.build(guess_topology: false) { atom "CD2", V[0, 0, 0] }.atoms[0]
      atom.match?(Topology::AtomType.new("CD2", element: "C")).should be_true
      atom.match?(Topology::AtomType.new("CD2", element: "N")).should be_false
      atom.match?(Topology::AtomType.new("ND2")).should be_false
    end
  end

  describe "#missing_valency" do
    it "returns number of bonds to reach closest nominal valency (no bonds)" do
      structure = Structure.build(guess_topology: false) do
        atom :C, V[0, 0, 0]
      end
      structure.atoms[0].missing_valency.should eq 4
    end

    it "returns number of bonds to reach closest nominal valency (bonds)" do
      structure = Structure.build(guess_topology: false) do
        atom :C, V[0, 0, 0]
        atom :H, V[1, 0, 0]
        atom :H, V[-1, 0, 0]
        bond "C1", "H1"
        bond "C1", "H2"
      end
      structure.atoms[0].missing_valency.should eq 2
    end

    it "returns number of bonds to reach closest nominal valency (full bonds)" do
      structure = Structure.build(guess_topology: false) do
        atom :C, V[0, 0, 0]
        atom :O, V[0, 1, 0]
        atom :C, V[-1, 0, 0]
        atom :C, V[1, 0, 0]
        bond "C1", "O1", order: 2
        bond "C1", "C2"
        bond "C1", "C3"
      end
      structure.atoms[0].missing_valency.should eq 0
    end

    it "returns number of bonds to reach closest nominal valency (over bonds)" do
      structure = Structure.build(guess_topology: false) do
        atom :N, V[0, 0, 0]
        atom :C, V[-1, 0, 0]
        atom :H, V[1, 0, 0]
        atom :H, V[0, 1, 0]
        atom :H, V[0, -1, 0]
        bond "C1", "N1"
        bond "N1", "H1"
        bond "N1", "H2"
        bond "N1", "H3"
      end
      structure.atoms[0].missing_valency.should eq 0
    end
  end

  describe "#nominal_valency" do
    it "returns nominal valency (no bonds)" do
      structure = Structure.build(guess_topology: false) do
        atom :C, V[0, 0, 0]
      end
      structure.atoms[0].nominal_valency.should eq 4
    end

    it "returns nominal valency (bonds)" do
      structure = Structure.build(guess_topology: false) do
        atom :I, V[-1, 0, 0]
        atom :C, V[0, 0, 0]
        atom :N, V[1, 0, 0]
        bond "I1", "C1"
        bond "C1", "N1", order: 3
      end
      structure.atoms.map(&.nominal_valency).should eq [1, 4, 3]
    end

    it "returns nominal valency (bonds exceed maximum valency)" do
      structure = Structure.build(guess_topology: false) do
        atom :N, V[1, 0, 0]
        atom :H, V[-1, 0, 0]
        atom :H, V[1, 0, 0]
        atom :H, V[0, 1, 0]
        atom :H, V[0, -1, 0]
        bond "N1", "H1"
        bond "N1", "H2"
        bond "N1", "H3"
        bond "N1", "H4"
      end
      structure.atoms[0].nominal_valency.should eq 3
    end

    it "returns nominal valency (multiple valencies, 1)" do
      structure = Structure.build(guess_topology: false) do
        atom :C, V[-1, 0, 0]
        atom :S, V[0, 0, 0]
        atom :H, V[1, 0, 0]
        bond "C1", "S1"
        bond "S1", "H1"
      end
      structure.atoms[1].nominal_valency.should eq 2
    end

    it "returns nominal valency (multiple valencies, 2)" do
      structure = Structure.build(guess_topology: false) do
        atom :O, V[-1, 0, 0]
        atom :S, V[0, 0, 0]
        atom :O, V[1, 0, 0]
        atom :O, V[0, 1, 0]
        atom :O, V[0, -1, 0]
        bond "O1", "S1"
        bond "S1", "O2"
        bond "S1", "O3", order: 2
        bond "S1", "O4", order: 2
      end
      structure.atoms[1].nominal_valency.should eq 6
    end

    it "returns nominal valency (multiple valencies, 3)" do
      structure = Structure.build(guess_topology: false) do
        atom :O, V[-1, 0, 0]
        atom :S, V[0, 0, 0]
        atom :O, V[1, 0, 0]
        atom :O, V[0, 1, 0]
        atom :O, V[0, -1, 0]
        atom :O, V[1, -1, 0]
        bond "O1", "S1"
        bond "S1", "O2"
        bond "S1", "O3", order: 2
        bond "S1", "O4", order: 2
        bond "S1", "O5"
      end
      structure.atoms[1].nominal_valency.should eq 6
    end

    it "returns maximum valency for ionic elements" do
      structure = Structure.build(guess_topology: false) do
        atom :Na, V[0, 0, 0]
      end
      structure.atoms[0].nominal_valency.should eq 1
    end
  end

  describe "#within_covalent_distance?" do
    res = fake_structure.residues[0]

    it "returns true for covalently-bonded atoms" do
      res["N"].within_covalent_distance?(res["CA"]).should be_true
      res["CA"].within_covalent_distance?(res["C"]).should be_true
      res["CB"].within_covalent_distance?(res["CA"]).should be_true
    end

    it "returns false for non-bonded atoms" do
      res["N"].within_covalent_distance?(res["CB"]).should be_false
      res["CA"].within_covalent_distance?(res["O"]).should be_false
      res["CA"].within_covalent_distance?(res["OD1"]).should be_false
    end
  end
end
