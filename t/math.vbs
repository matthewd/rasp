'Option Explicit

Dim i,j

Dim n

Function fib(n)
	WScript.Echo "zz"
'	If True Then n = 2
'	If 1 Then
'		x = 1
'		fib = 1
'	Else
'		fib = zfib(n - 2) + zfib(n - 1) + fizz(777)
'	End If
	fib = 7
End Function

Sub xyzzy(n)
	n = 3
End Sub

Const MIN = -1
Const MAX = 1

For i = MIN To MAX
	For j = MIN To MAX
		WScript.Echo i & " And " & j & " = " & (i And j)
'		WScript.Echo i & " Eqv " & j & " = " & (i Eqv j)
'		WScript.Echo i & " Imp " & j & " = " & (i Imp j)
		WScript.Echo i & " Or "  & j & " = " & (i Or  j)
		WScript.Echo i & " Xor " & j & " = " & (i Xor j)
	Next
	WScript.Echo "Not " & i & " = " & (Not i)
Next

