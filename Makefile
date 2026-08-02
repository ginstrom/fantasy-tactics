.PHONY: help editor play test check

help:
	@echo "make editor  Open the Godot editor"
	@echo "make play    Run the project"
	@echo "make test    Run automated tests"
	@echo "make check   Run the current validation suite"

editor:
	godot --editor project.godot

play:
	godot --path .

test:
	godot --headless -s addons/gut/gut_cmdln.gd -gexit

check: test
