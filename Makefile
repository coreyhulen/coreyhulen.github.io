.PHONY: run install

all: run

install:
	@echo Installing
	brew install ruby
	sudo gem install bundler jekyll jekyll-sitemap jekyll-feed
	sudo gem install github-pages


run:
	@echo Running
	open http://127.0.0.1:4000/
	jekyll serve
