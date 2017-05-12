const fs = require('fs');
const glob = require('glob');
const yaml = require('js-yaml');
const extendify = require('extendify');

glob("templates/*.yml", function (er, files) {
  const contents = files.map(f => {
    return yaml.safeLoad(fs.readFileSync(f, 'utf8'));
  });
  const extend = extendify({
    inPlace: false,
    isDeep: true
  });
  const merged = contents.reduce(extend);
  console.log("Generating build/aws-stack.json");
  fs.existsSync("build") || fs.mkdirSync("build");
  fs.writeFileSync("build/aws-stack.yaml", yaml.safeDump(merged));
  fs.writeFileSync("build/aws-stack.json", JSON.stringify(merged, null, 2));
});