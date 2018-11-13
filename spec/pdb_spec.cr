require "./spec_helper"

describe Chem::PDB do
  # TODO test partial occupancy and insertion code (5tun)
  describe ".parse" do
    it "parses a (real) PDB file" do
      st = PDB.read_first "spec/data/pdb/1h1s.pdb"
      st.size.should eq 9701
      st.formal_charge.should eq 0

      st.chains.map(&.id).should eq ['A', 'B', 'C', 'D']
      st.chains['A'].residues.size.should eq 569
      st.chains['B'].residues.size.should eq 440
      st.chains['C'].residues.size.should eq 436
      st.chains['D'].residues.size.should eq 370

      atom = st.atoms[-1]
      atom.serial.should eq 9705
      atom.name.should eq "O"
      atom.alt_loc.should be_nil
      atom.residue.name.should eq "HOH"
      atom.chain.id.should eq 'D'
      atom.residue.number.should eq 2112
      atom.coords.should eq Vector[66.315, 27.887, 48.252]
      atom.occupancy.should eq 1
      atom.temperature_factor.should eq 53.58
      atom.element.oxygen?.should be_true
      atom.charge.should eq 0
    end

    it "parses a PDB file" do
      st = PDB.read_first "spec/data/pdb/simple.pdb"
      st.experiment.should be_nil
      st.title.should eq "Glutamate"
      st.size.should eq 13
      st.chains.size.should eq 1
      st.residues.size.should eq 3
      st.atoms.map(&.element.symbol).should eq ["C", "O", "O", "N", "C", "C", "O",
                                                "C", "C", "C", "O", "O", "N"]
      st.atoms.map(&.charge).should eq [0, 0, -1, 0, 0, 0, 0, 0, 0, 0, 0, -1, 1]

      atom = st.atoms[11]
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
      atom.element.oxygen?.should be_true
      atom.charge.should eq -1
    end

    it "parses a PDB file without elements" do
      st = PDB.read_first "spec/data/pdb/no_elements.pdb"
      st.size.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without elements and irregular line width (77)" do
      st = PDB.read_first "spec/data/pdb/no_elements_irregular_end.pdb"
      st.size.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without charges" do
      st = PDB.read_first "spec/data/pdb/no_charges.pdb"
      st.size.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without charges and irregular line width (79)" do
      st = PDB.read_first "spec/data/pdb/no_charges_irregular_end.pdb"
      st.size.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file without trailing spaces" do
      st = PDB.read_first "spec/data/pdb/no_trailing_spaces.pdb"
      st.size.should eq 6
      st.atoms.map(&.element.symbol).should eq ["N", "C", "C", "O", "C", "O"]
      st.atoms.map(&.charge).should eq [0, 0, 0, 0, 0, 0]
    end

    it "parses a PDB file with long title" do
      st = PDB.read_first "spec/data/pdb/title_long.pdb"
      st.title.should eq "STRUCTURE OF THE TRANSFORMED MONOCLINIC LYSOZYME BY " \
                         "CONTROLLED DEHYDRATION"
    end

    it "parses a PDB file with numbers in hexadecimal representation" do
      st = PDB.read_first "spec/data/pdb/big_numbers.pdb"
      st.size.should eq 6
      st.atoms.map(&.serial).should eq (99995..100000).to_a
      st.residues.map(&.number).should eq [9999, 10000]
    end

    it "parses a PDB file with number of atoms/residues equal to asterisks (vmd)" do
      st = PDB.read_first "spec/data/pdb/asterisks.pdb"
      st.size.should eq 18
      st.residues.size.should eq 6
      st.atoms.map(&.serial).should eq (99998..100015).to_a
      st.residues.map(&.number).should eq [9998, 9999, 10000, 65535, 65536, 65537]
    end

    it "parses a PDB file with unit cell parameters" do
      st = PDB.read_first "spec/data/pdb/1crn.pdb"

      st.lattice.should_not be_nil
      lattice = st.lattice.not_nil!
      lattice.size.to_a.should eq [40.960, 18.650, 22.520]
      lattice.alpha.should eq 90
      lattice.beta.should eq 90.77
      lattice.gamma.should eq 90
      lattice.space_group.should eq "P 1 21 1"
    end

    it "parses a PDB file with experimental header" do
      st = PDB.read_first "spec/data/pdb/1crn.pdb"

      st.title.should eq "1crn"
      st.experiment.should_not be_nil
      exp = st.experiment.not_nil!
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
      st = PDB.read_first "spec/data/pdb/1crn.pdb"

      st.sequence.should_not be_nil
      seq = st.sequence.not_nil!
      seq.to_s.should eq "TTCCPSIVARSNFNVCRLPGTPEAICATYTGCIIIPGATCPGDYAN"
    end

    it "parses secondary structure information" do
      st = PDB.read_first "spec/data/pdb/1crn.pdb"
      st.residues[0].dssp.should eq 'B'
      st.residues[1].dssp.should eq 'B'
      st.residues[3].dssp.should eq 'B'
      st.residues[4].dssp.should eq '0'
      st.residues[5].dssp.should eq '0'
      st.residues[6].dssp.should eq 'H'
      st.residues[18].dssp.should eq 'H'
      st.residues[19].dssp.should eq '0'
      st.residues[31].dssp.should eq 'B'
      st.residues[-1].dssp.should eq '0'
    end

    it "parses bonds" do
      st = PDB.read_first "spec/data/pdb/1crn.pdb"
      st.atoms[19].bonds[st.atoms[281]].order.should eq 1
      st.atoms[25].bonds[st.atoms[228]].order.should eq 1
      st.atoms[115].bonds[st.atoms[187]].order.should eq 1
    end

    it "parses duplicate bonds" do
      st = PDB.read_first "spec/data/pdb/duplicate_bonds.pdb"
      st.atoms[0].bonds[st.atoms[1]].order.should eq 1
      st.atoms[1].bonds[st.atoms[2]].order.should eq 2
      st.atoms[2].bonds[st.atoms[3]].order.should eq 1
      st.atoms[3].bonds[st.atoms[4]].order.should eq 2
      st.atoms[4].bonds[st.atoms[5]].order.should eq 1
      st.atoms[5].bonds[st.atoms[0]].order.should eq 2
    end

    it "parses alternate conformations" do
      residue = PDB.read_first("spec/data/pdb/alternate_conf.pdb").residues.first
      residue.has_alternate_conformations?.should be_true
      residue.conformations.map(&.id).should eq ['A', 'B', 'C']
      residue.conformations.map(&.occupancy).should eq [0.37, 0.33, 0.3]

      residue.conf.try(&.id).should eq 'A'
      residue["N"].x.should eq 7.831
      residue["OD1"].x.should eq 10.427

      residue.conf = 'C'
      residue["N"].x.should eq 7.831
      residue["OD1"].x.should eq 8.924
    end

    it "parses alternate conformations with different residues" do
      residue = PDB.read_first("spec/data/pdb/alternate_conf_mut.pdb").residues.first
      residue.has_alternate_conformations?.should be_true
      residue.conformations.map(&.id).should eq ['A', 'B', 'C']
      residue.conformations.map(&.residue_name).should eq ["ARG", "ARG", "TRP"]
      residue.conformations.map(&.occupancy).should eq [0.22, 0.22, 0.56]

      residue.conf.try(&.id).should eq 'C' #  highest occupancy
      residue.name.should eq "TRP"
      residue.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB", "CG", "CD1",
                                           "CD2", "NE1", "CE2", "CE3", "CZ2", "CZ3",
                                           "CH2"]

      residue.conf = 'A'
      residue.name.should eq "ARG"
      residue.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB", "CG", "CD", "NE",
                                           "CZ", "NH1", "NH2"]
    end

    it "parses insertion codes" do
      residues = PDB.read_first("spec/data/pdb/insertion_codes.pdb").residues
      residues.size.should eq 7
      residues.map(&.number).should eq [75, 75, 75, 75, 75, 75, 76]
      residues.map(&.insertion_code).should eq [nil, 'A', 'B', 'C', 'D', 'E', nil]
    end

    it "parses multiple models" do
      st_list = PDB.read "spec/data/pdb/models.pdb"
      st_list.size.should eq 4
      xs = {5.606, 7.212, 5.408, 22.055}
      st_list.zip(xs) do |st, x|
        st.size.should eq 5
        st.atoms.map(&.serial).should eq (1..5).to_a
        st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
        st.atoms[0].x.should eq x
      end
    end

    it "parses selected model" do
      st = PDB.read "spec/data/pdb/models.pdb", model: 4
      st.size.should eq 5
      st.atoms.map(&.serial).should eq (1..5).to_a
      st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
      st.atoms[0].x.should eq 22.055
    end

    it "parses selected models" do
      st_list = PDB.read "spec/data/pdb/models.pdb", models: {2, 4}
      st_list.size.should eq 2
      xs = {7.212, 22.055}
      st_list.zip(xs) do |st, x|
        st.size.should eq 5
        st.atoms.map(&.serial).should eq (1..5).to_a
        st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB"]
        st.atoms[0].x.should eq x
      end
    end

    it "parses file without the END record" do
      st = PDB.read_first "spec/data/pdb/no_end.pdb"
      st.size.should eq 6
      st.chains.map(&.id).should eq ['A']
      st.residues.map(&.number).should eq [0]
      st.residues.map(&.name).should eq ["SER"]
      st.atoms.map(&.name).should eq ["N", "CA", "C", "O", "CB", "OG"]
    end

    it "parses 1cbn (alternate conformations)" do
      st = PDB.read_first "spec/data/pdb/1cbn.pdb"
      st.size.should eq 644 # atom with alt_loc = nil or highest occupancy
      st.chains.size.should eq 1
      st.residues.size.should eq 47
      st.residues.map(&.number).should eq ((1..46).to_a << 66)

      res = st.residues[serial: 23]
      res.has_alternate_conformations?.should be_true
      { {'A', 0.8, 10.387}, {'B', 0.2, 10.421} }.each do |conf_id, occupancy, cg_x|
        res.conf = conf_id
        res.conf.try(&.occupancy).should eq occupancy
        res["CG"].x.should eq cg_x
      end
    end

    it "parses 1dpo (insertions)" do
      st = PDB.read_first "spec/data/pdb/1dpo.pdb"
      st.size.should eq 1921 # atom with alt_loc = nil or A
      st.chains.size.should eq 1
      st.residues.size.should eq 446

      missing = {35, 36, 68, 126, 131, 205, 206, 207, 208, 218}
      resids = [] of Tuple(Int32, Char?)
      resids.concat (16..246).reject { |i| missing.includes? i }.map { |i| {i, nil} }
      resids.concat [250, 251, 247, 248, 249].map { |num| {num, nil} }
      resids.concat (252..468).map { |num| {num, nil} }
      {184, 188, 221}.each do |i|
        resids.insert resids.index!({i, nil}) + 1, {i, 'A'}
      end
      st.residues.map { |res| {res.number, res.insertion_code} }.should eq resids
    end
  end
end
