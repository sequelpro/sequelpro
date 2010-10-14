# $Id$

CONFIG=Release

BUILD_CONFIG?=$(CONFIG)

CP=ditto --rsrc
RM=rm

.PHONY: sequel-pro test clean clean-all localize latest

sequel-pro:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" build

test:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" -target "Unit Tests" build

clean:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" -nodependencies clean

clean-all:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" clean

localize:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" -target Localize

latest:
	svn update
	make sequel-pro
