# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [v6.40.2](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.40.1...v6.40.2) (2025-06-11)
- fix: update agent-scaler to 1.9.4 [#1487](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1487) ([scadu](https://github.com/scadu))

## [v6.40.1](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.40.0...v6.40.1) (2025-06-10)
- fix: correct reference to Elastic CI Mode toggle [#1485](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1485) ([scadu](https://github.com/scadu))

## [v6.40.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.39.0...v6.40.0) (2025-06-10)
- feat: add graceful scale-in with experimental Elastic CI Mode [#1475](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1475) ([scadu](https://github.com/scadu))

## [v6.39.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.39.0) (2025-06-06)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.38.0...v6.39.0)

### Changed
- Bump Agent v3.97.0 -> v3.98.1 [#1482](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1482) (@jeremybumsted)
- Update to latest aws lambda runtime [#1462](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1462) (@lswith)

<details>
<summary><h3>Agent Changelog</h3></summary>

## [v3.98.1](https://github.com/buildkite/agent/tree/v3.98.1) (2025-06-04)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.98.0...v3.98.1)

### Fixed
- Gracefully Handle Missing GitHub PR refs/pull/%s/head in Checkout [#3294](https://github.com/buildkite/agent/pull/3294) (@123sarahj123)
- Fix bootstrap subprocess handling [#3331](https://github.com/buildkite/agent/pull/3331) (@DrJosh9000)
- Reduce git fetch from twice to once for typical Github PR build [#3327](https://github.com/buildkite/agent/pull/3327) (@zhming0)
- Set job log tempfile permissions to 644 (was 600) [#3330](https://github.com/buildkite/agent/pull/3330) (@moskyb)

### Internal
- Tag tests with os / arch [#3326](https://github.com/buildkite/agent/pull/3326) (@catkins)

## [v3.98.0](https://github.com/buildkite/agent/tree/v3.98.0) (2025-05-27)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.97.2...v3.98.0)

### Added
- Add build URL to log fields [#3317](https://github.com/buildkite/agent/pull/3317) (@ChrisBr)
- Add kubernetes-bootstrap subcommand [#3306](https://github.com/buildkite/agent/pull/3306), [#3314](https://github.com/buildkite/agent/pull/3314), [#3316](https://github.com/buildkite/agent/pull/3316) (@DrJosh9000)

### Fixed
- Fix `redactor add --format json` help string [#3322](https://github.com/buildkite/agent/pull/3322) (@francoiscampbell)

## Dependency updates
- [#3320](https://github.com/buildkite/agent/pull/3320), [#3318](https://github.com/buildkite/agent/pull/3318), [#3319](https://github.com/buildkite/agent/pull/3319), [#3323](https://github.com/buildkite/agent/pull/3323), [#3321](https://github.com/buildkite/agent/pull/3321) (@dependabot[bot])


## [v3.97.2](https://github.com/buildkite/agent/tree/v3.97.2) (2025-05-13)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.97.1...v3.97.2)

### Fixed
- fix: Don't disconnect-after-idle when just given a job [#3312](https://github.com/buildkite/agent/pull/3312) (@DrJosh9000)

### Dependency updates
- [#3307](https://github.com/buildkite/agent/pull/3307), [#3311](https://github.com/buildkite/agent/pull/3311), [#3308](https://github.com/buildkite/agent/pull/3308), [#3309](https://github.com/buildkite/agent/pull/3309), [#3310](https://github.com/buildkite/agent/pull/3310) (@dependabot[bot])


## [v3.97.1](https://github.com/buildkite/agent/tree/v3.97.1) (2025-05-12)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.97.0...v3.97.1)

### Fixed
- Fix unusable `BUILDKITE_AGENT_TAGS_FROM_EC2_TAGS` env var [#3285](https://github.com/buildkite/agent/pull/3285) (@shanesmith)
- Set ignore_agent_in_dispatches when finishing with disconnect-after-job [#3297](https://github.com/buildkite/agent/pull/3297) (@DrJosh9000)

### Internal
- Introduce a structure where coverage can increase on githttp checkout code [#3296](https://github.com/buildkite/agent/pull/3296) (@wolfeidau)
- TE-3708-follow-up: Use go test -cover to generate coverage report [#3295](https://github.com/buildkite/agent/pull/3295) (@zhming0)
- TE-3708: use bktec on agent [#3292](https://github.com/buildkite/agent/pull/3292) (@zhming0)

### Dependency updates
- [#3298](https://github.com/buildkite/agent/pull/3298), [#3300](https://github.com/buildkite/agent/pull/3300), [#3301](https://github.com/buildkite/agent/pull/3301), [#3299](https://github.com/buildkite/agent/pull/3299), [#3287](https://github.com/buildkite/agent/pull/3287), [#3290](https://github.com/buildkite/agent/pull/3290), [#3291](https://github.com/buildkite/agent/pull/3291) (@dependabot[bot])

<details>

## [v6.38.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.37.0...v6.38.0) (2025-05-13)

## Changed
* Bump Docker buildx to v0.23.0 and Docker Compose to v2.35.1 by @orien in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1472
* ⬆️ Bump Windows server to 2022 by @mcncl and @scadu in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1456
* Bump golang.org/x/sys from 0.32.0 to 0.33.0 by @dependabot in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1478

## [v6.37.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.36.0...v6.37.0) (2025-04-30)

### Added
* Option to recursively copy AWS SSM parameters to an env file by @wolfeidau in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1455
* More instance types by @ivannalisetska in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1465
* `BuildkiteAgentSignalGracePeriod` parameter by @mcncl in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1468

### Changed
* Buildkite Agent v3.97.0, was v3.93.1 by @pda & @PriyaSudip in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1473 & https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1453
* Go 1.23 by @mcncl in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1467
  * Go 1.23.6 (just fixes) by @mcncl in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1469
* Bump golang.org/x/sys from 0.30.0 to 0.32.0 by @dependabot in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1464

## [v6.36.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.35.0...v6.36.0) (2025-03-10)

### Changed
- Bump buildkite-agent to v3.93.1 [#1449](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1449) ([DrJosh9000](https://github.com/DrJosh9000))
- Tidy up hcl whitespace and upgrade windows to use gp3 for more iops [#1407](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1407) ([wolfeidau](https://github.com/wolfeidau))

### Fixed
- fix: make sure buildkite-agent.service is not terminated by OOM [#1450](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1450) ([scadu](https://github.com/scadu))

### Internal
- Update CODEOWNERS [#1447](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1447) ([karensawrey](https://github.com/karensawrey))

### Dependencies
- Bump github.com/google/go-cmp from 0.6.0 to 0.7.0 [#1448](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1448) ([dependabot[bot]](https://github.com/apps/dependabot))

<details>
<summary><h3>Agent Changelog</h3></summary>

## [v3.93.1](https://github.com/buildkite/agent/tree/v3.93.1) (2025-02-27)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.93.0...v3.93.1)

### Added
- Set env when job cancelled for hooks [#3213](https://github.com/buildkite/agent/pull/3213) (@sj26)

## [v3.93.0](https://github.com/buildkite/agent/tree/v3.93.0) (2025-02-26)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.92.1...v3.93.0)

### Added
- Handle pause actions [#3211](https://github.com/buildkite/agent/pull/3211) (@DrJosh9000)
- Add agent stop command [#3198](https://github.com/buildkite/agent/pull/3198) (@sj26)

### Changed
- Skip pushing the git commit metadata if BUILDKITE_COMMIT_RESOLVED=true [#3152](https://github.com/buildkite/agent/pull/3152) (@CerealBoy)
- Update cancel_signal.go [#3197](https://github.com/buildkite/agent/pull/3197) (@karensawrey)
- Capture datadog metrics usage from registering agents [#3195](https://github.com/buildkite/agent/pull/3195) (@wolfeidau)
- Capture some HTTP client details from registering agents [#3193](https://github.com/buildkite/agent/pull/3193) (@yob)

### Fixed
- Change the signal handler to ensure the agent quits after the grace period [#3200](https://github.com/buildkite/agent/pull/3200) (@wolfeidau)
- Don't fail if the interrupt fails when the PID is already exited [#3199](https://github.com/buildkite/agent/pull/3199) (@wolfeidau)
- bash shouldn't be assumed to be in /bin for portability [#1534](https://github.com/buildkite/agent/pull/1534) (@jgedarovich)

### Internal
- Fixes from the new modernize analyzer from the Go team [#3209](https://github.com/buildkite/agent/pull/3209) (@wolfeidau)
- Kill exp/maps and replace with stdlib maps [#3210](https://github.com/buildkite/agent/pull/3210) (@moskyb)

### Dependabot
- Dependencies - they just keep being updated! [#3203](https://github.com/buildkite/agent/pull/3203), [#3208](https://github.com/buildkite/agent/pull/3208), [#3205](https://github.com/buildkite/agent/pull/3205), [#3204](https://github.com/buildkite/agent/pull/3204), [#3207](https://github.com/buildkite/agent/pull/3207), [#3183](https://github.com/buildkite/agent/pull/3183), [#3186](https://github.com/buildkite/agent/pull/3186), [#3194](https://github.com/buildkite/agent/pull/3194) (@dependabot[bot])

## [v3.92.1](https://github.com/buildkite/agent/tree/v3.92.1) (2025-02-13)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.92.0...v3.92.1)

### Removed

- Revert "Ensure the log streamer respects forced shutdown of the agent" [#3191](https://github.com/buildkite/agent/pull/3191) (@wolfeidau)
- Revert "Fix data race on exitImmediately" [#3190](https://github.com/buildkite/agent/pull/3190) (@wolfeidau)

### Dependabot
- The usual updates: [#3188](https://github.com/buildkite/agent/pull/3188), [#3185](https://github.com/buildkite/agent/pull/3185) (@dependabot[bot])

> [!NOTE]
> Reverted [#3180](https://github.com/buildkite/agent/pull/3180) and [#3187](https://github.com/buildkite/agent/pull/3187) as this change introduced a bug which resulted in truncated log output. Will re-think this fix and push it out again in another release after we do some more testing.

## [v3.92.0](https://github.com/buildkite/agent/tree/v3.92.0) (2025-02-12)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.91.0...v3.92.0)

### Fixed
- Ensure the log streamer respects forced shutdown of the agent [#3180](https://github.com/buildkite/agent/pull/3180) (@wolfeidau)
- Fix data race on exitImmediately [#3187](https://github.com/buildkite/agent/pull/3187) (@DrJosh9000)
- Reduce timeout for these two operations to avoid holding up compute [#3177](https://github.com/buildkite/agent/pull/3177) (@wolfeidau)
- Timeout waiting for client containers [#3172](https://github.com/buildkite/agent/pull/3172) (@DrJosh9000)
- Clean up worker pool implementation [#3171](https://github.com/buildkite/agent/pull/3171) (@DrJosh9000)

### Internal
- rm bazel-*, add to .gitignore [#3178](https://github.com/buildkite/agent/pull/3178) (@DrJosh9000)
- Speed up needlessly slow tests [#3179](https://github.com/buildkite/agent/pull/3179) (@DrJosh9000)

### Dependabot
- The usual updates: [#3184](https://github.com/buildkite/agent/pull/3184), [#3182](https://github.com/buildkite/agent/pull/3182), [#3174](https://github.com/buildkite/agent/pull/3174), [#3173](https://github.com/buildkite/agent/pull/3173), [#3176](https://github.com/buildkite/agent/pull/3176) (@dependabot[bot])

</details>

## [v6.35.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.34.0...v6.35.0) (2025-02-06)

### Added

* Let user provide full KMS Key ARN and update descriptions [#1425](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1425) ([toothbrush](https://github.com/toothbrush))
* Additional permissions are required when upgrading the scaler version [#1440](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1440) ([wolfeidau](https://github.com/wolfeidau))

### Internal
* Bump golang.org/x/sys from 0.29.0 to 0.30.0 [#1446](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1446) ([dependabot[bot]](https://github.com/apps/dependabot))
* bump agent version to v3.91.0 [#1443](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1443) ([jeremybumsted](https://github.com/jeremybumsted))
* Create CODEOWNERS [#1442](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1442) ([karensawrey](https://github.com/karensawrey))

<details>
<summary><h3>Agent Changelog</h3></summary>

## [v3.91.0](https://github.com/buildkite/agent/tree/v3.91.0) (2025-01-28)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.90.0...v3.91.0)

### Changed
- Jitter within ping, status, log loops [#3164](https://github.com/buildkite/agent/pull/3164) (@DrJosh9000)

### Fixed
- Roko v1.3.1 [#3157](https://github.com/buildkite/agent/pull/3157) (@moskyb)
- Better plugin checkout logging [#3166](https://github.com/buildkite/agent/pull/3166) (@DrJosh9000)

### Internal
- Add /.buildkite dir for Dockerfile updates [#3162](https://github.com/buildkite/agent/pull/3162) (@DrJosh9000)

</details>

## [v6.34.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.34.0) (2025-01-21)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.33.0...v6.34.0)

### Changed
- Upgrade the agent scaler which introduces a new agent endpoint param [#1437](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1437) (@wolfeidau)
- ➖ Docker can be a range of GIDs [#1436](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1436) (@mcncl)
- Ec2 instance connect [#1432](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1432) (@blackliner)

### Fixed
- Fix PATH used by jobs [#1420](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1420) (@jonhiggs)

### Internal
- 🔨 Add GitHub action for Linear sync [#1433](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1433) (@mcncl)
- Add EBS volume tag for BK queue, keep optional cost allocation tags [#1430](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1430) (@petetomasik)

> [!WARNING]
> This release will force an upgrade of the agent scaler by checking the version is 1.9.1 or higher. This is required so we can introduce a new parameter to the agent scaler to pass through agent endpoint.

## [v6.33.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.33.0) (2025-01-09)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.32.0...v6.33.0)

### Added
- This adds an optional override for agent API endpoint [#1428](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1428) (@wolfeidau)

### Internal
- Bump agent to v3.89.0 [#1427](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1427) (@CerealBoy)
- Bump golang.org/x/sys from 0.28.0 to 0.29.0 [#1426](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1426) (@dependabot[bot])

<details>
<summary><h3>Agent Changelog</h3></summary>

## [v3.89.0](https://github.com/buildkite/agent/tree/v3.89.0) (2025-01-06)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.88.0...v3.89.0)

### Added
- Adding support for Additional Hooks Paths [#3124](https://github.com/buildkite/agent/pull/3124) (@CerealBoy)

### Internal
- Bump the container-images group across 5 directories with 2 updates [#3143](https://github.com/buildkite/agent/pull/3143) (@dependabot[bot])
- Update golang.org/x/net [#3140](https://github.com/buildkite/agent/pull/3140) (@yob)

</details>

## [v6.32.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.32.0) (2024-12-19)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.31.0...v6.32.0)

### Changed
- Bump agent to v3.88.0 [#1418](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1418) (@DrJosh9000)

### Release process changes
- Increase AMI garbage collection to 100 images per run [#1417](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1417) (@yob)
- remove DRY_RUN flag from AMI cleaning script [#1416](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1416) (@yob)
- Expand the AMI cleaning pipeline to all regions [#1415](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1415) (@yob)
- New pipeline: deregister old AMIs [#1414](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1414) (@yob)
- Assume an IAM role via OIDC when running integration tests [#1413](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1413) (@yob)
- stop setting ACLs when publishing templates to S3 [#1412](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1412) (@yob)
- Update bk/elastic-ci-stack-s3-secrets-hooks to v2.2.0 [#1411](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1411) (@yob)
- Try harder to delete test S3 logging buckets created during CI [#1410](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1410) (@yob)

### Dependency bumps
- Bump golang.org/x/sys from 0.27.0 to 0.28.0 [#1409](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1409) (@dependabot[bot])

<details>
<summary><h3>Agent Changelog</h3></summary>

## [v3.88.0](https://github.com/buildkite/agent/tree/v3.88.0) (2024-12-18)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.87.1...v3.88.0)

### Changed
- Prefix fatal error message with 'buildkite-agent:' [#3135](https://github.com/buildkite/agent/pull/3135) (@jordandcarter)
- Notify when host and bootstrap agent paths mismatch [#3123](https://github.com/buildkite/agent/pull/3123) (@jordandcarter)

### Fixed
- Enable process debug logging [#3134](https://github.com/buildkite/agent/pull/3134) (@patrobinson)
- Ignore empty submodule clone configs [#3122](https://github.com/buildkite/agent/pull/3122) (@DrJosh9000)
- fix: allow for empty files on hook check [#3117](https://github.com/buildkite/agent/pull/3117) (@nzspambot)
- Parse more standalone `$` cases as literal `$`s and not variable expansions:
  - Bump github.com/buildkite/go-pipeline from 0.13.2 to 0.13.3 [#3137](https://github.com/buildkite/agent/pull/3137) (@dependabot[bot])
  - Bump github.com/buildkite/interpolate from 0.1.4 to 0.1.5 [#3138](https://github.com/buildkite/agent/pull/3138) (@dependabot[bot])

### Dependabot
- [#3136](https://github.com/buildkite/agent/pull/3136), [#3127](https://github.com/buildkite/agent/pull/3127), [#3129](https://github.com/buildkite/agent/pull/3129), [#3128](https://github.com/buildkite/agent/pull/3128), [#3130](https://github.com/buildkite/agent/pull/3130), [#3132](https://github.com/buildkite/agent/pull/3132), [#3131](https://github.com/buildkite/agent/pull/3131), [#3133](https://github.com/buildkite/agent/pull/3133), [#3125](https://github.com/buildkite/agent/pull/3125), [#3119](https://github.com/buildkite/agent/pull/3119), [#3120](https://github.com/buildkite/agent/pull/3120), [#3121](https://github.com/buildkite/agent/pull/3121), [#3116](https://github.com/buildkite/agent/pull/3116), [#3115](https://github.com/buildkite/agent/pull/3115) (@dependabot[bot])

</details>

## [v6.31.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.31.0) (2024-12-09)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.30.0...v6.31.0)

### Changed
- Bump agent to 3.87.1 [#1404](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1404) (@wolfeidau)
- Bump Docker buildx to v0.18.0 and Docker Compose to v2.30.3 [#1401](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1401) (@orien)
- Bump Docker buildx to v0.19.2 and Docker Compose to v2.31.0 [#1406](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1406) (@orien)

### Fixed
- Update packer and the AMI with some fixes for binfmt [#1405](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1405) (@wolfeidau)

### Internal
- PS-195 increase the instance_types from 4 to 10 [#1396](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1396) (@SorchaAbel)
- Various dependency bumps: [#1397](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1397) (@dependabot[bot])

<details>
<summary><h3>Agent Changelog</h3></summary>

## [v3.87.1](https://github.com/buildkite/agent/tree/v3.87.1) (2024-11-26)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.87.0...v3.87.1)

### Fixed
- Fix duplicated output when debug is enabled [#3108](https://github.com/buildkite/agent/pull/3108) (@DrJosh9000)

### Changed
- Small change to annotation example [#3106](https://github.com/buildkite/agent/pull/3106) (@PriyaSudip)

### Internal
- Use Ubuntu codename labels to refer to base images [#3103](https://github.com/buildkite/agent/pull/3103) (@DrJosh9000)

### Dependabot
- The usual updates: [#3111](https://github.com/buildkite/agent/pull/3111), [#3112](https://github.com/buildkite/agent/pull/3112), [#3110](https://github.com/buildkite/agent/pull/3110), [#3109](https://github.com/buildkite/agent/pull/3109), [#3113](https://github.com/buildkite/agent/pull/3113), [#3104](https://github.com/buildkite/agent/pull/3104), [#3098](https://github.com/buildkite/agent/pull/3098), [#3102](https://github.com/buildkite/agent/pull/3102), [#3097](https://github.com/buildkite/agent/pull/3097), [#3101](https://github.com/buildkite/agent/pull/3101) (@dependabot[bot])

## [v3.87.0](https://github.com/buildkite/agent/tree/v3.87.0) (2024-11-18)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.86.0...v3.87.0)

### Changed
- Remove signal reason unable\_to\_verify\_signature and replace with signature\_rejected [#3094](https://github.com/buildkite/agent/pull/3094) (@jordandcarter)

### Fixed
- Don't surface expected stderr output from git rev-parse [#3095](https://github.com/buildkite/agent/pull/3095) (@CerealBoy)
- Add retry around NewS3Client [#3092](https://github.com/buildkite/agent/pull/3092) (@l-suzuki)

### Internal
- Soft fail upload of packages docker images [#3093](https://github.com/buildkite/agent/pull/3093) (@tommeier)
- Switch to agent-base images [#3091](https://github.com/buildkite/agent/pull/3091) (@DrJosh9000)

## [v3.86.0](https://github.com/buildkite/agent/tree/v3.86.0) (2024-11-12)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.85.1...v3.86.0)

### Added
- Add `force-grace-period-seconds` argument to `step cancel` command [#3084](https://github.com/buildkite/agent/pull/3084) (@mitchbne)

### Changed
- Rename env var to `BUILDKITE_STEP_CANCEL_FORCE_GRACE_PERIOD_SECONDS` [#3087](https://github.com/buildkite/agent/pull/3087) (@mitchbne)
- Drop Ubuntu 18.04, add Ubuntu 24.04 [#3078](https://github.com/buildkite/agent/pull/3078) (@DrJosh9000)

### Fixed
- Handle older version of remote ref error message [#3082](https://github.com/buildkite/agent/pull/3082) (@steveh)

### Internal
- dependabot: Group Dockerfiles [#3077](https://github.com/buildkite/agent/pull/3077) (@DrJosh9000)
- Various dependency bumps: [#3086](https://github.com/buildkite/agent/pull/3086), [#3085](https://github.com/buildkite/agent/pull/3085), [#3081](https://github.com/buildkite/agent/pull/3081), [#3079](https://github.com/buildkite/agent/pull/3079) (@dependabot[bot])

## [v3.85.1](https://github.com/buildkite/agent/tree/v3.85.1) (2024-11-09)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.85.0...v3.85.1)

### Fixed
- Fix another nil pointer panic in k8s mode [#3075](https://github.com/buildkite/agent/pull/3075) (@DrJosh9000)
- Fix nil pointer panic in k8s mode [#3074](https://github.com/buildkite/agent/pull/3074) (@DrJosh9000)

## [v3.85.0](https://github.com/buildkite/agent/tree/v3.85.0) (2024-11-07)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.84.0...v3.85.0)

### Added
- Create `buildkite-agent step cancel` subcommand [#3070](https://github.com/buildkite/agent/pull/3070) (@mitchbne)

### Changed
- Support installing specific versions via script [#3069](https://github.com/buildkite/agent/pull/3069) (@jordandcarter)
- Promote polyglot-hooks experiment to default [#3063](https://github.com/buildkite/agent/pull/3063) (@DrJosh9000)
- Use sha256 in the checksum verification [#3062](https://github.com/buildkite/agent/pull/3062) (@esenmarti)
- Minor update to the 'redactor' CLI command examples. [#3060](https://github.com/buildkite/agent/pull/3060) (@gilesgas)

### Fixed
- Fix zzglob import path [#3057](https://github.com/buildkite/agent/pull/3057) (@DrJosh9000)

### Internal
- Shell package cleanup [#3068](https://github.com/buildkite/agent/pull/3068) (@DrJosh9000)
- Remove .editorconfig [#3064](https://github.com/buildkite/agent/pull/3064) (@DrJosh9000)
- Various dependency bumps: [#3066](https://github.com/buildkite/agent/pull/3066) [#3065](https://github.com/buildkite/agent/pull/3065) [#3067](https://github.com/buildkite/agent/pull/3067) (@dependabot[bot])
</details>

## [v6.30.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.30.0) (2024-10-30)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.29.1...v6.30.0)

### Added
- Add support for c8g instances. [#1392](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1392) (@toothbrush)
- Restore SSM Session Manager Plugin [#1389](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1389) (@ellsclytn)

### Changed
- Bump agent to v3.84.0 [#1393](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1393) (@DrJosh9000)

### Internal
- fix: update goss to be more explicit with platform in docker tests [#1390](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1390) (@wolfeidau)

<details>
<summary><h3>Agent Changelog</h3></summary>

## [v3.84.0](https://github.com/buildkite/agent/tree/v3.84.0) (2024-10-28)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.83.1...v3.84.0)

### Added
- Add command for canceling a running a build [#2958](https://github.com/buildkite/agent/pull/2958) (@dannymidnight)
- Add tini-static to alpine images [#3054](https://github.com/buildkite/agent/pull/3054) (@DrJosh9000)

### Fixed
- Implement several documentation improvements to the Agent (for the Buildkite Docs). [#3043](https://github.com/buildkite/agent/pull/3043) (@gilesgas)
- Allow token to be empty if graphql-token is provided [#3051](https://github.com/buildkite/agent/pull/3051) (@jordandcarter)
- Fix multiline secret redaction when output with \r\n [#3050](https://github.com/buildkite/agent/pull/3050) (@DrJosh9000)
- k8s exec: Perform liveness check of clients [#3045](https://github.com/buildkite/agent/pull/3045) (@DrJosh9000)
- Fix request headers for multipart [#3042](https://github.com/buildkite/agent/pull/3042) (@DrJosh9000)

### Internal
- install.sh tidyups [#3032](https://github.com/buildkite/agent/pull/3032) (@DrJosh9000)
- Parallel container image uploads [#3035](https://github.com/buildkite/agent/pull/3035) (@DrJosh9000)
- Various dependency bumps: [#3058](https://github.com/buildkite/agent/pull/3058), [#3026](https://github.com/buildkite/agent/pull/3026), [#3055](https://github.com/buildkite/agent/pull/3055), [#3056](https://github.com/buildkite/agent/pull/3056), [#3048](https://github.com/buildkite/agent/pull/3048), [#3047](https://github.com/buildkite/agent/pull/3047), [#3049](https://github.com/buildkite/agent/pull/3049), [#3036](https://github.com/buildkite/agent/pull/3036), [#3041](https://github.com/buildkite/agent/pull/3041), [#3040](https://github.com/buildkite/agent/pull/3040), [#3037](https://github.com/buildkite/agent/pull/3037), [#3039](https://github.com/buildkite/agent/pull/3039) (@dependabot[bot])

</details>

## [v6.29.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.29.1) (2024-10-10)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.29.0...v6.29.1)

### Fixed
- Bump agent to v3.83.1 [#1385](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1385) (@DrJosh9000)

<details>
<summary><h3>Agent Changelog</h3></summary>

## [v3.83.1](https://github.com/buildkite/agent/tree/v3.83.0) (2024-10-10)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.83.0...v3.83.1)

### Fixed
- Fix artifact up/download timeouts [#3033](https://github.com/buildkite/agent/pull/3033) (@DrJosh9000)

</details>

## [v6.29.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.29.0) (2024-10-09)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.28.0...v6.29.0)

### Fixed
- Add m8g instances to UsingArmInstances [#1381](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1381) (@wgrrrr)

### Changed
- Bump agent to v3.83.0 [#1383](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1383) (@DrJosh9000)
- Bump golang.org/x/sys from 0.25.0 to 0.26.0 [#1382](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1382) (@dependabot[bot])

<details>
<summary><h3>Agent Changelog</h3></summary>

## [v3.83.0](https://github.com/buildkite/agent/tree/v3.83.0) (2024-10-08)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.82.1...v3.83.0)

### Added
- Exit with code 94 if a mirror lock times out [#3023](https://github.com/buildkite/agent/pull/3023) (@DrJosh9000)
- Add support for oidc aws session tags [#3015](https://github.com/buildkite/agent/pull/3015) (@sj26)
- Support for future multipart artifact uploads [#2991](https://github.com/buildkite/agent/pull/2991) (@DrJosh9000)

### Fixed
- Tweak BUILDKITE_IGNORED_ENV handling [#3029](https://github.com/buildkite/agent/pull/3029) (@DrJosh9000)
- BUG FIX: Ensure Build Title Is Correct When Checkout Is Skipped [#3024](https://github.com/buildkite/agent/pull/3024) (@123sarahj123)
- Ensure all string slice args have whitespace cleaned off of each element [#3021](https://github.com/buildkite/agent/pull/3021) (@moskyb)
- Fix data race on worker stop [#3016](https://github.com/buildkite/agent/pull/3016) (@DrJosh9000)

### Internal
- Migrate Agent Pipeline to Agent Cluster [#3018](https://github.com/buildkite/agent/pull/3018) (@matthewborden)
- Refactor the various agent HTTP clients [#3017](https://github.com/buildkite/agent/pull/3017) (@DrJosh9000)
- Dependabot bumps to busybox [#3025](https://github.com/buildkite/agent/pull/3025), golang.org/x packages [#3027](https://github.com/buildkite/agent/pull/3027), cloud provider packages [#3028](https://github.com/buildkite/agent/pull/3028), [#3019](https://github.com/buildkite/agent/pull/3019), [#3013](https://github.com/buildkite/agent/pull/3013), [#3009](https://github.com/buildkite/agent/pull/3009), DataDog packages [#3010](https://github.com/buildkite/agent/pull/3010) Ubuntu [#3012](https://github.com/buildkite/agent/pull/3012), [#3008](https://github.com/buildkite/agent/pull/3008), and go-pipeline [#3014](https://github.com/buildkite/agent/pull/3014) (@dependabot[bot])

</details>

## [v6.28.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.28.0) (2024-09-24)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.27.0...v6.28.0)

### Fixed
- fix: Add `r8g` to the `UsingArmInstances` logic [#1373](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1373) (@ParkMyCar)
- Bump agent to v3.82.1 [#1376](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1376) (@patrobinson)

### Changed
- Pin amazon linux ami [#1377](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1377) (@patrobinson)
- Remove Test Splitter [#1372](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1372) (@nprizal)

<details>
<summary>Agent Changelog</summary>

## [v3.82.1](https://github.com/buildkite/agent/tree/v3.82.1) (2024-09-23)

### Fixed
- Work around issue with http2 connections on linux not cleanly closing, causing agents to be marked as lost [#3005](https://github.com/buildkite/agent/pull/3005) (@patrobinson)

</details>


## [v6.27.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.27.0) (2024-09-13)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.26.0...v6.27.0)

### Added
- Add signing verification behaviour and fix windows config option [#1370](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1370) (@wolfeidau)

## [v6.26.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.26.0) (2024-09-11)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.25.0...v6.26.0)

### Added
- Add the option to create a KMS key for signing of pipelines [#1366](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1366) (@wolfeidau)

### Changed
- Bump agent to v3.81.0 [#1368](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1368) (@wolfeidau)
- Bump agent to v3.80.0 [#1365](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1365) (@wolfeidau)

<details>
<summary>Agent Changelog</summary>

## [v3.81.0](https://github.com/buildkite/agent/tree/v3.81.0) (2024-09-10)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.80.0...v3.81.0)

### Fixed
- Fix for region discovery issue with aws sdkv2 when running in ec2 [#2977](https://github.com/buildkite/agent/pull/2977) (@wolfeidau)
- Explain verification-failure-behavior in more detail [#2984](https://github.com/buildkite/agent/pull/2984) (@DrJosh9000)

### Added
- Add sha256 checksum output to the formatting options [#2974](https://github.com/buildkite/agent/pull/2974) (@patrobinson)

### Internal
- Dependabot churn: [#2978](https://github.com/buildkite/agent/pull/2978), [#2980](https://github.com/buildkite/agent/pull/2980) (@dependabot[bot])

## [v3.80.0](https://github.com/buildkite/agent/tree/v3.80.0) (2024-09-06)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.79.0...v3.80.0)

### Added
- Support AWS KMS for signing and verifying pipelines [#2960](https://github.com/buildkite/agent/pull/2960) (@wolfeidau)

### Changed
- Allow `buildkite-agent` to run a job when JWK is unavailable but failure behaviour is set to `warn` [#2945](https://github.com/buildkite/agent/pull/2945) (@CheeseStick)

### Fixed
- coda-content-type pass content-type to the server when specified [#2967](https://github.com/buildkite/agent/pull/2967) (@SorchaAbel)
- Updated to support only ECC_NIST_P256 keyspec for initial release [#2973](https://github.com/buildkite/agent/pull/2973) (@wolfeidau)

### Internal
- Dependabot churn: [#2964](https://github.com/buildkite/agent/pull/2964), [#2965](https://github.com/buildkite/agent/pull/2965), [#2952](https://github.com/buildkite/agent/pull/2952), [#2972](https://github.com/buildkite/agent/pull/2972), [#2963](https://github.com/buildkite/agent/pull/2963) (@dependabot[bot])

</details>

### Internal
- Bump golang.org/x/sys from 0.24.0 to 0.25.0 [#1367](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1367) (@dependabot[bot])


## [v6.25.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.25.0) (2024-08-30)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.24.0...v6.25.0)

### Changed
- Bump agent to v3.79.0 [#1362](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1362) (@wolfeidau)

<details>
<summary>Agent Changelog</summary>

## [v3.79.0](https://github.com/buildkite/agent/tree/v3.79.0) (2024-08-29)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.78.0...v3.79.0)

### Fixed
- Fix error when hook cannot be run due to missing interpreter [#2948](https://github.com/buildkite/agent/pull/2948) (@mcncl)

### Added
- Support for multiple trace context encodings [#2947](https://github.com/buildkite/agent/pull/2947) (@DrJosh9000)

### Internal
- Bump github.com/buildkite/go-pipeline from 0.11.0 to 0.12.0 [#2959](https://github.com/buildkite/agent/pull/2959) (@wolfeidau)
- Dependabot churn: [#2951](https://github.com/buildkite/agent/pull/2951), [#2955](https://github.com/buildkite/agent/pull/2955), [#2949](https://github.com/buildkite/agent/pull/2949), [#2956](https://github.com/buildkite/agent/pull/2956), [#2954](https://github.com/buildkite/agent/pull/2954), [#2950](https://github.com/buildkite/agent/pull/2950), [#2953](https://github.com/buildkite/agent/pull/2953) (@dependabot[bot])

</details>

## [v6.24.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.24.0) (2024-08-21)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.23.0...v6.24.0)

### Changed
- docs: update RootVolumeIops to include gp3 [#1359](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1359) (@joemiller)
- Bump agent to v3.78.0 [#1360](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1360) (@CerealBoy)

### Internal
- Dependabot updates: [#1358](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1358) (@dependabot[bot])

<details>
<summary>Agent Changelog</summary>

## [v3.78.0](https://github.com/buildkite/agent/tree/v3.78.0) (2024-08-20)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.77.0...v3.78.0)

### Fixed
- fix for layout issues with log messages [#2933](https://github.com/buildkite/agent/pull/2933) (@wolfeidau)
- Prevent Cancel from running when a k8s job is cancelled already [#2935](https://github.com/buildkite/agent/pull/2935) (@CerealBoy)
- k8s: Unconditionally set `BUILDKITE_AGENT_ACCESS_TOKEN` [#2942](https://github.com/buildkite/agent/pull/2942) (@DrJosh9000)

### Changed
- Add a bit more context to the debugging for failing signature verify [#2926](https://github.com/buildkite/agent/pull/2926) (@wolfeidau)
- Update description for the 'priority' option for the 'buildkite-agent annotate' command. [#2934](https://github.com/buildkite/agent/pull/2934) (@gilesgas)

### Internal
Dependabot churn: [#2927](https://github.com/buildkite/agent/pull/2927), [#2928](https://github.com/buildkite/agent/pull/2928), [#2929](https://github.com/buildkite/agent/pull/2929), [#2930](https://github.com/buildkite/agent/pull/2930), [#2931](https://github.com/buildkite/agent/pull/2931), [#2937](https://github.com/buildkite/agent/pull/2937), [#2939](https://github.com/buildkite/agent/pull/2939), [#2940](https://github.com/buildkite/agent/pull/2940), [#2943](https://github.com/buildkite/agent/pull/2943) (@dependabot[bot])

</details>

## [v6.23.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.23.0) (2024-08-09)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.22.4...v6.23.0)

### Changed
- Bump agent to v3.77.0 [#1355](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1355) (@wolfeidau)

### Internal
- Dependabot updates: [#1354](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1354) (@dependabot[bot])

<details>
<summary>Agent Changelog </summary>

## [v3.77.0](https://github.com/buildkite/agent/tree/v3.77.0) (2024-08-08)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.76.2...v3.77.0)

</details>

## [v6.22.4](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.22.4) (2024-07-31)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.22.3...v6.22.4)

### Changed
- Bump agent to v3.76.2 [#1353](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1353), [#1351](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1351) (@DrJosh9000)
- Bump Test Splitter version to v0.8.0 [#1349](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1349) (@nprizal)
- Upgrade test-splitter-client to v0.7.3 [#1344](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1344) (@wooly)

<details>
<summary>Agent Changelog </summary>

## [v3.76.2](https://github.com/buildkite/agent/tree/v3.76.2) (2024-08-01)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.76.1...v3.76.2)

> [!NOTE]
> v3.76.0 fixed an issue which caused the HTTP client in the agent to fall back to HTTP/1.1, see [#2908](https://github.com/buildkite/agent/pull/2908). If you need to disable HTTP/2.0 in your environment you can do this using the `--no-http2` flag or matching configuration option.

### Fixed
- Only override TLSClientConfig if set [#2913](https://github.com/buildkite/agent/pull/2913) (@DrJosh9000)


## [v3.76.1](https://github.com/buildkite/agent/tree/v3.76.1) (2024-07-31)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.76.0...v3.76.1)

> [!NOTE]
> v3.76.0 fixed an issue which caused the HTTP client in the agent to fall back to HTTP/1.1, see [#2908](https://github.com/buildkite/agent/pull/2908). If you need to disable HTTP/2.0 in your environment you can do this using the `--no-http2` flag or matching configuration option.

### Changed
- Pass cancel grace period to bootstrap [#2910](https://github.com/buildkite/agent/pull/2910) (@DrJosh9000)

## [v3.76.0](https://github.com/buildkite/agent/tree/v3.76.0) (2024-07-31)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.75.1...v3.76.0)

> [!NOTE]
> This release fixed an issue which caused the HTTP client in the agent to fall back to HTTP/1.1, see [#2908](https://github.com/buildkite/agent/pull/2908). If you need to disable HTTP/2.0 in your environment you can do this using the `--no-http2` flag or matching configuration option.

### Changed
- fix enable http/2 by default as intended by flags [#2908](https://github.com/buildkite/agent/pull/2908) (@wolfeidau)

### Fixed
- Let artifact phase and post-command run in grace period [#2899](https://github.com/buildkite/agent/pull/2899) (@DrJosh9000)

### Internal
- Dependabot updates: [#2902](https://github.com/buildkite/agent/pull/2902), [#2907](https://github.com/buildkite/agent/pull/2907), [#2903](https://github.com/buildkite/agent/pull/2903), [#2904](https://github.com/buildkite/agent/pull/2904), [#2901](https://github.com/buildkite/agent/pull/2901), [#2905](https://github.com/buildkite/agent/pull/2905), [#2896](https://github.com/buildkite/agent/pull/2896), [#2897](https://github.com/buildkite/agent/pull/2897) (@dependabot[bot])

</details>

## [v6.22.3](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.22.3) (2024-07-22)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.22.2...v6.22.3)

### Changed
- Bump Agent to v3.75.1 and Scaler to v1.8.0 [#1345](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1345) (@DrJosh9000)

> [!NOTE]
> Depending on how you upgrade existing stacks, you may not automatically be upgraded to v1.8.0 of Buildkite Agent Scaler. [A work around](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/1172#issuecomment-1697304023) exists for this known issue.

<details>
<summary>Agent Changelog </summary>

## [v3.75.1](https://github.com/buildkite/agent/tree/v3.75.1) (2024-07-22)
[Full Changelog](https://github.com/buildkite/agent/compare/v3.75.0...v3.75.1)

### Fixed
- Fix downloaded artifact permissions [#2894](https://github.com/buildkite/agent/pull/2894) (@DrJosh9000)

</details>

## [v6.22.2](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.22.2) (2024-07-18)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.22.1...v6.22.2)

### Changed
- Bump agent version to v3.75.0 [#1342](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1342) (@wolfeidau)

### Added
- First pass at adding test-splitter to the elastic-ci linux stack. [#1337](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1337) (@wooly)

### Dependencies
- Bump golang.org/x/sys from 0.21.0 to 0.22.0 [#1340](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1340) (@dependabot[bot])

<details>
<summary>Agent Changelog </summary>
<p><a href="https://github.com/buildkite/agent/compare/v3.74.1...v3.75.0">Full Changelog</a></p>
<h5 id="added">Added</h5>
<ul>
<li>Introduce <code>riscv64</code> architecture <a href="https://github.com/buildkite/agent/pull/2877">#2877</a> (@TimePrinciple)</li>
<li>Add a SHA256SUMS file <a href="https://github.com/buildkite/agent/pull/2890">#2890</a> (@DrJosh9000)</li>
</ul>
<h5 id="changed">Changed</h5>
<ul>
<li>Reject more secrets <a href="https://github.com/buildkite/agent/pull/2884">#2884</a> (@DrJosh9000)</li>
<li>Include repo name in Packages image path <a href="https://github.com/buildkite/agent/pull/2871">#2871</a> (@swebb)</li>
</ul>
<h5 id="fixed">Fixed</h5>
<ul>
<li>Fix some common artifact download bugs <a href="https://github.com/buildkite/agent/pull/2878">#2878</a> (@DrJosh9000)</li>
<li>SUP-2343: remove &quot;retry&quot; example from &quot;buildkite-agent step get&quot; as not valid <a href="https://github.com/buildkite/agent/pull/2879">#2879</a> (@tomowatt)</li>
</ul>
<h5 id="internal">Internal</h5>
<ul>
<li>Log in to buildkite packages right before pushing images <a href="https://github.com/buildkite/agent/pull/2892">#2892</a> (@moskyb)</li>
<li>Update LICENSE.txt <a href="https://github.com/buildkite/agent/pull/2885">#2885</a> (@wooly)</li>
<li>Remove Packagecloud agent publish steps from agent pipeline <a href="https://github.com/buildkite/agent/pull/2873">#2873</a> (@tommeier)</li>
<li>Release Docker images on Buildkite Packages <a href="https://github.com/buildkite/agent/pull/2837">#2837</a> (@swebb)</li>
<li>Fix the OIDC login for Packages <a href="https://github.com/buildkite/agent/pull/2875">#2875</a> (@swebb)</li>
<li>Fix the Packages registry name <a href="https://github.com/buildkite/agent/pull/2874">#2874</a> (@swebb)</li>
<li>Fix image name when pushing to Buildkite packages <a href="https://github.com/buildkite/agent/pull/2870">#2870</a> (@swebb)</li>
<li>Dependabot updates: <a href="https://github.com/buildkite/agent/pull/2888">#2888</a>, <a href="https://github.com/buildkite/agent/pull/2887">#2887</a>, <a href="https://github.com/buildkite/agent/pull/2882">#2882</a>, <a href="https://github.com/buildkite/agent/pull/2883">#2883</a>, <a href="https://github.com/buildkite/agent/pull/2880">#2880</a> (@dependabot[bot])</li>
</ul>
</details>

## [v6.22.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.22.1) (2024-07-04)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.22.0...v6.22.1)

### Changed
- bump the agent version to v3.74.1 [#1338](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1338) (@wolfeidau)

### Internal
- Create dependabot.yml, update some Go things [#1332](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1332) (@DrJosh9000)

<details>
<summary>Agent Changelog </summary>
<p><a href="https://github.com/buildkite/agent/compare/v3.74.0...v3.74.1">Full Changelog</a></p>
<h5 id="added">Added</h5>
<ul>
<li>Log public signing key thumbprint and signed step payload <a href="https://github.com/buildkite/agent/pull/2853">#2853</a> (@jordandcarter)</li>
</ul>
<h5 id="fixed">Fixed</h5>
<ul>
<li>Don&#39;t try to early-set env vars <a href="https://github.com/buildkite/agent/pull/2852">#2852</a> (@DrJosh9000)</li>
<li>Convey env vars between k8s containers <a href="https://github.com/buildkite/agent/pull/2851">#2851</a> (@DrJosh9000)</li>
<li>Fix typo in &quot;kuberentes&quot; <a href="https://github.com/buildkite/agent/pull/2836">#2836</a> (@moskyb)</li>
</ul>
<h5 id="internal">Internal</h5>
<ul>
<li>Make the graphql endpoint for <code>buildkite-agent tool sign</code> configurable <a href="https://github.com/buildkite/agent/pull/2841">#2841</a> (@moskyb)</li>
<li>Dependabot updates: <a href="https://github.com/buildkite/agent/pull/2863">#2863</a>, <a href="https://github.com/buildkite/agent/pull/2862">#2862</a>, <a href="https://github.com/buildkite/agent/pull/2857">#2857</a>, <a href="https://github.com/buildkite/agent/pull/2860">#2860</a>, <a href="https://github.com/buildkite/agent/pull/2864">#2864</a>, <a href="https://github.com/buildkite/agent/pull/2856">#2856</a>, <a href="https://github.com/buildkite/agent/pull/2867">#2867</a>, <a href="https://github.com/buildkite/agent/pull/2846">#2846</a>, <a href="https://github.com/buildkite/agent/pull/2848">#2848</a>, <a href="https://github.com/buildkite/agent/pull/2847">#2847</a>, <a href="https://github.com/buildkite/agent/pull/2845">#2845</a>, <a href="https://github.com/buildkite/agent/pull/2840">#2840</a>, <a href="https://github.com/buildkite/agent/pull/2844">#2844</a>, <a href="https://github.com/buildkite/agent/pull/2842">#2842</a>, <a href="https://github.com/buildkite/agent/pull/2843">#2843</a>, <a href="https://github.com/buildkite/agent/pull/2849">#2849</a> (@dependabot[bot])</li>
</ul>
</details>

## [v6.22.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.22.0) (2024-06-19)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.21.0...v6.22.0)

### Added
* Add new stack parameter for enabling dualstack docker [PLT-2325] [#1306](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1306) (@yob)

### Changed
* Upgrade agent to 3.74.0 [#1328](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1328) (@zhming0)


<details>
<summary>Agent Changelog </summary>
<p><a href="https://github.com/buildkite/agent/compare/v3.73.1...v3.74.0">Full Changelog</a></p>
<h5 id="security">Security</h5>
<ul>
<li>⚠️ When using <code>artifact download</code>, artifacts that were uploaded with paths containing <code>..</code> will no longer be able to traverse up from the destination path. This change is unlikely to break the vast majority of pipelines, however if you are relying on <code>..</code> for path traversal and cannot fix your pipeline, you can enable the new experiment <code>allow-artifact-path-traversal</code> <a href="https://github.com/buildkite/agent/pull/2815">#2815</a> (@DrJosh9000)</li>
<li>Redact Job API token like other env vars <a href="https://github.com/buildkite/agent/pull/2834">#2834</a> (@DrJosh9000)</li>
</ul>
<h5 id="added">Added</h5>
<ul>
<li>Add logs to allowed-[repositories|plugins] <a href="https://github.com/buildkite/agent/pull/2810">#2810</a> (@jakubm-canva)</li>
</ul>
<h5 id="fixed">Fixed</h5>
<ul>
<li>Fix error in k8s after job completes <a href="https://github.com/buildkite/agent/pull/2804">#2804</a> (@DrJosh9000)</li>
</ul>
<h5 id="changed">Changed</h5>
<ul>
<li>PTY rows/cols increased <a href="https://github.com/buildkite/agent/pull/2806">#2806</a> (@pda)</li>
<li>Dont sign initial steps with interpolations <a href="https://github.com/buildkite/agent/pull/2813">#2813</a> (@moskyb)</li>
</ul>
<h5 id="internal">Internal</h5>
<ul>
<li>kubernetes-exec is now a flag <a href="https://github.com/buildkite/agent/pull/2814">#2814</a> (@DrJosh9000)</li>
<li>shell logger: Use fmt functions once <a href="https://github.com/buildkite/agent/pull/2805">#2805</a> (@DrJosh9000)</li>
<li>Update deprecated import <a href="https://github.com/buildkite/agent/pull/2811">#2811</a> (@DrJosh9000)</li>
<li>Use Rand per-test in agent/plugin/error_test.go <a href="https://github.com/buildkite/agent/pull/2795">#2795</a> (@moskyb)</li>
<li>Publish debian and rpm packages to Buildkite Packages <a href="https://github.com/buildkite/agent/pull/2824">#2824</a> <a href="https://github.com/buildkite/agent/pull/2826">#2826</a> <a href="https://github.com/buildkite/agent/pull/2831">#2831</a> <a href="https://github.com/buildkite/agent/pull/2830">#2830</a> <a href="https://github.com/buildkite/agent/pull/2833">#2833</a> (@sj26)</li>
<li>Dependabot updates: <a href="https://github.com/buildkite/agent/pull/2809">#2809</a>, <a href="https://github.com/buildkite/agent/pull/2816">#2816</a>, <a href="https://github.com/buildkite/agent/pull/2800">#2800</a>, <a href="https://github.com/buildkite/agent/pull/2801">#2801</a>, <a href="https://github.com/buildkite/agent/pull/2802">#2802</a>, <a href="https://github.com/buildkite/agent/pull/2803">#2803</a>, <a href="https://github.com/buildkite/agent/pull/2787">#2787</a>, <a href="https://github.com/buildkite/agent/pull/2798">#2798</a>, <a href="https://github.com/buildkite/agent/pull/2808">#2808</a>, <a href="https://github.com/buildkite/agent/pull/2827">#2827</a> <a href="https://github.com/buildkite/agent/pull/2817">#2817</a>, <a href="https://github.com/buildkite/agent/pull/2818">#2818</a>, <a href="https://github.com/buildkite/agent/pull/2819">#2819</a>, <a href="https://github.com/buildkite/agent/pull/2822">#2822</a>, <a href="https://github.com/buildkite/agent/pull/2829">#2829</a>, <a href="https://github.com/buildkite/agent/pull/2832">#2832</a>, <a href="https://github.com/buildkite/agent/pull/2835">#2835</a> (@dependabot[bot])</li>
</ul>
</details>

> [!IMPORTANT]
> When using `artifact download`, artifacts that were uploaded with paths containing `..` will no longer be able to traverse up from the destination path. This change is unlikely to break the vast majority of pipelines, however if you are relying on `..` for path traversal and cannot fix your pipeline, you can enable the new experiment `allow-artifact-path-traversal`



### Fixed
* Lazy-unmount /tmp before masking [#1327](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1327) (@DrJosh9000)

### Dependencies
* Bump Docker buildx to v0.15.0 [#1329](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1329) (@rianmcguire)

## [v6.21.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.21.0) (2024-05-27)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.20.0...v6.21.0)

### Changed
- Bump agent version to 3.73.1 [#1323](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1323) [#1321](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1321) [#1320](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1320) (@DrJosh9000 + @moskyb)

## [v6.20.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.20.0) (2024-05-03)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.19.0...v6.20.0)

### Fixed
- Fix windows agent not restarting [#1318](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1318) (@patrobinson)
- Fix SSH key clearance in buildkite-ami.pkr.hcl [#1316](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1316) (@Gezi-lzq @123sarahj123)

### Dependencies
- Bump Docker buildx to v0.14.0 and Docker Compose to v2.27.0 [#1317](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1317) (@orien)

## [v6.19.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.19.0) (2024-04-30)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.18.0...v6.19.0)

### Changed
- Bump agent version [#1314](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1314) (@patrobinson)
- Only allow SSH to reach Packer instance from Elastic Stack [#1308](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1308) (@steveh)
- Restore "Packer Builder" tag for Packer instances [#1307](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1307) (@steveh)

## [v6.18.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.18.0) (2024-03-28)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.17.0...v6.18.0)

### Changed
- Bump agent version to v3.67.0 [#1303](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1303) (@DrJosh9000)

## [v6.17.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.17.0) (2024-03-14)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.16.0...v6.17.0)

### Changed
- Bump Docker to v25.0.3 from repositories configured for the [Base Amazon Linux 2023 AMI](https://docs.aws.amazon.com/linux/al2023/release-notes/relnotes-2023.3.20240304.html)
- Update agent to 3.66 [#1301](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1301) (@moskyb) [#1295](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1295) (@matthewborden)
- Bump Docker buildx to v0.13.0 and Docker Compose to v2.24.6 [#1299](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1299) (@orien)
- Update ECR plugin to v2.8.0 [#1300](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1300) (@lucaswilric)

## [v6.16.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.16.0) (2024-02-15)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.15.0...v6.16.0)

### Changed
- Bump agent version to v3.63.0 [#1292](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1292) (@DrJosh9000)

## [v6.15.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.15.0) (2024-02-02)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.14.0...v6.15.0)

### Security
- For linux, the Base AMI has been updated to [Amazon Linux 2023.3.20240131](https://docs.aws.amazon.com/linux/al2023/release-notes/relnotes-2023.3.20240131.html) which fixes [CVE-2024-21626](https://nvd.nist.gov/vuln/detail/CVE-2024-21626).

### Added
- Support configurable log retention for scaler with the `LogRetentionDays` parameter. [#1278](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1278) (@grahamc)

### Fixed
- Fix path for cfn-env on windows elastic stack did not always work [#1286](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1286) (@triarius)

## [v6.14.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.14.0) (2024-01-30)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.13.0...v6.14.0)

### Added
- A parameter, `RootVolumeThroughput`, to be set for gp3 root volumes [#1282](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1282) (@cmanou)

### Changed
- Allow specifying IOPS for gp3 [#1283](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1283) (@bradleyayers)

### Dependencies
- Bump buildx to v0.12.1 and docker-compose to v2.24.4 [#1284](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1284) (@triarius)

## [v6.13.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.13.0) (2024-01-23)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.12.0...v6.13.0)

### Dependencies
- Bump agent version to v3.62.0 [#1280](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1280) (@tessereth)

## [v6.12.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.12.0) (2023-12-14)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.11.0...v6.12.0)

### Added
- Add MountTmpfsAtTmp parameter [#1274](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1274) (@DrJosh9000)

### Dependencies
- Bump buildkite-agent to v3.61.0 [#1275](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1275) (@DrJosh9000)

## [v6.11.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.11.0) (2023-12-07)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.10.0...v6.11.0)

### Added
- BuildkiteAgentCancelGracePeriod option to linux stack [#1258](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1258) (@njgrisafi)
- RootVolumeIops parameter to allow io1 and io2 RootVolumeTypes [#1269](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1269) (@triarius)

### Fixed
- Allow hyphens in all `InstanceTypes` values [#1266](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1266) (@pH14)

### Dependencies
- Bump agent to v3.60.1 [#1260](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1260) (@DrJosh9000) [#1265](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1265) (@moskyb) [#1271](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1271) (@triarius)
- Bump buildx to v0.12.0 [#1262](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1262) (@triarius)
- Bump docker-compose to v2.23.3 [#1272](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1272) (@triarius)

### Internal
- Launch test elastic stacks using templates from S3 [#1267](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1267) (@moskyb)
- Ensure tag builds have the tag [#1259](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1259) (@triarius)

## [v6.10.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.10.0) (2023-11-02)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.9.0...v6.10.0)

### Added
- Enable optionally changing EC2 Instance Types used for AMI Creation [#1252](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1252) (@tomowatt)
- Add support for graviton3 with local nvme [#1253](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1253) (@joemiller)

### Fixed
- Build fix-perms in Makefile [#1254](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1254) (@DrJosh9000)

### Changed
- Bump agent version to v3.58.0 [#1256](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1256) (@DrJosh9000)

### Internal
- Mention docker 20.10.25 to 24.0.5 upgrade in v6.8.0 changelog [#1249](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1249) (@yob)

## [v6.9.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.9.0) (2023-10-23)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.8.0...v6.9.0)

### Fixed
- Instances in ASGs at their minimum capacity will now be correctly terminated when `BuildkiteTerminateInstanceAfterJob` is enabled [#1245](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1245)
- Fix ScalerEventSchedulePeriod was missing from interface [#1243](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1243)

### Changed
- Update buildkite-agent to v3.57.0 [#1247](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1247) (@moskyb)
- Add more missing service role IAM permissions [#1244](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1244) (@triarius)

### Internal
- Update README to show we are on Amazon Linux 2023 now [#1246](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1246) (@triarius)

## [v6.8.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.8.0) (2023-10-19)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.7.1...v6.8.0)

### Changed
- Bump Agent Scaler version to v1.7.0. This updates the lambda runtime to `provided.al2` from the deprecated `go1.x` [#1236](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1236) (@HugeIRL)
  Note: depending on how you upgrade existing stacks, you may not automatically be upgraded to v1.7.0 of Buildkite Agent Scaler. See [here](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/1172#issuecomment-1697304023) for a work around to this known issue.
- Bump buildkite-agent to v3.56.0 [#1237](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1237) (@triarius)
- Bump docker-compose to v2.22.0 [#1234](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1234) (@jkburges)
- Improve logging for startup scripts on linux [#1230](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1230) (@triarius)
- Wrap quotes around AWS::StackName [#1238](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1238) (@n-tucker)
- Docker upgraded from from 20.10.25 to 24.0.5 [Amazon Linux 2023 changelog](https://docs.aws.amazon.com/linux/al2023/release-notes/relnotes-2023.2.20230920.html)

### Fixed
- Fix rsyslog was missing from base AMI [#1240](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1240) (@peter-svensson)
- Fix Service Role was missing some permissions [#1192](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1192) (@philnielsen) [#1233](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1233) (@triarius)
- Fix hyphens were not allowed in InstanceTypes [#1228](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1228) (@nitrocode)
- Fix qemu binfmt image is pulled during instance startup [#1231](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1231) (@triarius)

### Internal
- Fix Windows AMI build failed [#1239](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1239) (@triarius)
- Add test stack remover script [#1226](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1226) (@moskyb)
- Add a step to CI to check files have been formatted with shfmt [#1232](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1232) (@triarius)

## [v6.7.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.7.1) (2023-09-20)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.7.0...v6.7.1)

### Security
⚠️ This release fixes a medium-severity security vulnerability. We recommend upgrading to v6.7.1 or v5.22.5.

- Affected versions: All prior versions of Elastic CI Stack (except v5.22.5). v6.7.0 and v5.22.4 contained a partial fix.
- Impact: Privilege escalation to root on Linux agent instances
- Required privileges: Users that can run user-controlled commands on agents (e.g. by pushing a branch to a repo that triggers a build with those changes)
- Attack vector: A specially crafted build can abuse the `fix-buildkite-agent-builds-permissions` script to run commands as root on subsequent builds
- Fix: Improved input validation and file handling [#1219](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1219), [#1221](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1221) (@DrJosh9000)
- Alternative workarounds: Deploy a [pre-bootstrap hook](https://buildkite.com/docs/agent/v3/securing#strict-checks-using-a-pre-bootstrap-hook) to prevent execution of `fix-buildkite-agent-builds-permissions` during a build

## [v5.22.5](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.22.5) (2023-09-14)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.22.4...v5.22.5)

### Security
⚠️ This release fixes a medium-severity security vulnerability (same as described in v6.7.1).
- Fix: Improved input validation and file handling [#1220](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1220) (@DrJosh9000)

## [v6.7.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.7.0) (2023-09-14)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.6.0...v6.7.0)

### Security
⚠️ This release **partially** fixes a medium-severity security vulnerability. We recommend upgrading to v6.7.1 or v5.22.5.

### Changed
- Prevent permission script acting on symlinks [#1212](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1212) (@DrJosh9000)
- Update to scaler v1.6.0 [#1213](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1213) (@DrJosh9000)
- Bump buildkite-agent to v3.55.0 [#1214](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1214) (@DrJosh9000)

### Internal
- Fix ami_source_filter [#1211](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1211) (@DrJosh9000)

## [v5.22.4](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.22.4) (2023-09-14)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.22.3...v5.22.4)

### Security
⚠️ This release **partially** fixes a medium-severity security vulnerability (same as described in v6.7.1). We recommend upgrading to v6.7.1 or v5.22.5.

### Changed
- Prevent permission script acting on symlinks [#1215](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1215) (@DrJosh9000)

## [v6.6.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.6.0) (2023-09-07)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.5.0...v6.6.0)

### Fixed
- Fix instance storage mount script fails when instance storage not available [#1206](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1206) (@triarius)

### Changed
- Bump buildkite-agent to v3.54.0 [#1207](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1207) (@DrJosh9000)

## [v6.5.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.5.0) (2023-08-31)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.4.0...v6.5.0)

### Changed
- Bump buildkite-agent to v3.53.0 [#1204](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1204) (@DrJosh9000)

## [v6.4.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.4.0) (2023-08-24)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.3.0...v6.4.0)

### Changed
- Bump docker-compose to v2.20.3 [#1201](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1201) (@triarius)
- Bump buildkite-agent to v3.52.1 [#1200](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1200) (@triarius)
- Change the Community Slack links in documentation to Forum ones [#1199](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1199) (@mcncl)

### Internal
- Prevent tag builds from publishing a latest template when they are not "on the main branch" [#1197](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1197) (@triarius)

## [v6.3.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.3.0) (2023-08-16)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.2.0...v6.3.0)

### Changed
- Bump buildkite-agent to v3.51.0 [#1193](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1193) (@triarius)
- Bump `git-lfs` to v3.4.0 [#1191](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1191) (@triarius)

### Fix
- Fix `mdadm` is not installed, leading to broken instance storage when there is more than one volumes [#1190](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1190) (@triarius)

### Internal
- Incorporated CHANGELOG for v5.22.3 [#1189](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1189) (@triarius)

## [v6.2.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.2.0) (2023-08-09)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.1.0...v6.2.0)

### Changed
- Change base image to Windows Server 2019 w/o containers and install Docker CE (v24.0.5) [#1180](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1180) (@triarius)
- Add cost allocation tags to EBS volumes [#1171](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1171) (@keatmin)

### Fixed
- Add missing authorized keys systemd units [#1184](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1184) (@sj26)
- Fix instance storage docker dir not created [#1181](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1181) (@triarius)
- Fix `set -e` fails from environment hooks [#1179](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1179) (@triarius)

## [v6.1.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.1.0) (2023-08-01)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v6.0.0...v6.1.0)

### Changed
- Bump buildkite-agent to v3.50.4 [#1177](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1177) (@DrJosh9000)
- Disable client side pager for aws-cli v2 for the buildkite-agent user [#1174](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1174) (@triarius)
- Add `ScalerMinPollInterval` param [#1173](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1173) (@amartani)

## [v6.0.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v6.0.0) (2023-07-26)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.22.2...v6.0.0)

### Changed
- Upgrade base image to Amazon Linux 2023 [#1122](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1122) (@triarius)
    - Many packages have been added, upgraded, or removed since Amazon Linux 2. We've explicitly called out what's been intentionally left out by us below. Refer to [docs.aws.amazon.com/linux/al2023/ug/compare-with-al2.html](https://docs.aws.amazon.com/linux/al2023/ug/compare-with-al2.html) for the changes Amazon have made.
- Publish template to both `main` and `master` [#1129](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1129) (@triarius)
- Increase job cancel grace period to 60s [#1144](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1144) (@triarius)
- Allow the `MaxSize` to be 0 [#1140](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1140) (@triarius)
- Default EC2 instance names to stack name [#1137](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1137) (@triarius)
- Rename the parameter `InstanceType` to `InstanceTypes` [#1138](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1138) (@triarius)
- Rename the parameter `ManagedPolicyARN` to `ManagedPolicyARNs` [#1138](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1138) (@triarius)
- Rename the parameter `SecurityGroupId` to `SecurityGroupIds` [#1128](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1128) (@triarius)
- Rename the parameter `EnableAgentGitMirrorsExperiment` to `BuildkiteAgentEnableGitMirrors` [#1123](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1123) (@triarius)
- Enable the `ansi-timestamps` setting if and only if `BuildkiteAgentTimestampLines` parameter is `"false"` [#1132](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1132) (@triarius)
- Bump buildkite-agent-scaler to v1.5.0 [#1169](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1169) (@tomellis91)
- Bump docker compose to v2.20.2 [#1150](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1150) (@triarius)
- Bump buildx to v0.11.2 [#1150](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1150) (@triarius)

### Added
- Support running and building multi-platform docker images [#1139](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1139) [#1122](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1122) [#1149](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1149) (@triarius)
- Support i4g instance types [#1138](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1138) (@triarius)
- Added the parameter `SpotAllocationStrategy` [#1130](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1130) (@triarius)
- Added the parameter `ScalerEventScheduleRate` to control rate at which buildkite-agent-scaler is invoked [#1169](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1169) (@tomellis91)

### Fixed
- Guard against `BUILDKITE_AGENT_ENABLE_GIT_MIRRORS` not being set in startup script [#1135](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1135) (@triarius)

### Removed
- Remove deprecated `SpotPrice` parameter [#1130](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1130) (@triarius)
- Removed packages. These packages are either not available on Amazon Linux 2023, or not installed by default on the base image we use. We have decided to not install them as suitable replacements may be found.
  - Python 2
  - OpenSSL v1.0
  - AWS CLI v1
  - Docker-Compose v1
    - The `docker-compose` executable will prepend the `--compatibility` flag to docker-compose v2 [#1148](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1148) (@triarius)
  - Cronie

## [v5.22.3](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.22.3) (2023-08-10)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.22.2...v5.22.3)

### Changed
- Bump buildkite-agent to v3.50.4 [#1186](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1186) (@triarius)
- Use windows server 2019 base image and docker ce [#1187](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1187) (@triarius)

## [v5.22.2](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.22.2) (2023-07-24)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.22.1...v5.22.2)

### Changed
- Bump buildkite-agent to v3.50.3 [#1164](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1164) (@DrJosh9000)

### Internal
- Set `allow_dependency_failure: true` on stack cleanup jobs [#1159](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1159) (@triarius)

## [v5.22.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.22.1) (2023-07-21)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.22.0...v5.22.1)

### Changed
- Bump buildkite-agent to v3.50.2 [#1161](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1161) (@triarius)

## [v5.22.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.22.0) (2023-07-20)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.21.0...v5.22.0)

### Changed
- Bump buildkite-agent to v3.50.1 [#1157](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1157) (@DrJosh9000)
- Handle hard failures (eg. kernel panic) during bootstrap [#1143](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1143) (@trvrnrth)
- Backport de-experimentifying git-mirrors [#1141](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1141) (@triarius)
- Enable ansi-timestamps iff BuildkiteAgentTimestampLines is false [#1132](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1132) (@triarius)
- Don't (re)install docker (on Windows) [#1136](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1136) (@triarius)

## [v5.21.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.21.0) (2023-05-25)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.20.0...v5.21.0)

### Changed
- Bump `buildkite-agent` to v3.47.0 [#1120](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1120) (@DrJosh9000)
- Bumping python from 3.7 to 3.10 [#1117](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1117) (@123sarahj123)
- Bump Docker buildx from 0.10.4 to 0.10.5 [#1119](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1119) (@orien)
- Bump `buildkite-agent-scaler` to v1.4.0 [#1118](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1118) (@triarius)

## [5.20.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/5.20.0) (2023-05-05)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.19.0...5.20.0)

### Changed
- Bump buildkite-agent to v3.46.0 [#1114](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1114) (@moskyb)
- Update description of BuildkiteAdditionalSudoPermissions parameter [#1113](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1113) (@triarius)

### Fixed
- Error with docker experimental CLI [#1106](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1106) (@moskyb)

## [v5.19.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.19.0) (2023-04-24)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.18.0...v5.19.0)

### Added
- A parameter for buildkite-agent-scaler edition and version [#1104](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1104) (@triarius)

### Fixed
- Stack failed to create because it tried to create an ACL on S3 [#1109](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1109) (@saviogl)

## [v5.18.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.18.0) (2023-03-23)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.17.0...v5.18.0)

### Changed
- Bump buildkite-agent to v3.45.0 [#1101](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1101) (@triarius)
- Bump Docker buildx from 0.10.3 to 0.10.4 [#1100](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1100) (@orien)
- Explicitly disabled public access ACLs for managed secrets buckets [#1099](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1099) (@triarius)

## [v5.17.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.17.0) (2023-02-28)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.16.1...v5.17.0)

### Added
- Support for c7gn, m7g, and r7g instance type classes with the arm64 AMI [#1095](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1095) (@triarius)
- Customise the Name tag on EC2 instances spawned by the ASG with the new InstanceName parameter [#1088](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1088) (@fd-jonathanlinn)

### Changed
- Buildkite Agent v3.44.0 [#1097](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1097) (@DrJosh9000)
- Upgrades: Docker for Linux v20.10.23, Docker compose v2.16.0, buildx v0.10.3, Linux kernel v5.15 (@mumumumu, @orien, @triarius)
- And other minor cleanups! (@moskyb, @triarius)

### Fixed
- Correct invalid SSM policy action [#1087](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1087) (@jsleeio)

## [v5.16.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.16.1) (2023-01-20)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.16.0...v5.16.1)

### Changed
- Bump buildkite-agent to v3.43.1 [#1083](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1083) (@moskyb)

## [v5.16.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.16.0) (2023-01-19)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.15.0...v5.16.0)

### Security
- Git is updated to v2.39.1 to address [recent vulnerabilities](https://github.blog/2023-01-17-git-security-vulnerabilities-announced-2/) [#1077](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1077) (@triarius)

### Added
- Access logs are now pushed to Cloudwatch for Linux instances [#1075](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1075) (@moskyb)

### Changed
- Bump buildkite-agent to v3.43.0 [#1079](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1079) (@DrJosh9000)


## [v5.15.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.15.0) (2023-01-06)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.14.0...v5.15.0)

### Added
- Enable default bucket encryption for s3 and enforce SSL [#1050](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1050) (@ckornacker)

### Changed
- Bump buildkite-agent to v3.42.0 [#1073](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1073) (@mitchbne)
- Bump Docker buildx from 0.8.2 to 0.9.1 [#1071](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1071) (@orien)
- Bump lifecycled to v3.3.0 [#1065](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1065) (@triarius)


## [v5.14.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.14.0) (2022-11-29)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.13.0...v5.14.0)

### Added
- Add property to indicate if the EBS volume is encrypted [#1057](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1057) (@pzeballos)
- Enable GroupDesiredCapacity metric collection on ASGs by default [#1064](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1064) (@atticus-rippling)

### Changed
- Bump buildkite-agent to v3.41.0 [#1069](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1069) (@triarius)

## [v5.13.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.13.0) (2022-11-10)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.12.0...v5.13.0)

### Changed
- Bump buildkite-agent to v3.40.0 [#1060](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1060) (@DrJosh9000)

## [v5.12.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.12.0) (2022-11-08)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.11.2...v5.12.0)

### Added
- Add docker compose v2 to linux [#1052](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1052) (@donbobka)

## [v5.11.2](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.11.2) (2022-10-17)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.11.1...v5.11.2)

### Fixed
- Fix log collector date command [#1048](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1048) (@jeremybumsted)

### Changed
- Bump buildkite-agent to v3.39.1 [#1054](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1054) (@triarius)

### Security
- buildkite-agent v3.39.1 contains a security update. [buildkite/agent #1781](https://github.com/buildkite/agent/pull/1781)


## [v5.11.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.11.1) (2022-08-11)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.11.0...v5.11.1)

### Fixed
- Fix permissioning error on agent scaler [#1044](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1044) (@richardkeit)

### Changed
- Add groupless cloudformation params to groups [#1042](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1042) (@moskyb)

## [5.11.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/5.11.0) (2022-07-22)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.10.0...5.11.0)

### Added
- Add code of conduct [#1038](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1038) (@moskyb)
- More advanced config options [#1030](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1030) (@moskyb)
  - A way to specify arbitrary environment variables for the agent to consume
  - The ability to specify a tracing backend for the agent to use

### Changed
- Bump buildkite-agent to v3.38.0 [#1040](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1040) (@moskyb)

### Fixed
- Add a missing permission in the service role, allowing the stack to tag lambdas [#1039](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1039) (@hcho3)

## [v5.10.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.10.0) (2022-07-13)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.9.0...v5.10.0)

### Security

- Ensure `BUILDKITE_AGENT_TOKEN` is redacted from start-up logs to CloudWatch [#1032](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1032) (@moskyb)

### Added

- Permissions boundary for Autoscaling application [#984](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/984) (@kwong-chong-lfs)

### Changed

- Bump buildkite-agent to v3.37.0 [#1035](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1035) (@pda)
- Update docker version 20.10.17 [#1033](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1033) (@hari2192)

### Fixed

- Fix IAM permissions for SSM session [#987](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/987) (@ouranos)

## [v5.9.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.9.0) (2022-05-31)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.8.2...v5.9.0)

### Added
- Allow accessing tags via instance metadata [#1016](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1016) (@jchanam)
- Add option to enable detailed EC2 monitoring [#1007](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1007) (@threesquared)
- Log collector for support/debugging [#1017](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1017) + [#1020](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1020) (@jeremybumsted)

### Changed
- Update buildkite-agent v3.35.2 -> v3.36.1 [#1021](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1021) [#1025](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1025) (@moskyb)
- Bump Linux Kernel from 4.14 to 5.10 [#994](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/994) (@orien)

## [v5.8.2](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.8.2) (2022-04-27)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.8.1...v5.8.2)

### Changed

- Update docker [#1011](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1011) (@moskyb)
  - Linux v20.10.9 -> v20.10.14
  - Windows v20.10.7 -> v20.10.9
- Bump Docker Buildx from 0.7.1 to 0.8.2 [#1003](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1003) (@orien)

## [v5.8.1](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.8.1) (2022-04-07)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.8.0...v5.8.1)

## Changed

- Update agent version from v3.35.0 to v3.35.2 [#1005](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1005) [#1009](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1009) (@moskyb)
- Add quotes around AWS variables [#1008](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/1008) (@ctgardner)

## [v5.8.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v5.8.0) (2022-03-28)
[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.7.2...v5.8.0)

### Added

- Customise docker address pools to use more, slightly smaller networks rather than a few big ones  [#968](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/968) (@ouranos)
- Add support for additional ARM/Graviton instance types: `c7g`, `g5g`, `lm4gn`, `lm4gen`, and `x2gd` [#981](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/981) [#979](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/979)  (@toothbrush + @yob)
- Add SecretsBucketRegion parameter and update s3secrets-hooks [#962](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/962) (@keithduncan)
- Add docs on updating the different components [#957](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/957) (@keithduncan)

### Changed

- `autoscaling:DescribeAutoScalingInstances` can now only be applied to all resources [#989](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/989) (@jeremiahsnapp)
- Bump buildx from 0.5.1 to 0.7.1 [#975](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/975) (@orien)
- Quieten Fixing permissions header log group [#965](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/965) (@keithduncan)
- Update issue templates [#947](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/947) (@keithduncan)
- Update agent version from 3.33.3 to v3.35.0 [#990](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/990) [#999](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/999) (@moskyb)

### Security

- Create SECURITY.md [#948](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/948) (@keithduncan)

### Fixed

- Overwrite /usr/bin/buildkite-agent symlink if it already exists [#970](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/970) (@chefsale)

## [v5.7.2](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.7.1...v5.7.2) (2021-10-29)

### Changed

* Upgrade Docker for Linux (20.10.9) and Windows (20.10.7) [#954](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/954) (@eleanorakh)
* Upgrade docker-compose for Linux (1.29.2) and Windows (1.29.2) [#954](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/954) (@eleanorakh)

### Fixed

* `BuildkiteAgentTokenParameterStorePath` support for AWS Secrets Manager SSM references [#955](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/955) (@eleanorakh)
* Build failures originating from the S3 Secrets hook [#956](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/956) (@eleanorakh)

## [v5.7.1](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.7.0...v5.7.1) (2021-10-14)

### Added

* Add new docs links to template file

## [v5.7.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.6.1...v5.7.0) (2021-09-29)

### Added

* Support for storing builds, git-mirrors, and Docker on NVMe Instance Storage [#557](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/557) ([@lox](https://github.com/lox))
* Retried login for ECR and generic Docker registries [#930](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/930)
* Experimental CloudFormation service role, listing the IAM Actions required to create, update, and delete the template [#926](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/926)
* A README feature matrix for Linux and Windows [#910](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/910)
* qemu and binfmt hooks for cross-architecture Docker image builds [#903](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/903)
* Tag pins for the included plugin [#906](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/906) ([@nitrocode](https://github.com/nitrocode))
* Support for AWS SSM sessions [#905](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/905) ([@xiaket](https://github.com/xiaket))

### Changed

* Included buildkite-agent from v3.32.3 to v3.33.3 [#932](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/932)
* `EnableDockerExperimental` also enables Docker CLI experimental mode [#911](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/911)

### Fixed

* A frequent source of build interruption caused by scale-in [#923](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/923)
* A resource ordering issue preventing instances from self terminating when a stack [#928](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/928)
* Support for `BuildkiteAdditionalSudoPermissions` with spaces [#916](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/916) ([@twunderlich-grapl](https://github.com/twunderlich-grapl))
* Finish the git lfs install [#912](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/912) ([@pauldraper](https://github.com/pauldraper))

## [v5.6.1](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.6.0...v5.6.1) (2021-09-02)

## Fixed

* Missed parameter `BuildkiteAgentTokenParameterStoreKMSKey` in `Autoscaling` nested cloudformation template [#901](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/901)

## [v5.6.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.5.1...v5.6.0) (2021-08-31)

### Added

* Cross-region secrets bucket support to git-credentials-s3-secrets [elastic-ci-stack-s3-secrets-hooks#48](https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks/pull/48)
* AssumeRole support in the ECR Login plug-in [ecr-buildkite-plugin#69](https://github.com/buildkite-plugins/ecr-buildkite-plugin/pull/69)

### Changed

* Instance IAM Profile role permissions to be more tightly scoped [#800](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/800) ([@nitrocode](https://github.com/nitrocode))
* Import buildkite-lambda-scaler from the Severless Application Repository [#685](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/685)
* The built-in environment hook no longer overwrites `AWS_REGION` and `AWS_DEFAULT_REGION` if already present [#892](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/892) ([@toothbrush](https://github.com/toothbrush))
* Included buildkite-agent from 3.32.1 to 3.32.3

### Fixed

* Hourly disk check script on Linux [#898](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/898)
* git-credentials-s3-secrets on Windows [elastic-ci-stack-s3-secrets-hooks#47](https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks/pull/47)
* PowerShell hook support on Windows [agent#1497](https://github.com/buildkite/agent/pull/1497)

## [v5.5.1](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.5.0...v5.5.1) (2021-08-06)

### Changed

* Included buildkite-agent from 3.32.0 to 3.32.1

### Fixed

* A source of unexpected instance termination causing build failures [#888](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/888)

## [v5.5.0](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v5.4.0...v5.5.0) (2021-07-30)

### Added

* Template validation rules for the Buildkite Agent token [#873](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/873)
* Secret redaction in build logs [agent#1452](https://github.com/buildkite/agent/pull/1452)
* Support for the `pre-bootstrap` Buildkite Agent Lifecycle Hook [agent#1456](https://github.com/buildkite/agent/pull/1456)

### Changed

* Included buildkite-agent from 3.30.0 to 3.32.0 [#876](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/876) ([keithduncan](https://github.com/keithduncan))

### Fixed

* Remove logging of the Buildkite Agent token to CloudWatch Logs [#879](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/879)
* Cross-region S3 bucket access for secrets [#875](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/875)
* An error when handling zero length `environment` files [elastic-ci-stack-s3-secrets-hooks#42](https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks/pull/42)
* A hang when loading ssh keys without a trailing newline [elastic-ci-stack-s3-secrets-hooks#44](https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks/pull/44)

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
