#!/usr/bin/env bash

uglifyjs ./javascripts/codemirror.js \
        ./javascripts/continuelist.js \
        ./javascripts/fullscreen.js \
        ./javascripts/gfm.js \
        ./javascripts/markdown.js \
        ./javascripts/marked.js \
        ./javascripts/overlay.js \
        ./javascripts/search.js \
        ./javascripts/search-cursor.js \
        ./javascripts/tablist.js \
        ./javascripts/xml.js \
        ./javascripts/init.js \
        -o ./javascripts/markdown.min.js

echo "Successed!!!!"