require "./templates/all"

class Chem::Topology::Perception
  MAX_CHAINS = 62 # chain id is alphanumeric: A-Z, a-z or 0-9

  def initialize(@structure : Structure)
  end

  def guess_bonds : Nil
    guess_bonds @structure
  end

  # Guesses residues from existing bonds.
  #
  # Atoms are split in fragments, where each fragment is mapped to a list of residues.
  # Then, fragments are divided into polymers (e.g., peptide) and non-polymer
  # fragments (e.g., water), where residues assigned to the latter are grouped
  # together by their kind (i.e., protein, ion, solvent, etc.). Finally, polymer
  # fragments and residues grouped by kind are assigned to their own unique chain as
  # long as there are less residue groups than the chain limit (62), otherwise all
  # residues are assigned to the same chain.
  def guess_residues : Nil
    matches_per_fragment = detect_residues @structure
    builder = Structure::Builder.new @structure.clear
    matches_per_fragment.each do |matches|
      builder.chain do
        matches.each do |m|
          residue = builder.residue m.resname
          residue.kind = m.reskind
          m.each_atom do |atom, atom_name|
            atom.name = atom_name
            atom.residue = residue
          end
        end
      end
    end
  end

  def guess_topology : Nil
    return unless @structure.n_atoms > 0
    if has_topology?
      patcher = Patcher.new @structure
      patcher.match_and_patch
      unmatched_atoms = AtomView.new patcher.unmatched_atoms
      build_connectivity unmatched_atoms
      if has_hydrogens?
        assign_bond_orders unmatched_atoms
        bonded_atoms = unmatched_atoms.flat_map &.each_bonded_atom
        assign_formal_charges AtomView.new(unmatched_atoms.to_a.concat(bonded_atoms).uniq)
      end
    else
      guess_bonds
      guess_residues
      @structure.renumber_by_connectivity
    end
    assign_residue_types
  end

  private getter? has_hydrogens : Bool do
    @structure.has_hydrogens?
  end

  private getter largest_atom : Atom do
    @structure.each_atom.max_by &.covalent_radius
  end

  private getter kdtree : Spatial::KDTree do
    atom = largest_atom
    max_covalent_distance = Math.sqrt PeriodicTable.covalent_cutoff(atom, atom)
    Spatial::KDTree.new @structure, radius: max_covalent_distance
  end

  private def assign_bond_orders(atoms : AtomCollection) : Nil
    atoms.each_atom do |atom|
      next if atom.element.ionic?
      missing_bonds = atom.missing_valency
      while missing_bonds > 0
        others = atom.bonded_atoms.select &.missing_valency.>(0)
        break if others.empty?
        others.each(within: ...missing_bonds) do |other|
          atom.bonds[other].order += 1
          missing_bonds -= 1
        end
      end
    end
  end

  private def assign_formal_charges(atoms : AtomCollection) : Nil
    atoms.each_atom do |atom|
      atom.formal_charge = if atom.element.ionic?
                             atom.max_valency
                           else
                             atom.bonds.sum(&.order) - atom.nominal_valency
                           end
    end
  end

  private def assign_residue_types : Nil
    return unless bond_t = @structure.link_bond
    @structure.each_residue do |residue|
      next if residue.type
      types = residue
        .bonded_residues(bond_t, forward_only: false, strict: false)
        .map(&.kind)
        .uniq!
        .reject!(&.other?)
      residue.kind = types.size == 1 ? types[0] : Residue::Kind::Other
    end
  end

  private def build_connectivity(atoms : AtomCollection) : Nil
    atoms.each_atom do |atom|
      next if atom.element.ionic?
      cutoff = Math.sqrt PeriodicTable.covalent_cutoff(atom, largest_atom)
      kdtree.each_neighbor(atom, within: cutoff) do |other, d|
        next if other.element.ionic? ||
                atom.bonded?(other) ||
                (other.element.hydrogen? && other.bonds.size > 0) ||
                d > PeriodicTable.covalent_cutoff(atom, other)
        if atom.element.hydrogen? && atom.bonds.size == 1
          next unless d < atom.bonds[0].squared_distance
          atom.bonds.delete atom.bonds[0]
        end
        atom.bonds.add other
      end
    end
  end

  private def detect_residues(atoms : AtomCollection) : Array(Array(MatchData))
    fragments = [] of Array(MatchData)
    atoms.each_fragment do |frag|
      detector = Templates::Detector.new frag
      matches = [] of MatchData
      matches.concat detector.matches
      AtomView.new(detector.unmatched_atoms).each_fragment do |frag|
        matches << make_match(frag)
      end
      fragments << matches
    end

    polymers, other = fragments.partition &.size.>(1)
    other = other.flatten.sort_by!(&.reskind).group_by(&.reskind).values
    polymers.size + other.size <= MAX_CHAINS ? polymers + other : [fragments.flatten]
  end

  private def guess_bonds(atoms : AtomCollection) : Nil
    build_connectivity atoms
    if has_hydrogens?
      assign_bond_orders atoms
      assign_formal_charges atoms
    end
  end

  private def has_topology? : Bool
    @structure.n_residues > 1 || @structure.each_residue.first.name != "UNK"
  end

  private def make_match(atoms : Enumerable(Atom)) : MatchData
    atom_map = Hash(String, Atom).new initial_capacity: atoms.size
    ele_index = Hash(Element, Int32).new default_value: 0
    atoms.each do |atom|
      name = "#{atom.element.symbol}#{ele_index[atom.element] += 1}"
      atom_map[name] = atom
    end
    MatchData.new("UNK", :other, atom_map)
  end
end
