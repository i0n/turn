SHELL := /bin/bash
NAME := turn
GCR_NAME := gcr.io/organic-spirit-217211/${NAME}
GO := go
REV := $(shell git rev-parse --short HEAD 2> /dev/null || echo 'unknown')
ROOT_PACKAGE := github.com/pions/turn
GO_VERSION := $(shell $(GO) version | sed -e 's/^[^0-9.]*\([0-9.]*\).*/\1/')
PKGS := $(shell go list ./... | grep -v /vendor | grep -v generated)

BRANCH     := $(shell git rev-parse --abbrev-ref HEAD 2> /dev/null  || echo 'unknown')
BUILD_DATE := $(shell date +%Y%m%d-%H:%M:%S)
CGO_ENABLED = 0

all: build

check: fmt build test

version:
ifeq (,$(wildcard pkg/version/VERSION))
TAG := $(shell git fetch --all -q 2>/dev/null && git describe --abbrev=0 --tags 2>/dev/null)
ON_EXACT_TAG := $(shell git name-rev --name-only --tags --no-undefined HEAD 2>/dev/null | sed -n 's/^\([^^~]\{1,\}\)\(\^0\)\{0,1\}$$/\1/p')
VERSION := $(shell [ -z "$(ON_EXACT_TAG)" ] && echo "$(TAG)-dev-$(REV)" | sed 's/^v//' || echo "$(TAG)" | sed 's/^v//' )
else
VERSION := $(shell cat pkg/version/VERSION)
endif
BUILDFLAGS := -ldflags \
  " -X $(ROOT_PACKAGE)/pkg/version.Version=$(VERSION)\
		-X $(ROOT_PACKAGE)/pkg/version.Revision='$(REV)'\
		-X $(ROOT_PACKAGE)/pkg/version.Branch='$(BRANCH)'\
		-X $(ROOT_PACKAGE)/pkg/version.BuildDate='$(BUILD_DATE)'\
		-X $(ROOT_PACKAGE)/pkg/version.GoVersion='$(GO_VERSION)'"

print-version: version
	@echo $(VERSION)

build: version
	CGO_ENABLED=$(CGO_ENABLED) $(GO) build $(BUILDFLAGS) -o build/$(NAME) cmd/simple-turn/main.go

linux: version
	CGO_ENABLED=$(CGO_ENABLED) GOOS=linux GOARCH=amd64 $(GO) build $(BUILDFLAGS) -o build/linux/$(NAME) cmd/simple-turn/main.go

docker-build-latest:
	docker build . -t ${GCR_NAME}:latest

docker-build:
	docker build . --build-arg VERSION=$(VERSION) -t ${GCR_NAME}:latest
	docker tag ${GCR_NAME}:latest ${GCR_NAME}:$(VERSION)

docker-push:
	docker push ${GCR_NAME}:latest
	docker push ${GCR_NAME}:$(VERSION)

docker: docker-build docker-push

get-test-deps:
	@$(GO) get github.com/axw/gocov/gocov
	@$(GO) get -u gopkg.in/matm/v1/gocov-html

test:
	@CGO_ENABLED=$(CGO_ENABLED) $(GO) test -count=1 -coverprofile=cover.out -failfast -short -parallel 12 ./...

test-report: get-test-deps test
	@gocov convert cover.out | gocov report

test-report-html: get-test-deps test
	@gocov convert cover.out | gocov-html > cover.html && open cover.html

bootstrap: vendoring

clean:
	rm -rf build release cover.out cover.html
