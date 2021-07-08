# Makefile for OpenCraft deployment instructions.
all: install_prereqs compile

compile:
	mkdocs build

install_prereqs:
	pip install pip-tools
	pip-sync

upgrade:
	pip-compile requirements.in

run:
	mkdocs serve

clean:
	rm -rvf build