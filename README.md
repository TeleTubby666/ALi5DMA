# ALi5DMA

DOS tool that enables CD/DVD bus-master DMA on ALi M1543/M1543C (M5229) chipsets (Aladdin IV+, Aladdin V, Aladdin Pro II).
It fixes the "General failure" error you get with UIDE/UDVD2 when you don't use `/UX`.

*Deutsche Version weiter unten.*

## The problem

On boards with the ALi M1543/M1543C southbridge, CD/DVD drives work in DMA mode under Windows 9x. Under DOS with UIDE or UDVD2, every access to them fails with **"General failure"**. The usual workaround is `/UX`, which forces PIO mode.

## The cause

Bit 0 of register **53h** in the M5229 IDE controller's PCI config space is the "CD-ROM DMA enable" bit. Some BIOSes leave it cleared (confirmed on the ASUS P5A). The Windows 9x driver sets it, but DOS drivers don't touch chipset registers. As long as the bit is cleared, ATAPI DMA transfers fail.

## The fix

`ALI5DMA.EXE` finds the M5229 on the PCI bus and sets that bit. The change lasts until the next reset. The same file works as a device driver and as a program.

**As a device driver (recommended):** load it in `CONFIG.SYS` before UIDE/UDVD2.

```
DEVICE=C:\DOS\ALI5DMA.EXE /Q
DEVICEHIGH=C:\DOS\UIDE.SYS /S20 /D:MSCD000
```

Only the 18-byte device header and two short stubs stay resident (63 bytes). The rest is discarded after init.

**As a program:** run it in `AUTOEXEC.BAT`, before SHSUCDX/MSCDEX:

```
C:\DOS\ALI5DMA.EXE /Q
```

UIDE itself only issues PIO commands while loading, so this works too, even though UIDE was loaded first.

In both cases, load UIDE/UDVD2 **without** `/UX`.

| Option | Effect |
|---|---|
| (none) | Sets the bit and shows register 53h before and after |
| `/Q` | No output unless an error occurs |
| `/W` | Additionally enables CD-ROM DMA **write** (register 4Bh bit 7). Asks for confirmation every time. Not recommended, see below |

Program exit codes (`ERRORLEVEL`): `0` OK, `1` no M5229 found, `2` bit could not be set.

### Why CD-ROM DMA write is off by default

Register 4Bh bit 7 controls DMA for data sent *to* an ATAPI drive, which in practice means CD burning. The Linux `alim15x3` driver deliberately clears this bit on M5229 revisions 20h, C0h and C1h, because ATAPI DMA writes are broken there. The Windows 98 driver leaves it off as well, so it burns via PIO. A failure would most likely mean a silently corrupted disc, not an error message. Reading isn't affected.

There's also little to gain under DOS: UIDE/UDVD2 only read from CD/DVD, and DOS burning software uses its own ASPI driver. If you want to experiment anyway, `/W` enables the bit after you confirm it with `Y`. The prompt also appears when the driver is loaded from `CONFIG.SYS`.

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
nasm -f bin -o bin/ALI5DMA.EXE src/ALI5DMA.ASM
nasm -f bin -o bin/ALIINFO.COM src/ALIINFO.ASM
```

Requires a 386 or newer CPU (PCI configuration mechanism #1).

---

## Deutsch

**ALi5DMA** schaltet unter DOS den Bus-Master-DMA für CD/DVD-Laufwerke an ALi-M1543/M1543C-Chipsätzen (M5229) frei.

**Problem:** Unter Windows 9x laufen die Laufwerke mit DMA. Unter DOS bricht UIDE bzw. UDVD2 ohne `/UX` jeden Zugriff mit „Allgemeiner Fehler“ ab.

**Ursache:** Manche BIOS-Versionen (z. B. ASUS P5A) setzen Bit 0 im Register 53h des M5229 („CD-ROM DMA enable“) nicht. Der Windows-Treiber holt das nach, DOS-Treiber nicht.

**Lösung:** `DEVICE=C:\DOS\ALI5DMA.EXE /Q` in die `CONFIG.SYS` eintragen, und zwar vor UIDE. Alternativ kann `ALI5DMA.EXE /Q` in der `AUTOEXEC.BAT` vor SHSUCDX/MSCDEX stehen. UIDE dann ohne `/UX` laden. Als Treiber bleiben nur 63 Byte resident.

Die Option `/W` schaltet zusätzlich das DMA-Schreiben (Register 4Bh, Bit 7) ein. Davon wird abgeraten: Auf Revisionen unter C2h ist es laut Linux-Treiber defekt, und auch Windows 98 lässt es aus. Ein Fehler würde wahrscheinlich still eine Brenn-CD beschädigen. ALI5DMA fragt deshalb jedes Mal nach, auch beim Laden aus der `CONFIG.SYS`. Erst ein `Y` bestätigt die Änderung.

`ALIINFO.COM` liest die Register nur aus und ändert nichts. Es eignet sich zur Diagnose und zum Vergleich mit der DOS-Box unter Windows.

Getestet auf einem ASUS P5A mit M5229 Rev. C1. Dort laufen zwei TEAC-Laufwerke und eine CF-Karte mit UltraDMA 2, und die kopierten Daten sind byteidentisch. Bitte die Datenintegrität auf dem eigenen System mit `FC /B` prüfen.

## License

MIT, see [LICENSE](LICENSE).
