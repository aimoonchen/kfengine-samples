import os
import json
current_path = os.getcwd()
list_dirs = os.walk(current_path)
filelist = []
jsonfile = open("filelist.json", 'w')
for root, dirs, files in list_dirs:
    for file_name in files:
        fn = (root + '\\' + file_name)[len(current_path) + 1:]
        fn = '/'.join(fn.split('\\'))
        if fn != "filelist.py" and fn != "data.pak":
            filelist.append(fn)
json.dump(filelist, jsonfile)