#!/bin/bash

# Inspiration for this script by Deniz Yilmaz 
# https://docs.digitalden.cloud/posts/create-fast-loading-images-with-lqip-webp-in-your-jekyll-chirpy-site/

# Credits:
# https://stackoverflow.com/questions/965053/extract-filename-and-extension-in-bash


Help(){
   # Display Help
   echo "Prepare your image for jekyll."
   echo
   echo "Syntax: jekyll-image.sh [-f|b|w|h]"
   echo
   echo "Example: ./jekyll-image.sh -f test.png -w -b"
   echo "Convert a .png to .webp file and print the jekyll lqip string."
   echo
   echo "options:"
   echo "-f     Enter the absolute file path of the image."
   echo "-b     Print the jekyll lqip base64 string."
   echo "-w     Convert a image file to a .webp file."
   echo "-h     Print this help text exit."
   echo
}

requirements(){
    # verify imagemagick is installed
    if ! command -v convert 2>&1 >/dev/null
    then
        echo "The command 'convert' could not be found."
        echo "First install 'imagemagick' to run this script."
        echo "For Debian/Ubunut run 'sudo apt-get install imagemagick'."
        exit 1
    fi
    # verify webp is installed
    if ! command -v cwebp 2>&1 >/dev/null
    then
        echo "The command 'cwebp' could not be found."
        echo "First install 'webp' to run this script."
        echo "For Debian/Ubunut run 'sudo apt-get install webp'."
        exit 1
    fi
}

remove(){
    read -p "Want to remove file '$input_file'? (y/n) [n]: " -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        rm $input_file
    fi
}

webp_to_base64(){
    convert $file -resize 20x20 -strip -quality 20 /dev/shm/tmp.webp
    echo "Jekyll Front Matter"
    echo
    base_string=$(base64 /dev/shm/tmp.webp)
    rm /dev/shm/tmp.webp
    echo "---"
    echo "lqip: data:image/webp;base64,$base_string"
    echo "---"
}

image_to_webp(){
    filename=$(basename -- "$file")
    filename="${filename%.*}"
    images="$(pwd)/assets/img/header/$filename.webp"

    echo "Converting to webp format..."
    if cwebp $file -o $images &>/dev/null; then 
        echo "Created file '$images'"
        input_file=$file
        file=$images
        remove
    else
        echo "Convert failed, check your input file."
        exit 1
    fi
}

# Get the options
while getopts ":hf:bw" option; do
   case $option in
      h) # display Help
         Help
         exit
         ;;
      f) # Enter a image file
         file=$OPTARG
         ;;
      b) # convert to lqip base64
         requirements
         webp_to_base64
         ;;
      w) # convert to webp
         requirements
         image_to_webp
         ;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit
         ;;
   esac
done
