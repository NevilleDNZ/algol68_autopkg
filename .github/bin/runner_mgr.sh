CRR_REPO="https://github.com/NevilleDNZ-downstream/algol68_autopkg-downstream"
CRR_REPO="https://github.com/NevilleDNZ/algol68_autopkg-downstream"
CRR_URL_TOK_NEW="$CRR_REPO/settings/actions/runners/new"


OS="Linux"

get_CRR_NAME(){
    case "$#" in
        (1)
            (
                 ls */run.* 2> /dev/null | sed "s/\/run.sh//; /^depr_/d"
                 hostname
            ) | sort -u
            read -p "CRR_NAME: [`hostname`]" CRR_NAME
            [ "$CRR_NAME" = "" ] && CRR_NAME=`hostname`
        ;;
        (2) CRR_NAME="$2" ;;
        (*) echo "Huh?";;
    esac
}

get_TOKEN(){
    echo "$CRR_URL_TOK_NEW"
    read -p "Token: " CRR_TOKEN
}

RAISE(){
    echo RAISE/$?: "$cmd" 1>&2
    exit
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
AR=actions-runner-linux-$MACH-$V.tar.gz 

case "$1" in
    (download)
        ## Download
        # Create a folder
            # $TRACK mkdir actions-runner && cd actions-runner
        # Download the latest runner package
# curl -o actions-runner-linux-x64-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-x64-2.314.1.tar.gz
# curl -o actions-runner-linux-arm-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-arm-2.314.1.tar.gz
# curl -o actions-runner-linux-arm64-2.314.1.tar.gz -L https://github.com/actions/runner/releases/download/v2.314.1/actions-runner-linux-arm64-2.314.1.tar.gz

        curl -o $AR -L https://github.com/actions/runner/releases/download/v$V/$AR
     
# Optional: Validate the hash
# $TRACK echo "6c726a118bbe02cd32e222f890e1e476567bf299353a96886ba75b423c1137b5  actions-runner-linux-x64-2.314.1.tar.gz" | shasum -a 256 -c
    ;;
    (configure)
        get_CRR_NAME "$@"
        if mkdir $CRR_NAME && cd $CRR_NAME; then
            get_TOKEN
            echo "$CRR_TOKEN" > TOKEN.txt
        # Extract the installer
            $TRACK tar xzf ../$AR # actions-runner-linux-x64-2.314.1.tar.gz
        # Configure
        # Create the runner and start the configuration experience
        CRR_LABELS="$CRR_NAME,$( . /etc/os-release; echo $ID$VERSION_ID-`uname -m`,$ID$VERSION_ID,$ID,`uname -m`,$ID_LIKE,$ID$VERSION_ID-$MACH,$MACH;)"
        echo HINT: name: $CRR_NAME - CRR_TOKEN: $CRR_TOKEN - CRR_LABELS: $CRR_LABELS
            $TRACK ./config.sh --name "$CRR_NAME" --unattended --labels "$CRR_LABELS" --replace Y --url $CRR_REPO --token $CRR_TOKEN
        fi
    ;;
    (run)
        get_CRR_NAME "$@"
        if cd $CRR_NAME; then
            # Last step, run it!
            $TRACK ./run.sh
            # Using your self-hosted runner
            # Use this YAML in your workflow file for each job
            # runs-on: self-hosted
        fi
    ;;
    (remove)
        get_CRR_NAME "$@"
        if cd $CRR_NAME; then
            if [ -f "TOKEN.txt" ]; then
                CRR_TOKEN=`cat TOKEN.txt`
            else
                get_TOKEN
            fi
            echo CRR_TOKEN: $CRR_TOKEN
            $TRACK ./config.sh remove --token $CRR_TOKEN
            cd -
            $TRACK mv $CRR_NAME depr_$CRR_NAME
        fi
    ;;
    (status)
        get_CRR_NAME "$@"
        if cd $CRR_NAME; then
            cat "TOKEN.txt"
        fi
    ;;
    (*) echo Huh...;;
esac

