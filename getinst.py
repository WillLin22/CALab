import re
insts = re.findall(r'(inst(_[a-z0-9]+)+) ',open('mycpu_top.v').read())
ckinst = lambda s: not any(i in s for i in ['sram','reg'])
print(' | '.join(set(i[0] for i in insts if ckinst(i[0]))))