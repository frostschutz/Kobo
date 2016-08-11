#!/bin/bash

for header in "$@"
do
    echo Processing "$header"...
    cat "$header" \
    | sed -r \
          -e 's@^#\s*define\s+([^\t ()]+)\s.*$@DEFS2GO const \1 = C.\1@' \
          -e 's@^struct\s+([^\t ()]+)\s.*$@DEFS2GO type \1 C.struct_\1@' \
    | grep '^DEFS2GO' \
    | sed -r -e 's@^DEFS2GO @@' \
    > "$header".template.go
done
