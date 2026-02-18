# Implementation Plan

1. Add host-bridge state UI section in PRCCamera.
2. Implement periodic health checks to local host bridge endpoint.
3. Implement auto-start and manual start handlers.
4. Implement robust app discovery (bundle id + explicit fallback paths).
5. Rebuild signed macOS app.
6. Validate with process/port checks (`8787` + `39888`) after launching PRCCamera only.
