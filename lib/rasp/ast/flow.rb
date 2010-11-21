module Rasp::AST

class Loop < Node
  attr_accessor :type, :body
  def initialize(type, body)
    @type, @body = type, body
  end

  def bytecode(g)
    top = g.new_label
    top.set!

    @body.each do |s|
      s.bytecode(g)
    end
    g.goto top
  end
  def prescan(g)
    @body.each do |s|
      s.prescan(g)
    end
  end
end
class DoWhile < Loop
  attr_accessor :condition
  def initialize(type, condition, invert, body)
    super(type, body)
    @condition = invert ? NotExpr.new(condition) : condition
  end
  def bytecode(g)
    top = g.new_label
    done = g.new_label
    top.set!

    @condition.bytecode(g)
    g.meta_push_0
    g.meta_send_op_eq
    g.giz done

    @body.each do |s|
      s.bytecode(g)
    end
    g.goto top

    done.set!
  end
  def prescan(g)
    @condition.prescan(g)
    @body.each do |s|
      s.prescan(g)
    end
  end
end
class LoopWhile < DoWhile
  def bytecode(g)
    top = g.new_label
    top.set!

    @body.each do |s|
      s.bytecode(g)
    end

    @condition.bytecode(g)
    g.gnz top
  end
  def prescan(g)
    @body.each do |s|
      s.prescan(g)
    end
    @condition.prescan(g)
  end
end
class ForLoop < Loop
  # Contrary to my original expectation, not having used VBScript in
  # ages, all three of (start, finish, step) are fixed at loop start.

  attr_accessor :var, :start, :finish, :step
  def initialize(var, start, finish, step, body)
    super(:for, body)
    @var, @start, @finish, @step = var, start, finish, step
  end
  def bytecode(g)
    loop_var = g.state.scope.lookup_variable(g, var)

    @finish.bytecode(g)
    if @step
      @step.bytecode(g) if @step
      unless Rasp::AST::Literal === @step
        g.dup
        g.meta_push_0
        g.send :<, 1
      end
    end

    @start.bytecode(g)
    loop_var.set_bytecode(g)
    g.pop

    loop_body = g.new_label
    loop_body.set!

    @body.each do |s|
      s.bytecode(g)
    end

    if Rasp::AST::Literal === @step || @step.nil?
      # Step is constant

      if @step
        g.dup_many 2 # @step, @finish, ...
        loop_var.get_bytecode(g)
        g.send :+, 1
      else
        g.dup # @finish, ...
        loop_var.get_bytecode(g)
        g.send_vcall :succ
      end
      loop_var.set_bytecode(g)

      if @step.nil? || @step.value > 0
        # Always working forwards
        g.send :<=, 1
      elsif @step.value < 0
        # Always working backwards
        g.send :>=, 1
      else
        # Constant step of zero?! Twit.
        raise "For loop cannot have a zero step"
      end

      g.git loop_body

      if @step
        g.pop_many 2
      else
        g.pop
      end
    else
      # Dynamic step; have to work out which way we're going at runtime
      # Experimentation shows this isn't as scary as it seems; the
      # reference implementation only evaluates the Step value once, as
      # the loop starts.
      #
      # In theory, we could apply some clever logic based on the size of
      # @body, to decide whether we're better off paying an extra git
      # per iteration at runtime vs having two separate copies of the
      # loop. No idea whether that'd be actually useful.

      check_backwards = g.new_label
      end_loop = g.new_label

      g.dup_many 3 # loop_backwards, @step, @finish, ...
      loop_var.get_bytecode(g)
      g.send :+, 1
      loop_var.set_bytecode(g)

      g.git check_backwards
      g.send :<=, 1
      g.git loop_body
      g.goto end_loop

      check_backwards.set!
      g.send :>=, 1
      g.git loop_body

      end_loop.set!
      g.pop_many 3
    end
  end
  def prescan(g)
    @start.prescan(g)
    @finish.prescan(g)
    @step.prescan(g) if @step
    @body.each do |s|
      s.prescan(g)
    end
  end
end
class ForEachLoop < Loop
  attr_accessor :var, :collection
  def initialize(var, collection, body)
    super(:for, body)
    @var, @collection = var, collection
  end
  def bytecode(g)
    # TODO
  end
  def prescan(g)
    @collection.prescan(g)
    @body.each do |s|
      s.prescan(g)
    end
  end
end

class If < Node
  attr_accessor :condition, :true_body, :false_body
  def initialize(condition, true_body, false_body)
    @condition, @true_body, @false_body = condition, true_body, false_body
  end

  def bytecode(g)
    false_label = g.new_label

    @condition.bytecode(g)
    g.giz false_label

    @true_body.each do |s|
      s.bytecode(g)
    end

    if @false_body && @false_body.size > 0
      done = g.new_label
      g.goto done

      false_label.set!
      @false_body.each do |s|
        s.bytecode(g)
      end

      done.set!
    else
      false_label.set!
    end
  end
  def prescan(g)
    @condition.prescan(g)
    @true_body.each do |s|
      s.prescan(g)
    end
    if @false_body
      @false_body.each do |s|
        s.prescan(g)
      end
    end
  end
end

class SelectCase < Container
  attr_accessor :expr, :cases, :else_body
  def initialize(expr, cases, else_body)
    @expr, @cases, @else_body = expr, cases, else_body
  end

  def bytecode(g)
    done = new_label
    @expr.bytecode(g)
    @cases.each do |c|
      c.bytecode(g, done)
    end
    if @else_body
      @else_body.each do |s|
        s.bytecode(g)
      end
    end
    done.set!
  end
  def prescan(g)
    @expr.prescan(g)
    @cases.each do |c|
      c.prescan(g)
    end
    if @else_body
      @else_body.each do |s|
        s.prescan(g)
      end
    end
  end
end
class Case < Node
  attr_accessor :matches, :body
  def initialize(matches, body)
    @matches, @body = matches, body
  end
  def bytecode(g, done)
    body_label = g.new_label unless matches.size == 1
    failed_match = g.new_label

    matches.each do |m|
      g.dup
      m.bytecode(g)
      g.meta_send_op_eq find_literal(:==)
      if m == matches.last
        g.giz failed_match
      else
        g.gnz body_label
      end
    end

    body_label.set! unless matches.size == 1
    @body.each do |s|
      s.bytecode(g)
    end
    g.goto done

    failed_match.set!
  end
  def prescan(g)
    @matches.each do |m|
      m.prescan(g)
    end
    @body.each do |s|
      s.prescan(g)
    end
  end
end

end
