#!/bin/bash

set -e

if [ "$(uname)" = "Linux" ]; then
    OPEN=xdg-open;
elif [ "$(uname)" = "Darwin" ]; then
    OPEN=open;
else
    printf "Not running on Mac or Linux, aborting"
    exit 1
fi

if [ -z "$CHROME_WEBSTORE_CLIENT_SECRET" ]; then
    printf "Missing env CHROME_WEBSTORE_CLIENT_SECRET; check the infrastructure repository"
    exit 1
fi

app_id="dgjhfomjieaadpoljlnidmbgkdffpack"
client_id="527047051561-0vr4iah44ftj7ovd0cg3kk03hou5ggp0.apps.googleusercontent.com"
client_secret="$CHROME_WEBSTORE_CLIENT_SECRET"

$OPEN "https://accounts.google.com/o/oauth2/auth?response_type=code&scope=https://www.googleapis.com/auth/chromewebstore&client_id=$client_id&redirect_uri=urn:ietf:wg:oauth:2.0:oob"
read -p "Follow the web prompt and enter your code: " code

printf "Generating access token...\n"
access_token_response=$(curl -s "https://accounts.google.com/o/oauth2/token" -d "client_id=$client_id&client_secret=$client_secret&code=$code&grant_type=authorization_code&redirect_uri=urn:ietf:wg:oauth:2.0:oob")
access_token=$(echo $access_token_response | awk '{ print $4 }' | sed 's/,//g' | sed 's/\"//g') # remove quote and comma

if [ -z "$access_token" ]; then
    printf "FAILURE:\n$access_token_response\n"
    exit 1
fi

printf "Uploading bundle...\n\n"
echo $CHROME_BUNDLE
upload_response=$(curl -s -H "Authorization: Bearer $access_token" -H "x-goog-api-version: 2" -X PUT -T $CHROME_BUNDLE -v "https://www.googleapis.com/upload/chromewebstore/v1.1/items/$app_id")
printf "\n\n"

if [ -n "$(echo "$upload_response" | grep FAILURE)" ]; then
    printf "FAILURE:\n$upload_response\n"
    exit 1
fi

publish_response=$(curl -H "Authorization: Bearer $access_token" -H "x-goog-api-version: 2" -H "Content-Length: 0" -X POST -v "https://www.googleapis.com/chromewebstore/v1.1/items/$app_id/publish")

printf "Check to make sure that the Chrome developer dashboard has the version of the chrome extension you just uploaded (it may be listed as a DRAFT for a couple minutes before becoming the main version)"
$OPEN "https://chrome.google.com/webstore/developer/dashboard"

