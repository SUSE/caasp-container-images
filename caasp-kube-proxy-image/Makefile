mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir  := $(shell basename $(dir $(mkfile_path)))

.PHONY: suse-package
suse-package:
	make -C .. IMG="$(mkfile_dir)" suse-package

.PHONY: suse-changelog
suse-changelog:
	make -C .. IMG="$(mkfile_dir)" CHANGES=$(CHANGES) suse-changelog
