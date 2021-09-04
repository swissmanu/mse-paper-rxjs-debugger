# sections = $(wildcard content/*/*.md)
paper_source = content/paper.md
paper_filename = paper

reports_source = content/reports.md
reports_filename = reports

.PHONY: default clean build build_paper_pdf build_paper_html

default: clean build

clean:
	@echo "Remove and Recreate out/"
	@rm -rf ./out
	@mkdir ./out

build: build_paper_pdf build_reports_pdf

build_paper_pdf:
	@echo "Build out/${paper_filename}.pdf"
	@pandoc \
    --lua-filter=lib/lua-filters/include-files/include-files.lua \
    --metadata-file=./metadata_paper.yml \
    -f markdown+raw_tex \
    --citeproc \
    --listings \
    --standalone \
		--template=./templates/template.tex \
		--output=out/${paper_filename}.pdf \
		${paper_source}

build_paper_html:
	@echo "Build out/${paper_filename}.html"
	@pandoc \
    --lua-filter=lib/lua-filters/include-files/include-files.lua \
    --metadata-file=./metadata_paper.yml \
    -f markdown+raw_tex \
    --citeproc \
    --listings \
    --standalone \
		--output=out/${paper_filename}.html \
		${paper_source}

build_reports_pdf:
	@echo "Build out/${reports_filename}.pdf"
	@pandoc \
    --lua-filter=lib/lua-filters/include-files/include-files.lua \
    --metadata-file=./metadata_reports.yml \
    --toc \
    -f markdown+raw_tex \
    --citeproc \
    --standalone \
		--output=out/${reports_filename}.pdf \
		${reports_source}
