
#!/bin/bash

def_SHR_REPO="NevilleDNZ-downstream/algol68_autopkg-downstream"

SHR_AR_ROOT=action-runner
mkdir -p "$SHR_AR_ROOT"

get_SHR_REPO(){
    ( cd "$SHR_AR_ROOT"; ls -ltrd */* )
    read def_SHR_REPO <<< $(echo $def_SHR_REPO; ls -td */* | tail -1)
    read -e -p "SHR_REPO [ $def_SHR_REPO ]: " SHR_REPO
    SHR_REPO=${SHR_REPO:-$def_SHR_REPO}
    SHR_REPO_URL="https://github.com/$SHR_REPO"
    SHR_URL_TOK_NEW="$SHR_REPO_URL/settings/actions/runners/new"
}

ignore_depr(){
   sed 's/\/run.sh//; /_depr$/d'
}

get_default_SHR_NAME(){
   ( cd $SHR_AR_DIR && ( ls -t */run.* 2> /dev/null | ignore_depr ; echo "$(hostname)" ) | head -1)
}

get_SHR_NAME(){
    case "$#" in
        (1)
            (
                 cd $SHR_AR_ROOT &&
                   ls -tr */*/run.* 2> /dev/null | ignore_depr
                   get_default_SHR_NAME
            ) | sort -u
	        def_SHR_NAME=`get_default_SHR_NAME`
            read -e -p "SHR_NAME [ $def_SHR_NAME ]: " SHR_NAME
            SHR_NAME=${SHR_NAME:-$def_SHR_NAME}
        ;;
        (2) SHR_NAME="$2" ;;
        (*) echo "Huh?";;
    esac
    SHR_AR_DIR="$SHR_AR_ROOT/$SHR_REPO/$SHR_NAME"
}

get_TOKEN(){
    echo "$SHR_URL_TOK_NEW"
    read -e -p "Token: " SHR_TOKEN
}

RAISE(){
    echo RAISE/$?: "$cmd" 1>&2
}

TRACK(){
    cmd="$*"
    "$@" || RAISE
}

TRACE(){
    cmd="$*"
    "$@"
}

TRACE=TRACE
TRACK=TRACK
WATCH=WATCH

case "$(uname -m)" in
    (x86_64)MACH=x64;;
    (armv7l|arm*)MACH=arm;;
    (aarch64)MACH=arm64;;
    (*)MACH=Huh;;
esac

V=2.314.1
AR_TAR=actions-runner-linux-$MACH-$V.tar.gz 

case "$1" in
    (download)
        ## Download
        # Create a folder
            # $TRACK mkdir actions-runner && cd actions-runner
        # Download the latest runner package
# curl -o actions-runner-linux-x64-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-x64-2.314.1.tar.gz
# curl -o actions-runner-linux-arm-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-arm-2.314.1.tar.gz
# curl -o actions-runner-linux-arm64-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-arm64-2.314.1.tar.gz

        curl -o $AR_TAR -L https://github.com/actions/runner/releases/download/v$V/$AR_TAR
     
# Optional: Validate the hash
# $TRACK echo "6c726a118bbe02cd32e222f890e1e476567bf299353a96886ba75b423c1137b5  actions-runner-linux-x64-2.314.1.tar.gz" | shasum -a 256 -c
    ;;
    (configure)
        get_SHR_REPO "$@"
        get_SHR_NAME "$@"
        set +x
        if mkdir -p $SHR_AR_DIR && cd $SHR_AR_DIR; then
            get_TOKEN
            echo "$SHR_TOKEN" > TOKEN.txt
        # Extract the installer
            $TRACK tar xzf ../../../../$AR_TAR # actions-runner-linux-x64-2.314.1.tar.gz
        # Configure
        # Create the runner and start the configuration experience
	# ToDo: ID_LIKE fedora, centos, rhel etc
        SHR_LABELS="$SHR_NAME,$( . /etc/os-release; echo $ID$VERSION_ID-`uname -m`,$ID$VERSION_ID,$ID,`uname -m`,$ID$VERSION_ID-$MACH,$MACH;)"
        echo HINT: name: $SHR_NAME - SHR_TOKEN: $SHR_TOKEN - SHR_LABELS: $SHR_LABELS
            $TRACK ./config.sh --name "$SHR_NAME" --unattended --labels "$SHR_LABELS" --replace Y --url $SHR_REPO_URL --token $SHR_TOKEN
        fi
    ;;
    (run)
        get_SHR_REPO "$@"
        get_SHR_NAME "$@"
        if cd $SHR_AR_DIR; then
            # Last step, run it!
            $TRACK ./run.sh
            # Using your self-hosted runner
            # Use this YAML in your workflow file for each job
            # runs-on: self-hosted
        fi
    ;;
    (remove)
        get_SHR_REPO "$@"
        get_SHR_NAME "$@"
        if cd $SHR_AR_DIR; then
            if [ -f "TOKEN.txt" ]; then
                SHR_TOKEN=`cat TOKEN.t
            else
                get_TOKEN
            fi
            echo SHR_TOKEN: $SHR_TOKEN
            $TRACK ./config.sh remove --token $SHR_TOKEN
            cd -
            $TRACK mv $SHR_AR_DIR "$SHR_AR_DIR"_depr
        fi
    ;;
    (status)
        get_SHR_REPO "$@"
        get_SHR_NAME "$@"
        if cd $SHR_AR_DIR; then
            cat "TOKEN.txt"
        fi
    ;;
    (*) echo Huh...;;
esac
