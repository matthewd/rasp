module Rasp::AST

class Literal < Node
  attr_accessor :value
  def initialize(value)
    @value = value
  end
  def bytecode(g)
    g.push_literal value
  end
end
class String < Literal
end
class Integer < Literal
end
class Float < Literal
end
class TrueValue < Integer
  def initialize
    super TrueInt
  end
end
class FalseValue < Integer
  def initialize
    super FalseInt
  end
end

end
