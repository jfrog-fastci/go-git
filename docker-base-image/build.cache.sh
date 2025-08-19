docker build -f /home/yahavo/fastci/go-git/docker-base-image/Dockerfile.cache \
  --build-arg GO_VERSION=1.25.0 \
  -t cache-warmer:latest \
  /home/yahavo/fastci/go-git

echo "Finished build cache image"

CACHE_ROOT=/home/yahavo/fastci/go-git/docker-base-image/ci-cache
mkdir -p "$CACHE_ROOT/apt/archives" "$CACHE_ROOT/apt/lists" "$CACHE_ROOT/go-mod" "$CACHE_ROOT/go-build"

docker run --rm \
  -e PKGS="gettext libcurl4-openssl-dev" \
  -v /home/yahavo/fastci/go-git:/workspace \
  -v "$CACHE_ROOT/apt/archives":/var/cache/apt/archives \
  -v "$CACHE_ROOT/apt/lists":/var/lib/apt/lists \
  -v "$CACHE_ROOT/go-mod":/go/pkg/mod \
  -v "$CACHE_ROOT/go-build":/root/.cache/go-build \
  cache-warmer:latest
