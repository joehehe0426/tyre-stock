import json

with open('assets/fitment_data.json') as f:
    d = json.load(f)

# Split Audi+VW and Hyundai+Kia
if 'Audi' in d:
    audi_models = []
    vw_models = []
    for m in d['Audi']['models']:
        name = m['name']
        if name.startswith('Audi '):
            m['name'] = name[5:]
            audi_models.append(m)
        elif name.startswith('Volkswagen '):
            m['name'] = name[11:]
            vw_models.append(m)
        else:
            audi_models.append(m)
    d['Audi']['models'] = audi_models
    if vw_models:
        d['Volkswagen'] = {'models': vw_models}

if 'Hyundai' in d:
    hyundai_models = []
    kia_models = []
    for m in d['Hyundai']['models']:
        name = m['name']
        if name.startswith('Hyundai '):
            m['name'] = name[8:]
            hyundai_models.append(m)
        elif name.startswith('Kia '):
            m['name'] = name[4:]
            kia_models.append(m)
        else:
            hyundai_models.append(m)
    d['Hyundai']['models'] = hyundai_models
    if kia_models:
        d['Kia'] = {'models': kia_models}

# Standardize generation keys to 'n','y','p','o','c','t','q' throughout
for make_key in list(d.keys()):
    for m in d[make_key]['models']:
        # Convert 'generations' -> 'g' if needed
        if 'generations' in m:
            m['g'] = m.pop('generations')
        # Convert 'tyreSizes' -> 'ts', 'rimSizes' -> 'rs'
        if 'tyreSizes' in m:
            m['ts'] = m.pop('tyreSizes')
        if 'rimSizes' in m:
            m['rs'] = m.pop('rimSizes')
        # Normalize gen keys
        for gen in m.get('g', []):
            mapping = {'name':'n','year':'y','pcd':'p','offset':'o','cb':'c','thread':'t','torque':'q'}
            for old_k, new_k in mapping.items():
                if old_k in gen and new_k not in gen:
                    gen[new_k] = gen.pop(old_k)

# Split Chinese EVs into separate brands
if 'Chinese EVs' in d:
    cev = d.pop('Chinese EVs')
    brand_map = {
        'BYD': ['BYD Atto 3', 'BYD Seal', 'BYD Dolphin', 'BYD Han'],
        'Zeekr': ['Zeekr 001', 'Zeekr 007', 'Zeekr X', 'Zeekr 009'],
        'Nio': ['Nio ET5', 'Nio ET5T', 'Nio ET7', 'Nio ES6', 'Nio ES8'],
        'XPeng': ['XPeng G6', 'XPeng G9', 'XPeng P7', 'XPeng X9'],
        'Xiaomi': ['Xiaomi SU7'],
    }
    for brand, names in brand_map.items():
        filtered = [m for m in cev['models'] if any(n in m.get('name','') for n in names)]
        if filtered:
            for m in filtered:
                m['name'] = m['name'].replace(brand + ' ', '').replace(brand.upper() + ' ', '')
            d[brand] = {'models': filtered}

# Strip make prefix from model names everywhere
for make_key in list(d.keys()):
    for m in d[make_key]['models']:
        name = m['name']
        if name.startswith(make_key + ' '):
            m['name'] = name[len(make_key)+1:]
        elif name.startswith(make_key.upper() + ' '):
            m['name'] = name[len(make_key.upper())+1:]

with open('assets/fitment_data.json', 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)

total_models = sum(len(v['models']) for v in d.values())
print(f'Makes: {len(d)}, Models: {total_models}')
for k in sorted(d.keys()):
    print(f'  {k:20s}  {len(d[k]["models"]):3d} models')
