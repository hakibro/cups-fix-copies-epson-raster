## Bug: Multiple copies ("print N copies") are ignored for raster drivers via the `universal` filter

### Summary

When printing to a CUPS **raster** printer whose PPD uses a `*cupsFilter:` line
(so jobs are routed through the cups-filters **`universal`** filter), requesting
**N copies always prints exactly 1 copy**.

This affects Epson raster drivers (e.g. Epson L120/L121) and any raster driver
that relies on the `universal` filter.

### Environment

- Distro: CachyOS (Arch-based), kernel 7.2.2
- cups-filters **2.0.1** (`universal`, `pdftopdf` filter binaries)
- libcupsfilters **2.2.1** (the library that implements `cfFilterPDFToPDF`)
- libppd 2.1.1
- CUPS 2.4.19
- Ghostscript 10.07.1
- Printer: Epson L120 Series, PPD has:
  ```
  *cupsFilter: "application/vnd.cups-raster 0 epson_inkjet_printer_filter"
  ```

### Steps to reproduce

1. Print any 1-page document requesting multiple copies, e.g.:
   ```
   lp -d Epson-L121 -n 3 /etc/nsswitch.conf
   ```
   or from any desktop print dialog with Copies = 3.
2. Only 1 sheet comes out.

### What I expected

3 sheets (one per copy).

### What actually happens

1 sheet. The job is recorded correctly with `copies = 3` (visible via
`Get-Job-Attributes`), and the scheduler passes `argv[4] = 3` to the filter
chain, but only a single copy is produced.

### Root cause (traced in the source)

The copy count is lost between CUPS and `cfFilterPDFToPDF`.

1. **CUPS** passes the requested copy count to filters via the standard
   **`argv[4]`** argument and *strips* the `copies=` option from the options
   string (`argv[5]`). This is done in CUPS `scheduler/job.c` `get_options()`:
   the `copies` job attribute is consumed into the `copies` buffer (→ `argv[4]`)
   and deliberately not added to the options string (→ `argv[5]`).

2. **libcupsfilters `cfFilterPDFToPDF`** builds its options from the options
   string only and never reads `data->copies` (`argv[4]`):
   - `cupsfilters/pdftopdf.c`:
     ```c
     filter_options = cfFilterOptionsCreate(data->num_options, data->options);
     ```
   - `cupsfilters/ipp-options.c` `cfFilterOptionsCreate()` initialises
     `ippo->copies = 1;` and only overrides it from an option in the string:
     ```c
     if (((value = get_option("copies", num_options, options)) != NULL ||
          (value = get_option("Copies", num_options, options)) != NULL ||
          (value = get_option("num-copies", num_options, options)) != NULL ||
          (value = get_option("NumCopies", num_options, options)) != NULL) && ...)
       ippo->copies = intvalue;
     ```
   It never consults `data->copies`.

Because `argv[5]` contains no `copies=` (CUPS removed it) and
`cfFilterPDFToPDF` ignores `argv[4]`, `options->copies` stays `1`, and exactly
one copy is generated.

### Proof

Injecting `copies=N` into the options string makes copies work correctly. With
the `universal` filter called as:

```
universal 67 user title N "copies=N" file.pdf
```

the resulting CUPS raster stream is exactly N × the size of a single-copy run
(measured: 1 page vs 2 pages vs 3 pages). Without the `copies=` option in
`argv[5]`, it is always 1 page regardless of `argv[4]`.

### Suggested fix

Make `cfFilterPDFToPDF` (via `cfFilterOptionsCreate` or the caller) honour
`data->copies` (`argv[4]`), e.g. as a fallback when no `copies=`/`Copies=`
option is present, since CUPS always supplies the count via `argv[4]`. This is
the documented CUPS filter contract.

A workaround for end users (and what I currently use) is a small wrapper around
`/usr/lib/cups/filter/universal` that re-injects `copies=<argv[4]>` into the
options string: https://github.com/hakibro/cups-fix-copies-epson-raster

### Related

- #53 is about *unwanted* copies (double counting); this issue is the opposite
  (copies never produced for raster output via the `universal` filter).
