# Arch - Install Dependencies
* Network Manager
    ```
    ```
* Grub
    ```
    ```
* Enable Systemctl
    ```
    ```
## Post - Install System Tools
* Terminal Emulator
    + [Alacritty](https://github.com/alacritty/alacritty)
        + [Theme](https://github.com/catppuccin/catppuccin)
            ```
            sudo pacman -S alacritty
            sudo pacman -S ttf-jetbrains-mono-nerd
            fc-list | grep "JetBrainsMono"
            sudo pacman -S lsd
            ```
* yay | AUR Helper
    ```
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    ```
    + Clean up after install
        ```
        rm -rf ~/yay
        yay --version
        ```
+ Window Management & Launcher:
    + Theme: inpsired by [Typecraft-dev](https://guthub.com/Typecraft-dev/dotfiles)
        + i3
        ```
        sudo pacman -S i3-wm i3lock i3status dmenu
        sudo pacman -S xorg-xrandr xorg-xinit
        sudo pacman -S xorg-server
        sudo pacman -S xf86-input-libinput  # Touchpad Support
        sudo pacman -S i3-gaps
        ```
        + Rofi
        ```
        sudo pacman -S rofi 
        ```
        + Polybar
        ```
        sudo pacman -S polybar 
        ```
        + Picom
        ```
        sudo pacman -S picom
        ```
+ PDF Viewer: Zathura
    + Theme: Pywal [Zathura-Pywal](https://github.com/GideonWolfe/Zathura-Pywal)
    ```
    sudo pacman -S zathura zathura-pdf-poppler
    git clone https://github.com/GideonWolfe/Zathura-Pywal
    ```
    + [VimTex](https://github.com/lervag/vimtex) plugin compatible
        + [latexmk](https://github.com/gingerhot/latexmk)
        ```
        sudo pacman -S texlive-binextra
        sudo pacman -S texlive-core texlive-bin texlive-latex texlive-latexextra texlive-formatsextra
        ```
* Fetch:
    + [fastfetch](https://github.com/fastfetch-cli/fastfetch)
        ```
        sudo pacman -S fastfetch
        ```
* Process Viewer 
    + [htop](https://github.com/htop-dev/htop)
    ```
    sudo pacman -S htop
    ```
* Image Viewer
    + [feh](https://github.com/derf/feh)
    ```
    sudo pacman -S feh
    ```
* Audio
    ```
    sudo pacman -S pulseaudio pulseaudio-equalizer pulseaudio-jack
    sudo pacman -S alsa-utils  # run the command alsamixer
    sudo pacman -S pulseaudio pulseaudio-alsa
    ```
* Bluetooth
    ```
    bluez bluez-utils
    ```
* curl
    ```

    ``` 
* wget
    ```

    ```
* git
    ```
    sudo pacman -S git
    ```
### Data Science & Developer Tools
* [GNU Stow](https://github.com/aspiers/stow)
    + Manage data science tools and configurations with version control and CI/CD methods
    ```
    pacman -S stow
    ```
* Pyhton3
    ```
    python3 --version
    ```
* R 
    ```
    sudo pacman -S r
    ```
* rust
    ```
    sudo pacman -S rustup
    rustup default stable
    ```
* nodejs & npm
    ```
    sudo pacman -S nodejs npm
    ```
* Github CLI
    ```
    sudo pacman -S github-cli
    ```
* Vim
    ```
    sudo pacman -S vim
    ```
* Neovim
    ```
    sudo pacman -S neovim
    ```
* Tmux
    ```
    sudo pacman -S tmux 
    ```
* Quarto CLI
    ```
    git clone https://github.com/quarto-dev/quarto-cli
    sudo pacman -S nodejs npm
    ```
    + run setup script
        ```
        cd quarto-cli
        ./configure.sh
        ```
* Docker
    ```
    sudo pacman -S docker
    ```
    + Start & Enable the Docker Service
        ```
        sudo systemctl start docker.service
        ```
* uv
    + Lightweight rust based python package & tool manager
        ```
        cargo install --git https://github.com/astral-sh/uv uv
        export PATH="$HOME/.cargo/bin:$PATH"
        ```
* ripgep
    + Needed for Neovim Snacks Dashboard
        ```
        sudo pacman -S ripgrep
        ```
* fzf
    + Fuzzy finder
        ```
        sudo pacman -S fzf
        ```
