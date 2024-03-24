#!/bin/bash
2>&1 # on github the stderr can be delayed

translate_to_dnf(){ # native
    case "$1" in
        (build|builder) shift; $OPT_ECHO rpmbuild "$@";;
        (local) shift; $OPT_ECHO rpm "$@";;
        (ext) shift; $OPT_ECHO .rpm "$@";;
        (mime) shift; $OPT_ECHO application/x-rpm "$@";;
        (arch) shift; $OPT_ECHO `rpm --eval '%{_arch}'` "$@";;
        (_arch) shift; $OPT_ECHO .`rpm --eval '%{_arch}'` "$@";;
        (*) $OPT_ECHO "$MGR" "$@";;
    esac
}
translate_to_zypper(){ # native
# mimic dnf
    action="$1"; shift
    ORIG_IFS="$IFS"     # Save the original IFS
    IFS=$'\n' # Change IFS to newline
    # Rebuild "$@" with modified values
    set -- $(
        for arg in "$@"; do
            case "$arg" in
                (-y) echo --non-interactive;;
            esac
        done
    )
    IFS="$ORIG_IFS" # Reset IFS to its original value

    case "$action" in
        (build|builder) shift; $OPT_ECHO rpmbuild "$@";;
        (local) shift; $OPT_ECHO rpm "$@";;
        (ext) shift; $OPT_ECHO .rpm "$@";;
        (mime) shift; $OPT_ECHO application/x-rpm "$@";;
        (arch) shift; $OPT_ECHO `rpm --eval '%{_arch}'` "$@";;
        (_arch) shift; $OPT_ECHO .`rpm --eval '%{_arch}'` "$@";;
        (*) $OPT_ECHO "$MGR" "$@";;
    esac
}

# RHEL9
#   sudo autopkg_mgr install rpm-build gmp-devel  mpfr-devel  libRmath  plotutils-devel ncurses-devel  libpq-devel readline-devel  gsl-devel
# Ubuntu
#   sudo autopkg_mgr install cdbs     libgmp-dev libmpfr-dev r-mathlib libplot-dev     libncurses-dev libpq-dev   libreadline-dev libgsl-dev

translate_to_apt(){ # mimic dnf
    action="$1"; shift
    ORIG_IFS="$IFS"     # Save the original IFS
    IFS=$'\n' # Change IFS to newline
    # Rebuild "$@" with modified values
    set -- $(
        for arg in "$@"; do
            case "$arg" in
                (rpm-build) echo cdbs; echo debhelper;;
                (rpm-sign) echo cdbs;;
                (libRmath) echo r-mathlib;;
                (plotutils-devel) echo libplot-dev;;
                (libpq-devel) echo libpq-dev;;
                (*) echo "$arg" | sed 's/\(.*\)-devel$/lib\1-dev/g';;
            esac
        done
    )
    IFS="$ORIG_IFS" # Reset IFS to its original value

    case "$action" in
        (upgrade)
            $OPT_ECHO "$MGR" "update" "$@"
            $OPT_ECHO "$MGR" "$action" "$@";;
        (build|builder)
            $OPT_ECHO dpkg-buildpackage "$@"
        ;;
        (local) shift; $OPT_ECHO rpm "$@";;
        (ext) shift; $OPT_ECHO .rpm "$@";;
        (mime) shift; $OPT_ECHO application/x-rpm "$@";;
        (arch) shift; $OPT_ECHO `dpkg --print-architecture` "$@";;
        (_arch) shift; $OPT_ECHO _`dpkg --print-architecture` "$@";;
        (*) $OPT_ECHO "$MGR" "$action" "$@";;
    esac
}

translate_to_choco(){ # native
    exec $OPT_ECHO "$MGR" "$@"
}

translate_to_vcpkg(){ # native
    $OPT_ECHO "$MGR" "$@"
}

translate_to_softwareupdate(){ # native
    $OPT_ECHO "$MGR" "$@"
}

# sometimes both rpm and dpkg exist on the same system.
#for mgr in dnf yum apt rpm dpkg choco vcpkg softwareupdate; do
#    MGR=`which "$mgr"`
#    if [ "$MGR" ]; then
#        break
#    fi
#done

# Function to detect the package manager
detect_pkg_mgr() {
    # ( ls /etc | fmt; head -99 /etc/debian_version /etc/os-release; uname -a ) 1>&2
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            (debian|raspbian) echo apt;;
            (rhel|fedora|rocky|centos) echo dnf;;
            (*suse*|opensuse-leap) echo zypper;;
            (*)
                for like in "$ID_LIKE"; do
                    case "$like" in
                        (debian|raspbian) echo apt; break;;
                        (rhel|fedora|rocky|centos) echo dnf; break;;
                        (*suse*|opensuse-leap) echo zypper; break;;
                    esac
                    # otherwise: (*) echo linux_like_pkg_mgr_unknown; break;;
                done
            ;;
        esac 
    else
        #if [ -f /etc/debian_version ]; then
        #    echo "apt"
        #elif [ -f /etc/redhat-release ]; then
        #    echo "dnf"  # Assuming RHEL 8+, use 'yum' for older versions
        #el
        if [ -f /etc/arch-release ]; then
            echo "pacman"
        elif uname -s | grep -q FreeBSD; then
            echo "pkg"
        elif uname -s | grep -q CYGWIN; then
            echo "cygwin"
        # Add other package manager detections here
        else
            echo "Other pkg_mgr_unknown"
        fi
    fi
}

MGR=`detect_pkg_mgr`

case "$1" in
    (echo) OPT_ECHO="$1"; shift;;
    (*) OPT_ECHO="";;
esac

case "$MGR" in
    (dnf|yum)translate_to_dnf "$@";;
    (apt)translate_to_apt "$@";;
    (zypper)translate_to_zypper "$@";;
    (pacman)translate_to_pacman "$@";;
    (pkg)translate_to_pkg "$@";;
    (cygwin)translate_to_cygwin "$@";;
    (*)echo "Huh? $mgr $MGR $@";;
esac

exit
cat << end_cat > /dev/null
Here's a comprehensive list of package managers across various platforms,
including common Linux distributions, Unix systems (including SCO Unix,
Solaris, FreeBSD, etc.), Cygwin, GNU Hurd, and Windows. For each, I've
included the preferred file extension, commands to install, uninstall,
build package archives, list installed packages, and list available
packages from repositories. The package name used in the examples
is app_x.

Common Linux Distributions

    APT (Debian, Ubuntu)
        Extension: .deb
        Install: sudo apt-get install app_x
        Uninstall: sudo apt-get remove app_x
        Build: dpkg-buildpackage
        List Installed: apt list --installed
        List Available: apt-cache search .

    DPKG (Debian, Ubuntu)
        Extension: .deb
        Install: sudo dpkg -i app_x.deb
        Uninstall: sudo dpkg -r app_x
        Build: dpkg-deb --build directoryname
        List Installed: dpkg --get-selections
        List Available: Not directly applicable, managed via APT

    YUM (Older Red Hat, CentOS)
        Extension: .rpm
        Install: sudo yum install app_x
        Uninstall: sudo yum remove app_x
        Build: rpmbuild -ba app_x.spec
        List Installed: yum list installed
        List Available: yum list available

    DNF (Fedora, RHEL 8+)
        Extension: .rpm
        Install: sudo dnf install app_x
        Uninstall: sudo dnf remove app_x
        Build: rpmbuild -ba app_x.spec
        List Installed: dnf list --installed
        List Available: dnf list available

    RPM (Red Hat, CentOS, Fedora)
        Extension: .rpm
        Install: sudo rpm -i app_x.rpm
        Uninstall: sudo rpm -e app_x
        Build: rpmbuild -ba app_x.spec
        List Installed: rpm -qa
        List Available: Not directly applicable, managed via YUM/DNF

    Zypper (openSUSE)
        Extension: .rpm
        Install: sudo zypper install app_x
        Uninstall: sudo zypper remove app_x
        Build: rpmbuild -ba app_x.spec
        List Installed: zypper se --installed-only
        List Available: zypper se

    Pacman (Arch Linux)
        Extension: .pkg.tar.zst
        Install: sudo pacman -S app_x
        Uninstall: sudo pacman -R app_x
        Build: makepkg -s
        List Installed: pacman -Q
        List Available: pacman -Ss

    Portage (Gentoo)
        Extension: Ebuild scripts
        Install: sudo emerge app_x
        Uninstall: sudo emerge --deselect app_x
        Build: Ebuild process is inherently a build process
        List Installed: equery list --installed
        List Available: equery list

Common Unix Systems

    pkgsrc (NetBSD, Solaris, and others)
        Extension: Source tarballs or binary packages
        Install: pkg_add app_x
        Uninstall: pkg_delete app_x
        Build: cd /usr/pkgsrc/category/app_x && bmake package
        List Installed: pkg_info
        List Available: pkgin avail

    IPS (Solaris)
        Extension: .p5p
        Install: pkg install app_x
        Uninstall: pkg uninstall app_x
        Build: pkgmk
        List Installed: pkg list
        List Available: pkg list -a

    SCO Unix (SCO OpenServer)
        Extension: .vol
        Install: custom
        Uninstall: custom
        Build: Specific to development tools used
        List Installed: pkginfo
        List Available: Typically managed through "custom"

    pkg (FreeBSD)
        Extension: .txz
        Install: pkg install app_x
        Uninstall: pkg delete app_x
        Build: make package
        List Installed: pkg info
        List Available: pkg search .

Cygwin (Windows with Unix-like environment)

    Cygwin
        Extension: .tar.xz
        Install/Uninstall: Use Cygwin Setup GUI
        Build: Depends on the source and build system
        List Installed: cygcheck --check-setup --dump-only
        List Available: Use Cygwin Setup GUI

GNU Hurd

    GNU Hurd typically uses the same package managers as Linux, depending
    on the distribution running on Hurd (e.g., Debian GNU/Hurd would
    use APT and DPKG).


Windows

    Chocolatey (Windows)
        Extension: N/A (Uses NuGet packages)
        Install: choco install app_x
        Uninstall: choco uninstall app_x
        Build: Depends on software being packaged
        List Installed: choco list --local-only
        List Available: choco list --remote

    Winget (Windows)
        Extension: N/A (Uses YAML manifests)
        Install: winget install app_x
        Uninstall: winget uninstall app_x
        Build: N/A (Winget is a package manager, not a build system)
        List Installed: winget list
        List Available: winget search

Special Considerations

    For some Unix systems (like older versions of SCO Unix), the package
    management can be quite rudimentary and might not offer the same
    functionalities as modern systems.

    The build commands for package managers typically assume that you
    have the necessary build environment set up and are familiar with
    the build process for that specific package system.

    For some package managers, listing available packages might require
    access to the internet or configured repositories.

end_cat

