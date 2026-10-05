{ runCommand, playwrightCore }:
runCommand "keyfarm-pw" { } ''
  mkdir -p "$out/lib/node_modules"
  cp ${../pw}/package.json ${../pw}/keyfarm.ts ${../pw}/runner.ts "$out/lib/"
  ln -s ${playwrightCore} "$out/lib/node_modules/playwright-core"
''
