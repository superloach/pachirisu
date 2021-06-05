#!/bin/bash
# pachirisu
# pacman for chrome os
# bootstrap script

# exit on error
set -e

# as few globals as possible
PREFIX="/usr/local"
TMPDIR="${PREFIX}/pachi"
ARCH="$(uname -m)"

# everything needs this
mkdir -p "${TMPDIR}"

# print and save a log entry
function log() {
	echo "${1}" >> "${TMPDIR}/log"
	echo "pachi: ${1}" >/dev/stderr
}

# download & cache pacman archive
function download_pacman() {
	URL='https://sources.archlinux.org/other/pacman/pacman-6.0.0.tar.xz'
	OUT="${TMPDIR}/pacman.tar.xz"

	if [ -e "${OUT}" ]; then
		log "found pacman archive at ${OUT}"
	else
		log 'downloading pacman archive'
		curl '-#L' "${URL}" -o "${OUT}"
	fi
	
	echo "${OUT}"
}

# extract pacman archive
function extract_pacman() {
	DIR="${TMPDIR}/pacman/"

	if [ -e "${DIR}" ]; then
		log "found pacman sources at ${DIR}"
	else
		IN="$(download_pacman)"

		log 'extracting pacman sources'
		mkdir -p "${DIR}"
		tar -xJ --strip-components 1 -C "${DIR}" -f "${IN}"
	fi

	echo "${DIR}"
}

# download & cache chromebrew archive
function download_crew() {
	URL='https://github.com/skycocker/chromebrew/archive/refs/heads/master.tar.gz'
	OUT="${TMPDIR}/crew.tar.gz"

	if [ -e "${OUT}" ]; then
		log "crew archive found at ${OUT}"
	else
		log 'downloading crew archive'
		curl '-#L' "${URL}" -o "${OUT}"
	fi
	
	echo "${OUT}"
}

# extract chromebrew archive
function extract_crew() {
	DIR="${TMPDIR}/crew/"

	if [ -e "${DIR}" ]; then
		log "crew found at ${DIR}"
	else
		IN="$(download_crew)"

		log 'extracting crew'
		mkdir -p "${DIR}"
		tar -xz --strip-components 1 -C "${DIR}" -f "${IN}"
	fi
	
	echo "${DIR}"
}

# install chromebrew packages
function crew_package() {
	PKGDIR="${TMPDIR}/pkgs"
	mkdir -p "${PKGDIR}"

	PKG="${1}"; shift
	CHECK="${1}"; shift

	if [ -e "${PREFIX}/${CHECK}" ]; then
		log "${PKG} already installed (${CHECK})"
		return 0
	fi

	FILE="${CREWDIR}/packages/${PKG}.rb"
	if ! [ -e "${FILE}" ]; then
		log "package ${PKG} does not exist"
		return 1
	fi

	URL="$(grep "${ARCH}:" "${FILE}" | head -n 1 | cut -d "'" -f 2)"
	FNAME="$(basename "${URL}")"
	OUT="${PKGDIR}/${FNAME}"

	if [ -e "${OUT}" ]; then
		log "${FNAME} already downloaded"
	else
		log "downloading ${FNAME}"
		curl '-#L' "${URL}" -o "${OUT}"
	fi

	log "extracting ${PKG}"
	tar -xJ --skip-old-files -C '/' -f "${OUT}" "${PREFIX#/}"
}

function setup_pacman() {
	if [ -e './build/build.ninja' ]; then
		log 'pacman already setup'
		return 0
	fi

	LOG="${TMPDIR}/pacman.setup.log"
	log "setup pacman (log at ${LOG})"
	meson setup \
		--prefix="${PREFIX}" \
		-D 'i18n=false' \
		-D "scriptlet-shell=$(which bash)" \
		-D "root-dir=${PREFIX}" \
		-D "sysconfdir=${PREFIX}/etc" \
		-D "localstatedir=${PREFIX}/var" \
		-D "makepkg-template-dir=${PREFIX}/share/makepkg-template" \
			'./build' >"${LOG}" 2>&1
}

function compile_pacman() {
	setup_pacman

	if [ -e './build/pacman' ]; then
		log 'pacman already compiled'
		return 0
	fi

	LOG="${TMPDIR}/pacman.compile.log"
	log "compile pacman (log at ${LOG})"
	meson compile -C './build' >"${LOG}" 2>&1
}

function install_pacman() {
	if [ -e "${PREFIX}/bin/pacman" ]; then
		log 'pacman already installed'
		return 0
	fi

	DIR="$(extract_pacman)"

	pushd "${DIR}"
		compile_pacman

		pushd ./build
			LOG="${TMPDIR}/pacman.install.log"
			log "install pacman (log at ${LOG})"
			meson install >"${LOG}" 2>&1
		popd
	popd
}

# build pacman for chrome os
function main() {
	log '-------------------------'
	log "start of build at $(date)"

	export CREWDIR="$(extract_crew)"

	crew_package 'python3' 'bin/python3'
	crew_package 'meson' 'bin/meson'
	crew_package 'gcc11' 'bin/gcc'
	crew_package 'isl' 'lib64/libisl.so'
	crew_package 'mpc' 'lib64/libmpc.so'
	crew_package 'mpfr' 'lib64/libmpfr.so'
	crew_package 'zstd' 'lib64/libzstd.so'
	crew_package 'binutils' 'bin/ld'
	crew_package 'glibc' 'lib64/crti.o'
	crew_package 'flex' 'lib64/libfl.so'
	crew_package 'bash' 'bin/bash'
	crew_package 'pkgconfig' 'bin/pkg-config'
	crew_package 'libarchive' 'lib64/libarchive.so'
	crew_package 'ninja' 'bin/ninja'
	crew_package 'bash_completion' 'share/bash-completion/'
	crew_package 'linuxheaders' 'include/linux/'
	crew_package 'libgpgerror' 'include/gpg-error.h'
	crew_package 'libassuan' 'lib64/libassuan.so'
	crew_package 'acl' 'lib64/libacl.so'
	crew_package 'xzutils' 'lib64/liblzma.so'
	crew_package 'lz4' 'lib64/liblz4.so'
	crew_package 'bz2' 'lib64/libbz2.so'
	crew_package 'zlibpkg' 'lib64/libz.so'
	crew_package 'openssl' 'lib64/libcrypto.so'
	crew_package 'attr' 'lib64/libattr.so'
	crew_package 'libxml2' 'lib64/libxml2.so'
	crew_package 'icu4c' 'lib64/libicuuc.so'

	install_pacman

	log 'pacman installed :)'
}

main
