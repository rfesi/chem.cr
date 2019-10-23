require "../spec_helper.cr"

describe Chem::VASP::Poscar do
  describe ".parse" do
    it "parses a basic file" do
      st = Chem::Structure.read "spec/data/poscar/basic.poscar"
      st.n_atoms.should eq 49

      st.atoms.count(&.element.symbol.==("C")).should eq 14
      st.atoms.count(&.element.symbol.==("H")).should eq 21
      st.atoms.count(&.element.symbol.==("N")).should eq 7
      st.atoms.count(&.element.symbol.==("O")).should eq 7

      atom = st.atoms[-1]
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

      st.atoms[0].element.carbon?.should be_true
      st.atoms[14].element.hydrogen?.should be_true
      st.atoms[35].element.nitrogen?.should be_true
    end

    it "parses a file with direct coordinates" do
      st = Chem::Structure.read "spec/data/poscar/direct.poscar"
      st.atoms[0].coords.should eq Vector.origin
      st.atoms[1].coords.should be_close Vector[1.0710, 1.6065, 1.2495], 1e-15
    end

    it "parses a file with scaled Cartesian coordinates" do
      st = Chem::Structure.read "spec/data/poscar/cartesian.poscar"
      st.atoms[0].coords.should eq Vector.origin
      st.atoms[1].coords.should be_close Vector[0.8925, 0.8925, 0.8925], 1e-16
    end

    it "parses a file with selective dynamics" do
      st = Chem::Structure.read "spec/data/poscar/selective_dynamics.poscar"
      st.atoms[0].constraint.should eq Constraint::Z
      st.atoms[1].constraint.should eq Constraint::XYZ
      st.atoms[2].constraint.should eq Constraint::Z
    end

    it "fails when element symbols are missing" do
      msg = "Expected element symbols (vasp 5+)"
      ex = expect_raises(Chem::IO::ParseException) do
        Chem::Structure.read "spec/data/poscar/no_symbols.poscar"
      end
      ex.to_s_with_location.should eq <<-EOS
        In line 6:4:

         4 |  0.5 0.0 0.5
         5 |  0.5 0.5 0.0
         6 |    1 1
                ^
        Error: Expected element symbols (vasp 5+)
        EOS
    end

    it "fails when there are missing atomic species counts" do
      ex = expect_raises(Chem::IO::ParseException) do
        Chem::Structure.read "spec/data/poscar/mismatch.poscar"
      end
      ex.to_s_with_location.should eq <<-EOS
        In line 7:5:
        
         5 |  0.5 0.5 0.0
         6 |    C N
         7 |    1
                 ^
        Error: Expected 1 more number(s) of atoms per atomic species
        EOS
    end

    it "fails when constraint flags are invalid" do
      ex = expect_raises Chem::IO::ParseException do
        Chem::Structure.from_poscar <<-EOS
          Cubic BN
          3.57
            0.0 0.5 0.5
            0.5 0.0 0.5
            0.5 0.5 0.0
          O H
          1 1
          Selective dynamics
          Direct
            0.00 0.00 0.00 T T T
            0.25 0.25 0.25 A T F
          EOS
      end
      ex.to_s_with_location.should eq <<-EOS
        In line 11:18:
        
          9 | Direct
         10 |   0.00 0.00 0.00 T T T
         11 |   0.25 0.25 0.25 A T F
                               ^
        Error: Invalid boolean flag (expected either T or F)
        EOS
    end
  end
end

describe Chem::VASP::Poscar::Builder do
  structure = Chem::Structure.build do
    title "NaCl-O-NaCl"
    lattice 40, 20, 10
    atom :Cl, V[30, 15, 10]
    atom :Na, V[10, 5, 5]
    atom :O, V[30, 15, 9]
    atom :Na, V[10, 10, 12.5]
    atom :Cl, V[20, 10, 10]
  end

  it "writes a structure in cartesian coordinates" do
    structure.to_poscar.should eq <<-EOS
      NaCl-O-NaCl
         1.00000000000000
          40.0000000000000000    0.0000000000000000    0.0000000000000000
           0.0000000000000000   20.0000000000000000    0.0000000000000000
           0.0000000000000000    0.0000000000000000   10.0000000000000000
         Cl   Na   O 
           2     2     1
      Cartesian
         30.0000000000000000   15.0000000000000000   10.0000000000000000
         20.0000000000000000   10.0000000000000000   10.0000000000000000
         10.0000000000000000    5.0000000000000000    5.0000000000000000
         10.0000000000000000   10.0000000000000000   12.5000000000000000
         30.0000000000000000   15.0000000000000000    9.0000000000000000\n
      EOS
  end

  it "writes a structure in the specified element order" do
    elements = ["O", "Na", "Cl"].map { |ele| PeriodicTable[ele] }
    structure.to_poscar(order: elements).should eq <<-EOS
      NaCl-O-NaCl
         1.00000000000000
          40.0000000000000000    0.0000000000000000    0.0000000000000000
           0.0000000000000000   20.0000000000000000    0.0000000000000000
           0.0000000000000000    0.0000000000000000   10.0000000000000000
         O    Na   Cl
           1     2     2
      Cartesian
         30.0000000000000000   15.0000000000000000    9.0000000000000000
         10.0000000000000000    5.0000000000000000    5.0000000000000000
         10.0000000000000000   10.0000000000000000   12.5000000000000000
         30.0000000000000000   15.0000000000000000   10.0000000000000000
         20.0000000000000000   10.0000000000000000   10.0000000000000000\n
      EOS
  end

  it "writes a structure in fractional coordinates" do
    structure.to_poscar(fractional: true).should eq <<-EOS
      NaCl-O-NaCl
         1.00000000000000
          40.0000000000000000    0.0000000000000000    0.0000000000000000
           0.0000000000000000   20.0000000000000000    0.0000000000000000
           0.0000000000000000    0.0000000000000000   10.0000000000000000
         Cl   Na   O 
           2     2     1
      Direct
          0.7500000000000000    0.7500000000000000    1.0000000000000000
          0.5000000000000000    0.5000000000000000    1.0000000000000000
          0.2500000000000000    0.2500000000000000    0.5000000000000000
          0.2500000000000000    0.5000000000000000    1.2500000000000000
          0.7500000000000000    0.7500000000000000    0.9000000000000000\n
      EOS
  end

  it "writes a structure in fractional coordinates (wrapped)" do
    structure.to_poscar(fractional: true, wrap: true).should eq <<-EOS
      NaCl-O-NaCl
         1.00000000000000
          40.0000000000000000    0.0000000000000000    0.0000000000000000
           0.0000000000000000   20.0000000000000000    0.0000000000000000
           0.0000000000000000    0.0000000000000000   10.0000000000000000
         Cl   Na   O 
           2     2     1
      Direct
          0.7500000000000000    0.7500000000000000    1.0000000000000000
          0.5000000000000000    0.5000000000000000    1.0000000000000000
          0.2500000000000000    0.2500000000000000    0.5000000000000000
          0.2500000000000000    0.5000000000000000    0.2500000000000000
          0.7500000000000000    0.7500000000000000    0.9000000000000000\n
      EOS
  end

  it "writes a structure having constraints" do
    structure.atoms[0].constraint = Constraint::XYZ
    structure.atoms[3].constraint = Constraint::XZ
    structure.to_poscar.should eq <<-EOS
      NaCl-O-NaCl
         1.00000000000000
          40.0000000000000000    0.0000000000000000    0.0000000000000000
           0.0000000000000000   20.0000000000000000    0.0000000000000000
           0.0000000000000000    0.0000000000000000   10.0000000000000000
         Cl   Na   O 
           2     2     1
      Selective dynamics
      Cartesian
         30.0000000000000000   15.0000000000000000   10.0000000000000000   F   F   F
         20.0000000000000000   10.0000000000000000   10.0000000000000000   T   T   T
         10.0000000000000000    5.0000000000000000    5.0000000000000000   T   T   T
         10.0000000000000000   10.0000000000000000   12.5000000000000000   F   T   F
         30.0000000000000000   15.0000000000000000    9.0000000000000000   T   T   T\n
      EOS
  end

  it "fails with non-periodic structures" do
    expect_raises Chem::Spatial::NotPeriodicError do
      Chem::Structure.new.to_poscar
    end
  end

  it "fails when there is a missing element in the specified order" do
    expect_raises Chem::Error, "Missing Cl in element order" do
      structure.to_poscar order: [PeriodicTable::H]
    end
  end
end
