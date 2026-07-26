import re, json, os

vault = "C:/Users/User/Documents/OCBC Vault/Wheels/HK Market Makes"
makes = {}

for fn in sorted(os.listdir(vault)):
    if not fn.endswith('.md'): continue
    make_name = fn.replace('.md', '').replace('Audi VW', 'Audi').replace('Hyundai Kia', 'Hyundai')
    path = os.path.join(vault, fn)
    with open(path, encoding='utf-8') as f:
        text = f.read()
    
    models = []
    sections = re.split(r'^### ', text, flags=re.MULTILINE)
    for sec in sections[1:]:
        lines = sec.strip().split('\n')
        model_name = lines[0].strip()
        model_name = re.sub(r'\s*\(.*\)\s*$', '', model_name).strip()
        
        generations = []
        in_table = False
        for line in lines:
            if '|' in line and 'Generation' in line and 'Year' in line:
                in_table = True
                continue
            if in_table and line.strip().startswith('|') and line.count('|') >= 6:
                cells = [c.strip() for c in line.split('|')]
                if len(cells) >= 8:
                    generations.append({
                        'name': cells[1], 'year': cells[2], 'pcd': cells[3],
                        'offset': cells[4], 'cb': cells[5], 'thread': cells[6], 'torque': cells[7],
                    })
            elif in_table and (not line.strip().startswith('|') or line.strip() == '|'):
                in_table = False
        
        tyre_sizes = []
        rim_sizes = []
        joined = '\n'.join(lines)
        m_tyre = re.search(r'\*\*Common OEM tyre sizes?\*\*:\s*(.+?)(?:\n|$)', joined)
        if m_tyre:
            tyre_sizes = [s.strip() for s in m_tyre.group(1).split(',')]
        m_rim = re.search(r'\*\*Common OEM rim sizes?\*\*:\s*(.+?)(?:\n|$)', joined)
        if m_rim:
            rim_sizes = [s.strip() for s in m_rim.group(1).split(',')]
        
        if generations or tyre_sizes:
            models.append({
                'name': model_name,
                'generations': generations,
                'tyreSizes': tyre_sizes,
                'rimSizes': rim_sizes,
            })
    
    if models:
        makes[make_name] = {'models': models}

print(f"Parsed {len(makes)} makes from vault")

# Write JSON
out_dir = "C:/Users/User/Documents/tyre_stock_app/assets"
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, 'fitment_data.json'), 'w', encoding='utf-8') as f:
    json.dump(makes, f, ensure_ascii=False, indent=2)

print(f'Written: {os.path.getsize(os.path.join(out_dir, "fitment_data.json"))} bytes')
print(f'Makes: {len(makes)}')
total_models = sum(len(v['models']) for v in makes.values())
print(f'Models: {total_models}')
