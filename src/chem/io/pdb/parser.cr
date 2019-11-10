module Chem::PDB
  @[IO::FileType(format: PDB, ext: [:ent, :pdb])]
  class Parser < IO::Parser
    include IO::ColumnBasedParser

    @pdb_bonds = Hash(Tuple(Int32, Int32), Int32).new 0
    @pdb_expt : Structure::Experiment?
    @pdb_lattice : Lattice?
    @pdb_seq : Protein::Sequence?
    @pdb_title = ""

    @alt_locs : Hash(Residue, Array(AlternateLocation))?
    @chains : Set(Char)?
    @offsets : Array(Tuple(Int32, Int32))?
    @seek_bonds = true
    @serial = 0
    @ss_elements = [] of SecondaryStructureElement

    def initialize(input : ::IO | Path | String,
                   @alt_loc : Char? = nil,
                   chains : Enumerable(Char)? = nil,
                   @het : Bool = true)
      super input
      @chains = chains.try &.to_set
      parse_header
    end

    def next : Structure | Iterator::Stop
      each_record do |name|
        case name
        when "atom", "hetatm"
          return parse_model
        when "model"
          next_record
          return parse_model
        when "end", "master"
          break
        end
      end
      stop
    end

    def skip_structure : Nil
      next_record if current_record == "model"
      each_record do |name|
        case name
        when "model", "conect", "end", "master"
          break
        when "endmdl"
          next_record
          break
        end
      end
    end

    private def add_offset_at(serial : Int32) : Nil
      offsets << {serial, serial - @serial - 1}
    end

    private def add_sec(type : Protein::SecondaryStructure, i : ResidueId, j : ResidueId)
      @ss_elements << SecondaryStructureElement.new type, i, j
    end

    private def alt_loc(residue : Residue, id : Char, resname : String) : AlternateLocation
      alt_loc = alt_locs[residue].find &.id.==(id)
      alt_locs[residue] << (alt_loc = AlternateLocation.new id, resname) unless alt_loc
      alt_loc
    end

    private def alt_locs : Hash(Residue, Array(AlternateLocation))
      @alt_locs ||= Hash(Residue, Array(AlternateLocation)).new do |hash, key|
        hash[key] = Array(AlternateLocation).new 4
      end
    end

    private def assign_bonds(builder : Topology::Builder) : Nil
      @pdb_bonds.each do |(i, j), order|
        builder.bond serial_to_index(i), serial_to_index(j), order
      end
    end

    private def assign_secondary_structure(builder : Topology::Builder) : Nil
      @ss_elements.each do |ele|
        builder.secondary_structure ele.start, ele.end, ele.type
      end
    end

    private def current_record : String
      read(0, 6).rstrip.downcase
    end

    private def offsets : Array(Tuple(Int32, Int32))
      @offsets ||= [] of Tuple(Int32, Int32)
    end

    private def parse_atom(builder : Topology::Builder) : Nil
      return if (chains = @chains) && !chains.includes?(read(21))
      return if @alt_loc && (alt_loc = read?(16)) && alt_loc != @alt_loc

      builder.chain read(21)
      builder.residue read(17, 4).strip, read_serial(22, 4), read?(26)
      atom = builder.atom \
        read(12, 4).strip,
        read_serial(6, 5),
        read_vector,
        element: read_element,
        formal_charge: read?(78, 2).try(&.reverse.to_i?) || 0,
        occupancy: read_float(54, 6),
        temperature_factor: read_float(60, 6)

      add_offset_at atom.serial if atom.serial - @serial > 1
      @serial = atom.serial

      if !@alt_loc && (alt_loc = read?(16))
        alt_loc(atom.residue, alt_loc, read(17, 4).strip) << atom
      end
    end

    private def parse_bonds : Nil
      i = read_serial 6, 5
      (11..).step(5).each do |start|
        if j = read_serial?(start, 5)
          @pdb_bonds[{i, j}] += 1 unless i > j # skip redundant bonds
        else
          break
        end
      end
    end

    private def parse_expt : Nil
      title = ""
      method = Structure::Experiment::Method::XRayDiffraction
      date = doi = pdbid = resolution = nil

      each_record do |name|
        case name
        when "atom", "hetatm", "cryst1", "model", "seqres", "helix", "sheet"
          back_to_beginning_of_line
          break
        when "expdta"
          raw_method = read(10, 70).split(';')[0].delete "- "
          method = Structure::Experiment::Method.parse raw_method
        when "header"
          date = Time.parse_utc read(50, 9), "%d-%^b-%y"
          pdbid = read(62, 4).downcase
        when "jrnl"
          case read(12, 4).strip.downcase
          when "doi"
            doi = read(19, 60).strip
          end
        when "remark"
          next if read(10, 70).blank? # skip remark first line
          case read_int(7, 3)
          when 2
            resolution = read_float?(23, 7)
          end
        when "title"
          title += read(10, 70).rstrip.squeeze ' '
        end
      end

      if date && pdbid
        @pdb_expt = Structure::Experiment.new title, method, resolution, pdbid, date, doi
        @pdb_title = pdbid
      else
        @pdb_title = title
      end
    end

    private def parse_header
      each_record do |name|
        case name
        when "atom", "hetatm", "model"                     then break
        when "cryst1"                                      then parse_lattice
        when "helix"                                       then parse_helix
        when "sheet"                                       then parse_sheet
        when "header", "title", "expdta", "jrnl", "remark" then parse_expt
        when "seqres"                                      then parse_sequence
        end
      end
    end

    private def parse_helix : Nil
      kind = case read_int(38, 2)
             when 1 then Protein::SecondaryStructure::HelixAlpha
             when 3 then Protein::SecondaryStructure::HelixPi
             when 5 then Protein::SecondaryStructure::Helix3_10
             else        Protein::SecondaryStructure::None
             end
      add_sec kind,
        {read(19), read_int(21, 4), read?(25)},
        {read(19), read_int(33, 4), read?(37)}
    end

    private def parse_lattice
      @pdb_lattice = Lattice.new \
        size: {read_float(6, 9), read_float(15, 9), read_float(24, 9)},
        angles: {read_float(33, 7), read_float(40, 7), read_float(47, 7)}
    end

    private def parse_model : Structure
      @serial = 0
      Structure.build do |builder|
        title @pdb_title
        lattice @pdb_lattice
        expt @pdb_expt
        seq @pdb_seq

        each_record do |name|
          case name
          when "atom"          then parse_atom builder
          when "hetatm"        then parse_atom builder if read_het?
          when "conect"        then parse_bonds if @seek_bonds
          when "model"         then seek_bonds if @seek_bonds; break
          when "master", "end" then break
          end
        end

        resolve_alternate_locations unless @alt_loc
        assign_bonds builder
        assign_secondary_structure builder
      end
    end

    private def parse_sequence : Nil
      @pdb_seq = Protein::Sequence.build do |aminoacids|
        each_record_of("seqres") do
          next if (chains = @chains) && !chains.includes?(read(11))
          read(19, 60).split.each { |name| aminoacids << Protein::AminoAcid[name] }
        end
      end
    end

    private def parse_sheet : Nil
      add_sec :beta_strand,
        {read(21), read_int(22, 4), read?(26)},
        {read(21), read_int(33, 4), read?(37)}
    end

    private def read_element : Element?
      case symbol = read?(76, 2).try(&.lstrip)
      when "D" # deuterium
        PeriodicTable::D
      when "X" # unknown, e.g., ASX
        PeriodicTable::X
      when String
        PeriodicTable[symbol]? || parse_exception "Unknown element"
      end
    end

    private def read_het? : Bool
      @het
    end

    private def read_serial(start : Int, count : Int) : Int32
      Hybrid36.decode read(start, count), count
    end

    private def read_serial?(start : Int, count : Int) : Int32?
      if str = read?(start, count)
        Hybrid36.decode str, count
      end
    end

    private def read_vector : Spatial::Vector
      Spatial::Vector.new read_float(30, 8), read_float(38, 8), read_float(46, 8)
    end

    private def resolve_alternate_locations : Nil
      return unless table = @alt_locs
      table.each do |residue, alt_locs|
        alt_locs.sort! { |a, b| b.occupancy <=> a.occupancy }
        alt_locs.each(within: 1..) do |alt_loc|
          alt_loc.each_atom do |atom|
            unless @pdb_bonds.empty?
              i = offsets.bsearch_index { |(i, _)| i > atom.serial } || -1
              offsets.insert i, {atom.serial, 1}
            end
            residue.delete atom
          end
        end
        residue.name = alt_locs[0].resname
        residue.reset_cache
      end
      table.clear
    end

    private def seek_bonds
      read_context do
        @io.seek 0, ::IO::Seek::End
        each_record_reversed do |name|
          case name
          when "conect"
            parse_bonds
          when "atom", "hetatm", "endmdl", "ter"
            break
          end
        end
      end
      @seek_bonds = false
    end

    private def serial_to_index(serial : Int32) : Int32
      index = serial - 1
      offsets.each do |loc, offset|
        break if loc > serial
        index -= offset
      end
      index
    end

    private alias ResidueId = Tuple(Char, Int32, Char?)

    private struct AlternateLocation
      getter id : Char
      getter resname : String

      def initialize(@id : Char, @resname : String)
        @atoms = [] of Atom
      end

      def <<(atom : Atom) : self
        @atoms << atom
        self
      end

      def each_atom(&block : Atom ->) : Nil
        @atoms.each do |atom|
          yield atom
        end
      end

      def occupancy : Float64
        @atoms.sum(&.occupancy) / @atoms.size
      end
    end

    private record SecondaryStructureElement,
      type : Protein::SecondaryStructure,
      start : ResidueId,
      end : ResidueId
  end
end