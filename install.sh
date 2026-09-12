#!/usr/bin/env bash
# ============================================================================
#  ali2's Hyprland Rice - Interactive Installer
#  A full Hyprland desktop rice with quickshell, waybar, wlogout, and more.
# ============================================================================
set -euo pipefail

# ── Colors & Helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()     { echo -e "${RED}[ERR]${NC}   $*"; }
header()  { echo -e "\n${BOLD}${CYAN}── $* ──${NC}"; }

RICE_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.config/ali2-rice-backup/$(date +%Y%m%d_%H%M%S)"

# ── Detect distro ───────────────────────────────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
    elif command -v pacman &>/dev/null; then
        DISTRO_ID="arch"
    elif command -v apt &>/dev/null; then
        DISTRO_ID="debian"
    elif command -v dnf &>/dev/null; then
        DISTRO_ID="fedora"
    else
        DISTRO_ID="unknown"
    fi
    info "Detected distro: ${BOLD}$DISTRO_ID${NC}"
}

# ── Package installation ────────────────────────────────────────────────────
install_packages() {
    local pkgs=("$@")
    case "$DISTRO_ID" in
        arch|manjaro|endeavouros)
            sudo pacman -S --needed --noconfirm "${pkgs[@]}" ;;
        fedora)
            sudo dnf install -y "${pkgs[@]}" ;;
        debian|ubuntu|pop)
            sudo apt install -y "${pkgs[@]}" ;;
        opensuse*)
            sudo zypper install -y "${pkgs[@]}" ;;
        *)
            warn "Unknown distro. Please install these manually: ${pkgs[*]}"
            return 1 ;;
    esac
}

# ── Backup existing configs ─────────────────────────────────────────────────
backup_config() {
    local src="$HOME/.config/$1"
    if [ -d "$src" ] || [ -f "$src" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$src" "$BACKUP_DIR/"
        info "Backed up: ~/.config/$1 -> $BACKUP_DIR/$1"
    fi
}

# ── Selection menu ──────────────────────────────────────────────────────────
# Everything installs. Only DynaLinux (dynamic island) is optional.
declare -A COMPONENTS=(
    [hyprland]="Hyprland core config (hyprland.lua/conf, keybinds, rules, scripts, hyprlock)"
    [waybar]="Waybar status bar (config, style, GPU script)"
    [quickshell]="Quickshell (superlauncher, wallpaper + live pickers, cheatsheet, hypr-lens)"
    [rofi]="Rofi application launcher (theme, cheatsheet theme)"
    [wlogout]="Wlogout logout screen (layout, style, icons)"
    [clipse]="Clipse clipboard manager (config, theme)"
    [dunst]="Dunst notification daemon (dunstrc)"
    [kitty]="Kitty terminal (config + theme)"
)

SELECTED=(hyprland waybar quickshell rofi wlogout clipse dunst kitty)
INSTALL_DYNALINUX="no"

print_banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat << 'EOF'

    ╔═══════════════════════════════════════════════════╗
    ║       ali2's Hyprland Rice - Installer            ║
    ║  DynaLinux · Waybar · Quickshell · Hypr-Lens     ║
    ╚═══════════════════════════════════════════════════╝

EOF
    echo -e "${NC}"
}

component_menu() {
    print_banner
    echo -e "${BOLD}This will install:${NC}\n"

    local keys=(hyprland waybar quickshell rofi wlogout clipse dunst kitty)
    for key in "${keys[@]}"; do
        echo -e "  ${GREEN}[✓]${NC} ${BOLD}$key${NC}  — ${COMPONENTS[$key]}"
    done
    echo ""
    echo -e "  ${YELLOW}[?]${NC} ${BOLD}DynaLinux${NC}  — Dynamic Island (optional)"
    echo ""

    SELECTED=("${keys[@]}")

    read -rp "$(echo -e "${CYAN}Install DynaLinux dynamic island? [y/N]: ${NC}")" want_dyna
    if [[ "${want_dyna,,}" == "y" ]]; then
        INSTALL_DYNALINUX="yes"
        info "DynaLinux will be installed"
    else
        info "Skipping DynaLinux"
    fi

    echo ""
    info "Selected components: ${BOLD}${SELECTED[*]}${NC}"
    read -rp "$(echo -e "${CYAN}Proceed? [Y/n]: ${NC}")" confirm
    if [[ "${confirm,,}" == "n" ]]; then
        echo "Aborted."
        exit 0
    fi
}

# ── Core dependencies prompt ────────────────────────────────────────────────
install_core_deps() {
    header "Core Dependencies"

    local core_pkgs=(
        hyprland hyprlock hypridle hyprpaper hyprpicker
        waybar wlogout rofi-wayland dunst
        kitty clipse wl-clipboard
        mpvpaper ffmpeg socat
        brightnessctl playerctl
        polkit-kde-agent
        qt6ct qt6-wayland kvantum
        adw-gtk3-theme
        grim slurp
        NetworkManager-applet
        jq imagemagick curl unzip
        python3
    )

    echo -e "The following ${BOLD}core packages${NC} will be installed:\n"
    for pkg in "${core_pkgs[@]}"; do
        echo "  • $pkg"
    done
    echo ""
    read -rp "$(echo -e "${CYAN}Install core dependencies? [Y/n]: ${NC}")" install_core
    if [[ "${install_core,,}" != "n" ]]; then
        info "Installing core packages..."
        install_packages "${core_pkgs[@]}" || warn "Some packages may have failed"
        ok "Core dependencies installed"
    else
        warn "Skipping core dependency installation"
    fi
}

# ── Quickshell dependencies ─────────────────────────────────────────────────
install_quickshell_deps() {
    header "Quickshell Dependencies"

    echo -e "Quickshell modules require ${BOLD}quickshell${NC} and some extra packages.\n"
    echo "  • quickshell (from AUR or build from source)"
    echo "  • material-symbols-ttf (icon font)"
    echo "  • noto-fonts (text font)"
    echo ""
    read -rp "$(echo -e "${CYAN}Install quickshell extra deps? [Y/n]: ${NC}")" install_qs
    if [[ "${install_qs,,}" != "n" ]]; then
        case "$DISTRO_ID" in
            arch|manjaro|endeavouros)
                sudo pacman -S --needed --noconfirm material-symbols-ttf noto-fonts
                info "Quickshell must be installed separately (AUR / source build)"
                ;;
            *)
                info "Please install quickshell manually: https://quickshell.outfoxxed.me"
                ;;
        esac
    fi
}

# ── Install fonts ────────────────────────────────────────────────────────────
install_fonts() {
    header "Fonts"

    echo -e "This rice uses these fonts:\n"
    echo "  • JetBrainsMono Nerd Font"
    echo "  • Iosevka Nerd Font"
    echo "  • CaskaydiaCove Nerd Font"
    echo "  • Noto Sans"
    echo "  • Material Symbols Rounded"
    echo ""
    read -rp "$(echo -e "${CYAN}Download & install Nerd Fonts? [Y/n]: ${NC}")" install_f
    if [[ "${install_f,,}" != "n" ]]; then
        local font_dir="$HOME/.local/share/fonts"
        mkdir -p "$font_dir"

        local fonts=(
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.zip"
            "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"
        )

        for url in "${fonts[@]}"; do
            local name=$(basename "$url" .zip)
            info "Downloading $name..."
            local tmp=$(mktemp -d)
            if curl -sL "$url" -o "$tmp/$name.zip"; then
                unzip -qo "$tmp/$name.zip" -d "$font_dir/" 2>/dev/null
                ok "Installed $name"
            else
                warn "Failed to download $name"
            fi
            rm -rf "$tmp"
        done

        fc-cache -fv
        ok "Fonts installed and cache updated"
    fi
}

# ── Deploy configs ──────────────────────────────────────────────────────────
deploy_configs() {
    header "Deploying Configs"

    # Backup existing configs
    for comp in "${SELECTED[@]}"; do
        case "$comp" in
            hyprland)    backup_config "hypr" ;;
            waybar)      backup_config "waybar" ;;
            quickshell)  backup_config "quickshell" ;;
            rofi)        backup_config "rofi" ;;
            wlogout)     backup_config "wlogout" ;;
            clipse)      backup_config "clipse" ;;
            dunst)       backup_config "dunst" ;;
            kitty)       backup_config "kitty" ;;
        esac
    done

    # Deploy each selected component
    # NOTE: __HOME__ placeholders in config files will be replaced after deployment
    for comp in "${SELECTED[@]}"; do
        case "$comp" in
            hyprland)
                info "Installing Hyprland config..."
                mkdir -p "$HOME/.config/hypr/scripts"
                cp "$RICE_DIR/hypr/hyprland.lua"   "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/hyprland.conf"  "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/keybinds.lua"   "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/rules.lua"       "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/hyprlock.conf"   "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/hypridle.conf"   "$HOME/.config/hypr/"
                cp "$RICE_DIR/hypr/scripts/"*       "$HOME/.config/hypr/scripts/"
                chmod +x "$HOME/.config/hypr/scripts/"*.sh
                ok "Hyprland config installed"
                ;;
            waybar)
                info "Installing Waybar config..."
                mkdir -p "$HOME/.config/waybar/scripts"
                cp "$RICE_DIR/waybar/config.jsonc"   "$HOME/.config/waybar/"
                cp "$RICE_DIR/waybar/style.css"       "$HOME/.config/waybar/"
                cp "$RICE_DIR/waybar/scripts/"*       "$HOME/.config/waybar/scripts/"
                chmod +x "$HOME/.config/waybar/scripts/"*.sh 2>/dev/null || true
                ok "Waybar config installed"
                ;;
            quickshell)
                info "Installing Quickshell configs..."
                mkdir -p "$HOME/.config/quickshell"

                # Main shell.qml
                cp "$RICE_DIR/quickshell/shell.qml" "$HOME/.config/quickshell/"

                # superlauncher (SUPER)
                mkdir -p "$HOME/.config/quickshell/superlauncher"
                cp "$RICE_DIR/quickshell/superlauncher/"*.qml "$HOME/.config/quickshell/superlauncher/"

                # hyprquickpaper (static wallpaper picker, SUPER+W)
                mkdir -p "$HOME/.config/quickshell/hyprquickpaper"
                cp "$RICE_DIR/quickshell/hyprquickpaper/"* "$HOME/.config/quickshell/hyprquickpaper/"

                # hyprquickpaper-live (video wallpaper picker, SUPER+SHIFT+W)
                mkdir -p "$HOME/.config/quickshell/hyprquickpaper-live"
                cp "$RICE_DIR/quickshell/hyprquickpaper-live/"* "$HOME/.config/quickshell/hyprquickpaper-live/"

                # hyprcheatsheet (F1 cheatsheet)
                mkdir -p "$HOME/.config/quickshell/hyprcheatsheet"
                cp "$RICE_DIR/quickshell/hyprcheatsheet/"*.qml "$HOME/.config/quickshell/hyprcheatsheet/"

                # DynaLinux (Dynamic Island, optional)
                if [[ "$INSTALL_DYNALINUX" == "yes" ]]; then
                    mkdir -p "$HOME/.config/quickshell/DynaLinux/modules/dynalinux"
                    cp "$RICE_DIR/quickshell/DynaLinux/shell.qml" "$HOME/.config/quickshell/DynaLinux/"
                    cp "$RICE_DIR/quickshell/DynaLinux/modules/dynalinux/"*.qml \
                       "$HOME/.config/quickshell/DynaLinux/modules/dynalinux/"
                    ok "DynaLinux installed"
                else
                    info "Skipping DynaLinux (not selected)"
                fi

                # hypr-lens (screenshot/OCR/recording)
                local lens_dst="$HOME/.config/quickshell/hypr-lens"
                mkdir -p "$lens_dst"
                find "$RICE_DIR/quickshell/hypr-lens" -type f \( -name "*.qml" -o -name "*.js" -o -name "qmldir" \) | while read f; do
                    local rel="${f#$RICE_DIR/quickshell/hypr-lens/}"
                    mkdir -p "$lens_dst/$(dirname "$rel")"
                    cp "$f" "$lens_dst/$rel"
                done
                # qmldir
                if [ -f "$RICE_DIR/quickshell/hypr-lens/modules/common/qmldir" ]; then
                    mkdir -p "$lens_dst/modules/common"
                    cp "$RICE_DIR/quickshell/hypr-lens/modules/common/qmldir" "$lens_dst/modules/common/"
                fi

                ok "Quickshell configs installed"
                ;;
            rofi)
                info "Installing Rofi config..."
                mkdir -p "$HOME/.config/rofi"
                cp "$RICE_DIR/rofi/config.rasi"      "$HOME/.config/rofi/"
                cp "$RICE_DIR/rofi/cheatsheet.rasi"   "$HOME/.config/rofi/"
                cp "$RICE_DIR/rofi/colors.rasi"       "$HOME/.config/rofi/"
                ok "Rofi config installed"
                ;;
            wlogout)
                info "Installing Wlogout config..."
                mkdir -p "$HOME/.config/wlogout/icons"
                cp "$RICE_DIR/wlogout/layout"    "$HOME/.config/wlogout/"
                cp "$RICE_DIR/wlogout/style.css" "$HOME/.config/wlogout/"
                cp "$RICE_DIR/wlogout/icons/"*   "$HOME/.config/wlogout/icons/"
                ok "Wlogout config installed"
                ;;
            clipse)
                info "Installing Clipse config..."
                mkdir -p "$HOME/.config/clipse"
                cp "$RICE_DIR/clipse/config.json"       "$HOME/.config/clipse/"
                cp "$RICE_DIR/clipse/custom_theme.json" "$HOME/.config/clipse/"
                ok "Clipse config installed"
                ;;
            dunst)
                info "Installing Dunst config..."
                mkdir -p "$HOME/.config/dunst"
                cp "$RICE_DIR/dunst/dunstrc" "$HOME/.config/dunst/"
                ok "Dunst config installed"
                ;;
            kitty)
                info "Installing Kitty config..."
                mkdir -p "$HOME/.config/kitty"
                cp "$RICE_DIR/kitty/kitty.conf"       "$HOME/.config/kitty/"
                [ -f "$RICE_DIR/kitty/current-theme.conf" ] && \
                    cp "$RICE_DIR/kitty/current-theme.conf" "$HOME/.config/kitty/"
                ok "Kitty config installed"
                ;;
        esac
    done

    # Replace __HOME__ placeholders with actual $HOME in deployed configs
    info "Replacing __HOME__ placeholders..."
    local deployed_files=(
        "$HOME/.config/quickshell/hyprquickpaper/config.json"
        "$HOME/.config/quickshell/hyprquickpaper-live/config.json"
        "$HOME/.config/wlogout/style.css"
    )
    for f in "${deployed_files[@]}"; do
        if [ -f "$f" ]; then
            sed -i "s|__HOME__|$HOME|g" "$f"
        fi
    done
    ok "Placeholders resolved"
}

# ── Post-install setup ──────────────────────────────────────────────────────
post_install() {
    header "Post-Install Setup"

    # Create wallpaper directories if quickshell was installed
    if printf '%s\n' "${SELECTED[@]}" | grep -q "quickshell"; then
        mkdir -p "$HOME/Pictures/Livewall"
        if [ -z "$(ls -A "$HOME/Pictures/" 2>/dev/null)" ]; then
            info "No wallpapers found in ~/Pictures/"
            echo "  hyprquickpaper looks for .jpg/.png files there (SUPER+W)."
            echo "  Live videos go in ~/Pictures/Livewall/ (SUPER+SHIFT+W)."
        fi
    fi

    # Create cache dirs for wallpaper thumbnails
    mkdir -p "$HOME/.cache/quickshell/thumbs" "$HOME/.cache/quickshell/thumbs-live"

    # Symlink hyprland.lua -> hyprland.conf if hyprland looks for .conf
    if [ -f "$HOME/.config/hypr/hyprland.lua" ] && [ ! -f "$HOME/.config/hypr/hyprland.conf" ]; then
        info "Creating hyprland.conf symlink (Hyprland expects .conf)..."
        ln -sf hyprland.lua "$HOME/.config/hypr/hyprland.conf"
        ok "Symlinked hyprland.conf -> hyprland.lua"
    fi
}

# ── Final summary ────────────────────────────────────────────────────────────
print_summary() {
    header "Installation Complete!"

    echo -e "${GREEN}${BOLD}Installed components:${NC}"
    for comp in "${SELECTED[@]}"; do
        echo -e "  ${GREEN}✓${NC} $comp"
    done
    echo ""

    if [ -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Backups saved to:${NC} $BACKUP_DIR"
        echo ""
    fi

    echo -e "${BOLD}Quick Start:${NC}"
    echo "  1. Log out of your current session"
    echo "  2. Select Hyprland from your display manager"
    echo "  3. Use SUPER+T for terminal, SUPER+. for app launcher"
    echo "  4. Run 'hyprctl reload' to apply config changes"
    echo ""
    echo -e "${BOLD}Keybinds:${NC}  SUPER launcher · SUPER+W wallpapers · SUPER+SHIFT+W live wallpapers · F1 cheatsheet"
    echo ""
    echo -e "${BOLD}Wallpaper picker:${NC}"
    echo "  SUPER+W        static (needs images in ~/Pictures/)"
    echo "  SUPER+SHIFT+W  live video (needs videos in ~/Pictures/Livewall/)"
    echo ""

    if [ "$INSTALL_DYNALINUX" == "yes" ]; then
        echo -e "  ${GREEN}✓${NC} DynaLinux dynamic island"
        echo ""
    fi

    if printf '%s\n' "${SELECTED[@]}" | grep -q "quickshell"; then
        echo -e "${YELLOW}Note:${NC} Ensure quickshell + awww are installed (AUR):"
        echo "  yay -S quickshell-bin awww-bin"
        echo "  https://quickshell.outfoxxed.me"
        echo ""
    fi
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        err "Do not run this script as root."
        exit 1
    fi

    detect_distro
    component_menu
    install_core_deps

    # Only ask for quickshell deps if quickshell was selected
    if printf '%s\n' "${SELECTED[@]}" | grep -q "quickshell"; then
        install_quickshell_deps
    fi

    install_fonts
    deploy_configs
    post_install
    print_summary
}

main "$@"
