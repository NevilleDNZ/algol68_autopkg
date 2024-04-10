#!/bin/bash

def_SHR_REPO_NAME="NevilleDNZ-downstream/algol68_autopkg-downstream"

OPT_read= # was: -e, but this may not work in ssh??
UNTAR_DIR=untar

SHR_AR_ROOT=actions-runner
mkdir -p "$SHR_AR_ROOT"

get_SHR_REPO_NAME(){
    case "$1" in
        ("")
            ( cd "$SHR_AR_ROOT"; ls -ltrd */* )
            read def_SHR_REPO_NAME <<< $(echo $def_SHR_REPO_NAME; ls -td */* | tail -1)
            PROMPTREAD "SHR_REPO_NAME [ $def_SHR_REPO_NAME ]: " SHR_REPO_NAME
        ;;
        (*)
            SHR_REPO_NAME="$1"
        ;;
    esac
    SHR_REPO_NAME=${SHR_REPO_NAME:-$def_SHR_REPO_NAME}
    SHR_REPO_NAME_URL="https://github.com/$SHR_REPO_NAME"
    SHR_URL_TOK_NEW="$SHR_REPO_NAME_URL/settings/actions/runners/new"
}

ignore_depr(){
   sed 's/\/run.sh//; /_depr$/d'
}

get_default_SHR_RUNNER_NAME(){
   ( cd $SHR_AR_DIR && ( ls -t */run.* 2> /dev/null | ignore_depr ; echo "$(hostname)" ) | head -1)
}

get_SHR_RUNNER_NAME(){
    case "$1" in
        (""|*"*"*)
            (
                 cd $SHR_AR_ROOT &&
                   ls -tr */*/run.* 2> /dev/null | ignore_depr
                   get_default_SHR_RUNNER_NAME
            ) | sort -u
	        def_SHR_RUNNER_NAME=`get_default_SHR_RUNNER_NAME`
            PROMPTREAD "SHR_RUNNER_NAME [ $def_SHR_RUNNER_NAME ]: " SHR_RUNNER_NAME
            SHR_RUNNER_NAME=${SHR_RUNNER_NAME:-$def_SHR_RUNNER_NAME}
        ;;
        (-) SHR_RUNNER_NAME="$(hostname)";;
        (*) SHR_RUNNER_NAME="$1";;
    esac
    SHR_AR_DIR="$SHR_AR_ROOT/$SHR_REPO_NAME/$SHR_RUNNER_NAME"
}

get_TOKEN(){
    case "$1" in
        ("")
            echo "$SHR_URL_TOK_NEW"
            PROMPTREAD "Token: " SHR_TOKEN
        ;;
        (*)SHR_TOKEN="$1";;
    esac
}

RAISE(){
    echo RAISE/$?: "$cmd" 1>&2
}

ASSERT(){
    cmd="$*"
    "$@" || RAISE
}

TRACE(){
    cmd="$*"
    "$@"
}

PROMPTREAD(){
    prompt="$1"; shift
    # echo -n "PROMPT: $prompt" 1>&2
    read $OPT_read -p "$prompt" "$@" 1>&2
}

TRACE=TRACE
ASSERT=ASSERT
WATCH=WATCH

case "$(uname -m)" in
    (x86_64)MACH=x64;;
    (armv7l|arm*)MACH=arm;;
    (aarch64)MACH=arm64;;
    (*)MACH=Huh;;
esac

V=2.314.1
V=2.315.0
# actions-runner-linux-arm-2.315.0.tar.gz
# actions-runner-linux-x64-2.315.0.tar.gz314159
# actions-runner-linux-arm64-2.315.0.tar.gz
# actions-runner-osx-x64-2.315.0.tar.gz
# actions-runner-osx-arm64-2.315.0.tar.gz
# actions-runner-win-x64-2.315.0.zip
# actions-runner-win-arm64-2.315.0.zip
AR_TAR=actions-runner-linux-$MACH-$V.tar.gz
# echo AR_TAR=$AR_TAR

cmd="$1"; shift
case "$cmd" in
    (help) # cmd
        grep "^ *([a-z_]*) # cmd" "$0"
        exit
    ;;
    (test) # cmd
        get_SHR_REPO_NAME "$1"
        get_SHR_RUNNER_NAME "$2"
        get_TOKEN "$3"
        echo SHR_REPO_NAME=$SHR_REPO_NAME SHR_RUNNER_NAME=$SHR_RUNNER_NAME SHR_TOKEN=$SHR_TOKEN
    ;;
    (download) # cmd
        ## Download
        # Create a folder
            # $ASSERT mkdir actions-runner && cd actions-runner
        # Download the latest runner package
# curl -o actions-runner-linux-x64-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-x64-2.314.1.tar.gz
# curl -o actions-runner-linux-arm-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-arm-2.314.1.tar.gz
# curl -o actions-runner-linux-arm64-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-arm64-2.314.1.tar.gz

        [ ! -f "$AR_TAR" ] && # may root cause a problem if previously curl failed!! :-/
            ASSERT curl -o $AR_TAR -L https://github.com/actions/runner/releases/download/v$V/$AR_TAR

# Optional: Validate the hash
# $ASSERT echo "6c726a118bbe02cd32e222f890e1e476567bf299353a96886ba75b423c1137b5  actions-runner-linux-x64-2.314.1.tar.gz" | shasum -a 256 -c
    ;;
    (installdependencies) # cmd
        if mkdir -p $UNTAR_DIR && cd $UNTAR_DIR; then
            $ASSERT tar -xzf $OLDPWD/$AR_TAR # actions-runner-linux-x64-2.314.1.tar.gz
            set -x
            $ASSERT sudo bin/installdependencies.sh
            set +x
            cd -
        fi
    ;;
    (configure) # cmd
        get_SHR_REPO_NAME "$1"
        get_SHR_RUNNER_NAME "$2"
        set +x
        if mkdir -p "$SHR_AR_DIR" && cd "$SHR_AR_DIR"; then
            get_TOKEN "$3"
            echo "$SHR_TOKEN" > TOKEN.txt
        # Extract the installer
            $ASSERT tar -xzf ../../../../$AR_TAR # actions-runner-linux-x64-2.314.1.tar.gz
        # Configure
        # Create the runner and start the configuration experience
	# ToDo: ID_LIKE fedora, centos, rhel etc
        SHR_LABELS="$SHR_RUNNER_NAME,$( . /etc/os-release; echo $ID$VERSION_ID-`uname -m`,$ID$VERSION_ID,$ID,`uname -m`,$ID$VERSION_ID-$MACH,$MACH;)"
        echo HINT: name: $SHR_RUNNER_NAME - SHR_LABELS: $SHR_LABELS
            $ASSERT ./config.sh --name "$SHR_RUNNER_NAME" --unattended --labels "$SHR_LABELS" --replace Y --url $SHR_REPO_NAME_URL --token $SHR_TOKEN
        fi
    ;;
    (run) # cmd
        get_SHR_REPO_NAME "$1"
        get_SHR_RUNNER_NAME "$2"
        if cd $SHR_AR_DIR; then
            # Last step, run it!
            #$ASSERT ./run.sh
            exec ./run.sh
            # Using your self-hosted runner
            # Use this YAML in your workflow file for each job
            # runs-on: self-hosted
        fi
    ;;
#neville+    4657    3605  0 13:51 pts/0    00:00:00 /bin/bash /home/nevilledbld/AR/actions-runner/NevilleDNZ/algol68_autopkg/fedora-server-x86-64-39-1-5-vbox/run.sh
#neville+    4664    4657  0 13:51 pts/0    00:00:00 /bin/bash /home/nevilledbld/AR/actions-runner/NevilleDNZ/algol68_autopkg/fedora-server-x86-64-39-1-5-vbox/run-helper.sh
#neville+    4668    4664 19 13:51 pts/0    00:00:01 /home/nevilledbld/AR/actions-runner/NevilleDNZ/algol68_autopkg/fedora-server-x86-64-39-1-5-vbox/bin/Runner.Listener run
    (kill) # cmd
        get_SHR_REPO_NAME "$1"
        get_SHR_RUNNER_NAME "$2"
        ps -eaf | 
            grep "/$SHR_AR_ROOT/$SHR_REPO_NAME/$SHR_RUNNER_NAME[/]" | # bin/Runner.Listener run\$" | 
                awk '{print $2}' | xargs kill -KILL 
    ;;
    (remove) # cmd
        get_SHR_REPO_NAME "$1"
        get_SHR_RUNNER_NAME "$2"
        if cd "$SHR_AR_DIR"; then
            if [ -f "TOKEN.txt" ]; then
                SHR_TOKEN=`cat TOKEN.txt`
            else
                get_TOKEN "$3"
            fi
            # echo SHR_TOKEN: $SHR_TOKEN
            $ASSERT ./config.sh remove --token $SHR_TOKEN
            cd -
            #$ASSERT mv "$SHR_AR_DIR" "$SHR_AR_DIR"_depr
            $ASSERT rm -rf "$SHR_AR_DIR"
        fi
    ;;
    (status) # cmd
        get_SHR_REPO_NAME "$1"
        get_SHR_RUNNER_NAME "$2"
        if cd $SHR_AR_DIR; then
            echo TOKEN: `cat "TOKEN.txt"`
        fi
        ps -eaf | 
            grep "/$SHR_AR_ROOT/$SHR_REPO_NAME/$SHR_RUNNER_NAME[/]"
    ;;
    (*) echo Huh...;;
esac
