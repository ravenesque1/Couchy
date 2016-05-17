#!/bin/bash
STABLE_VERSION="\"v1.1\""
SRC=""

SOURCE=""
VERSION=""

is_default=false

if [ $# -eq 0 ]; then
	echo "⚠️	Warning: no option given, performing local update."
	SRC="git \"Couchy\" "
	is_default=true
	SOURCE=" local store"
else
	if [ $1 == "remote" ]; then
		echo "ℹ️	Performing remote update."
		SRC="github \"ravenesque1/Couchy\" "
		SOURCE="remote source"
	elif [ $1 == "local" ]; then
		echo "ℹ️	Performing local update."
		SRC="git \"file://$(pwd)/../Couchy\" "
		SOURCE="local store"
	else
		SRC="git \"file://$(pwd)/../Couchy\" "
		is_default=true
		SOURCE="local store"
	fi
fi

if [ ! -z $2 ] && [ "$is_default" == false ]; then
	SRC=$SRC"\"$2\""
	VERSION=$2
else
	SRC=$SRC$STABLE_VERSION
	VERSION="v1.1"
fi

cd Couchy/source
sh upd.sh "$SRC" "$SOURCE" "$VERSION"