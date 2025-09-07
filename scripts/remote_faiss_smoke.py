#!/usr/bin/env python3
"""Simple FAISS smoke test: create small index, add vectors, run a search.
If the process dies with "Illegal instruction" it's likely a native instruction set mismatch.
"""

import sys

try:
    import platform

    import faiss
    import numpy as np

    print('python', sys.version.splitlines()[0])
    print('platform', platform.platform())
    print('faiss file', getattr(faiss, '__file__', 'n/a'))
    d = 64
    xb = np.random.rand(1000, d).astype('float32')
    print('xb shape', xb.shape)
    idx = faiss.IndexFlatL2(d)
    print('created index', type(idx))
    idx.add(xb)
    print('ntotal', idx.ntotal)
    xq = np.random.rand(1, d).astype('float32')
    D, idx_i = idx.search(xq, 5)
    print('search OK, I shape', idx_i.shape, 'I', idx_i[:1], 'D', D[:1])
except Exception as e:
    import traceback

    print('EXCEPTION', type(e).__name__, e)
    traceback.print_exc()
    sys.exit(2)
