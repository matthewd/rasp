Option Explicit

Dim i,j
Dim a

Const MIN = -32
Const MAX = 32

For i = MIN To MAX
	For j = MIN To MAX
		a =  i & " And " & j & " = " & (i And j)
		a =  i & " Eqv " & j & " = " & (i Eqv j)
		a =  i & " Imp " & j & " = " & (i Imp j)
		a =  i & " Or "  & j & " = " & (i Or  j)
		a =  i & " Xor " & j & " = " & (i Xor j)
	Next
	a =  "Not " & i & " = " & (Not i)
Next
Wscript.Echo ".."

