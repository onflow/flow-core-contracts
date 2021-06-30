
#!/bin/bash

go get github.com/onflow/flow-go/crypto
# the version of flow-go/crypto used for now is v0.18.0
# till the script is automatized, the version is hardcoded in the path
cd $GOPATH/pkg/mod/github.com/onflow/flow-go/crypto\@v0.18.0

# relic version or tag
relic_version="7a9bba7f"

rm -rf relic

# clone a specific version of Relic without history if it's tagged.
# git clone --branch $(relic_version) --single-branch --depth 1 git@github.com:relic-toolkit/relic.git

# clone all the history if the version is only defined by a commit hash.
git clone --branch main --single-branch git@github.com:relic-toolkit/relic.git
cd relic
git checkout $relic_version
cd ..

# build relic
bash relic_build.sh
