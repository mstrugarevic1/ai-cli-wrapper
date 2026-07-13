lint:
	zsh -n scripts/ai-safe.sh
	bash -n scripts/ai-safe.sh
	bash -n install.sh
	bash tests/preflight.sh

update:
	git pull
	./install.sh
