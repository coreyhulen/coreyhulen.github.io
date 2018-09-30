.PHONY: run install

all: run

install-mac:
	@echo Installing
	brew install ruby
	sudo gem install bundler jekyll jekyll-sitemap jekyll-feed
	sudo gem install github-pages


run-mac:
	@echo Running
	open http://127.0.0.1:4000/
	jekyll serve

run-win:
	@echo Running
	-(sleep 2 && explorer.exe http://127.0.0.1:4000/)&
	jekyll serve

run: run-win