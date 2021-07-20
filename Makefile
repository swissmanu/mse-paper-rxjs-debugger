# sections = $(wildcard content/*/*.md)
sections = content/content.md
filename = paper

.PHONY: default clean build build_pdf build_html

default: clean build

clean:
	@echo "Remove and Recreate out/"
	@rm -rf ./out
	@mkdir ./out

build: build_pdf

build_pdf:
	@echo "Build out/${filename}.pdf"
	@pandoc \
    --lua-filter=lib/lua-filters/include-files/include-files.lua \
    --metadata-file=./metadata.yml \
    -f markdown+raw_tex \
    --citeproc \
    --listings \
    --standalone \
		--template=./templates/template.tex \
		--output=out/${filename}.pdf \
		${sections}

build_html:
	@echo "Build out/${filename}.html"
	@pandoc \
    --lua-filter=lib/lua-filters/include-files/include-files.lua \
    --metadata-file=./metadata.yml \
    -f markdown+raw_tex \
    --citeproc \
    --listings \
    --standalone \
		--output=out/${filename}.html \
		${sections}
