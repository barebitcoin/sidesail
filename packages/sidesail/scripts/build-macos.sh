set -e

app_name="$1"
# Check if exactly one argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 app_name"
    exit 1
fi

lower_app_name=$(echo "$app_name" | tr '[:upper:]' '[:lower:]')


echo Building $app_name

flutter build macos --dart-define-from-file=build-vars.env

zip_name=$lower_app_name-osx64.zip 
echo Zipping into $zip_name

old_cwd=$PWD
cd ./build/macos/Build/Products/Release 
ditto -c -k --sequesterRsrc --keepParent $app_name.app $zip_name

mkdir -p $old_cwd/release
cp $zip_name $old_cwd/release/
