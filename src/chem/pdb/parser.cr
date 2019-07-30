require "../topology/templates/all"
require "./helpers"
require "./record"
require "./record/*"

module Chem::PDB
  @[IO::FileType(format: PDB, ext: [:ent, :pdb])]
  class Parser < IO::Parser
    private alias BondTable = Hash(Int32, Hash(Int32, Int32))

    @pdb_bonds = uninitialized BondTable
    @pdb_expt : Protein::Experiment?
    @pdb_has_hydrogens = false
    @pdb_lattice : Lattice?
    @pdb_models = 1
    @pdb_seq : Protein::Sequence?
    @pdb_title = ""

    @chains : Set(Char)?
    @segments = [] of SecondaryStructureSegment
    @use_hex_numbers = {:atom_serial => false, :residue_number => false}

    def initialize(@io : ::IO, chains : Enumerable(Char)? = nil)
      @iter = Record::Iterator.new @io
      @chains = chains.try &.to_set
    end

    private def assign_bonds(to atoms : Hash(Int32, Atom))
      @pdb_bonds.each do |serial, bond_table|
        next unless atoms.has_key? serial
        bond_table.each do |other, order|
          next unless atoms.has_key? other
          atoms[serial].bonds.add atoms[other], order
        end
      end
    end

    private def assign_secondary_structure(to sys : Structure)
      chains = sys.chains
      @segments.each do |seg|
        next unless chain = chains[seg.chain]?
        chain.each_residue.each do |res|
          pos = {res.number, res.insertion_code || ' '}
          next if pos < seg.start_pos || pos > seg.end_pos
          res.secondary_structure = seg.kind
        end
      end
    end

    def each_structure(&block : Structure ->)
      parse_header
      parse_bonds
      @iter.each do |rec|
        case rec.name
        when "atom", "hetatm"
          @iter.back
          yield parse_model
        when "model", "endmdl"
          next
        else
          ::Iterator.stop
        end
      end
    end

    def each_structure(indexes : Indexable(Int), &block : Structure ->)
      return if indexes.empty?
      indexes = indexes.to_a.sort!

      parse_header
      parse_bonds
      @iter.each do |rec|
        case rec.name
        when "atom", "hetatm"
          @iter.back
          yield parse_model
        when "endmdl"
          indexes.shift
          return if indexes.empty?
        when "model"
          unless indexes.includes? rec[10..13].to_i
            @iter.skip "atom", "anisou", "endmdl", "hetatm", "ter", "sigatm", "siguij"
          end
        else
          ::Iterator.stop
        end
      end
    end

    private def guess_atom_serial(prev_atom : Atom?) : Int32
      prev_atom ? prev_atom.serial + 1 : Int32::MIN
    end

    private def guess_residue_number(prev_residue : Residue?, resname : String) : Int32
      return Int32::MIN unless prev_residue

      next_number = prev_residue.number
      if prev_residue.name == resname
        if template = Topology::Templates[resname]?
          count = template.atom_count include_hydrogens: @pdb_has_hydrogens
          next_number += 1 unless prev_residue.n_atoms < count
        end
      else
        next_number += 1
      end
      next_number
    end

    private def make_structure : Structure
      sys = Structure.new
      sys.experiment = @pdb_expt
      sys.lattice = @pdb_lattice
      sys.sequence = @pdb_seq
      sys.title = @pdb_title
      sys
    end

    def parse : Structure
      parse_header
      parse_bonds
      @iter.each do |rec|
        case rec.name
        when "atom", "hetatm"
          @iter.back
          return parse_model
        end
      end
      make_structure
    end

    private def parse_atom(residue : Residue, prev_atom : Atom?, rec : Record) : Atom
      Atom.new \
        name: rec[12..15].delete(' '),
        serial: parse_atom_serial(rec[6..10]) || guess_atom_serial(prev_atom),
        coords: Spatial::Vector.new(rec[30..37].to_f, rec[38..45].to_f, rec[46..53].to_f),
        residue: residue,
        alt_loc: rec[16]?,
        element: parse_element(rec, residue.name),
        formal_charge: rec[78..79]?.try(&.reverse.to_i?) || 0,
        occupancy: rec[54..59].to_f,
        temperature_factor: rec[60..65].to_f
    end

    private def parse_atom_serial(str : String) : Int32?
      number = str.to_i? base: @use_hex_numbers[:atom_serial] ? 16 : 10
      @use_hex_numbers[:atom_serial] = number >= 99999 if number
      number
    end

    private def parse_bonds
      last_pos = @io.pos
      @io.seek 0, ::IO::Seek::End

      @pdb_bonds = BondTable.new { |hash, key| hash[key] = Hash(Int32, Int32).new 0 }
      Record::BackwardIterator.new(@io).each do |rec|
        case rec.name
        when "conect"
          serial = rec[6..10].to_i
          {11..15, 16..20, 21..25, 26..30}.each do |range|
            if other = rec[range]?.try(&.to_i)
              next if serial > other # skip redundant bonds
              @pdb_bonds[serial][other] += 1
              @pdb_bonds[other][serial] += 1
            else
              break
            end
          end
        when "end", "master"
          next
        else
          ::Iterator.stop
        end
      end

      @io.pos = last_pos
    end

    private def parse_chain(sys : Structure, prev_chain : Chain?, rec : Record) : Chain?
      chain_id = rec[21]
      return if (chains = @chains) && !chains.includes?(chain_id)
      sys[chain_id]? || Chain.new chain_id, sys
    end

    private def parse_element(rec : Record, resname : String) : PeriodicTable::Element?
      case symbol = rec[76..77]?.try(&.lstrip)
      when "D" # deuterium
        PeriodicTable::D
      when "X"
        PeriodicTable::N_or_O if resname == "ASX"
      when String
        PeriodicTable[symbol]?
      end
    end

    private def parse_header
      expt_b = ExperimentBuilder.new
      @iter.each do |rec|
        case rec.name
        when "atom", "hetatm", "model" then ::Iterator.stop
        when "cryst1"                  then @pdb_lattice = parse_lattice rec
        when "helix"                   then @segments << parse_helix rec
        when "nummdl"                  then @pdb_models = rec[10..13].to_i
        when "sheet"                   then @segments << parse_sheet rec
        when "seqres"
          @iter.back
          @pdb_seq = parse_sequence
        when "expdta"
          expt_b.kind = Protein::Experiment::Kind.parse(rec[10..79].delete "- ")
        when "header"
          expt_b.deposition_date = Time.parse_utc rec[50..58], "%d-%^b-%y"
          expt_b.pdb_accession = rec[62..65].downcase
        when "jrnl"
          case rec[12..15].delete(' ').downcase
          when "doi"
            expt_b.doi = rec[19..79].delete ' '
          end
        when "remark"
          next if rec[10..79].blank? # skip remark first line
          case rec[7..9].to_i
          when 2
            expt_b.resolution = rec[23..29].to_f?
          end
        when "title"
          @pdb_title += rec[10..79].rstrip.squeeze ' '
          expt_b.title = @pdb_title
        end
      end
      @pdb_expt = expt_b.build?
      @pdb_title = @pdb_expt.try(&.pdb_accession) || @pdb_title
    end

    private def parse_helix(rec : Record)
      kind = case rec[38..39].to_i
             when 1 then Protein::SecondaryStructure::HelixAlpha
             when 3 then Protein::SecondaryStructure::HelixPi
             when 5 then Protein::SecondaryStructure::Helix3_10
             else        Protein::SecondaryStructure::None
             end
      SecondaryStructureSegment.new \
        kind: kind,
        chain: rec[19],
        start_pos: {rec[21..24].to_i, rec[25]},
        end_pos: {rec[33..36].to_i, rec[37]}
    end

    private def parse_lattice(rec : Record)
      @lattice = Lattice.new \
        size: {rec[6..14].to_f, rec[15..23].to_f, rec[24..32].to_f},
        angles: {rec[33..39].to_f, rec[40..46].to_f, rec[47..53].to_f},
        space_group: rec[55..65].rstrip
    end

    private def parse_model : Structure
      make_structure.tap do |structure|
        bonded_atoms = Hash(Int32, Atom).new initial_capacity: @pdb_bonds.size
        chain, residue, atom = nil, nil, nil
        @iter.each do |rec|
          case rec.name
          when "atom", "hetatm"
            chain = parse_chain structure, chain, rec
            next unless chain
            residue = parse_residue chain, residue, rec
            atom = parse_atom residue, atom, rec
            bonded_atoms[atom.serial] = atom if @pdb_bonds.has_key? atom.serial
            @pdb_has_hydrogens = true if atom.element.hydrogen?
          when "anisou", "ter", "sigatm", "siguij"
            next
          else
            ::Iterator.stop
          end
        end
        assign_bonds to: bonded_atoms
        assign_secondary_structure to: structure
      end
    end

    private def parse_residue(chain : Chain,
                              prev_res : Residue?,
                              rec : Record) : Residue
      name = rec[17..20].delete ' '
      number = parse_residue_number(rec[22..25]) || guess_residue_number(prev_res, name)
      ins_code = rec[26]?

      if residue = chain[number, ins_code]?
        if (alt_loc = rec[16]?) && !residue.conformations[alt_loc]?
          residue.conformations.add name, alt_loc, rec[54..59].to_f
        end
        residue
      else
        residue = Residue.new name, number, ins_code, chain
        if res_t = Topology::Templates[name]?
          residue.kind = Residue::Kind.from_value res_t.kind.to_i
        end
        residue
      end
    end

    private def parse_residue_number(str : String) : Int32?
      base = @use_hex_numbers[:residue_number] && str != "9999" ? 16 : 10
      number = str.to_i? base
      @use_hex_numbers[:residue_number] = number >= 9999 if number
      number
    end

    private def parse_sequence : Protein::Sequence
      Protein::Sequence.build do |aminoacids|
        @iter.each do |rec|
          case rec.name
          when "seqres"
            next if (chains = @chains) && !chains.includes?(rec[11])
            rec[19..79].split.each { |name| aminoacids << Protein::AminoAcid[name] }
          else
            ::Iterator.stop
          end
        end
      end
    end

    private def parse_sheet(rec : Record) : SecondaryStructureSegment
      SecondaryStructureSegment.new \
        kind: Protein::SecondaryStructure::BetaStrand,
        chain: rec[21],
        start_pos: {rec[22..25].to_i, rec[26]},
        end_pos: {rec[33..36].to_i, rec[37]}
    end
  end
end
