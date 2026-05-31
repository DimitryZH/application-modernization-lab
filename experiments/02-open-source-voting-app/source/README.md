# Docker Example Voting App source import

This directory contains the minimal image-based Docker Compose assets selected from the open-source Docker Example Voting App for this migration experiment.

Repository: https://github.com/dockersamples/example-voting-app

The full upstream repository includes build-context source code for `vote`, `result`, `worker`, and `seed-data`. Direct `git clone`/archive retrieval was blocked by the execution environment's GitHub proxy, so this experiment uses the upstream image-based Compose topology with prebuilt `dockersamples/examplevotingapp_*` images and the Compose service definitions documented by the upstream repository.
