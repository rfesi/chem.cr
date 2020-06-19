require "../spec_helper"

{% if env "STRIDE_BIN" %}
  describe Chem::Protein::Stride do
    it "assigns secondary structure (1cbn)" do
      structure = load_file "1cbn.pdb", topology: :templates
      Chem::Protein::Stride.assign structure
      expected = "0EE000HHHHHHHHHHHH0000HHHHHHHH00EE000000TTTTT0"
      structure.each_residue.select(&.protein?).map(&.dssp).join.should eq expected
    end

    it "assigns secondary structure (5jqf)" do
      structure = load_file "5jqf.pdb", topology: :templates
      Chem::Protein::Stride.assign structure
      expected = "00B0000BTTTTT0BTTEEE000B0000BTTTTT0B00EEE0"
      structure.each_residue.select(&.protein?).map(&.dssp).join.should eq expected
    end

    it "assigns secondary structure (1dpo, insertion codes)" do
      structure = load_file "1dpo.pdb", topology: :templates
      Chem::Protein::Stride.assign structure
      structure['A'][183].sec.beta_strand?.should be_true
      structure['A'][184].sec.none?.should be_true
      structure['A'][184, 'A'].sec.turn?.should be_true
    end

    it "calculates secondary structure (1cbn)" do
      structure = load_file "1cbn.pdb", topology: :templates
      ss_table = Chem::Protein::Stride.calculate structure
      ss_table[structure['A'][7]].helix_alpha?.should be_true
      ss_table[structure['A'][45]].turn?.should be_true
      ss_table[structure['A'][46]].none?.should be_true
    end
  end
{% end %}
