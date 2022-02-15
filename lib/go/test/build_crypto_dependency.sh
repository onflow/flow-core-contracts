
#!/bin/bash

# the version of flow-go/crypto used for now is v0.23.3.
# till the script is automatized, the version is hardcoded.
VERSION="c61d320eb5"

# go get the package
go get github.com/onflow/flow-go/crypto@${VERSION}

PKG_DIR="${GOPATH}/pkg/mod/github.com/onflow/flow-go/crypto@v0.24.3-0.20220214214245-c61d320eb56f"

# grant permissions if not existant
if [[ ! -r ${PKG_DIR}  || ! -w ${PKG_DIR} || ! -x ${PKG_DIR} ]]; then
   sudo chmod -R 755 ${PKG_DIR}
fi

cd ${PKG_DIR}

go generate
