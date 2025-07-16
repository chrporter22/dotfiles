# Arch - Install from Bootable Disk
* Set font if needed during install
    ```
    setfont ter-132N
    ```

* Connect to Inernet with Wifi
    ```
    iwctl
    device list 
    device wlan0 set-property powered on # <-- if needed
    station wlan0 connect WIFI
    exit
    ping -c 5 archlinux.org
    ```

* Sync package databases
    ```
    pacman -Syu
    pacman -S archlinux-keyring
    ```

# Partitioning
Create three main partitions with cfdisk EFI, ROOT, and SWAP; remember disk names for future reference.
* EFI - 1 GB

* root - depends on how much you are going to install

* Swap - 1.5 x RAM
    ```
    lsblk #For printing out our current disk
    cfdisk /dev/nvme0n1
    ```

* Format EFI Partition
    ```
    mkfs.fat -F32 /dev/nvme0n1p5
    ```

* Format root
    ```
    mkfs.ext4 /dev/nvme0n1p6
    ```

* Format Swap Partition
    ```
    mkswap /dev/nvme0n1p7
    swapon /dev/nvme0n1p7
    ```

# Mounting
* Make directories
    ```
    mkdir /mnt
    mkdir /mnt/efi
    ```

* Mount `root` partition into `/mnt`.
    ```
    mount /dev/nvme0n1p6 /mnt
    ```

* Check `/mnt` with `ls`:
    ```
    ls /mnt
    ```

* Mount efi
    ```
    mount /dev/nvme0n1p5 /mnt/efi
    ```

# Mirrorlist
* Improve download speed:
    ```
    pacman -S reflector
    reflector --latest 200 --sort rate --save /etc/pacman.d/mirrorlist
    ```

# Core Arch and Linux Kernel 
Use `amd-ucode` or `intel-ucode` for improved cpu performance.
`pacstrap /mnt base base-devel linux linux-firmware`

# Fstab
Generate UUID for partitions.
    ```
    echo /efi vfat defaults 0 1" >> /etc/fstab
    echo none swap sw 0 0" >> /etc/fstab
    echo / ext4 defaults 0 2" >> /etc/fstab
    ```
# Chroot prep
* Bind directories
    ```
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    cp /etc/resolv.conf /mnt/etc/
    ```

# Chroot
* Change root 
   ```
    arch-chroot /mnt
    ```

# Set Time
`sudo ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime`
`hwclock --systohc`

# Generate Locale
`vim /etc/locale.gen`

`locale-gen`

# Create a Locale Config
vim /etc/locale.conf
* Add:
    ```
    LANG = en_US.UTF-8
    ```

# Host Name
`vim /etc/hostname`

# Local IP For Host
`vim /etc/hosts`
* Add:
    ```
    verbatim
    127.0.0.1	localhost
    ::1			localhost
    127.0.1.1	Username.localdomain	Username
    ```

# Set Password
`passwd`

# Boot Loader
`pacman -S grub`

# Grub
`grub-install --target=i386-pc /dev/<YOUR_PARTITION>`
`grub-mkconfig -o /boot/grub/grub.cfg`

# Enabling Systemctl
`systemctl enable NetworkManager`

# Users
`useradd -mG wheel <Username>`

# Sudo Permissions / Sudoers
* Uncomment:
    ```
    EDITOR=vim visudo
    ```

# Password & System Control
* Enable Systemctl
    ```
    passwd <Username>
    ```

# Exit Chroot
* exit
    + Unmount
        ```
        umount -a
        reboot
        ```

# Post - Install System Tools
* Terminal Emulator
    + [Alacritty](https://github.com/alacritty/alacritty)
        + [Theme](https://github.com/catppuccin/catppuccin)
            ```
            sudo pacman -S alacritty
            sudo pacman -S ttf-jetbrains-mono-nerd
            fc-list | grep "JetBrainsMono"
            sudo pacman -S lsd
            ```
* [yay](https://aur.archlinux.org/yay.git) | AUR Helper
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
        + [i3](https://github.com/i3/i3.github.io)
        ```
        sudo pacman -S i3-wm i3lock i3status dmenu
        sudo pacman -S xorg-xrandr xorg-xinit
        sudo pacman -S xorg-server
        sudo pacman -S xf86-input-libinput  # Touchpad Support
        sudo pacman -S i3-gaps
        ```
        + [Rofi](https://github.com/davatorium/rofi)
        ```
        sudo pacman -S rofi 
        ```
        + [Polybar](https://github.com/polybar/polybar)
        ```
        sudo pacman -S polybar 
        ```
        + [Picom](https://github.com/yshui/picom)
        ```
        sudo pacman -S picom
        ```
+ PDF Viewer: [Zathura](https://github.com/pwmt/zathura)
    + Theme: [Zathura-Pywal](https://github.com/GideonWolfe/Zathura-Pywal) for transparency patch
    ```
    sudo pacman -S zathura zathura-pdf-poppler
    git clone https://github.com/GideonWolfe/Zathura-Pywal
    ```
    + [VimTex](https://github.com/lervag/vimtex) vim/nvim plugin compatible
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
* curl & wget
    ```
    sudo pacman -Syu git curl
    ``` 
* git
    ```
    sudo pacman -S git
    ```
* nmap
    ```
    sudo pacman -S nmap
    ```
* openssh
    ```
    sudo pacman -S openssh
    ```

# Data Science & Developer Tools
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
* go
    ```
    sudo pacman -S go
    ```
* nodejs & npm
    ```
    sudo pacman -S nodejs npm
    ```
* redis
    ```
    sudo pacman -S redis
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
