#!/bin/bash
#
# Build librdkafka on a bare-bone Debian host, such as the
# mcr.microsoft.com/dotnet/sdk Docker image.
#
# Statically linked
# WITH openssl 1.0, zlib
# WITHOUT libsasl2, lz4(ext, using builtin instead)
#
# Usage (from top-level librdkafka dir):
#   docker run -it -v $PWD:/v mcr.microsoft.com/dotnet/sdk /v/packaging/tools/build-debian.sh /v /v/librdkafka-debian9.tgz
#


set -ex

LRK_DIR=$1
shift
OUT_TGZ=$1
shift
CONFIG_ARGS=$*

if [[ ! -f $LRK_DIR/configure.self || -z $OUT_TGZ ]]; then
    echo "Usage: $0 <librdkafka-root-direcotry> <output-tgz> [<configure-args..>]"
    exit 1
fi

set -u

apt-get update
apt-get install -y gcc g++ zlib1g-dev python3 git-core make


# Copy the librdkafka git archive to a new location to avoid messing
# up the librdkafka working directory.

BUILD_DIR=$(mktemp -d)

pushd $BUILD_DIR

DEST_DIR=$PWD/dest
mkdir -p $DEST_DIR

# Workaround for newer Git not allowing clone directory to be owned by
# another user (which is a questionable limitation for the read-only archive
# command..)
git config --global --add safe.directory /v

(cd $LRK_DIR ; git archive --format tar HEAD) | tar xf -

./configure --install-deps --disable-gssapi --disable-lz4-ext --enable-static --prefix=$DEST_DIR $CONFIG_ARGS
make -j
examples/rdkafka_example -X builtin.features
CI=true make -C tests run_local_quick
make install

# Tar up the output directory
pushd $DEST_DIR
ldd lib/*.so.1
tar cvzf $OUT_TGZ .
popd # $DEST_DIR

popd # $BUILD_DIR

rm -rf "$BUILD_DIR"
