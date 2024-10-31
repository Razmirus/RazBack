import sys

def backupnums(currnum):
    
    for i in range(10):
        while(currnum % pow(2,i) != 0):
            currnum = currnum -1
        for _ in range(3):
            print(currnum,end="; ")
            currnum = currnum - pow(2,i)
            if currnum < pow(2,i) :
                break
        if currnum < pow(2,i)+1 :
            break
    print()        
   
def main():
    num = 30
    args = sys.argv[1:]
    if len(args) >= 1:
        num = int(args[0])
    for i in range(30):
        print(i+1,end="; ")
    print()

    for i in range(num):
        backupnums(i+1)

if __name__ == "__main__":
    main()
