require 'parser'

filename = ARGV.shift
out = ''

@tokenizer = VbScriptTokenizer.new
@tokenizer.setup

@tokenizer.filename = filename
@tokenizer.swallow = false
@tokenizer.follow_includes = false
@tokenizer.start( File.read( filename ) ) do |token|
  case token.group
  when :directive, :html, '<%', :newline, :comment, :ident
    out << token
  else
    puts out.to_a.last(5)
    p [token.group, token]
    exit
  end
end
@tokenizer.step until @tokenizer.eos?
@tokenizer.finish

