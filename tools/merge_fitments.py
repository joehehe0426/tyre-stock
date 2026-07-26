import json, os

path = "C:/Users/User/Documents/tyre_stock_app/assets/fitment_data.json"
with open(path, encoding='utf-8') as f:
    data = json.load(f)

extra = {
    "Land Rover": {"models": [
        {"name":"Range Rover Evoque","g":[{"n":"L538/L551","y":"2011+","p":"5x108","o":"ET42-50","c":"63.4mm","t":"M14x1.5","q":"130Nm"}],"ts":["235/60R18","235/55R19"],"rs":["7.5Jx18 ET45","8Jx18 ET40"]},
        {"name":"Range Rover Velar","g":[{"n":"L560","y":"2017+","p":"5x108","o":"ET42-50","c":"63.4mm","t":"M14x1.5","q":"130Nm"}],"ts":["255/55R19","265/45R21"],"rs":["8Jx19 ET45","8.5Jx21 ET42"]},
        {"name":"Discovery Sport","g":[{"n":"L550","y":"2014+","p":"5x108","o":"ET42-50","c":"63.4mm","t":"M14x1.5","q":"130Nm"}],"ts":["235/60R18","235/55R19"],"rs":["7.5Jx18 ET45","8Jx18 ET40"]},
    ]},
    "Mini": {"models": [
        {"name":"Cooper","g":[{"n":"F55/F56","y":"2014+","p":"5x112","o":"ET42-55","c":"66.6mm","t":"M12x1.5","q":"120Nm"}],"ts":["195/55R16","205/45R17"],"rs":["6.5Jx16 ET54","7Jx17 ET48"]},
        {"name":"Countryman","g":[{"n":"F60","y":"2017+","p":"5x112","o":"ET42-55","c":"66.6mm","t":"M12x1.5","q":"120Nm"}],"ts":["225/55R17","225/45R19"],"rs":["7Jx17 ET48","7.5Jx19 ET48"]},
    ]},
    "MG": {"models": [
        {"name":"MG4","g":[{"n":"EH32","y":"2022+","p":"5x108","o":"ET38-45","c":"65.1mm","t":"M12x1.5","q":"120Nm"}],"ts":["215/55R17","235/45R18"],"rs":["7Jx17 ET42","7.5Jx18 ET38"]},
        {"name":"ZS","g":[{"n":"IS1","y":"2017+","p":"5x114.3","o":"ET40-50","c":"67.1mm","t":"M12x1.5","q":"115Nm"}],"ts":["215/50R17","215/45R18"],"rs":["6.5Jx17 ET43","7Jx18 ET43"]},
        {"name":"HS","g":[{"n":"IS3","y":"2019+","p":"5x108","o":"ET38-45","c":"65.1mm","t":"M12x1.5","q":"120Nm"}],"ts":["235/50R18","235/45R19"],"rs":["7Jx18 ET42","7.5Jx19 ET42"]},
    ]},
    "Mitsubishi": {"models": [
        {"name":"Outlander","g":[{"n":"GF7W","y":"2013+","p":"5x114.3","o":"ET35-45","c":"67.1mm","t":"M12x1.5","q":"100Nm"}],"ts":["215/70R16","225/55R18"],"rs":["6.5Jx16 ET45","7Jx18 ET38"]},
        {"name":"Eclipse Cross","g":[{"n":"GK","y":"2018+","p":"5x114.3","o":"ET35-45","c":"67.1mm","t":"M12x1.5","q":"100Nm"}],"ts":["225/55R18"],"rs":["7Jx18 ET38"]},
    ]},
    "Suzuki": {"models": [
        {"name":"Swift","g":[{"n":"ZC83S","y":"2017+","p":"4x100","o":"ET45-55","c":"54.1mm","t":"M12x1.5","q":"100Nm"}],"ts":["185/55R16","195/45R17"],"rs":["6Jx16 ET50","6.5Jx17 ET50"]},
        {"name":"Jimny","g":[{"n":"JB64/JB74","y":"2018+","p":"5x139.7","o":"ET0-10","c":"108mm","t":"M12x1.25","q":"100Nm"}],"ts":["195/80R15","205/70R15"],"rs":["5.5Jx15 ET5","6Jx15 ET0"]},
        {"name":"Vitara","g":[{"n":"LY","y":"2015+","p":"5x114.3","o":"ET40-50","c":"60.1mm","t":"M12x1.5","q":"105Nm"}],"ts":["215/60R16","215/55R17"],"rs":["6Jx16 ET50","6.5Jx17 ET45"]},
    ]},
    "Subaru": {"models": [
        {"name":"Forester","g":[{"n":"SJ/SK","y":"2013+","p":"5x114.3","o":"ET45-55","c":"56.1mm","t":"M12x1.25","q":"120Nm"}],"ts":["225/60R17","225/55R18"],"rs":["7Jx17 ET48","7Jx18 ET48"]},
        {"name":"Outback","g":[{"n":"BS/BT","y":"2015+","p":"5x114.3","o":"ET45-55","c":"56.1mm","t":"M12x1.25","q":"120Nm"}],"ts":["225/65R17","225/60R18"],"rs":["7Jx17 ET48","7Jx18 ET48"]},
        {"name":"WRX","g":[{"n":"VB","y":"2022+","p":"5x114.3","o":"ET45-55","c":"56.1mm","t":"M12x1.25","q":"120Nm"}],"ts":["245/40R18"],"rs":["8.5Jx18 ET55"]},
    ]},
    "Ford": {"models": [
        {"name":"Focus","g":[{"n":"MK4","y":"2019+","p":"5x108","o":"ET45-55","c":"63.4mm","t":"M12x1.5","q":"110Nm"}],"ts":["205/60R16","235/40R18"],"rs":["6.5Jx16 ET50","8Jx18 ET50"]},
        {"name":"Ranger","g":[{"n":"T6","y":"2011+","p":"6x139.7","o":"ET0-25","c":"93.1mm","t":"M14x1.5","q":"140Nm"}],"ts":["265/65R17","265/60R18"],"rs":["7.5Jx17 ET20","8Jx18 ET20"]},
        {"name":"Mustang","g":[{"n":"S550","y":"2015+","p":"5x114.3","o":"ET30-45","c":"70.5mm","t":"M14x1.5","q":"130Nm"}],"ts":["235/55R17","255/40R19"],"rs":["8Jx17 ET40","9Jx19 ET45"]},
    ]},
    "Peugeot": {"models": [
        {"name":"308","g":[{"n":"T9","y":"2014+","p":"5x108","o":"ET35-45","c":"65.1mm","t":"M12x1.25","q":"100Nm"}],"ts":["205/55R16","225/40R18"],"rs":["6.5Jx16 ET45","7.5Jx18 ET40"]},
        {"name":"3008","g":[{"n":"P84","y":"2016+","p":"5x108","o":"ET35-45","c":"65.1mm","t":"M12x1.25","q":"100Nm"}],"ts":["215/65R17","235/50R19"],"rs":["7Jx17 ET43","7.5Jx19 ET40"]},
    ]},
    "Fiat": {"models": [
        {"name":"500","g":[{"n":"312","y":"2007+","p":"4x98","o":"ET35-45","c":"58.1mm","t":"M12x1.25","q":"100Nm"}],"ts":["175/65R15","195/45R16"],"rs":["5.5Jx15 ET35","6.5Jx16 ET35"]},
    ]},
}

data.update(extra)

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Total makes: {len(data)}")
total_models = sum(len(v['models']) for v in data.values())
print(f"Total models: {total_models}")
print(f"File size: {os.path.getsize(path)} bytes")
