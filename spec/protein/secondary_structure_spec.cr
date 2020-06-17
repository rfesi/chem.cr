require "../spec_helper"

describe Chem::Protein::SecondaryStructure do
  describe ".[]?" do
    it "returns the secondary structure member from the one-letter code" do
      Chem::Protein::SecondaryStructure['S']?.should eq sec(:bend)
      Chem::Protein::SecondaryStructure['B']?.should eq sec(:beta_bridge)
      Chem::Protein::SecondaryStructure['E']?.should eq sec(:beta_strand)
      Chem::Protein::SecondaryStructure['f']?.should eq sec(:left_handed_helix2_7)
      Chem::Protein::SecondaryStructure['g']?.should eq sec(:left_handed_helix3_10)
      Chem::Protein::SecondaryStructure['h']?.should eq sec(:left_handed_helix_alpha)
      Chem::Protein::SecondaryStructure['i']?.should eq sec(:left_handed_helix_pi)
      Chem::Protein::SecondaryStructure['0']?.should eq sec(:none)
      Chem::Protein::SecondaryStructure['C']?.should eq sec(:none)
      Chem::Protein::SecondaryStructure['P']?.should eq sec(:polyproline)
      Chem::Protein::SecondaryStructure['F']?.should eq sec(:right_handed_helix2_7)
      Chem::Protein::SecondaryStructure['G']?.should eq sec(:right_handed_helix3_10)
      Chem::Protein::SecondaryStructure['H']?.should eq sec(:right_handed_helix_alpha)
      Chem::Protein::SecondaryStructure['I']?.should eq sec(:right_handed_helix_pi)
      Chem::Protein::SecondaryStructure['T']?.should eq sec(:turn)
    end

    it "returns nil when code is invalid" do
      Chem::Protein::SecondaryStructure['X']?.should be_nil
    end
  end

  describe ".[]" do
    it "fails when code is invalid" do
      expect_raises Exception, "Unknown secondary structure code: X" do
        Chem::Protein::SecondaryStructure['X']
      end
    end
  end

  describe "#code" do
    it "returns the secondary structure one-letter code" do
      sec(:bend).code.should eq 'S'
      sec(:beta_bridge).code.should eq 'B'
      sec(:beta_strand).code.should eq 'E'
      sec(:left_handed_helix2_7).code.should eq 'f'
      sec(:left_handed_helix3_10).code.should eq 'g'
      sec(:left_handed_helix_alpha).code.should eq 'h'
      sec(:left_handed_helix_pi).code.should eq 'i'
      sec(:none).code.should eq '0'
      sec(:polyproline).code.should eq 'P'
      sec(:right_handed_helix2_7).code.should eq 'F'
      sec(:right_handed_helix3_10).code.should eq 'G'
      sec(:right_handed_helix_alpha).code.should eq 'H'
      sec(:right_handed_helix_pi).code.should eq 'I'
      sec(:turn).code.should eq 'T'
    end
  end

  describe "#helix2_7?" do
    it "tells if it's a 2.2_7-helix regardless of handedness" do
      sec(:bend).helix2_7?.should be_false
      sec(:beta_bridge).helix2_7?.should be_false
      sec(:beta_strand).helix2_7?.should be_false
      sec(:left_handed_helix2_7).helix2_7?.should be_true
      sec(:left_handed_helix3_10).helix2_7?.should be_false
      sec(:left_handed_helix_alpha).helix2_7?.should be_false
      sec(:left_handed_helix_pi).helix2_7?.should be_false
      sec(:none).helix2_7?.should be_false
      sec(:polyproline).helix2_7?.should be_false
      sec(:right_handed_helix2_7).helix2_7?.should be_true
      sec(:right_handed_helix3_10).helix2_7?.should be_false
      sec(:right_handed_helix_alpha).helix2_7?.should be_false
      sec(:right_handed_helix_pi).helix2_7?.should be_false
      sec(:turn).helix2_7?.should be_false
    end
  end

  describe "#helix3_10?" do
    it "tells if it's a 3_10-helix regardless of handedness" do
      sec(:bend).helix3_10?.should be_false
      sec(:beta_bridge).helix3_10?.should be_false
      sec(:beta_strand).helix3_10?.should be_false
      sec(:left_handed_helix2_7).helix3_10?.should be_false
      sec(:left_handed_helix3_10).helix3_10?.should be_true
      sec(:left_handed_helix_alpha).helix3_10?.should be_false
      sec(:left_handed_helix_pi).helix3_10?.should be_false
      sec(:none).helix3_10?.should be_false
      sec(:polyproline).helix3_10?.should be_false
      sec(:right_handed_helix2_7).helix3_10?.should be_false
      sec(:right_handed_helix3_10).helix3_10?.should be_true
      sec(:right_handed_helix_alpha).helix3_10?.should be_false
      sec(:right_handed_helix_pi).helix3_10?.should be_false
      sec(:turn).helix3_10?.should be_false
    end
  end

  describe "#helix_alpha?" do
    it "tells if it's a alpha-helix regardless of handedness" do
      sec(:bend).helix_alpha?.should be_false
      sec(:beta_bridge).helix_alpha?.should be_false
      sec(:beta_strand).helix_alpha?.should be_false
      sec(:left_handed_helix2_7).helix_alpha?.should be_false
      sec(:left_handed_helix3_10).helix_alpha?.should be_false
      sec(:left_handed_helix_alpha).helix_alpha?.should be_true
      sec(:left_handed_helix_pi).helix_alpha?.should be_false
      sec(:none).helix_alpha?.should be_false
      sec(:polyproline).helix_alpha?.should be_false
      sec(:right_handed_helix2_7).helix_alpha?.should be_false
      sec(:right_handed_helix3_10).helix_alpha?.should be_false
      sec(:right_handed_helix_alpha).helix_alpha?.should be_true
      sec(:right_handed_helix_pi).helix_alpha?.should be_false
      sec(:turn).helix_alpha?.should be_false
    end
  end

  describe "#helix_pi?" do
    it "tells if it's a pi-helix regardless of handedness" do
      sec(:bend).helix_pi?.should be_false
      sec(:beta_bridge).helix_pi?.should be_false
      sec(:beta_strand).helix_pi?.should be_false
      sec(:left_handed_helix2_7).helix_pi?.should be_false
      sec(:left_handed_helix3_10).helix_pi?.should be_false
      sec(:left_handed_helix_alpha).helix_pi?.should be_false
      sec(:left_handed_helix_pi).helix_pi?.should be_true
      sec(:none).helix_pi?.should be_false
      sec(:polyproline).helix_pi?.should be_false
      sec(:right_handed_helix2_7).helix_pi?.should be_false
      sec(:right_handed_helix3_10).helix_pi?.should be_false
      sec(:right_handed_helix_alpha).helix_pi?.should be_false
      sec(:right_handed_helix_pi).helix_pi?.should be_true
      sec(:turn).helix_pi?.should be_false
    end
  end

  describe "#regular?" do
    it "tells if it's a regular secondary structure" do
      sec(:bend).regular?.should be_false
      sec(:beta_bridge).regular?.should be_true
      sec(:beta_strand).regular?.should be_true
      sec(:left_handed_helix2_7).regular?.should be_true
      sec(:left_handed_helix3_10).regular?.should be_true
      sec(:left_handed_helix_alpha).regular?.should be_true
      sec(:left_handed_helix_pi).regular?.should be_true
      sec(:none).regular?.should be_false
      sec(:polyproline).regular?.should be_true
      sec(:right_handed_helix2_7).regular?.should be_true
      sec(:right_handed_helix3_10).regular?.should be_true
      sec(:right_handed_helix_alpha).regular?.should be_true
      sec(:right_handed_helix_pi).regular?.should be_true
      sec(:turn).regular?.should be_false
    end
  end

  describe "#type" do
    it "returns secondary structure type" do
      sec(:bend).type.should eq sectype(:coil)
      sec(:beta_bridge).type.should eq sectype(:extended)
      sec(:beta_strand).type.should eq sectype(:extended)
      sec(:left_handed_helix2_7).type.should eq sectype(:extended)
      sec(:left_handed_helix3_10).type.should eq sectype(:helical)
      sec(:left_handed_helix_alpha).type.should eq sectype(:helical)
      sec(:left_handed_helix_pi).type.should eq sectype(:helical)
      sec(:none).type.should eq sectype(:coil)
      sec(:polyproline).type.should eq sectype(:extended)
      sec(:right_handed_helix2_7).type.should eq sectype(:extended)
      sec(:right_handed_helix3_10).type.should eq sectype(:helical)
      sec(:right_handed_helix_alpha).type.should eq sectype(:helical)
      sec(:right_handed_helix_pi).type.should eq sectype(:helical)
      sec(:turn).type.should eq sectype(:coil)
    end
  end
end

describe Chem::Protein::SecondaryStructureType do
  describe "#code" do
    it "returns the secondary structure type one-letter code" do
      sectype(:coil).code.should eq 'C'
      sectype(:extended).code.should eq 'E'
      sectype(:helical).code.should eq 'H'
    end
  end

  describe "#regular?" do
    it "tells if it's a regular secondary structure type" do
      sectype(:coil).regular?.should be_false
      sectype(:extended).regular?.should be_true
      sectype(:helical).regular?.should be_true
    end
  end
end

private def sec(
  name : Chem::Protein::SecondaryStructure
) : Chem::Protein::SecondaryStructure
  name
end

private def sectype(
  name : Chem::Protein::SecondaryStructureType
) : Chem::Protein::SecondaryStructureType
  name
end
