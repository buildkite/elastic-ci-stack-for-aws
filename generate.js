const fs = require('fs');
const glob = require('glob');
const yaml = require('js-yaml');
const extendify = require('extendify');
const proc = require('child_process');

const sortOrder = [
  'AWSTemplateFormatVersion',
  'Description',
  'Parameters',
  'Mappings',
  'Conditions',
  'Resources',
  'Metadata',
  'Outputs',
]

glob("templates/*.yml", function (er, files) {
  const contents = files.map(f => {
    return yaml.safeLoad(fs.readFileSync(f, 'utf8'));
  });
  const extend = extendify({
    inPlace: false,
    isDeep: true
  });

  var merged = contents.reduce(extend);
  var sorted = {};

  // sort by a specific key order
  var keys = Object.keys(merged).sort(function(a,b){
    return sortOrder.indexOf(a) - sortOrder.indexOf(b);
  });

  for(var index in keys) {
    var key = keys[index];
    sorted[key] = merged[key];
  }

  const version = proc.execSync('git describe --tags --candidates=1');

  // set a description
  sorted.Description = "Buildkite stack " + String(version).trim();

  fs.existsSync("build") || fs.mkdirSync("build");
  console.log("Generating build/aws-stack.yml");
  fs.writeFileSync("build/aws-stack.yml", yaml.safeDump(sorted));

  console.log("Generating build/aws-stack.json");
  fs.writeFileSync("build/aws-stack.json", JSON.stringify(sorted, null, 2));
});