# eMudhra trust remediation (20 October 2026)

Source: https://emudhra.we-have-a-problem.com/ (consulted 21 October 2026).
`roots/*.crt` are the four affected trust anchors from the incident's `roots.json`;
the SHA-256 DER fingerprints are pinned in both validators. These public
certificates are needed to install explicit distrust, not to grant trust.

## Coverage

- Stable Buildkite agent: 4.7.0 on both platforms. Unstable/latest is intentionally
  unchanged; it tracks main, which already includes the incident fix. No Buildkite
  CLI is installed by this repository; none is introduced.
- AL2023 (including the fixed CIS source AMI): update the CA/p11-kit packages from
  `--releasever=latest`, not just the source AMI's locked repository snapshot;
  explicitly blocklist the affected roots and regenerate the extracted stores.
- Ubuntu 24.04: require at least the vendor-patched
  `20260816ubuntu0.24.04.1` CA package; persist the incident's two documented root
  exclusions and regenerate the store. Both architectures use the same script.
- Windows: put all four affected roots in LocalMachine/Disallowed **before**
  Chocolatey/other HTTPS downloads. Do not depend on online revocation or assume a
  recent Server 2022 AMI received the Microsoft disallowed-list update.
- Git for Windows ships native OpenSSL and MSYS CA bundles; remove the affected
  roots from both, independently of Windows CryptoAPI. Discover the native bundle
  under the installed prefix (`mingw64` before Git 2.56, `ucrt64` from 2.56), and
  require the separate `usr/ssl/certs/ca-bundle.crt` bundle too. Do not change
  Git's TLS backend.
- AWS CLI 2.37.10 bundles `awscli/botocore/cacert.pem` on both platforms
  ([source](https://github.com/aws/aws-cli/blob/2.37.10/awscli/botocore/httpsession.py)).
  Filter and validate that actual installed file, not just the OS store. This is
  a local incident workaround: reinstalling/upgrading AWS CLI or Git can replace
  the file and requires reapplying/validating the remediation.
- s3secrets-helper 2.9.0 uses the AWS SDK's default Go HTTP transport
  ([source](https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks/blob/v2.9.0/s3secrets-helper/s3/s3.go)).
  lifecycled 3.6.0 similarly uses default AWS sessions
  ([source](https://github.com/buildkite/lifecycled/blob/v3.6.0/cmd/lifecycled/main.go)).
  Neither installs an embedded trust bundle in this stack. Their default trust is
  the OS store (Go CryptoAPI on Windows); no speculative version bump is made.
  This is a source assessment, not per-binary endpoint validation.

Root removal also distrusts unrelated certificates issued beneath those roots.
Custom CA bundles, TLS overrides, user-installed runtimes, container images,
plugins and customer workloads are not covered by host trust changes. This is
not a claim that every bundled or workload HTTPS client is remediated.

## Validation and rebuilding

Provisioning fails if affected roots remain in the effective Linux system bundle
or the AWS CLI/Git PEM bundles, or if Windows explicit distrust is missing.
Nonempty-bundle and stable-agent-version checks run in the hosted image tests.
The unrelated certificate in `tests/trust` exercises preservation of safe roots
in local unit tests; it is not copied into images.

[Build 6893](https://buildkite.com/buildkite-aws-stack/buildkite-aws-stack/builds/6893)
qualified fresh base/final images and runtime behavior for all six variants using
the twelve published incident chains, issuer-not-found checks at the capture date,
and an unrelated positive trust control. Those incident-specific chain fixtures
and checks were subsequently removed; ongoing image checks retain only the
blocked-root guards. The full qualification suite remains in that build's commit
(`70ed5d305d43da6b686796aa1c7b82ef062ad193`).

Local unit command (Python 3, no network required):

```sh
python3 -m unittest discover -s tests/trust -v
```

Windows PEM bundle regression tests (PowerShell 7, fresh process):

```sh
pwsh -NoProfile -File tests/windows/test-trust.ps1
```

These tests exercise real PEM filtering and file writes for both Git layouts,
but simulate Windows discovery and distrust-store lookup and use an empty custom
chain trust store. They do not replace fresh Windows image validation.

Shared trust inputs invalidate **both base caches**, and the existing packer
filters select all final images. Rebuild fresh bases **and** final images for
AL2023 AMD64/ARM64, Ubuntu AMD64/ARM64, Windows AMD64 and private CIS AL2023 AMD64.
Do not reuse an old cached/custom `BASE_AMI_ID`. Package updates happen in the
base layer; merely rebuilding final images is insufficient.

Changes to provisioning still require fresh image validation before release.
The root checks cover code-signing anchors, not end-to-end Authenticode execution
policy behavior.
