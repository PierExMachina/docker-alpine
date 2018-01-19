#!/bin/bash

## VARIABLES ##
SCRIPT_PATH=$(dirname $(realpath $0))
MIRROR="http://dl-cdn.alpinelinux.org/alpine"
IMAGE_NAME="pierexmachina/alpine"
ALPINE_VER="3.7"
BASE_PACKAGES="musl musl-utils apk-tools alpine-baselayout busybox alpine-keys libc-utils"


f_usage() {
    echo "=USAGE= ./gen_rootfs.sh"
    echo "          -v <VERSION_ALPINE> choose version of alpine (default : 3.7)"
    echo "          -e <DOCKER_ENV> Add custom environment variable separate by space (default : none)"
    echo "          -i <LIST_INSTALL> Add custom package separate by space (default : none)"
    echo "          -m <MIRROR> Choose alpine mirror (default : http://dl-cdn.alpinelinux.org/alpine)"
    echo "          -t <IMAGE_NAME> Choose image for check update (default : pierexmachina/alpine)"
    echo "          -h show this message"
    echo "Example : ./gen_rootfs -v 3.4 -e http_proxy=http://proxy.local:8080 -i 'wget curl git'"
}

f_log() {
    echo "=$1= $(date +%d/%m/%Y-%H:%M:%S) $2"
}

f_gen_repos() {
    if [ "${ALPINE_VER}" == "edge" ]; then
        REPOS_URL="${MIRROR}/edge"
        REPOS="main testing community"
    else
        REPOS_URL="${MIRROR}/v${ALPINE_VER}"
        case ${ALPINE_VER} in
            "2.7")
                REPOS="main backports"
            ;;
            "3.0")
                REPOS="main testing"
            ;;
            "3.1")
                REPOS="main"
            ;;
            "3.2")
                REPOS="main"
            ;;
            "3.3")
                REPOS="main community"
            ;;
            "3.4")
                REPOS="main community"
            ;;
            "3.5")
                REPOS="main community"
            ;;
            "3.6")
                REPOS="main community"
            ;;
            "3.7")
                REPOS="main community"
            ;;
        esac
    fi

    for i in ${REPOS}; do
        REPOSITORIES=${REPOSITORIES}"${REPOS_URL}/${i}\n"
    done
}

f_gen_rootfs() {
    mkdir -p /tmp/alpine/${ALPINE_VER}
    
    docker run -i --rm ${DOCKER_ENV} -v /tmp/alpine/${ALPINE_VER}:/mnt alpine:3.6 sh -c "apk -X ${REPOS_URL}/main --no-cache --allow-untrusted --root /mnt/rootfs --initdb add ${BASE_PACKAGES} ${PACKAGES} \
                                                            && mkdir -p /mnt/rootfs/etc/apk \
                                                            && echo -e '${REPOSITORIES}' > /mnt/rootfs/etc/apk/repositories \
                                                            && tar czf /mnt/rootfs.tar.gz . -C /mnt/rootfs \
                                                            && rm -rf /mnt/rootfs/"
}

while getopts "v:e:i:m:t:h" option
do
    case $option in
        v)
            ALPINE_VER="$OPTARG"
        ;;
        e)
            for i in $OPTARG; do
                DOCKER_ENV="${DOCKER_ENV} --env $i"
                DOCKER_ENV_BUILD="${DOCKER_ENV_BUILD} --build-arg $i"
            done
        ;;
        i)
            PACKAGES="$OPTARG"
        ;;
        m)
            MIRROR="$OPTARG"
        ;;
        t)
            IMAGE_NAME="$OPTARG"
        ;;
        h)
            f_usage
            exit 0
        ;;
    esac
done

f_gen_dockerfile() {
    cat << EOF > /tmp/alpine/${ALPINE_VER}/Dockerfile 
FROM scratch
LABEL maintainer="pierexmachina <https://github.com/PierExMachina> original version : xataz <https://github.com/xataz>" \\
        description="Alpine ${ALPINE_VER}" \\
        build_version="$(date +%Y%m%d)"

ADD rootfs.tar.gz /
CMD ["sh"] 
EOF
}

f_gen_repos
f_gen_rootfs
f_gen_dockerfile

f_log INF "Build ${IMAGE_NAME}:${ALPINE_VER}"
docker build ${DOCKER_ENV_BUILD} -t ${IMAGE_NAME}:${ALPINE_VER} /tmp/alpine/${ALPINE_VER}
[ $? -eq 0 ] && f_log INF "Build ${IMAGE_NAME}:${ALPINE_VER} done" || (f_log ERR "Build ${IMAGE_NAME}:${ALPINE_VER} failed"; exit 1)

