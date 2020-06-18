#!/usr/bin/env bash

# Exit script as soon as a command fails.
set -o errexit

# Executes cleanup function at script exit.
trap cleanup EXIT

# get current directory
PWD=$(pwd)

cleanup() {
  echo "Cleaning up"
  pkill -f ganache-cli
  cd $PWD/test-blockchain
  bash stop-docker.sh
  bash clean.sh
  cd ..
  echo "Done"
}

start_testrpc() {
  npm run testrpc > /dev/null &
}

start_blockchain() {
  cd $PWD/test-blockchain
  bash run-docker.sh
  cd ..
}


echo "Starting our own testrpc instance"
start_testrpc

echo "Starting our own bor instance"
start_blockchain

# process templates
npm run template:process

# migrate contracts
npm run migrate "$@"

if [ "$SOLIDITY_COVERAGE" = true ]; then
  npm run truffle:coverage "$@"
else
  npm run test "$@"
fi
