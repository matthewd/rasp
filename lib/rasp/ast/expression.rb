module Rasp::AST

class Operator < Node
end
class UnaryOp < Node
  attr_accessor :inner
  def initialize(inner)
    @inner = inner
  end
end
class BinaryOp < Node
  attr_accessor :lhs, :rhs
  def initialize(lhs, rhs)
    @lhs, @rhs = lhs, rhs
  end
  def bytecode(g)
    @rhs.bytecode(g)
    @lhs.bytecode(g)
    op_bytecode g
  end
end
class ImpOp < BinaryOp
end
class EqvOp < BinaryOp
end
class XorOp < BinaryOp
  def op_bytecode(g)
    g.send :^
  end
end
class OrOp < BinaryOp
  def op_bytecode(g)
    g.send :|
  end
end
class AndOp < BinaryOp
  def op_bytecode(g)
    g.send :&
  end
end
class NotOp < UnaryOp
end
class Comparison < BinaryOp
  attr_accessor :operator
  def initialize(operator, lhs, rhs)
    super(lhs, rhs)
    @operator = operator
  end
  def op_bytecode(g)
    g.send @operator.to_sym
  end
end
class StringAppend < BinaryOp
  def op_bytecode(g)
    g.string_dup
    g.string_append
  end
end
class MathOp < BinaryOp
  attr_accessor :operator
  def initialize(operator, lhs, rhs)
    super(lhs, rhs)
    @operator = operator
  end
  def op_bytecode(g)
    g.send @operator.to_sym
  end
end
class UnaryPlus < UnaryOp
  def op_bytecode(g)
    g.send_vcall :"@+"
  end
end
class UnaryMinus < UnaryOp
  def op_bytecode(g)
    g.send_vcall :"@-"
  end
end

class NewObject < Node
  attr_accessor :class_name
  def initialize(class_name)
    @class_name = class_name
  end
end

end
