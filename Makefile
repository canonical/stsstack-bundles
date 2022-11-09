.PHONY: lint
lint:
	for linter in "bashate --ignore E006 --verbose" "shellcheck --shell bash --severity error"; do \
		$${linter} \
			tools/*.sh \
			tools/juju-lnav \
			openstack/novarc; \
	done
