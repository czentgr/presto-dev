ORG ?= $(shell git remote get-url origin | sed -E 's|.*[:/]([^/]+)/[^/]+(\.git)?$$|\1|')
DOCKER_CMD ?= $(shell if podman info > /dev/null 2>&1; then echo podman; else echo docker; fi)
CLEAN_CACHE ?= false
NUM_THREADS ?= 3
VERSION ?= $(shell grep -m 1 '^    <version>' ../pom.xml | sed -e 's/.*<version>\([^<]*\)<\/version>.*/\1/' -e 's/-SNAPSHOT//')
COMMIT_ID ?= $(shell git -C .. rev-parse --short origin/master)

.PHONY: build centos-dep ubuntu-dep centos-cpp-dev ubuntu-cpp-dev centos-dev ubuntu-dev \
	release-prepare release-publish pull-centos pull-ubuntu tag-centos-latest tag-ubuntu-latest \
	stop-centos stop-ubuntu vscode start stop info shell-centos shell-ubuntu

centos-dep:
	cd ../presto-native-execution && make submodules && $(DOCKER_CMD) compose build centos-native-dependency

ubuntu-dep:
	cd ../presto-native-execution && make submodules && $(DOCKER_CMD) compose build ubuntu-native-dependency

centos-cpp-dev:
	$(DOCKER_CMD) compose build --build-arg CLEAN_CACHE=$(CLEAN_CACHE) --build-arg NUM_THREADS=$(NUM_THREADS) centos-cpp-dev

ubuntu-cpp-dev:
	$(DOCKER_CMD) compose build --build-arg CLEAN_CACHE=$(CLEAN_CACHE) --build-arg NUM_THREADS=$(NUM_THREADS) ubuntu-cpp-dev

centos-dev:
	$(DOCKER_CMD) compose build centos-dev

ubuntu-dev:
	$(DOCKER_CMD) compose build ubuntu-dev

release-prepare:
	ORG=$(ORG) DOCKER_CMD=$(DOCKER_CMD) ./scripts/release.sh prepare

release-publish:
	ORG=$(ORG) DOCKER_CMD=$(DOCKER_CMD) ./scripts/release.sh publish

pull-centos:
	@if [ -z "$$($(DOCKER_CMD) images -q docker.io/presto/presto-dev:centos9)" ]; then \
		echo "Image not found locally. Pulling..."; \
		$(DOCKER_CMD) pull ${ORG}/presto-dev:latest-centos; \
		$(DOCKER_CMD) tag ${ORG}/presto-dev:latest-centos docker.io/presto/presto-dev:centos9; \
	else \
		echo "Image docker.io/presto/presto-dev:centos9 already exists locally."; \
	fi

pull-ubuntu:
	@if [ -z "$$($(DOCKER_CMD) images -q docker.io/presto/presto-dev:ubuntu-22.04)" ]; then \
		echo "Image not found locally. Pulling..."; \
		$(DOCKER_CMD) pull ${ORG}/presto-dev:latest-ubuntu; \
		$(DOCKER_CMD) tag ${ORG}/presto-dev:latest-ubuntu docker.io/presto/presto-dev:ubuntu-22.04; \
	else \
		echo "Image docker.io/presto/presto-dev:ubuntu-22.04 already exists locally."; \
	fi

tag-centos-latest:
	ORG=$(ORG) DOCKER_CMD=$(DOCKER_CMD) ./scripts/release.sh manifest-latest centos

tag-ubuntu-latest:
	ORG=$(ORG) DOCKER_CMD=$(DOCKER_CMD) ./scripts/release.sh manifest-latest ubuntu

vscode:
	@mkdir -p ../.vscode && \
	if [ ! -f "../.vscode/launch.json" ]; then \
		cp ./launch.json ../.vscode/launch.json; \
	fi

start-centos: vscode pull-centos
	${DOCKER_CMD} compose up centos-dev -d
	${DOCKER_CMD} ps | grep presto-dev

start-ubuntu: vscode pull-ubuntu
	${DOCKER_CMD} compose up ubuntu-dev -d
	${DOCKER_CMD} ps | grep presto-dev

stop-centos:
	${DOCKER_CMD} compose down centos-dev

stop-ubuntu:
	${DOCKER_CMD} compose down ubuntu-dev

shell-centos:
	${DOCKER_CMD} compose exec -it centos-dev bash

shell-ubuntu:
	${DOCKER_CMD} compose exec -it ubuntu-dev bash

start: start-centos

stop: stop-centos

shell: shell-centos

info:
	@echo ${DOCKER_CMD} ${ORG} ${VERSION} ${COMMIT_ID}
