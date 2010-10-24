require 'convertor'
require 'parser'
require 'reformat.tab'
require 'rasp'

require 'pathname'

$BuiltIns = %w(
Rnd Round CLng CInt CDbl CStr CBool oApplication Trim Write ID
Request Response Server Now Array DatePart WeekDayName Day Month Year Right Left Mid Replace IsNumeric IsNull IsEmpty
Null Nothing Empty Err TypeName FormatNumber Abs LBound UBound Split
)
#      elsif builtin = scan( /(IsArray|LBound|UBound|Abs|Asc|AscB|AscW|Chr|ChrB|ChrW|CBool|CByte|CDate|CDbl|CInt|CLng|CSng|CStr|DateSerial|DateValue|Hex|Oct|Fix|Int|Sgn|TimeSerial|TimeValue|Date|Time|Day|Month|Weekday|Year|Hour|Minute|Second|Now|Atn|Cos|Sin|Tan|Exp|Log|Sqr|Rnd|CreateObject|IsObject|InStr|InStrB|Len|LenB|LCase|UCase|Left|LeftB|Mid|MidB|Right|RightB|Space|StrComp|String|LTrim|RTrim|Trim|IsDate|IsEmpty|IsNull|IsNumeric|VarType)(?= *\()/i )

$Rename = { }

$seen = {}

def Bracket(s)
  (s.nil? || s.empty?) ? '' : "(#{s})"
end
def NL(s)
  s << "\n" unless s =~ /\n\z/
  s
end
def I(s)
  return '' if s.empty?

  lines = s.split("\n")
  lines.pop while lines.last.empty?

  lines.map {|l| l.empty? ? '' : ('   ' + l) }.join("\n") + "\n"
end
def check_ident(s)
  builtin = $BuiltIns.find {|b| b.downcase == s.downcase }
  return builtin if builtin

  rename = $Rename.keys.find {|r| r.downcase == s.downcase }
  return $Rename[rename] if rename

  # TODO: Try to split it into words (possibly with an ID suffix, and
  # possibly with a type prefix), and re-capitalize appropriately.

  $seen[s.downcase] = [] unless $seen.include? s.downcase
  $seen[s.downcase] << s

  s
end
def check_member(s)
  # This function is passed an already-checked identifier, for further
  # checking, now that we know it's an object member.

  s[0, 1].upcase + s[1, s.size]
end

filename = ARGV[0] || 'samples/test2.vbs'

convertor = Syntax::Convertors::CodeTree.for_syntax 'vbscript'
convertor.follow_includes = true
convertor.follow_includes = false ## XXX
convertor.swallow = false ## XXX
convertor.virtual_root = Pathname.new( filename ).parent
#convertor.type = :asp
proper_filename = File.expand_path(filename).gsub('/', '\\')
proper_filename = File.expand_path(filename) unless File.exists?( proper_filename )

begin
  print convertor.convert(File.read(filename), proper_filename).gsub(/\r/, '')

  $seen.each do |dc, list|
    if list.uniq.size > 1
      $stderr.puts "#{dc}: #{list.uniq.inspect}"
    end
  end
rescue Rasp::ScriptError => error
  $stderr.puts "#{error.token.inspect}\n#{error.location}Microsoft VBScript compilation error: #{error.description}"
  exit 1
end

