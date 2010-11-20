module Rasp::AST

class VarAccess < Node
  attr_accessor :var
  def initialize(var)
    @var = var
  end
end

end
