CONFIG=Debug
OPTIONS=

BUILD_CONFIG?=$(CONFIG)

CP=ditto --rsrc
RM=rm

.PHONY: sequel-pro test clean localize latest

sequel-pro:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) build

test:
	xcodebuild -project sequel-pro.xcodeproj -scheme "Sequel Pro" -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) test

analyze:
	xcodebuild -project sequel-pro.xcodeproj -scheme "Sequel Pro" -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) analyze

clean:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" $(OPTIONS) clean

localize:
	xcodebuild -project sequel-pro.xcodeproj -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) -target Localize

latest:
	svn update
	make sequel-pro
