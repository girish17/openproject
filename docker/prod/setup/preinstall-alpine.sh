#!/bin/bash
set -euxo pipefail

get_architecture() {
	if command -v uname > /dev/null; then
		ARCHITECTURE=$(uname -m)
		case $ARCHITECTURE in
			aarch64|arm64)
				echo "arm64"
				return 0
				;;
			ppc64le)
				echo "ppc64le"
				return 0
				;;
		esac
	fi

	echo "x64"
	return 0
}

set -exo pipefail
ARCHITECTURE=$(get_architecture)

apk add --no-cache \
	curl \
	wget \
	file \
	gnupg \
	bash \
	git \
	build-base \
	libffi-dev \
	libpq-dev \
	yaml-dev \
	nodejs \
	npm \
	tzdata \
	poppler-utils \
	imagemagick \
	jemalloc \
	unrtf \
	tesseract-ocr \
 perl

apk add postgresql-client

if [ "${BIM_SUPPORT:-true}" != "false" ]; then
	apk add --no-cache wget unzip

	tmpdir=$(mktemp -d)
	cd $tmpdir

	npm install -g @xeokit/xeokit-gltf-to-xkt@1.3.1

	wget --no-verbose --tries 3 https://github.com/KhronosGroup/COLLADA2GLTF/releases/download/v2.1.5/COLLADA2GLTF-v2.1.5-linux.zip
	unzip -q COLLADA2GLTF-v2.1.5-linux.zip
	mv COLLADA2GLTF-bin "/usr/local/bin/COLLADA2GLTF"

	wget --no-verbose --tries 3 https://s3.amazonaws.com/ifcopenshell-builds/IfcConvert-v0.7.11-fea8e3a-linux64.zip
	unzip -q IfcConvert-v0.7.11-fea8e3a-linux64.zip
	mv IfcConvert "/usr/local/bin/IfcConvert"

	wget --no-verbose --tries 3 https://github.com/opf/xeokit-metadata/releases/download/v1.1.0/xeokit-metadata-linux-x64.tar.gz
	tar -zxvf xeokit-metadata-linux-x64.tar.gz
	chmod +x xeokit-metadata-linux-x64/xeokit-metadata
	cp -r xeokit-metadata-linux-x64/ "/usr/lib/xeokit-metadata"
	ln -s /usr/lib/xeokit-metadata/xeokit-metadata /usr/local/bin/xeokit-metadata

	cd /
	rm -rf $tmpdir
fi

rm -rf /var/cache/apk/* /tmp/* /var/tmp/*