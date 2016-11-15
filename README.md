# POSM Imagery API

This is the POSM Imagery API. It does a few things:

* ingests GeoTIFFs (and probably other GDAL-supported formats, though it currently looks for `.tif`
  and `.tiff` extensions) using HTTP multipart uploads and via the [tus.io](http://tus.io/) protocol
  for resumable uploads.
* creates overviews and associated metadata to facilitate tiling
* tiles imagery on-demand
* creates MBTiles archives for individual images (and should do the same for imagery sets)

## Running

First, start `redis-server` so that Docker containers can access it (so that Celery can use it as a
broker and result backend and so that Flask-Tus can track uploads):

```bash
redis-server --bind 0.0.0.0
```

This runs `gunicorn` under the hood (using the default Docker `ENTRYPOINT`).

```bash
# get the host IP on OS X (wired, then wireless)
ip=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
docker run \
  -it \
  --rm \
  -e WEB_CONCURRENCY=8 \
  -e REDIS_URL="redis://${ip}/" \
  -v $(pwd)/imagery:/app/imagery \
  -v $(pwd)/uploads:/app/uploads \
  -p 8000:8000 \
  imagery-api
```

This overrides the default `ENTRYPOINT` and starts the Celery daemon to run workers instead. Note
that the `imagery` and `uploads` volumes are shared between containers.

```bash
# get the host IP on OS X (wired, then wireless)
ip=$(ipconfig getifaddr en0 || ipconfig getifaddr en1)
docker run \
  -it \
  --rm \
  -e REDIS_URL="redis://${ip}/" \
  -v $(pwd)/imagery:/app/imagery \
  -v $(pwd)/uploads:/app/uploads \
  --entrypoint celery \
  imagery-api \
  worker \
  -A app.celery \
  --loglevel=info
```

## Developing

You can either run a development copy with `docker-compose`:

```bash
docker-compose up
```

...or you can develop against a local copy. To set up, create a `virtualenv`, install the
dependencies, and start up the API server and Celery workers. You'll also need a local Redis server.

Create a `virtualenv` and install dependencies:

```bash
virtualenv venv
source venv/bin/activate
pip install -U numpy # install this first so rasterio doesn't complain
pip install -Ur requirements.txt
npm install
```

Start the API server:

```bash
source venv/bin/activate
python app.py
```

Start the Celery workers:

```bash
source venv/bin/activate
venv/bin/celery worker -A app.celery --loglevel=info
```

To start Redis:

```bash
redis-server
```

## API Endpoints

To see an up-to-date list of API endpoints (and supported methods), run `python manage.py
list_routes`.

* `GET /imagery` - List available imagery.
* `GET /imagery/<id>` - Get metadata for an image.
* `GET /imagery/<id>/<z>/<x>/<y>[@2x].png` - Tile endpoint for an image.
* `GET /imagery/<id>/ingest/status` - Check on the ingestion status for an image.
* `GET /imagery/<id>/mbtiles` - Download the MBTiles archive for an image (if available).
* `POST /imagery/<id>/mbtiles` - Request creation of an MBTiles archive.
* `GET /imagery/<id>/mbtiles/status` - Check on the status of MBTiles creation.
* `PUT /imagery/upload` - Upload imagery. Requires the image to be the `file` value of a
  `multipart/form-data` payload. E.g., `curl -X PUT -F "file=@image.tif"
  http://localhost:8000/imagery/upload`
* `POST /imagery/upload` - [tus.io](https://tus.io/) upload endpoint.

## Environment Variables

* `APPLICATION_ROOT` - Optional application prefix. Defaults to ``.
* `IMAGERY_PATH` - Where to store imagery on the filesystem. Must be accessible by both the API
  server and Celery workers. Defaults to `imagery` (relative to the current working directory).
* `UPLOADED_IMAGERY_DEST` - Where to (temporarily) store uploaded imagery. Must be accessible by
  both the API server and Celery workers. Defaults to `uploads/` (relative to the current working
  directory).
* `MIN_ZOOM` - Minimum zoom served up by the tile server. Defaults to `0`.
* `MAX_ZOOM` - Maximum zoom served up by the tile server. Defaults to `22`.
* `CELERY_BROKER_URL` - Celery broker URL. Defaults to the value of `REDIS_URL`.
* `CELERY_DEFAULT_QUEUE` - Default queue name. Defaults to `posm-imagery-api`.
* `CELERY_RESULT_BACKEND` - Celery result backend URL. Defaults to the value of `REDIS_URL`.
* `REDIS_URL` - Flask-Tus backend. Defaults to `redis://` (`localhost`, default port, default
  database).
* `SERVER_NAME` - Local server name, for use when generating MBTiles. Defaults to `localhost:8000`.
* `USE_X_SENDFILE` - Whether Flask should use `X-Sendfile` to defer file serving to a proxying web
  server (this requires that the web server and API server are running on the same "server", so
  Docker won't work). Defaults to `False`.
* `MBTILES_TIMEOUT` - How long to wait before timing out MBTiles archive creation tasks. Defaults to
  3600s (1 hour).
* `TASK_TIMEOUT` - How long to wait before timing out tasks. Defaults to 900s (15 minutes).
