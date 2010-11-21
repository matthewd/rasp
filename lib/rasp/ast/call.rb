module Rasp::AST

class Call < Node
  attr_accessor :target, :name, :args
  def initialize(target, name, args)
    @target, @name, @args = target, name, args
  end

  def prescan(g)
    if @args
      @args.each do |a|
        a.prescan(g)
      end
    end
  end
end

class GetCall < Call
  def self.from(call)
    new(call.target, call.name, call.args)
  end
  def bytecode(g)
    if @target && @target.name == :wscript && @name == :echo && @args && @args.size == 1
      g.push_const :Kernel
      @args.first.bytecode(g)
      g.send :puts, 1
      return
    end

    if @target
      if @args && !@args.empty?
        @target.bytecode(g)
        @args.each do |a|
          a.bytecode(g)
        end
        g.send :"vb:#@name", @args.size
      else
        @target.bytecode(g)
        g.send :"vb:#@name", 0
      end
    else
      if @args.nil? || @args.empty?
        if g.constants.key?(@name)
          g.push_literal g.constants[@name]
          return
        end

        ref = g.state.scope.lookup_variable(g, @name)
        if ref
          ref.get_bytecode(g)
          return
        end

        g.meta_push_0
      else
        g.push_self
        @args.each do |a|
          a.bytecode(g)
        end
        g.send :"vb:#@name", @args.size
      end
    end
  end
end
class NullCall < GetCall
  def bytecode(g)
    super
    g.pop
  end
end
class LetCall < Node
  attr_accessor :target, :name, :args, :value
  def initialize(target, name, args, value)
    @target, @name, @args, @value = target, name, args, value
  end
  def bytecode(g)
    if @target.nil? && (@args.nil? || @args.empty?)
      ref = g.state.scope.lookup_variable(g, @name)
      @value.bytecode(g)
      ref.set_bytecode(g)
      g.pop
    else
      raise NotImplementedError, "Deep let/set not supported"
    end
  end
  def self.from(call, value)
    new(call.target, call.name, call.args, value)
  end
  def prescan(g)
    if @args
      @args.each do |a|
        a.prescan(g)
      end
    end
    @value.prescan(g)
  end
end
class SetCall < LetCall
  def self.from(call, value)
    new(call.target, call.name, call.args, value)
  end
end

end
