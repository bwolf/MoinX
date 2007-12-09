#!/bin/sh
#
# $Id$
#
#  Copyright 2005 Marcus Geiger
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

if [ ! -d MoinX.xcodeproj ]; then
    echo Script must be called from the project root directory
    exit 64
fi

if [ ! -d generated ]; then
    echo "You have to run bootstrap before this ($0)"
    exit 64
fi

size=15m
base=generated/release
dmg=$base/MoinX.dmg
i_dmg=$base/MoinX_image.dmg

mkdir $base
rm -f $dmg
rm -f $i_dmg
hdiutil create -size $size -fs HFS+ -volname MoinX -ov $i_dmg
hdiutil mount $i_dmg
ditto build/Release/MoinX.app /Volumes/MoinX/MoinX.app
hdiutil eject /Volumes/MoinX
hdiutil convert -format UDZO -o $dmg $i_dmg
hdiutil internet-enable -yes $dmg
rm $i_dmg

echo ""
echo "###############################################################"
echo ""
echo Look at $base for the DMG and rename it to the release version.
