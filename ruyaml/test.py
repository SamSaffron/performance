from ruamel.yaml import YAML
import sys

example = """
# hello
test: "test\\ntest\\ntest" # a test
test2: hello.. #world
"""

rt_yaml=YAML(typ='rt')

parsed = rt_yaml.load(example)
parsed['world'] = "hello"
parsed['test2'] = "test2"

rt_yaml.dump(parsed, sys.stdout)


# output:

# # hello
# test: "test\ntest\ntest" # a test
# test2: test2   #world
# world: hello


