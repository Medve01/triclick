APP_NAME     := Triclick
BUNDLE_ID    := dev.medve01.Triclick
VERSION      := 1.0.1
BUILD_DIR    := build
APP_DIR      := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS     := $(APP_DIR)/Contents
MACOS_DIR    := $(CONTENTS)/MacOS
RES_DIR      := $(CONTENTS)/Resources
DIST_DIR     := dist
DMG_NAME     := $(APP_NAME)-$(VERSION).dmg

SWIFTC       := swiftc
SDK          := $(shell xcrun --show-sdk-path)
SWIFT_FILES  := $(wildcard Sources/*.swift)

CFLAGS       := -sdk $(SDK) -O -whole-module-optimization
FRAMEWORKS   := -framework AppKit \
                -framework Cocoa \
                -framework CoreGraphics \
                -framework Foundation \
                -framework ApplicationServices \
                -framework ServiceManagement \
                -framework IOKit \
                -F /System/Library/PrivateFrameworks \
                -framework MultitouchSupport

.PHONY: all app run dmg clean install

all: app

app: $(APP_DIR)/Contents/MacOS/$(APP_NAME)

$(APP_DIR)/Contents/MacOS/$(APP_NAME): $(SWIFT_FILES) Resources/Info.plist
	@mkdir -p "$(MACOS_DIR)" "$(RES_DIR)"
	@echo "→ Compiling $(APP_NAME)…"
	$(SWIFTC) $(SWIFT_FILES) -o "$(MACOS_DIR)/$(APP_NAME)" $(CFLAGS) $(FRAMEWORKS)
	@cp Resources/Info.plist "$(CONTENTS)/Info.plist"
	@# Ad-hoc sign so Gatekeeper treats it as a local build (no Developer ID needed).
	@codesign --force --deep --sign - "$(APP_DIR)"
	@echo "✓ Built $(APP_DIR)"

run: app
	@open "$(APP_DIR)"

install: app
	@echo "→ Installing to /Applications/$(APP_NAME).app"
	@rm -rf "/Applications/$(APP_NAME).app"
	@cp -R "$(APP_DIR)" "/Applications/$(APP_NAME).app"
	@codesign --force --deep --sign - "/Applications/$(APP_NAME).app"
	@echo "✓ Installed. Launch from Applications, then grant Accessibility."

dmg: app
	@mkdir -p "$(DIST_DIR)"
	@rm -f "$(DIST_DIR)/$(DMG_NAME)"
	@echo "→ Creating $(DMG_NAME)…"
	@STAGE=$$(mktemp -d); \
	  cp -R "$(APP_DIR)" "$$STAGE/"; \
	  ln -s /Applications "$$STAGE/Applications"; \
	  hdiutil create -volname "$(APP_NAME)" -srcfolder "$$STAGE" -ov -format UDZO "$(DIST_DIR)/$(DMG_NAME)"; \
	  rm -rf "$$STAGE"
	@shasum -a 256 "$(DIST_DIR)/$(DMG_NAME)" | tee "$(DIST_DIR)/$(DMG_NAME).sha256"
	@echo "✓ DMG ready at $(DIST_DIR)/$(DMG_NAME)"

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"
