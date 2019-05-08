.PHONY: suse-package
suse-package:
	ci/packaging/suse/obsfiles_maker.sh "$(IMG)"

.PHONY: suse-changelog
suse-changelog:
	ci/packaging/suse/changelog_maker.sh "$(IMG)" "$(CHANGES)"
