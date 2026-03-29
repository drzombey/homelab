import sys
import os.path

def usage():
    sys.exit('Usage: python ' + sys.argv[0] + ' filename')

# check for single command argument    
if len(sys.argv) != 2:
    usage()

jsonfile = sys.argv[1]

# check file exists
if os.path.isfile(jsonfile) is False:
    print('File not found: ' + jsonfile)
    usage()

# get a file object and read it in as a string
fileobj = open(jsonfile)
jsonstr = fileobj.read()
fileobj.close()

# do character conversion here
outstr = jsonstr.replace('"', '\\"').replace('\n', '\\n')

# print the converted string
print(outstr)