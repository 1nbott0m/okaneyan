# Performance QA

**Status:** `UNTESTED` for Lighthouse/Core Web Vitals and physical mobile performance.

The current preview is one local HTML page with inline styles and demo data; there is no production build, server request path, image loading or analytics telemetry. A Chromium DOM pass reported no JavaScript page errors during tested flows. This is not a performance score.

Pending: Lighthouse on a production-like build, mobile CPU throttling, animation frame/jank checks on device, load/interaction latency, CLS/LCP/INP field data (only if a real deployed product exists). Infinite decorative ring motion is disabled by the `prefers-reduced-motion` rule; its battery/compositor cost on real devices remains unknown.
