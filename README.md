# CUPS "Print N Copies" Fix for Epson Raster Drivers (Linux)

A tiny wrapper around the CUPS `universal` filter that restores **multi-copy
("print N copies")** printing for Epson CUPS raster drivers (e.g. **Epson
L120/L121**), where choosing more than one copy in a print dialog only ever
printed a single sheet.

> **Verified on**: Epson L121 (Epson L120 Series), CUPS 2.4.19, cups-filters
> 2.0.1 / libcupsfilters 2.2.1, CachyOS (Arch-based).

---

## The problem

On a CUPS printer that uses a **raster driver** via the cups-filters
**`universal`** filter (typical for the Epson open-source driver, declared in
the PPD as `*cupsFilter: "application/vnd.cups-raster ..."`), requesting **N
copies always prints exactly 1 copy**.

The print pipeline is:

```
PDF / text / image ──► universal ──► pdftopdf ──► ghostscript ──► raster ──► epson_inkjet_printer_filter ──► USB
```

### Root cause (bug in cups-filters / libcupsfilters)

- CUPS passes the requested copy count to filters through the standard
  **`argv[4]`** argument and **strips `copies=` from the options string
  (`argv[5]`)**.
- `cfFilterPDFToPDF` (in libcupsfilters 2.x) reads the copy count **only from
  the `copies` option in `argv[5]`**, and its default is `1`. It **never reads
  `data->copies` / `argv[4]`**.

So the requested copy count is lost, and every job prints a single copy.

### The fix

Wrap `/usr/lib/cups/filter/universal` with a small script that re-injects
`copies=<N>` into the options string before calling the real filter. This makes
the internal `pdftopdf ─► ghostscript` chain generate the requested number of
copies.

Verified behaviour after applying the fix:

| Requested copies | Resulting raster output |
|------------------|--------------------------|
| 1                | 1 page                   |
| 2                | 2 pages (2× size)        |
| 3                | 3 pages (3× size)        |

---

## Requirements

- A CUPS raster printer (Epson L120/L121 etc.) using the `universal` filter.
- `sudo` access (to install a filter under `/usr/lib/cups/filter`).

## Installation

```bash
git clone https://github.com/<you>/fix-cups-copies-epson-raster.git
cd fix-cups-copies-epson-raster
sudo bash install.sh
```

`install.sh` will:

1. Back up the real filter to `/usr/lib/cups/filter/universal.real`.
2. Install `universal-wrapper.sh` as `/usr/lib/cups/filter/universal`.
3. Restart CUPS.

## Test

```bash
lp -d Epson-L121 -n 3 /etc/nsswitch.conf
```

You should get **3 sheets** instead of 1.

Then test from your desktop print dialog (set Copies = 3 and print).

## Reverting

```bash
sudo mv /usr/lib/cups/filter/universal.real /usr/lib/cups/filter/universal
sudo systemctl restart cups
```

---

## How it works

`universal-wrapper.sh` receives the standard CUPS filter arguments:

```
universal job-id user title copies options [filename]
```

When `copies > 1`, it prepends `copies=<copies>` to `options`, then `exec`s the
real `/usr/lib/cups/filter/universal.real` with the same arguments. The
injected `copies=` option is what the downstream `pdftopdf` filter actually
honors, so the requested number of copies is generated.

The wrapper only touches jobs that ask for more than one copy, so normal
single-copy printing is completely unaffected.

---

## Affected setup / compatibility

This applies specifically to printers whose PPD uses a **`*cupsFilter:`
(not `*cupsFilter2:`)** line pointing at a CUPS **raster** driver, so that CUPS
routes jobs through the cups-filters `universal` filter. If your printer works
via `cupsFilter2` (IPP Everywhere / driverless) or a PostScript path, copies
may already work and this wrapper is not needed.

## License

MIT
