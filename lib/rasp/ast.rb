module Rasp; module AST
FalseInt = 0
TrueInt = ~FalseInt

def self.math_op(match, op=nil)
  binary_op(AST::MathOp, match.lhs, match.list, op ? [op] : :op)
end

def self.binary_op(klass, lhs, ary, op_attr=nil, attr=:rhs)
  lhs = lhs.value
  ary = ary.matches.dup
  until ary.empty?
    curr = ary.shift
    rhs = curr.send(attr).value
    if Symbol === op_attr
      op = curr.send(op_attr).to_sym
      lhs = klass.new(op, lhs, rhs)
    elsif op_attr
      op = op_attr.first
      lhs = klass.new(op, lhs, rhs)
    else
      lhs = klass.new(lhs, rhs)
    end
  end
  lhs
end

def self.list(lhs, ary, attr=:rhs)
  [lhs] + ary.matches.map do |curr|
    curr.send(attr).value
  end
end

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

require 'rasp/ast/block'
require 'rasp/ast/call'
require 'rasp/ast/expression'
require 'rasp/ast/flow'
require 'rasp/ast/simple'
require 'rasp/ast/value'
