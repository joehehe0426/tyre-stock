import json

# Read current data
with open('assets/fitment_data.json') as f:
    d = json.load(f)

# Chinese EV data from original (git stash the old version first, or just hardcode)
chinese_ev_data = {
    'BYD': {'models': [
        {'name':'Atto 3', 'g':[{'n':'All','y':'2022+','p':'5x114.3','o':'ET42','c':'64.1mm','t':'M12x1.5','q':'110Nm'}], 'ts':['215/55R18','235/50R19'], 'rs':['7Jx18 ET42','7.5Jx19 ET40']},
        {'name':'Seal', 'g':[{'n':'All','y':'2023+','p':'5x120','o':'ET35-42','c':'64.1mm','t':'M14x1.5','q':'140Nm'}], 'ts':['235/45R18','235/40R19','245/40R19'], 'rs':['8Jx18 ET40','8.5Jx19 ET38','8.5Jx20 ET35']},
        {'name':'Dolphin', 'g':[{'n':'All','y':'2023+','p':'5x114.3','o':'ET45','c':'64.1mm','t':'M12x1.5','q':'110Nm'}], 'ts':['195/60R16','205/50R17'], 'rs':['6Jx16 ET45','6.5Jx17 ET45']},
        {'name':'Han', 'g':[{'n':'All','y':'2022+','p':'5x120','o':'ET38-45','c':'64.1mm','t':'M14x1.5','q':'140Nm'}], 'ts':['245/45R19','245/40R20'], 'rs':['8.5Jx19 ET40','9Jx20 ET38']},
    ]},
    'Zeekr': {'models': [
        {'name':'001', 'g':[{'n':'All','y':'2022+','p':'5x108','o':'ET38-42','c':'63.4mm','t':'M14x1.5','q':'135Nm'}], 'ts':['255/45R21','265/40R22'], 'rs':['9Jx21 ET42','9.5Jx22 ET38']},
        {'name':'007', 'g':[{'n':'All','y':'2024+','p':'5x108','o':'ET38-42','c':'63.4mm','t':'M14x1.5','q':'135Nm'}], 'ts':['245/45R20'], 'rs':['8.5Jx20 ET40']},
        {'name':'X', 'g':[{'n':'All','y':'2023+','p':'5x108','o':'ET38-42','c':'63.4mm','t':'M14x1.5','q':'135Nm'}], 'ts':['235/50R19'], 'rs':['8Jx19 ET40']},
        {'name':'009', 'g':[{'n':'All','y':'2023+','p':'5x108','o':'ET40-45','c':'63.4mm','t':'M14x1.5','q':'135Nm'}], 'ts':['265/45R20'], 'rs':['9Jx20 ET42']},
    ]},
    'Nio': {'models': [
        {'name':'ET5', 'g':[{'n':'All','y':'2023+','p':'5x120','o':'ET38-45','c':'62.6mm','t':'M14x1.5','q':'140Nm'}], 'ts':['245/45R19','245/40R20'], 'rs':['8.5Jx19 ET40','8.5Jx20 ET38']},
        {'name':'ET7', 'g':[{'n':'All','y':'2022+','p':'5x120','o':'ET35-42','c':'62.6mm','t':'M14x1.5','q':'140Nm'}], 'ts':['245/45R20','255/40R21'], 'rs':['8.5Jx20 ET38','9Jx21 ET35']},
        {'name':'ES6', 'g':[{'n':'All','y':'2023+','p':'5x120','o':'ET38-45','c':'62.6mm','t':'M14x1.5','q':'140Nm'}], 'ts':['255/50R20','265/45R21'], 'rs':['9Jx20 ET40','9.5Jx21 ET38']},
        {'name':'ES8', 'g':[{'n':'All','y':'2023+','p':'5x120','o':'ET38-45','c':'62.6mm','t':'M14x1.5','q':'140Nm'}], 'ts':['255/55R20','265/45R21'], 'rs':['9Jx20 ET40','9.5Jx21 ET38']},
    ]},
    'XPeng': {'models': [
        {'name':'G6', 'g':[{'n':'All','y':'2023+','p':'5x112','o':'ET40-45','c':'60.1mm','t':'M14x1.5','q':'130Nm'}], 'ts':['235/55R19','255/45R20'], 'rs':['8Jx19 ET42','8.5Jx20 ET40']},
        {'name':'G9', 'g':[{'n':'All','y':'2022+','p':'5x112','o':'ET38-45','c':'60.1mm','t':'M14x1.5','q':'130Nm'}], 'ts':['255/50R19','265/45R20'], 'rs':['8.5Jx19 ET40','9Jx20 ET38']},
        {'name':'P7', 'g':[{'n':'All','y':'2021+','p':'5x112','o':'ET38-42','c':'60.1mm','t':'M14x1.5','q':'130Nm'}], 'ts':['245/45R19','245/40R20'], 'rs':['8.5Jx19 ET38','8.5Jx20 ET35']},
        {'name':'X9', 'g':[{'n':'All','y':'2024+','p':'5x112','o':'ET40-48','c':'60.1mm','t':'M14x1.5','q':'130Nm'}], 'ts':['235/55R20','255/45R21'], 'rs':['8.5Jx20 ET42','9Jx21 ET40']},
    ]},
    'Xiaomi': {'models': [
        {'name':'SU7', 'g':[{'n':'All','y':'2024+','p':'5x114.3','o':'ET38-42','c':'64.5mm','t':'M14x1.5','q':'140Nm'}], 'ts':['245/45R19','245/40R20','265/35R21'], 'rs':['8.5Jx19 ET40','9Jx20 ET38','9.5Jx21 ET35']},
        {'name':'SU7 Ultra', 'g':[{'n':'All','y':'2025+','p':'5x114.3','o':'ET35-40','c':'64.5mm','t':'M14x1.5','q':'140Nm'}], 'ts':['265/35R21','305/30R21'], 'rs':['9.5Jx21 ET35','11Jx21 ET35']},
    ]},
}

d.update(chinese_ev_data)

with open('assets/fitment_data.json', 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)

total_models = sum(len(v['models']) for v in d.values())
print(f'Makes: {len(d)}, Models: {total_models}')
for k in sorted(d.keys()):
    print(f'  {k:20s}  {len(d[k]["models"]):3d} models')
