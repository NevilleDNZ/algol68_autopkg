#!/usr/bin/python3
from genericpath import isdir
import re, time, os, sys, pprint

from collections import OrderedDict
from itertools import product
try:
    from socket import gethostname
    hostname_=gethostname()+"_"
except:
    hostname_=""

def pp(**arg_d):
    return pprint.pprint(arg_d,width=132)

prefix=r"^configure:(?P<line>[1-9][0-9]*): "

sep_d=dict(
    enable_l=re.compile(r"(--enable-[^ ]+)"),
    option_l=re.compile(r"([^ ]+)"),
    lib_l=re.compile(r"(-[^ ]*)"),
)

conf_il=(
    # ## Platform. ##
    ("chapter",re.compile(r"^## (?P<chapter>[^- ].*[^- ]) *##")),
    #   $ ./configure --disable-assert --disable-compiler --disable-curses --disable-dependency-tracking --disable-gsl --disable-gsltest --disable-mathlib --enable-mpfr --disable-option-checking --disable-parallel --disable-pic --disable-plotutils --disable-postgresql --disable-quadmath --disable-readline --disable-silent-rules
    ("enable_l",re.compile(r"^ *[$] .*/configure(?P<match_l>.* --enable-[^ ]+.*) *")),
    # Configured with: ../configure --enable-bootstrap --enable-languages=c,c++,fortran,lto --prefix=/usr --mandir=/usr/share/man --infodir=/usr/share/info --with-bugurl=http://bugzilla.redhat.com/bugzilla --enable-shared --enable-threads=posix --enable-checking=release --enable-multilib --with-system-zlib --enable-__cxa_atexit --disable-libunwind-exceptions --enable-gnu-unique-object --enable-linker-build-id --with-gcc-major-version-only --with-linker-hash-style=gnu --enable-plugin --enable-initfini-array --with-isl --disable-libmpx --enable-offload-targets=nvptx-none --without-cuda-driver --enable-gnu-indirect-function --enable-cet --with-tune=generic --with-arch_32=x86-64 --build=x86_64-redhat-linux
    ("option_l",re.compile(r"^Configured with: ../configure (?P<match_l>.*)")),
    # configure:6290: GNU MPFR...
    ("paragraph",re.compile(prefix+r"(?P<paragraph>[^ ].*[^ ])[.]{3,3}$")),
    # configure:6080: checking 64-bit long long unsigned is available
    ("checking_available",re.compile(prefix+r"checking (?P<hdr>.*[.]h) available")),
    # configure:6342: checking mpfr.h presence
    ("checking_presence",re.compile(prefix+r"checking (?P<hdr>.*[.]h) presence")),
    # configure:6342: checking mpfr.h usability
    ("checking_usability",re.compile(prefix+r"checking (?P<hdr>.*[.]h) usability")),
    # configure:5586: checking whether termios.h defines TIOCGWINSZ
    ("checking_whether",re.compile(prefix+r"checking whether (?P<hdr>.*[.]h) defines (?P<defines>[^ ]+)$")),
    # configure:3130: checking whether make sets $(MAKE)
    ("checking_whether",re.compile(prefix+r"checking whether (?P<other>.*)$")),
    # configure:5545: checking for sys/wait.h that is POSIX.1 compatible
    ("checking_for",re.compile(prefix+r"checking for (?P<hdr>.*[.]h) +(?P<that_is>[^ ]+)")),
    # configure:8261: checking for working ncursesw/curses.h
    ("checking_hdr",re.compile(prefix+r"checking for working (?P<hdr>.*[.]h)$")),
    # configure:6342: checking for mpfr.h
    ("checking_hdr",re.compile(prefix+r"checking for (?P<hdr>.*[.]h)$")),
    ("checking_hdr_other",re.compile(prefix+r"checking for (?P<hdr>.*[.]h) *(?P<other>.*)$")),
    # configure:8072: checking for ncursesw via pkg-config
    ("checking_lib_has_pc",re.compile(prefix+r"checking for (?P<lib>[^ ]*) via pkg-config$")),
    # configure:6353: checking for mpfr_gamma in -lmpfr
    ("checking_function_in_lib",re.compile(prefix+r"checking for (?P<function>[^ ]*) in -l(?P<lib>[^ ]+)")),
    # configure:5680: checking for aligned_alloc
    ("checking_name",re.compile(prefix+r"checking for (?P<name>[^ ]+)$")),
    ("checking_name_other",re.compile(prefix+r"checking for(| a) (?P<name>[^ ]+) *(?P<other>.*)$")),
    # configure:5914: checking int is 32 bit
    ("checking_for",re.compile(prefix+r"checking for (?P<checking_for>.*)")),
    # configure:5914: checking for a thread-safe mkdir -p
    ("checking_is",re.compile(prefix+r"checking (?P<checking>.*) is (?P<is>.*)")),
    # configure:5914: checking 80-bit __float80 has 64-bit mantissa
    ("checking_has",re.compile(prefix+r"checking (?P<checking>[^ ]+) has (?P<has>.*)")),
    ("checking_other",re.compile(prefix+r"checking (?P<other>.*)$")),
    # configure:3108: found /usr/bin/gawk
    ("result",re.compile(prefix+r"found (?P<found>[^ ])+")),
    # configure:6326: result: yes
    ("result",re.compile(prefix+r"result: (?P<result>[^ ]+)")),
    # #define PACKAGE_STRING "algol68g 3.0.6"
    #("str",re.compile(r'^#define +(?P<define>.*)')),
    # #define PACKAGE_STRING "algol68g 3.0.6"
    ("str",re.compile(r'^#define +(?P<name>[^ ]+) +"(?P<value>[^"]*)" *(?P<etc>.*)')),
    ("int",re.compile(r'^#define +(?P<name>[^ ]+) +"(?P<value>[^"][0-9]+)" *(?P<etc>.*)')),
    ("float",re.compile(r'^#define +(?P<name>[^ ]+) +"(?P<value>[^"][0-9]+[.][0-9]*)" *(?P<etc>.*)')),
    # #define HAVE_MPFR_H 1
    ("code",re.compile(r"^#define +(?P<name>[^ ]+) +(?P<value>.*)$")),
    # LIBS='-lmpfr -lgmp -lm '
    ("lib_l",re.compile(r"LIBS='(?P<match_l>(:?-l[^ ]+ )+) *'$")),
    # am_cv_prog_cc_c_o=yes
    ("var", re.compile("^ *(?P<name>[a-z_][a-z0-9_]*) *= *(?P<value>.*) *$", re.IGNORECASE)),
    # other
    ("other",re.compile(r"(?P<line>.*)$")),
)
#i=1
#conf_il=conf_il[i:i+1]

def cut_here():
    print("-"*32+"8><"+" -"*16)

OPT_v=not True

tab="    "
def lexx_config_log(config_log):
    for line in config_log:
        for desc,re_line in conf_il:
            line=line.rstrip()
            match=(re_line.search(line))
            if (match):
                if desc=="result" and OPT_v: print(tab, "=>", end="")
                if OPT_v: print(desc,line)
                if desc.endswith("_l"):
                    re_sep=sep_d[desc]
                    #print(tab,match.groups())
                    #print(tab,match.groupdict())
                    #print(tab,re_line.split(line))
                    #print(tab,match.groupdict()["match_l"])
                    match_l=re_sep.split(match.groupdict()["match_l"])[1::2]
                    if OPT_v: print(tab,match_l)
                    yield desc, match_l
                else:
                    if OPT_v: print(tab,match.groupdict())
                    yield desc,match.groupdict()
                break
        else:
            pass

class ItemList(list):
    pass

def compile_config_log(lexx_config_log):
    sentence_d=ItemList()
    paragraph_d=OrderedDict(paragraph_0=sentence_d)
    chapter_d=OrderedDict(chapter_0=paragraph_d)
    for desc,detail in lexx_config_log:
        if desc=="chapter":
            sentence_d=ItemList()
            paragraph_d=OrderedDict(paragraph_0=sentence_d)
            chapter_d[detail["chapter"]]=paragraph_d
        elif desc=="paragraph":
            sentence_d=ItemList()
            paragraph_d[detail["paragraph"]]=sentence_d
        if desc=="other":
            pass # sentence_d.append([desc,detail])
        elif desc!="result":
            # pre_result=[desc,detail]
            pre_result=OrderedDict(desc=desc)
            if isinstance(detail,list):
                pre_result.update(dict(list=detail))
            else:
                pre_result.update(detail)

            sentence_d.append(pre_result)
        else:
            # pre_result.append(detail)
            pre_result.update(detail)
            if OPT_v: print (tab, end="")
        # print(desc,detail)
    return chapter_d

default_width=132

def print_config_log(chapter_d, this_dep_summary_of_lib_l={}, width=default_width ):
    #pprint.pprint(chapter_d)
    for chapter,paragraph_d in chapter_d.items():
        print(chapter+":")
        for paragraph,sentence_d in paragraph_d.items():
            print(tab,paragraph, end=": "); pprint.pprint(sentence_d, width=width)

class PrintableList(list):
    def __repr__(self):
        sep = " " if opt_d.package_builder == package_builder_rpm else ", "
        return sep.join(uniq(self)) #.join("{}")

    def __add__(self,other):
        return PrintableList(super().__add__(other))

def get_macos_pkg_template_of_sect_of_subfile():
# https://www.ibiblio.org/pub/packages/solaris/sparc/html/creating.solaris.packages.html
    template_of_sect_of_subfile=OrderedDict()
    template_of_sect_of_pkginfo=template_of_sect_of_subfile["pkginfo"]=OrderedDict()

    template_of_sect_of_pkginfo["head"]='''\
    PKG="GNUbison"
    NAME="GNU bison 1.24"
    VERSION="1.24"
    ARCH="sparc"
    CLASSES="none"
    CATEGORY="utility"
    VENDOR="GNU"
    PSTAMP="4thSep95"
    EMAIL="request@gnu.ai.mit.edu"
    ISTATES="S s 1 2 3"
    RSTATES="S s 1 2 3"
    BASEDIR="/"
'''
    return template_of_sect_of_subfile

def get_unix_pkg_template_of_sect_of_subfile():
# https://www.ibiblio.org/pub/packages/solaris/sparc/html/creating.solaris.packages.html
    template_of_sect_of_subfile=OrderedDict()
    template_of_sect_of_pkginfo=template_of_sect_of_subfile["pkginfo.json"]=OrderedDict()

    template_of_sect_of_pkginfo["head"]='''\
{ "name":"algol68g",
    "full_name":"algol68g",
    "tap":"homebrew/core",
    "oldname":null,
    "aliases":[],
    "versioned_formulae":[],
    "desc":"Algol 68 compiler-interpreter",
    "license":"GPL-3.0-or-later",
    "homepage":"https://jmvdveer.home.xs4all.nl/algol.html",
    "versions":{"stable":"2.8.5","head":null,"bottle":true},
    "urls":{
        "stable":{
            "url":"https://ftp.openbsd.org/pub/OpenBSD/distfiles/algol68g-2.8.5.tar.gz",
            "tag":null,
            "revision":null
        }
    },
    "revision":0,"version_scheme":0,
    "bottle":{
        "stable":{
            "rebuild":0,
            "root_url":"https://ghcr.io/v2/homebrew/core",
            "files":{
                "arm64_monterey":{"cellar":":any_skip_relocation",
                    "url":"https://ghcr.io/v2/homebrew/core/algol68g/blobs/sha256:98edac632999d9493f86e738c6fdec7782cde8d07768c6a495681cd5de0103a4",
                    "sha256":"98edac632999d9493f86e738c6fdec7782cde8d07768c6a495681cd5de0103a4"
                },
                "arm64_big_sur":{"cellar":"/opt/homebrew/Cellar",
                    "url":"https://ghcr.io/v2/homebrew/core/algol68g/blobs/sha256:5e90719ca013bddd6066b0e1e87d6162094ee73ef300233f1f75d9833bf4dc42",
                    "sha256":"5e90719ca013bddd6066b0e1e87d6162094ee73ef300233f1f75d9833bf4dc42"
                },
                "monterey":{"cellar":"/usr/local/Cellar",
                    "url":"https://ghcr.io/v2/homebrew/core/algol68g/blobs/sha256:1f5961932f3fac98be74b6d33e23f1a91cfe48e3173ef4b5c9cb94743cdeb10a",
                    "sha256":"1f5961932f3fac98be74b6d33e23f1a91cfe48e3173ef4b5c9cb94743cdeb10a"
                },
                "big_sur":{"cellar":"/usr/local/Cellar",
                    "url":"https://ghcr.io/v2/homebrew/core/algol68g/blobs/sha256:7b7bb03b6cbe89d253b5e88294ecc4edf61a0687c4534f26ffb7422efe22e52d",
                    "sha256":"7b7bb03b6cbe89d253b5e88294ecc4edf61a0687c4534f26ffb7422efe22e52d"
                },
                "catalina":{"cellar":"/usr/local/Cellar",
                    "url":"https://ghcr.io/v2/homebrew/core/algol68g/blobs/sha256:046ba5e9ec0d0856557085fdf1acde227cd829d9955da28046e98c9a5ee84c09",
                    "sha256":"046ba5e9ec0d0856557085fdf1acde227cd829d9955da28046e98c9a5ee84c09"
                },
                "mojave":{"cellar":"/usr/local/Cellar",
                    "url":"https://ghcr.io/v2/homebrew/core/algol68g/blobs/sha256:7e1acd53615ebc407aaae64eb23af6047dbbd42f967e422b3fcfa0c6d01307b6",
                    "sha256":"7e1acd53615ebc407aaae64eb23af6047dbbd42f967e422b3fcfa0c6d01307b6"
                },
                "high_sierra":{"cellar":"/usr/local/Cellar",
                    "url":"https://ghcr.io/v2/homebrew/core/algol68g/blobs/sha256:18013401e3eed914022e0a34c6b9b1ed415ec679113de78970d74aa52b0a35e8",
                    "sha256":"18013401e3eed914022e0a34c6b9b1ed415ec679113de78970d74aa52b0a35e8"
                },
                "x86_64_linux":{"cellar":"/home/linuxbrew/.linuxbrew/Cellar",
                    "url":"https://ghcr.io/v2/homebrew/core/algol68g/blobs/sha256:3db30a51c50dc264cf0f7d261fb936a17ffad5cb14f73b105e44a69a10d56f30",
                    "sha256":"3db30a51c50dc264cf0f7d261fb936a17ffad5cb14f73b105e44a69a10d56f30"
                }
            }
       }
    },
    "keg_only":false,
    "keg_only_reason":null,
    "bottle_disabled":false,
    "options":[],
    "build_dependencies":[],
    "dependencies":[],
    "recommended_dependencies":[],
    "optional_dependencies":[],
    "uses_from_macos":[],
    "requirements":[],
    "conflicts_with":[],
    "caveats":null,"installed":[],
    "linked_keg":null,
    "pinned":false,
    "outdated":false,
    "deprecated":false,
    "deprecation_date":null,
    "deprecation_reason":null,
    "disabled":false,
    "disable_date":null,
    "disable_reason":null,
    "analytics":{
        "install":           { "30d":{"algol68g":1148}, "90d":{"algol68g":3259}, "365d":{"algol68g":13450}},
        "install_on_request":{ "30d":{"algol68g":1146}, "90d":{"algol68g":3256}, "365d":{"algol68g":13448}},
        "build_error":       { "30d":{"algol68g":5} }
    },
    "analytics-linux":{
        "install":           {"30d":{"algol68g":0},"90d":{"algol68g":0},"365d":{"algol68g":6}},
        "install_on_request":{"30d":{"algol68g":0},"90d":{"algol68g":0},"365d":{"algol68g":6}},
        "build_error":       {"30d":{"algol68g":0}}
    },
    "generated_date":"2022-03-17"
}
'''
    return template_of_sect_of_subfile

def get_dpkg_deb_template_of_sect_of_subfile():
    template_of_sect_of_subfile=OrderedDict()
    # subdir="{PACKAGE_TARNAME}-{PACKAGE_VERSION}-{opt_d.Epoch}/debian/"
    subdir="debian/"

    template_of_sect=template_of_sect_of_subfile[subdir+"README.source"]=OrderedDict()
    template_of_sect["head"]='''\
This package uses quilt to manage all modifications to the upstream
source. Changes are stored in the source package as diffs in
debian/patches and applied during the build.
See /usr/share/doc/quilt/README.source for a detailed explanation.
'''
    template_of_sect=template_of_sect_of_subfile[subdir+"docs"]=OrderedDict()
    template_of_sect["head"]='''\
AUTHORS
NEWS
README
'''
    template_of_sect=template_of_sect_of_subfile[subdir+"changelog"]=OrderedDict()
    template_of_sect["head"]='''\
{confdefs[PACKAGE_TARNAME]} ({opt_d.PACKAGE_VERSION}-{opt_d.Build}-{opt_d.os_release}) unstable; urgency=medium

  * New upstream version {opt_d.PACKAGE_VERSION}-{opt_d.Build}-{opt_d.os_release}

 -- {opt_d.Packager}  {opt_d.DEBPackDate}

{confdefs[PACKAGE_TARNAME]} (2.1.2-1) unstable; urgency=low

  * Initial release. (Closes: #598192)

 -- Tomas Fasth <tomfa@debian.org>  Mon, 25 Jun 2012 01:05:51 +0200
'''

# cf. https://www.debian.org/doc/manuals/maint-guide/dreq.en.html#control
    """ Here is a simplified description of package relationships: [33]
        Depends Recommends Suggests Pre-Depends Conflicts Breaks Provides Replaces
    """
    template_of_sect=template_of_sect_of_subfile[subdir+"control"]=OrderedDict()
    template_of_sect["head"]='''\
Source: {confdefs[PACKAGE_TARNAME]}
Section: {opt_d.Section}
Priority: {opt_d.Priority}
Maintainer: {confdefs[PACKAGE_BUGREPORT]}
Standards-Version: 4.2.1
Homepage: {opt_d.DOCUMENTATION_PAGE}

Package: {confdefs[PACKAGE_TARNAME]}
Architecture: any
Depends: ${lc}shlibs:Depends{rc}, ${lc}misc:Depends{rc}
'''

    template_of_sect["capabilities/subpkg"]='''\
# {SUBPACKAGE} requires:
# Build-Depends: cdbs, debhelper (>= 10.0.0), autotools-dev, {dep_of_this_subpkg[DPKG_BuildRequiresPkg]}
# Depends:       {dep_of_this_subpkg[DPKG_RunRequiresPkg]}
# Provides:      {dep_of_this_subpkg[DPKG_ProvidesCap]}
'''
#BuildRequires: {dep_of_this_subpkg[BuildRequiresCap]}

    template_of_sect["description"]='''\
Description: Implementation of {confdefs[PACKAGE_NAME]}
{read[README/control]}

'''
    template_of_sect=template_of_sect_of_subfile[subdir+"watch"]=OrderedDict()
    template_of_sect["head"]='''\
# See uscan(1) for format

# Compulsory line, this is a version 3 file
version=3
{opt_d.DOWNLOAD_PAGE} {confdefs[PACKAGE_TARNAME]}-(.+)[.]tar[.]gz

# {opt_d.Source_l}

# Uncomment for actual upstream tar
# https://jmvdveer.home.xs4all.nl/{confdefs[PACKAGE_TARNAME]}-(.*)\.tar.gz l

# Uncomment to find new files on sourceforge, for devscripts >= 2.9
# http://sourceforge.net/projects/algol68/files/{confdefs[PACKAGE_TARNAME]}/{confdefs[PACKAGE_TARNAME]}-(.*)/{confdefs[PACKAGE_TARNAME]}-(.*)\.tar.gz
'''
    template_of_sect=template_of_sect_of_subfile[subdir+"copyright"]=OrderedDict()
    template_of_sect["head"]='''\
This work was packaged for Debian by:

    {opt_d.Packager} on {opt_d.DEBPackDate}

It was downloaded from:

  - {opt_d.DOWNLOAD_PAGE}
  - {opt_d.Source_l}

Upstream Author:

    {confdefs[PACKAGE_BUGREPORT]}

Copyright:

    {read[AUTHORS]}

License:

    {read[COPYING]}

'''
# pre a68g-3.1.9 was: #     {read[LICENSE]}

    template_of_sect=template_of_sect_of_subfile[subdir+"compat"]=OrderedDict()
    template_of_sect["head"]='''\
10
'''
    template_of_sect=template_of_sect_of_subfile[subdir+"source/format"]=OrderedDict()
    template_of_sect["head"]='''\
3.0 (quilt)
'''
    template_of_sect=template_of_sect_of_subfile[subdir+"rules"]=OrderedDict()
    template_of_sect["head"]='''\
#!/usr/bin/make -f

include /usr/share/cdbs/1/rules/debhelper.mk
include /usr/share/cdbs/1/class/autotools.mk


# Add here any variable or target overrides you need.
'''
    return template_of_sect_of_subfile

def get_rpm_spec_template_of_sect_of_subfile():
    template_of_sect_of_subfile=OrderedDict()
    #Q# template_of_sect_of_spec=template_of_sect_of_subfile["{PACKAGE_TARNAME}-{PACKAGE_VERSION}-{opt_d.Epoch}.spec"]=OrderedDict()
    template_of_sect_of_spec=template_of_sect_of_subfile["{PACKAGE_TARNAME}-{PACKAGE_VERSION}-{opt_d.Build}.spec"]=OrderedDict()

    template_of_sect_of_spec["head"]="""\
Name: {confdefs[PACKAGE_TARNAME]}
### {sec_name} ###
%define PACKAGE {confdefs[PACKAGE_TARNAME]}
%define package_alias {opt_d.package_alias}
Version: {opt_d.PACKAGE_VERSION}

%{lc}lua:
    function trunc(str, len)
        return 0+string.sub(str..'', 1, #(str..'')-len)
    end
{rc}

# It turns out the in suse15 lua functions struggle to return non-strings, eg. bool, float and int
# ... there are even problems with special chars in strings, eg. hypen ...
# ...solution... use "pc_YES" macro everywhere...

# pre a68g-3.1.9 was: # actually for fedroa>= ? and rhel>=9
%if 0%{lc}?fedora{rc} || 0%{lc}?rhel{rc}
# error: bare words are no longer supported, please use "...":
    %define GTorEQ()  %{lc}expand:%%{lc}lua:if %1+0 >= %2+0 then print('"YeS"') else print('"OtHeR"') end {rc}{rc}
    %define YES "YeS"
%else
    %define GTorEQ()  %{lc}expand:%%{lc}lua:if %1+0 >= %2+0 then print("YeS") else print("OtHeR") end {rc}{rc}
    %define YES YeS
%endif

%define trunc() %{lc}expand:%%{lc}lua:print(trunc(%1, %2)){rc}{rc}
%define _localedir %_datadir/locale
%define _gamesdir %_datadir/locale

%{lc}?sle_version: %global platform_name sle
%global platform_version %{lc}trunc %{lc}?sle_version{rc} 4 {rc} {rc}

%{lc}?suse_version: %global platform_name suse
%global platform_version %{lc}trunc %{lc}?suse_version{rc} 2 {rc} {rc}

%{lc}?centos: %global platform_name centos
%global platform_version %{lc}trunc %{lc}?centos{rc} 2 {rc} {rc}

%{lc}?oracle_version: %global platform_name oracle
%global platform_version %{lc}?oracle_version{rc} {rc}

%{lc}?scientificlinux_version: %global platform_name scientificlinux
%global platform_version %{lc}trunc %{lc}?scientificlinux_version{rc} 2 {rc} {rc}

%{lc}?rhel: %global platform_name rhel
%global platform_version %{lc}?rhel{rc} {rc}

%{lc}?fedora: %global platform_name fedora
%global platform_version %{lc}?fedora{rc} {rc}

%{lc}?mdkversion: %global platform_name mdk
%global platform_version %{lc}?mdkversion{rc} {rc}

%{lc}?arch_linux: %global platform_name arch_linux
%global platform_version %{lc}?arch_linux{rc} {rc}

%{lc}?debian: %global platform_name debian
%global platform_version %{lc}?debian{rc} {rc}

%{lc}?amzn: %global platform_name amzn
%global platform_version %{lc}?amzn{rc} {rc}

%{lc}!?platform_name: %global platform_name linux
%global platform_version 0 {rc}

%define _platform_name _%platform_name
%define os_id %(. /etc/os-release; echo "$ID")
%define os_version_long %(. /etc/os-release; echo "$ID""$VERSION_ID")

# Note: Months start as per: Jan=001 Feb=051 Mar=101 ... Sep=701 Oct=801 Nov=901 Dec=951 per Latin: septem, ôctō, novem, decem
%define Build {opt_d.Build}

# Epoch: {opt_d.Epoch}
Release: %{lc}Build{rc}_%{lc}os_version_long{rc}

Summary: {opt_d.Summary}
Group: {opt_d.Group}
License: {opt_d.License}
URL: {opt_d.DOCUMENTATION_PAGE}

# NB: bcond_without MEANS a default of WITH
# NB: bcond_with MEANS a default of WITHOUT!

# Here's how it's explained in /usr/lib/rpm/macros ...
# Handle conditional builds. PC_bcond_with is for case when feature is
# default off and needs to be activated with --with ... command line
# switch. PC_bcond_without is for the dual case.
#
# PC_bcond_with foo defines symbol with_foo if --with foo was specified on
# command line.
# PC_bcond_without foo defines symbol with_foo if --without foo was *not*
# specified on command line.

%define default_without() %{lc}expand:%%{lc}?_with_%{lc}1{rc}:%%global with_%{lc}1{rc} 1{rc}{rc}
%define default_with()    %{lc}expand:%%{lc}!?_without_%{lc}1{rc}:%%global with_%{lc}1{rc} 1{rc}{rc}

# issue: `with_long-types` is not a valid m4 vaiable name, so hypens in option names will be ignored
%define default_enable()  %{lc}expand:
    %%{lc}!?_without_%{lc}1{rc}:
        %%global with_%{lc}1{rc} 1
        %%global opt_%{lc}1{rc} --enable-%1
    {rc}
{rc}

%define default_disable() %{lc}expand:
    %%{lc}?_with_%{lc}1{rc}:
        %%global with_%{lc}1{rc} 1
        %%global opt_%{lc}1{rc} --disable-%1
    {rc}
{rc}

# subpkg options
%default_with tiny      # minimise what gets installed, avoiding errors on missing optional pkgs
%default_without full   # try and install every pkg to get a "full" implentation

%default_without remix  # force a remix .RPM to be build
%default_without native # create remix pkg "as is", i.e. as per autotools on existing pkgs

%default_without check  # run `__make check` with std test suite

# merge_extra_tools to help with cross-platform building publication ...
%default_with    release

# build options
%default_with quiet
%default_with keep_scripts

# various constants
%define __attr_r 0644
%define __attr_x 0755

# prefer uid&gid=GNU
%define PkgUID root
%define PkgGID root

# useful macros
%define prelude(o:s:n:)  %{lc}?with_keep_scripts:ln -f "$0" `dirname "$0"`/rpmbuild-$USER-%-o*-%-s*-%-n*.sh{rc}

%define hdr_gcc_devel gcc

%global actual() %{lc}expand:%%{lc}?%{lc}1{rc}_%2:%%%{lc}1{rc}_%2{rc}%%{lc}!?%{lc}1{rc}_%2:%1-%2{rc}{rc}
%global hdr_actual() %{lc}expand:%%{lc}?hdr_%{lc}1{rc}_%2:%%hdr_%{lc}1{rc}_%2{rc}%%{lc}!?hdr_%{lc}1{rc}_%2:%1-%2{rc}{rc}
%global lib_actual() %{lc}expand:%%{lc}?lib_%{lc}1{rc}_%2:%%lib_%{lc}1{rc}_%2{rc}%%{lc}!?lib_%{lc}1{rc}_%2:%1-%2{rc}{rc}
%global bin_actual() %{lc}expand:%%{lc}?bin_%{lc}1{rc}_%2:%%bin_%{lc}1{rc}_%2{rc}%%{lc}!?bin_%{lc}1{rc}_%2:%1-%2{rc}{rc}

%if ( "%platform_name" == "rhel"   && %{lc}GTorEQ %platform_version  8{rc} == %YES ) || \
    ( "%platform_name" == "fedora" && %{lc}GTorEQ %platform_version 34{rc} == %YES )
#then
    %{lc}echo:Targeting platform: %platform_name-%platform_version{rc}
    %global lib() %1%{lc}?isa{rc}
%else
    %{lc}echo:Targeting platform: %platform_name-%platform_version{rc}
    %global lib() %1-devel%{lc}?isa{rc}
%endif

%global hdr() %{lc}hdr_actual %1 devel{rc}
%global bin() %1

%if ( "%platform_name" == "suse" && %{lc}GTorEQ %platform_version 15{rc} == %YES )
    %define C_COMPILER gcc7
    %define hdr_gcc7_devel gcc7
%else
    %define C_COMPILER gcc
%endif

%define configure_cross_build_opts %{lc}?_host:--host=%_host{rc} %{lc}?_build:--build=%_build{rc} %{lc}?_target:--target=%_target{rc}
"""

    template_of_sect_of_spec["head/opt"]="""\
%default_disable {opt}
"""
    template_of_sect_of_spec["head/source"]="""\
### {sec_name}/{enum} ###
Source{enum}: {source}
"""

    template_of_sect_of_spec["head/extra"]="""\
### {sec_name}/{enum} ###
Source{enum}: {merge_extra_tools}
"""

    template_of_sect_of_spec["head/patch"]="""\
### {sec_name}/{enum} ### nb. These can also be done via "pc_patch:" in %pc_prep
Patch{enum}: {confdefs[PACKAGE_TARNAME]}-{opt_d.PACKAGE_VERSION}-{patch}.patch
"""

    template_of_sect_of_spec["head_description"]="""\
%description -n %PACKAGE

{read[README]}

RHEL9.2 full example:
* BuildRequires: dnf install libquadmath-devel gmp-devel mpfr-devel libRmath-devel plotutils-devel ncurses-devel libpq-devel readline-devel gsl-devel
* RunRequires: dnf install a68g-full # implies: gsl libRmath libXaw libpq plotutils

Ubuntu22 full requires:
* apt install libgmp-dev libmpfr-dev r-mathlib libplot-dev libncurses-dev libpq-dev libreadline-dev libgsl-dev
"""

    template_of_sect_of_spec["head_rebuild_RPM/subpkg"]="""
# {SUBPACKAGE} by package name...
# RPM {SUBPACKAGE} BuildRequires: rpm -evh {dep_of_this_subpkg[BuildRequiresPkg]} """

    template_of_sect_of_spec["head_rebuild_YUM/subpkg"]="""
# {SUBPACKAGE} by capability...
# YUM {SUBPACKAGE} BuildRequires: yum install {dep_of_this_subpkg[YUM_BuildRequiresCap]} """

    template_of_sect_of_spec["head/subpkg"]="""

### {sec_name}/{SUBPACKAGE}  ###
%define {SUBPACKAGE}_configure_opt_l {configure_opt_l}
"""

    if opt_d.verbose_requires: template_of_sect_of_spec["head_verbose/subreq"]="""\
### {sec_name}/{dep_d[lib_name]} [complex] ###
## {dep_d[lib_desc]} => {dep_d[lib_name]} ##
%define {dep_d[mac_name]}_bld_req_bin     {dep_d[bld_req_bin]}
%define {dep_d[mac_name]}_bld_req_hdr     {dep_d[bld_req_hdr]}
%define {dep_d[mac_name]}_bld_req_lib     {dep_d[bld_req_lib]}

%define {dep_d[mac_name]}_bld_req_bhl_pkg {dep_d[BuildRequiresPkg]}
%define {dep_d[mac_name]}_bld_req_bin_pkg {dep_d[bld_req_bin_pkg]}
%define {dep_d[mac_name]}_bld_req_hdr_pkg {dep_d[bld_req_hdr_pkg]}
%define {dep_d[mac_name]}_bld_req_lib_pkg {dep_d[bld_req_lib_pkg]}

%define {dep_d[mac_name]}_BuildRequiresCap {dep_d[BuildRequiresCap]}
%define {dep_d[mac_name]}_YUM_BuildRequiresCap {dep_d[YUM_BuildRequiresCap]}
%define {dep_d[mac_name]}_bld_req_bin_cap {dep_d[bld_req_bin_cap]}
%define {dep_d[mac_name]}_bld_req_hdr_cap {dep_d[bld_req_hdr_cap]}
%define {dep_d[mac_name]}_bld_req_lib_cap {dep_d[bld_req_lib_cap]}

%define {dep_d[mac_name]}_run_req_bin     {dep_d[run_req_bin]}
%define {dep_d[mac_name]}_run_req_lib     {dep_d[run_req_lib]}
%define {dep_d[mac_name]}_run_req_bl      {dep_d[run_req_bl]}

%define {dep_d[mac_name]}_RunRequiresPkg  {dep_d[RunRequiresPkg]}
%define {dep_d[mac_name]}_run_req_bin_pkg {dep_d[run_req_bin_pkg]}
%define {dep_d[mac_name]}_run_req_lib_pkg {dep_d[run_req_lib_pkg]}

%define {dep_d[mac_name]}_RunRequiresCap  {dep_d[RunRequiresCap]}
%define {dep_d[mac_name]}_StaticRunRequiresCap {dep_d[StaticRunRequiresCap]}
%define {dep_d[mac_name]}_run_req_lib_cap {dep_d[run_req_lib_cap]}

%define {dep_d[mac_name]}_ProvidesCap        {dep_d[ProvidesCap]}

"""
    if True or opt_d.verbose_requires: template_of_sect_of_spec["head/subreq"]="""\
### {sec_name}/{dep_d[lib_name]} [simple] ###
## {dep_d[lib_desc]} => {dep_d[lib_name]} ##
%define {dep_d[mac_name]}_BuildRequiresCap {dep_d[BuildRequiresCap]}
%define {dep_d[mac_name]}_RunRequiresPkg   {dep_d[RunRequiresPkg]}
%define {dep_d[mac_name]}_RunRequiresCap   {dep_d[RunRequiresCap]}
%define {dep_d[mac_name]}_ProvidesCap      {dep_d[ProvidesCap]}

"""

    template_of_sect_of_spec["head_set_dirs"]="""\
### {sec_name} ###
#define _pkgdocdir #_defaultdocdir/XPACKAGE
%define configure_macro_builtins --bindir=%_bindir --sbindir=%_sbindir --includedir=%_includedir \
    --oldincludedir=%_oldincludedir --libdir=%_libdir --libexecdir=%_libexecdir --localstatedir=%_localstatedir \
    --datarootdir=%_datarootdir --datadir=%_datadir --sysconfdir=%_sysconfdir --mandir=%_mandir \
    --infodir=%_infodir
%define make_install_dirs bindir=%_bindir datadir=%_datadir datarootdir=%_datarootdir \
    defaultdocdir=%_defaultdocdir exec_prefix=%_exec_prefix includedir=%_includedir infodir=%_infodir \
    initddir=%_initddir libdir=%_libdir libexecdir=%_libexecdir lib=%_lib localstatedir=%_localstatedir \
    mandir=%_mandir oldincludedir=%_oldincludedir prefix=%_prefix rundir=%_rundir sbindir=%_sbindir \
    sharedstatedir=%_sharedstatedir sysconfdir=%_sysconfdir
"""

#BuildRequires: {dep_of_subpkg[BuildRequiresPkg]}
#Requires: {dep_of_subpkg[RunRequiresPkg]}

    template_of_sect_of_spec["head_package/subpkg"]="""\
### {sec_name}/{SUBPACKAGE}  ###
%if %{lc}with {SUBPACKAGE}{rc}

%package -n %PACKAGE-{SUBPACKAGE}
## build/subpkg PACKAGE-{SUBPACKAGE} ##
Summary: {opt_d.Summary} [{SUBPACKAGE}]
BuildRequires: {dep_of_this_subpkg[BuildRequiresCap]}
%if %{lc}with static{rc}
# esp statically pre-loaded libs
Requires:      {dep_of_this_subpkg[StaticRunRequiresCap]}
%else
# esp dynamically loaded libs
Requires:      {dep_of_this_subpkg[RunRequiresCap]}
%endif

# ToDo later: nest/test these tools, add/check autoheader/autoscan
%{lc}?with_autoupdate:BuildRequires: autoupdate{rc}
%{lc}?with_autoscan:BuildRequires: autoscan{rc}
%{lc}?with_autoheader:BuildRequires: autoheader{rc}
%{lc}?with_aclocal:BuildRequires:  aclocal{rc}
%{lc}?with_autoconf:BuildRequires: autoconf{rc}
%{lc}?with_automake:BuildRequires: automake{rc}

# ToDo: http://wiki.rosalab.ru/en/index.php/RPM_spec_file_syntax#Requires.2C_Obsoletes.2C_Provides.2C_Conflicts.2C_etc.
#Requires(pre):  foo
#Requires(postun): foo
#Conflicts:      tripwire
#Obsoletes:      bar

Provides: %PACKAGE %PACKAGE-{SUBPACKAGE} %package_alias %package_alias-{SUBPACKAGE} {dep_of_this_subpkg[ProvidesCap]}
%description -n %PACKAGE-{SUBPACKAGE}

{SUBPACKAGE} resources for %PACKAGE

Configure options: %{SUBPACKAGE}_configure_opt_l
%endif

"""
    template_of_sect_of_spec["prep"]="""\
### {sec_name} ###
%prep
%{lc}prelude -o 1 -s PREP_BUILD -n %PACKAGE{rc}

### {sec_name} ###
# Wanted: pc_autosetup -p1 # cf. rpmdev-newspec
# But: https://stackoverflow.com/questions/40714213/why-does-autosetup-perform-patching-before-extracting-sources

%setup -q

# re: patch ... http://ftp.rpm.org/max-rpm/s1-rpm-specref-macros.html#S2-RPM-SPECREF-PATCH-MACRO
"""

    template_of_sect_of_spec["prep/patch"]="""\
### {sec_name}/{enum} ### nb. not needed with pc_autosetup -p1
%patch{enum} -p1

"""

    template_of_sect_of_spec["prep_build"]="""\
### {sec_name} ###
%build # all
%{lc}prelude -o 2 -s BUILD_ALL -n %PACKAGE{rc}

# try: set_build_flags  # cf. /usr/lib/rpm/redhat/macros
%{lc}?set_build_flags{rc}

CFLAGS="{opt_d.CFLAGS} $CFLAGS"; export CFLAGS
CXXFLAGS="{opt_d.CXXFLAGS} $CXXFLAGS" ; export CXXFLAGS
FFLAGS="{opt_d.FFLAGS} $FFLAGS" ; export FFLAGS
FCFLAGS="{opt_d.FCFLAGS} $FCFLAGS" ; export FCFLAGS
LDFLAGS="{opt_d.LDFLAGS} $LDFLAGS" ; export LDFLAGS

# see results in first section
%{lc}!?with_quiet:echo "_arch=%_arch" "_isa=%_isa"{rc}
%{lc}!?with_quiet:echo "_host=%_host" "_build=%_build" "_target=%_target" "_host_cpu=%_host_cpu" "_target_os=%_target_os"{rc}
%{lc}!?with_quiet:echo "_host_platform=%_host_platform" "_build_platform=%_build_platform" "_target_platform=%_target_platform"{rc}
%{lc}!?with_quiet:echo "configure_cross_build_opts=%configure_cross_build_opts";{rc}
%{lc}!?with_quiet:echo Note: CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" FFLAGS="$FFLAGS" FCFLAGS="$FCFLAGS" LDFLAGS="$LDFLAGS"{rc}

avoid_automake_install={opt_d.avoid_automake_install}
"""

    template_of_sect_of_spec["build_sh_var/subpkg"]="""\
with_{SUBPACKAGE}=%{lc}with {SUBPACKAGE}{rc}
"""

    template_of_sect_of_spec["build_sh_var/extra"]="""\
with_{name}=%{lc}with {name}{rc} # {merge_extra_tools}
"""

    template_of_sect_of_spec["build/subpkg"]="""\
### {sec_name}/{SUBPACKAGE} ###

if [ $with_{SUBPACKAGE} == 1 ]; then

    # the following line may trigger a rerun of aclocal... problematic, cannot use `make -B` below instead
    test -r Makefile && %__make mostlyclean-compile || true # remove residual Makefile+objects between sub-package builds

    # Preeliminary use of autoscan .. autoconf, autoupdate not included #
    %{lc}?with_autoconf: %{lc}?with_automake: %{lc}?with_autoheader: %{lc}?with_aclocal: %{lc}?with_autoscan:
    autoscan && {rc} aclocal && {rc} autoheader && {rc} automake && {rc} autoconf configure.ac > configure && {rc}
    if [ -n "$avoid_automake_install" ]; then touch -r aclocal.m4 configure.ac; else true; fi &&
    {lc} %configure %configure_macro_builtins %configure_cross_build_opts %{SUBPACKAGE}_configure_opt_l; {rc} &&
    %make_build %{lc}?_smp_mflags{rc} ACFLAGS="$RPM_OPT_FLAGS" CFLAGS="$CFLAGS" CXXFLAGS="$CXXFLAGS" FFLAGS="$FFLAGS" FCFLAGS="$FCFLAGS" LDFLAGS="$LDFLAGS" && # %make_install_dirs
    %if "%{lc}?package_alias{rc}" != ""
        cp -p %package_alias %package_alias-{SUBPACKAGE}
        %if !%{lc}with quiet{rc}
            ls -ltr "%package_alias"*
            ./%package_alias-{SUBPACKAGE} -V
        %endif
    %endif
fi
"""
# the simpler make, suitable for running shell scripts for prop/build/clean
    template_of_sect_of_spec["merge_extra_tools"]="""\
tarball_build_configure_make(){lc}
  if mkdir -p "$1" && cd "$1"; then
    %configure $configure_dirs "$@" &&
    %{lc}make_build%{rc} %{lc}?make_flags{rc} %{lc}?_smp_mflags{rc} CFLAGS="$RPM_OPT_FLAGS"
  else
    %__error "tarball_build_configure_make cannot chdir '$1'"
  fi
{rc}
"""

    template_of_sect_of_spec["build/extra"]="""\
### {sec_name}/{merge_extra_tools} ###
if [ $with_{name} == 1 ]; then
    tarball_build_configure_make {name}-{version} %*
fi
"""

    template_of_sect_of_spec["install"]="""\
%install
### {sec_name} ###
%{lc}prelude -o 3 -s INSTALL -n %PACKAGE{rc}

"""

    template_of_sect_of_spec["install_sh_var/subpkg"]="""\
with_{SUBPACKAGE}=%{lc}with {SUBPACKAGE}{rc}
"""

    template_of_sect_of_spec["install/subpkg"]="""\
### {sec_name}/{SUBPACKAGE} ###
if [ $with_{SUBPACKAGE} == 1 ]; then
    #if #{lc}with {SUBPACKAGE}{rc}
    echo ECHO %make_install %make_install_dirs
    %make_install %make_install_dirs
    %__install --mode %__attr_x %package_alias-{SUBPACKAGE} $RPM_BUILD_ROOT%_bindir/%package_alias-{SUBPACKAGE}
    echo macro: RPM_BUILD_ROOT="$RPM_BUILD_ROOT"
    echo macro: _buildrootdir="%_buildrootdir"
    echo macro: _builddir="%_builddir"
    echo macro: _prefix="%_prefix"
    echo macro: _usr="%_usr"
    echo macro: _bindir="%_bindir"
    echo macro: _datarootdir="%_datarootdir"
    echo macro: _oldincludedir="%_oldincludedir"
    echo macro: _includedir="%_includedir"
    echo macro: _mandir="%_mandir"
    echo macro: _pkgdocdir="%_pkgdocdir"
    echo macro: _defaultdocdir="%_defaultdocdir"
    echo macro: _defaultlicensedir="%_defaultlicensedir"
    ( cd $RPM_BUILD_ROOT &&
        echo Installed files: &&
        find * -type f | sed 's?/[^/]*$?/*?' | sort -u
    )
    #endif
fi

"""

    def add_each_dir():
        file_d=dict(
            bin=["\n%defattr(%__attr_x,%PkgUID,%PkgGID,%__attr_x)"],
            doc=["\n%defattr(%__attr_r,%PkgUID,%PkgGID,%__attr_x)"],
            other=["\n%defattr(%__attr_r,%PkgUID,%PkgGID,%__attr_x)"],
            # dir=[],     # %dir to explicitly include directories, particularly empty ones
            # config=[],  # %config(noreplace) /etc/myapp.conf # prevent RPM replacing if altered by the user.
            # attr=[],    # %attr(640, root, root) /etc/securefile
            # ghost=[],   # %ghost /var/log/myapp/logfile.log # not included in the package payload, but managed
            # license=[], # %license /usr/share/licenses/myapp/LICENSE
            # verify=[],  # %verify(not md5 size mtime) /var/run/myapp.pid # not to check
            # lang=[],    # %lang(fr) /usr/share/locale/fr/LC_MESSAGES/myapp.mo
            # libexecdir=[], # to store executable for main programs, but not executed directly by users
            # %exclude=[],   # Excludes files from being packaged,
            # %missingok=[], # Indicates that it is acceptable if the file does not exist.
            # %docdir=[],    # Similar to %doc but used to specify an entire directory.
        )

        for dir_name in fedora39_build_dir_name:
            file_l=opt_d.__getattribute__(dir_name)
            if file_l:
                if "bin" in dir_name or "exec" in dir_name or dir_name in ["initddir","initrddir"]:
                    file_d["bin"]+=["%_"+dir_name+"/"+file for file in file_l if file and file != "None"]
                elif "pkgdocdir" == dir_name:
                    file_d["doc"]+=["%doc "+file for file in file_l if file and file != "None"]
                # elif "localedir" == dir_name:
                # ToDo ... # %lang(fr) /usr/share/locale/fr/LC_MESSAGES/myapp.mo
                else:
                    file_d["other"]+=["%_"+dir_name+"/"+file for file in file_l if file and file != "None"]
        return "\n".join(file for file_l in file_d.values() if len(file_l)> 1 for file in file_l)

    """

    """
    '''template_of_sect_of_spec["files/subpkg"]="""\
### {sec_name}/{SUBPACKAGE}  ###
%if %{lc}with {SUBPACKAGE}{rc}

%files -n %PACKAGE-{SUBPACKAGE}
"""+add_each_dir()+"""

# add-license-file-here
# pre a68g-3.1.9 was: #license LICENSE
# license COPYING
%endif

"""'''

    template_of_sect_of_spec["files"]="""\
### {sec_name}  ###
%files
"""+add_each_dir()
    
    template_of_sect_of_spec["clean"]="""
%clean
%{lc}prelude -o 4 -s CLEAN -n %PACKAGE{rc}
rm -rf $RPM_BUILD_ROOT

"""
    template_of_sect_of_spec["changelog"]="""\

%changelog
* {opt_d.RPMPackDate} {opt_d.Packager} - {opt_d.PACKAGE_VERSION}-{opt_d.Build}
- {confdefs[PACKAGE_STRING]}-{opt_d.Build}.spec - release with newest {confdefs[PACKAGE_NAME]} version:
1. for: rhel_8, fedora_35, suse_15, awsl_2, debian11, raspberryos11, ubuntu etc.
2. on: aarch64, s390x, i686, x86_64 etc.
{read[NEWS/changelog]}

"""

    template_of_sect_of_spec["check"]="""\
%check
### {sec_name} ###
%if %{lc}with check{rc}
%__make check
%else
echo Check disabled
%endif
"""

    template_of_sect_of_spec["verifyscript"]="""\
%verifyscript
echo verifyscript
"""

# http://fedoraproject.org/wiki/Packaging:ScriptletSnippets#Scriptlet_Ordering
    template_of_sect_of_spec["lua"]="""\
--- {sec_name} ---
%pretrans -p <lua>
-------- 8>< - - - - - - - - love that lua - - - - - - - -
print("Scriptlet: %pretrans of new package")

%pre -p <lua>
print("Scriptlet: %pre of new package")
print("Action: package install")

%post -p <lua>
print("Scriptlet: %post of new package")

%triggerin -p <lua> -- pkg_other
print("Scriptlet: %triggerin of other packages (set off by installing new package)")

%triggerin -p <lua> -- pkg_new
print("Scriptlet: %triggerin of new package (if any are true)")

%triggerun -p <lua> -- pkg_old
print("Scriptlet: %triggerun of old package (if it's set off by uninstalling the old package)")

%triggerun -p <lua> -- pkg_other
print("Scriptlet: %triggerun of other packages (set off by uninstalling old package)")

%preun -p <lua>
print("Scriptlet: %preun of old package")
print("Action: removal of old package")

%postun -p <lua>
print("Scriptlet: %postun of old package")

%triggerpostun -p <lua> -- pkg_old
print("Scriptlet: %triggerpostun of old package (if it's set off by uninstalling the old package)")

%posttrans -p <lua>
print("Scriptlet: %posttrans of new package ")
"""
    return template_of_sect_of_subfile

def print_autoconf_template(template_of_sect_of_subfile, req_d_of_subpkg_opt, configure_opt_l_of_sub_package_d=None):
    dep_summary_of_lib_l_of_subpkg=OrderedDict()
    dep_summary_of_lib_l_of_subpkg["full"]=[]

# Gather all the libraries for each required sub-package...
    for subpkg_name, subpkg_opt_d in req_d_of_subpkg_opt.items():
        this_dep_summary_of_lib_l=list(gen_dep_summary_of_lib_l(subpkg_opt_d[opt_d.core_tests]))
        for dep_d in this_dep_summary_of_lib_l:
            lib_name=dep_d["lib_name"]
            mac_name=dep_d["mac_name"]
            if subpkg_name not in dep_summary_of_lib_l_of_subpkg: dep_summary_of_lib_l_of_subpkg[subpkg_name]=[]
            for this_subpkg in subpkg_name,"full":
                if dep_d not in dep_summary_of_lib_l_of_subpkg[this_subpkg]:
                    dep_summary_of_lib_l=OrderedDict()
                    dep_summary_of_lib_l.update(dep_d)
                    if dep_summary_of_lib_l not in dep_summary_of_lib_l_of_subpkg[this_subpkg]:
                        dep_summary_of_lib_l_of_subpkg[this_subpkg].append(dep_summary_of_lib_l)

    re_colon_etc=re.compile(":.*")
# for each sub_package... Convert to a macro all dependances
    dep_of_subpkg=OrderedDict()
    for subpkg_name, dep_summary_of_lib_l in dep_summary_of_lib_l_of_subpkg.items():
        dep_d_of_subpkg={}
        dep_of_subpkg[subpkg_name]=dep_d_of_subpkg
        for dep_summary in dep_summary_of_lib_l:
            for run_req_key, run_req_l in dep_summary.items():
                out_l = PrintableList() if run_req_key not in dep_d_of_subpkg else dep_d_of_subpkg[run_req_key]
                if run_req_key.startswith("RPM_") or run_req_key.startswith("YUM_") or run_req_key.startswith("DPKG_"):
                    for req in run_req_l:
                        req=re_colon_etc.sub("",req) # truncate from colon... of 'libquadmath0:amd64'
                        if req not in out_l: out_l.append(req)
                else: # canonise with a macro
                    out_l.append("%"+dep_summary["mac_name"]+"_"+run_req_key)
                dep_d_of_subpkg[run_req_key]=out_l

# cf. http://ftp.rpm.org/max-rpm/s1-rpm-inside-scripts.html#S2-RPM-INSIDE-BUILD-TIME-SCRIPTS

    re_extra=re.compile(r"^(?P<name>[a-z][-_a-z0-9+]*)-(?P<version>[0-9][-_.0-9]*)(?P<ext>([.][a-z]*){1,2})", re.IGNORECASE)
    macro_d=dict( lc="{", rc="}" )

    confdefs=OrderedDict( ( ( cdh["name"],(cdh["value"] if cdh["desc"] in ["str","code"] else cdh["value"]) )
            for cdh in subpkg_opt_d['confdefs.h.']['paragraph_0'] if "value" in cdh ) )

    if opt_d.PACKAGE_VERSION is not None:
        print("opt_d.PACKAGE_VERSION:",opt_d.PACKAGE_VERSION)
        confdefs["PACKAGE_VERSION"]=opt_d.PACKAGE_VERSION

    for subfile_name,template_of_sect in template_of_sect_of_subfile.items():
        # with open(confdefs["PACKAGE_TARNAME"]+"-"+confdefs["PACKAGE_VERSION"]+".spec","w") as bld_subfile:
        file_name=os.path.join(opt_d.build_staging_dir,subfile_name.format(opt_d=opt_d,**confdefs))
        dir_name=os.path.dirname(file_name)
        if not os.path.isdir(dir_name): os.makedirs(dir_name)
        if opt_d.verbose: print("Writing:", file_name, "...")
        with open(file_name,"w") as bld_subfile:

            sec_prev=""
            for sec_name,sec_template in template_of_sect.items():
                if not sec_name.startswith("cont_"): # continue from previous line, no title or newline
                    title="## Section: "+sec_name+ " ##"
                    if opt_d.insert_headings and "lua" not in sec_prev: bld_subfile.write("\n".join(["","","#"*len(title),title,"#"*len(title),""]))
                sec_prev=sec_name
                if sec_name.endswith("/subreq"):
                    for dep_d in this_dep_summary_of_lib_l:
                        bld_subfile.write(sec_template.format(
                            confdefs=confdefs, sec_name=sec_name,
                            opt_d=opt_d, dep_d=dep_d, read=rf_d, **macro_d)
                        )
                elif sec_name.endswith("/subpkg"):
                    for sub_package, configure_opt_l in configure_opt_l_of_sub_package_d.items():
                        try:
                            dep_of_this_subpkg=dep_of_subpkg[sub_package]
                        except KeyError as error:
                            dep_of_this_subpkg=dep_of_subpkg["full"]

                        bld_subfile.write(sec_template.format(
                            confdefs=confdefs, sec_name=sec_name,
                            configure_opt_l=configure_opt_l,
                            SUBPACKAGE=sub_package,
                            dep_of_this_subpkg=dep_of_this_subpkg,
                            opt_d=opt_d, read=rf_d, **macro_d)
                            # opt_d=opt_d, dep_d=dep_d, read=rf_d, **macro_d)
                        )
                elif sec_name.endswith("/source"):
                    for enum, source in enumerate(opt_d.Source_l):
                        bld_subfile.write(sec_template.format(
                            confdefs=confdefs, sec_name=sec_name,
                            enum=enum, source=source,
                            opt_d=opt_d, read=rf_d, **macro_d)
                        )
                elif sec_name.endswith("/extra"):
                    for enum, merge_extra_tools in enumerate(opt_d.merge_extra_tool_l):
                        extra_d=re_extra.match(merge_extra_tools).groupdict()
                        bld_subfile.write(sec_template.format(
                            confdefs=confdefs, sec_name=sec_name,
                            enum=enum+len(opt_d.Source_l),
                            merge_extra_tools=merge_extra_tools,
                            name=extra_d["name"], version=extra_d["version"], ext=extra_d["ext"],
                            opt_d=opt_d, **macro_d)
                        )
                elif sec_name.endswith("/patch"):
                    for enum, patch in enumerate(opt_d.Patch_l):
                        bld_subfile.write(sec_template.format(
                            confdefs=confdefs, sec_name=sec_name,
                            enum=enum, patch=patch,
                            opt_d=opt_d, read=rf_d, **macro_d)
                        )
                elif sec_name.endswith("/opt"):
                    # opt_l=opt_d.enable_core + opt_d.enable_full
                    opt_l=opt_d.enable_full
                    for enum, opt in enumerate(opt_l):
                        bld_subfile.write(sec_template.format(
                            confdefs=confdefs, sec_name=sec_name,
                            enum=enum, opt=opt,
                            opt_d=opt_d, read=rf_d, **macro_d)
                        )
                else:
                    bld_subfile.write(sec_template.format(
                        confdefs=confdefs, sec_name=sec_name,
                        opt_d=opt_d, read=rf_d, **macro_d)
                    )
                # end for sec_name,sec_template
            # end with open(file_name,"w") as bld_subfile
        # end for subfile_name,template_of_sect
    return

def get_run_req_full_lib(Core_tests_d):
    # print_config_log(chapter_d)
    #autoconf_rpmspec(chapter_d)
    # Core_tests=chapter_d["Core tests."]
    run_req_full_libraries_d=OrderedDict()
    for name, paragraph_d in Core_tests_d.items():
        # paragraph_d=Core_tests["GNU MPFR"]
        # pprint.pprint(paragraph_d)
        req_d=dict(hdr=set(),lib=set(),function=set())
        run_req_full_libraries_d[name]=req_d
        for sentence_d in paragraph_d:
            for key in req_d.keys():
                if "result" in sentence_d and sentence_d["result"] in ok_l and key in sentence_d:
                    req_d[key].add(sentence_d[key])
            #print(sentence_d)
            #print(req_d)
    return run_req_full_libraries_d

# echo | gcc -E -Wp,-v - 2>&1
hdr_raw="""
ignoring nonexistent directory "/usr/lib/gcc/x86_64-redhat-linux/8/include-fixed"
ignoring nonexistent directory "/usr/lib/gcc/x86_64-redhat-linux/8/../../../../x86_64-redhat-linux/include"
#include "..." search starts here:
#include <...> search starts here:
 /usr/lib/gcc/x86_64-redhat-linux/8/include
 /usr/local/include
 /usr/include
End of search list.
# 1 "<stdin>"
# 1 "<built-in>"
# 1 "<command-line>"
# 31 "<command-line>"
# 1 "/usr/include/stdc-predef.h" 1 3 4
# 32 "<command-line>" 2
"""
re_hdr_dir=re.compile("\n (/[^\n]*)")
#hdr_path_l=re_hdr_dir.split(hdr_raw)[1::2]
hdr_path_l=None

len_pipe_buf=None

def get_hdr_path_l():
    global hdr_path_l
    if hdr_path_l is None:
        with os.popen("echo | {opt_d.CC} -E -Wp,-v {opt_d.CFLAGS} - 2>&1".format(opt_d=opt_d),"r") as gcc_out:
            hdr_path_l="".join(gcc_out)
            hdr_path_l=re_hdr_dir.split(hdr_path_l)[1::2]
    return hdr_path_l

def find_hdr(hdr_s, find_pkg=None):
    hdr_l=PrintableList()
    for hdr in hdr_s:
        for hdr_dir in get_hdr_path_l():
            full=os.path.join(hdr_dir,hdr)
            if os.path.exists(full) and ( find_pkg is None or find_pkg(full) ):
                hdr_l.append(full)
                break
        else:
            if not opt_d.ignore_missing:
                hdr_l.append(hdr+"?!")
    hdr_l.sort()
    return hdr_l

# ld --verbose | grep SEARCH_DIR | tr -s ' ;' \\012
rhel_lib_raw="""
SEARCH_DIR("=/usr/x86_64-redhat-linux/lib64");
SEARCH_DIR("=/usr/lib64");
SEARCH_DIR("=/usr/local/lib64");
SEARCH_DIR("=/lib64");
SEARCH_DIR("=/usr/x86_64-redhat-linux/lib");
SEARCH_DIR("=/usr/local/lib");
SEARCH_DIR("=/lib");
SEARCH_DIR("=/usr/lib");
"""
suse_lib_raw="""
SEARCH_DIR("/usr/x86_64-suse-linux/lib64");
SEARCH_DIR("/usr/lib64");
SEARCH_DIR("/usr/local/lib64");
SEARCH_DIR("/lib64");
SEARCH_DIR("/usr/x86_64-suse-linux/lib");
SEARCH_DIR("/usr/local/lib");
SEARCH_DIR("/lib");
SEARCH_DIR("/usr/lib")'
"""
re_split_search_dir=re.compile(r"""SEARCH_DIR\("={0,1}([^"]*)"\)""")
#lib_path_l=re_split_search_dir.split(lib_raw)[1::2]
lib_path_l=None

def get_lib_path_l():
    global lib_path_l
    if lib_path_l is None:
        # with os.popen(r"ld {opt_d.LDFLAGS} --verbose | grep SEARCH_DIR | tr -s ' ;' '\\012'".format(opt_d=opt_d),"r") as gcc_out:
        with os.popen(r"{opt_d.LD} {opt_d.LDFLAGS} --verbose | grep SEARCH_DIR".format(opt_d=opt_d),"r") as gcc_out:
            lib_path_l="".join(gcc_out)
            lib_path_l=re_split_search_dir.split(lib_path_l)[1::2]
    return lib_path_l

# dpkg: https://unix.stackexchange.com/questions/652798/debian-everything-in-usr-directory-scheme-usrmerge-breaks-dpkg-s-work-around?noredirect=1&lq=1
def find_lib(lib_s, find_pkg=None):
    so_l=opt_d.so_l # ".so .so.0 .so.1 .so.2 .so.3 .so.4 .so.5 .so.6 .so.7 .so.8 .so.9 .so.0.0 .so.0.0.0".split()
    lib_l=PrintableList()
    for lib in lib_s:
        for lib_dir,ext in product(get_lib_path_l(),so_l):
            full=os.path.join(lib_dir,"lib"+lib+ext)
            if os.path.exists(full) and ( find_pkg is None or find_pkg([full]) ):
                lib_l.append(full)
                # db/qqq: find_pkg([full])
                break
        else:
            if not opt_d.ignore_missing:
                lib_l.append(lib+"?!")
    lib_l.sort()
    return lib_l

def find_bin(bin_s, find_pkg=None):
    return PrintableList(bin_s) # just gcc until we figure out how to discover

#re_pkg=re.compile(r"^(?P<pkg>[a-z]+)-devel$",re.IGNORECASE) # .rpm only
re_pkg=re.compile(r"^(?P<pkg>[a-z][-a-z]*)-dev(el){0,1}$",re.IGNORECASE) # .rpm && .deb
#re_hdr=re.compile(r".*/(?P<hdr>[a-z]+)[.]h$",re.IGNORECASE)
re_hdr=re.compile(r".*/(?P<hdr>[a-z][-a-z]*)[.]h$",re.IGNORECASE) # eg. RHEL: /usr/include/libpq-fe.h

re_lib=re.compile(r".*/lib(?P<lib>[a-z][-a-z]*)[.]so.*$",re.IGNORECASE)

re_devel=re.compile(r"-devel$")
de_devel=""

def uniq(l):
    out_l=PrintableList()
    for e in l:
        if e not in out_l:
            out_l.append(e)
    out_l.sort()
    return out_l

def gen_dep_summary_of_lib_l(chapter_d, PACKAGE="algol68g"):
    # pprint.pprint(core_test_d)
    core_test_d=get_run_req_full_lib(chapter_d)
# {'hdr': {'mpfr.h'}, 'lib': {'gmp', 'mpfr'}, 'function': {'__gmpz_init', 'mpfr_gamma', 'mpfr_gamma_inc'}}
    for desc_full_lib, run_req_full_lib in core_test_d.items():
        if any( run_req_full_lib.values() ):
        # Requires: ?? "/usr/bin/autoconf",
            bld_req_bin=find_bin(set(["/usr/bin/gcc","/usr/bin/"+opt_d.package_builder])) # run_req_full_lib["bin"])
            bld_req_hdr=find_hdr(run_req_full_lib["hdr"])
# https://unix.stackexchange.com/questions/652798/debian-everything-in-usr-directory-scheme-usrmerge-breaks-dpkg-s-work-around
            bld_req_lib=find_lib(run_req_full_lib["lib"],
# it turns out that dpkg does not record hard-link pkg-owner in the .deb file
                find_pkg=find_pkg if opt_d.local_package_manager == local_package_manager_dpkg else None )
            bld_req_bhl= uniq(bld_req_bin + bld_req_hdr + bld_req_lib)

        # BuildRequires:
            #BuildRequiresPkg=find_pkg(bld_req_bhl)
            bld_req_bin_pkg=find_pkg(bld_req_bin)
            bld_req_hdr_pkg=find_pkg(bld_req_hdr)
            bld_req_lib_pkg=find_pkg(bld_req_lib)
            BuildRequiresPkg=uniq(bld_req_bin_pkg + bld_req_hdr_pkg + bld_req_lib_pkg)
            DPKG_BuildRequiresPkg=uniq(bld_req_bin_pkg + bld_req_hdr_pkg + bld_req_lib_pkg)

            #BuildRequiresCap=find_cap(BuildRequiresPkg, host_cpu="?")
            bld_req_bin_cap=find_cap(bld_req_bin_pkg, req="bin")
            bld_req_hdr_cap=find_cap(bld_req_hdr_pkg, req="hdr")
            bld_req_lib_cap=find_cap(bld_req_lib_pkg, req="lib", host_cpu="x86_64")
            BuildRequiresCap=uniq(bld_req_bin_cap + bld_req_hdr_cap + bld_req_lib_cap)
            YUM_BuildRequiresCap=find_cap(BuildRequiresPkg, req="yum")

            # run_req_bin=find_bin(set(["/usr/bin/bash"]))
            run_req_bin=find_bin(set(["/bin/bash"]))
            run_req_lib=bld_req_lib
            run_req_bl =run_req_bin + run_req_lib

            run_req_bin_pkg=find_pkg(run_req_bin)
            run_req_lib_pkg=bld_req_lib_pkg
            RunRequiresPkg =uniq(run_req_bin_pkg + run_req_lib_pkg)
            DPKG_RunRequiresPkg =uniq(run_req_bin_pkg + run_req_lib_pkg)

            run_req_bin_cap=find_cap(run_req_bin_pkg, req="bin")
            run_req_lib_cap=find_cap(run_req_lib_pkg, req="lib", host_cpu="x86_64")

            #StaticRunRequiresCap=run_req_bin_pkg
            #run_req_lib_cap=bld_req_lib_pkg

            StaticRunRequiresCap=run_req_bin_cap
            RunRequiresCap =uniq(run_req_bin_cap + run_req_lib_cap)

# now we play a bit of a guessing game...
            lib_name=desc_full_lib.split()
            if len(lib_name)==1: lib_name=lib_name[0]
            else:
                if len(bld_req_hdr)==1:
                    lib_name=re_hdr.search(bld_req_hdr[0]).groupdict()["hdr"]
                elif len(bld_req_lib)==1:
                    lib_name=re_lib.search(bld_req_lib[0]).groupdict()["lib"]
                elif len(run_req_lib_pkg)==1:
                    lib_name=re_pkg.search(run_req_lib_pkg[0]).groupdict()["pkg"]
                elif desc_full_lib=="check types":
                    lib_name="types"
                else:
                    lib_name=desc_full_lib+"_QQQ"
            #if lib_name=="m": lib_name="stdhdr"
            if lib_name=="m": lib_name="math"

            lib_name=lib_name.lower()
            mac_name=re_hyphen.sub("_",lib_name)

            out_d=dict(
                lib_desc=desc_full_lib,
                lib_name=lib_name,
                mac_name=mac_name,
                bld_req_bin=   bld_req_bin,
                bld_req_hdr=   bld_req_hdr,
                bld_req_lib=   bld_req_lib,
                bld_req_bhl=   bld_req_bhl,

                bld_req_bin_pkg=bld_req_bin_pkg,
                bld_req_hdr_pkg=bld_req_hdr_pkg,
                bld_req_lib_pkg=bld_req_lib_pkg,
                BuildRequiresPkg=BuildRequiresPkg,
                DPKG_BuildRequiresPkg=DPKG_BuildRequiresPkg,

                bld_req_bin_cap=   bld_req_bin_cap,
                bld_req_hdr_cap=   bld_req_hdr_cap,
                bld_req_lib_cap=   bld_req_lib_cap,
                BuildRequiresCap=   BuildRequiresCap,
                YUM_BuildRequiresCap=   YUM_BuildRequiresCap,

                run_req_bin=       run_req_bin,
                run_req_lib=       run_req_lib,
                run_req_bl=       run_req_bl,

                run_req_bin_pkg=   run_req_bin_pkg,
                run_req_lib_pkg=   run_req_lib_pkg,
                RunRequiresPkg=   RunRequiresPkg,
                DPKG_RunRequiresPkg=   DPKG_RunRequiresPkg,

                StaticRunRequiresCap=   StaticRunRequiresCap,
                run_req_lib_cap=   run_req_lib_cap,
                RunRequiresCap=    RunRequiresCap,

                # ProvidesCap=ws_join( PACKAGE+"-"+re_devel.sub(de_devel,pkg) for pkg in run_req_lib_pkg ),
                ProvidesCap=PACKAGE+"-"+lib_name,
                DPKG_ProvidesCap=[PACKAGE,PACKAGE+"-"+lib_name],
            )
            yield out_d

re_dash_number_etc=re.compile("-[0-9].*", re.MULTILINE)
re_colon_etc=re.compile(": .*", re.MULTILINE)
re_hyphen=re.compile("-")

def find_pkg(bin_or_hdr_or_lib_l):
    out_s=set()
    for bin_or_hdr_or_lib in bin_or_hdr_or_lib_l:
        if opt_d.local_package_manager==local_package_manager_dpkg:
            with os.popen(opt_d.local_package_manager+" -S "+bin_or_hdr_or_lib,'r') as rpm_qf:
                for pkg in rpm_qf:
                    pkg=re_colon_etc.sub("",pkg.strip())
                    if pkg: out_s.add(pkg)
        elif opt_d.local_package_manager==local_package_manager_rpm:
            with os.popen(opt_d.local_package_manager+" -qf "+bin_or_hdr_or_lib,'r') as rpm_qf:
                for pkg in rpm_qf:
                    pkg=re_dash_number_etc.sub("",pkg.strip())
                    if pkg: out_s.add(pkg)
        else:
            raise KeyError(opt_d.local_package_manager)
    out_l=PrintableList(out_s)
    out_l.sort()
    return out_l

"""
$ rpm -q --provides gsl-devel
gsl-devel = 2.5-1.el8
gsl-devel(x86-64) = 2.5-1.el8
pkgconfig(gsl) = 2.5
gsl-devel = 2.5-1.el8
gsl-devel(x86-32) = 2.5-1.el8
pkgconfig(gsl) = 2.5

$ rpm -q --provides gsl-devel.x86_64
gsl-devel = 2.5-1.el8
gsl-devel(x86-64) = 2.5-1.el8
pkgconfig(gsl) = 2.5

$ rpm -q --provides gsl-devel.i686
gsl-devel = 2.5-1.el8
gsl-devel(x86-32) = 2.5-1.el8
pkgconfig(gsl) = 2.5


rpm -q --provides gsl
gsl = 2.5-1.el8
gsl(x86-64) = 2.5-1.el8
libgsl.so.23()(64bit)
libgslcblas.so.0()(64bit)
gsl = 2.5-1.el8
gsl(x86-32) = 2.5-1.el8
libgsl.so.23
libgslcblas.so.0

$ rpm -q --provides gsl-2.5-1.el8.x86_64
gsl = 2.5-1.el8
gsl(x86-64) = 2.5-1.el8
libgsl.so.23()(64bit)
libgslcblas.so.0()(64bit)

$ rpm -q --provides gsl-2.5-1.el8.i686
gsl = 2.5-1.el8
gsl(x86-32) = 2.5-1.el8
libgsl.so.23
libgslcblas.so.0
"""

#re_arch=re.compile(r"\(x86-32|x86-64|i[1-9]86|aarch64\)")
#de_arch="%{_isa}"

re_cap_ver=re.compile(r"[ (].*")
de_cap_ver="%{?_isa}"

#bld_special_l="gcc clang".split() # bridges arch

re_quote=re.compile(r"'\"")
re_op_eq_etc=re.compile(r" *[<>=] *.*$")
re_cc=re.compile(r"^(gcc|clang|c_compiler)(|[1-9][0-9]*)$")
re_devel=re.compile(r"-devel")
de_devel=""

re_ignore=re.compile(r"^(pkgcpnfig|bundled|config)\(")

re_suffix=re.compile(r"-(headers|headers-x86|devel|lib)$")

re_colon_arch_colon_etc=re.compile(r":[^:]:.*")

def find_cap(pkg_l, req="yum", host_cpu="noarch"):
    # yum for any pkg is specific to the platform, so does not need to be canonised.
    host_cpu="" if host_cpu=="noarch" else re_quote.sub("",output_variable_d["host_cpu"]).join("()")
    out_l=PrintableList()
    for pkg in pkg_l:
        # Note: `rpm -q --provides qqq` finds any package provising qqq, EVEN if it is not installed!
        first_cap=best_cap=guess_cap=None
        if opt_d.local_package_manager==local_package_manager_dpkg:
# https://unix.stackexchange.com/questions/156421/can-capabilities-be-specified-in-debian-packages
            #with os.popen(local_package_manager+" -S "+pkg,'r') as rpm_q_provides:
            #    cap_l="".join(rpm_q_provides).splitlines()
            out_l.append(re_colon_arch_colon_etc.sub("",pkg)) # the (pkg) IS the (cap)
        elif opt_d.local_package_manager==local_package_manager_rpm:
            with os.popen(opt_d.local_package_manager+" -q --provides "+pkg,'r') as rpm_q_provides:
                cap_l="".join(rpm_q_provides).splitlines()
            for enum, in_cap in enumerate(cap_l):
                if re_ignore.search(in_cap): continue
                cap=in_cap
                cap=re_op_eq_etc.sub("",cap)
                first_cap=first_cap or cap
                if cap.startswith(pkg): best_cap =best_cap or cap
                if " = " in in_cap:     guess_cap=guess_cap or cap

            cap = best_cap or guess_cap or first_cap or pkg

            #if cap.startswith(pkg) and ( host_cpu in cap or "(" not in pkg ):
            #    cap=re_cap_ver.sub(de_cap_ver if req=="lib" else "" ,cap)
    # special case: glibc
            if req=="hdr":
                if cap in ["glibc","glibc-headers","glibc-headers-x86"]: cap="glibc"
                cap=re_suffix.sub(de_devel,cap)
                cap="%{hdr "+cap+"}"
            elif req=="lib":
                cap=re_suffix.sub(de_devel,cap)
                cap="%{lib "+cap+"}"
            elif req=="bin":
                if re_cc.search(cap): cap="%C_COMPILER"
                else:
                    cap=re_suffix.sub(de_devel,cap)
                    cap="%{bin "+cap+"}"

            else: 0/1

            if cap not in out_l: out_l.append(cap)
        else:
            raise KeyError(opt_d.local_package_manager)

    return out_l


sample_in="""
Version 3.0.1-4, January/February 2022
* Several bug fixes, reported for 3.0.0.
* Updates a68g.exe to GSL 2.7.1 and R mathlib 4.1.2.

Version 3.0.0, December 2021
* On platforms that support them: 64 bit INT/BITS and 128-bit LONG INT, LONG BITS and LONG REAL.
  These platforms include amd64, x86_64 and i386 with GCC.
* More bindings for routines from the GNU Scientific Library.
* Adds a generalized incomplete gamma function.
* Builds with R mathlib bindings, if available.
* Fixes several minor bugs.
"""

sample_out=""".vscode/
* Fri Nov 19 2021 Neville Dempsey <NevilleD.algol68@sgr-a.net> - 2.8.4-21013 - %packager
- algol68g-2.8.4-21013.spec - release with newist algol68g version tested for rhel8+fedora35+suse15+awsl2
- Overhaul of .spec file to accomidate changes from rhe7 to rhel8 and suse15 etc.
"""

re_date= re.compile(r"^Version (?P<version>[^ ]*), (?P<month>[^ ]*) (?P<year>[0-9]{4,5}) *")
re_point=re.compile(r"^[*] +(?P<text>.*)")
re_text= re.compile(r"^(?P<text>.*)")

def fmt_changelog(NEWS_l=["NEWS"]):
    bug_report=opt_d.bug_report
    out_l=[]
    for arg in NEWS_l:
        with open(arg,"r") as NEWS_f:
            for line in NEWS_f:
                match=re_date.search(line)
                if match:
                    d=match.groupdict()
                    if "/" in d["month"]: d["month"]=d["month"].split("/")[0]
                    d["mday"]="01"
                    dmy=("{mday} {month} {year}".format(**d))
                    t=time.strptime(dmy,"%d %B %Y")
                    out_l.append(" ".join(["*",time.strftime("%a %b %d %Y",t),bug_report,"-",d["version"]]))
                else:
                    match=re_point.search(line)
                    if match:
                        out_l.append(" ".join(["-",match.groupdict()["text"]]))
                    else:
                        match=re_text.match(line)
                        text=match.groupdict()["text"]
                        if not text:
                            out_l.append(text)
                        else:
                            out_l.append("- "+text)

def fmt_control(README_l=["README"]):
    bug_report=opt_d.bug_report
    out_l=[]
    for arg in README_l:
        with open(arg,"r") as README_f:
            for line in README_f:
                if line.strip()=="": line="."
        out_l.append(" "+line)
    return "\n".join(out_l)

class ReadFileDict(object):
    """ read in a file "as is" ..
        or /format to a specific alternate format
    """
    def __getitem__(self,key):

        if key=="NEWS/changelog":
            try:
                return fmt_changelog()
            except IOError as error:
                print(error,"NEWS")

        if key=="README/control":
            try:
                return fmt_control()
            except IOError as error:
                print(error,"README")

        try:
            with open(key,"r") as file:
                return "".join(file)
        except IOError as error:
            return key+"??"

rf_d=ReadFileDict()

package_builder_rpm ="rpmbuild"
local_package_manager_rpm ="rpm"

package_builder_dpkg="dpkg-buildpackage"
local_package_manager_dpkg="dpkg"

algol68_example_arg_l=[
    '--Summary','Algol 68 interpreter/compiler with utils and postgresql support',
    '--package_builder',package_builder_rpm,
    '--local_package_manager',local_package_manager_rpm,
    # '--Source','https://jmvdveer.home.xs4all.nl/algol68g-3.0.6.tar.gz',
    # '--Source','https://jmvdveer.home.xs4all.nl/algol68g-3.1.9.tar.gz',
    '--Source','https://jmvdveer.home.xs4all.nl/algol68g-3.2.0.tar.gz',
# pre a68g-3.1.9 was:     # '--Build','22113',
    # '--Build','23456', # 56th June 2023
#    '--os_release','rhel_8.5',
    '--bug_report','Marcel van der Veer <algol68g@xs4all.nl>',
    #'--Patch','22070',
    #'--Patch','22075',
    #'--Patch','22076',
# pre a68g-3.1.9 was:     #'--avoid_automake_install','22079', # some legacy system's have such and old version we need to avoid
    '--DOWNLOAD_PAGE','https://jmvdveer.home.xs4all.nl/en.download.algol-68-genie-current.html',
    '--DOCUMENTATION_PAGE','https://jmvdveer.home.xs4all.nl/en.algol-68-genie.html',
    '--package_alias','a68g',
#    '--License','GNU # pre a68g-3.1.9 was: GENERAL PUBLIC LICENSE, Version 3, 29 June 2007 - read[LICENSE]',
    '--License','GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007 - read[COPYING]',
    # '--sub_package_name','tiny',
    '--sub_package_name','full',
    '--enable_full','long-types',
    '--enable_full','compiler',
    '--enable_full','quadmath',
    '--enable_full','mpfr',
    '--enable_full','mathlib',
    '--enable_full','gsl',
    '--enable_full','plotutils',
    '--enable_full','postgresql',
    #'--merge_extra_tool_l','algol68_release-0.3-22113.tar.gz', # include release building utils
    #'--source_input_dir','../algol68g-3.0.6-ws',
    '--source_input_dir','.',
    #'--build_staging_dir',os.path.join(os.environ["HOME"],'rpmbuild/BUILD/algol68g'),
    '--build_staging_dir','.',
]

""" re: --avoid_automake_install
/home/algol68/rpmbuild/BUILD/algol68g-3.0.6/missing: line 81: aclocal-1.16: command not found
WARNING: 'aclocal-1.16' is missing on your system.
         You should only need it if you modified 'acinclude.m4' or
         'configure.ac' or m4 files included by 'configure.ac'.
"""
if os.path.exists("/usr/bin/automake"):
    # then os.system("cp -p /home/nevilled/rpmbuild/BUILD/algol68g-3.0.6/configure algol68g-3.0.6-22079-patchsrc")
    # and rebuild patch...
    pass
else:
    # matching configure patches, so that autoconf doesn't need to be installed.
    algol68_example_arg_l.extend(["--avoid_automake_install", "22079"])

gawk_example_arg_l=[
    "gawk-5.1.1/config.log"
]

ok_l="yes found".split()

import datetime

def yymdd(date):
    y, m, d=date.year, date.month, date.day
    y-=2000

    if m==1: m=2
    elif m==2: d+=50
    elif m==12: m=11; d+=50

    m-=2
    return y*1000+m*100+d

if __name__ == "__main__":

    from optparse import OptionParser
    parser = OptionParser(conflict_handler="resolve")

    optcflags="-m32 -march=i686 -fPIC -O3"
    optcflags="-fPIC -O3 -g"
    optcflags="-g -fPIE -O3 -I /usr/include/pgsql -I /usr/lib64/R/include" # +" -Dstdscr=_nc_stdscr"
    # optflags="-g -O3 -fPIC"
    optflags="-g -pie"

    default_opt_d0={'verbose': True,
                    'package_builder': 'rpmbuild',
                    'local_package_manager': 'rpm',
                    'Epoch': '23817',
                    'Summary': 'read[README]',
                    'Group': 'Development/Languages',
                    'Section': 'devel',
                    'Priority': 'optional',
                    'Build': '23959',
                    'License': 'GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007 - read[COPYING]',
                    'DOWNLOAD_PAGE': 'https://jmvdveer.home.xs4all.nl/en.download.algol-68-genie-current.html',
                    'DOCUMENTATION_PAGE': 'https://jmvdveer.home.xs4all.nl/en.algol-68-genie.html',
                    'Packager': 'Neville Dempsey <NevilleD.packager@sgr-a.net>',
                    'RPMPackDate': 'Sat Dec 09 2023',
                    'DEBPackDate': 'Sat, 09 Dec 2023 17:41:42 +1000',
                    'bug_report': 'x@y.z',
                    'Source_l': [],
                    'Patch_l': [],
                    'description': 'description?',
                    'files': 'files?',
                    'doc': 'doc?',
                    'changelog': 'read[NEWS]',
                    'etc': 'etc?', 'pkg_name': 'remix',
                    'enable_full': [],
                    'enable_core': ['compiler', 'gsl', 'mathlib', 'parallel', 'plotutils', 'readline', 'curses'], 'enable_tiny': ['standard-types'],
                    'enable_ignore': 'thread-safety generic standard-types pic arch',
                    'CC': 'gcc',
                    'CFLAGS': '-g -fPIE -O3 -I /usr/include/pgsql -I /usr/lib64/R/include',
                    'CXXFLAGS': '-g -pie',
                    'FFLAGS': '-g -pie',
                    'FCFLAGS': '-g -pie',
                    'LD': 'ld', 'static_LDFLAGS': '-Wl,-static',
                    'LDFLAGS': '-g -pie -L/usr/lib64/R/lib',
                    'core_tests': 'Core tests.',
                    'package_alias': 'a68g',
                    'verbose_requires': False,
                    'so_l': ['.so', '.so.0', '.so.1', '.so.2', '.so.3', '.so.4', '.so.5', '.so.6', '.so.7', '.so.8', '.so.9', '.so.10', '.so.11', '.so.0.0', '.so.0.0.0', '.a'],
                    'ignore_missing': True,
                    'avoid_automake_install': '',
                    'sub_package_name': ['tiny', 'full'],
                    'merge_extra_tool_l': [],
                    'source_input_dir': '.',
                    'build_staging_dir': '.',
                    'insert_headings': False
                }
    default_opt_d=dict(
        verbose=True,
        package_builder=package_builder_rpm, # or dpkg-buildpackage
        local_package_manager=local_package_manager_rpm, # or dpkg
# pre a68g-3.1.9 was:  # Epoch="20930", 30th Nov 2020
        Epoch="23817", # 17th Oct 2023
        Summary="read[README]",
        Group="Development/Languages",
        Section="devel", # as per debian/control/Section
        Priority="optional", # as per debian/control/Priority
        # Build="""%(date +"y=%y m=%m D=%d"`; case $m in (01)M=0;;(02)M=0;((D=D+50));;(12)M=9;((D=D+50));;(*)((M=m-2));;esac; case $D in (?)D=0$D; esac; echo $y$M$D)""",
        PACKAGE_VERSION=None, # otherwise get from confdefs
        Build="%r"%yymdd(datetime.date.today()),
        os_release="unknown",
# pre a68g-3.1.9 was: #        License="GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007 - read[LICENSE]",
        License="GNU GENERAL PUBLIC LICENSE, Version 3, 29 June 2007 - read[COPYING]",

        DOWNLOAD_PAGE='https://jmvdveer.home.xs4all.nl/en.download.algol-68-genie-current.html',
        DOCUMENTATION_PAGE='https://jmvdveer.home.xs4all.nl/en.algol-68-genie.html',        Packager="Neville Dempsey <NevilleD.packager@sgr-a.net>",
        RPMPackDate=time.strftime("%a %b %0d %Y"), # Sun Sep 01 2002 - as per changelog
        DEBPackDate=time.strftime("%a, %0d %b %Y %T %z"), # Mon, 25 Jun 2012 01:05:51 +0200 - as per control
        bug_report="x@y.z",
        Source_l=[],
        Patch_l=[],
        description="description?",
        files="files?",
        doc="doc?",
        changelog="read[NEWS]",
        etc="etc?",
        pkg_name="remix",
        enable_full="".split(),
# pre a68g-3.1.9 was:         # enable_core="parallel curses readline".split(),
        enable_core="compiler gsl mathlib parallel plotutils readline curses".split(),
        enable_tiny="standard-types".split(),
        enable_ignore="thread-safety generic standard-types pic arch", # int-8-real-16
        CC="gcc",
        #CFLAGS="-m32 -march=i686 "+optflags, # -Wall -Wshadow -Wunused-variable -Wunused-parameter -Wno-long-long -fno-diagnostics-color (as per a68g)
        CFLAGS=optcflags, # -Wall -Wshadow -Wunused-variable -Wunused-parameter -Wno-long-long -fno-diagnostics-color (as per a68g)
        CXXFLAGS=optflags,
        FFLAGS=optflags,
        FCFLAGS=optflags,
        # gcc: Supported emulations: elf_x86_64 elf32_x86_64 elf_i386 elf_iamcu i386linux elf_l1om elf_k1om i386pep i386pe
        LD="ld",
        static_LDFLAGS="-Wl,-static",
        # -L/usr/lib64/R/lib is required for Suse15.3
        LDFLAGS=optflags+" -L/usr/lib64/R/lib", # +" -shared",
        # target="i686-all-linux-gnu",
        core_tests="Core tests.",
        package_alias="a68g",
        verbose_requires=not True,
        so_l=(".so .so.0 .so.1 .so.2 .so.3 .so.4 .so.5 .so.6 .so.7 .so.8 .so.9 .so.10 .so.11 .so.0.0 .so.0.0.0 .a".split()),
        ignore_missing=True, # QQQ False
        avoid_automake_install="", # patch and touch ./configure so to avoid a (potentually tedious) automake/rebuild
        sub_package_name=["full"], # "tiny full".split(),
        merge_extra_tool_l=[],
        # package_builder=package_builder,
        # local_package_manager=local_package_manager,
        source_input_dir=".",
        build_staging_dir=".",
        insert_headings=False,
        bindir=[], # "%package_alias".split(), #  %package_alias-{SUBPACKAGE}".split(),
        includedir=[] # "%package_alias.h %package_alias-*.h".split(),
    )
# from `rpm --showrc`
# for future rhel reference...
    rhel9_build_dir_name="""
bindir binfmtdir builddir buildrootdir
datadir datarootdir defaultdocdir defaultlicensedir
emacs_sitelispdir emacs_sitestartdir environmentdir exec_prefix
fileattrsdir fmoddir fontbasedir fontconfig_confdir fontconfig_masterdir fontconfig_templatedir
includedir infodir initddir initrddir ivyxmldir
javaconfdir javadir javadocdir jnidir journalcatalogdir
jvmcommondatadir jvmcommonlibdir jvmcommonsysconfdir jvmdatadir jvmdir jvmlibdir jvmprivdir jvmsysconfdir
libdir libexecdir localstatedir
mandir mavenpomdir metainfodir modprobedir modulesdir modulesloaddir monodir monogacdir
oldincludedir
pkgdocdir prefix presetdir
rpmdir rpmluadir rpmmacrodir rundir
sbindir sharedstatedir sourcedir specdir srcrpmdir swidtagdir sysconfdir sysctldir
systemdgeneratordir systemd_system_env_generator_dir systemd_user_env_generator_dir systemdusergeneratordir systemd_util_dir
systemtap_datadir systemtap_tapsetdir sysusersdir
tmpfilesdir
udevhwdbdir udevrulesdir unitdir userpresetdir user_tmpfilesdir userunitdir usr usrsrc
var
""".split()
    # Note: generated from `create_rpmbuild_files_section.sh -d`
    fedora39_build_dir_name="""
bindir binfmtdir builddir buildrootdir
datadir datarootdir defaultdocdir defaultlicensedir
environmentdir exec_prefix
fileattrsdir fmoddir fontbasedir fontconfig_confdir fontconfig_masterdir fontconfig_templatedir
iconsdir includedir infodir initddir initrddir ivyxmldir
javaconfdir javadir javadocdir jnidir journalcatalogdir
jvmcommondatadir jvmcommonlibdir jvmcommonsysconfdir jvmdatadir jvmdir jvmlibdir jvmprivdir jvmsysconfdir
libdir libexecdir localstatedir
mandir mavenpomdir metainfodir modprobedir modulesloaddir monodir monogacdir
oldincludedir
pam_confdir pam_libdir pam_moduledir pam_secconfdir pam_vendordir
pkgdocdir prefix presetdir
rpmdir rpmluadir rpmmacrodir rundir runstatedir
sbindir sharedstatedir sourcedir specdir srcrpmdir swidtagdir sysconfdir sysctldir
systemd_system_env_generator_dir systemd_user_env_generator_dir systemd_util_dir systemdgeneratordir systemdusergeneratordir
sysusersdir
tmpfilesdir
udevhwdbdir udevrulesdir unitdir user_tmpfilesdir userpresetdir userunitdir usr usrsrc
var
""".split()
    for dir_name in fedora39_build_dir_name:
        if dir_name not in default_opt_d:
            default_opt_d[dir_name]=[]

    """ Algol68g-2.8.4's 13 options:
        1. With hardware support for long modes
        2. With compilation support
        3. With parallel-clause support
        4. With GNU MP %s
        5. With GNU MPFR %s
        6. With mathlib from R %s
        7. With GNU Scientific Library %s
        8. With GNU plotutils %s
        9. With curses %s
        10. With TCP/IP support
        11. With PostgreSQL support
        12? GNU libc version glibc 2.28
        13? GNU libpthread version NPTL 2.28
        +
        1:enable-int-8-real-16
        2:enable-compiler
        3:enable-parallel
        MP
        5:enable-mpfr
        6:enable-mathlib
        7:enable-gsl
        8:enable-plotutils
        9:enable-curses
        10:enable-postgresql enable-thread-safety
        11:TCP/IP
        enable-readline

        enable-generic enable-int-4-real-8 enable-arch=cpu enable-pic=option
        enable-dirent enable-http
    """

    # pp(default_opt_d=default_opt_d)

    for option,default in default_opt_d.items():
        short="-"+option[0]

        if isinstance(default,list):
            parser.add_option(short, "--"+option, action="append",
                dest=option, default=default, help=option, metavar=option)
        else:
            parser.add_option(short, "--"+option,
                dest=option, default=default, help=option, metavar=option)

    parser.add_option("-q", "--quiet",
                    action="store_false", dest="verbose", default=True,
                    help="don't print status messages to stdout")

    pp(argv=sys.argv[1:] or algol68_example_arg_l)
    (opt_d, arg_l) = parser.parse_args(sys.argv[1:] or algol68_example_arg_l)
    pp(opt_d=opt_d)
    pp(arg_l=arg_l)

    if opt_d.avoid_automake_install: opt_d.Patch_l.append(opt_d.avoid_automake_install)

    core=" ".join("--enable-"+enable for enable in opt_d.enable_core)
    tiny=" ".join("--enable-"+enable for enable in opt_d.enable_tiny)

    special_pkg_l=["remix","native"]

    configure_opt_l_of_sub_package_d=dict(
        tiny   =  core+" "+         " ".join( "--disable-"+disable for disable in opt_d.enable_full ),
        full   =  core+" "+tiny+" "+" ".join( "--enable-"+enable   for enable  in opt_d.enable_full ),
        # bug: `with_long-types`` is not a valid m4 vaiable name, so hypens in option names will be ignored
        remix  =  core+" "+tiny+" "+" ".join( "%{?opt_"+re_hyphen.sub("_",enable)+"}" for enable  in opt_d.enable_full ),
        native =  core,
    )

    configure_sh='env CFLAGS="{opt_d.CFLAGS}" LDFLAGS="{opt_d.LDFLAGS}" ./configure '.format(opt_d=opt_d)

    if not arg_l:
        sub_package_arg_d=OrderedDict()
# NB: tiny not build by default - QQQ
        if False: sub_package_arg_d["tiny"] = configure_sh+configure_opt_l_of_sub_package_d["tiny"]
        sub_package_arg_d["full"] = configure_sh+configure_opt_l_of_sub_package_d["full"]

    else:
        sub_package_arg_d=OrderedDict(zip(opt_d.sub_package_name,arg_l))

    sub_package_summary_d=OrderedDict()

    os.chdir(opt_d.source_input_dir)
    for sub_package_name, config_log_name in sub_package_arg_d.items():
        pp(sub_package_name=sub_package_name)
        pp(config_log_name0=config_log_name)
        if configure_sh in config_log_name:
            pp(config_log_name1=config_log_name)
            with os.popen(config_log_name,"r") as configure_log:
                configure_log=list(configure_log)
                print(config_log_name,"with",len(config_log_name),"lines")
            config_log_name="config.log"
        pp(config_log_name2=config_log_name)
        with open(config_log_name) as config_log:
            paragraph_d=lexx_config_log(config_log)
            chapter_d=compile_config_log(paragraph_d)
            # print_chapter_d(chapter_d)
            sub_package_summary_d[sub_package_name]=chapter_d
        # os.rename(config_log_name,hostname_+sub_package_name+"-"+config_log_name)
        # chapter_d["configure_opt_l"]=configure_opt_l_of_sub_package_d[sub_package_name]

    output_variable_d=dict([ (val_d["name"], val_d["value"])
        for val_d in chapter_d['Output variables.']['paragraph_0']
            if val_d["desc"] =="var" ])

    if opt_d.package_builder == package_builder_rpm:
        print_autoconf_template(
            #get_dpkg_deb_template_of_sect_of_subfile(),
            get_rpm_spec_template_of_sect_of_subfile(),
            sub_package_summary_d,
            configure_opt_l_of_sub_package_d=configure_opt_l_of_sub_package_d
        )

    elif opt_d.package_builder == package_builder_dpkg:
        print_autoconf_template(
            get_dpkg_deb_template_of_sect_of_subfile(),
            sub_package_summary_d,
            configure_opt_l_of_sub_package_d=configure_opt_l_of_sub_package_d
        )

    else:
        raise KeyError(opt_d.package_builder)
