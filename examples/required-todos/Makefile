all: main.js index.html
%.js: %.coffee
	coffee -c $<
%.html: %.jade
	jade $<
