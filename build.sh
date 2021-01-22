#!/usr/bin/env bash

#getopts setup
OPTIND=1

multiple=false
trim=false
crop=false
fold=false

while getopts "mtcf" opt; do
    case "$opt" in
    m)  multiple=true
        ;;
    t)  trim=true
        ;;
    c)  crop=true
        ;;
    f)  fold=true
        ;;
    esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

# cleaning build and dist
rm -rf ./build/
rm -rf ./dist/
mkdir build
mkdir dist

# adding xmp
cp ./src/license.xmp ./build/
sed -i 's/© DXC Technology Company XXXX/© DXC Technology Company '"$(date +%Y)"'/' ./build/license.xmp
cp ./src/attribution.xmp ./build/

# crops and trims
echo starting crops and trims
cp -r ./src/*.svg build/
mkdir build/crops
echo converting single crop mark svg to pdf
inkscape -T --export-pdf=./build/crops/cards-crop.pdf ./build/cards-crop.svg &>/dev/null
exiftool -tagsfromfile ./build/license.xmp -tagsfromfile ./build/attribution.xmp ./build/crops/cards-crop.pdf -overwrite_original &>/dev/null
echo converting rules crop mark svg to pdf
inkscape -T --export-pdf=./build/crops/rules-crop.pdf ./build/rules-crop.svg &>/dev/null
exiftool -tagsfromfile ./build/license.xmp -tagsfromfile ./build/attribution.xmp ./build/crops/rules-crop.pdf -overwrite_original &>/dev/null
mkdir build/trims
echo converting single trim line svg to pdf
inkscape -T --export-pdf=./build/trims/cards-trim.pdf ./build/cards-trim.svg &>/dev/null
exiftool -tagsfromfile ./build/license.xmp -tagsfromfile ./build/attribution.xmp ./build/trims/cards-trim.pdf -overwrite_original &>/dev/null
echo converting rules trim line svg to pdf
inkscape -T --export-pdf=./build/trims/rules-trim.pdf ./build/rules-trim.svg &>/dev/null
exiftool -tagsfromfile ./build/license.xmp-tagsfromfile ./build/attribution.xmp ./build/trims/rules-trim.pdf -overwrite_original &>/dev/null
if [ $multiple = true ]
then
  echo duplexing with multiple trim lines per page
  pdfjam ./build/trims/cards-trim.pdf ./build/trims/cards-trim.pdf ./build/trims/cards-trim.pdf ./build/trims/cards-trim.pdf --nup 2x2 --a4paper --noautoscale true --outfile ./build/trims/cards-trim-2x2.pdf &>/dev/null
  exiftool -tagsfromfile ./build/license.xmp -tagsfromfile ./build/attribution.xmp ./build/trims/cards-trim-2x2.pdf -overwrite_original &>/dev/null
fi
mkdir build/folds
echo converting box fold lines svg to pdf
inkscape -T --export-pdf=./build/folds/tuck_box-fold.pdf ./build/tuck_box-fold.svg &>/dev/null
exiftool -tagsfromfile ./build/license.xmp-tagsfromfile ./build/attribution.xmp ./build/folds/tuck_box-fold.pdf -overwrite_original &>/dev/null
echo converting box trim lines svg to pdf
inkscape -T --export-pdf=./build/trims/tuck_box-trim.pdf ./build/tuck_box-trim.svg &>/dev/null
exiftool -tagsfromfile ./build/license.xmp-tagsfromfile ./build/attribution.xmp ./build/trims/tuck_box-trim.pdf -overwrite_original &>/dev/null

# cards
echo starting cards
cp -r ./src/cards build/
for cardtype in ./build/cards/*
do
  for card in $cardtype/*
  do
    echo converting $(basename $cardtype) $(basename $card) svg to pdf
    for side in $card/*
    do
      inkscape -T --export-pdf="${side%.*}.pdf" $side &>/dev/null
      if [ $crop = true ]
      then
        echo stamping crop marks
        java -jar lib/pdftk-all.jar "${side%.*}.pdf" stamp ./build/crops/cards-crop.pdf output "${side%.*}-crop.pdf"
        rm "${side%.*}.pdf"
        mv "${side%.*}-crop.pdf" "${side%.*}.pdf"
      fi
      if [ $trim = true ]
      then
        echo stamping trim lines
        java -jar lib/pdftk-all.jar "${side%.*}.pdf" stamp ./build/trims/cards-trim.pdf output "${side%.*}-trim.pdf"
        rm "${side%.*}.pdf"
        mv "${side%.*}-trim.pdf" "${side%.*}.pdf"
      fi
    done
    if [ $multiple = false ]
    then
      echo duplexing singles
      java -jar lib/pdftk-all.jar $card/a.pdf $card/b.pdf cat output $cardtype/$(basename $card).pdf
    fi
  done
  if [ $multiple = true ]
  then
    echo duplexing with multiple cards per page
    let folderCount=$(ls -ld $cardtype/*/ | wc -l)
    let remainder=$(($folderCount % 4))
    for (( i=1; i<=($folderCount - $remainder); i+=4))
    do
      echo laying out $cardtype/$i-$(($i+1))-$(($i+2))-$(($i+3)) for duplex
      pdfjam $cardtype/$i/a.pdf $cardtype/$(($i+1))/a.pdf $cardtype/$(($i+2))/a.pdf $cardtype/$(($i+3))/a.pdf --nup 2x2 --a4paper --noautoscale true --outfile $cardtype/$i-$(($i+1))-$(($i+2))-$(($i+3))-a.pdf &>/dev/null
      pdfjam $cardtype/$(($i+1))/b.pdf $cardtype/$i/b.pdf $cardtype/$(($i+3))/b.pdf $cardtype/$(($i+2))/b.pdf --nup 2x2 --a4paper --noautoscale true --outfile $cardtype/$i-$(($i+1))-$(($i+2))-$(($i+3))-b.pdf &>/dev/null
    done
    for (( i=($folderCount - $remainder + 1); i<=$folderCount; i++))
    do
      echo duplexing single remainders
      java -jar lib/pdftk-all.jar $cardtype/$i/a.pdf $cardtype/$i/b.pdf cat output $cardtype/$i.pdf
    done
  fi
  echo merging $(basename $cardtype) pages
  java -jar lib/pdftk-all.jar $(ls -v $cardtype/*.pdf | xargs) cat output "./build/$(basename $cardtype).pdf"
  exiftool -tagsfromfile ./build/license.xmp -tagsfromfile ./build/attribution.xmp "./build/$(basename $cardtype).pdf" -overwrite_original &>/dev/null
done

# rules
echo starting rules
cp -r ./src/rules build/
sed -i 's/© DXC Technology Company XXXX/© DXC Technology Company '"$(date +%Y)"'/' ./build/rules/b.svg
for rule in ./build/rules/*
do
  echo converting rule svg to pdf
  inkscape -T --export-pdf="${rule%.*}.pdf" $rule &>/dev/null
  if [ $crop = true ]
  then
    echo stamping crop marks
    java -jar lib/pdftk-all.jar "${rule%.*}.pdf" stamp ./build/crops/rules-crop.pdf output "${rule%.*}-crop.pdf"
    rm "${rule%.*}.pdf"
    mv "${rule%.*}-crop.pdf" "${rule%.*}.pdf"
  fi
  if [ $trim = true ]
  then
    echo stamping trim lines
    java -jar lib/pdftk-all.jar "${rule%.*}.pdf" stamp ./build/trims/rules-trim.pdf output "${rule%.*}-trim.pdf"
    rm "${rule%.*}.pdf"
    mv "${rule%.*}-trim.pdf" "${rule%.*}.pdf"
  fi
done
echo merging rules pages
java -jar lib/pdftk-all.jar $(ls -v ./build/rules/*.pdf | xargs) cat output ./build/rules.pdf
exiftool -tagsfromfile ./build/license.xmp -tagsfromfile ./build/attribution.xmp ./build/rules.pdf -overwrite_original &>/dev/null

# box
echo starting box
cp -r ./src/box ./build/
sed -i 's/© DXC Technology Company XXXX/© DXC Technology Company '"$(date +%Y)"'/' ./build/box/tuck_box.svg
inkscape -T --export-pdf=./build/box/tuck_box.pdf ./build/box/tuck_box.svg &>/dev/null
if [ $fold = true ]
then
  echo stamping fold lines
  java -jar lib/pdftk-all.jar ./build/box/tuck_box.pdf stamp ./build/folds/tuck_box-fold.pdf output ./build/box/tuck_box-fold.pdf
  rm ./build/box/tuck_box.pdf
  mv ./build/box/tuck_box-fold.pdf ./build/box/tuck_box.pdf
fi
if [ $trim = true ]
then
  echo stamping trim lines
  java -jar lib/pdftk-all.jar ./build/box/tuck_box.pdf stamp ./build/trims/tuck_box-trim.pdf output ./build/box/tuck_box-trim.pdf
  rm ./build/box/tuck_box.pdf
  mv ./build/box/tuck_box-trim.pdf ./build/box/tuck_box.pdf
fi
exiftool -tagsfromfile ./build/license.xmp -tagsfromfile ./build/attribution.xmp ./build/box/tuck_box.pdf -overwrite_original &>/dev/null
mv ./build/box/tuck_box.pdf ./build/

echo copying to dist
cp ./build/*.pdf ./dist/
cp -r ./build/crops ./dist/
cp -r ./build/trims ./dist/
cp -r ./build/folds ./dist/

# packaging
cp ./LICENSE ./dist/
cp ./license.html ./dist/
cp ./RULES.md ./dist/
cp ./INSTRUCTIONS.md ./dist/

cd ./dist
echo creating zip
if [ $multiple = false ]
then
  zip ThreatDeck.zip *.pdf crops/* trims/* folds/* LICENSE license.html RULES.md INSTRUCTIONS.md &>/dev/null
else
  zip "ThreatDeck (2x2).zip" *.pdf crops/* trims/* folds/* LICENSE license.html RULES.md INSTRUCTIONS.md &>/dev/null
fi
rm *.pdf
rm -rf crops
rm -rf trims
rm -rf folds
rm LICENSE
rm license.html
rm RULES.md
rm INSTRUCTIONS.md
cd ..
