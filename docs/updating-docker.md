# Updating Docker

See https://github.com/buildkite/elastic-ci-stack-for-aws/pull/954 for an
example of updating Docker for Linux and Windows.

## Linux

Packer installs Docker, docker-compose, and `docker buildx` using the [`packer/linux/scripts/install-docker.sh`](packer/linux/scripts/install-docker.sh)
script. Update the `DOCKER_VERSION` variable in this file to change which
version of Docker is installed. Update the `DOCKER_COMPOSE_VERSION` variable to
change which version of docker-compose is installed. Update the
`DOCKER_BUILDX_VERSION`variable to change which version of `docker buildx` is installed.

Binary releases are downloaded directly from Docker and GitHub.

## Windows

Packer installs Docker, and `docker-compose` using the [`packer/windows/scripts/install-docker.ps1`](packer/windows/scripts/install-docker.ps1)
script.

[MicrosoftDockerProvider](https://github.com/OneGet/MicrosoftDockerProvider)
is used to source Docker packages. The list of available packages that it 
installs can be found at https://dockermsft.azureedge.net/dockercontainer/DockerMsftIndex.json.

Update the `docker_version` variable in `install-docker.ps1` to one of the
available package versions to change which version of Docker is installed.

The `choco` package manager is used to install `docker-compose`. See the
[chocolatey package manager version history](https://community.chocolatey.org/packages/docker-compose#versionhistory)
for a list of available versions.

Update the `docker_compose_version` variable in `install-docker.ps1` to change
which version of `docker-compose` is installed.
