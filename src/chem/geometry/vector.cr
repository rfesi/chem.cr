require "../core_ext/number"

module Chem::Geometry
  struct Vector
    getter x : Float64
    getter y : Float64
    getter z : Float64

    def self.[](x : Float64, y : Float64, z : Float64) : self
      new x, y, z
    end

    def self.origin : self
      new 0, 0, 0
    end

    def initialize(@x : Float64, @y : Float64, @z : Float64)
    end

    def [](index : Int32) : Float64
      case index
      when 0 then @x
      when 1 then @y
      when 2 then @z
      else
        raise IndexError.new
      end
    end

    {% for op in ['+', '-'] %}
      def {{op.id}}(other : Vector) : self
        Vector.new @x {{op.id}} other.x, @y {{op.id}} other.y, @z {{op.id}} other.z
      end

      def {{op.id}}(other : {Int32 | Float64, Int32 | Float64, Int32 | Float64}) : self
        Vector.new @x {{op.id}} other[0], @y {{op.id}} other[1], @z {{op.id}} other[2]
      end
    {% end %}

    def - : self
      inverse
    end

    {% for op in ['*', '/'] %}
      def {{op.id}}(other : Int32 | Float64) : self
        Vector.new @x {{op.id}} other, @y {{op.id}} other, @z {{op.id}} other
      end
    {% end %}

    def angle(other : Vector) : Float64
      Math.atan2(cross(other).magnitude, dot(other)).degrees
    end

    def cross(other : Vector) : self
      Vector.new @y * other.z - @z * other.y,
        @z * other.x - @x * other.z,
        @x * other.y - @y * other.x
    end

    def distance(to other : Vector) : Float64
      Math.sqrt squared_distance(other)
    end

    def dot(other : Vector) : Float64
      @x * other.x + @y * other.y + @z * other.z
    end

    def inverse : self
      Vector.new -@x, -@y, -@z
    end

    def magnitude : Float64
      Math.sqrt @x**2 + @y**2 + @z**2
    end

    def normalize : self
      return dup if origin?
      self / magnitude
    end

    def origin? : Bool
      @x == 0 && @y == 0 && @z == 0
    end

    @[AlwaysInline]
    def squared_distance(to other : Vector) : Float64
      (x - other.x)**2 + (y - other.y)**2 + (z - other.z)**2
    end

    def to_a : Array(Float64)
      [x, y, z]
    end

    def to_t : Tuple(Float64, Float64, Float64)
      {x, y, z}
    end
  end
end
