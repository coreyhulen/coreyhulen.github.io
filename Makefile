.PHONY: run install

all: run

install:
	@echo Installing
	gem install github-pages


run:
	@echo Running
	open http://127.0.0.1:4000/
	jekyll serve
