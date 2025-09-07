
def getpwuid(uid):
    # minimal shim returning a tuple-like object with pw_name at index 0
    class Pw:
        def __init__(self):
            self.pw_name = 'winuser'
    return Pw()

def getpwnam(name):
    return getpwuid(0)
