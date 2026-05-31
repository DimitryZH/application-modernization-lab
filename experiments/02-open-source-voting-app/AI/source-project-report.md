# Source Project Report

## Source identity

- Project name: Docker Example Voting App
- Repository URL: https://github.com/dockersamples/example-voting-app
- Upstream branch used: `main`
- Commit used: `63e9150` (latest commit visible on the GitHub commits page at retrieval time; full 40-character SHA could not be retrieved because direct GitHub clone, archive, and API requests from the shell were blocked by HTTP 403)
- Retrieval date: 2026-05-31 UTC
- License: Apache-2.0, as listed by the upstream GitHub repository page.

## Imported files

The experiment imports a minimal image-based source subset rather than the full build-context repository:

- `source/docker-compose.yml`
- `source/docker-compose.images.yml`
- `source/healthchecks/redis.sh`
- `source/healthchecks/postgres.sh`
- `source/README.md`

## Retrieval notes

Direct `git clone --depth 1 https://github.com/dockersamples/example-voting-app` failed with `CONNECT tunnel failed, response 403`. GitHub codeload and API access from the shell failed with HTTP 403 as well. The GitHub web page was accessible through the browsing tool and showed the project topology and latest short commit `63e9150`.

To avoid vendoring generated artifacts or a partial/corrupt repository, the experiment uses the upstream image-based Compose topology with prebuilt images:

- `dockersamples/examplevotingapp_vote`
- `dockersamples/examplevotingapp_result`
- `dockersamples/examplevotingapp_worker`
- `redis:alpine`
- `postgres:15-alpine`

## Source topology summary

- `vote`: Python voting web UI, HTTP target port 80, host port 8080.
- `result`: Node.js results web UI, HTTP target port 80, host port 8081.
- `worker`: .NET background worker consuming votes from Redis and writing to PostgreSQL.
- `redis`: Redis message queue/cache, private to the back-tier network.
- `db`: PostgreSQL 15, private to the back-tier network, persistent `db-data` volume.
