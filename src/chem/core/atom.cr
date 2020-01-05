module Chem
  # TODO rename `charge` to `formal_charge`
  # TODO add `partial_charge : Float64 = 0.0`
  # TODO add `residue_index` that starts from 0 and does not reset per chain
  class Atom
    getter bonds : BondArray { BondArray.new self }
    property constraint : Constraint?
    property coords : Spatial::Vector
    property element : Element
    property formal_charge : Int32 = 0
    property name : String
    property occupancy : Float64 = 1
    property partial_charge : Float64 = 0.0
    property residue : Residue
    property serial : Int32
    property temperature_factor : Float64 = 0

    delegate x, y, z, to: @coords
    delegate chain, to: @residue
    delegate atomic_number, covalent_radius, mass, max_valency, vdw_radius, to: @element

    def initialize(@name : String,
                   @serial : Int32,
                   @coords : Spatial::Vector,
                   @residue : Residue,
                   element : Element? = nil,
                   @formal_charge : Int32 = 0,
                   @occupancy : Float64 = 1,
                   @partial_charge : Float64 = 0.0,
                   @temperature_factor : Float64 = 0)
      @element = element || PeriodicTable[atom_name: @name]
      @residue << self
    end

    def bonded?(to other : self) : Bool
      !bonds[other]?.nil?
    end

    def bonded_atoms : Array(Atom)
      bonds.map &.other(self)
    end

    def inspect(io : ::IO)
      io << "<Atom "
      to_s io
      io << ">"
    end

    def missing_valency : Int32
      (nominal_valency - valency).clamp 0..
    end

    def nominal_valency : Int32
      @element.valencies.find(&.>=(valency)) || max_valency
    end

    def residue=(new_res : Residue) : Residue
      @residue.delete self
      @residue = new_res
      new_res << self
    end

    def to_s(io : ::IO)
      io << @residue
      io << ':' << @name << '(' << @serial << ')'
    end

    def valency : Int32
      if element.ionic?
        @element.max_valency
      else
        bonds.sum(&.order) - @formal_charge
      end
    end

    # NOTE: The additional term (0.3 Å) is taken from the covalent radii reference,
    # which states that about 96% of the surveyed bonds are within three standard
    # deviations of the sum of the radii, where the found average standard deviation is
    # about 0.1 Å.
    def within_covalent_distance?(of other : Atom) : Bool
      threshold = covalent_radius + other.covalent_radius + 0.3
      Spatial.squared_distance(@coords, other.coords) <= threshold**2
    end
  end
end
