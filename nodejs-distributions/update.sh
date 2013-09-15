#!/bin/sh

# Updates nodejs-distributions to the given nodejs version.
# requires: sh, curl, tar (only tested on macOS).

# IMPORTANT NOTE: this script does some removal of directories. Handle with care!

NODEJS_VERSION=$1

DOWNLOAD_URL_PREFIX="http://nodejs.org/dist/v$NODEJS_VERSION"

NPM_URL_PREFIX="http://nodejs.org/dist/npm"

function error_exit
{
	echo "$1" 1>&2
	exit 1
}


## Downloads nodejs and extracts it into the current directory
downloadNodeJs(){
  local platform=$1

  local filename="node-v$NODEJS_VERSION-$platform"
  local downloadUrl="$DOWNLOAD_URL_PREFIX/$filename.tar.gz"
  echo "downloading $downloadUrl"
  rm -f temp_tar
  mkdir temp_tar
  cd temp_tar
  curl -# -f -o nodejs.tar.gz $downloadUrl || error_exit "Error while downloading $downloadUrl"

  echo "Extracting and re-tarring.."

  # Sadly, all nodejs .tar.gz files include a platform-version specific directory.
  # So we remove that here by re-tarring the file
  tar zxf nodejs.tar.gz || error_exit "Error while extracting downloaded nodejs file"
  rm nodejs.tar.gz || error_exit "Could not clean up downloaded tar.gz file"
  # remove subdirectory added by .tar.gz file and make a new tar
  cp -R $filename/ . || error_exit "Error while removing subdirectory created by downloaded file"
  rm -Rf $filename
  tar -pczf ../nodejs.tar.gz * || error_exit "Could not recreate tar.gz for $platform"
  cd ..
  rm -Rf temp_tar
}

## A non-MSI distribution of node for Windows is only available as a single node.exe file
downloadAndExtractNodeJsWindows(){
  local platform=$1

  local downloadUrl="$DOWNLOAD_URL_PREFIX/node.exe"
  if [ "$platform" == "win-x64" ]
  then
    downloadUrl="$DOWNLOAD_URL_PREFIX/x64/node.exe"
  fi

  echo "downloading node.exe $downloadUrl"
  mkdir bin
  curl -# -f -o bin/node.exe $downloadUrl || error_exit "Error while downloading $downloadUrl"
}

# download separate npm distribution and append it to the windows dists and create tar.gz from it
appendNpmToWindowsDirs() {
  # first, determine which NPM version is used
  rm -Rf nodejs_tmp
  mkdir nodejs_tmp
  cd nodejs_tmp || error_exit "Error creating/changing to nodejs temporary directory"
  tar zxf ../linux-x64/nodejs.tar.gz --strip=3 '*/npm/package.json' || error_exit "Error while extracting nodejs to find out which NPM version to download"
  local npmVersion=`cat package.json | grep -o '"version":.*,' | sed -n 's/.*"version": "\(.*\)",/\1/p'`
  cd ..
  rm -Rf nodejs_tmp

  local npmDownloadUrl="$NPM_URL_PREFIX/npm-$npmVersion.zip"
  echo "downloading NPM $npmVersion from $npmDownloadUrl"
  curl -# -f -o npm.zip $npmDownloadUrl || error_exit "Error while downloading $downloadUrl" || error_exit "Could not download NPM"

  for windowsDistDir in "$@"
  do
    echo "creating node+NPM distributions in for $windowsDistDir"
    unzip -qo npm.zip -d $windowsDistDir/bin || error_exit "Could not extract downloaded NPM zip to $windowsDistDir"
    # create gzip file
    tar -pczf nodejs.tar.gz $windowsDistDir || error_exit "Could not create tar.gz for $windowsDistDir"
    rm -Rf $windowsDistDir/* || error_exit "Could not empty $windowsDistDir"
    cp nodejs.tar.gz $windowsDistDir || error_exit "Could not copy generated nodejs dist to $windowsDistDir"
    rm nodejs.tar.gz || error_exit "Could not clean up generated nodejs.tar.gz for $windowsDistDir"
  done
  rm npm.zip || error_exit "Could not delete downloaded NPM zip file"
}

# enter a dist subdir, clear contents and download & extract nodejs into it
updateDistDirectory() {
  local directory=$1
  local platform=$2

  cd $1 || error_exit "Could not change to $directory"
  rm -Rf * || error_exit "Could not delete contents of directory $directory"

  if [[ "$platform" == win* ]]; then
    downloadAndExtractNodeJsWindows $platform
  else
    downloadNodeJs $platform
  fi

  cd ..
}

if [ -z "$1" ]
  then
    error_exit "Please supply a nodejs version to download"
fi

updateDistDirectory "macos-x86" "darwin-x86"
updateDistDirectory "macos-x64" "darwin-x64"

updateDistDirectory "linux-x86" "linux-x86"
updateDistDirectory "linux-x64" "linux-x64"

updateDistDirectory "win-x86" "win-x86"
updateDistDirectory "win-x64" "win-x64"

appendNpmToWindowsDirs "win-x64" "win-x86"

echo "finished!"

