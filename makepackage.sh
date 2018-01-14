#!/bin/bash
set -euo pipefail

export CARCH=i686
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

if [ ! -r /build/packages/packages.db.tar.gz ]; then
	echo "Initialising local package repository..."
	sudo -u builder repo-add /build/packages/packages.db.tar.gz
fi

sed -i 's/# Branch = stable/Branch = x32-unstable/' /etc/pacman-mirrors.conf
sed -i '/^SyncFirst/c\SyncFirst    = manjaro-system archlinux-keyring manjaro-keyring archlinux32-keyring' /etc/pacman.conf

pacman-mirrors -a -U 'https://mirror.netzspielplatz.de/manjaro/packages'

source PKGBUILD
repo_version=$(pacman -Siy "${pkgname}" | grep "Version" | cut -d":" -f2 | tr -d '[:space:]' || echo "0")
package_version="${pkgver}-${pkgrel}"
newenough="$(vercmp $repo_version $package_version)"
if [ $newenough -ge 0 ]; then
        echo "Nothing to do, repo version is same or newer."
        exit 0
fi

# Make sure i686 in in the arch array
case "${arch[@]}" in
	*"any"*)
		;;
	*"i686"*)
		;;
	*)
		sed -i "/^arch=/c arch=('i686')" PKGBUILD
		;;
esac

echo "Importing any valid PGP keys..."
if [ ! -z "${validpgpkeys:-}" ]; then
	for key in "${validpgpkeys[@]}"; do
	        sudo -u builder gpg --recv-key "$key"
	done
fi

pacman --noconfirm --noprogressbar -Syyu

if [ ! -z "${IMTOOLAZYTOCHECKSUMS:-}" ]; then
	echo "Updating checksums..."
	sudo -u builder /usr/bin/updpkgsums
fi

echo "Building package..."
sudo -u builder script -q -c "/usr/bin/makepkg --noconfirm --noprogressbar --sign -Csfc" /dev/null

#echo "Updating local package repository..."
#sudo -u builder /usr/bin/repo-add -q -n /build/packages/packages.db.tar.gz /build/packages/*{i686,any}.pkg.tar.xz
