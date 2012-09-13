# $Id: Makefile 3740 2012-07-21 10:36:05Z stuart02 $

CONFIG=Debug
OPTIONS=

BUILD_CONFIG?=$(CONFIG)

CP=ditto --rsrc
RM=rm

.PHONY: querykit test clean clean-all latest

querykit:
	xcodebuild -project QueryKit.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) build

test:
	xcodebuild -project QueryKit.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" -target Tests $(OPTIONS) build

clean:
	xcodebuild -project QueryKit.xcodeproj -configuration "$(BUILD_CONFIG)" $(OPTIONS) -nodependencies clean

clean-all:
	xcodebuild -project QueryKit.xcodeproj -configuration "$(BUILD_CONFIG)" $(OPTIONS) clean

latest:
	svn update
	make querykit
