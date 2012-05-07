# $Id$

CONFIG=Debug
OPTIONS=

BUILD_CONFIG?=$(CONFIG)

CP=ditto --rsrc
RM=rm

.PHONY: sequel-pro test clean clean-all localize latest

sequel-pro:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) build

test:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" -target "Unit Tests" $(OPTIONS) build

clean:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" $(OPTIONS) -nodependencies clean

clean-all:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" $(OPTIONS) clean

localize:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) -target Localize

latest:
	svn update
	make sequel-pro
