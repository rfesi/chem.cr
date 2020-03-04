require "./templates/all"

class Chem::Topology::Perception
  MAX_CHAINS = 62 # chain id is alphanumeric: A-Z, a-z or 0-9

  def initialize(@structure : Structure)
  end

  def assign_templates : Nil
    TemplateMatcher.new(@structure).match_and_patch
  end

  def guess_bonds : Nil
    guess_connectivity @structure
    guess_bond_orders @structure if has_hydrogens?
  end

  def guess_formal_charges(atoms : AtomCollection) : Nil
    atoms.each_atom do |atom|
      atom.formal_charge = if atom.element.ionic?
                             atom.max_valency
                           else
                             atom.bonds.sum(&.order) - atom.nominal_valency
                           end
    end
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
      matcher = TemplateMatcher.new @structure
      matcher.match_and_patch
      unmatched_atoms = AtomView.new matcher.unmatched_atoms
      guess_connectivity unmatched_atoms
      if has_hydrogens?
        guess_bond_orders unmatched_atoms
        bonded_atoms = unmatched_atoms.flat_map &.each_bonded_atom
        guess_formal_charges AtomView.new(unmatched_atoms.to_a.concat(bonded_atoms).uniq)
      end

      if bond_t = link_bond(@structure)
        @structure.each_residue do |residue|
          residue.kind = guess_residue_type residue, bond_t unless Templates[residue.name]?
        end
      end
    else
      guess_bonds
      guess_formal_charges @structure if has_hydrogens?
      guess_residues
      renumber_by_connectivity
    end
  end

  def renumber_by_connectivity : Nil
    @structure.each_chain do |chain|
      next unless chain.n_residues > 1
      next unless bond_t = link_bond(chain)

      res_map = chain.each_residue.to_h do |residue|
        {guess_previous_residue(residue, bond_t), residue}
      end
      res_map[nil] = chain.residues.first unless res_map.has_key? nil

      prev_res = nil
      chain.n_residues.times do |i|
        next_res = res_map[prev_res]
        next_res.number = i + 1
        prev_res = next_res
      end
      chain.reset_cache
    end
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

  private def detect_residues(atoms : AtomCollection) : Array(Array(MatchData))
    fragments = [] of Array(MatchData)
    atoms.each_fragment do |frag|
      detector = Templates::Detector.new frag
      matches = [] of MatchData
      matches.concat detector.matches
      matches.concat guess_unmatched(detector.unmatched_atoms)
      fragments << matches
    end

    polymers, other = fragments.partition &.size.>(1)
    other = other.flatten.sort_by!(&.reskind).group_by(&.reskind).values
    polymers.size + other.size <= MAX_CHAINS ? polymers + other : [fragments.flatten]
  end

  private def guess_bond_orders(atoms : AtomCollection) : Nil
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

  private def guess_connectivity(atoms : AtomCollection) : Nil
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

  private def guess_previous_residue(residue : Residue, link_bond : BondType) : Residue?
    prev_res = nil
    if atom = residue[link_bond[1]]?
      prev_res = atom.each_bonded_atom.find(&.name.==(link_bond[0].name)).try &.residue
      prev_res ||= atom.each_bonded_atom.find do |atom|
        atom.element == link_bond[0].element && atom.residue != residue
      end.try &.residue
    else
      residue.each_atom do |atom|
        next unless atom.element == link_bond[1].element
        prev_res = atom.each_bonded_atom.find do |atom|
          atom.element == link_bond[0].element && atom.residue != residue
        end.try &.residue
        break if prev_res
      end
    end
    prev_res
  end

  private def guess_residue_type(res : Residue, bond_t : BondType) : Residue::Kind
    bonded_residues = res.bonded_residues bond_t, forward_only: false, strict: false
    types = bonded_residues.map(&.kind).uniq!.reject!(&.other?)
    types.size == 1 ? types[0] : Residue::Kind::Other
  end

  private def guess_unmatched(atoms : Array(Atom)) : Array(MatchData)
    matches = [] of MatchData
    AtomView.new(atoms).each_fragment do |frag|
      atom_map = Hash(String, Atom).new initial_capacity: frag.size
      ele_index = Hash(Element, Int32).new default_value: 0
      frag.each do |atom|
        name = "#{atom.element.symbol}#{ele_index[atom.element] += 1}"
        atom_map[name] = atom
      end
      matches << MatchData.new("UNK", :other, atom_map)
    end
    matches
  end

  private def link_bond(residues : ResidueCollection) : BondType?
    residues.each_residue do |residue|
      bond_t = Templates[residue.name]?.try &.link_bond
      return bond_t if bond_t
    end
  end

  private def has_topology? : Bool
    @structure.n_residues > 1 || @structure.each_residue.first.name != "UNK"
  end

  private class TemplateMatcher
    getter unmatched_atoms = [] of Atom

    def initialize(@residues : ResidueCollection)
    end

    def match_and_patch : Nil
      @residues.each_residue do |residue|
        if res_t = Templates[residue.name]?
          patch residue, res_t
        else
          @unmatched_atoms.concat residue.each_atom
        end
      end
    end

    def patch(atom : Atom, atom_t : AtomType) : Nil
      atom.formal_charge = atom_t.formal_charge
    end

    def patch(lhs : Residue, rhs : Residue, bond_t : BondType) : Nil
      if (i = lhs[bond_t[0]]?) && (j = rhs[bond_t[1]]?) && !i.bonded?(j)
        i.bonds.add j, bond_t.order if i.within_covalent_distance?(j)
      end
    end

    def patch(residue : Residue, res_t : ResidueType) : Nil
      residue.each_atom do |atom|
        if atom_t = res_t[atom.name]?
          patch atom, atom_t
        else
          @unmatched_atoms << atom
        end
      end

      res_t.bonds.each { |bond_t| patch residue, residue, bond_t }
      if bond_t = res_t.link_bond
        patch_link_bond residue, bond_t
      end
    end

    def patch_link_bond(residue : Residue, bond_t : BondType)
      if prev_res = residue.previous
        patch prev_res, residue, bond_t
      end
      if next_res = residue.next
        patch residue, next_res, bond_t
      end
    end
  end
end
