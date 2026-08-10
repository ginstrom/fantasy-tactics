RUNS ?= 20
SCENARIO ?= scenarios/battle/baseline-party-viability.json
SEED ?= 20260810
ITERATIONS ?= 20
OUTPUT_DIR ?=

.PHONY: help editor play test check screenshots simulate scenario

help:
	@echo "make editor       Open the Godot editor"
	@echo "make play         Run the project"
	@echo "make test         Run automated tests"
	@echo "make check        Run the current validation suite"
	@echo "make screenshots  Capture a screenshot of every scene/state into ./screenshots"
	@echo "make simulate     Play N headless battles and log outcomes (RUNS=20 make simulate)"
	@echo "make scenario     Run a deterministic scenario (SCENARIO=... SEED=1 ITERATIONS=20)"

editor:
	godot --editor project.godot

play:
	godot --path .

test:
	godot --headless -s addons/gut/gut_cmdln.gd -gexit

check: test

# Screenshots need a real (or virtual) display to render into, so this can't
# use --headless like `make test` does. The window is positioned off-screen
# so it doesn't steal focus or flash on top of other windows.
screenshots:
	godot --path . --rendering-driver opengl3 --position=-3000,-3000 \
		-s scripts/tools/screenshot_tour_main.gd -- --outdir=$(CURDIR)/screenshots

simulate:
	godot --headless -s scripts/tools/battle_sim_main.gd -- --runs=$(RUNS)

scenario:
	godot --headless -s scripts/tools/battle_scenarios/scenario_runner_main.gd -- --scenario=$(SCENARIO) --seed=$(SEED) --iterations=$(ITERATIONS) --output-dir=$(OUTPUT_DIR)
