#!/bin/bash

BUILD_DIR='build/a2c'
USER=$(whoami)
REPO='repo'
REPO_FULL="https://github.com/$USER/$REPO.git"
BRANCH=$1
DOCKERHUB_USER=user
DOCKERHUB_TOKEN=token
UUID=$(uuidgen | cut -d "-" -f1)


sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get -y install build-essential fakeroot dpkg-dev devscripts debhelper  --allow-downgrades

# clone branch
git clone -b $BRANCH $REPO_FULL $BUILD_DIR

cd $BUILD_DIR
TAG_NAME=$(cat acme_srv/version.py | grep -i __version__ | head -n 1 | sed 's/__version__ = //g' | sed s/\"//g) >> $GITHUB_ENV
rm setup.py
rm -f examples/ngnix/acme2certifier.te
rm -f examples/nginx/supervisord.conf
rm -f examples/nginx/uwsgi.service
sed -i "s/run\/uwsgi\/acme.sock/var\/www\/acme2certifier\/acme.sock/g" examples/nginx/nginx_acme_srv.conf
sed -i "s/run\/uwsgi\/acme.sock/var\/www\/acme2certifier\/acme.sock/g" examples/nginx/nginx_acme_srv_ssl.conf
sed -i "s/\/run\/uwsgi\/acme.sock/acme.sock/g" examples/nginx/acme2certifier.ini
sed -i "s/nginx/www-data/g" examples/nginx/acme2certifier.ini
echo "plugins=python3" >> examples/nginx/acme2certifier.ini
cat <<EOT > examples/nginx/acme2certifier.service
[Unit]
Description=uWSGI instance to serve acme2certifier
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=/var/www/acme2certifier
Environment="PATH=/var/www/acme2certifier"
ExecStart=uwsgi --ini /var/www/acme2certifier/acme2certifier.ini

[Install]
WantedBy=multi-user.target
EOT
cp -R examples/install_scripts/debian ./
sudo sed -i "s/__version__/$TAG_NAME/g" debian/changelog
cd ../
tar cvfz ../acme2certifier_$TAG_NAME.orig.tar.gz ./

cd a2c
dpkg-buildpackage -uc -us
dpkg -c ../acme2certifier_$TAG_NAME-1_all.deb
cp ../acme2certifier_$TAG_NAME-1_all.deb ./

# cat examples/Docker/apache2/wsgi/Dockerfile | docker build -t grindsa/acme2certifier:$BRANCH -f - . --no-cache
docker buildx create --name multi-arch \
--platform "linux/arm64,linux/amd64" \
--driver "docker-container"
docker buildx use multi-arch
docker login -u $DOCKERHUB_USER -p $DOCKERHUB_TOKEN
cat examples/Docker/apache2/wsgi/Dockerfile | docker buildx build --platform linux/amd64,linux/arm64 -t grindsa/acme2certifier:$BRANCH -f - . --no-cache --push
# cat examples/Docker/apache2/django/Dockerfile | docker buildx build --platform linux/amd64,linux/arm64 -t grindsa/acme2certifier:$BRANCH -f - . --no-cache --push
# cat examples/Docker/nginx/wsgi/Dockerfile | docker buildx build --platform linux/amd64,linux/arm64 -t grindsa/acme2certifier:$BRANCH -f - . --no-cache --push

docker login -u $DOCKERHUB_USER -p $DOCKERHUB_TOKEN
docker push -a $REPO_FULL

cd ~
rm -rf $BUILD_DIR
