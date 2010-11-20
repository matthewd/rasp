
module Rasp; module AST
FalseInt = 0
TrueInt = ~FalseInt

class Node
  def graph
    Rubinius::AST::AsciiGrapher.new(self, Node).print
  end

  def visit(visitor)
    # This is a bit magic... but is does avoid loads of repetition
    self_name = self.class.name.gsub(/(.)([A-Z])/) { $1 + "_" + $2.downcase }.downcase
    visitor.send(self_name, self)
  end
end
class Container < Node
  def visit(visitor)
    child_nodes.each {|c| c.visit visitor }
  end
end
end; end

require 'rasp/ast/value'
