require "../spec_helper.cr"

alias Poscar = Chem::VASP::Poscar

describe Chem::VASP::Poscar do
  describe ".parse" do
    it "parses a basic file" do
      system = Poscar.read "spec/data/poscar/basic.poscar"
      system.size.should eq 49

      system.atoms.count(&.element.symbol.==("C")).should eq 14
      system.atoms.count(&.element.symbol.==("H")).should eq 21
      system.atoms.count(&.element.symbol.==("N")).should eq 7
      system.atoms.count(&.element.symbol.==("O")).should eq 7

      atom = system.atoms[-1]
      atom.chain.id.should eq 'A'
      atom.coords.should eq Vector[1.25020645, 3.42088266, 4.92610368]
      atom.element.oxygen?.should be_true
      atom.serial.should eq 49
      atom.name.should eq "O7"
      atom.occupancy.should eq 1
      atom.residue.name.should eq "UNK"
      atom.residue.number.should eq 1
      atom.serial.should eq 49
      atom.temperature_factor.should eq 0

      system.atoms[0].element.carbon?.should be_true
      system.atoms[14].element.hydrogen?.should be_true
      system.atoms[35].element.nitrogen?.should be_true
    end

    it "parses a file with direct coordinates" do
      system = Poscar.read "spec/data/poscar/direct.poscar"
      system.atoms[0].coords.should eq Vector.origin
      system.atoms[1].coords.should be_close Vector[0.3, 0.45, 0.35], 1e-16
    end

    it "parses a file with selective dynamics" do
      system = Poscar.read "spec/data/poscar/selective_dynamics.poscar"
      system.atoms[0].constraint.should eq Constraint.new(:z)
      system.atoms[1].constraint.should eq Constraint.new(:xyz)
      system.atoms[2].constraint.should eq Constraint.new(:z)
    end

    it "fails when element symbols are missing" do
      msg = "Expected element symbols (vasp 5+) at 6:4"
      expect_raises(Poscar::ParseException, msg) do
        Poscar.read "spec/data/poscar/no_symbols.poscar"
      end
    end

    it "fails when there are missing atomic species counts" do
      msg = "Mismatch between element symbols and counts at 7:5"
      expect_raises(Poscar::ParseException, msg) do
        Poscar.read "spec/data/poscar/mismatch.poscar"
      end
    end
  end

  describe ".write" do
    it "works with cartesian coordinates" do
      system = Poscar.read "spec/data/poscar/basic.poscar"
      other = Poscar.write_and_read_back system

      system.atoms.each_with_index do |atom, index|
        atom.element.should be other.atoms[index].element
        atom.coords.should eq other.atoms[index].coords
      end
    end
  end
end
