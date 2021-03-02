# Inspiration:
# - https://devhints.io/makefile
# - https://tech.davis-hansson.com/p/make/
# - https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

SHELL := bash

# Default - top level rule is what gets run when you run just 'make' without specifying a goal/target.
.DEFAULT_GOAL := build

.DELETE_ON_ERROR:
.ONESHELL:
.SHELLFLAGS := -euo pipefail -c

MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --warn-undefined-variables

ifeq ($(origin .RECIPEPREFIX), undefined)
  $(error This Make does not support .RECIPEPREFIX. Please use GNU Make 4.0 or later.)
endif
.RECIPEPREFIX = >

binary_name ?= $(shell basename $(CURDIR))
image_repository ?= jlucktay/$(binary_name)

# Adjust the width of the first column by changing the '-20s' value in the printf pattern.
help:
> @grep -E '^[a-zA-Z0-9_-]+:.*? ## .*$$' $(MAKEFILE_LIST) | sort \
> | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
.PHONY: help

all: test lint build ## Test and lint and build.
test: tmp/.tests-passed.sentinel ## Run tests.
test-cover: tmp/.cover-tests-passed.sentinel ## Run all tests with the race detector and output a coverage profile.
bench: tmp/.benchmarks-ran.sentinel ## Run enough iterations of each benchmark to take ten seconds each.
lint: tmp/.linted.sentinel ## Lint the Dockerfile and all of the Go code. Will also test.
build: out/image-id ## [DEFAULT] Build the Docker image. Will also test and lint.
build-binary: $(binary_name) ## Build a bare binary only, without a Docker image wrapped around it.
.PHONY: all test test-cover bench lint build build-binary

clean: ## Clean up the built binary, test coverage, and the temp and output sub-directories.
> go clean -x -v
> rm -rf cover.out tmp out
.PHONY: clean

clean-docker: ## Clean up any built Docker images.
> docker images \
  --filter=reference=$(image_repository) \
  --no-trunc --quiet | sort -f | uniq | xargs -n 1 docker rmi --force
> rm -f out/image-id
.PHONY: clean-docker

clean-hack: ## Clean up binaries under 'hack'.
> rm -rf hack/bin
.PHONY: clean-hack

clean-all: clean clean-docker clean-hack ## Clean all of the things.
.PHONY: clean-all

# Tests - re-run if any Go files have changes since tmp/.tests-passed.sentinel was last touched.
tmp/.tests-passed.sentinel: $(shell find . -type f -iname "*.go")
> mkdir -p $(@D)
> go test ./...
> touch $@

tmp/.cover-tests-passed.sentinel: $(shell find . -type f -iname "*.go")
> mkdir -p $(@D)
> go test -count=1 -covermode=atomic -coverprofile=cover.out -race ./...
> touch $@

tmp/.benchmarks-ran.sentinel: $(shell find . -type f -iname "*.go")
> mkdir -p $(@D)
> go test ./... -bench=. -benchmem -benchtime=10s -run=DoNotRunTests
> touch $@

# Lint - re-run if the tests have been re-run (and so, by proxy, whenever the source files have changed).
tmp/.linted.sentinel: Dockerfile .golangci.yaml .hadolint.yaml hack/bin/golangci-lint tmp/.tests-passed.sentinel
> mkdir -p $(@D)
> docker run --env XDG_CONFIG_HOME=/etc --interactive --rm \
> --volume "$(shell pwd)/.hadolint.yaml:/etc/hadolint.yaml:ro" hadolint/hadolint < Dockerfile
> find . -type f -iname "*.go" -not -name "bindata.go" -exec gofmt -e -l -s "{}" + \
> | awk '{ print } END { if (NR != 0) { print "gofmt found issues in the above file(s); \
please run \"make lint-simplify\" to remedy"; exit 1 } }'
> go vet ./...
> hack/bin/golangci-lint run
> touch $@

lint-simplify: ## Runs 'gofmt -s' to format and simplify all Go code.
> find . -type f -iname "*.go" -exec gofmt -s -w "{}" +
.PHONY: lint-simplify

hack/bin/golangci-lint:
> curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh \
> | sh -s -- -b $(shell pwd)/hack/bin

# Docker image - re-build if the lint output is re-run.
out/image-id: Dockerfile tmp/.linted.sentinel
> mkdir -p $(@D)
> image_id="$(image_repository):$(shell uuidgen)"
> DOCKER_BUILDKIT=1 docker build --tag="$${image_id}" .
> echo "$${image_id}" > out/image-id

$(binary_name): tmp/.linted.sentinel
> go build -ldflags="-buildid= -w" -trimpath -v
