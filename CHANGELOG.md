# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-05-26

### Added
- Terraform module to deploy SSM Agent ping alert infrastructure.
- AWS Systems Manager (SSM) configurations tracking ping statuses.
- Automated email alerts routed to specified targets.
- Structured variable mapping for custom threshold configurations and target tags.
- Dedicated `docs/` workspace including step-by-step `DEPLOYMENT.md` documentation.
- `versions.tf` configuration pinning the required AWS providers and Terraform versions.
