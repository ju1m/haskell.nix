# Coverage

haskell.nix can generate coverage information for your package or
project using Cabal's inbuilt hpc support.

## Per-package

```bash
nix-build default.nix -A "$pkg.coverageReport'"
```

This will generate a coverage report for the package you requested. By
default, all tests that are enabled (configured with
`doCheck == true`) are included in the coverage report.

See the [developer coverage docs](../dev/coverage.md#package-reports) for more information.

## Project-wide

```bash
nix-build default.nix -A "projectCoverageReport'"
```

This will generate a coverage report for all the local packages in
your project.

See the [developer coverage docs](../dev/coverage.md#project-wide-reports) for more information.

## Custom

haskell.nix also exposes two functions which allow you to generate
custom coverage reports: `coverageReport` and `projectCoverageReport`.
These are found in the haskell.nix library:

```nix
let
  inherit (pkgs.haskell-nix) haskellLib;

  project = pkgs.haskell-nix.project {
    # 'cleanGit' cleans a source directory based on the files known by git
    src = pkgs.haskell-nix.haskellLib.cleanGit {
      name = "haskell-nix-project";
      src = ./.;
    };
    # For `cabal.project` based projects specify the GHC version to use.
    compiler-nix-name = "ghc884"; # Not used for `stack.yaml` based projects.
  };

  custom$pkgCoverageReport = haskellLib.coverageReport {
    inherit (project.$pkg.identifier) name version;
    inherit (project.$pkg.components) library tests;
  };

  customProjectCoverageReport = haskellLib.projectCoverageReport {
    packages                = haskellLib.selectProjectPackages project;
    coverageReportOverrides = { "${project.$pkg.identifier.name}" = custom$pkgCoverageReport; };
  };
in project // {
  inherit custom$pkgCoverageReport customProjectCoverageReport;
}

```
