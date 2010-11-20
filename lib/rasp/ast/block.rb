module Rasp::AST

class File < Node
  include Rasp::Compiler::LocalVariables

  attr_accessor :statements
  def initialize(statements)
    @statements = statements
  end
  def global; self; end
  def bytecode(g)
    g.push_state self
    statements.each do |s|
      s.bytecode(g)
    end
    g.pop_state
  end
end

end
