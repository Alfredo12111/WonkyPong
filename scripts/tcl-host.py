"""Only hosts Python's bundled Tcl interpreter; all strategy logic is Tcl."""
import pathlib
import sys
import tkinter
try:
    tkinter.Tcl().eval(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
except tkinter.TclError as error:
    print(error, file=sys.stderr)
    sys.exit(1)
