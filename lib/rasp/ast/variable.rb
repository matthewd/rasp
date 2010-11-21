module Rasp::AST

class VarAccess < Node
  attr_accessor :var
  def initialize(var)
    @var = var
  end
  def bytecode(g)
    ref = g.state.scope.lookup_variable(g, var)
    ref.get_bytecode(g)
  end
  def prescan(g)
  end
end

end
