aws s3 sync . s3://kevtown/games/zig-wasm/ --exclude "*" --include "*.html" --include "*.wasm" --include "*.png" --include "*.js" --include "*.css" --exclude "zig-cache/*" --exclude "node_modules/*" --acl public-read --cache-control max-age=60
