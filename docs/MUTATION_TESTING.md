# Mutation Testing

## What is mutation testing?

Mutation testing evaluates the **quality of your test suite** by introducing small changes (mutations) to the source code and checking whether the tests detect them.

- **Killed mutant** ✅ → Tests caught the change (good)
- **Survived mutant** ❌ → Tests missed the change (gap in coverage)

The **mutation score** (% killed) indicates how effective your tests are at catching real bugs.

## Tool

We use [`mutation_test`](https://pub.dev/packages/mutation_test) (v1.8.0+), a Dart-native mutation testing tool that works with any test command.

## Running locally

### Full mutation test (all configured files)

```bash
dart run mutation_test mutation_test.xml
```

### Single file

```bash
dart run mutation_test lib/features/match/models/match.dart
```

### Incremental (only changed files since last commit)

```bash
dart run mutation_test $(git diff --name-only HEAD~1 -- 'lib/**.dart' | grep -v '_test.dart$' | tr '\n' ' ')
```

### With coverage data (faster — skips uncovered lines)

```bash
flutter test --coverage
dart run mutation_test mutation_test.xml --coverage coverage/lcov.info
```

## Reports

Reports are generated in `mutation-test-report/` as HTML files. Open `mutation-test-report/index.html` in a browser to explore:

- Per-file mutation scores
- Surviving mutants highlighted in red (click to see the mutation)
- Quality ratings (A-E scale)

## CI Integration

After copying `docs/ci/mutation-testing.yaml` to `.github/workflows/mutation-testing.yaml`,
the GitHub Actions workflow runs:

1. **Full baseline** on pushes to `main` and weekly (Monday 6:00 UTC)
2. **Incremental** on PRs (only changed source files)

Both jobs are **non-blocking** initially (`continue-on-error: true`). To enforce a minimum mutation score, set the `failure` attribute in `mutation_test.xml`:

```xml
<threshold failure="60">
```

## Configuration

The `mutation_test.xml` file controls:

- **Which files to mutate**: `<directories>` and `<files>` elements
- **Test command**: `flutter test` (with 120s timeout)
- **Exclusion patterns**: Import statements, comments, annotations
- **Quality thresholds**: Rating scale and failure threshold

### Adding more source directories

Edit `mutation_test.xml` to include more directories as test coverage grows:

```xml
<directories>
  <directory recursive="true">lib/features/match/models/</directory>
  <directory recursive="true">lib/services/</directory>
  <!-- Add more as tests are written -->
</directories>
```

## Interpreting Results

| Rating | Score | Meaning |
|--------|-------|---------|
| A | > 80% | Excellent — tests catch most bugs |
| B | > 60% | Good — solid coverage with some gaps |
| C | > 40% | Acceptable — room for improvement |
| D | > 20% | Needs work — many untested code paths |
| E | > 0% | Critical — tests are ineffective |

### What to do with surviving mutants

1. Open the HTML report
2. Find red-highlighted lines (surviving mutants)
3. Click to see what was changed
4. Write a test that would catch that specific change
5. Re-run mutation testing to verify the mutant is now killed

## References

- [`mutation_test` on pub.dev](https://pub.dev/packages/mutation_test)
- [Mutation Testing on Wikipedia](https://en.wikipedia.org/wiki/Mutation_testing)
- [Issue #37](https://github.com/grunch/choke/issues/37) — Tracking issue
