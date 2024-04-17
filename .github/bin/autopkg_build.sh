2>&1 # on github the stderr can be delayed

output(){ n="$1"; case "$2" in (:=) shift 2; eval $n="'$*'"; esac; eval echo $n='"$'"$n"'"' >> $GITHUB_OUTPUT; }

# If updating an older project to newer Autoconf syntax: autoupdate
# aclocal && automake && autoconf && => configure: line 7325: AX_WITH_CURSES: command not found
if [ "$CRJ_AUTOTOOL_CONFIGURE" = "force-preserve" ]; then
    TOUCH="aclocal.m4 Makefile.in a68g-config.h.in a68g-config.in configure"
    for f in $TOUCH; do sleep 1; touch $f; done
elif [ "$CRJ_AUTOTOOL_CONFIGURE" = "force-remake" ]; then
    TOUCH="configure a68g-config.in a68g-config.h.in Makefile.in aclocal.m4"
    for f in $TOUCH; do sleep 1; touch $f; done
elif [ "$CRJ_AUTOTOOL_CONFIGURE" = "touch-now" ]; then
    NOW=`date +"%Y%m%d%H%M"`
    find . -type d -name .git -prune -o -type f -print0 | xargs -0 touch -t $NOW
fi

if [ "$RUNNER_OS" == "Linux" ]; then
    TAR="$CRJ_PACKAGE_VERSION-$CRJ_BUILD" RBLD="$CRJ_PACKAGE_VERSION-$CRJ_BUILD-$OMJ_OS_RELEASE" RBARCH="$RBLD"_*
    echo CRJ_PACKAGE_VERSION=$CRJ_PACKAGE_VERSION TAR=$TAR RBLD=$RBLD RBARCH=$RBARCH

# RHEL
    OMJ_BUILDER=`../.github/bin/autopkg_mgr.sh echo builder`
    if [ "$OMJ_BUILDER" == rpmbuild ]; then

        # OMJ_ARCH=`rpm --eval '%{_arch}'`

        TOPDIR="$PWD/../rpmbuild"
        mkdir -p "$TOPDIR/SOURCES"

        tar -czf "$TOPDIR/SOURCES/$CRJ_PRJ-$CRJ_PACKAGE_VERSION.tar.gz" *
        SPEC="$CRJ_PRJ-$CRJ_PACKAGE_VERSION-$CRJ_BUILD.spec"

        echo rpmbuild -ba --without check --without tiny --with full --build-in-place --define "_topdir $TOPDIR" "$SPEC"
             rpmbuild -ba --without check --without tiny --with full --build-in-place --define "_topdir $TOPDIR" "$SPEC"

        OMJ_BUILT_SRC=$TOPDIR/SRPMS/$CRJ_PRJ-"$CRJ_PACKAGE_VERSION"-"$CRJ_BUILD"_"$OMJ_OS_RELEASE".src.rpm
        OMJ_BUILT_BIN="$(echo $TOPDIR/RPMS/$OMJ_ARCH/$CRJ_PRJ-"$CRJ_PACKAGE_VERSION"-"$CRJ_BUILD"_"$OMJ_OS_RELEASE".$OMJ_ARCH.rpm)"
        # OMJ_BUILT_DBG="$(echo $TOPDIR/RPMS/$OMJ_ARCH/$CRJ_PRJ-debuginfo-"$CRJ_PACKAGE_VERSION"-"$CRJ_BUILD"_"$OMJ_OS_RELEASE".$OMJ_ARCH.rpm)"
        # OMJ_BUILT_DBG="$(echo $TOPDIR/RPMS/$OMJ_ARCH/$CRJ_PRJ-full-debuginfo-"$CRJ_PACKAGE_VERSION"-"$CRJ_BUILD"_"$OMJ_OS_RELEASE".$OMJ_ARCH.rpm)"

        # https://stackoverflow.com/questions/11903688/error-trying-to-sign-rpm
        # rpm --define "_gpg_name $CRJ_GPG_NAME" --addsign $OMJ_BUILT_SRC $OMJ_BUILT_BIN # $OMJ_BUILT_DBG

    elif [ "$OMJ_BUILDER" == dpkg-buildpackage ]; then

        # OMJ_ARCH=`dpkg --print-architecture`

    # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1015077
    # algol68g_3.2.0-23960.orig.tar.{bz2,gz,lzma,xz}
        tar -czf ../"$CRJ_PRJ"_$TAR.orig.tar.gz * # IF debian || ubuntu... ignore .github
        ls -l ../"$CRJ_PRJ"_$TAR.orig.tar.gz
        # ../gawk_5.3.0_beta-2420437.orig.tar.gz
        # ../gawk_5.3.0-2420437.orig.tar.{bz2,gz,lzma,xz}
        
    #   ./configure # https://stackoverflow.com/questions/62039244/does-git-store-the-file-creation-time
        ./configure # needs to be before tarball - i.e. "error: aborting due to unexpected upstream changes"

    # https://stackoverflow.com/questions/12380226/how-do-i-suppress-the-editor-in-dpkg-source-commit-calls
        EDITOR=/bin/true dpkg-source -q --commit . "patch$TAR"
        #echo ECHO dpkg-buildpackage --root-command=fakeroot --build=source --sign-key=$CRJ_GPG_NAME #|| exit $?
        #dpkg-buildpackage --root-command=fakeroot --build=source --sign-key=$CRJ_GPG_NAME #|| exit $?

    # https://askubuntu.com/questions/226495/how-to-solve-dpkg-source-source-problem-when-building-a-package
    # requires fmt: algol68g_3.2.0.orig.tar.{bz2,gz,lzma,xz}
        echo ECHO dpkg-buildpackage -us -uc --root-command=fakeroot --build=binary / --sign-key=$CRJ_GPG_NAME # || exit $?
        dpkg-buildpackage -us -uc --root-command=fakeroot --build=binary # --sign-key=$CRJ_GPG_NAME # || exit $?
        ls -ltr ..
        #tar -czf ../"$CRJ_PRJ"_"$RBLD".src.tar.gz ../"$CRJ_PRJ"_"$RBLD".dsc ../"$CRJ_PRJ"_"$RBLD"_"$OMJ_ARCH".{buildinfo,changes} ../"$CRJ_PRJ"_$TAR.orig.tar.gz || exit $?

        OMJ_BUILT_SRC="$PWD/../$CRJ_PRJ"_"$RBLD".src.tar.gz
        OMJ_BUILT_BIN="$PWD/../$CRJ_PRJ"_"$RBLD"_"$OMJ_ARCH".deb
      # OMJ_BUILT_DBG="$PWD/../$CRJ_PRJ"-dbgsym_"$RBLD"_"$OMJ_ARCH".ddeb

    else
         # needs to be before tarball - i.e. "error: aborting due to unexpected upstream changes"
        if ./configure && $OMJ_BUILDER "$CRJ_PRJ"-$CRJ_PACKAGE_VERSION-$CRJ_BUILD; then
            true # ToDo Under Construction
        else
            echo "$0: cannot find rpmbuild, nor dpkg-buildpackage... Huh?" || exit $?
        fi
    fi

elif [ "$RUNNER_OS" == "macOS" ]; then
    : # softwareupdate -i -a

elif [ "$RUNNER_OS" == "Windows" ]; then
    choco install libgmp-dev libmpfr-dev r-mathlib libplot-dev libncurses-dev libpq-dev libreadline-dev libgsl-dev
    vcpkg libgmp-dev libmpfr-dev r-mathlib libplot-dev libncurses-dev libpq-dev libreadline-dev libgsl-dev

else
    echo "$RUNNER_OS not supported"
    exit 1
fi

 output OMJ_BUILT_SRC
 output OMJ_BUILT_DBG
 output OMJ_BUILT_BIN

 output OMJ_BUILT_SRC_BASENAME := "$(basename "$OMJ_BUILT_SRC" )"
 output OMJ_BUILT_DBG_BASENAME := "$(basename "$OMJ_BUILT_DBG" )"
 output OMJ_BUILT_BIN_BASENAME := "$(basename "$OMJ_BUILT_BIN" )"