#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <number_of_loops>"
  exit 1
fi

ACME_SRV="http://acme-srv.acme"
LOOPS=$1
UUID=$(uuidgen)

for ((i=1; i<=LOOPS; i++)); do
  DOMAIN="lego-$UUID-$i.acme"
  echo "Run $i: Requesting certificate for $DOMAIN"
  docker run -i -v /home/joern/data/lego-$UUID:/.lego/ --network acme --rm --name lego-$UUID goacme/lego --tls-skip-verify -s $ACME_SRV -a --email "lego@example.com" -d "$DOMAIN" --http run
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "docker run failed with exit code $RC. Stopping."
    exit $RC
  fi

  echo "Revoking certificate for $DOMAIN"
  docker run -i -v /home/joern/data/lego-$UUID:/.lego/ --network acme --rm --name lego-$UUID goacme/lego --tls-skip-verify -s $ACME_SRV -a --email "lego@example.com" -d "$DOMAIN" revoke
  RC=$?
  if [ $RC -ne 0 ]; then
    echo "docker revoke failed with exit code $RC. Stopping."
    exit $RC
  fi  


  sudo rm -rf /home/joern/data/lego-$UUID/*
done
