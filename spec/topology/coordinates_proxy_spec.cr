require "../spec_helper"

describe Chem::Spatial::CoordinatesProxy do
  structure = Chem::Structure.build do
    lattice 10, 10, 10

    atom PeriodicTable::O, V[1, 2, 3]
    atom PeriodicTable::H, V[4, 5, 6]
    atom PeriodicTable::H, V[7, 8, 9]
  end

  describe "#each" do
    it "yields the coordinates of every atom" do
      vecs = [] of V
      structure.coords.each { |coords| vecs << coords }
      vecs.should eq [V[1, 2, 3], V[4, 5, 6], V[7, 8, 9]]
    end

    it "yields the fractional coordinates of every atom" do
      vecs = [] of V
      structure.coords.each(fractional: true) { |fcoords| vecs << fcoords }

      expected = [V[0.1, 0.2, 0.3], V[0.4, 0.5, 0.6], V[0.7, 0.8, 0.9]]
      vecs.should be_close expected, 1e-15
    end

    it "fails for a non-periodic atom collection" do
      msg = "Cannot compute fractional coordinates for non-periodic atoms"
      expect_raises Chem::Spatial::Error, msg do
        fake_structure.coords.each(fractional: true) { }
      end
    end
  end

  describe "#map" do
    it "returns the modified atom coordinates" do
      expected = [V[2, 4, 6], V[8, 10, 12], V[14, 16, 18]]
      structure.coords.map(&.*(2)).should eq expected
    end

    it "returns the modified fractional atom coordinates" do
      expected = [V[0.2, 0.4, 0.6], V[0.8, 1.0, 1.2], V[1.4, 1.6, 1.8]]
      structure.coords.map(fractional: true, &.*(2)).should be_close expected, 1e-15
    end

    it "fails for a non-periodic atom collection" do
      msg = "Cannot compute fractional coordinates for non-periodic atoms"
      expect_raises Chem::Spatial::Error, msg do
        fake_structure.coords.map fractional: true, &.itself
      end
    end
  end

  describe "#map!" do
    it "modifies the atom coordinates" do
      other = Chem::Structure.build do
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end

      other.coords.map! &.*(2)
      other.coords.to_a.should eq [V[2, 4, 6], V[8, 10, 12], V[14, 16, 18]]
    end

    it "modifies the fractional atom coordinates" do
      other = Chem::Structure.build do
        lattice 5, 10, 15
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end
      expected = [V[6, 12, 18], V[9, 15, 21], V[12, 18, 24]]

      other.coords.map! fractional: true, &.+(1)
      other.coords.to_a.should be_close expected, 1e-12
    end

    it "fails for a non-periodic atom collection" do
      msg = "Cannot compute fractional coordinates for non-periodic atoms"
      expect_raises Chem::Spatial::Error, msg do
        fake_structure.coords.map! fractional: true, &.itself
      end
    end
  end

  describe "#transform" do
    it "returns the transformed atom coordinates" do
      transform = Tf.translation by: V[3, 2, 1]
      expected = [V[4, 4, 4], V[7, 7, 7], V[10, 10, 10]]
      structure.coords.transform(transform).should eq expected
    end
  end

  describe "#transform!" do
    it "transforms the atom coordinates" do
      other = Chem::Structure.build do
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end

      expected = [V[0, 2, 4], V[3, 5, 7], V[6, 8, 10]]
      other.coords.transform! Tf.translation by: V[-1, 0, 1]
      other.coords.to_a.should eq expected
    end
  end

  describe "#translate" do
    it "returns the translated atom coordinates" do
      expected = [V[-1, 0, 1], V[2, 3, 4], V[5, 6, 7]]
      structure.coords.translate(by: V[-2, -2, -2]).should eq expected
    end
  end

  describe "#translate!" do
    it "translates the atom coordinates" do
      other = Chem::Structure.build do
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end

      expected = [V[-2, 0, 2], V[1, 3, 5], V[4, 6, 8]]
      other.coords.translate! by: V[-3, -2, -1]
      other.coords.to_a.should eq expected
    end
  end

  describe "#to_a" do
    it "returns the coordinates of the atoms" do
      structure.coords.to_a.should eq [V[1, 2, 3], V[4, 5, 6], V[7, 8, 9]]
    end

    it "returns the fractional coordinates of the atoms" do
      expected = [V[0.1, 0.2, 0.3], V[0.4, 0.5, 0.6], V[0.7, 0.8, 0.9]]
      structure.coords.to_a(fractional: true).should be_close expected, 1e-15
    end

    it "fails for a non-periodic atom collection" do
      msg = "Cannot compute fractional coordinates for non-periodic atoms"
      expect_raises Chem::Spatial::Error, msg do
        fake_structure.coords.to_a fractional: true
      end
    end
  end

  describe "#to_cartesian!" do
    it "transforms fractional coordinates to Cartesian" do
      structure = Chem::Structure.build do
        lattice 10, 20, 30
        atom PeriodicTable::O, V[0.2, 0.4, 0.6]
        atom PeriodicTable::H, V[0.1, 0.2, 0.3]
        atom PeriodicTable::H, V[0.6, 0.9, 0.35]
      end

      expected = [V[2, 8, 18], V[1, 4, 9], V[6, 18, 10.5]]
      structure.coords.to_cartesian!
      structure.coords.to_a.should be_close expected, 1e-15
    end
  end

  describe "#to_fractional!" do
    it "transforms Cartesian coordinates to fractional" do
      structure = Chem::Structure.build do
        lattice 10, 20, 30
        atom PeriodicTable::O, V[1, 2, 3]
        atom PeriodicTable::H, V[4, 5, 6]
        atom PeriodicTable::H, V[7, 8, 9]
      end

      expected = [V[0.1, 0.1, 0.1], V[0.4, 0.25, 0.2], V[0.7, 0.4, 0.3]]
      structure.coords.to_fractional!
      structure.coords.to_a.should be_close expected, 1e-15
    end
  end
end
