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
  [lhs.value] + ary.matches.map do |curr|
    curr.send(attr).value
  end
end

class Node
  def self.attr_names
    @attr_names ||= []
  end
  def self.node_attr *names
    attr_accessor *names
    attr_names.push *names
  end

  def node_summary
    s = ""
    s << self.class.name.sub(/.*::/, '')
    unless self.class.attr_names.empty?
      s << "<"
      s << self.class.attr_names.map {|x|
        z = instance_variable_get(:"@#{x}")
        if Array === z
          "[#{z.map {|q| q ? q.node_summary : '0' }.join ','}]"
        else
          z ? z.node_summary : '0'
        end
      }.join(',')
      s << ">"
    end
    s
  end

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
