.PHONY: test

test:
	nvim --headless -u NONE -c 'set rtp^=.' -l tests/run.lua
