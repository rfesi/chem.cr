require "../spec_helper"

describe Topology::Perception do
  describe "#assign_templates" do
    it "guesses bonds and types based on templates" do
      st = fake_structure
      r1, r2, r3 = st.residues

      Topology::Perception.guess_topology st, use_templates: true

      [r1, r2, r3].map(&.protein?).should eq [true, true, true]
      [r1, r2, r3].map(&.formal_charge).should eq [-1, 0, 0]

      r1["N"].bonded_atoms.map(&.name).should eq ["CA"]

      r1["N"].bonds[r1["CA"]].order.should eq 1
      r1["CA"].bonds[r1["C"]].order.should eq 1
      r1["C"].bonds[r1["O"]].order.should eq 2
      r1["CA"].bonds[r1["CB"]].order.should eq 1
      r1["CB"].bonds[r1["CG"]].order.should eq 1
      r1["CG"].bonds[r1["OD1"]].order.should eq 2
      r1["CG"].bonds[r1["OD2"]].order.should eq 1

      r1["C"].bonded_atoms.map(&.name).should eq ["CA", "O", "N"]
      r2["N"].bonded_atoms.map(&.name).should eq ["C", "CA"]

      r2["N"].bonds[r2["CA"]].order.should eq 1
      r2["CA"].bonds[r2["C"]].order.should eq 1
      r2["C"].bonds[r2["O"]].order.should eq 2
      r2["CA"].bonds[r2["CB"]].order.should eq 1
      r2["CB"].bonds[r2["CG"]].order.should eq 1
      r2["CG"].bonds[r2["CD1"]].order.should eq 2
      r2["CD1"].bonds[r2["CE1"]].order.should eq 1
      r2["CE1"].bonds[r2["CZ"]].order.should eq 2
      r2["CZ"].bonds[r2["CE2"]].order.should eq 1
      r2["CE2"].bonds[r2["CD2"]].order.should eq 2
      r2["CD2"].bonds[r2["CG"]].order.should eq 1

      r2["C"].bonded_atoms.map(&.name).should eq ["CA", "O"]
      r3["N"].bonded_atoms.map(&.name).should eq ["CA"]

      r3["N"].bonds[r3["CA"]].order.should eq 1
      r3["CA"].bonds[r3["C"]].order.should eq 1
      r3["C"].bonds[r3["O"]].order.should eq 2
      r3["CA"].bonds[r3["CB"]].order.should eq 1
      r3["CB"].bonds[r3["OG"]].order.should eq 1

      r3["C"].bonded_atoms.map(&.name).should eq ["CA", "O"]
    end

    it "guesses bonds of unknown residues" do
      structure = load_file "residue_kind_unknown_covalent_ligand.pdb", topology: :templates
      structure.dig('A', 148, "C20").bonded?(structure.dig('A', 147, "SG")).should be_true
      structure.dig('A', 148, "C20").bonded?(structure.dig('A', 148, "N21")).should be_true
      structure.dig('A', 148, "S2").bonded?(structure.dig('A', 148, "O23")).should be_true
    end

    it "does not connect consecutive residues when there are far away" do
      st = load_file "protein_gap.pdb", topology: :templates
      r1, r2, r3, r4 = st.residues
      r1["C"].bonds[r2["N"]]?.should_not be_nil
      r2["C"].bonds[r3["N"]]?.should be_nil
      r3["C"].bonds[r4["N"]]?.should_not be_nil
    end

    it "guesses kind of unknown residue when previous is known" do
      st = load_file "residue_kind_unknown_previous.pdb", topology: :templates
      st.residues[1].protein?.should be_true
    end

    it "guesses kind of unknown residue when next is known" do
      st = load_file "residue_kind_unknown_next.pdb", topology: :templates
      st.residues[0].protein?.should be_true
    end

    it "guesses kind of unknown residue when its flanked by known residues" do
      st = load_file "residue_kind_unknown_flanked.pdb", topology: :templates
      st.residues[1].protein?.should be_true
    end

    it "does not guess kind of unknown residue" do
      st = load_file "residue_kind_unknown_single.pdb", topology: :templates
      st.residues[0].other?.should be_true
    end

    it "does not guess kind of unknown residue when its not connected to others" do
      st = load_file "residue_kind_unknown_next_gap.pdb", topology: :templates
      st.residues.first.other?.should be_true
    end

    it "does not guess kind of unknown residue when it's not bonded by link bond" do
      structure = load_file "residue_kind_unknown_covalent_ligand.pdb", topology: :templates
      structure.residues.map(&.kind.to_s).should eq %w(Protein Protein Protein Other)
    end
  end

  describe "#guess_bonds" do
    it "guesses bonds from geometry" do
      atoms = load_file("AlaIle--unwrapped.poscar", topology: :bonds).atoms
      n_bonds = [4, 4, 3, 4, 3, 4, 4, 4, 4, 1, 1, 1, 1, 1, 1, 1,
                 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 3]
      atoms.each_with_index { |atom, i| atom.bonds.size.should eq n_bonds[i] }
      atoms[0].bonded_atoms.map(&.serial).sort!.should eq [2, 14, 15, 16]
      atoms[4].bonded_atoms.map(&.serial).sort!.should eq [4, 28, 30]
      atoms[4].bonds[atoms[27]].order.should eq 2
      atoms[4].bonds[atoms[29]].order.should eq 1
    end

    it "guesses bonds from geometry of a protein with charged termini and ions" do
      structure = load_file "k2p_pore_b.xyz", topology: :bonds

      structure.bonds.size.should eq 644
      structure.bonds.sum(&.order).should eq 714
      structure.bonds.count(&.single?).should eq 574
      structure.bonds.count(&.double?).should eq 70

      structure.formal_charge.should eq 3
      structure.atoms.count(&.formal_charge.!=(0)).should eq 9

      # ions
      (638..641).each do |i|
        structure.atoms[i].valency.should eq 1
        structure.atoms[i].bonds.size.should eq 0
        structure.atoms[i].formal_charge.should eq 1
      end

      # n-ter
      structure.atoms[324].valency.should eq 3
      structure.atoms[324].bonds.size.should eq 4
      structure.atoms[324].formal_charge.should eq 1

      # c-ter
      structure.atoms[364].valency.should eq 2
      structure.atoms[364].formal_charge.should eq -1
      structure.atoms[365].valency.should eq 2
      structure.atoms[365].formal_charge.should eq 0

      structure.atoms[149].bonded_atoms.map(&.serial).should eq [145] # H near two Os

      # aromatic ring
      structure.atoms[427].bonds[structure.atoms[428]].order.should eq 2
      structure.atoms[428].bonds[structure.atoms[430]].order.should eq 1
      structure.atoms[430].bonds[structure.atoms[432]].order.should eq 2
      structure.atoms[432].bonds[structure.atoms[431]].order.should eq 1
      structure.atoms[431].bonds[structure.atoms[429]].order.should eq 2
      structure.atoms[429].bonds[structure.atoms[427]].order.should eq 1
    end

    it "guesses bonds from geometry having a sulfate ion" do
      structure = load_file "sulbactam.xyz", topology: :bonds

      structure.bonds.size.should eq 27
      structure.bonds.sum(&.order).should eq 31
      structure.bonds.count(&.single?).should eq 23
      structure.bonds.count(&.double?).should eq 4

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0

      structure.atoms[13].valency.should eq 2
      structure.atoms[13].bonded_atoms.map(&.serial).sort!.should eq [13, 26]
      structure.atoms[14].valency.should eq 2
      structure.atoms[14].bonded_atoms.map(&.serial).should eq [13]

      # sulfate ion
      structure.atoms[3].valency.should eq 6
      structure.atoms[3].bonded_atoms.map(&.serial).sort!.should eq [2, 5, 6, 7]
      structure.atoms[3].bonds[structure.atoms[1]].single?.should be_true
      structure.atoms[3].bonds[structure.atoms[4]].double?.should be_true
      structure.atoms[3].bonds[structure.atoms[5]].double?.should be_true
      structure.atoms[3].bonds[structure.atoms[6]].single?.should be_true
    end

    it "guesses bonds from geometry of a protein having sulfur" do
      structure = load_file "acama.xyz", topology: :bonds

      structure.bonds.size.should eq 60
      structure.bonds.sum(&.order).should eq 65
      structure.bonds.count(&.single?).should eq 55
      structure.bonds.count(&.double?).should eq 5

      structure.formal_charge.should eq 0
      structure.atoms.count(&.formal_charge.!=(0)).should eq 0

      structure.atoms[15].valency.should eq 2
      structure.atoms[15].bonded_atoms.map(&.serial).should eq [15, 21]
      structure.atoms[15].bonds[structure.atoms[14]].single?.should be_true
      structure.atoms[15].bonds[structure.atoms[20]].single?.should be_true

      structure.atoms[37].valency.should eq 2
      structure.atoms[37].bonded_atoms.map(&.serial).should eq [37, 39]
      structure.atoms[37].bonds[structure.atoms[36]].single?.should be_true
      structure.atoms[37].bonds[structure.atoms[38]].single?.should be_true
    end

    it "doesn't guess bond orders if hydrogens are missing" do
      structure = load_file "residue_kind_unknown_covalent_ligand.pdb", topology: :bonds
      structure.bonds.size.should eq 59
      structure.bonds.all?(&.single?).should be_true
      structure.formal_charges.all?(&.==(0)).should be_true
    end
  end

  describe "#guess_residues" do
    it "guesses the topology of a dipeptide" do
      structure = load_file "AlaIle--unwrapped.poscar", topology: :guess
      structure.chains.map(&.id).should eq ['A']
      structure.residues.map(&.name).should eq %w(ALA ILE)
      structure.residues.map(&.number).should eq [1, 2]
      structure.residues[0].atoms.map(&.name).should eq %w(
        N CA HA C O CB HB1 HB2 HB3 H1 H2)
      structure.residues[1].atoms.map(&.name).should eq %w(
        N H CA HA C O CB HB CG1 HG11 HG12 CD HD1 HD2 HD3 CG2 HG21 HG22 HG23 OXT HXT)
    end

    it "guesses the topology of two peptide chains" do
      structure = load_file "5e61--unwrapped.poscar", topology: :guess
      structure.chains.map(&.id).should eq ['A', 'B']
      structure.each_chain do |chain|
        chain.residues.map(&.name).should eq %w(PHE GLY ALA ILE LEU SER SER)
        chain.residues.map(&.number).should eq (1..7).to_a
        chain.residues[0].atoms.map(&.name).should eq %w(
          N CA HA C O CB HB1 HB2 CG CD1 HD1 CE1 HE1 CZ HZ CE2 HE2 CD2 HD2 H1 H2)
        chain.residues[5].atoms.map(&.name).should eq %w(
          N H CA HA C O CB HB1 HB2 OG HG)
        chain.residues[6].atoms.map(&.name).should eq %w(
          N H CA HA C O CB HB1 HB2 OG HG OXT HXT)
      end
    end

    it "guesses the topology of two peptides off-center (issue #3)" do
      chains = load_file("5e61--off-center.poscar", topology: :guess).chains
      chains.map(&.id).should eq ['A', 'B']
      chains[0].residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER SER)
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER SER)
      chains[1].residues.map(&.number).should eq (1..7).to_a
    end

    it "guesses the topology of a broken peptide with waters" do
      chains = load_file("5e5v--unwrapped.poscar", topology: :guess).chains
      chains.map(&.id).should eq ['A', 'B', 'C', 'D']
      chains[0].residues.map(&.name).sort!.should eq %w(ALA ASN GLY ILE LEU PHE SER)
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).sort!.should eq %w(ALA GLY ILE LEU PHE SER UNK)
      chains[1].residues.map(&.number).should eq (1..7).to_a
      chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      chains[2].residues.map(&.number).should eq (1..7).to_a
      chains[3].residues.map(&.name).should eq %w(UNK)
      chains[3].residues.map(&.number).should eq [1]
    end

    it "guesses the topology of a periodic peptide" do
      chains = load_file("hlx_gly.poscar", topology: :guess).chains
      chains.map(&.id).should eq ['A']
      chains[0].residues.map(&.name).should eq ["GLY"] * 13
      chains[0].residues.map(&.number).should eq (1..13).to_a
    end

    it "guesses the topology of many fragments (beyond max chain id)" do
      structure = load_file "many_fragments.poscar", topology: :guess
      structure.n_chains.should eq 1
      structure.n_residues.should eq 144
      structure.fragments.size.should eq 72
      structure.chains.map(&.id).should eq ['A']
      structure.residues.map(&.name).should eq ["PHE"] * 144
      structure.residues.map(&.number).should eq (1..144).to_a
    end

    it "detects multiple residues for unmatched atoms (#16)" do
      structure = load_file "peptide_unknown_residues.xyz", topology: :guess
      structure.n_residues.should eq 9
      structure.residues.map(&.name).should eq %w(ALA LEU VAL THR LEU SER ALA UNK UNK)
      structure.residues[7].n_atoms.should eq 14
      structure.residues[8].n_atoms.should eq 8
    end
  end

  describe "#renumber_by_connectivity" do
    it "renumbers residues in ascending order based on the link bond" do
      structure = load_file "5e5v--unwrapped.poscar", topology: :renumber

      chains = structure.chains
      chains[0].residues.map(&.number).should eq (1..7).to_a
      chains[0].residues.map(&.name).should eq %w(ASN PHE GLY ALA ILE LEU SER)
      chains[1].residues.map(&.number).should eq (1..7).to_a
      chains[1].residues.map(&.name).should eq %w(UNK PHE GLY ALA ILE LEU SER)
      chains[2].residues.map(&.name).should eq %w(HOH HOH HOH HOH HOH HOH HOH)
      chains[2].residues.map(&.number).should eq (1..7).to_a
      chains[3].residues.map(&.name).should eq %w(UNK)
      chains[3].residues.map(&.number).should eq [1]

      chains[0].residues[0].previous.should be_nil
      chains[0].residues[3].previous.try(&.name).should eq "GLY"
      chains[0].residues[3].next.try(&.name).should eq "ILE"
      chains[0].residues[-1].next.should be_nil
    end

    it "renumbers residues of a periodic peptide" do
      structure = load_file "hlx_gly.poscar", topology: :renumber

      structure.each_residue.cons(2, reuse: true).each do |(a, b)|
        a["C"].bonded?(b["N"]).should be_true
        a.next.should eq b
        b.previous.should eq a
      end
    end
  end
end
