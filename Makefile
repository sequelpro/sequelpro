CONFIG=Debug
OPTIONS=

BUILD_CONFIG?=$(CONFIG)

CP=ditto --rsrc
RM=rm

.PHONY: sequel-pro test analyze clean localize

sequel-pro:
	xcodebuild -project sequel-pro.xcodeproj -scheme "Sequel Pro" -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) build

test:
	xcodebuild -project sequel-pro.xcodeproj -scheme "Sequel Pro" -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) test

analyze:
	xcodebuild -project sequel-pro.xcodeproj -scheme "Sequel Pro" -configuration "$(BUILD_CONFIG)" CFLAGS="$(SP_CFLAGS)" $(OPTIONS) analyze

clean:
	xcodebuild -project sequel-pro.xcodeproj -scheme "Sequel Pro" -configuration "$(BUILD_CONFIG)" $(OPTIONS) clean

localize:
	xcodebuild -project sequel-pro.xcodeproj -scheme "Localize" -configuration "$(BUILD_CONFIG)" $(OPTIONS)
