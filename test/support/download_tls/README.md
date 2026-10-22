# Isolated HTTPS fixture

The certificate and private key in this directory are public, disposable test
material for the loopback HTTP server. They are not application or GitHub
credentials. Never use them in production. The certificate has SANs for
127.0.0.1 and localhost; only the test client's SecurityContext trusts it.
Production uses normal platform trust, with no badCertificateCallback.

Generated with OpenSSL for the tests on 2026-10-22, valid for ten years. Renew
the two fixtures together when needed; no production trust store is changed.
