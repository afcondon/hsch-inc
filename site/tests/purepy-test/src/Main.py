# FFI for Main module - Python's print()

def printLine(s):
    """Effect-wrapped print: String -> Effect Unit"""
    def effect():
        print(s)
        return None  # Unit
    return effect
