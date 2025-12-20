#!/bin/bash

source common_utils.sh

# Set paths (GNU_DIR is set by common_utils.sh)
FONT_DIR="$GNU_DIR/good_fonts"
POWERLINE_FONTS_DIR="$HOME/.vim/plugged/fonts"
DEJAVU_FONT_DIR="$POWERLINE_FONTS_DIR/DejaVuSansMono"

# 1. Create symlinks for .vimrc and .spacemacs
log "Creating symlinks for .vimrc and .spacemacs..."
ln -sf "$GNU_DIR/.vimrc" "$HOME/.vimrc"
ln -sf "$GNU_DIR/.spacemacs" "$HOME/.spacemacs"
log "Symlinks created."

# 2. Install fonts (Linux and macOS)
log "Installing fonts from $FONT_DIR..."
if [[ ! -d "$FONT_DIR" ]]; then
    log "Font directory $FONT_DIR does not exist. Please add your font files."
    exit 1
fi

if [[ "$OS" == "Darwin" ]]; then
    # macOS - Use find with -print0 and while read for safe handling of filenames with spaces
    log "Installing fonts for macOS..."
    while IFS= read -r -d '' font; do
        if cp "$font" "$HOME/Library/Fonts/" 2> /dev/null; then
            log "Installed: $(basename "$font")"
        else
            log "Failed to install: $font" "WARNING"
        fi
    done < <(find "$FONT_DIR" -type f \( -name "*.ttf" -o -name "*.otf" \) -print0)
    log "Fonts installed for macOS. Might need to restart for font cache."
else
    # Linux - same safe pattern
    log "Installing fonts for Linux..."
    mkdir -p "$HOME/.fonts"
    while IFS= read -r -d '' font; do
        if cp "$font" "$HOME/.fonts/" 2> /dev/null; then
            log "Installed: $(basename "$font")"
        else
            log "Failed to install: $font" "WARNING"
        fi
    done < <(find "$FONT_DIR" -type f \( -name "*.ttf" -o -name "*.otf" \) -print0)
    fc-cache -fv
    log "Fonts installed for Linux."
fi

# 3. Install vim-plug for Vim
VIM_PLUG_FILE="$HOME/.vim/autoload/plug.vim"
if [ ! -f "$VIM_PLUG_FILE" ]; then
    log "Installing vim-plug for Vim..."
    curl -fLo "$VIM_PLUG_FILE" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
else
    log "vim-plug is already installed."
fi

# 4. Open Vim and install plugins
log "Installing Vim plugins..."
if command -v vim &> /dev/null; then
    vim +PlugInstall +qall || {
        log "Vim plugin installation failed. Check your .vimrc configuration."
        exit 1
    }
else
    log "Vim is not installed. Please install Vim and re-run the script." "WARNING"
fi

log "Vim plugins installed."

# 5. Install DejaVu Sans Mono for Powerline fonts
log "Installing DejaVu Sans Mono for Powerline fonts from $DEJAVU_FONT_DIR..."
if [[ -d "$DEJAVU_FONT_DIR" ]]; then
    for font in "$DEJAVU_FONT_DIR"/*.ttf "$DEJAVU_FONT_DIR"/*.otf; do
        [ -e "$font" ] || continue
        if [[ "$OSTYPE" == "darwin"* ]]; then
            cp "$font" ~/Library/Fonts/
        else
            mkdir -p "$HOME/.fonts"
            cp "$font" "$HOME/.fonts/"
            fc-cache -fv
        fi
    done
    log "DejaVu Sans Mono for Powerline fonts installed."
else
    log "DejaVu Sans Mono for Powerline font directory not found. Skipping..."
fi

log "Setup completed!"
