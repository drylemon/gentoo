# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=7

inherit flag-o-matic toolchain-funcs systemd

DESCRIPTION="xfs filesystem utilities"
HOMEPAGE="https://xfs.wiki.kernel.org/"
SRC_URI="https://www.kernel.org/pub/linux/utils/fs/xfs/${PN}/${P}.tar.xz"

LICENSE="LGPL-2.1"
SLOT="0"
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~hppa ~ia64 ~mips ~ppc ~ppc64 ~s390 ~sh ~sparc ~x86"
IUSE="icu libedit nls readline"

LIB_DEPEND=">=sys-apps/util-linux-2.17.2[static-libs(+)]
	icu? ( dev-libs/icu:=[static-libs(+)] )
	readline? ( sys-libs/readline:0=[static-libs(+)] )
	!readline? ( libedit? ( dev-libs/libedit[static-libs(+)] ) )"
RDEPEND="${LIB_DEPEND//\[static-libs(+)]}
	!<sys-fs/xfsdump-3"
DEPEND="${RDEPEND}"
BDEPEND="
	nls? ( sys-devel/gettext )
"

PATCHES=(
	"${FILESDIR}"/${PN}-4.9.0-underlinking.patch
	"${FILESDIR}"/${PN}-4.15.0-sharedlibs.patch
	"${FILESDIR}"/${PN}-4.15.0-docdir.patch
)

pkg_setup() {
	if use readline && use libedit ; then
		ewarn "You have USE='readline libedit' but these are exclusive."
		ewarn "Defaulting to readline; please disable this USE flag if you want libedit."
	fi
}

src_prepare() {
	default

	# Fix doc dir
	sed -i \
		-e "/^PKG_DOC_DIR/s:@pkg_name@:${PF}:" \
		include/builddefs.in || die

	# Don't install compressed docs
	sed 's@\(CHANGES\)\.gz[[:space:]]@\1 @' -i doc/Makefile || die
}

src_configure() {
	export DEBUG=-DNDEBUG
	export OPTIMIZER=${CFLAGS}
	unset PLATFORM # if set in user env, this breaks configure

	# Upstream does NOT support --disable-static anymore,
	# https://www.spinics.net/lists/linux-xfs/msg30185.html
	# https://www.spinics.net/lists/linux-xfs/msg30272.html
	local myconf=(
		--enable-blkid
		--with-crond-dir="${EPREFIX}/etc/cron.d"
		--with-systemd-unit-dir="$(systemd_get_systemunitdir)"
		$(use_enable icu libicu)
		$(use_enable nls gettext)
		$(use_enable readline)
		$(usex readline --disable-editline $(use_enable libedit editline))
	)

	if is-flagq -fno-lto ; then
		einfo "LTO disabled via {C,CXX,F,FC}FLAGS"
		myconf+=( --disable-lto )
	else
		if is-flagq -flto ; then
			einfo "LTO forced via {C,CXX,F,FC}FLAGS"
			myconf+=( --enable-lto )
		elif use amd64 || use x86  ; then
			# match upstream default
			myconf+=( --enable-lto )
		else
			# LTO can cause problems on some architectures, bug 655638
			myconf+=( --disable-lto )
		fi
	fi

	econf "${myconf[@]}"
}

src_compile() {
	# Unset {CF,LD}FLAGS which are already set via configure
	# but will cause problems when available during make.
	# Fixed in >=xfsprogs-5.3.0.
	unset CFLAGS LDFLAGS

	emake V=1
}

src_install() {
	emake DIST_ROOT="${ED}" install
	emake DIST_ROOT="${ED}" install-dev

	# removing unnecessary .la files if not needed
	find "${ED}" -type f -name '*.la' -delete || die
}
