# Docker Login Buildkite Plugin

__This is designed to run with Buildkite Agent v3.x beta. Plugins are not yet supported in Buildkite Agent v2.x.__

Login to docker registries. 

## Example

This will log in to Docker Hub prior to running your build step.

```yml
steps:
  - command: ./run_build.sh
    plugins:
      docker-login#v1.0.0:
        username: myuser
        password: ${PASSWORD_FROM_ENV}
```

You can login to multiple registries if required:

```yml
steps:
  - command: ./run_build.sh
    plugins:
      docker-login#v1.0.0:
        - server: my.private.registry 
          username: myuser
          password: ${PASSWORD_FROM_ENV}
        - server: another.private.registry 
          username: myuser
          password: ${PASSWORD_FROM_ENV}
```

## Options

### `username`

The username to send to the docker registry.

### `password`

The password to send to the docker registry.

### `server`

The server to log in to, if blank or ommitted logs into Docker Hub.


## License

MIT (see [LICENSE](LICENSE))