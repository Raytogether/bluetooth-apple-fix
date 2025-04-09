#!/bin/bash\n\n# Test utilities\n\nassert_success() {\n    if [ $1 -eq 0 ]; then\n        echo "✓ Test passed"\n        return 0\n    else\n        echo "✗ Test failed"\n        return 1\n    fi\n}\n\nassert_failure() {\n    if [ $1 -ne 0 ]; then\n        echo "✓ Test passed (expected failure)"\n        return 0\n    else\n        echo "✗ Test failed (unexpected success)"\n        return 1\n    fi\n}
