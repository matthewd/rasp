
Dim a, s: s = "This is a ""string"""
WScript.Echo s
WScript.Echo a
WScript.Echo ""

' I hope you like it! :)

'Session("foo") = "xyzzy"
'wscript.echo "--"
'wscript.echo session("bar")
'wscript.echo "**"
'wscript.echo session("foo")
'wscript.echo "--"

Sub frob
   Dim a
   a = 23: b = 17 + _
      2

   WScript.Echo a
   WScript.Echo b
   WScript.Echo "-"
   Exit Sub
   WScript.Echo "***"
End Sub

Function foo(a, b, ByrEf z)
   foo = a + b * z
   Exit Function
   foo = 99
End Function

a = 4
b = 51

WScript.Echo a
WScript.Echo b
WScript.Echo "-"

Call frob

'Dim x: x = foo
'Dim x: x = foo(12)
'Dim x: x = foo(12, 1, 1, 17)

WScript.Echo a
WScript.Echo b

WScript.Echo "=="

a = Empty
b = -17.3

WScript.Echo a & " | " & b & " | " & s

WScript.Echo foo(12, 8, 3)

