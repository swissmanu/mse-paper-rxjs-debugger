sections = $(wildcard sections/*/*.md)
filename = paper

.PHONY: default clean clean_diagrams clean_build build build_pdf force


default: clean_build build


clean_build:
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
    --standalone \
		--template=./templates/template.tex \
		--output=out/${filename}.pdf \
		${sections}
