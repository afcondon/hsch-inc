# Minard Future Work

**Category**: Plan
**Status**: Active
**Created**: 2026-02-01

## Overview

Ideas and planned future work for the Minard code cartography tool.

## Minard Dataset Demo

The stdlib-js repository has a `minard` dataset containing Charles Joseph Minard's famous visualization of Napoleon's Russian campaign (1812). This is a perfect fit for a showcase demo given our tool's name.

**Dataset**: https://github.com/stdlib-js/datasets-minard-napoleons-march

**Potential demo**:
- Recreate the classic Minard visualization using Hylograph
- Layer troop numbers, temperature, and geography
- Interactive exploration of the campaign timeline

**Why this matters**: Minard's original chart (1869) is considered one of the best statistical graphics ever made. Building our own version would:
1. Pay homage to our namesake
2. Demonstrate Hylograph's multi-layer composition capabilities
3. Create a visually striking demo for the landing page

## HTTPurple Route Extraction

Fabrizio's first comment on seeing the Code Explorer was about tracking API routes. The loader should extract:

1. **HTTPurple route definitions**:
   ```purescript
   route :: RouteDuplex' Route
   route = root $ sum
     { "GetUser": path "api/users" (int segment)
     , "CreateUser": path "api/users" noArgs
     }
   ```

2. **WebSocket endpoints**

3. **External API calls** (affjax, fetch)

**New tables needed**:
- `api_routes (id, module_id, name, method, url_pattern)`
- `api_route_types (route_id, request_type, response_type)`
- `api_calls (frontend_module_id, backend_route_id)`

**Benefits**:
- Dead API detection (defined but never called)
- Missing API detection (called but not defined)
- Full-stack dependency graphs
- Documentation generation

## Other Future Work

See `apps/minard/docs/LOADER-SPEC.md` for:
- Incremental loading
- Git integration
- Haskell support
- Registry integration

---

*These are notes for future work, not immediate priorities.*
