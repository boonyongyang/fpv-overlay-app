SHELL := /bin/bash

FVM ?= fvm
FLUTTER := $(FVM) flutter
DART := $(FVM) dart
UTF8_ENV := LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
DMG_SCRIPT := ./tools/create_dmg.sh
PREPARE_RUNTIME_SCRIPT := ./tools/prepare_macos_app_runtime.sh

.PHONY: help pub-get pods bootstrap format analyze test check runtime-check clean build-macos-debug build-macos-release package-macos-runtime dmg release

help: ## Show available commands
	@grep -E '^[a-zA-Z0-9._-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "%-22s %s\n", $$1, $$2}'

pub-get: ## Install Flutter/Dart dependencies with FVM
	$(FLUTTER) pub get

pods: ## Install macOS CocoaPods dependencies
	cd macos && env $(UTF8_ENV) pod install

bootstrap: pub-get pods ## Install Flutter packages and CocoaPods

format: ## Format Dart source files
	$(DART) format lib test

analyze: ## Run Flutter static analysis
	$(FLUTTER) analyze

test: ## Run the Flutter test suite
	$(FLUTTER) test

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

dmg: ## Package the existing release app into a DMG
	$(DMG_SCRIPT)

release: bootstrap check build-macos-release dmg ## Full release flow
