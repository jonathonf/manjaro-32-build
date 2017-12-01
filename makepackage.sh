#!/bin/bash
set -euo pipefail

cd /build
mkdir packages sources srcpackages makepkglogs || true
cp -r /gpg /home/builder/.gnupg
chown -R builder /build /home/builder
sudo -u builder gpg --list-keys >/dev/null

if [ ! -z "${PACKAGER:-}" ]; then
	sed -i "122cPACKAGER=\"$PACKAGER\"" /etc/makepkg.conf
fi

if [ ! -z "${GPGKEY:-}" ]; then
	sed -i "124cGPGKEY=\"$GPGKEY\"" /etc/makepkg.conf
fi

# Clean package cache to avoid rebuilding issues
for package in /build/packages/*.pkg.tar.xz; do
	rm -f /pkgcache/"$package"
done

if [ ! -r /build/packages/packages.db.tar.xz ]; then
	echo "Initialising local package repository..."
	sudo -u builder repo-add /build/packages/packages.db.tar.xz
fi

sed -i 's/# Branch = stable/Branch = x32-unstable/' /etc/pacman-mirrors.conf
sed -i '/^SyncFirst/c\SyncFirst    = manjaro-system archlinux-keyring manjaro-keyring archlinux32-keyring' /etc/pacman.conf

pacman-mirrors -a -U 'https://mirror.netzspielplatz.de/manjaro/packages'

source PKGBUILD
repo_version=$(pacman -Siy "${pkgname}" | grep "Version" | cut -d":" -f2 | tr -d '[:space:]')
package_version="${pkgver}-${pkgrel}"
newenough="$(vercmp $repo_version $package_version)"
if [ $newenough -ge 0 ]; then
        echo "Nothing to do, repo version is same or newer."
        exit 0
fi

echo "Importing any valid PGP keys..."
if [ ! -z "${validpgpkeys:-}" ]; then
        sudo -u builder gpg --recv-keys "$validpgpkeys"  
fi

pacman --noconfirm --noprogressbar -Syyu

if [ ! -z "${IMTOOLAZYTOCHECKSUMS:-}" ]; then
	echo "Updating checksums..."
	sudo -u builder /usr/bin/updpkgsums
fi

echo "Building package..."
sudo -u builder script -q -c "/usr/bin/makepkg --noconfirm --noprogressbar --sign -Csfc" /dev/null

#echo "Updating local package repository..."
#sudo -u builder GLOBEXCLUDE='*git*' /usr/bin/repo-add -n -R -s \
#  /build/packages/packages.db.tar.xz \
#  /build/packages/*.pkg.tar.xz
