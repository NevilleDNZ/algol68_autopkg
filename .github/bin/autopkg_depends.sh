#!/bin/bash
2>&1 # on github the stderr can be delayed

# cdbs - Common Debian Build System
LIBS="gcc rpm-build          gmp-devel  mpfr-devel  libRmath  plotutils-devel ncurses-devel  libpq-devel readline-devel  gsl-devel"

BLD_DEP="git gcc rpm-build rpm-sign"

# Headers and dynamic/static-libs needed to build
BLD_TINY_DEP="readline-devel"
BLD_NATIVE_DEP=""
BLD_REMIX_DEP=""
BLD_FULL_DEP="$BLD_TINY_DEP gmp-devel mpfr-devel ncurses-devel libpq-devel gsl-devel"

# dynamic-libs needed to run
RUN_TINY_DEP="readline"
RUN_NATIVE_DEP=""
RUN_REMIX_DEP=""
RUN_FULL_DEP="$RUN_TINY_DEP gmp mpfr ncurses-devel libpq gsl"
#RUN_FULL_DEP="$RUN_TINY_DEP gmp-devel mpfr-devel ncurses-devel libpq-devel gsl-devel"

LIBS="$BLD_DEP $BLD_FULL_DEP"

if [ "$RUNNER_OS" == "Linux" ]; then
    2>&1 # on github the stderr can be delayed
    #sudo .github/bin/autopkg_mgr.sh update
    sudo .github/bin/autopkg_mgr.sh -y upgrade
    sudo .github/bin/autopkg_mgr.sh -y install $LIBS
elif [ "$RUNNER_OS" == "Unix" ]; then
    2>&1 # on github the stderr can be delayed
    sudo .github/bin/autopkg_mgr.sh -y upgrade
    sudo .github/bin/autopkg_mgr.sh -y install $LIBS
elif [ "$RUNNER_OS" == "macOS" ]; then
    2>&1 # on github the stderr can be delayed
    : # softwareupdate -i -a
    sudo .github/bin/autopkg_mgr.sh -y upgrade
    sudo .github/bin/autopkg_mgr.sh -y install $LIBS
elif [ "$RUNNER_OS" == "Windows" ]; then
    sudo .github/bin/autopkg_mgr.sh -y upgrade
    sudo .github/bin/autopkg_mgr.sh -y install $LIBS
#    choco install libgmp-dev libmpfr-dev r-mathlib libplot-dev libncurses-dev libpq-dev libreadline-dev libgsl-dev
#    vcpkg libgmp-dev libmpfr-dev r-mathlib libplot-dev libncurses-dev libpq-dev libreadline-dev libgsl-dev
else
    echo "$RUNNER_OS not supported"
    exit 1
fi
