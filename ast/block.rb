module Rasp::AST

class Scope < Node
  include Rubinus::Compiler::LocalVariables

  attr_accessor :statements
  def initialize(statements)
    @statements = statements
  end
end

end
