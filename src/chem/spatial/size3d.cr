module Chem::Spatial
  struct Size3D
    getter a : Float64
    getter b : Float64
    getter c : Float64

    def initialize(@a : Float64, @b : Float64, @c : Float64)
    end

    def [](index : Int32) : Float64
      case index
      when 0 then @a
      when 1 then @b
      when 2 then @c
      else
        raise IndexError.new
      end
    end

    {% for op in ['*', '/'] %}
      def {{op.id}}(other : Number) : self
        Size3D.new @a {{op.id}} other, @b {{op.id}} other, @c {{op.id}} other
      end
    {% end %}

    def to_a : Array(Float64)
      [@a, @b, @c]
    end
  end
end
