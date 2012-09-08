# $Id$

CONFIG=Debug
OPTIONS=

BUILD_CONFIG?=$(CONFIG)

CP=ditto --rsrc
RM=rm

.PHONY: postgreskit test clean clean-all latest

querykit:
	xcodebuild -project PostgresKit.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) build

test:
	xcodebuild -project PostgresKit.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" -target Tests $(OPTIONS) build

clean:
	xcodebuild -project PostgresKit.xcodeproj -configuration "$(BUILD_CONFIG)" $(OPTIONS) -nodependencies clean

clean-all:
	xcodebuild -project PostgresKit.xcodeproj -configuration "$(BUILD_CONFIG)" $(OPTIONS) clean

latest:
	svn update
	make postgreskit