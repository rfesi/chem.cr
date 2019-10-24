require "../templates/all"

module Chem
  class Lattice::Builder
    @lattice : Lattice = Lattice[0, 0, 0]

    def self.build : Lattice
      builder = new
      with builder yield builder
      builder.build
    end

    def a(value : Number)
      a Spatial::Vector[value.to_f, 0, 0]
    end

    def a(vector : Spatial::Vector)
      @lattice.a = vector
    end

    def b(value : Number)
      b Spatial::Vector[0, value.to_f, 0]
    end

    def b(vector : Spatial::Vector)
      @lattice.b = vector
    end

    def build : Lattice
      @lattice
    end

    def c(value : Number)
      c Spatial::Vector[0, 0, value.to_f]
    end

    def c(vector : Spatial::Vector)
      @lattice.c = vector
    end
  end

  class Structure::Builder
    @aromatic_bonds : Array(Bond)?
    @atom_serial : Int32 = 0
    @atoms : Indexable(Atom)?
    @chain : Chain?
    @residue : Residue?
    @structure : Structure

    def initialize(structure : Structure? = nil)
      if structure
        @structure = structure
        @chain = structure.each_chain.last
        @residue = structure.each_residue.last
        @atom_serial = structure.each_atom.max_of &.serial
      else
        @structure = Structure.new
      end
    end

    def self.build(structure : Structure? = nil) : Structure
      builder = new structure
      with builder yield builder
      builder.build
    end

    def atom(coords : Spatial::Vector, **options) : Atom
      atom :C, coords, **options
    end

    def atom(element : PeriodicTable::Element | Symbol, coords : Spatial::Vector, **options) : Atom
      element = PeriodicTable[element.to_s.capitalize] if element.is_a?(Symbol)
      id = residue.each_atom.count(&.element.==(element)) + 1
      atom "#{element.symbol}#{id}", coords, **options.merge(element: element)
    end

    def atom(name : String, coords : Spatial::Vector, **options) : Atom
      Atom.new name, (@atom_serial += 1), coords, residue, **options
    end

    def atom(name : String, serial : Int32, coords : Spatial::Vector, **options) : Atom
      @atom_serial = serial
      Atom.new name, @atom_serial, coords, residue, **options
    end

    def bond(name : String, other : String, order : Int = 1) : Bond
      atom!(name).bonds.add atom!(other), order
    end

    def bond(i : Int, j : Int, order : Int = 1, aromatic : Bool = false) : Bond
      bond = atoms[i].bonds.add atoms[j], order
      aromatic_bonds << bond if aromatic
      bond
    end

    def build : Structure
      transform_aromatic_bonds
      @structure
    end

    def chain : Chain
      @chain ||= next_chain
    end

    def chain(& : self ->) : Nil
      @chain = next_chain
      with self yield self
    end

    def chain(id : Char) : Chain
      @chain = @structure[id]? || Chain.new(id, @structure)
    end

    def chain(id : Char, & : self ->) : Nil
      chain id
      with self yield self
    end

    def lattice : Lattice?
      @structure.lattice
    end

    def lattice! : Lattice
      @structure.lattice || raise Spatial::NotPeriodicError.new
    end

    def lattice(a : Spatial::Vector, b : Spatial::Vector, c : Spatial::Vector) : Lattice
      @structure.lattice = Lattice.new a, b, c
    end

    def lattice(a : Number, b : Number, c : Number) : Lattice
      @structure.lattice = Lattice.orthorombic a.to_f, b.to_f, c.to_f
    end

    def residue : Residue
      @residue || next_residue
    end

    def residue(name : String) : Residue
      @residue = next_residue name
    end

    def residue(name : String, & : self ->) : Nil
      residue name
      with self yield self
    end

    def residue(name : String, number : Int32, inscode : Char? = nil) : Residue
      @residue = chain[number, inscode]? || begin
        residue = Residue.new(name, number, inscode, chain)
        if res_t = Topology::Templates[name]?
          residue.kind = Residue::Kind.from_value res_t.kind.to_i
        end
        residue
      end
    end

    def residue(name : String, number : Int32, inscode : Char? = nil, & : self ->) : Nil
      residue name, number, inscode
      with self yield self
    end

    def secondary_structure(i : Tuple(Char, Int32, Char?),
                            j : Tuple(Char, Int32, Char?),
                            type : Protein::SecondaryStructure) : Nil
      return unless (ri = @structure.dig?(*i)) && (rj = @structure.dig?(*j))
      secondary_structure ri, rj, type
    end

    def secondary_structure(ri : Residue, rj : Residue, type : Protein::SecondaryStructure)
      loop do
        ri.secondary_structure = type
        break unless ri != rj && (ri = ri.next)
      end
    end

    def title(title : String)
      @structure.title = title
    end

    private def aromatic_bonds : Array(Bond)
      @aromatic_bonds ||= Array(Bond).new
    end

    private def atom!(name : String) : Atom
      if residue = @residue
        residue.each_atom do |atom|
          return atom if atom.name == name
        end
      end
      raise "Unknown atom #{name.inspect}"
    end

    private def atoms : Indexable(Atom)
      @atoms ||= @structure.atoms
    end

    private def next_chain : Chain
      chain (@chain.try(&.id) || 64.chr).succ
    end

    private def next_residue(name : String = "UNK") : Residue
      residue name, (chain.each_residue.max_of?(&.number) || 0) + 1
    end

    private def transform_aromatic_bonds : Nil
      return unless bonds = @aromatic_bonds
      bonds.sort_by! { |bond| Math.min bond[0].serial, bond[1].serial }
      until bonds.empty?
        bond = bonds.shift
        if other = bonds.find { |b| b.includes?(bond[0]) || b.includes?(bond[1]) }
          bonds.delete other
          (bond[1] != other[0] ? bond : other).order = 2
        end
      end
    end
  end
end
