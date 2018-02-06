const fs = require('fs');
const glob = require('glob');
const yaml = require('js-yaml');
const extendify = require('extendify');
const replace = require("replace");
const { schema } = require('yaml-cfn');

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
    try {
      return yaml.safeLoad(fs.readFileSync(f, 'utf8'), {
        schema: schema,
        noRefs: false,
      });
    } catch (e) {
      console.error("Failed to parse %s", f, e);
      process.exit(1);
    }
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

  const version = process.argv[2] || 'dev';

  // set a description
  sorted.Description = "Buildkite stack " + String(version).trim();
  console.log(sorted.Description);

  // clone the object, otherwise js-yaml uses anchors which aren't supported by cfn
  var userData = JSON.parse(JSON.stringify(sorted.Resources.AgentLaunchConfiguration.Properties.UserData));

  console.log(userData);

  for(var idx in sorted.Resources.SpotFleet.Properties.SpotFleetRequestConfigData.LaunchSpecifications) {
    sorted.Resources.SpotFleet.Properties.SpotFleetRequestConfigData.LaunchSpecifications[idx].UserData = userData;
  }

  fs.existsSync("build") || fs.mkdirSync("build");
  console.log("Generating build/aws-stack.yml");
  fs.writeFileSync("build/aws-stack.yml", yaml.safeDump(sorted));

  console.log("Generating build/aws-stack.json");
  fs.writeFileSync("build/aws-stack.json", JSON.stringify(sorted, null, 2));

  console.log("Updating BUILDKITE_STACK_VERSION to %s", version);
  replace({
    regex: "BUILDKITE_STACK_VERSION=dev",
    replacement: "BUILDKITE_STACK_VERSION="+version,
    paths: ['build/aws-stack.json','build/aws-stack.yml'],
    recursive: false,
    silent: true,
  });
});
