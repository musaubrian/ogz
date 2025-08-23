#!/usr/bin/env bash

set -xe

mkdir -p ./vendor/SDL/lib
mkdir -p ./vendor/SDL/include

pushd "./vendor/SDL/SDL3/src/"
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
cmake --build .
cp ./libSDL3.a ../../lib/
popd

pushd "./vendor/SDL/SDL3_image/src"
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
cmake --build .
cp ./libSDL3_image.a ../../lib/
popd


pushd "./vendor/SDL/SDL3_ttf/src/"
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
cmake --build .
cp ./libSDL3_ttf.a ../../lib/
popd
