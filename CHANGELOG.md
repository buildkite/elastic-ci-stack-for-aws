# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [v5.4.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.3.2...v5.4.0) (2021-06-30)

### Added

* Docker Buildx [#871](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/871)
* Docs on which user SSH access applies to [#863](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/863) ([@Temikus](https://github.com/Temikus))

### Changed

* Update Buildkite Agent to version 3.30.0 [#868](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/868) ([@esalter](https://github.com/esalter))
* The HttpPutResponseHopLimit from 1 to 2 [#858](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/858)

### Fixed

* The default cost allocation tag value [#859](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/859)

## [v5.3.2](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.3.1...v5.3.2) (2021-06-11)

### Fixed
* Fix s3secrets-helper for Windows [#846](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/846) ([DuBistKomisch](https://github.com/DuBistKomisch))
* Pin Docker systemd configuration to the same Docker version [#849](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/849) ([cmanou](https://github.com/cmanou))
* Excessive instance scaling while waiting for instances to boot

### Changed
* Create S3 secrets bucket only when needed [#844](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/844) ([vgrigoruk](https://github.com/vgrigoruk))

## [v5.3.1](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.3.0...v5.3.1) (2021-05-05)

### Fixed

* Allow dashes and multiple forward slashes (/) in BuildkiteAgentTokenParameterStorePath [#835](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/835) [#837](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/837)  ([nitrocode](https://github.com/nitrocode))

## [v5.3.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.2.0...v5.3.0) (2021-04-28)

### Added
* Support IAM Permissions Boundaries [#767](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/767) [#805](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/805) ([nitrocode](https://github.com/nitrocode))
* Session manager plugin [#818](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/818) ([nitrocode](https://github.com/nitrocode))

### Changed
* Replace awslogs with the cloudwatch-agent [#811](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/811) ([yob](https://github.com/yob))
* Avoid scaling down too aggressively when there are pending jobs in certain conditions [#823](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/823) ([yob](https://github.com/yob))
* Bump docker from 19.03.x to 20.10.x [#826](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/826) ([yob](https://github.com/yob))
* Bump docker-compose on all operating systems to 1.28.x [#825](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/825) ([yob](https://github.com/yob))
* Bump agent from 3.27.0 to 3.29.0 [#827](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/827) ([yob](https://github.com/yob))
* Bump lifecycled from 3.0.2 to 3.2.0 [#824](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/824) ([yob](https://github.com/yob))
* Bump git on windows from 2.22.0 to 2.31.0 [#819](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/819) ([yob](https://github.com/yob))
* Bump ECR plugin to v2.3.0 [#816](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/816) ([chloeruka](https://github.com/chloeruka))
* Documentation improvements [#815](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/815) [#810](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/810) ([acaire](https://github.com/acaire))

### Removed
* Remove unnecessary IAM roles for SNS and SQS [#829](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/829) ([chloeruka](https://github.com/chloeruka))

## [v5.2.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.1.0...v5.2.0) (2021-02-08)

### Added

* [buildkite-agent v3.27.0](https://github.com/buildkite/agent/releases/tag/v3.27.0) [#794](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/794) ([pda](https://github.com/pda))
* agent names use client-side `%spawn` not server-side `%n` for numbering [#794](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/794) ([pda](https://github.com/pda))

* `IMDSv2Tokens` parameter: optional / required [#786](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/786) ([holmesjr](https://github.com/holmesjr)) → [#788](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/788) & [#789](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/789) ([pda](https://github.com/pda))


### Changed

* Default to [`gp3` volumes](https://aws.amazon.com/about-aws/whats-new/2020/12/introducing-new-amazon-ebs-general-purpose-volumes-gp3/), previously `gp2` [#784](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/784) ([yob](https://github.com/yob))

### Fixed

* `c6gn.*` instances recognized as ARM [#785](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/785) ([yob](https://github.com/yob))
* `s3secrets-helper` installation more resilient [#783](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/783) ([shevaun](https://github.com/shevaun))

## [v5.1.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.0.1...v5.1.0) (2020-12-11)

### Added

* Experimental support for ARM instance types (linux only) [#758](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/758) ([yob](https://github.com/yob))
* Support up to four instance types and mixed combinations of Spot/OnDemand instances [#710](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/710) ([yob](https://github.com/yob))
  * The `InstanceType` stack parameter can now be a CSV with up to 4 types
  * The new `OnDemandPercentage` stack parameter can be reduced from 100% (the default) to allow some Spot instances

### Changed

* Update Buildkite Agent to v3.26.0 [#778](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/778) ([JuanitoFatas](https://github.com/JuanitoFatas))
* Speed up secret downloads from S3 (from ~8 seconds to under 1 second) [#772](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/772) ([pda](https://github.com/pda))
* ECR plugin now has its own log group header to make run time visible [#773](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/773) ([pda](https://github.com/pda))

### Fixed

* Avoid IAM changes for some kinds of stack updates (like changing InstanceType) [#781](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/781) ([yob](https://github.com/yob))
* Improved documentation
  * Add BUILDKITE_PLUGIN_S3_SECRETS_BUCKET_PREFIX to README [#775](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/775) ([maatthc](https://github.com/maatthc))
  * Remove outdated advice re AgentsPerInstance [#760](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/760) ([niceking](https://github.com/niceking))

## [v5.0.1](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.0.0...v5.0.1) (2020-11-09)

### Fixed

* Retreive agent token from parameter store on windows agents [#762](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/762) ([chrisfowles](https://github.com/chrisfowles))

## [v5.0.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.5.0...v5.0.0) (2020-10-26)

### Added
* **Our previously experimental blazing fast lambda scaler is now the default** which makes for much faster scaling in response to pending jobs [#575](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/575) (@lox)
* **EXPERIMENTAL** Windows support on a new Windows Server 2019 based image [#546](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/546), [#632](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/632), [#595](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/595), [#628](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/628), [#614](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/614), [#633](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/633) ([jeremiahsnapp](https://github.com/jeremiahsnapp)) [#670](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/670) ([pda](https://github.com/pda)) [#600](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/600) ([tduffield](https://github.com/tduffield))
  * There is a known issue with graceful handling of spot instances under windows. The agent may not disconnect gracefully, and may appear in the Buildkite UI for a few minutes after they terminate [#752](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/752)
* Support for [buildkite/image-builder](https://github.com/buildkite/image-builder) which can enable you to customize AMIs based off the ones we ship [#692](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/692) ([keithduncan](https://github.com/keithduncan))
* Support for multiple security groups on instances [#667](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/667) ([jdub](https://github.com/jdub))
* AMI and Lambda Scaler support more regions: ap-east-1 (Hong Kong), me-south-1 (Bahrain), af-south-1 (Cape Town), eu-south-1 (Milan) [#718](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/718) ([JuanitoFatas](https://github.com/JuanitoFatas))
* Support for loading BuildkiteAgentTokenPath from AWS Parameter Store [#601](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/601) ([jradtilbrook](https://github.com/jradtilbrook)), [#625](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/625) ([jradtilbrook](https://github.com/jradtilbrook))

### Changed
* Docker configuration is now isolated per-step [#678](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/678) ([patrobinson](https://github.com/patrobinson)) [#756](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/756) ([yob](https://github.com/yob))
* Use EC2 LaunchTemplate instead of a LaunchConfiguration [#589](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/589) ([lox](https://github.com/lox))
* InstanceType default is now `t3.large` (was `t2.nano`) [#699](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/699) ([pda](https://github.com/pda))
* Made ECR hook an `environment` hook (was `pre-command`). [#677](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/677) ([pda](https://github.com/pda))
* Mappings file format has changed to list both Linux and Windows AMIs [#569](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/569) ([lox](https://github.com/lox))
* We now warn instead of hard-fail when there's no configured SSH keys [#669](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/669) ([pda](https://github.com/pda))
* We now only set git-mirrors-path when EnableAgentGitMirrorsExperiment is set [#698](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/698) ([pda](https://github.com/pda))
* Set RootVolumeName appropriately and allow it to be overridden [#593](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/593) ([jeremiahsnapp](https://github.com/jeremiahsnapp))
* Disable AZRebalancing to prevent running instances being terminated unnecessarily [#751](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/751)

### Fixed
* Stop trying to call poweroff after the agent shuts down [#728](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/728) ([yob](https://github.com/yob))
* Update agent config to use `tags-from-ec2-meta-data` [#727](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/727) ([yob](https://github.com/yob))
* Set correct content-type on YAML template files shipped to S3 [#683](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/683) ([kyledecot](https://github.com/kyledecot))
* Fixed introduced issue with SSM permissions [#657](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/657) ([kushmansingh](https://github.com/kushmansingh))
* Add correct cost tags to S3 [#602](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/602) ([hawkowl](https://github.com/hawkowl))
* Fix incorrect yaml syntax for spot instances [#591](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/591) ([lox](https://github.com/lox))

### Dependencies updated
* Bump Buildkite Agent to v3.25.0 [#749](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/749) ([JuanitoFatas](https://github.com/JuanitoFatas))
* Bump Buildkite Agent Scaler to v1.0.2 [#724](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/724) ([JuanitoFatas](https://github.com/JuanitoFatas)) [4fafd8e](https://github.com/buildkite/elastic-ci-stack-for-aws/commit/4fafd8e85a888f0d7b23bb3a1420332fe4e9063c) ([JuanitoFatas](https://github.com/JuanitoFatas)) 
* Bump docker to v19.03.13 (linux) and v19.03.12 (windows) and docker-compose to v1.27.4 (linux, windows uses [latest choco version](https://chocolatey.org/packages/docker-comp…)) [#719](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/719) ([yob](https://github.com/yob)) [#723](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/723) ([JuanitoFatas](https://github.com/JuanitoFatas))
* Bump bundled plugins to the latest versions [secrets](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/740) [ecr](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/741) [docker login](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/744)

### Removed
* Remove AWS autoscaling in favor of buildkite-agent-scaler [#575](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/575) ([lox](https://github.com/lox)) [#588](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/588) ([jeremiahsnapp](https://github.com/jeremiahsnapp))
* Multiple parameters! See below

### Summary of parameter changes:
The following parameters have been **removed** or **reworked**:
* `EnableExperimentalLambdaBasedAutoscaling` was removed (it's the default now)
* `BuildkiteOrgSlug` was removed – the statistics reported by [buildkite-agent-scaler](https://github.com/buildkite/buildkite-agent-scaler/blob/0a127ce221c94ffa703882b233a630ccde67d824/README.md#publishing-cloudwatch-metrics) make it redundant, but consider [buildkite-agent-metrics](https://github.com/buildkite/buildkite-agent-metrics) if you need more detailed metric monitoring
* `BuildkiteTerminateInstanceAfterJobTimeout` is replaced by the more concise `ScaleInIdlePeriod` [#586](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/586) ([jeremiahsnapp](https://github.com/jeremiahsnapp))
* `BuildkiteTerminateInstanceAfterJobDecreaseDesiredCapacity` and `ScaleDownAdjustment` were  removed - instances will now always try to decrement the ASG desired count when their waiting period for new jobs has elapsed
* `ScaleUpAdjustment` is replaced by `ScaleOutFactor` as the new lambda scaler calculates how many agents are needed at the time
* `ScaleDownPeriod` and `ScaleCooldownPeriod` are replaced by `ScaleInIdlePeriod`

The following other parameters have been **added**:
* `ScaleOutFactor` (default: `1.0`) is a multiplier that allows you to add extra agents when scaling up is needed
* `ScaleInIdlePeriod` (default: `600` seconds) is used for scale-in by letting idle agents remove themselves from the ASG
* `InstanceOperatingSystem` (default: `linux`) can be used to specify Windows if you need Windows Server 2019 instances
* *Windows-only* `BuildkiteWindowsAdministrator` (default: `true`) adds the local "buildkite-agent" user account to the local Windows Administrator group
* *optional* `BuildkiteAgentTokenParameterStorePath` and `BuildkiteAgentTokenParameterStoreKMSKey` are for storing your token in [SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html) and are an alternative to `BuildkiteAgentToken`
* *optional* `ScaleOutForWaitingJobs` (default: `false`) can help anticipate future job load and get your instances ready ahead of time

## [v4.5.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.5.0) (2020-07-10)
## Elastic CI Stack for AWS v4.5.0
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.4.0...v4.5.0)

### Changed
- Added ImageIdParameter CloudFormation parameter for SSM Parameter Store image lookup [#691](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/691) (@keithduncan)

## [v4.4.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.4.0) (2020-05-21)
## Elastic CI Stack for AWS v4.4.0
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.3.5...v4.4.0)

### Changed
- Increase the threshold for disk cleanup to 5GB free for 4.3 [#646](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/646) (@huonw)
- Updated buildkite-agent to version 3.21.1 [#687](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/687) (@denbeigh2000)
- Updated docker-compose to version 1.25.1 [#660](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/660) (@dreyks)
- Updated git lfs to 2.10.0 [#668](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/668) (@kushmansingh)

## [v4.3.5](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.3.5) (2019-11-01)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.3.4...v4.3.5)

### Added
- Bump buildkite-agent to v3.13.2 [#644](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/644) (@lox)
- Prune docker builder cache in cleanup [#642](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/642) (@sj26)
- Power off immediately if cloud-init fails [#638](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/638) (@dbaggerman)
- Replaced Linux fixed AMI source with source AMI filter [#636](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/636) (@cawilson)
- Bump docker version to 19.03.2 [#634](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/634) (@PaulLiang1)
- Add cloudformation output exports [#616](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/616) (@jradtilbrook)
- Add python3 and future lib to allow prepping for Python2 EOL [#583](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/583) (@GreyKn)

### Fixed
- Add missing eu-north-1 to lambda mapping [#613](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/613) (@lox)
- Docker experimental needs boolean not string [#611](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/611) (@lox)
- Update ArtifactBucketPolicy to match docs [#607](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/607) (@gough)

## [v4.3.4](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.3.4) (2019-07-28)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.3.3...v4.3.4)

### Changed
- Bump agent to v3.13.2, docker to 19.03 and compose to 1.24.1 [#609](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/609) (@lox)
- Docker experimental needs boolean not string [#610](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/610) (@lox)

## [v4.3.3](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.3.3) (2019-06-01)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.3.2...v4.3.3)

### Changed
- Bump agent to 3.12.0 [#594](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/594) (@lox)

## [v4.3.2](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.3.2) (2019-04-16)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.3.1...v4.3.2)

### Changed
- Bump agent scaler to support newer regions [#566](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/566) (@lox)

## [v4.3.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.3.1) (2019-04-09)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.3.0...v4.3.1)

### Fixed
- Add back us-east-1 to regions [#563](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/563) (@ksindi)

## [v4.3.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.3.0) (2019-04-06)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.2.0...v4.3.0)

### Added
- Add EnableAgentGitMirrorsExperiment parameter [#555](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/555) (@lox)

### Fixed
- Remove temporary packer key [#551](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/551) (@lox)

### Changed
- Updated experimental lambda-based auto-scaler, respect ScaleDownPeriod [#559](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/559) (@lox)
- Bump agent to 3.10.3 [#558](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/558) (@lox)
- Install pigz for parallel decompression in docker pull [#560](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/560) (@lox)
- Use spawn vs multiple systemd units [#552](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/552) (@lox)
- Write cloudwatch metrics from lambda scaler [#541](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/541) (@lox)
- Bump docker-login, ecr and secrets plugins to latest [#550](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/550) (@lox)
- Bump lifecycled to v3.0.2 [#548](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/548) (@lox)
- Restart agent on SIGPIPE (journald restart) [#545](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/545) (@lox)
- Set the priority of the agent to its instance integer [#539](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/539) (@tduffield)

## [v4.2.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.2.0) (2019-02-25)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.1.0...v4.2.0)

### Added
- Add an experimental lambda scaler [#529](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/529) (@lox)
- Add helpers to Makefile for building packer image [#535](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/535) (@tduffield)
- Allow users to configure the root block device [#534](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/534) (@tduffield)

### Fixed
- Fix typo in CF setting [#537](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/537) (@tduffield)
- Make sure we reload the systemd unit files [#533](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/533) (@tduffield)

## [v4.1.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.1.0) (2019-02-11)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.0.4...v4.1.0)

### Changed
- Bump docker to 18.09.2 to fix CVE-2019-5736 [#532](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/532) (@lox)
- Fix typo in docker experimental config [#528](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/528) (@lox)
- Allow users to specify additional sudo permissions [#527](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/527) (@tduffield)
- Add new "TerminateInstanceAfterJob" configuration [#523](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/523) (@tduffield)
- Add Buildkite Org to Cloudwatch Metrics as a Dimension to support multiple orgs per AWS account [#510](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/510) (@lox)

## [v4.0.4](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.0.4) (2019-01-29)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.0.3...v4.0.4)

### Fixed
- Fix bug where lifecycled logs aren't flushed to cloudwatch logs [#524](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/524) (@lox)
- Prevent systemd from killing agent process group [#521](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/521) (@lox)

### Changed
- Expose AgentLifecycleTopic for programatic scaling [#522](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/522) (@tduffield)

## [v4.0.3](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.0.3) (2019-01-18)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.0.2...v4.0.3)

### Changed
- Bump docker to 18.09.1 [#516](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/516) (@lox)
- Bump agent to 3.8.2 [#514](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/514) (@lox)
- Tunable knob for ASG Cooldown period [#495](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/495) (@prateek)

## [v4.0.2](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.0.2) (2018-12-20)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.0.1...v4.0.2)

### Fixed
- Set a region for awslogsd [#508](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/508) (@dgarbus)
- Fix bug where lifecycled didn't pick up handler script [#507](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/507) (@lox)

### Changed
- Add a EnableDockerExperimental param [#506](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/506) (@lox)
- Bump docker to 18.09.0 [#505](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/505) (@lox)

## [v4.0.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.0.1) (2018-11-30)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.0.0...v4.0.1)

### Fixed
- Show correct stack version in log output [#503](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/503) (@lox)
- Remove duplicate AssociatePublicIpAddress

## [v4.0.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.0.0) (2018-11-28)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.0.0-rc3...v4.0.0)

No changes from v4.0.0-rc3.

## [v4.0.0-rc3](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.0.0-rc3) (2018-11-05)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.0.0-rc2...v4.0.0-rc3)

### Changed
- Use rsyslogd+awslogs for logs [#498](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/498) (@lox)
- Remove the dash in description to be consistent with v3 [#499](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/499) (@lox)
- Goss specs [#497](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/497) (@lox)
- Bump lifecycled to v3.0.0 [#496](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/496) (@lox)
- Support timestamp-lines [#494](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/494) (@raylu)
- Add docs for using the bootstrap script [#493](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/493) (@toolmantim)
- Start logging daemons as soon as possile during bootstrap [#492](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/492) (@zsims)
- Merge template files into a single file [#487](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/487) (@lox)
- Move AMI copy into a dedicated step [#486](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/486) (@lox)
- Update AMI to latest packages [#480](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/480) (@lox)

## [v4.0.0-rc2](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.0.0-rc2) (2018-09-04)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v4.0.0-rc1...v4.0.0-rc2)

### Added
- Install Git LFS [#468](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/468) (@lox)

### Changed
- Update to the very latest aws-cli [#478](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/478) (@lox)
- Bump lifecycled to 2.0.2 [#475](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/475) (@lox)
- Default BuildkiteAgentRelease to stable [#474](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/474) (@lox)
- Added InstanceCreationTimeout as parameter [#476](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/476) (@RexChenjq)
- Update README.md to reflect Amazon Linux 2[#470](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/470) (@alexjurkiewicz)
- Clean up docker login hooks [#466](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/466) (@lox)
- Rename the log group name we are using for elastic-stack.log file so we are consistent [#463](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/463) (@arturopie)
- Update to latest Amazon Linux 2 LTS [#462](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/462) (@lox)

## [v4.0.0-rc1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v4.0.0-rc1) (2018-07-18)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v3.2.1...v4.0.0-rc1)

### Changed
- Use Amazon Linux 2 as base AMI [#363](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/363) (@lox)
- Bump docker-login and ecr plugin to latest [#454](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/454) (@lox)
- Bump docker to 18.03.1-ce and docker-compose to 1.22.0 [#455](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/455) (@lox)
- Support attaching multiple policies via the parameter [#446](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/446) (@zsims)
- Make KeyName optional [#444](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/444) (@zsims)
- Provide InstanceRoleName as Output [#438](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/438) (@lox)

## [v3.3.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v3.3.1) (2018-09-13)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v3.3.0...v3.3.1)

### Fixed
- Bump lifecycled to v2.1.1 [#488](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/488) (@lox)

## [v3.3.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v3.3.0) (2018-09-04)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v3.2.1...v3.3.0)

### Changed
- Bump Amazon Linux to 2018.03 [#471](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/471) (@lox)
- Bump docker to 18.03.1-ce and docker-compose to 1.22.0 [#455](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/455) (@lox)
- Support attaching multiple policies via the parameter [#446](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/446) (@zsims)

### Fixed
- Set correct variable to pass to upstream ecr plugin [#453](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/453) (@bshelton229)
- Use exit instead of return in bk-check-disk-space.sh script [#440](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/440) (@arturopie)
- Move cleanup cron jobs to run hourly [#429](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/429) (@arturopie)

## [v3.2.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v3.2.1) (2018-05-24)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v3.2.0...v3.2.1)

### Changed
- Support enabling agent experiments [#423](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/423) (@lox)
- Use the docker directory to check for disk space [#418](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/418) (@arturopie)
- Set InstanceRoleName as stack template output [#421](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/421) (@dblandin)

## [v3.2.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v3.2.0) (2018-05-17)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v3.1.1...v3.2.0)

### Changed
- Updated stable agent to buildkite-agent v3.1.2
- Default EnableDockerUserNamespaceRemap to true [#417](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/417) (@lox)
- Bump the minimum inodes to 250K to allow for big docker images [#416](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/416) (@lox)
- Update to the new secrets hooks repo URL [#414](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/414) (@toolmantim)

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
