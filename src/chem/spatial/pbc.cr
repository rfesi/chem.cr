module Chem::Spatial::PBC
  extend self

  ADJACENT_IMAGE_IDXS = [{1, 0, 0}, {0, 1, 0}, {0, 0, 1}, {1, 1, 0}, {1, 0, 1},
                         {0, 1, 1}, {1, 1, 1}]

  def adjacent_images(*args, **options) : Array(Tuple(Atom, Vector))
    ary = [] of Tuple(Atom, Vector)
    each_adjacent_image(*args, **options) do |atom, coords|
      ary << {atom, coords}
    end
    ary
  end

  def each_adjacent_image(structure : Structure, &block : Atom, Vector ->)
    if lattice = structure.lattice
      each_adjacent_image structure, lattice, &block
    else
      raise Error.new "Cannot generate adjacent images of a non-periodic structure"
    end
  end

  def each_adjacent_image(atoms : AtomCollection,
                          lattice : Lattice,
                          &block : Atom, Vector ->)
    basis = Linalg::Basis.new lattice.a, lattice.b, lattice.c
    transform = Linalg::Basis.standard.transform to: basis
    inv_transform = transform.inv

    atoms = atoms.each_atom
    while !(atom = atoms.next).is_a? Iterator::Stop
      fcoords = transform * atom.coords            # convert to fractional coords
      w_fcoords = fcoords - fcoords.floor          # wrap to primary unit cell
      ax_offset = -2 * w_fcoords.round + {1, 1, 1} # compute offset per axis

      ADJACENT_IMAGE_IDXS.each do |img_idx|
        yield atom, inv_transform * (fcoords + ax_offset * img_idx)
      end
    end
  end

  def wrap(atoms : AtomCollection, lattice : Lattice)
    wrap atoms, lattice, lattice.center
  end

  def wrap(atoms : AtomCollection, lattice : Lattice, center : Spatial::Vector)
    if lattice.cuboid?
      vecs = {lattice.a, lattice.b, lattice.c}
      normed_vecs = vecs.map &.normalize
      atoms.each_atom do |atom|
        d = atom.coords - center
        {% for i in 0..2 %}
          fd = d.dot(normed_vecs[{{i}}]) / vecs[{{i}}].size
          atom.coords += -fd.round * vecs[{{i}}] if fd.abs > 0.5
        {% end %}
      end
    else
      basis = Linalg::Basis.new lattice.a, lattice.b, lattice.c
      transform = Linalg::Basis.standard.transform to: basis
      atoms.transform by: transform
      wrap atoms, Lattice.new(V.x, V.y, V.z), (transform * center)
      atoms.transform by: transform.inv
    end
  end
end
