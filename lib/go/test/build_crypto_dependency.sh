
#!/bin/bash

# go get the package
go get github.com/onflow/flow-go/crypto

# the version of flow-go/crypto used for now is v0.18.0.
# till the script is automatized, the version is hardcoded.
VERSION="v0.18.0"
PKG_DIR="${GOPATH}/pkg/mod/github.com/onflow/flow-go/crypto@${VERSION}"

# grant permissions if not existant
if [[ ! -r ${PKG_DIR}  || ! -w ${PKG_DIR} || ! -x ${PKG_DIR} ]]; then
   sudo chmod -R 755 ${PKG_DIR}
fi

cd ${PKG_DIR}

# relic version or tag
relic_version="7a9bba7f"

rm -rf relic

# clone a specific version of Relic without history if it's tagged.
# git clone --branch $(relic_version) --single-branch --depth 1 git@github.com:relic-toolkit/relic.git

# clone all the history if the version is only defined by a commit hash.
git clone --branch main --single-branch https://github.com/relic-toolkit/relic.git
cd relic
git checkout $relic_version
cd ..

# build relic
bash relic_build.sh
