SHELL := /bin/bash

FVM ?= fvm
FLUTTER := $(FVM) flutter
DART := $(FVM) dart
PWSH ?= pwsh
UTF8_ENV := LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
DMG_SCRIPT := ./tools/create_dmg.sh
PREPARE_RUNTIME_SCRIPT := ./tools/prepare_macos_app_runtime.sh
PREPARE_WINDOWS_RUNTIME_SCRIPT := ./tools/prepare_windows_release.ps1
WINDOWS_INSTALLER_SCRIPT := ./tools/create_windows_installer.ps1
BUILD_CLI_RUNTIME_SCRIPT := ./tools/build_cli_runtime_macos.sh
BUILD_CLI_RELEASE_SCRIPT := ./tools/build_cli_release_macos.sh
SMOKE_TEST_CLI_BUNDLE_SCRIPT := ./tools/smoke_test_cli_bundle.sh
RENDER_HOMEBREW_FORMULA_SCRIPT := ./tools/render_homebrew_formula.sh

.PHONY: help pub-get cli-pub-get pods bootstrap format analyze test cli-test verify-cli-release-metadata smoke-test-cli-bundle check runtime-check clean build-macos-debug build-macos-release package-macos-runtime build-cli-runtime-macos build-cli-release-macos render-homebrew-formula dmg release build-windows-release package-windows-runtime windows-installer

help: ## Show available commands
	@grep -E '^[a-zA-Z0-9._-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "%-22s %s\n", $$1, $$2}'

pub-get: ## Install Flutter/Dart dependencies with FVM
	$(FLUTTER) pub get

cli-pub-get: ## Install CLI and shared-core Dart dependencies
	cd cli && $(DART) pub get
	cd packages/overlay_core && $(DART) pub get

pods: ## Install macOS CocoaPods dependencies
	cd macos && env $(UTF8_ENV) pod install

bootstrap: pub-get pods ## Install Flutter packages and CocoaPods

format: ## Format Dart source files
	$(DART) format lib test

analyze: ## Run Flutter static analysis
	$(FLUTTER) analyze

test: ## Run the Flutter test suite
	$(FLUTTER) test

cli-test: ## Run the shared core Dart test suite
	cd packages/overlay_core && $(DART) test

verify-cli-release-metadata: ## Check CLI version and Homebrew release metadata wiring
	./tools/verify_cli_release_metadata.sh

smoke-test-cli-bundle: ## Smoke-test a built CLI bundle (pass ARGS='--bundle-dir ...' or '--archive ...')
	$(SMOKE_TEST_CLI_BUNDLE_SCRIPT) $(ARGS)

check: analyze test ## Run analyzer and tests

runtime-check: ## Print local ffmpeg/python runtime availability
	@echo "ffmpeg:"
	@which ffmpeg || true
	@echo
	@echo "python3:"
	@which python3 || true
	@echo
	@python3 -c "import sys; print(sys.executable); import numpy, PIL, pandas; print('python-deps: ok')" || true

clean: ## Clean Flutter/macOS build artifacts
	$(FLUTTER) clean
	rm -rf dist

build-macos-debug: ## Build the macOS debug app
	env $(UTF8_ENV) $(FLUTTER) build macos --debug

build-macos-release: ## Build the macOS release app
	env $(UTF8_ENV) $(FLUTTER) build macos --release

package-macos-runtime: ## Bundle ffmpeg and standalone overlay executables into the release app
	$(PREPARE_RUNTIME_SCRIPT)

build-cli-runtime-macos: ## Build the standalone macOS CLI runtime payload
	$(BUILD_CLI_RUNTIME_SCRIPT)

build-cli-release-macos: ## Build the standalone macOS CLI release tarball
	$(BUILD_CLI_RELEASE_SCRIPT)

render-homebrew-formula: ## Render a filled Homebrew formula from the template (requires args)
	$(RENDER_HOMEBREW_FORMULA_SCRIPT) $(ARGS)

dmg: ## Package the existing release app into a DMG
	$(DMG_SCRIPT)

release: bootstrap check build-macos-release package-macos-runtime dmg ## Full release flow

build-windows-release: ## Build the Windows release app (run on Windows)
	$(FLUTTER) build windows --release

package-windows-runtime: ## Bundle ffmpeg and standalone overlay executables into the Windows release app (run on Windows)
	$(PWSH) -NoProfile -ExecutionPolicy Bypass -File $(PREPARE_WINDOWS_RUNTIME_SCRIPT)

windows-installer: ## Build the Windows installer EXE with Inno Setup (run on Windows)
	$(PWSH) -NoProfile -ExecutionPolicy Bypass -File $(WINDOWS_INSTALLER_SCRIPT)
