/bin/env bash

MIX_ENV=prod mix phx.gen.release
docker build -t spyfall-1 .
docker run -e PORT=8080 -e PHX_HOST=localhost -e SECRET_KEY_BASE="iYYX2c1Fwd/YumX3Ajf9NSEQMiyi4XOIcWx/80q59uEUGIx8vqZMepyAezBolLgB" -p 8080:8080 -it spyfall-1
