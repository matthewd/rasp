#!/bin/bash

ruby C:/ruby/bin/racc vbscript.y

DEBUG=

FIRST="$1"
if [ "$FIRST" == "-d" ]; then
	DEBUG=-d
	shift
fi

SEARCH="$@"

if [ "$SEARCH" == "" ]; then
	SEARCH=t/
fi

temp1=temp-cscript.txt
temp2=temp-rasp.txt

/bin/find $SEARCH -name '*.vbs' | while read T; do
	if [ -f "$temp1" ]; then
		rm -f "$temp1"
	fi
	if [ -f "$temp2" ]; then
		rm -f "$temp2"
	fi

	time cscript /Nologo "$T" > $temp1 2>&1
	time ruby $DEBUG run.rb "$T" > $temp2 2>&1

	if diff -iwB "$temp1" "$temp2" > /dev/null; then
		# same
		echo "PASS: $T"
	else
		# differ
		echo "FAIL: $T"
		echo "# "
		#diff -uiwB "$temp1" "$temp2" | sed 's/^/# /'
		#echo "# "
		echo "# EXPECTED OUTPUT: "
		cat "$temp1" | sed 's/^/# /'
		echo "# "
		echo "# ACTUAL OUTPUT: "
		cat "$temp2" | sed 's/^/# /'
		echo "# "
	fi
	echo ""
done

if [ -f "$temp1" ]; then
	rm -f "$temp1"
fi
if [ -f "$temp2" ]; then
	rm -f "$temp2"
fi

