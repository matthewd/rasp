Option Explicit

Const MIN = 1
Const MAX = 10

Function fib(n)
	If n < 3 Then
		fib = 1
	Else
		fib = fib(n - 2) + fib(n - 1)
	End If
End Function

Dim i
For i = MIN To MAX
	WScript.Echo "fib(" & i & ") = " & fib(i)
Next

