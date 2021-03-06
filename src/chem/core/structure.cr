module Chem
  class Structure
    include AtomCollection
    include ChainCollection
    include ResidueCollection

    @chain_table = {} of Char => Chain
    @chains = [] of Chain

    getter biases = [] of Chem::Bias
    property experiment : Structure::Experiment?
    property lattice : Lattice?
    property sequence : Protein::Sequence?
    property title : String = ""

    delegate :[], :[]?, to: @chain_table

    def self.build(guess_topology : Bool = true, &) : self
      builder = Structure::Builder.new guess_topology: guess_topology
      with builder yield builder
      builder.build
    end

    def self.read(path : Path | String, guess_topology : Bool = true) : self
      format = IO::FileFormat.from_filename File.basename(path)
      read path, format, guess_topology
    end

    def self.read(input : ::IO | Path | String,
                  format : IO::FileFormat | String,
                  guess_topology : Bool = true) : self
      format = IO::FileFormat.parse format if format.is_a?(String)
      {% begin %}
        case format
        {% for parser in Parser.subclasses.select(&.annotation(IO::FileType)) %}
          {% format = parser.annotation(IO::FileType)[:format].id.underscore %}
          when .{{format.id}}?
            from_{{format.id}} input, guess_topology: guess_topology
        {% end %}
        else
          raise "No structure parser associated with file format #{format}"
        end
      {% end %}
    end

    protected def <<(chain : Chain) : self
      @chains << chain
      @chain_table[chain.id] = chain
      self
    end

    def clear : self
      @chain_table.clear
      @chains.clear
      self
    end

    # Returns a deep copy of `self`, that is, every chain/residue/atom is copied.
    #
    # Unlike array-like classes in the language, `#dup` (shallow copy) is not possible.
    #
    # ```
    # structure = Structure.new "/path/to/file.pdb"
    # other = structure.clone
    # other == structure     # => true
    # other.same?(structure) # => false
    #
    # structure.dig('A', 23, "OG").partial_charge         # => 0.0
    # other.dig('A', 23, "OG").partial_charge             # => 0.0
    # structure.dig('A', 23, "OG").partial_charge = 0.635 # => 0.635
    # other.dig('A', 23, "OG").partial_charge             # => 0.0
    # ```
    def clone : self
      structure = Structure.new
      structure.biases.concat @biases
      structure.experiment = @experiment
      structure.lattice = @lattice
      structure.sequence = @sequence
      structure.title = @title
      each_chain &.copy_to(structure)
      bonds.each do |bond|
        a, b = bond
        a = structure.dig a.chain.id, a.residue.number, a.residue.insertion_code, a.name
        b = structure.dig b.chain.id, b.residue.number, b.residue.insertion_code, b.name
        a.bonds.add b, order: bond.order
      end
      structure
    end

    def coords : Spatial::CoordinatesProxy
      Spatial::CoordinatesProxy.new self, @lattice
    end

    def delete(ch : Chain) : Chain?
      ch = @chains.delete ch
      @chain_table.delete(ch.id) if ch && @chain_table[ch.id]?.same?(ch)
      ch
    end

    def dig(id : Char) : Chain
      self[id]
    end

    def dig(id : Char, *subindexes)
      self[id].dig *subindexes
    end

    def dig?(id : Char) : Chain?
      self[id]?
    end

    def dig?(id : Char, *subindexes)
      if chain = self[id]?
        chain.dig? *subindexes
      end
    end

    def each_atom : Iterator(Atom)
      iterators = [] of Iterator(Atom)
      each_chain do |chain|
        chain.each_residue do |residue|
          iterators << residue.each_atom
        end
      end
      Iterator.chain iterators
    end

    def each_atom(&block : Atom ->)
      @chains.each do |chain|
        chain.each_atom do |atom|
          yield atom
        end
      end
    end

    def each_chain : Iterator(Chain)
      @chains.each
    end

    def each_chain(&block : Chain ->)
      @chains.each do |chain|
        yield chain
      end
    end

    def each_residue : Iterator(Residue)
      Iterator.chain each_chain.map(&.each_residue).to_a
    end

    def each_residue(&block : Residue ->)
      @chains.each do |chain|
        chain.each_residue do |residue|
          yield residue
        end
      end
    end

    def empty?
      size == 0
    end

    def inspect(io : ::IO)
      to_s io
    end

    def n_atoms : Int32
      each_chain.sum &.n_atoms
    end

    def n_chains : Int32
      @chains.size
    end

    def n_residues : Int32
      each_chain.sum &.n_residues
    end

    def periodic? : Bool
      !!@lattice
    end

    def to_s(io : ::IO)
      io << "<Structure"
      io << " " << title.inspect unless title.blank?
      io << ": "
      io << n_atoms << " atoms"
      io << ", " << n_residues << " residues" if n_residues > 1
      io << ", "
      io << "non-" unless @lattice
      io << "periodic>"
    end

    def unwrap : self
      raise Spatial::NotPeriodicError.new unless lattice = @lattice
      Spatial::PBC.unwrap self, lattice
      self
    end

    def write(path : Path | String) : Nil
      format = IO::FileFormat.from_filename path
      write path, format
    end

    def write(output : ::IO | Path | String, format : IO::FileFormat | String) : Nil
      format = IO::FileFormat.parse format if format.is_a?(String)
      {% begin %}
        case format
        {% for writer in IO::Writer.all_subclasses.select(&.annotation(IO::FileType)) %}
          {% if (type = writer.superclass.type_vars[0]) && type <= AtomCollection %}
            {% format = writer.annotation(IO::FileType)[:format].id.underscore %}
            when .{{format.id}}?
              to_{{format.id}} output
          {% end %}
        {% end %}
        else
          raise "No structure writer associated with file format #{format}"
        end
      {% end %}
    end

    protected def reset_cache : Nil
      @chain_table.clear
      @chains.sort_by! &.id
      @chains.each do |chain|
        @chain_table[chain.id] = chain
      end
    end
  end
end
