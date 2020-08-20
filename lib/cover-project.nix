{ pkgs, lib, haskellLib }:

# List of project packages to generate a coverage report for
{ packages
, coverageReportOverrides ? {}
}:

let
  getPackageCoverageReport = packageName: (coverageReportOverrides."${packageName}" or packages."${packageName}".coverageReport');

  # Create table rows for an project coverage index page that look something like:
  #
  # | Package          | TestSuite |
  # |------------------+-----------|
  # | cardano-shell    | test-1    |
  # |                  | test-2    |
  # | cardano-launcher | test-1    |
  # |                  | test-2    |
  #
  # The logic is a little complex to ensure that only the first test
  # is listed alongside the package, the second test is accompanied by
  # a blank 'Package' entry.
  packageTableRows = package: with lib;
    let
      testsOnly = filterAttrs (n: d: isDerivation d) package.components.tests;
      testNames = mapAttrsToList (testName: _: testName) testsOnly;
      firstPosition = 1;
      positions = range firstPosition (length testNames);
      testNamesWithPosition = zipLists positions testNames;
      isFirst = pos: pos == firstPosition;
    in
      concatStringsSep "\n" (map (tuple:
        let
          pos = tuple.fst;
          testName = tuple.snd;
        in ''
      <tr>
        <td>
          ${if isFirst pos then ''
          <a href="${package.identifier.name}-${package.identifier.version}/hpc_index.html">${package.identifier.name}</href>
          '' else ""} 
        </td>
        <td>
          <a href="${testName}/hpc_index.html">${testName}</a>
        </td>
      </tr>
    '') testNamesWithPosition);

  projectIndexHtml = pkgs.writeText "index.html" ''
  <html>
    <head>
      <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    </head>
    <body>
      <table border="1" width="100%">
        <tbody>
          <tr>
            <th>Package</th>
            <th>TestSuite</th>
          </tr>

          ${with lib; concatStringsSep "\n" (mapAttrsToList (_ : packageTableRows) packages)}

        </tbody>
      </table>
    </body>
  </html>
  '';
in pkgs.runCommand "project-coverage-report"
  { buildInputs = (with pkgs; [ghc]); }
  ''
    mkdir -p $out/share/hpc/tix/all
    mkdir -p $out/share/hpc/mix/
    mkdir -p $out/share/hpc/html/

    findMixDir() {
      find $1 -iwholename "*/hpc/vanilla/mix" -exec find {} -maxdepth 1 -type d -iwholename "*/mix/*" \; -quit
    }

    findCabalFile() {
      find $1 -iname "*.cabal" -print -quit
    }

    # Create tix file with test run information for all packages
    tixFile="$out/share/hpc/tix/all/all.tix"
    hpcSumCmd=("hpc" "sum" "--union" "--output=$tixFile")
    tixFiles=()

    ${with lib; concatStringsSep "\n" (mapAttrsToList (n: package: ''
      identifier="${package.identifier.name}-${package.identifier.version}"
      report=${getPackageCoverageReport n}
      tix="$report/share/hpc/tix/$identifier/$identifier.tix"
      if test -f "$tix"; then
        tixFiles+=("$tix")
      fi

      # Copy mix and tix information over from each report
      cp -R $report/share/hpc/mix/* $out/share/hpc/mix
      cp -R $report/share/hpc/tix/* $out/share/hpc/tix
      cp -R $report/share/hpc/html/* $out/share/hpc/html
    '') packages)}

    if [ ''${#tixFiles[@]} -ne 0 ]; then
      hpcSumCmd+=("''${tixFiles[@]}")
      echo "''${hpcSumCmd[@]}"
      eval "''${hpcSumCmd[@]}"

      cp ${projectIndexHtml} $out/share/hpc/html/index.html
    fi
  ''
