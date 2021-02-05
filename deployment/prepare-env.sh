#!/usr/bin/env bash
echo "+---------------------------------------+"
echo "| Using vendir to download carvel tools |"
echo "+---------------------------------------+"
vendir sync

echo "+------------------------+"
echo "| rename tools to ./bin/ |"
echo "+------------------------+"
mv bin/download_kapp/kapp-darwin-amd64 bin/kapp
chmod u+x bin/kapp
mv bin/download_kbld/kbld-darwin-amd64 bin/kbld
chmod u+x bin/kbld
mv bin/download_ytt/ytt-darwin-amd64 bin/ytt
chmod u+x bin/ytt
