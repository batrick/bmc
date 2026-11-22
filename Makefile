PDFLATEX       := pdflatex
PDFLATEX_FLAGS := -interaction=nonstopmode -halt-on-error -shell-escape
INKSCAPE       := inkscape
QRENCODE       := qrencode
MAGICK         := magick

FLYER_DIR      := flyers
ASSET_DIR      := assets
BUILD_DIR      := build
SVG_CACHE_DIR  := svg-inkscape
FAVICON_DIR    := $(BUILD_DIR)/favicons
LOGO_DIR       := $(BUILD_DIR)/logos

LOGO_SVG       := $(ASSET_DIR)/logos/bmc-v4.svg
ICON_BG        := \#FFFFFF

CLUB_URL       := https://bedfordmensclub.clubexpress.com
FB_URL         := https://www.facebook.com/bedfordmensclub
QR_PNG         := $(BUILD_DIR)/club-qr.png
FB_QR_PNG      := $(BUILD_DIR)/fb-qr.png

FLYERS := $(wildcard $(FLYER_DIR)/*.tex)
PDFS   := $(patsubst $(FLYER_DIR)/%.tex,$(BUILD_DIR)/%.pdf,$(FLYERS))
SVGS   := $(wildcard $(ASSET_DIR)/logos/*.svg $(ASSET_DIR)/illustrations/*.svg)

# High-res master raster rendered once by Inkscape, then downscaled by ImageMagick
LOGO_MASTER_PNG := $(LOGO_DIR)/bmc-logo-4096.png

# Favicon & web/PWA icon outputs
FAVICON_TARGETS := \
	$(FAVICON_DIR)/icon.svg \
	$(FAVICON_DIR)/favicon.ico \
	$(FAVICON_DIR)/favicon-16x16.png \
	$(FAVICON_DIR)/favicon-32x32.png \
	$(FAVICON_DIR)/favicon-48x48.png \
	$(FAVICON_DIR)/apple-touch-icon.png \
	$(FAVICON_DIR)/icon-192.png \
	$(FAVICON_DIR)/icon-512.png \
	$(FAVICON_DIR)/icon-mask.png

# Standard logo outputs for web, social media, presentations, and print
LOGO_PNG_SIZES    := 256 512 1024 2048
LOGO_JPG_SIZES    := 1024 2048
AVATAR_PNG_SIZES  := 512 1024 2048

LOGO_TARGETS := \
	$(LOGO_MASTER_PNG) \
	$(foreach s,$(LOGO_PNG_SIZES),$(LOGO_DIR)/bmc-logo-$(s).png) \
	$(foreach s,$(LOGO_JPG_SIZES),$(LOGO_DIR)/bmc-logo-$(s).jpg) \
	$(foreach s,$(AVATAR_PNG_SIZES),$(LOGO_DIR)/bmc-avatar-$(s).png)

.PHONY: all flyers favicons logos images clean distclean \
        check-tools check-flyer-tools check-image-tools help

all: flyers images

flyers: check-flyer-tools $(PDFS)

favicons: check-image-tools $(FAVICON_TARGETS)

logos: check-image-tools $(LOGO_TARGETS)

images: favicons logos

check-tools: check-flyer-tools check-image-tools

check-flyer-tools:
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

check-image-tools:
	@command -v $(INKSCAPE) >/dev/null 2>&1 || { \
		echo "Error: '$(INKSCAPE)' not found. Install Inkscape (sudo pacman -S inkscape)."; \
		exit 1; \
	}
	@command -v $(MAGICK) >/dev/null 2>&1 || { \
		echo "Error: '$(MAGICK)' not found. Install ImageMagick (sudo pacman -S imagemagick)."; \
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

# Render 4096px-tall master PNG via Inkscape for accurate SVG gradients and curves
$(LOGO_MASTER_PNG): $(LOGO_SVG)
	@mkdir -p $(LOGO_DIR)
	$(INKSCAPE) --export-type=png --export-height=4096 --export-filename="$@" "$<"

# Proportional transparent PNGs (longest edge sized to %, preserves 654:745 shield ratio)
$(LOGO_DIR)/bmc-logo-%.png: $(LOGO_MASTER_PNG)
	@mkdir -p $(LOGO_DIR)
	$(MAGICK) "$<" -resize $*x$* "$@"

# Proportional opaque JPGs on solid background
$(LOGO_DIR)/bmc-logo-%.jpg: $(LOGO_MASTER_PNG)
	@mkdir -p $(LOGO_DIR)
	$(MAGICK) "$<" -resize $*x$* -background "$(ICON_BG)" -alpha remove -alpha off -quality 92 "$@"

# Square padded social/profile avatars (~10% margin per side on solid background)
$(LOGO_DIR)/bmc-avatar-%.png: $(LOGO_MASTER_PNG)
	@mkdir -p $(LOGO_DIR)
	@inner=$$(( $* * 80 / 100 )); \
	$(MAGICK) "$<" -resize $${inner}x$${inner} -background "$(ICON_BG)" -gravity center -extent $*x$* -alpha remove -alpha off "$@"

# Favicons & web app icons
$(FAVICON_DIR)/icon.svg: $(LOGO_SVG)
	@mkdir -p $(FAVICON_DIR)
	cp -f "$<" "$@"

$(FAVICON_DIR)/favicon-16x16.png $(FAVICON_DIR)/favicon-32x32.png $(FAVICON_DIR)/favicon-48x48.png: $(LOGO_MASTER_PNG)
	@mkdir -p $(FAVICON_DIR)
	@sz=$$(basename "$@" .png | sed 's/favicon-//;s/x.*//'); \
	$(MAGICK) "$<" -resize $${sz}x$${sz} -background none -gravity center -extent $${sz}x$${sz} "$@"

$(FAVICON_DIR)/favicon.ico: $(FAVICON_DIR)/favicon-16x16.png $(FAVICON_DIR)/favicon-32x32.png $(FAVICON_DIR)/favicon-48x48.png
	$(MAGICK) $^ "$@"

$(FAVICON_DIR)/apple-touch-icon.png: $(LOGO_MASTER_PNG)
	@mkdir -p $(FAVICON_DIR)
	$(MAGICK) "$<" -resize 144x144 -background "$(ICON_BG)" -gravity center -extent 180x180 -alpha remove -alpha off "$@"

$(FAVICON_DIR)/icon-%.png: $(LOGO_MASTER_PNG)
	@mkdir -p $(FAVICON_DIR)
	$(MAGICK) "$<" -resize $*x$* -background none -gravity center -extent $*x$* "$@"

$(FAVICON_DIR)/icon-mask.png: $(LOGO_MASTER_PNG)
	@mkdir -p $(FAVICON_DIR)
	$(MAGICK) "$<" -resize 384x384 -background "$(ICON_BG)" -gravity center -extent 512x512 -alpha remove -alpha off "$@"

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
	@echo "  all        Build all flyers, favicons, and logos into $(BUILD_DIR)/ (default)"
	@echo "  flyers     Build all flyer PDFs into $(BUILD_DIR)/"
	@echo "  favicons   Build favicon and PWA icon set into $(FAVICON_DIR)/"
	@echo "  logos      Build standard & large logo exports into $(LOGO_DIR)/"
	@echo "  images     Build both favicons and logos"
	@echo "  clean      Remove intermediate LaTeX and svg-inkscape build files"
	@echo "  distclean  Remove all intermediate files and generated outputs"