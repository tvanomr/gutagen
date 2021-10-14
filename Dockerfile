FROM buildpack-deps:buster-scm

ENV GOLANG_VERSION=1.17.2 GOSU_VERSION=1.14 GOPATH=/home/executor/go GOROOT=/usr/local/go USER_ID=${USER_ID:-1000} GROUP_ID=${GROUP_ID:-1000}
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

RUN set -eux; \
	# save list of currently installed packages for later so we can clean up
	#	savedAptMark="$(apt-mark showmanual)"; \
	apt-get -q update \
	&& apt-get -q install -y --no-install-recommends \
	wget \
	g++ \
	gcc \
	#	build-essential \
	libc6-dev \
	make \
	gnupg2 \
	dirmngr \
	git \
	ca-certificates\
	pkg-config \
	&& rm -rf /var/lib/apt/lists/*; 

RUN	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -q -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -q -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
	&& mkdir -p "$GOPATH/src" "$GOPATH/bin" \
	&& update-ca-certificates ; \
	# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	command -v gpgconf && gpgconf --kill all || :; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
	&& chmod +x /usr/local/bin/gosu \
	# verify that the binary works
	&& gosu --version \
	&& gosu nobody true ;\
	case "${dpkgArch##*-}" in \
	amd64) goRelArch='linux-amd64'; goRelSha256='f242a9db6a0ad1846de7b6d94d507915d14062660616a61ef7c808a76e4f1676' ;; \
	armhf) goRelArch='linux-armv6l'; goRelSha256='04d16105008230a9763005be05606f7eb1c683a3dbf0fbfed4034b23889cb7f2' ;; \
	arm64) goRelArch='linux-arm64'; goRelSha256='a5a43c9cdabdb9f371d56951b14290eba8ce2f9b0db48fb5fc657943984fd4fc' ;; \
	i386) goRelArch='linux-386'; goRelSha256='8617f2e40d51076983502894181ae639d1d8101bfbc4d7463a2b442f239f5596' ;; \
	ppc64el) goRelArch='linux-ppc64le'; goRelSha256='12e2dc7e0ffeebe77083f267ef6705fec1621cdf2ed6489b3af04a13597ed68d' ;; \
	s390x) goRelArch='linux-s390x'; goRelSha256='c4b2349a8d11350ca038b8c57f3cc58dc0b31284bcbed4f7fca39aeed28b4a51' ;; \
	*) goRelArch='src'; goRelSha256='2255eb3e4e824dd7d5fcdc2e7f84534371c186312e546fb1086a34c17752f431'; \
	echo >&2; echo >&2 "warning: current architecture ($dpkgArch) does not have a corresponding Go binary release; will be building from source"; echo >&2 ;; \
	esac; \
	\
	url="https://golang.org/dl/go${GOLANG_VERSION}.${goRelArch}.tar.gz"; \
	wget -q -O go.tgz "$url"; \
	echo "${goRelSha256} *go.tgz" | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	if [ "$goRelArch" = 'src' ]; then \
	echo >&2; \
	echo >&2 'error: UNIMPLEMENTED'; \
	echo >&2 'TODO install golang-any from buster-backports for GOROOT_BOOTSTRAP (and uninstall after build)'; \
	echo >&2; \
	exit 1; \
	fi; \
	\
	export PATH="$GOPATH/bin:$GOROOT/bin:$PATH"; \
	go version


COPY . "$GOPATH/src/github.com/tvanomr/gutagen"
#USER executor
WORKDIR $GOPATH 
RUN cd "$GOPATH/src/github.com/tvanomr/gutagen" \
	&& chmod -R 755 /home/executor/ \
	&& chmod -R 750 "$GOPATH" \
	&& rm -rf Jenkinsfile Dockerfile 

RUN	cd "$GOPATH/src/github.com/tvanomr/gutagen" && go get -v all
RUN cd "$GOPATH/src/github.com/tvanomr/gutagen" && go vet ./...
RUN cd "$GOPATH/src/github.com/tvanomr/gutagen" && go install ./...

EXPOSE 24443
ENTRYPOINT ["/home/executor/go/bin/gutagen","port","24433"]
