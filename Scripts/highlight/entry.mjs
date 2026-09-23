// The languages the bundle carries. Add one here and rebuild with build.sh;
// anything not listed yields no tokens and renders plain.
import hljs from "highlight.js/lib/core";

import bash from "highlight.js/lib/languages/bash";
import diff from "highlight.js/lib/languages/diff";
import json from "highlight.js/lib/languages/json";
import markdown from "highlight.js/lib/languages/markdown";
import plaintext from "highlight.js/lib/languages/plaintext";
import python from "highlight.js/lib/languages/python";
import shell from "highlight.js/lib/languages/shell";
import swift from "highlight.js/lib/languages/swift";
import xml from "highlight.js/lib/languages/xml";
import yaml from "highlight.js/lib/languages/yaml";

for (const [name, language] of Object.entries({
    bash, diff, json, markdown, plaintext, python, shell, swift, xml, yaml,
})) {
    hljs.registerLanguage(name, language);
}

globalThis.hljs = hljs;
