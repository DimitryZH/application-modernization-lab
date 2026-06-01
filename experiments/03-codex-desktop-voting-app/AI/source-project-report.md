# Source Project Report

## Repository

- Repository URL: https://github.com/dockersamples/example-voting-app.git
- Commit SHA: `63e9150ca17af4ed05880d4245e486481f73fcb4`
- Retrieval date: 2026-06-01
- Retrieval command: `git clone https://github.com/dockersamples/example-voting-app.git experiments\03-codex-desktop-voting-app\source`

## Imported Project

The imported source is Docker's Example Voting App, a distributed demo application with:

- Python/Flask vote service.
- Node.js result service.
- .NET worker service.
- Redis queue.
- PostgreSQL database.

## Source Compose Files

- `docker-compose.yml`: local development Compose file that builds the application services from source and uses bind mounts.
- `docker-compose.images.yml`: alternate Compose file that runs prebuilt Docker Hub images.
- `docker-stack.yml`: Docker Swarm deployment file.

The migration and baseline validation use `docker-compose.yml` because it is the primary local development definition and builds from the imported source tree.

## Source Integrity Notes

The upstream repository was cloned directly from GitHub after the initial sandboxed network attempt failed. The source commit SHA above was captured from the cloned repository before migration work started.
