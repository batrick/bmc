PDFLATEX       := pdflatex
PDFLATEX_FLAGS := -interaction=nonstopmode -halt-on-error -shell-escape
INKSCAPE       := inkscape
QRENCODE       := qrencode

FLYER_DIR      := flyers
ASSET_DIR      := assets
BUILD_DIR      := build
SVG_CACHE_DIR  := svg-inkscape

CLUB_URL       := https://bedfordmensclub.clubexpress.com
FB_URL         := https://www.facebook.com/bedfordmensclub
QR_PNG         := $(BUILD_DIR)/club-qr.png
FB_QR_PNG      := $(BUILD_DIR)/fb-qr.png

FLYERS := $(wildcard $(FLYER_DIR)/*.tex)
PDFS   := $(patsubst $(FLYER_DIR)/%.tex,$(BUILD_DIR)/%.pdf,$(FLYERS))
SVGS   := $(wildcard $(ASSET_DIR)/logos/*.svg $(ASSET_DIR)/illustrations/*.svg)

.PHONY: all clean distclean check-tools help

all: check-tools $(PDFS)

check-tools:
	@command -v $(PDFLATEX) >/dev/null 2>&1 || { \
		echo "Error: '$(PDFLATEX)' not found. Install TeX Live."; \
		exit 1; \
	}
	@command -v $(INKSCAPE) >/dev/null 2>&1 || { \
		echo "Error: '$(INKSCAPE)' not found. LaTeX's svg package requires Inkscape (sudo pacman -S inkscape)."; \
		exit 1; \
	}
	@command -v $(QRENCODE) >/dev/null 2>&1 || { \
		echo "Error: '$(QRENCODE)' not found. Install qrencode (sudo pacman -S qrencode)."; \
		exit 1; \
	}

$(QR_PNG): Makefile
	@mkdir -p $(BUILD_DIR)
	$(QRENCODE) -o $@ -s 8 -m 1 "$(CLUB_URL)"

$(FB_QR_PNG): Makefile
	@mkdir -p $(BUILD_DIR)
	$(QRENCODE) -o $@ -s 8 -m 1 "$(FB_URL)"

$(BUILD_DIR)/%.pdf: $(FLYER_DIR)/%.tex $(SVGS) $(QR_PNG) $(FB_QR_PNG)
	@mkdir -p $(BUILD_DIR)/$(SVG_CACHE_DIR)
	@ln -sfn ../$(ASSET_DIR) $(BUILD_DIR)/$(ASSET_DIR)
	@cp -f $(SVGS) $(BUILD_DIR)/
	@set -e; for svg in $(SVGS); do \
		base=$$(basename $$svg .svg); \
		$(INKSCAPE) --export-area-drawing --export-type=pdf --export-latex \
			--export-filename="$(BUILD_DIR)/$(SVG_CACHE_DIR)/$${base}_svg-tex.pdf" "$$svg"; \
	done
	cd $(BUILD_DIR) && $(PDFLATEX) $(PDFLATEX_FLAGS) ../$<
	@if grep -q "Rerun to get" $(BUILD_DIR)/$*.log 2>/dev/null; then \
		cd $(BUILD_DIR) && $(PDFLATEX) $(PDFLATEX_FLAGS) ../$<; \
	fi

clean:
	rm -rf $(SVG_CACHE_DIR) $(BUILD_DIR)/$(SVG_CACHE_DIR)
	rm -f $(BUILD_DIR)/$(ASSET_DIR) $(BUILD_DIR)/*.svg $(QR_PNG) $(FB_QR_PNG)
	rm -f $(BUILD_DIR)/*.aux $(BUILD_DIR)/*.log $(BUILD_DIR)/*.out $(BUILD_DIR)/*.w18 \
	      $(BUILD_DIR)/*.toc $(BUILD_DIR)/*.fls $(BUILD_DIR)/*.fdb_latexmk \
	      $(BUILD_DIR)/*.synctex.gz $(BUILD_DIR)/*_svg-tex.pdf $(BUILD_DIR)/*_svg-tex.pdf_tex
	rm -f $(FLYER_DIR)/*.aux $(FLYER_DIR)/*.log $(FLYER_DIR)/*.out $(FLYER_DIR)/*.w18 \
	      $(FLYER_DIR)/*.fls $(FLYER_DIR)/*.fdb_latexmk $(FLYER_DIR)/*.synctex.gz
	rm -f *.aux *.log *.out *.w18 *.fls *.fdb_latexmk *.synctex.gz

distclean: clean
	rm -rf $(BUILD_DIR)

help:
	@echo "Usage: make [target]"
	@echo "  all        Build all flyer PDFs into $(BUILD_DIR)/ (default)"
	@echo "  clean      Remove intermediate LaTeX and svg-inkscape build files"
	@echo "  distclean  Remove all intermediate files and compiled PDFs"