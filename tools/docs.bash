set -o errexit -o nounset

spell() {
  python -c "
import re
x = open('README.md').read()
x = re.sub('"'```.*?```'"', '', x, flags=re.DOTALL)
x = re.sub('\`.*?\`|^    .*$', '', x, flags=re.MULTILINE)
print x
  " > /tmp/out
  aspell check /tmp/out
}

"$@"
