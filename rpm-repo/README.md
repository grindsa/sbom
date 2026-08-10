# A2C RPM repository layout

Binary RPMs for acme2certifier EL installs that are not (fully) available from
AppStream/EPEL. Layout is **EL major → Python stack**.

```text
RPMs/
├── rhel8/
│   ├── python36/   # EL8 legacy — system Python 3.6 (`python3-*`)
│   └── python39/   # EL8 default — parallel Python 3.9 (`python39-*`, plugins)
└── rhel9/
    └── python3/    # EL9 default — system Python 3.9 (`python3-*`)
```

## Which directory to use

| OS | a2c flavor | Directory |
| --- | --- | --- |
| EL8 | `acme2certifier-python3` (legacy 3.6) | `RPMs/rhel8/python36/` |
| EL8 | `acme2certifier-python39` (default 3.9) | `RPMs/rhel8/python39/` |
| EL9 | `acme2certifier-python3` (default 3.9) | `RPMs/rhel9/python3/` |

Do **not** mix `python3-*` and `python39-*` in one leaf directory.

Arch is encoded in the RPM filename (`noarch` / `x86_64` / `aarch64`). Install the
matching arch (or `noarch`) for the target host.

## Consumers

- Manual: `yum/dnf localinstall` from the matching leaf.
- CI (`acme2certifier` `rpm_prep`): copy only the leaf for the OS + flavor under test
  (not `rhel$N/*.rpm` from the old flat layout).

## SRPMs

Source RPMs remain under `SRPMs/` (flat). Split later if needed.

## Migration note

Previous flat paths:

- `RPMs/rhel8/*.rpm` → `RPMs/rhel8/python36/`
- `RPMs/rhel9/*.rpm` → `RPMs/rhel9/python3/`

Update bookmarks and docs that still point at the old flat URLs.
