require "../spec_helper"

describe Chem::Spatial do
  describe ".hlxparam" do
    it "returns helical parameters" do
      datasets = load_hlxparams_data
      st = Chem::PDB.read_first "spec/data/pdb/4wfe.pdb"
      Chem::Topology.guess_topology of: st
      st.each_residue.compact_map(&.hlxparams).with_index do |params, i|
        params.zeta.should be_close datasets[:zeta][i], 1e-1
        params.theta.should be_close datasets[:theta][i], 2e-1
        # params.radius.should be_close datasets[:radius][i], 5e-1
      end
    end

    it "returns nil when residue is terminal" do
      st = Chem::PDB.read_first "spec/data/pdb/hlxparam.pdb"
      Chem::Topology.guess_topology of: st

      st.residues.first.hlxparams.should be_nil
      st.residues.last.hlxparams.should be_nil
    end

    it "returns nil when residue is not bonded to its previous/next residue" do
      st = Chem::PDB.read_first "spec/data/pdb/hlxparam.pdb"
      Chem::Topology.guess_topology of: st

      # there is a gap between residues 2 and 3
      st.residues[2].hlxparams.should be_nil
      st.residues[3].hlxparams.should be_nil
    end
  end
end