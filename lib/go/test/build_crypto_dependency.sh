
#!/bin/bash

# the version of flow-go/crypto used for now is v0.23.3.
# till the script is automatized, the version is hardcoded.
VERSION="v0.23.3"

# go get the package
go get github.com/onflow/flow-go/crypto@8a4f9d6ce02b1d7fdd87da78ef6a1870188b58df

PKG_DIR="${GOPATH}/pkg/mod/github.com/onflow/flow-go/crypto@v0.24.3-0.20220203151650-a18137528dd0"

# grant permissions if not existant
if [[ ! -r ${PKG_DIR}  || ! -w ${PKG_DIR} || ! -x ${PKG_DIR} ]]; then
   sudo chmod -R 755 ${PKG_DIR}
fi

cd ${PKG_DIR}

go generate
