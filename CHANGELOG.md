# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [v3.1.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v3.1.1) (2018-05-02)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v3.1.0...v3.1.1)

### Changed
- Updated stable agent to buildkite-agent v3.1.1
- Bump docker to 18.03.0-ce and docker-compose to 1.21.1 [#411](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/411) (@lox)

## [v3.1.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v3.1.0) (2018-04-30)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v3.0.0...v3.1.0)

### Changed
- Allow userns remapping to be disabled [#410](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/410) (@lox)
- Update lifecycled to 2.0.1 [#407](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/407) (@lox)
- Fix cfn stack instance profile name [#395](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/395) (@chandanadesilva)

## [v3.0.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v3.0.0) (2018-04-18)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v3.0.0-rc1...v3.0.0)

## [v3.0.0-rc1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v3.0.0-rc1) (2018-04-18)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v2.3.5...v3.0.0-rc1)

### Changed
- Use new Metrics API, drop requirement for org-slug and api-token [#405](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/405) (@lox)
- Bump Lifecycled to v2.0.0 [#404](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/404) (@lox)
- Add support for billing tags [#398](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/398) (@tduffield)
- Drop support for buildkite-agent v2, stable is 3.0.0 [#400](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/400) (@lox)
- Don't blow up when no plugins are enabled [#394](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/394) (@haines)
- Fail install if docker hasn't started [#387](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/387) (@lox)
- Update docker to stable 17.12.1-ce [#391](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/391) (@lox)

## v2.3.5 - 2018-02-26
### Changed
- Make EnableDockerUserNamespaceRemap the new default [\#378](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/378)
- Docker 17.12.1-ce-rc2 (Related to [\#377](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/377))

## v2.3.4 - 2018-02-13
### Fixed
- Configure docker before it starts to avoid corruption [\#377](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/377)

### Added
- Show elastic stack logs in Instance Terminal for easier debugging
- Collect cron output in elastic-stack.log
- Check (and free) diskspace before builds

## v2.3.3 - 2018-01-11
### Fixed
- Amazon Linux 2017.09.1 (to mitigate Meltdown/Spectre)
- Docker 17.12.0-ce and Compose 1.18.0

## v2.3.2 - 2018-01-07
### Fixed
- Bump metrics lambda version to v2.0.2
- Bump ECR plugin to 1.1.3

## v2.3.1 - 2017-12-23
### Fixed
- Updated to latest buildkite-metrics lambda version (v2.0.0) that respects rate limiting headers [\#357](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/357)
- Added a new parameter for adding extra buildkite-agent tags/metadata [\#359](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/340)

## v2.3.0 - 2017-10-20
### Fixed
- Autoscaling is suspended when lifecycled crashes [\#344](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/344)
- Optimize the permissions check script to only fix the current pipeline’s build dir [\#340](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/340) (@toolmantim)

### Changed
- CloudWatch Logs namespaced [\#342](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/342)
- Docker 17.09.0-ce [\#350](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/350) (@lox)
- Buildkite Agent v2.6.6 and v3.0.0-beta34

### Added
- Optionally run docker as buildkite agent with userns-remap  [\#341](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/341) (@lox)

## 2.2.0-rc3 - 2017-08-12
### Changed
- Bump buildkite-metrics to v1.5.0 (retry on error)
- Replace shudder with new lifecycled that supports spot notifications

## 2.2.0-rc2 - 2017-06-26
### Changed
- Re-added deprecated DOCKER_HUB_USER variables

## 2.2.0-rc1 - 2017-07-18
### Changed
- Move ecr, secrets and docker-login to plugins
- Add a signature llama to the environment hook
- Show stack version in the environment hook
- Move pipeline to yaml, json version is deprecated
- Use Shudder tool to handle autoscaling events and spot notifications
- Docker 17.06.0-ce

### Removed
- Remove deprecated DOCKER_HUB_USER variables

## 2.1.4 - 2017-06-28
### Changed
- Buildkite Agents v3.0.0-beta28
- Edge agent version is downloaded when instances boot rather than baked in AMI
- Added SECRETS_PLUGIN_ENABLED to allow secrets downloading to be disabled

## 2.1.3 - 2017-06-20
### Changed
- Updated to latest Amazon Linux 2017.03.1 (see security advisory AWS-2017-007)
- Updated docker-compose to 1.14.0

## 2.1.2 - 2017-06-16
### Fixed
- Using an env secrets bucket hook caused builds to fail with an undefined variable error

## 2.1.1 - 2017-06-12
### Changed
- 🐳 Docker-Compose 1.14.0-r2 (with support for cache_from directive)
- Buildkite Agents v2.6.3 and v3.0.0-beta27
- Agent version defaults to beta rather than stable

### Fixed
- Using git-credentials was broken (#290)
- Managed secrets bucket failed to create (#282)

## 2.1.0 - 2017-05-12
### Added
- A secrets bucket is created automatically if left blank
- Git over HTTPS is supported via a git-credentials file
- A customisable ScaleDownPeriod parameter is available to prevent rapid scale downs

### Changed
🐳 Docker 17.05.0-ce and Docker-Compose 1.13.0
- Buildkite Agents v2.6.3 and v3.0.0-beta23
- Latest aws-cli
- Autoscaling group is replaced on update, for smoother updates in large groups

### Fixed
- Fixed a bug where the stack would scale up faster than instances were launching

## 2.0.2 - 2017-04-11
### Fixed
- 🕷 Avoid restarting docker whilst it's initializing to try and avoid corrupting it (#236)

## 2.0.1 - 2017-04-04
### Added
- 🆙 Includes new Buildkite Agent v2.5.1 (stable) and v3.0-beta.19 (beta)

### Fixed
- ⏰ Increase the polling duration for scale down events to prevent hitting api limits (#263)

## 2.0.0 - 2017-03-28
### Added
- Docker 17.03.0-ce and Docker-Compose 1.11.2
- Metrics are collected by a Lambda function, so no more metrics sub-stack 🎉
- Secrets bucket uses KMS-backed SSE by default
- Support authenticated S3 paths for BootstrapScriptUrl and AuthorizedUsersUrl
- New regions (US Ohio)
- ECRAccessPolicy parameter for easy Amazon ECR configuration
- Fixed size stacks are possible, and don't create auto-scaling resources
- Added version number to stack description and agent metadata
- Optionally non-public agent instances

### Fixed
- Improved scale-up/scale-down logic
- Cloudwatch logs are sent to correct region
- Fixed size stacks are support
- Correct release names for beta and edge agent
- Better error handling for when fetching env or private-key fails
- Regions that require v4 signatures are better handled
- Working docker-gc script
- Autoscaling is suspended during stack updates
- Breaking changes

### Changed
- Initialization logs have moved to /var/log/elastic-stack.log

### Removed
- ManagedPolicyARNs has been removed, a singular version exists now: ManagedPolicyARN

## 1.1.1 - 2016-09-19
### Fixed
- 👭 If you run multiple agents per instance, chmod during build environment setup no longer clashes (#143)
- 🔐 The AWS_ECR_LOGIN_REGISTRY_IDS option has been fixed, so it now calls aws ecr get-login --registry-ids correctly (#141)

## 1.1.0 - 2016-09-09
- ### Added
- 📡 Buildkite Agent has been updated to the latest builds
- 🐳 Docker has been upgraded to 1.12.1
- 🐳 Docker Compose has been upgraded to 1.8.0
- 🔒 Can now add a custom managed policy ARN to apply to instances to add extra permissions to agents
- 📦 You can now specify a BootstrapScriptUrl to a bash script in an S3 bucket for performing your own setup and install tasks on agent machine boot
- 🔑 Added support for a single SSH key at the root of the secrets bucket (and SSH keys have been renamed)
- 🐳 Added support for logging into any Docker registry, and built-in support for logging into AWS ECR (N.B. the docker login environment variables have been - renamed)
- 📄 Docker, cloud-init and CloudFormation logs are sent to CloudWatch logs
- 📛 Instances now have nicer names
- ⚡ Updating stack parameters now triggers instances to update, no need for deleting and recreating the stack

### Fixed
- 🚥 The "queue" parameter is now "default" by default, to make it easier and less confusing to get started. Make sure to update it to "elastic" if you want to continue using that queue name.
- 🐳 Jobs sometimes starting before Docker had started has been fixed
- ⏰ Rolling upgrades and stack updates are now more reliable, no longer should you get stack timeouts



## 1.0.0 - 2016-07-28
### Added
- Initial release! 🎂🎉
