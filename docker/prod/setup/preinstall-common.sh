#!/bin/bash


set -e
set -o pipefail
ARCHITECTURE=arm64

# install node + npm
curl -s https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${ARCHITECTURE}.tar.gz | tar xzf - -C /usr/local --strip-components=1

wget --quiet -O- https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list

apt-get update -qq
apt-get install -y \
	apt-transport-https \
	pandoc \
	poppler-utils \
	unrtf \
	tesseract-ocr \
	catdoc \
	postgresql-9.6 \
	postgresql-client-9.6 \
	postgresql-13 \
	postgresql-client-13 \
	imagemagick

# remove any existing cluster
service postgresql stop
rm -rf /var/lib/postgresql/{9.6,13}

# Specifics for BIM edition
curl 'https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh' -o ./dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh -c 3.1

tmpdir=$(mktemp -d)
cd $tmpdir

# Install XKT converter
npm install @xeokit/xeokit-gltf-to-xkt@1.3.1 -g

# Install COLLADA2GLTF
wget --quiet https://github.com/KhronosGroup/COLLADA2GLTF/releases/download/v2.1.5/COLLADA2GLTF-v2.1.5-linux.zip
unzip -q COLLADA2GLTF-v2.1.5-linux.zip
mv COLLADA2GLTF-bin "/usr/local/bin/COLLADA2GLTF"

# IFCconvert
wget --quiet https://s3.amazonaws.com/ifcopenshell-builds/IfcConvert-v0.6.0-517b819-linux64.zip
unzip -q IfcConvert-v0.6.0-517b819-linux64.zip
mv IfcConvert "/usr/local/bin/IfcConvert"

wget --quiet https://github.com/bimspot/xeokit-metadata/releases/download/1.0.0/xeokit-metadata-linux-x64.tar.gz
tar -zxvf xeokit-metadata-linux-x64.tar.gz
chmod +x xeokit-metadata-linux-x64/xeokit-metadata
cp -r xeokit-metadata-linux-x64/ "/usr/lib/xeokit-metadata"
ln -s /usr/lib/xeokit-metadata/xeokit-metadata /usr/local/bin/xeokit-metadata

cd /
rm -rf $tmpdir

gem install bundler --version "$BUNDLER_VERSION" --no-document

useradd -d /home/$APP_USER -m $APP_USER
