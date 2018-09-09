require "./spec_helper"

describe Chem::PDB do
  # TODO test partial occupancy and insertion code (5tun)
  describe ".parse" do
    pending "parses a PDB file" do
      system = PDB.parse "spec/data/1h1s.pdb"
      system.size.should eq 9701
      system.formal_charge.should eq 0

      atom = system.atoms[-1]
      atom.index.should eq 9700
      atom.serial.should eq 9705
      atom.name.should eq "O"
      atom.altloc.should be_nil
      atom.residue_name.should eq "HOH"
      atom.chain.should eq 'D'
      atom.residue_number.should eq 2112
      atom.insertion_code.should be_nil
      atom.coords.should eq Vector[66.315, 27.887, 48.252]
      atom.occupancy.should eq 1
      atom.temperature_factor.should eq 53.58
      atom.element.should eq PeriodicTable::Elements::O
      atom.charge.should eq 0

      system.atoms[atom.index].should be atom
    end

    it "parses a PDB file" do
      system = PDB.parse "spec/data/pdb/simple.pdb"
      system.experiment.should be_nil
      system.title.should eq "Glutamate"
      system.size.should eq 13
      system.chains.size.should eq 1
      system.residues.size.should eq 3
      system.atoms.map(&.element.symbol).should eq ["C", "O", "O", "N", "C", "C", "O",
                                                    "C", "C", "C", "O", "O", "N"]
      system.atoms.map(&.charge).should eq [0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, -1, 1]

      atom = system.atoms[11]
      atom.index.should eq 11
      atom.serial.should eq 12
      atom.name.should eq "OE2"
      # atom.altloc.should be_nil
      atom.residue.name.should eq "GLU"
      atom.chain.id.should eq 'A'
      atom.residue.number.should eq 2
      # atom.insertion_code.should be_nil
      atom.coords.should eq Vector[-1.204, 4.061, 0.195]
      atom.occupancy.should eq 1
      atom.temperature_factor.should eq 0
      atom.element.should eq PeriodicTable::Elements::O
      atom.charge.should eq -1
    end

    it "parses a PDB file without elements" do
      system = PDB.parse "spec/data/pdb/no_elements.pdb"
      system.size.should eq 6
      system.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      system.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without elements and irregular line width (77)" do
      system = PDB.parse "spec/data/pdb/no_elements_irregular_end.pdb"
      system.size.should eq 6
      system.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      system.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without charges" do
      system = PDB.parse "spec/data/pdb/no_charges.pdb"
      system.size.should eq 6
      system.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      system.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without charges and irregular line width (79)" do
      system = PDB.parse "spec/data/pdb/no_charges_irregular_end.pdb"
      system.size.should eq 6
      system.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      system.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without trailing spaces" do
      system = PDB.parse "spec/data/pdb/no_trailing_spaces.pdb"
      system.size.should eq 6
      system.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      system.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file with long title" do
      system = PDB.parse "spec/data/pdb/title_long.pdb"
      system.title.should eq "STRUCTURE OF THE TRANSFORMED MONOCLINIC LYSOZYME BY " \
                             "CONTROLLED DEHYDRATION"
    end

    it "parses a PDB file with numbers in hexadecimal representation" do
      system = PDB.parse "spec/data/pdb/big_numbers.pdb"
      system.size.should eq 6
      system.atoms.map(&.serial).should eq (99995..100000).to_a
      system.residues.map(&.number).should eq [9999, 10000]
    end

    it "parses a PDB file with unit cell parameters" do
      system = PDB.parse "spec/data/pdb/1crn.pdb"

      system.lattice.should_not be_nil
      lattice = system.lattice.not_nil!
      lattice.size.to_a.should eq [40.960, 18.650, 22.520]
      lattice.alpha.should eq 90
      lattice.beta.should eq 90.77
      lattice.gamma.should eq 90
      lattice.space_group.should eq "P 1 21 1"
    end

    it "parses a PDB file with experimental header" do
      system = PDB.parse "spec/data/pdb/1crn.pdb"

      system.title.should eq "1crn"
      system.experiment.should_not be_nil
      exp = system.experiment.not_nil!
      exp.deposition_date.should eq Time.utc(1981, 4, 30)
      exp.doi.should eq "10.1073/PNAS.81.19.6014"
      exp.kind.should eq Chem::Protein::Experiment::Kind::XRayDiffraction
      exp.pdb_accession.should eq "1crn"
      exp.resolution.should eq 1.5
      exp.title.should eq "WATER STRUCTURE OF A HYDROPHOBIC PROTEIN AT ATOMIC " \
                          "RESOLUTION. PENTAGON RINGS OF WATER MOLECULES IN CRYSTALS " \
                          "OF CRAMBIN"
    end

    it "parses a PDB file with sequence" do
      system = PDB.parse "spec/data/pdb/1crn.pdb"

      system.sequence.should_not be_nil
      seq = system.sequence.not_nil!
      seq.to_s.should eq "TTCCPSIVARSNFNVCRLPGTPEAICATYTGCIIIPGATCPGDYAN"
    end

    it "parses secondary structure information" do
      system = PDB.parse "spec/data/pdb/1crn.pdb"
      system.residues[0].dssp.should eq 'B'
      system.residues[1].dssp.should eq 'B'
      system.residues[3].dssp.should eq 'B'
      system.residues[4].dssp.should eq '0'
      system.residues[5].dssp.should eq '0'
      system.residues[6].dssp.should eq 'H'
      system.residues[18].dssp.should eq 'H'
      system.residues[19].dssp.should eq '0'
      system.residues[31].dssp.should eq 'B'
      system.residues[-1].dssp.should eq '0'
    end

    it "fails when charges are ill formatted" do
      expect_raises PDB::ParseException, "Couldn't read a formal charge at 4:78" do
        PDB.parse "spec/data/pdb/bad_charges.pdb"
      end
    end
  end
end
