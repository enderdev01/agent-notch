APP_NAME  := Agent Notch
BUILD_DIR := build
APP       := $(BUILD_DIR)/$(APP_NAME).app
BIN       := .build/release/AgentNotch

.PHONY: build app run install clean

build:
	swift build -c release

app: build
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BIN)" "$(APP)/Contents/MacOS/AgentNotch"
	cp packaging/Info.plist "$(APP)/Contents/Info.plist"
	cp Sources/AgentNotch/Resources/Mascots/*.png "$(APP)/Contents/Resources/"
	cp packaging/AppIcon.icns "$(APP)/Contents/Resources/"
	# The hook installer ships inside the app: install.sh resolves bridge/ and integrations/ relative to its own folder.
	mkdir -p "$(APP)/Contents/Resources/scripts"
	cp -R bridge integrations "$(APP)/Contents/Resources/"
	cp scripts/install.sh scripts/uninstall.sh scripts/lib.sh "$(APP)/Contents/Resources/scripts/"
	codesign --force -s - "$(APP)"
	@echo "Built $(APP)"

run: build
	$(BIN)

install:
	./scripts/install.sh

clean:
	swift package clean
	rm -rf $(BUILD_DIR) .build
