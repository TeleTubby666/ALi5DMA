# ALi5DMA

DOS tool that enables CD/DVD bus-master DMA on ALi M1543/M1543C (M5229) chipsets (Aladdin IV+, Aladdin V, Aladdin Pro II).
It fixes the "General failure" error you get with UIDE/UDVD2 when you don't use `/UX`.

*Deutsche Version weiter unten.*

## The problem

On boards with the ALi M1543/M1543C southbridge, CD/DVD drives work in DMA mode under Windows 9x. Under DOS with UIDE or UDVD2, every access to them fails with **"General failure"**. The usual workaround is `/UX`, which forces PIO mode.

## The cause

Bit 0 of register **53h** in the M5229 IDE controller's PCI config space is the "CD-ROM DMA enable" bit. Some BIOSes leave it cleared (confirmed on the ASUS P5A). The Windows 9x driver sets it, but DOS drivers don't touch chipset registers. As long as the bit is cleared, ATAPI DMA transfers fail.

## The fix

`ALI5DMA.COM` finds the M5229 on the PCI bus and sets that bit. The change lasts until the next reset.

Put it at the top of `AUTOEXEC.BAT`, before SHSUCDX/MSCDEX:

```
C:\DOS\ALI5DMA.COM /Q
LH C:\DOS\SHSUCDX.COM /D:MSCD000
```

UIDE itself can stay in `CONFIG.SYS` **without** `/UX`. It only issues PIO commands while loading, so setting the bit later in `AUTOEXEC.BAT` is fine.

| Option | Effect |
|---|---|
| (none) | Sets the bit and shows register 53h before and after |
| `/Q` | No output unless an error occurs |

Exit codes: `0` OK, `1` no M5229 found, `2` bit could not be set.

## Diagnostics: ALIINFO

`ALIINFO.COM` is read-only. It shows the M5229 revision, registers 40h–5Fh, the bus-master status and the relevant bits. Run it once in a Windows 9x DOS box and once in plain DOS to compare what the Windows driver changes:

| Register | Meaning |
|---|---|
| 53h bit 0 | CD-ROM DMA enable (the bit ALI5DMA sets) |
| 56h / 57h | UltraDMA enable + timing, primary / secondary (bit 3 = master, bit 7 = slave) |
| 58h–5Fh | PIO/MWDMA timings |
| 4Bh bit 7 | CD-ROM DMA write |

## Tested

| Board | M5229 rev | Drives | Result |
|---|---|---|---|
| ASUS P5A (Aladdin V) | C1 | TEAC CD-540E (sec. master), TEAC CD-W540E (sec. slave), Transcend CF (prim. master) | All three run at UltraDMA 2 (ATA-33) with UIDE 7-07-2020; copied files are byte-identical (`FC /B`) |

According to the Linux `alim15x3` driver, revisions below C2h aren't supposed to support UltraDMA for ATAPI. On the board above it works anyway, and the Windows 98 driver uses it too. **Verify data integrity on your system** by copying a large file from CD and comparing it with `FC /B`. If you have problems, use UIDE with `/UX`.

Reports from other boards are welcome. Please open an issue with your ALIINFO output.

## Building

```
nasm -f bin -o bin/ALI5DMA.COM src/ALI5DMA.ASM
nasm -f bin -o bin/ALIINFO.COM src/ALIINFO.ASM
```

Requires a 386 or newer CPU (PCI configuration mechanism #1).

---

## Deutsch

**ALi5DMA** schaltet unter DOS den Bus-Master-DMA für CD/DVD-Laufwerke an ALi-M1543/M1543C-Chipsätzen (M5229) frei.

**Problem:** Unter Windows 9x laufen die Laufwerke mit DMA. Unter DOS bricht UIDE bzw. UDVD2 ohne `/UX` jeden Zugriff mit „Allgemeiner Fehler“ ab.

**Ursache:** Manche BIOS-Versionen (z. B. ASUS P5A) setzen Bit 0 im Register 53h des M5229 („CD-ROM DMA enable“) nicht. Der Windows-Treiber holt das nach, DOS-Treiber nicht.

**Lösung:** `ALI5DMA.COM /Q` als erste Zeile in die `AUTOEXEC.BAT` schreiben, auf jeden Fall vor SHSUCDX/MSCDEX. UIDE dann ohne `/UX` laden.

`ALIINFO.COM` liest die Register nur aus und ändert nichts. Es eignet sich zur Diagnose und zum Vergleich mit der DOS-Box unter Windows.

Getestet auf einem ASUS P5A mit M5229 Rev. C1. Dort laufen zwei TEAC-Laufwerke und eine CF-Karte mit UltraDMA 2, und die kopierten Daten sind byteidentisch. Bitte die Datenintegrität auf dem eigenen System mit `FC /B` prüfen.

## License

MIT, see [LICENSE](LICENSE).
