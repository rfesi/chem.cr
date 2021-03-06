require "baked_file_system"
require "yaml"

module Chem::Protein
  class QUESSO < SecondaryStructureCalculator
    CURVATURE_CUTOFF = 60

    getter? blend_elements : Bool

    def initialize(structure : Structure, @blend_elements : Bool = true)
      super structure
      @residues = ResidueView.new structure.residues.to_a.select(&.protein?)
    end

    def assign : Nil
      reset_secondary_structure
      assign_secondary_structure
      extend_elements
      reassign_enclosed_elements
      normalize_regular_elements
    end

    protected class_getter pes : EnergySurface do
      EnergySurface.load
    end

    private def assign_secondary_structure
      @residues.each do |residue|
        residue.sec = compute_secondary_structure residue
      end
    end

    private def compute_curvature(residue : Residue) : Float64?
      if (h1 = residue.previous.try(&.hlxparams)) &&
         (h2 = residue.hlxparams) &&
         (h3 = residue.next.try(&.hlxparams))
        dprev = Spatial.distance h1.q, h2.q
        dnext = Spatial.distance h2.q, h3.q
        ((dprev + dnext) / 2).degrees
      end
    end

    private def compute_secondary_structure(
      residue : Residue,
      strict : Bool = true
    ) : SecondaryStructure
      if h = residue.hlxparams
        if !strict
          QUESSO.pes.walk_to_closest_basin(h.zeta, h.theta, check_proximity: false) ||
            SecondaryStructure::None
        elsif (curv = compute_curvature(residue)) && curv <= CURVATURE_CUTOFF
          QUESSO.pes.walk_to_closest_basin(h.zeta, h.theta) || SecondaryStructure::Uniform
        else
          SecondaryStructure::Bend
        end
      else
        SecondaryStructure::None
      end
    end

    private def extend_elements
      @residues.each_secondary_structure(reuse: true) do |ele, sec|
        next unless sec.regular?
        2.times do |i|
          res = ele[i == 0 ? 0 : -1]
          while (res = (i == 0 ? res.previous : res.next)) &&
                (res.sec.bend? || res.sec.none?)
            other_sec = compute_secondary_structure res, strict: false
            if other_sec == sec
              res.sec = other_sec
            else
              break
            end
          end
        end
      end
    end

    private def normalize_regular_elements : Nil
      @residues.each_secondary_structure(reuse: true, strict: false) do |ele, sec|
        if sec.type.regular?
          if blend_elements? && ele.any?(&.sec.!=(sec))
            SecondaryStructureBlender.new(ele).blend
          end
          min_size = ele.all?(&.sec.==(sec)) ? sec.min_size : sec.type.min_size
          unset_element ele if ele.size < min_size
        end
      end
    end

    private def reassign_enclosed_elements : Nil
      @residues
        .each_secondary_structure(strict: false)
        .each_cons(3, reuse: true) do |(left, ele, right)|
          if ele[0].sec.type.coil? &&
             left[0].sec.type.regular? &&
             left[0].sec.type == right[0].sec.type
            seclist = ele.map { |r| compute_secondary_structure r, strict: false }
            ele.sec = seclist if seclist.all?(&.type.==(left[0].sec.type))
          end
        end
    end

    private def unset_element(residues : ResidueView) : Nil
      residues.each do |residue|
        residue.sec = if curv = compute_curvature(residue)
                        if curv <= CURVATURE_CUTOFF
                          SecondaryStructure::Uniform
                        else
                          SecondaryStructure::Bend
                        end
                      else
                        SecondaryStructure::None
                      end
      end
    end

    private struct Basin
      getter sec : SecondaryStructure
      getter x0 : Float64
      getter y0 : Float64
      getter sigma_x : Float64
      getter sigma_y : Float64
      getter height : Float64
      getter rot : Float64
      getter offset : Float64

      def initialize(@sec : SecondaryStructure,
                     @x0 : Float64,
                     @y0 : Float64,
                     @sigma_x : Float64,
                     @sigma_y : Float64,
                     @height : Float64,
                     @rot : Float64,
                     @offset : Float64)
        @rot = rot.radians
      end

      def includes?(x : Float64, y : Float64) : Bool
        rotcos = Math.cos -@rot
        rotsin = Math.sin -@rot
        (rotcos * (x - @x0) + rotsin * (y - @y0))**2 / @sigma_x**2 +
          (rotsin * (x - @x0) - rotcos * (y - @y0))**2 / @sigma_y**2 <= 4.5
      end
    end

    private class EnergySurface
      X_EXTENT = 0..4
      Y_EXTENT = 0..360

      def initialize(@dx : Linalg::Matrix, @dy : Linalg::Matrix)
      end

      class_getter basins : Array(Basin) do
        io = Files.get("basins.yml")
        YAML.parse(io).as_a.map do |attrs|
          Basin.new Protein::SecondaryStructure.parse(attrs["sec"].as_s),
            attrs["x0"].as_f.scale(X_EXTENT),
            attrs["y0"].as_f.scale(Y_EXTENT),
            attrs["sigma_x"].as_f.scale(X_EXTENT),
            attrs["sigma_y"].as_f.scale(Y_EXTENT),
            attrs["height"].as_f,
            attrs["rot"].as_f,
            attrs["offset"].as_f
        end
      end

      def self.load
        EnergySurface.new(
          Linalg::Matrix.read(Files.get("dxx.npy"), 400, 400),
          Linalg::Matrix.read(Files.get("dyy.npy"), 400, 400),
        )
      end

      def find_basin(x : Float64,
                     y : Float64,
                     check_proximity : Bool = true) : SecondaryStructure?
        x, y = x.scale(X_EXTENT), y.scale(Y_EXTENT)
        sec = nil
        min_distance = Float64::MAX
        EnergySurface.basins.each do |basin|
          next if check_proximity && !basin.includes?(x, y)
          d = (x - basin.x0)**2 + (y - basin.y0)**2
          if d < min_distance
            sec = basin.sec
            min_distance = d
          end
        end
        sec
      end

      def walk(x : Float64, y : Float64, steps : Int) : Tuple(Float64, Float64)
        x, y = x.scale(X_EXTENT), y.scale(Y_EXTENT)
        steps.times do
          i = (x * (@dx.rows - 1)).to_i
          j = (y * (@dx.columns - 1)).to_i
          x += @dx[i, j]
          y += @dy[i, j]
        end
        {x.unscale(X_EXTENT), y.unscale(Y_EXTENT)}
      end

      def walk_to_closest_basin(
        x : Float64,
        y : Float64,
        steps : Int = 10,
        check_proximity : Bool = true
      ) : SecondaryStructure?
        x, y = walk x, y, steps if x > 0
        find_basin x, y, check_proximity
      end
    end

    class Files
      extend BakedFileSystem
      bake_folder "../../../data/quesso"
    end

    class SecondaryStructureBlender
      def initialize(@residues : ResidueView)
        @patches = {} of Int32 => SecondaryStructure
      end

      def [](i : Int32, offset : Int32 = 0) : SecondaryStructure?
        i += offset
        @residues.unsafe_fetch(i).sec if 0 <= i < @residues.size
      end

      def beginning_of_sec_at?(i : Int32) : Bool
        self[i] != self[i, -1] && self[i] == self[i, 1] && self[i] == self[i, 2]
      end

      def blend : Nil
        if @residues.size > 2
          until next_patches.empty?
            @patches.each do |i, sec|
              @residues[i].sec = sec
            end
          end
        else
          @residues.sec = @residues[0].sec
        end
      end

      def end_of_sec_at?(i : Int32) : Bool
        self[i] == self[i, -2] && self[i] == self[i, -1] && self[i] != self[i, 1]
      end

      def middle_of_sec_at?(i : Int32) : Bool
        self[i] == self[i, -1] && self[i] == self[i, 1]
      end

      def mutable?(i : Int32) : Bool
        !beginning_of_sec_at?(i) &&
          !middle_of_sec_at?(i) &&
          !end_of_sec_at?(i)
      end

      def next_patches : Hash(Int32, SecondaryStructure)
        max_score = 0
        @patches.clear
        @residues.each_with_index do |res, i|
          next unless mutable?(i)
          score_table(i).each do |sec, score|
            if score > max_score
              @patches.clear
              max_score = score
            end
            @patches[i] = sec if score == max_score
          end
        end
        # aviods a swap (XY -> YX) by removing the substitution at the
        # left-most position
        @patches.reject! { |i, sec| @patches[i + 1]? == self[i] && sec == self[i + 1] }
        @patches
      end

      def score(i : Int32, sec : SecondaryStructure) : Int32
        score = (-2..2).sum do |offset|
          if offset == 0
            0
          elsif other = self[i, offset]
            other == sec ? 10**(3 - offset.abs) : 0
          else
            1
          end
        end
        score -= 5 if @residues[i].sec == self[i, 3]
        score
      end

      def score_table(i : Int32) : Hash(SecondaryStructure, Int32)
        (-2..2)
          .compact_map { |offset| self[i, offset] if offset != 0 }
          .uniq!
          .to_h { |sec| {sec, score(i, sec)} }
      end
    end
  end
end
