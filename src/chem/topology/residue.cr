module Chem
  class Residue
    include AtomCollection

    @atoms = [] of Atom

    property chain : Chain
    property name : String
    property next : Residue?
    property number : Int32
    property previous : Residue?
    property secondary_structure : Protein::SecondaryStructure = :none

    def initialize(@name : String, @number : Int32, @chain : Chain)
    end

    def <<(atom : Atom)
      @atoms << atom
    end

    delegate dssp, to: @secondary_structure

    def bonded?(other : self) : Bool
      each_atom.any? do |a1|
        other.each_atom.any? { |a2| a1.bonded? to: a2 }
      end
    end

    def each_atom : Iterator(Atom)
      @atoms.each
    end

    def make_atom(**options) : Atom
      options = options.merge({residue: self})
      atom = Atom.new **options
      self << atom
      atom
    end

    def omega : Float64
      if (prev_res = previous) && bonded?(prev_res)
        Spatial.dihedral prev_res.atoms["CA"], prev_res.atoms["C"], atoms["N"],
          atoms["CA"]
      else
        raise Error.new "#{self} is terminal"
      end
    end

    def phi : Float64
      if (prev_res = previous) && bonded?(prev_res)
        Spatial.dihedral prev_res.atoms["C"], atoms["N"], atoms["CA"], atoms["C"]
      else
        raise Error.new "#{self} is terminal"
      end
    end

    def psi : Float64
      if (next_res = self.next) && bonded?(next_res)
        Spatial.dihedral atoms["N"], atoms["CA"], atoms["C"], next_res.atoms["N"]
      else
        raise Error.new "#{self} is terminal"
      end
    end

    def to_s(io : ::IO)
      io << chain.id
      io << ':'
      io << @name
      io << @number
    end
  end
end
