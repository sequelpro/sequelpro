# $Id$

CONFIG=Debug
OPTIONS=

BUILD_CONFIG?=$(CONFIG)

CP=ditto --rsrc
RM=rm

.PHONY: postgreskit test analyze clean

querykit:
	xcodebuild -project PostgresKit.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(PGK_CFLAGS)" $(OPTIONS) build

test:
	xcodebuild -project PostgresKit.xcodeproj -scheme "PostgresKit" -configuration "$(BUILD_CONFIG)" CFLAGS="$(PGK_CFLAGS)" $(OPTIONS) test

analyze:
	xcodebuild -project PostgresKit.xcodeproj -scheme "PostgresKit" -configuration "$(BUILD_CONFIG)" CFLAGS="$(PGK_CFLAGS)" $(OPTIONS) analyze

clean:
	xcodebuild -project PostgresKit.xcodeproj -configuration "$(BUILD_CONFIG)" $(OPTIONS) clean
