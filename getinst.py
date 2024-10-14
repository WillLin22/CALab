import re
with open('mycpu_top.v') as f:
    content = f.read()
insts = re.findall(r'(inst(_[a-z]+)+) ',content)
print(' | '.join(set(i[0] for i in insts)))