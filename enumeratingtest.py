import sys

def backupnums(currnum):
    returnval = []
    for i in range(10):
        while(currnum % pow(2,i) != 0):
            currnum = currnum -1
        for _ in range(3):
            returnval.append(currnum)
            currnum = currnum - pow(2,i)
            if currnum < pow(2,i) :
                break
        if currnum < pow(2,i)+1 :
            break
    return tuple(returnval)
   
def main():
    num = 30
    args = sys.argv[1:]
    if len(args) >= 1:
        num = int(args[0])
    vals = tuple(range(1,31))
    print(vals)

    for i in range(num):
        vals = backupnums(i+1)
        print(vals)

if __name__ == "__main__":
    main()
