# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.1] - 2025-12-24

### Changed

- Upgrade cargo dist to using macos-14 on github actions when building
  release binaries


## [2.0.0] - 2025-12-24

### Added

- Show coinbase distribution in grafana dashboard
- Upgrade to p2poolv2 hydrapool.v0.4.0

### Changed

- BREAKING: Use bitcoin compatible serialisation of shares in
  database. This requires that you nuke your existing store.db
  directory and start the server from no data. We want to make this
  change early before any servers are using Hydrapool at scale. We are
  not shipping a script to migrate existing data - if you really need
  it, please reach out to us and we'll try to make it work for
  you. Ideally, a PR will be welcome too with a script to migrate the
  rocksdb data.
- Update README with auth instructions on securing the server
- Use 256Foundation's address as default mainnet config


## [1.1.18] - 2025-10-31

### Fixed

- Change how we trigger docker build


## [1.1.17] - 2025-10-31

### Fixed

- Give package write permissions to build docker workflow

## [1.1.16] - 2025-10-31

### Fixed

- Prometheus docker image

## [1.1.15] - 2025-10-31

### Fixed

- Add extra artifacts for config and docker compose to release

## [1.1.14] - 2025-10-31

### Added

- Cosign docker images
- Add docker compose and config example to release
- Add docker compose instruction as primary way to run pool
- Support custom prometheus authentication

### Deprecated

- Ansible templates are not being maintained. We might bring them back
  in the future.
- Enable running workflows from github tags page.
- Sign docker images with cosign

## [1.1.13] - 2025-10-30

### Added

- Add docker files for hydrapool, grafana and prometheus
- Add a docker compose file for ease of use for end users
- Add docker build work flow to build docker images on github actions

## [1.1.12] - 2025-10-29

### Fixed

- Fix write permission for writing debian package from workflow

## [1.1.11] - 2025-10-29

### Fixed

- Book keeping fix for tag

## [1.1.10] - 2025-10-29

### Fixed

- Fix debian package failure to get release tag

## [1.1.9] - 2025-10-29

### Added

- Add debian package workflow using cargo-deb

[unreleased]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.18...HEAD
[1.1.18]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.17...v1.1.18
[1.1.17]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.16...v1.1.17
[1.1.16]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.15...v1.1.16
[1.1.15]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.14...v1.1.15
[1.1.14]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.13...v1.1.14
[1.1.13]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.12...v1.1.13
[1.1.12]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.11...v1.1.12
[1.1.11]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.10...v1.1.11
[1.1.10]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.9...v1.1.10
[1.1.9]: https://github.com/256-foundation/Hydra-Pool/compare/v1.1.8...v1.1.9

