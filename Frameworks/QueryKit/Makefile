# $Id$

CONFIG=Debug
OPTIONS=

BUILD_CONFIG?=$(CONFIG)

CP=ditto --rsrc
RM=rm

.PHONY: querykit test analyze clean latest

querykit:
	xcodebuild -project QueryKit.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(QK_CFLAGS)" $(OPTIONS) build

test:
	xcodebuild -project QueryKit.xcodeproj -scheme "QueryKit" -configuration "$(BUILD_CONFIG)" CFLAGS="$(QK_CFLAGS)" $(OPTIONS) test

analyze:
	xcodebuild -project QueryKit.xcodeproj -scheme "QueryKit" -configuration "$(BUILD_CONFIG)" CFLAGS="$(QK_CFLAGS)" $(OPTIONS) analyze

clean:
	xcodebuild -project QueryKit.xcodeproj -configuration "$(BUILD_CONFIG)" $(OPTIONS) clean
