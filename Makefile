.PHONY: init_submodules up down

init_submodules:
	@git submodule update --init --recursive  --remote

run:
	@echo "Running the application..."

down:
	@echo "Stopping the application..."