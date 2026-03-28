# Dependency Upgrade Design

## Goal

Upgrade all managed dependencies in the repository to the latest current stable
or latest mutually compatible versions, including major upgrades, while keeping
the existing local test suite passing at the end of the work.

The upgrade scope includes:

- Flutter SDK and Dart toolchain selection
- Dart and Flutter packages in `app/pubspec.yaml`
- PocketBase binaries used for local development, local tests, and CI
- Docker base images and runtime containers
- Browser test tooling, including Chrome and ChromeDriver pairing
- GitHub Actions versions and related automation metadata
- Dependabot coverage for the versioned surfaces above

If the latest releases are incompatible with each other, the implementation must
either use the newest mutually compatible version set or replace the dependency
with a viable alternative. Indefinite stale pins are out of scope.

## Current Repository Findings

The repository already shows version drift across execution contexts, which is
the main design problem this upgrade should solve.

- The Flutter app is defined in `app/pubspec.yaml` and currently targets Dart
  `^3.8.1`.
- `flutter pub outdated` shows minor direct package drift plus at least one
  direct major-upgrade candidate (`share_plus`).
- CI partially pins Flutter through `subosito/flutter-action`, while Docker
  build and local test images use `ghcr.io/cirruslabs/flutter:stable`, which is
  not reproducible over time.
- PocketBase is pinned separately in `Dockerfile.dev`,
  `docker/local-test/Dockerfile`, and `.github/workflows/test.yml`, which makes
  version alignment easy to break.
- Browser integration testing depends on explicit Chrome and ChromeDriver
  coordination. Repository memory indicates past failures from version mismatch.
- Dependabot exists, but the repository still relies on duplicated version
  literals and floating toolchain references.

This means the upgrade should not be treated as isolated package bumps. It is a
repository-wide compatibility and reproducibility effort.

## Recommended Approach

Use a synchronized full-stack upgrade strategy with one repository baseline.

This baseline defines the target versions for:

- Flutter stable release
- The Dart SDK that comes with that Flutter release
- Direct and transitive pub package set after compatibility resolution
- PocketBase release
- Docker base images used for app build and local tests
- Browser automation binaries used in local and CI integration tests
- GitHub Actions versions and dependency automation coverage

The recommendation is to treat this as one coordinated upgrade initiative, but
execute it in a controlled order so failures can be attributed correctly.

## Architecture

The upgrade design is organized around a single compatibility matrix for the
repository. No file should independently choose a version once the matrix is
defined.

The repository should be treated as four upgrade domains:

1. Application dependencies
2. Runtime and backend dependencies
3. Test and browser infrastructure
4. Automation and repository metadata

Each domain can be validated separately, but all of them must resolve back to
the same target baseline.

The design also requires reducing version ownership ambiguity:

- Remove floating tool versions where reproducibility matters.
- Collapse duplicate version literals where practical.
- Make version ownership obvious so future upgrades are routine instead of
  archaeological.

## Components And Flow

The implementation should follow five checkpoints.

### 1. Establish the target baseline

Pick the latest stable Flutter release as the anchor. From that anchor,
determine:

- the corresponding Dart version
- the latest compatible pub package set
- the latest PocketBase release suitable for this codebase
- the latest current versions of GitHub Actions dependencies
- the current browser automation pairing needed for integration testing

This produces a concrete compatibility matrix before version edits begin.

### 2. Normalize version ownership

Replace scattered literals with clearer ownership rules.

- Flutter and related tooling should have one canonical definition per context.
- PocketBase should not be hardcoded independently in multiple places without a
  documented source of truth.
- Browser automation should remain explicitly version-matched wherever
  reproducibility matters.

The design does not require inventing a complicated version-management system.
It does require reducing hidden drift.

### 3. Upgrade by dependency order

Use this order:

1. Toolchain baseline
2. App packages
3. Backend and runtime artifacts
4. Automation and CI metadata
5. Cleanup and documentation

This order is intentional. Package compatibility depends on the selected Flutter
and Dart baseline, and the final test environment must reflect the final runtime
decisions.

### 4. Resolve incompatibilities explicitly

When a major upgrade fails, classify the blocker before changing code.

Each incompatibility should be treated as one of:

- direct code adaptation required
- dependency constraint conflict
- obsolete dependency that should be replaced
- infrastructure behavior drift introduced by the new toolchain

If the latest versions are not mutually compatible, the upgrade should select
the newest compatible version combination or swap in an alternative dependency.

### 5. Validate incrementally

Validation should widen over time rather than happen only once at the end.

For each domain, start with the smallest useful verification and then expand to
broader system checks.

## Error Handling Strategy

Major upgrade failures are most likely to show up in three places:

- Flutter and plugin API drift
- PocketBase behavior changes affecting hooks, migrations, or app assumptions
- browser-driven integration instability caused by Chrome and ChromeDriver
  changes

The upgrade effort should handle failures as classification problems first.
Every failure should be sorted into one of four buckets:

1. Code adaptation required
2. Latest-version incompatibility requiring newest compatible choice
3. Dependency replacement candidate
4. Test or infrastructure flake introduced by environment drift

This avoids wasting time treating every failing test as an application defect.

## Testing Strategy

The completion gate for the upgrade is the existing local test suite passing on
the final dependency baseline.

Validation should proceed in this order:

1. Dependency resolution on the final toolchain
2. Static checks such as analyzer or lint validation as needed for the new
   baseline
3. Flutter unit and widget tests
4. Local Docker-backed integration execution

For this repository, passing `flutter test` alone is not enough. The final check
must include the Docker-based local integration path because Chrome,
ChromeDriver, PocketBase, and Flutter web behavior all interact there.

If tests fail during the upgrade, the implementation should document whether the
failure is:

- a real regression introduced by the upgrade
- an outdated test assumption
- a compatibility exception requiring an alternative version or dependency
- a coverage gap that leaves the upgrade under-verified

Coverage expansion is not a primary deliverable, but missing coverage that
blocks confidence in a dependency swap should be called out during execution.

## Repository-Specific Requirements

The implementation plan should include the following repository-specific checks:

- Verify `app/pubspec.yaml` and `app/pubspec.lock` against the selected Flutter
  baseline.
- Reconcile Flutter version selection between CI and Docker images so the repo
  stops mixing fixed and floating versions.
- Reconcile PocketBase versions across `Dockerfile.dev`,
  `docker/local-test/Dockerfile`, and `.github/workflows/test.yml`.
- Preserve explicit Chrome and ChromeDriver compatibility checks in local test
  flows because this repository has already experienced mismatch failures.
- Review Dependabot coverage after the normalization work so all maintained
  dependency surfaces remain monitored.

## Non-Goals

The upgrade should not broaden into unrelated refactoring.

Out of scope unless directly required by compatibility work:

- redesigning application architecture
- changing product behavior unrelated to dependency breakage
- general test-suite rewrites beyond what the new baseline requires
- speculative cleanup that does not improve upgradeability or reproducibility

## Definition of Done

The upgrade work is complete when all of the following are true:

1. All managed dependency surfaces in scope have been reviewed and upgraded to
   latest stable or latest mutually compatible versions.
2. Any incompatibility exception is justified by documented compatibility
   research or an approved dependency replacement.
3. Version drift between local development, local tests, and CI has been
   reduced to a clearly owned and reproducible baseline.
4. The existing local tests pass on the final dependency baseline.

## Plan Inputs

The implementation plan derived from this design should answer these concrete
questions:

- What exact Flutter stable release is the target baseline?
- Which direct pub dependencies require code changes or replacements?
- What is the final PocketBase target version and what compatibility checks are
  needed for hooks and migrations?
- Where should version ownership live so future upgrades do not drift again?
- What local validation commands prove the final baseline is working?
