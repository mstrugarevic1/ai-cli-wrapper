lint:
	zsh -n scripts/ai-safe.zsh
	bash -n scripts/ai-safe.bash
	bash -n install.sh

update:
	git pull
	./install.sh
