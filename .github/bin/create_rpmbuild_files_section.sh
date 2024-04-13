
eg_build_dir_name="
bindir binfmtdir builddir buildrootdir
datadir datarootdir defaultdocdir defaultlicensedir
emacs_sitelispdir emacs_sitestartdir environmentdir exec_prefix
fileattrsdir fmoddir fontbasedir fontconfig_confdir fontconfig_masterdir fontconfig_templatedir
includedir infodir initddir initrddir ivyxmldir
javaconfdir javadir javadocdir jnidir journalcatalogdir 
jvmcommondatadir jvmcommonlibdir jvmcommonsysconfdir jvmdatadir jvmdir jvmlibdir jvmprivdir jvmsysconfdir
libdir libexecdir localedir localstatedir 
mandir mavenpomdir metainfodir modprobedir modulesdir modulesloaddir monodir monogacdir oldincludedir
pkgdocdir prefix presetdir
rpmdir rpmluadir rpmmacrodir rundir
sbindir sharedstatedir sourcedir specdir srcrpmdir swidtagdir sysconfdir sysctldir
systemdgeneratordir systemd_system_env_generator_dir systemd_user_env_generator_dir systemdusergeneratordir systemd_util_dir
systemtap_datadir systemtap_tapsetdir sysusersdir
tmpfilesdir
udevhwdbdir udevrulesdir unitdir userpresetdir user_tmpfilesdir userunitdir usr usrsrc
var
"

tab=$'\t'
special_dir="dev|etc|opt|proc|run|srv|sys|usrsrc|usr|var|prefix"
re_var="_([a-z][a-z_]*(dir|home|prefix|pkg)|$special_dir)"
re_val="(/|%{$re_var})"

gen_macros(){
    rpm --showrc | {
        egrep "^-[0-9]*: $re_var$tab$re_val.*"
        echo "%def _localedir %{_datadir}/locale"
    } |
    while read a var val etc; do
        val="`rpm --eval "$val"`"
        temp="${val//[^\/]}"
        echo "${#temp}" "${#val}" "$var" "$val"
    done
}

gen_dirs(){
    gen_macros | awk '{print $3,$4;}'
}

sub_l="$(
    gen_macros | sort -nr | awk '{q="\""; print "s?"$4"/\\(.*\\)?--"substr($3,2)" "q"\\1"q"?;"; }'
)"

# echo "$sub_l"; exit

input(){
    case "$1" in
        (?*) ( cd "$1" && find . -type f | sed "s/^[.]//" );;
        (*) example;;
    esac
}

example(){
    exit
    while read file etc; do 
        case "$file" in
            (/*)echo $file ;;
        esac
    done << eof
RPM build errors:
    File listed twice: /usr/bin/gawk
    File listed twice: /usr/lib/.build-id/a0/390d5641ee82e136dbbe4a5d1c402913f11478
    Installed (but unpackaged) file(s) found:
   /etc/profile.d/gawk.csh
   /etc/profile.d/gawk.sh
   /usr/bin/awk
   /usr/bin/gawk-5.3.0
   /usr/bin/gawk-full
   /usr/bin/gawkbug
   /usr/include/gawkapi.h
   /usr/lib64/gawk/filefuncs.so
   /usr/lib64/gawk/fnmatch.so
   /usr/lib64/gawk/fork.so
   /usr/lib64/gawk/inplace.so
   /usr/lib64/gawk/intdiv.so
   /usr/lib64/gawk/ordchr.so
   /usr/lib64/gawk/readdir.so
   /usr/lib64/gawk/readfile.so
   /usr/lib64/gawk/revoutput.so
   /usr/lib64/gawk/revtwoway.so
   /usr/lib64/gawk/rwarray.so
   /usr/lib64/gawk/time.so
   /usr/libexec/awk/grcat
   /usr/libexec/awk/pwcat
   /usr/share/awk/assert.awk
   /usr/share/awk/bits2str.awk
   /usr/share/awk/cliff_rand.awk
   /usr/share/awk/ctime.awk
   /usr/share/awk/ftrans.awk
   /usr/share/awk/getopt.awk
   /usr/share/awk/gettime.awk
   /usr/share/awk/group.awk
   /usr/share/awk/have_mpfr.awk
   /usr/share/awk/inplace.awk
   /usr/share/awk/intdiv0.awk
   /usr/share/awk/isnumeric.awk
   /usr/share/awk/join.awk
   /usr/share/awk/libintl.awk
   /usr/share/awk/noassign.awk
   /usr/share/awk/ns_passwd.awk
   /usr/share/awk/ord.awk
   /usr/share/awk/passwd.awk
   /usr/share/awk/processarray.awk
   /usr/share/awk/quicksort.awk
   /usr/share/awk/readable.awk
   /usr/share/awk/readfile.awk
   /usr/share/awk/rewind.awk
   /usr/share/awk/round.awk
   /usr/share/awk/shellquote.awk
   /usr/share/awk/strtonum.awk
   /usr/share/awk/tocsv.awk
   /usr/share/awk/walkarray.awk
   /usr/share/awk/zerofile.awk
   /usr/share/info/dir
   /usr/share/info/gawk.info.gz
   /usr/share/info/gawk_api-figure1.png.gz
   /usr/share/info/gawk_api-figure2.png.gz
   /usr/share/info/gawk_api-figure3.png.gz
   /usr/share/info/gawk_array-elements.png.gz
   /usr/share/info/gawk_general-program.png.gz
   /usr/share/info/gawk_process-flow.png.gz
   /usr/share/info/gawk_statist.jpg.gz
   /usr/share/info/gawkinet.info.gz
   /usr/share/info/gawkworkflow.info.gz
   /usr/share/info/pm-gawk.info.gz
   /usr/share/locale/bg/LC_MESSAGES/gawk.mo
   /usr/share/locale/ca/LC_MESSAGES/gawk.mo
   /usr/share/locale/da/LC_MESSAGES/gawk.mo
   /usr/share/locale/de/LC_MESSAGES/gawk.mo
   /usr/share/locale/es/LC_MESSAGES/gawk.mo
   /usr/share/locale/fi/LC_MESSAGES/gawk.mo
   /usr/share/locale/fr/LC_MESSAGES/gawk.mo
   /usr/share/locale/id/LC_MESSAGES/gawk.mo
   /usr/share/locale/it/LC_MESSAGES/gawk.mo
   /usr/share/locale/ja/LC_MESSAGES/gawk.mo
   /usr/share/locale/ko/LC_MESSAGES/gawk.mo
   /usr/share/locale/ms/LC_MESSAGES/gawk.mo
   /usr/share/locale/nl/LC_MESSAGES/gawk.mo
   /usr/share/locale/pl/LC_MESSAGES/gawk.mo
   /usr/share/locale/pt/LC_MESSAGES/gawk.mo
l object.
To https://github.com/NevilleDNZ-downstream/algol68_autopkg   /usr/share/locale/pt_BR/LC_MESSAGES/gawk.mo
   /usr/share/locale/ro/LC_MESSAGES/gawk.mo
   /usr/share/locale/sr/LC_MESSAGES/gawk.mo
   /usr/share/locale/sv/LC_MESSAGES/gawk.mo
   /usr/share/locale/uk/LC_MESSAGES/gawk.mo
   /usr/share/locale/vi/LC_MESSAGES/gawk.mo
   /usr/share/locale/zh_CN/LC_MESSAGES/gawk.mo
   /usr/share/man/man1/gawk.1.gz
   /usr/share/man/man1/gawkbug.1.gz
   /usr/share/man/man1/pm-gawk.1.gz
   /usr/share/man/man3/filefuncs.3am.gz
   /usr/share/man/man3/fnmatch.3am.gz
   /usr/share/man/man3/fork.3am.gz
   /usr/share/man/man3/inplace.3am.gz
   /usr/share/man/man3/ordchr.3am.gz
   /usr/share/man/man3/readdir.3am.gz
   /usr/share/man/man3/readfile.3am.gz
   /usr/share/man/man3/revoutput.3am.gz
   /usr/share/man/man3/revtwoway.3am.gz
   /usr/share/man/man3/rwarray.3am.gz
   /usr/share/man/man3/time.3am.gz
eof
}

# ${_localedir}/bg/LC_MESSAGES/*
# --localedir "pt_BR/LC_MESSAGES/gawk.mo"

gen_autopkg_opts(){
    input "$@" | sed "$sub_l "'s?\(\b\|/\)[^ /]*"$?\1*"?; s/$/ \\/;' | sort -u
}

gen_files_section(){
    gen_autopkg_opts "$@" | sed "$sub_l;"' s/--/%_/; s/" .*//; s/"//;' | sort -u
}

help(){
    cat << eof
Usage:
   create_rpmbuild_files_section.sh gen_dirs ~/rpmbuild/BUILDROOT/<app_name>-<version>-<release>
   create_rpmbuild_files_section.sh gen_files_section ~/rpmbuild/BUILDROOT/<app_name>-<version>-<release>
   create_rpmbuild_files_section.sh gen_autopkg_opts ~/rpmbuild/BUILDROOT/<app_name>-<version>-<release>

1st: Configuring the Package:

    bash$ ./configure --prefix=/usr
    bash$ make

Here, --prefix=/usr sets the installation prefix to /usr, meaning
under normal circumstances, binaries would go to /usr/bin, libraries to
/usr/lib, etc.

2nd: Staged Installation Using DESTDIR:

    bash$ make install DESTDIR=/tmp/staging-area

%{buildroot}: This macro is used to refer to the build root directory. The make
install command often uses the DESTDIR variable to specify a root directory
where files should be installed, which should be set to %{buildroot} to
ensure files go into the correct temporary location for packaging.

GNU Autotools is a suite of programming tools designed to assist in
making source code packages portable to many Unix-like systems. When
using Autotools (autoconf, automake), the make install command is often
used in conjunction with a DESTDIR variable to specify a different root
directory for the installation, typically during package creation or staged
installations. This is crucial for package maintainers who need to install
software into a temporary location rather than the system's actual directories.
Understanding DESTDIR

The DESTDIR variable is used as a staging area for installing files. When
make install DESTDIR=/path/to/temp is run, the installation process will
prepend /path/to/temp to all installation paths specified by the PREFIX and
other related directories (BINDIR, LIBDIR, etc.). This allows the installed
files to be packaged by tools like rpmbuild, without interfering with the
actual system files.  

How DESTDIR Works with PREFIX:

PREFIX defines where the software is to be installed permanently. It's
typically set during the configuration phase (e.g., ./configure
--prefix=/usr/local).  DESTDIR, on the other hand, is used temporarily during
the make install phase to redirect the installation.

When you combine DESTDIR with PREFIX, files that would normally
go into ${PREFIX}/bin, ${PREFIX}/lib, etc., will instead go into
${DESTDIR}${PREFIX}/bin, ${DESTDIR}${PREFIX}/lib, etc., during installation.
eof
    exit 1
}

cmd="$1"; shift
case "$cmd" in
    (*help)help;;
    (*gen_dirs|-d)gen_dirs "$@";;
    (*gen_files_section|-f)gen_files_section "$@";;
    (*gen_autopkg_opts|-a)gen_autopkg_opts "$@";;
    (*input|-i)input "$@";;
    (*)help;
esac
