module Rasp::AST

class UnaryOp < Node
  attr_accessor :inner
  def initialize(inner)
    @inner = inner
  end

  def bytecode(g)
    @inner.bytecode(g)
    op_bytecode g
  end
  def prescan(g)
    @inner.prescan(g)
  end
end
class BinaryOp < Node
  attr_accessor :lhs, :rhs
  def initialize(lhs, rhs)
    @lhs, @rhs = lhs, rhs
  end
  def bytecode(g)
    @lhs.bytecode(g)
    @rhs.bytecode(g)
    op_bytecode g
  end

  def prescan(g)
    @lhs.prescan(g)
    @rhs.prescan(g)
  end
end
class ImpOp < BinaryOp
end
class EqvOp < BinaryOp
end
class XorOp < BinaryOp
  def op_bytecode(g)
    g.send :^, 1
  end
end
class OrOp < BinaryOp
  def op_bytecode(g)
    g.send :|, 1
  end
end
class AndOp < BinaryOp
  def op_bytecode(g)
    g.send :&, 1
  end
end
class NotOp < UnaryOp
  def op_bytecode(g)
    g.send_vcall :~
  end
end
class Comparison < BinaryOp
  attr_accessor :operator
  def initialize(operator, lhs, rhs)
    super(lhs, rhs)
    @operator = operator
  end
  def op_bytecode(g)
    g.send @operator.to_sym, 1
  end
end
class StringAppend < BinaryOp
  def bytecode(g)
    case @rhs
    when Rasp::AST::StringAppend, Rasp::AST::String
      @rhs.bytecode(g)
    else
      @rhs.bytecode(g)
      g.send_vcall :to_s
    end

    case @lhs
    when Rasp::AST::StringAppend
      @lhs.bytecode(g)
    when Rasp::AST::String
      @lhs.bytecode(g)
      g.string_dup
    else
      @lhs.bytecode(g)
      g.send_vcall :to_s
      g.string_dup
    end

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
    g.send @operator.to_sym, 1
  end
end
class UnaryPlus < UnaryOp
  def op_bytecode(g)
    g.send_vcall :+@
  end
end
class UnaryMinus < UnaryOp
  def op_bytecode(g)
    g.send_vcall :-@
  end
end

class NewObject < Node
  attr_accessor :class_name
  def initialize(class_name)
    @class_name = class_name
  end
  def prescan(g)
  end
end

end
