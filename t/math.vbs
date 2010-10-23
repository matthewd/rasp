Option Explicit

Dim i,j

Const MIN = -32
Const MAX = 32

For i = MIN To MAX
	For j = MIN To MAX
		WScript.Echo i & " And " & j & " = " & (i And j)
		WScript.Echo i & " Eqv " & j & " = " & (i Eqv j)
		WScript.Echo i & " Imp " & j & " = " & (i Imp j)
		WScript.Echo i & " Or "  & j & " = " & (i Or  j)
		WScript.Echo i & " Xor " & j & " = " & (i Xor j)
	Next
	WScript.Echo "Not " & i & " = " & (Not i)
Next

