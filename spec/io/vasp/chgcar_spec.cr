require "../../spec_helper"

describe Chem::VASP::Chgcar do
  it "parses a CHGCAR" do
    grid = Grid.from_chgcar "spec/data/vasp/CHGCAR"
    grid.dim.should eq({2, 2, 2})
    grid.bounds.should eq Bounds[10, 10, 10]
    grid.volume.should eq 1_000
    grid[0, 0, 0].should be_close 7.8406017013, 1e-10
    grid[-1, -1, -1].should be_close 1.0024522914, 1e-10
    grid[1, 0, 0].should be_close 7.6183317989, 1e-10
  end

  it "parses a CHGCAR header" do
    info = Grid.info "spec/data/vasp/CHGCAR", :chgcar
    info.bounds.should eq Bounds[10, 10, 10]
    info.dim.should eq({2, 2, 2})
  end

  it "writes a CHGCAR" do
    structure = Chem::Structure.build(guess_topology: false) do
      title "NaCl-O-NaCl"
      lattice 5, 10, 20
      atom :Cl, V[30, 15, 10]
      atom :Na, V[10, 5, 5]
      atom :O, V[30, 15, 9]
      atom :Na, V[10, 10, 12.5]
      atom :Cl, V[20, 10, 10]
    end

    grid = make_grid(3, 3, 3, Bounds[5, 10, 20]) { |i, j, k| i * 100 + j * 10 + k }
    grid.to_chgcar(structure).should eq <<-EOF
      NaCl-O-NaCl
         1.00000000000000
           5.0000000000000000    0.0000000000000000    0.0000000000000000
           0.0000000000000000   10.0000000000000000    0.0000000000000000
           0.0000000000000000    0.0000000000000000   20.0000000000000000
         Cl   Na   O 
           2     2     1
      Cartesian
         30.0000000000000000   15.0000000000000000   10.0000000000000000
         20.0000000000000000   10.0000000000000000   10.0000000000000000
         10.0000000000000000    5.0000000000000000    5.0000000000000000
         10.0000000000000000   10.0000000000000000   12.5000000000000000
         30.0000000000000000   15.0000000000000000    9.0000000000000000

          3    3    3
       0.00000000000E+00 0.10000000000E+06 0.20000000000E+06 0.10000000000E+05 0.11000000000E+06
       0.21000000000E+06 0.20000000000E+05 0.12000000000E+06 0.22000000000E+06 0.10000000000E+04
       0.10100000000E+06 0.20100000000E+06 0.11000000000E+05 0.11100000000E+06 0.21100000000E+06
       0.21000000000E+05 0.12100000000E+06 0.22100000000E+06 0.20000000000E+04 0.10200000000E+06
       0.20200000000E+06 0.12000000000E+05 0.11200000000E+06 0.21200000000E+06 0.22000000000E+05
       0.12200000000E+06 0.22200000000E+06

      EOF
  end

  it "fails when writing a CHGCAR with a non-periodic structure" do
    grid = make_grid 3, 3, 3, Bounds.zero
    expect_raises Chem::Spatial::NotPeriodicError do
      grid.to_chgcar Chem::Structure.new
    end
  end

  it "fails when lattice and bounds are incompatible" do
    structure = Chem::Structure.build { lattice 10, 20, 30 }
    expect_raises ArgumentError, "Incompatible structure and grid" do
      make_grid(3, 3, 3, Bounds[20, 20, 20]).to_chgcar structure
    end
  end

  it "writes numbers in Fortran scientific format (#63)" do
    grid = Grid.new({2, 1, 3}, Bounds[10, 10, 10])
    grid[0] = -0.34549298903E-04
    grid[1] = -0.73866266319E-06
    grid[2] = 0.23183335369E-04
    grid[3] = -0.34746402363E-01
    grid[4] = 0.10214454511E-02
    grid[5] = 0.20562611904E-03
    structure = Chem::Structure.build do
      title "Zn"
      lattice 10, 10, 10
      atom "Zn", V[0, 0, 0]
    end
    grid.to_chgcar(structure).should eq <<-EOF
      Zn
         1.00000000000000
          10.0000000000000000    0.0000000000000000    0.0000000000000000
           0.0000000000000000   10.0000000000000000    0.0000000000000000
           0.0000000000000000    0.0000000000000000   10.0000000000000000
         Zn
           1
      Cartesian
          0.0000000000000000    0.0000000000000000    0.0000000000000000

          2    1    3
       -.34549298903E-01 -.34746402363E+02 -.73866266319E-03 0.10214454511E+01 0.23183335369E-01
       0.20562611904E+00

      EOF
  end
end
