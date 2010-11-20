module Rasp::AST

class Call < Node
  attr_accessor :target, :name, :args
  def initialize(target, name, args)
    @target, @name, @args = target, name, args
  end
  def bytecode(g)
    if @target.nil? && g.constants.key?(@name)
      raise "Can't call constant with args" if @args && !@args.empty?
      g.push_literal g.constants[@name]
    end
  end
end

class NullCall < Call
end
class GetCall < Node
end
class LetCall < Node
  attr_accessor :value
  def initialize(target, name, args, value)
    super target, name, args
    @value = value
  end
end
class SetCall < LetCall
end

end
